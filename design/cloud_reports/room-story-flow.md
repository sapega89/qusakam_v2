---
type: report
status: done
tags: [cloud, code, maintainability]
---

# Cloud report: `cloud/room-story-flow` (2026-10-27)

**Summary.** Done: [[MASTER_PLAN]] S3 / [[code_review_2026-10-19]] §3.1. There is now one shared base,
`SampleProject/Scripts/Gameplay/Scenes/RoomStoryFlow.gd` (154 lines, preloaded by path, no `class_name`).
Seven rooms extend it: DesertRoad, Canyon, Village, ElderHouse, CityGates, LaboratoryOutside and LabBoss. The room
scripts lose 731 lines and gain 141, so 590 fewer lines net; with the base added, the drop is 436. The unused
SceneStateManager and ISceneStateManager (192 lines) are deleted. MayorHall and LabCells are left as they are (§4). No
story, flag, dialogue or objective change. A room's state is still not saved: it is re-derived from quest flags on entry,
as before, so old saves load into the same state. No `SampleProject/Maps/*` edits. No B rows fixed.
D-ID text (agent call, needs a number): see §5. **Full suite: `SUITE: ALL PASS` (132 verify scripts).**

Branch from `origin/feature/backlog` @ `b5cda2cf`. One commit per room, in the order the rooms were moved.

## 1. The base, `RoomStoryFlow.gd`

A room writes `extends "res://SampleProject/Scripts/Gameplay/Scenes/RoomStoryFlow.gd"` and keeps its own `enum State`.
The base reads that enum from the room's script constants with `get_script_constant_map()["State"]`, the same way
`StateChangeTrigger._is_backwards_transition()` already did.

| Shared (in the base) | What it replaces |
|---|---|
| `current_state: int` with a setter that calls `_on_state_changed()`; `state_run_id`; `signal state_complete` | the same setter, counter and signal copied into every room |
| `_ready()`: waits for ServiceLocator, then `_prepare()`, then `current_state = _initial_state()` (a single assignment, so the state does not start twice) | `_ready` + `_determine_initial_state` in each room |
| `_on_state_changed()`: increments the run id, logs, `_announce_state()` (EventBus.scene_state_changed), `_apply_state_logic(state, run_id)` | 6 copies |
| `get_current_state_name()`, `change_state_by_name()` (StateChangeTrigger) | 5 copies, 3 of them different |
| `advance_state()`: +1 until the last state, then `_on_story_end()` | 6 copies |
| `_play_dialogue(id, run_id, in_cloud)`: start, wait for this dialogue's `dialogue_finished`, set its flag, return whether it finished | 6 copies |
| `_dialogue_flags()` → `_complete_quest_for_dialogue()`: which dialogue sets which flag, as data | 6 `match` blocks |
| `_dialogue_then_advance(id, run_id)` | `_execute_step(StepType.DIALOGUE, …)` and the unused `StepType` enum (COMBAT, LOOP and TRANSITION were never used outside Canyon) |
| `_skip_done(flag)`: the B66 rule ("an already-done branch must advance"), now written once | the comment in Village and the hand-written branches in Village and ElderHouse |
| `_fight_won(state, flag)`: checks the state, sets the flag **before** `advance_state()`, then advances | `_on_all_enemies_defeated` in Village, DesertRoad, CityGates |
| `_set_objective(text, target)` | 6 copies |

## 2. Per room: lines removed, and what stayed room-specific

| Room | Lines (before → after) | Diff | Stayed in the room |
|---|---|---|---|
| DesertRoad | 91 → 52 | +9 −48 | State, `_initial_state` (desert_road_fight_complete), the `canyon_exit_complete` flag on entry, the spawner |
| Canyon | 800 → 640 | +46 −206 | its own `_ready` (gate controllers, frame waits, the repeat-call guard), `_on_state_changed` override (`is_node_ready` guard and the gates update), `_announce_state` with the previous state, `_determine_initial_state`, `_dialogue_step` (a dialogue already read is skipped and does **not** advance; EXPLORATION and CUTSCENE_ABDUCTION wait for a trigger), the one-dialogue-at-a-time guard with the 0.1 s pause (B154) wrapped around `super._play_dialogue`, `_is_dialogue_completed`, all cutscenes (meditation, descent), the gates |
| Village | 263 → 110 | +29 −182 | State, `_initial_state`, `_dialogue_flags`, the bandit fight with enemies switched off during the taunt (D743, D152) |
| ElderHouse | 183 → 122 | +26 −87 | State, `_initial_state`, `_dialogue_flags` (village_oldman_*), the talk and the healing light, the gift and the key on OldMan_Decision (an override of `_complete_quest_for_dialogue` that hands them out before the flag, same order as before) |
| CityGates | 251 → 166 | +12 −97 | State, `_initial_state`, `_dialogue_flags`, the raid cutscene, the census (D727), the guard assist and tips (D209, D744), `_exit_tree` |
| LaboratoryOutside | 177 → 95 | +9 −91 | State, `_dialogue_flags` (Demo_End), the demo-end screen (`_on_story_end`) |
| LabBoss | 196 → 186 | +10 −20 | everything except the state plumbing: `_enter(state)` became the setter, `_ready` became `_prepare` (`_apply_state_logic` keeps the old `match`). Its talks are cutscenes (`Cutscene.say`), so it has no dialogue flags |

