// loss30 48-tap P10: 48-tap FFE, per-tap CSD shift-add, Q3.6 samples, Q1.8 coefficients.
// Coefficients [-1, 2, -5, 9, -15, 25, -43, 73, -123, 204, -319, 384, -9, -1, 17, -4, -1, 5, -10, 7, -10, -3, 3, -10, 5, -8, 2, -2, -3, 2, -6, 3, -2, -1, 2, -4, 2, -2, 0, 0, -1, 0, -1, -1, 0, -2, 1, -1].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [9:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31, x32, x33, x34, x35, x36, x37, x38, x39, x40, x41, x42, x43, x44, x45, x46, x47;
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
    logic signed [20:0] xe24; assign xe24 = x24;
    logic signed [20:0] xe25; assign xe25 = x25;
    logic signed [20:0] xe26; assign xe26 = x26;
    logic signed [20:0] xe27; assign xe27 = x27;
    logic signed [20:0] xe28; assign xe28 = x28;
    logic signed [20:0] xe29; assign xe29 = x29;
    logic signed [20:0] xe30; assign xe30 = x30;
    logic signed [20:0] xe31; assign xe31 = x31;
    logic signed [20:0] xe32; assign xe32 = x32;
    logic signed [20:0] xe33; assign xe33 = x33;
    logic signed [20:0] xe34; assign xe34 = x34;
    logic signed [20:0] xe35; assign xe35 = x35;
    logic signed [20:0] xe36; assign xe36 = x36;
    logic signed [20:0] xe37; assign xe37 = x37;
    logic signed [20:0] xe38; assign xe38 = x38;
    logic signed [20:0] xe39; assign xe39 = x39;
    logic signed [20:0] xe40; assign xe40 = x40;
    logic signed [20:0] xe41; assign xe41 = x41;
    logic signed [20:0] xe42; assign xe42 = x42;
    logic signed [20:0] xe43; assign xe43 = x43;
    logic signed [20:0] xe44; assign xe44 = x44;
    logic signed [20:0] xe45; assign xe45 = x45;
    logic signed [20:0] xe46; assign xe46 = x46;
    logic signed [20:0] xe47; assign xe47 = x47;
    logic signed [20:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31, t32, t33, t34, t35, t36, t37, t38, t39, t40, t41, t42, t43, t44, t45, t46, t47;

    // tap 0: -1
    assign t0 = - xe0;
    // tap 1: 2
    assign t1 = (xe1 <<< 1);
    // tap 2: -5
    assign t2 = - (xe2 <<< 2) - xe2;
    // tap 3: 9
    assign t3 = (xe3 <<< 3) + xe3;
    // tap 4: -15
    assign t4 = - (xe4 <<< 4) + xe4;
    // tap 5: 25
    assign t5 = (xe5 <<< 5) - (xe5 <<< 3) + xe5;
    // tap 6: -43
    assign t6 = - (xe6 <<< 6) + (xe6 <<< 4) + (xe6 <<< 2) + xe6;
    // tap 7: 73
    assign t7 = (xe7 <<< 6) + (xe7 <<< 3) + xe7;
    // tap 8: -123
    assign t8 = - (xe8 <<< 7) + (xe8 <<< 2) + xe8;
    // tap 9: 204
    assign t9 = (xe9 <<< 8) - (xe9 <<< 6) + (xe9 <<< 4) - (xe9 <<< 2);
    // tap 10: -319
    assign t10 = - (xe10 <<< 8) - (xe10 <<< 6) + xe10;
    // tap 11: 384
    assign t11 = (xe11 <<< 9) - (xe11 <<< 7);
    // tap 12: -9
    assign t12 = - (xe12 <<< 3) - xe12;
    // tap 13: -1
    assign t13 = - xe13;
    // tap 14: 17
    assign t14 = (xe14 <<< 4) + xe14;
    // tap 15: -4
    assign t15 = - (xe15 <<< 2);
    // tap 16: -1
    assign t16 = - xe16;
    // tap 17: 5
    assign t17 = (xe17 <<< 2) + xe17;
    // tap 18: -10
    assign t18 = - (xe18 <<< 3) - (xe18 <<< 1);
    // tap 19: 7
    assign t19 = (xe19 <<< 3) - xe19;
    // tap 20: -10
    assign t20 = - (xe20 <<< 3) - (xe20 <<< 1);
    // tap 21: -3
    assign t21 = - (xe21 <<< 2) + xe21;
    // tap 22: 3
    assign t22 = (xe22 <<< 2) - xe22;
    // tap 23: -10
    assign t23 = - (xe23 <<< 3) - (xe23 <<< 1);
    // tap 24: 5
    assign t24 = (xe24 <<< 2) + xe24;
    // tap 25: -8
    assign t25 = - (xe25 <<< 3);
    // tap 26: 2
    assign t26 = (xe26 <<< 1);
    // tap 27: -2
    assign t27 = - (xe27 <<< 1);
    // tap 28: -3
    assign t28 = - (xe28 <<< 2) + xe28;
    // tap 29: 2
    assign t29 = (xe29 <<< 1);
    // tap 30: -6
    assign t30 = - (xe30 <<< 3) + (xe30 <<< 1);
    // tap 31: 3
    assign t31 = (xe31 <<< 2) - xe31;
    // tap 32: -2
    assign t32 = - (xe32 <<< 1);
    // tap 33: -1
    assign t33 = - xe33;
    // tap 34: 2
    assign t34 = (xe34 <<< 1);
    // tap 35: -4
    assign t35 = - (xe35 <<< 2);
    // tap 36: 2
    assign t36 = (xe36 <<< 1);
    // tap 37: -2
    assign t37 = - (xe37 <<< 1);
    // tap 38: 0
    assign t38 = '0;
    // tap 39: 0
    assign t39 = '0;
    // tap 40: -1
    assign t40 = - xe40;
    // tap 41: 0
    assign t41 = '0;
    // tap 42: -1
    assign t42 = - xe42;
    // tap 43: -1
    assign t43 = - xe43;
    // tap 44: 0
    assign t44 = '0;
    // tap 45: -2
    assign t45 = - (xe45 <<< 1);
    // tap 46: 1
    assign t46 = xe46;
    // tap 47: -1
    assign t47 = - xe47;

    logic signed [20:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23 + t24 + t25 + t26 + t27 + t28 + t29 + t30 + t31 + t32 + t33 + t34 + t35 + t36 + t37 + t38 + t39 + t40 + t41 + t42 + t43 + t44 + t45 + t46 + t47;

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
            x24 <= 10'sd0;
            x25 <= 10'sd0;
            x26 <= 10'sd0;
            x27 <= 10'sd0;
            x28 <= 10'sd0;
            x29 <= 10'sd0;
            x30 <= 10'sd0;
            x31 <= 10'sd0;
            x32 <= 10'sd0;
            x33 <= 10'sd0;
            x34 <= 10'sd0;
            x35 <= 10'sd0;
            x36 <= 10'sd0;
            x37 <= 10'sd0;
            x38 <= 10'sd0;
            x39 <= 10'sd0;
            x40 <= 10'sd0;
            x41 <= 10'sd0;
            x42 <= 10'sd0;
            x43 <= 10'sd0;
            x44 <= 10'sd0;
            x45 <= 10'sd0;
            x46 <= 10'sd0;
            x47 <= 10'sd0;
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
