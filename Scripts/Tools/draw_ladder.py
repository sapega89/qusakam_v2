"""Тайл драбини (D225) у стилі героя: дві дерев'яні тятиви й щабель, контур героя. 16x8, повторюється
вертикально (Ladder.tscn, texture_repeat), у грі ×1.5.
Запуск: python Scripts/Tools/draw_ladder.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pixel_kit import OUTLINE  # noqa: E402

WOOD = [(196, 142, 88), (158, 106, 62), (118, 76, 46)]
OUT = "SampleProject/Assets/Objects/ladder.png"

im = Image.new("RGBA", (16, 8))
px = im.load()
for y in range(8):
    for x0 in (1, 12):  # тятиви: контур, світло, основа, контур
        px[x0, y] = OUTLINE
        px[x0 + 1, y] = WOOD[0] + (255,)
        px[x0 + 2, y] = WOOD[1] + (255,)
        px[x0 + 3, y] = OUTLINE
for x in range(5, 12):  # щабель
    px[x, 2] = OUTLINE
    px[x, 3] = WOOD[0] + (255,)
    px[x, 4] = WOOD[2] + (255,)
    px[x, 5] = OUTLINE
im.save(OUT)
print("drawn", OUT)
