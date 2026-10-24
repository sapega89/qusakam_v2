---
type: reference
tags: [handoff, orchestrator]
---

# Handoff — 2026-10-24 morning

Where the orchestrator session left off, for the next session to pick up. Registers: next free **D693**, **B147**.

## Running in the cloud (round 13, fired 07:53 UTC)
| Routine | Branch | Task |
|---|---|---|
| rooms-1 (`trig_016osGBbqVCbe12sbHYKGvBh`) | cloud/rooms-1 | the five D643 side rooms with their backdrops |
| chibi-npcs (`trig_01TiXvBBfPWYrkrRUKcj7rEw`) | cloud/chibi-npcs | Malik, alchemist, guard on chibi sheets (D677); Alisia on the table (B127) |
| lab-curse (`trig_01JVxvY38yqsVZYsaVxNZ1sA`) | cloud/lab-curse | cursed jackals in the Laboratory (D649, D653, D675) |

Merge them like round 12: create an `integrator` routine (copy `trig_01KDVwmbR1H9KZ6Pz47ovPrz`'s prompt, change the branch list), then build Windows locally and send it.

## Art lane (ComfyUI, local)
- Waiting for Sapega's pick: the new **bandit brute** (drags the club) and **tower-shield guard** (shield in front) candidates, and **jackal_pack** candidates (not generated yet).
- Then full frames: `big_jackal_leader`, `big_armoured_scorpion`, `big_crossbowman` (a bow), `big_old_vulture` have picks and rows (D692) but **no frames yet** — run `comfy_sprite.py <name>` with `COMFY_MAX=4`, a `/free` between runs.
- Memory: background ComfyUI jobs get reaped when the session idles. Run in the foreground in chunks (`timeout 580`), or restart after a reap without asking (memory note). 96-px cells need `up=12`.
- Still to draw: B124 sword in the wrong hand, B110 the bow; the Lizard Cave backdrop's pseudo-letters.
- After the frames: a cloud routine wires the big kinds (big-mobs left disabled slots, D681–D683).

## Open
- **B145** — the exported game crashed going down from the Canyon; not reproduced; logs now keep 50 files.
- Q89, Q90 (from loose-ends) — read them to Sapega in plain words.
- `main` is 450+ commits behind; update it (PR + fast-forward) on Sapega's word once B145 is understood.
- A second local Claude session also commits here (the Cthulhu fly, D654–D655); its uncommitted `verify_difficulty.gd` edit is in `git stash@{0}`.
- Last: secrets in locations. Postponed by Sapega: old art redraw (chibi + three-quarter), the prologue script, the pixel UI skin and font.
