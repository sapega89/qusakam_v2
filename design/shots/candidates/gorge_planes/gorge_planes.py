"""M6a-2a: ущелина зі струмком (3 екрани, 1728×320 арту = 2592×480 світу) — дорога від осипища до скельних уступів,
без боїв (world_structure_plan v3). Шлейф і заслін робить comfy_backdrop.py (StreamGorge/gen_*); тут —
дальня стіна ущелини (продовження стіни осипища), берег зі струмком і аркуш для Сапеги.
  python -B design/shots/candidates/gorge_planes/gorge_planes.py gen    — ComfyUI: стіна трьома шматками праворуч від
                                                                         стіни осипища, берег за напрямною (сирі поруч)
  python -B design/shots/candidates/gorge_planes/gorge_planes.py build  — плани ущелини + перевірка, що стебло диму
                                                                         завжди за гребенем
  python -B design/shots/candidates/gorge_planes/gorge_planes.py sheet  — design/shots/m6a2_gorge.png

Одиниці — пікселі арту (світ = ×1.5), початок — лівий верхній кут стежки. Ущелина: лівий край x 1728 (стежка 1152 +
осипище 576 = 2592 світу), верх y 320 (480 світу: нижня клітинка осипища); лінія ходьби — рядок 277 кімнати (y 416
світу), як дно осипища. Плани прив'язані до світу, як на стежці: зсув плану з множником f — −f·камера.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, "Scripts/Tools")
sys.path.insert(0, "design/shots/candidates/path_planes")
import comfy_backdrop as cb
import path_planes as pp

D = os.path.dirname(os.path.abspath(__file__))
SG = pp.B + "StreamGorge/"
K, W, H = 3, 576, 324
X0, Y0 = pp.PATH_W + W, 320  # лівий верхній кут ущелини у світі стежки
ROOM_W = 3 * W  # 1728
WALK = 277  # лінія ходьби в кімнаті
CY = 316  # камера по y: як унизу осипища (640 − 324); кімната на 6 px світу нижча за кадр
CX = (X0, X0 + W, X0 + 2 * W)  # камера: лівий край, середина, правий край

# дальня стіна (×0.75): продовження ScreeSlide/gen_mid праворуч, у його ж рядках — стовпці 0–144 стіни ущелини — це
# стовпці 432–576 стіни осипища (ті самі місця світу)
MID_F = 0.75
MID_AX = MID_F * X0  # 1296: при камері лівого краю стовпець 0 — на лівому краї кадру
MID_W = W + round(MID_F * 2 * W)  # 1440: кадр + шлях камери ×0.75
R0, R1 = 232, 572  # рядки стіни осипища, які видно з дна (камера 316–320)
SEAM_COL = 432  # стовпець стіни осипища, з якого починається стіна ущелини
KEEP, RAMP = (
    110,
    144,
)  # у кожному шматку: перші 110 стовпців лишаються, до 144 маска м'яко спадає
# шматок 0 — перші 144 стовпці лишаються (рівно смуга, яку build бере зі стіни осипища: без прямого шва на стовпці 144,
# A5), до 178 маска спадає
KEEP0, RAMP0 = 144, 178
PATCH0 = (190, 420, 160)  # стовпці латки шматка 0 і початок її напрямної в шматку 1 (A5)
CHUNKS = (0, 432, 864)  # три шматки по 576 (вікно моделі), кожен продовжує попередній
# гребінь (рядки стіни осипища; рядок кадру = рядок − 237): від осипища ~283, далі 290–318 (небо — смуга 50–80 px,
# далина майже вся за стіною), на сході — сідловина до ~380 (рядок кадру ~143): крізь неї видно небо, клуб і стебло диму
# A5: шпиль стіни осипища (її стовпці 534–576, вище кадру) — тут стовпці 102–144; він продовжується до ~170 і спадає,
# а не обривається квадратним пеньком на стику
RIM = [
    (0, 283),
    (100, 283),
    (102, 232),
    (172, 232),
    (196, 268),
    (260, 300),
    (420, 290),
    (560, 312),
    (700, 298),
    (860, 316),
    (960, 340),
    (1040, 376),
    (1180, 384),
    (1260, 352),
    (1330, 300),
    (1440, 288),
]
WALL_SEED = 821  # 801 — щілини до дна між окремими столовими горами (A5)
WALL_TEXT = (
    "the far wall of a deep mountain gorge: tall rugged red-orange and ochre sandstone cliffs with horizontal rock "
    "strata, ledges and cracks, filling the whole width and continuing from the rim at the top all the way down to the "
    "bottom edge, one continuous unbroken wall with no gaps and no separate mesas, a few dry brown thorn bushes on the ledges, warm light on the ledges, "
    f"cool violet shadows in the cracks, {cb.CHROMA} above the rim, {cb.STYLE}"
)

# берег і струмок (×1.0): смуга від рядка 250 кімнати; рядок 27 смуги — лінія ходьби
G_TOP, G_ROWS = 250, 80
G_WALK = WALK - G_TOP  # 27
RUBBLE = 76  # західний край: осип зі схилу загачує струмок, вода — від стовпця ~76
GROUND_SEED = 831
GROUND_TEXT = (
    "a side view of a shallow mountain stream running along the floor of a gorge: in front a flat level bank of packed "
    "reddish dirt and flat stones spanning the full width with a thin light edge, right behind it a narrow band of "
    "clear calm blue-green water with thin light ripples and reflections and a few rounded wet stones sticking out of "
    "it, on the far side of the water a low edge of pebbles, at the far left a pile of loose rubble, below the bank "
    f"layered red-orange and dark violet rock strata down to the bottom edge, {cb.CHROMA} above, {cb.STYLE}"
)
WATER = np.array(
    [[46, 84, 112], [70, 122, 146], [112, 168, 184], [196, 226, 232]], np.float32
)

# шлейф (D796): власний план ущелини, більший за спільний шлейф стежки й осипища (654 проти 589). Сапега: «дим має бути
# видно, що за наступним екраном спалене село» — стебло ніколи не в кадрі: праворуч клуб у правому верхньому куті, а
# стебло нахиляється за східний край; ×0.35 (далеко, за наступним екраном) — ліворуч над гребенем тіло, посередині
# тіло через усе небо, праворуч клуб біля краю
PLUME_F = 0.35
FRONT_F = 1.3


def raw(name):
    return os.path.join(D, f"gorge_{name}_raw.png")


def rim(x):
    xs, ys = zip(*RIM)
    return np.interp(x, xs, ys)


def wall_guide():
    """Напрямна стіни в px генерації: сира стіна осипища (603) у дзеркальних повторах праворуч від стовпця 432, над
    обрисом RIM — зелене тло; зелені плями під обрисом (небо осипища) — кольором стіни нижче."""
    src = np.asarray(Image.open(pp.raw("scree_mid_603")).convert("RGB"))[
        R0 * K : R1 * K
    ]
    tile = np.concatenate(
        [src[:, SEAM_COL * K :], np.fliplr(src), src, np.fliplr(src)], 1
    )
    g = tile[:, : MID_W * K].copy()
    bg = np.median(src[:24].reshape(-1, 3), axis=0)
    f = g.astype(np.int32)
    # тло і зеленкуватий серпанок у щілині осипища (модель просвітила тло крізь неї) — не стіна
    sky = (np.linalg.norm(f - bg, axis=2) < cb.KEY_DISTANCE) | (f[..., 1] > np.maximum(f[..., 0], f[..., 2]) + 10)
    # зелене під обрисом — найближчим кольором стіни знизу
    last = np.minimum.accumulate(
        np.where(~sky, np.arange(len(g))[:, None], len(g) - 1)[::-1], axis=0
    )[::-1]
    g = g[last, np.arange(g.shape[1])[None, :]]
    # праворуч від стику — не дзеркальна копія (її щілини модель зробила проваллями між окремими столовими горами), а
    # пласти: середній колір рядка стіни осипища плюс шум, деталі домальовує модель
    rng = np.random.default_rng(801)
    bands = np.median(g[:, : RAMP * K].astype(np.float32), axis=1)
    rest = bands[:, None, :] + rng.normal(0, 12, (len(g), g.shape[1] - RAMP * K, 1))
    g[:, RAMP * K :] = np.clip(rest, 0, 255).astype(np.uint8)
    ys = np.arange(len(g))[:, None]
    above = ys < (rim(np.arange(g.shape[1]) / K) - R0)[None, :] * K
    g[above] = (0, 255, 0)
    return np.asarray(Image.fromarray(g).filter(ImageFilter.GaussianBlur(3)))


def bank_guide():
    """Напрямна берега (пікселі арту): зелене тло, далекий край камінцями, вода зі світлими брижами й каменями, світла
    кромка на лінії ходьби, під нею ґрунт і пласти скелі — у палітрі gen_ground, як дно осипища."""
    pal = pp.palette(pp.MP + "gen_ground.png")
    light, dirt, stone, rock, dark = (
        pal[-1],
        pal[-3],
        pal[len(pal) // 2],
        pal[3],
        pal[0],
    )
    rng = np.random.default_rng(GROUND_SEED)
    g = np.zeros((G_ROWS, ROOM_W, 3), np.uint8)
    g[:] = (0, 255, 0)
    x = np.arange(ROOM_W)
    far = 8 + np.round(1.5 * np.sin(x / 37) + rng.normal(0, 0.6, ROOM_W)).astype(
        int
    )  # верх далекого краю
    rubble = np.clip(RUBBLE - x, 0, None) * 0.3  # осип на заході: вищий біля схилу
    top = np.maximum(far - rubble.astype(int), 0)
    ys = np.arange(G_ROWS)[:, None]
    g[ys >= top[None, :]] = stone  # далекий край
    water = (ys >= top[None, :] + 3) & (ys < G_WALK) & (x[None, :] >= RUBBLE)
    g[water] = WATER[1]
    g[water & (ys < top[None, :] + 6)] = WATER[0]  # тінь далекого берега на воді
    g[G_WALK:] = dirt
    g[G_WALK + 3 :] = stone
    g[G_WALK + 18 :] = rock
    g[G_WALK + 18 :][(np.arange(G_WALK + 18, G_ROWS) // 9) % 3 == 0] = dark  # пласти
    img = Image.fromarray(g)
    d = ImageDraw.Draw(img)
    for _ in range(900):  # брижі
        cx, cy = rng.uniform(RUBBLE, ROOM_W), rng.uniform(13, G_WALK - 2)
        d.line(
            (cx, cy, cx + rng.uniform(4, 14), cy),
            fill=tuple(int(c) for c in WATER[2 + (rng.random() < 0.3)]),
        )
    for _ in range(int(ROOM_W * 0.35)):  # камінці далекого краю й осипу
        cx = rng.uniform(0, ROOM_W)
        cy = top[int(cx)] + rng.uniform(0, 3 + (cx < RUBBLE) * 12)
        r = rng.uniform(1.5, 3.5)
        d.ellipse(
            (cx - r, cy - r * 0.7, cx + r, cy + r * 0.7),
            fill=tuple(int(c) for c in (light if rng.random() < 0.4 else rock)),
        )
    for cx in rng.uniform(RUBBLE + 40, ROOM_W - 20, 14):  # камені у воді
        cy, r = rng.uniform(15, G_WALK - 4), rng.uniform(3, 6)
        d.ellipse(
            (cx - r, cy - r * 0.6, cx + r, cy + r * 0.6),
            fill=tuple(int(c) for c in rock),
        )
        d.line(
            (cx - r * 0.6, cy - r * 0.5, cx + r * 0.4, cy - r * 0.5),
            fill=tuple(int(c) for c in light),
        )
    for _ in range(int(ROOM_W * 0.25)):  # каміння в ґрунті
        cx, cy, r = (
            rng.uniform(0, ROOM_W),
            rng.uniform(G_WALK + 2, G_WALK + 26),
            rng.uniform(1.5, 4.5),
        )
        d.ellipse(
            (cx - r, cy - r * 0.7, cx + r, cy + r * 0.7),
            fill=tuple(int(c) for c in (light if rng.random() < 0.4 else dark)),
        )
    d.line([(0, G_WALK), (ROOM_W, G_WALK)], fill=tuple(int(c) for c in light), width=1)
    return img, top


def gen():
    # стіна: шматок за шматком, кожен бачить кінець попереднього (маска «лишити» — перші KEEP стовпців)
    for i, c0 in enumerate(CHUNKS):
        if os.path.exists(raw(f"wall_{i}")):
            continue
        guide = wall_guide()[:, c0 * K : (c0 + W) * K].copy()
        if i:
            prev = np.asarray(Image.open(raw(f"wall_{i - 1}")).convert("RGB"))
            guide[:, : RAMP * K] = prev[
                :, (c0 - CHUNKS[i - 1]) * K : (c0 - CHUNKS[i - 1] + RAMP) * K
            ]
        hgt = -(-len(guide) // 16) * 16
        guide = np.concatenate([guide, np.repeat(guide[-1:], hgt - len(guide), 0)])
        x = np.arange(W * K)
        k0, r0 = (KEEP, RAMP) if i else (KEEP0, RAMP0)
        keep = np.clip((r0 * K - x) / ((r0 - k0) * K), 0, 1)  # 1 — лишити, 0 — перемалювати
        alpha = np.repeat((keep * 255).astype(np.uint8)[None, :, None], hgt, axis=0)
        name = cb.upload(np.concatenate([guide, alpha], 2), f"gorge_wall_{i}.png")
        out = cb.run(cb.graph(WALL_TEXT, WALL_SEED + i, hgt, name, 0.9))[: (R1 - R0) * K]
        Image.fromarray(out.astype(np.uint8)).save(raw(f"wall_{i}"))
        print("wall", i, flush=True)
    # A5: у шматку 0 (сід 821) стовпці 190–420 вийшли пласким піском — перемальовуються поверх скелі шматка 1 (його
    # стовпці 160–390 — напрямна), краї смуги м'яко зливаються з сусідами
    if not os.path.exists(raw("wall_0_fixed")):
        w0 = np.asarray(Image.open(raw("wall_0")).convert("RGB")).copy()
        p0, p1, src = PATCH0
        guide = w0.copy()
        w1 = np.asarray(Image.open(raw("wall_1")).convert("RGB"))
        guide[:, p0 * K : p1 * K] = w1[:, src * K : (src + p1 - p0) * K]
        guide = np.asarray(Image.fromarray(guide).filter(ImageFilter.GaussianBlur(3)))
        hgt = -(-len(guide) // 16) * 16
        pad = lambda a: np.concatenate([a, np.repeat(a[-1:], hgt - len(a), 0)])
        x = np.arange(W * K)
        ramp = np.clip(np.maximum(p0 * K - x, x - p1 * K) / (12 * K), 0, 1)  # 0 — смуга, 1 — лишити
        alpha = np.repeat((ramp * 255).astype(np.uint8)[None, :, None], hgt, axis=0)
        guide = np.where(ramp[None, :, None] > 0, w0, guide)
        name = cb.upload(np.concatenate([pad(guide), alpha], 2), "gorge_wall_0_fix.png")
        out = cb.run(cb.graph(WALL_TEXT, WALL_SEED + 10, hgt, name, 0.75))[: len(w0)]
        wt = (1 - ramp)[None, :, None]
        Image.fromarray((out * wt + w0 * (1 - wt)).astype(np.uint8)).save(raw("wall_0"))
        Image.fromarray(np.zeros((1, 1), np.uint8)).save(raw("wall_0_fixed"))  # позначка: латка вже є
        print("wall 0 fixed", flush=True)
    # берег: уся кімната одним полотном (5184×240 px генерації), img2img за напрямною
    if not os.path.exists(raw(f"bank_{GROUND_SEED}")):
        img, _ = bank_guide()
        big = img.resize((ROOM_W * K, G_ROWS * K), Image.NEAREST).filter(
            ImageFilter.GaussianBlur(4)
        )
        rgba = np.concatenate(
            [np.asarray(big), np.zeros((G_ROWS * K, ROOM_W * K, 1), np.uint8)], 2
        )
        name = cb.upload(rgba, "gorge_bank_guide.png")
        out = cb.run(
            cb.graph(GROUND_TEXT, GROUND_SEED, G_ROWS * K, name, 0.75, width=ROOM_W * K)
        )
        Image.fromarray(out.astype(np.uint8)).save(raw(f"bank_{GROUND_SEED}"))
        print("bank", flush=True)
    cb.urllib.request.urlopen(
        cb.urllib.request.Request(
            cb.API + "/free",
            cb.json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )


def wall_raw():
    """Три шматки в одне полотно: кожен наступний — від кінця «лишити» попереднього."""
    out = np.asarray(Image.open(raw("wall_0")).convert("RGB"))
    for i in (1, 2):
        part = np.asarray(Image.open(raw(f"wall_{i}")).convert("RGB"))
        out = np.concatenate([out[:, : (CHUNKS[i] + KEEP) * K], part[:, KEEP * K :]], 1)
    return out.astype(np.float32)


def build():
    os.makedirs(SG, exist_ok=True)
    # стіна: як стіна осипища — серпанок шару 0.2, палітра gen_mid стежки, ще +0.35 сходинками від рядка 253
    layer = cb.LAYERS["MountainPath/gen_mid"]
    rgb, opaque = cb.shrink(wall_raw(), "green", layer["spill"])
    rgb, opaque = cb.fill_down(rgb, opaque)
    rgb = rgb * (1 - layer["haze"]) + cb.HAZE * layer["haze"]
    out = np.zeros((R1 - R0, MID_W, 4), np.uint8)
    out[..., :3] = pp.to_palette(rgb, pp.palette(pp.MP + "gen_mid.png"))
    out[..., 3] = opaque * 255
    step = (
        np.clip((np.arange(R0, R1) - pp.KEEP_MID) // (pp.WALL_RAMP // 8) + 1, 0, 8) / 8
    )
    h = (pp.WALL_HAZE * step)[:, None, None]
    out[..., :3] = np.round(out[..., :3] * (1 - h) + cb.HAZE * h).astype(np.uint8)
    scree = np.asarray(Image.open(pp.SC + "gen_mid.png"))
    out[:, : W - SEAM_COL] = scree[R0:R1, SEAM_COL:]  # стик з осипищем — його ж пікселі
    # A5: продовження шпиля осипища (стовпці 144–176) — схилом донизу, а не прямою стінкою: над лінією
    # (144, 0) → (176, 52) прозоро
    ys, xs = np.mgrid[: len(out), : out.shape[1]]
    out[(xs > W - SEAM_COL) & (xs < 200) & (ys < (xs - (W - SEAM_COL)) * 52 / 32), 3] = 0
    Image.fromarray(out).save(SG + "gen_mid.png")
    print("mid", out.shape, flush=True)
    # берег: форма — напрямна (верх далекого краю), колір — генерація; нижче лінії ходьби — палітра gen_ground (як дно
    # осипища), вода й далекий край — власні 10 кольорів
    _, top = bank_guide()
    pal = pp.palette(pp.MP + "gen_ground.png")
    rgb, _ = cb.shrink(
        np.asarray(Image.open(raw(f"bank_{GROUND_SEED}")).convert("RGB"), np.float32),
        None,
    )
    ys = np.arange(G_ROWS)[:, None]
    opaque = ys >= top[None, :]
    out = np.zeros((G_ROWS, ROOM_W, 4), np.uint8)
    upper = opaque & (ys < G_WALK)
    out[..., :3] = cb.quantize(rgb, upper, 10, "octree")[..., :3]
    lower = np.broadcast_to(ys >= G_WALK, opaque.shape)
    out[lower, :3] = pp.to_palette(rgb[lower][None], pal)[0]
    out[..., 3] = opaque * 255
    cols = np.arange(ROOM_W)
    out[G_WALK, cols, :3] = pal[-1]  # кромка, як на дні осипища
    out[G_WALK + 1, cols, :3] = pal[1]
    # зелені відблиски тла під верхом — у найближчий незелений колір
    px = out[..., :3].astype(int)
    green = opaque & (px[..., 1] > px[..., 0] + 15) & (px[..., 1] > px[..., 2] + 10)
    clean = np.unique(px[opaque & ~green], axis=0)
    if green.any():
        out[green, :3] = clean[
            np.linalg.norm(px[green][:, None] - clean[None], axis=2).argmin(1)
        ]
    Image.fromarray(out).save(SG + "gen_ground.png")
    print("ground", out.shape, "green fixed", int(green.sum()), flush=True)
    check_stem()


def planes(stem_only=False):
    """(картинка, множник, якір у світі арту при камері 0, плитка) — від заднього до переднього."""
    plume = pp.img(SG + "gen_plume.png")
    if stem_only:
        return plume
    front = pp.img(SG + "gen_front.png")
    front[..., :3] *= pp.FRONT_DARK
    return [
        (pp.img(pp.B + "DesertOasis/bg4/plan5.png"), 0.0, (0, 0), W),
        (pp.img(pp.MP + "gen_barrier.png"), 0.1, pp.BARRIER_AT, None),
        (pp.img(pp.MP + "gen_far.png"), 0.3, (0, 0), W),
        (plume, PLUME_F, plume_at(plume), None),
        (pp.img(SG + "gen_mid.png"), MID_F, (MID_AX, R0), None),
        (pp.img(SG + "gen_ground.png"), 1.0, (X0, Y0 + G_TOP), None),
        # заслін біля води: лише посередині кімнати, низ ~40 px під кадром
        (
            front,
            FRONT_F,
            (40 + FRONT_F * CX[1], H + 40 - len(front) + FRONT_F * CY),
            None,
        ),
    ]


def plume_at(plume):
    """Якір шлейфу: при камері правого краю стебло (зріз внизу) — за східним краєм кадру (x 600), низ — у рядку кадру 155 (верх клубу трохи за верхнім краєм),
    нижче гребеня біля правого краю (~51), тож у кадрі й частина стебла під гребенем схована стіною."""
    stem = np.nonzero(plume[-1, :, 3])[0].mean()
    return (600 - stem + PLUME_F * CX[2], 155 - len(plume) + PLUME_F * CY)


def check_stem():
    """Зріз стебла (нижній рядок шлейфу) за будь-якої камери в ущелині — за непрозорою стіною або поза кадром."""
    plume, mid = planes(True), np.asarray(Image.open(SG + "gen_mid.png"))
    ax, ay = plume_at(plume)
    sx = np.nonzero(plume[-1, :, 3])[0]
    for cx in range(CX[0], CX[2] + 1, 4):
        x = np.round(ax - PLUME_F * cx + sx).astype(int)
        y = round(ay - PLUME_F * CY) + len(plume) - 1
        on = (x >= 0) & (x < W)
        mx = x[on] - round(MID_AX - MID_F * cx)
        my = y - round(R0 - MID_F * CY)
        assert (mid[my, mx, 3] > 0).all(), (
            f"стебло диму видно над гребенем при камері {cx}"
        )
    print("stem hidden at every camera x", flush=True)


def view(ps, cx, cy, hero):
    c = np.zeros((H, W, 4), np.float32)
    c[..., 3] = 255
    for im, f, (ax, ay), tile in ps:
        x0, y0 = round(ax - f * cx), round(ay - f * cy)
        for x in [x0] if tile is None else range(x0 % tile - tile, W, tile):
            pp.paste(c, im, x, y0)
        if f == 1.0 and hero:
            pp.paste(c, hero[2], hero[0] - cx, hero[1] - cy - len(hero[2]))
    return c


def sheet():
    hero = pp.img("SampleProject/Sprites/Player/Walk/1.png")  # Idle, кадр 1
    ys, _ = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]
    hw = len(hero[0])
    ps = planes()
    feet = Y0 + WALK
    shots = [
        (
            "Seam 1/2. Scree slide, bottom (camera at the scree's only x): the hero walks off east into the gorge",
            pp.view("scree", pp.PATH_W, CY, (pp.PATH_W + 500, pp.FLOOR, hero)),
        ),
        (
            "Seam 2/2. Stream gorge, left end: the next screen of the same road (ground x1.0 continues the scree floor)",
            view(ps, CX[0], CY, (X0 + 60, feet, hero)),
        ),
        (
            "Stream gorge, middle (barrier x0.1, far x0.3, plume x0.35, wall x0.75, bank x1, front x1.3)",
            view(ps, CX[1], CY, (CX[1] + 288 - hw // 2, feet, hero)),
        ),
        (
            "Stream gorge, right end: the plume's puff in the corner, its stem bends down beyond the east edge (the village); the rock ledges follow",
            view(ps, CX[2], CY, (CX[2] + 400, feet, hero)),
        ),
    ]
    tw, th, lab = 960, 540, 28
    out = Image.new("RGB", (tw * 2 + 12, (th + lab) * 2 + 12), (24, 22, 28))
    d = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    for i, (title, v) in enumerate(shots):
        x, y = (i % 2) * (tw + 12), (i // 2) * (th + lab + 12)
        frame = Image.fromarray(v.astype(np.uint8)[..., :3]).resize(
            (1920, 1080), Image.NEAREST
        )
        out.paste(frame.resize((tw, th), Image.NEAREST), (x, y + lab))
        d.text((x + 6, y + 8), title, fill=(235, 225, 200), font=font)
    out.save("design/shots/m6a2_gorge.png")
    print("sheet", out.size, flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build, "sheet": sheet}[sys.argv[1]]()
