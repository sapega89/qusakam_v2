"""Живі деталі фону (BACKLOG 19, A5b): Qwen-Image (Apache 2.0) + Lightning-LoRA малює ОДИН предмет у стилі фонів
(STYLE з comfy_backdrop.py); кадри петлі робить скрипт із цієї однієї картинки — модель між генераціями форму не
тримає (як comfy_fx.py). sway — гойдання: зсув пікселів генерації, що росте від точки кріплення (anchor); flicker —
мерехтіння: яскравість «гарячих» пікселів (полум'я, сяйво) по кадрах. Кадри — горизонтальний аркуш, одна палітра.
dust — порошинки без моделі: 1-2 px цятки, що дрейфують (модельна «пилюка» після ×3 зменшення — ті самі цятки).
Запуск: python -I Scripts/Tools/comfy_decor.py [предмет ...]   (≤ 4 генерації за раз, моделі звільняються в кінці)
"""

import hashlib
import json
import os
import sys
import tempfile
import urllib.request

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import comfy_backdrop as cb  # noqa: E402
import comfy_fx as fx  # noqa: E402

CACHE = os.path.join(tempfile.gettempdir(), "comfy_decor")
OUT = "SampleProject/Assets/Backgrounds/Decor/"
# Без «no floor / no shadow / no beams»: кожне заперечення модель малює (як «сонце») — підлога, тінь і промені
# з'явились саме тоді. Позитивно: предмет торкається краю кадру (висить від верху / стоїть на низу), фон — суцільний.
LIGHT = "flat 2D game sprite, warm light on the top, cool violet shadows"

