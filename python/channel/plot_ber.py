"""Plot BER vs SNR for each channel: floating point, fixed point and RTL.

Reads results/channel/<channel>/ber.csv and writes
results/channel/ber_vs_snr.png (one panel per channel, shared log axis).
"""

import csv
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "results" / "channel"

SURFACE = "#fcfcfb"
INK = "#2b2b29"
MUTED = "#6b6a63"
GRID = "#e4e3dd"
SERIES = [  # label, column, color, marker, linestyle
    ("Floating point", "ber_float", "#2a78d6", "o", "-"),
    ("Fixed point (Q3.8 / Q1.10)", "ber_fixed", "#eb6834", "s", "--"),
    ("RTL in Verilator", "ber_rtl_baseline", "#1baf7a", "^", "none"),
]


def load(name):
    with (RESULTS / name / "ber.csv").open() as f:
        return list(csv.DictReader(f))


def main():
    names = [p.name for p in sorted(RESULTS.iterdir()) if (p / "ber.csv").exists()]
    order = [n for n in ("notebook", "short_reach", "pre_post", "long_tail") if n in names]
    order += [n for n in names if n not in order]

    cols = 2
    rows = (len(order) + 1) // 2
    plt.rcParams.update({"font.size": 10, "axes.edgecolor": MUTED, "axes.labelcolor": INK,
                         "xtick.color": MUTED, "ytick.color": MUTED, "text.color": INK})
    fig, axes = plt.subplots(rows, cols, figsize=(10, 3.6 * rows), sharex=True, sharey=True,
                             facecolor=SURFACE, squeeze=False)
    floor = 1.0
    for ax, name in zip(axes.flat, order):
        data = load(name)
        info = json.loads((RESULTS / name / "coefficients.json").read_text())
        snr = [float(r["snr_db"]) for r in data]
        bits = int(data[0]["bits"])
        floor = min(floor, 0.5 / bits)
        ax.set_facecolor(SURFACE)
        for label, column, color, marker, style in SERIES:
            # Points with zero errors cannot sit on a log axis; they are left out.
            pts = [(s, float(r[column])) for s, r in zip(snr, data) if float(r[column]) > 0]
            if not pts:
                continue
            ax.plot([p[0] for p in pts], [p[1] for p in pts], color=color, marker=marker,
                    markersize=8 if marker == "^" else 6, linewidth=2, linestyle=style,
                    markeredgecolor=SURFACE if marker != "^" else color,
                    markerfacecolor=color if marker != "^" else "none",
                    markeredgewidth=1.5, label=label, zorder=3 if marker == "^" else 2)
        ax.set_yscale("log")
        ax.grid(True, which="major", color=GRID, linewidth=0.8)
        ax.set_axisbelow(True)
        for side in ("top", "right"):
            ax.spines[side].set_visible(False)
        taps = ", ".join(f"{v:g}" for v in info["channel"])
        ax.set_title(f"{name}  [{taps}]", fontsize=10, loc="left", color=INK)
    for ax in axes.flat[len(order):]:
        ax.set_visible(False)
    for ax in axes[-1]:
        ax.set_xlabel("SNR (dB)")
    for ax in axes[:, 0]:
        ax.set_ylabel("Bit error rate")
    axes[0, 0].set_ylim(bottom=floor)

    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper center", ncol=3, frameon=False,
               bbox_to_anchor=(0.5, 1.0))
    fig.suptitle("5-tap FFE: BER vs SNR, same received samples through each model",
                 y=1.045, fontsize=12, color=INK)
    fig.text(0.5, -0.02, "RTL markers sit on the fixed-point curve because the RTL output "
             "matches the fixed-point model bit for bit. Points with zero errors are omitted.",
             ha="center", fontsize=9, color=MUTED)
    fig.tight_layout()
    out = RESULTS / "ber_vs_snr.png"
    fig.savefig(out, dpi=150, bbox_inches="tight", facecolor=SURFACE)
    print(f"Wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
