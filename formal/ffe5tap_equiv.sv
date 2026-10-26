// Equivalence miter: proves two FFE implementations produce identical
// y_out on every cycle, for every input sequence and every reset pattern.
// "gold" is the baseline (reference) design and "gate" is the design under
// test; both are renamed from ffe5tap_pam4 by the .sby script.

module ffe5tap_equiv (
    input logic               clk,
    input logic               rst_n,
    input logic signed [11:0] x_in
);

    logic signed [11:0] y_gold, y_gate;

    gold u_gold (.clk(clk), .rst_n(rst_n), .x_in(x_in), .y_out(y_gold));
    gate u_gate (.clk(clk), .rst_n(rst_n), .x_in(x_in), .y_out(y_gate));

    // Start both designs from reset; registers power up unknown otherwise.
    // After the first cycle rst_n and x_in are completely unconstrained,
    // so the proof also covers mid-stream and repeated resets.
    logic init = 1'b1;
    always_ff @(posedge clk) init <= 1'b0;

    always_comb begin
        if (init) assume (!rst_n);
        if (!init) assert (y_gold == y_gate);
    end

endmodule
