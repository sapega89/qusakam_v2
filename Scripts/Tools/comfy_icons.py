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
# Sapega 2026-10-23: «глянець і рамку прибери, вони зайві» — рамку дає слот панелі; спершу еталон без рамки, з нього решта
# Sapega 2026-10-23: «немає ніяких глянців, стиль панелі — камінь, і все» (дерево вмінь Diablo II) — матово, приглушено
KEEP_HEX = (
    "Repaint this icon in the style of Diablo II skill icons: no gold frame, no shine, no glow. A pale, desaturated "
    "violet rune with dim dark fire around it, painted on a dark weathered stone square that fills the whole icon, with "
    "gritty texture and a soft dark vignette. Remove the clawed hand and its sleeve completely. Muted colours, matte, "
    "simple and readable. No frame, no border, no text."
)
RESTYLE = (
    "Keep exactly this icon's style: the Diablo II look, the dark weathered stone square filling the whole icon, the "
    "gritty texture, the soft vignette, muted desaturated colours, matte with no shine and no glow, no frame. Replace the "
    "rune and its fire with {subject}, in a pale {glow} tint. One clear subject, centred and readable at a glance. No "
    "weapon as the subject; if a figure helps, a small faceless generic silhouette, never a lizard; no rune, no text."
)


def main():
    ref = np.asarray(Image.open(REF).convert("RGBA"))
    mp = ref.shape[0] * ref.shape[1] / 1048576
    # 1) еталон без рамки й глянцю (Searing Hex), 2) з нього — решта, щоб манера була одна
    base = run(edit_graph(KEEP_HEX, 400, upload(ref, "icon_style_ref.png"), mp)).astype(np.uint8)
    base_name = upload(np.dstack([base, np.full(base.shape[:2], 255, np.uint8)]), "icon_style_base.png")
    cells = [(SKILLS[0][0], SKILLS[0][1], Image.fromarray(base).resize((SIZE, SIZE), Image.LANCZOS))]
    print("generated", SKILLS[0][0], flush=True)
    for ki, (skill, source, subject, glow) in enumerate(SKILLS[1:], start=1):
        out = run(edit_graph(RESTYLE.format(subject=subject, glow=glow), 400 + ki, base_name, mp)).astype(np.uint8)
        cells.append((skill, source, Image.fromarray(out).resize((SIZE, SIZE), Image.LANCZOS)))
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
