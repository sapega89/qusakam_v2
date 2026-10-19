"""Шари паралаксу через ComfyUI (D234): Qwen-Image (Apache 2.0) з Lightning-LoRA малює шар пласкою
матовою ілюстрацією в SCALE разів більшою за піксель гри; скрипт робить його безшовним по горизонталі,
прибирає зелений фон у прозорість, зменшує до пікселя гри й зводить до кількох кольорів. Шар — екран
W×H (864×486 світу при ×1.5); шар, що стоїть на землі, генерується смугою висотою rows від рядка top.
Пікселі робить зменшення, не модель: її «піксель-арт» не збігається з сіткою гри.
Генерації кешуються в CACHE (за підказкою, зерном, висотою): зміна обробки не кличе модель знову.
Потрібен запущений ComfyUI з API і моделі з graph(). Шари — LAYERS: назва = <кімната>/<файл> у OUT.
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
OUT = "SampleProject/Assets/Backgrounds/"
CACHE = os.path.join(tempfile.gettempdir(), "comfy_backdrop")
W, H, SCALE = 576, 324, 3
GW = W * SCALE
# Пів ширини смуги шва, px генерації: серцевина (пів смуги) перемальовується, далі маска м'яко спадає;
# не з нуля (SEAM_DENOISE) — модель бачить обидва боки шва. Жорстка вузька смуга різала пальми й зубці муру.
SEAM = 200
SEAM_DENOISE = 0.9
# Ключ — від кольору, яким модель справді залила фон (верхні рядки): «чистий» #FF00FF у неї (248,75,235), і
# поріг 170 від номіналу різав фіолетові тіні стін — будинки села світились наскрізь. 75 від виміряного
# лишає тіні; біля землі фон світлішає до ~55, тож менше не можна.
KEY_DISTANCE = 75
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
MAGENTA = "on a solid flat magenta (#FF00FF) background"
# Неба тут немає: модель домальовує в ньому промені, землю й текст, тож небо — градієнт із паку (plan5).
# seam — як шар стає безшовним: model — модель перемальовує смугу шва (суцільний краєвид), blend —
# перехресне змішування з собою, зсунутим на пів ширини (плавний градієнт без деталей), drop — прибирається все,
# що торкається бічних і нижнього країв (окремі предмети в повітрі: хмари). key — колір фону, що стає
# прозорим (green / magenta, None — без прозорості); fill — під силуетом суцільно до низу (шар стоїть на землі); haze — частка серпанку
# (модель на «туманне» сірить і фон); shade — затемнення (передній план — майже силует).
LAYERS = {
    "Canyon/gen_clouds": dict(
        seed=7,
        rows=H,
        top=0,
        seam="drop",
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=6,
        prompt="three big soft fluffy cumulus clouds in pale pink and lavender with violet shadows, floating "
        f"in the middle with empty space around them, {CHROMA}",
    ),
    "Canyon/gen_far": dict(
        seed=11,
        rows=200,
        top=70,
        seam="model",
        key="green",
        shade=0,
        fill=True,
        haze=0.35,
        colors=8,
        prompt="a distant range of flat-topped desert mesas and buttes, sandy beige and dusty violet rock with violet "
        f"shadows, spanning the full width and reaching the bottom edge, {CHROMA}",
    ),
    "Canyon/gen_walls": dict(
        seed=5,
        rows=240,
        top=H - 240,
        seam="model",
        key="green",
        shade=0,
        fill=True,
        haze=0.25,
        colors=12,
        prompt="a long wall of steep red-orange sandstone canyon cliffs with horizontal rock strata and jagged flat "
        "mesa tops, spanning the full width and filling the lower part down to the bottom edge, warm light on "
        f"the tops, cool violet shadows in the cracks, {CHROMA}",
    ),
    # Село (D236): будинки за площиною героя (основи — рядок 258 = підлога y 384), передній план — внизу кадру.
    "Village/gen_houses": dict(
        seed=21,
        rows=170,
        top=90,
        seam="model",
        key="magenta",
        shade=0,
        fill=False,
        haze=0.18,
        colors=16,
        quant="octree",
        prompt="a row of small desert village houses side by side: flat-roofed adobe and sandstone houses with "
        "wooden roof beams sticking out, arched wooden doors, small shuttered windows, striped red and blue cloth "
        "awnings, clay pots and baskets, a few date palms between the houses, spanning the full width, standing "
        f"on the bottom edge, {MAGENTA}",
    ),
    "Village/gen_front": dict(
        seed=31,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground plants and objects along the bottom edge: dry desert shrubs, tall reeds, spiky agave "
        "plants, a few rocks, big clay jars and a broken wooden fence, with wide gaps between the groups, "
        f"{MAGENTA}",
    ),
    # Решта кімнат (D237): спільні з каньйоном небо, хмари й мези; свій середній і передній план.
    "Road/gen_mid": dict(
        seed=41,
        rows=200,
        top=60,
        seam="model",
        key="green",
        shade=0,
        fill=True,
        haze=0.2,
        colors=12,
        prompt="rolling sand dunes with weathered sandstone rock formations, a natural rock arch and broken ancient stone "
        f"pillars half buried in the sand, spanning the full width and reaching the bottom edge, {CHROMA}",
    ),
    "Road/gen_front": dict(
        seed=43,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground rocks and desert plants along the bottom edge: boulders, dry thorny shrubs, spiky agave, an "
        f"animal skull and a toppled stone block, with wide gaps between the groups, {MAGENTA}",
    ),
    "Gates/gen_mid": dict(
        seed=51,
        rows=200,
        top=60,
        seam="model",
        key="green",
        shade=0,
        fill=True,
        haze=0.15,
        colors=14,
        prompt="a massive sandstone city wall with crenellations and two tall square gate towers flanking a big arched "
        "wooden gate, long red banners with a plain golden disc with a raised rim, the wall stands directly on bare sand, spanning the full width and reaching the bottom "
        f"edge, {CHROMA}",
    ),
    "City/gen_far": dict(
        seed=61,
        rows=200,
        top=40,
        seam="model",
        key="green",
        shade=0,
        fill=True,
        haze=0.4,
        colors=10,
        prompt="a distant city skyline: sandstone towers, domed palaces and slender minarets behind a long crenellated "
        f"wall, spanning the full width and reaching the bottom edge, {CHROMA}",
    ),
    "City/gen_near": dict(
        seed=63,
        rows=190,
        top=70,
        seam="model",
        key="magenta",
        shade=0,
        fill=False,
        haze=0.18,
        colors=16,
        quant="octree",
        prompt="a row of tall city houses side by side: two- and three-storey sandstone and plastered houses with arched "
        "windows, wooden balconies, colourful striped market awnings, hanging carpets and lanterns, market stalls "
        f"with clay pots and baskets in front, spanning the full width, standing on the bottom edge, {MAGENTA}",
    ),
    "City/gen_front": dict(
        seed=65,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground market clutter along the bottom edge: wooden crates, grain sacks, big clay jars, baskets of "
        f"fruit and a wooden cart wheel, with wide gaps between the groups, {MAGENTA}",
    ),
    "LabOut/gen_mid": dict(
        seed=73,
        rows=220,
        top=40,
        seam="model",
        key="magenta",
        shade=0,
        fill=True,
        haze=0.15,
        colors=14,
        quant="octree",
        prompt="a lush desert oasis: a calm blue pool in the middle ground with reeds along its edge, a grove of date "
        "palms with bright olive green fronds, a towering sandstone rock pillar behind and a few ruined ancient stone "
        f"columns, spanning the full width and reaching the bottom edge, {MAGENTA}",
    ),
    "Hall/gen_wall": dict(
        seed=81,
        rows=H,
        top=0,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        prompt="the inner wall of a grand sandstone hall seen straight on: tall arched niches between carved columns, long "
        "red banners with a plain golden disc with a raised rim hanging in the niches, a carved frieze along the top and a stone "
        "plinth along the bottom, warm lantern light",
    ),
    # Задній ряд дахів села (критик: у проміжках між будинками сяяли скелі — «просвічується»); пальми тут.
    "Village/gen_back": dict(
        seed=25,
        rows=170,
        top=70,
        seam="model",
        key="magenta",
        shade=0,
        fill=True,
        haze=0.35,
        colors=10,
        quant="octree",
        prompt="a second row of desert village rooftops seen from the street: flat adobe roofs at different heights, a "
        "small round dome and a square watchtower, date palms with olive green fronds rising between the roofs, simple "
        f"shapes with little detail, spanning the full width, standing on the bottom edge, {MAGENTA}",
    ),
    # Свій передній план для брами й оази: той самий череп три кімнати поспіль (критик).
    "Gates/gen_front": dict(
        seed=53,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground along the bottom edge: boulders, dry thorny shrubs, a toppled carved stone block, broken "
        f"spears and a fallen wooden barricade, with wide gaps between the groups, {MAGENTA}",
    ),
    "LabOut/gen_front": dict(
        seed=75,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground along the bottom edge: tall reeds and papyrus, broad water plants, smooth river stones and a "
        f"few small palm shoots, with wide gaps between the groups, {MAGENTA}",
    ),
}


def graph(text, seed, height, image=None, denoise=1.0):
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
        "pos": ("CLIPTextEncode", {"clip": ["clip", 0], "text": text}),
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
                "denoise": denoise,
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


def seam_pass(img, layer, text, height):
    """Модель перемальовує смугу посередині картинки: серцевина — повністю, далі маска м'яко спадає."""
    ramp = np.clip((np.abs(np.arange(GW) - GW // 2) - SEAM / 2) / (SEAM / 2), 0, 1)  # 0 — серцевина, 1 — поза смугою
    alpha = np.repeat((ramp * 255).astype(np.uint8)[None, :, None], height, axis=0)  # прозоре = маска LoadImage
    name = upload(np.concatenate([img.astype(np.uint8), alpha], 2), "seam.png")
    fixed = run(graph(text, layer["seed"] + 1, height, name, SEAM_DENOISE))
    # у пікселях — лише вузька облямівка: м'який перехід дає маска моделі, а широке змішування двох різних
    # картинок лишало напівпрозорих «привидів» (бліда пальма, зелена смуга в стінах каньйону)
    w = np.clip((SEAM - np.abs(np.arange(GW) - GW // 2)) / 30, 0, 1)[None, :, None]
    return fixed * w + img * (1 - w)


def cache_path(layer):
    tag = json.dumps([layer["prompt"], STYLE, layer["seed"], layer["rows"], layer["seam"]])
    return os.path.join(CACHE, hashlib.sha1(tag.encode()).hexdigest()[:16] + ".png")


def reseam(layer):
    """Шов шарів, зроблених першою версією (жорстка вузька смуга), — заново, на схваленій картинці з кешу: її шов уже
    посередині, тож поза смугою все лишається як було."""
    path = cache_path(layer)
    img = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    height = -(-layer["rows"] * SCALE // 16) * 16
    padded = np.concatenate([img, np.repeat(img[-1:], height - len(img), axis=0)])
    img = seam_pass(padded, layer, f"{layer['prompt']}, {STYLE}", height)[: len(img)]
    Image.fromarray(img.astype(np.uint8)).save(path)


def generate(layer):
    """Картинка шару в px генерації, безшовна по горизонталі для seam model / blend."""
    path = cache_path(layer)
    if os.path.exists(path):
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    height = -(-layer["rows"] * SCALE // 16) * 16  # сторони латента кратні 16
    text = f"{layer['prompt']}, {STYLE}"
    img = run(graph(text, layer["seed"], height))
    if layer["seam"] == "model":
        img = seam_pass(np.roll(img, GW // 2, axis=1), layer, text, height)  # зсув виводить шов у середину
    elif layer["seam"] == "blend":
        # по краях — зсунута копія, посередині — оригінал: краї сходяться, бо в оригіналі вони сусіди
        w = (1 - np.abs(np.arange(GW) / GW * 2 - 1))[None, :, None]
        img = img * w + np.roll(img, GW // 2, axis=1) * (1 - w)
    img = img[: layer["rows"] * SCALE]
    os.makedirs(CACHE, exist_ok=True)
    Image.fromarray(img.astype(np.uint8)).save(path)
    return img


def shrink(img, key):
    """Фон — прозорий; зменшення в SCALE разів рахує колір лише з непрозорих пікселів."""
    rows = img.shape[0] // SCALE
    a = np.ones(img.shape[:2], np.float32)
    if key:
        bg = np.median(img[:24].reshape(-1, 3), axis=0)
        a = (np.linalg.norm(img - bg, axis=2) > KEY_DISTANCE).astype(np.float32)
    if key == "green":
        img[..., 1] = np.minimum(img[..., 1], np.maximum(img[..., 0], img[..., 2]))  # зелений відсвіт країв

    def blocks(m):
        return m.reshape(rows, SCALE, W, SCALE, -1).sum(axis=(1, 3))

    asum = blocks(a[..., None])
    return blocks(img * a[..., None]) / np.maximum(asum, 1e-6), asum[..., 0] >= SCALE * SCALE / 2


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


def quantize(rgb, opaque, colors, method="mediancut"):
    """Палітра — лише з непрозорих пікселів; без дизерингу, прозорість — 0 або 255. octree — де рідкі відтінки
    (зелене листя, синій тент) мусять уціліти: median-cut на 16 кольорах їх викидав."""
    how = Image.Quantize.FASTOCTREE if method == "octree" else Image.Quantize.MEDIANCUT
    pal = Image.fromarray(rgb[opaque].astype(np.uint8)[None]).quantize(colors, how, dither=Image.Dither.NONE)
    q = Image.fromarray(rgb.astype(np.uint8)).quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    return np.dstack([np.asarray(q), opaque.astype(np.uint8) * 255])


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    for name in names or LAYERS:
        layer = LAYERS[name]
        if "--reseam" in sys.argv:
            reseam(layer)
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
        rgb = (rgb * (1 - layer["haze"]) + HAZE * layer["haze"]) * (1 - layer["shade"])
        os.makedirs(os.path.dirname(OUT + name), exist_ok=True)
        Image.fromarray(quantize(rgb, opaque, layer["colors"], layer.get("quant", "mediancut"))).save(OUT + name + ".png")
        print("drawn", OUT + name + ".png", flush=True)
    # ComfyUI тримає моделі (~30 ГБ ОЗП разом із текстовим енкодером) і після роботи; на 32 ГБ це вичерпало
    # пам'ять системи — вивантажуємо одразу.
    urllib.request.urlopen(urllib.request.Request(API + "/free", json.dumps({"unload_models": True, "free_memory": True}).encode(),
                                                  {"Content-Type": "application/json"}))
