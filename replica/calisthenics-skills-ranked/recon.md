# Recon map: Calisthenics Skills – Ranked (iOS, nur iPhone)

Scope: gesamte App. Kern-Loop: Einstufungstest → Ränge (gesamt, je Skill-Linie, je Muskelregion) → Sätze loggen → Power Level und Rang bewegen sich → Plan gegen schwächste Region.
For: eigenes Produkt des Nutzers (Annahme, nicht bestätigt).
Date: 2026-10-15
App Store: https://apps.apple.com/us/app/calisthenics-skills-ranked/id6795844394 · Entwicklerin: Monica Dede Schmid · Kategorie Health & Fitness

## Methodik und Grenzen

- Methodik: `replica-recon` (aus Git-History, Commit a6fce94; in dieser Session nicht installiert).
- `apps.apple.com` vom Egress-Proxy der Umgebung blockiert. Einzige Quelle: Snippets der Store-Beschreibung über Websuche. Keine unabhängigen Reviews gefunden.
- Keine Screenshots. Screens, Komponenten und Zustände sind **aus der Beschreibung inferiert**. Store-Screenshots nachträglich ansehen und S-Tabelle korrigieren.
- Kein Login, kein Scraping, keine App-Binaries, keine Netzwerk-Mitschnitte.

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | App-Store-Listing | https://apps.apple.com/us/app/calisthenics-skills-ranked/id6795844394 | Beschreibung, IAP-Preise, Privacy; nur über Snippets gelesen |
| 2 | calisthenicsskills.com | https://calisthenicsskills.com/ | eingestellte Website (~7 Jahre Betrieb); Verbindung zur App **nicht belegt** |

Belegte Fakten aus #1:
- 9 Gesamtgrade, „Bedrock“ bis „Zenith“; bewertet wird Können, nicht Wiederholungen.
- Power Level, ändert sich mit jedem geloggten Satz; Inputs: Rang, geschaffte Stufen, Konstanz, Volumen.
- 38 Skill-Linien, jede eine Kette von Stufen („erste saubere Wiederholung bis fertiger Skill“, z. B. erste Liegestütze → Full Planche).
- Grade je Skill-Linie, u. a. „Foothold, Ridge, Summit, Cirrus“ (vollständige Liste unbekannt).
- 6 Muskelregionen mit eigenem Grad; Einstufung zeigt, welche Region „die anderen zurückhält“.
- Trainingsplan, gebaut gegen die schwächste Region.
- Rang-Verlauf (Rank History).
- Alles lokal: kein Account, kein Login, kein Upload.
- Abo: „Ranked Weekly“ 3,99 $/Woche, „Ranked Yearly“ 79,99 $/Jahr mit 1 Woche gratis; Auto-Renew.
- Privacy-Angaben der Entwicklerin von Apple nicht geprüft (Standardhinweis).

## Core loop

Sätze loggen → Stufe in einer Skill-Linie geschafft → Linien-, Regions- und Gesamtgrad plus Power Level steigen → Plan richtet sich auf die schwächste Region aus. Der Nutzer zahlt für den Rang als Motivation und den Plan.

## Screens (inferiert)

| ID | screen | route / how to reach | purpose | key components | states (inferiert) |
| --- | --- | --- | --- | --- | --- |
| S01 | Intro | Erststart | Versprechen „Grade statt Reps“, lokal ohne Account | Hero, CTA | — |
| S02 | Einstufungstest | nach S01 | max. Stufe je Linie/Region abfragen | Fragen-Stepper, Stufen-Auswahl mit Kriterium (Wdh./Sekunden) | in progress, skipped |
| S03 | Ergebnis / Rang-Reveal | nach S02 | Gesamtgrad, Power Level, 6 Regionsgrade, schwächste Region | Grade-Badge, Radar/Bars je Region, Callout schwächste Region | filled |
| S04 | Paywall | nach S03, Lock-Punkte | Weekly / Yearly mit Trial | Plan-Toggle, Trial-Hinweis, Restore | default, purchasing, error, restored |
| S05 | Dashboard | Tab | aktueller Grad, Power Level, Regionsübersicht, nächster Plan-Punkt | Grade-Badge, Power-Meter, Region-Bars, Today-Card | free, pro |
| S06 | Skill-Baum / Linienliste | Tab | 38 Linien gruppiert (Region) | Linien-Rows mit Stufen-Fortschritt und Liniengrad | locked, in progress, maxed |
| S07 | Linien-Detail | S06 → Row | Stufenkette, Kriterien, aktueller Liniengrad | Vertikale Stufen-Kette, Kriterium je Stufe, Log-CTA | stage locked / current / cleared |
| S08 | Satz loggen | S07 / S05 / S09 | Stufe + Wdh. oder Sekunden eintragen | Stufen-Picker, Number-Stepper, Hold-Timer | empty, valid, invalid |
| S09 | Log-Feedback | nach S08 | Power-Delta, Stufe geschafft, Grad-Aufstieg | Delta-Toast, Level-up-Sheet | no change, power up, stage cleared, grade up |
| S10 | Trainingsplan | Tab | Plan gegen schwächste Region | Tages-/Wochenliste, Übung → S08 | not generated, active, done |
| S11 | Regions-Detail | S05 → Region | Grad, beitragende Linien | Grade-Badge, Linienliste | weakest, normal |
| S12 | Rang-Verlauf | Tab/Profil | Verlauf Grad und Power Level | Line-Chart, Grad-Wechsel-Marker | empty, filled |
| S13 | Einstellungen | Profil | Einheiten, Abo, Daten | Settings-List, Restore, Daten löschen/exportieren(?) | — |

