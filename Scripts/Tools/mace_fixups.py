"""Ручні правки кадрів булави після `comfy_sprite.py hero_weapon_mace` (арт-директор, друга хвиля).

Запускати з кореня проєкту після кожного перегенерування — інструмент перезаписує кадри.
- Run/1-7: одна незмінна голова булави (куля з Run/2) на кінці руків'я — модель малювала то кулю, то молот.
- Heavy/1: руків'я обрізано біля задньої руки — модель дорисовувала довгий держак за руками.
"""

from PIL import Image

D = "SampleProject/Sprites/Player/Weapons/mace/"
METAL = {(0xF8, 0xF8, 0xE4), (0xC2, 0xC2, 0xC2), (0x87, 0x87, 0x8C), (0x52, 0x59, 0x6D), (0x3B, 0x38, 0x4B)}


def head_mask(im):
    """Пікселі голови: метал праворуч від морди героя (x >= 68, рядки 38-56) + темний контур навколо."""
    core = {
        (x, y)
        for x in range(68, im.width)
        for y in range(38, 57)
        if im.getpixel((x, y))[3] and im.getpixel((x, y))[:3] in METAL
    }
    mask = set(core)
    for x, y in core:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                p = im.getpixel((x + dx, y + dy))
                if p[3] and (sum(p[:3]) < 120 or p[:3] in METAL):
                    mask.add((x + dx, y + dy))
    # прив'язка — лівий нижній кут металу, там до кулі входить руків'я
    return mask, (min(x for x, _ in core), max(y for _, y in core))


src = Image.open(D + "Run/2.png").convert("RGBA")
src_mask, (sx, sy) = head_mask(src)
head = {(x - sx, y - sy): src.getpixel((x, y)) for x, y in src_mask}
for n in range(1, 8):
    path = D + "Run/%d.png" % n
    im = Image.open(path).convert("RGBA")
    mask, (ax, ay) = head_mask(im)
    for q in mask:
        im.putpixel(q, (0, 0, 0, 0))
    for (dx, dy), p in head.items():
        im.putpixel((ax + dx, ay + dy), p)
    im.save(path)

im = Image.open(D + "Heavy/1.png").convert("RGBA")
for x in range(0, 36):  # задня рука починається з x 36
    for y in range(26, 37):
        im.putpixel((x, y), (0, 0, 0, 0))
im.save(D + "Heavy/1.png")
