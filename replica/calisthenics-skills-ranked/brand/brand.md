# Brand: Kreide

Methodik: `replica-brand` (Git-History, Commit 6873202). Datum: 2026-10-15.
Kontext: zunächst **Eigengebrauch** (PERSONAL-Build). Markenprüfungen sind deshalb vorerst nicht nötig; vor jeder Veröffentlichung müssen sie laufen.
`replica/fixes.md` (replica-entrepreneur) existiert nicht → Angle aus Recon/Build: *ehrlich messen, was man kann – Stufen statt Wiederholungen, die schwächste Region zuerst.*

## 1. Name

20 Kandidaten:

| Stil | Kandidaten |
| --- | --- |
| beschreibend | Stufenwerk, Körpergrad, Skillgrad, Leiterlinie |
| zusammengesetzt | Gradwerk, Klimmwerk, Holdline, Barlevel |
| erfunden | Stufo, Gravit, Gradus |
| Metapher | **Kreide**, Magnesia, Kalk, Sprosse |
| Verb/Englisch | Rungs, Ascend, Barhold, Tier Bar, Rangstufe |

Gestrichen: alles mit „Rank/Ranked/Skills“ (Nähe zum Original), „Cali-“-Präfix (Kategorie überfüllt: Calistree, Caliverse, Calist, CaliStack, Calisteniapp), „Ascend“ (App „Ascend – Learn Calisthenics“ existiert), „Gradus“ (App „Gradus“ Notenrechner + „Gradux“ Kraft-App), „Rangstufe“ (Rang-Nähe), „Tier Bar“ (Wortspiel).

Shortlist und Checks:

| Name | Idee | App Store (Websuche) | Marke DE/EU/US/WIPO | Domain | Handles |
| --- | --- | --- | --- | --- | --- |
| **Kreide** (Empfehlung) | Magnesia an den Händen, Striche an der Tafel = Fortschritt markieren | 2026-10-15: kein Treffer „Kreide“ als Fitness-App | to run (DPMA, EUIPO eSearch, USPTO, WIPO; Klassen 9, 41, 42) | to run (kreide.app, kreideapp.de) | to run |
| Rungs | Sprossen einer Leiter = Stufen | 2026-10-15: kein Treffer | to run | to run | to run |
| Gradwerk | Werkstatt für Grade | 2026-10-15: kein Treffer | to run | to run | to run |
| Magnesia | Kletter-/Turn-Kreide | 2026-10-15: kein Treffer | to run; Achtung: Medikament/Mineral, generisch | to run | to run |
| Sprosse | Leitersprosse | to run | to run | to run | to run |

Die App-Store-Spalte stammt aus einer Websuche, nicht aus einer Store-Suche (apps.apple.com war in der Umgebung gesperrt). Das sind Vorprüfungen, keine Freigabe. Vor Geld für den Namen: Markenanwalt.
Risiko „Kreide“: im Englischen schwer aussprechbar, deutsches Alltagswort (schwache Unterscheidungskraft für Kreide-Produkte, für Software eher unkritisch).

## 2. Farben

Original: Markenfarben unbekannt (keine Screenshots) → in `brand.json` nachtragen, sobald bekannt.
Eigenes Konzept: **Tinte und Kreide.** Die Oberfläche bleibt monochrom (warmes Schwarz auf Hell, Kreideweiß auf Dunkel); Farbe tragen nur Grade (9) und Regionen (6). So konkurriert keine Markenfarbe mit der Bedeutung der Grade.

| Rolle | hell | dunkel |
| --- | --- | --- |
| accent / focus / power | `#24211d` | `#f1ede4` |
| on-accent | `#f4f1ea` | `#141210` |
| übrige Rollen | unverändert aus replica-design | |

Kontrast (`design/contrast.py`): hell 33 Paare, dunkel 34 Paare, **0 AA-Fehler**. accent auf bg 16,0 : 1 bzw. 16,4 : 1.
Nachteil: accent-Text (Labels wie „Schwächste“) unterscheidet sich farblich kaum von normalem Text → Hervorhebung über Gewicht/Rahmen, nicht Farbe. So umgesetzt (2-pt-Rahmen um schwächste Region).

## 3. Gradnamen

Original nutzt ein Berg-/Himmels-/Gesteins-Thema (Bedrock … Zenith, Foothold, Ridge, Summit, Cirrus). Bewusst anderes Thema: **Handwerksränge.**

| Grad | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Name | Anwärter | Lehrling | Geselle | Altgeselle | Meister | Obermeister | Großmeister | Ehrenmeister | Legende |

Liniengrade: römisch I–IV (neutral). Code: `GradeNames` in `app/App/Sources/Screens/Shared.swift`.

