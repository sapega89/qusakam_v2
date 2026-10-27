"""M6a-1: гірська стежка (2 екрани) і осипище (1×2) — дорога від мосту до села, без боїв (world_structure_plan v3).
Шари стежки робить comfy_backdrop.py (MountainPath/gen_*); тут — два шари осипища, яких одним текстом не зробити,
бар'єр (світло на чорному → прозорість), обрізка смуги землі й аркуш для Сапеги.
  python -B design/shots/candidates/path_planes/path_planes.py gen    — ComfyUI: стіна ущелини під гребенем gen_mid,
                                                                       схил осипу за напрямною, бар'єр (сирі PNG поруч)
  python -B design/shots/candidates/path_planes/path_planes.py build  — (scipy) плани осипища, рядок 0 gen_ground, gen_barrier
  python -B design/shots/candidates/path_planes/path_planes.py sheet  — design/shots/m6a1_path_scree.png

Одиниці — пікселі арту (світ = ×1.5). Стежка 1152×320 (1728×480 світу), осипище 576×640 (864×960), праворуч від
стежки. Лінія ходьби — y 416 світу (рядок 277); дно ущелини — y 896 (рядок 597). Плани прив'язані до світу, не до
кімнати: зсув плану з множником f у кімнаті з лівим краєм X — −f·X, тож на межі кімнат далина й середній план тягнуться
далі, а не стрибають назад.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, "Scripts/Tools")
import comfy_backdrop as cb

D = os.path.dirname(os.path.abspath(__file__))
B = "SampleProject/Assets/Backgrounds/"
MP, SC = B + "MountainPath/", B + "ScreeSlide/"
K, W, H = 3, 576, 324
WALK, FLOOR = 277, 597  # лінія ходьби стежки й дно ущелини в осипищі
# поверхня схилу: рівний вхід від стежки, схил ~37° (не крутіше 45° — по ньому ще можна йти), рівне дно до виходу
SLOPE = [(0, WALK), (64, WALK), (480, FLOOR), (W, FLOOR)]
SH = 640  # висота осипища
PATH_W = 1152  # ширина стежки — осипище починається тут
MID_F = 0.75
ROLL = round(MID_F * PATH_W) % W  # фаза плитки gen_mid, яку бачить осипище (288)
KEEP_MID = 253  # рядки gen_mid, що в осипищі лишаються як є; нижче — стіна ущелини
# бар'єр — величезний прозорий купол над селом із тріщиною (Сапега: «прозорий шар в небі з тріщиною»); лор кольору не
# дає («дзвенів над дюнами»), тож модель малює світло на чорному, а колір і прозорість — наші (build)
BARRIER_SEED = 701  # ширший і пласкіший купол; 702 — вужчий
BARRIER_CROP = (
    188,
    72,
    1556,
    688,
)  # x0, y0, x1, y1 сирої: купол без «підлоги» й обідка внизу (вони за горами)
BARRIER_W = W  # ширина купола в арті — на весь екран (D797; було 456 — чотири п'ятих), 576×259
BARRIER_ALPHA = (0.1, 0.18, 0.3, 0.45)  # тіло (за ним видно пролам), відблиски, обрис, кромки тріщини
BARRIER_TINT = np.array(
    [236, 246, 255], np.float32
)  # блідо-біле скло з холодним відтінком (лор кольору не дає)
WALL_HAZE = 0.35  # додатковий серпанок стіни ущелини під гребенем: уступи не мають читатися як підлога (D795)
WALL_RAMP = (
    64  # рядків від KEEP_MID, за які серпанок наростає (8 сходинок, без дизерингу)
)
BARRIER_TEXT = (
    "a gigantic faint transparent dome of magical glass seen from very far away, a thin shimmering hemisphere shell "
    "of pale white light, its curved base resting on the bottom edge of the frame and its arc filling the whole width, "
    "only its thin bright outline and a few faint streaks of reflection on its surface, the inside of the dome dark "
    "and empty, a long jagged crack running down across its upper left part with a large shard broken out of the "
    "shell leaving a jagged hole, thin cracks branching from the hole, no ground, no landscape, nothing else, on a "
    "pure solid black background, flat matte painting for a 2D game, clean simple shapes"
)


def raw(name):
    return os.path.join(D, f"path_{name}_raw.png")


def mid_guide():
    """Напрямна стіни ущелини: gen_mid (шар, уже залитий донизу) у фазі осипища, нижче — його останній рядок до дна,
    небо — зелене. Сира генерація не годиться: під низьким гребенем у ній зелене тло, і модель продовжувала небо."""
    m = np.roll(np.asarray(Image.open(MP + "gen_mid.png")), -ROLL, axis=1)
    g = np.zeros((SH, W, 3), np.uint8)
    g[:] = (0, 255, 0)
    g[: len(m)][m[..., 3] > 0] = m[..., :3][m[..., 3] > 0]
    g[len(m) :] = g[len(m) - 1]
    big = Image.fromarray(g).resize((W * K, SH * K), Image.NEAREST)
    return np.asarray(big.filter(ImageFilter.GaussianBlur(3)))


def surface(x):
    xs, ys = zip(*SLOPE)
    return np.interp(x, xs, ys)


def gen():
    # стіна ущелини: верх — gen_mid як є (маска «лишити»), нижче модель домальовує скелі до дна поверх напрямної.
    # 601 — водоспад вийшов оливковою смугою; 602 (з сирої генерації, denoise 1) — праворуч продовжилось небо
    if not os.path.exists(raw("scree_mid_603")):
        g = mid_guide()
        y = np.arange(SH * K)
        keep = np.clip(
            ((KEEP_MID + 34) * K - y) / (34 * K), 0, 1
        )  # 1 — лишити, 0 — перемалювати
        alpha = np.repeat((keep * 255).astype(np.uint8)[:, None, None], W * K, axis=1)
        name = cb.upload(np.concatenate([g, alpha], 2), "scree_mid.png")
        text = (
            "the far wall of a deep mountain gorge: tall rugged red-orange and ochre sandstone cliffs with horizontal "
            "rock strata, ledges and cracks, filling the whole width and continuing from the ridge at the top all the "
            "way down to the bottom edge, a few dry brown thorn bushes on the ledges, warm light on the ledges, "
            f"cool violet shadows in the cracks, {cb.CHROMA} above the ridge, {cb.STYLE}"
        )
        out = cb.run(cb.graph(text, 603, SH * K, name, 0.9))
        Image.fromarray(out.astype(np.uint8)).save(raw("scree_mid_603"))
        print("scree_mid_603", flush=True)
    # схил: напрямна — зелене тло над лінією, під нею смуги ґрунту, осипу й скелі в палітрі gen_ground
    if not os.path.exists(raw("scree_611")):
        pal = palette(MP + "gen_ground.png")
        light, dirt, stone, rock, dark = (
            pal[-1],
            pal[-3],
            pal[len(pal) // 2],
            pal[3],
            pal[0],
        )
        rng = np.random.default_rng(611)
        g = np.zeros((SH, W, 3), np.uint8)
        g[:] = (0, 255, 0)
        depth = np.arange(SH)[:, None] - surface(np.arange(W))[None, :]
        g[depth >= 0] = dirt
        g[depth >= 3] = stone
        g[depth >= 30] = rock
        g[(depth >= 30) & ((np.arange(SH)[:, None] // 9) % 3 == 0)] = dark  # пласти
        img = Image.fromarray(g)
        d = ImageDraw.Draw(img)
        for _ in range(260):  # каміння осипу вздовж поверхні
            x = rng.uniform(0, W)
            y = surface(x) + rng.uniform(2, 28)
            r = rng.uniform(1.5, 5)
            d.ellipse(
                (x - r, y - r * 0.7, x + r, y + r * 0.7),
                fill=tuple(int(c) for c in (light if rng.random() < 0.4 else dark)),
            )
        d.line([(x, y) for x, y in SLOPE], fill=tuple(int(c) for c in light), width=2)
        big = img.resize((W * K, SH * K), Image.NEAREST).filter(
            ImageFilter.GaussianBlur(4)
        )
        rgba = np.concatenate(
            [np.asarray(big), np.zeros((SH * K, W * K, 1), np.uint8)], 2
        )  # уся маска — img2img
        name = cb.upload(rgba, "scree_guide.png")
        text = (
            "a steep slope of loose scree and broken rubble seen exactly from the side in cross-section, running in a "
            "straight diagonal from the upper left down to the lower right, loose red and ochre stones and pebbles lying "
            "on its surface, layered red-orange and dark violet rock strata below it, at the bottom right a flat level "
            f"ledge of packed reddish dirt, {cb.CHROMA} above the slope, {cb.STYLE}"
        )
        out = cb.run(cb.graph(text, 611, SH * K, name, 0.8))
        Image.fromarray(out.astype(np.uint8)).save(raw("scree_611"))
        print("scree_611", flush=True)
    # бар'єр, що впав (D795): світло на чорному тлі — яскравість стане прозорістю (build)
    if not os.path.exists(raw(f"barrier_{BARRIER_SEED}")):
        out = cb.run(cb.graph(BARRIER_TEXT, BARRIER_SEED, 976))
        Image.fromarray(out.astype(np.uint8)).save(raw(f"barrier_{BARRIER_SEED}"))
        print(f"barrier_{BARRIER_SEED}", flush=True)
    cb.urllib.request.urlopen(
        cb.urllib.request.Request(
            cb.API + "/free",
            cb.json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )


def palette(path):
    a = np.asarray(Image.open(path).convert("RGBA"))
    p = np.unique(a[a[..., 3] > 0][:, :3], axis=0).astype(np.float32)
    return p[np.argsort(p.sum(1))]  # від темного до світлого


def to_palette(rgb, pal):
    d = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1)
    return pal[d.argmin(-1)]


def build():
    # смуга стежки: рядок 0 — лінія ходьби (перший суцільний рядок); камінці над нею зрізаються
    g = np.asarray(Image.open(MP + "gen_ground.png"))
    top = int(np.argmax((g[..., 3] > 0).mean(1) >= 0.9))
    if top:
        Image.fromarray(g[top:]).save(MP + "gen_ground.png")
    print("ground rows", len(g) - top, flush=True)
    os.makedirs(SC, exist_ok=True)
    # середній план осипища: gen_mid у фазі осипища до KEEP_MID, нижче — стіна ущелини в його ж палітрі
    mid = np.roll(np.asarray(Image.open(MP + "gen_mid.png")), -ROLL, axis=1)
    layer = cb.LAYERS["MountainPath/gen_mid"]
    rgb, opaque = cb.shrink(
        np.asarray(Image.open(raw("scree_mid_603")).convert("RGB"), np.float32),
        "green",
        layer["spill"],
    )
    rgb, opaque = cb.fill_down(rgb, opaque)
    rgb = rgb * (1 - layer["haze"]) + cb.HAZE * layer["haze"]
    out = np.zeros((SH, W, 4), np.uint8)
    out[..., :3] = to_palette(rgb, palette(MP + "gen_mid.png"))
    out[..., 3] = opaque * 255
    # стіна під гребенем — у серпанку, як далина: сходинками по 8 рядків від KEEP_MID, тож шва з гребенем немає
    step = np.clip((np.arange(SH) - KEEP_MID) // (WALL_RAMP // 8) + 1, 0, 8) / 8
    h = (WALL_HAZE * step)[:, None, None]
    out[..., :3] = np.round(out[..., :3] * (1 - h) + cb.HAZE * h).astype(np.uint8)
    out[: len(mid)][:KEEP_MID] = mid[:KEEP_MID]
    Image.fromarray(out).save(SC + "gen_mid.png")
    # схил: колір — генерація в палітрі gen_ground, форма — точно SLOPE (по ній карта ставить колізію)
    pal = palette(MP + "gen_ground.png")
    rgb, _ = cb.shrink(
        np.asarray(Image.open(raw("scree_611")).convert("RGB"), np.float32), None
    )
    out = np.zeros((SH, W, 4), np.uint8)
    out[..., :3] = to_palette(rgb, pal)
    ys = np.arange(SH)[:, None]
    edge = np.ceil(surface(np.arange(W))).astype(int)[None, :]
    out[..., 3] = (ys >= edge) * 255
    # кромка: найсвітліший колір на поверхні, під нею — рядок тіні (як підлога табору)
    cols = np.arange(W)
    out[edge[0], cols, :3] = pal[-1]
    out[edge[0] + 1, cols, :3] = pal[1]
    # зелені відблиски моделі (тло пролізло під лінію) — у найближчий незелений колір
    px = out[..., :3].astype(int)
    green = (
        (out[..., 3] > 0)
        & (px[..., 1] > px[..., 0] + 15)
        & (px[..., 1] >= px[..., 2] - 10)
    )
    out[green, :3] = pal[len(pal) // 2]
    Image.fromarray(out).save(SC + "gen_scree.png")
    print("scree", out.shape, "green fixed", int(green.sum()), flush=True)
    barrier()


def barrier():
    """Бар'єр, що впав: модель малює світле скло на чорному; яскравість стає прозорістю (BARRIER_ALPHA), колір —
    BARRIER_TINT. Нижче BARRIER_CROP — обідок і «підлога», які модель ставить під купол: їх ховають гори."""
    x0, y0, x1, y1 = BARRIER_CROP
    r = np.asarray(
        Image.open(raw(f"barrier_{BARRIER_SEED}")).convert("RGB"), np.float32
    )
    lum = r[y0:y1, x0:x1].mean(2)
    # та сама сира, менше зменшення (2.375 замість 3): середнє по площі (BOX), як раніше блоки 3×3, тож пікселі арту
    # лишаються різкими, а купол, тріщина й пролам більшають у 1.26 раза
    h = round(lum.shape[0] * BARRIER_W / lum.shape[1])
    lum = np.asarray(
        Image.fromarray(lum.astype(np.float32)).resize((BARRIER_W, h), Image.BOX)
    )
    # пороги яскравості сирої (0–255): тло ~3, тіло ~70, відблиски ~130, обрис ~200, кромки ~240
    level = np.digitize(lum, [40, 100, 160, 215])
    out = np.zeros((h, BARRIER_W, 4), np.uint8)
    out[..., :3] = BARRIER_TINT
    out[..., 3] = np.round(np.array((0,) + BARRIER_ALPHA)[level] * 255)
    Image.fromarray(out).save(MP + "gen_barrier.png")
    print("barrier", out.shape, [int((level == i).sum()) for i in range(5)], flush=True)


# --- аркуш ---------------------------------------------------------------------------------------------------------
FRONT_DARK = np.array([0.3, 0.26, 0.34])  # foreground_dark.tscn (D750)
# шлейф диму (Сапега, ескіз 27.10): вітер несе дим із села на захід через усе небо; герой біжить під ним на схід.
# Один план на стежку й осипище, прив'язаний до світу: на початку стежки — лише хвіст біля правого краю кадру (100 px),
# наприкінці — кінчик посередині й тіло до краю, на осипищі — увесь шлейф, клуб біля східного краю, а стебло до
# джерела (зріз keep унизу праворуч, стовпці від 568) — за краєм кадру. Звідси множник: між правим краєм кадру на початку
# стежки й на осипищі — 1152·f px плану, а шлейф лише 568 до стебла, тож при ×0.5 або хвоста не видно, або стебло в кадрі
PLUME_F = 0.4
PLUME_AT = (475, -20)  # лівий верхній кут шлейфу в арті при камері 0: кінчик (рядок 83) — у верхній третині неба
# лівий верхній кут купола (D797): при камері осипища (x 1152) купол рівно на весь кадр, на початку стежки — від x 115
# (над сходом, де село), в ущелині зсувається ліворуч; вершина в рядку ~7, нижній зріз (рядок 263) — за горами
# (найглибша долина далини — 223). Пролам — x 136–272 купола
BARRIER_AT = (115, 4)


def img(path):
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)


def planes(room):
    """(картинка, множник, якір у світі арту при камері 0, плитка) — від заднього до переднього."""
    way, front = (
        img(MP + "gen_waymarker.png"),
        img(MP + "gen_front.png"),
    )
    front[..., :3] *= FRONT_DARK
    barrier = img(MP + "gen_barrier.png")
    p = [
        (img(B + "DesertOasis/bg4/plan5.png"), 0.0, (0, 0), W),
        # бар'єр — за горами й шлейфом, спільний для доріг (×0.1, прив'язаний до світу); нижній зріз купола — рядок 263,
        # нижче найглибшої долини далини (223), тож його ховають гори
        (barrier, 0.1, BARRIER_AT, None),
        (img(MP + "gen_far.png"), 0.3, (0, 0), W),
        (img(MP + "gen_plume.png"), PLUME_F, PLUME_AT, None),
    ]
    if room == "path":
        g = img(MP + "gen_ground.png")
        p += [
            (img(MP + "gen_mid.png"), MID_F, (0, 0), W),
            (way, 0.9, (380 + 0.9 * W, WALK + 2 - len(way)), None),
            (g, 1.0, (0, WALK), W),
            (front, 1.3, (420, H + 40 - len(front)), None),
        ]
    else:
        p += [
            (img(SC + "gen_mid.png"), MID_F, (MID_F * PATH_W, 0), None),
            (img(SC + "gen_scree.png"), 1.0, (PATH_W, 0), None),
            (front, 1.3, (-40 + 1.3 * PATH_W, H + 40 - len(front) + 1.3 * 316), None),
        ]
    return p


def view(room, cx, cy, hero, n=None):
    """Кадр 576×324 арту: камера (cx, cy) — лівий верхній кут кадру у світі; y-множник = x-множник. n — лише n
    задніх планів (без героя)."""
    c = np.zeros((H, W, 4), np.float32)
    c[..., 3] = 255
    for im, f, (ax, ay), tile in planes(room)[:n]:
        x0, y0 = round(ax - f * cx), round(ay - f * cy)
        xs = [x0] if tile is None else range(x0 % tile - tile, W, tile)
        for x in xs:
            paste(c, im, x, y0)
        if f == 1.0 and hero:  # герой — у площині ×1.0, перед підлогою, за реквізитом ×1.3
            paste(c, hero[2], hero[0] - cx, hero[1] - cy - len(hero[2]))
    return c


def paste(c, im, x, y):
    h, w = im.shape[:2]
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    dx1, dy1 = min(W, x + w), min(H, y + h)
    if dx1 <= dx0 or dy1 <= dy0:
        return
    src = im[sy0 : sy0 + dy1 - dy0, sx0 : sx0 + dx1 - dx0]
    a = src[..., 3:] / 255
    c[dy0:dy1, dx0:dx1, :3] = src[..., :3] * a + c[dy0:dy1, dx0:dx1, :3] * (1 - a)


def sheet():
    hero = img("SampleProject/Sprites/Player/Walk/1.png")  # Idle, кадр 1
    ys, xs = np.nonzero(hero[..., 3])
    hero = hero[: ys.max() + 1]  # ступні — на нижньому рядку
    hw = len(hero[0])
    shots = [
        (
            "1/3 of the approach. Mountain path, camera at the room's left end: only the plume's tail, east (plume x0.4)",
            view("path", 0, 0, (288 - hw // 2, WALK, hero)),
        ),
        (
            "2/3. Mountain path, one screen right (far x0.3, mid x0.75, waymarker x0.9, ground x1, front x1.3)",
            view("path", W, 0, (W + 288 - hw // 2, WALK, hero)),
        ),
        (
            "3/3. Scree slide, top, right after the border: the whole plume, its source beyond the east edge",
            view("scree", PATH_W, 0, (PATH_W + 30, WALK, hero)),
        ),
        (
            "Scree slide: camera one screen down (on the gorge floor; far sinks behind the rim)",
            view("scree", PATH_W, 316, (PATH_W + 500, FLOOR, hero)),
        ),
        (
            "The fallen barrier (x0.1), x2 crop: path camera mid-room; the broken hole over the far peaks",
            np.asarray(
                Image.fromarray(view("path", 288, 0, None).astype(np.uint8))
                .crop((130, 0, 418, 162))
                .resize((W, H), Image.NEAREST)
            ).astype(np.float32),
        ),
        (
            "The barrier plane alone: sky and barrier (scree top camera, no mountains)",
            view("scree", PATH_W, 0, None, 2),
        ),
    ]
    tw, th, lab = 960, 540, 28
    out = Image.new("RGB", (tw * 2 + 12, (th + lab) * 3 + 24), (24, 22, 28))
    d = ImageDraw.Draw(out)
    font = ImageFont.load_default()
    for i, (title, v) in enumerate(shots):
        x, y = (i % 2) * (tw + 12), (i // 2) * (th + lab + 12)
        frame = Image.fromarray(v.astype(np.uint8)[..., :3]).resize(
            (1920, 1080), Image.NEAREST
        )
        out.paste(frame.resize((tw, th), Image.NEAREST), (x, y + lab))
        d.text((x + 6, y + 8), title, fill=(235, 225, 200), font=font)
    out.save("design/shots/m6a1_path_scree.png")
    print("sheet", out.size, flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build, "barrier": barrier, "sheet": sheet}[sys.argv[1]]()
