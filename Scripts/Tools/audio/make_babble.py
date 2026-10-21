"""Dialogue babble blips, one timbre per character (D277): Undertale-style syllables played while text types.

Synthesised from scratch (harmonics shaped by vowel formants + a little noise) — no licence involved.
    python make_babble.py <repo_dir>
Writes SampleProject/Assets/Audio/Voice/Babble/<voice>_<n>.wav (22.05 kHz, 16-bit mono), BLIPS per voice.
"""

import sys
import wave
from pathlib import Path

import numpy as np

SR = 22050
BLIPS = 6
# Vowel formants (Hz) of an adult male voice; a voice's `formant` scales them (women, children, gnomes higher).
VOWELS = [
    (730, 1090, 2440),
    (530, 1840, 2480),
    (270, 2290, 3010),
    (570, 840, 2410),
    (300, 870, 2240),
    (660, 1720, 2410),
]

# voice: f0 Hz, formant scale, length s, noise (breath), buzz (0 = round, 1 = harsh), glide (pitch fall share),
# vibrato depth, chorus (extra detuned voices)
VOICES = {
    "kusakam": dict(
        f0=140,
        formant=1.0,
        length=0.07,
        noise=0.04,
        buzz=0.3,
        glide=0.06,
        vibrato=0.0,
        chorus=0,
    ),
    "grandfather": dict(
        f0=108,
        formant=0.93,
        length=0.09,
        noise=0.14,
        buzz=0.2,
        glide=0.1,
        vibrato=0.03,
        chorus=0,
    ),
    "blacksmith": dict(
        f0=88,
        formant=0.88,
        length=0.08,
        noise=0.05,
        buzz=0.6,
        glide=0.05,
        vibrato=0.0,
        chorus=0,
    ),
    "merchant": dict(
        f0=165,
        formant=1.04,
        length=0.055,
        noise=0.03,
        buzz=0.35,
        glide=-0.08,
        vibrato=0.0,
        chorus=0,
    ),
    "priest": dict(
        f0=118,
        formant=0.95,
        length=0.1,
        noise=0.03,
        buzz=0.05,
        glide=0.02,
        vibrato=0.02,
        chorus=0,
    ),
    "guard": dict(
        f0=100,
        formant=0.9,
        length=0.07,
        noise=0.04,
        buzz=0.5,
        glide=0.08,
        vibrato=0.0,
        chorus=0,
    ),
    "villager": dict(
        f0=150,
        formant=1.02,
        length=0.065,
        noise=0.05,
        buzz=0.3,
        glide=0.05,
        vibrato=0.0,
        chorus=0,
    ),
    "bandit": dict(
        f0=118,
        formant=0.95,
        length=0.06,
        noise=0.08,
        buzz=0.85,
        glide=0.12,
        vibrato=0.0,
        chorus=0,
    ),
    "bandit_leader": dict(
        f0=92,
        formant=0.9,
        length=0.075,
        noise=0.08,
        buzz=0.9,
        glide=0.1,
        vibrato=0.0,
        chorus=0,
    ),
    "enemy": dict(
        f0=82,
        formant=0.85,
        length=0.07,
        noise=0.12,
        buzz=1.0,
        glide=0.15,
        vibrato=0.0,
        chorus=0,
    ),
    "alisia": dict(
        f0=245,
        formant=1.18,
        length=0.06,
        noise=0.05,
        buzz=0.15,
        glide=-0.05,
        vibrato=0.0,
        chorus=0,
    ),
    "astrit": dict(
        f0=195,
        formant=1.1,
        length=0.07,
        noise=0.04,
        buzz=0.45,
        glide=0.06,
        vibrato=0.0,
        chorus=0,
    ),
    "urizen": dict(
        f0=125,
        formant=0.96,
        length=0.09,
        noise=0.03,
        buzz=0.1,
        glide=0.03,
        vibrato=0.015,
        chorus=0,
    ),
    "gnome": dict(
        f0=225,
        formant=1.25,
        length=0.05,
        noise=0.04,
        buzz=0.5,
        glide=-0.1,
        vibrato=0.0,
        chorus=0,
    ),
    "suan": dict(
        f0=210,
        formant=1.14,
        length=0.065,
        noise=0.06,
        buzz=0.2,
        glide=0.0,
        vibrato=0.02,
        chorus=0,
    ),
    "dark_priests": dict(
        f0=78,
        formant=0.82,
        length=0.11,
        noise=0.1,
        buzz=0.4,
        glide=0.04,
        vibrato=0.02,
        chorus=2,
    ),
    # Laboratory speakers (queue row 9 drafts): two bosses, the prisoner Malik, the djinn's host, the alchemist.
    "brass_collector": dict(
        f0=70,
        formant=0.8,
        length=0.1,
        noise=0.03,
        buzz=0.9,
        glide=0.0,
        vibrato=0.0,
        chorus=1,
    ),
    "fire_djinn": dict(
        f0=82,
        formant=0.85,
        length=0.1,
        noise=0.2,
        buzz=0.7,
        glide=0.12,
        vibrato=0.04,
        chorus=2,
    ),
    "malik": dict(
        f0=150,
        formant=1.02,
        length=0.06,
        noise=0.05,
        buzz=0.15,
        glide=-0.08,
        vibrato=0.03,
        chorus=0,
    ),
    "prisoner": dict(
        f0=118,
        formant=0.96,
        length=0.08,
        noise=0.22,
        buzz=0.1,
        glide=0.12,
        vibrato=0.0,
        chorus=0,
    ),
    "scientist": dict(
        f0=175,
        formant=1.06,
        length=0.05,
        noise=0.03,
        buzz=0.35,
        glide=0.03,
        vibrato=0.0,
        chorus=0,
    ),
}


