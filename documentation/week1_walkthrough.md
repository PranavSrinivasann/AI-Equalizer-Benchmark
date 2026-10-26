# Week 1 Walkthrough: Verification and Optimization Provenance

This covers the professor's first two points: what the optimizations
actually do (with a hand-optimized comparison), and complete verification
evidence including reset, saturation and extreme inputs.

## What was added

| File | What it does |
|---|---|
| `scripts/rebuild_all.py` | One command that simulates, synthesizes and places-and-routes all nine designs and writes `results/rebuild/summary.csv` |
| `python/verification/check_arithmetic_bounds.py` | Shows when saturation can fire, and checks the bit-level arithmetic tricks in the B and C optimized RTL |
| `python/verification/generate_directed_vectors.py` | Builds the directed test vectors in `test_vectors/directed/` |
| `testbench/directed/ffe5tap_directed_tb.sv` | Testbench that drives reset and input each cycle and reports results per test group |
| `rtl/hand/ffe5tap_case{A,B,C}_hand.sv` | Hand-optimized reference designs (plain CSD shift-add) |
| `documentation/optimization_provenance.md` | The write-up: change log, what's recorded, comparison table |

## The ideas you need

### 1. Why saturation can or can't fire

The output is `y = (c0*x0 + ... + c4*x4) >> 10`, with each input in
[-2048, 2047]. The largest possible `|acc|` is `2048 * (|c0| + ... + |c4|)`.
Divide by 1024 (the shift) and you get the largest possible `|y|`:

- If `sum|c| < 1024`, then `|y| < 2048`, so `y` always fits 12 bits and
  saturation never triggers.
- Case A: `sum|c| = 1434`, so saturation **can** trigger (up to ±2868).
- Cases B and C: 486 and 469, so it **can't**. Removing it changes nothing.

This one-line bound is the whole justification for removing saturation.

### 2. CSD (canonical signed digit)

A constant multiply can be written as shifts and adds. CSD allows both +
and − digits, which minimizes the number of nonzero digits:

- `93 = 64 + 16 + 8 + 4 + 1` (5 terms) vs. CSD `93 = 128 − 32 − 4 + 1` (4 terms)
- Each nonzero digit costs one adder, so fewer digits means less logic.

The hand reference does exactly this, one tap at a time. It's what a
competent engineer would do mechanically.

### 3. What the optimized designs do beyond CSD

They share work **across taps**:

- **Pre-adders** (A and C): when `c4 = −c0`, `c0*x0 + c4*x4 = c0*(x0 − x4)`.
  One subtraction replaces a whole multiply.
- **Common factors** (C): `51 = 3*17` and `93 = 3*31`, so
  `51*d + 93*x2 = 3*(17*d + 31*x2)`. The `*3` is shared.
- **Coefficient relations** (B): `146 = 2*73` and `89 = 73 + 16`, so three
  taps share one `73*S`.
- **Skipping bits** (C): when you add `16*d + d`, the low 4 bits of the
  result are just the low 4 bits of `d`, so the adder only needs to cover
  the upper bits.

That cross-tap sharing is the "additional value" the professor asked about.
It accounts for about half of the total logic saving in every case.

### 4. The directed tests

Each line in a vector file is one clock cycle: `rst_n x_in expected group`.
The testbench applies `rst_n` and `x_in`, clocks once, and checks `y_out`.
Because reset is in the vector file, tests can hit reset at any point.

| Group | Tests |
|---|---|
| 1 | Power-up: reset held with nonzero input, then released |
| 2 | Constant max / min inputs filling the delay line |
| 3 | Alternating max/min (period 2 and 4) |
| 4 | Worst-case windows: inputs signed to match the coefficients |
| 5 | Windows that land exactly on, and just past, ±2047/−2048 |
| 6 | Single-cycle reset in the middle of random data, several phases |
| 7 | Reset held for several cycles while the input keeps changing |
| 8 | PAM4 levels (±256, ±768) |
| 9 | 5,000 uniform random samples |

The expected values come from a Python golden model of the spec
(`Golden.step` in the generator), not from any of the RTL.

### 5. Why 10 placement seeds

nextpnr's placement is randomized. Fmax can move a few MHz between seeds,
so a single run can make a design look better or worse than it is. We run
10 seeds and report the median and range. Logic-cell counts turned out to
be identical across seeds; only Fmax varies.

## Results at a glance

| Case | Baseline LC | Hand LC | Optimized LC | Fmax median, MHz (base / hand / opt) |
|---|---|---|---|---|
| A | 638 | 534 | 408 | 20.1 / 24.4 / 21.3 |
| B | 664 | 478 | 236 | 20.3 / 27.8 / 35.2 |
| C | 817 | 527 | 247 | 26.6 / 28.0 / 32.0 |

All nine designs pass both the 1000-sample regression and the directed
tests with zero mismatches.

## Questions you may get, and answers

**"Is the saturation removal safe?"**
Yes, by the bound in section 1: B and C can never exceed ±972. It's also
confirmed by simulation, including worst-case inputs.

**"How much of the gain is the AI, versus anyone doing shift-adds?"**
About half. Plain CSD gets 16–35% fewer logic cells; the optimized
designs get a further 24–53%, which comes from cross-tap sharing.

**"Why is the Case A hand design faster than the optimized one?"**
The Case A optimized RTL keeps two `*` operators after its pre-adders,
and synthesis maps those less efficiently than explicit CSD. Pre-adders
plus CSD would probably beat both, but that hasn't been tested.

**"Why do the numbers differ from the earlier report?"**
Different tool versions (the rebuild uses Yosys 0.70). B optimized moved
the most, from 376 to 236 logic cells. All comparisons now use one rebuild
so they're consistent with each other.

**"Was the Case A verification redone?"**
Yes. Case A now has saved regression and directed logs in
`results/rebuild/A_*/`, and its directed set produces 322 saturated
outputs, so the saturation path is tested.

## Rerunning it

```bash
python3 scripts/rebuild_all.py --seeds 10          # everything, about 8 minutes
python3 scripts/rebuild_all.py --only C_ai --seeds 1   # one design, quick
python3 python/verification/check_arithmetic_bounds.py
```

Needs `verilator`, `yosys` and `nextpnr-ice40` on PATH (the `yowasp-*`
PyPI builds also work).
