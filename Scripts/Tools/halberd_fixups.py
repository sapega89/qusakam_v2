"""Ручні правки кадрів алебарди після `comfy_sprite.py hero_weapon_halberd` (арт-директор, друга хвиля).

Запускати з кореня проєкту після кожного перегенерування — інструмент перезаписує кадри.
- Голова алебарди одна на весь набір: мала голова з одним лезом із CombatIdle/1 (модель у горизонтальних і низьких
  позах малювала велику дволезову сокиру). Тут її повернуто RotSprite-ом під кут древка кожного кадру (Scale2x ×8,
  поворот найближчим сусідом, вибірка центрів) і поставлено на місце голови моделі.
- Run/1-7: кадри бігу художника (Run/1, 3-8; Run/2 пропущено, як у меча) + одна незмінна алебарда за спиною — нахил
  29° від вертикалі, голова вгорі позаду; рухається лише з підскоком тіла (модель міняла голову й кут щокадру).
"""

import math

import numpy as np
from PIL import Image

D = "SampleProject/Sprites/Player/Weapons/halberd/"
A, E, F = (
    (0x28, 0x17, 0x24),
    (0x64, 0x34, 0x2D),
    (0x69, 0x21, 0x15),
)  # контур, дерево, тінь дерева


def scale2x(a):
    h, w = a.shape[:2]
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    b, d, e, f, hh = p[:-2, 1:-1], p[1:-1, :-2], p[1:-1, 1:-1], p[1:-1, 2:], p[2:, 1:-1]

    def eq(x, y):
        return (x == y).all(-1)

    c = ~eq(b, hh) & ~eq(d, f)
    o = np.zeros((h * 2, w * 2, a.shape[2]), a.dtype)
    o[0::2, 0::2] = np.where((c & eq(d, b))[..., None], d, e)
    o[0::2, 1::2] = np.where((c & eq(b, f))[..., None], f, e)
    o[1::2, 0::2] = np.where((c & eq(d, hh))[..., None], d, e)
    o[1::2, 1::2] = np.where((c & eq(hh, f))[..., None], f, e)
    return o


# голова з CombatIdle/1 (рядки 14-36, x 63-88), дзеркально: лезо з боку руху за годинниковою стрілкою, тож коли
# голова дивиться вперед, лезо внизу, як у низьких позах; вісь древка — 119° (29° від вертикалі), гніздо (24.0, 36.5)
idle = np.asarray(Image.open(D + "CombatIdle/1.png").convert("RGBA"))
HEAD = np.zeros_like(idle)
HEAD[14:37, 63:89] = idle[14:37, 63:89]
HEAD = HEAD[:, ::-1].copy()
AXIS, ANCHOR = 119.0, (24.0, 36.5)


def head_at(deg):
    """Голова з віссю під кутом deg (проти год. стрілки від +x, y угору); гніздо лишається в ANCHOR."""
    a = HEAD
    for _ in range(3):
        a = scale2x(a)
    big = Image.fromarray(a).rotate(
        deg - AXIS, resample=Image.NEAREST, center=(ANCHOR[0] * 8, ANCHOR[1] * 8)
    )
    return np.asarray(big)[4::8, 4::8]


def replace_head(path, p, deg, box):
    """Стерти в box усе, крім древка моделі до гнізда p (смуга ±2 px уздовж осі), і поставити спільну голову в p.
    box — лише алебарда, без тіла."""
    im = np.asarray(Image.open(D + path).convert("RGBA")).copy()
    ux, uy = math.cos(math.radians(deg)), -math.sin(math.radians(deg))
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            along = (x + 0.5 - p[0]) * ux + (y + 0.5 - p[1]) * uy
            across = abs((x + 0.5 - p[0]) * uy - (y + 0.5 - p[1]) * ux)
            if along >= 0 or across > 2:
                im[y, x] = 0
    h = head_at(deg)
    dx, dy = round(p[0] - ANCHOR[0]), round(p[1] - ANCHOR[1])
    for y, x in zip(*np.nonzero(h[..., 3])):
        if 0 <= y + dy < 96 and 0 <= x + dx < 96:
            im[y + dy, x + dx] = h[y, x]
    Image.fromarray(im).save(D + path)


