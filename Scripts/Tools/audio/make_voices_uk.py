"""Ukrainian NPC greetings (BACKLOG 31 part 3, design/localization_plan.md; English ones: make_voices.py, D277).

    python -I make_voices_uk.py <repo_dir> <uk-lada-x-low.onnx>
needs a venv with piper-tts (GPL-3.0 tool, only run here, not shipped), numpy, scipy, soundfile.
Voice: Piper "lada" x-low (rhasspy, voice-uk-lada-x-low.tar.gz from the piper v0.0.2 release) — its MODEL_CARD:
dataset egorsmkv/ukrainian-tts-datasets/lada, licence Apache 2.0, trained from scratch. The only Ukrainian
Piper voice whose card could be read from this environment (README in Assets/Audio/Voice).
One female speaker: men are pitched down tape-style (pitch() also slows), so their lines are spoken faster.
"""

import sys
from pathlib import Path

import numpy as np
from build_audio import SR, fade, pitch, reverb, save
from piper import PiperVoice, SynthesisConfig
from scipy.signal import resample_poly

# name: (length scale (<1 = faster), pitch factor, reverb share, lines) — the same moods as make_voices.py
LINES = {
    "grandfather": (0.95, 0.78, 0.0, ["Ах, мій хлопче.", "З поверненням."]),
    "blacksmith": (0.8, 0.74, 0.0, ["Потрібна сталь?", "Знову ти?"]),
    "merchant": (0.8, 0.84, 0.0, ["Вітаю, друже!", "Гарний крам сьогодні!"]),
    "oath_priest": (1.0, 1.0, 0.15, ["Небо бачить тебе.", "Мир тобі, мандрівнику."]),
    "oath_witch": (1.05, 0.92, 0.0, ["Ну-ну...", "Шукаєш сили?"]),
    "oath_dervish": (0.85, 0.8, 0.0, ["Спокійно, дитино.", "Рівновага — завжди."]),
}


def tts(voice: PiperVoice, length_scale: float, text: str) -> np.ndarray:
    chunks = voice.synthesize(text, SynthesisConfig(length_scale=length_scale))
    samples = np.concatenate([c.audio_float_array for c in chunks])
    x = resample_poly(samples, SR, voice.config.sample_rate).astype(np.float32)
    # Piper pads with silence: trim to the voice.
    loud = np.flatnonzero(np.abs(x) > 0.02 * np.abs(x).max())
    return fade(x[max(loud[0] - 400, 0) : loud[-1] + 2000], 0.005, 0.04)


def main(repo: Path, model: str) -> None:
    out = repo / "SampleProject/Assets/Audio/Voice/Greetings/uk"
    voice = PiperVoice.load(model)
    for name, (length_scale, factor, room, lines) in LINES.items():
        for i, text in enumerate(lines):
            x = tts(voice, length_scale, text)
            if factor != 1.0:
                x = pitch(x, factor)
            if room:
                x = reverb(x, room, 1.4)
            save(x, out / f"{name}_{i}.ogg")
    print("uk greetings built")


if __name__ == "__main__":
    main(Path(sys.argv[1]), sys.argv[2])
