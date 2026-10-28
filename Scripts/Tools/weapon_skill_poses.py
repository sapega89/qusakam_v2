"""Пози навичок руху (H3, D812) у бібліотеки зброї героя: `<Skill>Windup/Move/Strike` з кадрів
`Sprites/Player/Weapons/<набір>/{LungeCut,ShieldCharge,LeapSlam}/1–3`.

Лише дописує: бібліотеки мають ручні зсуви ніг (`Sprite2D:offset` по кадрах), які `weapon_libraries.py` не знає,
тож перезапис їх стер би. Меч — у `Player.tscn` (`AnimationLibrary_sword`), решта — `WeaponAnimations/*.tres`.
Тайминг як у базових поз (одна клітинка 0.3 с), зсув (0, −16) під клітинку 96×96, як уся бібліотека, плюс FEET.
Повторний запуск нічого не дублює.
    python Scripts/Tools/weapon_skill_poses.py   (з кореня репозиторію)
"""

import os
import re

from weapon_libraries import FRAMES, LOCAL, OUT, frames, track

SKILLS = ["LungeCut", "ShieldCharge", "LeapSlam"]
PHASES = ["Windup", "Move", "Strike"]
LENGTH = 0.3
SCENE = "SampleProject/Player.tscn"
## Кадри, де ноги не на рядку 88 (присід, коліно; древко чи голова нижче за ноги): зсув ніг униз у px кадру, щоб
## verify_hero_feet садив їх на низ колізії, як ручні ключі offset решти бібліотек.
FEET = {
    "sword/LungeCut/1": 1, "sword/LeapSlam/3": 4,
    "dagger/LeapSlam/3": 3,
    "mace/LeapSlam/3": 3,
    "halberd/LungeCut/1": 4, "halberd/ShieldCharge/1": 1, "halberd/LeapSlam/1": 4, "halberd/LeapSlam/3": 2,
}


def poses(folder):
    """Ім'я анімації → кадр (`<набір>/<Skill>/<n>`) для тек H3, що є в наборі."""
    out = {}
    for skill in SKILLS:
        if os.path.isdir(os.path.join(LOCAL, folder, skill)):
            for phase, frame in zip(PHASES, frames(folder, skill)):
                out[skill + phase] = frame
    return out


def patch(text, folder, prefix, anim_id, before, data_open):
    """Дописує в [param text] текстури після останнього ext_resource, анімації перед [param before] і ключі
    в словник `_data`, що починається з [param data_open]."""
    anims = {a: f for a, f in poses(folder).items() if f'id="{anim_id(a)}"]' not in text}
    if not anims:
        return text
    exts, subs, keys = [], [], []
    for anim, frame in anims.items():
        rid = prefix + frame.split("/", 1)[1].replace("/", "_").lower()
        exts.append(f'[ext_resource type="Texture2D" path="{FRAMES}{frame}.png" id="{rid}"]')
        body = track(0, "Sprite2D:texture", [0], [f'ExtResource("{rid}")'])
        body += track(1, "Sprite2D:offset", [0], [f"Vector2(0, {-16 + FEET.get(frame, 0)})"])
        subs.append(f'[sub_resource type="Animation" id="{anim_id(anim)}"]\nresource_name = "{anim}"\n'
                    f"length = {LENGTH:g}\n{body}\n")
        keys.append(f'&"{anim}": SubResource("{anim_id(anim)}")')
    last = [m.end() for m in re.finditer(r"^\[ext_resource [^\n]*\]$", text, re.M)][-1]
    text = text[:last] + "\n" + "\n".join(exts) + text[last:]
    at = text.index(before)
    text = text[:at] + "\n".join(subs) + "\n" + text[at:]
    start = text.index(data_open, text.index(before)) + len(data_open)
    end = text.index("\n}", start)
    return text[:end] + ",\n" + ",\n".join(keys) + text[end:]


def edit(path, fn):
    with open(path, encoding="utf-8", newline="") as f:
        text = f.read()
    new = fn(text)
    if new != text:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(new)
        print("patched", path)


if __name__ == "__main__":
    for folder, library in [("dagger", "dagger"), ("mace", "mace"), ("halberd", "polearm")]:
        edit(os.path.join(OUT, library + ".tres"),
             lambda t, f=folder: patch(t, f, "t_" + f + "_", lambda a: "Animation_" + a, "[resource]", "_data = {"))
    edit(SCENE, lambda t: patch(t, "sword", "sw_", lambda a: "Animation_sword_" + a,
                                '[sub_resource type="AnimationLibrary" id="AnimationLibrary_sword"]', "_data = {"))
