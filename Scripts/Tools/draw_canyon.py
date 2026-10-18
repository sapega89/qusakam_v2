"""Каньйон (D227, D228): Скеля Прайду (оглядовий навіс з уступами на спині), ущелина зі стінами й уступами,
далекі й нижні стіни каньйону. Піксель-арт у масштабі фону (текстура ×1.5 у грі), палітра пісковику.

Скеля й ущелина збігаються з невидимою колізією з Scripts/Tools/build_canyon.gd:
- скеля: навіс — рядки 3–5, уступи — односторонні полиці (SHELF / LEDGES нижче); картинка — стовпці 33–63,
  рядки 2–12 (x 1056–2016, y 64–384);
- ущелина: схема Scripts/Tools/canyon_gorge.txt (стовпці 0–24, рядки 12–29; картинка з x 0, y 384).
Верх, на який можна стати, має світлу кромку TOP — як помаранчева лінія плато.
Запуск: python Scripts/Tools/draw_canyon.py
"""

import math
import random

from PIL import Image, ImageDraw

OUT = "SampleProject/Assets/Backgrounds/Canyon/"
GORGE_LAYOUT = "Scripts/Tools/canyon_gorge.txt"
TILE = 32

# Пісковик «Короля Лева»: світло, основа, смуга, тінь, глибока тінь; контур; кромка «тут стати».
SAND = [(240, 186, 120), (214, 150, 92), (190, 126, 78), (160, 100, 64), (120, 72, 50)]
EDGE = (84, 50, 40)
TOP = (250, 214, 150)

# Колізія скелі (тайли): ті самі числа, що в build_canyon.gd — (рядок, перший стовпець, останній)
SHELF = [(3, 40, 49), (4, 35, 51), (5, 37, 51)]
LEDGES = [(10, 59, 61), (8, 56, 58), (6, 53, 55)]
ROCK_X0, ROCK_Y0 = 33 * TILE, 2 * TILE
ROCK_W, ROCK_H = round(30 * TILE / 1.5), round(10 * TILE / 1.5)


def organic(points, rng, origin, jitter=5.0, step=10.0):
    """Ламана з опорних точок, густіша й зсунута шумом — нерівний кам'яний обрис; у координати текстури."""
    out = []
    for i in range(len(points)):
        (x0, y0), (x1, y1) = points[i], points[(i + 1) % len(points)]
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
        for k in range(n):
            t = k / n
            j = jitter * (0.3 if k == 0 else 1.0)
            out.append(
                (
                    x0 + (x1 - x0) * t + rng.uniform(-j, j) * 0.4,
                    y0 + (y1 - y0) * t + rng.uniform(-j, j),
                )
            )
    return [((x - origin[0]) / 1.5, (y - origin[1]) / 1.5) for x, y in out]


def shelf_points():
    """Навіс: ніс ліворуч (рядок 4), горб (рядок 3), товщає до спини, брилистий низ."""
    T = TILE
    return [
        (34 * T + 20, 4 * T + 22),
        (36 * T, 4 * T + 2),
        (39 * T, 4 * T - 4),
        (40 * T + 10, 3 * T + 4),
        (44 * T, 3 * T - 6),
        (48 * T, 3 * T - 2),
        (50 * T + 16, 3 * T + 14),
        (52 * T + 10, 4 * T + 20),
        (53 * T, 6 * T),
        (52 * T, 7 * T + 10),
        (49 * T, 7 * T + 2),
        (46 * T, 6 * T + 20),
        (43 * T, 6 * T + 10),
        (40 * T, 6 * T - 2),
        (37 * T, 5 * T + 16),
    ]


def support_points():
    """Масив скелі позаду навісу до землі (декор, без колізії — під навісом прохід). Спина пологіша, ніж
    раніше, щоб уступи на ній не висіли в повітрі, а виходили з каменю."""
    T = TILE
    return [
        (46 * T, 6 * T + 10),
        (52 * T, 5 * T + 20),
        (56 * T, 6 * T + 16),
        (59 * T, 8 * T + 18),
        (62 * T + 8, 10 * T + 20),
        (63 * T + 16, 12 * T),
        (44 * T, 12 * T),
        (45 * T, 10 * T),
        (44 * T + 20, 8 * T),
    ]


def ledge_points(row, c0, c1, depth):
    T = TILE
    top = row * T
    return [
        (c0 * T - 6, top + 2),
        (c0 * T + 6, top - 1),
        ((c1 + 1) * T - 6, top - 1),
        ((c1 + 1) * T + 8, top + 4),
        ((c1 + 1) * T, top + depth * 0.7),
        (c0 * T + 24, top + depth),
        (c0 * T + 4, top + depth * 0.6),
    ]


