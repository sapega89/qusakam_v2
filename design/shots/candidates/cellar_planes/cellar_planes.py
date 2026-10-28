"""Підвал брами: один фон ×1.0 двічі на кімнату (сходи, ліхтар і кажан двічі на екран) розрізати на плани, як B162
у печері ящурів і табір бандитів (критики глибини 2026-10-27, знахідки 1, 6, 12). Qwen-Image-Edit-2511
(comfy_sprite.edit) прибирає й маскує; пікселі планів — з оригіналу gen_back.png, у його 16 кольорах.
  python -B design/shots/candidates/cellar_planes/cellar_planes.py gen    — правки моделі (сирі PNG поруч зі скриптом)
  python -B design/shots/candidates/cellar_planes/cellar_planes.py build  — (scipy) плани в SampleProject/Assets/Backgrounds/Cellar/
  python -B design/shots/candidates/cellar_planes/cellar_planes.py arch   — A8: вхід у підвал (CityGates/CellarArch) у gen_back.png;
    після нього build різав би арку вже порожньою — плани різано до A8
Плани: gen_far (×0.5, глуха цегляна стіна за арками, дзеркально), gen_mid (×0.8, арки, колони, бочки, ящики; отвори
арок прозорі), gen_stairs і gen_lantern (×0.9, по одному на кімнату), gen_floor (×1.0, рядок 0 — лінія ходьби y 416),
gen_column (передній план ×1.3 замість чорної смуги fg_pillar: колона з капітеллю з цього ж фону).
"""

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "Scripts/Tools")
import comfy_sprite as cs

D = os.path.dirname(os.path.abspath(__file__))
OUT = "SampleProject/Assets/Backgrounds/Cellar/"
SRC = OUT + "gen_back.png"
K = 3
W, H = 576, 324
WALK = 279  # лінія ходьби y 416 світу = рядок шару (416 + 3) / 1.5
KEEP = "Keep everything else exactly as it is, in the same pixel art style, colours and position."
# (x0, x1, y0, y1) у пікселях шару
LANTERN = (56, 94, 38, 146)
BAT = (68, 158, 48, 98)
STAIRS = (38, 224, 140, 300)
COLUMN = (
    437,
    491,
)  # права колона: капітель 108–128, стовбур до 250, ніщо її не заступає
LANTERN_BODY = (
    24  # арт px: висячий ліхтар — клас «sack, pot» таблиці світу (24), × план 0.9 → 22
)
LANTERN_DROP = 115  # від стелі (y 0) до низу ліхтаря: «lamp» 128 × план 0.9


def raw(name):
    return os.path.join(D, f"cellar_{name}_raw.png")


def big(img):
    return np.asarray(Image.fromarray(img).resize((W * K, H * K), Image.NEAREST))


