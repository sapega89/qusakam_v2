---
type: plan
status: done
tags: [combat, feedback]
---

# Souls-lite combat — plan (BACKLOG 4 + 15)

**Built 2026-10-20** (slices 1–6, D264–D270). Before this pass: one-swing attack, roll, enemy wind-ups only. Figma: no design exists (combat is not a UI screen).
Decisions it builds: D250 (two-handed, dual-wield), D251 (no running in towns), D253 (souls-lite), D259
(interrupts). The calls this pass makes are **D264–D270** (agent calls, Sapega to confirm). The skill execution
path stays in [[skills_combat_plan]]; per-skill animations are BACKLOG 21; frame coverage for every state was
[[character_animation_plan]].

## What exists today

| Thing | Where | State |
|---|---|---|
| Attack input → one swing | `Scripts/Player.gd:199` → `PlayerCombat.perform_attack` `Player/Components/PlayerCombat.gd:64` | ✅ one swing, weapon cooldown between swings |
| Swing animation (artist run frames) | `Player.tscn` → `Animation_attack` (0.3 s) | ✅ one for every weapon |
| Weapon in hand, tween, smear | `Player/Components/WeaponView.gd:81` (arc / thrust / punch, 2-hit alternation `COMBO_WINDOW` :31) | ✅ visual only, no gameplay combo |
| Weapon profiles | `Resources/Data/items.json` → `weapon_profile` (D203), `PlayerCombat.apply_weapon_profile` :35 | ✅ reach / cooldown / height / knockback |
| One weapon in hand, Q / D-pad switch | `Managers/Gameplay/EquipmentManager.gd:26` (D202) | ✅ |
| Hitbox → damage | `Combat/Components/DamageApplier.gd:72` → `HealthComponent.apply_damage` :12 → `CombatBody2D.take_damage` :68 | ✅ |
| Hero mitigation (defence, Shield Block) | `Player.gd:388` | ✅ |
| i-frames after a hit | `CombatBody2D.register_damage` :60 (0.5 s hero, 0 enemies) | ✅ |
| Roll (one charge, ground only, invulnerable) | `PlayerMover.start_roll` :68 (D200) | ✅ |
| Enemy AI, wind-up, swing | `Gameplay/Components/EnemyLogic.gd:360` (D198, D208) | ✅ one swing per cooldown |
| Enemy stun / knockback breaks wind-up | `EnemyLogic.stun` :347, `start_knockback` :354 | ✅ only mace knockback / Electric Strike |
| Enemy stats | `Gameplay/Characters/Enemies/EnemyStats.gd`, `Resources/Enemies/enemy_stats_*.tres` | ✅ |
| Hit feel (impact, flash, hitstop) | `Systems/VFXHooks.gd:96`, `Managers/TimeManager.hitstop` :114 | ✅ |
| Input actions | `project.godot [input]`: attack (LMB / X), dodge (Shift / RB), jump, interact, assist, weapon_next/prev | ✅ — no `heavy_attack`, `block` |
| Hero frames | `Sprites/Player/{Idle,Walk,Run,Jump,Fall,Land,Roll,Climb,Meditate}` | ❌ no Hurt, Heavy, Block |

## Missing entirely (how checked)

- Combo chain, heavy attack, block, parry: `grep -rn "combo\|heavy_attack\|parry\|block" Scripts/Player*` → only
  `WeaponView.COMBO_WINDOW` (visual) and Shield Block (passive %).
- Hero stagger / hurt state: `grep -n "stagger\|hurt" Player.gd PlayerCombat.gd` → 0; a hit only flashes.
- Enemy poise / stagger from ordinary hits: 0 hits; only mace knockback and stun break a wind-up.
- Enemy combos: `EnemyLogic.perform_attack` swings once.
- Double dash / air dash: `start_roll` refuses in the air and has one charge.
- Run vs walk: the hero always runs (`PlayerMover._handle_horizontal_movement` :184); `Walk` plays only in cutscenes.
- Grips: `grep -n "two_handed\|grip\|dual" items.json EquipmentManager.gd` → 0.
- Sheathing: `WeaponView._refresh` :65 shows the weapon whenever one is in hand.
- `InputMap.add_action` anywhere in `Scripts/` → 0 (actions live only in `project.godot`).
- Interrupted casts (D259): skills are instant (`SkillManager.use_skill` :453), no cast state.

## Decisions (agent calls, recorded as D-IDs)

1. **The "freeze" (D264).** A 40-s scripted melee fight on DesertRoad (scratch probe: hold a direction, mash attack,
   sample once a second) never locked the hero: `event`, pause, `Engine.time_scale`, `is_attacking` and roll all
   released, the hero moved 400 px/s every second. No lock bug reproduces. D253 lists "enemies that sometimes freeze
   the hero" among the souls-lite mechanics, so it is built as one: an enemy hit staggers the hero, a heavy one (the
   tank, an enemy combo finisher) locks him longer. A regression check keeps the "never stuck" property.
