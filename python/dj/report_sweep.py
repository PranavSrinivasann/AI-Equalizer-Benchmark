"""Aggregate the Phase 4 sweeps into tables and figures (results/sweep/)."""

import csv
import collections
import sys
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "results" / "sweep"
LEVELS = ["loss20", "loss30", "loss40"]
LABEL = {"loss20": "~20 dB", "loss30": "~30 dB", "loss40": "~40 dB"}
PRIMARY, STRETCH = 2e-4, 1e-6
COLORS = {"float": "#52514e", "P12": "#2a78d6", "P10": "#eb6834", "P8": "#1baf7a"}
INK, INK2, GRID = "#0b0b0b", "#52514e", "#e4e3df"


def verdict(errors, trials, target):
    rate = errors / trials
    upper = 3.0 / trials if errors == 0 else (errors + 1.96 * np.sqrt(errors) + 1) / trials
    if rate > target:
        return "FAIL"
    return "PASS" if upper <= target else "NOT RESOLVED"


def style(ax):
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(INK2)
    ax.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(colors=INK2)


def ber_table():
    rows = []
    for level in LEVELS:
        agg = collections.defaultdict(lambda: {"be": 0, "se": 0, "sym": 0, "seeds": [], "clip": 0})
        for r in csv.DictReader(open(OUT / f"ber_{level}.csv")):
            a = agg[(int(r["taps"]), r["precision"])]
            a["be"] += int(r["bit_errors"]); a["se"] += int(r["symbol_errors"])
            a["sym"] += int(r["symbols"]); a["clip"] += int(r["clipped"])
            a["seeds"].append(int(r["bit_errors"]) / (2 * int(r["symbols"])))
        for (taps, prec), a in sorted(agg.items(), key=lambda kv: (kv[0][0], kv[0][1])):
            bits = 2 * a["sym"]
            rows.append({"level": level, "taps": taps, "precision": prec, "symbols": a["sym"],
                         "bit_errors": a["be"], "symbol_errors": a["se"],
                         "ber": a["be"] / bits, "der": a["se"] / a["sym"],
                         "ber_seed_min": min(a["seeds"]), "ber_seed_max": max(a["seeds"]),
                         "ber_primary": verdict(a["be"], bits, PRIMARY),
                         "der_primary": verdict(a["se"], a["sym"], PRIMARY),
                         "ber_stretch": verdict(a["be"], bits, STRETCH),
                         "samples_clipped": a["clip"]})
    return rows


def dfe_table():
    rows = []
    for level in ("loss30", "loss40"):
        agg = collections.defaultdict(lambda: [0, 0, 0, 0.0])
        for r in csv.DictReader(open(OUT / f"dfe_{level}.csv")):
            a = agg[(int(r["ff_taps"]), int(r["fb_taps"]))]
            a[0] += int(r["bit_errors"]); a[1] += int(r["symbol_errors"]); a[2] += int(r["symbols"])
            a[3] = float(r["gaussian_ber"])
        for (ff, fb), (be, se, sym, g) in sorted(agg.items()):
            rows.append({"level": level, "ff_taps": ff, "fb_taps": fb, "symbols": sym,
                         "bit_errors": be, "symbol_errors": se, "ber": be / (2 * sym), "der": se / sym,
                         "gaussian_ber": g, "ber_primary": verdict(be, 2 * sym, PRIMARY),
                         "der_primary": verdict(se, sym, PRIMARY),
                         "ber_stretch": verdict(be, 2 * sym, STRETCH)})
    return rows


def write(path, rows):
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def plot_ber(rows):
    fig, axes = plt.subplots(1, 3, figsize=(12, 3.8), sharey=True)
    for ax, level in zip(axes, LEVELS):
        for prec in ("float", "P12", "P10", "P8"):
            pts = sorted((r["taps"], r) for r in rows if r["level"] == level and r["precision"] == prec)
            x = [t for t, _ in pts]
            floor = [3.0 / (2 * r["symbols"]) for _, r in pts]
            y = [max(r["ber"], f) for (_, r), f in zip(pts, floor)]
            ax.plot(x, y, color=COLORS[prec], linewidth=2, marker="o", markersize=5,
                    label="float" if prec == "float" else prec,
                    linestyle="--" if prec == "float" else "-")
            zero = [(a, b) for a, b, (_, r) in zip(x, y, pts) if r["bit_errors"] == 0]
            if zero:
                ax.scatter(*zip(*zero), s=60, facecolors="none", edgecolors=COLORS[prec], zorder=3)
        ax.axhline(PRIMARY, color=INK2, linewidth=1, linestyle=":")
        ax.axhline(STRETCH, color=INK2, linewidth=1, linestyle=":")
        ax.set_yscale("log")
        ax.set_xscale("log", base=2)
        ax.set_xticks([5, 8, 12, 16, 24, 32, 48])
        ax.set_xticklabels(["5", "8", "12", "16", "24", "32", "48"])
        ax.set_xlabel("FFE taps", color=INK2)
        ax.set_title(LABEL[level], loc="left", color=INK, fontsize=11)
        style(ax)
    axes[0].set_ylabel("BER (open marker: no errors, 95% bound)", color=INK2)
    axes[0].text(5.1, PRIMARY * 1.3, "2e-4", color=INK2, fontsize=8)
    axes[0].text(5.1, STRETCH * 1.3, "1e-6", color=INK2, fontsize=8)
    axes[2].legend(frameon=False, fontsize=9, loc="lower left")
    fig.suptitle("BER versus FFE taps and precision", x=0.01, ha="left", color=INK, fontsize=12)
    fig.tight_layout()
    fig.savefig(OUT / "ber_vs_taps.png", dpi=160)
    plt.close(fig)


