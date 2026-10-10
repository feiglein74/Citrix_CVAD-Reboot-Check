# Änderungsprotokoll

Alle nennenswerten Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [3.0.0] - 2026-10-10

### Geändert (Breaking)
- Desktop-Gruppen werden über den Pflichtparameter `-DesktopGroup` übergeben statt fest im Skript
  (`$Global:DESKTOPGROUP` entfällt). Bestehende geplante Aufgaben müssen den Parameter ergänzen.

### Dokumentation
- README: Aufruf mit `-DesktopGroup`, geplante Aufgabe mit `-Command` (String-Array-Übergabe)

## [2.1.0] - 2026-10-10

### Behoben
- `machinesStarted` wurde auch bei fehlgeschlagenem Start hochgezählt. `FinalStart` liefert jetzt
  `$true`/`$false` zurück; fehlgeschlagene Starts werden als Fehler gezählt und führen zu Exit Code 1
- Ausgabe von `New-BrokerHostingPowerAction` wird unterdrückt, damit sie das Ergebnis nicht verfälscht

### Geändert
- PowerState-Vergleich exakt (`-in @('Off', 'TurningOff')`) statt `-match "Off"`
- Event IDs als `[int]` statt als String
- `$null`-Vergleich auf die linke Seite verschoben (PowerShell Best Practice)

### Dokumentation
- MIT-Lizenz (LICENSE) hinzugefügt
- Englischer README-Kopf mit Beispielausgabe und Quickstart (inkl. geplanter Aufgabe)

### Tests
- Event-ID-Tests an Integer-Format angepasst
- Neue Tests für PowerState-Vergleich, `$null`-Vergleich und Start-Ergebnis

## [2.0.0] - 2025-11-10

### Hinzugefügt

#### Versionierung
- Skript-Version 2.0.0 im Header-Kommentar
- Version in allen Event Log Meldungen
- PowerShell Comment-Based Help mit vollständiger Dokumentation
- `#Requires -Version 5.1` für Mindestanforderung
- `[CmdletBinding()]` für erweiterte Funktionalität

#### Umfassende Fehlerbehandlung
- Try-Catch Blöcke für alle kritischen Operationen
- Validierung der Citrix Snap-ins beim Start
- Überprüfung ob benötigte Cmdlets verfügbar sind
- Fehlerbehandlung bei Event Log Operationen

#### Neue Hilfsfunktion: Write-EventLogSafe
- Sichere Event Log Schreiboperationen
- Fallback zu Write-Verbose wenn Event Log nicht verfügbar
- Fehlerbehandlung für Event Log Schreibfehler

#### Eingabevalidierung
- Null/Leerstring-Checks für Maschinennamen
- Validierung der Desktop-Gruppen
- Warnung bei leeren Desktop-Gruppen

#### Detaillierte Statistiken und Reporting
- Zählung geprüfter Maschinen
- Tracking von Online/Offline Status
- Fehlererfassung
- Summary-Log am Ende der Ausführung

#### Verbesserte Event IDs
- 111: Skript gestartet
- 112: Skript beendet (mit Summary)
- 120: Warnung - Keine Maschinen gefunden
- 123: Maschine läuft
- 124: Maschine offline, Start initiiert
- 125: Fehler beim Starten einer Maschine
- 126: Fehler beim Abfragen einer Desktop-Gruppe

#### Exit Codes
- Exit 0: Erfolgreiche Ausführung ohne Fehler
- Exit 1: Fehler während der Ausführung

#### Pester Tests
- Umfassende Unit-Tests für alle Skript-Komponenten
- Tests für Fehlerbehandlung, Event IDs, Statistiken
- Code-Struktur und Best-Practice Tests
- 7 Test-Suites mit über 40 Tests

### Behoben

- Grammatikfehler in Event Log Meldungen: "Host X is Offline" statt "Host Xis Offline"
- Ungenutzte Variable `$i` entfernt
- Redundante EventLog-Initialisierungen eliminiert
- Fehlende Fehlerbehandlung: Alle Citrix-Cmdlets verwenden jetzt -ErrorAction Stop mit Try-Catch
- Bessere Boolean-Vergleiche: `-eq $false` statt `-Match "False"`

### Geändert

- Logging-Strategie verbessert:
  - Alle kritischen Aktionen werden geloggt
  - Fehler werden sowohl in Event Log als auch via Write-Error ausgegeben
  - Verbose-Ausgaben für Debugging (mit -Verbose Parameter)
  - Summary am Ende mit Gesamtstatistik

## [1.0.0] - 2024-11-28

### Hinzugefügt

- Initiale Version des Citrix Reboot Check Scripts
- Überwachung von Desktop-Gruppen: DG-Example1, DG-Example2
- Automatisches Einschalten von offline Maschinen
- Event Log Integration
- Event IDs: 111 (Start), 123 (Maschine läuft), 124 (Maschine offline)
