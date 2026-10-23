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

> **2026-10-23, D565 (Sapega):** the demo has **three locations** taken from his world map (`design/refs/world_map_figma.png`, Figma `94:609`):
> 1. **Canyon of Whispers**: the canyon, the village, the desert road and Zahra's Rest. The canyon-exit cutscene becomes a walkable cave under the bridge that comes out on the road.
> 2. **The City**: the Gates and the City.
> 3. **The Laboratory**.
> 
> Paths open with keys and NPC talks, and side branches (a little cave, an attic, a cellar) hold secrets (D562). The genre is Tails of Iron's (D563). Slice 1's `locations.json` uses these three. Slice 4 stays the Laboratory; slice 5 becomes the Canyon of Whispers location (the road joins it), and slices 6–8 shrink to the City.

## Curiosity map (D583, D562, D565), draft for Sapega, 2026-10-23

**Rule:** nothing lies free on the main road. Every branch ends in a **chest**, a **piece of story** or a **shortcut** back to a meditation spot. Paths open with **keys** or **NPC talks**, never with new abilities. Optional fights guard the best chests (D582: crowds are hard).

### 1. Canyon of Whispers (the canyon, the village, the road, Zahra's Rest)

| Where | How you get in | What it holds |
|---|---|---|
| **The family shrine in Lizard Cave**, a side tunnel of the cave under the bridge | the grandfather's old key: he gives it after the talk in his house | **story:** a mural of the shaman family and the barrier. **Chest:** a shaman amulet (the first charm, or a Healing Palm upgrade) |
| **The grandfather's attic** (ElderHouse) | a ladder behind the curtain, once he lets you up (talk) | **story:** his notes on the barrier that fell asleep. A small potion |
| **A breakable wall in the canyon** | a heavy attack on a cracked wall | **story:** an old dragon mural (the dragons nobody has seen for ages) |
| **The bandit camp** on a dune side path off the road | open, but it is a hard group fight (D582) | **chest:** goods stolen from the village (they robbed his people). An elite bandit with a key |
| **Mesa climb** (today's `Pickup_MesaLedge` moves here) | a jump route up the mesa | **chest:** a weapon with a trade-off |
| **Shortcut** from the bandit camp back to Zahra's Rest | a gate opened from the far side | a shortcut to the meditation spot |

### 2. The City (the Gates and the City)

| Where | How you get in | What it holds |
|---|---|---|
| **The gatehouse cellar** | the guard lets you down if you clear the bats (talk) | a fight with bats (D558), then a **chest** |
| **The tavern attic** | a ladder behind the market stall | **the merchant's lost ledger** returned to him: a discount or an item (NPC quest) |
| **The Mayor Hall archive** behind a bookshelf | a key from the mayor's desk | **story:** the empire and the barriers. **Chest** |
| **Rooftops** | a climb from the market | a **shortcut** back to the Gates' meditation spot |

### 3. The Laboratory

| Where | How you get in | What it holds |
|---|---|---|
| **The collapsed drain** under Laboratory Outside | a crawl through a pipe | a second way into the cells, plus a **chest** |
| **The alchemist's storeroom** | the key from his desk in the corridor | **story:** his journal (the experiments, the djinn). Potion ingredients |
| **Malik's stash** | Malik's talk: "under the loose stone in my cell" | gold and his gift (his "humble place" promise) |
| **A lever** by the boss door | pull it from the far side | a **shortcut** back to the entrance meditation spot |

Every story piece goes into the Journal. Rewards are tuned so that the main path alone stays winnable, while explorers get the edge.

## Branch batch 1 (D643, Sapega «так», 2026-10-23)

Five new side rooms from the curiosity map, each a real MetSys room off the main road (not a roof). Art first (the
ComfyUI lane: one backdrop each, comfy-backdrop skill, in the style of the room it branches from), then one cloud
routine builds the rooms, doors, keys and contents with room-content. MetSys cell 864×480.

| # | Room (scene) | Location | Branches off | Size | How you get in | What it holds |
|---|---|---|---|---|---|---|
| 1 | **Lizard Cave** (`LizardCave`) | Canyon of Whispers | the Canyon, under the bridge | 2 cells wide | open; its side tunnel to the shrine is a `LockedDoor` (the grandfather's old key, given after the talk in his house) | the family shrine: **story** (a mural of the shaman family and the barrier) + **chest** (the first charm, D592, or a Healing Palm upgrade). A few small enemies in the open part |
| 2 | **Bandit Camp** (`BanditCamp`) | Canyon of Whispers | a dune side path off the Desert Road | 2 cells wide | open, but a hard group fight (D582) with an elite bandit holding a key | **chest** of goods stolen from the village; a gate opened from inside = **shortcut** back to Zahra's Rest |
| 3 | **Mesa Climb** (`MesaClimb`) | Canyon of Whispers | the Desert Road, the mesa | 1 cell wide, 2 tall | a jump route up the mesa (no new ability) | **chest:** a weapon with a trade-off. Vultures circle it (D558) |
| 4 | **Dragon Mural** (`DragonMural`) | Canyon of Whispers | the Canyon, a cracked wall | 1 cell | a heavy attack breaks the wall (`BreakableWall`) | **story:** an old dragon mural (the dragons nobody has seen for ages) |
| 5 | **Gatehouse Cellar** (`GatehouseCellar`) | The City | City Gates, the gatehouse | 1–2 cells | the guard lets you down (talk) | a **bat** fight (D558: bats live here, so the bat finally has a home) and a **chest** |

Backdrops to draw (one each, plus a far parallax plane where the room is outdoors): a sandstone cave with a carved
lizard-shaman shrine; a bandit camp of ragged tents and stolen crates on a dune; the mesa's terraced cliff; a small
cave chamber whose wall is a faded dragon mural; a stone gatehouse cellar with barrels and arches.

Out of this batch: the City rooftops, the tavern attic, the Mayor Hall archive, the Laboratory branches (batch 2).

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

### Slice 5 — The Desert Road as a region (D487: «так само треба переробити дорогу»)
- Same treatment as slice 4. The road becomes connected stretches: the main road, a dune side path, a mesa climb, a ruin with a
  chest and a secret, and a shortcut back. Vultures overhead (D445) and a meditation spot (D447).

### Slices 6–8 — The other three locations, one per slice, in story order.

## Order and dependencies
`1 → 2 → 3`, while 4 can start after 1. `4 → 5…8`. The fade and background loading (D434, [[performance_plan]]) should
land before slice 4: more rooms means more transitions.

## Out of scope for this pass
- Fast travel between meditation spots (later; Tails of Iron-style travel points).
- Ability gates (Q76).
- New locations beyond the five (Q75).
