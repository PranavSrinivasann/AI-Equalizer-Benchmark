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
