# Area-optimized 5-tap FFE for the iCE40 UP5K: transposed form with shared shift-add constant multipliers

I haven't synthesized this. The logic-cell (LC) counts below are estimates; check them with `yosys synth_ice40; stat` and the nextpnr utilization report. Exactness is argued step by step below, and the last section shows how to prove equivalence formally.

## Optimized RTL

```systemverilog
// ffe5tap_pam4 -- area-optimized for iCE40 UP5K (LC-only, 0 DSP, 0 BRAM)
//
// Bit-exact with the baseline:
//   y[n] = sat12( (13*x[n] + 1020*x[n-1] - 294*x[n-2] - 13*x[n-3] + 29*x[n-4]) >>> 10 )
// registered once (1-cycle latency, 1 sample/cycle), synchronous active-low reset.
//
// Architecture:
//   * Transposed-form FIR: only the CURRENT sample is multiplied; partial sums
//     s4..s1 are registered instead of x[n-1..n-4].
//   * Shared constant-multiplier block (MCM), CSD/shift-add, 4 narrow adders:
//       3x = 2x + x,  13x = 4*3x + x,  19x = 16x + 3x,  147x = 128x + 19x
//     plus  29x = 16x + 13x,  294x = 2*147x,  1020x = 1024x - 4x  folded into
//     the partial-sum adders.  -13x reuses +13x (C0 = -C3).
//   * Every adder starts at the first bit where both operands are non-zero.
//     Trailing-zero LSBs are wired through with explicit concatenations, so no
//     carry cells are spent on them.
//   * The true accumulator range is +/-2.80e6 < 2^22, so 23 bits are exact.
//     (The baseline used 28 bits.)
//   * The saturation uses a 13-bit overflow test and maps onto the final
//     adder's spare LUT input plus the FF's synchronous reset.

module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Coefficients (unchanged, Q1.10), realized as shift-add:
    //   C0 = 13, C1 = 1020, C2 = -294, C3 = -13, C4 = 29

    // ------------------------------------------------------------------
    // Declarations
    // ------------------------------------------------------------------
    // Shared multiples of the current sample x_in
    logic signed [12:0] m3_hi;     // (3x)   >>> 1
    logic signed [13:0] m3;        //  3x    : 14 b
    logic signed [13:0] m13_hi;    // (13x)  >>> 2
    logic signed [15:0] m13;       //  13x   : 16 b
    logic signed [12:0] m19_hi;    // (19x)  >>> 4
    logic signed [16:0] m19;       //  19x   : 17 b
    logic signed [12:0] m147_hi;   // (147x) >>> 7
    logic signed [19:0] m147;      //  147x  : 20 b

    // Transposed partial-sum registers (exact natural widths)
    logic signed [16:0] s4;        //  29x[n-1]
    logic signed [17:0] s3;        // -13x[n-1] + 29x[n-2]
    logic signed [20:0] s2;        // -294x[n-1] - 13x[n-2] + 29x[n-3]
    logic signed [22:0] s1;        // 1020x[n-1] - 294x[n-2] - 13x[n-3] + 29x[n-4]

    logic signed [12:0] s4_hi;
    logic signed [16:0] s4_d;
    logic signed [17:0] s3_d;
    logic signed [19:0] s2_hi;
    logic signed [20:0] s2_d;
    logic signed [18:0] w_hi;      // (s2 - 4x) >>> 2
    logic signed [12:0] s1_hi;     // (s2 - 4x + 1024x) >>> 10
    logic signed [22:0] s1_d;

    logic signed [22:0] acc;       // full exact sum (fits in 23 b)
    logic               pos_ovf, neg_ovf;
    logic               y_msb;
    logic        [10:0] y_lsb;

    // ------------------------------------------------------------------
    // Shared constant multiplier block (current sample only)
    // ------------------------------------------------------------------
    // 3x = 2x + x            -> bit 0 = x[0]
    assign m3_hi   = x_in + (x_in >>> 1);
    assign m3      = {m3_hi, x_in[0]};

    // 13x = 4*(3x) + x       -> bits [1:0] = x[1:0]
    assign m13_hi  = m3 + (x_in >>> 2);
    assign m13     = {m13_hi, x_in[1:0]};

    // 19x = 16x + 3x         -> bits [3:0] = 3x[3:0]
    assign m19_hi  = x_in + (m3 >>> 4);
    assign m19     = {m19_hi, m3[3:0]};

    // 147x = 128x + 19x      -> bits [6:0] = 19x[6:0]
    assign m147_hi = x_in + (m19 >>> 7);
    assign m147    = {m147_hi, m19[6:0]};

    // ------------------------------------------------------------------
    // Transposed-form tap adders (next-state of partial-sum registers)
    // ------------------------------------------------------------------
    // tap 4:  s4' = 29x = 16x + 13x            -> bits [3:0] = 13x[3:0]
    assign s4_hi = x_in + (m13 >>> 4);
    assign s4_d  = {s4_hi, m13[3:0]};

    // tap 3:  s3' = s4 - 13x
    assign s3_d  = s4 - m13;

    // tap 2:  s2' = s3 - 294x = s3 - 2*147x    -> bit 0 = s3[0]
    assign s2_hi = (s3 >>> 1) - m147;
    assign s2_d  = {s2_hi, s3[0]};

    // tap 1:  s1' = s2 + 1020x = (s2 - 4x) + 1024x
    //         bits [1:0] = s2[1:0], bits [9:0] = (s2 - 4x)[9:0]
    assign w_hi  = (s2 >>> 2) - x_in;
    assign s1_hi = (w_hi >>> 8) + x_in;
    assign s1_d  = {s1_hi, w_hi[7:0], s2[1:0]};

    // tap 0:  acc = s1 + 13x   (exact, |acc| <= 2,803,405 < 2^22)
    assign acc   = s1 + m13;

    // ------------------------------------------------------------------
    // Saturation: shifted = acc[22:10] always fits in 13 bits, so
    //   overflow <=> acc[22] != acc[21]
    //   y[11]    = acc[22] in every case
    //   y[10:0]  = pos_ovf ? all-ones : neg_ovf ? all-zeros : acc[20:10]
    // ------------------------------------------------------------------
    assign pos_ovf = ~acc[22] &  acc[21];
    assign neg_ovf =  acc[22] & ~acc[21];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s4    <= '0;
            s3    <= '0;
            s2    <= '0;
            s1    <= '0;
            y_msb <= 1'b0;
        end else begin
            s4    <= s4_d;
            s3    <= s3_d;
            s2    <= s2_d;
            s1    <= s1_d;
            y_msb <= acc[22];
        end
    end

    // Negative saturation and reset both force zero, so they share the FF's
    // synchronous-reset pin (SB_DFFSR). Positive saturation is an OR that fits
    // in the spare input (I0) of the final adder's sum LUT.
    always_ff @(posedge clk) begin
        if (!rst_n || neg_ovf)
            y_lsb <= '0;
        else
            y_lsb <= acc[20:10] | {11{pos_ovf}};
    end

    assign y_out = {y_msb, y_lsb};

endmodule
```

