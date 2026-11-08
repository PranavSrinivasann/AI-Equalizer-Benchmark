"""Phase 4 BER sweep: FFE tap count x sample/coefficient precision per channel.

Uses the Phase 3 front end (CTLE setting and sampling phase per level) for
every tap count. For each seed the same received samples go through every
(taps, precision) design, so differences come from the equalizer only.

Precisions (sample bits W, coefficient fraction bits F): samples Q3.(W-4),
coefficients Q1.F, output saturated to W bits.

  python3 python/dj/sweep.py --level loss30 --out results/phase4/ber_loss30.csv
"""

import argparse
import csv
import json
import sys
import time
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(HERE.parent)]

from channel.equalizer import quantize  # noqa: E402
from channel.link import PAM4_LEVELS, bit_errors, decide  # noqa: E402
from dj.channel_model import Level  # noqa: E402
from dj.ffe_design import TX_NOISE_VAR, hardware_design  # noqa: E402

TAPS = [5, 8, 12, 16, 24, 32, 48]
PRECISIONS = {"P12": (12, 10), "P10": (10, 8), "P8": (8, 6)}   # (sample bits, coef fraction bits)
SYMBOLS_PER_SEED = {"loss20": 10_000_000, "loss30": 20_000_000, "loss40": 2_000_000}
CHUNK = 1_000_000
SEEDS = 5


def fixed_general(codes, q, frac, bits):
    acc = np.convolve(codes, np.asarray(q, dtype=np.int64))[: len(codes)]
    return np.clip(acc >> frac, -(2 ** (bits - 1)), 2 ** (bits - 1) - 1)


def load_front_end(level_name):
    info = json.loads((ROOT / "results" / "dj" / level_name / "summary.json").read_text())
    level = Level(level_name)
    g_db, phase = info["ctle_dc_gain_db"], info["sampling_phase"]
    pulses = level.sample(level.responses(g_db), phase)
    return pulses, level.thermal_variance(g_db), info


def designs_for(pulses, thermal_var):
    out = {}
    for n in TAPS:
        d = hardware_design(pulses, thermal_var, n)
        out[n] = d
        for name, (bits, frac) in PRECISIONS.items():
            d.setdefault("q", {})[name] = quantize(d["float"], frac, frac + 2)
    return out


def count(sent, decided):
    wrong = np.nonzero(sent != decided)[0]
    if wrong.size == 0:
        return 0, 0
    return bit_errors(sent[wrong], decided[wrong])[0], int(wrong.size)


def run_seed(pulses, thermal_var, designs, symbols, seed):
    rng = np.random.default_rng(seed)
    hv = pulses["victim"]
    aggressors = [h for _, h in pulses["aggressors"]]
    gain = designs[TAPS[0]]["input_gain"]
    history = len(hv) + max(TAPS)
    keys = [(n, "float") for n in TAPS] + [(n, p) for n in TAPS for p in PRECISIONS]
    acc = {k: [0, 0] for k in keys}
    clipped = {p: 0 for p in PRECISIONS}
    done = 0
    while done < symbols:
        n = min(CHUNK, symbols - done)
        m = n + history
        s = rng.choice(PAM4_LEVELS, size=m)
        r = np.convolve(s + rng.normal(0.0, np.sqrt(TX_NOISE_VAR), m), hv, "valid")
        for ha in aggressors:
            r += np.convolve(rng.choice(PAM4_LEVELS, size=m).astype(float), ha, "valid")
        r += rng.normal(0.0, np.sqrt(thermal_var), len(r))
        x = r * gain
        scaled = {}
        for p, (bits, frac) in PRECISIONS.items():
            sc = np.round(x * 2 ** (bits - 4))
            lim = 2 ** (bits - 1)
            clipped[p] += int(np.count_nonzero((sc > lim - 1) | (sc < -lim)))
            scaled[p] = np.clip(sc, -lim, lim - 1).astype(np.int64)
        for taps in TAPS:
            d = designs[taps]
            j = np.arange(max(TAPS) - 1, len(x))
            sent = s[j + len(hv) - 1 - d["delay"]]
            y = np.convolve(x, d["float"])[: len(x)]
            be, se = count(sent, decide(y[j], d["output_gain"]))
            acc[(taps, "float")][0] += be
            acc[(taps, "float")][1] += se
            for p, (bits, frac) in PRECISIONS.items():
                yq = fixed_general(scaled[p], d["q"][p], frac, bits) / 2 ** (bits - 4)
                be, se = count(sent, decide(yq[j], d["output_gain"]))
                acc[(taps, p)][0] += be
                acc[(taps, p)][1] += se
        done += n
        counted = done
    return acc, clipped, counted


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--symbols", type=int, default=None)
    ap.add_argument("--seeds", type=int, default=SEEDS)
    args = ap.parse_args()
    pulses, th, info = load_front_end(args.level)
    designs = designs_for(pulses, th)
    symbols = args.symbols or SYMBOLS_PER_SEED[args.level]
    rows, t0 = [], time.time()
    coeffs = {}
    for seed in range(args.seeds):
        acc, clipped, counted = run_seed(pulses, th, designs, symbols, 1000 + seed)
        for (taps, prec), (be, se) in acc.items():
            rows.append({"level": args.level, "taps": taps, "precision": prec, "seed": seed,
                         "symbols": counted, "bit_errors": be, "symbol_errors": se,
                         "clipped": clipped.get(prec, 0)})
        print(f"[{args.level}] seed {seed} done, {time.time() - t0:.0f} s", flush=True)
    for taps, d in designs.items():
        coeffs[taps] = {"delay": d["delay"], "output_gain": d["output_gain"],
                        "float": [float(v) for v in d["float"]],
                        "q": {p: [int(v) for v in qv] for p, qv in d["q"].items()},
                        "gaussian_ber": d["gauss_ber"], "error_power": d["error_power"]}
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    out.with_suffix(".coefficients.json").write_text(json.dumps(coeffs, indent=1) + "\n")


if __name__ == "__main__":
    main()
