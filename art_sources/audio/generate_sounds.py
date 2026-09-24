#!/usr/bin/env python3
"""Build deterministic procedural sound effects and the ambient loop.

Requires NumPy; writes 16-bit PCM WAV with the standard library `wave`
module. Run from the project root:

    python3 art_sources/audio/generate_sounds.py

Every sound uses fixed parameters and a fixed random seed, so two runs
produce byte-identical files.
"""
from pathlib import Path
import wave

import numpy as np

SR = 44100
OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "audio"

# Peak targets. Most effects sit at -6 dBFS. `step` is deliberately quieter
# than the general target because it plays on every footstep and must not
# tire the ear (the brief calls this out as "low level"). The loop sits at
# -14 dBFS per the brief.
EFFECT_PEAK_DB = -6.0
STEP_PEAK_DB = -16.0
LOOP_PEAK_DB = -14.0


# --- small DSP building blocks -------------------------------------------------

def band_noise(rng, n, sr, center, bandwidth):
    """White noise shaped by a Gaussian gain bump in the frequency domain."""
    white = rng.standard_normal(n)
    spectrum = np.fft.rfft(white)
    freqs = np.fft.rfftfreq(n, 1 / sr)
    gain = np.exp(-0.5 * ((freqs - center) / bandwidth) ** 2)
    shaped = np.fft.irfft(spectrum * gain, n)
    peak = np.max(np.abs(shaped))
    return shaped / peak if peak > 1e-9 else shaped


def ad_envelope(n, sr, attack_ms, decay_s):
    """Attack/decay envelope: soft rise, exponential fall. Peaks at 1."""
    t = np.arange(n) / sr
    attack = max(attack_ms / 1000, 1e-4)
    env = (1 - np.exp(-t / attack)) * np.exp(-t / decay_s)
    peak = np.max(env)
    return env / peak if peak > 1e-9 else env


def gesture_envelope(n, rising):
    """Raised-cosine attack/release shape that starts and ends at zero."""
    if rising:
        attack_frac, release_frac = 0.28, 0.72
    else:
        attack_frac, release_frac = 0.08, 0.92
    attack_n = max(1, int(n * attack_frac))
    release_n = n - attack_n
    env = np.ones(n)
    env[:attack_n] = 0.5 * (1 - np.cos(np.pi * np.arange(attack_n) / attack_n))
    if release_n > 0:
        env[attack_n:] = 0.5 * (1 + np.cos(np.pi * np.arange(release_n) / release_n))
    return env


def additive_tone(rng, n, sr, fundamental, partials, tau_base, tau_falloff, attack_ms=3.0):
    """Sum of decaying partials. Higher ratios decay faster (bell/chime damping)."""
    t = np.arange(n) / sr
    out = np.zeros(n)
    for ratio, weight in partials:
        detune = 1 + rng.uniform(-0.002, 0.002)
        freq = fundamental * ratio * detune
        tau = tau_base / (ratio ** tau_falloff)
        env = ad_envelope(n, sr, attack_ms, tau)
        out += weight * np.sin(2 * np.pi * freq * t) * env
    return out


def shimmer(rng, n, sr, dur, f0, f1):
    """Inharmonic partials chirping from f0 to f1, plus a little airy noise."""
    t = np.arange(n) / sr
    ratios = (1.0, 1.5, 2.0, 2.66, 3.5)
    out = np.zeros(n)
    for ratio in ratios:
        detune = 1 + rng.uniform(-0.004, 0.004)
        r0, r1 = f0 * ratio * detune, f1 * ratio * detune
        phase = 2 * np.pi * (r0 * t + (r1 - r0) / (2 * dur) * t ** 2)
        out += np.sin(phase) / len(ratios)
    air = band_noise(rng, n, sr, (f0 + f1), 2500) * 0.25
    return out * 0.8 + air * 0.4


def remove_dc(x):
    return x - np.mean(x, axis=0)


def apply_fades(x, sr, fade_in_ms, fade_out_ms):
    """Short linear fades at both ends so truncation never clicks."""
    x = x.copy()
    fade_in = int(sr * fade_in_ms / 1000)
    fade_out = int(sr * fade_out_ms / 1000)
    if fade_in > 0:
        x[:fade_in] *= np.linspace(0, 1, fade_in)
    if fade_out > 0:
        x[-fade_out:] *= np.linspace(1, 0, fade_out)
    return x


def peak_normalize(x, target_db):
    peak = np.max(np.abs(x))
    if peak < 1e-9:
        return x
    return x * (10 ** (target_db / 20) / peak)


