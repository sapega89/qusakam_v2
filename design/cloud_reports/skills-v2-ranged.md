---
type: report
tags: [cloud, skills, v2, combat]
branch: cloud/skills-v2-ranged
---

# cloud/skills-v2-ranged: skills v2 slice 4, ranged skills and zones

**Summary**
- **Done:** Holy Javelin, Lightspear, Hallowed Circle and Hellfire Stomp can now be learned and cast. A **throw** flies as a `SkillProjectile`. It extends the bow's `Arrow` (D380–D381), so it flies straight along the facing, passes through the hero and NPCs, and sticks in walls. A **zone** is a `SkillZone` placed at the hero's feet. It hits once a second for its time. 18 planned actives are left.
- **Numbers** come from each row's `draft` (D808). They are now real fields that code reads: `projectile {range, speed, pierce}` and `zone {radius, time, dps, heal}`. Both are documented in `_schema`. Two numbers are my own calls (see the D-ID text): Lightspear's speed and the pool radius.
- **Casting:** SP is paid on release, whether the throw or zone hits anything. A blow during the wind-up interrupts the cast (D259): SP is paid and nothing is thrown or placed. A zone can only be cast from the ground; a throw also works in the air.
- **Art:** no new art. Every effect uses existing frames as a placeholder. The list the art lane needs is below.
- **Tests:** a new `verify_skills_ranged` (8 sections, ALL PASS); without this branch's code, every one of its casts returns PLANNED. Also ALL PASS: `verify_scripts_compile` and `verify_skill_rules` (planned count 22 → 18, new check [11]).
- **Full suite:** `SUITE: 2 FAIL in 20 min 18 s, J=4`. Neither failure comes from this branch. `verify_difficulty` is a known failure (17 FAIL; it is in the skills-v2-move list). `verify_lab_boss` fails the same 2 checks on the base `origin/cloud/skill-art-wire`, run once with this branch's code removed: the balanced build dies in 2.3 blows and the mercenary takes 67 light hits.
- No B rows fixed. The D-ID text is below (placeholders D-sv2r1, D-sv2r2).

## D-ID text (for the orchestrator)

| ID | Kind | Text |
|---|---|---|
| D-sv2r1 | ROUTINE CALL | **Thrown skills: Holy Javelin and Lightspear** (skills v2 slice 4; D380, D381, D259, D504; `cloud/skills-v2-ranged`).<br><br>**How it works.** On release, a spear of light flies from the hand along the facing, like the bow's arrow (`SkillProjectile` extends `Arrow`). It flies straight, with no gravity and no auto-aim, through the hero and NPCs. It sticks in a wall and fades after `projectile.range` px. A hit is a skill hit: skill damage with rank, attack scaling and synergies, no SP back for the hit (D504), and the D207 status. The struck enemy turns to the hero. The cast starts with no enemy in front (it is the ranged answer) and works in the air too. **SP is paid on the throw, hit or miss.** A projectile cannot be called back, like a movement whiff (D812).<br><br>**Numbers:**<br>• Holy Javelin: 520 px at 900 px/s, stops at the first enemy.<br>• Lightspear: 600 px at **1200 px/s** (the charged arrow's speed, D381; the draft had no speed), pierces every enemy on its line once.<br><br>SP and damage are unchanged from slice 1. Synergies: Javelin ← Weapon Training 0.06, Keen Edge 0.04; Lightspear ← Sky's Grace 0.06, Zealous Answer 0.04. |
| D-sv2r2 | ROUTINE CALL | **Ground zones: Hallowed Circle and Hellfire Stomp** (skills v2 slice 4; D207, D259; `cloud/skills-v2-ranged`).<br><br>**How it works.** On release, a zone is placed at the hero's feet and stays there. It reaches `zone.radius` px both ways and **96 px up**, so a standing enemy is inside and one that jumps above it is not. **Once a second, for `zone.time` s** (6 or 5 ticks): enemies inside take `zone.dps`, and the hero and allies inside (the `allies` group, as with Healing Palm) heal `zone.heal`. Both values scale with rank, Wisdom and synergies (`SkillManager.zone_power`), not with attack. Zone ticks give no SP. If the skill has `damage`, the release also hits every enemy in the zone (Hellfire Stomp's stomp). Zones are cast from the ground only, start with no enemy in front, and SP is paid on release.<br><br>**Numbers:**<br>• Hallowed Circle: radius 150, 6 s, 6 dps to enemies, 3 HP/s to the hero.<br>• Hellfire Stomp: stomp 60 (+ scaling), then a pool of **radius 80** (the draft's `pool_px` 160 read as the pool's width) for 5 s at 7 dps.<br><br>Companions are assists with no HP, so "you and your companion slowly heal" means the hero and any `allies` NPC. Synergies: Circle ← Mending Hands 0.06, Consecrated Ground 0.04; Stomp ← Embers Within 0.06, Dread Aura 0.04. |

## How it works (file:line)
- `SampleProject/Scripts/Systems/SkillDefinition.gd`:
  - new fields `projectile_range`, `projectile_speed`, `projectile_pierce`, `zone_radius`, `zone_time`, `zone_dps` and `zone_heal`;
  - `throws()` and `leaves_zone()`;
  - `from_dict` and `to_dict`.
- `SampleProject/Scripts/Combat/Arrow.gd`: one change, `range_px` (defaults to `RANGE`) replaces the constant in `_physics_process`.
- `SampleProject/Scripts/Combat/Skills/SkillProjectile.gd` (new, extends Arrow):
  - `_strike` → `SkillManager.projectile_hit`;
  - `place_at_hand` (`PlayerCombat.ARROW_FROM`).
  - Scene: `Scenes/Combat/skill_projectile.tscn`, which inherits `arrow_charged.tscn`.
