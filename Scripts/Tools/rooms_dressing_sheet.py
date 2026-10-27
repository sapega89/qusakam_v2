"""Аркуш кадрів для звіту rooms-dressing (R2/R3).

    python rooms_dressing_sheet.py OUT.png COLS WIDTH  label=path [label=path ...]
    python rooms_dressing_sheet.py OUT.png pairs WIDTH  label=before.png|after.png ...

COLS — кадрів у ряду; «pairs» — кожен рядок: «до» ліворуч, «після» праворуч. WIDTH — ширина одного кадру.
"""
import sys
from PIL import Image, ImageDraw


def tile(path: str, w: int) -> Image.Image:
    im = Image.open(path).convert("RGB")
    return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)


def label(im: Image.Image, text: str) -> None:
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 + 7 * len(text), 16), fill=(0, 0, 0))
    d.text((4, 2), text, fill=(255, 255, 255))


def main() -> None:
    out, mode, w = sys.argv[1], sys.argv[2], int(sys.argv[3])
    items = [a.split("=", 1) for a in sys.argv[4:]]
    if mode == "pairs":
        rows = []
        for name, paths in items:
            before, after = paths.split("|")
            a, b = tile(before, w), tile(after, w)
            label(a, name + " - before")
            label(b, name + " - after")
            rows.append((a, b))
        h = rows[0][0].height
        sheet = Image.new("RGB", (2 * w + 4, len(rows) * (h + 4)), (40, 40, 40))
        for i, (a, b) in enumerate(rows):
            sheet.paste(a, (0, i * (h + 4)))
            sheet.paste(b, (w + 4, i * (h + 4)))
    else:
        cols = int(mode)
        tiles = []
        for name, path in items:
            t = tile(path, w)
            label(t, name)
            tiles.append(t)
        h = tiles[0].height
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * (w + 4), rows * (h + 4)), (40, 40, 40))
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % cols) * (w + 4), (i // cols) * (h + 4)))
    sheet.save(out)
    print("saved", out, sheet.size)


main()
