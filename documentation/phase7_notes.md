# Phase 7 notes: how much hardware can a PAM4 equalizer save?

Question (Chen, 2026-11-23): how much hardware can we save in a PAM4 equalizer while
meeting the same BER, throughput and latency requirements?

Ground rules for every design: 5-tap FFE, hand-CSD RTL, one sample per cycle, one
cycle of latency, BER and DER <= 2e-4 (DER is about 2 x BER, so DER binds first),
cost in logic cells on the iCE40 UP5K.

Tool versions matter. Yosys 0.71 maps the same RTL to about 8% more cells than
Yosys 0.70 (618 against 571 cells for the 30 dB P12 reference). All numbers here use
Verilator 5.020, Yosys 0.70 (`pip install yowasp-yosys==0.70.0.0.post1259`) and
nextpnr 0.11.1, which reproduce the Phase 4 numbers exactly. The versions are stored
in every JSON record.

## Phase 1: one configuration end to end

`python/flow/run_flow.py` runs four stages and writes one record to
`results/phase7/<name>.json`: reference (quantized coefficients against float), RTL
(Verilator against a bit-exact fixed-point model), BER and DER (100M symbols,
fixed-point and float on the same samples), and place-and-route (Yosys, then
nextpnr: LUT4, logic cells, Fmax).

```
python3 python/flow/run_flow.py --level loss30 --taps 5 --precision P12 --seeds 5
```

Result (30 dB, 5 taps, P12): BER 8.085e-6, DER 1.617e-5, 571 cells, 24.84 MHz. This
matches the Phase 4 sweep exactly. It meets the 2e-4 target and misses the 1e-6
stretch target (the unquantized float design is already at 8.0e-6).

## Phase 2: uniform bit-width baseline

`python/flow/uniform_sweep.py` runs the same flow for widths W6 to W12 (sample bits W,
coefficient fraction W-2; W12 = P12, W10 = P10, W8 = P8).
`python/flow/plot_ber_vs_cells.py` draws BER against logic cells.

| Width | Logic cells | BER | DER | Meets DER <= 2e-4 |
|---|---|---|---|---|
| W6 | 168 | 1.65e-03 | 3.30e-03 | no |
| W7 | 216 | 8.91e-05 | 1.78e-04 | yes |
| W8 | 295 | 1.68e-05 | 3.35e-05 | yes |
| W9 | 325 | 9.87e-06 | 1.97e-05 | yes |
| W10 | 419 | 8.46e-06 | 1.69e-05 | yes |
| W11 | 495 | 8.16e-06 | 1.63e-05 | yes |
| W12 | 571 | 8.08e-06 | 1.62e-05 | yes |

The smallest uniform design that meets DER <= 2e-4 is W7: 216 cells, 62% below the
571-cell reference, with DER 1.78e-4.

## Phase 3: margin-guided per-tap bit widths

Idea: a PAM4 decision has a margin of 1 symbol unit between a level and its threshold.
The error left at the slicer has mean mu and spread sigma, so the margin left is
z = (1 - |mu|) / sigma and the symbol error rate is about 0.75 (Q(z+) + Q(z-)). Bits
are removed one at a time, always where the most hardware is saved per unit of margin
used up (`margin_design.greedy_path`).

What varies per design (`python/flow/margin_design.py`): W (sample bits), F
(accumulator fraction), f[k] (fractional bits of tap k's coefficient), t[k] (LSBs
dropped from the sample that tap k sees, so its delay-line register is narrower), and
b (a constant added to the accumulator that re-centres the output; floor truncation
biases it low and uses up margin). With t = 0, f = F, b = 0 the generator gives
exactly the old uniform results, so the comparison is fair. Every design passes the
Verilator check against the bit-exact model.

The margin predictor (a 2M-symbol sample, Gaussian tail set from the measured float
error rate) ranks designs correctly but under-predicts DER by up to 1.7x for designs
with very coarse coefficients, so it only proposes candidates. The real flow decides.
Search, screening of 88 candidates (4M symbols) and one round of single-bit neighbours
were run before the container reset and gave the ten designs below; those tables were
not regenerated. The ten designs were re-validated here from their labels
(100M symbols, 3 place-and-route seeds) and reproduce the earlier numbers exactly.

| Design | Logic cells | BER | DER | Fmax (MHz) |
|---|---|---|---|---|
| W7_F5_f33555_t00000_b14 | 177 | 8.27e-05 | 1.65e-04 | 33.6 |
| W7_F5_f55555_t00000_b15 | 220 | 6.94e-05 | 1.39e-04 | 28.7 |
| W8_F6_f66556_t01111_b50 | 230 | 4.70e-05 | 9.40e-05 | 28.4 |
| W8_F8_f78858_t01111_b202 | 245 | 4.10e-05 | 8.19e-05 | 27.1 |
| W8_F6_f66556_t00000_b31 | 247 | 1.89e-05 | 3.78e-05 | 27.9 |
| W8_F8_f78878_t00000_b127 | 290 | 1.52e-05 | 3.04e-05 | 25.8 |
| W9_F7_f77777_t01111_b103 | 296 | 1.30e-05 | 2.60e-05 | 27.6 |
| W9_F7_f77777_t00000_b64 | 327 | 9.63e-06 | 1.93e-05 | 26.7 |
| W10_F8_f78878_t01111_b205 | 338 | 9.43e-06 | 1.89e-05 | 27.0 |
| W10_F10_f99aaa_t00000_b511 | 464 | 8.37e-06 | 1.67e-05 | 24.8 |

Reading:

- Smallest design meeting DER <= 2e-4: `W7_F5_f33555_t00000_b14`, 177 cells,
  18% below the best uniform design (216) and 69% below the reference (571). The two
  taps with the smallest coefficients keep 3 bits; the other three keep 5.
- The offset alone (W7 uniform + offset, 220 cells) saves no cells but lowers DER from
  1.78e-4 to 1.39e-4: it buys margin, not area.
- Dropping sample LSBs saves little (247 to 230 cells at W8) and breaks the limit at W7.
- Away from the limit the saving shrinks: about 16% at DER 3e-5, and none above about
  330 cells.
- The 177-cell design has DER 1.65e-4, 17% under the limit. This is one channel and one
  coefficient set.

Plot: `results/phase7/ber_vs_cells_loss30_t5.png`.
