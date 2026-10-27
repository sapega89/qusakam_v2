---
type: report
tags: [cloud, skills, v2]
branch: cloud/skills-v2-data
---

# cloud/skills-v2-data: skills v2 slice 1, numbers and the gear-free shield

**Summary**
- **Already there:** the 33 rows, the [DRAFT]/[ЧЕРНЕТКА] keys in both `.po`, the icons, the 5 passives, the `planned` state and the JP caps all came with `cloud/skills-v2` (D626, D627). This run checked them and found nothing missing.
- **Done:** the 28 planned actives now have provisional numbers: SP, damage + Phys/Elem scaling, stun/burn/heal where the D207 shapes fit, and a `draft` block for the new mechanics (px, s, shares) that no code reads yet. No cooldowns (D504). See D-sv2a below.
- **Done:** the shield skills need no shield item and work with any grip (D-sv2b). Shield Block / Bulwark cut a blow that breaks through a held block. Shield of Faith heals on any held block. The texts are updated in en/uk. The spell visuals and the glass shield are noted in the plan as a later slice.
- **Caps (D530/D627):** unchanged, base 14 and profession 12. A full tab costs 23 / 26 JP to learn and 95 / 108 JP at top rank. The hero has 19 JP at level 20, so no tab can be maxed.
- **Not green:** `verify_difficulty` has 6 FAILs, all SKILLS-build fights at levels 8–12 (D-sv2c, a balance question). Without the old flat −20 % from a worn shield, that build loses those elites. The sim never blocks, so it overstates the loss.
- **Full suite:** `SUITE: 5 FAIL`, 127 PASS. `verify_map_geometry`, `verify_progression`, `verify_save_load` and `verify_save_load_room` fail the same way on `origin/feature/backlog` (checked in a clean worktree). `verify_difficulty` is this branch's.
- Env note: `heavy_battle.mp3.import` on feature/backlog has no `uid`/`path`. Godot rewrites it on import, and reverting it breaks every audio test. It is not committed here. Whoever owns D771 should commit the imported version.
- No B rows fixed.

## D-ID text (for the orchestrator; placeholders D-sv2a–c, the orchestrator numbers them)

| ID | Kind | Text |
|---|---|---|
| D-sv2a | ROUTINE CALL | **Provisional numbers for the 28 planned v2 actives** (`cloud/skills-v2-data`; D535, D626). Each planned row in `skills.json` has `sp_cost`, `cooldown 0` (D504: only ultimates), `damage` + `damage_scaling` where it hits, `stun` / `burn` / `heal` where the D207 shapes fit, and a `draft` object with the numbers of the mechanic its build slice adds (distances px, times s, shares 0..1). No code reads `draft`; each slice 3–6 turns it into real fields when it drops `planned`. Scale follows the built actives at the same level (L1–6 ≈ 22–26 + 1.6–1.8 Phys, L8–10 ≈ 34–44 + 2.2–2.4, L14–15 ≈ 55–58 + 3.0, L18 ≈ 62–70 + 3.2–3.5; utility skills deal nothing). Table in `design/cloud_reports/skills-v2-data.md`. `verify_skill_rules` [11] checks every planned row has SP, `draft` and its icon. |
| D-sv2b | ROUTINE CALL | **The shield skills need no shield** (S19 final answer: the shield is a spell that drops over Block/1). `Player._shield_in_hand()` is removed. **Shield Block** (−20 %) and **Bulwark** (−10 %) cut a blow that breaks through a held block (`mitigated_damage(damage, through_block)`; `guard == block` past `GUARD_BREAK`), with any grip including two-handed and bow. **Shield of Faith** heals 25 % of any held block. Shield Bash / Shield Charge texts lose the shield ("…behind a shield of light"). Tooltip: "−X% damage through a block", "a held block heals X%". `iron_shield` and the `shield` slot stay as plain armour (Defense +12); whether they leave the hero's gear is open. The spell (magic shield appear / hold / fade) and the glass-shield block (cracks, shards hurt the attacker) are a later slice, noted in [[skill_trees_plan]]. |
| D-sv2c | GAP | **The SKILLS build loses 6 difficulty rows without the worn shield's flat −20 %** (agent call needed, Sapega or a balance routine). `verify_difficulty`: elite brute L8, tower shield guard L9, armoured scorpion L11, Mercenary L12, scorpion L9 ("4 hits kill the hero"), brute rows, all SKILLS build. The sim (`verify_difficulty`) never blocks, so block-only Shield Block counts 0 there. Tried: Shield Block on every hit at 0.2 fails 6 road rows at L3–4 (the hero gets too tanky without a shield); 0.1 gives 3 FAIL; 0.05 gives 2 FAIL. No single value fits both. Options: (a) the sim models a share of blows taken in a block; (b) retune those elites or the SKILLS order; (c) Shield Block at 0.05 on every hit plus a block-only part. Default until then: D-sv2b as built, the test stays red. |

