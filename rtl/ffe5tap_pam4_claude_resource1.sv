// =============================================================
// Module: ffe5tap_pam4  (resource-optimized for iCE40 UP5K)
// 5-Tap Fixed-Coefficient Feed-Forward Equalizer for PAM4
// Input:  signed 12-bit Q3.8
// Coeffs: signed 12-bit Q1.10 (fixed, embedded as localparams)
// Output: signed 12-bit Q3.8 (saturated)
// Latency: 1 clock cycle, 1 sample/cycle throughput
//
// Architecture: exploits the antisymmetric coefficient set
// (C4=-C0, C3=-C1) and the power-of-two center tap (C2=2^10)
// to replace 5 multiplies with 2 multiplies + 1 hard-wired
// shift, and narrows every intermediate to its proven
// worst-case bit width instead of blanket over-sizing.
// =============================================================

module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // ---------------------------------------------------------
    // Coefficients (Q1.10) — values preserved exactly.
    // Folding below is valid ONLY because of these relations;
    // the asserts document that dependency (sim-only, no logic).
    // ---------------------------------------------------------
    localparam signed [11:0] C0 = 12'sd51;
    localparam signed [11:0] C1 = -12'sd154;
    localparam signed [11:0] C2 = 12'sd1024;   // == 2^10
    localparam signed [11:0] C3 = 12'sd154;
    localparam signed [11:0] C4 = -12'sd51;

    // synthesis translate_off
    initial begin
        assert (C4 == -C0) else $fatal(1, "folding invalid: C4 != -C0");
        assert (C3 == -C1) else $fatal(1, "folding invalid: C3 != -C1");
        assert (C2 == (12'sd1 <<< 10)) else $fatal(1, "folding invalid: C2 != 2^10");
    end
    // synthesis translate_on

    // ---------------------------------------------------------
    // Delay line: unchanged. 4 registers give the 5 taps
    // (x_in, x1, x2, x3, x4) with 1-cycle latency, as required.
    // ---------------------------------------------------------
    logic signed [11:0] x1, x2, x3, x4;

    // ---------------------------------------------------------
    // Fold antisymmetric pairs BEFORE multiplying.
    // 13-bit result is exact: 12-bit minus 12-bit needs 13 bits.
    // Relies on IEEE 1800 context-determined operand extension
    // for '-' (both operands sign-extended to the 13-bit target
    // before subtracting) — not a self-determined operator, so
    // this is well-defined and lossless.
    // ---------------------------------------------------------
    logic signed [12:0] sum04, sum13;
    assign sum04 = x_in - x4;   // pairs with C0 (was taps 0 & 4)
    assign sum13 = x1   - x3;   // pairs with C1 (was taps 1 & 3)

    // Two multiplies instead of five. 13x12 -> exact 25-bit product.
    logic signed [24:0] p0, p1;
    assign p0 = sum04 * C0;
    assign p1 = sum13 * C1;

    // Center tap: C2 = 2^10 exactly -> no multiplier at all.
    // NOTE: must NOT write `x2 <<< 10` here — shift operators are
    // self-determined (sized by the LEFT OPERAND only, i.e. 12
    // bits), so that would silently drop the high bits. Using
    // concatenation forces the correct 22-bit exact result.
    logic signed [21:0] p2;
    assign p2 = $signed({x2, 10'b0});   // exact x2 * 1024

    // ---------------------------------------------------------
    // 3-term accumulate instead of 5-term.
    // Worst-case |sum| = 4095*51 + 4095*154 + 2048*1024
    //                  = 2,936,627  -> needs exactly 23 bits signed.
    // 24 bits gives 1 bit of proven margin (no growth "just in case").
    // ---------------------------------------------------------
    logic signed [23:0] acc;
    assign acc = p0 + p1 + p2;

    // Scale Q4.18 -> Q4.8. acc already has its full required width,
    // so the arithmetic shift needs no extra headroom.
    // ---------------------------------------------------------
    // Worst-case |acc>>>10| ~= 2869 -> needs 13 bits signed.
    // 14 bits gives 1 bit of margin. Truncating the 24-bit shift
    // result to 14 bits is lossless because the true value already
    // fits in fewer than 14 bits (extra bits were redundant sign
    // copies).
    logic signed [13:0] shifted;
    assign shifted = acc >>> 10;

    // ---------------------------------------------------------
    // Saturation via sign-uniformity test instead of magnitude
    // compares. For a 12-bit signed result, the value is in range
    // iff bits [13:11] of `shifted` all equal bit 11 (its would-be
    // sign bit). Bit 11 compared to itself is always 0, so only
    // bits [13:12] need checking -> 2 XORs + 1 OR, replacing what
    // would otherwise be two wide arithmetic comparators.
    // ---------------------------------------------------------
    localparam signed [11:0] MAX_12 = 12'sd2047;
    localparam signed [11:0] MIN_12 = -12'sd2048;

    logic ovf;
    logic signed [11:0] y_sat;

    assign ovf = |(shifted[13:12] ^ {2{shifted[11]}});

    always_comb begin
        if (ovf)
            y_sat = shifted[13] ? MIN_12 : MAX_12;
        else
            y_sat = shifted[11:0];
    end

    // ---------------------------------------------------------
    // Registers: identical structure/behavior to the original —
    // synchronous, active-low reset; 1 sample/cycle; 1-cycle latency.
    // ---------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1    <= 12'sd0;
            x2    <= 12'sd0;
            x3    <= 12'sd0;
            x4    <= 12'sd0;
            y_out <= 12'sd0;
        end else begin
            x4    <= x3;
            x3    <= x2;
            x2    <= x1;
            x1    <= x_in;
            y_out <= y_sat;
        end
    end

endmodule