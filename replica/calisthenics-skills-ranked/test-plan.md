# Test plan: Nachbau Calisthenics Skills – Ranked

Build: 3c9f88e · Datum: 2026-10-15 · Umgebung: Linux-Container ohne Swift → nur Python-Referenz ausführbar.
Methodik: `replica-test` (Git-History, Commit 6873202). Getestet wird nur der Nachbau, nie das Original.

Legende `auto`: **py** = `app/tools/*.py` (hier gelaufen) · **xct** = XCTest (`GradingKit`/`App/Tests`) · **ui** = XCUITest (`App/UITests`) · **man** = manuell.
`result`: PASS/FAIL = hier ausgeführt · `—` = geschrieben, nicht ausgeführt (kein Xcode).

Nicht anwendbare Standard-Edge-Cases des Skills: zwei Tabs, Session-Ablauf, zweiter Nutzer (kein Account, ein Gerät = ein Nutzer), langsames Netz/offline (App ist vollständig offline), Kreditkarten-Testkarten (Kauf über StoreKit).

## F01 Erststart bis erster Rang

| case | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- |
| F01-H1 | happy | Intro → 12× „Nichts davon“ → Weiter | Ergebnis-Screen, dann Dashboard „Grad 1“ | ui | — |
| F01-E1 | edge: Einstufung über Maximum | claim 99 für „hang“ | auf letzte Stufe begrenzt | py | PASS |
| F01-E2 | edge: alles 0 | claims 0 überall | identisch zu leerem Zustand | py | PASS |
| F01-E3 | edge: alles Maximum | höchste Stufe überall | Grad 7–9 | py | PASS |
| F01-E4 | edge: Zurück mitten im Test | 1 Antwort → Zurück | Frage 1 wieder sichtbar | ui | — |
| F01-E5 | edge: App killen mitten im Test | Frage 5 → App beenden → neu starten | Einstufung beginnt neu, keine halben Claims gespeichert | man | — |
| F01-N1 | negative: Einstufung erzeugt Power | max. Claims | Power 0 | py, xct | PASS / — |
| F01-A1 | a11y | VoiceOver durch S01–S03, Audit | alle Elemente benannt, Fortschritt „Frage n von 12“ | ui, man | — |

## F02 Satz loggen (Kern-Loop)

| case | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- |
| F02-H1 | happy | Dashboard „… loggen“ → Speichern | ≤ 2 Taps, Toast „Power +n“, Stufe geschafft | ui, xct | — |
| F02-E1 | edge: riesiger Wert | 10⁹ Sekunden | Volumen gedeckelt, Power wie bei normalem Satz | py | PASS |
| F02-E2 | edge: Doppeltipp Speichern | Doppeltipp | genau ein Satz | ui (Button-Sperre), py (Auswirkung begrenzt) | PASS (py) / — |
| F02-E3 | edge: exakt am Ziel / Ziel − 1 | 1 Klimmzug / 7 statt 8 | schaltet frei / schaltet nicht frei | py | PASS |
| F02-E4 | edge: Rückgängig | Satz → Rückgängig | Rang und Power wie vorher | xct | — |
| F02-E5 | edge: Dynamic Type AX5 | größte Schrift, S08 | nichts abgeschnitten, Buttons erreichbar | man | — |
| F02-N1 | negative: Wert 0 | Tastatur „0“ | nicht speicherbar, kein Power | py, xct, ui | PASS (nach Fix) / — |
| F02-N2 | negative: negativer Wert | Einfügen „-5“ | ignoriert | py, xct | PASS (nach Fix) / — |
| F02-N3 | negative: unbekannte Stage-ID | Log mit gelöschter ID | ignoriert, kein Absturz | py, xct | PASS (nach Fix) / — |

## F03 Stufe/Grad aufsteigen

| case | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- |
| F03-H1 | happy | Ziel erreicht | LevelUp-Sheet „Stufe geschafft“, Haptik | ui | — |
| F03-E1 | edge: höhere Stufe zuerst | Stufe 6 ohne 1–5 | höchste zählt | py | PASS |
| F03-E2 | edge: 60 Tage Pause | alter Satz | Grad bleibt, Power sinkt | py | PASS |
| F03-E3 | edge: Monotonie | 300 Zufallsfolgen + geschaffter Satz | Score und Power sinken nie | py | PASS |
| F03-E4 | edge: Reduce Motion | Einstellung an, Aufstieg | Crossfade statt Spring | man | — |

