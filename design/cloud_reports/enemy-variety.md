---
type: cloud-report
branch: cloud/enemy-variety
date: 2026-10-23
tags: [cloud, combat, enemies]
---

# Cloud report: enemy-variety (pillar 1: sizes, elites, the shield-bearer)

**Summary.** Built: three sizes (×0.8 / ×1.0 / ×1.3) that scale the sprite, the D519 shapes and the stats from
`enemy_variety.json`. Elites roll 1 in 8, seeded by room and spawn point, with HP ×2.5, damage ×1.5, a gold outline
glow and ×1.1 size. The shield-bearer (a bandit kind, `shield`) blocks hits from the front with sparks and a clank. A
heavy attack breaks the shield: it flies off, he staggers 1.2 s in the bandit's stagger frames, then fights
shieldless. Placed per D582 (the full list is below). New `verify_enemy_variety` (ALL PASS) and the capture
`design/shots/enemy_variety/shield_fight.png`. **Not built:** the plan's elite name plate, signature move and better
drop; the shared guard bar and the scorpion's armour; real shield-bearer art (the shield is a placeholder).
D-IDs: **D603–D617** (text below). B rows fixed: none. Full suite: 102 PASS, 1 FAIL (`verify_onboarding`, which fails on the base branch too)

## D-ID text (for the register; the next free numbers after D602)

