// loss30 16-tap P8: 16-tap FFE, per-tap CSD shift-add, Q3.4 samples, Q1.6 coefficients.
// Coefficients [3, -9, 17, -30, 51, -80, 96, -2, 0, 4, -1, 0, 1, -3, 2, -3].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [7:0] x_in,
    output logic signed [7:0] y_out
);

    logic signed [7:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15;
    logic signed [16:0] xe0; assign xe0 = x_in;
    logic signed [16:0] xe1; assign xe1 = x1;
    logic signed [16:0] xe2; assign xe2 = x2;
    logic signed [16:0] xe3; assign xe3 = x3;
    logic signed [16:0] xe4; assign xe4 = x4;
    logic signed [16:0] xe5; assign xe5 = x5;
    logic signed [16:0] xe6; assign xe6 = x6;
    logic signed [16:0] xe7; assign xe7 = x7;
    logic signed [16:0] xe8; assign xe8 = x8;
    logic signed [16:0] xe9; assign xe9 = x9;
    logic signed [16:0] xe10; assign xe10 = x10;
    logic signed [16:0] xe11; assign xe11 = x11;
    logic signed [16:0] xe12; assign xe12 = x12;
    logic signed [16:0] xe13; assign xe13 = x13;
    logic signed [16:0] xe14; assign xe14 = x14;
    logic signed [16:0] xe15; assign xe15 = x15;
    logic signed [16:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15;

    // tap 0: 3
    assign t0 = (xe0 <<< 2) - xe0;
    // tap 1: -9
    assign t1 = - (xe1 <<< 3) - xe1;
    // tap 2: 17
    assign t2 = (xe2 <<< 4) + xe2;
    // tap 3: -30
    assign t3 = - (xe3 <<< 5) + (xe3 <<< 1);
    // tap 4: 51
    assign t4 = (xe4 <<< 6) - (xe4 <<< 4) + (xe4 <<< 2) - xe4;
    // tap 5: -80
    assign t5 = - (xe5 <<< 6) - (xe5 <<< 4);
    // tap 6: 96
    assign t6 = (xe6 <<< 7) - (xe6 <<< 5);
    // tap 7: -2
    assign t7 = - (xe7 <<< 1);
    // tap 8: 0
    assign t8 = '0;
    // tap 9: 4
    assign t9 = (xe9 <<< 2);
    // tap 10: -1
    assign t10 = - xe10;
    // tap 11: 0
    assign t11 = '0;
    // tap 12: 1
    assign t12 = xe12;
    // tap 13: -3
    assign t13 = - (xe13 <<< 2) + xe13;
    // tap 14: 2
    assign t14 = (xe14 <<< 1);
    // tap 15: -3
    assign t15 = - (xe15 <<< 2) + xe15;

    logic signed [16:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15;

    logic signed [10:0] shifted;
    assign shifted = acc >>> 6;
    logic signed [7:0] y_next;
    always_comb begin
        if (shifted > 11'sd127)
            y_next = 8'sd127;
        else if (shifted < -11'sd128)
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
            x8 <= 8'sd0;
            x9 <= 8'sd0;
            x10 <= 8'sd0;
            x11 <= 8'sd0;
            x12 <= 8'sd0;
            x13 <= 8'sd0;
            x14 <= 8'sd0;
            x15 <= 8'sd0;
            y_out <= 8'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            x5 <= x4;
            x6 <= x5;
            x7 <= x6;
            x8 <= x7;
            x9 <= x8;
            x10 <= x9;
            x11 <= x10;
            x12 <= x11;
            x13 <= x12;
            x14 <= x13;
            x15 <= x14;
            y_out <= y_next;
        end
    end
endmodule
