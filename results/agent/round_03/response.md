```systemverilog
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Transposed-form FIR, CSD shift-add, datapath scaled by 2^-6 (19 bits instead of 25).
    // Each term is (x * 2^k) >>> 6 with floor; total truncation error is well under 2 output LSB.
    logic signed [18:0] xe;
    assign xe = x_in;

    logic signed [18:0] m0, m1, m2, m3, m4;
    // 163  = 128 + 32 + 4 - 1
    assign m0 = (xe <<< 1) + (xe >>> 1) + (xe >>> 4) - (xe >>> 6);
    // -417 = -(512 - 128 + 32 + 1)
    assign m1 = -((xe <<< 3) - (xe <<< 1) + (xe >>> 1) + (xe >>> 6));
    // 782  = 512 + 256 + 16 - 2
    assign m2 = (xe <<< 3) + (xe <<< 2) + (xe >>> 2) - (xe >>> 5);
    // -1268 = -(1024 + 256 - 16 + 4)
    assign m3 = -((xe <<< 4) + (xe <<< 2) - (xe >>> 2) + (xe >>> 4));
    // 1536 = 1024 + 512
    assign m4 = (xe <<< 4) + (xe <<< 3);

    logic signed [18:0] s1, s2, s3, s4;

    logic signed [18:0] sum;
    assign sum = s1 + m0;

    logic signed [14:0] sh;
    assign sh = sum[18:4];

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
            s1    <= 19'sd0;
            s2    <= 19'sd0;
            s3    <= 19'sd0;
            s4    <= 19'sd0;
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
- Rescaled the whole datapath by 2^-6. Each shift-add term is now floor(x*2^k / 64), so the partial-sum registers and adders are 19 bits instead of 25.
- The saturation slice moves to sum[18:4], which is the same output alignment as before.

HYPOTHESIS: Logic cells should drop by about 20-25% (roughly 370-390), because adders, carry cells and flip-flops are about 6 bits narrower. Fmax should rise a little, to roughly 42-45 MHz, from shorter carry chains. Truncation error is about 1-2 output LSB at worst, so G2 and G3 should still pass.
