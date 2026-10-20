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
Also: painted terrain in all outdoor rooms (D248/D249), the four companions in two views (D243–D245),
companion and gift hints, attack hint on the first fight, the skill bar in the exe.

## Next, in this order

| # | Item | Why here |
|---|---|---|
| 1 | ~~**20** smoother hero animations, lighter jump dust~~ — done (D262) | the base the combat and skill animations stand on |
| 1b | ~~**25** after the meditation: white speech cloud, Kusakam stands up from the disc and stays locked~~ — done (D263) | small, on item 8's code |
| 2 | ~~**4 + 15** souls-lite combat~~ — done (D264–D270) — (combos, staggers, double dash, block/parry, heavy attack, freeze, run outside towns, two-handed + dual-wield) and sheathed weapons with an attack animation per weapon; **D259** interrupts | one system; plan first (plan-missing-system) |
| 3 | **21** an animation per skill | on top of 20 + 4 |
| 3b | **26** audio: world sound, every swing/hit/miss, grunts, voiced bosses, dialogue babble for every character | after combat (4+15) and skill animations (21) give the events; plan first: `design/audio_plan.md` |
| 3a | **15 fix** out of combat the weapon vanishes entirely, not on the back (Sapega 2026-10-21) — sent to the item-21 run |
| 4 | **22** class path and three skill trees (D260; oath in the City: priest / witch / sand dervish NPCs) | plan first: `design/skill_trees_plan.md` |
| 5 | **9–13** Game Menu (+ **B77** double click learns a skill): inventory actions, party of one, equipment slot picker, hints as tutorial windows with an off switch, Journal quests / characters / bestiary | UI batch |
| 6 | **14** blacksmith and merchant buildings + arrival cutscene with a task (also the blacksmith drawn in front of the hero) | |
| 7 | **5** NPC idle activities | generated frames |
| 8 | **23** DesertRoad grows; XP curve lands level 5 at the City (Canyon, Village, CityGates, City stay as they are) | plan first: `design/world_expansion_plan.md` |
| 9 | **16 + 17 + 6 + 23 (Laboratory)** Mayor Hall queue cutscene (D255) → the unbeatable boss → the rewritten Laboratory story split into several screens → the fire-djinn / cloak boss → the end of the demo | one story block |
| 9b | **24** gamepad parity audit: every action and screen on the pad, `verify_gamepad_parity.gd` | after the Game Menu batch the screens are final; earlier items already follow the rule |
| 10 | **7 + 19** foreground parallax in every outdoor room; living world (decor idle animations, drifting clouds) | backdrop layers |

## Open

- Q64 — the prisoner's shout before the fire djinn (default: an incantation in an invented language).
- Q66 — respec rules and class-stage names (defaults in D260).
- Agent-made calls Sapega has not confirmed: D256, D257, D258, D261, D262, D264–D270 (combat values, the "freeze" read as a
  mechanic, no stamina, bindings R-click/R/pad B heavy and Ctrl/middle mouse/pad LB block registered in code); the gate guard's draft line; text speed 24 letters/s and no Skip.
- Known leftovers: cutscenes have no skip and keep the HUD; camera/walk cutscene code is inline in room scripts (pull into
  shared helpers with the next cutscene); 12 `.dqd` files tag the speaker in the text instead of the speaker field; the
  assist guard still uses pack knight art; the old painted gates still show behind the new gatehouse.
- Unpushed: ~34 commits on `feature/backlog` since `main`.
