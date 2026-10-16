<#PSScriptInfo

.VERSION 3.1.1

.GUID b5220b73-8f76-473d-ac22-b7be21b904c4

.AUTHOR Sascha Feig

.COPYRIGHT (c) 2024-2026 Sascha Feig. MIT License.

.TAGS Citrix CVAD XenDesktop VirtualAppsAndDesktops VDA DeliveryGroup DeliveryController PowerOn ScheduledTask Windows

.LICENSEURI https://github.com/feiglein74/Citrix_CVAD-Reboot-Check/blob/master/LICENSE

.PROJECTURI https://github.com/feiglein74/Citrix_CVAD-Reboot-Check

.RELEASENOTES
See https://github.com/feiglein74/Citrix_CVAD-Reboot-Check/blob/master/CHANGELOG.md

#>

#Requires -Version 5.1

<#
.SYNOPSIS
    Citrix Reboot Check Script - Überwacht Citrix Desktop-Gruppen und startet offline Maschinen

.DESCRIPTION
    Checks Citrix Virtual Apps and Desktops (CVAD / XenDesktop) Delivery Groups for VDA machines
    that are powered off and powers them on. Machines in maintenance mode are skipped. Every action
    is written to the Windows Application event log. Intended as a scheduled task on the Delivery
    Controller after the nightly reboot window. Requires Windows PowerShell 5.1 and the Citrix
    Broker snap-ins.

    Dieses Skript prüft konfigurierte Citrix Desktop Delivery Groups auf offline Maschinen
    und initiiert automatisch deren Start. Alle Aktivitäten werden im Windows Event Log protokolliert.

    Beim Dot-Sourcing (z.B. in Pester-Tests) werden nur die Funktionen geladen,
    das Hauptprogramm wird nicht ausgeführt.

.PARAMETER DesktopGroup
    Namen der zu prüfenden Citrix Delivery Groups (Pflichtparameter)

.PARAMETER Verbose
    Zeigt detaillierte Ausgaben während der Ausführung

.EXAMPLE
    .\citrix_reboot_check.ps1 -DesktopGroup "DG-Example1","DG-Example2" -Verbose

.NOTES
    Version:        3.1.1
    Autor:          Sascha Feig
    Erstelldatum:   2024-11-28
    Änderungsdatum: 2026-10-16

.LINK
    Siehe CHANGELOG.md für detaillierte Versionshistorie
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$DesktopGroup
)

# Skript-Version
$ScriptVersion = "3.1.1"

# Event Log Objekt, wird von Initialize-EventLog gesetzt
$script:EventLog = $null

#region Funktionen

# Lädt die Citrix Snap-ins und prüft, ob die benötigten Cmdlets verfügbar sind
function Initialize-CitrixEnvironment {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Add-PSSnapin "Citrix.*" -ErrorAction Stop
        Write-Verbose "Citrix Snap-ins erfolgreich geladen"
    }
    catch {
        Write-Error "Fehler beim Laden der Citrix Snap-ins: $_"
        return $false
    }

    $requiredCmdlets = @('Get-BrokerDesktop', 'New-BrokerHostingPowerAction')
    foreach ($cmdlet in $requiredCmdlets) {
        if (-not (Get-Command $cmdlet -ErrorAction SilentlyContinue)) {
            Write-Error "Benötigtes Cmdlet '$cmdlet' nicht verfügbar. Bitte Citrix PowerShell Module installieren."
            return $false
        }
    }

    return $true
}

# Bereitet das Event Log vor und schreibt den Start-Eintrag
function Initialize-EventLog {
    [CmdletBinding()]
    param(
        [string]$Source = "Citrix Reboot Check Script"
    )

    try {
        $script:EventLog = New-Object -TypeName System.Diagnostics.EventLog -ArgumentList Application
        $script:EventLog.Source = $Source
        $script:EventLog.WriteEntry("Starting scheduled task Citrix Post-Reboot Check Script v$ScriptVersion.","Information",111)
    }
    catch {
        Write-Warning "Event Log konnte nicht initialisiert werden: $_. Skript wird ohne Event Log-Unterstützung fortgesetzt."
        $script:EventLog = $null
    }
}

# Schreibt ins Event Log, falls verfügbar, und immer nach Verbose
function Write-EventLogSafe {
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$EntryType = "Information",
        [int]$EventId = 100
    )

    if ($null -ne $script:EventLog) {
        try {
            $script:EventLog.WriteEntry($Message, $EntryType, $EventId)
        }
        catch {
            Write-Warning "Event Log Schreibfehler: $_"
        }
    }
    Write-Verbose $Message
}

