// loss30 5-tap P8: 5-tap FFE, per-tap CSD shift-add, Q3.4 samples, Q1.6 coefficients.
// Coefficients [10, -26, 49, -79, 96].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [7:0] x_in,
    output logic signed [7:0] y_out
);

    logic signed [7:0] x1, x2, x3, x4;
    logic signed [16:0] xe0; assign xe0 = x_in;
    logic signed [16:0] xe1; assign xe1 = x1;
    logic signed [16:0] xe2; assign xe2 = x2;
    logic signed [16:0] xe3; assign xe3 = x3;
    logic signed [16:0] xe4; assign xe4 = x4;
    logic signed [16:0] t0, t1, t2, t3, t4;

    // tap 0: 10
    assign t0 = (xe0 <<< 3) + (xe0 <<< 1);
    // tap 1: -26
    assign t1 = - (xe1 <<< 5) + (xe1 <<< 3) - (xe1 <<< 1);
    // tap 2: 49
    assign t2 = (xe2 <<< 6) - (xe2 <<< 4) + xe2;
    // tap 3: -79
    assign t3 = - (xe3 <<< 6) - (xe3 <<< 4) + xe3;
    // tap 4: 96
    assign t4 = (xe4 <<< 7) - (xe4 <<< 5);

    logic signed [16:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

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
            y_out <= 8'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
