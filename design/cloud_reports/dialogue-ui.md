---
type: report
branch: cloud/dialogue-ui
tags: [cloud, dialogue, hud, journal, loot]
---

# Cloud report — dialogue-ui (BACKLOG 36, 37, 33 non-art)

Branch `cloud/dialogue-ui`, from `origin/feature/backlog` @ `8811363f`. Three commits plus this report:
`8cad6058` (36), `6bf87124` (37), `a48a125e` (33). Godot 4.6.2 Linux headless. Figma was not available, so the layouts
follow the existing screens. No window captures could be made; the layouts are described in words below.
Not touched: the dialogue box's `AutoButton` (B10, branch cloud/b82-b10), `dialogue_player_settings.tres`, `project.godot`,
`MainMenu.tscn`, `GameUITheme.tres`, `playthrough.gd`, and the registers (BACKLOG / BUGS / decisions / queue).
**No theme regeneration is needed.** The new tokens are code-only consts in `UITokens.gd`.

## What was built

### 36 — who is speaking
- `SampleProject/Scenes/UI/dialogue_box.tscn:88–100`: `%Name` is no longer in the Auto/Skip row. It now sits in a
  `NameMargin` overlay, a direct child of the box's PanelContainer. The overlay spans the top of the box, the label is
  centred (`horizontal_alignment = 1`, margin top 14) and `mouse_filter = IGNORE`, so clicks reach the buttons beneath.
  The hard-coded purple `font_color` override is gone: names keep the authored character colour, which Q31 says
  does not matter. Layout: Auto | Skip on the left, the speaker's name centred on the same top row, the text below,
  and the portrait frame (128 px, existing `PortraitBackground`) on the right.
- Narration lines (`say||…`) still show no name and no portrait frame. This is the existing rule in
  `GameDialogueBox.gd:20`, unchanged; the class comment is extended at `:7–8`.
- `Scripts/Tools/build_portraits.gd` (new, re-runnable) crops a head from the front-view frame of art already in the
  repo. The square starts at the first opaque row and is centred on the head's columns. It writes
  `<sprite dir>/portrait.tres` (AtlasTexture) and links it into `dialogue_quest/characters/*.tres` by a text edit,
  which keeps their uids (ResourceSaver dropped them). Portraits:
  - Kusakam (`KUSAKAM`, `Кусакам`) ← `Sprites/Player/Idle/2.png`
  - grandfather ← old_man; blacksmith; merchant (`Торговец`); gate guard; oath priest / witch / dervish
    (dervish shifted 14 px down, past his tall hat); Malik; prisoner; alchemist (`SCIENTIST`)
  - Brass Collector, fire djinn (48 px crop)
  - Astrit, Alisia, Urizen ← their existing D243–D245 `portrait.tres`
  - No art, so no portrait (name only, no empty frame): bandits, `Враг`, `VILLAGER_1`, `PRIEST`, `Суан`,
    `Гном_механник`, `Три_темніх_жреца`.

### 37 — objective plaque
- `SampleProject/UI/Components/combat_hud_top.gd:56` `show_plaque()`: on a new or changed objective the plaque fades in,
  holds `OBJECTIVE_PLAQUE_HOLD` (5 s), then fades out over `OBJECTIVE_PLAQUE_FADE` (0.6 s, `UITokens.gd:264`). The
  objective stays set; only the alpha changes.
- It shows again after any menu:
  - `:71` `_on_frame()` watches `SceneTree.process_frame`, which runs during pause too, for the pause → play edge. The
    Game Menu, shop, forge screens and tutorial window all pause the tree, so this covers them all and any future
    pausing menu.
  - `:78` handles `EventBus.dialogue_finished`, because a dialogue does not pause the tree.
  - The HUD itself was not switched to PROCESS_MODE_ALWAYS, so its menu button stays inert under pause.
- `SampleProject/Scripts/Menus/Game/journal_component.gd:145, 165` `_append_live_objective()`: `Game.current_objective`
  (for example "Return to the village") becomes a current sub-row under the current zone in the Quests list. It is
  skipped when story.json already lists the same text, so there are no doubles.

### 33 (non-art) — gift popup and loot feed
- `SampleProject/Scripts/Managers/UI/UIManager.gd:176` `show_obtained(items)` queues the existing ItemPickup modal
  family. The template is `ModalTemplates.items_obtained`, `modal_templates.gd:110`, with title "You obtained:" and
  one "<Item> × <N>" line per item.
  - `:200`: it shows only when the game is free: the player is not held (`Player.event`: dialogue or cutscene), no
    dialogue or cloud talk is running, the tree is not paused, no UI state or other modal is open. It shows one
    popup per gift, in order.
  - Callers:
    - grandfather's gift, `Village.gd:267`
    - task hand-outs and rewards, `task_service.gd:76`
    - Mayor Hall victory loot, `MayorHall.gd:124` (it appears in the Laboratory once the cutscene lets go)
  - Closes with Enter / pad A / click on OK, or B / Esc (existing modal behaviour).
- `EventBus.loot_picked_up(item_id, amount)` (`EventBus.gd:398`) is emitted by mob coin pickups (`Coin.gd:70`) and
  `LootSystem` coins (`LootSystem.gd:29`).
