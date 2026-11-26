"""Margin-guided per-tap bit widths for the 5-tap PAM4 FFE.

Design knobs (all other structure is the hand-CSD direct form of ffe_gen):
  W        sample bits at the input and output (Q3.(W-4))
  F        common accumulator fraction; output = acc[W-1+F : F]
  f[k]     fractional bits of tap k's coefficient (tap value rounded to f[k] bits,
           then scaled to F so the CSD digit count falls with f[k])
  t[k]     LSBs dropped from the sample that tap k sees (t[0] = 0, non-decreasing);
           the delay-line register for tap k is only W - t[k] bits wide
  b        constant added to the accumulator; floor truncation biases the output
           low, which uses up margin, and b centres it again

Margin guidance: PAM4 decisions have a margin of 1 symbol unit between a level and
its threshold. The residual error at the slicer (equalizer output / gain - sent
symbol) has mean mu and std sigma, so the margin left is z = (1 - |mu|) / sigma and
the symbol error rate is about 0.75 (Q(z+) + Q(z-)). Bits are removed one at a time,
always where the most hardware is saved per unit of margin used up.
"""

import math
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from scipy.special import erfc

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(ROOT / "python"), str(ROOT / "python" / "dj"), str(ROOT / "python" / "rtl_gen")]

from channel.link import PAM4_LEVELS  # noqa: E402
from dj.ffe_design import TX_NOISE_VAR  # noqa: E402
from ffe_rtl import csd_digits  # noqa: E402
import sweep  # noqa: E402

FLOAT_BER_30DB_5TAP = 7.985e-6   # measured in Phase 4 (5 seeds x 20M symbols)


def qfunc(x):
    return 0.5 * erfc(x / math.sqrt(2))


@dataclass
class Design:
    W: int
    F: int
    f: list
    t: list
    c_float: list = field(repr=False, default=None)
    b: int = 0

    def normalized(self):
        t, run = [0], 0
        for v in self.t[1:]:
            run = max(run, v)
            t.append(run)
        return Design(self.W, self.F, list(self.f), t, self.c_float, self.b)

    @property
    def q(self):
        return [int(round(c * 2 ** fk)) * 2 ** (self.F - fk) for c, fk in zip(self.c_float, self.f)]

    def key(self):
        return (self.W, self.F, tuple(self.f), tuple(self.normalized().t), self.b)

    def label(self):
        fs = "".join(str(v) if v < 10 else "a" for v in self.f)
        return f"W{self.W}_F{self.F}_f{fs}_t{''.join(map(str, self.t))}_b{self.b}"


def from_label(label, c_float):
    """Inverse of Design.label()."""
    w, fpart, fs, ts, bs = label.split("_")
    return Design(int(w[1:]), int(fpart[1:]), [10 if ch == "a" else int(ch) for ch in fs[1:]],
                  [int(ch) for ch in ts[1:]], c_float, int(bs[1:]))


def model(codes, d: Design):
    """Bit-exact fixed-point model of the generated RTL (one output per input)."""
    q, t = d.q, d.t
    acc = np.zeros(len(codes), dtype=np.int64)
    for k in range(len(q)):
        xs = (codes >> t[k]) << t[k]
        if k:
            acc[k:] += q[k] * xs[:-k]
        else:
            acc += q[0] * xs
    acc += d.b
    lim = 2 ** (d.W - 1)
    return np.clip(acc >> d.F, -lim, lim - 1)


def csd_cost(d: Design):
    """Rough logic-cell proxy: adder bit-slices of the CSD terms plus flip-flops."""
    q = d.q
    l1 = sum(abs(v) for v in q)
    width = int(2 ** (d.W - 1) * max(l1, 1) + abs(d.b)).bit_length() + 1
    bits, terms = (width if d.b else 0), 0
    for k, v in enumerate(q):
        for _, s in csd_digits(abs(v)):
            bits += max(width - d.t[k] - s, 0)
            terms += 1
    dffs = d.W + sum(d.W - d.t[k] for k in range(1, len(q)))
    return bits + dffs, terms


