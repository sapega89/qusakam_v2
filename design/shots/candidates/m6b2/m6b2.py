"""M6b-2: фони вершини Мези (бічна гілка, 2 клітинки, закрита, вхід — розколина з Підйому на Месу на сході) і Зариного
привалу (оаза на дорозі, 2 клітинки, криниця з ґратами — вниз у Старі руїни, ключ ватажка). Обидві кімнати 1152×320 арту
(1728×480 світу), лінія ходьби — рядок 256 арту (підлога y 384 світу), камера x 0…576 арту, y стоїть.
  python -B design/shots/candidates/m6b2/m6b2.py gen    — ComfyUI (сирі PNG поруч; є — не кличе модель; ≤ 4 за запуск)
  python -B design/shots/candidates/m6b2/m6b2.py build  — плани в SampleProject/Assets/Backgrounds/{MesaTop,ZahraRest}/
  python -B design/shots/candidates/m6b2/m6b2.py sheet  — design/shots/m6b2_mesa_oasis.png

Вершина Мези: високо над пустелею — рівнина далеко внизу (×0.2), сусідні столові гори (×0.5), бандитська вежа-дозор
(×0.9: табір на дюнах і засідка на підйомі — їхні; пояснює скриню нагорі). Підлога — `MesaClimb/gen_floor.png` (та сама
скеля, що й підйом), передній план — `Canyon/gen_rock.png` (як на підйомі).
Привал: спільне небо і далекі гори дороги (desert_backdrop_open, прив'язані до світу — продовжують Пустельну дорогу),
оаза ×0.6 (ставок, пальми, напівзасипані руїни — те, що під нею), стоянка караванів ×0.85, пальма ×0.9, криниця ×1.0
на x 600 арту (WellDoor, 900 світу) з іржавими ґратами («ключ, зелений від старої води»), очерет попереду ×1.3.
Розміри — таблиця світу (D814): герой 64 арту, двері/прохід 112, намет 160, пальма 256; на плані f — round(h × f).
"""

import json
import os
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, "Scripts/Tools")
import comfy_backdrop as cb

D = os.path.dirname(os.path.abspath(__file__))
B = "SampleProject/Assets/Backgrounds/"
MESA, OASIS = B + "MesaTop/", B + "ZahraRest/"
W, VH, RW = 576, 324, 1152  # ширина тайла / кадру, висота кадру, ширина кімнати (арт)
WALK = 256  # лінія ходьби, арт (384 світу)
STYLE = cb.STYLE
MAG, GREEN = cb.MAGENTA, cb.CHROMA
GREEN_SKY = "the whole sky above is solid flat chroma key green (#00FF00)"
MAG_SKY = "the whole sky above is solid flat magenta (#FF00FF)"

# Пустельна дорога [4,5] — Зарин привал [10,5]: лівий край привалу на 6 × 864 світу правіше; план з множником f
# продовжує дорожній, якщо зсунутий на −f × X (mod 864 — повтор Parallax2D)
ROAD_X = 6 * 864

# тайли: (текст, рядки арту, зерно, ключ); генерація 1728 px завширшки (×3), шов — модель (comfy_backdrop, seam model)
TILES = {
    "mesa_far": (
        "a vast flat empty desert plain seen from the top of a very high cliff, far below and far away: the flat "
        "sandy ground stretches to a straight distant horizon line across the middle of the picture, low hazy "
        "flat-topped mesas along the horizon, soft dune ripples, a thin pale winding caravan road across the plain, "
        f"spanning the full width and reaching the bottom edge, {GREEN_SKY}",
        324,
        9101,
        "green",
    ),
    "mesa_buttes": (
        "a row of separate tall flat-topped red and ochre sandstone buttes and mesas standing apart with wide gaps "
        "between them, their flat tops in the upper half of the picture with a few dry thorn bushes, sheer layered "
        "cliff sides with horizontal strata and cool violet shadows going straight down to the bottom edge, "
        f"{GREEN_SKY} and in the gaps between them",
        300,
        9111,
        "green",
    ),
    "oasis_mid": (
        "a lush desert oasis seen from the side: a calm blue pool along the bottom with reeds and green grass on its "
        "banks, a grove of date palms with olive green fronds reaching about half the picture's height, between them "
        "half-buried ancient sandstone ruins, broken carved columns and a fallen stone arch sinking into the sand, "
        f"spanning the full width and reaching the bottom edge, {MAG_SKY}",
        284,
        9201,
        "magenta",
    ),
    "oasis_ground": (
        "a side cross-section of solid desert ground at an oasis filling the lower four fifths of the frame and "
        "spanning the full width edge to edge: its top is a flat level walking surface of packed pale sand with "
        "small flat stones, a few short tufts of green grass and patches of darker damp sand, continuing past the "
        "left and right edges, below it layered ochre, orange and pale tan sandstone strata with thin cracks and "
        f"small violet pebbles down to the bottom edge, seen straight on, {MAG} above the ground",
        100,
        9211,
        "magenta",
    ),
}

