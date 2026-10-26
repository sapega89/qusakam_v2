---
type: report
tags: [cloud, routines, dialogue]
branch: cloud/dialogue-triggers
date: 2026-10-26
---

# Cloud report: dialogue-triggers (built on `cloud/ui-critic`)

**Summary.** All five points are built in code on `cloud/dialogue-triggers` (from `origin/cloud/ui-critic` 4e957a5e). **Nothing was run:** the permission classifier refused to run the downloaded Godot 4.6.2 binary, the same as in `ui-critic`, and no other Godot is installed. So there was no import, no verify, no full suite and no capture.
- Triggers: one gate in `DialogueManager` (`when_story_free` / `when_story_free_inside`). A trigger entered during a story dialogue is queued and fires in order once the dialogue ends.
- Story dialogues, monologues included, hold the hero. Barks never hold him and never hold back a trigger.
- Typing: 48 letters/s (was 24). A press completes a typing line in the window and in the cloud talk.
- Auto-advance: 1.5–2.5 s, choices wait, Settings → Game → Auto-Advance.
- Trim drafts are in [[dialogue_trim]].

**D-IDs:** D737 (trigger gate and story hold), D738 (typing speed and press-to-complete), D739 (auto-advance, supersedes B10's «no Auto» in D736). **B row fixed:** B154 (lost triggers). D736 and B153 are already used on other branches; the orchestrator may renumber. **Full suite:** not run. **MASTER_PLAN** §3: row DT1 👀 → `integrator`.

## 1. Root cause: what each trigger did while a dialogue ran

"Dialogue" below means one of: a window talk (`start_dialogue`), a monologue in a bubble (D178), a cloud talk (D263), a replay (D158), or a bark (`say_in_passing`, D338 / BACKLOG 35).

| Trigger kind | Where | Before (during a dialogue) | Lost? | Now (D737) |
|---|---|---|---|---|
| `StateChangeTrigger` (story state / dialogue) | Canyon, Village, DesertRoad, CityGates, Lab rooms (`Scripts/Gameplay/StateChangeTrigger.gd`) | (a) The state change was applied **at once**, mid-dialogue, and its dialogue was queued. (b) `require_state` was checked at entry: if the running dialogue had not yet moved the scene to that state, the trigger was **dropped**. A hero standing in the zone gets no second `body_entered`, so it never fired. (c) In Canyon, the new state's dialogue was **swallowed** by `_play_dialogue` ("вже програється інший"), because `_is_dialogue_playing` was still true. During a monologue (D178) the hero kept walking, so he regularly hit the next trigger mid-dialogue. | yes (b, c) | Queued; **all** checks run when it fires. A story trigger fires even if the hero has left its zone, because it marks a place in the story, not «he stands here». A second entry while it waits does not queue it twice. Canyon clears `_is_dialogue_playing` before its 0.1 s pause (`Canyon.gd:486`). |
| `CanyonExitTrigger` (descent cutscene) | Canyon plateau edge | The cutscene started at once, on top of the dialogue. | no, but clashed | Queued; fires even if the hero has left (story event). |
| `RoomEnemySpawner` fight zone (section fights) | DesertRoad, CityGates, Lab, … | Enemies spawned mid-dialogue and hit the held hero. | no, but unfair | Queued as an **enter event**: if the hero is still in the zone, the fight starts; if he has left, the zone re-arms (the next entry starts it). |
| `CombatZone` context text | rooms with combat zones | The text popped over the dialogue. | no | Enter event, same as the fight zone: shown if he is still inside, re-armed (`has_triggered = false`) if he has left. |
| Room-script cutscene triggers: `LabCells` StepOut, `LabBoss` TalkTrigger, `MayorHall` QueueTrigger | room scripts | A cutscene (walk_hero, say) started on top of a running dialogue. Each one's state check happened at entry. | could clash | Queued through `when_story_free`; the state check runs when it fires. |
| `City` GateTalk (guard bark + objective) | City | A bark. While a dialogue runs, `say_in_passing` refuses it; the objective is still set. | the bark only | Unchanged: barks are never queued (they are colour, not story). |
| NPC chatter zones (`NpcBase`, `GateGuard`) | all NPCs | Bark refused during a dialogue, retried on the next entry. Never held anyone. | no | Unchanged. They do not count for `is_story_busy()`, so they never hold back a trigger. |
| NPC action menu auto-open (D454), tutorial banners | NpcBase, TutorialHintDisplay | They wait for `is_dialogue_active()` to clear. | no | Unchanged. |
| Interact prompts (doors, chests, TalkSpot, SavePoint, RelicArmor) | `InteractableComponent` | E during a window talk worked: a `RoomDoor` **teleported to another room mid-dialogue**, and a locked door queued its line. | no, but broke the talk | E is ignored while a story dialogue runs (`_gameplay_input_allowed` + `is_story_busy()`). The prompt stays, and E works once it ends. Barks do not block it. |
| `Portal` / `MiniPortal` | `Objects/*.tscn` | Not placed in any room (no `.tscn` instance). | — | Untouched. |
| Cutscene's own hold (`Cutscene.hold_lines`, B123) | Cutscene.gd | Talks wait for landing. | no | Counted as busy; release also flushes waiting triggers. Triggers the **cutscene itself** walks the hero through (`walk_hero`) are not gated: a cutscene is not a dialogue, and not every cutscene path reliably calls `end()` (MayorHall: 3 `Cutscene.new()`, 2 `end()`), so gating them could hang a trigger forever. |

## 2. The fix (one place)

`Scripts/Systems/DialogueManager.gd`:
- `is_story_busy()` is true while any of these runs or waits: a window talk, a replay, a monologue or cloud talk, a queued talk, or the B123 landing hold. Barks do not count.
- `when_story_free(action)` runs the action now, or queues it.
- `when_story_free_inside(area, action, rearm)` does the same. A queued action checks `area.overlaps_body(player)` when it fires: inside, `action` runs; outside, `rearm` runs.
- `_fire_pending_triggers()` runs from `_start_next_queued()` once the dialogue queue is empty. It also runs after a replay (`_end_replay`) and after `release_lines()`. Triggers fire one at a time: one that starts a new dialogue makes the rest wait for that one too. A trigger whose room has gone (its Callable is invalid) is dropped with the room, and `_on_bubble_gone` clears the list.
- Hold: monologue bubbles now call `_pause_player_for_dialogue()` / `_unpause_player_after_dialogue()` like windows and cloud talks. `Player.on_enter()` keeps the hold while `is_story_busy()`, so a monologue started in a room's `_ready` holds too. The hold is the same `set_movement_enabled` lock D735 uses, released on end or skip.

## 3–4. Typing and auto-advance

- `UITokens.DIALOGUE_LETTERS_PER_SECOND = 48.0`, set on the shared box settings in `GameDialogueBox._ready()` (the `.tres` also says 48). Settings → Text Speed Quick still doubles it (96). The cloud talk reads the same value.
- Press while typing: the window already did it through D736 (`accept()` → `finish()`). Speech bubbles that wait for input (cloud talk, D263) now do it too: `_press_bubble()` → `speech_bubble.finish_typing()` (the tween is stepped to its end). That covers Enter, left click and pad A (`dq_accept`), and the cutscene skip. Monologue bubbles (D178) show the line whole, as before, so a press there goes to the next line.
- Auto-advance: `GameDialogueBox._auto_advance()` and the cloud-talk loop share `auto_advance_delay(line)`, which is `clamp(len × 0.02, 1.5, 2.5)` s (`DIALOGUE_AUTO_MIN/PER_CHAR/MAX`). It never runs while the choice menu is visible, so the choice waits. A press still goes on at once.
- Settings → Game → **Auto-Advance** On/Off sits right under Text Speed. It is stored as `auto_advance` in `SettingsModule` (default `true`), with en «Auto-Advance» and uk «Автогортання». Monologue bubbles keep their timed lines (D178, `seconds_for`) whatever this setting says.

## 5. Less text

See [[dialogue_trim]]. Three main-route dialogues are over 6 lines, all in the Canyon: `Canyon_Intro` 7, `Canyon_StartMonologue` 7 and `RelicArmor_Examine` 7. Two sit at exactly 6: `Canyon_AbductionCutscene` and `City_MayorHall`. Each of the three has uk/en drafts (4 / 3 / 3 lines). The live text is unchanged.

## D-IDs for the register (orchestrator applies them)

| ID | Kind | Text |
|---|---|---|
| D737 | OVERRIDE (of D178 «гравець ходить» during a monologue) | **No trigger is lost to a dialogue; story dialogues hold the hero** (B154; Sapega 2026-10-26: «діалоги блокують тригери. Це не дуже, тому або менше тексту, або якось не давати пройти далі, поки іде діалог»). Any trigger the hero enters while a story dialogue runs, waits or is queued is held in `DialogueManager` and fires in entry order once no dialogue is left. That covers state/dialogue triggers, the canyon descent, the room cutscene triggers in LabCells, LabBoss and MayorHall, section fights and combat-zone text. Each trigger's own checks (`require_state`, backwards guard, state) run when it fires. Story triggers fire even if the hero has left the zone. Enter events (a section fight, combat-zone text) fire only if he is still inside, otherwise they re-arm for the next entry. Every story dialogue holds the hero for its length, with the same lock as D735, released on end or skip. That means window talks, cloud talks, replays, and now **monologue bubbles too** (D178 let him walk, which is how he walked past the next trigger while reading). E on doors and props is ignored until the talk ends. Barks and companion/NPC chatter (`say_in_passing`) never hold him and never hold back a trigger. |
| D738 | OVERRIDE (of D254 24 letters/s and D263 «набір не пропускається» in the cloud) | **Dialogue types twice as fast; a press shows the whole line** (Sapega 2026-10-26: «діалоговий текст довго викатується; при клацанні мишки треба пришвидшувати це, як при скіпі»). Default typing is `UITokens.DIALOGUE_LETTERS_PER_SECOND` = 48 letters/s, in the window and the cloud talk; Settings → Text Speed Quick = ×2 (96). In every dialogue window (D736) and now in speech bubbles that wait for input (cloud talks), a left click, Enter or pad A while a line types shows the whole line at once. The next press goes on, exactly as the skip does. Timed monologue bubbles (D178) already show the whole line. |
| D739 | OVERRIDE (supersedes B10's «no Auto button» part of D736) | **Dialogue auto-advances** (Sapega 2026-10-26: «автоматично показувати нову сторінку діалогу через 1-2 секунди»). Once a line has fully shown, the dialogue goes to the next line by itself after `clamp(length × DIALOGUE_AUTO_PER_CHAR, DIALOGUE_AUTO_MIN, DIALOGUE_AUTO_MAX)`: 0.02 s per letter, 1.5 s for 75 letters or fewer, 2.5 s cap. This applies to windows, replays and cloud talks. A press still goes on at once. A choice always waits for the player: no countdown while the choice menu is shown. It is on by default. Settings → Game → **Auto-Advance** On/Off (under Text Speed, stored with the settings as `auto_advance`). It is a setting, not an in-box Auto button, so Figma `npc-dialog-simple 36:6` still has no Auto/Skip buttons. The setting row is a GAP to that frame (Settings `17:632` has no such row). |

## B row (for BUGS.md, fixed)

| ID | Sev | Where | Text | Status |
|---|---|---|---|---|
| B154 | P1 | `Scripts/Gameplay/StateChangeTrigger.gd`, `Scripts/Gameplay/Scenes/Canyon.gd`, `Scripts/Systems/DialogueManager.gd` | Triggers were lost or misfired while a dialogue ran. A monologue let the hero walk on into the next trigger. The trigger changed the state mid-dialogue, its `require_state` was checked against the old state and dropped (the hero standing in the zone never re-entered), and in Canyon the new state's dialogue was discarded as «вже програється інший». Fights, combat text and room cutscenes started on top of the dialogue, and E on a door teleported mid-talk. Sapega 2026-10-26: «діалоги блокують тригери». | ✅ fixed in `cloud/dialogue-triggers` (D737); `verify_dialogue_triggers` [1], [1b], [2] written, not run |

## Tests

- New `SampleProject/UI/verify_dialogue_triggers.gd`:
  - [1] Two triggers are entered during a window talk (one of them twice). Nothing fires mid-talk; afterwards both fire, in entry order and one after another.
  - [1b] Enter events after the talk: still inside → fires; outside → re-armed.
  - [2] The window and a monologue both hold the hero; a bark does not, and a trigger during a bark fires at once.
  - [3] 48 letters/s. Left click, Enter and pad A complete a typing line; the next press goes on. A click completes a cloud-talk line.
  - [4] A typed line goes on by itself after its pause and not before half of it. Auto-Advance Off waits. The line before a choice goes on to the choice, and the choice waits.
- Changed: `verify_settings` (48/96 letters/s through the token; Auto-Advance row, default On, Off stored). `verify_canyon_exit` [cloud talk]: «Enter while the line types does nothing» becomes «shows the whole line» (D738).
- **For integrator, run first:** `verify_dialogue_triggers`, `verify_settings`, `verify_canyon_exit`, `verify_cutscene`, `verify_dialogue_speaker`, `verify_npc_flow`, `verify_npc_chatter`, `verify_npc_recall`, `verify_starter_loot`, `verify_desert_road`, `verify_city_gates_raid`, `verify_village_fight`, `verify_lab_cells`, `verify_lab_boss`, `verify_mayor_hall`, `verify_locale`, then `Scripts/Tools/run_verify.sh | grep -v '^PASS'`.
- **Risks to watch in those runs:**
  - A test that keeps a dialogue window open for more than 1.5 s without pressing, and expects it to stay open, will now see it auto-advance. Turn `auto_advance` off in that test or press sooner.
  - A test that walks the hero during a monologue (D178) now finds him held.
  - A test that presses E at a door during a talk finds it ignored.
- **RESULT lines:** none. Godot could not be started in this session.

## Files

- Changed:
  - `Scripts/Systems/DialogueManager.gd` (gate, monologue hold, `_press_bubble`, cloud auto-advance)
  - `Scripts/UI/GameDialogueBox.gd` (token speed, auto-advance)
  - `UI/Components/speech_bubble.gd` (`is_typing`, `finish_typing`)
  - `UI/Tokens/UITokens.gd` (`DIALOGUE_LETTERS_PER_SECOND`, `DIALOGUE_AUTO_*`)
  - `Scripts/Systems/Save/Modules/SettingsModule.gd` (`auto_advance`), `Scripts/Menus/Game/options_component.gd` (row)
  - `Resources/Translations/{en,uk}.po`, `Resources/Dialogue/dialogue_box_settings.tres` (48)
  - `Scripts/Gameplay/StateChangeTrigger.gd`, `CanyonExitTrigger.gd`, `RoomEnemySpawner.gd`, `CombatZone.gd`
  - `Scripts/Gameplay/Components/InteractableComponent.gd`, `Scripts/Player.gd`
  - `Scripts/Gameplay/Scenes/{Canyon,LabCells,LabBoss,MayorHall}.gd`
  - `UI/verify_settings.gd`, `UI/verify_canyon_exit.gd`
- New: `UI/verify_dialogue_triggers.gd`, `design/dialogue_trim.md`.
- Not touched: `SampleProject/Maps/*`, `playthrough.gd`, and the registers (BUGS / decision register / BACKLOG / remaining_work), per ROUTINE_RULES.
