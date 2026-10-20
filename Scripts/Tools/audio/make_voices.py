"""Spoken lines and vocal sounds (D275, D277, D278).

    python -I make_voices.py <downloads_dir> <repo_dir> <kokoro.onnx> <voices.bin>
needs a venv with kokoro-onnx (MIT) + its Kokoro-82M weights and voices (Apache 2.0), numpy, scipy, soundfile.
Lines are English (D277). Grunts and roars are cut from CC0 OpenGameArt recordings (README in each folder).
"""

import sys
from pathlib import Path

import numpy as np
from build_audio import SR, band, cut, fade, load, mix, pitch, reverb, save
from kokoro_onnx import Kokoro
from scipy.signal import resample_poly

# folder/name: (kokoro voice, speed, pitch factor, reverb share, lines)
LINES = {
    "Greetings/grandfather": (
        "bm_george",
        0.85,
        0.94,
        0.0,
        ["Ah, my boy.", "Welcome back."],
    ),
    "Greetings/blacksmith": (
        "am_onyx",
        0.95,
        0.92,
        0.0,
        ["Need steel?", "Back again?"],
    ),
    "Greetings/merchant": (
        "am_puck",
        1.05,
        1.0,
        0.0,
        ["Welcome, friend!", "Fine wares today!"],
    ),
    "Calls/guard": ("am_eric", 1.1, 1.0, 0.0, ["I've got you!", "Hold on!"]),
    "Calls/alisia": ("af_jessica", 1.1, 1.0, 0.0, ["Get them!", "Strike now!"]),
    "Calls/astrit": ("af_kore", 1.05, 0.95, 0.0, ["Out of my way!", "Shields up!"]),
    "Calls/urizen": ("bm_lewis", 1.0, 1.0, 0.15, ["Be blessed!", "Light, guide us!"]),
    "Hero/effort": ("am_liam", 1.2, 1.0, 0.0, ["Hah!", "Hyah!", "Hup!"]),
    "Boss/shout": ("am_onyx", 0.9, 0.72, 0.35, ["Kneel!", "You will burn!", "Enough!"]),
}


def tts(kokoro: Kokoro, voice: str, speed: float, text: str) -> np.ndarray:
    samples, sr = kokoro.create(text, voice=voice, speed=speed, lang="en-us")
    x = resample_poly(samples, SR, sr).astype(np.float32)
    # Kokoro pads with silence: trim to the voice.
    loud = np.flatnonzero(np.abs(x) > 0.02 * np.abs(x).max())
    return fade(x[max(loud[0] - 400, 0) : loud[-1] + 2000], 0.005, 0.04)


def segments(
    x: np.ndarray, threshold: float = 0.04, gap: float = 0.15
) -> list[tuple[int, int]]:
    """Vocal bursts in a long take, as (start, end) samples."""
    win = int(0.01 * SR)
    env = np.convolve(np.abs(x), np.ones(win) / win, "same")
    on = env > threshold * env.max()
    out, start, last = [], None, 0
    for i in np.flatnonzero(np.diff(on.astype(int)) != 0):
        if on[i + 1]:
            if start is None or (i - last) / SR > gap:
                if start is not None:
                    out.append((start, last))
                start = i
        else:
            last = i
    if start is not None:
        out.append((start, last))
    return [(a, b) for a, b in out if (b - a) / SR > 0.12]


def main(dl: Path, repo: Path, model: str, voices: str) -> None:
    voice_dir = repo / "SampleProject/Assets/Audio/Voice"
    kokoro = Kokoro(model, voices)
    for name, (voice, speed, factor, room, lines) in LINES.items():
        for i, text in enumerate(lines):
            x = tts(kokoro, voice, speed, text)
            if factor != 1.0:
                x = pitch(x, factor)
            if room:
                x = reverb(x, room, 1.4)
            save(x, voice_dir / f"{name}_{i}.ogg")

    # Bandits (and every human enemy): pain grunts and death cries cut from one take.
    take = load(dl / "dl_oga_grunts/grunts.wav")
    bursts = segments(take)
    short = [b for b in bursts if (b[1] - b[0]) / SR < 0.9][:6]
    long = [b for b in bursts if (b[1] - b[0]) / SR >= 1.0][:3]
    assert len(short) >= 4 and len(long) >= 2, (len(short), len(long))
    for i, (a, b) in enumerate(short):
        save(
            fade(take[max(a - 200, 0) : b + 2200], 0.004, 0.05),
            voice_dir / f"Enemy/grunt_{i}.ogg",
        )
    for i, (a, b) in enumerate(long):
        save(
            fade(take[max(a - 200, 0) : b + 4400], 0.004, 0.15),
            voice_dir / f"Enemy/death_{i}.ogg",
        )

    # The hero's pain and death: tinyworlds' "5 Hit Sounds + Dying".
    hits = dl / "dl_oga_hit5/x/ogg"
    for i in range(1, 6):
        save(load(hits / f"hit{i}.ogg"), voice_dir / f"Hero/hurt_{i - 1}.ogg")
    save(load(hits / "die1.ogg"), voice_dir / "Hero/death_0.ogg")

    # Bosses: a deep roar, pitched and layered with rubberduck's creature roars.
    roar = load(dl / "dl_oga_roar/roar.wav")
    creature = dl / "dl_oga_creature/x"
    for i in range(3):
        layer = pitch(load(creature / f"roar_0{i + 1}.ogg"), 0.8)
        body = pitch(cut(roar, 0.1, 3.2), [0.95, 0.85, 1.05][i])
        save(
            fade(mix((body, 0, 1.0), (layer, 0.05, 0.6)), 0.01, 0.6),
            voice_dir / f"Boss/roar_{i}.ogg",
        )
    death = pitch(cut(roar, 0.1, 5.2), 0.7)
    save(
        fade(reverb(band(death, None, 4000), 0.3, 1.8), 0.01, 1.0),
        voice_dir / "Boss/death_0.ogg",
    )
    print("voices built")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], sys.argv[4])