def rtl(d: Design, name="margin-guided FFE"):
    d = d.normalized()
    q, n, W, F = d.q, len(d.q), d.W, d.F
    l1 = sum(abs(v) for v in q)
    sat = l1 >= 2 ** F
    width = int(2 ** (W - 1) * max(l1, 1) + abs(d.b)).bit_length() + 1
    names = ["x_in"] + [f"x{i}" for i in range(1, n)]
    decl = "\n".join(f"    logic signed [{W - d.t[i] - 1}:0] x{i};" for i in range(1, n))
    ext = "\n".join(f"    logic signed [{width - 1}:0] xe{i}; assign xe{i} = {names[i]} <<< {d.t[i]};"
                    if d.t[i] else f"    logic signed [{width - 1}:0] xe{i}; assign xe{i} = {names[i]};"
                    for i in range(n))
    body = []
    for i, v in enumerate(q):
        digits = csd_digits(abs(v))
        sign = 1 if v >= 0 else -1
        if not digits:
            body.append(f"    // tap {i}: 0\n    assign tt{i} = '0;")
            continue
        terms = []
        for dd, k in digits:
            op = "+" if dd * sign > 0 else "-"
            terms.append(f"{op} (xe{i} <<< {k})" if k else f"{op} xe{i}")
        expr = " ".join(terms)
        expr = expr[2:] if expr.startswith("+ ") else expr
        body.append(f"    // tap {i}: {v} (f={d.f[i]}, drop {d.t[i]} LSBs)\n    assign tt{i} = {expr};")
    tlist = ", ".join(f"tt{i}" for i in range(n))
    acc = " + ".join(f"tt{i}" for i in range(n))
    if d.b:
        acc += f" + {width}'sd{d.b}" if d.b > 0 else f" - {width}'sd{-d.b}"
    if sat:
        sw = width - F
        out = f"""    logic signed [{sw - 1}:0] shifted;
    assign shifted = acc >>> {F};
    logic signed [{W - 1}:0] y_next;
    always_comb begin
        if (shifted > {sw}'sd{2 ** (W - 1) - 1})
            y_next = {W}'sd{2 ** (W - 1) - 1};
        else if (shifted < -{sw}'sd{2 ** (W - 1)})
            y_next = -{W}'sd{2 ** (W - 1)};
        else
            y_next = shifted[{W - 1}:0];
    end"""
    else:
        out = f"""    logic signed [{W - 1}:0] y_next;
    assign y_next = acc[{W - 1 + F}:{F}];"""
    clears = "\n".join(f"            x{i} <= '0;" for i in range(1, n))
    shifts = []
    for i in range(1, n):
        src = names[i - 1]
        sh = d.t[i] - d.t[i - 1]
        shifts.append(f"            x{i} <= {src} >>> {sh};" if sh else f"            x{i} <= {src};")
    return f"""// {name}: W={W}, F={F}, coefficient bits f={d.f}, dropped sample LSBs t={d.t}
// Coefficients (at F) {q}, accumulator offset {d.b}.
module ffe_pam4 (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [{W - 1}:0] x_in,
    output logic signed [{W - 1}:0] y_out
);

{decl}
{ext}
    logic signed [{width - 1}:0] {tlist};

{chr(10).join(body)}

    logic signed [{width - 1}:0] acc;
    assign acc = {acc};

{out}

    always_ff @(posedge clk) begin
        if (!rst_n) begin
{clears}
            y_out <= '0;
        end else begin
{chr(10).join(shifts)}
            y_out <= y_next;
        end
    end
endmodule
"""


