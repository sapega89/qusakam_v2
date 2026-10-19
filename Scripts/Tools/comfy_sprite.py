"""Спрайти персонажів через ComfyUI (D239): Qwen-Image-Edit-2511 (Apache 2.0, GGUF Q5) малює персонажа з
референсу — кадру героя від художника — у його піксельному стилі, а кожен кадр анімації — з першого кадру цього
персонажа, щоб він лишався тим самим. Кадр 64 px збільшується ×16 (піксель — блок 16×16, модель тримає сітку),
скрипт вирізає фон (виміряний колір рамки), зменшує ×16 назад до 64×64, зводить усі кадри до однієї палітри
(з першого кадру — кольори не мерехтять) і ставить ступні всіх кадрів на один рядок. Лист — рядок на анімацію.
Кеш — %TEMP%/comfy_sprite (референс + підказка + зерно). Потрібен запущений ComfyUI з моделями з edit_graph().
Запуск: python -I -B Scripts/Tools/comfy_sprite.py <персонаж> [анімація ...]   (лист — коли всі кадри є в кеші)
"""

import hashlib
import json
import os
import sys
import tempfile
import urllib.request

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from comfy_backdrop import API, run, upload  # noqa: E402

CACHE = os.path.join(tempfile.gettempdir(), "comfy_sprite")
UP, CELL = 16, 64
MAGENTA = (255, 0, 255)
KEEP = (
    "Keep this exact character — {who}, the same pixel art style, thick dark outline, flat shading, colours, size "
    "and position. Change only the pose: {pose}. Keep the plain flat magenta background."
)
URIZEN_FRONT = (
    "turned to face the viewer: a front view of him standing idle, the thin dark iron circlet across his forehead above "
    "the small tattoo, both eyes visible, the coin amulet in the middle of his chest, arms at his sides"
)
URIZEN_STEP = "walking quickly to the right in the same side view facing right, %s leg stepping forward, %s leg back, the robe swinging"
URIZEN_RAISE = "in the same side view facing right: raising his right hand to shoulder height in front of him, a small golden coin in his palm"
URIZEN_SMITE = "in the same side view facing right: his right arm stretched high above his head, a shining golden coin held up in his hand"
ASTRIT_FRONT = (
    "turned to face the viewer: a front view of her standing idle, both amber eyes visible, the red bow on her ponytail, "
    "the huge spiked shield with the flame emblem at her side, the burning spell book in her other hand"
)
ASTRIT_STEP = (
    "running to the right in the same side view facing right, %s leg stepping forward, %s leg back, the ponytail flying "
    "behind her, the shield held in front of her"
)
ASTRIT_CROUCH = (
    "in the same side view facing right: crouching very low on bent knees, her head down behind the top of her huge "
    "spiked shield, ready to pounce"
)
ASTRIT_LEAP = "in the same side view facing right: leaping forward through the air, her huge spiked shield thrust out in front of her"
ASTRIT_SLAM = (
    "in the same side view facing right: slamming her huge spiked shield forward with all her weight, leaning into the "
    "blow, the flame emblem on the shield blazing"  # «полум'я рветься зі щита» різала межа кадру
)
# rows — рядки листа: (анімація, підказки кадрів); None — сам перший кадр (base).
CHARACTERS = {
    "bandit": dict(
        out="SampleProject/Assets/Characters/Enemies/bandit/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=2,
        colors=16,
        who="the same chibi desert bandit with the red face scarf, sand-coloured cloak and curved scimitar",
        base="Replace this character with a new one drawn in exactly the same pixel art style, size, chibi proportions, "
        "thick dark outline and flat shading: a desert bandit with a curved scimitar, a red head scarf wrapped over his "
        "face and a ragged sand-coloured cloak, standing in an idle fighting stance facing right. Keep the plain flat "
        "magenta background.",
        rows=[
            (
                "idle",
                [
                    None,
                    "breathing in the same fighting stance, head and shoulders slightly lower, the red scarf still covering his nose and mouth",
                ],
            ),
            (
                "walk",
                [
                    "walking to the right, left leg stepping forward, right leg back",
                    "walking to the right, legs passing each other, feet together",
                    "walking to the right, right leg stepping forward, left leg back",
                    "walking to the right, legs passing each other, body slightly raised",
                ],
            ),
            (
                "attack",
                [
                    "winding up, the scimitar raised high behind his head",
                    "slashing down and forward with the scimitar, lunging on his front leg",
                    "follow-through after the slash, the scimitar pointing down in front of him, leaning forward",
                    "recovering back into his fighting stance",
                ],
            ),
            (
                "death",
                [
                    "recoiling backwards from a heavy hit, head thrown back",
                    "falling to his knees, the scimitar dropping from his hand",
                    "collapsing forward onto the ground",
                    "lying on his back on the ground, arms spread, the scimitar on the ground beside him",
                ],
            ),
        ],
    ),
    # NPC: дорослі, на 1,5 вищі за героя (D172) — клітинка 64×96 при його ж пікселі; дихання з двох кадрів.
    "blacksmith": dict(
        out="SampleProject/Assets/Characters/NPCs/blacksmith/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=5,
        colors=16,
        who="the same burly bearded blacksmith with the leather apron and the smithing hammer",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a burly bearded blacksmith, a tall adult man filling the whole height of the picture, with a leather apron "
        "over a dark shirt, rolled-up sleeves, thick forearms and a smithing hammer in his right hand, standing idle facing "
        "right. Keep the plain flat magenta background.",
        rows=[
            (
                "idle",
                [
                    None,
                    "breathing, chest and shoulders slightly lower, the hammer resting at his side",
                ],
            )
        ],
    ),
    "merchant": dict(
        out="SampleProject/Assets/Characters/NPCs/merchant/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=6,
        colors=16,
        who="the same cheerful desert merchant in the red turban and the yellow robe with the leather satchel",
        base="Replace this character with a new one drawn in exactly the same pixel art style, thick dark outline and flat "
        "shading: a cheerful desert merchant, a tall adult man filling the whole height of the picture, in a red turban and a "
        "long yellow robe with a big leather satchel over his shoulder, holding a small scroll, standing idle facing right. "
        "Keep the plain flat magenta background.",
        rows=[
            (
                "idle",
                [None, "breathing, chest and shoulders slightly lower, the same smile"],
            )
        ],
    ),
    # Дід — дід Кусакама, тож теж ящур (lore, Sapega 2026-10-19): той самий вид, що й герой, тільки старий.
    "old_man": dict(
        out="SampleProject/Assets/Characters/NPCs/old_man/sheet.png",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        cell=(64, 96),
        seed=8,
        colors=16,
        who="the same old lizardfolk grandfather with the faded scales, the hooded brown robe and the walking staff",
        base="Change this character into his old grandfather: the same lizardfolk species with the same round head shape, big "
        "eyes and snout, but elderly — paler faded scales, droopy wrinkled eyelids, a slight hunch, a hooded brown robe and a "
        "gnarled wooden walking staff; taller than the reference character and filling the whole height of the picture; the same "
        "pixel art style, thick dark outline and flat shading; standing idle facing right. Keep the plain flat magenta background.",
        rows=[("idle", [None, "BOB:50"])],
    ),
    # Уризен — жрець бога контрактів (lore). Два ракурси (Sapega): фас — стоїть у лабораторії й портрет, профіль —
    # біг (enter, ним же й тікає) і смайт монетою (strike, монети падають на кадрі 6). Листи — як у старих кадрів
    # (6/12/12 по 64 px, ступні на рядку 58): сцени й build_laboratory.gd ріжуть їх без змін. Повтор підказки —
    # той самий кадр з кешу (тримає позу довше). Референс Sapega (обличчя анфас) тягнув профіль у пів-оберта —
    # опис словами дав чистий профіль.
    "urizen": dict(
        rows_out="SampleProject/Assets/Characters/Companions/urizen",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=31,
        colors=16,
        floor=58,
        who="the same chubby bald priest with the thin dark iron circlet, the small forehead tattoo, the golden coin amulet, "
        "the dark tunic with a belt and the long brown hooded robe",
        base="Replace this character with a new one drawn in exactly the same pixel art style, size, chibi proportions, thick "
        "dark outline and flat shading: a chubby bald human priest with a sly smile, a small dark tattoo on his forehead, a "
        "long brown robe over a dark tunic with a belt, a big round golden coin amulet on his chest and a thin dark iron "
        "circlet around his bald head. Strict side view: his head and body in profile facing right, his eye, nose and smile "
        "on the right side of his face, looking ahead to the right. Standing idle. Keep the plain flat magenta background.",
        rows=[
            ("idle", [URIZEN_FRONT] * 3 + ["BOB:45:idle:0"] * 3),
            (
                "enter",
                [URIZEN_STEP % ("left", "right")] * 3
                + [None] * 3
                + [URIZEN_STEP % ("right", "left")] * 3
                + [None] * 3,
            ),
            (
                "strike",
                [None]
                + [URIZEN_RAISE] * 2
                + [URIZEN_SMITE] * 6
                + [URIZEN_RAISE] * 2
                + [None],
            ),
        ],
    ),
    # Астрит — драконороджена варварка-тауматургиня з величезним шипастим щитом і книгою (lore): символи вогню. Як
    # Уризен — фас стоїть і портрет, профіль у русі. Листи старих розмірів: забіг (enter) і відхід (run) — той самий
    # біг, наскок щитом (strike) влучає на кадрі 5 (strike_frame).
    "astrit": dict(
        rows_out="SampleProject/Assets/Characters/Companions/astrit",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=43,
        colors=16,
        floor=58,
        who="the same fierce red-haired barbarian woman with the high ponytail and the red bow, the dark steel armour with red "
        "flame emblems, the huge round spiked shield with the flame emblem and the burning spell book",
        base="Replace this character with a new one drawn in exactly the same pixel art style, size, chibi proportions, thick "
        "dark outline and flat shading: a fierce adult barbarian woman with fiery red hair in a high ponytail tied with a big "
        "red bow, amber eyes, dark steel plate armour with red flame emblems, a huge round spiked shield with a big "
        "red-and-gold flame emblem held in front of her, and her other hand wreathed in red fire holding a small spell book "
        "with a golden flame on its cover. Strict side view: her head and body in profile facing right, her eye and nose on "
        "the right side of her face, looking ahead to the right. Standing idle. Keep the plain flat magenta background.",
        rows=[
            ("idle", [ASTRIT_FRONT] * 3 + ["BOB:44:idle:0"] * 3),
            (
                "enter",
                [ASTRIT_STEP % ("left", "right")] * 3
                + [None] * 3
                + [ASTRIT_STEP % ("right", "left")] * 3
                + [None] * 3,
            ),
            (
                "run",
                [ASTRIT_STEP % ("left", "right")] * 3
                + [None] * 3
                + [ASTRIT_STEP % ("right", "left")] * 3
                + [None] * 3,
            ),
            (
                "strike",
                [ASTRIT_CROUCH] * 2
                + [ASTRIT_LEAP] * 3
                + [ASTRIT_SLAM] * 3
                + [ASTRIT_CROUCH] * 2
                + [None] * 2,
            ),
        ],
    ),
    # Нові кадри героя з його ж кадру художника (D239): Idle дихає, Jump/Fall, Roll, Climb — досі позичали біг і ходьбу.
    "hero_idle": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=11,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        rows=[
            ("Idle", [None, "BOB:44"])
        ],  # модель розвертала героя й домальовувала хмарку подиху
    ),
    "hero_air": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=12,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        rows=[
            (
                "Jump",
                [
                    "crouching with bent knees, about to jump",
                    "in the same side view facing right: jumping up, knees tucked, one arm raised, cape flowing down behind him",
                ],
            ),
            (
                "Fall",
                [
                    "falling down, legs dangling, arms raised above his head, cape flowing up"
                ],
            ),
        ],
    ),
    "hero_roll": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=13,
        palette="hero",
        base=None,
        who="the same small lizard knight with the steel armour, dark red cape and tail",
        # Клубок крутиться поворотами того самого кадру (модель ламала героя догори ногами й домальовувала колоду),
        # вихід — присід зі стрибка. Спершу hero_air.
        rows=[
            (
                "Roll",
                [
                    "ducking forward into a roll, head tucked, body low",
                    "curled into a tight ball rolling forward, cape wrapped around him",
                    "ROT:Roll:1:90",
                    "ROT:Roll:1:180",
                    "ROT:Roll:1:270",
                    "FILE:SampleProject/Sprites/Player/Jump/1.png",
                ],
            )
        ],
    ),
    "hero_climb": dict(
        frames_out="SampleProject/Sprites/Player",
        ref="SampleProject/Sprites/Player/Walk/1.png",
        seed=1,
        palette="hero",
        floor=56,  # як у кадрів художника: на драбині герой не просідає на 3 px
        who="the same small lizard knight seen from behind, with the steel armour, dark red cape and tail",
        base="Keep this exact character: the same small lizard knight with the same steel armour, red cape, tail and colours, the "
        "same pixel art style with a thick dark outline and flat shading. Change only his pose and view: climbing pose seen from "
        "behind, both arms raised high as if gripping a ladder rung above his head, one leg lifted; no ladder is drawn. Keep the "
        "plain flat magenta background.",
        rows=[
            (
                "Climb",
                [
                    None,
                    "the same climbing pose seen from behind, but the other leg lifted and the arms one rung lower",
                ],
            )
        ],
    ),
}


