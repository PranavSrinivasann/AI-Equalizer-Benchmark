# AI Equalizer Benchmark: Final Report

A 5-tap PAM4 feed-forward equalizer (FFE), tested on public 802.3dj 200G/lane channels and
optimized in hardware with and without an AI agent loop.

## 1. Summary

1. **A 5-tap, 12-bit FFE meets the primary target (BER and DER at most 2e-4) on the ~20 dB and ~30 dB
   channels and fails on the ~40 dB channel.** At ~20 dB it also meets the stretch target (BER at most 1e-6).
   At ~30 dB the BER is 7.2e-6, a factor of 7 above the stretch target.
2. **Fewer bits are enough on the easy channels.** An 8-bit-sample, 6-bit-coefficient-fraction FFE passes
   the primary target at ~20 and ~30 dB. With 8 taps at the same precision, ~30 dB also meets the stretch
   target. The cheapest passing designs use 281 logic cells (~20 dB) and 295 (~30 dB), against 507 and 571
   for the 12-bit 5-tap design.
3. **The ~40 dB channel needs a DFE.** An FFE alone needs 48 taps and still misses DER (BER 1.2e-4, DER 2.5e-4).
   A floating-point model with 24 feed-forward and 1 feedback tap passes the primary target (BER 2.3e-5,
   DER 4.6e-5), and 4 feedback taps pass the stretch target. No DFE hardware was built.
4. **AI-optimized hardware is much smaller than hand-written shift-add hardware.** Across seven coefficient
   sets, the six AI designs that passed verification used 24 to 59 percent fewer logic cells than hand
   canonical-signed-digit (CSD) designs. The seventh, on a channel-derived set, was functionally wrong
   and was caught only by simulation.
5. **An agent loop with verification, BER, synthesis and timing feedback beat single replies, on one run.**
   On the 30 dB channel the loop reached 274 logic cells at 54.1 MHz (score 0.325, hand CSD = 1.000),
   against 0.421 for the best single reply. Most of that advantage came from approximation inside an
   8 LSB tolerance that I chose, so it is a result about the setup as much as about the loop.

What is not shown: anything on real hardware, a DFE in hardware, the loop on the 20 and 40 dB channels, or any
statistics over repeated loop runs.

## 2. The question and the setup

**Link:** 212.5 Gb/s PAM4, 106.25 GBd, Nyquist frequency 53.125 GHz. Symbols are -3, -1, +1, +3 with Gray
mapping. Symbol error rate (DER) is about twice the bit error rate (BER).

**Targets:** primary, BER and DER at most 2e-4. Stretch, BER at most 1e-6. A run with no errors is reported as
a 95 percent upper bound (about 3 divided by the number of bits), not as a rate.

**Design under test:** 5 taps, samples in Q3.8 (12 bits), coefficients in Q1.10 (12 bits), arithmetic right
shift by 10, saturation to 12 bits, synchronous reset, one sample per cycle.

**Hardware flow:** Verilator (functional checks), Yosys (synthesis), nextpnr-ice40 (place and route) for the
iCE40 UP5K FPGA (5,280 logic cells). Logic cells are identical across placement seeds; Fmax is the median of
3 to 10 seeds. Fmax values come from an FPGA flow at a 12 MHz constraint. They compare designs against each
other and are not line-rate figures.

## 3. Weeks 1 and 2: can an AI optimize the hardware, and is it correct?

### Three fixed coefficient sets (Cases A, B, C)

Each set was implemented as a generic-multiplier baseline, a hand per-tap CSD design, and an AI-optimized design.
Ten placement seeds.

| Case | Baseline cells | Hand CSD cells | AI cells | AI vs hand | Fmax MHz (base / hand / AI) |
|---|---|---|---|---|---|
| A (51, -154, 1024, 154, -51) | 638 | 534 | 408 | -24% | 20.1 / 24.4 / 21.3 |
| B (73, -121, 89, 146, -57) | 664 | 478 | 236 | -51% | 20.3 / 27.8 / 35.2 |
| C (51, -137, 93, 137, -51) | 817 | 527 | 247 | -53% | 26.6 / 28.0 / 32.0 |

