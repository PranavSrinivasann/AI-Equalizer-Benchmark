# Phase 4: How many taps and how much precision does each channel need?

Phase 3 showed the 5-tap, 12-bit FFE passes the ~20 dB and ~30 dB channels
at the primary target (BER and DER <= 2e-4) and fails the ~40 dB stress
channel. This phase sweeps tap count and word width on all three channels,
synthesizes the designs, and models a DFE for the case the FFE cannot reach.

Reproduce (needs the Phase 3 results in `results/dj/` and the channel files):

```bash
python3 python/dj/sweep.py --level loss30 --out results/sweep/ber_loss30.csv   # also loss20, loss40
python3 python/dj/dfe_sweep.py --level loss40 --out results/sweep/dfe_loss40.csv   # also loss30
python3 python/dj/hw_sweep.py --levels loss30 --seeds 3 --check --out results/sweep/hw_loss30.csv
python3 python/dj/report_sweep.py                                               # tables and figures
```

## 1. What was swept

| Dimension | Values |
|---|---|
| FFE taps | 5, 8, 12, 16, 24, 32, 48 |
| Precision (sample bits / coefficient fraction bits) | P12 = Q3.8 / Q1.10 (the existing design), P10 = Q3.6 / Q1.8, P8 = Q3.4 / Q1.6 |
| Channels | the three levels from Phase 3 (20.8, 30.6, 40.7 dB) |
| Noise realizations | 5 seeds per point, identical samples for every design within a seed |
| Symbols per point | 50M at ~20 dB, 100M at ~30 dB, 10M at ~40 dB (so 1e8, 2e8 and 2e7 bits) |
| DFE | feed-forward 5/8/16/24/32 x feedback 0/1/2/4/8/16/24/32 taps, floating point |

Each tap count gets its own MMSE design over the full covariance (ISI,
transmitter noise, crosstalk, receiver noise), scaled to fit the coefficient range
and rounded. The CTLE setting and sampling phase are the ones Phase 3 chose
for the 5-tap FFE and are kept for every tap count. A different front end
could shift the numbers below, most likely in favor of fewer taps; it was not
tested.

Pass rule, as in Phase 3: the measured rate is at or below the target and so is
its 95% upper bound. A run with no errors is a bound, not a rate.

## 2. BER results

`results/sweep/ber_summary.csv` has every point, with per-seed spread.
`results/sweep/ber_vs_taps.png` shows them.

| Channel | 5 taps | 8 taps | 12-24 taps | 32 taps | 48 taps |
|---|---|---|---|---|---|
| ~20 dB | 0 errors, all precisions | 0 | 0 | 0 | 0 |
| ~30 dB, P12 | 8.1e-6 | 0 errors | 0 | 0 | 0 |
| ~30 dB, P8 | 1.7e-5 | 5e-9 (1 error) | 0 | 0 | 0 |
| ~40 dB, P12 | 8.3e-2 | 5.6e-2 | 4.6e-2 (12), 3.9e-2 (16), 9.1e-3 (24) | 2.5e-4 | 1.2e-4 |
| ~40 dB, P8 | 8.5e-2 | 5.9e-2 | 4.9e-2, 4.4e-2, 1.2e-2 | 1.6e-3 | 1.4e-3 |

- **~20 dB:** nothing fails, even 5 taps at P8 (8-bit samples, 6-bit coefficient fraction): no errors in 1e8 bits.
  The 95% bound is 3e-8, so both targets are met. Whether fewer than 8 bits still work was not tested.
- **~30 dB:** 8 taps removes the errors. 8 taps meets the stretch target at every precision
  (P8 saw one error in 2e8 bits, 5e-9). At 5 taps, P8 doubles the BER (1.7e-5 against 8.1e-6) but still meets the primary target.
- **~40 dB, FFE only:** BER falls steeply between 24 and 32 taps and flattens. At 48 taps P12 gives BER 1.2e-4
  (passes) but DER 2.5e-4 (fails 2e-4). At 32 taps both fail. P10 is within 30% of P12; P8 stalls at about 1.4e-3,
  so this channel needs coefficient resolution as well as taps. No FFE of 48 taps or fewer meets the
  stretch target.
- **Fixed point vs. float:** P12 matches float at every point to within the spread across seeds
  (for example 8.08e-6 against 7.99e-6 at 30 dB, 5 taps; 1.23e-4 against 1.21e-4 at 40 dB, 48 taps).
  P10 costs up to about 25% in BER on the 40 dB channel (1.5e-4 against 1.2e-4 at 48 taps).
- No input sample clipped in any run.

## 3. Where a DFE comes in

A floating-point DFE with decisions fed back (so error propagation is included). With zero feedback taps it
reproduces the FFE numbers (8.3e-2 at 5 taps, 40 dB), which checks the model.
`results/sweep/dfe_ber_grid.png`, `results/sweep/dfe_summary.csv`.

| ~40 dB channel | Feedback 0 | 1 | 2 | 4 | 8 | 24 |
|---|---|---|---|---|---|---|
| 5 feed-forward | 8.3e-2 | 6.2e-2 | 6.2e-2 | 5.7e-2 | 5.2e-2 | 1.1e-3 |
| 16 feed-forward | 3.9e-2 | 3.5e-2 | 3.5e-2 | 3.4e-2 | 3.1e-2 | 4e-7 |
| 24 feed-forward | 9.1e-3 | 2.3e-5 | 1.8e-5 | 1.8e-7 | 8e-8 | 0 |
| 32 feed-forward | 2.5e-4 | 4e-8 | 0 | 0 | 0 | 0 |

