---
type: plan
status: active
tags: [onboarding, tutorial, combat, feedback]
---

# Onboarding — the game teaches itself, combat first (BACKLOG 28)

Sapega 2026-10-21: «треба робити акцент на битві і тому, щоб було зрозуміло що і як — є на роботі хлопці, які не
зрозуміли, як грати в гру, значить вона недостатньо пояснила». Addition the same day: «в туторіалах, які вискакують,
не вистачає картинок, щоб наглядно було видно, що робити, не тільки читати».
Queue row 8e ([[play_feedback_queue]]). Builds on D289 (hints open tutorial windows), D264/D265 (souls-lite combat,
the red glint tell), D252 (Healing Palm at level 2), D270 (combat input). Figma: no frame for lessons or a controls
list; the tutorial window is Figma `tutorial-content 135:1260` (D126) and keeps its layout.
Decisions this pass makes: **D-28a…D-28i** below (agent calls, Sapega to confirm; the orchestrator registers them).

## The first ten minutes as a new player (before this pass)

| # | Moment | The player must know | Taught today | Gap |
|---|---|---|---|---|
| 1 | New Game → Canyon intro talk | advance a line (Enter / A) | nothing — the box has no prompt besides typing | small: the box's own `▼` cue |
| 2 | Canyon, 2 s in | move, jump, dash | `movement` window (D289) | ok |
| 3 | Canyon exploration → meditation → raid | where to go | objective plaque "Explore the Canyon", "Pursue the kidnappers" | no direction; objective words only |
| 4 | Village arrival | walk to the centre | "Reach the village center" | ok (one way) |
| 5 | **Street fight, one bandit — the first enemy of the game** | attack, combo, dodge, block, parry the glint, heavy | `attack` window on spawn; `block` window only **after the first hit taken**; `heavy_attack` window on the **second kill** (there is only one enemy here, so the first heavy lesson comes on DesertRoad) | **the core gap**: one window of text, then a real fight; parry and dodge never explained in a fight, nothing asks the player to try a move |
| 6 | After the fight | XP and coins | `first_kill` window | ok |
| 7 | The old man, his gift | equip the sword, switch weapons | `oldman_gift` sticky banner until equipped | ok |
| 8 | Back to the Canyon, descent, DesertRoad fights | everything from 5 | nothing new | — |
| 9 | Level 2 on the road | learn Healing Palm, use skill slot 1 | `healing_palm` window + sticky banner until learnt | the window had no picture |
| 10 | City Gates raid | call a companion (F / LT) | `call_guard` window + sticky | the window had no picture |
| 11 | Menus: inventory, skills, journal, oath | open the game menu (Esc / Start) | general topics in Misc → Tutorial; `level_up` window | **no list of all controls** — Settings → Controls is a rebinding table that misses the pad column, `heavy_attack`, `block`, `cutscene_skip`, and lists debug actions (Save Delete, Menu Next Tab) |

Every window was text only (only four general topics carried a still screenshot).

## What exists and is reused

| Thing | Where |
|---|---|
| Tutorial window with a picture slot and a button badge | `Scenes/Menus/Game/tutorial_menu.tscn` (`ShotFrame/Shot`, `HintBar/KeyBadge`), `Scripts/Menus/Game/tutorial_menu.gd` |
| Topics, texts with `{action}` glyphs by device | `Resources/Data/tutorial.json`, `Scripts/UI/tutorial_topics.gd`, `Scripts/UI/input_glyphs.gd` |
| First appearance → window, then sticky banner; `force_hide()` when done | `Scripts/UI/TutorialHintDisplay.gd` (D289) |
| Combat events | `EventBus.player_parried`, `player_blocked`, `player_heavy_windup`; `PlayerCombat.combo_step`, `state`; `PlayerMover.is_rolling()`; `DefaultEnemy.hitbox.monitoring` (strike live) |
| The bandit fight | `Scripts/Gameplay/Scenes/Village.gd` `STREET_FIGHT`, `RoomEnemySpawner` |
| Game Menu panels, Misc rows | `Scenes/Menus/Game/game_menu.tscn` `ContentRoot`, `misc_menu_modal.tscn` |

## Decisions (agent calls, Sapega to confirm)

- **D-28a — Where the lessons are.** The Village street fight: it is the first enemy of the game, on the story path
  everyone walks, and one bandit is a calm partner. The Canyon stays move / jump / dash only (Sapega: no enemies
  there). No separate training dummy: a dummy does not swing, and dodge / block / parry need a real swing with the glint.
