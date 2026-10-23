---
type: report
branch: cloud/journal-notes
tags: [cloud, journal, story]
---

# Cloud report: journal-notes (Q87 default, journal_story_plan)

**Summary**
- Done: the Journal has a fourth tab **NOTES** (uk «ЗАПИСИ») after BESTIARY, showing the found story pieces in the order found, with the full text on the right. It has an empty state, keyboard / pad / mouse navigation, `verify_journal_notes.gd` (ALL PASS) and a capture.
- Not done: the Figma frame for the tab (plan step 1). Figma MCP was not used, so the tab follows the built list + detail layout.
- **D675** (next free; the register already has D674 on `feature/backlog`): see the text below. **Q87** is answered by its default and can move to the register.
- B rows fixed: none.
- Full suite: `SUITE: 3 FAIL`: `verify_difficulty` (2), `verify_lab_boss` (2), `verify_mayor_boss` (1). All five are boss and difficulty balance numbers, in code this branch does not touch (see Details). The other 111 pass, journal ones included.

## D675 text (ROUTINE CALL)
| D675 | ROUTINE CALL | **Journal → Notes, Q87's default built** (`cloud/journal-notes`; D622, [[journal_story_plan]]). `journal_component.tscn` gets a fourth `TabButton` `NotesTab` "NOTES" (uk «ЗАПИСИ») after BESTIARY. `journal_component.gd` `SECTIONS.notes` = page "Notes" / «Записи», list caption "NOTES FOUND" / «ЗНАЙДЕНІ ЗАПИСИ», empty state "No notes found yet." / «Ви ще не знайшли записів.». It is filled from `JournalRecords.stories()`: the titles are in the order found (`player_state.journal.stories`), and the detail shows the title and the full text, with no state, portrait or objectives. **Layout:** Q87 asked for "the CHARACTERS list + detail layout of 192:1754", but since D624 Characters is a one-person card with no list. So Notes uses the same list + text columns Characters had before D624, which Bestiary still uses (the same rows, `ListRow`, `UITokens`, no new tokens). The card cannot show "titles in the order found". **Input:** Q/E and LB/RB cycle the four tabs (E after Notes wraps to Quests); ↑/↓ and the D-pad move through the titles and change the text; ↑ from the first title goes to the active tab and ↓ comes back (`_link_tab_and_list`). That fixes, for Quests and Bestiary too, the old geometric jump to the nearest tab, which from Notes landed on CHARACTERS. **Reading in the world** is unchanged from D622: E on a StoryNote opens one `misc_popup` modal and records the id once. A second E while the modal is open neither opens another nor records twice, and the note can be read again later. **Test seam:** `JournalRecords.stories_file` (static var, defaults to `STORIES_FILE`) lets the test use a fixture in `user://` with two extra pieces, to check the order of finding without inventing story content. Shots `design/shots/journal_notes_{empty,en,uk}.png`. No Figma frame exists yet (D436 precedent: draw from `192:1754`, Sapega confirms). Test `verify_journal_notes.gd`. |

## Details
- `SampleProject/Scenes/Menus/Game/journal_component.tscn:95`: `NotesTab`.
- `SampleProject/Scripts/Menus/Game/journal_component.gd:28` (section), `:61` (tab), `:125` (filled from `stories()`), `:316` `_link_tab_and_list`.
- `SampleProject/Scripts/Systems/journal_records.gd:82`: `stories_file`.
- `en.po` / `uk.po`: NOTES, Notes, NOTES FOUND, No notes found yet.
- `journal_stories.json` `_comment`, `StoryNote.gd` header, and `design/journal_story_plan.md` (status built) were updated.
- `verify_journal_notes.gd` covers four parts:
  - [1] Four tabs; E, RB, E reach Notes; the empty state shows.
  - [2] Uses the real attic: E opens one modal; a second E opens nothing more and records once; the tab then shows the title and full text.
  - [3] Fixture with two more pieces: the tab lists them in the order found; ↓ / D-pad ↓, clicks, D-pad ↑ to the tab and ↓ back, LB, and wrapping all work.
  - [4] Save → load keeps the same order. It writes only to `user://verify_journal_notes/` and removes it.
- `RESULT: ALL PASS` for `verify_journal_notes`, `verify_journal_sections` and `verify_journal`.
- `capture_journal_notes.gd` takes three shots: empty, en and uk. They match the Bestiary page's look.
- The suite failures, which this branch does not touch (it changes only journal UI, `journal_records.gd` and `.po` strings):
  - `verify_difficulty`: "Brass Collector at level 5: 9 hits kill the hero ([3, 4]), 27 hits kill it ([34, 46])" and the STRENGTH line.
  - `verify_mayor_boss`: "the boss (2600 HP) takes 50 light hits of 53 (D642: about 40)".
  - `verify_lab_boss`: two "balanced build" lines.
  - They look like the boss and difficulty branches' numbers disagreeing after they merged (D668–D673).
