# Architecture: eigene App (Nachbau der Kernfunktionen von Calisthenics Skills – Ranked)

Input: `recon.md`, `features.csv` in diesem Ordner. Methodik: `replica-architect` (Git-History, Commit 6873202; in dieser Session nicht installiert).

Grundentscheidung: Das Original ist nur für iPhone, rein lokal, ohne Account. Der Nachbau übernimmt das. **Kein Backend, keine Auth, keine E-Mails, kein Hosting.** Der Skill-Default (Next.js, Supabase, Stripe) passt nicht: Er löst Probleme, die diese App nicht hat, und Stripe ist für digitale Abos in iOS-Apps nicht zulässig (In-App-Kauf über Apple ist Pflicht).

## Stack

| layer | choice | why |
| --- | --- | --- |
| app | SwiftUI, iOS 17+ | nur iPhone wie das Original; native Widgets, HealthKit, StoreKit ohne Bridge |
| persistence | SwiftData (SQLite darunter) | lokal, Migrationen eingebaut; Referenzschema in `schema.sql` |
| katalog | `catalog.json` im Bundle, versioniert | 6 Regionen / 38 Linien / Stufen als Daten, ohne App-Update-Logik im Code |
| grading | reine Swift-Funktionen in eigenem Package `GradingKit` | deterministisch, ohne UI testbar, Kalibrierung per Unit-Tests |
| charts | Swift Charts | Rang-Verlauf (S12), keine Abhängigkeit |
| payments | StoreKit 2, `SubscriptionStoreView` | Pflicht für digitale Abos; Trial und Restore eingebaut |
| analytics | TelemetryDeck oder keins | datenschutzfreundlich; passt zum Versprechen „nichts wird hochgeladen“ — wenn genutzt, im Datenschutz-Label angeben |
| sync | (could) CloudKit über SwiftData | Abgrenzung zum Original; ändert das Schema nur über Soft-Delete und optionale Felder |
| tests | XCTest / Swift Testing, XCUITest für F02 | |
| CI/Release | Xcode Cloud oder fastlane + TestFlight | |
| Alternative | Expo + expo-sqlite + RevenueCat | nur wenn Android (could) früh gebraucht wird |

## Schema

Tables: 11 (3 Katalog, 1 Katalog-Meta, 7 Nutzer/Cache). Access rules: keine nötig — eine Person pro Gerät, App-Sandbox. Vollständig in `schema.sql`.

Entscheidungen:
- `set_logs` ist die einzige Quelle der Wahrheit. `line_progress`, `rank_snapshots` sind Caches und jederzeit per `recomputeAll()` rekonstruierbar.
- Einstufungs-Selbstangaben (`assessment_answers`) getrennt von Logs: Grade nutzen `max(geloggt, behauptet)`, das Power Level nur echte Logs. Verhindert, dass man Power durch Behaupten aufbläht.
- Soft-Delete auf `set_logs` für Undo und spätere CloudKit-Sync.
- Katalog-IDs sind stabile Slugs (`planche.07`). Neue Stufen nur anhängen oder per Mapping in `catalog.json` umziehen, nie IDs wiederverwenden.

SwiftData-Abbild (Kurzform):

```swift
@Model final class SetLog { @Attribute(.unique) var id: UUID; var stageID: String; var value: Int; var loggedAt: Date; var createdAt: Date; var updatedAt: Date; var deletedAt: Date? }
@Model final class LineProgress { @Attribute(.unique) var lineID: String; var highestClearedIdx: Int; var clearedAt: Date?; var lineGrade: Int; var updatedAt: Date }
@Model final class AssessmentAnswer { @Attribute(.unique) var lineID: String; var claimedIdx: Int; var answeredAt: Date }
@Model final class RankSnapshot { @Attribute(.unique) var id: UUID; var takenAt: Date; var localDay: String; var overallGrade: Int; var powerLevel: Int; var regionGrades: [String: Int]; var reason: String }
@Model final class Plan { @Attribute(.unique) var id: UUID; var targetRegionID: String; var createdAt: Date; var status: String; @Relationship(deleteRule: .cascade) var items: [PlanItem] }
@Model final class PlanItem { var stageID: String; var sets: Int; var target: Int; var sort: Int; var doneAt: Date? }
// Katalog: struct Catalog: Decodable { version, regions, lines, stages } — im Speicher, nicht in SwiftData.
```

## Grading-Modell (eigener Entwurf, nicht das Original)

Alle Werte 0…1 normiert, dann auf Grade abgebildet. Parameter in `GradingConfig`, damit sie ohne Code-Umbau kalibrierbar sind.

