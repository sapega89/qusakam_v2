# Runtime UI Surface Audit

Full sweep of every player-visible UI surface in the project — not just Game
Menu tabs. Existence of a file was **not** treated as proof a feature works: for
each surface I traced what instantiates it, whether it is reachable at runtime,
whether its data source exists and whether its controls are wired.

Audit only. Nothing was implemented, fixed or redesigned.

**Legend:** ✅ COMPLETE · 🟡 FUNCTIONAL BUT OLD STYLE · 🟠 PARTIAL ·
❌ MISSING UI · 💀 DEAD / UNREACHABLE · ❓ NEEDS DESIGN DECISION

**Figma coverage** (MATCH / PARTIAL / NONE / OUTDATED) for every row below is in
`design/figma_coverage.md`. The `Figma?` columns here list node IDs only. Supporting
docs: `figma_inventory.md` (what Figma contains), `figma_decision_register.md`
(which decisions override Figma).

---

## A. Game Menu + HUD (the implemented scope)

| Surface | Scene | Script | Instantiated by | Reachable? | Backing | Style | GameUITheme? | Figma? | Impl. | Functional | Restyle? | New design? | Blockers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Game Menu shell | `game_menu.tscn` | `game_menu.gd` | `GameMenuState` via `UIManager` | Yes | UIManager/MenuManager | Theme | Yes | `UI/Top Bar`+`Sidebar` | ✅ | ✅ | No | No | — |
| Inventory | `inventory_component.tscn` | `inventory_component.gd` | Menu tab | Yes | `ItemDatabase`, `InventoryManager` | Theme | Yes | `46:193` | ✅ | ✅ | No | No | — |
| Equipment | `equipment_component.tscn` | `equipment_component.gd` | Menu tab | Yes | `EquipmentManager` | Theme | Yes | `58:4` | ✅ | 🟠 | No | Yes — 11 real slots vs fewer in Figma | `request_tab` has no listener (equip flow entry) |
| Status | `stats_component.tscn` | `stats_component.gd` | Menu tab | Yes | `GameManager`/`StatCalculator` | Theme | Yes | `58:719` | ✅ | ✅ | No | No | Path Action/Talent are empty structure cards |
| Skills | `skills_component.tscn` | `skills_component.gd` | Menu tab | Yes | `SkillDatabase`+`SkillManager` | Theme | Yes | `58:453` | ✅ | 🟠 | No | No | `skills.json` empty; unlock via `_gui_input` unreachable |
| World Map | `metsys_map_component.tscn` | `metsys_map_component.gd` | Menu tab | Yes | MetSys | Theme | Yes | `94:609` | ✅ | ✅ | No | No | D40/D41 marker data |
| Journal | `journal_component.tscn` | `journal_component.gd` | Menu tab | Yes | `Game.current_objective` only | Theme | Yes | `192:1529` | ✅ shell | ✅ | No | Yes — codex frames rejected (D52) | No quest data (D56) |
| Settings | `options_component.tscn` | `options_component.gd` | Misc tab | Yes | `SettingsModule`, `LocalizationManager` | Theme | Yes | `17:280`+3 | ✅ | ✅ | No | Yes — deferred rows | D43–D48 |
| Misc submenu | `misc_menu_modal.tscn` | `misc_menu_modal.gd` | `ModalLayer.show_custom_modal()` | Yes | — | Theme | Yes | `58:1246` | ✅ | ✅ | No | No | — |
| Combat HUD — vitals | `player_vitals_panel.tscn` | `.gd` | `Game.tscn → UICanvas/CombatHUD` | Yes | player node, `SkillManager`, `XPManager` | Theme | Yes | `434:6558` | ✅ | ✅ | No | No | — |
| Combat HUD — hotbar | `skill_hotbar.tscn` | `.gd` | same | Yes | `SkillManager` | Theme | Yes | `434:6628` | ✅ | 🟠 | No | No | slots never equipped; `_resolve_target()` returns null |
| Combat HUD — top bar | `combat_hud_top.tscn` | `.gd` | same | Yes | `Game.objective_updated`, `EventBus.coins_changed` | Theme | Yes | `434:6556` | ✅ | ✅ | No | No | — |
| Bottom bar | `bottom_bar.tscn` | `.gd` | menu shell | Yes | per-screen hints | Theme | Yes | `UI/Bottom Bar` | ✅ | ✅ | No | No | — |
| Party panel | `party_status_panel.tscn` | `.gd` | menu shell | Yes | `CharacterManager` | Theme | Yes | `68:1484` | ✅ | 🟠 | No | No | SP shows `—/—`; portraits are colour blocks |
| Modal layer | `modal_layer.tscn` | `modal_layer.gd` | `UIManager` | Yes | — | Theme | Yes | `144:1799` (5 frames) | 🟠 | ✅ | Maybe | No | 5 modal frames never compared individually |

