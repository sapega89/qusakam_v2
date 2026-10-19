"""Шари паралаксу через ComfyUI (D234): Qwen-Image (Apache 2.0) з Lightning-LoRA малює шар пласкою
матовою ілюстрацією в SCALE разів більшою за піксель гри; скрипт робить його безшовним по горизонталі,
прибирає зелений фон у прозорість, зменшує до пікселя гри й зводить до кількох кольорів. Шар — екран
W×H (864×486 світу при ×1.5); шар, що стоїть на землі, генерується смугою висотою rows від рядка top.
Пікселі робить зменшення, не модель: її «піксель-арт» не збігається з сіткою гри.
Генерації кешуються в CACHE (за підказкою, зерном, висотою): зміна обробки не кличе модель знову.
Потрібен запущений ComfyUI з API і моделі з graph(). Шари — LAYERS, кладе в OUT.
Запуск: python Scripts/Tools/comfy_backdrop.py [шар ...]
"""

import hashlib
import io
import json
import os
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import uuid

import numpy as np
from PIL import Image

API = "http://127.0.0.1:8000"
OUT = "SampleProject/Assets/Backgrounds/Canyon/"
CACHE = os.path.join(tempfile.gettempdir(), "comfy_backdrop")
W, H, SCALE = 576, 324, 3
GW = W * SCALE
SEAM = 120  # пів ширини смуги шва, яку перемальовує модель, px генерації
GREEN = np.array([0, 255, 0], np.float32)
# Серпанок далини — колір неба біля обрію (ним же були в серпанку процедурні стіни D227).
HAZE = np.array([214, 214, 224], np.float32)
# Без назв ігор і без «сонця» навіть із «no»: модель пише назву текстом просто в небі й малює диск
# (а сонця в лорі немає, D196). Фон — хромакей: білий модель то сірить, то плутає зі світлим піском;
# палітра — лише в підказці предмета, інакше «пастельний» стиль робить і зелений бірюзовим.
STYLE = (
    "flat matte painting for a 2D side-scrolling game, orthographic side view, clean simple shapes, "
    "soft painterly shading, warm highlights and cool violet shadows"
)
CHROMA = "on a solid flat chroma key green (#00FF00) background"
# Неба тут немає: модель домальовує в ньому промені, землю й текст, тож небо — градієнт із паку (plan5).
# seam — як шар стає безшовним: model — модель перемальовує смугу шва (суцільний краєвид), blend —
# перехресне змішування з собою, зсунутим на пів ширини (плавний градієнт без деталей), drop — прибирається все,
# що торкається бічних і нижнього країв (окремі предмети в повітрі: хмари). key — зелений фон
# прозорий; fill — під силуетом суцільно до низу (шар стоїть на землі); haze — частка серпанку
# (модель на «туманне» сірить і фон).
LAYERS = {
    "gen_clouds": dict(
        seed=7,
        rows=H,
        top=0,
        seam="drop",
        key=True,
        fill=False,
        haze=0,
        colors=6,
        prompt="three big soft fluffy cumulus clouds in pale pink and lavender with violet shadows, floating "
        f"in the middle with empty space around them, {CHROMA}",
    ),
    "gen_far": dict(
        seed=11,
        rows=200,
        top=70,
        seam="model",
        key=True,
        fill=True,
        haze=0.35,
        colors=8,
        prompt="a distant range of flat-topped desert mesas and buttes, sandy beige and dusty violet rock with violet "
        f"shadows, spanning the full width and reaching the bottom edge, {CHROMA}",
    ),
    "gen_walls": dict(
        seed=5,
        rows=240,
        top=H - 240,
        seam="model",
        key=True,
        fill=True,
        haze=0.25,
        colors=12,
        prompt="a long wall of steep red-orange sandstone canyon cliffs with horizontal rock strata and jagged flat "
        "mesa tops, spanning the full width and filling the lower part down to the bottom edge, warm light on "
        f"the tops, cool violet shadows in the cracks, {CHROMA}",
    ),
}


