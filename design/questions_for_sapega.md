# Questions for Sapega

Open questions from the Runtime UI Completion plan (`runtime_ui_completion_plan.md`).
None blocks the start of the work. Each has a **default** that will be used until
answered, and names the slice it affects.

> ## ✅ Q1–Q28 closed — 2026-09-29. **Q29–Q35 are open**; Q36–Q37 answered (D121) (two sections below).
>
> Sapega answered **Q1–Q28** in one pass. The decisions are recorded as
> **D88–D115** in [[figma_decision_register]] §8. Q1 needed no decision.
>
> **Seven answers reverse shipped code** (slices 1b, 2, 8) — D89, D90, D91,
> D99, D104, D105, D108. See the table at the top of §8 before touching those
> areas; a passing `verify_*` there reflects the *old* decision.
>
> **Slice 4 (Crafting) is unblocked** by D97 (mock prices) and D108 (all four
> stations). **Enchanting is back in scope** (D94). Open work is tracked in
> [[BACKLOG]].
>
> The table below is kept as the historical record of what was asked and what
> the provisional defaults were. It is no longer a to-do list.

Answer by number. Answered questions move to [[figma_decision_register]].

## Opened by the Prologue journal plan, 2026-10-12 — [[prologue_journal_plan]]

| # | Area | Question | Default until answered |
|---|---|---|---|
| Q36 ✅ D121 | Journal | **Display titles of the six prologue zones.** Only code names exist (`StoryState`: CANYON, VILLAGE, DESERT_ROAD, CITY_GATES, LABORATORY, LAB_OUTSIDE). What should the journal call them? | English, 1:1 from scene names: Canyon · Village · Desert Road · City Gates · Laboratory · Laboratory — Outside. |
| Q44 ✅ D152 | [[room_state_plan]] | **Re-entering a room — what happens to its enemies?** (a) fresh every time · (b) exactly as left: dead stay dead, living keep HP, until the fight is won · (c) as (b) but reset on save-point rest. | (b) for scripted story fights. |
| Q45 ✅ D153 | Camera | **Camera vs room size.** The camera shows 1920×1080 world px (zoom 1) while a MetSys cell is 864×480, so every room is smaller than the screen and empty space shows around it. Zoom the camera ×2.25 (view ≈ 853×480, sprites look 2.25× bigger) · or make cells 1920×1080 and redraw rooms · or leave it. | Leave it until answered. |
| Q43 | Skills | **How are Fire Strike and Electric Strike learned?** Healing Palm comes from the old man (D140); the other two have no story moment. | ✅ Answered → D149. |
| Q42 | [[cutscene_plan]] | **What should a cutscene show, and which story beats get one?** Candidates: Canyon abduction, Village abduction, Canyon descent, Mayor's Hall → Laboratory, lab boss intro. Per beat: dialogue only · dialogue + fade/camera · fully staged. | ✅ Answered → D140. |
| Q41 | [[character_animation_plan]] | **Art for the bandit, gate guards, lab boss; which NPCs get idle animations?** | ✅ Answered → D139. |
| Q40 | [[character_animation_plan]] | **Which art is Kusakam?** Commission frames like `QusajamSprite` · adopt a pack already in `assets/` · extend the current 64×64 frames. | ✅ Answered → D138. |
| Q39 | Journal | **"Return to the village" is a live HUD / Objective-panel hint, not a journal list entry.** Canyon sets it (`Canyon.gd:367, 693`) when the player walks back into the Canyon after the Village started but before it finished. The journal list is built only from `story.json` flags (D125), so the hint is not in the list. Should navigation hints appear in the list (as an objective under Village, with its own flag), or stay a panel-only hint? | Panel-only (today). |
| Q38 | [[music_plan]] slice 2 | **Which music plays where?** Rooms: Canyon, Village, Desert Road, City Gates, City, Mayor's Hall, Laboratory, Laboratory — Outside, plus the Main Menu (and boss fights?). Tracks on hand: Desert Music pack — Dunes of Silence, Scorchlight Mirage, Whispers in the Sand, Canyon Echoes, Sunblade Horizon, Ash and Oasis (loop and full versions); Brackeys — Time for Adventure. | **Applied 2026-10-14 (Sapega: "connect it somehow"):** a provisional track per room — `Resources/Audio/Music/README.md`. Change by answering. |
| Q48 | [[npc_recall_plan]] slice 3 · roadmap 2.1 | **Speech bubbles "як в аніме"** (Figma `164:1318`): for every dialogue, or only NPC chatter and replays, keeping the box `127:1087` for story? | Not applied — blocks only the bubble slice. |
| Q37 ✅ D121 | Story text | **Objectives are half English, half Ukrainian** — Canyon sets "Explore the Canyon", Village sets "Дослідити село". Which language is the source, before localization? | Show them as authored; do not rewrite text. |

