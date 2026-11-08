// Streams a vector file through ffe_pam4 and dumps y_out for every cycle.
// +VECTORS=<path>: one "<rst_n> <x_in>" pair per line.  +DUMP=<path>: output.
// Build with -GW=<sample bits>.
module ffe_stream_tb #(parameter int W = 12);
    logic clk = 0;
    logic rst_n = 0;
    logic signed [W-1:0] x_in = 0;
    logic signed [W-1:0] y_out;
    integer vf, df, status, rv, sv, cycles = 0;
    string vpath, dpath;

    ffe_pam4 dut (.clk(clk), .rst_n(rst_n), .x_in(x_in), .y_out(y_out));
    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("VECTORS=%s", vpath) || !$value$plusargs("DUMP=%s", dpath)) begin
            $display("ERROR: need +VECTORS and +DUMP");
            $fatal(1);
        end
        vf = $fopen(vpath, "r");
        df = $fopen(dpath, "w");
        while (!$feof(vf)) begin
            status = $fscanf(vf, "%d %d\n", rv, sv);
            if (status != 2) continue;
            @(negedge clk);
            rst_n = rv[0];
            x_in = sv[W-1:0];
            @(posedge clk);
            #1;
            cycles++;
            $fdisplay(df, "%0d", $signed(y_out));
        end
        $fclose(vf);
        $fclose(df);
        $display("Cycles tested: %0d", cycles);
        $finish;
    end
endmodule
