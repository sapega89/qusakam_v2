"""Бойові ефекти через ComfyUI (D239, D268, D271): Qwen-Image (Apache 2.0) + Lightning-LoRA малює один ефект в
аніме-стилі на хромакеї; скрипт прибирає фон, вписує ефект у розмір текстури гри (піксель гри = ×1.5 світу, як
герой), зводить до кількох кольорів і робить кадри (поява → повний → згасання) з цієї однієї картинки — модель
між генераціями не тримає форму, а кадри з однієї картинки тримають.
Граф і ключ — з comfy_backdrop.py; кеш генерацій — CACHE (за підказкою й зерном).
Запуск: python Scripts/Tools/comfy_fx.py [ефект ...]   (≤ 4 генерації за раз, моделі звільняються в кінці)
"""

import hashlib
import json
import os
import sys
import tempfile
import urllib.request

import numpy as np
from scipy import ndimage
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import comfy_backdrop as cb  # noqa: E402

CACHE = os.path.join(tempfile.gettempdir(), "comfy_fx")
OUT = "SampleProject/Assets/FX/"
STYLE = "clean anime action game effect, crisp sharp shapes, flat cel shading, high contrast"
GREEN = "on a solid flat chroma key green (#00FF00) background"
MAGENTA = "on a solid flat magenta (#FF00FF) background"

