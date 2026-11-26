"""Phase 7: one FFE configuration through the whole flow, one results record.

Stages, in order (each one is recorded as PASS / FAIL with its numbers):
  1. reference  - fixed-point model: quantized coefficients vs the float design
  2. rtl        - RTL checked in Verilator against the bit-exact fixed-point model
  3. ber        - PAM4 BER / DER on the channel, fixed-point and float, same samples
  4. pnr        - Yosys synth_ice40 + nextpnr-ice40 (UP5K): LUT4, logic cells, Fmax

Requirement (Chen's plan): BER and DER <= 2e-4 at one sample per cycle with a
fixed pipeline latency (1 cycle in the RTL), compared by logic cells.

  python3 python/flow/run_flow.py --level loss30 --taps 5 --precision P12
"""

import argparse
import datetime
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(ROOT / "python"), str(ROOT / "python" / "dj"), str(ROOT / "python" / "rtl_gen")]

from channel.link import PAM4_LEVELS, decide  # noqa: E402
from dj.ffe_design import TX_NOISE_VAR  # noqa: E402
import hw_sweep  # noqa: E402
import sweep  # noqa: E402
from ffe_gen import hand_csd_rtl, saturation_reachable  # noqa: E402

BER_LIMIT = 2e-4          # primary target for both BER and DER
BER_STRETCH = 1e-6
OUT = ROOT / "results" / "phase7"


def _plain(o):
    if isinstance(o, np.generic):
        return o.item()
    if isinstance(o, np.ndarray):
        return o.tolist()
    raise TypeError(type(o))


def git_commit():
    r = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return r.stdout.strip() or None


def tool_versions():
    def first(cmd):
        try:
            r = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            lines = [l for l in r.stdout.strip().splitlines() if not l.startswith("Preparing to run")]
            return lines[0]
        except Exception as e:  # noqa: BLE001
            return f"unavailable ({e})"
    return {"verilator": first(["verilator", "--version"]),
            "yosys": first([hw_sweep.tool("yosys", "yowasp-yosys"), "-V"]),
            "nextpnr": first([hw_sweep.tool("nextpnr-ice40", "yowasp-nextpnr-ice40"), "--version"])}


def stage_reference(entry, prec):
    bits, frac = sweep.PRECISIONS[prec]
    q = entry["q"][prec]
    flt = np.asarray(entry["float"])
    err = np.abs(np.asarray(q) / 2 ** frac - flt)
    return {"status": "PASS", "bits": bits, "coef_frac": frac, "coefficients_int": [int(v) for v in q],
            "coefficients_float": [float(v) for v in flt],
            "max_coef_quant_error": float(err.max()),
            "sum_abs_coef_int": int(sum(abs(int(v)) for v in q)),
            "saturation_reachable": bool(saturation_reachable(q, frac))}


def stage_ber(pulses, thermal_var, entry, bits, model, symbols, seeds):
    """Same sample stream and RNG use as python/dj/sweep.py, for one design.

    Seeds are 1000+i like the Phase 4 sweep, so the numbers can be compared
    with results/sweep/ber_summary.csv for the same seeds. `model(codes)` is the
    bit-exact fixed-point model of the design (integer codes in, integer codes out).
    """
    flt = np.asarray(entry["float"])
    delay, og = entry["delay"], entry["output_gain"]
    gain = entry["input_gain"]
    hv = pulses["victim"]
    aggressors = [h for _, h in pulses["aggressors"]]
    history = len(hv) + max(sweep.TAPS)
    tot = {"fixed": [0, 0], "float": [0, 0]}
    done_total, clipped = 0, 0
    per_seed = []
    for i in range(seeds):
        rng = np.random.default_rng(1000 + i)
        seed_err = 0
        done = 0
        while done < symbols:
            n = min(sweep.CHUNK, symbols - done)
            m = n + history
            s = rng.choice(PAM4_LEVELS, size=m)
            r = np.convolve(s + rng.normal(0.0, np.sqrt(TX_NOISE_VAR), m), hv, "valid")
            for ha in aggressors:
                r += np.convolve(rng.choice(PAM4_LEVELS, size=m).astype(float), ha, "valid")
            r += rng.normal(0.0, np.sqrt(thermal_var), len(r))
            x = r * gain
            sc = np.round(x * 2 ** (bits - 4))
            lim = 2 ** (bits - 1)
            clipped += int(np.count_nonzero((sc > lim - 1) | (sc < -lim)))
            xi = np.clip(sc, -lim, lim - 1).astype(np.int64)
            j = np.arange(max(sweep.TAPS) - 1, len(x))
            sent = s[j + len(hv) - 1 - delay]
            yq = model(xi) / 2 ** (bits - 4)
            yf = np.convolve(x, flt)[: len(x)]
            for key, y in (("fixed", yq), ("float", yf)):
                be, se = sweep.count(sent, decide(y[j], og))
                tot[key][0] += be
                tot[key][1] += se
                if key == "fixed":
                    seed_err += be
            done += n
        done_total += done
        per_seed.append({"seed": 1000 + i, "symbols": done, "bit_errors_fixed": seed_err})
    nbits = 2 * done_total
    res = {"symbols": done_total, "seeds": seeds, "samples_clipped": clipped, "per_seed": per_seed}
    for key in tot:
        be, se = tot[key]
        res[f"bit_errors_{key}"] = be
        res[f"symbol_errors_{key}"] = se
        res[f"ber_{key}"] = be / nbits
        res[f"der_{key}"] = se / done_total
    res["ber_primary"] = "PASS" if res["ber_fixed"] <= BER_LIMIT else "FAIL"
    res["der_primary"] = "PASS" if res["der_fixed"] <= BER_LIMIT else "FAIL"
    res["ber_stretch"] = "PASS" if res["ber_fixed"] <= BER_STRETCH else "FAIL"
    res["status"] = "PASS" if res["ber_primary"] == res["der_primary"] == "PASS" else "FAIL"
    return res


