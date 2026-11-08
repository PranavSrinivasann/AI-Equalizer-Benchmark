# Optimized 5-tap FFE for the iCE40 UP5K: transposed form with shared constant multipliers

The rewrite below computes exactly the same function as the baseline and keeps the 1-cycle latency. It uses no DSP blocks, and I estimate it at about 185–200 logic cells (LCs). I worked that number out by hand. I haven't synthesized or simulated the code, so check it with Yosys and an equivalence test before you rely on it (see the last section).

## Optimized RTL

```systemverilog
// ffe5tap_pam4 -- area-optimized for iCE40 UP5K
//   * Transposed-form FIR (register outputs are adder outputs -> LUT+FF packing)
//   * Multiplierless: shared shift-add graph for {3,9,31,23,67,451}·x
//   * Exact-width datapath (23-bit max), pass-through of known-zero LSBs
//   * Saturation reduced to a 2-bit overflow test
// Function, precision, reset behaviour, throughput (1/clk) and latency (1 clk)
// are identical to the baseline.
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);
    // Coefficients (Q1.10), kept for documentation / assertions:
    //   C0 = -134 = -(67 << 1)
    //   C1 = 1152 =  (9  << 7)
    //   C2 = -451 = -(67 + (3 << 7))
    //   C3 =  -31 = -((1 << 5) - 1)
    //   C4 =   46 =  (23 << 1),  23 = 31 - 8

    // ------------------------------------------------------------------
    // 1) Shared constant-multiplier block (multiple constant multiplication)
    //    Each "_hi" is a single carry-chain adder; low bits that are
    //    provably unaffected are wired straight through (no logic).
    // ------------------------------------------------------------------
    logic signed [12:0] x3_hi;    // floor(3x/2)
    logic signed [13:0] x3;       // 3x
    logic signed [12:0] x9_hi;    // floor(9x/8)
    logic signed [15:0] x9;       // 9x
    logic signed [16:0] x31;      // 31x
    logic signed [13:0] x23_hi;   // floor(23x/8)
    logic signed [16:0] x23;      // 23x
    logic signed [12:0] x67_hi;   // floor(67x/64)
    logic signed [18:0] x67;      // 67x
    logic signed [13:0] x451_hi;  // floor(451x/128)
    logic signed [20:0] x451;     // 451x

    assign x3_hi   = x_in + $signed(x_in[11:1]);          // 2x + x
    assign x3      = {x3_hi, x_in[0]};

    assign x9_hi   = x_in + $signed(x_in[11:3]);          // 8x + x
    assign x9      = {x9_hi, x_in[2:0]};

    assign x31     = $signed({x_in, 5'b0}) - x_in;        // 32x - x

    assign x23_hi  = $signed(x31[16:3]) - x_in;           // 31x - 8x
    assign x23     = {x23_hi, x31[2:0]};

    assign x67_hi  = x_in + $signed(x3[13:6]);            // 64x + 3x
    assign x67     = {x67_hi, x3[5:0]};

    assign x451_hi = $signed(x67[18:7]) + x3;             // 67x + 384x
    assign x451    = {x451_hi, x67[6:0]};

    // ------------------------------------------------------------------
    // 2) Transposed-form partial-sum registers (exact minimum widths)
    //    r4 = 23·x[n-1]                      (46·x = r4<<1)
    //    r3 = -31·x[n-1] + 46·x[n-2]                          |.| < 2^18
    //    r2 = -451·x[n-1] + ... + 46·x[n-3]                   |.| < 2^21
    //    r1 = 1152·x[n-1] + ... + 46·x[n-4]                   |.| < 2^22
    // ------------------------------------------------------------------
    logic signed [16:0] r4;
    logic signed [18:0] r3;
    logic signed [21:0] r2;
    logic signed [22:0] r1;

    logic signed [17:0] r4x2;
    assign r4x2 = {r4, 1'b0};                             // 46·x[n-1]

    logic signed [15:0] r1_hi_d;                          // floor((r2+1152x)/128)
    assign r1_hi_d = $signed(r2[21:7]) + x9;

    // ------------------------------------------------------------------
    // 3) Output tap: s = r1 - 134·x[n]  (23-bit exact accumulator)
    //    s[0] = r1[0] (134x is even), so only s[22:1] needs an adder.
    // ------------------------------------------------------------------
    logic signed [21:0] s_hi;                             // s >>> 1
    assign s_hi = $signed(r1[22:1]) - x67;

    // s >>> 10 == s_hi[21:9] (13-bit signed). Saturate to 12 bits:
    // overflow iff the two MSBs differ; saturated value is set by the sign.
    logic               ovf;
    logic signed [11:0] y_sat;
    assign ovf   = s_hi[21] ^ s_hi[20];
    assign y_sat = ovf ? {s_hi[21], {11{~s_hi[21]}}} : s_hi[20:9];

    // ------------------------------------------------------------------
    // 4) Registers -- synchronous active-low reset, all cleared to 0
    // ------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            r4    <= '0;
            r3    <= '0;
            r2    <= '0;
            r1    <= '0;
            y_out <= '0;
        end else begin
            r4    <= x23;                                 // C4 = 46 = 23<<1
            r3    <= r4x2 - x31;                          // + C3·x
            r2    <= r3 - x451;                           // + C2·x
            r1    <= {r1_hi_d, r2[6:0]};                  // + C1·x (low 7 bits pass)
            y_out <= y_sat;                               // + C0·x, >>>10, sat
        end
    end
endmodule
```

