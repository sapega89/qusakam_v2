---
type: plan
status: active
tags: [feedback, queue, handoff]
---

# Play-feedback queue — how to continue (2026-10-20)

Sapega's play feedback of 2026-10-20 lives as items 1–23 in [[BACKLOG]] → "Sapega's play feedback 2026-10-20".
This note is the handoff: the order to run them in, the rules, what is open. Decisions: [[figma_decision_register]]
D250–D261. Questions: [[questions_for_sapega]] Q64, Q66.

## Rules Sapega set

- **One godot-dev agent at a time**, background, in the order below; no questions to Sapega — record the calls as
  D-IDs for him to confirm (Sapega «все роби як тобі заманеться»). Three parallel agents + ComfyUI froze the PC.
- When an agent reports: send Sapega its capture sheet, then launch the next item.
- ComfyUI on 127.0.0.1:8000 (Desktop, v0.42, base dir `D:\workflows\comfyUiWorkflow`). Page file on D: is 50 GB now
  (the freeze cause). Generations in the foreground, ≤4 images per run, models freed after.
- Never stage `SampleProject/MainMenu.tscn`, `SampleProject/UI/Themes/GameUITheme.tres`, `SampleProject/UI/playthrough.gd`,
  `project.godot` (Sapega's local edits). Commit on `feature/backlog`; **no push / merge to main without his word**.
- **Gamepad parity (item 24, Sapega: testers will use a gamepad):** every new or changed action gets a joypad binding
  and works with focus navigation only; check it in each item.
- Tests call `current_dialogue_box.finish()` before `accept()` — dialogue text types slowly and is unskippable (D254).
- After visual changes rebuild the exe: `godot --headless --path . --export-release "Windows Desktop" build/windows/Qusakam.exe`
  (data files embedded; templates installed for 4.6.2). Linux build:
  `godot --headless --path . --export-release "Linux" build/linux/Qusakam.x86_64` (preset `Linux` in `export_presets.cfg`).

## Done

1 bugs and look (B74, B75, D254) · 2 Canyon descent cutscene (D256) · 3 healing at level 2 (D252, D261) ·
8 meditation on the summit (D257; the stone is a step, no shadow/fringe) · 18 City Gates sky, gates, raid (D258) ·
20 smoother hero and lighter landing dust (D262) · 25 the talk after the meditation in a white cloud, Kusakam standing and locked (D263) ·
4 + 15 souls-lite combat and sheathed weapons with a swing per weapon type (D264–D270, [[souls_combat_plan]]).
21 a cast animation and effect per skill, interruptible (D271, D272).
26 audio: buses, every combat / world event, ambience, babble, greetings, boss and companion voices (D274–D278, [[audio_plan]] — listening checklist there).
22 class path and three skill trees: Holy Warrior → oath at 5 (Paladin / Dark Knight / Warden of Balance) in the City, respec for coins, cap 99 (D279–D285, [[skill_trees_plan]]).
9–13 Game Menu batch (D286–D290, [[game_menu_batch_mapping]]): inventory rows are used in place (potion heals at once, gear equips,
materials "Cannot Use"); the party column lists only the party; an Equipment slot opens a picker; every hint opens the tutorial
window once (Settings → Game → Tutorial Windows), heavy attack and block/parry topics, button names follow the device; Journal
tabs Quests / Characters / Bestiary.
14 NPCs behind the hero (z 10 + 10 on every NPC scene removed, D291); the Merchant's shop on the road and the Blacksmith's forge,
generated (D292); on arrival they walk out, control taken, a draft talk and a task — "The Stolen Caravan", "The Helmet" (D293, D294);
NPC tasks in the Journal.
5 NPC idle activities (D295): blacksmith hammers (sparks, anvil prop), merchant counts coins, grandfather smokes a pipe,
priestess prays, witch reads, dervish whirls, guards shift and look around; random rests; talk pose turned to the hero
while talking, back to work after (`NpcActivity.gd`, `verify_npc_activity.gd`).
8c the City Gates are a passage the hero walks through: towers and bridge drawn over him, the darker passage wall with open leaves behind, the room change inside it (D314, D315).
8d the gate no longer covers the hero: towers and bridge behind him, he stands inside the arch (D314 amended); B81 the anvil stays at the forge, the smith walks to it (D295).
8b the caravan merchant moves on to the City after the gates fight and trades there (D311); "The Helmet" text rewritten (D312); Lab speakers voiced + in the codex (D313).
9.3 the Mayor Hall: queue, wall burst, the Brass Collector, both outcomes → the Laboratory, no Game Over (D300).
9.4 the Laboratory split into rooms: LabCells → corridors → LabBoss → LaboratoryOutside, generated cells / bars / table / boss hall / gates, Малік, the prisoner and the alchemist (D303).
23 (DesertRoad part, D296–D299): the road is 6 cells — dunes, mesa, broken caravan, approach — with three trigger-zone fights,
three ledge pickups that stay picked, generated landmarks; XP curve and rewards in data, level 5 on the last City Gates kill;
B79 fixed (level and XP were never saved). Laboratory part open (row 9).
4b combat tuning (D264, D265, D261, D268 amended): block takes no damage (guard break by tank / finisher = full hit), heavy ×1.5,
parry window 0.25 s with a red glint on every enemy weapon exactly then and a ground line for lunges, longer wind-up poses,
enemy damage up (melee 14, fast 10, tank 20); potions only by crafting (no drops, none sold, Mayor Hall → silver ingots);
hit feel both ways (hitstop, camera kick, flinch, layered impact, rumble; red edge vignette and HP-row shake when hit);
verify_combat_flow flake fixed (live enemies' in-flight swings), verify_mayor_hall coin flake fixed.
Also: painted terrain in all outdoor rooms (D248/D249), the four companions in two views (D243–D245),
companion and gift hints, attack hint on the first fight, the skill bar in the exe.

## Two lanes (Sapega 2026-10-21: «арти генерувати поступово, а все інше одним скоупом; якщо арти готові — приступає, якщо ні — чекає»)

The PC must not freeze: ComfyUI runs in **one** lane only; at most two Godot-running agents at once.

**Art lane (main tree, ComfyUI)** — generates assets in this order, commits them, no wiring; each batch reports which items it unblocks:

| # | Art batch | Unblocks |
|---|---|---|
| A1 | chest closed / opening / open + Kusakam's raise-the-item pose (edit model) | 33 |
| A2 | buildings: sky chapel, witch's hut, dervish tent, grandfather's house, village-centre house + its interior backdrop (image model) | 29, 38 |
| A3 | Kusakam holding each weapon type — sword/axe, dagger, mace, halberd, dual, bare hands: combat idle, run, jump/fall, combo, heavy, block, hurt (edit model; one weapon type per run) | 42 |
| A4 | bow for the hero (draw, shoot, charged shot), an archer enemy, arrows (edit + image model) | 40 |
| A5 | foreground parallax for Canyon, DesertRoad, CityGates, City, LaboratoryOutside + decor idle frames (banners, palms, lamps) and drifting clouds (image model) | 7, 19 |
| A6 | skill-tree active effects that only reuse recoloured ones today (D279 leftover), effect polish notes (BACKLOG 30) when Sapega gives them | 30 |

**Code lane (git worktree, no ComfyUI)** — takes the next item whose art is ready; an item waiting for art is skipped until its batch lands:

| Order | Item | Needs art |
|---|---|---|
| 1 | 28 onboarding + pictures in tutorial windows (recorded from the game) | — |
| 2 | B82 position on load, B10 the Auto button | — |
| 3 | 43 + 44 Skills screen rework (pending picks + Accept, tree, details, hotbar assign) + 5 attribute points per level | — |
| 4 | 36 speaker name + portrait, 37 objective plaque, the gift / loot modals of 33 | — |
| 5 | 31 two languages (EN/UK), Piper greetings | — |
| 6 | 41 graphics settings + one selection look, 39 cleanup, 35 NPC chatter clouds, 34 lore stubs + Figma lore/flags pages | — |
| 7 | 9.5 → 9.8 the Laboratory to the demo end | already generated (9.4) |
| 8 | 33 chests wired | A1 |
| 9 | 29 + 38 buildings and the village-centre house wired | A2 |
| 10 | 42 hero weapon animations wired (per weapon type as A3 delivers) | A3 |
| 11 | 40 bow and archers | A4 |
| 12 | 7 + 19 foreground parallax, living world | A5 |
| 13 | 24 gamepad audit (last: every screen final) | — |

The orchestrator merges the code lane, runs the full suite, builds Windows + Linux, and owns the registers.
## Next, in this order

**Order from here (2026-10-21, after 8d):** 8h (32 ledges) → 8e (28 onboarding) → 8i (43 + 44 Skills screen + attribute points)
→ 8j (36, 37, 33) → 8k (42 weapon animations) → 8f (29) → 8g (31) → 9.5–9.8 (Laboratory) → 10a (35, 34, 38, 39, 40, 41)
→ 9b (24 gamepad audit) → 10 (7 + 19). Rows 8b, 8c, 8d, 4b and 9.1–9.4 are done (struck below). The table keeps its old
row order; follow this line.

**Stash `refs/wip/row9` (= `stash@{0}`):** of its untracked drafts (`git show --stat 'refs/wip/row9^3'`) only
`Scripts/Gameplay/Scenes/LabCells.gd` and `Scripts/Gameplay/Scenes/LabBoss.gd` (+ `.uid`) are not in the tree yet — rows 9.5 and
9.7 take them. Everything else there (`Cutscene.gd`, skip prompt, `BossEnemy`/`BossLogic`/hazards, boss bar) is already
committed; the tracked part (`MayorHall.gd`, `City_MayorHall.dqd`, `Laboratory_AfterBoss.dqd`) was used by 9.3 — take only
`Laboratory_AfterBoss.dqd` for 9.7 after a diff against the tree.

| # | Item | Why here |
|---|---|---|
| 1 | ~~**20** smoother hero animations, lighter jump dust~~ — done (D262) | the base the combat and skill animations stand on |
| 1b | ~~**25** after the meditation: white speech cloud, Kusakam stands up from the disc and stays locked~~ — done (D263) | small, on item 8's code |
| 2 | ~~**4 + 15** souls-lite combat~~ — done (D264–D270) — (combos, staggers, double dash, block/parry, heavy attack, freeze, run outside towns, two-handed + dual-wield) and sheathed weapons with an attack animation per weapon; **D259** interrupts | one system; plan first (plan-missing-system) |
| 3 | ~~**21** an animation per skill~~ — done (D271, D272) | on top of 20 + 4 |
| 3b | ~~**26** audio: world sound, every swing/hit/miss, grunts, voiced bosses, dialogue babble for every character~~ — done (D274–D278, [[audio_plan]]); left: boss cutscene lines with 16/17, rumble with 24 | |
| 3a | ~~**15 fix** out of combat the weapon vanishes entirely, not on the back (Sapega 2026-10-21)~~ — done (D268 amended) |
| 3a' | ~~**4 fix** swing and hit effects too small — bigger, sharper slash arcs matching the hitbox; on hit a cut streak + small sparks in the hit direction, NO flashes or bursts — hack'n'slash; anime-style effect sprites generated with ComfyUI (D239) for swings, hits and skills (Sapega 2026-10-21)~~ — done (D268 amended, D273: generated anime crescents ×1.3, a cut streak + shards on a hit instead of a burst, no flashes, hitboxes = drawn reach) |
| 4 | ~~**22** class path and three skill trees~~ — done (D279–D285, [[skill_trees_plan]]); left: subclass at 40 / prestige at 70 (outlined), own cast art for the 18 new actives (they reuse the D271 poses with tinted effects), oath keepers drawn over the hero — fixed with item 14 (D291) | |
| 5 | ~~**9–13** Game Menu (+ **B77** double click learns a skill): inventory actions, party of one, equipment slot picker, hints as tutorial windows with an off switch, Journal quests / characters / bestiary~~ — done (D286–D290, [[game_menu_batch_mapping]], [[journal_codex_plan]]); B77 was fixed with item 22 | UI batch |
| 6 | ~~**14** blacksmith and merchant buildings + arrival cutscene with a task (also the blacksmith drawn in front of the hero)~~ — done (D291–D294) | |
| 7 | ~~**5** NPC idle activities~~ — done (D295) | generated frames |
| 8 | ~~**23** DesertRoad grows; XP curve lands level 5 at the City~~ — done (D296–D299, B79, [[world_expansion_plan]]); the Laboratory part goes with row 9 | |
| 9 | **16 + 17 + 6 + 23 (Laboratory)** — split into 9.1–9.8 (Sapega 2026-10-21: too long for one agent). Plan: [[lab_story_plan]] (beats, flags, rooms, slices), bosses [[lab_boss_plan]] (D301/D302), helpers [[cutscene_plan]] (D308). Done: the plan, B79 leftover, boss art (D309), draft `.dqd` lines + speakers. **WIP code is in `git stash` "queue row 9 WIP drafts"** (`refs/wip/row9`) — as of 2026-10-21 only `LabCells.gd` and `LabBoss.gd` (and the `Laboratory_AfterBoss.dqd` cloak line) are left to take; the rest landed with 9.1–9.4 (see *Order from here* above). Each sub-row: one agent, own commits + verify + captures `fb17_*`. | one story block |
| 8b | ~~**City merchant + blacksmith task text** (Sapega 2026-10-21 «треба мерчанта додати в місто і текст квеста кузнеця переписати»): a merchant NPC in the City (shop, idle activity D295, arrival like D294 if it fits; the `[PLACEHOLDER]` City_Merchant trigger) and the blacksmith's task text («The Helmet», D175/D293 — quests.json + its .dqd lines) rewritten: clear goal, his voice, the lore.~~ — done (D311–D313: the road merchant follows his caravan into the City and trades there, the caravan task hands in to him; "The Helmet" has a backstory + a clear goal; babble voices and codex for the five Lab speakers) |
| 8c | ~~**Walking INTO the City Gates** (Sapega 2026-10-21 «треба щоб було враження, що я входжу в браму, а не просто брама»): the gatehouse (D258 `Gates/gen_gate`) must read as a passage the hero walks through — the arch's front pillars/lintel as a foreground layer drawn over the hero, a darker vaulted passage behind him, open gate leaves, light at the far end; the transition to the City happens inside the passage (the City side shows the same gate from within). Generated art (comfy-backdrop), the old painted gates behind the new gatehouse removed (Open leftover).~~ — done (D314, D315: a shared `gate_passage.tscn` — towers + bridge over the hero, the passage wall with open leaves behind him, warm light toward the City; the room edge falls inside the passage, the City shows the same gate from within; painted gates in the wall plane walled up) |
| 4b | ~~Combat tuning after Sapega's review of D264~~ — **done 2026-10-21**, see Done. |
| 8h | **BACKLOG 32 — ledges you can get back onto** (Q2 answer: the three DesertRoad ledges, no double jump). | first after 8d — Sapega hit it in play |
| 8e | ~~**BACKLOG 28 — the game teaches itself, combat first** (playtesters did not understand how to play). Plan first: `design/onboarding_plan.md` (the first 10 minutes step by step), then build the teaching fight and goals. High priority: after 8h. |~~ — done 2026-10-21 (D324–D326, `cloud/onboarding`, integration-1)
| 8i | ~~**BACKLOG 43 + 44 — the Skills screen reworked + attribute points every level** (Sapega confirmed all six Skills-screen problems; five points per level into Strength / Agility / HP / Wisdom, picked pending, spent on Accept). Plan first.~~ — done 2026-10-21 (D330–D336, `cloud/skills-screen`, integration-1) | after 8e |
| 8j | ~~**BACKLOG 36 who is speaking (name + portrait), 37 objective plaque, 33 chests + gift / loot modals** (Q31, Q39, Q2).~~ — **36, 37 and the 33 gift modal + loot feed done 2026-10-21** (D321–D323, `cloud/dialogue-ui`); **33 chests done 2026-10-21** (D339, D340, `cloud/chests`, integration-2) — only the Raise pose is left to wire (B91) | after 8i |
| 8k | **BACKLOG 42 — Kusakam animated holding each weapon.** Plan first. | after 8j |
| 8f | **BACKLOG 29 — buildings for the oath keepers and the grandfather** (D292 pattern). After 8k. |
| 8g | **BACKLOG 31 — two languages everywhere (EN/UK), no Cyrillic in EN, no English in UK except key names; tab names translated; Ukrainian greetings via a licence-clean Piper voice.** Plan first (`design/localization_plan.md`), then slices (UI, data, dialogue, voices, the locale verify). After 8f. |
| 9.1 | ~~**Cutscene helper, HUD hidden, hold-to-skip** ([[lab_story_plan]] slice 1, D308). First step: apply the stash, keep only `Cutscene.gd` + `cutscene_skip_prompt.*`; add `cutscene_skip` (Tab / pad Y) in `CombatInput.gd` and `DialogueManager.skip_line()`; move Canyon meditation/descent, CityGates raid and `NpcArrival` onto it; `verify_cutscene.gd` (real hold of Tab and of pad Y) + `verify_canyon_exit`, `verify_city_gates_raid`, `verify_npc_arrival`/`blacksmith`.~~ — done (D308; B80 found on the way) | the base for every beat below |
| 9.2 | ~~**Bosses core + the two boss scenes** (slice 2, D301/D302). First step: from the stash take `BossEnemy`, `BossLogic`, `Hazards/`, `boss_health_bar.*`; add `DefaultEnemy._make_logic()`, `EnemyLogic.start_knockback(…, time)`, `Player.defeat_handler`; generate the hazard FX with `comfy_fx.py` (fireball, fire pillar + floor mark, slam shockwave, explosion, wall burst, sleep gas, wall hole); scenes `Scenes/Characters/Bosses/brass_collector.tscn`, `fire_djinn.tscn` on the D309 sheets (READMEs list the frame rows); bestiary entries; delete `DemoBoss.gd`; `verify_bosses.gd`.~~ — done (D301, D302, D316; `capture_bosses.gd` → `fb9_2_*`) | needs 9.1 only for nothing — can go first |
| 9.3 | ~~**Mayor Hall** — queue (D255), wall burst, Brass Collector fight, both outcomes → `LabCells` (slice 3, D300). First step: take `MayorHall.gd` + `City_MayorHall.dqd` from the stash; build the hall nodes (Queue spots with the three `CompanionNPC`s, `QueueTrigger`, `WallHole`, `BarrierWest`, `Marks/*`, the boss); voices for the new speakers in `sound_events.json` → `voices`; `verify_mayor_hall.gd` replaces `verify_mayor_hall_teleport.gd` (win: XP + loot; lose: no Game Over). Until 9.4 lands the teleport target can stay `Laboratory`~~ — done (D300; `verify_mayor_hall.gd`, `capture_mayor_hall.gd` → `fb9_3_*`) | after 9.1, 9.2 |
| 9.4 | ~~**The Laboratory split** — `LabCells` `[12..13,3,2]`, corridors (the old `Laboratory`), `LabBoss` `[16..17,5,2]`, `LaboratoryOutside` → `[18..19,5..6,2]` (slice 4, D303). First step: generalise `build_laboratory.gd` to one LAYOUT per room; point `MayorHall.LAB_ROOM` / `LAB_MARKER` at `LabCells` / its arrival marker (now the old `Laboratory` / `SavePoint_Entrance`, D300) and `verify_mayor_hall.gd` `_in_lab` with them, open the corridors' west wall on the top storey; MapData; generate Малік / prisoner / alchemist (`comfy_sprite.py malik|prisoner|alchemist`, defined) and the cells / boss-hall props (comfy-backdrop: bars, operating table, gates); `verify_map_geometry`.~~ — done (D303: `build_laboratory.gd` builds the three rooms from one `ROOMS` table; generated cells, bars, operating table, furnace hall and portcullis; Малік / prisoner / alchemist in two views as `lab_<id>.tscn`; `verify_lab_rooms.gd` walks every door with real input; `capture_lab_rooms.gd` → `fb9_4_*`). Left for 9.5: `LabCells.gd` (the stash) plus the nodes it expects and 9.4 did not place — `ExitDoor` (+ art), `StepOutTrigger`, `Djinn`, `Marks/*`, the three `CompanionNPC_*` in their cells; the bars do not block yet; `story.json` zones for `LabCells`/`LabBoss` (the location title falls back to "Lab Cells" / "Lab Boss"). For 9.7: the `Gates` have no collision. | after 9.2 (scenes), independent of 9.3 |
| 9.5 | ~~**Cells cutscene + wake + acquaintance + Малік + assists** (slices 5–6, D304/D305). First step: take `LabCells.gd` from the stash; task `malik_escort` in `quests.json`; `story.json` laboratory zone objectives per [[lab_story_plan]]; retire `Lab_Companion_0N` / `Lab_LimitTest` / `lab_limit_test_complete`; `verify_lab_cells.gd` (flags-only load → right state, B53).~~ — done 2026-10-21 (D304, D305, `cloud/lab-9-5`, integration-2; new B92) | after 9.1, 9.4 |
| 9.6 | **Mob corridors** — three trigger-zone fights, one per storey (slice 7, D306). First step: rewrite `Laboratory.gd` as a plain room (objective), spawners like `DesertRoad` `Fight_*`; rewrite `verify_laboratory.gd`. | after 9.4 |
| 9.7 | ~~**Boss hall** — talk, arena lock, djinn fight, cloak Game Over / win line, gates (slice 8, D307). First step: take `LabBoss.gd` from the stash; `Laboratory_AfterBoss.dqd` from the stash; `verify_lab_boss.gd`.~~ — done 2026-10-21 (D307, `cloud/lab-9-7`, integration-1) | after 9.2, 9.4 |
| 9.8 | **Demo end + full route + voices + exe** (slices 9–10, D310). First step: `verify_lab_route.gd` Mayor Hall → demo end (both Mayor outcomes, the cloak Game Over, save/reload mid-Lab), boss roars / djinn laugh / incantation via Kokoro (D278 hook), gamepad pass, captures `fb17_*` + sheet, rebuild the exe, mark BACKLOG 6/16/17/23 done. | last |
| 10a | **BACKLOG 35** NPC chatter in clouds, **34** companion lore stubs, **38** Village centre house, **39** cleanup (`Maps/Legacy`, ranged stubs), **40** ranged weapons (plan first), **41** graphics settings + one selection look (Q33) — **35 route (D338, lines Q67), 39 (D337), 41 (D327–D329) done 2026-10-21** (`cloud/settings-cleanup`); 34, 38, 40 left | after 9.8 |
| 9b | **24** gamepad parity audit: every action and screen on the pad, `verify_gamepad_parity.gd` | after the Game Menu batch the screens are final; earlier items already follow the rule |
| 10 | **7 + 19** foreground parallax in every outdoor room; living world (decor idle animations, drifting clouds) | backdrop layers |

## Open
- **Sapega's review 2026-10-21 — confirmed:** D270, D272 (pad layout), D279 (1 point per level), D281 (oath keepers work, names kept), D282 (respec), D289 (tutorial windows), D292 (shop and forge), D295 (NPC activities, enough for now), D297 (XP curve), D300 (no Game Over in the Mayor Hall), D301/D302 (boss names), D308 (skip on Y / Tab), D311 (merchant moves to the City); HP/SP/XP stay Latin in Ukrainian; Q64 answered (the invented incantation).
- **Reviewed, changes queued:** D261 → potions removed (4b); D264 → block no damage, heavy ×1.5, learnable parry, readable scarier enemies, hit feel both ways (4b); D273 → effects polish later (BACKLOG 30); D277 → Ukrainian greetings via Piper (8g); D281 → make the oath more interesting (BACKLOG 27, waits for Sapega's ideas).
- **Still not reviewed (agent calls):** D256–D258, D262, D263, D265, D267–D269, D271, D274–D276, D278, D280, D283–D288, D290, D291, D293, D294, D296, D298, D299, D303, D309 (art), D312, D313, D315, D316; the gate guard's draft line; text speed 24 letters/s with no Skip. Q66 is partly answered (respec D282 ✅) — the oath being permanent (D280) and the subclass/prestige stage names are still defaults.
- **All `[ЧЕРНЕТКА]` dialogue lines** get one review pass with Sapega later.
- Game Menu batch leftovers: saves made before 2026-10-21 lack `seen_tutorials` / `journal` and fail loudly on load (no-fallback rule; the two local dev saves were migrated, backups `*.bak-before-D289`); codex portraits and the Figma class card not built (no art / data); hint topics have no screenshot; the bottom-bar action badges (LB / A / B) are static pad glyphs — item 24 audit.
- Item 14 leftovers: enemies drop only coins — no material loot exists for an "ore from enemies" task (would need a loot plan);
  the arrival cutscene (`NpcArrival.gd`) is reusable for other NPC meetings; ~~the raid/meditation camera code is still inline~~ — on `Cutscene.gd` since row 9.1.
- Known leftovers: ~~cutscenes have no skip and keep the HUD; camera/walk cutscene code is inline in room scripts~~ — done in row 9.1 (D308); the Village abduction still uses its own fade/await chain (not a staged beat, not moved); 12 `.dqd` files tag the speaker in the text instead of the speaker field; the
  assist guard still uses pack knight art; ~~the old painted gates still show behind the new gatehouse~~ — walled up with row 8c (D315).
- Row 9.1 leftovers: ~~**B80**~~ — fixed 2026-10-21: the hero (kinematic `CharacterBody2D`) jumped in the physics server only on the next step, so the new room's `Area2D`s saw him at his old spot (the `RaidTrigger` fired 200 px away). Every room-change placement now goes through `MetSysGame.place_player()` (body moved in the server at once); `verify_cutscene` no longer steps off, regression `verify_city_gates_raid` [7].
- Item 23 leftovers: ~~a New Game in the same session keeps the XP of the last one~~ — fixed 2026-10-21 (B79 note: XP, player state, roster and bag reset at a New Game); the ledge pickups show their icon in a grey frame (the `ItemPickup` look, first ones placed); `verify_combat_flow` [1] failed once and passed on re-run (timing flake).
- `verify_mayor_hall` [6] "coin +60" failed once in row 9.4 (0 → 77: 17 extra coins picked up before the count) and passed in the full suite — a drop-pickup timing flake, not looked into.
- Main fast-forwarded to `7b3a4106` on 2026-10-21 (PR #103); later commits are on `feature/backlog` only.