def graph(text, seed, height, image=None):
    """Граф API ComfyUI; з image — перемальовує лише прозору смугу цієї картинки."""
    g = {
        "unet": (
            "UNETLoader",
            {
                "unet_name": "qwen_image_fp8_e4m3fn.safetensors",
                "weight_dtype": "default",
            },
        ),
        "clip": (
            "CLIPLoader",
            {
                "clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors",
                "type": "qwen_image",
                "device": "default",
            },
        ),
        "vae": ("VAELoader", {"vae_name": "qwen_image_vae.safetensors"}),
        "lora": (
            "LoraLoaderModelOnly",
            {
                "model": ["unet", 0],
                "lora_name": "Qwen-Image-Lightning-4steps-V1.0.safetensors",
                "strength_model": 1.0,
            },
        ),
        "model": ("ModelSamplingAuraFlow", {"model": ["lora", 0], "shift": 3.1}),
        "pos": ("CLIPTextEncode", {"clip": ["clip", 0], "text": f"{text}, {STYLE}"}),
        "neg": ("CLIPTextEncode", {"clip": ["clip", 0], "text": ""}),  # cfg 1 — не діє
        "latent": (
            "EmptySD3LatentImage",
            {"width": GW, "height": height, "batch_size": 1},
        ),
        "sample": (
            "KSampler",
            {
                "model": ["model", 0],
                "positive": ["pos", 0],
                "negative": ["neg", 0],
                "latent_image": ["latent", 0],
                "seed": seed,
                "steps": 4,
                "cfg": 1.0,
                "sampler_name": "euler",
                "scheduler": "simple",
                "denoise": 1.0,
            },
        ),
        "decode": ("VAEDecode", {"samples": ["sample", 0], "vae": ["vae", 0]}),
        "save": (
            "SaveImage",
            {"images": ["decode", 0], "filename_prefix": "kusakam/backdrop"},
        ),
    }
    if image:
        g["load"] = ("LoadImage", {"image": image})
        g["encode"] = ("VAEEncode", {"pixels": ["load", 0], "vae": ["vae", 0]})
        g["latent"] = (
            "SetLatentNoiseMask",
            {"samples": ["encode", 0], "mask": ["load", 1]},
        )
    return {k: {"class_type": c, "inputs": i} for k, (c, i) in g.items()}


def run(g):
    req = urllib.request.Request(
        API + "/prompt",
        json.dumps({"prompt": g}).encode(),
        {"Content-Type": "application/json"},
    )
    pid = json.load(urllib.request.urlopen(req))["prompt_id"]
    while not (h := json.load(urllib.request.urlopen(f"{API}/history/{pid}")).get(pid)):
        time.sleep(2)
    if h["status"]["status_str"] != "success":
        sys.exit("ComfyUI: " + json.dumps(h["status"]["messages"])[-1500:])
    img = h["outputs"]["save"]["images"][0]
    data = urllib.request.urlopen(API + "/view?" + urllib.parse.urlencode(img)).read()
    return np.asarray(Image.open(io.BytesIO(data)).convert("RGB"), dtype=np.float32)


def upload(rgba, name):
    buf = io.BytesIO()
    Image.fromarray(rgba).save(buf, "PNG")
    b = uuid.uuid4().hex

    def field(k, v):
        return f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'

    head = field("overwrite", "true") + field("subfolder", "kusakam")
    head += f'--{b}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\nContent-Type: image/png\r\n\r\n'
    body = head.encode() + buf.getvalue() + f"\r\n--{b}--\r\n".encode()
    req = urllib.request.Request(
        API + "/upload/image",
        body,
        {"Content-Type": f"multipart/form-data; boundary={b}"},
    )
    r = json.load(urllib.request.urlopen(req))
    return f"{r['subfolder']}/{r['name']}"


