---
type: report
tags: [cloud, combat, stamina, poise]
---

# Cloud report: stamina-poise

**Summary.** Done: stamina is back for the hero (D775), with an **ST** row under SP. The row sits where the Figma revision for D537 had it (`48bac628`: plate 470 × 144). A poise bar is on every enemy and boss (D776). The combo's third hit no longer staggers (D777). Both bots read stamina.
- **MASHER** runs dry after 2.7–5 swings a bar (3.8 on average, a combo and a half at most). 49 of the 81 blows he takes land while his bar is empty. He still beats the lone bandit (63 % HP left, was 82 %) and loses every elite, boss and group of 3+.
- **GOOD** (stops swinging below swing + roll, rolls once a red tell, steps out of reach to refill) wins all nine.
- **Tests:** `verify_masher` ALL PASS (with the drill), and the combat, HUD, boss and difficulty verifies all pass. Full suite: see §7.
- **D-IDs:** D775–D777 (§6). No B rows.
- **Not done:** no art for the stagger-by-poise flash; the D535 stamina skill drafts (Steady Breath and the others) were not brought back (Q in §6).
- **Branch:** `cloud/stamina-poise-2`. `cloud/stamina-poise` holds a stale "not started" report from an earlier run of this routine on an older base. Force-pushing over it was refused, so this work is on `-2`. Merge `-2` and drop the old one.

## 1. Stamina (D775), restored from D537 / `c526ad3e`, removed by D551 / `88c85227`

Brought back from git history and extended (`Scripts/Player/Components/PlayerStamina.gd`, a node in `Player.tscn`):

| | D537 (old) | now |
|---|---|---|
| max | 100 | 100 |
| light swing | 12 | **18** |
| heavy (paid at the wind-up) | 25 | **30** |
| quick shot / charged shot | 8 / 25 | 10 / 25 |
| roll | 20 | **22** × armour weight (light −20 %, heavy +20 %) × Sand Runner's Ring (−30 %) |
| raising the block | – | **5** (does not pause the refill) |
| a blocked hit | 15 | **10** |
| refill | 60/s after 0.5 s | **100/s after 0.5 s**; while the block is held, 30 %; armour weight light +10 %, heavy −15 % |
| empty | no roll; attacks still work | **exhausted**: no swing, heavy, shot or roll until the bar is back to **30**; each refused press flashes the ST row red (`UITokens.STAMINA_EMPTY_FLASH`, 0.35 s) and plays `stamina_empty` (throttled to the flash) |
| weak block | blocked hit on an empty bar: ½ damage and a stagger | same (`Player.WEAK_BLOCK_DAMAGE`) |

Restored as they were: `EventBus.player_stamina_changed` (now with `exhausted`), the `ST` / `ВТ` strings and `UITokens.STAMINA_FILL` `#E67E22`. New: `player_stamina_refused`, theme type `HudStBar`. The parry and the riposte cost nothing.
- **Timings:** the empty bar lets the hero act again after 0.5 + 30/100 = **0.8 s** and is full after **1.5 s** of standing still. Measured in `verify_combat_player` [3]: acts again in < 1.4 s, full in < 2.2 s.
- **Hooks:** armour weight (`armour_weight.json` `roll_stamina`, `stamina_regen`; `ArmourWeight.roll_stamina_of`, `stamina_regen_of`). Sand Runner's Ring gets `roll_stamina −0.3`, and its text says so (en/uk). No skill mentions stamina now: D551 swapped the four D535 drafts, and Light Feet stays a longer roll.
- **HUD:** `player_vitals_panel.tscn` uses the D549 revision layout. The plate is 144 tall; the rows are HP 66, SP 88 and ST 110; the portrait is at y 40, the level badge at y 118 and the curl at y 64; the chips are at y 158; the panel is 520 × 220. `design/combat_hud_mapping.md` is updated.

## 2. Poise bar (D776) and no third-hit stagger (D777)

