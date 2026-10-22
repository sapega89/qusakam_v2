---
type: report
tags: [cloud, queue-9.8]
---

# Cloud report — queue row 9.8, the demo end, the full Lab route, boss voices (`cloud/lab-9-8`)

Branch `cloud/lab-9-8` off `origin/cloud/integration` (479183e4) + `origin/feature/backlog` merged. `cloud/lab-9-5`,
`-9-6` and `-9-7` were already in that base, so nothing else was merged. Godot 4.6.2 ran headless here. There is no
display, so there are no captures and no listening test. Nothing from the do-not-commit list was committed
(project.godot, MainMenu.tscn, GameUITheme.tres, playthrough.gd). Nothing went into BUGS / BACKLOG / the queue / the
decision register. Plan note: `design/lab_story_plan.md` → *Built — slices 9–10*.

## What was built

| What | Where |
|---|---|
| **Demo end, checked, no code change.** `Laboratory_Outside` and `Demo_End` play once each (`lab_outside_complete`, `demo_end_complete`). Every later entry goes straight to the demo end screen, and only one screen shows. The B66 fix (the "already read" branch moves on) holds. The room does not read `lab_after_boss_complete`, because the raised gates are the only way in | `SampleProject/Scripts/Gameplay/Scenes/LaboratoryOutside.gd:39` |
| **`verify_lab_route.gd`**: the whole route with real input, keyboard and gamepad mixed (76 checks, below) | `SampleProject/UI/verify_lab_route.gd` |
| Boss voices are looked up per boss: `boss_voices` maps an enemy_type to `{roar, shout, death}` | `SampleProject/Resources/Data/sound_events.json` (`boss_voices`), `SampleProject/Scripts/Systems/AudioManager.gd:94` `boss_voice()` |
| SoundHooks plays the boss's own events. The swing rule is unchanged: a roar on the first swing, a shout on every second swing after it, the death sound on the killing blow | `SampleProject/Scripts/Systems/SoundHooks.gd:67`, `:78`, `:97` |
| `Cutscene.voice(event)`: a voice that belongs to the scene. It stays silent once the player holds skip | `SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd:77`, `skipping` at `:31`, set in `_skip()` |
| Scene voices: the Brass Collector roars as it climbs out of the wall | `SampleProject/Scripts/Gameplay/Scenes/MayorHall.gd:81` |
| The prisoner's incantation at his shout; the djinn laughs as it rises out of him | `SampleProject/Scripts/Gameplay/Scenes/LabCells.gd:110`, `:124` |
| The djinn laughs as it floats over to take the cloak | `SampleProject/Scripts/Gameplay/Scenes/LabBoss.gd:127` |
| New voice files, made with **Kokoro-82M** (Apache 2.0) through kokoro-onnx 0.4 in a venv in /tmp. The model files came from the kokoro-onnx `model-files-v1.0` release: `Boss/brass_collector_roar_0..2`, `Boss/fire_djinn_roar_0..2`, `Boss/fire_djinn_laugh_0..1`, `Lab/prisoner_incantation_0` | `SampleProject/Assets/Audio/Voice/Boss/`, `.../Voice/Lab/` |
| `make_voices.py` takes LINES names and rebuilds only those lines, without cutting any recordings. It has the four new LINES and a `clank` post-effect (70 Hz ring modulation + a 4 ms comb) for the golem | `Scripts/Tools/audio/make_voices.py:51`, `:64`, `:123` |
| The Voice README (sources, voices, Steam AI disclosure) and the audio plan's event table were updated | `SampleProject/Assets/Audio/Voice/README.md`, `design/audio_plan.md:79` |
| `verify_audio` [5]: uses both real boss scenes (not a grunt put into the `boss` group), checks each boss's own roar / shout / death, and checks that a cutscene voice plays but stays silent under a skip | `SampleProject/UI/verify_audio.gd:403` |
| **Fix:** the world interaction prompt now reads the shared `InputGlyphs.using_gamepad` and redraws on `input_device_changed` | `SampleProject/UI/Components/interaction_prompt.gd:55`; `verify_interaction` [3] has a new check |
| **Fix:** the top HUD connects `process_frame` only while it is in the tree | `SampleProject/UI/Components/combat_hud_top.gd:41` |

