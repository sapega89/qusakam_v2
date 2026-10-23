---
type: report
tags: [cloud, text, world, loose-ends]
---

# cloud/loose-ends — round 11's "not done" lines

- **Done:** the City Gates guard says his D571 chatter (`GateGuard.gd` on `gate_guard.tscn`, left guard only, after the gate fight). `GameFlow.location_title` reads `LocationDB` (D618): the save card shows "Canyon of Whispers" / «Каньйон Шепотів», "The City" / «Місто», "The Laboratory" / «Лабораторія». The skills-v2 capture runs again (a fresh shot).
- **Not done:** the City market folk (no City NPC fits; waiting for art). The HUD shows no location name: it has no such element and HUD v2's Figma has none (Q below). Everything else left in round 11 needs art or a decision (table in §3).
- **D-ID text:** **D675** (gate guard chatter), **D676** (save card location from LocationDB). Proposed **Q89** (HUD location name) and **Q90** (the priest's sky line vs D587). Next free numbers at the time of writing; the orchestrator renumbers.
- **B rows fixed:** none.
- **Full suite (one run):** SUITE_LINE

## D-ID text (orchestrator to apply)

| ID | Type | Decision |
|---|---|---|
| D675 | ROUTINE CALL | **The City Gates guard chatters** (`cloud/loose-ends`, applies D571 / D607's gap). `gate_guard.tscn` stays a `Node2D` with its sprite and `NpcActivity`, and is not an `NpcBase`, so there is no interact prompt and no empty NPC menu. Its new script `Scripts/Gameplay/NPCs/GateGuard.gd` gives it NpcBase's chatter route: a `ChatterZone` (Area2D, 160×120 around the sprite). When the hero walks in, `DialogueManager.say_in_passing(self, chatter_dialogue, chatter_anchor())` runs, once per room visit, and `chatter_anchor()` is the same point NpcBase uses. `chatter_with_flag` keeps him quiet until a flag is set. In `CityGates.tscn` only **GuardLeft** (x 1200, the first the hero reaches) has `CityGates_Guard_Chatter.dqd`, with `chatter_with_flag = city_gates_after_fight_complete`. He does not talk over the raid, the fight or the talk after it. One guard and not both: two clouds 70 px apart would repeat the same three lines. **GuardRight** and the two City guards have no lines. In the City, the Mayor Hall guard still speaks through `City.gd` (`GUARD_LINE`). The two CityGates guards used to face left through a mirrored root (`scale = (-1, 1)`). That would also mirror the cloud's text, so they now face left through `Sprite2D.flip_h`, as the City's guards do. Their look and placement are unchanged. Test: `verify_npc_chatter` [9]. |
| D676 | ROUTINE CALL | **The save card's location is the LocationDB location** (`cloud/loose-ends`, D618 slice 1's last line; replaces D133). `GameFlow.location_title(room)` returns `LocationDB.location(LocationDB.of_scene(room)).name`, the English key. The card's Label translates the key when it draws, so the name follows a language change: Canyon, Village, ElderHouse and DesertRoad give "Canyon of Whispers" «Каньйон Шепотів»; CityGates, City and MayorHall give "The City" «Місто»; LaboratoryOutside, Laboratory, LabCells and LabBoss give "The Laboratory" «Лабораторія». The journal-zone lookup and the `scene.capitalize()` fallback ("Mayor Hall") are gone. A room outside every location is a data error (LocationDB asserts). Old saves keep the string they stored ("Desert Road", "Village"…), and it still translates. `current_zone_title()` (the Quest list's main-quest label, D188) still reads journal zones. Test: `verify_locations` [5]. |

## Proposed Q-IDs (non-blocking)

- **Q89: does the HUD show the location name?** The task asked for the save card and the HUD. Today's HUD (D630–D634) has no location element, and the HUD v2 Figma frame has none either. Default: no HUD element. The name appears on the save card and, later, on the world map (world_structure_plan slice 2). Another option is a short title card when the hero enters a new location (fades in and out, like D434's transition), which needs a Figma frame.
- **Q90: the priest's "The Sky shines on all alike"** (`City_Oath_Priest_Talk.dqd` line 2, flagged by `cloud/text-1`). It praises the sky, which D587 makes a curse. The whole oath of Light is "swear to the Sky" (line 3, D281), so rewriting one line would leave the oath itself in conflict. Needs Sapega's call on what the Paladin swears to. Not changed.

