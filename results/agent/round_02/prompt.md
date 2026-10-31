You are one round of an iterative hardware-optimization loop. Each round you receive the
current state of the search and return an improved SystemVerilog design. Your design is then
checked automatically and the results are fed back to you in the next round.

## The design

A 5-tap FIR equalizer for a PAM4 receiver, fixed coefficients, one sample per clock.

```
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,       // synchronous, active low
    input  logic signed [11:0] x_in,        // Q3.8
    output logic signed [11:0] y_out        // Q3.8
);
```

Reference function (c0 multiplies the newest sample):

    y_out[n+1] = sat12( (c0*x[n] + c1*x[n-1] + c2*x[n-2] + c3*x[n-3] + c4*x[n-4]) >>> 10 )

with Q1.10 coefficients c = [163, -417, 782, -1268, 1536], arithmetic right shift,
saturation to [-2048, 2047], one cycle of latency, and a reset that clears the sample history
and the output register to zero. The port list, module name, coefficients, tap count, one
sample per clock and one cycle of latency are fixed.

## Target and checks

Target: an iCE40 UP5K FPGA (Yosys synth_ice40, nextpnr-ice40). The goal is a design with fewer
logic cells and a higher Fmax than the starting point.

Your design must pass all three gates to count:

- **G1** it compiles in Verilator and synthesizes in Yosys.
- **G2** directed tests (power-up reset, mid-stream reset, constant and alternating extreme
  inputs, worst-case accumulation, PAM4 levels, random full-range inputs): every cycle with
  `rst_n` low must output exactly 0, and every output must be within 8 LSB (8/256 in Q3.8) of
  the reference function above.
- **G3** on a simulated 200G PAM4 link, the bit-error rate and the symbol-error rate measured
  through your RTL must both be at most 2e-4 (the exact reference gives about 8e-6).

Exact bit-for-bit equality with the reference is not required. G2 and G3 are what count, so
an approximation is allowed if it passes them. Typical inputs in this link have an RMS of about
440 codes (1.7 in real units). The PAM4 decision slicer after your output uses thresholds at
0 and about +-445 codes, and the nominal output levels are about +-223 and +-668 codes.

Score (lower is better, valid designs only):

    score = (logic_cells / 571) * sqrt(24.8 / Fmax_MHz)

A score of 1.0 is a hand-written canonical-signed-digit shift-add design (571 logic cells,
24.8 MHz). The iCE40 logic cell holds one 4-input LUT, one carry cell and one flip-flop; a
flip-flop that is fed directly by a LUT or carry adder shares that cell, while a flip-flop with
no logic in front of it takes a whole cell of its own.

## How to answer

Return exactly this, with no tools and no files:

1. One fenced ```systemverilog code block containing the complete module.
2. A line `CHANGE SUMMARY:` followed by at most three short lines describing what you changed.
3. A line `HYPOTHESIS:` with one line saying what you expect the change to do to logic cells and Fmax.

Design one coherent change per round rather than many unrelated ones, so the feedback tells
you what worked. If the last attempt failed a gate, fix that first.

## Round 2 of 8

### All attempts so far

| round | result | logic cells | Fmax MHz | score | your change summary |
|---|---|---|---|---|---|
| 1 | FAILED G2 | - | - | - | - Replaced the generic multipliers with CSD shift-add constants (4, 4, 4, 4 and 2 terms). - Switched from direct form to transposed form. The sample delay line becomes partial-sum registers, so the critical path is one constant... |

No valid design yet. The starting design is below.

```systemverilog
// 802.3dj loss30 baseline FFE. Coefficients [163, -417, 782, -1268, 1536] (Q1.10).
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    localparam signed [11:0] C0 = 12'sd163;
    localparam signed [11:0] C1 = -12'sd417;
    localparam signed [11:0] C2 = 12'sd782;
    localparam signed [11:0] C3 = -12'sd1268;
    localparam signed [11:0] C4 = 12'sd1536;

    logic signed [11:0] x1, x2, x3, x4;
    logic signed [23:0] p0, p1, p2, p3, p4;

    assign p0 = x_in * C0;
    assign p1 = x1   * C1;
    assign p2 = x2   * C2;
    assign p3 = x3   * C3;
    assign p4 = x4   * C4;

    logic signed [27:0] p0_ext, p1_ext, p2_ext, p3_ext, p4_ext;
    assign p0_ext = p0;
    assign p1_ext = p1;
    assign p2_ext = p2;
    assign p3_ext = p3;
    assign p4_ext = p4;

    logic signed [27:0] acc;
    assign acc = p0_ext + p1_ext + p2_ext + p3_ext + p4_ext;

    logic signed [27:0] shifted;
    assign shifted = acc >>> 10;

    localparam signed [27:0] MAX_12 = 28'sd2047;
    localparam signed [27:0] MIN_12 = -28'sd2048;

    logic signed [11:0] y_sat;

    always_comb begin
        if (shifted > MAX_12)
            y_sat = 12'sd2047;
        else if (shifted < MIN_12)
            y_sat = -12'sd2048;
        else
            y_sat = shifted[11:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1    <= 12'sd0;
            x2    <= 12'sd0;
            x3    <= 12'sd0;
            x4    <= 12'sd0;
            y_out <= 12'sd0;
        end else begin
            x4    <= x3;
            x3    <= x2;
            x2    <= x1;
            x1    <= x_in;
            y_out <= y_sat;
        end
    end
endmodule
```


### Your most recent attempt (round 1), which was not the best

```
G1 build/synthesis: PASS
G2 directed tests (reset cycles must output 0; every output within 8 LSB of the reference): FAIL  (37 failing cycles of 5693, max error 4095 LSB, 37 cycles not bit-exact)
   - power-up reset: 0 failing, max error 0 LSB
   - constant extremes: 0 failing, max error 0 LSB
   - alternating extremes: 13 failing, max error 4095 LSB
   - worst-case accumulation: 21 failing, max error 4095 LSB
   - mid-stream reset: 2 failing, max error 4095 LSB
   - reset held with active input: 1 failing, max error 4095 LSB
   - PAM4 levels: 0 failing, max error 0 LSB
   - random full range: 0 failing, max error 0 LSB
   failing example: cycle 46 (alternating extremes) rst_n=1 x_in=2047 expected=2047 got=-2048
   failing example: cycle 47 (alternating extremes) rst_n=1 x_in=-2048 expected=-2048 got=2047
   failing example: cycle 48 (alternating extremes) rst_n=1 x_in=2047 expected=2047 got=-2048
   failing example: cycle 49 (alternating extremes) rst_n=1 x_in=-2048 expected=-2048 got=2047
   failing example: cycle 50 (alternating extremes) rst_n=1 x_in=2047 expected=2047 got=-2048
   failing example: cycle 51 (alternating extremes) rst_n=1 x_in=-2048 expected=-2048 got=2047
G3 link BER/DER through the RTL on the channel (2,000,010 symbols): BER 8.25e-06, DER 1.65e-05 -> PASS (limit 0.0002); 0 outputs differ from the exact reference, max difference 0 LSB
Synthesis not run (gates G2/G3 must pass first).
```

```systemverilog
// Generated by Claude (claude-sonnet-5-5, as configured for the session) on 2026-10-31: agent loop round 1.
// Not edited by hand.
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Transposed-form FIR with CSD shift-add constant multipliers.
    // Coefficients [163, -417, 782, -1268, 1536]
    logic signed [23:0] x;
    assign x = x_in;

    logic signed [23:0] m0, m1, m2, m3, m4;
    // 163  = 128 + 32 + 4 - 1
    assign m0 = (x <<< 7) + (x <<< 5) + (x <<< 2) - x;
    // -417 = -(512 - 128 + 32 + 1)
    assign m1 = -((x <<< 9) - (x <<< 7) + (x <<< 5) + x);
    // 782  = 512 + 256 + 16 - 2
    assign m2 = (x <<< 9) + (x <<< 8) + (x <<< 4) - (x <<< 1);
    // -1268 = -(1024 + 256 - 16 + 4)
    assign m3 = -((x <<< 10) + (x <<< 8) - (x <<< 4) + (x <<< 2));
    // 1536 = 1024 + 512
    assign m4 = (x <<< 10) + (x <<< 9);

    logic signed [23:0] s1, s2, s3, s4;

    logic signed [23:0] sum;
    assign sum = s1 + m0;

    logic signed [13:0] sh;
    assign sh = sum[23:10];

    logic signed [11:0] y_sat;
    always_comb begin
        if (sh[13:11] == 3'b000 || sh[13:11] == 3'b111)
            y_sat = sh[11:0];
        else if (sh[13])
            y_sat = -12'sd2048;
        else
            y_sat = 12'sd2047;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s1    <= 24'sd0;
            s2    <= 24'sd0;
            s3    <= 24'sd0;
            s4    <= 24'sd0;
            y_out <= 12'sd0;
        end else begin
            s4    <= m4;
            s3    <= s4 + m3;
            s2    <= s3 + m2;
            s1    <= s2 + m1;
            y_out <= y_sat;
        end
    end
endmodule
```
