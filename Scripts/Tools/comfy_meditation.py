"""Місце медитації (D764) — одне на всю гру, строго збоку: Qwen-Image-Edit-2511 (comfy_sprite.edit) перемальовує
design/refs/meditation_spot_base.png у вигляд збоку й зводить до пікселя гри. Основа — проп Qwen-Image з
comfy_backdrop (зерно 7641, «a small wayside meditation spot of a desert road: a low flat round sandstone platform
with a spiral rune…», small=2), а він малював поміст трохи згори (Sapega 27.10: «строго збоку»).
Запуск: python -I -B Scripts/Tools/comfy_meditation.py
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import comfy_sprite as cs  # noqa: E402

REF = "design/refs/meditation_spot_base.png"
OUT = "SampleProject/Assets/Backgrounds/Decor/meditation/meditation_spot.png"
CELL = (104, 80)
SEED = 7656
TEXT = (
    "Redraw this exact object in exactly the same pixel art style, colours and size, as a strict side view at eye level "
    "with no perspective: the round stone platform becomes a flat horizontal stone slab seen exactly from the side, only "
    "its front face visible, its top edge one straight horizontal line, the spiral rune carved on its front face. Keep the "
    "cairn of stacked stones standing on the slab at the left, the leaning wooden pole with the blue prayer flags at the "
    "right and the two small clay oil lamps with flames standing on top of the slab. Keep the plain flat magenta background."
)

if __name__ == "__main__":
    img = cs.edit(cs.enlarge(REF, CELL), TEXT, SEED)
    rgb, op = cs.shrink(img, CELL)
    ys, xs = np.nonzero(op)
    out = np.dstack([rgb.astype(np.uint8), (op * 255).astype(np.uint8)])[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(out).save(OUT)
    cs.free()
    print("drawn", OUT, out.shape[1], "x", out.shape[0])