def edit_graph(text, seed, ref_name, megapixels, design_name=None):
    def node(c, **i):
        return {"class_type": c, "inputs": i}

    g = {
        "unet": node("UnetLoaderGGUF", unet_name="qwen-image-edit-2511-Q5_K_M.gguf"),
        "clip": node(
            "CLIPLoader",
            clip_name="qwen_2.5_vl_7b_fp8_scaled.safetensors",
            type="qwen_image",
            device="default",
        ),
        "vae": node("VAELoader", vae_name="qwen_image_vae.safetensors"),
        "lora": node(
            "LoraLoaderModelOnly",
            model=["unet", 0],
            lora_name="Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors",
            strength_model=1.0,
        ),
        "shift": node("ModelSamplingAuraFlow", model=["lora", 0], shift=3.1),
        "model": node("CFGNorm", model=["shift", 0], strength=1.0),
        "ref": node("LoadImage", image=ref_name),
        "scaled": node(
            "ImageScaleToTotalPixels",
            image=["ref", 0],
            upscale_method="nearest-exact",
            megapixels=megapixels,  # = розмір референсу: блоки 16×16 не перемасштабовуються
            resolution_steps=16,
        ),
        "pos": node(
            "TextEncodeQwenImageEditPlus",
            clip=["clip", 0],
            prompt=text,
            vae=["vae", 0],
            image1=["scaled", 0],
        ),
        "neg": node(
            "TextEncodeQwenImageEditPlus",
            clip=["clip", 0],
            prompt="",
            vae=["vae", 0],
            image1=["scaled", 0],
        ),
        "latent": node("VAEEncode", pixels=["scaled", 0], vae=["vae", 0]),
        "sample": node(
            "KSampler",
            model=["model", 0],
            positive=["pos", 0],
            negative=["neg", 0],
            latent_image=["latent", 0],
            seed=seed,
            steps=4,
            cfg=1.0,
            sampler_name="euler",
            scheduler="simple",
            denoise=1.0,
        ),
        "decode": node("VAEDecode", samples=["sample", 0], vae=["vae", 0]),
        "save": node(
            "SaveImage", images=["decode", 0], filename_prefix="kusakam/sprite"
        ),
    }
    if design_name:
        g["design"] = node("LoadImage", image=design_name)
        g["design_scaled"] = node(
            "ImageScaleToTotalPixels",
            image=["design", 0],
            upscale_method="lanczos",
            megapixels=1.0,
            resolution_steps=16,
        )
        for k in ("pos", "neg"):
            g[k]["inputs"]["image2"] = ["design_scaled", 0]
    return g


