---
type: report
status: done
tags: [cloud, settings, cleanup, dialogue, theme]
---

# Cloud report — settings-cleanup (BACKLOG 41, 39, 35)

Branch `cloud/settings-cleanup` (from `origin/feature/backlog`). Godot 4.6.2 headless, Linux. No display:
layouts are described in words, not captured.

## 1. What was built

### 39 — Cleanup (commit "Cleanup: delete Maps/Legacy and the ranged stubs")
- Deleted `SampleProject/Maps/Legacy/` (18 maps, Q34), `Scripts/Gameplay/Characters/Enemies/EnemyRanged.gd` (+ `.uid`),
  `Scenes/Gameplay/Projectiles/player_projectile.tscn` and its only script `Scripts/Gameplay/Projectiles/PlayerProjectile.gd`
  (+ `.uid`) (Q35).
- Reference sweep before deleting (scenes, scripts, `.tres`, `MapData.txt`, `Settings.tres`, `export_presets.cfg`, verifies):
  none of the 17 Legacy uids is a cell in `SampleProject/Maps/MapData.txt`, `StartingRoom.tscn` has no uid; nothing loads
  `res://SampleProject/Maps/Legacy/…`; `EnemyRanged` / `PlayerProjectile` had no users. `UpperElevatorRoom`'s uid
  `dkcgx06o6celq` was also used by `Extensions/ModernMap/…/UpperElevatorRoom.tscn` (a duplicate uid — gone now).
  `DemoBoss.gd` (also named in Q35) no longer exists on this branch.
- Left in place (not in the BACKLOG 39 list, no decision to delete): world-object scenes now referenced by nothing —
  `Objects/{Button, Elevator, MapItem, MiniPortal, Pipe, Portal, Spikes}.tscn`, `Objects/Dice.glb`,
  `Scripts/Gameplay/EnemyWithCollectibleDrop.gd`. `Objects/Elevator.tscn:6` still has a comment naming the deleted
  ElevatorRoom maps. See D-text 4.

### 41 — Graphics settings + one selection look (commit "Settings: Resolution and Frame Rate Limit, …")
- `SampleProject/Scripts/Systems/DisplayManager.gd:14,16` — `RESOLUTIONS` (1280x720, 1600x900, 1920x1080, 2560x1440) and
  `FPS_LIMITS` (30, 60, 120, 144, 0 = unlimited); `:64 set_resolution()` sizes and centres the window (Windowed only);
  `:78 set_fps_limit()` → `Engine.max_fps`; `:89 apply_display_settings()` reads every key (no `has()` fallbacks),
  mode first, then size. Unknown values `push_error` and change nothing.
- `SampleProject/Scripts/Systems/Save/Modules/SettingsModule.gd:16-17` — keys `resolution` ("1920x1080") and
  `fps_limit` (60) = the `project.godot` defaults (viewport 1920×1080, `run/max_fps=60`). They ride the existing
  slot persistence and are applied on start by `SaveSystem.load_game_settings()` → `apply_settings()`.
- `SampleProject/Scripts/Menus/Game/options_component.gd:158,165` — Display tab, Figma order: Display Mode ·
  Resolution · VSync · Frame Rate Limit. `:240 _add_stepper_row()` is the Figma Stepper archetype (17:280):
  `‹` · 280 px value (`SETTINGS_STEPPER_WIDTH`) · `›`, wraps around, updates in place (no list rebuild, so keyboard /
  gamepad focus stays on the chevron). Chevrons are ordinary focusable Buttons (`SettingsStepper`): mouse click, Enter,
  pad A. In Fullscreen the Resolution chevrons are disabled and the value is drawn `TEXT_DISABLED`.
  Layout in words: each row 68 px high, label left; the stepper sits on the right where the segment cells sit on the
  other rows, values read "1920 × 1080", "60 FPS", "Unlimited".
