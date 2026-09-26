# Skills UI — implementation mapping

**Figma:** `menu-skills` `58:453` · **Godot:** new `skills_component.tscn/.gd`
mounted in the existing `SkillsPanel` placeholder.

## Figma structure (measured, not eyeballed)

```
main-layout (h 1016)
├── left-column 320            — shared sidebar (already implemented)
└── center-content  flex-1, padding 48, gap 32
    ├── profile-header         avatar + name + class + "JP OBTAINED: <n> JP"
    └── columns-wrapper        two equal columns
        ├── left-column-primary
        │   ├── header: class name (Bold, accent) · "Primary Class Tree" · "NEXT SKILL COST" + value
        │   ├── "Job Skills"      (Regular 16, secondary)
        │   ├── skill rows …
        │   ├── "Support Skills"
        │   └── skill rows …
        └── right-column-secondary   same shape, "Secondary Class Tree"
            └── UI/Tooltip      selected-skill name + description
```

### ⚠️ It is not a graph

Despite the brief's contingency for a tree, the Figma frame contains **no
connectors, no nodes and no edges** — it is two flat lists grouped into
*Job Skills* / *Support Skills*. Confirmed from `get_design_context`: every
`skill-*` element is a plain full-width row, siblings in a vertical stack.

**Consequence: no `ui_position` / `tree_row` / `branch` field is required.**
Layout is fully derivable from data already on `SkillDefinition`:

| Figma placement | Derived from |
|---|---|
| left column | `class_id` == active character's `class_id` |
| right column | `subclass_id` == active character's `subclass_id` |
| "Job Skills" section | `skill_type == ACTIVE` |
| "Support Skills" section | `skill_type == PASSIVE` |

`prerequisites` drive row **state**, not position — exactly as §8 requires.

### Skill row states (measured)

| State | Icon (14px) | Name | Row |
|---|---|---|---|
| Learned | check-circle | Medium 18 **primary** | 1px border |
| Available / locked | empty 14px box, 1px border | Medium 18 **secondary** | 1px border |
| Hidden (prereq unmet) | lock glyph | Medium 18 secondary, text `???` | 1px border |
| **Selected** | as above | **Bold** 18 primary | **bg accent**, JP cost shown right (Regular 16 accent) |

Row metrics: `px 16`, `py 10`, icon→text gap `12`.
Tooltip: surface bg, 1px border, drop shadow, `px 14 py 10`, gap 4;
title Medium 16 accent, body Regular 13 primary.

## Godot mapping

| Figma | Godot | Source of truth |
|---|---|---|
| profile-header name/class | `CharacterManager.get_active_character()` | gameplay |
| `JP OBTAINED` | `player_state.job_points` via `SkillManager.get_job_points()` | gameplay |
| column headers | `GameManager.get_class_data()` → `pathfinder_classes.json` | **names are empty** → render `—` (deviation D14 convention) |
| `NEXT SKILL COST` | cheapest affordable-next `jp_cost` in that column | derived |
| skill rows | `SkillDatabase` filtered by class + type | data-driven, **no hardcoded rows** |
| row state | `SkillManager.is_unlocked()` / `can_unlock()` result | never re-implemented in UI |
| tooltip | `SkillDefinition.name` + `.description` | data |
| JP/SP readouts | `job_points_changed`, `sp_changed`, `skill_unlocked` | event-driven, not polled |

## Required wiring changes

`game_menu.gd` currently has **no `Skills` case** in `_update_visibility()`'s
`match`, so `SkillsPanel` never becomes visible, and `component_to_tab` has no
Skills entry. Two one-line additions needed — the tab button already exists and
already maps in `_apply_localized_labels` / `_update_button_states`.

## Scope boundaries honoured

`NEXT SKILL COST` is shown because it is derivable. There is **no** hotbar,
equip control, keybinding or JP-reward surface in this frame, so nothing had to
be rendered as a disabled placeholder.

## Production empty state

`skills.json` stays empty, so the real game shows an honest
"No skills available yet." message with the real JP value still displayed.
Test fixtures are injected via `SkillDatabase.load_from_array()` and are never
loaded by production gameplay.
