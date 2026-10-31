"""Phase 3: 5-tap FFE on the 802.3dj 200G/lane channels.

For each loss level (~20, ~30, ~40 dB at 53.125 GHz):
  - loss check, crosstalk table, noise budget
  - CTLE setting and sampling phase chosen to minimize 5-tap error power
  - 5-tap FFE design (Q1.10), float / fixed-point BER and DER on the same
    samples, and an RTL check on a subset
Outputs go to results/dj/.

  python3 python/dj/run_phase3.py                 # everything
  python3 python/dj/run_phase3.py --max-symbols 2000000 --rtl-symbols 20000   # quick
"""

import argparse
import csv
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(HERE.parent), str(ROOT / "python" / "rtl_gen"), str(ROOT / "python" / "channel")]

import matplotlib  # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

import rtl_sim  # noqa: E402
from channel.equalizer import fixed_ffe  # noqa: E402
from dj.channel_model import COM, LEVELS, NYQUIST, OVERSAMPLE, UI, Level  # noqa: E402
from dj.ffe_design import (TX_NOISE_VAR, choose_front_end, hardware_design,  # noqa: E402
                           simulate)
from ffe_rtl import baseline_rtl, hand_csd_rtl  # noqa: E402

RESULTS = ROOT / "results" / "dj"
RTL_DIR = ROOT / "rtl" / "dj"
TARGET_PRIMARY, TARGET_STRETCH = 2e-4, 1e-6
SEED = 20261031
BLOCK = 10_000_000
MIN_ERRORS = 100
COLORS = {"loss20": "#2a78d6", "loss30": "#eb6834", "loss40": "#1baf7a"}
INK, INK2, GRID = "#0b0b0b", "#52514e", "#e4e3df"


def style(ax):
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(INK2)
    ax.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(colors=INK2)


def verdict(rate, errors, trials, target):
    """PASS if the measured rate is at or below target and the 95% bound is too."""
    upper = max(errors, 3.0) / trials if errors == 0 else (errors + 1.96 * np.sqrt(errors) + 1) / trials
    if rate <= target and upper <= target:
        return "PASS"
    return "FAIL" if rate > target else "NOT RESOLVED"


