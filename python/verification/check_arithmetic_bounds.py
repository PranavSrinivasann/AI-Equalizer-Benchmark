"""Arithmetic bound and identity checks for the 5-tap FFE designs.

Part 1: output range per coefficient set.
    For 12-bit signed inputs, |acc| <= 2048 * sum(|c|), so y = acc >> 10
    can only leave the 12-bit range when sum(|c|) >= 1024. This shows,
    for each case, whether the saturation logic can ever fire.

Part 2: exhaustive checks of the factored arithmetic in the optimized RTL.
    Each optimized design rewrites the dot product as shift-adds, some on
    partial bit slices. This script transcribes every intermediate of
    rtl/generalization/optimized/ffe5tap_case{B,C}_optimized.sv with explicit
    Verilog widths and wrap-around, and checks it against exact integer
    arithmetic over every input value each intermediate can see.

This checks the arithmetic as transcribed here, not the RTL source itself.
The RTL is checked directly by the equivalence proofs in formal/ and by the
directed simulations in testbench/directed/.
"""

from pathlib import Path
import sys

import numpy as np

projectRoot = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(projectRoot / "python"))

from coefficient_sets import coefficientSets  # noqa: E402

X_MIN, X_MAX = -2048, 2047
failures = 0


def report(name, ok, detail=""):
    global failures
    status = "PASS" if ok else "FAIL"
    if not ok:
        failures += 1
    print(f"  {status}  {name}{(': ' + detail) if detail else ''}")


def wrap(value, bits):
    """Value as an unsigned bits-wide vector (Verilog truncation)."""
    return np.asarray(value, dtype=np.int64) & ((1 << bits) - 1)


def as_signed(value, bits):
    """Reinterpret a bits-wide vector as two's-complement signed."""
    value = wrap(value, bits)
    return np.where(value >= (1 << (bits - 1)), value - (1 << bits), value)


def bits_slice(value, hi, lo):
    """value[hi:lo] of a two's-complement number, as unsigned."""
    return (np.asarray(value, dtype=np.int64) >> lo) & ((1 << (hi - lo + 1)) - 1)


def concat(hi_part, lo_part, lo_bits):
    return (np.asarray(hi_part, dtype=np.int64) << lo_bits) | lo_part


def worst_case_acc(coefficients):
    """Largest and smallest exact accumulator values over 12-bit inputs."""
    hi = sum(c * (X_MAX if c > 0 else X_MIN) for c in coefficients)
    lo = sum(c * (X_MIN if c > 0 else X_MAX) for c in coefficients)
    return lo, hi


def part1():
    print("Part 1: can saturation fire?")
    for case, coefficients in coefficientSets.items():
        l1 = sum(abs(c) for c in coefficients)
        lo, hi = worst_case_acc(coefficients)
        y_lo, y_hi = lo >> 10, hi >> 10
        reachable = y_lo < X_MIN or y_hi > X_MAX
        print(
            f"  Case {case}: sum|c| = {l1:5d}, acc in [{lo}, {hi}], "
            f"y in [{y_lo}, {y_hi}] -> saturation "
            f"{'REACHABLE' if reachable else 'unreachable'}"
        )
    print()


