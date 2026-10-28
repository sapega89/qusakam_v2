---
type: report
tags: [cloud, routines]
---

# cloud/small-fixes

**Summary.** Branched from `origin/cloud/ui-bugs-205-206`.
- **B196 fixed** (D-sf1): `modal_layer.tscn` layer 20 → 96, so the «Your Skills» window covers «Hold Tab to skip» (95). `verify_starting_skills` [3] fails without it.
- **A14 wired** (D-sf2): Astrit's drop plays her 12-frame `enter` (`CompanionAssist.animate_drop`); Urizen's drop still holds frame 0. Covered by `verify_companions` [5]/[6].
- **Q123 done** (D-sf3): the MetSys orb is removed with its hidden HUD counter, `Objects/Collectible.tscn` and `EnemyWithCollectibleDrop.gd`.
- **B124 still open (needs art)**: the sword is baked into the hero's frames, so code can't fix it. The ComfyUI frame list is below.
- **B110 partly fixed, row still open**: air/block/hurt are drawn, wired and tested (`81c0a3d9`, `verify_bow` [1]). Roll and the fire/storm casts still need frames (list below).
- Full suite: `SUITE: 3 FAIL in 19 min 55 s, J=4`. All 3 (`verify_difficulty`, `verify_lab_boss`, `verify_camera_transitions`) fail identically on the base `origin/cloud/ui-bugs-205-206`, so none comes from this branch.

