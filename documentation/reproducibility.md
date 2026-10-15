# Reproducibility Guide

## Environment

The experiments use:

- Verilator for RTL compilation and simulation
- Yosys for synthesis and technology mapping
- nextpnr-ice40 for FPGA placement, routing, and timing analysis
- Python for coefficient checks and experiment-data generation

Record the actual installed versions before rerunning experiments:

```bash
verilator --version
yosys -V
nextpnr-ice40 --version
python3 --version
```

The historical result tables in this repository describe recorded runs. Different tool versions, constraints, seeds, or placement and routing choices may produce different results.

## Experiment specification

Read `documentation/experimental_spec.md` for the design configuration and fixed-point arithmetic requirements.

Coefficient definitions and related checks are in:

- `python/coefficient_sets.py`
- `python/check_coefficient_sets.py`

Generalization-related scripts and the testbench are in:

- `python/generalization/`
- `testbench/generalization/`

Inspect each script before execution to confirm its inputs, outputs, and whether it overwrites saved files. Preserve original results before running experiments again.

## Saved evidence

The main per-implementation evidence is stored under:

`results/generalization/case_{A,B,C}/{baseline,optimized}/`

Depending on the implementation, the directories contain Verilator logs, generated input and expected vectors, Yosys logs, and nextpnr logs.

The Phase 4 timing investigation artifacts are under `results/phase4/`.

## Recommended rerun procedure

1. Confirm the current Git state and make a backup of any results that must be preserved.
2. Record tool versions and the exact commands used.
3. Generate or select the appropriate test vectors.
4. Compile and simulate each RTL implementation against its reference outputs.
5. Record sample counts and mismatch counts from the actual simulation output.
6. Run Yosys synthesis and nextpnr implementation for the same target and timing constraint.
7. Capture logic-cell utilization, LUT4 count, DSP and BRAM utilization, and the final reported maximum frequency.
8. Preserve full logs and update `results/generalization/results.csv`.
9. Record the AI model/version, prompt count, and manual RTL modifications only when supported by actual records.

Do not infer functional correctness from successful synthesis. A result should be marked PASS only when the corresponding verification evidence supports it.

## Current evidence limitations

- Case A functional verification was not established by the artifacts identified during the Phase 4 audit.
- Exact AI model/version, prompt count, and manual RTL change history are not fully recorded.
- Timing-path excerpts do not necessarily identify the overall critical path.

These limitations are intentionally documented instead of being filled with assumptions.
