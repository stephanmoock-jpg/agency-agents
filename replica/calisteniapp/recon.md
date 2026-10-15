# Recon map: Calisteniapp (iOS, Android, Web-Marketing)

Scope: Kern-Loop — Level-Einstufung → Programm/EVO-Routine → geführtes Workout → Feedback/Anpassung → Tracking. Skills-Tutorials, Challenges, Custom-Workout-Builder als zweiter Ring.
For: eigenes Produkt des Nutzers (Annahme, nicht bestätigt).
Date: 2026-10-15

## Methodik und Grenzen

- Quelle der Methodik: `replica-recon`-Skill (aus Git-History, Commit a6fce94; in dieser Session nicht installiert).
- `calisteniapp.com`, `apps.apple.com`, `play.google.com`, `help.calisteniapp.com` waren aus der Cloud-Umgebung nicht erreichbar (Egress-Proxy: connect_rejected). Alle Angaben stammen aus Suchergebnis-Snippets öffentlicher Seiten.
- Keine Screenshots erfasst. `screens/` ist leer. Spalte "states seen" = **inferiert**, nicht beobachtet.
- Kein Login, kein Scraping, keine App-Bundles, keine API-Mitschnitte.

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | Marketing-Site | https://calisteniapp.com/de | nicht abrufbar (Proxy) |
| 2 | Marketing-Site EN | https://calisteniapp.com/ | nur Titel im Snippet |
| 3 | Help Center FAQ | https://help.calisteniapp.com/en/docs/faqs | Kategorien: My Subscription, Workouts (Challenges, Custom Workouts, Warm-up/Stretching, Schwierigkeit anpassen) |
| 4 | App Store | https://apps.apple.com/us/app/calisteniapp-fit-strong/id1265489771 | 40+ Programme, 700+ Übungen, 500+ freie Routinen, Health-Sync, Watch-App, Preise |
| 5 | Google Play | https://play.google.com/store/apps/details?id=me.inakitajes.calisteniapp | Workout-Builder, Kalender, Achievements, 4.6★ / 39.4K |
| 6 | EVO-Routine-Seite (Web) | https://calisteniapp.com/smart/back_and_biceps_muscle_building/SP004 | Level-Test, Voraussetzungen, Frequenz 1–3×/Woche |
| 7 | EVO-Routine-Seite (Web) | https://calisteniapp.com/smart/your_first_muscle_up/SP010 | Level "beginner", Voraussetzung Pull-/Chin-ups |
| 8 | Blog-Artikel | https://calisteniapp.com/articles/order-calisthenics-tricks | Skill-Reihenfolge |
| 9 | Blog-Artikel | https://calisteniapp.com/articles/Creating-and-Designing-Calisthenics-Routines-is-an-ArtLearn-It-with-Me | 24 EVO-Routinen; früherer Name "Smart Progress" |
| 10 | Changelog (APKMirror) | https://www.apkmirror.com/apk/calisteniapp-s-l/calisteniapp-workout/calisteniapp-workout-programs-26-5-1-release/ | Mai 2026: überarbeitete EVO-Level-Tests |
| 11 | Review | https://calisthenics.com/calisteniapp-review/ | 2 Mio. Downloads |
| 12 | Review | https://fitloop.app/blog/best-calisthenics-apps | Preis PRO $8.99–9.49/Monat, $59.99/Jahr |
| 13 | Review | https://recime.app/blog/?p=2104 | UI dicht für Einsteiger; kein Coaching, kein Weighted-Calisthenics |

## Core loop

Nutzer macht einen Level-Test, bekommt eine adaptive Routine (EVO), trainiert geführt, gibt Feedback, und die nächste Session passt Sätze/Wdh./Pause automatisch an. Das ist der PRO-Paywall-Kern.

## Screens

Alle IDs aus öffentlichen Beschreibungen abgeleitet; Routen der App unbekannt.

