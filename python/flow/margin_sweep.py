"""Screen and validate margin-guided candidates with the real flow.

  python3 python/flow/margin_sweep.py screen   --level loss30   # 4M symbols, 1 P&R seed
  python3 python/flow/margin_sweep.py validate --level loss30 [labels...]   # 100M symbols, 3 P&R seeds

Candidates come from margin_search.py. With no labels, validate picks the Pareto
front of the screened designs that meet DER <= 2e-4 (at most 10, spread by cells)
plus the cheapest uniform design with the output offset (the ablation point).
"""

import argparse
import csv
import json
import sys
from multiprocessing import Pool
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE)]
import margin_design as md  # noqa: E402
import run_flow  # noqa: E402
from run_flow import sweep  # noqa: E402

ROOT = HERE.parents[1]
OUT = ROOT / "results" / "phase7"
_CTX = {}


def cands_path(level):
    return OUT / f"margin_candidates_{level}_t5.json"


def screen_path(level):
    return OUT / f"margin_screen_{level}_t5.csv"


def context(level):
    if level not in _CTX:
        pulses, th, front = sweep.load_front_end(level)
        _CTX[level] = (pulses, th, front, sweep.designs_for(pulses, th)[5])
    return _CTX[level]


def one(args):
    cand, level, symbols, seeds, pnr_seeds, tmp = args
    ctx = context(level)
    run_flow.OUT = Path(tmp)
    d = md.Design(cand["W"], cand["F"], cand["f"], cand["t"], [float(v) for v in ctx[3]["float"]],
                  cand["b"]).normalized()
    rec = run_flow.run_design(level, d, md.rtl(d), lambda xi, d=d: md.model(xi, d), symbols, seeds, pnr_seeds,
                              cand["label"], context=ctx)
    b, p = rec["stages"]["ber"], rec["stages"]["pnr"]
    return {**{k: cand.get(k) for k in ("label", "W", "F", "f", "t", "b", "proxy_cost", "pred_der")},
            "rtl": rec["stages"]["rtl"]["status"], "symbols": b["symbols"], "ber": b["ber_fixed"], "der": b["der_fixed"],
            "lut4": p.get("lut4"), "dff": p.get("dff"), "logic_cells": p.get("logic_cells"),
            "fmax_median_mhz": p.get("fmax_median_mhz")}


def write_rows(path, rows):
    rows = sorted(rows, key=lambda r: float(r["logic_cells"] or 1e9))
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def run_jobs(jobs, tag):
    rows = []
    with Pool(2) as pool:
        for i, r in enumerate(pool.imap_unordered(one, jobs), 1):
            rows.append(r)
            print(i, len(jobs), r["label"], r["rtl"], r["logic_cells"], f"{r['ber']:.3e}", f"{r['der']:.3e}", flush=True)
    return rows


def screen(level, max_pred=3e-4):
    cands = [c for c in json.loads(cands_path(level).read_text()) if c["pred_der"] <= max_pred]
    tmp = OUT / "_screen"
    tmp.mkdir(exist_ok=True)
    rows = run_jobs([(c, level, 2_000_000, 2, 1, str(tmp)) for c in cands], "screen")
    write_rows(screen_path(level), rows)


def pick_validation(level, limit=2e-4, max_points=10):
    rows = list(csv.DictReader(screen_path(level).open()))
    for r in rows:
        r["cells"], r["d"] = int(float(r["logic_cells"])), float(r["der"])
    front, best = [], 1.0
    for r in sorted(rows, key=lambda r: (r["cells"], r["d"])):
        if r["d"] < best:
            front.append(r)
            best = r["d"]
    ok = [r for r in front if r["d"] <= limit]
    if len(ok) > max_points:
        idx = sorted({round(i * (len(ok) - 1) / (max_points - 1)) for i in range(max_points)})
        ok = [ok[i] for i in idx]
    labels = [r["label"] for r in ok]
    abl = [r for r in rows if r["label"].split("_")[2] == "f" + str(int(r["F"])) * 5 and set(r["t"].strip("[]").replace(",", "").split()) == {"0"}
           and r["d"] <= limit]
    if abl:
        labels.append(min(abl, key=lambda r: r["cells"])["label"])
    return list(dict.fromkeys(labels))


def validate(level, labels=None):
    cands = {c["label"]: c for c in json.loads(cands_path(level).read_text())} if cands_path(level).exists() else {}
    ctx = context(level)
    c_float = [float(v) for v in ctx[3]["float"]]
    labels = labels or pick_validation(level)
    jobs = []
    for lab in labels:
        c = cands.get(lab)
        if c is None:    # label alone is enough to rebuild a design
            d = md.from_label(lab, c_float)
            c = {"label": lab, "W": d.W, "F": d.F, "f": d.f, "t": d.t, "b": d.b}
        jobs.append((c, level, 20_000_000, 5, 3, str(OUT)))
    rows = run_jobs(jobs, "validate")
    write_rows(OUT / f"margin_{level}_t5.csv", rows)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["screen", "validate"])
    ap.add_argument("--level", default="loss30")
    ap.add_argument("labels", nargs="*")
    a = ap.parse_args()
    if a.cmd == "screen":
        screen(a.level)
    else:
        validate(a.level, a.labels or None)
