"""Ручна правка кадру кинджала — запускати з кореня проєкту ПІСЛЯ `comfy_sprite.py hero_weapon_dagger_h3` і ПЕРЕД
`weapon_key_fixups.py`.

dagger/ShieldCharge/2 (H3): за дві спроби (без і з HERO_FACE) модель малювала око мішенню — червоне кільце з темним
хрестиком. Кадр зроблено ON: з ShieldCharge/2 героя (64x64 у клітинці з (16, 32)), голова лягла піксель у піксель —
око (x 54–64, рядки 48–56) взято з кадру героя.
"""

import numpy as np
from PIL import Image

SKIN = {(0xF4, 0xCE, 0x8A), (0xE7, 0xB5, 0x7B)}
X0, X1, Y0, Y1 = 54, 64, 48, 56  # включно
path = "SampleProject/Sprites/Player/Weapons/dagger/ShieldCharge/2.png"
hero = Image.new("RGBA", (96, 96))
hero.alpha_composite(
    Image.open("SampleProject/Sprites/Player/ShieldCharge/2.png").convert("RGBA"),
    (16, 32),
)
src = np.asarray(hero)
a = np.asarray(Image.open(path).convert("RGBA")).copy()
for frame in (src, a):
    # око в прямокутнику: стовпці по боках — шкіра голови в обох кадрах
    edges = [
        tuple(frame[y, x, :3]) for y in range(Y0, Y1 + 1) for x in (X0 - 1, X1 + 1)
    ]
    assert set(edges) <= SKIN, (
        "dagger ShieldCharge/2: the head moved — the eye box no longer fits"
    )
a[Y0 : Y1 + 1, X0 : X1 + 1] = src[Y0 : Y1 + 1, X0 : X1 + 1]
Image.fromarray(a).save(path)
