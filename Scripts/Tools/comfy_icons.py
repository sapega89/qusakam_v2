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
from PIL import Image, ImageDraw, ImageFilter, ImageFont

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


# Піксельні іконки (Sapega 2026-10-23: «мені подобався стиль в пікселі, просто Кусакам тут зайвий»): еталон — палаючий
# меч з першого листа (design/shots/candidates/picks/icon_pixel_fire_ref.png) без героя; решта — правки цього кадру;
# потім сітка 48×48 найчастішим кольором блоку (як спрайти), 16 кольорів, тло — прозоре.
PIXEL_REF = "design/shots/candidates/picks/icon_pixel_fire_ref.png"
PIXEL_OUT = "design/shots/candidates/skill_icons_pixel.png"
PIX_GRID = 48
PIX_BASE = (
    "Remove the lizard character completely. Keep only the flaming sword with its fire, in exactly the same pixel art "
    "style: big square pixels, a thick dark outline, flat shading. The fire engulfs the blade as it strikes; the sword "
    "lies diagonally across the centre of the square. Plain flat bright green background (#00FF00) right to the edges. "
    "No character, no text, no border."
)
# Sapega 2026-10-23 (мобільна гра як приклад): «скіл каже, що він робить… давай і так, і так спробуємо… один колір для
# скілів, ультимейт — іншого». Знак — однокольоровий світлий (слот дає колір), два варіанти: лише ефект / фігурка в дії
PIX_RESTYLE = (
    "Keep exactly this icon's pixel art style: big square pixels, a thick dark outline, flat shading, and the plain flat "
    "bright green background right to the edges. Replace the flaming sword with {subject}. Use at most three colours: "
    "{colour} and the thick dark outline, nothing else, no rainbow. The element that carries "
    "the meaning sits exactly in the centre of the square. No lizard, no face details, no text, no border."
)
# Sapega: «можливо, в нас інші кольори; я не проти мати три кольори, але не різнокольорове» — кольори UI гри
SKILL_COLOUR, ULT_COLOUR = "pale ivory with warm gold accents", "warm gold with deep crimson accents"
EFFECT = {
    "Fire Strike": "a crescent of fire like the trail of a blow",
    "Electric Strike": "a jagged lightning bolt",
    "Healing Palm": "an open palm with light rising from it",
    "Radiant Smite": "a sunburst with a small holy sigil at its heart",
    "Searing Hex": "a curse rune inside a ring of fire",
    "Dervish Whirl": "a spinning whirlwind",
}
FIGURE = {  # маленька безлика фігурка робить дію (не ящур)
    "Fire Strike": "a small faceless figure swinging a flaming sword in a wide slash",
    "Electric Strike": "a small faceless figure striking down with a hammer as a lightning bolt hits it",
    "Healing Palm": "a small faceless figure laying an open hand on a kneeling ally, light rising between them",
    "Radiant Smite": "a small faceless figure raising a hammer as a beam of holy light strikes down",
    "Searing Hex": "a small faceless figure casting a curse rune from an outstretched hand, fire around the rune",
    "Dervish Whirl": "a small faceless figure spinning round with two curved blades inside a whirlwind",
    "Wind Step": "a small faceless figure leaping forward with a flying knee strike, motion lines behind",
    "Judgement of the Sky": "a small faceless figure raising a sword as a great pillar of light falls from the sky",
}
ULTIMATES = {"Judgement of the Sky"}


