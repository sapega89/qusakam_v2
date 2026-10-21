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
  (data files embedded; templates installed for 4.6.2).

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
23 (DesertRoad part, D296–D299): the road is 6 cells — dunes, mesa, broken caravan, approach — with three trigger-zone fights,
three ledge pickups that stay picked, generated landmarks; XP curve and rewards in data, level 5 on the last City Gates kill;
B79 fixed (level and XP were never saved). Laboratory part open (row 9).
Also: painted terrain in all outdoor rooms (D248/D249), the four companions in two views (D243–D245),
companion and gift hints, attack hint on the first fight, the skill bar in the exe.

## Next, in this order

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
| 9 | **16 + 17 + 6 + 23 (Laboratory)** — split into 9.1–9.8 (Sapega 2026-10-21: too long for one agent). Plan: [[lab_story_plan]] (beats, flags, rooms, slices), bosses [[lab_boss_plan]] (D301/D302), helpers [[cutscene_plan]] (D308). Done: the plan, B79 leftover, boss art (D309), draft `.dqd` lines + speakers. **WIP code is in `git stash` "queue row 9 WIP drafts"** (`git stash list`; apply with `git stash apply stash@{N}` — written, never run: `Cutscene.gd`, skip prompt, `BossEnemy`/`BossLogic`/hazards, boss bar, `MayorHall.gd`/`LabCells.gd`/`LabBoss.gd`, the queue rewrite of `City_MayorHall.dqd` and the cloak line in `Laboratory_AfterBoss.dqd`). Each sub-row: one agent, own commits + verify + captures `fb17_*`. | one story block |
| 8b | **City merchant + blacksmith task text** (Sapega 2026-10-21 «треба мерчанта додати в місто і текст квеста кузнеця переписати»): a merchant NPC in the City (shop, idle activity D295, arrival like D294 if it fits; the `[PLACEHOLDER]` City_Merchant trigger) and the blacksmith's task text («The Helmet», D175/D293 — quests.json + its .dqd lines) rewritten: clear goal, his voice, the lore. Next after 9.1. |
| 9.1 | **Cutscene helper, HUD hidden, hold-to-skip** ([[lab_story_plan]] slice 1, D308). First step: apply the stash, keep only `Cutscene.gd` + `cutscene_skip_prompt.*`; add `cutscene_skip` (Tab / pad Y) in `CombatInput.gd` and `DialogueManager.skip_line()`; move Canyon meditation/descent, CityGates raid and `NpcArrival` onto it; `verify_cutscene.gd` (real hold of Tab and of pad Y) + `verify_canyon_exit`, `verify_city_gates_raid`, `verify_npc_arrival`/`blacksmith`. | the base for every beat below |
| 9.2 | **Bosses core + the two boss scenes** (slice 2, D301/D302). First step: from the stash take `BossEnemy`, `BossLogic`, `Hazards/`, `boss_health_bar.*`; add `DefaultEnemy._make_logic()`, `EnemyLogic.start_knockback(…, time)`, `Player.defeat_handler`; generate the hazard FX with `comfy_fx.py` (fireball, fire pillar + floor mark, slam shockwave, explosion, wall burst, sleep gas, wall hole); scenes `Scenes/Characters/Bosses/brass_collector.tscn`, `fire_djinn.tscn` on the D309 sheets (READMEs list the frame rows); bestiary entries; delete `DemoBoss.gd`; `verify_bosses.gd`. | needs 9.1 only for nothing — can go first |
| 9.3 | **Mayor Hall** — queue (D255), wall burst, Brass Collector fight, both outcomes → `LabCells` (slice 3, D300). First step: take `MayorHall.gd` + `City_MayorHall.dqd` from the stash; build the hall nodes (Queue spots with the three `CompanionNPC`s, `QueueTrigger`, `WallHole`, `BarrierWest`, `Marks/*`, the boss); voices for the new speakers in `sound_events.json` → `voices`; `verify_mayor_hall.gd` replaces `verify_mayor_hall_teleport.gd` (win: XP + loot; lose: no Game Over). Until 9.4 lands the teleport target can stay `Laboratory` | after 9.1, 9.2 |
| 9.4 | **The Laboratory split** — `LabCells` `[12..13,3,2]`, corridors (the old `Laboratory`), `LabBoss` `[16..17,5,2]`, `LaboratoryOutside` → `[18..19,5..6,2]` (slice 4, D303). First step: generalise `build_laboratory.gd` to one LAYOUT per room, open the corridors' west wall on the top storey; MapData; generate Малік / prisoner / alchemist (`comfy_sprite.py malik|prisoner|alchemist`, defined) and the cells / boss-hall props (comfy-backdrop: bars, operating table, gates); `verify_map_geometry`. | after 9.2 (scenes), independent of 9.3 |
| 9.5 | **Cells cutscene + wake + acquaintance + Малік + assists** (slices 5–6, D304/D305). First step: take `LabCells.gd` from the stash; task `malik_escort` in `quests.json`; `story.json` laboratory zone objectives per [[lab_story_plan]]; retire `Lab_Companion_0N` / `Lab_LimitTest` / `lab_limit_test_complete`; `verify_lab_cells.gd` (flags-only load → right state, B53). | after 9.1, 9.4 |
| 9.6 | **Mob corridors** — three trigger-zone fights, one per storey (slice 7, D306). First step: rewrite `Laboratory.gd` as a plain room (objective), spawners like `DesertRoad` `Fight_*`; rewrite `verify_laboratory.gd`. | after 9.4 |
| 9.7 | **Boss hall** — talk, arena lock, djinn fight, cloak Game Over / win line, gates (slice 8, D307). First step: take `LabBoss.gd` from the stash; `Laboratory_AfterBoss.dqd` from the stash; `verify_lab_boss.gd`. | after 9.2, 9.4 |
| 9.8 | **Demo end + full route + voices + exe** (slices 9–10, D310). First step: `verify_lab_route.gd` Mayor Hall → demo end (both Mayor outcomes, the cloak Game Over, save/reload mid-Lab), boss roars / djinn laugh / incantation via Kokoro (D278 hook), gamepad pass, captures `fb17_*` + sheet, rebuild the exe, mark BACKLOG 6/16/17/23 done. | last |
| 9b | **24** gamepad parity audit: every action and screen on the pad, `verify_gamepad_parity.gd` | after the Game Menu batch the screens are final; earlier items already follow the rule |
| 10 | **7 + 19** foreground parallax in every outdoor room; living world (decor idle animations, drifting clouds) | backdrop layers |

