#!/bin/bash
set -u
cd "$(dirname "$0")/.." || exit 1
failed=0

check_file() {
    if [ -f "$1" ]; then
        echo "PASS  File exists: $1"
    else
        echo "FAIL  Missing file: $1"
        failed=1
    fi
}

check_dir() {
    if [ -d "$1" ] && [ -n "$(find "$1" -type f -print -quit)" ]; then
        echo "PASS  Directory contains files: $1"
    else
        echo "FAIL  Missing or empty directory: $1"
        failed=1
    fi
}

echo "======================================"
echo " AI EQUALIZER BENCHMARK: PHASE 6 AUDIT"
echo "======================================"

check_file README.md
check_file .gitignore
check_file documentation/reproducibility.md
check_file results/phase4/phase4_report.md
check_file results/generalization/results.csv
check_file prompts/generalization/ai_log.md
check_file results/phase6/phase6_release_report.md
check_dir rtl
check_dir testbench
check_dir test_vectors

echo
echo "Checking CSV schema and all six implementation rows..."
python3 - <<'PYCSV'
import csv
import sys
from pathlib import Path

p = Path("results/generalization/results.csv")
required = {
    "case", "implementation", "coefficient_structure", "coefficients",
    "functional_verification", "functional_samples",
    "functional_mismatches", "nextpnr_logic_cells", "yosys_lut4",
    "dsp_blocks", "bram_blocks", "max_frequency_mhz",
    "manual_rtl_changes", "notes"
}

try:
    with p.open(newline="") as f:
        reader = csv.DictReader(f)
        missing = required - set(reader.fieldnames or [])
        if missing:
            print("FAIL  Missing columns:", ", ".join(sorted(missing)))
            sys.exit(1)
        rows = list(reader)

    expected = {
        ("A", "baseline"), ("A", "optimized"),
        ("B", "baseline"), ("B", "optimized"),
        ("C", "baseline"), ("C", "optimized")
    }
    actual = {(r["case"], r["implementation"]) for r in rows}

    if len(rows) != 6 or actual != expected:
        print("FAIL  Expected exactly six unique case/implementation rows")
        print("Rows found:", len(rows))
        print("Missing:", sorted(expected - actual))
        print("Unexpected:", sorted(actual - expected))
        sys.exit(1)

    for r in rows:
        for col in ("nextpnr_logic_cells", "yosys_lut4",
                    "dsp_blocks", "bram_blocks", "max_frequency_mhz"):
            if not r[col].strip():
                print("FAIL  Blank metric:", r["case"], r["implementation"], col)
                sys.exit(1)

        if r["case"] in ("B", "C"):
            if r["functional_samples"] != "1000" or r["functional_mismatches"] != "0":
                print("FAIL  Unexpected recorded verification values for", r["case"])
                sys.exit(1)

    print("PASS  CSV schema and six unique rows are valid")
    for r in rows:
        print(
            "  Case {}/{}: {} LC, {} LUT4, {} MHz, verification={}".format(
                r["case"], r["implementation"], r["nextpnr_logic_cells"],
                r["yosys_lut4"], r["max_frequency_mhz"],
                r["functional_verification"]
            )
        )
except (OSError, csv.Error) as e:
    print("FAIL  CSV read error:", e)
    sys.exit(1)
PYCSV
if [ "$?" -ne 0 ]; then failed=1; fi

echo
echo "Checking Git whitespace..."
if git diff --check; then
    echo "PASS  No whitespace errors in unstaged tracked changes"
else
    echo "FAIL  Whitespace check failed"
    failed=1
fi

echo
echo "Review status:"
git status --short

if [ "$failed" -eq 0 ]; then
    echo
    echo "AUDIT RESULT: STRUCTURAL CHECKS PASSED"
else
    echo
    echo "AUDIT RESULT: CHECKS FAILED"
    exit 1
fi