def pixel_icon(img):
    """Кадр моделі на зеленому → іконка 48×48 у пікселях: блоки, палітра, прозоре тло, по центру з полем."""
    import comfy_sprite

    comfy_sprite.MAGENTA_CUT_MIN = 999  # тло зелене: пурпуровий виріз шрифту спрайтів тут зайвий (фіолетова руна)
    rgb, op = comfy_sprite.shrink(np.dstack([img, np.full(img.shape[:2], 255, np.uint8)]), (PIX_GRID, PIX_GRID))
    pal = comfy_sprite.own_palette([(rgb, op)], 16)
    q, op = comfy_sprite.polish(comfy_sprite.to_palette(rgb, pal), op)
    rgba = np.dstack([q, op * 255]).astype(np.uint8)
    ys, xs = np.nonzero(op)
    crop = rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    side = PIX_GRID
    out = np.zeros((side, side, 4), np.uint8)
    h, w = crop.shape[:2]
    out[(side - h) // 2 : (side - h) // 2 + h, (side - w) // 2 : (side - w) // 2 + w] = crop[:side, :side]
    return Image.fromarray(out)


def pixel_main(variant):
    """variant: "E" — лише ефект, "F" — фігурка в дії. База (палаючий меч без героя) — одна на обидва, кешується."""
    folder = os.path.join(ICONS_OUT, "pixel")
    os.makedirs(os.path.join(folder, "raw"), exist_ok=True)
    ref = np.asarray(Image.open(PIXEL_REF).convert("RGBA"))
    mp = ref.shape[0] * ref.shape[1] / 1048576
    base_path = os.path.join(folder, "raw", "_base.png")
    if not os.path.exists(base_path):
        Image.fromarray(run(edit_graph(PIX_BASE, 800, upload(ref, "icon_pixel_ref.png"), mp)).astype(np.uint8)).save(base_path)
        print("generated base", flush=True)
    base = np.asarray(Image.open(base_path).convert("RGB"))
    base_name = upload(np.dstack([base, np.full(base.shape[:2], 255, np.uint8)]), "icon_pixel_base.png")
    subjects = EFFECT if variant == "E" else FIGURE
    raw = {}
    for ki, (skill, subject) in enumerate(subjects.items()):
        colour = ULT_COLOUR if skill in ULTIMATES else SKILL_COLOUR
        path = os.path.join(folder, "raw", f"{variant}_{skill.lower().replace(' ', '_')}.png")
        if not os.path.exists(path):
            out = run(edit_graph(PIX_RESTYLE.format(subject=subject, colour=colour), 810 + ki, base_name, mp))
            Image.fromarray(out.astype(np.uint8)).save(path)
            print("generated", variant, skill, flush=True)
        raw[skill] = np.asarray(Image.open(path).convert("RGB"))
    free()
    pixel_sheet(variant, raw)


def pixel_sheet(variant, raw):
    """Лист: кожен знак — у круглому слоті одного кольору (як у прикладі Sapega), ультимейт — у слоті іншого."""
    folder = os.path.join(ICONS_OUT, "pixel")
    font = ImageFont.truetype("arial.ttf", 20)
    pad, top = 24, 50
    sheet = Image.new("RGB", (pad + len(raw) * (SIZE + pad), top + SIZE + pad), (60, 60, 66))
    d = ImageDraw.Draw(sheet)
    for i, (skill, img) in enumerate(raw.items()):
        icon = pixel_icon(img)
        icon.save(os.path.join(folder, f"{variant}_{skill.lower().replace(' ', '_')}.png"))
        big = icon.resize((SIZE, SIZE), Image.NEAREST)
        x = pad + i * (SIZE + pad)
        d.text((x, 14), skill, fill="white", font=font)
        disc = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        dd = ImageDraw.Draw(disc)
        fill = (58, 16, 32, 255) if skill in ULTIMATES else (29, 29, 39, 255)  # слот UI: #1D1D27; ультимейт — темно-багряний
        dd.ellipse((4, 4, SIZE - 5, SIZE - 5), fill=fill, outline=(15, 15, 20, 255), width=4)
        disc.alpha_composite(big)
        tile = Image.new("RGBA", (SIZE, SIZE), (60, 60, 66, 255))
        tile.alpha_composite(disc)
        sheet.paste(tile.convert("RGB"), (x, top))
    out = PIXEL_OUT.replace(".png", f"_{variant}.png")
    sheet.save(out)
    print("sheet", out, sheet.size)


# Набір елементів (Sapega 2026-10-23: «винеси схожі іконки, намалюй для них спільний елемент, затверди його як асет»):
# кожен елемент — окремо, 3 кандидати, у затвердженому піксельному стилі (база — палаючий меч без героя), слонова кістка
# з золотом; кольори пасивок і ультимейтів міняє код (D602). Див. design/skill_icons_brief.md → «The asset kit».
ASSETS_DIR = "design/shots/candidates/icon_assets"
ASSETS = {
    "hand_palm": "a three-fingered lizard hand in a priest's leather glove, open palm facing the viewer, fingers slightly spread",
    "shield": "a heater shield seen from the front, plain, with a simple round boss in its middle",
    "sword": "a straight longsword lying diagonally from the lower left to the upper right, point up",
    "hammer": "a war hammer with a heavy square head, lying diagonally, head up",
    "heart": "a simple stylised heart",
    "breastplate": "a steel breastplate seen from the front",
    "figure": "a small faceless generic figure standing in a heroic stance, a simple silhouette, not a lizard",
    "holy_beam": "a beam of holy light falling straight down from the top edge",
    "sunburst": "a sunburst: a small round core with straight rays all around",
    "fire": "a single tall flame",
    "dark_fire": "a single tall flame drawn mostly in the dark outline colour, with ivory and gold edges",
    "lightning": "a single jagged lightning bolt",
    "blood_drop": "a single drop of blood, drawn in deep crimson with an ivory highlight",
    "whirl": "a whirl of sand and wind seen from the side, curling round",
    "impact": "an impact flash: a spiky starburst with three small stars around it",
    "parry_spark": "a bright small spark where two blades meet, an X-shaped flash",
    "aura_ring": "a ring of light seen in slight perspective, an aura",
    "rune": "a single pale curse rune, angular strokes",
}
PIX_ASSET = (
    "Keep exactly this icon's pixel art style: big square pixels, a thick dark outline, flat shading, and the plain flat "
    "bright green background right to the edges. Replace the flaming sword with {desc}, alone, centred, filling about "
    "two thirds of the square. Use at most three colours: pale ivory, warm gold and the thick dark outline, unless the "
    "description names another. Nothing else in the picture, no lizard unless named, no text, no border."
)


def assets_main(names):
    """Кандидати елементів: names — які (порожньо — усі, яких ще немає). Сирі кадри кешуються; лист — усі наявні."""
    os.makedirs(os.path.join(ASSETS_DIR, "raw"), exist_ok=True)
    base_path = os.path.join(ICONS_OUT, "pixel", "raw", "_base.png")
    base = np.asarray(Image.open(base_path).convert("RGB"))
    mp = base.shape[0] * base.shape[1] / 1048576
    base_name = upload(np.dstack([base, np.full(base.shape[:2], 255, np.uint8)]), "icon_pixel_base.png")
    todo = names or [a for a in ASSETS if not os.path.exists(os.path.join(ASSETS_DIR, "raw", f"{a}_1.png"))]
    for ai, asset in enumerate(ASSETS):
        if asset not in todo:
            continue
        for n in (1, 2, 3):
            path = os.path.join(ASSETS_DIR, "raw", f"{asset}_{n}.png")
            if os.path.exists(path):
                continue
            out = run(edit_graph(PIX_ASSET.format(desc=ASSETS[asset]), 900 + ai * 10 + n, base_name, mp))
            Image.fromarray(out.astype(np.uint8)).save(path)
            print("generated", asset, n, flush=True)
    free()
    assets_sheet()


def assets_sheet():
    """Лист кандидатів: рядок на елемент, три кандидати на тлі слота; 48×48 PNG кожного — поруч із сирими."""
    done = [a for a in ASSETS if all(os.path.exists(os.path.join(ASSETS_DIR, "raw", f"{a}_{n}.png")) for n in (1, 2, 3))]
    font = ImageFont.truetype("arial.ttf", 22)
    cell, pad, left = 144, 16, 170
    sheet = Image.new("RGB", (left + 3 * (cell + pad) + pad, pad + len(done) * (cell + pad)), (60, 60, 66))
    d = ImageDraw.Draw(sheet)
    for r, asset in enumerate(done):
        y = pad + r * (cell + pad)
        d.text((12, y + cell // 2 - 12), asset, fill="white", font=font)
        for n in (1, 2, 3):
            icon = pixel_icon(np.asarray(Image.open(os.path.join(ASSETS_DIR, "raw", f"{asset}_{n}.png")).convert("RGB")))
            icon.save(os.path.join(ASSETS_DIR, f"{asset}_{n}.png"))
            tile = Image.new("RGBA", (cell, cell), SLOT + (255,))
            tile.alpha_composite(icon.resize((cell, cell), Image.NEAREST))
            x = left + (n - 1) * (cell + pad)
            sheet.paste(tile.convert("RGB"), (x, y))
            d.text((x + 6, y + 4), str(n), fill=(230, 230, 230), font=font)
    sheet.save(ASSETS_DIR + ".png")
    print("sheet", ASSETS_DIR + ".png", sheet.size, len(done), "assets")


# Sapega 2026-10-23: «не вистачає анімешності корейського стилю» — проба: те саме, але як у MapleStory / Elsword
ASSETS_K_DIR = "design/shots/candidates/icon_assets_k"
# Sapega 2026-10-23: «однотонності: ти робиш якісь акценти, декілька кольорів, а я б хотів силуети… додай те, що це силуети»
PIX_ASSET_K = (
    "Keep this icon's pixel art basics: big square pixels and the plain flat bright green background right to the "
    "edges. Replace the flaming sword with {desc}, drawn as a SILHOUETTE: one flat solid shape in a single pale ivory "
    "colour, with only a few thin dark lines inside for the key details. No shading, no gradients, no gold, no other "
    "colours. Give it the energy of Korean MMO skill icons like MapleStory and Elsword: a dynamic tilted angle, bold "
    "readable shapes, and small sparkles or short motion lines as part of the same ivory silhouette. Centred, filling "
    "about two thirds of the square. No lizard unless named, no text, no border."
)


def assets_k_main(names):
    """Проба корейського стилю для кількох елементів (по 2 кандидати) і лист «звичайний | корейський»."""
    os.makedirs(os.path.join(ASSETS_K_DIR, "raw"), exist_ok=True)
    base = np.asarray(Image.open(os.path.join(ICONS_OUT, "pixel", "raw", "_base.png")).convert("RGB"))
    mp = base.shape[0] * base.shape[1] / 1048576
    base_name = upload(np.dstack([base, np.full(base.shape[:2], 255, np.uint8)]), "icon_pixel_base.png")
    for ai, asset in enumerate(names):
        for n in (1, 2):
            path = os.path.join(ASSETS_K_DIR, "raw", f"{asset}_{n}.png")
            if not os.path.exists(path):
                out = run(edit_graph(PIX_ASSET_K.format(desc=ASSETS[asset]), 1100 + ai * 10 + n, base_name, mp))
                Image.fromarray(out.astype(np.uint8)).save(path)
                print("generated", asset, n, flush=True)
    free()
    font = ImageFont.truetype("arial.ttf", 22)
    cell, pad, left = 144, 16, 170
    cols = [("plain", ASSETS_DIR, 1), ("plain", ASSETS_DIR, 2), ("korean", ASSETS_K_DIR, 1), ("korean", ASSETS_K_DIR, 2)]
    sheet = Image.new("RGB", (left + len(cols) * (cell + pad) + pad, 40 + pad + len(names) * (cell + pad)), (60, 60, 66))
    d = ImageDraw.Draw(sheet)
    for c, (label, _, n) in enumerate(cols):
        d.text((left + c * (cell + pad), 10), f"{label} {n}", fill="white", font=font)
    for r, asset in enumerate(names):
        y = 40 + pad + r * (cell + pad)
        d.text((12, y + cell // 2 - 12), asset, fill="white", font=font)
        for c, (_, folder, n) in enumerate(cols):
            path = os.path.join(folder, "raw", f"{asset}_{n}.png")
            if not os.path.exists(path):
                continue
            icon = pixel_icon(np.asarray(Image.open(path).convert("RGB")))
            tile = Image.new("RGBA", (cell, cell), SLOT + (255,))
            tile.alpha_composite(icon.resize((cell, cell), Image.NEAREST))
            sheet.paste(tile.convert("RGB"), (left + c * (cell + pad), y))
    sheet.save(ASSETS_K_DIR + "_compare.png")
    print("sheet", ASSETS_K_DIR + "_compare.png", sheet.size)


# Sapega 2026-10-23: «знайди модель для створення іконок» — проба двох моделей тексту в картинку:
# 1) SDXL base 1.0 + LoRA «Game icon» (Civitai 141066 v156373, OpenRAIL++-M, тригер «icon»);
# 2) Qwen-Image + LoRA «Master Pixel Art» (уже стояла в ComfyUI) + Lightning 4 кроки.
MODELS_DIR = "design/shots/candidates/icon_models"
ICON_NEG = "text, letters, words, watermark, signature, frame, border, multiple objects, photo, blurry, broken fingers"


def sdxl_icon_graph(desc, seed):
    def n(c, **i):
        return {"class_type": c, "inputs": i}

    text = f"2d icon, {desc}, fantasy RPG game skill icon, bold simple shape, centered, plain flat green background, icon"
    return {
        "ckpt": n("CheckpointLoaderSimple", ckpt_name="sd_xl_base_1.0.safetensors"),
        "lora": n("LoraLoader", model=["ckpt", 0], clip=["ckpt", 1], lora_name="game_icon_v1.0.safetensors",
                  strength_model=0.9, strength_clip=0.9),
        "pos": n("CLIPTextEncode", clip=["lora", 1], text=text),
        "neg": n("CLIPTextEncode", clip=["lora", 1], text=ICON_NEG),
        "latent": n("EmptyLatentImage", width=1024, height=1024, batch_size=1),
        "sample": n("KSampler", model=["lora", 0], positive=["pos", 0], negative=["neg", 0], latent_image=["latent", 0],
                    seed=seed, steps=30, cfg=6.5, sampler_name="euler_ancestral", scheduler="normal", denoise=1.0),
        "decode": n("VAEDecode", samples=["sample", 0], vae=["ckpt", 2]),
        "save": n("SaveImage", images=["decode", 0], filename_prefix="kusakam/icon_sdxl"),
    }


def qwen_pixel_graph(desc, seed):
    def n(c, **i):
        return {"class_type": c, "inputs": i}

    text = (f"Pixel art game skill icon of {desc}: one bold readable subject, centred, thick dark outline, clean flat "
            "colours, on a plain flat bright green background (#00FF00). No text, no frame.")
    return {
        "unet": n("UNETLoader", unet_name="qwen_image_fp8_e4m3fn.safetensors", weight_dtype="default"),
        "clip": n("CLIPLoader", clip_name="qwen_2.5_vl_7b_fp8_scaled.safetensors", type="qwen_image", device="default"),
        "vae": n("VAELoader", vae_name="qwen_image_vae.safetensors"),
        "light": n("LoraLoaderModelOnly", model=["unet", 0], lora_name="Qwen-Image-Lightning-4steps-V1.0.safetensors",
                   strength_model=1.0),
        "pixel": n("LoraLoaderModelOnly", model=["light", 0], lora_name="Qwen-Image-2512-Master-Pixel-Art-LoRA.safetensors",
                   strength_model=1.0),
        "model": n("ModelSamplingAuraFlow", model=["pixel", 0], shift=3.1),
        "pos": n("CLIPTextEncode", clip=["clip", 0], text=text),
        "neg": n("CLIPTextEncode", clip=["clip", 0], text=""),
        "latent": n("EmptySD3LatentImage", width=1024, height=1024, batch_size=1),
        "sample": n("KSampler", model=["model", 0], positive=["pos", 0], negative=["neg", 0], latent_image=["latent", 0],
                    seed=seed, steps=4, cfg=1.0, sampler_name="euler", scheduler="simple", denoise=1.0),
        "decode": n("VAEDecode", samples=["sample", 0], vae=["vae", 0]),
        "save": n("SaveImage", images=["decode", 0], filename_prefix="kusakam/icon_qpix"),
    }


def models_main(names):
    """Лист «модель × елемент»: SDXL+Game icon і Qwen+Pixel Art, по 2 кандидати; сирі кадри й 48×48 поруч."""
    os.makedirs(os.path.join(MODELS_DIR, "raw"), exist_ok=True)
    rows = []
    for mi, (model, build) in enumerate((("sdxl", sdxl_icon_graph), ("qpix", qwen_pixel_graph))):
        for ai, asset in enumerate(names):
            for c in (1, 2):
                path = os.path.join(MODELS_DIR, "raw", f"{model}_{asset}_{c}.png")
                if not os.path.exists(path):
                    Image.fromarray(run(build(ASSETS[asset], 1300 + mi * 100 + ai * 10 + c)).astype(np.uint8)).save(path)
                    print("generated", model, asset, c, flush=True)
                rows.append((model, asset, c, path))
        free()
    font = ImageFont.truetype("arial.ttf", 20)
    cell, pad = 192, 14
    cols = len(names) * 2
    sheet = Image.new("RGB", (170 + cols * (cell + pad), 2 * 2 * (cell + pad) + 40), (60, 60, 66))
    d = ImageDraw.Draw(sheet)
    for i, (model, asset, c, path) in enumerate(rows):
        mi = 0 if model == "sdxl" else 1
        col = (i % cols)
        raw = Image.open(path).convert("RGB").resize((cell, cell), Image.LANCZOS)
        px = pixel_icon(np.asarray(Image.open(path).convert("RGB")))
        tile = Image.new("RGBA", (cell, cell), SLOT + (255,))
        tile.alpha_composite(px.resize((cell, cell), Image.NEAREST))
        x = 170 + col * (cell + pad)
        y = 40 + mi * 2 * (cell + pad)
        sheet.paste(raw, (x, y))
        sheet.paste(tile.convert("RGB"), (x, y + cell + pad))
        if mi == 0:
            d.text((x, 10), f"{asset} {c}", fill="white", font=font)
    d.text((10, 40 + cell // 2), "SDXL+Game icon", fill="white", font=font)
    d.text((10, 40 + cell + pad + cell // 2), "  → 48 px", fill="white", font=font)
    d.text((10, 40 + 2 * (cell + pad) + cell // 2), "Qwen+Pixel Art", fill="white", font=font)
    d.text((10, 40 + 3 * (cell + pad) + cell // 2), "  → 48 px", fill="white", font=font)
    sheet.save(MODELS_DIR + ".png")
    print("sheet", MODELS_DIR + ".png", sheet.size)


# Іконки оберегів (A6, design/charms_plan.md §3): як іконки предметів (SampleProject/Assets/UI/Icons/Items/*.png, 36×36) —
# сіра плитка з рамкою й білими кутиками, на ній темний контурний знак ~20×20 зі згладженим краєм. Плитка — crystal.png
# без знака; знак малює Qwen-Image (Apache 2.0, текст у картинку, без моделі правок) товстими темними лініями на
# зеленому, ключ — key_green, далі альфа знака стискається до 20 px і кладеться кольором знака предметів.
CHARMS_RAW = "design/shots/candidates/charm_icons"
CHARMS_OUT = "SampleProject/Assets/UI/Icons/Items/charms"
ITEMS = "SampleProject/Assets/UI/Icons/Items"
GLYPH, GLYPH_BOX, TILE_BG = (58, 58, 66), 20, (122, 122, 125)
CHARMS = {  # кільце — просто обідок із прикрасою; амулет — на шнурку з петлею
    "grandfathers_ring": "an old plain signet ring with a flat square top, seen at a slight angle from above",
    "sand_runner_ring": "a ring with a small swept-back bird wing on its side",
    "hermit_amulet": "a pendant amulet shaped like a small hanging lantern, on a cord with a loop at the top",
    "breaker_ring": "a ring with a big round stone on top, a jagged crack running through the stone",
    "deep_gourd_amulet": "a pendant amulet shaped like a small round gourd flask with a stopper, on a cord with a loop",
    "jackal_tooth_amulet": "a pendant of one long curved animal fang, hanging from a cord with a loop at the top",
}
CHARM_PROMPT = (
    "A simple flat line icon of {subject}: bold very thick uniform dark charcoal outline strokes only, like a small "
    "user interface icon, no fill, no shading, no colour, one single object centred and filling two thirds of the "
    "frame, on a solid flat chroma key green (#00FF00) background. No text, no frame, no border."
)


def charm_tile(raw):
    """Сирий кадр → плитка 36×36 у манері іконок предметів. Знак — темні лінії (не «все, що не тло»: перстень діда
    модель поставила на зелений квадрат у світлій рамці, і ключ за рамкою взяв квадрат за знак)."""
    a = (np.clip((110.0 - raw.max(axis=2)) / 50.0, 0, 1) * 255).astype(np.uint8)
    ys, xs = np.nonzero(a > 24)
    mask = Image.fromarray(a[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1])
    k = GLYPH_BOX / max(mask.size)
    size = (max(1, round(mask.width * k)), max(1, round(mask.height * k)))
    # лінії моделі в 20 px виходили в 1 px і бліді; у предметів — ~2 px: товщаємо на 4× більшому кадрі на 1 px з боку (на 2 — злипались)
    mask = mask.resize((size[0] * 4, size[1] * 4), Image.LANCZOS).filter(ImageFilter.MaxFilter(3))
    mask = mask.resize(size, Image.LANCZOS)
    tile = Image.open(os.path.join(ITEMS, "crystal.png")).convert("RGBA")
    tile.paste(TILE_BG + (255,), (4, 4, 32, 32))  # знак кристала геть, рамка й кутики лишаються
    glyph = Image.new("RGBA", mask.size, GLYPH + (255,))
    glyph.putalpha(mask)
    tile.alpha_composite(glyph, ((36 - mask.width) // 2, (36 - mask.height) // 2))
    return tile


def charms_main(names):
    import comfy_backdrop as cb

    os.makedirs(os.path.join(CHARMS_RAW, "raw"), exist_ok=True)
    os.makedirs(CHARMS_OUT, exist_ok=True)
    cb.GW = 1024  # graph() читає ширину з модуля
    for ci, (cid, subject) in enumerate(CHARMS.items()):
        path = os.path.join(CHARMS_RAW, "raw", cid + ".png")
        if not os.path.exists(path) or cid in names:
            Image.fromarray(run(cb.graph(CHARM_PROMPT.format(subject=subject), 1500 + ci, 1024)).astype(np.uint8)).save(path)
            print("generated", cid, flush=True)
        charm_tile(np.asarray(Image.open(path).convert("RGB"))).save(os.path.join(CHARMS_OUT, cid + ".png"))
    free()
    # лист ×4: шість оберегів і два предмети для порівняння
    tiles = [(c, Image.open(os.path.join(CHARMS_OUT, c + ".png"))) for c in CHARMS]
    tiles += [(n, Image.open(os.path.join(ITEMS, n + ".png"))) for n in ("crystal", "potion")]
    font = ImageFont.truetype("arial.ttf", 15)
    cell, pad = 144, 16
    sheet = Image.new("RGB", (pad + len(tiles) * (cell + pad), cell + 2 * pad + 30), (29, 29, 39))
    d = ImageDraw.Draw(sheet)
    for i, (name, tile) in enumerate(tiles):
        x = pad + i * (cell + pad)
        sheet.paste(tile.convert("RGB").resize((cell, cell), Image.NEAREST), (x, pad))
        d.text((x, cell + pad + 6), name.replace("_amulet", "").replace("_ring", " ring")[:20], fill="white", font=font)
    sheet.save("design/shots/charm_icons.png")
    print("sheet design/shots/charm_icons.png", sheet.size)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--charms"]:
        charms_main(sys.argv[2:])
    elif sys.argv[1:2] == ["--models"]:
        models_main(sys.argv[2:] or ["hand_palm", "sword", "fire"])
    elif sys.argv[1:2] == ["--assets-k"]:
        assets_k_main(sys.argv[2:])
    elif sys.argv[1:2] == ["--assets"]:
        assets_main(sys.argv[2:])
    elif sys.argv[1:2] == ["--pixel"]:
        pixel_main(sys.argv[2] if len(sys.argv) > 2 else "E")
    elif sys.argv[1:] == ["--sheet"]:  # лише лист із збережених сирих кадрів, без моделі
        sheet_from([np.asarray(Image.open(raw_path(s[0])).convert("RGB")) for s in SKILLS])
    else:
        main()