def gen():
    o = np.asarray(Image.open(SRC).convert("RGBA"))
    jobs = [
        (
            "clean_7911",
            big(o),
            "Remove the stone stairs at the left, the hanging oil lantern with its chain and the bat. Where they "
            "were, continue the brick wall inside the arch and the stone floor, matching the bricks and stones around "
            "them. " + KEEP,
            7911,
        ),
        (
            "far_7901",
            big(o),
            "Remove the whole front of the cellar: the brick arches, the stone columns, the stairs, the barrels, the "
            "wooden crates, the wine bottles, the lantern, the bat, the cobwebs and the straw nests. Show only the "
            "plain dark brick back wall of the cellar behind them in dim shadow, continued across the whole picture, "
            "and the flat worn stone floor along the bottom, empty, in the same pixel art style and colours.",
            7901,
        ),
    ]
    # сходи й ліхтар — окремі правки їхніх рамок ×6: різниця з «clean» ловила й відсвіт ліхтаря на стіні
    for name, box, what in (
        ("stairs_7931", STAIRS, "the flight of stone stairs with its steps"),
        ("lantern_7931", LANTERN, "the hanging oil lantern and its thin chain"),
    ):
        x0, x1, y0, y1 = box
        c = o[y0:y1, x0:x1]
        jobs.append(
            (
                name,
                np.asarray(Image.fromarray(c).resize((c.shape[1] * 6, c.shape[0] * 6), Image.NEAREST)),
                f"Keep only {what}, exactly as it is. Replace everything else, the brick wall behind it, the warm "
                "light on the wall, the floor, the bat and the barrel, with flat magenta (#FF00FF). Keep the same pixel "
                "art style, colours, size and position.",
                7931,
            )
        )
    for name, img, text, seed in jobs:
        if os.path.exists(raw(name)):
            continue
        out = cs.edit(img, text, seed)
        Image.fromarray(out.astype(np.uint8)).resize((img.shape[1], img.shape[0]), Image.BOX).save(raw(name))
        print(name, flush=True)
    # маска отворів — на картинці без сходів і ліхтаря: інакше сходи лишились би в арці
    if not os.path.exists(raw("holes_7921")):
        clean = np.asarray(Image.open(raw("clean_7911")).convert("RGBA"))
        out = cs.edit(
            clean,
            "Replace the dark back wall seen through the arches with flat magenta (#FF00FF): the empty space inside "
            "each arch, behind the columns, the barrels and the crates. Keep the brick arches, the stone columns, the "
            "brick wall around and above the arches, the barrels, the wooden crates with the wine bottles, the "
            "cobwebs, the straw nests and the stone floor. " + KEEP,
            7921,
        )
        Image.fromarray(out.astype(np.uint8)).resize((W * K, H * K), Image.BOX).save(
            raw("holes_7921")
        )
        print("holes_7921", flush=True)
    cs.free()


def down(path):
    """Сира правка → пікселі шару: середнє блоку K×K."""
    a = np.asarray(
        Image.open(path).convert("RGB").resize((W * K, H * K), Image.BOX)
    ).astype(np.float32)
    return a.reshape(H, K, W, K, 3).mean(axis=(1, 3))


def magenta(rgb):
    return (rgb[..., 0] > 150) & (rgb[..., 2] > 120) & (rgb[..., 1] < 110)


def to_palette(rgb, pal):
    d = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1)
    return pal[d.argmin(-1)]


def box_mask(o, clean, box, thr=60, min_size=40):
    """Предмет — те, чим оригінал відрізняється від правки «clean» (без нього) у рамці box."""
    from scipy import ndimage

    x0, x1, y0, y1 = box
    m = np.zeros((H, W), bool)
    m[y0:y1, x0:x1] = (
        np.abs(o[y0:y1, x0:x1, :3].astype(int) - clean[y0:y1, x0:x1]).sum(-1) > thr
    )
    m = ndimage.binary_opening(m, iterations=1)
    lab, k = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, k + 1))
    m = np.isin(lab, 1 + np.nonzero(sizes >= min_size)[0])
    return ndimage.binary_fill_holes(m)


def sprite(o, m):
    ys, xs = np.nonzero(m)
    c = o.copy()
    c[..., 3] = m * 255
    return c[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1], xs.min(), ys.min()