- **D-28b — The lesson order and what counts as done.** Six lessons, each waits until done, in this order:
  1 *Attack* — a light hit lands on the bandit; 2 *Combo* — the third swing of a chain (the finisher) lands;
  3 *Dodge* — the hero is mid-dash (`dodge`) at the moment a bandit swing is live within 160 px (dashing through or
  away from it both count); 4 *Block* — a bandit hit lands on a held block (`EventBus.player_blocked`; a parry counts
  too, it is a perfect block); 5 *Parry* — `EventBus.player_parried`; 6 *Heavy* — a heavy strike lands
  (`PlayerCombat.State.HEAVY_STRIKE`). Then "Finish him!" and the fight ends as before (bandit dead →
  `village_fight_complete`).
- **D-28c — The fight is safe while learning.** During the lessons the bandit cannot die (back to full when below
  40 %) and neither can the hero (healed to full when below 40 %); both stop the moment the last lesson is done.
  The heal comes after a blow, so health also has a floor of 1 during the lessons (`CombatBody2D.min_health`):
  without it the 3-hit finisher from 45 % killed the bandit in the middle of a lesson (found by the verify).
  The bandit keeps his real wind-ups, glint and damage — the lesson is the real fight, only without losing.
- **D-28d — How a lesson is shown.** Each lesson is a tutorial topic (`lesson_*` in `tutorial.json`, «Training N/6 —
  …», button by device). Its first appearance opens the tutorial window (D289) with a looping picture of the move;
  after the window, the same text stays as a sticky banner until the move is done. Settings → Tutorial Windows Off:
  banners only. The lesson topics stay in Misc → Tutorial for later. The general `attack` / `block` /
  `heavy_attack` hints are marked seen when the training starts, so they do not pop up in the middle of it.
  Resuming the fight after leaving the Village starts the training again from lesson 1 (it is short).
- **D-28e — Pictures in tutorial windows are recorded from the game.** A capture script plays each move in a window
  (`SampleProject/UI/capture_tutorial_frames.gd`) and saves 8–12 frames, 500×240 crops around the hero (the
  `ShotFrame` 1000×480 at 2×), into `SampleProject/Assets/UI/Tutorial/<set>/0.png…`; the window loops them at
  10 fps. A topic names its set with `"frames"` in `tutorial.json`. The existing folder `Assets/UI/Tutorial/` is used
  (not a second `Tutorials/` folder next to it). Sets: `move_jump`, `combo`, `dodge`, `block`, `parry` (the red glint
  and the parry sparks), `heavy`, `heal`, `assist`. The button badge next to the picture already names the button for
  the current device (`HintBar/KeyBadge`) — text glyphs, no pad icon art (none in the project).
- **D-28f — The Controls page.** Misc → **Controls** (a new row between Settings and Tutorial) opens a read-only list
  in the Game Menu centre panel, like Tutorial: every player action in play order with a **Keyboard / Mouse** and a
  **Gamepad** column, names from `InputGlyphs` (so rebinding in Settings → Controls shows up here). Rebinding stays in
  Settings. Styles from the existing theme variations (`SettingsHeading`, `SettingsEyebrow`, `FrameRule`, `ListRow`,
  `KeyBadge`); no theme regeneration.
- **D-28g — No skip for the training.** Six lessons take about a minute for someone who knows the moves; a skip
  is easy to add later (hold `cutscene_skip`) if Sapega wants it.
- **D-28h — Where to go next (amended by the cloud pass: the arrow is built).** The quest plaque (top centre,
  `combat_hud_top` → `QuestPanel`) shows an arrow `← → ↑ ↓` after the objective text, pointing from the hero at the
  objective's marker; it hides within 96 px of it. `Game.set_objective(text, target)` names a marker
  `ObjectiveTargets/<id>` in the room scene; a goal in another room is a marker with the same id at the edge that
  leads there (`canyon_bridge`: Village west edge → the Canyon bridge; `city_gates`: DesertRoad east edge → the
  raid trigger). Fights, talks and cutscenes have no arrow. The markers: Canyon `shrine` (meditation seat),
  `village` (east gate), `canyon_bridge`; Village `village_center`, `house`, `old_man`, `canyon_bridge`;
  DesertRoad `city_gates`; CityGates `city_gates`, `city` (the gate passage). "Pursue the kidnappers" points at the
  village gate directly, so the one-line RoadToVillage monologue (trigger by the bridge) may be skipped.
