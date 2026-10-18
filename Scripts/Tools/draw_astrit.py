"""Малює Астрит (D221): жінка-варварка з величезним шипастим щитом і книгою ([[lore]]), у стилі героя.

Кадр 64x64 як у героя (Sprites/Player), у грі ×1.5; ступні на рядку FEET, обличчям праворуч.
Три листи по 12 кадрів для companion_astrit.tscn: enter (забіг), strike (присід — наскок щитом —
повернення; влучання на кадрі 5, strike_frame), run (відхід). Плюс portrait.tres з голови.
Запуск: python Scripts/Tools/draw_astrit.py
"""

import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from draw_enemy_sheets import OUTLINE, Canvas, ellipse, flat, lit  # noqa: E402

OUT = "SampleProject/Assets/Characters/Companions/astrit/"
S = 64
FEET = 58
FRAMES = 12

SKIN = [(246, 200, 156), (226, 170, 128), (184, 124, 92), (136, 86, 66)]
HAIR = [(232, 104, 58), (196, 70, 42), (146, 46, 34), (98, 30, 28)]
FUR = [(214, 196, 168), (172, 150, 120), (128, 106, 84), (86, 70, 58)]
LEATHER = [(150, 98, 64), (118, 74, 48), (88, 54, 38), (62, 38, 30)]
WOOD = [(196, 140, 84), (164, 108, 62), (126, 80, 48), (90, 56, 38)]
IRON = [(214, 214, 220), (160, 162, 174), (112, 114, 128), (72, 72, 86)]
BOOK = [(96, 70, 150), (70, 48, 120), (50, 34, 92), (34, 22, 64)]
PAGE = (250, 238, 206)
GLOW = (170, 230, 255)
PAINT = (60, 110, 190)
EYE = [(70, 150, 80), (40, 104, 56)]


def poly(points):
    """Пікселі всередині многокутника (з краєм)."""
    m = Image.new("L", (S, S))
    ImageDraw.Draw(m).polygon(points, fill=255)
    px = m.load()
    return {(x, y) for y in range(S) for x in range(S) if px[x, y]}


def vgrad(y0, y1, pal):
    """Тон згори вниз: світло зверху (світло з неба), тінь знизу."""

    def f(x, y):
        k = (y - y0) / max(y1 - y0, 1)
        return pal[0 if k < 0.2 else 1 if k < 0.65 else 2]

    return f


def leg(c, hip, foot, pal=LEATHER, boot=FUR):
    hx, hy = hip
    fx, fy = foot
    c.part(
        poly([(hx - 3, hy), (hx + 3, hy), (fx + 3, fy - 5), (fx - 3, fy - 5)]),
        vgrad(hy, fy, SKIN),
    )
    c.part(
        poly([(fx - 4, fy - 6), (fx + 3, fy - 6), (fx + 5, fy), (fx - 4, fy)]),
        vgrad(fy - 6, fy, boot),
    )


def eye(c, x, y):
    """Око як у героя, але зелене, з бликом; над ним густа брова."""
    c.part(
        ellipse(x + 2.5, y + 3, 2.8, 3.2),
        lambda px, py: EYE[0] if py < y + 4 else EYE[1],
    )
    c.put(x + 1, y + 2, (255, 255, 255))
    c.put(x + 2, y + 2, (255, 255, 255))
    for i in range(6):
        c.put(x - 1 + i, y - 1, OUTLINE)


