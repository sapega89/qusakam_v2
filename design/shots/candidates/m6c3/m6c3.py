"""M6c-3: останні кімнати Міста — Архів мера (MayorArchive, 1 клітинка над Мейор-холом: шафи сувоїв і книг обліку,
мапа імперії з куполами бар'єрів, стіл мера; двері-шафа BookshelfDoor x 200), Цистерна під ринком (Cistern,
3 клітинки: ліс колон у зеленій воді, той самий старий водогін, що Акведук; ґрати в підвал брами CellarDoor x 140 з
важелем x 290, шахта криниці WellDoor x 1700 — залізні скоби вгору до денного світла, тріснута стіна до схованки
StashDoor/Wall_Stash x 2300 у торцевій стіні) і Схованка в цистерні (CisternStash, 2 клітинки: суха комора при
цистерні із запечатаними глеками води; пролом назад ExitDoor x 200, таємниця x 1100). Плюс три кінці переходів у
Місті, що були на заглушках: City/RooftopsDoor x 880 (драбина на стіні будинку), City/TavernAtticDoor x 2450 (драбина
за прилавком), CityGates/RooftopsDoor x 638 (сцена; не 300) — мотузка з дахів по контрфорсу муру, кінець у бухті.
Усі кімнати — одна клітинка заввишки: лінія ходьби — рядок 256 арту (підлога y 384 світу). Підлога ціла, драбини й
скоби стоять перед стіною (B201); нічого не висить у повітрі (A15).
  python -B design/shots/candidates/m6c3/m6c3.py gen     — ComfyUI (сирі PNG поруч; є — не кличе модель; ≤ 4 за запуск)
  python -B design/shots/candidates/m6c3/m6c3.py build   — плани в SampleProject/Assets/Backgrounds/...
  python -B design/shots/candidates/m6c3/m6c3.py sheet   — design/shots/m6c3_archive_cistern.png
  python -B design/shots/candidates/m6c3/m6c3.py wiring  — числа для сцен (світ)
Розміри — таблиця світу (D814): герой 64 арту, двері 112, ґрати 128, людина 96, бочка 32; на плані f — round(h × f).
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
import m6b5 as m5  # scaled, compose, stand, at, save, img, free, sh, darken — той самий конвеєр

D = os.path.dirname(os.path.abspath(__file__))
B = "SampleProject/Assets/Backgrounds/"
AR, CI, ST = B + "MayorArchive/", B + "Cistern/", B + "CisternStash/"
CITY, GATES, AQ = B + "City/", B + "Gates/", B + "Aqueduct/"
W, VH, WALK = 576, 324, 256
STYLE = cb.STYLE
MAG = cb.MAGENTA
GREEN = "on a solid flat chroma key green (#00FF00) background"
FRONT = "seen straight on, flat orthographic front elevation, no perspective"
FLAT = (
    "like a flat paper cut-out, flat orthographic front elevation, no perspective, only its front face visible, "
    "no top visible, no side visible"
)
SIDE = "seen exactly from the side, flat orthographic side elevation, no perspective"
SOLO = f"standing alone, nothing behind it, no people, warm light on the top, cool violet shadows, {GREEN}"
GROUP = "all in one group standing directly on the bottom edge of the frame, no floor, no wall, nothing behind them"

# тайли: (текст, рядки арту, зерно, ключ або None); генерація 1728 px завширшки (×3), шов — модель
TILES = {
    "ci_far": (
        f"the far depths of a vast ancient underground cistern under a desert city {FRONT}: several rows of slender "
        "stone columns with carved capitals holding low round arches of thin bricks, one row behind another, the "
        "further rows darker, all standing in still dark green water with their reflections, a few thin pale shafts "
        "of light from small round holes in the vault, deep violet and dark blue shadows, warm sandstone where the "
        "light falls, spanning the full width and filling the whole frame from the top edge to the bottom edge",
        324,
        10401,
        None,
    ),
    "ci_mid": (
        f"a row of thick round ancient stone columns with carved capitals and square bases {FRONT}, standing apart "
        "with wide empty gaps between them, each column rising from the bottom edge to the top edge of the frame, "
        "their feet in a strip of still murky green water along the bottom edge, old dark water lines high on the "
        "columns from when the cistern was full, green slime and stains at their feet, spanning the full width, "
        f"{MAG} in every gap between the columns",
        256,
        10411,
        "magenta",
    ),
    "st_wall": (
        f"the inside of a small dry vaulted stone storeroom beside an old city cistern {FRONT}: low round arches of "
        "fitted sandstone blocks along the back wall, dry empty niches, old dark water lines high on the stones from "
        "when it was flooded, a dry stone water channel along the wall, thin roots hanging through the joints, "
        "cobwebs, dim light, spanning the full width, the wall reaching the bottom edge, no floor visible, nothing "
        "standing in front of the wall",
        324,
        10421,
        None,
    ),
}

# предмети на хромакеї: (текст, ширина, висота генерації px, зерно)
PROPS = {
    # --- Архів мера
    # 10431 — ізометрія: шафа відсунута, зелена стіна з травою; зсередини архіву двері — зворот шафи
    "ar_door": (
        f"the back side of a secret bookcase door {FRONT}: a tall narrow panel of rough dark wooden planks with two "
        "big iron strap hinges on the left and an iron ring handle on the right, set in a carved sandstone doorway "
        "frame with a flat lintel, the threshold on the bottom edge, only the door and its stone frame, no wall "
        f"around it, no grass, no ground, standing alone, nothing behind it, {MAG}",
        1024,
        1536,
        10432,
    ),
    "ar_map": (
        f"a big old parchment map pinned to a wooden board on a tall wooden easel {FRONT}: a desert land ringed by "
        "mountains and sea drawn in brown ink, small round marks for towns and oases, three pale blue glowing domes "
        "painted over three small villages, no writing, no letters, the easel's legs on the bottom edge, standing "
        f"alone, nothing behind it, {MAG}",
        1024,
        1536,
        10441,
    ),
    # 10451, 10452 — стіл у ізометрії на плиті підлоги (двічі, і «paper cut-out» не тримає); пюпітр — простий силует
    "ar_lectern": (
        "a tall carved dark wooden reading lectern with a big open ledger on its slanted top, a brass candlestick "
        "with a lit candle beside the book, a few rolled scrolls tied with red cord stacked at its foot, like a "
        "flat paper cut-out, seen exactly from the side at eye level, flat orthographic side elevation, no "
        "perspective, its foot on the bottom edge of the frame, no floor visible, no wall, nothing behind it, "
        f"{MAG}",
        1024,
        1536,
        10453,
    ),
    # 10461 — балка в перспективі, навскіс
    "ar_front": (
        "a straight horizontal dark carved wooden beam along the very top edge of the picture from the left edge to "
        "the right edge, flat orthographic front elevation, no perspective, a brass oil lamp hanging from its middle "
        f"on a short chain, a red silk tassel under the lamp, nothing else, {GREEN}",
        1024,
        1024,
        10462,
    ),
    # --- Цистерна
    "ci_well": (
        f"a narrow vertical stone well shaft seen in cross-section {FRONT}: a tall narrow slot in a pillar of fitted "
        "sandstone blocks running from the top edge to the bottom edge of the picture, inside the slot iron rungs "
        "set into the back stone one above another from the bottom up to the top, pale daylight falling down from "
        "above, an old rope with a wooden bucket hanging down the middle of the shaft, a small puddle at its foot, "
        f"{MAG}",
        768,
        1536,
        10471,
    ),
    "ci_end": (
        f"a massive wall of big fitted ancient sandstone blocks {FRONT}, filling the right two thirds of the picture "
        "from the top edge to the bottom edge, its left side a straight vertical edge of big corner blocks, old dark "
        "water lines and green stains on the stones, in the middle of the wall at the bottom a ragged hole broken "
        "through the blocks, the height of a doorway, pitch dark behind it, a few fallen blocks beside it, "
        f"{MAG} on the left",
        1024,
        1536,
        10481,
    ),
    # 10491 — стіна з проломом посередині (не латка): «walled into a broken hole» модель читає як дірку
    "ci_cracked": (
        "a solid section of an old wall of fitted sandstone blocks with no hole and no opening, the blocks split by "
        "one big jagged crack running from the top to the bottom with smaller cracks branching off it, a few blocks "
        "bulging out and loose, dark damp stains, its outline ragged and irregular like a broken-off piece, seen "
        f"straight on, flat, nothing behind it, no floor, {MAG}",
        768,
        1024,
        10492,
    ),
    "ci_dragon": (
        "a huge carved stone dragon head lying on its side on the ground, used as the base of a thick round stone "
        "column that rises from the top of the head to the top edge of the picture, the dragon's horns, scales and "
        f"open jaws carved in old sandstone, green water stains and slime, {SIDE}, {MAG}",
        1024,
        1536,
        10501,
    ),
    # --- Схованка
    "st_hole": (
        f"a ragged hole broken through a wall of fitted sandstone blocks {FRONT}, the height of a doorway, through "
        "it darkness and the faint glimmer of water in a cistern, broken blocks around its edges, its bottom on the "
        f"bottom edge of the picture, only the hole and the blocks around it, {MAG}",
        1024,
        1024,
        10511,
    ),
    "st_jars": (
        "a row of big old clay water jars sealed with cloth and wax and tied with rope, standing side by side, two "
        f"jars lying on their sides, a wooden ladle, a big copper pot, {SIDE}, {GROUP}, {MAG}",
        1536,
        768,
        10521,
    ),
    # 10531, 10532 — скринька з навісним замком (читалася б скринею-нагородою; «no chest» при cfg 1 її й малює)
    "st_goods": (
        "a stack of three wooden crates, rolled carpets tied with cord lying on top of them, two burlap sacks leaning "
        f"against them and a coil of rope, {SIDE}, {GROUP}, {MAG}",
        1536,
        768,
        10533,
    ),
    # --- кінці переходів у Місті й біля брами
    # 10541 — драбина лише до половини стіни (до віконця), веде в нікуди; пісок і місто внизу
    "cy_ladder": (
        f"the narrow blank side wall of a tall plastered sandstone house in a desert city {FRONT}, a small shuttered "
        "window, a few round wooden beam ends, a low parapet at the top edge of the picture, and one long plain "
        "wooden ladder standing upright against the wall, its feet on the bottom edge and its top reaching all the "
        "way up to the parapet at the top edge, the ladder as tall as the whole wall, no ground, no sand, nothing "
        f"else, {SOLO}",
        1024,
        1536,
        10542,
    ),
    # 10551, 10561 — ізометрія (стіна з верхом і боком, прилавок у 3/4; вежа з боком, трава, чоловічок); «paper
    # cut-out … no top/side visible» тримало ga_pump і ga_ruins m6b5
    "cy_stall": (
        "a small market stall standing against a plastered sandstone house wall, "
        f"{FLAT}: a wooden counter with baskets of dates, oranges and red spices, a red and cream striped cloth "
        "awning hanging flat above it on two poles, and right of the stall one long plain wooden ladder standing "
        "upright against the wall, the wall and the ladder rising to the top edge of the picture, the counter on "
        f"the bottom edge, no ground, nothing else, {GREEN}",
        1536,
        1536,
        10552,
    ),
    "gt_rope": (
        f"the front face of a tall square sandstone buttress of a city wall, {FLAT}, a row of square battlements "
        "along its top, a thick rope tied around one merlon and hanging straight down the middle of the face, its "
        "loose end lying in a coil at the foot, standing alone, nothing behind it, no grass, no ground, no people, "
        f"{GREEN}",
        768,
        1536,
        10562,
    ),
}
# одна сцена на весь екран, без шва (кімната — один екран, камера стоїть)
SCREENS = {
    "ar_wall": (
        f"the inside of a mayor's private archive in a sandstone palace {FRONT}: tall dark wooden shelves from the "
        "floor to the ceiling against the wall, packed with rolled scrolls in cubbyholes, stacks of bound ledgers "
        "and leather document cases, a carved sandstone frieze along the top with a plain golden disc with a raised "
        "rim in its middle, two long red banners hanging between the shelves, a small high arched window with a "
        "carved stone lattice, warm candle light and cool violet shadows, the wall and the shelves reaching down to "
        "the bottom edge, nothing standing in front of the shelves, no furniture, no floor visible",
        10571,
    ),
}


def raw(name):
    return os.path.join(D, f"m6c3_{name}_raw.png")


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


def gen_screen(name):
    text, seed = SCREENS[name]
    im = cb.run(cb.graph(f"{text}, {STYLE}", seed, 976))
    Image.fromarray(im.astype(np.uint8)).save(raw(name))
    print(name, flush=True)


def gen():
    todo = [n for n in [*PROPS, *SCREENS, *TILES] if not os.path.exists(raw(n))]
    cost = 0
    while (
        todo and cost < 4
    ):  # ≤ 4 генерацій за запуск (ОЗП, skill comfy-backdrop); тайл — дві (шов)
        name = todo[0]
        if name in TILES and cost > 2:
            break
        todo.pop(0)
        (gen_tile if name in TILES else gen_screen if name in SCREENS else gen_prop)(
            name
        )
        cost += 2 if name in TILES else 1
    s = json.load(urllib.request.urlopen(cb.API + "/system_stats"))["system"]
    print("left", todo, "ram_free GB", round(s["ram_free"] / 2**30, 1))
    if not todo:
        m5.free()


# --- build --------------------------------------------------------------------------------------------------------
def load(name):
    return np.asarray(Image.open(raw(name)).convert("RGB"), np.float32)


# що лишається від сирої (px генерації: y0, y1, x0, x1); низ — лінія ходьби (без підлоги, яку модель домальовує)
KEEP = {
    "ar_map": [(0, 1445, 100, 900)],  # тінь мольберта ліворуч — геть
    "ci_well": [(0, 1385, 160, 605)],  # калюжа й пісок під стовпом — геть
    "ci_end": [
        (0, 1370, 0, 1024)
    ],  # плита підлоги під стіною — геть (поріг пролому — лінія ходьби)
    "ci_dragon": [(0, 1300, 0, 1024)],  # плита з калюжею — геть
    "ar_door": [(0, 1308, 110, 900)],  # трава, поріг і рожева цегла обабіч рами — геть
    "st_hole": [(0, 815, 0, 1024)],  # плити підлоги під проломом — геть
    "ci_cracked": [(0, 885, 0, 768)],  # плита підлоги — геть
    "st_jars": [(0, 605, 0, 1536)],  # кам'яна полиця під глеками — геть
    "cy_ladder": [(0, 1405, 150, 830)],  # пісок під будинком — геть
    "st_goods": [(0, 690, 0, 1536)],  # плити підлоги — геть
    "cy_stall": [(0, 1338, 200, 1300)],  # трава й тінь праворуч — геть
    "gt_rope": [(0, 1150, 0, 650), (1150, 1400, 0, 700)],  # трава і темний мур праворуч за контрфорсом — геть
}
# пролом схованки — у прямокутнику стіни на весь кадр: лишається еліпс довкола нього (x, y середини, півосі, px
# генерації) і низ від base_y на всю ширину, щоб край латки не був прямокутником
OVAL = {"st_hole": (478, 520, 400, 430, 700)}
# прозоре скло лампи — зелене від тла, ключ його з'їдав (лампа висіла б окремо від ланцюжка): еліпси (x, y, півосі,
# px генерації), де предмет непрозорий примусово (колір уже без зеленого відсвіту)
SOLID = {"ar_front": [(513, 500, 27, 40), (515, 592, 60, 55)]}
# стіна на весь кадр, тла немає (найрівніший край — самі блоки): без ключа, лише KEEP і OVAL
NOKEY = {"st_hole"}
# пройом на сирій, px генерації: (верх, поріг, x середини) — висота пройому стає дверима (D814: 112)
OPEN_PX = {"ci_end": (1005, 1370, 452), "ar_door": (379, 1305, 512), "st_hole": (245, 813, 478)}
# сира дзеркально (стіна намальована ліворуч, а торець Цистерни — праворуч; рівний край кутових блоків — до кімнати)
MIRROR = {"ci_end", "ar_front"}  # балка архіву — з правого краю, далі від дверей
# торцева стіна закінчується за 139 арту праворуч від пролому (1672 < 1728): кут закриває завал Акведука
# (Aqueduct/gen_rubble.png, 102×258) — дзеркальна смуга давала симетричні візерунки (sheet v1)
RUBBLE_X = 1636  # впритул до торця (1425…1645), за східний край 1728 на 10 арту
# x середини переходу на сирій (драбина, шахта, мотузка), px генерації — якір у сцені
CX_PX = {"ci_well": 388, "cy_ladder": 650, "cy_stall": 1105, "gt_rope": 381}
# висота, арт (D814: герой 64, людина 96, двері 112, бочка 32)
SIZES = dict(
    ar_map=86,  # мольберт із мапою — у зріст людини без голови (96 × 0.9)
    ar_lectern=68,  # пюпітр 1.2 м (людина 96 = 1.7 м) з книгою обліку
    ar_front=90,
    ci_well=WALK + 2,  # шахта від верху кадру до лінії ходьби (+2 під нею)
    ci_cracked=124,  # пройом 112 + 6 над ним + 2 під лінією ходьби, як gen_cracked Дна каньйону
    ci_dragon=200,  # верх колони — під смугою стелі (рядки 0…96); голова дракона ~85 — як людина
    st_jars=40,  # великий глек — трохи вищий за бочку (32)
    st_goods=60,  # ящики в два ряди, скриня, килими
    cy_ladder=WALK + 2,  # стіна будинку й драбина — вище кадру (дахи — клітинка вище)
    cy_stall=WALK + 2,
    gt_rope=230,  # контрфорс муру із зубцями: вище за мур брами ×0.7
)


def keyed(name):
    """Предмет на хромакеї (зелений чи пурпур): далеко від тла, без тіней кольору тла, у KEEP (як m6c2.keyed)."""
    from scipy import ndimage

    im = load(name)
    edges = [im[:8], im[:, :8], im[:, -8:]]
    bg = np.median(
        min((e.reshape(-1, 3) for e in edges), key=lambda e: e.std(0).sum()), axis=0
    )
    m = np.linalg.norm(im - bg, axis=2) > cb.KEY_DISTANCE
    if name in NOKEY:
        m[:] = True
    elif bg[1] > bg[0]:  # зелене тло: його тінь і відсвіт — теж зелені
        m &= im[..., 1] - np.maximum(im[..., 0], im[..., 2]) <= 10
        im[..., 1] = np.minimum(im[..., 1], np.maximum(im[..., 0], im[..., 2]) + 10)
    else:  # пурпур: темні пурпурні тіні
        m &= np.minimum(im[..., 0], im[..., 2]) - im[..., 1] < 60
    if name in KEEP:
        keep = np.zeros_like(m)
        for y0, y1, x0, x1 in KEEP[name]:
            keep[y0:y1, x0:x1] = True
        m &= keep
    for cx, cy, rx, ry in SOLID.get(name, ()):
        yy, xx = np.mgrid[: m.shape[0], : m.shape[1]]
        m |= ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1
    if name in OVAL:
        cx, cy, rx, ry, base = OVAL[name]
        yy, xx = np.mgrid[: m.shape[0], : m.shape[1]]
        m &= (((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1) | (
            (yy >= base) & (abs(xx - cx) <= rx)
        )
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


def tile(name, haze=0.0, colors=16):
    im = load(name)
    key = TILES[name][3]
    rgb, op = cb.shrink(im, key, spill=60 if key else 0)
    rgb = rgb * (1 - haze) + cb.HAZE * haze
    return cb.quantize(rgb, op, colors, "octree")


HOLE_DARK = 0.85  # пролом схованки — у тон стіни (×0.85, 0.8), трохи світліший: він ближче
FAR_DARK, MID_DARK, WALL_DARK = (
    0.5,
    0.75,
    0.8,
)  # глибина підземелля (як Акведук: far 0.5, опори 0.7)


def build():
    for d in (AR, CI, ST):
        os.makedirs(d, exist_ok=True)
    # Архів мера
    w = cb.shrink(load("ar_wall"), None)[0][:VH]
    m5.save(cb.quantize(w, np.ones((VH, W), bool), 16, "octree"), AR + "gen_wall.png")
    for n in ("ar_door", "ar_map", "ar_lectern", "ar_front"):
        m5.save(prop(n)[0], AR + f"gen_{n[3:]}.png")
    # Цистерна
    m5.save(m5.darken(tile("ci_far")[:VH], FAR_DARK), CI + "gen_far.png")
    m5.save(m5.darken(tile("ci_mid"), MID_DARK), CI + "gen_columns.png")
    m5.save(m5.darken(prop("ci_dragon")[0], MID_DARK), CI + "gen_dragon.png")
    m5.save(prop("ci_well")[0], CI + "gen_well.png")
    end = prop("ci_end")[0]
    end = end[max(0, len(end) - WALK - 2) :]  # вище кадру не видно — геть
    m5.save(end, CI + "gen_end.png")
    m5.save(prop("ci_cracked")[0], CI + "gen_cracked.png")
    # Схованка
    m5.save(m5.darken(tile("st_wall")[:VH], WALL_DARK), ST + "gen_wall.png")
    m5.save(m5.darken(prop("st_hole")[0], HOLE_DARK), ST + "gen_hole.png")
    for n in ("st_jars", "st_goods"):
        m5.save(prop(n)[0], ST + f"gen_{n[3:]}.png")
    # кінці переходів
    m5.save(prop("cy_ladder")[0], CITY + "gen_rooftops_ladder.png")
    m5.save(prop("cy_stall")[0], CITY + "gen_attic_stall.png")
    m5.save(prop("gt_rope")[0], GATES + "gen_rooftops_rope.png")
    for n in (*OPEN_PX, *CX_PX):
        print(f"{n}: anchor {prop(n)[1]:.1f} art from the left edge")


# --- розміщення (арт, кімната): (масив, множник, x якоря, y верху, тайл?, [передній?]) ----------------------------
SKY = B + "DesertOasis/bg4/plan5.png"
CLOUDS = B + "Canyon/gen_clouds.png"
MESAS = B + "Canyon/gen_far.png"
AQ_CEIL = (
    AQ + "gen_ceiling.png"
)  # 2304 арту; перший тайл — пролом Акведука, решта три — 1728, рівно Цистерна
AR_DOOR_X = 200 / 1.5  # MayorArchive/BookshelfDoor
CELLAR_X, LEVER_X = 140 / 1.5, 290 / 1.5  # Cistern/CellarDoor, CellarLever
WELL_X, STASH_X = (
    1700 / 1.5,
    2300 / 1.5,
)  # Cistern/WellDoor (Arrival), StashDoor = Wall_Stash
ST_DOOR_X, ST_SECRET_X = (
    200 / 1.5,
    1100 / 1.5,
)  # CisternStash/ExitDoor, SecretArea_Stash
CY_ROOF_X, CY_ATTIC_X = 880 / 1.5, 2450 / 1.5  # City/RooftopsDoor, TavernAtticDoor
GT_ROPE_X = 638 / 1.5  # CityGates/RooftopsDoor (сцена; не 300)
AQ_ARCH_CX = 90  # Aqueduct/gen_cellar.png: середина пройому від лівого краю (181 арту; README Акведука)
MAP_X, LECTERN_X = (
    300,
    480,
)  # Архів: мапа й пюпітр; між ними (330…420 арту) — місце скрині кімнати


def region(path, top):
    a = m5.img(path).copy()
    a[:top, :, 3] = 0  # region_rect сцени: верх не показується
    return a


def ar_planes():
    door, dx = m5.img(AR + "gen_door.png"), prop("ar_door")[1]
    mp, lect, front = (m5.img(AR + f"gen_{n}.png") for n in ("map", "lectern", "front"))
    return [
        (m5.img(AR + "gen_wall.png"), 1.0, 0, 0, False),
        (mp, 1.0, *m5.at(mp, MAP_X), False),
        (lect, 1.0, *m5.at(lect, LECTERN_X), False),
        (door, 1.0, round(AR_DOOR_X - dx), WALK + 1 - len(door), False),
        (m5.img(B + "Hall/gen_floor.png"), 1.0, 0, WALK, True),
        (front, 1.3, W + 10 - front.shape[1], -8, False, True),
    ]


def ci_planes():
    cols, dragon = m5.img(CI + "gen_columns.png"), m5.img(CI + "gen_dragon.png")
    well, wx = m5.img(CI + "gen_well.png"), prop("ci_well")[1]
    end, ex = m5.img(CI + "gen_end.png"), prop("ci_end")[1]
    arch, grate = m5.img(AQ + "gen_cellar.png"), m5.img(AQ + "gen_grate.png")
    pier = m5.img(AQ + "gen_front.png")
    ax = round(CELLAR_X - AQ_ARCH_CX)
    return [
        (m5.img(CI + "gen_far.png"), 0.45, 0, 0, True),
        (cols, 0.75, 0, WALK + 2 - len(cols), True),
        (dragon, 0.85, *m5.stand(dragon, 0.85, 288, 420), False),
        (arch, 1.0, ax, WALK + 2 - len(arch), False),
        (grate, 1.0, ax, WALK + 2 - len(grate), False),
        (well, 1.0, round(WELL_X - wx), WALK + 2 - len(well), False),
        (end, 1.0, round(STASH_X - ex), WALK + 2 - len(end), False),
        (m5.img(AQ + "gen_rubble.png"), 1.0, RUBBLE_X, 0, False),
        (
            m5.img(AQ_CEIL)[:, W:],
            1.0,
            0,
            0,
            False,
        ),  # над шахтою й торцем: обидва йдуть у склепіння
        (m5.img(AQ + "gen_floor.png"), 1.0, 0, WALK, True),
        *[
            (pier, 1.3, *m5.stand(pier, 1.3, 288, c, sink=40), False, True)
            for c in (250, 600)
        ],
    ]


def cracked(c, cam):
    """Wall_Stash (BreakableWall) — x 2300 світу, низ на 2 арти під лінією ходьби."""
    b = Image.fromarray(m5.img(CI + "gen_cracked.png"))
    c.alpha_composite(b, (round(STASH_X - cam - b.width / 2), WALK + 2 - b.height))


FILL1 = np.zeros((48, 1152, 4), np.uint8)
FILL1[...] = (31, 26, 26, 255)  # Color(0.12, 0.1, 0.1)
# кінці переходів стоять на задньому краї бруківки (непрозора з рядка 240): кузня Міста ховає низ за нею, а тут
# бухта мотузки й кошики мусять читатись
FOOT = 242


def st_planes():
    jars, goods = m5.img(ST + "gen_jars.png"), m5.img(ST + "gen_goods.png")
    hole, hx = m5.img(ST + "gen_hole.png"), prop("st_hole")[1]
    pier = m5.img(AQ + "gen_front.png")
    return [
        (m5.img(ST + "gen_wall.png"), 0.85, 0, 0, True),
        (jars, 0.95, *m5.stand(jars, 0.95, 420, 60), False),
        (goods, 0.95, *m5.stand(goods, 0.95, 430, 576), False),  # не на таємниці (x 733 арту)
        (hole, 1.0, round(ST_DOOR_X - hx), WALK + 1 - len(hole), False),
        (m5.img(B + "Cellar/gen_floor.png"), 1.0, 0, WALK, False),
        (FILL1, 1.0, 0, 272, False),  # Ground/Fill1 сцени (408…480 світу) — під смугою підлоги в 45 рядків
        (pier, 1.3, *m5.stand(pier, 1.3, 288, 300, sink=40), False, True),
    ]


def city_planes(name, path, x):
    """Ринок (City.tscn) з камерою 0: небо, хмари, гори, CityFar ×0.4, CityNear ×0.85 (регіони сцени), бруківка;
    кузні нема — m6c1 переносить її в Ремісничий квартал."""
    a, ax = m5.img(path), prop(name)[1]
    terr = m5.img(B + "Terrain/City_Terrain.png").copy()
    terr[:240, :, 3] = 0
    return [
        (m5.img(SKY), 0.0, 0, 0, True),
        (m5.img(CLOUDS), 0.1, 0, 0, True),
        (region(MESAS, 112), 0.3, 0, 0, True),
        (region(CITY + "gen_far.png", 48), 0.4, 0, 0, True),
        (region(CITY + "gen_near.png", 64), 0.85, 0, 0, True),
        (a, 1.0, round(x - ax), FOOT - len(a), False),
        (terr, 1.0, 0, 0, False),
    ]


def gates_planes():
    a, ax = m5.img(GATES + "gen_rooftops_rope.png"), prop("gt_rope")[1]
    return [
        (m5.img(SKY), 0.0, 0, 0, True),
        (m5.img(CLOUDS), 0.1, 0, 0, True),
        (region(MESAS, 112), 0.3, 0, 0, True),
        (region(GATES + "gen_mid.png", 80), 0.7, 0, -2, True),
        (a, 1.0, round(GT_ROPE_X - ax), FOOT - len(a), False),
        (m5.img(B + "Terrain/CityGates_Terrain.png"), 1.0, 0, 0, False),
    ]


PASSAGES = (  # (ім'я сирої, файл, x світу / 1.5, кадр камери)
    ("cy_ladder", CITY + "gen_rooftops_ladder.png", CY_ROOF_X, 300),
    ("cy_stall", CITY + "gen_attic_stall.png", CY_ATTIC_X, 1350),
    ("gt_rope", GATES + "gen_rooftops_rope.png", GT_ROPE_X, 140),
)


def sheet():
    hero = m5.img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    ap, cp, sp = ar_planes(), ci_planes(), st_planes()
    (_, lf, lx, lc), (_, sf, sx, sc), (_, _, gx, gc) = PASSAGES
    frames = [
        (
            "Mayor's Archive (one screen, fixed camera): the back of the bookshelf door - BookshelfDoor x 200 world; "
            "the empire map with the barrier domes x 450, a lectern with a ledger x 720; 495-630 kept for the chest; "
            "lamp beam front x1.3",
            m5.compose(ap, 0, (AR_DOOR_X + 45, hero)),
        ),
        (
            "Cistern, west end (camera 0): the gatehouse cellar grate - CellarDoor x 140 (the Aqueduct's arch and "
            "grate); the lever x 290 is lever.tscn (not drawn); columns in green water x0.75, depths x0.45",
            m5.compose(cp, 0, (LEVER_X + 30, hero)),
        ),
        (
            "Cistern, camera 420: the dragon-head column base x0.85; the vault pier front x1.3",
            m5.compose(cp, 420, (700, hero)),
        ),
        (
            "Cistern, the Arrival (camera 845): the well shaft with iron rungs up into the vault - WellDoor x 1700",
            m5.compose(cp, 845, (WELL_X + 40, hero)),
        ),
        (
            "Cistern, east end (camera 1152): the end wall, its old breach walled up and cracked - Wall_Stash's "
            "sprite at x 2300 (StashDoor)",
            m5.compose(cp, 1152, (1440, hero), lambda c: cracked(c, 1152)),
        ),
        (
            "Cistern, east end, Wall_Stash broken: the breach into the stash",
            m5.compose(cp, 1152, (1440, hero)),
        ),
        (
            "Cistern Stash, west end (camera 0, the Arrival): the breach back into the cistern - ExitDoor x 200; "
            "sealed water jars, a ladle and a copper pot x0.95",
            m5.compose(sp, 0, (ST_DOOR_X + 55, hero)),
        ),
        (
            "Cistern Stash, east end (camera 576): crates, rolled carpets, sacks x0.95; SecretArea_Stash x 1100",
            m5.compose(sp, 576, (ST_SECRET_X, hero)),
        ),
        (
            "City (market), camera 300: the ladder up a house wall - RooftopsDoor x 880 world (to the Rooftops)",
            m5.compose(city_planes("cy_ladder", lf, lx - lc), 0, (lx - lc + 45, hero)),
        ),
        (
            "City (market), camera 1350: the ladder behind the stall - TavernAtticDoor x 2450 world (to the attic)",
            m5.compose(city_planes("cy_stall", sf, sx - sc), 0, (sx - sc + 60, hero)),
        ),
        (
            "City Gate, camera 140: the rope from the Rooftops down a wall buttress, its end coiled - RooftopsDoor "
            "x 638 world (the scene's x)",
            m5.compose(gates_planes(), gc, (gx + 45, hero)),
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
    out.save("design/shots/m6c3_archive_cistern.png")
    print("sheet", out.size, flush=True)


def wiring():
    """Числа для сцен (світ = арт × 1.5): позиції спрайтів у своїх Parallax2D (scroll_offset 0, якщо не сказано)."""
    for room, planes in (
        ("MayorArchive", ar_planes()),
        ("Cistern", ci_planes()),
        ("CisternStash", st_planes()),
    ):
        print(room)
        for a, f, x, y, rep, *front in planes:
            print(
                f"  f {f:<4} size {a.shape[1]}x{a.shape[0]}  pos ({x * 1.5:g}, {y * 1.5:g})"
                + ("  tile" if rep else "")
                + ("  front" if front else "")
            )
    b = m5.img(CI + "gen_cracked.png")
    print(
        f"Wall_Stash/Sprite: size {b.shape[1]}x{b.shape[0]}, offset (0, {-(len(b) / 2 - 2):g})"
    )
    for name, path, x, _ in PASSAGES:
        a, ax = m5.img(path), prop(name)[1]
        print(
            f"{path}: size {a.shape[1]}x{a.shape[0]}  pos ({round(x - ax) * 1.5:g}, {(FOOT - len(a)) * 1.5:g})"
        )

if __name__ == "__main__":
    {"gen": gen, "build": build, "sheet": sheet, "wiring": wiring}[sys.argv[1]]()