# kind: arc — півмісяць праворуч у полотні 72×72 (центр кола — центр полотна, зовнішній радіус 32, як SMEAR_RADIUS);
# thrust — смуга від хвату ліворуч до вістря праворуч; cut — розтин удару; sprite — одна текстура (ефекти навичок).
# box — куди вписати ефект у полотні (x0, y0, x1, y1); canvas — розмір текстури; frames — імена кадрів у OUT.
FX = {
    "slash_arc": dict(
        seed=7,
        size=(1024, 1024),
        key="green",
        colors=6,
        kind="arc",
        canvas=(72, 72),
        box=(
            4,
            4,
            68,
            68,
        ),  # правий край = центр + SMEAR_RADIUS; хвости півмісяця тягнуться назад
        frames=["Smear/arc_1", "Smear/arc_2", "Smear/arc_3"],
        prompt="a single sharp sword slash crescent, a thin curved arc bulging to the right like the right half of a "
        "thin ring, thick in the middle and tapering to needle points at the top and the bottom, bright white core "
        "with a pale icy blue edge, a few thin straight speed lines along the curve, centered, "
        + GREEN,
    ),
    # Розтин влучання (HitImpact.tscn) і смуги уколу / удару кулаком (Smear/thrust, punch) малює скрипт — draw_cut(),
    # draw_thrust(), draw_punch(), див. нижче. Тричі модель на «розтин» малювала меч; згенерована смуга уколу була
    # кометою з круглою головою, що читалась як летючий снаряд (A7, A9, D813).
    "fire_arc": dict(
        seed=3,
        size=(1024, 1024),
        key="green",
        colors=10,
        kind="sprite",
        canvas=(56, 72),
        box=(4, 2, 52, 70),
        frames=["Skills/fire_arc"],
        prompt="a single blazing fire slash crescent, a thick curved arc of flames bulging to the right like the "
        "right half of a ring, white hot core, yellow and orange flames licking off its outer edge, tapering "
        "points at the top and the bottom, centered, " + GREEN,
    ),
    "bolt": dict(
        seed=9,
        size=(1024, 512),
        key="green",
        colors=8,
        kind="sprite",
        canvas=(80, 24),
        box=(0, 2, 80, 22),
        frames=["Skills/bolt"],
        prompt="a single horizontal lightning bolt from the left edge to the right edge, a jagged zigzag with a "
        "bright white core and an electric blue outline, two or three small forks branching off, "
        + GREEN,
    ),
    "heal_aura": dict(
        seed=4,
        size=(1024, 1024),
        key="magenta",
        colors=8,
        kind="sprite",
        canvas=(48, 48),
        box=(2, 2, 46, 46),
        frames=["Skills/heal_aura"],
        prompt="a soft radiant healing light, a ring of pale green and warm gold light with four small "
        "four-pointed sparkles and a few small glowing leaf-shaped motes around it, centered, "
        + MAGENTA,
    ),
    # Бос-ефекти (D301, D302, queue row 9.2): небезпеки боса й сюжетні ефекти Мерії / Лабораторії.
    "boss_fireball": dict(
        seed=21,
        size=(1024, 512),
        key="green",
        colors=8,
        kind="sprite",
        canvas=(40, 20),
        box=(0, 1, 40, 19),
        frames=["Bosses/fireball"],
        prompt="a single fireball flying to the right, a round white hot core at the right end, orange and red "
        "flames streaming back to the left into a tapering tail, side view, " + GREEN,
    ),
    "boss_pillar": dict(
        seed=22,
        size=(512, 1024),
        key="green",
        colors=8,
        kind="sprite",
        canvas=(48, 104),
        box=(0, 0, 48, 104),
        frames=["Bosses/pillar"],
        prompt="a single tall vertical column of roaring fire rising straight up from the ground, straight sides, "
        "white hot yellow core, orange flames, red tongues at the edges, flat bottom, front view, "
        + GREEN,
    ),
    # H4: стара мітка (тонкий овал жарин 48x10, 6 кольорів) у грі читалась блідою плямою. Тепер — коло рун згори,
    # стиснуте в овал на підлозі (stretch): біло-жовте ядро, помаранчеве кільце, червоний обідок і темний контур
    # 1 px. Ширина з контуром — x 6..40 = 35 px × 2.05 (Mark у boss_pillar.tscn) = 72 px світу, як width стовпа.
    "boss_mark": dict(
        seed=23,
        size=(1024, 1024),
        key="green",
        colors=7,
        kind="sprite",
        canvas=(48, 14),
        box=(7, 1, 40, 13),
        stretch=True,
        outline=(61, 11, 16),
        frames=["Bosses/mark"],
        prompt="a single round magic circle of fire seen from directly above, a solid filled disc: a white hot "
        "yellow center, a wide ring of bright orange glowing fire runes around it, a deep red outer rim, flat, "
        "no flames rising, centered, " + GREEN,
    ),
    # A1 (Sapega 27.10: «більш виразний має бути»): стара бежева хвиля пилу на пурпурі (знебарвлення пурпуру
    # стягувало червоний до зеленого + 40 — помаранч ставав беж) у темній залі зливалась із підлогою. Тепер — гребінь
    # піску з білим переднім краєм і помаранчевим нутром на зеленому, темний контур 1 px; полотно те саме 56x28.
    "boss_shockwave": dict(
        seed=24,
        size=(1024, 512),
        key="green",
        colors=7,
        kind="sprite",
        canvas=(56, 28),
        box=(0, 0, 56, 28),
        outline=(40, 16, 20),
        frames=["Bosses/shockwave"],
        prompt="a single ground shockwave rolling to the right, a tall curling crest of thick orange and tan sand "
        "dust like a breaking wave, a bright white yellow glowing front edge, flat bottom along the ground, side view, "
        + GREEN,
    ),
    "explosion": dict(
        seed=25,
        size=(1024, 1024),
        key="green",
        colors=10,
        kind="sprite",
        canvas=(72, 72),
        box=(0, 0, 72, 72),
        frames=["Bosses/explosion"],
        prompt="a single fiery explosion cloud, a billowing ball of orange and yellow fire with dark grey smoke "
        "puffs at its edges, flat bottom, " + GREEN,
    ),
    "wall_burst": dict(
        seed=26,
        size=(1024, 1024),
        key="magenta",
        colors=8,
        kind="sprite",
        canvas=(80, 80),
        box=(0, 0, 80, 80),
        frames=["Bosses/wall_burst"],
        prompt="a single burst of broken sandstone bricks and beige dust flying outward to the right from a wall, "
        "chunks of stone and a cloud of dust, side view, " + MAGENTA,
    ),
    "sleep_gas": dict(
        seed=27,
        size=(1024, 1024),
        key="magenta",
        colors=6,
        kind="sprite",
        canvas=(72, 56),
        box=(0, 0, 72, 56),
        frames=["Bosses/sleep_gas"],
        prompt="a single soft cloud of pale green poison gas, rounded puffy billows, translucent looking, flat "
        "bottom, " + MAGENTA,
    ),
    "wall_hole": dict(
        seed=28,
        size=(1024, 1024),
        key="magenta",
        colors=8,
        kind="sprite",
        canvas=(72, 96),
        box=(0, 0, 72, 96),
        frames=["Bosses/wall_hole"],
        prompt="a single tall ragged hole smashed through a sandstone brick wall, a black dark opening framed by "
        "broken sandstone bricks with jagged edges, front view, " + MAGENTA,
    ),
    # Лук героя (BACKLOG 40, A4): стріла й заряджена стріла; тонке древко — без main_shape (розмикання його стирає)
    "arrow": dict(
        seed=31,
        size=(1024, 256),
        key="magenta",
        colors=5,
        kind="sprite",
        main=False,
        canvas=(28, 9),
        box=(0, 0, 28, 9),
        frames=["Projectiles/arrow"],
        # перша спроба: наконечник у 28 px зводився до сірої плями — великий наконечник і темний контур, як у героя
        prompt="a single short thick chunky arrow flying to the right, perfectly horizontal, side view, 16-bit pixel "
        "art with a thick dark outline, a thick brown wooden shaft, a very large wide triangular light grey steel "
        "arrowhead at the right end, as tall as a third of the arrow's length, two big white feather fletchings at the "
        "left end, filling the whole width of the picture, " + MAGENTA,
    ),
    # arrow_charged — Scripts/Tools/bow_fixups.py (лимонне сяйво на весь спрайт і відірваний слід — арт-директор)
}