def strata_color(x, y, top_gap, bottom_gap, shade):
    """Тон пікселя каменю: кромка зверху (TOP), хвилясті шари, тінь знизу; [param shade] — темніше на N тонів."""
    if top_gap < 2:
        return TOP
    band = (y + int(3 * math.sin(x / 23.0))) // 7 % 3
    i = [1, 2, 1][band]
    if top_gap < 4:
        i = 0
    elif bottom_gap < 3:
        i = 4
    elif bottom_gap < 5:
        i = 3
    return SAND[min(i + shade, 4)]


def paint_mask(im, mask_fn, shade=0, cracks=0, rng=None, outside=False):
    """Заливає камінь за маскою mask_fn(x, y) -> bool: шари, кромка, тінь, контур, рідкі горизонтальні тріщини.
    [param outside] — що за межами картинки: True — камінь триває (край без контуру, шов не видно)."""
    w, h = im.size
    px = im.load()
    solid = [[mask_fn(x, y) for x in range(w)] for y in range(h)]

    def at(x, y):
        return solid[y][x] if 0 <= x < w and 0 <= y < h else outside

    for y in range(h):
        for x in range(w):
            if not solid[y][x]:
                continue
            outline = any(not at(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if outline:
                px[x, y] = EDGE + (255,)
                continue
            top_gap = next((k for k in range(1, 6) if not at(x, y - k)), 6)
            bottom_gap = next((k for k in range(1, 6) if not at(x, y + k)), 6)
            px[x, y] = strata_color(x, y, top_gap, bottom_gap, shade) + (255,)
    for _ in range(cracks):  # горизонтальні тріщини по шарах, 2–3 px
        x, y = rng.randrange(w), rng.randrange(h)
        for k in range(rng.randrange(2, 4)):
            if (
                0 <= x + k < w
                and solid[y][x + k]
                and px[x + k, y][:3] not in (EDGE, TOP)
            ):
                px[x + k, y] = SAND[4] + (255,)
    return solid


def polygon_mask(size, polygon):
    m = Image.new("L", size)
    ImageDraw.Draw(m).polygon(polygon, fill=255)
    data = m.load()
    return lambda x, y: data[x, y] > 0


def pride_rock():
    rng = random.Random(3)
    size = (ROCK_W, ROCK_H)
    origin = (ROCK_X0, ROCK_Y0)
    support = Image.new("RGBA", size)
    paint_mask(
        support,
        polygon_mask(size, organic(support_points(), rng, origin, 8.0)),
        shade=1,
        cracks=30,
        rng=rng,
    )
    shelf = Image.new("RGBA", size)
    shelf_solid = paint_mask(
        shelf,
        polygon_mask(size, organic(shelf_points(), rng, origin, 5.0)),
        cracks=25,
        rng=rng,
    )
    # глибока тінь на масиві під навісом
    spx = support.load()
    for y in range(size[1]):
        for x in range(size[0]):
            if spx[x, y][3] and any(
                0 <= y - k < size[1] and shelf_solid[y - k][x] for k in range(1, 12)
            ):
                spx[x, y] = SAND[4] + (255,)
    out = support
    for i, (row, c0, c1) in enumerate(LEDGES):
        ledge = Image.new("RGBA", size)
        depth = (
            18 if i == 0 else 34
        )  # нижній уступ тонкий — не «стеля» над головою на плато
        paint_mask(
            ledge,
            polygon_mask(
                size, organic(ledge_points(row, c0, c1, depth), rng, origin, 2.0, 8.0)
            ),
        )
        out.alpha_composite(ledge)
    out.alpha_composite(shelf)
    out.save(OUT + "pride_rock.png")


def gorge():
    """Ущелина з схеми canyon_gorge.txt: стіни й уступи з пісковику; краї стін трохи нерівні по x, верх — рівний
    (стоїш там, де колізія)."""
    rows = [
        line.rstrip("\n")
        for line in open(GORGE_LAYOUT, encoding="utf-8")
        if not line.startswith("# ")
    ]
    rows = [r for r in rows if r]
    x0, y0 = 0, 12 * TILE
    # +3 стовпці праворуч — край тіла плато стає скельною стіною ущелини
    w, h = math.ceil((len(rows[0]) + 3) * TILE / 1.5), math.ceil(len(rows) * TILE / 1.5)

    def solid_world(wx, wy):
        c, r = int(wx // TILE), int((wy - y0) // TILE)
        if r < 0 or r >= len(rows) or c < 0:
            return False
        if c >= len(rows[r]):
            return True  # праворуч від схеми — тіло плато
        return rows[r][c] == "#"

    def mask(x, y):
        wx, wy = x0 + x * 1.5, y0 + y * 1.5
        jx = 5.0 * math.sin(wy / 9.0 + wx / 31.0) + 3.0 * math.sin(wy / 4.1)
        jy = 6.0 * (0.5 + 0.5 * math.sin(wx / 7.3 + wy / 13.0)) * (0.5 + 0.5 * math.sin(wx / 3.1))
        # верхня смуга кожного виступу рівна (там стоїш), нижче — нерівні край і низ
        on_top = solid_world(wx, wy) and not solid_world(wx, wy - TILE) and (wy - y0) % TILE < TILE * 0.6
        if on_top:
            return solid_world(wx + jx * 0.3, wy)
        return solid_world(wx + jx, wy - jy)

    rng = random.Random(12)
    im = Image.new("RGBA", (w, h))
    paint_mask(im, mask, cracks=120, rng=rng, outside=True)
    im.save(OUT + "gorge.png")


def plateau_body():
    """Тіло плато під верхньою лінією (стовпці 25–80, рядки 13–29): та сама порода, що й ущелина та скеля.
    Тайли під ним лишаються колізією; ліворуч — нерівний край урвища над ущелиною."""
    cols, rows = 56, 17
    w, h = math.ceil(cols * TILE / 1.5), math.ceil(rows * TILE / 1.5)

    def mask(x, y):
        return x > 3 + 2.5 * math.sin(y / 5.0) + 1.5 * math.sin(y / 2.3)

    rng = random.Random(21)
    im = Image.new("RGBA", (w, h))
    paint_mask(im, mask, cracks=160, rng=rng, outside=True)
    px = im.load()
    for x in range(w):  # верх — під помаранчевою лінією плато, без кромки й контуру
        for y in range(4):
            if px[x, y][3]:
                px[x, y] = SAND[1] + (255,)
    im.save(OUT + "plateau_body.png")


def hazed(c, k, sky=(214, 214, 224)):
    return tuple(round(a * (1 - k) + b * k) for a, b in zip(c, sky))


def canyon_walls():
    """Далекі стіни каньйону: мези й урвища з шарами породи, у серпанку; тайлиться по 576 px."""
    w, h = 576, 324
    im = Image.new("RGBA", (w, h))
    px = im.load()
    pal = [hazed(c, 0.45) for c in SAND]
    edge = hazed(EDGE, 0.4)
    tops = []
    for x in range(w):
        t = (
            150
            + 40 * math.sin(x / w * math.tau * 2)
            + 22 * math.sin(x / w * math.tau * 5 + 1.3)
        )
        t += [0, -28, 10, -12][(x // 48) % 4]
        tops.append(int(t))
    for x in range(w):
        for y in range(tops[x], h):
            band = (y + int(2 * math.sin(x / 17.0))) // 9 % 3
            i = 0 if y < tops[x] + 3 else [1, 2, 1][band]
            if (x * 7 + y // 30) % 37 == 0 and y > tops[x] + 6:
                i = 3  # вертикальна тріщина урвища
            edge_px = (
                y == tops[x]
                or (x > 0 and tops[x - 1] > y)
                or (x < w - 1 and tops[x + 1] > y)
            )
            px[x, y] = (edge if edge_px else pal[i]) + (255,)
    im.save(OUT + "canyon_walls.png")


def canyon_depths():
    """Нижні стіни каньйону під плато: та сама порода, темніша з глибиною, вертикальні урвища; тайлиться по 576."""
    w, h = 576, 420
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for x in range(w):
        for y in range(h):
            k = min(1.0, y / h * 1.3)
            band = (y + int(3 * math.sin(x / 19.0 + y / 50.0))) // 11 % 3
            base = SAND[[2, 3, 2][band]]
            c = tuple(round(v * (0.78 - 0.38 * k)) for v in base)
            crack = (x * 7919 + (y // 60) * 131) % 211
            if crack < 2 and math.sin(y / 23.0 + x) > -0.3:
                c = tuple(round(v * 0.7) for v in c)  # рідкі нерівні тріщини урвищ
            px[x, y] = c + (255,)
    im.save(OUT + "canyon_depths.png")


if __name__ == "__main__":
    import os

    os.makedirs(OUT, exist_ok=True)
    pride_rock()
    gorge()
    plateau_body()
    canyon_walls()
    canyon_depths()
    print("drawn", OUT)