- 24 feed-forward plus **1** feedback tap passes the primary target for BER and DER (2.3e-5 and 4.6e-5).
  With 4 feedback taps it passes the stretch target (1.8e-7).
- Short feed-forward sections (5 to 16 taps) do not help until the feedback reaches 24 taps; the
  reflection that stops the FFE is about 17 symbols after the main pulse. At the ~30 dB channel,
  5 feed-forward plus 16 feedback taps also removes all errors.
- This is a bound from a floating-point model. A DFE has to close its decision loop within one symbol time,
  and no DFE hardware was built or synthesized here.

## 4. Hardware cost

Hand per-tap CSD direct-form RTL was generated for every swept coefficient set (`python/rtl_gen/ffe_gen.py`),
and 33 designs were synthesized: the full ~30 dB grid (7 tap counts x 3 precisions), 5 and 8 taps at ~20 dB,
and 24/32/48 taps at P12 and P10 for ~40 dB (`results/sweep/tradeoff.csv`). Every one was checked against the
fixed-point model in Verilator (20,000 cycles of random and extreme inputs with mid-stream resets): 33 of 33 match.
nextpnr targets the iCE40 UP5K (5,280 logic cells) at a 12 MHz constraint, three placement seeds;
logic-cell counts are identical across seeds and Fmax is the median. Every design fits the UP5K,
so the ECP5 fallback was not needed.

~30 dB channel, logic cells / Fmax (MHz):

| Taps | P12 | P10 | P8 |
|---|---|---|---|
| 5 | 571 / 24.8 | 419 / 23.6 | 295 / 26.8 |
| 8 | 965 / 20.6 | 657 / 21.2 | 409 / 24.4 |
| 12 | 1285 / 19.0 | 951 / 20.1 | 620 / 22.0 |
| 16 | 1752 / 17.0 | 1176 / 18.4 | 680 / 22.0 |
| 24 | 2522 / 16.5 | 1695 / 16.8 | 967 / 20.2 |
| 32 | 3073 / 16.2 | 2042 / 17.2 | 1121 / 19.2 |
| 48 | 4001 / 14.6 | 2531 / 16.4 | 1350 / 18.6 |

Other channels: ~20 dB 5 taps P8 281 LC / 28.5 MHz, 8 taps P8 373 LC; ~40 dB 48 taps P12 5252 LC / 14.1 MHz
(99.5% of the device), 48 taps P10 3512 LC / 15.2 MHz, 32 taps P12 3613 LC / 14.6 MHz.
Figure: `results/sweep/area_vs_ber_loss30.png`.

Cheapest design that meets each target (hand CSD, iCE40 UP5K):

| Channel | Primary (BER and DER <= 2e-4) | Stretch (BER <= 1e-6) |
|---|---|---|
| ~20 dB | 5 taps P8, 281 LC | 5 taps P8, 281 LC |
| ~30 dB | 5 taps P8, 295 LC | 8 taps P8, 409 LC |
| ~40 dB | not met by an FFE of 48 taps or fewer on both BER and DER; 48 taps P12 meets BER only (5252 LC) | not met |

Compared with the 5-tap, 12-bit design from Phase 3 (507 LC at ~20 dB, 571 LC at ~30 dB), the cheapest
passing designs are 45% and 48% smaller at the primary target, and 28% smaller at ~30 dB for the stretch target.

## 5. What this says

1. **Precision matters less than taps, up to a point.** On the easy and main channels 8-bit samples
   and 6-bit coefficient fractions cost almost nothing; the extra 5 to 8 taps at ~30 dB are worth more
   than any precision. On the stress channel, 8-bit precision is the bottleneck (BER floor near 1.4e-3).
2. **Taps and area grow together.** The hand direct-form cost is roughly 80 to 115 LC per tap at P12 and 50 to 85 at P10.
   An FFE that reaches the stress channel's BER target uses essentially the whole UP5K.
3. **The stress channel is a DFE case.** The FFE alone needs 48 taps and still misses DER;
   24 feed-forward taps with a few feedback taps pass both targets in the model.
4. **The numbers above are the reference for Phase 5.** The designs here are plain direct-form CSD. In
   Week 2 the AI-optimized transposed form was about 2.4x smaller and 2.5x faster than the same
   style of hand design at 5 taps; whether that holds at 8 to 48 taps is what the agent loop can test.

## 6. Limits

- One front-end setting per channel (Phase 3's), reused for all tap counts.
- 5 noise seeds; 3 placement seeds (the plan said 5; the logic-cell counts did not vary across seeds and Fmax spread
  was small, but it is three).
- The ~40 dB results have 2e7 bits per point; they are fine at 1e-4 and not for the stretch target.
- Hand-CSD direct form only. No generic-multiplier baseline was re-synthesized for the new sizes.
- The DFE is a floating-point model without hardware cost, quantization, or timing.
- Fmax values are for an FPGA flow at a 12 MHz constraint. They show trends across designs, not line-rate speed.
