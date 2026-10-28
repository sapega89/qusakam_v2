"""Щит-закляття (H2, design/skills_audit.md — Sapega 2026-10-27: щит не носять, він «з'являється з неба, бо це магія
з Pathfinder»): магічний щит світла і скляний щит, що тріскає і розлітається осколками в того, хто б'є. Малюються
поверх наявного кадру героя Block/1 (нових кадрів героя немає).
Як ефекти D273 (comfy_fx.py): одна картинка Qwen-Image на хромакеї на кожен щит → ключ, головна пляма, піксель гри,
кілька кольорів; кадри — з цієї однієї картинки. Тріщини й осколки модель між генераціями не тримає — їх малює цей
скрипт. Запуск: python -B Scripts/Tools/shield_spells.py → SampleProject/Assets/FX/Shield/{magic,glass}/,
design/shots/shield_spells.png (×4, кадри поверх Block/1, Idle 1 для масштабу).
"""

import json
import os
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import comfy_backdrop as cb  # noqa: E402
import comfy_fx as fx  # noqa: E402

OUT = "SampleProject/Assets/FX/Shield/"
HERO = "SampleProject/Sprites/Player/"
SHEET = "design/shots/shield_spells.png"
# Щит 31 арт-px заввишки = 0,65 намальованої фігури героя (48 px, рядки 9–56 Block/1; 0,65 від клітинки 64 = 42 px
# закрив би його від ступень до очей, а не стояв би перед грудьми). Перед кулаками Block/1: x 48–63, y 21–51 текстури
# героя. Фронтальний щит, стиснутий по ширині до 0,7, — повернутий до ворога (праворуч).
SHIELD_BOX = (48, 21, 64, 52)  # x0, y0, x1, y1 у текстурі героя 64×64
SQUASH = 0.7
LUMA = np.array([0.3, 0.59, 0.11])

SHIELDS = {
    "magic": dict(
        seed=51,
        size=(768, 1024),
        key="green",
        colors=8,
        # золото моделі читалось металом — 20 % до теплого білого (світло святого воїна); 40 % на піску зникало,
        # тому край (1 px) — суцільний блідо-блакитний, читається і на піску, і на темному
        lift=(0.2, (255, 246, 220)),
        edge=(118, 196, 250),
        prompt="a single magical shield made of solid glowing holy light, a tall heater shield shape with a straight "
        "top edge and a pointed bottom, seen straight from the front, a warm gold and white glowing body, a bright "
        "white core in the middle, a thin pale sky blue glowing rim around its edge, a small radiant four-pointed "
        "star emblem in its centre, centered, " + fx.GREEN,
    ),
    "glass": dict(
        seed=52,
        size=(768, 1024),
        key="magenta",
        colors=8,
        prompt="a single shield made of solid pale icy blue crystal glass, a tall heater shield shape with a straight "
        "top edge and a pointed bottom, seen straight from the front, faceted bevelled glass with sharp white glints "
        "and long diagonal white reflections, a thin bright white rim, centered, "
        + fx.MAGENTA,
    ),
}


def shield(name):
    """Щит у розмірі гри: rgba h×w — ключ, головна пляма, стиск по ширині, вписати в SHIELD_BOX, кольори."""
    s = SHIELDS[name]
    img = fx.generate(name, s)
    a = fx.main_shape(fx.key(img, s["key"]))
    h, w = a.shape
    nw = round(w * SQUASH)
    img = np.asarray(
        Image.fromarray(img.astype(np.uint8)).resize((nw, h), Image.LANCZOS), np.float32
    )
    a = np.asarray(
        Image.fromarray(a.astype(np.float32)).resize((nw, h), Image.BILINEAR),
        np.float32,
    )
    x0, y0, x1, y1 = SHIELD_BOX
    box = (x1 - x0, y1 - y0)
    canvas, opaque = fx.fit(img, a, dict(box=(0, 0) + box, canvas=box, kind="sprite"))
    if "lift" in s:
        k, warm = s["lift"]
        gold = canvas[..., 2] < canvas[..., 0]
        canvas[gold] = canvas[gold] * (1 - k) + np.array(warm, np.float32) * k
    q = cb.quantize(canvas, opaque, s["colors"], "octree")
    if "edge" in s:
        q[rim(opaque), :3] = s["edge"]
    return q


def rim(op):
    return op & ~fx.erode(op, 1)


def palette(q):
    pal = np.unique(q[q[..., 3] > 0][:, :3], axis=0)
    return pal[np.argsort(pal @ LUMA)]


