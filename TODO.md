# TODO - Verbesserungen für Citrix-RebootCheck

Dokumentiert am: 2026-01-21
Aktuelle Version: 3.1.1
Gesamtbewertung: 7/10

---

## Regel-Verstöße (defaults.md v1.1.0)

### Fehlende Dateien

- [x] **.gitignore erstellen** ✅
  - Erledigt: 2026-01-21

- [x] **.gitattributes erstellen** ✅
  - Erledigt: 2026-01-21

- [x] **LICENSE erstellen** ✅
  - Erledigt: 2026-10-10 (MIT)

- [x] **DESIGN-PRINCIPLES.md erstellen** ✅
  - Erledigt: 2026-10-10
  - Soll enthalten: Leitprinzipien, Design-Entscheidungen, Merksätze

### Sprach-Verstöße

- [x] ~~**Log-Meldungen auf Deutsch umstellen**~~ – verworfen (2026-10-10): Event-Log-Meldungen bleiben bewusst auf Englisch
  - Aktuell (Englisch):
    - `"Host $machineName is Offline. Start will be initiated!"`
    - `"Host: $machineName is running."`
    - `"Starting scheduled task Citrix Post-Reboot Check Script"`
  - Soll (Deutsch):
    - `"Host $machineName ist offline. Start wird initiiert!"`
    - `"Host: $machineName läuft."`
    - `"Starte geplante Aufgabe Citrix Post-Reboot Check Script"`

### Aufräumen

- [x] **citrix_reboot_check.ps1.zip entfernen oder in .gitignore** ✅ (Datei nicht mehr vorhanden, `*.zip` in .gitignore)
  - Build-Artefakte gehören nicht ins Repository
  - Entweder löschen oder via .gitignore ausschließen

---

## Code-Verbesserungen

### Priorität 1 - Niedrig (Quick Wins)

- [x] **PowerState-Vergleich korrigieren** ✅ (2.1.0) (Zeile 166)
  - Aktuell: `-match "Off"` ist fragil
  - Besser: `-eq 'Off' -or -eq 'TurningOff'` für exakten Vergleich
  - Risiko: Ungewollte Matches bei ähnlichen Zuständen

- [x] **$null-Vergleich umdrehen** ✅ (2.1.0) (Zeile 72)
  - Aktuell: `$Global:EventLog -ne $null`
  - Besser: `$null -ne $Global:EventLog`
  - Grund: PowerShell Best Practice für $null-Vergleiche

- [x] **Event ID Datentyp ändern** ✅ (2.1.0) (Zeile 69)
  - Aktuell: `[string]$EventId = "100"`
  - Besser: `[int]$EventId = 100`
  - Grund: Event IDs sind numerisch

---

### Priorität 2 - Mittel (Strukturelle Verbesserungen)

- [x] **machinesStarted Logik korrigieren** ✅ (2.1.0) (Zeilen 168-176)
  - Problem: Zähler wird erhöht, obwohl interner Fehler im ScriptBlock auftreten kann
  - Lösung: Rückgabewert aus ScriptBlock auswerten oder Exception weiterleiten
  - Code-Stelle:
    ```powershell
    try {
        Invoke-Command -ScriptBlock $FinalCheckDown -ArgumentList $member.MachineName
        $machinesStarted++  # Wird auch bei internem Fehler erhöht!
    }
    ```

- [x] **ScriptBlocks durch reguläre Funktionen ersetzen** ✅ (3.1.0)
  - Aktuell: Verschachtelte Funktionen in ScriptBlocks
  - Besser: Direkte Funktionen mit CmdletBinding
  - Vorteile: Bessere Testbarkeit, klarere Struktur
  - Beispiel:
    ```powershell
    function Start-OfflineMachine {
        [CmdletBinding()]
        param([string]$MachineName)
        # Logik hier
    }
    ```

- [x] **Globale Variablen entfernen** ✅ (3.0.0 Parameter, 3.1.0 `$script:EventLog`)
  - Betrifft: `$Global:EventLog`, `$Global:DESKTOPGROUP`
  - Besser: `$script:` Scope oder Parameter
  - Grund: Vermeidung von Scope-Verschmutzung

- [x] **Invoke-Command Overhead entfernen** ✅ (3.1.0)
  - Aktuell: `Invoke-Command -ScriptBlock $FinalCheckDown`
  - Besser: `& $FinalCheckDown` oder direkte Funktionsaufrufe
  - Grund: Invoke-Command für lokale ScriptBlocks ist unnötig

- [x] **Externe Konfigurationsdatei einführen** ✅ (3.0.0 als Parameter `-DesktopGroup`, keine Config-Datei)
  - Aktuell: Desktop-Gruppen hardcoded im Skript
  - Besser: JSON/PSD1 Konfigurationsdatei oder Parameter
  - Beispiel:
    ```powershell
    param(
        [string[]]$DesktopGroups,
        [string]$ConfigFile = ".\config.json"
    )
    ```

---

### Priorität 3 - Hoch (Aufwändige Verbesserungen)

- [x] **Pester-Tests mit echtem Mocking erweitern** ✅ (3.1.0, 73 Tests, ca. 92 % Coverage)
  - Vorher: Nur statische Pattern-Checks auf Code-Text
  - Besser: Echte Unit-Tests mit Mock-Objekten
  - Beispiel:
    ```powershell
    It "Startet offline Maschine" {
        Mock New-BrokerHostingPowerAction { }
        Mock Get-BrokerDesktop { @([PSCustomObject]@{
            MachineName = "TestVM"
            PowerState = "Off"
            InMaintenanceMode = $false
        })}
        # Skript ausführen und Mocks verifizieren
        Should -Invoke New-BrokerHostingPowerAction -Times 1
    }
    ```

---

## Bereits gut umgesetzt ✅

- README.md vorhanden
- TODO.md vorhanden
- CHANGELOG.md mit Semantic Versioning
- CLAUDE.md vorhanden
- Comment-Based Help mit vollständiger Dokumentation
- Try-Catch Blöcke für kritische Operationen
- Validierung der Citrix Cmdlets beim Start
- Event Log Integration mit strukturierten Event IDs
- Exit Codes für Scheduler-Integration
- Statistik-Summary am Ende
- #Requires Statement für PowerShell-Version
- CmdletBinding für Verbose-Support
- Git initialisiert

---

## Versions-Hinweis

Bei Umsetzung der Verbesserungen bitte Version aktualisieren:
1. `citrix_reboot_check.ps1:14` - Version im .NOTES Kommentar
2. `citrix_reboot_check.ps1:27` - `$ScriptVersion` Variable
3. `CHANGELOG.md` - Neuen Versions-Eintrag hinzufügen

Empfehlung: Version 2.1.0 für nicht-breaking Verbesserungen
