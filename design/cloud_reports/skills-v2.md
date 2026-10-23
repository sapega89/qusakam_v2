---
type: report
tags: [cloud, skills, v2]
branch: cloud/skills-v2
---

# cloud/skills-v2: skills v2, slice 1 (data, passives, caps, paid respec)

**Summary**
- **Done:** all 33 v2 skills are in `skills.json` as drafts (`[DRAFT]` / `[ЧЕРНЕТКА]`), each with its tree, level, kind, JP cost, prerequisites and gate. Every tab now holds 19 skills: 10 active and 9 passive.
- **Done:** the 5 new passives work: Keen Edge, Heavy Hand, Shield of Faith, Embers Within and Light Feet. The 28 new actives are `planned`. They cannot be learned, cast, used or ranked up (`Result.PLANNED`), and the skills screen shows them locked as "Later", with the text "Coming later: this skill is not built yet."
- **Done:** the JP caps are re-tuned to **14 for the base tree and 12 for each profession** (were 12 / 10).
- **Done:** respec now costs coins and is done only at a meditation spot: **10 coins × spent JP, at least 10** (provisional). The free reset (`reset_free`) is gone, and the oath stays (D570). The oath keepers no longer offer the respec.
- **Not done:** no button triggers the paid respec yet. The keepers' entry is gone, and the meditation spot has no Reset UI until slice 2 builds the skills screen (D626 default below).
- **Not done:** there is no new screenshot. `capture_skill_trees.gd` now stops on the tutorial window "Moving and Jumping" (a stale capture, not caused by this branch).
- D-ID text: D626–D629 below. No B rows fixed.
- **Full suite:** `SUITE: 2 FAIL` → after the locale fix: 101 PASS, 1 FAIL.
  - `verify_locale`: one key was missing from `en.po` and is fixed. `uk.po` lacked a blank line between two entries, so `po_sync.py` dropped a key; the blank line is added.
  - `verify_onboarding` ("keyboard: a light hit does not pass Heavy") fails the same way on `origin/feature/backlog` and is not caused by this branch.

## D-ID text (for the orchestrator)

