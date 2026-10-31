#!/usr/bin/env python3
"""Build the game's sound palette: deterministic synthesised effects and the
ambient loop.

Requires NumPy; writes 16-bit mono PCM WAV with the standard library `wave`
module. Run from the project root:

    python3 -I art_sources/audio/generate_sounds.py

Every sound uses fixed parameters and fixed random seeds, so two runs produce
byte-identical files.

The palette (docs/VISION.md, "Moment-to-moment feel"): a girl alone in a
snowed garden at dusk. Soft, warm and sparse, never gamey. Three families:

- snow: footsteps, the landing, the wind;
- glass and ice: the mirror (raise, lower, confirm, ticks, swing, moving on);
- felt piano: the title tap, the goal, and the distant motif in the loop.

Everything tonal sits in D Dorian, so any two sounds that overlap agree.
"""
from pathlib import Path
import wave

import numpy as np

SR = 44100
OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "audio"

# Peak targets in dBFS, one per sound, set by ear-proxy for perceived
# loudness rather than one shared ceiling: noisy and percussive sounds read
# louder than their peak suggests, held tones quieter. `world/sounds.gd` can
# trim further per event with `volume_db`.
PEAK_DB = {
    "step": -20.0,
    "land": -10.0,
    "ui": -12.0,
    "swing": -13.0,
    "view": -17.0,
    "create": -8.0,
    "remove": -10.0,
    "confirm": -11.0,
    "goal": -8.0,
    "sweep": -11.0,
    "title_tap": -7.0,
    "ambient_loop": -14.0,
}

# Footsteps are matched by loudness instead (see `make_step`); their
# "step" peak above is only the starting point.
STEP_RMS_DB = -40.0

# The ambient loop's length. 32 s of 16-bit mono at 44.1 kHz is 2.8 MB,
# inside the 3 MB source budget. `ambient_loop.wav.import` must set
# `edit/loop_end` to this many samples.
LOOP_SECONDS = 32.0

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6,
              "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}


def hz(name):
    """Equal-tempered frequency of a note name such as "D4" or "F#5"."""
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + NOTE_INDEX[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def seconds(s):
    return int(round(s * SR))


def timeline(n):
    return np.arange(n) / SR


# --- filters (offline, zero-phase, FFT domain) ----------------------------------

def _next_pow2(n):
    return 1 << int(np.ceil(np.log2(max(n, 2))))


def spectral(x, gain_fn):
    """Applies a real gain curve `gain_fn(freqs)` to the whole signal. Padded
    so the circular FFT never wraps the tail onto the head."""
    n = len(x)
    size = _next_pow2(n + SR // 2)
    freqs = np.fft.rfftfreq(size, 1 / SR)
    return np.fft.irfft(np.fft.rfft(x, size) * gain_fn(freqs), size)[:n]


def lowpass(x, cutoff, order=2):
    return spectral(x, lambda f: 1 / np.sqrt(1 + (f / cutoff) ** (2 * order)))


def highpass(x, cutoff, order=2):
    return spectral(x, lambda f: 1 / np.sqrt(1 + (cutoff / np.maximum(f, 1e-3)) ** (2 * order)))


def bandpass(x, low, high, order=2):
    return highpass(lowpass(x, high, order), low, order)


def convolve(x, ir):
    size = _next_pow2(len(x) + len(ir))
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:len(x) + len(ir) - 1]


def reverb(x, seed, decay=2.0, mix=0.3, predelay=0.018, damping=5000.0):
    """A soft synthetic room: decaying noise that darkens as it decays.

    `decay` is the time to fall 60 dB. The output keeps the input's length,
    so a caller leaves enough silence at the end for the tail it wants."""
    rng = np.random.default_rng(seed)
    n = seconds(decay)
    t = timeline(n)
    noise = rng.standard_normal(n)
    bright = lowpass(noise, damping)
    dark = lowpass(noise, damping * 0.3)
    tau = decay / 6.9
    blend = np.exp(-t / (tau * 0.4))
    ir = (bright * blend + dark * (1 - blend)) * np.exp(-t / tau)
    ir *= 1 - np.exp(-t / 0.004)
    ir = np.concatenate([np.zeros(seconds(predelay)), ir])
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = convolve(x, ir)[:len(x)]
    return x + wet * mix


def moving_band(rng, n, frame_gain, block=4096, hop=1024):
    """White noise filtered by a spectrum that changes over time.

    `frame_gain(t, freqs)` returns the gain curve for a frame centred at
    time `t`. Overlap-added Hann frames keep the changes smooth."""
    padded = n + 2 * block
    noise = rng.standard_normal(padded)
    window = np.hanning(block)
    freqs = np.fft.rfftfreq(block, 1 / SR)
    out = np.zeros(padded)
    for start in range(0, padded - block + 1, hop):
        centre = (start - block / 2) / SR
        spectrum = np.fft.rfft(noise[start:start + block] * window)
        out[start:start + block] += np.fft.irfft(spectrum * frame_gain(centre, freqs), block)
    # One block of lead-in on each side, so every kept sample has full overlap.
    out = out[block:block + n]
    peak = np.max(np.abs(out))
    return out / peak if peak > 1e-9 else out


def bump(freqs, centre, width):
    return np.exp(-0.5 * ((freqs - centre) / width) ** 2)


# --- envelopes ---------------------------------------------------------------------

def swell(n, start, attack, hold, release):
    """Zero, a raised-cosine rise over `attack`, flat for `hold`, then a
    raised-cosine fall over `release`, all in seconds; zero afterwards."""
    t = timeline(n) - start
    # Both phases come from clipped ramps of the same time value, so no
    # sample can fall between them (a one-sample gap is an audible tick).
    rise = np.clip(t / attack, 0, 1)
    fall = np.clip((t - attack - hold) / release, 0, 1)
    env = 0.25 * (1 - np.cos(np.pi * rise)) * (1 + np.cos(np.pi * fall))
    return env


def strike(n, start, attack, tau):
    """A soft onset then an exponential decay, starting at `start` seconds."""
    t = timeline(n) - start
    env = np.where(t >= 0, (1 - np.exp(-np.maximum(t, 0) / max(attack, 1e-4))) * np.exp(-np.maximum(t, 0) / tau), 0.0)
    return env


def fade_edges(x, fade_in_ms=2.0, fade_out_ms=40.0):
    """Short fades at both ends so a sound always starts and ends at zero."""
    x = x.copy()
    a, b = seconds(fade_in_ms / 1000), seconds(fade_out_ms / 1000)
    if a > 0:
        x[:a] *= 0.5 * (1 - np.cos(np.linspace(0, np.pi, a)))
    if b > 0:
        x[-b:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, b)))
    return x


