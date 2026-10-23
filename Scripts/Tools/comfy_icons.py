"""Іконки вмінь (D550: «маленькі малюночки, але впізнавані»). Лист кандидатів: кілька вмінь × кілька стилів.

    python -I -B Scripts/Tools/comfy_icons.py   → design/shots/candidates/skill_icons.png

Картинка — темний квадрат кольору дерева (полотно); кадру героя немає (на іконці не має бути Кусакама). Стиль MapleStory
зводиться до сітки 48×48 найчастішим кольором блоку й палітрою (comfy_sprite.shrink); мальовані — як є.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from comfy_backdrop import run, upload  # noqa: E402
from comfy_sprite import edit_graph, free, own_palette, polish, shrink, to_palette  # noqa: E402

GRID, UPX = 48, 16  # клітинка іконки й блок моделі
OUT = "design/shots/candidates/skill_icons.png"
TREE_BG = {  # тло квадрата за деревом (D550)
    "holy": (58, 44, 26),
    "paladin": (24, 34, 66),
    "dark": (52, 18, 40),
    "warden": (18, 52, 52),
}
SKILLS = [  # Sapega 2026-10-23: «вміння має бути самодостатнім» — на іконці сам ефект, не зброя й не герой
    ("Fire Strike", "holy", "a roaring burst of orange fire sweeping in a slash-shaped arc"),
    ("Electric Strike", "holy", "a jagged bolt of blue-white lightning with crackling sparks"),
    ("Healing Palm", "holy", "a gentle healing touch: an open palm with soft green-gold light flowing out of it"),
    ("Radiant Smite", "paladin", "a burst of white-gold holy light striking down from above"),
    ("Searing Hex", "dark", "a cursed rune burning with violet-black fire"),
    ("Dervish Whirl", "warden", "a spinning whirlwind of sand and wind"),
]
STYLES = [  # Sapega 2026-10-23: «за референси візьми Dragon Nest, MapleStory, Diablo»
    (
        "dragon_nest",
        "in the style of Dragon Nest skill icons: a glossy hand-painted square icon, vivid saturated colours, a strong "
        "inner glow and sharp highlights",
    ),
    (
        "maplestory",
        "in the style of MapleStory skill icons: a small cute pixel-art icon with clean dark outlines, bright cheerful "
        "colours and simple shapes",
    ),
    (
        "diablo2",
        "in the style of Diablo II skill icons: a dark, gritty hand-painted square icon, muted earthy colours, worn and "
        "moody",
    ),
    (
        "diablo4",
        "in the style of Diablo IV skill icons: a detailed painterly icon with dramatic lighting, mostly dark and "
        "monochrome with one strong accent colour",
    ),
]
PROMPT = (
    "Paint a square game skill icon over this whole dark square, {style}: {subject}. One clear subject filling the "
    "square, centred, readable at a glance; the dark square stays the background. Only the effect of the "
    "skill itself: no weapons, no people, no characters, no lizard, no faces (a lone hand only where the skill is a "
    "touch). No text, no letters, no border."
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
    cells = {}
    for si, (label, style) in enumerate(STYLES):
        for ki, (name, tree, subject) in enumerate(SKILLS):
            src = canvas(TREE_BG[tree])
            ref = upload(src, "icon_canvas.png")
            mp = src.shape[0] * src.shape[1] / 1048576
            out = run(
                edit_graph(
                    PROMPT.format(style=style, subject=subject), 300 + ki, ref, mp
                )
            ).astype(np.uint8)
            rgba = np.dstack([out, np.full(out.shape[:2], 255, np.uint8)])
            cells[(si, ki)] = (
                pixel_icon(rgba)
                if label == "maplestory"
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