## Opened by the 2026-09-29 scene inventory audit — [[scene_inventory]]

| # | Area | Question | Default until answered |
|---|---|---|---|
| Q34 | Content / maps | **The 18 `Maps/Legacy/*.tscn` are unreachable, and they hold the only placements of 9 world-object scenes.** Not one Legacy uid appears in `SampleProject/Maps/MapData.txt` (`StartingRoom.tscn` has no uid at all), so MetSys cannot load any of them. But `Objects/{Portal, MiniPortal, Pipe, Elevator, Button, MapItem, Spikes, Collectible}.tscn` are referenced **only** from Legacy maps, and the 8 live maps contain zero instanced sub-scenes — just `TileMap`, `RoomInstance` and inline `Area2D`s. Are the Legacy maps a parts bin to harvest for the real maps, or dead weight to delete along with the 9 objects? | **Keep both, delete nothing.** Deleting is irreversible in review terms and `Objects/Portal.tscn` in particular may be wanted once room-to-room content exists. Cost of keeping: 27 orphan scenes and `Maps/Legacy/EndingPoint.tscn:56,59` still loading `Game.tscn` / `MainMenu.tscn`. |
| Q35 | Combat content | **Three orphans with no scene and no spawner: `EnemyRanged.gd`, `DemoBoss.gd`, `player_projectile.tscn`.** Enemy variety ships as `EnemyStats` resources on one `default_enemy.tscn` (`melee`, `fast`, `tank`), and there is no `ranged` or boss resource. `EnemyRanged.gd:6` declares `projectile_scene: PackedScene = null` and nothing ever assigns it, so `player_projectile.tscn` can never spawn; `DemoBoss.gd` is referenced by nothing, and `Laboratory.gd:180-186`'s "boss fight" spawns ordinary enemies. Build the ranged enemy and the boss, or delete the three files? | **Leave them; do not build and do not delete.** No decision covers either, and inventing a ranged enemy's stats or a boss's phases would be inventing numbers. Note this is the same shape as the companion scripts — same triage, tracked in [[BACKLOG]]. |

## Opened after the 2026-09-29 screenshot review

