---
type: report
tags: [cloud, fx, skills]
---

# skill-fx — the 9 oath actives get their own cast effects

**Done:** the 9 active oath skills now play their own art (`Assets/FX/Skills/<id>/`) through **one** shared scene,
`Scenes/FX/Skills/OathSkill.tscn` + `Scripts/FX/OathSkillFX.gd`, which builds its frames from the skill id: `charge` 1–2, then
3–4 looping in the casting hand during the wind-up; `release` 1–3 once, pinned as each README says; ×1.5 pixel scale,
mirrored with the hero's facing. The tinted copies `RadiantSmite/SearingHex/BalancedStrike.tscn` are deleted; the three
base skills keep their scenes. **Not done:** particle accents (base effects have them; the oath art is frames only).
**D-ID text (amends D279):** «Oath actives have their own art: `OathSkill.tscn` plays `Assets/FX/Skills/<id>/charge_1–4`
(1–2, then 3–4 looping) during the wind-up and `release_1–3` at the release, anchored per README; the tinted copies are gone.»
**B row fixed (new, found here):** casting any oath active asserted in `SoundHooks` (`unknown sound event 'cast_<id>_windup'`)
— no sound events existed; each now reuses the base cast sounds of its pose. **Full suite:** see the last line below.

## Changes
- `SampleProject/Scripts/FX/SkillCastFX.gd` — `var skill: SkillDefinition` (set by `PlayerCombat.begin_cast` before
  `add_child`), `phase()` for tests; `$AnimationPlayer` is looked up lazily so the subclass needs none.
- `SampleProject/Scripts/FX/OathSkillFX.gd` — extends it; `RELEASE_PIN` id → [marker, texture edge]:
  arcs (radiant_smite, eclipse_cleave) right edge on `ArcEdge` (84, −4), like `Smear/arc`; streaks (searing_hex,
  balanced_strike) and the claw (withering_grasp) left edge on the forward `Hand` (36, −2), like `Smear/thrust`;
  sky beam / lance (skyfall_blessing, judgement_of_the_sky) bottom tip on `GroundFront` (56, 24); second_wind bottom on
  `Feet` (0, 24); dervish_whirl centred on `Centre` (0, 4). Charge sits on the marker named after the cast pose
  (`CastPalm` (9, 0), `CastFire` (21, 9), `CastStorm` (−7, −33) — `WeaponView.CAST_POSES`). 12 fps charge, 10 fps release.
- `SampleProject/Scenes/FX/Skills/OathSkill.tscn` — AnimatedSprite2D (nearest filter, ×1.5) + the markers (layout).
- `skills.json` — the 9 `vfx` → `OathSkill.tscn`.
- `sound_events.json` — `cast_<id>_windup/_release` for the 9 (CastStorm → electric, CastFire → fire, CastPalm → heal
  sounds); per-skill sounds remain D276 work.
- The 9 READMEs: "Not wired" → wired. `scorpion/stagger.png.import` was missing from the repo; committed.

## Calls made (owner unreachable)
- Release anchors for skills whose README names only the texture edge: I placed the strikes at the strike reach in front
  and the self-heal (second_wind) at the hero's feet. skyfall_blessing strikes in front *and* heals, so it falls in front.
- A 0.35 s wind-up shows charge 1–4 exactly once at 12 fps; the 3–4 loop is visible from 0.5 s wind-ups.

## Tests
- `verify_skill_fx` (new): `RESULT: ALL PASS` — every active has its own frames (none shared), README frame counts,
  each of the 9 cast both facings: charge (1–2 then 3–4) → release → gone, mirrored.
- `verify_skill_casts`: `RESULT: ALL PASS`.

## Shot
`design/shots/skill_fx_all.png` — the 9 releases in the order radiant_smite, skyfall_blessing, judgement_of_the_sky,
searing_hex, withering_grasp, eclipse_cleave, balanced_strike, dervish_whirl, second_wind (`capture_skill_fx.gd`).
The icy-blue streak on the enemy in every panel is the existing hit effect (`Hit/cut`), not the skill.
