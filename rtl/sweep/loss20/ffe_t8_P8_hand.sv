// loss20 8-tap P8: 8-tap FFE, per-tap CSD shift-add, Q3.4 samples, Q1.6 coefficients.
// Coefficients [-3, 7, -14, 29, -59, 96, 0, 2].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [7:0] x_in,
    output logic signed [7:0] y_out
);

    logic signed [7:0] x1, x2, x3, x4, x5, x6, x7;
    logic signed [15:0] xe0; assign xe0 = x_in;
    logic signed [15:0] xe1; assign xe1 = x1;
    logic signed [15:0] xe2; assign xe2 = x2;
    logic signed [15:0] xe3; assign xe3 = x3;
    logic signed [15:0] xe4; assign xe4 = x4;
    logic signed [15:0] xe5; assign xe5 = x5;
    logic signed [15:0] xe6; assign xe6 = x6;
    logic signed [15:0] xe7; assign xe7 = x7;
    logic signed [15:0] t0, t1, t2, t3, t4, t5, t6, t7;

    // tap 0: -3
    assign t0 = - (xe0 <<< 2) + xe0;
    // tap 1: 7
    assign t1 = (xe1 <<< 3) - xe1;
    // tap 2: -14
    assign t2 = - (xe2 <<< 4) + (xe2 <<< 1);
    // tap 3: 29
    assign t3 = (xe3 <<< 5) - (xe3 <<< 2) + xe3;
    // tap 4: -59
    assign t4 = - (xe4 <<< 6) + (xe4 <<< 2) + xe4;
    // tap 5: 96
    assign t5 = (xe5 <<< 7) - (xe5 <<< 5);
    // tap 6: 0
    assign t6 = '0;
    // tap 7: 2
    assign t7 = (xe7 <<< 1);

    logic signed [15:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7;

    logic signed [9:0] shifted;
    assign shifted = acc >>> 6;
    logic signed [7:0] y_next;
    always_comb begin
        if (shifted > 10'sd127)
            y_next = 8'sd127;
        else if (shifted < -10'sd128)
            y_next = -8'sd128;
        else
            y_next = shifted[7:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1 <= 8'sd0;
            x2 <= 8'sd0;
            x3 <= 8'sd0;
            x4 <= 8'sd0;
            x5 <= 8'sd0;
            x6 <= 8'sd0;
            x7 <= 8'sd0;
            y_out <= 8'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            x5 <= x4;
            x6 <= x5;
            x7 <= x6;
            y_out <= y_next;
        end
    end
endmodule
