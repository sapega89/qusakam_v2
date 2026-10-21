---
type: plan
status: active
tags: [skills, attributes, ui, feedback]
figma: "menu-skills 58:453"
---

# Skills screen rework + attribute points — plan (BACKLOG 43 + 44)

Built by a cloud agent on `cloud/skills-screen` (2026-10-21). D-IDs D330–D336 are provisional (D316–D318 were taken; other branches may take D319+) — the orchestrator renumbers on registration. Figma was not reachable from the cloud session: the
layout follows the existing screens, [[skills_ui_mapping]] and [[skill_trees_plan]]; it **departs from Figma 58:453**
(two flat lists) on purpose, because BACKLOG 43 asks for a tree — that is Sapega's call (D-IDs below). Every call is an
**agent call, Sapega to confirm**. Report: `design/cloud_reports/skills-screen.md`.

## What exists today (before this work)

| Thing | Where | State |
|---|---|---|
| Skills screen | `Scripts/Menus/Game/skills_component.gd` (460 lines), `Scenes/Menus/Game/skills_component.tscn` | two columns of rows, right one scrolls under a tab row; double click / Enter / pad A **learns at once** (`_on_row_input`, `try_unlock_selected`) |
| Row state | `skills_component.gd` `_apply_row_state` | a lock icon on every not-learned row, even a learnable one; prereq-locked rows read `???` |
| Details | `_publish_details` → bottom bar hint, one line | no panel; no cooldown, no effect values |
| Learn rules | `SkillManager.gd` `can_unlock` (`:288`), `unlock_skill`, `can_upgrade` / `upgrade_skill` (D150) | rules live here — the UI must not copy them |
| Hotbar | `SkillManager.equip_skill(skill_id, slot)`, 4 slots; actions `skill_slot_1..4` (keys 1–4, pad RT/R3/L3/Back via `CombatInput.gd`) | a learned active goes to the first free slot (D261); no way to choose the slot from a menu |
| Attributes | `player_state.strength/intelligence/dexterity/constitution` (10 each) mirrored from `CharacterAttributes` by `CharacterManager._sync_*` (overwritten on every equip) | **fixed** — nothing raises them; `StatCalculator`: constitution → Max HP (+5), strength → Phys. Atk. (+2), dexterity → speed / evasion / accuracy / crit, intelligence → Elem. Atk. |
| Crit / evasion / speed in combat | `StatCalculator.calculate_critical_chance` etc. | **shown in Status / Equipment only — combat never reads them** |
| Save | `PlayerDataModule.gd` | saves the four base attributes, JP, skills, ranks, oath |
| Respec (D282) | `SkillManager.respec` | refunds skills only |
| Status | `stats_component.gd` `LEFT_ROWS` / `RIGHT_ROWS` | derived stats only |

## Decisions (agent calls, Sapega to confirm)

- **D330 Pending picks + Accept.** The Skills screen never spends on a single input. Picking a skill (or an attribute
  point) marks it **pending**; the header shows what is left after the pending picks. Picks can be undone one by one
  (or all at once with **Cancel**). Only **Accept** spends: the button (mouse / focus + A / Enter) or its own action
  `skills_accept` (pad **Y**, key **F**). **Esc / pad B** with pending picks drops them and stays on the screen; a second
  Esc closes the menu as before. Leaving the tab or closing the menu drops them too (nothing is spent silently).
  Replaces the double-click learn of B77 / D283. Model: `SkillPlan` (RefCounted) asks `SkillManager` the same
  questions with the pending picks applied (`check_unlock(skill, unlocked, jp)`), so the rules stay in one place; a
  pick whose prerequisite is undone drops with it.
- **D331 Inputs.** Pick: left-click selects a node, the detail panel's **Pick** button picks; Enter / pad A on a
  focused node picks. Undo: the **Undo** button, right-click on a node, `skills_unpick` (pad **X**, key **Backspace**).
  Attribute rows have **−** / **+** buttons (mouse and focus). Hotbar: four slot buttons in the detail panel for a
  learned active skill, or the hotbar actions themselves (`skill_slot_1..4`: keys 1–4, pad RT / R3 / L3 / Back) while
  it is selected. Bottom bar shows the button names.
