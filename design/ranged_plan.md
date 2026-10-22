---
type: plan
status: active
tags: [combat, ranged, enemies]
---

# Ranged weapons — the hero's bow and the desert archer — plan (BACKLOG 40)

Sapega «стрільба з лука має бути як в грі Skul» (Q35, confirmed): the bow plays like **Skul: The Hero Slayer** —
quick shots on the attack button, arrows that fly straight, hold to charge a stronger shot. Builds on
[[souls_combat_plan]] (D264–D270: hit feel, block / parry, grips D267, sheathing D268) and
[[hero_weapon_animation_plan]] (weapon libraries on the hero's `AnimationPlayer`, D370). Figma: none (combat is not a
UI screen). Art: batch **A4** (commit `87c56f92`, laptop) — `Sprites/Player/Weapons/bow/`, `Assets/FX/Projectiles/`,
`Assets/Characters/Enemies/bandit_archer/sheet.png`. The old ranged stubs (`EnemyRanged.gd`,
`player_projectile.tscn`) were deleted in BACKLOG 39 (D337), so this is built fresh.

## What exists today (how checked)

| Thing | Where | State |
|---|---|---|
| A `bow` equipment slot and inventory slot rule | `EquipmentManager.WEAPON_SLOTS`, `InventorySlotRules.default_slot` | ✅ slot only — `grep '"bow"' items.json` → 0 items |
| Grip types | `EquipmentManager.get_grip()` → bare / one_handed / two_handed / dual (D267) | ❌ no ranged grip |
| Hero bow frames 96×96 (Draw 3, Shoot 2, Charged 2, Run 6) | `Sprites/Player/Weapons/bow/` | ✅ art, not wired |
| Arrows 28×9, charged 36×13 | `Assets/FX/Projectiles/arrow*.png` | ✅ art, not wired |
| Archer sheet 4×5 of 64×64 (idle, walk, draw → release, hurt, death) | `Assets/Characters/Enemies/bandit_archer/sheet.png` | ✅ art, not wired |
| A straight projectile hitting the hero through `Player.take_damage` (block / parry / roll work) | `Bosses/Hazards/BossFireball.gd` (D302) | ✅ pattern to follow |
| Enemy tell — red glint `PARRY_WINDOW` before the strike | `EnemyLogic.wind_up` → `EnemyView.show_tell` (4b) | ✅ reused as is |
| Hit feel (cut, hitstop, kick, flinch, rumble) | `VFXHooks._on_damage_dealt` — only for sources in the `player` / `companions` groups | ⚠️ arrows need to count |
| Player projectiles, ranged enemy AI | `grep -rn "Projectile\|ranged" Scripts/` → 0 (besides the boss fireball) | ❌ |

## Decisions (agent calls, Sapega to confirm) — D380–D387

1. **D380 — the bow plays like Skul.** The attack button **fires a quick shot on the press** (no wait for the
   release: the tap must feel instant); an arrow every `weapon_profile.cooldown` (0.3 s) while tapping. **Holding**
   the button past the shot draws the bow (`Draw` 0.6 s), then it is **charged** (`Charged` loop, the arrowhead glows);
   releasing a charged bow looses the **charged shot**. Releasing before the charge is full lowers the bow without a
   second arrow. The heavy button with a bow **draws at once** (no quick arrow first) — the same charged shot.
   Arrows fly **straight along the facing**, horizontally, from the nocked arrowhead in the frame (no auto-aim, no
   gravity) — Skul's Hunter / archer skulls.
2. **D381 — numbers.** Quick arrow: ×0.7 physical attack (`hit_damage()`), 900 px/s, light poise (1), the 8 px nudge,
   light hit feel. Charged arrow: ×1.8, 1200 px/s, heavy poise (3), knockback 60 px, heavy hit feel, **pierces**
   enemies (each one once) — Skul's charged shot goes through. Both stop on a wall (stick for 0.6 s, then fade) or
   after 720 px. The bow: `short_bow`, attack +12, cooldown 0.3.
3. **D382 — movement.** Quick shots do not stop the hero (like light swings, D223), on the ground and in the air.
   Drawing / holding a charge roots him (`locks_movement`), the dodge cancels the draw (roll out of danger, Skul's
   dash-cancel), an enemy hit staggers him out of it (D264).
4. **D383 — grip `bow` next to D267.** `items.json` → `"grip": "bow"`; `EquipmentManager.get_grip()` → `&"bow"`:
   both hands on the bow, so no Shield Block passive (like two-handed) and never dual-wield. The hero's melee hitbox
   is not used.
