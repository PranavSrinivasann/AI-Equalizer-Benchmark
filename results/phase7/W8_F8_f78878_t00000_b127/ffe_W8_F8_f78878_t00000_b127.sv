// margin-guided FFE: W=8, F=8, coefficient bits f=[7, 8, 8, 7, 8], dropped sample LSBs t=[0, 0, 0, 0, 0]
// Coefficients (at F) [40, -104, 196, -318, 384], accumulator offset 127.
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [7:0] x_in,
    output logic signed [7:0] y_out
);

    logic signed [7:0] x1;
    logic signed [7:0] x2;
    logic signed [7:0] x3;
    logic signed [7:0] x4;
    logic signed [18:0] xe0; assign xe0 = x_in;
    logic signed [18:0] xe1; assign xe1 = x1;
    logic signed [18:0] xe2; assign xe2 = x2;
    logic signed [18:0] xe3; assign xe3 = x3;
    logic signed [18:0] xe4; assign xe4 = x4;
    logic signed [18:0] tt0, tt1, tt2, tt3, tt4;

    // tap 0: 40 (f=7, drop 0 LSBs)
    assign tt0 = (xe0 <<< 5) + (xe0 <<< 3);
    // tap 1: -104 (f=8, drop 0 LSBs)
    assign tt1 = - (xe1 <<< 7) + (xe1 <<< 5) - (xe1 <<< 3);
    // tap 2: 196 (f=8, drop 0 LSBs)
    assign tt2 = (xe2 <<< 8) - (xe2 <<< 6) + (xe2 <<< 2);
    // tap 3: -318 (f=7, drop 0 LSBs)
    assign tt3 = - (xe3 <<< 8) - (xe3 <<< 6) + (xe3 <<< 1);
    // tap 4: 384 (f=8, drop 0 LSBs)
    assign tt4 = (xe4 <<< 9) - (xe4 <<< 7);

    logic signed [18:0] acc;
    assign acc = tt0 + tt1 + tt2 + tt3 + tt4 + 19'sd127;

    logic signed [10:0] shifted;
    assign shifted = acc >>> 8;
    logic signed [7:0] y_next;
    always_comb begin
        if (shifted > 11'sd127)
            y_next = 8'sd127;
        else if (shifted < -11'sd128)
            y_next = -8'sd128;
        else
            y_next = shifted[7:0];
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
