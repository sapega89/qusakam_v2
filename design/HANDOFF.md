---
type: reference
tags: [handoff, orchestrator]
---

# Handoff — 2026-10-27, day

Where the orchestrator session left off (Sapega asked for a fresh session to free the context). The plan with every
status is [[MASTER_PLAN]]; its journal at the bottom says what changed today.

**Registers:** next free **D774**, **B163**. `feature/backlog` has D764, D765, D771–D773; D766–D770 exist only on
`integrate-27` (hard-fights-2's, renumbered) until it is merged back.

## 1. Finish first (local, in this order)

1. **Merge `hard-fights-2`.** It is merged and renumbered on `integrate-27` in the worktree `D:\Projects\ngp-integrate`
   (`65a1e5db`; boss-fix's `BossLogic` kept, hard-fights-2's `MayorHall._fight()` taken, B159 note in BUGS). The full
   suite was running there when the session ended; if `logs/` there is incomplete, run it again (one suite at a time,
   never two). Then `git merge feature/backlog` into `integrate-27` (expect the register's tail and MASTER_PLAN to
   conflict: keep both sides' rows), and fast-forward `feature/backlog` (stash `project.godot` around it).
2. **Check the meditation spot in the game** (D764, committed `5db238da` without a game run):
   `capture_meditation_spots.gd` (window, `-- <out_dir>`), then `verify_progression`, `verify_save_load_room`,
   `verify_city_life`, `verify_laboratory`, `verify_scripts_compile`. The hero hops (`SavePoint._hop`,
   `Player.set_visual_offset`) onto the `Seat` marker on the stone; show Sapega the shots.
3. **Commit the import** of `Resources/Audio/Music/heavy_battle.mp3` (its `.import` was hand-written, Godot adds the uid).
4. **Rebuild** `build/windows/Qusakam.exe` and tell Sapega (SendUserFile caps at 30 MiB; he runs it from that path).

## 2. In the cloud (merge each when its report lands; renumber D from D774)

| Routine | Trigger | Waits for | Task |
|---|---|---|---|
| enemy-ai | `trig_01TcJLwHcQtb8KqkrptmVq7D` | — | enemies try to kill |
| stamina-poise | `trig_018ru9S2zWjNgkwyUjndckNC` | enemy-ai | relaunched 06:13 UTC (the first run waited 8 h and gave up) |
| room-story-flow | `trig_01MEJ6rh44P3wZwpfenyWXsG` | — | S3 |
| plugins-fsm | `trig_01YY9Xmo6EvTU28AYoNEuu6r` | — | S4 slice 1 |
| journal-hints | `trig_0194EUuEt97ps71hVSBof79E` | — | S6, S7 |
| side-stories | `trig_019hyUUSNnQ2yXz7U228Xa95` | journal-hints | S8 (ref `design/refs/figma_192_1636_side_stories.png`) |
| decision-audit-2 | `trig_01GLVCtEb2QatMqx4Wee1Air` | — | S15 (D179–D330), S16 |
| story-dialogue | `trig_01VekVCseD32fdUH9fCsGY5P` | — | S5 (ref `design/refs/figma_36_65_story_dialogue.png`) |
| secrets | `trig_01MATNrpE73ups6FydJzmJq7` | — | D765 |
| secrets-icon | `trig_01Xi3DvX6rxb5i4WM8LyrPLN` | secrets | found secrets on the map |
| map-pan | `trig_01BE9fUzLv58LaCY8TvsAK8W` | secrets-icon | drag / zoom the map like Octopath Traveler |

## 3. Art lane (ComfyUI, local)

- **M6** — [[m6_backdrops]]: all graphs are accepted (M1 D721, M3 D773, M4 D772). Rules from Sapega today: several
  layers per room, something to look at on every screen; interesting things (idols, statues) are their own props on
  their own parallax plane, in the same place.
- **First: B162, the Lizard Cave.** Its one backdrop holds three planes; cut them apart (front = floor, foreground
  rocks, ceiling; middle = walls, tunnel, idol shrines; back = sky, bridge, far canyon), each on a Parallax2D, the front
  floor on the walk line. A first try with Qwen-Image-Edit is in `design/shots/candidates/cave_planes/` (script
  `cave_planes.py`): the back plane came out well; the middle kept the floor and the front kept the shrines — try
  other seeds or prompts, or build the masks from the edits (front = not magenta in the front edit, minus the shrine
  boxes).
- Ladders (memory note): floors join by openings in the floor; ladders only where a place would have one (attic, a
  house wall, a well).

## 4. Waiting on Sapega

S19 shield (rework the 5 shield skills or give the hero a shield), `iron_shield`, the «Holy Warrior» name, the base +
one path tree; Q100 (the god of contracts' name); Q88 (HUD text size); the D-pad left shared by «?» and the new-points
buttons; P1 (112 agent/routine-call D-IDs to confirm) and P2 (60 `[ЧЕРНЕТКА]` lines).
