---
type: report
tags: [cloud, integrator, round-12]
---

# Integrator — round 12 (2026-10-24)

**Summary.** All six branches merged into `feature/backlog`, in order, none skipped (every report was present):
bugfix-1, loose-ends, big-mobs, journal-notes, charms, skills-dn. D-IDs renumbered to **D678–D691** and appended to
[[figma_decision_register]]. B rows removed from [[BUGS]]: B120, B121, B138, B141, B142, B143, B144, B146. B145 stays
open. Q89 and Q90 filed in [[questions_for_sapega]]; Q87 marked default built (D684), still open.
**Full suite: 117/117 `SUITE: ALL PASS`** (after two merge-interaction fixes; the first run was 110 PASS, 7 FAIL).

## Merged

| Branch | D-IDs (branch → register) | B fixed | Q | Conflicts |
|---|---|---|---|---|
| bugfix-1 | D674 → D678 | B142, B144, B138, B141, B143, B120, B121 | — | none |
| loose-ends | D675, D676 → D679, D680 | — | Q89, Q90 | none |
| big-mobs | D675–D677 → D681–D683 | — | — | none |
| journal-notes | D675 → D684 | — | Q87 default built | none (en/uk.po auto-merged) |
| charms | D675–D679 → D685–D689 | — | — | none |
| skills-dn | D675, D676 → D690, D691 | — | — | `SkillTooltip.gd`, `skills_component.gd`, en/uk.po |

skills-dn conflicts: the branch's `rank_factor()` ranks and detail layout, with the charms' `SkillManager.sp_cost()`
(Hermit's Amulet makes skills cheaper) kept in the SP rows; both .po blocks kept, no duplicate msgids. UITokens changed,
so the theme was regenerated (identical to the branch's).

## Merge interactions fixed

1. **The Lab fights spawned nothing** (6 tests: laboratory, lab_route, progression, xp_curve, difficulty,
   enemy_variety). The cursed jackal's sheet (D675) landed on `feature/backlog` while big-mobs made a big kind live by
   its sheet alone, so `BigSlot_JackalCursed` loaded a scene that does not exist. `EnemyVariety.available()` now also
   needs a big kind's scene and `enemy_stats_<id>.tres`; until then the slot spawns the ordinary jackal.
2. **E at the grandfather's notes opened the charm chest** (`verify_journal_notes` 10 FAIL). The two areas overlapped
   in the attic; the chest moved to x 480, the notes to x 640.

B146 is closed: `verify_lab_boss` (D676) and `verify_mayor_boss` (bugfix-1's D678) both pass.

## Not done / next

- The cursed jackal needs `enemy_jackal_cursed.tscn` and `enemy_stats_jackal_cursed.tres` to go live (its frames are in;
  `verify_enemy_variety` prints an INFO line until then). The other six big kinds still need their art.
- B145 (Canyon descent crash) is not reproduced; bugfix-1 thinks B142 (enchanted weapon) was the cause.

## What Sapega should test first

1. **The Canyon descent with an enchanted weapon equipped** (Windows build): B142 crashed the release build and is the
   likely cause of B145.
2. **The Mayor Hall boss** at its expected level: it now hits harder (D678), and the strength-only hero should lose.
3. **The Skills window** (D690, D691): ranks, Learn +1, Reset, and SP costs with Hermit's Amulet equipped.
4. **Charms**: the attic chest with Grandfather's Ring, the Charms block in Equipment, armour weight.
5. **Journal → NOTES** after reading the grandfather's notes in the attic (check the notes are still easy to reach at
   their new spot).
