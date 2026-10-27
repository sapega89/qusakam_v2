"""M6a-2b: скельні уступи (1×2 клітинки, 576×640 арту = 864×960 світу) — останній відрізок дороги перед селом: герой
виходить з ущелини внизу ліворуч і стрибає вгору по уступах скелі (без летючих платформ, A15; без драбин) до плато
вгорі праворуч, а з нього — крізь пролам у зовнішньому мурі — у спалене село (Сапега: «горить не вогнище, а все село
спалене … з цегли, то не розбиті, але спалені»). Тут — продовження дальньої стіни ущелини, скеля з уступами, мур села
з терасою, спалені будинки за ним (з дахів іде дим; великого шлейфу в цій кімнаті немає — A5) і аркуш.
  python -B design/shots/candidates/ledges_planes/ledges_planes.py gen    — ComfyUI (сирі PNG поруч)
  python -B design/shots/candidates/ledges_planes/ledges_planes.py build  — плани + перевірки (кроки, низ будинків)
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
# A5: уступи по 40 арту (60 світу; герой ~35 арту) замість ~50 — плато вдвічі ширше (226 арту), на ньому — пролам у
# мурі села
STEPS = [
    (0, FLOOR),
    (110, 555),
    (150, 501),
    (190, 459),
    (230, 405),
    (270, 352),
    (310, 309),
    (350, TOP),
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
CASCADE = (98, 110, 548)  # x0, x1, верх струменя
# A5: 841 — великі пласкі фіолетові брили; тепер тіло скелі — пісковик стіни ущелини (її сира генерація в напрямній),
# палітра — та сама, що в стін (MountainPath/gen_mid), без їхнього серпанку
LEDGES_SEED = 842
LEDGES_TEXT = (
    "a rugged red-orange and ochre sandstone cliff seen exactly from the side, the same rock as the tall gorge walls "
    "behind it, with horizontal rock strata, blocky cracks and cool violet shadows in the cracks, rising from the lower "
    "left to the upper right in a series of narrow natural rock ledges, each ledge a flat level shelf with a thin light "
    "sandy edge, steep cracked rock faces between the ledges, a wide flat plateau at the top right, a few dry thorn "
    f"bushes in the cracks, {cb.CHROMA} above the cliff, {cb.STYLE}"
)
CLIFF_DENOISE = 0.7
CLIFF_SHADE = 0.12  # тіло скелі (глибше 14 рядків під верхом) темніше: стіни позаду світліші, уступи читаються першими

# A5: зовнішній мур села (×0.9) на краю скелі за плато, з проламом — прохід у село; під ним скеля тераси до низу
# (ховає низ будинків). Кадр при камері верху: x від WALL_X, низ муру (верх тераси) — рядок WALL_BASE, за плато
WALL_F = 0.9
WALL_SEED = 863  # 861 — вогнище на мурі й чорні патьоки сажі (вогню в кімнаті не має бути, D796); 862 — мур 72
WALL_X = 192  # лівий край плану в кадрі (камера x одна)
WALL_W, WALL_H = 384, 432  # 1152 × 1296 px генерації, кратні 16
WALL_TOPROW = 100  # рядок плану: низ муру = верх тераси
WALL_BASE = 285  # рядок кадру низу муру при камері верху (плато — 277: низ сховано)
WALL_HEIGHT = 52  # мур у арті: нижчий за героя (64), будинки видно над ним
WALL_LEFT = 0  # стовпець плану, де мур (і тераса) починається: обламаний кут
WALL_HAZE = 0.2  # мур і тераса далі за скелю: серпанок, як у стін ущелини
BREACH = (250, 330)  # пролам у мурі (стовпці плану) — над плато, біля східного краю
WALL_TEXT = (
    "the outer wall of a desert village standing on the flat top of a sandstone cliff, seen exactly from the side: a "
    "long low wall of weathered clay and mud bricks with a crumbling broken left end, a few faint grey scorch marks on "
    "it, a wide jagged breach broken through the wall on the right with a few fallen bricks at its foot, the wall "
    "standing directly on bare rock, below it the red-orange and ochre sandstone cliff face with horizontal rock "
    f"strata and cracks down to the bottom edge, {cb.CHROMA} above the wall and in the breach, {cb.STYLE}"
)

# спалене село за муром (×0.6): три будинки Village/gen_houses (з синім тентом, з червоним, наступний) окремо, з
# проміжками, img2img «після пожежі» — стіни цілі; з кожного даху — невеликий дим (A5: великий шлейф закривав пів неба).
# ×0.6 і розмір ряду в селі (стіна ~83 арту ≈ поверх 144 × 0.6, D814): три будинки вміщаються над муром
HOUSES_F = 0.6
HOUSES_SEED = 853
HOUSES_ROWS = (0, 272)  # рядки gen_houses (над дахами — місце для диму; поріг ~231); 272 × 3 = 816, кратне 16
HOUSES_PICK = ((100, 232), (232, 332), (332, 456))  # стовпці будинків у gen_houses
HOUSES_GAP = 12  # magenta між ними: окремі будинки, а не одна довга стіна
HOUSES_TEXT = (
    "three separate small desert village houses standing apart after a great fire, still standing: flat-roofed adobe "
    "and clay brick houses with their walls whole and unbroken, black soot streaks above the doorways and windows, the "
    "cloth awnings burnt away leaving only charred bare wooden frames, charred black doors and shutters, wooden roof "
    "beams burnt to black stumps, a short thin column of grey smoke rising from each roof and leaning to the left in "
    f"the wind, a faint orange glow in one window, {cb.MAGENTA}, {cb.STYLE}"
)
HOUSES_BLOCK = 3
HOUSES_KEEP = 240  # рядки після зменшення: будинки й смуга землі під ними
HOUSES_PAD = 45  # земля під будинками — ще стільки рядків донизу: у проламі видно двір, а не небо під ним
# лівий нижній кут будинків у кадрі при камері верху: правіше від рваного краю тераси (192 + до ~20); низ — за муром і терасою (мур у кадрі
# — рядки ~225–315), пороги ~252, тож над муром видно стіни з вікнами й дахи
HOUSES_AT = (222, 305)

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


def sandstone(h, w):
    """Пісковик стіни ущелини в px генерації: сира генерація її шматка 1 (без гребеня), повтори по вертикалі."""
    r = np.asarray(Image.open(gp.raw("wall_1")).convert("RGB"))[300:]
    r = np.concatenate([r, np.flipud(r)])
    reps = (-(-h // len(r)), -(-w // r.shape[1]), 1)
    return np.tile(r, reps)[:h, :w]


def cliff_palette():
    """Палітра стін (MountainPath/gen_mid, 11 кольорів): скеля — той самий пісковик, що стіни ущелини."""
    return pp.palette(pp.MP + "gen_mid.png")


def ledges_guide():
    """Напрямна скелі в px генерації: тіло — пісковик стіни ущелини, верх кожного уступу — світла піщана кромка,
    тінь під нею; берег і каскад — як в ущелині."""
    ground = pp.palette(pp.MP + "gen_ground.png")
    cp = cliff_palette()
    g = np.zeros((RH, W, 3), np.uint8)
    g[:] = (0, 255, 0)
    ys = np.arange(RH)[:, None]
    depth = ys - top(np.arange(W))[None, :]
    g[(depth >= 0) & (depth < 7)] = cp[-2]  # освітлений верх уступу
    g[(depth >= 7) & (depth < 11)] = cp[2]  # тінь під кромкою
    img = Image.fromarray(g)
    d = ImageDraw.Draw(img)
    for (x0, y0), (x1, _) in zip(STEPS[1:], STEPS[2:] + [(W, 0)]):
        d.line(
            [(x0 - 1, y0), (x1, y0)], fill=tuple(int(c) for c in ground[-1]), width=2
        )  # кромка
    big = np.asarray(img.resize((W * K, RH * K), Image.NEAREST)).copy()
    bb = np.repeat(np.repeat(depth >= 11, K, 0), K, 1)
    big[bb] = sandstone(RH * K, W * K)[bb]
    s = gorge_strip()
    a = np.repeat(np.repeat(s[..., 3] > 0, K, 0), K, 1)
    sub = big[(RH - len(s)) * K :, : s.shape[1] * K]
    sub[a] = np.repeat(np.repeat(s[..., :3], K, 0), K, 1)[a]
    x0, x1, y0 = CASCADE
    big[y0 * K : FLOOR * K, x0 * K : x1 * K] = gp.WATER[2]
    return np.asarray(Image.fromarray(big).filter(ImageFilter.GaussianBlur(3)))


def wall_guide():
    """Напрямна муру (px плану ×3): мур із глини між рядками WALL_TOPROW − WALL_HEIGHT і WALL_TOPROW від WALL_LEFT,
    пролам BREACH до тераси, під муром — пісковик до низу; над муром і в проламі — зелене тло."""
    v = np.asarray(Image.open(pp.B + "Village/gen_houses.png").convert("RGBA"))
    patch = v[150:220, 140:220]
    clay = np.median(patch[patch[..., 3] > 0][:, :3], axis=0)
    g = np.zeros((WALL_H, WALL_W, 3), np.uint8)
    g[:] = (0, 255, 0)
    x = np.arange(WALL_W)
    rng = np.random.default_rng(WALL_SEED)
    wtop = WALL_TOPROW - WALL_HEIGHT + np.round(rng.normal(0, 1.2, WALL_W)).astype(int)
    end = x < WALL_LEFT + 24  # обламаний кут
    wtop[end] += (WALL_LEFT + 24 - x[end]) * 2
    b0, b1 = BREACH
    gap = np.clip(
        1 - np.abs(x - (b0 + b1) / 2) / ((b1 - b0) / 2), 0, 1
    )  # пролам: V до тераси
    wtop = wtop + (np.minimum(gap * 1.6, 1) * WALL_HEIGHT).astype(int)
    ys = np.arange(WALL_H)[:, None]
    wall = (ys >= wtop[None, :]) & (ys < WALL_TOPROW) & (x[None, :] >= WALL_LEFT)
    g[wall] = clay
    g[wall & ((ys % 8) == 0)] = clay * 0.8  # ряди цегли
    big = np.asarray(
        Image.fromarray(g).resize((WALL_W * K, WALL_H * K), Image.NEAREST)
    ).copy()
    rock = np.repeat(
        np.repeat((ys >= WALL_TOPROW) & (x[None, :] >= WALL_LEFT), K, 0), K, 1
    )
    big[rock] = sandstone(WALL_H * K, WALL_W * K)[rock]
    return np.asarray(Image.fromarray(big).filter(ImageFilter.GaussianBlur(3)))


def burnt_guide():
    """Три будинки села над magenta окремо (HOUSES_PICK через HOUSES_GAP), ×3; з кожного даху — короткий сірий дим із
    нахилом на захід."""
    v = np.asarray(Image.open(pp.B + "Village/gen_houses.png").convert("RGBA")).astype(np.float32)
    a = v[..., 3:] / 255
    rgb = v[..., :3] * a + np.array([255, 0, 255], np.float32) * (1 - a)
    rgb = rgb[HOUSES_ROWS[0] : HOUSES_ROWS[1]]
    canvas = np.zeros((len(rgb), W, 3), np.float32)
    canvas[:] = (255, 0, 255)
    x, roofs = 0, []
    for x0, x1 in HOUSES_PICK:
        canvas[:, x : x + x1 - x0] = rgb[:, x0:x1]
        roof = int(np.argmax(v[:, (x0 + x1) // 2, 3] > 0))
        roofs.append((x + (x1 - x0) // 2, roof))
        x += x1 - x0 + HOUSES_GAP
    img = Image.fromarray(canvas.astype(np.uint8))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(HOUSES_SEED)
    for rx, roof in roofs:
        for i in range(10):
            t = i / 9
            cx, cy = rx - 24 * t**1.5 + rng.normal(0, 1.5), roof - 4 - t * 60
            r = 3 + 7 * t
            grey = int(120 + 50 * t)
            d.ellipse((cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), fill=(grey, grey - 4, grey + 6))
    big = img.resize((W * K, img.height * K), Image.NEAREST).filter(ImageFilter.GaussianBlur(2))
    return np.asarray(big)


def free():
    cb.urllib.request.urlopen(
        cb.urllib.request.Request(
            cb.API + "/free",
            cb.json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )


def img2img(guide, text, seed, denoise, name):
    """Уся напрямна — img2img (маска на все полотно); висота доповнюється до кратної 16."""
    hgt = -(-len(guide) // 16) * 16
    guide = np.concatenate([guide, np.repeat(guide[-1:], hgt - len(guide), 0)])
    rgba = np.concatenate([guide, np.zeros((*guide.shape[:2], 1), np.uint8)], 2)
    up = cb.upload(rgba, f"ledges_{name}_guide.png")
    out = cb.run(cb.graph(text, seed, hgt, up, denoise, width=guide.shape[1]))
    Image.fromarray(out[: len(guide)].astype(np.uint8)).save(raw(name))
    print(name, flush=True)


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
        img2img(
            ledges_guide(),
            LEDGES_TEXT,
            LEDGES_SEED,
            CLIFF_DENOISE,
            f"cliff_{LEDGES_SEED}",
        )
    if not os.path.exists(raw(f"villagewall_{WALL_SEED}")):
        img2img(wall_guide(), WALL_TEXT, WALL_SEED, 0.8, f"villagewall_{WALL_SEED}")
    if not os.path.exists(raw(f"burnt_{HOUSES_SEED}")):
        img2img(burnt_guide(), HOUSES_TEXT, HOUSES_SEED, 0.65, f"burnt_{HOUSES_SEED}")
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

    # скеля з уступами: колір — генерація в палітрі стін без серпанку, форма — точно STEPS (по ній карта ставить
    # колізію); кромка й тінь під нею — як лінія ходьби дороги (gen_ground)
    pal = pp.palette(pp.MP + "gen_ground.png")
    cpal = cliff_palette()
    rgb, _ = cb.shrink(
        np.asarray(Image.open(raw(f"cliff_{LEDGES_SEED}")).convert("RGB"), np.float32),
        None,
    )
    out = np.zeros((RH, W, 4), np.uint8)
    out[..., :3] = pp.to_palette(rgb, cpal)
    ys = np.arange(RH)[:, None]
    t = top(np.arange(W))
    out[..., 3] = (ys >= t[None, :]) * 255
    # глибше 14 рядків під верхом — без трьох найсвітліших кольорів і трохи темніше: світлі полиці моделі в стіні
    # читалися б як уступи, а колізії там немає
    deep = (ys - t[None, :] >= 14) & (out[..., 3] > 0)
    out[deep, :3] = np.round(
        pp.to_palette(rgb[deep][None], cpal[:-3])[0] * (1 - CLIFF_SHADE)
    ).astype(np.uint8)
    cols = np.arange(W)
    out[t, cols, :3] = pal[-1]  # кромка
    out[t + 1, cols, :3] = pal[1]  # тінь під нею
    # берег із річкою — пікселі ущелини дзеркально (без шва на межі)
    s = gorge_strip()
    sub = out[RH - len(s) :, : s.shape[1]]
    a = s[..., 3] > 0
    sub[a] = s[a]
    # каскад малює скрипт: струмінь з-під кромки уступу 1 у кінець річки, перед стінкою (у повітрі над берегом —
    # колізії не стосується), смуги трьох кольорів води, піна внизу
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
    print("ledges", out.shape, flush=True)

    # мур села з терасою (×0.9): ключ green, до низу суцільно, легкий серпанок (далі за скелю)
    rgb, opaque = cb.shrink(
        np.asarray(
            Image.open(raw(f"villagewall_{WALL_SEED}")).convert("RGB"), np.float32
        ),
        "green",
        10,
    )
    opaque[:, :WALL_LEFT] = False
    rgb, opaque = cb.fill_down(rgb, opaque)
    rgb = rgb * (1 - WALL_HAZE) + cb.HAZE * WALL_HAZE
    q = cb.quantize(rgb, opaque, 14, "octree")
    # лівий край тераси — не прямий зріз полотна, а рваний край скелі з тінню (видно в нижньому кадрі над уступами)
    rng = np.random.default_rng(WALL_SEED)
    rows = np.arange(len(q))
    edge = np.round(8 + 5 * np.sin(rows / 9) + np.cumsum(rng.normal(0, 0.6, len(q))).clip(-6, 6)).astype(int).clip(1, None)
    edge[rows < WALL_TOPROW + 30] = 0
    dark = q[q[..., 3] > 0][:, :3][np.argmin(q[q[..., 3] > 0][:, :3].astype(int).sum(1))]
    for y in np.nonzero(edge)[0]:
        q[y, : edge[y], 3] = 0
        q[y, edge[y] : edge[y] + 2, :3] = dark
    Image.fromarray(q).save(RL + "gen_village_wall.png")
    print("village wall", q.shape, flush=True)

    # спалені будинки: ключ magenta, 16 кольорів, легкий серпанок (за муром, ×0.85)
    rgb, opaque = cb.shrink(
        np.asarray(Image.open(raw(f"burnt_{HOUSES_SEED}")).convert("RGB"), np.float32),
        "magenta",
        12,
        HOUSES_BLOCK,
    )
    rgb = rgb * 0.85 + cb.HAZE * 0.15
    # дірки в будинку (ключ з'їв сіру завісу й тіні в дверях) — найтемнішим кольором: випалене нутро, а не гори крізь стіну
    hole = cb.holes(opaque)
    rgb[hole] = rgb[opaque][np.argmin(rgb[opaque].sum(1))]
    opaque = opaque | hole
    q = cb.quantize(rgb, opaque, 16, "octree")
    q = q[:HOUSES_KEEP]
    ys_, xs_ = np.nonzero(q[..., 3])
    q = q[ys_.min() :, xs_.min() : xs_.max() + 1]
    q = np.concatenate([q, np.repeat(q[-1:], HOUSES_PAD, 0)])
    Image.fromarray(q).save(RL + "gen_burnt_houses.png")
    print("burnt houses", q.shape, flush=True)
    check()


def planes():
    """(картинка, множник, якір у світі арту при камері 0, плитка) — від заднього до переднього."""
    houses = pp.img(RL + "gen_burnt_houses.png")
    vwall = pp.img(RL + "gen_village_wall.png")
    front = pp.img(gp.SG + "gen_front.png")
    front[..., :3] *= pp.FRONT_DARK
    return [
        (pp.img(pp.B + "DesertOasis/bg4/plan5.png"), 0.0, (0, 0), W),
        (pp.img(pp.MP + "gen_barrier.png"), 0.1, pp.BARRIER_AT, None),
        (pp.img(pp.MP + "gen_far.png"), 0.3, (0, 0), W),
        (
            houses,
            HOUSES_F,
            (HOUSES_AT[0] + HOUSES_F * CX, HOUSES_AT[1] - len(houses)),
            None,
        ),
        (
            pp.img(RL + "gen_mid.png"),
            MID_F,
            (MID_F * X0, gp.R0),
            None,
        ),
        (vwall, WALL_F, (WALL_X + WALL_F * CX, WALL_BASE - WALL_TOPROW), None),
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
    # нижній рядок будинків — під ближчими планами при кожній камері y: кадр не міняється, якщо цей
    # рядок пофарбувати в червоне (мур іде до низу кадру — його низ ніколи не видно)
    for i in (3,):
        im, f, anchor, _ = ps[i]
        marked = im.copy()
        last = np.nonzero(im[..., 3].any(1))[0].max()
        marked[last, im[last, :, 3] > 0, :3] = (255, 0, 0)
        mps = ps[:i] + [(marked, f, anchor, None)] + ps[i + 1 :]
        for cy in range(0, CY[2] + 1, 2):
            diff = np.abs(view(ps, cy, None) - view(mps, cy, None)).max()
            assert diff < 1, f"низ плану {i} видно при камері y {cy}"
    print(
        "steps ok, mid joined, house bases hidden at every camera y",
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
            "Rock ledges, bottom frame (1920x1080): the hero on ledge 2; sandstone cliff, ledges 60 world px wide, steps 63-81 world px, each one jump",
            view(ps, CY[2], (X0 + 156, 501, hero)),
        ),
        (
            "Rock ledges, top frame (1920x1080): the wide plateau, the breach in the village wall, the burnt houses beyond with smoke from their roofs",
            view(ps, CY[0], (X0 + 400, TOP, hero)),
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
