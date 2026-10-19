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
}


def edit_graph(text, seed, ref_name):
    def node(c, **i):
        return {"class_type": c, "inputs": i}

    return {
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
            megapixels=1.0,
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


def enlarge(path):
    """Кадр 64 px на пурпурі, ×16 найближчим сусідом — для моделі."""
    ref = Image.open(path).convert("RGBA")
    canvas = Image.new("RGBA", ref.size, MAGENTA + (255,))
    canvas.alpha_composite(ref)
    return np.asarray(canvas.resize((ref.width * UP, ref.height * UP), Image.NEAREST))


def edit(ref_rgba, text, seed):
    """Редагування з кешем: той самий референс, підказка й зерно — та сама картинка без моделі."""
    key = hashlib.sha1(
        ref_rgba.tobytes() + text.encode() + str(seed).encode()
    ).hexdigest()[:16]
    path = os.path.join(CACHE, key + ".png")
    if not os.path.exists(path):
        name = upload(ref_rgba, "sprite_ref.png")
        os.makedirs(CACHE, exist_ok=True)
        Image.fromarray(run(edit_graph(text, seed, name)).astype(np.uint8)).save(path)
        print("generated", text[:60], flush=True)
    return np.asarray(Image.open(path).convert("RGBA"))


def cached(ref_rgba, text, seed):
    key = hashlib.sha1(
        ref_rgba.tobytes() + text.encode() + str(seed).encode()
    ).hexdigest()[:16]
    return os.path.exists(os.path.join(CACHE, key + ".png"))


def shrink(img):
    """Фон — виміряний колір рамки (модель малює «#FF00FF» як (244..252, 6..7, 245..247)); ×16 → 64×64."""
    img = img[: CELL * UP, : CELL * UP, :3].astype(np.float32)
    border = np.concatenate(
        [
            img[:12].reshape(-1, 3),
            img[-12:].reshape(-1, 3),
            img[:, :12].reshape(-1, 3),
            img[:, -12:].reshape(-1, 3),
        ]
    )
    a = (np.linalg.norm(img - np.median(border, axis=0), axis=2) > 75).astype(np.float32)
    # тінь, яку модель кладе під ступні на пурпурі, — теж геть: пурпурових кольорів на персонажах немає
    a[(img[..., 0] > img[..., 1] + 60) & (img[..., 2] > img[..., 1] + 60)] = 0

    def blocks(m):
        return m.reshape(CELL, UP, CELL, UP, -1).sum(axis=(1, 3))

    asum = blocks(a[..., None])
    return blocks(img * a[..., None]) / np.maximum(asum, 1e-6), asum[
        ..., 0
    ] >= UP * UP / 2


def feet_row(opaque):
    rows = np.nonzero(opaque.any(axis=1))[0]
    return int(rows[-1]) if len(rows) else CELL - 1


if __name__ == "__main__":
    char = CHARACTERS[sys.argv[1]]
    only = sys.argv[2:]
    seed = char["seed"]
    base = edit(enlarge(char["ref"]), char["base"], seed)
    base_ref = base.copy()
    base_ref[..., 3] = 255
    frames = {}
    for anim, poses in char["rows"]:
        for i, pose in enumerate(poses):
            text = KEEP.format(who=char["who"], pose=pose) if pose else None
            if pose is None:
                frames[(anim, i)] = base
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
    small = {k: shrink(v) for k, v in frames.items()}
    rgb0, op0 = small[(char["rows"][0][0], 0)]
    pal = Image.fromarray(rgb0[op0].astype(np.uint8)[None]).quantize(
        char["colors"], Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE
    )
    floor = feet_row(op0)
    cols = max(len(p) for _, p in char["rows"])
    sheet = np.zeros((CELL * len(char["rows"]), CELL * cols, 4), np.uint8)
    for r, (anim, poses) in enumerate(char["rows"]):
        for i in range(len(poses)):
            rgb, op = small[(anim, i)]
            q = np.asarray(
                Image.fromarray(rgb.astype(np.uint8))
                .quantize(palette=pal, dither=Image.Dither.NONE)
                .convert("RGB")
            )
            cell = np.dstack([q, op.astype(np.uint8) * 255])
            shift = floor - feet_row(op)  # ступні — на рядок першого кадру
            cell = np.roll(cell, shift, axis=0)
            if shift > 0:
                cell[:shift] = 0
            elif shift < 0:
                cell[shift:] = 0
            sheet[r * CELL : (r + 1) * CELL, i * CELL : (i + 1) * CELL] = cell
            print(f"{anim}[{i}] feet row {feet_row(op)} -> {floor}")
    os.makedirs(os.path.dirname(char["out"]), exist_ok=True)
    Image.fromarray(sheet).save(char["out"])
    print(
        "sheet", char["out"], sheet.shape[1], "x", sheet.shape[0], "| feet row", floor
    )