def write_wav(path, sr, data):
    data = np.clip(data, -1.0, 1.0)
    channels = 1 if data.ndim == 1 else data.shape[1]
    samples = (data * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as f:
        f.setnchannels(channels)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes(samples.tobytes())


# --- effects --------------------------------------------------------------------

def make_step(seed):
    """A very soft ceramic tap, ~60 ms. `seed` gives each variant its own jitter."""
    rng = np.random.default_rng(seed)
    n = int(0.06 * SR)
    pitch = rng.uniform(0.9, 1.12)
    tap = band_noise(rng, n, SR, 2300 * pitch, 850) * ad_envelope(n, SR, 0.5, 0.012)
    ring_freq = 3100 * pitch * rng.uniform(0.97, 1.03)
    t = np.arange(n) / SR
    ring = np.sin(2 * np.pi * ring_freq * t) * ad_envelope(n, SR, 0.5, 0.009)
    out = 0.75 * tap + 0.35 * ring
    out = remove_dc(out)
    out = apply_fades(out, SR, 1.0, 6.0)
    return peak_normalize(out, STEP_PEAK_DB)


def make_ui():
    """A soft click, ~40 ms."""
    rng = np.random.default_rng(601)
    n = int(0.04 * SR)
    click = band_noise(rng, n, SR, 3200, 1400) * ad_envelope(n, SR, 0.3, 0.006)
    body = band_noise(rng, n, SR, 650, 300) * ad_envelope(n, SR, 0.5, 0.010) * 0.4
    out = click * 0.8 + body
    out = remove_dc(out)
    out = apply_fades(out, SR, 0.5, 6.0)
    return peak_normalize(out, EFFECT_PEAK_DB)


def make_land():
    """A muffled soft thud, ~0.25 s."""
    rng = np.random.default_rng(701)
    n = int(0.25 * SR)
    thump = band_noise(rng, n, SR, 140, 55) * ad_envelope(n, SR, 1.5, 0.06)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 95 * t) * ad_envelope(n, SR, 1.0, 0.05) * 0.5
    out = thump * 0.8 + body
    out = remove_dc(out)
    out = apply_fades(out, SR, 1.0, 25.0)
    return peak_normalize(out, EFFECT_PEAK_DB)


def make_create():
    """A glass shimmer rising, ~0.5 s."""
    rng = np.random.default_rng(901)
    dur = 0.5
    n = int(dur * SR)
    raw = shimmer(rng, n, SR, dur, 700, 2400)
    out = raw * gesture_envelope(n, rising=True)
    out = remove_dc(out)
    out = apply_fades(out, SR, 2.0, 3.0)
    return peak_normalize(out, EFFECT_PEAK_DB)


def make_remove():
    """A reverse shimmer falling, ~0.5 s. Mirrors `create` (swapped sweep, envelope)."""
    rng = np.random.default_rng(902)
    dur = 0.5
    n = int(dur * SR)
    raw = shimmer(rng, n, SR, dur, 2400, 700)
    out = raw * gesture_envelope(n, rising=False)
    out = remove_dc(out)
    out = apply_fades(out, SR, 2.0, 5.0)
    return peak_normalize(out, EFFECT_PEAK_DB)


def make_confirm():
    """A settling glass chime, ~0.6 s. Bright, slightly inharmonic partials."""
    rng = np.random.default_rng(801)
    dur = 0.6
    n = int(dur * SR)
    partials = [(1.0, 1.0), (2.0, 0.55), (2.76, 0.4), (3.0, 0.3), (4.07, 0.22), (5.4, 0.12)]
    out = additive_tone(rng, n, SR, fundamental=740.0, partials=partials, tau_base=0.35, tau_falloff=1.1)
    out = remove_dc(out)
    out = apply_fades(out, SR, 2.0, 150.0)
    return peak_normalize(out, EFFECT_PEAK_DB)


def make_goal():
    """A warm two-note chime, ~1.2 s. Harmonic partials, softer top end than confirm."""
    rng = np.random.default_rng(1001)
    dur = 1.2
    n = int(dur * SR)
    partials = [(1.0, 1.0), (2.0, 0.5), (3.0, 0.22), (4.0, 0.10)]
    note1 = additive_tone(rng, n, SR, fundamental=523.25, partials=partials, tau_base=0.35, tau_falloff=1.6, attack_ms=4)
    note2 = additive_tone(rng, n, SR, fundamental=784.00, partials=partials, tau_base=0.35, tau_falloff=1.6, attack_ms=4)
    delay = int(0.32 * SR)
    out = note1.copy()
    out[delay:] += note2[: n - delay]
    out = remove_dc(out)
    out = apply_fades(out, SR, 2.0, 100.0)
    return peak_normalize(out, EFFECT_PEAK_DB)


