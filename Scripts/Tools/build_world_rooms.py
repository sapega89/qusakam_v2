#!/usr/bin/env python3
# M7 (Sapega 2026-10-28: «без фонів, просто додай дорогу аби-яку, а потім вже намалювати все»): усі кімнати трьох
# графів регіонів (design/refs/room_graph_M1_canyon.png, _M3_city.png, _M4_lab.png) — граються, на тимчасових фонах
# (плани наявних кімнат того самого роду: стежка, пустеля, печера, льох, інтер'єр, місто, лабораторія).
#   python3 Scripts/Tools/build_world_rooms.py
# Що робить (кожен запуск — те саме, правте тут, а не в .tscn нових кімнат):
#   1. Пише сцени нових кімнат у SampleProject/Maps/ (підлога — схований шар тайлів Foreground, як у LabCells;
#      видно — смуги підлоги з плану роду, по одній на кожен відрізок; схили осипища й уступів — полігон колізії).
#   2. Переписує MapData.txt: наявні кімнати зсуваються туди, де їх ставить граф (межі клітинок лишаються свої,
#      крім перелічених у EXISTING_BORDERS), нові кімнати додаються з межами: -1 усередині, 1 — прохід, 0 — стіна.
#   3. Дописує в наявні кімнати лише вузли дверей (RoomDoor + арт входу), важелі й підбирання — якщо їх там ще немає.
# Головна дорога — суцільний біг крізь межі MetSys (без дверей); бічні місця — двері із затемненням; поверхи й
# спуски — провали в підлозі (згори лише вниз). Короткі шляхи замкнені там, де їх видно, а відчиняються важелем
# з дальнього боку (Lever, прапорець брами з gates.json).
import base64
import hashlib
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "SampleProject/Maps"
CELL_W, CELL_H = 864, 480
TILE = 32
FLOOR = 384                    # верх підлоги в клітинці, як на дорозі, в селі й у місті
FLOOR_ROW = FLOOR // TILE      # 12
ROWS = CELL_H // TILE          # 15
COLS = CELL_W // TILE          # 27
# Абетка ResourceUID (основа 34: a–y, 0–8); перша літера b–d: id влазить у 63 біти, а «a» (нуль) спереду Godot відкидає — інакше текст не той, що в кеші.
UID_CHARS = "abcdefghijklmnopqrstuvwxy012345678"

ROOM_DOOR = "res://SampleProject/Scenes/Gameplay/Objects/room_door.tscn"
ENTRANCE = "res://SampleProject/Scenes/Gameplay/Objects/room_entrance.tscn"
LEVER = "res://SampleProject/Scenes/Gameplay/Objects/lever.tscn"
WALL = "res://SampleProject/Objects/BreakableWall.tscn"
PICKUP = "res://SampleProject/Objects/ItemPickup.tscn"
CHEST = "res://SampleProject/Objects/Chest.tscn"
SECRET = "res://SampleProject/Scenes/Gameplay/Objects/secret_area.tscn"
GUARD = "res://SampleProject/Scenes/Gameplay/Objects/NPCs/gate_guard.tscn"
NPC = "res://SampleProject/Scenes/Gameplay/Objects/NPCs/"
BG = "res://SampleProject/Assets/Backgrounds/"
ART = {name: BG + "Decor/%s/%s_sheet.png" % (name, name) for name in
       ("door_elder", "cave_mouth", "palisade_gate", "mesa_cleft", "palace_door", "lab_door")}
# Розмір кадру й отвір (RoomEntrance.OPENINGS) кожного арту входу, px кадру.
ART_SIZE = {"door_elder": (52, 76), "cave_mouth": (110, 100), "palisade_gate": (150, 87), "mesa_cleft": (110, 112),
            "palace_door": (100, 104), "lab_door": (72, 88)}
OPENING = {"door_elder": (14, 7, 22, 56), "cave_mouth": (34, 38, 30, 52), "palisade_gate": (69, 26, 20, 56),
           "mesa_cleft": (39, 30, 23, 49), "palace_door": (32, 11, 36, 74), "lab_door": (14, 6, 33, 65)}
# Масштаб арту входу (RoomEntrance.SCALES): двері 112 px арту = 168 px світу (D814, B192).
ART_SCALE = {"door_elder": 2.21, "cave_mouth": 1.68, "palisade_gate": 1.93, "mesa_cleft": 1.5, "palace_door": 1.615,
             "lab_door": 1.91}

# Тимчасові фони за родом кімнати: далекий план, середній план, смуга підлоги (усе з наявних кімнат).
#   far/mid: (текстура, scroll), floor: (текстура, region y), fill: колір землі під смугою.
KITS = {
    "path": {"far": ("MountainPath/gen_far.png", 0.3), "mid": ("MountainPath/gen_mid.png", 0.75),
             "floor": ("MountainPath/gen_ground.png", 0), "fill": "Color(0.29, 0.2, 0.16, 1)", "sky": "Color(0.56, 0.74, 0.9, 1)",
             "music": "canyon_echoes", "ambience": "amb_canyon_echo", "surface": "sand", "interior": False},
    "desert": {"far": ("BanditCamp/gen_far.png", 0.4), "mid": ("Road/gen_mid.png", 0.8),
               "floor": ("BanditCamp/gen_floor.png", 0), "fill": "Color(0.36, 0.24, 0.17, 1)",
               "music": "whispers_in_the_sand", "ambience": "amb_desert_wind", "surface": "sand", "interior": False},
    "cave": {"far": ("LizardCave/gen_far.png", 0.4), "mid": ("LizardCave/gen_wall.png", 0.8),
             "floor": ("LizardCave/gen_floor.png", 0), "fill": "Color(0.13, 0.1, 0.1, 1)",
             "music": "canyon_echoes", "ambience": "amb_canyon_echo", "surface": "stone", "interior": True},
    "cellar": {"far": ("Cellar/gen_far.png", 0.4), "mid": ("Cellar/gen_mid.png", 0.8),
               "floor": ("Cellar/gen_floor.png", 0), "fill": "Color(0.12, 0.1, 0.1, 1)",
               "music": "dunes_of_silence", "ambience": "amb_hall", "surface": "stone", "interior": True},
    "interior": {"far": None, "mid": ("ElderHouse/gen_wall.png", 0.9),
                 "floor": ("ElderHouse/gen_floor.png", 0), "fill": "Color(0.16, 0.11, 0.09, 1)",
                 "music": "ash_and_oasis", "ambience": "amb_hall", "surface": "wood", "interior": True},
    "hall": {"far": None, "mid": ("Hall/gen_wall.png", 0.9),
             "floor": ("Hall/gen_floor.png", 0), "fill": "Color(0.16, 0.11, 0.09, 1)",
             "music": "scorchlight_mirage", "ambience": "amb_hall", "surface": "wood", "interior": True},
    "city": {"far": ("City/gen_far.png", 0.4), "mid": ("City/gen_near.png", 0.8),
             "floor": ("Terrain/City_Terrain.png", 256), "fill": "Color(0.3, 0.22, 0.17, 1)", "sky": "Color(0.62, 0.78, 0.9, 1)",
             "music": "scorchlight_mirage", "ambience": "amb_city_crowd", "surface": "stone", "interior": False},
    "lab": {"far": ("Lab/gen_far.png", 0.4), "mid": ("Lab/gen_mid.png", 0.8),
            "floor": ("Lab/gen_slab.png", 0), "fill": "Color(0.1, 0.1, 0.12, 1)",
            "music": "dunes_of_silence", "ambience": "amb_lab_hum", "surface": "stone", "interior": True},
}
TEX_SIZE = {
    "MountainPath/gen_far.png": (576, 324), "MountainPath/gen_mid.png": (576, 324), "MountainPath/gen_ground.png": (576, 49),
    "BanditCamp/gen_far.png": (1152, 324), "Road/gen_mid.png": (576, 324), "BanditCamp/gen_floor.png": (576, 45),
    "LizardCave/gen_far.png": (1152, 324), "LizardCave/gen_wall.png": (576, 324), "LizardCave/gen_floor.png": (576, 49),
    "Cellar/gen_far.png": (1152, 324), "Cellar/gen_mid.png": (576, 324), "Cellar/gen_floor.png": (1152, 45),
    "ElderHouse/gen_wall.png": (576, 324), "ElderHouse/gen_floor.png": (576, 64),
    "Hall/gen_wall.png": (576, 324), "Hall/gen_floor.png": (576, 64),
    "City/gen_far.png": (576, 324), "City/gen_near.png": (576, 324), "Terrain/City_Terrain.png": (1728, 43),
    "Lab/gen_far.png": (576, 324), "Lab/gen_mid.png": (576, 324), "Lab/gen_slab.png": (576, 64),
}


def uid_for(name: str) -> str:
    h = hashlib.sha1(("qusakam-m7-" + name).encode()).digest()
    return "bcd"[h[0] % 3] + "".join(UID_CHARS[b % len(UID_CHARS)] for b in h[1:13])


def door_pos(art: str, x: float, floor: float, scale: float = 0.0) -> tuple[float, float]:
    """Двері (RoomDoor) в отворі арту, що стоїть низом посередині на (x, floor): посередині отвору впоперек, а по висоті —
    там, де центр отвору був у масштабі 1.5 (усередині більшого отвору D814): герой на підлозі дістає до дверей
    (verify_room_entrances: < 64 px)."""
    w, h = ART_SIZE[art]
    ox, oy, ow, oh = OPENING[art]
    return x + (ox + ow / 2 - w / 2) * (scale or ART_SCALE[art]), floor + (oy + oh / 2 - h) * 1.5


# Намальовані шахти бічних кімнат Лабораторії: двері лишаються там, де стояли в отворі lab_door (у старому масштабі 1.5).
LAB_DOOR_Y = door_pos("lab_door", 0, FLOOR, 1.5)[1]


