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
BG = "res://SampleProject/Assets/Backgrounds/"
ART = {name: BG + "Decor/%s/%s_sheet.png" % (name, name) for name in
       ("door_elder", "cave_mouth", "palisade_gate", "mesa_cleft", "palace_door", "lab_door")}
# Розмір кадру й отвір (RoomEntrance.OPENINGS) кожного арту входу, px кадру.
ART_SIZE = {"door_elder": (52, 76), "cave_mouth": (110, 100), "palisade_gate": (150, 87), "mesa_cleft": (110, 110),
            "palace_door": (100, 104), "lab_door": (72, 88)}
OPENING = {"door_elder": (14, 7, 22, 56), "cave_mouth": (34, 38, 30, 52), "palisade_gate": (69, 26, 20, 56),
           "mesa_cleft": (39, 30, 23, 47), "palace_door": (32, 11, 36, 74), "lab_door": (14, 6, 33, 65)}

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


def door_pos(art: str, x: float, floor: float) -> tuple[float, float]:
    """Центр отвору арту, що стоїть низом посередині на (x, floor): там стоять двері (RoomDoor)."""
    w, h = ART_SIZE[art]
    ox, oy, ow, oh = OPENING[art]
    return x + (ox + ow / 2 - w / 2) * 1.5, floor + (oy + oh / 2 - h) * 1.5


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
                       title=("Scree Slide", "Осипище"), arrival=(0, 60),
                       targets={"village": (1, 820), "canyon_bridge": (0, 40)}),
    "StreamGorge": dict(loc="canyon_of_whispers", kit="path", cells=(7, 2, 3, 1), open=[(0, "L"), (0, "R")],
                        title=("Stream Gorge", "Ущелина струмка"), arrival=(0, 150),
                        targets={"village": (0, 2540), "canyon_bridge": (0, 60)}),
    "RockLedges": dict(loc="canyon_of_whispers", kit="path", cells=(10, 1, 1, 2), open=[(1, "L"), (0, "R")], slope="up",
                       title=("Rock Ledges", "Скельні уступи"), arrival=(1, 60),
                       targets={"village": (0, 820), "canyon_bridge": (1, 40)}),
    "CaveUnderBridge": dict(loc="canyon_of_whispers", kit="cave", cells=(3, 2, 1, 3),
                            holes=[(0, 608, 800), (1, 64, 256), (2, 320, 544)],
                            title=("Cave Under The Bridge", "Печера під мостом"), arrival=(0, 200),
                            targets={"city_gates": (2, 445)}),
    "CaveExit": dict(loc="canyon_of_whispers", kit="cave", cells=(3, 5, 1, 1), open=[(0, "L"), (0, "R")],
                     title=("Cave Exit", "Вихід з печери"), arrival=(0, 432), targets={"city_gates": (0, 820)}),
    "CanyonFloor": dict(loc="canyon_of_whispers", kit="desert", cells=(-1, 5, 4, 1), open=[(0, "R")],
                        holes=[(0, 2912, 3104)],
                        title=("Canyon Floor", "Дно каньйону"), arrival=(0, 2600),
                        doors=[("StashDoor", 0, 300, "cave_mouth", "SmugglersStash", "ExitDoor", {"cover": "Wall_Stash"})],
                        covers=[("Wall_Stash", 0, 300)],
                        targets={"city_gates": (0, 3420)}),
    "SmugglersStash": dict(loc="canyon_of_whispers", kit="cave", cells=(-1, 6, 1, 1),
                           title=("Smugglers' Stash", "Схованка контрабандистів"), arrival=(0, 432),
                           doors=[("ExitDoor", 0, 432, "cave_mouth", "CanyonFloor", "StashDoor", {})],
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
                      doors=[("WellDoor", 0, 900, "cave_mouth", "OldRuins", "WellDoor", {"gate": "ruins_well"})],
                      targets={"city_gates": (0, 1700)}),
    "Dunes": dict(loc="canyon_of_whispers", kit="desert", cells=(12, 5, 4, 1), open=[(0, "L"), (0, "R")],
                  title=("Dunes", "Дюни"), arrival=(0, 200), targets={"city_gates": (0, 3420)}),
    "Chasm": dict(loc="canyon_of_whispers", kit="desert", cells=(16, 5, 1, 1), open=[(0, "L"), (0, "R")],
                  holes=[(0, 160, 704)], bridge=(144, 720, "chasm_bridge_down"),
                  title=("Chasm", "Провалля"), arrival=(0, 80), targets={"city_gates": (0, 820)}),
    "DryRiverbed": dict(loc="canyon_of_whispers", kit="cave", cells=(16, 6, 1, 1), holes=[(0, 576, 800)],
                        title=("Dry Riverbed", "Сухе русло"), arrival=(0, 300), targets={"city_gates": (0, 690)}),
    "Aqueduct": dict(loc="canyon_of_whispers", kit="cellar", cells=(16, 7, 4, 1), open=[(0, "L")],
                     title=("Aqueduct", "Акведук"), arrival=(0, 600),
                     doors=[("ApproachDoor", 0, 2900, "cave_mouth", "GateApproach", "AqueductDoor", {}),
                            ("CellarDoor", 0, 3300, "cave_mouth", "GatehouseCellar", "AqueductDoor",
                             {"gate": "aqueduct_cellar"})],
                     targets={"city_gates": (0, 2900)}),
    "OldRuins": dict(loc="canyon_of_whispers", kit="cellar", cells=(11, 7, 5, 1), open=[(0, "R")],
                     title=("Old Ruins", "Старі руїни"), arrival=(0, 300),
                     doors=[("WellDoor", 0, 160, "cave_mouth", "ZahraRest", "WellDoor", {})]),
    "GateApproach": dict(loc="canyon_of_whispers", kit="desert", cells=(17, 5, 2, 1), open=[(0, "L"), (0, "R")],
                         title=("Gate Approach", "Підхід до брами"), arrival=(0, 900),
                         doors=[("AqueductDoor", 0, 1300, "cave_mouth", "Aqueduct", "ApproachDoor", {})],
                         levers=[("BridgeLever", 0, 110, "chasm_bridge_down")],
                         targets={"city_gates": (0, 1700)}),
    # ── M3: Місто ──
    "CraftQuarter": dict(loc="city", kit="city", cells=(24, 5, 3, 1), open=[(0, "L"), (0, "R")],
                         title=("Craft Quarter", "Ремісничий квартал"), arrival=(0, 200)),
    "PalaceSquare": dict(loc="city", kit="city", cells=(27, 5, 2, 1), open=[(0, "L")],
                         title=("Palace Square", "Площа палацу"), arrival=(0, 200),
                         doors=[("MayorHallDoor", 0, 1560, "palace_door", "MayorHall", "CityDoor", {})],
                         guards=[("GuardLeft", 1500), ("GuardRight", 1620)]),
    "Rooftops": dict(loc="city", kit="city", cells=(19, 4, 3, 1),
                     title=("Rooftops", "Дахи"), arrival=(0, 2400),
                     doors=[("LadderDoor", 0, 2400, "door_elder", "City", "RooftopsDoor", {}),
                            ("SlideDoor", 0, 150, "door_elder", "CityGates", "RooftopsDoor",
                             {"sets_flag": "city_rooftops_slide"}),
                            ("LoftDoor", 0, 1300, "cave_mouth", "PigeonLoft", "ExitDoor", {"cover": "Wall_Loft"})],
                     covers=[("Wall_Loft", 0, 1300)]),
    "PigeonLoft": dict(loc="city", kit="interior", cells=(20, 3, 1, 1),
                       title=("Pigeon Loft", "Голубник"), arrival=(0, 432),
                       doors=[("ExitDoor", 0, 432, "cave_mouth", "Rooftops", "LoftDoor", {})],
                       secrets=[("SecretArea_Loft", 0, 640)]),
    "TavernAttic": dict(loc="city", kit="interior", cells=(23, 4, 2, 1),
                        title=("Tavern Attic", "Горище таверни"), arrival=(0, 200),
                        doors=[("LadderDoor", 0, 200, "door_elder", "City", "TavernAtticDoor", {})]),
    "MayorArchive": dict(loc="city", kit="hall", cells=(29, 4, 1, 1),
                         title=("Mayor's Archive", "Архів мера"), arrival=(0, 200),
                         doors=[("BookshelfDoor", 0, 200, "door_elder", "MayorHall", "ArchiveDoor", {})]),
    "Cistern": dict(loc="city", kit="cellar", cells=(22, 7, 3, 1),
                    title=("Cistern", "Цистерна під ринком"), arrival=(0, 1700),
                    doors=[("WellDoor", 0, 1700, "cave_mouth", "City", "CisternDoor", {}),
                           ("CellarDoor", 0, 140, "cave_mouth", "GatehouseCellar", "CisternDoor",
                            {"gate": "cistern_cellar"}),
                           ("StashDoor", 0, 2300, "cave_mouth", "CisternStash", "ExitDoor", {"cover": "Wall_Stash"})],
                    levers=[("CellarLever", 0, 290, "cistern_cellar_open")],
                    covers=[("Wall_Stash", 0, 2300)]),
    "CisternStash": dict(loc="city", kit="cellar", cells=(24, 8, 2, 1),
                         title=("Cistern Stash", "Схованка в цистерні"), arrival=(0, 200),
                         doors=[("ExitDoor", 0, 200, "cave_mouth", "Cistern", "StashDoor", {})],
                         secrets=[("SecretArea_Stash", 0, 1100)]),
    # ── M4: Лабораторія (шар 2) ──
    "AlchemistCorridor": dict(loc="laboratory", kit="lab", cells=(15, 2, 3, 1), layer=2,
                              title=("Alchemist's Corridor", "Коридор алхіміка"), arrival=(0, 150),
                              doors=[("StairsDoor", 0, 150, "lab_door", "Laboratory", "StairsDoor", {}),
                                     ("StoreDoor", 0, 2450, "lab_door", "AlchemistStore", "ExitDoor",
                                      {"gate": "alchemist_store"})],
                              table=(0, 1300), pickups=[("Pickup_AlchemistKey", 0, 1300, "alchemist_key")]),
    "AlchemistStore": dict(loc="laboratory", kit="lab", cells=(18, 2, 2, 1), layer=2,
                           title=("Alchemist's Storeroom", "Комора алхіміка"), arrival=(0, 150),
                           doors=[("ExitDoor", 0, 150, "lab_door", "AlchemistCorridor", "StoreDoor", {})]),
    "MalikStash": dict(loc="laboratory", kit="lab", cells=(12, 4, 2, 1), layer=2,
                       title=("Malik's Stash", "Схованка Маліка"), arrival=(0, 1450),
                       doors=[("SlabDoor", 0, 1450, "lab_door", "LabCells", "StashDoor", {})],
                       secrets=[("SecretArea_Stash", 0, 700)]),
    "CollapsedDrain": dict(loc="laboratory", kit="cellar", cells=(12, 8, 7, 1), layer=2,
                           title=("Collapsed Drain", "Обвалений дренаж"), arrival=(0, 900),
                           doors=[("HatchDoor", 0, 900, "lab_door", "LabCells", "DrainDoor", {}),
                                  ("GrateDoor", 0, 5750, "lab_door", "Laboratory", "DrainDoor", {})],
                           chests=[("Chest_Drain", 0, 3000, {"potion_lesser": 1, "herb": 2})]),
}

