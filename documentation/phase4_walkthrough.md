# Phase 4 Walkthrough: Taps, Precision, and When an FFE Is Not Enough

## What was added

| File | What it does |
|---|---|
| `python/rtl_gen/ffe_gen.py` | Generates RTL for any tap count and word width (baseline and per-tap CSD) |
| `testbench/sweep/ffe_stream_tb.sv` | Streams samples through any generated design and dumps outputs |
| `python/dj/sweep.py` | BER for every taps x precision combination on one channel, same samples for all |
| `python/dj/dfe.py`, `dfe_sim.c`, `dfe_sweep.py` | Decision-feedback equalizer model (C inner loop, floating point) |
| `python/dj/hw_sweep.py` | Generate RTL, check it in Verilator, synthesize, place and route over seeds |
| `python/dj/report_sweep.py` | Tables and figures in `results/sweep/` |
| `documentation/phase4_tap_precision_sweep.md` | Full write-up |

## The ideas

1. **More taps cancel more echoes.** Each tap can cancel one symbol's worth of trailing or leading echo.
   A channel with an echo 17 symbols away needs about that many taps to cancel it.
2. **Precision.** P12 is the existing 12-bit design; P10 and P8 shrink the sample and coefficient words.
   The cost is rounding noise and coarser coefficients.
3. **DFE.** After a symbol is decided, a DFE subtracts its known echo from later samples. It cancels
   post-cursor echoes with a few taps and does not amplify noise. Its catch is timing: the decision loop
   must finish within one symbol time.
4. **Same samples for every design.** Within each seed all designs see identical noise, so differences are the equalizer's.

## Results in one table

| Channel | Cheapest design that passes primary | Passes stretch? |
|---|---|---|
| ~20 dB | 5 taps, 8-bit: 281 LC | yes, same design |
| ~30 dB | 5 taps, 8-bit: 295 LC | 8 taps, 8-bit: 409 LC |
| ~40 dB | FFE alone: no (48 taps, BER 1.2e-4 but DER 2.5e-4) | no |
| ~40 dB with DFE (model) | 24 feed-forward + 1 feedback tap | 24 + 4 taps |

## Questions you may get

**"Does lower precision hurt?"** Not at 20 and 30 dB. At 40 dB, 8-bit stalls near 1.4e-3 while 12-bit reaches 1.2e-4.

**"Why is 40 dB so hard?"** There is an echo about 17 symbols after the main pulse and a wide pre-cursor.
Five taps cannot reach either; 32 to 48 taps can, at nearly the whole FPGA.

**"Did you build the DFE in hardware?"** No. It is a floating-point model that shows where a DFE
becomes necessary, which was the request.

**"Is the RTL right at all these sizes?"** All 33 synthesized designs matched the fixed-point model in Verilator.

**"Why only 3 placement seeds?"** The logic-cell count did not change across seeds and Fmax spread was small;
5 seeds would have been better.

## Rerunning

See the top of `documentation/phase4_tap_precision_sweep.md`. The full BER sweep takes about 5 minutes,
synthesis about 30 minutes on 2 cores.
