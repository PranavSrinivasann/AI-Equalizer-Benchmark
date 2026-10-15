# Phase 4: Synthesis and Critical-Path Investigation

## Objective

Compare baseline and AI-assisted optimized five-tap PAM4 FFE implementations across three coefficient sets using Yosys synthesis and nextpnr-ice40 implementation results.

## Configuration

- Signed 12-bit Q3.8 input/output
- Signed 12-bit Q1.10 coefficients
- Arithmetic right shift by 10 and signed 12-bit saturation
- Synchronous active-low reset
- One-cycle latency and target throughput of one sample per cycle
- iCE40 UP5K target
- 12 MHz timing target

Coefficient sets:

- A: `[51, -154, 1024, 154, -51]`
- B: `[73, -121, 89, 146, -57]`
- C: `[51, -137, 93, 137, -51]`

## Results

| Case | Implementation | Logic cells | LUT4s | DSPs | BRAMs | Max frequency |
|---|---|---:|---:|---:|---:|---:|
| A | Baseline | 629 | 558 | 0 | 0 | 20.42 MHz |
| A | Optimized | 408 | 350 | 0 | 0 | 20.75 MHz |
| B | Baseline | 674 | 593 | 0 | 0 | 20.20 MHz |
| B | Optimized | 376 | 319 | 0 | 0 | 31.22 MHz |
| C | Baseline | 785 | 729 | 0 | 0 | 25.23 MHz |
| C | Optimized | 247 | 196 | 0 | 0 | 32.60 MHz |

| Case | Logic-cell reduction | Frequency improvement |
|---|---:|---:|
| A | 35.1% | 1.6% |
| B | 44.2% | 54.6% |
| C | 68.5% | 29.2% |

All six recorded implementation runs passed the 12 MHz timing target. The logs reported zero dedicated DSP blocks and zero block RAM blocks used.

The largest logic-cell reduction was observed in Case C. The largest relative maximum-frequency improvement was observed in Case B. These results are specific to the recorded tools, target, constraints, and runs.

## Timing-path evidence

The available Case A excerpts report a path ending at `y_out[0]` with 1.39 ns logic delay and 6.30 ns routing delay for the baseline, and 1.39 ns logic delay and 6.95 ns routing delay for the optimized implementation. These excerpts alone do not establish that the paths are the overall critical paths.

## Verification and metadata limitations

Cases B and C have saved Verilator compilation and simulation logs. Existing experiment records report 1,000 samples and zero mismatches for their baseline and optimized implementations.

Case A functional equivalence was not established by the artifacts identified during the audit. Successful synthesis and implementation do not prove functional equivalence.

The AI experiment log still has metadata fields for model/version, prompt count, and manual RTL changes. Any value that cannot be recovered from existing records must be marked `Not recorded`.

## Conclusion

The Phase 4 synthesis, resource-utilization, and timing investigation is documented. The measured logic-cell reductions range from 35.1% to 68.5%, and the measured maximum-frequency improvements range from 1.6% to 54.6%. All six recorded implementation runs passed the 12 MHz target.

The Case A verification gap and incomplete AI metadata remain explicit limitations.