- **Model.** `DefaultEnemy.poise` is what is left. The bar shows `poise_max − poise`. Each hero hit adds its poise damage; a full bar staggers (0.6 s) and empties. After **1.2 s** without a hit the bar drains at **20 % of max a second**; before, it reset in one step after 2 s. Signal `poise_changed(filled, maximum)`; `last_stagger_source` tells light / heavy / riposte / parry apart.
- **Hero poise damage.** Light 1 on every combo swing; the finisher's 2 is gone. Heavy **5** (was 3); two-handed ×1.5 and Heavy Hand as before. A parry staggers as before and also adds **40 % of max**. The riposte still fills the whole bar. Arrows: quick 1, charged 5.
- **Big poise.** Elites ×**2.0** (was 1.6), so the bandit brute and the armoured scorpion are at 32. Bosses: Scorpicore 14 → **45**, Mercenary 16 → **55**, Brass Collector 14 → **40**, Fire Djinn 10 → **35**.
- **No stagger by hit count (D777).** The third combo swing pushed the enemy 40 px with `breaks_attack` (`PlayerCombat.finisher_knockback`). That froze its AI for the knockback time and broke a swing not yet committed. Sapega saw this as «стан з третього удару». Removed: every combo swing pushes like the others (the weapon's own knockback, or the 8 px nudge). The finisher keeps its ×1.4 damage and its cleave. The heavy's and riposte's push stay; they are not hit-count rules. Kept: the enemy's own combo finisher still staggers the hero longer (`EnemyLogic.FINISHER_STAGGER`). That is its red-tell heavy move, not a count.
- **The bar.** One component, `UI/Components/poise_bar.tscn` / `.gd`, theme type `PoiseBar`, tokens `POISE_*`:
  - over an ordinary enemy: 56 × 5 world px, 10 px over the hurtbox, shown while it chases, strikes or is staggered, or while the bar is not empty;
  - in the boss bar: a 6 px row under HP (`BossPoise`).
  - D502 stands: still no HP bar over ordinary enemies.

Shot: `design/shots/stamina_poise.png`. Top left: the hero panel with ST at 40 %. Top right: a bandit's poise bar at 55 %. Bottom: the Scorpicore's boss bar, poise at 40 %.

## 3. Before → after (`verify_masher`)

- **Before:** `origin/cloud/enemy-ai` in a worktree, with a counter of hero swings and staggers by duration (0.6 s = poise break, 1.0 s = parry). Riposte breaks count as "poise" there.
- **After:** the committed code (`m_final`, with the drill).
- **Stamina line** of each fight: swings a bar (from a full bar to empty), how often he ran dry, time to act again (measured in game time, so a stagger or a flask during it counts), and enemy blows that landed while his bar was empty.

| bot | build | fight | before | after: result, hero HP, time, blows taken (in empty windows), hero swings, swings a bar, ran dry, staggers by source |
|---|---|---|---|---|
| MASHER | SKILLS | lone bandit | wins 82 %, 2.6 s, 1 blow, 6 swings | **wins 63 %**, 4.0 s, 2 (1), 6 swings, 4.0, 1×, none |
| MASHER | SKILLS | road's first fight | loses, 6.2 s, 6, 15 | loses, 6.9 s, 6 (4), 6, 5.0, 1× |
| MASHER | SKILLS | City Gates | loses, 6.4 s, 6, 16 | loses, 9.0 s, 9 (5), 9, 3.0, 2× |
| MASHER | SKILLS | bandit brute | loses, 5.2 s, 3, 9 | loses, 11.3 s, 6 (4), 7, 5.0, 1× |
| MASHER | SKILLS | Lab middle | loses, 15.4 s, 8, 27 | loses, 8.2 s, 6 (3), 9, 2.7, 3× |
| MASHER | SKILLS | Mayor Hall boss | loses, 6.8 s, 4, 12 | loses, 10.0 s, 6 (4), 9, 2.7, 3× |
| MASHER | SKILLS | Caravan | loses, 6.0 s, 4, 12 | loses, 4.7 s, 4 (3), 4, 3.0, 1× |
| MASHER | SKILLS | cursed jackal | loses, 2.5 s, 3, 6 | loses, 2.4 s, 3 (2), 6, 5.0, 1× |
| MASHER | SKILLS | Laboratory boss | loses, 9.2 s, 4, 17, 1 poise break | loses, 10.8 s, 5 (3), 10, 2.7, 3×, none |
| MASHER | STRENGTH | lone bandit | wins 82 %, 2.6 s, 1, 6 | **wins 63 %**, 3.8 s, 2 (1), 6, 4.0, 1× |
| MASHER | STRENGTH | the other 8 | all lose | all lose; 3–5 swings a bar; 26 of 42 blows in empty windows |
| GOOD | SKILLS | lone bandit | wins 100 %, 2.5 s; parry 1, poise 1 | wins 100 %, 2.5 s; parry 1, riposte 1 |
| GOOD | SKILLS | road's first fight | wins 100 %, 14.8 s, 21 swings; parry 3, poise 2 | wins 79 %, 30.2 s, 29 swings; parry 3, riposte 2 |
| GOOD | SKILLS | City Gates | wins 100 %, 13.1 s; parry 4, poise 1 | wins 81 %, 10.6 s; 4.0 a bar, 1×; parry 1 |
| GOOD | SKILLS | bandit brute | wins 59 %, 5.5 s | wins 59 %, 11.8 s; 4.0, 1× |
| GOOD | SKILLS | Lab middle | wins 84 %, 24.6 s, 44 swings | wins 100 %, 31.4 s, 14 swings; parry 2, riposte 4 |
| GOOD | SKILLS | Mayor Hall boss | wins 71 %, 27.4 s, 56 swings; parry 6, poise 6 | wins 100 %, 42.8 s, 29 swings; 2× dry; parry 8, riposte 7 |
| GOOD | SKILLS | Caravan | wins 67 %, 35.6 s (2nd try) | wins 25 %, 73.3 s (2nd try); 57 swings, 5.8 a bar, 4× dry, 3 of 8 blows in empty windows; parry 4, riposte 7, other 1 |
| GOOD | SKILLS | cursed jackal | wins 100 %, 8.1 s | wins 49 %, 50.4 s, 47 swings |
| GOOD | SKILLS | Laboratory boss | wins 63 %, 37.1 s (2nd try); parry 6, poise 6 | wins 57 %, 78.7 s (2nd try); parry 9, riposte 8 |

**Totals.**
- MASHER: ran dry 28 times in 18 fights, 3.8 swings a bar on average (2.7–5). **49 of 81** blows he took landed in his empty-bar windows; before, he never had one.
- GOOD: ran dry 15 times; 7 of 29 blows in empty windows, mostly in the Caravan group, where he cannot step away. Fights take about twice as long because he rests.

**Staggers by source.** Light swings stagger nobody in any fight, before or after. Only sustained light play fills a bar (an ordinary enemy needs 12–16 lights with no 1.2 s pause). Poise breaks now come from the riposte (all fights), the heavy and the parry. Under the masher's stamina limit no enemy is staggered by a combo.

**What tuning took** (four GOOD-only reruns, in this order):
1. GOOD double-rolled every red tell (two dash charges) and drained itself. Now one roll per tell.
2. Holding the block drained 8/s and stopped the refill, so GOOD sat exhausted for up to 20 s in groups. Holding the block now refills at 30 % instead.
3. Raising the block paused the refill, so GOOD, blocking every tell, never refilled against bosses. Raising now costs 5 without the pause, and a blocked hit 10.
4. GOOD rested until 60 %: it lost both bosses with 11–14 swings in 30 s. It now swings whenever a swing and a roll fit, and steps 150 px back to rest when one or two enemies are left.
5. Finally light 20 → 18, roll 25 → 22, refill 90 → 100/s. The masher still runs dry on his 5th swing at most.

## 4. Bots (`verify_masher`)

- **MASHER:** presses as before. With an empty bar he does not press; the game would refuse anyway. He stands in the enemy's face.
- **GOOD:** below roll cost + light cost (or exhausted) he does not swing. With one or two enemies left he steps to 150 px from the nearest; in a group he holds his ground and blocks. He rolls once per red tell.
- **New [8]:** the masher runs dry in every fight, at most 6 swings and heavies a bar; at least 10 blows land on him in empty windows. The new per-fight lines `ST (D775)` and `poise (D776)` give the numbers above. `MASHER_NODRILL=1` skips the drill.

## 5. Tests

- `verify_combat_player`:
  - [3] rewritten for stamina: the costs, mashing runs dry ≤ 6 swings, an empty bar refuses a swing and a roll with a flash, the hero acts again and the bar refills, raising and holding the block, the weak block;
  - new [6] for the poise bar: three combo hits fill 3 of 14 and do not stagger, the bar drains, a heavy is ≥ 4 lights, a full bar staggers and empties.

  `RESULT: ALL PASS`.
- `verify_souls_combat` (the [5] heavy test refills first: the combo tests in [4] had spent the bar): ALL PASS.
- `verify_combat_hud` (panel 520 × 220, rows HP/SP/ST, chips at y 158): ALL PASS.
- `verify_combat_enemies`, `verify_enemy_stagger`, `verify_bosses`, `verify_difficulty` (unchanged, green): ALL PASS.
- `verify_enemy_variety` (elite poise ×2.0): ALL PASS.
- `verify_masher` (both bots, drill): ALL PASS.
- There is no `verify_hud_v2`; the HUD v2 checks live in `verify_combat_hud`.
- Capture: `capture_stamina_poise.gd` → `design/shots/stamina_poise.png`.

## 6. D-IDs (next free at writing: D775; the integrator renumbers)

| D775 | OVERRIDE (reverses D551, restores D537) | **Stamina is back** (Sapega 2026-10-26: «а ще все-таки енергію гравцю треба додати, бо бити без передиху — це круто, але тоді ворог не буде встигати вдарити або провести атаку»). `PlayerStamina` (D537's, from `c526ad3e`), max 100. Costs: light swing 18, heavy 30 at its wind-up, quick and charged shots 10 / 25, roll 22, raising the block 5, a blocked hit 10. Parry and riposte are free. Refill: 100/s once 0.5 s pass without spending; 30 % while the block is held. At zero the hero is exhausted: no swing, heavy, shot or roll until the bar is back to 30 (0.8 s from empty; full in 1.5 s). Each refused press flashes the ST row red and plays a dull sound. A blocked hit on an empty bar is a weak block (½ damage and a stagger, as D537). Armour weight prices the roll (light −20 %, heavy +20 %) and the refill (light +10 %, heavy −15 %); Sand Runner's Ring makes rolls 30 % cheaper. HUD: the ST row under SP at the Figma D549 revision's place (plate 470 × 144, panel 520 × 220). Tuned with `verify_masher`: a masher runs dry within a combo and a half (3–5 swings), and 60 % of the blows he takes land while his bar is empty. All numbers are provisional. |
| D776 | OVERRIDE | **A poise bar on every enemy and boss** (Sapega 2026-10-26: «шкала стану має бути в усіх»). Each hero hit fills it by its poise damage: light 1, heavy 5 (was 3), parry 40 % of the bar (and its stagger as before), riposte the whole bar. It drains at 20 % a second after 1.2 s without a hit (was: a full reset after 2 s). Full: a 0.6 s stagger and the bar empties. Big poise: elites ×2.0 (was ×1.6); bosses Scorpicore 45, Mercenary 55, Brass Collector 40, Fire Djinn 35 (were 10–16). One component (`poise_bar.tscn`, theme type `PoiseBar`, `UITokens.POISE_*`): over an ordinary enemy, 56 × 5 px over its head, shown while it fights or its bar is not empty; in the boss bar, a row under HP. D502 stands: no HP bar over ordinary enemies. |
| D777 | OVERRIDE (amends D265, D713) | **No stagger from the third hit** (Sapega 2026-10-26: «стан з третього удару — це глупо і дуже дивно»). The combo finisher's 40 px push (`finisher_knockback`) froze the enemy and broke its wind-up on every third swing; it is gone, and the finisher's poise is a light's (was 2). Only the poise bar staggers by hits. The finisher keeps ×1.4 damage and its cleave. |

**Q for Sapega (not blocking):** should the four D535 stamina skills come back (Steady Breath: faster refill; Shield of Faith: cheaper blocks; Centered Breath: an active refill; Light Feet: cheaper rolls)? D551 swapped them for HP/SP/crit/roll-length versions, which were built and are kept.

No B rows fixed.

## 7. Full suite

(filled below)