# Власні ефекти дев'яти активних навичок клятв (A6, D279): заряд у руці (charge) + удар (release), кадри — у
# Skills/<id>/. Світло — золото/біле сяйво, Темрява — фіолет/багрянець, Рівновага — пісок/вітер. Без спалахів
# на весь екран і круглих вибухів. Фіолет на пурпуровому ключі губиться — темні ефекти лише на зеленому.
# (id, seed, ключ, заряд, удар: (вид, розмір генерації, полотно, підказка))
CHARGE = (32, 32)
SKILL_FX = [
    (
        "radiant_smite",
        41,
        "green",
        "a small burst of saturated golden holy light, a bright white four-pointed star glint in the middle with long "
        "sharp golden rays and four shorter diagonal rays, deep amber edges, centered",
        (
            "arc",
            (1024, 1024),
            (56, 72),
            "a single massive crescent shaped slash wave of blazing golden holy light, no sword, a very thick curved arc bulging to the "
            "right like the right half of a ring, white hot core, saturated golden yellow body, deep amber orange outer "
            "rim, long sharp straight light rays bursting outward from its outer edge like a sunburst, tapering points "
            "at the top and the bottom, centered",
        ),
    ),
    (
        "skyfall_blessing",
        42,
        "green",
        "a single small glowing feather made of golden light, a white hot core along its quill, short sharp gold "
        "rays around it, centered",
        (
            "down",
            (512, 1024),
            (40, 104),
            "a single thick vertical pillar of golden holy light slamming straight down from the sky into the ground, "
            "white hot core, saturated golden yellow glow, deep amber edges, widening at the bottom into a wide burst "
            "of light rays and splashes spreading sideways along the ground, small golden four-pointed sparkles, "
            "front view",
        ),
    ),
    (
        "judgement_of_the_sky",
        43,
        "green",
        "a small golden halo ring with sharp white light runes and short gold rays pointing outward, centered",
        (
            "down",
            (512, 1024),
            (28, 96),
            "a single long thin vertical lance made of pure white and golden light pointing straight down, a sharp "
            "glowing tip at the bottom, a straight glowing shaft fading into a thin gold light trail toward the top, "
            "no handle, no crossguard, front view",
        ),
    ),
    (
        "searing_hex",
        44,
        "green",
        "a small glowing violet hex sigil, a thin bright violet circle with a six-pointed star rune inside, glowing "
        "lilac white lines, small bright violet flames licking up off its top, centered",
        (
            "thrust",
            (1024, 512),
            (72, 24),
            "a single horizontal blast of cursed violet hexfire flying to the right, a thick bolt of bright violet "
            "flames widest at its right end with a sharp flaming tip, a hot lilac white core, deep indigo flame edges, "
            "small violet rune sparks along it, fading to a thin violet trail toward the left",
        ),
    ),
    (
        "withering_grasp",
        45,
        "green",
        "a small knot of curling black violet shadow tendrils with glowing sickly yellow green tips and a pale green "
        "glowing rim, centered",
        (
            "right",
            (1024, 512),
            (64, 40),
            "a single huge spectral clawed hand made of black violet shadow reaching to the right, five long sharp "
            "claws spread open at the right end glowing sickly yellow green, a bright pale green glowing rim along its "
            "edges, a wispy smoky arm trailing back to the left edge, side view",
        ),
    ),
    (
        "eclipse_cleave",
        46,
        "green",
        "a small black crescent moon with a bright crimson rim and a thin violet glow, centered",
        (
            "arc",
            (1024, 1024),
            (64, 80),
            "a single dark crimson sword slash crescent, a thick curved arc bulging to the right like the right half of "
            "a ring, its body very dark violet black, a bright crimson flaming outer edge shaded from deep red to "
            "bright crimson with a thin pale pink highlight line, small violet sparks and ragged pixels trailing off "
            "its inner edge, a thin dark slate outline, tapering points at the top and the bottom, centered",
        ),
    ),
    (
        "balanced_strike",
        47,
        "magenta",
        "a small swirling spiral of golden sand grains and pale wind streaks, centered",
        (
            "thrust",
            (1024, 512),
            (72, 24),
            "a single horizontal gust of sand and wind flying to the right, a sharp beige wind streak widest at its "
            "right end with a blunt tip, curling pale wind lines and sand grains along it, fading to a thin line toward "
            "the left",
        ),
    ),
    (
        "dervish_whirl",
        48,
        "magenta",
        "a small tight vortex of beige sand and pale wind lines spinning, centered",
        (
            "right",
            (1024, 512),
            (96, 48),
            "a single wide flat horizontal whirlwind ring of beige sand and pale wind streaks spinning around an empty "
            "center, a wide thin oval band seen from the side, curling wind lines, sand grains, side view",
        ),
    ),
    (
        "second_wind",
        49,
        "magenta",
        "a small spiral of pale mint green wind lines around a white glowing core, two small bright green leaves, "
        "teal edges, centered",
        (
            "up",
            (512, 1024),
            (48, 80),
            "a single tall upward whirlwind of pale mint green healing wind, two broad curling wind ribbons rising and "
            "twisting around each other, white glowing core, teal edges, small bright green leaves and white sparkles "
            "carried up, tapering to a point at the top, no ground, centered, front view",
        ),
    ),
]
for _id, _seed, _key, _charge, (_kind, _size, _canvas, _release) in SKILL_FX:
    _bg = GREEN if _key == "green" else MAGENTA
    FX[_id + "_charge"] = dict(
        seed=_seed,
        size=(1024, 1024),
        key=_key,
        colors=8,
        kind="charge",
        canvas=CHARGE,
        box=(1, 1, CHARGE[0] - 1, CHARGE[1] - 1),
        frames=[f"Skills/{_id}/charge_{i}" for i in range(1, 5)],
        prompt=f"{_charge}, {_bg}",
    )
    FX[_id + "_release"] = dict(
        seed=_seed + 100,
        size=_size,
        key=_key,
        colors=8,
        kind=_kind,
        canvas=_canvas,
        box=(0, 0) + _canvas,
        frames=[f"Skills/{_id}/release_{i}" for i in range(1, 5)],
        prompt=f"{_release}, {_bg}",
    )
