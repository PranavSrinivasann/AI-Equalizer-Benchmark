# Resource-optimized 5-tap FFE for the iCE40 UP5K (Case long_tail)

## Summary

The baseline uses 5 generic signed 12×12 multipliers, a 48-flip-flop delay line and 28-bit adders and comparators. This version does the same math with 10 shift-add adders and minimum-width datapaths. It uses no DSP blocks and no block RAM. I expect it to fit in about 190–210 logic cells. I haven't synthesized it, so that number is an estimate. Inputs, outputs, coefficients, reset, latency and throughput are unchanged, and the output matches the baseline bit for bit.

## Optimized RTL

```systemverilog
// ffe5tap_pam4 — area-optimized for iCE40 UP5K (no SB_MAC16, no BRAM)
// Function is bit-identical to the baseline:
//   y[n+1] = sat12( (C0*x[n] + C1*x[n-1] + C2*x[n-2] + C3*x[n-3] + C4*x[n-4]) >>> 10 )
//   C = {-41, 1097, -602, 29, 45}  (Q1.10), x/y Q3.8, sync active-low reset,
//   1 sample/cycle, 1-cycle latency.
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // ------------------------------------------------------------------
    // 1) Multiple-constant multiplication of x_in (shared shift-add graph)
    //    All operands are signed, so each operand is sign-extended to the
    //    LHS width before the shift (IEEE 1800 context sizing).
    //    Widths are the exact minimum for x in [-2048, 2047].
    // ------------------------------------------------------------------
    logic signed [17:0] m33;    //   33x  in [-67584,   67551]
    logic signed [17:0] m41;    //   41x  in [-83968,   83927]
    logic signed [17:0] m45;    //   45x  in [-92160,   92115]
    logic signed [16:0] m29;    //   29x  in [-59392,   59363]
    logic signed [20:0] m301;   //  301x  in [-616448,  616147]
    logic signed [22:0] m1097;  // 1097x  in [-2246656, 2245559]

    assign m33   = x_in + (x_in <<< 5);    //   33 = 1 + 32
    assign m41   = m33  + (x_in <<< 3);    //   41 = 33 + 8
    assign m45   = m41  + (x_in <<< 2);    //   45 = 41 + 4
    assign m29   = m45  - (x_in <<< 4);    //   29 = 45 - 16 (fits 17b exactly)
    assign m301  = m45  + (x_in <<< 8);    //  301 = 45 + 256  (602 = 301<<1)
    assign m1097 = (m33 <<< 5) + m41;      // 1097 = 33*32 + 41

    // ------------------------------------------------------------------
    // 2) Transposed-form accumulation chain (exact minimum widths)
    // ------------------------------------------------------------------
    logic signed [17:0] s4;     //  45x[n-1]                         18b
    logic signed [18:0] s3;     //  |.| <= 151552                   19b
    logic signed [21:0] s2;     //  |.| <= 1383846                  22b
    logic signed [22:0] s1;     //  |.| <= 3630502                  23b

    logic signed [22:0] acc;    //  [-3714429, 3713901]             23b
    assign acc = s1 - m41;      //  + C0*x[n],  C0 = -41

    // ------------------------------------------------------------------
    // 3) Saturation: acc>>>10 is a 13-bit value acc[22:10].
    //    It fits in 12 bits  <=>  acc[22] == acc[21].
    //    This is exactly the baseline's  >2047 / < -2048  clamp.
    // ------------------------------------------------------------------
    logic               ovf;
    logic signed [11:0] y_sat;
    assign ovf   = acc[22] ^ acc[21];
    assign y_sat = ovf ? {acc[22], {11{~acc[22]}}} : acc[21:10];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s4    <= '0;
            s3    <= '0;
            s2    <= '0;
            s1    <= '0;
            y_out <= '0;
        end else begin
            s4    <= m45;                   // + C4*x
            s3    <= s4 + m29;              // + C3*x
            s2    <= s3 - (m301 <<< 1);     // + C2*x   (-602x)
            s1    <= s2 + m1097;            // + C1*x
            y_out <= y_sat;
        end
    end

endmodule
```

## Architectural changes

**1. Direct form changed to transposed form.**
- In the baseline, each coefficient multiplies a different delayed sample (`x_in`, `x1`…`x4`). Because the inputs differ, no multiplier logic can be shared between taps.
- In transposed form, every product is taken of `x_in` only. The registers hold partial sums instead of past samples.
- That turns the problem into multiplying one input by 5 constants, where intermediate results are shared.
- **Reset and latency are unchanged.** Resetting `s1`–`s4` to 0 is the same as the baseline clearing `x1`–`x4` to 0. Both designs then produce the same outputs on every cycle after reset is released. `acc` is still combinational from `x_in`, and `y_out` is the only register on the output path, so latency is still 1 cycle.

