"""Phase 5 (plan): one agent versus simple searches on the 21 design points.

Design space: 7 tap counts x 3 precisions at the 802.3dj 30 dB channel, with the
measured results of the Phase 4 sweep as the evaluator (BER/DER from 50M symbols,
logic cells and Fmax from Yosys + nextpnr). One evaluation = one lookup of one point,
the stand-in for running the whole flow once. Every method gets the same budget of
evaluations and is scored on the cheapest feasible design it has evaluated.

Targets (minimise logic cells subject to the target):
  primary  BER <= 2e-4 and DER <= 2e-4   (all 21 points pass, so the best is the smallest design)
  stretch  BER <= 1e-6 and DER <= 2e-4   (needs 8 or more taps)

  python3 python/flow/design_search.py baselines            # simple searches, both targets
  python3 python/flow/design_search.py agent-init           # create the agent trials
  python3 python/flow/design_search.py agent-prompt ID      # prompt for the next round of trial ID
  python3 python/flow/design_search.py agent-apply          # stdin lines: ID<TAB>reply
  python3 python/flow/design_search.py summary              # table of all methods
"""

import csv
import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "results" / "phase7" / "search"
STATE = OUT / "agent_state.json"
TAPS = [5, 8, 12, 16, 24, 32, 48]
PRECS = ["P8", "P10", "P12"]
BITS = {"P8": 8, "P10": 10, "P12": 12}
BUDGET = 6
TARGETS = {"primary": 2e-4, "stretch": 1e-6}


def load():
    hw = {(int(r["taps"]), r["precision"]): r for r in csv.DictReader((ROOT / "results/sweep/hw_loss30.csv").open())}
    ber = {(int(r["taps"]), r["precision"]): r for r in csv.DictReader((ROOT / "results/sweep/ber_summary.csv").open())
           if r["level"] == "loss30"}
    table = {}
    for k in hw:
        table[k] = {"taps": k[0], "precision": k[1], "ber": float(ber[k]["ber"]), "der": float(ber[k]["der"]),
                    "logic_cells": int(hw[k]["logic_cells"]), "fmax": float(hw[k]["fmax_median_mhz"])}
    assert len(table) == 21
    return table


TABLE = load()
POINTS = sorted(TABLE, key=lambda k: (k[0], BITS[k[1]]))


def feasible(k, target):
    r = TABLE[k]
    return r["ber"] <= TARGETS[target] and r["der"] <= 2e-4


def optimum(target):
    return min((k for k in POINTS if feasible(k, target)), key=lambda k: TABLE[k]["logic_cells"])


def proxy(k):
    return k[0] * BITS[k[1]]       # taps x bits, known without running anything


def curve(order, target):
    """best feasible logic cells after 1..21 evaluations along a sequence of points."""
    best, out = None, []
    for k in order:
        if feasible(k, target) and (best is None or TABLE[k]["logic_cells"] < best):
            best = TABLE[k]["logic_cells"]
        out.append(best)
    return out


def neighbours(k):
    i, j = TAPS.index(k[0]), PRECS.index(k[1])
    out = []
    for di, dj in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        a, b = i + di, j + dj
        if 0 <= a < len(TAPS) and 0 <= b < len(PRECS):
            out.append((TAPS[a], PRECS[b]))
    return out


def hill_climb(start, target):
    """Greedy grid search. Feasible: try the unevaluated neighbours that are cheaper by the
    taps x bits estimate, cheapest first, and move on a real saving. Infeasible: move to the
    unevaluated neighbour with the next larger estimate. Stops when nothing is left to try."""
    seen, order = {start}, [start]
    cur = start
    while len(order) < len(POINTS):
        if feasible(cur, target):
            cands = sorted((n for n in neighbours(cur) if n not in seen and proxy(n) < proxy(cur)), key=proxy)
        else:
            cands = sorted((n for n in neighbours(cur) if n not in seen and proxy(n) > proxy(cur)), key=proxy)[:1]
        if not cands:
            break
        nxt = cands[0]
        seen.add(nxt)
        order.append(nxt)
        if feasible(nxt, target) and (not feasible(cur, target) or TABLE[nxt]["logic_cells"] < TABLE[cur]["logic_cells"]):
            cur = nxt
        elif not feasible(nxt, target):
            cur = nxt if not feasible(cur, target) else cur
    rest = [k for k in POINTS if k not in seen]
    return order, rest


