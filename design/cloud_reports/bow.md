---
type: cloud-report
branch: cloud/bow
date: 2026-10-22
tags: [cloud, combat, ranged, enemies]
---

# Cloud report: bow (BACKLOG 40 — the hero's bow like Skul, the desert archer)

Start: `origin/cloud/integration`, then `origin/feature/backlog` merged in (a fast-forward; it brought art **A4** —
commit `87c56f92`: `Sprites/Player/Weapons/bow/`, `Assets/FX/Projectiles/arrow*.png`,
`Assets/Characters/Enemies/bandit_archer/sheet.png`). Godot 4.6.2 on Linux; tests headless, captures under Xvfb.
Figma: none (combat is not a UI screen). No questions were asked — every call is a D-ID below for Sapega to confirm.

Plan first: [[ranged_plan]] (new, linked from [[INDEX]]) — what exists, decisions D380–D387, slices, what is left.

## What was built

### The bow (slices 1–2)

- **Item:** `short_bow` — `Resources/Data/items.json:287` (weapon, category `bow`, `"grip": "bow"`, attack +12,
  `weapon_profile` cooldown 0.3 / knockback 0); sold by the caravan merchant in the City (`merchants.json:34`).
- **Grip `bow` next to D267:** `EquipmentManager.get_grip()` → `&"bow"` (`EquipmentManager.gd:47`); no Shield Block
  with a bow (`Player.gd:472`); no dual-wield (the bow slot is not one-handed).
- **Frames:** `Player.tscn` → `AnimationLibrary_bow` (`:1331`), mounted as `libraries/bow` (`:1427`): `Idle`
  (Shoot/2 — bow lowered at the hip), `Run` (Run/1–6), `Attack1` (quick shot: Draw/3 → Shoot/1 → Shoot/2, 0.22 s),
  `Draw` (Draw/1–3, 0.6 s), `Charged` (Charged/1–2 loop, the glow), `Release` (Shoot/1–2). 96×96 cells, every track
  keys `Sprite2D:offset` (0, −16) like the sword set. `WeaponView` uses the library for grip `bow` too
  (`FRAME_GRIPS`, `WeaponView.gd:27`, `:122`) and never shows an overlay sprite for it (`DRAWN_ONLY`, `:25`, `:107`,
  `:142`).
- **Shots** — `PlayerCombat.gd`: states `SHOOT`, `DRAW`, `CHARGED` (`:11`); quick shot on the press with the arrow at
  the `Shoot/1` frame 0.05 s later and one press buffered within the bow's tempo (`_quick_shot` `:356`, buffered shot
  fires toward the current facing `:216`); holding past the shot draws (`State.SHOOT` end `:241`, `_start_draw`
  `:382`), then charged; release → charged arrow + `Release` frames, early release lowers the bow (`release_shot`
  `:371`); heavy with a bow draws at once (`:329`); dodge cancels the draw (`cancel_draw` `:390`, `Player.gd:212`);
  arrows leave from the nocked arrowhead in the frame (`ARROW_FROM`, `_loose` `:395`). Quick shots do not root the
  hero, drawing does (`locks_movement`). `Player._unhandled_input` tracks the held button and the release
  (`Player.gd:226`, `:234`).
- **Arrows** — `Scripts/Combat/Arrow.gd` + `Scenes/Combat/arrow.tscn`, `arrow_charged.tscn` (speed 900 / 1200,
  charged `pierce`, `strength` 0 / 2 in the scenes): straight flight, 720 px range, hits the first enemy (charged:
  every enemy once) through `take_damage` with the arrow as source (`_strike` `:89`), sticks in a wall 0.6 s and fades
  (`_stick` `:106`). Poise, knockback, lifesteal / poise passives and "a shot enemy turns on the hero" go through
  `PlayerCombat.on_arrow_hit` / `_hit_effects` (`:162`, `:167` — melee hits use the same function now).
  Collision layer 0 but monitorable: in Godot 4.6 a non-monitorable Area2D never sees static bodies (walls) — found
  by `verify_bow` [5], noted in `Arrow.gd`.
- **Hit feel (D264/D268):** `VFXHooks` counts the group `hero_arrows` as a hero hit and takes the strength from the
  arrow (`VFXHooks.gd:43`, `:140`, `:147`, `:162`) — cut streak, hitstop, camera kick, flinch, rumble, hit sounds.
  Sounds `bow_draw`, `bow_shot`, `bow_shot_charged`, `arrow_wall` (existing files, `sound_events.json`) on new signals
  `EventBus.player_bow_drawn` / `player_shot` (`EventBus.gd:179`, `:181`; `SoundHooks.gd:13`).

### The desert archer (slice 3)

- `Scenes/Characters/Enemies/enemy_archer.tscn` (inherits `default_enemy.tscn`; the A4 sheet 4×5, idle / walk /
  attack 8→11 with the release on frame 11 at `attack_strike_time` 0.8, death 16–19; `tell_at` = the nocked
  arrowhead; detection 420), `Resources/Enemies/enemy_stats_archer.tres` (HP 60, damage 12, speed 60, wind-up 0.9,
  tempo 2.2, range 380, poise 2, XP 25).
