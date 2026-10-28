"""Око героя в кадрах H3 зі зброєю — запускати з кореня проєкту ПІСЛЯ `comfy_sprite.py hero_weapon_<тип>_h3` і ПЕРЕД
`weapon_key_fixups.py`.

ShieldCharge/2 (кинджал, булава): модель малювала око мішенню — червоне кільце з темним хрестиком. Кадр зроблено ON: з
ShieldCharge/2 героя (64x64 у клітинці з (16, 32)), голова лягла піксель у піксель (булава — на рядок нижче, dy) — око
(x 54–64, рядки 48–56 кадру героя) взято з кадру героя.
"""

import numpy as np
from PIL import Image

SKIN = {(0xF4, 0xCE, 0x8A), (0xE7, 0xB5, 0x7B)}
X0, X1, Y0, Y1 = 54, 64, 48, 56  # включно
FRAMES = {"dagger": 0, "mace": 1}  # набір → зсув голови вниз відносно кадру героя
hero = Image.new("RGBA", (96, 96))
hero.alpha_composite(
    Image.open("SampleProject/Sprites/Player/ShieldCharge/2.png").convert("RGBA"),
    (16, 32),
)
src = np.asarray(hero)
for weapon, dy in FRAMES.items():
    path = "SampleProject/Sprites/Player/Weapons/%s/ShieldCharge/2.png" % weapon
    a = np.asarray(Image.open(path).convert("RGBA")).copy()
    for frame, d in ((src, 0), (a, dy)):
        # око в прямокутнику: стовпці по боках — шкіра голови в обох кадрах
        edges = [
            tuple(frame[y + d, x, :3]) for y in range(Y0, Y1 + 1) for x in (X0 - 1, X1 + 1)
        ]
        assert set(edges) <= SKIN, (
            "%s ShieldCharge/2: the head moved — the eye box no longer fits" % weapon
        )
    a[Y0 + dy : Y1 + dy + 1, X0 : X1 + 1] = src[Y0 : Y1 + 1, X0 : X1 + 1]
    Image.fromarray(a).save(path)
