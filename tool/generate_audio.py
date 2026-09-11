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



def glide(f0: float, f1: float, seconds: float, *, gain=1.0, attack=0.02,
          release=0.4, harmonics=(1.0, 0.3, 0.12), wobble=0.0) -> list[float]:
    """A tone that slides from one pitch to another -- the slide-whistle shape
    every cartoon uses for a pratfall or a reveal."""
    n = int(seconds * SAMPLE_RATE)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = f0 * (f1 / f0) ** t
        if wobble:
            freq *= 1.0 + wobble * math.sin(2 * math.pi * 5.5 * i / SAMPLE_RATE)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        value = sum(h * math.sin(phase * (k + 1)) for k, h in enumerate(harmonics))
        out[i] = value * envelope(i, n, attack, release) * gain
    return out


def voice(freq: float, seconds: float, vowels, *, gain=1.0, attack=0.03,
          release=0.35) -> list[float]:
    """A cartoon voice: a buzzy vocal-cord source shaped by two moving formant
    peaks. Not speech -- nothing synthesised from scratch is -- but it lands in
    the same family as the wah-wah trombone that stands in for a voice in
    cartoons, and it reads as a character rather than a beep.

    `vowels` is a list of (formant1, formant2) pairs the sound morphs through.
    """
    n = int(seconds * SAMPLE_RATE)
    out = [0.0] * n
    phase = 0.0
    # Two resonators, updated with a simple one-pole-per-sample sweep.
    b1 = b2 = 0.0
    for i in range(n):
        t = i / max(1, n - 1)
        span = t * (len(vowels) - 1)
        k = min(int(span), len(vowels) - 2)
        frac = span - k
        f1 = vowels[k][0] + (vowels[k + 1][0] - vowels[k][0]) * frac
        f2 = vowels[k][1] + (vowels[k + 1][1] - vowels[k][1]) * frac

        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 2 * math.pi:
            phase -= 2 * math.pi
        # Sawtooth source: rich enough for formants to have something to bite.
        source = 1.0 - phase / math.pi
        # Each formant is a resonant peak; a leaky integrator approximates one.
        a1 = math.exp(-2 * math.pi * 90 / SAMPLE_RATE)
        a2 = math.exp(-2 * math.pi * 120 / SAMPLE_RATE)
        b1 = a1 * b1 + (1 - a1) * source * math.cos(2 * math.pi * f1 * i / SAMPLE_RATE)
        b2 = a2 * b2 + (1 - a2) * source * math.cos(2 * math.pi * f2 * i / SAMPLE_RATE)
        out[i] = (b1 * 1.6 + b2 * 1.1) * envelope(i, n, attack, release) * gain
    return out


def sfx_click() -> list[float]:
    return overlay(tone(880, 0.07, attack=0.01, release=0.8, harmonics=(1.0, 0.2)),
                   noise_hit(0.05, 4000, gain=0.25))


def sfx_found() -> list[float]:
    """A pleased little "ta-daa": two rising notes with a voice on top."""
    return sequence([
        (0.00, tone(NOTE["E5"], 0.16, harmonics=(1.0, 0.25, 0.1))),
        (0.09, tone(NOTE["A5"], 0.26, gain=0.9)),
        (0.06, voice(330, 0.34, [(720, 1240), (390, 1980)], gain=0.5)),
        (0.10, glide(700, 1500, 0.28, gain=0.16, harmonics=(1.0, 0.12))),
    ])


def sfx_misclick() -> list[float]:
    """The wrong person. A deflating "wah-waaah" rather than a buzzer: the
    penalty is already 15 points and 3 seconds, so the sound should tease
    rather than scold."""
    return sequence([
        (0.00, voice(196, 0.20, [(660, 1100), (520, 940)], gain=0.62)),
        (0.18, voice(155, 0.42, [(600, 1020), (430, 820)], gain=0.58, release=0.6)),
        (0.00, glide(260, 150, 0.55, gain=0.20, harmonics=(1.0, 0.45, 0.2))),
        (0.02, noise_hit(0.09, 700, gain=0.14)),
    ])


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


THEMES = {
    # name:   (bar seconds, chord roots, triads, lead notes, timbre, pulse)
    "bright": (3.2,
               ["C3", "A3", "F3", "G3"],
               [("C4", "E4", "G4"), ("A4", "C5", "E5"),
                ("F4", "A4", "C5"), ("G4", "B4", "D5")],
               ["E5", "G5", "A5", "G5", "E5", "D5", "E5", "G5"],
               (1.0, 0.30, 0.12), True),
    "rustic": (3.6,
               ["G3", "C3", "G3", "F3"],
               [("G4", "B4", "D5"), ("C4", "E4", "G4"),
                ("G4", "B4", "D5"), ("F4", "A4", "C5")],
               ["D5", "E5", "G5", "E5", "D5", "C5", "D5", "B4"],
               (1.0, 0.22, 0.30), True),
    "breezy": (4.4,
               ["F3", "C3", "A3", "F3"],
               [("F4", "A4", "C5"), ("C4", "E4", "G4"),
                ("A4", "C5", "E5"), ("F4", "A4", "C5")],
               ["C5", "A4", "F4", "G4", "A4", "C5", "A4", "G4"],
               (1.0, 0.14), False),
    "busy":   (2.6,
               ["A3", "F3", "C3", "G3"],
               [("A4", "C5", "E5"), ("F4", "A4", "C5"),
                ("C4", "E4", "G4"), ("G4", "B4", "D5")],
               ["A4", "C5", "E5", "C5", "A4", "B4", "D5", "B4"],
               (1.0, 0.34, 0.18, 0.08), True),
    "frost":  (4.8,
               ["C3", "G3", "A3", "F3"],
               [("C4", "E4", "G4"), ("G4", "B4", "D5"),
                ("A4", "C5", "E5"), ("F4", "A4", "C5")],
               ["C6", "G5", "E5", "G5", "A5", "E5", "C6", "G5"],
               (1.0, 0.08, 0.04), False),
    "dusk":   (4.0,
               ["A3", "F3", "C3", "G3"],
               [("A4", "C5", "E5"), ("F4", "A4", "C5"),
                ("C4", "E4", "G4"), ("G4", "B4", "D5")],
               ["E5", "D5", "C5", "A4", "C5", "E5", "D5", "B4"],
               (1.0, 0.26, 0.10), False),
}


