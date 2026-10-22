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
        seed=71,
        size=(512, 1024),
        key="green",
        colors=10,
        kind="sway",
        anchor=(0.5, 0.0),
        amp=2.0,
        canvas=(24, 48),
        box=(4, 0, 20, 48),
        prompt="one single long narrow hanging cloth banner with vertical red and deep blue stripes and a scalloped "
        "fringe at its bottom edge, hanging straight down from a short horizontal wooden rod with round knobs at both "
        f"ends, the rod touches the top edge of the image, the cloth falls freely, {LIGHT}, {cb.CHROMA}",
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
    if d.get("main", True):
        a = fx.main_shape(a)
    else:  # тонкі частини (стовбур, ланцюжок) розмикання стерло б — лише найбільша зв'язна пляма
        labels, n = ndimage.label(a > 0)
        a = (labels == 1 + int(np.argmax(ndimage.sum(np.ones_like(a), labels, range(1, n + 1))))).astype(np.float32)
    ys, xs = np.nonzero(a)
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


def dust(seed=3, n=14, size=(64, 64), frames=6):
    """Аркуш порошинок: n цяток, кожна дрейфує по колу (безшовна петля кадрів), кольори — світлий пісок фонів."""
    rng = np.random.default_rng(seed)
    pal = np.array(
        [[248, 232, 200], [236, 210, 170], [214, 214, 224]], np.uint8
    )  # пісок, тінь піску, серпанок
    w, h = size
    sheet = np.zeros((h, w * frames, 4), np.uint8)
    p0 = rng.uniform(0, 1, (n, 2)) * (w, h)
    drift = rng.uniform(
        4, 9, n
    )  # px за петлю — вгору й убік, по колу (петля без стрибка)
    ang = rng.uniform(0, 2 * np.pi, n)
    big = rng.uniform(0, 1, n) < 0.3
    col = rng.integers(0, len(pal), n)
    alpha = rng.choice([200, 255], n)
    for f in range(frames):
        t = 2 * np.pi * f / frames
        for i in range(n):
            x = int(p0[i, 0] + drift[i] * np.cos(t + ang[i])) % w
            y = int(p0[i, 1] + drift[i] * 0.6 * np.sin(t + ang[i])) % h
            cells = [(x, y)] + (
                [((x + 1) % w, y), (x, (y + 1) % h), ((x + 1) % w, (y + 1) % h)]
                if big[i]
                else []
            )
            for cx, cy in cells:
                sheet[cy, f * w + cx] = (*pal[col[i]], alpha[i])
    return sheet


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