## Architectural changes

**1. Removed every general multiplier.** The baseline has five `x * C` operators, so Yosys builds either 5 SB_MAC16 DSP blocks (out of 8) with `-dsp`, or generic array multipliers. A 12×12 signed array multiplier with a negative constant like −134 has many 1-bits in two's complement, so it maps poorly to LUTs. The new design builds every product from shifts and adds only.

**2. Shares multiplier work across taps.** In transposed form, all five coefficients multiply the same input `x_in`. That makes it a multiple-constant-multiplication problem, where intermediate products can be reused. The coefficients reduce to five odd base values, {9, 23, 31, 67, 451}. I checked that 451 can't be made from the others with a single add, so this graph uses 6 adders:

| Product | Built as | Adder width |
|---|---|---|
| 3x | 2x + x | 13 |
| 9x | 8x + x | 13 |
| 31x | 32x − x | 17 |
| 23x | 31x − 8x | 14 |
| 67x | 64x + 3x | 13 |
| 451x | 67x + 128·3x | 14 |

Writing each coefficient separately as signed digits (canonical signed digit, CSD) would need 14 terms, which is 9 adders inside the taps plus 4 to sum them.

**3. Switched from direct form to transposed form.** On the iCE40, each logic cell holds one LUT4, one carry and one flip-flop, and it has only one output. In the baseline's x1…x4 delay line, each flip-flop is fed by another flip-flop. Each of those 48 flip-flops therefore needs a cell of its own, with no logic in it. In transposed form, every register (r4…r1) is fed directly by an adder, so the flip-flop packs into the same cell as the adder bit at no extra cost. There are more flip-flops in total (about 93 instead of 60), but they cost nothing extra. Only 10 of them sit in cells of their own: r1[6:0] and r4[2:0].

Reset equivalence holds. Clearing x1…x4 in the baseline and clearing r1…r4 here both mean "all past samples contribute 0", so the output matches cycle for cycle, including during and after reset.

**4. Skipped bits that are known in advance.** Wherever an operand is shifted left by k, the low k bits of the sum are wired straight through and only the upper part goes through an adder. This applies to the `{_hi, low bits}` assignments, `r1`, and `s[0]`. Writing it out explicitly means the result doesn't depend on Yosys finding the optimization.

**5. Used exact widths.** The largest possible magnitude is 1814 × 2048 ≈ 3.72M, which is less than 2²², so the accumulator needs 23 bits, not 28. Every intermediate signal is sized to its proven range, and the bounds are written in the comments.

**6. Simplified saturation.** The baseline uses two 28-bit signed comparators. Here, the shifted value is a 13-bit number (s[22:10]), and it overflows 12 bits exactly when its top two bits differ. The result is one 3-input LUT per output bit, packed with the y_out flip-flop. `y_out[11]` is always equal to s[22].

Precision is unchanged throughout. All arithmetic is exact integer arithmetic, so `s` equals the baseline `acc` bit for bit, and taking s_hi[21:9] is exactly `acc >>> 10`.

## Expected resources (hand estimate, not synthesized)

| Block | Approx. LCs |
|---|---|
| Shared multiplier block (6 adders) | ~84 |
| Partial-sum adders r3, r2, r1 (registers absorbed) | ~57 |
| Flip-flops in their own cells (r1[6:0], r4[2:0]) | 10 |
| Output adder s_hi (22 bits) | ~22 |
| Saturation + y_out | ~12 |
| **Total** | **~185–200 LCs, 0 DSP, 0 BRAM** (about 3.5–4% of 5280) |

For comparison, a direct-form version with CSD multipliers comes to roughly 280–300 LCs. The 48 delay-line cells are most of that difference. The baseline itself would need either 5 of the 8 DSPs plus about 150 or more LCs, or a large LUT array-multiplier mapping.

## Tradeoffs

- **DSP blocks:** this design uses none, which leaves all 8 SB_MAC16 free for other logic. If DSPs cost you nothing and LCs are the only measure, a version using DSP blocks for the multiplies could save a few dozen more LCs. On a UP5K, though, DSPs are usually the scarcer resource.
- **Timing:** the longest combinational path is `x_in → 3x → 67x → s_hi → saturation → y_out`. That is three ripple-carry chains (13, 13 and 22 bits), which overlap from the low bits up. This is shorter than the baseline's multiplier followed by a 5-input sum. `x_in` now drives about 10 loads, which is fine at this size.
- **Internal state:** the registers now hold partial sums rather than delayed input samples. That's invisible at the ports, but debug probes have to look at r1…r4 instead of x1…x4.
- **Readability:** the coefficients are now built into the shift-add graph. Changing a coefficient means re-deriving that graph.

## How to check it

1. **Equivalence:** wrap the baseline and the new design in a miter and run SymbiYosys with k-induction. The internal state is mapped differently, so a combinational equivalence check isn't enough. Alternatively, run a random-plus-corner-case testbench with x = −2048 and 2047 held for 5 or more cycles, alternating signs, with reset asserted mid-stream.
2. **Real resource count:** run `yosys -p "synth_ice40 -top ffe5tap_pam4 -abc9; stat"` on both designs, with and without `-dsp`. Then use `nextpnr-ice40 --up5k` to get the LC count after packing.
