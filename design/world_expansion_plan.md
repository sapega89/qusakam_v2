---
type: plan
status: in-progress  # DesertRoad part done 2026-10-21 (D296–D299, B79); Laboratory part — with BACKLOG 16 + 17
tags: [world, map, xp, feedback]
---

# World expansion — plan (BACKLOG 23)

## Tails (2026-10-27)

Checked against the code by routine `decision-audit-2` (MASTER_PLAN S16). Every other slice is built.

- Slice 4, landmarks (D299): the art is in (`DesertRoad.tscn:18-20` `gen_tower`, `gen_wreck`, `gen_shrine`). The `fb23_*` captures along the road were never taken.

> **Ledge A's Potion is now an Iron Ingot** (potions removed in 4b, D261): `DesertRoad.tscn` `ItemPickup`s are `iron_ingot`, `herb`; ledge C holds a **chest** with Mana Crystal × 2 since cloud/chests ([[chests_plan]]). The Laboratory part moved to [[lab_story_plan]] (D303, queue 9.4–9.8).

**Sapega 2026-10-20:** no new location names. City, CityGates, Village and Canyon stay as they are. Before the City
only **DesertRoad** grows — longer, more MetSys cells, more fights, side ledges with pickups — and the XP curve is
tuned so the hero reaches **level 5 at the City** (the oath, D280, is sworn there from level 5). The **Laboratory**
grows and splits into several screens later, with the rewritten Laboratory story (BACKLOG 16 + 17).
Figma: no design exists (world layout is not a UI screen). Calls made here: **D296–D299** (agent calls, Sapega to confirm).

## What exists today (2026-10-21, before this pass)

| Thing | Where | State |
|---|---|---|
| DesertRoad room, **2 MetSys cells** (1728 px) | `Maps/MapData.txt` `[0,3,0]`, `[1,3,0]` (uid `1jf0qd1hdorm`); live settings `Resources/Settings.tres` cell 864×480 | ✅ flat floor, top y 384 (tile rows 12–14, x tiles −6…60) |
| Its neighbours | CityGates `[2..3,3,0]`, City `[4..6,3,0]`, MayorHall `[7,3,0]`; Canyon `[0..2,1,0]` + `[0,2,0]`, Village `[3..5,1..2,0]` | ✅ Canyon → road is a teleport cutscene (`Canyon.gd:734` → `ArrivalFromCanyon`); road → CityGates is the MetSys border `[1,3]` R=1 ↔ `[2,3]` L=1 |
| Room script | `Scripts/Gameplay/Scenes/DesertRoad.gd` — `TRAVELING → FIGHT_ENCOUNTER → TRANSITION_TO_CITY` | ✅ monologue trigger x 400, then the `DesertRoad_Fight` line, then `EnemySpawner` |
| The one fight | `DesertRoad.tscn` `EnemySpawner` (waves of 2): melee x 800, fast 900, melee 1000, fast 1100 | ✅ `desert_road_fight_complete` |
| Merchant shop + arrival | `Shop` sprite x 1087, `ShopDoor` x 1227, `Merchant` x 1120, `MerchantArrival` zone x 900–1500 (D292–D294) | ✅ after the fight |
| Save point | `SavePoint_BeforeCity` x 1500 | ✅ |
| Painted terrain | `Terrain` sprite ← `Scripts/Tools/build_terrain.gd -- mask` → `paint_terrain.py` (earth + cobble_top, D248/D249) | ✅ |
| Backdrops | `desert_backdrop_open.tscn` (sky, clouds, mesas — repeat) + `Mid` `Road/gen_mid.png` (dunes, repeat) | ✅ repeat at any length |
| Spawner | `Scripts/Gameplay/RoomEnemySpawner.gd` — searched the **whole room** for spawn points (`:70`) and kept one room-state key `"enemies"` (`:34`) | ⚠️ two spawners in one room would share points and state |
| XP sources | only enemy kills: `DefaultEnemy._calculate_xp_reward` `:392` — melee 25, tank 40, fast 20, **hardcoded** | ⚠️ in code |
| XP curve | `XPManager._calculate_xp_requirement` `:59` — `level × 100` (L2 100, L3 300, L4 600, **L5 1000** cumulative), hardcoded | ⚠️ in code |
| XP in saves | `Game.gd:308` writes the level only into the slot card; nothing restores `current_xp` / `current_level` | ❌ **B79** — a loaded save is level 1 |

