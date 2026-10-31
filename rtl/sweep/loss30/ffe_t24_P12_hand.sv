// loss30 24-tap P12: 24-tap FFE, per-tap CSD shift-add, Q3.8 samples, Q1.10 coefficients.
// Coefficients [-12, 29, -57, 99, -171, 291, -492, 818, -1276, 1536, -37, -3, 66, -14, -5, 21, -42, 29, -40, -12, 11, -38, 19, -26].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, x17, x18, x19, x20, x21, x22, x23;
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
    logic signed [24:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23;

    // tap 0: -12
    assign t0 = - (xe0 <<< 4) + (xe0 <<< 2);
    // tap 1: 29
    assign t1 = (xe1 <<< 5) - (xe1 <<< 2) + xe1;
    // tap 2: -57
    assign t2 = - (xe2 <<< 6) + (xe2 <<< 3) - xe2;
    // tap 3: 99
    assign t3 = (xe3 <<< 7) - (xe3 <<< 5) + (xe3 <<< 2) - xe3;
    // tap 4: -171
    assign t4 = - (xe4 <<< 8) + (xe4 <<< 6) + (xe4 <<< 4) + (xe4 <<< 2) + xe4;
    // tap 5: 291
    assign t5 = (xe5 <<< 8) + (xe5 <<< 5) + (xe5 <<< 2) - xe5;
    // tap 6: -492
    assign t6 = - (xe6 <<< 9) + (xe6 <<< 4) + (xe6 <<< 2);
    // tap 7: 818
    assign t7 = (xe7 <<< 10) - (xe7 <<< 8) + (xe7 <<< 6) - (xe7 <<< 4) + (xe7 <<< 1);
    // tap 8: -1276
    assign t8 = - (xe8 <<< 10) - (xe8 <<< 8) + (xe8 <<< 2);
    // tap 9: 1536
    assign t9 = (xe9 <<< 11) - (xe9 <<< 9);
    // tap 10: -37
    assign t10 = - (xe10 <<< 5) - (xe10 <<< 2) - xe10;
    // tap 11: -3
    assign t11 = - (xe11 <<< 2) + xe11;
    // tap 12: 66
    assign t12 = (xe12 <<< 6) + (xe12 <<< 1);
    // tap 13: -14
    assign t13 = - (xe13 <<< 4) + (xe13 <<< 1);
    // tap 14: -5
    assign t14 = - (xe14 <<< 2) - xe14;
    // tap 15: 21
    assign t15 = (xe15 <<< 4) + (xe15 <<< 2) + xe15;
    // tap 16: -42
    assign t16 = - (xe16 <<< 5) - (xe16 <<< 3) - (xe16 <<< 1);
    // tap 17: 29
    assign t17 = (xe17 <<< 5) - (xe17 <<< 2) + xe17;
    // tap 18: -40
    assign t18 = - (xe18 <<< 5) - (xe18 <<< 3);
    // tap 19: -12
    assign t19 = - (xe19 <<< 4) + (xe19 <<< 2);
    // tap 20: 11
    assign t20 = (xe20 <<< 4) - (xe20 <<< 2) - xe20;
    // tap 21: -38
    assign t21 = - (xe21 <<< 5) - (xe21 <<< 3) + (xe21 <<< 1);
    // tap 22: 19
    assign t22 = (xe22 <<< 4) + (xe22 <<< 2) - xe22;
    // tap 23: -26
    assign t23 = - (xe23 <<< 5) + (xe23 <<< 3) - (xe23 <<< 1);

    logic signed [24:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15 + t16 + t17 + t18 + t19 + t20 + t21 + t22 + t23;

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
            y_out <= y_next;
        end
    end
endmodule
