---
type: report
status: done
tags: [cloud, combat, settings, bugs]
---

# Cloud report — `cloud/combat-stats` (2026-10-22)

Branch `cloud/combat-stats` from `origin/feature/backlog` @ `14ca889c`. Covers Sapega's calls of 2026-10-22: **B84 → D393**,
**B111 → D394**, and the damage numbers (D66 Settings row). `BUGS.md`, `figma_decision_register.md`, `remaining_work.md`
and `BACKLOG.md` are untouched; the orchestrator applies the rows below.

## 1. Crit, evasion, attack speed in a fight (B84 → D393)

- **One seedable RNG:** `Scripts/Combat/CombatRolls.gd` (preloaded, no class_name). `static var rng` is seeded at random;
  `roll(chance)` is the only use. A test calls `calm()`, which seeds `CALM_SEED = 451095` and resets `rolls`. The first
  `CALM_ROLLS = 150` draws of that seed are all ≥ `CALM_FLOOR = 0.1`, so at normal chances (crit 7 %, evasion 5 % at
  dexterity 10, Agility 0) nothing fires. A seed search over about 20 M seeds found that 151 draws is the longest
  such run. `verify_combat_flow` and `verify_souls_combat` assert they stay inside the window; they use 22 and 75 rolls.
- **Crit:** `PlayerCombat.gd:186-191` `hit_damage()` rolls `calculate_critical_chance()`. A crit sets `critical` and
  deals ×`CRIT_DAMAGE` (1.5, `:27`). The flag travels with the hit:
  - the swing: `:325`, `:360` → `DamageApplier.critical` (`DamageApplier.gd:23`)
  - the arrow: `:412` → `Arrow.critical` (`Arrow.gd:30`, `:94`)
  - then `HealthComponent.apply_damage` (`:12`) → `IDamageable.safe_take_damage` (`:14`) → `CombatBody2D.take_damage`
    (`:72`) → `register_damage` (`:36`) → `EventBus.damage_received(target, source, amount, critical)` (`EventBus.gd:148`).
  - The three existing listeners (VFXHooks, SoundHooks, player_vitals_panel) take the extra `_critical`.
  - The overrides `DefaultEnemy.take_damage` (`:565`) and `Player.take_damage` pass it through.
- **Evasion:** `Player.gd:477` `mitigated_damage()` rolls `calculate_dodge_chance()` and returns 0. `Player.gd:463-466`:
  a 0 means no hit at all. There is no `register_damage`, no i-frames, no stagger, no damage event or hurt feel, only the
  new `EventBus.player_evaded(attacker)` (`EventBus.gd:174`). The roll runs on every hit that reaches `mitigated_damage`
  (enemies, boss moves, arrows, hazards). Block and parry come first and don't roll.
- **Attack speed:** `PlayerCombat.gd:318`. The light swing's `_state_left` is divided by `calculate_attack_speed()`
  (×1.2 at dexterity 10, so 0.30 → 0.25 s). The body animation speeds up through the existing
  `play_body(…, swing_time / _state_left)`. The heavy attack, the bow and the finisher recovery keep their times.
- **Test** `UI/verify_combat_stats.gd`:
  - [1] crit ×1.5, flagged, landed on an enemy
  - [2] evade: 0 HP, `player_evaded`, no i-frames, no stagger, then the next hit lands
  - [3] the swing lasts `swing_time / speed`, ends sooner in physics frames, and +20 dexterity shortens it further
  - [4] see §2
- **Other tests** that compare exact damage now start from `CombatRolls.calm()`: archer, attributes, bosses, bow,
  combat_hud, kusakam_skills, skill_trees, skill_casts.

## 2. Enemy tempo from stats (B111 → D394)

- `EnemyLogic.gd` no longer has its own `attack_cooldown = 1.5`. `:322` sets `attack_ready_in = enemy.attack_cooldown`
  (DefaultEnemy copies it from `EnemyStats` in `_apply_stats`). This builds on D388's game-time `attack_ready_in`.
- **Bosses as well:** `BossLogic.gd:60` `_rest()` now waits the boss's own stats. Brass Collector waits **1.2 s** and
  fire djinn **1.0 s**; before, both waited the base 1.5 s. The archer (`ArcherLogic.gd:30`) already read the stats;
  only its comment changed. `DefaultEnemy.attack_cooldown` is now typed `float`.
- `verify_combat_stats` [4] checks that EnemyLogic has no tempo of its own and that each DesertRoad enemy waits its
  stats' value (melee 1.5, fast 1.0).
- **10× runs of the four fight tests:** 39 / 40 ALL PASS. The failure was run 4 of `verify_combat_flow` [2b] (i-frames).
  An enemy swing already in flight when the test freezes physics had made the hero invulnerable. The faster tempo makes
  the fast enemy's combo more likely to be mid-swing then. Fix: `verify_combat_flow` [2b] waits until no enemy is
  attacking, the same guard [1] already had. After the fix, `combat_flow` passed 10 / 10: runs 5–10 of the loop plus 4
  more.
  - `verify_bosses`: 10 / 10
  - `verify_archer`: 10 / 10
  - `verify_souls_combat`: 10 / 10

## 3. Damage numbers (D66 row; Sapega «цифри урону по мені і ворогу»)

