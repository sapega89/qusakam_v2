---
type: plan
status: in-progress
---

# No fallbacks pass (D131) — what was done, what is left

Started 2026-10-12 on Sapega's rule "no fallbacks" ([[figma_decision_register]] D131).
Stopped by Sapega mid-way through part 3. Decisions taken for this pass: D129–D135.

## Part 1 — committed `e0d34ea3`, pushed

- **B50:** every `Engine.has_singleton/get_singleton(<autoload>)` guard (always false
  in Godot 4) replaced by direct autoload calls, 36 files. Code that now actually runs:
  `EventBus.enemy_died` / `player_died` from combat → LootSystem drops (D132), tutorial
  enemy hints, enemy death state; DialogueQuest flags saved/loaded; audio/display
  settings via AudioManager / DisplayManager.
- Bugs that surfaced once that code ran, fixed: `.has()` on nodes (SaveSystem, Game),
  Canyon exit cutscene checked a flag nobody sets, non-existent
  `EventBus.enemy_state_changed`, TutorialManager `_on_enemy_died` arity.
- ~30 unreferenced scripts deleted (list in the commit message). Q35 orphans kept.
- New test `verify_scripts_compile.gd` (compiles every script).

## Part 2 — committed `02bdc3be`, pushed

Bugs the fallbacks were hiding, fixed:
- **Two coin purses** — pickups went to an unsaved `InventoryManager.coins`; shop and
  loot used the saved Inventory "coin". One purse now.
- **Settings reset after every game save** — the slot file was rewritten without
  `game_settings`. Settings are saved with the game.
- **Save slot location** showed a MetSys uid / "Game" → journal zone title (D133).
- `Game.get_singleton()` kept a freed Game after leaving to the menu.
- Enemy death red flash never ran (looked for AnimatedSprite2D).

Removed: SaveSystem compatibility layer, MusicManager and UIUpdateManager (no callers;
music has no tracks wired — [[music_plan]], Q38), MenuManager / UIManager lookup
fallbacks, Game position-rescue heuristics, many single guards. Dialogue box now uses
GameUITheme (D134). New test `verify_eventbus_wiring.gd`.

## Part 3 — committed (see git log), full suite green + verify_combat_flow

Done; the full suite and the new `verify_combat_flow` (player hits enemy, enemies chase and
hit the player, death runs to the end with loot) pass:
- Mechanical removal of always-true guards on known receivers (29 files):
  `if ServiceLocator.has_method(...)`, `if game and ...`, `if MetSys ...`.
- DefaultEnemy: onready node refs, one `_set_collisions_disabled()`, old structure gone.
- EnemyLogic: `has_method("is_dead")` was always false (is_dead is a var) → dead enemies
  were not stopped; fixed. Direct calls to the enemy and player.
- UIManager: UIRoot is always its own child (no scene/group search); direct state setup.
- StateChangeTrigger: the state scene is `owner` (the room); no 3-way search.
- DialogueManager: DialogueSystem taken from Game; no path guessing; **"auto-recovering"
  removed** — it force-reset DialogueQuest's private `_lock`. The real cause it masked:
  DialogueQuest emits `dialogue_ended` before freeing the player, so a dialogue started
  from a finished-handler was refused. `dialogue_finished` is now emitted deferred.
- GameFlow reads quest flags once; with no Game running the journal shows a new game
  (GameFlow outlives Game — not a fallback).
- Tests: starter_loot drains Canyon's intro chain before the Village chain.

Targeted runs after these changes: starter_loot (×2), desert_road, mayor_hall_teleport,
full_regression, interaction, combat_hud, game_menu, journal — all pass.

## Dialogue queue (2026-10-13, after Sapega's Village report)

