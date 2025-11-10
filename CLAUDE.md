# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Sprache

**Alle Kommentare, Commit-Nachrichten und Dokumentation in diesem Repository müssen auf Deutsch verfasst werden.**

## Übersicht

Dieses Repository enthält ein einzelnes PowerShell-Skript, das Citrix Desktop Delivery Groups überwacht und automatisch Maschinen einschaltet, die offline sind. Das Skript läuft als geplante Aufgabe und protokolliert alle Aktionen im Windows-Anwendungsereignisprotokoll.

## Zweck des Skripts

Das `citrix_reboot_check.ps1` Skript:
- Überwacht spezifische Citrix Desktop Delivery Groups (DG-TS2019, DG-TS2016-Sage)
- Prüft den Betriebszustand aller Maschinen, die sich nicht im Wartungsmodus befinden
- Initiiert automatisch eine Einschaltaktion für Maschinen, die offline sind
- Protokolliert alle Aktivitäten im Windows-Ereignisprotokoll unter der Quelle "Citrix Reboot Check Script"

## Voraussetzungen

- Citrix PowerShell Snap-ins müssen installiert sein
- Skript muss mit entsprechenden Citrix-Administratorrechten ausgeführt werden
- Ereignisprotokoll-Quelle "Citrix Reboot Check Script" muss registriert sein

## Skript ausführen

```powershell
# Skript direkt ausführen
.\citrix_reboot_check.ps1

# Mit detaillierter Ausgabe (empfohlen für Debugging)
.\citrix_reboot_check.ps1 -Verbose
```

## Exit Codes

- `0`: Erfolgreiche Ausführung ohne Fehler
- `1`: Fehler während der Ausführung (Details siehe Event Log oder Fehlerausgabe)

## Architektur

Das Skript verwendet ein einfaches sequentielles Verarbeitungsmodell:

1. **Initialisierung**: Lädt Citrix Snap-ins und bereitet Ereignisprotokoll-Quelle vor
2. **Desktop Group Iteration**: Verarbeitet jede konfigurierte Desktop-Gruppe nacheinander
3. **Maschinenzustandsprüfung**: Fragt Maschinen ab, die nicht im Wartungsmodus sind, sortiert nach Namen
4. **Betriebszustandsbehandlung**: Verwendet Script-Blöcke zur Behandlung von Offline/Online-Zuständen
   - `$FinalCheckDown`: Wird für Offline-Maschinen aufgerufen, löst Einschaltaktion aus
   - `$FinalCheckOK`: Wird für laufende Maschinen aufgerufen, protokolliert Status

## Wichtige Konfiguration

- Zu überwachende Desktop-Gruppen sind in `$Global:DESKTOPGROUP` bei citrix_reboot_check.ps1:21 definiert
- Verwendete Event-IDs:
  - 111: Skript gestartet
  - 112: Skript beendet (mit Summary)
  - 120: Warnung - Keine Maschinen gefunden
  - 123: Maschine läuft
  - 124: Maschine offline, Start initiiert
  - 125: Fehler beim Starten einer Maschine
  - 126: Fehler beim Abfragen einer Desktop-Gruppe

## Fehlerbehandlung

Das Skript verfügt über umfassende Fehlerbehandlung:
- Validierung der Citrix Snap-ins beim Start
- Try-Catch Blöcke für alle kritischen Operationen
- Fehlertolerante Event Log Operationen
- Detaillierte Fehlerprotokollierung
- Exit Codes zur Statusübermittlung an Scheduler

## Verwendete Citrix Cmdlets

- `Get-BrokerDesktop`: Ruft Maschineninformationen aus Desktop-Gruppen ab
- `New-BrokerHostingPowerAction`: Initiiert Einschaltaktionen für Maschinen
