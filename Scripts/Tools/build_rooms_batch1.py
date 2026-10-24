#!/usr/bin/env python3
# D643, branch batch 1: пише п'ять бічних кімнат MetSys (SampleProject/Maps/<Room>.tscn) з backdrop-ів
# Assets/Backgrounds/<Room>/gen_back.png. Розмітка кімнат — тут (числа в px; клітинка MetSys 864×480).
#   python3 Scripts/Tools/build_rooms_batch1.py
# Підлога й стіни — схований шар тайлів Foreground (як LabCells), уступи меси — односторонні StaticBody2D, backdrop —
# спрайти, що йдуть разом зі світом (намальована кімната). Перезапис затирає ручні правки в цих п'яти .tscn: правте тут.
import base64
import struct
from pathlib import Path

MAPS = Path(__file__).resolve().parents[2] / "SampleProject/Maps"
CELL_W, CELL_H = 864, 480
FLOOR = 416          # верх підлоги однорядної кімнати (рядок тайлів 13)
STAND = FLOOR - 40   # де стоїть герой (і двері), як ExitDoor в ElderHouse

UIDS = {
    "LizardCave": "cn3wosqkjakdb",
    "BanditCamp": "bsuxeons58smh",
    "MesaClimb": "dqkh1e1q4c6cl",
    "DragonMural": "c4u87cxyqha6w",
    "GatehouseCellar": "nidweolightl",
}
BACKDROP = {
    "LizardCave": "LizardCave", "BanditCamp": "BanditCamp", "MesaClimb": "MesaClimb",
    "DragonMural": "DragonMural", "GatehouseCellar": "Cellar",
}
MUSIC = {
    "LizardCave": "canyon_echoes", "DragonMural": "canyon_echoes", "BanditCamp": "whispers_in_the_sand",
    "MesaClimb": "whispers_in_the_sand", "GatehouseCellar": "dunes_of_silence",
}


