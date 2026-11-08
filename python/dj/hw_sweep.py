"""Phase 4 hardware sweep: RTL generation, RTL check, synthesis and timing.

For every (level, taps, precision) coefficient set from the BER sweep:
  1. write hand-CSD direct-form RTL (rtl/sweep/<level>/)
  2. optionally check it in Verilator against the fixed-point model
  3. Yosys synth_ice40 (cell counts)
  4. nextpnr-ice40 on the UP5K over several seeds (logic cells, Fmax);
     designs that do not fit fall back to ECP5 (LFE5U-85F)

  python3 python/dj/hw_sweep.py --levels loss30 --seeds 5 --out results/sweep/hw_loss30.csv
"""

import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(HERE.parent), str(ROOT / "python" / "rtl_gen")]

from channel.equalizer import quantize  # noqa: E402
from ffe_gen import baseline_rtl, hand_csd_rtl, saturation_reachable  # noqa: E402
from sweep import PRECISIONS, fixed_general  # noqa: E402

RTL_DIR = ROOT / "rtl" / "sweep"
TB = ROOT / "testbench" / "sweep" / "ffe_stream_tb.sv"
UP5K_LCS = 5280


def tool(*names):
    for n in names:
        p = shutil.which(n)
        if p:
            return p
    raise SystemExit(f"none of {names} on PATH")


def rel(p):
    return os.path.relpath(p, ROOT)


