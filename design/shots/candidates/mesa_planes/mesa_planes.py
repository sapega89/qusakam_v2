"""Підйом на мезу: пряма лінія ходьби перетинала намальовану купу валунів, переднього плану не було (критики глибини
2026-10-27, знахідка 13). Qwen-Image-Edit-2511 (comfy_sprite.edit) прибирає валуни з фону; пікселі планів — з
оригіналу gen_back.png, у його 16 кольорах.
  python -B design/shots/candidates/mesa_planes/mesa_planes.py gen    — правка моделі (сирий PNG поруч зі скриптом)
  python -B design/shots/candidates/mesa_planes/mesa_planes.py build  — (scipy) плани в SampleProject/Assets/Backgrounds/MesaClimb/
Плани (кімната 864×960, фон ×2.963 від x −421.3, як і був): gen_mesa (небо, скелі, пісок без валунів), gen_boulders
(валуни на власному плані за підлогою), gen_floor (×1.5, кам'яний уступ — смуга Canyon_Terrain, з якої і полиці
підйому; рядок 0 — лінія ходьби y 896). Передній план (D774) — заслін D750 Canyon/gen_rock у правому нижньому куті, у сцені.
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "Scripts/Tools")
import comfy_sprite as cs

D = os.path.dirname(os.path.abspath(__file__))
OUT = "SampleProject/Assets/Backgrounds/MesaClimb/"
SRC = OUT + "gen_back.png"
TERRAIN = "SampleProject/Assets/Backgrounds/Terrain/Canyon_Terrain.png"
K = 3
W, H = 576, 324
BAND = 258  # валуни — нижче цього рядка
LEDGE = (
    1290,
    1728,
    239,
)  # смуга уступу в Canyon_Terrain: стовпці x0..x1, верх піску — рядок 239
FLOOR_ROWS = (
    44  # 44 × 1.5 = 66 px світу: від лінії ходьби 896 до низу кімнати 960 із запасом
)


def raw(name):
    return os.path.join(D, f"mesa_{name}_raw.png")


def gen():
    o = np.asarray(Image.open(SRC).convert("RGBA"))
    big = np.asarray(Image.fromarray(o).resize((W * K, H * K), Image.NEAREST))
    if not os.path.exists(raw("clear_8011")):
        out = cs.edit(
            big,
            "Remove the whole row of dark violet boulders and stones along the bottom edge, including the big dark "
            "boulder. Where they were, continue the pale sandy ground and the foot of the red cliffs down to the "
            "bottom edge, matching the sand around them. Keep everything else exactly as it is, in the same pixel art "
            "style, colours and position.",
            8011,
        )
        Image.fromarray(out.astype(np.uint8)).resize((W * K, H * K), Image.BOX).save(
            raw("clear_8011")
        )
        print("clear_8011", flush=True)
    cs.free()


def down(path):
    a = np.asarray(
        Image.open(path).convert("RGB").resize((W * K, H * K), Image.BOX)
    ).astype(np.float32)
    return a.reshape(H, K, W, K, 3).mean(axis=(1, 3))


def to_palette(rgb, pal):
    d = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1)
    return pal[d.argmin(-1)]


def build():
    from scipy import ndimage

    o = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    pal = np.unique(o[..., :3].reshape(-1, 3), axis=0).astype(np.float32)
    clear = to_palette(down(raw("clear_8011")), pal)
    # валуни — те, чим оригінал нижче BAND відрізняється від правки без них
    m = np.zeros((H, W), bool)
    m[BAND:] = np.abs(o[BAND:, :, :3].astype(int) - clear[BAND:]).sum(-1) > 60
    rgb = o[..., :3].astype(int)
    m &= (rgb[..., 2] >= rgb[..., 0] - 5) | (rgb.sum(-1) < 200)  # валуни фіолетово-сірі й темні; пісок і червоні скелі — теплі
    m = ndimage.binary_opening(m, iterations=1)
    lab, k = ndimage.label(m)
    m = np.isin(lab, 1 + np.nonzero(ndimage.sum(m, lab, range(1, k + 1)) >= 30)[0])
    m = ndimage.binary_fill_holes(m)
    m[-3:] |= m[-4]  # низ кадру — суцільний, як в оригіналі
    mesa = o.copy()
    gone = ndimage.binary_dilation(m, iterations=2)
    mesa[gone, :3] = clear[gone]
    Image.fromarray(mesa).save(OUT + "gen_mesa.png")
    boulders = o.copy()
    boulders[..., 3] = m * 255
    Image.fromarray(boulders).save(OUT + "gen_boulders.png")
    print("boulders px", int(m.sum()), "top row", int(np.argmax(m.any(1))), flush=True)
    # підлога: уступ з Canyon_Terrain (пісок і шари пісковику), дзеркально — 876 px, ширше за кімнату
    t = np.asarray(Image.open(TERRAIN).convert("RGBA"))
    tx0, tx1, ty = LEDGE
    strip = t[ty : ty + FLOOR_ROWS, tx0:tx1].copy()
    Image.fromarray(np.concatenate([strip, strip[:, ::-1]], axis=1)).save(
        OUT + "gen_floor.png"
    )
    print("floor", strip.shape[1] * 2, FLOOR_ROWS, flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build}[sys.argv[1]]()
