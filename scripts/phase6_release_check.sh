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
check_dir rtl
check_dir testbench
check_dir test_vectors

echo
echo "Checking CSV schema and row structure..."
python3 - <<'PYCSV'
import csv
import sys
from pathlib import Path

p = Path("results/generalization/results.csv")
required = {
    "case", "coefficient_structure", "coefficients",
    "ai_iterations", "verification", "logic_cells",
    "dsp", "bram", "max_frequency_mhz",
    "manual_changes", "notes"
}

try:
    with p.open(newline="") as f:
        reader = csv.DictReader(f)
        fields = set(reader.fieldnames or [])
        missing = required - fields
        if missing:
            print("FAIL  Missing CSV columns:", ", ".join(sorted(missing)))
            sys.exit(1)
        rows = list(reader)

    if not rows:
        print("FAIL  CSV contains no data rows")
        sys.exit(1)

    print(f"PASS  CSV schema valid; {len(rows)} rows found")
    for row in rows:
        print(
            "  Case {} / {} / verification={} / frequency={} MHz".format(
                row["case"], row["coefficient_structure"],
                row["verification"], row["max_frequency_mhz"]
            )
        )
except (OSError, csv.Error) as e:
    print("FAIL  CSV read error:", e)
    sys.exit(1)
PYCSV
if [ "$?" -ne 0 ]; then failed=1; fi

echo
echo "Checking tracked-file whitespace..."
if git diff --check; then
    echo "PASS  No whitespace errors in unstaged tracked changes"
else
    echo "FAIL  Whitespace check failed"
    failed=1
fi

echo
echo "Git status:"
git status --short
git log -1 --oneline 2>/dev/null || true

if [ "$failed" -eq 0 ]; then
    echo
    echo "AUDIT RESULT: STRUCTURAL CHECKS PASSED"
    echo "Functional correctness is not established by this audit."
else
    echo
    echo "AUDIT RESULT: CHECKS FAILED"
    exit 1
fi
