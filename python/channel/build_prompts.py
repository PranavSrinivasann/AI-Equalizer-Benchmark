"""Build AI optimization prompts for the channel-derived coefficient sets.

Uses exactly the protocol of Cases B and C: the resource-optimization
prompt (prompts/generalization/resource_optimization.txt) followed by the
baseline RTL, in the same format as prompts/generalization/case_B_prompt.txt.
Writes prompts/channel/<channel>_prompt.txt.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "python" / "rtl_gen"))

from ffe_rtl import baseline_rtl  # noqa: E402


def build(name, coefficients):
    instructions = (ROOT / "prompts/generalization/resource_optimization.txt").read_text().rstrip("\n")
    # Same baseline RTL as rtl/channel/, without the descriptive header comment,
    # matching the Case B and C prompts.
    return f"{instructions}\n\nBaseline RTL to optimize for Case {name}:\n{baseline_rtl(coefficients)}"


def main():
    sets = json.loads((ROOT / "results/channel/coefficient_sets.json").read_text())
    out = ROOT / "prompts" / "channel"
    out.mkdir(parents=True, exist_ok=True)
    for name, info in sets.items():
        path = out / f"{name}_prompt.txt"
        path.write_text(build(name, info["coefficients_q110"]))
        print(f"Wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
