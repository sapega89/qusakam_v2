"""Малює зброю в руці героя (D223) у його стилі: контур героя, світло зліва-згори.

Кожна зброя — вістрям угору, руків'я внизу по центру; точка хвату — GRIP пікселів від низу (WeaponMount
ставить її в руку). У грі ×1.5, як герой. Файл на кожен id з items.json, що має weapon_profile.
Запуск: python Scripts/Tools/draw_weapons.py
"""

import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from pixel_kit import OUTLINE  # noqa: E402

OUT = "SampleProject/Assets/Weapons/"
GRIP = 3

METAL = {
    "iron": [(222, 226, 236), (170, 176, 192), (118, 124, 144), (80, 84, 102)],
    "copper": [(250, 190, 130), (214, 132, 78), (160, 88, 54), (112, 58, 40)],
    "silver": [(255, 255, 255), (214, 226, 240), (158, 176, 200), (110, 124, 150)],
    "crystal": [(232, 252, 255), (150, 226, 240), (84, 150, 210), (48, 92, 150)],  # weapon_palettes.json
}
WOOD = [(184, 128, 80), (146, 96, 58), (108, 70, 44), (76, 48, 34)]
LEATHER = [(140, 84, 56), (108, 62, 42), (80, 44, 32)]
GOLD = [(255, 222, 120), (226, 172, 64), (170, 120, 44)]


def canvas(w, h):
    return Image.new("RGBA", (w, h))


def fill(im, points, pal, axis_x=None):
    """Многокутник: ліва половина світла, права — тінь, контур по краю."""
    m = Image.new("L", im.size)
    ImageDraw.Draw(m).polygon(points, fill=255)
    mp, px = m.load(), im.load()
    w, h = im.size
    xs = [p[0] for p in points]
    mid = axis_x if axis_x is not None else (min(xs) + max(xs)) / 2
    for y in range(h):
        for x in range(w):
            if not mp[x, y]:
                continue
            edge = any(
                not (0 <= x + dx < w and 0 <= y + dy < h and mp[x + dx, y + dy])
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            if edge:
                px[x, y] = OUTLINE
            else:
                i = 0 if x < mid - 0.5 else 1 if x < mid + 0.5 else 2
                px[x, y] = pal[i] + (255,)


def grip(im, cx, y0, y1):
    """Руків'я, обмотане шкірою (смужки)."""
    fill(im, [(cx - 2, y0), (cx + 1, y0), (cx + 1, y1), (cx - 2, y1)], LEATHER)
    for y in range(y0 + 1, y1, 2):
        im.putpixel((cx - 1, y), LEATHER[2] + (255,))


def sword(metal):
    w, h = 12, 36
    im = canvas(w, h)
    cx = w // 2
    pal = METAL[metal]
    fill(
        im,
        [(cx - 3, 3), (cx, 0), (cx + 2, 3), (cx + 2, 25), (cx - 3, 25)],
        pal,
        axis_x=cx - 0.5,
    )  # клинок
    for y in range(4, 24):  # дол
        im.putpixel((cx - 1, y), pal[3] + (255,))
    fill(
        im,
        [(0, 25), (w - 1, 25), (w - 1, 28), (0, 28)],
        GOLD if metal == "silver" else pal,
    )  # гарда
    grip(im, cx, 28, 33)
    fill(
        im,
        [(cx - 3, 32), (cx + 2, 32), (cx + 2, 35), (cx - 3, 35)],
        GOLD if metal == "silver" else pal,
    )  # навершя
    return im


def dagger():
    w, h = 9, 22
    im = canvas(w, h)
    cx = w // 2
    pal = METAL["iron"]
    fill(
        im,
        [(cx - 2, 2), (cx, 0), (cx + 2, 2), (cx + 2, 12), (cx - 2, 12)],
        pal,
        axis_x=cx,
    )
    fill(im, [(0, 12), (w - 1, 12), (w - 1, 14), (0, 14)], pal)
    grip(im, cx + 1, 14, 19)
    fill(im, [(cx - 1, 18), (cx + 2, 18), (cx + 2, 21), (cx - 1, 21)], pal)
    return im


def mace():
    w, h = 15, 30
    im = canvas(w, h)
    cx = w // 2
    pal = METAL["iron"]
    fill(
        im, [(cx - 1, 9), (cx + 1, 9), (cx + 1, 29), (cx - 1, 29)], WOOD, axis_x=cx
    )  # держак
    grip(im, cx + 1, 22, 28)
    fill(
        im,
        [(cx - 5, 3), (cx, 0), (cx + 5, 3), (cx + 5, 10), (cx, 13), (cx - 5, 10)],
        pal,
    )  # голова з ребрами
    for x, y in [
        (0, 6),
        (w - 1, 6),
        (cx, 0),
        (2, 1),
        (w - 3, 1),
        (2, 12),
        (w - 3, 12),
    ]:  # шипи
        im.putpixel((x, y), OUTLINE)
    for y in (4, 7, 10):
        im.putpixel((cx, y), pal[3] + (255,))
    return im


def halberd():
    """A9 (2026-10-28, D813 «поправити»): важка дворучна зброя-компроміс (D698) — широке лезо-півмісяць із рогами,
    довге листоподібне вістря, гак-дзьоб назад, залізна муфта з заклепками й окуття держака (було: сірий
    прямокутник сокири на палиці з тонким шпилем)."""
    w, h = 18, 60
    im = canvas(w, h)
    cx = 8
    pal = METAL["iron"]
    fill(
        im, [(cx - 1, 8), (cx + 1, 8), (cx + 1, 59), (cx - 1, 59)], WOOD, axis_x=cx
    )  # держак
    grip(im, cx + 1, 50, 57)
    fill(im, [(cx, 0), (cx + 2, 5), (cx + 1, 9), (cx - 1, 9), (cx - 2, 5)], pal, axis_x=cx)  # вістря-листок
    fill(
        im,
        [(cx + 1, 11), (cx + 5, 10), (w - 3, 5), (w - 1, 8), (w - 1, 21), (w - 3, 25), (cx + 5, 20), (cx + 1, 19)],
        pal,
        axis_x=cx + 6,
    )  # лезо-півмісяць уперед
    fill(im, [(cx - 1, 12), (1, 8), (3, 14), (cx - 1, 17)], pal)  # гак-дзьоб назад
    fill(im, [(cx - 2, 9), (cx + 2, 9), (cx + 2, 16), (cx - 2, 16)], pal[1:], axis_x=cx)  # муфта, темніша за лезо
    im.putpixel((cx, 12), pal[3] + (255,))  # заклепка
    fill(im, [(cx - 2, 41), (cx + 2, 41), (cx + 2, 44), (cx - 2, 44)], pal[1:], axis_x=cx)  # окуття
    for y in range(7, 23):
        im.putpixel((w - 2, y), pal[0] + (255,))  # лезо блищить
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for metal in METAL:
        sword(metal).save(OUT + f"{metal}_sword.png")
    dagger().save(OUT + "iron_dagger.png")
    mace().save(OUT + "iron_mace.png")
    halberd().save(OUT + "iron_halberd.png")
    print("drawn", OUT)
