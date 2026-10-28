"""M6b-3: фони Дюн (основна дорога, 4 клітинки, стежка вгору до табору бандитів) і Старих руїн (підземелля, 5 клітинок
у сцені, за ключем ватажка з криниці на Зариному привалі, петля далі в акведук). Обидві кімнати — одна клітинка
заввишки: лінія ходьби — рядок 256 арту (підлога y 384 світу), камера y стоїть; Дюни 2304 арту завширшки (камера x
0…1728), Руїни 2880 (камера x 0…2304).
  python -B design/shots/candidates/m6b3/m6b3.py gen    — ComfyUI (сирі PNG поруч; є — не кличе модель; ≤ 4 за запуск)
  python -B design/shots/candidates/m6b3/m6b3.py build  — плани в SampleProject/Assets/Backgrounds/{Dunes,OldRuins}/
  python -B design/shots/candidates/m6b3/m6b3.py sheet  — design/shots/m6b3_dunes_ruins.png

Дюни: спільне небо й далекі гори дороги (desert_backdrop_open, прив'язані до світу — продовжують привал), море дюн ×0.5,
голова кам'яного колоса, засипана по підборіддя ×0.6 (руїни лежать просто під дюнами — клітинки [11…15,7]), дюна з
табором на гребені ×0.7, ближні дюни ×0.8, сторожовий кіл бандитів ×0.9, початок стежки (прохід до табору) ×1.0 на
x 2700 світу (граф: «стежка на дюни» на 3–4 екрані), пісок під ногами, сухий кущ попереду ×1.3.
Руїни: темна зала далекої колонади зі світлом із тріщин ×0.45, зламані колони ×0.75, безголова статуя з чашею ×0.85,
рельєф дракона ×0.9 (дракони — «як божества», D196 lore), завал ×0.9, стеля ×1.0, шахта криниці з мотузкою й відром
×1.0 (WellDoor, x 151 світу), арка акведука на сході ×1.0 (прохід далі), плити підлоги, темна колона попереду ×1.3.
Розміри — таблиця світу (D814): герой 64 арту, двері/прохід 112, ґрати 128, поверх 144, людина 96; на плані f — round(h × f).
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
DUNES, RUINS = B + "Dunes/", B + "OldRuins/"
W, VH = 576, 324  # ширина тайла / кадру, висота кадру (арт)
WALK = 256  # лінія ходьби, арт (384 світу)
STYLE = cb.STYLE
MAG = cb.MAGENTA
GREEN_SKY = "the whole sky above is solid flat chroma key green (#00FF00)"

# Пустельна дорога [4,5] — Дюни [12,5]: лівий край дюн на 8 × 864 світу правіше; план з множником f продовжує
# дорожній, якщо зсунутий на −f × X (mod 864 — повтор Parallax2D)
ROAD_X = 8 * 864

# тайли: (текст, рядки арту, зерно, ключ); генерація 1728 px завширшки (×3), шов — модель
TILES = {
    "dunes_far": (
        # 9301 — «a sea of dunes» намалювало море з прибоєм
        "an endless dry desert of tall smooth sand dunes with sharp curved crests layered one behind another into "
        "the distance, pale golden and peach sand with soft cool violet shadows on their lee sides, wind ripples, no "
        f"water anywhere, spanning the full width and reaching the bottom edge, {GREEN_SKY}",
        240,
        9302,
        "green",
    ),
    "dunes_near": (
        "low rolling sand dune crests close by, golden sand with fine wind ripples and violet shadows, a few dry yellow "
        "grass tufts and small dark stones, spanning the full width and reaching the bottom edge, the dunes fill only "
        f"the lower half of the picture, {GREEN_SKY}",
        120,
        9311,
        "green",
    ),
    "dunes_ground": (
        "a side cross-section of solid desert ground in the dunes filling the lower four fifths of the frame and "
        "spanning the full width edge to edge: its top is a flat level walking surface of loose pale golden sand "
        "with fine wind ripples and a few small pebbles, no grass, continuing past the left and right edges, below "
        "it layered ochre, orange and pale tan sandstone strata with thin cracks and small violet pebbles down to "
        f"the bottom edge, seen straight on, {MAG} above the ground",
        100,
        9321,
        "magenta",
    ),
    "ruins_far": (
        "a vast dim underground hall of an ancient civilisation deep under the desert: rows of colossal carved "
        "sandstone columns receding into darkness, broken round arches high above, shafts of pale light falling "
        "through cracks in the vaulted ceiling onto heaps of sand, still dark water pools on the stone floor, deep "
        "violet and dark blue shadows, warm sandstone where the light falls, spanning the full width and filling the "
        "whole frame from the top edge to the bottom edge",
        324,
        9401,
        None,
    ),
    "ruins_arcade": (
        "a row of thick ancient carved sandstone columns standing apart with wide empty gaps between them, their "
        "shafts broken off at different heights, one fallen lintel block resting across two of them, carved bands "
        "and worn scale patterns, rubble and drifted sand at their feet, dark green water stains low on the stones, "
        "spanning the full width and reaching the bottom edge, solid flat chroma key green (#00FF00) above them and "
        "in every gap",
        240,
        9411,
        "green",
    ),
    # ключ читає фон з верхніх рядків (cb.shrink), а стеля — вгорі: генерація перевертається перед ключем (CEILING)
    "ruins_ceiling": (
        # 9421 — два темні стовпи звисали до нижнього краю й різались ним
        "the ceiling of an ancient underground hall seen from the side: a thin band of rough dark rock and broken "
        "carved sandstone vault blocks along the top edge only, spanning the full width and filling only the top "
        "third of the picture, its lower edge ragged with a few short hanging dry roots and short stalactites, thin "
        "trickles of sand from the cracks, nothing reaches the bottom edge, the whole lower two thirds of the picture "
        "is solid flat chroma key green (#00FF00)",
        110,
        9422,
        "green",
    ),
    "ruins_floor": (
        "a side cross-section of the stone floor of an ancient underground hall filling the lower four fifths of the "
        "frame and spanning the full width edge to edge: its top is a flat level walking surface of big worn carved "
        "sandstone flagstones with thin drifts of sand and dark green water stains, continuing past the left and "
        "right edges, below it big fitted stone blocks and dark rubble in violet shadow down to the bottom edge, seen "
        f"straight on, {MAG} above the floor",
        100,
        9431,
        "magenta",
    ),
}
CEILING = {"ruins_ceiling"}
CEIL_GHOSTS, CEIL_LIP = ((178, 258), (318, 392)), 47  # стовпці (арт) привидів шва; рядок, нижче якого — геть

# предмети на хромакеї: (текст, ширина, висота генерації px, зерно)
SIDE = "seen exactly from the side, flat orthographic side elevation, no perspective"
FRONT = "seen straight on, flat orthographic front elevation, no perspective"
PROPS = {
    "dunes_stake": (
        f"a bandits' warning post in the desert {SIDE}: a tall crooked wooden pole stuck in a small mound of sand, "
        "a bleached horned lizard skull tied on its top, long tattered red cloth strips hanging from it, a short "
        "crossbar with a few hanging bones, standing alone, nothing behind it, "
        f"{MAG}",
        768,
        1280,
        9331,
    ),
    "dunes_colossus": (
        f"the colossal weathered sandstone head of an ancient statue buried in the sand up to its chin, {FRONT}, "
        "facing the viewer, a calm stern face with closed eyes, a tall crown carved with a coiled winged dragon, "
        "deep cracks and a chipped nose, sand drifted against it, standing alone, nothing behind it, "
        f"{MAG}",
        1024,
        1024,
        9341,
    ),
    # 9353 — схил до правого верхнього кута, обрізаний за краями кадру: прямий зріз збоку; тепер — уся дюна
    # 9351, 9352 — табір на гребені цілком: частокіл 0.14–0.2 висоти пагорба, тож точний частокіл (128 × f) робив
    # дюну 450–640 арту — вищу за кадр; табір на карті на два ряди вище за дюни ([12,3] над [12,5]), тож у кадрі —
    # схил зі стежкою, а з-за гребеня вгорі виглядають лише вістря частоколу й прапор
    "dunes_camp": (
        f"a single tall sand dune standing alone {SIDE}, its whole outline visible with empty background on both "
        "sides and above: a long gentle brightly lit slope on the right rising to a sharp crest near the top left, "
        "a steep cool violet shadowed face falling from the crest to the left, a narrow footpath marked by short "
        "wooden stakes with red rags and a sagging rope handrail climbing the right slope up to the crest, nothing "
        f"on the crest, no people, nothing behind it, {MAG}",
        1280,
        1024,
        9354,
    ),
    # 9361 — між жердинами стояла темна плита, як двері посеред дюн
    "dunes_trailhead": (
        f"the start of a bandits' trail into the dunes {SIDE}: two tall crooked wooden poles leaning together and "
        "lashed with rope at the top into a rough narrow open gateway, the space between the poles is empty, torn "
        "red cloth strips and a coil of rope hanging from the crossing, a plain blank wooden plank nailed on one "
        "pole, a few short stakes in the sand beside it, standing alone, nothing behind it, "
        f"{MAG}",
        1024,
        1280,
        9363,
    ),
    "dunes_front": (
        "a big dry thorny desert bush with tangled bare branches and a bleached horned animal skull lying at its "
        f"foot, rising from the bottom edge of the frame, nothing else, {MAG}",
        1024,
        1024,
        9371,
    ),
    # 9441 — колодязь у перспективі: внизу ще одна кругла яма — читалась ходом униз (D747); 9442 — широка кругла
    # цямрина 218 арту завширшки (криниця привалу — 97), гігантська поруч із героєм
    "ruins_well": (
        "a narrow vertical old well shaft of carved sandstone blocks seen exactly from the side, like a tall narrow "
        "stone chimney rising from the flat ground straight up to the top edge of the picture, five times taller "
        "than wide, its front wall broken open in the lower part showing the dark inside, a rope hanging down inside "
        "it, a wooden bucket standing on the ground in the opening, a few fallen blocks and a little sand at its "
        f"foot, nothing else, {MAG}",
        512,
        1536,
        9443,
    ),
    "ruins_statue": (
        f"a broken ancient statue {SIDE}: a tall robed figure standing on a square carved plinth, its head broken "
        "off at the neck, holding a wide shallow stone bowl in both hands, cracked sandstone with dark green water "
        f"stains, sand heaped at its foot, standing alone, nothing behind it, {MAG}",
        768,
        1280,
        9451,
    ),
    "ruins_relief": (
        f"a huge ancient carved sandstone slab standing upright, {FRONT}: a deep relief of a great winged dragon "
        "coiled in a circle, small robed figures kneeling in a row below it with raised hands, worn and cracked, "
        "one upper corner broken off, dark green water stains and moss at the bottom, standing alone, nothing "
        f"behind it, {MAG}",
        1024,
        1024,
        9461,
    ),
    "ruins_arch": (
        f"a massive ancient stone archway {FRONT}: a round arch of big fitted sandstone blocks on two thick piers, "
        "its keystone carved as a dragon head, the opening pitch dark, a dry stone water channel coming out of it "
        "along the bottom, dark green water stains on the lower blocks, sand drifted against the piers, standing "
        f"alone, nothing behind it, {MAG}",
        1024,
        1024,
        9481,
    ),
    "ruins_front": (
        "one tall broken ancient carved stone column in deep shadow rising from the bottom edge to the top edge of "
        "the frame, its shaft cracked and chipped, a few dry roots hanging along it, nothing else, "
        f"{MAG}",
        512,
        1536,
        9491,
    ),
}

# обрізка сирої перед ключем (частки: y0, y1, x0, x1): схил — без гребеня з частоколом, прапором і вартовим (табір
# вище за кадр, на карті — два ряди вгору; модель не слухає «no people»); завал — без арочки з темним отвором (D747:
# намальований отвір — це прохід)
CROP = {}
SHADE = {}
# 9471 (завал із капітеллю-драконом) прибрано: блідий, з порожнистим барабаном, як приклеєний — четвертий екран
# тримають колона попереду й зала

# точні розміри (арт) на своєму плані: round(таблиця × f)
SIZES = dict(
    dunes_stake=round(128 * 0.9),  # кіл заввишки як ґрати (2 H); ×0.9
    dunes_colossus=round(256 * 0.6),  # над піском 4 H (як пальма); ×0.6
    dunes_camp=WALK + 10 - 30,  # дюна від лінії ходьби (+10) до гребеня на рядку 30 кадру; табір — за гребенем
    dunes_trailhead=112,  # прохід = двері (1.75 H); ×1.0
    dunes_front=150,  # передній план — за геометрією, як ZahraRest/gen_front
    ruins_well=WALK
    + 2
    + 4,  # шахта від верху кадру (−4) до підлоги (+2): мотузка до долу
    ruins_statue=round(160 * 0.85),  # постамент + фігура в 1.5 людини = 2.5 H; ×0.85
    ruins_relief=round(144 * 0.9),  # плита в поверх; ×0.9
    ruins_arch=144,  # арка акведука — поверх (прохід далі на схід); ×1.0
    ruins_front=340,  # колона на всю висоту кадру й за його межі
)


def raw(name):
    return os.path.join(D, f"m6b3_{name}_raw.png")


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


# правки Qwen-Image-Edit-2511 (comfy_sprite.edit, як m6b2) — вписуються після першого погляду на сирі
KEEP = "Keep the same style, colours, size and position."
EDITS = {
    # 9354: вартовий на гребені (модель не слухає «no people») і правий схил, обрізаний краєм картинки
    "dunes_camp": (
        "Remove the person standing on the top of the dune. Make the right side of the dune slope down smoothly to "
        "the bottom so that the whole dune ends before the right edge of the picture, with flat magenta (#FF00FF) "
        "background to the right of it and above it. Replace the distant dunes on the left with flat magenta "
        "(#FF00FF). Keep the path, the stakes, the rope, the red rags and the dune's colours. " + KEEP,
        9355,
    ),
    "dunes_trailhead": (
        "Remove the stone wall, the dark doorway and the rocks behind the two wooden poles and replace them and the "
        "distant dunes with flat magenta (#FF00FF). Keep the two poles, the crossbar, the ropes, the red cloth, the "
        "plank, the short stakes and the sand at their feet exactly as they are. "
        + KEEP,
        9364,
    ),
}


def edit(name):
    import comfy_sprite as cs

    src = np.asarray(Image.open(raw(name)).convert("RGBA"))
    out = cs.edit(src, *EDITS[name])
    Image.fromarray(out.astype(np.uint8)).convert("RGB").resize(
        (src.shape[1], src.shape[0]), Image.BOX
    ).save(raw(name + "_fix"))
    print(name + "_fix", flush=True)


def free():
    urllib.request.urlopen(
        urllib.request.Request(
            cb.API + "/free",
            json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )
    print("models freed")


def gen():
    todo = [n for n in [*TILES, *PROPS] if not os.path.exists(raw(n))]
    cost = 0
    while (
        todo and cost < 4
    ):  # ≤ 4 генерацій за запуск (ОЗП, skill comfy-backdrop); тайл — дві (шов)
        name = todo.pop(0)
        (gen_tile if name in TILES else gen_prop)(name)
        cost += 2 if name in TILES else 1
    s = json.load(urllib.request.urlopen(cb.API + "/system_stats"))["system"]
    print("left", todo, "ram_free GB", round(s["ram_free"] / 2**30, 1))
    if not todo:
        for name in EDITS:
            if not os.path.exists(raw(name + "_fix")):
                edit(name)
        free()


# --- build --------------------------------------------------------------------------------------------------------
def load(name):
    p = raw(name + "_fix") if os.path.exists(raw(name + "_fix")) else raw(name)
    return np.asarray(Image.open(p).convert("RGB"), np.float32)


def tile(name, haze, colors, fill=True):
    """Тайл 576 завширшки: ключ → ×3 вниз → (суцільно до низу; стеля — до верху) → серпанок → палітра."""
    img = load(name)
    key = TILES[name][3]
    flip = name in CEILING
    if flip:
        img = img[::-1].copy()
    rgb, op = cb.shrink(img, key)
    if fill and key:
        rgb, op = cb.fill_down(rgb, op)
    if flip:
        rgb, op = rgb[::-1], op[::-1]
    rgb = rgb * (1 - haze) + cb.HAZE * haze
    return cb.quantize(rgb, op, colors, "octree")


def darken(arr, k):
    """Темніше й холодніше (глибина підземелля): k — частка кольору, що лишається; тінь — у фіолет."""
    out = arr.copy()
    out[..., :3] = np.clip(
        arr[..., :3] * k + np.array([18, 10, 34]) * (1 - k), 0, 255
    ).astype(np.uint8)
    return out


def dune(img, reach=0.9, p=0.6):
    """Дюна з обрізаними краями (модель тягне схили за межі картинки) → цілий силует і його маска. Лівий схил — той,
    що намалювала модель, а там, де він сягає краю, — далі прямою з його ж нахилом (виміряним на 0.7 висоти); правий —
    опукла крива від гребеня до низу, (x / reach × висота)^p: пряма робила з дюни піраміду. Полотно розширюється
    повтором крайніх стовпців. Маска — геометрія, не колір: фіолетова тінь схилу близька до пурпурного тла, і ключ
    кольором робив у ній ряботиння."""
    bg = np.median(img[:24].reshape(-1, 3), axis=0)
    op = np.linalg.norm(img - bg, axis=2) > cb.KEY_DISTANCE
    h = len(img)
    yc = int(np.argmax(op.any(1)))
    xc = float(np.nonzero(op[yc])[0].mean())
    y7 = round(h * 0.7)
    k = (y7 - yc) / (xc - np.argmax(op[y7]))
    lr = (h - yc) / reach  # ширина правого схилу, px
    pl = max(0, round((h - yc) / k - xc))  # лівий схил дістає низу за лівим краєм
    pr = max(0, round(xc + lr - img.shape[1]))
    img = np.pad(img, ((0, 0), (pl, pr), (0, 0)), mode="edge")
    op = np.pad(op, ((0, 0), (pl, pr)), mode="edge")
    xc += pl
    yy, xx = np.mgrid[:h, : img.shape[1]]
    left = (yy - yc >= (xc - xx) * k) & (op | (xx < pl))  # лівий: малюнок моделі, у доданому — пряма
    right = yy - yc >= (h - yc) * (np.clip(xx - xc, 0, None) / lr) ** p
    inside = np.where(xx <= xc, left, right) & (yy >= yc)
    img[~inside] = bg
    return img, inside


def prop(name, h=None, shade=0.0, colors=16):
    """Предмет на пурпурі → рівно h (SIZES[name]) арту заввишки, своя палітра, альфа 0/255 (як m6b2.prop)."""
    from scipy import ndimage

    img = load(name)
    shape = None
    if name == "dunes_camp":
        img, shape = dune(img)
    if name in CROP:
        y0, y1, x0, x1 = CROP[name]
        h0, w0 = img.shape[:2]
        img = img[round(y0 * h0) : round(y1 * h0), round(x0 * w0) : round(x1 * w0)]
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
    if shape is not None:
        m = shape
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, 1 + np.nonzero(sizes >= sizes.max() * 0.02)[0])
    # плита землі, яку модель кладе під предмет усупереч підказці: від першого суцільного рядка в нижній третині — геть
    full = np.nonzero(m.mean(1)[len(m) * 2 // 3 :] >= 0.95)[0]
    if len(full):
        m[len(m) * 2 // 3 + full[0] :] = False
    ys, xs = np.nonzero(m)
    img, m = (
        img[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
        m[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
    )
    h = h or SIZES[name]
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


def ground(name, colors):
    """Смуга під ногами: рядок 0 — лінія ходьби (перший майже суцільний рядок), нижче — суцільно до низу кімнати."""
    g = tile(name, 0, colors, fill=True)
    top = int(np.argmax((g[..., 3] > 0).mean(1) >= 0.9))
    g = g[top:]
    short = (
        320 - WALK - len(g)
    )  # до низу кімнати (480 світу): бракує — нижні рядки віддзеркалюються
    if short > 0:
        g = np.concatenate([g, g[-1 : -short - 1 : -1]])
    return g


def build():
    save(tile("dunes_far", 0.3, 12), DUNES + "gen_dunes.png")
    save(tile("dunes_near", 0.1, 12), DUNES + "gen_near.png")
    save(ground("dunes_ground", 14), DUNES + "gen_ground.png")
    save(prop("dunes_stake"), DUNES + "gen_stake.png")
    save(prop("dunes_colossus"), DUNES + "gen_colossus.png")
    # стежка підіймається на захід, до гребеня ліворуч (табір на карті над західними екранами, [12,3])
    save(prop("dunes_camp"), DUNES + "gen_slope.png")
    save(prop("dunes_trailhead"), DUNES + "gen_trailhead.png")
    save(prop("dunes_front"), DUNES + "gen_front.png")  # темнить foreground_dark.tscn

    save(darken(tile("ruins_far", 0, 14), 0.5), RUINS + "gen_far.png")
    save(darken(tile("ruins_arcade", 0, 14, fill=True), 0.8), RUINS + "gen_arcade.png")
    # шов моделі лишив під стелею два напівпрозорі звислі брили до нижнього краю — зрізані під губою стелі
    c = tile("ruins_ceiling", 0, 12)
    for x0, x1 in CEIL_GHOSTS:
        c[CEIL_LIP:, x0:x1, 3] = 0
    save(c, RUINS + "gen_ceiling.png")
    save(ground("ruins_floor", 14), RUINS + "gen_floor.png")
    for n in (
        "ruins_well",
        "ruins_statue",
        "ruins_relief",
        "ruins_arch",
    ):
        save(prop(n, shade=SHADE.get(n, 0)), RUINS + "gen_" + n.split("_")[1] + ".png")
    save(prop("ruins_front"), RUINS + "gen_front.png")  # темнить foreground_dark.tscn


# --- розміщення: (файл, множник, x якоря, y верху, тайл?) — арт, кімната, при камері 0; на екрані x = якір − f × камера
def img(path):
    return np.asarray(Image.open(path).convert("RGBA"))


def stand(path, f, cx_screen, cam, sink=2):
    """Якір предмета з множником f: центр на екрані cx_screen, коли камера на cam; низ — на лінії ходьби + sink."""
    a = img(path)
    return round(cx_screen + f * cam - a.shape[1] / 2), WALK + sink - a.shape[0]


SKY = B + "DesertOasis/bg4/plan5.png"
CLOUDS = B + "Canyon/gen_clouds.png"
FRONT_DARK = np.array([0.3, 0.26, 0.34])  # foreground_dark.tscn (D750)
DUNES_Y, NEAR_Y = (
    70,
    150,
)  # гребені моря дюн ~ рядок 110…150 кадру; ближні дюни — над лінією ходьби
ARCADE_Y = 16
FRONT_SINK = 70  # колона попереду: підніжжя під кадром (D750), верх — над ним
CAMP_X = 1800  # початок стежки до табору, арт (2700 світу)
WELL_X = 151 / 1.5  # WellDoor, арт
ARCH_X = 2838  # центр арки акведука: її отвір — біля східного краю кімнати (2880)


def sh(f):
    return round(-f * ROAD_X / 1.5) % W  # зсув плану, що продовжує дорожній (арт)


def slope_at(cam):
    """Схил ×0.85: правий край — на 40 арту правіше від початку стежки (екран 288 при камері cam)."""
    a = img(DUNES + "gen_slope.png")
    return round(288 + 40 + 0.85 * cam - a.shape[1]), WALK + 10 - a.shape[0]


def dunes_planes():
    return [
        (SKY, 0.0, 0, 0, True),
        (CLOUDS, 0.1, sh(0.1), 0, True),
        (B + "Canyon/gen_far.png", 0.3, sh(0.3), 0, True),
        (DUNES + "gen_dunes.png", 0.5, 0, DUNES_Y, True),
        (
            DUNES + "gen_colossus.png",
            0.6,
            *stand(DUNES + "gen_colossus.png", 0.6, 330, 700, sink=-14),
            False,
        ),
        (DUNES + "gen_near.png", 0.8, 0, NEAR_Y, True),
        # схил зі стежкою: підніжжя (правий нижній кут) — біля початку стежки, коли вона посередині кадру
        (DUNES + "gen_slope.png", 0.85, *slope_at(CAMP_X - 288), False),
        (
            DUNES + "gen_stake.png",
            0.9,
            *stand(DUNES + "gen_stake.png", 0.9, 440, 0, sink=3),
            False,
        ),
        (
            DUNES + "gen_trailhead.png",
            1.0,
            *stand(DUNES + "gen_trailhead.png", 1.0, CAMP_X, 0),
            False,
        ),
        (DUNES + "gen_ground.png", 1.0, 0, WALK, True),
        (
            "front:" + DUNES + "gen_front.png",
            1.3,
            *stand(DUNES + "gen_front.png", 1.3, 288, 420, sink=80),
            False,
        ),
        (
            "front:" + DUNES + "gen_front.png",
            1.3,
            *stand(DUNES + "gen_front.png", 1.3, 288, 1150, sink=80),
            False,
        ),
    ]


def ruins_planes():
    return [
        (RUINS + "gen_far.png", 0.45, 0, 0, True),
        (RUINS + "gen_arcade.png", 0.75, 0, ARCADE_Y, True),
        (
            RUINS + "gen_statue.png",
            0.85,
            *stand(RUINS + "gen_statue.png", 0.85, 330, 700),
            False,
        ),
        (
            RUINS + "gen_relief.png",
            0.9,
            *stand(RUINS + "gen_relief.png", 0.9, 288, 1152),
            False,
        ),
        (
            RUINS + "gen_well.png",
            1.0,
            *stand(RUINS + "gen_well.png", 1.0, WELL_X, 0),
            False,
        ),
        (
            RUINS + "gen_ceiling.png",
            1.0,
            0,
            0,
            True,
        ),  # перед шахтою: та виходить зі стелі
        (
            RUINS + "gen_arch.png",
            1.0,
            *stand(RUINS + "gen_arch.png", 1.0, ARCH_X, 0),
            False,
        ),
        (RUINS + "gen_floor.png", 1.0, 0, WALK, True),
        (
            "front:" + RUINS + "gen_front.png",
            1.3,
            *stand(RUINS + "gen_front.png", 1.3, 288, 450, sink=FRONT_SINK),
            False,
        ),
        (
            "front:" + RUINS + "gen_front.png",
            1.3,
            *stand(RUINS + "gen_front.png", 1.3, 288, 1950, sink=FRONT_SINK),
            False,
        ),
    ]


def view(planes, cam, hero=None):
    c = Image.new("RGBA", (W, VH), (0, 0, 0, 255))
    for path, f, x, y, rep in [*planes, (None, 9, 0, 0, False)]:
        if hero and f > 1:  # герой — перед усім, крім переднього плану
            h = Image.fromarray(hero[1])
            c.alpha_composite(h, (round(hero[0] - cam - h.width / 2), WALK - h.height))
            hero = None
        if not path:
            continue
        front = path.startswith("front:")
        a = img(path.removeprefix("front:"))
        if front:
            a = a.copy()
            a[..., :3] = (a[..., :3] * FRONT_DARK).astype(np.uint8)
        im = Image.fromarray(a)
        sx = x - f * cam
        layer = Image.new("RGBA", (W, VH))
        if rep:
            sx = sx % im.width - im.width
            while sx < W:
                layer.paste(im, (round(sx), y))
                sx += im.width
        else:
            layer.paste(im, (round(sx), y))
        c.alpha_composite(layer)
    return np.asarray(c)


def sheet():
    hero = img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    dp, rp = dunes_planes(), ruins_planes()
    frames = [
        (
            "Dunes, west (camera 0, from Zahra's Rest): the road's sky and far mesas continue; dunes x0.5, near dunes "
            "x0.8, the bandits' warning post x0.9",
            view(dp, 0, (133, hero)),
        ),
        (
            "Dunes, parallax-shifted (camera 560): the buried colossus x0.6 (the Old Ruins lie under the dunes), the "
            "thorn bush x1.3 passes",
            view(dp, 560, (850, hero)),
        ),
        (
            "Dunes, the camp path (camera 1512): the trailhead x1.0 at x 2700 world (CampDoor), the dune slope with "
            "the path going up out of view x0.85 (the camp is two cells up)",
            view(dp, CAMP_X - 288, (CAMP_X - 30, hero)),
        ),
        ("Dunes, east end (camera 1728, on to the Chasm)", view(dp, 1728, (2200, hero))),
        (
            "Old Ruins, west (camera 0): the well shaft with the rope and bucket (WellDoor, x 151 world); far hall "
            "x0.45, broken colonnade x0.75, ceiling x1.0",
            view(rp, 0, (230, hero)),
        ),
        (
            "Old Ruins, parallax-shifted (camera 560): the statue with the bowl x0.85, the dark column x1.3 passes",
            view(rp, 560, (900, hero)),
        ),
        ("Old Ruins, the dragon relief x0.9 (camera 1152)", view(rp, 1152, (1380, hero))),
        (
            "Old Ruins, east end (camera 2304): the aqueduct arch x1.0, the way on east (Aqueduct)",
            view(rp, 2304, (2700, hero)),
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
    out.save("design/shots/m6b3_dunes_ruins.png")
    print("sheet", out.size, flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build, "sheet": sheet}[sys.argv[1]]()
