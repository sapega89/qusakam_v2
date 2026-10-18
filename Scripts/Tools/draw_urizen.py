"""Малює Уризена (D222): клірик, смайт у вигляді монети ([[lore]]), у стилі героя.

Біла ряса із золотою облямівкою, велика золота монета-оберіг на грудях, посох із монетним диском.
Кадр 64x64 як у героя, у грі ×1.5; ступні на рядку FEET, обличчям праворуч.
Листи по 12 кадрів для companion_urizen.tscn: enter (хода; ним же й відходить), strike (здіймає руку —
над нею спалахує монета; монети падають на ворогів на кадрі 6, strike_frame). Плюс portrait.tres.
Запуск: python Scripts/Tools/draw_urizen.py
"""

import math
import os
import sys


sys.path.insert(0, os.path.dirname(__file__))
from draw_astrit import FEET, S, SKIN, poly, sheet, vgrad  # noqa: E402
from pixel_kit import OUTLINE, Canvas, ellipse, lit  # noqa: E402

OUT = "SampleProject/Assets/Characters/Companions/urizen/"
FRAMES = 12

ROBE = [(250, 246, 236), (226, 220, 206), (186, 178, 164), (140, 132, 122)]
GOLD = [(255, 226, 120), (236, 186, 70), (190, 136, 46), (140, 94, 36)]
HAIR = [(120, 84, 60), (92, 62, 46), (66, 44, 36), (44, 30, 28)]
STAFF = [(170, 120, 74), (134, 90, 56), (98, 64, 44), (70, 46, 34)]
EYE = [(70, 110, 190), (44, 76, 150)]


def coin(c, x, y, r):
    """Золота монета з ободом і квадратним отвором, як у coin-смайта."""
    c.part(ellipse(x, y, r, r), lit(x, y, r, r, GOLD))
    for px, py in ellipse(x, y, r - 2, r - 2):
        if abs(px + 0.5 - x) < 1.2 and abs(py + 0.5 - y) < 1.2:
            c.put(px, py, GOLD[3])


