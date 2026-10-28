"""M6b-6: останні кімнати Каньйону — Дно каньйону (CanyonFloor, 4 клітинки, просто неба: дно глибокого каньйону;
захід — глуха скеля з тріщиною, замурованою контрабандистами, — тріснута стіна до схованки; на 2912…3104 світу —
діра вниз у печери ящерів; схід — гирло печери, вихід з печери), Вихід з печери (CaveExit, 1 клітинка: печера під
печерою під мостом — у стелі на 90…225 світу яма, з якої падає герой (BridgeCave README: pit 60…150 арту); захід —
тунель до дна каньйону, схід — широке гирло на пустельну дорогу) і Схованка контрабандистів (SmugglersStash,
1 клітинка: печерка за тріснутою стіною, пролом назад на x 423 світу, товар контрабандистів).
Усі три — одна клітинка заввишки: лінія ходьби — рядок 256 арту (підлога y 384 світу).
  python -B design/shots/candidates/m6b6/m6b6.py gen    — ComfyUI (сирі PNG поруч; є — не кличе модель; ≤ 4 за запуск)
  python -B design/shots/candidates/m6b6/m6b6.py build  — плани в SampleProject/Assets/Backgrounds/{CanyonFloor,CaveExit,SmugglersStash}/
  python -B design/shots/candidates/m6b6/m6b6.py sheet  — design/shots/m6b6_canyon_floor.png
Скеля дна й обох печер — пісковик Печери під мостом (m6b1_cave_rock_raw.png як підмальок напрямних: контур — скрипта,
не моделі). Розміри — таблиця світу (D814): герой 64 арту, двері 112, людина 96; на плані f — round(h × f).
"""

import json
import os
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, "Scripts/Tools")
sys.path.insert(
    0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "m6b5")
)
import comfy_backdrop as cb
import m6b5 as m5  # mask, scaled, darken, compose, stand, sh, save, img, free — той самий конвеєр

D = os.path.dirname(os.path.abspath(__file__))
B = "SampleProject/Assets/Backgrounds/"
CF, CE, SS = B + "CanyonFloor/", B + "CaveExit/", B + "SmugglersStash/"
W, VH, WALK = 576, 324, 256
STYLE = cb.STYLE
MAG = cb.MAGENTA
GREEN = "solid flat chroma key green (#00FF00)"
SIDE = "seen exactly from the side, flat orthographic side elevation, no perspective"
FRONT = "seen straight on, flat orthographic front elevation, no perspective"
ROCK = os.path.join(
    D, "..", "m6b1", "m6b1_cave_rock_raw.png"
)  # пісковик Печери під мостом

# геометрія сцен, арт (світ / 1.5)
CF_W = 2304  # Дно: 4 клітинки, камера x 0…1728
CF_HOLE = (
    1941,
    2069,
)  # діра в печери ящерів: світ 2912…3104 (Foreground: плитки 91…96 порожні)
STASH_X = 200  # Wall_Stash / StashDoor: світ 300 → тріщина в скелі
CE_PIT = (
    60,
    150,
)  # яма Печери під мостом (BridgeCave README: pit 90…225 світу) — діра в стелі Виходу
SS_DOOR_X = 128  # прохід Схованки — тунель, намальований стіною (ss_wall 9671: чорне ядро 93…160 арту); ExitDoor → світ 192
CRACK_H, CRACK_W = 112, 50  # тріщина-прохід — у двері (D814)

# тайли: (текст, рядки арту, зерно, ключ); генерація 1728 px завширшки (×3), шов — модель
TILES = {
    "cf_far": (
        "the far wall of a deep narrow desert canyon seen from its bottom, straight on, flat, no perspective: "
        "towering sheer cliffs of layered orange and ochre sandstone with wavy strata, deep vertical cracks and cool "
        "violet shadows, dry roots and small dead shrubs on narrow ledges, a narrow strip of pale grey sky only along "
        "the very top edge, heaps of fallen rock at the foot of the cliffs, spanning the full width and filling the "
        "whole frame from the top edge to the bottom edge",
        324,
        9601,
        None,
    ),
    "cf_mid": (
        "big rounded fallen sandstone boulders and broken flat rock slabs lying in groups at the bottom of a desert "
        "canyon with wide empty gaps between the groups, dead thorn bushes and bleached dry branches between them, "
        f"spanning the full width and reaching the bottom edge, {GREEN} above them and in every gap",
        200,
        9611,
        "green",
    ),
}

