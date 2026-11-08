```systemverilog
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Transposed-form FIR, CSD shift-add, datapath scaled by 2^-8 (17 bits).
    // Each term is floor(x * 2^k / 256); the output slice is sum[16:2].
    logic signed [16:0] xe;
    assign xe = x_in;

    logic signed [16:0] m0, m1, m2, m3, m4;
    // 163  = 128 + 32 + 4 - 1
    assign m0 = (xe >>> 1) + (xe >>> 3) + (xe >>> 6) - (xe >>> 8);
    // -417 = -(512 - 128 + 32 + 1)
    assign m1 = -((xe <<< 1) - (xe >>> 1) + (xe >>> 3) + (xe >>> 8));
    // 782  = 512 + 256 + 16 - 2
    assign m2 = (xe <<< 1) + xe + (xe >>> 4) - (xe >>> 7);
    // -1268 = -(1024 + 256 - 16 + 4)
    assign m3 = -((xe <<< 2) + xe - (xe >>> 4) + (xe >>> 6));
    // 1536 = 1024 + 512
    assign m4 = (xe <<< 2) + (xe <<< 1);

    logic signed [16:0] s1, s2, s3, s4;

    logic signed [16:0] sum;
    assign sum = s1 + m0;

    logic signed [14:0] sh;
    assign sh = sum[16:2];

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
            s1    <= 17'sd0;
            s2    <= 17'sd0;
            s3    <= 17'sd0;
            s4    <= 17'sd0;
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
- Rescaled the datapath from 2^-6 to 2^-8, so the partial-sum registers and adders are 17 bits instead of 19.
- The shift terms are rebased to match, and the saturation slice moves to sum[16:2].

HYPOTHESIS: Logic cells should fall by about 10% (roughly 350) because every adder and register is 2 bits narrower. Fmax should rise slightly from the shorter carry chains. The worst-case truncation error should stay under about 5 LSB, so G2 and G3 should still pass.