| # | Area | Question | Default until answered |
|---|---|---|---|
| Q29 | Shop | **Currency glyph is `₹` — the Indian rupee sign.** `UITokens.CURRENCY_SYMBOL` takes it from Figma and `verify_shop.gd:72` asserts it, so the code is faithful; the question is whether **Figma** meant a gold-coin glyph and the rupee is a stand-in. Also inconsistent: shop rows render `₹ 10`, while the top bar and party panel show the same currency as a bare number next to a coin icon. | Keep `₹` (Figma is the visual source of truth) and keep the inconsistency, until you say otherwise. |
| Q33 | Selection language | **Three different ways to say "this row is selected" ship side by side.** Journal entry list = full `#d4af37` fill · sidebar tab = `#d4af37` border · NPC action menu = **no accent at all**, only a chevron plus text alpha (`Talk` `#ffffff` vs `Buy` `#b5b5b7` = `MENU_INACTIVE_ALPHA`) · main menu = plain white text with `▶`, no gold anywhere. The NPC menu and the main menu are both built from Figma `UI/Menu Item 248:62`, so this needs **one** answer, not four fixes. Which is canonical? | No change until decided. Do not "fix" any single screen toward the others. |
| Q32 | Save / Load | **Empty slots look identical in load and save mode.** A pixel diff of the two modes shows only three changed regions outside the modal: the title, the hint line, and slot 1's highlight — slots 3 and 4 are pixel-identical, with `#ffffff` borders and full-weight `#ffffff` text, same as a loadable slot. In **load** mode an empty slot is not selectable; `TEXT_MUTED #666666` and `TEXT_DISABLED #404040` exist in the tokens and are used nowhere on this screen. "No save data available" is also load-mode phrasing reused where the slot is a valid save target. Mute and relabel per mode, or keep one presentation? | Keep one presentation until you decide — confirm against `load-game-screen 150:1278` / `save-game-screen 17:5` first. |
| Q31 | Dialogue | **Speaker names render in per-character colours outside the palette** — "Кусакам" shows magenta (≈`#c77ad6`). This is **not** a hardcoded UI colour: DialogueQuest reads `chara.color` off the character resource (`dialogue_player.gd:386` → `dialogue_box.set_name_color()`), so it is authored content. Should character colours be constrained to the token palette, or is per-character colour a deliberate readability device? | Leave the authored colours alone until D110 builds the project-owned presentation layer, then decide there. |
| Q30 | Bottom bar | **Input hints are gamepad-only** (`L/R Switch Category`, `A Confirm`, `B Back`) on every screen, but play is currently mouse-only. D98 already established that the interaction prompt swaps `E`/`A` with the last-used device. Should the bottom bar follow the same rule? | Leave as-is; D98 is scoped to the interaction prompt only. |