# Спис «Суду неба» модель малювала вістрям угору — перевертаємо, щоб падав вістрям униз.
FX["judgement_of_the_sky_release"]["flip"] = True
# Півмісяць «Затемнення» на 8 кольорах ставав двома пласкими смугами (арт-директор) — 10, як fire_arc.
FX["eclipse_cleave_release"]["colors"] = 10
# Контур 1 px кольором контуру заряду (charge_3), щоб заряд і удар читались однією навичкою; box на 1 px менший
# під контур, зовнішній край контуру — на правому краю полотна.
FX["eclipse_cleave_release"]["outline"] = (118, 154, 166)
FX["eclipse_cleave_release"]["box"] = (1, 1, 63, 79)
# A9 (2026-10-28, D813 «поправити» без нотаток, D828 «скіли мають вагу»): світлі ефекти зливались із піском, темні —
# з темними кімнатами, «Пекуче прокляття» читалось червоним вогнем, як Fire Strike, перший кадр удару був рубаним
# шматком. Тепер у кожного свій колір і 1-px контур (заряд і удар — одним кольором), удар — важкий: 1 — повна форма,
# розпечена до білого, 2 — повна в кольорі, 3 — тоншає.
A9_OUTLINE = {
    "radiant_smite": (92, 52, 12),  # золото, темно-бурштиновий контур
    "skyfall_blessing": (92, 52, 12),  # лише удар (заряд-перо не мінявся)
    "searing_hex": (44, 14, 78),  # фіолетовий вогонь, індиго, без червоного
    "withering_grasp": (150, 214, 92),  # чорно-фіолетова тінь, хворобливо-зелене світло по краю
    "second_wind": (18, 96, 96),  # м'ятний вітер зцілення, бірюзовий контур
}
for _id, _outline in A9_OUTLINE.items():
    for _fx in [FX[_id + "_release"]] + ([] if _id == "skyfall_blessing" else [FX[_id + "_charge"]]):
        _fx["outline"] = _outline
        _fx["box"] = (1, 1, _fx["canvas"][0] - 1, _fx["canvas"][1] - 1)
    FX[_id + "_release"]["heavy"] = True
# Чорна рука в білому спалаху ставала сірою — спалахує фіолетовим; вихор Другого подиху модель поставила на темну
# смугу землі (ключ брав її за фон) — низ генерації відрізано.
FX["withering_grasp_release"]["flash"] = (210, 170, 255)
FX["second_wind_release"]["crop"] = 0.9
# Стовп Благословення модель теж поставила на землю (низ відрізано) і довела до краю кадру — верх загострено.
FX["skyfall_blessing_release"]["crop"] = 0.86
FX["skyfall_blessing_release"]["taper"] = 0.25
# Q124 (A13): заряд «Пекучого прокляття» модель малює зіркою — п'ятикутною в колі (пентаграма) за «six-pointed star»,
# шестикутною за «hexagon» — тож знак без зірки малює скрипт (draw_hex_sigil), генерації заряду більше немає.
del FX["searing_hex_charge"]


