"""Щит героя окремим спрайтом поверх його наявних кадрів (S19, Sapega 2026-10-27: «Просто щит поверх намалювати»):
Qwen-Image-Edit-2511 (comfy_sprite.edit) замінює героя (Walk/1) на самотній залізний щит у його стилі; модель малює
щит на всю висоту героя, тож ×16-картинка зводиться блоками 32×32 (удвічі менше, колір блоку — найчастіший),
у 28 кольорів героя, з його контуром (polish). Де щит стоїть у кожному кадрі — Sprites/Player/Shields/README.md.
Запуск: python -B Scripts/Tools/hero_shield.py
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import comfy_sprite as cs  # noqa: E402

OUT = "SampleProject/Sprites/Player/Shields/iron_shield/shield.png"
SEED = 24
# «front view» малював щитові обличчя (очі над умбоном) за обох зерен — вигляд збоку під кутом, як герой
PROMPT = (
    "Replace this character with a single iron heater shield standing upright on the ground, drawn in exactly the "
    "same pixel art style, thick dark outline and flat shading as the character: seen from the side at an angle, "
    "turned to face right, narrower than it is tall, its curved front face towards the right, a flat top edge and a "
    "pointed bottom, the face of the shield dull steel grey like his armour with lighter grey highlights, a thick "
    "darker iron rim around the edge, a small round iron boss in the middle, no emblem, no character, no arms, the "
    "shield about as tall as his body from the feet to the neck. Keep the plain flat magenta background."
)

if __name__ == "__main__":
    img = cs.edit(
        cs.enlarge("SampleProject/Sprites/Player/Walk/1.png", (64, 64)), PROMPT, SEED
    )
    cs.free()
    cs.UP = 32  # удвічі менше: 54 px заввишки → 27
    rgb, op = cs.shrink(img, (32, 32))
    q, op = cs.polish(cs.to_palette(rgb, cs.hero_palette()), op)
    ys, xs = np.nonzero(op)
    sprite = np.dstack([q, op * 255.0]).astype(np.uint8)[
        ys.min() : ys.max() + 1, xs.min() : xs.max() + 1
    ]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(sprite).save(OUT)
    print("wrote", OUT, sprite.shape[1], "x", sprite.shape[0])
