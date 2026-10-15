#!/usr/bin/env python3
"""Referenzimplementierung des Grading-Modells (architecture.md, Abschnitt Grading-Modell).

Orakel für GradingKit (Swift). Beide lesen dieselben Testfälle aus
Packages/GradingKit/Tests/GradingKitTests/Resources/vectors.json.

    python3 -I grading_ref.py --check      # Katalog prüfen, Eigenschaftstests, Vektoren vergleichen
    python3 -I grading_ref.py --write      # vectors.json neu erzeugen (nach bewusster Modelländerung)
"""
import datetime as dt
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CATALOG = os.path.join(HERE, "..", "App", "Resources", "catalog.json")
VECTORS = os.path.join(HERE, "..", "Packages", "GradingKit", "Tests", "GradingKitTests", "Resources", "vectors.json")

# GradingConfig — identisch in GradingKit/Grading.swift halten.
LINE_GRADE_THRESHOLDS = [0.15, 0.40, 0.65, 0.85]
OVERALL_GRADE_THRESHOLDS = [0.05, 0.12, 0.20, 0.30, 0.42, 0.55, 0.70, 0.85]   # 8 Schwellen -> Grade 1..9
TOP_K = 3
TOP_K_FACTOR = 2.0
OTHER_FACTOR = 0.25   # Linien außerhalb der Top-k: wenig Gewicht, damit untrainierte Linien die Region nicht verwässern
BALANCE_BASE = 0.7
BALANCE_WEIGHT = 0.3
CONSISTENCY_DAYS = 14
VOLUME_DAYS = 30
VOLUME_CAP_PER_SET = 3.0
W_SCORE, W_STAGES, W_CONSISTENCY, W_VOLUME = 1000.0, 15.0, 300.0, 120.0


def load_catalog(path=CATALOG):
    c = json.load(open(path, encoding="utf-8"))
    stages = {}
    for line in c["lines"]:
        line["stage_ids"] = []
        for i, s in enumerate(line["stages"], start=1):
            sid = "%s.%02d" % (line["id"], i)
            s["id"], s["idx"], s["line"] = sid, i, line["id"]
            stages[sid] = s
            line["stage_ids"].append(sid)
    c["stage_map"] = stages
    c.setdefault("renamed", {})
    return c


def usable_logs(c, logs):
    """Wie GradingKit: umbenannte IDs auflösen, unbekannte IDs und Werte <= 0 ignorieren."""
    out = []
    for g in logs:
        sid = c["renamed"].get(g["stage"], g["stage"])
        if sid in c["stage_map"] and g["value"] > 0:
            out.append({**g, "stage": sid})
    return out


def validate_catalog(c):
    errs = []
    region_ids = [r["id"] for r in c["regions"]]
    if len(region_ids) != len(set(region_ids)):
        errs.append("doppelte Region-IDs")
    line_ids = [l["id"] for l in c["lines"]]
    if len(line_ids) != len(set(line_ids)):
        errs.append("doppelte Linien-IDs")
    for l in c["lines"]:
        if l["region"] not in region_ids:
            errs.append("%s: unbekannte Region %s" % (l["id"], l["region"]))
        if not l["stages"]:
            errs.append("%s: keine Stufen" % l["id"])
        prev = -1.0
        for s in l["stages"]:
            if s["metric"] not in ("reps", "seconds"):
                errs.append("%s: metric %s" % (s["id"], s["metric"]))
            if not (isinstance(s["target"], int) and s["target"] > 0):
                errs.append("%s: target" % s["id"])
            if not (0.0 <= s["difficulty"] <= 1.0):
                errs.append("%s: difficulty außerhalb 0..1" % s["id"])
            if s["difficulty"] <= prev:
                errs.append("%s: difficulty nicht streng steigend" % s["id"])
            prev = s["difficulty"]
    for r in region_ids:
        if not any(l["region"] == r for l in c["lines"]):
            errs.append("Region %s ohne Linien" % r)
    return errs


def grade_from(score, thresholds, base):
    return base + sum(1 for t in thresholds if score >= t - 1e-12)


def day_minus(day, n):
    return (dt.date.fromisoformat(day) - dt.timedelta(days=n)).isoformat()


