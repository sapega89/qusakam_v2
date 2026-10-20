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


def rect(px, x0, y0, x1, y1, c):
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = c if len(c) == 4 else c + (255,)


def lamp():
    """Ліхтар на кронштейні: кронштейн ліворуч у стіну, скло з полум'ям, латунна шапка."""
    im = Image.new("RGBA", (14, 20))
    px = im.load()
    rect(px, 0, 3, 5, 5, IRON[1])  # кронштейн
    rect(px, 0, 2, 5, 3, OUTLINE)
    rect(px, 0, 5, 5, 6, OUTLINE)
    rect(px, 4, 1, 13, 4, BRASS[1])  # шапка
    rect(px, 5, 1, 12, 2, BRASS[0])
    rect(px, 5, 4, 12, 15, (255, 232, 170, 150))  # скло
    rect(px, 7, 7, 10, 13, FLAME[1] + (255,))
    rect(px, 8, 6, 9, 12, FLAME[0] + (255,))
    rect(px, 7, 12, 10, 13, FLAME[2] + (255,))
    rect(px, 4, 15, 13, 17, BRASS[2])  # низ
    for y in range(1, 17):  # контур
        px[4, y] = OUTLINE
        px[12, y] = OUTLINE
    rect(px, 4, 0, 13, 1, OUTLINE)
    rect(px, 4, 17, 13, 18, OUTLINE)
    px[8, 18] = OUTLINE
    px[8, 19] = OUTLINE
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    lamp().save(OUT + "lamp.png")
    print("drawn", OUT)
