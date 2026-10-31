```systemverilog
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    // Transposed-form FIR, CSD shift-add, datapath scaled by 2^-9 (16 bits).
    // Each term is floor(x * 2^k / 512); the output slice is sum[15:1].
    logic signed [15:0] xe;
    assign xe = x_in;

    logic signed [15:0] m0, m1, m2, m3, m4;
    // 163  = 128 + 32 + 4 - 1
    assign m0 = (xe >>> 2) + (xe >>> 4) + (xe >>> 7) - (xe >>> 9);
    // -417 = -(512 - 128 + 32 + 1)
    assign m1 = -(xe - (xe >>> 2) + (xe >>> 4) + (xe >>> 9));
    // 782  = 512 + 256 + 16 - 2
    assign m2 = xe + (xe >>> 1) + (xe >>> 5) - (xe >>> 8);
    // -1268 = -(1024 + 256 - 16 + 4)
    assign m3 = -((xe <<< 1) + (xe >>> 1) - (xe >>> 5) + (xe >>> 7));
    // 1536 = 1024 + 512
    assign m4 = (xe <<< 1) + xe;

    logic signed [15:0] s1, s2, s3, s4;

    logic signed [15:0] sum;
    assign sum = s1 + m0;

    logic signed [14:0] sh;
    assign sh = sum[15:1];

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
            s1    <= 16'sd0;
            s2    <= 16'sd0;
            s3    <= 16'sd0;
            s4    <= 16'sd0;
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
- Rescaled the datapath from 2^-8 to 2^-9, so the partial-sum registers and adders are 16 bits instead of 17.
- Rebased every shift term to floor(x*2^k/512), and moved the saturation slice to sum[15:1].

HYPOTHESIS: About 16 fewer logic cells (roughly 330) and a slightly shorter carry chain, so Fmax rises by about 1 MHz. Worst-case error should grow to about 2 LSB, well inside the 8 LSB limit, and the BER should stay near 1e-5.
