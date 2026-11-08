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

## Round 7 of 8

### All attempts so far

| round | result | logic cells | Fmax MHz | score | your change summary |
|---|---|---|---|---|---|
| 1 | FAILED G2 | - | - | - | - Replaced the generic multipliers with CSD shift-add constants (4, 4, 4, 4 and 2 terms). - Switched from direct form to transposed form. The sample delay line becomes partial-sum registers, so the critical path is one constant... |
| 2 | valid | 487 | 39.8 | 0.674 | - Widened the accumulator and partial-sum registers from 24 to 25 bits. The worst-case sum is about 8.53M, which is above 2^23 and wrapped around. - Widened the saturation check to match: it now looks at sum[24:10] and tests... |
| 3 | valid | 388 | 44.2 | 0.510 | - Rescaled the whole datapath by 2^-6. Each shift-add term is now floor(x*2^k / 64), so the partial-sum registers and adders are 19 bits instead of 25. - The saturation slice moves to sum[18:4], which is the same output... |
| 4 | valid | 347 | 47.7 | 0.438 | - Rescaled the datapath from 2^-6 to 2^-8, so the partial-sum registers and adders are 17 bits instead of 19. - The shift terms are rebased to match, and the saturation slice moves to sum[16:2]. |
| 5 | valid | 323 | 45.4 | 0.419 | - Rescaled the datapath from 2^-8 to 2^-9, so the partial-sum registers and adders are 16 bits instead of 17. - Rebased every shift term to floor(x*2^k/512), and moved the saturation slice to sum[15:1]. |
| 6 | valid | 295 | 46.5 | 0.378 | - Rescaled the datapath from 2^-9 to 2^-10, so the partial-sum registers and adders are 15 bits instead of 16. - Rebased every shift term to floor(x*2^k/1024). The output slice is now sum[14:0], with no fractional guard bit. |

### Best valid design so far (round 6)

```
G1 build/synthesis: PASS
G2 directed tests (reset cycles must output 0; every output within 8 LSB of the reference): PASS  (0 failing cycles of 5693, max error 4 LSB, 2363 cycles not bit-exact)
   - power-up reset: 0 failing, max error 0 LSB
   - constant extremes: 0 failing, max error 1 LSB
   - alternating extremes: 0 failing, max error 2 LSB
   - worst-case accumulation: 0 failing, max error 1 LSB
   - mid-stream reset: 0 failing, max error 2 LSB
   - reset held with active input: 0 failing, max error 2 LSB
   - PAM4 levels: 0 failing, max error 3 LSB
   - random full range: 0 failing, max error 4 LSB
G3 link BER/DER through the RTL on the channel (2,000,010 symbols): BER 8.50e-06, DER 1.70e-05 -> PASS (limit 0.0002); 1,315,192 outputs differ from the exact reference, max difference 5 LSB
Synthesis (iCE40 UP5K): 295 logic cells (289 LUT4, 70 flip-flops, 64 carry cells); Fmax median 46.5 MHz (range 46.5-46.5, 3 placement seeds)
Score 0.378 (lower is better; 1.000 = hand-written CSD reference)
```

```systemverilog
// Generated by Claude (claude-sonnet-5-5, as configured for the session) on 2026-10-31: agent loop round 6.
// Not edited by hand.
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Transposed-form FIR, CSD shift-add, datapath scaled by 2^-10 (15 bits).
    // Each term is floor(x * 2^k / 1024); the output is sum[14:0] with no guard bit.
    logic signed [14:0] xe;
    assign xe = x_in;

    logic signed [14:0] m0, m1, m2, m3, m4;
    // 163  = 128 + 32 + 4 - 1
    assign m0 = (xe >>> 3) + (xe >>> 5) + (xe >>> 8) - (xe >>> 10);
    // -417 = -(512 - 128 + 32 + 1)
    assign m1 = -((xe >>> 1) - (xe >>> 3) + (xe >>> 5) + (xe >>> 10));
    // 782  = 512 + 256 + 16 - 2
    assign m2 = (xe >>> 1) + (xe >>> 2) + (xe >>> 6) - (xe >>> 9);
    // -1268 = -(1024 + 256 - 16 + 4)
    assign m3 = -(xe + (xe >>> 2) - (xe >>> 6) + (xe >>> 8));
    // 1536 = 1024 + 512
    assign m4 = xe + (xe >>> 1);

    logic signed [14:0] s1, s2, s3, s4;

    logic signed [14:0] sum;
    assign sum = s1 + m0;

    logic signed [11:0] y_sat;
    always_comb begin
        if (sum[14:11] == 4'b0000 || sum[14:11] == 4'b1111)
            y_sat = sum[11:0];
        else if (sum[14])
            y_sat = -12'sd2048;
        else
            y_sat = 12'sd2047;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s1    <= 15'sd0;
            s2    <= 15'sd0;
            s3    <= 15'sd0;
            s4    <= 15'sd0;
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