Plain CSD captures about half of the saving. The other half comes from sharing work between taps: pre-adders on
antisymmetric pairs, common factors (73 in B, 3 in C), and adders that skip bits that cannot carry. In Case A
the hand design is faster (24.4 against 21.3 MHz) although larger.

### Coefficient sets derived from channels

The FFE was connected to a PAM4 link model: float FFE, bit-exact fixed-point model, and RTL on the same samples.

- **Hardware is correct.** Every correct design matched the fixed-point model on all 2,200,022 cycles per
  design per channel, with zero mismatches.
- **12-bit fixed point costs no measurable BER.** Float and fixed error counts differ by a few tens at most, in
  both directions. Below about 1e-5 these runs cannot resolve a difference.
- **Four channels, optimized vs hand CSD:** 2.3 to 2.5 times smaller and 2.3 to 2.7 times faster on the three
  correct designs (for example 206 cells at 55.5 MHz against 498 cells at 23.8 MHz for `short_reach`).
- **One of four AI designs was wrong** (`notebook`: a bit-range error). Only simulation found it. Every
  automated flow therefore needs a verification gate, which is what Phase 5 builds.
- A harder, symbol-rate version of the notebook channel is not equalizable by a 5-tap linear FFE (about 9
  percent of bits wrong at 14 dB SNR), consistent with the DFE and neural equalizers doing better there.

Caveat: the hand reference is direct-form CSD. A hand transposed-form CSD design would narrow the gap and was not built.

## 4. Phase 3: the public 802.3dj channels

| Level | Source | Loss at 53.125 GHz | With package and terminations |
|---|---|---|---|
| ~20 dB | KR backplane, 100 mm | 20.8 dB | 20.6 dB |
| ~30 dB | KR backplane, 1200 mm | 30.6 dB | 30.4 dB |
| ~40 dB | OSFP cabled channel, 27 dB cable | 35.4 dB | 40.7 dB |

**The ~40 dB channel is not a single published file.** It is the highest-loss public channel (35.4 dB) with a
simplified package model added at both ends, which brings it to 40.7 dB. The ~20 and ~30 dB channels are used as published.

Signal chain: source, Tx package, channel, Rx package, 92.5 ohm termination, 4th-order Bessel-Thomson filter,
CTLE, sampler. Noise: receiver noise (5e-9 V²/GHz), transmitter noise (SNR 33 dB), and every crosstalk file
as an independent aggressor. CTLE gain and sampling phase were tuned per channel for this equalizer.

Taps (Q1.10, c0 is the newest sample):

| Level | Taps | Decision delay |
|---|---|---|
| ~20 dB | 80, -216, 466, -938, 1536 | 14 |
| ~30 dB | 163, -417, 782, -1268, 1536 | 15 |
| ~40 dB | -290, 829, -1453, 1536, -305 | 13 |

Results, bit-exact fixed point:

| Level | Symbols | BER | DER | Primary (2e-4) | Stretch (1e-6) |
|---|---|---|---|---|---|
| ~20 dB | 100M | 0 (bound 1.5e-8) | 0 | pass | pass |
| ~30 dB | 10M | 7.2e-6 | 1.4e-5 | pass, 28x margin | fail, 7x over |
| ~40 dB | 10M | 8.3e-2 | 1.7e-1 | fail | fail |

Float and fixed agree (144 and 148 errors at ~30 dB). At ~40 dB the response has a reflection 17 symbols after
the main pulse and a wide pre-cursor that five taps cannot cancel. Six RTL designs (baseline and hand CSD for
each level) matched the fixed-point model with zero mismatches over 300,000 cycles.

## 5. Phase 4: how many taps and bits does each channel need?

Swept 5, 8, 12, 16, 24, 32 and 48 taps at 12, 10 and 8-bit precision (P12 = Q3.8 / Q1.10, P10 = Q3.6 / Q1.8,
P8 = Q3.4 / Q1.6), five noise seeds, on all three channels. 33 designs were synthesized and all matched the
fixed-point model in simulation.

**BER:**

