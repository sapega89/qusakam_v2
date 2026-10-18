"""Кадри удару героя і шлейф замаху (D224). Ритм і форма дуги — за листом атаки
assets/idle and  alter/itch light atk sheet-Sheet.png: присід-замах, суцільний півмісяць через голову,
тонкий слід, повернення; другий удар серії — знизу вгору (той самий півмісяць, віддзеркалений).

Тіло: з кадру стійки героя (Sprites/Player/Walk/1.png) — верх тіла (вище пояса, рядок SPLIT) зсувається:
присід назад-униз, нахил уперед, дотягування; ноги на місці. -> Sprites/Player/Attack/1..4.png
Шлейф: суцільний сіро-блакитний півмісяць (дуга) і пряма смуга (укол) по 3 кадри, центр обертання —
середина картинки (дуга) / лівий край (укол). -> Assets/FX/Smear/arc_1..3.png, thrust_1..3.png
Запуск: python Scripts/Tools/draw_hero_attack.py
"""

import math
import os

from PIL import Image

HERO = "SampleProject/Sprites/Player/Walk/1.png"
BODY_OUT = "SampleProject/Sprites/Player/Attack/"
FX_OUT = "SampleProject/Assets/FX/Smear/"
SPLIT = 47  # пояс героя: вище — верх тіла, нижче — ноги

SMEAR = (214, 228, 244, 235)
SMEAR_EDGE = (255, 255, 255, 255)
R = 32  # зовнішній радіус дуги, px текстури


def body_frames():
    src = Image.open(HERO).convert("RGBA")
    legs = src.crop((0, SPLIT, 64, 64))
    top = src.crop((0, 0, 64, SPLIT))
    # (зсув верху x, y): присід-замах назад, удар уперед, дотягування, стійка
    out = []
    for dx, dy in [(-3, 3), (5, 1), (3, 0), (0, 0)]:
        f = Image.new("RGBA", (64, 64))
        f.alpha_composite(legs, (0, SPLIT))
        f.alpha_composite(top, (dx, dy))
        out.append(f)
    return out


def arc(start, end, thick, size=72):
    """Півмісяць навколо центру: кут 0 — угору, + — за годинниковою (вперед для героя праворуч).
    Товщина росте від 1 на початку до [param thick] на кінці дуги; передній край — білий."""
    im = Image.new("RGBA", (size, size))
    px = im.load()
    c = size / 2
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            r = math.hypot(dx, dy)
            ang = math.degrees(
                math.atan2(dx, -dy)
            )  # 0 угору, 90 праворуч, 180 донизу, -90 ліворуч
            if ang < start - 180:
                ang += 360
            if not (start <= ang <= end) or r > R:
                continue
            k = (ang - start) / max(end - start, 1)
            t = 1 + (thick - 1) * k**0.8
            t *= min(1.0, 0.35 + (end - ang) / 14.0)  # кінець закруглений, не клин
            if r < R - t:
                continue
            px[x, y] = SMEAR_EDGE if r > R - 1.2 or ang > end - 6 else SMEAR
    return im


def thrust(length, thick, size=(72, 24)):
    """Пряма смуга уколу від лівого краю: товстішає до вістря, вістря — біле."""
    w, h = size
    im = Image.new("RGBA", size)
    px = im.load()
    cy = h / 2
    for x in range(min(length, w)):
        k = x / max(length, 1)
        t = 1 + (thick - 1) * k
        for y in range(h):
            if abs(y + 0.5 - cy) <= t / 2:
                px[x, y] = (
                    SMEAR_EDGE
                    if x > length - 4 or abs(y + 0.5 - cy) > t / 2 - 1
                    else SMEAR
                )
    return im


if __name__ == "__main__":
    os.makedirs(BODY_OUT, exist_ok=True)
    os.makedirs(FX_OUT, exist_ok=True)
    for i, f in enumerate(body_frames()):
        f.save(BODY_OUT + f"{i + 1}.png")
    # як у референсі: повний півмісяць, той самий пізніше й тонший, тонкий слід
    for i, (s, e, t) in enumerate([(-40, 150, 18), (10, 165, 12), (90, 175, 3)]):
        arc(s, e, t).save(FX_OUT + f"arc_{i + 1}.png")
    for i, (length, t) in enumerate([(72, 12), (60, 8), (44, 3)]):
        thrust(length, t).save(FX_OUT + f"thrust_{i + 1}.png")
    print("drawn", BODY_OUT, FX_OUT)
