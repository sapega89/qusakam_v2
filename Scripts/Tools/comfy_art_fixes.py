"""Точкові виправлення готових кадрів (remaining_work Art 3-4): кадр-джерело — з коміту SRC_REV (тож повторний запуск
бере той самий референс і кеш comfy_sprite), модель (Qwen-Image-Edit-2511, через comfy_sprite.edit) міняє лише позу
або деталь, результат зводиться до палітри цільового листа (кольори не пливуть), ступні — на рядок джерела, і
кадр лягає в ту саму клітинку листа (або в новий лист stagger.png поряд).
Запуск: python -I -B Scripts/Tools/comfy_art_fixes.py <завдання ...>   (COMFY_MAX=4 — не більше 4 картинок)
"""

import hashlib
import io
import os
import subprocess
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import comfy_backdrop as cb  # noqa: E402
import comfy_sprite as cs  # noqa: E402

SRC_REV = "1c049fbf"
KEEP = cs.KEEP
NPC = "SampleProject/Assets/Characters/NPCs/"
BOSS = "SampleProject/Assets/Characters/Bosses/"
ENEMY = "SampleProject/Assets/Characters/Enemies/"
HERO = "SampleProject/Sprites/Player/Weapons/"
C = cs.CHARACTERS

DAGGER_WHO = C["hero_weapon_dagger"]["who"]
# кинджал над головою модель тричі видовжувала до меча — довжину названо рукою (як у кинджала дворучного бою)
TINY = (
    "; the dagger tiny, its blade only as long as his hand, a small knife, not a sword, the same short dagger as in "
    "the picture with the same small steel cross-guard and brown grip, only one dagger, the hero the same size, facing right"
)
DJINN_LEGS = (
    "he has no legs and no feet: below the waist only the same column of dark smoke ending in a flame, hanging "
    "straight down; the whole body in the picture, the same size, in the same side view facing right: "
)


def hero(anim, i):
    return (HERO + "dagger/%s/%d.png" % (anim, i), None)


def cell(sheet, col, row, w, h):
    return (sheet, (col * w, row * h, w, h))


# src / out: (png, box або None — увесь файл); out_index — клітинка нового листа (stagger.png)
JOBS = {}


def job(name, src, out, pose, who, seed, size, up=16, palette=None, bob=None, src_wt=False, erase=(), twin=()):
    """src_wt — джерело з робочого дерева (кадр, щойно зроблений попереднім завданням); erase — прямокутники
    (x0, y0, x1, y1) готового кадру, що стають прозорими (ручне прибирання сміття моделі); twin — прямокутники, де
    ключові кольори металу зброї — тіло (відблиск ока, пояс): зсув на BODY_TWIN, як у weapon_key_fixups.py, якого
    евристика тут не взяла."""
    JOBS[name] = dict(
        src=src,
        out=out,
        pose=pose,
        who=who,
        seed=seed,
        size=size,
        up=up,
        palette=palette,
        bob=bob,
        src_wt=src_wt,
        erase=erase,
        twin=twin,
    )


# --- кинджал: Heavy (3) і Attack2/2-3 з кадру уколу Attack1/2, де кинджал короткий ---
for n, pose in enumerate(
    [
        # спроби 1-2 (кинджал над головою, зерна 52, 53) — лезо завдовжки з меч: замах — кинджал біля вуха
        "in the same side view facing right: winding up a heavy stab, his dagger hand drawn back beside his ear at "
        "head height, elbow raised, the short blade pointing forward, his other hand empty and open, held forward, "
        "knees bent, the cape hanging behind him; the dagger blade no longer than his head is wide",
        "in the same side view facing right: a heavy downward stab, his dagger arm swung down hard in front of him, "
        "the short blade pointing down and forward at the height of his knees, leaning forward on his bent front "
        "leg, the cape flying behind him; the dagger blade no longer than his head is wide",
        "in the same side view facing right: recovering after the heavy stab, crouched on bent knees, the dagger "
        "pulled back in front of his chest, the short blade pointing forward, the cape hanging behind him",
    ],
    1,
):
    job(
        "dagger_heavy%d" % n,
        hero("Attack1", 2),
        (HERO + "dagger/Heavy/%d.png" % n, None),
        pose + TINY,
        DAGGER_WHO,
        {1: 54, 2: 53, 3: 52}[n],  # спроба 1 (зерно 52): Heavy/1 — лезо з меч і другий ніж, Heavy/2 — лезо з меч
        (96, 96),
        12,
        "hero",
        twin={2: ((57, 49, 58, 51),), 3: ((45, 71, 52, 73),)}.get(n, ()),  # відблиск ока; пояс
    )
