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
    Autor: Sascha Feig
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

        It "Comment-Based Help wird von PowerShell erkannt" {
            # Bis 3.1.0 klebte #Requires direkt am Hilfeblock, Get-Help fand dadurch nichts
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
            $help = $ast.GetHelpContent()
            $help | Should -Not -BeNullOrEmpty
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It "Versionsnummer ist definiert" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$ScriptVersion\s*=\s*"[\d\.]+"'
        }

        It "PSScriptInfo ist gültig und Versionen stimmen überein" {
            $info = Test-ScriptFileInfo -Path $scriptPath
            $content = Get-Content $scriptPath -Raw
            $null = $content -match '\$ScriptVersion\s*=\s*"([\d\.]+)"'
            $info.Version.ToString() | Should -Be $Matches[1]
            $content | Should -Match "Version:\s+$([regex]::Escape($Matches[1]))"
        }
    }

    Context "Konfiguration" {

        It "Hat Pflichtparameter DesktopGroup vom Typ string[]" {
            $param = (Get-Command $scriptPath).Parameters['DesktopGroup']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType | Should -Be ([string[]])
            $mandatory = $param.Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory }
            $mandatory | Should -Contain $true
        }

        It "Desktop-Gruppen sind nicht mehr hardcoded" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Not -Match '\$Global:DESKTOPGROUP'
            $content | Should -Match 'foreach \(\$desktopgroup in \$DesktopGroup\)'
        }
    }
}