# ── Нові кімнати ───────────────────────────────────────────────────────────────────────────────────────────────
# cells: (x0, y0, w, h) на карті MetSys (шар layer). open: сторони, крізь які йде дорога без дверей,
# [(рядок кімнати, "L"/"R")]. holes: провали в підлозі [(рядок, x0, x1)] (локальні px кімнати) — падіння вниз.
# Провал у нижньому рядку — прохід униз на карті (межа D = 1); клітинка під ним належить іншій кімнаті.
# slope: схил ("down" — згори ліворуч донизу праворуч, "up" — навпаки) у кімнаті 1×2.
# doors: (вузол, рядок, x, арт, кімната, двері там, дод.) — дод.: gate, sets_flag, cover. levers: (вузол, рядок, x, прапорець).
# Шлях до "Room/Door" дверей у наявній кімнаті — ті самі назви в EXISTING_DOORS.
ROOMS = {
    # ── M1: Каньйон шепотів ──
    "MountainPath": dict(loc="canyon_of_whispers", kit="path", cells=(3, 1, 3, 1), open=[(0, "L"), (0, "R")],
                         title=("Mountain Path", "Гірська стежка"), arrival=(0, 150),
                         targets={"village": (0, 2540), "canyon_bridge": (0, 60)}),
    "ScreeSlide": dict(loc="canyon_of_whispers", kit="path", cells=(6, 1, 1, 2), open=[(0, "L"), (1, "R")], slope="down",
                       slope_line=((96, 384), (720, 864)),  # поверхня gen_scree.png (ScreeSlide/README), −32
                       title=("Scree Slide", "Осипище"), arrival=(0, 60),
                       targets={"village": (1, 820), "canyon_bridge": (0, 40)}),
    "StreamGorge": dict(loc="canyon_of_whispers", kit="path", cells=(7, 2, 3, 1), open=[(0, "L"), (0, "R")],
                        title=("Stream Gorge", "Ущелина струмка"), arrival=(0, 150),
                        targets={"village": (0, 2540), "canyon_bridge": (0, 60)}),
    "RockLedges": dict(loc="canyon_of_whispers", kit="path", cells=(10, 1, 1, 2), open=[(1, "L"), (0, "R")], slope="up",
                       title=("Rock Ledges", "Скельні уступи"), arrival=(1, 60),
                       targets={"village": (0, 820), "canyon_bridge": (1, 40)}),
    "CaveUnderBridge": dict(loc="canyon_of_whispers", kit="cave", cells=(3, 2, 1, 3),
                            holes=[(0, 480, 864), (1, 0, 384), (2, 96, 224)], walls_in=True,
                            title=("Cave Under The Bridge", "Печера під мостом"), arrival=(0, 200),
                            targets={"city_gates": (2, 445)}),
    "CaveExit": dict(loc="canyon_of_whispers", kit="cave", cells=(3, 5, 1, 1), open=[(0, "L"), (0, "R")],
                     title=("Cave Exit", "Вихід з печери"), arrival=(0, 432), targets={"city_gates": (0, 820)}),
    "CanyonFloor": dict(loc="canyon_of_whispers", kit="desert", cells=(-1, 5, 4, 1), open=[(0, "R")],
                        holes=[(0, 2912, 3104)],
                        title=("Canyon Floor", "Дно каньйону"), arrival=(0, 2600),
                        # Тріщина в мертвій скелі (CanyonFloor/README): намальований отвір, брила — замурована тріщина.
                        doors=[("StashDoor", 0, 300, None, "SmugglersStash", "ExitDoor", {"cover": "Wall_Stash"})],
                        covers=[("Wall_Stash", 0, 300, "CanyonFloor/gen_cracked.png")],
                        targets={"city_gates": (0, 3420)}),
    "SmugglersStash": dict(loc="canyon_of_whispers", kit="cave", cells=(-1, 6, 1, 1),
                           # Вихід — намальований тунель до розбитої стіни (SmugglersStash/README): x 192.
                           title=("Smugglers' Stash", "Схованка контрабандистів"), arrival=(0, 192),
                           doors=[("ExitDoor", 0, 192, None, "CanyonFloor", "StashDoor", {})],
                           secrets=[("SecretArea_Stash", 0, 640)]),
    "LizardCaves": dict(loc="canyon_of_whispers", kit="cave", cells=(2, 6, 6, 1),
                        title=("Lizard Caves", "Печери ящерів"), arrival=(0, 600),
                        doors=[("ShrineDoor", 0, 140, "cave_mouth", "LizardCave", "DeepCavesDoor", {}),
                               ("RoadDoor", 0, 4980, "cave_mouth", "DesertRoad", "LizardCavesDoor",
                                {"gate": "lizard_caves_shortcut"})],
                        levers=[("RoadLever", 0, 4840, "lizard_caves_shortcut_open")]),
    "MesaTop": dict(loc="canyon_of_whispers", kit="desert", cells=(4, 3, 2, 1),
                    title=("Mesa Top", "Вершина Меси"), arrival=(0, 1560),
                    doors=[("ClimbDoor", 0, 1560, "mesa_cleft", "MesaClimb", "MesaTopDoor", {})]),
    "ZahraRest": dict(loc="canyon_of_whispers", kit="desert", cells=(10, 5, 2, 1), open=[(0, "L"), (0, "R")],
                      title=("Zahra's Rest", "Зарин привал"), arrival=(0, 200),
                      doors=[("WellDoor", 0, 900, None, "OldRuins", "WellDoor", {"gate": "ruins_well"}),
                             # Задня брама табору (Q119, граф: «ворота зсередини — скорочення до Зариного привалу»).
                             ("CampGateDoor", 0, 1500, "palisade_gate", "BanditCamp", "ShortcutDoor", {"gate": "camp_shortcut"})],
                      targets={"city_gates": (0, 1700)}),
    "Dunes": dict(loc="canyon_of_whispers", kit="desert", cells=(12, 5, 4, 1), open=[(0, "L"), (0, "R")],
                  title=("Dunes", "Дюни"), arrival=(0, 200), targets={"city_gates": (0, 3420)},
                  # Табір бандитів — стежкою з дюн (Q119, Dunes/README): намальований вхід до стежки на x 2700.
                  doors=[("CampDoor", 0, 2700, None, "BanditCamp", "ExitDoor", {"gate": "camp_door", "y": 334.5})]),
    "Chasm": dict(loc="canyon_of_whispers", kit="desert", cells=(16, 5, 1, 1), open=[(0, "L"), (0, "R")],
                  holes=[(0, 160, 704)], bridge=(144, 720, "chasm_bridge_down"),
                  title=("Chasm", "Провалля"), arrival=(0, 80), targets={"city_gates": (0, 820)}),
    "DryRiverbed": dict(loc="canyon_of_whispers", kit="cave", cells=(16, 6, 1, 1), holes=[(0, 576, 800)],
                        title=("Dry Riverbed", "Сухе русло"), arrival=(0, 300), targets={"city_gates": (0, 690)}),
    "Aqueduct": dict(loc="canyon_of_whispers", kit="cellar", cells=(16, 7, 4, 1), open=[(0, "L")],
                     title=("Aqueduct", "Акведук"), arrival=(0, 600),
                     # Обидва проходи намальовані (Aqueduct/README): бічні двері зі сходами й арка льоху з ґратою.
                     doors=[("ApproachDoor", 0, 2891, None, "GateApproach", "AqueductDoor", {}),
                            ("CellarDoor", 0, 3291, None, "GatehouseCellar", "AqueductDoor",
                             {"gate": "aqueduct_cellar"})],
                     targets={"city_gates": (0, 2900)}),
    "OldRuins": dict(loc="canyon_of_whispers", kit="cellar", cells=(11, 7, 5, 1), open=[(0, "R")],
                     title=("Old Ruins", "Старі руїни"), arrival=(0, 300),
                     doors=[("WellDoor", 0, 151, None, "ZahraRest", "WellDoor", {})]),  # шахта криниці (OldRuins/README)
    "GateApproach": dict(loc="canyon_of_whispers", kit="desert", cells=(17, 5, 2, 1), open=[(0, "L"), (0, "R")],
                         title=("Gate Approach", "Підхід до брами"), arrival=(0, 900),
                         # Криничний будиночок (GateApproach/README): намальований отвір; важіль — у кам'яному корпусі
                         # з храповиком (його Base ховається, ручка — на осі колеса, 16 px над підлогою).
                         doors=[("AqueductDoor", 0, 1291, None, "Aqueduct", "ApproachDoor", {})],
                         levers=[("BridgeLever", 0, 110, "chasm_bridge_down", {"base": False, "handle_y": -16})],
                         targets={"city_gates": (0, 1700)}),
    # ── M3: Місто ──
    # Кузня й каплиця — фасади ремісничого кварталу (D773, CraftQuarter/README): з ринку сюди перейшли ковадло, коваль,
    # жриця Самал і маркер ForgeDoor (ціль телепортів тестів і знімків).
    "CraftQuarter": dict(loc="city", kit="city", cells=(24, 5, 3, 1), open=[(0, "L"), (0, "R")],
                         title=("Craft Quarter", "Ремісничий квартал"), arrival=(0, 200),
                         markers=[("ForgeDoor", 1106, 396)],
                         npcs=[("Blacksmith", NPC + "blacksmith.tscn", 979), ("OathPriest", NPC + "oath_priest.tscn", 2395)]),
    "PalaceSquare": dict(loc="city", kit="city", cells=(27, 5, 2, 1), open=[(0, "L")],
                         title=("Palace Square", "Площа палацу"), arrival=(0, 200),
                         # Намальовані двері палацу (PalaceSquare/README): центр подвійних дверей — (1560, 300).
                         doors=[("MayorHallDoor", 0, 1560, None, "MayorHall", "CityDoor", {"y": 300})],
                         guards=[("GuardLeft", 1500), ("GuardRight", 1620)]),
    # Двері дахів намальовані (Rooftops/README): верх драбини, мотузка вниз по стіні, забиті двері голубника.
    "Rooftops": dict(loc="city", kit="city", cells=(19, 4, 3, 1),
                     title=("Rooftops", "Дахи"), arrival=(0, 2400),
                     doors=[("LadderDoor", 0, 2400, None, "City", "RooftopsDoor", {"y": 322.5}),
                            ("SlideDoor", 0, 150, None, "CityGates", "RooftopsDoor",
                             {"sets_flag": "city_rooftops_slide", "y": 322.5}),
                            ("LoftDoor", 0, 1300, None, "PigeonLoft", "ExitDoor", {"cover": "Wall_Loft", "y": 300})],
                     covers=[("Wall_Loft", 0, 1300, "Rooftops/gen_boards.png")]),
    "PigeonLoft": dict(loc="city", kit="interior", cells=(20, 3, 1, 1),
                       title=("Pigeon Loft", "Голубник"), arrival=(0, 432),
                       doors=[("ExitDoor", 0, 432, None, "Rooftops", "LoftDoor", {"y": 300})],
                       secrets=[("SecretArea_Loft", 0, 640)]),
    "TavernAttic": dict(loc="city", kit="interior", cells=(23, 4, 2, 1),
                        title=("Tavern Attic", "Горище таверни"), arrival=(0, 200),
                        doors=[("LadderDoor", 0, 200, None, "City", "TavernAtticDoor", {"y": 322.5})]),
    "MayorArchive": dict(loc="city", kit="hall", cells=(29, 4, 1, 1),
                         title=("Mayor's Archive", "Архів мера"), arrival=(0, 200),
                         doors=[("BookshelfDoor", 0, 200, None, "MayorHall", "ArchiveDoor", {"y": 300})]),
    # Криниця, арка льоху з ґратою й пролом у торцевій стіні — намальовані (Cistern/README).
    "Cistern": dict(loc="city", kit="cellar", cells=(22, 7, 3, 1),
                    title=("Cistern", "Цистерна під ринком"), arrival=(0, 1700),
                    doors=[("WellDoor", 0, 1700, None, "City", "CisternDoor", {}),
                           ("CellarDoor", 0, 140, None, "GatehouseCellar", "CisternDoor",
                            {"gate": "cistern_cellar"}),
                           ("StashDoor", 0, 2300, None, "CisternStash", "ExitDoor", {"cover": "Wall_Stash"})],
                    levers=[("CellarLever", 0, 290, "cistern_cellar_open")],
                    covers=[("Wall_Stash", 0, 2300, "Cistern/gen_cracked.png")]),
    "CisternStash": dict(loc="city", kit="cellar", cells=(24, 8, 2, 1),
                         title=("Cistern Stash", "Схованка в цистерні"), arrival=(0, 200),
                         doors=[("ExitDoor", 0, 200, None, "Cistern", "StashDoor", {"y": 300})],
                         secrets=[("SecretArea_Stash", 0, 1100)]),
    # ── M4: Лабораторія (шар 2), граф v3 (D863, D865, design/refs/room_graph_M4_lab_v3.png): бічні місця ──
    # Коридор алхіміка — на захід від верхнього поверху (двері праворуч), комора — ще західніше.
    "AlchemistCorridor": dict(loc="laboratory", kit="lab", cells=(11, 3, 3, 1), layer=2,
                              title=("Alchemist's Corridor", "Коридор алхіміка"), arrival=(0, 2450),
                              doors=[("FloorDoor", 0, 2450, None, "LabTopFloor", "CorridorDoor", {"y": 300}),
                                     ("StoreDoor", 0, 150, None, "AlchemistStore", "ExitDoor",
                                      {"gate": "alchemist_store", "y": 300})],
                              # Ключ — посередині стільниці намальованого столу (AlchemistCorridor/README).
                              pickups=[("Pickup_AlchemistKey", 0, 1300, "alchemist_key", 311)]),
    "AlchemistStore": dict(loc="laboratory", kit="lab", cells=(9, 3, 2, 1), layer=2,
                           title=("Alchemist's Storeroom", "Комора алхіміка"), arrival=(0, 1550),
                           doors=[("ExitDoor", 0, 1550, None, "AlchemistCorridor", "StoreDoor", {"y": 300})]),
    "MalikStash": dict(loc="laboratory", kit="lab", cells=(12, 6, 2, 1), layer=2,
                       title=("Malik's Stash", "Схованка Маліка"), arrival=(0, 1450),
                       doors=[("SlabDoor", 0, 1450, None, "LabCells", "StashDoor", {"y": LAB_DOOR_Y})],
                       secrets=[("SecretArea_Stash", 0, 700)]),
    # Обвалений дренаж — під нижнім поверхом: бічні сходи (GrateDoor) — під люком нижнього поверху, скриня — у глибині.
    "CollapsedDrain": dict(loc="laboratory", kit="cellar", cells=(14, 6, 7, 1), layer=2,
                           title=("Collapsed Drain", "Обвалений дренаж"), arrival=(0, 3000),
                           doors=[("HatchDoor", 0, 150, None, "LabCells", "DrainDoor", {"y": LAB_DOOR_Y}),
                                  ("GrateDoor", 0, 3000, None, "Laboratory", "DrainDoor", {"y": LAB_DOOR_Y})],
                           chests=[("Chest_Drain", 0, 5400, {"potion_lesser": 1, "herb": 2})]),
}

# Двері, важелі й підбирання, що дописуються в наявні кімнати (лише вузли; підлогу не чіпаємо).
#   (вузол, x, підлога, арт, кімната, двері там, дод.)
EXISTING_DOORS = {
    "LizardCave": [("DeepCavesDoor", 150, 416, "cave_mouth", "LizardCaves", "ShrineDoor", {})],
    # Дорога: рівна підлога, клір від трави (verify_ambient_critters) і від скрині грифа (4680), поза кадром заслонів переднього плану (OccluderRock2 при камері на 3458–4128).
    "DesertRoad": [("LizardCavesDoor", 3340, 384, "cave_mouth", "LizardCaves", "RoadDoor", {"gate": "lizard_caves_shortcut"})],
    "MesaClimb": [("MesaTopDoor", 480, 180, "mesa_cleft", "MesaTop", "ClimbDoor", {})],
    "GatehouseCellar": [("AqueductDoor", 300, 416, "cave_mouth", "Aqueduct", "CellarDoor", {"gate": "aqueduct_cellar"}),
                        ("CisternDoor", 1450, 416, "cave_mouth", "Cistern", "CellarDoor", {"gate": "cistern_cellar"})],
    # Ринок: клір від зупинок городян, NPC і реквізиту (verify_city_life).
    # Драбини на дахи й на горище намальовані (City/README M6c-3: RooftopsLadder, AtticStall — вузли в City.tscn).
    "City": [("RooftopsDoor", 880, 384, None, "Rooftops", "LadderDoor", {"y": 322.5}),
             ("TavernAtticDoor", 2450, 384, None, "TavernAttic", "LadderDoor", {"y": 322.5}),
             # Криниця на ринку — сама інтерактивна (ковток води), тож спуск у цистерну — окремий люк у кінці ринку.
             ("CisternDoor", 2540, 384, "door_elder", "Cistern", "WellDoor", {})],
    # Брама: між кущиками трави й далі від жайворонка (verify_ambient_critters).
    "CityGates": [("RooftopsDoor", 638, 384, None, "Rooftops", "SlideDoor", {"gate": "city_rooftops", "y": 322.5})],
    "MayorHall": [("ArchiveDoor", 250, 384, "door_elder", "MayorArchive", "BookshelfDoor", {"gate": "mayor_archive"})],
    "LabCells": [("StashDoor", 1450, 384, "lab_door", "MalikStash", "SlabDoor", {"gate": "malik_stash"}),
                 ("DrainDoor", 900, 384, "lab_door", "CollapsedDrain", "HatchDoor", {})],
    # Лабораторія v3: двері сходів нагору (вхід на сходи — суцільний біг крізь межу), люк у дренаж, коридор алхіміка.
    "Laboratory": [("DrainDoor", 3000, 384, "lab_door", "CollapsedDrain", "GrateDoor", {})],
    "LabStairsEast": [("FloorDoor", 1590, 208, "lab_door", "LabMiddleFloor", "StairsDoor", {})],
    "LabMiddleFloor": [("StairsDoor", 4000, 384, "lab_door", "LabStairsEast", "FloorDoor", {})],
    "LabStairsWest": [("FloorDoor", 138, 208, "lab_door", "LabTopFloor", "StairsDoor", {})],
    "LabTopFloor": [("CorridorDoor", 120, 384, "lab_door", "AlchemistCorridor", "FloorDoor", {}),
                    ("StairsDoor", 330, 384, "lab_door", "LabStairsWest", "FloorDoor", {})],
}
EXISTING_LEVERS = {"GatehouseCellar": [("AqueductLever", 420, 416, "aqueduct_cellar_open")]}
# D921: ключа зі столу мера (mayor_key) у демо немає — архів замкнений, місце ключа вирішать з архівом після демо.
EXISTING_PICKUPS: dict[str, list] = {}

