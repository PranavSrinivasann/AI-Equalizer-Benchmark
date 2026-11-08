# Phase 6 Walkthrough: The Final Report

## What was added

| File | What it does |
|---|---|
| `documentation/final_report.md` | One document with every result and finding, Weeks 1 and 2 through Phase 5 |
| `documentation/phase6_walkthrough.md` | This page |
| `README.md` | New section at the top pointing to the final report and the phase write-ups |

No code or results changed in this phase.

## How the report is organized

1. Summary: five findings in plain words.
2. Setup: link, targets, design, tools.
3. Weeks 1 and 2: AI-optimized hardware and its correctness.
4. Phase 3: the three public channels and whether 5 taps passes.
5. Phase 4: taps, bits and the DFE.
6. Phase 5: the agent loop.
7. Limits, next steps, and where every file is.

## What to remember

- 5 taps passes ~20 and ~30 dB, and fails ~40 dB.
- ~40 dB needs a DFE: 24 feed-forward plus 1 feedback tap passes in the model.
- AI-optimized hardware is far smaller than hand shift-add hardware, but needs a verification gate.
- The loop beat single replies on one run, mostly through approximation within a tolerance I chose.