- **One selection look (Q33):** `SampleProject/UI/Tokens/UITokens.gd:51-54` — `FOCUS_RING` (accent), `FOCUS_RING_ON_ACCENT`
  (white), `FOCUS_RING_WIDTH` (2). `SampleProject/UI/build_game_ui_theme.gd:105 _focus_ring()` is now the only source of
  every Button variation's `focus` stylebox: a 2px ring with no fill, drawn by Godot over the button's own state.
  Unified (before → after):
  - `MiscRow`/`MiscRowOn` (Misc menu): focus = brighter gradient → ring (the gradient stays as the selected look via
    `misc_menu_modal.gd:37`).
  - `MainMenuItem`/`MainMenuItemOn` (main menu, `MainMenu.gd:62`): focus = nothing (chevron + white text only) → ring.
  - `NpcMenuItem`/`NpcMenuItemOn` (NPC action menu `npc_action_menu.gd:41`, Game Over `game_over_screen.gd:69`):
    chevron + text alpha only → ring.
  - `FilterButton`: focus = same as normal (invisible on a pad) → ring (radius 3 like the button).
  - `SidebarTab`: hover fill + ring → ring only. `SettingsSegment(On)`: fill + ring → ring (white on the selected cell).
  - `PrimaryButton`, `ShopCategoryOn`: white ring (on accent). `ShopRow`/`ShopRowOn`: keeps the accent fill (its dark
    `…On` text needs it) plus a white ring.
  - Already a 2px accent ring, now through the helper: `Button`, `ListRow`/`ListSubRow`, `TabButton`, `IconButton`,
    `SettingsStepper`, `SettingsSidebarTab`, `CardSelect`, `ShopCategory`, `SaveSlotCard`.
  - `SkillRow` already matches the ring exactly; its builder lines were left untouched (Skills screen is another
    branch's area). `LineEdit` focus is a text field, not a menu row — unchanged.
  - No scene or script overrides a `focus` stylebox locally (grep of `.tscn` / `.gd`); the per-menu differences were all
    in the builder. The scripts above only swap variations (selected look), which stays.
- **`GameUITheme.tres` is NOT committed — Sapega must regenerate it on his machine:**
  `godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd`. Until then
  `verify_game_ui_theme` [3c] fails on the committed `.tres` (MiscRow etc. still old).

### 35 — NPC chatter in speech clouds (commit "NPC chatter in speech clouds")
- Where chatter is shown today: **nowhere** — no NPC says anything in passing. NpcBase / StoryNpc / OathKeeper only
  start talks from the NPC menu (box); TutorialManager hints are HUD banners, not NPC speech; DialogueManager's clouds are
  Kusakam's monologues (D178) and cutscene cloud talks (D263). No `.dqd` holds ambient lines.
- Built the route, no content: `SampleProject/Scripts/Systems/DialogueManager.gd:368 say_in_passing(speaker, path, anchor)`
  — the D263 `speech_bubble.gd` as a child of the NPC, lines timed by `seconds_for()` (pause holds them), not a dialogue
  (`is_dialogue_active()` stays false, hero and menus free, never queued); refused while any talk runs. Any real talk
  closes all chatter clouds (`:99`, in `start_dialogue`); `:400 end_chatter()`.
- `SampleProject/Scripts/Gameplay/NPCs/NpcBase.gd:23` `@export chatter_dialogue` (empty = silent); `:138` said once per
  room visit when the hero enters the interaction area (retried on the next approach if a talk was running);
  `:146 chatter_anchor()` = top centre of the NPC's sprite; `:120` opening the NPC menu ends the chatter. Talk / Quest
  keep the dialogue box.
- No NPC has `chatter_dialogue` set — there are no lines to show. See Q-text below.

## 2. Decisions (agent calls, Sapega to confirm) — ready to paste

- **D3xx (BACKLOG 41, Resolution):** Resolution is the **window size in Windowed mode**: 1280×720, 1600×900, 1920×1080
  (default), 2560×1440; the window is centred on its screen. Fullscreen always uses the screen's native resolution
  (`canvas_items` stretch scales the 1920×1080 viewport), so the row is locked (chevrons disabled, value greyed) while
  Fullscreen is on; the stored value comes back on Windowed. Stored as `"WxH"` in SettingsModule `resolution`.
  — agent call, Sapega to confirm.
- **D3xx (BACKLOG 41, Frame Rate Limit):** 30 / 60 (default = `project.godot run/max_fps`) / 120 / 144 / Unlimited →
  `Engine.max_fps`; SettingsModule `fps_limit`, 0 = unlimited. VSync still caps at the monitor's refresh when on.
  Both rows are the Figma Stepper (‹ value ›, wraps around). — agent call, Sapega to confirm.
- **D3xx (Q33, one selection look):** the focused / selected row in every menu shows the same **2px accent ring with no
  fill** (`UITokens.FOCUS_RING*`, builder `_focus_ring()`), drawn over the row's own look; on accent-filled controls
  (Primary button, active shop category, selected settings segment, shop row) the ring is white so it stays visible.
  Menu-specific "selected" looks stay as they are (main / NPC menu chevron + bright text, Misc lighter gradient, shop
  accent fill) — the ring is the shared part. — agent call, Sapega to confirm.
- **D3xx (BACKLOG 39):** only the 18 Legacy maps and the ranged stubs were deleted. The world-object scenes that only
  Legacy maps placed (`Objects/{Button, Elevator, MapItem, MiniPortal, Pipe, Portal, Spikes}.tscn`, `Dice.glb`,
  `EnemyWithCollectibleDrop.gd`) stay as a parts bin (Q34 named them; the answer named only the maps). — agent call,
  Sapega to confirm or ask for them gone.
- **D3xx (BACKLOG 35, Q48):** an NPC's line said in passing (hero walks up, no menu) is shown in the D263 cloud over the
  NPC's sprite, once per room visit, never during another talk; it is not a dialogue (hero walks, menus open, nothing
  queued). Any talk the player starts — NPC menu Talk / Quest, story dialogue — uses the dialogue box and closes the
  cloud. Lines live in a `.dqd` set per NPC (`NpcBase.chatter_dialogue`). — agent call, Sapega to confirm.