| Channel | 5 taps | 8 taps | 32 taps | 48 taps |
|---|---|---|---|---|
| ~20 dB, any precision | 0 errors | 0 | 0 | 0 |
| ~30 dB, P12 | 8.1e-6 | 0 errors | 0 | 0 |
| ~30 dB, P8 | 1.7e-5 | 5e-9 (1 error) | 0 | 0 |
| ~40 dB, P12 | 8.3e-2 | 5.6e-2 | 2.5e-4 | 1.2e-4 |
| ~40 dB, P8 | 8.5e-2 | 5.9e-2 | 1.6e-3 | 1.4e-3 |

- Precision matters less than taps, until the stress channel, where 8-bit precision sets a floor near 1.4e-3.
- P12 matches floating point within seed spread. P10 costs up to about 25 percent in BER at ~40 dB.
- At ~40 dB, 48 taps at P12 meets BER (1.2e-4) but not DER (2.5e-4). No FFE of 48 taps or fewer meets the stretch target.

**DFE (floating-point model, decisions fed back, error propagation included), ~40 dB, BER:**

| Feed-forward taps | 0 feedback | 1 | 4 | 24 |
|---|---|---|---|---|
| 5 | 8.3e-2 | 6.2e-2 | 5.7e-2 | 1.1e-3 |
| 16 | 3.9e-2 | 3.5e-2 | 3.4e-2 | 4e-7 |
| 24 | 9.1e-3 | 2.3e-5 | 1.8e-7 | 0 |
| 32 | 2.5e-4 | 4e-8 | 0 | 0 |

24 feed-forward plus 1 feedback tap passes the primary target. Short feed-forward sections do not help until
feedback reaches 24 taps, because the blocking reflection is about 17 symbols out. At ~30 dB, 5 feed-forward
plus 16 feedback taps also removes all errors.

**Hardware cost (hand CSD, iCE40 UP5K), logic cells / Fmax MHz, ~30 dB:**

| Taps | P12 | P10 | P8 |
|---|---|---|---|
| 5 | 571 / 24.8 | 419 / 23.6 | 295 / 26.8 |
| 8 | 965 / 20.6 | 657 / 21.2 | 409 / 24.4 |
| 16 | 1752 / 17.0 | 1176 / 18.4 | 680 / 22.0 |
| 32 | 3073 / 16.2 | 2042 / 17.2 | 1121 / 19.2 |
| 48 | 4001 / 14.6 | 2531 / 16.4 | 1350 / 18.6 |

The ~40 dB, 48-tap, P12 FFE takes 5,252 cells, 99.5 percent of the device.

**Cheapest design meeting each target:**

| Channel | Primary (BER and DER at most 2e-4) | Stretch (BER at most 1e-6) |
|---|---|---|
| ~20 dB | 5 taps, P8, 281 cells | 5 taps, P8, 281 cells |
| ~30 dB | 5 taps, P8, 295 cells | 8 taps, P8, 409 cells |
| ~40 dB | not met by an FFE (48 taps P12 meets BER only, 5,252 cells) | not met |

## 6. Phase 5: the agent loop

**Question:** does a model that sees verification, BER, synthesis and timing results and tries again find a
smaller and faster equalizer than a model that answers once?

**Setup:** the ~30 dB channel, 5 taps `[163, -417, 782, -1268, 1536]`, primary target only. Each reply came from
a fresh Claude instance (configured as `claude-sonnet-5-5`; the serving model may differ) with no tools or files.
Eight rounds. Each round's prompt held the task text, a table of past attempts, and the full report and RTL of
the best design so far.

**Gates a design must pass before it is scored:**

| Gate | Check |
|---|---|
| G1 | builds in Verilator and synthesizes in Yosys |
| G2 | directed tests (reset, extreme and alternating inputs, worst-case accumulation, 5,000 random inputs); every output within 8 LSB of the exact reference, exactly 0 while in reset |
| G3 | 2,000,010 symbols through the channel and RTL, BER and DER at most 2e-4 |

**Score** (lower is better) = (logic cells / 571) × sqrt(24.8 / Fmax in MHz). The hand CSD design scores 1.000.