- `ArcherEnemy.gd`: its logic, idle pose between shots, `start_attack` (`:36`) looses an arrow from the arrowhead
  (`EnemyView.weapon_point`, `EnemyView.gd:86` — the glint uses the same point).
- `ArcherLogic.gd`: keeps distance — closer than 170 px backs away (`RETREAT`) while there is floor and no wall behind
  and it stays inside its leash (`_can_back_away` `:58`), 170–380 px stands and shoots only at the hero's height
  ±48 px (`handle_attack_state` `:13`), farther it closes in (base `CHASE`). Every shot is the base wind-up, so the
  **red glint** flashes on the arrowhead `PARRY_WINDOW` (0.25 s) before the release (4b).
- Its arrow hits the hero through `Player.take_damage` with the arrow as source (`PlayerCombat.guard_against` `:450`,
  `Player.gd:462`): block breaks it, a parry deflects it back as the hero's arrow (`Arrow.parried` `:67`), a roll
  lets it fly through (i-frames), a jump clears it; an unguarded hit staggers 0.25 s.
- `EnemySpawnPoint` type `archer` (`EnemySpawnPoint.gd:9`, `:25`), coins 1–3 (`DefaultEnemy.gd:423`), voice pitch
  1.05, Bestiary "Desert Archer" (`bestiary.json:19`, D290).

### Placement (slice 4) and translations (slice 5)

- DesertRoad **Mesa** fight: `Fight_Mesa/EnemySpawnPoint4` fast → archer (`DesertRoad.tscn:270`) — the far end of
  the high ground.
- **City Gates** raid: `EnemySpawner/EnemySpawnPoint3` melee → archer (`CityGates.tscn:241`); its raid-cutscene figure
  `Raid/Bandits/Bandit3` uses the archer sheet (`:216`; the run / stand frames are the same cells).
- XP stays on the D297 curve: DesertRoad 625 XP (unchanged), City Gates 30 + 30 + 25 → 710, level 5 on the last kill.
- `uk.po` / `en.po` (`po_sync.py`): "Short Bow", its description, "Desert Archer", its bestiary text.

## D-IDs (agent calls, Sapega to confirm) — for `figma_decision_register.md`

- **D380 — The bow plays like Skul.** Attack fires a quick shot on the press (no wait for the release); holding the
  button past the shot draws the bow (0.6 s), then it is charged (glowing arrowhead); releasing a charged bow looses
  the charged shot, releasing earlier lowers it without a second arrow. Heavy with a bow draws at once. Arrows fly
  straight along the facing, horizontally, from the nocked arrowhead; no auto-aim, no gravity, no ammo. *Agent call,
  Sapega to confirm.*
