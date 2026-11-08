// loss40 32-tap P10: 32-tap FFE, per-tap CSD shift-add, Q3.6 samples, Q1.8 coefficients.
// Coefficients [5, -15, 31, -57, 101, -171, 273, -384, 379, -98, -1, 46, -61, 52, -38, 22, -14, 5, -8, 9, -13, 12, -10, 6, -21, 64, -109, 81, -50, 17, 1, -5].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [9:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31;
    logic signed [21:0] xe0; assign xe0 = x_in;
    logic signed [21:0] xe1; assign xe1 = x1;
    logic signed [21:0] xe2; assign xe2 = x2;
    logic signed [21:0] xe3; assign xe3 = x3;
    logic signed [21:0] xe4; assign xe4 = x4;
    logic signed [21:0] xe5; assign xe5 = x5;
    logic signed [21:0] xe6; assign xe6 = x6;
    logic signed [21:0] xe7; assign xe7 = x7;
    logic signed [21:0] xe8; assign xe8 = x8;
    logic signed [21:0] xe9; assign xe9 = x9;
    logic signed [21:0] xe10; assign xe10 = x10;
    logic signed [21:0] xe11; assign xe11 = x11;
    logic signed [21:0] xe12; assign xe12 = x12;
    logic signed [21:0] xe13; assign xe13 = x13;
    logic signed [21:0] xe14; assign xe14 = x14;
    logic signed [21:0] xe15; assign xe15 = x15;
    logic signed [21:0] xe16; assign xe16 = x16;
    logic signed [21:0] xe17; assign xe17 = x17;
    logic signed [21:0] xe18; assign xe18 = x18;
    logic signed [21:0] xe19; assign xe19 = x19;
    logic signed [21:0] xe20; assign xe20 = x20;
    logic signed [21:0] xe21; assign xe21 = x21;
    logic signed [21:0] xe22; assign xe22 = x22;
    logic signed [21:0] xe23; assign xe23 = x23;
    logic signed [21:0] xe24; assign xe24 = x24;
    logic signed [21:0] xe25; assign xe25 = x25;
    logic signed [21:0] xe26; assign xe26 = x26;
    logic signed [21:0] xe27; assign xe27 = x27;
    logic signed [21:0] xe28; assign xe28 = x28;
    logic signed [21:0] xe29; assign xe29 = x29;
    logic signed [21:0] xe30; assign xe30 = x30;
    logic signed [21:0] xe31; assign xe31 = x31;
    logic signed [21:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31;

    // tap 0: 5
    assign t0 = (xe0 <<< 2) + xe0;
    // tap 1: -15
    assign t1 = - (xe1 <<< 4) + xe1;
    // tap 2: 31
    assign t2 = (xe2 <<< 5) - xe2;
    // tap 3: -57
    assign t3 = - (xe3 <<< 6) + (xe3 <<< 3) - xe3;
    // tap 4: 101
    assign t4 = (xe4 <<< 7) - (xe4 <<< 5) + (xe4 <<< 2) + xe4;
    // tap 5: -171
    assign t5 = - (xe5 <<< 8) + (xe5 <<< 6) + (xe5 <<< 4) + (xe5 <<< 2) + xe5;
    // tap 6: 273
    assign t6 = (xe6 <<< 8) + (xe6 <<< 4) + xe6;
    // tap 7: -384
    assign t7 = - (xe7 <<< 9) + (xe7 <<< 7);
    // tap 8: 379
    assign t8 = (xe8 <<< 9) - (xe8 <<< 7) - (xe8 <<< 2) - xe8;
    // tap 9: -98
    assign t9 = - (xe9 <<< 7) + (xe9 <<< 5) - (xe9 <<< 1);
    // tap 10: -1
    assign t10 = - xe10;
    // tap 11: 46
    assign t11 = (xe11 <<< 6) - (xe11 <<< 4) - (xe11 <<< 1);
    // tap 12: -61
    assign t12 = - (xe12 <<< 6) + (xe12 <<< 2) - xe12;
    // tap 13: 52
    assign t13 = (xe13 <<< 6) - (xe13 <<< 4) + (xe13 <<< 2);
    // tap 14: -38
    assign t14 = - (xe14 <<< 5) - (xe14 <<< 3) + (xe14 <<< 1);
    // tap 15: 22
    assign t15 = (xe15 <<< 5) - (xe15 <<< 3) - (xe15 <<< 1);
    // tap 16: -14
    assign t16 = - (xe16 <<< 4) + (xe16 <<< 1);
    // tap 17: 5
    assign t17 = (xe17 <<< 2) + xe17;
    // tap 18: -8
    assign t18 = - (xe18 <<< 3);
    // tap 19: 9
    assign t19 = (xe19 <<< 3) + xe19;
    // tap 20: -13
    assign t20 = - (xe20 <<< 4) + (xe20 <<< 2) - xe20;
    // tap 21: 12
    assign t21 = (xe21 <<< 4) - (xe21 <<< 2);
    // tap 22: -10
    assign t22 = - (xe22 <<< 3) - (xe22 <<< 1);
    // tap 23: 6
    assign t23 = (xe23 <<< 3) - (xe23 <<< 1);
    // tap 24: -21
    assign t24 = - (xe24 <<< 4) - (xe24 <<< 2) - xe24;
    // tap 25: 64
    assign t25 = (xe25 <<< 6);
    // tap 26: -109
    assign t26 = - (xe26 <<< 7) + (xe26 <<< 4) + (xe26 <<< 2) - xe26;
    // tap 27: 81
    assign t27 = (xe27 <<< 6) + (xe27 <<< 4) + xe27;
    // tap 28: -50
    assign t28 = - (xe28 <<< 6) + (xe28 <<< 4) - (xe28 <<< 1);
    // tap 29: 17
    assign t29 = (xe29 <<< 4) + xe29;
    // tap 30: 1
    assign t30 = xe30;
    // tap 31: -5
    assign t31 = - (xe31 <<< 2) - xe31;

    logic signed [21:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23 + t24 + t25 + t26 + t27 + t28 + t29 + t30 + t31;

    logic signed [13:0] shifted;
    assign shifted = acc >>> 8;
    logic signed [9:0] y_next;
    always_comb begin
        if (shifted > 14'sd511)
            y_next = 10'sd511;
        else if (shifted < -14'sd512)
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
            x24 <= 10'sd0;
            x25 <= 10'sd0;
            x26 <= 10'sd0;
            x27 <= 10'sd0;
            x28 <= 10'sd0;
            x29 <= 10'sd0;
            x30 <= 10'sd0;
            x31 <= 10'sd0;
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
            x24 <= x23;
            x25 <= x24;
            x26 <= x25;
            x27 <= x26;
            x28 <= x27;
            x29 <= x28;
            x30 <= x29;
            x31 <= x30;
            y_out <= y_next;
        end
    end
endmodule
