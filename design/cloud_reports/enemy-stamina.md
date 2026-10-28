---
type: report
tags: [cloud, combat, enemies, stamina]
---

# Cloud report: enemy-stamina

**Summary.** Built: D824 enemy stamina, slice 1. Enemies pay stamina for swings, lunges, the jackal's pounce, a flier's dive or bite, an archer's shot and a boss's moves. It refills while they do not attack. Short of it, an enemy keeps out of the hero's reach and does not attack. The blow that empties the bar ends the series and leaves it **winded** for 0.9 s: it stands with the stun tint and its stagger pose, the `stamina_empty` sound plays, and the strip goes red. Bosses have their own pool and keep their pattern and recovery.
- **The strip:** 56 × 3 px under the poise bar, the hero's ST orange, shown only while engaged; a 4 px row under poise in the boss bar.
- **Plan:** `design/enemy_stamina_plan.md`. **The orchestrator needs to add** a link from `design/BACKLOG.md` (I did not edit it, per the routine rules).
- **Tempo** against a hero standing in reach for 40 s: bandit 23 strikes vs 26 with endless stamina (×0.88); jackal 22 vs 27 (×0.81).
- **verify_difficulty:** the same 5 red rows before and after, numbers unchanged (table §4). No green row lost. Stamina does not enter its hit-count model.
- **Not done:** no `verify_masher` bot run; no art for a winded pose (the stagger pose and stun tint stand in).
- **D-ID:** D844 (next free at writing), text in §6. No B rows fixed.
- **Full suite:** `SUITE: 3 FAIL` (J=4). After fixes each passes or is pre-existing: `verify_difficulty` (pre-existing 5), `verify_gates` (load flake, ALL PASS alone), `verify_enemy_stamina` (HUNG at 180 s, now `## TIMEOUT: 480`, PASS in 210 s).

## 1. What was built
- `Scripts/Gameplay/Components/EnemyStamina.gd` is a new node, preloaded and without `class_name`. It provides `can_afford`, `spend`, `take_winded`, `refill` and `tick`, and the signals `changed` and `winded`. `DefaultEnemy._initialize_components` creates it before the logic, and `_on_winded` sets `stun_left`, plays the stagger pose and emits `EventBus.enemy_winded`.
- `EnemyLogic`:
  - `process_physics` ticks it, but not while attacking.
  - `handle_attack_state`: when the bar cannot pay a `swing`, the enemy does nothing else. It emits the tactic `catch_breath` and holds at `_breath_gap()` = max(engage range, hero series reach + 20 px). There it neither swings nor lunges, and it does not punish openings.
  - `_lunge_due` needs the price of a lunge or pounce.
  - `perform_attack` spends at each strike, and `_breath_ends_series()` cuts the series once the bar is empty.
  - `perform_lunge` spends too. Both call `take_winded()` after their recovery.
- `FlyingLogic`: `can_strike` needs the price; the dive or bite spends; winded after recovery.
- `ArcherLogic`: a shot needs the price.
- `BossLogic` (D577 pattern, D316 recovery):
  - a move is never refused or reordered;
  - `_swing_kind` = `combo`, and `_breath_ends_series` = false, so combos keep their fixed length;
  - other moves spend by kind;
  - `take_winded()` runs after the move's own recovery; the pool is full again when the window ends;
  - `drink` refills.
- Numbers live in `Resources/Data/enemy_variety.json` → `stamina` (default, per-kind rows, elite ×1.5, boss). They are read by `EnemyVariety.stamina(id, boss)`. The table is in the plan.
- The strip: `UI/Components/enemy_stamina_bar.tscn/.gd`.
  - Above an ordinary enemy it is a child of the poise bar (`DefaultEnemy._add_poise_bar`).
  - In the boss bar it is `BossStamina` (`boss_health_bar.tscn/.gd`).
  - Tokens: `UITokens.ENEMY_STAMINA_FILL` (= `STAMINA_FILL`), `ENEMY_STAMINA_SPENT` (= `STAMINA_EMPTY_FLASH`), `ENEMY_STAMINA_HEIGHT` 3, `ENEMY_STAMINA_GAP` 1, `BOSS_STAMINA_HEIGHT` 4.
  - Theme types `EnemyStaminaBar` / `EnemyStaminaBarSpent`. The spent one has a red fill and a red rim, so an empty strip still reads. The theme was regenerated.
- Sound: `SoundHooks` plays `stamina_empty` on `enemy_winded`; it reuses the hero's sound, so there is no new asset.

**Prompt note:** D739/D740 in the prompt are the dialogue auto-advance and the living City. The lunge and pounce are D768/D769, and those are what I built against.

## 2. Tests

