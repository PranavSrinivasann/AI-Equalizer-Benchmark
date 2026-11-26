"""Phase 7: uniform bit-width sweep through the end-to-end flow.

Every width W uses sample bits W (Q3.(W-4)) and coefficient fraction W-2
(Q1.(W-2)), the same rule as P12 = (12, 10), P10 = (10, 8), P8 = (8, 6).
Each width goes through python/flow/run_flow.py, so every row has the same
stages (reference, RTL check, BER/DER, place-and-route).

  python3 python/flow/uniform_sweep.py --level loss30 --taps 5 --widths 6 7 8 9 10 11 12
"""

import argparse
import csv
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE)]
import margin_design as md  # noqa: E402
import run_flow  # noqa: E402
from run_flow import sweep  # noqa: E402

MIN_HAND_WIDTH = 6   # ffe_gen.hand_csd_rtl refuses narrower inputs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="loss30")
    ap.add_argument("--taps", type=int, default=5)
    ap.add_argument("--widths", type=int, nargs="+", default=[6, 7, 8, 9, 10, 11, 12])
    ap.add_argument("--symbols", type=int, default=20_000_000)
    ap.add_argument("--seeds", type=int, default=5)
    ap.add_argument("--pnr-seeds", type=int, default=3)
    args = ap.parse_args()
    for w in args.widths:
        sweep.PRECISIONS[f"W{w}"] = (w, w - 2)
    rows = []
    for w in args.widths:
        name = f"{args.level}_t{args.taps}_W{w}_uniform"
        if w >= MIN_HAND_WIDTH:
            rec = run_flow.run(args.level, args.taps, f"W{w}", args.symbols, args.seeds, args.pnr_seeds, name=name)
        else:   # same arithmetic as the hand generator (checked for W7..W12), narrower inputs allowed
            pulses, th, front = sweep.load_front_end(args.level)
            entry = sweep.designs_for(pulses, th)[args.taps]
            d = md.Design(w, w - 2, [w - 2] * args.taps, [0] * args.taps, [float(v) for v in entry["float"]], 0)
            rec = run_flow.run_design(args.level, d, md.rtl(d, f"uniform W{w}"), lambda xi, d=d: md.model(xi, d),
                                      args.symbols, args.seeds, args.pnr_seeds, name, context=(pulses, th, front, entry))
        b, p = rec["stages"]["ber"], rec["stages"]["pnr"]
        rows.append({"level": args.level, "taps": args.taps, "width": w, "coef_frac": w - 2,
                     "rtl": rec["stages"]["rtl"]["status"], "symbols": b["symbols"],
                     "bit_errors": b["bit_errors_fixed"], "ber": b["ber_fixed"], "der": b["der_fixed"],
                     "ber_float": b["ber_float"], "samples_clipped": b["samples_clipped"],
                     "ber_primary": b["ber_primary"], "ber_stretch": b["ber_stretch"],
                     "lut4": p.get("lut4"), "logic_cells": p.get("logic_cells"),
                     "fmax_median_mhz": p.get("fmax_median_mhz"), "all_pass": rec["summary"]["all_stages_pass"]})
        print(rows[-1], flush=True)
        out = run_flow.OUT / f"uniform_{args.level}_t{args.taps}.csv"
        with out.open("w", newline="") as f:
            wr = csv.DictWriter(f, fieldnames=list(rows[0]))
            wr.writeheader()
            wr.writerows(rows)


if __name__ == "__main__":
    main()
