"""Печера ящурів: фон розрізати на плани (B162; Sapega: «передній, середній і задній — їх треба порізати»).
Qwen-Image-Edit-2511 (comfy_sprite.edit) робить маски й домальовує стіну за святилищами; пікселі планів — з
оригіналу gen_back.png, щоб піксель гри лишився той самий.
  python -I design/shots/candidates/cave_planes/cave_planes.py gen    — правки моделі (сирі PNG поруч зі скриптом)
  python design/shots/candidates/cave_planes/cave_planes.py build     — (scipy) плани в SampleProject/Assets/Backgrounds/LizardCave/
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "Scripts/Tools")
import comfy_sprite as cs

D = os.path.dirname(os.path.abspath(__file__))
OUT = "SampleProject/Assets/Backgrounds/LizardCave/"
SRC = OUT + "gen_back.png"
K = 3
W, H = 576, 324
KEEP = "Keep everything else exactly as it is, in the same pixel art style, colours and position."
# Святилища в пікселях шару: (x0, x1, y0, y1); x по колу — праве святилище стоїть на шві копій.
SHRINES = {"a": (228, 348, 100, 282), "b": (488, 676, 96, 282)}
SHRINE_K = 6
# Підлога, яку обидві правки лишили під святилищем (і хвіст, який модель домалювала «a»): (x0, x1, y0, y1)
CLIP = {"a": [(332, 999, 230, 999), (0, 293, 263, 999), (0, 999, 273, 999)], "b": []}


def orig():
    o = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    # напис «sham mamil» на табличці правого святилища (модель написала текст): літери — кольором таблички
    xs = np.r_[558:619] % W
    band = o[134:143][:, xs]
    rgb = band[..., :3].reshape(-1, 3)
    cols, n = np.unique(rgb, axis=0, return_counts=True)
    band[band[..., :3].astype(int).sum(-1) < 480] = (*cols[n.argmax()], 255)
    o[134:143][:, xs] = band
    return o


def crop(img, box):
    x0, x1, y0, y1 = box
    return img[y0:y1][:, np.r_[x0:x1] % W]


def raw(name):
    return os.path.join(D, f"cave_{name}_raw.png")


def gen():
    o = orig()
    big = np.asarray(Image.fromarray(o).resize((W * K, H * K), Image.NEAREST))
    wall = (
        "Remove the three carved stone shrines with the seated lizard idols, their clay offering bowls, "
        "the patterned rugs and the long lizard tail. Where they stood, continue the orange sandstone cave wall and the "
        "stone floor in front of it, matching the rock around them. " + KEEP
    )
    jobs = [
        # перша спроба (HANDOFF §3): «back» — далечінь; з «middle» — лише пурпур отвору, з «front» — маска святилищ
        ("back_7701", big, "Remove the whole cave: the walls, the tunnel, the shrines, the floor, the rocks and the "
         "ceiling. Show only what lies far behind it: the bright sky, the old stone bridge high across the canyon and the "
         "distant canyon cliffs, continued across the whole picture where the cave hid them, in the same pixel art style "
         "and colours.", 7701),
        ("middle_7701", big, "Remove the nearest plane and the far view: the stone floor and the dark rocks at the "
         "bottom, the dark rock ceiling at the top, and the sky, the stone bridge and the distant canyon seen through the "
         "opening. Replace them with flat magenta (#FF00FF). Keep the orange cave walls, the dark tunnel and the three "
         "lizard idol shrines with their bowls and rugs. " + KEEP, 7701),
        ("front_7701", big, "Keep only the nearest plane: the flat stone cave floor along the bottom, the dark rocks in "
         "the foreground at the very bottom and the dark rock ceiling at the very top. Replace everything else (the cave "
         "walls, the tunnel, the three lizard idol shrines, the sky, the stone bridge and the distant canyon) with flat "
         "magenta (#FF00FF). " + KEEP, 7701),
        ("wall_7711", big, wall, 7711),
        # шов копій — посередині картинки: стіна за святилищем «b» домальована одним шматком
        ("wall_roll_7712", np.roll(big, W * K // 2, axis=1), wall, 7712),
    ]
    for n, box in SHRINES.items():
        c = crop(o, box)
        jobs.append(
            (
                f"shrine_{n}_7721",
                np.asarray(
                    Image.fromarray(c).resize(
                        (c.shape[1] * SHRINE_K, c.shape[0] * SHRINE_K), Image.NEAREST
                    )
                ),
                "Keep only the carved stone shrine with the seated lizard idol, the clay offering bowls, the patterned rug "
                "and the lizard's long tail, exactly as they are. Replace everything else, the orange rock wall behind the "
                "shrine, the light rays and the floor under it, with flat magenta (#FF00FF). Keep the same pixel art style, "
                "colours, size and position.",
                7721,
            )
        )
    for name, img, text, seed in jobs:
        if os.path.exists(raw(name)):
            continue
        out = cs.edit(img, text, seed)
        Image.fromarray(out.astype(np.uint8)).resize(
            (img.shape[1], img.shape[0]), Image.BOX
        ).save(raw(name))
        print(name, flush=True)
    cs.free()


def down(path, k, size):
    """Сира правка → пікселі шару: середнє блоку k×k."""
    h, w = size[1] * k, size[0] * k
    a = np.asarray(Image.open(path).convert("RGB").resize((w, h), Image.BOX)).astype(
        np.float32
    )
    return a.reshape(size[1], k, size[0], k, 3).mean(axis=(1, 3))


def magenta(rgb):
    return (rgb[..., 0] > 150) & (rgb[..., 2] > 120) & (rgb[..., 1] < 110)


def to_palette(rgb, pal):
    d = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1)
    return pal[d.argmin(-1)]


def shrine_mask(n, o):
    """Святилище — те, що лишили на пурпурі обидві правки: «front» (не вигадала хвіст у «a», але лишила скелю біля
    «b») і власна правка святилища (навпаки)."""
    from scipy import ndimage

    box = SHRINES[n]
    c = crop(o, box)
    e = down(raw(f"shrine_{n}_7721"), SHRINE_K, (c.shape[1], c.shape[0]))
    f = crop(down(raw("front_7701"), K, (W, H)), box)
    m = ~magenta(e) & ~magenta(f)
    m = ndimage.binary_opening(m, iterations=1)
    lab, k = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, k + 1))
    m = np.isin(lab, 1 + np.nonzero(sizes >= 40)[0])
    m = ndimage.binary_fill_holes(m)
    ys, xs = np.mgrid[box[2] : box[3], box[0] : box[1]]
    for x0, x1, y0, y1 in CLIP[n]:
        m &= ~((xs >= x0) & (xs < x1) & (ys >= y0) & (ys < y1))
    return m


def build():
    from scipy import ndimage

    o = orig()
    pal = np.unique(o[..., :3].reshape(-1, 3), axis=0).astype(np.float32)
    # святилища — окремі спрайти з пікселів оригіналу
    # стіна з правки моделі, де стояли святилища: «a» — з wall_7711, «b» (на шві копій) — з wall_roll_7712, зсунутої назад
    walls = {
        "a": to_palette(down(raw("wall_7711"), K, (W, H)), pal),
        "b": np.roll(to_palette(down(raw("wall_roll_7712"), K, (W, H)), pal), -W // 2, axis=1),
    }
    mid = o.copy()
    for n, (x0, x1, y0, y1) in SHRINES.items():
        m = shrine_mask(n, o)
        c = crop(o, SHRINES[n]).copy()
        c[..., 3] = m * 255
        ys, xs = np.nonzero(m)
        Image.fromarray(c[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]).save(
            OUT + f"gen_shrine_{n}.png"
        )
        print(
            n,
            "at",
            (x0 + xs.min()) % W,
            y0 + ys.min(),
            "size",
            xs.max() - xs.min() + 1,
            ys.max() - ys.min() + 1,
        )
        gone = np.zeros((H, W), bool)
        gone[np.ix_(np.r_[y0:y1], np.r_[x0:x1] % W)] = ndimage.binary_dilation(m, iterations=6)
        mid[gone, :3] = walls[n][gone]
    # отвір у далечінь (пурпур правки «middle») і небо — прозорі
    rgb = o[..., :3].astype(int)
    sky = (rgb[..., 2] > 200) & (rgb[..., 2] > rgb[..., 0] + 25)
    hole = magenta(down(raw("middle_7701"), K, (W, H))) | sky
    hole = ndimage.binary_opening(hole, iterations=1)
    hole[100:, :260] = False  # світло в кінці тунелю лишається намальованим: це вихід з печери (ExitDoor, D729)
    mid[hole, 3] = 0
    Image.fromarray(mid).save(OUT + "gen_wall.png")
    # далечінь: правка «back», дзеркально двічі — безшовна смуга 1152 px
    far = to_palette(down(raw("back_7701"), K, (W, H)), pal).astype(np.uint8)
    far = np.concatenate([far, far[:, ::-1]], axis=1)
    Image.fromarray(far).save(OUT + "gen_far.png")
    # підлога: смуга comfy_backdrop LizardCave/gen_floor (56 рядків) — кожен стовпець піднято так, щоб світла кромка
    # плит стала рядком 0 (лінія ходьби, рівно); низ добудовано дзеркалом до 49 рядків (73 px світу — до низу кадру)
    f = np.asarray(Image.open(OUT + "gen_floor.png").convert("RGB")).astype(int)
    light = (f[..., 0] > 190) & (f.sum(-1) > 420)
    top = np.argmax(light, axis=0)
    n = f.shape[0] - top.max()
    strip = np.stack([f[t : t + n, x] for x, t in enumerate(top)], axis=1)
    strip = np.concatenate([strip, strip[::-1][: 49 - n]])
    strip = to_palette(strip.astype(np.float32), pal).astype(np.uint8)
    Image.fromarray(strip).save(OUT + "gen_floor.png")
    print("floor rows", len(strip), "edge rows", np.bincount(top), flush=True)
    print("built", flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build}[sys.argv[1]]()
