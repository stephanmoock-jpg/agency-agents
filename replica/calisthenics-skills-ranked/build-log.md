# Build log: Nachbau Calisthenics Skills – Ranked

Methodik: `replica-build` (Git-History, Commit 6873202; in dieser Session nicht installiert).
Code: `app/` · Tokens/Primitives: `design/` · Stand: 2026-10-15

## Harte Einschränkung

Die Cloud-Umgebung ist Linux x86_64 ohne Swift-Toolchain; Download von swift.org und Docker gesperrt. SwiftUI/SwiftData/StoreKit existieren unter Linux ohnehin nicht.
**Kein Swift-Code ist kompiliert oder ausgeführt.** Keine Screenshots (`clone-screens/` fehlt). Definition of Done ist für keinen Screen erfüllt.

Was geprüft ist:
- `tools/grading_ref.py --check`: Katalog-Validierung (0 Fehler), 11 Eigenschaftstests (0 Fehler), 9 Testvektoren festgeschrieben. GradingKit-Tests vergleichen gegen dieselben Vektoren — Lauf in Xcode steht aus.
- `schema.sql` lädt in SQLite.
- Klammer-Balance aller Swift-Dateien (grobe Syntaxprobe, kein Ersatz für den Compiler).
- Keine Hex-Werte in Screens; Ausnahme: Toast-Schatten `.black.opacity(0.08)` laut Token `shadow.card`.

## Erste Schritte auf einem Mac

```bash
cd replica/calisthenics-skills-ranked/app
python3 -I tools/grading_ref.py --check          # Referenz grün?
(cd Packages/GradingKit && swift test)           # Swift vs. Referenz
brew install xcodegen && xcodegen                # GradeApp.xcodeproj
open GradeApp.xcodeproj                          # Scheme GradeApp, iPhone-Simulator, Cmd-R; Cmd-U für UI-Test
```
Erwartung: Compilerfehler in Screens sind möglich (ungebaut). Zuerst GradingKit grün bekommen, dann App.

## Screens

| ID | Datei | Status | fehlt / Anmerkung |
| --- | --- | --- | --- |
| S01 Intro | Screens/Onboarding.swift | geschrieben | ungebaut |
| S02 Einstufung | Screens/Onboarding.swift | geschrieben | 12 Fragen (eine je Linie); bei 38 Linien zu lang → auf Region-Fragen kürzen |
| S03 Ergebnis | Screens/Onboarding.swift | geschrieben | Paywall danach; `-skipPaywall` nur DEBUG |
| S04 Paywall | Screens/Onboarding.swift | geschrieben | SubscriptionStoreView; AGB/Datenschutz-URLs sind Platzhalter (example.com) |
| S05 Dashboard | Screens/Rank.swift | geschrieben | Regionsgrade hinter PRO, schwächste Region frei sichtbar |
| S06 Skills | Screens/Skills.swift | geschrieben | |
| S07 Linie | Screens/Skills.swift | geschrieben | Stufen aus Einstufung als „geschafft“ markiert, Hinweis zu Power |
| S08 Satz loggen | Screens/Skills.swift | geschrieben | Hold-Timer inline statt eigener Primitive |
| S09 Feedback | Screens/Shared.swift | geschrieben | Toast mit Rückgängig, LevelUpSheet, Haptik |
| S10 Plan | Screens/Plan.swift | geschrieben | PRO |
| S11 Region | Screens/Rank.swift | geschrieben | PRO (Zugang über S05) |
| S12 Verlauf | Screens/History.swift | geschrieben | PRO; letzter Snapshot pro Tag |
| S13 Einstellungen | Screens/Settings.swift | geschrieben | Export, Einstufung wiederholen, alles löschen |

## Abweichungen von architecture.md

- Services als eine `@MainActor @Observable` Klasse (`AppModel`) statt `@ModelActor`; Neuberechnung immer vollständig. Grund: kleine Datenmengen, weniger Concurrency-Fallen. Doppel-Log über deaktivierten Button verhindert.
- `set_logs.local_day` ergänzt (schema.sql + Model), damit Konstanz nach Zeitzonenwechsel stabil bleibt.
- Volumen pro Satz auf 3× Ziel gedeckelt (gegen „10000 Sekunden“-Eingaben).
- Testpreis Jahresabo 59,99 in `Products.storekit` (eigene Preisentscheidung, nicht vom Original).

## Härter als gedacht

- Content: 38 Linien mit fairen Schwierigkeitswerten sind Fachrecherche, keine Programmierung. 12 Linien gebaut; Schwierigkeitswerte sind grobe eigene Schätzungen und brauchen Kalibrierung.
- Kalibrierung: Testfall „ausgeglichen“ (10 Liegestütz, 8 Dips, 8 Klimmzüge …) ergibt Grad 4 von 9. Ob sich das richtig anfühlt, zeigt erst Nutzung.

## Offen

- In Xcode bauen, Compilerfehler beheben, GradingKit-Tests + UI-Test laufen lassen.
- Screenshots je Screen nach `clone-screens/` (hell, dunkel, AX5).
- Restliche 26 Linien in `catalog.json` (Testkopie mit `cp` aktualisieren, Script prüft das).
- App Store Connect: Produkte, Abo-Gruppe, echte `groupID` in `StoreService`.
- Gradnamen/App-Name/Akzentfarbe: `replica-brand`.