## 3. New bugs — ready to paste

- **B-new (settings, gamepad):** pressing a segment cell on a Settings row (Display Mode, VSync, Language, Tutorial
  Windows) rebuilds the whole list (`options_component.gd` `_on_*_changed` → `_rebuild_list()`), freeing the focused
  cell — keyboard / gamepad focus is lost after every toggle. The new stepper rows avoid it (update in place). Fix: update
  the cells in place or re-grab focus on the same row after the rebuild.
- **B-new (theme, minor):** a `ListRow` in its pressed (selected, accent-filled) state shows no visible focus ring —
  the accent ring sits on an accent fill and the `focus` stylebox cannot know the pressed state. Only matters where a
  selected row and the cursor can differ (inventory / journal lists).

## 4. Question for Sapega (non-blocking — the route is built, it just has nothing to say)

- **Q-new (BACKLOG 35):** no NPC has chatter lines. Who says what in passing, and in which language (dialogue `.dqd`
  is Ukrainian today)? Candidates: the City Gates guards, the caravan merchant on the road, the smith at the forge, the
  oath NPCs. Each needs a `.dqd` and `chatter_dialogue` set on its scene.

## 5. Verifies run

| Verify | RESULT |
|---|---|
| verify_scripts_compile (after cleanup) | ALL PASS |
| verify_map_geometry (after cleanup) | ALL PASS |
| verify_settings_graphics (new) | ALL PASS |
| verify_settings | ALL PASS |
| verify_game_ui_theme (with the regenerated theme, local) | ALL CHECKS PASSED |
| verify_main_menu | ALL PASS |
| verify_misc_modal | ALL PASS |
| verify_shop | ALL PASS |
| verify_game_menu | ALL PASS |
| verify_game_over | ALL PASS |
| verify_save_load | ALL PASS |
| verify_gamepad | ALL PASS |
| verify_npc_chatter (new) | ALL PASS |
| verify_npc_activity | ALL PASS |
| verify_npc_arrival | ALL PASS |
| verify_npc_recall | ALL PASS |
| verify_interaction | ALL PASS |
| verify_cutscene | ALL PASS |
| verify_tasks | ALL PASS |

Full suite (`Scripts/Tools/run_verify.sh`, regenerated theme in the working tree, not committed):

**69 PASS, 2 FAIL** on the first run (`SUITE: 2 FAIL`), then both fixed / re-run:
- `verify_full_regression` — `leaked: ["Frame Rate"]`: its forbidden-term list still treated Frame Rate as a deferred
  Settings row. BACKLOG 41 ships it, so the term was removed (`verify_full_regression.gd:141`) → re-run **ALL PASS**.
- `verify_audio` — `FAIL focusing a button (pad navigation) ticks on SFX` once; re-run on this branch **ALL PASS**,
  and **ALL PASS** on `origin/feature/backlog` too. Not reproduced: a one-off timing flake of the focus-tick check
  (`verify_audio.gd:276` reads `playing` one frame after `grab_focus()`). Worth watching; no code of this branch touches
  `ProjectUISoundController`.

Every other verify: PASS.

Headless noise seen (test_baseline): `Not supported by this display server` from `keyboard_get_keycode_from_physical`
when the Controls tab builds; exit 139 / leaks at shutdown.
`Scripts/Tools/godot_locked.sh` and `run_verify.sh` are not executable in the repo (mode 644) — on Linux the suite only
runs after `chmod +x` (not committed).

## 6. What is left

- Regenerate `GameUITheme.tres` on Sapega's machine (command above) and commit it there; rebuild the exe.
- Live-display check of Resolution (window really resizes / centres) and the focus ring in each menu — not possible
  headless here; `verify_settings_graphics` checks the window size only with a live driver.
- Chatter lines (Q-new) — then set `chatter_dialogue` on those NPC scenes.
- B-new focus loss on segment rows; the orphan world-object scenes (D-text 4).
- Register the D / B / Q texts above (orchestrator).
