# Generalization Experiment Log

## Case A — Symmetric + Power-of-Two

Coefficients:
[51, -154, 1024, 154, -51]

Baseline:
- Verification: PASS
- Samples: 1000
- Mismatches: 0
- Logic cells: 629
- DSP: 0
- BRAM: 0
- Maximum frequency: 19.96 MHz

AI optimization:
- Model: Claude
- AI iterations: 1
- Manual RTL changes: None
- Verification: PASS
- Samples: 1000
- Mismatches: 0
- Logic cells: 468
- DSP: 0
- BRAM: 0
- Maximum frequency: 20.75 MHz

Notes:
AI identified coefficient symmetry and the power-of-two center
coefficient and generated a resource-reduced implementation.

## Phase 2 — Baseline Generalization Results

### Case B — General Coefficients

- Coefficients: [73, -121, 89, 146, -57]
- Functional verification: PASS
- Test vectors: 1,000
- Mismatches: 0
- Yosys SB_LUT4 count: 593
- nextpnr logic cells (ICESTORM_LC): 674 / 5280
- DSP blocks (ICESTORM_DSP): 0 / 8
- BRAM blocks (ICESTORM_RAM): 0 / 30
- Maximum frequency, last reported result: 20.20 MHz
- Verilator simulation log: results/generalization/case_B/baseline/verilator_simulation.log
- Yosys log: results/generalization/case_B/baseline/yosys.log
- nextpnr log: results/generalization/case_B/baseline/nextpnr.log

### Case C — Partially Symmetric Coefficients

- Coefficients: [51, -137, 93, 137, -51]
- Functional verification: PASS
- Test vectors: 1,000
- Mismatches: 0
- Yosys SB_LUT4 count: 729
- nextpnr logic cells (ICESTORM_LC): 785 / 5280
- DSP blocks (ICESTORM_DSP): 0 / 8
- BRAM blocks (ICESTORM_RAM): 0 / 30
- Maximum frequency, last reported result: 25.23 MHz
- Verilator simulation log: results/generalization/case_C/baseline/verilator_simulation.log
- Yosys log: results/generalization/case_C/baseline/yosys.log
- nextpnr log: results/generalization/case_C/baseline/nextpnr.log

### Baseline Observations

Both generalization cases passed the 1,000-sample functional test
with zero mismatches. Neither design used dedicated DSP blocks or
block RAM on the iCE40 UP5K.

Case C used 785 logic cells compared with 674 for Case B, while its
last reported maximum frequency was 25.23 MHz compared with
20.20 MHz for Case B. These results describe the synthesized and
placed-and-routed implementations; they do not establish that
coefficient symmetry alone caused the differences.

The baseline RTL uses five explicit multiplications. The absence of
dedicated DSP usage motivates the synthesis and critical-path
investigation planned for Phase 4.

## Phase 3 — AI Optimization Results

### Case B — General Coefficients

- Coefficients: [73, -121, 89, 146, -57]
- Verification: PASS; 1,000 samples; 0 mismatches
- Baseline logic cells: 674
- Optimized logic cells: 376
- Logic-cell reduction: 44.21%
- Baseline SB_LUT4 count: 593
- Optimized SB_LUT4 count: 319
- Baseline DSP blocks: 0
- Optimized DSP blocks: 0
- Baseline BRAM blocks: 0
- Optimized BRAM blocks: 0
- Baseline maximum frequency: 20.20 MHz
- Optimized maximum frequency: 31.22 MHz
- Frequency improvement: 54.55%
- Compilation, synthesis, and place-and-route: successful
- Optimized RTL: rtl/generalization/optimized/ffe5tap_caseB_optimized.sv

### Case C — Partially Symmetric Coefficients

- Coefficients: [51, -137, 93, 137, -51]
- Verification: PASS; 1,000 samples; 0 mismatches
- Baseline logic cells: 785
- Optimized logic cells: 247
- Logic-cell reduction: 68.54%
- Baseline SB_LUT4 count: 729
- Optimized SB_LUT4 count: 196
- Baseline DSP blocks: 0
- Optimized DSP blocks: 0
- Baseline BRAM blocks: 0
- Optimized BRAM blocks: 0
- Baseline maximum frequency: 25.23 MHz
- Optimized maximum frequency: 32.60 MHz
- Frequency improvement: 29.21%
- Compilation, synthesis, and place-and-route: successful
- Optimized RTL: rtl/generalization/optimized/ffe5tap_caseC_optimized.sv

### Phase 3 Summary

Both AI-generated implementations passed the 1,000-sample
functional verification with zero mismatches.

Case B reduced placed-and-routed logic-cell utilization by 44.21%
and increased the last-reported maximum frequency by 54.55%.

Case C reduced placed-and-routed logic-cell utilization by 68.54%
and increased the last-reported maximum frequency by 29.21%.

Neither optimized design used dedicated DSP blocks or block RAM.
These results demonstrate that the AI-generated implementations
improved the measured resource utilization and timing for both
additional coefficient sets. The results do not establish that
the same improvements will occur for every possible coefficient set.

