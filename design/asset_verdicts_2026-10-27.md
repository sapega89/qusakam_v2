---
type: plan
status: active
tags: [art, comfyui, assets]
---

# Asset verdicts 2026-10-27 — the art queue

Sapega marked every card in the asset catalog (https://claude.ai/artifact/Qxty8beDtyy71ULkuvmocf, db `verdicts`,
generator `Scripts/Tools/asset_catalog.py`): **347 ok, 48 fix, 29 remove**. His answers on the ambiguous ones (D813):
«прибрати» on a new road plane, a shield phase or anything the game already uses means **redraw**, and the old file
goes only once the new one is wired; a fix without a note is the art lane's own call, shown as a before | after sheet.
Unused leftovers were deleted at once (`fdb739c9`).

Each batch is one ComfyUI run (< 1 h, own sheet), in this order. Mark ✅ with the commit.

| # | Batch | Items | Status |
|---|---|---|---|
| A1 | Sapega's noted fixes | main menu background: the same beautiful art, but a desert instead of the forest and a lizard (ящур) instead of the human (`UI/main_menu_background.jpg`); boss shockwave more expressive (`FX/Bosses/shockwave.png`); hero Climb with alternating arms and legs (`Sprites/Player/Climb/`) | ⬜ |
| A2 | NPCs → chibi, 1 | «чібі» on every NPC sheet (D677/D598 chibi style, as `alchemist/sheet_chibi.png`, `malik/sheet_chibi.png`): blacksmith, merchant (**an older, cunning rat-folk**), old_man, priest, contract_priest | ⬜ |
| A3 | NPCs → chibi, 2 | dervish, gate_guard, gate_scribe, malik (main sheet), prisoner, witch | ⬜ |
| A4 | NPCs → chibi, 3 | townsfolk_merchant_woman, townsfolk_old_man, townsfolk_porter, townsfolk_water_carrier; alchemist (fix) | ⬜ |
| A5 | Road planes redraw | MountainPath `gen_far`, `gen_waymarker`; StreamGorge `gen_mid`, `gen_plume`; ScreeSlide `gen_scree`, MountainPath `gen_plume` (fix); the Rock Ledges redo (cliff like the gorge walls, a wider plateau with a gate/breach, 3–4 burnt houses at the right size, D796) | ⬜ |
| A6 | Shield phases redraw | `FX/Shield/magic/drop_*`, `fade_*`, `glass/shatter_*` (H2) | ⬜ |
| A7 | In-game art redraw | Brass Collector `sheet.png` + `stagger.png`; Canyon dust (`Decor/dust`); hit flash `FX/Hit/cut_*`; `Terrain/Canyon_Gorge.png`; tutorial `basic_controls.png`, `journal.png`; `Sprites/Collectible.png`; tilesets `Sprites/DarkTiles.png`, `DesertTiles.png` (the tile grid must stay the same) | ⬜ |
| A8 | Fixes, own call: places | BanditCamp `gen_floor`, `gen_mid`; Cellar `gen_back`; the 7 `Terrain/*_Terrain.png`; `Laboratory/lamp.png` | ⬜ |
| A9 | Fixes, own call: effects and items | skill FX radiant_smite, searing_hex, second_wind (charge + release), skyfall_blessing release, withering_grasp; smears `punch_*`, `thrust_*`; `Companions/coin.png`; `Weapons/iron_halberd.png`; hero `Block/1.png`; tutorial `saving.png`, `the_map.png` | ⬜ |
