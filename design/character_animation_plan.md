---
type: plan
status: done
---

# Character animations — plan

> **Q40 → D138, Q41 → D139 (answered 2026-10-13).** The hero's frames now exist in his own style — Idle, Walk, Run, Jump, Fall, Land, Roll, Climb, Meditate, Hurt, Heavy, Block, CastPalm / CastFire / CastStorm in `SampleProject/Sprites/Player/` (D262, D264, D271). Enemies and NPCs stay as they are by D139; NPC idle activities came later (D295). There is no hero **Death** frame folder. The *What exists today* table below is the 2026-10-13 starting point.

~~**Placeholder only.**~~ (2026-10-13) The player has frames for Walk and Run; every other state shows a single
borrowed frame. Enemies share one generic sheet, NPCs are static pictures. 2026-10-13.
Figma: no design exists (Figma covers UI only).

## What exists today

| Thing | Where | State |
|---|---|---|
| Player `AnimationPlayer` | `Player.tscn` — Idle, Walk, Run, Jump, Fall, Attack | ⚠️ only **Run** (8 frames, `Sprites/Player/Run/1-8`) and **Walk** (3 of 6 frames) animate. Idle = Walk/1, Jump = Run/4, Fall = Run/6, Attack = Walk/1 for 0.3 s — the attack has **no swing** |
| Player state → animation | `Scripts/Player.gd:117-135` | ✅ picks Idle / Run / Jump / Fall / Attack correctly — only the frames are missing |
| Attack VFX | `Scenes/FX/SlashTrail.tscn`, `Systems/VFXHooks.gd` | ✅ particle slash covers for the missing swing |
| Enemy animations | `Scenes/Characters/Enemies/default_enemy.tscn:13-62` — idle, walk, attack, death | ✅ work, but **one generic sheet** (`Scripts/Systems/character-spritesheet (4).png`) for every enemy (bandit, guards, lab boss) |
| NPCs | Old Man (`Village.tscn`, static frame of `SampleProject/Assets/Characters/old_man_idle.png`), Merchant, Blacksmith (Figma NPC art) | ⚠️ static `Sprite2D`, no animation |
| Kusakam art | `assets/QusajamSprite-0001.png`, `-0002.png` (113×127) | ⚠️ two frames, not wired anywhere |
| Third-party packs | `assets/2D_SL_Knight_v1.0`, `Knight`, `Knight 2D Pixel Art`, `FreeKnight_v1`, `MainCharacter(FreePack)`, `Free Character Sprites/*`, `AntiHero Character`, `GandalfHardcore …`, `Minotaur - Sprite Sheet.png`, `assets/bosses/*` | ⚠️ imported, unused; licences not recorded |

## Missing entirely

- Real frames for player **Idle, Jump, Fall, Attack**, and **Hurt / Death** (no such animation: `grep '"Hurt"\|"Death"' Player.tscn` → 0).
- Per-character enemy art (bandit, gate guards, lab boss) — one sheet for all.
- NPC idle animations.
- A record of which asset pack is whose and under what licence.

## Decisions required

1. **Q40 — GAME DESIGN DECISION REQUIRED (blocks slice 1).** Which art is Kusakam? Options:
   (a) draw/commission Kusakam frames to match `QusajamSprite` (113×127);
   (b) adopt a pack already in `assets/` (e.g. a knight set with idle/run/jump/attack/hurt/death);
   (c) keep the current 64×64 player frames and add the missing states in the same style.
   Recommendation: (b) for a complete set now, swap to (a) later — the `AnimationPlayer` names stay.
2. **Q41 — GAME DESIGN DECISION REQUIRED (blocks slice 2).** Which art for the bandit, gate guards,
   lab boss, and which NPCs get idle animations. Recommendation: one pack per enemy type from
   `assets/`, NPCs idle only.
3. **Animation set** (not blocking): Idle, Walk, Run, Jump, Fall, Attack, Hurt, Death for the player;
   idle, walk, attack, hurt, death for enemies. Hurt/Death need small hooks in `Player.gd` /
   `CombatBody2D` (they exist as signals: `damage_token`, `entity_died`).
4. **Licences** (not blocking, but before release): list each pack's licence in `design/assets_licences.md`.

## Frames from Ludo AI (2026-10-15)

`@ludoai/cli` is installed and its skill is in `.claude/skills/ludo/`; Sapega has **not bought Ludo yet** —
nothing generated. When he has: `ludo login`, then per missing state (Idle, Jump, Fall, Attack, Hurt,
Death) `ludo sprite animate --initial-image SampleProject/Sprites/Player/Run/1.png --motion-prompt "<state>"
--model forge-pixel --frame-size 64 --engine godot` (D138: keep the 64×64 style). Estimate: 3 s ×
1.5 credits/s ≈ 4.5 credits per state, ≈ 27 for the set (one variation each). Check `ludo account` and
`--dry-run` first.

## Slices

### Slice 1 — Player full set
- `Player.tscn` animations get real frames (SpriteFrames or texture tracks, matching the current tracks).
- Add `Hurt` and `Death`; play them from `Player.gd` on damage / death.
- `UI/verify_player_animation.gd`: every state animation has > 1 frame (except deliberately static ones), Attack lasts the attack window, Hurt plays on damage, Death on death.
- Commit.

### Slice 2 — Enemies by type
- `EnemyStats` (already per type: melee / fast / tank) gains a `sprite_frames` / sheet field; `default_enemy.tscn` reads it.
- Bandit, guards, lab boss get their own art (Q41).
- Extend `verify_combat_flow.gd`: each enemy type shows its own sheet; death animation plays before free.

### Slice 3 — NPC idles
- Old Man, Merchant, Blacksmith, Mayor: `AnimatedSprite2D` idle loops.
- Capture shots of each NPC in place.

## Order and dependencies

`1 → 2 → 3`. Slices 2 and 3 are independent of each other once their art is chosen.
[[cutscene_plan]] uses these animations (walking, falling) but can start with the current ones.

## Out of scope for this pass

Portraits / full-body dialogue art — that is the dialogue presentation layer (D110, D112), see [[BACKLOG]].
