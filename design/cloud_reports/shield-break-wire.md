---
type: report
tags: [cloud, combat, enemies]
---

# shield-break-wire — the tower shield breaks for good (B200, D843)

**Summary.** Done: when the hero breaks the tower-shield guard's shield, it bursts into shards
(`FX/Hit/shield_break_1–4`) where the shield was drawn, the guard fights on with `shield_tower/sheet_noshield.png`, and
the shield never comes back (`_raise_shield` is gone). His hurtbox, hitbox and blocking body are re-fitted from the
shieldless frames (B128) and his `attack_range` drops by as much as his strike got shorter. The ordinary
shield-bearer is unchanged (its Polygon2D shield still flies off, `verify_enemy_variety` [4]). Not done: nothing.
**B rows fixed:** B200 (the tower guard half; the shield-bearer half was already working). **D843** as in the register
(text below), now built. **Full suite:** SUITE_LINE

## D-ID text (for the register; D843 is already there, append "Built")
| D843 | OVERRIDE (Sapega 28.10 via B200, amends D711) | **A broken tower shield stays broken.** «бо не малювали без щита? але ми ж розбиваємо щит»: when the hero breaks the tower-shield guard's shield, it bursts into shards (`FX/Hit/shield_break_1–4`) and the guard fights on with the shieldless sheet (`shield_tower/sheet_noshield.png`, `f393435d`); `_raise_shield` no longer restores it (D711 had him raise it again). The ordinary shield-bearer already loses its Polygon2D shield (`break_shield`). **Built** in `cloud/shield-break-wire` (report `design/cloud_reports/shield-break-wire.md`): the shards are `Scenes/FX/ShieldBreak.tscn` (12 fps, z 250), placed on the guard's cell at rest and mirrored with his facing; after the break his hurtbox, hitbox and blocking body are measured from the shieldless frames (B128), and `attack_range` drops by as much as his strike got shorter (scene numbers: 48 → 45.6; the body's front edge 33.6 → 22.8 px). |

## B rows
- **B200** → fixed for the tower guard (this branch). The shield-bearer half needed nothing: `ShieldBearer.break_shield`
  flies the Polygon2D shield off (still green in `verify_enemy_variety` [4]).
- **New, proposed (not fixed, outside the brief):** a *grown* elite's `attack_range` can start a strike that does not
  reach. `DefaultEnemy._grow` scales `attack_range` and the hitbox by the growth factor, but the hero's half-width (12)
  does not grow. The level-2 tower guard (×1.25): `attack_range` 60, reach 46.5 + 12 = 58.5, so he begins a thrust
  1.5 px out of reach (with or without the shield). `verify_hit_areas` checks only the ungrown scenes. Suggest
  checking every grown elite in `verify_hit_areas` and growing `attack_range` from the hitbox front instead.

## What changed
- `Scripts/Gameplay/Characters/Enemies/TowerShieldGuard.gd` — `break_shield` (no stagger-end timer any more):
  `_drop_shield` swaps the sheet, re-fits `Hurtbox`/`hitbox`/body with `HitAreas` on a still copy of the sprite and
  updates `_hurt_x`/`_strike_x`, `attack_range` (and `enemy_logic.attack_range`); `_burst` spawns the shards;
  `_raise_shield` removed. New export `noshield_sheet`, set in the scene.
- `Scripts/Gameplay/Components/EnemyView.gd` — `swap_sheet(sheet)`: `EnemyView` caches the sheet in `_sheet` and
  `end_stagger()` puts it back, so a bare `Sprite2D.texture` swap was undone when his break stagger ended (this is the
  "texture reset" the brief warned of; his own animation library replaces default_enemy's and keys only
  `Sprite2D:frame`, checked by the test). `rest_sprite()`: a copy of the sprite without the flinch squash / lean /
  hop, because a heavy hit leans the sprite (`offset.x` 1.4 px at the break) and `HitAreas` measures from
  `scale`/`offset` — measured on the live sprite the shapes came out up to 2 px off.
- `Scenes/Characters/Enemies/enemy_tower_shield_guard.tscn` — `noshield_sheet = shield_tower/sheet_noshield.png`.
- `Scenes/FX/ShieldBreak.tscn` — new: `AnimatedSprite2D`, the four 96×96 frames at 12 fps, not looping, z 250,
  nearest filter. The guard frees it on `animation_finished`. The canvas is the guard's cell, so it takes his sprite's
  rest transform (scene ×1.2, times elite growth), offset (0, −13) and `flip_h`; it stays in the room when he moves.
- `Assets/FX/README.md` — the shield_break row says where it is wired.
- `UI/capture_shield_break.gd` — new capture (same spot as `capture_tower_guard`, read-only use of DesertRoad).

## Shapes (scene scale; the elite grows them ×1.25 at level 2)
| | with shield | without |
|---|---|---|
| hurtbox (drawn idle + walk) | x −25.2 … 33.6, y −81.7 … 15.5 | x −25.2 … 22.8, y −76.9 … 15.5 |
| hitbox (attack frame 9) | x 0 … 37.2 | x 0 … 34.8 |
| blocking body (centred, front = drawn front) | 67.2 wide | 45.6 wide |
| attack_range | 48 | 45.6 (body contact 34.8, reach 46.8) |

## Tests
- `verify_enemy_variety` [8], new checks after the heavy hit: the sprite is the shieldless sheet; one shard burst
  (4 frames, `shield_break_1.png` first) on his rest cell, mirrored (he faces left); no animation of his keys
  `Sprite2D:texture`; hurtbox = shieldless body, hitbox = shieldless strike, body front = his front; `attack_range`
  60 → 57 (as much as the reach 46.5 → 43.5) and past body contact; after the stagger `shield_up` stays false and the
  sheet stays shieldless; the shards are freed; a light front hit still lands (no block); playing walk / attack /
  stagger / idle keeps the sheet. The old checks «the shield stays in his hands», «he raises the shield again» and
  «blocked again» are replaced (D843 overrides D711). `RESULT: ALL PASS`.
- `verify_hit_areas` PASS, `verify_combat_enemies` PASS, `verify_scripts_compile` PASS.
- `ERROR: Parent node is busy setting up children` at the end of `verify_enemy_variety` is pre-existing (same on
  `origin/feature/backlog` without this change).
- Full suite: SUITE_DETAIL

## Shot
`design/shots/shield_break.png` (xvfb, level-2 elite on DesertRoad where the lone shield-bearer stands): top — he
walks in behind the tower shield; middle — the break, shard frame 1 over his hurt pose with the block sparks;
bottom — after the stagger he walks on with the sword and an empty hand. Matches D843; the shards' frame 1 sits where
the shield is drawn in idle (FX/README: centre (48, 40)), so over the recoil pose it overlaps his body for 1/12 s —
read as the shield cracking off him, no B row.