def _pnr_stage(rtl, work, pnr_seeds):
    js, stats = hw_sweep.yosys(rtl, work)
    pnr = {"status": "FAIL", **stats}
    if js is not None and stats["lut4"] is not None:
        res = hw_sweep.pnr(js, work, pnr_seeds)
        lcs = [r[0] for r in res if r[0]]
        fms = [r[1] for r in res if r[1]]
        if lcs:
            pnr.update(status="PASS", logic_cells=lcs[0], logic_cells_all_seeds=lcs,
                       fmax_median_mhz=float(np.median(fms)), fmax_min_mhz=min(fms), fmax_max_mhz=max(fms),
                       seeds_ok=len(fms), fits_up5k=lcs[0] <= hw_sweep.UP5K_LCS)
    return pnr


def _finish(rec, pnr, t0, name):
    rec["stages"]["pnr"] = pnr
    ok = all(s["status"] == "PASS" for s in rec["stages"].values())
    rec["summary"] = {"all_stages_pass": ok, "ber": rec["stages"]["ber"]["ber_fixed"],
                      "der": rec["stages"]["ber"]["der_fixed"], "logic_cells": pnr.get("logic_cells"),
                      "fmax_median_mhz": pnr.get("fmax_median_mhz"), "runtime_s": round(time.time() - t0, 1)}
    (OUT / f"{name}.json").write_text(json.dumps(rec, indent=1, default=_plain) + "\n")
    return rec


def run(level, taps, prec, symbols, seeds, pnr_seeds, name=None):
    t0 = time.time()
    name = name or f"{level}_t{taps}_{prec}_hand"
    bits, frac = sweep.PRECISIONS[prec]
    pulses, thermal_var, front = sweep.load_front_end(level)
    designs = sweep.designs_for(pulses, thermal_var)
    entry = designs[taps]
    rec = {"name": name, "date_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
           "git_commit": git_commit(), "tools": tool_versions(),
           "config": {"channel": level, "taps": taps, "precision": prec, "sample_bits": bits,
                      "coef_frac": frac, "architecture": "hand CSD, direct form",
                      "throughput": "1 sample/cycle", "latency_cycles": 1,
                      "ber_limit": BER_LIMIT, "ctle_dc_gain_db": front["ctle_dc_gain_db"],
                      "sampling_phase": front["sampling_phase"]},
           "stages": {}}
    rec["stages"]["reference"] = stage_reference(entry, prec)
    q = entry["q"][prec]
    work = OUT / name
    work.mkdir(parents=True, exist_ok=True)
    rtl = work / f"ffe_{name}.sv"
    rtl.write_text(hand_csd_rtl(q, bits, frac, f"{level} {taps}-tap {prec}"))
    with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
        status, bad = hw_sweep.check_rtl(rtl, q, bits, frac, tmp)
    rec["stages"]["rtl"] = {"status": status, "mismatches": bad, "rtl_file": str(rtl.relative_to(ROOT)),
                            "check": "20000-cycle random + extreme + reset stream vs fixed-point model"}
    rec["stages"]["ber"] = stage_ber(pulses, thermal_var, entry, bits,
                                     lambda xi: sweep.fixed_general(xi, q, frac, bits), symbols, seeds)
    return _finish(rec, _pnr_stage(rtl, work, pnr_seeds), t0, name)


