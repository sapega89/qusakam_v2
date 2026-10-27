---
type: reference
tags: [handoff, orchestrator]
---

# Handoff — 2026-10-27, day

Where the orchestrator session left off (Sapega asked for a fresh session to free the context). The plan with every
status is [[MASTER_PLAN]]; its journal at the bottom says what changed today.

**Registers:** next free **D775**, **B163**. `feature/backlog` has D764, D765, D771–D773; D766–D770 exist only on
`integrate-27` (hard-fights-2's, renumbered) until it is merged back.

## 1. Finish first (local, in this order)

1. **`integrate-27` → the cloud** (Sapega 27.10). Pushed; routine `integrate-27` (`trig_01GjxkDd7Y8XLhKUpJKKo56D`)
   fixes `verify_flying_enemies` (vulture ×1.25 swoop) and `verify_city_gates_raid`, merges `feature/backlog`, runs the
   meditation tests and the full suite, commits the `heavy_battle.mp3.import`, pushes `cloud/integrate-27`. When its
   report lands: fast-forward (or merge) `feature/backlog` to it (stash `project.godot` around it).
2. **Show Sapega the meditation spot in the game** (D764; its tests run in `integrate-27`): after the merge,
   `capture_meditation_spots.gd` (window, `-- <out_dir>`); the hero hops onto the `Seat` marker on the stone.
3. **Art day** (Sapega 27.10: «за сьогодні згенеруємо все, що треба з плану»; no cloud GPU — «дорого»): one ComfyUI
   agent at a time — B162 ✅ (`cccb333c`) → the bird + hero Death frames → Mayor Hall / Bandit Camp foreground + charm icons → plane
   cuts like B162 for Bandit Camp, Gatehouse Cellar, Dragon Mural, Mesa Climb (depth-film's B rows; file them with the
   depth-critics triage after integrate-28) → M6.
4. **Rebuild** `build/windows/Qusakam.exe` and tell Sapega (SendUserFile caps at 30 MiB; he runs it from that path).

## 2. In the cloud (merge each when its report lands; renumber D from D775)

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
| ambient-critters | `trig_01Vvg7wKJZhBCgGk9zvAbMHN` | — | D774 slice 1: bats in the Lizard Cave fly off and come back later |
| depth-film | `trig_011DaLyWuBRKkSJKpe51aWDe` | — | A22: film every room with real input + per-plane probe, packs in `design/shots/depth/` |
| integrate-27 | `trig_01GjxkDd7Y8XLhKUpJKKo56D` | — | finish `integrate-27` (see §1.1) |
| integrate-28 | `trig_01EYt8kXZd2aYYa2Gy1xowCP` | integrate-27 | merges the 11 reported routines (enemy-ai … ambient-critters, not side-stories / depth-*), renumbers from D775 / B163, full suite; then fast-forward `feature/backlog` |
| hero-feet | `trig_01CnwNk3itjwafHhA8cxFXpo` | — | Sapega 27.10: «підняти спрайт, щоб ноги стояли точно на підлозі» (the hero is drawn 11–12 px below his collision, depth-film's Q) — file its D-ID **after** integrate-28 (it numbers from D775) |
| depth-critics | `trig_01SZJkm6bj2ys1JevyvFs1UY` | depth-film | A22: three critics (art director, motion, player) → `depth_critique_2026-10-27.md`; send Sapega the mp4s from the PC |

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
