// loss30 8-tap P8: 8-tap FFE, per-tap CSD shift-add, Q3.4 samples, Q1.6 coefficients.
// Coefficients [-2, 5, -10, 18, -31, 51, -80, 96].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [7:0] x_in,
    output logic signed [7:0] y_out
);

    logic signed [7:0] x1, x2, x3, x4, x5, x6, x7;
    logic signed [16:0] xe0; assign xe0 = x_in;
    logic signed [16:0] xe1; assign xe1 = x1;
    logic signed [16:0] xe2; assign xe2 = x2;
    logic signed [16:0] xe3; assign xe3 = x3;
    logic signed [16:0] xe4; assign xe4 = x4;
    logic signed [16:0] xe5; assign xe5 = x5;
    logic signed [16:0] xe6; assign xe6 = x6;
    logic signed [16:0] xe7; assign xe7 = x7;
    logic signed [16:0] t0, t1, t2, t3, t4, t5, t6, t7;

    // tap 0: -2
    assign t0 = - (xe0 <<< 1);
    // tap 1: 5
    assign t1 = (xe1 <<< 2) + xe1;
    // tap 2: -10
    assign t2 = - (xe2 <<< 3) - (xe2 <<< 1);
    // tap 3: 18
    assign t3 = (xe3 <<< 4) + (xe3 <<< 1);
    // tap 4: -31
    assign t4 = - (xe4 <<< 5) + xe4;
    // tap 5: 51
    assign t5 = (xe5 <<< 6) - (xe5 <<< 4) + (xe5 <<< 2) - xe5;
    // tap 6: -80
    assign t6 = - (xe6 <<< 6) - (xe6 <<< 4);
    // tap 7: 96
    assign t7 = (xe7 <<< 7) - (xe7 <<< 5);

    logic signed [16:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7;

    logic signed [10:0] shifted;
    assign shifted = acc >>> 6;
    logic signed [7:0] y_next;
    always_comb begin
        if (shifted > 11'sd127)
            y_next = 8'sd127;
        else if (shifted < -11'sd128)
            y_next = -8'sd128;
        else
            y_next = shifted[7:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1 <= 8'sd0;
            x2 <= 8'sd0;
            x3 <= 8'sd0;
            x4 <= 8'sd0;
            x5 <= 8'sd0;
            x6 <= 8'sd0;
            x7 <= 8'sd0;
            y_out <= 8'sd0;
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