## D-IDs (placeholders, for the orchestrator)
- **D-sf1** — The modal layer (`Scenes/UI/modal_layer.tscn`) is CanvasLayer **96**, not 20. A window the game pauses for sits above every in-world overlay (hurt vignette 90, `ScreenFade` 90, cutscene skip prompt 95). It stays below dialogue and scene transitions (100), brightness (127) and the cursor (128). B196 was a layer-order bug, not a corner offset: both the prompt and the window footer belong in the bottom-right, and the window is the one the player has to answer.
- **D-sf2** — `CompanionAssist.animate_drop` (an export, set in the companion's scene): a DROP entrance plays `enter` while falling. Astrit has it on, because her `enter` is her drop from the sky (A14, 12 frames at 24 fps = 0.5 s over a 0.6 s fall). Urizen keeps it off: he falls frozen on `enter` frame 0, as before.
- **D-sf3** — Q123 «Delete with its leftovers» applied: `Sprites/Collectible.png(.import)`, `Objects/Collectible.tscn`, `Scripts/Gameplay/EnemyWithCollectibleDrop.gd(.uid)` (no scene used it), the hidden `UI/HBoxContainer` (TextureRect + `CollectibleCount`) in `Game.tscn`, and `Game.gd`'s `collectibles` counter with its `collectible_count` key in the MetSys save. Old saves still carry that key; it is simply not read. `Extensions/ModernMap/` (a MetSys extension overlay, excluded from both export presets) still refers to the png and is left as is.

## B rows
- **B196** — fixed (D-sf1). Remove the row.
- **B124** — stays open; the cause is confirmed (below).
- **B110** — stays open; narrow it to the poses below.

## 1. B196
- Before, the modal layer was 20 and `cutscene_skip_prompt.tscn` was 95, so the prompt was drawn over any paused window, including the «Your Skills» footer at the summit meditation (`design/shots/starting_skills.png`).
- `SampleProject/Scenes/UI/modal_layer.tscn:8` is now `layer = 96`. I checked every other layer: UI 12, shops 13, Game Over 14, vignette/fade 90, skip 95, dialogue/transition 100, brightness 127, cursor 128. Nothing between 20 and 96 had to stay above modals. `verify_settings` (brightness above 100) and `verify_canyon_exit` (dialogue above fade) are unaffected.
- `verify_starting_skills` [3] adds two checks: «the cutscene's skip prompt is up behind the window» and «B196: the window covers the skip prompt». Before the fix: `RESULT: 1 FAIL: B196: the window covers the skip prompt (modal layer 20, skip 95)`. After: `RESULT: ALL PASS`.
- Not changed: the skip prompt is `process_mode = ALWAYS`, so holding Tab while the window is open still skips the cutscene behind it. That is behaviour, not this layout bug. If Sapega wants it stopped, it needs its own B row.

## 2. Astrit's drop (A14)
- In `SampleProject/Scripts/Gameplay/Characters/Companions/CompanionAssist.gd`, `_enter` pauses the sprite only when `not animate_drop`. The `animate_drop = true` line is in `Scenes/Characters/Companions/companion_astrit.tscn`.
- `verify_companions` has a new helper, `_enter_frames()`, that samples the animation and frames during the `enter` phase.
  - [5] «her drop plays her enter animation»: `[&"enter"]`, frames 0–11.
  - [6] «his drop stays on the first enter frame»: `[&"enter"]`, frames `[0]`.
  - With the tscn line removed, [5] fails (frames `[0]`). `RESULT: ALL PASS`.

## 3. Q123
- I grepped `.gd`, `.tscn`, `.tres`, `.cfg`, `.godot`, `.json`, `.md` and `.py` for `Collectible`, its uid `wiq0mic5m6is`, `c8j6i3fx8p758`, `EnemyWithCollectibleDrop` and `EnemyCollectible`. Outside `Extensions/` and `design/`, the only hits were the files removed here. `Coin.gd` (group `collectibles`) and the MetSys addon's own `Collectible` symbols are different things and stay.
- `design/scene_inventory.md:91` is marked removed.
- `verify_scripts_compile`, `verify_save_load_room`: `RESULT: ALL PASS`.

## 4. B124 and B110: frames for the ComfyUI lane
**B124 (sword).** The sword is drawn into the hero's frames (`Player.tscn` library `sword`), and `WeaponView` hides its overlay while those frames play. So no fist point fixes this. Looking at the frames (sheet: 2× of every folder, 5× crops):
- **Near hand, sword forward:** `CombatIdle/1–4`, `Attack1/1–3`, `Attack2/1–3`, `Attack3/1–3`, `Heavy/1–3` and `Block/1` (17 frames). This matches the README («held in the near hand»).
- **Wrong hand:** in `Run/1–7`, `Air/1–3` and `Hurt/1` (11 frames) the near fist is forward and empty, and the sword hangs low from the far hand at the hip.
- **Regenerate** with `comfy_sprite.py hero_weapon_sword`, then run `weapon_key_fixups.py`:
  - `sword/Run/1–7` — the artist's `Run/1,3–8` with the sword in the **near (front) fist, raised forward and up as in `CombatIdle/1`**, nothing in the far hand.
  - `sword/Air/1–3` (from `Jump/2`, `Jump/3`, `Fall/2`) — the same grip.
  - `sword/Hurt/1` — the near hand thrown back and holding the sword low.
  - Keep cell 96×96, feet row 88, and the run bounce 88–90.
- **Other weapons:** the dagger, dual, mace runs and airs hold the weapon in the forward fist, so no drift. In `halberd/Run/1` the pole is held over the shoulder with the forward fist empty. That may be a two-handed carry; the art lane should decide.

**B110 (bow).** Air (Jump/Apex/Fall/Land), Block and Hurt are drawn and wired (`81c0a3d9`, checked in `verify_bow` [1]). The bow still disappears in:
- `bow/Roll/1–3`, from `Sprites/Player/Dash/1–3`, which the `Roll` animation plays: the bow in the far hand, tucked along the back while he rolls. `WeaponView` hides overlay weapons in a roll, but drawn-in frames would show.
- `bow/CastFire/1–2` and `bow/CastStorm/1–2`, from `Sprites/Player/CastFire/1–2` and `CastStorm/1–2`: the bow in the far hand, lowered. The bow has no overlay sprite (`DRAWN_ONLY`, D385), so a cast with the bow equipped shows no bow at all.
- Wiring once the frames exist: add `Roll`, `CastFireWindup`/`CastFireRelease` and `CastStormWindup`/`CastStormRelease` to `AnimationLibrary_bow`, with the base animations' lengths and offset (0, −16), and extend the name list in `verify_bow` [1]. `Player.body_animation()` already picks up `bow/<base>` when it exists.

## Tests
- `verify_starting_skills`, `verify_companions`, `verify_scripts_compile`, `verify_save_load_room`, `verify_bow`: all `RESULT: ALL PASS`.
- Full suite: `SUITE: 3 FAIL in 19 min 55 s, J=4`. Each failure was re-run on a worktree of the base `origin/cloud/ui-bugs-205-206` and failed the same way there:
  - `verify_difficulty` (17 FAIL): balance bands, e.g. «scorpion L9 at level 9: 4 hits kill the hero ([5, 6])», «Mercenary [DRAFT] at level 12: 3 hits kill the hero ([3, 4]), 32 hits kill it ([34, 46])», elites at levels 3–4 «loses».
  - `verify_lab_boss` (2 FAIL): «balanced build: he dies in 2.3 of the mercenary's blows», «the mercenary takes 67 light hits».
  - `verify_camera_transitions` (1 FAIL): «reaching the right limit it slows down, no hard stop (biggest one-frame drop 6.75 px)».
  - These are balance and camera numbers from earlier branches, not touched here.
