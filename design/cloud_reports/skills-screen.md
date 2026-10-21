---
type: report
status: done
tags: [skills, attributes, ui, cloud-report]
---

# Cloud report — BACKLOG 43 + 44: Skills screen rework + attribute points

Branch `cloud/skills-screen` (from `origin/feature/backlog` 8811363). Plan: [[skill_screen_rework_plan]].
Godot 4.6.2 ran headless here (download worked); no display, so **no captures** — the layout is described in words
below and measured by the verifies. Figma was not reachable: the screen follows the existing screens, the common
Theme (no new theme token; `GameUITheme.tres` untouched) and [[skills_ui_mapping]].

## What was built

### Attribute points (BACKLOG 44)
- `SampleProject/Resources/Data/attributes.json` — 5 points per level; per-point values; caps (the StatCalculator ceilings).
- `Scripts/Managers/Gameplay/AttributeManager.gd` — new manager (`ManagerBase`): level-up grant `:53`, `bonus(stat)` `:100`,
  `capped` `:109`, `can_spend` / `spend` `:125` / `:139` (one event per allocation), `reset` `:156` (respec),
  `points_for_level` `:167` (old saves). Created in `GameManager.gd` `_create_managers`, registered in
  `GameplayServiceRegistry.gd`, `ServiceLocator.get_attribute_manager()`.
- State in `player_state.attribute_points` / `player_state.attributes` (`PlayerStateManager.gd:83`), saved and loaded by
  `PlayerDataModule.gd:56` / `:138` (a save from before: nothing spent, `5 × (level − 1)` unspent).
- Read by: `GameManager.level_and_passive_health` `:208` (Vitality), `level_and_passive_attack` `:214` (Strength; also used
  by the Equipment "without items" value), `with_attribute_ratio` `:220` (Agility: crit / evasion / speed, capped);
  `SkillManager.get_max_sp` `:271`, `scaled` `:131` (Wisdom: skill power on damage and heals), `_regen_sp` (SP/s);
  `SkillManager._on_attributes_changed` `:79` pulls SP to the new cap; `Player.gd:68` refreshes Max HP.
- Respec (D282): `SkillManager.can_respec` `:412` / `respec` `:421` also refund attribute points; the oath keepers offer
  "Unlearn skills and attributes (N coins)" when either was spent (`OathKeeper.gd:57`).
- Signals `EventBus.attribute_points_changed`, `EventBus.attributes_changed` (`EventBus.gd:226`).
- Status: header "Attribute Points: N" + a row Strength / Agility / Vitality / Wisdom with the points spent
  (`stats_component.gd:197`, `stats_component.tscn` `AttrPoints`, `PointAttrs`).

### Skills screen (BACKLOG 43) — `Scenes/Menus/Game/skills_component.tscn`, `Scripts/Menus/Game/skills_component.gd`
Layout, top to bottom at 1920×1080: the profile header (avatar, name, class title, JP left after the picks). Below,
two columns. **Left, the tree panel** (expands): a lane header — "Holy Warrior / Primary Class Tree" over the trunk
lane, the three oath tabs + "Light · Your oath" (or where to swear) over the oath lane — then 12 tier rows
(`Lv 1 … Lv 20`, only levels that have skills), each with up to two trunk nodes and two oath nodes; elbow lines from
each prerequisite into its skill, gold when the prerequisite is learned or picked, grey otherwise (including
Shield Block → Bulwark and Toughness → Iron Body across the lanes). Measured: the tiers need 616 px of a 663 px stage.
**Right, 420 px**: the detail panel (name, "Active skill · Holy Warrior", description, Cost / Level / SP / Cooldown /
Rank / Requires / Weapon / Effect, the full reason line, Pick + Undo, "PUT ON THE HOTBAR" with four slot buttons
"1 · Healing Palm"), the Attributes panel (Strength / Agility / Vitality / Wisdom, what one point gives, spent + picked,
− / +, points left), and the action bar ("To spend: 2 JP, 3 attribute pts", Cancel, Accept). Measured: 689 px of 813.
No ScrollContainer anywhere on the screen.
- Tree build `_rebuild_tree` `:265`, `_make_tier` `:296`; lines `skill_tree_links.gd` (drawn under the nodes,
  redrawn on `Tiers.sort_children`), fed by `_refresh_links` `:433`.