for n, pose in (
    (
        2,
        "in the same side view facing right: an upward slash rising out of a crouch, his dagger arm swung forward "
        "and up to the height of his shoulder, the short blade pointing forward and up, standing up on his front "
        "leg, the cape flying behind him",
    ),
    (
        3,
        "in the same side view facing right: finishing the upward slash, standing tall, his dagger arm raised in "
        "front of his face, the short blade pointing up, the cape hanging behind him",
    ),
):
    job(
        "dagger_attack2_%d" % n,
        hero("Attack1", 2),
        (HERO + "dagger/Attack2/%d.png" % n, None),
        pose + TINY,
        DAGGER_WHO,
        52,
        (96, 96),
        12,
        "hero",
        # Attack2/3: сіра закарлючка праворуч від кулака («іскра» моделі, пришита до силуету) — геть
        erase=((66, 44, 96, 60), (62, 50, 67, 51), (61, 51, 67, 53), (60, 53, 63, 54)) if n == 3 else (),
        twin=((47, 39, 49, 41),) if n == 3 else (),  # відблиск ока
    )
# Heavy/1 (зерно 54): кинджал за головою вдався, але в передній руці лишився обрубок леза з кадру уколу — прибрано
job(
    "dagger_heavy1_clean",
    (HERO + "dagger/Heavy/1.png", None),
    (HERO + "dagger/Heavy/1.png", None),
    "keeping exactly the same pose, the same short dagger drawn back behind his head, the same size and position "
    "as in the picture; only remove the small white blade from his front hand: his front hand is an open empty "
    "hand held forward with no weapon in it",
    DAGGER_WHO,
    53,  # спроба 1 (зерно 52): на маківці виріс білий клапоть
    (96, 96),
    12,
    "hero",
    src_wt=True,
)

# --- дворучний бій: Hurt з CombatIdle (гра досі брала sword/Hurt) ---
job(
    "dual_hurt",
    (HERO + "dual/CombatIdle/1.png", None),
    (HERO + "dual/Hurt/1.png", None),
    "in the same side view facing right: recoiling from a hard hit to the chest, his body bent backwards, head "
    "thrown back, eyes squeezed shut, staggering back on one foot, the full-length sword still in his near fist "
    "pointing down and back, the short dagger in his far fist "
    + cs.DUAL_REVERSE
    + cs.DUAL_TWO,
    cs.DUAL_WHO,
    52,
    (96, 96),
    12,
    "hero",
)

# --- алхімік: довга чорна маска читалась як борода. Спроба 1 (коротка чорна маска до підборіддя) усе ще читалась
# як коротка борода поруч із Маліком — світло-сіра хірургічна маска з ремінцем до вуха читається маскою одразу ---
ALC = NPC + "alchemist/sheet.png"
MASK = (
    "keeping exactly the same pose, body, coat, apron, syringe, size and position as in the picture; only change "
    "his face: instead of the long black cloth he now wears a short pale grey cloth surgical mask over his mouth and "
    "nose, tied with a thin dark strap that runs back to his ear, the mask ending at his chin, no beard and nothing "
    "hanging below his chin, his pale neck and the coat collar visible under his chin"
)
for name, col, row in (
    ("idle", 0, 0),
    ("walk0", 0, 1),
    ("walk1", 1, 1),
    ("walk2", 2, 1),
    ("walk3", 3, 1),
    ("inject", 0, 2),
    ("front", 0, 3),
):
    job(
        "alchemist_" + name,
        cell(ALC, col, row, 64, 96),
        cell(ALC, col, row, 64, 96),
        MASK
        + (", the front view, both goggle lenses visible" if name == "front" else ""),
        C["alchemist"]["who"].replace(
            "the black cloth mask over his mouth",
            "the short pale grey cloth surgical mask over his mouth and nose",
        ),
        39,
        (64, 96),
    )