def check_case_c():
    print("Part 2a: Case C optimized arithmetic")
    d = np.arange(-4095, 4096, dtype=np.int64)       # x_in - x4, x1 - x3
    x = np.arange(X_MIN, X_MAX + 1, dtype=np.int64)  # x2

    # a17 = {d04_18[17:4] + d04_18[13:0] (14 bits), d04_18[3:0]}
    a17_hi = wrap(bits_slice(d, 17, 4) + bits_slice(d, 13, 0), 14)
    a17 = as_signed(concat(a17_hi, bits_slice(d, 3, 0), 4), 18)
    report("a17 == 17*d04 for all d04", np.array_equal(a17, 17 * d))

    x31 = as_signed((x << 5) - x, 17)
    report("x31 == 31*x2 for all x2", np.array_equal(x31, 31 * x))

    # w = a17 + x31 (19 bits): check range and exactness over all pairs.
    w = as_signed(a17[:, None] + x31[None, :], 19)
    report("w == 17*d04 + 31*x2 for all pairs",
           np.array_equal(w, 17 * d[:, None] + 31 * x[None, :]))

    # w3 = {w_20[19:1] + w_20[18:0] (19 bits), w_20[0]} over every w value.
    w_all = np.arange(w.min(), w.max() + 1, dtype=np.int64)
    w3_hi = wrap(bits_slice(w_all, 19, 1) + bits_slice(w_all, 18, 0), 19)
    w3 = as_signed(concat(w3_hi, bits_slice(w_all, 0, 0), 1), 20)
    report("w3 == 3*w for every reachable w", np.array_equal(w3, 3 * w_all))

    # d9 = {d13_17[16:3] + d13_17[13:0] (14 bits), d13_17[2:0]}
    d9_hi = wrap(bits_slice(d, 16, 3) + bits_slice(d, 13, 0), 14)
    d9 = as_signed(concat(d9_hi, bits_slice(d, 2, 0), 3), 17)
    report("d9 == 9*d13 for all d13", np.array_equal(d9, 9 * d))

    # p137 = {d9_21[20:7] + d13_21[13:0] (14 bits), d9_21[6:0]}
    p137_hi = wrap(bits_slice(d9, 20, 7) + bits_slice(d, 13, 0), 14)
    p137 = as_signed(concat(p137_hi, bits_slice(d9, 6, 0), 7), 21)
    report("p137 == 137*d13 for all d13", np.array_equal(p137, 137 * d))

    # acc = w3 - p137 (21 bits): exact iff the true value fits in 21 bits.
    lo = 3 * int(w.min()) - 137 * 4095
    hi = 3 * int(w.max()) + 137 * 4095
    report("acc fits 21 bits", -(1 << 20) <= lo and hi < (1 << 20),
           f"range [{lo}, {hi}]")
    report("acc[20:10] fits 11 bits",
           -(1 << 10) <= (lo >> 10) and (hi >> 10) < (1 << 10),
           f"y in [{lo >> 10}, {hi >> 10}]")
    print()


def check_case_b():
    print("Part 2b: Case B optimized arithmetic")
    c = coefficientSets["B"]
    # Identity: acc = 73*S + 16*x2 + 7*B - 64*T
    #   S = x0 + x2 + 2*x3, B = x1 + x4, T = 2*x1 + x4
    rng = np.random.default_rng(1)
    xs = rng.integers(X_MIN, X_MAX + 1, size=(200_000, 5))
    corners = np.array(np.meshgrid(*[[X_MIN, -1, 0, X_MAX]] * 5)).T.reshape(-1, 5)
    xs = np.vstack([xs, corners])
    x0, x1, x2, x3, x4 = xs.T
    exact = c[0] * x0 + c[1] * x1 + c[2] * x2 + c[3] * x3 + c[4] * x4

    s = as_signed(x0 + x2 + (x3 << 1), 14)
    b = as_signed(x1 + x4, 13)
    t = as_signed((x1 << 1) + x4, 14)
    s9 = as_signed((s << 3) + s, 21)
    s73 = as_signed((s << 6) + s9, 21)
    b7 = as_signed((b << 3) - b, 21)
    r0 = as_signed((x2 << 4) - (t << 6), 21)
    r1 = as_signed(b7 + r0, 21)
    acc = as_signed(s73 + r1, 21)
    report("factored acc == dot product (random + all corner inputs)",
           np.array_equal(acc, exact))

    # The identity is linear, so also check it symbolically on unit vectors.
    unit_ok = True
    for k in range(5):
        e = [0] * 5
        e[k] = 1
        S, B, T = e[0] + e[2] + 2 * e[3], e[1] + e[4], 2 * e[1] + e[4]
        unit_ok &= (73 * S + 16 * e[2] + 7 * B - 64 * T) == c[k]
    report("factored form reproduces every coefficient", unit_ok)

    for name, lo, hi, bits in (
        ("S", -2048 * 4, 2047 * 4, 14),
        ("B", -4096, 4094, 13),
        ("T", -2048 * 3, 2047 * 3, 14),
    ):
        report(f"{name} fits {bits} bits",
               -(1 << (bits - 1)) <= lo and hi < (1 << (bits - 1)))
    lo, hi = worst_case_acc(c)
    report("acc fits 21 bits", -(1 << 20) <= lo and hi < (1 << 20),
           f"range [{lo}, {hi}]")
    print()


def main():
    part1()
    check_case_c()
    check_case_b()
    print("RESULT:", "PASS" if failures == 0 else f"FAIL ({failures} checks)")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
