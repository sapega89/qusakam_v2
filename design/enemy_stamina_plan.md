---
type: plan
status: in-progress  # 2026-10-27 cloud/enemy-stamina: slice 1 built
tags: [combat, enemies, stamina]
---

# Enemy stamina — plan (D824)

Sapega's playtest, 2026-10-27: «треба, щоби у ворогів теж була стаміна». Like the hero's stamina ([[stamina-poise]],
D775/D776), an enemy spends stamina on its blows and must breathe before it attacks again, so it cannot chain blows
forever; an exhausted enemy is open. It sits beside the poise bar (D777) and must read apart from it. It lands after
the tuning pass (D835–D839: slower enemies, longer cooldowns, a shorter micro-stun).

## What existed before
| Thing | Where | State |
|---|---|---|
| Hero stamina | `Scripts/Player/Components/PlayerStamina.gd`, the HUD ST row | ✅ D776 |
| Enemy poise and its bar | `DefaultEnemy.take_poise`, `UI/Components/poise_bar.tscn`, boss bar `BossPoise` | ✅ D777 |
| Enemy tempo | `EnemyStats.attack_cooldown`, rhythm ×0.7–1.3, attack token (2), D754 answer hits | ✅ |
| Enemy stamina | — | ❌ no grep hits for an enemy stamina anywhere |

## Design (agent call, Sapega to confirm)
1. **What costs stamina.** Paid at the strike, not the wind-up (a feint or a dropped wind-up is free):
   - every blow of a series (`EnemyLogic.perform_attack`), an archer's shot, a flier's dive or bite (`swing`);
   - a lunge (D768, `lunge`), the jackal's leap that may end in a latch (D769, `pounce`);
   - a boss's move by its kind (`combo` per blow, `charge`, `slam`, `fireball`, `pillar`; `drink` costs 0 and refills).
2. **Refill.** `regen`/s once `delay` s pass without an attack; nothing while attacking.
3. **Short of breath.** An ordinary enemy that cannot pay its next opener (`swing`) neither swings, lunges nor punishes
   an opening: it steps out to `max(engage range, hero's series reach + 20 px)` and waits there, facing the hero
   (tactic `catch_breath`). A lunge or pounce needs its own price. The shield-bearer's guard (D775) still works.
4. **Winded.** The blow that empties the bar ends the series (the next blow of the series is not struck). After the
   series' own recovery the enemy is **winded** for `winded` s: it stands (the stun tint, its stagger pose where it has
   one), cannot attack, evade or guard, counts as staggered for Breaker's Ring, and its strip is red; the hero's dull
   `stamina_empty` exhale plays (`EventBus.enemy_winded`, `SoundHooks`). It attacks again at `recover_at` of max.
5. **Bosses.** Their own pool, no refill mid-fight. A boss never refuses or reorders a move for stamina: its combo
   always runs its full fixed series. When a move empties the pool, the move's recovery (D316) runs first, then the boss
   is winded, then the pool is full again. The pattern (D577) goes on from where it was. The Mercenary's drinks (D564)
   refill, so he rarely runs dry: his breath is his drink.
6. **The strip.** A 56 × 3 px strip 1 px under the poise bar (it is a child of it), shown only while the enemy is engaged.
   Colour: the hero's ST orange (`UITokens.ENEMY_STAMINA_FILL = STAMINA_FILL`), red while spent
   (`ENEMY_STAMINA_SPENT = STAMINA_EMPTY_FLASH`) with a red rim, so an empty strip reads too; theme types `EnemyStaminaBar` / `EnemyStaminaBarSpent`. Poise stays
   yellow and 5 px: poise is what the hero fills, stamina is what the enemy burns. Bosses: a 4 px row under `BossPoise`.

## Numbers (`Resources/Data/enemy_variety.json` → `stamina`)
| kind | max | swing | lunge | pounce | regen /s | delay s | winded s |
|---|---|---|---|---|---|---|---|
| default (shield 30, vulture 40, fly 30, tower guard 35, heavy archer 35 swing) | 100 | 25 | 35 | 45 | 45 | 0.6 | 0.9 |
| bandit (melee) | 100 | 20 | 35 | – | 45 | 0.6 | 0.9 |
| jackal (fast), pack leader, cursed jackal | 90 | 20 | 35 | 45 | 50 | 0.6 | 0.9 |
| scorpion (tank), armoured scorpion | 100 | 40 | – | – | 40 | 0.6 | 1.1 |
| archer | 100 | 25 | – | – | 40 | 0.6 | 0.9 |
| bat | 100 | 25 | – | – | 50 | 0.6 | 0.9 |
| bandit brute | 100 × 1.5 | 40 | 45 | – | 45 | 0.6 | 0.9 |
| elites | max × 1.5 (`stamina.elite.max`), costs of their base kind unless they have a row | | | | | | |
| bosses | 150 | combo 12 a blow, charge 30, slam 25, fireball 20, pillar 25, drink 0 (refills) | | | 0 | – | 1.2 |

`recover_at` is 0.4 of max for every ordinary kind (a bandit is back 1.5 s after running dry).

Reasoning: a bandit's two-blow series costs 40, so a full bar is two and a half series; at its D836 tempo it refills
most of a series between series and runs dry when it chains (a lunge into a series, D754 answers, punishing openings).
Measured in `verify_enemy_stamina` [8] (a hero who stands in reach, 40 s): see the report for strikes with and without
stamina. A boss's pool lasts about one and a half pattern cycles (Brass: combo 24 + slam 25 + combo 24 + charge 30 ≈ 100).

## Slices
1. **Built (cloud/enemy-stamina):** `EnemyStamina.gd`, the costs above in `EnemyLogic`, `FlyingLogic`, `ArcherLogic`,
   `BossLogic`; winded; the strip and the boss row; `verify_enemy_stamina`.
2. Tune in real fights with `verify_masher` (MASHER and GOOD bots) and a playtest: does winded come too often against a
   blocking hero? Should the hero's block drain enemy stamina (a blocked blow costs the attacker extra)?
3. Optional: a winded pose / breath puff art (now the stagger pose and stun tint stand in); skills that drain stamina.

## Open questions (not blocking; defaults built)
- Should a blocked or parried blow cost the enemy extra stamina (rewarding the block)? Default: no.
- Is the ST orange right for enemies, or should enemy stamina have its own colour? Default: the hero's orange.
