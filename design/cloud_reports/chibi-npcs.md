---
type: cloud-report
branch: cloud/chibi-npcs
date: 2026-10-24
tags: [cloud, art, npcs, companions, laboratory]
---

# Cloud report: chibi-npcs (D677 wiring, B127)

**Summary**
- Done: Malik and the alchemist on `sheet_chibi.png`, the companion guard on `guard/chibi/{enter,strike}`, the three portraits from the new heads; B127: Alisia lies on the operating table while the alchemist injects her, sits up dazed for his line, then is led back.
- Not done: `village_elder.tscn` still shows Malik's **old** sheet (D438 removes that invented elder; it is not Malik). The City Gates guard NPC keeps his adult sheet, but `GATE_GUARD.tres` speaks with the companion guard's portrait, so it is now the chibi head (redrawn with the adult NPCs, D598).
- D-IDs below: D693, D694 (the orchestrator renumbers). B rows fixed: **B127**.
- Tests: `verify_chibi_npcs` (new) ALL PASS, `verify_lab_cells` ALL PASS (+3 B127 rows), `verify_companions` ALL PASS, `verify_dialogue_speaker` ALL PASS.
- Full suite: `SUITE: ALL PASS` (118 verify scripts, including the new one).
- The comfy-sprite skill (`.claude/skills/comfy-sprite/SKILL.md`) is not in this checkout (there is no `.claude/`), so I did not read its Wiring section. I followed the companion layout (D636: 64×64, feet on row 58, offset (-32, -58), scale 1.5) and measured the feet rows myself.

## D-ID text

| ID | Kind | Text |
|---|---|---|
| D693 | TECH | **Chibi Malik, alchemist and guard are wired in** (D677, D645, D647, D650). `lab_malik.tscn` / `lab_alchemist.tscn` show `sheet_chibi.png`: 4×3 / 4×4 cells of 64×64, same frame numbers (idle 0–1, walk 4–7, inject 8, front 8–9 / 12–13), scale 1.5 like the companions, offset (0, -29) / (0, -30) so the feet rows (60 / 61) land on the floor. On screen they are 1.21× / 1.27× Kusakam's height, so they read a little taller than him (D598). `companion_guard.tscn` takes `guard/chibi/enter.png` + `strike.png` (12 + 12, 64×64, scale 1.5, offset (-32, -58) like the other companions). The new thrust holds frames 3–8, so `strike_frame` stays at 6, the middle of the thrust, with the same timing. Portraits are 32×32 crops of the new heads: Malik `Rect2(16, 129, …)` and the alchemist `Rect2(16, 193, …)` from their front rows, the guard `Rect2(13, 1, …)` of `chibi/idle.png`. The old `sheet.png` files and the guard's 128-px `enter/strike.png` are no longer used by the Lab or companion scenes (the elder placeholder still uses Malik's old sheet, D438). |
| D694 | TECH | **Alisia on the operating table** (B127, D304; agent call on the staging). `LabCells.tscn` gives her sprite two one-frame animations from `Companions/alisia/lie.png`: `lie` (frame 0, on her back) and `sit_up` (frame 1, dazed). A new marker, `Marks/TableTop` at (925, 318), sits on the room table's top surface. The beat: she walks to the table → is laid on it (`lie`, held 0.5 s) → the alchemist injects her and she flinches (D460) → she sits up (`sit_up`) for `Lab_Cells_Injection` → she gets down and is led back to her cell. The stone slab drawn in the frames sits on the purple lab table like a stone bed. I kept it rather than cropping it out, because her legs hang over the slab in the sit-up frame. |

## Details

- `SampleProject/Scenes/Gameplay/Objects/NPCs/lab_malik.tscn`, `lab_alchemist.tscn`: texture and offset; hframes/vframes and the animation frame numbers are unchanged (the chibi sheets keep the old layout).
- `SampleProject/Scenes/Characters/Companions/companion_guard.tscn`: 24 atlas regions now 64×64 from `guard/chibi/`, plus the sprite's scale and offset. `guard/chibi/idle.png` feeds only the portrait: no companion scene has an idle animation.
- `SampleProject/Assets/Characters/{NPCs/malik,NPCs/alchemist,Companions/guard}/portrait.tres`: atlas and region. `MALIK.tres`, `SCIENTIST.tres` and `GATE_GUARD.tres` pick them up unchanged.
- `SampleProject/Maps/LabCells.tscn`: ext_resource `alisia_lie`, `AtlasTexture_alisia_lie` / `_sit_up`, the `lie` and `sit_up` animations in Alisia's SpriteFrames, `Marks/TableTop`.
- `SampleProject/Scripts/Gameplay/Scenes/LabCells.gd` `_cells_cutscene()`: the table beat; new `LIE_HOLD := 0.5`.
- Tests:
  - `SampleProject/UI/verify_chibi_npcs.gd` (new) checks each NPC's sheet and grid, that every animated frame's feet are on the floor, the height ratio to Kusakam, the guard's frame counts and atlas paths, that `strike_frame` is the thrust (59 px wide against 35 standing), the guard's feet and scale, the three portraits, the MALIK/SCIENTIST dialogue portraits, and Alisia's lie/sit_up frames.
  - `verify_lab_cells.gd` [1] adds three rows: she lies on `Marks/TableTop` while the alchemist plays `inject`, she sits up there during `Lab_Cells_Injection`, and she ends idle in her cell.
- RESULT lines: `verify_chibi_npcs` ALL PASS · `verify_lab_cells` ALL PASS · `verify_companions` ALL PASS · `verify_dialogue_speaker` ALL PASS.
- Shots (before on top, after below), from `capture_chibi_npcs.gd` (`-- before`, then `-- after`, which stitches them):
  - `design/shots/chibi_npcs/ba_inject.png`: the injection; she now lies on the table, and the alchemist is chibi.
  - `ba_situp.png`: the line; she sits on the table, and the new portrait shows.
  - `ba_malik.png`: Malik next to Kusakam.
  - `ba_guard.png`: the guard entering and on his strike frame.
- Visual triage: the alchemist's inject frame points the syringe down, toward the floor, and he stands at the head end of the table (`ScientistTable`, x 850), not over her arm. This comes from the art and was approved with D677, so nothing is filed.