### XP the hero has today, room by room (normal play kills every enemy)

| Room | Enemies | XP gained | Total | Level |
|---|---|---|---|---|
| Canyon I / II | none | 0 | 0 | 1 |
| Village | 1 melee | 25 | 25 | 1 |
| DesertRoad | 2 melee + 2 fast | 90 | 115 | 2 |
| CityGates (raid) | 3 melee | 75 | 190 | 2 |
| **City** | — | — | 190 | **2** — the oath needs 5 |

## The new DesertRoad — D296

**6 cells** (5184 px), `[0..5,3,0]`. CityGates, City and MayorHall move **+4 cells east** in `MapData.txt`
(`[6..7,3]`, `[8..10,3]`, `[11,3]`); no script holds a cell coordinate (`grep Vector3i` → only MetSys helpers).
Floor stays at y 384 on both room edges (the passage to CityGates keeps its height, `verify_map_geometry` [4]).
Hero jump ≈ 103 px (`PlayerMover.jump_velocity` −450, gravity 980), so every step is **2 tiles (64 px)**.

| Cell | x (px) | Section | Content |
|---|---|---|---|
| 0–1 | 0–1728 | **The descent** (as today) | arrival, monologue, fight 1 (`EnemySpawner`: 2 melee + 2 fast), Merchant shop + arrival |
| 2 | 1728–2592 | **The dune ledges** | ledge A: a 2-tile step (tiles 58–61) and a 4-tile rock (62–65), **Potion** on top; fight 2 on the floor (`Fight_Dunes`: 2 melee + 2 fast, x 2250–2490); generated ruined watchtower behind it |
| 3 | 2592–3456 | **The mesa** | a raised plateau (tiles 86–101, top y 320) — fight 3 on it (`Fight_Mesa`: tank + melee + 2 fast); ledge B: a 2-tile rock at its east end (98–101, top y 256), **Herb ×2** on top; drop back to the road at tile 102 |
| 4 | 3456–4320 | **The broken caravan** | fight 4, the ambush (`Fight_Caravan`: 2 tanks + 2 melee + fast, x 3640–3960); a generated wrecked wagon behind it — the bandits' loot cart (D293's stolen caravan went on to the Gates); ledge C: a step (124–127) and a 4-tile rock (128–130), **Mana Crystal** on top (a chest with Mana Crystal × 2 since [[chests_plan]]) |
| 5 | 4320–5184 | **The approach** | `SavePoint_BeforeCity` moves 1500 → 4900; a generated wayside shrine; exit east to CityGates |

Fights 2–4: a `RoomEnemySpawner` each, spawning when the hero walks into its `trigger_area` (a new export), waves of 2
like fight 1; each keeps its own room-state key (`state_key`, D152 per fight). Existing enemies only, with their
souls-lite stats (D264/D265) — no new enemy types (ranged unbuilt, Q35). Fight 1 and the room's state machine are
untouched; the extra fights are not story beats (no flags, no lines).

**Pickups — D298** (D88 path 2: prompt → inventory → pickup modal; `ItemPickup.tscn`, the first ones in a live map).
Sapega's item list (asked 2026-10-15) never came; his rule for this queue is "make every call", so: a **Potion**
(ledge A), **Herb ×2** (ledge B — `craft_potion` takes 2) and a **Mana Crystal** (ledge C — Hi-Potion / Ether).
Only items with a drawn icon: the material icons under `release/…` (leather, ingots, ores) do not exist in the repo,
a pickup of them would show the placeholder. A picked item stays picked: `ItemPickup` writes
`picked_<node name>` into the room state (D152) and frees itself on the next load — no farming by re-entering.

**Backdrops — D299:** the sky/mesa/dune layers repeat and need nothing. Three generated landmarks (Qwen-Image,
`comfy_backdrop.py`, the `Road/gen_shop` pattern — one plane on the floor line): `Road/gen_tower` (cell 2),
`Road/gen_wreck` (cell 4), `Road/gen_shrine` (cell 5). One ComfyUI run of 3 images.

