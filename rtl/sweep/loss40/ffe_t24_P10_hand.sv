// loss40 24-tap P10: 24-tap FFE, per-tap CSD shift-add, Q3.6 samples, Q1.8 coefficients.
// Coefficients [-23, 72, -150, 262, -383, 384, -96, 1, 44, -63, 57, -44, 25, -17, 9, -14, 17, -18, 11, 1, -20, 22, 0, -29].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [9:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23;
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
    logic signed [20:0] xe16; assign xe16 = x16;
    logic signed [20:0] xe17; assign xe17 = x17;
    logic signed [20:0] xe18; assign xe18 = x18;
    logic signed [20:0] xe19; assign xe19 = x19;
    logic signed [20:0] xe20; assign xe20 = x20;
    logic signed [20:0] xe21; assign xe21 = x21;
    logic signed [20:0] xe22; assign xe22 = x22;
    logic signed [20:0] xe23; assign xe23 = x23;
    logic signed [20:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23;

    // tap 0: -23
    assign t0 = - (xe0 <<< 5) + (xe0 <<< 3) + xe0;
    // tap 1: 72
    assign t1 = (xe1 <<< 6) + (xe1 <<< 3);
    // tap 2: -150
    assign t2 = - (xe2 <<< 7) - (xe2 <<< 5) + (xe2 <<< 3) + (xe2 <<< 1);
    // tap 3: 262
    assign t3 = (xe3 <<< 8) + (xe3 <<< 3) - (xe3 <<< 1);
    // tap 4: -383
    assign t4 = - (xe4 <<< 9) + (xe4 <<< 7) + xe4;
    // tap 5: 384
    assign t5 = (xe5 <<< 9) - (xe5 <<< 7);
    // tap 6: -96
    assign t6 = - (xe6 <<< 7) + (xe6 <<< 5);
    // tap 7: 1
    assign t7 = xe7;
    // tap 8: 44
    assign t8 = (xe8 <<< 6) - (xe8 <<< 4) - (xe8 <<< 2);
    // tap 9: -63
    assign t9 = - (xe9 <<< 6) + xe9;
    // tap 10: 57
    assign t10 = (xe10 <<< 6) - (xe10 <<< 3) + xe10;
    // tap 11: -44
    assign t11 = - (xe11 <<< 6) + (xe11 <<< 4) + (xe11 <<< 2);
    // tap 12: 25
    assign t12 = (xe12 <<< 5) - (xe12 <<< 3) + xe12;
    // tap 13: -17
    assign t13 = - (xe13 <<< 4) - xe13;
    // tap 14: 9
    assign t14 = (xe14 <<< 3) + xe14;
    // tap 15: -14
    assign t15 = - (xe15 <<< 4) + (xe15 <<< 1);
    // tap 16: 17
    assign t16 = (xe16 <<< 4) + xe16;
    // tap 17: -18
    assign t17 = - (xe17 <<< 4) - (xe17 <<< 1);
    // tap 18: 11
    assign t18 = (xe18 <<< 4) - (xe18 <<< 2) - xe18;
    // tap 19: 1
    assign t19 = xe19;
    // tap 20: -20
    assign t20 = - (xe20 <<< 4) - (xe20 <<< 2);
    // tap 21: 22
    assign t21 = (xe21 <<< 5) - (xe21 <<< 3) - (xe21 <<< 1);
    // tap 22: 0
    assign t22 = '0;
    // tap 23: -29
    assign t23 = - (xe23 <<< 5) + (xe23 <<< 2) - xe23;

    logic signed [20:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23;

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
            x16 <= 10'sd0;
            x17 <= 10'sd0;
            x18 <= 10'sd0;
            x19 <= 10'sd0;
            x20 <= 10'sd0;
            x21 <= 10'sd0;
            x22 <= 10'sd0;
            x23 <= 10'sd0;
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
            x16 <= x15;
            x17 <= x16;
            x18 <= x17;
            x19 <= x18;
            x20 <= x19;
            x21 <= x20;
            x22 <= x21;
            x23 <= x22;
            y_out <= y_next;
        end
    end
endmodule