# предмети на хромакеї: (текст, ширина, висота генерації px, зерно)
PROPS = {
    # 9121 — хатинка нагорі, вогонь горів, а мотузка звисала петлею
    "mesa_lookout": (
        "an old wooden lookout tower seen exactly from the side, flat orthographic side elevation, no perspective: "
        "four tall lashed wooden poles leaning together with cross braces, a small plank platform with a low "
        "railing on top, a tattered faded red cloth flag on a short pole above it, a ring of stones with cold grey "
        "ashes and a broken clay jar at its foot, no fire, no people, no hanging ropes, standing alone, "
        f"nothing behind it, {MAG}",
        1024,
        1280,
        9122,
    ),
    # 9221 — колодязь згори (3/4) на піщаному пагорбі; 9231 — «caravan» намалювало причіп-фургон і верблюда
    "oasis_well": (
        "an old stone well seen exactly from the side at eye level, flat orthographic side elevation, no "
        "perspective, no top view: a low wide cylindrical curb of big ancient carved sandstone blocks seen as a "
        "rectangle, dark green water stains on its lower stones, a heavy rusty iron grate with a big padlock on top "
        "of the curb seen edge-on, two wooden posts with a crossbar and a crank winch above it, a rope with a wooden "
        f"bucket hanging down, standing alone, nothing behind it, {MAG}",
        1024,
        1024,
        9222,
    ),
    "oasis_camp": (
        "a desert nomads' resting place seen exactly from the side, flat orthographic side elevation, no "
        "perspective: a faded red and cream striped cloth awning stretched over four wooden poles with guy ropes, "
        "under it a woven rug, cushions, clay water jars and a pile of grain sacks, a wooden saddle on a low rail "
        f"beside it, no animals, no people, no vehicles, all in one group, nothing behind it, {MAG}",
        1280,
        1024,
        9232,
    ),
    "oasis_palm": (
        "one single tall date palm tree seen from the side, a slightly curved ringed trunk, a full crown of long "
        "arching olive green fronds and hanging clusters of orange dates, standing alone directly on the bottom "
        f"edge of the frame, no ground, nothing behind it, {MAG}",
        768,
        1280,
        9241,
    ),
    "oasis_front": (
        "a dense clump of tall reeds and cattails with a few broad palm fronds sticking up between them, rising from "
        f"the bottom edge of the frame, nothing else, {MAG}",
        1024,
        1024,
        9251,
    ),
}

MID_K = 154 / 175  # найвища пальма оази — 175 арту в тайлі 576 (крона з рядка 10, стовбур до трави на ~185)
HOLE = (215, 282, 6, 18)  # x0, x1, y0, y1 (над нею — трава, не чіпати): темна пляма на поверхні gen_ground

# точні розміри (арт) на своєму плані: round(таблиця × f)
SIZES = dict(
    mesa_lookout=round(160 * 0.9),  # як намет (2.5 H) — бандитська споруда; ×0.9
    oasis_well=112,  # прохід = двері (1.75 H); ×1.0
    oasis_camp=round(160 * 0.85),  # намет 2.5 H; ×0.85
    oasis_palm=round(256 * 0.9),  # пальма 4 H; ×0.9
    oasis_front=150,  # передній план — за геометрією (structure), як MountainPath/gen_front
)


def raw(name):
    return os.path.join(D, f"m6b2_{name}_raw.png")


