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

## How an entrance looks — Tails of Iron (Sapega's reference, 2026-10-26)

![[refs/toi_cave_entrance.png]]

«прохід в печеру — ось дивись, як зроблено в Tails of Iron»: the cave entrance is a dark arch **at the foot of the
stone mass the hero walks on** — he stands on top of that same wall. The opening is cut into the playfield's own
material (the same stones as the ground and the ledge), framed by stone blocks and plants, dark inside; it is part of
the walkable foreground, not a picture in the far backdrop and not a separate object standing on the floor. So an
entrance is a piece of terrain: a rock or masonry block in the room's own material with the opening at its base, its
top flat enough to be ground (a ledge the hero can stand on where the room needs it), its foot on the floor line.

## Cave mood — Tails of Iron (Sapega, 2026-10-26)

«подивись, як зроблена печера: там темніше зверху, якесь листя, передній фон закриває вид, і це красиво» (a ToI cave
screenshot): the top of the frame is darker (the cave ceiling), hanging leaves and roots sit in front of the hero and
partly cover the view, plants grow at the bottom of the frame in the foreground, a lamp and light shafts give the
light. Our enclosed rooms (LizardCave, DragonMural, GatehouseCellar, MesaClimb, BanditCamp, ElderHouse) have no
Parallax2D layer at all, and the others have at most a 1.25 strip. Art: `Decor/hanging_roots` (dry roots and sandstone
stalactites — the caves are in the desert, Sapega: «може бути сиро, а може бути сухо… ліани — така собі ідея»),
`hanging_chain_web` (cellar, lab), `fg_scrub` (dry thorny brush; comfy_decor, sway). In a room: a foreground layer closer than the hero (Parallax2D scroll
above 1, drawn over the hero, darker by modulate), hanging pieces along the top edge, dry scrub along the bottom, never
over a door, an NPC, a chest or the hero's path at head height for long; plus a dark gradient from the top of the
screen in caves and cellars.

Outdoors too (Sapega: «передній план паралаксу був би прикольним, якби він іноді частково закривав огляд»): the
front parallax may **sometimes** cover part of the view — a tall dark palm, rock or ruin wall passing in front every
screen or two (scroll 1.25–1.4, darkened) — but not as a constant band at the hero's feet: the brown strip of fences
and plants that now runs right under the walk line (Village, road) makes the hero look as if he walks under the
ground. The walkable ground itself is redrawn by the orchestrator (`paint_terrain.py`, a surface band with depth).

## Castle corridor — Tails of Iron (Sapega, 2026-10-26: «коридор у замку, і придивись, як там вихід зроблений»)

- **The exit is lit.** A plain wooden door stands in the wall on the floor line, framed by the masonry, and a warm
  shaft of light falls on it from above; the rest of the corridor is dim. The eye finds the way out without a marker.
  → every RoomDoor gets a soft warm light on its entrance (a light shaft or a glow sprite / PointLight2D), stronger
  than the room around it.
- **Foreground pillars.** Wide dark pillars pass in front of the view at intervals (front parallax), and a dark band
  frames the top and the bottom of the frame: the playfield is a lit strip between darkness.
- **The floor** is a strip of stone cobbles with a light top surface the characters stand on, darkness below it.

## City gate — Tails of Iron (Sapega, 2026-10-26: «подивись, як брама зроблена; у нас теж вже непогано, але могло
бути краще»)

- The gate is a door **at the foot of the tower**, on the walk line, under a lit arch; the road runs straight into it.
- **Light and smoke:** slanted light shafts through the smoke, fires burning behind the ruins, a dark vignette at the
  top (tree canopy) — the scene has depth from light, not only from layers.
- **Foreground rubble** along the bottom edge: dark broken stakes, stones and debris in front of the road, partly
  covering the lowest strip of the view.
- **The road** is uneven cobbles and rubble with a visible top surface; characters stand on it.
Our CityGates: keep the walls and banners; add the lit door at the foot of the gate tower where the gate fight ends,
light shafts / a warm glow, foreground rubble at the bottom (Decor, darkened, scroll 1.25–1.4), the new floor surface.

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
| LizardCave | ExitDoor (320, 376) | the lit cave opening (moved from x 96 at a lizard shrine, `cloud/elder-home`, D716) | ✅ | — |
| DragonMural | ExitDoor (96, 376) | in front of the mural | ❌ | a tunnel mouth (art) |
| BanditCamp | ExitDoor (96, 376) | open sand | ❌ | the stockade gate from inside (art) |
| BanditCamp | ShortcutDoor (1640, 376) | next to a barrel | ❌ | the back gate from inside (art) |
| MesaClimb | ExitDoor (96, 856) | rocks | ❌ | the path's opening (art) |
| GatehouseCellar | ExitDoor (96, 376) | foot of the stairs up | ⚠ | at the top of the stairs, or a door there — the stairs are only painted (flat floor at y 416, no step to stand on), so the door stays (D716) |

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