---

## B. Shop / Merchant / Blacksmith

| Surface | Scene | Script | Instantiated by | Reachable? | Backing | Style | GameUITheme? | Figma? | Impl. | Functional | Restyle? | New design? | Blockers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Shop menu (buy/sell/blacksmith)** | `Scenes/Shop/shop_menu.tscn` | `Scripts/Shop/shop_ui.gd` | `Merchant.open_shop()` — `load()` + own `CanvasLayer` layer 13 | **NO** — see below | `merchants.json` ✅ + `ItemDatabase` | `Resources/Themes/default_button.tres`, local `StyleBoxFlat`, hardcoded colours, `theme_override_font_sizes` | **No** | `shop-buy` `153:1289` | 🟡 | 💀 | **Yes** | No | see blockers |
| Merchant NPC + prompt | `Objects/NPCs/merchant.tscn` | `Merchant.gd` | — | **NO** | `merchants.json` | plain `Label` `"Press E to open shop"` | No | `npc/merchant` in `desert-oasis-scene` | 🟡 | 💀 | Yes | No | never placed in a map |
| Blacksmith | — | — | `shop_ui._on_blacksmith_pressed()` → `_switch_mode("equipment")` | No | — | — | No | `npc-menu-blacksmith` | 🟠 | 💀 | Yes | No | only a mode of the shop; no NPC exists |

**Blockers (verified):**
1. **`merchant.tscn` is not instanced in any scene or map.** Grep across all
   `.tscn`/`.gd` finds zero placements → the shop is **unreachable in the
   current game**.
2. **`shop_ui.gd:43` uses `Engine.has_singleton("ServiceLocator")`**, which is
   always false for Godot 4 autoloads. So `item_database` and `game_manager`
   are **both null** even if the shop did open — item lookup and gold spending
   cannot work. Same systemic bug documented in `ui_visual_qa.md`.
3. Styling violates the CLAUDE.md "no duplicate styling" rule outright.

---

## C. Crafting / Enchanting

| Surface | Scene | Script | Instantiated by | Reachable? | Backing | Style | GameUITheme? | Figma? | Impl. | Functional | Restyle? | New design? | Blockers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Crafting UI** | — | — | — | **NO** | `crafting_recipes.json` — **18 real recipes**, parsed by `ItemDatabase` | — | — | `crafting-list` | ❌ | ❌ | — | No | no UI exists |
| Crafting station | — | — | — | No | — | — | — | — | ❌ | ❌ | — | ❓ | no station object anywhere |
| **`ForgeSystem`** | — | `Systems/ForgeSystem.gd` | `GameManager._create_managers()` | Runs | none | — | — | — | 💀 | 💀 | — | — | **The entire file is 8 lines: `_ready()` prints one line. No methods, no state.** |
| Enchanting | — | — | — | No | none | — | — | `enchant-list` | ❌ | ❌ | — | No | no system, no data |

**Crafting is data-only today.** 18 recipes load into `ItemDatabase` at startup
and are never read by anything. There is no crafting manager, no station, no UI.

---

## D. Dialogue

