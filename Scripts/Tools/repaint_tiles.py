"""A7 п. 7 (D813 «прибрати»): перемальовує атласи плиток DesertTiles.png і DarkTiles.png у стилі світу.

Сітка, розмір плитки (32 px), розклад атласу й роль кожної плитки не змінюються: колізія живе в TileSet (.tres), тут лише
вигляд, і прозорі клітинки лишаються прозорими. Ролі — з розкладу MetSys-автотайла (видно в старому DarkTiles.png):
панель 3×3 з кромками (7..9, 6..8), вертикальна смуга (10, 6..8), одиночні блоки (11/13, 6..8), широка смуга верх/
заповнення/низ (12, 6..8), горизонтальна смуга (7..9, 9) і одиночний (10, 9), верх/низ плити (13..14, 9..10),
заповнення й внутрішні кути (7..10, 10..11; 15, 10..11), фонова кладка без колізії (7..15, 0..5), MetSys-декор
(стовпці 0..6: міст-платформа, капітель зі схилами, колона, шипи).

Матеріали — з уже намальованої землі кімнат (Assets/Backgrounds/Terrain, paint_terrain.py): пісковик каньйону
(Canyon_Terrain, тіло й смуга піщаної поверхні), тесані блоки зали (MayorHall_Terrain) — у масштабі світу ×1.5, як
спрайти землі. Тіло — одна безшовна 32×32 текстура на всі плитки землі (варіанти відрізняються лише серединою), тож
будь-які сусіди сходяться без шва; кромки (поверхня згори, контур і тінь з боків і знизу) малюються лише на відкритих
сторонах плитки. Кладка — блоки зі швами по краю плитки (шов між двома плитками = шов між двома блоками).
Темний набір (печери, інтер'єри, лабораторія) — той самий малюнок, зведений у фіолетову тінь печер, із світлішою
поверхнею, щоб уступи читались.
Запуск з кореня проєкту: python -I Scripts/Tools/repaint_tiles.py  (перемальовує з нуля щоразу; ComfyUI не потрібен).
"""

import io
import subprocess

import numpy as np
from PIL import Image

T = 32
TERR = "SampleProject/Assets/Backgrounds/Terrain/"
OUT = {
    "desert": "SampleProject/Sprites/DesertTiles.png",
    "dark": "SampleProject/Sprites/DarkTiles.png",
}
LAYOUT = "734a8952"  # коміт зі старими (MetSys/Brackeys) атласами — джерело розкладу
SURF = 12  # px поверхні під верхньою кромкою (пісок, видимий трохи згори), далі тінь кромки й тіло
K = 8  # px перехрестного згасання, яким текстура стає безшовною

# Ролі: відкриті сторони (N E S W) плиток землі й кладки; решта клітинок регіону 7..15 × 6..11 — заповнення.
GROUND = {
    (7, 6): "NW",
    (8, 6): "N",
    (9, 6): "NE",
    (7, 7): "W",
    (8, 7): "",
    (9, 7): "E",
    (7, 8): "SW",
    (8, 8): "S",
    (9, 8): "SE",
    (12, 6): "N",
    (12, 7): "",
    (12, 8): "S",
    (7, 10): "",
    (8, 10): "",
    (9, 10): "",
    (10, 10): "",
    (15, 10): "",
    (7, 11): "",
    (8, 11): "",
    (9, 11): "",
    (10, 11): "",
    (15, 11): "",
}
# Кладка: (відкриті сторони, розклад блоків) — ряди (y0, y1, [x стиків]) усередині плитки.
BOND_A = [(0, 16, [12]), (16, 32, [24])]
BOND_B = [(0, 16, [20]), (16, 32, [8])]
BOND_C = [(0, 32, [])]
BOND_D = [(0, 12, [16]), (12, 32, [10, 22])]
MASONRY = {
    (10, 6): ("NEW", BOND_A),
    (10, 7): ("EW", BOND_B),
    (10, 8): ("ESW", BOND_A),
    (11, 6): ("NESW", BOND_C),
    (11, 7): ("NESW", BOND_A),
    (11, 8): ("NESW", BOND_B),
    (13, 6): ("NESW", BOND_D),
    (13, 7): ("NESW", BOND_C),
    (13, 8): ("NESW", BOND_A),
    (7, 9): ("NSW", BOND_A),
    (8, 9): ("NS", BOND_B),
    (9, 9): ("NES", BOND_A),
    (10, 9): ("NESW", BOND_C),
    (13, 9): ("N", BOND_A),
    (14, 9): ("N", BOND_B),
    (13, 10): ("S", BOND_B),
    (14, 10): ("S", BOND_A),
}


