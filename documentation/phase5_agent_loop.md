# Phase 5: Agent Loop for PAM4 Equalizer RTL

## Question

Can a model that gets verification, BER, synthesis and timing feedback, and tries again,
find a smaller and faster 5-tap PAM4 equalizer than a model that answers once?

## Setup

- Channel: 802.3dj 30 dB case from Phase 3, 5 taps, coefficients `[163, -417, 782, -1268, 1536]` in Q1.10.
- Target: BER and symbol-error rate at most 2e-4 (the primary target). The 1e-6 stretch target was not used.
- Device flow: iCE40 UP5K, Yosys `synth_ice40`, `nextpnr-ice40`, 3 placement seeds, median Fmax.
- Model: each reply came from a fresh Claude instance, configured as `claude-sonnet-5-5`, with no
  tools and no files. It saw only the prompt, which was preceded by one sentence telling it to answer
  directly. The serving model may differ from the configured one.

### The checks every design must pass

| Gate | Check |
|---|---|
| G1 | Builds in Verilator and synthesizes in Yosys |
| G2 | Directed tests (power-up and mid-stream reset, constant and alternating extremes, worst-case accumulation, PAM4 levels, 5000 random full-range samples). Every cycle with `rst_n` low must output exactly 0, and every output must be within 8 LSB of the exact reference |
| G3 | 2,000,010 PAM4 symbols through the 30 dB channel and the RTL. BER and symbol-error rate must both be at most 2e-4 |

Synthesis only runs after G1 to G3 pass.

Score, lower is better, valid designs only:

    score = (logic cells / 571) * sqrt(24.8 / Fmax in MHz)

A score of 1.000 is the hand-written canonical-signed-digit (CSD) design from Phase 3 (571 logic cells, 24.8 MHz).

### The loop

Eight rounds. Each round's prompt holds the fixed task text (`prompts/agent/loop_task.md`), a table of every
earlier attempt with the model's own change summary, the full gate report and RTL of the best valid design
so far, and the full report and RTL of the most recent attempt when it was not the best. Round 1 starts from
the generic-multiplier baseline. The model is told the gates, the tolerance, the score formula, the RMS of
typical inputs and the slicer thresholds, and that an approximation is allowed if it passes.

### What was compared

| Arm | What it is |
|---|---|
| Baseline | Generic multipliers, direct form (Phase 3 baseline) |
| Hand CSD | Hand-written shift-add design (Phase 3) |
| One-shot, exact | One reply to the Week 1 and 2 prompt: "preserve the exact function" |
| Controls A and B | Two more single replies to the round-1 loop prompt (same prompt as round 1, no feedback) |
| Loop rounds 1 to 8 | The loop |

## Results

| Attempt | Valid | Logic cells | Fmax MHz | Score | Max error vs exact (G2) | Bit errors in 4 M bits |
|---|---|---|---|---|---|---|
| Baseline | yes | 867 | 17.8 | 1.794 | 0 LSB | 33 |
| Hand CSD | yes | 571 | 24.8 | 1.000 | 0 LSB | 33 |
| One-shot, exact | yes | 329 | 46.5 | 0.421 | 0 LSB | 33 |
| Control A | yes | 350 | 47.1 | 0.445 | 0 LSB | 33 |
| Control B | yes | 517 | 27.3 | 0.864 | 6 LSB | 36 |
| Loop round 1 | **no, G2** | | | | 4095 LSB | 33 |
| Loop round 2 | yes | 487 | 39.8 | 0.674 | 0 LSB | 33 |
| Loop round 3 | yes | 388 | 44.2 | 0.510 | 1 LSB | 34 |
| Loop round 4 | yes | 347 | 47.7 | 0.438 | 1 LSB | 34 |
| Loop round 5 | yes | 323 | 45.4 | 0.419 | 2 LSB | 34 |
| Loop round 6 | yes | 295 | 46.5 | 0.378 | 4 LSB | 34 |
| Loop round 7 | yes | 283 | 56.7 | 0.328 | 5 LSB | 33 |
| **Loop round 8** | yes | **274** | **54.1** | **0.325** | 7 LSB | 35 |

Figure: `results/agent/score_by_round.png`. Table as data: `results/agent/summary.csv`.
Every prompt, reply, gate report and synthesis log is in `results/agent/`; the RTL is in `rtl/agent/`.

Best result, round 8: 274 logic cells against 867 for the baseline (3.2 times fewer) and 571 for the
hand design (2.1 times fewer), at 54.1 MHz against 17.8 and 24.8 MHz. It fits the UP5K with a large margin.

