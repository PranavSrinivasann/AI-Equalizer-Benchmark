# Phase 3: 5-tap FFE on 200G/lane (802.3dj) channels

Question: does the 5-tap PAM4 FFE meet the target error rate on the public
802.3dj 200G/lane electrical channels at three loss levels, and where does it stop being enough?

- Primary target: BER and DER <= 2e-4
- Stretch target: BER <= 1e-6
- Link: 212.5 Gb/s PAM4, 106.25 GBd, Nyquist 53.125 GHz

Reproduce:

```bash
./scripts/fetch_8023dj_channels.sh          # downloads the S-parameter files into data/8023dj/ (not committed)
export PATH=/usr/local/lib/python3.13/site-packages/verilator/bin:$PATH
export VERILATOR_ROOT=/usr/local/lib/python3.13/site-packages/verilator
python3 python/dj/run_phase3.py             # about 75 s; writes results/dj/ and rtl/dj/
```

## 1. Channels

| Level | Files | Sdd21 at 53.125 GHz | With package and terminations | Crosstalk files |
|---|---|---|---|---|
| `loss20` baseline | KR backplane, 100 mm | 20.8 dB | 20.6 dB | 3 FEXT, 4 NEXT |
| `loss30` main | KR backplane, 1200 mm | 30.6 dB | 30.4 dB | 3 FEXT, 4 NEXT |
| `loss40` stress | OSFP cabled channel, 27 dB cable (vendor Y) | 35.4 dB | 40.7 dB | 3 FEXT, 2 NEXT |

The 40 dB stress channel is not a single published file at that loss. It is
the highest-loss channel in the public set (35.4 dB) with the reference
package model added on both ends (about 5 dB, which includes the mismatch to
the 92.5 ohm terminations). `loss20` and `loss30` use no package model, so
their loss is the file's loss. Insertion loss versus frequency:
`results/dj/loss_vs_frequency.png`.

The four-port files are converted to differential Sdd21 by trying both port
pairings and keeping the one with the lower 1 GHz loss (the wrong pairing
shows a large, non-monotonic loss). Crosstalk files use the same pairing.
Loss at 53.125 GHz is checked for every candidate file; the three above were
chosen because they sit near 20, 30 and (with package) 40 dB.

## 2. Pulse responses

Signal chain, all differential:

source (2 x 46.25 ohm) -> Tx package -> channel Sdd21 -> Rx package ->
92.5 ohm termination -> 4th-order Bessel-Thomson filter (3 dB at 53.125 GHz)
-> CTLE -> sampler.

- The frequency response is band-limited with a raised-cosine taper from 80 to 100 GHz.
- The response to a one-UI rectangular pulse comes from an inverse FFT at 32 samples per UI.
- The response is sampled once per UI at the phase chosen below.
- CTLE: zero 25.16 GHz, poles 40 and 56 GHz, DC gain swept from -15 to 0 dB in 1 dB steps.
- The CTLE setting and the sampling phase (32 choices) are picked per
  channel to minimize the error power of the 5-tap MMSE FFE, so each
  channel gets its best front end for this equalizer.

Result at the chosen setting, in mV per unit symbol (symbols are -3, -1, 1, 3;
the outer level is 0.413 V). Figure: `results/dj/pulse_responses.png`.

| Level | CTLE DC gain | Cursor | Largest neighbors |
|---|---|---|---|
| `loss20` | -9 dB | 22.8 | pre-cursor 14.0 |
| `loss30` | -14 dB | 8.5 | 10.2 one UI after the peak sample (the cursor sits at the best sampling phase, the response peaks between samples) |
| `loss40` | -14 dB | 5.4 | pre-cursor 5.1; also a reflection of about 1.2 mV at +17 UI |

The `loss40` response has a reflection 17 UI after the cursor. A 5-tap
equalizer cannot reach that.

## 3. Noise

| Source | Model |
|---|---|
| Receiver noise | 5e-9 V^2/GHz density, integrated through the Rx filter and CTLE |
| Transmitter noise | SNR_TX 33 dB, noise added to the transmitted symbols before the channel |
| Crosstalk | Each Next/Fext file is a separate aggressor with its own random PAM4 stream (outer level 0.608 V for NEXT, 0.413 V for FEXT), filtered by its pulse response at the victim's sampling phase |

RMS contributions at the chosen front end, in mV, against the cursor:

| Level | Cursor | Receiver | Tx noise | Crosstalk |
|---|---|---|---|---|
| `loss20` | 22.8 | 0.40 | 1.35 | 0.57 |
| `loss30` | 8.5 | 0.38 | 0.67 | 0.24 |
| `loss40` | 5.4 | 0.38 | 0.40 | 0.20 |

