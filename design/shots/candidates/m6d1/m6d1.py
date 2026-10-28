"""M6d-1: бічні кімнати Лабораторії — Коридор алхіміка (AlchemistCorridor, 3 клітинки: сходи вниз на поверх 1
StairsDoor x 150, робочий стіл алхіміка з ключем x 1300, замкнені двері комори StoreDoor x 2450), Комора алхіміка
(AlchemistStore, 2 клітинки: ті самі двері зсередини ExitDoor x 150), Схованка Маліка (MalikStash, 2 клітинки: нора під
підлогою камер; отвір із відсунутою плитою і мотузкою вгору в камеру SlabDoor x 1450, таємниця x 700) і Обвалений
дренаж (CollapsedDrain, 7 клітинок: цегляний стік під Лабораторією; шахта зі скобами до люка в камери HatchDoor x 900,
шахта до ґрат у підлозі поверху 3 GrateDoor x 5750, скриня x 3000).
Усі кімнати — одна клітинка заввишки: лінія ходьби — рядок 256 арту (підлога y 384 світу). Підлога ціла, шахти й
мотузка стоять перед стіною (B201); нічого не висить у повітрі (A15).
  python -B design/shots/candidates/m6d1/m6d1.py gen     — ComfyUI (сирі PNG поруч; є — не кличе модель; ≤ 4 за запуск)
  python -B design/shots/candidates/m6d1/m6d1.py build   — плани в SampleProject/Assets/Backgrounds/...
  python -B design/shots/candidates/m6d1/m6d1.py sheet   — design/shots/m6d1_lab_rooms.png
  python -B design/shots/candidates/m6d1/m6d1.py wiring  — числа для сцен (світ)
Розміри — таблиця світу (D814): герой 64 арту, двері 112, людина 96, бочка 32; на плані f — round(h × f).
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
import m6b5 as m5  # scaled, compose, stand, at, save, img, free, darken — той самий конвеєр

D = os.path.dirname(os.path.abspath(__file__))
B = "SampleProject/Assets/Backgrounds/"
AC, AS, MS, DR = (
    B + "AlchemistCorridor/",
    B + "AlchemistStore/",
    B + "MalikStash/",
    B + "CollapsedDrain/",
)
W, VH, WALK = 576, 324, 256
STYLE = cb.STYLE
MAG = cb.MAGENTA
GREEN = "on a solid flat chroma key green (#00FF00) background"
FRONT = "seen straight on, flat orthographic front elevation, no perspective"
SIDE = "seen exactly from the side, flat orthographic side elevation, no perspective"
GROUP = "all in one group standing directly on the bottom edge of the frame, no floor, no wall, nothing behind them"
STONE = (
    "fitted dark violet-grey stone blocks"  # камінь Лабораторії (Lab/gen_far, gen_cell)
)

# тайли: (текст, рядки арту, зерно, ключ або None); генерація 1728 px завширшки (×3), шов — модель
TILES = {
    # 11001 — перспективний тунель із підлогою зліва, крупний план справа (шов); «corridor» модель малює вглиб.
    # 11002 — праворуч рівна стіна з нішами, але колба в ніші — на зріст героя (D814); ліворуч знову тунель
    "ac_wall": (
        f"a tall flat stone wall inside an alchemist's laboratory {FRONT}, no floor, no depth: {STONE}, three rows "
        "of small round-arched niches one above another, each niche small and shallow with a tiny wooden shelf "
        "holding a few tiny glass vials of glowing green and amber liquid, thin brass pipes with small valves "
        "running straight across the wall between the rows, small brass oil lamps on hooks with warm light, stone "
        "vault ribs along the top edge, spanning the full width, the wall filling the whole frame from the top "
        "edge to the bottom edge",
        324,
        11003,
        None,
    ),
    "as_wall": (
        f"the back wall of a cramped alchemist's storeroom {FRONT}: tall dark wooden shelves from the bottom edge up "
        "to a low stone vault at the top edge, packed with clay jars sealed with wax, glass bottles, small wooden "
        "boxes, bundles of dried herbs hanging from the shelves, coils of copper tubing, a few animal skulls, sacks "
        "on the lowest shelves, cobwebs in the corners, dim warm lamp light, no writing, no labels, spanning the "
        "full width, the shelves reaching the bottom edge, no floor visible, nothing standing in front of the shelves",
        324,
        11011,
        None,
    ),
    "ms_wall": (
        f"a cramped secret hollow dug under the stone floor of a prison {FRONT}: rough hewn rock walls, the big "
        "fitted stone foundation blocks of the cells above along the top edge, a low ceiling of heavy stone slabs "
        "resting on old wooden beams, small niches cut in the rock with stubs of tallow candles and warm flickering "
        "light, dark violet shadows, spanning the full width, the wall reaching the bottom edge, no floor visible, "
        "nothing standing in front of the wall",
        324,
        11021,
        None,
    ),
    "dr_far": (
        f"the far depths of a long collapsed brick drain tunnel deep under a laboratory {FRONT}: a round vault of "
        "old dark bricks, parts of it fallen in with heaps of broken bricks and stones, an old channel of murky "
        "water glowing faintly green along the bottom, rusted broken pipes along the walls dripping, hanging roots, "
        "deep violet and dark blue shadows, spanning the full width and filling the whole frame from the top edge "
        "to the bottom edge",
        324,
        11031,
        None,
    ),
    "dr_mid": (
        f"a row of thick old brick sewer arches on square brick piers {FRONT}, standing apart with wide empty gaps "
        "between them, some arches cracked and half fallen, heaps of fallen bricks at the feet of the piers, rusted "
        "iron pipes along the piers, hanging roots, each pier rising from the bottom edge to the top edge of the "
        f"frame, spanning the full width, {MAG} in every gap between the piers",
        256,
        11041,
        "magenta",
    ),
}

# предмети на хромакеї: (текст, ширина, висота генерації px, зерно); зелене скло й рідини — лише на пурпурі
PROPS = {
    # --- Коридор алхіміка (і комора: двері ті самі з обох боків)
    # 11102 («the top of a stairwell going down») — знову вгору, ще й другий темний прохід поруч; лишились 11101:
    # сходинки в арці піднімаються, хоч із коридору ведуть униз на поверх 1 — напрям модель не малює (у звіті)
    "ac_stairs": (
        f"an arched stone doorway in a short section of wall of {STONE} {FRONT}: a tall round-topped doorway, inside "
        "it narrow stone steps going steeply down into the depths, warm orange lamp light rising from below, the "
        "lower steps dark, a worn threshold on the bottom edge of the picture, only the doorway and the blocks "
        f"around it, standing alone, nothing behind it, {GREEN}",
        1024,
        1024,
        11101,
    ),
    "ac_door": (
        f"a heavy locked storeroom door {FRONT}: a tall narrow door of dark oak planks bound with three black iron "
        "bands with rivets, a big black iron lock plate with a keyhole, an iron ring handle, set in a doorway of "
        f"{STONE} with a flat lintel and a small brass plate above it, the threshold on the bottom edge of the "
        f"picture, only the door and its stone frame, standing alone, nothing behind it, no ground, {GREEN}",
        1024,
        1536,
        11111,
    ),
    # 11121, 11122 — стіл в ізометрії на плиті підлоги з кутом стіни (як m6c3 ar_desk), і «paper cut-out … edge-on»
    # не тримає; лишився 11122: 3/4 — як операційний стіл Lab/gen_table, задні ніжки — глибше на смузі підлоги
    "ac_desk": (
        "an alchemist's long wooden work table with an alembic of copper and glass on a small brass burner, a coiled "
        "glass tube dripping into a flask of amber liquid, round flasks of blue and red liquid, a mortar and pestle, "
        "a stack of old books and a burning candle standing on the table top, like a flat paper cut-out, seen "
        "exactly from the side at eye level, the table top seen edge-on as a thin straight plank, flat orthographic "
        "side elevation, no perspective, only two legs visible, its legs on the bottom edge of the frame, no floor "
        f"visible, no wall, nothing behind it, {MAG}",
        1536,
        1024,
        11122,
    ),
    "ac_vessel": (
        "a big round glass vessel the size of a man held in a riveted brass cage frame on three short legs, a heavy "
        "chain wrapped around it and locked, a small swirling flame of orange fire trapped inside the glass, brass "
        "pipes and a valve on its top, "
        f"{FRONT}, its legs on the bottom edge of the frame, standing alone, nothing behind it, no floor, {GREEN}",
        1024,
        1536,
        11131,
    ),
    "ac_cages": (
        "a wooden rack with small iron cages stacked on it, two rows, most of the cages empty with their doors open, "
        "one holding a small sleeping desert lizard, one holding a little glowing orange ember, a bowl of water, "
        f"{FRONT}, its feet on the bottom edge of the frame, standing alone, nothing behind it, no floor, {GREEN}",
        1536,
        1024,
        11141,
    ),
    "ac_front": (
        "a straight horizontal dark wooden beam along the very top edge of the picture from the left edge to the "
        "right edge, flat orthographic front elevation, no perspective, bundles of dried herbs, a string of dried "
        "roots and two small brass lanterns hanging from it on cords, nothing else, "
        f"{MAG}",
        1536,
        1024,
        11151,
    ),
    # --- Комора
    "as_barrels": (
        "two small wooden barrels, a big glass bottle in a wicker basket and a wooden crate of glass flasks packed "
        f"in straw, {SIDE}, {GROUP}, {MAG}",
        1536,
        768,
        11161,
    ),
    "as_parts": (  # 11171 — ізометрія на трав'яній плиті; скриню з замками вирізано (KEEP)
        "a spare big empty round glass vessel in a brass cage frame lying on a wooden cradle, a coil of copper pipe, "
        f"a heavy chain and two iron padlocks on top of a wooden crate, {SIDE}, {GROUP}, {GREEN}",
        1536,
        768,
        11171,
    ),
    # --- Схованка Маліка
    "ms_slab": (
        f"a narrow tall pillar of rough rock {FRONT} running from the top edge to the bottom edge of the picture, in "
        "its upper part a square hole in a low stone ceiling with a heavy flat stone floor slab pushed aside on its "
        "edge, pale light falling down through the hole, a thick knotted rope hanging from the hole straight down "
        "to the bottom edge, two wooden crates stacked under it, nothing else, "
        f"{GREEN}",
        768,
        1536,
        11181,
    ),
    "ms_hoard": (
        "a merchant's hidden hoard: rolled carpets tied with cord, bolts of silk cloth, a small iron-bound strongbox "
        "with a padlock, sacks of spices, a brass oil lamp, a brass hookah, a small golden statuette, a bedroll and "
        f"a water jug, {SIDE}, {GROUP}, {GREEN}",
        1536,
        768,
        11191,
    ),
    "ms_post": (
        "an old crooked wooden support post rising from the bottom edge to the top edge of the frame, a short "
        "crossbeam on its top, an iron hook with a small tin lantern on it, a frayed rope wound around it, "
        f"nothing else, {GREEN}",
        768,
        1536,
        11201,
    ),
    # --- Обвалений дренаж
    "dr_hatch": (
        f"a narrow vertical brick shaft seen in cross-section {FRONT}: a tall narrow slot in a pillar of old dark "
        "bricks running from the top edge to the bottom edge of the picture, inside the slot rusty iron rungs set "
        "into the back wall one above another from the bottom up to the top, a square wooden hatch with iron bands "
        f"closing the shaft at the top, a thin line of light around the hatch, {GREEN}",
        768,
        1536,
        11211,
    ),
    "dr_grate": (
        f"a narrow vertical brick shaft seen in cross-section {FRONT}: a tall narrow slot in a pillar of old dark "
        "bricks running from the top edge to the bottom edge of the picture, inside the slot rusty iron rungs set "
        "into the back wall one above another from the bottom up to the top, a rusty iron floor grate across the "
        "top of the shaft, warm lamp light falling down through the grate bars in stripes, "
        f"{MAG}",
        768,
        1536,
        11221,
    ),
    "dr_collapse": (
        "a big heap of fallen old bricks and broken stone blocks from a collapsed brick vault, a broken piece of "
        "the brick arch still standing on one side, a snapped rusty pipe sticking out of the heap, roots hanging "
        f"over it, {SIDE}, {GROUP}, {GREEN}",
        1536,
        1024,
        11231,
    ),
    "dr_pipe": (
        "a short section of old dark brick wall with a big broken brass pipe sticking out of it, a thick glowing "
        "green sludge pouring from the pipe into a stone basin at its foot, broken glass vials and a cracked flask "
        f"in the sludge, green stains down the bricks, {FRONT}, standing alone, nothing behind it, {MAG}",
        1024,
        1536,
        11241,
    ),
    # 11251 — ціле дерево зі стовбуром до землі, не звисле коріння; передній план дренажу — опора склепіння Акведука
    "dr_front": (
        "a mass of long tangled tree roots and a broken rusty iron pipe hanging down from the very top edge of the "
        "picture, hanging into empty space, a few drops of water, nothing else, "
        f"{MAG}",
        1536,
        1024,
        11251,
    ),
}


def raw(name):
    return os.path.join(D, f"m6d1_{name}_raw.png")


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
    im = cb.run(cb.graph(f"{text}, {STYLE}", seed, h, width=w))
    Image.fromarray(im.astype(np.uint8)).save(raw(name))
    print(name, flush=True)


ORDER = [  # коридор і комора спершу (не встигну — решта в списку)
    "ac_wall",
    "ac_stairs",
    "ac_door",
    "ac_desk",
    "ac_vessel",
    "ac_cages",
    "ac_front",
    "as_wall",
    "as_barrels",
    "as_parts",
    "ms_wall",
    "ms_slab",
    "ms_hoard",
    "ms_post",
    "dr_far",
    "dr_mid",
    "dr_hatch",
    "dr_grate",
    "dr_collapse",
    "dr_pipe",
    "dr_front",
]


def gen():
    todo = [n for n in ORDER if not os.path.exists(raw(n))]
    cost = 0
    while (
        todo and cost < 4
    ):  # ≤ 4 генерацій за запуск (ОЗП, skill comfy-backdrop); тайл — дві (шов)
        name = todo[0]
        if name in TILES and cost > 2:
            break
        todo.pop(0)
        (gen_tile if name in TILES else gen_prop)(name)
        cost += 2 if name in TILES else 1
    s = json.load(urllib.request.urlopen(cb.API + "/system_stats"))["system"]
    print("left", todo, "ram_free GB", round(s["ram_free"] / 2**30, 1))
    if not todo:
        m5.free()


# --- build --------------------------------------------------------------------------------------------------------
# два предмети з однієї сирої (різні KEEP)
SRC = {"ms_lamp": "ms_hoard"}
# латки на сирій: (y0, y1, x0, x1, dx) — прямокутник заливається пікселями зі зсуву dx; петля на кінці мотузки
# читалась зашморгом — на її місці камінь стовпа зліва, лишається вузол
PATCH = {"ms_slab": [(985, 1080, 355, 445, -90)]}


def load(name):
    im = np.asarray(Image.open(raw(SRC.get(name, name))).convert("RGB"), np.float32).copy()
    for y0, y1, x0, x1, dx in PATCH.get(name, ()):
        im[y0:y1, x0:x1] = im[y0:y1, x0 + dx : x1 + dx]
    return im


# що лишається від сирої (px генерації: y0, y1, x0, x1); низ — лінія ходьби (без підлоги, яку модель домальовує)
KEEP = {
    "ac_door": [(0, 1340, 110, 905)],  # поріг, трава й зелена цегла праворуч — геть (поріг — лінія ходьби)
    "ac_vessel": [(0, 1385, 0, 1024)],  # трава й фіолетова цегла під ніжками — геть
    "ac_cages": [(0, 905, 0, 1536)],  # плитка підлоги й цегла під стелажем — геть
    "ac_stairs": [(0, 865, 285, 740)],  # лицьова грань виступної плити, трава й стіна обабіч арки — геть
    "ac_desk": [(0, 800, 0, 1536), (800, 1005, 0, 1000)],  # тінь на підлозі (ключ) і кут цегли праворуч унизу — геть
    "as_barrels": [(0, 640, 0, 1536)],  # кам'яний бордюр під групою — геть
    # скриня з двома замками й ланцюгом читалась би нагородою (як m6c3 st_goods) — лишається посудина на ложі з трубою
    "as_parts": [(0, 760, 150, 610)],
    "ms_slab": [(0, 1440, 0, 768)],  # рядок плит підлоги під ящиками — геть
    # схованка — сама скарбниця; окута скринька з замком читалась би нагородою, а золота статуетка — ідолом чужої
    # віри: геть обидві. Лишаються килими з мішком (ліворуч) і лампа з кальяном на постелі (праворуч), без плити
    "ms_hoard": [(0, 642, 150, 543)],
    "ms_lamp": [(0, 650, 805, 1105)],
    "ms_post": [(0, 1385, 0, 768)],  # трава й камінь під стовпом — геть
    "dr_collapse": [(0, 870, 0, 1536)],  # трава й земля під купою — геть
    "dr_pipe": [(0, 1400, 0, 1024)],  # фіолетова підлога під басейном — геть (решту бере ключ)
}
# пройом на сирій, px генерації: (верх, поріг, x середини) — висота пройому стає дверима (D814: 112)
OPEN_PX = {"ac_door": (392, 1338, 508), "ac_stairs": (178, 862, 510)}
# x середини переходу на сирій (шахта, мотузка), px генерації — якір у сцені
CX_PX = {"ms_slab": 390, "dr_hatch": 390, "dr_grate": 385}  # мотузка; середина шахти
MIRROR = set()
# висота, арт (D814: герой 64, людина 96, двері 112, бочка 32)
SIZES = dict(
    ac_desk=99,  # стільниця на 42 арти над підлогою (0.75 м при людині 96 = 1.7 м): (998 − 600) px → 42
    ac_vessel=104,  # посудина «на зріст людини» (96) на ніжках — трохи вища
    ac_cages=80,  # стелаж у два яруси; клітка ~20 арту, ящірка ~10
    ac_front=90,  # балка з травами й ліхтарями, як балка архіву (ar_front)
    as_barrels=39,  # бочка — рівно 32 (430 px сирої з 527 групи)
    as_parts=64,  # запасна посудина без ніжок на ложі
    ms_slab=WALK + 2,  # від стелі (верх кадру) до лінії ходьби
    ms_hoard=58,  # мішок спецій ~0.5 м = 28 арту
    ms_lamp=38,
    ms_post=340,
    dr_hatch=WALK + 2,  # шахти — від верху кадру до лінії ходьби
    dr_grate=WALK + 2,
    dr_collapse=96,  # купа цегли з уламком арки — на зріст людини
    dr_pipe=110,  # уламок стіни з трубою над басейном  # передній стовп вищий за кадр, як опора Акведука (gen_front 340)
)


# де міряти колір тла (рядки, стовпці), якщо найрівніший з країв — не тло: угорі ms_slab стеля на всю ширину; у dr_pipe
# лівий край — суцільна цегла (ключ брав цеглу за тло й стіна зникала, труба висіла в повітрі)
BG_FROM = {"ms_slab": (slice(400, 1400), slice(0, 8)), "dr_pipe": (slice(None), slice(-8, None))}


def keyed(name):
    """Предмет на хромакеї (зелений чи пурпур): далеко від тла, без тіней кольору тла, у KEEP (як m6c3.keyed)."""
    from scipy import ndimage

    im = load(name)
    edges = [im[BG_FROM[name]]] if name in BG_FROM else [im[:8], im[:, :8], im[:, -8:]]
    bg = np.median(
        min((e.reshape(-1, 3) for e in edges), key=lambda e: e.std(0).sum()), axis=0
    )
    m = np.linalg.norm(im - bg, axis=2) > cb.KEY_DISTANCE
    if bg[1] > bg[0]:  # зелене тло: його тінь і відсвіт — теж зелені
        m &= im[..., 1] - np.maximum(im[..., 0], im[..., 2]) <= 10
        im[..., 1] = np.minimum(im[..., 1], np.maximum(im[..., 0], im[..., 2]) + 10)
    else:  # пурпур: темні пурпурні тіні
        m &= np.minimum(im[..., 0], im[..., 2]) - im[..., 1] < 60
    if name in KEEP:
        keep = np.zeros_like(m)
        for y0, y1, x0, x1 in KEEP[name]:
            keep[y0:y1, x0:x1] = True
        m &= keep
    m = ndimage.binary_opening(m, iterations=2)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    return im, np.isin(lab, 1 + np.nonzero(sizes >= sizes.max() * 0.02)[0])


def prop(name, colors=16):
    """(масив, x якоря в арті від лівого краю або None): висота з пройому (D814) чи SIZES; якір — середина пройому
    (OPEN_PX) чи переходу (CX_PX)."""
    im, m = keyed(name)
    if name in OPEN_PX:
        top, sill, cx = OPEN_PX[name]
    else:
        cx = CX_PX.get(name)
    if name in MIRROR:
        im, m = im[:, ::-1], m[:, ::-1]
        cx = None if cx is None else im.shape[1] - 1 - cx
    ys, xs = np.nonzero(m)
    h = (
        round((ys.max() - ys.min() + 1) * 112 / (sill - top))
        if name in OPEN_PX
        else SIZES[name]
    )
    a = m5.scaled(im, m, h, colors)
    return a, None if cx is None else (cx - xs.min()) * a.shape[1] / (
        xs.max() - xs.min() + 1
    )


# тайл із правого краю сирої + його дзеркало (шов — сам собою), завширшки 2 × (1728 − x) / 3 арту: у шві моделі
# напівпрозорі привиди полиць (as_wall, x 690…1010); x початку, px генерації (кратне 3)
MIRROR_TILE = {"as_wall": 1020, "ms_wall": 1236}  # ms_wall: посередині — темна арка-прохід, ліворуч ґрати (камера)


def tile(name, colors=16):
    im = load(name)
    if name in MIRROR_TILE:
        half = im[:, MIRROR_TILE[name] :]
        im = np.concatenate([half, half[:, ::-1]], axis=1)
    key = TILES[name][3]
    rgb, op = cb.shrink(im, key, spill=60 if key else 0)
    return cb.quantize(rgb, op, colors, "octree")


DESK_FOOT_PX, DESK_TOP_PX = 998, 540  # сира стола: низ передніх ніжок, середина стільниці (де лежить ключ)
WALL_DARK = 0.8  # стіни приміщень ×0.85 — темніші за предмети перед ними (як Схованка в цистерні)
MS_DARK = 0.65  # нора Маліка темніша: дзеркальний тайл (симетричні брили) — тихіше
FAR_DARK, MID_DARK = 0.5, 0.55  # глибина підземелля (Цистерна: 0.5 / 0.75; цегляна аркада яскравіша за колони)
SLAB_DARK = 0.85  # стовп під отвором освітлений згори й світлий — трохи в тон нори


def build():
    for d in (AC, AS, MS, DR):
        os.makedirs(d, exist_ok=True)
    have = lambda *ns: all(os.path.exists(raw(SRC.get(n, n))) for n in ns)  # noqa: E731
    if have("ac_wall"):
        m5.save(m5.darken(tile("ac_wall")[:VH], WALL_DARK), AC + "gen_wall.png")
    for n in ("ac_stairs", "ac_door", "ac_desk", "ac_vessel", "ac_cages", "ac_front"):
        if have(n):
            m5.save(prop(n)[0], AC + f"gen_{n[3:]}.png")
    if have("as_wall"):
        m5.save(m5.darken(tile("as_wall")[:VH], WALL_DARK), AS + "gen_wall.png")
    for n in ("as_barrels", "as_parts"):
        if have(n):
            m5.save(prop(n)[0], AS + f"gen_{n[3:]}.png")
    if have("ms_wall"):
        m5.save(m5.darken(tile("ms_wall")[:VH], MS_DARK), MS + "gen_wall.png")
    for n in ("ms_slab", "ms_hoard", "ms_lamp", "ms_post"):
        if have(n):
            a = prop(n)[0]
            m5.save(m5.darken(a, SLAB_DARK) if n == "ms_slab" else a, MS + f"gen_{n[3:]}.png")
    if have("dr_far"):
        m5.save(m5.darken(tile("dr_far")[:VH], FAR_DARK), DR + "gen_far.png")
    if have("dr_mid"):
        m5.save(m5.darken(tile("dr_mid"), MID_DARK), DR + "gen_mid.png")
    for n in ("dr_hatch", "dr_grate", "dr_collapse", "dr_pipe"):
        if have(n):
            m5.save(prop(n)[0], DR + f"gen_{n[3:]}.png")
    for n in (*OPEN_PX, *CX_PX):
        if have(n):
            print(f"{n}: anchor {prop(n)[1]:.1f} art from the left edge")


# --- розміщення (арт, кімната): (масив, множник, x якоря, y верху, тайл?, [передній?]) ----------------------------
SLAB = B + "Lab/gen_slab.png"  # підлога Лабораторії (Floor1 коридору й комори)
CELLAR_FLOOR = B + "Cellar/gen_floor.png"  # плити підвалу (Floor1 дренажу; схованки — замість решітки Лабораторії)
STAIRS_X, DESK_X, STORE_X = 150 / 1.5, 1300 / 1.5, 2450 / 1.5  # AlchemistCorridor: StairsDoor, Table, StoreDoor
AS_DOOR_X = 150 / 1.5  # AlchemistStore/ExitDoor
SLAB_X, MS_SECRET_X = 1450 / 1.5, 700 / 1.5  # MalikStash/SlabDoor (Arrival), SecretArea_Stash
HATCH_X, GRATE_X, CHEST_X = 900 / 1.5, 5750 / 1.5, 3000 / 1.5  # CollapsedDrain/HatchDoor, GrateDoor, Chest_Drain
FILL1 = np.zeros((48, 4032, 4), np.uint8)
FILL1[...] = (31, 26, 26, 255)  # Ground/Fill1 сцени (408…480 світу) — під смугою плит у 45 рядків


def near(a, f, x):
    """Предмет плану f — центром на екрані тоді, коли герой стоїть на x арту кімнати (камера x − 288)."""
    return m5.stand(a, f, 288, x - 288)


def front(a, f, x, top=-8):
    return (a, f, round(288 + f * (x - 288) - a.shape[1] / 2), top, False, True)


def door(path, name, x):
    a, ax = m5.img(path), prop(name)[1]
    return (a, 1.0, round(x - ax), WALK + 1 - len(a), False)


def ac_planes():
    desk, vessel, cages, fr = (m5.img(AC + f"gen_{n}.png") for n in ("desk", "vessel", "cages", "front"))
    return [
        (m5.img(AC + "gen_wall.png"), 0.85, 0, 0, True),
        (vessel, 0.95, *near(vessel, 0.95, 470), False),
        (cages, 0.95, *near(cages, 0.95, 1260), False),
        door(AC + "gen_stairs.png", "ac_stairs", STAIRS_X),
        (desk, 1.0, *m5.at(desk, DESK_X), False),
        door(AC + "gen_door.png", "ac_door", STORE_X),
        (m5.img(SLAB), 1.0, 0, WALK, True),
        front(fr, 1.3, 640),
        front(fr, 1.3, 1080),
    ]


def as_planes():
    barrels, parts = m5.img(AS + "gen_barrels.png"), m5.img(AS + "gen_parts.png")
    return [
        (m5.img(AS + "gen_wall.png"), 0.85, 0, 0, True),
        (barrels, 0.95, *near(barrels, 0.95, 360), False),
        (parts, 0.95, *near(parts, 0.95, 860), False),
        door(AC + "gen_door.png", "ac_door", AS_DOOR_X),
        (m5.img(SLAB), 1.0, 0, WALK, True),
        front(m5.img(AC + "gen_front.png"), 1.3, 600),
    ]


def ms_planes():
    hoard, lamp, post = (m5.img(MS + f"gen_{n}.png") for n in ("hoard", "lamp", "post"))
    sl, sx = m5.img(MS + "gen_slab.png"), prop("ms_slab")[1]
    return [
        (m5.img(MS + "gen_wall.png"), 0.85, 0, 0, True),
        (hoard, 0.95, *near(hoard, 0.95, 150), False),
        (lamp, 0.95, *near(lamp, 0.95, 250), False),
        (sl, 1.0, round(SLAB_X - sx), WALK + 2 - len(sl), False),
        (m5.img(CELLAR_FLOOR), 1.0, 0, WALK, False),
        (FILL1[:, :1152], 1.0, 0, 272, False),
        (post, 1.3, *m5.stand(post, 1.3, 288, 290, sink=40), False, True),
    ]


def dr_planes():
    coll, pipe = m5.img(DR + "gen_collapse.png"), m5.img(DR + "gen_pipe.png")
    pier = m5.img(B + "Aqueduct/gen_front.png")
    hatch, hx = m5.img(DR + "gen_hatch.png"), prop("dr_hatch")[1]
    grate, gx = m5.img(DR + "gen_grate.png"), prop("dr_grate")[1]
    return [
        (m5.img(DR + "gen_far.png"), 0.45, 0, 0, True),
        (m5.img(DR + "gen_mid.png"), 0.75, 0, WALK + 2 - VH + 68, True),
        (pipe, 0.9, *near(pipe, 0.9, 2560), False),
        (coll, 1.0, *m5.at(coll, 1420), False),
        (coll[:, ::-1], 1.0, *m5.at(coll, 3150), False),
        (hatch, 1.0, round(HATCH_X - hx), WALK + 2 - len(hatch), False),
        (grate, 1.0, round(GRATE_X - gx), WALK + 2 - len(grate), False),
        (m5.img(CELLAR_FLOOR), 1.0, 0, WALK, True),
        (FILL1, 1.0, 0, 272, False),
        *[(pier, 1.3, *m5.stand(pier, 1.3, 288, c, sink=40), False, True) for c in (750, 1850, 3000)],
    ]


def sheet():
    hero = m5.img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    ac, st, ms, dr = ac_planes(), as_planes(), ms_planes(), dr_planes()
    frames = [
        ("Alchemist's Corridor, west end (camera 0): the stairs down to floor 1 - StairsDoor x 150 world; the djinn "
         "vessel x0.95; shelves of vials x0.85", m5.compose(ac, 0, (STAIRS_X + 50, hero))),
        ("Alchemist's Corridor, camera 580: the alchemist's work table - Table x 1300, the key lies on it; the beam "
         "with herbs front x1.3", m5.compose(ac, 580, (DESK_X - 70, hero))),
        ("Alchemist's Corridor, east end (camera 1152): cages on a rack x0.95; the storeroom's locked door - "
         "StoreDoor x 2450", m5.compose(ac, 1152, (STORE_X - 60, hero))),
        ("Alchemist's Storeroom, west end (camera 0): the same door from inside - ExitDoor x 150; barrels, a carboy, "
         "flasks in straw x0.95", m5.compose(st, 0, (AS_DOOR_X + 50, hero))),
        ("Alchemist's Storeroom, east end (camera 576): the spare djinn vessel on its cradle with a copper pipe x0.95",
         m5.compose(st, 576, (780, hero))),
        ("Malik's Stash, west end (camera 0): his hoard x0.95; SecretArea_Stash x 700",
         m5.compose(ms, 0, (MS_SECRET_X, hero))),
        ("Malik's Stash, east end (camera 576, the Arrival): the hole of the moved slab, the rope up into his cell - "
         "SlabDoor x 1450", m5.compose(ms, 576, (SLAB_X - 50, hero))),
        ("Collapsed Drain, the Arrival (camera 312): the shaft up to the hatch into the cells - HatchDoor x 900",
         m5.compose(dr, 312, (HATCH_X + 50, hero))),
        ("Collapsed Drain, camera 1150: the collapse x1.0", m5.compose(dr, 1150, (1300, hero))),
        ("Collapsed Drain, camera 1712: Chest_Drain x 3000 (not drawn), the floor clear",
         m5.compose(dr, 1712, (CHEST_X - 60, hero))),
        ("Collapsed Drain, camera 2272: the broken pipe pouring the lab's green waste x0.9",
         m5.compose(dr, 2272, (2500, hero))),
        ("Collapsed Drain, east end (camera 3456): the shaft up to the grate in floor 3 - GrateDoor x 5750",
         m5.compose(dr, 3456, (GRATE_X - 60, hero))),
    ]
    lab, gap = 28, 12
    out = Image.new("RGB", (1920, len(frames) * (1080 + lab + gap)), (24, 22, 28))
    d = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    y = 0
    for title, v in frames:
        out.paste(Image.fromarray(v[..., :3]).resize((1920, 1080), Image.NEAREST), (0, y + lab))
        d.text((6, y + 8), title, fill=(235, 225, 200), font=font)
        y += 1080 + lab + gap
    out.save("design/shots/m6d1_lab_rooms.png")
    print("sheet", out.size, flush=True)


def wiring():
    """Числа для сцен (світ = арт × 1.5): позиції спрайтів у своїх Parallax2D (scroll_offset 0)."""
    for room, planes in (
        ("AlchemistCorridor", ac_planes()),
        ("AlchemistStore", as_planes()),
        ("MalikStash", ms_planes()),
        ("CollapsedDrain", dr_planes()),
    ):
        print(room)
        for a, f, x, y, rep, *fr in planes:
            print(
                f"  f {f:<4} size {a.shape[1]}x{a.shape[0]}  pos ({x * 1.5:g}, {y * 1.5:g})"
                + ("  tile" if rep else "")
                + ("  front" if fr else "")
            )
    desk = m5.img(AC + "gen_desk.png")
    top = (DESK_FOOT_PX - DESK_TOP_PX) * desk.shape[0] / (DESK_FOOT_PX - keyed("ac_desk")[1].nonzero()[0].min())
    print(f"Table: size {desk.shape[1]}x{desk.shape[0]}, the middle of its top {top:.0f} art over the floor -> "
          f"Pickup_AlchemistKey y {384 - top * 1.5:.0f} world")


if __name__ == "__main__":
    {"gen": gen, "build": build, "sheet": sheet, "wiring": wiring}[sys.argv[1]]()
