# Bugs: Nachbau Calisthenics Skills – Ranked

Nur Gefundenes mit Nachweis. Vermutungen unter „Zu prüfen“.

### BUG-001: Sätze mit Wert 0 oder negativ verändern das Power Level

- Severity: S3
- Flow / case: F02 / F02-N1, F02-N2
- Screen: S08
- Build: b844def  Gerät: Python-Referenz (Logik identisch zu GradingKit)

Steps
1. In S08 das Zahlenfeld leeren und „0“ tippen (Feld klemmt nur die +/−-Buttons, nicht die Tastatur) oder „-5“ einfügen.
2. Speichern.

Expected: Satz wird nicht gespeichert, Power unverändert.
Actual: Wert 0 → Power +21 (zählt als aktiver Tag). Wert −5 → Power −13 (negatives Volumen in log1p).
Evidence: `tools/edge_tests.py` F02-N1 „Satz mit Wert 0 erzeugt Power 21“, F02-N2 „negativer Wert erzeugt Power -13“.
Suspected cause: Grading filtert Werte nicht; `NumberStepper` klemmt Texteingabe nicht; `AppModel.addLog` prüft nichts.
Status: fixed in 3c9f88e — Grading (Swift + Referenz) ignoriert Werte ≤ 0; `AppModel.addLog/editLog` erzwingen 1…10 000; `NumberStepper` klemmt per `onChange`; S08 sperrt Speichern außerhalb des Bereichs. Tests: F02-N1/N2 (py PASS), `testRejectsOutOfRangeValues`, `testNonPositiveValuesIgnored` (xct, nicht ausgeführt).

### BUG-002: Referenz stürzt bei umbenannter oder unbekannter Stage-ID ab

- Severity: S3
- Flow / case: X-E4, F02-N3
- Screen: —
- Build: b844def  Gerät: Python-Referenz

Steps
1. `catalog.json` mit `"renamed": {"pushup.99": "pushup.04"}`.
2. Log mit `pushup.99` bewerten.

Expected: ID wird aufgelöst wie in GradingKit (`Catalog.resolve`).
Actual: `KeyError: 'pushup.99'`. Referenz und Swift weichen damit bei jedem Katalog-Update ab; Testvektoren würden falsch.
Evidence: `tools/edge_tests.py` X-E4.
Status: fixed in 3c9f88e — `usable_logs()` löst `renamed` auf und verwirft unbekannte IDs; neuer Vektor `wert_null_negativ_unbekannt`; Swift-Test `testRenamedStageResolves`.

### BUG-003: Rückgängig/Löschen lässt Plan-Punkt als erledigt stehen

- Severity: S3
- Flow / case: F04 / F04-E4
- Screen: S09, S10
- Build: b844def  Gerät: Code-Trace (nicht ausgeführt, kein Xcode)

Steps
1. PRO, Plan erstellen.
2. Ersten Plan-Punkt über S08 mit Zielwert loggen → Punkt erledigt.
3. Im Toast „Rückgängig“.

Expected: Punkt wieder offen, Plan wieder aktiv.
Actual: `AppModel.deleteLog` rechnet Rang neu, fasst Plan-Punkte aber nicht an; `doneAt` bleibt, ein dadurch „erledigter“ Plan bleibt erledigt.
Evidence: `AppModel.swift` @ b844def, `deleteLog` ruft nur `recompute()`; `markPlanItems` setzt `doneAt` nur, nie zurück. Swift-Test `testUndoRevertsPlanItem` geschrieben, **nicht ausgeführt**.
Status: fixed in 3c9f88e — `refreshPlanItems()` leitet Erledigt-Status nach jeder Log-Änderung aus Logs seit Planerstellung + manuellem Haken (`PlanItem.doneManually`) ab; erledigter Plan bleibt sichtbar (`currentPlan()`).

## Zu prüfen (nicht reproduziert)

- LevelUp-Sheet wird aus `MainTabs` präsentiert, während das Log-Sheet aus dem Tab noch schließt → SwiftUI kann die zweite Präsentation verwerfen. Im Simulator prüfen (F03-H1).
- F02-E2 Doppeltipp: zweiter Tipp trifft eventuell ein Element unter dem schließenden Sheet (UI-Test kann flackern).
- VoiceOver: Toast und LevelUp-Sheet kündigen beide an → doppelte Ansage.
- `HistoryView` parst `localDay` mit lokaler Zeitzone um Mitternacht; in Zonen ohne Mitternacht am DST-Tag fällt der Punkt weg.
- „Einstufung wiederholen“ lässt sich nicht abbrechen (nur bis zum Ende durchklicken).
- `-uiTesting` setzt `hasOnboarded` im echten UserDefaults des Simulators zurück.
- `activeLogs()` wird in View-Bodies mehrfach gefetcht; bei Tausenden Sätzen Scroll-Ruckler möglich.
- `StoreService.groupID` ist der Wert aus der Testkonfiguration; mit App Store Connect abgleichen.
- Swift-Code insgesamt ungebaut: Compilerfehler sind wahrscheinlicher als alle obigen Punkte.