# Startet eine offline Maschine; liefert $true bei Erfolg, sonst $false
function Start-OfflineMachine {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$MachineName
    )

    if ([string]::IsNullOrWhiteSpace($MachineName)) {
        Write-Warning "Ungültiger Maschinenname übergeben"
        return $false
    }

    $message = "Host $MachineName is Offline. Start will be initiated!"
    Write-EventLogSafe -Message $message -EventId 124

    try {
        New-BrokerHostingPowerAction -MachineName $MachineName -Action TurnOn -ErrorAction Stop | Out-Null
        Write-Verbose "Power-On Aktion erfolgreich für $MachineName"
        return $true
    }
    catch {
        $errorMsg = "Fehler beim Starten von ${MachineName}: $_"
        Write-EventLogSafe -Message $errorMsg -EntryType "Error" -EventId 125
        Write-Error $errorMsg
        return $false
    }
}

# Protokolliert eine laufende Maschine
function Write-MachineRunning {
    [CmdletBinding()]
    param(
        [string]$MachineName
    )

    if ([string]::IsNullOrWhiteSpace($MachineName)) {
        Write-Warning "Ungültiger Maschinenname übergeben"
        return
    }

    $message = "Host: $MachineName is running."
    Write-EventLogSafe -Message $message -EventId 123
}

# Prüft alle Desktop-Gruppen, startet offline Maschinen und liefert den Exit Code (0/1)
function Invoke-CitrixRebootCheck {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$DesktopGroup
    )

    # Statistik-Variablen initialisieren
    $totalMachines = 0
    $machinesOnline = 0
    $machinesOffline = 0
    $machinesStarted = 0
    $errors = 0

    # Schleife um alle Bereitstellungsgruppen abzuarbeiten
    foreach ($desktopgroup in $DesktopGroup)
    {
        Write-Verbose "Verarbeite Desktop-Gruppe: $desktopgroup"

        try {
            # Abfrage nach Workern in DG
            $desktopgroupmember = @( Get-BrokerDesktop -DesktopGroupName $desktopgroup -ErrorAction Stop |
                                     Where-Object {$_.InMaintenanceMode -eq $false} |
                                     Sort-Object -Property MachineName )

            if ($desktopgroupmember.Count -eq 0) {
                $warnMsg = "Keine Maschinen in Desktop-Gruppe '$desktopgroup' gefunden (oder alle im Wartungsmodus)"
                Write-Warning $warnMsg
                Write-EventLogSafe -Message $warnMsg -EntryType "Warning" -EventId 120
                continue
            }

            Write-Verbose "Gefundene Maschinen in ${desktopgroup}: $($desktopgroupmember.Count)"
            $totalMachines += $desktopgroupmember.Count

            # Prüfung bzgl laufender VMs
            foreach ($member in $desktopgroupmember)
            {
                if ($member.PowerState -in @('Off', 'TurningOff'))
                {
                    $machinesOffline++
                    $started = Start-OfflineMachine -MachineName $member.MachineName
                    if ($started -eq $true) {
                        $machinesStarted++
                    }
                    else {
                        $errors++
                    }
                }
                else
                {
                    $machinesOnline++
                    Write-MachineRunning -MachineName $member.MachineName
                }
            }
        }
        catch {
            $errors++
            $errorMsg = "Fehler beim Abfragen der Desktop-Gruppe '${desktopgroup}': $_"
            Write-Error $errorMsg
            Write-EventLogSafe -Message $errorMsg -EntryType "Error" -EventId 126
        }
    }

    # Abschluss-Summary erstellen und loggen
    $summaryMsg = @"
Citrix Reboot Check Script v$ScriptVersion abgeschlossen.
Geprüfte Desktop-Gruppen: $($DesktopGroup.Count)
Gesamt-Maschinen geprüft: $totalMachines
  - Online: $machinesOnline
  - Offline (Start initiiert): $machinesOffline
  - Erfolgreich gestartet: $machinesStarted
  - Fehler: $errors
"@

    Write-EventLogSafe -Message $summaryMsg -EventId 112

    # Exit Code basierend auf Ergebnissen
    if ($errors -gt 0) {
        Write-Warning "Skript mit $errors Fehler(n) beendet"
        return 1
    }

    Write-Verbose "Skript erfolgreich beendet"
    return 0
}

#endregion

# Hauptprogramm - wird beim Dot-Sourcing (z.B. in Tests) übersprungen
if ($MyInvocation.InvocationName -ne '.') {
    Write-Verbose "Citrix Reboot Check Script v$ScriptVersion wird gestartet..."

    if (-not (Initialize-CitrixEnvironment)) {
        exit 1
    }

    Initialize-EventLog
    exit (Invoke-CitrixRebootCheck -DesktopGroup $DesktopGroup)
}
