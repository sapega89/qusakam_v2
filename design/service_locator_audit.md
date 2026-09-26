# Core Wiring Audit — `Engine.has_singleton("ServiceLocator")`

## The defect

Godot 4 autoloads are **nodes under `/root`**, not entries in the Engine
singleton registry. `Engine.has_singleton("ServiceLocator")` therefore returns
`false` **always**, and every guarded block behind it is dead code.

Correct pattern (now in `ServiceLocatorHelper.get_service_locator()`):

```gdscript
var main_loop := Engine.get_main_loop()
if main_loop is SceneTree and main_loop.root:
    return main_loop.root.get_node_or_null(^"ServiceLocator")
```

A second, related defect: `game_manager.has("player_state")`. `Object` has no
`has()` method in Godot 4 (`has_method("has")` → `false`), so the call raises and
aborts its enclosing function.

## Scope of this pass

| | |
|---|---|
| Occurrences at audit start | **94** |
| Fixed in Phases 5.1 / 5.3 | 4 |
| Fixed in this pass (5.2A) | **16** |
| **Remaining (deliberately held)** | **74** |
| `Object.has()` sites fixed | 8 |

Reachability was computed by crawling `project.godot` (main scene + 21 autoloads)
through `ext_resource` / `preload` / `uid://` links — 123 scripts reached — then
corrected by hand for runtime-loaded code the static crawl cannot see (save
modules instantiated via `class_name`, MetSys room scenes, shop opened by
`Merchant.gd`).

---

## Fixed — reachable, critical, semantics clear

### Save / load — **was completely broken**

| File | Function | Was | Now |
|---|---|---|---|
| `Save/Modules/PlayerDataModule.gd` | `_get_game_manager()` | returned `null` → `save()` returned `{}` — **player data never saved** | resolves; `save()` returns a populated payload incl. `equipment` |
| `Save/Modules/PlayerDataModule.gd` | `save()`, `load_data()` | `game_manager.has(…)` raised | `"…" in game_manager` |
| `Save/Modules/InventoryModule.gd` | `_get_game_manager()`, 2× `has()` | same | fixed |
| `Save/Modules/SettingsModule.gd` | `_apply_audio_settings()`, `_apply_display_settings()` | `elif Engine.has_singleton(…)` never taken → audio/display settings never applied on load | `else:` + helper |

**Coverage:** `verify_core_wiring.gd` §3–4 — asserts `save()` is non-empty,
contains `equipment`, reflects a live equipment change, and that `load_data()`
runs.

### Equipment / character (Phases 5.1, 5.3 — listed for completeness)

| File | Impact |
|---|---|
| `Core/ServiceLocatorHelper.gd` | every `BaseMenuComponent` had `game_manager == null` |
| `Gameplay/CharacterManager.gd` | `game_manager` null → `_sync_player_state_from_character()` returned early → **equipment lost on save** |
| `Gameplay/EquipmentManager.gd` | dependency resolution |
| `Systems/Character.gd` | `item_database` null → `get_equipment_stats()` all zeros → **equipping changed no stat** |

**Coverage:** `verify_equipment.gd` (32), `verify_status.gd` (20), `verify_core_wiring.gd` §2.

### UI core

| File | Sites | Subsystem | Was | Now |
|---|---|---|---|---|
| `Managers/UI/UIManager.gd` | 2 | UI state machine | dead guard | fixed |
| `Managers/UI/MenuManager.gd` | 4 | menu open/close, HUD hide/show | dead guard; HUD hide/show never ran | fixed |
| `Managers/UI/UIUpdateManager.gd` | 3 | HUD health bar / potion UI refresh | dead guard | fixed |
| `Components/base_menu.gd` | 1 | menu chrome, gold display | dead guard | fixed |
| `Menus/Game/game_menu.gd` | 1 of 2 | game menu | dead guard | fixed; **1 left deliberately** as a documented fallback after the `/root` lookup |
| `UI/States/options_state.gd` | 1 | options state | dead guard | fixed |
| `UI/GoldDisplay.gd` | 1 | gold readout | dead guard | fixed |

**Coverage:** `verify_inventory.gd` (30), `verify_status.gd` (20),
`verify_equipment.gd` (32), `verify_game_ui_theme.gd` (28) all exercise menu
open/close, HUD-adjacent paths and state switching.

---

## Held — NOT fixed, with reasons

Per instruction: *"Stop any fix that would activate behavior whose intended
semantics are unclear."*

