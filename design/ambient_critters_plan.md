---
type: plan
status: planned
tags: [art, rooms, living-world, M6]
---

# Ambient critters — plan

**Nothing implemented.** 2026-10-27. Sapega, on the Lizard Cave planes: «всюди, в кожній кімнаті, в кожному притулку
має бути передній фон (частина інтер'єру або щось подібне), може летюча миша або якась річ, яка, коли ти туди
підходиш, вона улітає і з'являється не одразу, як вийшов з зони огляду, а через час». Decision: [[figma_decision_register]]
D774. No Figma design (world art, not UI).

## What exists today
| Thing | Where | State |
|---|---|---|
| Foreground layer in front of the hero | `Scenes/Backgrounds/foreground_dark.tscn` (`FrontDark`: Parallax2D, scroll 1.3, z 20, modulate 0.3/0.26/0.34), in 13 of 16 rooms (D749, D750) | ✅ |
| Swaying decor pattern | `Scenes/Backgrounds/Decor/palm.tscn` — AnimatedSprite2D, 4 frames, 3 fps, no script | ✅ |
| Bat art | `Assets/Characters/Enemies/bat/sheet.png`, 64×64 cells, row `fly` 4 frames (README) | ✅ an enemy's sheet |
| Bird art | `Assets/Characters/Enemies/vulture/sheet.png` — an enemy, too big for a critter | ❌ no small bird |
| Finding the hero | `GameGroups.PLAYER` (`Scripts/Core/GameGroups.gd:23`) | ✅ |
| Occluder rules | `verify_room_entrances.gd:211` `_check_not_covering`, `:262` `_check_front` — nothing covers a door, NPC or chest | ✅ |
| Wing sound | `sound_events.json` has no `wing`/`flap` event (`grep -n 'wing\|flap'` → 0 hits) | ❌ |

## Missing entirely
`grep -rniE 'critter|flee|fly away' SampleProject/Scripts SampleProject/Scenes` → 0 hits. Missing: the critter scene and
its script, a small bird sheet (perch + fly), a wing-flap sound event, placement in the rooms, a verify script.

## Decisions required
1. **What lives where.** Recommendation: bats in caves, cellars and the Laboratory (the existing bat sheet, darkened
   like the rest of `FrontDark`); birds (pigeons in the City, a small desert bird outdoors and in the Village);
   interiors with no animal get only the still interior piece. Not blocking — default as recommended.
2. **When it comes back.** Sapega: not the moment the hero turns away, «через час». Default: it returns after
   **30 s**, and only while its perch is out of view; it reappears perched (no fly-in). A room left and entered again
   keeps the timer for the session (a static dictionary keyed by room and node), it is not saved. Provisional,
   tune in play.
3. **Scare distance.** Default 160 px between the hero and the critter's drawn position. Provisional.
4. **The bat critter vs the bat enemy.** Same sheet; the critter is a dark silhouette on the foreground plane and never
   blocks or hurts. If in play it reads as an enemy, generate a smaller cave bat. Not blocking.

## Slices
### Slice 1 — the critter and the Lizard Cave pilot (☁)
- `Scenes/Backgrounds/Decor/critter_bat.tscn` + `Scripts/Gameplay/AmbientCritter.gd` (preloaded, no `class_name`):
  `perch` (frame 0 of `fly`, held) and `fly` (4 frames, 12 fps). Every physics frame: if the hero is within the scare
  distance of the critter's `global_position` (Parallax2D moves the node, so this is where it is drawn), it plays
  `fly`, tweens up and away from the hero out of the view, hides, and stores the time it left. It shows again perched
  when the delay has passed and a `VisibleOnScreenNotifier2D` on the perch says it is off screen.
- Two bats under `LizardCave/FrontDark`, hanging from the ceiling roots, away from the doors and the chest.
- `SampleProject/UI/verify_ambient_critters.gd`: the hero walks up → it leaves the view; it stays away while the perch
  is on screen and before the delay; it is back after the delay with the perch off screen; nothing covers a door
  (`verify_room_entrances` stays green).
- Own commit.

### Slice 2 — the bird (🖥 ComfyUI)
- `comfy_sprite.py critter_bird`: a small bird, 32×32 or 48×48, rows `perch` 2 (`BOB`) and `fly` 4, side view facing
  right; a pigeon variant for the City by recolour or a second seed. Sheet + README (AI disclosure). Show Sapega a ×4
  sheet. Commit at once.
- A soft wing-flap sound (CC0) as `sound_events.json` → `critter_flap`, played on take-off.

### Slice 2b — butterflies and glow (🖥 ComfyUI)
- Atmosphere rule ([[m6_backdrops]], Sapega 2026-10-27): a small butterfly sheet (perch 2, fly 4, two colourings) and a
  moth, plus a soft firefly / spore glow sprite for the particles; README with the AI disclosure.

### Sapega's placements (2026-10-27)
«Міль на горищі діда, миша в підвалі, голуб в місті» («миша летюча я мав на увазі»): the **moth** lives in Grandfather's
attic (ElderHouse attic), a **bat** in the cellar (GatehouseCellar; the existing bat critter), the **pigeon** in the City. And a **mouse** too
(Sapega on the idea: «о ні, це гарна ідея»): a ground critter that runs along the floor into a hole when the hero comes
near and comes back later — in the cellar under the bat and in the house interiors; new art: a small mouse sheet,
`idle` 2 and `run` 4, side view; the behaviour is `AmbientCritter` with a ground path instead of a flight. Bats stay in
the Lizard Cave; butterflies and the lark outdoors.

**Mouse — placed (wire-art, 2026-10-28):** `critter_mouse.tscn` (`AmbientCritter.hole` + `run_speed` 220 px/s; the hole is a dark `Polygon2D` oval on the floor), `GatehouseCellar` Mouse1 (x 1320, under Bat2, hole +96) and `ElderHouse` Critters/Mouse1 (x 740, hole +84 at the right wall foot); `verify_ambient_critters` [5]/[8]. Earlier note — **Mouse — not placed yet (rooms-dressing, 2026-10-27).** The sheet `Critters/mouse.png` has landed (12 art px sitting),
but the mouse needs what the others do not: a ground path to a hole instead of a flight, and the hole itself (a painted
gap at a wall foot in the GatehouseCellar and the house interiors). Next room-routine slice: `AmbientCritter` gets a
`run_to` (a Marker2D child: the hole), `critter_mouse.tscn` (scale 18 / 12 = 1.5, the sheet is drawn at 12 px), one
in the cellar under the bats and one in ElderHouse; `verify_ambient_critters` [5] then lists it in `LIVES`.

### Slice 3 — every room (☁, the one room routine)
- Birds in the outdoor rooms and the City, bats in the caves, cellars and Laboratory rooms, one to three per room, with
  the foreground pieces of D774 (MayorHall, BanditCamp get theirs first — [[m6_backdrops]]).
- The atmosphere effects of [[m6_backdrops]] in every existing room: one or two per room, fitted to the place, on
  `GraphicsQuality`; the Canyon's dust swirls are the reference.
- New M6 rooms get critters and their atmosphere as they are built (M7).

## Order and dependencies
`1 → 3`; `2` runs in parallel with `1` on the PC. Slice 3 waits for the map routines that edit the same room scenes
(secrets → secrets-icon → map-pan) to merge.

## Out of scope for this pass
Flocks that rise together, critters that land on the hero's path, day/night — add on Sapega's word.
