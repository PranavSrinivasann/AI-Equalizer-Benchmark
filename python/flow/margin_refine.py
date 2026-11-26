"""Local refinement: add or remove one bit on one tap around the best screened designs.

Every neighbour is screened with the real flow (not the predictor). New designs are
appended to the candidate list and to the screening table.

  python3 python/flow/margin_refine.py --level loss30 LABEL [LABEL ...]
"""

import argparse
import csv
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE)]
import margin_design as md  # noqa: E402
import margin_search as msr  # noqa: E402
import margin_sweep as ms  # noqa: E402

OUT = ms.OUT


def neighbours(d):
    out = []
    for k in range(5):
        for step in (-1, 1):
            f = list(d.f)
            f[k] += step
            if 2 <= f[k] <= d.F:
                out.append(md.Design(d.W, d.F, f, list(d.t), d.c_float))
    for k in range(1, 5):
        for step in (-1, 1):
            t = list(d.t)
            t[k] += step
            if 0 <= t[k] <= d.W - 3:
                out.append(md.Design(d.W, d.F, list(d.f), t, d.c_float).normalized())
    return out


def main(level, labels):
    s = md.Sample(level, symbols=2_000_000, float_ber=msr.FLOAT_BER.get(level))
    cands = json.loads(ms.cands_path(level).read_text())
    known = {c["label"] for c in cands}
    by_label = {c["label"]: c for c in cands}
    new = []
    for lab in labels:
        c = by_label[lab]
        d = md.Design(c["W"], c["F"], c["f"], c["t"], s.c_float, c["b"])
        for n in neighbours(d):
            n, m = s.margin(n)
            if n.label() in known:
                continue
            known.add(n.label())
            new.append({"label": n.label(), "W": n.W, "F": n.F, "f": n.f, "t": n.t, "b": n.b,
                        "proxy_cost": md.csd_cost(n)[0], "pred_der": 2 * m["ber"], "pred_ber": m["ber"],
                        "mu": m["mu"], "sigma": m["sigma"], "start": "refine"})
    print(len(new), "new neighbours")
    ms.cands_path(level).write_text(json.dumps(cands + new, indent=1) + "\n")
    tmp = OUT / "_screen"
    tmp.mkdir(exist_ok=True)
    rows = ms.run_jobs([(c, level, 2_000_000, 2, 1, str(tmp)) for c in new], "refine")
    old = list(csv.DictReader(ms.screen_path(level).open()))
    ms.write_rows(ms.screen_path(level), old + [{k: ("" if v is None else v) for k, v in r.items()} for r in rows])


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="loss30")
    ap.add_argument("labels", nargs="+")
    a = ap.parse_args()
    main(a.level, a.labels)
