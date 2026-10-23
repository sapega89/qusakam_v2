---
type: report
tags: [cloud, combat, D504]
---

# Cloud report: combat-player (D504 player side, D502, D503)

**Summary.** All five items are built on `cloud/combat-player`. (1) Attacks commit. A ground swing plants the hero with a short step. Facing stays locked until the hit is out (fixes **B136**). A roll, block or jump cuts an attack only in its recovery, and never the heavy's wind-up or strike. Cutting the heavy's recovery keeps the rest of it as a cooldown (fixes the critique's **B-9**). Presses are buffered for 0.2 s, even through a stagger, and jumps for 0.1 s. (2) Stamina: an ST bar under SP, spent by attacks, rolls and blocked hits, refilling after a 0.5 s pause. An empty bar means no roll and a weak block. (3) Potions are drunk from the `quick_potion` button (Q / D-pad right) in a 0.8 s planted lock, and no longer from the Game Menu. (4) Ordinary enemies have no HP bar. (5) The combat tutorial has 4 lessons, shows banners only, uses no timers and can be skipped with the cutscene-skip button. The pad run takes 8.3 s. D-ID text: **D536–D540** (below). B rows fixed: **B136**, plus the critique's **B-9** (not yet filed). Found and fixed on the way: the Settings → Controls labels were shifted by two rows (**B-new-1**). Not done: elites' name plate (no elites exist), a drinking animation (the chest "Raise" pose stands in, Q below). Full suite: **SUITE: ALL PASS (99 scripts)**.

## D-ID text for the register (renumbered D523–D527 → D536–D540 at merge)

| ID | Kind | Text |
|---|---|---|
| D536 | GAP (`cloud/combat-player`) | **Attacks commit, as built (D504; amends D223, D456, D521).** A combo swing (`PlayerCombat._swing_phase`) has three phases: wind-up, hit (the hitbox is on only from 0.05/0.3 to 0.13/0.3 of the swing, at least 0.05 s) and recovery. From the ground it plants the hero (`locks_movement`) and pushes him forward **10 px** (the finisher **24 px**, the heavy's strike **18 px**) over 0.08 s. In the air he keeps flying. **Facing** stays locked until the hit is out (`locks_facing` → `PlayerMover.facing_locked`), so turning mid-swing no longer turns the body away from the hitbox (B136). Between swings, a held direction turns the next swing (`PlayerMover.face_input`). **Cancel:** a roll, block or jump cuts a combo swing only once its hit is out. The heavy's wind-up and strike cannot be cut. The heavy now has a planted **recovery state of 0.6 s** (was a free 1.0 s cooldown, critique R1), and a roll or block cuts only its last **0.3 s** (`HEAVY_CANCEL_LAST`). What is left of it becomes `attack_cooldown` (B-9). A bow shot can be cut once its arrow is out. Skill casts and drinking cannot be cut. **Buffers:** roll, light and heavy pressed while busy wait **0.2 s** (`INPUT_BUFFER`), even through a stagger. Jump waits **0.1 s** (`PlayerMover.JUMP_BUFFER`). If the jump is released while it waits, it becomes a short hop. Tests: `verify_combat_player` [1], [2]. The D456 checks in `verify_combat_feel` [4] are retired. |
| D537 | OVERRIDE (`cloud/combat-player`) | **Stamina, as built (D504; reverses D264's "no stamina").** `Player/Components/PlayerStamina.gd`, a node in `Player.tscn`. Max 100. Costs: light swing 12, heavy 25 (paid at the wind-up), quick shot 8, charged shot 25, roll 20, blocked hit 15. Regen: 60/s once **0.5 s** pass without the hero acting (any combat state but READY or BLOCK, or a roll). While blocking it regenerates at 30 %. **Empty:** no roll, and a **weak block**: a blocked normal hit deals 50 % damage and staggers (`Player.WEAK_BLOCK_DAMAGE`). Hits that already break the guard are unchanged. Attacks still work on an empty bar. The parry costs nothing. Death and respawn refill it. HUD: an **ST** row under SP in the hero panel (`UITokens.STAMINA_FILL` #e67e22), fed by `EventBus.player_stamina_changed`. All numbers are provisional (table below). Tests: `verify_combat_player` [3]. |
| D538 | OVERRIDE (`cloud/combat-player`) | **Potion quick slot, as built (D504; amends D286).** A new input action `quick_potion`: **Q** / **D-pad right**, listed in Misc → Controls and Settings → Controls. One press drinks a healing potion in real time (`Player.drink_potion` → `PlayerCombat.drink`). The hero must be on the ground and free. He is planted for **0.8 s** and heals at **0.5 s**. The potion leaves the bag at once, so a hit before the heal wastes it. If HP is full, or he is in the air or busy, nothing happens. **Which potion** (agent call): the smallest one that covers the missing HP, otherwise the strongest one carried (`Combat/QuickPotion.gd`). The hero panel shows `Q  Potions ×N` (every healing potion together). The Game Menu no longer drinks healing potions: Enter, double-click or pad A shows "Drink it in play with the quick slot (Q)" in the bottom bar. **The Ether (SP) is still drunk in the menu** (agent call: it is not a heal; Q-ID below). Sound: `potion` (reuses `cast_heal_release.ogg`). Tests: `verify_combat_player` [4], `verify_use_item` [1]–[2]. |
| D539 | GAP (`cloud/combat-player`) | **No HP bar over ordinary enemies, as built (D502).** `DefaultEnemy` no longer creates a HealthBar (its `health_bar` field and `_initialize_health_bar` are gone), and `Scenes/UI/enemy_health_bar.tscn` is deleted. Bosses keep their top-of-screen bar (D316, `BossEnemy`). No elites exist in the code yet, so the gold name plate (D495) is left for `cloud/combat-enemies`, along with the guard bar. The `ENEMY` mode of `HealthBar.gd` is now unused. Tests: `verify_combat_player` [5], `verify_bosses`. |
| D540 | GAP (`cloud/combat-player`) | **The faster combat tutorial, as built (D503).** Four lessons (`CombatTraining.LESSONS`): **Attack** (a combo whose finisher lands; this merges attack and combo), **Dodge or Block** (a dash through a live blow, a block or a parry), **Parry**, **Heavy**. One successful action each. A lesson shows only its banner: the topic is marked seen, so no paused window opens, but it still goes into the Tutorial list. The next lesson starts at once, with a coin sound and no `NEXT_DELAY`. The **cutscene-skip** button (Tab / pad Y) skips the rest (`CombatTraining._unhandled_input`), and the first banner says so. Texts in `tutorial.json`, `en.po` and `uk.po`, with the six old titles and texts replaced. The pad run, each move once, took **8.3 s**. Tests: `verify_onboarding` [1], [2] (under 60 s), [2b] (skip). |

## B rows fixed

| Row | Fix |
|---|---|
| **B136**: turning mid-swing turned the body and weapon, not the hitbox | Facing stays locked until the hit is out, and the hitbox is placed by `_direction` when it turns on (`PlayerCombat.locks_facing`, `PlayerMover.facing_locked`). `verify_combat_player` [1] |
| **Critique B-9** (unfiled): cutting the heavy's strike skipped its recovery | The strike cannot be cut any more. The recovery is a state, and cutting its last 0.3 s keeps the rest as `attack_cooldown` (`PlayerCombat.cancel_attack`). `verify_combat_player` [2] |
| **B-new-1** (found here, file it): Settings → Controls showed the wrong names from "assist" on | `input_options_menu.tscn` `readable_action_names` had two extra entries ("Next Weapon", "Previous Weapon") with no matching actions, so every label after "Dodge" belonged to the action two rows below. Removed them and added "Quick Potion" in step |

## Questions (non-blocking, defaults in place)

- **Q (Ether):** the Ether still restores SP from the paused menu. Should it go to the quick slot too, or wait for the skills branch's SP-from-hits change (D504)?
- **Q (art):** drinking reuses the chest pose `Raise`. A drink frame set is missing (`hero_drink`?).
- **Q (Figma):** the ST row and the `Q  Potions ×N` line in the hero panel have no Figma frame (434:6558 has HP, SP, XP). They are built with the panel's own row and value styles.

## Provisional numbers

| What | Value | Where |
|---|---|---|
| Light swing: hit window | 0.05–0.13 of a 0.3 s swing (scaled by attack speed), at least 0.05 s | `PlayerCombat.SWING_HIT_FROM/TO`, `MIN_HIT_TIME` |
| Forward step: swing, finisher, heavy | 10, 24, 18 px over 0.08 s | `SWING_STEP`, `FINISHER_STEP`, `HEAVY_STEP`, `STEP_TIME` |
| Heavy recovery (planted) | 0.6 s (was a 1.0 s free cooldown) | `heavy_recovery` |
| Heavy recovery that can be cut | last 0.3 s | `HEAVY_CANCEL_LAST` |
| Input buffer (roll, light, heavy) | 0.2 s | `PlayerCombat.INPUT_BUFFER` |
| Jump buffer | 0.1 s | `PlayerMover.JUMP_BUFFER` |
| Stamina max | 100 | `PlayerStamina.MAX` |
| Cost: light, heavy, quick shot, charged shot | 12, 25, 8, 25 | `COST_*` |
| Cost: roll, blocked hit | 20, 15 | `COST_ROLL`, `COST_BLOCK` |
| Regen | 60/s after 0.5 s idle; ×0.3 while blocking | `REGEN`, `REGEN_DELAY`, `BLOCK_REGEN` |
| Weak block (empty bar) | 50 % damage plus a stagger | `Player.WEAK_BLOCK_DAMAGE` |
| Potion drink | 0.8 s lock, heals at 0.5 s | `PlayerCombat.DRINK_TIME`, `DRINK_HEAL_AT` |

## Files

- `Scripts/Player/Components/PlayerCombat.gd`: states `HEAVY_RECOVERY` and `DRINK`; `_swing_phase` :302, `locks_facing` :361, `_buffer` :433, `can_cancel_attack` :548, `cancel_attack` :561, `drink` :574.
- `Scripts/Player/Components/PlayerMover.gd`: `facing_locked`, `face_input` :101, the jump buffer :61.
- `Scripts/Player/Components/PlayerStamina.gd` (new; a node in `Player.tscn`), `Scripts/Combat/QuickPotion.gd` (new).
- `Scripts/Player.gd`: `_try_roll` :203 (stamina), `drink_potion` :269, weak block in `take_damage`, jump-cancel in `_physics_process`.
- `UI/Components/player_vitals_panel.gd/.tscn`: the ST row and the `QuickPotion` label. `UITokens.STAMINA_FILL`.
- `Scripts/Menus/Game/inventory_component.gd`: healing potions point to the quick slot. `controls_component.gd`, `input_options_menu.tscn`, `project.godot` (`quick_potion`).
- `Scripts/Gameplay/DefaultEnemy.gd`; `Scenes/UI/enemy_health_bar.tscn` deleted.
- `Scripts/Gameplay/CombatTraining.gd`, `Resources/Data/tutorial.json`, `en.po`, `uk.po`, `sound_events.json` (`potion`).
- Tests: new `UI/verify_combat_player.gd`. Updated `verify_combat_feel` ([4] retired), `verify_onboarding`, `verify_use_item`, `verify_bosses`. Capture: `UI/capture_combat_player.gd` → `design/shots/combat_player_hud.png` (the hero panel with ST under SP and `Q  Potions ×2`, and a hurt bandit with no bar over him).

## RESULT lines

- `verify_combat_player`: ALL PASS (43 checks)
- `verify_combat_feel`: ALL PASS
- `verify_onboarding`: ALL PASS (pad chain 8.3 s)
- `verify_use_item`, `verify_bosses`, `verify_combat_hud`, `verify_combat_flow`: ALL PASS
- First full-suite run: 4 FAIL, all because the tests assumed the old behaviour, now fixed. `verify_hit_areas`: its reach now includes the 10 px step. `verify_souls_combat`: a planted swing no longer counts as "stuck". `verify_weapon_animations`: the steps walked the hero into the enemy, so the hero's x is reset for each weapon. `verify_locale`: "ST" is now "ВТ" in uk, and the label is empty in the .tscn.
- **Full suite (final): `SUITE: ALL PASS`, 99 PASS.**
