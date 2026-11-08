// loss40 24-tap P12: 24-tap FFE, per-tap CSD shift-add, Q3.8 samples, Q1.10 coefficients.
// Coefficients [-92, 287, -601, 1048, -1531, 1536, -383, 4, 175, -251, 226, -174, 101, -68, 35, -57, 67, -71, 43, 3, -78, 89, 1, -117].
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

    // tap 0: -92
    assign t0 = - (xe0 <<< 7) + (xe0 <<< 5) + (xe0 <<< 2);
    // tap 1: 287
    assign t1 = (xe1 <<< 8) + (xe1 <<< 5) - xe1;
    // tap 2: -601
    assign t2 = - (xe2 <<< 9) - (xe2 <<< 7) + (xe2 <<< 5) + (xe2 <<< 3) - xe2;
    // tap 3: 1048
    assign t3 = (xe3 <<< 10) + (xe3 <<< 5) - (xe3 <<< 3);
    // tap 4: -1531
    assign t4 = - (xe4 <<< 11) + (xe4 <<< 9) + (xe4 <<< 2) + xe4;
    // tap 5: 1536
    assign t5 = (xe5 <<< 11) - (xe5 <<< 9);
    // tap 6: -383
    assign t6 = - (xe6 <<< 9) + (xe6 <<< 7) + xe6;
    // tap 7: 4
    assign t7 = (xe7 <<< 2);
    // tap 8: 175
    assign t8 = (xe8 <<< 8) - (xe8 <<< 6) - (xe8 <<< 4) - xe8;
    // tap 9: -251
    assign t9 = - (xe9 <<< 8) + (xe9 <<< 2) + xe9;
    // tap 10: 226
    assign t10 = (xe10 <<< 8) - (xe10 <<< 5) + (xe10 <<< 1);
    // tap 11: -174
    assign t11 = - (xe11 <<< 8) + (xe11 <<< 6) + (xe11 <<< 4) + (xe11 <<< 1);
    // tap 12: 101
    assign t12 = (xe12 <<< 7) - (xe12 <<< 5) + (xe12 <<< 2) + xe12;
    // tap 13: -68
    assign t13 = - (xe13 <<< 6) - (xe13 <<< 2);
    // tap 14: 35
    assign t14 = (xe14 <<< 5) + (xe14 <<< 2) - xe14;
    // tap 15: -57
    assign t15 = - (xe15 <<< 6) + (xe15 <<< 3) - xe15;
    // tap 16: 67
    assign t16 = (xe16 <<< 6) + (xe16 <<< 2) - xe16;
    // tap 17: -71
    assign t17 = - (xe17 <<< 6) - (xe17 <<< 3) + xe17;
    // tap 18: 43
    assign t18 = (xe18 <<< 6) - (xe18 <<< 4) - (xe18 <<< 2) - xe18;
    // tap 19: 3
    assign t19 = (xe19 <<< 2) - xe19;
    // tap 20: -78
    assign t20 = - (xe20 <<< 6) - (xe20 <<< 4) + (xe20 <<< 1);
    // tap 21: 89
    assign t21 = (xe21 <<< 7) - (xe21 <<< 5) - (xe21 <<< 3) + xe21;
    // tap 22: 1
    assign t22 = xe22;
    // tap 23: -117
    assign t23 = - (xe23 <<< 7) + (xe23 <<< 4) - (xe23 <<< 2) - xe23;

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
