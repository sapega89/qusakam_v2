"""M6b-1: фони печери під мостом (підземелля, 1×3 клітинки, 576×960 арту = 864×1440 світу) і горища діда (інтер'єр,
один екран, 576×324 арту). Обидві кімнати — один екран завширшки: камера x стоїть, паралакс лише по y (печера).
  python -B design/shots/candidates/m6b1/m6b1.py gen    — ComfyUI (сирі PNG поруч зі скриптом; є — не кличе модель)
  python -B design/shots/candidates/m6b1/m6b1.py build  — плани в SampleProject/Assets/Backgrounds/{BridgeCave,GrandfatherAttic}/
  python -B design/shots/candidates/m6b1/m6b1.py sheet  — design/shots/m6b1_cave_attic.png

Печера: герой спускається з мосту крізь гирло в стелі (зліва вгорі) на верхній уступ, падає з його східного краю на
середній уступ, з його західного краю — на дно, і йде далі вниз крізь діру в дні (кімната «вихід з печери» під нею).
Обидва падіння по 320 арту (480 світу) — вгору не вистрибнути («вперше — лише вниз»); наприкінці гри на них опускаються
дві мотузяні драбини (окремий реквізит). Стіна — img2img по намальованій напрямній: непрозора рівно під контуром нижче.
Горище: над домом діда (ElderHouse), лаз у підлозі з драбиною; його речі — молитовний куток зі статуеткою Діви і
записками (journal_stories: grandfather_notes), скриня, килими, сушені трави.
Одиниці — пікселі арту (світ = ×1.5), початок — лівий верхній кут кімнати.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, "Scripts/Tools")
import comfy_backdrop as cb

D = os.path.dirname(os.path.abspath(__file__))
B = "SampleProject/Assets/Backgrounds/"
CAVE, ATTIC = B + "BridgeCave/", B + "GrandfatherAttic/"
W, VH = 576, 324  # ширина кімнати й висота кадру, арт
CAVE_H = 960
STYLE = cb.STYLE
MAG, GREEN = cb.MAGENTA, cb.CHROMA

# --- печера: контур (арт px) -------------------------------------------------------------------------------------
TOP_SHELF = (0, 330, 277)  # x від, x до, верх — лінія ходьби 416 світу
MID_SHELF = (246, W, 597)  # 896 світу
FLOOR = 917  # 1376 світу
SHELF_T = 46  # товщина уступу
MOUTH = (70, 210)  # гирло в стелі: стовпці; згори — світло й низ мосту
CEIL = 58  # нижній край стелі (рваний)
SIDE = 26  # бічні стіни
HOLE = (60, 150)
CEIL_PATCH = (205, 390)  # діра в дні — далі вниз
DROP = 320
FAR_F, PROP_F, FRONT_F = 0.5, 0.9, 1.3
CAM_MAX = CAVE_H - VH  # 636

# --- горище -------------------------------------------------------------------------------------------------------
WALK = 277  # лінія ходьби 416 світу; підлога — ElderHouse/gen_floor (той самий дім), рядок 0 на лінії ходьби
HATCH_X, HATCH_W = 300, 44  # лаз у підлозі: лівий край і ширина (герой ~35 арту)

# розміри — таблиця світу (D814): герой 64, бочка 32, двері 112
SIZES = dict(
    ladder=DROP + 12,  # від гаків на кромці уступу до рівня нижче
    waymark=56,
    stalactites=150,
    clutter=70,
    shrine=54,
    hatch=60,
    herbs=120,
)

CAVE_WALL_TEXT = (
    "the inside of a tall natural sandstone cave under a canyon bridge seen exactly from the side: rough natural "
    "rock, no bricks and no masonry, warm orange and ochre sandstone with wavy strata, irregular cracks and cool violet "
    "shadows, uneven natural rock shelves with a thin light "
    "sandy edge, a ragged rock ceiling with an opening at the top left where pale daylight and the dark stone underside "
    f"of an old arched bridge show, a dark pit in the cave floor, {GREEN} for the open air inside the cave, {STYLE}"
)
TEXTS = {
    # скеля печери окремо, без будови: її пікселі лягають у контур напрямної (0.86 по пласкій напрямній малювало
    # цеглу й власну будову замість контуру)
    "cave_rock": (
        "a flat wall of rough natural sandstone cave rock filling the whole frame, seen straight on: warm orange and "
        "ochre rock with wavy horizontal strata, irregular cracks and cool violet shadows in the cracks, no bricks, no "
        f"masonry, no openings, {STYLE}",
        1152,
        1920,
        5141,
    ),
    "cave_far": (
        "the far back wall of a huge dark sandstone cave seen straight on, filling the whole frame: tall rock columns "
        "and hanging stalactites receding into deep violet and maroon shadow, faint warm orange light on a few rock "
        f"edges, small clusters of softly glowing pale blue cave mushrooms on ledges, thin dusty light from a crack high above, {STYLE}",
        1152,
        1296,
        5101,
    ),
    "cave_ladder": (
        "a single long rope ladder hanging perfectly straight down, seen exactly from the front, two thick twisted "
        "hemp ropes with evenly spaced round wooden rungs, two old iron hooks at its very top, the whole ladder fills "
        f"the frame from top to bottom, {MAG}, {STYLE}",
        512,
        1536,
        5111,
    ),
    "cave_waymark": (
        "a small old standing stone waymark seen from the side, carved with a simple lizard figure and spiral marks, "
        "faded red and blue prayer cloths tied around it, a small clay offering bowl at its foot, standing alone on "
        f"bare rock in the middle of the frame, {MAG}, {STYLE}",
        1024,
        1024,
        5121,
    ),
    "cave_stalactites": (
        "a cluster of long sharp sandstone stalactites of different lengths hanging down from a rough rock ceiling "
        f"edge at the top of the frame, nothing else, {GREEN}, {STYLE}",
        1024,
        768,
        5131,
    ),
    "attic_wall": (
        "the inside of a dusty attic under the pitched roof of an old desert village house seen straight on: dark "
        "wooden rafters slanting down from the ridge at the top middle to both sides, roof boards and reed matting "
        "between them, a plastered warm adobe gable wall at the back with one small round window letting in a soft "
        "beam of dusty daylight, cobwebs in the upper corners, an empty bare wooden plank floor along the bottom, "
        f"nothing standing on the floor, {STYLE}",
        1728,
        976,
        5201,
    ),
    "attic_clutter": (
        "a low pile of an old man's stored belongings seen exactly from the side: a worn wooden chest with iron "
        "bands, rolled woven red and blue carpets, a stack of baskets, clay jars, an old round hand drum with painted "
        "spirals leaning against the chest, all in one group standing directly on the bottom edge of the frame, no "
        f"floor, no wall, nothing behind them, {MAG}, {STYLE}",
        1536,
        768,
        5212,
    ),
    "attic_shrine": (
        "a small home prayer corner seen exactly from the side: a low old wooden table, on it a small rough "
        "terracotta figurine of an ancient desert goddess with her arms raised, simple rounded shapes, a burnt-down "
        "candle, a loop of wooden prayer beads, a stack of handwritten paper notes and an ink pot with a reed pen, the "
        f"table standing directly on the bottom edge of the frame, no floor, no wall, nothing behind it, {MAG}, {STYLE}",
        1024,
        1024,
        5222,
    ),
    "attic_hatch": (
        "seen exactly from the side: the top end of a plain wooden ladder sticking straight up, and right next to it "
        "a square wooden trapdoor lid with iron hinges standing open upright, both standing directly on the bottom "
        f"edge of the frame, no floor, no hole, no wall, nothing behind them, {MAG}, {STYLE}",
        1024,
        1024,
        5232,
    ),
    "attic_herbs": (
        "the end of a dark wooden roof beam at the top of the frame with bundles of dried herbs and a string of dried "
        f"red peppers hanging down from it on strings, nothing else, {GREEN}, {STYLE}",
        768,
        1024,
        5241,
    ),
}


def raw(name):
    return os.path.join(D, f"m6b1_{name}_raw.png")


def noise(h, w, cell, seed):
    """Гладкий шум 0..1: випадкова сітка cell, розтягнута білінійно."""
    r = np.random.default_rng(seed).random((h // cell + 2, w // cell + 2))
    return (
        np.asarray(
            Image.fromarray((r * 255).astype(np.uint8)).resize(
                ((w // cell + 2) * cell, (h // cell + 2) * cell), Image.BILINEAR
            )
        )[:h, :w]
        / 255.0
    )


def cave_masks():
    """Контур печери (арт px): solid — скеля, sky — гирло, hole — діра в дні; решта — повітря."""
    y, x = np.mgrid[:CAVE_H, :W]
    jag = (
        noise(CAVE_H, W, 14, 7) - 0.5
    ) * 18  # рваний край стін, стелі й низу уступів (не верху: там ходять)
    solid = (x < SIDE + jag) | (x > W - SIDE + jag)
    ceil = y < CEIL + jag
    mouth = (x >= MOUTH[0] + jag / 2) & (x < MOUTH[1] + jag / 2)
    sky = mouth & (y < 26 + jag / 3)  # денне світло згори; нижче в гирлі — повітря (прохід з мосту)
    solid |= ceil & ~mouth
    for x0, x1, top in (TOP_SHELF, MID_SHELF):
        # низ уступу — клин: товстий біля стіни, тонший до кромки
        thick = (
            SHELF_T + jag + np.where(x0 == 0, (x1 - x) / x1, (x - x0) / (W - x0)) * 30
        )
        solid |= (x >= x0) & (x < x1) & (y >= top) & (y < top + thick)
    hole = (x >= HOLE[0]) & (x < HOLE[1]) & (y >= FLOOR)
    solid |= (y >= FLOOR) & ~hole
    return solid, sky, hole


def cave_guide(k=2):
    solid, sky, hole = cave_masks()
    rock = np.asarray(
        Image.open(raw("cave_rock")).convert("RGB").resize((W, CAVE_H), Image.BOX), np.float32
    )
    # низ уступів і стелі — у тінь, щоб модель бачила об'єм
    y = np.arange(CAVE_H)[:, None]
    below = np.zeros((CAVE_H, W))
    for x0, x1, top in (TOP_SHELF, MID_SHELF):
        below[top + 14 :, x0:x1] = 1
    rock = rock * (1 - 0.3 * (below * solid)[..., None])
    g = np.where(solid[..., None], rock, [0, 255, 0])
    # кромки уступів і дна — світлий пісок
    for x0, x1, top in (TOP_SHELF, MID_SHELF, (0, W, FLOOR)):
        g[top : top + 3, x0:x1] = [236, 178, 116]
    g[sky] = [160, 205, 235]
    # низ мосту в гирлі: темна арка
    y, x = np.mgrid[:CAVE_H, :W]
    cx = sum(MOUTH) / 2
    arch = sky & (y < 4 + ((x - cx) / 70.0) ** 2 * 10)
    g[arch] = [92, 70, 78]
    g[hole] = [26, 18, 34]
    g = np.clip(g, 0, 255).astype(np.uint8)
    return np.asarray(Image.fromarray(g).resize((W * k, CAVE_H * k), Image.NEAREST))


# Qwen-Image «на пурпурі» все одно малює підлогу й стіну під предметами — їх прибирає правка Qwen-Image-Edit-2511
# (comfy_sprite.edit, як cellar_planes); на горищі: статуетка була фараоновою лялькою, кришка лазу — віконницею на стіні
KEEP = "Keep the same style, colours, size and position."
EDITS = {
    "attic_clutter": (
        "Replace the floor, the floor edge and the wall behind with flat magenta (#FF00FF). Keep the wooden chest, the "
        "rolled carpets, the baskets, the clay jars and the drum exactly as they are. " + KEEP,
        6211,
    ),
    "attic_shrine": (
        "Replace the floor and the walls with flat magenta (#FF00FF), keep the table with its legs. Change the figurine "
        "into a small rough clay figurine of a woman in a long plain robe with her hands together in prayer, with no "
        "crown and no headdress. Keep the candle, the prayer beads, the paper notes and the ink pot. " + KEEP,
        6221,
    ),
    "attic_hatch": (
        "Keep only the wooden ladder on the left, exactly as it is. Replace everything else, the walls, the wooden "
        "shutter, the doorway, the floor and the shadows, with flat magenta (#FF00FF). " + KEEP,
        6231,
    ),
}


def edit(name):
    sys.path.insert(0, "Scripts/Tools")
    import comfy_sprite as cs

    src = np.asarray(Image.open(raw(name)).convert("RGBA"))
    out = cs.edit(src, *EDITS[name])
    Image.fromarray(out.astype(np.uint8)).convert("RGB").resize(
        (src.shape[1], src.shape[0]), Image.BOX
    ).save(raw(name + "_edit"))
    print(name + "_edit", flush=True)


def txt2img(name):
    text, w, h, seed = TEXTS[name]
    out = cb.run(cb.graph(text, seed, h, width=w))
    Image.fromarray(out.astype(np.uint8)).save(raw(name))
    print(name, flush=True)


def gen():
    import json
    import urllib.request

    todo = [n for n in [*TEXTS, "cave_wall"] if not os.path.exists(raw(n))]
    for name in todo[:4]:  # ≤ 4 за запуск (ОЗП, skill comfy-backdrop)
        if name == "cave_wall":
            g = cave_guide()
            rgba = np.concatenate([g, np.zeros((*g.shape[:2], 1), np.uint8)], 2)
            up = cb.upload(rgba, "m6b1_cave_guide.png")
            out = cb.run(
                cb.graph(CAVE_WALL_TEXT, 5002, len(g), up, 0.55, width=g.shape[1])
            )
            Image.fromarray(out.astype(np.uint8)).save(raw(name))
            print(name, flush=True)
        else:
            txt2img(name)
    if not todo:
        for name in EDITS:
            if not os.path.exists(raw(name + "_edit")):
                edit(name)
    s = json.load(urllib.request.urlopen(cb.API + "/system_stats"))["system"]
    print("left", todo[4:], "ram_free GB", round(s["ram_free"] / 2**30, 1))
    if not todo[4:]:
        urllib.request.urlopen(
            urllib.request.Request(
                cb.API + "/free",
                json.dumps({"unload_models": True, "free_memory": True}).encode(),
                {"Content-Type": "application/json"},
            )
        )
        print("models freed")


# --- build --------------------------------------------------------------------------------------------------------
def load(name):
    return np.asarray(Image.open(raw(name)).convert("RGB"), np.float32)


def to_palette(rgb, pal):
    d = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1)
    return pal[d.argmin(-1)]


def palette(rgba):
    return np.unique(rgba[..., :3][rgba[..., 3] > 0].reshape(-1, 3), axis=0).astype(
        np.float32
    )


def prop(name, height, pal, shade=0.0, squeeze=None):
    """Предмет на хромакеї → рівно height арту заввишки, у палітрі кімнати, альфа 0/255."""
    from scipy import ndimage

    img = load(name)
    # тло — найрівніший з чотирьох країв (у бурульок верх — скеля, у предметів на підлозі — низ)
    edges = [img[:8], img[-8:], img[:, :8], img[:, -8:]]
    edge = min((e.reshape(-1, 3) for e in edges), key=lambda e: e.std(0).sum())
    bg = np.median(edge, axis=0)
    m = np.linalg.norm(img - bg, axis=2) > cb.KEY_DISTANCE
    if bg[1] < 120:  # пурпур: і темні пурпурні тіні на тлі
        m &= np.minimum(img[..., 0], img[..., 2]) - img[..., 1] < 60
    else:  # зелений відсвіт країв
        img[..., 1] = np.minimum(img[..., 1], np.maximum(img[..., 0], img[..., 2]) + 10)
    m = ndimage.binary_opening(m, iterations=2)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, 1 + np.nonzero(sizes >= sizes.max() * 0.02)[0])
    ys, xs = np.nonzero(m)
    img, m = (
        img[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
        m[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
    )
    f = height / len(img)
    w = squeeze or max(1, round(img.shape[1] * f))
    # колір — лише з непрозорих пікселів
    a = Image.fromarray((m * 255).astype(np.uint8)).resize((w, height), Image.BOX)
    c = Image.fromarray((img * m[..., None]).astype(np.uint8)).resize(
        (w, height), Image.BOX
    )
    al = np.asarray(a, np.float32)
    rgb = np.asarray(c, np.float32) * 255 / np.maximum(al, 1)[..., None]
    rgb = rgb * (1 - shade)
    out = np.zeros((height, w, 4), np.uint8)
    out[..., :3] = to_palette(rgb, pal)
    out[..., 3] = (al >= 128) * 255
    return out


def save(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr).save(path)
    print(path, arr.shape[1], "x", arr.shape[0], flush=True)


def build():
    # печера: стіна — сира img2img, ×2 → арт; непрозора рівно під контуром (колізія = контур), гирло — теж непрозоре
    solid, sky, hole = cave_masks()
    big = load("cave_wall")
    rgb = big.reshape(CAVE_H, 2, W, 2, 3).mean(axis=(1, 3))
    op = solid | sky
    # стеля праворуч від гирла: модель домалювала там темну цегляну арку мосту — другий «вхід» у глуху скелю;
    # на її місці — стеля правої частини дзеркально (cave_rock там виходив чорною плитою)
    x0, x1 = CEIL_PATCH
    rgb[: CEIL + 12, x0:x1] = rgb[: CEIL + 12, x1 : x1 + (x1 - x0)][:, ::-1]
    # дно: модель поклала цеглу — підлога сусідньої печери ящурів (той самий пісковик, рядок 0 — лінія ходьби)
    lf = np.asarray(Image.open(B + "LizardCave/gen_floor.png").convert("RGB"), np.float32)
    rgb[FLOOR:] = lf[: CAVE_H - FLOOR]
    wall = cb.quantize(rgb, op, 16, "octree")
    # зелений відсвіт хромакею на краях скелі — у найближчий незелений колір
    pal = palette(wall)
    ok = pal[~(pal[:, 1] > np.maximum(pal[:, 0], pal[:, 2]) + 10)]
    px = wall[..., :3].astype(np.float32)
    bad = (wall[..., 3] > 0) & (px[..., 1] > np.maximum(px[..., 0], px[..., 2]) + 10)
    wall[bad, :3] = to_palette(px[bad][None], ok)[0]
    # кромка ходьби — найсвітліший теплий колір палітри, щоб уступи читались першими
    pal = palette(wall)
    lip = pal[np.argmax(pal.sum(-1) * (pal[:, 0] > pal[:, 2]))].astype(np.uint8)
    for x0, x1, top in (TOP_SHELF, MID_SHELF, (0, W, FLOOR)):
        row = wall[top, x0:x1]
        row[row[:, 3] > 0, :3] = lip
    save(wall, CAVE + "gen_wall.png")
    # далечінь ×0.5: 576×648 (кадр 324 + 0.5 × 636), темніша й холодніша за стіну
    far = load("cave_far")
    far = np.asarray(
        Image.fromarray(far.astype(np.uint8)).resize((W, 648), Image.BOX), np.float32
    )
    far = (far * 0.62 + np.array([50, 34, 64]) * 0.38) * 0.8
    save(
        cb.quantize(far, np.ones(far.shape[:2], bool), 12, "octree"),
        CAVE + "gen_far.png",
    )
    save(prop("cave_ladder", SIZES["ladder"], pal, squeeze=34), CAVE + "gen_ladder.png")
    save(prop("cave_waymark", SIZES["waymark"], pal), CAVE + "gen_waymark.png")
    # передній план: лише бурульки — суцільна плита стелі над ними (прямі краї обрізу) геть; верх — край кадру
    st = prop("cave_stalactites", SIZES["stalactites"], pal, shade=0.45)
    cover = (st[..., 3] > 0).mean(1)
    save(st[int(np.argmax(cover < 0.6)) :], CAVE + "gen_front.png")
    # горище
    a = load("attic_wall")[: VH * 3]
    a = a.reshape(VH, 3, W, 3, 3).mean(axis=(1, 3))
    floor = np.asarray(Image.open(B + "ElderHouse/gen_floor.png").convert("RGBA"))
    aw = cb.quantize(a, np.ones((VH, W), bool), 16, "octree")
    save(aw, ATTIC + "gen_wall.png")
    apal = np.concatenate([palette(aw), palette(floor)])
    # підлога горища — підлога дому діда з лазом: темний отвір на всю товщу, світла кромка дощок по краях
    af = floor.copy()
    fp = palette(floor)
    dark, light = fp[np.argmin(fp.sum(-1))], fp[np.argmax(fp.sum(-1))]
    af[:, HATCH_X : HATCH_X + HATCH_W, :3] = dark
    af[:, [HATCH_X - 1, HATCH_X + HATCH_W], :3] = light
    save(af, ATTIC + "gen_floor.png")
    save(prop("attic_clutter_edit", SIZES["clutter"], apal), ATTIC + "gen_clutter.png")
    save(prop("attic_shrine_edit", SIZES["shrine"], apal), ATTIC + "gen_shrine.png")
    save(prop("attic_hatch_edit", SIZES["hatch"], apal), ATTIC + "gen_hatch.png")
    save(prop("attic_herbs", SIZES["herbs"], apal, shade=0.55), ATTIC + "gen_front.png")


# --- розміщення (для README і аркуша): (файл, множник, x, y якорів — верхній лівий кут при камері 0) ------------
def img(path):
    return np.asarray(Image.open(path).convert("RGBA"))


def on(top_row, h, f, cam):
    """y якоря плану з множником f, щоб його низ стояв на рядку top_row кімнати, коли камера на cam."""
    return round(top_row - h - (1 - f) * cam)


def cave_planes(ladders=False):
    lad, wm, _fr = (
        img(CAVE + "gen_ladder.png"),
        img(CAVE + "gen_waymark.png"),
        img(CAVE + "gen_front.png"),
    )
    lw, lh = lad.shape[1], lad.shape[0]
    ps = [
        ("gen_far.png", FAR_F, 0, 0),
        ("gen_wall.png", 1.0, 0, 0),
        ("gen_waymark.png", PROP_F, 236, on(TOP_SHELF[2] + 2, len(wm), PROP_F, 0)),
    ]
    if ladders:  # наприкінці гри: від кромки уступу (гаки на рядку верху) до рівня нижче, ×1.0 — драбина для ходьби
        ps += [
            ("gen_ladder.png", 1.0, TOP_SHELF[1] - lw - 4, TOP_SHELF[2] - 12 + 0),
            ("gen_ladder.png", 1.0, MID_SHELF[0] + 4, MID_SHELF[2] - 12),
        ]
    ps += [
        ("gen_front.png", FRONT_F, 400, 0),
    ]
    return ps, lh


def attic_planes():
    cl, sh, ha = (
        img(ATTIC + "gen_clutter.png"),
        img(ATTIC + "gen_shrine.png"),
        img(ATTIC + "gen_hatch.png"),
    )
    return [
        ("gen_wall.png", 1.0, 0, 0),
        ("gen_floor.png", 1.0, 0, WALK),
        ("gen_clutter.png", 1.0, 30, WALK + 3 - len(cl)),
        ("gen_shrine.png", 1.0, 440, WALK + 3 - len(sh)),
        ("gen_hatch.png", 1.0, HATCH_X + (HATCH_W - ha.shape[1]) // 2, WALK + 20 - len(ha)),
        ("gen_front.png", FRONT_F, 520, -4),
    ]


def view(base, planes, cam, hero=None):
    c = Image.new("RGBA", (W, VH), (0, 0, 0, 255))
    for name, f, x, y in [*planes, (None, 9, 0, 0)]:
        if hero and f > 1:  # герой — перед усім, крім переднього плану
            h = Image.fromarray(hero[2])
            c.alpha_composite(h, (hero[0], hero[1] - cam - h.height))
            hero = None
        if name:
            c.alpha_composite(Image.fromarray(img(base + name)), (x, round(y - f * cam)))
    return np.asarray(c)


def sheet():
    hero = img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    cp, _ = cave_planes()
    cl, _ = cave_planes(ladders=True)
    ap = attic_planes()
    frames = [
        (
            "Cave under the bridge, top frame (camera y 0): dropped in through the mouth under the bridge; the waymark x0.9, stalactites x1.3",
            view(CAVE, cp, 0, (150, TOP_SHELF[2], hero)),
        ),
        (
            "Cave, parallax-shifted (camera y 318): far x0.5 and front x1.3 slide against the wall; hero on the middle shelf",
            view(CAVE, cp, 318, (420, MID_SHELF[2], hero)),
        ),
        (
            "Cave, bottom frame (camera y 636), END-GAME state: the two rope ladders lowered; the pit at the left goes down to the cave exit",
            view(CAVE, cl, 636, (230, FLOOR, hero)),
        ),
        (
            "Grandfather's attic (one screen, static camera): the hatch with its ladder, his belongings, the Maiden statuette corner with his notes",
            view(ATTIC, ap, 0, (240, WALK, hero)),
        ),
    ]
    lab, gap = 28, 12
    out = Image.new("RGB", (1920, len(frames) * (1080 + lab + gap)), (24, 22, 28))
    d = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    y = 0
    for title, v in frames:
        out.paste(
            Image.fromarray(v[..., :3]).resize((1920, 1080), Image.NEAREST),
            (0, y + lab),
        )
        d.text((6, y + 8), title, fill=(235, 225, 200), font=font)
        y += 1080 + lab + gap
    out.save("design/shots/m6b1_cave_attic.png")
    print("sheet", out.size, flush=True)


if __name__ == "__main__":
    {
        "gen": gen,
        "build": build,
        "sheet": sheet,
        "guide": lambda: Image.fromarray(cave_guide(1)).save(raw("guide")),
    }[sys.argv[1]]()