# предмети на хромакеї: (текст, ширина, висота генерації px, зерно)
PROPS = {
    "cf_cracked": (
        f"a rough wall of stacked flat sandstone stones and dried mud plaster {FRONT}, tall and narrow, plugging a "
        "crack in a cliff, a big jagged crack running through it from top to bottom, a few stones loose and chipped, "
        f"small stones fallen at its foot, standing alone, nothing behind it, {MAG}",
        1024,
        1024,
        9641,
    ),
    "cf_cart": (
        f"an old abandoned wooden handcart {SIDE}, one wheel broken and lying beside it, loaded with bulging sacks "
        "tied with rope and a cracked clay jar, its two long handles resting on the ground, standing alone, nothing "
        f"behind it, {MAG}",
        1536,
        1024,
        9651,
    ),
    # 9661 — драбина, приставлена до насипу: читалась шляхом угору (ям назад немає, D834; драбин — ні)
    "ce_rubble": (
        f"a low wide mound of fallen sandstone rubble and sand {SIDE}, a few broken old wooden planks and a frayed "
        f"snapped rope end lying flat on it, standing alone, nothing behind it, {MAG}",
        1536,
        768,
        9662,
    ),
    "ss_wall": (
        "the inside of a small hidden cave hollow seen straight on, flat, no perspective: rough walls of warm orange "
        "and ochre sandstone with wavy strata and violet shadows, a low uneven rock ceiling, an old timber prop beam "
        "holding up the rock, a small niche in the wall with a clay oil lamp giving a warm glow, rows of tally marks "
        "and a crude map scratched into the rock, coils of rope and empty sacks hanging on wooden pegs, an empty bare "
        "sandy floor along the bottom, nothing standing on the floor",
        1728,
        976,
        9671,
    ),
    "ss_goods": (
        f"a pile of hidden smuggled goods {SIDE}: stacked wooden crates with rope handles, bulging burlap sacks, tall "
        "clay amphorae, a rolled striped carpet, a small iron-bound strongbox, an oil lantern standing on top, all in "
        f"one group standing directly on the bottom edge of the frame, no floor, no wall, nothing behind them, {MAG}",
        1536,
        768,
        9691,
    ),
}

# напрямні (img2img по намальованому контуру, як cave_wall у m6b1): (текст, зерно, denoise)
GUIDES = {
    "cf_cliff": (
        "a towering sheer cliff of rough natural sandstone closing the end of a canyon seen exactly from the side: "
        "warm orange and ochre rock with wavy strata, irregular cracks and cool violet shadows, no bricks, no masonry, "
        f"a narrow tall dark crack opening into the rock at its foot, {GREEN} for the open air, {STYLE}",
        9712,  # 9711 — цегляні латки біля підніжжя
        0.55,
    ),
    "cf_mouth": (
        "the side of a sandstone cliff at the bottom of a canyon seen exactly from the side, a big dark cave mouth "
        "opening in it at ground level and reaching the right edge, rough natural rock, warm orange and ochre "
        f"sandstone with wavy strata, cracks and cool violet shadows, {GREEN} for the open air, {STYLE}",
        9721,
        0.55,
    ),
    "ce_wall": (
        "the inside of a low wide natural sandstone cave seen exactly from the side: rough natural rock, no bricks and "
        "no masonry, warm orange and ochre sandstone with wavy strata, irregular cracks and cool violet shadows, a "
        "ragged rock ceiling with short stalactites and a dark hole broken through the ceiling at the top left, on "
        f"the right the cave opens wide to the outside, {GREEN} for the open air inside the cave, {STYLE}",
        9731,
        0.55,
    ),
}

# дорисовування діри в підлозі Дна (як river_hole у m6b4: темний підмальок, модель лише зводить краї)
HOLE_TEXT = (
    "a side cross-section of the rocky floor of a canyon with a deep hole broken through it: the broken edges of the "
    "floor on the left and right show layered orange sandstone with hanging dry roots, between them the hole is a "
    "deep dark void fading from deep violet to black"
)
HOLE_SEED, HOLE_DENOISE, LIP, CTX_TOP = 9741, 0.75, 2, 200
HOLE_CAM = 1728  # контекст — кадр при камері на східному краю (діра на 213…341 кадру)