def generate(name, fx):
    text = f"{fx['prompt']}, {STYLE}"
    path = os.path.join(
        CACHE,
        hashlib.sha1(f"{text}|{fx['seed']}|{fx['size']}".encode()).hexdigest()[:12]
        + ".png",
    )
    if not os.path.exists(path):
        g = cb.graph(text, fx["seed"], fx["size"][1])
        g["latent"]["inputs"]["width"] = fx["size"][0]
        os.makedirs(CACHE, exist_ok=True)
        Image.fromarray(cb.run(g).astype(np.uint8)).save(path)
        print("generated", name, path)
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)


def key(img, which):
    """Маска непрозорого: далі KEY_DISTANCE від кольору, яким модель залила кути (не від номіналу)."""
    corners = np.concatenate(
        [img[:16, :16], img[:16, -16:], img[-16:, :16], img[-16:, -16:]]
    ).reshape(-1, 3)
    bg = np.median(corners, axis=0)
    a = np.linalg.norm(img - bg, axis=2) > cb.KEY_DISTANCE
    if which == "green":  # зелений відсвіт країв
        img[..., 1] = np.minimum(img[..., 1], np.maximum(img[..., 0], img[..., 2]))
    else:
        img[..., [0, 2]] = np.minimum(img[..., [0, 2]], img[..., 1:2] + 40)
    return a.astype(np.float32)


OPEN = 16


def main_shape(a):
    """Лише найбільша суцільна пляма: тонкі лінії швидкості й зайві кільця, які модель додає довкола, геть
    (лінії, що торкаються плями, відрізає розмикання на OPEN px генерації)."""
    a = ndimage.binary_opening(a > 0, iterations=OPEN).astype(np.float32)
    labels, n = ndimage.label(a > 0)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(a), labels, range(1, n + 1))
        a = a * (labels == 1 + int(np.argmax(sizes)))
    return a