# Наявні кімнати на карті: найменша клітинка (x, y) — там, де їх ставить граф (форма кімнати лишається своя).
PLACE = {
    "Canyon": (0, 1), "DragonMural": (1, 0), "Village": (11, 1), "ElderHouse": (13, -1),
    "LizardCave": (0, 6), "DesertRoad": (4, 5), "BanditCamp": (12, 3), "MesaClimb": (6, 3),
    "CityGates": (19, 5), "GatehouseCellar": (20, 7), "City": (21, 5), "MayorHall": (29, 5),
    "LabCells": (12, 5), "LabBoss": (18, 2), "LaboratoryOutside": (20, 2),
}
# Лабораторія v3 (D863, D865): поверхи й сходи будує build_laboratory.gd (сцени — його), тут — лише їхні клітинки карти
# (шар 2) і проходи суцільним бігом (open, як у ROOMS). Лабораторія під землею, герой підіймається: нижній поверх
# праворуч → сходи схід → середній ліворуч (на схід — кишеня вартового) → сходи захід → верхній праворуч → двері
# вгору в залу джина (LabBoss, рівень поверхні) → подвір'я (LaboratoryOutside).
LAB_V3 = {
    "Laboratory": dict(cells=(14, 5, 5, 1), open=[(0, "R")]),
    "LabStairsEast": dict(cells=(19, 5, 2, 1), open=[(0, "L")]),
    "LabMiddleFloor": dict(cells=(16, 4, 5, 1), open=[(0, "L"), (0, "R")]),
    "LabGuardPocket": dict(cells=(21, 4, 2, 1), open=[(0, "L")]),
    "LabStairsWest": dict(cells=(14, 4, 2, 1), open=[(0, "R")]),
    "LabTopFloor": dict(cells=(14, 3, 5, 1)),
}
# Межі наявних кімнат, що міняються: (кімната, клітинка відносно її найменшої, сторона R/D/L/U, значення).
EXISTING_BORDERS = [
    ("Canyon", (0, 1), 1, 0),       # спуск з каньйону — кат-сцена в печеру під мостом, не прохід униз на дорогу
    ("DesertRoad", (0, 0), 2, 1),   # з виходу з печери на дорогу
    ("City", (2, 0), 0, 1),         # ринок → ремісничий квартал (двері палацу тепер на площі)
]
SIDES = {"R": 0, "D": 1, "L": 2, "U": 3}


# ── Бої й життя в нових кімнатах (rooms-finish) ─────────────────────────────────────────────────────────────────
# fights: (вузол, рядок, x тригера, рівень, win_xp, [(тип, x[, висота над підлогою])]) — звичайні гурти (D817/D831:
#   щонайбільше бандит + шакал або два бандити + шакал; D840/D857 скейлить рівень від героя). На дорозі від мосту до села
#   й на вулицях міста боїв немає (world_structure_plan, D773). Нагорода за перемогу — win_xp, щоб рівні маршруту
#   трималися (verify_xp_curve).
# critters: (сцена, рядок, x[, дод.]) — D803: жайворонки й метелики надворі, голуби в місті, кажани в печерах і льохах
#   (на FrontDark, висять під склепінням), міль біля ламп і свічок; ≥ 96 px від дверей/NPC/скрині/підбирання,
#   ≥ 200 px від тригера бою. air: (сцена, рядок, x, y від верху рядка[, дод.]) — D804, одна-дві тихі речі з README.
DECOR = "res://SampleProject/Scenes/Backgrounds/Decor/%s.tscn"
SPAWNER = "res://SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd"
SPAWN_POINT = "res://SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd"
FLY_HEIGHT = {"vulture": 174}   # висота спавну грифа над підлогою, як на DesertRoad (кажани-вороги — лише в льоху, D643)


def pollen(w: int, amount: int = 0) -> tuple:
    """Пилок / пісок на всю ширину кімнати (як на дорозі: 48 частинок на 5184 px)."""
    return ("atmo_pollen", 0, w / 2, 250, {"emission_rect_extents": "Vector2(%g, 140)" % (w / 2),
                                           "amount": amount or max(12, min(48, int(w / 108)))})


def spores(x: float, half: float, amount: int = 16) -> tuple:
    return ("atmo_spores", 0, x, 250, {"emission_rect_extents": "Vector2(%g, 110)" % half, "amount": amount})


LIVING = {
    # ── M1: Каньйон шепотів ──
    "MountainPath": dict(critters=[("critter_bird", 0, 700), ("critter_butterfly", 0, 1300), ("critter_bird", 0, 1900, {"perch_flip": True})],
                         air=[pollen(2592), ("dust", 0, 1600, 336)]),
    "ScreeSlide": dict(critters=[("critter_bird", 1, 820)], air=[("atmo_pollen", 0, 432, 480, {"emission_rect_extents": "Vector2(432, 300)", "amount": 12})]),
    "StreamGorge": dict(critters=[("critter_butterfly_blue", 0, 900), ("critter_butterfly_blue", 0, 1700), ("critter_bird", 0, 2300)],
                        air=[pollen(2592)]),
    "RockLedges": dict(critters=[("critter_bird", 0, 820, {"perch_flip": True})],
                       air=[("atmo_pollen", 0, 432, 480, {"emission_rect_extents": "Vector2(432, 300)", "amount": 12})]),
    "CaveUnderBridge": dict(critters=[("critter_bat", 1, 640)], air=[("atmo_light_shaft", 0, 640, 40)]),
    "CaveExit": dict(critters=[("critter_bat", 0, 680)], air=[("atmo_light_shaft", 0, 432, 40)]),
    "CanyonFloor": dict(fights=[("Fight_CanyonFloor", 0, 1500, 3, 0, [("fast", 1660), ("vulture", 1780)])],
                        critters=[("critter_butterfly", 0, 800), ("critter_bird", 0, 2200), ("critter_bat", 0, 3260)],
                        air=[pollen(3456), ("dust", 0, 2500, 336)]),
    "SmugglersStash": dict(critters=[("critter_bat", 0, 420)], air=[("atmo_motes", 0, 600, 250)]),
    "LizardCaves": dict(fights=[("Fight_Lizards", 0, 1800, 3, 0, [("fast", 1980), ("fast", 2120)]),
                                ("Fight_Scorpion", 0, 3600, 3, 0, [("tank", 3780)])],
                        critters=[("critter_bat", 0, 1100), ("critter_bat", 0, 2700)],
                        air=[("atmo_fireflies", 0, 2600, 250, {"emission_rect_extents": "Vector2(2400, 110)", "amount": 32})]),
    "MesaTop": dict(fights=[("Fight_Lookout", 0, 900, 3, 0, [("archer", 560), ("melee", 700)])],
                    critters=[("critter_bird", 0, 1250)], air=[pollen(1728), ("dust", 0, 300, 336)]),
    "ZahraRest": dict(critters=[("critter_butterfly_blue", 0, 450), ("critter_butterfly_blue", 0, 620), ("critter_bird", 0, 1250)],
                      air=[pollen(1728)]),
    "Dunes": dict(fights=[("Fight_Dunes", 0, 1500, 4, 10, [("melee", 1660), ("fast", 1780)])],
                  critters=[("critter_butterfly", 0, 600), ("critter_bird", 0, 2300)],
                  air=[pollen(3456), ("dust", 0, 3000, 336)]),
    "Chasm": dict(critters=[("critter_bird", 0, 790, {"perch_flip": True})], air=[pollen(864), ("dust", 0, 432, 304)]),
    "DryRiverbed": dict(critters=[("critter_bat", 0, 200)], air=[("atmo_light_shaft", 0, 300, 40)]),
    "Aqueduct": dict(fights=[("Fight_Aqueduct", 0, 1500, 4, 10, [("archer", 1820), ("fast", 1660)])],
                     critters=[("critter_bat", 0, 2300)], air=[("atmo_light_shaft", 0, 900, 40)]),
    "OldRuins": dict(fights=[("Fight_Ruins", 0, 2000, 4, 0, [("melee", 2160), ("shield", 2260), ("fast", 2380)])],
                     critters=[("critter_bat", 0, 3200)], air=[("atmo_light_shaft", 0, 1200, 40), spores(2160, 2000, 24)]),
    "GateApproach": dict(critters=[("critter_bird", 0, 600)], air=[pollen(1728), ("dust", 0, 1500, 336)]),
    # ── M3: Місто ──
    "CraftQuarter": dict(critters=[("critter_pigeon", 0, 700), ("critter_pigeon", 0, 1800)], air=[pollen(2592)]),
    "PalaceSquare": dict(critters=[("critter_pigeon", 0, 500), ("critter_pigeon", 0, 900)], air=[pollen(1728)]),
    "Rooftops": dict(critters=[("critter_pigeon", 0, 700), ("critter_pigeon", 0, 1900)], air=[pollen(2592)]),
    "PigeonLoft": dict(critters=[("critter_pigeon", 0, 200), ("critter_pigeon", 0, 760, {"perch_flip": True})],
                       air=[("atmo_light_shaft", 0, 600, 40)]),
    "TavernAttic": dict(critters=[("critter_moth", 0, 900, {"hover": 200}), ("critter_mouse", 0, 1300, {"hole": 84})],
                        air=[("atmo_light_shaft", 0, 700, 40)]),
    "MayorArchive": dict(critters=[("critter_moth", 0, 600, {"hover": 200})], air=[("atmo_light_shaft", 0, 480, 40)]),
    "Cistern": dict(fights=[("Fight_Smugglers", 0, 1200, 5, 0, [("melee", 1000), ("archer", 880)])],
                    critters=[("critter_bat", 0, 2000)], air=[("atmo_light_shaft", 0, 1700, 40)]),
    "CisternStash": dict(critters=[("critter_bat", 0, 800)], air=[("atmo_motes", 0, 1000, 250)]),
    # ── M4: Лабораторія ──
    "AlchemistCorridor": dict(fights=[("Fight_Corridor", 0, 700, 8, 0, [("shield", 860), ("fast", 960)])],
                              critters=[("critter_moth", 0, 1900, {"hover": 200})], air=[("atmo_steam", 0, 1300, 300)]),
    "AlchemistStore": dict(critters=[("critter_moth", 0, 900, {"hover": 200})], air=[("atmo_motes", 0, 900, 250)]),
    "MalikStash": dict(critters=[("critter_moth", 0, 400, {"hover": 200})], air=[("atmo_motes", 0, 700, 250)]),
    "CollapsedDrain": dict(fights=[("Fight_Drain", 0, 2000, 9, 0, [("tank", 2160), ("fast", 2260)])],
                           critters=[("critter_bat", 0, 4200)], air=[spores(3200, 2800, 32)]),  # центр поза GrateDoor (x 3000)
}


# ── Намальовані плани (wire-backdrops, Sapega 2026-10-28: «чому не всі арти підключені?») ───────────────────────
# Кімнати з готовим артом малюють його замість тимчасового комплекту KITS — механічно з таблиць README тек
# Backgrounds/<кімната>/. Площина: (вузол, текстура, (множник x, y), позиція у світі кімнати, дод.), дод.:
#   tile — ширина плитки в арті (Parallax2D повторює її), region — Rect2 арту, material, z, modulate, flip.
# Множник 1.0 — звичайний Sprite2D у Ground (намальована підлога, verify_map_geometry правило 6); front — заслін
# у FrontDark (foreground_dark.tscn, ×1.3 по x, ×1 по y; назва Occluder*, D750).
#
# Дорога каньйону (MountainPath/README «Seamless road»): плани прив'язані до світу стежки, у README якорі — арт стежки
# при камері 0, і площина з множником f стоїть на якорі − f × камера. Стежка тут на клітинку ширша, ніж у README
# (3 клітинки, не 2): зайва клітинка — на заході, тож (x, y) лівого верхнього кута кожної кімнати у світі README, арт px:
ROAD = {"MountainPath": (-576, 0), "ScreeSlide": (1152, 0), "StreamGorge": (1728, 320), "RockLedges": (3456, 0)}
# Лінія ходу арту доріг і печери — 416 світу, підлога кімнат world-rooms — 384: усі плани на 32 px вище.
DY = -32
# Parallax2D рахує камеру як центр − половина вікна 1920×1080 і не зважає на zoom камери (кадр — 864×486 світу):
# вузол стоїть на (1 − f) × (центр − (960, 540)), а не на (1 − f) × лівий верхній кут кадру. Тож площина, що в README
# стоїть на якорі − f × камера, отримує позицію + (1 − f) × (960 − 432, 540 − 243). Виміряно в Godot 4.6.2.
VIEW_FIX = (528, 297)
MP = "MountainPath/"
AC = "AlchemistCorridor/"
PILLAR_Y = -10


def at(anchor: tuple[float, float], f: tuple[float, float], off: tuple[float, float],
       cam: tuple[float, float] = (0, 0), f_node: tuple[float, float] | None = None) -> tuple[float, float]:
    """Позиція площини у світі кімнати: README малює її на якорі − f × камера (арт; камера у світі README = камера
    кімнати / 1.5 + off). Вузол прокручується з f_node (за замовчуванням f); якщо f_node ≠ f, кадр README
    відтворюється точно при камері кімнати cam (світ)."""
    fn = f_node or f
    return tuple(1.5 * (anchor[i] - f[i] * (cam[i] / 1.5 + off[i])) + fn[i] * cam[i] + (DY if i else 0) for i in (0, 1))