- `SampleProject/Scripts/Combat/Skills/SkillZone.gd` (new):
  - ticks are counted (`roundi(time / TICK)`), so each zone hits exactly its time;
  - `area()`;
  - fades after the last tick.
  - Scene: `Scenes/Combat/skill_zone.tscn`, with one placeholder sprite per skill id.
- `SampleProject/Scripts/Combat/Systems/SkillCombatExecutor.gd`:
  - `throw`, `place_zone`, `hurt`;
  - the scenes are loaded at runtime, not preloaded. Preloading made a compile cycle: Arrow → PlayerCombat → SkillManager → executor.
- `SampleProject/Scripts/Combat/Systems/SkillTargeting.gd`: `enemies_in(rect)`, `allies_in(player, rect)`.
- `SampleProject/Scripts/Managers/Gameplay/SkillManager.gd`:
  - `cast_skill`: a throw or zone starts without an enemy in front;
  - `use_skill`: one dispatch line to `_use_ranged`;
  - new functions `_use_ranged`, `projectile_hit`, `zone_tick`, `zone_power`.
- `SampleProject/Scripts/Player/Components/PlayerCombat.gd`: one condition in `begin_cast`, so a zone, like a move, starts from the ground only.
- `SampleProject/Scripts/FX/RangedSkillFX.gd` + `Scenes/FX/Skills/RangedSkill.tscn`: the cast effect is a borrowed glow (`heal_aura.png`) in the casting hand during the wind-up, which fades on release.
- `SampleProject/Resources/Data/skills.json`:
  - the 4 rows no longer have `planned` or `draft`;
  - they gain `cast`, `vfx`, `projectile` / `zone`, `synergies` and `required_weapons: []`;
  - `_schema` gains `projectile` and `zone`.
  - All edits stay inside these 4 rows and the schema, so merging with slices 5 and 6 stays mechanical.
- `SampleProject/Resources/Data/sound_events.json`: `cast_<id>_windup` / `_release` for the 4 skills, all reusing existing files.

**Poses (borrowed):**
- Holy Javelin: CastStormWindup → CastFireRelease.
- Lightspear: CastStormWindup → CastStormRelease.
- Hallowed Circle: CastPalmWindup → CastPalmRelease.
- Hellfire Stomp: HeavyWindup → LeapSlamStrike.

## Tests
- `verify_skills_ranged` (new; DesertRoad, real enemies; fails without the code because every cast returns PLANNED):
  - [1] Javelin at 380 px, out of strike reach: hits for 238 = `skill_damage`; 9 SP paid and none back; the hero does not move.
  - [2] Javelin with two enemies: only the first is hit. An enemy at 700 px is not hit, and the miss still costs 9 SP.
  - [3] Lightspear hits both enemies at 200 and 420 px once each (242), not the one at 800.
  - [4] Hallowed Circle: 3 ticks (18) after 3 s; 36 = 6 × 6 inside at the end and 0 outside; the hero healed 18 = 6 × 3; no damage after it ends.
  - [5] Hellfire Stomp: the stomp hits ±60 px (198 each); the pool brings the total to 233 = 198 + 5 × 7; nothing outside.
  - [6] A stagger during the wind-up of Javelin and of Circle: nothing spawned, SP paid.
  - [7] Circle in the air returns BUSY; Javelin in the air starts.
  - [8] Data: not planned, no `draft`, RangedSkill.tscn, the fields read back.
- `verify_skill_rules` [11]:
  - 18 planned actives;
  - the 4 ranged and zone skills are built (cast, effect, synergies);
  - each throw has a speed and each zone a radius and a dps or heal;
  - the planned example for the skill screen's plan moved from Lightspear to Rising Slash.
- `verify_skill_fx` [1]: skills whose vfx is `RangedSkill.tscn` are exempt from the D279 "own frames" check until slice 7 draws their art, as movement skills were before H3.

## For the art lane (slice 7, ComfyUI)
- **Holy Javelin:**
  - pose frames: a throw windup (spear of light raised over the shoulder) and a throw release (arm forward);
  - effect: a spear-of-light projectile (now the tinted charged arrow at 1.5×), a hand glow during the windup, a light burst on hit.
- **Lightspear:**
  - pose frames: a two-handed lance-thrust windup and release;
  - effect: a longer piercing lance or beam with a trail, and a burst on each enemy it pierces.
- **Hallowed Circle:**
  - pose frames: a prayer windup and a palms-down release onto the ground (now CastPalm);
  - effect: a gold holy ring on the ground, 300 px wide, looping for 6 s (now a stretched, tinted `Smear/slam_ring_2`), rising motes, a heal sparkle on the hero for each tick.
- **Hellfire Stomp:**
  - pose frames: a stomp windup (knee raised) and a stomp impact (now HeavyWindup → LeapSlamStrike);
  - effect: a dark-fire pool on the ground, 160 px wide, looping for 5 s (now a squashed, tinted `fire_arc.png`), a stomp shockwave, flame licks on ticking enemies.
- **Sounds:** a throw whoosh, a spear impact, a circle hum loop, a fire pool crackle loop. All four reuse existing files now.

## Not done / open
- **Hellfire Stomp cannot be learned in play yet:** its prerequisite `night_reaper` is a slice 6 skill that is still planned. The code and data are ready; the test unlocks it directly.
- The tooltip shows damage only. It does not list range, zone dps or heal yet.
- No capture was made. Figma has no frames for these skills, so there is nothing to compare.
