---
type: audit
status: reference
tags: [audit, decisions]
---

# Decision audit — did the D-IDs become code?

Each run takes a range of [[figma_decision_register]] D-IDs and checks the
runtime ones against the code and the `verify_*` scripts. The code is the
evidence; doc claims of "built" are not. Newest run on top.

Verdicts: ✅ built + tested · 🟡 built, untested · 🤝 agreed, never built ·
↩️ built, then reverted / contradicted · ❓ can't tell. Non-runtime rows
(design-only, deferral, GAP blocked on art/content, superseded) get no verdict.

A grep of source or `ck(x or true, …)` does not count as a test ([[BUGS]] B4).

---

## Run 1 — 2026-10-15 — D1–D40

Source text for D1–D40 is [[ui_visual_qa]] (the register only summarises them).
Tests run this pass, all `RESULT: ALL PASS`: `verify_inventory`, `verify_status`,
`verify_equipment`, `verify_skills_ui`, `verify_world_map`, `verify_hotbar`.

**Counts:** ✅ 11 · 🟡 6 · 🤝 4 · ↩️ 1 · ❓ 0 · non-runtime 18.

| D-ID | Kind | Verdict | Evidence |
|---|---|---|---|
| D1 | deferral (TECH: no Control blur) | — | No blur exists (no `BackBufferCopy`/blur shader in `Scenes`, `Scripts`, `UI`), consistent with the decision. |
| D2 | runtime (GAP: playtime clock) | ✅ | Gap closed since. `UI/Components/party_status_panel.gd:53-55` reads `SaveSystem.get_current_playtime_sec()`. `verify_status` "party panel shows the slot's real play time". |
| D3 | runtime (GAP: per-character HP/SP) | 🤝 (SP half) | HP: active character only, `party_status_panel.gd:110` (others have no HP — D18). SP: `party_status_panel.gd:109-112` still draws `—` with comment "SP-моделі ще немає", but an SP model now exists — `SkillManager.get_current_sp()/get_max_sp()` (`Scripts/Managers/Gameplay/SkillManager.gd:227-232`), pool from D146. |
| D4 | GAP (portrait art) | — | Still colour swatches, `party_status_panel.gd:106-108`, `stats_component.gd:88`. Art gap; D112 covers story scenes only. |
| D5 | GAP (item icons) | — | Partly closed by D128: `Assets/UI/Icons/Items/{potion,ether,herb,crystal}.png`, referenced from `items.json`. Rest still placeholders. |
| D6 | superseded → D65 | — | D65: keep Healing and Jobs; 7-vs-9 sidebar stays a runtime gap. |
| D7 | runtime | ✅ | `Scripts/Menus/Game/inventory_component.gd:19` `EQUIPMENT` = `["weapon","armor"]`. `verify_inventory` "EQUIPMENT contains only weapon/armor", "tab labels match Figma" (label wording is stale — Figma says WEAPONS; the checked list is the D7 one). |
| D8 | runtime | ✅ | `inventory_component.gd:259-266` publishes name + description to the bottom bar. `verify_inventory` "keyboard focus publishes description to bottom bar". |
| D9 | runtime (CLOSED in §4) | ✅ | Register §4 says "Not implemented" — stale. `inventory_component.gd:242-248` cycles `CATEGORIES`. `verify_inventory` "ALL → CONSUMABLES → MATERIALS → EQUIPMENT → KEY ITEMS → ALL", "KEY ITEMS kept in the cycle with its empty state", "no popup or dropdown". |
| D10 | design-only (UI KIT doc vs frames) | — | Doc reconciliation, no code. |
| D11 | runtime (GAP: JP Obtained) | 🤝 | `stats_component.gd:103-104` hard-codes `—` ("Системи Job Points у проєкті немає"), but JP exists: `SkillManager.get_job_points()` (`SkillManager.gd:190`), D149. `verify_status:52` pins the placeholder ("no JP system") and must change with the fix. |
| D12 | runtime (GAP: Max. SP on Status) | 🤝 | `stats_component.gd:166-167` fills the SP meter with `-1` ("SP-моделі в проєкті немає"); `SkillManager.get_max_sp()` exists (D146). `verify_status:53` pins the placeholder. |
| D13 | runtime | 🟡 | `stats_component.gd:132-146` builds weapon boxes from equipped weapon slots, one `—` box when none. No `verify_*` checks `_weapon_slots`. |
| D14 | GAP (class names content) | — | Content task; Status renders `—` via `_or_placeholder`, `stats_component.gd:120-122`. |
| D15 | GAP (Path Action / Talent system) | — | No system; shells at `stats_component.gd:260-267`. |
| D16 | GAP (portrait art) | — | Art gap (same as D4). |
| D17 | GAP (attribute icons) | — | Still plain `Panel` boxes, `stats_component.gd:198-204`. Note: [[ui_visual_qa]] "Visual completion pass" claims the glyph import closed D17/D21 — the code does not bear that out. |
| D18 | deferral | — | Deferred in §4; Status shows the active character only. |
| D19 | runtime | ✅ | `stats_component.gd:308-311` hides `ui_party_column` (`Scenes/Menus/Game/base_menu.tscn:154`). `verify_status` "party column hidden while Status is open", "party column restored when leaving Status". |
| D20 | runtime (amended by D147: 12 slots) | ✅ | `equipment_component.gd:17-30` lists all 12 real slots incl. polearm/axe/staff/mace. `verify_equipment` "11 slot rows match player_state.equipment exactly" (label stale; compares against the real keys) and "12 rows rendered (mace — D147)". |
| D21 | GAP (slot icons) | — | Still plain `Panel` boxes, `equipment_component.gd:114-123`. |
| D22 | runtime | ✅ | Only `UNEQUIP ALL` (`equipment_component.gd:351-361`); no per-slot unequip. `verify_equipment` "all slots cleared", "slot replaced, not duplicated". |
| D23 | GAP (portrait art) | — | Art gap. |
| D24 | runtime (GAP: Max. SP delta on Equipment) | 🤝 | `equipment_component.gd:274` prints `—` ("Max. SP не має моделі"); the SP model exists (D146). No delta needed until equipment affects SP, but the value itself is available. |
| D25 | runtime | 🟡 | Equipment never touches `ui_party_column`; the column is visible by default in `base_menu.tscn:154`. No `verify_equipment` check on the party column. (D101 is about the Shop, not this.) |
| D26 | runtime | 🟡 | `skills_component.gd:301` JP cost uses `UITokens.ON_ACCENT`. No test reads the colour. |
| D27 | runtime | 🟡 | `skills_component.gd:13` and no SP pool on the Skills screen (`%d SP` at `:357` is the skill's cost, not the pool). The only check, `verify_skills_ui` "Skills screen does not display SP (D27)", greps the source — does not count (B4). |
| D28 | GAP (row-marker icons) | — | Closed since: `skills_component.gd:304-315` uses `ICON_CHECK` / `ICON_LOCK`. |
| D29 | runtime | ✅ | `skills_component.gd:339` writes details to the bottom bar; no tooltip in the component. `verify_skills_ui` "details published on focus, not just click". |
| D30 | design-only (matches Figma) | — | Nothing to build. |
| D31 | runtime | ✅ | `skills_component.gd:394-398` unlocks directly, no modal. `verify_skills_ui` "unlock succeeds via UI" + "skill recorded as unlocked" in the same frame. |
| D32 | superseded → D141 / D148 / D149 | — | `skills.json` now has Kusakam's skills; `verify_skills_ui` "production skills.json has Kusakam's skills (D141)". |
| D33 | runtime (absence) | 🟡 | No `bag`/`quickbar`/`BagSection` in any `.gd`/`.tscn`/`.json` outside addons. No test asserts the absence. |
| D34 | runtime | 🟡 | `UI/Components/combat_hud_top.gd` (Quest Info + Currency + MENU), instanced in `Game.tscn:18`. Tests check presence only (`verify_responsive` "combat_hud_top present", `verify_full_regression` "CombatHudTop inside the themed wrapper"); quest-title and coin bindings are untested. |
| D35 | runtime | ↩️ | Legacy disposition is built (`Game.tscn:253,269,281` `modulate` 0; `UI/HBoxContainer` `visible = false` at `:232`), but "all HUD overlaps cleared" is contradicted by open **B11** (tutorial hint `Game.tscn:294` overlaps the hotbar). Already filed — no new B-ID. |
| D36 | GAP (skill icon art) | — | Art gap. |
| D37 | runtime | ✅ | `project.godot:144-163` `skill_slot_1..4` on keys 1–4; `UI/Components/skill_hotbar.gd:213`. `verify_hotbar` "skill_slot_1..4 input actions registered"; `verify_village_fight` drives `skill_slot_1` → "the old man is healed". Controller half → [[gamepad_plan]] (D156). |
| D38 | superseded → D142 | — | Targeting decided in D142. |
| D39 | runtime | ✅ | `Scripts/Menus/Game/metsys_map_component.gd:96` from `MetSys.get_explored_ratio()`. `verify_world_map` "percent matches MetSys", "explored panel present". |
| D40 | deferral | — | No legend in `metsys_map_component.gd` or the scene — consistent. |

**Resume at D41.**