def lighter(q, where):
    """Кожен колір у where — на крок світліший колір тієї ж палітри (мерехтіння, спалах): палітра не росте."""
    pal = palette(q)
    out = q.copy()
    for i, c in enumerate(pal[:-1]):
        m = where & (q[..., 3] > 0) & (q[..., :3] == c).all(axis=2)
        out[m, :3] = pal[i + 1]
    return out


def body_alpha(q, inner):
    """Напівпрозоре тіло (герой проглядає), край — суцільний."""
    out = q.copy()
    op = q[..., 3] > 0
    out[op & ~rim(op), 3] = inner
    return out


def fade(q, k):
    out = q.copy()
    out[..., 3] = (out[..., 3] * k).astype(np.uint8)
    return out


def over(base, sprite, x, y):
    """sprite на base у (x, y), що за краєм — обрізано; лишається піксель з більшою альфою."""
    h, w = sprite.shape[:2]
    H, W = base.shape[:2]
    sx0, sy0, sx1, sy1 = max(0, -x), max(0, -y), min(w, W - x), min(h, H - y)
    if sx0 < sx1 and sy0 < sy1:
        src = sprite[sy0:sy1, sx0:sx1]
        dst = base[y + sy0 : y + sy1, x + sx0 : x + sx1]
        m = src[..., 3] > dst[..., 3]
        dst[m] = src[m]
    return base


def place(size, sprite, x, y):
    return over(np.zeros((size[1], size[0], 4), np.uint8), sprite, x, y)


# Магічний щит: полотно 32×96, ліво-верх — (40, −32) текстури героя (над головою — місце для падіння з неба).
MAGIC, MAGIC_AT = (32, 96), (40, -32)


def put(f, x, y, rgb, a=255):
    """Піксель на полотні f (у межах), якщо він непрозоріший за наявний."""
    if 0 <= y < f.shape[0] and 0 <= x < f.shape[1] and a > f[y, x, 3]:
        f[y, x] = tuple(int(c) for c in rgb) + (a,)


def ray(f, x, y, dx, dy, n, rgb, a=255):
    for k in range(n):
        put(f, x + dx * k, y + dy * k, rgb, a)


def sparkle(f, x, y, core, arm):
    """Іскра-хрестик 3×3: біле серце, руки — колір краю (читається і на темному, і на піску)."""
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        put(f, x + dx, y + dy, arm)
    put(f, x, y, core)


def beam(f, x0, x1, y1, core, glow, side):
    """Стовп світла з неба: від верху полотна до y1 (верх щита); ядро 2 px посередині, сяйво на ширину x0..x1, краї
    стовпа — 1 px кольору краю щита (біле й золоте на піску зникали). Угорі рідшає (через піксель) — тане в небі,
    а не обрізаний краєм полотна."""
    cx = (x0 + x1) // 2
    for y in range(y1):
        t = y / y1
        for x in range(x0, x1):
            if t < 0.4 and (x + y) % 2:
                continue
            if cx - 1 <= x <= cx:
                put(f, x, y, core, 230 if t > 0.4 else 160)
            elif x in (x0, x1 - 1):
                put(f, x, y, side, 220 if t > 0.4 else 140)
            elif t > 0.25:
                put(f, x, y, glow, 130 if t > 0.6 else 90)