Command used for the voices (run it from the repo; `-I` cannot be used because the script imports `build_audio` from its
own folder):
`python Scripts/Tools/audio/make_voices.py <dl> <repo> kokoro-v1.0.onnx voices-v1.0.bin Boss/brass_collector_roar Boss/fire_djinn_roar Boss/fire_djinn_laugh Lab/prisoner_incantation`

### What `verify_lab_route` checks, with real input

1. **Mayor Hall.** A save at the hall door (test-only: the hall has no save point). Win: a real `move_right` starts
   the queue, pad Y skips (the prompt reads "Hold Y to skip"), and the last blow is a real `attack`. Then
   `MayorHall_Victory` → LabCells, the cutscene starts, and pad Y skips it to AWAKE. Lose, from the same save: the
   hall loads at the door (QUEUE), a real `move_right`, Tab skips (the prompt reads "Hold Tab to skip"), the boss
   wins → `MayorHall_Defeat`, no Game Over → the same cells cutscene. Both runs set `city_mayor_hall_complete`. Only
   the win sets `mayor_boss_defeated`. The hero who lost is back on his feet.
2. **Cells.** Pad Y skips the cutscene, and all six cells talks run under the skip. A save, then a load: AWAKE, no
   cutscene replay, the hero in his cell. The left stick walks out → ACQUAINTANCE. Pad A reads `Lab_Acquaintance` +
   `Lab_Malik_Quest` → FREE, three assists, `task_malik_escort_taken`. The stick walks east into the corridors.
3. **Corridors.** The `SavePoint_Entrance` prompt shows the pad badge. Three storeys by stick, A to jump and the D-pad
   down the ladders. At `SavePoint_PreBoss`, pad Y opens the save screen and pad A saves into the slot. The load lands
   at PreBoss: Upper and Middle stay won, Lower waits. Lower is fought → `lab_corridors_complete`, and a second pad
   save at PreBoss.
4. **Djinn, lost.** The stick walks into the hall, the talk starts, and pad Y skips it to FIGHT. The djinn wins →
   CLOAK → `Lab_Boss_TakesCloak` (pad A) → the normal Game Over, paused, with Resume focused. Pad A on Resume loads the
   last save: back in the corridors, the corridors done, the djinn not met.
5. **Djinn, won.** The stick walks back in, and the talk plays again (it was not in the save). Tab skips it, and the
   last blow is a real `attack`. `Laboratory_AfterBoss` (pad A) → OPEN, the gates up, the objective "Leave the
   laboratory". The stick walks east → LaboratoryOutside. Pad A reads `Laboratory_Outside` and `Demo_End`, once each.
   Both flags are set, one demo end screen shows, and Return has focus.
6. **B66.** Back west into the open hall: no talk, no lock. East again: the demo end screen again (one), and the closing
   talks do not replay. Pad A on Return → `MainMenu.tscn`.

## Decisions — ready to paste (agent call, Sapega to confirm)

> **D310 — boss voices, cutscene voices, the demo end and the full Lab route (queue row 9.8)** — *agent call, Sapega to
> confirm.* Each boss has its own voice, looked up by its enemy_type in `sound_events.json → boss_voices`
> (`{roar, shout, death}`), and SoundHooks keeps the D278 timing. **The Brass Collector** roars with Kokoro roars
> (am_onyx, pitched ×0.62, ring-modulated at 70 Hz with a short metal comb so it sounds like a golem), picked at random
> along with the three old CC0 roars. It keeps the shared Kokoro shouts and the CC0 death roar. **The fire djinn** roars
> with its own Kokoro roars (am_fenrir ×0.7 + hall reverb), laughs (×0.8) instead of shouting, and uses the shared death
> roar. The old `boss_roar` event is folded into the Brass Collector's roar. **Scene voices** go through
> `Cutscene.voice`, which says nothing once the player holds skip: the collector roars as it climbs out of the wall, the
> prisoner shouts his invented incantation (Q64 words "Varra-khess um-tal! Shakraz-idoon! Tahmi-rakh ash-zarra!",
> am_adam ×0.9 + reverb) at his shout pose, and the djinn laughs as it rises out of him and as it comes to take the
> cloak. **The demo end** stays as built: each closing talk plays once, every later entry shows the one demo end
> screen, and Return (focused, pad A / Enter) goes to the main menu. **Resume after the cloak Game Over** loads the last
> manual save. There is no save point in the boss hall, so that is `SavePoint_PreBoss`, and the djinn's talk plays
> again on the next try. That is deliberate: no auto-save is added.

