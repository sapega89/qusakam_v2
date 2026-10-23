"""Іконки вмінь (D550, D600): сам ефект уміння, матово, як у Diablo II, без рамки, без глянцю, без Кусакама; тло порожнє
(«в нас немає текстури в меню, тому підкладка, можливо, має бути пустою або просто колір»).

    python -I -B Scripts/Tools/comfy_icons.py   → design/shots/candidates/skill_icons.png

Еталон — руна в темному вогні, яку схвалив Sapega (design/shots/candidates/picks/icon_base_d2.png). Модель ставить її
на зелене тло, решта іконок — правки цього кадру (та сама манера), потім зелене вирізається в прозоре (фіолетовий
вогонь руни надто близький до пурпуру, тому не пурпур). На листі кожна іконка —
на темному кольорі слота панелі й на відтінку свого дерева. Образи — з D&D 5e SRD і Pathfinder 2e (D285).
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from comfy_backdrop import run, upload  # noqa: E402
from comfy_sprite import edit_graph, free  # noqa: E402

BASE = "design/shots/candidates/picks/icon_base_d2.png"
OUT = "design/shots/candidates/skill_icons.png"
ICONS_OUT = "design/shots/candidates/skill_icons"  # прозорі PNG кожної іконки
SIZE = 192  # показ на листі
SLOT = (21, 20, 28)  # тло слота панелі (#15141C)
TINT = {
    "holy": (58, 44, 26),
    "paladin": (24, 34, 66),
    "dark": (52, 18, 40),
    "warden": (18, 52, 52),
}
# (вміння, дерево, джерело D&D / Pathfinder, що намалювати, відтінок); None — еталонна руна
SKILLS = [
    ("Searing Hex", "dark", "Touch of Corruption", None, None),
    (
        "Fire Strike",
        "holy",
        "Searing Smite",
        "a roaring burst of fire shaped like a slashing arc",
        "orange",
    ),
    (
        "Electric Strike",
        "holy",
        "Thunderous Smite",
        "a jagged bolt of lightning crackling with sparks",
        "blue-white",
    ),
    (
        "Healing Palm",
        "holy",
        "Lay on Hands",
        "a laying-on of hands: an open palm with soft light pouring out of it",
        "golden",
    ),
    (
        "Radiant Smite",
        "paladin",
        "Divine Smite",
        "a radiant burst of holy light with a small sunburst sigil at its heart",
        "white-gold",
    ),
    (
        "Dervish Whirl",
        "warden",
        "Whirlwind",
        "a spinning whirlwind of sand and wind",
        "sand-yellow",
    ),
]
TO_GREEN = (
    "Keep the pale violet rune and its dark fire as they are, but put the rune exactly in the centre of the square with "
    "the dark fire burning evenly around it (the rune carries the meaning: a curse). Replace the whole stone "
    "square behind them with a plain flat bright green background (#00FF00) right to the edges: no stone, no texture, no "
    "border, no shadow. No text."
)
RESTYLE = (
    "Keep exactly this icon's painting style: matte, muted and desaturated, soft shading, no shine and no glow, on the "
    "same plain flat bright green background right to the edges. Replace the rune and its fire with {subject}, in a pale "
    "{tint} tint. The element that carries the meaning sits exactly in the centre of the square, anything else around it. "
    "One clear subject, readable at a glance. No weapon as the "
    "subject; if a figure helps, a small faceless generic silhouette, never a lizard; no rune, no text, no border."
)


def key_green(rgb):
    """Зелене тло → прозоре; м'який край без зеленого ореолу (домішку зеленого прибираємо)."""
    f = rgb.astype(np.float32)
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    m = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (np.clip(m / 255.0, 0, 1) - 0.25) / 0.4, 0, 1)
    out = f.copy()
    out[..., 1] = g - np.clip(m, 0, None)  # зелений не більший за червоний чи синій
    return np.dstack([out.clip(0, 255), alpha * 255]).astype(np.uint8)


def centre(rgba, fill=0.8):
    """Видима частина (альфа) — рівно по центру квадрата й займає fill його сторони (Sapega: «центрувати не забувай»)."""
    im = Image.fromarray(rgba)
    box = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    im = im.crop(box)
    side = round(max(im.width, im.height) / fill)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq


def sheet_from(raw):
    """Лист: кожна іконка — по центру, на тлі слота й на відтінку дерева; прозорі PNG — у ICONS_OUT."""
    os.makedirs(ICONS_OUT, exist_ok=True)
    font, small = ImageFont.truetype("arial.ttf", 22), ImageFont.truetype("arial.ttf", 17)
    pad, top = 24, 70
    sheet = Image.new("RGB", (pad + len(SKILLS) * (SIZE + pad), top + 2 * (SIZE + pad)), (60, 60, 66))
    d = ImageDraw.Draw(sheet)
    for i, ((skill, tree, source, _, _), img) in enumerate(zip(SKILLS, raw)):
        icon = centre(key_green(img)).resize((SIZE, SIZE), Image.LANCZOS)
        icon.save(os.path.join(ICONS_OUT, skill.lower().replace(" ", "_") + ".png"))
        x = pad + i * (SIZE + pad)
        d.text((x, 14), skill, fill="white", font=font)
        d.text((x, 42), source, fill=(200, 200, 210), font=small)
        for row, bg in enumerate((SLOT, TINT[tree])):
            tile = Image.new("RGBA", (SIZE, SIZE), bg + (255,))
            tile.alpha_composite(icon)
            sheet.paste(tile.convert("RGB"), (x, top + row * (SIZE + pad)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    print("sheet", OUT, sheet.size)


def raw_path(skill):
    return os.path.join(ICONS_OUT, "raw", skill.lower().replace(" ", "_") + ".png")


def main():
    base = np.asarray(Image.open(BASE).convert("RGBA"))
    mp = base.shape[0] * base.shape[1] / 1048576
    hexm = run(edit_graph(TO_GREEN, 500, upload(base, "icon_base.png"), mp)).astype(
        np.uint8
    )
    hex_name = upload(
        np.dstack([hexm, np.full(hexm.shape[:2], 255, np.uint8)]),
        "icon_base_green.png",
    )
    raw = [hexm]
    print("generated", SKILLS[0][0], flush=True)
    for ki, (_, _, _, subject, tint) in enumerate(SKILLS[1:], start=1):
        raw.append(
            run(
                edit_graph(
                    RESTYLE.format(subject=subject, tint=tint), 500 + ki, hex_name, mp
                )
            ).astype(np.uint8)
        )
        print("generated", SKILLS[ki][0], flush=True)
    free()
    os.makedirs(os.path.join(ICONS_OUT, "raw"), exist_ok=True)
    for (skill, *_), img in zip(SKILLS, raw):
        Image.fromarray(img).save(raw_path(skill))
    sheet_from(raw)


if __name__ == "__main__":
    if sys.argv[1:] == ["--sheet"]:  # лише лист із збережених сирих кадрів, без моделі
        sheet_from([np.asarray(Image.open(raw_path(s[0])).convert("RGB")) for s in SKILLS])
    else:
        main()