- `SampleProject/UI/Components/loot_feed.tscn/.gd` (new; instanced in `Game.tscn` under `UICanvas/CombatHUD`, so it
  inherits GameUITheme): a column of toasts at the top right, under the currency row.
  - Each toast is a theme `PanelContainer` (HUD surface) holding a 24 px item icon and a `UILabel` "Coin × 12".
  - A repeat of the same item adds to its live toast and keeps it up longer.
  - New items stack on top, at most `LOOT_FEED_MAX` (4); each toast fades after `LOOT_TOAST_HOLD` (2.5 s).
  - Gifts do not go to the feed; they get the popup.

## Decisions (ready to paste; agent calls, Sapega to confirm)

- **D3xx (36)**: The speaker's name is centred across the top of the dialogue box, on the Auto / Skip row as an
  overlay that mouse clicks pass through. The speaker's portrait is in the existing frame on the right. Portraits are
  head crops of the art the game already draws: the hero, every NPC with a sheet, both bosses, and the D243–D245
  companion portraits. They are built by `Scripts/Tools/build_portraits.gd`. Speakers without art (bandits, villager,
  enemy, the old priest, Суан, the gnome, the dark priests) show their name and no frame. Narration shows neither. Name
  colours stay as authored (Q31: they do not matter); the box's purple override is removed.
- **D3xx (37)**: The HUD objective plaque fades in on a new or changed objective, holds 5 s and fades out in 0.6 s.
  It comes back each time the game leaves pause (Game Menu, shop, forge, tutorial window) and when a dialogue ends.
  Re-entering a room re-sets the objective, so it also shows on room entry. The current objective is also a "●"
  sub-row under the current Journal item, unless story.json already lists the same text.
- **D3xx (33, non-art)**: Items someone gives the hero (the grandfather's gift, task hand-outs and rewards, the Mayor
  Hall loot) open the same "You obtained:" modal as pickups, one line per item. It waits until no dialogue, cutscene,
  menu, pause or other modal is up, so the grandfather's gift shows after the LeavingVillage talk and the Mayor Hall
  loot shows in the Laboratory. Mob loot (coins) is a HUD toast under the currency instead: "Coin × N", summed per
  item, at most 4, fading after 2.5 s. It never opens a modal. Shop buys and crafting keep their own modals.

## New bugs (B-ID text)

- **B-new (tooling)**: `Scripts/Tools/godot_locked.sh` is committed as mode 100644. On Linux / cloud,
  `run_verify.sh` calls it directly, so every test logs "Permission denied" and the suite reports 72 FAIL with no
  RESULT lines. Fix: `git update-index --chmod=+x Scripts/Tools/godot_locked.sh` (same for `run_verify.sh`). This
  branch only did a local `chmod +x` and did not commit it.
- **B-new (content, low)**: many speaker names in `dialogue_quest/characters/*.tres` are Russian / Ukrainian ("Дед",
  "Торговец", "Разбойник", …). English UI shows Cyrillic names, now centred and prominent. Belongs to BACKLOG 31
  (two languages).
- **B-new (cleanup, low)**: `Game.tscn` still has the `ObjectiveHUD.tscn` ext_resource (`10_objective`), but nothing
  instances it, so it is dead since `combat_hud_top` replaced it. Left alone.

## Verifies run (Linux, Godot 4.6.2, headless)

| Verify | RESULT |
|---|---|
| verify_dialogue_speaker (new: narration / Kusakam / grandfather / three companions; Enter, pad A, click) | ALL PASS |
| verify_objective_plaque (new: fades; back after Esc menu, pad Start menu, Enter-ended dialogue; Journal row, no double) | ALL PASS |
| verify_gift_popup (new: pad X kill → one summed toast, stacking, cap, fade; grandfather gift after the talks, Enter; helmet reward pad A; enchant hand-out click) | ALL PASS |
| verify_npc_recall ([5] now expects the grandfather's portrait) | ALL PASS |
| verify_npc_arrival (closes the caravan reward popup with ui_accept before Buy) | ALL PASS |
| verify_game_ui_theme | ALL CHECKS PASSED |
| verify_journal, verify_journal_sections, verify_story_journal, verify_combat_hud | ALL PASS |
| verify_tasks, verify_starter_loot, verify_mayor_hall, verify_combat_flow, verify_scripts_compile | ALL PASS |
| verify_audio | 1 FAIL in a single run ("focusing a button ticks on SFX"), also on the clean branch; passed in the full suite (flake) |
| **Full suite `Scripts/Tools/run_verify.sh`** | **SUITE: ALL PASS (72 / 72)** |

## Left

- 33 chests (art lane A1): the chest frames and Kusakam's raise-the-item pose. The popup is ready to be reused as
  `ui.show_obtained({...})`.
- Mob drops other than coins do not exist yet (item 14 leftover). When they do, emit `EventBus.loot_picked_up` from
  their pickup and the feed shows them.
- No window capture or Figma comparison was possible here. Someone needs to look at it in the editor or exe: the
  centred name over the Auto / Skip row, the portrait crop of each NPC (dervish and gate guard most of all), and the
  toast column under the currency.
- The portrait `.tres` files have no `.uid` sidecars, because headless does not write them. The editor adds them on
  the next open.
- After merge with cloud/b82-b10 (Auto button removed): check that the name overlay still centres. It is independent
  of the button row, so it should.