def load(name):
    return np.asarray(Image.open(TERR + name).convert("RGBA"), np.float32)


def up15(img):
    """×1.5 «найближчим» — як спрайт землі у світі: зерно текстури плиток = зерно намальованої землі."""
    h, w = img.shape[:2]
    ys, xs = (np.arange(h * 3 // 2) * 2 // 3), (np.arange(w * 3 // 2) * 2 // 3)
    return img[ys][:, xs]


def seamless(crop, axes=(0, 1)):
    """(32+K)-клапоть → 32 безшовних px: останні K px перехресно згасають у перші (перехід 31→0 = 31→32 джерела)."""
    out = crop.copy()
    for ax in axes:
        out = np.moveaxis(out, ax, 0)
        t = ((np.arange(K) + 0.5) / K).reshape(-1, *([1] * (out.ndim - 1)))
        out[:K] = out[:K] * t + out[T : T + K] * (1 - t)
        out = np.moveaxis(out[:T], 0, ax)
    return out


def details(img, outline, seed, pebbles, cracks):
    """Варіант плитки: камінці й волосяні тріщини, як у тілі намальованої землі, — лише в середині (≥ 4 px від краю), тож
    шов з будь-яким сусідом той самий, що й у бази."""
    rng = np.random.default_rng(seed)
    img = img.copy()
    for _ in range(pebbles):
        y, x = rng.integers(5, T - 7, 2)
        img[y : y + 2, x : x + 3] = outline * 2.0  # камінець: темна ямка, світла кромка згори
        img[y - 1, x : x + 3] = np.minimum(img[y - 1, x : x + 3] * 1.25, 255)
    for _ in range(cracks):
        y, x = rng.integers(6, T - 6, 2)
        for _ in range(rng.integers(5, 10)):
            img[y, x] = outline * 1.8
            x, y = x + rng.choice([-1, 1]), int(np.clip(y + rng.integers(0, 2), 4, T - 5))
            x = int(np.clip(x, 4, T - 5))
    return img


def materials():
    canyon = load("Canyon_Terrain.png")[:, 1300:1720, :3]
    # Тіло: пісковик під смугою поверхні; уступ темнішає з глибиною — кожен рядок зводиться до одного середнього.
    body = canyon[272:372].copy()
    body *= (128 / body.mean(axis=(1, 2)))[:, None, None]
    body = up15(np.clip(body, 0, 255))
    # Вікно тіла: шари породи є (рядки різні), тріщин і косих жил немає (мало перепадів уздовж x), а рядки й стовпці
    # через 32 px майже ті самі — перехресне згасання шва майже нічого не розмиває (підібрано перебором вікон).
    base = seamless(body[104 : 104 + T + K, 168 : 168 + T + K])
    base = base.mean(axis=(0, 1)) + (base - base.mean(axis=(0, 1))) * 0.65  # шари тихші: повтор через 32 px не рябить
    outline = np.percentile(body.reshape(-1, 3), 3, axis=0) * 0.55
    # варіант 0 (8,7 — ним залита майже вся земля) — чиста база: камінець у ньому рябів би через кожні 32 px
    variants = [base] + [details(base, outline, s, 1 + s % 2, s % 3 > 0) for s in range(1, 6)]
    # Поверхня: смуга піску над кромкою каньйону (дальній край угорі темніший), стиснута по вертикалі до SURF px.
    band = up15(canyon[243:268])
    rows = np.linspace(0, len(band) - 1, SURF).round().astype(int)
    surf = seamless(band[rows, 60 : 60 + T + K], axes=(1,))
    # Камінь кладки: тесані блоки зали — середина блоку, без швів (шви малюються самі).
    hall = up15(load("MayorHall_Terrain.png")[250:300, 40:300, :3])
    stone = seamless(hall[10 : 10 + T + K, 120 : 120 + T + K])
    stone = stone.mean(axis=(0, 1)) + (stone - stone.mean(axis=(0, 1))) * 0.6
    return dict(
        body=variants,
        surf=surf,
        stone=stone,
        outline=outline,
    )


def wear(side, seed):
    """Скільки px стерто з відкритого краю в кожному рядку (0..3) — край нерівний плавно, як у намальованої землі."""
    rng = np.random.default_rng(seed)
    x = np.arange(T) / T * 2 * np.pi
    v = sum(np.sin(x * f + rng.uniform(0, 6.3)) / f for f in (1, 2, 3))  # цілі частоти: край безшовний на повторі
    return np.round((v - v.min()) / np.ptp(v) * 3).astype(int)


def ground(m, flags, variant, seed):
    rgb = m["body"][variant % len(m["body"])].copy()
    a = np.full((T, T), 255.0)
    yy, xx = np.mgrid[0:T, 0:T]
    top = (
        SURF + 3 if "N" in flags else 0
    )  # стерти можна лише нижче поверхні: верх — лінія колізії
    for s, dist in (("W", xx), ("E", T - 1 - xx)):
        if s in flags:
            w = wear(s, seed + ord(s))[:, None]
            gone = (dist < w) & (yy >= top)
            a[gone] = 0
            d = dist - w
            rgb *= np.where((d >= 1) & (d <= 3), 0.84, 1.0)[..., None]
            rgb[(d == 0) & (yy >= top)] = m["outline"]
    if "S" in flags:
        up = T - 1 - yy
        rgb *= (1 - 0.55 * np.clip(1 - up / 14, 0, 1) ** 1.5)[..., None]
        w = wear("S", seed + 7)[None, :]
        a[up < w] = 0
        rgb[up == w] = m["outline"]
    if "N" in flags:
        t = (np.arange(SURF) / (SURF - 1))[
            :, None, None
        ]  # 0 — дальній край, 1 — ближній
        rgb[:SURF] = m["surf"] * (0.86 + 0.18 * t)
        for d, k in enumerate(
            (0.5, 0.65, 0.8)
        ):  # тінь під ближньою кромкою: поверхня — верх товщі, а не смужка
            rgb[SURF + d] *= k
        for s, x in (
            ("W", 0),
            ("E", T - 1),
        ):  # кінець поверхні на відкритому боці — темніший торець
            if s in flags:
                rgb[:SURF, x] *= 0.6
    return rgb, a


def masonry(m, flags, bond, seed, dim=1.0):
    rng = np.random.default_rng(seed)
    rgb = m["stone"] * dim
    a = np.full((T, T), 255.0)
    out = np.empty_like(rgb)
    mortar = m["outline"] * 1.25
    joint = np.zeros((T, T), bool)
    joint[:, 0] = joint[:, -1] = joint[0] = joint[-1] = (
        True  # пів шва по краю плитки; у сусіда — друга половина
    )
    for y0, y1, xs in bond:
        edges = [0] + xs + [T]
        for x0, x1 in zip(edges[:-1], edges[1:]):
            blk = rgb[y0:y1, x0:x1] * rng.uniform(0.9, 1.08)
            blk[1, 1:-1] *= 1.14  # світло згори-зліва, тінь знизу-справа: блок опуклий
            blk[1:-1, 1] *= 1.07
            blk[-2, 1:-1] *= 0.8
            blk[1:-1, -2] *= 0.88
            out[y0:y1, x0:x1] = blk
            joint[y0:y1, x0] |= x0 > 0
            joint[y0:y1, x1 - 1] |= x1 < T
            joint[y0, x0:x1] |= y0 > 0
            joint[y1 - 1, x0:x1] |= y1 < T
    out[joint] = mortar
    for s, sl in (
        ("N", np.s_[0, :]),
        ("S", np.s_[-1, :]),
        ("W", np.s_[:, 0]),
        ("E", np.s_[:, -1]),
    ):
        if s in flags:
            out[sl] = m["outline"]
    if "N" in flags:
        out[1, 1:-1] = np.minimum(
            out[1, 1:-1] * 1.25, 255
        )  # верхня грань блоку освітлена — край читається
    if "S" in flags:
        out[-6:-1] *= np.linspace(0.95, 0.7, 5)[:, None, None]
    return out, a


def ramp_recolor(src, m, dark_bias):
    """Старий MetSys-декор (міст, капітель зі схилами, колона, шипи): силует (альфа) лишається піксель у піксель —
    схили й половинки збігаються з колізією, — а яскравість переводиться в рампу кольорів пісковику."""
    ramp = np.concatenate(
        [
            m["body"][0].reshape(-1, 3),
            m["surf"].reshape(-1, 3),
            m["stone"].reshape(-1, 3),
        ]
    )
    ramp = ramp[np.argsort(ramp.mean(axis=1))]
    lum = src[..., :3].mean(-1)
    on = src[..., 3] > 0
    lo, hi = np.percentile(lum[on], [2, 98])
    t = np.clip((lum - lo) / max(hi - lo, 1), 0, 1) ** dark_bias
    return ramp[(t * (len(ramp) - 1)).astype(int)], src[..., 3]


def quantize(rgb, alpha, colors=48):
    """Палітра — медіанний переріз самих непрозорих px атласу (кольори прийшли з намальованої землі)."""
    on = np.clip(rgb[alpha > 127], 0, 255).astype(np.uint8)
    side = int(np.ceil(np.sqrt(len(on))))
    sample = np.zeros((side * side, 3), np.uint8)
    sample[: len(on)] = on
    sample[len(on) :] = on[0]
    pal = Image.fromarray(sample.reshape(side, side, 3)).quantize(colors, method=Image.Quantize.MEDIANCUT)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).quantize(palette=pal, dither=Image.Dither.NONE)
    return np.asarray(img.convert("RGB"))


def to_dark(rgb, lift):
    """Темний набір: тінь печер — фіолетова, темна; lift (0..1) — скільки лишити світла (поверхня уступу)."""
    shade = np.array([0.62, 0.46, 0.78]) * rgb * 0.55 + np.array([22, 12, 30])
    warm = rgb * np.array([1.0, 0.66, 0.5])  # поверхня — тепле світло на кромці, як уступи печери під мостом
    k = np.clip(lift, 0, 1)
    return shade * (1 - k) + warm * k


def build(kind, before):
    m = materials()
    old = np.asarray(Image.open(before).convert("RGBA"), np.float32)
    rgb = np.zeros((512, 512, 3), np.float32)
    alpha = np.zeros((512, 512), np.float32)
    lift = np.zeros((512, 512), np.float32)  # для темного набору: де лишити світло

    def put(tx, ty, img, a, lf=0.0):
        rgb[ty * T : ty * T + T, tx * T : tx * T + T] = img
        alpha[ty * T : ty * T + T, tx * T : tx * T + T] = a
        lift[ty * T : ty * T + T, tx * T : tx * T + T] = lf

    for (tx, ty), flags in GROUND.items():
        variant = 0 if flags or (tx, ty) == (8, 7) else 1 + (tx * 7 + ty * 3) % 5
        img, a = ground(m, flags, variant, tx * 31 + ty)
        lf = np.zeros((T, T))
        if "N" in flags:
            lf[:SURF] = 1.0
        put(tx, ty, img, a, lf)
    for (tx, ty), (flags, bond) in MASONRY.items():
        put(tx, ty, *masonry(m, flags, bond, tx * 31 + ty), 0.35)
    # Фонова кладка (без колізії): стіна позаду — темніша за землю, щоб не сперечалась з тим, по чому ходиш. Плитки, де в
    # старому атласі не було цеглин (рівна стіна), — штукатурка кольору каменю кладки з зерном тіла.
    for ty in range(0, 6):
        for tx in range(7, 16):
            tile = old[ty * T : ty * T + T, tx * T : tx * T + T]
            if tile[..., 3].max() == 0:
                continue
            if tile[..., :3].mean(-1).std() < 12:
                lum = m["body"][(tx + ty) % len(m["body"])].mean(axis=-1, keepdims=True)
                img = m["stone"].mean(axis=(0, 1)) * 0.72 * (1 + 0.3 * (lum / lum.mean() - 1))
                put(tx, ty, img, np.full((T, T), 255.0))
            else:
                put(
                    tx,
                    ty,
                    *masonry(
                        m,
                        "",
                        (BOND_A, BOND_B, BOND_D)[(tx + 2 * ty) % 3],
                        tx * 17 + ty,
                        dim=0.72,
                    ),
                )
    # MetSys-декор у стовпцях 0..6 — перефарбування за силуетом.
    left = old[:, : 7 * T]
    img, a = ramp_recolor(left, m, 1.0)
    rgb[:, : 7 * T], alpha[:, : 7 * T] = img, a

    if kind == "dark":
        rgb = to_dark(rgb, lift[..., None] * 0.9)
    q = quantize(rgb, alpha)
    out = np.dstack([np.asarray(q), np.where(alpha > 127, 255, 0).astype(np.uint8)])
    out[out[..., 3] == 0] = 0
    Image.fromarray(out).save(OUT[kind])
    print("repainted", OUT[kind])


if __name__ == "__main__":
    # Розклад (силуети декору, які плитки стіни були цеглою) береться зі старих атласів у git, а не з файлу на диску:
    # повторний запуск дає той самий результат, а не перефарбовує вже перефарбоване.
    for kind in ("desert", "dark"):
        build(
            kind,
            io.BytesIO(
                subprocess.run(
                    ["git", "show", f"{LAYOUT}:{OUT[kind]}"],
                    capture_output=True,
                    check=True,
                ).stdout
            ),
        )