| File | Sites | Subsystem | Reachable? | Why held |
|---|---|---|---|---|
| `Systems/SaveSystem_old.gd` | 11 | save/load | ❌ **dead** | Superseded by `SaveSystem.gd`; referenced only in a comment. Delete in a cleanup pass — do not repair. |
| `Shop/shop_ui.gd` | 6 | shop | ✅ via `Merchant.gd` | Whole shop subsystem is dormant. Waking it enables buy/sell against `InventoryManager` with no current test coverage. **Needs its own phase.** |
| `Shop/buy_item_list_display.gd` | 3 | shop | ✅ | same |
| `Shop/sell_item_list_display.gd` | 3 | shop | ✅ | same |
| `Shop/tooltip.gd` | 2 | shop | ✅ | same |
| `Gameplay/DefaultEnemy.gd` | 4 | combat | ✅ via room scenes | Would wake enemy↔manager wiring mid-combat. Unclear whether damage/XP paths double-fire. **GAMEPLAY RISK.** |
| `Gameplay/Potion.gd` | 2 | items/combat | ✅ | Potion consumption semantics unverified. |
| `Gameplay/RelicArmor.gd` | 1 | items | ⚠️ no scene found | Likely dead; confirm before touching. |
| `Gameplay/Scenes/Canyon.gd` | 3 | world/triggers | ✅ | Room scripts gate progression. Unclear which triggers become live. |
| `Gameplay/Scenes/CityGates.gd` | 2 | world/triggers | ✅ | same |
| `Gameplay/Scenes/Laboratory.gd` | 2 | world/triggers | ✅ | same |
| `Gameplay/Scenes/LaboratoryOutside.gd` | 3 | world/triggers | ✅ | same |
| `Managers/Debug/DebugManager.gd` | 3 | debug | ✅ autoload | Waking it may enable debug overlays/cheats in a shipped build. **Confirm intent first.** |
| `Managers/Story/GameFlow.gd` | 1 | quests/story | ✅ autoload | Story progression semantics unclear. |
| `Managers/Audio/GameMusicManager.gd` | 2 | audio | ⚠️ no scene found | Music already plays via `MusicManager`; this may be a second, competing system. |
| `Managers/Scene/SceneManager.gd` | 1 | scene flow | ✅ autoload | Scene transitions — high blast radius, needs a dedicated test. |
| `Systems/LocalizationManager.gd` | 3 | i18n | ✅ autoload | Translations already load. Waking could change language resolution order. |
| `Systems/SettingsManager.gd` | 4 | settings | ✅ | Settings screen is Phase 5.9; fix it there with that screen's coverage. |
| `Menus/LoadGameMenu.gd` | 5 | save/load UI | ✅ | Load-game UI is its own screen phase. |
| `Menus/MainMenu.gd` | 1 | main menu | ✅ | Reached, but untested; bundle with the main-menu phase. |
| `Systems/DialogueRunner.gd` | 1 | dialogue | ⚠️ | Dialogue runs through DialogueQuest; this may be a parallel path. |
| `Systems/Cutscenes/CutsceneDialogueStep.gd` | 1 | dialogue | ⚠️ | same |
| `UI/DialogueUI.gd` | 1 | dialogue | ⚠️ no scene | Probably superseded by the addon UI. |
| `UI/InventoryUI.gd` | 1 | UI | ⚠️ no scene | Superseded by `inventory_component`. |
| `Components/ItemInfoTooltip.gd` | 1 | UI | ✅ scene exists | Not used by any implemented screen yet. |
| `Systems/Cutscenes/*`, misc | — | — | — | — |
| `Core/ServiceLocatorHelper.gd` | 2 | core | ✅ | **Intentional.** The `Engine.has_singleton` branch is kept as a *secondary fallback* after the `/root` lookup. |

### Recommended order for the held items

1. **Delete** `SaveSystem_old.gd` (dead, 11 sites vanish).
2. **Settings** + **LoadGameMenu** + **MainMenu** — fix alongside their UI phases.
3. **Shop** — one phase, with buy/sell/gold tests.
4. **Combat** (`DefaultEnemy`, `Potion`) — needs combat regression first.
5. **World/trigger scripts** — one room at a time, with progression tests.
6. **DebugManager**, **GameFlow**, **SceneManager**, **audio**, **dialogue** —
   each needs a product decision about what "on" should mean.

---

## Verification

```bash
godot --headless --path . --script res://SampleProject/UI/verify_core_wiring.gd
```

18 assertions: helper resolves the autoload and matches `/root/ServiceLocator`;
`Engine.has_singleton` still `false` (the bug is asserted, not assumed); manager
dependencies resolve; `PlayerDataModule.save()` non-empty, contains equipment and
tracks live changes; `load_data()` runs; `SettingsModule` API intact; no
`Object.has()` remains on the runtime save path.

Full suite after this pass — all green, boot clean:

| Suite | Result |
|---|---|
| `verify_game_ui_theme` | 28 ✅ |
| `verify_core_wiring` | 18 ✅ |
| `verify_inventory` | 30 ✅ |
| `verify_status` | 20 ✅ |
| `verify_equipment` | 32 ✅ |
