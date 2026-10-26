// Directed testbench: reset, saturation and extreme-input coverage.
//
// Vector file (+VECTORS=<path>), one clock cycle per line:
//   <rst_n> <x_in> <expected_y_out> <group>
// rst_n and x_in are driven on the falling edge; y_out is checked just
// after the following rising edge (1-cycle latency, synchronous reset).
// Groups are defined in python/verification/generate_directed_vectors.py.
// Optional +DUMP=<path> writes y_out for every cycle, one value per line.

module ffe5tap_directed_tb;

    localparam int NUM_GROUPS = 10;

    logic clk = 0;
    logic rst_n = 0;
    logic signed [11:0] x_in = 0;
    logic signed [11:0] y_out;

    integer vectorFile;
    integer status;
    integer rstValue, sample, expected, group;
    integer cycles = 0;
    integer mismatches = 0;
    integer groupCycles     [NUM_GROUPS];
    integer groupMismatches [NUM_GROUPS];
    integer expectedCycles = -1;
    string  vectorPath;
    string  dumpPath;
    integer dumpFile = 0;

    ffe5tap_pam4 dut (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_in),
        .y_out(y_out)
    );

    always #5 clk = ~clk;

    initial begin
        for (int g = 0; g < NUM_GROUPS; g++) begin
            groupCycles[g] = 0;
            groupMismatches[g] = 0;
        end

        if (!$value$plusargs("VECTORS=%s", vectorPath)) begin
            $display("ERROR: Missing +VECTORS=<path>");
            $fatal(1);
        end
        void'($value$plusargs("CYCLES=%d", expectedCycles));

        if ($value$plusargs("DUMP=%s", dumpPath)) begin
            dumpFile = $fopen(dumpPath, "w");
            if (dumpFile == 0) begin
                $display("ERROR: Could not open %s", dumpPath);
                $fatal(1);
            end
        end

        vectorFile = $fopen(vectorPath, "r");
        if (vectorFile == 0) begin
            $display("ERROR: Could not open %s", vectorPath);
            $fatal(1);
        end

        while (!$feof(vectorFile)) begin
            status = $fscanf(vectorFile, "%d %d %d %d\n",
                             rstValue, sample, expected, group);
            if (status != 4) continue;
            if (group < 0 || group >= NUM_GROUPS) group = 0;

            @(negedge clk);
            rst_n = rstValue[0];
            x_in  = sample[11:0];

            @(posedge clk);
            #1;

            cycles++;
            groupCycles[group]++;
            if (dumpFile != 0) $fdisplay(dumpFile, "%0d", $signed(y_out));

            if ($signed(y_out) !== expected) begin
                mismatches++;
                groupMismatches[group]++;
                if (mismatches <= 20)
                    $display("Mismatch cycle %0d (group %0d): rst_n=%0d x_in=%0d expected=%0d actual=%0d",
                             cycles, group, rstValue, sample, expected, $signed(y_out));
            end
        end
        $fclose(vectorFile);
        if (dumpFile != 0) $fclose(dumpFile);

        $display("========================================");
        $display("Directed Verification: %s", vectorPath);
        for (int g = 1; g < NUM_GROUPS; g++)
            if (groupCycles[g] > 0)
                $display("  group %0d: %0d cycles, %0d mismatches",
                         g, groupCycles[g], groupMismatches[g]);
        $display("Cycles tested: %0d", cycles);
        $display("Total mismatches: %0d", mismatches);

        if (expectedCycles >= 0 && cycles != expectedCycles)
            $display("RESULT: FAIL (expected %0d cycles)", expectedCycles);
        else if (cycles == 0)
            $display("RESULT: FAIL (no vectors read)");
        else if (mismatches == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $display("========================================");
        $finish;
    end

endmodule
