"""M6c-1: фони Міста — Ремісничий квартал (CraftQuarter, 3 клітинки: вулиця від ринку на схід, відкрита в обидва
боки; майстерні гончаря, ткача килимів і мідника на вулиці, за ними ряд майстерень із сохнучими фарбованими тканинами
й шкурами, кузня й каплиця ринку переходять сюди, D773) і Площа палацу (PalaceSquare, 2 клітинки: глухий схід —
фасад палацу мера з дверима між вартовими, MayorHallDoor x 1560 світу, D836 звіту world-rooms; фонтан із кам'яним
драконом посеред площі). Обидві — одна клітинка заввишки: лінія ходьби — рядок 256 арту (підлога y 384 світу).
  python -B design/shots/candidates/m6c1/m6c1.py gen    — ComfyUI (сирі PNG поруч; є — не кличе модель; ≤ 4 за запуск)
  python -B design/shots/candidates/m6c1/m6c1.py build  — плани в SampleProject/Assets/Backgrounds/{CraftQuarter,PalaceSquare}/
  python -B design/shots/candidates/m6c1/m6c1.py sheet  — design/shots/m6c1_craft_palace.png
Вигляд — Місто D237 (вежі й бані, кам'яниці з балконами, тенти, ліхтарі; на прапорах — проста золота бляха, Q57).
Розміри — таблиця світу (D814): герой 64 арту, двері 112, поверх 144, людина 96; на плані f — round(h × f).
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
import m6b5 as m5  # mask, scaled, darken, compose, stand, save, img, free — той самий конвеєр

D = os.path.dirname(os.path.abspath(__file__))
B = "SampleProject/Assets/Backgrounds/"
CQ, PS, CITY = B + "CraftQuarter/", B + "PalaceSquare/", B + "City/"
W, VH, WALK = 576, 324, 256
STYLE = cb.STYLE
MAG = cb.MAGENTA
GREEN = "on a solid flat chroma key green (#00FF00) background"
FRONT = "seen straight on, flat orthographic front elevation, no perspective"
ALONE = "standing alone in the middle of the frame with empty space on both sides, its base resting on the bottom edge"
FACADE = (
    "seen straight on, only its front face visible, flat orthographic front elevation, no perspective, no roof "
    "visible, no side walls visible"
)
SOLO = f"standing alone, nothing behind it, no people, warm light on the top, cool violet shadows, {GREEN}"
DISC = "red banners each carrying a plain golden disc with a raised rim"  # герб — Q57

# геометрія сцен, арт (світ / 1.5)
CQ_W, PS_W = 1728, 1152  # камера x 0…1152 / 0…576
DOOR_X = 1560 / 1.5  # PalaceSquare/MayorHallDoor; вартові — 1500 і 1620 світу

# тайли: (текст, рядки арту, зерно, ключ); генерація 1728 px завширшки (×3), шов — модель
TILES = {
    "cq_mid": (
        "a street of craftsmen's workshop houses in a desert city, one- and two-storey sandstone and plastered houses "
        "of different heights joined wall to wall: flat roofs with short chimneys and thin smoke, ropes strung between "
        "the roofs with freshly dyed cloth hanging to dry in deep red, indigo blue and saffron yellow, stretched hides "
        "drying on wooden frames on a roof, carpets hung over balcony rails, copper pots hanging by the doors, stacks "
        "of clay jars on the roofs, wooden shutters and arched doorways, spanning the full width, standing on the "
        f"bottom edge, {MAG}",
        220,
        10011,
        "magenta",
    ),
    # 10021 — крило в перспективі (ліва половина тікає вдалину), привид шва посередині, бруківка площі й дюни
    "ps_mid": (
        "the long flat front wall of the outer wing of a desert palace seen straight on, only its front face visible, "
        "flat orthographic front elevation, no perspective: a ground floor arcade of pointed arches on slender "
        "sandstone columns with deep shade inside, an upper storey of plastered sandstone with small arched windows "
        f"with carved wooden screens, a crenellated parapet with {DISC} hanging from it, the same height along the "
        f"whole width, spanning the full width and reaching the bottom edge, nothing in front of it, {MAG} above it",
        220,
        10022,
        "magenta",
    ),
}

# предмети на хромакеї: (текст, ширина, висота генерації px, зерно)
PROPS = {
    # 10031/10041/10051 («one single small … workshop») — ізометричні діорами з плитою під будинком, як ga_pump 9921;
    # фасад — формула ga_pump: лише передня стіна, без даху й боків
    "cq_potter": (
        f"the flat front wall of a small potter's workshop in a desert city {FACADE}: a sandstone facade with a wide "
        "open front under a striped cloth awning, a potter's wheel and wooden shelves full of clay jars and bowls "
        "inside, a round clay kiln built against the wall beside it with a faint orange glow in its mouth and a short "
        f"chimney, big clay amphorae standing in front along its foot, {SOLO}",
        1536,
        1024,
        10032,
    ),
    "cq_weaver": (
        f"the flat front wall of a small carpet weaver's workshop in a desert city {FACADE}: a plastered sandstone "
        "facade with a doorway, a big upright wooden carpet loom standing against it under a plank awning with a "
        "half-woven patterned carpet in deep red, indigo and saffron, finished carpets hung over a rail on the wall "
        f"and rolled carpets leaning on it, baskets of wool yarn at its foot, {SOLO}",
        1536,
        1024,
        10042,
    ),
    "cq_copper": (
        f"the flat front wall of a small coppersmith's shop in a desert city {FACADE}: a sandstone facade with an "
        "arched open front, the wall and the doorframe hung all over with shining hammered copper pots, pans, trays "
        "and lanterns, a low wooden workbench with a small anvil and hammers against the wall, a big copper cauldron "
        f"on the ground at its foot, {SOLO}",
        1536,
        1024,
        10052,
    ),
    "cq_front": (
        "a tall rough wooden pole rising from the bottom edge to the top edge of the frame, a rope tied to it with long "
        "strips of dyed cloth hanging from the rope, a small copper lantern hanging on a hook, a few clay jars stacked "
        f"at its foot, nothing else, {MAG}",
        512,
        1536,
        10061,
    ),
    # 10071 — фасад завширшки з дверима на пів висоти: у 112 арту дверей палац виходив 189 арту (1.3 поверху) і
    # сходи перед дверима; тут — високий фасад, двері — третина висоти
    "ps_palace": (
        f"the grand front of a desert palace {FACADE}: a tall three-storey symmetrical facade of pale sandstone with "
        "carved bands, much taller than it is wide, at its foot in the middle a closed double door of dark carved wood "
        "with bronze studs under a pointed arch, the door small, only a third of the facade's height, its threshold "
        "level with the paved ground, rows of arched windows with carved wooden screens and a balcony above the door, "
        f"two slender towers with small onion domes on both sides, a crenellated top, two {DISC} hanging on both "
        f"sides of the door, standing alone, nothing behind it, {GREEN}",
        1024,
        1536,
        10072,
    ),
    # 10081 — у три чверті згори: овальна чаша з водою, видно її дно, сходинки збоку
    "ps_fountain": (
        "one single round fountain of carved sandstone seen exactly from the side at eye level, flat orthographic side "
        "elevation, no perspective, the rim of the basin a straight horizontal line and the water surface not visible: "
        "a wide low basin wall with carved panels standing on a low plinth, a slender column rising from behind it "
        "with a small upper bowl, on top of the column a coiled stone dragon with its head raised, a thin stream of "
        f"water pouring from the dragon's mouth into the bowl and spilling over its edge, {SOLO}",
        1024,
        1024,
        10082,
    ),
}


def raw(name):
    return os.path.join(D, f"m6c1_{name}_raw.png")


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


def gen():
    todo = [n for n in [*PROPS, *TILES] if not os.path.exists(raw(n))]
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
def load(name):
    return np.asarray(Image.open(raw(name)).convert("RGB"), np.float32)


# що лишається від сирої (px генерації: y0, y1, x0, x1): будинок без пустелі, яку модель домальовує обабіч; низ
# останнього прямокутника — лінія ходьби (ноги амфор, казана, верстата; між ними — смужка бруку під порогом)
KEEP = {
    "cq_potter": [(180, 560, 185, 1375), (560, 878, 195, 1330)],
    "cq_weaver": [(100, 600, 150, 1370), (600, 905, 230, 1345)],
    "cq_copper": [(50, 700, 215, 1350), (700, 958, 255, 1235)],
    "ps_palace": [
        (150, 1180, 35, 990),
        (1180, 1347, 40, 985),
    ],  # нижче 1347 — сходи й доріжка: геть (D830)
    "ps_fountain": [(20, 986, 95, 910)],
}
# пройом на сирій, px генерації: (верх, поріг) — висота пройому стає дверима плану (D814: 112 × f)
OPEN_PX = {
    "cq_potter": (460, 855),  # низ тенту → долівка (відкрита майстерня)
    "cq_weaver": (478, 855),
    "cq_copper": (345, 895),  # арка з віялом
    "ps_palace": (935, 1345),
}
PALACE_DOOR_PX = 511  # x середини стулок на сирій
FOUNTAIN_H = 176  # фонтан із драконом, ×1.0: чаша по коліно дорослому (32 арту), дракон — 1.2 поверху
PLANE = dict(
    cq_potter=0.9, cq_weaver=0.9, cq_copper=0.9, ps_fountain=0.9, ps_palace=1.0
)


def keyed(name):
    """Хромакей предмета: далеко від тла (верхні рядки) і в KEEP; зелена тінь на тлі й відсвіт — геть."""
    from scipy import ndimage

    im = load(name)
    bg = np.median(im[:8].reshape(-1, 3), axis=0)
    m = np.linalg.norm(im - bg, axis=2) > cb.KEY_DISTANCE
    m &= (
        im[..., 1] - np.maximum(im[..., 0], im[..., 2]) <= 10
    )  # тінь на зеленому — теж зелена
    keep = np.zeros_like(m)
    for y0, y1, x0, x1 in KEEP[name]:
        keep[y0:y1, x0:x1] = True
    m = ndimage.binary_opening(m & keep, iterations=2)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, 1 + np.nonzero(sizes >= sizes.max() * 0.02)[0])
    im[..., 1] = np.minimum(
        im[..., 1], np.maximum(im[..., 0], im[..., 2]) + 10
    )  # зелений відсвіт країв
    return im, m


def prop(name):
    """(масив, k арт/px сирої, x лівого краю маски на сирій) — висота з пройому (D814) чи FOUNTAIN_H, × план."""
    im, m = keyed(name)
    ys, xs = np.nonzero(m)
    f = PLANE[name]
    if name in OPEN_PX:
        top, sill = OPEN_PX[name]
        k = 112 * f / (sill - top)
    else:
        k = FOUNTAIN_H * f / (ys.max() - ys.min() + 1)
    a = m5.scaled(im, m, round((ys.max() - ys.min() + 1) * k), 16)
    return a, k, xs.min()


def tile(name, haze, colors=16):
    """Тайл 576 завширшки на пурпурі (як m6b6.tile без зеленого); блідо-рожевий дим із комінів — геть (на пурпурі
    він рожевий; дим — частинки кімнати, а не плями на плані)."""
    im = load(name)
    smoke = (np.minimum(im[..., 0], im[..., 2]) - im[..., 1] > 30) & (im.mean(2) > 190)
    im[smoke] = np.median(im[:24].reshape(-1, 3), axis=0)
    rgb, op = cb.shrink(im, TILES[name][3], spill=60)
    rgb = rgb * (1 - haze) + cb.HAZE * haze
    return cb.quantize(rgb, op, colors, "octree")


def build():
    for d in (CQ, PS):
        os.makedirs(d, exist_ok=True)
    m5.save(tile("cq_mid", MID_HAZE), CQ + "gen_mid.png")
    for n in ("cq_potter", "cq_weaver", "cq_copper"):
        a, k, _ = prop(n)
        m5.save(a, CQ + f"gen_{n[3:]}.png")
    m5.save(
        m5.scaled(load("cq_front"), m5.mask(load("cq_front")), FRONT_H),
        CQ + "gen_front.png",
    )
    m5.save(tile("ps_mid", MID_HAZE), PS + "gen_mid.png")
    a, k, x0 = prop("ps_palace")
    print(f"palace door centre: {(PALACE_DOOR_PX - x0) * k:.1f} art from the left edge")
    m5.save(a, PS + "gen_palace.png")
    m5.save(prop("ps_fountain")[0], PS + "gen_fountain.png")


MID_HAZE = 0.25
FRONT_H = 340  # жердина на всю висоту кадру й за нього (як aq_front)


# --- розміщення (арт, кімната): (масив, множник, x якоря, y верху, тайл?, [передній?]) ----------------------------
SKY = B + "DesertOasis/bg4/plan5.png"
CLOUDS = B + "Canyon/gen_clouds.png"
MESAS = B + "Canyon/gen_far.png"
# Ринок City [21,5] → Квартал [24,5] → Площа [27,5]: спільні плани продовжують ринкові (зсув −f × X mod 576 арту)
CQ_X, PS_X = 3 * W, 6 * W
MID_F = {
    "cq": 0.5,
    "ps": 0.6,
}  # за виміряними дверима й поверхами тайлів (двері 50 / 67 арту = 112 × f)
MID_FOOT = {
    "cq": 214,
    "ps": 203,
}  # рядок тайла, де стоять будинки (нижче — бруківка, її ховає підлога)


def region(path, top):
    a = m5.img(path).copy()
    a[:top, :, 3] = 0  # region_rect сцени: верх не показується
    return a


def backdrop(X):
    return [
        (m5.img(SKY), 0.0, 0, 0, True),
        (m5.img(CLOUDS), 0.1, m5.sh(0.1, X), 0, True),
        (region(MESAS, 112), 0.3, m5.sh(0.3, X), 0, True),
        (region(CITY + "gen_far.png", 48), 0.4, m5.sh(0.4, X), 0, True),
    ]


def floor(width):
    """Ground/Fill1 і Ground/Floor1 сцени: смуга бруку Міста (City_Terrain, рядки 256…299) і земля під нею."""
    t = m5.img(B + "Terrain/City_Terrain.png")[256:299, :width]
    out = np.zeros((VH - WALK, width, 4), np.uint8)
    out[16:] = (77, 56, 43, 255)  # Fill1: Color(0.3, 0.22, 0.17) від y 408 світу
    out[: len(t)] = np.where(t[..., 3:] > 0, t, out[: len(t)])
    return out


def on_plane(a, f, cam, cx_screen, sink=2):
    return (a, f, *m5.stand(a, f, cx_screen, cam, sink=sink), False)


# Квартал: кожен предмет посередині кадру (екран 288) при своїй камері; кузня й каплиця — ×1.0 на своїх x
CAM = dict(potter=110, weaver=640, copper=960)
FORGE_X, CHAPEL_X = (
    720,
    1600,
)  # середина спрайта, арт (кузня 356, каплиця 219 — City/gen_*.png як є)
FRONT_CAMS = (
    300,
    860,
)  # жердина ×1.3 посередині кадру: між гончарем і кузнею, між ткачем і мідником
FRONT_SINK = 108
FORGE_Y, CHAPEL_Y = (
    137 / 1.5,
    136 / 1.5,
)  # як у City.tscn: низ (піщана плита) — під смугою підлоги


def cq_planes():
    mid = m5.img(CQ + "gen_mid.png")
    forge, chapel = m5.img(CITY + "gen_forge.png"), m5.img(CITY + "gen_chapel.png")
    front = m5.img(CQ + "gen_front.png")
    return backdrop(CQ_X) + [
        (mid, MID_F["cq"], m5.sh(MID_F["cq"], 0), WALK - MID_FOOT["cq"], True),
        *[on_plane(m5.img(CQ + f"gen_{n}.png"), 0.9, c, 288) for n, c in CAM.items()],
        (forge, 1.0, round(FORGE_X - forge.shape[1] / 2), round(FORGE_Y), False),
        (chapel, 1.0, round(CHAPEL_X - chapel.shape[1] / 2), round(CHAPEL_Y), False),
        (floor(CQ_W), 1.0, 0, WALK, False),
        *[
            (fr, 1.3, *m5.stand(front, 1.3, 288, c, sink=FRONT_SINK), False, True)
            for fr, c in zip((front, front[:, ::-1].copy()), FRONT_CAMS)
        ],
    ]


FOUNTAIN_CAM = 220
PALM = B + "Decor/palm/palm_sheet.png"
PALM_X, PALM_Y = (
    1017 / 1.5,
    520 / 1.5,
)  # FrontDark/OccluderPalm у площі: як у City.tscn, scale 3 (×2 до спрайта)


def palace_x(a):
    _, k, x0 = prop("ps_palace")
    return round(DOOR_X - (PALACE_DOOR_PX - x0) * k)


def ps_planes():
    mid, palace = m5.img(PS + "gen_mid.png"), m5.img(PS + "gen_palace.png")
    fountain = m5.img(PS + "gen_fountain.png")
    palm = m5.img(PALM)[:70, :56]
    palm = np.asarray(Image.fromarray(palm).resize((112, 140), Image.NEAREST))
    return backdrop(PS_X) + [
        (mid, MID_F["ps"], m5.sh(MID_F["ps"], 0), WALK - MID_FOOT["ps"], True),
        on_plane(fountain, 0.9, FOUNTAIN_CAM, 288, sink=3),
        (palace, 1.0, palace_x(palace), WALK - len(palace), False),
        (floor(PS_W), 1.0, 0, WALK, False),
        (palm, 1.3, round(PALM_X - 26 * 2), round(PALM_Y - 70 * 2), False, True),
    ]


def guards(c, cam):
    """Вартові біля дверей (gate_guard.tscn: x 1500 і 1620 світу, кадр 64×96 по центру, offset y −44) — для масштабу."""
    g = Image.fromarray(m5.img("SampleProject/Assets/Characters/NPCs/gate_guard/sheet.png")[:96, :64])
    for x, flip in ((1500, True), (1620, True)):
        im = g.transpose(Image.FLIP_LEFT_RIGHT) if flip else g
        c.alpha_composite(im, (round(x / 1.5 - cam - 32), round(396 / 1.5 - 44 - 48)))


def sheet():
    hero = m5.img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    cp, pp = cq_planes(), ps_planes()
    frames = [
        (
            "Craft Quarter, west end (camera 0, from the market): the potter's workshop x0.9 with its kiln, the dyers' "
            "and tanners' row x0.5, the City skyline x0.4",
            m5.compose(cp, 0, (133, hero)),
        ),
        (
            "Craft Quarter, camera 450: the forge (City/gen_forge.png, moved here with the Blacksmith, D773), the dyed-"
            "cloth pole front x1.3",
            m5.compose(cp, 450, (650, hero)),
        ),
        (
            "Craft Quarter, camera 800: the carpet weaver's loom x0.9, the coppersmith x0.9",
            m5.compose(cp, 800, (1000, hero)),
        ),
        (
            "Craft Quarter, east end (camera 1152, on to the Palace Square): the coppersmith, the sky chapel "
            "(City/gen_chapel.png, moved here with the oath priest, D773)",
            m5.compose(cp, 1152, (1450, hero)),
        ),
        (
            "Palace Square, west (camera 0, from the craft quarter): the palace's outer wing with its arcade x0.6, the "
            "dragon fountain x0.9",
            m5.compose(pp, 0, (133, hero)),
        ),
        (
            "Palace Square, camera 300: the fountain, the palm front x1.3 (palm.tscn as in the market)",
            m5.compose(pp, 300, (560, hero)),
        ),
        (
            "Palace Square, east end (camera 576): the palace front with its door at x 1560 world (MayorHallDoor, door "
            "112 art), the guards stand at 1500 / 1620",
            m5.compose(pp, 576, (960, hero), lambda c: guards(c, 576)),
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
    out.save("design/shots/m6c1_craft_palace.png")
    print("sheet", out.size, flush=True)


def wiring():
    """Числа для сцен (світ = арт × 1.5): позиції спрайтів у своїх Parallax2D (scroll_offset 0, якщо не сказано)."""
    for room, planes in (("CraftQuarter", cq_planes()), ("PalaceSquare", ps_planes())):
        print(room)
        for a, f, x, y, rep, *front in planes:
            print(f"  f {f:<4} size {a.shape[1]}x{a.shape[0]}  pos ({x * 1.5:g}, {y * 1.5:g})" + ("  tile" if rep else ""))


if __name__ == "__main__":
    {"gen": gen, "build": build, "sheet": sheet, "wiring": wiring}[sys.argv[1]]()
