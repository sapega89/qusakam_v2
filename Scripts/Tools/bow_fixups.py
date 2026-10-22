"""Лук героя (BACKLOG 40, A4), після відмови арт-директора:
- bow/Run/1-6 — кадри бігу художника (Run/1,3,4,5,7,8) без змін, лук позаду тіла в дальній руці. Лук — один і той самий
  (вирізаний з кадру Qwen-Image-Edit ON: Run/1 коміту 87c56f92), іде за кулаком по x (і до 2 px по y), тож не
  мерехтить довжиною і не лягає на морду (голова художника його закриває).
- FX/Projectiles/arrow_charged.png — arrow.png (Qwen-Image) + сяйво й слід кольорами сяйва кадрів Charged (кремові
  кольори художника), сяйво за наконечником, слід упритул до древка.
Запуск: python Scripts/Tools/bow_fixups.py
"""

import io
import subprocess

import numpy as np
from PIL import Image

BOW = "SampleProject/Sprites/Player/Weapons/bow/"
GEN = "87c56f92:" + BOW + "Run/1.png"
# центр кулака ближньої руки в кадрах бігу художника (64x64)
FIST = {1: (53, 35), 3: (50, 38), 4: (46, 41), 5: (50, 40), 7: (46, 41), 8: (44, 45)}


def h(s):
    return np.array([int(s[i : i + 2], 16) for i in (0, 2, 4)] + [255], np.uint8)


def bow_layer():
    src = np.array(Image.open(io.BytesIO(subprocess.check_output(["git", "show", GEN]))).convert("RGBA"))
    b = np.zeros_like(src)
    b[45:90, 68:75] = src[45:90, 68:75]
    b[66:72, 68:75] = 0  # там був кулак моделі — тягнемо плече лука далі
    for y in range(66, 72):
        b[y, 71], b[y, 72], b[y, 73] = h("020100"), h("93573f"), h("020100")
    for y in range(49, 86):  # тятива
        if not b[y, 67:69, 3].any():
            b[y, 67] = h("f4ce8a")
    b[b[:, :, 3] == 0] = 0
    return b


def run():
    b = bow_layer()
    for k, n in enumerate(sorted(FIST)):
        fx, fy = FIST[n]
        dx, dy = fx - FIST[1][0], max(0, min(2, (fy - FIST[1][1]) // 2))
        c = Image.fromarray(np.roll(np.roll(b, dy, 0), dx, 1))
        c.alpha_composite(Image.open("SampleProject/Sprites/Player/Run/%d.png" % n).convert("RGBA"), (16, 32))
        c.save(BOW + "Run/%d.png" % (k + 1))


def arrow_charged():
    core, c1, c2, c3 = h("fcf3d5"), h("f4ce8a"), h("eec87d"), h("dcc3a2")
    r = np.array(Image.open("SampleProject/Assets/FX/Projectiles/arrow.png").convert("RGBA"))
    w, hh, ox, oy = 36, 13, 4, 2
    out = np.zeros((hh, w, 4), np.uint8)
    cx, cy = ox + 24, oy + 3.5  # центр наконечника
    for y in range(hh):
        for x in range(w):
            d = ((x - cx) ** 2 + ((y - cy) * 1.25) ** 2) ** 0.5
            if d <= 2.5:
                out[y, x] = core
            elif d <= 3.6:
                out[y, x] = c1
            elif d <= 5.2:
                out[y, x] = c2 if d < 4.3 else c3
    for x in range(ox + 8, ox + 21):  # слід уздовж древка
        t = (x - ox - 8) / 13
        out[oy + 2, x] = out[oy + 5, x] = c1 if t > 0.5 else c3
        if t > 0.75:
            out[oy + 1, x] = out[oy + 6, x] = c3
    a = r[:, :, 3] > 0
    arrow = r.copy()
    lit = (r[:, :, 0] == 0xE4) & a
    lit[:, :20] = False  # світиться лише наконечник, не оперення
    arrow[lit] = core
    out[oy : oy + 9, ox : ox + 28][a] = arrow[a]
    Image.fromarray(out).save("SampleProject/Assets/FX/Projectiles/arrow_charged.png")


if __name__ == "__main__":
    run()
    arrow_charged()