## Rows (33; P = works now, A = planned)

| id | tab | Lv | kind | JP (rank jp) | gate | numbers |
|---|---|---|---|---|---|---|
| `dash_strike` | Base | 1 | A (planned) | 1 (1) | — | 5 SP · 22 dmg + 1.6 Phys / 0.0 Elem · draft dash_px 180 |
| `rising_slash` | Base | 3 | A (planned) | 1 (1) | — | 6 SP · 26 dmg + 1.8 Phys / 0.0 Elem · draft launch_s 0.8 |
| `shield_bash` | Base | 4 | A (planned) | 1 (1) | — | 5 SP · 14 dmg + 1.0 Phys / 0.0 Elem · stun 0.4 s · draft poise_x 2.5 |
| `ground_slam` | Base | 8 | A (planned) | 1 (1) | — | 9 SP · 34 dmg + 2.2 Phys / 0.0 Elem · draft radius_px 140, knockdown_s 1.2 |
| `holy_javelin` | Base | 10 | A (planned) | 1 (1) | — | 9 SP · 40 dmg + 2.3 Phys / 0.4 Elem · draft range_px 520, speed_px_s 900 |
| `battle_cry` | Base | 12 | A (planned) | 2 (2) | — | 10 SP · draft attack_bonus 0.15, duration_s 8.0, flinch_radius_px 160 |
| `counter_stance` | Base | 14 | A (planned) | 2 (2) | — | 10 SP · 55 dmg + 3.0 Phys / 0.0 Elem · draft stance_s 0.8 |
| `keen_edge` | Base | 14 | P | 2 (2) | — | crit_chance 0.05 |
| `heavy_hand` | Base | 16 | P | 2 (2) | — | heavy_poise 0.3 |
| `shield_charge` | Paladin | 5 | A (planned) | 1 (1) | 3 | 6 SP · 24 dmg + 1.7 Phys / 0.0 Elem · draft run_px 220, knockback_px 120 |
| `lightspear` | Paladin | 8 | A (planned) | 1 (1) | 6 | 9 SP · 40 dmg + 2.2 Phys / 0.6 Elem · draft range_px 600 |
| `aegis` | Paladin | 10 | A (planned) | 1 (1) | 6 | 10 SP · draft absorb 60, absorb_elem 1.0, duration_s 5.0 |
| `hallowed_circle` | Paladin | 10 | A (planned) | 1 (1) | 6 | 12 SP · draft radius_px 150, duration_s 6.0, enemy_dps 6, heal_per_s 3 |
| `rally` | Paladin | 15 | A (planned) | 2 (2) | 6 | 8 SP · draft assist_damage 0.4, assist_duration 0.5 |
| `heavens_anvil` | Paladin | 15 | A (planned) | 2 (2) | 6 | 14 SP · 58 dmg + 3.0 Phys / 0.6 Elem · draft leap_px 200, pillar_px 160 |
| `radiant_flare` | Paladin | 18 | A (planned) | 2 (2) | 6 | 12 SP · 20 dmg + 1.0 Phys / 1.0 Elem · stun 1.2 s · draft radius_px 200 |
| `shield_of_faith` | Paladin | 18 | P | 2 (2) | 6 | block_heal 0.25 |
| `blood_rush` | Dark Knight | 5 | A (planned) | 1 (1) | 3 | 6 SP · 24 dmg + 1.8 Phys / 0.0 Elem · draft dash_px 200, lifesteal 0.3 |
| `chain_of_night` | Dark Knight | 8 | A (planned) | 1 (1) | 6 | 8 SP · 18 dmg + 1.2 Phys / 0.4 Elem · draft range_px 420 |
| `blood_price` | Dark Knight | 10 | A (planned) | 1 (1) | 6 | 4 SP · draft hp_cost 0.1, hits 3, damage_bonus 0.5 |
| `night_reaper` | Dark Knight | 10 | A (planned) | 1 (1) | 6 | 10 SP · 44 dmg + 2.4 Phys / 0.5 Elem · burn 4/s 2 s · draft width_px 260 |
| `dread_howl` | Dark Knight | 15 | A (planned) | 2 (2) | 6 | 10 SP · draft radius_px 220, fear_s 2.0, flinch_s 0.4 |
| `hellfire_stomp` | Dark Knight | 15 | A (planned) | 2 (2) | 6 | 12 SP · 30 dmg + 1.8 Phys / 0.6 Elem · draft pool_px 160, duration_s 5.0, pool_dps 7 |
| `soul_harvest` | Dark Knight | 18 | A (planned) | 2 (2) | 6 | 14 SP · 70 dmg + 3.5 Phys / 0.6 Elem · draft hp_threshold 0.2, sp_refund 10 |
| `embers_within` | Dark Knight | 18 | P | 2 (2) | 6 | burning_damage 0.2 |
| `wind_step` | Warden | 5 | A (planned) | 1 (1) | 3 | 5 SP · 26 dmg + 1.8 Phys / 0.0 Elem · draft step_px 160, invulnerable_s 0.25 |
| `sand_veil` | Warden | 8 | A (planned) | 1 (1) | 6 | 8 SP · draft cone_px 180, blind_s 3.0, miss_chance 0.6 |
| `stone_palm` | Warden | 10 | A (planned) | 1 (1) | 6 | 9 SP · 16 dmg + 1.0 Phys / 0.0 Elem · stun 0.3 s · draft poise_x 3.0 |
| `sweeping_arc` | Warden | 10 | A (planned) | 1 (1) | 6 | 9 SP · 36 dmg + 2.2 Phys / 0.0 Elem · draft range_px 160, knockdown_s 1.0 |
| `mirror_stance` | Warden | 15 | A (planned) | 2 (2) | 6 | 10 SP · draft stance_s 1.0, reflect_ratio 1.0 |
| `centered_breath` | Warden | 15 | A (planned) | 2 (2) | 6 | 0 SP · heal 30 + 1.0 Elem · draft channel_s 1.5, sp_restore 8 |
| `dune_quake` | Warden | 18 | A (planned) | 2 (2) | 6 | 15 SP · 62 dmg + 3.2 Phys / 0.0 Elem · draft leap_px 200, wave_px 240, knockdown_s 1.2 |
| `light_feet` | Warden | 18 | P | 2 (2) | 6 | roll_length 0.2 |