- **Hook, once:** `Scripts/FX/DamageNumbers.gd` is created by `GameManager.gd:160`, next to VFXHooks. It listens to
  `EventBus.damage_received`, which is emitted only by `CombatBody2D.register_damage`, plus `player_evaded`. Numbers show
  only for the hero and for enemies.
  - Each number is `Scenes/FX/DamageNumber.tscn` + `Scripts/FX/DamageNumber.gd`: bold Cormorant with an outline,
    `z_index` 260, node scale 0.4 (crisp under the camera's 2.25 zoom).
  - It sits 18 px above the top of the body's collision shape, which is above the enemy HP bar.
  - It lives in the room, not on the body, so a hero knocked back by the hit leaves it where the hit landed.
  - It rises 28 px (ease-out) over 0.8 s and fades in the second half. Numbers in a row alternate x offsets 0 / −10 / +10.
- **Look (UITokens.gd, "Цифри урону" block):**

  | Case | Colour | Size | Notes |
  |---|---|---|---|
  | Enemy hit | `TEXT_PRIMARY` white | 52 | |
  | Hero hit | `HURT_RED` | 52 | different from the enemy colour |
  | Crit | `ACCENT` gold | 72 | pops at ×1.4 and settles in 0.15 s |
  | Evade | `TEXT_SECONDARY` | 40 | the word `tr("Evade")`, en "Evade", uk «Ухил», instead of 0 |

  Outline: `BACKGROUND`, 16. Cormorant uses old-style figures, which is why the sizes are large.
- **Settings → Game → Damage Numbers:**
  - `options_component.gd:211` adds a segmented On/Off row, the same widget as Tutorial Windows.
  - Handler at `:415`. `settings.damage_numbers` defaults to **On** (`SettingsModule.gd:20`) and is saved with the other
    settings; Restore puts it back On.
  - The Game tab hint now names it. en.po and uk.po have the hint, "Damage Numbers" and "Evade".
  - Screen Shake and Text Speed rows **do not exist** on this branch, so the row is modelled on Tutorial Windows.
    `verify_settings` no longer lists Damage Numbers as a deferred row.
- **Test** `UI/verify_damage_numbers.gd` (writes only to `user://verify_damage_numbers/`, never real saves):
  - [1] one number, the value, the enemy colour and size, above the head, in the room
  - [2] rises, fades, freed
  - [3] crit: gold and bigger
  - [4] hero: red, above him
  - [5] evade: the word, not 0, plus uk translations
  - [6] row On/Off, saved and reloaded, Off shows nothing, Restore → On
- **Shots** (xvfb, `UI/capture_damage_numbers.gd`):
  - `design/shots/damage_numbers_enemy_hit.png` — white 30
  - `design/shots/damage_numbers_crit.png` — gold 45
  - `design/shots/damage_numbers_hero_hit.png` — red 12, where the hit landed before the knock-back
  - `design/shots/damage_numbers_evaded.png` — «Evade» above the hero
  - The tutorial banner in two of the shots is the live onboarding hint (noise).

## D-IDs for the register (agent calls, Sapega to confirm)

- **D-new (damage numbers look):** "Damage numbers (D66): enemy hits white (`TEXT_PRIMARY`) 52, hits on the hero red
  (`HURT_RED`) 52, the hero's crit gold (`ACCENT`) 72 with a ×1.4 pop, an evade shows «Evade» / «Ухил»
  (`TEXT_SECONDARY`) 40. Dark outline. Numbers rise 28 px over 0.8 s and fade in the second half, 18 px above the body's
  top, in the room, not following the body. No Figma frame; agent call, Sapega to confirm."
- **D-new (evasion is a clean miss):** "An evaded hit (D393) is no hit at all: no i-frames, no stagger, no hurt flash,
  sound or HP shake. Only `player_evaded` and the word. Every hit that reaches `mitigated_damage` can be evaded,
  including boss moves, arrows and hazards; block and parry come first. Agent call, Sapega to confirm."
- **D-new (attack speed scope):** "Attack speed (D393) shortens only the light swing (and its animation). Heavy wind-up,
  bow draw and shot, and the combo-finisher recovery keep their times. Agent call, Sapega to confirm."
- **D-new (boss tempo):** "D394 applies to the bosses too: the Brass Collector rests 1.2 s and the fire djinn 1.0 s after
  a move (their EnemyStats), not 1.5 s. Agent call, Sapega to confirm."
- **D-new (test RNG):** "Tests that compare exact damage call `CombatRolls.calm()`: seed 451095, the first 150 draws are
  ≥ 0.1. Fight tests assert they stayed inside 150 rolls. Agent call."

## B rows fixed

- **B84** — fixed (D393). Remove the row; `git log --grep B84`.
- **B111** — fixed (D394). Remove the row; `git log --grep B111`.

`design/settings_plan.md` "Damage Numbers ❌ no damage-number system exists" is now ✅. The orchestrator should update the
row together with `settings_mapping.md`.

## RESULT lines

| Test | Result |
|---|---|
| verify_combat_stats (new) | RESULT: ALL PASS |
| verify_damage_numbers (new) | RESULT: ALL PASS |
| verify_combat_flow | RESULT: ALL PASS (10 / 10 after the [2b] fix) |
| verify_souls_combat | RESULT: ALL PASS (10 / 10) |
| verify_bosses | RESULT: ALL PASS (10 / 10) |
| verify_archer | RESULT: ALL PASS (10 / 10) |
| verify_settings, verify_settings_graphics, verify_tutorial_hints, verify_scripts_compile | RESULT: ALL PASS |

**Full suite** (`Scripts/Tools/run_verify.sh`, 90 scripts): **89 PASS, 1 FAIL**. The fail is `verify_game_ui_theme`
(no RESULT line), which is expected until the owner regenerates his theme.

Not committed (Godot import artefacts of other branches' assets): `Assets/FX/Skills/*/*.png.import`,
`capture_living_world.gd.uid`, `verify_living_world.gd.uid`.
