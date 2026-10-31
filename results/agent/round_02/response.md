```systemverilog
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Transposed-form FIR with CSD shift-add constants.
    // Coefficients [163, -417, 782, -1268, 1536]
    // Worst-case |sum| is about 8.53M, which is above 2^23, so the datapath is 25 bits wide.
    logic signed [24:0] x;
    assign x = x_in;

    logic signed [24:0] m0, m1, m2, m3, m4;
    // 163  = 128 + 32 + 4 - 1
    assign m0 = (x <<< 7) + (x <<< 5) + (x <<< 2) - x;
    // -417 = -(512 - 128 + 32 + 1)
    assign m1 = -((x <<< 9) - (x <<< 7) + (x <<< 5) + x);
    // 782  = 512 + 256 + 16 - 2
    assign m2 = (x <<< 9) + (x <<< 8) + (x <<< 4) - (x <<< 1);
    // -1268 = -(1024 + 256 - 16 + 4)
    assign m3 = -((x <<< 10) + (x <<< 8) - (x <<< 4) + (x <<< 2));
    // 1536 = 1024 + 512
    assign m4 = (x <<< 10) + (x <<< 9);

    logic signed [24:0] s1, s2, s3, s4;

    logic signed [24:0] sum;
    assign sum = s1 + m0;

    logic signed [14:0] sh;
    assign sh = sum[24:10];

    logic signed [11:0] y_sat;
    always_comb begin
        if (sh[14:11] == 4'b0000 || sh[14:11] == 4'b1111)
            y_sat = sh[11:0];
        else if (sh[14])
            y_sat = -12'sd2048;
        else
            y_sat = 12'sd2047;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s1    <= 25'sd0;
            s2    <= 25'sd0;
            s3    <= 25'sd0;
            s4    <= 25'sd0;
            y_out <= 12'sd0;
        end else begin
            s4    <= m4;
            s3    <= s4 + m3;
            s2    <= s3 + m2;
            s1    <= s2 + m1;
            y_out <= y_sat;
        end
    end
endmodule
```

CHANGE SUMMARY:
- Widened the accumulator and partial-sum registers from 24 to 25 bits. The worst-case sum is about 8.53M, which is above 2^23 and wrapped around.
- Widened the saturation check to match: it now looks at sum[24:10] and tests the top 4 bits.

HYPOTHESIS: Round 1 failed G2 only on extreme inputs, which matches the 24-bit overflow, so this should pass G2 and G3. Logic cells rise slightly from the extra bit per stage. Fmax should be about the same as round 1 would have been, set by one 4-term constant add and the adder into the partial-sum register.
