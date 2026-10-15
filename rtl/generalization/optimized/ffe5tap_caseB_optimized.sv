module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Delay line (12-bit, same as baseline)
    logic signed [11:0] x1, x2, x3, x4;

    // Output register: only 11 bits are needed (see bound proof below)
    logic signed [10:0] y_q;

    // ------------------------------------------------------------------
    // acc = 73*x0 - 121*x1 + 89*x2 + 146*x3 - 57*x4
    //     = 73*S + 16*x2 + 7*B - 64*T
    //   S = x0 + x2 + 2*x3        (146 = 2*73, 89 = 73 + 16)
    //   B = x1 + x4
    //   T = 2*x1 + x4             (-121 = -128 + 7, -57 = -64 + 7)
    // ------------------------------------------------------------------
    (* keep *) logic signed [13:0] s;      // |S| <= 8192
    (* keep *) logic signed [12:0] b;      // |B| <= 4096
    (* keep *) logic signed [13:0] t;      // |T| <= 6144

    assign s = x_in + x2 + (x3 <<< 1);
    assign b = x1 + x4;
    assign t = (x1 <<< 1) + x4;

    // All partial results are modulo 2^21; the true sum fits in 21 bits,
    // so the final value is exact.
    (* keep *) logic signed [20:0] s9;     // 9*S
    (* keep *) logic signed [20:0] s73;    // 73*S
    (* keep *) logic signed [20:0] b7;     // 7*B
    (* keep *) logic signed [20:0] r0;     // 16*x2 - 64*T
    (* keep *) logic signed [20:0] r1;     // 7*B + 16*x2 - 64*T
    logic signed [20:0] acc;

    assign s9  = (s  <<< 3) + s;
    assign s73 = (s  <<< 6) + s9;
    assign b7  = (b  <<< 3) - b;
    assign r0  = (x2 <<< 4) - (t <<< 6);
    assign r1  = b7 + r0;
    assign acc = s73 + r1;

    // ------------------------------------------------------------------
    // Saturation removed: provably unreachable (see below).
    // y = acc >>> 10 is in [-972, 971], i.e. acc[20:10] is exact.
    // ------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1  <= 12'sd0;
            x2  <= 12'sd0;
            x3  <= 12'sd0;
            x4  <= 12'sd0;
            y_q <= 11'sd0;
        end else begin
            x4  <= x3;
            x3  <= x2;
            x2  <= x1;
            x1  <= x_in;
            y_q <= acc[20:10];
        end
    end

    assign y_out = {y_q[10], y_q};   // sign-extend; no 12th flop

endmodule