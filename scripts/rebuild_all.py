#!/usr/bin/env python3
"""Rebuild and re-verify every FFE implementation from source.

For each design this runs, in order:
  1. Verilator: the original 1000-sample regression vectors
  2. Verilator: the directed reset / saturation / extreme-input vectors
  3. Yosys synth_ice40 (LUT4 count)
  4. nextpnr-ice40 on the UP5K over several placement seeds
     (logic cells and Fmax per seed; median, min and max reported)

Outputs go to results/rebuild/: per-design logs, tool_versions.txt,
summary.csv (one row per design) and fmax_seeds.csv (one row per seed).

Usage:
  python3 scripts/rebuild_all.py                 # all designs, 10 seeds
  python3 scripts/rebuild_all.py --seeds 3       # quicker
  python3 scripts/rebuild_all.py --only C_ai C_hand

Tools are found on PATH as verilator, yosys and nextpnr-ice40; the
yowasp-* Python builds are used as a fallback for yosys and nextpnr.
"""

import argparse
import csv
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "results" / "rebuild"

REGRESSION = {
    "A": (ROOT / "test_vectors/input_vectors.txt",
          ROOT / "test_vectors/expected_vectors.txt"),
    "B": (ROOT / "results/generalization/case_B/baseline/input_vectors.txt",
          ROOT / "results/generalization/case_B/baseline/expected_vectors.txt"),
    "C": (ROOT / "results/generalization/case_C/baseline/input_vectors.txt",
          ROOT / "results/generalization/case_C/baseline/expected_vectors.txt"),
}

# name: (case, implementation, rtl path)
DESIGNS = {
    "A_baseline": ("A", "baseline", "rtl/ffe5tap_pam4.sv"),
    "A_ai":       ("A", "ai",       "rtl/ffe5tap_pam4_claude_resource1.sv"),
    "A_hand":     ("A", "hand",     "rtl/hand/ffe5tap_caseA_hand.sv"),
    "B_baseline": ("B", "baseline", "rtl/generalization/ffe5tap_caseB_baseline.sv"),
    "B_ai":       ("B", "ai",       "rtl/generalization/optimized/ffe5tap_caseB_optimized.sv"),
    "B_hand":     ("B", "hand",     "rtl/hand/ffe5tap_caseB_hand.sv"),
    "C_baseline": ("C", "baseline", "rtl/generalization/ffe5tap_caseC_baseline.sv"),
    "C_ai":       ("C", "ai",       "rtl/generalization/optimized/ffe5tap_caseC_optimized.sv"),
    "C_hand":     ("C", "hand",     "rtl/hand/ffe5tap_caseC_hand.sv"),
}

# Channel-derived coefficient sets (python/channel/hardware_ber.py) add
# baseline, hand and, when present, optimized designs. They have no
# 1000-sample regression set; the directed vectors and the channel BER
# runs cover them.
CHANNEL_SETS = ROOT / "results/channel/coefficient_sets.json"
if CHANNEL_SETS.exists():
    for _name in json.loads(CHANNEL_SETS.read_text()):
        for _impl, _path in (("baseline", f"rtl/channel/ffe5tap_{_name}_baseline.sv"),
                             ("hand", f"rtl/channel/ffe5tap_{_name}_hand.sv"),
                             ("ai", f"rtl/channel/optimized/ffe5tap_{_name}_optimized.sv")):
            if (ROOT / _path).exists():
                DESIGNS[f"{_name}_{_impl}"] = (_name, _impl, _path)

REGRESSION_TB = ROOT / "testbench/generalization/ffe5tap_generalization_tb.sv"
DIRECTED_TB = ROOT / "testbench/directed/ffe5tap_directed_tb.sv"
DIRECTED_VECTORS = ROOT / "test_vectors/directed"


def find_tool(*names):
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    sys.exit(f"ERROR: none of {', '.join(names)} found on PATH")


