# Phase 6 — Final Validation and Release

## Scope

This phase checks repository structure, the experiment CSV schema, and Git state. It does not independently rerun simulations or synthesis.

## Design

The benchmark uses a five-tap PAM4 feed-forward equalizer:
- Signed 12-bit Q3.8 input and output.
- Signed 12-bit Q1.10 coefficients.
- Arithmetic right shift by 10 and signed saturation.
- Synchronous active-low reset.
- One-cycle latency and one sample per cycle.

## Recorded Phase 4 implementation results

| Case | Implementation | nextpnr logic cells | Yosys LUT4 | Max frequency |
|---|---|---:|---:|---:|
| A | Baseline | 629 | 558 | 20.42 MHz |
| A | Optimized | 408 | 350 | 20.75 MHz |
| B | Baseline | 674 | 593 | 20.20 MHz |
| B | Optimized | 376 | 319 | 31.22 MHz |
| C | Baseline | 785 | 729 | 25.23 MHz |
| C | Optimized | 247 | 196 | 32.60 MHz |

All six recorded nextpnr runs met the 12 MHz target. The recorded implementations used zero DSP blocks and zero BRAM blocks. nextpnr logic-cell usage and Yosys LUT4 counts are different metrics.

## Functional verification status

- Cases B and C: existing records report 1,000 samples and zero mismatches for baseline and optimized implementations.
- Case A: functional equivalence is not verified by the currently identified evidence.
- Successful synthesis and timing analysis do not prove functional correctness.

## Data reconciliation required

The existing `results/generalization/results.csv` has a different schema from the earlier audit's expected schema. Its rows also conflict with the final Phase 4 table in places. In particular, the Case A `PASS` field should not be interpreted as functional equivalence without a corresponding test artifact. The CSV has deliberately not been silently rewritten.

Before making quantitative claims, reconcile each CSV row against its original synthesis and simulation logs.

## Release checklist

- [ ] Structural audit passes.
- [ ] Sensitive files are excluded.
- [ ] CSV entries reconciled against source logs.
- [ ] Case A functional verification either completed or clearly marked unverified.
- [ ] Changes committed and pushed to GitHub.

## Limitations

This report documents the currently available evidence. It does not claim new simulation runs, independent reproduction, or complete functional verification.
