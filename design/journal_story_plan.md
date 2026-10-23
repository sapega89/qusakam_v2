---
type: plan
status: planned
blocked-by: [Q87]
figma: "journal-main-story 192:1529 · journal-character-detail 192:1754 (no frame for story pieces)"
tags: [journal, story, secrets]
---

# Journal: found story pieces (plan)

**Half built.** D583 says every "what's there?" may end in a **piece of story** (a note, a mural, the grandfather's or
the alchemist's papers), and [[world_structure_plan]] says every story piece goes into the Journal. `cloud/world-1`
(D622) built the **data and the record**, not the Journal view:

| Thing | Where | State |
|---|---|---|
| Story texts | `Resources/Data/journal_stories.json` (`id`, `title`, `text`, `draft`), English keys, uk in `uk.po` | ✅ one: `grandfather_notes` `[ЧЕРНЕТКА]` |
| A thing to read in the world | `Objects/StoryNote.tscn` + `Scripts/Gameplay/StoryNote.gd`: a sparkle (D446), "Read", the text in the `misc_popup` modal | ✅ the grandfather's attic (D621) |
| The record | `JournalRecords.find_story / story / stories`, `player_state.journal.stories` (in the save) | ✅ `verify_branches` [4]–[5] |
| **A Journal page that lists them** | `journal_component.gd` has three tabs: QUESTS · CHARACTERS · BESTIARY (D290) | ❌ no tab, no Figma frame |

## Decision required (Q87)
Where do found pieces show in the Journal? Default: a fourth tab **NOTES** (uk «ЗАПИСИ») after BESTIARY, built
from the same list + detail layout as CHARACTERS (`journal-character-detail` `192:1754`): the list shows the titles in
the order found, the detail shows the full text. Alternatives: under CHARACTERS, as the author's page (the grandfather's
notes on his card); or a section at the end of QUESTS. Figma first: the tab needs a frame (D436 precedent: Claude draws
it from the codex frame, Sapega confirms).

## Slice (after Q87)
1. Figma frame for the NOTES tab (from `192:1754`).
2. `journal_component.gd`: the fourth `TabButton`, filled from `JournalRecords.stories()`; LB/RB and the mouse as for
   the other tabs.
3. `verify_journal_sections.gd`: read the notes in the attic → the tab lists "Grandfather's notes" with its text.
