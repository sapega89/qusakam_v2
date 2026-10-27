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
| [[MASTER_PLAN]] | **The plan with statuses** (2026-10-24): everything left, who does it (cloud / local / Sapega), in order |
| [[BACKLOG]] | **What is not built yet**, and what blocks each item |
| [[BUGS]] | **What is built but wrong** — open B-IDs, filed by QA |
| [[questions_for_sapega]] | Open **Q-IDs** — decisions waiting on Sapega, each with a provisional default |
| [[figma_decision_register]] | Approved **D-IDs** — where the runtime intentionally differs from Figma |
| [[test_baseline]] | Failures that are **not yours** — the pre-existing baseline |
| [[skill_icons_brief]] | **What each skill does and how its icon is drawn** — D&D / Pathfinder image, base + effect (D601) |
| [[pillars]] | **The four pillars** and the player fantasy — read before any game-design call (D585) |
| [[lore]] | **The world** as Sapega described it — desert, no sun, dragons, gods; and what is still open |
| [[UI_IMPLEMENTATION_STATUS]] | What **is** built, plus technical debt and Figma frames needing an update |

## Plans

Runnable specs. One per system, sliced so each slice ships on its own.

- [[lab_vertical_plan]] — ✅ D225 slices 1–2 built (ladders, one-way platforms); superseded by [[lab_story_plan]]
- [[settings_plan]] — how every Settings row must behave (change at once, persist, restore); Language: Q55 answered (D194), two languages everywhere = BACKLOG 31 / queue 8g; Controls split D193
- [[companion_assist_plan]] — ✅ built (D213): guard at City Gates, Алісия / Астрит / Уризен; art generated (D243–D245)
- [[character_animation_plan]] — ✅ Q40/Q41 answered (D138/D139); hero frames for every state exist (D262/D264/D271); enemies/NPCs stay (D139)
- [[enchanting_plan]] — D94/D115/D163/D164; slice 1 (rule) built; `+N` lives in the item id
- [[npc_recall_plan]] — D158–D162: NPC `Quest` list (main ◆ gold), hints, side quests on `GameFlow`; bubbles built (D178/D263), Quest at the old man built (D169); Remind (D158) and hints (D159) not built
- [[gamepad_plan]] — D156/D157, ready: hero moves/jumps/attacks on a pad; A/B in every menu; one last-device source
- [[cutscene_plan]] — ✅ built: staged scenes, shared helper, HUD hidden, hold-to-skip (D308); screenplay in [[cutscene_script]]
- [[lab_story_plan]] — BACKLOG 16 + 17 + 6 + 23 (Lab): Mayor Hall queue and boss, the Laboratory split into cells / corridors / boss hall, the djinn and the cloak, the demo end (D300–D310)
- [[lab_boss_plan]] — merged into [[lab_story_plan]]; the two bosses (built, row 9.2, D316): the Brass Collector (D301) and the fire djinn (D302), move sets on a shared `BossEnemy`
- [[prologue_journal_plan]] — D120: the Prologue as a journal stage, zones as sub-stages; fixes B43
- [[game_menu_single_scene_plan]] — ✅ D116/D117: Game Menu as one scene; later work → [[game_menu_batch_mapping]]
- [[runtime_ui_completion_plan]] — slices 0–8, the umbrella pass (1a–5, 8 done; 6–7 audit-only)
- [[ui_implementation_plan]] — the original Figma → Godot pass, and the token import table (§1); superseded by [[runtime_ui_completion_plan]]
- [[skills_system_plan]] — the original survey; superseded by [[skill_trees_plan]] (decisions closed by D279–D285)
- [[skills_combat_plan]] — ✅ the combat vertical slice for skills (Phase 5.5)
- [[skill_trees_plan]] — BACKLOG 22: Holy Warrior trunk + Paladin / Dark Knight / Warden trees, the oath in the City, respec, level cap 99 (D279–D285)
- [[world_expansion_plan]] — BACKLOG 23: DesertRoad 2 → 6 cells, three more fights, ledges with pickups; XP curve in data, level 5 at the City (D296–D299); Laboratory split outlined
- [[journal_codex_plan]] — BACKLOG 13: Journal sections Quests / Characters / Bestiary (D290)
- [[souls_combat_plan]] — BACKLOG 4 + 15: combos, heavy, staggers both ways, block/parry, double dash, grips, sheathing (D264–D270); town walking revoked (D266) — the hero runs everywhere
- [[ranged_plan]] — BACKLOG 40: the hero's bow like Skul (quick shot on the press, hold to charge, arrows fly straight) and the desert archer (keeps distance, red glint, arrows you block / parry / roll), D380–D387
- [[inventory_diff_plan]] — inventory delta
- [[backlog_roadmap]] — superseded by [[play_feedback_queue]] (the order work runs in now)
- [[room_state_plan]] — ✅ built; D152: rooms remember enemies and their HP when the player leaves
- [[no_fallbacks_pass]] — D131: what the no-fallbacks pass removed and what is left
- [[audio_plan]] — BACKLOG 26: buses, event→sound map, world sound, babble, greetings, boss voices (D274–D278)
- [[performance_plan]] — measured 2026-10-23: room-change freezes (script compiling plus a synchronous load), New Game with no loading screen, GPU post-processing and overdraw; slices 1–6 ready, 7 waits on Q83 / Q84
- [[world_structure_plan]] — D458: Tails of Iron-style locations, world map + location map, Desert Road pilot (Q75–Q78)
- [[playable_heroes_plan]] — D498, future: four heroes picked at New Game, co-op like Castle Crashers
- [[enemy_variety_plan]] — D495: size variants, elites, shield-bearers (Q85)
- [[flying_enemies_plan]] — D445: vultures outdoors, bats indoors; art → movement and attack → placement (Q74)
- [[ambient_critters_plan]] — D774: a foreground in every room; bats and birds that fly off when the hero comes near and come back later
- [[dialogue_review_plan]] — every `[ЧЕРНЕТКА]` dialogue line read and signed off by Sapega on a review page; the oath design
- [[depth_critics_plan]] — visual critics judge depth from a film of each room and a probe of every plane, not from stills
- [[music_plan]] — ✅ music plays: a `Music` node in every room and the Main Menu; Q38 answered 2026-10-21 (keep the tracks)

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
- [[combat_critique_2026-10-23]] — the combat against a 2D souls-like bar: the top 10, the hero's action matrix, enemy movement, 10 bugs
- [[decision_audit]] — did the D-IDs become code?
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
