"""A13 (B189, B191): реквізит, вмальований у плани в 2,5–3,9 раза більшим за таблицю (D814), — геть із планів; окремі
спрайти точного розміру малює comfy_backdrop.py (шари */prop_*), тут вони лише беруть кольори своєї кімнати.
  py -3.13 -I -B Scripts/Tools/unbake_props.py gen    — Qwen-Image-Edit-2511 прибирає реквізит (сирі PNG у design/shots/candidates/a13/)
  py -3.13 -I -B Scripts/Tools/unbake_props.py build  — плани без реквізиту: правка моделі лише там, де стояв реквізит
  py -3.13 -I -B Scripts/Tools/unbake_props.py props  — prop_*.png (з comfy_backdrop.py) у палітру свого плану
  py -3.13 -I -B Scripts/Tools/unbake_props.py scrub  — B191: fg_scrub_sheet 2:1 (31 арт замість 61, ті самі кадри)
Оригінали планів — design/shots/candidates/a13/*_orig.png (з них і повторний build).
"""

import os
import shutil
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import comfy_sprite as cs  # noqa: E402

BG = "SampleProject/Assets/Backgrounds/"
D = "design/shots/candidates/a13/"
K = 3
KEEP = (
    " Keep the plain flat magenta background and everything else exactly as it is, in the same painterly style, "
    "colours and position."
)
# план → (файл, зерно, підказка, прямокутники реквізиту в пікселях плану (x0, y0, x1, y1))
PLANES = {
    "camp": (
        "BanditCamp/gen_mid.png",
        1311,
        "Remove the wooden barrel standing by the palisade on the left, the stack of four wooden crates in front of "
        "the big striped tent and the burlap sack beside them. Where they stood, continue the sand ground, the "
        "palisade and the striped tent behind them." + KEEP,
        [(55, 150, 98, 206), (308, 148, 476, 228)],
    ),
    "cellar": (
        "Cellar/gen_mid.png",
        1312,
        "Remove all the wooden barrels, the wooden crates and the wine bottles standing between the stone pillars. "
        "Where they stood, continue the stone pillars down to their bases, the brick wall, the flat magenta inside "
        "the arches down to the stone floor, and the stone floor." + KEEP,
        [(178, 140, 572, 298)],
    ),
    "elder": (
        "ElderHouse/gen_wall.png",
        1313,
        "Remove the tall clay jar standing on the floor beside the hearth and the two round clay pots standing on "
        "the low stone bench on the right. Where they stood, continue the plain adobe wall, the floor and the stone "
        "bench. Keep the clay pots on the wall shelves, the hearth, the scrolls and everything else exactly as it is, "
        "in the same painterly style, colours and position.",
        [(170, 230, 218, 306), (360, 222, 445, 275)],
    ),
}
# другий прохід (з плану після першого): мішок біля намету перша правка лишила
FIX = {
    "camp": (
        1321,
        "Remove the small burlap sack standing at the foot of the big striped tent, left of its dark entrance. Where "
        "it stood, continue the dark tent cloth, the tent pole and the sand ground." + KEEP,
        [(428, 168, 478, 224)],
    ),
}
# латки готовими пікселями плану: (джерело x0, y0, x1, y1) → (x, y). Біля печі обидві правки домальовували другу
# арочну нішу замість глека — там гола стіна праворуч від неї
PATCH = {"elder": [((222, 228, 246, 282), (170, 228))]}
# нижній рядок прорізу арки (підлога), там, де реквізит стояв у прорізі
OPEN = {"cellar": 250}  # з рядком щербатої цегли, яку модель поклала на підлогу
# prop_*.png → план, з палітри якого кольори
PROPS = {
    "BanditCamp": "camp",
    "Cellar": "cellar",
    "ElderHouse": "elder",
}


def orig(name):
    path = D + name + "_orig.png"
    if not os.path.exists(path):
        os.makedirs(D, exist_ok=True)
        shutil.copy(BG + PLANES[name][0], path)
    return np.asarray(Image.open(path).convert("RGBA"))


def edit(plane, text, seed, raw):
    """Правка моделі плану (прозоре — пурпур, ×K) у сирий PNG raw; є — не генерує."""
    if os.path.exists(raw):
        return
    o = plane.copy()
    o[o[..., 3] == 0, :3] = cs.MAGENTA  # прозоре — пурпур, модель його лишає
    o[..., 3] = 255
    big = np.asarray(Image.fromarray(o).resize((o.shape[1] * K, o.shape[0] * K), Image.NEAREST))
    out = cs.edit(big, text, seed)
    Image.fromarray(out.astype(np.uint8)).resize((big.shape[1], big.shape[0]), Image.BOX).save(raw)
    print("generated", raw, flush=True)


def gen():
    """Перший прохід (з оригіналу), тоді другий — FIX (з плану після першого)."""
    for name, (_, seed, text, _) in PLANES.items():
        edit(orig(name), text, seed, D + name + "_raw.png")
    for name, (seed, text, _) in FIX.items():
        edit(splice(name, orig(name), D + name + "_raw.png", PLANES[name][3]), text, seed, D + name + "_fix_raw.png")
    cs.free()


def down(path, size):
    w, h = size
    a = np.asarray(Image.open(path).convert("RGB").resize((w * K, h * K), Image.BOX), np.float32)
    return a.reshape(h, K, w, K, 3).mean(axis=(1, 3))