def blip(v: dict, vowel: tuple, f0_scale: float) -> np.ndarray:
    n = int(v["length"] * SR)
    t = np.arange(n) / SR
    f0 = (
        v["f0"]
        * f0_scale
        * (1.0 - v["glide"] * t / v["length"])
        * (1.0 + v["vibrato"] * np.sin(2 * np.pi * 6 * t))
    )
    phase = 2 * np.pi * np.cumsum(f0) / SR
    formants = [f * v["formant"] for f in vowel]
    out = np.zeros(n)
    for k in range(1, int(4000 / v["f0"])):
        fk = k * v["f0"] * f0_scale
        # Each harmonic weighted by how close it sits to a formant; buzz keeps the high harmonics loud.
        gain = sum(
            np.exp(-(((fk - f) / (90 + 0.08 * f)) ** 2)) * w
            for f, w in zip(formants, (1.0, 0.6, 0.25))
        )
        gain += v["buzz"] * 0.35 / k
        out += gain * np.sin(k * phase)
    rng = np.random.default_rng(int(f0_scale * 1000))
    breath = np.convolve(rng.standard_normal(n), np.ones(8) / 8, "same")  # breath, not hiss: ~2.5 kHz low-pass
    out += v["noise"] * 2 * breath * np.abs(out).max()
    attack, release = int(0.006 * SR), int(0.4 * n)
    env = np.ones(n)
    env[:attack] = np.linspace(0, 1, attack)
    env[-release:] = np.linspace(1, 0, release) ** 2
    return out * env


def write(path: Path, x: np.ndarray) -> None:
    x = x / np.abs(x).max() * 0.8
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((x * 32767).astype("<i2").tobytes())


def main(repo: Path) -> None:
    out_dir = repo / "SampleProject/Assets/Audio/Voice/Babble"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, v in VOICES.items():
        for i in range(BLIPS):
            f0_scale = (
                1.0 + (i - BLIPS / 2) * 0.03
            )  # a little intonation between syllables
            x = blip(v, VOWELS[i % len(VOWELS)], f0_scale)
            for c in range(v["chorus"]):
                x = x + 0.7 * blip(
                    v,
                    VOWELS[(i + c + 1) % len(VOWELS)],
                    f0_scale * (1.0 + 0.02 * (c + 1)),
                )
            write(out_dir / f"{name}_{i}.wav", x)
    print("babble:", len(VOICES), "voices x", BLIPS)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
