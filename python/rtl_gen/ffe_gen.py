"""Generators for fixed-coefficient N-tap PAM4 FFEs with configurable precision.

Both generators emit module `ffe_pam4` (clk, rst_n, signed x_in/y_out of
`in_bits` bits), direct form, synchronous active-low reset, 1-cycle latency.
Samples are Q3.(in_bits-4); coefficients are Q1.coef_frac
(coef_frac + 2 bits); y = sat(sum(c[k] * x[n-k]) >>> coef_frac).

baseline_rtl(): one generic multiply per tap, a wide accumulator and
    comparator saturation (same structure as the 5-tap baseline).
hand_csd_rtl(): per-tap canonical-signed-digit shift-add, accumulator sized
    to the worst-case bound, saturation only when it is reachable.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ffe_rtl import csd_digits  # noqa: E402


def check(coefficients, in_bits, coef_frac):
    c = [int(v) for v in coefficients]
    lo, hi = -(2 ** (coef_frac + 1)), 2 ** (coef_frac + 1) - 1
    if not c or any(not lo <= v <= hi for v in c):
        raise ValueError(f"coefficients must fit Q1.{coef_frac}: [{lo}, {hi}]")
    if in_bits < 6:
        raise ValueError("in_bits too small")
    return c


def saturation_reachable(coefficients, coef_frac):
    return sum(abs(int(v)) for v in coefficients) >= 2 ** coef_frac


def _lit(value, bits):
    return f"{bits}'sd{value}" if value >= 0 else f"-{bits}'sd{-value}"


def _ports(w):
    return f"""module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [{w - 1}:0] x_in,
    output logic signed [{w - 1}:0] y_out
);"""


def _registers(n, w, nxt):
    names = [f"x{i}" for i in range(1, n)]
    clears = "\n".join(f"            {x} <= {w}'sd0;" for x in names)
    shifts = "\n".join(
        f"            {names[i]} <= {names[i - 1] if i else 'x_in'};" for i in range(len(names)))
    return f"""    always_ff @(posedge clk) begin
        if (!rst_n) begin
{clears}
            y_out <= {w}'sd0;
        end else begin
{shifts}
            y_out <= {nxt};
        end
    end"""


def _delay_decl(n, w):
    return f"    logic signed [{w - 1}:0] " + ", ".join(f"x{i}" for i in range(1, n)) + ";" if n > 1 else ""


def baseline_rtl(coefficients, in_bits=12, coef_frac=10, header=""):
    c = check(coefficients, in_bits, coef_frac)
    n, w = len(c), in_bits
    cw = coef_frac + 2
    pw = w + cw
    aw = pw + max(1, math.ceil(math.log2(n)))
    taps = ["x_in"] + [f"x{i}" for i in range(1, n)]
    prefix = "".join(f"// {l}\n" for l in header.splitlines())
    params = "\n".join(f"    localparam signed [{cw - 1}:0] C{i} = {_lit(v, cw)};" for i, v in enumerate(c))
    prods = "\n".join(f"    assign p{i} = {t} * C{i};" for i, t in enumerate(taps))
    exts = "\n".join(f"    assign e{i} = p{i};" for i in range(n))
    plist = ", ".join(f"p{i}" for i in range(n))
    elist = ", ".join(f"e{i}" for i in range(n))
    acc = " + ".join(f"e{i}" for i in range(n))
    return f"""{prefix}{_ports(w)}

{params}

{_delay_decl(n, w)}
    logic signed [{pw - 1}:0] {plist};
    logic signed [{aw - 1}:0] {elist};

{prods}
{exts}

    logic signed [{aw - 1}:0] acc, shifted;
    assign acc = {acc};
    assign shifted = acc >>> {coef_frac};

    localparam signed [{aw - 1}:0] MAX_Y = {aw}'sd{2 ** (w - 1) - 1};
    localparam signed [{aw - 1}:0] MIN_Y = -{aw}'sd{2 ** (w - 1)};

    logic signed [{w - 1}:0] y_sat;
    always_comb begin
        if (shifted > MAX_Y)
            y_sat = {w}'sd{2 ** (w - 1) - 1};
        else if (shifted < MIN_Y)
            y_sat = -{w}'sd{2 ** (w - 1)};
        else
            y_sat = shifted[{w - 1}:0];
    end

{_registers(n, w, "y_sat")}
endmodule
"""


def hand_csd_rtl(coefficients, in_bits=12, coef_frac=10, name="FFE"):
    c = check(coefficients, in_bits, coef_frac)
    n, w = len(c), in_bits
    l1 = sum(abs(v) for v in c)
    sat = l1 >= 2 ** coef_frac
    width = int(2 ** (w - 1) * max(l1, 1)).bit_length() + 1
    taps = ["x_in"] + [f"x{i}" for i in range(1, n)]
    ext = "\n".join(f"    logic signed [{width - 1}:0] xe{i}; assign xe{i} = {t};" for i, t in enumerate(taps))
    body = []
    for i, v in enumerate(c):
        digits = csd_digits(abs(v))
        sign = 1 if v >= 0 else -1
        if not digits:
            body.append(f"    // tap {i}: 0\n    assign t{i} = '0;")
            continue
        terms = []
        for d, k in digits:
            op = "+" if d * sign > 0 else "-"
            terms.append(f"{op} (xe{i} <<< {k})" if k else f"{op} xe{i}")
        expr = " ".join(terms)
        if expr.startswith("+ "):
            expr = expr[2:]
        body.append(f"    // tap {i}: {v}\n    assign t{i} = {expr};")
    tlist = ", ".join(f"t{i}" for i in range(n))
    acc = " + ".join(f"t{i}" for i in range(n))
    if sat:
        sw = width - coef_frac
        out = f"""    logic signed [{sw - 1}:0] shifted;
    assign shifted = acc >>> {coef_frac};
    logic signed [{w - 1}:0] y_next;
    always_comb begin
        if (shifted > {sw}'sd{2 ** (w - 1) - 1})
            y_next = {w}'sd{2 ** (w - 1) - 1};
        else if (shifted < -{sw}'sd{2 ** (w - 1)})
            y_next = -{w}'sd{2 ** (w - 1)};
        else
            y_next = shifted[{w - 1}:0];
    end"""
    else:
        out = f"""    // sum|c| = {l1} < {2 ** coef_frac}: the result always fits, saturation cannot fire.
    logic signed [{w - 1}:0] y_next;
    assign y_next = acc[{w - 1 + coef_frac}:{coef_frac}];"""
    return f"""// {name}: {n}-tap FFE, per-tap CSD shift-add, Q3.{w - 4} samples, Q1.{coef_frac} coefficients.
// Coefficients {c}.
{_ports(w)}

{_delay_decl(n, w)}
{ext}
    logic signed [{width - 1}:0] {tlist};

{chr(10).join(body)}

    logic signed [{width - 1}:0] acc;
    assign acc = {acc};

{out}

{_registers(n, w, "y_next")}
endmodule
"""
