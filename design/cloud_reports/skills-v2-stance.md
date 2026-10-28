---
type: report
tags: [cloud, skills, v2, combat]
branch: cloud/skills-v2-stance
---

# cloud/skills-v2-stance: skills v2 slice 5, stances and buffs

**Summary**
- **Done:** Counter Stance, Mirror Stance, Centered Breath, Battle Cry, Aegis, Blood Price and Rally can be learned and cast. A new component, `SkillStances` (a child of SkillManager), runs all seven. 15 planned actives are left. Branched from `cloud/skill-art-wire`.
- **Numbers are provisional** (routine call, D-sv2s1). They are the D808 drafts, now in a `buff` block in `skills.json` that the code reads. The `draft` and `planned` keys of these 7 rows are gone, and `_schema.entry.buff` documents the block.
- **Reuse:** the counter goes through the normal take-damage path; the mirror sends arrows back with `Arrow.parried` (D384); Counter Stance and Aegis show the **magic** shield (H2/D851) over the hero. The glass shield stays **off** (Q115 not answered). Rally boosts the next `CompanionAssist`. Buffs show their skill icon in the hero's status row on the HUD (`status_row`, D599). No new art: the poses are Block / Meditate / Cast*, and the effect is a placeholder made of particles.
- **Tests:** a new `verify_skills_stance` (10 sections, ALL PASS) and `verify_skill_rules` [11] extended (ALL PASS). `verify_scripts_compile` ALL PASS. NEIGHBOURS_LINE
- **Full suite:** SUITE_LINE
- No B rows fixed. The D-ID text is below (placeholder D-sv2s1).

## D-ID text (for the orchestrator; placeholder D-sv2s1)

| ID | Kind | Text |
|---|---|---|
| D-sv2s1 | ROUTINE CALL | **Stances and buffs** (skills v2 slice 5; D535, D808, D851, D384, D259, D504; `cloud/skills-v2-stance`).<br><br>**How they work.** `SkillStances` (a child of SkillManager) runs the `buff` block of `skills.json`. Every value grows with rank, Wisdom and synergies, the same way heals do; times do not grow. None of these skills needs an enemy in front. SP is paid on release; a blow during the wind-up interrupts the cast (D259). Each lasting buff shows its skill icon in the hero's status row. Death and respawn clear them all.<br><br>**Counter Stance** (0.8 s; the stance is the cast's release, in the Block pose, with the magic shield): the first blow of an enemy, from either side, is blocked, and the attacker takes the skill's damage (110 + 6.0 Phys). The hero answers in the HeavyStrike pose, and that ends the stance. An arrow is blocked, and the stance keeps waiting. A red (dodge) attack still hits and breaks the stance.<br>**Mirror Stance** (1.0 s): every arrow that reaches the hero flies back, carrying reflect 1.0 × its damage (× rank). Melee blows, red arrows and the boss's fireball (B133) still hit.<br>**Centered Breath**: only in battle (`PlayerCombat.in_combat`), so it is not a free heal between fights next to the Healing Palm flask (D504). The 1.5 s wind-up is the channel (Meditate pose), and a wounding blow breaks it. On release it heals 30 + 1.0 Elem and restores 8 SP. It costs 0 SP.<br>**Battle Cry** (8 s): the hero's hits (melee and arrows, `PlayerCombat.hit_damage`) deal +15 %. Skills are not raised. Ordinary enemies (not elite, not a boss) within 160 px flinch, a 0.4 s stagger (new number).<br>**Aegis** (5 s): a barrier soaks 60 + 1.0 Elem of damage after defence. A blow it soaks whole does not stagger. The magic shield shows while the barrier lasts.<br>**Blood Price**: it costs 10 % of Max HP, with no hit, no stagger and no invulnerability. It is refused if it would leave 0 HP. The next 3 landed hits of the hero deal +50 %; skill hits do not use them up.<br>**Rally**: the next companion assist deals +40 % and its stun and stay last +50 %. It is refused when no companion is in the party. It holds until that assist; it has no timer.<br><br>Each skill has 1–2 synergies with passives of its own tree. Poses come from existing frames. The cast effect is a placeholder (`StanceSkill.tscn`, particles) until the art lane draws its own. |

## How it works (file:line)
- `SampleProject/Scripts/Combat/Systems/SkillStances.gd` (new):
  - `begin` handles the refusals (Rally with no party, Breath out of battle, Blood Price at low HP);
  - `use` starts the stance or buff when the cast releases;
  - `answer_blow` (Counter, Mirror), `soak` (Aegis), `hit_factor` (Battle Cry, Blood Price) and `rally` (the assist);
  - `_on_damage_dealt` uses up the Blood Price charges;
  - the `changed` signal drives the HUD, and `clear` runs on `player_respawned`.
  - SkillManager loads it with `load()`, not `preload`. A preload makes a compile cycle: SkillStances → DefaultEnemy → EnemyLogic → PlayerCombat → GameManager → SkillManager. The precedent is MoveSkillFX in verify_skill_fx.
- `SampleProject/Scripts/Systems/SkillDefinition.gd`:
  - the buff fields, `_read_buff`, `is_buff()` and `is_stance()`;
  - a stance's `cast_release` is set to its `buff.time`.