def run_simulation(pulses, thermal_var, design, max_symbols):
    total, merged = 0, None
    while total < max_symbols:
        r = simulate(pulses, thermal_var, design, min(BLOCK, max_symbols - total), SEED + total // BLOCK)
        merged = r if merged is None else {k: merged[k] + r[k] for k in r}
        total += BLOCK
        if merged["fixed_bit_errors"] >= MIN_ERRORS:
            break
    return merged


def rtl_check(name, design, pulses, thermal_var, count):
    """Run baseline and hand RTL on a subset; compare to the fixed-point model."""
    rng = np.random.default_rng(SEED)
    from channel.link import PAM4_LEVELS
    hv = pulses["victim"]
    m = count + len(hv)
    s = rng.choice(PAM4_LEVELS, size=m)
    r = np.convolve(s + rng.normal(0, np.sqrt(TX_NOISE_VAR), m), hv, "valid")
    for _, ha in pulses["aggressors"]:
        r += np.convolve(rng.choice(PAM4_LEVELS, size=m), ha, "valid")
    r += rng.normal(0, np.sqrt(thermal_var), len(r))
    codes = np.clip(np.round(r * design["input_gain"] * 256), -2048, 2047).astype(np.int64)
    q = [int(v) for v in design["q110"]]
    expected = fixed_ffe(codes, q)
    rst = np.concatenate([np.zeros(2, int), np.ones(len(codes), int)])
    x = np.concatenate([np.zeros(2, int), codes])
    exp = np.concatenate([np.zeros(2, int), expected])
    RTL_DIR.mkdir(parents=True, exist_ok=True)
    out = {}
    header = f"802.3dj {name} baseline FFE. Coefficients {q} (Q1.10)."
    designs = {"baseline": baseline_rtl(q, header), "hand": hand_csd_rtl(q, f"802.3dj {name}")}
    for impl, text in designs.items():
        path = RTL_DIR / f"ffe5tap_dj_{name}_{impl}.sv"
        path.write_text(text)
        _, mismatches, cycles = rtl_sim.run(path, rst, x, exp, RESULTS / name / f"rtl_{impl}.log")
        out[impl] = {"rtl": str(path.relative_to(ROOT)), "cycles": cycles, "mismatches_vs_fixed": mismatches}
        print(f"    RTL {impl:8s}: {cycles} cycles, {mismatches} mismatches")
    return out


def analyse(name, args):
    folder = RESULTS / name
    folder.mkdir(parents=True, exist_ok=True)
    level = Level(name)
    fe = choose_front_end(level)
    pulses, th = fe["pulses"], fe["thermal_var"]
    design = hardware_design(pulses, th)
    v = pulses["victim"]
    cursor = float(v[10])
    xt_var = 5.0 * sum(float(np.sum(h ** 2)) for _, h in pulses["aggressors"])
    isi = float(np.sum(v ** 2) - cursor ** 2)
    noise = {"cursor_mV": 1e3 * cursor,
             "thermal_rms_mV": 1e3 * np.sqrt(th),
             "tx_noise_rms_mV": 1e3 * np.sqrt(TX_NOISE_VAR * np.sum(v ** 2)),
             "crosstalk_rms_mV": 1e3 * np.sqrt(xt_var),
             "residual_isi_rms_mV_unequalized": 1e3 * np.sqrt(5.0 * isi)}
    print(f"[{name}] {LEVELS[name]['label']}: channel {level.channel_loss_db:.1f} dB, "
          f"with package/terminations {level.total_loss_db:.1f} dB; CTLE {fe['g_dc_db']:+.0f} dB, "
          f"phase {fe['phase']}/{OVERSAMPLE}")
    print(f"    Q1.10 taps {[int(c) for c in design['q110']]}  delay {design['delay']}  "
          f"gain {design['output_gain']:.3f}  sum|c| {int(np.abs(design['q110']).sum())}")

    result = run_simulation(pulses, th, design, args.max_symbols)
    n_sym, n_bit = result["symbols"], result["bits"]
    rows = {}
    for model in ("float", "fixed"):
        be, se = result[f"{model}_bit_errors"], result[f"{model}_symbol_errors"]
        rows[model] = {"bit_errors": be, "symbol_errors": se, "ber": be / n_bit, "der": se / n_sym,
                       "ber_primary": verdict(be / n_bit, be, n_bit, TARGET_PRIMARY),
                       "ber_stretch": verdict(be / n_bit, be, n_bit, TARGET_STRETCH),
                       "der_primary": verdict(se / n_sym, se, n_sym, TARGET_PRIMARY),
                       "der_stretch": verdict(se / n_sym, se, n_sym, TARGET_STRETCH)}
    print(f"    {n_sym:,} symbols: fixed BER {rows['fixed']['ber']:.2e} DER {rows['fixed']['der']:.2e} "
          f"(float BER {rows['float']['ber']:.2e}); Gaussian estimate BER {design['gauss_ber']:.2e}")

    rtl = rtl_check(name, design, pulses, th, args.rtl_symbols)
    info = {
        "level": name, "label": LEVELS[name]["label"],
        "channel_loss_db_at_nyquist": level.channel_loss_db,
        "loss_with_package_and_terminations_db": level.total_loss_db,
        "package_included": level.with_package,
        "ctle_dc_gain_db": fe["g_dc_db"], "sampling_phase": fe["phase"], "oversample": OVERSAMPLE,
        "ctle_sweep": fe["sweep"],
        "noise": noise,
        "crosstalk": [{"kind": x["kind"], "file": x["name"], "loss_db_at_nyquist": x["loss_db"]}
                      for x in level.xtalk],
        "victim_pulse_mV": [1e3 * float(a) for a in v],
        "ffe": {"taps": 5, "coefficients_q110": [int(c) for c in design["q110"]],
                "coefficients_float": [float(c) for c in design["float"]],
                "decision_delay": design["delay"], "output_gain": design["output_gain"],
                "input_gain_codes_per_volt": design["input_gain"],
                "sum_abs_q110": int(np.abs(design["q110"]).sum()),
                "error_power_symbol_units": design["error_power"],
                "gaussian_estimate_ber": design["gauss_ber"],
                "gaussian_estimate_der": design["gauss_ser"]},
        "simulation": {"symbols": n_sym, "bits": n_bit, "seed": SEED,
                       "samples_clipped": result["samples_clipped"], **rows},
        "rtl": rtl,
    }
    (folder / "summary.json").write_text(json.dumps(info, indent=2) + "\n")
    return info, level, fe, pulses


def plots(infos, levels, pulses_by_level):
    fig, ax = plt.subplots(figsize=(7.2, 4.2))
    for name, level in levels.items():
        f = level.f / 1e9
        ax.plot(f, -20 * np.log10(np.abs(level.s_thru[2])), color=COLORS[name], linewidth=2,
                label=f"{LEVELS[name]['label']}: {level.channel_loss_db:.1f} dB"
                + (f" ({level.total_loss_db:.1f} dB with package)" if level.with_package else ""))
    ax.axvline(NYQUIST / 1e9, color=INK2, linewidth=1, linestyle="--")
    ax.text(NYQUIST / 1e9 + 0.8, 3, "53.125 GHz", color=INK2, fontsize=9)
    ax.set_xlim(0, 80)
    ax.set_ylim(0, 70)
    ax.invert_yaxis()
    ax.set_xlabel("Frequency (GHz)", color=INK2)
    ax.set_ylabel("Insertion loss, Sdd21 (dB)", color=INK2)
    ax.set_title("Channel insertion loss, three levels", color=INK, loc="left", fontsize=11)
    style(ax)
    ax.legend(frameon=False, fontsize=9, loc="lower left")
    fig.tight_layout()
    fig.savefig(RESULTS / "loss_vs_frequency.png", dpi=160)
    plt.close(fig)

    fig, axes = plt.subplots(1, 3, figsize=(11, 3.6), sharey=False)
    for ax, (name, level) in zip(axes, levels.items()):
        v = np.asarray(infos[name]["victim_pulse_mV"])
        ax.axhline(0, color=INK2, linewidth=0.8)
        ax.stem(np.arange(len(v)) - 10, v, linefmt=COLORS[name], markerfmt="o", basefmt=" ")
        ax.set_xlim(-6, 25)
        ax.set_xlabel("Symbol position relative to cursor (UI)", color=INK2)
        ax.set_title(f"{LEVELS[name]['label']}", color=INK, loc="left", fontsize=10)
        style(ax)
    axes[0].set_ylabel("Pulse response (mV)", color=INK2)
    fig.suptitle("Symbol-spaced pulse response at 106.25 GBd (after Rx filter and CTLE)",
                 color=INK, x=0.01, ha="left", fontsize=11)
    fig.tight_layout()
    fig.savefig(RESULTS / "pulse_responses.png", dpi=160)
    plt.close(fig)


def write_tables(infos):
    with (RESULTS / "summary.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["level", "channel_loss_db", "loss_with_package_db", "ctle_db", "q110_coefficients",
                    "symbols", "ber_float", "ber_fixed", "der_fixed", "gaussian_ber",
                    "ber_primary", "ber_stretch", "der_primary", "der_stretch",
                    "rtl_baseline_mismatches", "rtl_hand_mismatches"])
        for n, i in infos.items():
            s = i["simulation"]["fixed"]
            w.writerow([n, f"{i['channel_loss_db_at_nyquist']:.1f}",
                        f"{i['loss_with_package_and_terminations_db']:.1f}", i["ctle_dc_gain_db"],
                        " ".join(map(str, i["ffe"]["coefficients_q110"])), i["simulation"]["symbols"],
                        f"{i['simulation']['float']['ber']:.3e}", f"{s['ber']:.3e}", f"{s['der']:.3e}",
                        f"{i['ffe']['gaussian_estimate_ber']:.3e}", s["ber_primary"], s["ber_stretch"],
                        s["der_primary"], s["der_stretch"],
                        i["rtl"]["baseline"]["mismatches_vs_fixed"], i["rtl"]["hand"]["mismatches_vs_fixed"]])
    sets = {n: {"coefficients_q110": i["ffe"]["coefficients_q110"], "decision_delay": i["ffe"]["decision_delay"],
                "output_gain": i["ffe"]["output_gain"]} for n, i in infos.items()}
    (RESULTS / "coefficient_sets.json").write_text(json.dumps(sets, indent=2) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", nargs="*", default=list(LEVELS))
    ap.add_argument("--max-symbols", type=int, default=100_000_000)
    ap.add_argument("--rtl-symbols", type=int, default=300_000)
    args = ap.parse_args()
    RESULTS.mkdir(parents=True, exist_ok=True)
    infos, levels, pulses = {}, {}, {}
    for name in args.levels:
        infos[name], levels[name], _, pulses[name] = analyse(name, args)
    plots(infos, levels, pulses)
    write_tables(infos)


if __name__ == "__main__":
    main()