# Двері, важелі й підбирання, що дописуються в наявні кімнати (лише вузли; підлогу не чіпаємо).
#   (вузол, x, підлога, арт, кімната, двері там, дод.)
EXISTING_DOORS = {
    "LizardCave": [("DeepCavesDoor", 150, 416, "cave_mouth", "LizardCaves", "ShrineDoor", {})],
    # Дорога: рівна підлога, клір від трави (verify_ambient_critters), поза кадром заслонів переднього плану (OccluderRock2 при камері на 3458–4128).
    "DesertRoad": [("LizardCavesDoor", 4690, 384, "cave_mouth", "LizardCaves", "RoadDoor", {"gate": "lizard_caves_shortcut"})],
    "MesaClimb": [("MesaTopDoor", 480, 180, "mesa_cleft", "MesaTop", "ClimbDoor", {})],
    "GatehouseCellar": [("AqueductDoor", 300, 416, "cave_mouth", "Aqueduct", "CellarDoor", {"gate": "aqueduct_cellar"}),
                        ("CisternDoor", 1450, 416, "cave_mouth", "Cistern", "CellarDoor", {"gate": "cistern_cellar"})],
    # Ринок: клір від зупинок городян, NPC і реквізиту (verify_city_life).
    "City": [("RooftopsDoor", 880, 384, "door_elder", "Rooftops", "LadderDoor", {}),
             ("TavernAtticDoor", 2450, 384, "door_elder", "TavernAttic", "LadderDoor", {}),
             # Криниця на ринку — сама інтерактивна (ковток води), тож спуск у цистерну — окремий люк у кінці ринку.
             ("CisternDoor", 2540, 384, "door_elder", "Cistern", "WellDoor", {})],
    # Брама: між кущиками трави й далі від жайворонка (verify_ambient_critters).
    "CityGates": [("RooftopsDoor", 638, 384, "door_elder", "Rooftops", "SlideDoor", {"gate": "city_rooftops"})],
    "MayorHall": [("ArchiveDoor", 250, 384, "door_elder", "MayorArchive", "BookshelfDoor", {"gate": "mayor_archive"})],
    "LabCells": [("StashDoor", 1450, 384, "lab_door", "MalikStash", "SlabDoor", {"gate": "malik_stash"}),
                 ("DrainDoor", 900, 384, "lab_door", "CollapsedDrain", "HatchDoor", {})],
    "Laboratory": [("StairsDoor", 330, 384, "lab_door", "AlchemistCorridor", "StairsDoor", {}),
                   ("DrainDoor", 1200, 1344, "lab_door", "CollapsedDrain", "GrateDoor", {})],
}
EXISTING_LEVERS = {"GatehouseCellar": [("AqueductLever", 420, 416, "aqueduct_cellar_open")]}
EXISTING_PICKUPS = {"MayorHall": [("Pickup_MayorKey", 380, 384, "mayor_key")]}