def run(cmd, log_path, cwd=ROOT, env=None):
    """Run a command, tee everything to log_path, return its stdout text."""
    result = subprocess.run(cmd, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path.write_text(f"$ {' '.join(map(str, cmd))}\n\n{result.stdout}")
    if result.returncode != 0:
        print(f"    command failed ({result.returncode}), see {log_path.relative_to(ROOT)}")
    return result.returncode, result.stdout


def first_line(cmd):
    try:
        out = subprocess.run(cmd, text=True, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=300).stdout
    except (OSError, subprocess.TimeoutExpired):
        return "unavailable"
    lines = [l for l in out.splitlines() if l.strip() and "Preparing to run" not in l]
    return lines[0].strip() if lines else "unknown"


def verilator_cflags():
    try:
        version = subprocess.run(["c++", "--version"], text=True,
                                 stdout=subprocess.PIPE).stdout
    except OSError:
        return []
    # GCC needs -fcoroutines for Verilator's timing support; Clang does not.
    return ["-CFLAGS", "-std=c++20 -fcoroutines"] if "clang" not in version.lower() else []


def simulate(tools, tb, top, rtl, work, plusargs, log):
    build = work / f"obj_{top}"
    shutil.rmtree(build, ignore_errors=True)
    code, _ = run([tools["verilator"], "--binary", "-j", "2", *verilator_cflags(),
                   "-Wno-fatal", "-Wno-WIDTHEXPAND", "-Wno-WIDTHTRUNC",
                   "--top-module", top, str(tb), str(rtl),
                   "--Mdir", str(build), "-o", "sim"],
                  work / f"{log}_compile.log")
    if code != 0:
        return "BUILD_FAIL", None, None
    code, out = run([str(build / "sim"), *plusargs], work / f"{log}.log")
    shutil.rmtree(build, ignore_errors=True)
    samples = re.search(r"(?:Samples|Cycles) tested: (\d+)", out)
    mism = re.search(r"Total mismatches: (\d+)", out)
    verdict = "PASS" if "RESULT: PASS" in out else "FAIL"
    return verdict, int(samples.group(1)) if samples else None, \
        int(mism.group(1)) if mism else None


def synthesize(tools, rtl, work):
    # Paths are relative to the repo root: the yowasp builds can only see
    # the current directory tree.
    rel = lambda p: os.path.relpath(p, ROOT)
    json_path = work / "design.json"
    stat_path = work / "yosys_stat.txt"
    code, _ = run([tools["yosys"], "-q", "-l", rel(work / "yosys.log"), "-p",
                   f"read_verilog -sv {rel(rtl)}; hierarchy -top ffe5tap_pam4; "
                   f"synth_ice40 -top ffe5tap_pam4 -json {rel(json_path)}; "
                   f"tee -o {rel(stat_path)} stat"],
                  work / "yosys_console.log")
    stat = stat_path.read_text() if stat_path.exists() else ""
    luts = re.findall(r"(\d+)\s+SB_LUT4", stat) or re.findall(r"SB_LUT4\s+(\d+)", stat)
    return (json_path if code == 0 else None), (int(luts[-1]) if luts else None)


def place_and_route(tools, json_path, work, seeds):
    rows = []
    for seed in range(1, seeds + 1):
        code, out = run([tools["nextpnr"], "--up5k", "--package", "sg48",
                         "--freq", "12", "--seed", str(seed),
                         "--json", str(json_path),
                         "--asc", str(work / f"seed{seed}.asc")],
                        work / f"nextpnr_seed{seed}.log")
        (work / f"seed{seed}.asc").unlink(missing_ok=True)
        lc = re.search(r"ICESTORM_LC:\s+(\d+)/", out)
        fmax = re.findall(r"Max frequency for clock[^:]*: ([\d.]+) MHz", out)
        rows.append({"seed": seed,
                     "logic_cells": int(lc.group(1)) if lc and code == 0 else None,
                     "fmax_mhz": float(fmax[-1]) if fmax and code == 0 else None})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--seeds", type=int, default=10)
    parser.add_argument("--only", nargs="*", choices=sorted(DESIGNS))
    parser.add_argument("--out", default="results/rebuild",
                        help="output folder, relative to the repo root")
    args = parser.parse_args()
    global OUT
    OUT = ROOT / args.out

    tools = {
        "verilator": find_tool("verilator"),
        "yosys": find_tool("yosys", "yowasp-yosys"),
        "nextpnr": find_tool("nextpnr-ice40", "yowasp-nextpnr-ice40"),
    }

    OUT.mkdir(parents=True, exist_ok=True)
    versions = [f"python: {sys.version.split()[0]}"]
    versions += [f"{name}: {first_line([path, flag])}" for name, path, flag in (
        ("verilator", tools["verilator"], "--version"),
        ("yosys", tools["yosys"], "-V"),
        ("nextpnr-ice40", tools["nextpnr"], "--version"))]
    if "UNKNOWN" in versions[1]:
        try:
            from importlib.metadata import version
            versions[1] += f" (PyPI verilator package {version('verilator')})"
        except Exception:
            pass
    (OUT / "tool_versions.txt").write_text("\n".join(versions) + "\n")
    print("\n".join(versions))

    print("Regenerating directed vectors...")
    subprocess.run([sys.executable, str(ROOT / "python/verification/generate_directed_vectors.py")],
                   check=True, stdout=subprocess.DEVNULL)

    names = args.only or list(DESIGNS)
    summary, seed_rows = [], []
    for name in names:
        case, impl, rtl_rel = DESIGNS[name]
        rtl = ROOT / rtl_rel
        work = OUT / name
        work.mkdir(parents=True, exist_ok=True)
        print(f"[{name}] {rtl_rel}")

        if case in REGRESSION:
            inp, exp = REGRESSION[case]
            reg = simulate(tools, REGRESSION_TB, "ffe5tap_generalization_tb", rtl, work,
                           [f"+INPUT={inp}", f"+EXPECTED={exp}"], "sim_regression")
            print(f"    regression: {reg[0]} ({reg[1]} samples, {reg[2]} mismatches)")
        else:
            reg = ("n/a", None, None)

        vectors = DIRECTED_VECTORS / f"case_{case}.txt"
        n_cycles = sum(1 for line in vectors.open() if line.strip())
        dirc = simulate(tools, DIRECTED_TB, "ffe5tap_directed_tb", rtl, work,
                        [f"+VECTORS={vectors}", f"+CYCLES={n_cycles}"], "sim_directed")
        print(f"    directed:   {dirc[0]} ({dirc[1]} cycles, {dirc[2]} mismatches)")

        json_path, luts = synthesize(tools, rtl, work)
        rows = place_and_route(tools, json_path, work, args.seeds) if json_path else []
        for row in rows:
            seed_rows.append({"design": name, **row})
        fmax = [r["fmax_mhz"] for r in rows if r["fmax_mhz"] is not None]
        lcs = [r["logic_cells"] for r in rows if r["logic_cells"] is not None]
        print(f"    synth:      {luts} LUT4, {lcs[0] if lcs else '?'} LC, "
              f"Fmax median {round(statistics.median(fmax), 2) if fmax else '?'} MHz over {len(fmax)} seeds")

        summary.append({
            "design": name, "case": case, "implementation": impl, "rtl": rtl_rel,
            "regression": reg[0], "regression_samples": reg[1], "regression_mismatches": reg[2],
            "directed": dirc[0], "directed_cycles": dirc[1], "directed_mismatches": dirc[2],
            "yosys_lut4": luts,
            "logic_cells": int(statistics.median(lcs)) if lcs else None,
            "fmax_median_mhz": round(statistics.median(fmax), 2) if fmax else None,
            "fmax_min_mhz": min(fmax) if fmax else None,
            "fmax_max_mhz": max(fmax) if fmax else None,
            "seeds": len(fmax),
        })

    with (OUT / "summary.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(summary[0]))
        writer.writeheader()
        writer.writerows(summary)
    with (OUT / "fmax_seeds.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["design", "seed", "logic_cells", "fmax_mhz"])
        writer.writeheader()
        writer.writerows(seed_rows)

    failed = [r["design"] for r in summary
              if r["regression"] not in ("PASS", "n/a") or r["directed"] != "PASS"]
    print(f"\nWrote {args.out}/summary.csv and fmax_seeds.csv")
    print("RESULT:", "PASS" if not failed else "FAIL: " + ", ".join(failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