SIZES = dict(
    cf_cracked=124,  # закладає тріщину-прохід 112 (D814) з запасом
    cf_cart=round(64 * 0.9),  # візок з поклажею — 1 H; ×0.9
    ce_rubble=26,  # низький насип під ямою: герой падає на нього, не ховається
    ss_goods=80,  # ящики (32–40, як бочка) в два яруси з мішками й амфорами
)


def raw(name):
    return os.path.join(D, f"m6b6_{name}_raw.png")


# --- напрямні (арт px) --------------------------------------------------------------------------------------------
def noise(h, w, cell, seed):
    r = np.random.default_rng(seed).random((h // cell + 2, w // cell + 2))
    big = Image.fromarray((r * 255).astype(np.uint8)).resize(
        ((w // cell + 2) * cell, (h // cell + 2) * cell), Image.BILINEAR
    )
    return np.asarray(big)[:h, :w] / 255.0


ROCK_Y = 300  # рядок сирої скелі, з якого береться підмальок
GH = 264  # висота напрямної: кадр до трохи нижче лінії ходьби (низ перекриває смуга підлоги)


def crack(x, y, cx, top, hw):
    """Вузька тріщина-прохід: стіни прямі до 0.6 висоти, далі сходяться в гострий верх."""
    h = WALK + 2 - top
    up = np.clip((WALK + 2 - y) / h, 0, 1)
    half = hw * np.clip((1 - up) / 0.4, 0, 1)
    return (
        (y <= WALK + 1) & (y >= top) & (np.abs(x - cx) <= np.where(up < 0.6, hw, half))
    )


def masks(name):
    """(solid, dark): solid — скеля (непрозора), dark — темний отвір у ній (теж непрозорий)."""
    y, x = np.mgrid[:GH, :W]
    jag = (noise(GH, W, 14, 11) - 0.5) * 18
    floor = y >= WALK + 2
    if name == "cf_cliff":
        # глуха скеля на західному краю: обличчя до ~330 (нахилений контрфорс), тріщина на STASH_X
        edge = 330 + (GH - y) * 0.06 + jag
        solid = (x < edge) | floor
        dark = crack(x, y, STASH_X, WALK + 2 - CRACK_H, CRACK_W / 2)
    elif name == "cf_mouth":
        # останній екран (кімната 1728…2304 → 0…576): скеля від ~430, гирло від 480 до краю, 150 заввишки
        edge = 430 - (GH - y) * 0.08 + jag
        solid = (x > edge) | floor
        top = 106 + 40 * ((W - x) / 96.0) ** 2
        dark = (x >= 480 + jag / 2) & (y >= top) & ~floor
    else:  # ce_wall: стеля, задня стіна-одвірок гирла, яма в стелі
        ceil = y < 64 + jag
        # край гирла: скеля між L і R — широка під стелею (350…470), вузька біля підлоги (440…460)
        left = 440 - 90 * (1 - y / WALK) ** 2 + jag / 2
        right = 460 + 10 * (1 - y / WALK) + jag / 2
        jamb = (x > left) & (x < right) & (y < WALK)
        solid = ceil | jamb | floor
        dark = (x >= CE_PIT[0]) & (x < CE_PIT[1]) & (y < 64 + jag + 6)
    return solid, dark


def guide(name, k=2):
    solid, dark = masks(name)
    # смуга без цегли й дверей сирої (рядки ROCK_Y…), без стискання: 1152 px сирої = 576 арту
    rock = Image.open(ROCK).convert("RGB").crop((0, ROCK_Y, 1152, ROCK_Y + GH * 2))
    rock = np.asarray(rock.resize((W, GH), Image.BOX), np.float32)
    g = np.where(solid[..., None], rock, [0, 255, 0]).astype(np.float32)
    # отвір — темний градієнт згори вниз (порожнеча), край ходьби — світлий пісок
    t = np.linspace(0, 1, GH)[:, None, None]
    void = np.array([70, 44, 92]) * (1 - t) + np.array([12, 8, 20]) * t
    if (
        name == "ce_wall"
    ):  # яма в стелі: темно вгорі, тьмяне світло знизу не треба — над нею печера
        void = np.array([12, 8, 20]) * (1 - t) + np.array([60, 40, 80]) * t
    g = np.where(dark[..., None], void, g)
    # без світлої кромки на лінії ходьби (як у m6b1): 9711 прочитала її верхом цегляної кладки
    g = np.clip(g, 0, 255).astype(np.uint8)
    return np.asarray(Image.fromarray(g).resize((W * k, GH * k), Image.NEAREST))


# --- генерація ----------------------------------------------------------------------------------------------------
def gen_tile(name):
    text, rows, seed, _ = TILES[name]
    h = -(-rows * cb.SCALE // 16) * 16
    full = f"{text}, {STYLE}"
    im = cb.run(cb.graph(full, seed, h))
    im = cb.seam_pass(np.roll(im, cb.GW // 2, axis=1), {"seed": seed}, full, h)
    Image.fromarray(im[: rows * cb.SCALE].astype(np.uint8)).save(raw(name))
    print(name, flush=True)


def gen_prop(name):
    text, w, h, seed = PROPS[name]
    Image.fromarray(
        cb.run(cb.graph(f"{text}, {STYLE}", seed, h, width=w)).astype(np.uint8)
    ).save(raw(name))
    print(name, flush=True)


def gen_guide(name):
    text, seed, denoise = GUIDES[name]
    g = guide(name)
    up = cb.upload(
        np.dstack([g, np.zeros(g.shape[:2], np.uint8)]), f"m6b6_{name}_guide.png"
    )
    out = cb.run(cb.graph(text, seed, len(g), up, denoise, width=g.shape[1]))
    Image.fromarray(out.astype(np.uint8)).save(raw(name))
    print(name, flush=True)


def gen_hole(name="cf_hole"):
    """Кадр Дна при камері HOLE_CAM від CTX_TOP до низу (×3) — контекст; прозоре — лише діра нижче LIP."""
    ctx = cf_context()
    x0, x1 = CF_HOLE[0] - HOLE_CAM - 6, CF_HOLE[1] - HOLE_CAM + 6
    h = -(-len(ctx) * cb.SCALE // 16) * 16
    big = np.asarray(
        Image.fromarray(ctx).resize((W * cb.SCALE, len(ctx) * cb.SCALE), Image.NEAREST)
    )
    big = np.concatenate([big, np.repeat(big[-1:], h - len(big), axis=0)])
    x, y = np.arange(cb.GW), np.arange(h)
    edge = 12
    rx = np.clip(np.maximum(x0 * cb.SCALE - x, x - x1 * cb.SCALE) / edge, 0, 1)
    ry = np.clip(((WALK + LIP - CTX_TOP) * cb.SCALE - y) / edge, 0, 1)
    alpha = (np.maximum(rx[None, :], ry[:, None]) * 255).astype(np.uint8)
    up = cb.upload(np.dstack([big[..., :3], alpha]), "m6b6_cf_hole.png")
    out = cb.run(cb.graph(f"{HOLE_TEXT}, {STYLE}", HOLE_SEED, h, up, HOLE_DENOISE))
    Image.fromarray(out[: len(ctx) * cb.SCALE].astype(np.uint8)).save(raw(name))
    print(name, flush=True)


# латки на сирій напрямній (px генерації x0, y0, x1, y1): модель поклала там цеглу; перемальовуються лише вони
# Схованка (9671): мотузки на кілках вийшли петлями-зашморгами, а мішки на підлозі — у зріст героя (D814): обидва
# місця перемальовуються в голу стіну й пісок; товар у масштабі — окремий предмет (ss_goods)
CAVE_BARE = (
    "the inside of a small hidden cave hollow seen straight on: a plain rough sandstone cave wall with wavy strata and "
    "violet shadows meeting an empty bare sandy floor, nothing on the wall, nothing standing on the floor"
)
FIXES = {
    "cf_cliff": ([(170, 0, 310, 70), (530, 340, 668, 425), (0, 410, 140, 528)], 9713, 0.8, None),
    "ss_wall": ([(1150, 330, 1360, 660), (1140, 680, 1500, 935)], 9672, 0.9, CAVE_BARE),
    # 9672 лишила на місці мотузок темно-фіолетову прямокутну нішу — читалась другим проходом (D747)
    "ss_wall_fix": ([(1140, 320, 1370, 470)], 9673, 0.75, "a plain rough warm orange sandstone cave wall with wavy "
                    "strata lit by warm lamplight, no niche, no opening"),
}


# px генерації (x0, y0, x1, y1): 9713 намалювала цеглу в лівому нижньому куті знову
PATCH = {"cf_cliff": [(0, 410, 145, 512)]}


def gen_fix(name):
    boxes, seed, denoise, text = FIXES[name]
    im = load(name)
    alpha = np.full(im.shape[:2], 255, np.uint8)
    yy, xx = np.mgrid[: len(im), : im.shape[1]]
    for x0, y0, x1, y1 in boxes:  # м'який край 16 px: без видимої рамки латки
        d = np.maximum(np.maximum(x0 - xx, xx - x1), np.maximum(y0 - yy, yy - y1))
        alpha = np.minimum(alpha, np.clip(d * 16, 0, 255).astype(np.uint8))
    up = cb.upload(np.dstack([im.astype(np.uint8), alpha]), f"m6b6_{name}_fix.png")
    if text:
        text = f"{text}, {STYLE}"
    else:  # напрямна: її ж текст (у ньому вже STYLE)
        text = GUIDES[name][0].replace(", no bricks, no masonry", ", natural rock only, no bricks, no masonry")
    out = cb.run(cb.graph(text, seed, len(im), up, denoise, width=im.shape[1]))
    Image.fromarray(out.astype(np.uint8)).save(raw(name + "_fix"))
    print(name + "_fix", flush=True)


def gen():
    names = [*GUIDES, *[n + "_fix" for n in FIXES], *PROPS, *TILES, "cf_hole"]
    todo = [n for n in names if not os.path.exists(raw(n))]
    cost = 0
    while (
        todo and cost < 4
    ):  # ≤ 4 генерацій за запуск (ОЗП, skill comfy-backdrop); тайл — дві (шов)
        name = todo[0]
        if name == "cf_hole" and not all(os.path.exists(raw(n)) for n in TILES):
            break
        if name in TILES and cost > 2:
            break
        todo.pop(0)
        if name in TILES:
            gen_tile(name)
        elif name in PROPS:
            gen_prop(name)
        elif name in GUIDES:
            gen_guide(name)
        elif name.endswith("_fix"):
            gen_fix(name[:-4])
        else:
            gen_hole()
        cost += 2 if name in TILES else 1
    s = json.load(urllib.request.urlopen(cb.API + "/system_stats"))["system"]
    print("left", todo, "ram_free GB", round(s["ram_free"] / 2**30, 1))
    if not todo:
        m5.free()


# --- build --------------------------------------------------------------------------------------------------------
def load(name):
    return np.asarray(Image.open(raw(name)).convert("RGB"), np.float32)


def tile(name, haze, colors, fill=True):
    """Тайл 576 завширшки: ключ → ×3 вниз → (суцільно до низу) → серпанок → палітра (як m6b5.tile)."""
    key = TILES[name][3]
    im = load(name)
    if key == "green":  # напівпрозорий привид шва й блідо-бірюзові скелі (зелене просвічує) — теж тло
        im[im[..., 1] > np.maximum(im[..., 0], im[..., 2]) - 4] = np.median(im[:24].reshape(-1, 3), axis=0)
    rgb, op = cb.shrink(im, key)
    if fill and key:
        rgb, op = cb.fill_down(rgb, op)
    rgb = rgb * (1 - haze) + cb.HAZE * haze
    return cb.quantize(rgb, op, colors, "octree")


# обрізка сирої (px генерації: y0, y1, x0, x1): товар стоїть на кам'яній плиті на всю ширину — її кромка лишалась
# тонкою лінією через пів кімнати
CROP = dict(ss_goods=(0, 672, 260, 1110))  # 672 — передній край плити


def no_floor(m, y0=540):
    """Товар стоїть на плиті в перспективі (її задній край — рядок 540, передній — 672): нижче y0 лишаються лише
    стовпці, де товар був одразу над краєм плити; плита обабіч і між речами — геть."""
    m = m.copy()
    m[y0:] &= m[y0 - 12 : y0].any(0)
    return m


def prop(name, colors=16, haze=0.0, plate=True):
    im = load(name)
    m = m5.mask(im, plate)
    if name == "ss_goods":
        m = no_floor(m)
    if name in CROP:
        y0, y1, x0, x1 = CROP[name]
        im, m = im[y0:y1, x0:x1], m[y0:y1, x0:x1]
    return m5.scaled(im, m, SIZES[name], colors, haze)


def from_guide(name, colors=16):
    """Сира img2img ×2 → арт; непрозора рівно на контурі напрямної (скеля й отвір); зелений відсвіт — геть."""
    solid, dark = masks(name)
    big = load(name + "_fix" if os.path.exists(raw(name + "_fix")) else name)
    for x0, y0, x1, y1 in PATCH.get(name, []):  # цегла, що вціліла й після FIXES: дзеркало смуги над нею
        big[y0:y1, x0:x1] = big[2 * y0 - y1 : y0, x0:x1][::-1]
    rgb = big.reshape(GH, 2, W, 2, 3).mean(axis=(1, 3))
    rgb[..., 1] = np.minimum(rgb[..., 1], np.maximum(rgb[..., 0], rgb[..., 2]) + 10)
    op = solid | dark
    op[WALK + 1 :] = False  # нижче — смуга підлоги кімнати
    return cb.quantize(rgb, op, colors, "octree")


GROUND = (
    B + "MountainPath/gen_ground.png"
)  # скеля стежки — та сама порода каньйону; рядок 0 — лінія ходьби


def ground_tile():
    """Ґрунт стежки до 64 рядків (дзеркало низу) — суцільний до низу кімнати."""
    g = m5.img(GROUND)
    short = 320 - WALK - len(g)
    g = np.concatenate([g, g[-1 : -short - 1 : -1]])
    g[1:, :, 3] = 255  # рядок 0 — кромка стежки з її прозорими зазубринами
    return g


def ground_strip():
    """Уся підлога Дна одним спрайтом 2304×64 (без повтору): тайл стежки, у діру — дорисоване."""
    s = np.concatenate([ground_tile()] * (CF_W // W), axis=1)
    if not os.path.exists(raw("cf_hole")):
        return s
    rgb, _ = cb.shrink(load("cf_hole"), None)
    x0, x1 = CF_HOLE[0] - HOLE_CAM - 6, CF_HOLE[1] - HOLE_CAM + 6
    new = rgb[WALK - CTX_TOP : 320 - CTX_TOP, x0:x1]
    q = cb.quantize(new[LIP:], np.ones(new[LIP:].shape[:2], bool), 16, "octree")
    s[LIP:, CF_HOLE[0] - 6 : CF_HOLE[1] + 6] = q
    s[:LIP, CF_HOLE[0] : CF_HOLE[1]] = s[
        LIP + 3, CF_HOLE[0] : CF_HOLE[1]
    ]  # над дірою — без смужки землі
    s[..., 3] = 255
    return s


def cut(strip, x0, x1):
    """Підлога з прорізом x0…x1 нижче LIP (темний підмальок) — контекст для дорисовування (як m6b4.cut)."""
    s = strip.copy()
    t = np.linspace(0, 1, len(s) - LIP)[:, None, None]
    s[LIP:, x0:x1, :3] = (
        np.array([70, 44, 92]) * (1 - t) + np.array([10, 6, 18]) * t
    ).astype(np.uint8)
    return s


# скеля ×1.0 (обрив, гирло, печера) темніша за підмальок: яскравий пісковик сперечався з героєм і з підлогою
WALL_DARK = 0.72
FAR_DARK, MID_DARK = (
    0.55,
    0.75,
)  # дно в тіні: далека стіна темніша й холодніша, герой читається першим
MID_Y = VH - 200 + 12  # низ каменів ×0.75 трохи під лінією ходьби
FRONT_DARK = np.array([0.3, 0.26, 0.34])  # foreground_dark.tscn (D750)


def cf_back():
    return [
        (m5.img(CF + "gen_far.png"), 0.45, 0, 0, True),
        (m5.img(CF + "gen_mid.png"), 0.75, 0, MID_Y, True),
    ]


def cf_context():
    """Кадр Дна при камері HOLE_CAM (без переднього плану), рядки CTX_TOP…320, з темним прорізом у підлозі."""
    hole = cut(
        np.concatenate([ground_tile()] * (CF_W // W), axis=1),
        CF_HOLE[0] - 6,
        CF_HOLE[1] + 6,
    )
    planes = [(far_plane(), 0.45, 0, 0, True), (mid_plane(), 0.75, 0, MID_Y, True), (hole, 1.0, 0, WALK, False)]
    return m5.compose(planes, HOLE_CAM)[CTX_TOP:320, :, :3].copy()


def far_plane():
    return m5.darken(tile("cf_far", 0, 16, fill=False), FAR_DARK)


def mid_plane():
    return m5.darken(tile("cf_mid", 0.05, 14, fill=False), MID_DARK)  # fill: сухі кущі ставали шипами (B71)


def build():
    os.makedirs(CF, exist_ok=True)
    m5.save(far_plane(), CF + "gen_far.png")
    m5.save(mid_plane(), CF + "gen_mid.png")
    m5.save(ground_strip(), CF + "gen_ground.png")
    m5.save(m5.darken(from_guide("cf_cliff"), WALL_DARK), CF + "gen_cliff.png")
    m5.save(m5.darken(from_guide("cf_mouth"), WALL_DARK), CF + "gen_mouth.png")
    m5.save(prop("cf_cracked"), CF + "gen_cracked.png")
    m5.save(m5.darken(prop("cf_cart", colors=14), 0.85), CF + "gen_cart.png")

    m5.save(m5.darken(from_guide("ce_wall"), WALL_DARK), CE + "gen_wall.png")
    m5.save(ce_far(), CE + "gen_far.png")
    m5.save(prop("ce_rubble"), CE + "gen_rubble.png")

    m5.save(ss_wall(), SS + "gen_wall.png")
    m5.save(prop("ss_goods", plate=False), SS + "gen_goods.png")


def ss_wall():
    a = load("ss_wall_fix_fix")[: VH * 3]
    a = a.reshape(VH, 3, W, 3, 3).mean(axis=(1, 3))
    return cb.quantize(a, np.ones((VH, W), bool), 16, "octree")


# Вихід з печери: за гирлом — небо, хмари й гори дороги, прив'язані до світу (CaveExit [3,5] — на клітинку західніше
# Пустельної дороги [4,5]); у печері — глибини Печери під мостом (її низ: та сама печера)
SKY = B + "DesertOasis/bg4/plan5.png"
CLOUDS = B + "Canyon/gen_clouds.png"
MESAS = B + "Canyon/gen_far.png"
ROAD_X = -W
CE_SPLIT = 420  # одвірок гирла (ce_wall) — від ~350 під стелею до ~440 біля підлоги


def ce_far():
    desert = m5.compose(
        [
            (m5.img(SKY), 0.0, 0, 0, True),
            (m5.img(CLOUDS), 0.1, m5.sh(0.1, ROAD_X), 0, True),
            (m5.img(MESAS), 0.3, m5.sh(0.3, ROAD_X), 0, True),
        ],
        0,
    )
    depths = m5.img(B + "BridgeCave/gen_far.png")[648 - VH :]
    out = desert.copy()
    # межа — посередині одвірка гирла в кожному рядку (ліворуч від нього — глибини, праворуч — пустеля)
    solid, _ = masks("ce_wall")
    for y in range(VH):
        row = solid[min(y, GH - 1), CE_SPLIT - 100 :]
        x = CE_SPLIT - 100 + (int(np.argmax(row)) + 12 if row.any() else 100)
        out[y, :x] = depths[y, :x]
    return out


# --- розміщення (арт, кімната): (масив, множник, x якоря, y верху, тайл?, [передній?]) ----------------------------
CART_CAM = 700  # візок посередині кадру при цій камері
# скеля ×1.3 перетинає кадр посередині при цих камерах; далеко від тріщини (камера 0) і діри (камера ~1700)
FRONT_CAMS = (500, 1200)
FRONT_SINK = 108  # підніжжя скелі ~40 арту під кадром (як на Гірській стежці)


def cf_planes(cracked=True):
    cliff, mouth = m5.img(CF + "gen_cliff.png"), m5.img(CF + "gen_mouth.png")
    wall, cart = m5.img(CF + "gen_cracked.png"), m5.img(CF + "gen_cart.png")
    front = m5.img(B + "MountainPath/gen_front.png")
    plug = [
        (wall, 1.0, round(STASH_X - wall.shape[1] / 2), WALK + 2 - len(wall), False)
    ]
    return cf_back() + [
        (cart, 0.9, *m5.stand(cart, 0.9, 300, CART_CAM, sink=3), False),
        (cliff, 1.0, 0, 0, False),
        (mouth, 1.0, CF_W - W, 0, False),
        *(plug if cracked else []),
        (m5.img(CF + "gen_ground.png"), 1.0, 0, WALK, False),
        (
            front,
            1.3,
            *m5.stand(front, 1.3, 300, FRONT_CAMS[0], sink=FRONT_SINK),
            False,
            True,
        ),
        (
            front[:, ::-1].copy(),
            1.3,
            *m5.stand(front, 1.3, 300, FRONT_CAMS[1], sink=FRONT_SINK),
            False,
            True,
        ),
    ]


RUBBLE_X = sum(CE_PIT) / 2


FILL = np.full((320 - WALK, W, 4), (33, 26, 26, 255), np.uint8)  # Color(0.13, 0.1, 0.1) у CaveExit.tscn


def ce_planes():
    rubble = m5.img(CE + "gen_rubble.png")
    floor = m5.img(B + "LizardCave/gen_floor.png")
    return [
        (m5.img(CE + "gen_far.png"), 0.0, 0, 0, False),
        (m5.img(CE + "gen_wall.png"), 1.0, 0, 0, False),
        (
            rubble,
            1.0,
            round(RUBBLE_X - rubble.shape[1] / 2),
            WALK + 2 - rubble.shape[0],
            False,
        ),
        (FILL, 1.0, 0, WALK, False),  # Ground/Fill1 сцени під смугою підлоги
        (floor, 1.0, 0, WALK, True),
        (m5.img(B + "BridgeCave/gen_front.png"), 1.3, W - 245, 0, False, True),
    ]


# товар — між тунелем і намальованими мішками (на стіні вони праворуч, біля SecretArea_Stash: 560…720 світу)
GOODS_X = 330


def ss_planes():
    # передній план — сталактити Печери під мостом (та сама порода): 9701/9702 вішали на мотузці зашморг
    goods, front = m5.img(SS + "gen_goods.png"), m5.img(B + "BridgeCave/gen_front.png")
    return [
        (m5.img(SS + "gen_wall.png"), 0.0, 0, 0, False),
        (goods, 1.0, round(GOODS_X - len(goods[0]) / 2), WALK + 2 - len(goods), False),
        (front, 1.3, W - len(front[0]), 0, False, True),  # верхній правий кут: над товаром, далеко від тунелю
    ]


def sheet():
    hero = m5.img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    cp, ep, sp = cf_planes(), ce_planes(), ss_planes()
    frames = [
        (
            "Canyon Floor, west end (camera 0): the dead-end cliff, the smugglers' walled-up crack at x 300 world "
            "(the cracked wall, Wall_Stash's sprite) - the stash behind it",
            m5.compose(cp, 0, (330, hero)),
        ),
        (
            "Canyon Floor, west end after the wall is broken: the crack open (the painted passage, StashDoor)",
            m5.compose(cf_planes(cracked=False), 0, (330, hero)),
        ),
        (
            "Canyon Floor, camera 700: the abandoned cart x0.9, the rock front x1.3",
            m5.compose(cp, CART_CAM, (CART_CAM + 420, hero)),
        ),
        (
            "Canyon Floor, east end (camera 1728): the hole down into the lizard caves (x 2912-3104 world), the cave "
            "mouth into the Cave Exit",
            m5.compose(cp, 1728, (2120, hero)),
        ),
        (
            "Cave Exit (one screen): the pit from the Cave under the Bridge at x 90-225 world, the rubble and the broken "
            "rope ladder under it; west the tunnel to the canyon floor, east the mouth onto the Desert Road",
            m5.compose(ep, 0, (300, hero)),
        ),
        (
            "Smugglers' Stash (one screen): the hole broken through their wall (ExitDoor, x 423 world), their goods "
            "by the secret's spot, the lantern beam front",
            m5.compose(sp, 0, (180, hero)),
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
    out.save("design/shots/m6b6_canyon_floor.png")
    print("sheet", out.size, flush=True)


if __name__ == "__main__":
    {
        "gen": gen,
        "build": build,
        "sheet": sheet,
        "guide": lambda: [
            Image.fromarray(guide(n, 1)).save(raw(n + "_guide")) for n in GUIDES
        ],
    }[sys.argv[1]]()
