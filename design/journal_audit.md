# Journal — backing-data audit

**Audit only. Nothing implemented.**

**Figma:** `journal-main-story` `192:1529`, `journal-side-stories` `192:1636`,
`journal-character-detail` `192:1754`
**Godot:** `Scenes/Menus/Game/journal_component.tscn` (26 lines, empty shell) ·
`Scripts/Menus/Game/journal_component.gd` (**15 lines, two `TODO` stubs, no logic**)

## What Figma actually specifies

The name is misleading: `journal-main-story` is **not a quest list**.

| Frame | Contents |
|---|---|
| `journal-main-story` `192:1529` | Header `QUEST JOURNAL` / `Main Story`; a `◇ All Chapters ◇` stepper top-right; then a **row of four character banners** — `banner-Khalahas`, `banner-Lyra Ashveil`, `banner-Valen`, `banner-Selene`. Each is a 240×650 column: `UI/Banner Graphic` (64×420), `UI/Character Pedestal`, and on Khalahas an `indicator-glow`. |
| `journal-side-stories` `192:1636` | Same layout, different story set. |
| `journal-character-detail` `192:1754` | Two columns inside a gothic border. Left: `class-title`, `character-main-name` (78px), ornate divider, a **stats card** with exactly three rows — `Class`, `Path Action`, `Talent` — another divider, then `backstory-section` with a heading and **three narrative paragraphs** (32 / 128 / 64px tall). Right: a **720×820 portrait**. |

So the Journal is a **story/character codex**, driven by named characters,
their class/talent metadata, prose backstories and full-body portrait art.

## Backing verdict

### ✅ Real

| Thing | Where |
|---|---|
| Character roster with display names | `CharacterManager._get_default_character_data()` — 8 characters (Астрит, Уризен, Кусакам, Три темніх жреца, Гном механник, Алісия, Суан, Торговец) |
| `class_id` / `subclass_id` per character | same dictionary |
| A single free-text current objective | `Game.current_objective` + `Game.objective_updated(text)`, set by `Canyon.gd` (`"Explore the Canyon"`, `"Find a way forward"`, `"Pursue the kidnappers"`, `"Повернутися до села"`). Already consumed by the combat HUD quest panel. |
| Dialogue completion history | `FlagsModule` / `SaveSystem` persist `completed_dialogues` |

### ⚠️ Code exists, but **zero data and zero instances**

`Scripts/Quest/` contains a complete, working quest engine:
`SceneQuestManager` (stages, required dialogues, flag conditions, scene
unlocks, `stage_completed` / `all_stages_completed` / `progress_updated`
signals), `QuestStageResource`, `SceneQuestConfig`, `QuestProgressUI`.

It is, however, entirely inert:

- **No `SceneQuestConfig` or `QuestStageResource` `.tres` exists anywhere in the
  project.** Not one quest, stage or objective has been authored.
- **No scene instantiates a `SceneQuestManager` node.** `Village.gd:31` and
  `Canyon.gd:30` both do `get_node_or_null("SceneQuestManager")`, which returns
  null in every scene — the reference is never satisfied.
- `EventBus` declares **no** quest or objective signals.

So there is a quest *system* but no quest *content*, and nothing is running it.

### ❌ No backing at all

| Figma element | Missing |
|---|---|
| `All Chapters` stepper | No concept of chapters anywhere |
| Story grouping (Main Story vs Side Stories) | No story/category model |
| Banner names — Khalahas, **Lyra Ashveil, Valen, Selene** | **These four do not exist in the project.** The real roster is Астрит, Уризен, Кусакам, … — Figma's names are placeholders from a different naming pass. "Khalahas" is the world name (used as the World Map title), not a character. |
| `UI/Banner Graphic` (64×420) and `UI/Character Pedestal` art | No such assets; the party panel currently renders characters as flat `avatar_color` blocks |
| 720×820 character portraits | No portrait art of any size exists |
| `backstory-section` — three prose paragraphs per character | No backstory, biography or description field on any character |
| Stats card row **`Class`** | `class_id` exists, but `pathfinder_classes.json` is schema-only with **empty display names** (established during the Equipment phase) |
| Stats card row **`Path Action`** | No such concept in the codebase |
| Stats card row **`Talent`** | No talent field on characters; the Skills system uses JP-unlocked skills, and `skills.json` ships empty |
| `indicator-glow` (selected banner) | Presentational only — needs a selection model that does not exist |

## Summary

**Of the Journal's content, essentially none has backing.** The screen needs, at
minimum: a story/chapter model, per-character prose backstories, portrait and
banner art, real class display names, and two invented stat fields
(`Path Action`, `Talent`). Four of the four banner names in Figma are not
project characters.

The one thing that *is* real — the single `current_objective` string — is
already displayed on the combat HUD and is far too thin to justify a
full-screen quest journal.

## Recommendation

Journal is **blocked on content and design decisions**, not on UI work. It is
categorically different from Settings: there the question was which of 19 rows
to show, and 11 were real. Here the honest count is close to zero, so building
the screen now would mean fabricating a story codex — exactly what the standing
rules forbid.

Two coherent ways forward, both requiring a decision before any implementation:

1. **Reduce scope to what exists** — a minimal quest panel driven by
   `SceneQuestManager`, which first requires authoring real
   `SceneQuestConfig`/`QuestStageResource` data *and* actually instancing a
   `SceneQuestManager` in Village and Canyon. This is gameplay-content work, not
   UI work.
2. **Build the codex as designed** — needs a character-codex dataset (story
   grouping, chapter list, backstory prose, class display names, talent/path
   fields) plus banner and portrait art, and Figma updated to the real roster.

## NEEDS DESIGN DECISION (Journal)

| ID | Question |
|---|---|
| **D52** | Is the Journal a **quest log** (driven by `SceneQuestManager`) or a **character codex** (as Figma draws it)? The frames say codex; the name says quest log. |
| **D53** | Figma's banner characters (Khalahas, Lyra Ashveil, Valen, Selene) are not in the project. Update Figma to the real roster, or are these a planned cast replacing it? |
| **D54** | `Path Action` and `Talent` have no counterpart in the codebase. Define them, or cut the rows? |
| **D55** | Backstory prose and 720×820 portraits do not exist. Who authors them, and is the screen blocked until they do? |
| **D56** | The quest engine has no authored data and is never instanced. Is it intended to ship, or is it dead code to be removed? |
| **D57** | Class display names in `pathfinder_classes.json` are still empty (open since the Equipment phase). The Journal's `Class` row cannot render until they are filled. |
