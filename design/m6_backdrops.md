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
| Stream gorge | outdoor, main | 3 | — | 🔄 art M6a-2a (`Backgrounds/StreamGorge/`: shared barrier ×0.1 (now full screen width, D797) and far ×0.3, own plume ×0.5, far wall ×0.75 continuing the scree’s, bank + stream ×1.0, reed-boulder front ×1.3), smoke moved beyond the east edge (D796, Sapega), waiting for Sapega’s look at `shots/m6a2_gorge.png` |
| Rock ledges | outdoor, main, climbs | 1×2 | ledges up (no floating platforms, A15) | 🔄 art M6a-2b, redone in A5 (`Backgrounds/RockLedges/`: shared barrier/far, far wall ×0.75 continuing the gorge’s, three burnt village houses ×0.6 with smoke from their roofs (no big plume), the village’s outer wall with a breach ×0.9 — the passage east, sandstone cliff with 7 ledges 60 world px wide and a wide plateau ×1.0 — collision table in the README — and a cascade into the gorge stream, reeds front ×1.3), waiting for Sapega’s look at `shots/m6a2b_ledges.png` and `shots/a5_road_before_after.png` |
| Cave under the bridge | underground | 1×3 | the cave mouth; the way down | 🔄 art M6b-1 (`Backgrounds/BridgeCave/`: far ×0.5, wall ×1.0 with the mouth in the ceiling, three shelves and the pit down — collision table in the README —, the shaman family's waymark ×0.9, end-game rope ladder ×2, stalactite front ×1.3), waiting for Sapega’s look at `shots/m6b1_cave_attic.png` |
| Grandfather's attic | interior | 1 | the hatch with its ladder | 🔄 art M6b-1 (`Backgrounds/GrandfatherAttic/`: roof-and-gable wall, the house's floor with the hatch cut in, the ladder top, his belongings, the Maiden statuette corner with his notes, herbs front ×1.3), same review |
| Smugglers' stash | secret | 1 | a cracked wall | 🔄 art M6b-6 (`Backgrounds/SmugglersStash/`: the smugglers' den in one opaque plane with its own sandy floor — prop beam, lantern niche, tally marks and a scratched map, a peg rail with a hanging sack; its way out is the **tunnel the wall painted** (ExitDoor 432 → 192 world, cave mouth deleted); the goods ×1.0 (crates 32–40, strongbox, amphora, rug, 80 art); the cave stalactites front ×1.3; no lock — the grandfather's key opens the lizard shrine, not the stash; wiring table in the README), waiting for Sapega's look at `shots/m6b6_canyon_floor.png` |
| Canyon floor | outdoor, main | 4 | the cracked wall to the stash; the hole down into the lizard caves; the cave mouth east | 🔄 art M6b-6 (`Backgrounds/CanyonFloor/`: far canyon walls ×0.45, boulders and dead thorn bushes ×0.75, the smugglers' abandoned handcart ×0.9 (58 art), the dead-end cliff ×1.0 with a natural crack at x 300 world (door-tall, 112) walled up by the smugglers — the **cracked wall** is `Wall_Stash`'s sprite (124 art), the crack stands open behind it; the cave mouth into the Cave Exit at the east edge; the whole floor in one 2304-art strip (the Mountain Path's rock) with the **hole** at 2912…3104 world painted (it drops into the Lizard Caves, D834); the path's rock-spire front ×1.3 twice; wiring table in the README), same review |
| Cave exit | underground | 1 | the pit from the cave under the bridge (in the ceiling); the tunnel west; the mouth east | 🔄 art M6b-6 (`Backgrounds/CaveExit/`: one fixed composition — the cave depths of the Cave under the Bridge left of the mouth's rock curtain and the Desert Road's sky and mesas right of it (far, baked), the ceiling with the **pit's hole at 90…225 world** (the BridgeCave art's pit; the generator's cave still has its bottom hole at 320…544 — wire the cave to its art), a rubble mound with broken planks under it, the Lizard Cave floor kept, the cave's stalactite front ×1.3; wiring table in the README), same review |
| Mesa top | side | 4 (scene: 2) | — | 🔄 art M6b-2 (`Backgrounds/MesaTop/`: shared sky, the desert plain far below with a caravan ×0.2, neighbouring buttes ×0.5 below this mesa, the bandits' lookout tower ×0.9 (144 art), the climb's floor and rock front reused; tiles, so a 4-screen room needs no new art; wiring table in the README), waiting for Sapega's look at `shots/m6b2_mesa_oasis.png` |
| Zahra's Rest (oasis) | main | 2 | the well down to the Old Ruins | 🔄 art M6b-2 (`Backgrounds/ZahraRest/`: the road's sky and far mesas world-anchored (Plan3 offset 172.8), oasis pool + palms + half-buried ruins ×0.6 (palm 154 art), nomads' awning ×0.85, date palm ×0.9, the well with a padlocked iron grate ×1.0 at x 900 (a painted opening), sand ground in the road terrain's look, reeds front ×1.3; wiring table in the README), same review |
| Dunes | main | 4 | the camp path | 🔄 art M6b-3 (`Backgrounds/Dunes/`: the road's sky and far mesas world-anchored (Plan3 offset 518.4), dune sea ×0.5, the buried colossus head with a dragon crown ×0.6 (154 art; the ruins lie under the dunes), near dunes ×0.8, the big dune with the staked path climbing out of view ×0.85 (the camp is two cells up; at exact size its palisade can't sit on a dune that fits the view), the bandits' warning post ×0.9 (115), the trailhead ×1.0 at x 2700 world as a painted passage (112, `CampDoor` when the camp moves here, Q-a), rippled sand ground, thorn-bush front ×1.3 twice; wiring table in the README), waiting for Sapega's look at `shots/m6b3_dunes_ruins.png` |
| Old ruins | underground | 4 (scene: 5) | the leader's key gate | 🔄 art M6b-3 (`Backgrounds/OldRuins/`: dim colonnade hall with light from cracks ×0.45, broken columns over green standing water ×0.75, statue with an offering bowl ×0.85 (136), the dragon relief ×0.9 (130), the well shaft with rope and bucket ×1.0 at `WellDoor` (x 151, a painted opening behind the ceiling), ceiling ×1.0, the aqueduct arch at the east edge ×1.0 (144, the way on), flagstone floor, root-wrapped column front ×1.3 twice; wiring table in the README), same review |
| Chasm | main | 1 | the bridge dropped from the far side | 🔄 art M6b-4 (`Backgrounds/Chasm/`: the road's sky and far mesas world-anchored (Plan3 offset 345.6), the Dunes' dune sea ×0.5 and near dunes ×0.8 continuing, the City's walls and towers peeking over the dunes ×0.4 (115 art), both lips in the Dunes' ground with the abyss painted between them (broken sandstone faces, roots, dark) ×1.0, the **drawbridge** as its own sprite at the exact span (384 art = 144…720 world, deck top on the walk line, no rail — raised it read as a ladder; `FlagBridge` stands it up on the east lip), the bridge winch with its chain running east to the lever ×1.0, a rock spur front ×1.3; one screen, fixed camera; wiring table in the README — the scene is generated by `build_world_rooms.py`), waiting for Sapega's look at `shots/m6b4_chasm_riverbed.png` |
| Dry riverbed | underground | 1×2 (scene: 1) | the climb out (built: the fall in from the chasm and the drop on through the floor) | 🔄 art M6b-4 (`Backgrounds/DryRiverbed/`: the gorge bottom with the crack of sky above and its end choked by a rockfall ×0.45, the old bank with boulders, a driftwood log and dead reeds ×0.75, a wrecked river boat ×0.85 (54 art), cracked-mud floor broken open at 576…800 world into the aqueduct vault ×1.0, boulder front ×1.3; one screen, fixed camera; wiring table in the README), same review |
| Aqueduct | underground | 4 | the way up to the gate approach | 🔄 art M6b-5 (`Backgrounds/Aqueduct/`: the cistern hall beyond round arches ×0.45, square piers with iron rings over green standing water ×0.75 (as the Old Ruins), a broken water-lifting wheel ×0.85 (122 art), a dragon-head spout ×0.9 (86), the vault in one 2304-art strip with the **breach** from the Dry Riverbed at 576…800 world, the Old Ruins' arch seen from inside at the west edge (mirrored), `ApproachDoor` as a side doorway with a stair up to daylight (opening 112), `CellarDoor` as a barred arch (grate 128) with the **grate as its own sprite** to hide when `aqueduct_cellar_open` is set, a rockfall closing the east end, walkway-over-conduit floor, vault-pier front ×1.3 twice; painted doors, wiring table in the README), waiting for Sapega's look at `shots/m6b5_aqueduct_gate.png` |
| Gate approach | main | 2 | the City gate | 🔄 art M6b-5 (`Backgrounds/GateApproach/`: the road's sky and far mesas world-anchored (Plan3 offset 86.4), the Dunes' dune sea ×0.5 (offset 432) and near dunes ×0.8 continuing, the Chasm's City nearer ×0.55 (158 art), three arches of the old aqueduct ×0.75 (135), the **bridge lever**'s stone-and-iron housing with the chain from the Chasm's winch at x 110 world (`lever.tscn` keeps its moving handle: `Base` hidden, `Handle` y −16 on the ratchet axle), the aqueduct well house with a ground-level doorway down at `AqueductDoor` (door 112), old paving under sand, a leaning aqueduct-pillar front ×1.3; wiring table in the README), same review |
| Village, burnt (M6a-3) | outdoor, main | 3 | — | 🔄 art M6a-3 (`Backgrounds/Village/*_burnt.png`: back row, houses row, grandfather’s and elder’s houses after the fire — same sizes, anchors and silhouettes, walls whole, soot, awnings to frames, embers in windows, smoke from eight roofs and a smoke veil in the back row (D796); RockLedges’ three burnt houses rebuilt from the same row, so the two rooms match and the hollow shells are gone), not wired yet, waiting for Sapega’s look at `shots/m6a3_burnt_village.png` and `shots/m6a3_ledges_to_village.png` |
| M1a: smoke over the village, the fallen barrier; the burnt village | background story | — | — | 🔄 the burnt village: M6a-3 above |

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
