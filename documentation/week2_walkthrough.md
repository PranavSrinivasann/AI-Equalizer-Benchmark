# Week 2 Walkthrough: Connecting the Hardware to the Channel

This covers the professor's third point: run the floating-point FFE, the
fixed-point reference and the RTL on the same received samples, then test
coefficient sets derived from channels. The full write-up is
`documentation/channel_connection.md`.

## What was added

| File | What it does |
|---|---|
| `python/channel/link.py` | PAM4 symbols, channels, noise, decisions, bit errors (same conventions as the notebooks) |
| `python/channel/equalizer.py` | Designs the 5-tap MMSE equalizer for a channel, rounds it to Q1.10, and runs the float and bit-exact fixed-point FFE |
| `python/channel/rtl_sim.py` | Runs any RTL design on a sample stream in Verilator and returns its outputs |
| `python/channel/hardware_ber.py` | The main experiment: same samples through float, fixed and RTL, BER at each SNR |
| `python/channel/plot_ber.py` | Draws `results/channel/ber_vs_snr.png` |
| `python/rtl_gen/ffe_rtl.py` | Writes baseline and hand-CSD RTL for any coefficient set (reproduces the existing files exactly) |
| `python/channel/build_prompts.py` | Builds the optimization prompts in exactly the Case B/C format |
| `rtl/channel/` | Baseline, hand and optimized RTL for the four channel-derived sets |

## The ideas you need

### 1. Why symbol-spaced

The hardware FFE takes one sample per symbol, so the channel has to be
applied at that rate too. The CNN and LSTM notebooks use 2 samples per
symbol, so their BER numbers aren't directly comparable with these.

### 2. MMSE equalizer, and the bias fix

MMSE picks the 5 taps that minimize the average squared error between the
equalizer output and the sent symbol. The catch is that the MMSE output is
slightly shrunk toward zero. With fixed decision thresholds at 0 and ±2,
that shrinkage causes extra errors. So the taps are rescaled until the
wanted symbol comes out at exactly its true size ("unbiased MMSE").

### 3. Why the notebook channel needs a gain factor

The best taps for that channel include 2.34, but Q1.10 only reaches just
under 2. So the equalizer is designed to output 0.562 × the symbol, and the
decision thresholds are scaled by 0.562 too. This is the same thing a real
receiver's gain control would do.

### 4. How the three-way comparison works

At each noise level, one batch of 200,000 symbols with one noise draw goes
through all three versions. Because the inputs are identical, any
difference in errors comes from the arithmetic alone.

- Float vs. fixed tells you what 12-bit rounding costs. Here it's nothing
  measurable: the error counts differ by a few, in both directions.
- Fixed vs. RTL tells you whether the hardware is correct. It matched on
  every single cycle, 2.2 million per design per channel.

### 5. Why the new coefficient sets have no pairs

Cases A and C had pairs like 51 and −51 because their channel was
symmetric. Real links are lopsided (echoes trail the main pulse), so their
equalizers aren't paired. That removes the pre-adder trick the AI used in
Cases A and C, which makes these sets a tougher test.

### 6. Transposed form (what the AI did this time)

A normal FIR stores the last 4 inputs and multiplies each by its
coefficient. Transposed form flips it: it multiplies the *current* input by
all 5 coefficients and stores running partial sums instead.

Two things follow:
- All 5 multiplies use the same input, so they can share sub-results
  (e.g. build 33x once and reuse it for 41x, 45x and 1097x).
- On this FPGA, a flip-flop fed by an adder shares its logic cell for free,
  while a plain delay flip-flop wastes a whole cell.

It's a textbook technique, but none of the earlier designs used it.

## Results at a glance

| Channel | Baseline LC | Hand LC | AI LC | Fmax median, MHz (base / hand / AI) |
|---|---|---|---|---|
| short_reach | 778 | 498 | 206 | 18.2 / 23.8 / 55.5 |
| pre_post | 682 | 493 | 216 | 18.9 / 24.7 / 66.5 |
| long_tail | 979 | 614 | 249 | 17.2 / 23.5 / 64.5 |
| notebook | 841 | 599 | 223 (fails tests) | 16.8 / 23.7 / 38.1 |

## Questions you may get, and answers

**"Does the RTL match the models on real signals?"**
Yes, bit for bit, on 2.2 million cycles per design per channel.

**"How much BER does fixed point cost?"**
Nothing measurable down to about 10⁻⁵. Float and fixed error counts differ
by a few errors either way, which is statistical noise.

**"Why is the BER so high on the notebook channel?"**
At one sample per symbol its echoes (0.6 total) outweigh its main tap (0.5),
and 5 linear taps can't undo that. That fits the notebooks, where the DFE
and neural equalizers beat the linear FFE. In the notebooks the same taps
are applied at 10 samples per symbol, which is much milder.

**"Did the AI still beat hand design without paired coefficients?"**
Yes, by more than before: 2.3–2.5× fewer cells than hand CSD and 2.3–2.7×
the clock speed, on the three correct designs.

**"Was anything wrong?"**
One of four AI designs (notebook) had a bug: its overflow check looks at the
wrong bits, so almost every output gets forced to the maximum. Its own
explanation claimed it was exact. The directed tests caught it straight
away. We kept it as a recorded failure instead of fixing it, so the
protocol stays one attempt, no edits.

**"Is the hand comparison fair?"**
Mostly. The hand version is direct-form CSD, which is what week 1 used. A
hand-written transposed design would close some of the gap; that's a good
next test.

**"Which model was used, and when?"**
Claude (claude-opus-5-5), on 2026-10-25, one fresh instance per set, one
attempt each, recorded in `documentation/channel_connection.md`.

## Rerunning it

```bash
python3 python/channel/hardware_ber.py --symbols 200000    # ~6 minutes
python3 python/channel/plot_ber.py
python3 python/channel/hardware_ber.py --channels short_reach --symbols 20000   # quick
```
