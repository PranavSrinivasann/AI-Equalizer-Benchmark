// loss20 5-tap W6: 5-tap FFE, per-tap CSD shift-add, Q3.2 samples, Q1.4 coefficients.
// Coefficients [1, -3, 7, -15, 24].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [5:0] x_in,
    output logic signed [5:0] y_out
);

    logic signed [5:0] x1, x2, x3, x4;
    logic signed [11:0] xe0; assign xe0 = x_in;
    logic signed [11:0] xe1; assign xe1 = x1;
    logic signed [11:0] xe2; assign xe2 = x2;
    logic signed [11:0] xe3; assign xe3 = x3;
    logic signed [11:0] xe4; assign xe4 = x4;
    logic signed [11:0] t0, t1, t2, t3, t4;

    // tap 0: 1
    assign t0 = xe0;
    // tap 1: -3
    assign t1 = - (xe1 <<< 2) + xe1;
    // tap 2: 7
    assign t2 = (xe2 <<< 3) - xe2;
    // tap 3: -15
    assign t3 = - (xe3 <<< 4) + xe3;
    // tap 4: 24
    assign t4 = (xe4 <<< 5) - (xe4 <<< 3);

    logic signed [11:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

    logic signed [7:0] shifted;
    assign shifted = acc >>> 4;
    logic signed [5:0] y_next;
    always_comb begin
        if (shifted > 8'sd31)
            y_next = 6'sd31;
        else if (shifted < -8'sd32)
            y_next = -6'sd32;
        else
            y_next = shifted[5:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1 <= 6'sd0;
            x2 <= 6'sd0;
            x3 <= 6'sd0;
            x4 <= 6'sd0;
            y_out <= 6'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
