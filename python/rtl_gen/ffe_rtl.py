"""SystemVerilog generators for fixed-coefficient 5-tap FFEs.

baseline_rtl(): the reference architecture (five multiplies, 28-bit
    accumulator, explicit saturation), identical in structure to
    rtl/generalization/ffe5tap_case{B,C}_baseline.sv.
hand_csd_rtl(): the hand-optimized reference (per-tap CSD shift-add,
    accumulator sized to the worst-case bound, saturation kept only when
    it is reachable), as in rtl/hand/.

Both produce module ffe5tap_pam4 with the standard ports.
Usage:  python3 python/rtl_gen/ffe_rtl.py --name caseA 51 -154 1024 154 -51
"""

import argparse
from pathlib import Path

TAPS = ["x_in", "x1", "x2", "x3", "x4"]

_REGISTERS = """    always_ff @(posedge clk) begin
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
            y_out <= {next};
        end
    end"""

_PORTS = """module ffe5tap_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [11:0] x_in,
    output logic signed [11:0] y_out
);"""


def _check(coefficients):
    coefficients = [int(c) for c in coefficients]
    if len(coefficients) != 5 or any(not -2048 <= c <= 2047 for c in coefficients):
        raise ValueError("need five Q1.10 coefficients in [-2048, 2047]")
    return coefficients


def _literal(value, bits=12):
    return f"{bits}'sd{value}" if value >= 0 else f"-{bits}'sd{-value}"


def csd_digits(n):
    """Canonical signed-digit form of n >= 0 as [(+1 or -1, shift)], MSB first."""
    digits, shift = [], 0
    while n:
        if n & 1:
            d = 2 - (n & 3)
            n -= d
            digits.append((d, shift))
        n //= 2
        shift += 1
    return digits[::-1]


def baseline_rtl(coefficients, header=""):
    c = _check(coefficients)
    params = "\n".join(f"    localparam signed [11:0] C{i} = {_literal(v)};" for i, v in enumerate(c))
    prefix = "".join(f"// {line}\n" if line else "//\n" for line in header.splitlines())
    return f"""{prefix}{_PORTS}

{params}

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

{_REGISTERS.format(next="y_sat")}
endmodule
"""


def hand_csd_rtl(coefficients, name):
    c = _check(coefficients)
    l1 = sum(abs(v) for v in c)
    saturate = l1 >= 1024
    width = max(int(2048 * l1).bit_length() + 1, 22 if not saturate else 0)

    extend = "\n".join(
        f"    logic signed [{width - 1}:0] xe{i};  assign xe{i} = {t};" for i, t in enumerate(TAPS))

    taps = []
    for i, value in enumerate(c):
        sign = 1 if value >= 0 else -1
        digits = csd_digits(abs(value))
        if not digits:
            taps.append(f"    // tap {i}:     0\n    assign t{i} = '0;")
            continue
        terms = []
        for d, k in digits:
            op = "+" if d * sign > 0 else "-"
            terms.append(f"{op} (xe{i} <<< {k})" if k else f"{op} xe{i}")
        expr = " ".join(terms)
        if expr.startswith("+ "):
            expr = expr[2:]
        form = " ".join(("+" if d > 0 else "-") + f"2^{k}" for d, k in digits).lstrip("+")
        shown = form if sign > 0 else f"-({form})"
        taps.append(f"    // tap {i}: {value:5d} = {shown}\n    assign t{i} = {expr};")

    if saturate:
        sw = width - 10
        output = f"""    // sum|c| = {l1} >= 1024, so the output can exceed 12 bits: saturate.
    logic signed [{sw - 1}:0] shifted;
    assign shifted = acc >>> 10;

    logic signed [11:0] y_next;
    always_comb begin
        if (shifted > {sw}'sd2047)
            y_next = 12'sd2047;
        else if (shifted < -{sw}'sd2048)
            y_next = -12'sd2048;
        else
            y_next = shifted[11:0];
    end"""
    else:
        output = f"""    // sum|c| = {l1} < 1024, so |acc >>> 10| <= 2048*{l1}/1024 < 2048:
    // the result always fits 12 bits and saturation can never fire.
    logic signed [11:0] y_next;
    assign y_next = acc[{width - 1}:10];"""

    taps_text = "\n\n".join(taps)
    return f"""// {name} hand-optimized FFE: plain per-tap CSD shift-add.
// Coefficients {c} (Q1.10). Same ports, latency and reset
// behavior as the baseline. Each multiply is replaced by its canonical
// signed-digit shift-add form; no cross-tap sharing or factoring.

{_PORTS}

    logic signed [11:0] x1, x2, x3, x4;

    // Sign-extend each tap to the accumulator width ({width} bits covers
    // the worst case |acc| <= 2048*{l1} = {2048 * l1}).
{extend}

    logic signed [{width - 1}:0] t0, t1, t2, t3, t4;

{taps_text}

    logic signed [{width - 1}:0] acc;
    assign acc = t0 + t1 + t2 + t3 + t4;

{output}

{_REGISTERS.format(next="y_next")}

endmodule
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--name", required=True)
    parser.add_argument("--outdir", default="rtl/channel")
    parser.add_argument("coefficients", nargs=5, type=int)
    args = parser.parse_args()
    out = Path(args.outdir)
    out.mkdir(parents=True, exist_ok=True)
    (out / f"ffe5tap_{args.name}_baseline.sv").write_text(baseline_rtl(args.coefficients))
    (out / f"ffe5tap_{args.name}_hand.sv").write_text(hand_csd_rtl(args.coefficients, args.name))


if __name__ == "__main__":
    main()
