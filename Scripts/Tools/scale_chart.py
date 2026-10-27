#!/usr/bin/env python3
"""Розмірна сітка (design/world_scale_plan.md, слайс 1): картинка з probe.json зонда probe_world_scale.gd.

  Scripts/Tools/scale_chart.py [design/shots/scale/probe.json]

design/shots/scale_chart.png — сітка 1 H, герой, і для кожної категорії справжні спрайти в їхньому розмірі у світі
(1 px картинки = 1 px світу) поруч із сірим контуром цілі; порушники підписані червоним із відношенням.
design/shots/scale/rooms/<кімната>_grid.jpg — кадр кімнати з лінійкою 1 H від ніг героя.
design/shots/scale/tables.md — таблиці для звіту (кімнати, найгірші порушники, категорії).
Pillow; на цій машині — /usr/bin/python3 (системний Pillow у /usr/local зламаний).
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
CHART_W = 2400
MARGIN = 16
LABEL_W = 230
GAP = 18
BG = (30, 32, 38)
GRID = (62, 66, 78)
GRID_FIG = (70, 92, 80)
TEXT = (220, 222, 228)
DIM = (140, 144, 156)
BAD = (240, 86, 80)
OK = (110, 200, 120)
GHOST = (170, 174, 186)
SKIP_ROWS = {"hero", "sky"}
# Хто з поза-цілями лише показаний, без контуру: monster (D560), unknown.


def res(path: str) -> Path:
    return ROOT / path.removeprefix("res://")


_images: dict[str, Image.Image] = {}


def texture(path: str) -> Image.Image:
    if path not in _images:
        _images[path] = Image.open(res(path)).convert("RGBA")
    return _images[path]


def part_image(part: dict) -> Image.Image:
    """Непрозорий кадр частини у px світу (масштаб частини, найближчий сусід)."""
    fx, fy, fw, fh = part["frame"]
    ux, uy, uw, uh = part["used"]
    sx, sy = abs(part["scale"][0]), abs(part["scale"][1])
    if res(part["texture"]).suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
        # SVG (іконки підбирання): Pillow не малює — сірий прямокутник того ж розміру.
        return Image.new("RGBA", (max(1, round(uw * sx)), max(1, round(uh * sy))), GHOST + (120,))
    img = texture(part["texture"]).crop((fx + ux, fy + uy, fx + ux + uw, fy + uy + uh))
    if part["flip_h"]:
        img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    w, h = max(1, round(uw * sx)), max(1, round(uh * sy))
    img = img.resize((w, h), Image.Resampling.NEAREST)
    if part.get("modulate_a", 1.0) < 1.0:
        a = img.getchannel("A").point(lambda v: int(v * part["modulate_a"]))
        img.putalpha(a)
    return img


def object_image(obj: dict) -> Image.Image:
    """Об'єкт із кількох частин — кожна на своєму місці його bbox у світі."""
    bx, by, bw, bh = obj["bbox"]
    canvas = Image.new("RGBA", (max(1, round(bw)), max(1, round(bh))), (0, 0, 0, 0))
    for part in obj["parts"]:
        px, py, _, _ = part["bbox"]
        img = part_image(part)
        canvas.alpha_composite(img, (max(0, round(px - bx)), max(0, round(py - by))))
    return canvas


