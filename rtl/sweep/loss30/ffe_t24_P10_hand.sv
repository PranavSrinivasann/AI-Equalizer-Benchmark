// loss30 24-tap P10: 24-tap FFE, per-tap CSD shift-add, Q3.6 samples, Q1.8 coefficients.
// Coefficients [-3, 7, -14, 25, -43, 73, -123, 204, -319, 384, -9, -1, 17, -3, -1, 5, -10, 7, -10, -3, 3, -10, 5, -7].
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

    // tap 0: -3
    assign t0 = - (xe0 <<< 2) + xe0;
    // tap 1: 7
    assign t1 = (xe1 <<< 3) - xe1;
    // tap 2: -14
    assign t2 = - (xe2 <<< 4) + (xe2 <<< 1);
    // tap 3: 25
    assign t3 = (xe3 <<< 5) - (xe3 <<< 3) + xe3;
    // tap 4: -43
    assign t4 = - (xe4 <<< 6) + (xe4 <<< 4) + (xe4 <<< 2) + xe4;
    // tap 5: 73
    assign t5 = (xe5 <<< 6) + (xe5 <<< 3) + xe5;
    // tap 6: -123
    assign t6 = - (xe6 <<< 7) + (xe6 <<< 2) + xe6;
    // tap 7: 204
    assign t7 = (xe7 <<< 8) - (xe7 <<< 6) + (xe7 <<< 4) - (xe7 <<< 2);
    // tap 8: -319
    assign t8 = - (xe8 <<< 8) - (xe8 <<< 6) + xe8;
    // tap 9: 384
    assign t9 = (xe9 <<< 9) - (xe9 <<< 7);
    // tap 10: -9
    assign t10 = - (xe10 <<< 3) - xe10;
    // tap 11: -1
    assign t11 = - xe11;
    // tap 12: 17
    assign t12 = (xe12 <<< 4) + xe12;
    // tap 13: -3
    assign t13 = - (xe13 <<< 2) + xe13;
    // tap 14: -1
    assign t14 = - xe14;
    // tap 15: 5
    assign t15 = (xe15 <<< 2) + xe15;
    // tap 16: -10
    assign t16 = - (xe16 <<< 3) - (xe16 <<< 1);
    // tap 17: 7
    assign t17 = (xe17 <<< 3) - xe17;
    // tap 18: -10
    assign t18 = - (xe18 <<< 3) - (xe18 <<< 1);
    // tap 19: -3
    assign t19 = - (xe19 <<< 2) + xe19;
    // tap 20: 3
    assign t20 = (xe20 <<< 2) - xe20;
    // tap 21: -10
    assign t21 = - (xe21 <<< 3) - (xe21 <<< 1);
    // tap 22: 5
    assign t22 = (xe22 <<< 2) + xe22;
    // tap 23: -7
    assign t23 = - (xe23 <<< 3) + xe23;

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
