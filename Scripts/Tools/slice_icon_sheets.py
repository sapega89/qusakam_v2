"""Нарізка аркушів іконок з Figma AI (D604): кожен аркуш 1536×1024 — сітка 3×2, у клітинці один світлий силует на темному.

    python -I -B Scripts/Tools/slice_icon_sheets.py

Тло (темне) → прозоре за яскравістю, силует по центру з рівним полем, 256×256, світлий (тон дає гра: колір виду
вміння через modulate, D602). Пише SampleProject/Assets/UI/Icons/skills/<id>.png і лист для перегляду.
"""

import json
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
    # 33 чернетки D535 (skills-v2); аркуш 15 — три останні й запасні варіанти трьох ризикових (D635)
    10: [
        "dash_strike",
        "rising_slash",
        "shield_bash",
        "ground_slam",
        "holy_javelin",
        "battle_cry",
    ],
    11: [
        "counter_stance",
        "keen_edge",
        "heavy_hand",
        "shield_charge",
        "lightspear",
        "aegis",
    ],
    12: [
        "hallowed_circle",
        None,  # стяг із фігуркою — взято кулак зі стягом з аркуша 15
        "heavens_anvil",
        "radiant_flare",
        "shield_of_faith",
        "blood_rush",
    ],
    13: [
        "chain_of_night",
        "blood_price",
        "night_reaper",
        None,  # паща з кільцями — взято голову вовка з аркуша 15
        "hellfire_stomp",
        None,  # розбитий щит із душею — взято косу з аркуша 15
    ],
    14: [
        "embers_within",
        "wind_step",
        "sand_veil",
        "stone_palm",
        "sweeping_arc",
        "mirror_stance",
    ],
    15: [
        "centered_breath",
        "dune_quake",
        "light_feet",
        "rally",
        "dread_howl",
        "soul_harvest",
    ],
}
# вид іконки для листа перегляду — з даних вмінь (skill_type, ultimate), а не зі списків
SKILLS = {
    s["id"]: s
    for s in json.load(
        open("SampleProject/Resources/Data/skills.json", encoding="utf-8")
    )["skills"]
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
    if skill.startswith("state_"):
        return "state"
    data = SKILLS[skill]
    if data.get("ultimate"):
        return "ultimate"
    return "active" if data["skill_type"] == "active" else "passive"


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
