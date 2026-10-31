// loss30 8-tap P10: 8-tap FFE, per-tap CSD shift-add, Q3.6 samples, Q1.8 coefficients.
// Coefficients [-9, 22, -42, 73, -124, 205, -321, 384].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [9:0] x1, x2, x3, x4, x5, x6, x7;
    logic signed [20:0] xe0; assign xe0 = x_in;
    logic signed [20:0] xe1; assign xe1 = x1;
    logic signed [20:0] xe2; assign xe2 = x2;
    logic signed [20:0] xe3; assign xe3 = x3;
    logic signed [20:0] xe4; assign xe4 = x4;
    logic signed [20:0] xe5; assign xe5 = x5;
    logic signed [20:0] xe6; assign xe6 = x6;
    logic signed [20:0] xe7; assign xe7 = x7;
    logic signed [20:0] t0, t1, t2, t3, t4, t5, t6, t7;

    // tap 0: -9
    assign t0 = - (xe0 <<< 3) - xe0;
    // tap 1: 22
    assign t1 = (xe1 <<< 5) - (xe1 <<< 3) - (xe1 <<< 1);
    // tap 2: -42
    assign t2 = - (xe2 <<< 5) - (xe2 <<< 3) - (xe2 <<< 1);
    // tap 3: 73
    assign t3 = (xe3 <<< 6) + (xe3 <<< 3) + xe3;
    // tap 4: -124
    assign t4 = - (xe4 <<< 7) + (xe4 <<< 2);
    // tap 5: 205
    assign t5 = (xe5 <<< 8) - (xe5 <<< 6) + (xe5 <<< 4) - (xe5 <<< 2) + xe5;
    // tap 6: -321
    assign t6 = - (xe6 <<< 8) - (xe6 <<< 6) - xe6;
    // tap 7: 384
    assign t7 = (xe7 <<< 9) - (xe7 <<< 7);

    logic signed [20:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7;

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
            y_out <= 10'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            x5 <= x4;
            x6 <= x5;
            x7 <= x6;
            y_out <= y_next;
        end
    end
endmodule
