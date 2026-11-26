// loss20 5-tap W7: 5-tap FFE, per-tap CSD shift-add, Q3.3 samples, Q1.5 coefficients.
// Coefficients [3, -7, 15, -29, 48].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [6:0] x_in,
    output logic signed [6:0] y_out
);

    logic signed [6:0] x1, x2, x3, x4;
    logic signed [13:0] xe0; assign xe0 = x_in;
    logic signed [13:0] xe1; assign xe1 = x1;
    logic signed [13:0] xe2; assign xe2 = x2;
    logic signed [13:0] xe3; assign xe3 = x3;
    logic signed [13:0] xe4; assign xe4 = x4;
    logic signed [13:0] t0, t1, t2, t3, t4;

    // tap 0: 3
    assign t0 = (xe0 <<< 2) - xe0;
    // tap 1: -7
    assign t1 = - (xe1 <<< 3) + xe1;
    // tap 2: 15
    assign t2 = (xe2 <<< 4) - xe2;
    // tap 3: -29
    assign t3 = - (xe3 <<< 5) + (xe3 <<< 2) - xe3;
    // tap 4: 48
    assign t4 = (xe4 <<< 6) - (xe4 <<< 4);

    logic signed [13:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

    logic signed [8:0] shifted;
    assign shifted = acc >>> 5;
    logic signed [6:0] y_next;
    always_comb begin
        if (shifted > 9'sd63)
            y_next = 7'sd63;
        else if (shifted < -9'sd64)
            y_next = -7'sd64;
        else
            y_next = shifted[6:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1 <= 7'sd0;
            x2 <= 7'sd0;
            x3 <= 7'sd0;
            x4 <= 7'sd0;
            y_out <= 7'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
