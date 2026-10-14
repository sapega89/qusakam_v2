---
type: plan
status: done
tags: [backlog, journal, story]
---

# Prologue in the Journal — plan

**Not implemented.** The prologue runs as a story, but nothing turns it into journal
entries. 2026-10-12. Decided by Sapega: **D120** ([[figma_decision_register]] §9).
Figma: no design for a stage/sub-stage journal. `journal-main-story 192:1529` is a
character codex (see [[journal_audit]]); D52 already made the Journal a quest log.

> **Layout reworked 2026-10-12 (D124, D125).** Left: `PROLOGUE` + sub-stage items +
> their objectives as sub-items (done ones stay, ✓). Right: only the item's chronicle.
> `story.json` zones now carry `objectives[{flag,text}]`; `done_flag` is gone. Shot:
> `shots/journal_prologue_1920.png`. The tree below is history.
>
> **Chronicle added 2026-10-12 (D122).** Done and current sub-stages show what
> already happened, one line per story step with its flag set; detail column scrolls.
>
> **Slice 2 done 2026-10-12.** The Journal pulls `GameFlow.journal_entries()` each
> time the tab is shown (and on `objective_updated`); sub-stages render from a
> `ZoneRow` template in `journal_component.tscn` (D117) with theme variations
> `JournalZoneDone/Current/Locked`; the live objective sits under the current one.
> Entry rows and objective lines moved to scene templates too (no `Button.new()` /
> `Label.new()` left). `verify_journal.gd` updated to D120, shot:
> `shots/journal_prologue_1920.png` (Canyon I ✓, Village ✓, Canyon II current).
>
> **Slice 1 done 2026-10-12.** `Resources/Data/story.json`, `GameFlow.journal_entries()`
> / `sync_story_state()`, B43 fixed, `verify_story_journal.gd` 21/21 (mutation-checked:
> a wrong `done_flag` fails 4 checks). Sub-stages are **7**, not 6 — the canyon is
> visited twice (Canyon I / Canyon II). Q36 and Q37 answered as **D121** (English).

## The model (D120)

**Stage = Prologue. Sub-stages = the zones**, like Dragon Nest's main quest
chapters. One stage today; the structure must take more stages later (main game).

```
Пролог                         ← stage
  ✓ Canyon I                   ← sub-stage = zone, done
  ✓ Village
  ✓ Canyon II                  ← the return to the canyon (relic, exit)
  ● Desert Road                ← current, shows the live objective
      Дійти до воріт міста
  ○ City Gates                 ← not reached
  ○ Laboratory
  ○ Laboratory — outside
```

## What exists today

| Thing | Where | State |
|---|---|---|
| Six prologue zones, in order | `Scripts/Managers/Story/GameFlow.gd:8-16` `StoryState` (CANYON … LAB_OUTSIDE, DEMO_END) | ✅ declared |
| Story progress | `GameFlow.current_state` | ❌ **never moves** — the only `advance_story()` call, `LaboratoryOutside.gd:122`, sits behind `Engine.get_singleton("ServiceLocator")`, which is always null in Godot 4 ([[BUGS]] B43). Not saved by any `SaveModule`. |
| Per-zone progress | quest flags, `Game.get_quest_flag()` / `set_quest_flag()`, persisted by `Scripts/Systems/Save/Modules/FlagsModule.gd` | ✅ works and is saved |
| Last flag of each zone | `canyon_exit_complete` (Canyon.gd) · `village_left_complete` (Village.gd) · `desert_road_fight_complete` (DesertRoad.gd:122) · `city_gates_after_fight_complete` (CityGates.gd:124) · `lab_after_boss_complete` (Laboratory.gd:159) · `lab_outside_complete` (LaboratoryOutside.gd:105) | ✅ set by the zone scripts — **verify each is truly the zone's last step** in slice 1 |
| Current objective | `Game.set_objective()` / `objective_updated`, `Game.gd:663-670`; ~45 calls across the six zone scripts | ✅ works; overwritten each time, no history |
| Journal data API | `journal_component.gd:78` `set_entries([{id,title,state,objectives,description}])` | ✅ built and tested (`verify_journal.gd`), **no production caller** — hence "No journal entries yet." |
| Journal current-objective panel | `journal_component.gd:55` subscribes to `objective_updated` | ✅ works |
| Quest engine | `Scripts/Quest/SceneQuestManager` + resources | ⚠️ complete code, zero data, never instanced (D56 open). **Not used by this plan.** |

## Missing entirely

- A **stage/sub-stage data file**: which zones belong to the Prologue, their display
  titles and done-flags. Checked: no `Resources/Data/*.json` mentions zones or
  stages; `GameFlow` has only the enum.
- **Something that builds journal entries** from that file + quest flags + current
  objective, and hands them to `set_entries()`.
- **Sub-stage state in the Journal UI**: `objectives` are plain strings drawn as
  `◇ text` (`journal_component.gd:186`); there is no done / current / locked state.

## Decisions required

1. **Zone display titles** — `StoryState` names are code identifiers. **Q36**,
   non-blocking. Default: English titles derived 1:1 from the scene names
   ("Canyon", "Village", "Desert Road", "City Gates", "Laboratory", "Laboratory —
   Outside"), per `docs/CLAUDE.md` "User-facing: English".
2. **Objective language** — objectives mix English ("Explore the Canyon") and
   Ukrainian ("Дослідити село"). **Q37**, non-blocking. Default: leave the texts as
   authored; the journal shows whatever `set_objective()` received.
3. **Stage description** — none exists. Default: empty (the journal hides an empty
   description). No invented prose.
4. **D56** (ship or delete the quest engine) stays open; this plan works without it.

## Slices

### Slice 1 — data + entry builder (no UI change)
- `Resources/Data/story.json`: `{"stages":[{"id":"prologue","title":"Prologue",
  "zones":[{"id":"canyon","title":"Canyon","done_flag":"canyon_exit_complete"}, …]}]}`
  — six zones in `StoryState` order, titles per Q36 default.
- `GameFlow.gd`: `journal_entries() -> Array` — reads `story.json`, marks each zone
  done / current (first not-done) / locked from quest flags, puts
  `Game.current_objective` under the current zone. Fold B43 here: derive
  `current_state` from the same flags instead of the dead `advance_story()` call.
- `SampleProject/UI/verify_story_journal.gd`: no flags → Canyon current; set
  `village_left_complete`+`canyon_exit_complete` → Desert Road current with the live
  objective; all six flags → stage complete.
- Commit.

### Slice 2 — Journal shows the Prologue
- `journal_component.gd`: on `NOTIFICATION_VISIBILITY_CHANGED`, pull
  `GameFlow.journal_entries()` (pull, not push — the journal already refreshes on
  show) and pass to `set_entries()`; refresh on `objective_updated` and on quest-flag
  change.
- Sub-stage rows get a state: a row template in `journal_component.tscn`
  (D117), duplicated per zone; states as theme variations (done / current / locked),
  colours from `UITokens` — no Figma frame, so screenshot it for Sapega before
  calling it done.
- Extend `verify_journal.gd`; capture `design/shots/journal_prologue_1920.png`.
- Commit.

## Order and dependencies

`1 → 2`. Slice 1 is useful alone (and fixes B43). Q36/Q37 can be answered at any
time; only titles/texts change.

## Out of scope for this pass

Side stories and the codex frames (D52/D53), character backstories (D55), chapter
stepper (`All Chapters` — no chapter model beyond this stage list), the quest engine
(D56), the demo end screen (`GameFlow._show_demo_end_screen()` is a stub —
[[figma_coverage]] §1).
