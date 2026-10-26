"""5-tap FFE design and reference models (floating point and bit-exact).

Tap order matches the RTL: c[0] multiplies the newest sample (x_in) and
c[4] the oldest (x4). The fixed-point model is bit-exact with the RTL
contract: Q3.8 input, Q1.10 coefficients, acc >>> 10, saturate to 12 bits.
"""

import numpy as np

NUM_TAPS = 5
X_MIN, X_MAX = -2048, 2047
COEF_FRACTION_BITS = 10
DATA_FRACTION_BITS = 8


def mmse_ffe(channel, snr_db, num_taps=NUM_TAPS):
    """MMSE FFE for a symbol-spaced channel.

    Searches every decision delay and returns (coefficients, delay, mse),
    where the equalizer output at time n estimates the symbol sent at n - delay.
    The MMSE solution is biased (it scales the wanted symbol by less than 1),
    so the returned coefficients are rescaled to unit gain on that symbol;
    otherwise fixed PAM4 decision thresholds would sit in the wrong place.
    """
    h = np.asarray(channel, dtype=float)
    symbol_power = 5.0
    noise_power = symbol_power * np.sum(h ** 2) / 10 ** (snr_db / 10)
    span = len(h) + num_taps - 1
    H = np.zeros((num_taps, span))
    for k in range(num_taps):
        H[k, k:k + len(h)] = h
    R = symbol_power * H @ H.T + noise_power * np.eye(num_taps)
    best = None
    for delay in range(span):
        p = symbol_power * H[:, delay]
        c = np.linalg.solve(R, p)
        mse = symbol_power - p @ c
        if best is None or mse < best[2]:
            best = (c, delay, mse, H[:, delay])
    c, delay, mse, cursor = best
    return c / float(c @ cursor), delay, mse


def output_gain(coefficients, max_coefficient=1.5):
    """Scale the equalizer target so every tap fits comfortably in Q1.10.

    Q1.10 covers [-2, 2). If the MMSE taps are larger than max_coefficient,
    the equalizer is designed to output gain * symbol instead of symbol,
    and decisions use thresholds scaled by the same gain.
    """
    peak = float(np.max(np.abs(coefficients)))
    return min(1.0, max_coefficient / peak)


def quantize(values, fraction_bits, total_bits=12):
    scaled = np.round(np.asarray(values, dtype=float) * 2 ** fraction_bits)
    limit = 2 ** (total_bits - 1)
    return np.clip(scaled, -limit, limit - 1).astype(np.int64)


def float_ffe(samples, coefficients):
    """Floating-point FFE; history starts at zero like the RTL after reset."""
    return np.convolve(samples, coefficients)[: len(samples)]


def fixed_ffe(samples_q38, coefficients_q110):
    """Bit-exact fixed-point FFE: sat12((sum c_k * x[n-k]) >>> 10)."""
    x = np.asarray(samples_q38, dtype=np.int64)
    c = np.asarray(coefficients_q110, dtype=np.int64)
    acc = np.convolve(x, c)[: len(x)]
    return np.clip(acc >> COEF_FRACTION_BITS, X_MIN, X_MAX)


def coefficient_set(channel, snr_db, max_coefficient=1.5):
    """Design, scale and quantize a coefficient set for a channel."""
    c, delay, mse = mmse_ffe(channel, snr_db)
    gain = output_gain(c, max_coefficient)
    c_scaled = c * gain
    return {
        "float": c_scaled,
        "q110": quantize(c_scaled, COEF_FRACTION_BITS),
        "delay": delay,
        "gain": gain,
        "mse": float(mse),
        "design_snr_db": snr_db,
    }