job(
    "alchemist_idle_bob",
    cell(ALC, 0, 0, 64, 96),
    cell(ALC, 1, 0, 64, 96),
    None,
    None,
    0,
    (64, 96),
    bob=56,
)
job(
    "alchemist_front_bob",
    cell(ALC, 0, 3, 64, 96),
    cell(ALC, 1, 3, 64, 96),
    None,
    None,
    0,
    (64, 96),
    bob=56,
)

# --- жриця: зайва блакитна палиця ліворуч під руками в кадрах молитви. Модель (зерно 21, «remove the thin
# pale-blue stick…») лишала її на місці — стерто прямокутником: палиця — x 18-23, y 58-79 клітинки, лівий контур
# мантії — стовпець 24 (не зачеплено), поділ — від рядка 80 (не зачеплено); кадри дихання (BOB:56) ті самі внизу
PRI = NPC + "priest/sheet.png"
for col in range(4):
    job("priest_work%d" % col, cell(PRI, col, 2, 64, 96), cell(PRI, col, 2, 64, 96), None, None, 0, (64, 96),
        erase=((0, 58, 24, 80),))

# --- дід: у idle посох у ближній руці, у кадрах люльки — у дальній; idle перемальовано з кадру люльки ---
OLD = NPC + "old_man/sheet.png"
job(
    "old_man_idle",
    cell(OLD, 0, 1, 64, 96),
    cell(OLD, 0, 0, 64, 96),
    "keeping exactly the same character, robe, hood, staff, size and position as in the picture, still leaning on "
    "the same walking staff with the same hand exactly as in the picture; only now standing idle with no pipe: his "
    "other hand empty and resting at his side, his eyes open, looking ahead to the right",
    C["old_man"]["who"],
    8,
    (64, 96),
)
job(
    "old_man_idle_bob",
    cell(OLD, 0, 0, 64, 96),
    cell(OLD, 1, 0, 64, 96),
    None,
    None,
    0,
    (64, 96),
    bob=50,
)

# --- джин: кадр смерті 0 читався як idle ---
DJ = BOSS + "fire_djinn/sheet.png"
job(
    "djinn_death0",
    cell(DJ, 0, 0, 96, 112),
    cell(DJ, 0, 4, 96, 112),
    DJINN_LEGS
    + "dying: thrown backwards by a fatal blow, his head flung back, his arms flung wide open to both "
    "sides, his mouth open in a scream, his flame hair shrunk to small dim flickers, dark cracks across his chest",
    C["fire_djinn"]["who"],
    33,
    (96, 112),
)

