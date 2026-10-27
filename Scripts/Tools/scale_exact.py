#!/usr/bin/env python3
"""Точна розмірна сітка (design/world_scale_plan.md, R4): перерахунок probe.json за design/world_scale.json без Godot.

  /usr/bin/python3 Scripts/Tools/scale_exact.py [probe.json] [room ...]

Бере probe.json зонда probe_world_scale.gd (виміряний у Godot) і:
1. для кімнат [room ...] (змінених після того прогону) читає Maps/<room>.tscn: прибирає об'єкти й плани, яких у сцені
   вже нема, і міряє нові Sprite2D статично (непрозорий bbox текстури × масштаби предків у цьому ж файлі, план =
   scroll_scale.x найближчого Parallax2D, і вкладеного інстанса теж). Лише прості спрайти без region/hframes;
2. наново ставить категорію (той самий порядок джерел, що _haystacks/_category у probe_world_scale.gd) і вердикт:
   ціль = round(art_px × план) art px × 1.5, ok лише в межах ±tolerance_art_px;
3. до кожного порушника пише виправлення: ×0.5 / ×0.75 / ×2, якщо після нього висота точно в межах і сітка пікселів
   ціла (texel кратний art px), інакше «regenerate at N art px».
Результат — назад у той самий probe.json; далі Scripts/Tools/scale_chart.py.
"""
import json
import math
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "SampleProject/Maps"


def res(path: str) -> Path:
    return ROOT / path.removeprefix("res://")


# --- .tscn -------------------------------------------------------------------------------------------------------

NODE_RE = re.compile(r'^\[node name="([^"]+)"(?: type="([^"]+)")?(?: parent="([^"]*)")?(?: instance=ExtResource\("([^"]+)"\))?')
EXT_RE = re.compile(r'^\[ext_resource type="([^"]+)"[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"')
VEC_RE = re.compile(r"Vector2\(([-\d.e]+), ([-\d.e]+)\)")


def parse_tscn(path: Path) -> tuple[dict, list[dict]]:
    ext: dict[str, str] = {}
    nodes: list[dict] = []
    cur: dict | None = None
    for line in path.read_text().splitlines():
        m = EXT_RE.match(line)
        if m:
            ext[m.group(3)] = m.group(2)
            continue
        m = NODE_RE.match(line)
        if m:
            name, typ, parent, inst = m.groups()
            if 'parent="' not in line:
                parent = None
            if 'type="' not in line:
                typ = None
            cur = {"name": name, "type": typ, "parent": parent, "instance": ext.get(inst) if inst else None, "props": {}}
            nodes.append(cur)
            continue
        if line.startswith("["):
            cur = None
            continue
        if cur is not None and " = " in line:
            k, v = line.split(" = ", 1)
            cur["props"][k] = v
    for n in nodes:
        n["path"] = n["name"] if n["parent"] in (".", None) else "%s/%s" % (n["parent"], n["name"])
        if n["parent"] is None:
            n["path"] = "."
    return ext, nodes


def vec(props: dict, key: str, default: tuple[float, float]) -> tuple[float, float]:
    m = VEC_RE.search(props.get(key, ""))
    return (float(m.group(1)), float(m.group(2))) if m else default


def instance_root(scene: str) -> dict:
    _, nodes = parse_tscn(res(scene))
    return nodes[0]


def node_chain(nodes_by_path: dict, path: str) -> list[dict]:
    chain = []
    while path not in (".", ""):
        n = nodes_by_path[path]
        chain.append(n)
        path = n["parent"] if n["parent"] not in (None,) else "."
    return chain


def node_type(n: dict) -> str:
    if n["type"]:
        return n["type"]
    if n["instance"]:
        return instance_root(n["instance"])["type"] or ""
    return ""


def node_props(n: dict) -> dict:
    """Властивості вузла поверх кореня його інстанса."""
    if n["instance"]:
        base = dict(instance_root(n["instance"])["props"])
        base.update(n["props"])
        return base
    return n["props"]


def used_rect(tex: str) -> tuple[int, int, int, int]:
    img = Image.open(res(tex)).convert("RGBA")
    box = img.getchannel("A").getbbox()
    if box is None:
        return (0, 0, 0, 0)
    return (box[0], box[1], box[2] - box[0], box[3] - box[1])


