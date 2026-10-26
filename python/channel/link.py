"""Symbol-rate PAM4 link model for the hardware FFE experiments.

Matches the conventions of the benchmark notebooks:
  - Gray-coded PAM4 levels {-3, -1, +1, +3} with the notebook bit mapping
  - additive white Gaussian noise, with SNR defined as the received
    (noiseless) signal power over the noise power
The hardware FFE takes one sample per symbol, so channels here are
symbol-spaced impulse responses applied at the symbol rate.
"""

import numpy as np

PAM4_LEVELS = np.array([-3, -1, 1, 3])

# Gray mapping from the notebooks: (0,0)->-3, (0,1)->-1, (1,1)->+1, (1,0)->+3
_LEVEL_TO_BITS = {-3: (0, 0), -1: (0, 1), 1: (1, 1), 3: (1, 0)}
_BITS_TABLE = np.array([_LEVEL_TO_BITS[l] for l in PAM4_LEVELS])  # index by level

# Symbol-spaced channel impulse responses (main cursor and echoes).
CHANNELS = {
    # The benchmark notebooks' channel taps, applied at the symbol rate.
    "notebook": [0.1, 0.2, 0.5, 0.2, 0.1],
    # Short reach: main cursor with a small trailing echo.
    "short_reach": [1.0, 0.3, 0.1],
    # One pre-cursor plus decaying post-cursors.
    "pre_post": [0.15, 1.0, 0.45, 0.2, 0.05],
    # Long post-cursor tail, typical of bandwidth-limited links.
    "long_tail": [0.08, 1.0, 0.6, 0.3, 0.12],
}


def random_symbols(count, rng):
    return rng.choice(PAM4_LEVELS, size=count)


def symbols_to_bits(symbols):
    index = (np.asarray(symbols) + 3) // 2  # -3,-1,1,3 -> 0,1,2,3
    return _BITS_TABLE[index].reshape(-1)


def apply_channel(symbols, channel):
    """Causal convolution, truncated to the input length."""
    return np.convolve(symbols, channel)[: len(symbols)]


def noise_sigma(channel, snr_db):
    """Noise standard deviation for a given received SNR (PAM4 power = 5)."""
    signal_power = 5.0 * float(np.sum(np.square(channel)))
    return np.sqrt(signal_power / 10 ** (snr_db / 10))


def transmit(symbols, channel, snr_db, rng):
    received = apply_channel(symbols, channel)
    return received + rng.normal(0.0, noise_sigma(channel, snr_db), len(received))


def decide(values, gain=1.0):
    """Nearest PAM4 level for equalizer outputs targeting gain * symbol."""
    v = np.asarray(values, dtype=float) / gain
    return np.where(v < -2, -3, np.where(v < 0, -1, np.where(v < 2, 1, 3)))


def bit_errors(sent, decided):
    a, b = symbols_to_bits(sent), symbols_to_bits(decided)
    return int(np.count_nonzero(a != b)), a.size
