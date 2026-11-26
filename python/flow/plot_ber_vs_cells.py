"""BER versus logic cells for the Phase 7 designs (one channel).

Reads results/phase7/uniform_<level>_t<taps>.csv (uniform bit-width sweep) and,
when present, results/phase7/margin_<level>_t<taps>.csv (margin-guided designs).
The hand-CSD reference is the P12 design (width 12) from the uniform sweep.

  python3 python/flow/plot_ber_vs_cells.py --level loss30 --taps 5
"""

import argparse
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "results" / "phase7"
SURFACE, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
BLUE, ORANGE = "#2a78d6", "#eb6834"
NUM = ("ber", "der", "logic_cells", "width", "ber_float")


def read(path):
    with path.open() as f:
        return [{k: (float(v) if k in NUM else v) for k, v in r.items()} for r in csv.DictReader(f)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", default="loss30")
    ap.add_argument("--taps", type=int, default=5)
    ap.add_argument("--ablation-offset", default="-100,-62", help="label offset in points, dx,dy")
    args = ap.parse_args()
    adx, ady = (float(v) for v in args.ablation_offset.split(","))
    uni = read(OUT / f"uniform_{args.level}_t{args.taps}.csv")
    mpath = OUT / f"margin_{args.level}_t{args.taps}.csv"
    margin = read(mpath) if mpath.exists() else []

    fig, ax = plt.subplots(figsize=(7.4, 4.8), dpi=200, facecolor=SURFACE)
    ax.set_facecolor(SURFACE)
    ax.set_yscale("log")
    ax.grid(True, color=GRID, lw=0.8)
    ax.set_axisbelow(True)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(INK2)
    ax.tick_params(colors=INK2)

    ref_ber = uni[0]["ber_float"]
    ax.axhline(1e-4, color=INK2, lw=1, ls="--")
    if ref_ber > 0:
        ax.axhline(ref_ber, color=INK2, lw=1, ls=":")

    x = [r["logic_cells"] for r in uni]
    pos = [r["ber"] for r in uni if r["ber"] > 0]
    floor = min(pos + [r["ber"] for r in margin if r["ber"] > 0] + [ref_ber or 1]) / 1.6
    y = [max(r["ber"], floor) for r in uni]
    ax.plot(x, y, color=BLUE, lw=2, marker="o", ms=7, mfc=BLUE, mec=SURFACE, mew=1.5,
            label="Uniform bit width (all taps the same)", zorder=3)
    for r in uni:
        w = int(r["width"])
        off, ha = {6: ((10, 2), "left"), 7: ((10, -3), "left"), 12: ((0, 16), "center")}.get(w, ((0, 9), "center"))
        ax.annotate(f"W{w}", (r["logic_cells"], max(r["ber"], floor)), textcoords="offset points",
                    xytext=off, ha=ha, fontsize=8, color=INK2)
    ref = [r for r in uni if int(r["width"]) == 12]
    if ref:
        ax.plot([ref[0]["logic_cells"]], [max(ref[0]["ber"], floor)], marker="D", ms=10, mfc="none", mec=INK,
                mew=1.8, ls="none", label="Hand CSD reference (P12)", zorder=4)
    if margin:
        ax.plot([r["logic_cells"] for r in margin], [max(r["ber"], floor) for r in margin],
                color=ORANGE, lw=2, marker="s", ms=7, mfc=ORANGE, mec=SURFACE, mew=1.5,
                label="Margin-guided bit widths (per tap)", zorder=3)
        ok = [r for r in margin if r["der"] <= 2e-4]
        if ok:
            best = min(ok, key=lambda r: r["logic_cells"])
            ax.annotate(f"{int(best['logic_cells'])} cells", (best["logic_cells"], max(best["ber"], floor)),
                        textcoords="offset points", xytext=(-8, -16), ha="right", fontsize=8.5, color=INK)

        for r in margin:       # ablation: uniform widths, only the output offset added
            parts = r["label"].split("_")
            if parts[2] == "f" + parts[1][1:] * 5 and set(parts[3][1:]) == {"0"} and int(parts[4][1:]) != 0:
                ax.annotate("uniform widths + output offset\n(only the trim, no per-tap change)",
                            (r["logic_cells"], max(r["ber"], floor)), xytext=(adx, ady),
                            textcoords="offset points", ha="left", va="center", fontsize=8, color=INK2,
                            arrowprops=dict(arrowstyle="-", color=INK2, lw=0.8))
                break

    lo = min(r["logic_cells"] for r in uni + margin)
    hi = max(r["logic_cells"] for r in uni + margin)
    pad = 0.06 * (hi - lo)
    left = max(lo - 4 * pad, 0)
    ax.set_xlim(left, hi + pad)
    ymax = max(r["ber"] for r in uni) * 4
    ax.set_ylim(floor / 1.4, max(ymax, 3e-4))
    ax.text(hi + pad - 2, 1.1e-4, "DER limit 2e-4 (DER ≈ 2 × BER, so BER ≈ 1e-4)", color=INK2,
            fontsize=8, ha="right", va="bottom")
    if ref_ber > 0:
        ax.text(left + 4, ref_ber * 0.92, "float FFE (no quantization)", color=INK2, fontsize=8,
                ha="left", va="top")
    if any(r["ber"] == 0 for r in uni + margin):
        ax.text(hi + pad - 2, floor * 25, "BER = 0 (no errors in 100M symbols)\nis drawn on the bottom edge",
                color=INK2, fontsize=8, ha="right", va="bottom")
    ax.set_xlabel("Logic cells (iCE40 UP5K, lower is smaller)", color=INK)
    ax.set_ylabel("BER", color=INK)
    ax.set_title(f"{args.taps}-tap FFE, {args.level.replace('loss', '')} dB channel: BER versus logic cells",
                 color=INK, fontsize=11, loc="left")
    leg = ax.legend(frameon=False, loc="upper right", fontsize=8.5, bbox_to_anchor=(1, 0.93))
    for t in leg.get_texts():
        t.set_color(INK)
    fig.tight_layout()
    out = OUT / f"ber_vs_cells_{args.level}_t{args.taps}.png"
    fig.savefig(out, facecolor=SURFACE)
    print(out)


if __name__ == "__main__":
    main()
