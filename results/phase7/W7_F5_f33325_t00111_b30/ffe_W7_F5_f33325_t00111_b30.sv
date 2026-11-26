// margin-guided FFE: W=7, F=5, coefficient bits f=[3, 3, 3, 2, 5], dropped sample LSBs t=[0, 0, 1, 1, 1]
// Coefficients (at F) [4, -8, 16, -32, 48], accumulator offset 30.
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [6:0] x_in,
    output logic signed [6:0] y_out
);

    logic signed [6:0] x1;
    logic signed [5:0] x2;
    logic signed [5:0] x3;
    logic signed [5:0] x4;
    logic signed [13:0] xe0; assign xe0 = x_in;
    logic signed [13:0] xe1; assign xe1 = x1;
    logic signed [13:0] xe2; assign xe2 = x2 <<< 1;
    logic signed [13:0] xe3; assign xe3 = x3 <<< 1;
    logic signed [13:0] xe4; assign xe4 = x4 <<< 1;
    logic signed [13:0] tt0, tt1, tt2, tt3, tt4;

    // tap 0: 4 (f=3, drop 0 LSBs)
    assign tt0 = (xe0 <<< 2);
    // tap 1: -8 (f=3, drop 0 LSBs)
    assign tt1 = - (xe1 <<< 3);
    // tap 2: 16 (f=3, drop 1 LSBs)
    assign tt2 = (xe2 <<< 4);
    // tap 3: -32 (f=2, drop 1 LSBs)
    assign tt3 = - (xe3 <<< 5);
    // tap 4: 48 (f=5, drop 1 LSBs)
    assign tt4 = (xe4 <<< 6) - (xe4 <<< 4);

    logic signed [13:0] acc;
    assign acc = tt0 + tt1 + tt2 + tt3 + tt4 + 14'sd30;

    logic signed [8:0] shifted;
    assign shifted = acc >>> 5;
    logic signed [6:0] y_next;
    always_comb begin
        if (shifted > 9'sd63)
            y_next = 7'sd63;
        else if (shifted < -9'sd64)
            y_next = -7'sd64;
        else
            y_next = shifted[6:0];
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
            x2 <= x1 >>> 1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
