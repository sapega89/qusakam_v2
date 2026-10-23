---
type: plan
status: planned
blocked-by: [Q85]
tags: [enemies, combat, art]
---

# Enemy variety: sizes, elites, shield-bearers — plan

**Not built.** Sapega asked for it on 2026-10-23: «моби мають бути різної висоти, і елітні моби якісь мають бути, і з
щитом». The direction is D495. It sits beside [[flying_enemies_plan]] (D445) and follows D494 (fewer, heavier hits).

## What exists today
| Thing | Where | State |
|---|---|---|
| Kinds | `Resources/Enemies/enemy_stats_{melee,fast,tank,archer}.tres`, `Scenes/Characters/Enemies/*.tscn` | ✅ four kinds, all one size per kind |
| Body and brain | `DefaultEnemy.gd`, `EnemyLogic.gd` | ✅ no block, no scale variants |
| Hero's guard break | heavy attack, the D264 / D265 poise and stagger rules | ✅ for the hero; enemies never block |
| Spawning | `RoomEnemySpawner`, plus the D492 respawn rule | ✅ with no rarity / elite roll |
| Journal | `bestiary.json` | ✅ one entry per kind |

## Missing entirely
- size variants: the scale, the matching hitboxes and hurtboxes (B128), and stats that scale with size;
- an elite layer: a rarity roll at spawn, a visual marker, a stat multiplier, one signature move and a better drop;
- a shared **guard bar** (shield or armour) that absorbs every hit until it is broken (D495 follow-up). It is used by the
  shield-bearer and by the scorpion (tank), whose bulk moves from HP into armour;
- a shield-bearer kind with a shield-bash attack;
- art: a shield-bearer sheet, plus elite marks (UI art or a palette swap).

## Decisions required
1. **Q85 — numbers and how often.** Default:
   - **sizes:** small ×0.8 (HP ×0.7, faster), medium ×1.0, large ×1.3 (HP ×1.8, slower, heavier hits per D494);
   - **elites:** 1 in 8 spawns outside story fights; HP ×2.5, damage ×1.5, a gold name plate with an epithet and a
     faint aura; one signature move per kind; double XP and a guaranteed drop.
   GAME DESIGN DECISION — defaults stand until Sapega answers.
2. **The guard bar (Sapega's follow-up, 2026-10-23).** There is no backstab, since bodies block (D443).
   - The shield-bearer's shield and the scorpion's armour plates absorb all damage until the guard bar is gone; heavy
     attacks drain it ×2.
   - On a break, pieces fly off, the enemy staggers for 1.2 s and then takes normal damage.
   - The shield-bearer's bash has a clear wind-up.
   - The scorpion trades about half of its HP for armour.

## Slices
### Slice 1 — size variants
- A `scale` field on the stats, honoured by the sprite, the shapes and the stats.
- Per room, the spawner picks sizes.
- `verify_enemy_variety.gd` checks that shapes and stats scale.
- Its own commit.

### Slice 2 — elites
- The rarity roll in `RoomEnemySpawner`; the elite flag on `DefaultEnemy`.
- The name plate, the aura shader and the signature move per kind.
- The drop and the XP.
- Its own verify checks and commit.

### Slice 3 — the shield-bearer
- Art (comfy-sprite, in the hero's style): idle, walk, block, bash, staggered, hurt, death.
- `enemy_stats_shield.tres`, `enemy_shield.tscn`, and the block logic in `EnemyLogic`.
- The bestiary entry.
- `verify_enemy_variety.gd` checks three things: no HP damage while the guard holds, a heavy attack drains it faster, and after the break normal hits land.
- The scorpion gets the same guard bar (armour) in this slice.
- Its own commit.

## Order and dependencies
After `cloud/combat-feel` (B128 hit areas, D443 bodies) and D494's tempo pass. `1 → 2`; `3` can go in parallel once its
art exists. The regions of D487 place them.

## Out of scope
- Elite affix stacking (several modifiers).
- Shielded fliers.