## Flows

```
F01 Erststart bis erster Rang
    S01 -> S02 -> S03 -> S04 (Trial oder schließen) -> S05
    happy path clicks: ~12 (Test-Fragen dominieren; geschätzt)
    edge: Test abbrechen, alle Stufen 0, Paywall schließen

F02 Satz loggen (Kern-Loop)
    S05/S10 -> S08 -> S09 -> zurück
    happy path clicks: 3–4  ← Zahl, die geschlagen werden muss
    edge: Kriterium knapp verfehlt, falsche Eingabe korrigieren, Satz löschen, Stufe zurückstufen

F03 Stufe/Grad aufsteigen
    S08 -> S09 (stage cleared) -> S09 (grade up) -> S07 nächste Stufe
    edge: Abstieg bei Inaktivität? (Konstanz geht in Power ein; Abstiegsregel unbekannt)

F04 Plan gegen schwächste Region
    S05 -> S10 -> Übung -> S08
    edge: zwei Regionen gleich schwach, Plan nach Grad-Aufstieg neu berechnen

F05 Abo
    S04 -> Trial starten -> nach 7 Tagen Abbuchung; S13 -> Restore
    edge: Trial abgelaufen, Restore ohne Kauf, Familienfreigabe
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Grade-Badge | gesamt (9), Linie, Region | je Grad eigene Farbe/Icon | S03, S05, S06, S07, S11 |
| Power-Meter | groß, kompakt | static, animating delta | S03, S05, S09 |
| Region-Bars / Radar | 6 Achsen | weakest hervorgehoben | S03, S05 |
| Stage-Chain | vertikal | locked, current, cleared | S07 |
| Line-Row | — | Fortschritt x/n Stufen, Liniengrad | S06, S11 |
| Number-Stepper | Wdh., Sekunden | — | S08 |
| Hold-Timer | — | idle, running, stopped | S08 |
| Level-up-Sheet | stage, grade | — | S09 |
| Paywall-Sheet | weekly, yearly | trial, purchasing, error | S04 |
| Line-Chart | grade, power | empty, filled | S12 |
| Button | primary, secondary, ghost | default, pressed, disabled, loading | alle |

## Inferred data model (lokal, z. B. SwiftData/Core Data)

```
Region          id, name                      (6 Stück; Namen unbekannt — guess: Push, Pull, Core, Legs, Shoulders/Handstand, Grip)
                evidence: "6 muscle regions"   confidence: high (Anzahl), guess (Namen)

SkillLine       id, name, region_id, order    (38 Stück)
                evidence: "38 lines"           confidence: high

Stage           id, line_id, index, name, metric (reps|seconds), target
                evidence: "chain of stages from first honest rep to finished skill"
                confidence: high (Struktur), guess (metric/target)

SetLog          id, stage_id, value, logged_at
                evidence: "Power Level moves with every set you log"
                confidence: high

LineProgress    line_id, highest_cleared_stage, line_grade (Foothold|Ridge|Summit|Cirrus|…)
                evidence: Liniengrade im Listing  confidence: medium

RegionGrade     region_id, grade, computed_at
OverallGrade    grade (1..9, Bedrock..Zenith), power_level, computed_at
                evidence: Listing                 confidence: high (Felder), guess (Formel)

RankSnapshot    date, overall_grade, power_level, region_grades{}
                evidence: "rank history"          confidence: medium

Plan            id, target_region_id, items[] (stage_id, sets, target), created_at
                evidence: "plan built against your weakest region"
                confidence: medium

Entitlement     product (weekly|yearly), status, trial_ends_at   (StoreKit, nicht persistiert)
```

Relationships: Region 1-n SkillLine 1-n Stage 1-n SetLog; SkillLine 1-1 LineProgress; Region 1-1 RegionGrade; Plan n-1 Region.

Formelentwurf (eigen, nicht vom Original):
`power = w1·overall_grade + w2·summe(cleared_stages) + w3·consistency(14d) + w4·log(volume_30d)`; Regionsgrad = Perzentil der höchsten Stufen ihrer Linien; Gesamtgrad = gewichtetes Mittel der Regionsgrade mit Malus für Streuung (bestraft schwächste Region).

## Feature matrix

See `features.csv`. Must: 11, should: 6, could: 5, skip: 3.

## Out of scope

- Name „Ranked“, Gradnamen (Bedrock, Zenith, Foothold, Ridge, Summit, Cirrus), Beschreibungstexte, Icons → eigene Benennung.
- Konkrete Zusammensetzung der 38 Linien und Stufenkriterien: allgemeines Calisthenics-Wissen ist frei, die konkrete Liste und Texte der App nicht kopieren; eigene Progressionen aus Fachliteratur ableiten.
- Formeln des Originals: unbekannt, eigene entwerfen.

## Size

Screens 13, Flows 5, Entities 10.
Hard parts:
1. Bewertungsmodell: Grade/Power müssen sich fair und motivierend anfühlen; braucht Kalibrierung mit echten Nutzerdaten.
2. Content-Design der 38 Linien mit sinnvollen Stufenkriterien (fachlich, kein Video nötig).
3. Paywall/StoreKit 2 mit Trial und Restore; Wochenabo-Pricing ist App-Review- und Retention-sensibel.
Kein Backend nötig (alles lokal) — größter Vereinfacher.
Size: S (Wochenende: Datenmodell, Log, Grade-Berechnung, 1 Screen je Kernschritt) bis M (wenige Wochen: Polish, Paywall, Verlauf, Plan, App-Store-Release).
