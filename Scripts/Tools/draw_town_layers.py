"""Малює шари фону для поселень (D219): будинки села, мур і забудова міста, стіна зали мера.

Піксель-арт у масштабі фону Desert Oasis (текстура 576 px завширшки, у грі ×1.5 = 864 = клітинка MetSys).
Світло рівне, згори, без сонця й довгих тіней ([[lore]]). Низ будівель — на рядку 256 текстури (= підлога
y 384 у кімнаті), трохи нижче, щоб основа ховалась за тайлами.
Запуск: python Scripts/Tools/draw_town_layers.py  (seed фіксований — результат той самий щоразу)
"""

import math
import random
from PIL import Image

OUT = "SampleProject/Assets/Backgrounds/Town/"
W = 576
BASE = 260  # низ будівель у текстурі (підлога — 256)

# Глина / пісковик: світло, основа, тінь, глибока тінь, контур (м'якший за контур персонажів — це фон).
ADOBE = [(236, 204, 150), (214, 172, 118), (184, 140, 94), (150, 108, 72)]
ADOBE_RED = [(226, 170, 122), (200, 138, 96), (168, 110, 76), (132, 84, 60)]
PLASTER = [(244, 232, 208), (226, 212, 186), (196, 180, 154), (160, 144, 122)]
EDGE = (110, 74, 52)
WOOD = (112, 72, 46)
DARK = (64, 40, 34)
CLOTH = [(186, 66, 50), (60, 130, 132), (212, 158, 60), (128, 70, 120)]


class Pix:
    def __init__(self, w, h, fill=(0, 0, 0, 0)):
        self.im = Image.new("RGBA", (w, h), fill)
        self.px = self.im.load()
        self.w, self.h = w, h

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c if len(c) == 4 else c + (255,)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.put(x, y, c)


