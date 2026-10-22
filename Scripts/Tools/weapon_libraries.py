"""Бібліотеки анімацій героя для типів зброї з власними кадрами (BACKLOG 42, design/hero_weapon_animation_plan.md).

Пише `SampleProject/Resources/Player/WeaponAnimations/<бібліотека>.tres` — по одній на тип, ті самі імена й тайминги,
що в бібліотеці меча в `Player.tscn` (D345): Idle, Run, Jump/Apex/Fall, Land, Attack1–N (0.3 с, удар на 0.05 с — як
базовий удар, тож хітбокс не зсувається), HeavyWindup (0.4 с) / HeavyStrike (0.25 с), Block, Hurt; кожна ставить
`Sprite2D:offset` (0, −16) під клітинку 96×96. Ім'я бібліотеки — `category` з items.json (алебарда — `polearm`),
дві зброї — `dual_<у руці>_<друга>`.

Кадрів, яких немає в наборі (README набору), бере найближчу наявну анімацію через `overrides`. Кинджал (Heavy,
Attack2/2–3) і dual (Hurt) їх більше не потребують — кадри додано в fe96e88a (remaining_work Art 3).
    python Scripts/Tools/weapon_libraries.py
"""

import os

FRAMES = "res://SampleProject/Sprites/Player/Weapons/"
OUT = "SampleProject/Resources/Player/WeaponAnimations/"
LOCAL = "SampleProject/Sprites/Player/Weapons/"
SWING_LENGTH = 0.3
SWING_TIMES = [0, 0.05, 0.13, 0.21]  # замах, удар, супровід, стійка (базовий Attack)
RUN_LENGTH = 0.8
OFFSET = "Vector2(0, -16)"


def frames(folder, kind):
    path = os.path.join(LOCAL, folder, kind)
    names = sorted(
        (f for f in os.listdir(path) if f.endswith(".png")), key=lambda f: int(f[:-4])
    )
    return [f"{folder}/{kind}/{n[:-4]}" for n in names]


def library(folder, attacks, overrides):
    """Анімації бібліотеки: ім'я → (довжина, цикл, [(час, кадр)])."""
    idle = frames(folder, "CombatIdle")
    run = frames(folder, "Run")
    air = frames(folder, "Air")
    anims = {
        "Idle": (1.2, True, list(zip([0, 0.3, 0.6, 0.9], idle))),
        "Run": (RUN_LENGTH, True, [(round(i * RUN_LENGTH / len(run), 3), f) for i, f in enumerate(run)]),
        "Jump": (0.2, False, [(0, air[0])]),
        "Apex": (0.18, False, [(0, air[1])]),
        "Fall": (0.1, True, [(0, air[2])]),
        "Land": (0.1, False, [(0, idle[0])]),
    }
    for step in range(1, attacks + 1):
        swing = overrides.get(f"Attack{step}") or frames(folder, f"Attack{step}")
        anims[f"Attack{step}"] = (SWING_LENGTH, False, list(zip(SWING_TIMES, swing + [idle[0]])))
    heavy = overrides.get("Heavy") or frames(folder, "Heavy")
    anims["HeavyWindup"] = (0.4, False, [(0, heavy[0])])
    anims["HeavyStrike"] = (0.25, False, [(0, heavy[1]), (0.1, heavy[2])])
    anims["Block"] = (0.1, False, [(0, (overrides.get("Block") or frames(folder, "Block"))[0])])
    anims["Hurt"] = (0.25, False, [(0, (overrides.get("Hurt") or frames(folder, "Hurt"))[0])])
    return anims


def floats(values):
    return ", ".join(f"{v:g}" for v in values)


def track(index, path, times, values):
    return (
        f'tracks/{index}/type = "value"\n'
        f"tracks/{index}/imported = false\n"
        f"tracks/{index}/enabled = true\n"
        f'tracks/{index}/path = NodePath("{path}")\n'
        f"tracks/{index}/interp = 1\n"
        f"tracks/{index}/loop_wrap = true\n"
        f"tracks/{index}/keys = {{\n"
        f'"times": PackedFloat32Array({floats(times)}),\n'
        f'"transitions": PackedFloat32Array({floats([1] * len(times))}),\n'
        f'"update": 1,\n'
        f'"values": [{", ".join(values)}]\n'
        "}\n"
    )


def write(name, anims):
    ids = {}
    for _, _, keys in anims.values():
        for _, frame in keys:
            ids.setdefault(frame, "t_" + frame.replace("/", "_").lower())
    out = ['[gd_resource type="AnimationLibrary" format=3]', ""]
    for frame, rid in ids.items():
        out.append(f'[ext_resource type="Texture2D" path="{FRAMES}{frame}.png" id="{rid}"]')
    out.append("")
    for anim, (length, loop, keys) in anims.items():
        out.append(f'[sub_resource type="Animation" id="Animation_{anim}"]')
        out.append(f'resource_name = "{anim}"')
        out.append(f"length = {length:g}")
        if loop:
            out.append("loop_mode = 1")
        body = track(0, "Sprite2D:texture", [t for t, _ in keys], [f'ExtResource("{ids[f]}")' for _, f in keys])
        body += track(1, "Sprite2D:offset", [0], [OFFSET])
        out.append(body)
    out.append("[resource]")
    out.append("_data = {")
    out.append(",\n".join(f'&"{a}": SubResource("Animation_{a}")' for a in anims))
    out.append("}")
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name + ".tres"), "w", newline="\n") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    write("dagger", library("dagger", 3, {}))
    write("mace", library("mace", 3, {}))
    write("polearm", library("halberd", 3, {}))
    write("dual_sword_dagger", library("dual", 4, {}))
    print("written", OUT)