| test | result |
|---|---|
| `verify_enemy_stamina` (new, SERIAL, TIMEOUT 480): [1] data per kind, [2] spend at the strike and refill, [3] cannot afford → no attack, out of reach, attacks after refilling, [4] the series ends on empty, winded (stun, tint, sound event, red strip, no attack), fights again at 40 %, [5] strip under poise only when engaged, own colour, [6] flier pays, [7] boss same moves in same order and same combo lengths with an empty pool as with an endless one, winded after the move, never during its recovery, full after, [8] tempo | ALL PASS (210 s) |
| `verify_combat_enemies` | ALL PASS. [2] now refills the jackal before its measured 3-blow series: the live AI had spent it. |
| `verify_combat_flow` | ALL PASS. [2c] and the lunge check refill the jackal and clear its winded stun first, since its physics is off in that step and the stun never runs out. |
| `verify_combat_feel`, `verify_enemy_variety`, `verify_bosses`, `verify_boss_hits`, `verify_combat_hud`, `verify_scripts_compile` | ALL PASS |
| `verify_game_ui_theme` | `=== ALL CHECKS PASSED ===` |
| `verify_difficulty` | 5 FAIL, the same rows as before (§4) |

Baselines (clean worktree of the starting `feature/backlog`): all of the above passed, except `verify_difficulty` with 5 FAIL.

## 3. Shot
`design/shots/enemy_stamina.png`: left, a fighting bandit (poise 40 % yellow, stamina 40 % orange under it); middle, a
winded bandit (stagger pose, empty strip with the red rim); bottom, the Scorpicore's bar (HP, poise 30 %, stamina 50 %).

## 4. verify_difficulty: the five red rows, before → after
| row | before | after |
|---|---|---|
| scorpion L9 at level 9 | 4 hits kill the hero ([5, 6]), 4 kill it | same |
| shield-bearer L11 at level 11 | 5 hits kill the hero, 3 kill it ([4, 6]) | same |
| Scorpicore Axe-Warrior at level 5 | 3 hits kill the hero, 27 kill it ([34, 46]) | same |
| Mercenary at level 12 | 4 hits kill the hero, 30 kill it ([34, 46]) | same |
| elite armoured scorpion L11, SKILLS | loses (9 hits needed, 3 blows taken, survives 2) | same |

Its model counts HP and damage only, so stamina cannot move it. The real effect of stamina on difficulty is the tempo in §5 and the winded windows. Measure that in `verify_masher` next (slice 2).

## 5. Tempo (verify_enemy_stamina [8], 40 s against an invulnerable hero standing in reach)
- **bandit:** 23 strikes and winded 1× with stamina, against 26 with endless stamina (×0.88).
- **jackal:** 22 strikes and winded 5×, against 27 (×0.81).

The threshold in the test is ≥ 0.7. An earlier tuning (regen 35, bandit swing 25) gave ×0.69–0.75. I raised regen (default 45, jackal and bat 50, scorpion and archer 40) and lowered the bandit's swing to 20, so the bars cap chains without making fights easy after D836's slow-down.

## 6. D-ID (next free at writing: D844; the integrator renumbers)

| D844 | ROUTINE CALL (`enemy-stamina`, D824 as built) | **Enemy stamina.** `EnemyStamina` on every enemy and boss; numbers in `enemy_variety.json` → `stamina`. Costs are paid at the strike: a swing (each blow of a series, a shot, a dive or bite) 25 by default (bandit 20, jackal 20, shield-bearer 30, tower guard 35, scorpion / brute / vulture 40, fly 30), a lunge 35 (brute 45), the jackal's pounce 45. Pool 100 (jackal 90), elites ×1.5. Refill 45/s (jackal and bat 50, scorpion and archer 40) after 0.6 s without attacking. An enemy that cannot pay a swing keeps out of the hero's series reach and neither attacks nor punishes. The blow that empties the bar ends the series. After its recovery the enemy is winded for 0.9 s (scorpions 1.1): it stands, shows the stun tint and its stagger pose, plays the `stamina_empty` sound, and its strip goes red. It fights again at 40 %. Bosses: a pool of 150 that does not refill mid-fight (combo 12 per blow, charge 30, slam 25, fireball 20, pillar 25). A boss never skips or reorders a move and never cuts a combo. A move that empties the pool is followed by the move's own recovery (D316), then 1.2 s winded, then a full pool. A drink refills it. UI: a 56 × 3 px strip in the hero's ST orange, 1 px under the poise bar, only while engaged; red fill and red rim when spent; a 4 px row under poise in the boss bar. |

Non-blocking questions (defaults built, in the plan):
- Should a blocked or parried blow cost the attacker extra stamina?
- Should enemy stamina have its own colour instead of the hero's ST orange?

## 7. Full suite
`Scripts/Tools/run_verify.sh` (J=4, 16 min 13 s): **`SUITE: 3 FAIL`**.
- `verify_difficulty`: 5 FAIL, the pre-existing rows of §4.
- `verify_gates`: 1 FAIL, `Chest_TowerGuard offers "Open"`. It passed alone on this branch (`SUITE: ALL PASS`) and on the base, so this is load timing.
- `verify_enemy_stamina`: HUNG at the default 180 s. It now carries `## TIMEOUT: 480` and passes in 210 s through `run_verify.sh enemy_stamina`.

Maps/ untouched. `playthrough.gd` untouched.
