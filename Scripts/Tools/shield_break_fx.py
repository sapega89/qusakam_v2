"""B200: уламки розбитого щита — 4 кадри 96×96 у FX/Hit/shield_break_1–4.png. Не генерація: щит вирізано з кадру
idle 0 вартового (shield_tower/sheet.png, x 53–76, y 33–90), розколото на 12 уламків (Вороной із фіксованим зерном),
уламки розлітаються від центру й падають, повертаючись на 90° (без втрат), кольори — лише кольори щита.
Центр щита в кадрі 1 — (48, 40) полотна. Запуск: python -I -B Scripts/Tools/shield_break_fx.py
"""

import os

import numpy as np
from PIL import Image

SRC = "SampleProject/Assets/Characters/Enemies/shield_tower/sheet.png"
OUT = "SampleProject/Assets/FX/Hit/shield_break_%d.png"
BOX = (53, 33, 77, 91)  # щит у клітинці 0
SIZE, CENTRE, PIECES = 96, (48, 40), 12
# t — «час» кадру; alive — частка уламків, що лишаються (останній кадр рідшає)
FRAMES = [(0.35, 1.0), (1.0, 1.0), (1.8, 0.8), (2.6, 0.5)]
GRAVITY = 3.0


def main():
    rng = np.random.default_rng(200)
    shield = np.asarray(Image.open(SRC).convert("RGBA"))[
        BOX[1] : BOX[3], BOX[0] : BOX[2]
    ].copy()
    red = (shield[..., 0] > 140) & (
        shield[..., 1] < 90
    )  # край шарфа, що заходить у прямокутник
    shield[(shield[..., 3] < 128) | red] = 0
    h, w = shield.shape[:2]
    seeds = np.stack([rng.uniform(0, h, PIECES), rng.uniform(0, w, PIECES)], 1)
    yy, xx = np.mgrid[0:h, 0:w]
    owner = np.argmin(
        ((yy[..., None] - seeds[:, 0]) ** 2 + (xx[..., None] - seeds[:, 1]) ** 2),
        axis=2,
    )
    shards = []
    for k in range(PIECES):
        mask = (owner == k) & (shield[..., 3] > 0)
        if not mask.any():
            continue
        ys, xs = np.nonzero(mask)
        piece = np.where(mask[..., None], shield, 0)[
            ys.min() : ys.max() + 1, xs.min() : xs.max() + 1
        ]
        cy, cx = (ys.min() + ys.max()) / 2 - h / 2, (xs.min() + xs.max()) / 2 - w / 2
        away = np.array([cy, cx]) / (np.hypot(cy, cx) + 1e-6)
        speed = rng.uniform(5, 8)
        shards.append(
            dict(
                piece=piece,
                pos=np.array([cy, cx]),
                vel=np.array(
                    [
                        away[0] * speed - rng.uniform(3, 6),
                        away[1] * speed + rng.uniform(1, 3),
                    ]
                ),
                spin=int(rng.choice([-1, 1])),
                order=rng.random(),
            )
        )
    for n, (t, alive) in enumerate(FRAMES, 1):
        pad = SIZE // 2  # уламки за краєм обрізає crop, а не alpha_composite
        canvas = Image.new("RGBA", (SIZE + 2 * pad, SIZE + 2 * pad))
        for s in shards:
            if s["order"] > alive:
                continue
            y, x = s["pos"] + s["vel"] * t + np.array([GRAVITY * t * t, 0])
            im = Image.fromarray(
                np.ascontiguousarray(np.rot90(s["piece"], -s["spin"] * int(t * 1.5)))
            )
            at = (
                pad + int(round(CENTRE[1] + x - im.width / 2)),
                pad + int(round(CENTRE[0] + y - im.height / 2)),
            )
            canvas.alpha_composite(im, at)
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        canvas.crop((pad, pad, pad + SIZE, pad + SIZE)).save(OUT % n)
        print("done", OUT % n)


if __name__ == "__main__":
    main()