| # | Slice | Question | Default until answered |
|---|---|---|---|
| Q1 | — | Your message starts at item 3. Were items 1 and 2 intentional, or did they get lost? | Treat the plan as complete without them. |
| Q2 | 1a | **Which pickups use prompt + confirmation modal (D71)?** Today everything is picked up on touch: coins, orbs, enemy loot. Showing a modal for every coin would stop play constantly. **Found in slice 1a:** no world object in the production maps gives an inventory item (orbs exist only in legacy maps and only raise a counter). `ItemPickup.tscn` is built and tested but not placed. Where should pickups go, and should orbs/chests become `ItemPickup`s? | Only world item pickups use it. Coins and enemy loot stay automatic. No map placement until you name items and places. |
| Q3 | 1b ✅ default applied | The Figma slot card shows **level, lead character, party portraits and a region name**. Save metadata has only date, room name and playtime. Store level and lead character (real data exists) and leave party portraits and region out until art/data exist? | Store level + lead character name. Show the room name as the location. Omit region and portraits. |
| Q4 | 1b ✅ default applied | Player data (`player_data.json`) is saved to **one shared file, not per slot**, so loading slot 2 may restore slot 1's inventory and stats. Fix this inside slice 1b? | Yes: make player data per slot. It is required for slot selection to be correct. |
| Q5 | 1b ✅ default applied | Save points **auto-save on touch** today. After the change (prompt → slot selection), should auto-save on touch be removed, or kept as a silent quick-save? | Remove it. Saving only through the prompt. |
| Q6 | 5 ✅ default applied (Figma confirms "Return to title") | **Game Over behaviour.** Today the player is teleported back and healed. What should the Game Over options do: "Resume from last save point" = reload the last saved slot? What is the second option (return to title?)? | Resume = reload the slot last saved or loaded. Second option = return to title. |
| Q7 | 1b ✅ default applied (Delete / pad Y) | The runtime has a **delete save slot** action that Figma doesn't show. Keep it? | Keep it (no removal of existing functionality). Styled with the same modal family. |
| Q8 | 3 ✅ default applied | Blacksmith menu includes **Enchant**, but Enchanting is out of scope. Hide the entry or show it disabled? | Hide it. |
| Q9 | 3 ✅ default applied | Remove the old "blacksmith = shop Equipment mode" path in slice 3, or keep it until later? | Remove it once the Blacksmith NPC works (D69). |
| Q10 | 4 | `ForgeSystem.gd` is an 8-line stub. Replace it with the new `CraftingManager`, or keep both? | Replace it. |
| Q11 | 4 ⛔ **BLOCKING** | Recipes need a **gold cost** (D85). **Confirmed in slice 4: `crafting_recipes.json` has no price field** for any of the 18 recipes (all ingredients/results exist in `items.json`). Please give a gold cost per recipe — see *Q11 price sheet* below. | Slice 4 stopped here. No invented numbers. |
| Q12 | 1a | Prompt input badge: keyboard **E** + gamepad **A**, switching with the last used input device? | Yes. |
| Q14 | 1a | The pickup modal reuses the shared modal family (D79), which is larger than Figma's compact `UI/Modal/ItemPickup` card (327×140, small "You obtained:" caption over a larger item name). Build a dedicated compact pickup card, or keep the shared modal? | Keep the shared modal. |
| Q15 | 2 | The Figma shop replaces the party column with **Party Equipment Effects** (per-character stat changes, e.g. MAX HP 740 → 810). No stat-comparison logic exists yet. Build it (needs equip-slot rules per character), or keep the normal party panel? | Keep the normal party panel for now. |
| Q16 | 2 | Figma's category icons (sword, shield, helmet, bell, scroll) vs our item data: we map **sword → weapons, shield → shields, helmet → other armor, bell → accessories (none exist yet), scroll → consumables + materials**. OK? | Use this mapping. |
| Q17 | 2 | Figma's shop sidebar has **Equipment** next to Buy/Sell. What does it do in a shop (equip what you just bought)? D69 already says the Blacksmith is not a shop mode. | Hidden until defined. |
| Q18 | 2 | The Figma buy confirmation shows **Quantity: 4**, but no quantity picker is designed. Buy one at a time, or add a quantity selector? | One at a time (Quantity: 1). |
| Q19 | 2 | Figma has no "not enough gold" state. We show a modal "Not Enough Gold — You need ₹ N to buy X." from the shared family. OK, or grey out rows you can't afford? | Keep the modal. |
| Q20 | 3 | `merchants.json` has a **"blacksmith" stock list** (ingots, swords, iron armor), but the Figma blacksmith menu has no Buy. Should the blacksmith also sell, or is that data obsolete? | No Buy on the blacksmith; data left untouched. |
| Q21 | 3 | The merchant and blacksmith now use the Figma NPC art (`npc/merchant`, `npc/blacksmith`). Is that art final for in-game use, or placeholder? | Use it until replaced. |
| Q22 | 4 | Every recipe names a station: **furnace** (4 smelting), **workbench** (wood plank, leather armor), **anvil** (swords, iron armor/helmet/shield), **alchemy_table** (6 potions). The blacksmith is the crafting entry (D69). Which stations does the blacksmith cover — all four, or only furnace + anvil (+ workbench)? | Blacksmith offers furnace + anvil + workbench recipes; alchemy waits for its own NPC/station. |
| Q23 | 5 | "Resume from last save point" when **no save exists yet** (e.g. dying before the first save point): today we fall back to the old respawn at the room entrance. Keep that, or hide/disable Resume in that case? | Keep the fallback respawn. |
| Q24 | 6 | **D83 decision — dialogue presentation.** (A) restyle through project scenes extending the addon's `DQDialogueBox` / `DQChoiceMenu` (small–medium, tied to the rc addon's node names), or (B) own presentation layer (medium–large; the addon doesn't expose say text, so we'd write our own DQD player). See `dialogue_audit.md` §3. | No work until decided. Recommendation: A now, B only when story scenes exist. |
| Q25 | 7 | Which scenes are **special story scenes** (D70), and what are their chapter titles? None exist in data or code. | Slice 7 waits. |
| Q26 | 6/7 | **Portraits:** no character has portrait art. Figma's standard box has none (fine), but story scenes (`36:65`) need two 160×320 portraits. Who provides them? Also: hide the addon's empty portrait frame in standard dialogue? | Hide the empty frame; story scenes wait for art. |
| Q27 | 6/7 | No `.dqd` uses **choices** yet, but Figma designs a choice list (`258:5108`) and story scenes rely on it. Are branching dialogues planned for this build? | Style the choice menu with the box (option A); no content work. |
| Q28 | 6 — partly applied: stray `.dqd.tmp` removed in slice 8; speaker ID merge and text tags untouched | Dialogue data cleanup: `KUSAKAM` and `Кусакам` are two IDs for one character; location tags like `[Village]` / `[PLACEHOLDER]` are typed into lines; 8 stray `.dqd.tmp` files. OK to clean up in slice 8? | Yes, in slice 8, no text changes. |
| Q13 | 8 ✅ default applied | `CLAUDE.md` says "154 tests (100% pass)", but no GUT tests exist; the real suite is 17 verify scripts. Update `CLAUDE.md`? | Yes, in slice 8. |