- **D-28i — Previous weapon on the keyboard.** `weapon_prev` had only D-pad ←; it gets **Z** (`CombatInput.gd`,
  next to Q for the next weapon). Found by the Controls page check.

## Slices

Status after the cloud pass (2026-10-21, `cloud/onboarding`): slices 1–5 built and verified
(`verify_onboarding.gd` ALL PASS); report in [[cloud_reports/onboarding]].

### Slice 1 — the plan — ✅
This note.

### Slice 2 — the six lessons in the street fight — ✅
- `Scripts/Gameplay/CombatTraining.gd` (new, a child node Village adds for the fight): lesson list, done-checks
  (D-28b), safety (D-28c), banners (D-28d), signal `finished`.
- `Village.gd` `_start_fight` → training first, then "Finish him!"; `tutorial.json` six `lesson_*` topics.
- Test: `verify_onboarding.gd` — each lesson blocks until done, the wrong move does not advance it, each completes
  with the real keyboard key **and** with the real pad button (`Input.parse_input_event` of `InputEventKey` /
  `InputEventMouseButton` / `InputEventJoypadButton`), the bandit and the hero survive the lessons, the bandit can be
  killed after.

### Slice 3 — moving pictures in the tutorial window — ✅
- `tutorial_menu.gd` plays `"frames"`; `capture_tutorial_frames.gd` writes the eight sets; `tutorial.json` names them.
- Test: `verify_onboarding.gd` — every topic with `"frames"` has ≥ 6 frames on disk, the window opened on it shows
  them and the texture changes over time.

### Slice 4 — the Controls page — ✅
- `Scenes/Menus/Game/controls_component.tscn` + `Scripts/Menus/Game/controls_component.gd`; Misc row; `game_menu.gd`
  `open_controls()`; `input_glyphs.gd` names for a chosen device.
- Test: `verify_onboarding.gd` — reached by real input (Misc → Controls), every gameplay action has a keyboard and a
  pad name.

### Slice 5 — waypoint arrow — ✅ (D-28h amended)
- `Game.set_objective(text, target)`, `Game.objective_marker()`; `combat_hud_top` `%Direction`; markers in the four
  early rooms. Test: `verify_onboarding.gd` [7] — every early objective names a marker that exists in its room (or
  is a fight / talk / cutscene), the arrow flips with the hero's side and hides on arrival.

## Playtest checklist for Sapega's coworkers

Hand them the controller (or keyboard) and a new game. Say nothing about the controls. Watch, take notes, ask after.

**Watch (write down the minute):**
1. Do they find how to advance the first dialogue line? How long does it take?
2. In the Canyon: do they jump and dash without being told twice? Do they read the movement window or close it at once?
3. Do they know where to go after the meditation (objective plaque top centre, the arrow after its text)? Where did
   they stop and look around? Did anyone follow the arrow into a wall (a ledge, a closed gate)?
4. The street fight: for each lesson — how many tries until it counts? Which lesson took longest? Did anyone get
   stuck on *Dodge* or *Parry* (the red glint)?
5. After the lessons, on DesertRoad: do they still block / parry / dodge on their own, or only mash attack?
6. Level 2: do they find Skills and learn Healing Palm from the hint? Do they use it in a fight?
7. City Gates: do they call the guard (F / LT)?
8. Do they ever open Misc → Controls or Misc → Tutorial on their own?
9. Keyboard vs pad: did any button name shown on screen not match the device in their hands?

**Ask after (short answers):**
1. What does the red glint on an enemy's weapon mean?
2. What is the difference between holding block and tapping it?
3. Which move did you not understand or never use?
4. Was there a moment you did not know where to go? Where?
5. Were the tutorial pictures helpful, or did you skip them? Too many windows?
6. Did you notice the arrow on the objective plaque? Did it help or mislead?
7. Anything you tried to press that did nothing?

Bring the answers back as BACKLOG notes; a confusion that repeats in two people is a B-ID or a new lesson.

## Out of scope for this pass

- Lessons for skills beyond Healing Palm, the oath, companions beyond the guard — the existing windows cover them,
  now with pictures where they are moves.
- Pad button icons (art); localisation of lesson texts (BACKLOG 31 does all texts).
