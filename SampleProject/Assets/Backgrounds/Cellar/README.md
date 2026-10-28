# Gatehouse cellar art

**AI-generated**: `gen_back.png` by `Scripts/Tools/comfy_backdrop.py` (layer `Cellar/gen_back`), cut into planes by
`design/shots/candidates/cellar_planes/cellar_planes.py` with Qwen-Image-Edit-2511 — the local ComfyUI with **Qwen-Image**
/ **Qwen-Image-Edit** (Alibaba Qwen, Apache 2.0) and the Lightning LoRAs (lightx2v, Apache 2.0), in the backdrop's 16
colours at the game's pixel (×1.5). A Steam release has to disclose AI-generated content.

| File | Use (`Maps/GatehouseCellar.tscn`) |
|---|---|
| `gen_back.png` | the source picture (was the whole room, tiled twice); not in the cellar scene. `CityGates.tscn` → `CellarArch` shows its region (300, 40, 150 × 170) as the cellar entrance. **A8** (2026-10-28, `cellar_planes.py arch`): that arch held a cobweb, a bat nest and bottles on a crate cut off by the frame — a storeroom, not a way in; now the vault is empty and dark with warm lamp light rising from the stairs below. The planes were cut before A8 (a `build` now would cut this arch empty) |
| `gen_far.png` | Back/Far ×0.5: the dark brick back wall seen through the arches, mirrored seamless (1152 px) |
| `gen_mid.png` | Back/Mid ×0.8: arches, columns, barrels, crates and bottles; stairs, lantern and bat repainted out, arch openings transparent |
| `gen_stairs.png` | Back/Props ×0.9: the stone stairs, once, by the exit |
| `gen_lantern.png` | Back/Props ×0.9: the hanging lantern, once: body 24 art px, 115 from the ceiling (world scale) |
| `gen_floor.png` | Back/Floor ×1.0: the empty flagstone floor, row 0 = the walk line y 416, a light lip |
| `gen_column.png` | FrontDark/Pillar1–2 (×1.3, ×2): a stone column with its capital from the backdrop, in place of the flat black `fg_pillar` strip |

## A13 (B189, D814), 2026-10-28 — props out of `gen_mid`, at chart size

`gen_mid.png` had two barrels (95 art px — 3.7× the chart on its ×0.8 plane), stacks of crates and wine bottles
between the columns. `Scripts/Tools/unbake_props.py` (Qwen-Image-Edit-2511, Apache 2.0, AI-generated) repainted it
without them: the columns continue to their bases, and the arch openings behind the props are transparent down to the
floor like the left arch (the model bricked them up with see-through joints — those pixels are cut open, `OPEN`), so
`gen_far`'s back wall shows through. Original: `design/shots/candidates/a13/cellar_orig.png`.

Props (`comfy_backdrop.py` layers `Cellar/prop_*`, **Qwen-Image**, Apache 2.0, AI-generated; barrel and crate 32 art ×
0.8 = 26 art, in the cellar's palette). Wire as a `Sprite2D` child of `Back/Mid`, `texture_filter = 1`,
`scale = (1.5, 1.5)`, `centered = false`, `offset = (−width / 2, −height)`, `position` = the feet:

| File | Size (art) | Feet `position` in `Back/Mid` | Was |
|---|---|---|---|
| `prop_barrel.png` | 21×26 | (319.5, 433.5) | barrel left of the first column |
| `prop_crate.png` | 27×26 | (388.5, 436.5) and (388.5, 397.5) on top | two crates by the first column |
| `prop_barrel.png` | 21×26 | (499.5, 426) | barrel between the columns |
| `prop_crate.png` | 27×26 | (595.5, 418.5) and (595.5, 379.5) on top | crates with bottles, middle arch |
| `prop_crate.png` | 27×26 | (789, 414) and (789, 375) on top | crates with a bottle, right arch |

The bottles are not redrawn (each under the chart's smallest row); the crates stand without them.
