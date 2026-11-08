"""FFE design and BER measurement on the pulse-response channels.

Same hardware contract as python/channel/equalizer.py: Q3.8 input,
Q1.10 coefficients, acc >>> 10, saturate to 12 bits; tap c[0] multiplies
the newest sample. This module adds what the 802.3dj channels need:
covariance-based MMSE design that includes crosstalk and transmitter
noise, an input gain stage, and a Monte-Carlo link simulation.
"""

import sys
from pathlib import Path

import numpy as np
from scipy.special import erfc

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from channel.equalizer import (COEF_FRACTION_BITS, fixed_ffe, output_gain,  # noqa: E402
                               quantize)
from channel.link import PAM4_LEVELS, bit_errors, decide  # noqa: E402
from dj.channel_model import COM, OVERSAMPLE, Level  # noqa: E402

SYMBOL_POWER = 5.0
TX_NOISE_VAR = SYMBOL_POWER / 10 ** (COM["snr_tx_db"] / 10)   # symbol units^2
CLIP_SIGMAS = 4.5


def q_func(x):
    return 0.5 * erfc(x / np.sqrt(2))


def _conv_matrix(h, num_taps):
    span = len(h) + num_taps - 1
    H = np.zeros((num_taps, span))
    for k in range(num_taps):
        H[k, k:k + len(h)] = h
    return H


def covariance(pulses, thermal_var, num_taps):
    """Receive-sample covariance R and the cross-correlation matrix.

    Returns (R, Hv) where Hv[k, d] is the response of the victim symbol sent
    d positions before the newest sample, seen at tap k.
    """
    Hv = _conv_matrix(pulses["victim"], num_taps)
    R = (SYMBOL_POWER + TX_NOISE_VAR) * Hv @ Hv.T + thermal_var * np.eye(num_taps)
    for _, ha in pulses["aggressors"]:
        Ha = _conv_matrix(ha, num_taps)
        R += SYMBOL_POWER * Ha @ Ha.T
    return R, Hv


def mmse_design(pulses, thermal_var, num_taps):
    """Unbiased MMSE taps (unit gain on the wanted symbol), best decision delay.

    Returns dict with taps (per volt), delay, and the residual error power
    E[(y - s)^2] of the unbiased filter in symbol units.
    """
    R, Hv = covariance(pulses, thermal_var, num_taps)
    best = None
    for d in range(Hv.shape[1]):
        p = SYMBOL_POWER * Hv[:, d]
        c = np.linalg.solve(R, p)
        mse = SYMBOL_POWER - p @ c
        if best is None or mse < best[0]:
            best = (mse, d, c, Hv[:, d])
    _, d, c, cursor = best
    c = c / float(c @ cursor)
    p = SYMBOL_POWER * Hv[:, d]
    error_power = float(c @ R @ c - 2 * c @ p + SYMBOL_POWER)
    return {"taps": c, "delay": d, "error_power": error_power}


def gaussian_rates(error_power):
    """Symbol- and bit-error rates if the residual error were Gaussian."""
    ser = 1.5 * q_func(1.0 / np.sqrt(error_power))
    return float(ser), float(ser / 2)


def rx_rms(pulses, thermal_var):
    var = (SYMBOL_POWER + TX_NOISE_VAR) * np.sum(pulses["victim"] ** 2) + thermal_var
    var += SYMBOL_POWER * sum(np.sum(h ** 2) for _, h in pulses["aggressors"])
    return float(np.sqrt(var))


