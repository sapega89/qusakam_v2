"""M6b-5: фони Акведука (підземелля, 4 клітинки: старий акведук під дорогою; петля зі Старих руїн заходить у його
західний край, згори в нього падають із Сухого русла, двері вгору — до підступу до брами, ґрати — у підвал брамної
вежі) і Підступу до брами (основна дорога, 2 клітинки: дорога до брами Міста; важіль, що опускає міст через
провалля, і вхід униз в акведук). Обидві кімнати — одна клітинка заввишки: лінія ходьби — рядок 256 арту (підлога
y 384 світу), камера y стоїть; Акведук 2304 арту завширшки (камера x 0…1728), Підступ 1152 (камера x 0…576).
  python -B design/shots/candidates/m6b5/m6b5.py gen    — ComfyUI (сирі PNG поруч; є — не кличе модель; ≤ 4 за запуск)
  python -B design/shots/candidates/m6b5/m6b5.py build  — плани в SampleProject/Assets/Backgrounds/{Aqueduct,GateApproach}/
  python -B design/shots/candidates/m6b5/m6b5.py sheet  — design/shots/m6b5_aqueduct_gate.png

Акведук (Maps/Aqueduct.tscn): захід відкритий у Старі руїни (там їхній край намальований аркою акведука — тут та сама
арка зсередини, дзеркально); у склепінні на 576…800 світу (арт 384…533) — пролом із Сухого русла (дно русла
провалилось у склепіння); ApproachDoor x 2891 світу — бокові двері зі сходами вгору до денного світла (підступ до
брами); CellarDoor x 3291 — арка з ґратами в підвал брамної вежі (aqueduct_cellar, важіль по той бік): ґрати —
окремий спрайт, щоб кімната могла їх підняти чи сховати, коли прапорець стоїть; схід — завал (стіна кімнати).
Далека цистерна з колонами за арками ×0.45, аркада опор каналу ×0.75, зламане водопідйомне колесо ×0.85, кам'яна
голова дракона-водомета ×0.9, склепіння з проломом ×1.0, підлога з каналом ×1.0, опора склепіння попереду ×1.3.
Підступ (Maps/GateApproach.tscn): небо, хмари й далекі гори дороги прив'язані до світу, море дюн ×0.5 і ближні дюни
×0.8 Дюн тривають, місто Провалля ближче й більше ×0.55, аркада акведука до міста ×0.75, важіль мосту на x 110 світу
(ланцюг від лебідки Провалля приходить із західного краю), водорозбірний будиночок акведука з дверима вниз
(AqueductDoor x 1291 світу), бруківка під піском, зламана колона попереду ×1.3.
Розміри — таблиця світу (D814): герой 64 арту, двері 112, ґрати 128, поверх 144, людина 96; на плані f — round(h × f).
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
AQ, GA, DUNES, RUINS = (
    B + "Aqueduct/",
    B + "GateApproach/",
    B + "Dunes/",
    B + "OldRuins/",
)
W, VH = 576, 324  # ширина тайла / кадру, висота кадру (арт)
WALK = 256  # лінія ходьби, арт (384 світу)
STYLE = cb.STYLE
MAG = cb.MAGENTA
GREEN = "solid flat chroma key green (#00FF00)"
SIDE = "seen exactly from the side, flat orthographic side elevation, no perspective"
FRONT = "seen straight on, flat orthographic front elevation, no perspective"

# геометрія сцен, арт (світ / 1.5)
AQ_W, GA_W = 2304, 1152
BREACH = (
    384,
    533,
)  # пролом у склепінні: світ 576…800 (діра в підлозі Сухого русла над ним)
APPROACH_X = 2891 / 1.5  # Aqueduct/ApproachDoor
CELLAR_X = 3291 / 1.5  # Aqueduct/CellarDoor
LEVER_X = 110 / 1.5  # GateApproach/BridgeLever
PUMP_X = 1291 / 1.5  # GateApproach/AqueductDoor

# тайли: (текст, рядки арту, зерно, ключ); генерація 1728 px завширшки (×3), шов — модель
TILES = {
    "aq_far": (
        "the far wall of a vast ancient underground aqueduct deep under the desert seen straight on, flat, no "
        "perspective: a row of tall round arches of fitted sandstone blocks opening onto a dark cistern hall behind "
        "them, rows of slender columns standing in still dark water in that hall, a few thin shafts of pale light "
        "from small holes high in the vault, deep violet and dark blue shadows, warm sandstone where the light "
        "falls, spanning the full width and filling the whole frame from the top edge to the bottom edge",
        324,
        9801,
        None,
    ),
    "aq_arcade": (
        "a row of massive square ancient sandstone piers of big fitted blocks standing apart with wide empty gaps "
        "between them, each pier with a carved band near its top and an iron ring, dark green water stains and old "
        "water lines low on the stones, a little drifted sand at their feet, spanning the full width and reaching "
        f"the bottom edge, {GREEN} above them and in every gap",
        240,
        9811,
        "green",
    ),
    # ключ читає фон з верхніх рядків (cb.shrink), а стеля — вгорі: генерація перевертається перед ключем (CEILING)
    # 9821 — «barrel vault … ribs» намалювало тунель у перспективі з темним отвором посередині (читався проходом,
    # D747) і бірюзову воду, яку не бере ключ; 9822 — те саме ліворуч, а праворуч добра смуга блоків з корінням:
    # тайл — її права половина й дзеркало (MIRROR); перемальовування лівої (9823) дало бірюзову смугу й шви
    "aq_ceiling": (
        "the ceiling of an ancient underground aqueduct seen from the side: a thin flat band of big neatly fitted cut "
        "sandstone blocks laid in even courses along the top edge only, like the top of a stone wall, no tunnel, no "
        "opening, spanning the full width and filling only the top third of the picture, its lower edge a straight "
        "row of blocks with a few short hanging dry roots and dark old water stains dripping from the joints, "
        f"nothing reaches the bottom edge, the whole lower two thirds of the picture is {GREEN}",
        110,
        9822,
        "green",
    ),
    "aq_floor": (
        "a side cross-section of the floor of an ancient underground aqueduct filling the lower four fifths of the "
        "frame and spanning the full width edge to edge: its top is a flat level walkway of big worn fitted "
        "sandstone slabs with thin drifts of sand and dark green water stains, continuing past the left and right "
        "edges, below it a square stone water conduit cut through the blocks running the whole width with a thin "
        "trickle of murky green water at its bottom, and big fitted blocks in violet shadow down to the bottom edge, "
        f"seen straight on, {MAG} above the floor",
        100,
        9831,
        "magenta",
    ),
    # ga_arcade (аркада акведука тайлом ×0.75): 9841 і 9842 — у перспективі (аркада тікає вдалину, видно канал зверху),
    # між половинами — напівпрозорий привид шва; тепер — окремий предмет ga_ruins
    "ga_ground": (
        "a side cross-section of an old paved desert road filling the lower four fifths of the frame and spanning "
        "the full width edge to edge: its top is a flat level walking surface of big worn flat paving stones half "
        "covered by drifted pale golden sand, no grass, continuing past the left and right edges, below it a bed of "
        "rubble and layered ochre and orange sandstone strata with thin cracks and small violet pebbles down to the "
        f"bottom edge, seen straight on, {MAG} above the ground",
        100,
        9851,
        "magenta",
    ),
}
CEILING = {"aq_ceiling"}
MIRROR = {
    "aq_ceiling": 900
}  # px генерації: тайл = [сира x 900… → пів ширини, її дзеркало] — безшовний

# предмети на хромакеї: (текст, ширина, висота генерації px, зерно)
PROPS = {
    "aq_stair": (
        f"an ancient arched side doorway in a short section of wall of fitted sandstone blocks {FRONT}: a tall "
        "round-topped doorway, inside it a narrow stone stair climbing steeply up toward pale daylight falling from "
        "above, the steps lit from above and dark below, worn threshold, a little drifted sand, standing alone, "
        f"nothing behind it, {MAG}",
        1024,
        1024,
        9861,
    ),
    "aq_cellar": (
        f"a low massive round arch of big fitted sandstone blocks {FRONT}, its opening closed by a heavy rusted iron "
        "grate of thick vertical bars and two crossbars set into the stone, pitch darkness behind the bars, dark "
        "water stains and green moss on the lower blocks, a small puddle at its foot, standing alone, nothing behind "
        f"it, {MAG}",
        1024,
        1024,
        9871,
    ),
    "aq_wheel": (
        f"a huge old broken wooden water-lifting wheel {SIDE}: a big spoked wheel of dark timber with a ring of clay "
        "pots tied along its rim, several pots broken, a few spokes snapped, standing on a stone base with an iron "
        f"axle, standing alone, nothing behind it, {MAG}",
        1024,
        1024,
        9881,
    ),
    "aq_spout": (
        f"a carved stone dragon head water spout set in a square panel of fitted sandstone blocks {FRONT}: the "
        "dragon's open mouth, dark green stains running down from it, a dry carved stone basin under it, worn and "
        f"cracked, standing alone, nothing behind it, {MAG}",
        1024,
        1024,
        9891,
    ),
    "aq_rubble": (
        "a tall heap of big fallen cut sandstone blocks, broken vault stones and rubble piled from the ground up to "
        "the top edge of the picture, completely blocking a tunnel, dark violet shadows between the stones, dust, "
        f"rising from the bottom edge, nothing else, {MAG}",
        512,
        1536,
        9901,
    ),
    "aq_front": (
        "one massive square stone pier of big fitted blocks in deep shadow rising from the bottom edge to the top "
        "edge of the frame, a rusted iron ring with a broken chain hanging on it, old water stains, nothing else, "
        f"{MAG}",
        512,
        1536,
        9911,
    ),
    # 9921 — будиночок ізометрично (дах і бік видно згори) — не бічний вид; 9922 — фасад, але поріг на трьох сходинках
    # над піском (двері висіли б над дорогою) і корито з помпою
    "ga_pump": (
        "the flat symmetrical front wall of a small old stone well house of a city aqueduct seen straight on, only its "
        "front face visible: a square facade of cut sandstone blocks with a low parapet and a carved band along the "
        "top, a round arched doorway in the middle that opens right at ground level with no steps in front of it, "
        "inside the doorway darkness and worn stone steps going down into the dark, drifted sand along its foot, "
        "flat orthographic front elevation, no perspective, no roof visible, no side walls visible, standing alone, "
        f"nothing behind it, {MAG}",
        1024,
        1024,
        9923,
    ),
    "ga_ruins": (
        f"the ruins of an ancient stone aqueduct {FRONT}, like a flat paper cut-out: three tall round arches of pale "
        "sandstone blocks standing in a row on square piers, broken off at both ends, a few top stones missing, "
        f"drifted sand at the feet of the piers, standing alone, nothing behind it, {MAG}",
        1536,
        768,
        9961,
    ),
    "ga_lever": (
        f"a heavy iron bridge lever mechanism on the ground {SIDE}: a low squat block of stone banded with iron "
        "straps and big bolts, a toothed iron ratchet wheel with a pawl on its side, a thick heavy iron chain coming "
        "out of the block's left side and lying straight along the flat ground to the left edge of the picture, "
        f"standing alone, nothing behind it, {MAG}",
        1536,
        512,
        9931,
    ),
    "ga_front": (
        "a tall broken leaning stone pillar of an old aqueduct with a dry thorny desert bush growing at its foot, "
        f"rising from the bottom edge of the frame, nothing else, {MAG}",
        1024,
        1024,
        9941,
    ),
}

# дорисовування по готовій композиції (маска — прозоре, як у m6b4): (текст, x0, x1 арту, зерно); підмальок пролому —
# діра Сухого русла (DryRiverbed/gen_ground.png, x 378…539), перевернута: та сама діра знизу
INPAINT = {
    # 9951 (denoise 0.8 по темному градієнту) — ламані плити без отвору
    "aq_breach": (
        "a ragged hole broken up through the stone vault ceiling, broken cut sandstone blocks along its jagged sides, "
        "darkness above, dim pale light coming down through it",
        BREACH[0] - 6,
        BREACH[1] + 6,
        9952,
    ),
}
INPAINT_DENOISE = 0.6
CEIL_ROWS = 110  # висота смуги стелі, арт

# точні розміри (арт) на своєму плані
SIZES = dict(
    aq_wheel=round(144 * 0.85),  # колесо в поверх; ×0.85
    aq_spout=round(96 * 0.9),  # панель із водометом — у зріст людини; ×0.9
    aq_rubble=WALK + 2,  # завал від підлоги до верху кадру
    aq_front=340,  # опора на всю висоту кадру й за його межі
    ga_city=round(
        288 * 0.55
    ),  # мур і вежі брами — два поверхи; ×0.55 (у Проваллі ×0.4 — 115)
    ga_ruins=round(180 * 0.75),  # аркада в 1.25 поверху; ×0.75
    ga_front=220,  # похилий стовп з уламком арки: на 150 з-під кадру визирав лише вигин арки
)
# пройоми: висота пройому — частка висоти сирої (виміряна по сирій) → висота предмета дає точний пройом (D814)
OPENING = dict(aq_stair=112, aq_cellar=128, ga_pump=112)


def raw(name):
    return os.path.join(D, f"m6b5_{name}_raw.png")


def gen_tile(name):
    text, rows, seed, _ = TILES[name]
    h = -(-rows * cb.SCALE // 16) * 16
    full = f"{text}, {STYLE}"
    img = cb.run(cb.graph(full, seed, h))
    img = cb.seam_pass(np.roll(img, cb.GW // 2, axis=1), {"seed": seed}, full, h)
    Image.fromarray(img[: rows * cb.SCALE].astype(np.uint8)).save(raw(name))
    print(name, flush=True)


def gen_prop(name):
    text, w, h, seed = PROPS[name]
    Image.fromarray(
        cb.run(cb.graph(f"{text}, {STYLE}", seed, h, width=w)).astype(np.uint8)
    ).save(raw(name))
    print(name, flush=True)


def gen_inpaint(name):
    """Перші 576 арту стелі (над далекою стіною й аркадою, ×3) як контекст; прозоре (перемальовується) — лише x0…x1
    у смузі стелі."""
    text, x0, x1, seed = INPAINT[name]
    ctx = breach_context()
    h = -(-len(ctx) * cb.SCALE // 16) * 16
    big = np.asarray(
        Image.fromarray(ctx).resize((W * cb.SCALE, len(ctx) * cb.SCALE), Image.NEAREST)
    )
    big = np.concatenate([big, np.repeat(big[-1:], h - len(big), axis=0)])
    x, y = np.arange(cb.GW), np.arange(h)
    edge = 12
    rx = np.clip(np.maximum(x0 * cb.SCALE - x, x - x1 * cb.SCALE) / edge, 0, 1)
    ry = np.clip((y - BREACH_ROWS * cb.SCALE) / edge, 0, 1)
    alpha = (np.maximum(rx[None, :], ry[:, None]) * 255).astype(np.uint8)
    up = cb.upload(np.dstack([big[..., :3], alpha]), name + ".png")
    out = cb.run(cb.graph(f"{text}, {STYLE}", seed, h, up, INPAINT_DENOISE))
    Image.fromarray(out[: len(ctx) * cb.SCALE].astype(np.uint8)).save(raw(name))
    print(name, flush=True)


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
    todo = [n for n in [*TILES, *PROPS, *INPAINT] if not os.path.exists(raw(n))]
    cost = 0
    while (
        todo and cost < 4
    ):  # ≤ 4 генерацій за запуск (ОЗП, skill comfy-backdrop); тайл — дві (шов)
        name = todo.pop(0)
        if name in INPAINT and not all(
            os.path.exists(raw(n)) for n in ("aq_far", "aq_arcade", "aq_ceiling")
        ):
            break
        (gen_tile if name in TILES else gen_prop if name in PROPS else gen_inpaint)(
            name
        )
        cost += 2 if name in TILES else 1
    s = json.load(urllib.request.urlopen(cb.API + "/system_stats"))["system"]
    print("left", todo, "ram_free GB", round(s["ram_free"] / 2**30, 1))
    if not todo:
        free()


# --- build --------------------------------------------------------------------------------------------------------
def load(name):
    return np.asarray(Image.open(raw(name)).convert("RGB"), np.float32)


def img(path):
    return np.asarray(Image.open(path).convert("RGBA"))


def tile(name, haze, colors, fill=True):
    """Тайл 576 завширшки: (дзеркало) → ключ → ×3 вниз → (суцільно до низу; стеля — до верху) → серпанок → палітра."""
    im = load(name)
    if name in MIRROR:
        half = Image.fromarray(im[:, MIRROR[name] :].astype(np.uint8)).resize(
            (cb.GW // 2, len(im))
        )
        half = np.asarray(half, np.float32)
        im = np.concatenate([half, half[:, ::-1]], axis=1)
    key = TILES[name][3]
    flip = name in CEILING
    if flip:
        im = im[::-1].copy()
    rgb, op = cb.shrink(im, key)
    if fill and key:
        rgb, op = cb.fill_down(rgb, op)
    if flip:
        rgb, op = rgb[::-1], op[::-1]
    rgb = rgb * (1 - haze) + cb.HAZE * haze
    return cb.quantize(rgb, op, colors, "octree")


def darken(arr, k):
    """Темніше й холодніше (глибина підземелля), як m6b3.darken: k — частка кольору, що лишається."""
    out = arr.copy()
    out[..., :3] = np.clip(
        arr[..., :3] * k + np.array([18, 10, 34]) * (1 - k), 0, 255
    ).astype(np.uint8)
    return out


def mask(im, plate=True, dry=False):
    """Предмет на пурпурі → маска (як m6b4.prop): тло — найрівніший край, без пурпурних тіней; plate — без плити
    землі, яку модель кладе під предмет (перший суцільний рядок у нижній третині); dry — без блакитної води."""
    from scipy import ndimage

    edges = [im[:8], im[:, :8], im[:, -8:]]
    bg = np.median(
        min((e.reshape(-1, 3) for e in edges), key=lambda e: e.std(0).sum()), axis=0
    )
    m = np.linalg.norm(im - bg, axis=2) > cb.KEY_DISTANCE
    m &= (
        np.minimum(im[..., 0], im[..., 2]) - im[..., 1] < 60
    )  # темні пурпурні тіні на тлі
    if dry:  # акведук сухий: блакитні струмки й калюжі, що модель домальовує, — геть (як m6b4 river_)
        m &= ~((im[..., 2] - im[..., 0] > 60) & (im[..., 1] - im[..., 0] > 30))
    m = ndimage.binary_opening(m, iterations=2)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, 1 + np.nonzero(sizes >= sizes.max() * 0.02)[0])
    full = np.nonzero(m.mean(1)[len(m) * 2 // 3 :] >= 0.95)[0]
    if plate and len(full):
        m[len(m) * 2 // 3 + full[0] :] = False
    return m


def scaled(im, m, h, colors=16, haze=0.0):
    """Обрізка до маски → рівно h арту заввишки, колір лише з непрозорих, своя палітра, альфа 0/255."""
    ys, xs = np.nonzero(m)
    box = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
    im, m = im[box], m[box]
    w = max(1, round(im.shape[1] * h / len(im)))
    a = np.asarray(
        Image.fromarray((m * 255).astype(np.uint8)).resize((w, h), Image.BOX),
        np.float32,
    )
    c = np.asarray(
        Image.fromarray((im * m[..., None]).astype(np.uint8)).resize((w, h), Image.BOX),
        np.float32,
    )
    rgb = c * 255 / np.maximum(a, 1)[..., None]
    rgb = rgb * (1 - haze) + cb.HAZE * haze
    return cb.quantize(rgb, a >= 128, colors, "octree")


# обрізка сирої (px генерації: y0, y1, x0, x1): низ — поріг пройому (нижче — підлога кімнати); сходи — без чоловічка
# ліворуч і без стіни обабіч
CROP = dict(
    aq_stair=(0, 886, 266, 763),
    aq_cellar=(0, 850, 0, 1024),
    aq_rubble=(0, 1367, 0, 512),
    ga_pump=(0, 733, 0, 1024),
)
# без зрізання «плити землі»: суцільні рядки тут — стіна, пройом чи завал
NO_PLATE = {"aq_stair", "aq_cellar", "aq_rubble", "ga_pump"}
DRY = {"aq_wheel", "aq_spout"}
# висота пройому на сирій, px генерації (від порога до замка арки зсередини) → висота предмета, за якої пройом — рівно
# OPENING арту (D814: двері 112, ґрати 128)
OPEN_PX = dict(aq_stair=726, aq_cellar=614, ga_pump=329)


def raw_crop(name):
    im = load(name)
    if name in CROP:
        y0, y1, x0, x1 = CROP[name]
        im = im[y0:y1, x0:x1]
    return im


def prop(name, h=None, colors=16, haze=0.0):
    im = raw_crop(name)
    m = mask(im, name not in NO_PLATE, name in DRY)
    if h is None and name in OPENING:
        ys, _ = np.nonzero(m)
        h = round(OPENING[name] * (ys.max() - ys.min() + 1) / OPEN_PX[name])
    return scaled(im, m, h or SIZES[name], colors, haze)


def ground(name, colors):
    """Смуга під ногами: рядок 0 — лінія ходьби (перший майже суцільний рядок), до низу кімнати (64 рядки)."""
    g = tile(name, 0, colors, fill=True)
    g = g[int(np.argmax((g[..., 3] > 0).mean(1) >= 0.9)) :]
    short = 320 - WALK - len(g)
    if short > 0:
        g = np.concatenate([g, g[-1 : -short - 1 : -1]])
    g = g[: 320 - WALK].copy()
    g[..., 3] = 255  # суцільна до низу кімнати
    return g


def save(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr).save(path)
    print(path, arr.shape[1], "x", arr.shape[0], flush=True)


FAR_DARK = 0.5  # дальня цистерна (як far Руїн)
CEIL_KEEP = 96  # стеля: нижче цього рядка — прозоро (корені й патьоки сягають ~93)
BREACH_ROWS = 58  # глибина пролому, арт: від верху кадру до нижньої губи смуги стелі
BREACH_GLOW = 0.45
CEIL_DARK, ARCADE_DARK = 0.7, 0.7  # стеля й опори яскраві — герой має читатись першим


def ceiling_tile():
    t = tile("aq_ceiling", 0, 12)
    t[CEIL_KEEP:, :, 3] = 0
    return t


def ceiling_strip():
    """Стеля на всю кімнату (2304 арту, без повтору): чотири тайли, у першому — пролом із Сухого русла."""
    s = np.concatenate([ceiling_tile()] * (AQ_W // W), axis=1)
    _, x0, x1, _ = INPAINT["aq_breach"]
    rgb, _ = cb.shrink(load("aq_breach"), None)
    new = rgb[:BREACH_ROWS, x0:x1]
    # модель лишила пролом чорною плямою: темне в ньому світлішає до блідого світла згори посередині (світло русла)
    yy, xx = np.mgrid[:BREACH_ROWS, : x1 - x0]
    half = (x1 - x0) / 2
    f = np.clip(1 - np.abs(xx - half) / half, 0, 1) * (1 - yy / BREACH_ROWS)
    g = (BREACH_GLOW * f * (new.mean(2) < 45))[..., None]
    new = new * (1 - g) + np.array([170, 160, 190]) * g
    s[:BREACH_ROWS, x0:x1] = cb.quantize(
        new, np.ones(new.shape[:2], bool), 12, "octree"
    )
    return darken(s, CEIL_DARK)


def breach_context():
    """Кадр Акведука на 0…576 без переднього плану, рядки 0…CEIL_ROWS: стеля поверх далекої стіни й аркади; у пролом —
    діра Сухого русла догори дриґом (її губа — на губі стелі): модель лише зводить її зі стелею."""
    far = darken(tile("aq_far", 0, 14, fill=False), FAR_DARK)
    arc = darken(tile("aq_arcade", 0, 14), ARCADE_DARK)
    c = compose(
        [
            (far, 0, 0, 0, True),
            (arc, 0, 0, ARCADE_Y, True),
            (ceiling_tile(), 0, 0, 0, True),
        ],
        0,
    )
    c = c[:CEIL_ROWS, :, :3].copy()
    _, x0, x1, _ = INPAINT["aq_breach"]
    hole = img(B + "DryRiverbed/gen_ground.png")[:BREACH_ROWS, x0:x1, :3]
    c[:BREACH_ROWS, x0:x1] = hole[::-1]
    return c


def build():
    save(darken(tile("aq_far", 0, 14, fill=False), FAR_DARK), AQ + "gen_far.png")
    save(darken(tile("aq_arcade", 0, 14), ARCADE_DARK), AQ + "gen_arcade.png")
    save(ceiling_strip(), AQ + "gen_ceiling.png")
    save(ground("aq_floor", 14), AQ + "gen_floor.png")
    save(darken(prop("aq_wheel", colors=14), 0.85), AQ + "gen_wheel.png")
    save(darken(prop("aq_spout", colors=14), 0.9), AQ + "gen_spout.png")
    save(prop("aq_stair"), AQ + "gen_stair.png")
    cellar, grate = cellar_split()
    save(cellar, AQ + "gen_cellar.png")
    save(grate, AQ + "gen_grate.png")
    save(prop("aq_rubble"), AQ + "gen_rubble.png")
    save(prop("aq_front"), AQ + "gen_front.png")  # темнить foreground_dark.tscn

    save(ground("ga_ground", 14), GA + "gen_ground.png")
    save(city(), GA + "gen_city.png")
    save(prop("ga_ruins", haze=0.2), GA + "gen_ruins.png")
    save(prop("ga_pump"), GA + "gen_pump.png")
    save(lever(), GA + "gen_lever.png")
    save(prop("ga_front"), GA + "gen_front.png")  # темнить foreground_dark.tscn


# пройом арки з ґратами на сирій (px генерації): півколо з центром (x, y) і радіусом r над прямокутником до порога
CELLAR_HOLE = (515, 470, 235)
BAR_LUM = 35  # ґрати — світліші за темряву за ними (16, 6, 25)


def cellar_split():
    """Арка з ґратами → (арка з порожнім темним пройомом, лише ґрати) — однаковий розмір і якір: у пройомі (геометрія
    CELLAR_HOLE) світле — прути, темне — темрява за ними; відчинена арка — пройом, залитий цією темрявою."""
    im = raw_crop("aq_cellar")
    m = mask(im, plate=False)
    cx, cy, r = CELLAR_HOLE
    yy, xx = np.mgrid[: len(im), : im.shape[1]]
    hole = np.where(
        yy < cy, (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r, abs(xx - cx) <= r
    )
    dark = np.median(im[hole & (im.mean(2) < BAR_LUM)], axis=0)
    bars = hole & (im.mean(2) >= BAR_LUM)
    ys, _ = np.nonzero(m)
    h = round(OPENING["aq_cellar"] * (ys.max() - ys.min() + 1) / OPEN_PX["aq_cellar"])
    opened = im.copy()
    opened[hole] = dark
    arch = scaled(opened, m, h)
    # ґрати в рамці арки: той самий обріз і масштаб, прозоре — все, крім прутів
    ys, xs = np.nonzero(m)
    box = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
    size = arch.shape[1::-1]
    a = Image.fromarray((bars[box] * 255).astype(np.uint8)).resize(size, Image.BOX)
    c = Image.fromarray((im[box] * bars[box][..., None]).astype(np.uint8)).resize(
        size, Image.BOX
    )
    a, c = np.asarray(a, np.float32), np.asarray(c, np.float32)
    grate = cb.quantize(c * 255 / np.maximum(a, 1)[..., None], a >= 110, 8, "octree")
    return arch, grate


def city():
    """Місто Провалля (та сама сира m6b4) — ближче: ×0.55, серпанок 0.25."""
    m6b4 = os.path.join(os.path.dirname(D), "m6b4", "m6b4_chasm_city_raw.png")
    im = np.asarray(Image.open(m6b4).convert("RGB"), np.float32)
    h0, w0 = im.shape[:2]
    im = im[: round(0.86 * h0), round(0.04 * w0) : round(0.955 * w0)]  # як CROP у m6b4
    return scaled(im, mask(im), SIZES["ga_city"], 14, 0.25)


# кожух важеля: висота (арт); праворуч від LEVER_CUT (px генерації) — друга рукоятка, геть (рухома — Polygon2D
# lever.tscn); вісь храпового колеса на сирій — на неї має стати вісь ручки
LEVER_H = 24
LEVER_CUT = 1213
LEVER_AXLE = (1060, 250)


def lever_geom():
    """(масив, x осі від лівого краю, висота осі над низом) — арт."""
    im = load("ga_lever")[:, :LEVER_CUT]
    m = mask(im)
    ys, xs = np.nonzero(m)
    k = LEVER_H / (ys.max() - ys.min() + 1)
    return (
        scaled(im, m, LEVER_H),
        (LEVER_AXLE[0] - xs.min()) * k,
        (ys.max() - LEVER_AXLE[1]) * k,
    )


def lever():
    a, ax, ay = lever_geom()
    print(f"lever axle: {ax:.1f} art from the left end, {ay:.1f} art above the foot")
    return a


# --- розміщення: (масив, множник, x якоря, y верху, тайл?, [передній?]) — арт, кімната; на екрані x = якір − f × камера
SKY = B + "DesertOasis/bg4/plan5.png"
CLOUDS = B + "Canyon/gen_clouds.png"
MESAS = B + "Canyon/gen_far.png"
FRONT_DARK = np.array([0.3, 0.26, 0.34])  # foreground_dark.tscn (D750)
ARCADE_Y = 24  # як аркада Руїн
FRONT_SINK = 70  # опора попереду: підніжжя під кадром (D750), верх — над ним
# Пустельна дорога [4,5] — Підступ [17,5]: 13 клітинок; Дюни [12,5] — 5. План f продовжує дорожній (дюнний), якщо
# зсунутий на −f × X (mod 576 арту — повтор 864 світу)
ROAD_X, DUNES_X = 13 * W, 5 * W
DUNES_Y, NEAR_Y = 70, 150  # як у Дюнах і Проваллі


def sh(f, x):
    return round(-f * x) % W


def stand(a, f, cx_screen, cam, sink=2):
    """Якір предмета a з множником f: центр на екрані cx_screen, коли камера на cam; низ — на лінії ходьби + sink."""
    return round(cx_screen + f * cam - a.shape[1] / 2), WALK + sink - a.shape[0]


def at(a, cx, sink=2):
    """Предмет ×1.0 центром на cx (арт, кімната), низом на лінії ходьби + sink."""
    return round(cx - a.shape[1] / 2), WALK + sink - a.shape[0]


def arch_west():
    """Арка Руїн зсередини: дзеркально, отвір — біля західного краю (у Руїнах центр 2838 при краю 2880 → тут 42)."""
    a = img(RUINS + "gen_arch.png")[:, ::-1].copy()
    return a, *at(a, 2880 - 2838)


def aq_planes():
    wheel, spout = img(AQ + "gen_wheel.png"), img(AQ + "gen_spout.png")
    stair, cellar, grate = (
        img(AQ + "gen_stair.png"),
        img(AQ + "gen_cellar.png"),
        img(AQ + "gen_grate.png"),
    )
    rubble, front = img(AQ + "gen_rubble.png"), img(AQ + "gen_front.png")
    arch, ax, ay = arch_west()
    return [
        (img(AQ + "gen_far.png"), 0.45, 0, 0, True),
        (img(AQ + "gen_arcade.png"), 0.75, 0, ARCADE_Y, True),
        (wheel, 0.85, *stand(wheel, 0.85, 330, WHEEL_CAM, sink=4), False),
        (spout, 0.9, *stand(spout, 0.9, 300, SPOUT_CAM, sink=-SPOUT_LIFT), False),
        (
            rubble,
            1.0,
            AQ_W - rubble.shape[1] + RUBBLE_OUT,
            WALK + 2 - rubble.shape[0],
            False,
        ),
        (img(AQ + "gen_ceiling.png"), 1.0, 0, 0, False),
        (arch, 1.0, ax, ay, False),
        (stair, 1.0, *at(stair, APPROACH_X), False),
        (cellar, 1.0, *at(cellar, CELLAR_X), False),
        (grate, 1.0, *at(cellar, CELLAR_X), False),
        (img(AQ + "gen_floor.png"), 1.0, 0, WALK, True),
        (
            front,
            1.3,
            *stand(front, 1.3, 288, FRONT_CAMS[0], sink=FRONT_SINK),
            False,
            True,
        ),
        (
            front,
            1.3,
            *stand(front, 1.3, 288, FRONT_CAMS[1], sink=FRONT_SINK),
            False,
            True,
        ),
    ]


WHEEL_CAM, SPOUT_CAM = 700, 1250  # камера, за якої предмет посередині кадру
SPOUT_LIFT = 40  # водомет висить на стіні над підлогою (арт)
RUBBLE_OUT = 30  # завал заходить за східний край кімнати
FRONT_CAMS = (
    900,
    1400,
)  # опори ×1.3 посередині кадру; далеко від пролому (камера ~170) і дверей (1639, 1728)


def ga_planes():
    city_a, ruins = img(GA + "gen_city.png"), img(GA + "gen_ruins.png")
    pump, lev, front = (
        img(GA + "gen_pump.png"),
        img(GA + "gen_lever.png"),
        img(GA + "gen_front.png"),
    )
    return [
        (img(SKY), 0.0, 0, 0, True),
        (img(CLOUDS), 0.1, sh(0.1, ROAD_X), 0, True),
        (img(MESAS), 0.3, sh(0.3, ROAD_X), 0, True),
        (img(DUNES + "gen_dunes.png"), 0.5, sh(0.5, DUNES_X), DUNES_Y, True),
        (city_a, 0.55, *stand(city_a, 0.55, CITY_SCREEN, 576, sink=CITY_SINK), False),
        (
            ruins,
            0.75,
            *stand(ruins, 0.75, RUINS_SCREEN, RUINS_CAM, sink=RUINS_SINK),
            False,
        ),
        (img(DUNES + "gen_near.png"), 0.8, sh(0.8, DUNES_X), NEAR_Y, True),
        (pump, 1.0, *at(pump, PUMP_X + PUMP_SHIFT), False),
        (lev, 1.0, round(LEVER_X - lever_axle()[0]), WALK + 2 - lev.shape[0], False),
        (img(GA + "gen_ground.png"), 1.0, 0, WALK, True),
        (front, 1.3, *stand(front, 1.3, 288, 300, sink=80), False, True),
    ]


CITY_SCREEN, CITY_SINK = (
    400,
    -60,
)  # місто: центр на екрані при камері 576 (східний край), підніжжя — за ближніми дюнами
RUINS_SCREEN, RUINS_CAM, RUINS_SINK = (
    300,
    120,
    -40,
)  # руїни акведука ×0.75: посередині першого екрана
PUMP_SHIFT = 0  # центр пройому будиночка відносно центру предмета, арт (пройом — на AqueductDoor)


def lever_axle():
    """Вісь храпового колеса кожуха (арт): x від його лівого краю, висота над лінією ходьби (кожух — на +2)."""
    _, ax, ay = lever_geom()
    return ax, ay - 2


def lever_handle(c, cam, pulled):
    """Ручка lever.tscn поверх кадру (Polygon2D: стрижень 42 світу, руків'я 12×10; лежить −0.9 рад, потягнута +0.9) — з
    віссю на осі колеса кожуха (README: Handle.position y = −висота осі × 1.5)."""
    d = ImageDraw.Draw(c)
    ang = 0.9 if pulled else -0.9
    px, py = LEVER_X - cam, WALK - lever_axle()[1]
    dx, dy = np.sin(ang) * 42 / 1.5, -np.cos(ang) * 42 / 1.5
    d.line([(px, py), (px + dx, py + dy)], fill=(115, 97, 77, 255), width=3)
    gx, gy = px + dx * 45 / 42, py + dy * 45 / 42
    d.rectangle([gx - 4, gy - 3, gx + 4, gy + 3], fill=(140, 56, 41, 255))


def compose(planes, cam, hero=None, extra=None):
    c = Image.new("RGBA", (W, VH), (0, 0, 0, 255))
    for a, f, x, y, rep, *front in [*planes, (None, 9, 0, 0, False, True)]:
        if front and (
            hero is not None or extra
        ):  # герой і ручка важеля — перед усім, крім переднього плану
            if extra:
                extra(c)
                extra = None
            if hero is not None:
                h = Image.fromarray(hero[1])
                c.alpha_composite(
                    h, (round(hero[0] - cam - h.width / 2), WALK - h.height)
                )
                hero = None
        if a is None:
            continue
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
    ap, gp = aq_planes(), ga_planes()
    frames = [
        (
            "Aqueduct, west (camera 0): the Old Ruins' arch seen from inside (the loop from the ruins), the breach in the "
            "vault at x 576-800 world (the fall from the Dry Riverbed), the cistern x0.45, the piers x0.75",
            compose(ap, 0, (460, hero)),
        ),
        (
            "Aqueduct, parallax-shifted (camera 700): the broken water wheel x0.85, the vault pier x1.3 passes",
            compose(ap, WHEEL_CAM, (WHEEL_CAM + 200, hero)),
        ),
        (
            "Aqueduct, camera 1250: the dragon-head spout x0.9",
            compose(ap, SPOUT_CAM, (SPOUT_CAM + 330, hero)),
        ),
        (
            "Aqueduct, east end (camera 1728): ApproachDoor (x 2891 world) - the stair up to daylight; CellarDoor (x 3291) "
            "- the barred arch into the gatehouse cellar (the grate its own sprite); the rockfall closes the tunnel",
            compose(ap, 1728, (APPROACH_X + 70, hero)),
        ),
        (
            "Gate Approach, west (camera 0, from the Chasm): the bridge lever at x 110 world with the chain from the "
            "Chasm's winch (the handle drawn as lever.tscn's Polygon2D, not pulled); the road's sky and mesas, the dunes "
            "continue",
            compose(gp, 0, (150, hero), lambda c: lever_handle(c, 0, False)),
        ),
        (
            "Gate Approach, parallax-shifted (camera 300): the aqueduct arcade x0.75, the City nearer x0.55, the pillar "
            "front x1.3",
            compose(gp, 300, (560, hero), lambda c: lever_handle(c, 300, True)),
        ),
        (
            "Gate Approach, east end (camera 576, on to the City Gates): the aqueduct well house with the door down "
            "(AqueductDoor, x 1291 world)",
            compose(gp, 576, (PUMP_X + 80, hero)),
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
    out.save("design/shots/m6b5_aqueduct_gate.png")
    print("sheet", out.size, flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build, "sheet": sheet}[sys.argv[1]]()
