---
type: report
branch: cloud/integrate-33
base: feature/backlog @ 56bcea6d (contains integrate-32)
date: 2026-10-28
---

# integrate-33

- **Merged (6):** skills-v2-ranged, skills-v2-stance, skills-v2-control-a, skills-v2-control-b, small-fixes, wire-leftovers, one at a time, each branch's own tests re-run after its merge. Not merged, as briefed: the room chain (wire-backdrops-2, rooms-finish, wire-backdrops-3*/-4*, prop-sizes*, wire-props*), lab-v3-now, lab-v3, lab-main-path, rooms-city, rooms-lab. No `Maps/*.tscn` edited.
- **IDs:** D874–D884 replace the placeholders (in code comments, data, tests and the six reports); **D885** is this merge's own call (below). Q123 is answered → **D881** (`Q123 ✅ D881`). No new B or Q IDs (next free stays **B210**, **Q126**; next D is **D886**).
- **Fixed:** B196 (D879). B124 stays open with its cause confirmed and the frame list (art lane). B110 narrowed to Roll and the fire/storm casts.
- **Planned skills:** all 28 v2 drafts are built, so **0 planned actives are left**. `verify_skill_rules` [11] now asserts 0 and checks the D535 gate on Soul Harvest marked planned for the check; `verify_skill_screen` [2]'s «Coming later» example is Radiant Flare marked the same way (no row in the data is still planned).
- **Task B:** `verify_camera_transitions` root found and fixed in the measurement: a frame that spans 2–3 physics ticks under the suite's load. Reproduced with a 70 ms stall (drop 13.5 px). No threshold changed.
- **Full suite:** `SUITE: 2 FAIL in 28 min 48 s, J=4` (nproc 4; 145 PASS). The two are the balance reds: `verify_difficulty` 17 FAIL and `verify_lab_boss` 2 FAIL. Both match `origin/feature/backlog` row for row (diffed against a worktree run).
- **Left:** balance (Q114, Q116–Q118); B124/B110 art (ComfyUI stopped → BACKLOG); the room chain; skill names still end in `[DRAFT]` (D808: their numbers are provisional).

## Per branch

| branch | conflicts | IDs | tests after its merge |
|---|---|---|---|
| skills-v2-ranged | none | D874 ← D-sv2r1, D875 ← D-sv2r2 | scripts_compile, skills_ranged, skill_rules ALL PASS |
| skills-v2-stance | skills.json `_schema`, SkillDefinition (fields, `from_dict`, `to_dict`), SkillManager.use_skill, verify_skill_fx, verify_skill_rules [11]: both sides kept; planned 22 − 4 − 7 = 11 | D876 ← D-sv2s1 | scripts_compile, skills_ranged, skills_stance, skill_rules ALL PASS; skill_fx 1 FAIL once, then ALL PASS (a frame sample of a charge loop; passed again after every later merge and in the suite) |
| skills-v2-control-a | skills.json, sound_events.json, SkillDefinition, SkillTargeting, SkillManager.cast_skill, verify_skill_fx, verify_skill_rules (planned → 6) | D877 ← D-sv2ca1 | `verify_skills_control_a` [4] **red on feature/backlog + control-a alone** (a worktree): Sweeping Arc hit the enemy behind. Fixed in `SkillTargeting.enemies_ahead` (D885 (1)). Then scripts_compile, skills_control_a, skill_rules, skills_ranged, skills_stance, skill_fx ALL PASS |
| skills-v2-control-b | 11 files. Both control slices added `ControlSkill.tscn` + `ControlSkillFX.gd` and `SkillCombatExecutor.apply_control`, and both added `enemies_ahead` | D878 ← D-sv2cb1 | control-a keeps `ControlSkill*` and `apply_control`. control-b's effect becomes **`AreaSkill.tscn` / `AreaSkillFX.gd`** (its uid is kept) and its call becomes `apply_area_control`. One `enemies_ahead` (control-a's, as fixed). [11] gets 0 planned. scripts_compile, skills_control_a, skills_control_b, skills_ranged, skills_stance, skill_rules, skill_fx, skill_screen ALL PASS |
| small-fixes | none | D879 ← D-sf1, D880 ← D-sf2, D881 ← D-sf3 (= Q123) | scripts_compile, starting_skills, companions, save_load_room ALL PASS |
| wire-leftovers | none (no Maps) | D882–D884 ← D-wl1..3 | scripts_compile, hero_feet, weapon_animations, skill_moves ALL PASS |

## D885 (integrator call, in the register)
1. **"Ahead" is the facing side.** `SkillTargeting.enemies_ahead` measures `reach` px forward from the hero's front edge and only takes enemies whose centre is on the facing side. An enemy grown by B187 is about 140 px wide. Standing 56 px behind the hero, its hurt rect (x 72–210) reached past his front edge (208), so Sweeping Arc hit it for 204.
2. **Two control effects.** 6a keeps `ControlSkill.tscn`. 6b's borrowed-oath effect is now `AreaSkill.tscn`.
3. **No planned actives left.** The D535 gate stays in the code and is still tested, on stand-ins (above).

## Task B: verify_camera_transitions
- The failing check was «reaching the right limit it slows down, no hard stop (biggest one-frame drop 6.75 px)» in BanditCamp. It failed only in the suite, under 4 parallel Godots.
- Traced runs (3 alone, then 5 at once plus 4 busy cores) always had 1 physics tick and delta 1/60 s per frame, and all passed. A forced stall inside the run reproduced the failure:

| stall | ticks / delta of the long frame | steps around it | result before fix |
|---|---|---|---|
| 70 ms | 3 / 0.066 s | −6.75, **−18.0**, −4.5 | drop 13.5 px FAIL |
| 120 ms | 7 / 0.116 s | −6.75, **−33.75**, −2.25 | drop 33.75 px FAIL |

- **Cause:** the smoothed camera moves in proportion to the frame's delta. A long frame shows up as a spike, and the next normal frame then reads as a "hard stop", even though the camera's speed did not change. The canvas read at the start of a frame is the previous frame's camera, so each step belongs to the previous frame's delta.
- **Fix:** `_run_steps` returns px per 1/60 s: each step is divided by its own frame's delta. On even frames the numbers are unchanged, and no threshold changed. A real hard stop would still fail, because it is a speed drop. After the fix the test passes with stalls of 45, 70, 120 and 190 ms, and in the suite (387 s).

## Balance reds (unchanged)
- `verify_difficulty`: `RESULT: 17 FAIL`. All 17 FAIL lines are identical to `origin/feature/backlog`.
- `verify_lab_boss`: `RESULT: 2 FAIL`: «balanced build: he dies in 2.3 of the mercenary's blows (351 HP; mace 129, club 206)», «the mercenary takes 67 light hits (6800 HP, Phys. Atk. 89)». Identical to the base.
