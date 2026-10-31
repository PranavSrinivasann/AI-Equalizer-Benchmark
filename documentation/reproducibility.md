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

## One-command rebuild

`scripts/rebuild_all.py` reruns verification, synthesis and place-and-route
for every design (baseline, optimized and hand-optimized for Cases A-C):

```bash
python3 scripts/rebuild_all.py --seeds 10
```

It records tool versions, saves per-design logs under `results/rebuild/`,
and writes `results/rebuild/summary.csv` and `results/rebuild/fmax_seeds.csv`.
See `documentation/week1_walkthrough.md` for what each check covers.

## Channel experiments

`python/channel/hardware_ber.py` runs the floating-point, fixed-point and
RTL FFEs on the same PAM4 channel samples and writes `results/channel/`.
See `documentation/channel_connection.md` and
`documentation/week2_walkthrough.md`.

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

- Case A functional verification was not established by the artifacts identified during the Phase 4 audit; it is now re-established by the saved logs in `results/rebuild/A_*/`.
- Exact AI model/version, prompt count, and manual RTL change history are not fully recorded.
- Timing-path excerpts do not necessarily identify the overall critical path.

These limitations are intentionally documented instead of being filled with assumptions.

## 802.3dj channel study (Phase 3)

```bash
./scripts/fetch_8023dj_channels.sh      # channel files into data/8023dj/ (git-ignored)
python3 python/dj/run_phase3.py         # results/dj/, rtl/dj/
```

Needs scikit-rf, SciPy, matplotlib and Verilator. See
`documentation/phase3_802_3dj.md`.

## Agent loop (Phase 5)

```bash
export V=/usr/local/lib/python3.13/site-packages/verilator   # wherever Verilator lives
export PATH=$V/bin:$PATH VERILATOR_ROOT=$V
python3 python/agent/loop.py setup          # evaluate the baseline and the hand CSD reference
python3 python/agent/loop.py prompt N       # writes results/agent/round_NN/prompt.md
# ... the model's reply is saved as results/agent/round_NN/response.md ...
python3 python/agent/loop.py evaluate N     # gates G1-G3, synthesis, place and route; updates state.json
python3 python/agent/loop.py control NAME   # evaluate a single-shot control sample
python3 python/agent/report_agent.py        # results/agent/summary.csv and score_by_round.png
```

Every prompt, reply, report and synthesis log is kept under `results/agent/`.
The model's replies cannot be regenerated bit for bit; the saved replies are the record.
See `documentation/phase5_agent_loop.md`.