def magic_frames(q):
    """A6 (D813, «прибрати» = перемалювати): падіння — щит їде вниз у стовпі світла з неба (замість блідих копій
    над ним, що читались падаючою паличкою), приземлення — спалах променями; згасання — щит розсипається на іскри,
    що злітають (замість ледь видного прозорого щита). hold_* — як були."""
    sx, sy = SHIELD_BOX[0] - MAGIC_AT[0], SHIELD_BOX[1] - MAGIC_AT[1]
    op = q[..., 3] > 0
    h, w = op.shape
    held = body_alpha(q, 210)
    pal = palette(q)
    white, gold = pal[-1], pal[-2]
    edge = q[rim(op)][:, :3]
    blue = edge[np.argmax(edge[:, 2].astype(int) - edge[:, 0])]
    bright = body_alpha(lighter(q, op), 235)
    out = {}
    # падіння: світліший щит у стовпі світла з неба трохи вужчому за щит
    for i, dy in enumerate([-30, -10], 1):
        top = sy + dy
        f = np.zeros((MAGIC[1], MAGIC[0], 4), np.uint8)
        beam(f, sx + 2, sx + w - 2, top, white, gold, blue)
        out[f"drop_{i}"] = over(f, bright, sx, top)
    # приземлення: щит світліший, сяйво довкола (силует + 1 px кольором краю), промені спалаху від країв
    p = np.pad(op, 1)
    ring = (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]) & ~op
    halo = np.zeros_like(q)
    halo[ring] = list(blue) + [190]
    f = place(MAGIC, halo, sx, sy)
    mx, my = sx + w // 2, sy + h // 2
    for dx, dy, x, y, n in (
        (-1, 0, sx - 2, my, 5),  # убік від середини
        (1, 0, sx + w + 1, my, 5),
        (0, -1, mx, sy - 2, 5),  # угору від верху
        (0, -1, mx - 1, sy - 2, 3),
        (-1, -1, sx - 1, sy - 1, 4),  # навскіс від верхніх кутів
        (1, -1, sx + w, sy - 1, 4),
        (-1, 1, sx + 1, sy + h - 6, 3),  # навскіс від низу
        (1, 1, sx + w - 2, sy + h - 6, 3),
    ):
        ray(
            f, x, y, dx, dy, 2, white
        )  # біле серце променя, далі — колір краю (читається на піску)
        ray(f, x + 2 * dx, y + 2 * dy, dx, dy, n - 2, blue)
    out["drop_3"] = over(f, bright, sx, sy)
    # утримання: рівний щит ↔ світла діагональна смуга мерехтіння
    yy, xx = np.mgrid[: q.shape[0], : q.shape[1]]
    band = np.abs((xx * 2 + yy) - q.shape[0] * 0.75) < 4
    out["hold_1"] = place(MAGIC, held, sx, sy)
    out["hold_2"] = place(MAGIC, body_alpha(lighter(q, band), 210), sx, sy)
    # згасання 1: верх ще цілий і світлий, низ розсипається на окремі пікселі (чим нижче, тим рідше; шахівниця
    # читалась візерунком), іскри злітають з боків
    rng = np.random.default_rng(61)
    melt = bright.copy()
    keep = np.clip(1 - (np.arange(h)[:, None] / h - 0.4) / 0.6, 0.12, 1)
    melt[rng.random((h, w)) > keep, 3] = 0
    melt[melt[..., 3] > 0, 3] = (
        255  # що лишилось — суцільне: розсипання, а не прозорість
    )
    f = place(MAGIC, melt, sx, sy)
    for x, y in (
        (sx - 2, sy + 10),
        (sx + w + 1, sy + 6),
        (sx + 2, sy - 3),
        (sx + w - 3, sy - 5),
    ):
        sparkle(f, x, y, white, blue)
    for _ in range(8):
        put(
            f,
            sx + int(rng.integers(-3, w + 3)),
            sy + int(rng.integers(-8, h // 2)),
            gold,
        )
    out["fade_1"] = f
    # згасання 2: щита немає — рій іскор, що летять угору там, де він стояв (повні кольори, без прозорості)
    f = np.zeros((MAGIC[1], MAGIC[0], 4), np.uint8)
    for x, y in (
        (sx + 3, sy - 6),
        (sx + w - 2, sy - 12),
        (sx + w // 2, sy + 4),
        (sx - 1, sy - 15),
    ):
        sparkle(f, x, y, white, blue)
    for _ in range(18):
        x, y = sx + int(rng.integers(-2, w + 2)), sy + int(rng.integers(-20, h - 6))
        put(f, x, y, white if rng.random() < 0.4 else gold)
        if rng.random() < 0.5:
            put(f, x, y + 1, blue)  # хвостик униз — іскра летить угору
    out["fade_2"] = f
    return out


# Скляний щит: полотно 64×64, ліво-верх — (40, 0) текстури героя (праворуч — місце для осколків, що летять у ворога).
GLASS, GLASS_AT = (64, 64), (40, 0)
CRACK = (28, 52, 96)  # темно-синій


def cracks(q, stage, seed=7):
    """Тріщини від точки удару (передня частина, трохи вище середини) — ламані лінії CRACK (найтемніший колір скла
    зливався з гранями — тріщин не було видно).
    stage 1 — п'ять коротких променів; stage 2 — ті самі до краю й ще три, у точці удару вибито кілька пікселів."""
    h, w = q.shape[:2]
    op = q[..., 3] > 0
    cx, cy = w * 0.62, h * 0.42
    rng = np.random.default_rng(seed)
    mask = Image.new("L", (w, h))
    d = ImageDraw.Draw(mask)
    for i, ang in enumerate([-150, -95, -30, 25, 85, 150, 200, -60]):
        jitter = rng.uniform(
            -0.45, 0.45, 10
        )  # однакові злами в обох стадіях: друга продовжує першу
        if stage == 1 and i >= 5:
            break
        steps = 3 if stage == 1 else (9 if i < 5 else 4)
        x, y, a = cx, cy, np.radians(ang)
        pts = [(x, y)]
        for j in range(steps):
            a += jitter[j]
            x, y = x + 3 * np.cos(a), y + 3 * np.sin(a)
            pts.append((x, y))
        d.line(pts, fill=255, width=1)
    m = (np.asarray(mask) > 0) & op & ~rim(op)
    out = q.copy()
    out[m, :3] = CRACK
    if stage == 2:
        hole = (
            np.abs(np.arange(w)[None] - cx) + np.abs(np.arange(h)[:, None] - cy)
        ) < 1.6
        out[hole, 3] = 0
        m &= ~hole
    return out, m


def shatter_frames(q, seed=9):
    """A6 (D813): осколки — шматки щита між тріщинами другої стадії, великі ще порізані на скалки ~5 px (Вороной).
    1 — спалах у точці удару, скалки трохи розійшлися; 2–3 — летять праворуч (у того, хто бив), розходячись угору-вниз
    і падаючи, кожна з темним контуром CRACK (читається й на піску) і рискою руху позаду; на 3 — менші.
    Раніше на 2–3 від шматків лишались крапки (3 і 1,6 px довкола центру) — читалось як випадкові точки."""
    cracked, lines = cracks(q, 2)
    op = cracked[..., 3] > 0
    h, w = op.shape
    labels, n = ndimage.label(op & ~lines)
    rng = np.random.default_rng(seed)
    gy, gx = np.mgrid[2:h:6, 2:w:6]
    seeds = np.stack([gy.ravel(), gx.ravel()], 1) + rng.uniform(-1.5, 1.5, (gy.size, 2))
    yy, xx = np.mgrid[:h, :w]
    near = (
        (yy[..., None] - seeds[:, 0]) ** 2 + (xx[..., None] - seeds[:, 1]) ** 2
    ).argmin(axis=2)
    shard = np.where(labels > 0, labels * len(seeds) + near, 0)
    pal = palette(q)
    white, cyan, pale = pal[-1], pal[-3], pal[-2]
    cx, cy = w * 0.62, h * 0.42  # точка удару, як у cracks()
    ox, oy = SHIELD_BOX[0] - GLASS_AT[0], SHIELD_BOX[1] - GLASS_AT[1]
    frames = []
    for t, (dist, spread, fall, shrink) in enumerate(
        [(4, 0.3, 0, False), (13, 0.75, 1, False), (27, 1.1, 2, True)]
    ):
        f = np.zeros((GLASS[1], GLASS[0], 4), np.uint8)
        body = np.zeros((GLASS[1], GLASS[0]), bool)
        for sid in np.unique(shard[shard > 0]):
            m = shard == sid
            if m.sum() < 3:
                continue
            ys, xs = np.nonzero(m)
            py, px = ys.mean(), xs.mean()
            r = np.random.default_rng(seed * 1000 + int(sid))
            dx = dist * r.uniform(0.6, 1.3) + (px - cx) * spread * 0.6
            # віялом від точки удару; униз удвічі менше — під щитом до краю полотна лише 12 px
            dy = (
                (py - cy) * spread * (1 if py < cy else 0.5)
                + fall
                + r.uniform(-1, 1) * t
            )
            col = cracked[ys, xs]  # своє скло, не світліше: на світлому білий спалах губився
            if shrink:
                keep = (ys - py) ** 2 + (xs - px) ** 2 <= 2.3**2
                ys, xs, col = ys[keep], xs[keep], col[keep]
            X = np.round(xs + dx).astype(int) + ox
            Y = np.round(ys + dy).astype(int) + oy
            # не за край полотна (там скалку різало б прямою), а впритул до нього
            X -= max(0, X.max() - (GLASS[0] - 2))
            Y -= max(0, Y.max() - (GLASS[1] - 2))
            Y += max(0, 1 - Y.min())
            f[Y, X] = col
            f[Y, X, 3] = 255
            body[Y, X] = True
            if t:
                ray(
                    f, int(X.min()) - 1, int(round(Y.mean())), -1, 0, 2 + t, pale, 150
                )  # риска руху позаду
        # темний контур скалок — 1 px зовні
        pb = np.pad(body, 1)
        outline = (pb[:-2, 1:-1] | pb[2:, 1:-1] | pb[1:-1, :-2] | pb[1:-1, 2:]) & ~body
        f[outline] = CRACK + (255,)
        if t == 0:
            # спалах у точці удару — поверх скалок: біле серце, промені білі, кінці (за щитом) — блакитні
            hx, hy = int(round(cx)) + ox, int(round(cy)) + oy
            for dx, dy, k in (
                (1, 0, 15),
                (-1, 0, 5),
                (0, 1, 10),
                (0, -1, 10),
                (1, 1, 8),
                (1, -1, 8),
                (-1, 1, 3),
                (-1, -1, 3),
            ):
                for j in range(1, k + 1):
                    c = white if j <= k - 3 else cyan
                    f[hy + dy * j, hx + dx * j] = tuple(int(v) for v in c) + (255,)
            f[hy - 1 : hy + 2, hx - 1 : hx + 2] = tuple(int(c) for c in white) + (255,)
        frames.append(f)
    return frames


def glass_frames(q):
    sx, sy = SHIELD_BOX[0] - GLASS_AT[0], SHIELD_BOX[1] - GLASS_AT[1]
    out = {}
    # поява: спершу лише край і ледь видне тіло, потім повний щит зі світлою смугою відблиску
    out["appear_1"] = place(GLASS, body_alpha(q, 50), sx, sy)
    yy, xx = np.mgrid[: q.shape[0], : q.shape[1]]
    band = np.abs((xx * 2 + yy) - q.shape[0] * 0.6) < 5
    out["appear_2"] = place(GLASS, body_alpha(lighter(q, band), 190), sx, sy)
    out["hold_1"] = place(GLASS, body_alpha(q, 170), sx, sy)
    for st in (1, 2):
        c, m = cracks(q, st)
        c = body_alpha(c, 170)
        c[m, 3] = 255
        out[f"crack_{st}"] = place(GLASS, c, sx, sy)
    for i, f in enumerate(shatter_frames(q), 1):
        out[f"shatter_{i}"] = f
    return out


def sheet(magic, glass):
    """×4: рядок на щит, кожна клітинка — кадр поверх Block/1 (перша — Idle 1 для масштабу); тло темне, потім пісок."""
    T, hero_at, S, LBL = (104, 96), (0, 32), 4, 12  # текстура героя в (0, 32) клітинки
    idle = Image.open(HERO + "Walk/1.png").convert("RGBA")
    block = Image.open(HERO + "Block/1.png").convert("RGBA")
    rows = [("magic", magic, MAGIC_AT), ("glass", glass, GLASS_AT)]
    cols = 1 + max(len(magic), len(glass))
    out = Image.new("RGBA", (T[0] * cols * S, (T[1] + LBL) * 4 * S), (20, 18, 24, 255))
    d = ImageDraw.Draw(out)
    font = ImageFont.load_default(28)
    for r, (bg, (name, frames, at)) in enumerate(
        (bg, row) for bg in ((58, 56, 68), (214, 186, 140)) for row in rows
    ):
        y = r * (T[1] + LBL) * S
        for c, (label, frame) in enumerate([("Idle 1", None)] + list(frames.items())):
            tile = Image.new("RGBA", T, bg + (255,))
            tile.alpha_composite(idle if frame is None else block, hero_at)
            if frame is not None:
                tile.alpha_composite(
                    Image.fromarray(frame), (hero_at[0] + at[0], hero_at[1] + at[1])
                )
                label = f"{name} {label}"
            out.paste(
                tile.resize((T[0] * S, T[1] * S), Image.NEAREST),
                (c * T[0] * S, y + LBL * S),
            )
            d.text((c * T[0] * S + 8, y + 6), label, font=font, fill=(235, 230, 220))
    return out


if __name__ == "__main__":
    q = {n: shield(n) for n in SHIELDS}
    urllib.request.urlopen(
        urllib.request.Request(
            cb.API + "/free",
            json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )
    made = {"magic": magic_frames(q["magic"]), "glass": glass_frames(q["glass"])}
    for kind, frames in made.items():
        os.makedirs(OUT + kind, exist_ok=True)
        for name, f in frames.items():
            Image.fromarray(f).save(f"{OUT}{kind}/{name}.png")
            print("wrote", f"{OUT}{kind}/{name}.png")
    sheet(made["magic"], made["glass"]).save(SHEET)
    print("sheet", SHEET)
