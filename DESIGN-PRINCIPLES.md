# Design-Prinzipien

Leitlinien und bewusste Entscheidungen hinter `citrix_reboot_check.ps1`. Wer das Skript ändert,
sollte diese Punkte kennen, bevor er sie bricht.

## Leitprinzipien

1. **Eine Aufgabe.** Das Skript findet ausgeschaltete Worker in Citrix Delivery Groups und
   schaltet sie ein. Es startet nichts neu, fährt nichts herunter und setzt keinen Wartungsmodus.
2. **Unbeaufsichtigt lauffähig.** Das Skript läuft als geplante Aufgabe ohne Benutzer. Es fragt nichts ab
   und meldet sein Ergebnis über Exit Code und Event Log.
3. **Fehler stoppen den Lauf nicht.** Ein Fehler bei einer Maschine oder Gruppe wird protokolliert
   und gezählt; die übrigen Maschinen und Gruppen werden trotzdem bearbeitet.
4. **Nachvollziehbar.** Jede Aktion landet mit fester Event-ID im Windows Event Log.
5. **Keine Umgebungsdaten im Code.** Gruppennamen, Hostnamen und Ähnliches gehören in den Aufruf,
   nicht ins Skript.

## Design-Entscheidungen

| Entscheidung | Begründung |
|---|---|
| Delivery Groups über den Pflichtparameter `-DesktopGroup` (seit 3.0.0) | Keine internen Namen im Repository; dasselbe Skript passt für mehrere Umgebungen. Pflicht, damit ein vergessener Parameter sofort fehlschlägt, statt still nichts zu prüfen. |
| Aufruf in der geplanten Aufgabe über `-Command`, nicht `-File` | `powershell.exe -File` übergibt `'A','B'` als einen einzigen String statt als Array. Mit `-NonInteractive` bricht ein fehlender Parameter sofort mit Exit Code 1 ab. |
| Maschinen im Wartungsmodus werden nie angefasst | Der Wartungsmodus ist eine bewusste Entscheidung eines Admins; das Skript übergeht sie nicht. |
| `Off` und `TurningOff` gelten als offline, exakter Vergleich | `-match "Off"` war fragil. `TurningOff` wird mitgenommen, weil die Maschine danach ohnehin aus ist. |
| „Gestartet“ heißt: Einschaltaktion erfolgreich beauftragt | `New-BrokerHostingPowerAction` stellt die Aktion nur in die Warteschlange. Ob die VM wirklich hochkommt, prüft das Skript nicht. |
| Erfolg nur bei `$true` aus `Start-OfflineMachine` | Vor 2.1.0 wurde auch ein fehlgeschlagener Start als gestartet gezählt und der Lauf endete mit Exit Code 0. |
| Event-Log-Meldungen auf Englisch, feste Event-IDs (111–126) | Die IDs sind die Schnittstelle zum Monitoring. Die Sprache der Meldungen bleibt bewusst Englisch (Entscheidung 2026-10-10). |
| Event Log ist optional | Kann die Quelle nicht initialisiert werden, läuft das Skript mit Warnung weiter, statt den Start der Maschinen zu verhindern. |
| Exit Code `0` / `1` | Die Aufgabenplanung und das Monitoring erkennen einen Fehler ohne Auswertung des Event Logs. |
| Windows PowerShell 5.1 als Ziel | Die Citrix-Cmdlets werden als Snap-ins geladen (`Add-PSSnapin`), und Snap-ins gibt es nur in Windows PowerShell. |
| Dateien als UTF-8 **mit BOM** | Ohne BOM liest Windows PowerShell 5.1 die Datei als ANSI und verstümmelt Umlaute (bis 3.1.0 der Fall). |
| Funktionen plus kurzes Hauptprogramm, das beim Dot-Sourcing übersprungen wird | Die Funktionen lassen sich in Tests laden und mit gemockten Citrix-Cmdlets aufrufen, ohne dass `exit` die Testsitzung beendet. |
| Keine globalen Variablen | Zustand liegt in Parametern, Rückgabewerten und höchstens im Skript-Scope (`$script:EventLog`). |

## Merksätze

- **Wartungsmodus heißt: Finger weg.**
- **Event-IDs sind eine Schnittstelle – nicht umnummerieren.**
- **Ein Fehler stoppt nicht den Lauf, aber er setzt den Exit Code.**
- **Keine echten Namen im Code.**
- **Getestet wird ohne Citrix: alles, was Citrix ist, wird gemockt.**
