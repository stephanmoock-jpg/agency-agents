#!/usr/bin/env python3
"""Edge-/Negativtests der Bewertungslogik gegen die Referenz (grading_ref.py).

    python3 -I edge_tests.py
Fall-IDs wie in ../../test-plan.md.
"""
import copy
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grading_ref as g  # noqa: E402

C = g.load_catalog()
results = []


def case(cid, fn):
    try:
        fn()
        results.append((cid, "PASS", ""))
    except AssertionError as e:
        results.append((cid, "FAIL", str(e)))
    except Exception as e:  # Absturz ist ebenfalls ein Fehlschlag
        results.append((cid, "FAIL", "%s: %s" % (type(e).__name__, e)))


def ev(logs, claims=None, cat=C):
    return g.evaluate(cat, logs, claims or {}, g.NOW_TS, g.NOW_DAY)


# F02-N1: Wert 0 (per Tastatur eingegeben) darf weder Konstanz noch Power erzeugen.
def f02_n1():
    r = ev([g.mk("pushup.01", 0)])
    assert r["power"] == 0, "Satz mit Wert 0 erzeugt Power %d" % r["power"]

# F02-N2: negativer Wert ebenso.
def f02_n2():
    r = ev([g.mk("pushup.01", -5)])
    assert r["power"] == 0, "negativer Wert erzeugt Power %d" % r["power"]

# F02-E1: extrem großer Wert wird beim Volumen gedeckelt.
def f02_e1():
    assert ev([g.mk("hang.01", 10**9)])["power"] == ev([g.mk("hang.01", 60)])["power"]

# F02-E2: Doppel-Log desselben Satzes am selben Tag erhöht nur Volumen, nicht Stufen/Konstanz.
def f02_e2():
    a, b = ev([g.mk("squat.02", 30)]), ev([g.mk("squat.02", 30)] * 2)
    assert a["cleared_stages"] == b["cleared_stages"]
    assert b["power"] - a["power"] < 60, "Doppel-Log bringt %d Power" % (b["power"] - a["power"])

# F02-E3: Satz exakt am Ziel schaltet frei, Ziel-1 nicht.
def f02_e3():
    assert ev([g.mk("pullup.03", 1)])["highest_logged"]["pullup"] == 3
    assert ev([g.mk("pullup.04", 7)])["highest_logged"]["pullup"] == 0

# F03-E1: höhere Stufe geschafft ohne niedrigere -> höchste zählt.
def f03_e1():
    assert ev([g.mk("pushup.06", 12)])["highest_logged"]["pushup"] == 6

# F03-E2: kein Gradabstieg durch Pause, nur Power sinkt.
def f03_e2():
    now = ev([g.mk("pushup.06", 12, 0)])
    old = ev([g.mk("pushup.06", 12, 60)])
    assert old["overall_grade"] == now["overall_grade"]
    assert old["power"] < now["power"]

# F01-E1: Einstufung über Maximum wird auf letzte Stufe begrenzt.
def f01_e1():
    r = ev([], {"hang": 99})
    assert r["line_grades"]["hang"] == g.grade_from(C["lines"][10]["stages"][-1]["difficulty"], g.LINE_GRADE_THRESHOLDS, 0)

# F01-E2: Einstufung mit 0 überall = leerer Zustand.
def f01_e2():
    assert ev([], {l["id"]: 0 for l in C["lines"]}) == ev([])

# F01-N1: Einstufung erzeugt nie Power.
def f01_n1():
    assert ev([], {l["id"]: len(l["stages"]) for l in C["lines"]})["power"] == 0

# F01-E3: maximale Einstufung ergibt Grad 9 nicht automatisch (Schwierigkeit < 1), aber hoch.
def f01_e3():
    r = ev([], {l["id"]: len(l["stages"]) for l in C["lines"]})
    assert 7 <= r["overall_grade"] <= 9, "max. Einstufung ergibt Grad %d" % r["overall_grade"]

# F04-E1: zwei Regionen gleich schwach -> weniger Logs der letzten 14 Tage gewinnt, dann sort.
def f04_e1():
    r = ev([g.mk("pushup.01", 20)])   # push hat Log, alle Scores ~0 außer push
    assert r["weakest"] != "push"
    r2 = ev([])
    assert r2["weakest"] == "push"   # Gleichstand ohne Logs -> sort 1