# anchor — точка кріплення в частках рамки предмета (x, y): там зсув 0. amp — найбільший зсув у px гри.
# canvas — кадр (px гри), предмет вписується в box по центру. hot — гарячі пікселі: (канал, поріг яскравості).
DECOR = {
    "banner": dict(
        seed=103,
        size=(512, 1024),
        key="green",
        colors=10,
        kind="shift",  # кадри — цілі px-зсуви рядків ОДНОГО зменшеного кадру: смуги й кольори ті самі в усіх кадрах
        amp=2,
        canvas=(24, 32),
        box=(2, 1, 22, 32),  # 1 px над жердиною — навершя не обрізаються
        prompt="one single hanging cloth banner, the cloth has exactly three bold wide vertical stripes: brick red, "
        "teal blue, brick red, the bottom hem is cut into a swallow-tail with two points, the cloth hangs straight down "
        "from a horizontal wooden rod that is wider than the cloth, a round wooden knob at each end of the rod, the "
        "whole rod with both knobs is visible near the top of the image, flat 2D game sprite, warm light on the top, "
        f"{cb.CHROMA}",
    ),
    "palm": dict(
        seed=73,
        size=(768, 1024),
        key="magenta",
        colors=12,
        kind="sway",
        anchor=(0.5, 1.0),  # основа стовбура (низ кадру) нерухома, крона гойдається
        amp=2.0,
        main=False,
        crop=(0, 0.1),
        canvas=(56, 72),
        box=(2, 0, 54, 72),
        prompt="one single slender date palm tree seen from the side: a thin slightly curved brown trunk rising from "
        "the bottom edge of the image, a lush top of long arching olive green and yellow-green feathered fronds "
        "drooping down on both sides, a small cluster of orange dates under the fronds, the trunk is cut off by the "
        f"bottom edge, wide empty space on both sides and above, {LIGHT}, {cb.MAGENTA}",
    ),
    "lamp": dict(
        seed=91,
        size=(768, 512),
        key="magenta",
        colors=10,
        kind="flicker",
        hot=0.78,
        main=False,
        crop=(0, 0),
        canvas=(28, 26),
        box=(1, 2, 27, 26),
        prompt="one single small clay oil lamp shaped like a low round teapot with a long pointed spout and a small "
        "loop handle, terracotta clay with a painted blue band, a small bright yellow-orange flame burning on the tip "
        f"of the spout, the lamp rests on the bottom edge of the image, {LIGHT}, {cb.MAGENTA}",
    ),
    "crystal": dict(
        seed=77,
        size=(768, 768),
        key="magenta",
        colors=10,
        kind="flicker",
        hot=0.72,
        bgv=0,
        crop=(0, 0.14),
        canvas=(24, 28),
        box=(1, 1, 23, 28),
        prompt="one single small cluster of glowing pale green crystals growing from a dark grey rock, sharp "
        f"hexagonal crystal points, bright mint green glow in their cores, the rock rests on the bottom edge of the image, {LIGHT}, {cb.MAGENTA}",
    ),
    # Входи (Sapega 2026-10-26: прохід має бути пояснений фоном — двері, вхід, колодязь). Нерухомі, один кадр;
    # стоять на рядку підлоги біля RoomDoor ([[room_art_audit]]).
    "door_elder": dict(
        seed=211, size=(512, 768), key="magenta", colors=12, kind="static", canvas=(52, 76), box=(0, 0, 52, 76),
        prompt="one single arched doorway seen from the front: a closed door of vertical dark brown planks with two "
        "black iron bands and a round iron ring handle, set in a narrow arch frame of pale sandstone blocks, a flat "
        "stone step at its foot on the bottom edge of the image, the doorway stands alone with wide empty space on both "
        f"sides and above, {LIGHT}, {cb.MAGENTA}",
    ),
    # Прохід — щонайменше 56 px заввишки (герой 47 px у тому ж масштабі 1.5): розмір задає висота, не ширина.
    "cave_mouth": dict(
        seed=232, size=(768, 768), key="green", colors=12, kind="static", crop=(0, 0.05), canvas=(110, 100),
        box=(0, 0, 110, 100),
        prompt="one single face of a red sandstone cliff with a large dark cave entrance in it, the entrance is a tall "
        "rough arch that reaches two thirds of the way up the rock, deep darkness inside, the rock face stands on the "
        f"bottom edge of the image alone with wide empty space on both sides and above, {LIGHT}, {cb.CHROMA}",
    ),
    "palisade_gate": dict(
        seed=213, size=(1024, 768), key="green", colors=12, kind="static", crop=(0, 0.1), canvas=(150, 100),
        box=(0, 0, 150, 100),
        prompt="one single wooden palisade gate of a desert bandit camp: tall rough sharpened log posts lashed with "
        "rope, a gate of lashed logs standing half open, the dark gap of the open gate as tall as the posts, a torn "
        "red cloth tied to one post, a short stretch of palisade on both sides, standing on the bottom edge of the "
        f"image alone with wide empty space above, {LIGHT}, {cb.CHROMA}",
    ),
    "mesa_cleft": dict(
        seed=234, size=(768, 768), key="green", colors=12, kind="static", crop=(0, 0.05), canvas=(110, 110),
        box=(0, 0, 110, 110),
        prompt="one single block of red and orange sandstone cliff with a tall narrow passage cut through it from "
        "the ground, rough stone steps rise inside the passage into shadow, the rock is the same warm red sandstone on "
        "both sides of the passage and above it, the block stands on the bottom edge of the image alone with wide empty "
        f"space on both sides and above, {LIGHT}, {cb.CHROMA}",
    ),
    "palace_door": dict(
        seed=235, size=(640, 768), key="magenta", colors=14, kind="static", crop=(0, 0.04), canvas=(100, 120),
        box=(0, 0, 100, 120),
        prompt="one single heavy closed double door of dark brown wood with rows of brass studs, filling a grand "
        "pointed arch of pale sandstone with a carved frame and a band of blue tiles, two stone steps in front, the "
        "doorway stands on the bottom edge of the image alone, nothing behind it, flat empty background all around, "
        f"{LIGHT}, {cb.MAGENTA}",
    ),
    "lab_door": dict(
        seed=236, size=(512, 768), key="magenta", colors=12, kind="static", canvas=(72, 100), box=(0, 0, 72, 100),
        prompt="one single arched doorway made of dark grey stone blocks with a heavy riveted iron door inside the "
        "arch, a small round glowing green window in the door, a copper pipe running along the outside of the arch, "
        "the doorway stands on the bottom edge of the image alone, nothing behind it, flat empty background all "
        f"around, {LIGHT}, {cb.MAGENTA}",
    ),
    # Передній план печер (Sapega 2026-10-26, Tails of Iron: зверху темніше, листя й коріння перед камерою закривають
    # вид). Висять від верхнього краю кадру й гойдаються; у кімнаті — шар ближче за героя, темніший (modulate).
    # Печери в пустелі сухі (Sapega: «може бути сиро, а може бути сухо, бо це печера в пустелі; ліани — така собі
    # ідея»): згори сухе коріння й натічні камені з пісковику, знизу колючий чагарник і суха трава.
    "hanging_roots": dict(
        seed=252, size=(1024, 768), key="green", colors=10, kind="sway", anchor=(0.5, 0.0), amp=1.0, main=False,
        crop=(0.04, 0),
        canvas=(170, 120), box=(4, 0, 166, 120),
        prompt="a cluster of dry bare twisted roots of desert shrubs hanging down from the top edge of the image, "
        "pale brown and dusty ochre, no leaves, a few short pointed sandstone stalactites between them, some roots "
        f"long and some short, wide empty space below and on both sides, {LIGHT}, {cb.CHROMA}",
    ),
    "hanging_chain_web": dict(
        seed=242, size=(768, 1024), key="green", colors=8, kind="sway", anchor=(0.5, 0.0), amp=1.0, main=False,
        canvas=(90, 130), box=(4, 0, 86, 130),
        prompt="one rusty iron chain and torn grey cobwebs hanging straight down from the top edge of the image, a "
        f"few dusty strands, wide empty space below and on both sides, {LIGHT}, {cb.CHROMA}",
    ),
    "fg_scrub": dict(
        seed=253, size=(1024, 640), key="magenta", colors=10, kind="sway", anchor=(0.5, 1.0), amp=1.0, main=False,
        canvas=(150, 70), box=(4, 2, 146, 70),
        prompt="one low clump of dry thorny desert brush with bare grey-brown twigs, tufts of dry yellow grass and a "
        "few small sandstone rocks growing from the bottom edge of the image, wide empty space above and on both "
        f"sides, {LIGHT}, {cb.MAGENTA}",
    ),
    # Драбини в стилі гри (A14, Sapega 2026-10-26: «драбини мають бути в стилі гри») і платформи з опорами (A15: «щоб
    # були частиною інтер'єру, а не просто так висіли в повітрі»). Драбину Ladder.tscn повторює по вертикалі: з високої
    # генерації вирізається один період щаблів.
    "ladder_wood": dict(
        seed=261, size=(384, 1024), key="magenta", colors=10, kind="static", canvas=(26, 180), box=(0, 0, 26, 180),
        prompt="one single tall wooden ladder standing straight up, seen straight from the front, two rough wooden "
        "rails lashed with rope to evenly spaced round wooden rungs, it reaches from the top edge to the bottom edge of "
        f"the image, wide empty space on both sides, {LIGHT}, {cb.MAGENTA}",
    ),
    "ladder_iron": dict(
        seed=272, size=(384, 1024), key="green", colors=10, kind="static", canvas=(26, 180), box=(0, 0, 26, 180),
        prompt="a vertical row of evenly spaced U-shaped rusty iron rungs hammered into a strip of dark grey stone "
        "blocks, seen straight from the front, flat, from the top edge to the bottom edge of the image, wide empty "
        f"space on both sides, {LIGHT}, {cb.CHROMA}",
    ),
    "ledge_rock": dict(
        seed=263, size=(768, 512), key="green", colors=12, kind="static", canvas=(110, 64), box=(0, 0, 110, 64),
        prompt="one single jutting ledge of red sandstone rock seen from the side: a flat walkable top surface with a "
        "little sand and dry grass on it, under it the rock body tapers down to a rough point like a shelf growing out "
        f"of a cliff, wide empty space around it, {LIGHT}, {cb.CHROMA}",
    ),
    # Платформи: суворо збоку, як тайл 2D-платформера (модель за «seen from the side» малювала ізометрію з тінню).
    "plank_posts": dict(
        seed=274, size=(768, 512), key="green", colors=12, kind="static", canvas=(110, 84), box=(0, 0, 110, 84),
        prompt="a flat 2D platformer tile in strict orthographic side view: a short horizontal wooden walkway, its top "
        "a straight level line of plank ends, held up by two thin vertical wooden posts going straight down with one "
        "diagonal brace between them, the posts reach the bottom edge of the image, wide empty space around it, "
        f"{LIGHT}, {cb.CHROMA}",
    ),
    "stone_balcony": dict(
        seed=275, size=(768, 512), key="green", colors=12, kind="static", canvas=(110, 56), box=(0, 0, 110, 56),
        prompt="a flat 2D platformer tile in strict orthographic side view: a short horizontal pale sandstone ledge, "
        "its top a straight level line, under it two carved stone corbels shaped like quarter circles, wide empty "
        f"space around it, {LIGHT}, {cb.CHROMA}",
    ),
    "lab_grate": dict(
        seed=276, size=(768, 512), key="green", colors=12, kind="static", canvas=(110, 48), box=(0, 0, 110, 48),
        prompt="a flat 2D platformer tile in strict orthographic side view: a short horizontal dark iron girder "
        "platform, its top a straight level line, riveted, held from below by two triangular iron brackets, wide empty "
        f"space around it, {LIGHT}, {cb.CHROMA}",
    ),
    # BACKLOG 19: трава гойдається (живий світ, D392) — кущик сухої пустельної трави, основа нерухома.
    "grass": dict(
        seed=282, size=(768, 512), key="green", colors=8, kind="sway", anchor=(0.5, 1.0), amp=1.5, main=False,
        crop=(0, 0.12), canvas=(44, 30), box=(2, 1, 42, 30),
        prompt="one single bushy clump of dry desert grass with thick wide blades fanning upward and bending outward, "
        "straw yellow and ochre with warm highlights, the clump rises from a single point at the bottom edge of the "
        f"image, wide empty space above and on both sides, {LIGHT}, {cb.CHROMA}",
    ),
}
FRAMES = 4  # sway: 0, +amp, 0, -amp (синус); flicker — 3
FLICKER = (1.0, 0.72, 1.18)