- **D332 States.** A node is one of: **learned** (check icon, rank `R3`), **pending** (accent `+` icon, "Pending"),
  **can learn now** (no icon, cost `1 JP` in accent), **locked** (lock icon + the short reason: `Lv 12`,
  `Needs Radiant Smite`, `Oath`, `Other oath`, `JP`). The full reason sits in the detail panel. Names are always shown
  (the old `???` for a missing prerequisite hid exactly what the player needs to know).
- **D333 Tree view.** One panel, no scrolling: rows = the level tiers that have skills (trunk ∪ shown oath — 12 tiers
  for levels 1–20), a `Lv N` caption on the left, the **Holy Warrior** lane (up to 2 nodes per tier) and the **oath**
  lane (up to 2 per tier); lines from each prerequisite to its skill (elbow lines, accent when the prerequisite is
  learned or pending), including the trunk → oath links (Shield Block → Bulwark, Toughness → Iron Body). The three oath
  tabs sit in the oath lane's header row (no own row). Departs from Figma 58:453 (flat lists) as BACKLOG 43 asks.
- **D334 Detail panel.** Right column, fixed width: name, kind + tree, description, a value grid — Cost (JP), SP,
  Cooldown, Level, Requires, Rank, Effect values (damage / heal / passive value at the current rank) — the state line
  with the reason, Pick / Undo, the hotbar row. Below it the **Attributes** block and the **Cancel / Accept** bar.
- **D335 Attribute points (BACKLOG 44).** **5 per level** (Sapega), awarded on level-up, 0 at level 1. Four
  attributes — **Strength, Agility, Vitality (HP), Wisdom** — kept apart from the old base attributes (which
  `CharacterManager` rewrites on equip) in `player_state.attribute_points` (unspent) and `player_state.attributes`
  (`{strength, agility, vitality, wisdom}` points spent). What one point gives is data,
  `Resources/Data/attributes.json`:

  | Attribute | Per point | Read by |
  |---|---|---|
  | Strength | +1 Phys. Atk. | `GameManager.calculate_physical_damage` (hit damage) |
  | Agility | +0.4 % crit, +0.3 % evasion, +0.5 % speed | `GameManager.calculate_critical_chance` / `_dodge_chance` / `_attack_speed` |
  | Vitality | +4 Max HP | `GameManager.level_and_passive_health` |
  | Wisdom | +2 Max SP, +1 % skill power, +0.05 SP/s | `SkillManager.get_max_sp`, `scaled`, `_regen_sp` |

  Scale: a level already gives +20 HP and +5 attack (XPManager); 5 points in one attribute match one level's bonus.
  Owner: `AttributeManager` (new manager, `ManagerBase`, ServiceLocator `get_attribute_manager`). Saved / loaded by
  `PlayerDataModule` (old saves: 0 spent, unspent = 5 × (level − 1)). Respec (D282) also refunds attribute points and
  is offered when either skills or attributes were spent. Status shows the four attributes.
- **D336 Crit hits.** So Agility does something in a fight: a player weapon hit rolls `calculate_critical_chance()`;
  a crit deals ×1.5 (`PlayerCombat.hit_damage`). Evasion and speed stay shown-only (they never drove combat; wiring
  them changes the souls-lite feel D264 — left for Sapega, see the report).

## Slices

1. **Attributes model** — `attributes.json`, `AttributeManager.gd`, GameManager / ServiceLocator / registry,
   `player_state` + `PlayerDataModule`, bonuses wired, crit, respec refund, EventBus signals. `verify_attributes.gd`
   (model part). Commit + push.
2. **Pending model** — `SkillManager.check_unlock` / `check_upgrade` (hypothetical state), `SkillPlan.gd`.
   Checked in `verify_skill_screen.gd`. Commit + push.
3. **The screen** — `skills_component.tscn/.gd` rebuilt: tree view + links (`skill_tree_links.gd`), detail panel,
   attributes block, Cancel / Accept, hotbar assign, `MenuInput.gd` actions. `verify_skill_screen.gd` (real keys,
   mouse, `InputEventJoypadButton`), `verify_attributes.gd` UI part; update `verify_skill_trees_ui`,
   `verify_kusakam_skills`, `verify_skills_ui`. Commit + push.
4. **Status + respec** — Status attribute rows; `verify_status`, `verify_oath`. Commit + push.
5. **Full suite + report.**
