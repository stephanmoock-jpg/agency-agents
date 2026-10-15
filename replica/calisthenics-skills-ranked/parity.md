# Parity: Nachbau vs. Calisthenics Skills – Ranked

Build: ef9b735 · Datum: 2026-10-15 · Methodik: `replica-diff` (Git-History, Commit 6873202), Tools in `diff/` (unverändert vendored).

## Ergebnis

| | Wert | Grundlage |
| --- | --- | --- |
| **Gesamt** | **47.9 / 100** | = Feature-Score (kein Layout-Score möglich) |
| Feature-Score | 47.9 | `python3 diff/parity.py features.csv` |
| Must-haves fertig | 0 von 11 | alle 11 `partial`: Code geschrieben, nicht kompiliert |
| Layout-Score | — | keine Screenshots, weder Original noch Nachbau |
| Prognose nach grünem Xcode-Lauf | 89.6 (9 von 11 Must-haves) | `diff/features.projected.csv`: jedes `partial` → `yes`, außer 38 Linien und Abo |

**Verdict: nicht shippable.** Grund: kein Must-have nachweisbar fertig, weil kein Swift-Code gebaut oder ausgeführt wurde. Keine offenen S1/S2-Bugs bekannt (`bugs.md`), aber das ist ohne Testlauf wenig wert.

Die 47.9 heißt nicht „halb so gut“, sondern: alles ist geschrieben, nichts ist bewiesen. Der Sprung auf ~90 hängt allein am ersten Build mit grünen Tests — die Prognose ist eine Annahme, keine Messung.

Vorbehalte zur Matrix:
- 6 Zeilen haben `original = unknown` (Hold-Timer, Satz bearbeiten, Einstellungen, CSV-Export, Widgets, Health). `parity.py` zählt sie als Funktionen des Originals. Die Recon hat sie nur abgeleitet; ohne Prüfung am Original kann der Score zu streng oder zu mild sein.
- Recon-Grundlage war nur der Store-Text (keine Screenshots), siehe `recon.md`.

## Layout-Diff

Nicht durchgeführt. `screens/` (Original) ist leer, `clone-screens/` existiert nicht.
- Original: Store-Screenshots der App-Store-Seite manuell speichern (nicht scrapen), als `screens/S03.png`, `S05.png`, `S07.png`, `S08.png`, `S09.png`.
- Nachbau: Simulator iPhone 16 (393×852 pt), gleicher Zustand, `xcrun simctl io booted screenshot clone-screens/S05.png`.
- Dann je Screen: `python3 diff/imgdiff.py screens/S05.png clone-screens/S05.png --json > diff/S05.json` und `python3 diff/parity.py features.csv --visual diff/*.json --markdown`.

Ziel ist Struktur-Nähe (wo steht Grad, Power, Regionen), nicht Pixel-Nähe; Farben und Namen ändert `replica-brand` ohnehin.

## Verhalten (Flow für Flow)

Original laut Store-Text bzw. Recon-Schätzung; Nachbau laut Code (`app/`) und UI-Tests (nicht ausgeführt).

| Flow | Original | Nachbau | fix oder keep |
| --- | --- | --- | --- |
| F01 Einstufung | Einstufung zeigt schwächste Region; Länge unbekannt (Recon-Schätzung ~12 Taps) | 1 Tap + 12 Fragen (eine je Linie) + 1 = 14 Taps | **fix**: bei 38 Linien wären es 40 Taps → auf eine Frage je Region plus optionale Details kürzen |
| F01 Einstufung → Power | unbekannt | Einstufung hebt nur Grade, Power startet bei 0 | keep (gegen Aufblähen durch Selbstangabe), im Onboarding erklärt |
| F02 Satz loggen | Recon-Schätzung 3–4 Taps | 2 Taps vom Dashboard („… loggen“, „Speichern“), 4 über Skills-Tab | keep — schneller als die Schätzung |
| F02 Fehleingaben | unbekannt | Werte außerhalb 1…10 000 gesperrt (BUG-001 behoben) | keep |
| F02 Rückgängig | unbekannt | Toast mit Rückgängig (4 s; mit VoiceOver bis zum Schließen) | keep |
| F03 Abstieg | unbekannt; Power „bewegt sich mit jedem Satz“ | Grade sinken nie, Power sinkt über Konstanz/Volumen | keep, am Original prüfen |
| F04 Plan | „gebaut gegen die schwächste Region“ | nächste offene Stufe der 2–3 schwächsten Linien dieser Region; erledigt sich durch Logs | keep; Detailtiefe des Originals unbekannt |
| F05 Abo | Weekly 3,99 $, Yearly 79,99 $ mit 1 Woche gratis | Testkonfig: Weekly 3,99, Yearly 59,99 mit 1 Woche gratis | Preisentscheidung → `replica-entrepreneur` |
| F05 Paywall-Grenze | unbekannt, was frei ist | frei: Einstufung, Gesamtgrad, Loggen, schwächste Region (Name); PRO: Regionsgrade, Plan, Verlauf | am Original prüfen |
| Daten | lokal, kein Konto | lokal, kein Konto, plus CSV-Export | keep; Export ist Vorteil gegen Datenverlust |
| Plattform | nur iPhone | nur iPhone; iCloud/Android als eigene Zusätze geplant | keep |

