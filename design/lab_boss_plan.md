---
type: plan
status: in-progress
---

# Bosses — the Mayor Hall boss and the Laboratory boss — plan

> **Merged into [[lab_story_plan]].** Both bosses are built (queue row 9.2, D316: `BossEnemy`, `BossLogic`, hazards, boss bar, `brass_collector.tscn`, `fire_djinn.tscn`, `verify_bosses.gd`); the Mayor Hall fight is live (D300). The djinn's boss hall is built on `cloud/lab-9-7` (queue row 9.7, D307 in [[lab_story_plan]] slice 8; `verify_lab_boss.gd`).

Was blocked on Q52 (who the Laboratory boss is). BACKLOG 16 + 17 answered most of it: the Laboratory boss is the
**fire djinn** that bursts out of the prisoner (item 17), and item 16 adds a second boss in the Mayor Hall — "meant
to be unbeatable, but can be beaten" (item 6 = generate it). The rest (names, numbers, move sets, art) are agent calls
**D301 / D302**, Sapega to confirm. Story around them: [[lab_story_plan]]. Combat rules they follow: [[souls_combat_plan]]
(D264 hero staggers, D265 poise / staggers / combos). Figma: no design exists (no boss bar frame, [[figma_coverage]] §1).

## What exists today (before this pass)

| Thing | Where | State |
|---|---|---|
| Enemy base | `DefaultEnemy.gd` + `EnemyLogic.gd` (chase / attack / combo / poise / stagger / knockback), `EnemyStats` resource | ✅ reused |
| Hero side of a hit | `Player.take_damage(amount, source)`: block / parry / stagger read `source` (a `DefaultEnemy`) | ✅ bosses pass themselves as the source |
| Boss group + voice | `GameGroups.BOSS`; `SoundHooks` roars on the first wind-up, shouts on every second, death roar (D278) | ✅ |
| `DemoBoss.gd` | instanced nowhere; damage bypasses the hitbox | ✅ deleted (row 9.2) |
| Boss HP bar | `DefaultEnemy._initialize_health_bar` skips bosses | ❌ → `boss_health_bar.tscn` |

## The model (built in slice 2)

- `Scripts/Gameplay/Characters/Bosses/BossEnemy.gd` (`extends DefaultEnemy`, group `boss`): picks the logic
  `BossLogic`, shows the boss bar, enters **phase 2 at 50 % HP** (wind-ups × `phase2_windup`, speed × `phase2_speed`).
- `BossLogic.gd` (`extends EnemyLogic`): `perform_attack()` chooses one **move** from the boss's `moves` (an exported
  array of dictionaries in the boss scene: `kind`, `min_range`, `max_range`, `windup`, `damage`, `weight`, `phase`) among
  those whose range holds the hero; `combo` falls back to the shared combo of D265.
- Move kinds: `combo` (the shared hitbox swing series), `charge` (wind-up, then a dash of `distance` px with the hitbox
  live), `slam` (a shockwave on the floor on both sides within `radius`, misses a hero in the air), `fireball` (a
  projectile at the hero's height, `Scenes/FX/boss_fireball.tscn`), `pillar` (a mark on the floor under the hero, then a
  column of fire `width` px wide). Every hazard hits through `Player.take_damage(…, boss)`, so block, parry, i-frames
  of the dodge and the hero stagger work unchanged.
- **Poise**: bosses have high poise (one stagger per long chain), `super_armor` (a stun does not break a wind-up; a
  poise break still does, D265).
- `Player.defeat_handler: Callable` — when set, a defeat calls it instead of the Game Over screen (the Mayor Hall: lost
  fight → the Laboratory; the cloak fight: the djinn takes the cloak → then the Game Over screen).

## D301 — the Brass Collector (Mayor Hall)

A hulking golem of brass and sandstone with a barred cage on its back — the Laboratory's catcher of people; it breaks
through the hall's back wall. **HP 1400**, damage 28, speed 55, poise 14, stagger on the hero 0.6 s, XP 400.
Moves: **Sweep** (≤ 130 px, wind-up 0.7 s, a 2-swing combo), **Charge** (140–460 px, wind-up 0.8 s, a 320 px dash,
×1.3), **Slam** (≤ 240 px, wind-up 1.0 s, a shockwave 240 px each side, ×1.5, jump over it). Phase 2: wind-ups ×0.75,
speed ×1.3. Win loot (D300): Hi-Potion ×2, Silver Sword, 60 coins.

## D302 — the fire djinn (Laboratory)

A burning spirit with a smoke tail instead of legs, horns of flame and gold bands on its arms; it floats. **HP 1100**,
damage 24, speed 80, poise 10, XP 500. Moves: **Claws** (≤ 120 px, wind-up 0.5 s, up to 3 swings), **Fireball** (≥ 150 px,
wind-up 0.6 s, 360 px/s), **Pillar** (any range, wind-up 0.9 s, 72 px wide, ×1.6). Phase 2: wind-ups ×0.8, two fireballs
in a row, a pillar under the hero and one each side 140 px away.

## Slices

1. ✅ (queue row 9.2, D316) see [[lab_story_plan]] slice 2 — `BossEnemy`, `BossLogic`, hazards, boss bar, `defeat_handler`; `verify_bosses.gd`
   (each move hits a hero standing in it and misses one out of it; phase 2 at half HP; the bar follows HP).
2. ✅ (queue row 9.2) The two bosses as scenes with generated art (comfy-sprite, D309) — `brass_collector.tscn`, `fire_djinn.tscn`.
3. Their fights in the rooms — [[lab_story_plan]] slices 3 and 8.

## Out of scope

A Figma boss bar; boss music of its own (rooms keep their tracks, [[music_plan]]).

## Boss replaced (D466, 2026-10-23)

Sapega: the Laboratory boss is the **manticore-man brute** (not a lizardfolk) from `design/refs/lab_boss_reference.webp`, not the djinn. The djinn
stays a story beat: it escapes in the cells cutscene (D304 / D459). Slices:
1. **Art candidates.** Add `comfy_sprite.py` entry `lab_boss_brute`: `design` = `assets/references/bosses/lab_boss.webp`, the
   hero palette, an adult-sized cell (D172 ×1.5 or a boss size like `brass_collector`). Render a ×4 candidate sheet; Sapega picks one.
2. **Frames.** Idle, walk, club smash (wind-up, slam, recover), mace combo ×2, tail sweep, charge, hurt and death, each in the
   picked look.
3. **Fight.** A new boss scene on `BossEnemy` / `BossLogic` (D316) with the D466 moveset. `LabBoss` spawns it in place of
   `fire_djinn.tscn`. `verify_lab_boss.gd` checks each move's tell and hit and the defeat flow (B117's deterministic placement
   stays).
4. **Story text.** The lines around the fight (`[ЧЕРНЕТКА]`, name per Q79).