def first_hit(cv, target_cells):
    return next((i + 1 for i, v in enumerate(cv) if v == target_cells), None)


def baselines():
    res = {}
    rng = random.Random(0)
    for target in TARGETS:
        opt = optimum(target)
        oc = TABLE[opt]["logic_cells"]
        r = {"optimum": f"{opt[0]} taps, {opt[1]}", "optimum_cells": oc}
        # random search without replacement: exact P(optimum within k) = k/21, Monte Carlo for the cost
        trials = 20000
        best_k = [[] for _ in range(BUDGET)]
        for _ in range(trials):
            order = POINTS[:]
            rng.shuffle(order)
            cv = curve(order, target)
            for k in range(BUDGET):
                best_k[k].append(cv[k])
        r["random"] = {"p_optimum_within_budget": BUDGET / 21, "expected_evals_to_optimum": 11.0,
                       "mean_best_cells_by_k": [round(sum(v for v in b if v) / max(1, sum(1 for v in b if v)), 1) for b in best_k],
                       "p_any_feasible_by_k": [round(sum(1 for v in b if v) / trials, 3) for b in best_k]}
        # scan in order of the taps x bits estimate (no feedback)
        order = sorted(POINTS, key=lambda k: (proxy(k), k[0]))
        cv = curve(order, target)
        r["scan_by_estimate"] = {"order": [f"{k[0]}/{k[1]}" for k in order[:BUDGET]], "best_cells_by_k": cv[:BUDGET],
                                 "evals_to_optimum": first_hit(cv, oc)}
        # hill climb from every start point
        hits, curves = [], []
        for s in POINTS:
            o, rest = hill_climb(s, target)
            cv = curve(o + rest, target)
            curves.append(cv[:BUDGET])
            hits.append(first_hit(cv, oc))
        found = [h for h in hits if h is not None and h <= BUDGET]
        r["hill_climb"] = {"starts": len(POINTS), "p_optimum_within_budget": len(found) / len(POINTS),
                           "mean_evals_to_optimum_when_found": round(sum(found) / len(found), 2) if found else None,
                           "mean_best_cells_by_k": [round(sum(c[k] for c in curves if c[k]) / max(1, sum(1 for c in curves if c[k])), 1)
                                                    for k in range(BUDGET)],
                           "p_any_feasible_by_k": [round(sum(1 for c in curves if c[k]) / len(curves), 3) for k in range(BUDGET)]}
        res[target] = r
    (OUT / "baselines.json").write_text(json.dumps(res, indent=1) + "\n")
    return res


# ------------------------------------------------------------------ agent trials
TASK = """You are choosing the hardware configuration of a PAM4 feed-forward equalizer (FFE) for an optical/electrical link (IEEE 802.3dj, 30 dB channel), implemented on a small iCE40 UP5K FPGA. Work only from this message; you have no tools and no files.

Design space (21 designs): number of taps in {{5, 8, 12, 16, 24, 32, 48}} and precision in {{P8, P10, P12}}. P8, P10 and P12 are the sample width in bits (8, 10, 12), with the coefficient width scaled to match.

Goal: find the design with the FEWEST LOGIC CELLS whose bit error rate meets the target: {goal}.

Each evaluation runs the complete flow for one design (RTL check, 50 million PAM4 symbols through the channel, synthesis and place-and-route) and returns its BER, symbol error rate (DER), logic cells and Fmax. You may use at most {budget} evaluations in total. Evaluations are expensive, so do not waste them.

{history}

Reply with exactly one line and nothing else, in one of these two forms:
PICK taps=<n> precision=<P8|P10|P12> | WHY: <one sentence>      (evaluate this design next)
STOP best=<n>,<P8|P10|P12> | WHY: <one sentence>                (finish; the best must be a design you have already evaluated)"""

GOALS = {"primary": "BER at most 2e-4 and DER at most 2e-4",
         "stretch": "BER at most 1e-6 and DER at most 2e-4"}


def state():
    return json.loads(STATE.read_text()) if STATE.exists() else None


def save(s):
    STATE.write_text(json.dumps(s, indent=1) + "\n")


def agent_init(n_primary=3, n_stretch=4):
    trials = {}
    for target, n in (("primary", n_primary), ("stretch", n_stretch)):
        for i in range(1, n + 1):
            trials[f"{target}_{i}"] = {"target": target, "evals": [], "replies": [], "stopped": None}
    save({"budget": BUDGET, "trials": trials})
    print(len(trials), "trials:", ", ".join(trials))


