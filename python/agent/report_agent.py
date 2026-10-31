"""Collect every Phase 5 attempt into results/agent/summary.csv and a score-by-round figure."""
import csv
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[2]
AGENT = ROOT / "results" / "agent"


def row(name, kind, path):
    r = json.loads((path / "report.json").read_text())
    g2, g3, s = r["g2_directed"], r["g3_link"], r.get("synthesis") or {}
    return {
        "attempt": name, "kind": kind, "valid": r["valid"],
        "failed_gate": "" if r["valid"] else ("G1" if not r["g1_build"]["pass"] else "G2" if not g2["pass"] else "G3"),
        "logic_cells": s.get("logic_cells", ""), "fmax_mhz": s.get("fmax_median_mhz", ""),
        "score": round(r["score"], 3) if r.get("score") else "",
        "g2_max_err_lsb": g2["max_abs_error_lsb"], "g2_exact_mismatches": g2["exact_mismatches"],
        "ber": g3["ber"], "der": g3["der"], "bit_errors": g3["bit_errors"],
    }


def main():
    rows = [row("baseline", "start", AGENT / "arms" / "baseline"),
            row("hand_csd", "reference", AGENT / "arms" / "hand"),
            row("oneshot_exact", "single prompt, exact function", AGENT / "oneshot")]
    for c in ("control_a", "control_b"):
        rows.append(row(c, "single shot, loop prompt (control)", AGENT / c))
    for n in range(1, 9):
        rows.append(row(f"round_{n:02d}", "loop", AGENT / f"round_{n:02d}"))
    with open(AGENT / "summary.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)

    loop = [r for r in rows if r["kind"] == "loop"]
    fig, ax = plt.subplots(figsize=(7, 4))
    xs = [int(r["attempt"][-2:]) for r in loop if r["valid"]]
    ys = [r["score"] for r in loop if r["valid"]]
    ax.plot(xs, ys, "o-", label="loop round (valid)")
    for r in loop:
        if not r["valid"]:
            ax.plot([int(r["attempt"][-2:])], [1.0], "rx", ms=10, label="failed a gate")
    for name, style in (("oneshot_exact", "--"), ("hand_csd", ":")):
        sc = next(r["score"] for r in rows if r["attempt"] == name)
        ax.axhline(sc, ls=style, color="gray")
        ax.text(8.1, sc, name.replace("_", " "), va="center", fontsize=8)
    ctl = [r["score"] for r in rows if r["attempt"].startswith("control")]
    ax.plot([0.8] * len(ctl), ctl, "D", color="gray", mfc="none", label="single-shot controls (same prompt)")
    ax.set_xlabel("round"); ax.set_ylabel("score (lower is better)")
    ax.set_xlim(0.4, 9.5); ax.set_title("Phase 5 agent loop, 30 dB channel, 5 taps")
    ax.grid(alpha=.3); ax.legend(fontsize=8)
    fig.tight_layout(); fig.savefig(AGENT / "score_by_round.png", dpi=150)
    for r in rows:
        print(r["attempt"], r["valid"], r["logic_cells"], r["fmax_mhz"], r["score"], r["g2_max_err_lsb"], r["bit_errors"])


if __name__ == "__main__":
    main()
