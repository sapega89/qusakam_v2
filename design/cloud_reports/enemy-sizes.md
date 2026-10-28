---
type: report
tags: [cloud, routines, enemies, scale]
---

# enemy-sizes — B187 / A10 by scaling

- **Done:** `enemy_variety.json` `kinds.<kind>.scale` (every kind has one; no default in code) is multiplied into `grow` in `DefaultEnemy._apply_variety` before size and `elite.scale`. Ordinary adult humans now draw **144 world px** (bandit, shield-bearer, archer). The elites brute, tower guard and heavy archer stand on the same 144 base, then get ×1.5 on top (**216**). Beasts are unchanged.
- **D-ID text (for the register; the next free number, D862 if nobody took it):** *ROUTINE CALL (`cloud/enemy-sizes`, Sapega 28.10 «ти ж сам можеш підправити розміри»; D814, D816, D859).* **Enemy sizes are fixed by scale, not by redraw.** Every kind in `enemy_variety.json` has a base `scale`, applied from the feet before its size class and `elite.scale`, through the same `_grow` that already scales the sprite, body, hit and hurt areas, reach and lunge (B128). Result: every adult human enemy's idle figure is the chart's 96 art = 144 world px. Bandit and shield-bearer ×1.96 (73.5 → 144). Archer and heavy archer ×1.0: their sheets were already 144. Brute ×1.46 (98.9 → 144). Tower shield guard ×1.48 (97.2 → 144). Elites then grow ×1.5 on top (D859), to 216. Beasts (jackals, scorpions, vultures, bats, the fly) have no chart row (`world_scale.json` monster: null) and stay ×1.0. With this, A10 leaves the art queue; the bandit's look stays a BACKLOG item.
- **B rows fixed:** **B187** (sizes; the art regeneration is no longer needed). **B203**: a grown enemy's `attack_range` no longer outruns its strike. It is needed here because the brute at ×1.46×1.5 would start a swing 0.6 px out of reach; the tower guard was already 4 px out of reach before this change. Now checked for every grown kind (`verify_hit_areas` [1b]).
- **Not done / for Sapega:** the chart (`world_scale.json`) has no elite row. D814 says 120 art (×1.25), but D859 made it ×1.5, so the probe flags the three human elites as `too big ×1.5`. They are right by D859. **Proposed:** an `elite_human` row at 144 art = 216 world px. I did not edit the chart (that is a design call).
- **Tests:** verify_hit_areas, verify_enemy_variety, verify_combat_enemies, verify_enemy_scaling, verify_enemy_stamina, verify_scripts_compile: ALL PASS. verify_archer: 5 FAIL, the same 5 on feature/backlog (pre-existing). verify_difficulty: 17 FAIL, identical row for row before and after (it adds up hits and blows, not body size).
- **Full suite:** running (this line is updated when it ends).

## Details