def bgm_loop(theme: str = "bright") -> list[float]:
    """One looping track. Twenty-five levels sharing a single piece of music is
    what made the old one wear out; each scene family gets its own instead.

    The shape is the same in every theme -- four bars of bass, triad pad and a
    lead line -- so they sit together as one soundtrack rather than six
    unrelated pieces. What changes is key, tempo, timbre and whether a soft
    pulse keeps time underneath.
    """
    bar, roots, triads, lead, timbre, pulse = THEMES[theme]
    parts = []
    for b, (bass, triad) in enumerate(zip(roots, triads)):
        t0 = b * bar
        parts.append((t0, tone(NOTE[bass], bar * 0.98, gain=0.28, attack=0.12,
                               release=0.35, harmonics=(1.0, 0.18))))
        for note in triad:
            parts.append((t0 + 0.04, tone(NOTE[note], bar * 0.9, gain=0.12,
                                          attack=0.25, release=0.45,
                                          harmonics=(1.0, 0.1))))
        if pulse:
            for beat in range(4):
                parts.append((t0 + beat * bar / 4,
                              noise_hit(0.05, 2600, gain=0.05)))

    # The lead walks across the whole loop, two notes to a bar.
    step = bar / 2
    for i, note in enumerate(lead):
        parts.append((i * step, tone(NOTE[note], step * 0.85, gain=0.22,
                                     attack=0.08, release=0.5,
                                     harmonics=timbre)))
    return sequence(parts)


def sfx_peek() -> list[float]:
    """A cartoon slide whistle, for opening Findo's character sheet.

    Up fast, down slower, with a wobble at the bottom. The detune argument
    sweeps the frequency across the note rather than holding it, which is what
    makes a whistle read as a slide rather than a beep.
    """
    return sequence([
        (0.00, tone(420, 0.26, gain=0.75, attack=0.03, release=0.15,
                    harmonics=(1.0, 0.06), detune=6.9)),
        (0.24, tone(1180, 0.30, gain=0.75, attack=0.02, release=0.25,
                    harmonics=(1.0, 0.06), detune=-2.1)),
        (0.52, tone(520, 0.22, gain=0.55, attack=0.02, release=0.6,
                    harmonics=(1.0, 0.2), vibrato=0.045)),
    ])


def sfx_star() -> list[float]:
    """One bright ping. The win panel plays it once per star, and the caller
    pitches later stars up by playing them in sequence."""
    return overlay(
        tone(NOTE["E5"], 0.30, gain=0.7, attack=0.005, release=0.85,
             harmonics=(1.0, 0.45, 0.2)),
        tone(NOTE["B4"], 0.30, gain=0.28, attack=0.005, release=0.85),
    )


def sfx_swoosh() -> list[float]:
    """A short, quiet breath under a screen change. Deliberately faint: this
    plays on navigation, and anything with character here grates within
    minutes of ordinary play."""
    n = int(SAMPLE_RATE * 0.20)
    rnd = random.Random(19)
    out, prev = [], 0.0
    for i in range(n):
        t = i / n
        # Sweep the filter open then shut, which reads as movement.
        cutoff = 900 + 2600 * math.sin(math.pi * t)
        alpha = cutoff / (cutoff + SAMPLE_RATE)
        prev = prev + alpha * (rnd.uniform(-1, 1) - prev)
        out.append(prev * envelope(i, n, 0.18, 0.55) * 0.30)
    return out


AUDIO_BUILDERS = {
    "click": sfx_click,
    "found": sfx_found,
    "misclick": sfx_misclick,
    "combo": sfx_combo,
    "hint": sfx_hint,
    "win": sfx_win,
    "star": sfx_star,
    "peek": sfx_peek,
    "swoosh": sfx_swoosh,
    # bgm_main stays as the fallback AudioManager uses when a level names a
    # theme that is not shipped, so the game is never silent by accident.
    "bgm_main": lambda: bgm_loop("bright"),
    **{f"bgm_{name}": (lambda n=name: bgm_loop(n)) for name in THEMES},
}

def main() -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    for name, builder in AUDIO_BUILDERS.items():
        write_wav(AUDIO / f"{name}.wav", builder())
    print(f"audio: {len(AUDIO_BUILDERS)} files in {AUDIO.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
