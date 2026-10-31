"""DFE sweep: feed-forward taps x feedback taps on a channel (floating point).

  python3 python/dj/dfe_sweep.py --level loss40 --out results/phase4/dfe_loss40.csv
"""

import argparse
import csv
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE.parent), str(HERE)]

from channel.link import PAM4_LEVELS  # noqa: E402
from dfe import design_dfe, run_dfe  # noqa: E402
from dj.ffe_design import TX_NOISE_VAR  # noqa: E402
from sweep import load_front_end  # noqa: E402

NFF = [5, 8, 16, 24, 32]
NB = [0, 1, 2, 4, 8, 16, 24, 32]
CHUNK = 1_000_000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--symbols", type=int, default=5_000_000)
    ap.add_argument("--seeds", type=int, default=5)
    args = ap.parse_args()
    pulses, th, _ = load_front_end(args.level)
    hv = pulses["victim"]
    aggressors = [h for _, h in pulses["aggressors"]]
    designs = {(f, b): design_dfe(pulses, th, f, b) for f in NFF for b in NB}
    rows = []
    for seed in range(args.seeds):
        rng = np.random.default_rng(2000 + seed)
        totals = {k: [0, 0, 0] for k in designs}
        done = 0
        while done < args.symbols:
            n = min(CHUNK, args.symbols - done)
            m = n + len(hv) + 64
            s = rng.choice(PAM4_LEVELS, size=m)
            r = np.convolve(s + rng.normal(0, np.sqrt(TX_NOISE_VAR), m), hv, "valid")
            for ha in aggressors:
                r += np.convolve(rng.choice(PAM4_LEVELS, size=m).astype(float), ha, "valid")
            r += rng.normal(0, np.sqrt(th), len(r))
            for (f, b), d in designs.items():
                idx = np.arange(len(r)) + len(hv) - 1 - d["delay"]
                sent = s[np.clip(idx, 0, m - 1)]
                be, se = run_dfe(r, sent, d)
                counted = len(r) - 64
                totals[(f, b)][0] += be
                totals[(f, b)][1] += se
                totals[(f, b)][2] += counted
            done += n
        for (f, b), (be, se, cnt) in totals.items():
            rows.append({"level": args.level, "ff_taps": f, "fb_taps": b, "seed": seed,
                         "symbols": cnt, "bit_errors": be, "symbol_errors": se,
                         "gaussian_ber": designs[(f, b)]["gauss_ber"],
                         "error_power": designs[(f, b)]["error_power"]})
        print(f"[{args.level}] seed {seed} done", flush=True)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


if __name__ == "__main__":
    main()