def road(room: str) -> list:
    off = ROAD[room]
    sky = ("Sky", "DesertOasis/bg4/plan5.png", (0, 0), (0, 0), {})
    barrier = ("Barrier", MP + "gen_barrier.png", (0.1, 0.1), at((115, 4), (0.1, 0.1), off), {})
    far = ("Far", MP + "gen_far.png", (0.3, 0.3), at((0, 0), (0.3, 0.3), off), {"tile": 576})
    plume = ("Plume", MP + "gen_plume.png", (0.4, 0.4), at((572, -12), (0.4, 0.4), off), {})
    planes = [sky, barrier, "clouds", far]
    if room == "MountainPath":
        planes += [plume,
                   ("Mid", MP + "gen_mid.png", (0.75, 0.75), at((0, 0), (0.75, 0.75), off), {"tile": 576}),
                   ("Waymarker", MP + "gen_waymarker.png", (0.9, 0.9), at((380 + 0.9 * 576, 279 - 57), (0.9, 0.9), off), {}),
                   ("Ground", MP + "gen_ground.png", (1, 1), at((0, 277), (1, 1), off), {"tile": 576}),
                   ("OccluderRock1", MP + "gen_front.png", "front", at((420, 152), (1.3, 1.3), off, (864, 0), (1.3, 1)), {})]
    elif room == "ScreeSlide":
        planes += [plume,
                   ("Mid", "ScreeSlide/gen_mid.png", (0.75, 0.75), at((0.75 * 1152, 0), (0.75, 0.75), off), {}),
                   ("Ground", "ScreeSlide/gen_scree.png", (1, 1), at((1152, 0), (1, 1), off), {}),
                   ("OccluderRock1", MP + "gen_front.png", "front",
                    at((-40 + 1.3 * 1152, 152 + 1.3 * 316), (1.3, 1.3), off, (0, 474), (1.3, 1)), {})]
    elif room == "StreamGorge":
        planes += [("Plume", "StreamGorge/gen_plume.png", (0.35, 0.35), at((978, 90), (0.35, 0.35), off), {}),
                   ("Mid", "StreamGorge/gen_mid.png", (0.75, 0.75), at((1296, 232), (0.75, 0.75), off), {}),
                   ("Ground", "StreamGorge/gen_ground.png", (1, 1), at((1728, 570), (1, 1), off), {}),
                   ("OccluderRock1", "StreamGorge/gen_front.png", "front",
                    at((3035, 603), (1.3, 1.3), off, (0, -6), (1.3, 1)), {})]
    else:  # RockLedges: уступи зігнуті під пандус world-rooms (ledges_ramp.py, D830)
        # D919: великий шлейф і над уступами — план ущелини (StreamGorge/gen_plume.png, ×0.35): пухнаста голова над
        # кадром верху, хвіст на захід через небо, стовбур (стовпці ~600–650) іде вниз за перший будинок (кадр x ~300),
        # обрізаний низ — за будинком і муром при кожній камері y (D796: дим — з-за проходу в село, не вогонь тут).
        # D918: спалені будинки на плані ×0.85, не ×0.6 — арт ×0.85/0.6 (розмір ряду, D814), над плато півтора будинки;
        # лівий нижній кут — x 222 кадру верху, як був, пороги — на тому ж рядку 252 (низ 252 + 53 × 0.85/0.6 = 327).
        planes += [("Plume", "StreamGorge/gen_plume.png", (0.35, 0.35), at((885, 14), (0.35, 0.35), off), {}),
                   ("Mid", "RockLedges/gen_mid.png", (0.75, 0.75), at((2592, 232), (0.75, 0.75), off), {}),
                   ("BurntHouses", "RockLedges/gen_burnt_houses.png", (0.85, 0.85),
                    at((222 + 0.85 * 3456, 327 - 278 * 0.85 / 0.6), (0.85, 0.85), off), {"scale": 1.5 * 0.85 / 0.6}),
                   ("VillageWall", "RockLedges/gen_village_wall.png", (0.9, 0.9), at((3302, 185), (0.9, 0.9), off), {}),
                   ("Ground", "RockLedges/gen_ledges_ramp.png", (1, 1), at((3456, 0), (1, 1), off), {}),
                   ("OccluderRock1", "StreamGorge/gen_front.png", "front",
                    at((4453, 603), (1.3, 1.3), off, (0, 474), (1.3, 1)), {})]
    return planes


def cave() -> list:
    """Печера під мостом (BridgeCave/README): один екран завширшки, камера ходить лише вниз; множник — по y."""
    off = (0, 0)
    return [("Far", "BridgeCave/gen_far.png", (1, 0.5), at((0, 0), (1, 0.5), off), {}),
            ("Waymark", "BridgeCave/gen_waymark.png", (1, 0.9), at((236, 223), (1, 0.9), off), {}),
            ("Ground", "BridgeCave/gen_wall.png", (1, 1), at((0, 0), (1, 1), off), {}),
            ("OccluderStalactites", "BridgeCave/gen_front.png", "front", at((400, 0), (1.3, 1.3), off, (0, 0), (1.3, 1)), {})]


# Меза й Зарин привал (MesaTop/README, ZahraRest/README): позиції вже у світі кімнати (підлога 384).
OPEN_BACKDROP = "res://SampleProject/Scenes/Backgrounds/desert_backdrop_open.tscn"
# Обрис міста ринку (City.tscn CityFar): рядки 48… арту, розмиття середнього плану.
CITY_FAR = {"tile": 576, "region": (0, 48, 576, 276), "material": "res://SampleProject/Resources/Materials/depth_blur_mid.tres",
            "shared": True}
