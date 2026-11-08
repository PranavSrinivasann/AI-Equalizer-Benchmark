"""Connect the FFE hardware to the PAM4 link: BER for float, fixed and RTL.

For each channel:
  1. Design a 5-tap MMSE FFE at the design SNR, scale it to fit Q1.10,
     and quantize it (python/channel/equalizer.py).
  2. Generate baseline and hand-CSD RTL for the quantized coefficients
     (rtl/channel/), plus any optimized RTL already present there.
  3. At each SNR, send the same PAM4 symbols and noise through
       - the floating-point FFE (unquantized samples and coefficients),
       - the bit-exact fixed-point model (Q3.8 samples, Q1.10 coefficients),
       - every RTL design, simulated with Verilator on the Q3.8 samples,
     and count bit errors after PAM4 decisions.
  4. Check that each RTL design's outputs equal the fixed-point model's.

Writes results/channel/<channel>/{ber.csv,coefficients.json,rtl_*.log}
and results/channel/coefficient_sets.json.

Usage:
  python3 python/channel/hardware_ber.py                 # all channels
  python3 python/channel/hardware_ber.py --channels notebook --symbols 20000
"""

import argparse
import csv
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(HERE), str(ROOT / "python" / "rtl_gen")]

import equalizer as eq  # noqa: E402
import link  # noqa: E402
import rtl_sim  # noqa: E402
from ffe_rtl import baseline_rtl, hand_csd_rtl  # noqa: E402

RESULTS = ROOT / "results" / "channel"
RTL_DIR = ROOT / "rtl" / "channel"
RESET_CYCLES = 2
SEED = 20261026


def design_rtl(name, coefficients):
    """Write baseline and hand RTL; return every RTL design for this channel."""
    RTL_DIR.mkdir(parents=True, exist_ok=True)
    header = f"Channel '{name}' baseline FFE. Coefficients {list(coefficients)} (Q1.10)."
    (RTL_DIR / f"ffe5tap_{name}_baseline.sv").write_text(baseline_rtl(coefficients, header))
    (RTL_DIR / f"ffe5tap_{name}_hand.sv").write_text(hand_csd_rtl(coefficients, f"Channel '{name}'"))
    designs = {"baseline": RTL_DIR / f"ffe5tap_{name}_baseline.sv",
               "hand": RTL_DIR / f"ffe5tap_{name}_hand.sv"}
    optimized = RTL_DIR / "optimized" / f"ffe5tap_{name}_optimized.sv"
    if optimized.exists():
        designs["ai"] = optimized
    return designs


def count_errors(symbols, outputs, delay, skip, gain):
    decided = link.decide(outputs[skip:], gain)
    return link.bit_errors(symbols[skip - delay: len(symbols) - delay], decided)


