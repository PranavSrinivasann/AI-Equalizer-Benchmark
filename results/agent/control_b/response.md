```systemverilog
// 5-tap PAM4 FFE, CSD shift-add, input truncated to 10 bits with bias compensation.
// Coefficients [163, -417, 782, -1268, 1536] (Q1.10).
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Delay line holds only the upper 10 bits of each sample (2 LSBs dropped).
    logic signed [9:0] x0, x1, x2, x3, x4;
    assign x0 = x_in[11:2];

    // Sign-extended taps
    logic signed [23:0] e0, e1, e2, e3, e4;
    assign e0 = 24'(x0);
    assign e1 = 24'(x1);
    assign e2 = 24'(x2);
    assign e3 = 24'(x3);
    assign e4 = 24'(x4);

    // Bias: dropped LSBs average 1.5 (in units of 4), so add sum(c)*1.5/4 = 298.5 -> 299
    localparam signed [23:0] BIAS = 24'sd299;

    // CSD terms, working in units of 4 input LSBs (so final shift is 8, not 10)
    logic signed [23:0] t0, t1, t2, t3, t4;
    assign t0 = (e0 <<< 7) + (e0 <<< 5) + (e0 <<< 2) - e0;          //  163
    assign t1 = -(e1 <<< 9) + (e1 <<< 7) - (e1 <<< 5) - e1;         // -417
    assign t2 = (e2 <<< 10) - (e2 <<< 8) + (e2 <<< 4) - (e2 <<< 1); //  782
    assign t3 = -(e3 <<< 10) - (e3 <<< 8) + (e3 <<< 4) - (e3 <<< 2);// -1268
    assign t4 = (e4 <<< 10) + (e4 <<< 9);                           //  1536

    logic signed [23:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + BIAS;

    logic signed [15:0] shifted;
    assign shifted = acc[23:8];

    logic signed [11:0] y_sat;
    always_comb begin
        if (shifted[15:11] == 5'b00000 || shifted[15:11] == 5'b11111)
            y_sat = shifted[11:0];
        else if (!shifted[15])
            y_sat = 12'sd2047;
        else
            y_sat = -12'sd2048;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1    <= 10'sd0;
            x2    <= 10'sd0;
            x3    <= 10'sd0;
            x4    <= 10'sd0;
            y_out <= 12'sd0;
        end else begin
            x4    <= x3;
            x3    <= x2;
            x2    <= x1;
            x1    <= x0;
            y_out <= y_sat;
        end
    end
endmodule
```

CHANGE SUMMARY:
- Replaced the generic multipliers with explicit CSD shift-add terms (18 terms in total).
- Dropped the 2 input LSBs, so the delay line and adders are 10 bits wide. A +299 bias re-centres the truncation error.
- Shifted the final scaling from >>>10 to >>>8, because the datapath is in units of 4 input LSBs.

HYPOTHESIS: Logic cells should fall from 867 to roughly 450-550. That comes from the narrower datapath, 8 fewer delay-line flops and no multiplier arrays. Fmax should rise a little, to roughly 20-25 MHz, because the adder chain is shorter. The worst-case truncation error is about 6.1 LSB after bias, which is inside the 8 LSB limit, and it should barely move the BER.