PAINTED = {
    "MountainPath": road("MountainPath"), "ScreeSlide": road("ScreeSlide"), "StreamGorge": road("StreamGorge"),
    "RockLedges": road("RockLedges"), "CaveUnderBridge": cave(),
    "MesaTop": [("backdrop", {"Plan3": "visible = false", "Plan1": "visible = false"}),
                ("Far", "MesaTop/gen_far.png", (0.2, 1), (0, -3), {"tile": 576}),
                ("Buttes", "MesaTop/gen_buttes.png", (0.5, 1), (0, 132), {"tile": 576}),
                ("Lookout", "MesaTop/gen_lookout.png", (0.9, 1), (588, 171), {}),
                # Рядки 0–1 смуги — рвана кромка (36–71 % непрозорих): лінія ходу — рядок 2 (verify_map_geometry правило 6).
                ("Ground", "MesaClimb/gen_floor.png", (1, 1), (0, 381), {"tile": 876, "region": (0, 0, 1152, 44)}),
                ("OccluderRock1", "Canyon/gen_rock.png", "front", (1100, 520), {"scale": 2.2, "centered": True})],
    "ZahraRest": [("backdrop", {"Plan3": "scroll_offset = Vector2(172.8, 0)", "Plan1": "scroll_offset = Vector2(432, 0)"}),
                  ("Mid", "ZahraRest/gen_mid.png", (0.6, 1), (0, 25.5),
                   {"tile": 507, "repeat": 760.5, "material": "res://SampleProject/Resources/Materials/depth_blur_near.tres"}),
                  ("Camp", "ZahraRest/gen_camp.png", (0.85, 1), (183, 189), {}),
                  ("Palm", "ZahraRest/gen_palm.png", (0.9, 1), (930, 43.5), {}),
                  ("Well", "ZahraRest/gen_well.png", "room", (828, 219), {"z": -2}),
                  ("Ground", "ZahraRest/gen_ground.png", (1, 1), (0, 384), {"tile": 576, "region": (0, 0, 1152, 67)}),
                  # README ставить y 219 — ступня 444, у кадрі; заслін D750 має ступню нижче кадру (verify_room_entrances п. 4).
                  ("OccluderReeds", "ZahraRest/gen_front.png", "front", (1684.5, 275), {})],
    # Бічні кімнати Лабораторії (M6d-1, README тек AlchemistCorridor, AlchemistStore, MalikStash, CollapsedDrain).
    # Граф v3 (D863, D865) переставив їхні двері: двері коридору на верхній поверх — на сході (намальований
    # прохід зі сходами), двері комори — на заході; у коморі вихід — на сході; у дренажі люк камер на 150, грати
    # нижнього поверху на 3000. Двері-арти стоять на своїх дверях: x README зсунуто на нові місця дверей.
    "AlchemistCorridor": [("Wall", AC + "gen_wall.png", (0.85, 1), (0, 0), {"tile": 576}),
                          ("Vessel", AC + "gen_vessel.png", (0.95, 1), (640.5, 231), {}),
                          ("Cages", AC + "gen_cages.png", (0.95, 1), (1729.5, 267), {}),
                          ("Stairs", AC + "gen_stairs.png", "room", (2450 - 55.5, 196.5), {"z": -2}),
                          ("Table", AC + "gen_desk.png", "room", (1195.5, 238.5), {"z": -3}),
                          ("StoreDoorArt", AC + "gen_door.png", "room", (150 - 69.5, 171), {"z": -2}),
                          ("floor", "Lab/gen_slab.png"),
                          ("OccluderBeam1", AC + "gen_front.png", "front", (966, -12), {}),
                          ("OccluderBeam2", AC + "gen_front.png", "front", (1824, -12), {})],
    "AlchemistStore": [("Wall", "AlchemistStore/gen_wall.png", (0.85, 1), (0, 0), {"tile": 472}),
                       ("Barrels", "AlchemistStore/gen_barrels.png", (0.95, 1), (475.5, 328.5), {}),
                       ("Vessel", "AlchemistStore/gen_parts.png", (0.95, 1), (1212, 291), {}),
                       ("DoorArt", AC + "gen_door.png", "room", (1550 - 69, 171), {"z": -2}),
                       ("floor", "Lab/gen_slab.png"),
                       ("OccluderBeam", AC + "gen_front.png", "front", (888, -12), {})],
    # README ставить стовпи (340 арту) на y −66 — ступня 444, у кадрі (verify_room_entrances п. 4): на −10 верх над
    # кадром (−6), ступня 500 — під ним (480).
    # Вузька плитка (492 світу): 6 повторів не доходять до східного краю (видно порожнечу біля шахти), 12 — доходять.
    "MalikStash": [("Wall", "MalikStash/gen_wall.png", (0.85, 1), (0, 0), {"tile": 328, "times": 12}),
                   ("Hoard", "MalikStash/gen_hoard.png", (0.95, 1), (202.5, 300), {}),
                   ("Lamp", "MalikStash/gen_lamp.png", (0.95, 1), (358.5, 330), {}),
                   ("Shaft", "MalikStash/gen_slab.png", "room", (1345.5, 0), {"z": -2}),
                   ("floor", "Cellar/gen_floor.png"),
                   ("OccluderPost", "MalikStash/gen_post.png", "front", (883.5, PILLAR_Y), {})],
    "CollapsedDrain": [("Far", "CollapsedDrain/gen_far.png", (0.45, 1), (0, 0), {"tile": 576}),
                       ("Mid", "CollapsedDrain/gen_mid.png", (0.75, 1), (0, 3), {"tile": 576}),
                       ("Pipe", "CollapsedDrain/gen_pipe.png", (0.9, 1), (3444, 222), {}),
                       ("Collapse1", "CollapsedDrain/gen_collapse.png", "room", (1999.5, 243), {"z": -3}),
                       ("Collapse2", "CollapsedDrain/gen_collapse.png", "room", (4594.5, 243), {"z": -3, "flip": True}),
                       ("Hatch", "CollapsedDrain/gen_hatch.png", "room", (150 - 64.5, 0), {"z": -2}),
                       ("Grate", "CollapsedDrain/gen_grate.png", "room", (3000 - 69.5, 0), {"z": -2}),
                       ("floor", "Cellar/gen_floor.png"),
                       ("OccluderPier1", "Aqueduct/gen_front.png", "front", (1794, PILLAR_Y), {}),
                       ("OccluderPier2", "Aqueduct/gen_front.png", "front", (3939, PILLAR_Y), {}),
                       ("OccluderPier3", "Aqueduct/gen_front.png", "front", (6180, PILLAR_Y), {})],
    # ── wire-backdrops-2: решта каньйону (README кожної теки; позиції — світ кімнати, підлога 384, камера x 0) ──
    # Дорога пустелею: спільні плани продовжують Зарин привал (scroll_offset Plan3 і зсув дюн — −f × відстань до дюн).
    "Dunes": [("backdrop", {"Plan3": "scroll_offset = Vector2(518.4, 0)"}),
              ("Dunes", "Dunes/gen_dunes.png", (0.5, 1), (0, 105), {"tile": 576}),
              ("Colossus", "Dunes/gen_colossus.png", (0.6, 1), (991.5, 132), {}),
              ("Near", "Dunes/gen_near.png", (0.8, 1), (0, 225), {"tile": 576}),
              ("Slope", "Dunes/gen_slope.png", (0.85, 1), (1498.5, 45), {}),
              ("Stake", "Dunes/gen_stake.png", (0.9, 1), (603, 216), {}),
              # Стежка до табору — намальований прохід (Dunes/README): CampDoor стоїть на ній (Q119).
              ("CampTrail", "Dunes/gen_trailhead.png", "room", (2619, 219), {"z": -2}),
              ("Ground", "Dunes/gen_ground.png", (1, 1), (0, 384), {"tile": 576, "region": (0, 0, 2304, 64)}),
              ("OccluderThorn1", "Dunes/gen_front.png", "front", (1131, 279), {}),
              ("OccluderThorn2", "Dunes/gen_front.png", "front", (2554.5, 279), {})],
    "Chasm": [("backdrop", {"Plan3": "scroll_offset = Vector2(345.6, 0)"}),
              ("City", "Chasm/gen_city.png", (0.4, 1), (433.5, 69), {}),
              ("Dunes", "Dunes/gen_dunes.png", (0.5, 1), (0, 105), {"tile": 576}),
              ("Near", "Dunes/gen_near.png", (0.8, 1), (691.2, 225), {"tile": 576}),
              ("Winch", "Chasm/gen_winch.png", "room", (714, 243), {"z": -2}),
              # Обидва краї й провалля між ними — одна смуга (без лінії підлоги над проваллям).
              ("Chasm", "Chasm/gen_ground.png", (1, 1), (0, 384), {}),
              ("OccluderSpur", "Chasm/gen_front.png", "front", (315, 393), {})],
    "GateApproach": [("backdrop", {"Plan3": "scroll_offset = Vector2(86.4, 0)"}),
                     ("Dunes", "Dunes/gen_dunes.png", (0.5, 1), (432, 105), {"tile": 576}),
                     ("City", "GateApproach/gen_city.png", (0.55, 1), (805.5, 57), {}),
                     ("Ruins", "GateApproach/gen_ruins.png", (0.75, 1), (325.5, 121.5), {}),
                     ("Near", "Dunes/gen_near.png", (0.8, 1), (0, 225), {"tile": 576}),
                     ("WellHouse", "GateApproach/gen_pump.png", "room", (1102.5, 70.5), {"z": -2}),
                     # Корпус важеля з ланцюгом від лебідки провалля — перед BridgeLever у дереві.
                     ("LeverHousing", "GateApproach/gen_lever.png", "room", (-4.5, 351), {"z": -2}),
                     ("Ground", "GateApproach/gen_ground.png", (1, 1), (0, 384), {"tile": 576, "region": (0, 0, 1152, 64)}),
                     ("OccluderPillar", "GateApproach/gen_front.png", "front", (835.5, 174), {})],
    # Дно каньйону: мертва скеля з тріщиною схованки на заході, провал у печери ящерів, гирло печери на сході.
    "CanyonFloor": [("Far", "CanyonFloor/gen_far.png", (0.45, 1), (0, 0), {"tile": 576}),
                    ("Mid", "CanyonFloor/gen_mid.png", (0.75, 1), (0, 204), {"tile": 576}),
                    ("Cart", "CanyonFloor/gen_cart.png", (0.9, 1), (1314, 301.5), {}),
                    ("Cliff", "CanyonFloor/gen_cliff.png", "room", (0, 0), {"z": -2}),
                    ("Mouth", "CanyonFloor/gen_mouth.png", "room", (2592, 0), {"z": -2}),
                    ("Floor", "CanyonFloor/gen_ground.png", (1, 1), (0, 384), {}),
                    ("OccluderRock1", MP + "gen_front.png", "front", (1281, 228), {}),
                    ("OccluderRock2", MP + "gen_front.png", "front", (2646, 228), {"flip": True})],
    # Під землею: один екран (русло, вихід з печери, схованка) — камера стоїть; руїни й акведук — 5 і 4 клітинки.
    "DryRiverbed": [("Far", "DryRiverbed/gen_far.png", (0.45, 1), (0, 0), {}),
                    ("Banks", "DryRiverbed/gen_banks.png", (0.75, 1), (0, 237), {}),
                    ("Boat", "DryRiverbed/gen_boat.png", (0.85, 1), (162, 307.5), {}),
                    ("Riverbed", "DryRiverbed/gen_ground.png", (1, 1), (0, 384), {}),
                    ("OccluderBoulders", "DryRiverbed/gen_front.png", "front", (-97.5, 375), {})],
    "CaveExit": [("Far", "CaveExit/gen_far.png", (1, 1), (0, 0), {"under": False}),
                 ("Wall", "CaveExit/gen_wall.png", (1, 1), (0, 0), {"under": False}),
                 ("Floor", "LizardCave/gen_floor.png", (1, 1), (0, 384), {"tile": 576, "region": (0, 0, 576, 49)}),
                 ("Rubble", "CaveExit/gen_rubble.png", "room", (87, 348), {"z": -2}),
                 ("OccluderStalactites", "BridgeCave/gen_front.png", "front", (496.5, 0), {})],
    "SmugglersStash": [("Far", "SmugglersStash/gen_wall.png", (1, 1), (0, 0), {"under": False}),  # з піщаною підлогою
                       ("Goods", "SmugglersStash/gen_goods.png", "room", (405, 267), {"z": -2}),
                       # README ставить x 496.5 — посеред кадру, а камера тут завжди на межі кімнати: заслін ×1.3
                       # лише краєм кадру (B177, verify_room_entrances _check_limits) — у правому куті над кілками.
                       ("OccluderStalactites", "BridgeCave/gen_front.png", "front", (775, 0), {})],
    "OldRuins": [("Far", "OldRuins/gen_far.png", (0.45, 1), (0, 0), {"tile": 576}),
                 ("Arcade", "OldRuins/gen_arcade.png", (0.75, 1), (0, 24), {"tile": 576}),
                 ("Statue", "OldRuins/gen_statue.png", (0.85, 1), (1326, 183), {}),
                 ("Relief", "OldRuins/gen_relief.png", (0.9, 1), (1867.5, 192), {}),
                 # Шахта криниці — перед стелею: її верх ховає стеля.
                 ("Well", "OldRuins/gen_well.png", "room", (72, -6), {"z": -2}),
                 ("Ceiling", "OldRuins/gen_ceiling.png", "room", (0, 0), {"z": -2, "region": (0, 0, 2880, 110), "repeat": True}),
                 ("Arch", "OldRuins/gen_arch.png", "room", (4095, 171), {"z": -2}),
                 ("Ground", "OldRuins/gen_floor.png", (1, 1), (0, 384), {"tile": 576, "region": (0, 0, 2880, 64)}),
                 ("OccluderColumn1", "OldRuins/gen_front.png", "front", (1213.5, -21), {}),
                 ("OccluderColumn2", "OldRuins/gen_front.png", "front", (4138.5, -21), {})],
    "Aqueduct": [("Far", "Aqueduct/gen_far.png", (0.45, 1), (0, 0), {"tile": 576}),
                 ("Piers", "Aqueduct/gen_arcade.png", (0.75, 1), (0, 36), {"tile": 576}),
                 ("Wheel", "Aqueduct/gen_wheel.png", (0.85, 1), (1302, 207), {}),
                 ("Spout", "Aqueduct/gen_spout.png", (0.9, 1), (2085, 195), {}),
                 ("Rubble", "Aqueduct/gen_rubble.png", "room", (3348, 0), {"z": -2}),
                 ("Ceiling", "Aqueduct/gen_ceiling.png", "room", (0, 0), {"z": -2}),  # з проломом під руслом (567…809)
                 ("RuinsArch", "OldRuins/gen_arch.png", "room", (-99, 171), {"z": -2, "flip": True}),
                 ("Stair", "Aqueduct/gen_stair.png", "room", (2833.5, 198), {"z": -2}),
                 ("CellarArch", "Aqueduct/gen_cellar.png", "room", (3156, 142.5), {"z": -2}),
                 # Ґрата льоху — доки важіль у льоху не поставив прапорець брами aqueduct_cellar (FlagGrate.gd).
                 ("CellarGrate", "Aqueduct/gen_grate.png", "room", (3156, 142.5), {"z": -2, "flag": "aqueduct_cellar_open"}),
                 ("Ground", "Aqueduct/gen_floor.png", (1, 1), (0, 384), {"tile": 576, "region": (0, 0, 2304, 64)}),
                 ("OccluderPier1", "Aqueduct/gen_front.png", "front", (2085, -21), {}),
                 ("OccluderPier2", "Aqueduct/gen_front.png", "front", (3060, -21), {})],
    # ── wire-backdrops-3: місто (README тек M6c-1…3; позиції — світ кімнати, підлога 384, камера x 0) ──
    # Вулиця продовжує ринок: спільні плани зсунуті на −f × відстань від ринку (scroll_offset; без поправки кадру).
    "CraftQuarter": [("backdrop", {"Plan3": "scroll_offset = Vector2(86.4, 0)"}),
                     ("Far", "City/gen_far.png", (0.4, 1), (691.2, 72), CITY_FAR),
                     ("Mid", "CraftQuarter/gen_mid.png", (0.5, 1), (0, 63), {"tile": 576}),
                     ("Potter", "CraftQuarter/gen_potter.png", (0.9, 1), (354, 124.5), {}),
                     ("Weaver", "CraftQuarter/gen_weaver.png", (0.9, 1), (1053, 69), {}),
                     ("Copper", "CraftQuarter/gen_copper.png", (0.9, 1), (1572, 141), {}),
                     # Кузня й каплиця з ринку (D773): за смугою бруківки (z −10), як плани Back.
                     # Одна поверхівка за картою D814 (prop-sizes, ×1.05 на порозі): ринкові (1019.5, 220.25) − 121, як решта кузні.
                     ("Forge", "City/gen_forge.png", "room", (898.5, 220.25), {"z": -10, "scale": 1.05}),
                     ("Chapel", "City/gen_chapel.png", "room", (2235, 136), {"z": -10}),
                     # Ковадло коваля, як на ринку (offset −44 арту = −66 світу), центр — на x коваля.
                     ("Anvil", "res://SampleProject/Assets/Characters/NPCs/blacksmith/anvil.png", "room", (979, 330), {"centered": True}),
                     ("Floor1", "Terrain/City_Terrain.png", (1, 1), (0, 384), {"region": (0, 256, 1728, 43), "repeat": True}),
                     ("Pole1", "CraftQuarter/gen_front.png", "front", (921, 36), {}),
                     ("Pole2", "CraftQuarter/gen_front.png", "front", (2013, 36), {"flip": True})],
    "PalaceSquare": [("backdrop", {"Plan3": "scroll_offset = Vector2(172.8, 0)"}),
                     ("Far", "City/gen_far.png", (0.4, 1), (518.4, 72), CITY_FAR),
                     ("Mid", "PalaceSquare/gen_mid.png", (0.6, 1), (0, 79.5), {"tile": 576}),
                     ("Fountain", "PalaceSquare/gen_fountain.png", (0.9, 1), (630, 151.5), {}),
                     # Фасад палацу з подвійними дверима (112 арту, центр x 1560) замість арту palace_door.
                     ("Palace", "PalaceSquare/gen_palace.png", "room", (1366.5, -102), {"z": -10}),
                     ("Floor1", "Terrain/City_Terrain.png", (1, 1), (0, 384), {"region": (0, 256, 1152, 43), "repeat": True}),
                     ("OccluderPalm", "res://SampleProject/Scenes/Backgrounds/Decor/palm.tscn", "front", (1017, 520), {"scale": 7.15})],
    "Rooftops": [("backdrop", {"Plan3": "scroll_offset = Vector2(518.4, 0)"}),
                 ("Mid", "Rooftops/gen_mid.png", (0.6, 1), (0, 123), {"tile": 576}),
                 ("Laundry1", "Rooftops/gen_laundry.png", (0.9, 1), (591, 252), {}),
                 ("Laundry2", "Rooftops/gen_laundry.png", (0.9, 1), (1731, 252), {"flip": True}),
                 ("Loft", "Rooftops/gen_loft.png", "room", (1102.5, 0), {"z": -10}),
                 ("Floor1", "Rooftops/gen_roof.png", (1, 1), (0, 384), {"tile": 576, "region": (0, 0, 576, 64)}),
                 ("Rope", "Rooftops/gen_rope.png", "room", (135, 316.5), {"z": -8}),
                 ("Ladder", "Rooftops/gen_ladder.png", "room", (2382, 324), {"z": -8}),
                 ("Chimney1", "Rooftops/gen_front.png", "front", (723, 189), {}),
                 ("Chimney2", "Rooftops/gen_front.png", "front", (2088, 189), {"flip": True})],
    # Кімнати в один екран: стіна — суцільний план ×1 (без низу під ним), двері й речі — спрайти кімнати.
    "PigeonLoft": [("Wall", "PigeonLoft/gen_wall.png", (1, 1), (0, 0), {"under": False}),
                   ("Floor1", "ElderHouse/gen_floor.png", (1, 1), (0, 384), {}),
                   ("Door", "PigeonLoft/gen_door.png", "room", (327, 175.5), {"z": -2}),
                   ("Keeper", "PigeonLoft/gen_keeper.png", "room", (99, 346.5), {"z": -2}),
                   ("Cages", "PigeonLoft/gen_front.png", "front", (-15, -12), {})],
    "TavernAttic": [("Mid", "TavernAttic/gen_wall.png", (0.85, 1), (0, 0), {"tile": 576}),
                    ("Barrels", "TavernAttic/gen_barrels.png", (0.95, 1), (703.5, 336), {}),
                    ("Sacks", "TavernAttic/gen_sacks.png", (0.95, 1), (1206, 285), {}),
                    ("Floor1", "ElderHouse/gen_floor.png", (1, 1), (0, 384), {"tile": 576}),
                    ("Ladder", "Rooftops/gen_ladder.png", "room", (181.5, 324), {"z": -8}),
                    ("Post", "TavernAttic/gen_front.png", "front", (1095, -15), {})],
    "MayorArchive": [("Wall", "MayorArchive/gen_wall.png", (1, 1), (0, 0), {"under": False}),
                     ("Floor1", "Hall/gen_floor.png", (1, 1), (0, 384), {}),
                     ("Door", "MayorArchive/gen_door.png", "room", (129, 175.5), {"z": -2}),
                     ("Map", "MayorArchive/gen_map.png", "room", (412.5, 258), {"z": -2}),
                     ("Lectern", "MayorArchive/gen_lectern.png", "room", (690, 285), {"z": -2}),
                     ("Lamp", "MayorArchive/gen_front.png", "front", (721.5, -12), {})],
    "Cistern": [("Far", "Cistern/gen_far.png", (0.45, 1), (0, 0), {"tile": 576}),
                ("Columns", "Cistern/gen_columns.png", (0.75, 1), (0, 3), {"tile": 576}),
                ("Dragon", "Cistern/gen_dragon.png", (0.85, 1), (843, 87), {}),
                ("Floor1", "Aqueduct/gen_floor.png", (1, 1), (0, 384), {"tile": 576, "region": (0, 0, 576, 64)}),
                ("CellarArch", "Aqueduct/gen_cellar.png", "room", (4.5, 142.5), {"z": -2}),
                # Ґрата — доки важіль цистерни не поставив прапорець брами cistern_cellar (FlagGrate.gd).
                ("CellarGrate", "Aqueduct/gen_grate.png", "room", (4.5, 142.5), {"z": -2, "flag": "cistern_cellar_open"}),
                ("Well", "Cistern/gen_well.png", "room", (1632, 0), {"z": -2}),
                ("EndWall", "Cistern/gen_end.png", "room", (2137.5, 0), {"z": -2}),
                ("Rubble", "Aqueduct/gen_rubble.png", "room", (2454, 0), {"z": -2}),
                # Склепіння — після шахти й торцевої стіни (вони йдуть за ним угору); смуга акведука без пролому.
                ("Ceiling", "Aqueduct/gen_ceiling.png", "room", (0, 0), {"z": -2, "region": (576, 0, 1728, 110)}),
                ("Pier1", "Aqueduct/gen_front.png", "front", (819, -66), {}),
                ("Pier2", "Aqueduct/gen_front.png", "front", (1500, -66), {})],
    "CisternStash": [("Wall", "CisternStash/gen_wall.png", (0.85, 1), (0, 0), {"tile": 576}),
                     ("Jars", "CisternStash/gen_jars.png", (0.95, 1), (607.5, 327), {}),
                     ("Goods", "CisternStash/gen_goods.png", (0.95, 1), (1404, 297), {}),
                     ("Floor1", "Cellar/gen_floor.png", (1, 1), (0, 384), {}),
                     ("Breach", "CisternStash/gen_hole.png", "room", (81, 171), {"z": -2}),
                     ("Pier", "Aqueduct/gen_front.png", "front", (915, -66), {})],
}
# Розміри арту, px (для повторів і низу кімнати).
PAINTED_SIZE = {
    "DesertOasis/bg4/plan5.png": (576, 324), MP + "gen_barrier.png": (576, 259), MP + "gen_far.png": (576, 324),
    MP + "gen_plume.png": (491, 132), MP + "gen_mid.png": (576, 324), MP + "gen_waymarker.png": (73, 57),
    MP + "gen_ground.png": (576, 49), MP + "gen_front.png": (193, 212),
    "ScreeSlide/gen_mid.png": (576, 640), "ScreeSlide/gen_scree.png": (576, 640),
    "StreamGorge/gen_plume.png": (655, 176), "StreamGorge/gen_mid.png": (1440, 340), "StreamGorge/gen_ground.png": (1728, 80),
    "StreamGorge/gen_front.png": (188, 172),
    "RockLedges/gen_mid.png": (576, 340), "RockLedges/gen_burnt_houses.png": (380, 278),
    "RockLedges/gen_village_wall.png": (384, 432), "RockLedges/gen_ledges_ramp.png": (576, 640),
    "BridgeCave/gen_far.png": (576, 648), "BridgeCave/gen_waymark.png": (58, 56), "BridgeCave/gen_wall.png": (576, 960),
    "BridgeCave/gen_front.png": (245, 91),
    "MesaTop/gen_far.png": (576, 324), "MesaTop/gen_buttes.png": (576, 300), "MesaTop/gen_lookout.png": (83, 144),
    "MesaClimb/gen_floor.png": (876, 44), "Canyon/gen_rock.png": (156, 114),
    "ZahraRest/gen_mid.png": (507, 250), "ZahraRest/gen_camp.png": (175, 136), "ZahraRest/gen_palm.png": (161, 230),
    "ZahraRest/gen_well.png": (97, 112), "ZahraRest/gen_ground.png": (576, 67), "ZahraRest/gen_front.png": (192, 150),
    AC + "gen_wall.png": (576, 324), AC + "gen_vessel.png": (68, 104), AC + "gen_cages.png": (116, 80),
    AC + "gen_stairs.png": (75, 126), AC + "gen_desk.png": (139, 99), AC + "gen_door.png": (92, 143),
    AC + "gen_front.png": (204, 90),
    "AlchemistStore/gen_wall.png": (472, 324), "AlchemistStore/gen_barrels.png": (79, 39), "AlchemistStore/gen_parts.png": (46, 64),
    "MalikStash/gen_wall.png": (328, 324), "MalikStash/gen_hoard.png": (44, 58), "MalikStash/gen_lamp.png": (25, 38),
    "MalikStash/gen_slab.png": (138, 258), "MalikStash/gen_post.png": (152, 340),
    "CollapsedDrain/gen_far.png": (576, 324), "CollapsedDrain/gen_mid.png": (576, 256), "CollapsedDrain/gen_pipe.png": (73, 110),
    "CollapsedDrain/gen_collapse.png": (174, 96), "CollapsedDrain/gen_hatch.png": (84, 258), "CollapsedDrain/gen_grate.png": (92, 258),
    "Aqueduct/gen_front.png": (135, 340),
    "Dunes/gen_colossus.png": (178, 154), "Dunes/gen_dunes.png": (576, 240), "Dunes/gen_front.png": (160, 150),
    "Dunes/gen_ground.png": (576, 64), "Dunes/gen_near.png": (576, 120), "Dunes/gen_slope.png": (614, 236),
    "Dunes/gen_stake.png": (77, 115), "Dunes/gen_trailhead.png": (109, 112),
    "Chasm/gen_city.png": (262, 115), "Chasm/gen_front.png": (181, 150), "Chasm/gen_ground.png": (576, 64),
    "Chasm/gen_winch.png": (105, 96),
    "GateApproach/gen_city.png": (359, 158), "GateApproach/gen_front.png": (242, 220), "GateApproach/gen_ground.png": (576, 64),
    "GateApproach/gen_lever.png": (88, 24), "GateApproach/gen_pump.png": (251, 211), "GateApproach/gen_ruins.png": (346, 135),
    "CanyonFloor/gen_cart.png": (107, 58), "CanyonFloor/gen_cliff.png": (576, 264), "CanyonFloor/gen_far.png": (576, 324),
    "CanyonFloor/gen_ground.png": (2304, 64), "CanyonFloor/gen_mid.png": (576, 200), "CanyonFloor/gen_mouth.png": (576, 264),
    "DryRiverbed/gen_banks.png": (576, 120), "DryRiverbed/gen_boat.png": (84, 54), "DryRiverbed/gen_far.png": (576, 324),
    "DryRiverbed/gen_front.png": (210, 150), "DryRiverbed/gen_ground.png": (576, 64),
    "CaveExit/gen_far.png": (576, 324), "CaveExit/gen_rubble.png": (95, 26), "CaveExit/gen_wall.png": (576, 264),
    "LizardCave/gen_floor.png": (576, 49),
    "SmugglersStash/gen_goods.png": (120, 80), "SmugglersStash/gen_wall.png": (576, 324),
    "OldRuins/gen_arcade.png": (576, 240), "OldRuins/gen_arch.png": (215, 144), "OldRuins/gen_ceiling.png": (576, 110),
    "OldRuins/gen_far.png": (576, 324), "OldRuins/gen_floor.png": (576, 64), "OldRuins/gen_front.png": (128, 340),
    "OldRuins/gen_relief.png": (160, 130), "OldRuins/gen_statue.png": (81, 136), "OldRuins/gen_well.png": (105, 262),
    "Aqueduct/gen_arcade.png": (576, 240), "Aqueduct/gen_ceiling.png": (2304, 110), "Aqueduct/gen_cellar.png": (181, 163),
    "Aqueduct/gen_far.png": (576, 324), "Aqueduct/gen_floor.png": (576, 64), "Aqueduct/gen_front.png": (135, 340),
    "Aqueduct/gen_grate.png": (181, 163), "Aqueduct/gen_rubble.png": (102, 258), "Aqueduct/gen_spout.png": (70, 86),
    "Aqueduct/gen_stair.png": (77, 126), "Aqueduct/gen_wheel.png": (113, 122),
    "City/gen_far.png": (576, 324), "Terrain/City_Terrain.png": (1728, 43),
    "CraftQuarter/gen_mid.png": (576, 220), "CraftQuarter/gen_potter.png": (302, 175), "CraftQuarter/gen_weaver.png": (325, 212),
    "CraftQuarter/gen_copper.png": (208, 164),
    "PalaceSquare/gen_mid.png": (576, 220), "PalaceSquare/gen_fountain.png": (133, 158),
    "Rooftops/gen_mid.png": (576, 180), "Rooftops/gen_laundry.png": (151, 90), "Rooftops/gen_roof.png": (576, 64),
    "PigeonLoft/gen_wall.png": (576, 324), "ElderHouse/gen_floor.png": (576, 64),
    "TavernAttic/gen_wall.png": (576, 324), "TavernAttic/gen_barrels.png": (90, 34), "TavernAttic/gen_sacks.png": (86, 68),
    "MayorArchive/gen_wall.png": (576, 324), "Hall/gen_floor.png": (576, 64),
    "Cistern/gen_far.png": (576, 324), "Cistern/gen_columns.png": (576, 256), "Cistern/gen_dragon.png": (166, 200),
    "CisternStash/gen_wall.png": (576, 324), "CisternStash/gen_jars.png": (144, 40), "CisternStash/gen_goods.png": (83, 60),
    "Cellar/gen_floor.png": (1152, 45),
}


