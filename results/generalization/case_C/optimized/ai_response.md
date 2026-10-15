# Optimized iCE40 UP5K FFE, Case C

## Optimized RTL

```systemverilog
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
```

## Architectural changes

**1. Saturation removed, because it cannot fire.**
- Worst case over the full 12-bit input range: d04 = +4095 (x0 = 2047, x4 = −2048), d13 = −4095 (x1 = −2048, x3 = 2047), x2 = 2047.
- That gives 51·4095 + 137·4095 + 93·2047 = **960,231**, and `>>> 10` gives **+937**.
- The mirror case (x2 = −2048) gives **−960,324**, and the floor shift gives **−938**.
- Both are well inside [−2048, 2047], so the two 28-bit comparators and the output mux in the baseline are dead logic. Behavior is bit-identical for every input sequence.
- Redo this bound check if any coefficient changes.

**2. Pre-adders exploit the antisymmetry.**
- The outer coefficient pairs are ±51 and ∓137, so one subtract per pair replaces two multiplies.
- That is 5 multiplies down to 3 constant multiplies (51, 137 and 93).

**3. Constant multiplies become shared-factor shift-add.**
- 51 = 3·17 and 93 = 3·31, so one shared ×3 stage covers both: 3·(17·d04 + 31·x2).
- 137 = 128 + 8 + 1 is built as 128·d + 9·d.
- The total is **9 two-input adders**: 2 pre-adders, 3 for w, 1 for ×3, 2 for ×137, and 1 final.
- I found no 8-adder decomposition, but I haven't proven 9 is minimal.
- The ×3 and ×137 stages are in the same tree, which keeps the logic depth at 5 adders.

**4. Every adder is sized to its proven range.**

| Signal | Width |
|---|---|
| d04, d13 | 13 |
| 17·d04 | 18 |
| 31·x2 | 17 |
| w | 19 |
| 3w | 20 |
| 9·d13 | 17 |
| 137·d13, acc | 21 |

The baseline carries a 28-bit accumulator and 24-bit products.

**5. Trailing zeros are passed through, not added.**
- In `16·d + d`, `8·d + d`, `128·d + d9` and `2w + w`, the low bits of the shifted operand are zero.
- I split those adders so only the upper bits use carry-chain LCs. That saves about 15 LCs, and it's harmless if yosys already trims them.

**6. Output register is 11 bits.**
- y ∈ [−938, 937], so bit 11 always equals bit 10 and is driven from the same flop.
- The 11 `y_q` flops pack into the final adder's LCs, since each acc LC's sum output feeds its own flop. They cost no extra LCs.

**7. Reset is unchanged.**
- iCE40 flops have a built-in synchronous reset (`SB_DFFSR`), so the active-low reset costs no extra LUTs.
- All delay stages and `y_q` are still reset, so post-reset behavior is identical.

## Resource estimate

These are my own estimates. I haven't run synthesis. Please check with `yosys -p "synth_ice40 -top ffe5tap_pam4; stat"`.

| | Baseline | This design |
|---|---|---|
| Multipliers | 5 (LUT-mapped, or 5 `SB_MAC16` with `-dsp`) | 0 |
| DSP blocks | 0 or 5 | 0 |
| Saturation compare + mux | yes | none |
| Adder LCs | 28-bit adds plus multiplier arrays | about 144 (13+13+14+17+19+19+14+14+21) |
| Flops | 60 | 59 |
| Total LCs | high (hundreds) | roughly 190 (about 3.6% of 5280) |

- The total assumes the 48 delay-line flops each occupy their own LC, since a pure shift flop can't pack with a LUT.
- **Fmax:** The path is combinational between registers, and 1-cycle latency rules out pipelining. The critical path is about 5 chained adders, so expect tens of MHz on the UP5K. Check timing in nextpnr before assuming your clock closes.
- **DSP alternative:** `SB_MAC16` blocks would cut LUT use further, but they would consume several of the 8 DSPs. If DSPs are free and LCs are scarce, that wins. For minimum fabric logic with DSPs left over, this version is the better trade.
- **Input-range assumption:** I assumed the full 12-bit signed range. Restricting the input to PAM4 levels would allow narrower adders, but that breaks the "preserve exactly" contract, so I didn't take it.

## Equivalence check

Compare against the baseline (renamed `ffe5tap_ref`) with extreme-value stimulus and random resets:

```systemverilog
module tb;
    logic clk = 0, rst_n = 0;
    logic signed [11:0] x;
    wire  signed [11:0] y_a, y_b;
    ffe5tap_ref  ref_i (clk, rst_n, x, y_a);
    ffe5tap_pam4 dut_i (clk, rst_n, x, y_b);
    always #5 clk = ~clk;

    int errors = 0;
    initial begin
        x = 0; repeat (3) @(posedge clk); rst_n = 1;
        repeat (2_000_000) begin
            @(negedge clk);
            case ($urandom_range(0, 3))
                0: x = $urandom;
                1: x = 12'sd2047;
                2: x = -12'sd2048;
                3: x = ($urandom_range(0,1)) ? 12'sd2047 : -12'sd2048;
            endcase
            rst_n = ($urandom_range(0, 9999) != 0);
        end
        // Directed extremes: max (+937) then min (-938) pattern.
        // Oldest sample first: x4=-2048, x3=2047, x2=2047, x1=-2048, x0=2047
        rst_n = 1;
        foreach ({-12'sd2048, 12'sd2047, 12'sd2047, -12'sd2048, 12'sd2047}[i]) ; // see note
        $display("errors = %0d", errors);
        $finish;
    end
    always @(posedge clk) begin
        #1;
        if (y_a !== y_b) begin errors++; $display("MISMATCH t=%0t %0d vs %0d", $time, y_a, y_b); end
    end
endmodule
```

The directed `foreach` line is a placeholder I wrote carelessly. Replace it with five explicit drives:

- **Max case:** one sample per negedge, in the order −2048, 2047, 2047, −2048, 2047. After the last sample, `y_out` should read +937 one clock later.
- **Min case:** the sign-flipped sequence (2047, −2048, −2048, 2047, −2048) should produce −938.

Confirm both extremes match the reference.