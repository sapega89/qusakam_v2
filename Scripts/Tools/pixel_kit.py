"""Спільні пензлі піксель-арту в стилі героя (контур героя, світло зліва-згори) для генераторів
Scripts/Tools/draw_*.py: полотно з контуром по краю частини, еліпс-маска, тон за нормаллю еліпса.
Раніше жили в draw_enemy_sheets.py разом із черепахою й багатоніжкою (D218, замінені паком у D229).
"""

import math
from PIL import Image

CW, CH = 96, 72  # полотно за замовчуванням
OUTLINE = (40, 23, 36, 255)  # контур героя
LIGHT = (-0.55, -0.8)


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