def fit(img, a, fx):
    """Обрізати до непрозорого, вписати в box полотна (пропорції зберігаються), колір — лише з непрозорого."""
    ys, xs = np.nonzero(a)
    img, a = (
        img[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
        a[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
    )
    x0, y0, x1, y1 = fx["box"]
    k = min((x1 - x0) / a.shape[1], (y1 - y0) / a.shape[0])
    w, h = max(1, round(a.shape[1] * k)), max(1, round(a.shape[0] * k))
    if fx.get("stretch"):  # заповнити box цілком (коло згори → овал на підлозі), пропорції не зберігаються
        w, h = x1 - x0, y1 - y0

    def down(m):
        return np.asarray(
            Image.fromarray(m.astype(np.float32)).resize((w, h), Image.BOX), np.float32
        )

    asum = down(a)
    rgb = (
        np.dstack([down(img[..., c] * a) for c in range(3)])
        / np.maximum(asum, 1e-6)[..., None]
    )
    cw, ch = fx["canvas"]
    canvas = np.zeros((ch, cw, 3), np.float32)
    opaque = np.zeros((ch, cw), bool)
    # arc і thrust — притиснуті до правого краю box (вістря / зовнішній край дуги), решта — по центру box
    ox = x1 - w if fx["kind"] in ("arc", "thrust") else x0 + (x1 - x0 - w) // 2
    # up / down — нижній край на дні box (кадр прикріплено низом до ніг / землі), решта — по центру
    oy = y1 - h if fx["kind"] in ("up", "down") else y0 + (y1 - y0 - h) // 2
    canvas[oy : oy + h, ox : ox + w] = rgb
    opaque[oy : oy + h, ox : ox + w] = asum > 0.45
    return canvas, opaque


def taper(m, part):
    """Верхня частка part плями звужується до вістря: у кожному рядку — довкола його ж середини."""
    ys = np.nonzero(m.any(axis=1))[0]
    n = max(1, round((ys[-1] - ys[0]) * part))
    m = m.copy()
    for y in range(ys[0], ys[0] + n):
        xs = np.nonzero(m[y])[0]
        if len(xs):
            mid, half = (xs[0] + xs[-1]) / 2, (xs[-1] - xs[0] + 1) / 2 * (y - ys[0] + 1) / n
            m[y, : int(np.ceil(mid - half))] = False
            m[y, int(mid + half) + 1 :] = False
    return m


def erode(m, n):
    for _ in range(n):
        e = m.copy()
        e[1:] &= m[:-1]
        e[:-1] &= m[1:]
        e[:, 1:] &= m[:, :-1]
        e[:, :-1] &= m[:, 1:]
        m = e
    return m


def grow(q, k):
    """Той самий спрайт, зменшений у k разів (найближчий сусід) по центру полотна."""
    h, w = q.shape[:2]
    small = np.asarray(
        Image.fromarray(q).resize(
            (max(1, round(w * k)), max(1, round(h * k))), Image.NEAREST
        )
    )
    out = np.zeros_like(q)
    y, x = (h - small.shape[0]) // 2, (w - small.shape[1]) // 2
    out[y : y + small.shape[0], x : x + small.shape[1]] = small
    return out


CUT_ANGLE = 35  # градусів угору-праворуч (знизу зліва вгору направо), як було; ліворуч — flip_h сцени
CUT_COLORS = ((255, 255, 255), (206, 240, 255), (128, 200, 246), (58, 110, 196))  # ядро, світло, лід, обвідка


def draw_cut(size=64, half=31.0, width=4.2):
    """A7 (2026-10-28): розтин навскіс — тонка лінза, гостра з обох кінців (аніме-розріз, не комета): біле ядро,
    крижаний край, синя 1-px обвідка (читається і на піску, і в темній залі). 1 — розріз пробігає знизу зліва вгору
    направо, тонкий; 2 — повний, поперек нього коротка іскра-штрих (не кругла — D204: без круглих спалахів);
    3 — розріз розходиться навпіл (дві половини відсунуто на 2 px від осі), тоншає; 4 — дві тонкі нитки, коротші.
    Без моделі: не AI."""
    c = (size - 1) / 2
    yy, xx = np.mgrid[:size, :size].astype(np.float32)
    t = np.radians(CUT_ANGLE)
    u = (xx - c) * np.cos(t) - (yy - c) * np.sin(t)  # уздовж розрізу, + — угору праворуч
    v = (xx - c) * np.sin(t) + (yy - c) * np.cos(t)  # поперек

    def lens(u0, u1, w, dv=0.0, side=0):
        """Лінза між u0 і u1 (гостра на кінцях), півширина w, зсув dv поперек; side — лише одна половина."""
        m, hl = (u0 + u1) / 2, (u1 - u0) / 2
        k = np.clip(1 - ((u - m) / hl) ** 2, 0, 1) ** 1.3
        vv = v - dv
        inside = (np.abs(vv) <= w * k + 0.35) & (k > 0)
        if side:
            inside &= vv * side >= -0.5
        level = np.where(np.abs(vv) <= w * k * 0.35, 0, np.where(np.abs(vv) <= w * k * 0.75, 1, 2))
        return inside, level

    def paint(parts):
        return paint_cut(parts, (size, size))

    cross = (np.abs(u) <= 0.9) & (np.abs(v) <= 12) | (np.abs(u) <= 1.6) & (np.abs(v) <= 5)
    cross_level = np.where(np.abs(v) <= 5, 0, 1)
    return [
        paint([lens(-half, half * 0.35, width * 0.45)]),
        paint([lens(-half, half, width), (cross, cross_level)]),
        paint([lens(-half * 0.9, half * 0.95, width * 0.55, 2.0, 1), lens(-half * 0.95, half * 0.9, width * 0.55, -2.0, -1)]),
        paint([lens(-half * 0.7, half * 0.75, 0.6, 3.0), lens(-half * 0.75, half * 0.7, 0.6, -3.0)]),
    ]


def paint_cut(parts, shape):
    """Частини (маска, рівень 0 ядро / 1 світло / 2 лід) → RGBA кольорами CUT_COLORS, синя 1-px обвідка навколо."""
    rgba = np.zeros(shape + (4,), np.uint8)
    body = np.zeros(shape, bool)
    for inside, level in parts:
        for lv in (2, 1, 0):  # світліше поверх
            m = inside & (level == lv)
            rgba[m] = (*CUT_COLORS[lv], 255)
        body |= inside
    ring = ndimage.binary_dilation(body) & ~body
    rgba[ring] = (*CUT_COLORS[3], 255)
    return rgba


def band(d, hw):
    """Смуга завширшки 2·hw навколо осі (d — відстань від осі), рівні як у розтину: ядро, світло, лід."""
    inside = (np.abs(d) <= hw + 0.35) & (hw > 0.15)
    level = np.where(np.abs(d) <= hw * 0.35, 0, np.where(np.abs(d) <= hw * 0.75, 1, 2))
    return inside, level


def draw_thrust(w=72, h=24, tip=70):
    """A9 (2026-10-28, D813): смуга уколу — голка від хвату (лівий край) до гострого вістря на x = tip (було: комета з
    круглою головою), кольори й обвідка розтину, дві лінії швидкості. 1 — повна, 2 — тонша, хвіст коротший, лінії
    попереду, 3 — лише голова (її ж бере шлейф стріли, arrow.tscn)."""
    yy, xx = np.mgrid[:h, :w].astype(np.float32)
    v, t = yy - (h - 1) / 2, xx / tip

    def needle(width, start):
        hw = np.where(t <= 0.84, width * np.clip((t - start) / (0.84 - start), 0, 1) ** 1.6, width * (1 - t) / 0.16)
        return band(v, hw)

    outs = []
    for width, start, lines in ((3.6, 0.0, (16, 50)), (2.6, 0.25, (36, 60)), (1.7, 0.55, None)):
        out = paint_cut([needle(width, start)], (h, w))
        if lines:
            out[[5, h - 6], lines[0] : lines[1]] = (*CUT_COLORS[2], 255)
        outs.append(out)
    return outs


def draw_punch(size=28):
    """A9: удар кулаком — 1 коротка смуга (кулак летить), 2 смуга тоншає, попереду дуга удару «)», 3 дуга ширшає,
    тоншає й розходиться навпіл (не кругле коло — D204)."""
    c = (size - 1) / 2
    yy, xx = np.mgrid[:size, :size].astype(np.float32)

    def streak(x0, x1, width):  # лінза, найширша на 0.7 довжини
        t = (xx - x0) / (x1 - x0)
        k = np.where(t < 0.7, (t - 0.7) / 0.7, (t - 0.7) / 0.3)
        return band(yy - c, np.where((t >= 0) & (t <= 1), width * np.clip(1 - k**2, 0, 1), 0))

    def shock(cx, r, width, span, gap=0.0):  # дуга кола радіуса r праворуч від cx, гостра на кінцях
        ang = np.degrees(np.abs(np.arctan2(yy - c, xx - cx)))
        k = np.where(ang < gap, 0, np.clip(1 - (ang / span) ** 2, 0, 1))
        return band(np.hypot(xx - cx, yy - c) - r, width * k)

    return [
        paint_cut([streak(1, 19, 2.8)], (size, size)),
        paint_cut([streak(4, 17, 1.8), shock(11, 10.5, 1.8, 62)], (size, size)),
        paint_cut([shock(11, 12, 1.0, 66, gap=14)], (size, size)),
    ]


def draw_hex_sigil(size=32):
    """Q124: знак прокляття без зірки — кільце, у ньому шестикутник (лише контур), між ними шість рисок-рун навпроти
    його сторін (не вершин — зірки не складають), світла цятка в центрі, фіолетовий вогник згори; кольори й контур
    A9. Кадри як у заряду з моделі: росте з центру (1–2) → повний (3) → тонший пульс (4)."""
    deep, violet, lilac, white = (110, 40, 190), (160, 90, 240), (210, 170, 255), (245, 230, 255)
    q = np.zeros((size, size, 4), np.uint8)
    cx, cy = 15.5, 17.5
    yy, xx = np.mgrid[:size, :size].astype(np.float32)
    d = np.hypot(xx - cx, yy - cy)

    def put(mask, colour):
        q[mask] = colour + (255,)

    put((d >= 10.6) & (d < 11.6), deep)  # сяйво з внутрішнього боку кільця
    put((d >= 11.6) & (d < 13.0), lilac)
    put((d >= 12.4) & (d < 13.0) & (yy < cy), white)  # світло згори

    def line(a, b, colour):
        n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1])) * 2) + 1
        for t in np.linspace(0, 1, n):
            q[int(round(a[1] + (b[1] - a[1]) * t)), int(round(a[0] + (b[0] - a[0]) * t))] = colour + (255,)

    hexagon = [(cx + 7.5 * np.cos(np.radians(60 * k)), cy + 7.5 * np.sin(np.radians(60 * k))) for k in range(6)]
    for k in range(6):
        line(hexagon[k], hexagon[(k + 1) % 6], white)
        a = np.radians(60 * k + 30)  # навпроти середини сторони
        line((cx + 8.6 * np.cos(a), cy + 8.6 * np.sin(a)), (cx + 10.2 * np.cos(a), cy + 10.2 * np.sin(a)), violet)
    put((np.abs(xx - cx) < 1) & (np.abs(yy - cy) < 1), white)
    put(((np.abs(xx - cx) < 2) & (np.abs(yy - cy) < 2)) & (q[..., 3] == 0), violet)
    # вогник над кільцем: ширина рядка від вершини вниз, зміщення язика ліворуч / праворуч
    for y, (x0, x1) in enumerate([(16, 16), (15, 16), (15, 17), (14, 17), (14, 18), (13, 18)]):
        for x in range(x0, x1 + 1):
            inner = x0 < x < x1 and y >= 2
            q[y, x] = (white if inner and x == 16 else lilac if inner else violet) + (255,)
    q[3, 19] = q[2, 12] = violet + (255,)
    pulse = q.copy()  # пульс — кільце на піксель тонше (ерозія з'їла б однопіксельний шестикутник)
    pulse[(d >= 12.4) & (d < 13.0), 3] = 0
    outs = [grow(q, 0.45), grow(q, 0.75), q, pulse]
    for out in outs:
        mask = out[..., 3] > 0
        out[ndimage.binary_dilation(mask) & ~mask] = A9_OUTLINE["searing_hex"] + (255,)
    return outs