## Q11 price sheet — fill in the gold cost

Current recipes from `SampleProject/Resources/Data/crafting_recipes.json`. Fill the last column
(gold paid on top of the materials, D85). The value will be stored as `"gold_cost"` on each recipe.
For reference, `buy_price` of the result item is shown where it exists in `items.json`.

| Recipe id | Result | Materials | Station | Gold cost |
|---|---|---|---|---|
| smelt_iron_ingot | Iron Ingot ×1 (buy 30) | Iron Ore ×2 | furnace | ? |
| smelt_copper_ingot | Copper Ingot ×1 (buy 20) | Copper Ore ×2 | furnace | ? |
| smelt_silver_ingot | Silver Ingot ×1 (buy 150) | Silver Ore ×2 | furnace | ? |
| smelt_gold_ingot | Gold Ingot ×1 (buy 300) | Gold Ore ×2 | furnace | ? |
| craft_wood_plank | Wood Plank ×4 (buy 10) | Wood Log ×1 | workbench | ? |
| craft_copper_sword | Copper Sword ×1 (buy 100) | Copper Ingot ×3 + Wood Plank ×1 | anvil | ? |
| craft_iron_sword | Iron Sword ×1 (buy 200) | Iron Ingot ×3 + Wood Plank ×1 | anvil | ? |
| craft_silver_sword | Silver Sword ×1 (buy 600) | Silver Ingot ×3 + Wood Plank ×1 + Mana Crystal ×1 | anvil | ? |
| craft_potion | Potion ×2 (buy 20) | Herb ×2 + Stone ×1 | alchemy_table | ? |
| craft_hi_potion | Hi-Potion ×1 (buy 100) | Potion ×2 + Mana Crystal ×1 | alchemy_table | ? |
| craft_ether | Ether ×2 (buy 30) | Mana Crystal ×1 + Herb ×1 | alchemy_table | ? |
| craft_leather_armor | Leather Armor ×1 (buy 160) | Leather ×5 + Wood Plank ×2 | workbench | ? |
| craft_iron_armor | Iron Armor ×1 (buy 300) | Iron Ingot ×5 + Leather ×3 | anvil | ? |
| craft_iron_helmet | Iron Helmet ×1 (buy 120) | Iron Ingot ×2 + Leather ×1 | anvil | ? |
| craft_iron_shield | Iron Shield ×1 (buy 180) | Iron Ingot ×3 + Wood Plank ×2 + Leather ×1 | anvil | ? |
| craft_potion_lesser_chain | Lesser Potion ×1 (buy 40) | Potion ×2 | alchemy_table | ? |
| craft_potion_medium_chain | Medium Potion ×1 (buy 70) | Lesser Potion ×4 | alchemy_table | ? |
| craft_hi_potion_chain | Hi-Potion ×1 (buy 100) | Medium Potion ×8 | alchemy_table | ? |
