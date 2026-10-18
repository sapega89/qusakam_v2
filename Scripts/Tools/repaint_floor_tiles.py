"""Перемальовує верх піщаної підлоги в DesertTiles.png (D216, критика візуалу).

Верхні плитки Brackeys (атлас 7..9, 6) — окремі «блоки» з чорною рамкою: на екрані підлога читалась як
ряд маріо-блоків. Тут верх стає суцільною смугою з кольорів тієї ж плитки, а тіло — як плитка під нею
(8, 7). Чорний контур у піщаній частині атласу (стовпці 7..13, рядки 6..11) — темний пісок #6b4a2b.
Запуск: python Scripts/Tools/repaint_floor_tiles.py  (ідемпотентний — стару рамку не шукає вдруге).
"""
from PIL import Image

PATH = "SampleProject/Sprites/DesertTiles.png"
T = 32
OUTLINE = (53, 43, 38, 255)
SAND_DARK = (0x6B, 0x4A, 0x2B, 255)
# Смуга верху, згори вниз: кольори з самої верхньої плитки.
HI, MID, LOW = (243, 207, 149, 255), (216, 158, 88, 255), (182, 107, 58, 255)
CAP = [SAND_DARK] + [HI] * 3 + [MID] * 6 + [LOW] * 3 + [SAND_DARK]
TOP_TILES = [(7, 6), (8, 6), (9, 6)]
FILL = (8, 7)

im = Image.open(PATH).convert("RGBA")
px = im.load()
fill = im.crop((FILL[0] * T, FILL[1] * T, FILL[0] * T + T, FILL[1] * T + T))
for cx, cy in TOP_TILES:
    ox, oy = cx * T, cy * T
    im.paste(fill, (ox, oy))
    for y, c in enumerate(CAP):
        for x in range(T):
            px[ox + x, oy + y] = c
    # Кілька світлих плям на смузі, щоб не була пласкою (з тієї ж палітри), зі зсувом на кожну плитку.
    for x in range((cx * 11) % 7, T, 9):
        px[ox + x, oy + 2] = (226, 207, 164, 255)
        px[ox + (x + 4) % T, oy + 6] = LOW
        px[ox + (x + 5) % T, oy + 6] = LOW
for y in range(6 * T, 12 * T):
    for x in range(7 * T, 14 * T):
        if px[x, y] == OUTLINE:
            px[x, y] = SAND_DARK
im.save(PATH)
print("repainted", PATH)
