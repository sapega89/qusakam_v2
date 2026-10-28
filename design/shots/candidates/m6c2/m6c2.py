"""M6c-2: фони Міста — Дахи (Rooftops, 3 клітинки над брамою й ринком: пласкі дахи, по яких бігти, з дахами,
банями, вітроловами й білизною Міста довкола; на заході — мотузка вниз до брами (SlideDoor x 150 світу), посередині
— голубник на даху з дверцятами, забитими дошками (LoftDoor/Wall_Loft x 1300), на сході — верх драбини з ринку
(LadderDoor x 2400)), Голубник (PigeonLoft, 1 клітинка: усередині голубника — ніші, жердини, дверцята з виламаними
дошками посередині, ExitDoor x 432) і Горище таверни (TavernAttic, 2 клітинки: крокви, бочки, мішки, люк із драбиною
LadderDoor x 200). Усі три — одна клітинка заввишки: лінія ходьби — рядок 256 арту (підлога y 384 світу).
Підлога ціла, драбина стоїть перед нею (B201); нічого не висить у повітрі (A15).
  python -B design/shots/candidates/m6c2/m6c2.py gen     — ComfyUI (сирі PNG поруч; є — не кличе модель; ≤ 4 за запуск)
  python -B design/shots/candidates/m6c2/m6c2.py build   — плани в SampleProject/Assets/Backgrounds/{Rooftops,PigeonLoft,TavernAttic}/
  python -B design/shots/candidates/m6c2/m6c2.py sheet   — design/shots/m6c2_rooftops.png
  python -B design/shots/candidates/m6c2/m6c2.py wiring  — числа для сцен (світ)
Розміри — таблиця світу (D814): герой 64 арту, двері 112, бочка 32; на плані f — round(h × f).
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
import m6b5 as m5  # scaled, compose, stand, save, img, free, sh — той самий конвеєр

D = os.path.dirname(os.path.abspath(__file__))
B = "SampleProject/Assets/Backgrounds/"
RT, PL, TA = B + "Rooftops/", B + "PigeonLoft/", B + "TavernAttic/"
W, VH, WALK = 576, 324, 256
STYLE = cb.STYLE
MAG = cb.MAGENTA
GREEN = "on a solid flat chroma key green (#00FF00) background"
FRONT = "seen straight on, flat orthographic front elevation, no perspective"
SIDE = "seen exactly from the side, flat orthographic side elevation, no perspective"
SOLO = f"standing alone, nothing behind it, no people, warm light on the top, cool violet shadows, {GREEN}"
GROUP = "all in one group standing directly on the bottom edge of the frame, no floor, no wall, nothing behind them"

# тайли: (текст, рядки арту, зерно, ключ або None); генерація 1728 px завширшки (×3), шов — модель
TILES = {
    # що видно з даху збоку: сусідні дахи на тій самій висоті ховає наша смуга даху, над ними — те, що на дахах
    "rt_mid": (
        f"the flat rooftops of a desert city {SIDE}, at roof level: the flat roofs all at the same height along the "
        "bottom edge, and standing on them small white plastered domes, square wind-catcher towers with tall narrow "
        "vent slots, rooftop shelters with striped cloth canopies on wooden poles, laundry lines strung between thin "
        "poles with shirts, sheets and red and indigo rugs hanging to dry, big clay water jars, low parapets with "
        "carpets hung over them, a slender minaret with a balcony in the distance, spanning the full width, reaching "
        f"the bottom edge, {MAG}",
        180,
        10211,
        "magenta",
    ),
    # смуга під ногами: верх будинку, по даху якого біжить герой — рядок 0 — лінія даху
    "rt_roof": (
        f"the top storey of a row of plastered sandstone houses joined wall to wall {FRONT}: the flat roof line "
        "perfectly straight and level a little below the top of the frame, a thin pale roof edge, a row of round "
        "wooden beam ends sticking out under it, the upper walls below with small arched windows with wooden "
        "shutters, a carpet hung from a window, a small lantern on a bracket, the walls reaching the bottom edge, "
        f"spanning the full width, {MAG} above the roof line",
        140,
        10221,
        "magenta",
    ),
    "ta_wall": (
        f"the inside of a long dusty tavern attic under the roof {FRONT}: a heavy horizontal ridge beam and purlins "
        "along the top, evenly spaced upright dark wooden posts holding them with diagonal braces, rough roof boards "
        "and reed matting between the beams, a low plastered warm adobe back wall along the bottom, one small square "
        "window with a wooden shutter letting in a soft dusty light, cobwebs in the corners, spanning the full width, "
        "the back wall reaching the bottom edge, no floor visible, nothing standing in front of the wall",
        324,
        10231,
        None,
    ),
}

# предмети на хромакеї: (текст, ширина, висота генерації px, зерно)
PROPS = {
    "rt_loft": (
        f"a desert pigeon tower, a dovecote, {FRONT}: a round squat tower of plastered mud brick, wider at its base, "
        "its upper part covered all over in rows of small round pigeon holes with little wooden perch sticks poking "
        "out under them, a whitewashed band around it, a small dome on top with a pointed finial, at its foot in the "
        "middle a plain arched doorway with a dark empty opening, the doorway reaching half of the tower's height, "
        f"its threshold on the bottom edge, {SOLO}",
        1024,
        1536,
        10241,
    ),
    "rt_boards": (
        "a rough barricade of old weathered wooden planks nailed crosswise and askew over each other, some loose and "
        "hanging by one rusty nail, the planks forming a tall narrow upright shape like a boarded-up doorway, seen "
        f"straight on, flat, no wall, nothing behind it, {GREEN}",
        768,
        1024,
        10251,
    ),
    "rt_ladder": (
        f"one plain long wooden ladder standing perfectly upright and straight {FRONT}: two straight parallel side "
        "rails and evenly spaced round rungs, worn wood, rope lashings at the rungs, the ladder reaching from the "
        f"bottom edge to the top edge of the frame, nothing else, {GREEN}",
        512,
        1536,
        10261,
    ),
    "rt_rope": (
        f"a short thick wooden mooring post standing upright {SIDE}, a thick rope tied around it in a knot, the "
        "rope's long end hanging straight down from the knot to the bottom edge of the frame, an iron ring on the "
        f"post, {SOLO}",
        768,
        1536,
        10271,
    ),
    # 10281 — футболка з кишенькою й джинси (сучасне), кам'яний парапет під жердинами
    "rt_laundry": (
        "a laundry line strung between two thin wooden poles standing upright, with a long plain linen tunic, a white "
        "sheet, a striped red and indigo woven rug and loose baggy linen trousers pegged on it to dry, the line "
        "sagging slightly, seen straight on, flat orthographic front elevation, both poles ending on the bottom edge, "
        f"no wall, no ground, nothing behind it, {MAG}",
        1536,
        1024,
        10282,
    ),
    # навісу на даху (вітролову, 10291/10292; навісу з лавою, 10293/10294) нема: модель чотири рази малювала його в
    # ізометрії на брилі даху з дверима біля основи; на сході — та сама білизна, віддзеркалена (інший екран)
    "rt_front": (
        "a squat sandstone chimney stack rising from the bottom edge of the frame, topped by a round clay pot cowl, a "
        "big cracked clay water jar standing beside it, a coiled rope hanging from a hook on the chimney, nothing "
        f"else, {MAG}",
        768,
        1536,
        10301,
    ),
    "pl_door": (
        f"a plain arched doorway with a heavy rough wooden frame and lintel {FRONT}, broken wooden planks hanging "
        "askew from its sides on rusty nails, through the opening bright daylight and the flat roofs and domes of a "
        f"desert city, its threshold on the bottom edge, only the doorway frame, no wall around it, {GREEN}",
        1024,
        1024,
        10311,
    ),
    # 10321 — діорама в ізометрії з дощаною плитою, стіною й голубом; «at eye level» тримало фонтан m6c1 плоским
    "pl_keeper": (
        "a burlap sack of grain, a domed wicker pigeon basket and a small three-legged wooden stool standing side by "
        "side in a row, seen exactly from the side at eye level, flat orthographic side elevation, no perspective, "
        "the bottoms of all three on one straight horizontal line on the bottom edge of the frame, no floor visible, "
        f"no wall, nothing behind them, {MAG}",
        1536,
        768,
        10322,
    ),
    "pl_front": (
        "a dark wooden beam across the top of the frame from edge to edge, two domed wicker bird cages hanging from "
        f"it on short ropes, a few white feathers, nothing else, {GREEN}",
        1024,
        1024,
        10331,
    ),
    "ta_barrels": (
        f"old wooden barrels with iron hoops {SIDE}: three barrels lying on their sides on a low wooden rack, one "
        f"with a wooden tap, two barrels standing upright beside them, a small wooden crate, {GROUP}, {MAG}",
        1536,
        768,
        10341,
    ),
    "ta_sacks": (
        f"a pile of tied burlap sacks of flour and grain {SIDE}, a stack of wooden crates with straw sticking out, "
        f"a broken wooden chair on top, a string of onions lying on a sack, {GROUP}, {MAG}",
        1536,
        768,
        10351,
    ),
    "ta_front": (
        "a dark wooden roof post rising from the bottom edge to the top edge of the frame, an old iron oil lantern "
        "hanging from a hook on it, strings of onions and garlic and a bunch of dried sausages hanging from a nail, "
        f"nothing else, {GREEN}",
        768,
        1536,
        10371,
    ),
}
# одна сцена на весь екран, без шва (кімната — один екран, камера стоїть)
SCREENS = {
    "pl_wall": (
        f"the inside of an old desert pigeon tower {FRONT}: the warm mud-brick walls covered from top to bottom with "
        "rows of small arched nesting niches, pigeons sitting in some of them, wooden perch poles fixed across the "
        "wall at different heights, small square openings high up letting in soft beams of dusty daylight, a few "
        "feathers in the air, a shadowy warm interior, the wall reaching down to the bottom edge, nothing standing in "
        "front of it",
        10381,
    ),
}


def raw(name):
    return os.path.join(D, f"m6c2_{name}_raw.png")


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


# що лишається від сирої (px генерації: y0, y1, x0, x1); низ — лінія ходьби (без піску, плити, стіни, підлоги під
# предметом, яку модель домальовує)
KEEP = {
    "rt_loft": [(0, 1404, 100, 925)],  # пісок і сходинка під дверима — геть (D830)
    "rt_boards": [
        (230, 900, 255, 612)
    ],  # лише дошки на дверях (із правим стовпом), без паркану обабіч і трави
    "rt_ladder": [(60, 1270, 40, 440)],  # верх драбини
    "rt_laundry": [(0, 895, 0, 1536)],  # кам'яний парапет під жердинами — геть
    "pl_door": [(90, 886, 100, 920)],  # підлога за порогом — геть
    # мішок, кошик (без курки на кришці — плоский верх), стілець; дощана плита під ними — геть (низ на 1.5 арту вище)
    "pl_keeper": [(225, 580, 185, 585), (284, 580, 600, 1012), (345, 580, 1060, 1335)],
    "ta_barrels": [(0, 645, 0, 1536)],
    "ta_sacks": [(0, 665, 0, 1536)],
}
# пройом на сирій, px генерації: (верх, поріг, x середини) — висота пройому стає дверима (D814: 112)
OPEN_PX = {"rt_loft": (1057, 1403, 508), "pl_door": (250, 885, 500)}
# висота, арт (D814: бочка 32, мішок ~26–28, герой 64)
SIZES = dict(
    rt_boards=124,  # пройом 112 + 6 над аркою + 2 під лінією ходьби, як gen_cracked Дна каньйону
    rt_ladder=104,  # 40 над дахом + 64 донизу кадру (стоїть перед цілою смугою, B201)
    rt_rope=46,  # тумба 0.7 H; мотузка — донизу кадру (rope_down)
    rt_laundry=100,  # жердини 1.6 H (на плані ×0.9 — 90)
    rt_front=230,
    pl_keeper=27,  # мішок зерна 28 (низ зрізано на 1.5)
    pl_front=90,
    ta_barrels=34,  # стояча бочка 32 (D814), полиця з лежачими трохи вища
    ta_sacks=68,  # мішок борошна 26, на ящиках — зламаний стілець
    ta_front=340,
)
PROP_F = dict(rt_laundry=0.9)


def keyed(name):
    """Предмет на хромакеї (зелений чи пурпур): далеко від тла, без тіней кольору тла, у KEEP."""
    from scipy import ndimage

    im = load(name)
    edges = [im[:8], im[:, :8], im[:, -8:]]  # тло — найрівніший край (стовп горища зачіпає верх кадру крокв'ям)
    bg = np.median(min((e.reshape(-1, 3) for e in edges), key=lambda e: e.std(0).sum()), axis=0)
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


def prop(name):
    """(масив, x середини пройому в арті або None) — висота з пройому (D814) чи SIZES × PROP_F."""
    im, m = keyed(name)
    ys, xs = np.nonzero(m)
    if name in OPEN_PX:
        top, sill, cx = OPEN_PX[name]
        a = m5.scaled(im, m, round((ys.max() - ys.min() + 1) * 112 / (sill - top)))
        return a, (cx - xs.min()) * a.shape[1] / (xs.max() - xs.min() + 1)
    return m5.scaled(im, m, round(SIZES[name] * PROP_F.get(name, 1.0))), None


def tile(name, haze=0.0, colors=16):
    im = load(name)
    key = TILES[name][3]
    rgb, op = cb.shrink(im, key, spill=60 if key else 0)
    rgb = rgb * (1 - haze) + cb.HAZE * haze
    return cb.quantize(rgb, op, colors, "octree")


def roof_strip():
    """Смуга під ногами на дахах: рядок 0 — лінія даху (перший майже суцільний рядок), 64 рядки донизу кімнати."""
    g = tile("rt_roof")
    g = g[int(np.argmax((g[..., 3] > 0).mean(1) >= 0.9)) :][: 320 - WALK].copy()
    g[..., 3] = 255
    return g


ROPE_EXTRA = 66  # мотузка звисає на 66 арту нижче основи тумби — до низу кадру


def rope_down(a, extra=ROPE_EXTRA):
    """Мотузка тумби звисає з краю даху до низу кадру: її відрізок ліворуч від тумби повторено донизу, китиця — в кінці.
    Частки висоти — з сирої (вертикальний відтинок мотузки 1100…1240 px, китиця 1240…1350 при тумбі 145…1400)."""
    h = len(a)
    post0 = int(np.nonzero(a[-1, :, 3])[0].min())  # лівий край основи тумби
    seg = a[round(h * 0.76) : round(h * 0.87), :post0].copy()
    tassel = a[round(h * 0.87) :, :post0].copy()
    out = np.zeros((h + extra, a.shape[1], 4), np.uint8)
    out[:h] = a
    out[round(h * 0.76) :, :post0] = 0
    y = round(h * 0.76)
    while y < len(out) - len(tassel):
        n = min(len(seg), len(out) - len(tassel) - y)
        out[y : y + n, :post0] = seg[:n]
        y += n
    out[-len(tassel) :, :post0] = tassel
    return out


MID_HAZE = 0.3


def build():
    for d in (RT, PL, TA):
        os.makedirs(d, exist_ok=True)
    # Дахи
    m5.save(tile("rt_mid", MID_HAZE), RT + "gen_mid.png")
    m5.save(roof_strip(), RT + "gen_roof.png")
    loft, door_x = prop("rt_loft")
    print(
        f"loft door centre: {door_x:.1f} art from the left edge, loft {loft.shape[1]}x{len(loft)}"
    )
    m5.save(
        loft[max(0, len(loft) - WALK) :], RT + "gen_loft.png"
    )  # вище кадру не видно — геть
    for n in ("rt_boards", "rt_ladder", "rt_laundry", "rt_front"):
        m5.save(prop(n)[0], RT + f"gen_{n[3:]}.png")
    m5.save(rope_down(prop("rt_rope")[0]), RT + "gen_rope.png")
    # Голубник
    w = cb.quantize(
        cb.shrink(load("pl_wall"), None)[0][:VH], np.ones((VH, W), bool), 16, "octree"
    )
    m5.save(w, PL + "gen_wall.png")
    door, dx = prop("pl_door")
    print(f"loft exit door centre: {dx:.1f} art from the left edge")
    m5.save(door, PL + "gen_door.png")
    m5.save(prop("pl_keeper")[0], PL + "gen_keeper.png")
    m5.save(prop("pl_front")[0], PL + "gen_front.png")
    # Горище таверни
    m5.save(tile("ta_wall")[:VH], TA + "gen_wall.png")
    for n in ("ta_barrels", "ta_sacks", "ta_front"):
        m5.save(prop(n)[0], TA + f"gen_{n[3:]}.png")


# --- розміщення (арт, кімната): (масив, множник, x якоря, y верху, тайл?, [передній?]) ----------------------------
SKY = B + "DesertOasis/bg4/plan5.png"
CLOUDS = B + "Canyon/gen_clouds.png"
MESAS = B + "Canyon/gen_far.png"
ELDER_FLOOR = B + "ElderHouse/gen_floor.png"
# Ринок City [21,5] → Дахи [19,4]: спільні плани продовжують ринкові (зсув −f × X mod 576 арту)
RT_X = -2 * W
PL_W, TA_W = 576, 1152
ROPE_X, LOFT_X, LADDER_X = (
    150 / 1.5,
    1300 / 1.5,
    2400 / 1.5,
)  # SlideDoor, LoftDoor/Wall_Loft, LadderDoor
TA_LADDER_X = 200 / 1.5  # TavernAttic/LadderDoor
PL_DOOR_X = 432 / 1.5  # PigeonLoft/ExitDoor (Arrival)
MID_F, MID_FOOT = 0.6, 262  # низ тайла дахів — під смугою даху
LADDER_UP = 40  # верх драбини над підлогою (як горище діда)
FRONT_SINK = 100  # основа комина — нижче кадру


def region(path, top):
    a = m5.img(path).copy()
    a[:top, :, 3] = 0  # region_rect сцени: верх не показується
    return a


def rt_planes():
    mid, roof = m5.img(RT + "gen_mid.png"), m5.img(RT + "gen_roof.png")
    loft, laundry = m5.img(RT + "gen_loft.png"), m5.img(RT + "gen_laundry.png")
    rope, ladder, front = (
        m5.img(RT + f"gen_{n}.png") for n in ("rope", "ladder", "front")
    )
    _, door_x = prop("rt_loft")
    return [
        (m5.img(SKY), 0.0, 0, 0, True),
        (m5.img(CLOUDS), 0.1, m5.sh(0.1, RT_X), 0, True),
        (region(MESAS, 112), 0.3, m5.sh(0.3, RT_X), 0, True),
        (mid, MID_F, 0, MID_FOOT - len(mid), True),
        (laundry, 0.9, *m5.stand(laundry, 0.9, 200, 300), False),
        (laundry[:, ::-1].copy(), 0.9, *m5.stand(laundry, 0.9, 330, 1000), False),
        (loft, 1.0, round(LOFT_X - door_x), WALK - len(loft), False),
        (roof, 1.0, 0, WALK, True),
        (
            rope,
            1.0,
            round(ROPE_X - rope.shape[1] / 2),
            WALK + 1 - (len(rope) - ROPE_EXTRA),
            False,
        ),
        (ladder, 1.0, round(LADDER_X - ladder.shape[1] / 2), WALK - LADDER_UP, False),
        *[
            (fr, 1.3, *m5.stand(front, 1.3, 288, c, sink=FRONT_SINK), False, True)
            for fr, c in zip((front, front[:, ::-1].copy()), (200, 900))
        ],
    ]


def boards(c, cam):
    """Wall_Loft (BreakableWall) з дошками — x 1300 світу, низ на 2 арти під лінією ходьби."""
    b = Image.fromarray(m5.img(RT + "gen_boards.png"))
    c.alpha_composite(b, (round(LOFT_X - cam - b.width / 2), WALK + 2 - b.height))


def floor(width):
    t = m5.img(ELDER_FLOOR)
    return np.concatenate([t] * (width // t.shape[1]), axis=1)


def pl_planes():
    door, dx = m5.img(PL + "gen_door.png"), prop("pl_door")[1]
    keeper, front = m5.img(PL + "gen_keeper.png"), m5.img(PL + "gen_front.png")
    return [
        (m5.img(PL + "gen_wall.png"), 1.0, 0, 0, False),
        (door, 1.0, round(PL_DOOR_X - dx), WALK + 1 - len(door), False),
        (keeper, 1.0, *m5.at(keeper, 110, sink=2), False),
        (floor(PL_W), 1.0, 0, WALK, False),
        (front, 1.3, -10, -8, False, True),
    ]


def ta_planes():
    barrels, sacks = m5.img(TA + "gen_barrels.png"), m5.img(TA + "gen_sacks.png")
    front, ladder = m5.img(TA + "gen_front.png"), m5.img(RT + "gen_ladder.png")
    return [
        (m5.img(TA + "gen_wall.png"), 0.85, 0, 0, True),
        (barrels, 0.95, *m5.stand(barrels, 0.95, 400, 120), False),
        (sacks, 0.95, *m5.stand(sacks, 0.95, 300, 576), False),
        (floor(TA_W), 1.0, 0, WALK, False),
        (
            ladder,
            1.0,
            round(TA_LADDER_X - ladder.shape[1] / 2),
            WALK - LADDER_UP,
            False,
        ),
        (front, 1.3, m5.stand(front, 1.3, 288, 400)[0], -10, False, True),
    ]


def sheet():
    hero = m5.img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    rp, pp, tp = rt_planes(), pl_planes(), ta_planes()
    frames = [
        (
            "Rooftops, west end (camera 0): the rope tied to a post, hanging down the house wall - SlideDoor x 150 "
            "world, the drop to the City Gate; laundry x0.9, the City's roofs x0.6",
            m5.compose(rp, 0, (190, hero)),
        ),
        (
            "Rooftops, camera 600: the dovecote on the roof (it rises into the Pigeon Loft above), its door boarded up "
            "- Wall_Loft's new sprite at x 1300 world; the chimney front x1.3",
            m5.compose(rp, 600, (760, hero), lambda c: boards(c, 600)),
        ),
        (
            "Rooftops, east end (camera 1152, the Arrival): the ladder's top over the roof edge - LadderDoor x 2400 "
            "world, up from the market; the floor whole, the ladder stands against it (B201)",
            m5.compose(rp, 1152, (1640, hero)),
        ),
        (
            "Pigeon Loft (one screen, fixed camera): the nesting niches, the doorway with its broken boards - "
            "ExitDoor x 432 world, the keeper's sack, basket and stool, cages front x1.3; SecretArea at x 640",
            m5.compose(pp, 0, (350, hero)),
        ),
        (
            "Tavern Attic, west end (camera 0, the Arrival): the ladder up from the market stall through the hatch - "
            "LadderDoor x 200 world, the floor whole (B201); barrels x0.95",
            m5.compose(tp, 0, (180, hero)),
        ),
        (
            "Tavern Attic, east end (camera 576): sacks, crates and a broken chair x0.95, the lantern post front x1.3",
            m5.compose(tp, 576, (1000, hero)),
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
    out.save("design/shots/m6c2_rooftops.png")
    print("sheet", out.size, flush=True)


def wiring():
    """Числа для сцен (світ = арт × 1.5): позиції спрайтів у своїх Parallax2D (scroll_offset 0, якщо не сказано)."""
    for room, planes in (
        ("Rooftops", rt_planes()),
        ("PigeonLoft", pl_planes()),
        ("TavernAttic", ta_planes()),
    ):
        print(room)
        for a, f, x, y, rep, *front in planes:
            print(
                f"  f {f:<4} size {a.shape[1]}x{a.shape[0]}  pos ({x * 1.5:g}, {y * 1.5:g})"
                + ("  tile" if rep else "")
            )
    b = m5.img(RT + "gen_boards.png")
    print(
        f"Wall_Loft/Sprite: size {b.shape[1]}x{b.shape[0]}, offset (0, {-(len(b) / 2 - 2):g})"
    )


if __name__ == "__main__":
    {"gen": gen, "build": build, "sheet": sheet, "wiring": wiring}[sys.argv[1]]()