def urizen(bob=0, stride=0.0, arm=0.0, glow=0.0, dx=0):
    """arm — 0 рука біля тіла … 1 піднята над головою; glow — 0..1 спалах монети в руці."""
    c = Canvas(S, S)
    cx = 30 + dx
    hip_y = FEET - 15 + bob
    # посох у задній руці
    st_x = cx - 13
    for y in range(hip_y - 36, FEET + 1):
        c.put(st_x, y, OUTLINE)
        c.put(st_x + 1, y, STAFF[1] if y % 5 else STAFF[2])
        c.put(st_x + 2, y, OUTLINE)
    coin(c, st_x + 1, hip_y - 39, 4)
    # ступні під рясою
    for fx in (cx - 3 - round(stride * 4), cx + 3 + round(stride * 4)):
        c.part(
            poly(
                [(fx - 3, FEET - 3), (fx + 4, FEET - 3), (fx + 4, FEET), (fx - 3, FEET)]
            ),
            vgrad(FEET - 3, FEET, STAFF),
        )
    # ряса: трапеція до п'ят із золотою облямівкою знизу
    robe = poly(
        [
            (cx - 6, hip_y - 15),
            (cx + 6, hip_y - 15),
            (cx + 9 + round(stride * 2), FEET - 2),
            (cx - 9 + round(stride * 2), FEET - 2),
        ]
    )
    c.part(robe, vgrad(hip_y - 15, FEET, ROBE))
    for x in range(cx - 8, cx + 10):
        if (x, FEET - 4) in robe:
            c.put(x, FEET - 4, GOLD[1])
    for y in range(hip_y - 12, FEET - 4):  # золота смуга-орар посередині
        if (cx + 1, y) in robe:
            c.put(cx + 1, y, GOLD[1])
            c.put(cx + 2, y, GOLD[2])
    # пояс
    c.part(
        poly(
            [
                (cx - 7, hip_y - 3),
                (cx + 7, hip_y - 3),
                (cx + 7, hip_y - 1),
                (cx - 7, hip_y - 1),
            ]
        ),
        vgrad(hip_y - 3, hip_y, GOLD),
    )
    # задня рука тримає посох
    c.part(
        ellipse(st_x + 2, hip_y - 9, 2.5, 2.5), lit(st_x + 2, hip_y - 9, 2.5, 2.5, SKIN)
    )
    c.part(
        poly(
            [
                (cx - 6, hip_y - 14),
                (cx - 3, hip_y - 13),
                (st_x + 3, hip_y - 8),
                (st_x + 1, hip_y - 10),
            ]
        ),
        vgrad(hip_y - 14, hip_y - 8, ROBE),
    )
    # монета-оберіг на грудях
    coin(c, cx + 1, hip_y - 9, 3)
    # плечі-накидка з каптуром за спиною
    c.part(ellipse(cx, hip_y - 15, 8, 4), lit(cx, hip_y - 15, 8, 4, ROBE))
    for x in range(cx - 7, cx + 8):
        c.put(x, hip_y - 12, GOLD[2] if x % 2 else GOLD[1])
    # голова
    hx, hy = cx + 1, hip_y - 24
    c.part(
        ellipse(hx - 6, hy + 4, 5, 6), lit(hx - 6, hy + 4, 5, 6, ROBE)
    )  # каптур на спині
    c.part(ellipse(hx, hy, 9.5, 9), lit(hx, hy, 9.5, 9, SKIN))
    hair = {p for p in ellipse(hx - 1, hy - 2, 10, 8) if p[1] < hy - 5 or p[0] < hx - 4}
    c.part(hair, lit(hx - 1, hy - 2, 10, 8, HAIR))
    c.part(
        ellipse(hx + 3, hy + 1, 2.6, 3.0),
        lambda px, py: EYE[0] if py < hy + 2 else EYE[1],
    )
    c.put(hx + 2, hy, (255, 255, 255))
    for i in range(5):  # спокійна брова, не зла — це союзник
        c.put(hx + 1 + i, hy - 3, OUTLINE)
    c.put(hx + 7, hy + 5, (150, 80, 70))
    c.put(hx + 8, hy + 5, (150, 80, 70))
    # передня рука: від тіла вгору, у долоні монета
    ang = math.radians(-15 - arm * 72)
    sx, sy = cx + 5, hip_y - 13
    hx2, hy2 = sx + 2 + round(math.cos(ang) * 11), sy + round(math.sin(ang) * 11)
    c.part(
        poly(
            [(sx - 2, sy - 2), (sx + 2, sy + 2), (hx2 + 2, hy2 + 1), (hx2 - 1, hy2 - 2)]
        ),
        vgrad(min(sy, hy2), max(sy, hy2) + 1, ROBE),
    )
    c.part(ellipse(hx2, hy2, 2.5, 2.5), lit(hx2, hy2, 2.5, 2.5, SKIN))
    if glow > 0:
        r = 3 + round(glow * 3)
        for px, py in ellipse(hx2, hy2 - r - 2, r + 3, r + 3):
            if 0 <= px < S and 0 <= py < S and c.px[px, py][3] == 0:
                c.put(px, py, GOLD[0] + (int(110 * glow),))
        coin(c, hx2, hy2 - r - 2, r)
    return c.im


def walk_cycle():
    return [
        urizen(
            bob=-abs(round(math.sin(i / FRAMES * math.tau * 2))),
            stride=math.sin(i / FRAMES * math.tau * 2),
        )
        for i in range(FRAMES)
    ]


def strike_cycle():
    """0–4 рука здіймається, монета розгорається; 5–6 спалах (6 — монети падають); 7–11 рука опускається."""
    arm = [0.1, 0.3, 0.55, 0.8, 1.0, 1.0, 1.0, 1.0, 0.8, 0.55, 0.3, 0.1]
    glow = [0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0, 0.6, 0.3, 0.1, 0, 0]
    return [
        urizen(arm=a, glow=g, bob=-1 if 4 <= i <= 7 else 0)
        for i, (a, g) in enumerate(zip(arm, glow))
    ]


if __name__ == "__main__":
    sheet(walk_cycle()).save(OUT + "enter.png")
    sheet(strike_cycle()).save(OUT + "strike.png")
    print("drawn", OUT)
