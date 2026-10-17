# Phase 6 — Final Validation and Release

## Design

Five-tap PAM4 feed-forward equalizer:
- Signed 12-bit Q3.8 input/output.
- Signed 12-bit Q1.10 coefficients.
- Arithmetic right shift by 10 and signed saturation.
- Synchronous active-low reset.
- One-cycle latency; one sample per cycle.

## Final synthesis and timing results

| Case | Implementation | nextpnr logic cells | Yosys LUT4 | DSP | BRAM | Max frequency |
|---|---|---:|---:|---:|---:|---:|
| A | Baseline | 629 | 558 | 0 | 0 | 20.42 MHz |
| A | Optimized | 408 | 350 | 0 | 0 | 20.75 MHz |
| B | Baseline | 674 | 593 | 0 | 0 | 20.20 MHz |
| B | Optimized | 376 | 319 | 0 | 0 | 31.22 MHz |
| C | Baseline | 785 | 729 | 0 | 0 | 25.23 MHz |
| C | Optimized | 247 | 196 | 0 | 0 | 32.60 MHz |

All six recorded nextpnr runs met the 12 MHz target. All recorded runs used zero DSP blocks and zero BRAM blocks. nextpnr logic-cell counts and Yosys LUT4 counts are separate metrics.

## Functional verification evidence

- Cases B and C: existing records report 1,000 samples and zero mismatches for both baseline and optimized implementations.
- Case A: the user reports running functional tests multiple times. The CSV records this as user-reported PASS, but the corresponding test artifact and exact sample/mismatch counts were not located in the currently identified repository evidence.

A user-reported test history is useful evidence, but it is not the same as a reproducible log included in the repository. No test results or sample counts have been invented.

## CSV cleanup

The generalization CSV has been normalized to a consistent schema with six rows, one per case and implementation. The final recorded synthesis metrics are separated into nextpnr logic cells and Yosys LUT4. Unknown manual RTL changes remain marked "Not recorded."

## Reproducibility and limitations

The release audit checks expected files, CSV structure, and Git whitespace. It does not rerun the simulations, synthesis, or place-and-route. Consult documentation/reproducibility.md for reproduction instructions.

## Release checklist

- [ ] Structural audit passes.
- [ ] Sensitive files reviewed before publishing.
- [ ] Changes committed and pushed.
- [ ] Functional test logs retained for future independent reproduction.
