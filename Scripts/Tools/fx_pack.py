#!/usr/bin/env python3
"""Пакунок фільму бойових ефектів (SampleProject/UI/film_fx.gd) для нотаток Sapega (BACKLOG 30 / A9).

  python3 -I Scripts/Tools/fx_pack.py <тека з fx.avi і fx.marks.json> [design/shots/fx]

На кожен кліп з fx.marks.json:
  <id>.gif        вирізано навколо героя й цілі, пікселі гри x2 (nearest), 15 fps, не більше MAX_GIF байт
  <id>_sheet.jpg  6 кадрів кліпу рівно по часу, в одному аркуші (3 x 2)
і index.md — таблиця: ефект, звідки він (файл / skill id), GIF, аркуш, що він має показати.
Потрібні cv2, numpy, Pillow. Відео (.avi) у git не йде.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

GIF_FPS = 15
MAX_GIF = 1_500_000
SHEET_FRAMES = 6
SHEET_COLS = 3
## Пікселів GIF на піксель гри (світу).
SCALE = 2
JPG = [cv2.IMWRITE_JPEG_QUALITY, 88]

## Звідки ефект: файли кадрів / сцена / skill id (для таблиці).
SOURCES = {
    "level_up": "`Scenes/FX/LevelUpFlash.tscn`, `LevelUpParticles.tscn`",
    "landing_dust": "`Scenes/FX/LandingDust.tscn`",
    "punch_combo": "`Assets/FX/Smear/punch_1-3`, `Hit/cut_1-4`, `SlashTrail.tscn`, `HitImpact.tscn`",
    "sword_combo": "`Assets/FX/Smear/arc_1-3`, `Hit/cut_1-4`",
    "mace_combo": "`Assets/FX/Smear/arc_1-3`, `Hit/cut_1-4`",
    "dagger_combo": "`Assets/FX/Smear/thrust_1-3`, `Hit/cut_1-4`",
    "halberd_combo": "`Assets/FX/Smear/thrust_1-3`, `arc_1-3`",
    "dual_combo": "`Assets/FX/Smear/arc_1-3`, `thrust_1-3`",
    "heavy_attack": "`Assets/FX/Smear/arc_1-3` (x1.4), `Hit/cut_1-4`",
    "bow_quick_shot": "`Assets/FX/Projectiles/arrow.png`",
    "bow_charged_shot": "`Assets/FX/Projectiles/arrow_charged.png`",
    "skill_fire_strike": "`fire_strike` - `Skills/fire_arc.png`, `Scenes/FX/Skills/FireStrike.tscn`",
    "skill_electric_strike": "`electric_strike` - `Skills/bolt.png`, `ElectricStrike.tscn`",
    "skill_healing_palm": "`healing_palm` - `Skills/heal_aura.png`, `HealingPalm.tscn`",
    "parry_spark": "`Scenes/FX/ParrySpark.tscn` (VFXHooks._on_guard)",
    "block_spark": "`Scenes/FX/ParrySpark.tscn` x0.5",
    "enemy_shield_sparks": "`ParrySpark.tscn` (VFXHooks._on_shield)",
    "boss_fire_djinn_fireball": "`Assets/FX/Bosses/fireball.png`, `Scenes/FX/Bosses/boss_fireball.tscn`",
    "boss_fire_djinn_pillar": "`Assets/FX/Bosses/mark.png`, `pillar.png`, `boss_pillar.tscn`",
    "boss_brass_collector_slam": "`Assets/FX/Bosses/shockwave.png`, `boss_shockwave.tscn`; EnemyStrikeFX slam",
    "companion_alisia": "`Scenes/FX/Companions/charge_glow`, `arrow_streak`, `hit_spark`",
    "companion_astrit": "`Scenes/FX/Companions/landing_dust`, `charge_glow`, `shield_slam`, `stun_stars`",
    "companion_urizen": "`Scenes/FX/Companions/charge_glow`, `gold_burst`",
    "companion_guard": "`Scenes/FX/Companions/wind_arc`, `knockback_puff`",
    "enemy_death": "`Scenes/FX/DeathParticles.tscn`, `DamageNumber.tscn`",
}


def source(cid: str) -> str:
    if cid in SOURCES:
        return SOURCES[cid]
    if cid.startswith("skill_"):
        sid = cid[len("skill_"):]
        return f"`{sid}` - `Assets/FX/Skills/{sid}/charge_*, release_*`, `OathSkill.tscn`"
    if cid.startswith("enemy_"):
        kind = cid[len("enemy_"):]
        extra = ", `CursedFoam.tscn`" if kind == "jackal_cursed" else ""
        return f"`Scripts/FX/EnemyStrikeFX.gd` ({kind}){extra}; hurt: `HitImpact.tscn`, `HurtVignette.tscn`"
    return "?"


def read_all(avi: Path, wanted: set) -> dict:
    cap = cv2.VideoCapture(str(avi))
    frames = {}
    i = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if i in wanted:
            frames[i] = frame
        i += 1
    cap.release()
    return frames


def crop(frame: np.ndarray, rect: list, zoom: float) -> Image.Image:
    x, y, w, h = rect
    part = frame[y:y + h, x:x + w]
    size = (max(1, round(w / zoom * SCALE)), max(1, round(h / zoom * SCALE)))
    part = cv2.resize(part, size, interpolation=cv2.INTER_NEAREST)
    return Image.fromarray(cv2.cvtColor(part, cv2.COLOR_BGR2RGB))


def save_gif(images: list, path: Path) -> int:
    """GIF не більше MAX_GIF: спершу менше кольорів, далі менший розмір."""
    imgs = images
    for colors in (256, 128, 64, 48):
        pal = [im.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for im in imgs]
        pal[0].save(path, save_all=True, append_images=pal[1:], duration=round(1000 / GIF_FPS), loop=0,
                    optimize=True, disposal=1)
        if path.stat().st_size <= MAX_GIF:
            return colors
    for factor in (0.75, 0.6, 0.5):
        small = [im.resize((round(im.width * factor), round(im.height * factor)), Image.Resampling.NEAREST) for im in images]
        for colors in (64, 32):
            pal = [im.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for im in small]
            pal[0].save(path, save_all=True, append_images=pal[1:], duration=round(1000 / GIF_FPS), loop=0,
                        optimize=True, disposal=1)
            if path.stat().st_size <= MAX_GIF:
                return -round(factor * 100)
    return 0


def sheet(images: list) -> np.ndarray:
    picks = [images[round(i * (len(images) - 1) / (SHEET_FRAMES - 1))] for i in range(SHEET_FRAMES)]
    w, h = picks[0].size
    rows = (SHEET_FRAMES + SHEET_COLS - 1) // SHEET_COLS
    out = np.full((rows * (h + 4) + 4, SHEET_COLS * (w + 4) + 4, 3), 24, np.uint8)
    for n, im in enumerate(picks):
        r, c = divmod(n, SHEET_COLS)
        cell = cv2.cvtColor(np.asarray(im.convert("RGB")), cv2.COLOR_RGB2BGR)
        out[4 + r * (h + 4):4 + r * (h + 4) + h, 4 + c * (w + 4):4 + c * (w + 4) + w] = cell
    return out


def main() -> None:
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2] if len(sys.argv) > 2 else "design/shots/fx")
    dst.mkdir(parents=True, exist_ok=True)
    marks = json.loads((src / "fx.marks.json").read_text())
    zoom = float(marks["zoom"])
    step = round(marks["movie_fps"] / GIF_FPS)
    wanted = set()
    for c in marks["clips"]:
        wanted.update(range(c["first"], c["last"] + 1, step))
    frames = read_all(src / "fx.avi", wanted)
    rows = []
    for c in marks["clips"]:
        idx = [i for i in range(c["first"], c["last"] + 1, step) if i in frames]
        if not idx or "rect_px" not in c:
            print(f"PACK {c['id']}: no frames")
            continue
        images = [crop(frames[i], c["rect_px"], zoom) for i in idx]
        gif = dst / f"{c['id']}.gif"
        colors = save_gif(images, gif)
        cv2.imwrite(str(dst / f"{c['id']}_sheet.jpg"), sheet(images), JPG)
        # colors: палітра GIF; від'ємне — GIF зменшено до стількох % (не вліз у MAX_GIF); 0 — не вліз зовсім
        print(f"PACK {c['id']}: {len(images)} frames {images[0].size} {gif.stat().st_size // 1024} KB colors {colors}")
        rows.append(f"| `{c['id']}` | {source(c['id'])} | ![]({gif.name}) | [sheet]({c['id']}_sheet.jpg) | {c['note']} |")
    lines = ["---", "type: shots", "tags: [fx, film]", "---", "", "# Combat effects in motion",
             "",
             "Filmed by `SampleProject/UI/film_fx.gd` (DesertRoad, a stationary dummy or enemy, HUD hidden, the hero takes no "
             "real damage), packed by `Scripts/Tools/fx_pack.py`: each GIF cropped around the hero and the target, game "
             f"pixels x{SCALE} nearest, {GIF_FPS} fps; each sheet is {SHEET_FRAMES} frames evenly through the clip. "
             "Report: [[fx-film]].", "",
             "| Effect | From (file / skill id) | GIF | Sheet | Meant to show |", "|---|---|---|---|---|", *rows]
    if marks.get("skipped"):
        lines += ["", "Not filmed: " + "; ".join(marks["skipped"])]
    (dst / "index.md").write_text("\n".join(lines) + "\n")
    print(f"PACK index: {len(rows)} effects -> {dst}")


if __name__ == "__main__":
    main()
