# Painted terrain (D248, D249)

One picture of the walkable ground per room, drawn over the unchanged collision: the tile layers stay as
invisible collision, `<Room>_<Node>.png` is a `Sprite2D` (×1.5, the hero's pixel scale) right after `TileMap`.

Pipeline: `Scripts/Tools/build_terrain.gd -- mask` (solid mask per room) → `python -I Scripts/Tools/paint_terrain.py`
(fills the mask with materials, a surface band on every edge you can stand on) → `build_terrain.gd -- place`
(adds the node to the room's `.tscn` as a text edit).

The materials (rock and earth bodies, sand / cobble / oasis-grass surface bands) are **AI-generated**:
`paint_terrain.py` asks the local ComfyUI for them through `comfy_backdrop.py` with **Qwen-Image** (Alibaba Qwen,
Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), then brings them to the game's pixel and
palette. A Steam release has to disclose AI-generated content.

| Room | Body | Surface |
|---|---|---|
| Canyon (Terrain, Gorge) | sandstone | sand_top |
| Village | earth | sand_top |
| DesertRoad, CityGates, City | earth | cobble_top |
| LaboratoryOutside | sandstone | oasis_top |

**A7 redraw of `Canyon_Gorge.png`** (2026-10-28, D813 «прибрати»; before | after `design/shots/a7_ingame_redraw.png`):
the same collision mask and materials, painted again by `paint_terrain.py` with three changes in the painter — the walk
surface is high-passed (`FLOOR_BLOB`: blotches wider than 6 px go to the mean colour, pebbles and cracks stay), so the
orange sand «star» no longer sits on every ledge; each edge row takes its own offset into the surface texture; the
underside of every ledge darkens over its last 28 px (`UNDER`, `UNDER_DARK`), so a thin ledge reads as a slab with
volume and the lower, narrower collision step reads as its shaded underside, not a lighter second plate. The other
rooms keep their pictures until they are repainted (A8).

**A8 repaint of the seven `*_Terrain.png`** (2026-10-28, D813 «поправити» without a note; before | after
`design/shots/a8_places.png`): the same masks (`build_terrain.gd -- mask` re-run, byte-identical; DesertRoad's is the D830
flat road), so every walk line, ledge and one-way edge is painted exactly where it was. All seven get A7's painter, plus:

- **Body quilting** (`quilt()`): the rock/earth texture is 288 px wide — half a screen — and the model's seam repaint left a
  pale ghost and broken strata at the same x in every period. The body is now stitched from 144-px patches taken from
  random places outside that seam band, each joined to its neighbour along the least-different line (image quilting), so
  the strata run on and the repeat is gone. The second vertical period is the texture turned 180° instead of mirrored —
  a mirror folded the diagonal veins into chevrons — and the per-period x-shift (a horizontal seam) is gone.
- **LaboratoryOutside**: the oasis floor took its colour from the whole top band, mostly the violet damp sand under the
  grass, and came out grey-violet; it now takes it from the grass rows (`surface`), and is green.
- **MayorHall**: the `marble_floor` texture was a hall with columns and light shafts (pale swirls in the floor band); it is
  regenerated as a plain tile grid (seed 369), and the hall's far edge is straight (`ragged=0`).
- Specks the model left floating above the top band (tufts not attached to the ground) are dropped.

`Canyon_Gorge.png` is painted by the same run (`paint_terrain.py Canyon`), so its body is quilted too; its ledges and
surface are A7's. `canyon_depths.png` was left as committed.

`SampleProject/Assets/Backgrounds/Canyon/canyon_depths.png` (the gorge's back wall) is made by the same script from
the sandstone material.
