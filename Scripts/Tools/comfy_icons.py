"""Іконки вмінь (D550: «маленькі малюночки, але впізнавані»). Лист кандидатів: кілька вмінь × кілька стилів.

    python -I -B Scripts/Tools/comfy_icons.py   → design/shots/candidates/skill_icons.png

Картинка 1 — темний квадрат кольору дерева (полотно), картинка 2 — кадр героя (стиль). Піксельний стиль зводиться
до сітки 48×48 найчастішим кольором блоку й палітрою, як спрайти (comfy_sprite.shrink); мальований і гравюра — як є.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from comfy_backdrop import run, upload  # noqa: E402
from comfy_sprite import edit_graph, free, own_palette, polish, shrink, to_palette  # noqa: E402

GRID, UPX = 48, 16  # клітинка іконки й блок моделі
HERO = "SampleProject/Sprites/Player/Walk/1.png"
OUT = "design/shots/candidates/skill_icons.png"
TREE_BG = {  # тло квадрата за деревом (D550)
    "holy": (58, 44, 26),
    "paladin": (24, 34, 66),
    "dark": (52, 18, 40),
    "warden": (18, 52, 52),
}
SKILLS = [
    (
        "Fire Strike",
        "holy",
        "a sword blade wreathed in orange fire, slashing diagonally",
    ),
    (
        "Electric Strike",
        "holy",
        "a sword blade crackling with bright blue lightning arcs",
    ),
    (
        "Healing Palm",
        "holy",
        "an open hand cradling a small glowing healing flask with a soft green-gold light",
    ),
    (
        "Radiant Smite",
        "paladin",
        "a war hammer striking down in a burst of white-gold holy light",
    ),
    (
        "Searing Hex",
        "dark",
        "a clawed hand casting a violet-black flame shaped like a cursed rune",
    ),
    ("Dervish Whirl", "warden", "two curved scimitars spinning in a whirl of sand"),
]
STYLES = [
    (
        "pixel",
        "in exactly the pixel art style of the character in picture 2: big square pixels, a thick dark outline, flat "
        "shading and a small palette",
    ),
    (
        "painted",
        "as a small hand-painted fantasy RPG skill icon like the ones in Diablo II or Dragon Nest: rich painted shading "
        "and glow, yet simple and readable at a small size",
    ),
    (
        "ink",
        "as a bold inked woodcut emblem on old parchment, thick dark lines and a single accent colour",
    ),
]
PROMPT = (
    "Paint a square game skill icon over this whole dark square, {style}: {subject}. One clear subject filling the "
    "square, centred, readable at a glance; the dark square stays the background. No text, no letters, no border."
)


def canvas(color):
    return np.asarray(Image.new("RGBA", (GRID * UPX, GRID * UPX), color + (255,)))


def pixel_icon(img):
    rgb, op = shrink(img, (GRID, GRID))
    op[:] = True  # іконка — повний квадрат, тло не вирізаємо
    pal = own_palette([(rgb, op)], 16)
    q, _ = polish(to_palette(rgb, pal), op)
    return Image.fromarray(q.astype(np.uint8)).resize(
        (GRID * 4, GRID * 4), Image.NEAREST
    )


def main():
    hero = upload(
        np.asarray(
            Image.open(HERO)
            .convert("RGBA")
            .resize((64 * UPX // 4, 64 * UPX // 4), Image.NEAREST)
        ),
        "icon_style.png",
    )
    cells = {}
    for si, (label, style) in enumerate(STYLES):
        for ki, (name, tree, subject) in enumerate(SKILLS):
            src = canvas(TREE_BG[tree])
            ref = upload(src, "icon_canvas.png")
            mp = src.shape[0] * src.shape[1] / 1048576
            out = run(
                edit_graph(
                    PROMPT.format(style=style, subject=subject), 300 + ki, ref, mp, hero
                )
            ).astype(np.uint8)
            rgba = np.dstack([out, np.full(out.shape[:2], 255, np.uint8)])
            cells[(si, ki)] = (
                pixel_icon(rgba)
                if label == "pixel"
                else Image.fromarray(out).resize((GRID * 4, GRID * 4), Image.LANCZOS)
            )
            print("generated", label, name, flush=True)
    free()
    font = ImageFont.truetype("arial.ttf", 26)
    cw, pad, top, left = GRID * 4, 24, 60, 150
    sheet = Image.new(
        "RGB",
        (left + len(SKILLS) * (cw + pad), top + len(STYLES) * (cw + pad)),
        (60, 60, 66),
    )
    d = ImageDraw.Draw(sheet)
    for ki, (name, _, _) in enumerate(SKILLS):
        d.text((left + ki * (cw + pad), 18), name, fill="white", font=font)
    for si, (label, _) in enumerate(STYLES):
        d.text(
            (16, top + si * (cw + pad) + cw // 2 - 14),
            f"{si + 1} {label}",
            fill="white",
            font=font,
        )
        for ki in range(len(SKILLS)):
            sheet.paste(
                cells[(si, ki)], (left + ki * (cw + pad), top + si * (cw + pad))
            )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("sheet", OUT, sheet.size)


if __name__ == "__main__":
    main()
