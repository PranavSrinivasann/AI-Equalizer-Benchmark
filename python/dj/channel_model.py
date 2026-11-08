"""200G/lane PAM4 channel model: S-parameters to symbol-spaced pulse responses.

Signal chain (all differential, 106.25 GBd):

    source Rd -> Tx package -> channel (Sdd21 + crosstalk files) -> Rx package
    -> termination Rd -> Rx filter (4th-order Bessel-Thomson) -> CTLE

Parameters follow the reference channel-operating-margin (COM) configuration
for 212.5 Gb/s PAM4. The package model here is a simplified version of the
reference one (two transmission-line segments plus shunt capacitances, see
PACKAGE below), and Tx FFE, jitter and the Rx DFE are not modelled.
"""

from pathlib import Path

import numpy as np
import skrf as rf
from scipy.signal import bessel, freqs

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "8023dj"

BAUD = 106.25e9
UI = 1.0 / BAUD
NYQUIST = BAUD / 2
OVERSAMPLE = 32          # time-domain samples per UI
F_MAX_FILE = 100e9       # band of the measured S-parameters
F_TAPER_START = 80e9     # raised-cosine band limit from here to F_MAX_FILE

# Reference configuration values (212.5 Gb/s PAM4).
COM = {
    "A_v": 0.413,        # V, victim outer-level amplitude
    "A_fe": 0.413,       # V, FEXT aggressor outer-level amplitude
    "A_ne": 0.608,       # V, NEXT aggressor outer-level amplitude
    "eta0": 5.0e-9,      # V^2/GHz, receiver noise density
    "snr_tx_db": 33.0,   # transmitter SNR
    "R_d": 46.25,        # ohm single-ended; 2x this differential
    "f_r": 0.5 * BAUD,   # Rx filter 3 dB frequency
    "ctle_fz": 25.16e9,
    "ctle_fp1": 40.0e9,
    "ctle_fp2": 56.0e9,
    "g_dc_db": [float(g) for g in range(-15, 1)],
}

# Simplified package: die capacitance, 12 mm + 1.8 mm lines, pad capacitance.
PACKAGE = {
    "C_d": 0.5 * 0.4e-13,                          # F, die pad, differential equivalent
    "C_p": 0.5 * 0.4e-13,                          # F, package pad, differential equivalent
    "lines": [(12.0, 2 * 87.5), (1.8, 2 * 92.5)],  # (mm, differential ohm)
    "tau": 0.006141e-9,                            # s per mm
    "gamma0": 0.0005, "a1": 0.00089, "a2": 0.0002,
}

LEVELS = {
    "loss20": {"label": "baseline ~20 dB", "package": False},
    "loss30": {"label": "main ~30 dB", "package": False},
    "loss40": {"label": "stress ~40 dB", "package": True},
}

# Port pairing of the 4-port files: (side-1 pair), (side-2 pair).
_PAIRINGS = [((0, 2), (1, 3)), ((0, 1), (2, 3))]


def _mixed(s, pair_out, pair_in):
    a, b = pair_in
    c, d = pair_out
    return 0.5 * (s[:, c, a] - s[:, c, b] - s[:, d, a] + s[:, d, b])


def read_differential(path, pairing=None):
    """Return (f, Sdd11, Sdd12, Sdd21, Sdd22, pairing) for a 4-port file.

    Without a pairing, the one whose 1 GHz insertion loss is lower is used
    (the wrong pairing shows a large, non-monotonic loss).
    """
    net = rf.Network(str(path))
    f, s = net.f, net.s
    if pairing is None:
        i1 = int(np.argmin(np.abs(f - 1e9)))
        pairing = min(_PAIRINGS, key=lambda p: -20 * np.log10(abs(_mixed(s, p[1], p[0])[i1])))
    p1, p2 = pairing
    return (f, _mixed(s, p1, p1), _mixed(s, p1, p2), _mixed(s, p2, p1),
            _mixed(s, p2, p2), pairing)


