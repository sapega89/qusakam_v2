"""Каньйон (D227): Скеля Прайду («Король Лев») — кам'яний навіс над каньйоном з уступами на спині —
і далекі стіни каньйону для паралаксу. Піксель-арт у масштабі фону (текстура ×1.5 у грі).

Скеля збігається з невидимою колізією з Scripts/Tools/build_canyon.gd: верх навісу — рядок 4 тайлів
(y 128), горб — рядок 3, низ навісу — рядок 6, уступи — односторонні полиці. Картинка покриває стовпці
33–63, рядки 2–12 (x 1056–2016, y 64–384); у текстурі все ÷1.5.
Запуск: python Scripts/Tools/draw_canyon.py
"""

import math
import random

from PIL import Image, ImageDraw

OUT = "SampleProject/Assets/Backgrounds/Canyon/"
TILE = 32
X0, Y0 = 33 * TILE, 2 * TILE  # лівий верх картинки скелі у світі
W, H = round(30 * TILE / 1.5), round(10 * TILE / 1.5)

# Пісковик кольору «Короля Лева»: світло, основа, смуга, тінь, глибока тінь, контур.
SAND = [(240, 186, 120), (214, 150, 92), (190, 126, 78), (160, 100, 64), (120, 72, 50)]
EDGE = (84, 50, 40)

# Колізія (тайли): навіс і уступи — ті самі числа, що в build_canyon.gd
SHELF = [  # (рядок, перший стовпець, останній стовпець)
    (3, 40, 49),
    (4, 35, 51),
    (5, 37, 51),
]
LEDGES = [(10, 59, 61), (8, 56, 58), (6, 53, 55)]


def to_tex(x, y):
    return ((x - X0) / 1.5, (y - Y0) / 1.5)


def organic(points, rng, jitter=5.0, step=10.0):
    """Ламана з опорних точок: густіше точки, кожна зсунута шумом — нерівний кам'яний обрис."""
    out = []
    for i in range(len(points)):
        (x0, y0), (x1, y1) = points[i], points[(i + 1) % len(points)]
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
        for k in range(n):
            t = k / n
            j = jitter * (0.3 if k == 0 else 1.0)
            out.append((x0 + (x1 - x0) * t + rng.uniform(-j, j) * 0.4, y0 + (y1 - y0) * t + rng.uniform(-j, j)))
    return [to_tex(x, y) for x, y in out]


def shelf_points():
    """Навіс: гострий ніс ліворуч (рядок 4), горб (рядок 3), товщає до спини, брилистий низ."""
    T = TILE
    return [(34 * T + 20, 4 * T + 22), (36 * T, 4 * T + 2), (39 * T, 4 * T - 4), (40 * T + 10, 3 * T + 4),
            (44 * T, 3 * T - 6), (48 * T, 3 * T - 2), (50 * T + 16, 3 * T + 14), (52 * T + 10, 4 * T + 20),
            (53 * T, 6 * T), (52 * T, 7 * T + 10), (49 * T, 7 * T + 2), (46 * T, 6 * T + 20), (43 * T, 6 * T + 10),
            (40 * T, 6 * T - 2), (37 * T, 5 * T + 16)]


def support_points():
    """Опора позаду навісу аж до землі (декор, без колізії — під навісом прохід)."""
    T = TILE
    return [(46 * T, 6 * T + 10), (52 * T, 6 * T), (55 * T, 8 * T), (58 * T + 10, 11 * T), (60 * T, 12 * T),
            (44 * T, 12 * T), (45 * T, 10 * T), (44 * T + 20, 8 * T)]


def ledge_points(row, c0, c1):
    T = TILE
    top = row * T
    return [(c0 * T - 6, top + 2), (c0 * T + 6, top - 1), ((c1 + 1) * T - 6, top - 1), ((c1 + 1) * T + 6, top + 4),
            ((c1 + 1) * T - 4, top + 26), (c0 * T + 26, top + 44), (c0 * T + 4, top + 24)]


def paint_rock(im, polygon, rng, shade=0):
    """Заливка з горизонтальними шарами породи, світлим верхом, тінню знизу, контуром і тріщинами."""
    mask = Image.new("L", im.size)
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    m, px = mask.load(), im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if not m[x, y]:
                continue
            above = y > 0 and m[x, y - 1]
            above2 = y > 1 and m[x, y - 2]
            below = y < h - 1 and m[x, y + 1]
            below3 = y < h - 3 and m[x, y + 3]
            edge = not (
                above and below and x > 0 and m[x - 1, y] and x < w - 1 and m[x + 1, y]
            )
            if edge:
                px[x, y] = EDGE + (255,)
                continue
            band = (y + int(3 * math.sin(x / 23.0))) // 7 % 3  # хвилясті шари
            i = [1, 2, 1][band]
            if not above2:
                i = 0  # верх освітлений небом
            elif not below3:
                i = 4  # низ навісу — у тіні
            elif not below or rng.random() < 0.05:
                i = 3
            px[x, y] = SAND[min(i + shade, 4)] + (255,)
    for _ in range(len(polygon) // 2):  # тріщини
        x, y = rng.randrange(w), rng.randrange(h)
        for k in range(rng.randrange(3, 8)):
            xx, yy = x + k // 3, y + k
            if 0 <= xx < w and 0 <= yy < h and m[xx, yy] and px[xx, yy][:3] != EDGE:
                px[xx, yy] = SAND[4] + (255,)


def pride_rock():
    rng = random.Random(3)
    im = Image.new("RGBA", (W, H))
    paint_rock(im, organic(support_points(), rng, 8.0), rng, shade=1)  # опора позаду — на тон темніша
    for row, c0, c1 in LEDGES:
        paint_rock(im, organic(ledge_points(row, c0, c1), rng, 3.0, 8.0), rng)
    paint_rock(im, organic(shelf_points(), rng, 5.0), rng)
    im.save(OUT + "pride_rock.png")


def canyon_walls():
    """Далекі стіни каньйону: мези й урвища з шарами породи, у серпанку; тайлиться по 576 px."""
    rng = random.Random(9)
    w, h = 576, 324
    im = Image.new("RGBA", (w, h))
    px = im.load()
    sky = (214, 214, 224)
    pal = [tuple(round(a * 0.55 + b * 0.45) for a, b in zip(c, sky)) for c in SAND]
    edge = tuple(round(a * 0.6 + b * 0.4) for a, b in zip(EDGE, sky))
    # силует: висота стіни по x — кілька мез з крутими боками, безшовно по краях
    tops = []
    for x in range(w):
        t = (
            150
            + 40 * math.sin(x / w * math.tau * 2)
            + 22 * math.sin(x / w * math.tau * 5 + 1.3)
        )
        step = (x // 48) % 4
        t += [0, -28, 10, -12][step]
        tops.append(int(t))
    for x in range(w):
        for y in range(tops[x], 262):
            band = (y + int(2 * math.sin(x / 17.0))) // 9 % 3
            i = 0 if y < tops[x] + 3 else [1, 2, 1][band]
            if y > 240:
                i = 3
            if rng.random() < 0.03:
                i = min(i + 1, 4)
            edge_px = (
                y == tops[x]
                or (x > 0 and tops[x - 1] > y)
                or (x < w - 1 and tops[x + 1] > y)
            )
            px[x, y] = (edge if edge_px else pal[i]) + (255,)
    im.save(OUT + "canyon_walls.png")


if __name__ == "__main__":
    import os

    os.makedirs(OUT, exist_ok=True)
    pride_rock()
    canyon_walls()
    print("drawn", OUT, W, H)
