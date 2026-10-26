# Resource-minimized 5-tap FFE for the iCE40 UP5K

The biggest savings come from three changes:

1. **Transposed form.** The 48-bit input delay line becomes a chain of partial-sum registers, and most of those registers share a logic cell with the adder that feeds them.
2. **Shared shift-add constant multiplication.** All five coefficients are built with 7 shared adders, using no DSPs and no `*` operators.
3. **Exact bit widths.** Every node is sized from its true value range. The saturation logic shrinks to a 13-bit "all bits equal" test.

The resource numbers below are my hand estimates. I have not synthesized this, so check them with Yosys `stat` and nextpnr before relying on them.

## RTL

```systemverilog
// ffe5tap_pam4 - minimum-LUT iCE40 UP5K implementation
//
// Function (bit-exact with the baseline):
//   acc[n]   = -483*x[n] + 1536*x[n-1] - 398*x[n-2] - 165*x[n-3] + 106*x[n-4]
//   y[n+1]   = sat12(acc[n] >>> 10)          (Q3.8 in/out, Q1.10 coeffs)
//
// Architecture: transposed-form FIR + multiple-constant-multiplication (MCM)
// adder graph, all operands at minimum exact width.  No DSP, no EBR.
//
// Shared constant multiplier graph (7 adders):
//   t3   = x + 2x               =   3x
//   t5   = x + 4x               =   5x
//   t99  = t3 + 32*t3           =  99x
//   t53  = 16*t3 + t5           =  53x     (106  =   2*53)
//   t165 = t5 + 32*t5           = 165x
//   t199 = 2*t99 + x            = 199x     (398  =   2*199)
//   t483 = 128*t3 + t99         = 483x
//                                          (1536 = 512*3)
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // ------------------------------------------------------------------
    // 1. Multiple-constant multiplier (all products of the current sample)
    //    Widths are the exact minimum signed widths for x in [-2048, 2047].
    // ------------------------------------------------------------------
    logic signed [13:0] t3;    //   3x : |.| <=    6144
    logic signed [14:0] t5;    //   5x : |.| <=   10240
    logic signed [18:0] t99;   //  99x : |.| <=  202752
    logic signed [17:0] t53;   //  53x : |.| <=  108544
    logic signed [19:0] t165;  // 165x : |.| <=  337920
    logic signed [19:0] t199;  // 199x : |.| <=  407552
    logic signed [20:0] t483;  // 483x : |.| <=  989184

    assign t3   = x_in + $signed({x_in, 1'b0});
    assign t5   = x_in + $signed({x_in, 2'b00});
    assign t99  = t3   + $signed({t3,   5'b0});
    assign t53  = $signed({t3, 4'b0}) + t5;
    assign t165 = t5   + $signed({t5,   5'b0});
    assign t199 = $signed({t99, 1'b0}) + x_in;
    assign t483 = $signed({t3, 7'b0}) + t99;

    // ------------------------------------------------------------------
    // 2. Transposed partial-sum chain
    //    q4 = 53*x[n-1]                     (r4 = 106*x[n-1] = 2*q4)
    //    r3 = 106*x[n-2] - 165*x[n-1]
    //    r2 = r3 - 398*x                    ...
    //    r1 = r2 + 1536*x
    //    Exact extreme values set each width (no wrap anywhere):
    //      r3 in [-554843,   554902]   -> 21 b
    //      r2 in [-1369549, 1370006]   -> 22 b
    //      r1 in [-4515277, 4514198]   -> 24 b
    //      acc in [-5503978, 5503382]  -> 24 b
    // ------------------------------------------------------------------
    logic signed [17:0] q4;
    logic signed [20:0] r3;
    logic signed [21:0] r2;
    logic signed [23:0] r1;

    logic signed [20:0] r3_d;
    logic signed [21:0] r2_d;
    logic signed [23:0] r1_d;
    logic signed [23:0] acc;

    assign r3_d = $signed({q4,   1'b0}) - t165;   //  +106x[n-1] - 165x[n]
    assign r2_d = r3 - $signed({t199, 1'b0});      //  -398x[n]
    assign r1_d = r2 + $signed({t3,   9'b0});      // +1536x[n]
    assign acc  = r1 - t483;                       //  -483x[n]

    // ------------------------------------------------------------------
    // 3. >>>10 and saturation, reduced to the exact logic required.
    //    shifted = acc[23:10].  It fits in 12 bits iff acc[23:11] all equal.
    //    In-range:   y = acc[21:10] = {acc[23], acc[20:10]}
    //    Overflow:   y = {sgn, {11{~sgn}}}   (+2047 or -2048)
    //    So y[11] = acc[23] in every case; only y[10:0] need a mux.
    // ------------------------------------------------------------------
    logic               sgn, ovf;
    logic signed [11:0] y_d;

    assign sgn = acc[23];
    assign ovf = (acc[22:11] != {12{sgn}});
    assign y_d = ovf ? {sgn, {11{~sgn}}} : {sgn, acc[20:10]};

    // ------------------------------------------------------------------
    // 4. State: synchronous active-low reset (maps to SB_DFFSR, no LUT cost)
    // ------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            q4    <= '0;
            r3    <= '0;
            r2    <= '0;
            r1    <= '0;
            y_out <= '0;
        end else begin
            q4    <= t53;
            r3    <= r3_d;
            r2    <= r2_d;
            r1    <= r1_d;
            y_out <= y_d;
        end
    end

endmodule
```

## Why it matches the baseline exactly