class Room:
    def __init__(self, name: str, cells_w: int, cells_h: int):
        self.name = name
        self.w = cells_w * CELL_W
        self.h = cells_h * CELL_H
        self.ext: list[str] = []
        self.ext_ids: dict[str, str] = {}
        self.subs: list[str] = []
        self.nodes: list[str] = []
        self._n = 0

    def res(self, kind: str, path: str) -> str:
        if path not in self.ext_ids:
            rid = "r%d" % (len(self.ext_ids) + 1)
            self.ext_ids[path] = rid
            self.ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
        return 'ExtResource("%s")' % self.ext_ids[path]

    def rect(self, w: float, h: float) -> str:
        self._n += 1
        sid = "RectangleShape2D_%d" % self._n
        self.subs.append('[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%g, %g)' % (sid, w, h))
        return 'SubResource("%s")' % sid

    def node(self, text: str) -> None:
        self.nodes.append(text.strip("\n"))

    # ── будівельні блоки ──────────────────────────────────────────────────────────────────────────
    def backdrop(self, scale: float = 1.5, x: float = 0.0, y: float = -3.0) -> None:
        """Backdrop — намальована кімната: по спрайту на кожну колонку клітинок, разом зі світом (не Parallax2D:
        його підлога — це підлога кімнати, і verify_map_geometry має бачити її намальованою під тайлами)."""
        tex = self.res("Texture2D", "res://SampleProject/Assets/Backgrounds/%s/gen_back.png" % BACKDROP[self.name])
        self.node('[node name="Back" type="Node2D" parent="."]\nz_index = -10')
        step = 576 * scale
        for i in range(max(1, round(self.w / step))):
            self.node('[node name="Sprite%d" type="Sprite2D" parent="Back"]\ntexture_filter = 1\nposition = Vector2(%g, %g)\n'
                      'scale = Vector2(%g, %g)\ntexture = %s\ncentered = false' % (i + 1, x + i * step, y, scale, scale, tex))

    def bounds(self, floor_row: int) -> None:
        """Підлога (від рядка [floor_row] до низу) і бічні стіни — схований шар тайлів Foreground, як у LabCells:
        видно намальовану підлогу backdrop-у, а verify_map_geometry бачить ті самі тайли, що й в інших кімнатах."""
        cols, rows = self.w // 32, self.h // 32
        cells = [(x, y) for y in range(floor_row, rows) for x in range(cols)]
        cells += [(x, y) for y in range(0, floor_row) for x in (-1, cols)]
        data = bytearray(b"\x00\x00")
        for x, y in cells:
            data += struct.pack("<hhHHHH", x, y, 1, 8, 7, 0)
        tiles = self.res("TileSet", "res://SampleProject/Resources/DesertTileset.tres")
        self.node('[node name="TileMap" type="Node2D" parent="."]')
        self.node('[node name="Foreground" type="TileMapLayer" parent="TileMap"]\nvisible = false\n'
                  'tile_map_data = PackedByteArray("%s")\ntile_set = %s' % (base64.b64encode(bytes(data)).decode(), tiles))

    def ledge(self, name: str, x0: float, x1: float, top: float, art: bool = True) -> None:
        """Односторонній уступ: верх на [top], від x0 до x1; вигляд — смуга верхньої плитки DesertTileset."""
        self.node('[node name="%s" type="StaticBody2D" parent="Ledges"]\nposition = Vector2(%g, %g)' % (name, (x0 + x1) / 2, top))
        self.node('[node name="CollisionShape2D" type="CollisionShape2D" parent="Ledges/%s"]\nposition = Vector2(0, 6)\n'
                  'shape = %s\none_way_collision = true' % (name, self.rect(x1 - x0, 12)))
        if art:
            tex = self.res("Texture2D", "res://SampleProject/Assets/Backgrounds/Terrain/Canyon_Terrain.png")
            self.node('[node name="Art" type="Sprite2D" parent="Ledges/%s"]\ntexture_filter = 1\ntexture_repeat = 2\n'
                      'position = Vector2(0, 14)\nscale = Vector2(1.5, 1.5)\ntexture = %s\nregion_enabled = true\n'
                      'region_rect = Rect2(724, 140, %g, 22)' % (name, tex, (x1 - x0) / 1.5))

    def door(self, name: str, x: float, y: float, target: str, arrival: str, text: str = "Leave", extra: str = "") -> None:
        scn = self.res("PackedScene", "res://SampleProject/Scenes/Gameplay/Objects/room_door.tscn")
        self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\ntarget_room = "res://SampleProject/Maps/%s.tscn"\n'
                  'arrival = NodePath("%s")%s' % (name, scn, x, y, target, arrival, extra))
        self.node('[node name="Interactable" parent="%s" index="1"]\naction_text = "%s"' % (name, text))

    def marker(self, name: str, x: float, y: float) -> None:
        self.node('[node name="%s" type="Marker2D" parent="."]\nposition = Vector2(%g, %g)' % (name, x, y))

    def chest(self, name: str, x: float, y: float, contents: dict | None = None, charm: str = "") -> None:
        scn = self.res("PackedScene", "res://SampleProject/Objects/Chest.tscn")
        body = '[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)' % (name, scn, x, y)
        if contents:
            body += "\ncontents = Dictionary[String, int]({\n%s\n})" % ",\n".join('"%s": %d' % kv for kv in contents.items())
        if charm:
            body += '\ncharm = "%s"' % charm
        self.node(body)

    def note(self, name: str, x: float, y: float, story: str) -> None:
        scn = self.res("PackedScene", "res://SampleProject/Objects/StoryNote.tscn")
        self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\nstory_id = "%s"' % (name, scn, x, y, story))

    def gate(self, name: str, x: float, gate_id: str) -> None:
        """Ґрати LockedDoor (Lab gen_bars з замком) на підлозі; тіло — від підлоги до стелі, щоб не перестрибнути."""
        scn = self.res("PackedScene", "res://SampleProject/Objects/LockedDoor.tscn")
        bars = self.res("Texture2D", "res://SampleProject/Assets/Backgrounds/Lab/gen_bars.png")
        self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\ngate_id = "%s"' % (name, scn, x, FLOOR, gate_id))
        self.node('[node name="Sprite" parent="%s" index="0"]\nz_index = 1\nposition = Vector2(0, -56)\ntexture = %s' % (name, bars))
        self.node('[node name="CollisionShape2D" parent="%s/Body" index="0"]\nposition = Vector2(0, -%g)\nshape = %s'
                  % (name, FLOOR / 2, self.rect(48, FLOOR)))
        self.node('[node name="CollisionShape2D" parent="%s/Area" index="0"]\nposition = Vector2(-48, -56)\nshape = %s'
                  % (name, self.rect(112, 112)))

    def fight(self, name: str, trigger_x: float, trigger_w: float, level: int, points: list, waves: int = 0,
              reward: dict | None = None, trigger_y: float = -1.0) -> None:
        """RoomEnemySpawner з тригером (D492: звичайний бій, вертається після медитації). points: (назва, x, y, тип, big_kind)."""
        spawner = self.res("Script", "res://SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd")
        point = self.res("Script", "res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd")
        body = ('[node name="%s" type="Node2D" parent="." node_paths=PackedStringArray("trigger_area")]\nscript = %s\n'
                'enemy_level = %d\nauto_spawn_on_ready = false\ntrigger_area = NodePath("%sTrigger")\nstate_key = "enemies_%s"\n'
                'respawns = true' % (name, spawner, level, name, name.removeprefix("Fight_").lower()))
        if waves:
            body += "\nspawn_in_waves = true\nwave_size = %d\nwave_delay = 2.0" % waves
        if reward:
            body += "\nreward = Dictionary[String, int]({\n%s\n})" % ",\n".join('"%s": %d' % kv for kv in reward.items())
        self.node(body)
        self.node('[node name="%sTrigger" type="Area2D" parent="%s"]\nposition = Vector2(%g, %g)'
                  % (name, name, trigger_x, self.h / 2 if trigger_y < 0 else trigger_y))
        self.node('[node name="CollisionShape2D" type="CollisionShape2D" parent="%s/%sTrigger"]\nshape = %s'
                  % (name, name, self.rect(trigger_w, self.h if trigger_y < 0 else 320)))
        for pname, x, y, kind, big in points:
            text = '[node name="%s" type="Node2D" parent="%s"]\nposition = Vector2(%g, %g)\nscript = %s\nenemy_type = "%s"' % (pname, name, x, y, point, kind)
            if big:
                text += '\nbig_kind = "%s"\nspawn_id = "%s_%s"' % (big, name, pname)
            self.node(text)

    def write(self) -> None:
        music = self.res("AudioStream", "res://SampleProject/Resources/Audio/Music/%s.ogg" % MUSIC[self.name])
        room = self.res("PackedScene", "res://addons/MetroidvaniaSystem/Nodes/RoomInstance.tscn")
        self.node('[node name="RoomInstance" parent="." instance=%s]' % room)
        self.node('[node name="Music" type="AudioStreamPlayer" parent="."]\nprocess_mode = 3\nstream = %s\nautoplay = true\nbus = &"Music"' % music)
        head = '[gd_scene format=3 uid="uid://%s"]' % UIDS[self.name]
        root = '[node name="%s" type="Node2D"]' % self.name
        text = "\n\n".join([head, "\n".join(self.ext)] + self.subs + [root] + self.nodes) + "\n"
        (MAPS / ("%s.tscn" % self.name)).write_text(text, encoding="utf-8")