- Node states `node_state` `:355`, drawing `_apply_row_state` `:397`.
- Detail panel `_refresh_detail` `:445`, `_effect_text` `:495` (values at the current rank and Wisdom),
  `_reason_text` `:525` (SkillManager's verdict through the plan), hotbar row `_refresh_hotbar` `:562`.
- Picks: `Scripts/Systems/SkillPlan.gd` — `can_pick` `:75` asks `SkillManager.check_unlock` / `check_upgrade`
  (`SkillManager.gd:321` / `:103`, the old `can_unlock` / `can_upgrade` now call them with the real state), `unpick` `:91`
  + `_revalidate` `:102` (undoing a prerequisite drops what relied on it), `clear` `:147`, `accept` `:157`.
- Inputs: `pick_selected` `:611`, `unpick_selected` `:618`, `accept_plan` `:631`, `cancel_plan` `:638`,
  `assign_to_slot` `:643`, node input `_on_row_input` `:651`, Esc / B `_shortcut_input` `:675` (runs before the
  FocusRouter / game-menu `_unhandled_input`, only while focus is on this screen), Accept / Undo / hotbar keys
  `_unhandled_input` `:685`; actions `skills_accept` (key F, pad Y) and `skills_unpick` (Backspace, pad X) registered in
  `Scripts/Core/SkillScreenInput.gd` (from `GameManager._initialize`, like CombatInput). Bottom bar line names the
  buttons of the current device (`_describe` `:712`, InputGlyphs). Leaving the tab drops the picks (`_notification` `:727`).

## Decisions — ready to paste (agent calls, Sapega to confirm)

Numbers D330–D336 are provisional: D316–D318 were taken on `feature/backlog`, other branches may take D319+.

| D | Kind | Text |
|---|---|---|
| D330 | GAP | **Skills screen: pending picks + Accept** (BACKLOG 43, Sapega «подвійний клік — то погано… перевибрати, поки не натиснув прийняти»; agent call, Sapega to confirm). Nothing is spent on a single input. Picking a skill (learn or one rank) or an attribute point marks it *pending*; the header shows the JP left after the picks, the action bar what will be spent. Picks are undone one by one (Undo / right click / X / Backspace) or all at once (**Cancel** button, **Esc / pad B** — Esc with picks only drops them and the screen stays; the next Esc works as before). Only **Accept** spends (button, pad **Y**, key **F**), in the order picked. Leaving the tab or closing the menu drops the picks. `SkillPlan` asks SkillManager the same rules with the picks applied; undoing a prerequisite drops the skills picked on top of it. Replaces the double-click learn of B77 / D283. Plan [[skill_screen_rework_plan]]; test `verify_skill_screen.gd`. |
| D331 | GAP | **Skills screen inputs** (agent call, Sapega to confirm). Mouse: a click selects a node (and fills the detail panel), **Pick** / **Undo** buttons in the detail panel, right click = undo, − / + on attribute rows, Cancel / Accept buttons, a click on a hotbar slot button. Keyboard: Enter picks the focused node, Backspace undoes, F accepts, Esc drops the picks, keys **1–4** put the selected learned active skill into that hotbar slot. Gamepad: A picks, X undoes, Y accepts, B drops, D-pad moves between nodes / tabs / panel buttons, the hotbar buttons (RT / R3 / L3 / Back) put the selected skill into their slot. Actions `skills_accept`, `skills_unpick` are registered in code (`SkillScreenInput.gd`) because `project.godot` is not committed. |
| D332 | GAP | **Skill node states** (BACKLOG 43 problem 1; agent call, Sapega to confirm). **Learned**: check icon, rank `R3` (`R3 +1` with a picked rank). **Picked**: gold diamond, `Picked`. **Can learn now**: no icon (no lock on a learnable skill), the cost `1 JP` / `Free` in gold. **Locked**: lock icon + short note `Lv 12` / `Oath` / `Other oath` / `Locked` (missing prerequisite — the line shows which) / the cost when JP is short; the full sentence ("Level too low: needs level 12.", "Needs Radiant Smite first.") is in the detail panel and the bottom bar. Names always show — the `???` of the old screen is gone. |
| D333 | DEVIATION | **The Skills screen is a tree, not Figma's two flat lists** (BACKLOG 43 problems 3 + 5; departs from `menu-skills 58:453` as Sapega's item asks — Sapega to confirm). One panel, no scrolling: a row per level that has skills (trunk ∪ shown oath: 12 rows for levels 1–20), a `Lv N` caption, the Holy Warrior lane and the oath lane (two places each per row), elbow lines from each prerequisite (gold when learned or picked). The three oath tabs sit in the oath lane's header — no own row. More than two skills on one level of one tree make the nodes narrower rather than breaking the window. |
| D334 | GAP | **Skill detail panel** (BACKLOG 43 problems 2 + 6; agent call, Sapega to confirm). Right column, 420 px: name, kind + tree, description, Cost / Level / SP / Cooldown / Rank / Requires / Weapon / Effect (damage, heal, burn, chain, stun or the passive's value — at the current rank and with Wisdom once learned), the reason line, Pick / Undo, and for a learned active skill four hotbar slot buttons ("1 · Healing Palm"; the slot holding it is pressed). Below: the Attributes panel and Cancel / Accept. The learn-time auto-slot of D261 stays (first free slot). |
| D335 | GAP | **Attribute points** (BACKLOG 44, Sapega «5 навичок на рівень»; values: agent call, Sapega to confirm). **5 per level-up** (0 at level 1; skill points stay 1 per level, D279) into **Strength** (+1 Phys. Atk. per point), **Agility** (+0.4 % crit, +0.3 % evasion, +0.5 % speed), **Vitality** (+4 Max HP), **Wisdom** (+2 Max SP, +1 % skill power on skill damage and heals, +0.05 SP/s); 5 points in one attribute ≈ one level's own bonus (+20 HP / +5 attack). Data: `Resources/Data/attributes.json` (crit / evasion / speed keep the StatCalculator ceilings 50 % / 50 % / 2×). Kept apart from the old base strength / dexterity / … (CharacterManager rewrites those on every equip): `player_state.attribute_points` + `player_state.attributes`, owner `AttributeManager`, saved by PlayerDataModule (a save from before gets `5 × (level − 1)` unspent). Spent on the Skills screen in the same pick / Accept flow (D330). The respec (D282) refunds them too ("Unlearn skills and attributes (N coins)", offered when skills or attributes were spent). Status shows the unspent points and the four attributes. Test `verify_attributes.gd`. |
| D336 | GAP | **Agility stays on the sheet for now** (agent call, Sapega to confirm). Agility's crit / evasion / speed show in Status and Equipment but no combat code reads those three — true before this work for the base dexterity too (B-ID below). Wiring them is a combat-feel call (random crits and dodges in a souls-lite parry game, D264) and makes the exact-damage combat tests random (they need a seeded roll); left for Sapega. |

## New bugs — ready to paste

| B | Text |
|---|---|
| B84 (provisional) | **Crit, evasion and attack speed do nothing in a fight.** `GameManager.calculate_critical_chance` / `calculate_dodge_chance` / `calculate_attack_speed` (StatCalculator + Agility, D335) are read only by the Status and Equipment screens; `PlayerCombat.hit_damage()` never rolls a crit, `Player.mitigated_damage()` never rolls an evasion, swing times ignore speed. Agility points therefore change numbers on screen only (D336). Fix: a crit roll in `hit_damage` (×1.5) and an evasion roll in `mitigated_damage`, behind a seedable RNG so `verify_combat_flow` / `verify_souls_combat` stay exact; speed into `swing_time`. Needs Sapega's call on the feel. |

Fixed in passing (no B-ID needed): the Equipment screen's "without items" Phys. Atk. left out the passive attack
(D284), so Weapon Training / Dread Aura / Perfect Balance read as item bonuses — now `level_and_passive_attack()` on
both sides; a load clamped current SP to the base 30, ignoring Devotion (max SP passives) — now clamped to
`get_max_sp()` after skills and attributes are loaded.

Seen, not mine (pre-existing, every menu test): `WARNING: This control can't grab focus` from
`game_menu.gd:95 switch_to_tab` when a test switches tabs from code.

## Verifies

Run headless with Godot 4.6.2 Linux (`$G`), each under `godot_locked.sh`; RESULT lines:

| Verify | RESULT |
|---|---|
| `verify_skill_screen.gd` (new: mouse, keys, InputEventJoypadButton) | ALL PASS |
| `verify_attributes.gd` (new) | ALL PASS |
| `verify_skill_trees_ui.gd` (Accept flow) | ALL PASS |
| `verify_skills_ui.gd` (Accept flow, `???` → names) | ALL PASS |
| `verify_kusakam_skills.gd` (Enter picks, Accept learns) | ALL PASS |
| `verify_oath.gd` (respec refunds attributes) | ALL PASS |
| `verify_status.gd` ([3b] attribute points) | ALL PASS |
| `verify_skill_trees`, `verify_equipment`, `verify_combat_flow`, `verify_save_load`, `verify_hotbar` | ALL PASS |

**Full suite** (`Scripts/Tools/run_verify.sh`, 71 scripts): **69 PASS, 2 FAIL**:
- `verify_audio` — 1 FAIL "focusing a button (pad navigation) ticks on SFX": **fails the same on the base
  `origin/feature/backlog`** in this headless Linux container (not this branch).
- `verify_souls_combat` — 1 FAIL "the hero moved in at least 10 of 12 seconds of fighting (3 stuck)" in the suite run;
  **ALL PASS on two re-runs** and on the base: a timing flake under load, not a regression.

(`Scripts/Tools/godot_locked.sh` and `run_verify.sh` are committed without the exec bit; here they were run via
`bash` / a local `chmod +x`, not committed.)

## Left

- **Theme regeneration: not needed** — no theme token was added (the screen uses existing variations: SkillRow,
  SkillName*, SkillCost, TreeTitle, TabButton, TreePanel, TooltipBody, StatLabel / StatValue, AttrLabel / AttrValue,
  AccentLabel, MicroLabel, PrimaryButton).
- **Captures**: none possible here; the orchestrator should capture the Skills screen (before / after the oath, with
  picks pending), the Status header and compare with Figma 58:453 (D333 is the deliberate departure).
- **B84 / D336**: Agility into combat (crit / evasion / speed) waits for Sapega.
- The Skills screen has no icons per skill (none exist in the repo; `SkillDefinition.icon` is empty everywhere).
- Later tiers (25–99, subclass at 40, prestige at 70) would add rows; at 3+ rows more the tree no longer fits
  1080 px without scrolling — the tier view then needs paging by level band (not needed for levels 1–20).
- Exe rebuild (Windows / Linux) and registering D330–D336 / B84 in the vault — orchestrator.
