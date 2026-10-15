# Optimized iCE40 UP5K FFE

## Optimized RTL

```systemverilog
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Delay line (12-bit, same as baseline)
    logic signed [11:0] x1, x2, x3, x4;

    // Output register: only 11 bits are needed (see bound proof below)
    logic signed [10:0] y_q;

    // ------------------------------------------------------------------
    // acc = 73*x0 - 121*x1 + 89*x2 + 146*x3 - 57*x4
    //     = 73*S + 16*x2 + 7*B - 64*T
    //   S = x0 + x2 + 2*x3        (146 = 2*73, 89 = 73 + 16)
    //   B = x1 + x4
    //   T = 2*x1 + x4             (-121 = -128 + 7, -57 = -64 + 7)
    // ------------------------------------------------------------------
    (* keep *) logic signed [13:0] s;      // |S| <= 8192
    (* keep *) logic signed [12:0] b;      // |B| <= 4096
    (* keep *) logic signed [13:0] t;      // |T| <= 6144

    assign s = x_in + x2 + (x3 <<< 1);
    assign b = x1 + x4;
    assign t = (x1 <<< 1) + x4;

    // All partial results are modulo 2^21; the true sum fits in 21 bits,
    // so the final value is exact.
    (* keep *) logic signed [20:0] s9;     // 9*S
    (* keep *) logic signed [20:0] s73;    // 73*S
    (* keep *) logic signed [20:0] b7;     // 7*B
    (* keep *) logic signed [20:0] r0;     // 16*x2 - 64*T
    (* keep *) logic signed [20:0] r1;     // 7*B + 16*x2 - 64*T
    logic signed [20:0] acc;

    assign s9  = (s  <<< 3) + s;
    assign s73 = (s  <<< 6) + s9;
    assign b7  = (b  <<< 3) - b;
    assign r0  = (x2 <<< 4) - (t <<< 6);
    assign r1  = b7 + r0;
    assign acc = s73 + r1;

    // ------------------------------------------------------------------
    // Saturation removed: provably unreachable (see below).
    // y = acc >>> 10 is in [-972, 971], i.e. acc[20:10] is exact.
    // ------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1  <= 12'sd0;
            x2  <= 12'sd0;
            x3  <= 12'sd0;
            x4  <= 12'sd0;
            y_q <= 11'sd0;
        end else begin
            x4  <= x3;
            x3  <= x2;
            x2  <= x1;
            x1  <= x_in;
            y_q <= acc[20:10];
        end
    end

    assign y_out = {y_q[10], y_q};   // sign-extend; no 12th flop

endmodule
```

## Architectural changes

**1. Saturation logic removed, because it cannot fire.**
- The worst case over the full 12-bit input range (not just PAM4 levels) is:
  - Max: positive-coefficient taps at 2047, negative-coefficient taps at -2048. That gives 2047·308 + 2048·178 = 995,020, and `>>> 10` gives +971.
  - Min: the opposite assignment gives -995,150, and `>>> 10` (floor) gives -972.
- Both are well inside [-2048, 2047], so the two 28-bit comparators and the output mux in the baseline are dead logic.
- Output behavior is bit-identical for every possible input sequence.
- If you ever change a coefficient, redo this bound check.

**2. Accumulator narrowed from 28 bits to 21 bits.**
- The exact sum needs at most 21 signed bits (|acc| ≤ 995,328 < 2²⁰).
- Two's-complement wraparound in the intermediate adds is harmless because the final value fits.
- The baseline carries 28-bit adds and a 24-bit product for every tap.

**3. The five multipliers become shift-add logic with shared subexpressions.**
- A naive CSD decomposition needs about 16 terms and 15 adders. This version needs 10 two-input adders, all on the iCE40 carry chain at one LUT per bit:
  - 146 = 2·73 and 89 = 73 + 16, so x0, x2 and x3 share one ×73 multiplication on S = x0 + x2 + 2·x3.
  - 121 = 128 − 7 and 57 = 64 − 7, so x1 and x4 share ×7 on B = x1 + x4, plus a cheap 64·T term.
- The adders are written as separate `(* keep *)` signals so yosys doesn't merge them into a `$macc` and map it to a LUT-based compressor tree. Without that, the carry-chain advantage can be lost.
- The tree is balanced to about 5 adder levels instead of an 8-term serial chain. The adder count is unchanged, so this helps timing at no area cost.

**4. Output register reduced to 11 flops.**
- Since y ∈ [-972, 971], bit 11 always equals bit 10.
- It's driven by a continuous `assign` from the same flop, saving a flop with identical behavior.

**5. Reset is unchanged.**
- The iCE40 logic cell has a built-in synchronous reset on its flop (`SB_DFFSR`), so the active-low sync reset costs no extra LUTs.
- I kept it on all delay stages and the output register to preserve post-reset behavior exactly.

## Resource tradeoffs

These are my own estimates. I haven't run synthesis, so please check with `yosys -p "synth_ice40 -top ffe5tap_pam4; stat"`.

| | Baseline | This design |
|---|---|---|
| Multipliers | 5 (LUT-mapped, or 5 `SB_MAC16` with `-dsp`) | 0 |
| DSP blocks | 0 or 5 | 0 |
| Adder width | 28-bit | 14 / 13 / 21-bit |
| Saturation compare + mux | yes | none |
| Flops | 60 | 59 |
| LUT4 | high (hundreds) | roughly 150 |

- **Fmax:** The design is purely combinational between registers, and 1-cycle latency rules out pipelining, so it's an area-first design. Expect Fmax in the tens of MHz on the UP5K. If the target clock is tight, check timing before assuming it closes.
- **DSP alternative:** Instantiating `SB_MAC16` blocks would bring LUT use near zero, but it costs 5 of the 8 DSPs on the chip. For minimum logic with DSPs left free for other uses, the shift-add version is the better trade. If DSPs are free and LUTs are the scarce resource, the DSP version wins on LUT count.
- **Input-range assumption:** I assumed the full 12-bit signed range. If the input is guaranteed to be only PAM4 levels, further savings are possible, but that would change the "preserve exactly" contract, so I didn't take them.

## Equivalence check

Because the claims above are bound arguments, run a cycle-accurate comparison against the baseline (renamed `ffe5tap_ref`), including extreme-value stimulus:

```systemverilog
module tb;
    logic clk = 0, rst_n = 0;
    logic signed [11:0] x;
    wire  signed [11:0] y_a, y_b;
    ffe5tap_ref  ref_i (clk, rst_n, x, y_a);
    ffe5tap_pam4 dut_i (clk, rst_n, x, y_b);
    always #5 clk = ~clk;

    int errors = 0;
    initial begin
        x = 0; repeat (3) @(posedge clk); rst_n = 1;
        repeat (2_000_000) begin
            @(negedge clk);
            case ($urandom_range(0, 3))
                0: x = $urandom;                          // random
                1: x = 12'sd2047;                         // extremes
                2: x = -12'sd2048;
                3: x = ($urandom_range(0,1)) ? 12'sd2047 : -12'sd2048;
            endcase
            if ($urandom_range(0, 9999) == 0) rst_n = 0; else rst_n = 1;
        end
        $display("errors = %0d", errors);
        $finish;
    end
    always @(posedge clk) begin
        #1;
        if (y_a !== y_b) begin errors++; $display("MISMATCH t=%0t %0d vs %0d", $time, y_a, y_b); end
    end
endmodule
```

Also worth a directed run that places the min/max-producing 5-sample patterns (e.g. +2047/-2048 assigned per the coefficient signs) to confirm the ±971/-972 extremes.