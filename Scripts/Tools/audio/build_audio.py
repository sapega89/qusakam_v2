"""Builds the game's sound files from downloaded CC0 packs (BACKLOG 26, audio_plan.md, D275).

Usage (a venv with numpy, scipy, soundfile):
    python -I build_audio.py <downloads_dir> <repo_dir> <stage> [<stage> ...]
Stages: combat, world, voices.

<downloads_dir> holds one folder per downloaded archive, unpacked into `x/` (names below, URLs in the
README of each Assets/Audio/<category>/). Kenney's Impact Sounds and RPG Audio are read from the repo's
local `assets/kenney_*` copies (not in git). Only the files the game uses are written.
"""

import shutil
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt

SR = 44100


def load(path: Path) -> np.ndarray:
    """Mono float32 at SR."""
    x, sr = sf.read(str(path), always_2d=True, dtype="float32")
    x = x.mean(axis=1)
    if sr != SR:
        x = resample_poly(x, SR, sr).astype(np.float32)
    return x


def save(x: np.ndarray, path: Path, peak: float = 0.89) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    m = float(np.abs(x).max())
    assert m > 0.0, f"silent output {path}"
    y = (x / m * peak).astype(np.float32)
    # libsndfile's Vorbis encoder crashes on one large write — feed it in blocks.
    with sf.SoundFile(str(path), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(y), SR // 4):
            f.write(y[i : i + SR // 4])


def fade(x: np.ndarray, fade_in: float, fade_out: float) -> np.ndarray:
    x = x.copy()
    a, b = int(fade_in * SR), int(fade_out * SR)
    if a:
        x[:a] *= np.linspace(0.0, 1.0, a)
    if b:
        x[-b:] *= np.linspace(1.0, 0.0, b)
    return x


def cut(x: np.ndarray, start: float, length: float) -> np.ndarray:
    return x[int(start * SR) : int((start + length) * SR)]


def pitch(x: np.ndarray, factor: float) -> np.ndarray:
    """Resample-style pitch shift (also changes length, like a tape)."""
    up, down = 1000, int(round(1000 * factor))
    return resample_poly(x, up, down).astype(np.float32)


def band(x: np.ndarray, low: float | None, high: float | None) -> np.ndarray:
    if low and high:
        sos = butter(4, [low, high], btype="band", fs=SR, output="sos")
    elif low:
        sos = butter(4, low, btype="high", fs=SR, output="sos")
    else:
        sos = butter(4, high, btype="low", fs=SR, output="sos")
    return sosfilt(sos, x).astype(np.float32)


def reverb(
    x: np.ndarray, room: float = 0.35, length: float = 1.2, seed: int = 1
) -> np.ndarray:
    """Convolution with decaying noise — a cheap hall."""
    rng = np.random.default_rng(seed)
    n = int(length * SR)
    ir = rng.standard_normal(n).astype(np.float32) * np.exp(
        -np.linspace(0, 7, n)
    ).astype(np.float32)
    ir = band(ir, 200, 6000)
    wet = np.convolve(x, ir)[: len(x) + n - 1]
    wet /= np.abs(wet).max() + 1e-9
    dry = np.concatenate([x, np.zeros(n - 1, np.float32)])
    return dry / (np.abs(dry).max() + 1e-9) * (1 - room) + wet * room


def mix(*parts: tuple[np.ndarray, float, float]) -> np.ndarray:
    """(signal, offset s, gain) → one signal."""
    end = max(int(o * SR) + len(s) for s, o, _ in parts)
    out = np.zeros(end, np.float32)
    for s, o, g in parts:
        i = int(o * SR)
        out[i : i + len(s)] += s * g
    return out


def loop(x: np.ndarray, length: float, xfade: float = 1.5) -> np.ndarray:
    """A seamless loop of `length` s: the tail is cross-faded into the head."""
    n, f = int(length * SR), int(xfade * SR)
    assert len(x) >= n + f, "source shorter than the loop"
    body = x[:n].copy()
    ramp = np.linspace(0.0, 1.0, f, dtype=np.float32)
    body[:f] = body[:f] * ramp + x[n : n + f] * (1 - ramp)
    return body


# ── stages ────────────────────────────────────────────────────────────────────


def stage_combat(dl: Path, repo: Path) -> None:
    sfx = repo / "SampleProject/Assets/Audio/SFX"
    impact = repo / "assets/kenney_impact-sounds/Audio"
    rpg = repo / "assets/kenney_rpg-audio/Audio"
    scifi = dl / "dl_kenney_sci-fi-sounds/x/Audio"
    ui = dl / "dl_kenney_interface-sounds/x/Audio"
    for name in [
        "impactMetal_light_000",
        "impactMetal_light_001",
        "impactMetal_light_002",
        "impactBell_heavy_000",
        "impactBell_heavy_001",
        "impactPlate_heavy_000",
        "impactPlate_heavy_001",
    ]:
        shutil.copy(impact / f"{name}.ogg", sfx / f"{name}.ogg")
    for name in ["cloth1", "cloth2", "cloth3", "cloth4", "beltHandle1", "beltHandle2"]:
        shutil.copy(rpg / f"{name}.ogg", sfx / f"{name}.ogg")
    # Casts (D271): wind-ups cut to the wind-up length, so the sound ends with the release.
    save(
        fade(cut(load(scifi / "forceField_001.ogg"), 0.0, 0.6), 0.15, 0.1),
        sfx / "cast_heal_windup.ogg",
    )
    shutil.copy(ui / "confirmation_002.ogg", sfx / "cast_heal_release.ogg")
    save(
        fade(cut(load(scifi / "thrusterFire_003.ogg"), 1.0, 0.35), 0.1, 0.05),
        sfx / "cast_fire_windup.ogg",
    )
    fire = fade(cut(load(scifi / "thrusterFire_001.ogg"), 1.0, 0.45), 0.005, 0.3)
    boom = fade(
        cut(load(scifi / "lowFrequency_explosion_000.ogg"), 0.0, 0.6), 0.005, 0.4
    )
    save(mix((fire, 0.0, 1.0), (boom, 0.0, 0.6)), sfx / "cast_fire_release.ogg")
    zaps = [load(scifi / f"laserSmall_00{i}.ogg") for i in range(3)]
    save(
        fade(
            mix((zaps[0], 0.0, 1.0), (zaps[1], 0.16, 0.9), (zaps[2], 0.3, 1.0))[
                : int(0.5 * SR)
            ],
            0.02,
            0.05,
        ),
        sfx / "cast_electric_windup.ogg",
    )
    shutil.copy(scifi / "laserLarge_001.ogg", sfx / "cast_electric_release.ogg")
    shutil.copy(ui / "error_001.ogg", sfx / "cast_interrupt.ogg")


def critter_flap(repo: Path) -> None:
    """Ambient critters take off (A21, D774): three quick soft flaps cut from cloth rustles, pitched up, fading away."""
    rpg = repo / "assets/kenney_rpg-audio/Audio"
    flaps = [
        fade(band(pitch(cut(load(rpg / f"cloth{i}.ogg"), start, 0.14), 1.3), 300, 5000), 0.01, 0.06)
        for i, start in ((2, 0.06), (3, 0.04), (4, 0.02))
    ]
    flaps = [f / np.abs(f).max() for f in flaps]  # the cloths differ 2x in level: the gains below set the fade
    save(
        mix((flaps[0], 0.0, 1.0), (flaps[1], 0.14, 0.8), (flaps[2], 0.27, 0.6)),
        repo / "SampleProject/Assets/Audio/SFX/critter_flap.ogg",
    )


def stage_world(dl: Path, repo: Path) -> None:
    sfx = repo / "SampleProject/Assets/Audio/SFX"
    ui_dir = repo / "SampleProject/Assets/Audio/UI"
    amb = repo / "SampleProject/Assets/Audio/Ambience"
    impact = repo / "assets/kenney_impact-sounds/Audio"
    rpg = repo / "assets/kenney_rpg-audio/Audio"
    ui = dl / "dl_kenney_interface-sounds/x/Audio"
    ui_dir.mkdir(parents=True, exist_ok=True)
    for surface in ["snow", "concrete", "wood"]:
        for i in range(5):
            shutil.copy(
                impact / f"footstep_{surface}_00{i}.ogg",
                sfx / f"footstep_{surface}_00{i}.ogg",
            )
    for name in [
        "impactSoft_medium_000",
        "impactSoft_medium_001",
        "impactSoft_medium_002",
        "impactWood_light_000",
        "impactWood_light_001",
        "impactWood_light_002",
    ]:
        shutil.copy(impact / f"{name}.ogg", sfx / f"{name}.ogg")
    for name in [
        "doorOpen_1",
        "doorOpen_2",
        "doorClose_1",
        "doorClose_2",
        "handleSmallLeather",
        "handleCoins",
    ]:
        shutil.copy(rpg / f"{name}.ogg", sfx / f"{name}.ogg")
    shutil.copy(ui / "confirmation_001.ogg", sfx / "level_up.ogg")
    critter_flap(repo)
    for name in ["tick_002", "click_001", "switch_002", "scroll_001"]:
        shutil.copy(ui / f"{name}.ogg", ui_dir / f"{name}.ogg")

    # Ambience loops (D276): 30 s, cross-faded into themselves.
    wind = load(dl / "dl_oga_wind/wind.wav")
    dungeon = load(dl / "dl_oga_dungeon/dungeon.ogg")
    crowd = load(dl / "dl_oga_crowd/crowd.ogg")
    rumble = load(dl / "dl_oga_rumble/rumble.mp3")
    wind_soft = band(wind, None, 3000)
    distant = band(crowd, 200, 1800)  # far away: no highs, no rumble
    murmur = band(crowd, 150, 900)  # behind walls
    while len(distant) < 32 * SR:
        distant = np.concatenate([distant, distant])
        murmur = np.concatenate([murmur, murmur])
    while len(rumble) < 32 * SR:
        rumble = np.concatenate([rumble, rumble])
    save(loop(wind_soft, 30), amb / "amb_desert_wind.ogg", 0.7)
    save(
        loop(mix((dungeon[10 * SR :], 0, 1.0), (wind_soft, 0, 0.35)), 30),
        amb / "amb_canyon_echo.ogg",
        0.7,
    )
    save(
        loop(mix((wind_soft, 0, 0.8), (distant, 0, 0.25)), 30),
        amb / "amb_village.ogg",
        0.7,
    )
    save(
        loop(mix((distant, 0, 0.9), (wind_soft, 0, 0.2)), 30),
        amb / "amb_city_crowd.ogg",
        0.7,
    )
    save(loop(murmur, 30), amb / "amb_hall.ogg", 0.5)
    save(loop(band(rumble, None, 400), 30), amb / "amb_lab_hum.ogg", 0.6)


STAGES = {"combat": stage_combat, "world": stage_world}

if __name__ == "__main__":
    downloads, repo_dir = Path(sys.argv[1]), Path(sys.argv[2])
    for stage in sys.argv[3:]:
        STAGES[stage](downloads, repo_dir)
        print("built", stage)