### Code
- `SampleProject/Resources/Data/enemy_variety.json`: `"scale"` on every kind, plus the explanation in `kinds._note`.
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd:242`: `grow = kind.scale * mult.scale`; elites then `*= elite.scale` as before.
- `DefaultEnemy.gd:288` `_strike_front()`, `:295` `_grown_range()` (B203): the grown range is `min(range × f, range + (hitbox front + lunge) × (f − 1))` for f > 1. It still grows with the enemy, but never further than its hitbox and lunge grew. The hero's half-width (12), which a strike must reach, does not grow, so a strike that reaches in the scene also reaches when grown. Fliers dive from a distance and archers shoot, so their range just scales (`ArcherEnemy.gd:26` overrides it). Effect on the existing kinds at medium: jackals, the fly and the bat are unchanged. Armoured scorpion 117 → 114.2. Brute 125.9 → 119.1. Tower guard 106.6 → 93.4. Bandit and shield-bearer: 73.1 (it would be 78.4 by plain ×1.96).
- `SampleProject/Scripts/Gameplay/EnemyVariety.gd`: doc line.

### Tests changed
- `verify_hit_areas.gd:148` `[1b]`: every melee kind, small and medium, spawned and grown: `attack_range` is between body contact and hitbox front + lunge + 12. All 16 OK.
- `verify_enemy_variety.gd:141`: the medium base's reach grows with the kind (no longer the `.tres` value). The small size is checked as shorter than medium; the reach rule itself lives in verify_hit_areas.
- `verify_enemy_variety.gd:785`: the brute's drawn feet vs the bandit's line: tolerance 1.0 → 1.5 world px (the chart's ±1 art px). Both grow from the body's feet, and half an art pixel of the brute's sheet (now 2.5 world px per art px) stays: 14.9 vs 16.0.

### Measured heights (idle frames, world px; `capture_enemy_sizes.gd` prints them)
| kind | before | scale | after (medium) |
|---|---|---|---|
| melee (bandit) | 73.5 | 1.96 | 144.1 |
| shield | 73.5 | 1.96 | 144.1 |
| archer | 144.0 | 1.0 | 144.0 |
| bandit_brute (elite) | 148.3 (98.9 × 1.5) | 1.46 | 216.6 |
| tower_shield_guard (elite) | 145.8 (97.2 × 1.5) | 1.48 | 215.8 |
| heavy_archer (elite) | 216.0 | 1.0 | 216.0 |
| fast 68.4, jackal_pack_leader 109.2, jackal_cursed 108.8, tank 51.8, armoured_scorpion 138.8, vulture 73.8, old_vulture 139.5, bat 42.0, fly 141.8 | — | 1.0 | unchanged (no chart row) |

The small size class stays ×0.8 (a small bandit is 115 px).

### Ceilings and doors (`SampleProject/UI/probe_enemy_headroom.gd`, new, headless)
Every spawn point in BanditCamp, CityGates, DesertRoad, GatehouseCellar, Laboratory, LizardCave, MesaClimb and Village was checked with its kind spawned and settled on the floor:
- **Gap to the ceiling** (rays up from the top of the drawn body): the tightest human is DesertRoad's first-fight bandit at **67 px** (open sky before; the body is now 138 px wide and reaches under an overhang). Laboratory brutes: 171 → **102**. Laboratory tower guard: 237 → **167**. CityGates and Laboratory bandits: 309 → 237. MesaClimb vulture: 3 px, unchanged and pre-existing (a flier at its spawn).
- **Walk ±400 px** (rays up from the feet line to the drawn height; a hit above the body's 32 px means the body would pass under it while the drawing cuts into it): no ground kind hits anything. The only hit is the MesaClimb vulture, measured from mid-air.
- Doors: an ordinary door is 168 px (chart). Ordinary humans (144) fit under it. Elites (216) are taller than a door, but they spawn only in BigSlot fight arenas, and the walk scan finds no lintel there.

### verify_difficulty
Before and after: `RESULT: 17 FAIL`, 119 OK, an identical diff. The script models hits-to-kill and blows taken, not hit-area size, so no green row is lost. In play, a bigger hurt area is easier for the hero to hit, and the bandit's reach also grows (73 vs 40 px start range). The B203 cap keeps that reach honest. Its 17 fails are pre-existing (elites-bigger saw 5 of them on 28.10; more have appeared on feature/backlog since).

### Shots
- `design/shots/enemy_sizes.png`: before | after, three rows (humans, beasts, fliers), each next to Kusakam at camera zoom 1 (1 px = 1 world px). Sources: `design/shots/enemy_sizes/before.png`, `after.png`. The capture now zooms to 1:1 and prints the idle heights.
- `design/shots/scale_chart.png`, `design/shots/scale/probe.json`, `tables.md` and the grids of the eight enemy rooms: redrawn (`probe_world_scale.gd`, `Scripts/Tools/scale_chart.py`). Bandit, shield and archer read `ok`. The three human elites read `too big ×1.5` (see the chart question above).