def astrit(
    dx=0,
    bob=0,
    stride=0.0,
    crouch=0,
    shield_dx=0,
    shield_dy=0,
    hair_flow=0,
    impact=False,
    book_lift=0,
):
    """Одна поза. dx — зсув усього тіла, stride — фаза кроку (−1..1), crouch — присід,
    shield_dx/dy — винос щита, hair_flow — грива назад від руху."""
    c = Canvas(S, S)
    cx = 28 + dx
    hip_y = FEET - 16 + crouch + bob
    # задня нога, коса, задня рука з книгою — за тілом
    back_foot = (cx - 2 - round(stride * 6), FEET)
    front_foot = (cx + 3 + round(stride * 6), FEET)
    lift_b = 2 if stride > 0.3 else 0
    lift_f = 2 if stride < -0.3 else 0
    leg(c, (cx - 2, hip_y), (back_foot[0], FEET - lift_b))
    head_cx, head_cy = cx + 1, hip_y - 23 + crouch // 2
    # грива: густе волосся спадає по спині до пояса, віється від руху
    for i in range(18):
        bx = head_cx - 8 - i // 2 - (hair_flow * i) // 8
        by = head_cy - 3 + i
        r = 5.0 - i * 0.14
        c.part(ellipse(bx, by, r, 2.8), lit(bx, by, r, 2.8, HAIR))
    # розкрита книга в задній руці на рівні плеча, світиться (тавматургія)
    bkx, bky = cx - 13, hip_y - 16 - book_lift
    for (x, y) in ellipse(bkx + 3, bky + 1, 8, 6):
        if 0 <= x < S and 0 <= y < S and c.px[x, y][3] == 0:
            c.put(x, y, GLOW + (80,))
    c.part(poly([(bkx - 2, bky - 2), (bkx + 3, bky), (bkx + 8, bky - 2), (bkx + 8, bky + 4), (bkx + 3, bky + 6), (bkx - 2, bky + 4)]), vgrad(bky - 2, bky + 6, BOOK))
    for (x, y) in poly([(bkx - 1, bky - 1), (bkx + 3, bky + 1), (bkx + 7, bky - 1), (bkx + 7, bky + 2), (bkx + 3, bky + 4), (bkx - 1, bky + 2)]):
        c.put(x, y, PAGE)
    for k in range(3):
        c.put(bkx + 1 + k * 2, bky + 1, (180, 160, 200))
    c.put(bkx + 3, bky - 3, GLOW)
    c.put(bkx + 3, bky - 5, GLOW)
    c.part(poly([(cx - 5, hip_y - 13), (cx - 2, hip_y - 12), (bkx + 4, bky + 5), (bkx + 1, bky + 5)]), vgrad(bky, hip_y - 12, SKIN))
    # тулуб: шкіряний верх і хутряна спідниця
    c.part(
        poly(
            [
                (cx - 6, hip_y - 15),
                (cx + 6, hip_y - 15),
                (cx + 6, hip_y),
                (cx - 6, hip_y),
            ]
        ),
        vgrad(hip_y - 15, hip_y, LEATHER),
    )
    c.part(
        poly(
            [
                (cx - 7, hip_y - 2),
                (cx + 7, hip_y - 2),
                (cx + 8, hip_y + 6),
                (cx - 8, hip_y + 6),
            ]
        ),
        vgrad(hip_y - 2, hip_y + 6, FUR),
    )
    for x in range(cx - 6, cx + 7, 3):
        c.put(x, hip_y + 6, FUR[3])
    c.part(
        poly(
            [
                (cx - 7, hip_y - 3),
                (cx + 7, hip_y - 3),
                (cx + 7, hip_y - 1),
                (cx - 7, hip_y - 1),
            ]
        ),
        flat(LEATHER, 3),
    )
    c.put(cx + 1, hip_y - 2, (230, 190, 80))
    # передня нога
    leg(c, (cx + 3, hip_y + 2), (front_foot[0], FEET - lift_f))
    # хутряна накидка на плечах
    c.part(ellipse(cx, hip_y - 15, 9, 4.5), lit(cx, hip_y - 15, 9, 4.5, FUR))
    for x in range(cx - 8, cx + 9, 2):
        c.put(x, hip_y - 11, FUR[3])
    # голова: велика, чибі
    c.part(ellipse(head_cx, head_cy, 10, 9.5), lit(head_cx, head_cy, 10, 9.5, SKIN))
    # волосся: маківка й потилиця, обличчя відкрите; пасмо на чолі
    hair = {p for p in ellipse(head_cx - 1, head_cy - 2, 11, 9) if p[1] < head_cy - 5 or p[0] < head_cx - 3}
    c.part(hair, lit(head_cx - 1, head_cy - 2, 11, 9, HAIR))
    for i in range(4):
        c.put(head_cx + 2 + i, head_cy - 5 + (i // 2), HAIR[1])
        c.put(head_cx + 2 + i, head_cy - 6, HAIR[0] if i % 2 else HAIR[1])
    eye(c, head_cx + 2, head_cy - 2)
    c.put(head_cx + 6, head_cy - 3, OUTLINE)  # вії
    c.put(head_cx + 7, head_cy - 4, OUTLINE)
    for i in range(3):  # бойове розфарбування під оком
        c.put(head_cx + 2 + i, head_cy + 4, PAINT)
    c.put(head_cx + 6, head_cy + 3, (236, 140, 120))  # рум'янець
    c.put(head_cx + 8, head_cy + 5, (150, 60, 60))  # рот
    c.put(head_cx + 7, head_cy + 5, (150, 60, 60))
    # величезний щит на передній руці: овал із залізним ободом і шипами
    sx, sy = cx + 9 + shield_dx, hip_y - 6 + shield_dy
    c.part(ellipse(sx, sy, 7, 13.5), lit(sx, sy, 7, 13.5, IRON))
    c.part(ellipse(sx + 0.5, sy, 5.5, 12), lit(sx, sy, 5.5, 12, WOOD))
    for yy in range(sy - 10, sy + 11, 4):  # дошки
        c.put(sx - 2, yy, WOOD[3])
        c.put(sx + 2, yy + 2, WOOD[3])
    c.part(ellipse(sx + 1, sy, 2.5, 2.5), lit(sx + 1, sy, 2.5, 2.5, IRON))  # умбон
    for oy in (-8, 0, 8):  # шипи вперед
        for k in range(4):
            c.put(sx + 6 + k, sy + oy, IRON[1] if k < 3 else IRON[0])
        c.put(sx + 6, sy + oy - 1, OUTLINE)
        c.put(sx + 6, sy + oy + 1, OUTLINE)
    # передня рука тримає щит
    c.part(ellipse(sx - 4, sy - 1, 3, 2.5), lit(sx - 4, sy - 1, 3, 2.5, SKIN))
    if impact:
        for k, (ox, oy) in enumerate([(12, -12), (14, 0), (12, 12), (16, -6), (16, 6)]):
            for i in range(3):
                c.put(
                    sx + ox + i,
                    sy + oy + (i if oy > 0 else -i if oy < 0 else 0),
                    (255, 255, 255),
                )
    return c.im


def run_cycle():
    return [
        astrit(
            bob=-abs(round(math.sin(i / FRAMES * math.tau * 2))),
            stride=math.sin(i / FRAMES * math.tau * 2),
            hair_flow=2,
        )
        for i in range(FRAMES)
    ]


def strike_cycle():
    """0–3 присід і замах щитом, 4–5 наскок (5 — влучання), 6–11 повернення в стійку."""
    poses = [
        dict(crouch=1),
        dict(crouch=2, shield_dx=-2),
        dict(crouch=3, shield_dx=-3, book_lift=2),
        dict(crouch=3, shield_dx=-4, book_lift=3),
        dict(dx=6, bob=-3, shield_dx=4, hair_flow=4, stride=0.6),
        dict(dx=10, bob=-1, shield_dx=8, hair_flow=4, stride=0.8, impact=True),
        dict(dx=9, shield_dx=6, hair_flow=3, stride=0.5),
        dict(dx=7, shield_dx=4, hair_flow=2, stride=0.3),
        dict(dx=5, shield_dx=2, hair_flow=1),
        dict(dx=3, shield_dx=1),
        dict(dx=1),
        dict(),
    ]
    return [astrit(**p) for p in poses]


def sheet(frames):
    out = Image.new("RGBA", (S * len(frames), S))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * S, 0))
    return out


if __name__ == "__main__":
    run = sheet(run_cycle())
    run.save(OUT + "enter.png")
    run.save(OUT + "run.png")
    sheet(strike_cycle()).save(OUT + "strike.png")
    print("drawn", OUT)