def evaluate(c, logs, claims, now_ts, now_day):
    """logs: [{stage, value, ts, day}] (nur nicht gelöschte). claims: {line_id: idx}."""
    st = c["stage_map"]
    lines = c["lines"]
    logs = usable_logs(c, logs)

    logged_idx = {l["id"]: 0 for l in lines}
    for g in logs:
        s = st[g["stage"]]
        if g["value"] >= s["target"]:
            logged_idx[s["line"]] = max(logged_idx[s["line"]], s["idx"])

    def scores(use_claims):
        out = {}
        for l in lines:
            idx = logged_idx[l["id"]]
            if use_claims:
                idx = max(idx, min(int(claims.get(l["id"], 0)), len(l["stages"])))
            out[l["id"]] = l["stages"][idx - 1]["difficulty"] if idx > 0 else 0.0
        return out

    def region_scores(ls):
        out = {}
        for r in c["regions"]:
            rl = sorted((l for l in lines if l["region"] == r["id"]),
                        key=lambda l: (-ls[l["id"]], l["sort"]))
            num = den = 0.0
            for rank, l in enumerate(rl):
                w = l["weight"] * (TOP_K_FACTOR if rank < TOP_K else OTHER_FACTOR)
                num += w * ls[l["id"]]
                den += w
            out[r["id"]] = num / den if den else 0.0
        return out

    def overall(rs):
        vals = list(rs.values())
        mean = sum(vals) / len(vals)
        balance = (min(vals) / mean) if mean > 0 else 1.0
        return mean * (BALANCE_BASE + BALANCE_WEIGHT * balance)

    ls_claim = scores(True)
    rs_claim = region_scores(ls_claim)
    ov_claim = overall(rs_claim)
    ls_logs = scores(False)
    ov_logs = overall(region_scores(ls_logs))

    window = {day_minus(now_day, i) for i in range(CONSISTENCY_DAYS)}
    active_days = {g["day"] for g in logs if g["day"] in window}
    consistency = len(active_days) / CONSISTENCY_DAYS
    vol_from = now_ts - VOLUME_DAYS * 86400
    volume = sum(min(g["value"] / st[g["stage"]]["target"], VOLUME_CAP_PER_SET)
                 for g in logs if g["ts"] >= vol_from)
    cleared = sum(logged_idx.values())
    power = round(W_SCORE * ov_logs + W_STAGES * cleared + W_CONSISTENCY * consistency
                  + W_VOLUME * math.log1p(volume))

    recent = {r["id"]: 0 for r in c["regions"]}
    for g in logs:
        if g["day"] in window:
            recent[[l for l in lines if l["id"] == st[g["stage"]]["line"]][0]["region"]] += 1
    sort = {r["id"]: r["sort"] for r in c["regions"]}
    weakest = min(rs_claim, key=lambda r: (round(rs_claim[r], 9), recent[r], sort[r]))

    return {
        "overall_grade": max(1, grade_from(ov_claim, OVERALL_GRADE_THRESHOLDS, 1)),
        "overall_score": round(ov_claim, 6),
        "power": int(power),
        "region_grades": {r: grade_from(v, OVERALL_GRADE_THRESHOLDS, 1) for r, v in rs_claim.items()},
        "region_scores": {r: round(v, 6) for r, v in rs_claim.items()},
        "weakest": weakest,
        "line_grades": {l: grade_from(v, LINE_GRADE_THRESHOLDS, 0) for l, v in ls_claim.items()},
        "highest_logged": logged_idx,
        "cleared_stages": cleared,
    }


def plan(c, result, max_lines=3, sets=3):
    """Nächste nicht geschaffte Stufe der schwächsten Linien der schwächsten Region."""
    order = sorted(c["regions"], key=lambda r: (r["id"] != result["weakest"], result["region_scores"][r["id"]], r["sort"]))
    for r in order:
        cand = []
        for l in sorted((l for l in c["lines"] if l["region"] == r["id"]), key=lambda l: l["sort"]):
            nxt = result["highest_logged"][l["id"]] + 1
            if nxt <= len(l["stages"]):
                s = l["stages"][nxt - 1]
                cand.append((s["difficulty"], l["sort"], s["id"], s["target"]))
        if cand:
            cand.sort()
            return {"region": r["id"], "items": [{"stage": sid, "sets": sets, "target": tgt}
                                                  for _, _, sid, tgt in cand[:max_lines]]}
    return {"region": result["weakest"], "items": []}


# ---------- Testfälle ----------
NOW_DAY = "2026-10-15"
NOW_TS = 1792065600  # 2026-10-15T12:00:00Z


def ts_of(day, hour=12):
    d = dt.datetime.fromisoformat(day + "T%02d:00:00+00:00" % hour)
    return int(d.timestamp())


def mk(stage, value, days_ago=0):
    day = day_minus(NOW_DAY, days_ago)
    return {"stage": stage, "value": value, "ts": ts_of(day), "day": day}


def cases():
    return [
        {"name": "leer", "logs": [], "claims": {}},
        {"name": "nur_einstufung", "logs": [], "claims": {"pushup": 4, "pullup": 3, "squat": 2}},
        {"name": "ein_satz_knapp_verfehlt", "logs": [mk("pushup.04", 9)], "claims": {}},
        {"name": "ein_satz_geschafft", "logs": [mk("pushup.04", 10)], "claims": {}},
        {"name": "ausgeglichen", "claims": {},
         "logs": [mk(s, 99, d) for d, s in enumerate(
             ["pushup.04", "dip.04", "pullup.04", "row.03", "lsit.03", "legraise.03",
              "squat.04", "hinge.03", "handstand.03", "hspu.02", "hang.02", "fingers.02"])]},
        {"name": "einseitig_push", "claims": {},
         "logs": [mk("pushup.08", 5), mk("dip.07", 6), mk("squat.02", 30)]},
        {"name": "konstanz_und_volumen", "claims": {},
         "logs": [mk("squat.02", 30, d) for d in range(0, 20)] + [mk("pushup.03", 15, 40)]},
        {"name": "einstufung_plus_logs", "claims": {"handstand": 5, "pullup": 6},
         "logs": [mk("pullup.04", 8, 1), mk("hang.02", 60, 2)]},
        {"name": "einstufung_ueber_max", "claims": {"hang": 99}, "logs": []},
        {"name": "wert_null_negativ_unbekannt", "claims": {},
         "logs": [mk("pushup.01", 0), mk("pushup.01", -5), mk("gibtsnicht.01", 10), mk("squat.02", 30)]},
    ]


