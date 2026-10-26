// Case A hand-optimized FFE: plain per-tap CSD shift-add.
// Coefficients [51, -154, 1024, 154, -51] (Q1.10). Same ports, latency and reset
// behavior as the baseline. Each multiply is replaced by its canonical
// signed-digit shift-add form; no cross-tap sharing or factoring.

module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4;

    // Sign-extend each tap to the accumulator width (23 bits covers
    // the worst case |acc| <= 2048*1434 = 2936832).
    logic signed [22:0] xe0;  assign xe0 = x_in;
    logic signed [22:0] xe1;  assign xe1 = x1;
    logic signed [22:0] xe2;  assign xe2 = x2;
    logic signed [22:0] xe3;  assign xe3 = x3;
    logic signed [22:0] xe4;  assign xe4 = x4;

    logic signed [22:0] t0, t1, t2, t3, t4;

    // tap 0:    51 = 2^6 -2^4 +2^2 -2^0
    assign t0 = (xe0 <<< 6) - (xe0 <<< 4) + (xe0 <<< 2) - xe0;

    // tap 1:  -154 = -(2^7 +2^5 -2^3 +2^1)
    assign t1 = - (xe1 <<< 7) - (xe1 <<< 5) + (xe1 <<< 3) - (xe1 <<< 1);

    // tap 2:  1024 = 2^10
    assign t2 = (xe2 <<< 10);

    // tap 3:   154 = 2^7 +2^5 -2^3 +2^1
    assign t3 = (xe3 <<< 7) + (xe3 <<< 5) - (xe3 <<< 3) + (xe3 <<< 1);

    // tap 4:   -51 = -(2^6 -2^4 +2^2 -2^0)
    assign t4 = - (xe4 <<< 6) + (xe4 <<< 4) - (xe4 <<< 2) + xe4;

    logic signed [22:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

    // sum|c| = 1434 >= 1024, so the output can exceed 12 bits: saturate.
    logic signed [12:0] shifted;
    assign shifted = acc >>> 10;

    logic signed [11:0] y_next;
    always_comb begin
        if (shifted > 13'sd2047)
            y_next = 12'sd2047;
        else if (shifted < -13'sd2048)
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