def run_channel(name, snrs, num_symbols, design_snr):
    channel = link.CHANNELS[name]
    cset = eq.coefficient_set(channel, design_snr)
    q = [int(v) for v in cset["q110"]]
    designs = design_rtl(name, q)
    out = RESULTS / name
    out.mkdir(parents=True, exist_ok=True)

    l1 = sum(abs(v) for v in q)
    info = {
        "channel": channel,
        "design_snr_db": design_snr,
        "decision_delay": cset["delay"],
        "output_gain": round(cset["gain"], 6),
        "coefficients_float": [round(float(v), 6) for v in cset["float"]],
        "coefficients_q110": q,
        "sum_abs_q110": l1,
        "saturation_reachable": l1 >= 1024,
        "mmse": cset["mse"],
    }
    (out / "coefficients.json").write_text(json.dumps(info, indent=2) + "\n")
    print(f"[{name}] channel {channel}")
    print(f"    coefficients Q1.10 {q} (delay {cset['delay']}, gain {cset['gain']:.3f}, "
          f"sum|c| {l1}, saturation {'reachable' if l1 >= 1024 else 'unreachable'})")

    rng = np.random.default_rng(SEED)
    skip = cset["delay"] + 10
    rows, stream = [], {"rst_n": [], "x": [], "expected": []}
    blocks = []
    coef_float = cset["float"]
    for snr in snrs:
        symbols = link.random_symbols(num_symbols, rng)
        received = link.transmit(symbols, channel, snr, rng)

        y_float = eq.float_ffe(received, coef_float)
        x_q = eq.quantize(received, eq.DATA_FRACTION_BITS)
        y_fixed = eq.fixed_ffe(x_q, q)
        clipped = int(np.count_nonzero(np.abs(np.round(received * 256)) > 2047))

        e_float, bits = count_errors(symbols, y_float, cset["delay"], skip, cset["gain"])
        e_fixed, _ = count_errors(symbols, y_fixed / 256.0, cset["delay"], skip, cset["gain"])
        rows.append({"snr_db": snr, "bits": bits, "errors_float": e_float, "errors_fixed": e_fixed,
                     "ber_float": e_float / bits, "ber_fixed": e_fixed / bits,
                     "input_samples_clipped": clipped})

        start = sum(len(s) for s in stream["x"]) + RESET_CYCLES
        stream["rst_n"] += [np.zeros(RESET_CYCLES, int), np.ones(num_symbols, int)]
        stream["x"] += [np.zeros(RESET_CYCLES, int), x_q]
        stream["expected"] += [np.zeros(RESET_CYCLES, int), y_fixed]
        blocks.append((start, symbols))

    stream = {k: np.concatenate(v) for k, v in stream.items()}
    rtl_summary = {}
    for impl, rtl_path in designs.items():
        outputs, mismatches, cycles = rtl_sim.run(
            rtl_path, stream["rst_n"], stream["x"], stream["expected"],
            log_path=out / f"rtl_{impl}.log")
        rtl_summary[impl] = {"rtl": str(rtl_path.relative_to(ROOT)),
                             "cycles": cycles, "mismatches_vs_fixed": mismatches}
        for row, (start, symbols) in zip(rows, blocks):
            y_rtl = outputs[start: start + num_symbols] / 256.0
            e_rtl, bits = count_errors(symbols, y_rtl, cset["delay"], skip, cset["gain"])
            row[f"errors_rtl_{impl}"] = e_rtl
            row[f"ber_rtl_{impl}"] = e_rtl / bits
        print(f"    RTL {impl:8s}: {cycles} cycles, {mismatches} mismatches vs fixed-point model")

    info["rtl"] = rtl_summary
    (out / "coefficients.json").write_text(json.dumps(info, indent=2) + "\n")
    with (out / "ber.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    for row in rows:
        rtl = " ".join(f"{row[k]:.2e}" for k in row if k.startswith("ber_rtl_"))
        print(f"    SNR {row['snr_db']:4.1f} dB  BER float {row['ber_float']:.2e}  "
              f"fixed {row['ber_fixed']:.2e}  rtl {rtl}")
    return info


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--channels", nargs="*", default=list(link.CHANNELS),
                        choices=list(link.CHANNELS))
    parser.add_argument("--symbols", type=int, default=100_000, help="symbols per SNR point")
    parser.add_argument("--snr", type=float, nargs="*", default=list(range(0, 21, 2)))
    parser.add_argument("--design-snr", type=float, default=14.0)
    args = parser.parse_args()

    summary_path = RESULTS / "coefficient_sets.json"
    summary = json.loads(summary_path.read_text()) if summary_path.exists() else {}
    failures = []
    for name in args.channels:
        info = run_channel(name, args.snr, args.symbols, args.design_snr)
        summary[name] = {k: info[k] for k in ("channel", "coefficients_q110", "sum_abs_q110",
                                              "saturation_reachable", "decision_delay", "output_gain")}
        failures += [f"{name}/{impl}" for impl, r in info["rtl"].items() if r["mismatches_vs_fixed"]]
    RESULTS.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, indent=2) + "\n")
    print("RESULT:", "PASS (every RTL output matches the fixed-point model)"
          if not failures else "FAIL: " + ", ".join(failures))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
