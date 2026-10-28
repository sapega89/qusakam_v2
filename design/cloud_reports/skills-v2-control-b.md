---
type: report
tags: [cloud, skills, v2, combat]
branch: cloud/skills-v2-control-b
---

# cloud/skills-v2-control-b: skills v2 slice 6, second half (control and finishers)

**Summary**
- **Done:** Chain of Night, Sand Veil, Dread Howl, Radiant Flare, Night Reaper and Soul Harvest are built and can be learned. Each row drops `planned`; its `draft` became real keys that code reads (`area`, `pull`, `blind`, `fear`, `execute`), documented in `_schema`. 16 planned actives are left (control-a builds 5 more on its own branch).
- **Reused:** stun / stagger (D207, D264), burn, the Stunned and Burning status icons, the shield-bearer's shield break (D495), the XP on a kill, and `restore_sp`. Enemies had no fear or flee before. It is new and small: `EnemyLogic.fear` / `_flee`. The same goes for the blind: `EnemyLogic.blind`, `blind_misses`.
- **No new art.** The skills use oath cast poses (CastFire / CastStorm). The effect `ControlSkill.tscn` borrows the frames of an oath skill per skill (`ControlSkillFX.BORROW`). The list of missing art is below.
- **Radiant Flare no longer "clears burning and curses from you".** The hero has neither state (`grep` finds no burn or curse on the hero), so the text says only what it does (en/uk). Cleansing waits for hero statuses.
- **Tests:** a new `verify_skills_control_b` (7 sections, ALL PASS). Also ALL PASS: `verify_skill_rules` ([11] 16 planned; the 6 are built), `verify_skill_fx` (the 6 may borrow frames), `verify_scripts_compile`.
- **Full suite:** running (this line is updated when it ends).
- No B rows fixed. The D-ID text is below (placeholder D-sv2cb1).

## D-ID text (for the orchestrator; placeholder D-sv2cb1)

| ID | Kind | Text |
|---|---|---|
| D-sv2cb1 | ROUTINE CALL | **Control and finisher skills** (skills v2 slice 6, second half; D535, D495, D264, D207, D504; `cloud/skills-v2-control-b`).<br><br>**Zone without moving** (`area`): `first` = the nearest enemy ahead within `reach` px of the hero's body, `front` = every enemy ahead within `reach`, `around` = every enemy within `reach` on both sides. The cast needs someone in its zone, otherwise it does not start and costs nothing. Control times grow with rank and synergies the same way damage does (`SkillManager.control_factor`).<br><br>**Chain of Night** (`area first 420`, `pull.hold 1.5`): pulls the nearest enemy ahead to the hero's body in 0.2 s, cuts it, and holds it in a stagger for 1.5 s. A boss is neither pulled nor held.<br>**Sand Veil** (`area front 180`, `blind 3 s / miss 0.6`): for 3 s an enemy ahead loses the hero beyond its own strike reach. It does not chase, it does not go to where it last saw him, and a wind-up on him breaks. Each of its swings misses with a 60 % chance (the hitbox deals nothing). Enemies behind the hero are not touched.<br>**Dread Howl** (`area around 220`, `fear 2 s / flinch 0.4 s`): everyone in range staggers for 0.4 s. The weak (not elite, not a boss) then run from the hero for 2 s. Elites and bosses only flinch.<br>**Radiant Flare** (`area around 200`, stun 1.2 s): hits and stuns everyone around. Cleansing the hero waits for hero burn and curse states, which do not exist.<br>**Night Reaper** (`area front 260`, burn): a crescent that hits every enemy up to 260 px ahead and sets them burning.<br>**Soul Harvest** (`execute below 0.2 / sp_refund 10`): a target at or below 20 % HP, or a shield-bearer whose shield just broke and still staggers (D495), dies from the blow. The kill gives its XP, and the hero gets 10 SP back (after paying the cost). Above the threshold it is a plain hit. A boss is never executed.<br><br>SP, damage and scaling are slice 1's. Each skill has 1–2 synergies with passives of its own tree. Poses and effects borrow existing frames until the art lane draws their own. |