def check_rtl_model(rtl, model, bits, work, cycles=20000, seed=7):
    """Random + extreme + reset stream through Verilator against a model(codes) callable."""
    rng = np.random.default_rng(seed)
    lim = 2 ** (bits - 1)
    x = rng.integers(-lim, lim, cycles)
    x[: cycles // 4] = np.where(rng.random(cycles // 4) < 0.5, lim - 1, -lim)
    x[cycles // 2: cycles // 2 + 200] = lim - 1
    rst = np.ones(cycles, int)
    rst[[0, 1, cycles // 3, cycles // 3 + 1]] = 0
    y = np.zeros(cycles, dtype=np.int64)
    start = 0
    for i in list(np.nonzero(rst == 0)[0]) + [cycles]:
        if i > start:
            y[start:i] = model(x[start:i].astype(np.int64))
        start = i + 1
    y[rst == 0] = 0
    work = Path(work)
    obj = work / "obj"
    code, _ = hw_sweep.run([hw_sweep.tool("verilator"), "--binary", "-j", "1", *hw_sweep.verilator_cflags(),
                            "-Wno-fatal", "-Wno-WIDTHEXPAND", "-Wno-WIDTHTRUNC", "--top-module", "ffe_stream_tb",
                            f"-GW={bits}", str(hw_sweep.TB), str(rtl), "--Mdir", str(obj), "-o", "sim"],
                           work / "build.log")
    if code != 0:
        return "BUILD_FAIL", None
    vec, dump = work / "v.txt", work / "d.txt"
    vec.write_text("".join(f"{r} {v}\n" for r, v in zip(rst, x)))
    hw_sweep.run([str(obj / "sim"), f"+VECTORS={vec}", f"+DUMP={dump}"], work / "sim.log")
    got = np.loadtxt(dump, dtype=np.int64)
    bad = int(np.count_nonzero(got != y))
    return ("PASS" if bad == 0 else "FAIL"), bad


def run_design(level, d, rtl_text, model, symbols, seeds, pnr_seeds, name, context=None):
    """Same four stages for a per-tap design (python/flow/margin_design.Design).

    context = (pulses, thermal_var, front, entry) to avoid reloading the channel.
    """
    t0 = time.time()
    if context is None:
        pulses, thermal_var, front = sweep.load_front_end(level)
        entry = sweep.designs_for(pulses, thermal_var)[len(d.f)]
    else:
        pulses, thermal_var, front, entry = context
    rec = {"name": name, "date_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
           "git_commit": git_commit(), "tools": tool_versions(),
           "config": {"channel": level, "taps": len(d.f), "architecture": "hand CSD, per-tap widths",
                      "W": d.W, "F": d.F, "coef_bits_per_tap": d.f, "dropped_sample_lsbs_per_tap": d.t,
                      "accumulator_offset": d.b, "throughput": "1 sample/cycle", "latency_cycles": 1,
                      "ber_limit": BER_LIMIT},
           "stages": {}}
    q = d.q
    err = np.abs(np.asarray(q) / 2 ** d.F - np.asarray(entry["float"]))
    rec["stages"]["reference"] = {"status": "PASS", "coefficients_int_at_F": [int(v) for v in q],
                                  "coefficients_float": [float(v) for v in entry["float"]],
                                  "max_coef_quant_error": float(err.max())}
    work = OUT / name
    work.mkdir(parents=True, exist_ok=True)
    rtl = work / f"ffe_{name}.sv"
    rtl.write_text(rtl_text)
    with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
        status, bad = check_rtl_model(rtl, model, d.W, tmp)
    rec["stages"]["rtl"] = {"status": status, "mismatches": bad, "rtl_file": str(rtl.relative_to(ROOT)),
                            "check": "20000-cycle random + extreme + reset stream vs fixed-point model"}
    rec["stages"]["ber"] = stage_ber(pulses, thermal_var, entry, d.W, model, symbols, seeds)
    return _finish(rec, _pnr_stage(rtl, work, pnr_seeds), t0, name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="loss30")
    ap.add_argument("--taps", type=int, default=5)
    ap.add_argument("--precision", default="P12", choices=list(sweep.PRECISIONS))
    ap.add_argument("--symbols", type=int, default=20_000_000, help="symbols per seed")
    ap.add_argument("--seeds", type=int, default=2)
    ap.add_argument("--pnr-seeds", type=int, default=3)
    args = ap.parse_args()
    rec = run(args.level, args.taps, args.precision, args.symbols, args.seeds, args.pnr_seeds)
    print(json.dumps(rec["summary"], indent=1))
    for k, v in rec["stages"].items():
        print(f"  {k:10s} {v['status']}")


if __name__ == "__main__":
    main()