Describe "citrix_reboot_check.ps1 - Funktionen" {

    Context "Write-EventLogSafe Funktion" {

        BeforeAll {
            # Skript dot-sourcen: lädt nur die Funktionen, Hauptprogramm läuft nicht
            . $scriptPath -DesktopGroup 'DG-Test'
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

    Context "Funktionsstruktur" {

        BeforeAll {
            . $scriptPath -DesktopGroup 'DG-Test'
        }

        It "Definiert Funktion <_>" -ForEach @(
            'Initialize-CitrixEnvironment'
            'Initialize-EventLog'
            'Start-OfflineMachine'
            'Write-MachineRunning'
            'Invoke-CitrixRebootCheck'
        ) {
            Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Verwendet keine ScriptBlocks und kein Invoke-Command mehr" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Not -Match '\$FinalCheck(Down|OK)'
            $content | Should -Not -Match 'Invoke-Command'
        }

        It "Verwendet keine globalen Variablen" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Not -Match '\$Global:'
        }

        It "Start-OfflineMachine enthält Null-Check" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\[string\]::IsNullOrWhiteSpace'
        }

        It "Start-OfflineMachine ruft New-BrokerHostingPowerAction auf" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'New-BrokerHostingPowerAction.*-Action TurnOn'
        }

        It "Hauptprogramm wird beim Dot-Sourcing übersprungen" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "if \(\`$MyInvocation\.InvocationName -ne '\.'\)"
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
            $content | Should -Match '\[string\]::IsNullOrWhiteSpace\(\$MachineName\)'
        }
    }

    Context "Exit Codes" {

        It "Verwendet exit 1 bei Fehlern" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'exit 1'
        }

        It "Liefert 0 bei Erfolg und reicht den Code an exit weiter" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'return 0'
            $content | Should -Match 'exit \(Invoke-CitrixRebootCheck'
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

        It "Start-OfflineMachine liefert Erfolg/Misserfolg zurück" {
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

Describe "citrix_reboot_check.ps1 - Verhalten (Mock-Tests)" {

    BeforeAll {
        # Skript dot-sourcen: lädt nur die Funktionen, Hauptprogramm läuft nicht
        . $scriptPath -DesktopGroup 'DG-Test'

        # Platzhalter für Citrix-Cmdlets, damit Pester sie mocken kann
        function Get-BrokerDesktop { param($DesktopGroupName) }
        function New-BrokerHostingPowerAction { param($MachineName, $Action) }

        function New-TestMachine {
            param([string]$Name, [string]$PowerState, [bool]$Maintenance = $false)
            [PSCustomObject]@{ MachineName = $Name; PowerState = $PowerState; InMaintenanceMode = $Maintenance }
        }
    }

    Context "Write-EventLogSafe" {

        AfterEach {
            $script:EventLog = $null
        }

        It "Schreibt Meldung, Typ und Event ID ins Event Log" {
            $script:written = [System.Collections.Generic.List[object]]::new()
            $script:EventLog = [PSCustomObject]@{} | Add-Member -MemberType ScriptMethod -Name WriteEntry -Value {
                param($Message, $EntryType, $EventId)
                $script:written.Add([PSCustomObject]@{ Message = $Message; EntryType = $EntryType; EventId = $EventId })
            } -PassThru

            Write-EventLogSafe -Message "Test" -EntryType "Warning" -EventId 120

            $script:written.Count | Should -Be 1
            $script:written[0].Message | Should -Be "Test"
            $script:written[0].EntryType | Should -Be "Warning"
            $script:written[0].EventId | Should -Be 120
        }

        It "Wirft nicht, wenn kein Event Log verfügbar ist" {
            $script:EventLog = $null
            { Write-EventLogSafe -Message "Test" } | Should -Not -Throw
        }

        It "Gibt bei Schreibfehler eine Warnung aus statt abzubrechen" {
            $script:EventLog = [PSCustomObject]@{} | Add-Member -MemberType ScriptMethod -Name WriteEntry -Value {
                throw "Zugriff verweigert"
            } -PassThru

            Write-EventLogSafe -Message "Test" -WarningVariable warn -WarningAction SilentlyContinue
            $warn | Should -Match "Event Log Schreibfehler"
        }
    }

    Context "Initialize-CitrixEnvironment" {

        It "Liefert `$true, wenn Snap-ins und Cmdlets verfügbar sind" {
            Mock Add-PSSnapin { }
            Initialize-CitrixEnvironment | Should -BeTrue
        }

        It "Liefert `$false, wenn die Snap-ins nicht geladen werden können" {
            Mock Add-PSSnapin { throw "Snap-in nicht gefunden" }
            Initialize-CitrixEnvironment -ErrorAction SilentlyContinue | Should -BeFalse
        }

        It "Liefert `$false, wenn ein benötigtes Cmdlet fehlt" {
            Mock Add-PSSnapin { }
            # Standard-Mock nötig: Pester 6 fällt bei nicht passendem Filter nicht mehr auf das echte Cmdlet zurück
            Mock Get-Command { [PSCustomObject]@{ Name = $Name } }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'New-BrokerHostingPowerAction' }
            Initialize-CitrixEnvironment -ErrorAction SilentlyContinue | Should -BeFalse
        }
    }

    Context "Initialize-EventLog" {

        AfterEach {
            $script:EventLog = $null
        }

        It "Setzt die Quelle und schreibt Event 111" {
            $script:written = [System.Collections.Generic.List[object]]::new()
            Mock New-Object {
                [PSCustomObject]@{ Source = $null } | Add-Member -MemberType ScriptMethod -Name WriteEntry -Value {
                    param($Message, $EntryType, $EventId)
                    $script:written.Add([PSCustomObject]@{ Message = $Message; EventId = $EventId })
                } -PassThru
            } -ParameterFilter { $TypeName -eq 'System.Diagnostics.EventLog' }

            Initialize-EventLog

            $script:EventLog.Source | Should -Be "Citrix Reboot Check Script"
            $script:written.Count | Should -Be 1
            $script:written[0].EventId | Should -Be 111
        }

        It "Läuft ohne Event Log weiter, wenn die Initialisierung fehlschlägt" {
            Mock New-Object { throw "Quelle nicht registriert" } -ParameterFilter { $TypeName -eq 'System.Diagnostics.EventLog' }

            { Initialize-EventLog -WarningAction SilentlyContinue } | Should -Not -Throw
            Initialize-EventLog -WarningVariable warn -WarningAction SilentlyContinue
            $warn | Should -Match "Event Log konnte nicht initialisiert werden"
            $script:EventLog | Should -BeNullOrEmpty
        }
    }

    Context "Start-OfflineMachine" {

        BeforeEach {
            Mock Write-EventLogSafe { }
        }

        It "Startet die Maschine und liefert `$true" {
            Mock New-BrokerHostingPowerAction { [PSCustomObject]@{ Uid = 1 } }

            $result = Start-OfflineMachine -MachineName 'VDA01'

            $result | Should -BeExactly $true
            Should -Invoke New-BrokerHostingPowerAction -Times 1 -Exactly -ParameterFilter {
                $MachineName -eq 'VDA01' -and $Action -eq 'TurnOn'
            }
            Should -Invoke Write-EventLogSafe -Times 1 -Exactly -ParameterFilter { $EventId -eq 124 }
        }

        It "Liefert `$false und loggt Event 125, wenn der Start fehlschlägt" {
            Mock New-BrokerHostingPowerAction { throw "Hypervisor nicht erreichbar" }

            $result = Start-OfflineMachine -MachineName 'VDA01' -ErrorAction SilentlyContinue

            $result | Should -BeExactly $false
            Should -Invoke Write-EventLogSafe -Times 1 -Exactly -ParameterFilter {
                $EventId -eq 125 -and $EntryType -eq 'Error' -and $Message -match 'Hypervisor nicht erreichbar'
            }
        }

        It "Liefert `$false ohne Startversuch bei leerem Maschinennamen" {
            Mock New-BrokerHostingPowerAction { }

            Start-OfflineMachine -MachineName ' ' -WarningAction SilentlyContinue | Should -BeExactly $false
            Should -Invoke New-BrokerHostingPowerAction -Times 0 -Exactly
        }
    }

    Context "Write-MachineRunning" {

        It "Loggt Event 123 für eine laufende Maschine" {
            Mock Write-EventLogSafe { }

            Write-MachineRunning -MachineName 'VDA01'

            Should -Invoke Write-EventLogSafe -Times 1 -Exactly -ParameterFilter {
                $EventId -eq 123 -and $Message -match 'VDA01'
            }
        }

        It "Loggt nichts bei leerem Maschinennamen" {
            Mock Write-EventLogSafe { }

            Write-MachineRunning -MachineName '' -WarningAction SilentlyContinue

            Should -Invoke Write-EventLogSafe -Times 0 -Exactly
        }
    }

    Context "Invoke-CitrixRebootCheck" {

        BeforeEach {
            Mock Write-EventLogSafe { }
            Mock New-BrokerHostingPowerAction { }
            Mock Get-BrokerDesktop {
                New-TestMachine 'VDA-On'          'On'
                New-TestMachine 'VDA-Off'         'Off'
                New-TestMachine 'VDA-TurningOff'  'TurningOff'
                New-TestMachine 'VDA-Maintenance' 'Off' $true
            } -ParameterFilter { $DesktopGroupName -eq 'DG-A' }
            Mock Get-BrokerDesktop { } -ParameterFilter { $DesktopGroupName -eq 'DG-Leer' }
            Mock Get-BrokerDesktop { throw "Gruppe nicht gefunden" } -ParameterFilter { $DesktopGroupName -eq 'DG-Fehler' }
        }

        It "Startet nur offline Maschinen außerhalb des Wartungsmodus und liefert 0" {
            $result = Invoke-CitrixRebootCheck -DesktopGroup 'DG-A'

            $result | Should -Be 0
            Should -Invoke New-BrokerHostingPowerAction -Times 2 -Exactly
            Should -Invoke New-BrokerHostingPowerAction -Times 1 -Exactly -ParameterFilter { $MachineName -eq 'VDA-Off' }
            Should -Invoke New-BrokerHostingPowerAction -Times 1 -Exactly -ParameterFilter { $MachineName -eq 'VDA-TurningOff' }
            Should -Invoke New-BrokerHostingPowerAction -Times 0 -Exactly -ParameterFilter { $MachineName -in 'VDA-On', 'VDA-Maintenance' }
        }

        It "Loggt laufende Maschinen mit Event 123" {
            Invoke-CitrixRebootCheck -DesktopGroup 'DG-A' | Out-Null

            Should -Invoke Write-EventLogSafe -Times 1 -Exactly -ParameterFilter { $EventId -eq 123 -and $Message -match 'VDA-On' }
        }

        It "Schreibt Summary (Event 112) mit korrekten Zahlen" {
            Invoke-CitrixRebootCheck -DesktopGroup 'DG-A' | Out-Null

            Should -Invoke Write-EventLogSafe -Times 1 -Exactly -ParameterFilter {
                $EventId -eq 112 -and
                $Message -match 'Gesamt-Maschinen geprüft: 3' -and
                $Message -match 'Online: 1' -and
                $Message -match 'Offline \(Start initiiert\): 2' -and
                $Message -match 'Erfolgreich gestartet: 2' -and
                $Message -match 'Fehler: 0'
            }
        }

        It "Liefert 1, wenn ein Start fehlschlägt, und startet die übrigen Maschinen trotzdem" {
            Mock New-BrokerHostingPowerAction { throw "Hypervisor nicht erreichbar" } -ParameterFilter { $MachineName -eq 'VDA-Off' }

            $result = Invoke-CitrixRebootCheck -DesktopGroup 'DG-A' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            $result | Should -Be 1
            Should -Invoke New-BrokerHostingPowerAction -Times 1 -Exactly -ParameterFilter { $MachineName -eq 'VDA-TurningOff' }
            Should -Invoke Write-EventLogSafe -Times 1 -Exactly -ParameterFilter {
                $EventId -eq 112 -and $Message -match 'Erfolgreich gestartet: 1' -and $Message -match 'Fehler: 1'
            }
        }

        It "Loggt Event 126 bei Abfragefehler, liefert 1 und prüft die nächste Gruppe weiter" {
            $result = Invoke-CitrixRebootCheck -DesktopGroup 'DG-Fehler', 'DG-A' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            $result | Should -Be 1
            Should -Invoke Write-EventLogSafe -Times 1 -Exactly -ParameterFilter { $EventId -eq 126 -and $Message -match 'DG-Fehler' }
            Should -Invoke New-BrokerHostingPowerAction -Times 2 -Exactly
        }

        It "Warnt mit Event 120 bei leerer Gruppe und liefert 0" {
            $result = Invoke-CitrixRebootCheck -DesktopGroup 'DG-Leer' -WarningAction SilentlyContinue

            $result | Should -Be 0
            Should -Invoke Write-EventLogSafe -Times 1 -Exactly -ParameterFilter { $EventId -eq 120 -and $EntryType -eq 'Warning' }
            Should -Invoke New-BrokerHostingPowerAction -Times 0 -Exactly
        }

        It "Liefert genau einen Rückgabewert (keine Ausgabe-Verschmutzung)" {
            $result = @(Invoke-CitrixRebootCheck -DesktopGroup 'DG-A')

            $result.Count | Should -Be 1
            $result[0] | Should -BeOfType [int]
        }
    }
}
