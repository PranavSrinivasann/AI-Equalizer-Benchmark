```systemverilog
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Transposed-form FIR, CSD shift-add, datapath scaled by 2^-10 (15 bits).
    // Each term is floor(x * 2^k / 1024); the output is sum[14:0] with no guard bit.
    logic signed [14:0] xe;
    assign xe = x_in;

    logic signed [14:0] m0, m1, m2, m3, m4;
    // 163 approximated as 164 = 128 + 32 + 4
    assign m0 = (xe >>> 3) + (xe >>> 5) + (xe >>> 8);
    // -417 approximated as -416 = -(512 - 128 + 32)
    assign m1 = -((xe >>> 1) - (xe >>> 3) + (xe >>> 5));
    // 782  = 512 + 256 + 16 - 2
    assign m2 = (xe >>> 1) + (xe >>> 2) + (xe >>> 6) - (xe >>> 9);
    // -1268 = -(1024 + 256 - 16 + 4)
    assign m3 = -(xe + (xe >>> 2) - (xe >>> 6) + (xe >>> 8));
    // 1536 = 1024 + 512
    assign m4 = xe + (xe >>> 1);

    logic signed [14:0] s1, s2, s3, s4;

    logic signed [14:0] sum;
    assign sum = s1 + m0;

    logic signed [11:0] y_sat;
    always_comb begin
        if (sum[14:11] == 4'b0000 || sum[14:11] == 4'b1111)
            y_sat = sum[11:0];
        else if (sum[14])
            y_sat = -12'sd2048;
        else
            y_sat = 12'sd2047;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s1    <= 15'sd0;
            s2    <= 15'sd0;
            s3    <= 15'sd0;
            s4    <= 15'sd0;
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
- Approximated c1 from -417 to -416 by dropping the +(xe>>>10) term, so m1 has 3 shift terms instead of 4.
- Everything else is unchanged from round 7.

HYPOTHESIS: One 15-bit adder goes away, so I expect about 12-15 fewer logic cells (roughly 270) and a slightly shorter m1 path, with Fmax flat or a little higher. The extra error is at most about 2 LSB, which should keep the maximum error under the 8 LSB limit and BER/SER well under 2e-4.
