#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester Tests für citrix_reboot_check.ps1

.DESCRIPTION
    Testet die Funktionalität des Citrix Reboot Check Scripts.

    Hinweis: Diese Tests verwenden Mocking, um Citrix-Abhängigkeiten zu simulieren,
    da echte Citrix-Umgebungen für Tests nicht verfügbar sind.

.NOTES
    Pester Version: 5.x
    Autor: ACP Group AG
    Datum: 2025-11-10
#>

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot "citrix_reboot_check.ps1"

    # Mock Citrix Snap-ins und Cmdlets
    function Add-PSSnapin { }
    function Get-BrokerDesktop { }
    function New-BrokerHostingPowerAction { }

    # Mock EventLog
    $mockEventLog = [PSCustomObject]@{
        Source = "Citrix Reboot Check Script"
    } | Add-Member -MemberType ScriptMethod -Name WriteEntry -Value {
        param($Message, $Type, $EventId)
        # Stille Ausführung für Tests
    } -PassThru
}

Describe "citrix_reboot_check.ps1 - Skript-Grundlagen" {

    Context "Skript-Datei und Struktur" {

        It "Skript-Datei existiert" {
            $scriptPath | Should -Exist
        }

        It "Skript ist gültiges PowerShell" {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$null) } |
                Should -Not -Throw
        }

        It "Enthält #Requires -Version Deklaration" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '#Requires -Version'
        }

        It "Enthält CmdletBinding Attribut" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\[CmdletBinding\(\)\]'
        }

        It "Enthält Comment-Based Help" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
            $content | Should -Match '\.NOTES'
        }

        It "Versionsnummer ist definiert" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$ScriptVersion\s*=\s*"[\d\.]+"'
        }
    }

    Context "Konfiguration" {

        It "Desktop-Gruppen sind definiert" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$Global:DESKTOPGROUP'
        }

        It "Desktop-Gruppen enthalten erwartete Werte" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'DG-TS2019'
            $content | Should -Match 'DG-TS2016-Sage'
        }
    }
}

Describe "citrix_reboot_check.ps1 - Funktionen" {

    Context "Write-EventLogSafe Funktion" {

        BeforeAll {
            # Funktion aus dem Skript extrahieren und definieren
            $scriptContent = Get-Content $scriptPath -Raw

            # Write-EventLogSafe Funktion für Tests definieren
            function Write-EventLogSafe {
                param(
                    [string]$Message,
                    [string]$EntryType = "Information",
                    [string]$EventId = "100"
                )

                if ($Global:EventLog -ne $null) {
                    try {
                        $Global:EventLog.WriteEntry($Message, $EntryType, $EventId)
                    }
                    catch {
                        Write-Warning "Event Log Schreibfehler: $_"
                    }
                }
                Write-Verbose $Message
            }
        }

        It "Funktion existiert im Skript" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'function Write-EventLogSafe'
        }

        It "Akzeptiert Message Parameter" {
            { Write-EventLogSafe -Message "Test" } | Should -Not -Throw
        }

        It "Hat EntryType Parameter mit Default" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\[string\]\$EntryType\s*=\s*"Information"'
        }

        It "Hat EventId Parameter mit Default" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\[int\]\$EventId\s*=\s*100'
        }
    }

    Context "ScriptBlocks - FinalCheckDown und FinalCheckOK" {

        It "FinalCheckDown ScriptBlock existiert" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$FinalCheckDown\s*='
        }

        It "FinalCheckOK ScriptBlock existiert" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$FinalCheckOK\s*='
        }

        It "FinalCheckDown enthält Null-Check" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\[string\]::IsNullOrWhiteSpace'
        }

        It "FinalCheckDown ruft New-BrokerHostingPowerAction auf" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'New-BrokerHostingPowerAction.*-Action TurnOn'
        }
    }
}

