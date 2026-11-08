// Case B hand-optimized FFE: plain per-tap CSD shift-add.
// Coefficients [73, -121, 89, 146, -57] (Q1.10). Same ports, latency and reset
// behavior as the baseline. Each multiply is replaced by its canonical
// signed-digit shift-add form; no cross-tap sharing or factoring.

module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4;

    // Sign-extend each tap to the accumulator width (22 bits covers
    // the worst case |acc| <= 2048*486 = 995328).
    logic signed [21:0] xe0;  assign xe0 = x_in;
    logic signed [21:0] xe1;  assign xe1 = x1;
    logic signed [21:0] xe2;  assign xe2 = x2;
    logic signed [21:0] xe3;  assign xe3 = x3;
    logic signed [21:0] xe4;  assign xe4 = x4;

    logic signed [21:0] t0, t1, t2, t3, t4;

    // tap 0:    73 = 2^6 +2^3 +2^0
    assign t0 = (xe0 <<< 6) + (xe0 <<< 3) + xe0;

    // tap 1:  -121 = -(2^7 -2^3 +2^0)
    assign t1 = - (xe1 <<< 7) + (xe1 <<< 3) - xe1;

    // tap 2:    89 = 2^7 -2^5 -2^3 +2^0
    assign t2 = (xe2 <<< 7) - (xe2 <<< 5) - (xe2 <<< 3) + xe2;

    // tap 3:   146 = 2^7 +2^4 +2^1
    assign t3 = (xe3 <<< 7) + (xe3 <<< 4) + (xe3 <<< 1);

    // tap 4:   -57 = -(2^6 -2^3 +2^0)
    assign t4 = - (xe4 <<< 6) + (xe4 <<< 3) - xe4;

    logic signed [21:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

    // sum|c| = 486 < 1024, so |acc >>> 10| <= 2048*486/1024 < 2048:
    // the result always fits 12 bits and saturation can never fire.
    logic signed [11:0] y_next;
    assign y_next = acc[21:10];

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
