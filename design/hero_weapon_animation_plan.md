---
type: plan
status: active
tags: [combat, animation, art]
---

# Kusakam animated holding each weapon — plan (BACKLOG 42)

Sapega 2026-10-21 «він має мати анімацію, як він тримає меч, і анімацію, як він тримає інші типи зброї»;
2026-10-22 weapon variants by palette swap. Builds on [[souls_combat_plan]] (D264–D270: combo, heavy, block,
hurt, grips D267, sheathing D268). Figma: none (the hero is not a UI screen). Art: comfy-sprite (D239), batch
**A3** = the one-handed sword, made on the laptop (`SampleProject/Sprites/Player/Weapons/sword/README.md`).

## What exists today

| Thing | Where | State |
|---|---|---|
| Hero body frames, 64×64, artist + generated (Hurt, Heavy, Block, Cast*) | `Player.tscn` → `AnimationLibrary_player` (one library, `Sprite2D:texture` tracks) | ✅ one set for every weapon |
| Weapon as a separate sprite pinned to measured hand points | `Scripts/Player/Components/WeaponView.gd` (D223, D268): `HAND_*` constants, tweened arcs / stabs / smashes | ✅ every weapon type |
| Out of combat the weapon is hidden | `WeaponView.sheathed`, `EventBus.combat_state_changed` (D268 amended) | ✅ |
| Grip | `EquipmentManager.get_grip()` → bare / one_handed / two_handed / dual (D267) | ✅ |
| Per-type body swing | `PlayerCombat.SWING_ANIMATIONS` (mace → `AttackSmash`, polearm → `AttackThrust`) | ✅ |
| Hitbox | on for the whole `swing_time` (0.3 s) from the press; heavy: 0.4 s wind-up, 0.25 s strike | ✅ |
| Sword full-body frames, 96×96 | `Sprites/Player/Weapons/sword/{CombatIdle,Run,Air,Attack1-3,Heavy,Block,Hurt}` (25 frames) | ✅ art, wired by this pass |
| Frames for dagger, mace, halberd, dual-wield, bare-hands combat | — | ❌ (laptop art) |

## Decision: baked full-body frames per weapon TYPE, overlay kept as the fallback-free second path (D370)

- **Per weapon type with frames:** the weapon is drawn in the hero's frame (prettier, real hand poses, Sapega's
  ask). The `WeaponView` overlay is hidden while such an animation plays. Swing smears (`SlashTrail`) stay: they are
  the arc effect, not the weapon.
- **Per weapon type without frames yet:** the overlay as today (D268). This is not a fallback for missing art inside
  one type — a type either has its full set or uses the overlay for all its animations; the check is per type
  (an `AnimationLibrary` named after the type exists on the hero's `AnimationPlayer`).
- **Variants inside a type** (copper / iron / silver / crystal sword) do **not** get frames: a palette-swap shader on
  the blade key colours, item data names the palette (BACKLOG 42, Sapega 2026-10-22). A different silhouette
  (scimitar, jagged crystal) is a sub-type with its own library. Next slice after the sword wiring.

## Animation set per weapon type

Every weapon library carries the same names as the base library, so the code asks for `Idle`, `Attack` … and gets
the weapon's version when it exists:

| Base name | Weapon frames | Notes |
|---|---|---|
| `Idle` (in combat) | `CombatIdle/1–4` | out of combat the base `Idle` plays, weapon hidden (D268) |
| `Run` | `Run/1–N` | same 0.8 s loop as the base run |
| `Jump`, `Apex`, `Fall` | `Air/1`, `Air/2`, `Air/3` | rise, apex, fall |
| `Land` | `CombatIdle/1` | 0.1 s, the lead-in into `Idle` |
| `Attack` | `Attack1`, `Attack2`, `Attack3` by combo step | same 0.3 s length and key times as the base swing (wind-up 0, strike 0.05, follow-through 0.13, stance 0.21) so the hitbox window is unchanged |
| `HeavyWindup` / `HeavyStrike` | `Heavy/1` / `Heavy/2 → 3` | 0.4 s / 0.25 s, strike frame at 0, tip on the ground at 0.1 |
| `Block` | `Block/1` | |
| `Hurt` | `Hurt/1` | |
| `Roll`, `Climb`, `Cast*`, `Meditate`, `Walk` | — | base frames; weapon hidden in a roll, overlay in casts (D271) |

Dual-wield gets its own library (`dual_<type>`) later — the frames draw both blades; until then dual-wield keeps
the overlay for both hands. Bare hands keep the base frames (fists are drawn already).

## How the switch works (built for the sword)

- `Player.tscn`: one extra `AnimationLibrary` per weapon type with frames, keyed by the items.json `category`
  (`sword`), animations named as in the table. 96×96 cells: every animation sets `Sprite2D:offset` (0, −16) (the
  64×64 body sits at (16, 32) in the cell); every base animation sets it back to (0, 0).
- `WeaponView.body_library()` → the library name when the weapon in hand is drawn (in combat, or mid-swing), its grip
  is `one_handed` and the hero's `AnimationPlayer` has a library for its category; `&""` otherwise.
- `Player.body_animation(name)` resolves `name` → `<library>/<name>` (`Attack` → `<library>/Attack<step+1>`) when that
  animation exists; `Player.play_body()` is the one entry every hero animation goes through (`Player.gd`,
  `PlayerCombat._play`). When the library changes (a fight starts / ends, the weapon is switched) the current
  animation is replayed from the new library.
- `WeaponView._process` hides the overlay while a weapon-library animation plays.

## Slices

1. **Sword (one-handed sword)** — ✅ wired this pass (`cloud/weapon-gamepad`),
   `verify_souls_combat.gd` [12c].
2. **Palette swap for variants** — shader on the hero `Sprite2D` while a weapon library plays; items.json
   `palette` per item; crystal glow. Needs the key colours of the A3 blade measured.
3. **Dagger** (A-batch on the laptop): same table, quick stabs for `Attack1–3`.
4. **Mace**: overhead smash `Attack1–3`; `SWING_ANIMATIONS` mace → `AttackSmash` then resolves inside the library.
5. **Halberd (two-handed)**: both hands on the shaft; thrusts, low sweep, long lunge.
6. **Dual-wield** (`dual_sword`): four-swing combo frames (`Attack1–4`), both blades drawn.
7. **Bare-hands combat stance** (optional): `CombatIdle` with fists up.

Each art slice: comfy-sprite from the artist frames (D239), 96×96, same offset, then add the library to
`Player.tscn` and a [12c]-style check. More in-betweens (Sapega: smoother) — 5 frames per swing where the generator
holds the silhouette.