def magenta(rgb):
    return (rgb[..., 0] > 150) & (rgb[..., 2] > 120) & (rgb[..., 1] < 110)


def to_palette(rgb, pal):
    return pal[((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1).argmin(-1)]


def palette(o):
    return np.unique(o[o[..., 3] > 0][:, :3], axis=0).astype(np.float32)


def splice(name, o, raw, boxes):
    """Правка raw лише там, де реквізит: у прямокутниках — що вона змінила (з запасом), решта — пікселі o."""
    from scipy import ndimage

    h, w = o.shape[:2]
    rep = down(raw, (w, h))
    hole = magenta(rep)
    rep = to_palette(rep, palette(orig(name)))
    box = np.zeros((h, w), bool)
    for x0, y0, x1, y1 in boxes:
        box[y0:y1, x0:x1] = True
    diff = (np.abs(o[..., :3].astype(int) - rep.astype(int)).sum(-1) > 60) | ((o[..., 3] == 0) != hole)
    m = ndimage.binary_opening(diff & box, iterations=1)
    lab, n = ndimage.label(m)
    m = np.isin(lab, 1 + np.nonzero(ndimage.sum(m, lab, range(1, n + 1)) >= 40)[0])
    m = ndimage.binary_dilation(ndimage.binary_fill_holes(m), iterations=3) & box
    out = o.copy()
    out[m, :3] = rep[m]
    if (orig(name)[..., 3] == 0).any():  # план із прозорими прорізами; суцільна стіна хати лишається суцільною
        out[m, 3] = np.where(hole[m], 0, 255)
    if name in OPEN:
        # проріз арки над реквізитом іде вниз до підлоги: модель мурувала там низьку стіну з пурпуровими швами
        # (дірки) — прозоро, за аркою видно дальню стіну (gen_far), як у лівій арці
        for x0, y0, x1, y1 in boxes:
            cols = np.nonzero((o[y0 - 40 : y0, x0:x1, 3] == 0).any(axis=0))[0] + x0  # над ним проріз (і за павутинням)
            for x in cols:
                col = slice(y0, OPEN[name] + 1)
                out[col, x, 3] = np.where(m[col, x], 0, out[col, x, 3])
    print(name, raw, "changed px", int(m.sum()), flush=True)
    return out


def build():
    for name, (path, _, _, boxes) in PLANES.items():
        out = splice(name, orig(name), D + name + "_raw.png", boxes)
        if name in FIX:
            out = splice(name, out, D + name + "_fix_raw.png", FIX[name][2])
        for (x0, y0, x1, y1), (x, y) in PATCH.get(name, []):
            out[y : y + y1 - y0, x : x + x1 - x0] = out[y0:y1, x0:x1].copy()
        Image.fromarray(out).save(BG + path)
        print("built", BG + path, flush=True)


def props():
    """prop_*.png з comfy_backdrop.py: без трави й кинутої тіні (модель кладе їх під предмет, хоч і «no ground, no
    shadow»), обрізані до предмета, у палітрі свого плану. Висота шару в comfy_backdrop — з запасом на ту смугу."""
    for room, plane in PROPS.items():
        pal = palette(orig(plane))
        for f in sorted(os.listdir(BG + room)):
            if not (f.startswith("prop_") and f.endswith(".png")):
                continue
            p = np.asarray(Image.open(BG + room + "/" + f).convert("RGBA")).copy()
            op = p[..., 3] > 0
            px = p[..., :3].astype(int)
            op &= ~(px[..., 1] > np.maximum(px[..., 0], px[..., 2]))  # оливкова трава
            ys = np.nonzero(op.any(axis=1))[0]
            # стовпці самого предмета: тінь на землі збоку — низенька смуга, у предмета стовпці високі
            xs = np.nonzero(op.sum(axis=0) >= 0.4 * (ys[-1] - ys[0] + 1))[0]
            keep = np.zeros_like(op)
            keep[:, max(0, xs[0] - 1) : xs[-1] + 2] = True
            op &= keep
            ys, xs = np.nonzero(op)
            p[~op] = 0
            p[op, :3] = to_palette(p[op, :3].astype(np.float32)[None], pal)[0]
            p = p[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
            Image.fromarray(p).save(BG + room + "/" + f)
            print(room, f, p.shape[1], "x", p.shape[0], flush=True)


def scrub():
    """2:1 — у блоці 2×2 непрозорий, якщо таких пікселів ≥ 2, колір — найчастіший з непрозорих (палітра та сама)."""
    path = BG + "Decor/fg_scrub/fg_scrub_sheet.png"
    s = np.asarray(Image.open(path).convert("RGBA"))
    assert s.shape[1] == 600, "already downsampled"
    s = np.concatenate(
        [np.zeros((s.shape[0] % 2, s.shape[1], 4), np.uint8), s]
    )  # низ (корінь куща) — на місці
    h, w = s.shape[0] // 2, s.shape[1] // 2
    out = np.zeros((h, w, 4), np.uint8)
    for y in range(h):
        for x in range(w):
            block = s[2 * y : 2 * y + 2, 2 * x : 2 * x + 2].reshape(4, 4)
            px = [tuple(c) for c in block if c[3] > 0]
            if len(px) >= 2:
                out[y, x] = max(set(px), key=px.count)
    Image.fromarray(out).save(path)
    print("fg_scrub_sheet", w, "x", h, flush=True)


if __name__ == "__main__":
    {"gen": gen, "build": build, "props": props, "scrub": scrub}[sys.argv[1]]()
