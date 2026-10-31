"""Decision-feedback equalizer model (floating point) for channels a 5-tap FFE cannot pass.

Feed-forward taps and feedback taps are designed jointly (MMSE assuming
correct past decisions); the simulation then feeds back the real decisions,
so error propagation is included. Floating point only: this is a bound on
what a DFE could do, not a hardware design.
"""

import ctypes
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE.parent)]

from dj.ffe_design import SYMBOL_POWER, _conv_matrix, covariance, gaussian_rates  # noqa: E402

_LIB = None


def _load():
    global _LIB
    if _LIB is None:
        so = HERE / "_dfe_sim.so"
        src = HERE / "dfe_sim.c"
        if not so.exists() or so.stat().st_mtime < src.stat().st_mtime:
            subprocess.run(["gcc", "-O2", "-shared", "-fPIC", "-o", str(so), str(src)], check=True)
        _LIB = ctypes.CDLL(str(so))
        _LIB.dfe_run.restype = ctypes.c_int64
        _LIB.dfe_run.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int,
                                 ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_int64,
                                 ctypes.c_void_p]
    return _LIB


def design_dfe(pulses, thermal_var, nff, nb):
    """Returns dict(c, b, delay, error_power, gauss_ber)."""
    R, Hv = covariance(pulses, thermal_var, nff)
    span = Hv.shape[1]
    best = None
    for d in range(span):
        Rp = R.copy()
        for k in range(1, nb + 1):
            if d + k < span:
                col = Hv[:, d + k]
                Rp -= SYMBOL_POWER * np.outer(col, col)
        p = SYMBOL_POWER * Hv[:, d]
        c = np.linalg.solve(Rp, p)
        mse = SYMBOL_POWER - p @ c
        if best is None or mse < best[0]:
            best = (mse, d, c, Rp, p)
    _, d, c, Rp, p = best
    c = c / float(c @ Hv[:, d])
    b = np.array([c @ Hv[:, d + k] if d + k < span else 0.0 for k in range(1, nb + 1)])
    err = float(c @ Rp @ c - 2 * c @ p + SYMBOL_POWER)
    return {"c": c, "b": b, "delay": d, "error_power": err, "gauss_ber": gaussian_rates(err)[1]}


def run_dfe(r, sent, design, skip=64):
    """r: received samples (volts), sent: symbols aligned to outputs. Returns (bit_err, sym_err)."""
    lib = _load()
    r = np.ascontiguousarray(r, dtype=np.float64)
    sent = np.ascontiguousarray(sent, dtype=np.int8)
    c = np.ascontiguousarray(design["c"], dtype=np.float64)
    b = np.ascontiguousarray(design["b"] if len(design["b"]) else np.zeros(1), dtype=np.float64)
    bits = ctypes.c_int64(0)
    sym = lib.dfe_run(r.ctypes.data, sent.ctypes.data, len(r), len(c), c.ctypes.data,
                      len(design["b"]), b.ctypes.data, skip, ctypes.byref(bits))
    return int(bits.value), int(sym)
