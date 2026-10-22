---
type: report
status: done
tags: [cloud, buildings, village, lore]
---

# Cloud report — buildings, the village elder's house, companion lore stubs (cloud/buildings)

Routine of 2026-10-21 ([[routines]]), branch `cloud/buildings` from `feature/backlog` (no `cloud/integration`
existed at start). Items **BACKLOG 29, 38, 34**. Art A2 **had landed** (commit 5f8f8bb8): every generated building and
the interior wall were in the repo, so all three tasks were built; no `buildings_plan.md` was needed.

## What was built

### A. BACKLOG 29 — the trade NPCs' buildings (D292 pattern)
- `SampleProject/Maps/City.tscn:82` `Chapel` (`City/gen_chapel.png`, x 1450), `:89` `WitchHut` (`gen_witch_hut.png`,
  x 1765), `:96` `DervishTent` (`gen_dervish_tent.png`, x 2136) — Sprite2D ×1.5, before `Terrain` in the tree (drawn
  behind the hero, z 0, D291), each doorway's bottom row on y ≈ 400 like the forge. They fill the street from the
  forge to the east edge (1450–2592) with a few pixels of transparent margin overlapping.
- The oath keepers move to stand in front of their doors, like the Blacksmith left of his forge door:
  `City.tscn:167` OathPriest 1500 → **1610**, `:170` OathWitch 1850 → **1915**, `:173` OathDervish 2200 → **2330**.
  Their D295 activities, talk and the oath flow are untouched (still east of the Blacksmith, verify_oath checks the priest is east of the Blacksmith).
- `SampleProject/Maps/Village.tscn:105` `GrandpaHouse` (`Village/gen_grandpa_house.png`, x 1413) behind the
  grandfather (he stays at 1572, left of the door at ~1650).
- READMEs `Assets/Backgrounds/City/README.md`, `Village/README.md` say where each plane is used.

### B. BACKLOG 38 — the village elder's house (Q59), an interior you enter
- **Outside:** `Village.tscn:112` `ElderHouse` (`Village/gen_elder_house.png`, x 2120, the east end of the Village)
  with `:155` `ElderDoor` on its arched door (x 2354).
- **Door:** new `SampleProject/Scripts/Gameplay/RoomDoor.gd` + `Scenes/Gameplay/Objects/room_door.tscn` — an Area2D
  with the shared `InteractableComponent` (D74): the prompt "[E] Enter" / "[Y] Enter" at the door; `interact`
  (E / pad Y) calls `Game.teleport_to_room(target_room, arrival)` — the same call the Mayor Hall uses to send the hero
  to the Laboratory (`MayorHall.gd:147`).
- **Inside:** new MetSys room `SampleProject/Maps/ElderHouse.tscn` (uid `dj0cdy8vnn08q`), `MapData.txt` cell
  **`[6,1,0]`, all four borders walls** (east of the Village's `[5,1]`, so the map shows it at the village's end; no
  edge passage — the house is entered only by its door). One cell 864×480 like the Mayor Hall: the generated
  `ElderHouse/gen_wall.png` (`Wall`, z −10, y −64 so its stone floor meets the floor), the Mayor Hall's tile floor at
  y 384 (`Foreground`, visible — same look as the hall), side walls on a hidden `Walls` layer so the art is not
  covered, `Arrival` + `ExitDoor` ("[E] Leave", back to `Village/ElderDoor`) at x 96, the elder at x 560, the
  Village's music. `sound_events.json:93` `ElderHouse` → `amb_hall`, `stone`, interior.
- **The village elder:** no elder art exists → `Scenes/Gameplay/Objects/NPCs/village_elder.tscn` reuses
  **Малік's front frames** (`malik/sheet.png` frames 8–9) — a robed, turbaned, bearded figure; the grandfather's own
  sheet was not used because he stands outside in the same village. He only stands (no dialogue exists for him;
  none was invented). Swap the sheet when elder art is generated.
- **The Village stays as it is** — its MetSys rows were not touched; the new room is one cell high.

### C. BACKLOG 34 — companion lore stubs
- `design/lore.md:56` new section **Companion stubs [ЗАГЛУШКА]**: `:64` Астрит, `:79` Алісія (spelt Алісия in
  the dialogue and code — noted), `:95` Уризен. Each: who, look, how they fight, the story so far, and the open
  points for the character's creator — only from D209, D243–D245, D255, D300, `journal_people.json` and the
  dialogue (most of it `[ЧЕРНЕТКА]` drafts, marked as such).
- `SampleProject/Resources/Data/journal_people.json:76/:82/:88` — the three entries get `"lore":
  "design/lore.md#<name>"` (the Journal UI ignores the field; `verify_journal_sections` stays green).

### Tests and captures
- New `SampleProject/UI/verify_village_house.gd`: the houses are behind the hero, the grandfather stands in front of
  his house, the door is on the elder's house; the hero **walks** east (held `move_right`) until the prompt shows,
  **E key** → ElderHouse, on the floor at the exit door, camera limits = the room (0..864) and the view inside it, the
  elder inside behind the hero; held right/left for 4 s — both walls hold; walks back to the exit, **pad Y** → the
  Village outside `ElderDoor`, on the floor, camera limits = the Village (0..2592).
