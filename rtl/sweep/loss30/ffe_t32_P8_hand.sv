// loss30 32-tap P8: 32-tap FFE, per-tap CSD shift-add, Q3.4 samples, Q1.6 coefficients.
// Coefficients [0, -1, 2, -4, 6, -11, 18, -31, 51, -80, 96, -2, 0, 4, -1, 0, 1, -3, 2, -2, -1, 1, -2, 1, -2, 0, 0, -1, 1, -2, 1, -1].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [7:0] x_in,
    output logic signed [7:0] y_out
);

    logic signed [7:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31;
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
    logic signed [16:0] xe16; assign xe16 = x16;
    logic signed [16:0] xe17; assign xe17 = x17;
    logic signed [16:0] xe18; assign xe18 = x18;
    logic signed [16:0] xe19; assign xe19 = x19;
    logic signed [16:0] xe20; assign xe20 = x20;
    logic signed [16:0] xe21; assign xe21 = x21;
    logic signed [16:0] xe22; assign xe22 = x22;
    logic signed [16:0] xe23; assign xe23 = x23;
    logic signed [16:0] xe24; assign xe24 = x24;
    logic signed [16:0] xe25; assign xe25 = x25;
    logic signed [16:0] xe26; assign xe26 = x26;
    logic signed [16:0] xe27; assign xe27 = x27;
    logic signed [16:0] xe28; assign xe28 = x28;
    logic signed [16:0] xe29; assign xe29 = x29;
    logic signed [16:0] xe30; assign xe30 = x30;
    logic signed [16:0] xe31; assign xe31 = x31;
    logic signed [16:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31;

    // tap 0: 0
    assign t0 = '0;
    // tap 1: -1
    assign t1 = - xe1;
    // tap 2: 2
    assign t2 = (xe2 <<< 1);
    // tap 3: -4
    assign t3 = - (xe3 <<< 2);
    // tap 4: 6
    assign t4 = (xe4 <<< 3) - (xe4 <<< 1);
    // tap 5: -11
    assign t5 = - (xe5 <<< 4) + (xe5 <<< 2) + xe5;
    // tap 6: 18
    assign t6 = (xe6 <<< 4) + (xe6 <<< 1);
    // tap 7: -31
    assign t7 = - (xe7 <<< 5) + xe7;
    // tap 8: 51
    assign t8 = (xe8 <<< 6) - (xe8 <<< 4) + (xe8 <<< 2) - xe8;
    // tap 9: -80
    assign t9 = - (xe9 <<< 6) - (xe9 <<< 4);
    // tap 10: 96
    assign t10 = (xe10 <<< 7) - (xe10 <<< 5);
    // tap 11: -2
    assign t11 = - (xe11 <<< 1);
    // tap 12: 0
    assign t12 = '0;
    // tap 13: 4
    assign t13 = (xe13 <<< 2);
    // tap 14: -1
    assign t14 = - xe14;
    // tap 15: 0
    assign t15 = '0;
    // tap 16: 1
    assign t16 = xe16;
    // tap 17: -3
    assign t17 = - (xe17 <<< 2) + xe17;
    // tap 18: 2
    assign t18 = (xe18 <<< 1);
    // tap 19: -2
    assign t19 = - (xe19 <<< 1);
    // tap 20: -1
    assign t20 = - xe20;
    // tap 21: 1
    assign t21 = xe21;
    // tap 22: -2
    assign t22 = - (xe22 <<< 1);
    // tap 23: 1
    assign t23 = xe23;
    // tap 24: -2
    assign t24 = - (xe24 <<< 1);
    // tap 25: 0
    assign t25 = '0;
    // tap 26: 0
    assign t26 = '0;
    // tap 27: -1
    assign t27 = - xe27;
    // tap 28: 1
    assign t28 = xe28;
    // tap 29: -2
    assign t29 = - (xe29 <<< 1);
    // tap 30: 1
    assign t30 = xe30;
    // tap 31: -1
    assign t31 = - xe31;

    logic signed [16:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23 + t24 + t25 + t26 + t27 + t28 + t29 + t30 + t31;

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
            x16 <= 8'sd0;
            x17 <= 8'sd0;
            x18 <= 8'sd0;
            x19 <= 8'sd0;
            x20 <= 8'sd0;
            x21 <= 8'sd0;
            x22 <= 8'sd0;
            x23 <= 8'sd0;
            x24 <= 8'sd0;
            x25 <= 8'sd0;
            x26 <= 8'sd0;
            x27 <= 8'sd0;
            x28 <= 8'sd0;
            x29 <= 8'sd0;
            x30 <= 8'sd0;
            x31 <= 8'sd0;
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
