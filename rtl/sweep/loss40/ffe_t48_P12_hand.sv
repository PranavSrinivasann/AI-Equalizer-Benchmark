// loss40 48-tap P12: 48-tap FFE, per-tap CSD shift-add, Q3.8 samples, Q1.10 coefficients.
// Coefficients [7, -21, 44, -80, 138, -238, 406, -684, 1094, -1536, 1516, -389, -13, 200, -268, 232, -173, 98, -61, 22, -36, 45, -66, 61, -50, 25, -85, 257, -441, 326, -191, 39, 58, -98, 93, -83, 59, -30, 5, 8, -6, -5, 13, -6, -14, 26, -18, 5].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30, x31, x32, x33, x34, x35, x36, x37, x38, x39, x40, x41, x42, x43, x44, x45, x46, x47;
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
    logic signed [25:0] xe32; assign xe32 = x32;
    logic signed [25:0] xe33; assign xe33 = x33;
    logic signed [25:0] xe34; assign xe34 = x34;
    logic signed [25:0] xe35; assign xe35 = x35;
    logic signed [25:0] xe36; assign xe36 = x36;
    logic signed [25:0] xe37; assign xe37 = x37;
    logic signed [25:0] xe38; assign xe38 = x38;
    logic signed [25:0] xe39; assign xe39 = x39;
    logic signed [25:0] xe40; assign xe40 = x40;
    logic signed [25:0] xe41; assign xe41 = x41;
    logic signed [25:0] xe42; assign xe42 = x42;
    logic signed [25:0] xe43; assign xe43 = x43;
    logic signed [25:0] xe44; assign xe44 = x44;
    logic signed [25:0] xe45; assign xe45 = x45;
    logic signed [25:0] xe46; assign xe46 = x46;
    logic signed [25:0] xe47; assign xe47 = x47;
    logic signed [25:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31, t32, t33, t34, t35, t36, t37, t38, t39, t40, t41, t42, t43, t44, t45, t46, t47;

    // tap 0: 7
    assign t0 = (xe0 <<< 3) - xe0;
    // tap 1: -21
    assign t1 = - (xe1 <<< 4) - (xe1 <<< 2) - xe1;
    // tap 2: 44
    assign t2 = (xe2 <<< 6) - (xe2 <<< 4) - (xe2 <<< 2);
    // tap 3: -80
    assign t3 = - (xe3 <<< 6) - (xe3 <<< 4);
    // tap 4: 138
    assign t4 = (xe4 <<< 7) + (xe4 <<< 3) + (xe4 <<< 1);
    // tap 5: -238
    assign t5 = - (xe5 <<< 8) + (xe5 <<< 4) + (xe5 <<< 1);
    // tap 6: 406
    assign t6 = (xe6 <<< 9) - (xe6 <<< 7) + (xe6 <<< 5) - (xe6 <<< 3) - (xe6 <<< 1);
    // tap 7: -684
    assign t7 = - (xe7 <<< 10) + (xe7 <<< 8) + (xe7 <<< 6) + (xe7 <<< 4) + (xe7 <<< 2);
    // tap 8: 1094
    assign t8 = (xe8 <<< 10) + (xe8 <<< 6) + (xe8 <<< 3) - (xe8 <<< 1);
    // tap 9: -1536
    assign t9 = - (xe9 <<< 11) + (xe9 <<< 9);
    // tap 10: 1516
    assign t10 = (xe10 <<< 11) - (xe10 <<< 9) - (xe10 <<< 4) - (xe10 <<< 2);
    // tap 11: -389
    assign t11 = - (xe11 <<< 9) + (xe11 <<< 7) - (xe11 <<< 2) - xe11;
    // tap 12: -13
    assign t12 = - (xe12 <<< 4) + (xe12 <<< 2) - xe12;
    // tap 13: 200
    assign t13 = (xe13 <<< 8) - (xe13 <<< 6) + (xe13 <<< 3);
    // tap 14: -268
    assign t14 = - (xe14 <<< 8) - (xe14 <<< 4) + (xe14 <<< 2);
    // tap 15: 232
    assign t15 = (xe15 <<< 8) - (xe15 <<< 5) + (xe15 <<< 3);
    // tap 16: -173
    assign t16 = - (xe16 <<< 8) + (xe16 <<< 6) + (xe16 <<< 4) + (xe16 <<< 2) - xe16;
    // tap 17: 98
    assign t17 = (xe17 <<< 7) - (xe17 <<< 5) + (xe17 <<< 1);
    // tap 18: -61
    assign t18 = - (xe18 <<< 6) + (xe18 <<< 2) - xe18;
    // tap 19: 22
    assign t19 = (xe19 <<< 5) - (xe19 <<< 3) - (xe19 <<< 1);
    // tap 20: -36
    assign t20 = - (xe20 <<< 5) - (xe20 <<< 2);
    // tap 21: 45
    assign t21 = (xe21 <<< 6) - (xe21 <<< 4) - (xe21 <<< 2) + xe21;
    // tap 22: -66
    assign t22 = - (xe22 <<< 6) - (xe22 <<< 1);
    // tap 23: 61
    assign t23 = (xe23 <<< 6) - (xe23 <<< 2) + xe23;
    // tap 24: -50
    assign t24 = - (xe24 <<< 6) + (xe24 <<< 4) - (xe24 <<< 1);
    // tap 25: 25
    assign t25 = (xe25 <<< 5) - (xe25 <<< 3) + xe25;
    // tap 26: -85
    assign t26 = - (xe26 <<< 6) - (xe26 <<< 4) - (xe26 <<< 2) - xe26;
    // tap 27: 257
    assign t27 = (xe27 <<< 8) + xe27;
    // tap 28: -441
    assign t28 = - (xe28 <<< 9) + (xe28 <<< 6) + (xe28 <<< 3) - xe28;
    // tap 29: 326
    assign t29 = (xe29 <<< 8) + (xe29 <<< 6) + (xe29 <<< 3) - (xe29 <<< 1);
    // tap 30: -191
    assign t30 = - (xe30 <<< 8) + (xe30 <<< 6) + xe30;
    // tap 31: 39
    assign t31 = (xe31 <<< 5) + (xe31 <<< 3) - xe31;
    // tap 32: 58
    assign t32 = (xe32 <<< 6) - (xe32 <<< 3) + (xe32 <<< 1);
    // tap 33: -98
    assign t33 = - (xe33 <<< 7) + (xe33 <<< 5) - (xe33 <<< 1);
    // tap 34: 93
    assign t34 = (xe34 <<< 7) - (xe34 <<< 5) - (xe34 <<< 2) + xe34;
    // tap 35: -83
    assign t35 = - (xe35 <<< 6) - (xe35 <<< 4) - (xe35 <<< 2) + xe35;
    // tap 36: 59
    assign t36 = (xe36 <<< 6) - (xe36 <<< 2) - xe36;
    // tap 37: -30
    assign t37 = - (xe37 <<< 5) + (xe37 <<< 1);
    // tap 38: 5
    assign t38 = (xe38 <<< 2) + xe38;
    // tap 39: 8
    assign t39 = (xe39 <<< 3);
    // tap 40: -6
    assign t40 = - (xe40 <<< 3) + (xe40 <<< 1);
    // tap 41: -5
    assign t41 = - (xe41 <<< 2) - xe41;
    // tap 42: 13
    assign t42 = (xe42 <<< 4) - (xe42 <<< 2) + xe42;
    // tap 43: -6
    assign t43 = - (xe43 <<< 3) + (xe43 <<< 1);
    // tap 44: -14
    assign t44 = - (xe44 <<< 4) + (xe44 <<< 1);
    // tap 45: 26
    assign t45 = (xe45 <<< 5) - (xe45 <<< 3) + (xe45 <<< 1);
    // tap 46: -18
    assign t46 = - (xe46 <<< 4) - (xe46 <<< 1);
    // tap 47: 5
    assign t47 = (xe47 <<< 2) + xe47;

    logic signed [25:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23 + t24 + t25 + t26 + t27 + t28 + t29 + t30 + t31 + t32 + t33 + t34 + t35 + t36 + t37 + t38 + t39 + t40 + t41 + t42 + t43 + t44 + t45 + t46 + t47;

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
            x32 <= 12'sd0;
            x33 <= 12'sd0;
            x34 <= 12'sd0;
            x35 <= 12'sd0;
            x36 <= 12'sd0;
            x37 <= 12'sd0;
            x38 <= 12'sd0;
            x39 <= 12'sd0;
            x40 <= 12'sd0;
            x41 <= 12'sd0;
            x42 <= 12'sd0;
            x43 <= 12'sd0;
            x44 <= 12'sd0;
            x45 <= 12'sd0;
            x46 <= 12'sd0;
            x47 <= 12'sd0;
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
