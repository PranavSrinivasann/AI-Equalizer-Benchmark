"""Directed test vectors for reset, saturation and extreme inputs.

Writes one vector file per case to test_vectors/directed/case_<X>.txt.
Each line is:  <rst_n> <x_in> <expected_y_out> <group>

The testbench drives rst_n and x_in before a rising edge and compares
y_out just after it, so each line describes one clock cycle. The golden
model matches the RTL contract: synchronous active-low reset clears the
delay line and output register; otherwise y = sat12((c . x) >>> 10).
"""

from pathlib import Path
import random
import sys

projectRoot = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(projectRoot / "python"))

from coefficient_sets import coefficientSets  # noqa: E402

X_MIN, X_MAX = -2048, 2047
outputDir = projectRoot / "test_vectors" / "directed"
seed = 20261025

GROUPS = {
    1: "power-up reset",
    2: "constant extremes",
    3: "alternating extremes",
    4: "worst-case accumulation",
    5: "saturation threshold",
    6: "mid-stream reset",
    7: "reset held with active input",
    8: "PAM4 levels",
    9: "random full range",
}


class Golden:
    def __init__(self, coefficients):
        self.c = coefficients
        self.history = [0, 0, 0, 0]
        self.saturated = 0

    def step(self, rst_n, x):
        if not rst_n:
            self.history = [0, 0, 0, 0]
            return 0
        taps = [x] + self.history
        acc = sum(c * v for c, v in zip(self.c, taps))
        shifted = acc >> 10
        y = max(X_MIN, min(X_MAX, shifted))
        if y != shifted:
            self.saturated += 1
        self.history = taps[:4]
        return y


def worst_window(coefficients, sign):
    """Inputs (oldest first) that drive acc to its max (sign=+1) or min."""
    window = []
    for c in reversed(coefficients):  # c4 multiplies the oldest sample
        positive = (c > 0) == (sign > 0)
        window.append(X_MAX if positive else X_MIN)
    return window


def threshold_windows(coefficients, rng, tries=200_000):
    """Find windows whose unsaturated output lands at or just past a limit."""
    targets = {X_MAX - 1, X_MAX, X_MAX + 1, X_MAX + 2,
               X_MIN + 1, X_MIN, X_MIN - 1, X_MIN - 2}
    found = {}
    for sign in (+1, -1):
        base = worst_window(coefficients, sign)
        for _ in range(tries):
            scale = rng.uniform(0.5, 1.0)
            window = [int(max(X_MIN, min(X_MAX, round(v * scale + rng.randint(-8, 8)))))
                      for v in base]
            acc = sum(c * v for c, v in zip(coefficients, reversed(window)))
            y = acc >> 10
            if y in targets and y not in found:
                found[y] = window
            if len(found) == len(targets):
                return [found[k] for k in sorted(found)]
    return [found[k] for k in sorted(found)]


def build_stimulus(coefficients, rng):
    """List of (rst_n, x, group)."""
    stim = []

    def add(group, xs, rst_n=1):
        stim.extend((rst_n, x, group) for x in xs)

    # 1. Power-up: hold reset with nonzero input, then release.
    add(1, [X_MAX, X_MIN, 1234, -999], rst_n=0)
    add(1, [0] * 5)

    # 2. Constant extremes (fill the whole delay line each way).
    add(2, [X_MAX] * 8)
    add(2, [X_MIN] * 8)
    add(2, [0] * 5)
    add(2, [-1] * 6 + [1] * 6)

    # 3. Alternating extremes, period 2 and period 4.
    add(3, [X_MAX, X_MIN] * 8)
    add(3, [X_MAX, X_MAX, X_MIN, X_MIN] * 4)

    # 4. Worst-case positive and negative accumulation windows.
    for sign in (+1, -1):
        add(4, worst_window(coefficients, sign) * 3)
    add(4, worst_window(coefficients, +1) + worst_window(coefficients, -1))

    # 5. Windows landing on and just past the 12-bit output limits.
    for window in threshold_windows(coefficients, rng):
        add(5, window)
        add(5, [0] * 4)

    # 6. Single-cycle reset in the middle of a busy stream, several phases.
    for phase in range(5):
        add(6, [rng.randint(X_MIN, X_MAX) for _ in range(3 + phase)])
        add(6, [rng.randint(X_MIN, X_MAX)], rst_n=0)
        add(6, [rng.randint(X_MIN, X_MAX) for _ in range(6)])

    # 7. Reset held for several cycles while the input keeps changing.
    add(7, worst_window(coefficients, +1))
    add(7, [rng.choice([X_MIN, X_MAX]) for _ in range(6)], rst_n=0)
    add(7, [rng.randint(X_MIN, X_MAX) for _ in range(8)])

    # 8. PAM4 levels in Q3.8 (+-1, +-3 -> +-256, +-768).
    add(8, [rng.choice([-768, -256, 256, 768]) for _ in range(500)])

    # 9. Uniform random over the full input range.
    add(9, [rng.randint(X_MIN, X_MAX) for _ in range(5000)])
    return stim


def main():
    outputDir.mkdir(parents=True, exist_ok=True)
    for case, coefficients in coefficientSets.items():
        rng = random.Random(seed)
        golden = Golden(coefficients)
        stim = build_stimulus(coefficients, rng)
        lines = []
        for rst_n, x, group in stim:
            y = golden.step(rst_n, x)
            lines.append(f"{rst_n} {x} {y} {group}\n")
        path = outputDir / f"case_{case}.txt"
        path.write_text("".join(lines))
        resets = sum(1 for r, _, _ in stim if not r)
        print(f"Case {case}: {len(stim)} cycles, {resets} reset cycles, "
              f"{golden.saturated} saturating outputs -> {path.relative_to(projectRoot)}")


if __name__ == "__main__":
    main()