def frames(kind, opaque):
    """Кадри з однієї картинки: поява (частина, що вже промайнула) → повний → тоншає."""
    h, w = opaque.shape
    yy, xx = np.mgrid[:h, :w]
    if kind == "arc":  # мах згори вниз: спершу верх дуги
        return [opaque & (yy < h * 0.55), opaque, erode(opaque, 2)]
    if kind == "thrust":
        return [
            opaque,
            erode(opaque, 1) | (opaque & (xx > w * 0.8)),
            opaque & (xx > w * 0.45) & erode(opaque, 1),
        ]
    if kind == "cut":  # розтин іде знизу зліва вгору направо
        return [
            opaque & (xx + (h - yy) < (w + h) * 0.5),
            opaque,
            erode(opaque, 1),
            erode(opaque, 2),
        ]
    # down — згори вниз, up — знизу вгору, right — зліва направо: поява → повний → тоншає
    head = {"down": yy < h * 0.45, "up": yy > h * 0.55, "right": xx < w * 0.5}.get(kind)
    if head is not None:
        return [opaque & head, opaque, erode(opaque, 1)]
    return [opaque]


if __name__ == "__main__":
    drawn = {"hit_cut": ("Hit/cut_%d", draw_cut), "thrust": ("Smear/thrust_%d", draw_thrust),
             "punch": ("Smear/punch_%d", draw_punch),
             "searing_hex_charge": ("Skills/searing_hex/charge_%d", draw_hex_sigil)}  # малює скрипт, без моделі
    names = sys.argv[1:] or [*FX, *drawn]
    for name in names:
        if name in drawn:
            for i, out in enumerate(drawn[name][1](), 1):
                Image.fromarray(out).save(OUT + drawn[name][0] % i + ".png")
                print("wrote", OUT + drawn[name][0] % i + ".png")
            continue
        fx = FX[name]
        img = generate(name, fx)
        if "crop" in fx:  # лишити верхню частку генерації
            img = img[: int(img.shape[0] * fx["crop"])]
        a = key(img, fx["key"])
        if "rotate" in fx:  # проти годинникової, полотно розширюється
            img = np.asarray(
                Image.fromarray(img.astype(np.uint8)).rotate(
                    fx["rotate"], expand=True, fillcolor=(0, 255, 0)
                ),
                np.float32,
            )
            a = (
                np.asarray(
                    Image.fromarray((a * 255).astype(np.uint8)).rotate(
                        fx["rotate"], expand=True
                    ),
                    np.float32,
                )
                / 255
            )
        if fx.get("flip"):  # модель малює вістря вгору — перевернути
            img, a = img[::-1].copy(), a[::-1].copy()
        if fx.get("main", True):
            a = main_shape(a)
        canvas, opaque = fit(img, a, fx)
        if "taper" in fx:
            opaque = taper(opaque, fx["taper"])
        q = cb.quantize(canvas, opaque, fx["colors"], "octree")
        if (
            fx["kind"] == "charge"
        ):  # заряд росте з центру → повний → пульс тонше (кадри 3–4 — петля утримання)
            pulse = q.copy()
            pulse[..., 3] *= erode(opaque, 1)
            outs = [grow(q, 0.45), grow(q, 0.75), q, pulse]
            if "outline" in fx:
                for out in outs:
                    mask = out[..., 3] > 0
                    out[ndimage.binary_dilation(mask) & ~mask] = fx["outline"] + (255,)
        else:
            outs = []
            masks = [opaque, opaque, erode(opaque, 1)] if fx.get("heavy") else frames(fx["kind"], opaque)
            for i, mask in enumerate(masks):
                outs.append(q.copy())
                outs[-1][..., 3] = mask.astype(np.uint8) * 255
                if fx.get("heavy") and i == 0:  # спалах удару: кольори розпечені до білого (чи до кольору flash)
                    hot = np.array(fx.get("flash", (255, 255, 255)), np.float32)
                    outs[-1][..., :3] = hot - (hot - outs[-1][..., :3]) * 0.3
                if "outline" in fx:
                    ring = ndimage.binary_dilation(mask) & ~mask
                    outs[-1][ring] = fx["outline"] + (255,)
        for path, out in zip(fx["frames"], outs):
            os.makedirs(os.path.dirname(OUT + path), exist_ok=True)
            Image.fromarray(out).save(OUT + path + ".png")
            print("wrote", OUT + path + ".png")
    urllib.request.urlopen(
        urllib.request.Request(
            cb.API + "/free",
            json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )
