// margin-guided FFE: W=9, F=7, coefficient bits f=[7, 7, 7, 7, 7], dropped sample LSBs t=[0, 0, 0, 0, 0]
// Coefficients (at F) [20, -52, 98, -159, 192], accumulator offset 64.
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [8:0] x_in,
    output logic signed [8:0] y_out
);

    logic signed [8:0] x1;
    logic signed [8:0] x2;
    logic signed [8:0] x3;
    logic signed [8:0] x4;
    logic signed [18:0] xe0; assign xe0 = x_in;
    logic signed [18:0] xe1; assign xe1 = x1;
    logic signed [18:0] xe2; assign xe2 = x2;
    logic signed [18:0] xe3; assign xe3 = x3;
    logic signed [18:0] xe4; assign xe4 = x4;
    logic signed [18:0] tt0, tt1, tt2, tt3, tt4;

    // tap 0: 20 (f=7, drop 0 LSBs)
    assign tt0 = (xe0 <<< 4) + (xe0 <<< 2);
    // tap 1: -52 (f=7, drop 0 LSBs)
    assign tt1 = - (xe1 <<< 6) + (xe1 <<< 4) - (xe1 <<< 2);
    // tap 2: 98 (f=7, drop 0 LSBs)
    assign tt2 = (xe2 <<< 7) - (xe2 <<< 5) + (xe2 <<< 1);
    // tap 3: -159 (f=7, drop 0 LSBs)
    assign tt3 = - (xe3 <<< 7) - (xe3 <<< 5) + xe3;
    // tap 4: 192 (f=7, drop 0 LSBs)
    assign tt4 = (xe4 <<< 8) - (xe4 <<< 6);

    logic signed [18:0] acc;
    assign acc = tt0 + tt1 + tt2 + tt3 + tt4 + 19'sd64;

    logic signed [11:0] shifted;
    assign shifted = acc >>> 7;
    logic signed [8:0] y_next;
    always_comb begin
        if (shifted > 12'sd255)
            y_next = 9'sd255;
        else if (shifted < -12'sd256)
            y_next = -9'sd256;
        else
            y_next = shifted[8:0];
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
