"""Реквізит лабораторії (D226): настінна лампа, колба з зеленою рідиною, ланка ланцюга, силуети переднього
плану (труба, колона). Стиль героя: контур (40, 23, 36), світло зліва-згори; силуети — майже чорні.
У грі ×1.5. Ставить Scripts/Tools/build_laboratory.gd.
Запуск: python Scripts/Tools/draw_lab_props.py
"""

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from pixel_kit import OUTLINE  # noqa: E402

OUT = "SampleProject/Assets/Laboratory/"
IRON = [(150, 156, 170), (104, 108, 124), (70, 72, 86)]
BRASS = [(236, 196, 110), (196, 148, 70), (140, 98, 46)]
FLAME = [(255, 246, 200), (255, 206, 110), (240, 140, 60)]
GLASS = (190, 230, 240, 90)
LIQUID = [(150, 240, 150, 220), (90, 200, 110, 220), (50, 150, 80, 230)]
SIL = (18, 14, 22, 255)
SIL_EDGE = (34, 28, 40, 255)


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


def vat():
    """Колба на підставці: залізні кільця, скло, зелена рідина з бульбашками, блік."""
    w, h = 22, 42
    im = Image.new("RGBA", (w, h))
    px = im.load()
    rect(px, 2, 0, w - 2, 4, IRON[1])  # верхнє кільце
    rect(px, 3, 0, w - 3, 1, IRON[0])
    rect(px, 3, 4, w - 3, h - 6, GLASS)
    for y in range(12, h - 6):  # рідина: світліша згори
        c = LIQUID[0] if y < 15 else LIQUID[1] if y < h - 12 else LIQUID[2]
        for x in range(4, w - 4):
            px[x, y] = c
    for bx, by in [(8, 30), (13, 22), (10, 17), (15, 33), (7, 25)]:  # бульбашки
        px[bx, by] = (220, 255, 220, 255)
    for y in range(6, h - 8):  # блік на склі
        px[5, y] = (255, 255, 255, 140)
    rect(px, 1, h - 6, w - 1, h, IRON[1])  # підставка
    rect(px, 2, h - 6, w - 2, h - 5, IRON[0])
    rect(px, 1, h - 2, w - 1, h, IRON[2])
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and (
                x == 0
                or y == 0
                or x == w - 1
                or y == h - 1
                or not px[x - 1, y][3]
                or not px[x + 1, y][3]
            ):
                if px[x, y][3] > 100:
                    px[x, y] = OUTLINE
    for y in range(4, h - 6):
        px[3, y] = OUTLINE
        px[w - 4, y] = OUTLINE
    return im


def chain():
    """Ланка ланцюга 6x8, повторюється вертикально."""
    im = Image.new("RGBA", (6, 8))
    d = ImageDraw.Draw(im)
    d.ellipse((1, 0, 4, 5), outline=OUTLINE)
    im.putpixel((2, 1), IRON[0] + (255,))
    d.line((2, 5, 2, 7), fill=IRON[1] + (255,))
    d.line((3, 5, 3, 7), fill=OUTLINE)
    return im


def fg_pipe():
    """Силует труби переднього плану, тайл 32x14 по горизонталі: труба з фланцем."""
    im = Image.new("RGBA", (32, 14))
    px = im.load()
    rect(px, 0, 3, 32, 11, SIL)
    rect(px, 0, 3, 32, 4, SIL_EDGE)
    rect(px, 26, 1, 30, 13, SIL)  # фланець
    rect(px, 26, 1, 30, 2, SIL_EDGE)
    return im


def fg_column():
    """Силует колони переднього плану, тайл 28x16 по вертикалі (стовбур із жолобками)."""
    im = Image.new("RGBA", (28, 16))
    px = im.load()
    rect(px, 2, 0, 26, 16, SIL)
    for x in (7, 13, 19):
        rect(px, x, 0, x + 1, 16, SIL_EDGE)
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    lamp().save(OUT + "lamp.png")
    vat().save(OUT + "vat.png")
    chain().save(OUT + "chain.png")
    fg_pipe().save(OUT + "fg_pipe.png")
    fg_column().save(OUT + "fg_column.png")
    print("drawn", OUT)
