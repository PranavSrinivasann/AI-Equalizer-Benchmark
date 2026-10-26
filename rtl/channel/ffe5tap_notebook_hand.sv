// Channel 'notebook' hand-optimized FFE: plain per-tap CSD shift-add.
// Coefficients [-483, 1536, -398, -165, 106] (Q1.10). Same ports, latency and reset
// behavior as the baseline. Each multiply is replaced by its canonical
// signed-digit shift-add form; no cross-tap sharing or factoring.

module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4;

    // Sign-extend each tap to the accumulator width (24 bits covers
    // the worst case |acc| <= 2048*2688 = 5505024).
    logic signed [23:0] xe0;  assign xe0 = x_in;
    logic signed [23:0] xe1;  assign xe1 = x1;
    logic signed [23:0] xe2;  assign xe2 = x2;
    logic signed [23:0] xe3;  assign xe3 = x3;
    logic signed [23:0] xe4;  assign xe4 = x4;

    logic signed [23:0] t0, t1, t2, t3, t4;

    // tap 0:  -483 = -(2^9 -2^5 +2^2 -2^0)
    assign t0 = - (xe0 <<< 9) + (xe0 <<< 5) - (xe0 <<< 2) + xe0;

    // tap 1:  1536 = 2^11 -2^9
    assign t1 = (xe1 <<< 11) - (xe1 <<< 9);

    // tap 2:  -398 = -(2^9 -2^7 +2^4 -2^1)
    assign t2 = - (xe2 <<< 9) + (xe2 <<< 7) - (xe2 <<< 4) + (xe2 <<< 1);

    // tap 3:  -165 = -(2^7 +2^5 +2^2 +2^0)
    assign t3 = - (xe3 <<< 7) - (xe3 <<< 5) - (xe3 <<< 2) - xe3;

    // tap 4:   106 = 2^7 -2^5 +2^3 +2^1
    assign t4 = (xe4 <<< 7) - (xe4 <<< 5) + (xe4 <<< 3) + (xe4 <<< 1);

    logic signed [23:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

    // sum|c| = 2688 >= 1024, so the output can exceed 12 bits: saturate.
    logic signed [13:0] shifted;
    assign shifted = acc >>> 10;

    logic signed [11:0] y_next;
    always_comb begin
        if (shifted > 14'sd2047)
            y_next = 12'sd2047;
        else if (shifted < -14'sd2048)
            y_next = -12'sd2048;
        else
            y_next = shifted[11:0];
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
            y_out <= y_next;
        end
    end

endmodule
