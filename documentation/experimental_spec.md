# Experimental Specification

## Objective

Evaluate whether AI-assisted RTL optimization generalizes across
different coefficient structures in a 5-tap PAM4 feed-forward equalizer.

## Common Hardware Specification

- Architecture: 5-tap feed-forward equalizer (FFE)
- Input: signed 12-bit Q3.8
- Output: signed 12-bit Q3.8
- Coefficients: signed 12-bit Q1.10
- Arithmetic: multiply-accumulate
- Product width: 24 bits
- Accumulator: wide enough to prevent overflow before scaling
- Scaling: arithmetic right shift by 10
- Output saturation: signed 12-bit range [-2048, 2047]
- Latency: 1 clock cycle
- Throughput: 1 sample per clock cycle
- Reset: synchronous active-low
- FPGA target: Lattice iCE40 UP5K
- Verification: Python reference model + SystemVerilog testbench + Verilator
- Implementation flow: Yosys + nextpnr-ice40

## Coefficient Sets

### Case A — Symmetric + Power-of-Two

C0 = 51
C1 = -154
C2 = 1024
C3 = 154
C4 = -51

Properties:
- C4 = -C0
- C3 = -C1
- C2 = 2^10

### Case B — General Random

C0 = 73
C1 = -121
C2 = 89
C3 = 146
C4 = -57

Properties:
- No intentional coefficient symmetry
- No intentional power-of-two coefficient

### Case C — Partially Symmetric

C0 = 51
C1 = -137
C2 = 93
C3 = 137
C4 = -51

Properties:
- C4 = -C0
- C3 = -C1
- C2 is not a power of two

## Variables Held Constant

The following remain unchanged across all experiments:

- Number of taps
- Input/output precision
- Coefficient precision
- Arithmetic scaling
- Saturation behavior
- Latency
- Throughput
- Reset behavior
- FPGA device
- Verification methodology
- Synthesis/place-and-route flow
- AI optimization prompt
- AI model/version, when possible