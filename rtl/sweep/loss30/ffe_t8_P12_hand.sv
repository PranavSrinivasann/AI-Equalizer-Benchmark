// loss30 8-tap P12: 8-tap FFE, per-tap CSD shift-add, Q3.8 samples, Q1.10 coefficients.
// Coefficients [-35, 88, -167, 290, -495, 821, -1283, 1536].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4, x5, x6, x7;
    logic signed [24:0] xe0; assign xe0 = x_in;
    logic signed [24:0] xe1; assign xe1 = x1;
    logic signed [24:0] xe2; assign xe2 = x2;
    logic signed [24:0] xe3; assign xe3 = x3;
    logic signed [24:0] xe4; assign xe4 = x4;
    logic signed [24:0] xe5; assign xe5 = x5;
    logic signed [24:0] xe6; assign xe6 = x6;
    logic signed [24:0] xe7; assign xe7 = x7;
    logic signed [24:0] t0, t1, t2, t3, t4, t5, t6, t7;

    // tap 0: -35
    assign t0 = - (xe0 <<< 5) - (xe0 <<< 2) + xe0;
    // tap 1: 88
    assign t1 = (xe1 <<< 7) - (xe1 <<< 5) - (xe1 <<< 3);
    // tap 2: -167
    assign t2 = - (xe2 <<< 7) - (xe2 <<< 5) - (xe2 <<< 3) + xe2;
    // tap 3: 290
    assign t3 = (xe3 <<< 8) + (xe3 <<< 5) + (xe3 <<< 1);
    // tap 4: -495
    assign t4 = - (xe4 <<< 9) + (xe4 <<< 4) + xe4;
    // tap 5: 821
    assign t5 = (xe5 <<< 10) - (xe5 <<< 8) + (xe5 <<< 6) - (xe5 <<< 4) + (xe5 <<< 2) + xe5;
    // tap 6: -1283
    assign t6 = - (xe6 <<< 10) - (xe6 <<< 8) - (xe6 <<< 2) + xe6;
    // tap 7: 1536
    assign t7 = (xe7 <<< 11) - (xe7 <<< 9);

    logic signed [24:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4 + t5 + t6 + t7;

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
            y_out <= 12'sd0;
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
