#!/bin/bash

set -u

projectRoot="$(pwd)"
outputFile="$projectRoot/results/phase4/investigation_summary.txt"

{
    echo "PHASE 4 — SYNTHESIS AND CRITICAL-PATH INVESTIGATION"
    echo "Project root: $projectRoot"
    echo "Date: $(date)"
    echo

    for caseName in A B C; do
        for implementation in baseline optimized; do
            logDir="$projectRoot/results/generalization/case_${caseName}/${implementation}"

            echo "============================================================"
            echo "CASE $caseName — $implementation"
            echo "Log directory: $logDir"
            echo "============================================================"

            if [ ! -d "$logDir" ]; then
                echo "WARNING: Log directory not found."
                echo
                continue
            fi

            for logName in yosys.log nextpnr.log verilator_simulation.log; do
                logFile="$logDir/$logName"
                if [ -f "$logFile" ]; then
                    echo
                    echo "--- $logName: key evidence ---"
                    grep -niE \
                      'SB_MAC16|ICESTORM_DSP|DSP|mul|multiply|multiplication|number of cells|SB_LUT4|ICESTORM_LC|ICESTORM_RAM|critical path|maximum frequency|max frequency|frequency|setup|logic levels|routing|slack|period' \
                      "$logFile" | tail -n 100 || true
                else
                    echo "MISSING LOG: $logFile"
                fi
            done

            echo
        done
    done
} | tee "$outputFile"

echo
echo "Saved summary to:"
echo "$outputFile"
