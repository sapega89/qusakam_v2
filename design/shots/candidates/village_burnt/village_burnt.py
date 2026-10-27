"""M6a-3: спалене село (D796). Кожен план Village — та сама картинка «після пожежі»: img2img над оригіналом (denoise
0.6), стіни цілі, сажа над дверима й вікнами, тенти — обгорілі рами, пальми й дерево обвуглені, жар; дим з кількох
дахів (джерело шлейфу дороги), у gen_back — ще й завіса диму над дахами (небо темніше й димніше).
Розміри й якорі — як в оригіналів: непрозоре = непрозоре оригіналу (будинки не стають «порожніми коробками», як у
першому прогоні на уступах), нове непрозоре дозволене лише в намальованих скриптом смугах диму.
  python -B design/shots/candidates/village_burnt/village_burnt.py gen    — ComfyUI (сирі PNG поруч, ≤ 4 за раз)
  python -B design/shots/candidates/village_burnt/village_burnt.py build  — *_burnt.png + RockLedges/gen_burnt_houses.png
  python -B design/shots/candidates/village_burnt/village_burnt.py sheet  — design/shots/m6a3_burnt_village.png і стик з уступами
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, "Scripts/Tools")
import comfy_backdrop as cb

D = os.path.dirname(os.path.abspath(__file__))
V = cb.OUT + "Village/"
K = 3
DENOISE = 0.45  # 0.6 переставляв будинки gen_back і стирав бруківку; тепер напрямна вже «обгоріла» (pre_burn)
SEAM_DENOISE = 0.5  # смуга шву (0.9 comfy_backdrop малював на краях нові будинки)

BURNT = (
    "the walls of brick and clay stay whole and unbroken, black soot streaks above every doorway and window, the cloth "
    "awnings burnt away leaving only charred bare wooden frames with a few black rags, charred black doors and "
    "shutters, wooden roof beams burnt to black stumps, charred black palm trunks with a few burnt brown fronds, "
    "glowing orange embers in a few windows and doorways"
)
SMOKE = (
    "thick dark grey smoke rising from the roofs and leaning to the left in the wind"
)

# план: (seed, кількість кольорів, шов (плитка ×576), дим [(x даху, висота стовпа, нахил)], підказка)
PLANES = {
    "gen_back": (
        871,
        14,
        True,
        [(160, 130, 60), (300, 120, 50), (390, 130, 70), (500, 120, 50)],
        "a distant row of flat-roofed desert village houses, a square watchtower and domed houses after a great fire, "
        f"{BURNT}, {SMOKE}, the smoke spreading into a low dark smoky haze hanging over the rooftops, {cb.MAGENTA}, "
        f"{cb.STYLE}",
    ),
    "gen_houses": (
        872,
        18,
        True,
        [(165, 120, 50), (290, 110, 40), (395, 125, 55), (530, 105, 40)],
        "a row of small adobe desert village houses joined wall to wall after a great fire, with clay jars and baskets "
        f"in front, {BURNT}, {SMOKE}, {cb.MAGENTA}, {cb.STYLE}",
    ),
    "gen_grandpa_house": (
        873,
        18,
        False,
        [],
        "an old man's small adobe desert house after a great fire, still standing, a wooden roof of logs charred black, "
        "a doorway with a burnt awning frame, a shuttered window, a bunch of dried peppers, a walking staff, a clay jar, "
        f"a scorched wooden bench and a basket in front, {BURNT}, {cb.MAGENTA}, {cb.STYLE}",
    ),
    "gen_elder_house": (
        874,
        18,
        False,
        [],
        "the village elder's wide one-storey adobe house after a great fire, still standing, a crenellated roof "
        "terrace, a closed arched wooden double door charred black, a porch with wooden posts and the striped awning "
        "burnt to a bare charred frame, two hanging banners burnt to tatters, clay jars, stone steps, "
        f"{BURNT}, {cb.MAGENTA}, {cb.STYLE}",
    ),
}


def raw(name, tag=""):
    return os.path.join(D, f"{name}{tag}_raw.png")


def orig(name):
    return np.asarray(Image.open(V + name + ".png").convert("RGBA"))


def smoke(name, shape, draw=None):
    """Стовпи диму з дахів (x даху, висота, нахил на захід): маска в px плану; з draw — ще й сірий дим у напрямній.
    У gen_back верхівки стовпів зливаються в завісу над дахами."""
    _, _, _, plumes, _ = PLANES[name]
    a = orig(name)[..., 3] > 0
    mask = Image.new("L", shape[::-1], 0)
    md = ImageDraw.Draw(mask)
    rng = np.random.default_rng(PLANES[name][0])
    for x, hgt, lean in plumes:
        roof = int(np.argmax(a[:, x]))
        for i in range(14):
            t = i / 13
            cx, cy = x - lean * t**1.5 + rng.normal(0, 1.5), roof - 2 - t * hgt
            r = 3 + 11 * t
            box = (cx - r, cy - r * 0.8, cx + r, cy + r * 0.8)
            md.ellipse(box, 255)
            if draw:
                g = int(70 + 70 * t)
                draw.ellipse(box, fill=(g, g - 4, g + 4))
    if name == "gen_back":  # завіса: пасмо диму від верхівок на захід
        for i in range(40):
            cx, cy = (
                60 + i * 12 + rng.normal(0, 4),
                42 + 8 * np.sin(i / 3) + rng.normal(0, 2),
            )
            r = 14 + rng.normal(0, 3)
            box = (cx - r, cy - r * 0.6, cx + r, cy + r * 0.6)
            md.ellipse(box, 255)
            if draw:
                g = int(115 + rng.normal(0, 8))
                draw.ellipse(box, fill=(g, g - 6, g + 2))
    return np.asarray(mask.filter(ImageFilter.MaxFilter(5))) > 0


def pre_burn(rgb, opaque):
    """Напрямна вже після пожежі, щоб модель не мусила перемальовувати багато: насичене (тенти, прапори, дерево,
    листя) — у вугіль, над темними дверима й вікнами — сажа, що слабне догори."""
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    violet = (b >= mx) & (r > g)  # фіолетові тіні стін лишаються
    char = opaque & ~violet & ((sat > 0.5) | ((b >= mx) & (sat > 0.35))) & (mx > 60)
    out = rgb.copy()
    out[char] = out[char] * 0.18 + np.array([40, 34, 38]) * 0.82
    dark = opaque & (mx < 90)
    rng = np.random.default_rng(1)
    soot = np.zeros(rgb.shape[:2], np.float32)
    for d in range(1, 14):
        up = np.zeros_like(dark)
        up[:-d] = dark[d:]
        soot = np.maximum(soot, up * (1 - d / 14))
    soot *= opaque & ~dark
    soot *= rng.uniform(0.5, 1, rgb.shape[1])[None, :]  # патьоки нерівні
    out = (
        out * (1 - 0.75 * soot[..., None])
        + np.array([30, 26, 30]) * 0.75 * soot[..., None]
    )
    return out


def guide(name):
    """Оригінал над magenta + дим, ×3, ширина й висота доповнені до кратних 16."""
    v = orig(name).astype(np.float32)
    al = v[..., 3:] / 255
    rgb = v[..., :3] * al + np.array([255, 0, 255], np.float32) * (1 - al)
    img = Image.fromarray(pre_burn(rgb, v[..., 3] > 0).astype(np.uint8))
    smoke(name, rgb.shape[:2], ImageDraw.Draw(img))
    big = np.asarray(
        img.resize((img.width * K, img.height * K), Image.NEAREST).filter(
            ImageFilter.GaussianBlur(2)
        )
    )
    h, w = -(-big.shape[0] // 16) * 16, -(-big.shape[1] // 16) * 16
    out = np.zeros((h, w, 3), np.uint8)
    out[:] = (255, 0, 255)
    out[: big.shape[0], : big.shape[1]] = big
    return out, big.shape[:2]


def gen():
    for name, (seed, _, seam, _, text) in PLANES.items():
        if os.path.exists(raw(name)):
            continue
        g, (h, w) = guide(name)
        rgba = np.concatenate(
            [g, np.zeros((*g.shape[:2], 1), np.uint8)], 2
        )  # маска на все полотно
        up = cb.upload(rgba, f"village_burnt_{name}.png")
        out = cb.run(cb.graph(text, seed, g.shape[0], up, DENOISE, width=g.shape[1]))
        if seam:
            cb.SEAM_DENOISE = SEAM_DENOISE  # плитка 576: шов посередині, модель перемальовує смугу (метод comfy_backdrop)
            out = np.roll(out, out.shape[1] // 2, 1)
            out = np.roll(
                cb.seam_pass(out, {"seed": seed}, text, out.shape[0]),
                -out.shape[1] // 2,
                1,
            )
        Image.fromarray(out[:h, :w].astype(np.uint8)).save(raw(name))
        print(name, flush=True)
    cb.urllib.request.urlopen(
        cb.urllib.request.Request(
            cb.API + "/free",
            cb.json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )


def burnt(name):
    """Сира генерація → план у пікселях гри: непрозоре = оригінал ∪ (дим за ключем у смугах диму)."""
    _, colors, _, _, _ = PLANES[name]
    o = orig(name)
    img = np.asarray(Image.open(raw(name)).convert("RGB"), np.float32)
    # дим — ключ зі spill (пурпурні тіні моделі на тлі геть); будинки — без spill: фіолетові тіні стін і бруківка
    # (min(r, b) − g ≈ 15) під spill 12 ставали «тлом» і чорніли
    rgb_s, smoke_k = cb.shrink(img.copy(), "magenta", 12)
    rgb_k, ak = cb.shrink(img.copy(), "magenta")
    base = o[..., 3] > 0
    in_smoke = smoke(name, base.shape) & ~base
    opaque = base | (smoke_k & in_smoke)
    rgb = np.where(in_smoke[..., None], rgb_s, rgb_k)
    # де модель лишила тло всередині силуету — колір оригіналу, приглушений (обгоріле), а не небо крізь стіну
    pink = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1] > 60  # край, змішаний із тлом (рожева облямівка)
    gutted = base & (~ak | pink)
    rgb[gutted] = o[gutted][:, :3] * 0.45
    return cb.quantize(rgb, opaque, colors, "octree")


# RockLedges/gen_burnt_houses — ті самі три будинки (ledges_planes.HOUSES_PICK) з gen_houses_burnt: уступи й село
# збігаються, а дірки «порожньої коробки» зникають (непрозоре — оригінал)
PICK = ((100, 232), (232, 332), (332, 456))
GAP, ROWS, KEEP, PAD = 12, 272, 240, 45


def ledges_houses(h):
    canvas = np.zeros((ROWS, 576, 4), np.uint8)
    x = 0
    for x0, x1 in PICK:
        canvas[:, x : x + x1 - x0] = h[:ROWS, x0:x1]
        x += x1 - x0 + GAP
    q = canvas[:KEEP].astype(np.float32)
    q[..., :3] = np.round(
        q[..., :3] * 0.85 + cb.HAZE * 0.15
    )  # серпанок, як у ledges_planes (за муром)
    q = q.astype(np.uint8)
    ys, xs = np.nonzero(q[..., 3])
    q = q[ys.min() :, xs.min() : xs.max() + 1]
    return np.concatenate([q, np.repeat(q[-1:], PAD, 0)])


def build():
    out = {}
    for name in PLANES:
        q = burnt(name)
        o = orig(name)
        assert q.shape == o.shape, name
        assert ((o[..., 3] > 0) <= (q[..., 3] > 0)).all(), f"{name}: дірка в будинку"
        Image.fromarray(q).save(V + name + "_burnt.png")
        out[name] = q
        print(
            name,
            q.shape,
            len(np.unique(q[q[..., 3] > 0][:, :3], axis=0)),
            "colours",
            flush=True,
        )
    for name in (
        "gen_back",
        "gen_houses",
    ):  # плитка: стовпець 0 продовжує стовпець 575 (шов — смуга моделі)
        q = out[name].astype(int)
        both = (q[:, 0, 3] > 0) & (q[:, -1, 3] > 0)
        print(
            name,
            "seam mean diff",
            np.abs(q[both, 0, :3] - q[both, -1, :3]).mean().round(1),
        )
    lh = ledges_houses(out["gen_houses"])
    Image.fromarray(lh).save(cb.OUT + "RockLedges/gen_burnt_houses.png")
    print("RockLedges/gen_burnt_houses", lh.shape, flush=True)


# ---- аркуш: кімната Village у пікселях арту (світ / 1.5), камера — лівий верхній кут кадру 576×324 ----
VW, VH = 576, 324
BD = "SampleProject/Assets/Backgrounds/"


def img(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float32)


def paste(c, im, x, y):
    x, y = int(round(x)), int(round(y))
    h, w = im.shape[:2]
    x0, y0, x1, y1 = (
        max(x, 0),
        max(y, 0),
        min(x + w, c.shape[1]),
        min(y + h, c.shape[0]),
    )
    if x0 >= x1 or y0 >= y1:
        return
    s = im[y0 - y : y1 - y, x0 - x : x1 - x]
    a = s[..., 3:] / 255
    c[y0:y1, x0:x1, :3] = s[..., :3] * a + c[y0:y1, x0:x1, :3] * (1 - a)


def village_planes(burnt_on):
    """(картинка, множник, якір (арт), плитка, модуляція) з Village.tscn і desert_backdrop_canyon.tscn; рядки регіонів
    як у сцені. Спалене: Back і Houses з рядка 0 (дим над дахами — регіон треба відкрити), фон темніший."""
    t = "_burnt" if burnt_on else ""
    sky_mod = np.array([0.72, 0.66, 0.68]) if burnt_on else np.ones(3)
    by = -100 / 1.5  # Backdrop y −100
    sky = img(BD + "DesertOasis/bg4/plan5.png")
    clouds = img(BD + "Canyon/gen_clouds.png")[:196, 16:544]
    far = img(BD + "Canyon/gen_far.png")
    far[:112, :, 3] = 0
    walls = img(BD + "Canyon/gen_walls.png")
    walls[:144, :, 3] = 0
    p1 = img(BD + "DesertOasis/bg4/plan1.png")
    p1[:272, :, 3] = 0
    back = img(V + f"gen_back{t}.png")
    houses = img(V + f"gen_houses{t}.png")
    if not burnt_on:
        back[:80, :, 3] = 0
        houses[:112, :, 3] = 0
    houses[276:, :, 3] = 0
    houses[..., :3] *= (0.9, 0.88, 0.94)
    return [
        (sky, 0.0, (0, by), 576, sky_mod),
        (clouds, 0.1, (16, by), 576, sky_mod),
        (far, 0.3, (0, by), 576, sky_mod),
        (walls, 0.45, (0, by + 32), 576, sky_mod),
        (p1, 0.75, (0, by), 576, sky_mod),
        ("veil", None, None, None, None),
        (back, 0.6, (0, -2), 576, None),
        (houses, 0.85, (0, -2), 576, None),
        (img(V + f"gen_grandpa_house{t}.png"), 1.0, (932, 102.67), None, None),
        (img(V + f"gen_elder_house{t}.png"), 1.0, (1260, 100), None, None),
        (img(BD + "Terrain/Village_Terrain.png"), 1.0, (0, 0), None, None),
    ]


def village_view(burnt_on, cx, cy, hero_x=None):
    c = np.zeros((VH, VW, 4), np.float32)
    c[..., :3] = img(BD + "DesertOasis/bg4/plan5.png")[0, 0, :3] * (
        0.72 if burnt_on else 1
    )  # SkyTop
    c[..., 3] = 255
    for im, f, anchor, tile, mod in village_planes(burnt_on):
        if isinstance(im, str):
            # Veil: від y 96 до 390 світу (64–260 арту) серпанок (214,214,224) з прозорості 0 до 0.4
            for y in range(max(64 - int(cy), 0), min(260 - int(cy), VH)):
                a = 0.4 * (y + cy - 64) / 196
                c[y, :, :3] = c[y, :, :3] * (1 - a) + cb.HAZE * a
            continue
        if mod is not None:
            im = im.copy()
            im[..., :3] *= mod
        ax, ay = anchor
        x0, y0 = ax - f * cx, ay - cy
        for x in [x0] if tile is None else range(int(x0) % tile - tile, VW, tile):
            paste(c, im, x, y0)
    if hero_x is not None:
        hero = hero_img()
        paste(c, hero, hero_x - cx - 32, 256 - cy - len(hero))
    return c[..., :3]


def hero_img():
    h = img("SampleProject/Sprites/Player/Walk/1.png")
    ys = np.nonzero(h[..., 3])[0]
    return h[: ys.max() + 1]


def sheet():
    cy = 0  # однокліткова кімната: кадр 486 світу з верху кімнати
    shots = [
        ("West entrance (from the Rock Ledges)", 0, 120),
        ("Grandfather's house", 870, 1010),
        ("Elder's house, east end", 1152, 1320),
    ]
    tw, th, lab, gap = 954, 536, 24, 12
    out = Image.new("RGB", (1920, len(shots) * (th + lab + gap)), (24, 22, 28))
    d = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    for r, (title, cx, hx) in enumerate(shots):
        y = r * (th + lab + gap)
        for i, b in enumerate((False, True)):
            v = village_view(b, cx, cy, hx)
            x = i * (tw + gap)
            out.paste(
                Image.fromarray(v.astype(np.uint8)).resize((tw, th), Image.NEAREST),
                (x, y + lab),
            )
            d.text(
                (x + 6, y + 6),
                f"{title} - {'after (burnt)' if b else 'before'}",
                fill=(235, 225, 200),
                font=font,
            )
    out.save("design/shots/m6a3_burnt_village.png")
    print("sheet", out.size, flush=True)

    # стик: верхній кадр уступів (пролам у мурі) | західний вхід у село
    sys.path.insert(0, "design/shots/candidates/ledges_planes")
    sys.path.insert(0, "design/shots/candidates/path_planes")
    sys.path.insert(0, "design/shots/candidates/gorge_planes")
    import ledges_planes as lp

    hero = hero_img()
    a = lp.view(lp.planes(), lp.CY[0], (lp.X0 + 400, lp.TOP, hero))[..., :3]
    b = village_view(True, 0, cy, 120)
    out = Image.new("RGB", (1920 * 2 + gap, 1080 + lab), (24, 22, 28))
    d = ImageDraw.Draw(out)
    for i, (title, v) in enumerate(
        (
            (
                "Rock Ledges, top frame: the breach and the burnt houses beyond the wall",
                a,
            ),
            ("Village, west entrance (burnt): the same houses up close", b),
        )
    ):
        x = i * (1920 + gap)
        out.paste(
            Image.fromarray(v.astype(np.uint8)).resize((1920, 1080), Image.NEAREST),
            (x, lab),
        )
        d.text((x + 6, 6), title, fill=(235, 225, 200), font=font)
    out.save("design/shots/m6a3_ledges_to_village.png")
    print("ledges | village", out.size, flush=True)


if __name__ == "__main__":
    {
        "gen": gen,
        "build": build,
        "sheet": sheet,
        "guide": lambda: [
            Image.fromarray(guide(n)[0]).save(raw(n, "_guide")) for n in PLANES
        ],
    }[sys.argv[1]]()
