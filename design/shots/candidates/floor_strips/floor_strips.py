"""Підлоги залу мера й дому старости замість бежевої плитки (критики глибини 2026-10-27, знахідка 8).
Смуги намалював comfy_backdrop.py (Hall/gen_floor, ElderHouse/gen_floor; їхні виходи — *_floor_gen.png поруч):
тут — обрізати те, що модель поставила над підлогою, латка, 64 рядки (96 px світу: від лінії ходьби до низу
кадру), кольори — палітрою стіни кімнати, рядок 0 — кромка.
  python -B design/shots/candidates/floor_strips/floor_strips.py
"""

import os

import numpy as np
from PIL import Image

D = os.path.dirname(os.path.abspath(__file__))
A = "SampleProject/Assets/Backgrounds/"
ROWS = 64
# кімната: (сирий вихід, стіна-палітра, вихід, рядків зверху геть, латки (x_з, x_куди, ширина, y0, y1))
STRIPS = {
    # над доріжкою модель поставила смугу мармурової стіни: підлога починається з доріжки
    "hall": (
        "hall_floor_gen.png",
        A + "Hall/gen_wall.png",
        A + "Hall/gen_floor.png",
        8,
        [],
    ),
    # над дошками — шматок стіни з глеком і темною скринькою; глек стоїть і на дошках — латка з чистих дощок
    "elder": (
        "elder_floor_gen.png",
        A + "ElderHouse/gen_wall.png",
        A + "ElderHouse/gen_floor.png",
        11,
        [(100, 212, 64, 0, 40), (340, 280, 24, 18, 36), (300, 15, 70, 38, 64), (130, 212, 40, 38, 64)],
    ),
}


def to_palette(rgb, pal):
    d = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1)
    return pal[d.argmin(-1)]


def build(src, wall, out, cut, patches):
    f = np.asarray(Image.open(os.path.join(D, src)).convert("RGB")).copy()
    for sx, dx, w, y0, y1 in patches:
        f[y0:y1, dx : dx + w] = f[y0:y1, sx : sx + w]
    f = f[cut:]
    f = np.concatenate([f, f[::-1]])[:ROWS]  # низ добудовано дзеркалом
    pal = np.unique(np.asarray(Image.open(wall).convert("RGB")).reshape(-1, 3), axis=0)
    # червоні тони смуги (доріжка в залі) — свої: у стіні їх немає, і доріжка ставала фіолетовою
    own = np.unique(f.reshape(-1, 3), axis=0)
    pal = np.concatenate([pal, own[own[:, 0].astype(int) > own[:, 1].astype(int) + 60]]).astype(np.float32)
    f = to_palette(f.astype(np.float32), pal).astype(np.uint8)
    # кромка: рядок 0 — найсвітліший колір першого рядка, рядок 1 — на тон темніший, щоб край читався
    top = f[0].astype(int)
    f[0] = top[np.argmax(top.sum(-1))]
    f[1] = (f[1].astype(int) * 0.75).astype(np.uint8)
    rgba = np.dstack([f, np.full(f.shape[:2], 255, np.uint8)])
    Image.fromarray(rgba).save(out)
    print(out, rgba.shape[1], rgba.shape[0], flush=True)


if __name__ == "__main__":
    for args in STRIPS.values():
        build(*args)
