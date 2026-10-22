"""Складає вирізи capture_art_fixes.gd в один design/shots/art_fixes_all.png (правки арту fe96e88a у грі).
    python Scripts/Tools/art_fixes_sheet.py <out_dir capture_art_fixes.gd>
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

TILE = (480, 400)
LABEL = 28
ROWS = [
    [("malik", "Malik: robe solid"), ("alchemist", "alchemist: grey mask"), ("priestess", "priestess: no stick"),
     ("grandfather", "grandfather: staff in one hand"), ("djinn_death0", "fire djinn death 0")],
    [("dagger_heavy1", "dagger HeavyWindup = Heavy/1"), ("dagger_heavy2", "dagger HeavyStrike = Heavy/2"),
     ("bandit_stagger0", "bandit stagger 0 (+ tint)"), ("bandit_stagger1", "bandit stagger 1 (+ tint)")],
]
OUT = "design/shots/art_fixes_all.png"


def main(src):
    font = ImageFont.load_default(size=20)
    cols = max(len(r) for r in ROWS)
    far = Image.open(os.path.join(src, "boss_far.png")).convert("RGB")
    far_w = TILE[0] * cols
    far = far.resize((far_w, far_w * far.height // far.width), Image.LANCZOS)
    sheet = Image.new("RGB", (far_w, len(ROWS) * (TILE[1] + LABEL) + far.height + LABEL), (24, 24, 28))
    draw = ImageDraw.Draw(sheet)
    for r, row in enumerate(ROWS):
        for c, (name, label) in enumerate(row):
            x, y = c * TILE[0], r * (TILE[1] + LABEL)
            draw.text((x + 8, y + 4), label, fill=(240, 240, 240), font=font)
            sheet.paste(Image.open(os.path.join(src, name + ".png")).convert("RGB"), (x, y + LABEL))
    y = len(ROWS) * (TILE[1] + LABEL)
    draw.text((8, y + 4), "LabBoss: far layer glyphs (full frame)", fill=(240, 240, 240), font=font)
    sheet.paste(far, (0, y + LABEL))
    sheet.save(OUT)
    print("written", OUT, sheet.size)


if __name__ == "__main__":
    main(sys.argv[1])