class Sample:
    """A fixed received-sample stream for fast margin predictions (not the BER runs)."""

    def __init__(self, level="loss30", taps=5, symbols=2_000_000, seed=777, float_ber=None):
        pulses, th, _ = sweep.load_front_end(level)
        e = sweep.designs_for(pulses, th)[taps]
        self.c_float = [float(v) for v in e["float"]]
        self.og, self.delay = e["output_gain"], e["delay"]
        self.float_ber = float_ber
        rng = np.random.default_rng(seed)
        hv = pulses["victim"]
        history = len(hv) + max(sweep.TAPS)
        m = symbols + history
        s = rng.choice(PAM4_LEVELS, size=m)
        r = np.convolve(s + rng.normal(0.0, np.sqrt(TX_NOISE_VAR), m), hv, "valid")
        for _, ha in pulses["aggressors"]:
            r += np.convolve(rng.choice(PAM4_LEVELS, size=m).astype(float), ha, "valid")
        r += rng.normal(0.0, np.sqrt(th), len(r))
        self.x = r * e["input_gain"]
        j = np.arange(max(sweep.TAPS) - 1, len(self.x))
        self.sent = s[j + len(hv) - 1 - self.delay]
        self.j = j
        self._codes = {}
        self._yf = np.convolve(self.x, self.c_float)[: len(self.x)][self.j] / self.og
        self._sigma0 = None

    def codes(self, W):
        if W not in self._codes:
            lim = 2 ** (W - 1)
            self._codes[W] = np.clip(np.round(self.x * 2 ** (W - 4)), -lim, lim - 1).astype(np.int64)
        return self._codes[W]

    def sigma0(self):
        """Effective Gaussian sigma of the float design.

        Its residual is not Gaussian, so the sample std over-predicts the tails.
        When the measured float error rate is known (30 dB: 7.985e-6), the std that
        reproduces it is used; otherwise the sample std (conservative).
        """
        if self._sigma0 is None:
            if self.float_ber:
                from scipy.optimize import brentq
                self._sigma0 = 1 / brentq(lambda z: 1.5 * qfunc(z) - 2 * self.float_ber, 2, 9)
            else:
                self._sigma0 = float((self._yf - self.sent).std())
        return self._sigma0

    def margin(self, d: Design, recenter=True):
        """Margin metrics for design d; with recenter the accumulator offset is set so
        the output has zero mean error. Returns (design_with_offset, metrics)."""
        yf = self._yf
        codes = self.codes(d.W)
        scale = 2 ** (d.W - 4) * self.og
        d = Design(d.W, d.F, list(d.f), list(d.t), d.c_float, 0)
        y = model(codes, d)[self.j] / scale
        if recenter:
            mu0 = float((y - yf).mean())
            b = int(round(-mu0 * scale * 2 ** d.F))
            if b:
                d = Design(d.W, d.F, list(d.f), list(d.t), d.c_float, b)
                y = model(codes, d)[self.j] / scale
        dd = y - yf
        mu, sd = float(dd.mean()), float(np.sqrt(self.sigma0() ** 2 + dd.var()))
        zp, zm = (1 - mu) / sd, (1 + mu) / sd
        ser = 0.75 * (qfunc(zp) + qfunc(zm))
        return d, {"mu": mu, "sigma": sd, "z": min(zp, zm), "ser": ser, "ber": ser / 2, "b": d.b}


def start(sample, W, F):
    return Design(W, F, [F] * 5, [0] * 5, sample.c_float)


def moves(d: Design):
    out = []
    for k in range(5):
        if d.f[k] > 2:
            f = list(d.f)
            f[k] -= 1
            out.append(Design(d.W, d.F, f, list(d.t), d.c_float).normalized())
    for k in range(1, 5):
        if d.t[k] < d.W - 3:
            t = list(d.t)
            t[k] += 1
            out.append(Design(d.W, d.F, list(d.f), t, d.c_float).normalized())
    seen, uniq = set(), []
    for m in out:
        if m.key() != d.key() and m.key() not in seen:
            seen.add(m.key())
            uniq.append(m)
    return uniq


def greedy_path(sample, W, F, stop_ser=3e-4, recenter=True):
    """Remove bits where hardware saved per unit of margin used is largest."""
    d, m = sample.margin(start(sample, W, F), recenter)
    path = [(d, m, csd_cost(d)[0])]
    while m["ser"] < stop_ser:
        best = None
        for c in moves(d):
            c, mc = sample.margin(c, recenter)
            saved = csd_cost(d)[0] - csd_cost(c)[0]
            used = max(m["z"] - mc["z"], 1e-6)
            score = saved / used
            if saved > 0 and (best is None or score > best[0]):
                best = (score, c, mc)
        if best is None:
            break
        _, d, m = best
        path.append((d, m, csd_cost(d)[0]))
    return path