def generate(name, d):
    text = f"{d['prompt']}, {cb.STYLE}"
    path = os.path.join(
        CACHE,
        hashlib.sha1(f"{text}|{d['seed']}|{d['size']}".encode()).hexdigest()[:12]
        + ".png",
    )
    if not os.path.exists(path):
        g = cb.graph(text, d["seed"], d["size"][1])
        g["latent"]["inputs"]["width"] = d["size"][0]
        os.makedirs(CACHE, exist_ok=True)
        Image.fromarray(cb.run(g).astype(np.uint8)).save(path)
        print("generated", name, path, flush=True)
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)


def key(img, which, warm=0, bgv=175):
    """Маска предмета. Фон у моделі плаває градієнтом і сяйвом, тож не відстань від кольору, а GrabCut (cv2): точно
    фон — відтінок ключа, зв'язаний із краєм кадру; решта — «мабуть предмет», GrabCut доучує межу."""
    hsv = cv2.cvtColor(img.astype(np.uint8), cv2.COLOR_RGB2HSV).astype(int)  # H 0..179
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    if which == "green":
        bg = (h > 40) & (h < 95) & (s > 70)
    else:
        bg = ((h > 135) | (h < warm)) & (s > 70) & (v > bgv)  # warm — ще й рожево-помаранчеве сяйво; bgv — фон світліший за
        # тіні предмета (стовбур пальми того ж відтінку, що й фон); 0 — коли фон згори темніє (кристал)
    labels, _ = ndimage.label(bg)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    sure = np.isin(labels, edge[edge > 0])
    m = np.where(sure, cv2.GC_BGD, cv2.GC_PR_FGD).astype(np.uint8)
    cv2.grabCut(img.astype(np.uint8), m, None, np.zeros((1, 65)), np.zeros((1, 65)), 5, cv2.GC_INIT_WITH_MASK)
    a = (m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    if which == "green":
        img[..., 1] = np.minimum(g, np.maximum(r, b) + 20)  # зелений відсвіт країв
    return a.astype(np.float32)


def down(img, a, k, size):
    """Зменшення з кольором лише з непрозорих пікселів (як cb.shrink), до size = (w, h)."""

    def r(m):
        return np.asarray(
            Image.fromarray(m.astype(np.float32)).resize(size, Image.BOX), np.float32
        )

    asum = r(a)
    rgb = (
        np.dstack([r(img[..., c] * a) for c in range(3)])
        / np.maximum(asum, 1e-6)[..., None]
    )
    return rgb, asum > 0.45


def sway(img, a, d, phase):
    """Зсув праворуч на phase·amp у точці, найдальшій від кріплення; у самій точці — 0 (px генерації)."""
    h, w = a.shape
    ax, ay = d["anchor"][0] * w, d["anchor"][1] * h
    yy, xx = np.mgrid[:h, :w].astype(np.float32)
    r = np.hypot(xx - ax, yy - ay) / np.hypot(max(ax, w - ax), max(ay, h - ay))
    dx = phase * d["amp_gen"] * r**1.5
    dy = (
        -0.25 * dx * np.sign(xx - ax) * (d["anchor"][1] > 0)
    )  # крона: кінчики листя трохи піднімаються в бік вітру
    coords = [yy - dy, xx - dx]
    warped = np.dstack(
        [
            ndimage.map_coordinates(img[..., c], coords, order=1, mode="nearest")
            for c in range(3)
        ]
    )
    return warped, ndimage.map_coordinates(a, coords, order=1, mode="constant")


def build(name, d):
    img = generate(name, d)
    t, btm = d.get("crop", (0, 0))  # частки кадру згори / знизу: стеля й підлога, які модель домальовує попри підказку
    img = img[int(t * len(img)) : len(img) - int(btm * len(img))]
    a = key(img, d["key"], d.get("warm", 0), d.get("bgv", 175))
    if "dark" in d:  # лише темні px: світлі плями — фон, що просвічує між гілками
        a *= img.mean(axis=2) < d["dark"]
    if d.get("main", True):
        a = fx.main_shape(a)
    else:  # тонкі частини (стовбур, ланцюжок) розмикання стерло б — лише найбільша зв'язна пляма
        labels, n = ndimage.label(a > 0)
        a = (labels == 1 + int(np.argmax(ndimage.sum(np.ones_like(a), labels, range(1, n + 1))))).astype(np.float32)
    ys, xs = np.nonzero(a)
    if d["kind"] == "shift":
        return shift_sheet(img[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1], a[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1], d)
    img, a = (
        img[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
        a[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1],
    )
    x0, y0, x1, y1 = d["box"]
    k = min((x1 - x0) / a.shape[1], (y1 - y0) / a.shape[0])
    w, h = max(1, round(a.shape[1] * k)), max(1, round(a.shape[0] * k))
    if d["kind"] == "sway":
        pad = int(d["amp"] / k) + 2  # місце для зсуву, px генерації
        img = np.pad(img, ((0, 0), (pad, pad), (0, 0)), mode="edge")
        a = np.pad(a, ((0, 0), (pad, pad)))
        d = dict(d, amp_gen=d["amp"] / k)
        w += 2 * round(pad * k)
        frames = [
            sway(img, a, d, np.sin(2 * np.pi * i / FRAMES)) for i in range(FRAMES)
        ]
    elif d["kind"] == "static":
        frames = [(img, a)]
    else:
        frames = [(img, a)] * len(FLICKER)
    cw, ch = d["canvas"]
    sheet = np.zeros((ch, cw * len(frames), 3), np.float32)
    opaque = np.zeros((ch, cw * len(frames)), bool)
    ox, oy = x0 + (x1 - x0 - w) // 2, y0 + (y1 - y0 - h) // 2
    for i, (fi, fa) in enumerate(frames):
        rgb, op = down(fi, fa, k, (w, h))
        if d["kind"] == "flicker":
            lum = rgb.max(axis=2) / 255
            hot = np.clip((lum - d["hot"]) / (1 - d["hot"]), 0, 1)[..., None]
            rgb = np.clip(rgb * (1 + (FLICKER[i] - 1) * hot), 0, 255)
        # кадр може вилазити за полотно на кілька px (padding sway): обрізаємо симетрично
        cx0, cy0 = max(0, -ox), max(0, -oy)
        rgb, op = (
            rgb[cy0 : cy0 + ch, cx0 : cx0 + cw],
            op[cy0 : cy0 + ch, cx0 : cx0 + cw],
        )
        px, py = max(0, ox), max(0, oy)
        sheet[py : py + rgb.shape[0], i * cw + px : i * cw + px + rgb.shape[1]] = rgb
        opaque[py : py + rgb.shape[0], i * cw + px : i * cw + px + rgb.shape[1]] = op
    out = cb.quantize(sheet, opaque, d["colors"], "octree")
    rows = np.nonzero(opaque.any(axis=1))[0]  # порожні рядки геть: верхній рядок — підвіс, нижній — лінія ніг
    return out[rows.min() : rows.max() + 1]


def shift_sheet(img, a, d):
    """Один кадр зменшується й квантується РАЗ; кадри петлі — цілі px-зсуви його рядків: рядок y зсувається на
    round(phase·amp·(y/h)^1.5) — жердина (верх) стоїть, кінчик ходить на ±amp. Кольори й смуги в кадрах однакові."""
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    a = a * ~((b > g + 15) & (b > r + 30) & (r > 35))  # синьо-фіолетова тінь на фоні (STYLE), не тканина: бірюза має r < 25
    ys, xs = np.nonzero(a > 0)
    img, a = img[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1], a[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    x0, y0, x1, y1 = d["box"]
    k = min((x1 - x0) / a.shape[1], (y1 - y0) / a.shape[0])
    w, h = max(1, round(a.shape[1] * k)), max(1, round(a.shape[0] * k))
    rgb, op = down(img, a, k, (w, h))
    base = cb.quantize(rgb, op, d["colors"], "octree")  # (h, w, 4)
    cw, ch = d["canvas"]
    ox = x0 + (x1 - x0 - w) // 2
    sheet = np.zeros((ch, cw * FRAMES, 4), np.uint8)
    for i in range(FRAMES):
        phase = round(np.sin(2 * np.pi * i / FRAMES))
        for y in range(h):
            dx = round(phase * d["amp"] * (y / max(1, h - 1)) ** 1.5)
            sheet[y0 + y, i * cw + ox + dx : i * cw + ox + dx + w] = base[y]
    return sheet


def dust(seed=3, size=(64, 64), frames=6):
    """Аркуш порошинок, безшовна петля кадрів. A7 (D813, 2026-10-28): була рівна сипка однакових 1-2-px цяток, що
    кружляли кожна сама по собі, — читалась шумом або зорями, а не пилом у вітрі. Тепер три розміри (крихта 1 px,
    кругла порошинка 2×2 з прозорішими кутами, пасмо — хвіст із 5 px уздовж свого кола), усі кружляють в один бік
    (вихор, а не рій), і кожна мерехтить зі своєю фазою — ловить світло. Кольори ті самі: пісок, тінь піску, серпанок."""
    rng = np.random.default_rng(seed)
    pal = np.array(
        [[248, 232, 200], [236, 210, 170], [214, 214, 224]], np.uint8
    )  # пісок, тінь піску, серпанок
    w, h = size
    sheet = np.zeros((h, w * frames, 4), np.float32)

    def put(f, x, y, rgb, a):
        x, y = int(round(x)) % w, int(round(y)) % h
        px = sheet[y, f * w + x]
        if a > px[3]:  # світліша цятка перекриває, прозорість не складається в пляму
            px[:] = (*rgb, a)

    kinds = [("speck", 18), ("mote", 7), ("wisp", 3)]
    for kind, n in kinds:
        p0 = rng.uniform(0, 1, (n, 2)) * (w, h)
        r = rng.uniform(*{"speck": (3, 7), "mote": (4, 8), "wisp": (8, 12)}[kind], n)
        ang = rng.uniform(0, 2 * np.pi, n)
        blink = rng.uniform(0, 2 * np.pi, n)
        col = rng.integers(0, len(pal), n)
        for f in range(frames):
            t = 2 * np.pi * f / frames
            for i in range(n):
                glow = 0.75 + 0.25 * np.cos(t + blink[i])  # мерехтить
                if kind == "wisp":
                    # хвіст позаду голови на тому ж колі: вихор видно, а не лише цятку
                    for k in range(7):  # крок ~1 px уздовж кола: суцільний хвіст, не пунктир
                        th = t + ang[i] - k / r[i]
                        put(f, p0[i, 0] + r[i] * np.cos(th), p0[i, 1] + 0.55 * r[i] * np.sin(th), pal[0],
                            255 * glow * (1 - k / 7))
                    continue
                x = p0[i, 0] + r[i] * np.cos(t + ang[i])
                y = p0[i, 1] + 0.55 * r[i] * np.sin(t + ang[i])
                a = 255 * glow
                put(f, x, y, pal[col[i]], a)
                if kind == "mote":
                    for dx, dy, k in ((1, 0, 1.0), (0, 1, 1.0), (1, 1, 1.0), (-1, 0, 0.4), (-1, 1, 0.4), (2, 0, 0.4),
                                      (2, 1, 0.4), (0, -1, 0.4), (1, -1, 0.4), (0, 2, 0.4), (1, 2, 0.4)):
                        put(f, x + dx, y + dy, pal[col[i]], a * k)
    # альфа — чотири рівні: піксель-арт без плавних градієнтів
    a = sheet[..., 3]
    sheet[..., 3] = np.select([a < 40, a < 110, a < 170, a < 225], [0, 90, 150, 210], 255)
    return sheet.astype(np.uint8)


def save(name, out):
    os.makedirs(OUT + name, exist_ok=True)
    Image.fromarray(out).save(f"{OUT}{name}/{name}_sheet.png")
    print("wrote", f"{OUT}{name}/{name}_sheet.png", out.shape[1::-1], flush=True)


if __name__ == "__main__":
    names = sys.argv[1:] or [*DECOR, "dust"]
    for name in names:
        save(name, dust() if name == "dust" else build(name, DECOR[name]))
    if any(n != "dust" for n in names):
        urllib.request.urlopen(
            urllib.request.Request(
                cb.API + "/free",
                json.dumps({"unload_models": True, "free_memory": True}).encode(),
                {"Content-Type": "application/json"},
            )
        )