## 1. Gate guard (text-1)

- `SampleProject/Scripts/Gameplay/NPCs/GateGuard.gd` (new, with its `.uid`): `chatter_dialogue`, `chatter_with_flag`, `_chatted`, `chatter_anchor()`.
- `SampleProject/Scenes/Gameplay/Objects/NPCs/gate_guard.tscn`: root script and `ChatterZone` (`monitorable = false`, at the sprite's centre, y −44).
- `SampleProject/Maps/CityGates.tscn`: GuardLeft gets the lines and the flag; both guards lose `scale = (-1, 1)` and get `Sprite2D.flip_h = true`.
- `dialogue_quest/CityGates_Guard_Chatter.dqd` and `en/`: the header no longer says "not wired".
- `verify_npc_chatter.gd` [9]: the map wiring (left has the lines, right has none), no mirrored root, both still face left; no cloud before the flag, a cloud with the first draft line after it, once per room, and a guard without lines stays quiet. `RESULT: ALL PASS`. `verify_progression` (the City's Mayor Hall guard): `RESULT: ALL PASS`.

**Market folk:** the City's NPCs are the caravan merchant, the smith, the three oath keepers and two guards. The only seller is the caravan merchant, but he already met Kusakam on the Desert Road ("A lizard from the edge of the world?"), so "A lizard at the market?" would contradict him, and his speaker is `MERCHANT`, not `MARKET_TRADER`. So `City_Market_Chatter.dqd` (speaker `MARKET_TRADER` «Крамар», voice "villager") **waits for a market NPC: a sprite and a scene, which need art**. No sprite was invented. `verify_npc_chatter` keeps it in `UNWIRED`.

## 2. Save card location (world-1)

- `SampleProject/Scripts/Managers/Story/GameFlow.gd`: `location_title` reads `LocationDB` (preloaded).
- `SampleProject/Scripts/Game.gd:295`: comment only.
- `verify_locations.gd` [5]: every room scene on the save card gives its location's name, MayorHall gives "The City" (not "Mayor Hall"), and a `save_slot_card.tscn` shows «Місто» in uk and "The City" in en. `RESULT: ALL PASS`. `verify_save_load`: `RESULT: ALL PASS`.

## 3. Other round 11 "not done" lines

| Report | Item | Here |
|---|---|---|
| skills-v2 | `capture_skill_trees.gd` stops on "Moving and Jumping" | **Does not reproduce** on today's `feature/backlog`: the capture ran to the end (7 shots). Fresh shot: `design/shots/skills_v2_paladin.png` (the 19-skill trees, 8 px → 4 px tiers). |
| skills-v2 | no button runs the paid respec | Left: it belongs on the skills screen that D674 redraws (D629 default). |
| world-1 | world-map position per location (slice 2) | Left: needs the slice 2 Figma frame; no values invented. |
| world-1 | Journal tab for story pieces (D622) | Left: **Q87**. |
| combat-polish | knockback scaling | Left: the hero's blows already push by kind (`PlayerCombat`: weapon profile, finisher 40, heavy 70, charged arrow). A scale for the riposte or the hits the hero takes would need new numbers, which is a combat call. |
| combat-polish | "killed by" on the death screen | Left: D581 calls it a provisional idea for Sapega. |
| enemy-variety | elite name plate, signature moves, guaranteed drop, guard bar, scorpion armour | Left: design calls. |
| enemy-variety | shield-bearer art | Left: art. |
| hud-v2 | painted skill icons (D550) | Left: art. |
| hud-v2 | the 8-button "Put on the hotbar" grid has no Figma frame | Left: Figma first (D674 redraws the screen). |
| ui-moments | painted character illustrations (D486) | Left: art. |
| perf-gfx | pixel diff not 0; nothing measured on the HD 3000 | Left: D608 explains why 0 is not reachable; the hardware is not here. |
| text-1 | the priest's sky line | Left: **Q90** above. |

## Full suite

SUITE_DETAIL
