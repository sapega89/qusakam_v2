---
type: report
branch: cloud/journal-hints
tags: [cloud, journal, story]
---

# Cloud report: journal-hints (MASTER_PLAN S6, S7)

**Summary**
- Done, S6 / D159: every main-path objective in `story.json` (all 19) now has a `hint` and a `from` (a DialogueQuest speaker id). The Journal Quests list shows the hint as a wrapped, muted row right under the **current** objective, for example `Malik: “The way out is at the bottom…”` / `Малік: «Вихід — унизу…»`. The texts are Claude's drafts, marked `# [ЧЕРНЕТКА] D159` in uk.po and `# [DRAFT] D159` in en.po, for Sapega to edit.
- Done, S7 / D181: the Quests list puts a location header row (`CANYON OF WHISPERS`, `THE CITY`, `THE LABORATORY` from locations.json, in that file's order) before each group. NPC tasks stand in their own location, set by a new `location` field in quests.json.
- Not done: a check against Figma `192:1636`, because Figma can't be reached from the cloud. The header reuses the existing `QuestCaption` look as a list row.
- **D781** (next free on `feature/backlog` @ `b5cda2cf`; renumber it if another routine has taken it): text below.
- B rows fixed: none.
- Full suite: `SUITE: 1 FAIL` (131 PASS). The one failure is `verify_audio` (1 FAIL), which passes when run alone (`RESULT: ALL PASS`). That is a flake in audio code this branch doesn't touch.

## D781 text (ROUTINE CALL)
| D781 | ROUTINE CALL | **Journal Quests: hints and location groups built** (`cloud/journal-hints`; D159, D181, D565, D714). **Groups:** the Quests list is grouped by the locations of `locations.json`, in file order, under one header row per location: `ListGroupRow`, an accent caption in `QuestCaption` size that can't be selected. The header carries the location's name: Canyon of Whispers (the canyon, the village, Canyon II and the desert road), The City (the City Gates) and The Laboratory. This replaces the single «PROLOGUE» stage caption, and the item's eyebrow on the right now shows the location too. D181's *Bab ar-Rimal* stays the City's provisional name (Q54) and is not shown: the header uses the same name as the World Map. NPC tasks stand at the end of their location's group (`quests.json` `location`: caravan, helmet and enchant → city; Malik's escort → laboratory). The separate «Tasks» group is gone. **Hints:** each `story.json` objective has `hint` (an English key) and `from` (a DialogueQuest character id). The hint shows only under the **current** objective (a done one no longer needs it), as a `ListHintRow` reading `<Speaker>: “<hint>”` (uk `«…»`). If no NPC gives the objective, the hint is Kusakam's own first-person thought, taken from his monologue. The 19 texts are drafts, `[ЧЕРНЕТКА]` / `[DRAFT]` D159 in the .po comments. Live HUD-only objectives («Return to the village», «Find the laboratory», «Talk to the old man»…) have no hint, because they are not in story.json. |

## Details
- `SampleProject/Resources/Data/story.json`: `hint` and `from` on all 19 objectives. Speakers: GRANDFATHER, for «Leave the village», uses Sapega's sentence from D159 («Іди в бік каньйону і вийди на дорогу в пустелі»), plus «Descend to the road». MERCHANT gives «Defeat the enemies on the road», GATE_GUARD «Defeat the bandits», and MALIK «Fight through the laboratory» and the outside «Leave the laboratory». The rest are KUSAKAM. Each hint comes from the dialogue that gives the objective: Canyon_Intro/Exploration, Canyon_AbductionCutscene, Village_AfterFight, OldMan_Decision, DesertRoad_Merchant_Chatter, CityGates_Raid/AfterFight, Lab_Cells_Awake, Lab_Acquaintance, Lab_Boss_Talk, Laboratory_AfterBoss and Demo_End. LAB_BOSS was not used as a speaker because its name is still «The Mercenary [DRAFT]».
- `SampleProject/Resources/Data/quests.json`: `location` on each task.
- `SampleProject/Scripts/Managers/Story/GameFlow.gd`: `journal_entries()` adds each zone's `location` (`LocationDB.of_room(zone.scene)`), and `_objectives()` passes on `hint` and `from`.
- `SampleProject/Scripts/Menus/Game/journal_component.gd`: `_load_story()` sorts items into per-location buckets, adds the hint row (`kind: "hint"`, parent = the objective) and files tasks by location. `hint_line()` formats the hint row. `_rebuild_rows()` inserts the header rows in the Quests section and sets hint rows to disabled and unfocusable with word wrap. It also scrolls the list so the selected item and its objective and hint are visible, because with three groups the current item is below the fold. `%ListScroll` gets a unique name in `journal_component.tscn`.
- `SampleProject/UI/build_game_ui_theme.gd`: adds the `ListGroupRow` and `ListHintRow` variations, both from tokens (`ACCENT`, `TEXT_SECONDARY`, `SIZE_SMALL`, `SPACE_*`). Their focus is the shared ring. `GameUITheme.tres` was regenerated, which renumbers its subresources and makes the diff large.
- `Scripts/Tools/po_sync.py`: now copies `# [ЧЕРНЕТКА] Dnnn` into en.po as `# [DRAFT] Dnnn`. **Not run on this branch:** en.po holds 8 keys that uk.po lacks («New skills», «Dash out of a red-glint blow.», «Attribute points: %d · in Status»…), and a sync would drop them from en.po. Those keys need uk translations first. I appended the D159 block to en.po by hand instead.
- Tests:
  - `verify_journal`: ALL PASS. It gains the location headers and their order, Desert Road under the Canyon, the hint row under the current objective, its text, style and colour, the uk «» quotes and header, a hint that disappears once its objective is done, and a task in its location's group.
  - `verify_story_journal`: ALL PASS. Every objective's `from` is a real speaker, the hint is a draft in both .po files, and every zone lies in a location.
  - Also ALL PASS: `verify_journal_notes`, `verify_journal_sections`, `verify_objective_plaque`, `verify_tasks`, `verify_npc_recall`, `verify_locale`, `verify_locations` and `verify_game_ui_theme` (ALL CHECKS PASSED).
- Shots: `design/shots/journal_quests_en_1920.png` and `journal_quests_uk_1920.png`, from the new `capture_journal_quests.gd`. They show the Canyon and the City done, the Laboratory current, and Malik's hint under «Fight through the laboratory».
- Not committed: four `.uid` files that Godot generated for other routines' scripts (`capture_meditation_stones`, `capture_quest_panel`, `verify_boss_hits`, `verify_masher`). They were already untracked when this run started.