def generate(layer):
    """Картинка шару в px генерації, безшовна по горизонталі для seam model / blend."""
    tag = json.dumps(
        [layer["prompt"], STYLE, layer["seed"], layer["rows"], layer["seam"]]
    )
    path = os.path.join(CACHE, hashlib.sha1(tag.encode()).hexdigest()[:16] + ".png")
    if os.path.exists(path):
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    height = -(-layer["rows"] * SCALE // 16) * 16  # сторони латента кратні 16
    img = run(graph(layer["prompt"], layer["seed"], height))
    if layer["seam"] == "model":
        # зсув на пів ширини виводить шов у середину, модель перемальовує смугу навколо нього
        rolled = np.roll(img, GW // 2, axis=1)
        alpha = np.full((height, GW, 1), 255, np.uint8)
        alpha[:, GW // 2 - SEAM : GW // 2 + SEAM] = 0  # прозоре = маска LoadImage
        name = upload(np.concatenate([rolled.astype(np.uint8), alpha], 2), "seam.png")
        fixed = run(graph(layer["prompt"], layer["seed"] + 1, height, name))
        w = np.clip((SEAM - np.abs(np.arange(GW) - GW // 2)) / (SEAM / 4), 0, 1)[
            None, :, None
        ]
        img = fixed * w + rolled * (1 - w)
    elif layer["seam"] == "blend":
        # по краях — зсунута копія, посередині — оригінал: краї сходяться, бо в оригіналі вони сусіди
        w = (1 - np.abs(np.arange(GW) / GW * 2 - 1))[None, :, None]
        img = img * w + np.roll(img, GW // 2, axis=1) * (1 - w)
    img = img[: layer["rows"] * SCALE]
    os.makedirs(CACHE, exist_ok=True)
    Image.fromarray(img.astype(np.uint8)).save(path)
    return img


def shrink(img, key):
    """Зелений фон — прозорий; зменшення в SCALE разів рахує колір лише з непрозорих пікселів."""
    rows = img.shape[0] // SCALE
    a = np.ones(img.shape[:2], np.float32)
    if key:
        a = (np.linalg.norm(img - GREEN, axis=2) > 170).astype(np.float32)
        img[..., 1] = np.minimum(
            img[..., 1], np.maximum(img[..., 0], img[..., 2])
        )  # зелений відсвіт країв

    def blocks(m):
        return m.reshape(rows, SCALE, W, SCALE, -1).sum(axis=(1, 3))

    asum = blocks(a[..., None])
    return blocks(img * a[..., None]) / np.maximum(asum, 1e-6), asum[
        ..., 0
    ] >= SCALE * SCALE / 2


def drop_edges(opaque):
    """Прибирає все, що торкається бічних чи нижнього краю: краї порожні — шар безшовний, а «земля»,
    яку модель домальовує під хмарами, зникає."""
    touch = np.zeros_like(opaque)
    touch[:, [0, -1]] = opaque[:, [0, -1]]
    touch[-1] = opaque[-1]
    while True:
        grown = touch.copy()
        grown[1:] |= touch[:-1]
        grown[:-1] |= touch[1:]
        grown[:, 1:] |= touch[:, :-1]
        grown[:, :-1] |= touch[:, 1:]
        grown &= opaque
        if (grown == touch).all():
            return opaque & ~touch
        touch = grown


def fill_down(rgb, opaque):
    """Під силуетом — суцільно до низу, кольором найближчого непрозорого пікселя вище."""
    last = np.maximum.accumulate(
        np.where(opaque, np.arange(len(rgb))[:, None], -1), axis=0
    )
    return rgb[np.maximum(last, 0), np.arange(W)[None, :]], last >= 0


def quantize(rgb, opaque, colors):
    """Палітра — лише з непрозорих пікселів; без дизерингу, прозорість — 0 або 255."""
    pal = Image.fromarray(rgb[opaque].astype(np.uint8)[None]).quantize(
        colors, Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    )
    q = (
        Image.fromarray(rgb.astype(np.uint8))
        .quantize(palette=pal, dither=Image.Dither.NONE)
        .convert("RGB")
    )
    return np.dstack([np.asarray(q), opaque.astype(np.uint8) * 255])


if __name__ == "__main__":
    for name in sys.argv[1:] or LAYERS:
        layer = LAYERS[name]
        strip, strip_opaque = shrink(generate(layer), layer["key"])
        if layer["seam"] == "drop":
            # предмети в повітрі — під верх шару: модель ставить їх посередині, де їх ховають скелі
            strip_opaque = drop_edges(strip_opaque)
            rise = np.argmax(strip_opaque.any(axis=1)) - 6
            strip, strip_opaque = np.roll(strip, -rise, axis=0), np.roll(strip_opaque, -rise, axis=0)
        rgb, opaque = np.zeros((H, W, 3)), np.zeros((H, W), bool)
        rgb[layer["top"] : layer["top"] + len(strip)] = strip
        opaque[layer["top"] : layer["top"] + len(strip)] = strip_opaque
        if layer["fill"]:
            rgb, opaque = fill_down(rgb, opaque)
        rgb = rgb * (1 - layer["haze"]) + HAZE * layer["haze"]
        Image.fromarray(quantize(rgb, opaque, layer["colors"])).save(
            OUT + name + ".png"
        )
        print("drawn", OUT + name + ".png", flush=True)