`DialogueManager.start_dialogue()` used to refuse a second request but, before refusing, hid and
reset the LIVE dialogue box (`_find_dialogue_system_in_scene()`); the Village arrival trigger
(state change + its own dialogue, while the new state starts the bandit's taunt) did exactly that:
no box, player locked, no enemy. Now a request during a running dialogue is **queued** and played
after it; refusals have no side effects. The trigger's BOTH mode plays its dialogue first, then
changes state (arrival line → taunt → fight). In all four combat rooms the taunt comes BEFORE the
enemies spawn (`_start_fight`), and the fight flag is set only when every enemy is dead
(CityGates and Laboratory set it after the taunt, the DesertRoad bug). Tests: verify_village_fight.

## Menus and HUD (2026-10-13)

~30 guards removed in game menu, inventory, equipment, journal, stats, skills, map, tutorial,
shop, load menu, party panel, skill hotbar, HUD top. Dead UI states (Options/MainMenu/LoadGame/
Modal) and the old `SettingsManager` deleted; language goes straight to `SaveSystem`.
Bugs the guards were hiding:
- bottom bar joined its group in `_ready()`, after the menu components — the first item's hint
  was lost; now `_enter_tree()` + stored hint;
- PLAYTIME in the menu was always `00:00:00` (`set_playtime` had no caller) — now the slot's time;
- Status "current HP" always showed the max (read a `HealthComponent` the player does not have);
- Shop and Load menu auto-confirmed their modal when UI was unavailable.
Menu tests now boot a real `Game.tscn` (the menu requires a player); the "menu alone (F6)" case
in verify_game_menu is gone with its fallbacks.

## Combat (2026-10-13)

- `EnemyStateManager` deleted: write-only. Every enemy death wrote `user://enemy_states.ini`, nothing
  ever read it (`load_enemy_states`, `save_current_scene_enemies` had no callers), and the scene key
  was always `Game`, not the room. The `has_method("is_dead")` bug lived in that dead code.
- `DebugManager` deleted: no key, menu or call ever reached `execute_debug_command`.
- `CombatBody2D.Damage_Receiver` deleted: assigned in no scene.
- Guards removed in spawners, Hazard, Player, PlayerCombat (typed `DamageApplier`), SkillManager
  (`SkillDatabase` autoload), SkillCombatExecutor, VFXHooks (no 5-frame wait for an autoload).

## Systems and scenes (2026-10-13)

- `EnemySpawner` required in the four combat rooms (each script is used by exactly one room that has it).
- Canyon gates: `has_method("open_gate")` → `is GateController`; the `_set_pending_state` branch removed
  (that method never existed — the `else` always ran).
- Dead code deleted: `DialogueStateTrigger` (placed in no scene), `SceneManager`'s cleanup of the
  long-gone `LocationManager`, `GameGroups.get_location_manager`.
- Guards removed in Merchant, NpcBase, InteractableComponent, SavePoint, CharacterManager,
  PlayerDataModule, SaveSystem, LaboratoryOutside, DemoEndScreen, game_over_screen, MainMenu,
  map, options, tutorial, skills, SlashTrail, player vitals.
- Scripts that tests compile before autoloads exist (NpcBase, InteractableComponent,
  game_over_screen) reach services through `ServiceLocatorHelper`, without null checks.

**Found and fixed (D137):** `CanyonExitTrigger.gd` was placed in no scene and looked up its room via
`current_scene` (always `Game`), so Canyon's `EXIT_CUTSCENE` never played. It now sits halfway down
the Canyon stairs and the cutscene ends on the Desert Road. Test: verify_canyon_exit.

## Left on purpose

Quest engine (`quest_manager`, D56), Blacksmith crafting (unbuilt), interfaces, modal types,
TileMap search, Q23 respawn, Q35 orphans, `focus_router` export paths, legacy HUD scripts
(`HealthBar`, `TimerDisplay`, `GoldDisplay`, `base_menu`).

Listed by `grep -rnE 'has_method\(|has_signal\(|get_node_or_null\(' SampleProject/Scripts SampleProject/UI/Components`.
Known real bugs among them:
- `EnemyStateManager.gd:116` — `has_method("is_dead")`, always false.
- `DebugManager.gd:86` — `enemy.has("is_dead")` (no such method on Object); its debug keys
  call `add_to_inventory`, `go_to_next_level`, `go_to_previous_level` — check they exist.

Keep: interface checks (`IDamageable`, `IDamageDealer`, `ICompanionAssist`,
`ISceneStateManager`), checks on bodies entering areas, the bottom bar (absent in the
main menu). Do not touch: Q35 orphans, the quest engine (D56 open), `Maps/Legacy`.

**Resume:** continue the grep list file by file (EnemyStateManager and DebugManager first).

## For Sapega

- Slots saved before part 2 have no `game_settings` → an error on load until saved again.
- Slot 2 (`slot_02.sav`, 0.27 s of play) disappeared during the session; no test touches
  slot 2 — possibly deleted from the in-game Delete button. Slot 3 test leftovers were
  removed and `last_slot` reset to 1.