## Bugs

> **B-? — world interaction prompts show the keyboard badge to a pad player after a room change** — *Where:*
> `SampleProject/UI/Components/interaction_prompt.gd` (its own `static var _using_gamepad`). *Expected:* the
> `[Y] Save` badge whenever the last input was the pad. *Got:* the flag only changed in a prompt's `_input`, and only
> while a prompt was in the tree. A player who walked by stick into a new room (the stick held, no new event) saw `[E]`
> at the first save point. *Fix (done):* read `InputGlyphs.using_gamepad` (fed by InputDeviceWatcher) and redraw on
> `EventBus.input_device_changed`. *Severity:* minor (BACKLOG 24 parity).

> **B-? — SCRIPT ERROR in the top HUD on every scene change from the game** — *Where:*
> `SampleProject/UI/Components/combat_hud_top.gd` `_on_frame`. *Expected:* a clean change of scene. *Got:* "Invalid
> access to property 'paused' on a null instance" (`get_tree()` is null). The HUD stayed connected to
> `process_frame` after it left the tree, which happens on "Resume from last save" on the Game Over screen and on
> Return to menu from the demo end. *Fix (done):* connect in `_enter_tree`, disconnect in `_exit_tree`.
> *Severity:* minor (log noise; it would fail a verify that greps SCRIPT ERROR).

Not new: the `.sh` exec bits from the 9.7 report are fixed in git for `godot_locked.sh` and `run_verify.sh`.
`playthrough.sh` is still 100644. I left it alone because it is on the do-not-touch list next to `playthrough.gd`.

## Verifies run (RESULT lines)

| Verify | RESULT |
|---|---|
| `verify_lab_route` (new, 76 checks) | `RESULT: ALL PASS` |
| `verify_audio` (updated [5]) | `RESULT: ALL PASS` |
| `verify_interaction` (updated [3]) | `RESULT: ALL PASS` |
| `verify_demo_end`, `verify_lab_boss`, `verify_mayor_hall`, `verify_lab_cells`, `verify_laboratory` (before the change, as a baseline) | `RESULT: ALL PASS` each |
| Full suite `Scripts/Tools/run_verify.sh` | `SUITE: 2 FAIL` — 84 verifies, 82 PASS. The 2 FAILs are pre-existing: `verify_game_ui_theme` prints no RESULT line, as in integration-1/2/3 (D329: `GameUITheme.tres` has to be regenerated, and it is on the do-not-commit list). `verify_audio` failed "focusing a button (pad navigation) ticks on SFX", the known flake **B94**; re-run alone right after, it gave `RESULT: ALL PASS`. Every Lab verify passed in the suite, `verify_lab_route` included |

## What is left

- **Registers (Sapega / the integration run):** D310 into `figma_decision_register.md`; the two B-IDs into `BUGS.md`
  (both already fixed); queue row 9.8 struck through; BACKLOG 6/16/17/23 marked done. I could not do these: the
  register files are off-limits to this row.
- **Listening check:** the new voices were never played to a human here. Check the roars' length (2.4–4.5 s including
  the reverb tail), that the clank sounds metallic rather than robotic, and that the laugh reads as a laugh.
  Re-generate with the command above after tuning LINES / `clank`.
- **Captures `fb17_*` + sheet** need a display (`capture_lab_rooms.gd`). They were not taken here.
- **Exe rebuild** (`--export-release`) was not done here: it is not in this task, and there are no export templates in
  the container.
- The pad assist (RT) in the Lab is checked by action in `verify_lab_boss` / `verify_laboratory` (F key), not by the RT
  axis.
