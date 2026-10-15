module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    logic signed [11:0] x1, x2, x3, x4;   // delay line (unchanged)
    logic signed [10:0] y_q;              // 11-bit output register (see bounds)

    // ------------------------------------------------------------------
    // C = {51, -137, 93, 137, -51}  (antisymmetric outer pairs)
    //   acc = 51*(x0 - x4) - 137*(x1 - x3) + 93*x2
    //       = 3*(17*d04 + 31*x2) - 137*d13
    //   d04 = x0 - x4,  d13 = x1 - x3
    //   51 = 3*17,  93 = 3*31,  137 = 128 + 9
    // 9 two-input adders total, all on the carry chain.
    // Adders whose shifted operand has trailing zeros are written with the
    // low bits passed straight through, so no carry-chain LCs are spent there.
    // ------------------------------------------------------------------

    // Stage 1: pre-adders (|d| <= 4095 -> 13 bits)
    (* keep *) logic signed [12:0] d04, d13;
    assign d04 = x_in - x4;
    assign d13 = x1   - x3;

    // Sign-extended views
    logic signed [17:0] d04_18;  assign d04_18 = d04;
    logic signed [16:0] d13_17;  assign d13_17 = d13;
    logic signed [20:0] d13_21;  assign d13_21 = d13;
    logic signed [16:0] x2_17;   assign x2_17  = x2;

    // 17*d04 = 16*d04 + d04      (|.| <= 69,615 -> 18 bits)
    (* keep *) logic [13:0] a17_hi;
    assign a17_hi = d04_18[17:4] + d04_18[13:0];
    logic signed [17:0] a17;
    assign a17 = {a17_hi, d04_18[3:0]};

    // 31*x2 = 32*x2 - x2         (|.| <= 63,488 -> 17 bits)
    (* keep *) logic signed [16:0] x31;
    assign x31 = (x2_17 <<< 5) - x2_17;

    // w = 17*d04 + 31*x2         (|w| <= 133,103 -> 19 bits)
    (* keep *) logic signed [18:0] w;
    assign w = a17 + x31;

    // 3*w = 2*w + w              (|.| <= 399,309 -> 20 bits)
    logic signed [19:0] w_20;  assign w_20 = w;
    (* keep *) logic [18:0] w3_hi;
    assign w3_hi = w_20[19:1] + w_20[18:0];
    logic signed [19:0] w3;
    assign w3 = {w3_hi, w_20[0]};

    // 9*d13 = 8*d13 + d13        (|.| <= 36,855 -> 17 bits)
    (* keep *) logic [13:0] d9_hi;
    assign d9_hi = d13_17[16:3] + d13_17[13:0];
    logic signed [16:0] d9;
    assign d9 = {d9_hi, d13_17[2:0]};
    logic signed [20:0] d9_21;  assign d9_21 = d9;

    // 137*d13 = 128*d13 + 9*d13  (|.| <= 561,015 -> 21 bits)
    (* keep *) logic [13:0] p137_hi;
    assign p137_hi = d9_21[20:7] + d13_21[13:0];
    logic signed [20:0] p137;
    assign p137 = {p137_hi, d9_21[6:0]};

    // acc = 3*w - 137*d13
    logic signed [20:0] w3_21;  assign w3_21 = w3;
    (* keep *) logic signed [20:0] acc;
    assign acc = w3_21 - p137;

    // Saturation is unreachable: y = acc >>> 10 is in [-938, 937].
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

    assign y_out = {y_q[10], y_q};

endmodule