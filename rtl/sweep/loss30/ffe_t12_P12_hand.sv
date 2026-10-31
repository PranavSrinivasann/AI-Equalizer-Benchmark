// loss30 12-tap P12: 12-tap FFE, per-tap CSD shift-add, Q3.8 samples, Q1.10 coefficients.
// Coefficients [19, -51, 96, -171, 289, -492, 815, -1276, 1536, -41, 5, 52].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11;
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
    logic signed [24:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11;

    // tap 0: 19
    assign t0 = (xe0 <<< 4) + (xe0 <<< 2) - xe0;
    // tap 1: -51
    assign t1 = - (xe1 <<< 6) + (xe1 <<< 4) - (xe1 <<< 2) + xe1;
    // tap 2: 96
    assign t2 = (xe2 <<< 7) - (xe2 <<< 5);
    // tap 3: -171
    assign t3 = - (xe3 <<< 8) + (xe3 <<< 6) + (xe3 <<< 4) + (xe3 <<< 2) + xe3;
    // tap 4: 289
    assign t4 = (xe4 <<< 8) + (xe4 <<< 5) + xe4;
    // tap 5: -492
    assign t5 = - (xe5 <<< 9) + (xe5 <<< 4) + (xe5 <<< 2);
    // tap 6: 815
    assign t6 = (xe6 <<< 10) - (xe6 <<< 8) + (xe6 <<< 6) - (xe6 <<< 4) - xe6;
    // tap 7: -1276
    assign t7 = - (xe7 <<< 10) - (xe7 <<< 8) + (xe7 <<< 2);
    // tap 8: 1536
    assign t8 = (xe8 <<< 11) - (xe8 <<< 9);
    // tap 9: -41
    assign t9 = - (xe9 <<< 5) - (xe9 <<< 3) - xe9;
    // tap 10: 5
    assign t10 = (xe10 <<< 2) + xe10;
    // tap 11: 52
    assign t11 = (xe11 <<< 6) - (xe11 <<< 4) + (xe11 <<< 2);

    logic signed [24:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11;

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
            y_out <= y_next;
        end
    end
endmodule