def static_sprites(room: str) -> tuple[list[dict], set[str]]:
    """Нові Sprite2D сцени кімнати (без інстансів у ланцюгу), їхні частини як у _part; і множина шляхів вузлів."""
    ext, nodes = parse_tscn(MAPS / ("%s.tscn" % room))
    by_path = {n["path"]: n for n in nodes}
    out = []
    for n in nodes:
        if n["type"] != "Sprite2D" or n["path"] == ".":
            continue
        p = n["props"]
        tex_id = re.search(r'ExtResource\("([^"]+)"\)', p.get("texture", ""))
        if not tex_id or "region_enabled" in p or "hframes" in p or "vframes" in p:
            continue
        chain = node_chain(by_path, n["path"])
        if any(c["instance"] and c is not n and node_type(c) != "Parallax2D" for c in chain):
            continue  # усередині інстанса сцени — його міряв Godot
        if any(node_props(c).get("visible") == "false" for c in chain):
            continue
        tex = ext[tex_id.group(1)]
        ux, uy, uw, uh = used_rect(tex)
        if uw == 0:
            continue
        sx = sy = 1.0
        x = y = 0.0
        plane = 1.0
        for c in chain:  # від вузла до кореня
            cp = node_props(c)
            csx, csy = vec(cp, "scale", (1.0, 1.0))
            px, py = vec(cp, "position", (0.0, 0.0))
            x, y = px + x * csx, py + y * csy
            sx, sy = sx * csx, sy * csy
            if node_type(c) == "Parallax2D" and plane == 1.0 and "scroll_scale" in cp:
                plane = vec(cp, "scroll_scale", (1.0, 1.0))[0]
        tw, th = Image.open(res(tex)).size
        centered = p.get("centered") != "false"
        flip_h = p.get("flip_h") == "true"
        ox, oy = vec(p, "offset", (0.0, 0.0))
        lx = (ox - (tw / 2 if centered else 0)) + ((tw - ux - uw) if flip_h else ux)
        ly = (oy - (th / 2 if centered else 0)) + uy
        own_sx, own_sy = vec(p, "scale", (1.0, 1.0))
        # x, y вже включає позицію вузла; локальний зсув множиться на повний масштаб.
        bx, by = x + lx * sx, y + ly * sy
        part = {"node": n["path"], "texture": tex, "frame": [0, 0, tw, th], "used": [ux, uy, uw, uh], "flip_h": flip_h,
                "scale": [round(sx, 4), round(sy, 4)], "rotation": 0.0, "modulate_a": 1.0,
                "bbox": [round(bx, 1), round(by, 1), round(uw * abs(sx), 1), round(uh * abs(sy), 1)]}
        out.append({"path": n["path"], "scene": "", "plane": round(plane, 3), "height_world": round(uh * abs(sy), 1),
                    "width_world": round(uw * abs(sx), 1), "bbox": part["bbox"], "textures": [tex], "parts": [part],
                    "measured": "static (scale_exact.py)", "_own_scale": own_sy})
    return out, set(by_path)


# --- категорія й вердикт (порт probe_world_scale.gd) ----------------------------------------------------------------

TOKENS_RE = re.compile(r"[a-z]+")
CAMEL_RE = re.compile(r"([a-z0-9])([A-Z])")


def tokens(text: str) -> list[str]:
    return TOKENS_RE.findall(CAMEL_RE.sub(r"\1_\2", text).lower())


def hay(words: list[str]) -> str:
    return "_" + "_".join(words) + "_"


def haystacks(obj: dict, room_names: list[str]) -> list[str]:
    path = obj["path"]
    if obj.get("spawn_kind"):
        name = "ScaleProbe_%s" % obj["spawn_kind"]
    else:
        name = path.split("/")[-1]
        if name.startswith("@"):
            name = path.split("/")[-2]
    words = tokens(name)
    first_tokens = tokens(name.split("_")[0]) if "_" in name else []
    head = first_tokens[0] if "_" in name and first_tokens else (words[-1] if words else "")
    scene = obj.get("scene", "") or ""
    files = [Path(scene).stem if scene else ""]
    paths = [scene]
    for part in obj["parts"]:
        files.append(Path(part["texture"]).stem)
        files.append(part["node"].split("/")[-1])
        p = part["texture"]
        for room in room_names:
            p = p.replace("/%s/" % room, "/")
        paths.append(p)
    out = []
    if obj.get("spawn_kind"):
        for bit in (Path(scene).stem, obj["spawn_kind"]):
            out.append(hay(tokens(bit)))
    out.append(hay([head]))
    out.append(hay(words))
    for group in (files, paths):
        allw: list[str] = []
        for bit in group:
            allw += tokens(bit)
        out.append(hay(allw))
    return out


def category(hays: list[str], chart: dict) -> dict:
    for h in hays:
        for cat in chart["categories"]:
            if cat["id"] == "hero":
                continue
            for kw in cat["keywords"]:
                for tail in ("_", "s_", "es_"):
                    if ("_" + kw + tail) in h:
                        return {"id": cat["id"], "keyword": kw, "art_px": cat["art_px"], "h": cat["h"]}
    return {"id": "unknown", "keyword": "", "art_px": None, "h": None}


def verdict(obj: dict, chart: dict) -> None:
    cat = obj["category"]
    obj.pop("fix", None)
    if cat["id"] == "unknown" or cat["art_px"] is None:
        obj["target_world"] = None
        obj["target_art"] = None
        obj["verdict"] = "no target" if cat["id"] != "unknown" else "unknown"
        obj["ratio"] = None
        return
    plane = obj["plane"] if obj["plane"] > 0 else 1.0
    a2w = chart["unit"]["art_to_world"]
    art = round(cat["art_px"] * plane)
    target = art * a2w
    tol = chart["tolerance_art_px"] * a2w
    obj["target_art"] = art
    obj["target_world"] = target
    obj["ratio"] = round(obj["height_world"] / target, 2)
    if abs(obj["height_world"] - target) <= tol:
        obj["verdict"] = "ok"
        return
    obj["verdict"] = "too big" if obj["height_world"] > target else "too small"
    obj["fix"] = fix(obj, art, target, tol, a2w)


def fix(obj: dict, art: int, target: float, tol: float, a2w: float) -> str:
    """×0.5 / ×0.75 / ×2, лише коли після нього висота в межах і texel = ціле число art px; інакше regenerate."""
    h = obj["height_world"]
    texel_art = abs(obj["parts"][0]["scale"][1]) / a2w  # скільки art px займає один texel сьогодні
    for f in (0.5, 0.75, 2.0):
        if abs(h * f - target) > tol:
            continue
        t = texel_art * f
        if abs(t - round(t)) < 1e-3 and round(t) >= 1:
            return "x%g (node scale x%g; 1 texel = %d art px)" % (f, f, round(t))
        if f == 0.5 and abs(texel_art - 1.0) < 1e-3:
            return "x0.5 (2:1 downsample of the texture, node scale unchanged at 1 texel = 1 art px)"
    return "regenerate at %d art px tall (%g world px)" % (art, target)


def main() -> None:
    args = sys.argv[1:]
    probe_path = Path(args[0]) if args and args[0].endswith(".json") else ROOT / "design/shots/scale/probe.json"
    changed = [a for a in args if not a.endswith(".json")]
    probe = json.loads(probe_path.read_text())
    chart = json.loads((ROOT / "design/world_scale.json").read_text())
    probe["unit"] = chart["unit"]
    room_names = sorted(p.stem for p in MAPS.glob("*.tscn"))
    for room in probe["rooms"]:
        if room["room"] in changed:
            new, paths = static_sprites(room["room"])
            keep = []
            for o in room["objects"]:
                if o["path"] in paths:
                    keep.append(o)
            known = {o["path"] for o in keep} | {b["path"] for b in room["backdrops"] if b["path"] in paths}
            room["backdrops"] = [b for b in room["backdrops"] if b["path"] in paths]
            for o in new:
                if o["path"] in known:
                    continue
                o.pop("_own_scale")
                if o["width_world"] >= chart["backdrop_min_width_world_px"]:
                    room["backdrops"].append({"path": o["path"], "plane": o["plane"], "width_world": o["width_world"],
                                              "height_world": o["height_world"], "textures": o["textures"],
                                              "measured": o["measured"]})
                else:
                    keep.append(o)
            room["objects"] = keep
            room["static_patch"] = True
        if room.get("capture") and not (probe_path.parent / room["capture"]).exists():
            room["capture"] = ""
        if room.get("static_patch"):
            room["capture"] = ""  # кадр старий: лінійку кімнати не перемальовувати
        for o in room["objects"]:
            if o.get("spawn_kind") or not (o["textures"] and all(t.endswith(".svg") for t in o["textures"])):
                o["category"] = category(haystacks(o, room_names), chart)
            verdict(o, chart)
    probe_path.write_text(json.dumps(probe, indent="\t", ensure_ascii=False) + "\n")
    n = sum(len(r["objects"]) for r in probe["rooms"])
    off = sum(1 for r in probe["rooms"] for o in r["objects"] if o.get("fix"))
    print("scale_exact -> %s: %d objects, %d off" % (probe_path, n, off))


if __name__ == "__main__":
    main()