**2. Shift-add constant multipliers using the minimum number of adders.**
- None of the 5 coefficient magnitudes (41, 1097, 301, 29, 45) is of the form 2^i ± 2^j. So each needs at least one adder, plus at least one intermediate value they can share. The lower bound is 6 adders.
- Using 33x as the shared intermediate reaches that bound:
  - 41 = 33 + 8
  - 45 = 41 + 4
  - 29 = 45 − 16
  - 301 = 45 + 256 (and 602 = 301 << 1)
  - 1097 = 33·32 + 41
- With 9x as the intermediate, 7 adders are needed. With per-tap canonical signed-digit (CSD) coding, 14 are needed.
- Shift amounts were picked to be large where possible, because the low bits of a shifted operand pass through without logic. That keeps the total number of adder bits low (about 88 cells for the multiplication network).
- The 4 adders in the accumulation chain can't be avoided with 5 taps.

**3. Exact minimum widths.**
- The baseline's 24/28-bit widths far exceed the real range. The worst case of `acc` is [−3714429, 3713901], which fits in 23 bits. Every intermediate signal uses its exact required width (ranges are in the comments). Nothing is truncated, so the result is exact.
- The low 10 bits are still computed. Their carry into bit 10 changes the result, so dropping them would change the function.

**4. Saturation reduced to 1 LUT per output bit.**
- After the shift, the value is 13 bits wide. Overflow means exactly that bit 12 differs from bit 11.
- The baseline's two signed 28-bit comparisons become one XOR plus a 2:1 mux on each output bit.
- Each output bit is one 3-input LUT, packed into the same logic cell as its `y_out` flip-flop.

**5. Fitted to the iCE40 logic cell.**
- An iCE40 logic cell has one 4-input LUT, one carry cell and one flip-flop.
- In the baseline, the 48 delay-line flip-flops have no LUT driving them, so each one takes a whole logic cell.
- In this version, almost every register is fed directly by an adder bit, so it packs into that adder's logic cell for free. Only s4[1:0] and s2[0] need pass-through cells.
- There are no `*` operators, so yosys cannot infer SB_MAC16 blocks or array multipliers.

## Expected resources (UP5K: 5280 logic cells, 8 SB_MAC16)

| | Baseline (no `-dsp`) | Baseline (`-dsp`) | Optimized |
|---|---|---|---|
| SB_MAC16 | 0 | 5 of 8 | **0** |
| Logic cells | several hundred (generic signed array multipliers; −41 and −602 have many 1-bits in two's complement; 28-bit adders/comparators) | ~150–250 (28-bit adder tree, saturation, delay line) | **~190–210** |
| Flip-flops | 60 | 60 | 94 (nearly all packed with adder LUTs) |
| BRAM | 0 | 0 | 0 |

Rough breakdown for the optimized design:
- Constant multipliers: about 88 cells.
- Accumulation chain: about 66 cells.
- `acc` adder: about 24 cells. Its low 10 bits exist only to produce the carry, but each carry cell still occupies a logic cell.
- Saturation plus output register: 12 cells.

## Tradeoffs

- **More flip-flops (94 vs. 60)** in exchange for far less logic. On iCE40 these flip-flops almost never cost extra logic cells. On an architecture where flip-flops can't be packed with LUTs, this trade would look worse.
- **Uses no DSP blocks.** If your metric treats DSPs as free, the `-dsp` baseline can use fewer logic cells, but it consumes 5 of the 8 MACs. This version leaves all 8 free and holds up when there's contention.
- **Timing.** The longest path chains 5 short ripple-carry adders: `x_in` → m33 → m41 → m45 → m301 → s2. The output path chains 4: `x_in` → m33 → m41 → `acc` → saturation. Both should beat the baseline's 28-bit compare path, but check them against your clock target in nextpnr.
- **Input fanout.** `x_in` fans out to 6 adders, which the router handles easily at this size.

## Verification

Before signing off, I'd confirm three things:
1. **Equivalence.** Build a miter of baseline vs. this version in SymbiYosys. Either check it with bounded model checking from reset for 8 or more cycles, or with k-induction at k ≥ 5 (both designs' state depends only on the last 4 inputs). Also run random and corner simulation with all-+2047 and all-−2048 inputs to exercise both saturation rails.
2. **Area.** Compare the cell counts in `synth_ice40 -top ffe5tap_pam4; stat`, since the numbers above are estimates.
3. **Timing.** Check the clock target in nextpnr-ice40.