def enlarge(path, cell):
    """Кадр героя знизу посередині клітинки cell на пурпурі, ×16 найближчим сусідом — для моделі. Вища клітинка —
    для дорослих NPC (D172: на 1,5 вищі за героя) при тому ж пікселі."""
    ref = Image.open(path).convert("RGBA")
    canvas = Image.new("RGBA", cell, MAGENTA + (255,))
    canvas.alpha_composite(ref, ((cell[0] - ref.width) // 2, cell[1] - ref.height))
    return np.asarray(canvas.resize((cell[0] * UP, cell[1] * UP), Image.NEAREST))


def edit(ref_rgba, text, seed, design=None):
    """Редагування з кешем: той самий референс, підказка й зерно — та сама картинка без моделі. design — шлях до
    картинки з дизайном персонажа (референс Sapega): друга картинка моделі, перша — стиль героя й полотно."""
    extra = open(design, "rb").read() if design else b""
    key = hashlib.sha1(
        ref_rgba.tobytes() + text.encode() + str(seed).encode() + extra
    ).hexdigest()[:16]
    path = os.path.join(CACHE, key + ".png")
    if not os.path.exists(path):
        name = upload(ref_rgba, "sprite_ref.png")
        design_name = (
            upload(np.asarray(Image.open(design).convert("RGBA")), "sprite_design.png")
            if design
            else None
        )
        os.makedirs(CACHE, exist_ok=True)
        mp = ref_rgba.shape[0] * ref_rgba.shape[1] / 1048576
        Image.fromarray(
            run(edit_graph(text, seed, name, mp, design_name)).astype(np.uint8)
        ).save(path)
        print("generated", text[:60], flush=True)
    return np.asarray(Image.open(path).convert("RGBA"))


def cached(ref_rgba, text, seed):
    key = hashlib.sha1(
        ref_rgba.tobytes() + text.encode() + str(seed).encode()
    ).hexdigest()[:16]
    return os.path.exists(os.path.join(CACHE, key + ".png"))


def shrink(img, cell, k=32):
    """Фон — виміряний колір рамки (модель малює «#FF00FF» як (244..252, 6..7, 245..247)); ×16 → клітинка
    кольором, якого в блоці найбільше (з k кольорів кадру). Середнє розмивало дрібні деталі моделі й краї, де її
    сітка не збігається з нашою, — татуювання Уризена ставало сірою плямою (Sapega: «дуже розмитий»)."""
    w, h = cell
    rgb = img[: h * UP, : w * UP, :3]
    f = rgb.astype(np.float32)
    border = np.concatenate(
        [
            f[:12].reshape(-1, 3),
            f[-12:].reshape(-1, 3),
            f[:, :12].reshape(-1, 3),
            f[:, -12:].reshape(-1, 3),
        ]
    )
    a = np.linalg.norm(f - np.median(border, axis=0), axis=2) > 75
    # тінь, яку модель кладе під ступні на пурпурі, — теж геть: пурпурових кольорів на персонажах немає
    a &= ~((f[..., 0] > f[..., 1] + 60) & (f[..., 2] > f[..., 1] + 60))
    pim = Image.fromarray(rgb[a][None].astype(np.uint8)).quantize(
        k, Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE
    )
    pal = np.array(pim.getpalette()[: 3 * k], dtype=np.float32).reshape(-1, 3)
    block = (np.arange(h * UP)[:, None] // UP) * w + np.arange(w * UP)[None] // UP
    counts = np.bincount(
        block[a] * k + np.asarray(pim)[0], minlength=h * w * k
    ).reshape(h, w, k)
    return pal[counts.argmax(axis=2)], counts.sum(axis=2) >= UP * UP / 2


def feet_row(opaque):
    rows = np.nonzero(opaque.any(axis=1))[0]
    return int(rows[-1]) if len(rows) else len(opaque) - 1


def bob(small, waist):
    """Дихання: усе вище рядка waist — на піксель нижче (кадр художника лишається його кадром)."""
    rgb, op = small[0].copy(), small[1].copy()
    rgb[1:waist], op[1:waist] = rgb[: waist - 1].copy(), op[: waist - 1].copy()
    op[0] = False
    return rgb, op


def rotate(small, deg):
    """Поворот на кратний 90° кут за годинниковою стрілкою навколо середини силуету — піксель-арт без втрат."""
    rgb, op = small
    ys, xs = np.nonzero(op)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    k = (-deg // 90) % 4
    crop_rgb, crop_op = np.rot90(rgb[y0:y1, x0:x1], k), np.rot90(op[y0:y1, x0:x1], k)
    h, w = crop_op.shape
    ny0, nx0 = int(round((y0 + y1) / 2 - h / 2)), int(round((x0 + x1) / 2 - w / 2))
    out_rgb, out_op = np.zeros_like(rgb), np.zeros_like(op)
    ys0, xs0 = max(0, ny0), max(0, nx0)
    ys1, xs1 = min(op.shape[0], ny0 + h), min(op.shape[1], nx0 + w)
    out_rgb[ys0:ys1, xs0:xs1] = crop_rgb[ys0 - ny0 : ys1 - ny0, xs0 - nx0 : xs1 - nx0]
    out_op[ys0:ys1, xs0:xs1] = crop_op[ys0 - ny0 : ys1 - ny0, xs0 - nx0 : xs1 - nx0]
    return out_rgb, out_op


def from_file(path):
    im = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)
    return im[..., :3], im[..., 3] > 128


SPECIAL = ("BOB", "ROT", "FILE")


def hero_palette():
    """Усі кольори кадрів художника — нові кадри героя мають лише їх (28 кольорів)."""
    cols = set()
    for path in sorted(os.listdir("SampleProject/Sprites/Player")):
        folder = os.path.join("SampleProject/Sprites/Player", path)
        for f in sorted(os.listdir(folder)) if path in ("Run", "Walk") else []:
            if f.endswith(".png"):
                px = np.asarray(
                    Image.open(os.path.join(folder, f)).convert("RGBA")
                ).reshape(-1, 4)
                cols |= {tuple(c[:3]) for c in px if c[3] > 128}
    return np.array(sorted(cols), dtype=np.float32)


if __name__ == "__main__":
    char = CHARACTERS[sys.argv[1]]
    only = sys.argv[2:]
    seed = char["seed"]
    cell = char.get("cell", (CELL, CELL))
    ref = enlarge(char["ref"], cell)
    # base=None — перший кадр сам кадр художника (новий кадр героя, D239), інакше модель робить його з референсу
    base = (
        ref
        if char["base"] is None
        else edit(ref, char["base"], seed, char.get("design"))
    )
    base_ref = base.copy()
    base_ref[..., 3] = 255
    frames = {}
    for anim, poses in char["rows"]:
        for i, pose in enumerate(poses):
            text = KEEP.format(who=char["who"], pose=pose) if pose else None
            if pose is None:
                frames[(anim, i)] = base
            elif pose.split(":")[0] in SPECIAL:
                frames[(anim, i)] = (
                    pose  # BOB:<рядок пояса> | ROT:<анімація>:<кадр>:<градуси> | FILE:<png>
                )
            elif not only or anim in only:
                frames[(anim, i)] = edit(base_ref, text, seed)
            elif cached(base_ref, text, seed):
                frames[(anim, i)] = edit(base_ref, text, seed)
    total = sum(len(p) for _, p in char["rows"])
    urllib.request.urlopen(
        urllib.request.Request(
            API + "/free",
            json.dumps({"unload_models": True, "free_memory": True}).encode(),
            {"Content-Type": "application/json"},
        )
    )
    if len(frames) < total:
        sys.exit(
            f"{len(frames)}/{total} frames cached — run the remaining animations, then the sheet is built"
        )
    small = {k: shrink(v, cell) for k, v in frames.items() if not isinstance(v, str)}
    for k, pose in frames.items():
        if isinstance(pose, str):
            kind, *arg = pose.split(":")
            if (
                kind == "BOB"
            ):  # BOB:<рядок пояса>[:<анімація>:<кадр>] — дихає перший кадр або вказаний
                small[k] = bob(
                    small[(arg[1], int(arg[2]))]
                    if len(arg) > 1
                    else shrink(base, cell),
                    int(arg[0]),
                )
            elif kind == "ROT":
                small[k] = rotate(small[(arg[0], int(arg[1]))], int(arg[2]))
            else:
                small[k] = from_file(":".join(arg))
    rgb0, op0 = shrink(base, cell)
    if char.get("palette") == "hero":
        pal_rgb = hero_palette()
    else:
        pim = Image.fromarray(rgb0[op0].astype(np.uint8)[None]).quantize(
            char["colors"], Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE
        )
        pal_rgb = np.array(
            pim.getpalette()[: 3 * char["colors"]], dtype=np.float32
        ).reshape(-1, 3)
    floor = char.get(
        "floor", feet_row(op0)
    )  # ступні — на рядок першого кадру; floor — явно (лінія ніг героя 56)
    cols = max(len(p) for _, p in char["rows"])
    cw, ch = cell
    sheet = np.zeros((ch * len(char["rows"]), cw * cols, 4), np.uint8)
    for r, (anim, poses) in enumerate(char["rows"]):
        for i, pose in enumerate(poses):
            rgb, op = small[(anim, i)]
            q = pal_rgb[
                np.linalg.norm(rgb[:, :, None, :] - pal_rgb[None, None], axis=3).argmin(
                    axis=2
                )
            ]
            frame = np.dstack([q, op * 255.0]).astype(np.uint8)
            shift = floor - feet_row(op)
            frame = np.roll(frame, shift, axis=0)
            if shift > 0:
                frame[:shift] = 0
            elif shift < 0:
                frame[shift:] = 0
            sheet[r * ch : (r + 1) * ch, i * cw : (i + 1) * cw] = frame
            if char.get("rows_out") and i == len(poses) - 1:
                # компаньйони — лист на анімацію (idle/enter/strike), як їх ріжуть сцени й build_laboratory.gd
                Image.fromarray(sheet[r * ch : (r + 1) * ch, : len(poses) * cw]).save(
                    os.path.join(char["rows_out"], anim + ".png")
                )
            if char.get("frames_out") and not (pose is None and char["base"] is None):
                # кадри героя — окремими текстурами, як його кадри художника (Player.tscn міняє Sprite2D:texture)
                folder = os.path.join(char["frames_out"], anim)
                os.makedirs(folder, exist_ok=True)
                Image.fromarray(frame).save(os.path.join(folder, f"{i + 1}.png"))
            print(f"{anim}[{i}] feet row {feet_row(op)} -> {floor}")
    if (
        "out" in char
    ):  # кадри героя — лише окремими текстурами (frames_out), листа гра не бере
        os.makedirs(os.path.dirname(char["out"]), exist_ok=True)
        Image.fromarray(sheet).save(char["out"])
    print(
        "sheet",
        char.get("out") or char.get("frames_out") or char.get("rows_out"),
        sheet.shape[1],
        "x",
        sheet.shape[0],
        "| feet row",
        floor,
    )
