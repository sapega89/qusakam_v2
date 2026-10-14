---
type: plan
status: planned
---

# Room state — plan

**Built 2026-10-14** (slices 1–2). Rooms remember their fight: who is dead, the HP of the
living, and that the fight line was already played. Figma: no design exists (no UI — this is world state).

Reported by Sapega in play: an enemy appears, the player leaves the room, comes back —
the enemy's HP bar is still on screen but the enemy never reappears. The orphan HP bar
was a separate bug and is fixed (`DefaultEnemy._exit_tree` frees it). What remains is
the missing system: "remember what happened in a room — dialogue done, enemies spawned,
how much HP each had when I left".

## What exists today
| Thing | Where | State |
|---|---|---|
| Dialogue / story progress per room | `Game.set_quest_flag()`; e.g. `DesertRoad.gd:130` `desert_road_monologue_complete`, `:187` `desert_road_fight_complete` | ✅ works, saved with the game. **Dialogues are already remembered.** |
| Scripted fight restarts on re-entry | `DesertRoad.gd:_determine_initial_state` → `FIGHT_ENCOUNTER` → `_start_fight` replays `DesertRoad_Fight` and spawns all 4 again at full HP | ⚠️ works, but every enemy is fresh — killed ones return, HP resets |
| Enemy spawning | `Scripts/Gameplay/RoomEnemySpawner.gd` — every `EnemySpawnPoint` under the room, `spawn_all_enemies()` | ✅ no memory of earlier spawns |
| Rooms with spawners | `Maps/DesertRoad.tscn:103`, `CityGates.tscn:67`, `Village.tscn:89`, `Laboratory.tscn:82` (all `auto_spawn_on_ready = false`, started by the room script) | ✅ |
| MetSys storable objects | `MetroidvaniaSystem.gd:224` `register_storable_object_with_marker` / `save_data.store_object` | ✅ in the addon, **unused** here. Stores "this object is gone", not HP |
| Earlier attempt | `EnemyStateManager.gd`, deleted in `42310058` — wrote `user://enemy_states.ini` on every death, nothing read it | ❌ removed as write-only |

## Missing entirely
- A per-room state store that survives unloading the room and goes into the save.
  `grep -rn "room_state" SampleProject/Scripts` → 0 hits.
- Enemy identity across loads: an enemy is a fresh node each time; the stable key would be
  its `EnemySpawnPoint` path inside the room.
- `RoomEnemySpawner` writing "who is alive, with what HP" when the room unloads, and
  reading it back when it spawns.

## Decisions required
1. ✅ **Decided — D152: (b).** Was Q44. What does re-entering a room do to its enemies?
   - (a) Fresh every time (today) — classic metroidvania respawn.
   - (b) Exactly as left: dead stay dead, the living keep their HP — until the fight is won.
   - (c) As (b), but everything resets on save-point rest.
   Recommendation: **(b) for scripted story fights** (the only fights the prologue has);
   decide (a)/(c) when free-roaming enemies exist. Blocks slice 2.
2. Does room state go into the save file, or live only for the session?
   Recommendation: into the save, beside quest flags (`Game.gd:274` `save_game`). Not
   blocking — slice 1 can do it either way; the default is "into the save".

## Slices
### ✅ Slice 1 — the store (done 2026-10-14)
- `Game.gd`: `room_state: Dictionary` keyed by MetSys room name → `{key: value}`;
  `get_room_state(key)` / `set_room_state(key, value)` for the current room; saved and
  loaded in `save_game` / `_initialize_save_and_room` next to `events`.
- `SampleProject/UI/verify_room_state.gd`: set a value, leave the room, come back, read it;
  save, load, read it.
- Commit.
- **Note for slice 2:** values come back from the save as JSON — an int HP returns as a
  float (42 → 42.0). Cast on read.
### ✅ Slice 2 — enemies remember (D152, done 2026-10-14)
- `RoomEnemySpawner.gd`: on `_exit_tree` write `{spawn_point_path: hp}` for living enemies
  and the list of killed ones; `spawn_all_enemies()` skips killed points and applies HP.
- Room scripts (`DesertRoad.gd`, `CityGates.gd`, `Village.gd`, `Laboratory.gd`): returning
  mid-fight resumes the fight without replaying its dialogue.
- `verify_room_state.gd`: hit one zombie, kill one, leave, return → 3 enemies, one damaged.
- Commit.

As built: `RoomEnemySpawner` keeps `{spawn_id: HP}` under room-state key `enemies` (-1 = not
spawned yet), writes the whole fight at its start (so a wave that had not appeared yet is not
lost on leaving), updates HP on every `health_changed` and drops a killed enemy. The four room
scripts skip the fight line when `fight_in_progress()`. Waves still apply on return.

## Order and dependencies
`1 → 2`. Nothing blocks.

## Out of scope for this pass
- Free-roaming enemy respawn rules — no such enemies yet.
- Pickups / chests remembering they were taken — that is MetSys storable objects, see
  [[BACKLOG]] → `ItemPickup` placement (D88).
