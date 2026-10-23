"""До/після кадрів capture_world_fixes.gd: на кімнату один аркуш, рядок на стовпець, ліворуч «до», праворуч «після».
  python Scripts/Tools/world_fixes_sheet.py <before_dir> <after_dir> <out_dir> [scale]
Без <after_dir> (передати «-») — лише «до»."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

before, after, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
scale = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
out.mkdir(parents=True, exist_ok=True)
rooms: dict[str, list[Path]] = {}
for p in sorted(before.glob("*.png"), key=lambda p: (p.stem.rsplit("_", 1)[0], int(p.stem.rsplit("_", 1)[1]))):
    rooms.setdefault(p.stem.rsplit("_", 1)[0], []).append(p)
for room, shots in rooms.items():
    first = Image.open(shots[0])
    w, h = int(first.width * scale), int(first.height * scale)
    cols = 1 if after == "-" else 2
    sheet = Image.new("RGB", (w * cols + 4 * (cols - 1), h * len(shots) + 4 * (len(shots) - 1)), "white")
    for row, shot in enumerate(shots):
        pair = [shot] if after == "-" else [shot, Path(after) / shot.name]
        for col, src in enumerate(pair):
            if src.exists():
                sheet.paste(Image.open(src).resize((w, h)), (col * (w + 4), row * (h + 4)))
        ImageDraw.Draw(sheet).text((4, row * (h + 4) + 4), shot.stem, fill="yellow")
    sheet.save(out / f"{room}.png")
    print(out / f"{room}.png", sheet.size)