# --- стагер (по два кадри, новий лист stagger.png поруч із sheet.png, та сама клітинка й лінія ніг) ---
STAG = [
    "staggered by a heavy blow: knocked off balance, leaning far back, his head jerked back, his arms thrown out "
    "to the sides, stumbling back on one foot",
    "still staggered and dazed, hunched forward with his head down, his arms hanging low, his knees buckling",
]
for who_key, sheet, w, h, src_box, seed, up in (
    ("bandit", ENEMY + "bandit/sheet.png", 64, 64, (0, 0), 2, 16),
    ("brass_collector", BOSS + "brass_collector/sheet.png", 96, 112, (0, 0), 31, 16),
    ("fire_djinn", BOSS + "fire_djinn/sheet.png", 96, 112, (0, 0), 33, 16),
):
    for k, pose in enumerate(STAG):
        if who_key == "bandit":
            if k == 1:  # спроба 1 («hunched forward … knees buckling») — той самий idle: поза сильніша
                pose = (
                    "dazed after a heavy blow: doubled over, bent forward at the waist, his head hanging down low, "
                    "his free hand clutching his stomach, the scimitar pointing down with its tip on the ground"
                )
            pose = (
                "in the same side view facing right: "
                + pose
                + ", the scimitar still in his hand"
                + cs.ARCHER_SCARF
            )
        elif who_key == "fire_djinn":
            pose = DJINN_LEGS + pose.replace(
                "stumbling back on one foot", "his smoke tail swaying back"
            )
            if k == 0:  # спроба 1 (руки врозтіч, голова назад) — двійник нового кадру смерті 0: інший силует
                pose = DJINN_LEGS + (
                    "reeling from a heavy blow: his body twisted away to the left, one forearm raised in front of "
                    "his face as if shielding it, the other arm held low and bent, his head turned down and away, "
                    "his flame hair blown back"
                )
        else:
            pose = "in the same side view facing right: " + pose.replace(
                "his", "its"
            ).replace("he ", "it ")
        out = ENEMY if who_key == "bandit" else BOSS
        job(
            "stagger_%s%d" % (who_key, k),
            cell(sheet, *src_box, w, h),
            (out + who_key + "/stagger.png", (k * w, 0, w, h)),
            pose,
            C[who_key]["who"],
            seed,
            (w, h),
            up,
        )
# шакал — кадр Crusenho (48x48 у клітинці 96x72), опис словами
for who_key, who, poses in (
    (
        "jackal",
        "the same small spotted brown hyena-like jackal with the dark muzzle and dark legs",
        [
            # спроба 1 («knocked back on its hind legs … head jerked up and back») — стає дибки й дивиться ліворуч
            "in the same side view facing right: staggered by a heavy blow, pushed back onto its haunches, its "
            "hindquarters low, its front legs stiff and braced forward, its head jerked up but still facing right, "
            "its snout pointing up to the right",
            "in the same side view facing right: dazed, its head hanging low to the ground, its legs splayed and "
            "wobbling, its tail tucked down",
        ],
    ),
):
    sheet = ENEMY + who_key + "/sheet.png"
    for k, pose in enumerate(poses):
        job(
            "stagger_%s%d" % (who_key, k),
            cell(sheet, 0, 0, 96, 72),
            (ENEMY + who_key + "/stagger.png", (k * 96, 0, 96, 72)),
            pose + ", the same tiny size, the same pixel art style",
            who,
            41,
            (96, 72),
        )
# скорпіон: дві спроби моделі (зерна 41, 42) — поза моделлю пака: друга клешня кільцем, око на клешні, видовжене
# тіло. Стагер — його ж кадри смерті 1-2 (хвіст осідає; Crusenho, CC BY 4.0), лише скопійовані в stagger.png
for k in range(2):
    job("stagger_scorpion%d" % k, cell(ENEMY + "scorpion/sheet.png", 1 + k, 3, 96, 72),
        (ENEMY + "scorpion/stagger.png", (k * 96, 0, 96, 72)), None, None, 0, (96, 72))


# --- зала боса: руни на стіні читались латиницею (DPOB над піччю, кільця обабіч) — перемальовано лише їхні
# прямокутники схваленої картинки з кешу comfy_backdrop (denoise 0.65), підказка шару в comfy_backdrop.py — нова ---
RUNES_OLD = "a ring of carved runes on the wall glowing faint orange"
# спроба 1 («abstract glyphs: circles, dots, crescents, zigzags…», denoise 0.75): кільце розпалось на великі
# блискавки й «Z», над піччю — «M●C●M» — клинопис (клини не схожі на літери), denoise 0.65 тримає кільце
RUNES_NEW = (
    "a ring of small carved cuneiform wedge marks on the wall glowing faint orange, clusters of tiny triangular "
    "wedges, no letters"
)


