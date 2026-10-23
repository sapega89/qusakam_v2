---
type: report
status: done
tags: [cloud, combat, boss, lab]
---

# Cloud report — `cloud/lab-boss` (2026-10-23)

**Summary.** [[lab_boss_plan]] → "Boss replaced (D466)" slices 3 and 4 are done. The Laboratory boss is now the manticore-man mercenary (`lab_boss.tscn`) in `LabBoss`. The djinn stays only in the cells cutscene.
- **Moves.** A mace combo (two strikes, white then yellow), a club slam (a red shockwave), and a swig from the flask: no tell and no damage, it is the punish window, and he taunts in a bubble. Phase 2 starts at half HP.
- **Numbers (D642).** HP 6800, damage 180 (club ×1.6), checked by `verify_lab_boss` [11].
- **Story text.** The talk, cloak and victory dialogues are rewritten for him. The taunts, his name and the bestiary entry are drafts in uk.po / en.po.
- **Not done.** The tail sweep and charge of D466: D644 drew no frames for them. The D642 build simulation is still open, and no `cloud/difficulty` formula existed, so these numbers are hand-set.
- **D-IDs.** D660–D663 below. No B rows fixed.
- **Full suite.** `SUITE: 2 FAIL`. verify_story_journal failed on the old objective text in `story.json`; it is fixed and passes now. verify_combat_feel (bandit roll) passed on a rerun and is untouched by this branch.

## D-ID text (for the register)

| D660 | ROUTINE CALL | **The Laboratory mercenary's moveset, as built** (D466, D564, D644; `cloud/lab-boss`). `Scenes/Characters/Bosses/lab_boss.tscn` on BossEnemy / BossLogic (D316). **Mace** (`combo`, ≤ 72 px, first wind-up 0.55 s): two strikes, white then yellow (phase 2 yellow, yellow); the second strike has its own pose (`BossEnemy.finisher_animation`, mace row frames 14–15); recovery 0.6 s. **Club slam** (`slam`, ≤ 200 px, wind-up 1.1 s, red): the club goes up (frame 16), comes down (17), then back to the shoulder (18). A shockwave hits a grounded hero within 200 px for ×1.6; jump it or roll through. Recovery 1.0 s. **Swig** (new kind `drink`, ≤ 200 px, 1.4 s): drink row; no tell, no damage, `recovering` is true. It is the punish window, and he says the next taunt in a bubble. Pattern `combo, slam, drink, combo, slam, combo, drink`; phase 2 `combo, slam, combo, slam, drink`, wind-ups ×0.8, speed ×1.25, with a taunt as the phase starts. Poise 16, stagger 0.6 s (the hurt frame), preferred range 60 px, cooldown 1.0 s (D642: more aggressive). There is no tail sweep or charge: D644 has no frames for them. Provisional, for Sapega's play. |
| D661 | ROUTINE CALL | **The mercenary's numbers from D642** (no `cloud/difficulty` formula existed). Hero at level 16 (straight through the Lab, `xp_curve.json`) with the gear of that moment (silver sword, iron armour, helmet and shield), not blocking. **Balanced attributes** (19/19/19/18): 556 HP, Phys. Atk. 149. His series mace, mace, club takes 129, 129 and 206, so the hero dies in **3.6** blows. The boss has **6800 HP**, about **40** light hits (series 1.0, 1.0, 1.4). **Strength only:** 480 HP, dies in 3.1 blows; needs 29 hits. Without healing, guard or stagger skills that is 29 exchanges at 3 blows to death. Base damage 180, XP 500 (as the djinn, so `xp_curve` holds). `verify_lab_boss` [11] fails when these drift. Strength's diminishing returns (D642) are not built, so a strength build still shortens the fight. |
| D662 | ROUTINE CALL | **The mercenary in the story** (D555; name per Q79 still open). Boss bar, dialogue name and bestiary use "The Mercenary [DRAFT]" / «Найманець [ЧЕРНЕТКА]». Character `LAB_BOSS` (portrait from his idle frame, babble voice `bandit_leader`, boss voices `lab_boss_roar` / `lab_boss_laugh` reuse the generic boss roar and shout). The cloak beat (BACKLOG 17) stays with him: Lab_Boss_Talk (drunk, wants the cloak as a bonus), Lab_Boss_TakesCloak (he walks up and takes it, then Game Over), Laboratory_AfterBoss unchanged. Objective "Defeat the mercenary". Taunts (.po, [DRAFT]): "Hic! Hold still, lizard. I get paid by the head.", "Ha! Look at him dance!", "One more swig, then I flatten you.", phase 2: "You made me spill it! Now you pay." |
| D663 | TECH | **Bubbles and poses for bosses.** `DialogueManager.say_line_in_passing(speaker, text, anchor)`: one already-translated line as a passing bubble (the D263 chatter, silent during a talk). `BossEnemy.taunts` / `phase2_taunt` / `taunt_anchor` / `finisher_animation`; `EnemyView.on_attack_started(windup, anim)`. |

## Details

- `Scripts/Gameplay/Characters/Bosses/BossLogic.gd`: the `drink` kind in `perform_attack` → `_drink()`.
- `Scripts/Gameplay/Characters/Bosses/BossEnemy.gd`: `drink()`, `taunt()`, the finisher pose, and the taunt at phase 2.
- `Scripts/Gameplay/Scenes/LabBoss.gd`, `Maps/LabBoss.tscn`: the node is `Mercenary`. On a lost fight he walks to the hero instead of hovering.
- The hit shapes come from the drawn frames (`verify_hit_areas`): hurtbox 135×160.5, strike 67.5×139.5, melee_reach 67.5.
- Data: `sound_events.json`, `bestiary.json`, `journal_people.json` (not listed), `story.json` (objective), `build_portraits.gd`.
- The tests follow the new boss: `verify_lab_route`, `verify_audio` (lab_boss voices), `verify_hit_areas` (lab_boss.tscn), and comments in `verify_xp_curve` / `verify_lab_rooms`. `verify_enemy_stagger` does not list him: he has no `stagger.png`, and his stagger is the hurt frame of `sheet.png`.

### RESULT lines
- verify_lab_boss — ALL PASS. [5b] each move: tells `[block, parry]`, `[dodge]`, none for the swig. The mace takes 180 HP from a level-1 hero; the club takes 288 at 150 px and misses at 280 px. The swig shows a taunt bubble, and a real attack during it lands. Phase 2 starts at 3400/6800 with tells `[parry, parry]`. [11] D642: 3.6 blows / 40 hits; strength only: 3.1 / 29. B117: [5] places the hero for the move still missing (40 px for the mace, 150 px for the slam or swig).
- verify_lab_route, verify_hit_areas, verify_audio, verify_bosses, verify_story_journal — ALL PASS.
- Full suite: `SUITE: 2 FAIL` (verify_combat_feel: "after the roll the bandit blocks again", passed on a rerun; verify_story_journal: fixed afterwards, passes).

### Shots (`capture_bosses.gd -- <dir> lab`)
`design/shots/fb9_2_lab_{idle,mace,tell_mace,club_raise,tell_club,club_slam,drink}.png`. In `fb9_2_lab_club_slam.png` the club is on the floor and the hero 150 px away takes 288. The dust wave is faint at that moment (0.12 s into its 0.45 s). `tell_club` shows the red glint on the raised club.