def gen_tile(name):
    text, rows, seed, _ = TILES[name]
    h = -(-rows * cb.SCALE // 16) * 16
    full = f"{text}, {STYLE}"
    img = cb.run(cb.graph(full, seed, h))
    img = cb.seam_pass(
        np.roll(img, cb.GW // 2, axis=1), {"seed": seed}, full, h
    )  # шов — у середину й перемалювати
    Image.fromarray(img[: rows * cb.SCALE].astype(np.uint8)).save(raw(name))
    print(name, flush=True)


def gen_prop(name):
    text, w, h, seed = PROPS[name]
    Image.fromarray(
        cb.run(cb.graph(f"{text}, {STYLE}", seed, h, width=w)).astype(np.uint8)
    ).save(raw(name))
    print(name, flush=True)


# Qwen-Image кладе предмети в ізометрії на плиту землі й не слухає «no fire» — правка Qwen-Image-Edit-2511
# (comfy_sprite.edit, як m6b1): плиту — у пурпур, вогонь і мотузки — геть
KEEP = "Keep the same style, colours, size and position."
EDITS = {
    "mesa_lookout": (
        "Remove the campfire and its flames, leave only the ring of stones with grey ashes. Remove the ropes hanging "
        "from the tower. Replace all the shadows on the background with flat magenta (#FF00FF). " + KEEP,
        9123,
    ),
    "oasis_camp": (
        "Replace the sand platform under the camp and its edges with flat magenta (#FF00FF), so the poles, the rug, "
        "the jars, the sacks and the rail stand directly on the bottom edge. Keep the striped awning, the poles, the "
        "rug, the cushions, the jars, the sacks and the saddle exactly as they are. " + KEEP,
        9233,
    ),
}


def edit(name):
    import comfy_sprite as cs

    src = np.asarray(Image.open(raw(name)).convert("RGBA"))
    out = cs.edit(src, *EDITS[name])
    Image.fromarray(out.astype(np.uint8)).convert("RGB").resize((src.shape[1], src.shape[0]), Image.BOX).save(
        raw(name + "_fix")
    )
    print(name + "_fix", flush=True)


def gen():
    todo = [n for n in [*TILES, *PROPS] if not os.path.exists(raw(n))]
    cost = 0
    while todo and cost < 4:  # ≤ 4 генерацій за запуск (ОЗП, skill comfy-backdrop); тайл — дві (шов)
        name = todo.pop(0)
        (gen_tile if name in TILES else gen_prop)(name)
        cost += 2 if name in TILES else 1
    s = json.load(urllib.request.urlopen(cb.API + "/system_stats"))["system"]
    print("left", todo, "ram_free GB", round(s["ram_free"] / 2**30, 1))
    if not todo:
        fix()
        for name in EDITS:
            if not os.path.exists(raw(name + "_fix")):
                edit(name)
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
    p = raw(name + "_fix") if os.path.exists(raw(name + "_fix")) else raw(name)
    return np.asarray(Image.open(p).convert("RGB"), np.float32)


# шов моделі лишив у оазі напівпрозорий привид (розмита пальма, сходинка ставка): смуга x0…x1 арту перемальовується
# з малим denoise (як comfy_backdrop --repaint) — будова лишається, привид стає суцільним
REPAINT = {"oasis_mid": (190, 390, 0.6)}


def fix():
    for name, (x0, x1, dn) in REPAINT.items():
        if os.path.exists(raw(name + "_fix")):
            continue
        text, _, seed, _ = TILES[name]
        img = np.asarray(Image.open(raw(name)).convert("RGB"), np.float32)
        h = -(-len(img) // 16) * 16
        pad = np.concatenate([img, np.repeat(img[-1:], h - len(img), axis=0)])
        x = np.arange(cb.GW)
        ramp = np.clip(np.maximum(x0 * cb.SCALE - x, x - x1 * cb.SCALE) / 24, 0, 1)  # 0 — смуга
        alpha = np.repeat((ramp * 255).astype(np.uint8)[None, :, None], h, axis=0)
        up = cb.upload(np.concatenate([pad.astype(np.uint8), alpha], 2), "m6b2_repaint.png")
        out = cb.run(cb.graph(f"{text}, {STYLE}", seed + 2, h, up, dn))
        w = (1 - ramp)[None, :, None]
        Image.fromarray((out * w + pad * (1 - w))[: len(img)].astype(np.uint8)).save(raw(name + "_fix"))
        print(name + "_fix", flush=True)


def tile(name, haze, colors, fill=True, k=1.0):
    """Тайл 576 × k завширшки: (масштаб сирої) → ключ → ×3 вниз → (суцільно до низу) → серпанок → палітра."""
    raw_img = load(name)
    if k != 1.0:
        h, w = raw_img.shape[:2]
        size = (round(w * k / 3) * 3, round(h * k / 3) * 3)
        raw_img = np.asarray(Image.fromarray(raw_img.astype(np.uint8)).resize(size, Image.LANCZOS), np.float32)
    rgb, op = cb.shrink(raw_img, TILES[name][3])
    if fill:
        rgb, op = cb.fill_down(rgb, op)
    rgb = rgb * (1 - haze) + cb.HAZE * haze
    return cb.quantize(rgb, op, colors, "octree")


def prop(name, shade=0.0, colors=16, shadow=False):
    """Предмет на пурпурі → рівно SIZES[name] арту заввишки, своя палітра, альфа 0/255 (як m6b1.prop)."""
    from scipy import ndimage

    img = load(name)
    edges = [
        img[:8],
        img[:, :8],
        img[:, -8:],
    ]  # тло — найрівніший край (низ — земля під предметом)
    bg = np.median(
        min((e.reshape(-1, 3) for e in edges), key=lambda e: e.std(0).sum()), axis=0
    )
    m = np.linalg.norm(img - bg, axis=2) > cb.KEY_DISTANCE
    m &= (
        np.minimum(img[..., 0], img[..., 2]) - img[..., 1] < 60
    )  # темні пурпурні тіні на тлі
    m = ndimage.binary_opening(m, iterations=2)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, 1 + np.nonzero(sizes >= sizes.max() * 0.02)[0])
    # плита землі, яку модель кладе під предмет усупереч підказці: від першого суцільного рядка в нижній третині — геть
    full = np.nonzero(m.mean(1)[len(m) * 2 // 3 :] >= 0.99)[0]
    if len(full):
        m[len(m) * 2 // 3 + full[0] :] = False
    if shadow:  # темно-пурпурна тінь, яку модель кидає на тло (криниця)
        r, g, b = img[..., 0], img[..., 1], img[..., 2]
        m &= ~((r - g > 40) & (b - g > 40) & (np.abs(r - b) < 70) & (r + g + b < 450))
        m = ndimage.binary_opening(m, iterations=1)
    ys, xs = np.nonzero(m)
    img, m = (
        img[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
        m[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
    )
    h = SIZES[name]
    w = max(1, round(img.shape[1] * h / len(img)))
    a = np.asarray(
        Image.fromarray((m * 255).astype(np.uint8)).resize((w, h), Image.BOX),
        np.float32,
    )
    c = np.asarray(
        Image.fromarray((img * m[..., None]).astype(np.uint8)).resize(
            (w, h), Image.BOX
        ),
        np.float32,
    )
    rgb = c * 255 / np.maximum(a, 1)[..., None] * (1 - shade)
    return cb.quantize(rgb, a >= 128, colors, "octree")


def save(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr).save(path)
    print(path, arr.shape[1], "x", arr.shape[0], flush=True)


def build():
    save(tile("mesa_far", 0.35, 12), MESA + "gen_far.png")
    save(tile("mesa_buttes", 0.35, 14), MESA + "gen_buttes.png")
    save(prop("mesa_lookout"), MESA + "gen_lookout.png")
    # без fill: заливка вниз тягнула з крон пальм вертикальні смуги (B71); ×MID_K — пальма рівно 154 арту (256 × 0.6)
    save(tile("oasis_mid", 0.12, 16, fill=False, k=MID_K), OASIS + "gen_mid.png")
    # земля: рядок 0 — лінія ходьби (перший майже суцільний рядок), нижче — суцільно
    g = tile("oasis_ground", 0, 14, fill=True)
    top = int(np.argmax((g[..., 3] > 0).mean(1) >= 0.9))
    g = g[top:]
    # темна пляма на поверхні ходьби читалась ямою: у колір піску навколо
    band = g[HOLE[2] : HOLE[3], HOLE[0] : HOLE[1]]
    cols, n = np.unique(g[2:6, HOLE[0] : HOLE[1], :3].reshape(-1, 3), axis=0, return_counts=True)
    sand = cols[n.argmax()]  # найчастіший колір піску — з палітри
    band[(band[..., :3].astype(int).sum(-1) < 560) & (band[..., 3] > 0), :3] = sand.astype(np.uint8)  # і світліший обідок
    assert len(g) >= 320 - WALK, len(g)  # до низу кімнати (480 світу)
    save(g, OASIS + "gen_ground.png")
    save(prop("oasis_well", shadow=True), OASIS + "gen_well.png")
    for n in ("oasis_camp", "oasis_palm"):
        save(prop(n), OASIS + "gen_" + n.split("_")[1] + ".png")
    save(prop("oasis_front"), OASIS + "gen_front.png")  # темнить foreground_dark.tscn


# --- розміщення: (файл, множник, x якоря, y верху, тайл?) — арт, кімната, при камері 0; на екрані x = якір − f × камера
def img(path):
    return np.asarray(Image.open(path).convert("RGBA"))


def h_of(path):
    return img(path).shape[0]


def w_of(path):
    return img(path).shape[1]


def stand(path, f, cx_screen, cam, sink=2):
    """Якір предмета з множником f: центр на екрані cx_screen, коли камера на cam; низ — на лінії ходьби + sink."""
    return round(cx_screen + f * cam - w_of(path) / 2), WALK + sink - h_of(path)


BUTTES_Y = 88  # верхівки сусідніх мес (рядок ~87 тайла) — на ~175: нижче за наш погляд, ми на найвищій
MID_Y = 17  # ставок оази (рядки ~183–249 тайла) — над лінією ходьби, крони пальм з ~26
SKY = B + "DesertOasis/bg4/plan5.png"
CLOUDS = B + "Canyon/gen_clouds.png"
FRONT_DARK = np.array([0.3, 0.26, 0.34])  # foreground_dark.tscn (D750)


def mesa_planes():
    lx, ly = stand(
        MESA + "gen_lookout.png", 0.9, 288, 162
    )  # дозор на x ~450 кімнати: посередині, коли камера 162
    return [
        (SKY, 0.0, 0, 0, True),
        (CLOUDS, 0.1, 0, 0, True),
        (MESA + "gen_far.png", 0.2, 0, 0, True),
        (MESA + "gen_buttes.png", 0.5, 0, BUTTES_Y, True),
        (MESA + "gen_lookout.png", 0.9, lx, ly, False),
        ("fill", 1.0, 0, 272, False),  # Ground/Fill1 сцени: Color(0.36, 0.24, 0.17) з y 408 світу
        (B + "MesaClimb/gen_floor.png", 1.0, 0, WALK, True),
        # розколина вниз на підйом (ClimbDoorEntrance, x 1560 світу = 1040 арту; низ посередині на підлозі)
        (
            B + "Decor/mesa_cleft/mesa_cleft_sheet.png",
            1.0,
            1040 - 55,
            WALK - 110,
            False,
        ),
        # передній план: FrontDark/OccluderRock (Canyon/gen_rock ×2.2 у світі = ×1.467 арту), x 1100 світу
        (
            "front:" + B + "Canyon/gen_rock.png",
            1.3,
            round(1100 / 1.5),
            round(520 / 1.5),
            False,
        ),
    ]


def zahra_planes():
    wx, wy = stand(
        OASIS + "gen_well.png", 1.0, 600, 0
    )  # криниця: центр на x 600 кімнати (WellDoor 900 світу)
    cx, cy = stand(OASIS + "gen_camp.png", 0.85, 210, 0, sink=6)  # ковдра на піщаній кромці, не над водою
    px, py = stand(
        OASIS + "gen_palm.png", 0.9, 420, 312, sink=3
    )  # праворуч від криниці, коли герой біля неї
    fx, fy = stand(
        OASIS + "gen_front.png", 1.3, 470, 576, sink=40
    )  # схід, екран 2; низ під кадром
    sh = lambda f: round(-f * ROAD_X / 1.5) % W  # noqa: E731 — зсув плану, що продовжує дорожній (арт)
    return [
        (SKY, 0.0, 0, 0, True),
        (CLOUDS, 0.1, sh(0.1), 0, True),
        (B + "Canyon/gen_far.png", 0.3, sh(0.3), 0, True),
        (OASIS + "gen_mid.png", 0.6, 0, MID_Y, True),
        (OASIS + "gen_camp.png", 0.85, cx, cy, False),
        (OASIS + "gen_palm.png", 0.9, px, py, False),
        (OASIS + "gen_well.png", 1.0, wx, wy, False),
        (OASIS + "gen_ground.png", 1.0, 0, WALK, True),
        ("front:" + OASIS + "gen_front.png", 1.3, fx, fy, False),
    ]


def view(planes, cam, hero=None):
    c = Image.new("RGBA", (W, VH), (0, 0, 0, 255))
    for path, f, x, y, rep in [*planes, (None, 9, 0, 0, False)]:
        if hero and f > 1:  # герой — перед усім, крім переднього плану
            h = Image.fromarray(hero[1])
            c.alpha_composite(h, (hero[0] - cam - h.width // 2, WALK - h.height))
            hero = None
        if not path:
            continue
        if path == "fill":
            c.paste((92, 61, 43, 255), (0, y, W, VH))
            continue
        front = path.startswith("front:")
        a = img(path.removeprefix("front:"))
        if front:  # foreground_dark.tscn: модуляція, Canyon/gen_rock — ×2.2/1.5
            if "gen_rock" in path:
                a = np.asarray(
                    Image.fromarray(a).resize(
                        (round(a.shape[1] * 2.2 / 1.5), round(a.shape[0] * 2.2 / 1.5)),
                        Image.NEAREST,
                    )
                )
                y = y - a.shape[0] // 2  # Sprite2D centered
                x = x - a.shape[1] // 2
            a = a.copy()
            a[..., :3] = (a[..., :3] * FRONT_DARK).astype(np.uint8)
        im = Image.fromarray(a)
        sx = x - f * cam
        if rep:
            sx = sx % im.width - im.width
            while sx < W:
                c.alpha_composite(im, (round(sx), y)) if y >= 0 else c.paste(
                    im.crop((0, -y, im.width, im.height)),
                    (round(sx), 0),
                    im.crop((0, -y, im.width, im.height)),
                )
                sx += im.width
        else:
            l = Image.new("RGBA", (W, VH))
            l.paste(im, (round(sx), y))
            c.alpha_composite(l)
    return np.asarray(c)


def sheet():
    hero = img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    mp, zp = mesa_planes(), zahra_planes()
    frames = [
        (
            "Mesa top, west (camera 0): the desert plain far below x0.2, neighbouring buttes x0.5, the bandit lookout x0.9",
            view(mp, 0, (200, hero)),
        ),
        (
            "Mesa top, parallax-shifted (camera 288): far x0.2 and buttes x0.5 slide against the lookout x0.9 and the floor; the rock x1.3 passes",
            view(mp, 288, (560, hero)),
        ),
        (
            "Mesa top, east end (camera 576): the cleft down to the Mesa Climb (ClimbDoor, x 1560 world) where the hero arrives",
            view(mp, 576, (1000, hero)),
        ),
        (
            "Zahra's Rest, west (camera 0, coming from the Desert Road): road sky and far mesas continue; oasis x0.6, caravan stop x0.85",
            view(zp, 0, (140, hero)),
        ),
        (
            "Zahra's Rest, the well (camera 312): stone well with the locked iron grate (WellDoor, x 900 world), palm x0.9",
            view(zp, 312, (560, hero)),
        ),
        (
            "Zahra's Rest, east end (camera 576, on to the Dunes): reeds foreground x1.3",
            view(zp, 576, (1000, hero)),
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
    out.save("design/shots/m6b2_mesa_oasis.png")
    print("sheet", out.size, flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build, "sheet": sheet}[sys.argv[1]]()