def compute_all(c):
    out = []
    for case in cases():
        res = evaluate(c, case["logs"], case["claims"], NOW_TS, NOW_DAY)
        out.append({**case, "now_ts": NOW_TS, "now_day": NOW_DAY, "expected": res, "expected_plan": plan(c, res)})
    return out


def property_tests(c):
    fails = []
    e = lambda logs, claims={}: evaluate(c, logs, claims, NOW_TS, NOW_DAY)
    base = e([])
    if base["overall_grade"] != 1 or base["power"] != 0:
        fails.append("leer muss Grad 1 und Power 0 sein: %r" % base)
    if e([mk("pushup.04", 9)])["highest_logged"]["pushup"] != 0:
        fails.append("knapp verfehlt darf nicht abhaken")
    claim = e([], {"pushup": 8, "dip": 7})
    if claim["power"] != 0:
        fails.append("Einstufung darf kein Power erzeugen: %d" % claim["power"])
    if claim["overall_score"] <= 0:
        fails.append("Einstufung muss Grad-Score erhöhen")
    bal = e([mk(s, 99) for s in ["pushup.05", "pullup.05", "lsit.04", "squat.05", "handstand.05", "hang.04"]])
    one = e([mk("pushup.08", 5), mk("dip.07", 6)])
    if not (one["region_scores"]["push"] > bal["region_scores"]["push"]):
        fails.append("Testaufbau: einseitig sollte höheren Push-Score haben")
    if one["overall_score"] >= bal["overall_score"]:
        fails.append("Ungleichgewicht muss Gesamtscore drücken")
    if one["weakest"] == "push":
        fails.append("schwächste Region falsch")
    a = e([mk("squat.02", 30)])
    b = e([mk("squat.02", 30), mk("squat.02", 30, 1)])
    if b["power"] <= a["power"]:
        fails.append("mehr aktive Tage muss Power erhöhen")
    old = e([mk("squat.02", 30, 40)])
    if old["power"] >= a["power"]:
        fails.append("alte Logs dürfen nicht in Konstanz/Volumen zählen")
    capped = e([mk("hang.01", 10000)])
    normal = e([mk("hang.01", 60)])
    if capped["power"] != normal["power"]:
        fails.append("Volumen-Deckel pro Satz greift nicht")
    p = plan(c, one)
    if p["region"] != one["weakest"] or not p["items"]:
        fails.append("Plan muss auf schwächste Region zielen")
    return fails


def main():
    c = load_catalog()
    errs = validate_catalog(c)
    test_copy = os.path.join(os.path.dirname(VECTORS), "catalog.json")
    if not os.path.exists(test_copy) or open(test_copy, "rb").read() != open(CATALOG, "rb").read():
        errs.append("Test-Kopie des Katalogs veraltet: cp App/Resources/catalog.json " + os.path.relpath(test_copy, os.path.join(HERE, "..")))
    print("Katalog: %d Regionen, %d Linien, %d Stufen, %d Fehler"
          % (len(c["regions"]), len(c["lines"]), len(c["stage_map"]), len(errs)))
    for x in errs:
        print("  -", x)
    if "--write" in sys.argv:
        os.makedirs(os.path.dirname(VECTORS), exist_ok=True)
        json.dump(compute_all(c), open(VECTORS, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
        print("vectors.json geschrieben")
    fails = property_tests(c)
    print("Eigenschaftstests: %d Fehler" % len(fails))
    for x in fails:
        print("  -", x)
    mism = 0
    if os.path.exists(VECTORS):
        stored = json.load(open(VECTORS, encoding="utf-8"))
        for got, want in zip(compute_all(c), stored):
            if got["expected"] != want["expected"] or got["expected_plan"] != want["expected_plan"]:
                mism += 1
                print("  - Vektor weicht ab:", want["name"])
        print("Vektoren: %d Fälle, %d Abweichungen" % (len(stored), mism))
    for case in compute_all(c):
        r = case["expected"]
        print("  %-24s Grad %d  Power %5d  schwächste %-9s Score %.3f" %
              (case["name"], r["overall_grade"], r["power"], r["weakest"], r["overall_score"]))
    return 1 if (errs or fails or mism) else 0


if __name__ == "__main__":
    sys.exit(main())