## Open

- Q64 — the prisoner's shout before the fire djinn (default: an incantation in an invented language).
- Q66 — respec rules and class-stage names: defaults applied as D280–D282 (oath permanent, respec 10 coins × level, names drafts).
- Agent-made calls Sapega has not confirmed: D296–D299 (the 6-cell road and its sections, XP curve 100 + 50 × (level − 1) and rewards melee 30 / fast 25 / tank 70, the three ledge items, the generated landmarks), D295 (the NPC activities, the anvil standing behind the Blacksmith, the grandfather in his own scene), D291–D294 (NPC z, shop/forge art and the Merchant moved to x 1120, the two tasks and
  their draft `.dqd` lines `Merchant_Arrival`, `Merchant_Caravan_*`, `Smith_Arrival`, the arrival cutscene), D286–D290 (Game Menu batch: potion use without a target choice, party = hero + companions, slot picker, tutorial windows pause the game and are On by default, codex texts / bestiary names are English drafts), D256, D257, D258, D261, D262, D264–D270, D271 (skill wind-ups 0.6/0.35/0.5 s and their looks), D272 (skill slots on pad RT/R3/L3/Back), D273 (generated anime slash/cut/skill effects), D279–D285 (skill trees, the oath and its keepers, respec price, passive stats, level cap; draft `.dqd` lines `City_Oath_*`) (combat values, the "freeze" read as a
  mechanic, no stamina, bindings R-click/R/pad B heavy and Ctrl/middle mouse/pad LB block registered in code); the gate guard's draft line; text speed 24 letters/s and no Skip.
- Game Menu batch leftovers: saves made before 2026-10-21 lack `seen_tutorials` / `journal` and fail loudly on load (no-fallback rule; the two local dev saves were migrated, backups `*.bak-before-D289`); codex portraits and the Figma class card not built (no art / data); hint topics have no screenshot; the bottom-bar action badges (LB / A / B) are static pad glyphs — item 24 audit.
- Item 14 leftovers: enemies drop only coins — no material loot exists for an "ore from enemies" task (would need a loot plan);
  the arrival cutscene (`NpcArrival.gd`) is reusable for other NPC meetings, but the raid/meditation camera code is still inline.
- Known leftovers: cutscenes have no skip and keep the HUD; camera/walk cutscene code is inline in room scripts (pull into
  shared helpers with the next cutscene); 12 `.dqd` files tag the speaker in the text instead of the speaker field; the
  assist guard still uses pack knight art; the old painted gates still show behind the new gatehouse.
- Item 23 leftovers: ~~a New Game in the same session keeps the XP of the last one~~ — fixed 2026-10-21 (B79 note: XP, player state, roster and bag reset at a New Game); the ledge pickups show their icon in a grey frame (the `ItemPickup` look, first ones placed); `verify_combat_flow` [1] failed once and passed on re-run (timing flake).
- Unpushed: ~92 commits on `feature/backlog` since `origin/main`.
