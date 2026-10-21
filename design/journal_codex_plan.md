---
type: plan
status: done
figma: "journal-main-story 192:1529 · journal-character-detail 192:1754"
tags: [journal, bestiary, feedback-queue]
---

# Journal sections — Quests, Characters, Bestiary — plan

Sapega's play feedback item 13 ([[BACKLOG]], [[play_feedback_queue]]): «choose between Quests and Characters
(people we have met); plus a Bestiary». 2026-10-21. Built in the same pass (D290, agent call, Sapega to confirm).
Figma: `journal-main-story` 192:1529 (header + stepper), `journal-character-detail` 192:1754 (codex page,
portrait 720×820) — [[journal_audit]].

## What existed

| Thing | Where | State |
|---|---|---|
| Quest journal (story stages → zones → objectives, chronicle text) | `Scripts/Menus/Game/journal_component.gd`, `GameFlow.journal_entries()` (D120–D125) | ✅ |
| Generic entry list + detail pane (`set_entries`) | `journal_component.gd` `set_entries()` / `_show_detail()` | ✅ reused for every section |
| Dialogue speakers | `dialogue_quest/characters/*.tres` (DQCharacter: id, name, colour) | ✅ |
| Who spoke a line | `DialogueManager._on_letter_shown()` → `SoundHooks.speaker_from_name()` (D277) | ✅ — the hook "met" uses |
| Enemy kinds | `Resources/Enemies/enemy_stats_{melee,fast,tank}.tres` → `EnemyStats.enemy_type`; art bandit / jackal / scorpion (D229) | ✅ |
| Record of people met / enemies met or killed | — (`grep -ri bestiar SampleProject/Scripts` → 0 hits) | ❌ missing |

## Built

- `player_state.journal = {"people": [ids], "enemies": {kind: kills}}` — saved with the player
  (`PlayerDataModule`), reset by a new game (`PlayerStateManager` defaults).
- `Scripts/Systems/journal_records.gd` (preload helper, like `tutorial_topics.gd`): `meet_person(id)`,
  `meet_enemy(kind)`, `kill_enemy(kind)`, `people()`, `enemies()`; texts from
  `Resources/Data/journal_people.json` and `Resources/Data/bestiary.json`.
- Triggers (mechanisms, not lists): the first letter of a dialogue line records its speaker
  (`DialogueManager._on_letter_shown`); an enemy entering the scene records its kind as met
  (`DefaultEnemy._ready`), its death adds a kill (`entity_died`).
- Journal screen: three `TabButton` tabs **QUESTS · CHARACTERS · BESTIARY** under the title; each fills the
  existing list + detail columns. Characters: DQ display name, role line, text. Bestiary: name, "Defeated: N"
  (or "Not yet defeated"), text. The objective panel shows on Quests only.
- `verify_journal_sections.gd` — tabs by mouse, keys and pad (LB/RB `menu_prev_tab` / `menu_next_tab`),
  a dialogue line records the speaker, an enemy spawn / kill updates the Bestiary, save round-trip, and every
  DialogueQuest character is either in `journal_people.json` or in its `not_listed`.

## Decisions (D290 — agent calls, Sapega to confirm)

1. **Met = spoke a line in the dialogue box** (cloud talk is Kusakam only). Enemies: **met = spawned in the
   room**, killed = died.
2. **Names** are the DialogueQuest display names (the ones the dialogue box shows); role and text are English
   drafts from [[lore]] and the NPCs' jobs — nothing beyond what lore or the game says.
3. **Not listed:** Kusakam himself, bandits and the generic enemy speaker; characters that never speak yet
   (Жрец, Суан, Гном механник, Три темніх жреца — Q51/Q53) until they have a line and an entry.
4. **Bestiary kinds** = the three `EnemyStats.enemy_type`s; names Desert Bandit / Jackal / Giant Scorpion (D229
   art), texts describe how they fight (D208, D215).
5. Figma's portrait (720×820), class/path/talent card and chapter stepper are not built — no portrait art and no
   such data ([[journal_audit]]); the codex page uses the existing detail column.

## Out of scope

Portraits for the codex page; enemy art in the Bestiary; bosses (none built — [[lab_boss_plan]]); side quests
([[npc_recall_plan]]).
