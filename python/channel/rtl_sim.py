"""Run an FFE RTL design on a sample stream with Verilator.

Uses testbench/directed/ffe5tap_directed_tb.sv: the stream is written as a
vector file (with the expected fixed-point outputs) and the testbench dumps
y_out for every cycle, so callers get both a mismatch count and the RTL's
own outputs.
"""

import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TESTBENCH = ROOT / "testbench" / "directed" / "ffe5tap_directed_tb.sv"


def _cflags():
    try:
        version = subprocess.run(["c++", "--version"], text=True, stdout=subprocess.PIPE).stdout
    except OSError:
        return []
    return [] if "clang" in version.lower() else ["-CFLAGS", "-std=c++20 -fcoroutines"]


def build(rtl_path, workdir):
    """Compile the testbench with one RTL design; returns the executable path."""
    verilator = shutil.which("verilator")
    if not verilator:
        raise RuntimeError("verilator not found on PATH")
    mdir = Path(workdir) / "obj"
    result = subprocess.run(
        [verilator, "--binary", "-j", "2", *_cflags(), "-Wno-fatal",
         "-Wno-WIDTHEXPAND", "-Wno-WIDTHTRUNC", "--top-module", "ffe5tap_directed_tb",
         str(TESTBENCH), str(rtl_path), "--Mdir", str(mdir), "-o", "sim"],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        raise RuntimeError(f"Verilator build failed for {rtl_path}:\n{result.stdout[-3000:]}")
    return mdir / "sim"


def run(rtl_path, rst_n, x, expected, log_path=None):
    """Simulate one stream. Returns (rtl_outputs, mismatches, cycles)."""
    rst_n, x, expected = (np.asarray(a, dtype=np.int64) for a in (rst_n, x, expected))
    with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
        tmp = Path(tmp)
        sim = build(rtl_path, tmp)
        vectors = tmp / "vectors.txt"
        dump = tmp / "dump.txt"
        with vectors.open("w") as f:
            for r, v, e in zip(rst_n, x, expected):
                f.write(f"{r} {v} {e} 0\n")
        result = subprocess.run(
            [str(sim), f"+VECTORS={vectors}", f"+DUMP={dump}", f"+CYCLES={len(x)}"],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if log_path:
            Path(log_path).write_text(result.stdout)
        outputs = np.loadtxt(dump, dtype=np.int64, ndmin=1)
    mismatches = re.search(r"Total mismatches: (\d+)", result.stdout)
    cycles = re.search(r"Cycles tested: (\d+)", result.stdout)
    if not mismatches or not cycles or len(outputs) != len(x):
        raise RuntimeError(f"simulation of {rtl_path} did not complete:\n{result.stdout[-2000:]}")
    return outputs, int(mismatches.group(1)), int(cycles.group(1))