- **D381 — Bow numbers.** Quick arrow ×0.7 physical attack, 900 px/s, light poise, light hit feel; charged ×1.8,
  1200 px/s, heavy poise, knockback 60, heavy hit feel, pierces enemies; both stick in walls, 720 px range. One shot
  per 0.3 s (the bow's cooldown), one press buffered. *Agent call, Sapega to confirm.*
- **D382 — Moving with the bow.** Quick shots never stop the hero (ground or air, like light swings D223); the draw and
  the charge root him; the dodge cancels the draw; an enemy hit staggers him out of it. *Agent call, Sapega to
  confirm.*
- **D383 — Grip `bow`.** `"grip": "bow"` in items.json → `get_grip()` = `bow`: both hands on the bow, no Shield
  Block, never dual-wield; the melee hitbox (and the skills' zone, D142) is the bare-hands one. *Agent call, Sapega to
  confirm.*
- **D384 — Heavy and block with the bow.** Heavy = the charged draw. Block and parry work as with any weapon; a parried
  archer arrow flies back as the hero's quick arrow, a blocked one breaks on the guard (0 damage, D264), a roll passes
  through it, a jump clears it. *Agent call, Sapega to confirm.*
- **D385 — Bow frames.** Library `bow` (D370 switch): `Idle` = bow lowered at the hip, `Run`, `Attack1` = quick shot,
  `Draw`, `Charged` (glow loop), `Release`; no overlay sprite for the bow — where A4 has no frames (jump, fall, block,
  hurt, roll) the base frames play without the bow (B110). *Agent call, Sapega to confirm.*
- **D386 — The desert archer.** HP 60, damage 12, XP 25, coins 1–3; keeps 170–380 px from the hero (backs away while it
  has floor and no wall behind, closes in when farther), shoots only at its own height, a 0.9 s draw with the red glint
  0.25 s before the release, one arrow every 2.2 s at 420 px/s; Bestiary "Desert Archer". *Agent call, Sapega to
  confirm.*
- **D387 — Placement and where the bow is found.** One archer replaces the last fast of the DesertRoad Mesa fight, one
  replaces the third bandit of the City Gates raid (its raid figure drawn from the archer sheet); XP keeps level 5 on
  the last gate kill. The short bow is sold by the caravan merchant in the City. *Agent call, Sapega to confirm.*

## B-IDs (for `BUGS.md`)

- **B110 — The bow vanishes outside its frames.** A4 has bow frames only for stance, run, shots, draw and charge; in
  jump / apex / fall / land, block, hurt and roll the base frames play and the hero holds no bow (`capture_bow`:
  `hero_blocks_arrow.png`). Fix: an A-batch for the bow — Air 1–3, Block, Hurt (the sword set's list) — then add them
  to `AnimationLibrary_bow`. Not a code bug: the D370 switch already falls back per animation name.
- **B111 — Enemy attack tempo ignores `EnemyStats.attack_cooldown`.** `EnemyLogic.handle_attack_state`
  (`EnemyLogic.gd:319`) compares against its own `attack_cooldown` (1.5 s) and `initialize()` never copies the stats
  value, so the fast (1.0) and every other enemy swing every 1.5 s. The archer reads `enemy.attack_cooldown`
  (`ArcherLogic.gd`, its 2.2 s tempo is real); the melee enemies were left as they are because fixing it re-tunes
  every fight (4b) — needs a call on whether the stats' tempos are wanted.

## Verifies

- `verify_bow.gd` (new, real `InputEventMouseButton` / `InputEventJoypadButton` / `InputEventKey` copied from the
  InputMap): [0] item, grip, City shop, no Shield Block, tempo; [1] the six bow animations (bow frames, 96×96, offset),
  combat stance, no overlay; [2] quick shot on mouse and pad X — arrow ~80 ms after the press, quick-shot frames, not
  rooted, from the arrowhead, straight; three taps at the tempo → three arrows; a press mid-shot buffered; running
  while shooting; [3] a hit ×0.7, stops in the first enemy, light poise, one cut, hitstop, flinch, the enemy turns on
  the hero; [4] hold → draw (rooted) → charged → release: one charged arrow, pierces two enemies ×1.8, heavy hitstop
  and poise; early release on the pad → no arrow; pad B draws at once; dodge key cancels the draw; [5] an arrow sticks
  in a wall, stays, fades, the enemy behind is untouched. **`RESULT: ALL PASS`**
- `verify_archer.gd` (new, real key and pad events): [0] spawn point `archer` → ArcherEnemy, stats, bestiary, journal,
  voice; [1] backs away to 170 px when the hero is close, closes in to 380 px when far; [2] draw frames, red glint,
  the arrow 266 ms after the glint, from the arrowhead, straight; [3] unguarded: 12 HP (mitigated), stagger, the arrow
  breaks; [4] block on Ctrl and on pad LB: blocked, 0 damage; [5] parry on pad LB and on Ctrl: no damage, the arrow
  turns back and hits the archer; [6] roll on Shift and on pad RB: no damage, the arrow flies on; [7] jump on Space and
  on pad A: 98 px up, the arrow flies under. **`RESULT: ALL PASS`** (twice in a row)
- Touched by the change: `verify_souls_combat` **ALL PASS**, `verify_xp_curve` **ALL PASS** (CityGates `["melee",
  "melee", "archer"] → 710 XP, level 4 → 5`), `verify_road_sections` **ALL PASS**, `verify_city_gates_raid`
  **ALL PASS**, `verify_locale` **ALL PASS**.
- Captures: `SampleProject/UI/capture_bow.gd` → `design/shots/bow_stance.png`, `bow_quick_shot.png`,
  `bow_draw.png`, `bow_charged.png`, `bow_charged_release.png`, `bow_arrow_in_wall.png`, `archer_glint.png`,
  `archer_arrow.png`, `hero_blocks_arrow.png`, `hero_parries_arrow_back.png` (Xvfb, 1920×1080, crops).

## Full suite

`Scripts/Tools/run_verify.sh`, 85 verifies: **84 PASS, 1 FAIL — `SUITE: 1 FAIL`**. The one failure is
`verify_game_ui_theme` ("every button focus is the shared ring (off: FilterButton, MainMenuItem, … ShopRowOn)"): the
known baseline from `cloud/settings-cleanup` — the committed `GameUITheme.tres` is stale until Sapega regenerates it
on his machine (`build_game_ui_theme.gd`), and this branch may not commit that file. `PlayerCombat.gd` got two small
review fixes after the suite started (a buffered shot flies toward the current facing; the bow keeps the bare-hands
hitbox for skills), so `verify_bow`, `verify_archer`, `verify_souls_combat` and `verify_combat_flow` were re-run on
the final code: all four **`RESULT: ALL PASS`**.

## Left

- B110: bow frames for air / block / hurt (art lane).
- B111: whether enemies should use their stats' attack tempo (a balance call).
- Translations of the older bestiary / item texts come with `cloud/localization-2` (not merged here); the four new
  strings are in `uk.po` already and translate through the labels' auto-translate.
- Optional later: aim up/down, a quiver / volley skill, an archer kick at point-blank range ([[ranged_plan]] → Left).
- Never committed (per the rules): `project.godot`, `MainMenu.tscn`, `GameUITheme.tres`, `playthrough.gd`. Untracked
  `Sprites/Player/Weapons/dual/**/*.import` files appeared from the import and were left alone (not this task's art).