class Scene:
    def __init__(self, name: str, prefix: str = "w"):
        self.name = name
        self.prefix = prefix
        self.ext: list[str] = []
        self.ext_ids: dict[str, str] = {}
        self.subs: list[str] = []
        self.nodes: list[str] = []
        self._n = 0

    def res(self, kind: str, path: str) -> str:
        if path not in self.ext_ids:
            rid = "%s%d" % (self.prefix, len(self.ext) + 1)
            self.ext_ids[path] = rid
            self.ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, rid))
        return 'ExtResource("%s")' % self.ext_ids[path]

    def rect(self, w: float, h: float) -> str:
        self._n += 1
        sid = "RectangleShape2D_w%d" % self._n
        self.subs.append('[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%g, %g)' % (sid, w, h))
        return 'SubResource("%s")' % sid

    def node(self, text: str) -> None:
        self.nodes.append(text.strip("\n"))


# ── Будівельні блоки (спільні для нових і наявних кімнат) ────────────────────────────────────────────────────
def add_door(s: Scene, name: str, x: float, floor: float, art: str | None, target: str, arrival: str, extra: dict,
             parent: str = ".") -> None:
    if art is None:
        # Отвір уже намальований у кімнаті (криниця на ринку): двері стоять на висоті героя над підлогою
        # або в центрі намальованого отвору (extra y — від верху рядка кімнати).
        dx, dy = x, floor - 54 if "y" not in extra else floor - FLOOR + extra["y"]
    else:
        dx, dy = door_pos(art, x, floor)
        s.node('[node name="%sEntrance" parent="%s" instance=%s]\nposition = Vector2(%g, %g)\ntexture = %s' % (
            name, parent, s.res("PackedScene", ENTRANCE), x, floor, s.res("Texture2D", ART[art])))
    body = '[node name="%s" parent="%s" instance=%s]\nposition = Vector2(%g, %g)\ntarget_room = "res://SampleProject/Maps/%s.tscn"\narrival = NodePath("%s")' % (
        name, parent, s.res("PackedScene", ROOM_DOOR), dx, dy, target, arrival)
    if extra.get("gate"):
        body += '\ngate_id = "%s"' % extra["gate"]
    if extra.get("sets_flag"):
        body += '\nsets_flag = "%s"' % extra["sets_flag"]
    if extra.get("cover"):
        body += '\ncover = NodePath("../%s")' % extra["cover"]
    s.node(body)


def add_lever(s: Scene, name: str, x: float, floor: float, flag: str) -> None:
    s.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\nsets_flag = "%s"' % (
        name, s.res("PackedScene", LEVER), x, floor, flag))


def add_pickup(s: Scene, name: str, x: float, floor: float, item: str, y: float | None = None) -> None:
    """y — висота підбирання, коли воно лежить на намальованому (стіл), а не на підлозі."""
    s.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\nitem_id = "%s"' % (
        name, s.res("PackedScene", PICKUP), x, floor - 32 if y is None else y, item))


