---
type: report
status: done
tags: [skills, combat, cloud-report]
---

# Cloud report — skill rules from Sapega's 2026-10-23 calls (B137, D490, D491, D496, D497, D504)

**Summary.** Done: skills scale with Phys. Atk. / Elem. Atk. (B137); SP comes from landed hits (2) and parries (6), not
over time, and only ultimates keep a cooldown (D504); Healing Palm is a 3-sip flask refilled on a save-screen save (D504);
each oath's level-18 active and level-20 passive swapped, the level-20 skill is an active ultimate (60 s cooldown, screen
shake, `ultimate` flag) (D491); synergies, 11 new conditional passives (drafts) and tooltip data (D496); JP caps per tree
and base-tree gates for profession skills, a free respec API (D497, D490). Not done: the HUD's double gold ring and the
Reset button (later branches, D453 / D489); the oath keepers' paid respec is left as is (see Open points).
D-ID text: **D523–D527** below. B rows fixed: **B137**. Full suite: RESULT_LINE_PLACEHOLDER

Branch `cloud/skills-data` from `origin/feature/backlog` 80dc164. Godot 4.6.2 headless; no captures (no screen changed
its layout).

## D-ID text for the register (agent calls; Sapega to confirm; all numbers provisional, tuned in playtest)

| D-ID | Kind | Text |
|---|---|---|
| D523 | OVERRIDE | **Skill power from the hero's attack; SP from hits** (B137, D504; agent call). Damage = (`damage` + `damage_scaling.phys` × Phys. Atk. + `damage_scaling.elem` × Elem. Atk.) × rank (+10 %/rank, D150) × Wisdom skill power (D335) × (1 + synergies, D496) × (1 + `skill_damage` passives). Heal is the same with `heal` / `heal_scaling` and `heal_power`. Shares: Fire Strike 1.3 / 0.3, Electric Strike 1.2 / 0.5, Radiant Smite 1.4 / 0.4, Skyfall Blessing 1.6 / 0.4 (heal elem 0.6), Searing Hex 1.3 / 0.5, Withering Grasp 1.8 / 0.4, Balanced Strike 1.4 / 0, Dervish Whirl 1.8 / 0; ultimates below (D525). With Phys. Atk. 100 a Fire Strike hits for about 157 against a light swing of 100. SP no longer refills over time: a landed hit of the hero or his arrow on an enemy gives **2 SP**, a parry **6 SP**; a skill's own hits, burn ticks and companions give none. Sky's Grace and Wisdom's `sp_regen` become `sp_per_hit` (+0.5 and +0.05 per point per hit or parry). Every active skill but the three ultimates has cooldown 0. |
| D524 | OVERRIDE | **Healing Palm is a flask** (D504; agent call). 3 charges, 0 SP, no cooldown; a sip heals 25 + 1.0 × Elem. Atk. (synergy Devotion +6 %/rank). Charges live in `player_state.skill_charges` and are saved (a save without them: full). They refill on the new `EventBus.game_saving(slot)`, which the save screen (`LoadGameMenu._save_to_slot`) emits **before** writing, so the save already holds a full flask; the D413 auto-save on room change does not emit it. A sip interrupted by a hit is spent, as SP is (D259). |
| D525 | OVERRIDE | **The oath ultimates** (D491; agent call). Swapped: Judgement of the Sky / Unbroken Vow, Eclipse Cleave / Crimson Thirst, Second Wind / Perfect Balance — the active is now level 20 and `ultimate: true`, the passive level 18. Judgement of the Sky 80 + 4.0 Phys. + 1.0 Elem. (chain 0.6, stun 0.6 s); Eclipse Cleave 90 + 4.5 Phys. + 0.8 Elem. (chain, burn); Second Wind heals 120 + 1.0 Phys. + 2.0 Elem. and now needs Dervish Whirl, as the other two need their level-12 active. Cooldown 60 s each, SP costs unchanged (16 / 18 / 14), casts unchanged. A used ultimate shakes the camera 9 px for 0.5 s (`VFXHooks.shake_camera`, off with Settings → Screen Shake) and rumbles the pad. `SkillDefinition.ultimate` is the flag the hotbar's double gold ring (D453) will read. |
| D526 | OVERRIDE | **Synergies, conditional passives and the tooltip** (D496; agent call; names and texts are drafts, `[DRAFT]` in en and `[ЧЕРНЕТКА]` in uk). Synergies (`synergies: [{skill, per_rank}]`): Healing Palm ← Devotion 6 %; Fire Strike ← Weapon Training 6 %, Riposte Instinct 4 %; Electric Strike ← Weapon Training 6 %, Devotion 4 %; Radiant Smite ← Sky's Grace 6 %, Zealous Answer 4 %; Skyfall Blessing ← Mending Hands 8 %, Sky's Grace 5 %; Judgement of the Sky ← Aura of Resolve 6 %, Unbroken Vow 6 %; Searing Hex ← Dread Aura 6 %, Dark Riposte 4 %; Withering Grasp ← Blood Pact 6 %, Relentless 4 %; Eclipse Cleave ← Crimson Thirst 6 %, Dread Aura 6 %; Balanced Strike ← Sand Stance 6 %, Still Water 4 %; Dervish Whirl ← Dervish Rhythm 6 %, Unshakable 4 %; Second Wind ← Iron Body 8 %, Rooted Resolve 4 % (per rank of the source). Conditional passives (`passive.condition: {type, value}`, counted by `SkillManager.passive_value` only while true; types `below_hp`, `after_parry`, `after_skill`; new stat `skill_damage`), 1 JP each: trunk **Riposte Instinct** (L8, 3 s after a parry skills +25 %), **Last Stand** (L10, below 30 % HP −15 % damage taken); Paladin **Merciful Light** (L8, below 30 % HP heals +40 %), **Zealous Answer** (L10, 4 s after a parry skills +30 %), **Consecrated Ground** (L15, 3 s after a skill −10 % damage taken); Dark Knight **Desperate Hunger** (L8, below 35 % HP lifesteal +15 %), **Cruel Momentum** (L10, 3 s after a skill +6 attack), **Dark Riposte** (L15, 4 s after a parry skills +30 %); Warden **Still Water** (L8, 3 s after a parry −15 % damage taken), **Dervish Rhythm** (L10, 3 s after a skill poise +30 %), **Rooted Resolve** (L15, below 30 % HP poise +50 %). Trees end at 3 actives / 7 passives (trunk) and 3 / 8 (each oath). Their levels reuse existing tiers, so the skills screen keeps its 12 rows. Tooltip: `SkillTooltip.data(skills, id)` → rank, current and next-rank values (damage, heal, passive, SP, cooldown, charges), synergy rows and ready lines ("Rank 1: …", "Next rank: …", "Receives bonuses from:", "Mending Hands: +8% per rank (now +24%)", "Ultimate · cooldown 60 s", "Flask: 3 / 3 sips…"). The current screen's Effect fact uses the same `effect_text`. |
| D527 | OVERRIDE | **JP caps, profession gates and the free respec** (D497, D490; agent call). Caps in `skills.json`: `class.jp_cap` 12, each `oaths.<id>.jp_cap` 10; a learn or rank-up past the cap → `Result.TREE_CAP`. Gates as `base_jp` on each oath skill: 3 base-tree JP for level-5 skills, 6 for levels 8–18, 10 for the level-20 ultimate → `Result.BASE_TREE_GATE`, and `base_jp_missing(id)` says how many are still needed (the current screen shows it on the node and in the hint). The plan of the skills screen (D330) checks both with the planned ranks. Free respec API: `SkillManager.can_reset_free()` / `reset_free()` forgets every skill and attribute point, refunds every JP (each tree's spend is within its cap) and keeps the oath; `tree_budgets()` gives "spent / cap" per tree for D489's left column. |

## B rows fixed
- **B137** — skills ignored Phys. Atk.: `SkillManager.skill_damage` / `skill_heal` (`SkillManager.gd:157`, `:166`); `use_skill` uses them.

## Open points (not blocking)
- The oath keepers still offer the **paid** respec (D282, `OathKeeper.gd:57`); D490 makes respec free but puts the button on
  the new skills screen. Left as is; the D489 branch should either drop the keepers' entry or point it at `reset_free()`.
- Draft marks: the brief asked for `[ЧЕРНЕТКА]` in en too, but `verify_locale` [0]/[4] forbid Cyrillic in English text
  (en.po values are their English keys), so en carries `[DRAFT]` and uk `[ЧЕРНЕТКА]`, as `cloud/npc-flow` did (D517).

## Details
DETAILS_PLACEHOLDER