| Attempt | Cells | Fmax MHz | Score | Max error (LSB) |
|---|---|---|---|---|
| Baseline (generic multipliers) | 867 | 17.8 | 1.794 | 0 |
| Hand CSD | 571 | 24.8 | 1.000 | 0 |
| One-shot, exact | 329 | 46.5 | 0.421 | 0 |
| Control A (single reply, loop prompt) | 350 | 47.1 | 0.445 | 0 |
| Control B (single reply, loop prompt) | 517 | 27.3 | 0.864 | 6 |
| Loop round 1 | failed G2 | | | 4095 |
| Round 2 | 487 | 39.8 | 0.674 | 0 |
| Round 3 | 388 | 44.2 | 0.510 | 1 |
| Round 4 | 347 | 47.7 | 0.438 | 1 |
| Round 5 | 323 | 45.4 | 0.419 | 2 |
| Round 6 | 295 | 46.5 | 0.378 | 4 |
| Round 7 | 283 | 56.7 | 0.328 | 5 |
| **Round 8** | **274** | **54.1** | **0.325** | 7 |

**What happened:**

- Round 1 failed G2 and passed G3. It used 24-bit sums where the worst case needs 25, so extreme inputs wrapped
  (errors up to 4095 LSB). The link BER was identical to the exact design (8.25e-6) because real PAM4 inputs never
  reach those extremes. A BER test alone would have accepted a broken design.
- Rounds 2 to 6 narrowed the datapath (25, 19, 17, 16, 15 bits) by scaling terms down and dropping low bits.
- Rounds 7 and 8 removed one CSD term each from two constants (163 became 164, -417 became -416).
- The model's cell-count predictions were close. Its Fmax predictions were weaker.

**How to read it:**

- The loop's best (0.325) is 23 percent below the best single reply (0.421). One loop run and four single
  replies from one model show the direction, not a measured effect size.
- Most of the gain is approximation, not a better exact design. The best exact designs were found by single
  replies (0.421 and 0.445), better than the loop's own exact design in round 2 (0.674).
- The 8 LSB tolerance was my choice. All designs show 33 to 36 bit errors in 4M bits (about 8 to 9e-6), against
  a limit of 800. The loop stopped because it ran out of tolerance, not because the link needed the accuracy. A
  looser G2 would likely give a smaller design.
- Rounds 7 and 8 are close to a tie (their Fmax ranges overlap).
- The model was given the slicer thresholds, typical input level and score formula. That is part of what is measured.

## 7. Limits

- One front end (CTLE and sampling phase) per channel, reused across tap counts. A different front end could change tap counts.
- The ~40 dB channel is built from the highest-loss public file plus a simplified package model.
- No transmitter FFE, jitter or duty-cycle distortion, and no receiver DFE in the main results.
- The DFE is a floating-point model, with no quantization, timing or area.
- Zero-error results are upper bounds. The ~40 dB points have 2e7 bits and cannot resolve the stretch target.
- Phase 5 covers one channel, one loop run, one model, one device family.
- Fmax comes from FPGA place and route and is a relative measure. Nothing was run on hardware.
- The Week 1 and 2 hand reference is direct-form CSD, not transposed form.

## 8. What I would do next

These are not started. Each is a separate piece of work.

1. Build and synthesize a DFE (the ~40 dB result says it is the structure that is needed) and check that its
   decision loop closes in one symbol time.
2. Run the agent loop on the ~20 and ~40 dB channels, repeat it several times, and try a looser or tighter G2 tolerance.
3. Repeat the hand-versus-AI comparison with a hand-written transposed-form CSD design as the reference.
4. Run the final designs on hardware.

## 9. Where things are

| What | Where |
|---|---|
| Phase write-ups | `documentation/phase3_802_3dj.md`, `phase4_tap_precision_sweep.md`, `phase5_agent_loop.md` |
| Week 1 and 2 write-ups | `documentation/optimization_provenance.md`, `channel_connection.md` |
| Simple walkthroughs | `documentation/*_walkthrough.md` |
| How to rerun | `documentation/reproducibility.md` |
| Results data and figures | `results/dj/`, `results/sweep/`, `results/agent/`, `results/channel/` |
| RTL | `rtl/` (the AI-designed RTL carries a header saying Claude generated it) |
| Earlier release audit of Cases A to C | `results/phase6/` |