| ID | Kind | Text |
|---|---|---|
| D626 | OVERRIDE | **Skills v2, slice 1: the 33 draft skills are in the data** (D535; agent call; names and texts are drafts, `[DRAFT]` in en and `[ЧЕРНЕТКА]` in uk). Each tab holds 19 skills, 10 active and 9 passive. JP costs: 1 for levels up to 10, 2 for levels 12 and up. Gates: 3 base JP for level 5, 6 for levels 8–18. New prerequisites: Ground Slam ← Rising Slash, Counter Stance ← Shield Bash, Keen Edge / Heavy Hand ← Weapon Training, Lightspear ← Radiant Smite, Heaven's Anvil ← Shield Charge, Radiant Flare ← Lightspear, Shield of Faith ← Mending Hands, Blood Price ← Blood Pact, Night Reaper ← Searing Hex, Hellfire Stomp ← Night Reaper, Soul Harvest ← Blood Rush, Embers Within ← Searing Hex, Stone Palm ← Balanced Strike, Mirror Stance ← Sand Veil, Dune Quake ← Wind Step. **The 28 new actives are `planned: true`**: `SkillManager` answers `Result.PLANNED` to learn, rank-up, cast and use, even when the skill is already in a save. The skills screen shows them locked with "Later" and "Coming later: this skill is not built yet." Each later slice (3–6) removes `planned` from the skills it builds and adds their numbers. **The 5 new passives work**, through `passive_value` (D529), at rank 1 and +10 % per rank: Keen Edge `crit_chance` +5 % (within the D393 crit cap); Heavy Hand `heavy_poise` +30 % guard damage on the heavy attack; Shield of Faith `block_heal`, where a held block with a shield heals 25 % of the blocked hit; Embers Within `burning_damage`, where a burning enemy takes +20 % from the hero's swing, skill or arrow (not from the burn's own ticks); Light Feet `roll_length`, where the roll lasts 20 % longer at the same speed, so it goes 20 % further and stays invulnerable 20 % longer. To fit levels 14 and 16, the skills screen's tiers are 4 px apart (were 8) and its nodes are 42 px tall (were 44): 14 tiers in 640 of 663 px. This is a stopgap until slice 2 redraws `485:6490`. |
| D627 | OVERRIDE | **JP caps for 19 skills a tab: base 14, profession 12** (D530 re-tuned; agent call, provisional). Learning a whole tab costs 23 JP in the base tree and 26 in each profession. The hero has 19 JP at level 20. Both caps sit well under a full tab (61 % and 46 %), so even a higher level cap would not max a tab. Their sum (26) is 7 over the 19 JP the hero has, so where those JP go is the build choice. One way is 10 base JP (the ultimate's gate) + 9 profession JP, which reaches the ultimate path (Radiant Smite 1 + Skyfall 2 + Judgement 2 = 5) and 4 more. Another is 14 base + 5 profession, which gives the whole trunk and the ultimate path. A third is 7 base + 12 profession, the widest profession but no ultimate. Today's built skills cost 14 in the base tree (equal to its cap) and 16 in each profession (over the cap). |
| D628 | OVERRIDE | **Paid respec at a meditation spot** (D592, D447; numbers provisional). `SkillManager.respec()` costs **10 coins per spent JP** (costs + ranks above 1, `spent_points()`), with a floor of **10 coins** when only attribute points are spent. It works only while the hero sits at a meditation spot (`SavePoint.meditating`, `SkillManager.is_meditating()`); elsewhere it returns `Result.NOT_MEDITATING`. It refunds every JP and attribute point and keeps the oath (D570). The free `reset_free()` / `can_reset_free()` (D490, D530) are removed. The price stays near D282's 10 × level: at level 20 with 19 JP spent it is 190 coins (was 200), and at level 5 with 4 JP spent it is 40 (was 50). The oath keepers' "Unlearn skills and attributes" entry is removed, since the respec moved to the meditation spot. |
| D629 | GAP | **Where the respec button lives at a meditation spot** (agent default; Sapega to confirm). Default: D490's **Reset** button on the skills screen (D489, slice 2) is enabled only while the hero meditates. Elsewhere it is disabled with "Reset at a meditation spot". During meditation the save screen opens (D447), and it would get a way into the skills screen. Until slice 2 nothing triggers `respec()`. The three keeper strings ("Unlearn skills and attributes (%d coins)", "Not enough coins (%d needed)", "Forget every skill and attribute point for %d coins") stay in the `.po` files for that screen. |

## Details

### Data (`SampleProject/Resources/Data/skills.json`)
- 76 skills (was 43). Every tab has 19: 10 active, 9 passive, 2–3 conditional passives, and one ultimate per oath.
- New field `planned` (bool) in `_schema.entry`, read by `SkillDefinition.planned` (`Scripts/Systems/SkillDefinition.gd`).
- The `passive.stat` list adds `crit_chance | heavy_poise | block_heal | burning_damage | roll_length`.
- `class.jp_cap` 14, `oaths.*.jp_cap` 12.
- Texts: 66 new uk.po entries (name + description) plus 6 UI and tooltip strings. `en.po` was regenerated by `po_sync.py`. `po_data_keys.py`: 0 missing.

### Code
- `SkillManager.gd:46-47`: new results `PLANNED` and `NOT_MEDITATING`. `PLANNED` is checked in `check_upgrade` (:130), `can_use_skill` (:262, before `NOT_UNLOCKED`, so a save that holds the skill still cannot cast it) and `check_unlock` (:456, before the oath and level checks).
- `SkillManager.gd:54`: `RESPEC_COINS_PER_JP`, `RESPEC_MIN_COINS`. `respec_price` is at :561, `can_respec` / `respec` / `is_meditating` at :565-588. `reset_free` is removed.
- Keen Edge: `GameManager.crit_chance_from()` (:271), shared with the equipment screen's crit row (`equipment_component.gd`).
- Heavy Hand: `PlayerCombat.gd:473`.
- Shield of Faith: `Player._heal_on_block()` (:519), called on a held block. The shield check moved into `Player._shield_in_hand()`, now shared with Shield Block.
- Embers Within: `DefaultEnemy.gd:566`. A source in the player group or a hero arrow counts; the burn tick (no source) does not.
- Light Feet: `PlayerMover.gd:52,123`. `roll_length` is the current roll's length, and the double-dash chain window uses it.
- `SkillTooltip._passive_text`: texts for the 5 new stats.
- `skills_component.gd:383,544`: the "Later" note and the "Coming later" reason.
- `OathKeeper.gd`: the respec entry and its confirmation are removed (D592).

### Tests
- `verify_skill_rules` (ALL PASS) covers:
  - [1]: 10 actives / 9 passives per tab, level 20 = the oath's only ultimate, caps 14 / 12, every tab's full cost over both its cap and the 19 JP of level 20.
  - [5]: the cap walk at 14 / 12.
  - [10]: the paid respec (NOT_MEDITATING, the price = 10 × JP, coins taken, the oath kept, no `reset_free`).
  - [11]: 28 planned actives refuse learn / cast / use / rank-up / plan pick.
  - [12]: each of the 5 passives measured in play code.
- `verify_skill_trees` (ALL PASS): 19 per tree with 10 actives; `planned` only on draft actives; built actives still need a cast and effect; the respec is refused away from a spot and when sitting without coins; the attribute-only floor price.
- `verify_skill_screen` (ALL PASS): 14 tiers; 11 links in the Paladin view; Dash Strike locked with "Later" and the "Coming later" text; every node inside the tree panel with no scroll.
- `verify_oath` (ALL PASS): a keeper offers only Talk after the oath; `respec()` → NOT_MEDITATING; the oath stays.

### Notes
- `capture_skill_trees.gd` shows the "Moving and Jumping" tutorial window over every shot now. It needs to close tutorials, or turn them off in settings, before its shots. Candidate B row.
- Godot's `--import` creates untracked `.import` / `.uid` files on this branch's base (hero panel, hotbar SVGs, `QuickPotion.gd.uid`). They are not committed here.
