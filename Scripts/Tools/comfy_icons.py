"""Іконки вмінь (D550: «маленькі малюночки, але впізнавані»; сам ефект уміння, без зброї й без Кусакама).

    python -I -B Scripts/Tools/comfy_icons.py   → design/shots/candidates/skill_icons.png

Еталон стилю — іконка, яку обрав Sapega (Searing Hex у стилі Dragon Nest: золота рамка, глянець, світіння;
design/shots/candidates/picks/icon_style_ref_hex.png). Кожна іконка — правка цієї картинки: рамка й манера лишаються,
всередині — ефект уміння, колір світіння — свій. Образи — з D&D 5e SRD і Pathfinder 2e, звідки вміння (D285).
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from comfy_backdrop import run, upload  # noqa: E402
from comfy_sprite import edit_graph, free  # noqa: E402

REF = "design/shots/candidates/picks/icon_style_ref_hex.png"
OUT = "design/shots/candidates/skill_icons.png"
SIZE = 192  # показ на листі
# (вміння, джерело D&D / Pathfinder, що всередині рамки, колір світіння); None — сам еталон без руки
SKILLS = [
    ("Searing Hex", "Touch of Corruption", None, None),
    (
        "Fire Strike",
        "Searing Smite",
        "a roaring burst of orange fire shaped like a slashing arc",
        "warm orange",
    ),
    (
        "Electric Strike",
        "Thunderous Smite",
        "a jagged bolt of blue-white lightning crackling with sparks",
        "electric blue",
    ),
    (
        "Healing Palm",
        "Lay on Hands",
        "a laying-on of hands: an open palm with soft golden light pouring out of it",
        "soft golden green",
    ),
    (
        "Radiant Smite",
        "Divine Smite",
        "a blinding white-gold radiant burst with a small holy sunburst sigil at its heart",
        "white gold",
    ),
    (
        "Dervish Whirl",
        "Whirlwind",
        "a spinning whirlwind of sand and wind",
        "sand yellow and teal",
    ),
]
KEEP_HEX = (
    "Keep this icon exactly as it is: the gold rounded-square frame, the dark purple background, the glow, the dark rune "
    "and the violet-black fire. Remove the clawed hand and its sleeve completely, so only the rune in its fire stays, "
    "centred in the frame. No text."
)
RESTYLE = (
    "Keep exactly this icon's frame and style: the same gold rounded-square frame, the dark background, the glossy "
    "hand-painted look and the soft outer glow. Replace everything inside the frame with {subject}, and change the glow "
    "and the main colour to {glow}. One clear subject, centred and readable at a glance. No weapons, no people, no faces "
    "(a lone hand only where the skill is a touch), no rune, no text."
)


def main():
    ref = np.asarray(Image.open(REF).convert("RGBA"))
    name = upload(ref, "icon_style_ref.png")
    mp = ref.shape[0] * ref.shape[1] / 1048576
    cells = []
    for ki, (skill, source, subject, glow) in enumerate(SKILLS):
        text = (
            KEEP_HEX if subject is None else RESTYLE.format(subject=subject, glow=glow)
        )
        out = run(edit_graph(text, 400 + ki, name, mp)).astype(np.uint8)
        cells.append(
            (skill, source, Image.fromarray(out).resize((SIZE, SIZE), Image.LANCZOS))
        )
        print("generated", skill, flush=True)
    free()
    font, small = (
        ImageFont.truetype("arial.ttf", 22),
        ImageFont.truetype("arial.ttf", 17),
    )
    pad, top = 24, 70
    sheet = Image.new(
        "RGB", (pad + len(cells) * (SIZE + pad), top + SIZE + pad), (60, 60, 66)
    )
    d = ImageDraw.Draw(sheet)
    for i, (skill, source, im) in enumerate(cells):
        x = pad + i * (SIZE + pad)
        d.text((x, 14), skill, fill="white", font=font)
        d.text((x, 42), source, fill=(200, 200, 210), font=small)
        sheet.paste(im, (x, top))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("sheet", OUT, sheet.size)


if __name__ == "__main__":
    main()