| ID | screen | route / how to reach | purpose | key components | states seen (inferiert) |
| --- | --- | --- | --- | --- | --- |
| S01 | Onboarding-Fragebogen | Erststart | Ziel, Level, Equipment (Klimmzugstange optional) erfassen | Choice-Cards, Progress-Stepper | filled |
| S02 | Programm-Empfehlung | nach S01 | empfohlenes Programm anzeigen | Program-Card, CTA | filled |
| S03 | Paywall / PRO | Lock-Icon, nach S02 | Upgrade Monat/Jahr | Plan-Toggle, Feature-Liste, IAP | filled, error (Kauf fehlgeschlagen), restore |
| S04 | Home / Heute | Tab | nächste Session, aktive Programme/Challenges | Hero-Card, Carousels | empty, filled |
| S05 | Programm-Katalog | Tab "Programme" | 40+ Programme filtern | Filter-Chips (Ziel, Level, Equipment), Card-Grid, Lock-Badge | filled, locked |
| S06 | Programm-Detail | S05 → Card | Wochenplan, Dauer, Level | Header-Bild, Wochen-Liste, Start-CTA | not started, in progress |
| S07 | EVO-Routine-Detail | Katalog / Web `/smart/<slug>/<SPnnn>` | Beschreibung, Voraussetzungen, Frequenz | Prereq-Liste, Level-Badge, Start-CTA | not started, configured |
| S08 | EVO-Level-Test | S07 → Start | Startniveau bestimmen | Test-Übung, Wdh.-Eingabe | filled, invalid input |
| S09 | Routinen-Bibliothek | Tab/Suche | 500+ freie Routinen | Suche, Liste, Filter | empty search, filled |
| S10 | Workout-Player | Start aus S04/S06/S07/S09 | Übung für Übung geführt | Video-Loop, Satz/Wdh.-Zähler, Rest-Timer, Skip/Weiter | running, paused, rest, finished |
| S11 | Session-Feedback | Ende S10 | Schwierigkeit/Wdh. melden → EVO-Anpassung | Rating-Scale, Wdh.-Eingabe | filled |
| S12 | Session-Zusammenfassung | nach S11 | Dauer, Volumen, Muskeln | Stat-Tiles, Muscle-Map | filled |
| S13 | Skills-Übersicht | Tab "Skills" | Handstand, Muscle-up, Front/Back Lever, Planche, Human Flag | Skill-Cards, Fortschritt | locked, in progress |
| S14 | Skill-Tutorial | S13 → Card | Progressionsstufen mit Video | Step-Liste, Video, Kriterien | per step: locked/done |
| S15 | Übungsdatenbank | Suche | 700+ Übungen | Suche, Muskel-Filter | empty, filled |
| S16 | Übungs-Detail | S15 / S10 Info | Ausführung, Muskeln | Video, Cues, Muscle-Map | filled |
| S17 | Challenges-Liste | Tab/Home | 21-Tage-Challenges | Cards, Anmelde-CTA | not joined, joined, locked |
| S18 | Challenge-Detail / Tagesplan | S17 → Card | 21 Tage, Tagesstatus | Day-Grid, Streak | day done / missed / today |
| S19 | Workout-Builder | "Eigenes Workout" | Routine aus Ziel, Zeit, Übungen erstellen | Übungs-Picker, Sätze/Wdh./Zeit, Reorder | empty, draft, saved |
| S20 | Kalender / Historie | Tab "Fortschritt" | Session-Log | Monatskalender, Log-Liste | empty, filled |
| S21 | Statistik | S20 | Metriken (PRO: erweitert) | Charts, Muscle-Map | free, PRO |
| S22 | Achievements | Profil | Abzeichen | Badge-Grid | locked, unlocked |
| S23 | Profil / Einstellungen | Tab | Abo, Health-Sync, Sprache, Einheiten | Settings-List | — |
| S24 | Abo-Verwaltung | S23 | Plan wechseln, kündigen, wiederherstellen | Plan-Info, Store-Deeplink | active, expired |
| S25 | Watch-Workout | Apple Watch | Session vom Handgelenk | Satz-Zähler, Timer, HR | running |
| W01 | Web-Landing | `/`, `/de` | Positionierung, Store-Links | Hero, Feature-Blöcke | — |
| W02 | Web-EVO-Seiten | `/smart/<slug>/<SPnnn>` | SEO-Seite pro Routine | Text, Prereqs | — |
| W03 | Web-Artikel | `/articles/<slug>` | SEO-Content | Artikel | — |

## Flows

```
F01 Neuer Nutzer startet erstes Training
    S01 -> S02 -> (S03 skip) -> S06 -> S10 -> S11 -> S12
    happy path clicks: ~8 (geschätzt)
    edge: kein Equipment, Paywall abgelehnt, Abbruch mitten in Session

F02 Adaptive EVO-Routine (Kern-Loop, PRO)
    S07 -> S03 (falls Free) -> S08 -> S10 -> S11 -> [EVO passt nächste Session an] -> S20
    happy path clicks: ~6
    edge: Level-Test zu schwer (0 Wdh.), Voraussetzungen nicht erfüllt, Session ausgelassen, Feedback übersprungen

F03 Skill lernen
    S13 -> S14 -> Step-Video -> Step als erreicht markieren -> nächster Step
    edge: Step-Kriterium nicht erreicht, Rückstufung

F04 21-Tage-Challenge
    S17 -> Anmelden -> S18 (Tag n) -> S10 -> S11 -> S18 (Tag done)
    edge: Tag verpasst, Neustart, PRO-gesperrt

F05 Eigenes Workout bauen
    S19 -> Übungen wählen (S15) -> Parameter -> Speichern -> S10
    edge: leeres Workout, Reihenfolge ändern, löschen

F06 Abo
    S03 -> Store-Kauf -> PRO aktiv ; S24 -> kündigen/wechseln/wiederherstellen (Gerätewechsel)
    edge: Kauf abgebrochen, Restore findet nichts, Plattformwechsel iOS↔Android
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Button | primary, secondary, ghost, PRO-CTA | default, pressed, disabled, loading | alle |
| Content-Card | program, routine, skill, challenge | default, locked (PRO), in progress, done | S04, S05, S09, S13, S17 |
| Filter-Chips | Ziel, Level, Equipment, Muskel | on/off | S05, S09, S15 |
| Video-Loop-Player | inline, fullscreen | loading, playing, error | S10, S14, S16 |
| Rep/Set-Counter | Wdh., Zeit (Hold), Satz | active, done | S10, S19, S25 |
| Rest-Timer | ring, compact | running, paused, skip | S10, S25 |
| Feedback-Scale | Schwierigkeit 1–5, Wdh.-Eingabe | — | S08, S11 |
| Muscle-Map | front, back | highlight intensity | S12, S16, S21 |
| Calendar | month | day empty/trained/today | S18, S20 |
| Stat-Tile | value, delta | free, PRO-blurred | S12, S21 |
| Badge | achievement | locked, unlocked | S22 |
| Paywall-Sheet | monthly, yearly | default, purchasing, error | S03 |
| Stepper | onboarding, progression | current, done | S01, S14 |

## Inferred data model

```
User            id, goal, level, equipment[], locale, units, is_pro, created_at
                evidence: S01 (Onboarding), "recommended program based on level and goal"
                confidence: high