```
stage cleared        : ein Satz mit value >= stage.target (ein sauberer Satz genügt; Konfig: n Sätze)
line_score(l)        : difficulty der höchsten geschafften Stufe (max mit Einstufung), 0 wenn keine
line_grade(l)        : 0..4  per Schwellen auf line_score  (0.15 / 0.4 / 0.65 / 0.85)
region_score(r)      : gewichtetes Mittel der line_score in r, Top-k-Linien (k=3) zählen doppelt
                       -> Spezialisierung wird belohnt, ohne alle Linien zu verlangen
balance              : min(region_score) / mean(region_score)   (0..1)
overall_score        : mean(region_score) * (0.7 + 0.3 * balance)
                       -> schwächste Region drückt den Gesamtgrad; Kern des Produktversprechens
overall_grade        : 1..9 per Schwellen auf overall_score (Tabelle in GradingConfig)
region_grade(r)      : 1..9 mit derselben Tabelle auf region_score

consistency          : Anteil aktiver lokaler Tage in den letzten 14 (0..1)
volume               : Summe value/target über geloggte Sätze der letzten 30 Tage
power_level          : round(1000*overall_score + 15*summe(cleared_stages) + 300*consistency + 120*ln(1+volume))
weakest_region       : argmin region_score; Gleichstand -> weniger Logs in 14 Tagen -> fester sort
```

Abstieg: Grade sinken nicht durch Inaktivität (geschaffte Stufen bleiben). Nur das Power Level fällt über `consistency` und `volume`. Verhindert Frust; im Onboarding so kommunizieren.

## API (lokale Service-Schicht, kein Netzwerk)

Kein HTTP. „Routen“ sind die Methoden der Services, die die Views aufrufen. Alle laufen auf einem `@ModelActor` (`DataActor`), damit Schreibzugriffe serialisiert sind.

| method | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| `CatalogService.load()` | `catalog.json` dekodieren, Version prüfen, ID-Mapping anwenden | App-Start | — | `Catalog` | alle |
| `AssessmentService.questions()` | eine Frage je Region, dann je Linie der Region (verkürzt: 6 + max. 12) | S02 | — | `[Question]` | F01 |
| `AssessmentService.submit(_:)` | Antworten speichern, `recomputeAll`, Snapshot `assessment` | S02 → S03 | `[lineID: claimedIdx]` | `RankSummary` | F01 |
| `LogService.add(stageID:value:at:)` | Satz anlegen, betroffene Linie neu bewerten, Grade/Power neu, Snapshot `log` upsert | S08 | stageID, value, Date | `LogOutcome` (powerDelta, stageCleared?, gradeUp?) | F02, F03 |
| `LogService.edit(id:value:)` | Satz ändern, Neuberechnung | S08 | id, value | `LogOutcome` | F02 |
| `LogService.delete(id:)` / `undo(id:)` | Soft-Delete / zurück, Neuberechnung | S08, S09 | id | `RankSummary` | F02 |
| `RankService.current()` | Gesamtgrad, Power, 6 Regionsgrade, schwächste Region | S03, S05, S11 | — | `RankSummary` | F01, F04 |
| `RankService.line(_:)` | Stufenkette mit Status, Liniengrad | S07 | lineID | `LineDetail` | F02, F03 |
| `RankService.history(range:)` | Snapshots für Chart | S12 | DateInterval | `[RankSnapshot]` | — |
| `RankService.recomputeAll()` | alle Caches aus Logs neu | Debug, Katalog-Update, Migration | — | `RankSummary` | — |
| `PlanService.current()` / `generate()` | Plan gegen schwächste Region: 3–5 Items = nächste nicht geschaffte Stufe der 2–3 schwächsten Linien dieser Region | S10 | — | `Plan` | F04 |
| `PlanService.markDone(itemID:)` | Item abhaken (geschieht auch automatisch, wenn passender Log kommt) | S10 | itemID | `Plan` | F04 |
| `StoreService.products()` / `purchase(_:)` / `restore()` | StoreKit 2 | S04, S13 | productID | `Entitlement` | F05 |
| `StoreService.entitlementStream` | `Transaction.updates` beobachten, Cache setzen | App-Start | — | `AsyncStream<Entitlement>` | F05 |
| `DataService.exportCSV()` / `wipe()` | Export (could) / alles löschen | S13 | — | URL / — | — |

Paywall-Grenze (Vorschlag, eigene Entscheidung): frei = Einstufung, Gesamtgrad, Loggen in allen Linien. PRO = Regionsgrade-Details, schwächste-Region-Plan, Verlauf, Widgets.

