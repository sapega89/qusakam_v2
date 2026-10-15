---
type: plan
status: blocked
blocked-by: [Q52]
---

# Laboratory boss — plan

**Nothing implemented.** The «boss fight» is four ordinary enemies in two waves. 2026-10-15.
Figma: no design exists.

## What exists today

| Thing | Where | State |
|---|---|---|
| Boss state | `Scripts/Gameplay/Scenes/Laboratory.gd:107` `BOSS_FIGHT` → `_start_fight("Laboratory_BossFight")` | ✅ works, but spawns ordinary enemies |
| The «boss» | `Maps/Laboratory.tscn:127-150` `EnemySpawner`: tank, melee, fast, tank; `spawn_in_waves`, `wave_size = 2` | ⚠️ not a boss |
| Win condition | `Laboratory.gd:214` `all_enemies_defeated` → `lab_boss_fight_complete` | ✅ works, reusable as is |
| Enemy types | `Resources/Enemies/enemy_stats_{melee,tank,fast}.tres`; `EnemySpawnPoint.enemy_type` is an `@export_enum` of those three (`EnemySpawnPoint.gd:9`) | ✅ no boss type |
| Enemy scene | `Scenes/Characters/Enemies/default_enemy.tscn`, one shared sheet (D139) | ✅ |
| Boss line | `dialogue_quest/Laboratory_BossFight.dqd` — one line, no speaker | ⚠️ placeholder |
| Boss art | `assets/bosses/Orc_Berserk`, `Orc_Shaman`, `Orc_Warrior` (Attack_1-3 … sheets) | ⚠️ imported, unused, licence not recorded |
| HP bar over enemies | enemy HP bars exist (D173 keeps them screen-sized) | ✅ no boss-size bar (`figma_coverage` §1: enemy HP bar undesigned) |

Checked: `grep -ri boss Scripts/` → only the `Laboratory.gd` state names and the objective text.

## Missing entirely

- A boss enemy: stats resource, type in `EnemySpawnPoint`, its own scene/sprite.
- Boss behaviour beyond the shared enemy AI (phases, special attacks) — if wanted.
- Who the boss is: name, speaker for its lines, its place in the story.

## Decisions required

1. **Q52 — GAME DESIGN DECISION REQUIRED (blocks slice 1).** Who is the lab boss and how does the
   fight go? (a) one big enemy on the shared AI with more HP/damage — cheapest; (b) (a) plus a
   second phase (at 50 % HP: faster, or summons the current small enemies); (c) unique attacks.
   Also: its name and art — one of the Orc packs in `assets/bosses/`, or the shared sheet
   scaled up (D139 covers ordinary enemies, not a boss).
2. **Stats** — HP, damage, speed. Not invented here: Sapega's numbers, or a provisional row
   recorded as a Q-ID.
3. Keep the small enemies in the fight (as adds) or remove them — part of Q52.

## Slices

### Slice 1 — one boss enemy
- `Resources/Enemies/enemy_stats_boss.tres` (Q52 numbers); `"boss"` added to `EnemySpawnPoint.enemy_type`.
- Boss scene/sprite per Q52; `Maps/Laboratory.tscn` spawner: the boss (+ adds per Q52).
- `Laboratory_BossFight.dqd`: the boss's speaker and lines (drafts `[ЧЕРНЕТКА]` for Sapega).
- `UI/verify_laboratory.gd`: BOSS_FIGHT spawns exactly the boss (+ adds); killing it sets
  `lab_boss_fight_complete`; room state remembers its HP (D152).

### Slice 2 — phase / special attacks (only if Q52 says b or c)

### Slice 3 — boss intro cutscene (needs a beat chosen, [[cutscene_plan]])

## Order and dependencies

`Q52 → 1 → 2`. Slice 3 can go after 1 independently. Playtest 1.1 ([[backlog_roadmap]]) should
run after slice 1, so the lab is played with its real fight.

## Out of scope for this pass

Per-type art for ordinary enemies (D139). Boss HP bar design (no Figma, [[figma_coverage]] §1).
