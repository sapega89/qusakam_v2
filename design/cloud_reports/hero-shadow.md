---
type: cloud-report
branch: cloud/hero-shadow
date: 2026-10-27
tags: [cloud, art, hero]
---

# Cloud report: hero-shadow: an MK1 blob shadow under the hero

**Summary**
- **Done:** the hero has a soft, dark, stepped pixel ellipse on the floor under him. Standing, it sits on the walk line under his feet. In a jump or fall it stays on the floor below him and shrinks and fades with his height. It is hidden on a ladder and over a pit (no floor within 240 px). Room changes never show it at an old offset.
- Built on `cloud/hero-feet` (the feet sit on the collision bottom, so the shadow sits there too).
- **Proposed D-ID:** «D-new» below. **B rows fixed:** none.
- New check `verify_hero_shadow` (ALL PASS). Shot `design/shots/hero_shadow.png`. Texture tool `Scripts/Tools/draw_hero_shadow.gd`.
- **Changed from the prompt:** alpha is 0.6 on the ground and 0.35 at the top, not 0.45 and 0.15. At 0.15 the half-size blob could not be seen on the DesertRoad stones at game scale. The values are exports on `Player.tscn → Shadow`.
- Full suite once at the end: `SUITE: 3 FAIL`. progression, save_load and save_load_room fail the same way they did on hero-feet and feature/backlog (a save point without `Seat`, `SavePoint.gd:62`). None comes from this change.

## D-new (proposed; Sapega 2026-10-27: «треба якусь тінь кусакаму, може як в MK1: коли стрибає, то на підлозі видно кружечок»)
| D-new | DECISION | **The hero casts an MK1 blob shadow** (Sapega 2026-10-27: «треба якусь тінь кусакаму, може як в MK1: коли стрибає, то на підлозі видно кружечок»). A soft, dark pixel ellipse (26×6, three alpha steps, near-black `#100A10`, ×1.5, nearest) lies on the floor under the hero's body. Standing, it sits on his collision bottom, which is the walk line (the band's middle in road rooms, D559). In the air it stays on the world floor straight below him, found by a downward ray (characters are skipped). It shrinks linearly to half size and fades from 0.6 to 0.35 alpha up to the top of a plain jump (103 px), and stays that way above it. With no floor within 240 px (a pit) or on a ladder it is not drawn. It is drawn behind the hero's drawing and in front of floors and backdrops, at the hero's own z. Only the body counts: the D764 meditation hop moves the drawing, and the shadow stays on the floor. `Player.tscn → Shadow` (`HeroShadow.gd`). `verify_hero_shadow` checks it. Enemies and NPCs: not yet. |

## Changes (file:line)
- `SampleProject/Scripts/Player/Components/HeroShadow.gd` (new, preloaded through the scene, no `class_name`):
  - `:47` `_physics_process`. On the floor, `floor_y` = the feet (`feet_y` 24). In the air it comes from `_floor_below` (`:65`): a ray from the feet down `reach` (240) on the hero's `collision_mask`, excluding him. It skips up to 4 `CharacterBody2D`s (enemies, NPCs, companions). Areas (ladders, triggers) are not hit.
  - `:54` hides the shadow on a ladder (`mover.is_climbing()`), with no floor in reach, or on a body jump of more than 64 px in one physics frame (a teleport).
  - `:58` scale and alpha over `top_height` (103 px = 450² / 2·980).
  - `:41` `reset()` hides it until the next physics frame.
  - It is a Node2D that draws its texture (`:78`), not a Sprite2D: `Cutscene._body` takes the hero's first Sprite2D as his body.
  - The position is local (0, floor − body y), so x follows the hero in cutscene tweens too.
- `SampleProject/Player.tscn:1621`: the `Shadow` node at (0, 24), ×1.5, before `Sprite2D` (drawn behind the hero's drawing, at the hero's z 1, above the room floors and backdrops at z ≤ 0).
- `SampleProject/Scripts/Player.gd:426`: `on_enter()` calls `$Shadow.reset()`, so a room change shows no frame at the old offset.
- `Scripts/Tools/draw_hero_shadow.gd` → `SampleProject/Sprites/Player/Shadow/shadow.png` (26×6; core 1.0, middle 0.8, edge 0.55).
- Tests: `SampleProject/UI/verify_hero_shadow.gd` (new). Capture: `SampleProject/UI/capture_hero_shadow.gd`.