## 4. Logo-Brief

- **Idee:** drei Kreidestriche, die wie Stufen ansteigen – Fortschritt, mit der Hand markiert.
- **Typ:** Symbol plus Wortmarke „Kreide“; Symbol allein als App-Icon.
- **Stil:** Strich mit Kreidetextur am Rand, sonst flach; Kreideweiß auf warmem Schwarz `#24211d`.
- **Muss funktionieren:** 16 px (drei Striche bleiben lesbar → Textur bei kleinen Größen weglassen), 1024 × 1024 App-Icon ohne Transparenz.
- **Lieferung:** SVG (Symbol, Wortmarke, kombiniert), App-Icon 1024 × 1024 PNG, für Eigengebrauch reicht das Icon.
- **Darf nicht:** dem Icon des Originals ähneln (vor Freigabe nebeneinanderlegen); keine Berge, Gipfel, Abzeichen-/Wappenform, keine Rangsterne.
- **Für ein Bildmodell:** „flat app icon, three hand-drawn white chalk strokes rising like stairs from bottom left to top right, warm near-black background #24211d, subtle chalk texture on stroke edges, no text, centered, generous padding“.

## 5. Stimme

Drei Wörter:
- **ehrlich** – nicht hart: sagt, wo du stehst, ohne zu werten.
- **knapp** – nicht kalt: ein Satz statt drei, aber ganze Sätze.
- **ruhig** – nicht lahm: keine Ausrufezeichen, kein Hype, trotzdem Bewegung.

| Do | Don't |
| --- | --- |
| „Hier hängst du hinterher: Ziehen“ | „Deine Schwachstelle!!“ |
| „Abgehakt: Tuck Planche“ | „WOW, du bist ein Biest! 🔥“ |
| „Die Tafel ist noch leer“ | „Oops, hier ist nichts…“ |
| „Das geht nicht: bitte 1 bis 10 000.“ | „Ungültige Eingabe (Fehler 422)“ |
| „Unter dem Ziel. Zählt trotzdem.“ | „Leider nicht geschafft :(“ |

Die 10 meistgesehenen Texte (neu geschrieben, in `app/App/Sources/Screens/`):

| Ort | Text |
| --- | --- |
| S01 Titel | Kreide |
| S01 Unterzeile | Zählt nicht Wiederholungen, sondern Stufen. Jeder saubere Satz zeigt, wo du stehst – und welche Region dich zurückhält. |
| S01 Button | Einstufung starten · 12 Fragen, etwa zwei Minuten. |
| S02 Frage | ‹Linie›: Was gelingt dir heute sauber? |
| S03 schwächste Region | Hier hängst du hinterher: ‹Region› |
| S05 leer | Die Tafel ist noch leer · Trag deinen ersten Satz ein. Nur echte Sätze bewegen dein Power Level. |
| S08 Hinweis | Ziel erreicht – die Stufe wird abgehakt. / Unter dem Ziel. Zählt trotzdem für Konstanz und Volumen. |
| S08 Fehler | Das geht nicht: bitte 1 bis 10 000. |
| S09 Aufstieg | Du bist jetzt ‹Gradname›. · Abgehakt: ‹Stufe› |
| S09 Button | Weiter trainieren |

## 6. Sweep

`brand/sweep.py` (vendored, unverändert) mit `brand/brand.json`:

```bash
python3 -I brand/sweep.py app --config brand/brand.json          # Clean
python3 -I brand/sweep.py design/swift --config brand/brand.json # Clean
grep -rwil ridge app design/swift                                # leer
```

Erster Lauf: 29 Treffer — 3 echte (Pfad mit Ordnernamen in `PERSONAL.md`, ersetzt), 26 falsche („Ridge“ in „Bridge“; Begriff aus der Liste genommen, Wortgrenzen-Suche stattdessen). Zweiter Lauf: clean.
Nicht automatisch prüfbar, per Auge: App-Icon (noch keins), Startbildschirm (System), Anzeigename `Kreide` (project.yml).
Planungsordner `replica/` enthält den Namen des Originals absichtlich (Recon) und wird nicht ausgeliefert. Der App-Code liegt aktuell darunter (`replica/calisthenics-skills-ranked/app/`); vor einer Veröffentlichung in ein eigenes Repo/Verzeichnis ohne den Originalnamen im Pfad verschieben.

## Noch offen

- Markenfarben des Originals in `brand.json`, Sweep erneut.
- Marken-, Domain-, Handle-Checks (erst vor Veröffentlichung).
- App-Icon nach Brief erstellen, in Assets einbinden (`AppIcon`).
- Internes Target/Projekt heißt weiter `GradeApp` (nicht sichtbar).
