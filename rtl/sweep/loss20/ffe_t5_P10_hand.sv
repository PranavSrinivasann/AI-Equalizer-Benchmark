// loss20 5-tap P10: 5-tap FFE, per-tap CSD shift-add, Q3.6 samples, Q1.8 coefficients.
// Coefficients [20, -54, 117, -234, 384].
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [9:0] x1, x2, x3, x4;
    logic signed [19:0] xe0; assign xe0 = x_in;
    logic signed [19:0] xe1; assign xe1 = x1;
    logic signed [19:0] xe2; assign xe2 = x2;
    logic signed [19:0] xe3; assign xe3 = x3;
    logic signed [19:0] xe4; assign xe4 = x4;
    logic signed [19:0] t0, t1, t2, t3, t4;

    // tap 0: 20
    assign t0 = (xe0 <<< 4) + (xe0 <<< 2);
    // tap 1: -54
    assign t1 = - (xe1 <<< 6) + (xe1 <<< 3) + (xe1 <<< 1);
    // tap 2: 117
    assign t2 = (xe2 <<< 7) - (xe2 <<< 4) + (xe2 <<< 2) + xe2;
    // tap 3: -234
    assign t3 = - (xe3 <<< 8) + (xe3 <<< 5) - (xe3 <<< 3) - (xe3 <<< 1);
    // tap 4: 384
    assign t4 = (xe4 <<< 9) - (xe4 <<< 7);

    logic signed [19:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

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
            y_out <= 10'sd0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