# F04-E2: Linie komplett -> Plan nimmt andere Linie / nächste Region.
def f04_e2():
    logs = [g.mk(sid, 999) for l in C["lines"] if l["region"] == "grip" for sid in l["stage_ids"]]
    r = ev(logs)
    p = g.plan(C, r)
    assert all(not it["stage"].startswith(("hang.", "fingers.")) for it in p["items"])
    assert p["items"], "Plan leer, obwohl andere Regionen offen sind"

# F04-E3: alles geschafft -> leerer Plan, kein Absturz.
def f04_e3():
    logs = [g.mk(sid, 999) for l in C["lines"] for sid in l["stage_ids"][-1:]]
    p = g.plan(C, ev(logs))
    assert p["items"] == []

# X-E1: Zeitzone/Sommerzeit: Tagesfenster über DST-Wechsel (Europa 25.10.2026) bleibt 14 Kalendertage.
def x_e1():
    w = {g.day_minus("2026-11-01", i) for i in range(14)}
    assert len(w) == 14 and "2026-10-25" in w and "2026-10-19" in w

# X-E2: Schaltjahr.
def x_e2():
    assert g.day_minus("2028-03-01", 1) == "2028-02-29"

# X-E3: Log am Vortag kurz vor Mitternacht lokal zählt für den lokalen Tag, nicht UTC.
def x_e3():
    log = {"stage": "squat.02", "value": 30, "ts": g.ts_of("2026-10-15", 1), "day": "2026-10-14"}
    r = ev([log])
    r2 = ev([log, g.mk("squat.02", 30, 0)])
    assert r2["power"] > r["power"], "zweiter lokaler Tag zählt nicht"

# X-E4: umbenannte Stage-ID (Katalog-Update) wird aufgelöst.
def x_e4():
    cat = copy.deepcopy(json.load(open(g.CATALOG, encoding="utf-8")))
    cat["renamed"] = {"pushup.99": "pushup.04"}
    path = os.path.join(os.path.dirname(g.VECTORS), "..", "..", "..", ".tmp_catalog.json")
    path = os.path.abspath(path)
    json.dump(cat, open(path, "w", encoding="utf-8"))
    try:
        c2 = g.load_catalog(path)
        r = ev([g.mk("pushup.99", 10)], cat=c2)
        assert r["highest_logged"]["pushup"] == 4, "umbenannte ID nicht aufgelöst"
    finally:
        os.remove(path)

# X-P1: Performance: 10 000 Logs < 1 s.
def x_p1():
    logs = [g.mk("squat.02", 30, i % 60) for i in range(10_000)]
    t = time.perf_counter(); ev(logs); dt_ = time.perf_counter() - t
    assert dt_ < 1.0, "%.2f s für 10k Logs" % dt_

# X-M1: Monotonie: zusätzlicher geschaffter Satz senkt nie den Gesamtscore.
def x_m1():
    import random
    rnd = random.Random(7)
    ids = list(C["stage_map"])
    for _ in range(300):
        logs = [g.mk(rnd.choice(ids), rnd.randint(1, 40), rnd.randint(0, 20)) for _ in range(rnd.randint(0, 15))]
        extra = g.mk(rnd.choice(ids), 999)
        a, b = ev(logs), ev(logs + [extra])
        assert b["overall_score"] >= a["overall_score"] - 1e-9, "Score sinkt durch geschafften Satz"
        assert b["power"] >= a["power"], "Power sinkt durch geschafften Satz"


for cid, fn in [("F01-E1", f01_e1), ("F01-E2", f01_e2), ("F01-E3", f01_e3), ("F01-N1", f01_n1),
                ("F02-E1", f02_e1), ("F02-E2", f02_e2), ("F02-E3", f02_e3), ("F02-N1", f02_n1), ("F02-N2", f02_n2),
                ("F03-E1", f03_e1), ("F03-E2", f03_e2),
                ("F04-E1", f04_e1), ("F04-E2", f04_e2), ("F04-E3", f04_e3),
                ("X-E1", x_e1), ("X-E2", x_e2), ("X-E3", x_e3), ("X-E4", x_e4), ("X-P1", x_p1), ("X-M1", x_m1)]:
    case(cid, fn)

for cid, res, msg in results:
    print("  %-7s %s %s" % (cid, res, msg))
fails = sum(1 for r in results if r[1] == "FAIL")
print("%d Fälle, %d bestanden, %d fehlgeschlagen" % (len(results), len(results) - fails, fails))
sys.exit(1 if fails else 0)
