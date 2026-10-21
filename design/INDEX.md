---
type: index
tags: [hub]
---

# Design vault — index

Open `design/` as an Obsidian vault. This note is the hub: every design
document hangs off it, so the graph view is connected from day one.

Conventions: [[#Frontmatter schema]] · [[#Linking rules]]

---

## Start here

| Note | What it answers |
|---|---|
| [[BACKLOG]] | **What is not built yet**, and what blocks each item |
| [[BUGS]] | **What is built but wrong** — open B-IDs, filed by QA |
| [[questions_for_sapega]] | Open **Q-IDs** — decisions waiting on Sapega, each with a provisional default |
| [[figma_decision_register]] | Approved **D-IDs** — where the runtime intentionally differs from Figma |
| [[test_baseline]] | Failures that are **not yours** — the pre-existing baseline |
| [[lore]] | **The world** as Sapega described it — desert, no sun, dragons, gods; and what is still open |
| [[UI_IMPLEMENTATION_STATUS]] | What **is** built, plus technical debt and Figma frames needing an update |

## Plans

Runnable specs. One per system, sliced so each slice ships on its own.

- [[lab_vertical_plan]] — D225: rooms with floors joined by ladders (Tails of Iron), the Laboratory first
- [[settings_plan]] — how every Settings row must behave (change at once, persist, restore); Language blocked on Q55; Controls split D193
- [[companion_assist_plan]] — D201/D209: guard at City Gates, then Алісия / Астрит / Уризен; core needs no art, the rest waits on Ludo
- [[character_animation_plan]] — blocked on Q40/Q41: player frames for every state, per-type enemy art, NPC idles
- [[enchanting_plan]] — D94/D115/D163/D164; slice 1 (rule) built; `+N` lives in the item id
- [[npc_recall_plan]] — D158–D162: NPC `Quest` list (main ◆ gold), hints, side quests on `GameFlow`; bubbles wait on Q48
- [[gamepad_plan]] — D156/D157, ready: hero moves/jumps/attacks on a pad; A/B in every menu; one last-device source
- [[cutscene_plan]] — D140/D176/D177: staged scenes on Tween; screenplay in [[cutscene_script]]
- [[lab_story_plan]] — BACKLOG 16 + 17 + 6 + 23 (Lab): Mayor Hall queue and boss, the Laboratory split into cells / corridors / boss hall, the djinn and the cloak, the demo end (D300–D310)
- [[lab_boss_plan]] — the two bosses: the Brass Collector (D301) and the fire djinn (D302), move sets on a shared `BossEnemy`
- [[prologue_journal_plan]] — D120: the Prologue as a journal stage, zones as sub-stages; fixes B43
- [[game_menu_single_scene_plan]] — D116/D117: Game Menu as one scene, script only shows/hides; row templates in the scene
- [[runtime_ui_completion_plan]] — slices 0–8, the umbrella pass (1a–5, 8 done; 6–7 audit-only)
- [[ui_implementation_plan]] — the original Figma → Godot pass, and the token import table (§1)
- [[skills_system_plan]] — survey + proposal. ⚠️ opens "Nothing implemented"; `SkillManager.gd` now exists — the note predates the build
- [[skills_combat_plan]] — the combat vertical slice for skills
- [[skill_trees_plan]] — BACKLOG 22: Holy Warrior trunk + Paladin / Dark Knight / Warden trees, the oath in the City, respec, level cap 99 (D279–D285)
- [[world_expansion_plan]] — BACKLOG 23: DesertRoad 2 → 6 cells, three more fights, ledges with pickups; XP curve in data, level 5 at the City (D296–D299); Laboratory split outlined
- [[journal_codex_plan]] — BACKLOG 13: Journal sections Quests / Characters / Bestiary (D290)
- [[souls_combat_plan]] — BACKLOG 4 + 15: combos, heavy, staggers both ways, block/parry, double dash, towns walk, grips, sheathing (D264–D270)
- [[inventory_diff_plan]] — inventory delta
- [[backlog_roadmap]] — the order to work through BACKLOG and BUGS: playable to the end first
- [[room_state_plan]] — ✅ built; D152: rooms remember enemies and their HP when the player leaves
- [[audio_plan]] — BACKLOG 26: buses, event→sound map, world sound, babble, greetings, boss voices (D274–D278)
- [[music_plan]] — music: tracks exist in `assets/`, nothing plays them; player + table, content waits on Q38

## Audits

Read-only findings. No decisions made inside them.

- [[scene_inventory]] — **all 121 `.tscn` files** vs what should exist. 46 are unreachable in play; 11 are required and missing
- [[figma_coverage]] — every runtime surface labelled MATCH / PARTIAL / NONE / OUTDATED
- [[figma_inventory]] — what exists on the Figma side
- [[UI_SURFACE_AUDIT]] — every runtime UI surface
- [[ui_visual_qa]] — per-screen visual deviations, source of most D-IDs
- [[dialogue_audit]] — slices 6–7; the D83 decision input
- [[journal_audit]] — D52–D57
- [[ui_theme_scope_audit]] — **why `project.godot` sets no global theme.** Read before changing that
- [[service_locator_audit]]
- [[play_feedback_queue]] — Sapega's play feedback 2026-10-20: the order to run BACKLOG items 1–23, rules, what is open
- [[code_review_2026-10-19]] — the whole game: the B73 room leak, plugins keep / own / remove, maintainability (Q61–Q63)
- [[investigation_pathfinder_classes]]

## Mappings

Figma frame → Godot scene, per screen. The format lives in the
`ui-screen-pipeline` skill.

- [[crafting_mapping]] · [[tutorial_mapping]] · [[combat_hud_mapping]] · [[settings_mapping]] · [[skills_ui_mapping]] · [[world_map_mapping]] · [[game_menu_batch_mapping]]
- [[equipment_data_flow]] · [[ui_navigation_map]]

## Screenshots

`design/shots/` — `*_1920.png` and `*_1280.png` per surface. Not linked here;
reference them from the note that discusses them.

---

## Frontmatter schema

Every note in this vault carries frontmatter. Keep it small and consistent —
it is what makes the vault queryable instead of just linked.

```yaml
---
type: plan | audit | mapping | register | status | index
status: blocked | planned | in-progress | done | reference
blocked-by: [Q11, Q22]        # Q-IDs or D-IDs, omit when nothing blocks
figma: "crafting-list 153:1289"  # frame name + node-id, omit when no design
tags: [backlog]
---
```

`status` on an audit or register is `reference` — they are never "done".

## Linking rules

- Refer to another note as `[[note_name]]`, never as a bare filename. That is
  what builds the graph.
- Name the ID inline: `[[questions_for_sapega]] (Q11)`. Q-IDs and D-IDs live in
  **table rows**, not headings, so `#Q11` anchors do not resolve.
- Every new note gets a link from [[BACKLOG]] or from this index. An unlinked
  note is one nobody finds.
- Converting an old note: add frontmatter and turn its filename mentions into
  `[[links]]` **when you touch it for another reason**. Do not do a mass rewrite.

## Optional — Dataview

If the Dataview plugin is installed, this collects the backlog automatically
instead of by hand. Without the plugin it renders as an inert code block.

```dataview
TABLE status, blocked-by, figma
FROM "design"
WHERE type = "plan" AND status != "done"
SORT status ASC
```
