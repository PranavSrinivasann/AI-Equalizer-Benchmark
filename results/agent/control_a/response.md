```systemverilog
// Transposed-form FFE with a shared multiplier block (shift-add), exact arithmetic.
// Coefficients [163, -417, 782, -1268, 1536] (Q1.10).
//   t3 = 3x, t5 = 5x, t7 = 7x
//   163  = 5*32 + 3
//   -417 = 3*32 - 512 - 1  (times x)
//   782  = 3*256 + 7*2
//   -1268 = 3*4 - 5*256
//   1536 = 3*512
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // small multiples of x, sized to their range
    logic signed [13:0] t3_s;
    logic signed [14:0] t5_s, t7_s;
    logic signed [14:0] x15;
    logic signed [13:0] x14;

    assign x14  = x_in;
    assign x15  = x_in;
    assign t3_s = x14 + (x14 <<< 1);
    assign t5_s = x15 + (x15 <<< 2);
    assign t7_s = (x15 <<< 3) - x15;

    // 25-bit accumulator domain
    logic signed [24:0] x25, t3, t5, t7;
    assign x25 = x_in;
    assign t3  = t3_s;
    assign t5  = t5_s;
    assign t7  = t7_s;

    logic signed [24:0] p0, p1, p2, p3, p4;
    assign p0 = (t5 <<< 5) + t3;                  //  163 x
    assign p1 = (t3 <<< 5) - (x25 <<< 9) - x25;   // -417 x
    assign p2 = (t3 <<< 8) + (t7 <<< 1);          //  782 x
    assign p3 = (t3 <<< 2) - (t5 <<< 8);          // -1268 x
    assign p4 = t3 <<< 9;                         //  1536 x

    logic signed [24:0] s1, s2, s3, s4;
    logic signed [24:0] sum;
    assign sum = s1 + p0;

    logic ovf;
    assign ovf = ~((sum[24:21] == 4'b0000) || (sum[24:21] == 4'b1111));

    logic signed [11:0] y_sat;
    always_comb begin
        if (ovf)
            y_sat = sum[24] ? -12'sd2048 : 12'sd2047;
        else
            y_sat = sum[21:10];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s1    <= '0;
            s2    <= '0;
            s3    <= '0;
            s4    <= '0;
            y_out <= 12'sd0;
        end else begin
            s4    <= p4;
            s3    <= s4 + p3;
            s2    <= s3 + p2;
            s1    <= s2 + p1;
            y_out <= y_sat;
        end
    end
endmodule
```

CHANGE SUMMARY:
- Replaced the five generic multipliers and the 48-flop input delay line with a transposed-form FIR. The partial-sum registers sit behind the adders, so the flops share cells with them.
- All five constant multiplies now come from shared 3x, 5x and 7x terms, using about 8 small adders. The arithmetic is still exact.
- Saturation is a 4-bit sign-run check on the top bits of the sum, and the sum is 25 bits wide.

HYPOTHESIS: Logic cells should drop from 867 to roughly 400-500, since the generic multipliers and the delay-line flops are gone. Fmax should rise from 17.8 MHz to about 25-30 MHz, because the critical path is now one shared-term chain plus one add. The output should stay bit-exact, so G2 and G3 should pass. Later rounds can truncate low bits for further savings.
