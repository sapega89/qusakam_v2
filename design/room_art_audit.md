---
type: audit
status: active
tags: [map, art, rooms]
---

# Room art audit — passages, doors, ladders, platforms (2026-10-26)

Sapega, 2026-10-26: every passage must be explained by the backdrop (a door, an entrance, a well — not a passage in the
middle of the background); the hero leaves a house, a cave, the camp or the cellar the same way he came in; ladders in
the game's style; platforms part of the interior, not hanging in the air. Rules: [[world_structure_plan]] → «How rooms
must look». Shots: `design/shots/maps/<Room>.png` (whole room) and `design/shots/maps/exits_1..4.png` (each passage as the
player sees it), from `godot --path . --resolution 1920x1080 --script res://SampleProject/UI/capture_maps.gd`.

The door logic is already symmetric: every `RoomDoor` leads back to the door it came from (`arrival`). What is wrong is
the picture: most doors inside rooms stand at x 96 at the left edge where nothing is painted.

## Doors (`room_door.tscn`, invisible; the backdrop must show the opening)

| Room | Door | Backdrop at the door | Verdict | Fix |
|---|---|---|---|---|
| Canyon | LizardCaveDoor | dark cave mouth | ✅ | — |
| Canyon | DragonMuralDoor | middle of a solid boulder | ❌ | a crack / cave opening in the boulder (art) |
| Village | ElderDoor | the house's painted wooden door | ✅ | — |
| DesertRoad | BanditCampDoor | a tent on a mound | ⚠ a tent, while inside is the open camp | the camp's stockade gate (art), the same gate inside |
| DesertRoad | MesaClimbDoor | foot of a ladder by a ruined tower, open sand | ❌ | a path cut into the mesa rock (art) |
| DesertRoad | CampShortcutDoor | open sand by the obelisk | ❌ | the camp's back gate in a palisade (art) |
| CityGates | CellarDoor | dark arch with cobwebs | ✅ | — |
| ElderHouse | ExitDoor (96, 824) | wall by the fireplace, no door | ❌ | a wooden door in the clay wall (art) |
| LizardCave | ExitDoor (96, 376) | a lizard shrine; the lit cave opening is further right | ❌ | move the door to the opening |
| DragonMural | ExitDoor (96, 376) | in front of the mural | ❌ | a tunnel mouth (art) |
| BanditCamp | ExitDoor (96, 376) | open sand | ❌ | the stockade gate from inside (art) |
| BanditCamp | ShortcutDoor (1640, 376) | next to a barrel | ❌ | the back gate from inside (art) |
| MesaClimb | ExitDoor (96, 856) | rocks | ❌ | the path's opening (art) |
| GatehouseCellar | ExitDoor (96, 376) | foot of the stairs up | ⚠ | at the top of the stairs, or a door there |

## Edge passages (MapData borders = 1)

Outdoors the road simply goes on (Canyon → Village → road → gates → city, the oasis), which is right. Inside, the hero
walks through a painted wall:

| Passage | Backdrop | Verdict | Fix |
|---|---|---|---|
| City (10,3) right → MayorHall (11,3) left | a tent and guards / the hall's wall | ❌ | a palace entrance on the street and a doorway in the hall, as a door |
| LabCells (13,3) right ↔ Laboratory (14,3) left | cells / shelves | ❌ | an archway or iron door at both sides |
| Laboratory (15,5) right ↔ LabBoss (16,5) left | shelves / furnace wall | ❌ | an archway at both sides |
| LabBoss (17,5) right → LaboratoryOutside (18,5) left | iron portcullis / oasis | ✅ | — |
| Canyon (0,2) down | a drop | ✅ | — |

## Ladders (3 rooms) and platforms

- Ladders: `Ladder.tscn` tiles a 16×8 procedural strip (`Scripts/Tools/draw_ladder.py`) in DesertRoad (3) and ElderHouse
  (2), Laboratory (1). Redraw in the backdrop style (A14).
- Platforms: one-way ledges are a strip cut out of a texture with nothing under them (MesaClimb 10, DesertRoad 2,
  ElderHouse 1), plus solid ledges in the Canyon's lower cell and the lab rooms (thin bars on the furnace wall in
  LabBoss). Each needs what holds it up (A15).
