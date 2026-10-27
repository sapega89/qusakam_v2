---
type: report
tags: [cloud, plugins, S4]
---

# plugins-fsm — MASTER_PLAN S4, slice 1 of 3 (2026-10-27)

**Summary**
- Done: `addons/fsm` and `addons/interaction_system` are deleted; the UI uses our own `SampleProject/Scripts/UI/States/ui_state_machine.gd`.
- interaction_system had no user: every `Interactable` node in the rooms runs our own `InteractableComponent.gd`, and no script or scene referenced `Activator` or the addon `Interactable` (class names, paths, uids).
- Not done (out of scope): slice 2 ModalDialog, slice 3 our own menus instead of Maaack (D242).
- D-ID text for the orchestrator (D780, numbered by integrate-28): «**S4 slice 1 — no third-party fsm / interaction_system.** The UI state machine is ours (`Scripts/UI/States/ui_state_machine.gd`, preloaded, no class_name): one active UIState, NullState (first child in ui_root.tscn) on start, `change_state()` exits the old state and enters the new one; UIManager frees the old state as before. interaction_system was dead code and is deleted.»
- B rows fixed: none. Maps untouched.
- Full suite: `SUITE: ALL PASS` (132 verify scripts).

## What changed
- `ui_state_machine.gd` (new): `state: UIState`, `_ready()` → `change_state(get_child(0))`, `change_state()` = `_exit_state()` on the old, `_enter_state()` on the new. The addon also toggled `set_physics_process` on states and set `actor`; every state's `_physics_process` was an empty `pass` and nothing read `actor`, so both are dropped (behaviour unchanged).
- `ui_state.gd`: `extends Node` instead of `addons/fsm/FSMState.gd`; the empty `_physics_process` stubs are removed from `ui_state.gd`, `null_state.gd`, `game_menu_state.gd`, `save_game_state.gd`.
- `ui_root.tscn`: the StateMachine node's script points at the new file. `ui_root.gd`, `UIManager.gd`: typed with the preloaded script; `state_machine.get("state")` / `_change_state` → `state_machine.state` / `change_state`; the null guards on `state_machine` went away (it is always built by `_ensure_ui_root()`).
- `docs/CLAUDE.md` «Addons»: fsm / interaction_system mention replaced.
- Not edited (orchestrator's): `design/BACKLOG.md:358` and `design/MASTER_PLAN.md` S4 row still name fsm / interaction_system as next work — mark slice 1 done.

## Tests
verify_game_ui_theme (`ALL CHECKS PASSED`), verify_scripts_compile, verify_interaction, verify_game_menu, verify_main_menu,
verify_menu_after_room_change, verify_misc_modal, verify_pause, verify_save_load, verify_save_load_room, verify_inventory,
verify_journal, verify_journal_notes, verify_journal_sections, verify_story_journal, verify_skills_ui, verify_skill_trees_ui,
verify_equip_picker, verify_equipment, verify_enchanted_equip, verify_quiet_transitions — all `RESULT: ALL PASS`.
Full suite `Scripts/Tools/run_verify.sh`: `SUITE: ALL PASS`.
