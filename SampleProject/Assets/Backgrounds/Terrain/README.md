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

`SampleProject/Assets/Backgrounds/Canyon/canyon_depths.png` (the gorge's back wall) is made by the same script from
the sandstone material.