Unchanged JP costs, levels, prerequisites and gates are from D626.

## The 5 passives (D626, checked again)
- **Keen Edge** `crit_chance` +5 %: `GameManager.gd:277` (calculate_critical_chance).
- **Heavy Hand** `heavy_poise` +30 % guard damage on the heavy attack: `PlayerCombat.gd:488`.
- **Shield of Faith** `block_heal` 25 % of a held block: `Player._heal_on_block` (now with no shield check).
- **Embers Within** `burning_damage` +20 % on burning enemies from the hero's hits, not from burn ticks: `DefaultEnemy.gd:749`.
- **Light Feet** `roll_length` +20 % roll time at the same speed: `PlayerMover.gd:143`.
Each rank above the first adds +25 % of the rank-1 value (D674). Tests: `verify_skill_rules` [12].

## Caps
| tree | cap | learn all 19 | all at top rank |
|---|---|---|---|
| base | 14 | 23 | 95 |
| each profession | 12 | 26 | 108 |
The hero has 19 JP at level 20 (1 per level). `verify_skill_rules` [1] now prints the top-rank cost too.

## Files
- `SampleProject/Resources/Data/skills.json`: planned numbers + `draft`, shield texts, `_schema.entry.draft`.
- `SampleProject/Scripts/Player.gd`: `_shield_in_hand` removed, `mitigated_damage(damage, through_block)`, `_heal_on_block` with no check.
- `SampleProject/Scripts/Systems/SkillTooltip.gd`, `en.po`, `uk.po`: 7 keys changed (5 descriptions, 2 tooltip lines).
- Tests: `verify_skill_rules` (planned numbers, top-rank cost, Shield of Faith with no item), `verify_souls_combat`, `verify_kusakam_skills`, `verify_bow`, `verify_skill_trees` (Blood Pact setup sets HP directly).
- `design/skill_trees_plan.md`: slice-1 state and the later shield-spell slice.

## RESULT lines
verify_skill_rules, verify_skill_trees, verify_skill_ranks, verify_skill_screen, verify_skills_ui, verify_souls_combat, verify_kusakam_skills, verify_bow, verify_locale (the localization test), verify_scripts_compile: `RESULT: ALL PASS`. verify_difficulty: `RESULT: 6 FAIL` (D-sv2c).
