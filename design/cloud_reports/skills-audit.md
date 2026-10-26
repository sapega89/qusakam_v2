---
type: cloud-report
branch: cloud/skills-audit
date: 2026-10-26
tags: [cloud, skills, oaths, art, audit]
---

# Cloud report: skills-audit

**Summary.** Done: [[skills_audit]] (76-skill table, gear check, proposals, art queue) and MASTER_PLAN §4 row S19.
Documents only: no code, data or scene change, so no Godot run and no test suite (not needed; nothing executable changed).
Findings: 48 skills work, the 28 v2 actives have no handler / pose / VFX; all 12 built actives share 3 two-frame poses
(the ultimates and Dervish Whirl borrow a wrong one); 5 skills need a shield the hero can buy (City merchant, blacksmith
recipe) but is never seen holding; no mace or dagger exists anywhere in the world; 29 skills repeat another's stat.
Recommended: rework the 5 shield skills shield-free (Steady Guard, Pommel Strike, Samal's Advance, Samal's Mercy, Read the
Blow) and take the shield off the hero's gear; one coherent 19-skill kit per path under D728. Art queue: 14 poses, 30 VFX,
16 icons. No D-ID (nothing decided: the choices wait for Sapega); no B rows fixed.

## Details
- Start: `origin/feature/backlog` at `7b200f0b`.
- Proposed D-ID text for the orchestrator, once Sapega picks: «Shield skills reworked without a shield (skills_audit 3.1
  option a); the hero's shield slot and `iron_shield` leave his gear» or «the hero gets a visible shield (option b)».
- Candidate B rows (not filed, BUGS.md is the orchestrator's): `iron_mace` and `iron_dagger` have no source, so Electric
  Strike's mace and Fire Strike's dagger can never be held; `skills.json` → `oaths` still names the Sky keepers and the
  witch (D718/D726); three skill names still say «Sky».
- Open questions for Sapega (in the doc): (a) or (b) for the shield; keep `iron_shield` as an invisible armour piece or
  remove it (default remove); rename the base tree «Holy Warrior» for the no-god path (default keep).
