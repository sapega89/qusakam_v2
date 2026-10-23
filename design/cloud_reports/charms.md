---
type: cloud-report
branch: cloud/charms
date: 2026-10-23
tags: [cloud, build, pillar-3, equipment]
---

# Cloud report: charms (D592 — charms and armour weight)

**Summary**
- Done: 6 rule charms as data (`charms.json`), 3 slots (2 open, the 3rd after the Brass Collector), save/load, the
  attic chest with Grandfather's Ring, armour weight (light / medium / heavy, `armour_weight.json`), a Charms block in
  Equipment. Plan: [[charms_plan]]. `verify_charms` ALL PASS, `verify_equipment` ALL PASS (new [12b] weight).
- Not done: the other 5 charm chests (their D643 rooms are not built), charm icons (crystal stand-in), a Figma frame.
- D-IDs below: D675–D679 (orchestrator renumbers). No B rows fixed.
- `verify_difficulty`: 2 FAIL, both already failing before this branch (the Mayor Hall boss, B144); every other row unchanged.
- Full suite: `SUITE: 4 FAIL`, 110 PASS. Not from this branch: verify_difficulty (2), verify_mayor_boss (1), verify_lab_boss (2) fail the same way on `origin/feature/backlog` (B144). verify_audio failed once and passed on an immediate re-run (a hurt-voice timing flake).
- For the orchestrator: add `[[charms_plan]]` to `design/BACKLOG.md` (pillar 3 / D592 row). The routine rules forbid
  routines to edit BACKLOG, so this branch does not touch it.

## D-ID text (next free numbers after D674)

| ID | Type | Text |
|---|---|---|
| D675 | ROUTINE CALL | **Charms: rings and amulets that change a rule** (D592). Data `Resources/Data/charms.json`, rules `Scripts/Systems/Charms.gd`, state `player_state.charms {owned, equipped, slots}` saved by `PlayerDataModule` (a save from before has no charms and 2 slots). **3 slots, 2 open from the start; the 3rd opens when the Brass Collector falls** (`MayorHall._on_warrior_died` → `Charms.unlock_slot()`), the first boss and the oath's level. A charm is found once, worn in one slot. Charms are separate from the `accessory_1/2` stat slots, which stay as they are. Each rule is read by the system that owns it (`Charms.effect(name)`), never a flat stat. |
| D676 | ROUTINE CALL | **The six charms** (numbers provisional; names and texts [DRAFT] / [ЧЕРНЕТКА]). **Grandfather's Ring**: a parry heals 5 % max HP. **Sand Runner's Ring**: no block and no parry, the roll lasts 30 % longer. **Hermit's Amulet**: skills cost 30 % less SP (at least 1), every skill heal (the flask too) is 30 % weaker. **Breaker's Ring**: the hero's melee blows deal 35 % more to an enemy that is staggered or stunned (`DefaultEnemy.is_staggered`). **Deep Gourd Amulet**: the flask holds 4 sips instead of 3, each 30 % weaker (2.8 flasks' worth instead of 3); the new sip waits for a save, and taking it off removes it. **Jackal Tooth Amulet**: each kill gives 4 SP. Skill SP costs and sip counts shown in the skills screen, tooltip and hotbar follow the charms. |
| D677 | ROUTINE CALL | **Armour weight** (D592, D551). Body armour carries `"weight"` in `items.json`, and the worn body armour sets the class. With no body armour the hero counts as medium (the plain roll, so every roll test keeps its numbers); helmets and shields have no weight. Numbers are in `armour_weight.json`: **light** roll +15 %, **medium** ±0 (no body armour), **heavy** roll −15 % and **+2 Phys. Def.** (+4 max HP through the existing 2 HP per defence). `leather_armor` is light and `iron_armor` heavy. The roll factor is Light Feet + charm + weight (`PlayerMover.roll_factor`), at the same speed, so a longer roll goes further and stays invulnerable for longer. +5 and +3 defence broke D642 (jackal L9/L10 at 7 hits, the Fire Djinn at 5); +2 leaves every `verify_difficulty` row as it was. |
| D678 | ROUTINE CALL | **Where the charms are found** (D583: no free gifts). Grandfather's Ring is in a new chest in the grandfather's attic (`ElderHouse` → `Attic/Chest_Attic`; the attic opens with its key). The shrine (D643) is not built. Planned, not placed: Deep Gourd Amulet in the family shrine chest (Lizard Cave), Breaker's Ring in the Bandit Camp chest, Sand Runner's Ring at the top of the Mesa Climb, Jackal Tooth Amulet behind the Dragon Mural wall, Hermit's Amulet in the Gatehouse Cellar chest. `Chest.gd` takes `charm = "<id>"` (alone or with items); the found icon and the modal name the charm. |
| D679 | ROUTINE CALL | **The CHARMS section in Equipment** (no Figma frame). In the Attributes side panel, under the attributes: the heading "Charms" and three rows copied from the `%SlotRow` template (captions CHARM 1–3 (Roman numerals fail the uk Latin check), "(empty)", "(locked)" for a closed slot, the accent dot on a worn one). A row opens the existing equip picker with the found charms, each showing its rule text, and Unequip. The BODY row adds the weight ("Iron Armor · Heavy armour"). Long names end in an ellipsis (`text_overrun_behavior` on the template); the hint bar shows the full name and rule on focus. The slot scroll now follows focus. No new colours or sizes. Under the slot list the rows ran off the screen (`verify_responsive`), so they went to the side panel, which was empty below the attributes. |

