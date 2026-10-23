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
SKILLS = [  # Sapega 2026-10-23: «для кожної іконки треба особистий промт» — склад і що в центрі, окремо для кожної
    ("Searing Hex", "dark", "Touch of Corruption", None, None),
    (
        "Fire Strike",
        "holy",
        "Searing Smite",
        "a crescent-shaped burst of fire sweeping from the upper right to the lower left like the trail of a blow, bright "
        "at its leading edge, darker ember tips, painted volume; the crescent fills the square and nothing else is there",
        "orange",
    ),
    (
        "Electric Strike",
        "holy",
        "Thunderous Smite",
        "a single jagged lightning bolt striking down diagonally through the centre, branching into thin crackling arcs, "
        "a blue-white core with a pale blue halo",
        "blue-white",
    ),
    (
        "Healing Palm",
        "holy",
        "Lay on Hands",
        "an open palm facing the viewer in the centre, fingers slightly spread, soft golden light pooling in the palm and "
        "rising from it as small motes; the hand is the only figure",
        "golden",
    ),
    (
        "Radiant Smite",
        "paladin",
        "Divine Smite",
        "a sunburst of white-gold light bursting down from the top centre, a small eight-pointed holy sigil at its heart, "
        "rays fanning out to the edges",
        "white-gold",
    ),
    (
        "Dervish Whirl",
        "warden",
        "Whirlwind",
        "a spinning funnel of sand and wind in the centre, circling streaks of sand and small flying grit, a darker eye at "
        "its core",
        "sand-yellow",
    ),
]
TO_GREEN = (
    "Keep the pale violet rune and its dark fire as they are, but put the rune exactly in the centre of the square with "
    "the dark fire burning evenly around it (the rune carries the meaning: a curse). Replace the whole stone "
    "square behind them with a plain flat bright green background (#00FF00) right to the edges: no stone, no texture, no "
    "border, no shadow. No text."
)
# Sapega 2026-10-23: «вогонь якийсь плоский, на попередньому арті краще було… і людина тут ні до чого» — кожну іконку
# спершу малюємо на камені (об'єм, світлотінь), потім окремою правкою знімаємо камінь; жодних фігурок на ефектах
STONE_RESTYLE = (
    "Keep exactly this icon's style: the Diablo II look, the dark weathered stone square filling the whole icon, the "
    "gritty texture, the soft vignette, muted desaturated colours, painted volume and soft shading, matte with no shine "
    "and no glow, no frame. Replace the rune and its fire with {subject}, in a pale {tint} tint. The element that carries "
    "the meaning sits exactly in the centre, anything else around it. One clear subject, readable at a glance. No weapon "
    "as the subject, no people, no figures, no faces (a lone hand only where the skill is a touch), no rune, no text."
)
CLEAR_BG = (
    "Keep the painted subject exactly as it is: the same shapes, painted volume, shading and colours, centred in the "
    "square. Replace the whole stone square behind it with a plain flat bright green background (#00FF00) right to the "
    "edges: no stone, no texture, no border, no shadow. Remove any people or figures. No text."
)
STONE = {"Fire Strike": "design/shots/candidates/picks/icon_fire_stone.png"}  # кам'яні кадри, які схвалив Sapega


def key_green(rgb):
    """Тло → прозоре. Колір тла міряємо з рамки кадру (модель малює «#00FF00» неточно, приглушено), альфа — за
    відстанню до нього з м'яким краєм; із краю прибираємо зелену домішку."""
    f = rgb.astype(np.float32)
    border = np.concatenate([f[:8].reshape(-1, 3), f[-8:].reshape(-1, 3), f[:, :8].reshape(-1, 3), f[:, -8:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    dist = np.linalg.norm(f - bg, axis=2)
    alpha = np.clip((dist - 45.0) / 70.0, 0, 1)
    out = f.copy()
    g_over = out[..., 1] - np.maximum(out[..., 0], out[..., 2])
    out[..., 1] -= np.clip(g_over, 0, None)  # зелений не більший за червоний чи синій: тло пофарбувало краї
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
    """Що вже є — не перемальовуємо: сирий зелений кадр (raw) лишається; кам'яний кадр — лише знімаємо камінь;
    решта — камінь, потім зняти камінь. Аргументи — назви вмінь (за замовчуванням ті, яких ще немає)."""
    base = np.asarray(Image.open(BASE).convert("RGBA"))
    mp = base.shape[0] * base.shape[1] / 1048576
    base_name = upload(base, "icon_base.png")
    want = [s for s in SKILLS if s[0] in sys.argv[1:]] or [s for s in SKILLS if not os.path.exists(raw_path(s[0]))]
    os.makedirs(os.path.join(ICONS_OUT, "raw"), exist_ok=True)
    for ki, (skill, _, _, subject, tint) in enumerate(SKILLS):
        if (skill, _, _, subject, tint) not in want:
            continue
        if skill in STONE:
            stone = np.asarray(Image.open(STONE[skill]).convert("RGB"))
        elif subject is None:
            stone = base[..., :3]
        else:
            stone = run(edit_graph(STONE_RESTYLE.format(subject=subject, tint=tint), 600 + ki, base_name, mp)).astype(np.uint8)
            Image.fromarray(stone).save(raw_path(skill).replace(".png", "_stone.png"))
        stone_name = upload(np.dstack([stone, np.full(stone.shape[:2], 255, np.uint8)]), "icon_stone.png")
        green = run(edit_graph(CLEAR_BG, 700 + ki, stone_name, mp)).astype(np.uint8)
        Image.fromarray(green).save(raw_path(skill))
        print("generated", skill, flush=True)
    free()
    sheet_from([np.asarray(Image.open(raw_path(s[0])).convert("RGB")) for s in SKILLS])


if __name__ == "__main__":
    if sys.argv[1:] == ["--sheet"]:  # лише лист із збережених сирих кадрів, без моделі
        sheet_from([np.asarray(Image.open(raw_path(s[0])).convert("RGB")) for s in SKILLS])
    else:
        main()
