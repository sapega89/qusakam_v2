"""Монета помочі Уризена (assist_coin.tscn): 12 кадрів обертання 16×16 у ряд, 24 к/с, ×3 у грі.
A9 (2026-10-28, D813 «поправити»): була стокова монета Brackeys з «0» — тепер торгова монета пустелі в стилі героя:
контур героя, золото зі світлом зліва-згори, темніший обідок, квадратний отвір посередині (видно, коли монета
повернута лицем), на ребрі — смуга обідка. Без моделі.
Запуск: python Scripts/Tools/draw_coin.py
"""

import math

from PIL import Image

OUT = "SampleProject/Assets/Characters/Companions/coin.png"
OUTLINE = (40, 23, 36, 255)  # контур героя (pixel_kit)
LIGHT, FACE, SHADE, RIM = (
    (255, 236, 140, 255),
    (238, 184, 60, 255),
    (198, 132, 36, 255),
    (150, 88, 30, 255),
)
SIZE, R, FRAMES = 16, 6.6, 12


def frame(turn):
    """turn — частка обороту: 0 лице, 0.25 ребро, 0.5 зворот."""
    c = abs(math.cos(turn * 2 * math.pi))
    rx = max(R * c, 1.2)
    im = Image.new("RGBA", (SIZE, SIZE))
    px = im.load()
    mid = (SIZE - 1) / 2
    inside = {
        (x, y)
        for y in range(SIZE)
        for x in range(SIZE)
        if ((x - mid) / (rx + 0.35)) ** 2 + ((y - mid) / (R + 0.35)) ** 2 <= 1
    }
    for x, y in inside:
        if any(
            (x + dx, y + dy) not in inside
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
        ):
            px[x, y] = OUTLINE
            continue
        u, v = (x - mid) / max(rx, 1e-6), (y - mid) / R
        if c < 0.35:  # ребро
            px[x, y] = RIM if abs(x - mid) > 0.6 else SHADE
        elif u * u + v * v > 0.62:  # обідок
            px[x, y] = SHADE if u + v > -0.3 else FACE
        elif (
            c > 0.6 and abs(x - mid) <= 1.0 * c and abs(y - mid) <= 1.0
        ):  # квадратний отвір
            px[x, y] = OUTLINE
        elif u + v < -0.55 and c > 0.5:
            px[x, y] = LIGHT
        else:
            px[x, y] = FACE
    return im


if __name__ == "__main__":
    sheet = Image.new("RGBA", (SIZE * FRAMES, SIZE))
    for i in range(FRAMES):
        sheet.paste(frame(i / FRAMES), (i * SIZE, 0))
    sheet.save(OUT)
    print("wrote", OUT)
