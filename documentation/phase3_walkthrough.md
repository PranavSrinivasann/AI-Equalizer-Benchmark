# Phase 3 Walkthrough: Real 200G Channels

What was done, in plain terms, and what to say if asked.

## What was added

| File | What it does |
|---|---|
| `scripts/fetch_8023dj_channels.sh` | Downloads the public channel files for the three loss levels |
| `python/dj/channel_model.py` | Reads the S-parameters, adds package, Rx filter and CTLE, produces symbol-spaced pulse responses |
| `python/dj/ffe_design.py` | Designs the 5-tap FFE (with crosstalk and noise), input gain, and the Monte-Carlo link simulation |
| `python/dj/run_phase3.py` | Runs everything and writes `results/dj/` |
| `rtl/dj/` | Baseline and hand-CSD RTL for each channel's coefficients |
| `documentation/phase3_802_3dj.md` | The full write-up |

## The ideas

1. **S-parameters to pulse response.** A channel file gives gain versus frequency. An inverse FFT of that,
   times the shape of one symbol, gives what one symbol looks like at the receiver. Sampling it once per
   symbol gives the numbers the FFE works with: a main value and leftovers on either side (ISI).
2. **Why CTLE and a sampling phase.** Real receivers boost high frequencies before sampling and choose
   where in the symbol to sample. Both are chosen here to help the 5-tap FFE the most.
3. **Crosstalk.** Neighboring lanes leak in. Each leak path is a separate file, driven by its own random data.
4. **What "pass" means.** Measured BER and DER at or below 2e-4 (primary) and BER at or below 1e-6 (stretch).
   A run with no errors is only a bound: 100M symbols with none means below about 1.5e-8.

## Results

| Level | Loss | BER (5-tap, fixed point) | Primary 2e-4 | Stretch 1e-6 |
|---|---|---|---|---|
| baseline | 20.8 dB | 0 in 200M bits | pass | pass |
| main | 30.6 dB | 7.2e-6 | pass | fail |
| stress | ~40 dB | 8.3e-2 | fail | fail |

## Questions you may get

**"Is the 40 dB channel an official file?"** No. It is the highest-loss public file (35.4 dB) plus a
package model, 40.7 dB total. Say so.

**"Did fixed point hurt?"** No measurable difference (144 vs. 148 errors on the main channel).

**"Does the RTL match?"** Yes, 0 mismatches over 300,000 cycles per design and channel, with both baseline and hand RTL.

**"Why does the stress channel fail?"** Five taps cannot cancel a reflection 17 symbols later or the wide
pre-cursor. That is the case for more taps or a DFE (Phase 4).

**"What was not modelled?"** Tx FFE, jitter, DFE, and the exact package model.

## Rerunning

```bash
./scripts/fetch_8023dj_channels.sh
python3 python/dj/run_phase3.py --max-symbols 2000000 --rtl-symbols 20000    # quick, about 30 s
python3 python/dj/run_phase3.py                                              # full, about 75 s
```
