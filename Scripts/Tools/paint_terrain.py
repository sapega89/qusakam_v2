"""Земля кімнат (D248, D249): по масці твердого з build_terrain.gd малює картинку землі з матеріалів, які генерує
ComfyUI (Qwen-Image, Apache 2.0) тим самим конвеєром, що й фони (comfy_backdrop.py): тіло — безшовна текстура
породи, верх — смуга поверхні (пісок із сухою травою, бруківка, трава оази, підлога зали) по кожній кромці, на яку
можна стати. Верх кромки рівний — там колізія; бічні краї й низи стерті нерівно, обведені й притінені, тіло
темнішає з глибиною. Пікселі — пікселі гри (×1.5 у світі, як у героя); палітра зводиться на кімнату.
Запуск (з кореня проєкту, між двома кроками build_terrain.gd): python -I Scripts/Tools/paint_terrain.py [кімната ...]
"""

import os
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comfy_backdrop as cb  # noqa: E402

MASKS = os.path.join(tempfile.gettempdir(), "terrain_masks")
OUT = "SampleProject/Assets/Backgrounds/Terrain/"

# Матеріали: body — непрозора безшовна текстура породи, top — смуга поверхні на ключі (небо над нею прозоре) або
# непрозора (підлога зали). h — висота генерації (px моделі, кратна 16), f — скільки px моделі в пікселі гри: тіло
# зменшується сильніше (f 6), щоб шари породи були в масштабі героя, а не на пів екрана. Підказки — за правилами
# comfy-backdrop: без «pixel art», без «sun»; стиль фонів (STYLE) тут не додається — з ним модель малює сцену
# з небом і підлогою замість текстури.
TEXTURE = "flat matte painting, soft painterly shading, warm highlights and cool violet shadows"
MATERIALS = {
    "sandstone": dict(
        seed=321,
        h=1024,
        f=6,
        key=None,
        prompt="a seamless texture, close-up of a flat smooth sandstone wall surface seen straight on, the rock fills "
        "the entire image edge to edge with no gaps, many thin wavy horizontal strata in warm orange, ochre, rust red "
        "and pale cream, small embedded pebbles and fine hairline cracks, evenly detailed everywhere",
    ),
    "earth": dict(
        seed=341,
        h=1024,
        f=6,
        key=None,
        prompt="a seamless texture, close-up of a flat smooth packed earth wall surface seen straight on, the soil "
        "fills the entire image edge to edge with no gaps, many thin wavy horizontal strata in warm tan, ochre, sienna "
        "brown and pale cream, small embedded pebbles and fine hairline cracks, evenly detailed everywhere",
    ),
    "hall_body": dict(
        seed=313,
        h=1024,
        f=6,
        key=None,
        prompt="a seamless texture of a wall of large cut sandstone blocks, one continuous flat surface of masonry fills the entire image edge to "
        "edge, staggered rectangular blocks with worn chipped edges and dark mortar lines, warm beige, evenly "
        "detailed everywhere",
    ),
    "sand_top": dict(
        seed=305,
        h=192,
        f=4,
        key="green",
        prompt="the top edge of desert ground seen from the side, spanning the full width: a thin band of light golden "
        "sand along the top with small tufts of dry yellow grass and little pebbles sticking up, under it weathered "
        "orange sandstone, filling the lower part down to the bottom edge, the empty space above "
        f"{cb.CHROMA}",
    ),
    "cobble_top": dict(
        seed=307,
        h=192,
        f=4,
        key="green",
        prompt="the top edge of an old road seen from the side, spanning the full width: a row of small rounded worn "
        "sandstone cobbles of different sizes set in sand along the top, small pebbles and dry yellow grass tufts "
        "between them, packed brown earth below, filling the lower part down to the bottom edge, the empty space "
        f"above {cb.CHROMA}",
    ),
    "oasis_top": dict(
        seed=309,
        h=192,
        f=4,
        key="magenta",
        prompt="the top edge of oasis ground seen from the side, spanning the full width: a band of short lush green "
        "grass with small reeds, tiny white flowers and clumps of moss along the top, damp dark sand below, filling "
        f"the lower part down to the bottom edge, the empty space above {cb.MAGENTA}",
    ),
    "hall_floor": dict(
        seed=311,
        h=192,
        f=4,
        key=None,
        prompt="a side cross-section of a palace floor spanning the full width and filling the frame from top to "
        "bottom: along the top a row of polished cream marble floor tiles with a thin golden inlay line, below them "
        "a band of carved sandstone blocks with a repeating geometric frieze, seen straight on",
    ),
}

