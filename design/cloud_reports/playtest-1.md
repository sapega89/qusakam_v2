---
type: report
status: done
tags: [cloud, playtest, dialogue, cutscene]
---

# Cloud routine: playtest-1 (Sapega's playtest, 2026-10-23)

Branch `cloud/playtest-1`, from `feature/backlog` @ `6182a265`. Rules: [[ROUTINE_RULES]].

**Summary**
- **Done:** B122 (the dialogue box grows to fit the portrait on every `start_dialogue`), B123 (a cutscene that starts mid-air lands the hero first), D437 (the listed narrator lines are cut, en + uk), D439 (no Desert Road talk; the enemies stand on the road from the start).
- **Not done:** D438 (art), as instructed. There are 32 more speaker-less lines in the `say | |` spelling that D437 did not list (Q74 below).
- **D-ID text:** D443–D446 below.
- **B rows fixed:** B122, B123. Move both to Fixed with the commits below.
- **Full suite:** FULL_SUITE_LINE

## B122: the portrait sticks out below the dialogue box (`c6c71df0`)
- **Repro, through the real path:** `verify_dialogue_speaker` [1] then [2], two `start_dialogue` calls in a row (OldMan_Outside, then City_MayorHall). The first talk grows the box to 245 px. In the second, every line with a speaker and a portrait stayed at 178 px, with the portrait at y 835–995 under a box ending at 954. That is 4 FAIL with the new check and the old code.
- **Root cause:** when a talk ends, `DialogueManager._on_dialogue_quest_ended` hides the box and only then clears its name and portrait. Godot does not update the cached last minimum size of a hidden Control. On the next `start_dialogue` the box is shown empty, so its size is set to the 178-px offsets. When the name and portrait come back, the minimum size (245) equals the stale cached value, so no resize fires and the box stays at 178. The cutscene path and the isolated repro were both a *first* show, which is why they grew correctly.
- **Fix, in the shared place** (`Scripts/UI/GameDialogueBox.gd`): the box sets its own `offset_top` from `max(178, combined minimum height)`, deferred and coalesced, whenever the text, name, portrait or visibility changes. The bottom edge stays where it is, the box grows upward and shrinks back for a short line.
- **Check:** `verify_dialogue_speaker._check_line` asserts that the box rect encloses the portrait rect on every line with a speaker and a portrait, on the `start_dialogue` path. RESULT: ALL PASS.