class Room(Scene):
    def __init__(self, name: str, spec: dict):
        super().__init__(name)
        self.spec = spec
        self.x0, self.y0, self.cw, self.ch = spec["cells"]
        self.w = self.cw * CELL_W
        self.h = self.ch * CELL_H
        self.kit = KITS[spec["kit"]]
        self.solid: set[tuple[int, int]] = set()
        self.has_front = False

    def floor_y(self, row: int) -> int:
        return row * CELL_H + FLOOR

    # Підлога й стіни — схований шар тайлів; видно — смуги підлоги.
    def build_ground(self) -> list[tuple[int, float, float]]:
        """Тверді тайли й відрізки видимої підлоги [(рядок, x0, x1)]."""
        holes = self.spec.get("holes", [])
        slope = self.spec.get("slope")
        runs: list[tuple[int, float, float]] = []
        for row in range(self.ch):
            cuts = sorted((a, b) for r, a, b in holes if r == row)
            assert all(a % TILE == 0 and b % TILE == 0 for a, b in cuts), "%s: holes on the tile grid" % self.name
            if slope:
                # Схил: тайли лише на майданчиках біля проходів, решта — полігон колізії (Slope).
                top_land = (0, 96) if slope == "down" else (self.w - 96, self.w)
                low_land = (self.w - 96, self.w) if slope == "down" else (0, 96)
                spans = [top_land] if row == 0 else [low_land]
            else:
                spans, x = [], 0
                for a, b in cuts:
                    spans.append((x, a))
                    x = b
                spans.append((x, self.w))
            for a, b in spans:
                if b <= a:
                    continue
                runs.append((row, a, b))
                bottom = ROWS * (row + 1) if not slope or row == self.ch - 1 else ROWS * self.ch
                for cx in range(a // TILE, -(-b // TILE)):
                    for cy in range(row * ROWS + FLOOR_ROW, bottom):
                        self.solid.add((cx, cy))
        if self.spec.get("walls_in"):
            # Намальовані бічні стіни (печера під мостом, ~39 px): крайні стовпці тайлів — уся висота кімнати.
            for cy in range(ROWS * self.ch):
                self.solid.update({(0, cy), (self.w // TILE - 1, cy)})
        # Стіни за межами кімнати там, де немає проходу.
        opened = {(r, side) for r, side in self.spec.get("open", [])}
        for row in range(self.ch):
            for side, cx in (("L", -1), ("R", self.w // TILE)):
                if (row, side) in opened:
                    for cy in range(row * ROWS + FLOOR_ROW, ROWS * (row + 1)):
                        self.solid.add((cx, cy))
                    continue
                for cy in range(row * ROWS, ROWS * (row + 1)):
                    self.solid.add((cx, cy))
        return runs

    def tilemap(self) -> None:
        data = bytearray(b"\x00\x00")
        for x, y in sorted(self.solid, key=lambda c: (c[1], c[0])):
            data += struct.pack("<hhHHHH", x, y, 1, 8, 7, 0)
        tiles = self.res("TileSet", "res://SampleProject/Resources/DesertTileset.tres")
        self.node('[node name="TileMap" type="Node2D" parent="."]')
        self.node('[node name="Foreground" type="TileMapLayer" parent="TileMap"]\nvisible = false\n'
                  'tile_map_data = PackedByteArray("%s")\ntile_set = %s' % (base64.b64encode(bytes(data)).decode(), tiles))

    def backdrop(self) -> None:
        self.node('[node name="Back" type="Node2D" parent="."]\nz_index = -10')
        if self.kit.get("sky"):
            # Далекий план має прозоре небо: тло неба на всю кімнату.
            self.node('[node name="Sky" type="Polygon2D" parent="Back"]\ncolor = %s\npolygon = PackedVector2Array(%g, %g, %g, %g, %g, %g, %g, %g)'
                      % (self.kit["sky"], -CELL_W, -CELL_H, self.w + CELL_W, -CELL_H, self.w + CELL_W, self.h, -CELL_W, self.h))
        for plane in ("far", "mid"):
            if self.kit[plane] is None:
                continue
            tex_path, scroll = self.kit[plane]
            tw, th = TEX_SIZE[tex_path]
            rw = tw * 1.5
            label = plane.capitalize()
            self.node('[node name="%s" type="Parallax2D" parent="Back"]\nscroll_scale = Vector2(%g, 1)\n'
                      'repeat_size = Vector2(%g, 0)\nrepeat_times = %d' % (label, scroll, rw, int(self.w / rw) + 2))
            tex = self.res("Texture2D", BG + tex_path)
            for row in range(self.ch):
                self.node('[node name="Sprite%d" type="Sprite2D" parent="Back/%s"]\ntexture_filter = 1\n'
                          'position = Vector2(0, %g)\nscale = Vector2(1.5, 1.5)\ntexture = %s\ncentered = false'
                          % (row + 1, label, row * CELL_H - 3, tex))

    def ground_art(self, runs: list[tuple[int, float, float]], tex_path: str | None = None, node: bool = True) -> None:
        """Смуга підлоги на кожному відрізку (верх тайлів намальований, verify_map_geometry правило 6) і темна земля під нею."""
        tex_path, region_y = (tex_path, 0) if tex_path else self.kit["floor"]
        tw, th = TEX_SIZE[tex_path]
        tex = self.res("Texture2D", BG + tex_path)
        if node:
            self.node('[node name="Ground" type="Node2D" parent="."]\nz_index = -9')
        for i, (row, a, b) in enumerate(runs, 1):
            top = self.floor_y(row)
            bottom = (row + 1) * CELL_H if not self.spec.get("slope") or row == self.ch - 1 else self.h
            self.node('[node name="Fill%d" type="Polygon2D" parent="Ground"]\ncolor = %s\n'
                      'polygon = PackedVector2Array(%g, %g, %g, %g, %g, %g, %g, %g)'
                      % (i, self.kit["fill"], a, top + 24, b, top + 24, b, bottom, a, bottom))
            self.node('[node name="Floor%d" type="Sprite2D" parent="Ground"]\ntexture_filter = 1\ntexture_repeat = 2\n'
                      'position = Vector2(%g, %g)\nscale = Vector2(1.5, 1.5)\ntexture = %s\ncentered = false\n'
                      'region_enabled = true\nregion_rect = Rect2(0, %d, %g, %d)'
                      % (i, a, top, tex, region_y, (b - a) / 1.5, th))

    def painted(self, planes: list) -> None:
        """Плани з README теки арту замість тимчасового комплекту (див. PAINTED)."""
        for e in planes:
            if e[0] == "backdrop":
                self.node('[node name="Backdrop" parent="." instance=%s]\nposition = Vector2(0, -3)' % self.res("PackedScene", OPEN_BACKDROP))
                for child, prop in e[1].items():
                    self.node('[node name="%s" parent="Backdrop" index="%d"]\n%s' % (child, (3 if child == "Plan3" else 4), prop))
        self.node('[node name="Back" type="Node2D" parent="."]\nz_index = -10')
        if self.kit["interior"]:
            # Під печерою — темна порода комплекту: крізь провал униз видно її, а не порожнечу.
            self.node('[node name="Backstop" type="Polygon2D" parent="Back"]\ncolor = %s\npolygon = PackedVector2Array(0, 0, %g, 0, %g, %g, 0, %g)'
                      % (self.kit["fill"], self.w, self.w, self.h + CELL_H, self.h + CELL_H))
        grounds, fronts, props = [], [], []
        for e in planes:
            if e[0] in ("backdrop", "floor"):
                continue
            if e == "clouds":
                self.node('[node name="DriftingClouds" parent="Back" instance=%s]'
                          % self.res("PackedScene", "res://SampleProject/Scenes/Backgrounds/drifting_clouds.tscn"))
                continue
            name, tex, f, pos, ex = e
            if f == "front":
                fronts.append(e)
                continue
            if f == "room":
                props.append(e)
                continue
            if f == (1, 1):
                grounds.append(e)
                continue
            tw, th = PAINTED_SIZE[tex]
            body = '[node name="%s" type="Parallax2D" parent="Back"]\nscroll_scale = Vector2(%g, %g)' % (name, f[0], f[1])
            if not ex.get("shared"):
                # Спільний з ринком план (shared) стоїть, як у ринку, на scroll_offset без поправки кадру.
                pos = self._fix(pos, f)
            x = pos[0]
            if "tile" in ex:
                rw = ex.get("repeat", ex["tile"] * 1.5)
                x = x % rw - rw
                body += '\nrepeat_size = Vector2(%g, 0)\nrepeat_times = %d' % (rw, ex.get("times", int(self.w / rw) + 3))
            self.node(body)
            self.node(self._sprite("Sprite", "Back/" + name, tex, (x, pos[1]), ex))
        self.node('[node name="Ground" type="Node2D" parent="."]\nz_index = -9')
        for name, tex, f, pos, ex in grounds:
            tw, th = PAINTED_SIZE[tex]
            if "tile" in ex:
                # Плитка ×1: одна смуга на всю кімнату, фаза — як у світі README.
                rx, ry, _, rh = ex.get("region", (0, 0, 0, th))
                region = ((-pos[0] / 1.5) % ex["tile"] + rx, ry, self.w / 1.5, rh)
                self.node(self._sprite(name, "Ground", tex, (0, pos[1]), {"region": region, "repeat": True}))
                x0, w_art, bottom = 0, self.w / 1.5, pos[1] + rh * 1.5
            else:
                self.node(self._sprite(name, "Ground", tex, pos, ex))
                region = ex.get("region", (0, 0, tw, th))
                x0, w_art, bottom = pos[0], region[2], pos[1] + region[3] * 1.5
            if bottom < self.h and ex.get("under", True):
                # Низ кімнати під артом: його ж нижній рядок, розтягнутий донизу.
                self.node(self._sprite(name + "Under", "Ground", tex, (x0, bottom),
                                       {"region": (region[0], region[1] + region[3] - 1, w_art, 1), "repeat": "tile" in ex,
                                        "scale_y": (self.h - bottom) + 1}))
        for name, tex, f, pos, ex in props:
            self.node(self._sprite(name, ".", tex, pos, ex))
        if fronts:
            self.node('[node name="FrontDark" parent="." instance=%s]' % self.res("PackedScene", "res://SampleProject/Scenes/Backgrounds/foreground_dark.tscn"))
            self.has_front = True
            for name, tex, f, pos, ex in fronts:
                pos = self._fix(pos, (1.3, 1))
                if tex.endswith(".tscn"):
                    # Заслін-сцена (пальма ринку, Decor/palm.tscn), не спрайт.
                    self.node('[node name="%s" parent="FrontDark" instance=%s]\nposition = Vector2(%g, %g)\nscale = Vector2(%g, %g)'
                              % (name, self.res("PackedScene", tex), round(pos[0], 1), round(pos[1], 1), ex["scale"], ex["scale"]))
                    continue
                self.node(self._sprite(name, "FrontDark", tex, pos, ex))

    @staticmethod
    def _fix(pos: tuple[float, float], f: tuple[float, float]) -> tuple[float, float]:
        return pos[0] + (1 - f[0]) * VIEW_FIX[0], pos[1] + (1 - f[1]) * VIEW_FIX[1]

    def _sprite(self, name: str, parent: str, tex: str, pos: tuple[float, float], ex: dict) -> str:
        s = ex.get("scale", 1.5)
        body = '[node name="%s" type="Sprite2D" parent="%s"]' % (name, parent)
        if "z" in ex:
            body += '\nz_index = %d' % ex["z"]
        if "material" in ex:
            body += '\nmaterial = %s' % self.res("Material", ex["material"])
        if "flag" in ex:
            body += '\nscript = %s\nflag = "%s"' % (self.res("Script", "res://SampleProject/Scripts/Gameplay/FlagGrate.gd"), ex["flag"])
        body += '\ntexture_filter = 1'
        if ex.get("repeat"):
            body += '\ntexture_repeat = 2'
        body += '\nposition = Vector2(%g, %g)\nscale = Vector2(%g, %g)\ntexture = %s' % (
            round(pos[0], 1), round(pos[1], 1), s, ex.get("scale_y", s), self.res("Texture2D", tex if tex.startswith("res://") else BG + tex))
        if not ex.get("centered"):
            body += '\ncentered = false'
        if ex.get("flip"):
            body += '\nflip_h = true'
        if "region" in ex:
            body += '\nregion_enabled = true\nregion_rect = Rect2(%g, %g, %g, %g)' % tuple(round(v, 1) for v in ex["region"])
        return body

    def slope(self) -> None:
        kind = self.spec.get("slope")
        if not kind:
            return
        hi, lo = FLOOR, CELL_H + FLOOR
        if self.spec.get("slope_line"):
            (ax, ay), (bx, by) = self.spec["slope_line"]
            pts = [(0, ay), (ax, ay), (bx, by), (self.w, by), (self.w, self.h), (0, self.h)]
            line = [(ax, ay), (bx, by)]
        elif kind == "down":
            pts = [(0, hi), (96, hi), (self.w - 96, lo), (self.w, lo), (self.w, self.h), (0, self.h)]
            line = [(96, hi), (self.w - 96, lo)]
        else:
            pts = [(0, lo), (96, lo), (self.w - 96, hi), (self.w, hi), (self.w, self.h), (0, self.h)]
            line = [(96, lo), (self.w - 96, hi)]
        flat = ", ".join("%g, %g" % p for p in pts)
        self.node('[node name="Slope" type="StaticBody2D" parent="."]')
        self.node('[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="Slope"]\npolygon = PackedVector2Array(%s)' % flat)
        if self.name in PAINTED:
            return  # схил намальований у самому арті
        self.node('[node name="Rock" type="Polygon2D" parent="Ground"]\ncolor = %s\npolygon = PackedVector2Array(%s)' % (self.kit["fill"], flat))
        self.node('[node name="Crust" type="Line2D" parent="Ground"]\npoints = PackedVector2Array(%s)\nwidth = 14.0\n'
                  'default_color = Color(0.62, 0.45, 0.3, 1)' % ", ".join("%g, %g" % (x, y + 6) for x, y in line))

    def bridge(self) -> None:
        spec = self.spec.get("bridge")
        if not spec:
            return
        a, b, flag = spec
        script = self.res("Script", "res://SampleProject/Scripts/Gameplay/FlagBridge.gd")
        tex = self.res("Texture2D", BG + "Chasm/gen_bridge.png")
        # Опора — на східному краю провалля: звідти міст опускають (важіль на підході до брами).
        self.node('[node name="Bridge" type="StaticBody2D" parent="."]\nposition = Vector2(%g, %g)\nscript = %s\nflag = "%s"'
                  % (b, FLOOR, script, flag))
        self.node('[node name="CollisionShape2D" type="CollisionShape2D" parent="Bridge"]\nposition = Vector2(%g, 8)\nshape = %s'
                  % (-(b - a) / 2, self.rect(b - a, 16)))
        # Підйомний міст провалля (Chasm/README): рядок 0 — верх настилу, опущений лежить точно на колізії.
        self.node('[node name="Plank" type="Sprite2D" parent="Bridge"]\nz_index = -8\ntexture_filter = 1\nscale = Vector2(1.5, 1.5)\n'
                  'texture = %s\ncentered = false\noffset = Vector2(%g, 0)' % (tex, -(b - a) / 1.5))

    def content(self) -> None:
        sp = self.spec
        row, x = sp["arrival"]
        self.node('[node name="Arrival" type="Marker2D" parent="."]\nposition = Vector2(%g, %g)' % (x, self.floor_y(row) - 24))
        for name, row, x, *art in sp.get("covers", []):
            self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\ncollision_layer = 0'
                      % (name, self.res("PackedScene", WALL), x, self.floor_y(row)))
            if art:
                # Намальована замурована тріщина (CanyonFloor/README): низ на 2 px арту під лінією ходу.
                self.node('[node name="Sprite" parent="%s" index="0"]\nz_index = -1\ntexture = %s\noffset = Vector2(0, -60)'
                          % (name, self.res("Texture2D", BG + art[0])))
            else:
                self.node('[node name="Sprite" parent="%s" index="0"]\nz_index = -1\nscale = Vector2(1, 1)\noffset = Vector2(0, -50)' % name)
        for name, row, x, art, target, arrival, extra in sp.get("doors", []):
            add_door(self, name, x, self.floor_y(row), art, target, arrival, extra)
        for name, row, x, flag, *extra in sp.get("levers", []):
            add_lever(self, name, x, self.floor_y(row), flag)
            if extra:
                # Намальований корпус важеля (LeverHousing) замість трапеції Base; ручка — на осі його колеса.
                self.node('[node name="Base" parent="%s" index="1"]\nvisible = %s' % (name, str(extra[0]["base"]).lower()))
                self.node('[node name="Handle" parent="%s" index="2"]\nposition = Vector2(0, %g)' % (name, extra[0]["handle_y"]))
        for name, row, x, item, y in sp.get("pickups", []):
            add_pickup(self, name, x, self.floor_y(row), item, row * CELL_H + y)
        for name, row, x, contents in sp.get("chests", []):
            self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\ncontents = Dictionary[String, int]({\n%s\n})'
                      % (name, self.res("PackedScene", CHEST), x, self.floor_y(row),
                         ",\n".join('"%s": %d' % kv for kv in contents.items())))
        for name, x in sp.get("guards", []):
            self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)' % (name, self.res("PackedScene", GUARD), x, FLOOR + 12))
            self.node('[node name="Sprite2D" parent="%s" index="0"]\nflip_h = true' % name)
        for name, x, y in sp.get("markers", []):
            self.node('[node name="%s" type="Marker2D" parent="."]\nposition = Vector2(%g, %g)' % (name, x, y))
        for name, scene, x in sp.get("npcs", []):
            # NPC стоїть на лінії ходу, як у ринку (y 396).
            self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)' % (name, self.res("PackedScene", scene), x, FLOOR + 12))
        for name, row, x in sp.get("secrets", []):
            self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)' % (name, self.res("PackedScene", SECRET), x, self.floor_y(row) - 48))
        if sp.get("targets"):
            self.node('[node name="ObjectiveTargets" type="Node2D" parent="."]')
            for target, (row, x) in sp["targets"].items():
                self.node('[node name="%s" type="Marker2D" parent="ObjectiveTargets"]\nposition = Vector2(%g, %g)' % (target, x, self.floor_y(row) - 44))

    def fights(self) -> None:
        for name, row, tx, level, win_xp, enemies in LIVING.get(self.name, {}).get("fights", []):
            floor = self.floor_y(row)
            body = ('[node name="%s" type="Node2D" parent="." node_paths=PackedStringArray("trigger_area")]\nscript = %s\n'
                    'enemy_level = %d\nauto_spawn_on_ready = false\ntrigger_area = NodePath("%sTrigger")\nstate_key = "enemies_%s"\n'
                    'respawns = true' % (name, self.res("Script", SPAWNER), level, name, name[len("Fight_"):].lower()))
            if win_xp:
                body += "\nwin_xp = %d" % win_xp
            self.node(body)
            self.node('[node name="%sTrigger" type="Area2D" parent="%s"]\nposition = Vector2(%g, %g)' % (name, name, tx, floor - 144))
            self.node('[node name="CollisionShape2D" type="CollisionShape2D" parent="%s/%sTrigger"]\nshape = %s'
                      % (name, name, self.rect(64, 480)))
            for i, (kind, x, *h) in enumerate(enemies, 1):
                y = floor - (h[0] if h else FLY_HEIGHT.get(kind, 16))
                self.node('[node name="EnemySpawnPoint%d" type="Node2D" parent="%s"]\nposition = Vector2(%g, %g)\nscript = %s\n'
                          'enemy_type = "%s"\nspawn_id = "%s_EnemySpawnPoint%d"' % (i, name, x, y, self.res("Script", SPAWN_POINT), kind, name, i))

    def life(self) -> None:
        spec = LIVING.get(self.name, {})
        air = spec.get("air", [])
        if air:
            self.node('[node name="Ambience" type="Node2D" parent="."]')
            for i, (kind, row, x, y, *extra) in enumerate(air, 1):
                label = "".join(w.capitalize() for w in kind.replace("atmo_", "").split("_")) + str(i)
                body = '[node name="%s" parent="Ambience" instance=%s]\nposition = Vector2(%g, %g)' % (
                    label, self.res("PackedScene", DECOR % kind), x, row * CELL_H + y)
                for prop, value in (extra[0] if extra else {}).items():
                    body += "\n%s = %s" % (prop, value)
                self.node(body)
        critters = spec.get("critters", [])
        if not critters:
            return
        if any(c[0] == "critter_bat" for c in critters) and not self.has_front:
            self.node('[node name="FrontDark" parent="." instance=%s]' % self.res("PackedScene", "res://SampleProject/Scenes/Backgrounds/foreground_dark.tscn"))
            self.has_front = True
        if any(c[0] != "critter_bat" for c in critters):
            self.node('[node name="Critters" type="Node2D" parent="."]')
        counts: dict[str, int] = {}
        for kind, row, x, *extra in critters:
            ex = extra[0] if extra else {}
            label = {"critter_bird": "Lark", "critter_butterfly": "Butterfly", "critter_butterfly_blue": "Butterfly",
                     "critter_pigeon": "Pigeon", "critter_bat": "Bat", "critter_moth": "Moth", "critter_mouse": "Mouse"}[kind]
            counts[label] = counts.get(label, 0) + 1
            floor = self.floor_y(row)
            if kind == "critter_bat":
                parent, y = "FrontDark", row * CELL_H + 130   # висить під склепінням (як у печері ящурів)
            elif kind.startswith("critter_butterfly"):
                parent, y = "Critters", floor - 20
            else:
                parent, y = "Critters", floor - ex.get("hover", 0)
            body = '[node name="%s%d" parent="%s" instance=%s]\nposition = Vector2(%g, %g)' % (
                label, counts[label], parent, self.res("PackedScene", DECOR % kind), x, y)
            if ex.get("perch_flip"):
                body += "\nperch_flip = true"
            self.node(body)
            if "hole" in ex:
                self.node('[node name="Hole" parent="%s/%s%d" index="0"]\nposition = Vector2(%g, 0)' % (parent, label, counts[label], ex["hole"]))

    def write(self) -> None:
        painted = PAINTED.get(self.name)
        if painted:
            self.painted(painted)
        else:
            self.backdrop()
        runs = self.build_ground()
        floor = [e for e in painted or [] if e[0] == "floor"]
        if not painted:
            self.ground_art(runs)
        elif floor:
            # Намальовані стіни без своєї підлоги: смуга підлоги (за замовчуванням — комплекту) у вже наявному Ground.
            self.ground_art(runs, floor[0][1], node=False)
        self.tilemap()
        self.slope()
        self.bridge()
        self.content()
        self.fights()
        self.life()
        self.node('[node name="RoomInstance" parent="." instance=%s]' % self.res("PackedScene", "res://addons/MetroidvaniaSystem/Nodes/RoomInstance.tscn"))
        music = self.res("AudioStream", "res://SampleProject/Resources/Audio/Music/%s.ogg" % self.kit["music"])
        self.node('[node name="Music" type="AudioStreamPlayer" parent="."]\nprocess_mode = 3\nstream = %s\nautoplay = true\nbus = &"Music"' % music)
        head = '[gd_scene format=3 uid="uid://%s"]' % uid_for(self.name)
        root = '[node name="%s" type="Node2D"]' % self.name
        text = "\n\n".join([head, "\n".join(self.ext)] + self.subs + [root] + self.nodes) + "\n"
        (MAPS / ("%s.tscn" % self.name)).write_text(text, encoding="utf-8")


# ── Наявні кімнати: дописати вузли ────────────────────────────────────────────────────────────────────────────
def patch_existing() -> None:
    rooms = set(EXISTING_DOORS) | set(EXISTING_LEVERS) | set(EXISTING_PICKUPS)
    for room in sorted(rooms):
        path = MAPS / ("%s.tscn" % room)
        text = path.read_text(encoding="utf-8")
        s = Scene(room, "m7_")
        have = set(re.findall(r'^\[node name="([^"]+)" parent="\."', text, re.M))
        # Наявні ext_resource за шляхом — їх і беремо, нові отримують id m7_*.
        for m in re.finditer(r'^\[ext_resource type="[^"]+"(?: uid="[^"]+")? path="([^"]+)" id="([^"]+)"\]', text, re.M):
            s.ext_ids[m.group(1)] = m.group(2)
        for name, x, floor, art, target, arrival, extra in EXISTING_DOORS.get(room, []):
            if name not in have:
                add_door(s, name, x, floor, art, target, arrival, extra)
        for name, x, floor, flag in EXISTING_LEVERS.get(room, []):
            if name not in have:
                add_lever(s, name, x, floor, flag)
        for name, x, floor, item in EXISTING_PICKUPS.get(room, []):
            if name not in have:
                add_pickup(s, name, x, floor, item)
        if not s.nodes:
            continue
        new_ext, nodes = s.ext, s.nodes
        last = list(re.finditer(r'^\[ext_resource [^\n]*\]\n', text, re.M))[-1]
        text = text[:last.end()] + "".join(line + "\n" for line in new_ext) + text[last.end():]
        text = text.rstrip("\n") + "\n\n" + "\n\n".join(nodes) + "\n"
        path.write_text(text, encoding="utf-8")


# ── MapData.txt ───────────────────────────────────────────────────────────────────────────────────────────────
def scene_uid(room: str) -> str:
    head = (MAPS / ("%s.tscn" % room)).read_text(encoding="utf-8").split("\n", 1)[0]
    return re.search(r'uid="uid://([a-z0-9]+)"', head).group(1)


def write_map() -> None:
    path = MAPS / "MapData.txt"
    lines = path.read_text(encoding="utf-8").split("\n")
    uid_room = {scene_uid(r): r for r in PLACE}
    scenes = {f.stem for f in MAPS.glob("*.tscn")}
    placed = set(PLACE) | set(ROOMS) | set(LAB_V3)
    assert scenes == placed, "every room scene is placed: %s" % (scenes ^ placed)
    cells: dict[tuple[int, int, int], list] = {}
    order: list[tuple[int, int, int]] = []
    stubs: list[str] = []
    old: dict[str, list] = {}
    for i, line in enumerate(lines):
        if not line.startswith("["):
            continue
        x, y, z = (int(v) for v in line[1:-1].split(","))
        data = lines[i + 1]
        if ":" not in data:
            stubs += [line, data]
            continue
        uid = data.rsplit(":", 1)[1]
        if uid not in uid_room:
            continue  # нові кімнати (і їхні колишні uid) пишемо наново нижче
        borders = [int(v) for v in data.split("|")[0].split(",")]
        old.setdefault(uid_room[uid], []).append(((x, y, z), borders, uid))
    for room, room_cells in old.items():
        mx, my = min(c[0][0] for c in room_cells), min(c[0][1] for c in room_cells)
        px, py = PLACE[room]
        for (x, y, z), borders, uid in room_cells:
            key = (x - mx + px, y - my + py, z)
            cells[key] = [borders, uid, room]
            order.append(key)
    for room, (rx, ry), side, value in EXISTING_BORDERS:
        mine = [c for c in cells if cells[c][2] == room]
        mx, my = min(c[0] for c in mine), min(c[1] for c in mine)
        z = mine[0][2]
        cells[(mx + rx, my + ry, z)][0][side] = value
    for name, spec in list(ROOMS.items()) + [(n, dict(sp, layer=2)) for n, sp in LAB_V3.items()]:
        x0, y0, w, h = spec["cells"]
        z = spec.get("layer", 0)
        opened = {(r, s) for r, s in spec.get("open", [])}
        uid = scene_uid(name) if name in LAB_V3 else uid_for(name)
        for cy in range(h):
            for cx in range(w):
                b = [-1, -1, -1, -1]
                if cx == w - 1:
                    b[0] = 1 if (cy, "R") in opened else 0
                if cx == 0:
                    b[2] = 1 if (cy, "L") in opened else 0
                if cy == h - 1:
                    b[1] = 1 if _holes_cell(spec, cy, cx) else 0
                if cy == 0:
                    b[3] = 0
                key = (x0 + cx, y0 + cy, z)
                assert key not in cells, "%s overlaps %s at %s" % (name, cells[key][2], key)
                cells[key] = [b, uid, name]
                order.append(key)
    out: list[str] = []
    for key in order:
        b, uid, _ = cells[key]
        out += ["[%d,%d,%d]" % key, "%s|||:%s" % (",".join(str(v) for v in b), uid)]
    path.write_text("\n".join(out + stubs) + "\n", encoding="utf-8")


def _holes_cell(spec: dict, row: int, cx: int) -> list:
    return [1 for r, a, b in spec.get("holes", []) if r == row and a < (cx + 1) * CELL_W and b > cx * CELL_W]


if __name__ == "__main__":
    for room_name, room_spec in ROOMS.items():
        Room(room_name, room_spec).write()
    patch_existing()
    write_map()
    print("%d rooms written, MapData.txt rebuilt" % len(ROOMS))
