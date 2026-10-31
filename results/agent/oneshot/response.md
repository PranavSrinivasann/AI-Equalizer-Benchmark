# Minimum-LUT 5-tap FFE for iCE40 UP5K

I didn't synthesize or simulate this, so all resource figures below are hand estimates. Please run Yosys `stat` and an equivalence check before relying on them.

## Optimized RTL

```systemverilog
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);
    // Coefficients (documentation only; hard-wired as shift/add below):
    //   C0=163  = 5*32 + 3
    //   C1=-417 = -(13*32 + 1)
    //   C2=782  = 2*(3*128 + 7)
    //   C3=-1268= -(5*256 - 3*4)
    //   C4=1536 = 3*512

    // ---------------- Shared multiples of x_in (MCM) ----------------
    logic signed [13:0] t3;    //  3x   (+-6144)
    logic signed [14:0] t5;    //  5x   (+-10240)
    logic signed [14:0] k7;    //  7x   (+-14336)
    logic signed [15:0] k13;   // 13x   (+-26624) = 10x + 3x

    assign t3  = x_in + (x_in <<< 1);
    assign t5  = x_in + (x_in <<< 2);
    assign k7  = (x_in <<< 3) - x_in;
    assign k13 = (t5 <<< 1) + t3;

    // ---------------- Transposed-form state (LSBs that are always 0 are not stored) -------
    logic signed [13:0] r4;    // s4 = 1536*x[n-1]   = r4 << 9
    logic signed [21:0] s3q;   // s3 = s3q << 2      (|s3| <= 5.74M)
    logic signed [22:0] s2h;   // s2 = s2h << 1      (|s2| <= 7.34M)
    logic signed [23:0] s1;    // s1                 (|s1| <= 8.20M)

    logic signed [21:0] s3q_n;
    logic signed [22:0] s2h_n;
    logic signed [23:0] s1_n;
    logic signed [24:0] acc;   // |acc| <= 8.53M > 2^23, so 25 bits are required

    // s3 = s4 - 1268x         in units of 4: 128*r4 + (3x - 64*5x) = ... -317x
    assign s3q_n = (r4  <<< 7) + (t3 - (t5 <<< 6));
    // s2 = s3 + 782x          in units of 2: 2*s3q + 384x + 7x
    assign s2h_n = (s3q <<< 1) + (t3 <<< 7) + k7;
    // s1 = s2 - 417x          = s2 - 13x*32 - x
    assign s1_n  = (s2h <<< 1) - (k13 <<< 5) - x_in;
    // y  = 163x + s1          = 5x*32 + 3x + s1
    assign acc   = (t5 <<< 5) + t3 + s1;

    // ---------------- Exact saturation of acc >>> 10 to 12 bits ----------------
    // acc[24:10] is the shifted value; it fits 12 bits iff acc[24:21] are all equal.
    logic ovf;
    logic signed [11:0] y_next;
    assign ovf = (acc[24:21] != 4'b0000) && (acc[24:21] != 4'b1111);
    assign y_next[11]   = acc[24];                       // sign is correct in all cases
    assign y_next[10:0] = ovf ? {11{~acc[24]}} : acc[20:10];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            r4    <= '0;
            s3q   <= '0;
            s2h   <= '0;
            s1    <= '0;
            y_out <= '0;
        end else begin
            r4    <= t3;
            s3q   <= s3q_n;
            s2h   <= s2h_n;
            s1    <= s1_n;
            y_out <= y_next;
        end
    end
endmodule
```

## What changed

1. **No multipliers.** Every constant is a short shift-add recipe. Yosys's default constant-multiply mapping uses plain binary partial products, which cost 21 terms for these coefficients. My recipes use 3x, 5x, 7x and 13x.

2. **Transposed form with multiple-constant multiplication.** All five taps now multiply the same input, `x_in`. That lets the products share `3x` and `5x`, which a direct-form tap, fed by a different delayed sample each time, cannot do. The whole filter needs 12 adders instead of about 17 or more.

3. **Delay line replaced by partial sums.**
   - `x1..x4` (48 FFs) are gone.
   - The partial sums `s1..s4` hold the same history. They reset to zero exactly as the delay line did, so reset behavior and the first outputs match the baseline.
   - Timing is unchanged: `y_out <= sat(163·x[n] + s1)`, with `s1` holding the other four taps, giving 1 sample/cycle and 1-cycle latency.

4. **Minimum bit widths, proven from coefficient sums.**
   - The baseline used 28-bit accumulation. The true bound is 2047·2481 + 2048·1685 = 8,529,487, which exceeds 2^23, so 25 bits are needed. 24 bits would be wrong for some inputs.
   - Each partial sum is sized from its own bound (24, 23, 22 and 14 bits). Bits that are always zero are not stored: s2 is always even, s3 is always a multiple of 4, and s4 is 3x<<9.

5. **Cheap saturation.**
   - Overflow is detected from `acc[24:21]` with one LUT4.
   - `y[11]` is simply `acc[24]`.
   - Each of the other 11 output bits is a 3-input LUT, packed with its output FF.
   - The sync reset uses the LC's built-in set/reset input. It costs one shared inverter for the active-low `rst_n`.

6. **FFs packed into adder LCs.** Each accumulator register sits in the same logic cell as its final adder's carry-chain bit, so the extra state costs almost no extra cells.

## Expected tradeoffs (estimates, unverified)

| | Baseline, LUT mapping | This design |
|---|---|---|
| Multipliers | 5 constant multiplies via binary partial products | 0 |
| Adders | about 25 wide (up to 28-bit) | 12, widths trimmed |
| FFs | 60 | about 95 |
| LCs | roughly 650–750 | roughly 230–250 |

- LC count should drop by about two thirds. FF count rises by about 35, but most of those FFs share cells with adders.
- Fmax is lower. The critical path is `x_in` → 5x → +3x → +s1 → saturation → `y_out`, which is about three chained carry chains. You can't pipeline it without breaking the 1-cycle latency requirement, so this is the floor for this form.
- If your clock target is tight, tell me and I'll look at it.
- If you only care about LCs, not DSP blocks, this beats `synth_ice40 -dsp`. DSP inference would use 5 of the 8 SB_MAC16 blocks and almost no LUTs. Choose that route only if DSPs are free in your design.

## Verification to run

- Check the Yosys `stat` output. The zero-LSB adders (for example `t3<<7 + k7`) should show reduced widths. If they don't, split the low bits out manually as pass-through wires.
- Run an equivalence check or random simulation against the baseline. Include rail-to-rail inputs such as -2048 and 2047 held for 5 cycles, which hit the 25-bit worst case, and a mid-stream reset.
