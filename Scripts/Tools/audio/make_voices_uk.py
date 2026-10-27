"""Ukrainian NPC greetings (BACKLOG 31 part 3, design/localization_plan.md; English ones: make_voices.py, D277).

    python -I make_voices_uk.py <repo_dir> <uk_UA-ukrainian_tts-medium.onnx>
needs a venv with piper-tts (GPL-3.0 tool, only run here, not shipped), numpy, scipy, soundfile.
Voice: Piper `uk_UA-ukrainian_tts-medium` (rhasspy/piper-voices on huggingface, 22 kHz, three speakers: lada, mykyta,
tetiana); its MODEL_CARD: dataset OHF-Voice/voice-datasets, licence CC0, trained from scratch; the model repo is MIT
(README in Assets/Audio/Voice). The men speak with mykyta, the women with lada or tetiana; pitch only shades a voice.
"""

import sys
from pathlib import Path

import numpy as np
from build_audio import SR, fade, pitch, reverb, save
from piper import PiperVoice, SynthesisConfig
from scipy.signal import resample_poly

SPEAKERS = {"lada": 0, "mykyta": 1, "tetiana": 2}
# name: (speaker, length scale (<1 = faster), pitch factor, reverb share, lines) — the same moods as make_voices.py
LINES = {
    "grandfather": ("mykyta", 1.05, 0.9, 0.0, ["Ах, мій хлопче.", "З поверненням."]),
    "blacksmith": ("mykyta", 0.95, 0.86, 0.0, ["Потрібна сталь?", "Знову ти?"]),
    "merchant": ("mykyta", 0.9, 1.0, 0.0, ["Вітаю, друже!", "Гарний крам сьогодні!"]),
    "oath_priest": ("tetiana", 1.0, 1.0, 0.15, ["Небо бачить тебе.", "Мир тобі, мандрівнику."]),
    "oath_witch": ("lada", 1.05, 0.95, 0.0, ["Ну-ну...", "Шукаєш сили?"]),
    "oath_dervish": ("mykyta", 0.95, 0.93, 0.0, ["Спокійно, дитино.", "Рівновага — завжди."]),
}


def tts(voice: PiperVoice, speaker: str, length_scale: float, text: str) -> np.ndarray:
    chunks = voice.synthesize(text, SynthesisConfig(speaker_id=SPEAKERS[speaker], length_scale=length_scale))
    samples = np.concatenate([c.audio_float_array for c in chunks])
    x = resample_poly(samples, SR, voice.config.sample_rate).astype(np.float32)
    # Piper pads with silence: trim to the voice.
    loud = np.flatnonzero(np.abs(x) > 0.02 * np.abs(x).max())
    return fade(x[max(loud[0] - 400, 0) : loud[-1] + 2000], 0.005, 0.04)


def main(repo: Path, model: str) -> None:
    out = repo / "SampleProject/Assets/Audio/Voice/Greetings/uk"
    voice = PiperVoice.load(model)
    for name, (speaker, length_scale, factor, room, lines) in LINES.items():
        for i, text in enumerate(lines):
            x = tts(voice, speaker, length_scale, text)
            if factor != 1.0:
                x = pitch(x, factor)
            if room:
                x = reverb(x, room, 1.4)
            save(x, out / f"{name}_{i}.ogg")
    print("uk greetings built")


if __name__ == "__main__":
    main(Path(sys.argv[1]), sys.argv[2])
