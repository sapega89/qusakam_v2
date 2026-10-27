---
type: plan
status: planned
tags: [dialogue, story, localization, oath]
---

# Dialogue review — every draft line read and signed off, and the oath made interesting

**Nothing reviewed yet.** 2026-10-27. Sapega, on MASTER_PLAN P2 («Прочитати всі `[ЧЕРНЕТКА]` репліки (uk/en), ідеї для
клятви»): «всі діалоги треба винести в окремий план, видали це звідси, запиши в беклог». No Figma design (text work).
Rules for the text itself: the `story-and-dialogue` skill.

## What exists today
| Thing | Where | State |
|---|---|---|
| Draft lines marked `[ЧЕРНЕТКА]` (uk) / `[DRAFT]` (en) | `SampleProject/Resources/Translations/uk.po`, `en.po` — 136 entries on `cloud/integrate-28`, 144 with `cloud/side-stories` (`git grep -c ЧЕРНЕТКА`) | ⚠️ in the game, never read by Sapega |
| Where they come from | NPC chatter, task givers (D740 townsfolk, npc_flow), the oath census, charms, journal hints (S6, `journal-hints`), side-story quotes and outcomes (S8, `side-stories`), the grandfather's key line (D698) | ⚠️ written by routines |
| Tests that pin a draft marker | `verify_npc_chatter`, `verify_npc_flow`, `verify_oath_census`, `verify_charms`, `verify_story_journal`, `verify_side_stories` (one `ЧЕРНЕТКА` grep each) | ✅ — they must follow the marker when a line is signed off |
| A review page pattern | the P1 page for the 112 agent calls (https://claude.ai/artifact/TTw9d4LafTG574jTXRKGkk: verdicts in its db, read back by Claude) | ✅ reuse |
| The oath | a menu choice at one of three keepers (D281); ideas in BACKLOG 27, none decided | ⚠️ works, «треба подумати, як зробити цікавіше» |

## Missing entirely
A list of every draft line with its speaker, place and the moment it plays; a way for Sapega to sign one off or rewrite
it; a pass that applies his verdicts; a design for the oath.

## How it works
1. **The page is generated, not hand-written** (a mechanism, not an inventory): `Scripts/Tools/dialogue_review.py`
   reads `uk.po` / `en.po`, takes every entry marked `[ЧЕРНЕТКА]` / `[DRAFT]`, and finds its speaker and where it plays
   from the msgid and the `.dqd` / JSON that uses it. It writes the page's data; re-running it after new routines adds
   their new drafts and drops the ones already signed off.
2. **The page** (an artifact like P1): grouped by place and by speaker, in story order; each line shows uk and en, who
   says it and when; buttons «Так» (keep as is) / «Переписати» + a field for his version (uk; en follows). Verdicts land
   in the page's db.
3. **Apply** (a cloud routine): «Так» removes the marker in both files; «Переписати» puts his uk line in and writes the
   en to match; the tests that grep a marker are updated; `verify_localization` and the touched tests run.
4. **The oath** (BACKLOG 27): a one-page set of 2–3 concrete options for Sapega (from BACKLOG 27: a trial per keeper —
   a fight, a choice, a sacrifice by Light / Dark / Neutral; a ceremony with a visible change on Kusakam; the keepers
   reacting), each with what it costs to build. His pick becomes a D-ID and its own slices here.

## Decisions required
1. **Who rewrites the en line** when he rewrites the uk one: Claude, from his uk text. Recommendation; not blocking.
2. **The oath** — GAME DESIGN DECISION REQUIRED (Sapega). Blocks slice 4 only.

## Slices
### Slice 1 — the review page (🖥 orchestrator)
- After `integrate-28` and `side-stories` are merged (so every current draft is in). `dialogue_review.py` + the page;
  send Sapega the link.
### Slice 2 — apply his verdicts (☁)
- One routine reads the page's db (the orchestrator exports it to `design/dialogue_review_verdicts.json`), edits both
  `.po` files and the marker tests, runs `verify_localization` + the touched verify_*; own commit.
### Slice 3 — keep it current
- Any routine that writes a new line keeps marking it `[ЧЕРНЕТКА]` / `[DRAFT]` (ROUTINE_RULES already says user text
  goes through keys in both `.po`); the page is regenerated after each integration.
### Slice 4 — the oath design (👤 Sapega → ☁)
- The options page; then the plan for the chosen one.

## Order and dependencies
`1 → 2 → 3`; `4` independent (waits on Sapega).

## Out of scope for this pass
New dialogue content (new NPCs, new quests), voice lines (D-audio), the prologue script (S18, deferred by Sapega).
