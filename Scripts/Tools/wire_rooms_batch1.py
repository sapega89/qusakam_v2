#!/usr/bin/env python3
# D643: входи в п'ять бічних кімнат з головних (Canyon, DesertRoad, CityGates). Одноразовий: дописує ресурси й вузли
# в кінець .tscn; вдруге не пише (вузол LizardCaveDoor / BanditCampDoor / CellarDoor уже є).
#   python3 Scripts/Tools/wire_rooms_batch1.py
import re
from pathlib import Path

MAPS = Path(__file__).resolve().parents[2] / "SampleProject/Maps"
BG = "res://SampleProject/Assets/Backgrounds/"
DOOR = "res://SampleProject/Scenes/Gameplay/Objects/room_door.tscn"


def patch(room: str, guard: str, ext: list, subs: list, nodes: list) -> None:
    path = MAPS / ("%s.tscn" % room)
    text = path.read_text(encoding="utf-8")
    if 'name="%s"' % guard in text:
        print("%s: already wired" % room)
        return
    last_ext = list(re.finditer(r"^\[ext_resource [^\n]*\]$", text, re.M))[-1]
    ext_text = "".join("\n" + '[ext_resource type="%s" path="%s" id="%s"]' % e for e in ext)
    text = text[:last_ext.end()] + ext_text + text[last_ext.end():]
    first_sub = re.search(r"^\[sub_resource |^\[node ", text, re.M)
    sub_text = "".join('[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%g, %g)\n\n' % s for s in subs)
    text = text[:first_sub.start()] + sub_text + text[first_sub.start():]
    text = text.rstrip("\n") + "\n\n" + "\n\n".join(n.strip("\n") for n in nodes) + "\n"
    path.write_text(text, encoding="utf-8")
    print("%s: wired" % room)


def door(name: str, x: float, y: float, target: str, arrival: str, extra: str = "") -> list:
    return ['[node name="%s" parent="." instance=ExtResource("b1_door")]\nposition = Vector2(%g, %g)\n'
            'target_room = "res://SampleProject/Maps/%s.tscn"\narrival = NodePath("%s")%s' % (name, x, y, target, arrival, extra),
            '[node name="Interactable" parent="%s" index="1"]\naction_text = "Enter"' % name]


def hole(name: str, x: float, bottom: float, points: list, z: int = -1) -> str:
    """Темний отвір у скелі заднього плану (вхід у печеру, тріщина за брилою): Polygon2D, низ — на [bottom]."""
    pts = ", ".join("%g, %g" % p for p in points)
    return ('[node name="%s" type="Polygon2D" parent="."]\nz_index = %d\nposition = Vector2(%g, %g)\n'
            'color = Color(0.16, 0.09, 0.15, 1)\npolygon = PackedVector2Array(%s)' % (name, z, x, bottom, pts))


def tent(name: str, x: float, bottom: float, flip: bool = False) -> str:
    """Подертий намет (City gen_dervish_tent) на задньому плані — знак табору бандитів біля дороги."""
    return ('[node name="%s" type="Sprite2D" parent="."]\nz_index = -1\ntexture_filter = 1\nposition = Vector2(%g, %g)\n'
            'scale = Vector2(0.6, 0.6)\ntexture = ExtResource("b1_tent")%s\noffset = Vector2(0, -100)'
            % (name, x, bottom, "\nflip_h = true" if flip else ""))


CAVE = [(-52, 0), (-50, -48), (-38, -86), (-14, -108), (10, -112), (34, -96), (48, -64), (54, 0)]
CRACK = [(-34, 0), (-30, -34), (-36, -58), (-18, -80), (-4, -96), (10, -84), (26, -64), (22, -36), (36, 0)]

# ── Canyon: печера ящурів біля містка (схід від CanyonExitTrigger, 830–890); брила на плато, за нею тріщина ──────────
# Брила — на задньому плані (не тримає героя: її тіло перегородило б єдину стежку каньйону), двері за нею
# зʼявляються, коли її розбито (RoomDoor.cover).
patch("Canyon", "LizardCaveDoor",
      [("PackedScene", DOOR, "b1_door"), ("PackedScene", "res://SampleProject/Objects/BreakableWall.tscn", "b1_wall")],
      [],
      [hole("LizardCaveMouth", 950, 392, CAVE),
       *door("LizardCaveDoor", 950, 356, "LizardCave", "ExitDoor"),
       hole("DragonMuralCrack", 1450, 218, CRACK, -2),
       '[node name="Wall_Mural" parent="." instance=ExtResource("b1_wall")]\nposition = Vector2(1450, 218)\ncollision_layer = 0',
       '[node name="Sprite" parent="Wall_Mural" index="0"]\nz_index = -1\nscale = Vector2(1, 1)\noffset = Vector2(0, -50)',
       *door("DragonMuralDoor", 1450, 190, "DragonMural", "ExitDoor", '\ncover = NodePath("../Wall_Mural")')])

# ── DesertRoad: табір на дюні (x 2050), підйом на месу (x 2800), задні ворота табору біля медитації (x 4820) ────────
patch("DesertRoad", "BanditCampDoor",
      [("PackedScene", DOOR, "b1_door"), ("Texture2D", "res://SampleProject/Assets/Backgrounds/City/gen_dervish_tent.png", "b1_tent"),
       ("Texture2D", "res://SampleProject/Assets/Objects/ladder.png", "b1_ladder")],
      [],
      [tent("BanditCampTent", 2050, 262),
       *door("BanditCampDoor", 2050, 232, "BanditCamp", "ExitDoor"),
       '[node name="MesaClimbLadder" type="Sprite2D" parent="."]\nz_index = -1\ntexture_filter = 1\ntexture_repeat = 2\n'
       'position = Vector2(2800, 324)\nscale = Vector2(1.5, 1.5)\ntexture = ExtResource("b1_ladder")\noffset = Vector2(0, -64)\n'
       'region_enabled = true\nregion_rect = Rect2(0, 0, 16, 128)',
       *door("MesaClimbDoor", 2800, 296, "MesaClimb", "ExitDoor"),
       tent("CampShortcutTent", 4820, 392, True),
       *door("CampShortcutDoor", 4820, 356, "BanditCamp", "ShortcutDoor", '\ngate_id = "camp_shortcut"')])

# ── CityGates: льох вартових ліворуч від брами; вартовий (GuardLeft) пускає туди після розмови ─────────────────────
patch("CityGates", "CellarDoor",
      [("PackedScene", DOOR, "b1_door"), ("PackedScene", "res://SampleProject/Scenes/Gameplay/Objects/talk_spot.tscn", "b1_talk"),
       ("Texture2D", "res://SampleProject/Assets/Backgrounds/Cellar/gen_back.png", "b1_cellar")],
      [],
      ['[node name="CellarArch" type="Sprite2D" parent="."]\nz_index = -1\ntexture_filter = 1\nposition = Vector2(1090, 394)\n'
       'texture = ExtResource("b1_cellar")\noffset = Vector2(0, -85)\nregion_enabled = true\nregion_rect = Rect2(300, 40, 150, 170)',
       *door("CellarDoor", 1090, 356, "GatehouseCellar", "ExitDoor", '\ngate_id = "gatehouse_cellar"'),
       '[node name="CellarTalk" parent="." instance=ExtResource("b1_talk")]\nposition = Vector2(1200, 356)\n'
       'dialogue = "res://dialogue_quest/CityGates_Cellar_Guard.dqd"\nsets_flag = "gatehouse_cellar_allowed"\n'
       'after_flag = "city_gates_after_fight_complete"'])
