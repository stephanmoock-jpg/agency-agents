# Components: eigene App (Nachbau Calisthenics Skills – Ranked)

Basis: `tokens.json`, `tokens.dark.json` → `swift/DesignTokens.swift` (generiert). Screen-IDs aus `../recon.md`.
Grundlage: **eigener Entwurf**. Keine Screenshots des Originals vorhanden; nichts gemessen, nichts übernommen.

## Regeln

- Icons: SF Symbols (Apple-Lizenz für Apple-Plattformen) oder Lucide (ISC). Keine Icons/Illustrationen des Originals.
- Schrift: System (SF Pro / SF Pro Rounded für Zahlen). Dynamic Type bis AX5; Layout darf umbrechen, nicht abschneiden.
- Texte: alle neu schreiben. Gradnamen sind Platzhalter `Grad 1…9`, Liniengrade `Stufe I…IV` bis replica-brand eigene Namen vergibt (nicht Bedrock/Zenith/Foothold/Ridge/Summit/Cirrus).
- Farbe ist nie alleiniger Informationsträger: Grade immer mit Zahl/Name, Regionen immer mit Label.
- Tap-Ziele ≥ 44 pt. Fokus/Selektion über System. Haptik: `.success` bei Stufe geschafft, `.impact(.rigid)` bei Grad-Aufstieg; aus, wenn System-Haptik aus.
- Reduce Motion: Springs → 0,2 s Crossfade, Zähler springen auf Endwert.
- Akzentfarbe `accent` ist Platzhalter (replica-brand).

## Specs

