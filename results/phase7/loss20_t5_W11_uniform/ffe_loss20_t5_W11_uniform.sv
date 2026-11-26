// loss20 5-tap W11: 5-tap FFE, per-tap CSD shift-add, Q3.7 samples, Q1.9 coefficients.
// Coefficients [40, -108, 233, -469, 768].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [10:0] x_in,
    output logic signed [10:0] y_out
);

    logic signed [10:0] x1, x2, x3, x4;
    logic signed [21:0] xe0; assign xe0 = x_in;
    logic signed [21:0] xe1; assign xe1 = x1;
    logic signed [21:0] xe2; assign xe2 = x2;
    logic signed [21:0] xe3; assign xe3 = x3;
    logic signed [21:0] xe4; assign xe4 = x4;
    logic signed [21:0] t0, t1, t2, t3, t4;

    // tap 0: 40
    assign t0 = (xe0 <<< 5) + (xe0 <<< 3);
    // tap 1: -108
    assign t1 = - (xe1 <<< 7) + (xe1 <<< 4) + (xe1 <<< 2);
    // tap 2: 233
    assign t2 = (xe2 <<< 8) - (xe2 <<< 5) + (xe2 <<< 3) + xe2;
    // tap 3: -469
    assign t3 = - (xe3 <<< 9) + (xe3 <<< 6) - (xe3 <<< 4) - (xe3 <<< 2) - xe3;
    // tap 4: 768
    assign t4 = (xe4 <<< 10) - (xe4 <<< 8);

    logic signed [21:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

    logic signed [12:0] shifted;
    assign shifted = acc >>> 9;
    logic signed [10:0] y_next;
    always_comb begin
        if (shifted > 13'sd1023)
            y_next = 11'sd1023;
        else if (shifted < -13'sd1024)
            y_next = -11'sd1024;
        else
            y_next = shifted[10:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1 <= 11'sd0;
            x2 <= 11'sd0;
            x3 <= 11'sd0;
            x4 <= 11'sd0;
            y_out <= 11'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