## B123: a cutscene starts while Kusakam is in the air (`374daa57`)
- **Shared fix** (`Scripts/Systems/Cutscenes/Cutscene.gd`): `_init` records `velocity.y` before `hold()`. If the hero is not on the floor, `_start_landing` runs. Each physics frame it applies his own gravity (`PlayerMover.gravity`, capped at `max_fall_speed`) with x = 0 and calls `move_and_slide`, while his input stays off (`event`). The Fall pose plays. Once he is on the floor the cutscene `hold()`s him and emits `landed`. `walk_hero` waits for `landed`. `end()` and `_abandon()` stop the landing.
- **Lines wait too:** the Canyon exit starts its talk through `DialogueManager`, not `cs.say`. So `DialogueManager.hold_lines()` / `release_lines()` queue any `start_dialogue` (cloud talks too) until he lands. On abandon (the game leaves mid-fall) the held lines are dropped.
- **Check:** `verify_cutscene` [0]. The hero is lifted 160 px at the City Gates, `Cutscene.new()` runs mid-air, then `start_dialogue` (the Canyon exit's way). The line waits while he falls, he is on the floor when `dialogue_started` fires, he is at ground y (360 vs 360) with input off, and control comes back after `end()`. RESULT: ALL PASS.

## D437: no narrator lines (`374daa57`)
- **Cut** (en + uk twins): `Canyon_AbductionCutscene:1-3`, `Canyon_ExitCutscene:4`, `OldMan_Healing:3-4`, `OldMan_Outside:2`, `VillageAbduction:5`, and Kusakam's "But I know - this is my path." (`Canyon_ExitCutscene:6`).
- **Given a speaker:** `ArrivalToVillage:1` → `BANDIT_1` (D443), `RoadToVillage:1` → `KUSAKAM` (D444). Their stage tags `[Village]` / `[Canyon]` went with the narrator form.
- **The healing is shown, not told** (D445): `Village._show_healing_light` puts the Healing Palm cast effect (`Scenes/FX/Skills/HealingPalm.tscn`: charge, then release) on Kusakam when Grandfather heals him.
- **Flows that read the removed lines:** no localisation keys (the dialogue twins are not in the `.po` files), and no cutscene step counted lines. These verify scripts expected a line that is gone:
  - `verify_dialogue_speaker` [1] now opens on Kusakam. The new [1b] checks a speaker-less line on `Laboratory_Outside`.
  - `verify_canyon_exit` [0]: the cloud opens on "What is that?".
  - `verify_audio` [5]: the narration-is-silent check replays `Laboratory_Outside`, and the cloud talk types Kusakam's first line.
  - `verify_village_fight` [6] gains a check for the healing light on screen.

## D439: no talk on the Desert Road (`374daa57`)
- **Cut:** `DesertRoad_Monologue.dqd` and `DesertRoad_Fight.dqd` (en + uk), the `StateChangeTrigger_DesertMonologue` node (with its unused shape and script ext_resource), the TRAVELING state, `_play_dialogue` / `_execute_step` / `_complete_quest_for_dialogue`, and the `desert_road_monologue_complete` flag. There is no old-save branch: an old save with the flag just has an unread key. The flag is also gone from `story.json` (objective "Continue on to the city", chronicle "The desert road stretched ahead…"), from both `.po` files, and from ~30 verify / capture scripts that set it to get past the monologue.
- **New flow** (`DesertRoad.gd`): the room starts in `FIGHT_ENCOUNTER` and spawns its four enemies at once, or in `TRANSITION_TO_CITY` once `desert_road_fight_complete` is set. The `EnemySpawner` no longer spawns in waves, so all four stand on the road when the hero arrives (D446). They stand at x 800–1100, more than their 300-px `detection_range` from the arrival at x 80, so they attack when he comes near. Killing them all still sets `desert_road_fight_complete` and moves to `TRANSITION_TO_CITY`. The merchant arrival (`verify_npc_arrival`, `verify_cutscene` [2]) and the save point are untouched.
- **Check:** `verify_desert_road`, rewritten:
  - no talk on arrival, the files and the trigger are gone;
  - 4 enemies at once, each out of reach of the arrival;
  - killing them all ends the fight;
  - re-entering leaves the road clear.
- `verify_room_state` (mid-fight leave / load), `verify_road_sections`, `verify_npc_arrival`: ALL PASS.

## D-ID text (for the orchestrator)
| ID | Type | Text |
|---|---|---|
| D443 | ROUTINE CALL | **"Hold it, kid!" (ArrivalToVillage) is the bandit's line** (D437). `ArrivalToVillage:1` → `BANDIT_1` (en + uk). He is the bandit Kusakam fights next (`FightWithBandit`). The `[Village]` stage tag is dropped. |
| D444 | ROUTINE CALL | **"Time to head for the village." (RoadToVillage) is Kusakam's** (D437). It is first person, and cutting it would leave `RoadToVillage` empty (it is played by `Canyon.gd` and the Canyon trigger). `RoadToVillage:1` → `KUSAKAM` (en + uk), `[Canyon]` tag dropped. |
| D445 | ROUTINE CALL | **Grandfather's healing is shown with the Healing Palm light** (D437: "the event must be shown on screen"). When `OldMan_Healing` ends and Kusakam's HP goes to full, `Village._show_healing_light` plays `HealingPalm.tscn` (charge 0.6 s → release 0.8 s) on him. This reuses D271's effect; no new art. Grandfather's stagger (the other cut line) waits for D438's art. `verify_village_fight` [6]. |
| D446 | ROUTINE CALL | **The Desert Road's four enemies stand on the road at once, not in two waves** (D439: "the enemies stand on the road when the hero arrives"). `DesertRoad.tscn → EnemySpawner`: `spawn_in_waves` off. The Fight_Dunes / Fight_Mesa sections keep their waves. |

Also note on B122 in BUGS → Fixed: the root cause (stale minimum size after hide-then-clear) and `GameDialogueBox._refit`.

## Q74 (non-blocking; for `questions_for_sapega.md`)
**Q74: The other speaker-less lines.** D437 listed the 10 `say||` lines, but `dialogue_quest/en` has 32 more speaker-less lines written `say | |` (with spaces) in 11 files: AfterFight_Meditation, Canyon_MeditationAtRelic, Canyon_Monologue, CityGates, FirstFight_Canyon, Laboratory_AfterBoss, Laboratory_BossFight, Laboratory_Outside, LeavingVillage, RelicArmor_Examine, ReturnToCanyon. Many are Kusakam's thoughts tagged `[Hero]` / `[Kusakam]` (→ give him the line); some are real narration ("The village is left empty…", "You have left the laboratory…", "[The laboratory gates grind open.]") (→ cut). **Default:** the same rule as D437, done in a follow-up routine. Not touched here.

## Files
- B122: `Scripts/UI/GameDialogueBox.gd`, `UI/verify_dialogue_speaker.gd`.
- B123: `Scripts/Systems/Cutscenes/Cutscene.gd`, `Scripts/Systems/DialogueManager.gd` (`hold_lines` / `release_lines`), `UI/verify_cutscene.gd` [0].
- D437: 14 `.dqd` (7 en + 7 uk), `Scripts/Gameplay/Scenes/Village.gd`, `UI/verify_{dialogue_speaker,canyon_exit,audio,village_fight}.gd`.
- D439: `Scripts/Gameplay/Scenes/DesertRoad.gd`, `Maps/DesertRoad.tscn`, 4 `.dqd` deleted, `Resources/Data/story.json`, `Translations/{en,uk}.po`, `UI/verify_desert_road.gd`, flag lines in ~30 `UI/verify_*.gd` / `capture_*.gd`.
- No capture was taken (no window in this run). B122 is checked geometrically (box rect ⊇ portrait rect).
