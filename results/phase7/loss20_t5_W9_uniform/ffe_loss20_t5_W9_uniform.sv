// loss20 5-tap W9: 5-tap FFE, per-tap CSD shift-add, Q3.5 samples, Q1.7 coefficients.
// Coefficients [10, -27, 58, -117, 192].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [8:0] x_in,
    output logic signed [8:0] y_out
);

    logic signed [8:0] x1, x2, x3, x4;
    logic signed [17:0] xe0; assign xe0 = x_in;
    logic signed [17:0] xe1; assign xe1 = x1;
    logic signed [17:0] xe2; assign xe2 = x2;
    logic signed [17:0] xe3; assign xe3 = x3;
    logic signed [17:0] xe4; assign xe4 = x4;
    logic signed [17:0] t0, t1, t2, t3, t4;

    // tap 0: 10
    assign t0 = (xe0 <<< 3) + (xe0 <<< 1);
    // tap 1: -27
    assign t1 = - (xe1 <<< 5) + (xe1 <<< 2) + xe1;
    // tap 2: 58
    assign t2 = (xe2 <<< 6) - (xe2 <<< 3) + (xe2 <<< 1);
    // tap 3: -117
    assign t3 = - (xe3 <<< 7) + (xe3 <<< 4) - (xe3 <<< 2) - xe3;
    // tap 4: 192
    assign t4 = (xe4 <<< 8) - (xe4 <<< 6);

    logic signed [17:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

    logic signed [10:0] shifted;
    assign shifted = acc >>> 7;
    logic signed [8:0] y_next;
    always_comb begin
        if (shifted > 11'sd255)
            y_next = 9'sd255;
        else if (shifted < -11'sd256)
            y_next = -9'sd256;
        else
            y_next = shifted[8:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1 <= 9'sd0;
            x2 <= 9'sd0;
            x3 <= 9'sd0;
            x4 <= 9'sd0;
            y_out <= 9'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
