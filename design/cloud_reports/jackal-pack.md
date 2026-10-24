---
type: cloud-report
branch: cloud/jackal-pack
date: 2026-10-24
tags: [cloud, combat, enemies, art]
---

# Cloud report: jackal-pack (the ordinary jackal in the pack leader's style, D692 / D693)

**Summary.** Done: the ordinary jackal (`fast`) draws the D693 pick `Enemies/jackal_pack/sheet.png` in `enemy_fast.tscn` and in `kinds.fast.sheet`. It uses the leader's rows: idle 0–1, walk 4–7, attack 8–10, a stagger on the hurt frame 12, and death 16–18. Its numbers and behaviour are unchanged (D642). The hit shapes were re-measured from the new frames (D519), and the paws stand on the floor line (28.5 px, the bandit's). The old Crusenho hyena (`Enemies/jackal/`) is deleted because nothing references it any more. Its two tool jobs are deleted too. The bestiary has no picture, so there was nothing to change there. Tests: `verify_enemy_variety` [1b] (new) and `verify_enemy_stagger` (the jackal now uses its hurt frame). `verify_hit_areas` measures the frames itself and passes unchanged. Capture: `design/shots/jackal_pack/pack_dunes.png`. D-ID: **D694** (text below). B rows fixed: none. Full suite: first run `SUITE: 1 FAIL` (116 PASS; `verify_combat_flow` [2c] put the hero 40 px in front, past the jackal's re-measured bite); after the test fix `verify_combat_flow` RESULT: ALL PASS, so all 117 pass.

## D-ID text (the next free number after D693; the orchestrator renumbers)

| D694 | ROUTINE CALL | **The ordinary jackal is the pack jackal** (D692, D693; `cloud/jackal-pack`). `enemy_fast.tscn` and `enemy_variety.json kinds.fast.sheet` draw `Assets/Characters/Enemies/jackal_pack/sheet.png`: 4×5 cells of 96×72 with the pack leader's rows. They are idle 0–1 (0.4 s each), walk 4–7 (running, 0.5 s loop) and attack 8–10 (crouch, leap, bite at 0.15 s each). The strike still lands at 0.225 s, on the leap. Stagger is the hurt frame 12, held for the whole stagger, so there is no `stagger.png` any more. Death is 16–18. Behaviour and numbers stay as they were (`enemy_stats_fast.tres`, D642). **Drawn at ×0.75** with `offset` (0, 8) (agent call). On screen it is 61×43 px across idle and walk, about the old hyena's 52×42. The pack leader (×1.0, 83 px long) stays about 1.4× its length, so the pack reads as jackals around a bigger leader. The paws are 28.5 px below the centre, which is the bandit's floor line (the old jackal's was also 28.5). Shapes (D519): hurtbox 60.75×42.75 at (−2.625, 7.125); hitbox 26.25×43.5 at (13.125, 6.75) (frames 9–10); `attack_range` stays 80 (contact 28, reach 98). The glint `tell_at` (29, 13) sits on the teeth of the crouch frame. The old Crusenho `2 Hyena` art (`Enemies/jackal/`: sheet, stagger and README) is deleted. Its `comfy_art_fixes.py` jobs `stagger_jackal*` and its `build_desert_enemy_sheets.py` entry are deleted with it. The Crusenho credit still covers the scorpion. |

## What changed (files)