| Surface | Scene | Script | Instantiated by | Reachable? | Backing | Style | GameUITheme? | Figma? | Impl. | Functional | Restyle? | New design? | Blockers |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Dialogue box** | `addons/dialogue_quest/.../dialogue_box.tscn` via `DialogueSystem.tscn` | addon | `Game.tscn:314` → `DialogueSystem` | **Yes — live in every gameplay session** | DQD files + `DialogueManager` | **addon default** | **No** | `144:1800` (2 frames) | 🟡 | ✅ | **Yes** | No | third-party ownership (same question as D48) |
| Dialogue choices | `.../choice_menu.tscn` | addon | same | Yes | DQD | addon default | No | `conversation-dialog-choices` | 🟡 | ✅ | Yes | No | third-party |
| `DialogueUI.gd` | — | `Scripts/UI/DialogueUI.gd` | **nothing** | No | — | — | — | — | 💀 | 💀 | — | — | `class_name DialogueUI`, zero references |
| Boss / cutscene dialogue | — | `CutsceneDialogueStep.gd` | cutscene system | ❓ unverified | DQD | addon | No | — | 🟠 | ❓ | Yes | ❓ | no dedicated UI; reuses the dialogue box |

The dialogue box is **the most-seen unstyled surface in the game** — it appears
in every gameplay screenshot in `design/shots/` with default addon styling
(plain box, `Auto`/`Skip` buttons, purple speaker name) directly beside fully
themed HUD elements.

---

## E. NPC interaction

| Surface | Scene | Script | Reachable? | Figma | Impl. | Functional | Blockers |
|---|---|---|---|---|---|---|---|
| Interaction prompt | inline `Label` in `merchant.tscn` | `Merchant.gd:25` | No (merchant unplaced) | `UI/Interaction/Prompt` `461:6479` (D74) | 🟡 | 💀 | one hardcoded English string, no shared prompt component |
| NPC action menu (Talk / Quest / Buy / Craft / Enchant) | — | — | No | `npc-menu-merchant`, `npc-menu-blacksmith` | ❌ | ❌ | does not exist |
| NPC speech bubble | — | — | No | `npc-speech-bubble` | ❌ | ❌ | does not exist |
| Full-screen NPC dialogue | addon box | — | Yes | `npc-dialogue-full` | 🟡 | ✅ | addon styling |

**No generic interaction-prompt system exists.** The only prompt in the project
is a `Label` inside `merchant.tscn`.

---

## F. Notifications, HUD extras, flow screens

| Surface | Scene | Instantiated by | Reachable? | Backing | Theme? | Figma? | Status |
|---|---|---|---|---|---|---|---|
| Level-up notification | `level_up_notification.tscn` | `Game.tscn:274` | Yes | `XPManager.level_up` | No | — | 🟡 |
| Level-up flash FX | `FX/LevelUpFlash.tscn` | `Player.gd:6` preload | Yes | XP | n/a | — | ✅ |
| Coin counter | `coin_counter.tscn` | `Game.tscn:278` | Yes (hidden — `visible=false`) | `EventBus.coins_changed` | No | superseded by `combat_hud_top` | 💀 superseded |
| Legacy health bar | `health_bar.tscn` | `Game.tscn:249` | Hidden (`visible=false`, alpha 0) | player | No | superseded | 💀 superseded |
| Legacy XP bar | `xp_bar.tscn` | `Game.tscn:265` | Hidden | `XPManager` | No | superseded | 💀 superseded |
| Enemy health bar | `enemy_health_bar.tscn` | `DefaultEnemy.gd:142` `load()` | Yes | `HealthComponent` | No | — | 🟡 |
| Combat context display | `CombatContextDisplay.tscn` | `Game.tscn:288` | Yes | combat events | No | — | 🟡 |
| Tutorial hints | `TutorialHintDisplay.tscn` | `Game.tscn:292` | Yes | `TutorialManager.show_hint()` | No | — | 🟡 |
| **ObjectiveHUD** | `ObjectiveHUD.tscn` | **ext_resource only — no node** | **No** | `Game.objective_updated` | No | — | 💀 orphan ext_resource; replaced by `combat_hud_top` |
| Objective notifications | — | — | No | — | — | — | ❌ no transient "objective updated" toast |
| Item acquired / loot toast | — | — | No | `LootSystem` runs | — | — | ❌ does not exist |
| Death / respawn UI | — | — | No | `EventBus.player_died`, `player_respawned` | — | — | ❌ **no death screen at all** |
| Demo end screen | `DemoEndScreen.tscn` | `LaboratoryOutside.gd:127` | Yes (end of demo) | — | No | — | 🟡 |
| Prologue scene | `PrologueScene.tscn` | **nothing** | No | — | No | — | 💀 |
| Tutorial menu | `tutorial_menu.tscn` | `game_menu.gd:18` via Misc → Tutorial | Yes | — | No | — | 🟡 |
| Timer display / panel | `timer_display.tscn`, `timer_panel.tscn` | `base_menu.tscn` / unreferenced | Partly | `TimeManager` | No | — | 🟡 / 💀 |
| Gold display | `gold_display.tscn` | `base_menu.tscn` | Yes | coins | No | — | 🟡 |
| Item tooltip | `item_info_tooltip.tscn` | unreferenced externally | No | — | No | `UI/Tooltip` | 💀 |
| `ui_panel.tscn`, `game_title.tscn` | — | nothing | No | — | No | — | 💀 |
| `modal_dialog.tscn` | — | `modal_layer.tscn` | Yes | — | Yes | `144:1799` | ✅ |
| `yes_no_dialog.tscn` | — | `YesNoDialog.gd:61` `load()` | **No callers of `YesNoDialog`** | — | No | — | 💀 |
| Save point | — | `SavePoint.gd` | Yes (in 4+ maps) | SaveSystem | — | — | ❌ **no save-point UI/prompt** |

