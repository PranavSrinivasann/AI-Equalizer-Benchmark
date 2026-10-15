
`timescale 1ns/1ps

module ffe5tap_tb;

    logic clk;
    logic rst_n;

    logic signed [11:0] x_in;
    logic signed [11:0] y_out;

    integer inputFile;
    integer expectedFile;

    integer inputValue;
    integer expectedValue;

    integer sampleIndex;
    integer errorCount;

    ffe5tap_pam4 dut (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_in),
        .y_out(y_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        errorCount = 0;
        sampleIndex = 0;

        inputFile = $fopen("/Users/pranavsrinivasan/Downloads/Optical Communications Project/AI-Equalizer-Benchmark/notebooks/Project/test_vectors/input_vectors.txt", "r");
        expectedFile = $fopen("/Users/pranavsrinivasan/Downloads/Optical Communications Project/AI-Equalizer-Benchmark/notebooks/Project/test_vectors/expected_vectors.txt", "r");

        if (inputFile == 0) begin
            $display("ERROR: Could not open input vector file.");
            $finish;
        end

        if (expectedFile == 0) begin
            $display("ERROR: Could not open expected vector file.");
            $finish;
        end

        rst_n = 1'b0;
        x_in = 12'sd0;

        repeat (2) @(posedge clk);

        rst_n = 1'b1;

        while (!$feof(inputFile)) begin

            if ($fscanf(inputFile, "%d\n", inputValue) != 1)
                break;

            @(negedge clk);

            x_in = inputValue;

            @(posedge clk);

            if (sampleIndex > 0) begin

                if ($fscanf(expectedFile, "%d\n", expectedValue) != 1) begin
                    $display("ERROR: Could not read expected output.");
                    $finish;
                end

                if ($signed(y_out) !== expectedValue) begin
                    errorCount = errorCount + 1;

                    if (errorCount <= 20) begin
                        $display(
                            "Mismatch at sample %0d: expected=%0d actual=%0d",
                            sampleIndex - 1,
                            expectedValue,
                            $signed(y_out)
                        );
                    end
                end
            end

            sampleIndex = sampleIndex + 1;
        end

        @(negedge clk);
        x_in = 12'sd0;

        @(posedge clk);

        if ($fscanf(expectedFile, "%d\n", expectedValue) == 1) begin
            if ($signed(y_out) !== expectedValue) begin
                errorCount = errorCount + 1;

                $display(
                    "Mismatch at final sample: expected=%0d actual=%0d",
                    expectedValue,
                    $signed(y_out)
                );
            end
        end

        $fclose(inputFile);
        $fclose(expectedFile);

        $display("");
        $display("========================================");
        $display("AI Revision 1 Verification");
        $display("========================================");
        $display("Samples tested: %0d", sampleIndex);
        $display("Total mismatches: %0d", errorCount);

        if (errorCount == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $display("========================================");

        $finish;
    end

endmodule