| ID | Kind | Text |
|---|---|---|
| D614 | ROUTINE CALL | **Enemy sizes, as built** (D560; `cloud/enemy-variety`). Numbers live in `Resources/Data/enemy_variety.json` (`sizes`): small ×0.8 scale, HP ×0.7, damage ×0.8, speed ×1.15; medium ×1; large ×1.3 scale, HP ×1.8, damage ×1.3, speed ×0.85 (the plan's HP defaults; the damage and speed factors are agent calls). **XP does not scale** (`xp` 1.0). The D297 curve puts level 5 on the last City Gates kill with only 15 XP to spare (D280), and seeded sizes would move it. `DefaultEnemy._grow` scales the sprite, the blocking body, the hitbox and the hurtbox from the feet line, so a big one stands on the same floor and what you see still hits (D519). `attack_range` and `lunge` scale with the hitbox. The scene's shared body shape is copied first. The spawn point's `size` is `auto` by default: a seeded roll with weights small 1 : medium 2 : large 1 in ordinary fights (`RoomEnemySpawner.respawns`), and medium in story fights. A point can pin its size. |
| D615 | ROUTINE CALL | **Elites, as built** (D560; `cloud/enemy-variety`). `enemy_variety.json` `elite`: chance 0.125, HP ×2.5, damage ×1.5, scale ×1.1, XP ×1 (no bonus, to keep the D297 curve; the plan's double XP is dropped). Multipliers stack with size, so a large elite bandit has 100 × 1.8 × 2.5 = 450 HP. The roll is seeded by `<MetSys room>/<spawn_id>` (`EnemyVariety.roll_elite`), so a room gives the same elites on every visit and every D492 respawn. The marker is a thin outline (`Shaders/elite_outline.gdshader`, colour `#ffcf5a`, alpha breathing 0.45–0.85) and the slightly larger body. It needs no new art, and the cursed Laboratory art (D589) replaces it later for those kinds. Rolls happen only where the spawner has `elite_rolls` on (the three Laboratory fights). A spawn point can pin `elite = always/never`. **Not built from the plan:** the gold name plate and epithet, the signature move per kind, the guaranteed drop, and the double XP. |
| D616 | ROUTINE CALL | **The shield-bearer, as built** (D495, D560; `cloud/enemy-variety`). A new kind `shield` (`enemy_shield.tscn`, `ShieldBearer.gd`, `enemy_stats_shield.tres`) is the bandit with a round shield held to the front. Stats: HP 110, damage 22, speed 55, wind-up 0.8 s, one swing per series, poise 4, XP 30 (a bandit's, so swapping one in keeps the XP curve), coins 3–5. A hit from the side he faces is blocked: no HP loss, no poise loss, small sparks on the shield and the `block` clank. A hit in the back (after a roll through him, D443) lands as usual. A hit of strength 2 from the front breaks the shield: the hero's heavy attack, the riposte or a charged arrow (`VFXHooks.hit_strength`). The breaking blow does no HP damage. The shield flies off and fades, with big sparks, hitstop, a camera kick and `hit_heavy` + `hit_armour`. He staggers `guard_break_stagger` 1.2 s in the bandit's existing `stagger.png` frames and then fights shieldless. Burn ticks have no source and go past the shield. The shield is **placeholder art**: three `Polygon2D` discs under `Sprite2D/Shield`, brass rim and leather face. A comfy-sprite shield-bearer sheet (plan slice 3) replaces it. There is no guard bar: one heavy breaks it, per D560's «breaks to a heavy attack». The plan's shared guard bar and the scorpion's armour stay open. Bestiary «Shield Bandit» / «Бандит зі щитом» in `en.po`/`uk.po`. |
| D617 | ROUTINE CALL | **Where the new enemies stand (D582)** (`cloud/enemy-variety`). DesertRoad, left to right: the new `Fight_LoneShield` (one medium shield-bearer at x 1760, never elite, trigger at 1650, past the merchant) teaches the shield alone. Its bandit comes out of the **Dunes** (4 → 3: SP3 removed). The **Mesa** second wave becomes shield-bearer (2990) + archer behind (3070), the first pair. The **Caravan** (guards the ledge chest) gets a shield-bearer at 3880 in place of a bandit. It gives its SP2 bandit to the lone elite (5 → 4). Desert Road XP is unchanged at 595. The new `Fight_LoneElite` (one pinned elite bandit at 4480, medium, trigger at 4300) sits between the chest and `SavePoint_BeforeCity` and teaches the elite alone. The **Laboratory**: `elite_rolls` is on for Upper, Middle and Lower, and Lower (the group before the boss save point) gets a shield-bearer at 1350 in place of a bandit. No random elites on DesertRoad or in story fights, so the first elite is always the lone one. Both lone fights respawn (D492). |

## Placements (every one)

| Room | Fight | Point | Kind | Size | Elite | Why |
|---|---|---|---|---|---|---|
| DesertRoad | `Fight_Dunes` | SP3 (2410) removed | — | — | — | its bandit became the lone shield-bearer (XP-neutral) |
| DesertRoad | `Fight_LoneShield` (new, x 1650 trigger) | SP1 (1760, 368) | shield | medium (pinned) | never | first meeting, alone, on flat ground (D582) |
| DesertRoad | `Fight_Mesa` wave 2 | SP3 (2990, 304) | shield (was melee) | medium (roll) | no rolls | first pair: shield in front |
| DesertRoad | `Fight_Mesa` wave 2 | SP4 (3070, 304) | archer (unchanged) | large (roll) | no rolls | the archer behind |
| DesertRoad | `Fight_Caravan` | SP4 (3880, 368) | shield (was melee) | medium (roll) | no rolls | big group guarding `Chest_CaravanLedge` |
| DesertRoad | `Fight_Caravan` | SP2 (3720) removed | — | — | — | its bandit became the lone elite (XP-neutral) |
| DesertRoad | `Fight_LoneElite` (new, x 4300 trigger) | SP1 (4480, 368) | melee | medium (pinned) | always | first elite, alone, just before the save point |
| Laboratory | `Fight_Upper` | SP1 (1120, 368) | melee | medium | **elite** (roll) | — |
| Laboratory | `Fight_Lower` | SP2 (1350, 1328) | shield (was melee) | medium | no | big group before the boss |
| Laboratory | `Fight_Lower` | SP3 (1450, 1328) | fast | small | **elite** (roll) | — |

The seeded rolls, which are stable, from `verify_enemy_variety` [3]:
- **DesertRoad sizes:** Dunes: melee large, fast small, fast large. Mesa: tank small, fast medium,
  shield medium, archer large. Caravan: tank large, fast medium, shield medium, tank medium.
- **Laboratory:** Upper: melee medium **ELITE**, fast large, melee large. Middle: melee small, fast large, tank
  medium, fast large. Lower: tank large, shield medium, fast small **ELITE**, tank small.
- So the demo has three elites: the lone DesertRoad bandit, Upper's first bandit and Lower's jackal.

Floors were checked with a ray probe before placing (DesertRoad is flat at y 384 for x 100–1800 and 4300–5400).

## Files

- `SampleProject/Resources/Data/enemy_variety.json` holds the numbers. `SampleProject/Scripts/Gameplay/EnemyVariety.gd`
  loads them and makes the seeded rolls (preloaded, no `class_name`).
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd`: `size_kind` / `elite` / `xp_reward`. `_apply_variety` (:186) runs
  from `_ready` (:116) before the shapes are read. Also `_grow` (:209), `_mark_elite` (:222), XP from `xp_reward`, and
  coins for `shield`.
- `SampleProject/Scripts/Gameplay/RoomEnemySpawner.gd`: `elite_rolls` (:38). `_spawn` (:183) is shared by the instant
  and wave paths and sets the variant before the deferred `add_child`. Also `variant_size` (:194) and `variant_elite`
  (:200).
- `SampleProject/Scripts/Gameplay/EnemySpawnPoint.gd`: kind `shield`, plus the `size` and `elite` exports.
- `SampleProject/Scripts/Gameplay/Characters/Enemies/ShieldBearer.gd`: `take_damage` (:20), `take_poise` (:31) (a
  blocked hit costs no poise), `break_shield` (:44) and `_face_shapes` (:61) (the shield mirrors with facing).
- `SampleProject/Scenes/Characters/Enemies/enemy_shield.tscn` and
  `SampleProject/Resources/Enemies/enemy_stats_shield.tres`.
- `SampleProject/Shaders/elite_outline.gdshader`.
- `SampleProject/Scripts/Core/EventBus.gd:166,168` `enemy_shield_blocked` / `enemy_shield_broken`;
  `Scripts/Systems/VFXHooks.gd:177` `_on_shield`; `Scripts/Systems/SoundHooks.gd:22-25`.
- `bestiary.json` entry `shield`, `en.po` / `uk.po` (name and text), `sound_events.json` voice pitch `shield` 0.92.
- Maps: `SampleProject/Maps/DesertRoad.tscn` (two new fights, two kind swaps) and `SampleProject/Maps/Laboratory.tscn`
  (`elite_rolls`, one kind swap). `verify_road_sections` now counts 3 / 4 / 4 (Dunes, Mesa, Caravan).

## Fixes after the first full suite

- `verify_xp_curve` failed four times: the extra Desert Road enemies reached level 5 before City Gates. Fixed by making
  the changes XP-neutral (D614 to D617 above), so it is ALL PASS again.
- `verify_souls_combat` failed twice ("no fight: the sword is out of sight"). The test uses the strip east of the story
  fight as its arena, and the hero walked into the lone shield-bearer's trigger, which spawned a live enemy. The test
  now switches off section-fight triggers (`verify_souls_combat.gd`, after it collects the story enemies), so it is ALL
  PASS again.
- `verify_onboarding` "keyboard: a light hit does not pass Heavy" also fails on untouched `origin/feature/backlog`, so
  it was already broken and is not from this branch.

## Tests

`verify_enemy_variety.gd`: RESULT: ALL PASS. It checks:
- [1] For the bandit, the scorpion and the jackal, small and large: sprite, hurtbox, hitbox and body ×0.8/×1.3, the
  feet stay at y 16, and HP, damage, speed, reach and XP. The shared body is untouched.
- [2] The elite rate over 8000 keys is 0.128, the sizes follow 1 : 2 : 1, the rolls are stable, an elite bandit has
  HP 250, damage 30 and XP 60, it is ×1.1 with the outline shader, and a large elite has 450 HP.
- [3] Every placement above, and no rolls on DesertRoad.
- [4] Real input against a shield-bearer: a light hit from the front is blocked (HP and poise unchanged, one block
  signal). A hit in the back lands (110 → 80). A heavy from the front breaks the shield (HP unchanged, a 1.2 s stagger
  in the stagger frames, the shield node gone). After that a light hit from the front lands (80 → 50). Also the
  bestiary entry.

Shot: `design/shots/enemy_variety/shield_fight.png` (`UI/capture_enemy_variety.gd`). Top to bottom:
1. small, medium, large and elite bandits;
2. a light hit sparking off the shield;
3. the heavy: the shield flies off and he reels in the stagger pose;
4. shieldless, the hit lands for 30.

There is no Figma frame for enemies. The visual calls are D615 (the outline) and D616 (the placeholder shield).

Full suite (`Scripts/Tools/run_verify.sh | grep -v '^PASS'`):

```
FAIL  verify_onboarding — RESULT: 1 FAIL: keyboard: a light hit does not pass Heavy, 0 SCRIPT ERROR
SUITE: 1 FAIL
(102 PASS; the one FAIL also fails on untouched origin/feature/backlog)
```
