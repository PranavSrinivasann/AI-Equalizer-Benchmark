// loss40 32-tap P12: 32-tap FFE, per-tap CSD shift-add, Q3.8 samples, Q1.10 coefficients.
// Coefficients [18, -59, 124, -230, 402, -683, 1093, -1536, 1518, -394, -3, 184, -246, 208, -152, 87, -58, 21, -32, 37, -53, 49, -42, 23, -85, 256, -435, 322, -199, 67, 5, -19].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31;
    logic signed [25:0] xe0; assign xe0 = x_in;
    logic signed [25:0] xe1; assign xe1 = x1;
    logic signed [25:0] xe2; assign xe2 = x2;
    logic signed [25:0] xe3; assign xe3 = x3;
    logic signed [25:0] xe4; assign xe4 = x4;
    logic signed [25:0] xe5; assign xe5 = x5;
    logic signed [25:0] xe6; assign xe6 = x6;
    logic signed [25:0] xe7; assign xe7 = x7;
    logic signed [25:0] xe8; assign xe8 = x8;
    logic signed [25:0] xe9; assign xe9 = x9;
    logic signed [25:0] xe10; assign xe10 = x10;
    logic signed [25:0] xe11; assign xe11 = x11;
    logic signed [25:0] xe12; assign xe12 = x12;
    logic signed [25:0] xe13; assign xe13 = x13;
    logic signed [25:0] xe14; assign xe14 = x14;
    logic signed [25:0] xe15; assign xe15 = x15;
    logic signed [25:0] xe16; assign xe16 = x16;
    logic signed [25:0] xe17; assign xe17 = x17;
    logic signed [25:0] xe18; assign xe18 = x18;
    logic signed [25:0] xe19; assign xe19 = x19;
    logic signed [25:0] xe20; assign xe20 = x20;
    logic signed [25:0] xe21; assign xe21 = x21;
    logic signed [25:0] xe22; assign xe22 = x22;
    logic signed [25:0] xe23; assign xe23 = x23;
    logic signed [25:0] xe24; assign xe24 = x24;
    logic signed [25:0] xe25; assign xe25 = x25;
    logic signed [25:0] xe26; assign xe26 = x26;
    logic signed [25:0] xe27; assign xe27 = x27;
    logic signed [25:0] xe28; assign xe28 = x28;
    logic signed [25:0] xe29; assign xe29 = x29;
    logic signed [25:0] xe30; assign xe30 = x30;
    logic signed [25:0] xe31; assign xe31 = x31;
    logic signed [25:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31;

    // tap 0: 18
    assign t0 = (xe0 <<< 4) + (xe0 <<< 1);
    // tap 1: -59
    assign t1 = - (xe1 <<< 6) + (xe1 <<< 2) + xe1;
    // tap 2: 124
    assign t2 = (xe2 <<< 7) - (xe2 <<< 2);
    // tap 3: -230
    assign t3 = - (xe3 <<< 8) + (xe3 <<< 5) - (xe3 <<< 3) + (xe3 <<< 1);
    // tap 4: 402
    assign t4 = (xe4 <<< 9) - (xe4 <<< 7) + (xe4 <<< 4) + (xe4 <<< 1);
    // tap 5: -683
    assign t5 = - (xe5 <<< 10) + (xe5 <<< 8) + (xe5 <<< 6) + (xe5 <<< 4) + (xe5 <<< 2) + xe5;
    // tap 6: 1093
    assign t6 = (xe6 <<< 10) + (xe6 <<< 6) + (xe6 <<< 2) + xe6;
    // tap 7: -1536
    assign t7 = - (xe7 <<< 11) + (xe7 <<< 9);
    // tap 8: 1518
    assign t8 = (xe8 <<< 11) - (xe8 <<< 9) - (xe8 <<< 4) - (xe8 <<< 1);
    // tap 9: -394
    assign t9 = - (xe9 <<< 9) + (xe9 <<< 7) - (xe9 <<< 3) - (xe9 <<< 1);
    // tap 10: -3
    assign t10 = - (xe10 <<< 2) + xe10;
    // tap 11: 184
    assign t11 = (xe11 <<< 8) - (xe11 <<< 6) - (xe11 <<< 3);
    // tap 12: -246
    assign t12 = - (xe12 <<< 8) + (xe12 <<< 3) + (xe12 <<< 1);
    // tap 13: 208
    assign t13 = (xe13 <<< 8) - (xe13 <<< 6) + (xe13 <<< 4);
    // tap 14: -152
    assign t14 = - (xe14 <<< 7) - (xe14 <<< 5) + (xe14 <<< 3);
    // tap 15: 87
    assign t15 = (xe15 <<< 7) - (xe15 <<< 5) - (xe15 <<< 3) - xe15;
    // tap 16: -58
    assign t16 = - (xe16 <<< 6) + (xe16 <<< 3) - (xe16 <<< 1);
    // tap 17: 21
    assign t17 = (xe17 <<< 4) + (xe17 <<< 2) + xe17;
    // tap 18: -32
    assign t18 = - (xe18 <<< 5);
    // tap 19: 37
    assign t19 = (xe19 <<< 5) + (xe19 <<< 2) + xe19;
    // tap 20: -53
    assign t20 = - (xe20 <<< 6) + (xe20 <<< 4) - (xe20 <<< 2) - xe20;
    // tap 21: 49
    assign t21 = (xe21 <<< 6) - (xe21 <<< 4) + xe21;
    // tap 22: -42
    assign t22 = - (xe22 <<< 5) - (xe22 <<< 3) - (xe22 <<< 1);
    // tap 23: 23
    assign t23 = (xe23 <<< 5) - (xe23 <<< 3) - xe23;
    // tap 24: -85
    assign t24 = - (xe24 <<< 6) - (xe24 <<< 4) - (xe24 <<< 2) - xe24;
    // tap 25: 256
    assign t25 = (xe25 <<< 8);
    // tap 26: -435
    assign t26 = - (xe26 <<< 9) + (xe26 <<< 6) + (xe26 <<< 4) - (xe26 <<< 2) + xe26;
    // tap 27: 322
    assign t27 = (xe27 <<< 8) + (xe27 <<< 6) + (xe27 <<< 1);
    // tap 28: -199
    assign t28 = - (xe28 <<< 8) + (xe28 <<< 6) - (xe28 <<< 3) + xe28;
    // tap 29: 67
    assign t29 = (xe29 <<< 6) + (xe29 <<< 2) - xe29;
    // tap 30: 5
    assign t30 = (xe30 <<< 2) + xe30;
    // tap 31: -19
    assign t31 = - (xe31 <<< 4) - (xe31 <<< 2) + xe31;

    logic signed [25:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23 + t24 + t25 + t26 + t27 + t28 + t29 + t30 + t31;

    logic signed [15:0] shifted;
    assign shifted = acc >>> 10;
    logic signed [11:0] y_next;
    always_comb begin
        if (shifted > 16'sd2047)
            y_next = 12'sd2047;
        else if (shifted < -16'sd2048)
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
