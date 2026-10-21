---
type: plan
status: in-progress
tags: [backlog, dialogue, journal]
---

# NPC quests: recall, hints, side quests — plan

> **Partly built (checked 2026-10-21).** Built: Quest at the old man (slice 2a, D169, `verify_npc_recall.gd`), speech bubbles (slice 3, D178/D263, `UI/Components/speech_bubble.gd`), Blacksmith tasks (D175, `quests.json`, `verify_tasks.gd`). **Not built:** objective hints (slice 1, D159 — no `hint` key in `story.json`), Remind at any NPC (slice 2, D158/D161 — no Remind entry in the NPC menu code), side quests in `story.json` (slice 4, D162).

~~**Nothing implemented.**~~ 2026-10-14 (outdated, see the banner). Asked by Sapega: "ми маємо мати можливість перечитати те,
що нам розповів NPC; якщо він дав квест — скорочений текст квесту".
Decided: **D158** (re-read at the NPC itself), **D159** (objective keeps its short title, gains a
hint sentence from the NPC; Sapega writes the texts). **D161**: the entry is Figma's `Quest`, a list when an NPC has several — main first with a gold
diamond. Bubbles: **Q48**. **D162**: side quests in `story.json`, run by `GameFlow`; `Scripts/Quest/` deleted (closes D56).
Figma: no recall design. `npc-speech-bubble 164:1318` and the box `127:1087` — [[dialogue_audit]].

## What exists today

| Thing | Where | State |
|---|---|---|
| Short objectives per zone (`{flag, text}`) | `Resources/Data/story.json` → `zones[].objectives` | ✅ 7 zones, all authored |
| Live objective in HUD and Journal | `Game.current_objective` (`Scripts/Game.gd:495`), `journal_component.gd:163-168` | ✅ |
| Completed dialogues saved | `FlagsModule` / `SaveSystem` `completed_dialogues` ([[journal_audit]]) | ✅ |
| Dialogue files | `dialogue_quest/*.dqd` — only `say` (107) and `exit` (36) lines, plus `//` comments | ✅ linear, parseable |
| NPC menu | `Scripts/Gameplay/NPCs/NpcBase.gd`, `UI/Components/npc_action_menu.gd` (D155) | ✅ Merchant, Blacksmith |
| Story NPCs (old man, bandit, companions) | inline `StateChangeTrigger` dialogues in maps | ⚠️ not `NpcBase` — no menu to put "Remind" on |
| Any dialogue log / replay | `grep -rn 'dialogue_history\|dialogue_log' Scripts` → 0 hits | ❌ |

## Missing entirely

- A read-only reader of a `.dqd` (speaker + line pairs).
- A "Remind" entry on `NpcBase` and a way to know which dialogues are "this NPC's".
- A presenter that shows lines **without** DialogueQuest: replaying through
  `DialogueManager.start_dialogue()` would re-emit `dialogue_finished`, which room scripts use to
  advance their state machines — a replay must never do that.
- `hint` (and the speaker it came from) on objectives; the Journal line that shows it.

## Decisions required

1. ✅ Where to re-read — **D158**: at the NPC. Known ceiling (accepted): an NPC left behind (the old
   man, the bandit) can't be asked again.
2. ✅ Quest text — **D159**: short title stays (HUD); `hint` sentence under it in the Journal.
3. **Which dialogues belong to an NPC** — recommendation: by speaker. An NPC exports its speaker id
   (e.g. `Торговец`); "Remind" lists completed dialogues where that speaker says a line. No
   hand-written list. Non-blocking.
4. **Q48 — speech bubbles "як в аніме"** — for every dialogue, or only for NPC chatter / replays
   with the box kept for story? Blocks slice 3 only.
5. **Hint texts** — Sapega writes them; until then `hint` is empty and nothing shows. Not a default.

## Slices

### Slice 1 — objective hints (D159)
- `story.json`: optional `hint` and `from` (speaker) on each objective — empty until Sapega fills them.
- `journal_component.gd` + its `ObjectiveLine` template: a second, smaller line under the objective
  when `hint` is set ("Дід: …"). Theme variation from tokens, no overrides.
- `verify_journal.gd`: a hint renders under its objective; no hint → no line.

### ✅ Slice 2a — Quest at the old man (D169), built 2026-10-15
- `Scripts/Systems/dqd_reader.gd` (`DqdReader.lines`), `DialogueManager.replay(path, tail)` — same box and
  keys (`dq_accept`), no DialogueQuest, no `dialogue_started/finished`; `is_dialogue_active()` covers it.
