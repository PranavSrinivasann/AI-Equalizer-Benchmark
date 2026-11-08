// loss30 48-tap P8: 48-tap FFE, per-tap CSD shift-add, Q3.4 samples, Q1.6 coefficients.
// Coefficients [0, 1, -1, 2, -4, 6, -11, 18, -31, 51, -80, 96, -2, 0, 4, -1, 0, 1, -3, 2, -2, -1, 1, -2, 1, -2, 0, 0, -1, 1, -1, 1, -1, 0, 0, -1, 1, -1, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [7:0] x_in,
    output logic signed [7:0] y_out
);

    logic signed [7:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31, x32, x33, x34, x35, x36, x37, x38, x39, x40, x41, x42, x43, x44, x45, x46, x47;
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
    logic signed [16:0] xe32; assign xe32 = x32;
    logic signed [16:0] xe33; assign xe33 = x33;
    logic signed [16:0] xe34; assign xe34 = x34;
    logic signed [16:0] xe35; assign xe35 = x35;
    logic signed [16:0] xe36; assign xe36 = x36;
    logic signed [16:0] xe37; assign xe37 = x37;
    logic signed [16:0] xe38; assign xe38 = x38;
    logic signed [16:0] xe39; assign xe39 = x39;
    logic signed [16:0] xe40; assign xe40 = x40;
    logic signed [16:0] xe41; assign xe41 = x41;
    logic signed [16:0] xe42; assign xe42 = x42;
    logic signed [16:0] xe43; assign xe43 = x43;
    logic signed [16:0] xe44; assign xe44 = x44;
    logic signed [16:0] xe45; assign xe45 = x45;
    logic signed [16:0] xe46; assign xe46 = x46;
    logic signed [16:0] xe47; assign xe47 = x47;
    logic signed [16:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31, t32, t33, t34, t35, t36, t37, t38, t39, t40, t41, t42, t43, t44, t45, t46, t47;

    // tap 0: 0
    assign t0 = '0;
    // tap 1: 1
    assign t1 = xe1;
    // tap 2: -1
    assign t2 = - xe2;
    // tap 3: 2
    assign t3 = (xe3 <<< 1);
    // tap 4: -4
    assign t4 = - (xe4 <<< 2);
    // tap 5: 6
    assign t5 = (xe5 <<< 3) - (xe5 <<< 1);
    // tap 6: -11
    assign t6 = - (xe6 <<< 4) + (xe6 <<< 2) + xe6;
    // tap 7: 18
    assign t7 = (xe7 <<< 4) + (xe7 <<< 1);
    // tap 8: -31
    assign t8 = - (xe8 <<< 5) + xe8;
    // tap 9: 51
    assign t9 = (xe9 <<< 6) - (xe9 <<< 4) + (xe9 <<< 2) - xe9;
    // tap 10: -80
    assign t10 = - (xe10 <<< 6) - (xe10 <<< 4);
    // tap 11: 96
    assign t11 = (xe11 <<< 7) - (xe11 <<< 5);
    // tap 12: -2
    assign t12 = - (xe12 <<< 1);
    // tap 13: 0
    assign t13 = '0;
    // tap 14: 4
    assign t14 = (xe14 <<< 2);
    // tap 15: -1
    assign t15 = - xe15;
    // tap 16: 0
    assign t16 = '0;
    // tap 17: 1
    assign t17 = xe17;
    // tap 18: -3
    assign t18 = - (xe18 <<< 2) + xe18;
    // tap 19: 2
    assign t19 = (xe19 <<< 1);
    // tap 20: -2
    assign t20 = - (xe20 <<< 1);
    // tap 21: -1
    assign t21 = - xe21;
    // tap 22: 1
    assign t22 = xe22;
    // tap 23: -2
    assign t23 = - (xe23 <<< 1);
    // tap 24: 1
    assign t24 = xe24;
    // tap 25: -2
    assign t25 = - (xe25 <<< 1);
    // tap 26: 0
    assign t26 = '0;
    // tap 27: 0
    assign t27 = '0;
    // tap 28: -1
    assign t28 = - xe28;
    // tap 29: 1
    assign t29 = xe29;
    // tap 30: -1
    assign t30 = - xe30;
    // tap 31: 1
    assign t31 = xe31;
    // tap 32: -1
    assign t32 = - xe32;
    // tap 33: 0
    assign t33 = '0;
    // tap 34: 0
    assign t34 = '0;
    // tap 35: -1
    assign t35 = - xe35;
    // tap 36: 1
    assign t36 = xe36;
    // tap 37: -1
    assign t37 = - xe37;
    // tap 38: 0
    assign t38 = '0;
    // tap 39: 0
    assign t39 = '0;
    // tap 40: 0
    assign t40 = '0;
    // tap 41: 0
    assign t41 = '0;
    // tap 42: 0
    assign t42 = '0;
    // tap 43: 0
    assign t43 = '0;
    // tap 44: 0
    assign t44 = '0;
    // tap 45: -1
    assign t45 = - xe45;
    // tap 46: 0
    assign t46 = '0;
    // tap 47: 0
    assign t47 = '0;

    logic signed [16:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23 + t24 + t25 + t26 + t27 + t28 + t29 + t30 + t31 + t32 + t33 + t34 + t35 + t36 + t37 + t38 + t39 + t40 + t41 + t42 + t43 + t44 + t45 + t46 + t47;

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
            x32 <= 8'sd0;
            x33 <= 8'sd0;
            x34 <= 8'sd0;
            x35 <= 8'sd0;
            x36 <= 8'sd0;
            x37 <= 8'sd0;
            x38 <= 8'sd0;
            x39 <= 8'sd0;
            x40 <= 8'sd0;
            x41 <= 8'sd0;
            x42 <= 8'sd0;
            x43 <= 8'sd0;
            x44 <= 8'sd0;
            x45 <= 8'sd0;
            x46 <= 8'sd0;
            x47 <= 8'sd0;
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
            x32 <= x31;
            x33 <= x32;
            x34 <= x33;
            x35 <= x34;
            x36 <= x35;
            x37 <= x36;
            x38 <= x37;
            x39 <= x38;
            x40 <= x39;
            x41 <= x40;
            x42 <= x41;
            x43 <= x42;
            x44 <= x43;
            x45 <= x44;
            x46 <= x45;
            x47 <= x46;
            y_out <= y_next;
        end
    end
endmodule