def _abcd_from_s(s11, s12, s21, s22, z0=100.0):
    d = 2 * s21
    A = ((1 + s11) * (1 - s22) + s12 * s21) / d
    B = z0 * ((1 + s11) * (1 + s22) - s12 * s21) / d
    C = ((1 - s11) * (1 - s22) - s12 * s21) / d / z0
    D = ((1 - s11) * (1 + s22) + s12 * s21) / d
    return np.stack([np.stack([A, B], -1), np.stack([C, D], -1)], -2)


def _line(f, length_mm, zc):
    p = PACKAGE
    fg = f / 1e9
    gamma = (p["gamma0"] + (1 + 1j) * p["a1"] * np.sqrt(fg) + p["a2"] * fg
             + 1j * 2 * np.pi * f * p["tau"]) * length_mm
    ch, sh = np.cosh(gamma), np.sinh(gamma)
    m = np.zeros((len(f), 2, 2), dtype=complex)
    m[:, 0, 0], m[:, 0, 1], m[:, 1, 0], m[:, 1, 1] = ch, zc * sh, sh / zc, ch
    return m


def _shunt(f, c):
    m = np.zeros((len(f), 2, 2), dtype=complex)
    m[:, 0, 0] = m[:, 1, 1] = 1
    m[:, 1, 0] = 1j * 2 * np.pi * f * c
    return m


def _package_abcd(f, reverse=False):
    """Die side first: C_d, line 1, line 2, C_p (reversed for the receiver)."""
    parts = [_shunt(f, PACKAGE["C_d"])]
    parts += [_line(f, mm, zc) for mm, zc in PACKAGE["lines"]]
    parts += [_shunt(f, PACKAGE["C_p"])]
    if reverse:
        parts = parts[::-1]
    out = parts[0]
    for m in parts[1:]:
        out = out @ m
    return out


def voltage_transfer(f, abcd):
    """2 * V_load / V_source for matched source and load (0 dB for a lossless line).

    Source and load are both 2 x R_d = 92.5 ohm differential, so the plain
    ratio is 1/2 for a lossless connection; the factor 2 removes that divider
    so the response reads as launched-amplitude to received-amplitude.
    """
    rs = rl = 2 * COM["R_d"]
    A, B, C, D = abcd[:, 0, 0], abcd[:, 0, 1], abcd[:, 1, 0], abcd[:, 1, 1]
    return 2.0 / (A + B / rl + rs * C + rs * D / rl)


def rx_filter(f):
    b, a = bessel(4, 2 * np.pi * COM["f_r"], btype="low", analog=True, norm="mag")
    return freqs(b, a, 2 * np.pi * f)[1]


def ctle(f, g_dc_db):
    fz, fp1, fp2 = COM["ctle_fz"], COM["ctle_fp1"], COM["ctle_fp2"]
    # Zero moved by the DC gain setting: gain is 10^(g/20) at DC and about
    # 0 dB near Nyquist, so a lower setting means more high-frequency boost.
    return (fp1 * fp2 / fz) * (1j * f + fz * 10 ** (g_dc_db / 20)) / (
        (1j * f + fp1) * (1j * f + fp2))


def band_window(f):
    w = np.ones_like(f)
    edge = (f > F_TAPER_START) & (f < F_MAX_FILE)
    w[edge] = 0.5 * (1 + np.cos(np.pi * (f[edge] - F_TAPER_START) / (F_MAX_FILE - F_TAPER_START)))
    w[f >= F_MAX_FILE] = 0.0
    return w


def pulse_from_spectrum(f, h_spectrum):
    """Time-domain response to a one-UI rectangular pulse of unit height.

    Returns (time_step, samples) with OVERSAMPLE samples per UI.
    """
    df = f[1] - f[0]
    n_half = int(round(OVERSAMPLE * BAUD / 2 / df))        # bins up to fs/2
    spectrum = np.zeros(n_half + 1, dtype=complex)
    keep = min(len(f), n_half + 1)
    rect = np.sinc(f[:keep] * UI) * np.exp(-1j * np.pi * f[:keep] * UI)
    spectrum[:keep] = h_spectrum[:keep] * rect
    p = np.fft.irfft(spectrum, n=2 * n_half) * (2 * n_half) * df * UI
    return 1.0 / (OVERSAMPLE * BAUD), p


