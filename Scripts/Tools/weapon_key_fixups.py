"""Ключ палітри зброї (BACKLOG 42, палітрова заміна) — лише на металі зброї в кадрах героя.

Метал зброї у всіх наборах `SampleProject/Sprites/Player/Weapons/<тип>` намальовано трьома кольорами меча
(`#F8F8E4`, `#C2C2C2`, `#87878C`); шейдер `SampleProject/Shaders/weapon_palette.gdshader` перефарбовує саме їх під
предмет (мідь, срібло, кристал). Але ті самі три кольори є і в броні героя (нагрудник, наручі) та у відблиску ока — їх
шейдер перефарбував би теж. Тут такі пікселі зсуваються на 2 одиниці RGB (`BODY_TWIN`, оком не видно), і ключ лишається
тільки на зброї.

Що зброя, а що тіло — за зв'язними плямами ключових кольорів (8-сусідство):
- зброя — пляма, що межує більше з контуром / прозорістю, ніж з тілом (сталь броні `#52596D`, `#3B384B` важить 0.3:
  нею ж затінено голови булав), і лежить переважно поза тулубом (рамка під найбільшою плямою шкіри — головою);
  довга (від 12 px) може заходити в тулуб;
- тонка довга пляма (від 7 px, не товща за 2.5 px у середньому) — лезо, де б вона не була;
- решта — тіло.
Залишки, які евристика не бере (B105: шип кінця древка алебарди під тулубом, кинджал dual, притиснутий до грудей,
клинки dual/Air/3, намальовані не ключовими кольорами, наплічник у sword/Attack3/2), правлять ручні прямокутники
`MANUAL` після евристики (design/cloud_reports/art-fixes-wire.md).

Запускати з кореня проєкту після `comfy_sprite.py hero_weapon_<тип>` і ручних правок (`*_fixups.py`) — інструмент
перезаписує кадри; повторний запуск нічого не змінює.
    python Scripts/Tools/weapon_key_fixups.py
"""

import glob
import os

from PIL import Image

SETS = ["sword", "dagger", "mace", "halberd", "dual"]
ROOT = "SampleProject/Sprites/Player/Weapons/"
KEY = [(0xF8, 0xF8, 0xE4), (0xC2, 0xC2, 0xC2), (0x87, 0x87, 0x8C)]
BODY_TWIN = {k: (k[0] - 2, k[1] - 2, k[2] - 2) for k in KEY}
OUTLINE = {
    (0x28, 0x17, 0x24),
    (0x02, 0x01, 0x00),
    (0x26, 0x18, 0x25),
    (0x20, 0x03, 0x06),
    (0x2E, 0x11, 0x15),
}
ARMOUR = {(0x52, 0x59, 0x6D), (0x3B, 0x38, 0x4B)}
ARMOUR_WEIGHT = 0.3
SKIN = {(0xF4, 0xCE, 0x8A), (0xE7, 0xB5, 0x7B), (0xEE, 0xC8, 0x7D), (0xAF, 0x87, 0x59)}


def blobs(px, size, colours, neighbours):
    w, h = size
    seen, out = set(), []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or px[x, y][3] == 0 or px[x, y][:3] not in colours:
                continue
            stack, blob = [(x, y)], []
            seen.add((x, y))
            while stack:
                a, b = stack.pop()
                blob.append((a, b))
                for dx, dy in neighbours:
                    n = (a + dx, b + dy)
                    if (
                        0 <= n[0] < w
                        and 0 <= n[1] < h
                        and n not in seen
                        and px[n][3]
                        and px[n][:3] in colours
                    ):
                        seen.add(n)
                        stack.append(n)
            out.append(blob)
    return out


N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy]


def torso(px, size):
    """Рамка тулуба: під головою (найбільша пляма шкіри), трохи ширша за неї."""
    head = max(blobs(px, size, SKIN, N4), key=len)
    xs = [p[0] for p in head]
    ys = [p[1] for p in head]
    return min(xs) - 4, max(ys) - 2, max(xs) + 2, max(ys) + 22


def is_weapon(px, size, blob, box):
    w, h = size
    inside_blob = set(blob)
    body = other = 0.0
    for a, b in blob:
        for dx, dy in N4:
            n = (a + dx, b + dy)
            if n in inside_blob:
                continue
            if not (0 <= n[0] < w and 0 <= n[1] < h) or px[n][3] == 0 or px[n][:3] in OUTLINE:
                other += 1
            elif px[n][:3] in ARMOUR:
                body += ARMOUR_WEIGHT
            else:
                body += 1
    xs = [p[0] for p in blob]
    ys = [p[1] for p in blob]
    extent = max(max(xs) - min(xs), max(ys) - min(ys)) + 1
    inside = sum(1 for p in blob if box[0] <= p[0] <= box[2] and box[1] <= p[1] <= box[3]) / len(blob)
    sized = (len(blob) >= 5 and extent >= 4) or (inside == 0 and len(blob) >= 2 and min(ys) < box[3])
    placed = inside < 0.5 or (extent >= 12 and inside < 0.85)
    thin = extent >= 7 and len(blob) <= 2.5 * extent
    return (body <= other and sized and placed) or thin