def build():
    from scipy import ndimage

    o = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    pal = np.unique(o[..., :3].reshape(-1, 3), axis=0).astype(np.float32)
    clean = to_palette(down(raw("clean_7911")), pal)
    far = to_palette(down(raw("far_7901")), pal).astype(np.uint8)
    # далечінь — над лінією ходьби (нижче її закриває підлога), дзеркально двічі — безшовна смуга 1152 px
    Image.fromarray(np.concatenate([far, far[:, ::-1]], axis=1)).save(
        OUT + "gen_far.png"
    )
    # підлога: порожня підлога правки «far» від лінії ходьби до низу кадру, дзеркально; кромка — найсвітліший камінь
    floor = np.concatenate([far[WALK:], far[WALK:, ::-1]], axis=1)
    floor.astype(int)
    lip = pal[np.argmax(pal.sum(-1) * (pal[:, 0] > pal[:, 2]))].astype(
        np.uint8
    )  # теплий світлий камінь
    floor[0] = lip
    floor[1] = (floor[1].astype(int) * 0.7).astype(np.uint8)
    Image.fromarray(floor).save(OUT + "gen_floor.png")
    print("floor rows", len(floor), "lip", lip, flush=True)
    # реквізит: сходи й ліхтар — пікселі їхніх правок ×6 (без пурпуру) у кольорах оригіналу
    def prop(name, box, k=6):
        from scipy import ndimage

        x0, x1, y0, y1 = box
        w, h = x1 - x0, y1 - y0
        a = np.asarray(Image.open(raw(name)).convert("RGB").resize((w * k, h * k), Image.BOX)).astype(np.float32)
        a = a.reshape(h, k, w, k, 3).mean(axis=(1, 3))
        m = ~magenta(a)
        m = ndimage.binary_opening(m, iterations=1)
        lab, n = ndimage.label(m)
        m = lab == 1 + ndimage.sum(m, lab, range(1, n + 1)).argmax()
        c = np.zeros((h, w, 4), np.uint8)
        c[..., :3] = to_palette(a, pal)
        c[..., 3] = m * 255
        full = np.zeros((H, W), bool)
        full[y0:y1, x0:x1] = m
        return c, full

    s, stairs = prop("stairs_7931", STAIRS)
    s[:15, 95:145, 3] = 0  # шматок колони арки над верхньою сходинкою
    stairs[STAIRS[2] : STAIRS[2] + 15, STAIRS[0] + 95 : STAIRS[0] + 145] = False
    s, sx, sy = sprite(s, s[..., 3] > 0)
    Image.fromarray(s).save(OUT + "gen_stairs.png")
    print("stairs at", STAIRS[0] + sx, STAIRS[2] + sy, "size", s.shape[1], s.shape[0], flush=True)
    l, lantern = prop("lantern_7931", LANTERN)
    # тіло ліхтаря — найбільша пляма нижче ланцюга (ланцюг — рядки ширини ≤ 3): масштаб до LANTERN_BODY, ланцюг — заново
    widths = (l[..., 3] > 0).sum(1)
    top = int(np.argmax(widths > 4))
    body, _, _ = sprite(l[top:], l[top:, :, 3] > 0)
    bw = max(1, round(body.shape[1] * LANTERN_BODY / body.shape[0]))
    small = np.asarray(Image.fromarray(body).resize((bw, LANTERN_BODY), Image.BOX)).copy()
    small[..., 3] = np.where(small[..., 3] > 127, 255, 0)
    small[..., :3] = to_palette(small[..., :3].astype(np.float32), pal)
    chain = body[body[..., 3] > 0][:, :3]  # ланцюг — найтемнішим кольором ліхтаря (тонкий ланцюг правки зняло відкриття)
    lamp = np.zeros((LANTERN_DROP, bw, 4), np.uint8)
    lamp[-LANTERN_BODY:] = small
    lamp[: LANTERN_DROP - LANTERN_BODY, bw // 2, :3] = chain[np.argmin(chain.astype(int).sum(-1))]
    lamp[: LANTERN_DROP - LANTERN_BODY, bw // 2, 3] = 255
    Image.fromarray(lamp).save(OUT + "gen_lantern.png")
    print("lantern body", body.shape[1], body.shape[0], "->", bw, LANTERN_BODY, "drop", LANTERN_DROP, flush=True)
    # середній план: оригінал без сходів, ліхтаря й кажана (правка «clean»), отвори арок прозорі
    mid = o.copy()
    bat = np.zeros((H, W), bool)
    bat[BAT[2] : BAT[3], BAT[0] : BAT[1]] = True
    gone = ndimage.binary_dilation(stairs | lantern, iterations=3) | bat
    mid[gone, :3] = clean[gone]
    hole = magenta(down(raw("holes_7921")))
    hole = ndimage.binary_opening(hole, iterations=1)
    lab, k = ndimage.label(hole)
    hole = np.isin(
        lab, 1 + np.nonzero(ndimage.sum(hole, lab, range(1, k + 1)) >= 80)[0]
    )
    hole[WALK - 6 :] = False  # підлога за аркою лишається намальованою
    mid[hole, 3] = 0
    Image.fromarray(mid).save(OUT + "gen_mid.png")
    print("mid holes px", int(hole.sum()), flush=True)
    # колона переднього плану: капітель і стовбур правої колони; стовбур повторено до 260 рядків (×2 = 520 px світу)
    x0, x1 = COLUMN
    cap, shaft = o[104:130, x0:x1], o[130:246, x0:x1]
    col = np.concatenate([shaft[-12:], cap] + [shaft] * 3)[:260].copy()
    col[..., 3] = np.where(
        col[..., :3].astype(int).sum(-1) > 90, 255, col[..., 3]
    )  # темні шви — теж колона
    Image.fromarray(col).save(OUT + "gen_column.png")
    print("column", col.shape[1], col.shape[0], flush=True)


# A8 (2026-10-28, «поправити» без примітки): CityGates/CellarArch показує шматок gen_back.png (region 300, 40, 150 × 170)
# як вхід у підвал — а в тій арці висіли павутина й гніздо кажанів і стояли пляшки на ящику, зрізаному низом кадру:
# не вхід, а вирізка з комори. Тепер отвір арки порожній і темний, знизу — тепле світло ліхтаря зі сходів униз.
ARCH = (385, 108, 55, 61)  # центр отвору x, рядок п'ят арки, пів ширини отвору, висота склепіння над п'ятами
GLOW = [(54, 33, 78), (85, 39, 57), (145, 75, 60), (209, 108, 86)]  # кольори фону, від краю світла до серця
DARK = (26, 11, 42)
WEB = [(180, 171, 201), (154, 132, 166)]  # павутина
NEST = [(209, 108, 86), (223, 146, 111), (231, 166, 136), (145, 75, 60)]  # гніздо (праворуч; ліворуч цим світиться цегла)


def arch():
    from scipy import ndimage

    o = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    cx, y0, a, b = ARCH
    ys, xs = np.mgrid[:H, :W]
    u = (xs - cx) / a
    vault = (np.abs(u) < 1) & (ys >= y0 - b * np.sqrt(np.clip(1 - u**2, 0, 1))) & (ys < 215)
    # кінці павутини й гнізда, що лягли на цеглу по краю отвору, — кольором цегли навколо
    rgb = o[..., :3]
    stray = ndimage.binary_dilation(vault, iterations=8) & ~vault
    stray &= np.isin(rgb, WEB).all(-1) | (np.isin(rgb, NEST).all(-1) & (xs > cx))
    for y, x in zip(*np.nonzero(stray)):
        win = rgb[y - 3 : y + 4, x - 3 : x + 4].reshape(-1, 3)
        ok = win[~stray[y - 3 : y + 4, x - 3 : x + 4].reshape(-1) & ~vault[y - 3 : y + 4, x - 3 : x + 4].reshape(-1)]
        cols, n = np.unique(ok, axis=0, return_counts=True)
        rgb[y, x] = cols[n.argmax()]
    rgb[vault] = DARK
    for i, c in enumerate(GLOW):  # світло знизу, з-під підлоги, смугами, як ліхтар у фоні; видно лише верхні смуги —
        r = 1 - i / len(GLOW)  # нижче рядка 173 арку закриває смуга підлоги кімнати
        rgb[vault & (((xs - cx) / (a * r)) ** 2 + ((ys - 214) / (90 * r)) ** 2 < 1)] = c
    Image.fromarray(o).save(SRC)
    print("arch cleared", flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build, "arch": arch}[sys.argv[1]]()