def finish(x, name, fade_in_ms=2.0, fade_out_ms=40.0):
    x = x - np.mean(x)
    x = fade_edges(x, fade_in_ms, fade_out_ms)
    peak = np.max(np.abs(x))
    return x * (10 ** (PEAK_DB[name] / 20) / peak) if peak > 1e-9 else x


def write_wav(path, data):
    samples = np.round(np.clip(data, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(samples.tobytes())


# --- voices ------------------------------------------------------------------------

# Glass modes: a near-pure fundamental with two faint inharmonic modes, like
# a wine glass or a sheet of ice. Each mode is a pair a fraction of a hertz
# apart, so the tone breathes with a slow beat instead of sounding electronic.
GLASS_MODES = ((1.0, 1.0), (2.32, 0.09), (4.25, 0.03))


def glass(n, rng, freq, env, beat=0.6, modes=GLASS_MODES, mode_decay=None):
    """A glass tone shaped by `env` (an array of length n). `mode_decay`, if
    given, is a time constant that makes the upper modes fade faster."""
    t = timeline(n)
    out = np.zeros(n)
    for ratio, weight in modes:
        f = freq * ratio
        pair = (np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
                + np.sin(2 * np.pi * (f + beat * ratio) * t + rng.uniform(0, 2 * np.pi))) / 2
        mode_env = env
        if mode_decay is not None and ratio > 1:
            mode_env = env * np.exp(-t / (mode_decay / ratio))
        out += weight * pair * mode_env
    return out


def warm(n, rng, freq, env, detune_cents=3.0):
    """A warm held voice: sine with soft second and third harmonics, three
    copies a few cents apart for a gentle chorus."""
    t = timeline(n)
    out = np.zeros(n)
    for cents in (-detune_cents, 0.0, detune_cents):
        f = freq * 2 ** (cents / 1200)
        phase = rng.uniform(0, 2 * np.pi)
        out += (np.sin(2 * np.pi * f * t + phase)
                + 0.22 * np.sin(4 * np.pi * f * t + 2 * phase)
                + 0.07 * np.sin(6 * np.pi * f * t + 3 * phase))
    return out / 3 * env


def felt_piano(freq, velocity, length, rng, damper=None):
    """One felt-piano note: slightly stretched partials that each decay in
    two stages (prompt sound, then aftersound), three unison strings a hair
    apart, a soft felt attack, a little hammer noise, and a muffled top end.

    `velocity` is 0..1. `damper`, in seconds, lifts the note off with a
    short release; left out, the damper falls just before `length`, so the
    note always ends at zero."""
    n = seconds(length)
    t = timeline(n)
    out = np.zeros(n)
    inharmonicity = 0.00035
    rolloff = 2.5 + 4.0 * velocity
    base_fast = 0.55 * (293.66 / freq) ** 0.5
    base_slow = 3.2 * (293.66 / freq) ** 0.6
    for k in range(1, 18):
        fk = k * freq * np.sqrt(1 + inharmonicity * k * k)
        if fk > 8000:
            break
        amp = np.exp(-(k - 1) / rolloff) / k ** 0.6
        fast = base_fast / (1 + 0.45 * (k - 1))
        slow = base_slow / (1 + 0.30 * (k - 1))
        env = 0.65 * np.exp(-t / fast) + 0.35 * np.exp(-t / slow)
        strings = np.zeros(n)
        for cents in (-0.7, 0.1, 0.8):
            strings += np.sin(2 * np.pi * fk * 2 ** (cents / 1200) * t + rng.uniform(0, 2 * np.pi))
        out += amp * env * strings / 3
    out *= 1 - np.exp(-t / (0.006 - 0.003 * velocity))
    hammer = lowpass(rng.standard_normal(n), 900 + 1400 * velocity) * strike(n, 0.0, 0.0008, 0.010)
    thock = bandpass(rng.standard_normal(n), freq * 1.5, freq * 4) * strike(n, 0.0, 0.001, 0.020)
    out += hammer * 0.05 * velocity + thock * 0.04
    out = lowpass(out, 1400 + 3200 * velocity)
    if damper is None:
        damper = length - 0.4
    out *= swell(n, 0.0, 1e-4, damper, 0.35)
    return out * (0.35 + 0.65 * velocity)


def crunch(rng, n, length, grains, brightness=1.0):
    """Snow crunch: a burst of tiny crackles under a soft envelope, filtered
    to stay muffled. `grains` is roughly how many crackles; `length` is
    how long the burst lasts, in seconds."""
    out = np.zeros(n)
    count = rng.poisson(grains)
    times = rng.beta(1.4, 3.2, count) * length
    for when in times:
        start = seconds(when)
        size = seconds(rng.uniform(0.0015, 0.005))
        if start + size >= n:
            continue
        envelope_at = np.exp(-when / (length * 0.45))
        grain = rng.standard_normal(size) * np.exp(-np.arange(size) / (size * 0.25))
        out[start:start + size] += grain * rng.uniform(0.25, 1.0) * envelope_at
    return bandpass(out, 500, 3800 * brightness)


# --- effects -----------------------------------------------------------------------

def make_step(seed):
    """A small child's step in fresh snow, ~0.22 s: a soft press and a few
    muffled crackles. `seed` gives each of the three variants its own
    grains, length and brightness."""
    rng = np.random.default_rng(seed)
    n = seconds(0.22)
    length = rng.uniform(0.09, 0.13)
    press = lowpass(rng.standard_normal(n), 320) * strike(n, 0.0, 0.006, 0.035)
    out = crunch(rng, n, length, rng.uniform(26, 36), rng.uniform(0.85, 1.05)) * 0.55 + press * 0.9
    out = lowpass(out, 3200)
    out = finish(out, "step", 1.5, 30.0)
    # The variants differ in density, so match their loudness (RMS) rather
    # than their peaks; the walk then has no odd loud or quiet step.
    out *= 10 ** (STEP_RMS_DB / 20) / np.sqrt(np.mean(out ** 2))
    return out


def make_land():
    """Landing in snow, ~0.8 s: a soft thump, a crunch, a puff of powder."""
    rng = np.random.default_rng(701)
    n = seconds(0.8)
    t = timeline(n)
    thump = lowpass(rng.standard_normal(n), 170) * strike(n, 0.0, 0.004, 0.075)
    body_freq = 62 + 18 * np.exp(-t / 0.05)
    body = np.sin(2 * np.pi * np.cumsum(body_freq) / SR) * strike(n, 0.0, 0.003, 0.07)
    crackle = crunch(rng, n, 0.2, 70, 0.9)
    puff = lowpass(rng.standard_normal(n), 1400) * strike(n, 0.012, 0.02, 0.17)
    out = thump * 1.0 + body * 0.55 + crackle * 0.3 + puff * 0.22
    out = reverb(out, 702, decay=0.7, mix=0.12, damping=3000)
    return finish(out, "land", 1.0, 80.0)


def make_ui():
    """A very soft glass tick, ~0.3 s with its room: a fingertip on a pane.
    Shared by slide, resize and turn adjustments and by the HUD buttons."""
    rng = np.random.default_rng(601)
    n = seconds(0.3)
    env = strike(n, 0.0, 0.0015, 0.028)
    tick = glass(n, rng, hz("E6"), env, beat=2.0,
                 modes=((1.0, 1.0), (2.32, 0.35), (4.25, 0.12)), mode_decay=0.02)
    touch = bandpass(rng.standard_normal(n), 2000, 6000) * strike(n, 0.0, 0.0005, 0.003)
    out = tick + touch * 0.12
    out = lowpass(out, 6500)
    out = reverb(out, 602, decay=0.5, mix=0.25)
    return finish(out, "ui", 1.0, 40.0)


def make_swing():
    """The mirror swinging round to a new direction (0.6 s): a breath of air
    and a soft rising fourth in glass, ~1.1 s with its tail."""
    rng = np.random.default_rng(1301)
    n = seconds(1.1)
    air = moving_band(rng, n, lambda t, f: bump(f, 380 + 520 * np.sin(np.pi * min(t / 0.6, 1)), 260)
                      + 0.25 * bump(f, 2400, 900))
    air *= swell(n, 0.0, 0.28, 0.0, 0.42)
    low_note = glass(n, rng, hz("A5"), strike(n, 0.04, 0.012, 0.22), mode_decay=0.15)
    high_note = glass(n, rng, hz("D6"), strike(n, 0.30, 0.012, 0.28), mode_decay=0.15)
    out = air * 0.7 + (low_note * 0.16 + high_note * 0.14)
    out = reverb(out, 1302, decay=1.0, mix=0.25)
    return finish(out, "swing", 2.0, 120.0)


def make_view():
    """Turning the view (0.8 s): a soft swell of wind, ~1.3 s, no pitch."""
    rng = np.random.default_rng(1401)
    n = seconds(1.3)

    def gain(t, f):
        rise = np.sin(np.pi * np.clip(t / 0.95, 0, 1))
        return (bump(f, 420 + 380 * rise, 300 + 150 * rise)
                + 0.35 * bump(f, 160, 90)
                + 0.12 * rise * bump(f, 3200, 1400))

    out = moving_band(rng, n, gain) * swell(n, 0.0, 0.48, 0.05, 0.62)
    out = lowpass(out, 4000)
    return finish(out, "view", 3.0, 120.0)


def make_create():
    """Raising the mirror, ~2.8 s: a glass tone (A5) that, over the 0.8 s the
    pane rises like ice, blooms into a soft D minor add-9 chord, with a
    faint frosting hiss under the rise."""
    rng = np.random.default_rng(901)
    n = seconds(2.8)
    t = timeline(n)
    lead_env = swell(n, 0.0, 0.07, 0.0, 2.3) * np.exp(-t / 1.6)
    lead = glass(n, rng, hz("A5"), lead_env, beat=0.5)
    chord = np.zeros(n)
    for note, start, weight in (("D4", 0.12, 0.30), ("A4", 0.26, 0.24),
                                ("F4", 0.40, 0.20), ("E5", 0.55, 0.14)):
        env = swell(n, start, 0.42, 0.95 - start, 1.25)
        chord += glass(n, rng, hz(note), env, beat=0.35) * weight
    frost = bandpass(rng.standard_normal(n), 5000, 9500) * swell(n, 0.0, 0.6, 0.0, 0.35)
    out = lead * 0.42 + chord + frost * 0.018
    out = reverb(out, 902, decay=2.4, mix=0.38)
    return finish(out, "create", 3.0, 250.0)


def make_remove():
    """Lowering the mirror, ~1.8 s: the same glass and chord, resolving
    downward (E5 to D5 over a fading D and A) and settling."""
    rng = np.random.default_rng(1501)
    n = seconds(1.8)
    t = timeline(n)
    upper = glass(n, rng, hz("E5"), swell(n, 0.0, 0.03, 0.10, 0.30), beat=0.5)
    resolve_env = swell(n, 0.20, 0.10, 0.0, 1.3) * np.exp(-np.maximum(t - 0.2, 0) / 0.9)
    resolve = glass(n, rng, hz("D5"), resolve_env, beat=0.4)
    under = (glass(n, rng, hz("A3"), swell(n, 0.0, 0.05, 0.15, 0.9), beat=0.3) * 0.22
             + glass(n, rng, hz("D4"), swell(n, 0.0, 0.05, 0.25, 1.1), beat=0.3) * 0.18)
    out = upper * 0.32 + resolve * 0.40 + under
    out = reverb(out, 1502, decay=1.8, mix=0.34)
    return finish(out, "remove", 2.0, 200.0)


def make_confirm():
    """A change to the mirror applied in the classic editor, ~1.3 s: one
    soft glass bell on D5 with a faint fifth."""
    rng = np.random.default_rng(801)
    n = seconds(1.3)
    root = glass(n, rng, hz("D5"), strike(n, 0.0, 0.008, 0.38), mode_decay=0.25)
    fifth = glass(n, rng, hz("A5"), strike(n, 0.03, 0.010, 0.30), mode_decay=0.2)
    out = root + fifth * 0.3
    out = reverb(out, 802, decay=1.4, mix=0.3)
    return finish(out, "confirm", 1.5, 200.0)


def make_goal():
    """Reaching the goal, ~3.2 s: a small homecoming. A felt-piano D5 over a
    warm held D (with its octave below and a faint fifth), sustained
    through the 1.2 s of stillness and then released."""
    rng = np.random.default_rng(1001)
    n = seconds(3.2)
    piano = np.zeros(n)
    note = felt_piano(hz("D5"), 0.32, 3.0, rng)
    piano[:len(note)] += note
    held = (warm(n, rng, hz("D4"), swell(n, 0.0, 0.22, 1.05, 1.6)) * 0.36
            + warm(n, rng, hz("D3"), swell(n, 0.05, 0.35, 0.9, 1.7)) * 0.22
            + warm(n, rng, hz("A4"), swell(n, 0.25, 0.40, 0.6, 1.5)) * 0.10)
    held = lowpass(held, 2200)
    out = piano * 0.55 + held
    out = reverb(out, 1002, decay=2.6, mix=0.4)
    return finish(out, "goal", 3.0, 300.0)


def make_sweep():
    """Moving on to the next place (the 1.6 s camera travel while the next
    place grows), ~2.6 s: a soft, rising, airy wash with a faint high
    shimmer of glass. Kept under the name `sweep.wav`, which game.gd plays."""
    rng = np.random.default_rng(1101)
    n = seconds(2.6)
    t = timeline(n)

    def gain(time, f):
        x = np.clip(time / 1.9, 0, 1)
        ease = x * x * (3 - 2 * x)
        return (bump(f, 420 + 1500 * ease, 260 + 900 * ease)
                + 0.3 * bump(f, 180, 110))

    air = moving_band(rng, n, gain) * swell(n, 0.0, 1.45, 0.1, 1.05)
    air = lowpass(air, 5500)
    shimmer = np.zeros(n)
    for note, start, weight in (("D6", 0.65, 1.0), ("A6", 0.95, 0.7), ("E7", 1.25, 0.45)):
        env = swell(n, start, 0.45, 0.25, 1.1)
        tremolo = 0.75 + 0.25 * np.sin(2 * np.pi * 3.1 * t + rng.uniform(0, 2 * np.pi))
        shimmer += glass(n, rng, hz(note), env * tremolo, beat=1.1) * weight
    out = air * 0.8 + shimmer * 0.055
    out = reverb(out, 1102, decay=2.0, mix=0.3)
    return finish(out, "sweep", 5.0, 250.0)


def make_title_tap():
    """The tap on the title: one felt-piano note (D4), ~4.5 s with its room."""
    rng = np.random.default_rng(1601)
    n = seconds(4.5)
    out = np.zeros(n)
    note = felt_piano(hz("D4"), 0.5, 4.2, rng)
    out[:len(note)] += note
    out = reverb(out, 1602, decay=3.0, mix=0.45, damping=4000)
    return finish(out, "title_tap", 1.0, 600.0)


# --- ambient loop -------------------------------------------------------------------

# The distant motif: two phrases in D Dorian, a question and a softer answer,
# with most of the loop left to the wind. (time in s, note, velocity).
MOTIF = (
    (2.4, "A4", 0.40), (3.9, "F4", 0.32), (3.9, "D3", 0.22),
    (5.9, "E4", 0.30), (7.6, "D4", 0.34),
    (17.0, "C5", 0.34), (18.6, "A4", 0.30), (18.6, "F3", 0.20),
    (20.6, "G4", 0.26), (23.0, "E4", 0.28), (25.2, "D4", 0.30), (25.2, "A2", 0.18),
)


def gust_profile(t, period, rng):
    """A slow gust curve in 0..1 that repeats exactly every `period` s: a few
    sines at whole multiples of 1/period, shaped so gusts are occasional."""
    s = np.zeros_like(t)
    for k, weight in ((1, 1.0), (2, 0.6), (3, 0.45), (5, 0.3), (7, 0.18)):
        s += weight * np.sin(2 * np.pi * k * t / period + rng.uniform(0, 2 * np.pi))
    s = (s - s.min()) / (s.max() - s.min())
    return s ** 1.5


def make_wind(rng, n, xfade):
    """Winter wind for `n` samples plus `xfade` extra, whose gusts repeat every
    `n` samples; the caller crossfades the extra onto the start."""
    period = n / SR
    total = n + xfade
    grid = np.linspace(0, period, 2048)
    gusts = gust_profile(grid, period, rng)
    whistle = gust_profile(grid, period, rng)

    def gain(t, f):
        g = np.interp(t % period, grid, gusts)
        w = np.interp(t % period, grid, whistle)
        return ((0.35 + 0.65 * g) * bump(f, 230 + 260 * g, 170 + 110 * g)
                + (0.4 + 0.6 * g) * 0.45 * bump(f, 85, 55)
                + 0.18 * w * w * bump(f, 640 + 420 * w, 55 + 25 * w)
                + (0.3 + 0.7 * g) * 0.05 * bump(f, 3600, 1600))

    return moving_band(rng, total, gain)


def loop_crossfade(x, n, xfade):
    """Folds the `xfade` samples past the loop end onto the loop start with an
    equal-power crossfade, so sample n-1 runs straight on into sample 0."""
    out = x[:n].copy()
    phase = np.linspace(0, np.pi / 2, xfade)
    out[:xfade] = x[:xfade] * np.sin(phase) + x[n:n + xfade] * np.cos(phase)
    return out


def make_ambient_loop():
    """A seamless 32 s loop: winter wind with slow gusts and, far off, a
    sparse felt-piano motif.

    The gust curves repeat exactly over the loop, and the noise past the
    loop end is crossfaded onto the start (equal power: the two noise
    streams are uncorrelated). The piano and its long room are rendered past
    the loop end and that tail is added back onto the start, so a note near
    the end rings on across the seam."""
    rng = np.random.default_rng(1201)
    n = seconds(LOOP_SECONDS)
    xfade = seconds(2.0)
    wind = loop_crossfade(make_wind(rng, n, xfade), n, xfade)
    wind /= np.max(np.abs(wind))

    tail = seconds(7.0)
    piano = np.zeros(n + tail)
    piano_rng = np.random.default_rng(1202)
    for when, note, velocity in MOTIF:
        voice = felt_piano(hz(note), velocity, 6.0, piano_rng)
        start = seconds(when)
        piano[start:start + len(voice)] += voice
    piano = lowpass(piano, 2400)
    piano = reverb(piano, 1203, decay=4.5, mix=0.9, predelay=0.04, damping=3000)
    looped = piano[:n].copy()
    looped[:tail] += piano[n:]
    looped *= 0.3 / np.max(np.abs(looped))

    out = wind + looped
    out = out - np.mean(out)
    return out * (10 ** (PEAK_DB["ambient_loop"] / 20) / np.max(np.abs(out)))


SOUNDS = {
    "ui": make_ui,
    "swing": make_swing,
    "view": make_view,
    "create": make_create,
    "remove": make_remove,
    "confirm": make_confirm,
    "goal": make_goal,
    "sweep": make_sweep,
    "land": make_land,
    "title_tap": make_title_tap,
    "ambient_loop": make_ambient_loop,
}


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for index, seed in enumerate((401, 402, 403), start=1):
        write_wav(OUTPUT / f"step_{index}.wav", make_step(seed))
    for name, make in SOUNDS.items():
        write_wav(OUTPUT / f"{name}.wav", make())