Full numbers, including the CTLE sweep, are in `results/dj/<level>/summary.json`.

## 4. The 5-tap FFE

Design: MMSE over the full covariance (victim ISI, transmitter noise, all
crosstalk aggressors, receiver noise), best decision delay, rescaled to unit gain on the
wanted symbol, then scaled so every tap fits Q1.10 (largest tap 1536), then
rounded. An input gain stage scales the received voltage so the signal
rms sits at 1/4.5 of the Q3.8 range; no sample was clipped in any run.

| Level | Q1.10 taps (c0 = newest sample) | Decision delay | Output gain | sum abs(c) |
|---|---|---|---|---|
| `loss20` | 80, -216, 466, -938, 1536 | 14 | 0.989 | 3236 |
| `loss30` | 163, -417, 782, -1268, 1536 | 15 | 0.870 | 4166 |
| `loss40` | -290, 829, -1453, 1536, -305 | 13 | 0.461 | 4413 |

All three sets have sum abs(c) above 1024, so saturation can fire (unlike
Cases B and C). The taps are not paired.

## 5. Results

Same samples through the floating-point FFE and the bit-exact fixed-point
model (Q3.8 in, Q1.10 taps, `>>> 10`, 12-bit saturation). Runs add 10M-symbol blocks until
100 bit errors are seen, up to 100M symbols.

| Level | Symbols | BER float | BER fixed | DER fixed | BER <= 2e-4 | DER <= 2e-4 | BER <= 1e-6 |
|---|---|---|---|---|---|---|---|
| `loss20` | 100.0M | 0 | 0 | 0 | PASS | PASS | PASS |
| `loss30` | 10.0M | 7.4e-6 | 7.2e-6 | 1.4e-5 | PASS | PASS | FAIL |
| `loss40` | 10.0M | 8.3e-2 | 8.3e-2 | 1.7e-1 | FAIL | FAIL | FAIL |

- `loss20`: no errors in 200M bits. The 95% upper bound is about 1.5e-8, so the stretch target
  is met with margin. A Gaussian estimate from the error power gives 1.9e-9.
- `loss30`: the primary target is met with a 28x margin. The stretch target is
  missed by 7x.
- `loss40`: fails both. The residual error power is 0.66 (0.03 at `loss20`,
  0.065 at `loss30`). The response has a wide pre-cursor and a reflection at
  +17 UI that five taps cannot reach; Phase 4 tests whether more taps or a DFE fix it.
- Float vs. fixed point: 148 vs. 144 bit errors at `loss30`, 1,661,320 vs.
  1,661,648 at `loss40`. No measurable cost from 12-bit arithmetic here. At
  `loss20` there are no errors to compare.
- The Gaussian estimate (BER 1.9e-9, 3.3e-5, 8.2e-2) matches at `loss40` but is
  4.5x pessimistic at `loss30`, where the remaining error is probably dominated by
  bounded ISI rather than Gaussian noise (not separately verified). Use the simulation, not the estimate, for pass/fail.

## 6. RTL

Baseline and hand-CSD RTL were generated for each coefficient set
(`rtl/dj/`, same generator as `rtl/channel/`). Each was run in Verilator on 300,000
cycles of the channel samples, after a 2-cycle reset, against the fixed-point
model: 0 mismatches for all six designs (`results/dj/<level>/rtl_*.log`).
The optimized (AI) RTL is not part of this phase; it enters in Phase 5.

## 7. Assumptions and limits

- Package model is a simplified two-segment line (12 mm, 1.8 mm) with shunt
  capacitances, not the full reference model. It affects `loss40` only.
- No transmitter FFE, no jitter or duty-cycle distortion, and no receiver DFE.
  The 5-tap result is therefore an FFE-only result.
- Crosstalk aggressors share the victim's sampling phase and are modelled as independent
  random PAM4 streams.
- The CTLE and the sampling phase are tuned per channel for this equalizer.
- One noise setup, one random seed per level. Zero-error results are bounds, not rates.
- Resolution: 1e-6 needs about 1e8 bits, so 100M symbols is used for `loss20`; the
  others stopped early because they had enough errors (and both already fail the stretch target).
- For the reference channel-operating-margin parameters, a single published configuration
  was applied to every channel; per-channel settings may differ.

## 8. Handing over to Phase 4

- `loss20` needs no more than 5 taps. Cheaper variants (fewer taps, narrower words) may still pass.
- `loss30` is the interesting channel: more taps or precision should close the gap to 1e-6.
- `loss40` needs a structural change; Phase 4 shows how many taps, or whether a DFE, brings it under 2e-4.
