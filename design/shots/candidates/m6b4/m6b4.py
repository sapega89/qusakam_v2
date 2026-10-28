"""M6b-4: фони Провалля (основна дорога, 1 екран: дорогу перед містом розрізало провалля; з дальнього боку герой
скидає міст важелем — короткий шлях) і Сухого русла (підземелля під проваллям, 1 клітинка у сцені: падіння згори,
діра в підлозі вниз, в акведук). Обидві кімнати — рівно один екран: камера не рухається ні по x, ні по y, тож
плани — одна композиція (без шва) і на кадрі множники не зсувають нічого; вони записані для глибини й порядку.
Лінія ходьби — рядок 256 арту (підлога y 384 світу).
  python -B design/shots/candidates/m6b4/m6b4.py gen    — ComfyUI (сирі PNG поруч; є — не кличе модель; ≤ 4 за запуск)
  python -B design/shots/candidates/m6b4/m6b4.py build  — плани в SampleProject/Assets/Backgrounds/{Chasm,DryRiverbed}/
  python -B design/shots/candidates/m6b4/m6b4.py sheet  — design/shots/m6b4_chasm_riverbed.png

Провалля (Maps/Chasm.tscn): краї — арт 0…107 і 469…576 (світ 0…160, 704…864), між ними прірва; міст FlagBridge
шарнірно на східному краї (світ 720, 384), проліт 144…720 світу = 384 арту; піднятий — стоїть сторч (обертання π/2).
Небо, хмари й далекі гори дороги (desert_backdrop_open, прив'язані до світу), море дюн ×0.5 і ближні дюни ×0.8 Дюн
(продовжують їх), над дюнами визирає місто ×0.4 (мета за проваллям), земля з урвищем ×1.0 (краї — земля Дюн, прірва
домальована моделлю по їхній картинці), підйомний міст і лебідка ×1.0, скеля попереду ×1.3.
Сухе русло (Maps/DryRiverbed.tscn): стіни по краях екрана, згори відкрито (падають із провалля 160…704 світу),
діра в підлозі 576…800 світу (арт 384…533) — у склепіння акведука. Дальня стіна ущелини зі щілиною неба ×0.45,
береги з валунами й корчем ×0.75, розбитий човен ×0.85, дно русла з діркою в склепіння ×1.0, валуни попереду ×1.3.
Розміри — таблиця світу (D814): герой 64 арту, поверх 144, людина 96; на плані f — round(h × f).
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
CHASM, RIVER, DUNES = B + "Chasm/", B + "DryRiverbed/", B + "Dunes/"
W, VH = 576, 324  # кадр (арт)
WALK = 256  # лінія ходьби, арт (384 світу)
STYLE = cb.STYLE
MAG = cb.MAGENTA
SIDE = "seen exactly from the side, flat orthographic side elevation, no perspective"
FRONT = "seen straight on, flat orthographic front elevation, no perspective"

# геометрія сцен, арт (світ / 1.5)
GAP = (107, 469)  # прірва Провалля: світ 160…704
PIVOT = 480  # шарнір мосту: світ 720
SPAN = 384  # проліт мосту: світ 576 (144…720)
HOLE = (384, 533)  # діра Сухого русла: світ 576…800
OPEN = (107, 469)  # отвір згори в русло: світ 160…704 (прірва над ним)

# цілі кадри / смуги без шва (камера стоїть): (текст, рядки арту, зерно, ключ)
TILES = {
    # 9501, 9502 — жива вода (водоспад, потік), хоч «dry» і «no water anywhere»; 9502 ще й арка зі сходами — намальований
    # отвір, а ходу там нема (D747). Слова river / water / waterfall модель малює водою — їх тут нема
    "river_far": (
        "a dim narrow underground gorge deep under the desert: tall walls of smooth wind-carved and water-worn "
        "layered sandstone with long horizontal grooves and pale bands rising on both sides and leaning together "
        "overhead, a thin crack high above at the top edge letting in a strip of pale sky and soft pale light, the "
        "floor between them is bone dry pale sand with rounded pebbles and a few bleached dead branches, deep violet "
        "and dark blue shadows, spanning the full width and filling the whole frame from the top edge to the bottom "
        "edge",
        324,
        9503,
        None,
    ),
    "river_banks": (
        "a dry old riverbank seen from the side: big smooth rounded water-worn boulders and pebbles piled along an "
        "old riverbed, a bleached dead driftwood log stranded across them, dry pale dead reeds, cracked dried mud, "
        "spanning the full width and reaching the bottom edge, the stones fill only the lower half of the picture, "
        "solid flat chroma key green (#00FF00) above them and in every gap",
        120,
        9511,
        "green",
    ),
    "river_ground": (
        "a side cross-section of a dry riverbed floor filling the lower four fifths of the frame and spanning the "
        "full width edge to edge: its top is a flat level walking surface of cracked dried pale mud with scattered "
        "small rounded pebbles and a few empty shells, continuing past the left and right edges, below it layers of "
        "grey and ochre river sediment, sand and rounded stones in violet shadow down to the bottom edge, seen "
        f"straight on, {MAG} above the floor",
        100,
        9521,
        "magenta",
    ),
}

# предмети на хромакеї: (текст, ширина, висота генерації px, зерно)
PROPS = {
    # 9601 — настил ледь під кутом (схил 0.064) і стовп під правим кінцем: вирівнюється зсувом (SHEAR), стовп і ланцюг
    # під балкою зрізаються; 9602 — «perfectly level» дав причал над водою, у перспективі згори
    "chasm_bridge": (
        f"a long heavy wooden drawbridge lying flat, {SIDE}: a very long low straight deck of dark weathered timber "
        "planks on two long squared beams, iron bands and big round bolts along the beams, a big iron hinge at the "
        "right end, a heavy iron ring with a short chain at the left end, a low rope hand-rail on short wooden posts "
        "along the top, the bridge ten times longer than it is tall, the whole bridge visible with a little empty "
        f"space at both ends, nothing under it, nothing behind it, {MAG}",
        1728,
        384,
        9601,
    ),
    "chasm_winch": (
        f"a heavy wooden bridge winch standing on the ground {SIDE}: two stout squared timber posts joined by "
        "crossbeams, a big wooden drum wound with a thick iron chain between them, an iron crank handle, iron "
        "brackets and bolts, the chain running off to the right along the ground, standing alone, nothing behind "
        f"it, {MAG}",
        1024,
        1024,
        9611,
    ),
    "chasm_city": (
        f"a walled desert city far away {FRONT}: long sandstone city walls with square crenellated towers, a big "
        "gatehouse with two tall towers in the middle, behind the walls pale domes, flat roofs and one tall slender "
        f"palace tower, small red banners, standing alone, nothing in front of it, nothing behind it, {MAG}",
        1536,
        768,
        9621,
    ),
    "chasm_front": (
        "a dark jagged rock spur with sharp broken edges and a dead twisted tree root clinging to it, rising from "
        f"the bottom edge of the frame, nothing else, {MAG}",
        1024,
        1024,
        9631,
    ),
    "river_boat": (
        f"an old wooden river boat wreck lying stranded on dry ground, {SIDE}: a small long boat hull of grey "
        "weathered planks, its side broken open with missing planks, a snapped short mast, a coil of old rope, a "
        f"little sand drifted against it, standing alone, nothing behind it, {MAG}",
        1280,
        768,
        9641,
    ),
    # 9651 (нависла скеля у верхніх кутах) прибрано: брила з пласким уступом висіла в повітрі, як платформа (A15)
    "river_front": (
        "a pile of big dark smooth round water-worn boulders with a bleached dead branch sticking out of them, "
        f"rising from the bottom edge of the frame, nothing else, {MAG}",
        1024,
        1024,
        9661,
    ),
}

# дорисовування по готовій композиції (маска — прозоре, як у cb.seam_pass): (текст, x0, x1 арту, зерно)
INPAINT = {
    # 9701, 9711 (з нуля, denoise 1): у прірві — кам'яна арка-тунель і летючі брили, у русла — світла сходинка без діри;
    # тепер підмальок — темний градієнт (cut), і модель лише перемальовує його (INPAINT_DENOISE): порожнеча лишається
    "chasm_gap": (
        "a side cross-section of the dark abyss of a deep chasm: on the left and on the right sheer broken rock faces "
        "of layered orange sandstone with cracks and a few hanging dry roots drop straight down, between them a wide "
        "deep void of darkness fading from deep violet to black, the far rock wall of the chasm barely visible in "
        "the gloom",
        GAP[0] - 6,
        GAP[1] + 6,
        9702,
    ),
    "river_hole": (
        "a side cross-section of a dry riverbed floor with a deep square hole broken through it: the broken edges of "
        "the floor on the left and right show cut sandstone blocks of an old buried vault, between them the hole is "
        "a deep dark void fading from deep violet to black",
        HOLE[0] - 6,
        HOLE[1] + 6,
        9712,
    ),
}
INPAINT_DENOISE = 0.75
OPENING = dict(chasm_gap=GAP, river_hole=HOLE)
FAR_DARK = 0.45  # дальня стіна русла: 0.6 сперечалась із героєм
CTX_TOP = 200  # дорисовування бачить кадр від цього рядка до низу
LIP = 2  # рядки під лінією ходьби, що лишаються від землі: край — рівно на колізії

# точні розміри (арт) на своєму плані: висота, крім мосту й навислої скелі (ширина)
SIZES = dict(
    chasm_winch=96,  # лебідка в зріст людини (1.5 H); ×1.0
    chasm_city=round(288 * 0.4),  # мур і вежі брами — два поверхи; ×0.4
    chasm_front=150,  # передній план — як Dunes/gen_front
    river_boat=round(64 * 0.85),  # човен із пеньком щогли — 1 H; ×0.85
    river_front=150,
)
# вертикальний зсув сирої (стовпці донизу на k × x: стовпчики поручня лишаються прямовисними) і рядок, нижче якого —
# геть (стовп-опора й ланцюг під балкою), px генерації
SHEAR = dict(chasm_bridge=(0.064, 344))
# обрізка сирої перед ключем (частки: y0, y1, x0, x1): місто — без піску й людини перед брамою, мур — до крайніх веж
CROP = dict(chasm_city=(0, 0.86, 0.04, 0.955))
# лише настил, без поручня: піднятий міст із поручнем читався драбиною (драбин на дорозі нема)
NO_RAIL = {"chasm_bridge"}
WIDTHS = dict(chasm_bridge=SPAN)  # нависла скеля — над краєм отвору (OPEN 107)


def raw(name):
    return os.path.join(D, f"m6b4_{name}_raw.png")


def gen_tile(name):
    text, rows, seed, _ = TILES[name]
    h = -(-rows * cb.SCALE // 16) * 16
    img = cb.run(cb.graph(f"{text}, {STYLE}", seed, h))
    Image.fromarray(img[: rows * cb.SCALE].astype(np.uint8)).save(raw(name))
    print(name, flush=True)


def gen_prop(name):
    text, w, h, seed = PROPS[name]
    Image.fromarray(
        cb.run(cb.graph(f"{text}, {STYLE}", seed, h, width=w)).astype(np.uint8)
    ).save(raw(name))
    print(name, flush=True)


def gen_inpaint(name):
    """Кадр від CTX_TOP до низу (×3) як контекст; прозоре (перемальовується) — лише x0…x1 нижче лінії ходьби + LIP."""
    text, x0, x1, seed = INPAINT[name]
    ctx = context(name)
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
    up = cb.upload(np.dstack([big[..., :3], alpha]), name + ".png")
    out = cb.run(cb.graph(f"{text}, {STYLE}", seed, h, up, INPAINT_DENOISE))
    Image.fromarray(out[: len(ctx) * cb.SCALE].astype(np.uint8)).save(raw(name))
    print(name, flush=True)


# правки Qwen-Image-Edit-2511 (comfy_sprite.edit, як m6b3) — після першого погляду на сирі
KEEP = "Keep the same style, colours, size and position."
EDITS = {
    # 9641: човен стоїть у піщаному пагорбі на всю ширину картинки — плита землі, яку prop() не відріже, не зрізавши корпус
    "river_boat": (
        "Remove the sand, the ground, the grass, the stones and the shadow under and around the boat and replace them "
        "with flat magenta (#FF00FF), so the boat stands alone on a plain magenta background. Keep the boat, its "
        "broken planks, the mast and the rope exactly as they are. " + KEEP,
        9642,
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


# перемальовування прямокутника сирої (px генерації) по ній самій → <name>_fix: (x0, x1, y0, y1, текст, зерно, denoise)
REPAINTS = {
    # 9503: посередині — темний коридор ущелини просто за героєм, читався проходом (D747), а ходу там нема; 9504
    # («solid wall … no opening») закрив його брилами, але поставив поруч арку з темним отвором
    "river_far": (
        690,
        1110,
        330,
        760,
        "a huge heap of big fallen boulders and drifted sand completely filling the narrow end of the gorge from one "
        "cliff to the other, rough rocks piled high against the layered cliffs, everything solid rock",
        9505,
        0.85,
    ),
}


def repaint(name):
    x0, x1, y0, y1, text, seed, denoise = REPAINTS[name]
    src = load(name)
    h = -(-len(src) // 16) * 16
    big = np.concatenate([src, np.repeat(src[-1:], h - len(src), axis=0)])
    x, y = np.arange(big.shape[1]), np.arange(h)
    edge = 24
    rx = np.clip(np.maximum(x0 - x, x - x1) / edge, 0, 1)
    ry = np.clip(np.maximum(y0 - y, y - y1) / edge, 0, 1)
    alpha = (np.maximum(rx[None, :], ry[:, None]) * 255).astype(np.uint8)
    up = cb.upload(np.dstack([big.astype(np.uint8), alpha]), name + "_fix.png")
    out = cb.run(cb.graph(f"{text}, {STYLE}", seed, h, up, denoise, width=big.shape[1]))
    w = (1 - alpha / 255)[..., None]
    Image.fromarray((out * w + big * (1 - w))[: len(src)].astype(np.uint8)).save(
        raw(name + "_fix")
    )
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
    # дорисовування русла бачить його дальню стіну, береги й дно — вони генеруються раніше
    todo = [n for n in [*TILES, *PROPS, *INPAINT] if not os.path.exists(raw(n))]
    cost = 0
    while todo and cost < 4:  # ≤ 4 генерацій за запуск (ОЗП, skill comfy-backdrop)
        name = todo.pop(0)
        if name == "river_hole" and not all(os.path.exists(raw(n)) for n in TILES):
            break
        (gen_tile if name in TILES else gen_prop if name in PROPS else gen_inpaint)(
            name
        )
        cost += 2 if name == "river_far" else 1
    s = json.load(urllib.request.urlopen(cb.API + "/system_stats"))["system"]
    print("left", todo, "ram_free GB", round(s["ram_free"] / 2**30, 1))
    if not todo:
        for name in EDITS:
            if not os.path.exists(raw(name + "_fix")):
                edit(name)
        for name in REPAINTS:
            if not os.path.exists(raw(name + "_fix")):
                repaint(name)
        free()


# --- build --------------------------------------------------------------------------------------------------------
def load(name):
    p = raw(name + "_fix") if os.path.exists(raw(name + "_fix")) else raw(name)
    return np.asarray(Image.open(p).convert("RGB"), np.float32)


def img(path):
    return np.asarray(Image.open(path).convert("RGBA"))


def tile(name, haze, colors, fill=True):
    """Смуга / кадр 576 завширшки: ключ → ×3 вниз → (суцільно до низу) → серпанок → палітра."""
    key = TILES[name][3]
    rgb, op = cb.shrink(load(name), key)
    if fill and key:
        rgb, op = cb.fill_down(rgb, op)
    rgb = rgb * (1 - haze) + cb.HAZE * haze
    return cb.quantize(rgb, op, colors, "octree")


def darken(arr, k):
    """Темніше й холодніше (глибина підземелля), як m6b3.darken: k — частка кольору, що лишається."""
    out = arr.copy()
    out[..., :3] = np.clip(
        arr[..., :3] * k + np.array([18, 10, 34]) * (1 - k), 0, 255
    ).astype(np.uint8)
    return out


def prop(name, colors=16, haze=0.0):
    """Предмет на пурпурі → рівно SIZES (висота) чи WIDTHS (ширина) арту, своя палітра, альфа 0/255 (як m6b3.prop)."""
    from scipy import ndimage

    im = load(name)
    if name in SHEAR:
        k, cut_row = SHEAR[name]
        h0, w0 = im.shape[:2]
        bg = np.median(im[:8].reshape(-1, 3), axis=0)
        out = np.tile(bg, (h0 + round(k * w0), w0, 1))
        for x in range(w0):
            out[round(k * x) : round(k * x) + h0, x] = im[:, x]
        out[cut_row:] = bg
        im = out
    if name in CROP:
        y0, y1, x0, x1 = CROP[name]
        h0, w0 = im.shape[:2]
        im = im[round(y0 * h0) : round(y1 * h0), round(x0 * w0) : round(x1 * w0)]
    edges = [
        im[:8],
        im[:, :8],
        im[:, -8:],
    ]  # тло — найрівніший край (низ — земля під предметом)
    bg = np.median(
        min((e.reshape(-1, 3) for e in edges), key=lambda e: e.std(0).sum()), axis=0
    )
    m = np.linalg.norm(im - bg, axis=2) > cb.KEY_DISTANCE
    m &= (
        np.minimum(im[..., 0], im[..., 2]) - im[..., 1] < 60
    )  # темні пурпурні тіні на тлі
    if name.startswith(
        "river_"
    ):  # русло сухе: блакитні краплі й смужки води, що модель домальовує, — геть
        m &= ~((im[..., 2] - im[..., 0] > 60) & (im[..., 1] - im[..., 0] > 30))
    m = ndimage.binary_opening(m, iterations=2)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, 1 + np.nonzero(sizes >= sizes.max() * 0.02)[0])
    # плита землі, яку модель кладе під предмет усупереч підказці: від першого суцільного рядка в нижній третині — геть
    full = np.nonzero(m.mean(1)[len(m) * 2 // 3 :] >= 0.95)[0]
    if len(full) and name not in CROP:
        m[len(m) * 2 // 3 + full[0] :] = False
    if name in NO_RAIL:  # над настилом (перший рядок, суцільний на 85 % ширини) — геть
        cols = m.any(0)
        m[: int(np.argmax(m[:, cols].mean(1) >= 0.85))] = False
    ys, xs = np.nonzero(m)
    im, m = (
        im[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
        m[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
    )
    if name in WIDTHS:
        w = WIDTHS[name]
        h = max(1, round(len(im) * w / im.shape[1]))
    else:
        h = SIZES[name]
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


def ground(name, colors):
    """Смуга під ногами: рядок 0 — лінія ходьби (перший майже суцільний рядок), до низу кімнати (64 рядки)."""
    g = tile(name, 0, colors, fill=True)
    top = int(np.argmax((g[..., 3] > 0).mean(1) >= 0.9))
    g = g[top:]
    short = 320 - WALK - len(g)
    if short > 0:
        g = np.concatenate([g, g[-1 : -short - 1 : -1]])
    return g[: 320 - WALK]


def cut(strip, x0, x1):
    """Земля з прорізом x0…x1 нижче LIP (темний підмальок) — контекст для дорисовування."""
    s = strip.copy()
    t = np.linspace(0, 1, len(s) - LIP)[:, None, None]
    s[LIP:, x0:x1, :3] = (
        np.array([70, 44, 92]) * (1 - t) + np.array([10, 6, 18]) * t
    ).astype(np.uint8)
    s[LIP:, x0:x1, 3] = 255
    return s


def context(name):
    """Кадр без переднього плану від CTX_TOP до низу кімнати (320): те, що модель бачить навколо прорізу."""
    if name == "chasm_gap":
        planes = chasm_back(city=False) + [
            (cut(img(DUNES + "gen_ground.png"), *GAP), 0, WALK, False)
        ]
    else:
        planes = river_back(raw_ok=True) + [
            (cut(river_ground_strip(), *HOLE), 0, WALK, False)
        ]
    return compose(planes)[CTX_TOP:320, :, :3].copy()


def filled(name, strip):
    """Дорисоване (×3 вниз, палітра) — у проріз x0…x1 нижче LIP; решта смуги — як була."""
    _, x0, x1, _ = INPAINT[name]
    rgb, _ = cb.shrink(load(name), None)
    new = rgb[WALK - CTX_TOP : 320 - CTX_TOP]
    q = cb.quantize(
        new[LIP:, x0:x1], np.ones(new[LIP:, x0:x1].shape[:2], bool), 16, "octree"
    )
    out = strip.copy()
    out[LIP:, x0:x1] = q
    o0, o1 = OPENING[name]
    out[:LIP, o0:o1] = out[LIP + 3, o0:o1]
    out[..., 3] = (
        255  # підлога суцільна до низу кімнати (у смузі Дюн лишились поодинокі прозорі пікселі)  # над прорізом — без смужки землі (читалась би тонким містком)
    )
    return out


def river_ground_strip():
    return ground("river_ground", 14)


def save(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr).save(path)
    print(path, arr.shape[1], "x", arr.shape[0], flush=True)


def build():
    save(prop("chasm_bridge", 14), CHASM + "gen_bridge.png")
    save(prop("chasm_winch"), CHASM + "gen_winch.png")
    save(prop("chasm_city", 14, haze=0.35), CHASM + "gen_city.png")
    save(prop("chasm_front"), CHASM + "gen_front.png")  # темнить foreground_dark.tscn
    save(filled("chasm_gap", img(DUNES + "gen_ground.png")), CHASM + "gen_ground.png")

    save(darken(tile("river_far", 0, 16, fill=False), FAR_DARK), RIVER + "gen_far.png")
    save(darken(tile("river_banks", 0.05, 14), 0.8), RIVER + "gen_banks.png")
    save(darken(prop("river_boat", 14), 0.85), RIVER + "gen_boat.png")
    save(filled("river_hole", river_ground_strip()), RIVER + "gen_ground.png")
    save(prop("river_front"), RIVER + "gen_front.png")


# --- композиція: камера стоїть на 0, тож на екрані x = якір; (картинка, x, y, тайл?, передній план?) ---------------
SKY = B + "DesertOasis/bg4/plan5.png"
CLOUDS = B + "Canyon/gen_clouds.png"
MESAS = B + "Canyon/gen_far.png"
FRONT_DARK = np.array([0.3, 0.26, 0.34])  # foreground_dark.tscn (D750)
# Пустельна дорога [4,5] — Провалля [16,5]: 12 клітинок; Дюни [12,5] — 4. План f продовжує дорожній (дюнний), якщо
# зсунутий на −f × X (mod 576 арту — повтор 864 світу)
ROAD_X, DUNES_X = 12 * W, 4 * W
DUNES_Y, NEAR_Y = 70, 150  # як у Дюнах (m6b3)


def sh(f, x):
    return round(-f * x) % W


def stand(a, cx, sink=2):
    """Предмет a з центром на cx (арт) і низом на лінії ходьби + sink."""
    return round(cx - a.shape[1] / 2), WALK + sink - a.shape[0]


def chasm_back(city=True):
    """Небо, хмари, гори, (місто), дюни; місто — не в контексті дорисовування (воно генерується окремо)."""
    c = img(CHASM + "gen_city.png") if city else None
    return [
        (img(SKY), 0, 0, True),
        (img(CLOUDS), sh(0.1, ROAD_X), 0, True),
        (img(MESAS), sh(0.3, ROAD_X), 0, True),
        *([(c, *stand(c, CITY_X, CITY_SINK), False)] if city else []),
        (img(DUNES + "gen_dunes.png"), sh(0.5, DUNES_X), DUNES_Y, True),
        (img(DUNES + "gen_near.png"), sh(0.8, DUNES_X), NEAR_Y, True),
    ]


# місто: центр над східним краєм, підніжжя за дюнами
CITY_X, CITY_SINK = 420, -95
WINCH_X = (
    PIVOT + 48
)  # лебідка — праворуч від піднятого мосту (452…480), ланцюг — за край, до важеля
FRONT_X, FRONT_TOP = (
    300,
    262,
)  # скеля попереду — над серединою прірви, не над Arrival (53) і не над східним виходом


def bridge(raised):
    """Міст як у FlagBridge: вузол у шарнірі (PIVOT, WALK), Plank offset = (−SPAN, −deck); піднятий — π/2 за
    годинниковою (вільний кінець угору, настил — на схід)."""
    a = img(CHASM + "gen_bridge.png")
    deck = deck_row(a)
    if not raised:
        return a, PIVOT - a.shape[1], WALK - deck
    r = np.asarray(Image.fromarray(a).transpose(Image.Transpose.ROTATE_270))
    return r, PIVOT - (a.shape[0] - deck), WALK - a.shape[1]


def deck_row(a):
    """Рядок верху настилу: перший рядок, непрозорий на ≥ 90 % ширини (поручні й стовпчики над ним — рідкі)."""
    return int(np.argmax((a[..., 3] > 0).mean(1) >= 0.9))


def chasm_planes(raised):
    w = img(CHASM + "gen_winch.png")
    f = img(CHASM + "gen_front.png")
    return chasm_back() + [
        (img(CHASM + "gen_ground.png"), 0, WALK, False),
        (*bridge(raised), False),
        (w, *stand(w, WINCH_X), False),
        (f, round(FRONT_X - f.shape[1] / 2), FRONT_TOP, False, True),
    ]


def river_back(raw_ok=False):
    """Дальня стіна, береги, човен (без землі й переднього плану)."""
    if raw_ok and not os.path.exists(
        RIVER + "gen_far.png"
    ):  # контекст дорисовування до build
        far, banks = (
            darken(tile("river_far", 0, 16, fill=False), FAR_DARK),
            darken(tile("river_banks", 0.05, 14), 0.8),
        )
        return [(far, 0, 0, False), (banks, 0, BANKS_Y, False)]
    b = img(RIVER + "gen_boat.png")
    return [
        (img(RIVER + "gen_far.png"), 0, 0, False),
        (img(RIVER + "gen_banks.png"), 0, BANKS_Y, False),
        (b, *stand(b, BOAT_X, 3), False),
    ]


BANKS_Y = (
    WALK + 22 - 120
)  # береги: смужка води внизу (9511 її таки намалював) — під землею, нижче лінії ходьби
BOAT_X = 150  # човен — на захід від Arrival (200), далеко від діри (384…533)


def river_planes():
    f = img(RIVER + "gen_front.png")
    return river_back() + [
        (img(RIVER + "gen_ground.png"), 0, WALK, False),
        (f, round(40 - f.shape[1] / 2), 250, False, True),
    ]


def compose(planes, hero=None):
    c = Image.new("RGBA", (W, VH), (0, 0, 0, 255))
    for a, x, y, rep, *front in [*planes, (None, 0, 0, False, True)]:
        if hero is not None and front:  # герой — перед усім, крім переднього плану
            h = Image.fromarray(hero[1])
            c.alpha_composite(h, (round(hero[0] - h.width / 2), WALK - h.height))
            hero = None
        if a is None:
            continue
        if front:
            a = a.copy()
            a[..., :3] = (a[..., :3] * FRONT_DARK).astype(np.uint8)
        im = Image.fromarray(a)
        layer = Image.new("RGBA", (W, VH))
        sx = x % im.width - im.width if rep else x
        while True:
            layer.paste(im, (round(sx), y))
            sx += im.width
            if not rep or sx >= W:
                break
        c.alpha_composite(layer)
    return np.asarray(c)


def sheet():
    hero = img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    frames = [
        (
            "Chasm, first visit (bridge raised, stands upright on the far lip): the hero at Arrival (x 80 world); the "
            "road's sky and mesas, the Dunes' dune sea x0.5 and near dunes x0.8 continue, the City peeks over the dunes x0.4",
            compose(chasm_planes(True), (53, hero)),
        ),
        (
            "Chasm, after BridgeLever (GateApproach): the bridge lowered, span x 144-720 world, deck top on the walk "
            "line; the winch x1.0 on the east lip, the rock spur front x1.3",
            compose(chasm_planes(False), (288, hero)),
        ),
        (
            "Dry Riverbed, Arrival (x 300 world): the gorge's far wall with the sky slit x0.45, old banks x0.75, the "
            "boat wreck x0.85, the boulder front x1.3",
            compose(river_planes(), (200, hero)),
        ),
        (
            "Dry Riverbed, at the hole (x 576-800 world): the floor broken into the aqueduct vault below, the drop on",
            compose(river_planes(), (360, hero)),
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
    out.save("design/shots/m6b4_chasm_riverbed.png")
    print("sheet", out.size, flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build, "sheet": sheet}[sys.argv[1]]()
