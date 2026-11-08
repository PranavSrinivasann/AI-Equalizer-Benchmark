// loss30 32-tap P12: 32-tap FFE, per-tap CSD shift-add, Q3.8 samples, Q1.10 coefficients.
// Coefficients [6, -17, 33, -58, 100, -171, 291, -492, 818, -1276, 1536, -37, -3, 66, -14, -4, 21, -41, 29, -40, -11, 11, -39, 21, -31, 7, -7, -12, 9, -24, 12, -13].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31;
    logic signed [24:0] xe0; assign xe0 = x_in;
    logic signed [24:0] xe1; assign xe1 = x1;
    logic signed [24:0] xe2; assign xe2 = x2;
    logic signed [24:0] xe3; assign xe3 = x3;
    logic signed [24:0] xe4; assign xe4 = x4;
    logic signed [24:0] xe5; assign xe5 = x5;
    logic signed [24:0] xe6; assign xe6 = x6;
    logic signed [24:0] xe7; assign xe7 = x7;
    logic signed [24:0] xe8; assign xe8 = x8;
    logic signed [24:0] xe9; assign xe9 = x9;
    logic signed [24:0] xe10; assign xe10 = x10;
    logic signed [24:0] xe11; assign xe11 = x11;
    logic signed [24:0] xe12; assign xe12 = x12;
    logic signed [24:0] xe13; assign xe13 = x13;
    logic signed [24:0] xe14; assign xe14 = x14;
    logic signed [24:0] xe15; assign xe15 = x15;
    logic signed [24:0] xe16; assign xe16 = x16;
    logic signed [24:0] xe17; assign xe17 = x17;
    logic signed [24:0] xe18; assign xe18 = x18;
    logic signed [24:0] xe19; assign xe19 = x19;
    logic signed [24:0] xe20; assign xe20 = x20;
    logic signed [24:0] xe21; assign xe21 = x21;
    logic signed [24:0] xe22; assign xe22 = x22;
    logic signed [24:0] xe23; assign xe23 = x23;
    logic signed [24:0] xe24; assign xe24 = x24;
    logic signed [24:0] xe25; assign xe25 = x25;
    logic signed [24:0] xe26; assign xe26 = x26;
    logic signed [24:0] xe27; assign xe27 = x27;
    logic signed [24:0] xe28; assign xe28 = x28;
    logic signed [24:0] xe29; assign xe29 = x29;
    logic signed [24:0] xe30; assign xe30 = x30;
    logic signed [24:0] xe31; assign xe31 = x31;
    logic signed [24:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31;

    // tap 0: 6
    assign t0 = (xe0 <<< 3) - (xe0 <<< 1);
    // tap 1: -17
    assign t1 = - (xe1 <<< 4) - xe1;
    // tap 2: 33
    assign t2 = (xe2 <<< 5) + xe2;
    // tap 3: -58
    assign t3 = - (xe3 <<< 6) + (xe3 <<< 3) - (xe3 <<< 1);
    // tap 4: 100
    assign t4 = (xe4 <<< 7) - (xe4 <<< 5) + (xe4 <<< 2);
    // tap 5: -171
    assign t5 = - (xe5 <<< 8) + (xe5 <<< 6) + (xe5 <<< 4) + (xe5 <<< 2) + xe5;
    // tap 6: 291
    assign t6 = (xe6 <<< 8) + (xe6 <<< 5) + (xe6 <<< 2) - xe6;
    // tap 7: -492
    assign t7 = - (xe7 <<< 9) + (xe7 <<< 4) + (xe7 <<< 2);
    // tap 8: 818
    assign t8 = (xe8 <<< 10) - (xe8 <<< 8) + (xe8 <<< 6) - (xe8 <<< 4) + (xe8 <<< 1);
    // tap 9: -1276
    assign t9 = - (xe9 <<< 10) - (xe9 <<< 8) + (xe9 <<< 2);
    // tap 10: 1536
    assign t10 = (xe10 <<< 11) - (xe10 <<< 9);
    // tap 11: -37
    assign t11 = - (xe11 <<< 5) - (xe11 <<< 2) - xe11;
    // tap 12: -3
    assign t12 = - (xe12 <<< 2) + xe12;
    // tap 13: 66
    assign t13 = (xe13 <<< 6) + (xe13 <<< 1);
    // tap 14: -14
    assign t14 = - (xe14 <<< 4) + (xe14 <<< 1);
    // tap 15: -4
    assign t15 = - (xe15 <<< 2);
    // tap 16: 21
    assign t16 = (xe16 <<< 4) + (xe16 <<< 2) + xe16;
    // tap 17: -41
    assign t17 = - (xe17 <<< 5) - (xe17 <<< 3) - xe17;
    // tap 18: 29
    assign t18 = (xe18 <<< 5) - (xe18 <<< 2) + xe18;
    // tap 19: -40
    assign t19 = - (xe19 <<< 5) - (xe19 <<< 3);
    // tap 20: -11
    assign t20 = - (xe20 <<< 4) + (xe20 <<< 2) + xe20;
    // tap 21: 11
    assign t21 = (xe21 <<< 4) - (xe21 <<< 2) - xe21;
    // tap 22: -39
    assign t22 = - (xe22 <<< 5) - (xe22 <<< 3) + xe22;
    // tap 23: 21
    assign t23 = (xe23 <<< 4) + (xe23 <<< 2) + xe23;
    // tap 24: -31
    assign t24 = - (xe24 <<< 5) + xe24;
    // tap 25: 7
    assign t25 = (xe25 <<< 3) - xe25;
    // tap 26: -7
    assign t26 = - (xe26 <<< 3) + xe26;
    // tap 27: -12
    assign t27 = - (xe27 <<< 4) + (xe27 <<< 2);
    // tap 28: 9
    assign t28 = (xe28 <<< 3) + xe28;
    // tap 29: -24
    assign t29 = - (xe29 <<< 5) + (xe29 <<< 3);
    // tap 30: 12
    assign t30 = (xe30 <<< 4) - (xe30 <<< 2);
    // tap 31: -13
    assign t31 = - (xe31 <<< 4) + (xe31 <<< 2) - xe31;

    logic signed [24:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23 + t24 + t25 + t26 + t27 + t28 + t29 + t30 + t31;

    logic signed [14:0] shifted;
    assign shifted = acc >>> 10;
    logic signed [11:0] y_next;
    always_comb begin
        if (shifted > 15'sd2047)
            y_next = 12'sd2047;
        else if (shifted < -15'sd2048)
            y_next = -12'sd2048;
        else
            y_next = shifted[11:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1 <= 12'sd0;
            x2 <= 12'sd0;
            x3 <= 12'sd0;
            x4 <= 12'sd0;
            x5 <= 12'sd0;
            x6 <= 12'sd0;
            x7 <= 12'sd0;
            x8 <= 12'sd0;
            x9 <= 12'sd0;
            x10 <= 12'sd0;
            x11 <= 12'sd0;
            x12 <= 12'sd0;
            x13 <= 12'sd0;
            x14 <= 12'sd0;
            x15 <= 12'sd0;
            x16 <= 12'sd0;
            x17 <= 12'sd0;
            x18 <= 12'sd0;
            x19 <= 12'sd0;
            x20 <= 12'sd0;
            x21 <= 12'sd0;
            x22 <= 12'sd0;
            x23 <= 12'sd0;
            x24 <= 12'sd0;
            x25 <= 12'sd0;
            x26 <= 12'sd0;
            x27 <= 12'sd0;
            x28 <= 12'sd0;
            x29 <= 12'sd0;
            x30 <= 12'sd0;
            x31 <= 12'sd0;
            y_out <= 12'sd0;
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
