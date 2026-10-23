"""Склеює кадри capture_companion_assists.gd в одну картинку: рядок на асист, before | after (D465).
    python3 Scripts/Tools/companion_shots.py [before after] → design/shots/companions_before_after.png
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

DIR = Path("design/shots/companions")
ORDER = ["astrit", "alisia", "urizen", "guard"]
SCALE = 0.5
GAP = 8

tags = sys.argv[1:] or ["before", "after"]
cells = [[Image.open(DIR / f"{tag}_{cid}_{n}.png") for tag in tags for n in (0, 1)] for cid in ORDER]
w, h = int(cells[0][0].width * SCALE), int(cells[0][0].height * SCALE)
cols = len(cells[0])
out = Image.new("RGB", (cols * w + (cols - 1) * GAP + GAP * 2, len(ORDER) * (h + GAP) + 30), (20, 20, 24))
draw = ImageDraw.Draw(out)
for t, tag in enumerate(tags):
    draw.text((t * 2 * (w + GAP) + 10 + (GAP if t else 0), 8), tag.upper(), fill=(240, 220, 160))
for r, row in enumerate(cells):
    for c, img in enumerate(row):
        x = c * (w + GAP) + (GAP * 2 if c >= 2 else 0)
        out.paste(img.resize((w, h), Image.NEAREST), (x, 30 + r * (h + GAP)))
    draw.text((6, 34 + r * (h + GAP)), ORDER[r], fill=(255, 255, 255))
name = "companions_before_after.png" if len(tags) == 2 else f"companions_{tags[0]}.png"
out.save(Path("design/shots") / name)
print("saved", name)
