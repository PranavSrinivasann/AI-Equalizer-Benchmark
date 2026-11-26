// margin-guided FFE: W=6, F=4, coefficient bits f=[3, 3, 3, 2, 4], dropped sample LSBs t=[0, 0, 0, 0, 0]
// Coefficients (at F) [2, -4, 8, -16, 24], accumulator offset 7.
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [5:0] x_in,
    output logic signed [5:0] y_out
);

    logic signed [5:0] x1;
    logic signed [5:0] x2;
    logic signed [5:0] x3;
    logic signed [5:0] x4;
    logic signed [11:0] xe0; assign xe0 = x_in;
    logic signed [11:0] xe1; assign xe1 = x1;
    logic signed [11:0] xe2; assign xe2 = x2;
    logic signed [11:0] xe3; assign xe3 = x3;
    logic signed [11:0] xe4; assign xe4 = x4;
    logic signed [11:0] tt0, tt1, tt2, tt3, tt4;

    // tap 0: 2 (f=3, drop 0 LSBs)
    assign tt0 = (xe0 <<< 1);
    // tap 1: -4 (f=3, drop 0 LSBs)
    assign tt1 = - (xe1 <<< 2);
    // tap 2: 8 (f=3, drop 0 LSBs)
    assign tt2 = (xe2 <<< 3);
    // tap 3: -16 (f=2, drop 0 LSBs)
    assign tt3 = - (xe3 <<< 4);
    // tap 4: 24 (f=4, drop 0 LSBs)
    assign tt4 = (xe4 <<< 5) - (xe4 <<< 3);

    logic signed [11:0] acc;
    assign acc = tt0 + tt1 + tt2 + tt3 + tt4 + 12'sd7;

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
