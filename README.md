# Citrix CVAD Reboot Check

PowerShell script for **Citrix Virtual Apps and Desktops (CVAD / XenDesktop)** that checks
Delivery Groups for offline VDA machines and powers them on automatically — typically run as a
scheduled task on the Delivery Controller after the nightly reboot window.

Every action is logged to the Windows **Application** event log (source
`Citrix Reboot Check Script`, event IDs 111–126), so it can be picked up by your monitoring.

## Example output

Run with `-Verbose` (example with one configured Delivery Group, placeholder machine names):

```text
VERBOSE: Citrix Reboot Check Script v2.1.0 wird gestartet...
VERBOSE: Citrix Snap-ins erfolgreich geladen
VERBOSE: Verarbeite Desktop-Gruppe: DG-Example
VERBOSE: Gefundene Maschinen in DG-Example: 3
VERBOSE: Host: VDA01 is running.
VERBOSE: Host VDA02 is Offline. Start will be initiated!
VERBOSE: Power-On Aktion erfolgreich für VDA02
VERBOSE: Host: VDA03 is running.
VERBOSE: Citrix Reboot Check Script v2.1.0 abgeschlossen.
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

# 2. Set your Delivery Groups in citrix_reboot_check.ps1
#    $Global:DESKTOPGROUP = @("DG-Example1","DG-Example2")

# 3. Test run
.\citrix_reboot_check.ps1 -Verbose

# 4. Schedule it (adjust time to your reboot schedule)
$cred = Get-Credential   # account with Citrix admin rights
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\citrix_reboot_check.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At 05:30
Register-ScheduledTask -TaskName "Citrix Reboot Check" -Action $action -Trigger $trigger `
    -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Highest
```

> Detailed documentation is in German.

License: [MIT](LICENSE)

---

## Citrix Reboot Check Script (Deutsch)

Überwacht Citrix Desktop Delivery Groups und startet automatisch offline Maschinen.

**Version:** 2.1.0

## Übersicht

Dieses Repository enthält ein PowerShell-Skript, das Citrix Desktop Delivery Groups überwacht und automatisch Maschinen einschaltet, die offline sind. Das Skript läuft als geplante Aufgabe und protokolliert alle Aktionen im Windows-Anwendungsereignisprotokoll.

## Funktionen

- Überwacht spezifische Citrix Desktop Delivery Groups (DG-TS2019, DG-TS2016-Sage)
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
.\citrix_reboot_check.ps1

# Mit detaillierter Ausgabe (empfohlen für Debugging)
.\citrix_reboot_check.ps1 -Verbose
```

## Konfiguration

Zu überwachende Desktop-Gruppen sind in `$Global:DESKTOPGROUP` bei `citrix_reboot_check.ps1:51` definiert:

```powershell
$Global:DESKTOPGROUP = @("DG-TS2019","DG-TS2016-Sage")
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

Das Skript verwendet ein sequentielles Verarbeitungsmodell:

1. **Initialisierung**: Lädt Citrix Snap-ins und bereitet Ereignisprotokoll-Quelle vor
2. **Desktop Group Iteration**: Verarbeitet jede konfigurierte Desktop-Gruppe nacheinander
3. **Maschinenzustandsprüfung**: Fragt Maschinen ab, die nicht im Wartungsmodus sind
4. **Betriebszustandsbehandlung**:
   - `$FinalCheckDown`: Wird für Offline-Maschinen aufgerufen, löst Einschaltaktion aus
   - `$FinalCheckOK`: Wird für laufende Maschinen aufgerufen, protokolliert Status

## Tests

Das Projekt verwendet [Pester](https://pester.dev/) für Unit-Tests.

### Pester installieren

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck
```

### Tests ausführen

```powershell
# Alle Tests ausführen
Invoke-Pester

# Tests mit detaillierter Ausgabe
Invoke-Pester -Output Detailed

# Code Coverage Report erstellen
Invoke-Pester -CodeCoverage .\citrix_reboot_check.ps1
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

## Versionierung

Das Projekt folgt [Semantic Versioning](https://semver.org/lang/de/) (MAJOR.MINOR.PATCH).

Siehe [CHANGELOG.md](CHANGELOG.md) für die vollständige Versionshistorie.

## Lizenz

MIT – siehe [LICENSE](LICENSE). © ACP IT Solutions AG
