#!/usr/bin/env python3
# wire-backdrops (D830, D834): скельні уступи — на головній дорозі, а там сходинок немає. Колізія кімнати RockLedges —
# пандус world-rooms (build_world_rooms.py, slope "up": (96, 864) → (768, 384) у світі кімнати). Цей скрипт гне
# намальовану скелю RockLedges/gen_ledges.png під той самий пандус: кожен стовпчик арту зсувається по вертикалі так,
# що його лінія ходу (сходинка з таблиці README) лягає на пандус; світла кромка, тінь під нею й порода йдуть разом зі
# стовпчиком, низ доповнюється нижнім рядком стовпчика. Нічого не малюється заново.
#   python3 Scripts/Tools/ledges_ramp.py   →   RockLedges/gen_ledges_ramp.png
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "SampleProject/Assets/Backgrounds/RockLedges/gen_ledges.png"
OUT = ROOT / "SampleProject/Assets/Backgrounds/RockLedges/gen_ledges_ramp.png"
# Лінія ходу арту (README «The ledges — collision», art px): [x від, верх].
STEPS = [(0, 597), (110, 555), (150, 501), (190, 459), (230, 405), (270, 352), (310, 309), (350, 277)]
# Пандус кімнати в арті: світ (x, y) → арт (x / 1.5, (y + 32) / 1.5) — план зсунутий на −32, щоб лінія ходу 416 арту
# лягла на підлогу дороги 384 (як і решта планів дороги).
RAMP = ((96 / 1.5, (864 + 32) / 1.5), (768 / 1.5, (384 + 32) / 1.5))


def walk(x: int) -> int:
    top = STEPS[0][1]
    for x0, y in STEPS:
        if x >= x0:
            top = y
    return top


def ramp(x: int) -> int:
    (x0, y0), (x1, y1) = RAMP
    t = min(1.0, max(0.0, (x + 0.5 - x0) / (x1 - x0)))
    return round(y0 + (y1 - y0) * t)


def main() -> None:
    src = np.asarray(Image.open(SRC).convert("RGBA"))
    h, w = src.shape[:2]
    out = np.zeros_like(src)
    for x in range(w):
        d = ramp(x) - walk(x)  # >0 — вниз (зрізати ріг сходинки), <0 — вгору (заповнити під пандусом)
        col = src[:, x]
        for y in range(h):
            sy = min(h - 1, y - d)
            if sy >= 0:
                out[y, x] = col[sy]
    Image.fromarray(out).save(OUT)
    print("wrote", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
