// loss20 8-tap P10: 8-tap FFE, per-tap CSD shift-add, Q3.6 samples, Q1.8 coefficients.
// Coefficients [-10, 26, -57, 118, -234, 384, 0, 8].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [9:0] x1, x2, x3, x4, x5, x6, x7;
    logic signed [19:0] xe0; assign xe0 = x_in;
    logic signed [19:0] xe1; assign xe1 = x1;
    logic signed [19:0] xe2; assign xe2 = x2;
    logic signed [19:0] xe3; assign xe3 = x3;
    logic signed [19:0] xe4; assign xe4 = x4;
    logic signed [19:0] xe5; assign xe5 = x5;
    logic signed [19:0] xe6; assign xe6 = x6;
    logic signed [19:0] xe7; assign xe7 = x7;
    logic signed [19:0] t0, t1, t2, t3, t4, t5, t6, t7;

    // tap 0: -10
    assign t0 = - (xe0 <<< 3) - (xe0 <<< 1);
    // tap 1: 26
    assign t1 = (xe1 <<< 5) - (xe1 <<< 3) + (xe1 <<< 1);
    // tap 2: -57
    assign t2 = - (xe2 <<< 6) + (xe2 <<< 3) - xe2;
    // tap 3: 118
    assign t3 = (xe3 <<< 7) - (xe3 <<< 3) - (xe3 <<< 1);
    // tap 4: -234
    assign t4 = - (xe4 <<< 8) + (xe4 <<< 5) - (xe4 <<< 3) - (xe4 <<< 1);
    // tap 5: 384
    assign t5 = (xe5 <<< 9) - (xe5 <<< 7);
    // tap 6: 0
    assign t6 = '0;
    // tap 7: 8
    assign t7 = (xe7 <<< 3);

    logic signed [19:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7;

    logic signed [11:0] shifted;
    assign shifted = acc >>> 8;
    logic signed [9:0] y_next;
    always_comb begin
        if (shifted > 12'sd511)
            y_next = 10'sd511;
        else if (shifted < -12'sd512)
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
