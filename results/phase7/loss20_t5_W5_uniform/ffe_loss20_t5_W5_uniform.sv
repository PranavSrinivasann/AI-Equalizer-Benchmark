// uniform W5: W=5, F=3, coefficient bits f=[3, 3, 3, 3, 3], dropped sample LSBs t=[0, 0, 0, 0, 0]
// Coefficients (at F) [1, -2, 4, -7, 12], accumulator offset 0.
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [4:0] x_in,
    output logic signed [4:0] y_out
);

    logic signed [4:0] x1;
    logic signed [4:0] x2;
    logic signed [4:0] x3;
    logic signed [4:0] x4;
    logic signed [9:0] xe0; assign xe0 = x_in;
    logic signed [9:0] xe1; assign xe1 = x1;
    logic signed [9:0] xe2; assign xe2 = x2;
    logic signed [9:0] xe3; assign xe3 = x3;
    logic signed [9:0] xe4; assign xe4 = x4;
    logic signed [9:0] tt0, tt1, tt2, tt3, tt4;

    // tap 0: 1 (f=3, drop 0 LSBs)
    assign tt0 = xe0;
    // tap 1: -2 (f=3, drop 0 LSBs)
    assign tt1 = - (xe1 <<< 1);
    // tap 2: 4 (f=3, drop 0 LSBs)
    assign tt2 = (xe2 <<< 2);
    // tap 3: -7 (f=3, drop 0 LSBs)
    assign tt3 = - (xe3 <<< 3) + xe3;
    // tap 4: 12 (f=3, drop 0 LSBs)
    assign tt4 = (xe4 <<< 4) - (xe4 <<< 2);

    logic signed [9:0] acc;
    assign acc = tt0 + tt1 + tt2 + tt3 + tt4;

    logic signed [6:0] shifted;
    assign shifted = acc >>> 3;
    logic signed [4:0] y_next;
    always_comb begin
        if (shifted > 7'sd15)
            y_next = 5'sd15;
        else if (shifted < -7'sd16)
            y_next = -5'sd16;
        else
            y_next = shifted[4:0];
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