def box_repaint(img, box, text, seed, height, denoise, edge=24):
    """Перемальовує прямокутник box (px генерації) картинки шару; м'який край edge."""
    x0, y0, x1, y1 = box
    x, y = np.arange(cb.GW), np.arange(height)
    rx = np.clip(np.maximum(x0 - x, x - x1) / edge, 0, 1)
    ry = np.clip(np.maximum(y0 - y, y - y1) / edge, 0, 1)
    ramp = np.maximum(ry[:, None], rx[None, :])  # 0 — прямокутник, 1 — поза ним
    alpha = (ramp * 255).astype(np.uint8)[..., None]
    name = cb.upload(np.concatenate([img.astype(np.uint8), alpha], 2), "repaint.png")
    fixed = cb.run(cb.graph(text, seed, height, name, denoise))
    w = (1 - ramp)[..., None]
    return fixed * w + img * (1 - w)


def boss_runes():
    layer = cb.LAYERS["Lab/gen_boss_far"]
    old = dict(layer, prompt=layer["prompt"].replace(RUNES_NEW, RUNES_OLD))
    assert old["prompt"] != layer["prompt"]
    S, rows = cb.SCALE, layer["rows"] * cb.SCALE
    height = -(-rows // 16) * 16
    img = np.asarray(Image.open(cb.cache_path(old)).convert("RGB"), np.float32)
    img = np.concatenate([img, np.repeat(img[-1:], height - len(img), axis=0)])
    text = f"{layer['prompt']}, {cb.STYLE}"
    # кільця гліфів біля обох країв: зсув на пів ширини зводить їх в один прямокутник і не чіпає шов шару
    rings = os.path.join(cb.CACHE, "runes_rings_%s.png" % hashlib.sha1((text + "|0.65|4").encode()).hexdigest()[:12])
    if os.path.exists(rings):  # проміжна картинка: смугу над піччю пробували кілька разів
        img = np.asarray(Image.open(rings).convert("RGB"), np.float32)
    else:
        img = np.roll(img, cb.GW // 2, axis=1)
        img = box_repaint(img, (190 * S, 56 * S, 408 * S, 248 * S), text, layer["seed"] + 4, height, 0.65)
        img = np.roll(img, -(cb.GW // 2), axis=1)
        Image.fromarray(img.astype(np.uint8)).save(rings)
    # смуга над піччю: з підказкою шару (зерно +5) — знаки, схожі на китайські ієрогліфи; «трикутники» з denoise 0.65
    # (зерно +6) — смуга зникла, три великі трикутники й обрізаний на краю прямокутника; 0.55 тримає смугу
    band = (
        "the same stone band over the furnace, carved with a row of six small glowing orange triangle glyphs and "
        "dots, the same triangular glyphs as the ring on the wall, no letters, no characters, " + cb.STYLE
    )
    img = box_repaint(img, (230 * S, 62 * S, 348 * S, 104 * S), band, layer["seed"] + 7, height, 0.55)
    Image.fromarray(img[:rows].astype(np.uint8)).save(cb.cache_path(layer))
    print("done boss_runes ->", cb.cache_path(layer), "(run comfy_backdrop.py Lab/gen_boss_far)")


def git_png(path):
    data = subprocess.run(
        ["git", "show", "%s:%s" % (SRC_REV, path)], capture_output=True, check=True
    ).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


def crop(im, box):
    return (
        im
        if box is None
        else im.crop((box[0], box[1], box[0] + box[2], box[1] + box[3]))
    )


def palette(j):
    if j["palette"] == "hero":
        return cs.hero_palette()
    px = np.asarray(git_png(j["src"][0])).reshape(-1, 4)
    return np.array(sorted({tuple(c[:3]) for c in px if c[3] > 128}), np.float32)


def drop_specks(op, least):
    """Лишає 8-зв'язні шматки силуету з least пікселів і більше."""
    keep, seen = op.copy(), np.zeros_like(op)
    for y, x in zip(*np.nonzero(op)):
        if seen[y, x]:
            continue
        part, stack = [], [(y, x)]
        seen[y, x] = True
        while stack:
            cy, cx = stack.pop()
            part.append((cy, cx))
            for ny in (cy - 1, cy, cy + 1):
                for nx in (cx - 1, cx, cx + 1):
                    if 0 <= ny < op.shape[0] and 0 <= nx < op.shape[1] and op[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        if len(part) < least:
            for cy, cx in part:
                keep[cy, cx] = False
    return keep


def run_job(name):
    j = JOBS[name]
    w, h = j["size"]
    if j["bob"]:  # дихання з уже виправленого кадру в робочому дереві
        src = crop(Image.open(j["src"][0]).convert("RGBA"), j["src"][1])
        a = np.asarray(src, np.float32)
        rgb, op = cs.bob((a[..., :3], a[..., 3] > 128), j["bob"])
        frame = np.dstack([rgb, op * 255.0]).astype(np.uint8)
    elif j["pose"] is None:  # без моделі — кадр із SRC_REV, лише erase
        frame = np.asarray(crop(git_png(j["src"][0]), j["src"][1])).copy()
    else:
        src = crop(Image.open(j["src"][0]).convert("RGBA") if j["src_wt"] else git_png(j["src"][0]), j["src"][1])
        cs.UP = j["up"]
        canvas = Image.new("RGBA", (w, h), cs.MAGENTA + (255,))
        canvas.alpha_composite(src, ((w - src.width) // 2, h - src.height))
        ref = np.asarray(canvas.resize((w * cs.UP, h * cs.UP), Image.NEAREST))
        raw = cs.edit(ref, KEEP.format(who=j["who"], pose=j["pose"]), j["seed"])
        rgb, op = cs.shrink(raw, (w, h))
        pal = palette(j)
        rgb = pal[
            np.linalg.norm(rgb[:, :, None] - pal[None, None], axis=3).argmin(axis=2)
        ]
        # клапті, відірвані від тіла (менше 15 пікселів), — сміття ключування й «іскри» моделі (Attack2/3 кинджала)
        op = drop_specks(op, 15)
        frame = np.dstack([rgb, op * 255.0]).astype(np.uint8)
        shift = cs.feet_row(np.asarray(src)[..., 3] > 128) - cs.feet_row(op)
        frame = np.roll(frame, shift, axis=0)
        if shift > 0:
            frame[:shift] = 0
        elif shift < 0:
            frame[shift:] = 0
    for x0, y0, x1, y1 in j["erase"]:
        frame[y0:y1, x0:x1] = 0
    for x0, y0, x1, y1 in j["twin"]:
        part = frame[y0:y1, x0:x1]
        for key in ((0xF8, 0xF8, 0xE4), (0xC2, 0xC2, 0xC2), (0x87, 0x87, 0x8C)):
            hit = (part[..., :3] == key).all(-1) & (part[..., 3] > 0)
            part[hit, :3] = np.array(key) - 2
    path, box = j["out"]
    if box is None:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        Image.fromarray(frame).save(path)
    else:
        sheet = (
            Image.open(path).convert("RGBA")
            if os.path.exists(path)
            else Image.new("RGBA", (box[0] + w, h))
        )
        if sheet.width < box[0] + w:
            grown = Image.new("RGBA", (box[0] + w, sheet.height))
            grown.paste(sheet, (0, 0))
            sheet = grown
        sheet.paste(Image.fromarray(frame), box[:2])
        sheet.save(path)
    print("done", name, "->", path, box or "")


if __name__ == "__main__":
    # кожне завдання — один раз (dagger_heavy1_clean читає щойно записаний dagger_heavy1: удруге — промах кешу)
    names = list(
        dict.fromkeys(
            n
            for a in sys.argv[1:]
            for n in JOBS
            if n == a or n.startswith(a + "_") or (a.endswith("*") and n.startswith(a[:-1]))
        )
    )
    try:
        if "boss_runes" in sys.argv:
            boss_runes()
        for n in names:
            run_job(n)
    finally:
        cs.free()