def run(cmd, log):
    r = subprocess.run(cmd, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_text(f"$ {' '.join(map(str, cmd))}\n\n{r.stdout}")
    return r.returncode, r.stdout


def verilator_cflags():
    v = subprocess.run(["c++", "--version"], text=True, stdout=subprocess.PIPE).stdout
    return [] if "clang" in v.lower() else ["-CFLAGS", "-std=c++20 -fcoroutines"]


def check_rtl(rtl, q, bits, frac, work, cycles=20000, seed=7):
    """Random + extreme stream through Verilator vs the fixed-point model."""
    rng = np.random.default_rng(seed)
    lim = 2 ** (bits - 1)
    x = rng.integers(-lim, lim, cycles)
    x[: cycles // 4] = np.where(rng.random(cycles // 4) < 0.5, lim - 1, -lim)   # extremes
    x[cycles // 2: cycles // 2 + 200] = lim - 1                                  # hold max
    rst = np.ones(cycles, int)
    rst[[0, 1, cycles // 3, cycles // 3 + 1]] = 0                                # resets mid-stream
    # Vectorized model: segments between resets.
    qa = np.asarray(q, dtype=np.int64)
    y = np.zeros(cycles, dtype=np.int64)
    start = 0
    for i in list(np.nonzero(rst == 0)[0]) + [cycles]:
        if i > start:
            seg = fixed_general(x[start:i], qa, frac, bits)
            # y_out registers the combinational result of the same cycle's x_in
            y[start:i] = seg
        start = i + 1
    y[rst == 0] = 0
    obj = Path(work) / "obj"
    code, out = run([tool("verilator"), "--binary", "-j", "1", *verilator_cflags(), "-Wno-fatal",
                     "-Wno-WIDTHEXPAND", "-Wno-WIDTHTRUNC", "--top-module", "ffe_stream_tb",
                     f"-GW={bits}", str(TB), str(rtl), "--Mdir", str(obj), "-o", "sim"],
                    Path(work) / "build.log")
    if code != 0:
        return "BUILD_FAIL", None
    vec = Path(work) / "v.txt"
    dump = Path(work) / "d.txt"
    vec.write_text("".join(f"{r} {v}\n" for r, v in zip(rst, x)))
    run([str(obj / "sim"), f"+VECTORS={vec}", f"+DUMP={dump}"], Path(work) / "sim.log")
    got = np.loadtxt(dump, dtype=np.int64)
    bad = int(np.count_nonzero(got != y))
    return ("PASS" if bad == 0 else "FAIL"), bad


def yosys(rtl, work):
    js, stat = work / "design.json", work / "stat.txt"
    code, _ = run([tool("yosys", "yowasp-yosys"), "-q", "-l", rel(work / "yosys.log"), "-p",
                   f"read_verilog -sv {rel(rtl)}; hierarchy -top ffe_pam4; "
                   f"synth_ice40 -top ffe_pam4 -json {rel(js)}; tee -o {rel(stat)} stat"],
                  work / "yosys_console.log")
    text = stat.read_text() if stat.exists() else ""
    def num(pat):
        m = re.findall(pat, text)
        return int(m[-1]) if m else None
    return (js if code == 0 else None), {
        "lut4": num(r"(\d+)\s+SB_LUT4"), "dff": num(r"(\d+)\s+SB_DFF\w*"),
        "carry": num(r"(\d+)\s+SB_CARRY")}


def pnr(js, work, seeds):
    rows = []
    for seed in range(1, seeds + 1):
        code, out = run([tool("nextpnr-ice40", "yowasp-nextpnr-ice40"), "--up5k", "--package", "sg48",
                         "--freq", "12", "--seed", str(seed), "--json", str(js)],
                        work / f"pnr{seed}.log")
        lc = re.search(r"ICESTORM_LC:\s+(\d+)/", out)
        fm = re.findall(r"Max frequency for clock[^:]*: ([\d.]+) MHz", out)
        rows.append((int(lc.group(1)) if lc and code == 0 else None,
                     float(fm[-1]) if fm and code == 0 else None))
    return rows


def ecp5(rtl, work, seeds):
    """Fallback for designs that do not fit the UP5K: ECP5 LFE5U-85F."""
    js = work / "design_ecp5.json"
    stat = work / "stat_ecp5.txt"
    code, _ = run([tool("yosys", "yowasp-yosys"), "-q", "-l", rel(work / "yosys_ecp5.log"), "-p",
                   f"read_verilog -sv {rel(rtl)}; hierarchy -top ffe_pam4; "
                   f"synth_ecp5 -top ffe_pam4 -json {rel(js)}; tee -o {rel(stat)} stat"],
                  work / "yosys_ecp5_console.log")
    text = stat.read_text() if stat.exists() else ""
    m = re.findall(r"(\d+)\s+LUT4", text)
    result = {"ecp5_lut4": int(m[-1]) if m else None}
    fms = []
    for seed in range(1, seeds + 1):
        code, out = run([tool("nextpnr-ecp5", "yowasp-nextpnr-ecp5"), "--85k", "--package", "CABGA381",
                         "--freq", "50", "--seed", str(seed), "--json", str(js)],
                        work / f"pnr_ecp5_{seed}.log")
        fm = re.findall(r"Max frequency for clock[^:]*: ([\d.]+) MHz", out)
        if code == 0 and fm:
            fms.append(float(fm[-1]))
        comb = re.search(r"TRELLIS_COMB:\s+(\d+)/", out)
        if comb:
            result["ecp5_comb"] = int(comb.group(1))
    result["ecp5_fmax_median_mhz"] = float(np.median(fms)) if fms else None
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", nargs="+", required=True)
    ap.add_argument("--taps", nargs="*", type=int)
    ap.add_argument("--precisions", nargs="*")
    ap.add_argument("--seeds", type=int, default=5)
    ap.add_argument("--check", action="store_true", help="run the Verilator check")
    ap.add_argument("--baseline", action="store_true", help="also synthesize generic-multiplier baseline")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    rows = []
    for level in args.levels:
        coeffs = json.loads((ROOT / "results/sweep" / f"ber_{level}.coefficients.json").read_text())
        for taps_s, entry in coeffs.items():
            taps = int(taps_s)
            if args.taps and taps not in args.taps:
                continue
            for prec, (bits, frac) in PRECISIONS.items():
                if args.precisions and prec not in args.precisions:
                    continue
                q = entry["q"][prec]
                for arch in (["hand", "baseline"] if args.baseline else ["hand"]):
                    name = f"{level}_t{taps}_{prec}_{arch}"
                    RTL_DIR.joinpath(level).mkdir(parents=True, exist_ok=True)
                    rtl = RTL_DIR / level / f"ffe_t{taps}_{prec}_{arch}.sv"
                    rtl.write_text(hand_csd_rtl(q, bits, frac, f"{level} {taps}-tap {prec}")
                                   if arch == "hand" else baseline_rtl(q, bits, frac))
                    work = ROOT / "results/sweep/hw" / name
                    work.mkdir(parents=True, exist_ok=True)
                    row = {"level": level, "taps": taps, "precision": prec, "arch": arch,
                           "sum_abs_coef": sum(abs(v) for v in q),
                           "saturation_reachable": saturation_reachable(q, frac)}
                    if args.check:
                        with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
                            row["rtl_check"], row["rtl_mismatches"] = check_rtl(rtl, q, bits, frac, tmp)
                    js, stats = yosys(rtl, work)
                    row.update(stats)
                    fits = js is not None and stats["lut4"] is not None and stats["lut4"] <= UP5K_LCS
                    if fits:
                        res = pnr(js, work, args.seeds)
                        lcs = [r[0] for r in res if r[0]]
                        fms = [r[1] for r in res if r[1]]
                        row["logic_cells"] = lcs[0] if lcs else None
                        row["fmax_median_mhz"] = float(np.median(fms)) if fms else None
                        row["fmax_min_mhz"] = min(fms) if fms else None
                        row["fmax_max_mhz"] = max(fms) if fms else None
                        row["seeds_ok"] = len(fms)
                        row["fits_up5k"] = bool(lcs)
                    else:
                        row["fits_up5k"] = False
                        row.update(ecp5(rtl, work, args.seeds))
                    print(name, {k: row.get(k) for k in ("lut4", "logic_cells", "fmax_median_mhz", "rtl_check", "fits_up5k", "ecp5_fmax_median_mhz")},
                          flush=True)
                    rows.append(row)
    keys = sorted({k for r in rows for k in r}, key=lambda k: list(rows[0]).index(k) if k in rows[0] else 99)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)


if __name__ == "__main__":
    main()
