// uniform W4: W=4, F=2, coefficient bits f=[2, 2, 2, 2, 2], dropped sample LSBs t=[0, 0, 0, 0, 0]
// Coefficients (at F) [0, -1, 2, -4, 6], accumulator offset 0.
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [3:0] x_in,
    output logic signed [3:0] y_out
);

    logic signed [3:0] x1;
    logic signed [3:0] x2;
    logic signed [3:0] x3;
    logic signed [3:0] x4;
    logic signed [7:0] xe0; assign xe0 = x_in;
    logic signed [7:0] xe1; assign xe1 = x1;
    logic signed [7:0] xe2; assign xe2 = x2;
    logic signed [7:0] xe3; assign xe3 = x3;
    logic signed [7:0] xe4; assign xe4 = x4;
    logic signed [7:0] tt0, tt1, tt2, tt3, tt4;

    // tap 0: 0
    assign tt0 = '0;
    // tap 1: -1 (f=2, drop 0 LSBs)
    assign tt1 = - xe1;
    // tap 2: 2 (f=2, drop 0 LSBs)
    assign tt2 = (xe2 <<< 1);
    // tap 3: -4 (f=2, drop 0 LSBs)
    assign tt3 = - (xe3 <<< 2);
    // tap 4: 6 (f=2, drop 0 LSBs)
    assign tt4 = (xe4 <<< 3) - (xe4 <<< 1);

    logic signed [7:0] acc;
    assign acc = tt0 + tt1 + tt2 + tt3 + tt4;

    logic signed [5:0] shifted;
    assign shifted = acc >>> 2;
    logic signed [3:0] y_next;
    always_comb begin
        if (shifted > 6'sd7)
            y_next = 4'sd7;
        else if (shifted < -6'sd8)
            y_next = -4'sd8;
        else
            y_next = shifted[3:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1 <= '0;
            x2 <= '0;
            x3 <= '0;
            x4 <= '0;
            y_out <= '0;
        end else begin
            x1 <= x_in;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
