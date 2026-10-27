---
type: plan
status: active
tags: [art, comfyui, rooms, M6]
---

# M6 — backdrops for the new rooms (ComfyUI, the PC)

The room graphs are accepted (M5: M1 `545:6590`, M3 `557:6590`, M4 `560:6590`). Every new room needs its backdrop
before the one map routine (M7) builds it. Each passage is painted where the graph puts it (D747): a door, an arch, a
cave mouth, a well shaft, a hole in the floor. Ladders only where a place would really have one (an attic hatch, a
well, a ladder up a house wall). Tool: `comfy_backdrop.py` (the `comfy-backdrop` skill); props like the forge and the
chapel stand on the floor line. Sapega sees each batch in a capture before the next one.

**Interesting, in several layers** (Sapega 2026-10-27: «фони мають бути цікавими, можливо не один шар»). Each room gets
at least three planes: a far one (sky and distance, slow parallax ×0.3–0.5), a middle one (buildings, rocks, machines,
×0.7–0.85) and the room's own wall at ×1.0 with its passages painted in; outdoors also the dark foreground that passes
now and then (D750). Every screen has something to look at that tells the place: smoke, banners, lamps, broken
statues, pipes with steam, birds, a story detail in the distance. No screen is just a repeated texture.

**Interesting things are their own props** (Sapega 2026-10-27: «от як ящури в печері — вони цікаві, то треба було
зробити їх як окрема частина інтер'єру»). A shrine, an idol, a statue, a machine or a cart is generated alone and
placed once in the room where it makes sense, like the forge and the chapel. It is not baked into a tiling backdrop,
where it repeats every screen. The wall layers stay calmer, so these props read. Each prop sits on its own plane
with its own parallax, between the wall and the hero («на тому ж місці, але наче ми їх оббігаємо, типу паралакс»):
running past, it slides against the wall behind it, and the room gets depth. The Lizard Cave keeps its idol shrines
where they are today, cut out onto such a plane.

**Every room has a foreground** (D774, Sapega 2026-10-27: «всюди, в кожній кімнаті, в кожному притулку має бути
передній фон»). Each room below gets its piece in front of the hero with its backdrop: an interior piece (a column, a
beam, a lamp, crates) or the outdoor occluders of D750, never over a door, an NPC or the middle of a fight. Some of it
is alive: a bat or a bird that flies off when the hero comes near and comes back later — [[ambient_critters_plan]].
The ledge the hero walks on is the floor plane, behind him, not foreground.

**Every room has atmosphere: something alive in the air** (Sapega 2026-10-27: «нам треба зробити атмосферу гри, тому треба
додавати якісь ефекти світіння або бабочки — таке вже щось схоже є в каньйоні, на це приємно дивитись»; the room routine
does it in every room it builds). Today only the Canyon and the Desert Road have it (the dust swirls
`Scenes/Backgrounds/Decor/dust.tscn`, `Decor/Dust1–4`, and the `AmbientDust` particles in `Game.tscn`). Each room gets
one or two quiet effects that fit the place: outdoors and the oasis — butterflies, dragonflies by water, drifting sand
and pollen, dust in the light; caves — glowing spores or fireflies, dust in a light shaft, drips that glint; the City —
dust in sunbeams, chimney smoke, lantern glow; the Laboratory — steam, sparks, the glow of vials and lamps; interiors —
dust in the window light, candle flicker. Small, slow, low alpha, mostly behind the hero; never over a door, an NPC or
the middle of a fight, never mistaken for an enemy or a pickup; particle counts follow `GraphicsQuality` (Low halves
them, D554). Sprites (a butterfly, a moth, a firefly glow) are art-lane work; the placement is the room routine's.

**Everything at the world's scale** (a player via Sapega 2026-10-27: everything is too big next to the hero): props,
doors and painted objects follow the size chart of [[world_scale_plan]] — the hero is exactly 1 H = 64 art px, a door
112 art px, a barrel 32 — exact sizes, no «about» (Sapega); prompts name the size against the hero, and planes further back shrink with their factor.

## Batch 0 — existing rooms with no foreground (D774)

| Room | What goes in front | Status |
|---|---|---|
| Mayor Hall (arena) | a chandelier and banners at the top, columns at the sides | ✅ `a927d524` |
| Bandit Camp (arena) | tent ropes and stakes at the sides, a dark crate low | ✅ `a927d524` (a stake with two guy ropes, A-shape) |

## Batch 1 — Canyon of Whispers (M1 v3), story order

| Room | Kind | Screens | Passages to paint | Status |
|---|---|---|---|---|
| Lizard Cave (exists) | underground | — | the lizard idol shrines become separate props; the wall behind them is repainted without them | ✅ B162 (`cccb333c`): far / wall / shrines / floor planes |
| Mountain path | outdoor, main | 2 | — | 🔄 art M6a-1 (`Backgrounds/MountainPath/`: barrier ×0.1 (cracked glass dome), far ×0.3, smoke plume ×0.4 blown west, mid ×0.75, waymarker ×0.9, ground, front — M6a-1b, D795), waiting for Sapega’s look at `shots/m6a1_path_scree.png` |
| Scree slide | outdoor, main, falls | 1×2 | a scree run down | 🔄 art M6a-1 (`Backgrounds/ScreeSlide/`: gorge-wall mid ×0.75 with hazed ledges, slope ×1.0 with its surface polyline in the README; shares the path’s barrier, far, plume, front), same review |
| Stream gorge | outdoor, main | 3 | — | 🔄 art M6a-2a (`Backgrounds/StreamGorge/`: shared barrier ×0.1 (now full screen width, D797) and far ×0.3, own plume ×0.5, far wall ×0.75 continuing the scree’s, bank + stream ×1.0, reed-boulder front ×1.3), waiting for Sapega’s look at `shots/m6a2_gorge.png` |
| Rock ledges | outdoor, main, climbs | 1×2 | ledges up (no floating platforms, A15) | ⬜ |
| Cave under the bridge | underground | 1×3 | the cave mouth; the way down | ⬜ |
| Grandfather's attic | interior | 1 | the hatch with its ladder | ⬜ |
| Smugglers' stash | secret | 1 | a cracked wall | ⬜ |
| Mesa top | side | 4 | — | ⬜ |
| Zahra's Rest (oasis) | main | 2 | — (`Backgrounds/DesertOasis/` is empty) | ⬜ |
| Dunes | main | 4 | the camp path | ⬜ |
| Old ruins | underground | 4 | the leader's key gate | ⬜ |
| Chasm | main | 1 | the bridge dropped from the far side | ⬜ |
| Dry riverbed | underground | 1×2 | the climb out | ⬜ |
| Aqueduct | underground | 4 | the way up to the gate approach | ⬜ |
| Gate approach | main | 2 | the City gate | ⬜ |
| M1a: smoke over the village, the fallen barrier; the burnt village | background story | — | — | ⬜ |

## Batch 2 — the City (M3)

| Room | Kind | Screens | Passages to paint | Status |
|---|---|---|---|---|
| Craft quarter | main | 3 | the forge and chapel fronts stand there (props exist) | ⬜ |
| Palace square | main | 2 | the palace doors, the alley down | ⬜ |
| Rooftops | side | 3 | a ladder up a house wall; the drop to the gate | ⬜ |
| Pigeon loft | secret | 1 | loose boards | ⬜ |
| Tavern attic | interior | 2 | the hatch with its ladder behind the stall | ⬜ |
| Mayor's archive | interior | 1 | the bookshelf door | ⬜ |
| Cistern under the market | underground | 3 | the well shaft; the grate into the gate cellar | ⬜ |
| Cistern stash | secret | 2 | a cracked wall | ⬜ |

## Batch 3 — the Laboratory (M4 v2)

| Room | Kind | Screens | Passages to paint | Status |
|---|---|---|---|---|
| Floors 1–3 (zigzag) | main | 5 each | an opening in the floor at alternate ends | ⬜ (today's `Lab/` layers, longer) |
| Alchemist's corridor | side | 3 | stairs up from floor 1 | ⬜ |
| Alchemist's storeroom | interior | 2 | a locked door | ⬜ |
| Malik's stash | secret | 2 | the loose slab in his cell | ⬜ |
| Collapsed drain | underground | 7 | the grate in floor 3; the hatch into the cells | ⬜ |
| Courtyard (finale) | main | 1 | — (one room with the demo's finale) | ⬜ |