def level_files(level):
    folder = DATA / level
    thru = sorted(folder.glob("*_thru1.s4p"))
    if not thru:
        raise FileNotFoundError(f"no channel files in {folder}; run scripts/fetch_8023dj_channels.sh")
    fext = sorted(folder.glob("*_xtalk*_Fext.s4p"))
    next_ = sorted(folder.glob("*_xtalk*_Next.s4p"))
    return thru[0], fext, next_


def loss_db(f, h, at=NYQUIST):
    return float(-20 * np.log10(np.interp(at, f, np.abs(h))))


class Level:
    """Everything derived from one set of channel files."""

    def __init__(self, level, with_package=None):
        self.level = level
        self.with_package = LEVELS[level]["package"] if with_package is None else with_package
        thru, fext, next_ = level_files(level)
        f, s11, s12, s21, s22, pairing = read_differential(thru)
        self.f = f
        self.channel_loss_db = loss_db(f, s21)
        self.s_thru = (s11, s12, s21, s22)
        self.xtalk = []
        for kind, files in (("FEXT", fext), ("NEXT", next_)):
            for path in files:
                _, _, _, sdd21_x, _, _ = read_differential(path, pairing)
                self.xtalk.append({"kind": kind, "name": path.name, "s21": sdd21_x,
                                   "loss_db": loss_db(f, sdd21_x)})
        self.h_front = self._front_end()
        self.total_loss_db = loss_db(f, self.h_front)

    def _front_end(self):
        """Source-to-load voltage transfer before the Rx filter and CTLE."""
        f = self.f
        s11, s12, s21, s22 = self.s_thru
        abcd = _abcd_from_s(s11, s12, s21, s22)
        if self.with_package:
            abcd = _package_abcd(f) @ abcd @ _package_abcd(f, reverse=True)
        return voltage_transfer(f, abcd)

    def spectra(self, g_dc_db):
        f = self.f
        back = rx_filter(f) * ctle(f, g_dc_db) * band_window(f)
        victim = self.h_front * back
        z = self.h_front / self.s_thru[2]
        aggressors = [(x["kind"], z * x["s21"] * back) for x in self.xtalk]
        return victim, aggressors

    def thermal_variance(self, g_dc_db):
        f = self.f
        back = rx_filter(f) * ctle(f, g_dc_db) * band_window(f)
        df_ghz = (f[1] - f[0]) / 1e9
        return COM["eta0"] * float(np.sum(np.abs(back) ** 2) * df_ghz)

    def responses(self, g_dc_db, span_ui=3000):
        """Fine-grained time responses (volts per unit symbol) for one CTLE setting."""
        victim, aggressors = self.spectra(g_dc_db)
        keep = span_ui * OVERSAMPLE
        _, pv = pulse_from_spectrum(self.f, victim)
        out = {"victim": pv[:keep] * (COM["A_v"] / 3), "aggressors": []}
        for kind, spec in aggressors:
            _, pa = pulse_from_spectrum(self.f, spec)
            amp = (COM["A_fe"] if kind == "FEXT" else COM["A_ne"]) / 3
            out["aggressors"].append((kind, pa[:keep] * amp))
        out["cursor_ui"] = int(np.argmax(np.abs(out["victim"]))) // OVERSAMPLE
        return out

    @staticmethod
    def sample(resp, phase, pre=10, post=60):
        """Symbol-spaced responses at a sampling phase (0..OVERSAMPLE-1).

        The victim's cursor sits at index `pre`. Symbols are the PAM4 integers
        -3, -1, 1, 3, so responses are in volts per unit symbol.
        """
        lo = resp["cursor_ui"] - pre
        if lo < 0:
            raise ValueError("response peaks too early for the requested pre-cursor span")
        idx = np.arange(lo, lo + pre + post + 1) * OVERSAMPLE + phase
        return {"victim": resp["victim"][idx],
                "aggressors": [(k, a[idx]) for k, a in resp["aggressors"]],
                "phase": phase, "cursor_ui": resp["cursor_ui"]}
