"""Нарізка аркушів іконок з Figma AI (D604): кожен аркуш 1536×1024 — сітка 3×2, у клітинці один світлий силует на темному.

    python -I -B Scripts/Tools/slice_icon_sheets.py

Тло (темне) → прозоре за яскравістю, силует по центру з рівним полем, 256×256, світлий (тон дає гра: колір виду
вміння через modulate, D602). Пише SampleProject/Assets/UI/Icons/skills/<id>.png і лист для перегляду.
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SHEETS = "design/shots/candidates/icon_figma"
OUT = "SampleProject/Assets/UI/Icons/skills"
PREVIEW = "design/shots/skill_icons_all.png"
SIZE, FILL = 256, 0.82
# аркуш → шість вмінь (зліва направо, згори вниз); None — клітинку не беремо (Healing Palm перемальована на аркуші 3)
MANIFEST = {
    2: [
        "fire_strike",
        "electric_strike",
        None,
        "radiant_smite",
        "searing_hex",
        "dervish_whirl",
    ],
    3: [
        "healing_palm",
        "toughness",
        "shield_block",
        "devotion",
        "weapon_training",
        "riposte_instinct",
    ],
    4: [
        "last_stand",
        "fortitude",
        "mending_hands",
        "aura_of_resolve",
        "merciful_light",
        "skys_grace",
    ],
    5: [
        "zealous_answer",
        "skyfall_blessing",
        "aura_of_valour",
        "consecrated_ground",
        "unbroken_vow",
        "judgement_of_the_sky",
    ],
    6: [
        "blood_pact",
        "dread_aura",
        "desperate_hunger",
        "relentless",
        "cruel_momentum",
        "withering_grasp",
    ],
    7: [
        "hoarded_ward",
        "dark_riposte",
        "crimson_thirst",
        "eclipse_cleave",
        "balanced_strike",
        "bulwark",
    ],
    8: [
        "sand_stance",
        "still_water",
        "iron_body",
        "dervish_rhythm",
        "unshakable",
        "rooted_resolve",
    ],
    9: [
        "perfect_balance",
        "second_wind",
        "state_stunned",
        "state_burning",
        "state_cursed",
        "state_bleeding",
    ],
}
ULTIMATES = {"judgement_of_the_sky", "eclipse_cleave", "second_wind"}
ACTIVES = {
    "fire_strike",
    "electric_strike",
    "healing_palm",
    "radiant_smite",
    "searing_hex",
    "dervish_whirl",
    "skyfall_blessing",
    "withering_grasp",
    "balanced_strike",
}
TINT = {
    "active": (237, 230, 211),
    "passive": (150, 185, 215),
    "ultimate": (236, 196, 92),
    "state": (237, 230, 211),
}


def cut(cell):
    """Клітинка → RGBA силует: альфа за яскравістю над тлом, колір — сам силует (світлий)."""
    f = cell.astype(np.float32)
    lum = f.mean(axis=2)
    bg = np.median(
        np.concatenate(
            [lum[:6].ravel(), lum[-6:].ravel(), lum[:, :6].ravel(), lum[:, -6:].ravel()]
        )
    )
    alpha = np.clip((lum - bg - 18.0) / 90.0, 0, 1)
    rgba = np.dstack(
        [
            np.full_like(lum, 255),
            np.full_like(lum, 255),
            np.full_like(lum, 255),
            alpha * 255,
        ]
    ).astype(np.uint8)
    im = Image.fromarray(rgba)
    box = im.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    im = im.crop(box)
    side = round(max(im.width, im.height) / FILL)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq.resize((SIZE, SIZE), Image.LANCZOS)


def kind(skill):
    return (
        "state"
        if skill.startswith("state_")
        else "ultimate"
        if skill in ULTIMATES
        else "active"
        if skill in ACTIVES
        else "passive"
    )


def main():
    os.makedirs(OUT, exist_ok=True)
    icons = []
    for n, skills in MANIFEST.items():
        sheet = np.asarray(
            Image.open(os.path.join(SHEETS, f"sheet_{n}.png")).convert("RGB")
        )
        h, w = sheet.shape[:2]
        cw, ch = w // 3, h // 2
        for i, skill in enumerate(skills):
            if skill is None:
                continue
            r, c = divmod(i, 3)
            icon = cut(sheet[r * ch : (r + 1) * ch, c * cw : (c + 1) * cw])
            icon.save(os.path.join(OUT, skill + ".png"))
            icons.append((skill, icon))
    font = ImageFont.truetype("arial.ttf", 15)
    cell, pad, cols = 128, 10, 9
    rows = (len(icons) + cols - 1) // cols
    sheet = Image.new(
        "RGB", (pad + cols * (cell + pad), pad + rows * (cell + 26 + pad)), (34, 34, 40)
    )
    d = ImageDraw.Draw(sheet)
    for i, (skill, icon) in enumerate(icons):
        r, c = divmod(i, cols)
        x, y = pad + c * (cell + pad), pad + r * (cell + 26 + pad)
        tile = Image.new("RGBA", (cell, cell), (21, 20, 28, 255))
        tinted = Image.new("RGBA", icon.size, TINT[kind(skill)] + (255,))
        tinted.putalpha(icon.getchannel("A"))
        tile.alpha_composite(
            tinted.resize((cell - 16, cell - 16), Image.LANCZOS), (8, 8)
        )
        sheet.paste(tile.convert("RGB"), (x, y))
        d.text(
            (x, y + cell + 4),
            skill.replace("_", " ")[:18],
            fill=(210, 210, 215),
            font=font,
        )
    sheet.save(PREVIEW)
    print(len(icons), "icons ->", OUT, "| preview", PREVIEW, sheet.size)


if __name__ == "__main__":
    main()