def plot_dfe(rows):
    fig, axes = plt.subplots(1, 2, figsize=(10, 3.9))
    for ax, level in zip(axes, ("loss30", "loss40")):
        ffs = sorted({r["ff_taps"] for r in rows})
        fbs = sorted({r["fb_taps"] for r in rows})
        grid = np.zeros((len(ffs), len(fbs)))
        for r in rows:
            if r["level"] == level:
                grid[ffs.index(r["ff_taps"]), fbs.index(r["fb_taps"])] = max(r["ber"], 3.0 / (2 * r["symbols"]))
        im = ax.imshow(np.log10(grid), cmap="Blues_r", aspect="auto", origin="lower")
        ax.set_xticks(range(len(fbs)), [str(v) for v in fbs])
        ax.set_yticks(range(len(ffs)), [str(v) for v in ffs])
        for i in range(len(ffs)):
            for j in range(len(fbs)):
                zero = grid[i, j] <= 3.0 / (2 * 5_000_000 * 5) * 1.0001
                ax.text(j, i, "0" if zero else f"{grid[i, j]:.0e}".replace("e-0", "e-"),
                        ha="center", va="center", fontsize=7,
                        color="white" if np.log10(grid[i, j]) < -6.2 else INK)
        ax.set_xlabel("Feedback taps", color=INK2)
        ax.set_ylabel("Feed-forward taps", color=INK2)
        ax.set_title(f"{LABEL[level]}: BER, floating-point DFE", loc="left", color=INK, fontsize=10)
        ax.tick_params(colors=INK2)
    fig.tight_layout()
    fig.savefig(OUT / "dfe_ber_grid.png", dpi=160)
    plt.close(fig)


def hardware(ber_rows):
    hw = []
    for level in LEVELS:
        p = OUT / f"hw_{level}.csv"
        if p.exists():
            hw += list(csv.DictReader(open(p)))
    lookup = {(r["level"], r["taps"], r["precision"]): r for r in ber_rows}
    merged = []
    for h in hw:
        b = lookup[(h["level"], int(h["taps"]), h["precision"])]
        merged.append({**{k: h.get(k, "") for k in ("level", "taps", "precision", "sum_abs_coef", "rtl_check",
                                                    "lut4", "logic_cells", "fits_up5k", "fmax_median_mhz",
                                                    "fmax_min_mhz", "fmax_max_mhz", "ecp5_lut4",
                                                    "ecp5_fmax_median_mhz")},
                       "ber": b["ber"], "der": b["der"], "ber_primary": b["ber_primary"],
                       "der_primary": b["der_primary"], "ber_stretch": b["ber_stretch"]})
    return merged


def plot_tradeoff(merged):
    rows = [m for m in merged if m["level"] == "loss30" and m["logic_cells"]]
    if not rows:
        return
    fig, ax = plt.subplots(figsize=(6.8, 4.2))
    for prec in ("P12", "P10", "P8"):
        pts = sorted((int(m["taps"]), int(m["logic_cells"]), float(m["ber"])) for m in rows if m["precision"] == prec)
        ax.plot([p[1] for p in pts], [max(p[2], 1e-9) for p in pts], color=COLORS[prec], marker="o",
                linewidth=2, label=prec)
        for t, lc, b in [p for p in pts if p[0] in (5, 8, 12, 24, 48)]:
            ax.annotate(str(t), (lc, max(b, 1e-9)), textcoords="offset points", xytext=(4, 4),
                        fontsize=7, color=INK2)
    ax.axhline(PRIMARY, color=INK2, linestyle=":", linewidth=1)
    ax.axhline(STRETCH, color=INK2, linestyle=":", linewidth=1)
    ax.set_yscale("log")
    ax.set_xlabel("iCE40 UP5K logic cells (hand CSD, direct form)", color=INK2)
    ax.set_ylabel("BER (floor 1e-9 = no errors seen)", color=INK2)
    ax.set_title("~30 dB channel: area versus BER (labels = taps)", loc="left", color=INK, fontsize=11)
    style(ax)
    ax.legend(frameon=False, fontsize=9)
    fig.tight_layout()
    fig.savefig(OUT / "area_vs_ber_loss30.png", dpi=160)
    plt.close(fig)


def main():
    ber = ber_table()
    write(OUT / "ber_summary.csv", ber)
    dfe = dfe_table()
    write(OUT / "dfe_summary.csv", dfe)
    plot_ber(ber)
    plot_dfe(dfe)
    merged = hardware(ber)
    if merged:
        write(OUT / "tradeoff.csv", merged)
        plot_tradeoff(merged)
    print("wrote", sorted(p.name for p in OUT.glob("*") if p.is_file() and p.suffix in (".csv", ".png")))


if __name__ == "__main__":
    main()
