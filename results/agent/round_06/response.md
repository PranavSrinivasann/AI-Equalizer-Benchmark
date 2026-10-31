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
    // 163  = 128 + 32 + 4 - 1
    assign m0 = (xe >>> 3) + (xe >>> 5) + (xe >>> 8) - (xe >>> 10);
    // -417 = -(512 - 128 + 32 + 1)
    assign m1 = -((xe >>> 1) - (xe >>> 3) + (xe >>> 5) + (xe >>> 10));
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
- Rescaled the datapath from 2^-9 to 2^-10, so the partial-sum registers and adders are 15 bits instead of 16.
- Rebased every shift term to floor(x*2^k/1024). The output slice is now sum[14:0], with no fractional guard bit.

HYPOTHESIS: Logic cells should fall by about 20 to 25 (one bit less in each of 4 adders, 4 registers and the shift-term adders). Fmax should be about the same or slightly higher because the carry chains are one bit shorter. The max error should grow to about 3 to 5 LSB, which is still under the 8 LSB limit.