## Architectural changes

**1. Direct form changed to transposed form.** In the baseline, each of the 48 delay-line flip-flops (x1..x4) uses a whole iCE40 logic cell, because a cell's flip-flop can only capture its own LUT output. In the transposed form, the registers s4..s1 hold partial sums, and each one is fed by the adder that computes it. That flip-flop sits in the same logic cell as the adder bit, so it costs almost nothing.

Cycle and reset equivalence:
- s1[n] = 1020x[n-1] − 294x[n-2] − 13x[n-3] + 29x[n-4]
- y[n+1] = sat(13x[n] + s1[n])
- Resetting s1..s4 to 0 is the same state as the baseline's zeroed x1..x4.

**2. Shared shift-add multipliers.** All five products now come from the current sample only, so they can share one multiplier block:

| Coefficient | Realization | Extra adders |
|---|---|---|
| 13 | 4·(3x) + x | 1 (+1 for 3x, shared) |
| −13 | reuses 13x, subtracted in tap 3 | 0 |
| 29 | 16x + 13x | 1 (forms the s4 next-state) |
| −294 | −2·(128x + 16x + 3x) | 2 |
| 1020 | 1024x − 4x, folded into the tap-1 sum | 2 (13-bit and 19-bit) |

- **Total:** 10 two-input adders of 13 to 23 bits.
- **Baseline:** five generic 12×12 multipliers producing more than 20 shifted partial products, then a 28-bit five-operand sum.

