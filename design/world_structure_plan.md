---
type: plan
status: planned
blocked-by: [Q75, Q76, Q77, Q78]
figma: "UI/World Map Base 68:1900, UI/Map/Marker 222:4785, menu-world-map 94:609"
tags: [world, map, metsys, rooms]
---

# World structure, Tails of Iron style: plan

**Not built.** Sapega asked for it on 2026-10-23: «карта — сама цікава частина, карта не мала бути такою
примітивною. Має бути як в Tails of Iron: великі локації, а всередині метроїдванія». The direction is D458; transitions
between locations fade to black (D434). Figma has the parchment world map (`UI/World Map Base` `68:1900`) and its
markers (`UI/Map/Marker` `222:4785`), but no location map.

## What exists today
| Thing | Where | State |
|---|---|---|
| Rooms | 11 MetSys rooms on 38 cells (`Maps/MapData.txt`): Canyon 4 · Village 6 + ElderHouse 1 · DesertRoad 6 · CityGates 2 · City 3 + MayorHall 1 · LaboratoryOutside 4 · Laboratory 6 · LabCells 2 · LabBoss 2 | ✅ but each location is 1–3 rooms in a line |
| Vertical rooms | Laboratory: ladders and one-way platforms (D225, [[lab_vertical_plan]]) | ✅ Laboratory only |
| Map screen | `metsys_map_component.tscn/.gd`: the MetSys grid drawn over the parchment background, plus the explored % ([[world_map_mapping]]) | ✅ grid only; legend and the 13 named markers have no data |
| Room change | `MetSysGame.load_room()`: synchronous load, no fade | ⚠️ freezes a weak PC; D434 and [[performance_plan]] fix it |
| Doors between rooms | `RoomDoor` (`InteractableComponent` + `Game.teleport_to_room`), MetSys borders | ✅ |
| Gating | none: no keys, levers or locked doors. The only "gates" are story states (`StateChangeTrigger`) | ❌ |

## Missing entirely
- A **location** as data. No file groups rooms into locations: `grep -rn "location" SampleProject/Resources/Data`
  finds only `GameFlow.location_title`, a title per room.
- A **world map** of locations, separate from the room map.
- A **location map**: only the current location's rooms, drawn as hand-drawn room shapes rather than grey squares, with
  icons for meditation spots (save, D447), merchants and exits.
- **Metroidvania content** inside a location: side paths, secrets, a shortcut opened from the far side, keys / levers /
  locked doors.

## Decisions required (all GAME DESIGN DECISION REQUIRED — Sapega skipped the questions on 2026-10-23, so the recommendations are the provisional defaults)
1. **Q75: which locations.** Default: the same five (Canyon, Village, Desert Road, City, Laboratory), each grown into a
   small metroidvania of 6–10 rooms with side paths, secrets and shortcuts. Sapega said 2026-10-20 "no new location
   names". Alternatives: Figma's Aethelgard names, or fewer but larger locations.
2. **Q76: what opens new paths.** Default: keys, levers and shortcuts that open from the far side. The hero's moveset
   stays (roll, D200). Ability gates (double jump, wall climb) come later, if ever.
3. **Q77: the maps.** Default: two maps. The **world map** is the illustrated parchment with the locations drawn on it
   and "you are here". The **location map** shows the current location's rooms, hand-drawn, with meditation spots,
   merchants and exits.
4. **Q78: the pilot location.** Default since D487: the **Laboratory**, which Sapega called short and without chests or secrets. Before that the default was the **Desert Road**. Its growth was already planned ([[world_expansion_plan]]),
   and it sits between the Village and the City. The Canyon would make the better first impression; the Laboratory
   already has floors.

## Slices
### Slice 1 — Locations as data
- `Resources/Data/locations.json`: per location an id, a name key, its rooms (MetSys scene uids), its world-map position
  and its entry rooms.
- `LocationDB` (preloaded helper).
- `GameFlow.location_title` reads it.
- Adds `verify_locations.gd`: every room belongs to exactly one location, and every location has an entry.
- Its own commit.

### Slice 2 — World map (Figma first)
- Claude draws the frame in Figma from `68:1900` + `222:4785` (D436 precedent). Sapega confirms.
- Then the Map tab shows the world map by default: the locations as drawings or markers, "you are here", and undiscovered
  locations dimmed. Selecting a location opens its location map.
- Its own verify and capture.

### Slice 3 — Location map
- The MetSys map restricted to the current location's rooms (`MetSys` map drawing filtered by the slice 1 room set).
- Restyled cells: a hand-drawn room shape, borders as walls, doors as gaps.
- Legend icons for meditation spot (D447), merchant, exit to the next location, and the "!" quest givers (D442).
- Its own verify and capture.

### Slice 4 — Pilot region: the Laboratory as a metroidvania (D487; was the Desert Road)
- First a room graph on paper, in this plan: the main road, 2 side paths, 1 secret, 1 shortcut opened from the far
  side, 1 locked door with its key.
- Then the rooms, using the room-content and comfy-backdrop skills: the backdrops in the style Sapega likes; enemies,
  including vultures (D445); pickups as sparkles (D446); a meditation spot (D447).
- Keys and levers get their own small system: a `Lever` / `LockedDoor` scene and a key item.
- `verify_desert_road_layout.gd` walks the graph.

### Slices 5–8 — The other four locations, one per slice, in story order.

## Order and dependencies
`1 → 2 → 3`, while 4 can start after 1. `4 → 5…8`. The fade and background loading (D434, [[performance_plan]]) should
land before slice 4: more rooms means more transitions.

## Out of scope for this pass
- Fast travel between meditation spots (later; Tails of Iron-style travel points).
- Ability gates (Q76).
- New locations beyond the five (Q75).
