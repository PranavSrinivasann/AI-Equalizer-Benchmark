# Phase 4 — Synthesis and Critical-Path Investigation

## 1. Objective

Investigate why the five-tap PAM4 feed-forward equalizer (FFE) maps
to zero dedicated DSP blocks on the iCE40 UP5K, and identify the
timing-critical path in the baseline and optimized implementations.

The investigation compares Cases A, B, and C, using the recorded
Yosys synthesis and nextpnr place-and-route reports.

## 2. Resource and Timing Results

| Case | Implementation | Logic cells | Yosys LUT4 | DSP | BRAM | Fmax (MHz) |
|---|---|---:|---:|---:|---:|---:|
| A | Baseline | 629 | Not recorded here | 0 | 0 | 19.96 |
| A | Optimized | 468 | Not recorded here | 0 | 0 | 20.75 |
| B | Baseline | 674 | 593 | 0 | 0 | 20.20 |
| B | Optimized | 376 | 319 | 0 | 0 | 31.22 |
| C | Baseline | 785 | 729 | 0 | 0 | 25.23 |
| C | Optimized | 247 | 196 | 0 | 0 | 32.60 |

Fmax values use the last reported frequency from each recorded run.

## 3. Why Are Zero DSP Blocks Used?

All six recorded implementations report zero dedicated DSP blocks
and zero block RAM blocks.

The resource count alone does not explain why DSP blocks were not
inferred. The synthesis logs must be examined to determine:

- Whether multiplication or multiply-accumulate cells exist before
  technology mapping.
- Whether any SB_MAC16 cells are inferred or instantiated.
- How the constant-coefficient arithmetic is mapped into iCE40 logic.
- Whether the synthesis flow, RTL structure, or target-specific
  mapping explains the absence of dedicated DSP blocks.

Evidence from Yosys:
[Complete this section using the synthesis logs.]

## 4. Critical-Path Analysis

For each available nextpnr report, record:

| Case | Implementation | Startpoint | Endpoint | Critical-path delay | Main delay contributors |
|---|---|---|---|---|---|
| A | Baseline | To be extracted | To be extracted | To be extracted | To be extracted |
| A | Optimized | To be extracted | To be extracted | To be extracted | To be extracted |
| B | Baseline | To be extracted | To be extracted | To be extracted | To be extracted |
| B | Optimized | To be extracted | To be extracted | To be extracted | To be extracted |
| C | Baseline | To be extracted | To be extracted | To be extracted | To be extracted |
| C | Optimized | To be extracted | To be extracted | To be extracted | To be extracted |

Distinguish combinational logic delay from routing delay and register
clock-to-Q/setup contributions wherever the reports provide them.
Do not infer a critical path from the RTL alone.

Evidence is collected in:
- investigation_summary.txt
- critical_path_details.txt

## 5. Interpretation and Limitations

The optimized B and C implementations reduce logic-cell usage by
44.2% and 68.5%, respectively, relative to their baselines.
Their recorded maximum frequencies improve by 54.6% and 29.2%.

These are implementation results for the tested coefficient sets,
tool flow, target device, and constraints. They do not establish that
the same improvements will occur for every coefficient set.

All six recorded designs use zero DSP blocks. The reason for this
must be supported by synthesis evidence before a definitive
architectural explanation is reported.

The critical-path explanation remains incomplete until the actual
nextpnr timing reports have been examined.

## 6. Reproducibility

Raw evidence:
- investigation_summary.txt
- critical_path_details.txt

The RTL, coefficient sets, simulation vectors, and individual
synthesis/place-and-route logs are retained in the project directories.