# Наявні кімнати на карті: найменша клітинка (x, y) — там, де їх ставить граф (форма кімнати лишається своя).
PLACE = {
    "Canyon": (0, 1), "DragonMural": (1, 0), "Village": (11, 1), "ElderHouse": (13, -1),
    "LizardCave": (0, 6), "DesertRoad": (4, 5), "BanditCamp": (12, 3), "MesaClimb": (6, 3),
    "CityGates": (19, 5), "GatehouseCellar": (20, 7), "City": (21, 5), "MayorHall": (29, 5),
    "LabCells": (12, 3), "Laboratory": (14, 3), "LabBoss": (16, 5), "LaboratoryOutside": (18, 5),
}
# Межі наявних кімнат, що міняються: (кімната, клітинка відносно її найменшої, сторона R/D/L/U, значення).
EXISTING_BORDERS = [
    ("Canyon", (0, 1), 1, 0),       # спуск з каньйону — кат-сцена в печеру під мостом, не прохід униз на дорогу
    ("DesertRoad", (0, 0), 2, 1),   # з виходу з печери на дорогу
    ("City", (2, 0), 0, 1),         # ринок → ремісничий квартал (двері палацу тепер на площі)
]
SIDES = {"R": 0, "D": 1, "L": 2, "U": 3}


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
        # Отвір уже намальований у кімнаті (криниця на ринку): двері стоять на висоті героя над підлогою.
        dx, dy = x, floor - 54
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


