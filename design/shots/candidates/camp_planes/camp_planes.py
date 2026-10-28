"""Табір бандитів: фон розрізати на плани (як B162 у печері ящурів; критики глибини дали 1/5 — небо, намети й бочки
їдуть разом, герой бігає по намальованих бочках і мішках). Qwen-Image-Edit-2511 (comfy_sprite.edit) робить маски й
домальовує пісок за бочкою й мішками; пікселі планів — з оригіналу gen_back.png, у його 16 кольорах.
  python -B design/shots/candidates/camp_planes/camp_planes.py gen    — правки моделі (сирі PNG поруч зі скриптом)
  python -B design/shots/candidates/camp_planes/camp_planes.py build  — (scipy) плани в SampleProject/Assets/Backgrounds/BanditCamp/
  python -B design/shots/candidates/camp_planes/camp_planes.py fix    — (scipy) A8: латки на готових gen_mid і gen_floor
Плани: gen_far (×0.4, небо й дюни, дзеркально), gen_mid (×0.8, частокіл, намети, ящики, котли, пісок до лінії ходьби),
gen_sacks (×0.9, мішки й бочка — окремий реквізит за героєм), gen_floor (×1.0, рядок 0 — лінія ходьби y 416).
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "Scripts/Tools")
import comfy_sprite as cs

D = os.path.dirname(os.path.abspath(__file__))
OUT = "SampleProject/Assets/Backgrounds/BanditCamp/"
SRC = OUT + "gen_back.png"
K = 3
W, H = 576, 324
# лінія ходьби y 416 світу = рядок шару (416 + 3) / 1.5
WALK = 279
KEEP = "Keep everything else exactly as it is, in the same painterly style, colours and position."
# мішок, бочка, мішок справа внизу — стоять на лінії ходьби (x0, x1, y0, y1)
PROPS = (380, 576, 215, 324)
# мішки: тінь на піску ліворуч, хвіст тіні під правим мішком і пісок під усією групою (x0, x1, y0, y1)
CLIP = [(0, 397, 283, 999), (525, 999, 299, 999), (0, 999, 317, 999)]
# гребінь дюни над великим наметом не взяла жодна правка: у стовпцях CREST небо й дюна — все вище першого пікселя табору
CREST = (320, 520, 30, 120)
# кромка підлоги — кольори палітри оригіналу: найсвітліший пісок і фіолетова тінь піску
LIP, SHADOW = (253, 195, 162), (148, 98, 144)


def raw(name):
    return os.path.join(D, f"camp_{name}_raw.png")


def gen():
    o = np.asarray(Image.open(SRC).convert("RGBA"))
    big = np.asarray(Image.fromarray(o).resize((W * K, H * K), Image.NEAREST))
    jobs = [
        (
            "far_7801",
            "Remove the whole bandit camp and the sand ground in front of it: the tents, the palisade of "
            "sharpened stakes, the weapon racks with the swords and spears, the crates, the barrels, the sacks, the cooking "
            "pots, the campfire and the banner pole. Show only what lies far behind the camp: the pink and violet sky with "
            "its long clouds and the big smooth sand dunes in the distance, continued across the whole picture down to the "
            "bottom edge where the camp hid them, in the same painterly style and colours.",
            7801,
        ),
        (
            "middle_7801",
            "Replace the sky with its clouds and the big distant sand dune behind the tents with flat "
            "magenta (#FF00FF). Keep the palisade of sharpened stakes, the weapon racks, the tents, the banner pole, the "
            "crates, the barrels, the sacks, the cooking pots, the campfire and all the sand ground they stand on. "
            + KEEP,
            7801,
        ),
        # друга маска: перша лишила гребінь дюни над наметом і світлі клапті обрію між кілками
        (
            "middle_7802",
            "Replace everything behind the camp with flat magenta (#FF00FF): the whole sky with its clouds, "
            "the whole big sand dune behind the tents including its top crest above the big striped tent, and the pale "
            "pink glowing horizon seen between the stakes of the palisade. Keep the palisade of sharpened stakes, the "
            "weapon racks, the tents with their poles, the banner pole and its flag, the crates, the barrels, the sacks, "
            "the cooking pots, the campfire and all the sand ground they stand on. "
            + KEEP,
            7802,
        ),
        (
            "wall_7811",
            "Remove the two big sacks and the wooden barrel at the bottom right corner. Where they stood, "
            "continue the sand ground and its violet shadow, matching the sand around them. "
            + KEEP,
            7811,
        ),
    ]
    for name, text, seed in jobs:
        if os.path.exists(raw(name)):
            continue
        out = cs.edit(big, text, seed)
        Image.fromarray(out.astype(np.uint8)).resize(
            (big.shape[1], big.shape[0]), Image.BOX
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


def build():
    from scipy import ndimage

    o = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    pal = np.unique(o[..., :3].reshape(-1, 3), axis=0).astype(np.float32)
    # далечінь: правка «far» (небо, хмари, дюни), дзеркально двічі — безшовна смуга 1152 px
    far = to_palette(down(raw("far_7801"), K, (W, H)), pal).astype(np.uint8)
    Image.fromarray(np.concatenate([far, far[:, ::-1]], axis=1)).save(OUT + "gen_far.png")
    # мішки й бочка — те, чим оригінал відрізняється від правки «wall» (пісок без них) у кутку PROPS
    wall = to_palette(down(raw("wall_7811"), K, (W, H)), pal)
    x0, x1, y0, y1 = PROPS
    m = np.zeros((H, W), bool)
    m[y0:y1, x0:x1] = np.abs(o[y0:y1, x0:x1, :3].astype(int) - wall[y0:y1, x0:x1]).sum(-1) > 60
    m = ndimage.binary_opening(m, iterations=1)
    lab, k = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, k + 1))
    m = np.isin(lab, 1 + np.nonzero(sizes >= 150)[0])
    m &= ~np.isin(o[..., :3], [LIP, (241, 168, 151)]).all(-1)  # світлий пісок навколо — не мішки
    ys, xs = np.mgrid[:H, :W]
    for cx0, cx1, cy0, cy1 in CLIP:
        m &= ~((xs >= cx0) & (xs < cx1) & (ys >= cy0) & (ys < cy1))
    lab, k = ndimage.label(m)
    m = ndimage.binary_fill_holes(lab == 1 + ndimage.sum(m, lab, range(1, k + 1)).argmax())
    ys, xs = np.nonzero(m)
    props = o.copy()
    props[..., 3] = m * 255
    Image.fromarray(props[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]).save(OUT + "gen_sacks.png")
    print("sacks at", xs.min(), ys.min(), "size", xs.max() - xs.min() + 1, ys.max() - ys.min() + 1, flush=True)
    mid = o.copy()
    gone = ndimage.binary_dilation(m, iterations=2)
    mid[gone, :3] = wall[gone]
    # небо — кольори верхніх рядків, зв'язані з верхнім краєм; дюна й світлий обрій — пурпур правки «middle»
    rgb = o[..., :3]
    top_cols = np.unique(rgb[:12].reshape(-1, 3), axis=0)
    cand = (rgb[:, :, None, :] == top_cols[None, None]).all(-1).any(-1)
    lab, k = ndimage.label(cand)
    sky = np.isin(lab, np.unique(lab[0])[np.unique(lab[0]) > 0])
    hole = magenta(down(raw("middle_7801"), K, (W, H))) | sky
    # друга маска — лише її шматки, що торкаються першої: окремі цятки вона пробила в наметі й частоколі
    lab, k = ndimage.label(magenta(down(raw("middle_7802"), K, (W, H))))
    hole |= np.isin(lab, np.unique(lab[ndimage.binary_dilation(hole) & (lab > 0)]))
    camp = rgb.astype(int).sum(-1) < 430
    cx0, cx1, cy0, cy1 = CREST
    for x in range(cx0, cx1):
        col = camp[cy0:cy1, x]
        hole[cy0 : cy0 + (col.argmax() if col.any() else cy1 - cy0), x] = True
    hole = ndimage.binary_opening(hole, iterations=1)
    lab, k = ndimage.label(hole)  # цятки в наметах і на ящиках — геть, лишаються небо й великі просвіти
    hole = np.isin(lab, 1 + np.nonzero(ndimage.sum(hole, lab, range(1, k + 1)) >= 80)[0])
    # світлі клапті рожевого обрію на вістрях кілків і жердин: кольори обрію за 4 px від просвіту
    pink = np.isin(rgb, [(249, 205, 224), (230, 165, 221)]).all(-1)
    pink[140:] = False  # нижче — дим над котлами, він лишається цілим
    hole |= pink & ndimage.binary_dilation(hole, iterations=4)
    # жердини, держаки списів, обриси — темні кольори, яких у небі й дюнах немає: маски моделі їх з'їли, вертаємо
    hole &= rgb.astype(int).sum(-1) >= 300
    hole[190:] = False  # пісок перед наметами лишається (обрій не нижчий за рядок 180)
    mid[hole, 3] = 0
    Image.fromarray(mid).save(OUT + "gen_mid.png")
    # підлога: власний пісок табору від лінії ходьби до низу кадру (45 рядків, безшовний, як оригінал) — у ньому
    # нічого не стоїть; згенерована смуга була рожевою стрічкою з дзеркальними ромбами. Кромка намальована:
    # рядок 0 — найсвітліший пісок, рядок 1 — тінь, щоб зсув планів на лінії ходьби читався як край, а не розрив
    floor = mid[WALK:].copy()
    floor[..., 3] = 255
    floor[0, :, :3] = LIP
    floor[1, :, :3] = SHADOW
    Image.fromarray(floor).save(OUT + "gen_floor.png")
    print("floor rows", len(floor), flush=True)


# A8 (2026-10-28, «поправити» без примітки). Підлога: зрізаний посередині камінь і кущик на лінії ходьби, пряма
# вертикальна межа на x 397 (край латки з правки «wall» під мішками, CLIP) і половина смуги — суцільна фіолетова тінь
# мішків; цю смугу повторюють сім кімнат пустелі (build_world_rooms «desert»). Тепер — пісок «згори під кутом» із
# текстури землі (paint_terrain sand_floor, Qwen-Image), у кольорах табору: світлий пісок угорі, плями фіолетової тіні,
# що густішають до ближнього краю, камінці; безшовна (2 періоди текстури, плями — цілі частоти на ширину).
# Mid: рожеві клапті обрію, що лишились на вістрях частоколу й хмаркою на його правому кінці, — прозорі.
RAMP = [(87, 51, 84), (111, 72, 108), (148, 98, 144), (228, 140, 118), (241, 168, 151), (253, 195, 162)]  # темне → світле
HORIZON = [(249, 205, 224), (230, 165, 221), (253, 195, 162), (241, 168, 151)]  # кольори рожевого обрію
SKY_SCRAPS = [(140, 192, 110, 180), (0, 70, 118, 142)]  # x0, x1, y0, y1: хмарка за частоколом і клапті на вістрях


def fix():
    from scipy import ndimage
    from PIL import ImageFilter

    import paint_terrain as pt

    mid = np.asarray(Image.open(OUT + "gen_mid.png").convert("RGBA")).copy()
    horizon = np.isin(mid[..., :3], HORIZON).all(-1) & (mid[..., 3] > 0)
    box = np.zeros(horizon.shape, bool)
    for x0, x1, y0, y1 in SKY_SCRAPS:
        box[y0:y1, x0:x1] = True
    lab, _ = ndimage.label(horizon & box)  # лише клапті, що торкаються неба
    sky = mid[..., 3] == 0
    mid[np.isin(lab, np.unique(lab[ndimage.binary_dilation(sky) & (lab > 0)])), 3] = 0
    Image.fromarray(mid).save(OUT + "gen_mid.png")

    tex, _ = pt.material("sand_floor")
    lum = tex @ np.array([0.3, 0.55, 0.15], np.float32)
    blur = np.asarray(Image.fromarray(lum.astype(np.uint8)).filter(ImageFilter.GaussianBlur(pt.FLOOR_BLOB)), np.float32)
    detail = (lum - blur) / (lum - blur).std()  # лише дрібне: камінці, брижі
    n = 45 - 2
    rows = [int((0.1 + 0.8 * i / (n - 1)) * (len(tex) - 1)) for i in range(n)]  # угорі дальнє, внизу ближнє
    d = np.tile(detail[rows], (1, W // tex.shape[1]))
    t = np.arange(W) / W * 2 * np.pi
    patch = sum(np.sin(t * f + p) / f for f, p in ((2, 0.4), (3, 2.2), (5, 4.1), (9, 1.7)))
    patch = (patch - patch.min()) / np.ptp(patch)
    depth = np.arange(n)[:, None] / (n - 1)
    v = 4.4 - 1.0 * depth - 2.6 * patch[None, :] * (0.4 + 0.6 * depth) + 0.6 * d
    floor = np.full((45, W, 4), 255, np.uint8)
    floor[0, :, :3] = LIP
    floor[1, :, :3] = SHADOW
    floor[2:, :, :3] = np.array(RAMP, np.uint8)[np.clip(np.round(v), 0, len(RAMP) - 1).astype(int)]
    Image.fromarray(floor).save(OUT + "gen_floor.png")
    print("fixed gen_mid, gen_floor", flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build, "fix": fix}[sys.argv[1]]()