Webhooks in/out: keine. App Store Server Notifications nicht nötig ohne Server.
Jobs:
- `daily snapshot` — beim ersten App-Start eines lokalen Tages (kein Hintergrund-Job nötig), Snapshot `daily` für den Vortag.
- `widget refresh` — `WidgetCenter.reloadAllTimelines()` nach jedem Log.
- optional `BGAppRefreshTask` — nur falls Erinnerungen (nicht im Scope).

## The parts that bite

- **Zeitzonen/Sommerzeit:** `consistency` zählt lokale Kalendertage. `local_day` beim Loggen mit `TimeZone.current` speichern, nicht nachträglich aus UTC ableiten — sonst springt ein Satz nach Reisen auf einen anderen Tag.
- **Idempotenz:** StoreKit liefert Transaktionen mehrfach (`Transaction.updates`, Restore). Immer `transaction.finish()` nach Prüfung, Entitlement nur aus `currentEntitlements` ableiten, nie hochzählen.
- **Races:** Doppeltipp auf „Speichern“ → zwei Logs. Button während `add` deaktivieren; alle Schreibzugriffe über einen `@ModelActor`; Neuberechnung inkrementell pro Linie, `recomputeAll` nur als Fallback.
- **Katalog-Migration:** neue/umsortierte Stufen ändern Grade rückwirkend. Mapping-Tabelle `renamed: {old: new}` in `catalog.json`, nach Update `recomputeAll` und einmalig Snapshot `recompute`; Grad-Abstieg durch Katalogänderung im UI erklären.
- **Datenverlust:** rein lokal = Gerät weg, Daten weg. Mindestens CSV-Export (could) früh; CloudKit (could) als Abgrenzung zum Original.
- **Selbstangaben:** Einstufung ist ungeprüft. Darum Power nur aus echten Logs (s. Schema-Entscheidung).
- **App Review:** Wochenabo mit Trial braucht klare Preis-/Laufzeit-Anzeige, Links zu AGB/Datenschutz und „Restore“ auf der Paywall (Guideline 3.1.2). Funktionsumfang im Free-Tier muss ohne Kauf sinnvoll sein.
- **Datenschutz-Label:** „Data Not Collected“ nur, wenn wirklich kein Analytics/Crash-SDK sendet. Sonst korrekt deklarieren.
- **Gesundheitsbezug:** keine Verletzungs- oder Medizinversprechen; Hinweis „Training auf eigenes Risiko“.
- **Nicht relevant:** Multi-Tenancy, E-Mail, Rate Limits, Realtime, Suche (38 Linien → lokale Filterung reicht), DSGVO-Löschung beschränkt sich auf `wipe()`.

## Build order

1. **Vertikaler Schnitt** (Wochenende)
   Screens S06, S07, S08, S09, S05 (roh). Tabellen `set_logs`, `line_progress`, Katalog mit 6 Regionen × 2 Linien. Services `CatalogService`, `LogService.add`, `RankService.current/line`, `GradingKit` mit Unit-Tests.
   Fertig, wenn: Satz loggen → Stufe geschafft → Gesamtgrad und Power ändern sich sichtbar, in ≤ 4 Taps.
2. **Must-haves**
   - Onboarding + Einstufung: S01, S02, S03 · `assessment_answers` · `AssessmentService`.
   - Volle 38 Linien mit Stufen in `catalog.json` (Fachrecherche, eigene Texte).
   - Regionsgrade + schwächste Region: S11 · `RankService`.
   - Edit/Delete/Undo: `LogService.edit/delete/undo`.
   - Paywall + Restore: S04, S13 · `StoreService` · StoreKit-Konfigurationsdatei für Tests.
3. **Should-haves**
   - Liniengrade (4 Stufen) in S06/S07.
   - Plan gegen schwächste Region: S10 · `plans`, `plan_items` · `PlanService`.
   - Rang-Verlauf: S12 · `rank_snapshots` · Swift Charts.
   - Hold-Timer in S08, Einstellungen S13.
4. **Could-haves:** CSV-Export, Widgets, HealthKit-Workouts schreiben, CloudKit-Sync, Android (dann Expo-Port prüfen).
5. **Fixes aus replica-entrepreneur:** offen (Skill nicht ausgeführt).

## Summary

- Stack: SwiftUI + SwiftData + StoreKit 2, rein lokal, kein Backend.
- Tabellen: 11. Service-Methoden: 18 (lokal, kein HTTP). Webhooks: 0. Jobs: 2 (bei App-Start/nach Log).
- Riskanteste Teile: 1) Kalibrierung des Grading-Modells, 2) Katalog-Migration ohne rückwirkenden Frust, 3) Paywall/App-Review beim Wochenabo.
- Nächster Schritt: `/replica-design` (nur in Git-History, Commit 6873202).