- `Scenes/Characters/Enemies/enemy_fast.tscn`: new sheet, 4×5, ×0.75, offset (0, 8). The rows are re-keyed and the stagger plays frame 12. The shapes and `tell_at` are re-measured.
- `Resources/Data/enemy_variety.json`: `kinds.fast.sheet` → `jackal_pack/sheet.png`.
- `Assets/Characters/Enemies/jackal/` deleted. New: `jackal_pack/README.md` and `jackal_pack/sheet.png.import`. `Enemies/README.md` updated.
- `Scripts/Tools/comfy_art_fixes.py`: `JK`, `jackal_tail_stub` and the `stagger_jackal0/1` jobs are deleted. `Scripts/Tools/build_desert_enemy_sheets.py`: the hyena entry is deleted.
- `UI/verify_combat_flow.gd` [2c]: the hero stands inside the attacker's measured strike instead of a fixed 40 px.
- Tests: `verify_enemy_variety` gets [1b] `_pack_art`, which checks the sheet in the scene and the kind, the 4×5 grid, the frames of each animation, that the old art is gone, and that the paws are on the bandit's floor line. `verify_enemy_stagger` drops the jackal from the stagger.png list and gets a new `[jackal]` check for the hurt-frame stagger. New capture `UI/capture_jackal_pack.gd`.

## Results

- `verify_hit_areas`: RESULT: ALL PASS. «enemy_fast: hurtbox (-33,-14.25) 60.75×42.75 = drawn body», «hitbox (0,-15) 26.25×43.5 = drawn strike», «attack_range 80 starts a strike that reaches (body contact 28, reach 98)»; hit 3 px inside, missed 6 px past.
- `verify_enemy_variety`: RESULT: ALL PASS. [1b] «its drawn paws stand where the bandit's feet do (28.5 vs 28.5 px below its centre)», frames per animation OK, «the old jackal art is gone». [1] «fast small: feet stay on the floor line».
- `verify_enemy_stagger`: RESULT: ALL PASS. «jackal: staggered shows its hurt frame (stagger, sheet.png, frame 12)», still frame 12 at 60 %, back to walk afterwards, tint gone.
- Full suite (`Scripts/Tools/run_verify.sh`): the first run gave `SUITE: 1 FAIL`, with 116 scripts passing. The failure was `verify_combat_flow` [2c] («the swing hits the player in front once (got [])», «turns … hits the player behind (got [])»). The test placed the hero 40 px from the attacker, which is the jackal. The bite measured from the new frames ends 26.25 px from its centre, so it reaches 38 px with the hero's half (the hyena's reached 46.5). The test now places the hero 6 px inside the attacker's own drawn strike (`hitbox` front + 12 − 6, «info fast attacks, the hero 32.2 px in front») for all four placements in [2c], and passes: `RESULT: ALL PASS`. I did not run the whole suite again (rules: once at the end). Only that test file changed after the run.
- **Gameplay note on the shorter bite:** without its 60 px lunge the jackal now reaches 38 px instead of 46.5. In play every attack lunges, so it still reaches 98 px against an `attack_range` of 80, which `verify_hit_areas` checks. D519 asks for this: the hitbox is what is drawn.
- Shot `design/shots/jackal_pack/pack_dunes.png` (`UI/capture_jackal_pack.gd`): the hero steps into `DesertRoad Fight_Dunes`, the pack's first fight. Its log reads «spawned Enemy_Fight_Dunes_EnemySpawnPoint2 fast size small HP 127». Panel 1: the jackal runs in from the east next to the bandit, with its paws on the floor. Panel 2: the jackal leaps at the hero to bite. No visual defect was found. Panel 1 has a white strip on the right where the crop runs past the screen edge (an artefact of the capture, not the game).

## Notes for the orchestrator

- **Cursed foam on the fallback:** `kinds.jackal_cursed.foam` [15, 16] was set on the hyena's frames. Until `cloud/lab-curse` lands the cursed scene, a `BigSlot_JackalCursed_*` spawns `enemy_fast` with the foam, and the foam would now float near the pack jackal's chest; its mouth on idle is at about (27, −4). I did not touch it because `jackal_cursed` belongs to lab-curse. Once lab-curse merges the fallback is no longer used.
- **Merging:** `cloud/big-leader` and `cloud/lab-curse` also edit `verify_enemy_variety.gd`, but at the end of the file, while my [1b] is near the top, so the conflict should be textual only. Neither of them touches `enemy_fast.tscn`. If big-leader's [6] compares the leader's paws with «a medium jackal's line (28.5)», that is still true: 28.5.
