"""Run the margin-guided greedy search from several starting points and list candidates.

  python3 python/flow/margin_search.py --level loss30
"""

import argparse
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE)]
import margin_design as md  # noqa: E402

ROOT = HERE.parents[1]
FLOAT_BER = {"loss30": md.FLOAT_BER_30DB_5TAP}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="loss30")
    ap.add_argument("--symbols", type=int, default=2_000_000)
    ap.add_argument("--stop-ser", type=float, default=4e-4)
    ap.add_argument("--widths", type=int, nargs="+", default=[6, 7, 8, 9, 10])
    ap.add_argument("--float-ber", type=float, default=None)
    args = ap.parse_args()
    out = ROOT / f"results/phase7/margin_candidates_{args.level}_t5.json"
    s = md.Sample(args.level, symbols=args.symbols, float_ber=args.float_ber or FLOAT_BER.get(args.level))
    seen, cands = set(), []
    t0 = time.time()
    for W in args.widths:
        for F in sorted({W - 2, 8, 10}):
            path = md.greedy_path(s, W, F, stop_ser=args.stop_ser)
            for d, m, c in path:
                if d.key() in seen:
                    continue
                seen.add(d.key())
                cands.append({"label": d.label(), "W": d.W, "F": d.F, "f": d.f, "t": d.t, "b": d.b,
                              "proxy_cost": c, "pred_der": 2 * m["ber"], "pred_ber": m["ber"],
                              "mu": m["mu"], "sigma": m["sigma"], "start": f"W{W}F{F}"})
            print(f"W{W} F{F}: {len(path)} steps, {len(cands)} candidates, {time.time() - t0:.0f}s", flush=True)
    out.write_text(json.dumps(cands, indent=1) + "\n")
    print(len(cands), "candidates ->", out)


if __name__ == "__main__":
    main()