---

## G. Main menu / Save / Load

| Surface | Scene | Script | Instantiated by | Reachable? | Theme? | Figma | Status |
|---|---|---|---|---|---|---|---|
| Main menu | `SampleProject/MainMenu.tscn` | `Scripts/Menus/MainMenu.gd` | project run target | Yes | No — 3 local overrides | `144:1775` (2 frames) | 🟡 |
| Load game menu | `Scenes/Menus/LoadGameMenu.tscn` | `LoadGameMenu.gd` | `MainMenu.gd:217`, `load_game_state`, `save_game_state` | Yes | No — 6 local overrides | `144:1776` (3 frames) | 🟡 |
| Save game state | `States/save_game_state.tscn` | `save_game_state.gd` | `UIManager.change_state("SaveGameState")` | Yes | No | `144:1776` | 🟡 |
| Splash | — | — | — | No | — | `144:1775` | ❌ |

---

# Report

## 1. Total distinct runtime UI surfaces

**52 surfaces** identified across 49 UI scenes plus addon-provided and
code-only surfaces.

## 2. Fully complete (✅) — 15

Game Menu shell · Inventory · Equipment · Status · Skills · World Map · Journal
· Settings · Misc submenu · Combat HUD (vitals, hotbar, top bar) · bottom bar ·
party panel · modal dialog · level-up flash.

Four carry functional caveats that are **content/product gaps, not UI**:
Equipment's equip entry point, Skills' empty `skills.json`, the hotbar's
unset targeting, and the party panel's `—/—` SP.

## 3. Functional but old style (🟡) — 13

**Dialogue box** and **dialogue choices** (addon default, seen constantly) ·
Main menu · Load game menu · Save game state · tutorial menu · level-up
notification · enemy health bar · combat context display · tutorial hints ·
demo end screen · gold display · timer display.

Plus the **shop menu**, which is old-style *and* unreachable.

## 4. Missing UI (❌) — 9

Crafting list · crafting station · enchanting · NPC action menu · NPC speech
bubble · generic interaction prompt · **death/respawn screen** · item-acquired /
loot toast · objective-change notification · splash screen · save-point prompt.

## 5. Dead / unreachable (💀) — 12

`shop_menu` + `Merchant` (never placed in a map) · blacksmith mode ·
`ForgeSystem` (8-line stub) · `DialogueUI.gd` · `ObjectiveHUD` (orphan
ext_resource) · `PrologueScene` · `yes_no_dialog` · `item_info_tooltip` ·
`ui_panel` · `game_title` · `timer_panel` · superseded `coin_counter` /
`health_bar` / `xp_bar` (still instanced but permanently hidden).

## 6. Still need Figma designs

*Revised by the Figma coverage audit — full per-surface labels in
`design/figma_coverage.md`. The earlier list wrongly included death/respawn and
the item-acquired modal: both are designed.*

**No design at all (live surfaces):** enemy health bar · level-up notification ·
in-game tutorial hint · combat context display · objective-change notification ·
demo end screen.