Most of Village's 182 removed lines were comments about the old `Engine.has_singleton()` bugs inside the copied
`_play_dialogue` and `_get_dialogue_manager`. Those functions now exist only in the base.

## 3. Behaviour: what is identical, and the small differences

Identical: state order, flags and when they are set, dialogues, objectives, the stale-branch exit by `state_run_id`, the
initial state taken from flags. Each room's verifies passed right after that room was moved (§6).

Small differences, all with nobody listening or no live path:
- `EventBus.scene_state_changed` is now emitted by every room. Before, only Canyon, Village and ElderHouse emitted it.
  Nothing connects to this signal (grep: only the doc comment in EventBus.gd).
- `state_complete` is now also emitted when `_dialogue_then_advance` finishes LaboratoryOutside, before the demo-end
  screen. Nobody connects to it.
- `change_state_by_name` is now strict: it asserts that the name exists. Before, Village and ElderHouse warned and Canyon
  upper-cased the name. Every `target_state` in Maps/*.tscn (Canyon, Village, ElderHouse, CityGates) is an upper-case
  name that exists.
- `current_state` is no longer `@export`. No `.tscn` sets it.
- Canyon: the special case "TO_VILLAGE after the village" in `_on_state_changed` is gone. `_on_to_village_state` already
  did the same thing (objective "Return to the village", no dialogue).
- Canyon: the fallback search over `dialogue_quest/dialogues/` is gone. That folder does not exist, so the path was
  always `res://dialogue_quest/<id>.dqd`.
- Log lines are shorter and use the room's file name (for example "Village: Entering state …"). Village also lost its
  "already done, skipping" log lines; `_skip_done` logs one line instead.

## 4. Not moved

- **MayorHall, LabCells**: here `State` only marks how far a cutscene has got. There is no setter, no run id, no
  `advance_state`, and no dialogue-to-flag mapping, because the talks are `Cutscene.say`. The only thing they could share
  is `get_current_state_name` (3 lines), and giving them a setter would mean every `current_state = X` inside a cutscene
  starts a state. Left alone.
- **Laboratory, City**: these have no State enum.
- Canyon still contains dead code (`trigger_abduction_cutscene`, `set_state_for_relic_pickup`,
  `_open_gate_if_quest_complete`, `_after_relic_meditation`, none of them called) and about 10 raw `print()` lines
  (§3.2 of the code review). Neither is part of S3, so I left them.

## 5. D-ID text (agent call, for the orchestrator to number)

> **D?: room story scripts share `RoomStoryFlow`.** A room with a story state machine extends
> `Scenes/RoomStoryFlow.gd` and keeps only its `enum State` (in story order), `_initial_state()` from quest flags,
> `_apply_state_logic()`, `_dialogue_flags()` and its own cutscenes and fights. "Already done → advance" (B66) is
> `_skip_done(flag)`, and a won fight is `_fight_won(state, flag)` (the flag goes before the advance). Rooms whose
> states only mark cutscene progress (MayorHall, LabCells) stay plain. SceneStateManager and ISceneStateManager are
> removed.

## 6. Tests

Baseline before any change: all of the verifies below were `RESULT: ALL PASS`.

| Step | Verifies (all `RESULT: ALL PASS`) |
|---|---|
| DesertRoad | desert_road, road_sections, save_load, save_load_room |
| Canyon | canyon_exit (new game → intro → EXPLORATION → summit → CUTSCENE_ABDUCTION → RELIC_PICKUP → descent), story_journal, gates, dialogue_triggers, onboarding, camera_transitions, save_load, save_load_room |
| Village | village_fight, village_house, story_journal, journal, masher, save_load, save_load_room |
| ElderHouse | village_house, village_fight, gift_popup, starter_loot, rooms_batch1, save_load, save_load_room |
| CityGates | city_gates_raid, oath_census, npc_flow, road_sections, save_load, save_load_room |
| LaboratoryOutside | demo_end, lab_route, lab_rooms, save_load, save_load_room |
| LabBoss | lab_boss, bosses, lab_route, save_load, save_load_room |
| End | `Scripts/Tools/run_verify.sh` → `SUITE: ALL PASS` (132 scripts) |

`verify_story_flow.gd` does not exist. One run of city_gates_raid failed check [7] once ("the hero falls after the
teleport (y 360.0 -> 360.0)"), which is a B80 physics-timing check. It passed on the next two runs and in the full
suite, and it does not touch the state flow.
