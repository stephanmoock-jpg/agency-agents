# Eigengebrauch: App auf dein iPhone bringen

Diese Variante ist für dich allein: alles frei, keine Paywall, kein StoreKit, keine Daten verlassen das Telefon.
Gesteuert über das Compiler-Flag `PERSONAL` in `project.yml`. Für einen späteren App-Store-Build das Flag entfernen.

## Was du brauchst

- Mac mit Xcode 15 oder neuer (iOS 17 SDK), kostenlos aus dem Mac App Store.
- iPhone mit iOS 17 oder neuer, USB-Kabel (oder später WLAN-Pairing).
- Apple-ID. Ein kostenloser Account reicht ("Personal Team"); Einschränkung siehe unten.
- Homebrew für XcodeGen: `brew install xcodegen`.

## Einmalig

```bash
cd app     # dieser Ordner
python3 -I tools/grading_ref.py --check     # Referenz ok?
python3 -I tools/edge_tests.py
(cd Packages/GradingKit && swift test)      # Bewertungslogik in Swift ok?
```

1. In `project.yml` beide `com.example.gradeapp` durch eine eigene, eindeutige ID ersetzen, z. B. `de.deinname.gradeapp`.
2. `xcodegen` ausführen, dann `open GradeApp.xcodeproj`.
3. Xcode → Settings → Accounts → Apple-ID hinzufügen.
4. Projekt `GradeApp` → Target `GradeApp` → Signing & Capabilities → Team: dein "Personal Team" (oder dein bezahlter Account).
5. iPhone anschließen, entsperren, „Diesem Computer vertrauen“.
6. iPhone: Einstellungen → Datenschutz & Sicherheit → Entwicklermodus → an, Neustart.
7. In Xcode oben das iPhone als Ziel wählen, `Cmd-R`.
8. Beim ersten Start: iPhone → Einstellungen → Allgemein → VPN & Geräteverwaltung → Entwickler-App → vertrauen. Erneut `Cmd-R`.

Vorher im Simulator testen: Ziel „iPhone 16“, `Cmd-R`; Tests mit `Cmd-U`.

## Was du wissen musst

- **Kostenloser Account:** Die App läuft 7 Tage, dann startet sie nicht mehr. Mit `Cmd-R` aus Xcode neu installieren — die Daten bleiben erhalten, solange du die App nicht löschst und die Bundle-ID gleich bleibt. Max. 3 eigene Apps gleichzeitig.
- **Bezahlter Account (99 €/Jahr):** 1 Jahr Laufzeit, TestFlight möglich.
- **Datensicherung:** Alles liegt nur auf dem iPhone. App löschen = Daten weg. Regelmäßig Einstellungen (Zahnrad) → „Sätze als CSV exportieren“. iPhone-Backups (iCloud/Finder) enthalten die App-Daten ebenfalls.
- **Ungebaut:** Der Code wurde nie kompiliert (kein Mac in der Entwicklungsumgebung). Rechne beim ersten `Cmd-R` mit Compilerfehlern. Reihenfolge: zuerst `swift test` in `Packages/GradingKit` grün, dann App bauen. Fehlermeldungen einfach zurückgeben.
- **Schwierigkeitswerte** der 199 Stufen sind eigene Schätzungen. Wenn sich Grade falsch anfühlen: Werte in `App/Resources/catalog.json` ändern, `cp App/Resources/catalog.json Packages/GradingKit/Tests/GradingKitTests/Resources/`, `python3 -I tools/grading_ref.py --write`, neu bauen.
- **Training auf eigenes Risiko.** Die Stufen sind Richtwerte, keine Trainerberatung.

## Was beim Selbsttest beobachten

- Einstufung (12 Fragen): fühlt sich der Startgrad plausibel an?
- Satz loggen: wie viele Taps im Alltag, fehlt etwas (z. B. Pausentimer)?
- Grad/Power nach 1–2 Wochen: steigt es zu schnell, zu langsam?
- Plan: sind die vorgeschlagenen Stufen machbar?
- Notizen dazu helfen beim Kalibrieren von `GradingConfig` und `catalog.json`.
