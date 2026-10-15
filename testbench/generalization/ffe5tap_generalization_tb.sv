module ffe5tap_generalization_tb;

    logic clk = 0;
    logic rst_n = 0;
    logic signed [11:0] x_in = 0;
    logic signed [11:0] y_out;

    integer inputFile;
    integer expectedFile;
    integer inputStatus;
    integer expectedStatus;
    integer sample;
    integer expected;
    integer samplesTested = 0;
    integer mismatches = 0;
    integer resetCycles;

    string inputPath;
    string expectedPath;

    ffe5tap_pam4 dut (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_in),
        .y_out(y_out)
    );

    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("INPUT=%s", inputPath)) begin
            $display("ERROR: Missing +INPUT=<path>");
            $fatal(1);
        end

        if (!$value$plusargs("EXPECTED=%s", expectedPath)) begin
            $display("ERROR: Missing +EXPECTED=<path>");
            $fatal(1);
        end

        inputFile = $fopen(inputPath, "r");
        expectedFile = $fopen(expectedPath, "r");

        if (inputFile == 0 || expectedFile == 0) begin
            $display("ERROR: Could not open vector files.");
            $fatal(1);
        end

        // Apply synchronous active-low reset.
        repeat (2) @(negedge clk);
        rst_n = 0;
        x_in = 0;

        repeat (2) @(negedge clk);
        rst_n = 1;

        while (!$feof(inputFile) && !$feof(expectedFile)) begin
            inputStatus = $fscanf(inputFile, "%d\n", sample);
            expectedStatus = $fscanf(expectedFile, "%d\n", expected);

            if (inputStatus == 1 && expectedStatus == 1) begin
                @(negedge clk);
                x_in = sample;

                @(posedge clk);
                #1;

                samplesTested = samplesTested + 1;

                if ($signed(y_out) !== expected) begin
                    mismatches = mismatches + 1;

                    if (mismatches <= 10) begin
                        $display(
                            "Mismatch sample %0d: input=%0d expected=%0d actual=%0d",
                            samplesTested,
                            sample,
                            expected,
                            $signed(y_out)
                        );
                    end
                end
            end
        end

        $fclose(inputFile);
        $fclose(expectedFile);

        $display("========================================");
        $display("Generalization Baseline Verification");
        $display("Samples tested: %0d", samplesTested);
        $display("Total mismatches: %0d", mismatches);

        if (samplesTested != 1000) begin
            $display("RESULT: FAIL (unexpected sample count)");
            $finish;
        end

        if (mismatches == 0) begin
            $display("RESULT: PASS");
        end else begin
            $display("RESULT: FAIL");
        end

        $display("========================================");
        $finish;
    end

endmodule
