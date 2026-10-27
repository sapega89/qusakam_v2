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
    # D643: фони п'яти бічних кімнат (гілки першої партії), повний екран як Lab/gen_far
    "LizardCave/gen_back": dict(
        seed=301,
        rows=H,
        top=0,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="the back wall of a sandstone cave under a canyon bridge seen straight on: warm orange and ochre rock, a narrow side tunnel at the right glowing faintly, in the middle a small carved shrine of the lizard shaman family with a stone lizard idol, offering bowls and old prayer cloths, shafts of dusty light from cracks in the ceiling, rocky floor along the bottom",
    ),
    # B162: смуга підлоги печери ящурів на лінії ходьби (план ×1.0 за героєм), кольори — палітрою gen_back (cave_planes.py)
    "LizardCave/gen_floor": dict(
        seed=411,
        rows=56,
        top=0,
        crop=True,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=12,
        quant="octree",
        prompt="a side cross-section of a thick sandstone cave floor spanning the full width and filling the frame from "
        "top to bottom: along the top a flat level walking surface of worn pale orange flagstones with a thin light edge, "
        "below it layered dark violet and maroon rock with cracks and a few small pebbles, seen straight on",
    ),
    "BanditCamp/gen_back": dict(
        seed=303,
        rows=H,
        top=0,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="a desert bandit camp on top of a dune seen from the side: ragged striped tents, piles of stolen crates, barrels and sacks, a cold campfire with a cooking pot, weapon racks with curved swords, a palisade of sharpened stakes, a dusty pink and violet sky at the top, sand along the bottom",
    ),
    "MesaClimb/gen_back": dict(
        seed=305,
        rows=H,
        top=0,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="the terraced side of a tall desert mesa seen straight on: layered red and ochre sandstone cliffs stepping up in ledges, a few dry thorn bushes clinging to the ledges, a narrow climbing route of rock shelves, a pale pink and lavender sky at the top, rubble along the bottom",
    ),
    "DragonMural/gen_back": dict(
        seed=307,
        rows=H,
        top=0,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="a small hidden cave chamber seen straight on: its whole back wall is a huge faded ancient mural of great winged dragons flying over the desert and tiny people bowing, painted in faded red, ochre and turquoise, cracked and peeling, dust in the air, a little light from a hole above, rocky floor along the bottom",
    ),
    "Cellar/gen_back": dict(
        seed=309,
        rows=H,
        top=0,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="the cellar of a city gatehouse seen straight on: low brick arches and thick stone pillars, old wine barrels and wooden crates stacked along the walls, cobwebs and hanging bat roosts in the dark vaults, a flight of stone stairs coming down at the left, one hanging oil lamp, damp stone floor along the bottom",
    ),
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
    # Окремі хмари для дрейфу (BACKLOG 19, A5b): по одній на кадр, drop + trim — спрайт хмари, не екран.
    "Clouds/gen_cloud_1": dict(
        seed=81,
        rows=H,
        top=0,
        seam="drop",
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=6,
        small=2,
        trim=True,
        prompt="one single big soft fluffy cumulus cloud with a rounded billowing top and a flat base in pale pink and lavender with violet shadows, floating in the middle with empty space around "
        f"it, {CHROMA}",
    ),
    "Clouds/gen_cloud_2": dict(
        seed=83,
        rows=H,
        top=0,
        seam="drop",
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=6,
        small=2,
        trim=True,
        prompt="one single long thin flat stratus cloud streak, wide and low, with soft wispy ends in pale pink and lavender with violet shadows, floating in the middle with empty space around "
        f"it, {CHROMA}",
    ),
    "Clouds/gen_cloud_3": dict(
        seed=85,
        rows=H,
        top=0,
        seam="drop",
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=6,
        small=2,
        trim=True,
        prompt="one single small round soft puffy cloud in pale pink and lavender with violet shadows, floating in the middle with empty space around "
        f"it, {CHROMA}",
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
    # Передні плани решти кімнат (BACKLOG 7, A5a): як у села — смуга внизу, рідкі групи з широкими проміжками.
    "Canyon/gen_front": dict(
        seed=131,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground objects along the bottom edge: jagged red sandstone boulders, dry yellow grass tufts, thorny "
        f"dead bushes and a fallen weathered log, with wide gaps between the groups, {MAGENTA}",
    ),
    "Road/gen_front": dict(
        seed=133,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground objects along the bottom edge: half-buried sandstone rocks, dry grass tufts, a broken "
        "wooden cart wheel, a small stack of wooden crates and a leaning wooden road post, with wide gaps between the "
        f"groups, {MAGENTA}",
    ),
    "Gates/gen_front": dict(
        seed=135,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground objects along the bottom edge: stacked wooden crates, grain sacks, wooden barrels, a "
        "red cloth draped over a cart, a few sandstone blocks and dry grass tufts, with wide gaps between the groups, "
        f"{MAGENTA}",
    ),
    "City/gen_front": dict(
        seed=137,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground objects along the bottom edge: market crates of fruit, woven baskets, big clay jars, a "
        "rolled carpet, a low wooden stall with striped red and blue cloth hanging from it, with wide gaps between the "
        f"groups, {MAGENTA}",
    ),
    "LabOut/gen_front": dict(
        seed=139,
        rows=110,
        top=H - 110,
        seam="model",
        key="magenta",
        shade=0.6,
        fill=False,
        haze=0,
        colors=6,
        prompt="foreground plants and objects along the bottom edge: tall reeds, low palm fronds, leafy desert shrubs, "
        f"mossy rocks and a broken stone column piece, with wide gaps between the groups, {MAGENTA}",
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
    # Лабораторія на кімнати (черга 9.4, D303): камера-ніша, ґрати перед нею (зникають після пробудження, 9.5),
    # операційний стіл у LabCells; брама і дальня стіна зали джина в LabBoss. Предмети — trim, без шва.
    "Lab/gen_cell": dict(
        seed=111,
        rows=150,
        top=0,
        seam="none",
        trim=True,
        block=4,  # ніша в 1.9 зросту героя: в'язень-дорослий (×1.5) вміщається
        cut=(142, 291),  # лише ніша: смуга підлоги обабіч (пікселі шару після block)
        keep=95,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=14,
        quant="octree",
        prompt="one single small prison cell niche in a dark stone dungeon wall seen straight on as a flat elevation: a "
        "shallow rectangular alcove of dark grey stone blocks, a heap of yellow straw on its floor, an iron shackle on a "
        "chain hanging from its back wall, a tiny barred window high up with a faint cold blue light, standing alone in "
        "the middle of the frame and filling a third of its width, with empty space on both sides, its base resting on "
        f"the bottom edge, no perspective, {CHROMA}",
    ),
    "Lab/gen_bars": dict(
        seed=113,
        rows=150,
        top=0,
        seam="none",
        trim=True,
        block=5,  # ґрати — у отвір ніші Lab/gen_cell
        cut=(136, 256),  # праві шість прутів із замком: пропорції отвору
        keep=81,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=8,
        prompt="one single rectangular frame of thick black iron prison bars seen straight on as a flat elevation: seven "
        "evenly spaced vertical round bars, two flat horizontal iron bands riveted across them, a small heavy padlock on "
        "the right band, rust stains, nothing behind the bars, the flat background visible between every bar, standing "
        f"alone in the middle of the frame and filling a third of its width, its base resting on the bottom edge, {CHROMA}",
    ),
    "Lab/gen_table": dict(
        seed=116,
        rows=150,
        top=0,
        small=2,  # стіл на пів шару — у кімнаті поруч із героєм, не на всю камеру
        seam="none",
        trim=True,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=14,
        quant="octree",
        prompt="one single alchemist operating table seen exactly from the side: a long flat dark iron table on four "
        "thick legs with brown leather straps and brass buckles, a small brass tray with surgical tools at one end, "
        "standing alone in the middle of the frame and filling half of its width, with empty space on both sides, its legs "
        f"resting on the bottom edge, flat even lighting, cool violet shadows, {CHROMA}",
    ),
    "Lab/gen_gates": dict(
        seed=117,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        cut=(185, 410),  # ліворуч — відблиск вогню на тлі
        keep=193,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=12,
        quant="octree",
        prompt="one single massive closed iron portcullis gate seen straight on as a flat elevation: a tall heavy grid "
        "of thick dark iron bars with sharp spikes along the bottom, set in a tall rectangular frame of big dark stone "
        "blocks with brass bolts and a brass plate on the lintel, standing alone in the middle of the frame and filling a "
        f"third of its width, its base resting on the bottom edge, warm firelight on the left, cool violet shadows, {CHROMA}",
    ),
    "Lab/gen_boss_far": dict(
        seed=119,
        rows=H,
        top=0,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="the far back wall of a huge underground furnace hall seen straight on: a giant cracked stone furnace "
        "with a glowing orange mouth in the middle, huge shattered glass vats broken open from inside, scorched black "
        "stone walls with soot, thick iron chains hanging from the dark vault, a ring of small carved cuneiform wedge "
        "marks on the wall glowing faint orange, clusters of tiny triangular wedges, no letters, "
        "lit only by firelight and embers, dark vaulted ceiling at the top, stone floor along the bottom",
        # руни читались латиницею (DPOB) — клинопис перемальовано по схваленій картинці (comfy_art_fixes.py boss_runes)
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
    # BACKLOG 29 + 38 (арт A2): будинки NPC-професій у Місті (каплиця жерця, хатина відьми, намет дервіша), дім
    # діда й дім старости в кінці села — окремі предмети на лінії підлоги, як кузня й крамниця (D292).
    "City/gen_chapel": dict(
        seed=291,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        cut=(163, 382),  # лише будинок: дюни обабіч модель домальовує
        keep=205,  # нижче — пісок під ним
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt=(
            "one single small desert sky chapel: a small one-storey whitewashed sandstone chapel with a flat roof, a small round pale blue dome on top and a slender open bell arch holding a small bronze bell, a tall narrow arched open doorway in its middle showing a dark interior, long pale blue and white cloth ribbons hanging on both sides of the door, a row of small clay oil lamps on the doorstep, a plain round window above the door, standing alone in the middle of the frame and filling half of its width, with empty space on both sides, its base resting on the bottom edge, it stands directly on bare sand, warm light on the top, cool violet shadows in the recesses, "
            f"{CHROMA}"
        ),
    ),
    "City/gen_witch_hut": dict(
        seed=293,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        cut=(155, 410),  # лише будинок: дюни обабіч модель домальовує
        keep=207,  # нижче — пісок під ним
        key="magenta",
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt=(
            "one single small witch's hut: a crooked round mud-brick hut with a pointed thatched roof of dry reeds, bundles of dried herbs and green leafy herbs hanging upside down from the eaves, a low dark open doorway in its middle, clay pots with green herb plants and small glass bottles on a wooden shelf beside the door, a small black iron cauldron on three legs by the wall, standing alone in the middle of the frame and filling half of its width, with empty space on both sides, its base resting on the bottom edge, it stands directly on bare sand, warm light on the top, cool violet shadows in the recesses, "
            f"{MAGENTA}"
        ),
    ),
    "City/gen_dervish_tent": dict(
        seed=295,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        cut=(144, 448),  # лише будинок: дюни обабіч модель домальовує
        keep=214,  # нижче — пісок під ним
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt=(
            "one single round desert dervish tent: a tall round tent of ochre and deep red striped cloth with a pointed top and a small round brass knob on the top, a scalloped fringe along the edge of its roof, its front flaps tied open on both sides showing a dark interior, a rolled carpet and a small brass incense burner beside the entrance, standing alone in the middle of the frame and filling half of its width, with empty space on both sides, its base resting on the bottom edge, it stands directly on bare sand, warm light on the top, cool violet shadows in the recesses, "
            f"{CHROMA}"
        ),
    ),
    "Village/gen_grandpa_house": dict(
        seed=381,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        cut=(119, 447),  # лише будинок: дюни обабіч модель домальовує
        keep=204,  # нижче — пісок під ним
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt=(
            "one single small old village house: a low one-storey adobe house with rounded walls and a flat roof, wooden roof beams sticking out, a small shuttered window, a faded blue cloth awning over a long wooden bench beside a dark open doorway in its middle, a walking staff leaning by the door, clay pots, a woven basket and a string of dried red peppers hanging by the window, standing alone in the middle of the frame and filling half of its width, with empty space on both sides, its base resting on the bottom edge, it stands directly on bare sand, warm light on the top, cool violet shadows in the recesses, "
            f"{CHROMA}"
        ),
    ),
    # Масштаб — як дім діда й крамниця (двері ~34×85 px шару): двоповерховий виходив ляльковим будиночком
    # (двері 32×58), а два поверхи в такому масштабі не влазять в одноклітинне село (Q58) — тож широкий одноповерховий.
    "Village/gen_elder_house": dict(
        seed=387,
        rows=220,
        top=0,
        seam="none",
        trim=True,
        cut=(52, 520),  # лише будинок: дюни обабіч модель домальовує
        holes=True,  # 2 px шпарина біля цоколя праворуч
        keep=210,  # нижче — пісок під ним
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt=(
            "one single wide village elder's house: a long one-storey adobe and sandstone house, grander and wider than its neighbours, with a flat roof terrace edged by a low stepped parapet, wooden roof beams sticking out under the parapet, a tall closed arched wooden double door in its middle reaching more than half the height of the wall, a big shuttered window on each side of the door, a covered porch in front of the door under a striped red and blue cloth awning held on two wooden posts, long red and blue cloth banners hanging on the wall, big clay jars beside the low stone step, seen at a slight angle from the left with its left side wall in shadow, standing alone in the middle of the frame and filling two thirds of its width, with empty space on both sides, its base resting on the bottom edge, it stands directly on bare sand, warm light on the top, cool violet shadows in the recesses, "
            f"{CHROMA}"
        ),
    ),
    # Підлоги інтер'єрів замість бежевої плитки (критики глибини 2026-10-27, знахідка 8): смуга від лінії ходьби до низу
    # кадру (64 рядки = 96 px світу), кольори — палітрою стіни кімнати (floor_strips.py)
    "Hall/gen_floor": dict(
        seed=611,
        rows=64,
        top=0,
        crop=True,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="a side cross-section of the floor of a grand sandstone palace hall spanning the full width and filling "
        "the frame from top to bottom: along the top a flat level walking surface of polished cream marble slabs with a "
        "long dark red carpet runner with thin golden borders lying along it, below it the front face of the floor of "
        "large dressed sandstone blocks with thin dark joints in warm shadow, seen straight on",
    ),
    "ElderHouse/gen_floor": dict(
        seed=613,
        rows=64,
        top=0,
        crop=True,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        quant="octree",
        prompt="a side cross-section of the floor of an old village house spanning the full width and filling the frame "
        "from top to bottom: along the top a flat level walking surface of worn brown wooden floor planks with scuffs, "
        "gaps and a few nail heads, below it a thick dark wooden floor beam and a low wall of plastered adobe in warm "
        "shadow, seen straight on",
    ),
    # Дім старости зсередини (BACKLOG 38): стіна-екран кімнати, як Hall/gen_wall у залі мера.
    "ElderHouse/gen_wall": dict(
        seed=385,
        rows=H,
        top=0,
        seam="model",
        key=None,
        shade=0,
        fill=False,
        haze=0,
        colors=16,
        prompt="the inner wall of a village elder's house seen straight on: plastered warm adobe walls with dark wooden "
        "ceiling beams across the top, two small arched windows with open wooden shutters, woven red and blue carpets "
        "hanging on the wall, wooden shelves with clay pots, jars and old scrolls, a low clay hearth with a small fire, "
        "a tall plain clay water jar and a round clay pot standing on the bare floor to the right of the hearth, a low "
        "stone plinth along the bottom, a clean empty floor in front, warm light from the hearth fire",
        # «warm lamp light» дав торшер з абажуром біля вогнища (технології в лорі немає) і темну пляму на підлозі;
        # картинка — стара з кешу, перемальована: --repaint 165-255 --denoise 0.9 (арт-директор, artA1A2; на 0.75
        # абажур ставав жаровнею з другим вогнем)
    ),
    # D774 Batch 0: передній план зали мера й табору бандитів — окремі предмети в FrontDark (×1.3, темний силует),
    # тож деталі й колір тут другорядні: важить обрис.
    "Decor/fg_hall/chandelier": dict(
        seed=701,
        rows=200,
        top=0,
        small=2,
        seam="none",
        trim=True,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=10,
        prompt="one single large ornate brass chandelier hanging on a short chain seen exactly from the side: a wide "
        "ring of curved brass arms holding small candles, hanging glass drops under the ring, a pointed finial at the "
        "bottom, the chain reaching the top edge, floating alone in the middle of the frame and filling a third of its "
        f"width, empty space all around it, {CHROMA}",
    ),
    "Decor/fg_hall/banner": dict(
        seed=703,
        rows=240,
        top=0,
        small=2,
        cut=(
            100,
            197,
        ),  # жердина — на всю ширину кадру: лише прапор між золотими кулями
        seam="none",
        trim=True,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=10,
        prompt="one single long narrow hanging cloth banner seen straight on: deep red cloth with a golden border and a "
        "plain golden disc with a raised rim in its upper half, hanging from a horizontal wooden rod with round golden "
        "knobs at the top edge, the bottom cut into a swallowtail with two golden tassels, floating alone in the middle "
        f"of the frame and filling a tenth of its width, empty space on both sides, {CHROMA}",
    ),
    "Decor/fg_hall/column": dict(
        seed=715,
        rows=440,  # колона від верху екрана до низу: 324 пікселі гри (486 світу) і запас
        top=0,
        cut=(
            220,
            353,
        ),  # праворуч — тінь колони на тлі (той самий колір, що й тінь ствола: силует трохи несиметричний)
        keep=397,  # нижче — смуга підлоги (рядки полотна: предмет починається з рядка 45)
        seam="none",
        trim=True,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=10,
        # «straight on» і «orthographic elevation» давали ізометрію з тінню й стінами обабіч
        prompt="a flat front elevation of one single tall sandstone column, perfectly symmetrical: a rectangular "
        "base, a straight shaft with vertical fluting, a rectangular capital, only the front face visible, no top "
        "surface and no side surfaces visible, no shadow, no floor, no walls, centred in the frame with wide empty space "
        f"on both sides, filling the frame from the bottom edge to the top edge, {CHROMA}",
    ),
    "Decor/fg_camp/rope_stake": dict(
        seed=717,
        rows=H,
        top=0,
        small=2,
        keep=131,  # нижче — смуга піску на всю ширину
        seam="none",
        trim=True,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=8,
        # «мотузки здіймаються вгору» — кілок у горбі піску; «жердина з відтяжками» — цілий намет із смугою землі
        prompt="one single wooden tent stake with two thick taut parallel ropes tied to its head, the ropes rising in "
        "a straight steep diagonal line from the stake at the bottom edge to the top edge of the frame, nothing else: "
        "no tent, no pole, no ground, no sand, the stake and the ropes alone in the middle of the frame with wide empty "
        f"space on both sides, seen from the side, {CHROMA}",
    ),
    "Decor/fg_camp/crate": dict(
        seed=709,
        rows=120,
        top=0,
        small=2,
        cut=(102, 205),  # смуга землі на всю ширину
        seam="none",
        trim=True,
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=8,
        prompt="one single big battered wooden crate with dark iron corner brackets and a thick rope tied around it, "
        "a sack leaning against it, seen exactly from the side, standing alone in the middle of the frame and filling a "
        f"fifth of its width, empty space on both sides, its base resting on the bottom edge, {CHROMA}",
    ),
    # M6a-1: дорога від мосту до села — гірська стежка й осипище (спільні далина, дим і передній план; збирає
    # design/shots/candidates/path_planes/path_planes.py). Бар'єр (прозорий купол із проламом, D795) — там же.
    "MountainPath/gen_far": dict(
        seed=501,
        rows=240,
        top=84,
        seam="model",
        key="green",
        shade=0,
        fill=True,
        haze=0.35,
        colors=8,
        prompt="a distant range of tall jagged bare rocky mountains with sharp peaks and deep valleys between them, "
        "dusty rose and sandy violet rock with violet shadows, spanning the full width and reaching the bottom edge, "
        f"{CHROMA}",
    ),
    # дим над селом — довгий шлейф, який вітер несе на захід через усе небо стежки (Сапега, ескіз 27.10: «десь з-за
    # краю екрану починається дим, потім ми підходимо до села»): тонкий кінчик на заході, широке тіло, на сході
    # спускається до джерела за східним краєм. Ширший за екран: width — ширина генерації в px гри при SCALE
    "MountainPath/gen_plume": dict(
        seed=722,  # 721 — стіна праворуч, 723 — клуб на пів неба; 722 — тонкий кінчик, клуб праворуч, стебло донизу
        rows=288,
        width=864,
        block=4,  # 648 px: шлейф займає верх неба, а не пів екрана
        keep=186,  # нижче — димар і смуга землі, які модель ставить під джерелом
        top=0,
        seam="none",
        trim=True,
        blob=True,
        spill=8,
        khaki=True,  # оливкові відблиски зеленого тла на верхах клубів
        key="green",
        shade=0,
        fill=False,
        haze=0.1,
        colors=8,
        prompt="one long horizontal plume of dark smoke blown sideways by a strong wind, drifting from right to left "
        "across the sky: at the right edge of the frame it is thick, wide and billowing in heavy rounded puffs, bending "
        "down toward the bottom right corner, and toward the left it grows steadily thinner and narrower until it ends "
        "in a thin ragged wispy pointed tip in the left third of the frame, the left quarter of the frame completely "
        "empty, charcoal grey and dark violet smoke, the plume floating in the upper half of the frame with empty space "
        f"above it, {CHROMA}",
    ),
    "MountainPath/gen_mid": dict(
        seed=505,
        rows=200,
        top=124,
        seam="model",
        key="green",
        spill=10,  # сіро-оливкова кромка скелі на зеленому тлі
        khaki=True,
        shade=0,
        fill=True,
        haze=0.2,
        colors=12,
        quant="octree",
        prompt="a ridge of rugged mountain cliffs and tall rock spires, red-orange and ochre sandstone with horizontal "
        "rock strata, a few dry brown thorn bushes clinging to the ledges, spanning the full width and reaching the "
        f"bottom edge, warm light on the tops, cool violet shadows in the cracks, {CHROMA}",
    ),
    # смуга стежки під ногами (×1.0, рядок 0 — лінія ходьби), як LizardCave/gen_floor
    "MountainPath/gen_ground": dict(
        seed=508,
        rows=80,
        top=0,
        crop=True,
        seam="model",
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=12,
        quant="octree",
        # 507 — плита з обрізаними краями; 508 без ключа — блакитне небо над землею: небо — ключ, рядок 0 знаходить
        # path_planes.py (перший суцільний рядок)
        prompt="a side cross-section of solid rocky mountain ground filling the lower four fifths of the frame and "
        "spanning the full width edge to edge: its top is a flat level walking surface of packed reddish dirt and flat "
        "stones with a thin light edge and a few pebbles, continuing past the left and right edges, below it layered "
        f"red-orange and dark violet rock strata with cracks down to the bottom edge, seen straight on, {CHROMA} above the ground",
    ),
    "MountainPath/gen_waymarker": dict(
        seed=513,
        rows=220,
        top=0,
        height=58,  # 1 H (64 арту) на плані ×0.9 — world_scale_plan
        seam="none",
        trim=True,
        blob=True,
        spill=12,  # оливкова трава, яку модель садить під стовпом
        key="green",
        shade=0,
        fill=False,
        haze=0,
        colors=12,
        quant="octree",
        # 509/512 — стовп на схилі з піском і травою: модель домальовує стежку до «waymarker of a mountain path»
        prompt="one single small broken square sandstone pillar, cracked across with its top corner broken off, a "
        "carved spiral rune and a carved arrow on its front face, a faded blue cloth ribbon tied around its middle, seen "
        "exactly from the side, the object alone floating in the middle of the frame and filling a sixth of its width, "
        "the whole pillar visible with its flat bottom edge, no ground, no grass, no shadow, empty space all around it, "
        f"warm light on the top, cool violet shadows in the recesses, {CHROMA}",
    ),
    # заслін переднього плану (D750: FrontDark ×1.3, затемнений модуляцією сцени)
    "MountainPath/gen_front": dict(
        seed=511,
        rows=240,
        top=0,
        seam="none",
        trim=True,
        keep=224,  # нижче — смуга землі на всю ширину
        cut=(205, 410),
        key="green",
        shade=0.3,
        fill=False,
        haze=0,
        colors=8,
        prompt="one single tall jagged rock spire with a dead twisted leafless tree growing from a crack near its "
        "top, its dry branches reaching sideways, standing alone in the middle of the frame and filling a third of its "
        f"width, with empty space on both sides, its base resting on the bottom edge, warm light on the top, cool violet "
        f"shadows in the cracks, {CHROMA}",
    ),
    # M6a-2a: ущелина зі струмком (збирає design/shots/candidates/gorge_planes/gorge_planes.py). Заслін D750 біля води:
    # валуни з сухим очеретом (×1.3, затемнений модуляцією сцени)
    "StreamGorge/gen_front": dict(
        seed=811,
        rows=240,
        top=0,
        seam="none",
        trim=True,
        keep=188,  # нижче — смуга землі на всю ширину
        cut=(170, 412),
        spill=10,
        khaki=True,
        key="green",
        shade=0.3,
        fill=False,
        haze=0,
        colors=8,
        prompt="one single cluster of three large rounded boulders with tall dry tan reeds and rushes growing between "
        "them, their thin stalks and seed heads reaching high above the stones, standing alone in the middle of the frame "
        "and filling a third of its width, with empty space on both sides, its base resting on the bottom edge, warm "
        f"light on the tops, cool violet shadows in the cracks, {CHROMA}",
    ),
}
# шлейф ущелини (D796: ближчий і більший) — та сама генерація, що й на стежці (кеш). Сапега: «дим має бути видно, що за
# наступним екраном спалене село» — тож трохи менший, ніж був (×3 давав клуб на пів неба над власною стіною ущелини):
# height — висота всього диму з обрізаним стеблом у px шару (сира 716 рядків → ×0.85 від зменшення в 3 рази)
LAYERS["StreamGorge/gen_plume"] = {
    **LAYERS["MountainPath/gen_plume"],
    "block": 3,
    "height": 203,
    "keep": 211,  # рядок сирої 744 (зріз стебла) × 0.85 / 3
    "haze": 0.2,  # далі за гребенем — блідіший
}
# скельні уступи (M6a-2b): найбільший шлейф дороги (D796) — дим спаленого села просто за проходом; сира × 1.12 / 3
LAYERS["RockLedges/gen_plume"] = {
    **LAYERS["MountainPath/gen_plume"],
    "block": 3,
    "height": 267,
    "keep": 278,
}


def graph(text, seed, height, image=None, denoise=1.0, width=GW):
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
            {"width": width, "height": height, "batch_size": 1},
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
    tag = [layer["prompt"], STYLE, layer["seed"], layer["rows"], layer["seam"]]
    if layer.get(
        "width"
    ):  # ширший за екран шар (шлейф диму); без width ключ кешу старий
        tag.append(layer["width"])
    tag = json.dumps(tag)
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
    img = run(graph(text, layer["seed"], height, width=layer.get("width", W) * SCALE))
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


def fit_height(img, h):
    """Предмет рівно h px генерації заввишки (рамка всього, що не фон): точні розміри world_scale_plan — сира
    генерація масштабується до зменшення, тож піксельна сітка шару лишається цілою."""
    from scipy import ndimage

    bg = np.median(img[:24].reshape(-1, 3), axis=0)
    labels, n = ndimage.label(np.linalg.norm(img - bg, axis=2) > KEY_DISTANCE)
    sizes = ndimage.sum(np.ones(labels.shape), labels, range(1, n + 1))
    ys = np.nonzero((labels == 1 + int(np.argmax(sizes))).any(axis=1))[
        0
    ]  # лише сам предмет, без крихт довкола
    f = h / (ys.max() - ys.min() + 1)
    size = (round(img.shape[1] * f), round(img.shape[0] * f))
    return np.asarray(
        Image.fromarray(img.astype(np.uint8)).resize(size, Image.LANCZOS), np.float32
    )


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
        # small — предмет, який модель малює завеликим: пікселі гри з більшого блоку; block — сам блок (ціле число
        # пікселів генерації на піксель гри, SCALE = 3 — без зменшення), коли потрібне не кратне SCALE зменшення
        block = layer.get("block", SCALE * layer.get("small", 1))
        raw = generate(layer)
        if layer.get("height"):  # height — точна висота предмета в пікселях шару
            raw = fit_height(raw, layer["height"] * block)
        strip, strip_opaque = shrink(raw, layer["key"], layer.get("spill", 0), block)
        if layer["seam"] == "drop":
            # предмети в повітрі — під верх шару: модель ставить їх посередині, де їх ховають скелі
            strip_opaque = drop_edges(strip_opaque)
            rise = np.argmax(strip_opaque.any(axis=1)) - 6
            strip, strip_opaque = (
                np.roll(strip, -rise, axis=0),
                np.roll(strip_opaque, -rise, axis=0),
            )
        rgb, opaque = (
            # предмет, вищий за екран (колона переднього плану), — полотно під нього
            np.zeros((max(H, layer["top"] + len(strip)), strip.shape[1], 3)),
            np.zeros((max(H, layer["top"] + len(strip)), strip.shape[1]), bool),
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
            # хакі-кромка скелі: зелене тло, змішане з пісковиком (MountainPath/gen_mid); поріг 20 ловить і оливкові
            # відблиски на клубах gen_plume (gen_mid від нього не змінився)
            if layer.get("khaki"):
                tinted |= (
                    (out[..., 3] > 0)
                    & (np.abs(px[..., 0] - px[..., 1]) < 25)
                    & (px[..., 1] > px[..., 2] + 20)
                )
            clean = (out[..., 3] > 0) & ~tinted
            if tinted.any() and clean.any():
                pal = np.unique(px[clean], axis=0)
                d = np.linalg.norm(px[tinted][:, None, :] - pal[None], axis=2)
                out[tinted, :3] = pal[d.argmin(axis=1)]
        for sx, dx, w, y0, y1 in layer.get(
            "patch", []
        ):  # латка: стовпці sx.. на місце dx.. (по колу — шар безшовний)
            out[y0:y1, (dx + np.arange(w)) % W] = out[y0:y1, (sx + np.arange(w)) % W]
        if layer.get("trim"):  # предмет, а не екран: лише його рамка
            if (
                layer["seam"] == "drop" or layer.get("blob")
            ):  # окрема хмара чи предмет: крихти довкола (шум ключа) розтягли б рамку — лише найбільша пляма
                from scipy import ndimage

                labels, n = ndimage.label(out[..., 3] > 0)
                sizes = ndimage.sum(np.ones(labels.shape), labels, range(1, n + 1))
                out[labels != 1 + int(np.argmax(sizes)), 3] = 0
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
