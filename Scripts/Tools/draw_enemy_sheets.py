"""Малює листи спрайтів ворогів у стилі героя (D218): чибі-пропорції, темний контур, 3 тони світла згори зліва.

Замість арту з теки «ChatGPT Image…» (D214, походження невідоме). Сітка та сама, що в D214, тож сцени
enemy_tank.tscn / enemy_fast.tscn не змінюються: клітинка 96x72, ступні на нижньому рядку, морда праворуч,
рядки idle / walk / attack / death.
  tank = пустельна черепаха, 4 кадри на рядок; fast = багатоніжка, 6 кадрів (idle / walk / death — 4).
Запуск: python Scripts/Tools/draw_enemy_sheets.py
"""

import math
from PIL import Image

OUT = "SampleProject/Assets/Characters/Enemies/"
CW, CH = 96, 72
GROUND = 71
OUTLINE = (40, 23, 36, 255)  # контур героя
LIGHT = (-0.55, -0.8)

# Палітри: 4 тони від світлого до тіні (як у героя: світло, основа, тінь, глибока тінь).
SKIN = [(244, 206, 138), (231, 181, 123), (175, 135, 89), (122, 88, 60)]
SHELL = [(214, 146, 82), (176, 106, 58), (128, 70, 44), (88, 46, 34)]
SHELL_RIM = [(240, 214, 160), (210, 178, 124), (160, 128, 86), (112, 86, 60)]
CHITIN = [(226, 120, 70), (186, 78, 52), (132, 50, 42), (86, 32, 34)]
BELLY = [(246, 214, 160), (222, 182, 128), (176, 136, 92), (128, 94, 66)]
EYE_IRIS = (190, 38, 30, 255)


class Canvas:
    def __init__(self, w=CW, h=CH):
        self.im = Image.new("RGBA", (w, h))
        self.px = self.im.load()
        self.w, self.h = w, h

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c if len(c) == 4 else c + (255,)

    def part(self, mask, shade, outline=OUTLINE):
        """Малює частину: тон за shade(x, y) -> 0..3, контур по краю маски (поверх того, що під нею)."""
        for x, y in mask:
            edge = any(
                (x + dx, y + dy) not in mask
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            )
            if edge:
                self.put(x, y, outline)
            else:
                self.put(x, y, shade(x, y))