- `Scripts/Gameplay/NPCs/StoryNpc.gd` + `Scenes/Gameplay/Objects/NPCs/grandfather.tscn` (zone only; the scene
  draws the NPC). `Village.tscn` `OldManQuest` at the old man: `village_oldman_complete` → `OldMan_Decision`,
  then "Current objective: …". Shows up the moment the flag is set (`Game.quest_flag_changed`).
- `NpcBase`: E does not open an NPC menu while a dialogue runs.
- Test: `verify_npc_recall.gd`. Not yet: the gold-diamond list (one quest per NPC so far), hints (D159).

### Slice 2 — Remind at the NPC (D158)
- `Scripts/Systems/DqdReader.gd` (static): `lines(path) -> Array[{speaker, text}]`, `say` only.
- `NpcBase`: `@export var speaker_id`; `menu_entries()` adds `Remind` when a completed dialogue has
  that speaker; choosing it shows the lines read-only (slice 3's presenter, or the existing box in a
  read-only mode until then).
- `verify_npc_recall.gd`: Remind hidden before any talk, shown after; replay emits no
  `dialogue_finished` and changes no flag.

### Slice 3 — speech bubbles (after Q48; art per D160)
- **D160:** Figma's bubble shape is rejected; art is hand-drawn PNG. Needed from Sapega:
  `bubble_body.png` — 9-slice, ~96×96, corners inside a 24 px margin, flat fill in the middle;
  `bubble_tail.png` — ~24×24, pointing down, drawn to join the body's bottom edge; flipped in code
  for left/right. Put in `SampleProject/Assets/UI/Dialogue/`. Margins become tokens.
- **D178 (2026-10-15):** temporary bubble PNGs drawn by Claude to this spec (tail 32² instead of 24²);
  `UI/Components/speech_bubble.gd` shows Kusakam's monologues. Swap the PNGs when Sapega's art lands.
- Belongs to the dialogue presentation layer, roadmap **2.1** ([[dialogue_audit]], D110–D114).
  `164:1318`: name SemiBold 12 accent, line Italic 16, tail, close hint. Build it there, then point
  Remind at it.

### Slice 4 — side quests in the story data (D162)
- `story.json`: a `side` stage list (or `side: true` on a stage) — same zone/objective/hint/`from`
  shape. No side quest content exists: the first one is Sapega's to write; the slice ships the
  format with a test fixture only.
- `GameFlow.journal_entries()` returns side entries apart from main; Journal shows them
  (Figma `journal-side-stories 192:1636`).
- `GameFlow.quests_from(speaker_id)` → `[{id, title, main: bool, dialogue}]` — feeds the NPC
  `Quest` list (D161): main first with the gold diamond, then side.
- Delete `Scripts/Quest/` (5 scripts) and the two `get_node_or_null("SceneQuestManager")` lines in
  `Canyon.gd:30`, `Village.gd:36` with whatever reads `quest_manager` there.
- `verify_journal.gd` + `verify_npc_recall.gd` extended.

### First Blacksmith tasks (Sapega, 2026-10-14) — ✅ built 2026-10-15 (D175)
- `quests.json` + `Scripts/Tasks/task_service.gd`, Quest in `NpcBase` (`task_giver`), test `verify_tasks.gd`.
  Still open from slice 4: Journal side entries, the diamond list. `Scripts/Quest/` deleted (D162).
- **Helmet:** craft `iron_helmet` (recipe `craft_iron_helmet`: 2 `iron_ingot` + 1 `leather`, both sold
  by the Desert Road Merchant) and show it. Reward, Sapega's words: "той шолом що ми створили і
  назад золото повертається" — you keep the helmet and get gold back. *Which* gold (the crafting fee,
  or the ingredients too) — ask when this slice starts.
- **Enchant:** he gives two identical items → enchant → bring back the `+1`. Waits on
  [[enchanting_plan]].
- Side quests are **Stoneshard-style Tasks** (one-time, from an NPC, giver + steps + reward), not
  story zones — the `story.json` shape in slice 4 is to be replaced by a `quests.json` of that shape.

### Reported missing in play (Sapega, 2026-10-15)
- No `Quest` entry at the Blacksmith — expected: slice 2 + the Tasks system are not built, and no
  side quest exists yet.
- No `Quest` entry at the old man although he gives the main quest — **D169**: he becomes an
  interactable NPC (after his Village beat) whose `Quest` replays `OldMan_Decision.dqd` read-only
  with the current main objective + hint.

## Order and dependencies

`1` is independent. `4 → 2` (the Quest list needs `quests_from`). `2 → 3`; 2 can ship with a plain
read-only box and switch to bubbles later.

## Out of scope for this pass

- Recall for story NPCs that are not `NpcBase` (old man, bandit) — D158 ceiling.
- Choices / branching in replays — D113 (no choice UI yet).
- A separate "Conversations" tab — not chosen (D158).