- **Same equation, no wrapping.** The baseline computes Σ Cₖ·x[n−k] at 28 bits. I worked out the true minimum and maximum of every intermediate value, so each node is exactly as wide as it needs to be and never overflows. The 24-bit `acc` therefore equals the baseline's 28-bit `acc` for every input.
- **Same reset behavior.** In the baseline, reset zeroes x1–x4, and their contribution to the sum becomes zero. Here, reset zeroes q4, r3, r2 and r1, which are exactly those zero contributions already summed. The outputs match cycle for cycle during reset, right after it, and from then on.
- **Same latency.** `x_in` reaches `y_out` through the combinational path `acc → sat → y_out` and then one register, just as in the baseline. Throughput is still 1 sample per cycle.
- **Saturation is the same function, rewritten.** The baseline's `shifted > 2047` / `< -2048` test is true exactly when `acc[23:11]` are not all equal. The saturated output's sign bit always equals `acc[23]`, so `y[11]` needs no mux.

## The architectural changes

**1. Transposed form instead of direct form.** On the iCE40, each logic cell (LC) has one LUT4 and one flip-flop, but only one output. A flip-flop can share an LC only if its LUT drives nothing but that flip-flop. A plain delay register has no LUT, so it costs a whole LC.

- **Baseline:** x1–x4 are 48 such registers, so 48 LCs do nothing but store.
- **This design:** the stored values are the outputs of the chain adders (`r3_d`, `r2_d`, `r1_d`, `t53`), and each feeds only its register. About 80 of the 97 flip-flops share an LC with the adder bit above them.
- **What remains:** about 14 storage-only bits that cannot be avoided. Nine are r1's low bits, which come straight from r2 because 1536 has nine trailing zeros. Four are q4's low bits.

**2. Shared shift-add multipliers on one input.** Transposed form has a second benefit: all five products use the same sample, `x_in`, so they can share sub-products.

- **Per-coefficient shift-add (CSD), no sharing:** 13 adders.
- **Best per-coefficient factoring:** 12 adders.
- **Shared graph used here:** 7 adders.
- **Lower bound:** there are 5 distinct odd constants (3, 53, 165, 199, 483), so at least 5 adders are needed. I searched by hand for 6-adder graphs with a single shared intermediate and found none. That search did not cover every possible graph.
- **Free taps:** the `1536 = 3·2⁹` tap reuses `t3` at no cost. Negative coefficients become subtractions in the chain, which cost the same as additions on the iCE40 carry chain.

**3. Exact widths everywhere.** Synthesis tools trim widths only from the declared operand sizes. Yosys cannot tell that a sum of five 24-bit products fits in 24 bits, so the baseline keeps a 27–28-bit adder tree. It also builds two 28-bit comparators, which are effectively two more carry chains. Here, every adder starts at its operand's lowest nonzero bit and stops at its exact top bit. The two comparators become about 5 LUT4s for the "all equal" test and 11 LUT3 muxes, and those muxes share LCs with `y_out`.

**4. Sync reset costs nothing.** The reset maps onto `SB_DFFSR`. All flip-flops share `clk` and `rst_n`, so the PLB packing rules are not a problem.

## Estimated resources (hand count, not yet measured)

| Block | LCs (approx.) |
|---|---|
| Shared multipliers (t3, t5, t99, t53, t165, t199, t483) | ~102 |
| q4 low-bit storage | 4 |
| r3 / r2 / r1 chain adders, registers shared | ~21 / ~22 / ~24 |
| acc adder (low 10 bits are only the carry chain) | ~24 |
| Saturation + `y_out` | ~17 |
| **Total** | **~215 LCs (~4% of 5280), 97 FFs, 0 DSP, 0 EBR** |

How that compares (also unmeasured):
- **Direct form with per-tap shift-add:** roughly 320–340 LCs (48 storage-only LCs, about 180 LCs of multipliers, about 90 for a 4-adder tree, plus saturation).
- **Baseline built from fabric:** typically several hundred LCs more, because of generic signed constant multipliers, the 28-bit tree and the 28-bit comparators.
- **Baseline with `-dsp`:** about 5 SB_MAC16 blocks plus around 100 LCs.

## Tradeoffs

- **More flip-flops, fewer LCs.** Flip-flops go from 60 to 97, but most share an LC with an adder. On the iCE40, LC count is the scarce resource, not flip-flop count.
- **Longer critical path.** The path is `x_in → t3 → t99 → t483 → acc (24-bit) → sat → y_out`, which is four carry chains in series plus about 2 LUT levels. That is comparable to or shorter than the baseline's multiplier array plus 5-input tree plus 28-bit compares, but it is the price of sharing. If Fmax becomes a constraint, build 483 as `(x<<9) − (x<<5) + t3`. That costs one more adder (about 21 LCs) and removes one chain from the path.
- **High fanout on `x_in` and `t3`.** They feed 3–4 adders each. That is a routing cost, not a logic cost.
- **DSP option.** The four non-trivial taps could each go into an SB_MAC16, using its built-in adder to add the incoming partial sum and its output register as `r_k`. That would bring fabric use down to about 40–60 LCs, but it uses 4 of the UP5K's 8 DSPs. If the goal is minimum total resources, the fabric version is the better choice. Use the DSP version only if your benchmark treats DSPs as free.

## Checking it

- **Synthesis:** run `yosys -p "synth_ice40 -abc9 -top ffe5tap_pam4; stat"` without `-dsp` on both designs and compare `SB_LUT4`, `SB_CARRY` and `SB_DFF*` counts. Then compare logic-cell counts after nextpnr placement, since that is the number that matters.
- **Proving equivalence:** a filter like this remembers only its last 4 inputs, so every reachable state can be reached within a few cycles of reset. A short bounded model check (about 8 cycles, with `x_in` and `rst_n` left free) on a miter of the two designs is therefore a full proof of equivalence. It is cheap to run in SymbiYosys.
- **Simulation:** run a sweep over extreme input values to make sure saturation actually triggers. `shifted` reaches [−5375, 5374], so both saturation limits are hit.