WEAPON = {v: k for k, v in BODY_TWIN.items()}
# B105: кадр → [(прямокутник x0, y0, x1, y1 включно, заміна кольорів)]. WEAPON повертає двійника тіла в ключ (зброя),
# BODY_TWIN зсуває ключ у двійника (тіло); інші пари — не ключові кольори клинка, які шейдер пропускав.
OFF_KEY_BLADE = {(0xFC, 0xF3, 0xD5): KEY[0], (0xC0, 0xC0, 0xC0): KEY[1]}
MANUAL = {
    "halberd/Air/1": [((60, 79, 61, 80), WEAPON)],
    "halberd/Block/1": [((56, 84, 58, 86), WEAPON)],
    "halberd/CombatIdle/1": [((40, 84, 42, 87), WEAPON)],
    "halberd/CombatIdle/2": [((40, 84, 42, 87), WEAPON)],
    "halberd/CombatIdle/3": [((40, 84, 42, 87), WEAPON)],
    "halberd/CombatIdle/4": [((40, 84, 42, 87), WEAPON)],
    "dual/Heavy/1": [((49, 71, 68, 72), WEAPON)],
    "dual/Run/7": [((50, 77, 68, 84), WEAPON)],
    "dual/Air/3": [
        ((64, 40, 79, 64), WEAPON | OFF_KEY_BLADE | {(0xF4, 0xCE, 0x8A): KEY[2]}),
        ((43, 73, 60, 81), OFF_KEY_BLADE),
    ],
    "sword/Attack3/2": [((41, 59, 48, 62), BODY_TWIN)],
    # H3 (пози навичок руху): лезо LungeCut/1 перетинає ногу — евристика взяла його тілом; решта — відблиск ока,
    # нагрудник, наруч, чоботи в ключових кольорах
    "sword/LungeCut/1": [
        ((48, 72, 79, 87), WEAPON),
        ((38, 68, 40, 69), BODY_TWIN),
        ((37, 80, 42, 82), BODY_TWIN),
    ],
    "sword/ShieldCharge/1": [
        ((53, 50, 55, 51), BODY_TWIN),
        ((46, 70, 53, 73), BODY_TWIN),
    ],
    "sword/ShieldCharge/2": [((49, 62, 56, 65), BODY_TWIN)],
    "sword/ShieldCharge/3": [((50, 63, 56, 66), BODY_TWIN)],
    "sword/LeapSlam/2": [((52, 48, 53, 48), BODY_TWIN)],
    "sword/LeapSlam/3": [((57, 47, 57, 48), BODY_TWIN)],
    "dagger/LungeCut/1": [
        ((50, 75, 70, 85), WEAPON),
        ((39, 63, 41, 66), BODY_TWIN),
        ((39, 81, 42, 83), BODY_TWIN),
    ],
    "dagger/ShieldCharge/1": [
        ((70, 61, 70, 62), WEAPON),
        ((55, 51, 55, 52), BODY_TWIN),
        ((48, 61, 54, 64), BODY_TWIN),
    ],
    "dagger/ShieldCharge/2": [((49, 62, 55, 66), BODY_TWIN)],
    "dagger/ShieldCharge/3": [((40, 81, 42, 83), BODY_TWIN)],
    "dagger/LeapSlam/2": [((41, 57, 42, 59), BODY_TWIN), ((56, 75, 60, 81), BODY_TWIN)],
    # булава: куля LungeCut/1–2 торкається тіла — евристика взяла її тілом
    "mace/LungeCut/1": [
        ((61, 72, 71, 83), WEAPON),
        ((39, 63, 41, 66), BODY_TWIN),
        ((39, 81, 42, 83), BODY_TWIN),
    ],
    "mace/LungeCut/2": [((66, 73, 75, 83), WEAPON)],
    "mace/ShieldCharge/1": [((55, 51, 55, 52), BODY_TWIN), ((46, 71, 53, 74), BODY_TWIN)],
    "mace/ShieldCharge/2": [((49, 62, 55, 65), BODY_TWIN)],
    "mace/ShieldCharge/3": [((55, 61, 63, 63), BODY_TWIN), ((40, 81, 42, 83), BODY_TWIN)],
    "mace/LeapSlam/2": [((38, 45, 40, 47), BODY_TWIN), ((46, 67, 53, 70), BODY_TWIN)],
    "mace/LeapSlam/3": [((53, 65, 56, 71), BODY_TWIN)],
    "halberd/ShieldCharge/1": [((44, 59, 51, 62), BODY_TWIN), ((44, 69, 51, 72), BODY_TWIN)],
}


def fix(path):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    before = im.copy().load()
    box = torso(px, im.size)
    for blob in blobs(px, im.size, set(KEY), N8):
        if is_weapon(px, im.size, blob, box):
            continue
        for p in blob:
            c = px[p]
            px[p] = BODY_TWIN[c[:3]] + (c[3],)
    frame = os.path.relpath(path, ROOT)[:-4].replace(os.sep, "/")
    for (x0, y0, x1, y1), swap in MANUAL.get(frame, []):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                c = px[x, y]
                if c[3] and c[:3] in swap:
                    px[x, y] = swap[c[:3]] + (c[3],)
    w, h = im.size
    moved = sum(1 for y in range(h) for x in range(w) if px[x, y] != before[x, y])
    if moved:
        im.save(path)
    return moved


if __name__ == "__main__":
    for kind in SETS:
        total = sum(fix(p) for p in sorted(glob.glob(os.path.join(ROOT, kind, "*", "*.png"))))
        print(kind, "pixels changed:", total)