def block(p, rng, x0, y0, w, h, pal=ADOBE, round_top=True):
    """Глинобитний обʼєм: верх світліший (світло з неба), низ темніє до землі, легкий шум, контур."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if round_top and y == y0 and x in (x0, x0 + w - 1):
                continue
            d = y - y0
            i = 0 if d < 2 else 1 if d < h - 6 else 2
            if rng.random() < 0.06:
                i = min(i + 1, 3)
            edge = (
                x in (x0, x0 + w - 1)
                or y in (y0, y0 + h - 1)
                or (round_top and y == y0 + 1 and x in (x0, x0 + w - 1))
            )
            p.put(x, y, EDGE if edge else pal[i])
    # кілька тріщин
    for _ in range(w * h // 600):
        cx, cy = rng.randrange(x0 + 3, x0 + w - 3), rng.randrange(y0 + 4, y0 + h - 4)
        for k in range(rng.randrange(2, 5)):
            p.put(cx + k // 2, cy + k, pal[3])


def door(p, x, y_base, w=9, h=15, arch=True):
    for y in range(y_base - h, y_base):
        for x0 in range(x, x + w):
            top = y_base - h
            if arch and y < top + w // 2:
                r = w / 2
                if (x0 + 0.5 - x - r) ** 2 + (y + 0.5 - top - r) ** 2 > r * r:
                    continue
            p.put(x0, y, DARK)
    for y in range(y_base - h + w // 2, y_base):  # одвірок
        p.put(x - 1, y, EDGE)
        p.put(x + w, y, EDGE)


def window(p, x, y, w=5, h=6, shutter=None):
    p.rect(x, y, x + w, y + h, DARK)
    p.rect(x - 1, y + h, x + w + 1, y + h + 1, EDGE)
    if shutter:
        p.rect(x - 2, y, x, y + h, shutter)
        p.rect(x + w, y, x + w + 2, y + h, shutter)


def beams(p, x0, w, y, rng):
    """Кінці балок (vigas) під дахом."""
    for x in range(x0 + 3, x0 + w - 3, rng.choice((6, 7, 8))):
        p.put(x, y, WOOD)
        p.put(x + 1, y, WOOD)
        p.put(x, y + 1, DARK)


def awning(p, x0, w, y, color):
    for i in range(w):
        p.put(x0 + i, y, EDGE)
        for d in range(1, 4):
            p.put(
                x0 + i,
                y + d,
                color if (i // 3) % 2 == 0 else tuple(min(255, c + 40) for c in color),
            )
        p.put(x0 + i, y + 4 + (i % 3 == 0), color)


def dome(p, cx, base_y, r, pal=PLASTER):
    for y in range(base_y - r, base_y + 1):
        for x in range(cx - r, cx + r + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - base_y
            if dx * dx + dy * dy <= r * r:
                edge = dx * dx + dy * dy > (r - 1.2) ** 2
                i = 0 if dy < -r * 0.6 else 1 if dx < r * 0.3 else 2
                p.put(x, y, EDGE if edge else pal[i])
    p.put(cx, base_y - r - 1, EDGE)
    p.put(cx, base_y - r - 2, EDGE)


def house(p, rng, x0, w, h, pal=ADOBE, storeys=1):
    y0 = BASE - h
    block(p, rng, x0, y0, w, h, pal)
    beams(p, x0, w, y0 + 3, rng)
    door(p, x0 + rng.randrange(4, max(5, w - 14)), BASE, 9, min(16, h - 6))
    for wx in range(x0 + 5, x0 + w - 8, rng.choice((14, 16, 18))):
        if rng.random() < 0.7:
            window(p, wx, y0 + 8, 5, 6, rng.choice((None, None, WOOD)))
    if storeys > 1:
        uw = rng.randrange(w // 2, w - 8)
        ux = x0 + rng.randrange(2, w - uw - 1)
        uh = rng.randrange(16, 24)
        block(p, rng, ux, y0 - uh + 1, uw, uh, pal)
        beams(p, ux, uw, y0 - uh + 4, rng)
        window(p, ux + uw // 2 - 2, y0 - uh + 8, 5, 6, WOOD)
    return y0


def village():
    rng = random.Random(7)
    p = Pix(W, 324)
    x = 10
    plan = [
        (64, 42, ADOBE, 1),
        (0, 0, None, 0),
        (78, 52, ADOBE_RED, 2),
        (56, 38, ADOBE, 1),
        (0, 0, None, 0),
        (90, 46, ADOBE, 2),
        (60, 40, ADOBE_RED, 1),
        (0, 0, None, 0),
    ]
    for w, h, pal, st in plan:
        if pal is None:
            x += 26  # прогалина — там видно пальми оазису з фону
            continue
        y0 = house(p, rng, x, w, h, pal, st)
        awning(p, x + 6, min(24, w - 12), y0 + h - 22, rng.choice(CLOTH))
        x += w + rng.randrange(6, 14)
    # глеки й низький тин між будинками
    for _ in range(9):
        jx = rng.randrange(8, W - 8)
        for y in range(BASE - 7, BASE):
            for xx in range(jx - 3, jx + 4):
                if (xx - jx) ** 2 / 9 + (y - BASE + 4) ** 2 / 12 <= 1:
                    p.put(xx, y, ADOBE_RED[2] if xx > jx else ADOBE_RED[1])
    p.im.save(OUT + "village_houses.png")


def haze(c, k=0.45, sky=(206, 214, 226)):
    return tuple(round(a * (1 - k) + b * k) for a, b in zip(c, sky))


def city_far():
    """Мур із зубцями, вежі з куполами й мінарети — у серпанку."""
    rng = random.Random(11)
    p = Pix(W, 324)
    pal = [haze(c) for c in ADOBE]
    edge = haze(EDGE, 0.35)
    wall_top = BASE - 70
    # силуети будинків за муром
    x = 0
    while x < W:
        w, h = rng.randrange(20, 46), rng.randrange(80, 120)
        p.rect(x, BASE - h, x + w, BASE, haze(ADOBE[2], 0.55))
        x += w + rng.randrange(-4, 4)
    for cx in (70, 250, 430):
        dome(
            p, cx, wall_top - 26, rng.randrange(12, 17), [haze(c, 0.5) for c in PLASTER]
        )
    for mx in (150, 330, 520):
        p.rect(mx, wall_top - 70, mx + 6, wall_top, haze(ADOBE[1], 0.5))
        dome(p, mx + 3, wall_top - 70, 4, [haze(c, 0.5) for c in PLASTER])
    # мур
    for y in range(wall_top, BASE):
        for xx in range(W):
            i = 0 if y < wall_top + 3 else 1 if y < BASE - 10 else 2
            if (y - wall_top) % 10 == 0 or (
                (xx + (5 if (y - wall_top) // 10 % 2 else 0)) % 20 == 0
            ):
                i = min(i + 1, 3)
            p.put(xx, y, pal[i])
    for xx in range(0, W, 12):  # зубці
        p.rect(xx, wall_top - 6, xx + 7, wall_top, pal[1])
        p.rect(xx, wall_top - 6, xx + 7, wall_top - 5, pal[0])
    for tx in (30, 200, 380, 540):  # вежі
        p.rect(tx - 12, wall_top - 28, tx + 12, BASE, pal[1])
        p.rect(tx - 12, wall_top - 28, tx + 12, wall_top - 25, pal[0])
        for xx in range(tx - 12, tx + 12, 6):
            p.rect(xx, wall_top - 34, xx + 4, wall_top - 28, pal[1])
        p.rect(tx - 2, wall_top - 14, tx + 2, wall_top - 6, haze(DARK, 0.3))
        for y in range(wall_top - 34, BASE):
            p.put(tx - 12, y, edge)
            p.put(tx + 11, y, edge)
    p.im.save(OUT + "city_far.png")


def city_near():
    rng = random.Random(23)
    p = Pix(W, 324)
    x = 4
    while x < W - 40:
        w = rng.randrange(52, 84)
        h = rng.randrange(44, 64)
        pal = rng.choice((ADOBE, ADOBE, ADOBE_RED, PLASTER))
        y0 = house(p, rng, x, w, h, pal, rng.choice((1, 2, 2)))
        awning(p, x + 4, w - 8, y0 + h - 24, rng.choice(CLOTH))
        if rng.random() < 0.4:
            dome(p, x + w // 2, y0 - 1, rng.randrange(8, 12))
        x += w + rng.randrange(2, 8)
    p.im.save(OUT + "city_near.png")


def mayor_hall():
    """Стіна зали: пісковикова кладка, арки-ніші з колонами, червоні прапори з монетою, фриз згори."""
    rng = random.Random(5)
    H = 320
    p = Pix(W, H, ADOBE[1] + (255,))
    stone = [(222, 186, 132), (204, 164, 112), (178, 138, 92), (146, 108, 74)]
    # кладка
    for y in range(H):
        row = y // 12
        for x in range(W):
            joint = y % 12 == 0 or (x + (12 if row % 2 else 0)) % 24 == 0
            i = 3 if joint else 0 if y % 12 == 1 else 1
            if not joint and rng.random() < 0.05:
                i = 2
            p.put(x, y, stone[i])
    # фриз і плінтус
    p.rect(0, 0, W, 22, stone[2])
    for x in range(0, W, 8):
        p.rect(x + 2, 6, x + 6, 16, stone[0])
    p.rect(0, 22, W, 24, EDGE)
    p.rect(0, 236, W, 256, stone[2])
    p.rect(0, 236, W, 237, EDGE)
    # арки-ніші
    for i, ax in enumerate(range(36, W, 144)):
        aw, top = 72, 70
        for y in range(top, 236):
            for x in range(ax, ax + aw):
                r = aw / 2
                if (
                    y < top + r
                    and (x + 0.5 - ax - r) ** 2 + (y + 0.5 - top - r) ** 2 > r * r
                ):
                    continue
                depth = 0.55 + 0.45 * (y - top) / (236 - top)
                c = tuple(round(v * depth) for v in (150, 104, 70))
                p.put(x, y, c)
        for y in range(top - 2, 236):  # обвідка арки
            for x in range(ax - 2, ax + aw + 2):
                r = aw / 2 + 2
                dx, dy = x + 0.5 - ax - aw / 2, y + 0.5 - top - aw / 2
                ring = (
                    (r - 3) ** 2 < dx * dx + dy * dy <= r * r
                    if y < top + aw / 2
                    else x in (ax - 2, ax - 1, ax + aw, ax + aw + 1)
                )
                if ring:
                    p.put(x, y, stone[0] if dy < 0 or x < ax else stone[2])
        # прапор у ніші
        bx = ax + aw // 2 - 12
        p.rect(bx - 2, top + 30, bx + 26, top + 32, WOOD)
        for y in range(top + 32, top + 110):
            for x in range(bx, bx + 24):
                if y > top + 100 and abs(x - bx - 12) < (y - top - 100) * 1.3:
                    continue
                c = CLOTH[0] if 2 < x - bx < 21 else (150, 46, 38)
                p.put(x, y, c)
        # монета — знак Уризена й міської казни
        gold = [(250, 214, 110), (226, 176, 70), (180, 130, 50)]
        for y in range(top + 56, top + 73):
            for x in range(bx + 4, bx + 21):
                d = (x + 0.5 - bx - 12.5) ** 2 + (y + 0.5 - top - 64.5) ** 2
                if d <= 64:
                    p.put(x, y, EDGE if d > 49 else gold[0] if y < top + 61 else gold[1] if d > 12 else gold[2])
    # колони між нішами
    for cx in range(0, W + 1, 144):
        p.rect(cx - 9, 24, cx + 9, 236, stone[1])
        p.rect(cx - 9, 24, cx - 6, 236, stone[0])
        p.rect(cx + 6, 24, cx + 9, 236, stone[2])
        p.rect(cx - 12, 24, cx + 12, 32, stone[0])
        p.rect(cx - 12, 226, cx + 12, 236, stone[2])
        for y in range(24, 236):
            p.put(cx - 10, y, EDGE)
            p.put(cx + 9, y, EDGE)
    p.im.save(OUT + "mayor_hall_wall.png")


if __name__ == "__main__":
    import os

    os.makedirs(OUT, exist_ok=True)
    village()
    city_far()
    city_near()
    mayor_hall()
    print("drawn", OUT)
