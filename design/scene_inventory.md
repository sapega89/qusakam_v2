---
type: audit
status: reference
tags: [audit, scenes, orphans]
---

# Scene inventory — what should exist, what does, what is missing

The project has 121 `.tscn` files under `SampleProject/` and has never had a list
to check them against. This note is that list. Vault conventions: [[INDEX]].

Verified 2026-09-29 by grep against the tree, not against any document. Where a
document and the grep disagree, the grep is recorded and the document is named in
[[#What this changes]].

## Method — how "used" was proven

Every `[ext_resource]` in this project carries both a `path=` and (mostly) a
`uid=`, so a scene is referenced in exactly four ways, all greppable:

| Reference form | Where it appears |
|---|---|
| `res://…/x.tscn` | `.tscn` / `.tres` / `.gd` / `project.godot` |
| `uid://<hash>` | `.tscn` / `.tres` headers |
| bare `<hash>` (no `uid://`) | **`SampleProject/Maps/MapData.txt`** — how MetSys binds a room cell to a scene. Missing this form makes all 26 map scenes look orphaned. |
| `preload`/`load` string | `.gd` |

Two traps this audit hit, both of which defeat a naive grep:

1. **A declared `ext_resource` is not an instanced node.**
   `ObjectiveHUD.tscn` is declared at `SampleProject/Game.tscn:15` and never
   appears in any `[node … instance=ExtResource("10_objective")]`. It is the only
   dangling `PackedScene` `ext_resource` in the project (checked all 121). Filed
   as [[BUGS]] **B42**.
2. **A scene whose only reference is `preload` of itself, inside its own script,
   in a function nobody calls.** `Scenes/Objects/potion.tscn` →
   `Scripts/Gameplay/Potion.gd:126` inside `spawn_potion()`, zero callers.
   Same shape: `Scenes/UI/yes_no_dialog.tscn` → `Scripts/UI/YesNoDialog.gd:61`.
   Both are orphans, not uses.

Counterexample — a static factory that *is* a use: `game_over_screen.tscn` is
loaded from `Scripts/UI/game_over_screen.gd:11`, whose `present()` is called at
`SampleProject/Scripts/Player.gd:198`.

## States

| State | Rule |
|---|---|
| ✅ **exists and is used** | File exists AND something outside it and outside `UI/verify_*.gd` / `UI/capture_*.gd` instantiates or loads it |
| ⚠️ **exists, unused** | File exists, nothing reaches it in play. Includes test-only, Legacy-map-only, and self-referencing scenes |
| ❌ **required, missing** | A D-ID, a Figma frame or a shipped script requires it and no file exists |

A scene reachable **only** through `Maps/Legacy/` is ⚠️: no Legacy map appears in
`MapData.txt`, so none of them is reachable in play (see [[#4. Maps]]).

## Totals

| | ✅ used | ⚠️ unused | Files |
|---|---|---|---|
| [[#1. Gameplay]] | 8 | 13 | 21 |
| [[#2. UI]] | 47 | 13 | 60 |
| [[#3. NPCs]] | 0 | 2 | 2 |
| [[#4. Maps]] | 8 | 18 | 26 |
| [[#5. Systems and roots]] | 12 | 0 | 12 |
| **Total** | **75** | **46** | **121** |

**38% of this project's scenes are unreachable in play.** Plus 11 ❌ rows in
[[#6. Required and missing]].

The single largest finding is in §1: **not one of the ten `Objects/*.tscn`
scenes is placed in any of the eight production maps.** All world-object content
— pickups, portals, hazards, buttons, elevators — exists only inside the 18 dead
Legacy maps. This is the mechanical cause of [[BACKLOG]]'s "no production map
grants an inventory item" (Q2 / D88), and it is broader than that row states.

---

## 1. Gameplay

| Scene | Path or — | State | Evidence | Source that requires it |
|---|---|---|---|---|
| Player | `SampleProject/Player.tscn` | ✅ | `SampleProject/Game.tscn:6` | the game |
| Default enemy | `Scenes/Characters/Enemies/default_enemy.tscn` | ✅ | `Scripts/Gameplay/EnemySpawnPoint.gd:74` (hard-coded path); also `Maps/Legacy/EndingPoint.tscn:5` | 4 production maps place `EnemySpawnPoint` nodes |
| Coin | `Scenes/Gameplay/Objects/Coin.tscn` | ✅ | `Scripts/Gameplay/DefaultEnemy.gd:6` | enemy loot, automatic (D88) |
| Death particles | `Scenes/FX/DeathParticles.tscn` | ✅ | `Scripts/Gameplay/DefaultEnemy.gd:8` | — |
| Hit impact | `Scenes/FX/HitImpact.tscn` | ✅ | `Scripts/Gameplay/DefaultEnemy.gd:7` | — |
| Slash trail | `Scenes/FX/SlashTrail.tscn` | ✅ | `Scripts/Player.gd:5` | — |
| Level-up flash | `Scenes/FX/LevelUpFlash.tscn` | ✅ | `Scripts/Player.gd:6` | — |
| Level-up particles | `Scenes/FX/LevelUpParticles.tscn` | ✅ | `Scripts/Player.gd:7` | — |
| Item pickup | `Objects/ItemPickup.tscn` | ⚠️ | only `UI/verify_interaction.gd:10`. No map places it | **D71, D88, D86** — built in slice 1a, never placed. [[BACKLOG]] *Agreed but never built* |
| Collectible (orb) | `Objects/Collectible.tscn` | ⚠️ | 8 Legacy maps only, e.g. `Maps/Legacy/Corridor.tscn:5` | Legacy demo |
| Portal | `Objects/Portal.tscn` | ⚠️ | 4 Legacy maps only, e.g. `Maps/Legacy/PortalRoom.tscn:5` | Legacy demo; production maps use MetSys `RoomInstance` borders |
| Mini portal | `Objects/MiniPortal.tscn` | ⚠️ | `Maps/Legacy/DarkStaircase.tscn:5`, `Maps/Legacy/SecretChamber.tscn:6` | Legacy demo |
| Pipe | `Objects/Pipe.tscn` | ⚠️ | 4 Legacy maps only, e.g. `Maps/Legacy/ElevatorRoom.tscn:5` | Legacy demo |
| Elevator | `Objects/Elevator.tscn` | ⚠️ | `Maps/Legacy/ElevatorRoom.tscn:6`, `Maps/Legacy/UpperElevatorRoom.tscn:6` | Legacy demo |
| Button | `Objects/Button.tscn` | ⚠️ | `Maps/Legacy/LeftStaircase.tscn:5` | Legacy demo |
| Map item | `Objects/MapItem.tscn` | ⚠️ | `Maps/Legacy/RightStaircase.tscn:5` | Legacy demo |
| Spikes | `Objects/Spikes.tscn` | ⚠️ | `Maps/Legacy/StartingPoint.tscn:7` | Legacy demo |
| Lava hazard | `Objects/LavaHazard.tscn` | ⚠️ | **zero references**, including Legacy. Script `Scripts/Hazard.gd` | none |
| Combat zone | `Scenes/Gameplay/CombatZone.tscn` | ⚠️ | **zero references**. 25 lines, script `Scripts/Gameplay/CombatZone.gd` | none |
| Player projectile | `Scenes/Gameplay/Projectiles/player_projectile.tscn` | ⚠️ | **zero references.** `EnemyRanged.gd:6` declares `projectile_scene: PackedScene = null` and nothing ever assigns it | see **Q35** |
| Potion (world) | `Scenes/Objects/potion.tscn` | ⚠️ | self-preload only: `Scripts/Gameplay/Potion.gd:126` in `spawn_potion()`, **zero callers** | none |

**System without content, deliberately:** enemy variety is not scenes. One
`default_enemy.tscn` plus three `EnemyStats` resources
(`Resources/Enemies/enemy_stats_{melee,fast,tank}.tres`) selected by the map's
`enemy_type` property — `Maps/CityGates.tscn:75` `enemy_type = "melee"`. No
`enemy_ranged` or boss resource exists, which is why `EnemyRanged.gd` and
`DemoBoss.gd` have no scenes (**Q35**). The "boss fight" in
`Scripts/Gameplay/Scenes/Laboratory.gd:180-186` spawns ordinary enemies.

## 2. UI

### 2.1 Game Menu and its tabs

| Scene | Path or — | State | Evidence | Source that requires it |
|---|---|---|---|---|
| Game menu | `Scenes/Menus/Game/game_menu.tscn` | ✅ | `Scripts/Managers/UI/MenuManager.gd:9`, `Scripts/UI/States/game_menu_state.gd:4` | Figma `316:7708` |
| Game menu content | `Scenes/Menus/Game/game_menu_content.tscn` | ✅ | `Scenes/Menus/Game/game_menu.tscn:5` | — |
| Base menu (shared chrome) | `Scenes/Menus/Game/base_menu.tscn` | ✅ | `game_menu.tscn:4`, `Scenes/Shop/shop_menu.tscn:5` | D49 (shared chrome) |
| Vertical tab menu | `Scenes/UI/vertical_tab_menu.tscn` | ✅ | `game_menu_content.tscn:3`; script `Scripts/Menus/Game/panel_manager.gd` | — |
| Inventory | `Scenes/Menus/Game/inventory_component.tscn` | ✅ | `game_menu_content.tscn:4` | Figma `46:193` |
| Equipment | `Scenes/Menus/Game/equipment_component.tscn` | ✅ | `game_menu_content.tscn:5` | Figma `58:4` + `258:5110/5111` (D20) |
| World map | `Scenes/Menus/Game/metsys_map_component.tscn` | ✅ | `game_menu_content.tscn:6` | D42 |
| Journal | `Scenes/Menus/Game/journal_component.tscn` | ✅ | `game_menu_content.tscn:7` | D52–D60 |
| Status | `Scenes/Menus/Game/stats_component.tscn` | ✅ | `game_menu_content.tscn:8` | Figma `58:719` |
| Settings / Misc | `Scenes/Menus/Game/options_component.tscn` | ✅ | `game_menu_content.tscn:9`, `Scripts/Menus/MainMenu.gd:312` | D49, D66 |
| Skills | `Scenes/Menus/Game/skills_component.tscn` | ✅ | `game_menu_content.tscn:10` | Figma `58:453` |
| Misc modal | `Scenes/Menus/Game/misc_menu_modal.tscn` | ✅ | `Scripts/Menus/Game/game_menu.gd:16` | Figma `58:1246`, D62–D64 |
| Input options (maaacks) | `Scenes/Menus/Game/input_options_menu.tscn` | ✅ | `options_component.tscn:4` | D48 |
| Tutorial page | `Scenes/Menus/Game/tutorial_menu.tscn` | ✅ **stub** | `Scripts/Menus/Game/game_menu.gd:18`. 20 lines, one centred `Label` "Tutorial", no script | Figma `135:1260`. Content unbuilt: [[BACKLOG]] *Tutorial menu page*; navigation broken: [[BUGS]] B2 |
| Vertical menu (legacy dup) | `Scenes/Menus/Game/vertical_menu.tscn` | ⚠️ | **zero references.** 194 lines, shares `panel_manager.gd` with the live `vertical_tab_menu.tscn` | none — duplicate |
| Right panel | `Scenes/Menus/Game/right_panel_component.tscn` | ⚠️ | **zero references.** 116 lines | none |
| Timer panel | `Scenes/Menus/Game/timer_panel.tscn` | ⚠️ | **zero references** | [[figma_coverage]] §F: "`timer_panel.tscn` is dead" — confirmed |
| Sub-location selection | `Scenes/Menus/Game/sub_location_selection.tscn` | ⚠️ | **zero references.** 53 lines | none |
| Base menu (older dup) | `Scenes/Components/base_menu.tscn` | ⚠️ | **zero references.** 232 lines, script `Scripts/Components/base_menu.gd` — distinct from the live `Scenes/Menus/Game/base_menu.tscn` | none — duplicate |
| Item info tooltip | `Scenes/Components/item_info_tooltip.tscn` | ⚠️ | **zero references**; `Scripts/Components/ItemInfoTooltip.gd` has no callers | D8 / D29 killed it (details live in the shared bottom bar) |

Sidebar has **7** tabs (`game_menu_content.tscn:25-43`); Figma has 9. Healing and
Jobs are ❌ rows below (D65).

### 2.2 Flow screens, HUD, modals

| Scene | Path or — | State | Evidence | Source that requires it |
|---|---|---|---|---|
| Main menu / Splash | `SampleProject/MainMenu.tscn` | ✅ | `project.godot:22` `run/main_scene` | Figma `9:26`, `258:5140`, D72 |
| Save / Load slot selection | `Scenes/Menus/LoadGameMenu.tscn` | ✅ | `Scripts/Menus/MainMenu.gd:8`, `Scripts/UI/States/load_game_state.gd:4`, `Scripts/UI/States/save_game_state.gd:4` | D75, D80 |
| Shop | `Scenes/Shop/shop_menu.tscn` | ✅ | `Scripts/Gameplay/NPCs/Merchant.gd:45` | Figma `153:1289/1523/1760` |
| Game Over | `Scenes/UI/game_over_screen.tscn` | ✅ | `Scripts/UI/game_over_screen.gd:11`, presented from `Scripts/Player.gd:198` | Figma `41:83`, D92 (third button still missing) |
| Demo end screen | `Scenes/UI/DemoEndScreen.tscn` | ✅ | `Scripts/Gameplay/Scenes/LaboratoryOutside.gd:127` | no Figma design ([[figma_coverage]] §F NONE) |
| UI root | `Scenes/UI/ui_root.tscn` | ✅ | `Scripts/Managers/UI/UIManager.gd:4` | theme scope, [[ui_theme_scope_audit]] |
| Modal layer | `Scenes/UI/modal_layer.tscn` | ✅ | `Scenes/UI/ui_root.tscn:4` | D79 |
| Modal dialog | `Scenes/UI/modal_dialog.tscn` | ✅ | `Scenes/UI/modal_layer.tscn:4` | Figma `258:5332`, D76/D79 |
| UI states ×7 | `Scenes/UI/States/{main_menu,game_menu,options,load_game,save_game,modal,null}_state.tscn` | ✅ | `Scripts/Managers/UI/UIManager.gd:6-12`; `null_state` also `ui_root.tscn:6` | UIManager state machine |
| Combat HUD — top | `UI/Components/combat_hud_top.tscn` | ✅ | `SampleProject/Game.tscn:18` | Figma `434:6580/6586` |
| Combat HUD — vitals | `UI/Components/player_vitals_panel.tscn` | ✅ | `SampleProject/Game.tscn:17` | Figma `434:6558` |
| Combat HUD — hotbar | `UI/Components/skill_hotbar.tscn` | ✅ | `SampleProject/Game.tscn:16` | Figma `437:6405` |
| Bottom bar | `UI/Components/bottom_bar.tscn` | ✅ | `Scenes/Menus/Game/base_menu.tscn:7`, `Scenes/Menus/LoadGameMenu.tscn:7`, `UI/Components/menu_shell.tscn:4` | Figma `121:1073` |
| Party status panel | `UI/Components/party_status_panel.tscn` | ✅ | `Scenes/Menus/Game/base_menu.tscn:6` | Figma `68:1177`, D51 |
| Interaction prompt | `UI/Components/interaction_prompt.tscn` | ✅ | `Scripts/Gameplay/Components/InteractableComponent.gd:15` | Figma `461:6479`, D74, D84, D98 |
| Item row | `UI/Components/item_row.tscn` | ✅ | `Scripts/Menus/Game/inventory_component.gd:10` | Figma `222:4827` |
| Shop row | `UI/Components/shop_row.tscn` | ✅ | `Scripts/Shop/shop_ui.gd:14` | Figma `153:1289` |
| Save slot card | `UI/Components/save_slot_card.tscn` | ✅ | `Scripts/Menus/LoadGameMenu.gd:15` | Figma `217:3038`, D89 (rework) |
| Level-up notification | `Scenes/UI/level_up_notification.tscn` | ✅ | `SampleProject/Game.tscn:11` | **no Figma design** ([[figma_coverage]] §F NONE) |
| Combat context display | `Scenes/UI/CombatContextDisplay.tscn` | ✅ | `SampleProject/Game.tscn:13` | **no Figma design** |
| Tutorial hint (in-game) | `Scenes/UI/TutorialHintDisplay.tscn` | ✅ | `SampleProject/Game.tscn:14`; driven by `Scripts/Managers/TutorialManager.gd` | **no Figma design** — `135:1260` is the menu page, not this |
| Enemy health bar | `Scenes/UI/enemy_health_bar.tscn` | ✅ | `Scripts/Gameplay/DefaultEnemy.gd:142` | **no Figma design** |
| Health bar (legacy) | `Scenes/UI/health_bar.tscn` | ✅ | `SampleProject/Game.tscn:9` **`visible = false`** (`:252`); also `Scripts/Player.gd:277`, `enemy_health_bar.tscn:4` | superseded by `434:6558`; [[figma_coverage]] says *remove, do not restyle* |
| XP bar (legacy) | `Scenes/UI/xp_bar.tscn` | ✅ | `SampleProject/Game.tscn:10` **`visible = false`** (`:268`) | same |
| Coin counter (legacy) | `Scenes/UI/coin_counter.tscn` | ✅ | `SampleProject/Game.tscn:12` **`visible = false`** (`:280`) | same |
| Gold display | `Scenes/UI/gold_display.tscn` | ✅ | `Scenes/Menus/Game/base_menu.tscn:5` | `GOLD` in every Game Menu frame |
| Timer display | `Scenes/UI/timer_display.tscn` | ✅ | `Scenes/Menus/Game/base_menu.tscn:4` | `PLAYTIME`; data gap D2 |
| Objective HUD | `Scenes/UI/ObjectiveHUD.tscn` | ⚠️ | declared `SampleProject/Game.tscn:15`, **never instanced** — [[BUGS]] **B42** | superseded by `434:6580` |
| Menu shell | `UI/Components/menu_shell.tscn` | ⚠️ | only `UI/verify_game_ui_theme.gd:17` | its own Phase 4/5 plan; [[BACKLOG]] *Agreed but never built*; root cause of [[BUGS]] B7, B8 |
| Prologue scene | `Scenes/UI/PrologueScene.tscn` | ⚠️ | **zero references.** Its script `Scripts/UI/PrologueScene.gd:80` loads `Game.tscn`, so the script is live-looking and the scene is not reachable | **D111** puts prologue story dialogue back in scope — see [[#What this changes]] |
| Game title | `Scenes/UI/game_title.tscn` | ⚠️ | **zero references.** `MainMenu.tscn:63` builds its own inline `GameTitle` VBoxContainer instead | dead; function covered by `258:5140` |
| UI panel | `Scenes/UI/ui_panel.tscn` | ⚠️ | **zero references** | dead ([[figma_coverage]] §F) |
| Yes/No dialog | `Scenes/UI/yes_no_dialog.tscn` | ⚠️ | self-preload only: `Scripts/UI/YesNoDialog.gd:61`; `YesNoDialog` has no callers | dead duplicate of `modal_dialog` |
| Controller test | `Scenes/Test/ControllerTest.tscn` | ⚠️ | **zero references.** 12 lines | dev scratch |

## 3. NPCs

| Scene | Path or — | State | Evidence | Source that requires it |
|---|---|---|---|---|
| Merchant | `Scenes/Gameplay/Objects/NPCs/merchant.tscn` | ⚠️ | only `UI/verify_shop.gd:10`, `UI/verify_interaction.gd:11`, `UI/capture_npcs.gd:21`, `UI/capture_shop.gd:42`. **No map references it** | **D81** — deliberately unplaced. [[BACKLOG]] *Agreed but never built* |
| Blacksmith | `Scenes/Gameplay/Objects/NPCs/blacksmith.tscn` | ⚠️ | only `UI/verify_blacksmith.gd:8`, `UI/capture_npcs.gd:24`. **No map references it** | **D81**, D69, D115 |

`grep -rn "merchant\|blacksmith" SampleProject/Maps/` returns exactly three
lines, all in `Maps/City.tscn:46-52`, and all belong to an inline `Area2D` named
`StateChangeTrigger_Merchant` with `dialogue_id = "City_Merchant"`. **That is a
dialogue trigger, not the merchant scene.** Neither NPC scene is placed anywhere.

Both NPCs share `Scripts/Gameplay/NPCs/NpcBase.gd`. The menu they open,
`NpcActionMenu`, has **no `.tscn`** — `NpcBase.gd:22` does
`NpcActionMenu.new()` against `UI/Components/npc_action_menu.gd:2`. Built in
code by choice; parked as **O13**, not a defect.

## 4. Maps

Binding is `SampleProject/Maps/MapData.txt`: each cell line ends `|||:<uid>`
with the room scene's uid, **without** the `uid://` prefix.

| Scene | Path or — | State | Evidence | Source that requires it |
|---|---|---|---|---|
| Laboratory | `Maps/Laboratory.tscn` | ✅ | 9 cells in `MapData.txt` (uid `csao70e2jutpd`) | MetSys `map_root_folder`, `Resources/Settings.tres:11` |
| Village | `Maps/Village.tscn` | ✅ | 6 cells (`dbq66sndnfrq7`) | — |
| Canyon | `Maps/Canyon.tscn` | ✅ | 4 cells (`d2qxq8pgs28p4`); also `Resources/Settings.tres:11` `scene_template`, `Scripts/Game.gd:275` | MetSys template room |
| Desert Road | `Maps/DesertRoad.tscn` | ✅ | 4 cells (`1jf0qd1hdorm`) | — |
| City | `Maps/City.tscn` | ✅ | 3 cells (`cd2gmmoyuovq8`) | — |
| City Gates | `Maps/CityGates.tscn` | ✅ | 1 cell (`clx0l64d6oi0m`) | — |
| Laboratory Outside | `Maps/LaboratoryOutside.tscn` | ✅ | 1 cell (`cu832u1avju30`) | — |
| Mayor Hall | `Maps/MayorHall.tscn` | ✅ | 1 cell (`cmayorhall001`) | — |
| 17 Legacy rooms | `Maps/Legacy/{Corridor, DarkCorridor, DarkPortalRoom, DarkStaircase, DiceRoom, ElevatorRoom, EndingPoint, Junction, LavaCorridor, LavaCorridorAfterwater, LeftStaircase, PortalRoom, RelicRoom, RightStaircase, SecretChamber, StartingPoint, UpperElevatorRoom}.tscn` | ⚠️ | **not one uid appears in `MapData.txt`.** `Maps/Legacy/EndingPoint.tscn:56,59` still loads `Game.tscn` / `MainMenu.tscn` | none — see **Q34** |
| Legacy StartingRoom | `Maps/Legacy/StartingRoom.tscn` | ⚠️ | **has no `uid` in its header at all**, so MetSys cannot bind it. Script `Scripts/SavePoint.gd` | none — **Q34** |

### What the eight live maps actually contain

Node-name dump of all eight: `TileMap`, `Foreground`/`Background`,
`RoomInstance` (MetSys), plus **inline** `Area2D`s — `SavePoint*`,
`StateChangeTrigger_*`, `EnemySpawner`/`EnemySpawnPoint*`. **Zero instanced
sub-scenes.** No NPC, no pickup, no chest, no portal, no prop.

That is the mechanical statement of the content gap: the game's systems are
built, and nothing is placed in the world.

Save points are 10 hand-built `Area2D` + `Scripts/SavePoint.gd` + `Label` triples
across the eight maps (`Maps/Canyon.tscn:101`, `Maps/City.tscn:22`,
`Maps/DesertRoad.tscn` ×2, `Maps/Laboratory.tscn` ×2, …). There is **no
`SavePoint.tscn`**, and no source requires one — parked as **O12**.

## 5. Systems and roots

All twelve ✅. Autoload scenes are proven by `project.godot`.

| Scene | Path or — | State | Evidence | Source that requires it |
|---|---|---|---|---|
| Game root | `SampleProject/Game.tscn` | ✅ | `Scripts/Menus/MainMenu.gd:258`, `Scripts/Menus/LoadGameMenu.gd:23`, `Scripts/UI/game_over_screen.gd:12` | the game |
| GameManager | `Scenes/Managers/Core/GameManager.tscn` | ✅ | `project.godot:37` | autoload |
| EventBus | `Scenes/EventBus.tscn` | ✅ | `project.godot:38` | autoload |
| SaveSystem | `Scenes/Systems/SaveSystem.tscn` | ✅ | `project.godot:39` | autoload |
| ServiceLocator | `Scenes/ServiceLocator.tscn` | ✅ | `project.godot:40` | autoload |
| AudioManager | `Scenes/Systems/AudioManager.tscn` | ✅ | `project.godot:41` | autoload |
| DisplayManager | `Scenes/Systems/DisplayManager.tscn` | ✅ | `project.godot:42` | autoload |
| MusicManager | `Scenes/Systems/MusicManager.tscn` | ✅ | `project.godot:43` | autoload |
| ItemDatabase | `Scenes/Systems/ItemDatabase.tscn` | ✅ | `project.godot:44` | autoload |
| LocalizationManager | `Scenes/Systems/LocalizationManager.tscn` | ✅ | `project.godot:46` | autoload, D67 |
| Dialogue system | `Scenes/DialogueSystem.tscn` | ✅ | `SampleProject/Game.tscn:19` | DialogueQuest. **All three children are addon prefabs** — `dialogue_player.tscn`, `dialogue_box.tscn`, `choice_menu.tscn` at `DialogueSystem.tscn:3-5` |
| CustomRunner start | `CustomRunnerIntegration/CustomStart.tscn` | ✅ | `addons/CustomRunner/Config.gd:20`; plugin enabled `project.godot:70` | editor tooling only |

## 6. Required and missing

Eleven scenes a D-ID, a Figma frame or a shipped script requires, with no file.
Each verified by `find`/`grep` for the name and for any near-match.

| Scene | Path or — | State | Evidence | Source that requires it |
|---|---|---|---|---|
| Crafting UI (tabbed, 4 stations) | — | ❌ | `find SampleProject -iname "*craft*"` returns only `Resources/Data/crafting_recipes.json` and `Scripts/Systems/ForgeSystem.gd` (8-line stub, deleted by D96). No `verify_crafting.gd`. **Three traces: data ✅, code ❌, test ❌** | **D97** (mock prices unblock it), **D108** (tab strip `Furnace │ Workbench │ Anvil │ Alchemy`, undesigned), **D85**, **D115**. Figma `160:1291`, `164:2326`, `164:2545`, `164:2764`. [[BACKLOG]] *Planned* |
| Enchanting UI | — | ❌ | `find … -iname "*enchant*"` → **nothing**, anywhere in `SampleProject/` | **D94** (two identical items → +1), **D115**. Figma `enchant-list 177:1362` is a crafting-list copy and not final (D68). [[BACKLOG]] needs `design/enchanting_plan.md` |
| Chest | — | ❌ | `find … -iname "*chest*"` → **nothing**. Figma art `prop/treasure-chest` exists | **D88** — third pickup path: opens on button press, adds contents, *then* shows the pickup modal |
| Healing menu component | — | ❌ | `game_menu_content.tscn` instances 7 tab panels, no Healing | **D65** — Figma `58:230` is authoritative |
| Jobs menu component | — | ❌ | same; no Jobs | **D65** — Figma `58:947` is authoritative. Also blocked on the Job Points gap D11 |
| Dialogue box (project-owned) | — | ❌ | `Scenes/DialogueSystem.tscn:4` instances `addons/dialogue_quest/prefabs/ui/dialogue/components/dialogue_box/dialogue_box.tscn`. No presentation scene exists under `SampleProject/` | **D110** — DialogueQuest stays as engine/data; presentation is project-owned and the addon prefab is *not* restyled. [[BACKLOG]] *Planned*; [[dialogue_audit]] §3 needs rewriting to D110 first |
| Choice menu (project-owned) | — | ❌ | `Scenes/DialogueSystem.tscn:5` instances the addon `choice_menu.tscn` | **D110** for the layer; **D113** says no choice work yet, so this is ❌-but-deferred. Figma `258:5108` |
| Story-scene dialogue (full-body art) | — | ❌ | nothing matches `*story*`, `*cutscene*.tscn`. `Scripts/Systems/Cutscene*.gd` exist with no scenes | **D111** (in scope), **D112** (full-body art, not portraits — so Figma `36:65`'s 160×320 portraits are partly outdated), **D70** |
| NPC speech bubble | — | ❌ | `find … -iname "*bubble*"` → **nothing** | Figma `164:1318`, labelled MATCH in [[figma_coverage]] §E with no runtime behind it |
| Four companion scenes | — | ❌ | `Scripts/Gameplay/Characters/Companions/Companion{Fire,Healer,Shield,Utility}.gd` all exist; `grep -rn "CompanionFire\|CompanionHealer\|CompanionShield\|CompanionUtility"` outside that folder returns **zero hits**. `CompanionManager` is registered (`Scripts/Core/ServiceLocator.gd:168`, `ServiceRegistry/GameplayServiceRegistry.gd:39`) but is 27 lines — an array with add/remove | **No D-ID.** `docs/SYSTEMS_OVERVIEW.md:130-134` describes all four as shipping. [[BACKLOG]] *Agreed but never built* records the 206-line version in `raw_assets/qusakam_v2-main/` |
| "Objective updated" toast | — | ❌ | no scene; `Scripts/Quest/QuestProgressUI.gd` (152 lines) is never instanced (D56) | [[figma_coverage]] §F NONE — needs a Figma frame **and** a plan before it is buildable |

**Not scene-shaped, so not listed above** but still unbuilt: the Game Over third
button (**D92**), the Shop quantity selector (**D104**), disabled unaffordable
rows (**D105**), Equipment removal from Shop and Blacksmith (**D103**). All four
are edits inside scenes that already exist.

## 7. The project's own "should exist" list is broken

`SampleProject/Scripts/Core/ResourcePaths.gd` is the only place in the codebase
that enumerates expected scene paths — 15 `.tscn` constants. Checked every one
against the filesystem:

| Constant | Line | Resolves? |
|---|---|---|
| `GAME_MENU` | `:66` | ✅ the only one |
| `ENEMY_DEFAULT` | `:26` | ❌ `Scenes/Characters/default_enemy.tscn` — real file is `Scenes/Characters/**Enemies**/default_enemy.tscn` |
| `MERCHANT` | `:48` | ❌ `Scenes/Objects/NPCs/merchant.tscn` — real file is `Scenes/**Gameplay**/Objects/NPCs/merchant.tscn` |
| `ENEMY_{MELEE,RANGED,FAST,TANK,MINIBOSS}` | `:27-31` | ❌ ×5 |
| `BOSS_{CONTROLLER,DEFAULT,ENEMY,DEMO,MINIBOSS,FINAL}` | `:34-39` | ❌ ×6 |
| `GAME_ROOT` | `:57` | ❌ `Scenes/Levels/GameRoot.tscn`; no `Scenes/Levels/` directory exists |

`MAP_LOCATIONS_CONFIG` (`:74` → `Resources/Data/map_locations.json`) is also
missing — that is the same "location dataset" that blocks **D40** and **D41**.

`grep -rn "ResourcePaths" SampleProject addons` outside the file itself returns
**zero hits**, so nothing breaks today. `get_enemy_scene_path()` (`:127`) would
return a dead path for every type except `default_enemy`, and its `match` has an
unreachable duplicate `"miniboss"` arm (`:139` and `:157`). Filed as
[[BUGS]] **B41**.

The 12 missing enemy/boss paths are **not** required scenes: enemy variety is
`EnemyStats` resources on one scene (see §1). They are a stale registry, not a
backlog.

---

## What this changes

### Registers corrected

- **[[BACKLOG]] — "Merchant / Blacksmith on production maps … placed **only in
  `Maps/City.tscn`**" is wrong.** They are placed in **no map at all**. The only
  match in `Maps/` is the inline `StateChangeTrigger_Merchant` dialogue trigger
  at `Maps/City.tscn:46-52`. D81 approved exactly this, so nothing is broken —
  but the row understates the gap and would send someone looking for a placement
  that does not exist. Row corrected.
- **[[BACKLOG]] — "The Game Menu still runs on legacy `vertical_menu.tscn` +
  `panel_manager.gd`"** names the orphan. The live scene is
  `Scenes/UI/vertical_tab_menu.tscn` (`game_menu_content.tscn:3`);
  `Scenes/Menus/Game/vertical_menu.tscn` has zero references. `panel_manager.gd`
  is shared by both, so the point about B7/B8 stands. Row sharpened.
- **[[BACKLOG]] — `ItemPickup` placement** is broader than the row says: **no**
  `Objects/*.tscn` is placed in **any** production map, not just item pickups.
  Note added pointing here.
- **[[figma_coverage]] §F "ObjectiveHUD — Orphan"** is right, and this audit
  explains *why* a grep says otherwise: it is a declared-but-uninstanced
  `ext_resource` (B42).

### Documents contradicted

- **`docs/SYSTEMS_OVERVIEW.md` § Companions (`:130-134`)** lists all four
  companions as delivered systems. Four scripts exist, nothing references them,
  no scene exists. Already known; this note gives the grep.
- **`docs/SYSTEMS_OVERVIEW.md` § Scenes (`:159-174`)** lists `spawn_portal.tscn`
  — no such file, and no `SpawnPortal.gd` either. It also lists `ui_panel.tscn`,
  `game_title.tscn`, `yes_no_dialog.tscn`, `potion.tscn` and
  `player_projectile.tscn` as project scenes; all five are ⚠️ orphans. And
  `EnemyMelee.gd`, `EnemyFast.gd`, `EnemyTank.gd`, `PauseMenu.gd` (`:120-156`)
  do not exist — `PauseMenu.gd` was deleted in `fc56f37b` per
  [[figma_decision_register]] §6. Treat the whole file as a historical import
  manifest, not a state document.
- **`docs/CLAUDE.md`** says "23 verify scripts as of 2026-09-27". There are now
  **24** (`ls SampleProject/UI/verify_*.gd`). Stale by one, not wrong in kind.
  Left alone — **D99** says do not touch `CLAUDE.md` yet.
- **[[figma_coverage]] §F "Prologue scene — NONE — Dead."** Still true as a
  reachability statement (`PrologueScene.tscn` has zero references), but **D111**
  puts prologue story dialogue back in scope, so "dead" should not be read as
  "cut". Flagged, not edited — that is the dialogue plan's call.

### IDs filed

| ID | Where | What |
|---|---|---|
| **B41** | [[BUGS]] | `ResourcePaths.gd` — 14 of 15 scene constants point at non-existent files; duplicate unreachable `match` arm; class entirely unreferenced |
| **B42** | [[BUGS]] | `ObjectiveHUD.tscn` declared at `Game.tscn:15`, never instanced — the only dangling `PackedScene` `ext_resource` in the project |
| **Q34** | [[questions_for_sapega]] | 18 `Maps/Legacy/*.tscn` are unreachable (no uid in `MapData.txt`) and hold the only placements of 9 world-object scenes. Keep as a parts bin, or delete both layers? |
| **Q35** | [[questions_for_sapega]] | `EnemyRanged.gd`, `DemoBoss.gd` and `player_projectile.tscn` — scripts with no scene and a scene with no spawner. Build them or delete them? |
| **O12** | [[BUGS]] | Save points are 10 inline `Area2D` copies across 8 maps with no `SavePoint.tscn` |
| **O13** | [[BUGS]] | `NpcActionMenu` is built in code (`NpcBase.gd:22`), the only UI component in `UI/Components/` with a `.gd` and no `.tscn` |

### The one thing that would unblock this topic

**Answer Q34.** Deleting the 18 Legacy maps drops 18 of the 46 orphans outright
and turns 9 more world-object scenes from "used in Legacy" into "unused", which
makes the real question visible and unavoidable: *what goes into the eight live
maps?* Every other row here — merchant placement (D81), `ItemPickup` placement
(Q2/D88), chests (D88) — is a downstream instance of that one unanswered
question. Keeping Legacy as a parts bin is also a fine answer; what is not fine
is that the project cannot currently tell which of its 121 scenes are content
and which are archaeology.