## States
| state | behaviour | how |
|---|---|---|
| standing, run, landing | on the walk line under the feet, full size | `is_on_floor()` → feet y |
| jump, fall, air dash, double jump | on the floor below, smaller and fainter with height | ray |
| roll / dash on the ground | on the floor (the roll's own transparency is on `Sprite2D` only) | body on the floor |
| hurt knock-back | follows the body; if it lifts him, as a jump | same rules |
| ladder | hidden | `mover.is_climbing()` |
| meditation hop (D764) | stays on the floor | only `Sprite2D` / `WeaponMount` move (`set_visual_offset`) |
| cutscene moves (`walk_hero`, `Cutscene._fall_step`) | follows (local x); `_fall_step` lands him with `move_and_slide`, so the ray works | own `_physics_process` runs while `Player.event` is set |
| death / Game Over / respawn | stays under the body; respawn goes through `load_room` → `on_enter` → `reset()` | — |
| room change / teleport | hidden for that frame, then recomputed | `reset()` and the 64 px jump guard |
| pit (no floor within 240 px) | hidden; reappears once the floor is within reach | ray miss |

## Tests (RESULT lines)
- verify_hero_shadow **ALL PASS**. Checks:
  - the node order and nearest filtering;
  - entering DesertRoad and LabBoss mid-jump shows no frame with the old offset;
  - standing in both rooms: under the feet within 0.5 px, ×1.5, ground alpha;
  - a jump in both rooms (107 px): stays on the floor y within 1 px, scale 0.75 (half), alpha at `top_alpha`;
  - 300 px above the DesertRoad road: hidden, appears at 237 px (within `reach`), back on landing;
  - the D764 visual offset −16: the shadow does not move;
  - Laboratory Ladder1: drawn on the bridge, hidden on the ladder.
- verify_combat_flow, verify_souls_combat, verify_ladders, verify_scripts_compile, verify_hero_feet: **ALL PASS**.
- verify_progression **4 FAIL** (`pose: Jump`, `then the save screen opens (NullState)`, `leaving the screen gives him his feet back`, `he stands up (Meditate)`). These are the same lines hero-feet reported as failing on untouched `origin/feature/backlog` (the save point without `Seat`, `SavePoint.gd:62`). Pre-existing, not from this change.
- Full suite (`Scripts/Tools/run_verify.sh`), once, at the end: **`SUITE: 3 FAIL`**. Every other script passes.
  - verify_progression (4): the lines above.
  - verify_save_load (2, plus the SCRIPT ERROR `SavePoint.gd:62 _meditate` on a null `Seat`).
  - verify_save_load_room (2: the save screen does not open (NullState); B82 position).
  - All three are the pre-existing failures the hero-feet report showed on untouched `origin/feature/backlog`. B candidate (already raised by hero-feet): the save point these tests use has no `Seat` marker (D764).

## Shot
`design/shots/hero_shadow.png`, 2×2, each cell 600×560 screen px around the shadow:
- top: DesertRoad (a road room, D559 band); bottom: LabBoss (indoor, flat `Surfaces` top);
- left: standing; right: the top of a jump.

Standing, the blob reads as a dark ellipse around and under the feet. At the top of a jump it is a small, faint smudge on the floor. It is clearer on the light road than on the dark lab floor. There the dark floor plates keep any dark shadow subtle: the indoor shadow is barely visible even standing. If Sapega wants it to read more indoors, raise `ground_alpha` / `top_alpha` on the node, or give indoor rooms a lighter floor.

## Enemies and NPCs
The same node would fit ground enemies and NPCs with two changes:
- `feet_y` set per scene (their collision bottom: 0 relative to the origin for most NPCs, the root `CollisionShape2D` bottom for enemies, see the hero-feet table);
- the ladder check moved out of the script (an export, or the hero sets `visible` himself), because `hero.mover` exists only on the hero.

Flyers (bat, fly, vultures) would get the most out of it: their height above the floor becomes readable. Not done now, as the prompt asked.

## Notes
- One-way bridges: in the air, the ray starts at the feet, so a bridge he is already above catches the shadow, and one he is passing up through does not.
- `reach` 240 is above the double-jump top (~206), so a double jump over flat ground keeps the shadow. A drop deeper than 240 hides it until the floor is in reach.
