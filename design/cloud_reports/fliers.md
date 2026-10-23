---
type: cloud-report
branch: cloud/fliers
date: 2026-10-23
tags: [enemies, combat, cloud]
---
# Cloud report: fliers ([[flying_enemies_plan]] slices 1 and 2)

**Summary**
- **Done:** a flying mode on the existing enemy (`DefaultEnemy` + `FlyingLogic extends EnemyLogic`, chosen by `EnemyStats.flying`); the **vulture** (circles out of reach, red tell, a dive along a locked line, hittable only while low, climbs back) and the **bat** (wavy approach, white-tell bite, backs off); stats in `.tres`, scenes, bestiary entries in `en.po` / `uk.po`, `verify_flying_enemies` (all pass) and a capture of the dive.
- **Placed:** two vultures, both on the Desert Road: a lone one between the lone shield-bearer and the Dunes, and one joining the Caravan fight as its last wave. **No bats placed** (no cave room; D589).
- **Not done:** no vulture in the Canyon (a story room: meditation, bridge collapse) or at the City Gates (the story raid, "3 bandits" is tested and scripted); the bat's and vulture's motion is the D637 art as generated.
- **D-ID text:** D638–D641 below (next free numbers after D637; renumber if another routine took them).
- **B rows fixed:** none. **New B row proposed:** the block lesson still says "red glint → parry" (see the end).
- **Full suite:** SUITE_LINE

## D-ID text (for the register)

| ID | Type | Text |
|---|---|---|
| D638 | ROUTINE CALL | **Flying enemies, as built** (D445, D558; `cloud/fliers`). One enemy system: `EnemyStats.flying` makes `DefaultEnemy._make_logic` return `FlyingLogic` (`Scripts/Gameplay/Components/FlyingLogic.gd`, extends `EnemyLogic`: the same tell, attack token, stagger, knockback, poise). A flier has no gravity (`CharacterBody2D.MOTION_MODE_FLOATING`, `DefaultEnemy._fly`) and no ledge checks: it patrols around its spawn point (±60 px, bobbing ±6) and chases in the air. **Its body is not an obstacle** (`collision_layer = 0`, collision exceptions with the hero and every enemy): the hero walks and rolls under it and ground enemies pass beneath; it stops only at walls and floors. This amends D443 for fliers, which are in the air. Shapes as D519: hurtbox = the `fly` frames (idle and walk both play them), hitbox = the frames shown while it is live. A dead flier falls to the ground under it (`_fall_dead`, 0.45 s). Spawn points for fliers are placed in the air. The art is scaled by the drawn size against the hero (24×40 body): vulture ×1.0 (59×59 px), bat ×0.75 (28.5×31.5 px); the other enemies are ×1.5. |
| D639 | ROUTINE CALL | **The vulture** (D445, D558, D573; numbers provisional, Q74). Circles over the hero at `hover_height` 150 px above his feet, ±110 px side to side, out of any weapon's reach, and **cannot be hit there**: its hurtbox is off, `hurt_rect()` is empty, and `take_damage` with a source does nothing, so blows, arrows and skills all miss (a burn still ticks). When ready and within 160 px (`attack_range`) it winds up for 0.6 s, drifting back and up; at `TELL_LEAD` before the dive its beak glints **red** (dodge, with the `tell_dodge` sound) and the line locks on the spot where the hero is at that instant. It dives along that straight line at 450 px/s (`dive_speed`), skims on low for 0.3 s at 60 %, holds its recovery pose 0.45 s while gliding slowly, then climbs back to the circle. It is **hittable from the first frame of the dive until it has climbed 60 px above the bottom of the dive** (`FlyingLogic.low`). The roll's i-frames take the hero under it (D443). Stats: the jackal's (HP 60, damage 14, speed 120, poise 2, XP 25, recovery 0.45, cooldown 1.5) with a 0.6-s wind-up; 1–3 coins. |
| D640 | ROUTINE CALL | **The bat, and its reuse** (D445, D558, D589; provisional, Q74). Flutters toward the hero in a wavy line (±18 px) at 40 px over his feet, head height, so a swing always reaches it. Waits beside him at `attack_range + 40`; when ready and a token is free it closes to 50 px, winds up 0.55 s, glints **white** (block) and bites with a 40-px dart along the line locked at the tell, then backs off 90 px away and up, and comes again. Half the jackal's HP (30) and damage (7), poise 1, XP 12, 0–1 coins. Bats come in twos and threes in caves (D558), and the attack token (2 attackers) still applies. **No bat is placed in the demo**: there is no cave room, and the Laboratory gets the Cthulhu flies (D589). A new flying kind needs its own sheet scene (`enemy_<kind>.tscn` as an instance of `default_enemy.tscn` with `idle` / `walk` / `attack` / `death` / `stagger`) and `enemy_stats_<kind>.tres` with `flying = true` and `flight_attack = "bite"` (or `"dive"`); then one line each in `EnemySpawnPoint` (enum, scene), the coin table, `enemy_voice_pitch` and `bestiary.json`. |
| D641 | ROUTINE CALL | **Where the vultures are** (D558, D582). Desert Road only: **`Fight_LoneVulture`**: one medium, never-elite vulture alone (spawn 1900, 210; zone at x 1810), after the lone shield-bearer (1760) and before the Dunes zone (2170). The hero meets it after he has learnt the shield-bearer, on open ground, before any mixed fight. **`Fight_Caravan`**: a vulture joins the Caravan's ground fight (tank, jackal, shield-bearer, scorpion) as the last wave (spawn 3760, 220), so this optional fight guarding the bandit key is the hard crowd. No vulture in the Canyon (a story room: shrine, bridge collapse, descent) or at the City Gates (the scripted story raid); both stay open for the world rework. No bats anywhere. |