```
GradeBadge                                             swift/Primitives.swift
  variants  overall (1–9), region (1–9), line (I–IV)
  sizes     sm 28pt, md 44pt, lg 96pt (S03 Reveal)
  states    default, locked (PRO: Füllung track, Schloss-Symbol), animating (Grad-Aufstieg)
  tokens    fill grade-n, text on-grade / on-grade-9, ring grade-ring 1pt, radius pill, font grade (lg) / headline (md)
  a11y      ein Element, Label "Gesamtgrad 5 von 9" bzw. "Push, Grad 3 von 9"; locked: Hinweis "Mit PRO sichtbar"
  used on   S03, S05, S06, S07, S11, S12

PowerMeter
  variants  hero (S03/S05), compact (S09 Toast)
  states    static, delta (+n hochzählend, success-Farbe; −n textMuted), empty (0, Hinweis "Ersten Satz loggen")
  tokens    zahl font power text, delta success/textMuted, Balken power auf track, radius pill
  a11y      Label "Power Level 1240", Wert-Änderung per AccessibilityNotification.Announcement "+35"
  used on   S03, S05, S09

RegionBars
  variants  bars (Standard), radar (could; nur zusätzlich, nie allein)
  states    default, weakest (Label "Schwächste" + Rahmen accent 2pt), locked (PRO: Werte verborgen, Balken track)
  tokens    region-<id> auf track, label text, wert textMuted, gap space s2
  a11y      jede Zeile ein Element "Pull, Grad 4 von 9, schwächste Region"; Reihenfolge fest nach Region-sort
  used on   S03, S05, S11

StageChain
  variants  vertikal (S07)
  states    je Stufe: locked (Kreis border, text textMuted), current (Kreis accent, Kriterium fett, Log-CTA), cleared (Kreis success + Haken)
  tokens    Linie border 2pt, Kreis 28pt, space s4 zwischen Stufen
  a11y      Liste; Element "Stufe 7 von 12, Tuck Planche, 10 Sekunden halten, aktuell"; aktuelle Stufe initial fokussiert
  used on   S07, S02 (Auswahl-Variante)

LineRow
  variants  default, compact (S11)
  states    not started, in progress (x/n), maxed
  tokens    surface-raised, radius md, Fortschritt accent auf track, GradeBadge line sm
  a11y      Label "Planche, Stufe 7 von 12, Liniengrad II", Trait button
  used on   S06, S11

NumberStepper
  variants  reps, seconds
  states    default, min (−deaktiviert bei 1), max, editing (Tastatur .numberPad), invalid (danger + Text)
  tokens    Zahl font power, Buttons 44pt surface radius md, Rahmen border-input
  a11y      accessibilityAdjustableAction (Wischen hoch/runter), Label "Wiederholungen, 8"
  used on   S08, S02

HoldTimer
  variants  stopwatch (seconds-Stufen)
  states    idle, running, stopped (übernimmt Wert in NumberStepper)
  tokens    Ring accent auf track, Zahl font power
  a11y      Start/Stopp ein Button mit wechselndem Label; Sekunden-Ansagen alle 10 s optional
  used on   S08

PrimaryButton / SecondaryButton / GhostButton
  sizes     md 50pt (volle Breite), sm 36pt
  states    default, pressed (opacity 0.85), disabled (opacity 0.4), loading (ProgressView, Label bleibt für VoiceOver)
  tokens    primary: accent / on-accent; secondary: surface / text, Rahmen border; ghost: text accent; radius md; font headline
  a11y      Button, Doppeltipp-Schutz: deaktiviert während async Aktion (verhindert Doppel-Log, siehe architecture.md)
  used on   alle

LevelUpSheet
  variants  stage cleared, grade up (gesamt/region/linie)
  states    presenting (GradeBadge lg animating), done
  tokens    surface-raised, radius lg, Badge grade-n
  a11y      Sheet mit Titel als Überschrift, Announcement beim Erscheinen; Haptik s. Regeln
  used on   S09

LogToast
  variants  power delta, undo
  states    visible 4 s, dismissed
  tokens    surface-raised, shadow card, radius pill, font footnote
  a11y      Announcement; Undo als eigener Button, 4 s → bei VoiceOver an: bleibt bis Wischen
  used on   S09

PaywallSheet
  variants  SubscriptionStoreView (System) mit eigenem Header
  states    default, purchasing, error, restored, trial-eligible / not eligible
  tokens    Header bg, Features text, CTA System
  a11y      System-Komponente; Preis/Laufzeit/Trial im Klartext (Guideline 3.1.2), Restore + AGB + Datenschutz-Links sichtbar
  used on   S04

HistoryChart                                           (Swift Charts)
  variants  grade (Stufenlinie), power (Linie)
  states    empty (< 2 Snapshots: Erklärtext), filled, locked (PRO)
  tokens    Linie accent, Raster border, Achsen textMuted caption
  a11y      Swift Charts AXChartDescriptor; Audio Graph aktiv
  used on   S12

QuestionStep (Einstufung)
  variants  region-intro, line-question
  states    unanswered, answered, skipped ("Weiß nicht" → 0)
  tokens    Fortschritt accent auf track, Optionen als StageChain-Auswahl
  a11y      Fortschritt "Frage 4 von 18"
  used on   S02

EmptyState
  variants  noLogs (S05), noHistory (S12), noPlan (S10)
  tokens    SF Symbol 40pt textMuted, Titel headline, Text body textMuted, PrimaryButton
  used on   S05, S10, S12
```

## Screens → Komponenten

| Screen | Komponenten |
| --- | --- |
| S01 Intro | GradeBadge lg (Demo), PrimaryButton |
| S02 Einstufung | QuestionStep, StageChain (Auswahl), NumberStepper, PrimaryButton, GhostButton |
| S03 Ergebnis | GradeBadge lg, PowerMeter hero, RegionBars, PrimaryButton |
| S04 Paywall | PaywallSheet |
| S05 Dashboard | GradeBadge md, PowerMeter hero, RegionBars, LineRow (nächste Stufe), EmptyState |
| S06 Skills | LineRow, Segment-Filter (System Picker) |
| S07 Linie | GradeBadge line, StageChain, PrimaryButton |
| S08 Log | NumberStepper, HoldTimer, PrimaryButton |
| S09 Feedback | LogToast, LevelUpSheet, PowerMeter compact |
| S10 Plan | LineRow compact, EmptyState |
| S11 Region | GradeBadge region, LineRow compact |
| S12 Verlauf | HistoryChart, EmptyState |
| S13 Einstellungen | System Form |