Subscription    id, user_id, store (apple|google), plan (monthly|yearly), status, renews_at
                evidence: FAQ "My Subscription" (cancel, switch, restore on phone change)
                confidence: high

Exercise        id, name, video_url, muscles[], equipment[], type (reps|hold), cues
                evidence: 700+ Übungen, Muscle-Map, Tutorials
                confidence: high

Routine         id, name, level, exercises[] (exercise_id, sets, reps|seconds, rest), is_pro, source (official|user)
                evidence: 500+ freie Routinen, Workout-Builder
                confidence: high

Program         id, name, goal, level, weeks, schedule[] (day -> routine_id), is_pro
                evidence: 40+ guided programs, Wochenplan
                confidence: medium

EvoRoutine      id (SPnnn), slug, goal, prerequisites, frequency_per_week, level_test (exercise_ids), progression_rules
                evidence: /smart/<slug>/SP004, SP010; "Level-Test", "1–3×/Woche"
                confidence: high (Felder), guess (progression_rules)

EvoState        user_id, evo_routine_id, current_level, current_targets (per exercise), last_feedback
                evidence: "adjusts every time you complete it based on your feedback"
                confidence: medium

Challenge       id, name, days (21), day_plan[] (day -> routine_id), is_pro
UserChallenge   user_id, challenge_id, started_at, days_done[]
                evidence: "21-day challenges", FAQ "how to sign up"
                confidence: medium

Skill           id, name, steps[] (order, exercise_id, criterion)
UserSkillProgress user_id, skill_id, current_step
                evidence: Skill-Tutorials, Artikel "order-calisthenics-tricks"
                confidence: medium

Session         id, user_id, routine_id, program_id?, evo_routine_id?, challenge_id?, started_at, duration, sets_logged[] (exercise_id, reps|seconds), feedback
                evidence: Kalender mit Session-Logs, Health-Sync
                confidence: high

Achievement     id, name, rule ; UserAchievement user_id, achievement_id, unlocked_at
                evidence: Play-Listing "achievements"
                confidence: medium
```

Relationships: User 1-n Session; Routine n-n Exercise; Program 1-n Routine; EvoRoutine 1-n EvoState (pro User); Challenge 1-n UserChallenge; Skill 1-n Step→Exercise; Session n-1 Routine.

## Feature matrix

See `features.csv`. Must: 13, should: 10, could: 5, skip: 3.

## Out of scope (cannot or should not be cloned)

- Video-/Bildmaterial der Übungen und Tutorials (Eigentum von Calisteniapp, S.L.) — eigene Videos produzieren.
- Konkrete Programm- und Routineninhalte, Texte, Namen ("EVO", "Calisteniapp") — eigene Progressionen und Marke.
- Nutzerbasis / Community-Beiträge.
- Sicherheitsrelevant: Trainingsempfehlungen ohne Coaching-Anspruch; kein medizinischer Rat.

## Size

Screens 25 (+3 Web), Flows 6, Entities 14.
Hard parts:
1. Adaptiv-Engine (EVO): Progressionsregeln sind nicht öffentlich, müssen selbst entworfen und validiert werden.
2. Content-Produktion: 700+ Übungsvideos, Programme, Skill-Progressionen — Aufwand übersteigt die Software.
3. Cross-Platform-Abos (StoreKit + Play Billing, Restore, Plattformwechsel) plus Watch-App und Health-Sync.
Size: L (Software ein Quartal für iOS+Android mit kleinem Startkatalog); mit vollem Content-Umfang XL.