5. **D384 — heavy / block with the bow.** Heavy = the charged draw (D380). **Block and parry work as with any
   weapon** (the base `Block` frame — the A4 set has no bow block pose, B110); a parried **arrow** is **deflected**
   back as the hero's quick arrow (it then hits the archer), a blocked arrow breaks on the guard (0 damage, D264),
   a roll lets it fly through (i-frames), a jump clears it (it flies at chest height).
6. **D385 — bow frames.** A library `bow` on the hero's `AnimationPlayer` (D370's switch, keyed by the item
   `category`), 96×96 cells, offset (0, −16) like the sword: `Idle` = `Shoot/2` (bow lowered at the hip — the combat
   stance), `Run` = `Run/1–6`, `Attack1` = the quick shot (`Draw/3` → `Shoot/1` release → `Shoot/2`), `Draw` =
   `Draw/1–3`, `Charged` = `Charged/1–2` loop, `Release` = `Shoot/1–2`. The bow has **no** overlay sprite
   (`WeaponView` hides it for `bow`); jump / fall / block / hurt / roll show the base frames without the bow (B110).
7. **D386 — the desert archer.** `enemy_archer.tscn` (inherits `default_enemy.tscn`, `ArcherEnemy` + `ArcherLogic`,
   `enemy_stats_archer.tres`): HP 60, damage 12, speed 60, poise 2, XP 25, coins 1–3. **Keeps distance:** closer than
   170 px it backs away (until its leash / a wall), from 170 to 380 px it stops and shoots, farther it closes in. It
   shoots only when the hero is at its height (±48 px) — arrows fly straight. Every shot: a 0.9 s draw (`attack`
   frames 8 → 10) with the **red glint on the arrowhead** `PARRY_WINDOW` (0.25 s) before the release (frame 11) —
   the same tell as every enemy (4b); arrow 420 px/s, 2.2 s between shots. Its arrow hits the hero through
   `Player.take_damage` with the arrow as the source: block, parry (D384), roll and jump all work; a hit staggers like
   a melee hit (0.25 s). Coins and voice pitch (1.05) like the others; Bestiary entry "Desert Archer" (D290).
8. **D387 — placement and how the bow is found.** One archer replaces the last **fast** on the DesertRoad
   **Mesa** fight (`Fight_Mesa/EnemySpawnPoint4`, the far end of the high ground — it shoots across the mesa), one
   replaces the third bandit of the **City Gates** raid (`EnemySpawner/EnemySpawnPoint3`; its raid-cutscene figure is
   drawn from the archer sheet). XP stays on the D297 curve: the archer gives 25 (= the fast it replaces on the road;
   the gates total 625 + 30 + 30 + 25 = 710 → level 5 on the last gate kill, `verify_xp_curve`). The `short_bow` is
   sold by the caravan merchant in the City (`merchants.json` → `city_merchant`) — weapons other than swords are
   not sold anywhere yet, the bow is the first.

## Slices

1. **Bow item, grip, frames** — `items.json`, `EquipmentManager.get_grip`, `Player.tscn` library `bow`,
   `WeaponView` (no overlay, library for grip `bow`). Check: `verify_bow` [0]–[1].
2. **Shots** — `PlayerCombat` states `SHOOT`, `DRAW`, `CHARGED`; `Player._unhandled_input` tracks the held
   attack / heavy buttons, dodge cancels the draw; `Scenes/Combat/arrow.tscn` + `Scripts/Combat/Arrow.gd`;
   hit feel through `VFXHooks` (group `hero_arrows`, strength from the arrow); sounds `bow_shot`, `bow_shot_charged`,
   `bow_draw`, `arrow_wall` (existing files). Check: `verify_bow` [2]–[6] with real mouse and pad events.
3. **Archer** — `ArcherEnemy.gd`, `ArcherLogic.gd`, `enemy_archer.tscn`, `enemy_stats_archer.tres`,
   `EnemySpawnPoint` type `archer`, bestiary, coins, voice pitch. Check: `verify_archer` [0]–[5] (keeps distance,
   tell then shot, block / parry / roll / jump an arrow, with real key and pad events).
4. **Placement** — DesertRoad Mesa, City Gates (D387), `verify_xp_curve`, `verify_road_sections`,
   `verify_city_gates_raid` stay green.
5. **Translations** — item name / description, bestiary name / text in `uk.po` (+ `en.po` via `po_sync.py`).

## Left for later

- Bow frames for jump / fall / block / hurt (A-batch on the laptop) — **B110**.
- Aiming up / down (Skul has none for the basic shot; skills could add a volley later — BACKLOG 21 style).
- Arrow pickups / ammo — none (Skul has unlimited arrows); a quiver upgrade is a skill-tree idea.
- Archer frames for a melee kick when the hero is point-blank — it just keeps shooting today.
