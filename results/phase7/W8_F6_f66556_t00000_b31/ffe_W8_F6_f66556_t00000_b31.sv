// margin-guided FFE: W=8, F=6, coefficient bits f=[6, 6, 5, 5, 6], dropped sample LSBs t=[0, 0, 0, 0, 0]
// Coefficients (at F) [10, -26, 48, -80, 96], accumulator offset 31.
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
    logic signed [16:0] xe0; assign xe0 = x_in;
    logic signed [16:0] xe1; assign xe1 = x1;
    logic signed [16:0] xe2; assign xe2 = x2;
    logic signed [16:0] xe3; assign xe3 = x3;
    logic signed [16:0] xe4; assign xe4 = x4;
    logic signed [16:0] tt0, tt1, tt2, tt3, tt4;

    // tap 0: 10 (f=6, drop 0 LSBs)
    assign tt0 = (xe0 <<< 3) + (xe0 <<< 1);
    // tap 1: -26 (f=6, drop 0 LSBs)
    assign tt1 = - (xe1 <<< 5) + (xe1 <<< 3) - (xe1 <<< 1);
    // tap 2: 48 (f=5, drop 0 LSBs)
    assign tt2 = (xe2 <<< 6) - (xe2 <<< 4);
    // tap 3: -80 (f=5, drop 0 LSBs)
    assign tt3 = - (xe3 <<< 6) - (xe3 <<< 4);
    // tap 4: 96 (f=6, drop 0 LSBs)
    assign tt4 = (xe4 <<< 7) - (xe4 <<< 5);

    logic signed [16:0] acc;
    assign acc = tt0 + tt1 + tt2 + tt3 + tt4 + 17'sd31;

    logic signed [10:0] shifted;
    assign shifted = acc >>> 6;
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