- New `SampleProject/UI/capture_buildings.gd` → `design/shots/buildings_{forge_chapel,hut,tent,grandpa_house,
  elder_house,elder_inside}.png` (1920×1080, Xvfb).

## D-IDs to register (agent call, Sapega to confirm)
- **D-new-a (BACKLOG 29):** "**Oath keepers' buildings and the grandfather's house** (BACKLOG 29; agent call, Sapega
  to confirm; D292 pattern): generated planes before the terrain, behind the hero (D291) — City: Sister Ilvane's sky
  chapel x 1450, Morrow's thatched hut x 1765, Kesh's striped tent x 2136, filling the street from the forge to the
  Mayor Hall edge; the keepers stand left of their doors (priest 1500 → 1610, witch 1850 → 1915, dervish 2200 →
  2330), activities (D295) unchanged; Village: the grandfather's house x 1413 behind him (he stays at 1572). No door
  markers or arrival cutscenes for them (D294 is the Merchant's and the Blacksmith's)."
- **D-new-b (BACKLOG 38, Q59):** "**The village elder's house** (BACKLOG 38; agent call, Sapega to confirm): at the
  Village's east end (x 2120); its door `ElderDoor` (x 2354) shows "[E] Enter" and moves the hero into the new MetSys
  room **ElderHouse `[6,1,0]`** (walled on the map, entered only by the door — `RoomDoor`: `InteractableComponent` +
  `Game.teleport_to_room`, the Mayor Hall → Laboratory call); inside: the generated wall, the Mayor Hall's tile floor
  at y 384, "[E] Leave" at the west end back to the door. The elder stands inside with **Малік's front frames
  reused** (no elder art; the grandfather's sheet would put two identical old men in one village) and has no lines.
  The Village keeps its MetSys rows."
- **D-new-c (BACKLOG 34, Q51):** "**Companion lore stubs** (agent call, Sapega to confirm): `lore.md` → *Companion stubs
  [ЗАГЛУШКА]* — Астрит, Алісія, Уризен, each from what the repo already says, with the open points for the creator;
  `journal_people.json` entries carry `lore` → the stub. The Journal UI pages for character lore (Figma) are not built."

## B-ID text (for BUGS.md)
- **B-new (tests):** "`Game.gd:389` `var old_room_instance := MetSys.get_current_room_instance()` cannot infer its type
  when Game.gd is compiled before the autoloads exist (any `--script` verify that names a `class_name` whose script
  references `Game`): Parse Error, 'Failed to compile depended scripts', the test crashes. Hit while writing
  verify_village_house (it named `RoomDoor`); worked around by typing the doors as `Area2D` in the test. Fix: an
  explicit type (`var old_room_instance: Node = …`)."

- **B-new-2 (tests, flaky):** "`verify_audio.gd:276` 'focusing a button (pad navigation) ticks on SFX' fails about one
  run in three on Linux 4.6.2, also on an untouched `feature/backlog` (93ed70f1): it checks
  `ButtonFocusedAudioStreamPlayer.playing` one `process_frame` after `grab_focus()`; the player is not always
  `playing` yet (or already done) on that frame. Fix: wait until `playing` with a short deadline, or count the
  `play()` calls instead of sampling `playing`."

## Calls made without Sapega (to confirm)
- The elder borrows Малік's sprite (see D-new-b). The elder art (two views, D243) is the next art batch's item.
- The room is entered by the **door**, not by walking off the Village's east edge (the Mayor Hall's way): the art
  has a door, and an edge passage would cut the house in half at the room border.
- Gameplay interaction has no mouse binding (`interact` = E / pad Y in `project.godot`), so the door is keyboard and
  gamepad only, like every NPC, save point and the shop. Not changed (`project.godot` is not committed by routines).
- The interior's exit is at the west wall without a painted door (the wall art has none); the prompt shows it.

## Verifies
| Verify | RESULT |
|---|---|
| verify_village_house (new) | RESULT: ALL PASS |
| verify_map_geometry | RESULT: ALL PASS |
| verify_oath | RESULT: ALL PASS |
| verify_npc_activity | RESULT: ALL PASS |
| verify_npc_arrival | RESULT: ALL PASS |
| verify_journal_sections | RESULT: ALL PASS |

**Full suite** (`Scripts/Tools/run_verify.sh`, Linux Godot 4.6.2): **70 verifies, 69 PASS, 1 FAIL — `verify_audio` ("focusing a button (pad navigation) ticks on SFX")**, a pre-existing flake, not this branch: re-run alone on this branch it failed 1 of 2, and on the untouched base (`feature/backlog` 93ed70f1) it failed 1 of 3 too (B-new-2). Every other verify, the new `verify_village_house` included, is ALL PASS.
Baseline before this branch (`feature/backlog` 93ed70f1): 69 / 69 PASS.

## What is left
- **Elder art** (two views) and his lines / role — then swap `village_elder.tscn`'s sheet; maybe an exit door plane
  inside the house.
- **Q58 vs the map:** Q58 is answered "the Village one cell high", but `MapData.txt` still has the Village on
  `[3..5,1..2]` (two rows); BACKLOG 38 says it "stays" one cell high — the reshaping itself is not done (not in this
  routine's items; the house does not depend on it).
- The Journal pages for character lore (Figma, BACKLOG 34's second half).
- Ambient voices/greetings for the elder (D277) once he has lines.
- Register D-new-a/b/c and B-new in the vault (integrator).
