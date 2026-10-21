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
    # Решта кімнат (D237): спільні з каньйоном небо, хмари й мези; свій середній план. Переднього плану в кімнатах
    # заввишки в одну клітинку немає: камера показує рівно до низу бруківки, нижче місця нема.
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
        # намальовані ворота в мурі — за брамою-проходом (D314) читались як друга брама: замуровані стіною поруч
        patch=[(333, 253, 78, 146, 238), (180, 538, 92, 146, 238)],
        prompt="a massive sandstone city wall with crenellations and two tall square gate towers flanking a big arched "
        "wooden gate, long red banners with a plain golden disc with a raised rim, the wall stands directly on bare sand, spanning the full width and reaching the bottom "
        f"edge, {CHROMA}",
    ),
    # Брама як прохід (черга 8c, D314): герой іде крізь неї. Передній шар — дві вежі й міст над проходом, малюється
    # над героєм; прохід між ними прозорий до самої землі (open). У CityGates і в City стоїть та сама картинка: межа
    # кімнат — на ~70 % проходу. Замінила gen_gate (D258) — фасад брами, що читався як задник.
    "Gates/gen_passage_front": dict(
        seed=83,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        open=True,  # прохід під мостом — прозорий до низу: за героєм видно gen_passage_back
        cut=(57, 521),  # лише вежі й міст: стіни обабіч накривали б бій на дорозі
        keep=204,  # нижче — пісок, який модель стелить під вежами
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="one single massive desert city gateway frame seen straight on as a flat elevation with no perspective: two "
        "thick square sandstone towers with crenellated tops standing at the far left edge and at the far right edge, joined "
        "high above by a thick straight crenellated stone wall bridge with a row of carved stone blocks along its underside, "
        "the wide space between the two towers under the bridge completely empty and open down to the ground, showing the "
        "flat background through it, red banners with a plain golden disc with a raised rim on the towers, filling the full "
        f"width of the frame, the towers resting on the bottom edge, warm light on the top, cool violet shadows, {CHROMA}",
    ),
    # Стіна проходу за героєм: відчинені стулки брами, смолоскип; у сцені темніша (modulate) і обрізана по проходу.
    "Gates/gen_passage_back": dict(
        seed=85,
        rows=220,
        top=0,
        seam="none",
        crop=True,
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="a perfectly flat straight-on swatch of an old sandstone block wall in deep cool violet shadow, large "
        "rectangular stone blocks laid in even horizontal rows filling the whole frame edge to edge, a heavy brown wooden "
        "gate door leaf with iron bands standing open and lying flat against the wall on the left third, a small iron wall "
        "torch with a warm orange flame casting a soft warm glow on the stones in the middle, a strip of flat paving stones "
        "along the bottom edge, no perspective, no depth, no arches",
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
    # Лабораторія (D246): підземний зал без неба — світло лише від колб, ламп і кристалів (лор). Далекий зал
    # (×0.4), ряд обладнання на підлозі (×0.75, два варіанти на поверхи), передній план звисає зі стелі,
    # а slab — текстура підлог і стін, по яких ходить герой (crop: зберігається лише смуга).
    "Lab/gen_far": dict(
        seed=91,
        rows=H,
        top=0,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="the far back wall of a vast dim underground alchemist laboratory hall seen straight on: tall dark stone "
        "arches with iron beams, giant glass vats filled with glowing green and cyan liquid, brass pipes and copper tubes "
        "running along the walls, big round boilers with gauges, tall shelves crowded with glass flasks and jars, lit "
        "only by the glowing vats and hanging oil lamps, dark vaulted ceiling at the top, stone floor along the bottom",
    ),
    "Lab/gen_mid": dict(
        seed=93,
        rows=200,
        top=H - 200,
        seam="model",
        key="magenta",
        spill=60,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="a row of alchemist laboratory equipment standing side by side on the floor: tall glass vats with glowing "
        "green liquid and brass caps, wooden workbenches with retorts, alembics and bubbling flasks, tall wooden shelves "
        "full of colourful potion bottles and old books, a copper distillation still with coiled tubes, iron cabinets "
        f"with round gauges, spanning the full width, standing on the bottom edge, {MAGENTA}",
    ),
    "Lab/gen_mid2": dict(
        seed=95,
        rows=200,
        top=H - 200,
        seam="model",
        key="magenta",
        spill=60,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="a row of alchemist laboratory machines standing side by side on the floor: a large brass boiler with "
        "pressure gauges and valves, a big glass sphere on an iron stand with a glowing cyan crystal inside, racks of "
        "test tubes, an iron furnace with an orange glowing door, thick copper pipes rising from the machines, crates and "
        f"barrels, spanning the full width, standing on the bottom edge, {MAGENTA}",
    ),
    "Lab/gen_front": dict(
        seed=97,
        rows=110,
        top=0,
        seam="model",
        key="magenta",
        spill=60,
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground objects hanging down from the top edge: thick dark iron pipes running along the top with "
        "valves, drooping black cables, a few hanging glass lamps on chains, with wide empty gaps between the groups, "
        f"{MAGENTA}",
    ),
    "Lab/gen_slab": dict(
        seed=99,
        rows=64,
        top=0,
        crop=True,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=14,
        quant="octree",
        prompt="a side cross-section of a thick laboratory floor slab spanning the full width and filling the frame from "
        "top to bottom: along the top a dark iron grating walkway with a polished brass edge strip, below it riveted "
        "dark steel plates with bolts, a horizontal copper pipe running through the middle, seen straight on",
    ),
    # Спуск із каньйону (D256): камінь переднього плану, за який злазить Кусакам, і місток над ущелиною —
    # окремі предмети, не екрани: seam none (без шва), trim — картинка обрізається до самого предмета.
    "Canyon/gen_rock": dict(
        seed=101,
        rows=170,
        top=0,
        seam="none",
        trim=True,
        keep=131,  # нижче — смуга землі, яку модель домальовує під каменем: її не треба
        key="green",
        shade=0.3,
        fill=False,
        haze=0,
        colors=10,
        prompt="one single big weathered red-orange sandstone boulder with horizontal rock strata and a rounded top, "
        "standing alone in the middle of the frame with empty space on both sides, its base resting on the bottom edge, "
        f"warm light on the top, cool violet shadows in the cracks, {CHROMA}",
    ),
    # Місце медитації на вершині скелі Прайду (BACKLOG feedback 8): плаский камінь, на якому сідає Кусакам.
    "Canyon/gen_shrine": dict(
        seed=106,
        rows=120,
        top=0,
        small=2,  # модель малює камінь на пів шару — пікселі гри з блоків 6×6, камінь удвічі менший
        seam="none",
        trim=True,
        spill=12,  # оливкова тінь моделі на зеленому тлі
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=12,
        quant="octree",
        prompt="one single small low flat round sandstone slab for meditation, wide and only knee high, with a small "
        "cairn of three smooth stacked flat stones at its back end, an ancient spiral rune carved into its front face "
        "glowing softly golden, a faint golden shimmer rising above it, floating alone in the middle of the frame and "
        "filling only a third of its width, the whole slab visible with its rounded front side and its bottom edge, "
        "empty space all around it, no ground beneath it, warm light "
        f"on the top, cool violet shadows in the cracks, {CHROMA}",
    ),
    "Canyon/gen_bridge": dict(
        seed=103,
        rows=48,
        top=0,
        seam="none",
        trim=True,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=10,
        prompt="a long old rope bridge seen exactly from the side as one thin straight horizontal band spanning the full "
        "width from the left edge to the right edge: a deck of weathered brown wooden planks side by side, a thick rope "
        f"handrail running straight above the deck, a short thick wooden post at each end, {CHROMA}",
    ),
    # BACKLOG 14 (D292): будинки коваля й торговця — окремі предмети на дорозі, з дверей виходить NPC.
    "City/gen_forge": dict(
        seed=142,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        holes=True,  # темний дверний отвір, з якого виходить коваль
        cut=(122, 576),  # ліворуч — довга тінь, яку модель кидає на тло
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="one single small desert blacksmith forge house: a squat one-storey sandstone workshop with a flat roof, "
        "a short square brick chimney, a tall wide open arched doorway in its middle showing a dark interior with a faint "
        "orange glow of the furnace, an iron anvil and a wooden barrel beside the door, a crossed hammer and tongs emblem "
        "carved into the plain wall above the door, standing alone in the middle of the frame and filling half of its width, with empty space "
        f"on both sides, its base resting on the bottom edge, warm light on the top, cool violet shadows in the recesses, {CHROMA}",
    ),
    "Road/gen_shop": dict(
        seed=144,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        holes=True,  # темний вхід, з якого виходить торговець
        cut=(158, 412),  # лише будинок із крамом: дюни обабіч модель домальовує
        keep=198,  # нижче — пісок, який модель стелить під будинком
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="one single small roadside desert merchant shop: a one-storey sandstone and clay house with a flat roof, "
        "a red and yellow striped cloth awning over a tall wide open doorway in its middle showing a dark interior, clay "
        "pots, rolled carpets and wooden crates stacked beside the door, a hanging brass lantern, standing alone in the "
        "middle of the frame and filling half of its width, with empty space on both sides, its base resting on the "
        f"bottom edge, the house stands directly on bare sand, warm light on the top, cool violet shadows in the recesses, {CHROMA}",
    ),
    # Довша дорога (BACKLOG 23, D299): по орієнтиру на кожну нову ділянку — окремі предмети на лінії підлоги, як крамниця.
    "Road/gen_tower": dict(
        seed=231,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        cut=(187, 391),  # лише предмет: дюни обабіч модель домальовує
        keep=202,  # нижче — пісок під предметом
        key="green",
        shade=0,
        fill=False,
        haze=0.15,
        colors=14,
        quant="octree",
        prompt="one single ruined ancient desert watchtower: a tall square sandstone tower with its top broken off "
        "jaggedly, a dark empty arched window, crumbling blocks and a few fallen stones at its foot half buried in sand, "
        "standing alone in the middle of the frame and filling a third of its width, with empty space on both sides, its "
        f"base resting on the bottom edge, the tower stands directly on bare sand, warm light on the top, cool violet shadows in the recesses, {CHROMA}",
    ),
    "Road/gen_wreck": dict(
        seed=233,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        cut=(114, 394),  # лише предмет: дюни обабіч модель домальовує
        keep=189,  # нижче — пісок під предметом
        key="green",
        shade=0,
        fill=False,
        haze=0.1,
        colors=16,
        quant="octree",
        prompt="one single abandoned broken wooden merchant caravan wagon tipped on its side with one wheel off and "
        "lying beside it, a torn red and yellow striped cloth cover hanging loose, smashed wooden crates, spilled clay "
        "pots and a rolled carpet scattered around it, standing alone in the middle of the frame and filling half of its "
        "width, with empty space on both sides, resting on the bottom edge, the wreck lies directly on bare sand, warm "
        f"light on the top, cool violet shadows in the recesses, {CHROMA}",
    ),
    "Road/gen_shrine": dict(
        seed=235,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        cut=(218, 372),  # лише предмет: дюни обабіч модель домальовує
        keep=198,  # нижче — пісок під предметом
        key="green",
        shade=0,
        fill=False,
        haze=0.1,
        colors=14,
        quant="octree",
        prompt="one single old wayside shrine of a desert road: a tall narrow sandstone obelisk on a low stepped "
        "plinth, simple carved spiral runes on its face, a few small votive clay lamps and a faded blue cloth ribbon tied "
        "around it, standing alone in the middle of the frame and filling a quarter of its width, with empty space on "
        "both sides, its base resting on the bottom edge, it stands directly on bare sand, warm light on the top, cool "
        f"violet shadows in the recesses, {CHROMA}",
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
    ramp = np.clip(
        (np.abs(np.arange(GW) - GW // 2) - SEAM / 2) / (SEAM / 2), 0, 1
    )  # 0 — серцевина, 1 — поза смугою
    alpha = np.repeat(
        (ramp * 255).astype(np.uint8)[None, :, None], height, axis=0
    )  # прозоре = маска LoadImage
    name = upload(np.concatenate([img.astype(np.uint8), alpha], 2), "seam.png")
    fixed = run(graph(text, layer["seed"] + 1, height, name, SEAM_DENOISE))
    # у пікселях — лише вузька облямівка: м'який перехід дає маска моделі, а широке змішування двох різних
    # картинок лишало напівпрозорих «привидів» (бліда пальма, зелена смуга в стінах каньйону)
    w = np.clip((SEAM - np.abs(np.arange(GW) - GW // 2)) / 30, 0, 1)[None, :, None]
    return fixed * w + img * (1 - w)


def cache_path(layer):
    tag = json.dumps(
        [layer["prompt"], STYLE, layer["seed"], layer["rows"], layer["seam"]]
    )
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


def repaint(layer, x0, x1, denoise):
    """Перемальовує смугу x0..x1 (пікселі шару) схваленої картинки з кешу не з нуля: будова лишається, а
    напівпрозорі привиди й рвані тіні стають суцільними (будиночок із тентом у селі, D238)."""
    path = cache_path(layer)
    img = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    height = -(-layer["rows"] * SCALE // 16) * 16
    padded = np.concatenate([img, np.repeat(img[-1:], height - len(img), axis=0)])
    x = np.arange(GW)
    edge = 24
    ramp = np.clip(
        np.maximum(x0 * SCALE - x, x - x1 * SCALE) / edge, 0, 1
    )  # 0 — смуга, 1 — поза нею
    alpha = np.repeat(
        (ramp * 255).astype(np.uint8)[None, :, None], height, axis=0
    )  # прозоре = маска LoadImage
    name = upload(np.concatenate([padded.astype(np.uint8), alpha], 2), "repaint.png")
    fixed = run(
        graph(f"{layer['prompt']}, {STYLE}", layer["seed"] + 2, height, name, denoise)
    )
    w = (1 - ramp)[None, :, None]
    Image.fromarray((fixed * w + padded * (1 - w))[: len(img)].astype(np.uint8)).save(
        path
    )


def generate(layer):
    """Картинка шару в px генерації, безшовна по горизонталі для seam model / blend."""
    path = cache_path(layer)
    if os.path.exists(path):
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    height = -(-layer["rows"] * SCALE // 16) * 16  # сторони латента кратні 16
    text = f"{layer['prompt']}, {STYLE}"
    img = run(graph(text, layer["seed"], height))
    if layer["seam"] == "model":
        img = seam_pass(
            np.roll(img, GW // 2, axis=1), layer, text, height
        )  # зсув виводить шов у середину
    elif layer["seam"] == "blend":
        # по краях — зсунута копія, посередині — оригінал: краї сходяться, бо в оригіналі вони сусіди
        w = (1 - np.abs(np.arange(GW) / GW * 2 - 1))[None, :, None]
        img = img * w + np.roll(img, GW // 2, axis=1) * (1 - w)
    img = img[: layer["rows"] * SCALE]
    os.makedirs(CACHE, exist_ok=True)
    Image.fromarray(img.astype(np.uint8)).save(path)
    return img


def shrink(img, key, spill=0, block=SCALE):
    """Фон — прозорий; зменшення в block разів (SCALE, для дрібного предмета — більше) рахує колір лише з непрозорих
    пікселів. spill (для magenta) — ще й усе, де червоний і синій обидва більші за зелений на spill: темні пурпурні
    тіні, що модель кидає на фон."""
    rows = img.shape[0] // block
    cols = img.shape[1] // block
    a = np.ones(img.shape[:2], np.float32)
    if key:
        bg = np.median(img[:24].reshape(-1, 3), axis=0)
        a = (np.linalg.norm(img - bg, axis=2) > KEY_DISTANCE).astype(np.float32)
    if (
        spill and key == "green"
    ):  # тінь, яку модель кладе на зелене тло (оливкова), — геть
        a *= img[..., 1] - np.maximum(img[..., 0], img[..., 2]) < spill
    elif spill:
        a *= np.minimum(img[..., 0], img[..., 2]) - img[..., 1] < spill
    if key == "green":
        img[..., 1] = np.minimum(
            img[..., 1], np.maximum(img[..., 0], img[..., 2])
        )  # зелений відсвіт країв

    def blocks(m):
        return (
            m[: rows * block, : cols * block]
            .reshape(rows, block, cols, block, -1)
            .sum(axis=(1, 3))
        )

    asum = blocks(a[..., None])
    return blocks(img * a[..., None]) / np.maximum(asum, 1e-6), asum[
        ..., 0
    ] >= block * block / 2


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


def holes(opaque):
    """Прозоре, до якого від жодного краю картинки не дійти прозорим: прохід у брамі, вирізаний ключем."""
    reach = np.zeros_like(opaque)
    reach[[0, -1]] = ~opaque[[0, -1]]
    reach[:, [0, -1]] = ~opaque[:, [0, -1]]
    while True:
        grown = reach.copy()
        grown[1:] |= reach[:-1]
        grown[:-1] |= reach[1:]
        grown[:, 1:] |= reach[:, :-1]
        grown[:, :-1] |= reach[:, 1:]
        grown &= ~opaque
        if (grown == reach).all():
            return ~opaque & ~reach
        reach = grown


def fill_down(rgb, opaque):
    """Під силуетом — суцільно до низу, кольором найближчого непрозорого пікселя вище."""
    last = np.maximum.accumulate(
        np.where(opaque, np.arange(len(rgb))[:, None], -1), axis=0
    )
    return rgb[np.maximum(last, 0), np.arange(rgb.shape[1])[None, :]], last >= 0


def quantize(rgb, opaque, colors, method="mediancut"):
    """Палітра — лише з непрозорих пікселів; без дизерингу, прозорість — 0 або 255. octree — де рідкі відтінки
    (зелене листя, синій тент) мусять уціліти: median-cut на 16 кольорах їх викидав."""
    how = Image.Quantize.FASTOCTREE if method == "octree" else Image.Quantize.MEDIANCUT
    pal = Image.fromarray(rgb[opaque].astype(np.uint8)[None]).quantize(
        colors, how, dither=Image.Dither.NONE
    )
    q = (
        Image.fromarray(rgb.astype(np.uint8))
        .quantize(palette=pal, dither=Image.Dither.NONE)
        .convert("RGB")
    )
    return np.dstack([np.asarray(q), opaque.astype(np.uint8) * 255])


if __name__ == "__main__":
    names = [
        a
        for i, a in enumerate(sys.argv[1:], 1)
        if not a.startswith("--") and sys.argv[i - 1] not in ("--repaint", "--denoise")
    ]
    for name in names or LAYERS:
        layer = LAYERS[name]
        if "--reseam" in sys.argv:
            reseam(layer)
        if (
            "--repaint" in sys.argv
        ):  # --repaint X0-X1 [--denoise D]: смуга в пікселях шару
            x0, x1 = map(int, sys.argv[sys.argv.index("--repaint") + 1].split("-"))
            d = (
                float(sys.argv[sys.argv.index("--denoise") + 1])
                if "--denoise" in sys.argv
                else 0.6
            )
            repaint(layer, x0, x1, d)
        # small — предмет, який модель малює завеликим: пікселі гри з більшого блоку
        strip, strip_opaque = shrink(
            generate(layer),
            layer["key"],
            layer.get("spill", 0),
            SCALE * layer.get("small", 1),
        )
        if layer["seam"] == "drop":
            # предмети в повітрі — під верх шару: модель ставить їх посередині, де їх ховають скелі
            strip_opaque = drop_edges(strip_opaque)
            rise = np.argmax(strip_opaque.any(axis=1)) - 6
            strip, strip_opaque = (
                np.roll(strip, -rise, axis=0),
                np.roll(strip_opaque, -rise, axis=0),
            )
        rgb, opaque = (
            np.zeros((H, strip.shape[1], 3)),
            np.zeros((H, strip.shape[1]), bool),
        )
        rgb[layer["top"] : layer["top"] + len(strip)] = strip
        opaque[layer["top"] : layer["top"] + len(strip)] = strip_opaque
        if layer["fill"]:
            rgb, opaque = fill_down(rgb, opaque)
        if layer.get(
            "open"
        ):  # прохід, вирізаний ключем, — прозорий і нижче, до низу (там модель домалювала далечінь)
            hole = holes(opaque)
            for x in np.nonzero(hole.any(axis=0))[0]:
                opaque[np.argmax(hole[:, x]) :, x] = False
        if layer.get(
            "holes"
        ):  # дірки всередині предмета — найтемнішим його кольором (темний прохід)
            hole = holes(opaque)
            rgb[hole] = rgb[opaque][np.argmin(rgb[opaque].sum(axis=1))]
            opaque = opaque | hole
        rgb = (rgb * (1 - layer["haze"]) + HAZE * layer["haze"]) * (1 - layer["shade"])
        os.makedirs(os.path.dirname(OUT + name), exist_ok=True)
        out = quantize(rgb, opaque, layer["colors"], layer.get("quant", "mediancut"))
        if layer.get(
            "crop"
        ):  # текстура, а не екран (поверхні лабораторії): лише смуга rows
            out = out[layer["top"] : layer["top"] + layer["rows"]]
        if layer.get("keep"):  # рядки шару від keep і нижче — прозорі
            out[layer["keep"] :, :, 3] = 0
        if layer.get(
            "cut"
        ):  # стовпці шару x0..x1 — решта прозора (обрізані стіни обабіч брами)
            out[:, : layer["cut"][0], 3] = 0
            out[:, layer["cut"][1] :, 3] = 0
        if (
            layer["key"] == "green"
        ):  # бірюзова кромка — відсвіт зеленого тла: у найближчий не-зелений колір шару
            px = out[..., :3].astype(int)
            tinted = (
                (out[..., 3] > 0)
                & (px[..., 1] > px[..., 0] + 15)
                & (px[..., 1] >= px[..., 2] - 10)
            )
            clean = (out[..., 3] > 0) & ~tinted
            if tinted.any() and clean.any():
                pal = np.unique(px[clean], axis=0)
                d = np.linalg.norm(px[tinted][:, None, :] - pal[None], axis=2)
                out[tinted, :3] = pal[d.argmin(axis=1)]
        for sx, dx, w, y0, y1 in layer.get("patch", []):  # латка: стовпці sx.. на місце dx.. (по колу — шар безшовний)
            out[y0:y1, (dx + np.arange(w)) % W] = out[y0:y1, (sx + np.arange(w)) % W]
        if layer.get("trim"):  # предмет, а не екран: лише його рамка
            ys, xs = np.nonzero(out[..., 3])
            out = out[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
        if layer.get(
            "shadow"
        ):  # предмет стоїть на землі: власна тінь-овал найтемнішим кольором під його низом
            h, w = out.shape[:2]
            sh = layer["shadow"]
            canvas = np.zeros((h + sh, w + 2 * sh, 4), np.uint8)
            opaque_px = out[out[..., 3] > 0][:, :3]
            dark = opaque_px[np.argmin(opaque_px.astype(int).sum(axis=1))]
            yy, xx = np.mgrid[: h + sh, : w + 2 * sh]
            # тінь щільно під низом предмета (ледь виглядає з-під нього), а не смугою нижче — інакше він висить
            ellipse = ((xx - (w + 2 * sh) / 2) / (w * 0.45)) ** 2 + (
                (yy - (h - sh)) / (sh * 0.75)
            ) ** 2 <= 1
            canvas[ellipse] = (*dark, 255)
            body = out[..., 3] > 0
            canvas[:h, sh : sh + w][body] = out[body]
            out = canvas
        Image.fromarray(out).save(OUT + name + ".png")
        print("drawn", OUT + name + ".png", flush=True)
    # ComfyUI тримає моделі (~30 ГБ ОЗП разом із текстовим енкодером) і після роботи; на 32 ГБ це вичерпало
    # пам'ять системи — вивантажуємо одразу.
    urllib.request.urlopen(
        urllib.request.Request(
            API + "/free",
            json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )
