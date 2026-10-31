// loss30 16-tap P12: 16-tap FFE, per-tap CSD shift-add, Q3.8 samples, Q1.10 coefficients.
// Coefficients [55, -143, 275, -485, 814, -1275, 1536, -35, -5, 66, -14, -7, 23, -45, 34, -48].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15;
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
    logic signed [24:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15;

    // tap 0: 55
    assign t0 = (xe0 <<< 6) - (xe0 <<< 3) - xe0;
    // tap 1: -143
    assign t1 = - (xe1 <<< 7) - (xe1 <<< 4) + xe1;
    // tap 2: 275
    assign t2 = (xe2 <<< 8) + (xe2 <<< 4) + (xe2 <<< 2) - xe2;
    // tap 3: -485
    assign t3 = - (xe3 <<< 9) + (xe3 <<< 5) - (xe3 <<< 2) - xe3;
    // tap 4: 814
    assign t4 = (xe4 <<< 10) - (xe4 <<< 8) + (xe4 <<< 6) - (xe4 <<< 4) - (xe4 <<< 1);
    // tap 5: -1275
    assign t5 = - (xe5 <<< 10) - (xe5 <<< 8) + (xe5 <<< 2) + xe5;
    // tap 6: 1536
    assign t6 = (xe6 <<< 11) - (xe6 <<< 9);
    // tap 7: -35
    assign t7 = - (xe7 <<< 5) - (xe7 <<< 2) + xe7;
    // tap 8: -5
    assign t8 = - (xe8 <<< 2) - xe8;
    // tap 9: 66
    assign t9 = (xe9 <<< 6) + (xe9 <<< 1);
    // tap 10: -14
    assign t10 = - (xe10 <<< 4) + (xe10 <<< 1);
    // tap 11: -7
    assign t11 = - (xe11 <<< 3) + xe11;
    // tap 12: 23
    assign t12 = (xe12 <<< 5) - (xe12 <<< 3) - xe12;
    // tap 13: -45
    assign t13 = - (xe13 <<< 6) + (xe13 <<< 4) + (xe13 <<< 2) - xe13;
    // tap 14: 34
    assign t14 = (xe14 <<< 5) + (xe14 <<< 1);
    // tap 15: -48
    assign t15 = - (xe15 <<< 6) + (xe15 <<< 4);

    logic signed [24:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15;

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
            y_out <= y_next;
        end
    end
endmodule
