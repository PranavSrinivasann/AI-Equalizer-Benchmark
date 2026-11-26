// margin-guided FFE: W=10, F=10, coefficient bits f=[9, 9, 10, 10, 10], dropped sample LSBs t=[0, 0, 0, 0, 0]
// Coefficients (at F) [164, -416, 782, -1268, 1536], accumulator offset 511.
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [9:0] x1;
    logic signed [9:0] x2;
    logic signed [9:0] x3;
    logic signed [9:0] x4;
    logic signed [22:0] xe0; assign xe0 = x_in;
    logic signed [22:0] xe1; assign xe1 = x1;
    logic signed [22:0] xe2; assign xe2 = x2;
    logic signed [22:0] xe3; assign xe3 = x3;
    logic signed [22:0] xe4; assign xe4 = x4;
    logic signed [22:0] tt0, tt1, tt2, tt3, tt4;

    // tap 0: 164 (f=9, drop 0 LSBs)
    assign tt0 = (xe0 <<< 7) + (xe0 <<< 5) + (xe0 <<< 2);
    // tap 1: -416 (f=9, drop 0 LSBs)
    assign tt1 = - (xe1 <<< 9) + (xe1 <<< 7) - (xe1 <<< 5);
    // tap 2: 782 (f=10, drop 0 LSBs)
    assign tt2 = (xe2 <<< 10) - (xe2 <<< 8) + (xe2 <<< 4) - (xe2 <<< 1);
    // tap 3: -1268 (f=10, drop 0 LSBs)
    assign tt3 = - (xe3 <<< 10) - (xe3 <<< 8) + (xe3 <<< 4) - (xe3 <<< 2);
    // tap 4: 1536 (f=10, drop 0 LSBs)
    assign tt4 = (xe4 <<< 11) - (xe4 <<< 9);

    logic signed [22:0] acc;
    assign acc = tt0 + tt1 + tt2 + tt3 + tt4 + 23'sd511;

    logic signed [12:0] shifted;
    assign shifted = acc >>> 10;
    logic signed [9:0] y_next;
    always_comb begin
        if (shifted > 13'sd511)
            y_next = 10'sd511;
        else if (shifted < -13'sd512)
            y_next = -10'sd512;
        else
            y_next = shifted[9:0];
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
