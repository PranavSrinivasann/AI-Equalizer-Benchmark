# Phase 5 Walkthrough: The Agent Loop

## What was added

| File | What it does |
|---|---|
| `python/agent/evaluate.py` | Checks one RTL file: build, directed tests, link BER, synthesis, place and route, score |
| `python/agent/loop.py` | Writes each round's prompt, evaluates the reply, keeps the history in `results/agent/state.json` |
| `python/agent/report_agent.py` | Builds `results/agent/summary.csv` and `score_by_round.png` |
| `prompts/agent/loop_task.md` | The task text every round starts with |
| `documentation/phase5_agent_loop.md` | Full write-up |

## The idea in four lines

1. A model proposes a new design. 2. A script checks it and measures it. 3. The model sees the results and
tries again. 4. After 8 rounds, keep the best design that passed every check.

## Why there are three gates

- **G1** catches code that does not build.
- **G2** (directed tests) catches corner cases, like a sum that overflows only for extreme inputs. Round 1 failed here while the link test passed.
- **G3** (link BER) checks that the equalizer still equalizes.

A design only gets a score if it passes all three.

## How to read the table

Score 1.0 is the hand-written design. Lower is better. 0.325 means about one third of the hand design's
combined area-and-speed cost. Look at the "Max error" column too: it shows how much the design departs from the
exact function. The last rounds spend most of the allowed 8 LSB.

## What to remember

- The loop reached 274 cells at 54.1 MHz, against 571 cells at 24.8 MHz for the hand design.
- Single replies reached 0.421 to 0.864, or failed a gate. The loop did better, but it is one run.
- Most of the gain came from allowed approximation (narrower datapath, simpler constants), not from a better exact design.
- The 8 LSB tolerance was my choice and it limited the result.

## Run it

See the Phase 5 section of `documentation/reproducibility.md`.
