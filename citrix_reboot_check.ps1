#Requires -Version 5.1
<#
.SYNOPSIS
    Citrix Reboot Check Script - Überwacht Citrix Desktop-Gruppen und startet offline Maschinen

.DESCRIPTION
    Dieses Skript prüft konfigurierte Citrix Desktop Delivery Groups auf offline Maschinen
    und initiiert automatisch deren Start. Alle Aktivitäten werden im Windows Event Log protokolliert.

.PARAMETER Verbose
    Zeigt detaillierte Ausgaben während der Ausführung

.NOTES
    Version:        2.1.0
    Autor:          ACP Group AG
    Erstelldatum:   2024-11-28
    Änderungsdatum: 2026-10-10

.LINK
    Siehe CHANGELOG.md für detaillierte Versionshistorie
#>

[CmdletBinding()]
param()

# Skript-Version
$ScriptVersion = "2.1.0"

Write-Verbose "Citrix Reboot Check Script v$ScriptVersion wird gestartet..."

# Citrix Snap-ins laden mit Fehlerbehandlung
try {
    Add-PSSnapin "Citrix.*" -ErrorAction Stop
    Write-Verbose "Citrix Snap-ins erfolgreich geladen"
}
catch {
    Write-Error "Fehler beim Laden der Citrix Snap-ins: $_"
    exit 1
}

# Überprüfen ob benötigte Citrix Cmdlets verfügbar sind
$requiredCmdlets = @('Get-BrokerDesktop', 'New-BrokerHostingPowerAction')
foreach ($cmdlet in $requiredCmdlets) {
    if (-not (Get-Command $cmdlet -ErrorAction SilentlyContinue)) {
        Write-Error "Benötigtes Cmdlet '$cmdlet' nicht verfügbar. Bitte Citrix PowerShell Module installieren."
        exit 1
    }
}

# Festlegen der zu prüfenden Bereitstellungsgruppen
$Global:DESKTOPGROUP = @("DG-TS2019","DG-TS2016-Sage")

# Eventlog-Einträge vorbereiten mit Fehlerbehandlung
try {
    $Global:EventLog = New-Object -type System.Diagnostics.Eventlog -argumentlist Application
    $Global:EventLog.Source = "Citrix Reboot Check Script"
    $EventLog.WriteEntry("Starting scheduled task Citrix Post-Reboot Check Script v$ScriptVersion.","Information",111)
}
catch {
    Write-Warning "Event Log konnte nicht initialisiert werden: $_. Skript wird ohne Event Log-Unterstützung fortgesetzt."
    $Global:EventLog = $null
}

# Hilfsfunktion für Event Log Schreiben
function Write-EventLogSafe {
    param(
        [string]$Message,
        [string]$EntryType = "Information",
        [int]$EventId = 100
    )

    if ($null -ne $Global:EventLog) {
        try {
            $Global:EventLog.WriteEntry($Message, $EntryType, $EventId)
        }
        catch {
            Write-Warning "Event Log Schreibfehler: $_"
        }
    }
    Write-Verbose $Message
}

#Funktionsdefinitionen
$FinalCheckDown =
    {
        param ([string]$member)

        if ([string]::IsNullOrWhiteSpace($member)) {
            Write-Warning "Ungültiger Maschinenname übergeben"
            return $false
        }

        function FinalStart
        {
            param([string]$machineName)

            $message = "Host $machineName is Offline. Start will be initiated!"
            Write-EventLogSafe -Message $message -EventId 124

            try {
                New-BrokerHostingPowerAction -MachineName $machineName -Action TurnOn -ErrorAction Stop | Out-Null
                Write-Verbose "Power-On Aktion erfolgreich für $machineName"
                return $true
            }
            catch {
                $errorMsg = "Fehler beim Starten von ${machineName}: $_"
                Write-EventLogSafe -Message $errorMsg -EntryType "Error" -EventId 125
                Write-Error $errorMsg
                return $false
            }
        }

        FinalStart $member
    }

$FinalCheckOK =
    {
        param ([string]$member)

        if ([string]::IsNullOrWhiteSpace($member)) {
            Write-Warning "Ungültiger Maschinenname übergeben"
            return
        }

        function FinalRunning
        {
            param([string]$machineName)

            $message = "Host: $machineName is running."
            Write-EventLogSafe -Message $message -EventId 123
        }

        FinalRunning $member
    }


# Statistik-Variablen initialisieren
$totalMachines = 0
$machinesOnline = 0
$machinesOffline = 0
$machinesStarted = 0
$errors = 0

# Schleife um alle Bereitstellungsgruppen abzuarbeiten
foreach ($desktopgroup in $GLOBAL:DESKTOPGROUP)
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
                $started = Invoke-Command -ScriptBlock $FinalCheckDown -ArgumentList $member.MachineName
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
                Invoke-Command -ScriptBlock $FinalCheckOK -ArgumentList $member.MachineName
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
Geprüfte Desktop-Gruppen: $($GLOBAL:DESKTOPGROUP.Count)
Gesamt-Maschinen geprüft: $totalMachines
  - Online: $machinesOnline
  - Offline (Start initiiert): $machinesOffline
  - Erfolgreich gestartet: $machinesStarted
  - Fehler: $errors
"@

Write-Verbose $summaryMsg
Write-EventLogSafe -Message $summaryMsg -EventId 112

# Exit Code basierend auf Ergebnissen
if ($errors -gt 0) {
    Write-Warning "Skript mit $errors Fehler(n) beendet"
    exit 1
}
else {
    Write-Verbose "Skript erfolgreich beendet"
    exit 0
} 
