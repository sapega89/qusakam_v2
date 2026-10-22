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
        box=(4, 4, 68, 68),  # правий край = центр + SMEAR_RADIUS; хвости півмісяця тягнуться назад
        frames=["Smear/arc_1", "Smear/arc_2", "Smear/arc_3"],
        prompt="a single sharp sword slash crescent, a thin curved arc bulging to the right like the right half of a "
        "thin ring, thick in the middle and tapering to needle points at the top and the bottom, bright white core "
        "with a pale icy blue edge, a few thin straight speed lines along the curve, centered, "
        + GREEN,
    ),
    "thrust": dict(
        seed=12,
        size=(1024, 512),
        key="green",
        colors=6,
        kind="thrust",
        canvas=(72, 24),
        box=(0, 6, 72, 18),
        frames=["Smear/thrust_1", "Smear/thrust_2", "Smear/thrust_3"],
        prompt="a single horizontal white light streak like a long thin flat comet tail, brightest and widest at "
        "its right end with a blunt rounded tip, fading to a thin line toward the left, a pale icy blue rim, "
        + GREEN,
    ),
    # Тричі модель на «розтин» малювала меч — розтин зроблено зі смуги уколу, повернутої навскіс;
    # іскри-осколки — частинки HitImpact.tscn.
    "hit_cut": dict(
        src="thrust",
        rotate=35,
        key="green",
        colors=6,
        kind="cut",
        canvas=(64, 64),
        box=(4, 8, 60, 56),
        frames=["Hit/cut_1", "Hit/cut_2", "Hit/cut_3", "Hit/cut_4"],
    ),
    # Удар кулаком — коротка смуга уколу по центру полотна (раніше — кругле «вибух»-коло, Sapega: не про хак-енд-слеш).
    "punch": dict(
        src="thrust",
        key="green",
        colors=6,
        kind="thrust",
        canvas=(28, 28),
        box=(0, 10, 28, 18),
        frames=["Smear/punch_1", "Smear/punch_2", "Smear/punch_3"],
    ),
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
        "white hot yellow core, orange flames, red tongues at the edges, flat bottom, front view, " + GREEN,
    ),
    "boss_mark": dict(
        seed=23,
        size=(1024, 512),
        key="green",
        colors=6,
        kind="sprite",
        canvas=(48, 10),
        box=(0, 0, 48, 10),
        frames=["Bosses/mark"],
        prompt="a single flat glowing ellipse of red hot embers and cracks on the ground seen from a low side angle, "
        "a thin wide horizontal oval, orange glow, " + GREEN,
    ),
    "boss_shockwave": dict(
        seed=24,
        size=(1024, 512),
        key="magenta",
        colors=6,
        kind="sprite",
        canvas=(56, 28),
        box=(0, 0, 56, 28),
        frames=["Bosses/shockwave"],
        prompt="a single ground shockwave of sandy dust and small rock chunks rolling to the right, a low curling "
        "wave of beige dust, tallest at its right front edge, flat bottom, side view, " + MAGENTA,
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
    "arrow_charged": dict(
        seed=32,
        size=(1024, 384),
        key="magenta",
        colors=7,
        kind="sprite",
        main=False,
        canvas=(36, 13),
        box=(0, 0, 36, 13),
        frames=["Projectiles/arrow_charged"],
        # перша спроба: сяйво тонке й бліде — велике жовте сяйво навколо наконечника
        prompt="a single short thick chunky arrow flying to the right, perfectly horizontal, side view, 16-bit pixel "
        "art with a thick dark outline, a thick brown wooden shaft, a very large wide triangular arrowhead glowing "
        "bright yellow, surrounded by a big solid round bright yellow and white glow around the arrowhead and a thick "
        "glowing yellow trail along the shaft, white feather fletchings, filling the whole width of the picture, "
        + MAGENTA,
    ),
}


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
    oy = y0 + (y1 - y0 - h) // 2
    canvas[oy : oy + h, ox : ox + w] = rgb
    opaque[oy : oy + h, ox : ox + w] = asum > 0.45
    return canvas, opaque


def erode(m, n):
    for _ in range(n):
        e = m.copy()
        e[1:] &= m[:-1]
        e[:-1] &= m[1:]
        e[:, 1:] &= m[:, :-1]
        e[:, :-1] &= m[:, 1:]
        m = e
    return m


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
    return [opaque]


if __name__ == "__main__":
    names = sys.argv[1:] or list(FX)
    for name in names:
        fx = FX[name]
        img = generate(name, FX[fx["src"]]) if "src" in fx else generate(name, fx)
        a = key(img, fx["key"])
        if "rotate" in fx:  # проти годинникової, полотно розширюється
            img = np.asarray(Image.fromarray(img.astype(np.uint8)).rotate(fx["rotate"], expand=True, fillcolor=(0, 255, 0)), np.float32)
            a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).rotate(fx["rotate"], expand=True), np.float32) / 255
        if fx.get("main", True):
            a = main_shape(a)
        canvas, opaque = fit(img, a, fx)
        q = cb.quantize(canvas, opaque, fx["colors"], "octree")
        for path, mask in zip(fx["frames"], frames(fx["kind"], opaque)):
            out = q.copy()
            out[..., 3] = mask.astype(np.uint8) * 255
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