def hardware_design(pulses, thermal_var, num_taps=5, max_coefficient=1.5):
    """Complete hardware setup: input gain, coefficient set, decision gain."""
    d = mmse_design(pulses, thermal_var, num_taps)
    g = (2047 / 256 * 0.97) / (CLIP_SIGMAS * rx_rms(pulses, thermal_var))   # code per volt
    unit = d["taps"] / g                       # taps acting on codes, output = symbol
    gain = output_gain(unit, max_coefficient)
    c_float = unit * gain
    return {"input_gain": g, "output_gain": gain, "delay": d["delay"],
            "float": c_float, "q110": quantize(c_float, COEF_FRACTION_BITS),
            "error_power": d["error_power"],
            "gauss_ser": gaussian_rates(d["error_power"])[0],
            "gauss_ber": gaussian_rates(d["error_power"])[1]}


def choose_front_end(level: Level, num_taps=5, pre=10, post=60):
    """Pick the CTLE setting and sampling phase that minimize 5-tap error power.

    Returns the winner plus the sweep (best error power for every CTLE setting).
    """
    best, sweep = None, []
    for g_db in COM["g_dc_db"]:
        resp = level.responses(g_db)
        th = level.thermal_variance(g_db)
        local = None
        for phase in range(OVERSAMPLE):
            pul = level.sample(resp, phase, pre, post)
            e = mmse_design(pul, th, num_taps)["error_power"]
            if local is None or e < local[0]:
                local = (e, g_db, phase, pul, th)
        sweep.append({"g_dc_db": g_db, "phase": local[2], "error_power": local[0]})
        if best is None or local[0] < best[0]:
            best = local
    e, g_db, phase, pul, th = best
    return {"g_dc_db": g_db, "phase": phase, "pulses": pul, "thermal_var": th,
            "error_power": e, "sweep": sweep}


def simulate(pulses, thermal_var, design, n_symbols, seed, chunk=1_000_000, quantized_models=()):
    """Monte-Carlo link run; returns error counts for float, fixed (and extra models).

    The same received samples go through every model. The input stage rounds
    to Q3.8 (clipping if needed); the float model sees the unrounded samples.
    """
    rng = np.random.default_rng(seed)
    hv = pulses["victim"]
    aggressors = [h for _, h in pulses["aggressors"]]
    taps = len(design["float"])
    history = len(hv) + taps
    results = {"float": [0, 0, 0], "fixed": [0, 0, 0]}   # bit errors, symbol errors, count
    clipped = 0
    thermal_sigma = np.sqrt(thermal_var)
    done = 0
    while done < n_symbols:
        n = min(chunk, n_symbols - done)
        m = n + history
        s = rng.choice(PAM4_LEVELS, size=m)
        tx = s.astype(float) + rng.normal(0.0, np.sqrt(TX_NOISE_VAR), m)
        r = np.convolve(tx, hv, "valid")
        for ha in aggressors:
            r += np.convolve(rng.choice(PAM4_LEVELS, size=m).astype(float), ha, "valid")
        r += rng.normal(0.0, thermal_sigma, len(r))
        x = r * design["input_gain"]
        codes = np.clip(np.round(x * 256), -2048, 2047).astype(np.int64)
        clipped += int(np.count_nonzero(np.abs(np.round(x * 256)) > 2047))
        y_float = np.convolve(x, design["float"])[: len(x)]
        y_fixed = fixed_ffe(codes, design["q110"]) / 256.0
        # r[j] is the sample at symbol time j + len(hv) - 1; output j estimates
        # the symbol sent `delay` earlier.
        j = np.arange(taps - 1, len(x))
        sent = s[j + len(hv) - 1 - design["delay"]]
        for name, y in (("float", y_float), ("fixed", y_fixed)):
            decided = decide(y[j], design["output_gain"])
            be, _ = bit_errors(sent, decided)
            results[name][0] += be
            results[name][1] += int(np.count_nonzero(sent != decided))
            results[name][2] += len(j)
        done += n
    return {"symbols": results["fixed"][2], "bits": 2 * results["fixed"][2],
            "float_bit_errors": results["float"][0], "float_symbol_errors": results["float"][1],
            "fixed_bit_errors": results["fixed"][0], "fixed_symbol_errors": results["fixed"][1],
            "samples_clipped": clipped}