**Design incomplete:** enchant list (`177:1362` is a mislabelled crafting copy) ·
full-screen NPC dialogue (`164:1334` has no dialogue panel) · dialogue choices
in context (component `258:5108` only).

**Save flow (D75):** one shared Save Slot Selection surface — LOAD mode from
Main Menu → Continue, SAVE mode from a save point. Figma `150:1278` / `17:5` /
`258:5162` cover it. Save-success confirmation is derived from the overwrite
modal (D76) — no new visual design.

**Already designed, previously listed as missing:** death/respawn →
`game-over-screen` `41:83` · item acquired → `item-pickup-*` `28:5`, `28:25`
(D71: the confirmation modal, after the generic prompt) · interaction prompt →
`UI/Interaction/Prompt` `461:6479` (D74) ·
crafting station → blacksmith NPC menu `176:1357` (D69: separate NPC).

**Designer-requested new design:** a dedicated Enchanting page (D68).

**Figma needs updating:** Equipment slots (D20) · Controls actions (D47) ·
Journal codex → quest log (D52) · Settings Language must list English +
Ukrainian (D67) · remove HUD Bag Section
(D33) · accent-on-accent selected rows in Shop and Crafting (same defect as D26)
· duplicate `crafting-confirm` / `crafting-error` frames (`164:1446`,
`164:1621`).

**Figma coverage totals:** 39 MATCH (1 by reuse) · 4 PARTIAL · 11 NONE · 3 OUTDATED
(World Map, Journal, item tooltip). Designer answers are recorded as D65–D76
(`figma_decision_register.md` §4).

## 7. Recommended implementation order

**Tier 1 — visible in every session, already backed, pure restyle**
1. **Dialogue box + choices** — the single most-seen unstyled surface. Decide
   addon ownership first (same question as D48).
2. **Splash / Main menu / Save Slot Selection** — first thing a player sees;
   all wired and working, only styling is off. All designed (`258:5141`,
   `9:26`, `150:1278`, `17:5` + `258:5162`). Load and Save become **one**
   Save Slot Selection surface with LOAD/SAVE modes (D75); the two runtime
   scenes merge. Splash reuses the
   hidden `PressAnyButtonContainer` already in `MainMenu.tscn`. Main menu's
   runtime Load Game button must go — slot choice goes through Continue (D72).
3. **Tutorial hints, combat context, level-up notification, enemy health bar** —
   small, live, backed; **still need Figma designs** (the only Tier 1 items
   blocked on design).

**Tier 2 — designed and backed, UI missing or unreachable**
4. **Death / game-over screen** — `EventBus.player_died` / `player_respawned`
   exist, and `41:83` is designed. Moved up from Tier 3: no longer blocked on
   design.
5. **Shop** — fix the `Engine.has_singleton` bug, place a merchant in a map,
   then restyle to `shop-buy` `153:1289`, `shop-sell` `153:1523`,
   `shop-buy-confirm` `153:1760`. Highest value per effort: data and logic
   already exist.
6. **NPC interaction prompt + NPC action menu** — prerequisite for reaching the
   shop, blacksmith and crafting from the world. Designed: prompt
   `UI/Interaction/Prompt` `461:6479` (D74), menus `164:1302` / `176:1357`,
   speech bubble `164:1318`.
7. **Item pickup** — `LootSystem` runs. D71: nearby prompt
   `461:6479`, then the confirmation modal `28:5` / `28:25`.

**Tier 3 — needs systems built first, not UI work**
8. **Crafting** — 18 recipes exist but no manager or UI. The full screen flow
   is designed (`160:1291` → `164:2326` → `164:2545` / `164:2764`), and Figma
   puts the station at the blacksmith NPC. Needs a `CraftingManager` and a
   blacksmith NPC (D69 — separate from the Shop) before any screen.
9. **Enchanting** — planned (D68); no system and no data. Wait for the
   dedicated Enchanting page design.
10. **Save point** — prompt `461:6479` "[A] Save" (D74) → Save Slot
    Selection in SAVE mode (D75) → "Game Saved" modal derived from the
    overwrite confirm (D76) → gameplay.

**Cleanup (any time)**
11. Delete or wire the 12 dead surfaces; remove the orphan `ObjectiveHUD`
   ext_resource and the superseded hidden HUD widgets.