def make_sweep():
    """A soft airy glass sweep, ~1.7 s, matching the 1.7 s stage sweep."""
    rng = np.random.default_rng(1101)
    dur = 1.7
    n = int(dur * SR)
    block, hop = 4096, 1024
    padded = n + block
    noise = rng.standard_normal(padded)
    window = np.hanning(block)
    out = np.zeros(padded)
    for start in range(0, padded - block, hop):
        frac = np.clip((start + block / 2) / SR / dur, 0, 1)
        center = 1100 + (3200 - 1100) * frac
        segment = noise[start:start + block] * window
        spectrum = np.fft.rfft(segment)
        freqs = np.fft.rfftfreq(block, 1 / SR)
        gain = np.exp(-0.5 * ((freqs - center) / 900) ** 2)
        out[start:start + block] += np.fft.irfft(spectrum * gain, block)
    out = out[:n]
    peak = np.max(np.abs(out))
    if peak > 1e-9:
        out = out / peak

    # A few sparse high glints for a glassy sparkle.
    glints = np.zeros(n)
    for glow_time in sorted(rng.uniform(0.15, dur - 0.2, size=5)):
        start = int(glow_time * SR)
        length = int(0.15 * SR)
        if start + length > n:
            continue
        freq = rng.uniform(2800, 4200)
        t = np.arange(length) / SR
        glints[start:start + length] += np.sin(2 * np.pi * freq * t) * ad_envelope(length, SR, 1.0, 0.05) * 0.3

    out = out * 0.85 + glints
    attack_n, release_n = int(0.18 * n), int(0.28 * n)
    env = np.ones(n)
    env[:attack_n] = 0.5 * (1 - np.cos(np.pi * np.arange(attack_n) / attack_n))
    env[n - release_n:] = 0.5 * (1 + np.cos(np.pi * np.arange(release_n) / release_n))
    out = out * env
    out = remove_dc(out)
    out = apply_fades(out, SR, 3.0, 5.0)
    return peak_normalize(out, EFFECT_PEAK_DB)


# --- ambient loop -----------------------------------------------------------------

def make_ambient_loop():
    """A seamless 30 s calm pad loop.

    Every oscillator frequency is quantised to an exact multiple of 1/duration,
    so each tone completes a whole number of cycles inside the loop and is
    phase-continuous across the seam. Chord envelopes use a circular (wrapped)
    window, so they are also periodic across the seam. The result loops without
    a click by construction, with no crossfade needed.

    Mixed down to mono: stereo at 44.1 kHz/16-bit for 30 s is 5.3 MB, over the
    3 MB budget for this asset. Mono fits at 2.6 MB. The two detuned voices
    per note still give a soft chorus width even after the mixdown.
    """
    n = int(30.0 * SR)
    dur = n / SR
    unit = 1.0 / dur
    t = np.arange(n) / SR

    def quantize(freq):
        return max(1, round(freq / unit)) * unit

    # A gentle i-VI-III-VII modal progression (Am7 - Fmaj7 - Cmaj7 - G6).
    chords = [
        (110.00, 130.81, 164.81, 196.00),
        (87.31, 110.00, 130.81, 164.81),
        (130.81, 164.81, 196.00, 246.94),
        (98.00, 123.47, 146.83, 164.81),
    ]
    weights = (1.0, 0.72, 0.56, 0.42)
    slot_width = dur / len(chords)
    window_width = slot_width * 1.9

    def circular_window(center):
        distance = np.abs(((t - center + dur / 2) % dur) - dur / 2)
        x = np.clip(distance / (window_width / 2), 0, 1)
        return 0.5 * (1 + np.cos(np.pi * x))

    rng = np.random.default_rng(1201)
    left = np.zeros(n)
    right = np.zeros(n)
    for i, chord in enumerate(chords):
        win = circular_window((i + 0.5) * slot_width)
        for note_freq, weight in zip(chord, weights):
            for detune_cents, gain_left, gain_right in ((0.0, 1.0, 0.85), (2.5, 0.85, 1.0)):
                freq = quantize(note_freq * (2 ** (detune_cents / 1200)))
                phase = rng.uniform(0, 2 * np.pi)
                sine = np.sin(2 * np.pi * freq * t + phase)
                triangle = 2 / np.pi * np.arcsin(sine)
                voice = (0.7 * sine + 0.3 * triangle) * weight * win * 0.5
                left += voice * gain_left
                right += voice * gain_right

    mono = (left + right) / 2
    mono = remove_dc(mono)
    return peak_normalize(mono, LOOP_PEAK_DB)


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for index, seed in enumerate((401, 402, 403), start=1):
        write_wav(OUTPUT / f"step_{index}.wav", SR, make_step(seed))
    write_wav(OUTPUT / "ui.wav", SR, make_ui())
    write_wav(OUTPUT / "create.wav", SR, make_create())
    write_wav(OUTPUT / "confirm.wav", SR, make_confirm())
    write_wav(OUTPUT / "remove.wav", SR, make_remove())
    write_wav(OUTPUT / "goal.wav", SR, make_goal())
    write_wav(OUTPUT / "sweep.wav", SR, make_sweep())
    write_wav(OUTPUT / "land.wav", SR, make_land())
    write_wav(OUTPUT / "ambient_loop.wav", SR, make_ambient_loop())
