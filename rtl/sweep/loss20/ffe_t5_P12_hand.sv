// loss20 5-tap P12: 5-tap FFE, per-tap CSD shift-add, Q3.8 samples, Q1.10 coefficients.
// Coefficients [80, -216, 466, -938, 1536].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4;
    logic signed [23:0] xe0; assign xe0 = x_in;
    logic signed [23:0] xe1; assign xe1 = x1;
    logic signed [23:0] xe2; assign xe2 = x2;
    logic signed [23:0] xe3; assign xe3 = x3;
    logic signed [23:0] xe4; assign xe4 = x4;
    logic signed [23:0] t0, t1, t2, t3, t4;

    // tap 0: 80
    assign t0 = (xe0 <<< 6) + (xe0 <<< 4);
    // tap 1: -216
    assign t1 = - (xe1 <<< 8) + (xe1 <<< 5) + (xe1 <<< 3);
    // tap 2: 466
    assign t2 = (xe2 <<< 9) - (xe2 <<< 6) + (xe2 <<< 4) + (xe2 <<< 1);
    // tap 3: -938
    assign t3 = - (xe3 <<< 10) + (xe3 <<< 7) - (xe3 <<< 5) - (xe3 <<< 3) - (xe3 <<< 1);
    // tap 4: 1536
    assign t4 = (xe4 <<< 11) - (xe4 <<< 9);

    logic signed [23:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

    logic signed [13:0] shifted;
    assign shifted = acc >>> 10;
    logic signed [11:0] y_next;
    always_comb begin
        if (shifted > 14'sd2047)
            y_next = 12'sd2047;
        else if (shifted < -14'sd2048)
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
            y_out <= 12'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