## The XP math — D297

The curve and the rewards move to data:
- `Resources/Data/xp_curve.json` — `first_level` 100, `step` 50: XP for the next level = 100 + 50 × (level − 1)
  → 100, 150, 200, 250, 300 …; cumulative **L2 100, L3 250, L4 450, L5 700**. At 98 → 99: 4950 (was 9800).
- `EnemyStats.xp_reward` in `Resources/Enemies/enemy_stats_*.tres` — **melee 30, fast 25, tank 70**.

| Where | Kills | XP | Total | Level after |
|---|---|---|---|---|
| Village | 1 melee | 30 | 30 | 1 |
| Road, fight 1 | 2 melee + 2 fast | 110 | 140 | **2** (Healing Palm on the road, as D252 had it) |
| Road, fight 2 (dunes) | 2 melee + 2 fast | 110 | 250 | 3 |
| Road, fight 3 (mesa) | tank + melee + 2 fast | 150 | 400 | 3 |
| Road, fight 4 (caravan) | 2 tanks + 2 melee + fast | 225 | 625 | 4 |
| CityGates raid | 3 melee | 90 | **715** | **5** — on the raid's last kill |
| **City** | | | 715 | **5** |

Before the CityGates fight is done the hero has 625–685 XP (< 700): level 5 cannot come early. A player who skips
one road fight reaches the City at 4 and meets level 5 at the next kills — the oath only waits.
`verify_xp_curve.gd` reads the spawn points from the real room scenes and the `.tres` rewards, so any later change
to a fight or a reward re-checks the landing.

## Slices

### Slice 1 — XP in data (D297)
- `XPManager.gd` reads `xp_curve.json`; `EnemyStats.xp_reward` + three `.tres`; `DefaultEnemy._calculate_xp_reward` deleted.
- `verify_xp_curve.gd`.

### Slice 2 — spawners per fight
- `RoomEnemySpawner`: spawn points = its own children (the room-wide search and `spawn_points_container` go),
  `state_key`, `trigger_area`; a duplicate key in one room is a loud error.

### Slice 3 — the road (D296, D298)
- `MapData.txt`: 4 new road cells, CityGates / City / MayorHall +4 east.
- `DesertRoad.tscn`: Foreground tiles (floor to tile 168, plateau, ledges), fights 2–4, pickups, save point.
- Terrain: `build_terrain.gd -- mask DesertRoad` → `paint_terrain.py DesertRoad` (materials cached).
- Tests: `verify_map_geometry`, `verify_desert_road`, `verify_room_state`, `verify_city_gates_raid`, `verify_canyon_exit`.

### Slice 4 — landmarks (D299)
- `comfy_backdrop.py` `Road/gen_tower`, `Road/gen_wreck`, `Road/gen_shrine`; sprites in `DesertRoad.tscn`.
- Captures `fb23_*` along the road.

### Slice 5 — B79, XP survives a save
- `current_level` / `current_xp` into the player save data and back.

Order: 1 → 2 → 3 → 4; 5 is independent.

## The Laboratory — outline only (BACKLOG 16 + 17, queue row 9) → planned in [[lab_story_plan]] (D303)

Today: one room `Laboratory.tscn`, 2×3 cells on layer 2 (`[14..15,3..5,2]`, D225 three floors joined by ladders),
plus `LaboratoryOutside` `[16..17,5..6,2]`. Item 17 rewrites the story; item 23 splits it into **separate MetSys rooms**:
1. **The cells floor** — where the prisoners are held (the prisoner's shout, Q64); the companion talks of item 17.
2. **The corridors** — one or two rooms of mob fights (the same per-fight spawners as the road).
3. **The boss room** — the fire djinn / cloak boss ([[lab_boss_plan]], item 6), the end of the demo.
Each is its own `.tscn` + MapData cells on layer 2, painted terrain and backdrops (`comfy-backdrop`), room state per
room. The rooms, their order and their triggers come from the item 17 story; plan them with it, not before
(the Laboratory's story beats decide the screens).

## Out of scope for this pass

- The Laboratory split (above) — BACKLOG 16 + 17.
- Canyon, Village, CityGates, City unchanged (Sapega 2026-10-20).
