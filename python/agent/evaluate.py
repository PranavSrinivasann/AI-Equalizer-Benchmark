"""Evaluate one 5-tap FFE RTL design for the agent loop.

Gates, in order (a design must pass all to be valid):
  G1  builds in Verilator and synthesizes in Yosys
  G2  directed tests (reset, saturation, extreme inputs): every cycle with
      rst_n low outputs exactly 0, and every output is within TOL_LSB of the
      fixed-point reference
  G3  link BER and DER through the RTL on the ~30 dB channel are both <= 2e-4
Valid designs are then placed and routed on the iCE40 UP5K over three seeds.

Score (lower is better):  (LC / LC_ref) * sqrt(Fmax_ref / Fmax), with the
reference being the hand-written CSD design on the same channel.

  python3 python/agent/evaluate.py rtl/dj/ffe5tap_dj_loss30_baseline.sv --out results/agent/arms/baseline
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(ROOT / "python"), str(ROOT / "python" / "channel"), str(ROOT / "python" / "dj"),
                str(ROOT / "python" / "verification")]

import rtl_sim  # noqa: E402
from channel.equalizer import fixed_ffe  # noqa: E402
from channel.link import PAM4_LEVELS, bit_errors, decide  # noqa: E402
from dj.ffe_design import TX_NOISE_VAR, hardware_design  # noqa: E402
from sweep import load_front_end  # noqa: E402

LEVEL = "loss30"
TOL_LSB = 8
TARGET = 2e-4
BER_SEEDS = (7001, 7002)
BER_SYMBOLS = 1_000_000
PNR_SEEDS = 3
LC_REF = 571          # hand CSD, same coefficients (results/sweep/tradeoff.csv)
FMAX_REF = 24.84
DIRECTED = ROOT / "test_vectors" / "directed" / "case_dj_loss30.txt"
GROUPS = {1: "power-up reset", 2: "constant extremes", 3: "alternating extremes",
          4: "worst-case accumulation", 5: "saturation threshold", 6: "mid-stream reset",
          7: "reset held with active input", 8: "PAM4 levels", 9: "random full range"}


def coefficients():
    info = json.loads((ROOT / "results" / "dj" / "coefficient_sets.json").read_text())
    return info[LEVEL]["coefficients_q110"]


def ensure_directed_vectors():
    import random
    import generate_directed_vectors as g
    c = coefficients()
    rng = random.Random(g.seed)
    golden = g.Golden(c)
    lines = []
    for rst_n, x, group in g.build_stimulus(c, rng):
        lines.append(f"{rst_n} {x} {golden.step(rst_n, x)} {group}\n")
    DIRECTED.parent.mkdir(parents=True, exist_ok=True)
    DIRECTED.write_text("".join(lines))
    return len(lines)


def run(cmd, log):
    r = subprocess.run(cmd, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    Path(log).write_text(f"$ {' '.join(map(str, cmd))}\n\n{r.stdout}")
    return r.returncode, r.stdout


def tool(*names):
    for n in names:
        p = shutil.which(n)
        if p:
            return p
    raise SystemExit(f"none of {names} on PATH")


def build_sim(rtl, work):
    try:
        return rtl_sim.build(rtl, work), None
    except RuntimeError as e:
        text = str(e)
        errs = [l for l in text.splitlines() if "%Error" in l or "error" in l.lower()]
        return None, "\n".join(errs[:12]) or text[-1500:]


def simulate(sim, rst, x, expected, work, name):
    vec, dump = Path(work) / f"{name}_v.txt", Path(work) / f"{name}_d.txt"
    with vec.open("w") as f:
        f.write("".join(f"{r} {v} {e} 0\n" for r, v, e in zip(rst, x, expected)))
    subprocess.run([str(sim), f"+VECTORS={vec}", f"+DUMP={dump}", f"+CYCLES={len(x)}"],
                   text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=ROOT)
    out = np.loadtxt(dump, dtype=np.int64, ndmin=1)
    vec.unlink()
    return out


def directed_gate(sim, work):
    rows = [l.split() for l in DIRECTED.read_text().splitlines()]
    rst = np.array([int(r[0]) for r in rows])
    x = np.array([int(r[1]) for r in rows])
    exp = np.array([int(r[2]) for r in rows])
    grp = np.array([int(r[3]) for r in rows])
    y = simulate(sim, rst, x, exp, work, "directed")
    err = np.abs(y - exp)
    bad_reset = np.nonzero((rst == 0) & (y != 0))[0]
    bad_tol = np.nonzero(err > TOL_LSB)[0]
    per_group = {}
    for g, name in GROUPS.items():
        m = grp == g
        if m.any():
            per_group[name] = {"cycles": int(m.sum()), "exact_mismatches": int(np.count_nonzero(err[m])),
                               "max_abs_error_lsb": int(err[m].max()),
                               "failures": int(np.count_nonzero(((rst[m] == 0) & (y[m] != 0)) | (err[m] > TOL_LSB)))}
    failures = sorted(set(bad_reset.tolist()) | set(bad_tol.tolist()))
    examples = [{"cycle": int(i), "group": GROUPS.get(int(grp[i]), "?"), "rst_n": int(rst[i]), "x_in": int(x[i]),
                 "expected": int(exp[i]), "rtl": int(y[i])} for i in failures[:6]]
    return {"pass": not failures, "cycles": len(x), "failing_cycles": len(failures),
            "exact_mismatches": int(np.count_nonzero(err)), "max_abs_error_lsb": int(err.max()),
            "reset_cycles_nonzero": int(len(bad_reset)), "per_group": per_group, "examples": examples}


def link_gate(sim, work):
    pulses, th, _ = load_front_end(LEVEL)
    design = hardware_design(pulses, th, 5)
    q = [int(v) for v in design["q110"]]
    assert q == coefficients(), "front-end design no longer matches the stored coefficient set"
    hv = pulses["victim"]
    aggressors = [h for _, h in pulses["aggressors"]]
    tot_bits = tot_sym = be = se = exact = 0
    max_err = 0
    for seed in BER_SEEDS:
        rng = np.random.default_rng(seed)
        m = BER_SYMBOLS + len(hv) + 8
        s = rng.choice(PAM4_LEVELS, size=m)
        r = np.convolve(s + rng.normal(0, np.sqrt(TX_NOISE_VAR), m), hv, "valid")
        for ha in aggressors:
            r += np.convolve(rng.choice(PAM4_LEVELS, size=m).astype(float), ha, "valid")
        r += rng.normal(0, np.sqrt(th), len(r))
        codes = np.clip(np.round(r * design["input_gain"] * 256), -2048, 2047).astype(np.int64)
        ref = fixed_ffe(codes, q)
        rst = np.concatenate([np.zeros(2, int), np.ones(len(codes), int)])
        y = simulate(sim, rst, np.concatenate([np.zeros(2, int), codes]),
                     np.concatenate([np.zeros(2, int), ref]), work, "link")[2:]
        exact += int(np.count_nonzero(y != ref))
        max_err = max(max_err, int(np.abs(y - ref).max()))
        j = np.arange(4, len(codes))
        sent = s[j + len(hv) - 1 - design["delay"]]
        decided = decide(y[j] / 256.0, design["output_gain"])
        wrong = np.nonzero(sent != decided)[0]
        se += len(wrong)
        be += bit_errors(sent[wrong], decided[wrong])[0] if len(wrong) else 0
        tot_sym += len(j)
        tot_bits += 2 * len(j)
    ber, der = be / tot_bits, se / tot_sym
    return {"pass": ber <= TARGET and der <= TARGET, "symbols": tot_sym, "bit_errors": be,
            "symbol_errors": se, "ber": ber, "der": der, "mismatches_vs_fixed_model": exact,
            "max_abs_error_vs_fixed_model_lsb": max_err}


def synth_and_pnr(rtl, work):
    work = Path(work)
    rel = lambda p: os.path.relpath(p, ROOT)
    js, stat = work / "design.json", work / "stat.txt"
    code, out = run([tool("yosys", "yowasp-yosys"), "-q", "-l", rel(work / "yosys.log"), "-p",
                     f"read_verilog -sv {rel(rtl)}; hierarchy -top ffe5tap_pam4; "
                     f"synth_ice40 -top ffe5tap_pam4 -json {rel(js)}; tee -o {rel(stat)} stat"],
                    work / "yosys_console.log")
    if code != 0 or not js.exists():
        return {"ok": False, "error": "\n".join(out.splitlines()[-12:])}
    text = stat.read_text() if stat.exists() else ""
    num = lambda p: (int(re.findall(p, text)[-1]) if re.findall(p, text) else None)
    res = {"ok": True, "lut4": num(r"(\d+)\s+SB_LUT4"), "dff": num(r"(\d+)\s+SB_DFF\w*"),
           "carry": num(r"(\d+)\s+SB_CARRY"), "seeds": []}
    for seed in range(1, PNR_SEEDS + 1):
        code, out = run([tool("nextpnr-ice40", "yowasp-nextpnr-ice40"), "--up5k", "--package", "sg48",
                         "--freq", "12", "--seed", str(seed), "--json", str(js)], work / f"pnr{seed}.log")
        lc = re.search(r"ICESTORM_LC:\s+(\d+)/", out)
        fm = re.findall(r"Max frequency for clock[^:]*: ([\d.]+) MHz", out)
        res["seeds"].append({"seed": seed, "logic_cells": int(lc.group(1)) if lc and code == 0 else None,
                             "fmax_mhz": float(fm[-1]) if fm and code == 0 else None,
                             "critical_path": critical_path(out)})
    good = [s for s in res["seeds"] if s["fmax_mhz"]]
    if not good:
        res["ok"] = False
        res["error"] = "place and route failed"
        return res
    res["logic_cells"] = good[0]["logic_cells"]
    fm = sorted(s["fmax_mhz"] for s in good)
    res["fmax_median_mhz"] = fm[len(fm) // 2]
    res["fmax_min_mhz"], res["fmax_max_mhz"] = fm[0], fm[-1]
    median = [s for s in good if s["fmax_mhz"] == res["fmax_median_mhz"]][0]
    res["critical_path"] = median["critical_path"]
    for s in res["seeds"]:
        s.pop("critical_path", None)
    return res


def critical_path(text):
    """The last critical-path report, as a short list of source/sink/delay lines."""
    blocks = text.split("Critical path report for clock")
    if len(blocks) < 2:
        return []
    last = blocks[-1].splitlines()[:40]
    keep = [l.replace("Info:", "").strip() for l in last
            if re.search(r"(Source|Sink|Setup|Net|logic|routing)", l, re.I) and re.search(r"\d+\.\d+ns", l)]
    return keep[:14]


def evaluate(rtl, out_dir):
    rtl, out = Path(rtl), Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    try:
        shown = str(rtl.relative_to(ROOT))
    except ValueError:
        shown = str(rtl)
    report = {"rtl": shown, "valid": False}
    if not DIRECTED.exists():
        ensure_directed_vectors()
    with tempfile.TemporaryDirectory(dir=ROOT) as tmp:
        sim, err = build_sim(rtl, tmp)
        if sim is None:
            report["g1_build"] = {"pass": False, "error": err}
            (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
            return report
        report["g1_build"] = {"pass": True}
        report["g2_directed"] = directed_gate(sim, tmp)
        report["g3_link"] = link_gate(sim, tmp)
    if report["g2_directed"]["pass"] and report["g3_link"]["pass"]:
        syn = synth_and_pnr(rtl, out)
        report["synthesis"] = syn
        if syn.get("ok"):
            lc, fm = syn["logic_cells"], syn["fmax_median_mhz"]
            report["valid"] = True
            report["score"] = (lc / LC_REF) * (FMAX_REF / fm) ** 0.5
    for f in out.glob("design.json"):
        f.unlink()
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def feedback_text(report):
    """Plain-text report for the agent."""
    L = []
    g1 = report.get("g1_build", {})
    L.append(f"G1 build/synthesis: {'PASS' if g1.get('pass') else 'FAIL'}")
    if not g1.get("pass"):
        L.append("Compiler errors:\n" + str(g1.get("error", "")))
        return "\n".join(L)
    d, k = report["g2_directed"], report["g3_link"]
    L.append(f"G2 directed tests (reset cycles must output 0; every output within {TOL_LSB} LSB of the "
             f"reference): {'PASS' if d['pass'] else 'FAIL'}  ({d['failing_cycles']} failing cycles of "
             f"{d['cycles']}, max error {d['max_abs_error_lsb']} LSB, {d['exact_mismatches']} cycles not bit-exact)")
    for name, v in d["per_group"].items():
        L.append(f"   - {name}: {v['failures']} failing, max error {v['max_abs_error_lsb']} LSB")
    for e in d["examples"]:
        L.append(f"   failing example: cycle {e['cycle']} ({e['group']}) rst_n={e['rst_n']} x_in={e['x_in']} "
                 f"expected={e['expected']} got={e['rtl']}")
    L.append(f"G3 link BER/DER through the RTL on the channel ({k['symbols']:,} symbols): "
             f"BER {k['ber']:.2e}, DER {k['der']:.2e} -> {'PASS' if k['pass'] else 'FAIL'} (limit {TARGET:g}); "
             f"{k['mismatches_vs_fixed_model']:,} outputs differ from the exact reference, "
             f"max difference {k['max_abs_error_vs_fixed_model_lsb']} LSB")
    s = report.get("synthesis")
    if s:
        if s.get("ok"):
            L.append(f"Synthesis (iCE40 UP5K): {s['logic_cells']} logic cells ({s['lut4']} LUT4, {s['dff']} flip-flops, "
                     f"{s['carry']} carry cells); Fmax median {s['fmax_median_mhz']:.1f} MHz "
                     f"(range {s['fmax_min_mhz']:.1f}-{s['fmax_max_mhz']:.1f}, 3 placement seeds)")
            L.append(f"Score {report['score']:.3f} (lower is better; 1.000 = hand-written CSD reference)")
            if s.get("critical_path"):
                L.append("Critical path (median seed):\n   " + "\n   ".join(s["critical_path"]))
        else:
            L.append("Synthesis FAILED:\n" + str(s.get("error")))
    else:
        L.append("Synthesis not run (gates G2/G3 must pass first).")
    return "\n".join(L)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rtl")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    rep = evaluate(Path(args.rtl).resolve(), ROOT / args.out)
    print(feedback_text(rep))


if __name__ == "__main__":
    main()