## How it works (file:line)
- `SampleProject/Scripts/Systems/SkillDefinition.gd`: fields `area_hits`, `area_reach`, `pull_hold`, `blind_time`, `blind_miss`, `fear_time`, `fear_flinch`, `execute_below`, `execute_refund`; `from_dict` / `to_dict`; `controls()`.
- `SampleProject/Scripts/Combat/Systems/SkillTargeting.gd`: `area_targets`, `enemies_ahead`, `_nearest`; `skill_targets` checks `area_hits` first.
- `SampleProject/Scripts/Combat/Systems/SkillCombatExecutor.gd` (section «Контроль і добивання»): `apply_control`, `pull` (`PULL_TIME` 0.2, `PULL_GAP` 8), `strong`, `reaps`, `reap`.
- `SampleProject/Scripts/Managers/Gameplay/SkillManager.gd`:
  - `cast_skill` checks the zone through `skill_targets`;
  - `use_skill`: a control branch without damage (veil, howl); in the hit loop, `apply_control` and the harvest; `restore_sp(sp_back)` after `_pay`;
  - `control_factor`.
- `SampleProject/Scripts/Gameplay/Components/EnemyLogic.gd`: `blind_left`, `blind_miss`, `fear_left`; `blind()`, `blind_misses()`, `fear()`, `_flee()`; the tick in `process_physics`, the fear in `process_ai`, and the blind check in `can_notice`.
- `SampleProject/Scripts/Gameplay/DefaultEnemy.gd`: `guard_broken()` (false); `start_attack` skips `enable_damage` on a blind miss. `ShieldBearer.gd`: `guard_broken()` = shield gone and still staggered.
- `SampleProject/Scripts/FX/ControlSkillFX.gd` + `Scenes/FX/Skills/ControlSkill.tscn` (inherits `OathSkill.tscn`): borrowed charge / release frames.
- `SampleProject/Resources/Data/skills.json`: the 6 rows and 5 `_schema` keys. `sound_events.json`: `cast_<id>_windup/_release` reuse cast_fire / cast_electric. `en.po` / `uk.po`: the 3 changed descriptions.

## Tests
- `verify_skills_control_b` (new; DesertRoad, real enemies; it fails without the code, because the skills would still be `planned`):
  - [1] data;
  - [2] Chain: an enemy 300 px away is pulled to under 90 px and cut, the one behind it is untouched, it is held in place for its time and then released, SP is paid; nobody within 420 px → NO_TARGET with no SP spent;
  - [3] Veil: the enemy ahead is blind and stops coming 170 px away, the one behind still comes, a blind swing misses, and after the veil it sees the hero again;
  - [4] Howl: both enemies in range stagger, the weak one flees (its gap grows by more than 40 px), the elite stays, the one 420 px away is untouched; nobody around → NO_TARGET;
  - [5] Flare: front and back are hit and stunned, 420 px is out of range;
  - [6] Reaper: 60 px and 240 px ahead are hit and burn, the one behind is not;
  - [7] Harvest: at 25 % a plain hit, it lives, SP paid, nothing back; at 15 % executed, with XP and +10 SP; a broken shield at full HP is executed with +10 SP; a shield still up is no broken guard.
- `verify_skill_rules` [11]: 16 planned; the 6 are built.
- `verify_skill_fx` [1]: the 6 borrow oath frames (the D279 "own frames" check comes with their art).

## For the art lane (slice 7)
- **Chain of Night:** a hero pose throwing a chain; a dark chain that flies out and drags the enemy back; a chain-bind loop on the held enemy. It borrows Withering Grasp's dark hand now.
- **Sand Veil:** a throw-sand pose; a sand cloud cone ahead; a **Blinded status icon** for `status_row` (none exists, so a blind enemy shows nothing). It borrows Second Wind's gust now.
- **Dread Howl:** a howl pose (head back); a dark sound wave ring; a **Feared status icon** and an enemy flee pose (they walk away now). It borrows Searing Hex now.
- **Radiant Flare:** a burst-of-light pose; a radial gold flash. It borrows Dervish Whirl's ring now.
- **Night Reaper:** a wide sweep pose; a long dark-fire crescent the length of its 260 px reach (the borrowed Eclipse Cleave arc covers less than half).
- **Soul Harvest:** a reaping pose; a scythe cut; a soul wisp flying from the killed enemy to the hero (the SP refund). It borrows Eclipse Cleave now.
- **Sounds:** a chain rattle, sand, a howl, a flare, a reap. Cast_fire / cast_electric are reused now.

## Not done / open
- Blind does not affect archers' arrows or the jackal's latch bite: only melee hitbox swings can miss.
- The tooltip shows damage only, not the zone, hold, blind, fear or the threshold (as in slice 3).
- Merge notes for the integrator: `skills.json` rows and `_schema` keys are additive; `verify_skill_rules` [11]'s planned count (16 here) must be lowered by the other slices too; `sound_events.json` gains lines after `cast_dune_quake_release`, as the other slices will.
- Figma has no frames for these skills. Nothing to compare. No capture was taken: the effects are borrowed placeholders.
