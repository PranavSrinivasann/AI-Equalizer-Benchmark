# AI-Assisted PAM4 Equalizer Hardware Optimization

## Overview

This project investigates hardware optimization of a five-tap PAM4 feed-forward equalizer (FFE). Baseline and AI-assisted optimized RTL implementations are compared across three coefficient sets using synthesis and FPGA implementation tools.

The main evaluation metrics are logic-cell utilization, LUT4 count, maximum reported clock frequency, and use of dedicated FPGA resources. Functional verification results are documented separately from synthesis results.

## Design specification

- Architecture: five-tap feed-forward equalizer
- Input/output: signed 12-bit Q3.8
- Coefficients: signed 12-bit Q1.10
- Arithmetic scaling: arithmetic right shift by 10
- Output: signed 12-bit saturation
- Reset: synchronous active-low
- Target FPGA: iCE40 UP5K
- Timing target: 12 MHz
- Tools: Verilator, Yosys, and nextpnr-ice40

### Coefficient sets

| Case | Coefficients |
|---|---|
| A | `[51, -154, 1024, 154, -51]` |
| B | `[73, -121, 89, 146, -57]` |
| C | `[51, -137, 93, 137, -51]` |

## Hardware results

The following table consolidates the recorded synthesis and implementation results. Logic cells, DSP/BRAM utilization, and frequency are from nextpnr logs. LUT4 counts are from Yosys statistics.

| Case | Implementation | Logic cells | LUT4s | DSPs | BRAMs | Max frequency |
|---|---|---:|---:|---:|---:|---:|
| A | Baseline | 629 | 558 | 0 | 0 | 20.42 MHz |
| A | Optimized | 408 | 350 | 0 | 0 | 20.75 MHz |
| B | Baseline | 674 | 593 | 0 | 0 | 20.20 MHz |
| B | Optimized | 376 | 319 | 0 | 0 | 31.22 MHz |
| C | Baseline | 785 | 729 | 0 | 0 | 25.23 MHz |
| C | Optimized | 247 | 196 | 0 | 0 | 32.60 MHz |

### Optimization impact

| Case | Logic-cell reduction | Frequency improvement |
|---|---:|---:|
| A | 35.1% | 1.6% |
| B | 44.2% | 54.6% |
| C | 68.5% | 29.2% |

All six recorded implementation runs passed the 12 MHz timing target. No dedicated DSP blocks or block RAM blocks were used in these runs.

Case C had the largest logic-cell reduction. Case B had the largest relative improvement in maximum reported frequency. Case A reduced logic-cell utilization, but its frequency improvement was comparatively small.

These measurements apply to the recorded toolchain, target, constraints, and runs. They do not by themselves establish improved end-to-end optical-link performance.

## Repository structure

- `rtl/`: Case A baseline and optimized RTL.
- `rtl/generalization/`: Case B and C implementations.
- `testbench/generalization/`: Generalization testbench.
- `python/`: Coefficient checks, vector generation, and experiment scripts.
- `prompts/`: AI optimization prompts and experiment log.
- `results/generalization/`: Saved vectors, simulation logs, synthesis logs, implementation logs, and results CSV.
- `results/phase4/`: Timing investigation artifacts and summary.
- `documentation/`: Experimental specification and reproducibility notes.

## Reproducing the work

Read `documentation/experimental_spec.md` and `documentation/reproducibility.md` first.

Check the required tools and versions:

```bash
verilator --version
yosys -V
nextpnr-ice40 --version
python3 --version
```

Saved experiment logs are retained under `results/generalization/`. Review the existing scripts before rerunning them, because a rerun may overwrite generated RTL, vectors, or logs. Record tool versions, commands, and any changes to constraints when repeating experiments.

## Verification status and limitations

Cases B and C have saved Verilator compile and simulation logs. Existing experiment records report 1,000 samples with zero mismatches for their baseline and optimized implementations.

For Case A, synthesis and implementation logs are available, but a corresponding Verilator functional-verification artifact was not identified during the documentation audit. Case A functional equivalence is therefore marked **not verified from the currently identified evidence**. Successful synthesis is not a substitute for functional verification.

The AI experiment log contains fields for the exact model/version, prompt iteration count, and manual RTL changes. Values not recoverable from the records are marked as not recorded rather than inferred.

Timing-path excerpts are retained as evidence, but individual paths are not described as the overall critical path unless the full timing report establishes that conclusion.

## License and citation

No license or publication citation is asserted by this repository. Add a license only after choosing the terms under which the project should be distributed. Cite relevant external tools, datasets, and research when preparing a publication or public release.
