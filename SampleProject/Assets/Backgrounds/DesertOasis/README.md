# Desert Oasis backgrounds

Source: craftpix.net — *Free Desert Oasis Pixel Art Background Pack* (`assets/craftpix-net-546708-free-desert-oasis-pixel-art-background-pack/`).
Licence: craftpix free licence, https://craftpix.net/file-licenses/ (the pack's `License.txt`). Chosen under D210.

`bgN/planK.png` = `PNG/background N/Plan K.png`, 576×324, drawn at ×1.5 (864×486 — one MetSys cell; the camera zoom is 2.25). Plan 5 is the farthest (sky), Plan 1 the nearest.
Scenes: `SampleProject/Scenes/Backgrounds/desert_backdrop_N.tscn`.

## Desert floor tiles

**A7 redraw (2026-10-28, D813 «прибрати»).** `SampleProject/Sprites/DesertTiles.png` and `DarkTiles.png` are repainted
by `Scripts/Tools/repaint_tiles.py` from the rooms' painted terrain (`Assets/Backgrounds/Terrain/`: Canyon sandstone body
and sand surface, Mayor Hall cut blocks — AI-generated materials, see that README), sampled at the world's ×1.5. The
Brackeys sand / cobble tiles and the MetSys grey/teal look are gone; the grid (32 px), atlas layout, transparent cells and
every tile's role stay, collisions are untouched (`Resources/DesertTileset.tres`, `Resources/Tileset.tres`).

| Atlas cells | Role (MetSys autotile layout) | New look |
|---|---|---|
| 7..9 × 6..8, 12 × 6..8 | ground panel: top / sides / bottom edges | sandstone strata, sand surface band on the top edge, worn outlined sides, shaded underside |
| 7..10 × 10..11, 15 × 10..11 | fill, inner corners | the same body (one seamless 32-px texture; variants differ only inside, ≥ 4 px from the edge) |
| 10 × 6..8, 11/13 × 6..8, 7..10 × 9, 13..14 × 9..10 | vertical strip (gate pillar), single blocks, horizontal strip, slab | cut sandstone blocks, mortar on the tile edge, outlined open sides |
| 7..15 × 0..5 | background wall, no collision | darker block masonry; plain cells → plaster |
| 0..6 × 0..14 | MetSys decor: one-way bridge, capital with slopes, column, spikes (no room places them) | recoloured into the sandstone ramp, silhouettes kept pixel-for-pixel (slopes match their collision) |

`DarkTiles.png` is the same drawing pulled into the caves' violet shade with a warm lit top edge (caves / interiors /
lab); no room places it yet. Visible in-game today: `8,6` (ElderHouse attic floor), `10,7` + `11,7` (attic back wall,
modulated), `8,1` (attic darkness), `10,6..8` (Canyon / DesertRoad gate pillar), `8,7` (MayorHall east edge column); every
other placed cell is in a hidden collision layer. Before | after: `design/shots/a7_tiles.png`.