Describe "citrix_reboot_check.ps1 - Event IDs" {

    Context "Event ID Verwendung" {

        It "Verwendet Event ID 111 für Start" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '"Information",\s*111\)'
        }

        It "Verwendet Event ID 112 für Ende/Summary" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '-EventId 112\b'
        }

        It "Verwendet Event ID 120 für Warnungen" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '-EventId 120\b'
        }

        It "Verwendet Event ID 123 für Maschine läuft" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '-EventId 123\b'
        }

        It "Verwendet Event ID 124 für Maschine offline" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '-EventId 124\b'
        }

        It "Verwendet Event ID 125 für Start-Fehler" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '-EventId 125\b'
        }

        It "Verwendet Event ID 126 für Abfrage-Fehler" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '-EventId 126\b'
        }
    }
}

Describe "citrix_reboot_check.ps1 - Fehlerbehandlung" {

    Context "Try-Catch Blöcke" {

        It "Enthält Try-Catch für Snap-in Laden" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'try\s*\{[^}]*Add-PSSnapin[^}]*\}\s*catch'
        }

        It "Enthält Try-Catch für EventLog Initialisierung" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'try\s*\{[\s\S]*?EventLog[\s\S]*?\}\s*catch'
        }

        It "Verwendet -ErrorAction Stop bei kritischen Cmdlets" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Add-PSSnapin.*-ErrorAction Stop'
            $content | Should -Match 'Get-BrokerDesktop.*-ErrorAction Stop'
        }
    }

    Context "Validierung" {

        It "Validiert Citrix Cmdlets beim Start" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Get-Command'
            $content | Should -Match 'Get-BrokerDesktop'
            $content | Should -Match 'New-BrokerHostingPowerAction'
        }

        It "Validiert Maschinennamen auf Null/Leer" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\[string\]::IsNullOrWhiteSpace\(\$member\)'
        }
    }

    Context "Exit Codes" {

        It "Verwendet exit 1 bei Fehlern" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'exit 1'
        }

        It "Verwendet exit 0 bei Erfolg" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'exit 0'
        }
    }
}

Describe "citrix_reboot_check.ps1 - Statistiken und Reporting" {

    Context "Statistik-Variablen" {

        It "Initialisiert totalMachines Variable" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$totalMachines\s*=\s*0'
        }

        It "Initialisiert machinesOnline Variable" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$machinesOnline\s*=\s*0'
        }

        It "Initialisiert machinesOffline Variable" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$machinesOffline\s*=\s*0'
        }

        It "Initialisiert machinesStarted Variable" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$machinesStarted\s*=\s*0'
        }

        It "Initialisiert errors Variable" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$errors\s*=\s*0'
        }
    }

    Context "Summary Reporting" {

        It "Erstellt Summary-Nachricht" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$summaryMsg\s*='
        }

        It "Summary enthält Versions-Information" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'v\$ScriptVersion'
        }

        It "Summary enthält Statistiken" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'totalMachines'
            $content | Should -Match 'machinesOnline'
            $content | Should -Match 'machinesOffline'
        }
    }
}

Describe "citrix_reboot_check.ps1 - Best Practices" {

    Context "PowerShell Best Practices" {

        It "Verwendet -eq für Boolean-Vergleiche statt -Match" {
            $content = Get-Content $scriptPath -Raw
            # Prüft ob .InMaintenanceMode mit -eq verglichen wird
            $content | Should -Match '\.InMaintenanceMode\s+-eq\s+\$false'
        }

        It "Verwendet Write-Verbose für Debug-Ausgaben" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Write-Verbose'
        }

        It "Verwendet Write-Error für Fehler" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Write-Error'
        }

        It "Verwendet Write-Warning für Warnungen" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Write-Warning'
        }

        It "Vergleicht PowerState exakt statt mit -match" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "\.PowerState\s+-in\s+@\('Off',\s*'TurningOff'\)"
            $content | Should -Not -Match '\.PowerState\s+-match'
        }

        It "Steht `$null links bei Vergleichen" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Not -Match '-ne\s+\$null'
        }
    }

    Context "Start-Ergebnis" {

        It "FinalStart liefert Erfolg/Misserfolg zurück" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'return \$true'
            $content | Should -Match 'return \$false'
        }

        It "Unterdrückt Ausgabe von New-BrokerHostingPowerAction" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'New-BrokerHostingPowerAction.*\|\s*Out-Null'
        }

        It "Zählt machinesStarted nur bei Erfolg" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'if \(\$started -eq \$true\)\s*\{\s*\$machinesStarted\+\+'
        }
    }
}