def font(size: int) -> ImageFont.ImageFont:
    for name in ("DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def offender(obj: dict) -> bool:
    return obj["verdict"] in ("too big", "too small")


def badness(obj: dict) -> float:
    return abs(math.log(obj["ratio"])) if obj.get("ratio") else 0.0


def chart_rows(probe: dict, scale: dict) -> list[dict]:
    """Ряд на категорію: різні спрайти (текстура+кадр+масштаб) один раз, з кімнатами, де стоять."""
    by_cat: dict[str, dict] = {}
    order = [c["id"] for c in scale["categories"]] + ["unknown"]
    for room in probe["rooms"]:
        for obj in room["objects"]:
            cat = obj["category"]["id"]
            if cat in SKIP_ROWS:
                continue
            key = (tuple((p["texture"], tuple(p["frame"]), tuple(p["scale"])) for p in obj["parts"]), obj.get("target_world"))
            row = by_cat.setdefault(cat, {"id": cat, "items": {}})
            item = row["items"].setdefault(key, {"obj": obj, "rooms": []})
            if room["room"] not in item["rooms"]:
                item["rooms"].append(room["room"])
    rows = [by_cat[c] for c in order if c in by_cat]
    for row in rows:
        row["items"] = sorted(row["items"].values(), key=lambda i: -i["obj"]["height_world"])
    return rows


def draw_chart(probe: dict, scale: dict, out: Path) -> None:
    unit = scale["unit"]["world_px"]
    fig = probe["hero"]["figure_world_px"]
    hero_part = {"texture": probe["hero"]["texture"], "frame": probe["hero"]["frame"], "used": probe["hero"]["used"],
                 "flip_h": False, "scale": probe["hero"]["scale"]}
    hero = part_image(hero_part)
    f_big, f_small = font(18), font(13)
    cats = {c["id"]: c for c in scale["categories"]}
    # Розкладка: ряди, у кожному кілька «полиць», якщо не влазить у ширину.
    shelves: list[dict] = []
    for row in chart_rows(probe, scale):
        line: list[dict] = []
        x = MARGIN + LABEL_W + hero.width + GAP
        for item in row["items"]:
            img = object_image(item["obj"])
            tgt = item["obj"].get("target_world")
            ghost_w = round(img.width * tgt / img.height) if tgt else 0
            w = img.width + (GAP // 2 + ghost_w if tgt else 0)
            w = max(w, 90)
            if line and x + w > CHART_W - MARGIN:
                shelves.append({"row": row, "items": line, "first": len(shelves) == 0 or shelves[-1]["row"] is not row})
                line, x = [], MARGIN + LABEL_W + hero.width + GAP
            line.append({"item": item, "img": img, "ghost_w": ghost_w, "tgt": tgt, "x": x, "w": w})
            x += w + GAP
        shelves.append({"row": row, "items": line, "first": len(shelves) == 0 or shelves[-1]["row"] is not row})
    for s in shelves:
        tallest = max([max(i["img"].height, i["tgt"] or 0) for i in s["items"]] + [unit])
        s["height"] = int(math.ceil(tallest / unit) * unit) + 56
    title_h = 70
    total_h = title_h + sum(s["height"] for s in shelves) + MARGIN
    im = Image.new("RGB", (CHART_W, total_h), BG)
    d = ImageDraw.Draw(im)
    d.text((MARGIN, 12), "World scale chart (draft, world_scale.json) — 1 px = 1 world px; grid = 1 H = %d world px "
           "(64 art px x1.5); green line = the hero's drawn figure %.1f px; grey box = chart target" % (unit, fig),
           fill=TEXT, font=f_big)
    d.text((MARGIN, 38), "red = off the chart (ratio = drawn / target, +-1 art px is ok); on a parallax plane the target "
           "is x the plane factor; rooms listed under each sprite", fill=DIM, font=f_small)
    y = title_h
    for s in shelves:
        base = y + s["height"] - 40
        for k in range(1, s["height"] // unit + 1):
            gy = base - k * unit
            if gy > y:
                d.line((MARGIN + LABEL_W - 10, gy, CHART_W - MARGIN, gy), fill=GRID)
        d.line((MARGIN + LABEL_W - 10, base - fig, CHART_W - MARGIN, base - fig), fill=GRID_FIG)
        d.line((MARGIN, base, CHART_W - MARGIN, base), fill=DIM)
        cat = cats.get(s["row"]["id"])
        if s["first"]:
            label = s["row"]["id"]
            sub = ("%s H = %s art px" % (cat["h"], cat["art_px"])) if cat and cat["h"] else "no chart value"
            d.text((MARGIN, base - 46), label, fill=TEXT, font=f_big)
            d.text((MARGIN, base - 22), sub, fill=DIM, font=f_small)
        im.paste(hero, (MARGIN + LABEL_W, base - hero.height), hero)
        for it in s["items"]:
            img, x = it["img"], it["x"]
            im.paste(img, (x, base - img.height), img)
            obj = it["item"]["obj"]
            if it["tgt"]:
                gx = x + img.width + GAP // 2
                _dashed(d, (gx, base - round(it["tgt"]), gx + it["ghost_w"], base), GHOST)
            bad = offender(obj)
            colour = BAD if bad else (OK if obj["verdict"] == "ok" else DIM)
            tag = "%s x%.2f" % (obj["verdict"], obj["ratio"]) if obj.get("ratio") else obj["verdict"]
            d.text((x, base + 3), "%d px %s" % (round(obj["height_world"]), tag), fill=colour, font=f_small)
            d.text((x, base + 19), ", ".join(it["item"]["rooms"])[:max(12, it["w"] // 7)], fill=DIM, font=f_small)
            if bad:
                d.rectangle((x - 2, base - img.height - 2, x + img.width + 1, base + 1), outline=BAD)
        y += s["height"]
    im.save(out, optimize=True)
    print("chart -> %s (%dx%d)" % (out.relative_to(ROOT), im.width, im.height))


def _dashed(d: ImageDraw.ImageDraw, box: tuple, colour: tuple) -> None:
    x0, y0, x1, y1 = box
    for x in range(x0, x1, 8):
        d.line((x, y0, min(x + 4, x1), y0), fill=colour)
        d.line((x, y1, min(x + 4, x1), y1), fill=colour)
    for y in range(y0, y1, 8):
        d.line((x0, y, x0, min(y + 4, y1)), fill=colour)
        d.line((x1, y, x1, min(y + 4, y1)), fill=colour)


def room_grids(probe: dict, scale: dict, shots: Path) -> None:
    """Кадр кімнати зменшений до 1280 px з лінійкою 1 H (і висотою фігури героя) від його ніг."""
    unit = scale["unit"]["world_px"]
    fig = probe["hero"]["figure_world_px"]
    for room in probe["rooms"]:
        if not room["capture"]:
            continue
        src = shots / room["capture"]
        im = Image.open(src).convert("RGB")
        z = room["zoom"]
        hx, hy, hw, hh = room["hero_screen"]
        feet = hy + hh
        d = ImageDraw.Draw(im)
        for k in range(1, 9):
            gy = feet - k * unit * z
            if gy < 0:
                break
            d.line((0, gy, im.width, gy), fill=(255, 255, 255), width=1)
            d.text((6, gy + 2), "%d H" % k, fill=(255, 255, 255), font=font(22))
        d.line((0, feet, im.width, feet), fill=(255, 220, 0), width=2)
        d.line((hx - 20, feet - fig * z, hx + hw + 20, feet - fig * z), fill=(0, 255, 120), width=2)
        im = im.resize((1280, round(im.height * 1280 / im.width)), Image.Resampling.LANCZOS)
        out = shots / "rooms" / ("%s_grid.jpg" % room["room"])
        im.save(out, quality=82)
    print("room grids -> %s" % (shots / "rooms").relative_to(ROOT))


def tables(probe: dict, scale: dict, out: Path) -> None:
    unit = scale["unit"]["world_px"]
    fig = probe["hero"]["figure_world_px"]
    lines: list[str] = []
    stats = []
    for room in probe["rooms"]:
        objs = room["objects"]
        judged = [o for o in objs if o.get("ratio")]
        bad = [o for o in judged if offender(o)]
        big = [o for o in bad if o["verdict"] == "too big"]
        worst = max(bad, key=badness) if bad else None
        # Інша одиниця: H = намальована фігура героя (70.5 px), цілі × fig/unit.
        alt_bad = [o for o in judged if abs(o["height_world"] - o["target_world"] * fig / unit) > 1.5 * fig / unit]
        stats.append((badness(worst) if worst else 0.0, room, judged, bad, big, worst, alt_bad))
    stats.sort(key=lambda s: (-s[0], -len(s[3])))
    lines.append("| Room | objects | judged | off | too big | worst | worst ratio | unknown | backdrops |")
    lines.append("|---|---|---|---|---|---|---|---|---|")
    for b, room, judged, bad, big, worst, _alt in stats:
        unknown = len([o for o in room["objects"] if o["verdict"] == "unknown"])
        w = "`%s` (%s)" % (worst["path"], worst["category"]["id"]) if worst else "—"
        lines.append("| %s | %d | %d | %d | %d | %s | %s | %d | %d |" % (room["room"], len(room["objects"]), len(judged), len(bad),
                     len(big), w, ("x%.2f" % worst["ratio"]) if worst else "—", unknown, len(room["backdrops"])))
    lines.append("")
    every = [(room["room"], o) for room in probe["rooms"] for o in room["objects"] if o.get("ratio") and offender(o)]
    every.sort(key=lambda ro: -badness(ro[1]))
    lines.append("| # | Room | object | category (keyword) | plane | drawn px | target px | ratio | scale | texture |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|")
    for i, (room, o) in enumerate(every, 1):
        sc = o["parts"][0]["scale"]
        lines.append("| %d | %s | `%s` | %s (%s) | %s | %.1f | %.1f | x%.2f %s | %s | `%s` |" % (
            i, room, o["path"], o["category"]["id"], o["category"]["keyword"], o["plane"], o["height_world"], o["target_world"],
            o["ratio"], o["verdict"], "%g" % abs(sc[1]), o["textures"][0].removeprefix("res://SampleProject/")))
    lines.append("")
    lines.append("| Category | target px | n | ok | too big | too small | median ratio | median ratio vs figure-H |")
    lines.append("|---|---|---|---|---|---|---|---|")
    by: dict[str, list] = {}
    for room in probe["rooms"]:
        for o in room["objects"]:
            by.setdefault(o["category"]["id"], []).append(o)
    for cat in [c["id"] for c in scale["categories"]] + ["unknown"]:
        objs = by.get(cat, [])
        if not objs:
            continue
        judged = [o for o in objs if o.get("ratio")]
        rs = sorted(o["ratio"] for o in judged)
        med = rs[len(rs) // 2] if rs else None
        tgt = next((c["art_px"] for c in scale["categories"] if c["id"] == cat), None)
        lines.append("| %s | %s | %d | %d | %d | %d | %s | %s |" % (
            cat, ("%g" % (tgt * 1.5)) if tgt else "—", len(objs), len([o for o in judged if o["verdict"] == "ok"]),
            len([o for o in judged if o["verdict"] == "too big"]), len([o for o in judged if o["verdict"] == "too small"]),
            ("x%.2f" % med) if med else "—", ("x%.2f" % (med * unit / fig)) if med else "—"))
    lines.append("")
    lines.append("Unknown objects (no keyword):")
    for room in probe["rooms"]:
        names = ["`%s` %.0f px" % (o["path"], o["height_world"]) for o in room["objects"] if o["verdict"] == "unknown"]
        if names:
            lines.append("- %s: %s" % (room["room"], ", ".join(names)))
    lines.append("")
    lines.append("Backdrop planes (not measured as objects):")
    for room in probe["rooms"]:
        lines.append("- %s: %s" % (room["room"], ", ".join("`%s` x%s %.0fx%.0f" % (b["path"], b["plane"], b["width_world"],
                     b["height_world"]) for b in room["backdrops"])))
    out.write_text("\n".join(lines) + "\n")
    print("tables -> %s" % out.relative_to(ROOT))


def main() -> None:
    probe_path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "design/shots/scale/probe.json"
    probe = json.loads(probe_path.read_text())
    scale = json.loads((ROOT / "design/world_scale.json").read_text())
    shots = probe_path.parent
    draw_chart(probe, scale, ROOT / "design/shots/scale_chart.png")
    room_grids(probe, scale, shots)
    tables(probe, scale, shots / "tables.md")


if __name__ == "__main__":
    main()