## Top 5 als Nächstes

1. **In Xcode bauen und alle Tests grün bekommen** (GradingKit 4, AppModel 10, UI 8). Hebt 9 Must-haves von `partial` auf `yes` → Prognose ~90.
2. **Restliche 26 Skill-Linien** in `catalog.json` (Fachrecherche; Testkopie aktualisieren, `grading_ref.py --check`).
3. **Abo in App Store Connect** anlegen, echte `groupID`, AGB-/Datenschutz-URLs statt `example.com`.
4. **Screenshots** beider Apps für den Layout-Diff (S03, S05, S07–S09).
5. **Einstufung kürzen** (eine Frage je Region) und `/replica-brand` für Namen, Gradnamen, Akzentfarbe.

Danach: `/replica-build` für die Lücken; `/replica-entrepreneur` erst, wenn Must-haves `yes` sind.

---

## parity.py-Ausgabe

## Parity: 47.9 / 100

features 47.9  (20 counted, must-haves 0 of 11 done)

Not shippable yet: 11 must-have features are not done.

## By area, weakest first
- integrations                   0.0  (1 features)
- platform                      42.9  (4 features)
- onboarding                    50.0  (1 features)
- ranking                       50.0  (6 features)
- content                       50.0  (1 features)
- logging                       50.0  (3 features)
- payments                      50.0  (2 features)
- plan                          50.0  (1 features)
- tracking                      50.0  (1 features)

## Missing, in build order
- [must] content: 38 Skill-Linien mit Stufenketten, partial  (eigene Progressionen; 12 von 38 Linien (77 Stufen) im Katalog; Rest ist Content-Arbeit)
- [must] logging: Satz loggen (Wdh. oder Sekunden), partial  (Code geschrieben, nicht kompiliert; S08)
- [must] onboarding: Einstufungstest beim Erststart, partial  (Code geschrieben, nicht kompiliert; S01-S03)
- [must] payments: Abo weekly/yearly mit Trial, partial  (StoreKit 2; Code geschrieben, nicht kompiliert; nur StoreKit-Testkonfiguration, App Store Connect fehlt)
- [must] payments: Käufe wiederherstellen, partial  (Code geschrieben, nicht kompiliert)
- [must] platform: Lokale Speicherung ohne Account, partial  (SwiftData/Core Data; Code geschrieben, nicht kompiliert; SwiftData)
- [must] ranking: Gesamtgrad in 9 Stufen, partial  (eigene Gradnamen; Code geschrieben, nicht kompiliert; Logik per Python-Referenz geprüft)
- [must] ranking: Grad je Muskelregion (6), partial  (Code geschrieben, nicht kompiliert; PRO)
- [must] ranking: Power Level aus Rang Stufen Konstanz Volumen, partial  (Formel selbst entwerfen; Code geschrieben, nicht kompiliert; Logik per Python-Referenz geprüft)
- [must] ranking: Schwächste Region hervorheben, partial  (Code geschrieben, nicht kompiliert; Logik geprüft)
- [must] ranking: Stufe geschafft und Grad-Aufstieg Feedback, partial  (Code geschrieben, nicht kompiliert; Toast + LevelUpSheet)
- [should] logging: Hold-Timer für statische Stufen, partial  (inferiert; Code geschrieben, nicht kompiliert)
- [should] logging: Satz bearbeiten/löschen, partial  (inferiert; Code geschrieben, nicht kompiliert; Swipe + Undo-Toast)
- [should] plan: Trainingsplan gegen schwächste Region, partial  (Code geschrieben, nicht kompiliert; Planer per Python-Referenz geprüft)
- [should] platform: Einheiten und Einstellungen, partial  (Code geschrieben, nicht kompiliert; keine Einheiten nötig (Wdh./s))
- [should] ranking: Grad je Skill-Linie, partial  (Code geschrieben, nicht kompiliert)
- [should] tracking: Rang-Verlauf Chart, partial  (Code geschrieben, nicht kompiliert; Swift Charts)
- [could] integrations: Apple Health Sync, no
- [could] platform: Widgets mit Grad/Power, no
- [could] platform: Daten-Export CSV, partial  (Code geschrieben, nicht kompiliert)

## Left out on purpose (not scored)
- Name Ranked und Gradnamen: Marke/Texte des Originals
- Konkrete Linien- und Stufentexte des Originals: eigene Inhalte schreiben
- Original-Bewertungsformel: nicht öffentlich; eigene Formel

## Yours, not in the original (not scored)
- iCloud-Sync zwischen Geräten
- Android-Version
