// loss30 16-tap P10: 16-tap FFE, per-tap CSD shift-add, Q3.6 samples, Q1.8 coefficients.
// Coefficients [14, -36, 69, -121, 203, -319, 384, -9, -1, 17, -3, -2, 6, -11, 9, -12].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [9:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15;
    logic signed [20:0] xe0; assign xe0 = x_in;
    logic signed [20:0] xe1; assign xe1 = x1;
    logic signed [20:0] xe2; assign xe2 = x2;
    logic signed [20:0] xe3; assign xe3 = x3;
    logic signed [20:0] xe4; assign xe4 = x4;
    logic signed [20:0] xe5; assign xe5 = x5;
    logic signed [20:0] xe6; assign xe6 = x6;
    logic signed [20:0] xe7; assign xe7 = x7;
    logic signed [20:0] xe8; assign xe8 = x8;
    logic signed [20:0] xe9; assign xe9 = x9;
    logic signed [20:0] xe10; assign xe10 = x10;
    logic signed [20:0] xe11; assign xe11 = x11;
    logic signed [20:0] xe12; assign xe12 = x12;
    logic signed [20:0] xe13; assign xe13 = x13;
    logic signed [20:0] xe14; assign xe14 = x14;
    logic signed [20:0] xe15; assign xe15 = x15;
    logic signed [20:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15;

    // tap 0: 14
    assign t0 = (xe0 <<< 4) - (xe0 <<< 1);
    // tap 1: -36
    assign t1 = - (xe1 <<< 5) - (xe1 <<< 2);
    // tap 2: 69
    assign t2 = (xe2 <<< 6) + (xe2 <<< 2) + xe2;
    // tap 3: -121
    assign t3 = - (xe3 <<< 7) + (xe3 <<< 3) - xe3;
    // tap 4: 203
    assign t4 = (xe4 <<< 8) - (xe4 <<< 6) + (xe4 <<< 4) - (xe4 <<< 2) - xe4;
    // tap 5: -319
    assign t5 = - (xe5 <<< 8) - (xe5 <<< 6) + xe5;
    // tap 6: 384
    assign t6 = (xe6 <<< 9) - (xe6 <<< 7);
    // tap 7: -9
    assign t7 = - (xe7 <<< 3) - xe7;
    // tap 8: -1
    assign t8 = - xe8;
    // tap 9: 17
    assign t9 = (xe9 <<< 4) + xe9;
    // tap 10: -3
    assign t10 = - (xe10 <<< 2) + xe10;
    // tap 11: -2
    assign t11 = - (xe11 <<< 1);
    // tap 12: 6
    assign t12 = (xe12 <<< 3) - (xe12 <<< 1);
    // tap 13: -11
    assign t13 = - (xe13 <<< 4) + (xe13 <<< 2) + xe13;
    // tap 14: 9
    assign t14 = (xe14 <<< 3) + xe14;
    // tap 15: -12
    assign t15 = - (xe15 <<< 4) + (xe15 <<< 2);

    logic signed [20:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15;

    logic signed [12:0] shifted;
    assign shifted = acc >>> 8;
    logic signed [9:0] y_next;
    always_comb begin
        if (shifted > 13'sd511)
            y_next = 10'sd511;
        else if (shifted < -13'sd512)
            y_next = -10'sd512;
        else
            y_next = shifted[9:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1 <= 10'sd0;
            x2 <= 10'sd0;
            x3 <= 10'sd0;
            x4 <= 10'sd0;
            x5 <= 10'sd0;
            x6 <= 10'sd0;
            x7 <= 10'sd0;
            x8 <= 10'sd0;
            x9 <= 10'sd0;
            x10 <= 10'sd0;
            x11 <= 10'sd0;
            x12 <= 10'sd0;
            x13 <= 10'sd0;
            x14 <= 10'sd0;
            x15 <= 10'sd0;
            y_out <= 10'sd0;
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