**3. Trailing zeros are wired, not added.** Every shifted operand (`<<1`, `<<2`, `<<4`, `<<7`, `<<10`) is written as an explicit concatenation. Each adder only spans the bits where both operands can be non-zero; for example, the "+1024x" adder is only 13 bits. This doesn't depend on the synthesizer spotting constant-zero bits.

**4. Exact width trimming.** These are worst-case ranges, not approximations, so no precision is lost:

| Signal | Range | Width |
|---|---|---|
| 3x | ±6144 | 14 bits |
| 13x | ±26624 | 16 bits |
| 29x | ±59392 | 17 bits |
| s3 | ±86003 | 18 bits |
| s2 | ±688128 | 21 bits |
| s1 | ±2777088 | 23 bits |
| acc | [−2803405, 2802650] | 23 bits |

So `acc >>> 10` lies in [−2738, 2736] and always fits in 13 bits. Bits 23 to 27 of the baseline accumulator were pure sign extension. Each split such as `{(a>>>k) ± b, a[k-1:0]}` is exactly a ± b·2^k, because adding a multiple of 2^k leaves the low k bits unchanged.

**5. Cheaper saturation.** Because `shifted` fits in 13 bits, the two 28-bit comparisons reduce to `acc[22] ^ acc[21]`.
- y[11] always equals acc[22].
- Positive overflow is an OR, which uses the spare LUT input on the final adder's sum bits.
- Negative overflow forces zero, which merges with reset on the flip-flop's synchronous-reset pin.
- The result is about 3 extra logic cells instead of about 12 LUTs plus two wide comparators.
- Reset still has priority and still gives y_out = 0.

## Expected resources (estimate)

| Block | Logic cells |
|---|---|
| 3x / 13x / 19x / 147x | 13 + 14 + 13 + 13 |
| s4 (29x), including 4 flip-flop-only LSB cells | 17 |
| s3 | 18 |
| s2, including 1 flip-flop-only cell | 21 |
| s1 (two adders + 2 flip-flop-only cells) | 34 |
| Final 23-bit adder (y[10:0] flip-flops packed) | 23 |
| Saturation, reset inverter, y[11] | ~4 |
| **Total** | **~170 logic cells, 0 SB_MAC16, 0 BRAM** |

- **Flip-flops:** 91 (60 in the baseline), but about 83 of them share a logic cell with an adder bit.
- **Baseline without `-dsp`:** usually several hundred logic cells. The generic multipliers expand into many partial products, the accumulator is 28 bits wide, and the 48 delay flip-flops need their own cells.
- **Baseline with `-dsp`:** 5 of the 8 SB_MAC16 blocks, plus a wide adder tree and the 48 delay flip-flops.

## Tradeoffs and caveats

- **Timing:** the combinational path is longer: x_in → 3x → 13x → 23-bit final add → saturation. That's three ripple chains, which is fine at typical PAM4 benchmark clock rates on a UP5K. If fmax ever matters, you'd have to pay with area or latency, and latency is fixed here.
- **More flip-flops, fewer logic cells:** this only wins because iCE40 adders and flip-flops pack together. On a part where flip-flops are the scarce resource, the trade would look different.
- **Ripple adders, not carry-save:** on iCE40 a ripple-carry adder costs 1 logic cell per bit, while a 3:2 compressor costs 2 LUTs per bit. So a chain of two-input carry adders is cheapest.
  - Yosys `alumacc` can sometimes merge single-fanout add chains into a multi-operand `$macc`, mapped to carry-save adders.
  - Check the synthesis log and `stat`. If it merged, mark the intermediate `*_hi` wires `(* keep *)`.
- **Saturation trick:** it relies on Yosys inferring `SB_DFFSR` from `!rst_n || neg_ovf` and on `opt_lut` folding the OR into the sum LUT. If either doesn't happen, the result is still correct and costs about 11 more LUTs.
- **DSPs stay free:** all 8 SB_MAC16 blocks are left for the next phase of the design. Spending DSPs on constant coefficients is the less efficient use of the device.

## Verifying exactness

- **Method:** build a miter against the baseline. Run `miter -equiv -flatten`, then `sat -seq 8 -prove-asserts` with rst_n asserted in cycle 1 and left free afterwards.
- **Why this is a complete proof:** in both designs the output depends only on the last 5 inputs and on reset events within that window, so a bounded check of about 6 or more cycles from reset covers every reachable case.
