"""Брама святилища в печері ящурів (Gate_Shrine, LockedDoor, ключ — Grandfather's Old Key, D698): 4 кандидати.
Sapega: «це треба переробити» — зараз там ґрати лабораторії по пояс, а тіло брами від підлоги до стелі (48×416).

    python -I -B design/shots/candidates/cave_gate/cave_gate.py   → gate_{a,b,c,d}.png (пікселі гри)

Qwen-Image (Apache 2.0) через comfy_backdrop: предмет на зеленому → ключ → рамка предмета → висота 416 / 1.5 = 277
пікселів гри (брама від підлоги до стелі) → палітра печери (gen_back, 16 кольорів, як cave_planes).
"""

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "Scripts", "Tools"))
os.chdir(ROOT)
import comfy_backdrop as cb  # noqa: E402

OUT = "design/shots/candidates/cave_gate"
TALL = 277  # пікселів гри: 416 світу / 1.5
# Перша спроба (широкий кадр 1728×972): присадкуваті брами по пояс і смуга землі на всю ширину. Тепер кадр
# вертикальний, брама — вузька будова від низу до верху кадру, самі двері — біля її основи, на два зрости героя.
FRAME = (768, 1536)
TAIL = (
    "standing alone in the middle of the frame with empty space on both sides, floating with no ground or floor "
    "beneath it, seen straight on as a flat elevation, no perspective, warm light on the top, cool violet shadows in "
    f"the recesses, {cb.CHROMA}"
)
# a і d з TAIL стали на летючий острівець скелі — їхня основа зрізана рівно по нижньому краю кадру
TAIL_CUT = TAIL.replace(
    "floating with no ground or floor beneath it",
    "its base cut off straight and flat along the bottom edge of the frame, no ground and no rocks beneath it",
)
TALL_NARROW = "three times taller than it is wide, filling the frame from the bottom edge to the top edge"
GATES = {
    "a": (
        515,
        f"one single tall narrow pillar of rough orange cave rock, {TALL_NARROW}; at its base a closed arched door "
        "of a heavy pale sandstone slab, a third of the pillar's height, with a big carved relief of a climbing lizard "
        "and a small dark bronze keyhole plate",
        TAIL_CUT,
    ),
    "b": (
        512,
        f"one single tall narrow gateway of carved pale sandstone, {TALL_NARROW}: two carved pillars with lizard "
        "idols and spiral patterns and a high pointed arch on top, closed by a portcullis of thick warm brass bars "
        "filling the whole opening, the top of every bar ends in a small lizard head, a brass lock plate on the middle "
        "band, the flat background visible between the bars",
    ),
    "c": (
        513,
        f"one single tall narrow gate of thick weathered wooden poles lashed together with rope, {TALL_NARROW}: "
        "vertical brown poles side by side with no gaps, crossbars lashed on with rope, two bleached lizard skulls "
        "tied to the poles, a heavy brass padlock at the height of a man's waist",
    ),
    "d": (
        516,
        f"one single tall narrow pillar of rough orange cave rock, {TALL_NARROW}, with a huge round stone seal door "
        "as wide as the pillar set into its lower half: a thick disc of pale carved sandstone with rings of carved "
        "lizard scales, in its centre a carved almond-shaped stone eye with an amber iris and a vertical slit pupil",
        TAIL_CUT,
    ),
}


def cut(name):
    seed, prompt, *tail = GATES[name]
    cb.GW = FRAME[0]  # graph() читає ширину з модуля; кеш розрізняє кадри за підказкою
    layer = dict(seed=seed, rows=FRAME[1] // cb.SCALE, seam="none", prompt=f"{prompt}, {(tail or [TAIL])[0]}")
    img = cb.generate(layer)
    bg = np.median(img[:24].reshape(-1, 3), axis=0)
    a = (np.linalg.norm(img - bg, axis=2) > cb.KEY_DISTANCE).astype(np.float32)
    img[..., 1] = np.minimum(
        img[..., 1], np.maximum(img[..., 0], img[..., 2])
    )  # зелений відсвіт країв
    wide = a.mean(axis=1) > 0.8
    floor = len(a)
    while floor > 0 and wide[floor - 1]:
        floor -= 1
    a[floor:] = 0
    from scipy import ndimage

    labels, n = ndimage.label(a > 0)
    sizes = ndimage.sum(np.ones(labels.shape), labels, range(1, n + 1))
    a *= labels == 1 + int(np.argmax(sizes))  # лише сама брама, без крихт ключа
    ys, xs = np.nonzero(a)
    img, a = (
        img[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
        a[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
    )
    size = (round(img.shape[1] * TALL / img.shape[0]), TALL)
    rgb = np.dstack(
        [
            np.asarray(
                Image.fromarray((img[..., c] * a).astype(np.float32)).resize(
                    size, Image.BOX
                )
            )
            for c in range(3)
        ]
    )
    alpha = np.asarray(Image.fromarray(a).resize(size, Image.BOX))
    rgb = rgb / np.maximum(alpha, 1e-6)[..., None]
    opaque = alpha >= 0.5
    cave = np.asarray(
        Image.open("SampleProject/Assets/Backgrounds/LizardCave/gen_back.png").convert(
            "RGB"
        )
    )
    pal = np.unique(cave.reshape(-1, 3), axis=0).astype(np.float32)
    d = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1)
    q = pal[d.argmin(-1)].astype(np.uint8)
    out = np.dstack([q, opaque.astype(np.uint8) * 255])
    Image.fromarray(out).save(f"{OUT}/gate_{name}.png")
    print("gate", name, out.shape[1], "x", out.shape[0], flush=True)


if __name__ == "__main__":
    for g in sys.argv[1:] or GATES:
        cut(g)
    cb.urllib.request.urlopen(
        cb.urllib.request.Request(
            cb.API + "/free",
            cb.json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )
