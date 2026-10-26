# AI Experiment Log

## Case A

Model:
Claude

Version:
Not recorded

Date:
Not recorded

Prompt:
See resource_optimization.txt

Generated RTL:
rtl/ffe5tap_pam4_claude_resource1.sv

Manual changes:
None

---

## Case B

Model:
Claude

Version:
Not recorded

Date:
Not recorded

Prompt:
See case_B_prompt.txt (embeds resource_optimization.txt)

Generated RTL:
rtl/generalization/optimized/ffe5tap_caseB_optimized.sv
(identical to the RTL in results/generalization/case_B/optimized/ai_response.md, comments excluded)

Manual changes:
None

---

## Case C

Model:
Claude

Version:
Not recorded

Date:
Not recorded

Prompt:
See case_C_prompt.txt (embeds resource_optimization.txt)

Generated RTL:
rtl/generalization/optimized/ffe5tap_caseC_optimized.sv
(identical to the RTL in results/generalization/case_C/optimized/ai_response.md, comments excluded)

Manual changes:
None
## Case B — AI Optimization Record

- Prompt file: prompts/generalization/case_B_prompt.txt
- Response file: results/generalization/case_B/optimized/ai_response.md
- Optimized RTL: rtl/generalization/optimized/ffe5tap_caseB_optimized.sv
- Functional verification: PASS
- Samples: 1000
- Mismatches: 0
- Baseline logic cells: 674
- Optimized logic cells: 376
- Logic-cell reduction: 44.21%
- Baseline SB_LUT4: 593
- Optimized SB_LUT4: 319
- Baseline DSP / optimized DSP: 0 / 0
- Baseline BRAM / optimized BRAM: 0 / 0
- Baseline frequency: 20.20 MHz
- Optimized frequency: 31.22 MHz
- Frequency improvement: 54.55%
- Model/version: Not recorded
- AI iterations: Not recorded
- Manual RTL changes: Not recorded
- Full logs: results/generalization/case_B/optimized/

## Case C — AI Optimization Record

- Prompt file: prompts/generalization/case_C_prompt.txt
- Response file: results/generalization/case_C/optimized/ai_response.md
- Optimized RTL: rtl/generalization/optimized/ffe5tap_caseC_optimized.sv
- Functional verification: PASS
- Samples: 1000
- Mismatches: 0
- Baseline logic cells: 785
- Optimized logic cells: 247
- Logic-cell reduction: 68.54%
- Baseline SB_LUT4: 729
- Optimized SB_LUT4: 196
- Baseline DSP / optimized DSP: 0 / 0
- Baseline BRAM / optimized BRAM: 0 / 0
- Baseline frequency: 25.23 MHz
- Optimized frequency: 32.60 MHz
- Frequency improvement: 29.21%
- Model/version: Not recorded
- AI iterations: Not recorded
- Manual RTL changes: Not recorded
- Full logs: results/generalization/case_C/optimized/


## Channel-derived sets (notebook, short_reach, pre_post, long_tail)

Model:
Claude (claude-opus-5-5)

Date:
2026-10-25

Prompt:
prompts/channel/<channel>_prompt.txt (same format as case_B_prompt.txt),
sent to a fresh instance per set with an instruction to answer without tools

Generated RTL:
rtl/channel/optimized/ffe5tap_<channel>_optimized.sv
(identical to the RTL in results/channel/<channel>/ai_response.md, apart
from a provenance header comment)

Iterations:
1 per set

Manual changes:
None

Verification:
short_reach, pre_post, long_tail: PASS (directed tests; 2.2M channel cycles
each, 0 mismatches vs. the fixed-point model)
notebook: FAIL (overflow test checks acc[23:11] instead of acc[23:21])