## What the loop did

1. **Round 1 failed G2 and passed G3.** It switched to transposed form with CSD constants and used 24-bit
   partial sums. The worst-case sum needs 25 bits, so extreme inputs wrapped around (37 failing cycles,
   error up to 4095 LSB). The BER test did not see it: the link run gave 8.25e-6, the same as the exact design,
   because real PAM4 inputs never reach those extremes. The directed gate caught it. Round 2 fixed the width.
2. **Rounds 2 to 6** (0.674 to 0.378) mostly narrowed the datapath: 25, then 19, 17, 16 and 15 bits, by
   scaling every term down by a power of two and dropping low bits. These are approximations. Max error
   against the exact reference grew from 0 to 4 LSB over these rounds.
3. **Rounds 7 and 8** (0.328, 0.325) dropped one CSD term each from the constants for c0 and c1, turning 163
   into 164 and -417 into -416. Max error rose to 5 and then 7 LSB, one LSB under the gate.
4. The model's logic-cell predictions were close (for example 388 predicted 370 to 390, 347 predicted about
   350, 274 predicted about 270). Its Fmax predictions were weaker: in round 5 it predicted a small rise and
   Fmax fell from 47.7 to 45.4 MHz; in round 7 it predicted no change and Fmax rose from 46.5 to 56.7 MHz.

## How to read the results

- **The loop beat the single replies, with a small sample.** The three valid single replies scored 0.421
  (exact prompt), 0.445 and 0.864; the fourth, round 1, failed a gate. The loop's best is 0.325, which is
  23 percent lower than the best single reply. This is one loop run and four single replies from one model,
  so it shows the direction, not a measured size.
- **Most of the gain over single replies is from approximation, not a better exact design.** The best exact
  designs are the one-shot (329 cells, 0.421) and control A (350 cells, 0.445), both better than the loop's
  exact design in round 2 (0.674). The loop passed the one-shot at round 5 and kept going because it was
  allowed to trade accuracy for area. Told to keep the function exact, it would have had to find the shared
  3x/5x/7x structure that the one-shot and control A found on their own.
- **The result depends on the 8 LSB tolerance, which I chose.** 8 LSB is 8/256, about 0.03 in real units,
  against decision levels hundreds of codes apart. Every design, including the 7 LSB one, shows 33 to 36 bit
  errors in 4 M bits (8.25e-6 to 9.0e-6). With that few errors the run-to-run noise is about 17 percent, so
  these differences are not meaningful, but the limit of 2e-4 would be 800 errors, so there is a lot of room.
  The loop stopped because it ran out of the 8 LSB tolerance, not because the link needed the accuracy. A looser G2 would
  likely have allowed a smaller design. That is a choice to discuss, not a property of the channel.
- **Rounds 7 and 8 are close to a tie.** Their Fmax seed ranges overlap (53.3 to 56.7 MHz and 54.1 to 54.9 MHz)
  and the score differs by 0.003. Round 8 has fewer cells; round 7 has more margin on error (5 LSB, not 7).
- **Fmax values are from nextpnr place and route at a 12 MHz target, median of 3 seeds.** They are not a timing sign-off.

## Limits of this phase

- One channel (30 dB), one loop run, one model, one device family. The 20 dB and 40 dB cases were not run.
- Rounds 3 to 8 floor the low bits, which leaves a small systematic bias. It had no visible effect on this
  channel; a channel with less margin could be more sensitive.
- The model was told the slicer thresholds and the typical input level, and the score formula. That helps it design
  approximations and is part of what is being measured.
- Verification is by simulation and synthesis only. No design has been run on hardware.

## Files

| Path | What it is |
|---|---|
| `prompts/agent/loop_task.md` | Fixed task text used in every round |
| `python/agent/evaluate.py` | Gates G1 to G3, synthesis, place and route, score |
| `python/agent/loop.py` | Builds prompts, evaluates replies, keeps the history |
| `python/agent/report_agent.py` | Summary table and figure |
| `results/agent/round_NN/` | Prompt, reply, report and logs for each round |
| `results/agent/oneshot/`, `control_a/`, `control_b/` | The single-reply arms |
| `results/agent/arms/` | Baseline and hand CSD reference runs |
| `rtl/agent/` | The RTL from every attempt |
| `test_vectors/directed/case_dj_loss30.txt` | Directed test vectors for G2 |

The RTL files in `rtl/agent/` were generated by Claude and are unedited; each carries a header saying so.
