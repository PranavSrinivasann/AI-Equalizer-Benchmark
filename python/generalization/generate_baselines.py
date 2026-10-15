from pathlib import Path
import sys

projectRoot = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(projectRoot / "python"))

from coefficient_sets import coefficientSets

outputDir = projectRoot / "rtl" / "generalization"
outputDir.mkdir(parents=True, exist_ok=True)


def formatCoefficient(coefficient):
    if coefficient < 0:
        return f"-12'sd{abs(coefficient)}"
    return f"12'sd{coefficient}"


rtlTemplate = """\
module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);

    localparam signed [11:0] C0 = {c0};
    localparam signed [11:0] C1 = {c1};
    localparam signed [11:0] C2 = {c2};
    localparam signed [11:0] C3 = {c3};
    localparam signed [11:0] C4 = {c4};

    logic signed [11:0] x1, x2, x3, x4;
    logic signed [23:0] p0, p1, p2, p3, p4;

    assign p0 = x_in * C0;
    assign p1 = x1   * C1;
    assign p2 = x2   * C2;
    assign p3 = x3   * C3;
    assign p4 = x4   * C4;

    logic signed [27:0] p0_ext, p1_ext, p2_ext, p3_ext, p4_ext;
    assign p0_ext = p0;
    assign p1_ext = p1;
    assign p2_ext = p2;
    assign p3_ext = p3;
    assign p4_ext = p4;

    logic signed [27:0] acc;
    assign acc = p0_ext + p1_ext + p2_ext + p3_ext + p4_ext;

    logic signed [27:0] shifted;
    assign shifted = acc >>> 10;

    localparam signed [27:0] MAX_12 = 28'sd2047;
    localparam signed [27:0] MIN_12 = -28'sd2048;

    logic signed [11:0] y_sat;

    always_comb begin
        if (shifted > MAX_12)
            y_sat = 12'sd2047;
        else if (shifted < MIN_12)
            y_sat = -12'sd2048;
        else
            y_sat = shifted[11:0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x1    <= 12'sd0;
            x2    <= 12'sd0;
            x3    <= 12'sd0;
            x4    <= 12'sd0;
            y_out <= 12'sd0;
        end else begin
            x4    <= x3;
            x3    <= x2;
            x2    <= x1;
            x1    <= x_in;
            y_out <= y_sat;
        end
    end
endmodule
"""

for caseName in ("B", "C"):
    coefficients = coefficientSets[caseName]

    formatted = rtlTemplate.format(
        c0=formatCoefficient(coefficients[0]),
        c1=formatCoefficient(coefficients[1]),
        c2=formatCoefficient(coefficients[2]),
        c3=formatCoefficient(coefficients[3]),
        c4=formatCoefficient(coefficients[4]),
    )

    outputPath = outputDir / f"ffe5tap_case{caseName}_baseline.sv"
    outputPath.write_text(formatted)

    print(f"Created {outputPath}: {coefficients}")