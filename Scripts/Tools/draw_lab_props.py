"""Реквізит лабораторії (D226): настінна лампа. Колби, ланцюги й силуети переднього плану замінили
згенеровані плани (D246). Стиль героя: контур (40, 23, 36), світло зліва-згори.
У грі ×1.5. Ставить Scripts/Tools/build_laboratory.gd.
Запуск: python Scripts/Tools/draw_lab_props.py
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pixel_kit import OUTLINE  # noqa: E402

OUT = "SampleProject/Assets/Laboratory/"
IRON = [(150, 156, 170), (104, 108, 124), (70, 72, 86)]
BRASS = [(236, 196, 110), (196, 148, 70), (140, 98, 46)]
FLAME = [(255, 246, 200), (255, 206, 110), (240, 140, 60)]


# A8 (2026-10-28, «поправити» без примітки): був набір прямокутників — плоске сіре скло, полум'я-брусок, кронштейн
# смужкою. Тепер ліхтар: гачок, шапка-дашок, рамка з бурштиновим склом, що світиться від полум'я-краплі, піддон і
# кронштейн зі стінною пластиною. Розмір 14 × 20 і полум'я там само (x 7–10, рядки 7–12) — світло лампи з
# build_laboratory.gd стоїть на ньому.
LAMP = [
    "........oo....",
    ".......oBro...",
    "......oBbbro..",
    ".....oBbbbbro.",
    "o...oBbbbbbbro",
    "oI..oorrrrrroo",
    "oI...ogGGGGgo.",
    "oIoooogGWWGgo.",
    "oIiiiogGWWGgo.",
    "oIdddogGWWGgo.",
    "oIoooogFWWFgo.",
    "o....ogFFFFgo.",
    ".....ogGffGgo.",
    ".....oggGGggo.",
    ".....oggggggo.",
    "....oBbbbbbbro",
    ".....orrrrrro.",
    ".......obbo...",
    "........oo....",
    "..............",
]
LAMP_COLORS = {
    "o": OUTLINE,
    "I": IRON[1],
    "i": IRON[0],
    "d": IRON[2],
    "B": BRASS[0],
    "b": BRASS[1],
    "r": BRASS[2],
    "g": (214, 150, 80),  # скло біля рамки
    "G": (255, 214, 140),  # скло, що світиться
    "W": FLAME[0],
    "F": FLAME[1],
    "f": FLAME[2],
}


def lamp():
    """Ліхтар на кронштейні: кронштейн ліворуч у стіну, скло з полум'ям, латунна шапка (карта LAMP)."""
    assert len(LAMP) == 20 and all(len(row) == 14 for row in LAMP)
    im = Image.new("RGBA", (14, 20))
    for y, row in enumerate(LAMP):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), tuple(LAMP_COLORS[ch][:3]) + (255,))
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    lamp().save(OUT + "lamp.png")
    print("drawn", OUT)