## Details

**Rules, file:line**
- `Scripts/Systems/Charms.gd`: data, slots, `grant` / `equip` / `unequip` / `unlock_slot`, `effect`.
- Parry heal: `PlayerCombat._on_parried`. No block: `PlayerCombat._physics_process` (`guarding`). Roll:
  `PlayerMover.roll_factor`. Staggered bonus: `PlayerCombat._load_hit` → `DamageApplier.staggered_bonus` →
  `DefaultEnemy.is_staggered`. SP cost / heal / flask: `SkillManager.sp_cost`, `_charm_heal_factor`, `max_charges`,
  `_on_charms_changed`. SP on kill: `SkillManager._on_enemy_died`. Signal: `EventBus.charms_changed`.
- Weight: `Scripts/Systems/ArmourWeight.gd`, `GameCharacter.get_equipment_stats` (body slot), `PlayerMover.roll_factor`.
- Third slot: `MayorHall.gd` after `mayor_boss_defeated`.
- Localization: 21 keys in `en.po` / `uk.po`; `charms.json` name and description registered in `data_fields.json`.

**Tests**
- `verify_charms.gd` — RESULT: ALL PASS. [1] data and po keys, [2] slots and unlocks, [3a–f] each rule in the real
  game (parry heal, block refused + roll, SP cost + heal, staggered damage on a real enemy, 4-sip flask, SP on kill),
  [4] attic chest holds the ring + a charm chest grants it and names it, [5] PlayerDataModule round-trip and a pre-D592
  save, [6] the Equipment section, the locked hint, picking a charm.
- `verify_equipment.gd` — RESULT: ALL PASS; new [12b]: unarmoured medium (plain roll), leather light (roll ×1.15, defence item only),
  iron heavy (roll ×0.85, +20 +2 defence), BODY row names the weight, a real roll uses it.
- `verify_difficulty.gd` — RESULT: 2 FAIL, identical to `origin/feature/backlog` before this branch: "Brass Collector
  at level 5: 9 hits kill the hero / 27 hits kill it" and "…STRENGTH: wins" — the Mayor Hall boss is the Scorpicore
  (2600 HP), B144. Hero HP from level 5 on is +4 (heavy armour); H and N are unchanged in every row.

**Shots** (no Figma frame to compare; the look follows the Equipment slot rows)
- `design/shots/charms/equipment_charms.png` — Equipment, BODY "Iron Armor · Heavy armour", the Charms block under Attributes, hint for CHARM 3 locked.
- `design/shots/charms/charm_picker.png` — the picker with the rule texts.
- Visual notes, not fixed: charm names are cut to "Grandfat…" by the 150 px caption column. The picker marks a charm
  worn in another slot "Equipped", and picking it moves it there. Both are left for a Figma frame (a Q for Sapega when
  the frame is drawn).
