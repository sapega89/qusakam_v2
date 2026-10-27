"""Атмосфера (A23, ambient_critters_plan зріз 2b): те, що не варто кликати модель.
- butterfly_blue.png і moth.png — кадри butterfly.png (comfy_sprite.py critter_butterfly) в інших кольорах: оазисний
  блакитний (відтінок повернуто на 180°) і пильна сіро-бура міль (знебарвлено до бурого);
- glow_*.png — світлячок, спора, порошинка, смуга світла для частинок: ядро в кілька пікселів і 2–3 сходинки альфи,
  кольори з палітри печери ящурів (LizardCave/gen_back.png);
- design/shots/atmosphere_sprites.png — лист ×4 з підписами, поруч герой для масштабу.
  python -B Scripts/Tools/draw_atmosphere.py
"""

import colorsys

import numpy as np
from PIL import Image, ImageDraw

OUT = "SampleProject/Assets/Characters/Critters/"
SHEET = "design/shots/atmosphere_sprites.png"
HERO = "SampleProject/Sprites/Player/Walk/1.png"
# палітра печери ящурів: найсвітліший теплий, теплий помаранч, холодне небо далечіні, світлий сірий
WARM, ORANGE, SKY, PALE = (
    (252, 204, 153),
    (244, 150, 99),
    (180, 232, 248),
    (223, 218, 221),
)


def recolor(src, fn):
    a = np.asarray(Image.open(src).convert("RGBA")).copy()
    for c in np.unique(a[a[..., 3] > 0][:, :3], axis=0):
        h, s, v = colorsys.rgb_to_hsv(*(c / 255))
        at = (a[..., :3] == c).all(-1)
        a[at, :3] = np.round(np.array(colorsys.hsv_to_rgb(*fn(h, s, v))) * 255)
    return Image.fromarray(a)


def blue(h, s, v):
    return ((h + 0.5) % 1 if s > 0.3 else h), s, v


def moth(h, s, v):
    return 0.08, s * 0.3, v * (0.72 if v > 0.9 else 0.85)


def glow(size, steps, core, halo):
    """Кругле сяйво: steps — (радіус, альфа) від ядра назовні; ядро кольором core, решта — halo."""
    c = (size - 1) / 2
    y, x = np.mgrid[:size, :size]
    d = np.hypot(x - c, y - c)
    a = np.zeros((size, size, 4), np.uint8)
    for i, (r, alpha) in reversed(list(enumerate(steps))):
        at = d <= r
        a[at] = (*(core if i == 0 else halo), alpha)
    return Image.fromarray(a)


def shaft(w, h, color):
    """Смуга світла: поперек — три сходинки альфи, вздовж — сходинками з'являється й зникає."""
    x = np.abs(np.arange(w) - (w - 1) / 2)
    across = np.select([x <= 2, x <= 5], [90, 50], 20)
    along = np.minimum(np.minimum(np.arange(h) + 1, h - np.arange(h)) / (h / 4), 1.0)
    along = np.ceil(along * 3) / 3  # три сходинки
    a = np.zeros((h, w, 4), np.uint8)
    a[..., :3] = color
    a[..., 3] = (across[None, :] * along[:, None]).astype(np.uint8)
    return Image.fromarray(a)


def sheet(items):
    """items: (підпис, картинка, тло) — у ряд, ×4, герой першим."""
    k, pad, top = 4, 16, 28
    ims = [
        (n, im.resize((im.width * k, im.height * k), Image.NEAREST), bg)
        for n, im, bg in items
    ]
    w = sum(im.width for _, im, _ in ims) + pad * (len(ims) + 1)
    h = max(im.height for _, im, _ in ims) + top + pad
    out = Image.new("RGBA", (w, h), (30, 28, 36, 255))
    d = ImageDraw.Draw(out)
    x = pad
    for n, im, bg in ims:
        y = (
            h - pad - im.height
        )  # усе стоїть на одному низу — герой і нижній ряд (політ) поруч
        out.paste(Image.new("RGBA", im.size, bg), (x, y))
        out.alpha_composite(im, (x, y))
        d.text((x, y - 16), n, fill=(255, 255, 255, 255))
        x += im.width + pad
    out.save(SHEET)


def glows_panel(ims):
    w = sum(im.width for im in ims) + 6 * (len(ims) + 1)
    h = max(im.height for im in ims) + 12
    p = Image.new("RGBA", (w, h))
    x = 6
    for im in ims:
        p.alpha_composite(im, (x, (h - im.height) // 2))
        x += im.width + 6
    return p


if __name__ == "__main__":
    recolor(OUT + "butterfly.png", blue).save(OUT + "butterfly_blue.png")
    recolor(OUT + "butterfly.png", moth).save(OUT + "moth.png")
    g = {
        "glow_firefly": glow(9, [(1, 255), (2, 150), (3, 70), (4, 25)], WARM, ORANGE),
        "glow_spore": glow(7, [(1, 255), (2, 120), (3, 40)], PALE, SKY),
        "glow_dust": glow(3, [(0, 255), (1, 110)], WARM, WARM),
        "glow_shaft": shaft(16, 96, WARM),
    }
    for n, im in g.items():
        im.save(OUT + n + ".png")
    sand, night = (196, 160, 132, 255), (24, 22, 40, 255)
    sheet(
        [
            ("hero (Walk/1)", Image.open(HERO).convert("RGBA"), sand),
            (
                "butterfly: perch 2 / fly 4",
                Image.open(OUT + "butterfly.png").convert("RGBA"),
                sand,
            ),
            (
                "butterfly_blue (oasis)",
                Image.open(OUT + "butterfly_blue.png").convert("RGBA"),
                sand,
            ),
            (
                "moth (caves, night)",
                Image.open(OUT + "moth.png").convert("RGBA"),
                night,
            ),
            ("firefly / spore / dust / shaft", glows_panel(list(g.values())), night),
        ]
    )
    print("drawn", SHEET)