2. **No stamina (D264).** No HUD element without Figma, pacing by recovery frames, cooldowns and poise instead.
3. **Values (D264):** light combo 3 swings (dual-wield 4), multipliers 1.0 / 1.0 / 1.4, chain window 0.35 s after a
   swing, finisher knockback 40 px; heavy: 0.4 s wind-up, ×2.2, knockback 70, 1.0 s recovery; enemy poise melee 3 /
   fast 2 / tank 6, light hit 1, finisher 2, heavy 3, two-handed ×1.5, resets 2 s after the last hit; poise break =
   0.6 s stagger (wind-up broken); hero stagger 0.25 s (melee, fast) / 0.6 s (tank, combo finisher), knockback 50 px;
   block: front hits ×0.3, no stagger except the tank (guard break); parry: a hit within 0.18 s of pressing block —
   no damage, attacker staggered 1.0 s; dash: 2 charges, the second in the air too, both back 0.6 s after the last.
   Enemy combos: melee 2 swings, fast 3, tank 1, chance 0.5, 0.25 s between swings.
4. **Running (D266):** a room root with `metadata/town = true` (Village, City, CityGates, MayorHall) makes the hero
   walk (Walk frames, 150 px/s) while out of combat; in a fight he runs as anywhere.
5. **Grips (D267):** `items.json` → `"grip": "two_handed"` on the halberd; two-handed = no Shield Block, poise ×1.5,
   both hands on the shaft. Dual-wield = a one-handed weapon in hand + another equipped one-handed weapon + no
   shield: the second is drawn in the off hand, swings alternate hands, combo of 4 at 0.8× swing time.
6. **Sheathing and per-weapon swings (D268):** in combat = an enemy chasing / attacking the hero, or the hero hit or
   struck in the last 3 s. Out of combat the weapon rides on the back; drawn on the first swing or when a fight
   starts. Swing shape per weapon type: bare hands punch, sword/axe slash arcs (down, up, spin finisher), mace an
   overhead smash, dagger quick stabs, polearm thrusts, heavy = overhead wind-up for all.
7. **Interrupts (D269):** a hit during the heavy wind-up staggers and cancels it; `SkillManager.interrupt_cast`
   spends the SP and starts the cooldown without the effect; skill wind-ups themselves come with BACKLOG 21.
8. **Input (D270):** `heavy_attack` = right mouse / R / pad B, `block` = Left Ctrl / middle mouse / pad LB; registered
   at boot from code (`Scripts/Core/CombatInput.gd`), because `project.godot` carries Sapega's local edits; move them
   into `project.godot` when that file is committed. Double dash reuses `dodge`; draw/sheathe is automatic.

## Slices

### Slice 1 — staggers both ways, enemy combos, the freeze check — ✅ built
- `PlayerCombat.gd` (state machine on timers, `stagger`), `Player.gd` (stagger on a wounding enemy hit),
  `PlayerMover.gd` (`push`, `locked`), `EnemyLogic.gd` (combo loop, `stagger`), `DefaultEnemy.gd` (poise),
  `EnemyStats.gd` + `enemy_stats_*.tres`, `Core/CombatInput.gd` (D270), EventBus `enemy_staggered`,
  `player_staggered`, `player_parried`, `skill_interrupted`; `Player.tscn` → `Hurt` (placeholder frame until slice 5).
- `verify_souls_combat.gd` [0]–[3].
### Slice 2 — light combo, heavy attack, block, parry, interrupts (D259) — ✅ built
- `PlayerCombat.gd`, `Player.gd`, `WeaponView.gd`, `SkillManager.interrupt_cast`, `VFXHooks.gd` (parry spark);
  `verify_souls_combat.gd` [4]–[7].
### Slice 3 — double dash, walking in towns — ✅ built
- `PlayerMover.gd`, room `.tscn` metadata; `verify_souls_combat.gd` [8]–[9].
### Slice 4 — grips, sheathing, per-weapon swings — ✅ built
- `items.json`, `EquipmentManager.gd`, `WeaponView.gd`, `Player.tscn`; `verify_souls_combat.gd` [10]–[12].
### Slice 5 — hero frames — ✅ built (4 generated, 4 kept)
- `comfy_sprite.py hero_combat` (Hurt, Heavy wind-up / strike, Block) from `Walk/1`; `Player.tscn` animations.
### Slice 6 — captures, exe, registers — ✅ done
- `capture_souls_combat.gd` (window; crops around the hero): sheathed / drawn, combo 1–3, heavy wind-up / strike,
  block, parry, both staggers, air double dash, dual-wield, mace, halberd. Full suite 53/53 PASS; exe rebuilt.
- Left: enemy stagger frames (D196), enemy HP/damage retuning, a tutorial hint for heavy / block (BACKLOG 12 batch).

## Order and dependencies

`1 → 2 → 3 → 4 → 5 → 6`. 5 can move: until frames exist the new states hold existing artist frames.

## Out of scope for this pass

- Skill cast animations and effects — BACKLOG 21 (D259 hook only).
- Enemy hurt / stagger frames — enemies stagger on their idle frame with a tint (D196 per-type art still open).
- Ranged enemy (Q35).
