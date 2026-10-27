"""Розпис з драконами: підлога — частина одного фону, а розпис читається плиткою (два дракони на кадр; критики
глибини 2026-10-27, знахідки 5 і 12). Камера тут не рухається: глибина — від перекриття й тону. Qwen-Image-Edit-2511
(comfy_sprite.edit) прибирає драконів і людей зі стіни та маскує скелю; пікселі планів — з оригіналу gen_back.png.
  python -B design/shots/candidates/mural_planes/mural_planes.py gen    — правки моделі (сирі PNG поруч зі скриптом)
  python -B design/shots/candidates/mural_planes/mural_planes.py build  — (scipy) плани в SampleProject/Assets/Backgrounds/DragonMural/
Плани: gen_wall (стіна з розписом без драконів і людей), gen_dragon (лівий дракон — розпис один раз, на своєму
місці), gen_frame (скельна стеля й колона посередині, темніші — ближня рамка перед розписом), gen_floor (рядок 0 —
лінія ходьби y 416).
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "Scripts/Tools")
import comfy_sprite as cs

D = os.path.dirname(os.path.abspath(__file__))
OUT = "SampleProject/Assets/Backgrounds/DragonMural/"
SRC = OUT + "gen_back.png"
K = 3
W, H = 576, 324
WALK = 279  # лінія ходьби y 416 світу = рядок шару (416 + 3) / 1.5
DRAGON = (8, 214, 70, 205)  # лівий дракон (x0, x1, y0, y1)
DARK = 0.62  # рамка темніша за розпис: тон × DARK
KEEP = "Keep everything else exactly as it is, in the same pixel art style, colours and position."


def raw(name):
    return os.path.join(D, f"mural_{name}_raw.png")


def gen():
    o = np.asarray(Image.open(SRC).convert("RGBA"))
    big = np.asarray(Image.fromarray(o).resize((W * K, H * K), Image.NEAREST))
    jobs = [
        (
            "wall_8111",
            "Remove all the painted red dragons, the big ones at the left and the right and the two small dragon "
            "heads in the middle, and remove all the small bowing people standing on the floor. Where they were, "
            "continue the faded turquoise and ochre cracked plaster of the mural wall and the desert painted on it. "
            + KEEP,
            8111,
        ),
        (
            "frame_8121",
            "Keep only the dark rock: the dark rock ceiling along the top and the big rock column in the middle with "
            "its two leaning slabs. Replace everything else, the painted mural wall, the dragons, the light shafts, the "
            "people and the floor, with flat magenta (#FF00FF). " + KEEP,
            8121,
        ),
    ]
    for name, text, seed in jobs:
        if os.path.exists(raw(name)):
            continue
        out = cs.edit(big, text, seed)
        Image.fromarray(out.astype(np.uint8)).resize((W * K, H * K), Image.BOX).save(
            raw(name)
        )
        print(name, flush=True)
    cs.free()


def down(path):
    a = np.asarray(
        Image.open(path).convert("RGB").resize((W * K, H * K), Image.BOX)
    ).astype(np.float32)
    return a.reshape(H, K, W, K, 3).mean(axis=(1, 3))


def magenta(rgb):
    return (rgb[..., 0] > 150) & (rgb[..., 2] > 120) & (rgb[..., 1] < 110)


def to_palette(rgb, pal):
    d = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1)
    return pal[d.argmin(-1)]


def build():
    from scipy import ndimage

    o = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    pal = np.unique(o[..., :3].reshape(-1, 3), axis=0).astype(np.float32)
    wall = to_palette(down(raw("wall_8111")), pal)
    # рамка — скеля, яку лишила правка «frame»; найбільші плями (стеля й колона)
    fr = ~magenta(down(raw("frame_8121")))
    fr &= o[..., :3].astype(int).sum(-1) < 420  # лише темна скеля: світловий стовп і люди в ньому — не рамка
    fr[268:] = False  # підлога — свій план
    fr = ndimage.binary_opening(fr, iterations=1)
    lab, k = ndimage.label(fr)
    fr = np.isin(lab, 1 + np.nonzero(ndimage.sum(fr, lab, range(1, k + 1)) >= 400)[0])
    fr = ndimage.binary_fill_holes(fr)
    rgb = o[..., :3].astype(int)
    diff = np.abs(rgb - wall).sum(-1) > 70

    def boxed(boxes):
        m = np.zeros((H, W), bool)
        for x0, x1, y0, y1 in boxes:
            m[y0:y1, x0:x1] = diff[y0:y1, x0:x1]
        return m

    # дракони — червоні й вохристі, і правка «wall» їх прибрала; бірюзова штукатурка й тріщини — ні
    red = boxed([DRAGON, (360, 572, 70, 205), (236, 344, 95, 192)]) & (rgb[..., 0] > rgb[..., 1] + 30) & ~fr
    red = ndimage.binary_closing(red, iterations=1)
    people = boxed([(0, 86, 228, WALK), (262, 322, 228, WALK), (488, 576, 228, WALK)])
    # дракон-реквізит: лівий, з пікселів оригіналу
    dm = red.copy()
    dm[:, DRAGON[1] :] = False
    dm = ndimage.binary_opening(dm, iterations=1)
    lab, k = ndimage.label(dm)
    dm = np.isin(lab, 1 + np.nonzero(ndimage.sum(dm, lab, range(1, k + 1)) >= 25)[0])
    dm = ndimage.binary_fill_holes(dm)
    ys, xs = np.nonzero(dm)
    d = o.copy()
    d[..., 3] = dm * 255
    Image.fromarray(d[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]).save(OUT + "gen_dragon.png")
    print("dragon at", xs.min(), ys.min(), "size", xs.max() - xs.min() + 1, ys.max() - ys.min() + 1, flush=True)
    # стіна: оригінал; де стояли дракони й люди — правка «wall» (штукатурка, домальована моделлю)
    w = o.copy()
    gone = ndimage.binary_dilation(red | dm | people, iterations=2) & ~fr
    w[gone, :3] = wall[gone]
    Image.fromarray(w).save(OUT + "gen_wall.png")
    # рамка: пікселі оригіналу, темніші; над лінією ходьби (нижче — підлога)
    f = o.copy()
    f[..., :3] = (o[..., :3].astype(np.float32) * DARK).astype(np.uint8)
    f[..., 3] = fr * 255
    f[WALK:, :, 3] = 0
    Image.fromarray(f).save(OUT + "gen_frame.png")
    # підлога: оригінал від лінії ходьби до низу кадру, скеля колони в ній — так само темніша; кромка — світла
    floor = o[WALK:].copy()
    fl = ~magenta(down(raw("frame_8121")))[WALK:] & (rgb[WALK:].sum(-1) < 420)
    fl[:, :190] = False
    fl[:, 400:] = False
    floor[fl, :3] = (floor[fl, :3].astype(np.float32) * DARK).astype(np.uint8)
    lip = pal[np.argmax(pal.sum(-1))].astype(np.uint8)
    floor[0, ~fl[0], :3] = lip
    Image.fromarray(floor).save(OUT + "gen_floor.png")
    print("floor rows", len(floor), "frame px", int(fr.sum()), flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build}[sys.argv[1]]()
