"""M6a-2b: скельні уступи (1×2 клітинки, 576×640 арту = 864×960 світу) — останній відрізок дороги перед селом: герой
виходить з ущелини внизу ліворуч і стрибає вгору по уступах скелі (без летючих платформ, A15; без драбин) до плато
вгорі праворуч, звідки — прохід у спалене село (Сапега: «горить не вогнище, а все село спалене … з цегли, то не
розбиті, але спалені»). Шлейф робить comfy_backdrop.py (RockLedges/gen_plume); тут — продовження дальньої стіни
ущелини, скеля з уступами, перші спалені будинки за проходом і аркуш.
  python -B design/shots/candidates/ledges_planes/ledges_planes.py gen    — ComfyUI (сирі PNG поруч)
  python -B design/shots/candidates/ledges_planes/ledges_planes.py build  — плани + перевірки (кроки, стебло диму)
  python -B design/shots/candidates/ledges_planes/ledges_planes.py sheet  — design/shots/m6a2b_ledges.png

Одиниці — пікселі арту (світ = ×1.5), початок — лівий верхній кут стежки. Кімната: лівий край x 3456 (ущелина 1728 +
1728), верх y 0 (на рівні стежки), низ 640. Камера: x завжди 3456 (кімната в один екран завширшки), y від 0 (верх) до
316 (низ, як в ущелині). Плани прив'язані до світу: зсув плану з множником f — −f·камера.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, "Scripts/Tools")
sys.path.insert(0, "design/shots/candidates/path_planes")
sys.path.insert(0, "design/shots/candidates/gorge_planes")
import comfy_backdrop as cb
import gorge_planes as gp
import path_planes as pp

D = os.path.dirname(os.path.abspath(__file__))
RL = pp.B + "RockLedges/"
K, W, H = 3, 576, 324
X0 = gp.X0 + gp.ROOM_W  # 3456
RH = 640
CX = X0
CY = (0, 158, 316)  # верх, середина, низ
FLOOR, TOP = 597, 277  # лінія ходьби внизу (як в ущелині) і на плато (як на стежці)

# уступи: (x початку, верх) — кожен до початку наступного; останній — плато до східного краю. Кроки в світі: 63, 81,
# 63, 81, 80, 65, 48 px — не вище 81 (стрибок героя ~103 px, D296: на кожен уступ — один стрибок)
STEPS = [
    (0, FLOOR),
    (130, 555),
    (184, 501),
    (234, 459),
    (284, 405),
    (334, 352),
    (384, 309),
    (430, TOP),
]
JUMP_ART = 103 / 1.5

# дальня стіна (×0.75): четвертий шматок стіни ущелини, стовпці 1296–1872; гребінь на сході опускається — ущелина
# розкривається до долини, де село
MID_F = 0.75
MID_C0 = 1296
GORGE_MID_W = 1440  # стіна ущелини закінчується тут
RIM_EAST = [(1600, 300), (1750, 330), (1872, 350)]

# річка: в ущелині — рядки кімнати 261–276 (тут 581–596); біля підніжжя скелі — невеликий каскад з тріщини під уступом 1
STREAM = (581, 597)
CASCADE = (118, 130, 548)  # x0, x1, верх струменя
LEDGES_SEED = 841
LEDGES_TEXT = (
    "a rugged sandstone cliff seen exactly from the side, rising from the lower left to the upper right in a series of "
    "natural rock ledges irregular and weathered, each ledge a flat level shelf of solid rock with a thin light "
    "edge and a slightly overhanging lip, cracked vertical rock faces between the ledges, layered red-orange and dark "
    "violet rock strata inside the cliff down to the bottom edge, a few dry thorn bushes in the cracks, at the bottom "
    "left a thin small waterfall pouring from a crack under the lowest ledge into a pool, a flat plateau at the top "
    f"right, {cb.CHROMA} above the cliff, {cb.STYLE}"
)

# спалене село за проходом (×0.85): ті самі будинки, що Village/gen_houses, img2img «після пожежі» — стіни цілі
HOUSES_F = 0.85
HOUSES_SEED = 851
HOUSES_ROWS = (
    64,
    272,
)  # рядки gen_houses (дахи, пальми, поріг ~231); 208 × 3 = 624, кратне 16
HOUSES_TEXT = (
    "the same row of small desert village houses after a great fire, still standing: flat-roofed adobe and clay "
    "brick houses with their walls whole and unbroken, thick black soot streaks rising above every doorway and window, "
    "the cloth awnings burnt away leaving only charred bare wooden frames, charred black doors and shutters, wooden roof "
    "beams burnt to black stumps, scorched date palms with bare black trunks and a few burnt fronds, grey smoke rising "
    "from the roofs, a few glowing orange embers in the doorways, "
    f"{cb.MAGENTA}, {cb.STYLE}"
)
# стовпці спаленого ряду (зменшення в 2 рази): будинок з балками й вогнем у вікні, пальма, ще один
HOUSES_CROP = (440, 864)
HOUSES_KEEP = 250  # рядок (поріг ~231 − 64) × 3 / 2: нижче — бруківка, її ховає плато
HOUSES_BLOCK = (
    2  # у 1.5 раза більші, ніж ряд у селі: перший будинок за проходом ближчий
)
# лівий нижній кут будинків у кадрі при камері верху: низ за плато (277), лівий край — над плато (від x 430)
HOUSES_AT = (436, 300)

PLUME_F = 0.6
PLUME_FOOT = (
    560,
    280,
)  # зріз стебла в кадрі при камері верху: за будинками, біля проходу
FRONT_F = 1.3


def raw(name):
    return os.path.join(D, f"ledges_{name}_raw.png")


def top(x):
    """Верх скелі в стовпці x (арт кімнати)."""
    xs = [s[0] for s in STEPS]
    return np.array(
        [STEPS[i][1] for i in np.searchsorted(xs, np.asarray(x), "right") - 1]
    )


def gorge_strip():
    """Берег ущелини дзеркально від її східного краю: стовпець 0 уступів = стовпець 1727 берега, без шва."""
    g = np.asarray(Image.open(gp.SG + "gen_ground.png"))
    return np.fliplr(g[: RH - (gp.Y0 + gp.G_TOP)][:, -STEPS[1][0] :])


def ledges_guide():
    pal = pp.palette(pp.MP + "gen_ground.png")
    light, _stone, _rock, dark = pal[-1], pal[len(pal) // 2], pal[3], pal[0]
    rng = np.random.default_rng(LEDGES_SEED)
    g = np.zeros((RH, W, 3), np.uint8)
    g[:] = (0, 255, 0)
    ys = np.arange(RH)[:, None]
    depth = ys - top(np.arange(W))[None, :]
    # тіло скелі — фіолетова скеля з тріщинами з-під схилу осипища (та сама дорога), не рівні смуги: на рівних смугах
    # модель малювала цегляну піраміду
    sc = np.asarray(Image.open(pp.SC + "gen_scree.png"))[420:640, 0:300, :3]
    tile = np.tile(sc, (RH // len(sc) + 1, W // sc.shape[1] + 1, 1))[:RH, :W]
    g[depth >= 0] = tile[depth >= 0]
    g[(depth >= 0) & (depth < 9)] = pal[-3]  # освітлений верх уступу — пісковик
    g[(depth >= 9) & (depth < 14)] = pal[2]  # тінь під кромкою
    img = Image.fromarray(g)
    d = ImageDraw.Draw(img)
    for (x0, y0), (x1, _) in zip(STEPS[1:], STEPS[2:] + [(W, 0)]):
        d.line(
            [(x0 - 1, y0), (x1, y0)], fill=tuple(int(c) for c in light), width=2
        )  # кромка
        d.line(
            [(x0, y0 + 2), (x0 + rng.uniform(-6, 6), y0 + 50)],
            fill=tuple(int(c) for c in dark),
            width=3,
        )  # стінка
    for _ in range(120):
        x = rng.uniform(150, W)
        y = top([int(x)])[0] + rng.uniform(6, 120)
        r = rng.uniform(2, 6)
        d.ellipse(
            (x - r, y - r * 0.6, x + r, y + r * 0.6), fill=tuple(int(c) for c in dark)
        )
    s = gorge_strip()
    a = s[..., 3] > 0
    reg = np.asarray(img).copy()
    sub = reg[RH - len(s) :, : s.shape[1]]
    sub[a] = s[..., :3][a]
    x0, x1, y0 = CASCADE
    reg[y0:FLOOR, x0:x1] = gp.WATER[2]
    reg[y0:FLOOR, x0 + 3 : x1 - 3 : 3] = gp.WATER[3]
    return reg


def burnt_guide():
    v = np.asarray(Image.open(pp.B + "Village/gen_houses.png").convert("RGBA")).astype(
        np.float32
    )
    a = v[..., 3:] / 255
    rgb = v[..., :3] * a + np.array([255, 0, 255], np.float32) * (1 - a)
    rgb = rgb[HOUSES_ROWS[0] : HOUSES_ROWS[1]].astype(np.uint8)
    big = (
        Image.fromarray(rgb)
        .resize((W * K, len(rgb) * K), Image.NEAREST)
        .filter(ImageFilter.GaussianBlur(2))
    )
    return np.asarray(big)


def free():
    cb.urllib.request.urlopen(
        cb.urllib.request.Request(
            cb.API + "/free",
            cb.json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )


def gen():
    # стіна: четвертий шматок за методом ущелини (перші 110 стовпців — кінець шматка 2)
    if not os.path.exists(raw("wall_3")):
        gp.MID_W, gp.RIM = MID_C0 + W, gp.RIM + RIM_EAST
        guide = gp.wall_guide()[:, MID_C0 * K :].copy()
        prev = np.asarray(Image.open(gp.raw("wall_2")).convert("RGB"))
        o = MID_C0 - gp.CHUNKS[2]
        guide[:, : gp.RAMP * K] = prev[:, o * K : (o + gp.RAMP) * K]
        hgt = -(-len(guide) // 16) * 16
        guide = np.concatenate([guide, np.repeat(guide[-1:], hgt - len(guide), 0)])
        x = np.arange(W * K)
        keep = np.clip((gp.RAMP * K - x) / ((gp.RAMP - gp.KEEP) * K), 0, 1)
        alpha = np.repeat((keep * 255).astype(np.uint8)[None, :, None], hgt, axis=0)
        name = cb.upload(np.concatenate([guide, alpha], 2), "ledges_wall_3.png")
        out = cb.run(cb.graph(gp.WALL_TEXT, 804, hgt, name, 0.9))[: (gp.R1 - gp.R0) * K]
        Image.fromarray(out.astype(np.uint8)).save(raw("wall_3"))
        print("wall 3", flush=True)
    if not os.path.exists(raw(f"cliff_{LEDGES_SEED}")):
        big = (
            Image.fromarray(ledges_guide())
            .resize((W * K, RH * K), Image.NEAREST)
            .filter(ImageFilter.GaussianBlur(4))
        )
        rgba = np.concatenate(
            [np.asarray(big), np.zeros((RH * K, W * K, 1), np.uint8)], 2
        )
        name = cb.upload(rgba, "ledges_guide.png")
        out = cb.run(
            cb.graph(LEDGES_TEXT, LEDGES_SEED, RH * K, name, 0.65)
        )  # 0.8 — уступи моделі не там, де STEPS; 0.65 — цегляна піраміда
        Image.fromarray(out.astype(np.uint8)).save(raw(f"cliff_{LEDGES_SEED}"))
        print("cliff", flush=True)
    if not os.path.exists(raw(f"burnt_{HOUSES_SEED}")):
        g = burnt_guide()
        rgba = np.concatenate([g, np.zeros((*g.shape[:2], 1), np.uint8)], 2)
        name = cb.upload(rgba, "ledges_burnt_guide.png")
        out = cb.run(cb.graph(HOUSES_TEXT, HOUSES_SEED, len(g), name, 0.6))
        Image.fromarray(out.astype(np.uint8)).save(raw(f"burnt_{HOUSES_SEED}"))
        print("burnt", flush=True)
    free()


def build():
    os.makedirs(RL, exist_ok=True)
    # стіна — як в ущелині: серпанок шару, палітра gen_mid стежки, +0.35 сходинками від рядка 253
    wall = np.asarray(Image.open(gp.raw("wall_2")).convert("RGB"))
    part = np.asarray(Image.open(raw("wall_3")).convert("RGB"))
    o = MID_C0 - gp.CHUNKS[2]
    wall = np.concatenate(
        [wall[:, : (o + gp.KEEP) * K], part[:, gp.KEEP * K :]], 1
    ).astype(np.float32)[:, o * K :]
    layer = cb.LAYERS["MountainPath/gen_mid"]
    rgb, opaque = cb.shrink(wall, "green", layer["spill"])
    rgb, opaque = cb.fill_down(rgb, opaque)
    rgb = rgb * (1 - layer["haze"]) + cb.HAZE * layer["haze"]
    out = np.zeros((gp.R1 - gp.R0, W, 4), np.uint8)
    out[..., :3] = pp.to_palette(rgb, pp.palette(pp.MP + "gen_mid.png"))
    out[..., 3] = opaque * 255
    step = (
        np.clip(
            (np.arange(gp.R0, gp.R1) - pp.KEEP_MID) // (pp.WALL_RAMP // 8) + 1, 0, 8
        )
        / 8
    )
    h = (pp.WALL_HAZE * step)[:, None, None]
    out[..., :3] = np.round(out[..., :3] * (1 - h) + cb.HAZE * h).astype(np.uint8)
    gm = np.asarray(Image.open(gp.SG + "gen_mid.png"))
    out[:, : GORGE_MID_W - MID_C0] = gm[:, MID_C0:]  # стик з ущелиною — її ж пікселі
    Image.fromarray(out).save(RL + "gen_mid.png")
    print("mid", out.shape, flush=True)

    # скеля з уступами: колір — генерація в палітрі gen_ground, форма — точно STEPS (по ній карта ставить колізію)
    pal = pp.palette(pp.MP + "gen_ground.png")
    rgb, _ = cb.shrink(
        np.asarray(Image.open(raw(f"cliff_{LEDGES_SEED}")).convert("RGB"), np.float32),
        None,
    )
    out = np.zeros((RH, W, 4), np.uint8)
    out[..., :3] = pp.to_palette(rgb, pal)
    ys = np.arange(RH)[:, None]
    t = top(np.arange(W))
    out[..., 3] = (ys >= t[None, :]) * 255
    cols = np.arange(W)
    out[t, cols, :3] = pal[-1]  # кромка
    out[t + 1, cols, :3] = pal[1]  # тінь під нею
    px = out[..., :3].astype(int)
    green = (
        (out[..., 3] > 0)
        & (px[..., 1] > px[..., 0] + 15)
        & (px[..., 1] >= px[..., 2] - 10)
    )
    out[green, :3] = pal[len(pal) // 2]
    # глибше 14 рядків під верхом — лише фіолетові кольори скелі: модель малювала в стіні помаранчеві полиці й кущі,
    # які читаються як уступи, а колізії там немає
    deep = (ys - t[None, :] >= 14) & (out[..., 3] > 0)
    violet = pal[[0, 1, 3, 7]]
    out[deep, :3] = pp.to_palette(rgb[deep][None], violet)[0]
    # каскад: світлі й блакитні пікселі моделі біля стінки уступу 1 (не кромки) — у 4 кольори води ущелини + піна
    x0, x1, y0 = CASCADE
    wpal = np.concatenate([gp.WATER, [[236, 246, 250]]])
    box = (slice(y0 - 12, RH), slice(x0 - 30, x1 + 30))
    r = rgb[box]
    rows = np.arange(y0 - 12, RH)[:, None]
    tb = t[None, x0 - 30 : x1 + 30]
    water = ((r[..., 2] > r[..., 0] + 15) | (r.sum(-1) > 520)) & (out[box][..., 3] > 0)
    water &= (rows != tb) & (rows != tb + 1)
    out[box][water, :3] = pp.to_palette(r[water][None], wpal)[0]
    # берег із річкою — пікселі ущелини дзеркально (без шва на межі)
    s = gorge_strip()
    sub = out[RH - len(s) :, : s.shape[1]]
    a = s[..., 3] > 0
    sub[a] = s[a]
    # каскад малює скрипт: модель на 0.65 його загубила. Струмінь з-під кромки уступу 1 у кінець річки, перед стінкою
    # (стовпці 118–129, у повітрі над берегом — колізії не стосується), смуги трьох кольорів води, піна внизу
    x0, x1, _ = CASCADE
    rng = np.random.default_rng(LEDGES_SEED)
    for x in range(x0, x1):
        out[STEPS[1][1] + 4 : FLOOR, x, :3] = (
            gp.WATER[1 + (x - x0) % 3] if rng.random() > 0.2 else gp.WATER[3]
        )
        out[STEPS[1][1] + 4 : FLOOR, x, 3] = 255
    out[STEPS[1][1] + 4, x0:x1, :3] = gp.WATER[0]  # тінь кромки на струмені
    out[FLOOR - 4 : FLOOR, x0 - 3 : x1 + 1, :3] = [236, 246, 250]
    out[FLOOR - 4 : FLOOR, x0 - 3 : x1 + 1, 3] = 255
    Image.fromarray(out).save(RL + "gen_ledges.png")
    print("ledges", out.shape, "green fixed", int(green.sum()), flush=True)

    # спалені будинки: ключ magenta, 16 кольорів, легкий серпанок (за проходом, ×0.85)
    rgb, opaque = cb.shrink(
        np.asarray(Image.open(raw(f"burnt_{HOUSES_SEED}")).convert("RGB"), np.float32),
        "magenta",
        12,
        HOUSES_BLOCK,
    )
    rgb = rgb * 0.9 + cb.HAZE * 0.1
    q = cb.quantize(rgb, opaque, 16, "octree")
    q = q[:HOUSES_KEEP, HOUSES_CROP[0] : HOUSES_CROP[1]]
    ys_, xs_ = np.nonzero(q[..., 3])
    q = q[ys_.min() :]
    Image.fromarray(q).save(RL + "gen_burnt_houses.png")
    print("burnt houses", q.shape, flush=True)
    check()


def planes():
    """(картинка, множник, якір у світі арту при камері 0, плитка) — від заднього до переднього."""
    plume = pp.img(RL + "gen_plume.png")
    houses = pp.img(RL + "gen_burnt_houses.png")
    front = pp.img(gp.SG + "gen_front.png")
    front[..., :3] *= pp.FRONT_DARK
    stem = np.nonzero(plume[-1, :, 3])[0].mean()
    return [
        (pp.img(pp.B + "DesertOasis/bg4/plan5.png"), 0.0, (0, 0), W),
        (pp.img(pp.MP + "gen_barrier.png"), 0.1, pp.BARRIER_AT, None),
        (pp.img(pp.MP + "gen_far.png"), 0.3, (0, 0), W),
        (
            plume,
            PLUME_F,
            (PLUME_FOOT[0] - stem + PLUME_F * CX, PLUME_FOOT[1] - len(plume)),
            None,
        ),
        (
            pp.img(RL + "gen_mid.png"),
            MID_F,
            (MID_F * X0, gp.R0),
            None,
        ),
        (
            houses,
            HOUSES_F,
            (HOUSES_AT[0] + HOUSES_F * CX, HOUSES_AT[1] - len(houses)),
            None,
        ),
        (pp.img(RL + "gen_ledges.png"), 1.0, (X0, 0), None),
        (
            front,
            FRONT_F,
            (-40 + FRONT_F * CX, H + 40 - len(front) + FRONT_F * CY[2]),
            None,
        ),
    ]


def check():
    # кроки — один стрибок
    for (_, a), (_, b) in zip(STEPS, STEPS[1:]):
        assert 0 < a - b <= 54, f"уступ {a}→{b} вищий за 81 px світу"
    ps = planes()
    _, f, (ax, ay), _ = ps[4]
    assert round(ax - f * CX) == 0, "дальня стіна не з'єднана з ущелиною"
    # стебло диму й низ будинків — за скелею (×1.0) при кожній камері y
    pl, pf, (px_, py_), _ = ps[3]
    hs, hf, (hx, hy), _ = ps[5]
    led = np.asarray(Image.open(RL + "gen_ledges.png"))[..., 3]
    sx = np.nonzero(pl[-1, :, 3])[0]
    hb = np.nonzero(hs[-1, :, 3])[0]
    for cy in range(0, CY[2] + 1, 2):
        for xs, x0, y in (
            (sx, px_ - pf * CX, py_ - pf * cy + len(pl) - 1),
            (hb, hx - hf * CX, hy - hf * cy + len(hs) - 1),
        ):
            x = np.round(x0 + xs).astype(int)
            x = x[(x >= 0) & (x < W)]
            ry = round(y) + cy  # рядок кімнати під цим пікселем кадру
            if 0 <= round(y) < H:
                assert (led[ry, x] > 0).all(), f"низ видно при камері y {cy}"
    print(
        "steps ok, mid joined, stem and house bases hidden at every camera y",
        flush=True,
    )


def view(ps, cy, hero):
    c = np.zeros((H, W, 4), np.float32)
    c[..., 3] = 255
    for im, f, (ax, ay), tile in ps:
        x0, y0 = round(ax - f * CX), round(ay - f * cy)
        for x in [x0] if tile is None else range(x0 % tile - tile, W, tile):
            pp.paste(c, im, x, y0)
        if f == 1.0 and hero:
            pp.paste(c, hero[2], hero[0] - X0, hero[1] - cy - len(hero[2]))
    return c


def sheet():
    hero = pp.img("SampleProject/Sprites/Player/Walk/1.png")
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    gps = gp.planes()
    ps = planes()
    small = [
        (
            "Seam 1/2. Stream gorge, right end: the hero walks east, the smoke's stem bends down beyond the edge",
            gp.view(gps, gp.CX[2], gp.CY, (gp.CX[2] + 470, gp.Y0 + gp.WALK, hero)),
        ),
        (
            "Seam 2/2. Rock ledges, bottom: the bank and the stream go on, a cascade at the cliff foot, ledges up east",
            view(ps, CY[2], (X0 + 40, FLOOR, hero)),
        ),
    ]
    big = [
        (
            "Rock ledges, bottom frame (1920x1080): the hero on ledge 2; steps of 63-81 world px, each one jump",
            view(ps, CY[2], (X0 + 196, 501, hero)),
        ),
        (
            "Rock ledges, top frame (1920x1080): the plateau and the passage east into the burnt village; its smoke rises right behind",
            view(ps, CY[0], (X0 + 410, 309, hero)),
        ),
    ]
    tw, th, lab, gap = 960, 540, 28, 12
    out = Image.new(
        "RGB", (1920 + gap, th + lab + 2 * (1080 + lab) + 2 * gap), (24, 22, 28)
    )
    d = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    for i, (title, v) in enumerate(small):
        x = i * (tw + gap)
        f = Image.fromarray(v.astype(np.uint8)[..., :3]).resize((tw, th), Image.NEAREST)
        out.paste(f, (x, lab))
        d.text((x + 6, 8), title, fill=(235, 225, 200), font=font)
    y = th + lab + gap
    for title, v in big:
        out.paste(
            Image.fromarray(v.astype(np.uint8)[..., :3]).resize(
                (1920, 1080), Image.NEAREST
            ),
            (0, y + lab),
        )
        d.text((6, y + 8), title, fill=(235, 225, 200), font=font)
        y += 1080 + lab + gap
    out.save("design/shots/m6a2b_ledges.png")
    print("sheet", out.size, flush=True)


if __name__ == "__main__":
    {
        "gen": gen,
        "build": build,
        "sheet": sheet,
        "guide": lambda: Image.fromarray(ledges_guide()).save(raw("guide")),
    }[sys.argv[1]]()