def history_text(t):
    if not t["evals"]:
        return "Evaluations so far: none."
    lines = ["Evaluations so far (your own):", "| # | taps | precision | BER | DER | logic cells | Fmax (MHz) | meets target |",
             "|---|---|---|---|---|---|---|---|"]
    for i, e in enumerate(t["evals"], 1):
        lines.append(f"| {i} | {e['taps']} | {e['precision']} | {e['ber']:.2e} | {e['der']:.2e} | {e['logic_cells']} | "
                     f"{e['fmax']:.1f} | {'yes' if e['feasible'] else 'no'} |")
    lines.append(f"Evaluations used: {len(t['evals'])} of {BUDGET}.")
    return "\n".join(lines)


def agent_prompt(tid):
    s = state()
    t = s["trials"][tid]
    return TASK.format(goal=GOALS[t["target"]], budget=BUDGET, history=history_text(t))


def apply_reply(s, tid, reply):
    import re
    t = s["trials"][tid]
    t["replies"].append(reply.strip())
    if t["stopped"] is not None:
        return "already stopped"
    m = re.search(r"PICK\s+taps=(\d+)\s+precision=(P8|P10|P12)", reply)
    if m:
        k = (int(m.group(1)), m.group(2))
        if k not in TABLE:
            return f"invalid design {k}"
        r = dict(TABLE[k])
        r["feasible"] = feasible(k, t["target"])
        r["repeat"] = any((e["taps"], e["precision"]) == k for e in t["evals"])
        t["evals"].append(r)
        if len(t["evals"]) >= BUDGET:
            t["stopped"] = "budget"
        return f"evaluated {k[0]}/{k[1]}: {r['logic_cells']} cells, {'feasible' if r['feasible'] else 'infeasible'}"
    m = re.search(r"STOP\s+best=(\d+),\s*(P8|P10|P12)", reply)
    if m:
        t["stopped"] = f"stop:{m.group(1)}/{m.group(2)}"
        return t["stopped"]
    return "UNPARSED"


def agent_apply():
    s = state()
    for line in sys.stdin:
        if "\t" not in line:
            continue
        tid, reply = line.rstrip("\n").split("\t", 1)
        print(tid, "->", apply_reply(s, tid, reply))
    save(s)


def trial_summary(t):
    target = t["target"]
    opt = optimum(target)
    oc = TABLE[opt]["logic_cells"]
    cv = curve([(e["taps"], e["precision"]) for e in t["evals"]], target)
    final = None
    if t["stopped"] and t["stopped"].startswith("stop:"):
        n, p = t["stopped"][5:].split("/")
        final = (int(n), p)
    best = min((e for e in t["evals"] if e["feasible"]), key=lambda e: e["logic_cells"], default=None)
    return {"evals": len(t["evals"]), "best_cells": best["logic_cells"] if best else None,
            "evals_to_optimum": first_hit(cv, oc), "reported": final, "optimum_cells": oc,
            "reported_is_best_evaluated": (final == (best["taps"], best["precision"])) if (final and best) else None}


def summary():
    b = json.loads((OUT / "baselines.json").read_text())
    s = state()
    for target in TARGETS:
        r = b[target]
        print(f"\n== {target}: optimum {r['optimum']} ({r['optimum_cells']} cells), budget {BUDGET} of 21 ==")
        print("random search       P(optimum in budget) %.2f, expected evals to optimum 11.0, mean best cells by k: %s" % (
            r["random"]["p_optimum_within_budget"], r["random"]["mean_best_cells_by_k"]))
        print("scan by estimate    evals to optimum:", r["scan_by_estimate"]["evals_to_optimum"], " best cells by k:", r["scan_by_estimate"]["best_cells_by_k"])
        h = r["hill_climb"]
        print("hill climb (21 starts) P(optimum in budget) %.2f, mean evals when found %s" % (h["p_optimum_within_budget"], h["mean_evals_to_optimum_when_found"]))
        if s:
            for tid, t in s["trials"].items():
                if t["target"] == target:
                    print("agent", tid, trial_summary(t))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    cmd = sys.argv[1]
    if cmd == "baselines":
        print(json.dumps(baselines(), indent=1))
    elif cmd == "agent-init":
        agent_init()
    elif cmd == "agent-prompt":
        print(agent_prompt(sys.argv[2]))
    elif cmd == "agent-apply":
        agent_apply()
    elif cmd == "summary":
        summary()