# Картинка (= <кімната>_<вузол> з build_terrain.gd) → тіло, верх, кольорів у палітрі.
PAINT = {
    "Canyon_Terrain": ("sandstone", "sand_top", 32),
    "Canyon_Gorge": ("sandstone", "sand_top", 32),
    "Village_Terrain": ("earth", "sand_top", 32),
    "DesertRoad_Terrain": ("earth", "cobble_top", 32),
    "CityGates_Terrain": ("earth", "cobble_top", 32),
    "City_Terrain": ("earth", "cobble_top", 32),
    "LaboratoryOutside_Terrain": ("sandstone", "oasis_top", 32),
    "MayorHall_Terrain": ("hall_body", "hall_floor", 32),
}

FLAT = 6  # верхні px під кромкою не стираються: стоїш рівно на колізії
KEEP = 8  # px смуги поверхні під кромкою цілком
FADE = 8  # далі смуга переходить у тіло плямами


def generate(layer):
    """Картинка матеріалу в px моделі, безшовна по горизонталі (модель перемальовує шов, як у фонах); кеш — у
    кеші comfy_backdrop за підказкою, зерном і висотою."""
    text = f"{layer['prompt']}, {TEXTURE}"
    tag = cb.json.dumps([text, layer["seed"], layer["h"]])
    path = os.path.join(cb.CACHE, "terrain_" + cb.hashlib.sha1(tag.encode()).hexdigest()[:16] + ".png")
    if os.path.exists(path):
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    img = cb.run(cb.graph(text, layer["seed"], layer["h"]))
    img = cb.seam_pass(np.roll(img, cb.GW // 2, axis=1), layer, text, layer["h"])
    os.makedirs(cb.CACHE, exist_ok=True)
    Image.fromarray(img.astype(np.uint8)).save(path)
    return img


def material(name):
    """(rgb, непрозоре) у пікселях гри: фон-ключ прозорий, колір блоку — лише з непрозорих px моделі."""
    layer = MATERIALS[name]
    img, f = generate(layer), layer["f"]
    a = np.ones(img.shape[:2], np.float32)
    if layer["key"]:
        bg = np.median(img[:24].reshape(-1, 3), axis=0)
        a = (np.linalg.norm(img - bg, axis=2) > cb.KEY_DISTANCE).astype(np.float32)
    if layer["key"] == "green":
        img[..., 1] = np.minimum(img[..., 1], np.maximum(img[..., 0], img[..., 2]))
    rows, cols = img.shape[0] // f, img.shape[1] // f
    img, a = img[: rows * f, : cols * f], a[: rows * f, : cols * f]

    def blocks(m):
        return m.reshape(rows, f, cols, f, -1).sum(axis=(1, 3))

    asum = blocks(a[..., None])
    return blocks(img * a[..., None]) / np.maximum(asum, 1e-6), asum[..., 0] >= f * f / 2


def noise1d(n, seed, scale):
    """Плавний шум 0..1 довжиною n: сума кількох синусоїд із випадковими фазами."""
    rng = np.random.default_rng(seed)
    t = np.arange(n, dtype=np.float32)
    v = sum(np.sin(t / (scale * k) + rng.uniform(0, 6.3)) / k for k in (1, 2.3, 4.7))
    return (v - v.min()) / max(np.ptp(v), 1e-6)


def run_lengths(solid, axis, reverse, outside):
    """Скільки суцільних твердих px до повітря вздовж осі (вгору/вниз/вбік); за межею картинки — outside."""
    a = np.moveaxis(solid, axis, 0)
    if reverse:
        a = a[::-1]
    out = np.zeros(a.shape, np.int32)
    prev = np.full(a.shape[1:], 10_000 if outside else 0, np.int32)
    for i in range(len(a)):
        prev = np.where(a[i], prev + 1, 0)
        out[i] = prev
    if reverse:
        out = out[::-1]
    return np.moveaxis(out, 0, axis)


def flatten(top, opaque):
    """Модель малює землю горбами; кромка ж рівна. Кожен стовпець смуги зсувається так, щоб згладжена (медіана ±12 px —
    без кущиків трави) поверхня стала на одну лінію; кущики лишаються стирчати над нею."""
    th, tw = opaque.shape
    first = np.where(opaque.any(axis=0), opaque.argmax(axis=0), th)
    pad = np.concatenate([first[-12:], first, first[:12]])  # смуга безшовна — по колу
    smooth = np.median(np.lib.stride_tricks.sliding_window_view(pad, 25), axis=1).astype(np.int32)
    ground = int(np.median(smooth))
    rows = np.arange(th)[:, None] - (ground - smooth)[None, :]  # рядок джерела для кожного рядка результату
    ok = (rows >= 0) & (rows < th)
    src = np.clip(rows, 0, th - 1)
    cols = np.arange(tw)[None, :]
    flat_top = top[src, cols]
    flat_opaque = opaque[src, cols] & ok
    flat_opaque |= ~ok & (rows >= th)  # знизу смуга продовжується останнім рядком
    flat_top[~ok & (rows >= th)] = top[-1, np.broadcast_to(cols, (th, tw))[~ok & (rows >= th)]]
    return flat_top, flat_opaque, ground


def paint(name, body_name, top_name, colors):
    mask = np.asarray(Image.open(os.path.join(MASKS, name + ".png")).convert("RGB"))
    solid = mask[..., 0] > 127
    h, w = solid.shape
    seed = sum(map(ord, name))
    rng = np.random.default_rng(seed)

    # Стерті бічні краї й низи: верх (FLAT px під кромкою) не чіпаємо — він на лінії колізії.
    down = run_lengths(
        solid, 0, False, True
    )  # px від кромки вниз (1 — сама кромка); від верху картинки — глибоко
    side = np.minimum(
        run_lengths(solid, 1, False, True), run_lengths(solid, 1, True, True)
    )
    up = run_lengths(solid, 0, True, True)  # px до повітря знизу
    wear_x = np.round(noise1d(h, seed, 3.0) * 4).astype(np.int32)[:, None]
    wear_y = np.round(noise1d(w, seed + 1, 3.0) * 3).astype(np.int32)[None, :]
    worn = (down > FLAT) & ((side <= wear_x) | (up <= wear_y))
    solid = solid & ~worn
    down = run_lengths(solid, 0, False, True)
    side = np.minimum(
        run_lengths(solid, 1, False, True), run_lengths(solid, 1, True, True)
    )
    up = run_lengths(solid, 0, True, True)

    body, _ = material(body_name)
    body = np.concatenate(
        [body, body[::-1]]
    )  # по вертикалі — дзеркально, шари сходяться
    ox = rng.integers(0, body.shape[1])
    yy, xx = np.mgrid[0:h, 0:w]
    # повтор текстури ламають хвиля шарів уздовж x і свій зсув для кожного періоду по y
    wave = np.round(noise1d(w, seed + 2, 40.0) * 24).astype(np.int32)[None, :]
    shift = rng.integers(0, body.shape[1], 64)[(yy + wave) // len(body) % 64]
    rgb = body[(yy + wave) % len(body), (xx + ox + shift) % body.shape[1]].astype(np.float32)

    # Темнішає з глибиною; під навісами й біля бічних країв — тінь, по краю — контур.
    # глибина розмита вздовж x: інакше під кожною терасою тінь починалась би заново прямокутником
    k = 81
    pad = np.pad(np.minimum(down, 400).astype(np.float32), ((0, 0), (k // 2, k // 2)), mode="edge")
    c = np.cumsum(pad, axis=1)
    smooth = (c[:, k - 1 :] - np.concatenate([np.zeros((h, 1)), c[:, :-k]], axis=1)) / k
    depth = np.clip((smooth - 30) / 220.0, 0, 1)
    rgb *= (1 - 0.45 * depth)[..., None]
    rgb *= np.where((side >= 2) & (side <= 4), 0.84, 1.0)[..., None]
    rgb *= np.where((up >= 2) & (up <= 6), 0.72, 1.0)[..., None]
    outline_color = np.percentile(body.reshape(-1, 3), 3, axis=0) * 0.55
    outline = solid & ((side == 1) | (up == 1)) & (down > 1)
    rgb[outline] = outline_color

    # Смуга поверхні по кожній кромці (тверде, над ним повітря), лінія землі смуги — на кромці.
    top, top_opaque = material(top_name)
    th = len(top)
    top, top_opaque, ground = flatten(top, top_opaque)
    opaque = solid.copy()
    edge_y, edge_x = np.nonzero(solid & (down == 1))
    sx = (edge_x + 37 * edge_y + ox) % top.shape[1]
    blots = rng.random((64, 64))
    for r in range(th):
        y = edge_y - ground + r
        ok = (y >= 0) & (y < h) & top_opaque[r, sx]
        if r >= ground:  # під кромкою — лише в тілі цієї ж кромки
            ok &= solid[np.clip(y, 0, h - 1), edge_x]
            if r >= ground + KEEP:  # нижче — у тіло плямами 3×3 px, не рівною лінією
                ok &= blots[y // 3 % 64, edge_x // 3 % 64] > (r - ground - KEEP) / FADE
        rgb[y[ok], edge_x[ok]] = top[r, sx[ok]]
        opaque[y[ok], edge_x[ok]] = True

    out = cb.quantize(rgb, opaque, colors, "octree")
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(out).save(OUT + name + ".png")
    print("drawn", OUT + name + ".png", flush=True)


def depths(path, body_name, colors):
    """Задня стіна ущелини каньйону (за ямою під містком, Parallax2D ×0.45): та сама порода, що й земля, темніша з
    глибиною й притоплена у фіолетову тінь, щоб стояла позаду ігрової площини. 576×420, тайлиться по ширині."""
    w, h = 576, 420
    body, _ = material(body_name)
    body = np.concatenate([body, body[::-1]])
    assert w % body.shape[1] == 0, "ширина стіни — ціле число періодів матеріалу, інакше шов на повторі"
    yy, xx = np.mgrid[0:h, 0:w]
    rgb = body[yy % len(body), xx % body.shape[1]].astype(np.float32)
    k = np.clip(yy / h * 1.3, 0, 1)[..., None]
    shadow = np.array([46, 30, 52], np.float32)  # фіолетова тінь, як тіні породи
    rgb = rgb * (0.62 - 0.3 * k) + shadow * (0.38 + 0.3 * k)
    out = cb.quantize(rgb, np.ones((h, w), bool), colors, "octree")
    Image.fromarray(out).save(path)
    print("drawn", path, flush=True)


DEPTHS = ("SampleProject/Assets/Backgrounds/Canyon/canyon_depths.png", "sandstone", 24)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--materials":  # лише згенерувати (шматками по ≤ 2 матеріали — 4 генерації)
        for m in args[1:]:
            material(m)
            print("material", m, flush=True)
        # ComfyUI тримає моделі в ОЗП і після роботи — вивантажуємо одразу (як comfy_backdrop.py)
        cb.urllib.request.urlopen(
            cb.urllib.request.Request(
                cb.API + "/free",
                cb.json.dumps({"unload_models": True, "free_memory": True}).encode(),
                {"Content-Type": "application/json"},
            )
        )
    else:
        for name in [n for n in PAINT if not args or n.split("_")[0] in args]:
            paint(name, *PAINT[name])
        if not args or "Canyon" in args:
            depths(*DEPTHS)
