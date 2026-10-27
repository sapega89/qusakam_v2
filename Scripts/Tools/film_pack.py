#!/usr/bin/env python3
"""Pack a room film for the depth critics (design/depth_critics_plan.md, slice 1).

From <src>/<Room>.avi and <src>/<Room>.layers.json (written by SampleProject/UI/film_rooms.gd) it writes, into
<dst>/<Room>/:
  filmstrip.jpg  8 frames 0.5 s apart in one sheet (2 x 4)
  slitscan.jpg   three horizontal bands (30 %, 55 %, 80 % of the height) of every frame, stacked in time: each plane
                 leaves streaks at its own slope, a plane that does not move draws vertical lines
  layers.json    the probe, copied
JPG quality 85, at most 1920 px wide. No video goes to git.

  python3 -I Scripts/Tools/film_pack.py pack <src> <dst> [Room ...]    (no rooms: every <src>/*.layers.json)
  python3 -I Scripts/Tools/film_pack.py report <dst>                   the probe table and the rule violations (md)

Needs cv2 + numpy (pip install opencv-python-headless).
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np

JPG = [cv2.IMWRITE_JPEG_QUALITY, 85]
MAX_W = 1920
STRIP_FRAMES = 8
STRIP_STEP_S = 0.5
BANDS = (0.30, 0.55, 0.80)
BAND_H = 3
# Rules (plan, decision 1).
SEEN = 0.001          # a plane counts on a screen from this coverage
SPEED_EPS = 0.03      # «faster» means faster by more than this
SPEED_STEP = 0.05     # speeds closer than this are one plane for «distinct speeds»
FLOOR_SPEED_EPS = 0.02
FLOOR_TOP_WORLD_PX = 4.0


def read_frames(avi: Path, first: int, last: int) -> list:
    cap = cv2.VideoCapture(str(avi))
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    frames = []
    i = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if first <= i <= last:
            frames.append(frame)
        i += 1
    cap.release()
    if not frames:
        raise SystemExit(f"{avi}: no frames {first}..{last} (the file has {total})")
    return frames


def fit_width(img: np.ndarray) -> np.ndarray:
    h, w = img.shape[:2]
    if w <= MAX_W:
        return img
    return cv2.resize(img, (MAX_W, round(h * MAX_W / w)), interpolation=cv2.INTER_AREA)


def label(img: np.ndarray, text: str) -> None:
    cv2.putText(img, text, (10, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 0), 4, cv2.LINE_AA)
    cv2.putText(img, text, (10, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2, cv2.LINE_AA)


def filmstrip(frames: list, fps: int) -> np.ndarray:
    step = round(STRIP_STEP_S * fps)
    picks = [min(i * step, len(frames) - 1) for i in range(STRIP_FRAMES)]
    h, w = frames[0].shape[:2]
    cw, ch = w // 4, h // 4
    sheet = np.zeros((ch * 2, cw * 4, 3), np.uint8)
    for k, i in enumerate(picks):
        cell = cv2.resize(frames[i], (cw, ch), interpolation=cv2.INTER_AREA)
        label(cell, f"{i / fps:.1f} s")
        r, c = divmod(k, 4)
        sheet[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] = cell
    return sheet


def slitscan(frames: list) -> np.ndarray:
    h, w = frames[0].shape[:2]
    parts = []
    for frac in BANDS:
        y = int(h * frac)
        band = np.concatenate([f[y:y + BAND_H] for f in frames], axis=0)
        head = np.zeros((40, w, 3), np.uint8)
        label(head, f"y = {y} px ({round(frac * 100)} %), time runs down, {len(frames)} frames")
        parts += [head, band]
    return np.concatenate(parts, axis=0)


def pack(src: Path, dst: Path, rooms: list) -> None:
    if not rooms:
        rooms = sorted(p.name.removesuffix(".layers.json") for p in src.glob("*.layers.json"))
    for room in rooms:
        layers = json.loads((src / f"{room}.layers.json").read_text())
        first, last = layers["info"]["film_frames"]
        frames = read_frames(src / f"{room}.avi", first, last)
        out = dst / room
        out.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(out / "filmstrip.jpg"), fit_width(filmstrip(frames, layers["movie_fps"])), JPG)
        cv2.imwrite(str(out / "slitscan.jpg"), fit_width(slitscan(frames)), JPG)
        (out / "layers.json").write_text(json.dumps(layers, indent=1, ensure_ascii=False) + "\n")
        print(f"PACK {room}: {len(frames)} frames -> {out}")


def best(screens: dict) -> dict:
    """The screen where the plane covers the most (its stats are read there)."""
    return max(screens.values(), key=lambda s: s.get("coverage", 0.0))


def seen_on(plane: dict, spot: str) -> bool:
    """Visible on that screen: its opaque pixels not covered by the planes drawn over it."""
    return plane["screens"][spot].get("visible", 0.0) >= SEEN


def violations(d: dict) -> list:
    out = []
    hero_z = d["hero_z"]
    zoom = d["zoom"]
    # A plane in front of the hero pinned to the view (TopShade, D749) is a screen overlay, not a depth plane.
    planes = [p for p in d["layers"] if p["kind"] != "camera" and p["speed_x"] is not None
              and not (p["z"] > hero_z and abs(p["speed_x"]) < SPEED_EPS)]
    spots = list(d["screens"])
    # 1. A plane drawn behind another (z, then tree order) moves faster than it, on a screen where both show.
    for a in sorted(planes, key=lambda p: (p["z"], p["order"])):
        nearer = [b for b in planes if (b["z"], b["order"]) > (a["z"], a["order"])
                  and a["speed_x"] > b["speed_x"] + SPEED_EPS
                  and any(seen_on(a, s) and seen_on(b, s) for s in spots)]
        if nearer:
            names = ", ".join(f"`{b['path']}` ×{b['speed_x']:.2f}" for b in nearer)
            out.append(f"out of speed order: `{a['path']}` (z {a['z']}, ×{a['speed_x']:.2f}) is drawn behind "
                       f"but moves faster than {names}")
    # 2. At least three distinct speeds on every screen.
    for s in spots:
        speeds = sorted({round(p["speed_x"] / SPEED_STEP) * SPEED_STEP for p in planes if seen_on(p, s)})
        if len(speeds) < 3:
            out.append(f"screen `{s}` (hero x {d['screens'][s]['hero'][0]:.0f}): {len(speeds)} distinct speeds "
                       f"({', '.join(f'×{v:.2f}' for v in speeds)})")
    # 3. The floor plane: ×1.0 and its painted top on the collision.
    for s in spots:
        cands = [p for p in d["layers"] if p["kind"] != "camera" and p["z"] <= hero_z
                 and p["screens"][s].get("painted_top_px") is not None]
        if not cands:
            out.append(f"screen `{s}`: no plane has a painted top at the hero's feet (within 80 px; what is "
                       f"there is solid from above, e.g. one baked backdrop)")
            continue
        # The floor art is the widest plane with a top there (props such as a shrine are narrow).
        floor = max(cands, key=lambda p: p["screens"][s].get("visible", 0.0))
        top = floor["screens"][s]["painted_top_px"] / zoom
        speed = floor["speed_x"]
        if speed is None or abs(speed - 1.0) > FLOOR_SPEED_EPS:
            out.append(f"screen `{s}`: the floor plane `{floor['path']}` moves at ×{speed}, not ×1.0")
        if abs(top) > FLOOR_TOP_WORLD_PX:
            where = "above" if top < 0 else "below"
            out.append(f"screen `{s}`: the floor plane `{floor['path']}` is painted {abs(top):.0f} px {where} "
                       f"the collision under the hero")
    # 4. A foreground piece: something drawn in front of the hero.
    if not any(p["kind"] != "camera" and p["z"] > hero_z for p in d["layers"]):
        out.append("no foreground piece (nothing drawn in front of the hero, D774)")
    return out


def num(v) -> str:
    return "—" if v is None else f"{v:.2f}"


def fmt_px(screen_px, zoom: float) -> str:
    return "—" if screen_px is None else f"{screen_px / zoom:+.0f}"


def report(dst: Path) -> None:
    for path in sorted(dst.glob("*/layers.json")):
        d = json.loads(path.read_text())
        info = d["info"]
        gap = d["floor_gap_px"]
        print(f"### {d['room']}\n")
        print(f"Start `{info['arrival']}`, ran {info['run_out_px']:+.0f} px and back {info['run_back_px']:+.0f} px; "
              f"film frames {info['film_frames'][0]}–{info['film_frames'][1]}; enemies frozen {d['frozen_enemies']}; "
              f"hero on the floor {gap['frames_on_floor']} frames, feet–collision gap median {num(gap['median'])} px, "
              f"max {num(gap['max'])} px; the hero's drawn feet vs the collision: "
              + ", ".join(f"{k} {fmt_px(v['hero_sprite_bottom_px'], d['zoom'])}" for k, v in d["screens"].items())
              + " (world px, + below).\n")
        print("| plane | kind | z | speed ×cam | scroll_scale | seen | value | contrast | sat | top at feet (px) |")
        print("|---|---|---|---|---|---|---|---|---|---|")
        for p in sorted(d["layers"], key=lambda p: (p["z"], p["order"])):
            b = best(p["screens"])
            if b.get("coverage", 0.0) < SEEN:
                stats = "— | — | — | —"
            else:
                seen = max(sc.get("visible", 0.0) for sc in p["screens"].values())
                stats = f"{seen:.3f} | {b['value']:.2f} | {b['contrast']:.2f} | {b['saturation']:.2f}"
            tops = [p["screens"][s].get("painted_top_px") for s in p["screens"]]
            tops = ", ".join("—" if t is None else f"{t / d['zoom']:+.0f}" for t in tops)
            ss = p.get("scroll_scale")
            ss = "—" if ss is None else f"{ss[0]:.2f}"
            sp = "—" if p["speed_x"] is None else f"{p['speed_x']:.2f}"
            print(f"| `{p['path']}` | {p['kind']} | {p['z']} | {sp} | {ss} | {stats} | {tops} |")
        v = violations(d)
        print("\nViolations: " + ("none" if not v else "") + "\n")
        for line in v:
            print(f"- {line}")
        print()


def main() -> None:
    if len(sys.argv) >= 4 and sys.argv[1] == "pack":
        pack(Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4:])
    elif len(sys.argv) == 3 and sys.argv[1] == "report":
        report(Path(sys.argv[2]))
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