## F04 Plan gegen schwächste Region (PRO)

| case | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- |
| F04-H1 | happy | Plan erstellen | Punkte aus schwächster Region | py, xct | PASS / — |
| F04-H2 | happy | alle Punkte loggen | Plan „erledigt“, bleibt sichtbar | xct | — |
| F04-E1 | edge: Gleichstand Regionen | keine Logs | Tie-Break: weniger Logs, dann Reihenfolge | py | PASS |
| F04-E2 | edge: Region komplett | alle Griff-Stufen | Plan nimmt andere Region | py | PASS |
| F04-E3 | edge: alles geschafft | jede letzte Stufe | leerer Plan, kein Absturz | py | PASS |
| F04-E4 | edge: Rückgängig nach Plan-Satz | Punkt per Log erledigt → Rückgängig | Punkt wieder offen | xct | — (Bug gefunden per Code-Trace, s. BUG-003) |
| F04-E5 | edge: manueller Haken | Haken → anderer Satz → Rückgängig | Haken bleibt | xct | — |
| F04-N1 | negative: ohne PRO | Tab Plan | Hinweis + „PRO ansehen“ | ui | — |

## F05 Abo

| case | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- |
| F05-H1 | happy | Verlauf → PRO ansehen | Paywall mit Preisen, Restore, AGB, Datenschutz | ui | — |
| F05-H2 | happy | Jahresabo mit Trial kaufen (StoreKit-Test) | PRO aktiv, Paywall schließt | man | — |
| F05-E1 | edge: Kauf abgebrochen | Abbrechen im Kaufdialog | kein PRO, keine Fehlermeldung | man | — |
| F05-E2 | edge: Restore ohne Kauf | Käufe wiederherstellen | Status bleibt „Nicht aktiv“ | man | — |
| F05-E3 | edge: Abo abgelaufen | StoreKit-Test „Expire“ | PRO weg nach Neustart/Update | man | — |
| F05-N1 | negative: Kauf fehlgeschlagen | StoreKit-Test „Fail transactions“ | Fehler von System-UI, kein PRO | man | — |
| F05-N2 | negative: alles löschen | S13 → Alles löschen | Daten weg, Onboarding, Abo bleibt | xct | — |

## Querschnitt

| case | type | expected | auto | result |
| --- | --- | --- | --- | --- |
| X-E1 | Sommerzeit-Wechsel im 14-Tage-Fenster | 14 Kalendertage | py | PASS |
| X-E2 | Schaltjahr | 29.02. korrekt | py, xct | PASS / — |
| X-E3 | Satz kurz nach Mitternacht lokal (UTC noch Vortag) | zählt für lokalen Tag | py | PASS |
| X-E4 | umbenannte Stage-ID nach Katalog-Update | aufgelöst | py, xct | PASS (nach Fix) / — |
| X-P1 | 10 000 Sätze | Bewertung < 1 s | py | PASS |
| X-D1 | Snapshots | einer pro Tag und Grund | xct | — |
| X-V1 | Referenz vs. Swift | 10 Vektoren identisch | py, xct | PASS / — |
| X-C1 | Katalog-Validierung | IDs eindeutig, Schwierigkeit streng steigend | py | PASS |
| X-A1 | Accessibility-Audit je Screen | keine Befunde | ui | — |
| X-T1 | Dark Mode alle Screens | Kontrast laut tokens.dark.json | man | — |

## Ausführen

```bash
cd app
python3 -I tools/grading_ref.py --check     # Katalog, 11 Eigenschaftstests, 10 Vektoren
python3 -I tools/edge_tests.py              # 20 Edge-/Negativfälle
(cd Packages/GradingKit && swift test)      # Mac
xcodegen && xcodebuild test -scheme GradeApp -destination 'platform=iOS Simulator,name=iPhone 16'
```
