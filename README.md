# Citrix CVAD Reboot Check

[![Tests](https://github.com/feiglein74/Citrix_CVAD-Reboot-Check/actions/workflows/tests.yml/badge.svg)](https://github.com/feiglein74/Citrix_CVAD-Reboot-Check/actions/workflows/tests.yml)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Citrix%20Delivery%20Controller%20%28Windows%29-0078D6)
[![License](https://img.shields.io/github/license/feiglein74/Citrix_CVAD-Reboot-Check)](LICENSE)

PowerShell script for **Citrix Virtual Apps and Desktops (CVAD / XenDesktop)** that checks
Delivery Groups for offline VDA machines and powers them on automatically — typically run as a
scheduled task on the Delivery Controller after the nightly reboot window.

Every action is logged to the Windows **Application** event log (source
`Citrix Reboot Check Script`, event IDs 111–126), so it can be picked up by your monitoring.

## Example output

Run with `-Verbose` (example with one configured Delivery Group, placeholder machine names):

```text
VERBOSE: Citrix Reboot Check Script v3.1.1 wird gestartet...
VERBOSE: Citrix Snap-ins erfolgreich geladen
VERBOSE: Verarbeite Desktop-Gruppe: DG-Example
VERBOSE: Gefundene Maschinen in DG-Example: 3
VERBOSE: Host: VDA01 is running.
VERBOSE: Host VDA02 is Offline. Start will be initiated!
VERBOSE: Power-On Aktion erfolgreich für VDA02
VERBOSE: Host: VDA03 is running.
VERBOSE: Citrix Reboot Check Script v3.1.1 abgeschlossen.
Geprüfte Desktop-Gruppen: 1
Gesamt-Maschinen geprüft: 3
  - Online: 2
  - Offline (Start initiiert): 1
  - Erfolgreich gestartet: 1
  - Fehler: 0
```

Machines in maintenance mode are skipped. Exit code is `0` on success and `1` if any group
query or power-on action failed.

## Quickstart

Requirements: PowerShell 5.1, Citrix Broker PowerShell snap-ins (e.g. on a Delivery Controller),
an account with Citrix admin rights.

```powershell
# 1. Register the event log source once (elevated)
New-EventLog -LogName Application -Source "Citrix Reboot Check Script"

# 2. Test run with your Delivery Groups
.\citrix_reboot_check.ps1 -DesktopGroup "DG-Example1","DG-Example2" -Verbose

# 3. Schedule it (adjust time to your reboot schedule)
#    -Command instead of -File, because -File cannot pass string arrays
$cred = Get-Credential   # account with Citrix admin rights
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& ''C:\Scripts\citrix_reboot_check.ps1'' -DesktopGroup ''DG-Example1'',''DG-Example2''; exit $LASTEXITCODE"'
$trigger = New-ScheduledTaskTrigger -Daily -At 05:30
Register-ScheduledTask -TaskName "Citrix Reboot Check" -Action $action -Trigger $trigger `
    -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Highest
```

> Detailed documentation is in German.

License: [MIT](LICENSE)

---

## Citrix Reboot Check Script (Deutsch)

Überwacht Citrix Desktop Delivery Groups und startet automatisch offline Maschinen.

**Version:** 3.1.1

## Übersicht

Dieses Repository enthält ein PowerShell-Skript, das Citrix Desktop Delivery Groups überwacht und automatisch Maschinen einschaltet, die offline sind. Das Skript läuft als geplante Aufgabe und protokolliert alle Aktionen im Windows-Anwendungsereignisprotokoll.

## Funktionen

- Überwacht die per `-DesktopGroup` übergebenen Citrix Desktop Delivery Groups
- Prüft den Betriebszustand aller Maschinen, die sich nicht im Wartungsmodus befinden
- Initiiert automatisch eine Einschaltaktion für Maschinen, die offline sind
- Protokolliert alle Aktivitäten im Windows-Ereignisprotokoll unter der Quelle "Citrix Reboot Check Script"

## Voraussetzungen

- PowerShell 5.1 oder höher
- Citrix PowerShell Snap-ins müssen installiert sein
- Skript muss mit entsprechenden Citrix-Administratorrechten ausgeführt werden
- Ereignisprotokoll-Quelle "Citrix Reboot Check Script" muss registriert sein

## Installation

1. Repository klonen oder Skript herunterladen
2. Ereignisprotokoll-Quelle registrieren (als Administrator):
   ```powershell
   New-EventLog -LogName Application -Source "Citrix Reboot Check Script"
   ```

## Verwendung

```powershell
# Skript direkt ausführen
.\citrix_reboot_check.ps1 -DesktopGroup "DG-Example1","DG-Example2"

# Mit detaillierter Ausgabe (empfohlen für Debugging)
.\citrix_reboot_check.ps1 -DesktopGroup "DG-Example1","DG-Example2" -Verbose
```

## Konfiguration

Die zu überwachenden Desktop-Gruppen werden über den Pflichtparameter `-DesktopGroup` übergeben.
In der geplanten Aufgabe `-Command` statt `-File` verwenden, da `-File` keine String-Arrays übergeben kann:

```text
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& 'C:\Scripts\citrix_reboot_check.ps1' -DesktopGroup 'DG-Example1','DG-Example2'; exit $LASTEXITCODE"
```

## Event-IDs

| Event-ID | Typ | Beschreibung |
|----------|-----|--------------|
| 111 | Information | Skript gestartet |
| 112 | Information | Skript beendet (mit Summary) |
| 120 | Warnung | Keine Maschinen gefunden |
| 123 | Information | Maschine läuft |
| 124 | Information | Maschine offline, Start initiiert |
| 125 | Fehler | Fehler beim Starten einer Maschine |
| 126 | Fehler | Fehler beim Abfragen einer Desktop-Gruppe |

## Exit Codes

| Code | Bedeutung |
|------|-----------|
| 0 | Erfolgreiche Ausführung ohne Fehler |
| 1 | Fehler während der Ausführung |

## Architektur

Das Skript besteht aus Funktionen und einem kurzen Hauptprogramm:

| Funktion | Aufgabe |
|----------|---------|
| `Initialize-CitrixEnvironment` | Lädt Citrix Snap-ins und prüft die benötigten Cmdlets |
| `Initialize-EventLog` | Bereitet das Event Log vor und schreibt Event 111 |
| `Write-EventLogSafe` | Schreibt ins Event Log (falls verfügbar) und nach Verbose |
| `Invoke-CitrixRebootCheck` | Prüft alle Desktop-Gruppen (ohne Wartungsmodus), zählt Statistik, liefert Exit Code |
| `Start-OfflineMachine` | Startet eine offline Maschine, liefert `$true`/`$false` |
| `Write-MachineRunning` | Protokolliert eine laufende Maschine |

Das Hauptprogramm am Ende läuft nur bei direktem Aufruf. Beim Dot-Sourcing
(`. .\citrix_reboot_check.ps1 -DesktopGroup x`, z.B. in Tests) werden nur die Funktionen geladen.

Die Skriptdatei ist als UTF-8 **mit BOM** gespeichert, damit Windows PowerShell 5.1 die Umlaute korrekt liest.

## Tests

Das Projekt verwendet [Pester](https://pester.dev/) 5 oder 6 für Unit-Tests (75 Tests, ca. 92 % Code Coverage).
Neben statischen Prüfungen des Skripttexts gibt es Verhaltenstests: Das Skript wird per Dot-Sourcing
geladen, die Citrix-Cmdlets (`Get-BrokerDesktop`, `New-BrokerHostingPowerAction`) und das Event Log
werden gemockt. Eine Citrix-Umgebung ist für die Tests nicht nötig. Die Tests laufen unter
Windows PowerShell 5.1 und PowerShell 7, bei jedem Push automatisch per GitHub Actions
(`.github/workflows/tests.yml`).

### Pester installieren

```powershell
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
```

Windows PowerShell 5.1 bringt Pester 3.4 mit. Falls Version 3.4 geladen wird, vorher
`Import-Module Pester -MinimumVersion 5.0` ausführen.

### Tests ausführen

```powershell
# Alle Tests ausführen
Invoke-Pester

# Tests mit detaillierter Ausgabe
Invoke-Pester -Output Detailed

# Code Coverage Report erstellen
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = '.\citrix_reboot_check.ps1'
Invoke-Pester -Configuration $config
```

## Fehlerbehandlung

Das Skript verfügt über umfassende Fehlerbehandlung:

- Validierung der Citrix Snap-ins beim Start
- Try-Catch Blöcke für alle kritischen Operationen
- Fehlertolerante Event Log Operationen
- Detaillierte Fehlerprotokollierung
- Exit Codes zur Statusübermittlung an Scheduler

## Verwendete Citrix Cmdlets

| Cmdlet | Beschreibung |
|--------|--------------|
| `Get-BrokerDesktop` | Ruft Maschineninformationen aus Desktop-Gruppen ab |
| `New-BrokerHostingPowerAction` | Initiiert Einschaltaktionen für Maschinen |

## Design-Prinzipien

Leitlinien und bewusste Entscheidungen (z.B. Wartungsmodus, Event-IDs, Exit Codes, UTF-8 mit BOM)
stehen in [DESIGN-PRINCIPLES.md](DESIGN-PRINCIPLES.md).

## Versionierung

Das Projekt folgt [Semantic Versioning](https://semver.org/lang/de/) (MAJOR.MINOR.PATCH).

Siehe [CHANGELOG.md](CHANGELOG.md) für die vollständige Versionshistorie.

## Lizenz

MIT – siehe [LICENSE](LICENSE). © Sascha Feig