def needs_ledges(r: Room) -> None:
    r.node('[node name="Ledges" type="Node2D" parent="."]')


def lizard_cave() -> None:
    """Печера ящурів під містком каньйону: відкрита частина з двома ящірками-шакалами, далі ґрати святилища
    (дідів ключ), за ними — розпис шаманів (StoryNote) і скриня з першим амулетом (charms_plan)."""
    r = Room("LizardCave", 2, 1)
    r.backdrop()
    # Псевдолітери на двох табличках backdrop-у (шов повтору: «sham|m mamit»): зверху — орнамент середньої таблички.
    tex = r.res("Texture2D", "res://SampleProject/Assets/Backgrounds/LizardCave/gen_back.png")
    for i, sx in enumerate((554 * 1.5, 554 * 1.5 + 864)):
        r.node('[node name="TabletCover%d" type="Sprite2D" parent="Back"]\ntexture_filter = 1\nposition = Vector2(%g, %g)\n'
               'scale = Vector2(1.5, 1.5)\ntexture = %s\ncentered = false\nregion_enabled = true\nregion_rect = Rect2(276, 134, 64, 12)'
               % (i + 1, sx, 133 * 1.5 - 3, tex))
    r.bounds(FLOOR // 32)
    r.marker("Arrival", 96, STAND)
    r.door("ExitDoor", 96, STAND, "Canyon", "LizardCaveDoor")
    r.fight("Fight_CaveLizards", 520, 120, 2, [("EnemySpawnPoint1", 760, FLOOR - 16, "fast", ""),
                                                ("EnemySpawnPoint2", 900, FLOOR - 16, "fast", "")])
    r.gate("Gate_Shrine", 1240, "lizard_shrine")
    r.note("ShamanMural", 1440, STAND - 20, "lizard_shrine_mural")
    r.chest("Chest_Shrine", 1600, FLOOR, charm="deep_gourd_amulet")
    r.write()


def bandit_camp() -> None:
    """Табір бандитів на дюні біля дороги: важкий груповий бій (D582) з елітою, що носить ключ від частоколу;
    за частоколом — скриня з награбованим у селі й задні ворота: зсередини вони відчиняють шорткат до дороги біля
    місця медитації (SavePoint_BeforeCity)."""
    r = Room("BanditCamp", 2, 1)
    r.backdrop()
    r.bounds(FLOOR // 32)
    r.marker("Arrival", 96, STAND)
    r.door("ExitDoor", 96, STAND, "DesertRoad", "BanditCampDoor")
    r.fight("Fight_Camp", 420, 160, 4, [
        ("EnemySpawnPoint1", 700, FLOOR - 16, "fast", ""),
        ("EnemySpawnPoint2", 820, FLOOR - 16, "melee", ""),
        ("EnemySpawnPoint3", 940, FLOOR - 16, "shield", ""),
        ("EnemySpawnPoint4", 1120, FLOOR - 16, "archer", ""),
        ("EnemySpawnPoint5", 760, FLOOR - 16, "melee", ""),
        ("BigSlot_BanditBrute_1", 1040, FLOOR - 16, "melee", "bandit_brute"),
    ], waves=3, reward={"camp_key": 1})
    r.gate("Gate_Stockade", 1300, "camp_stockade")
    r.chest("Chest_Loot", 1450, FLOOR, contents={"potion_lesser": 2, "herb": 3, "leather": 2}, charm="breaker_ring")
    r.door("ShortcutDoor", 1640, STAND, "DesertRoad", "CampShortcutDoor", "Open the gate", '\nsets_flag = "bandit_camp_shortcut"')
    r.write()


def mesa_climb() -> None:
    """Підйом на месу: 1 клітинка завширшки, 2 заввишки. Стрибки по уступах (стрибок героя ~103 px, тут крок 72),
    уступи сусідніх кроків перекриваються на 40 px (стрибок з краю — прямо вгору крізь односторонній уступ); нагорі скриня зі зброєю з компромісом; над месою кружляють грифи (D558)."""
    r = Room("MesaClimb", 1, 2)
    floor = r.h - 64
    # Картина на всю висоту кімнати: 960 / 324 ≈ 2.963, по центру.
    s = r.h / 324.0
    r.backdrop(scale=round(s, 4), x=round((r.w - 576 * s) / 2, 1), y=0)
    r.bounds(floor // 32)
    r.marker("Arrival", 96, floor - 40)
    r.door("ExitDoor", 96, floor - 40, "DesertRoad", "MesaClimbDoor")
    needs_ledges(r)
    steps = [(300, 828), (480, 756), (660, 684), (480, 612), (300, 540), (120, 468), (300, 396), (480, 324), (660, 252)]
    for i, (cx, top) in enumerate(steps, 1):
        r.ledge("Ledge%d" % i, cx - 110, cx + 110, top)
    r.ledge("Ledge_Top", 380, 864, 180)
    r.chest("Chest_Mesa", 760, 180, contents={"iron_halberd": 1}, charm="sand_runner_ring")
    r.fight("Fight_Vultures", 432, 864, 3, [("EnemySpawnPoint1", 300, 420, "vulture", ""),
                                             ("EnemySpawnPoint2", 620, 300, "vulture", "")],
            trigger_y=640)
    r.write()


def dragon_mural() -> None:
    """Печерка за тріснутою брилою каньйону: стародавній розпис дракона (StoryNote → Journal NOTES, D684) і скриня."""
    r = Room("DragonMural", 1, 1)
    r.backdrop()
    r.bounds(FLOOR // 32)
    r.marker("Arrival", 96, STAND)
    r.door("ExitDoor", 96, STAND, "Canyon", "DragonMuralDoor")
    r.note("DragonMural", 432, STAND - 20, "dragon_mural")
    r.chest("Chest_Mural", 740, FLOOR, charm="jackal_tooth_amulet")
    r.write()


def gatehouse_cellar() -> None:
    """Льох під міською брамою: вартовий пускає після розмови. Тут живуть кажани (D558): перший — сам (D582),
    далі троє; у кінці скриня."""
    r = Room("GatehouseCellar", 2, 1)
    r.backdrop()
    r.bounds(FLOOR // 32)
    r.marker("Arrival", 96, STAND)
    r.door("ExitDoor", 96, STAND, "CityGates", "CellarDoor")
    r.fight("Fight_LoneBat", 320, 120, 5, [("EnemySpawnPoint1", 560, 260, "bat", "")])
    r.fight("Fight_Bats", 980, 120, 5, [("EnemySpawnPoint1", 1200, 230, "bat", ""),
                                         ("EnemySpawnPoint2", 1320, 290, "bat", ""),
                                         ("EnemySpawnPoint3", 1440, 240, "bat", "")])
    r.chest("Chest_Cellar", 1620, FLOOR, contents={"potion": 1}, charm="hermit_amulet")
    r.write()


if __name__ == "__main__":
    for build in (lizard_cave, bandit_camp, mesa_climb, dragon_mural, gatehouse_cellar):
        build()
    print("rooms written to", MAPS)
