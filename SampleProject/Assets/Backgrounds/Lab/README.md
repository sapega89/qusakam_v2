# Laboratory planes and surfaces (D246)

**AI-generated.** `Scripts/Tools/comfy_backdrop.py` (layers `Lab/*`) asks the local ComfyUI for them with
**Qwen-Image** (Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), then brings
them to the game's pixel (×1.5) and palette. A Steam release has to disclose AI-generated content.
Placed by `Scripts/Tools/build_laboratory.gd`:

- `gen_far.png` — the far vaulted hall (Parallax2D ×0.4, every storey).
- `gen_mid.png`, `gen_mid2.png` — the row of lab equipment on the floor (×0.75; storeys 1 and 3 / storey 2).
- `gen_front.png` — pipes, cables and bulbs hanging from the ceiling in front of the hero (×1.25).
- `gen_slab.png` — 576×64 slab cross-section (grating walkway, brass edge, riveted plates): the texture of every
  floor, wall and bridge the hero touches; the collision is the hidden `TileMap/Foreground`.

Laboratory rooms (queue row 9.4, D303) — same model and licence, placed by `build_laboratory.gd`:

- `gen_cell.png` — a prison cell niche (LabCells `Cells`, five of them).
- `gen_bars.png` — iron bars sized to the niche's opening (LabCells `Bars`, drawn over the hero).
- `gen_table.png` — the operating table (LabCells `Table`).
- `gen_boss_far.png` — the fire djinn's hall: furnaces, broken vats, rings of glyphs (LabBoss far plane ×0.4). Its runes
  read as Latin letters (DPOB over the furnace); `Scripts/Tools/comfy_art_fixes.py boss_runes` repainted only their
  rectangles of the approved image (same model, denoise 0.65; the side rings with the image rolled by half so the
  horizontal seam stays intact): rings of triangular wedge glyphs, and glowing studs on the band over the furnace
  (tries with «abstract glyphs» and with the layer prompt drew zigzags, «M●C●M» and Chinese-like signs). Then
  `comfy_backdrop.py Lab/gen_boss_far` as usual (its prompt now names the glyphs). Same size, 576×324.
- `gen_gates.png` — the portcullis before LabBoss's east exit (LabBoss `Gates`).
