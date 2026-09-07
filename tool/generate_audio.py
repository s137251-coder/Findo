"""Generates Findo's music and sound effects.

    python tool/generate_audio.py

Everything is synthesised as raw PCM and written as WAV, so the pipeline needs
no encoder in the toolchain. Replace the output with composed music and
recorded effects when they exist; the file names in `assets/audio/` are what
`AudioManager` depends on, not this script.

Maps and the character sprite are generated separately, by
`tool/generate_maps.py`.
"""

from __future__ import annotations

import math
import random
import wave
from array import array
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio"

SAMPLE_RATE = 22050


# --------------------------------------------------------------------------
# audio
# --------------------------------------------------------------------------

def write_wav(path: Path, samples: list[float]) -> None:
    frames = array("h")
    peak = max((abs(s) for s in samples), default=1.0) or 1.0
    scale = 0.86 / peak
    for s in samples:
        frames.append(int(max(-1.0, min(1.0, s * scale)) * 32767))
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(frames.tobytes())


def envelope(i: int, n: int, attack: float, release: float) -> float:
    a = max(1, int(n * attack))
    r = max(1, int(n * release))
    if i < a:
        return i / a
    if i > n - r:
        return max(0.0, (n - i) / r)
    return 1.0


def tone(freq: float, seconds: float, *, gain=1.0, attack=0.02, release=0.35,
         harmonics=(1.0, 0.32, 0.12), vibrato=0.0, detune=0.0) -> list[float]:
    n = int(SAMPLE_RATE * seconds)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = freq * (1.0 + detune * t)
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * 5.5 * t)
        v = 0.0
        for k, amp in enumerate(harmonics, start=1):
            v += amp * math.sin(2 * math.pi * f * k * t)
        out.append(v * envelope(i, n, attack, release) * gain)
    return out


def noise_hit(seconds: float, cutoff: float, gain=1.0) -> list[float]:
    rnd = random.Random(7)
    n = int(SAMPLE_RATE * seconds)
    out, prev = [], 0.0
    alpha = cutoff / (cutoff + SAMPLE_RATE)
    for i in range(n):
        prev = prev + alpha * (rnd.uniform(-1, 1) - prev)
        out.append(prev * envelope(i, n, 0.01, 0.7) * gain)
    return out


def overlay(*layers: list[float]) -> list[float]:
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def sequence(parts: list[tuple[float, list[float]]]) -> list[float]:
    """parts: (start_seconds, samples)."""
    total = max(int(start * SAMPLE_RATE) + len(buf) for start, buf in parts)
    out = [0.0] * total
    for start, buf in parts:
        off = int(start * SAMPLE_RATE)
        for i, v in enumerate(buf):
            out[off + i] += v
    return out


NOTE = {"C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00,
        "A4": 440.00, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25,
        "G5": 783.99, "A5": 880.00, "C6": 1046.50, "A3": 220.00, "F3": 174.61,
        "G3": 196.00, "C3": 130.81}


def sfx_click() -> list[float]:
    return overlay(tone(880, 0.07, attack=0.01, release=0.8, harmonics=(1.0, 0.2)),
                   noise_hit(0.05, 4000, gain=0.25))


def sfx_found() -> list[float]:
    return sequence([(0.0, tone(NOTE["E5"], 0.16, harmonics=(1.0, 0.25, 0.1))),
                     (0.09, tone(NOTE["A5"], 0.26, gain=0.9))])


def sfx_misclick() -> list[float]:
    return overlay(tone(150, 0.26, harmonics=(1.0, 0.5, 0.35), detune=-0.28, release=0.5),
                   noise_hit(0.18, 900, gain=0.35))


def sfx_combo() -> list[float]:
    return sequence([(0.00, tone(NOTE["C5"], 0.13, gain=0.8)),
                     (0.07, tone(NOTE["E5"], 0.13, gain=0.8)),
                     (0.14, tone(NOTE["G5"], 0.15, gain=0.85)),
                     (0.21, tone(NOTE["C6"], 0.30, gain=0.9))])


def sfx_hint() -> list[float]:
    return overlay(tone(NOTE["C6"], 0.55, gain=0.5, attack=0.15, release=0.6, vibrato=0.012),
                   tone(NOTE["G5"], 0.55, gain=0.32, attack=0.2, release=0.6))


def sfx_win() -> list[float]:
    parts = []
    for i, note in enumerate(("C5", "E5", "G5", "C6")):
        parts.append((i * 0.13, tone(NOTE[note], 0.42, gain=0.75)))
    parts.append((0.52, tone(NOTE["C5"], 0.9, gain=0.45)))
    parts.append((0.52, tone(NOTE["E5"], 0.9, gain=0.38)))
    parts.append((0.52, tone(NOTE["G5"], 0.9, gain=0.34)))
    return sequence(parts)


def bgm_loop() -> list[float]:
    """A calm 16 second loop: four bars of pad plus a wandering lead."""
    bar = 4.0
    chords = [("C3", ("C4", "E4", "G4")), ("A3", ("A4", "C5", "E5")),
              ("F3", ("F4", "A4", "C5")), ("G3", ("G4", "B4", "D5"))]
    lead = [("E5", 0.0, 0.9), ("G5", 1.0, 0.7), ("C5", 2.0, 1.2), ("D5", 3.2, 0.6),
            ("A4", 4.2, 1.0), ("C5", 5.4, 0.8), ("E5", 6.4, 1.3),
            ("F4", 8.2, 1.0), ("A4", 9.4, 0.8), ("C5", 10.4, 1.2),
            ("D5", 12.2, 0.9), ("B4", 13.4, 0.7), ("G4", 14.4, 1.4)]
    parts = []
    for b, (bass, triad) in enumerate(chords):
        t0 = b * bar
        parts.append((t0, tone(NOTE[bass], bar * 0.98, gain=0.30, attack=0.12,
                               release=0.35, harmonics=(1.0, 0.18))))
        for note in triad:
            parts.append((t0 + 0.04, tone(NOTE[note], bar * 0.9, gain=0.13, attack=0.25,
                                          release=0.45, harmonics=(1.0, 0.1))))
    for note, at, dur in lead:
        parts.append((at, tone(NOTE[note], dur, gain=0.24, attack=0.08, release=0.5,
                               harmonics=(1.0, 0.22, 0.06))))
    return sequence(parts)


AUDIO_BUILDERS = {
    "click": sfx_click,
    "found": sfx_found,
    "misclick": sfx_misclick,
    "combo": sfx_combo,
    "hint": sfx_hint,
    "win": sfx_win,
    "bgm_main": bgm_loop,
}

def main() -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    for name, builder in AUDIO_BUILDERS.items():
        write_wav(AUDIO / f"{name}.wav", builder())
    print(f"audio: {len(AUDIO_BUILDERS)} files in {AUDIO.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
