"""Шлейфи удару героя (D224, D232). Ритм і форма дуги — за листом атаки
assets/idle and  alter/itch light atk sheet-Sheet.png: суцільний півмісяць через голову, тонкий слід;
другий удар серії — знизу вгору (той самий півмісяць, віддзеркалений).

Кадри тіла тут більше не малюються: удар бере кадри художника (Player.tscn → Attack: біг 4 — замах,
біг 2 — удар з рукою вперед, біг 1 — дотяг, хода 1 — стійка; D232).
Шлейф: суцільний сіро-блакитний півмісяць (дуга) і пряма смуга (укол) по 3 кадри, центр обертання —
середина картинки (дуга) / лівий край (укол). Удар кулаком — короткий «вибух» біля рукавиці.
-> Assets/FX/Smear/arc_1..3.png, thrust_1..3.png, punch_1..3.png
Запуск: python Scripts/Tools/draw_hero_attack.py
"""

import math
import os

from PIL import Image

FX_OUT = "SampleProject/Assets/FX/Smear/"

SMEAR = (214, 228, 244, 235)
SMEAR_EDGE = (255, 255, 255, 255)
R = 32  # зовнішній радіус дуги, px текстури


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


def punch(size, rays, core, ring, alpha=255):
    """«Вибух» удару кулаком: біле ядро, промені різної довжини, тонке кільце (аніме-кадр удару)."""
    im = Image.new("RGBA", (size, size))
    px = im.load()
    c = size / 2
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            r = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            if r <= core:
                px[x, y] = (255, 255, 255, alpha)
                continue
            if ring and abs(r - ring) < 0.9:
                px[x, y] = (255, 236, 190, alpha)
                continue
            for k in range(8):  # промені: довгі й короткі по черзі
                a0 = k * math.pi / 4 + 0.2
                length = rays * (1.0 if k % 2 == 0 else 0.6)
                if abs(math.atan2(math.sin(ang - a0), math.cos(ang - a0))) < 0.16 * (1 - r / max(length, 1)) + 0.04 and r <= length:
                    px[x, y] = (255, 230, 160, alpha) if r > core + 2 else (255, 255, 255, alpha)
    return im


if __name__ == "__main__":
    os.makedirs(FX_OUT, exist_ok=True)
    # як у референсі: повний півмісяць, той самий пізніше й тонший, тонкий слід
    for i, (s, e, t) in enumerate([(-40, 150, 18), (10, 165, 12), (90, 175, 3)]):
        arc(s, e, t).save(FX_OUT + f"arc_{i + 1}.png")
    for i, (length, t) in enumerate([(72, 12), (60, 8), (44, 3)]):
        thrust(length, t).save(FX_OUT + f"thrust_{i + 1}.png")
    # кулак: спалах із променями → кільце, що розходиться → згасання
    for i, (rays, core, ring, alpha) in enumerate([(13, 4, 0, 255), (12, 2, 9, 230), (8, 0, 12, 140)]):
        punch(28, rays, core, ring, alpha).save(FX_OUT + f"punch_{i + 1}.png")
    print("drawn", FX_OUT)
