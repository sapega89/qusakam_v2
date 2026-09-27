# CLAUDE.md

@docs/CLAUDE.md

# UI Implementation Rules

Figma is the visual source of truth.
Existing Godot gameplay code is the behavioral source of truth.

- Do not redesign the UI.
- Do not rewrite working gameplay systems just to fit the design.
- Reuse existing scenes, managers and signals whenever possible.
- All screens must use shared reusable UI components and one common Godot Theme.
- Never hardcode duplicate colors, font sizes, borders or spacing when a shared
  token/component can be used.
- Implement one screen at a time.
- Do not remove existing functionality unless explicitly instructed.
- Do not modify `main` directly. Use a feature branch.

## Before changing a screen

1. Inspect its Figma frame
2. Inspect the existing Godot scene/script
3. Document the mapping
4. Only then implement

## After implementing

1. Run Godot
2. Check for errors
3. Capture/inspect the rendered UI
4. Compare against Figma
5. Fix visual differences
6. Test navigation and gameplay integration

## Where these rules point

- **Common Theme:** `SampleProject/UI/Themes/GameUITheme.tres`.
  Generated from `SampleProject/UI/Tokens/UITokens.gd` — edit the tokens, then run
  `godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd`.
  Do not hand-edit the `.tres`; regeneration overwrites it.
  Scope: applied at `Scenes/UI/ui_root.tscn → UILayer/StateRoot` and
  `Scenes/UI/modal_layer.tscn → ModalLayer/Container`, so all UIManager states and
  modals inherit it. `project.godot` deliberately does **not** set
  `gui/theme/custom` — see `design/ui_theme_scope_audit.md` before changing that.
  Verify with `godot --headless --path . --script res://SampleProject/UI/verify_game_ui_theme.gd`.
  (`SampleProject/Resources/UI/ui_theme.tres` is an empty legacy stub, unreferenced
  by any scene or script; `assets/themes/*.theme` are stock third-party themes.)
- **Inspect Figma frame:** Figma MCP — `get_design_context`, `get_screenshot`,
  `get_metadata`, `get_variable_defs`. Load the `figma-design-to-code` skill first.
- **Run Godot:** `godot --path . res://SampleProject/MainMenu.tscn`
  (Godot 4.6 — the binary is not on PATH in this environment.)
- **Errors:** Godot stderr + `DebugLogger.error(...)` output.
- **Tests:** `godot --headless --path . --script res://SampleProject/UI/verify_<area>.gd` for each
  `verify_*.gd`; read the `RESULT:` line (every run exits 139 — see `design/test_baseline.md`).
  GUT has no tests in this project.