def ellipse(cx, cy, rx, ry, angle=0.0):
    ca, sa = math.cos(angle), math.sin(angle)
    m = set()
    for y in range(int(cy - max(rx, ry)) - 1, int(cy + max(rx, ry)) + 2):
        for x in range(int(cx - max(rx, ry)) - 1, int(cx + max(rx, ry)) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u, v = dx * ca + dy * sa, -dx * sa + dy * ca
            if (u / rx) ** 2 + (v / ry) ** 2 <= 1.0:
                m.add((x, y))
    return m


def lit(cx, cy, rx, ry, pal, bias=0.0):
    """Тон за нормаллю еліпса до світла: 3 смуги + глибока тінь знизу."""

    def f(x, y):
        nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        d = nx * LIGHT[0] + ny * LIGHT[1] + bias
        i = 0 if d > 0.45 else 1 if d > -0.1 else 2 if d > -0.6 else 3
        return pal[i]

    return f


def flat(pal, i=1):
    return lambda x, y: pal[i]


def eye(c, x, y, look=1, closed=False):
    """Кругле чибі-око як у героя: темний обідок, червона райдужка майже на все око, білий блік;
    над ним зла брова, що опускається до носа. (x, y) — верхній лівий кут 6x7."""
    if closed:
        for i in range(6):
            c.put(x + i, y + 4, OUTLINE)
        return
    c.part(ellipse(x + 3, y + 3.5, 3.4, 3.8), lambda px, py: (150, 30, 28) if py < y + 4 else (196, 58, 38))
    c.put(x + 1 + max(look, 0), y + 2, (255, 255, 255))
    c.put(x + 2 + max(look, 0), y + 2, (255, 255, 255))
    c.put(x + 1 + max(look, 0), y + 3, (255, 255, 255))
    for i in range(7):
        c.put(x - 1 + i, y - 2 + i // 3, OUTLINE)


# ── Черепаха (tank) ──────────────────────────────────────────────────────────


def turtle(pose, t):
    """pose: idle / walk / windup / strike / recover / death; t — фаза 0..1 усередині пози."""
    c = Canvas()
    bob = round(math.sin(t * math.tau)) if pose in ("idle", "walk") else 0
    lean = {"windup": -3, "strike": 4, "recover": 1}.get(pose, 0)
    sink = int(t * 10) if pose == "death" else 0
    cx = 44 + lean // 2
    shell_cy = GROUND - 22 + bob + sink
    # ноги — короткі стовпчики, верх ховається під панцир; у ході переступають
    step = math.sin(t * math.tau) * 3 if pose == "walk" else 0
    if pose != "death" or t < 0.5:
        for lx, ph in ((cx - 15, step), (cx + 13, -step)):
            leg = ellipse(lx + ph, GROUND - 9, 6, 10)
            c.part({p for p in leg if p[1] <= GROUND}, lit(lx + ph, GROUND - 9, 6, 10, SKIN))
    # голова на шиї: тягнеться вперед в ударі, ховається в замаху
    head_dx = {"windup": -4, "strike": 10, "recover": 4, "death": -6}.get(pose, 0)
    hx = cx + 26 + head_dx
    hy = shell_cy - 4 + (2 if pose == "windup" else 0) + sink // 2
    nx = (cx + 14 + hx) / 2
    nrx = abs(hx - cx - 14) / 2 + 4
    c.part(ellipse(nx, hy + 5, nrx, 5), lit(nx, hy + 5, nrx, 5, SKIN))
    # панцир: ребро знизу і купол
    c.part(ellipse(cx, shell_cy + 8, 25, 5), lit(cx, shell_cy + 8, 25, 5, SHELL_RIM, 0.2))
    dome = {p for p in ellipse(cx, shell_cy + 6, 24, 20) if p[1] <= shell_cy + 7}
    c.part(dome, lit(cx, shell_cy + 6, 24, 20, SHELL))
    # пластини: обведені тінню овали на куполі
    for (px, py) in [(cx - 10, shell_cy - 6), (cx + 4, shell_cy - 9), (cx - 2, shell_cy + 1),
                     (cx + 13, shell_cy - 1), (cx - 16, shell_cy + 3), (cx + 8, shell_cy + 4)]:
        plate = ellipse(px, py, 6, 4.5)
        for (x, y) in plate:
            if (x, y) in dome and any((x + dx, y + dy) not in plate for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                c.put(x, y, SHELL[3])
    for (x, y) in ellipse(cx - 9, shell_cy - 10, 5, 1.5):  # блік на маківці
        if (x, y) in dome:
            c.put(x, y, SHELL_RIM[0])
    # голова: велика, кругла, чибі
    c.part(ellipse(hx, hy, 10, 9), lit(hx, hy, 10, 9, SKIN))
    eye(c, hx - 1, hy - 6, 1, closed=pose == "death")
    # рот: відкритий в ударі
    if pose == "strike":
        for i in range(5):
            c.put(hx + 6 + i // 2, hy + 4 + (i % 2), OUTLINE)
        for (x, y) in ellipse(hx + 8, hy + 4, 2.2, 1.4):
            c.put(x, y, (120, 30, 36))
    else:
        for i in range(5):
            c.put(hx + 5 + i, hy + 4, OUTLINE)
    if pose == "death":
        _fade(c, 1.0 - t * 0.85)
    return c.im


# ── Багатоніжка (fast) ───────────────────────────────────────────────────────


def centipede(pose, t):
    c = Canvas()
    n = 6
    wave = t * math.tau
    rear = {"windup": -6, "strike": 8, "recover": 3}.get(pose, 0)
    sink = int(t * 8) if pose == "death" else 0
    segs = []
    for i in range(n):
        x = 14 + i * 9 + (rear * i / (n - 1))
        amp = 2 if pose == "walk" else 1 if pose == "idle" else 0
        y = GROUND - 10 - round(math.sin(wave + i * 0.9) * amp) + sink
        if pose == "windup":
            y -= int(i * i * 0.7)  # передні сегменти здіймаються, як кобра
        elif pose == "strike":
            y -= int(i * 0.6)
        segs.append((x, y))
    body = segs[:-1]
    # ніжки: косі, по дві на сегмент, кінчики світлі; у ході — переступають
    if pose != "death" or t < 0.4:
        for i, (x, y) in enumerate(body):
            if y < GROUND - 16:
                continue  # піднятий сегмент — ніжки в повітрі не малюємо
            k = (1 if (i + int(t * 4)) % 2 == 0 else -1) if pose == "walk" else 0
            for dx in (-3, 2):
                x0, x1 = x + dx, x + dx - 2 + k
                for yy in range(y + 4, GROUND + 1):
                    f = (yy - y - 4) / max(GROUND - y - 4, 1)
                    c.put(round(x0 + (x1 - x0) * f), yy, OUTLINE)
                c.put(x1, GROUND, CHITIN[0] + (255,))
    # сегменти від хвоста до голови, через один — темніша смуга
    for i, (x, y) in enumerate(body):
        r = 6 if i else 5
        pal = CHITIN if i % 2 else [CHITIN[1], CHITIN[2], CHITIN[3], OUTLINE[:3]]
        c.part(ellipse(x, y, r + 0.5, 7), lit(x, y, r + 0.5, 7, pal))
        for (px, py) in ellipse(x, y + 5, r - 2, 1.4):
            c.put(px, py, BELLY[1])
        c.put(x - 1, y - 4, CHITIN[0] + (255,))
        c.put(x, y - 4, CHITIN[0] + (255,))
    hx, hy = segs[-1]
    hx += 5
    hy -= 4
    # вусики назад-угору
    for i in range(8):
        c.put(hx - 2 - i // 2, hy - 8 - i, OUTLINE)
    head = ellipse(hx, hy, 9, 8)
    c.part(head, lit(hx, hy, 9, 8, CHITIN))
    eye(c, hx - 1, hy - 5, 1, closed=pose == "death")
    # жвала: два серпи, розкриті в замаху, зімкнені в ударі
    open_ = {"windup": 3, "strike": 0, "recover": 1}.get(pose, 2)
    for k in (-1, 1):
        y0 = hy + 3 + (1 if k > 0 else 0)
        for i in range(5):
            yy = y0 + k * (open_ - (i * open_) // 4) if open_ else y0 + k * (1 if i < 2 else 0)
            c.put(hx + 7 + i, yy, (250, 236, 200, 255))
            c.put(hx + 7 + i, yy + k, OUTLINE)
    if pose == "death":
        _fade(c, 1.0 - t * 0.85)
    return c.im


def _fade(c, alpha):
    for y in range(c.h):
        for x in range(c.w):
            r, g, b, a = c.px[x, y]
            if a:
                c.px[x, y] = (r, g, b, int(a * alpha))


def sheet(draw, rows, cols):
    out = Image.new("RGBA", (cols * CW, len(rows) * CH))
    for y, frames in enumerate(rows):
        for x, (pose, t) in enumerate(frames):
            out.alpha_composite(draw(pose, t), (x * CW, y * CH))
    return out


def loop(pose, k):
    return [(pose, i / k) for i in range(k)]


# Кадри атаки збігаються з ключами анімацій у сценах (tank: 0 / 0.35 / 0.7 / 0.82 с; fast: 6 рівних).
TANK = [
    loop("idle", 4),
    loop("walk", 4),
    [("windup", 0), ("windup", 1), ("strike", 0), ("recover", 0)],
    [("death", i / 3) for i in range(4)],
]
FAST = [
    loop("idle", 4),
    loop("walk", 4),
    [
        ("windup", 0),
        ("windup", 1),
        ("windup", 1),
        ("strike", 0),
        ("strike", 0),
        ("recover", 0),
    ],
    [("death", i / 3) for i in range(4)],
]

if __name__ == "__main__":
    sheet(turtle, TANK, 4).save(OUT + "battle_turtle/sheet.png")
    sheet(centipede, FAST, 6).save(OUT + "centipede/sheet.png")
    print("drawn", OUT)
