// loss30 12-tap P10: 12-tap FFE, per-tap CSD shift-add, Q3.6 samples, Q1.8 coefficients.
// Coefficients [5, -13, 24, -43, 72, -123, 204, -319, 384, -10, 1, 13].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [9:0] x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11;
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
    logic signed [20:0] t0, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11;

    // tap 0: 5
    assign t0 = (xe0 <<< 2) + xe0;
    // tap 1: -13
    assign t1 = - (xe1 <<< 4) + (xe1 <<< 2) - xe1;
    // tap 2: 24
    assign t2 = (xe2 <<< 5) - (xe2 <<< 3);
    // tap 3: -43
    assign t3 = - (xe3 <<< 6) + (xe3 <<< 4) + (xe3 <<< 2) + xe3;
    // tap 4: 72
    assign t4 = (xe4 <<< 6) + (xe4 <<< 3);
    // tap 5: -123
    assign t5 = - (xe5 <<< 7) + (xe5 <<< 2) + xe5;
    // tap 6: 204
    assign t6 = (xe6 <<< 8) - (xe6 <<< 6) + (xe6 <<< 4) - (xe6 <<< 2);
    // tap 7: -319
    assign t7 = - (xe7 <<< 8) - (xe7 <<< 6) + xe7;
    // tap 8: 384
    assign t8 = (xe8 <<< 9) - (xe8 <<< 7);
    // tap 9: -10
    assign t9 = - (xe9 <<< 3) - (xe9 <<< 1);
    // tap 10: 1
    assign t10 = xe10;
    // tap 11: 13
    assign t11 = (xe11 <<< 4) - (xe11 <<< 2) + xe11;

    logic signed [20:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11;

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
            y_out <= y_next;
        end
    end
endmodule
