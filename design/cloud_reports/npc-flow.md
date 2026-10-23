---
type: report
status: done
tags: [cloud, npc, playtest]
---

# Cloud routine: npc-flow (how NPCs meet the player, playtest 2026-10-23)

Branch `cloud/npc-flow`, from `feature/backlog` @ `ca8c2d1b`. Rules: [[ROUTINE_RULES]].

**Summary**
- **Done:** D442 (the `NpcArrival` zones and `Merchant_Arrival` / `Smith_Arrival` are gone, and the NPCs stand at their stations; yellow "!" for a story quest, blue "!" for a side quest, gone once taken), D452 (a crest for the oath keepers; quest givers call out once per visit, with uk/en drafts marked [ЧЕРНЕТКА]/[DRAFT]), D454 (the menu opens by itself and is not modal; Up/Down pick, Interact chooses, leaving closes it).
- **Not done:** Malik (Laboratory, giver of `malik_escort`) is not an `NpcBase`, so he gets no marker or bark. The Desert Road ledges and enemies were not touched.
- **D-ID text:** D516, D517, D518 below. D485 was already taken in the register.
- **B rows fixed:** none.
- **Full suite:** 93 PASS / 1 FAIL (`verify_oath` still used the old E step). After fixing it, `verify_oath` alone gives RESULT: ALL PASS, so 94 / 94.

## What changed
- **Arrival removed:** `Maps/DesertRoad.tscn` (MerchantArrival) and `Maps/City.tscn` (BlacksmithArrival), with their ext/sub resources, are gone. So are `Scripts/Gameplay/NPCs/NpcArrival.gd` (+ .uid), the four `*_Arrival.dqd` files (uk + en), and `NpcActivity.held` / `resume()` (only the cutscene used them). The `ShopDoor` / `ForgeDoor` markers stay, because captures teleport to them. The `desert_road_merchant_met` / `city_blacksmith_met` flags are no longer read or set, and the tests that set them were cleaned up.
- **Marker:** `UI/Components/quest_marker.gd` is a new preloaded component with no class_name. It draws pixel art in code from two patterns (a 4×10 "!" and a 7×9 shield with a cross), with a dark outline. Colours and sizes come from new tokens in `UITokens.gd:305` (`QUEST_MARK_STORY` = ACCENT, `QUEST_MARK_SIDE` #4a9cff, `QUEST_MARK_OATH` #c9cdd8, outline, 3-px cell, 4-px gap). It is sized for the screen, like the other world UI.
- **Who shows what:** `NpcBase.quest_marker()` (`NpcBase.gd:159`) shows side when a task in `quests.json` is open and not taken. `StoryNpc.quest_marker()` (`:31`) shows story until `quest_flag`. `OathKeeper.quest_marker()` (`:40`) shows oath until any oath is sworn. The marker refreshes on `quest_flag_changed` (task givers) and `oath_sworn`.
- **Bark:** the new `NpcBase.quest_bark_dialogue` plays through `DialogueManager.say_in_passing` (D338), once per room visit, and only while the NPC has a marker; otherwise `chatter_dialogue` plays (`_say_in_passing`, `:221`). Lines: `Merchant_Bark`, `Smith_Bark`, `OldMan_Bark`, `City_Oath_{Priest,Witch,Dervish}_Bark` in `dialogue_quest/` and `dialogue_quest/en/`, set in the six NPC scenes. Lines go to Sapega under Q67.
- **Auto menu:** `InteractableComponent.show_prompt` is a new property, and NPCs set it to false (`NpcBase.gd:77`). `_process` opens the menu when `_wants_menu()` (`:117`) is true, and closes it while a dialogue or modal is on top (`:99`). `npc_action_menu.gd:75` swallows any event that is both `ui_accept` and `jump` (Space, pad A).

## D-ID text (for the register)
| D516 | GAP | **Quest markers, as built** (D442, D452; agent call, Sapega to confirm; `cloud/npc-flow`). A pixel icon drawn in code (`UI/Components/quest_marker.gd`, no texture), screen-sized, above the sprite top: yellow "!" (ACCENT) while a story NPC's quest is not given (the grandfather until `village_oldman_complete`); blue "!" (#4a9cff) while an NPC has a `quests.json` task open and **not yet taken** (an active task waiting for hand-in shows nothing); a silver shield-with-cross crest (#c9cdd8) on **all three** oath keepers until any oath is sworn, shown below level 5 too (the menu says "Come back at level 5"). Priority story > oath > side. The marker hides while the NPC's own bark cloud stands in the same spot. Malik (Laboratory) is not an `NpcBase` and has no marker. Supersedes D294; the `*_met` flags are retired. |
| D517 | GAP | **The quest-giver bark** (D452; agent call). "Within earshot" = the NPC's interaction range, the same one that opens the menu; the bark and the menu come together. The bark (`NpcBase.quest_bark_dialogue`, D338 cloud route, once per room visit) plays only while the NPC shows a marker; after the quest is taken he falls back to `chatter_dialogue` (none written yet). Drafts for the merchant, blacksmith, grandfather and the three keepers, uk + en, `[ЧЕРНЕТКА]` (Q67). The D277 voiced greeting now plays once per room visit, when the menu first opens, not on every approach. |
| D518 | GAP | **The self-opening menu, details** (D454; agent call). No [E] prompt on NPCs (`InteractableComponent.show_prompt = false`). Space and pad A are jump and never choose a row; Interact (E / Y) chooses, and Enter still works. ui_cancel closes the menu until the hero leaves the range, and E reopens it. While the hero stays in range, the menu comes back by itself after a talk, the shop, the forge or a reward popup. It steps aside while a dialogue or modal is on top. Picking a row ends the bark cloud. Oath "Not yet" returns to the keeper's main menu. |

## Tests (RESULT lines)
- `verify_npc_flow.gd` (new): markers (token colours, shapes, story → gone on the flag, side → gone on take → back for The Enchantment, crest → gone on swear), bark (once per visit, silent with no quest, uk/en drafts), auto menu (no prompt, focus, Space does not pick, Up/Down, cancel stays closed, E reopens, Interact picks Talk, comes back after the talk, leaving closes). RESULT: ALL PASS.
- `verify_npc_arrival.gd` (rewritten [2]–[3b], [6] updated): no NpcArrival; the merchant and the smith stand at their stations with a blue "!"; a real `move_right` walk-up starts no cutscene, the menu opens while the hero keeps running, a bark and a greeting play, and Quest gives the task and removes the "!"; the City merchant's menu waits under the reward popup and comes back after it. RESULT: ALL PASS.
- Updated for D454: `verify_npc_chatter`, `verify_interaction` [10], `verify_blacksmith` [3], `verify_npc_activity` [3]–[5], `verify_oath`, `verify_audio` [5], `verify_cutscene` (the merchant-arrival skip is gone; pad Y now skips the canyon descent). All ALL PASS.
- Full suite: 93 PASS, 1 FAIL (`verify_oath`, now fixed: ALL PASS).

## Shot
`design/shots/npc_flow_sheet.png` (`capture_npc_flow.gd`): the City with a blue "!" over the smith and a crest over the priestess; the smith's menu opened by itself with his bark; the Village with a yellow "!" over the grandfather. The marker is small at 1080p (12×30 px), so a bigger `QUEST_MARK_PIXEL` is a one-token change if Sapega wants it.