## Details

### Code
- `Scripts/Gameplay/Characters/Enemies/EnemyStats.gd:40` group *Flight*: `flying`, `flight_attack` (`dive` / `bite`), `hover_height`, `dive_speed`.
- `Scripts/Gameplay/Components/FlyingLogic.gd` (new, preloaded, no `class_name`):
  - `process_ai` replaces the ground handlers;
  - `_patrol`, `_chase` → `_station` (vulture orbit / bat side spot with the wave) → `_in_reach`;
  - `perform_attack` reuses `wind_up`, the token and the signals; the target follows the hero until the tell, then locks (`_attack_velocity`);
  - `_dive`; `_track_low` (the low window); `_retreat` (the bat); `_home` (6-s timeout → new home).
- `Scripts/Gameplay/DefaultEnemy.gd`:
  - flight fields from stats; `_ready` sets layer 0 and the floating mode;
  - `_make_logic` picks `FLYING_LOGIC`;
  - `_physics_process` → `_fly` (full 2D velocity, hurtbox `monitorable` = `reachable()`); `_ignore_bodies` / `_other_bodies`; `reachable()`;
  - `hurt_rect()` is empty while unreachable; `take_damage` returns early while unreachable;
  - `_fall_dead` on death; coins for `vulture` / `bat`.
- `Scripts/Gameplay/EnemySpawnPoint.gd`: `vulture` and `bat` in the enum, scenes and editor colours.
- `Resources/Enemies/enemy_stats_vulture.tres`, `enemy_stats_bat.tres`; `Scenes/Characters/Enemies/enemy_vulture.tscn`, `enemy_bat.tscn` (sheet 4×4: row 0 `fly` → idle 0.15 s / walk 0.1 s per frame; row 1 → `attack`, strike at 0.6 s (vulture, frame 6) / 0.4 s (bat, frame 5); row 2 → `stagger` (hurt frame); row 3 → `death`).
- Hit shapes (HitAreas, D519): vulture hurtbox and hitbox (−27, −29) 59×59 (the whole bird hits in the dive); bat hurtbox (−16.5, −18.75) 28.5×31.5, bite hitbox from the centre forward (0, −16.5) 12×29.25. `tell_at`: vulture (18, 2), bat (8, −8).
- `Resources/Data/bestiary.json`: *Vulture*, *Cave Bat* (en + uk in the `.po` files). `sound_events.json` `enemy_voice_pitch`: vulture 0.85, bat 1.6.
- `Maps/DesertRoad.tscn`: `Fight_LoneVulture` (new spawner, `enemies_lonevulture`, respawns); `Fight_Caravan/EnemySpawnPoint6` (vulture).

### Tests
- `verify_flying_enemies` (new): **RESULT: ALL PASS**, 48 checks:
  - [1] shapes from the frames, the stats;
  - [2] both patrol at their height (drift 5.4 px), chase, and never touch the floor (lowest feet y 380 / 370, floor 384);
  - [3] circling 147 px over the hero: no hurtbox, `take_damage` ignored, a real swing misses; the same swing hits a low vulture (60 → 30);
  - [4] the standing hero is hit for 14 after a red tell 785 ms earlier, along one line (off by 0.00 px), then it climbs out of reach;
  - [5] a roll as it comes down: no damage;
  - [6] the bat bites for 7 after a white tell, waves 12 px, backs off 23 → 144 px and comes again;
  - [7] the bandit scene with the bat's stats flies and bites (reuse), a dead vulture falls to y 384, the kill counts, the bestiary and both `.po` files have the entries;
  - [8] vultures only outdoors (two, both on the Desert Road), the lone one first, the Caravan's last, the lone zone 250 / 270 px from its neighbours, no bats.
- Changed for the new placements: `verify_enemy_variety` (Caravan has 5, Desert Road has 7 fights): ALL PASS. `verify_road_sections` (Caravan 5, the floor check skips fliers): ALL PASS.
- Full suite: SUITE_DETAIL

### Capture
`design/shots/flying_enemies/vulture_dive.png` (`UI/capture_flying_enemies.gd`), real Desert Road, four panels:
1. circling over the hero;
2. the wind-up with the red glint on the beak;
3. the dive along the line;
4. skimming low past the hero (he is made invulnerable for this panel only, so the block lesson banner does not cover it).

It matches the intent. The dive frames keep the flying pose, as D637 accepted.

### Proposed B row (not fixed, outside this task)
The block lesson (`tutorial.json:102`, `en.po:2496`) still says "When an enemy's weapon glints red, press {block} — that is a parry". Since D573 / D574, red means dodge and yellow means parry. Seen in the capture when a vulture's hit triggered the lesson.
