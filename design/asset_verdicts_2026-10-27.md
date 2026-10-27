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

**Like Skul (D816): only Kusakam and his companions are chibi**; NPCs and enemies keep normal proportions and are not redrawn into chibi; the «чібі» notes on NPC cards are void.

Each batch is one ComfyUI run (< 1 h, own sheet), in this order. Mark ✅ with the commit.

| # | Batch | Items | Status |
|---|---|---|---|
| A1 | Sapega's noted fixes | main menu background: the same beautiful art, but a desert instead of the forest and a lizard (ящур) instead of the human (`UI/main_menu_background.jpg`); boss shockwave more expressive (`FX/Bosses/shockwave.png`); hero Climb with alternating arms and legs (`Sprites/Player/Climb/`) | ✅ Climb `4711b42f`, shockwave `999a1a1b`, menu (candidate C2: the hero's sand-yellow lizard, painterly-prompted Qwen-Image-Edit of the original) — commit below; sheet `design/shots/a1_menu_shockwave_climb.png`, waits for Sapega's look |
| A2 | ~~NPCs → chibi~~ | cancelled (D816). Left from the notes: the merchant becomes **an older, cunning rat-folk** (normal proportions). NPC size (B188, 96 art) stays open until Sapega asks for the redraw | ⏸ |
| A4 | Alchemist (fix) | the alchemist's normal sheet, fix without a note (own call) | ⬜ |
| A5 | Road planes redraw | MountainPath `gen_far`, `gen_waymarker`; StreamGorge `gen_mid`, `gen_plume`; ScreeSlide `gen_scree`, MountainPath `gen_plume` (fix); the Rock Ledges redo (cliff like the gorge walls, a wider plateau with a gate/breach, 3–4 burnt houses at the right size, D796) | ⬜ |
| A6 | Shield phases redraw | `FX/Shield/magic/drop_*`, `fade_*`, `glass/shatter_*` (H2) | ⬜ |
| A7 | In-game art redraw | Brass Collector `sheet.png` + `stagger.png`; Canyon dust (`Decor/dust`); hit flash `FX/Hit/cut_*`; `Terrain/Canyon_Gorge.png`; tutorial `basic_controls.png`, `journal.png`; `Sprites/Collectible.png`; tilesets `Sprites/DarkTiles.png`, `DesertTiles.png` (the tile grid must stay the same) | ⬜ |
| A8 | Fixes, own call: places | BanditCamp `gen_floor`, `gen_mid`; Cellar `gen_back`; the 7 `Terrain/*_Terrain.png`; `Laboratory/lamp.png` | ⬜ |
| A9 | Fixes, own call: effects and items | skill FX radiant_smite, searing_hex, second_wind (charge + release), skyfall_blessing release, withering_grasp; smears `punch_*`, `thrust_*`; `Companions/coin.png`; `Weapons/iron_halberd.png`; hero `Block/1.png`; tutorial `saving.png`, `the_map.png` | ⬜ |
| A10 | Scale: enemies (B187) | normal proportions (D816): `bandit_archer` at 96 art (the bandit itself is a BACKLOG item, Sapega); elites `shield_tower`, `bandit_brute`, `archer_heavy` at 120 art (D766, D814) | ⬜ |
| A11 | Scale: palms (chart #2–3) | `palm_sheet` at 256 art (4 H); the FrontDark occluder palms use the same palm ×1.3 on its plane | ⬜ |
| A12 | Scale: doors, gates, houses (B190, B192) | locked gates `gen_gate.png` (BanditCamp, LizardCave) at 128 art; door sheets (`palisade_gate`, `lab_door`, `cave_mouth`, `palace_door`, `door_elder`) at 112 art, `mesa_cleft` re-cut; City `CityNear`, Village `Houses` painted doors to the exact door; City forge one storey 144 art | ⬜ |
| A13 | Scale: props (B189, B191) | BanditCamp `Back/Mid` + `gen_sacks`, Cellar `gen_mid`, ElderHouse `Wall` repainted without props + props at exact sizes (barrel 32 art…); `fg_scrub_sheet` 2:1 downsample | ⬜ |
| A14 | Companions (stay chibi, D816) | `astrit` `enter` is a copy of `run` — draw a real one | ⬜ |