- `SampleProject/Scripts/Managers/Gameplay/SkillManager.gd` (+17 lines):
  - `stances`;
  - `cast_skill` → `stances.begin`;
  - `use_skill` → `stances.use`;
  - `_buff_used` (pays, `after_skill`, `skill_used`).
- `SampleProject/Scripts/Player.gd` `take_damage` (+5 lines): `stances.answer_blow` before mitigation, `stances.soak` after it.
- `SampleProject/Scripts/Player/Components/PlayerCombat.gd` (+6 lines): `hit_damage` × `stances.hit_factor()`, and `answer_stance(pose, time)`.
- `SampleProject/Scripts/Managers/Gameplay/CompanionManager.gd` `_send` (+1 line): `stances.rally(actor)`.
- `SampleProject/Scripts/Player/Components/ShieldSpell.gd` (2 lines): the magic shield also stands while `stances.shows_shield()` (Counter Stance, Aegis). `uses_glass_shield()` stays false (Q115).
- `SampleProject/UI/Components/status_row.gd/.tscn`: `set_buff` and `buff_ids`, with a hidden `BuffTemplate` node. `player_vitals_panel.gd` connects `stances.changed`.
- `SampleProject/Scenes/FX/Skills/StanceSkill.tscn`: the placeholder cast effect (SkillCastFX; particles gather, then rise; no textures).
- `SampleProject/Resources/Data/skills.json`: the 7 rows (no `planned`, no `draft`; `cast`, `vfx`, `buff`, `synergies`, `required_weapons: []`) and `_schema.entry.buff`.
- `SampleProject/Resources/Data/sound_events.json`: `cast_<id>_windup` / `_release` for the 7, reusing files (drawKnife / impactPlate for the stances, cast_heal for Breath and Aegis, cast_electric for the cries, cast_fire for Blood Price).

## Tests
- `verify_skills_stance` (new, DesertRoad, real enemies) — RESULT: ALL PASS:
  - [1] Counter Stance: Block pose, SP 10 paid, HUD icon, magic shield; a blow takes nothing and the attacker takes 290 (= skill damage); HeavyStrike; one answer ends it; a blow from behind is answered too;
  - [2] a red blow hurts, no counter, the stance breaks, the hero staggers;
  - [3] after 0.8 s a blow lands again;
  - [4] Mirror Stance: a real archer's arrow flies back and hits the archer for 12; the stance holds; a melee blow still hurts;
  - [5] Centered Breath: refused out of battle; HP 20 → 75, SP 10 → 18; a blow in the channel heals nothing;
  - [6] Battle Cry: a hit deals 35 instead of 30; the ordinary enemy flinches, the elite and the far one do not; after 8 s it is back to 30 and the icon is gone;
  - [7] Aegis: holds 85; a soaked blow costs no HP and causes no stagger; a bigger one lets 20 through and the barrier is gone; it fades after 5 s;
  - [8] Blood Price: HP 100 → 90, SP 4; 3 hits deal 45 (base 30), the 4th 30; refused at 10 HP with nothing paid;
  - [9] Rally: refused with no party; with the guard offered, its assist does 999 → 1399 damage and stays 0.40 → 0.60 s; Rally is spent;
  - [10] respawn clears everything.
  - Without this branch's code `sm.stances` does not exist and every section fails.
- `verify_skill_rules` [11]: 15 planned (was 22); the 7 are built (cast, effect, synergies); a stance lasts its release; no built buff row keeps `draft` / `planned`.
- `verify_skill_fx` [1]: the 7 use `StanceSkill.tscn`, the placeholder, with no frames of their own until the art lane (as the movement skills did before H3).

## For the art lane (ComfyUI, slice 7)
- **Counter Stance:** a guard pose (it borrows Block) and a counter-cut pose (it borrows HeavyStrike); a flash when the blow is caught.
- **Mirror Stance:** a mirror guard pose (it borrows Block); a ring or mirror plane in front of the hero; a glint when an arrow turns.
- **Centered Breath:** it borrows Meditate → CastPalmRelease; it needs a breathing aura during the channel and a calm burst on release.
- **Battle Cry:** a shout pose (it borrows CastStorm); a shout wave ring along the ground; a buff glow on the weapon while it lasts.
- **Aegis:** a raise-hand pose (it borrows CastPalm); its own barrier of light around the hero. It now borrows the magic block shield (H2), which stands in front only.
- **Blood Price:** a self-cut pose (it borrows CastFire); a blood burst from the hero; a red glow on the next 3 hits.
- **Rally:** a banner-raise or call pose (it borrows CastStorm); a gold mark on the companion who comes next.
- **Icons:** all 7 have one (`Assets/UI/Icons/skills/<id>.png`), and they are used in the HUD status row as they are; a small status variant may read better at 10 px.
- **Sounds:** a shout for Battle Cry, a heartbeat or cut for Blood Price, a mirror ring for Mirror Stance; the current ones are reused files.

## Not done / open
- The tooltip shows damage / heal only. It does not list buff values (time, +%, absorb). That needs new `en.po` / `uk.po` keys and is left for the tooltip pass, as slice 3 also left it.
- The glass shield stays off (Q115).
- Battle Cry raises the hero's hits, not skills. Whether it should also raise skill damage is a product call. It is noted here, not filed as a Q.
- Figma has no frames for these skills, so there was nothing to compare.