def add_pickup(s: Scene, name: str, x: float, floor: float, item: str) -> None:
    s.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\nitem_id = "%s"' % (
        name, s.res("PackedScene", PICKUP), x, floor - 32, item))


class Room(Scene):
    def __init__(self, name: str, spec: dict):
        super().__init__(name)
        self.spec = spec
        self.x0, self.y0, self.cw, self.ch = spec["cells"]
        self.w = self.cw * CELL_W
        self.h = self.ch * CELL_H
        self.kit = KITS[spec["kit"]]
        self.solid: set[tuple[int, int]] = set()

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

    def ground_art(self, runs: list[tuple[int, float, float]]) -> None:
        """Смуга підлоги на кожному відрізку (верх тайлів намальований, verify_map_geometry правило 6) і темна земля під нею."""
        tex_path, region_y = self.kit["floor"]
        tw, th = TEX_SIZE[tex_path]
        tex = self.res("Texture2D", BG + tex_path)
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

    def slope(self) -> None:
        kind = self.spec.get("slope")
        if not kind:
            return
        hi, lo = FLOOR, CELL_H + FLOOR
        if kind == "down":
            pts = [(0, hi), (96, hi), (self.w - 96, lo), (self.w, lo), (self.w, self.h), (0, self.h)]
            line = [(96, hi), (self.w - 96, lo)]
        else:
            pts = [(0, lo), (96, lo), (self.w - 96, hi), (self.w, hi), (self.w, self.h), (0, self.h)]
            line = [(96, lo), (self.w - 96, hi)]
        flat = ", ".join("%g, %g" % p for p in pts)
        self.node('[node name="Slope" type="StaticBody2D" parent="."]')
        self.node('[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="Slope"]\npolygon = PackedVector2Array(%s)' % flat)
        self.node('[node name="Rock" type="Polygon2D" parent="Ground"]\ncolor = %s\npolygon = PackedVector2Array(%s)' % (self.kit["fill"], flat))
        self.node('[node name="Crust" type="Line2D" parent="Ground"]\npoints = PackedVector2Array(%s)\nwidth = 14.0\n'
                  'default_color = Color(0.62, 0.45, 0.3, 1)' % ", ".join("%g, %g" % (x, y + 6) for x, y in line))

    def bridge(self) -> None:
        spec = self.spec.get("bridge")
        if not spec:
            return
        a, b, flag = spec
        script = self.res("Script", "res://SampleProject/Scripts/Gameplay/FlagBridge.gd")
        tex = self.res("Texture2D", BG + "Canyon/gen_bridge.png")
        # Опора — на східному краю провалля: звідти міст опускають (важіль на підході до брами).
        self.node('[node name="Bridge" type="StaticBody2D" parent="."]\nposition = Vector2(%g, %g)\nscript = %s\nflag = "%s"'
                  % (b, FLOOR, script, flag))
        self.node('[node name="CollisionShape2D" type="CollisionShape2D" parent="Bridge"]\nposition = Vector2(%g, 8)\nshape = %s'
                  % (-(b - a) / 2, self.rect(b - a, 16)))
        self.node('[node name="Plank" type="Sprite2D" parent="Bridge"]\nz_index = -8\ntexture_filter = 1\ntexture = %s\n'
                  'centered = false\noffset = Vector2(%g, -8)\nregion_enabled = true\nregion_rect = Rect2(0, 0, %g, 46)'
                  % (tex, -(b - a), b - a))

    def content(self) -> None:
        sp = self.spec
        row, x = sp["arrival"]
        self.node('[node name="Arrival" type="Marker2D" parent="."]\nposition = Vector2(%g, %g)' % (x, self.floor_y(row) - 24))
        for name, row, x in sp.get("covers", []):
            self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\ncollision_layer = 0'
                      % (name, self.res("PackedScene", WALL), x, self.floor_y(row)))
            self.node('[node name="Sprite" parent="%s" index="0"]\nz_index = -1\nscale = Vector2(1, 1)\noffset = Vector2(0, -50)' % name)
        if "table" in sp:
            row, x = sp["table"]
            self.node('[node name="Table" type="Sprite2D" parent="."]\nz_index = -3\ntexture_filter = 1\nposition = Vector2(%g, %g)\n'
                      'scale = Vector2(1.5, 1.5)\ntexture = %s\noffset = Vector2(0, -36)'
                      % (x, self.floor_y(row), self.res("Texture2D", BG + "Lab/gen_table.png")))
        for name, row, x, art, target, arrival, extra in sp.get("doors", []):
            add_door(self, name, x, self.floor_y(row), art, target, arrival, extra)
        for name, row, x, flag in sp.get("levers", []):
            add_lever(self, name, x, self.floor_y(row), flag)
        for name, row, x, item in sp.get("pickups", []):
            add_pickup(self, name, x, self.floor_y(row), item)
        for name, row, x, contents in sp.get("chests", []):
            self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)\ncontents = Dictionary[String, int]({\n%s\n})'
                      % (name, self.res("PackedScene", CHEST), x, self.floor_y(row),
                         ",\n".join('"%s": %d' % kv for kv in contents.items())))
        for name, x in sp.get("guards", []):
            self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)' % (name, self.res("PackedScene", GUARD), x, FLOOR + 12))
            self.node('[node name="Sprite2D" parent="%s" index="0"]\nflip_h = true' % name)
        for name, row, x in sp.get("secrets", []):
            self.node('[node name="%s" parent="." instance=%s]\nposition = Vector2(%g, %g)' % (name, self.res("PackedScene", SECRET), x, self.floor_y(row) - 48))
        if sp.get("targets"):
            self.node('[node name="ObjectiveTargets" type="Node2D" parent="."]')
            for target, (row, x) in sp["targets"].items():
                self.node('[node name="%s" type="Marker2D" parent="ObjectiveTargets"]\nposition = Vector2(%g, %g)' % (target, x, self.floor_y(row) - 44))

    def write(self) -> None:
        self.backdrop()
        runs = self.build_ground()
        self.ground_art(runs)
        self.tilemap()
        self.slope()
        self.bridge()
        self.content()
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
    assert scenes == set(PLACE) | set(ROOMS), "every room scene is placed: %s" % (scenes ^ (set(PLACE) | set(ROOMS)))
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
    for name, spec in ROOMS.items():
        x0, y0, w, h = spec["cells"]
        z = spec.get("layer", 0)
        opened = {(r, s) for r, s in spec.get("open", [])}
        uid = uid_for(name)
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
