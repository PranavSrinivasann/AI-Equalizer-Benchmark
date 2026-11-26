// margin-guided FFE: W=10, F=8, coefficient bits f=[7, 8, 8, 7, 8], dropped sample LSBs t=[0, 1, 1, 1, 1]
// Coefficients (at F) [40, -104, 196, -318, 384], accumulator offset 205.
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [9:0] x_in,
    output logic signed [9:0] y_out
);

    logic signed [8:0] x1;
    logic signed [8:0] x2;
    logic signed [8:0] x3;
    logic signed [8:0] x4;
    logic signed [20:0] xe0; assign xe0 = x_in;
    logic signed [20:0] xe1; assign xe1 = x1 <<< 1;
    logic signed [20:0] xe2; assign xe2 = x2 <<< 1;
    logic signed [20:0] xe3; assign xe3 = x3 <<< 1;
    logic signed [20:0] xe4; assign xe4 = x4 <<< 1;
    logic signed [20:0] tt0, tt1, tt2, tt3, tt4;

    // tap 0: 40 (f=7, drop 0 LSBs)
    assign tt0 = (xe0 <<< 5) + (xe0 <<< 3);
    // tap 1: -104 (f=8, drop 1 LSBs)
    assign tt1 = - (xe1 <<< 7) + (xe1 <<< 5) - (xe1 <<< 3);
    // tap 2: 196 (f=8, drop 1 LSBs)
    assign tt2 = (xe2 <<< 8) - (xe2 <<< 6) + (xe2 <<< 2);
    // tap 3: -318 (f=7, drop 1 LSBs)
    assign tt3 = - (xe3 <<< 8) - (xe3 <<< 6) + (xe3 <<< 1);
    // tap 4: 384 (f=8, drop 1 LSBs)
    assign tt4 = (xe4 <<< 9) - (xe4 <<< 7);

    logic signed [20:0] acc;
    assign acc = tt0 + tt1 + tt2 + tt3 + tt4 + 21'sd205;

    logic signed [12:0] shifted;
    assign shifted = acc >>> 8;
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
            x1 <= x_in >>> 1;
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            y_out <= y_next;
        end
    end
endmodule
