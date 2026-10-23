---
type: plan
status: planned
blocked-by: [Q74]
tags: [enemies, combat, art]
---

# Flying enemies: plan

**Nothing implemented.** Sapega asked for them in his playtest (2026-10-23): «треба додати літаючих ворогів, якісь
грифи або летючі миші». The direction is recorded as D445. Enemies are not UI, so no Figma design exists.

## What exists today
| Thing | Where | State |
|---|---|---|
| Enemy body | `Scripts/Gameplay/DefaultEnemy.gd`, a `CharacterBody2D`. It always falls: `:289-293` adds `default_gravity` when not on the floor | ✅ ground enemies only |
| Enemy brain | `Scripts/Gameplay/Components/EnemyLogic.gd`: patrol, chase, wind-up, attack. It reads `is_on_floor` (`:133`); the jackal's lunge is a knockback-style dash (`:398-399`) | ✅ ground only |
| Kinds and numbers | `Resources/Enemies/enemy_stats_{melee,fast,tank,archer}.tres`, scenes `Scenes/Characters/Enemies/*.tscn` | ✅ 4 ground kinds |
| Spawning | `Scripts/Gameplay/RoomEnemySpawner.gd`; spawn points in each room | ✅ |
| Journal | `Resources/Data/bestiary.json`, `JournalRecords.meet_enemy` / `kill_enemy` | ✅ |
| Art | the ComfyUI pipeline `comfy_sprite.py` (the hero's palette, D239) | ✅ tool exists; no flier sheet |

## Missing entirely
Checked with `grep -rliE "flying|vulture|bat|is_flying" SampleProject/Scripts SampleProject/Scenes/Characters`, which
finds nothing:
- a movement mode without gravity (hover, fly a path, dive and climb back);
- a flier's attack (dive or swoop) that leaves a window where the hero's sword can reach it;
- two kinds with stats, scenes and bestiary entries;
- art: fly loop, dive, hurt, death for each kind;
- spawn points in the rooms where they live.

## Decisions required
1. **Who lives where** (GAME DESIGN DECISION REQUIRED). The recommendation follows the lore and the light:
   - the **vulture** outdoors (Canyon, Desert Road, City Gates);
   - the **bat** indoors (Laboratory, LabCells, later caves).
2. **How they fight** (GAME DESIGN DECISION REQUIRED). Recommendation:
   - The vulture circles high out of reach, then dives at the hero along a line he can read, and climbs back. It can be
     hit only while low.
   - The bat flutters toward the hero in a wavy line, bites at close range and backs off. It is weak and often comes
     in twos or threes.
   - Neither touches the ground, and the roll passes under both (D443).
3. **Numbers (Q74)**: HP, damage, speed, wind-up and XP for both. Default until answered: the vulture uses the jackal's
   numbers (`enemy_stats_fast.tres`) with a 0.6-s wind-up before the dive; the bat has half the jackal's HP and damage.
   Both are provisional and get tuned in playtest.

## Slices
### Slice 0: art (ComfyUI art batch)
- `comfy_sprite.py` entries `enemy_vulture` and `enemy_bat` in the hero's palette, profile facing right. Frames: fly
  loop (4), dive or bite (2–3), hurt (1), death (3).
- Per memory: show Sapega a ×4 candidate sheet first, then make the frames.
- Its own commit, with a README beside the frames (AI-generated disclosure, as for the sword).

### Slice 1: flying movement and attack
- `EnemyLogic` / `DefaultEnemy` get a `flying` stat: no gravity, a hover height above the floor, the dive (vulture) and
  the flutter-bite (bat). Patrol and chase are rebuilt for the air, with no ledge checks.
- `enemy_stats_vulture.tres`, `enemy_stats_bat.tres`, `enemy_vulture.tscn`, `enemy_bat.tscn`, and `bestiary.json`
  entries.
- Adds `SampleProject/UI/verify_flying_enemies.gd`:
  - a flier stays airborne and never lands;
  - the dive hits a standing hero;
  - the roll passes under it;
  - the hero's sword hits it only in the low window;
  - it dies and counts in the bestiary.
- Its own commit.

### Slice 2: placement
- Uses the `room-content` skill: vultures on the Desert Road and in the Canyon, bats in the Laboratory, each with
  `RoomEnemySpawner` points that do not crowd the existing fights.
- `verify_flying_enemies` grows a room check.
- Its own commit, then a capture.

## Order and dependencies
`0 → 1 → 2`. Slice 1 can be coded while slice 0 renders, with the sheet's frame grid agreed first, but it is only
merged together with the art. Slice 2 waits on the bigger rooms of the world rework if that lands first.

## Out of scope for this pass
- A flying boss.
- Ranged fliers (spitting, dropping rocks).