# кадр: (гніздо — де древко моделі входить у її голову, кут древка до голови, ділянка голови моделі)
HEADS = {
    "Attack1/1.png": ((68, 71.5), 0, (66, 60, 96, 84)),
    "Attack1/2.png": ((71, 62.5), 0, (68, 49, 96, 74)),
    "Attack1/3.png": ((70, 63.5), 0, (68, 52, 96, 75)),
    "Attack2/1.png": ((23, 76.5), 188, (0, 66, 30, 89)),
    "Attack2/2.png": ((69, 75.5), -10, (63, 64, 96, 90)),
    "Attack2/3.png": ((72, 74.5), 0, (64, 61, 96, 90)),
    "Attack3/1.png": ((72, 70.5), 0, (64, 58, 96, 83)),
    "Attack3/2.png": ((75, 65.5), 0, (68, 54, 96, 77)),
    "Attack3/3.png": ((71, 74.5), -23, (62, 62, 96, 90)),
    "Heavy/1.png": ((30, 35.5), 140, (8, 15, 42, 46)),
    "Heavy/2.png": ((73, 62), 24, (66, 46, 96, 74)),
    "Heavy/3.png": ((69, 73.5), -8, (62, 60, 96, 90)),
}
for path, (p, deg, box) in HEADS.items():
    replace_head(path, p, deg, box)


def halberd_sprite(p, butt_y):
    """Алебарда за спиною в бігу: спільна голова в гнізді p під кутом AXIS + древко до рядка butt_y."""
    out = np.zeros((96, 96, 4), np.uint8)
    slope = math.cos(math.radians(AXIS)) / -math.sin(
        math.radians(AXIS)
    )  # x на рядок униз (0.55)
    rows = range(int(p[1]), butt_y + 1)
    for y in rows:  # контур спершу, дерево поверх — сходинки не перекривають одна одну
        x = math.floor(p[0] + slope * (y + 0.5 - p[1]) - 1)
        out[y, x - 1], out[y, x + 2] = A + (255,), A + (255,)
    for y in rows:
        x = math.floor(p[0] + slope * (y + 0.5 - p[1]) - 1)
        out[y, x], out[y, x + 1] = E + (255,), F + (255,)
    x = math.floor(p[0] + slope * (butt_y + 1.5 - p[1]) - 1)
    out[butt_y + 1, x - 1 : x + 3] = A + (255,)  # торець
    h = head_at(AXIS)
    dx, dy = round(p[0] - ANCHOR[0]), round(p[1] - ANCHOR[1])
    for y, x in zip(*np.nonzero(h[..., 3])):
        out[y + dy, x + dx] = h[y, x]
    return out


def head_top(im):
    return int(np.nonzero(np.asarray(im)[..., 3].any(axis=1))[0][0])


RUN = (1, 3, 4, 5, 6, 7, 8)
top0 = head_top(Image.open("SampleProject/Sprites/Player/Run/1.png"))
for i, n in enumerate(RUN):
    body = Image.open("SampleProject/Sprites/Player/Run/%d.png" % n).convert("RGBA")
    bounce = head_top(body) - top0
    frame = Image.fromarray(halberd_sprite((32, 36.5 + bounce), 84 + bounce))
    cell = Image.new("RGBA", (96, 96))
    cell.alpha_composite(
        body, (16, 32)
    )  # як enlarge() у comfy_sprite: знизу посередині клітинки
    frame.alpha_composite(cell)  # тіло поверх древка — алебарда за спиною
    frame.save(D + "Run/%d.png" % (i + 1))
