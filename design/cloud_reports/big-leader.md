---
type: cloud-report
branch: cloud/big-leader
date: 2026-10-24
tags: [cloud, combat, enemies]
---

# Cloud report: big-leader (the jackal pack leader goes live, D652 / D692)

**Summary.** Done: `jackal_pack_leader` is the first live big kind on the road. It has its own scene on the jackal's behaviour (`enemy_fast` numbers, the D692 sheet `Enemies/jackal_leader/sheet.png`), hit shapes measured from its frames (D519) and its own stats file. It is an elite through `kinds.jackal_pack_leader.elite` (D681), and the slot's level gives it D642 numbers: L2 454 HP / 41 hit. It has a bestiary entry in en/uk. There is one slot, `DesertRoad Fight_Dunes/BigSlot_JackalPackLeader_4`, and it now spawns the leader. D582 holds: no other big or cursed kind is in that fight, and the leader comes alone in the second wave, after a bandit and a jackal (its pack). Tests updated: `verify_enemy_variety` [6], `verify_difficulty` [3b], `verify_hit_areas` [1]/[3]. Capture: `design/shots/big_leader/pack_leader_dunes.png`. D-IDs: **D695** (text below; the orchestrator renumbers). B rows fixed: none. Full suite: `SUITE: ALL PASS` (117 PASS).

## D-ID text (for the register; the next free number after D692, lab-curse took D693–D694, renumber as needed)

| D695 | ROUTINE CALL | **The jackal pack leader, as built** (D652, D681, D682, D692; `cloud/big-leader`). `Scenes/Characters/Enemies/enemy_jackal_pack_leader.tscn` (on `default_enemy`, like the jackal) + `Resources/Enemies/enemy_stats_jackal_pack_leader.tres`. The stats are the jackal's `enemy_fast` numbers and behaviour: speed 120, lunge 60, windup 0.55, a three-hit combo with the parry finisher, 165 HP / 23 damage, 25 XP, `enemy_type = jackal_pack_leader`. `kinds.jackal_pack_leader.sheet` is the D692 pick `Assets/Characters/Enemies/jackal_leader/sheet.png`, 4×5 cells of 96×72: idle 0–1, walk 4–7 (running), attack 8–10 (crouch, leap, bite; the strike lands at 0.225 s on the leap, as the jackal's), stagger 12 (the hurt frame), death 16–18. **Drawn at sprite scale ×1.0**, as the cursed jackal (D693): the beast fills its cell (86×56 against the jackal's 35×28 at ×1.5), so on screen it is about 1.6× the jackal's length and still shorter than the hero (agent call). Paws on the jackal's line (+28 px vs +28.5). Shapes (D519): hurtbox 86×56 at (−1, 0), hitbox 41×57 at (20.5, −0.5), and attack_range stays 80. The glint `tell_at` (22, −20) is at the eye. No cursed foam: it is a living jackal. Elite from the kind (D681): at Fight_Dunes level 2 it has 454 HP and hits for 41, and the hero falls in 4 hits. `verify_difficulty` [3]: before the oath both builds win (STRENGTH needs 9 hits and survives 7 blows; SKILLS 10 and 8), as D668 asks of the road's elites. Coins 1–3 (the jackal's), voice pitch 1.0 (lower than the jackal's 1.15, agent call). Bestiary «Jackal Pack Leader» / «Ватажок зграї шакалів», en + uk. **Placement (D582, D682):** its one slot is `DesertRoad Fight_Dunes/BigSlot_JackalPackLeader_4` (spawn_id `Fight_Dunes_EnemySpawnPoint4`, unchanged). The fight's waves of 2 are a bandit and a jackal, then the leader alone 1.5 s later. It is the only big kind in its first encounter. The kind id stays `jackal_pack_leader` (D681), so slot names and saves keep their keys; only the sheet path moved to D692's folder. |

## Placements (D582 check)

| Room / fight (level) | Slot | Spawns | Big or cursed kinds in that fight |
|---|---|---|---|
| DesertRoad `Fight_Dunes` (2) | `BigSlot_JackalPackLeader_4` | `jackal_pack_leader` (elite, medium) | only the leader. `BigSlot_BanditBrute_1` still spawns a bandit (no brute art) |

That is the only `BigSlot_JackalPackLeader_*` on any map (`verify_enemy_variety` [6] walks every `Maps/*.tscn`).

**Watch when the bandit brute lands:** `Fight_Dunes` would then hold two big kinds, the brute in wave 1 and the leader in wave 2. The brute's own first encounter is the earlier `Fight_LoneElite`, so this is not a first meeting for either kind. Still, D582 wants big elite groups rare, so the brute's routine should decide whether Dunes keeps both, or whether `BigSlot_BanditBrute_1` there goes back to an ordinary bandit.

## What changed (files)

- `Resources/Data/enemy_variety.json`: `kinds.jackal_pack_leader.sheet` → `Enemies/jackal_leader/sheet.png` (D692's folder).
- `Scenes/Characters/Enemies/enemy_jackal_pack_leader.tscn` (new), `Resources/Enemies/enemy_stats_jackal_pack_leader.tres` (new),
  `Assets/Characters/Enemies/jackal_leader/sheet.png.import` (new).
- `Scripts/Gameplay/DefaultEnemy.gd` `_calculate_coin_drop`: `jackal_pack_leader` 1–3.
- `Resources/Data/sound_events.json` `enemy_voice_pitch.jackal_pack_leader = 1.0` (`SoundHooks` reads it by `enemy_type`).
- `Resources/Data/bestiary.json` + `en.po` / `uk.po`: the entry.
- Tests: `verify_enemy_variety` [6] (new), `verify_difficulty` (`KIND_NAMES`, new [3b]), `verify_hit_areas` (the scene in
  [1], its strike in [3]). New capture `UI/capture_big_leader.gd`.

## Results

- `verify_enemy_variety`: RESULT: ALL PASS. [6]: «in the game it is the pack leader, an elite at the fight's level 2: HP 454,
  damage 41.4». That check is the live `Fight_Dunes` spawner, so `EnemySpawnPoint.kind()` resolves the slot. Also
  «its drawn paws stand on a medium jackal's line (28.0 vs 28.5 px below its centre)». [2]: «jackal_pack_leader has its
  sheet, so it has its scene and stats».
- `verify_hit_areas`: RESULT: ALL PASS. «hurtbox (-44,-28) 86×56 = drawn body», «hitbox (0,-29) 41×57 = drawn strike»,
  «attack_range 80 starts a strike that reaches (body contact 28, reach 113)», hit at 3 px inside, missed at 6 px past.
- `verify_difficulty`: RESULT: ALL PASS. Rows: `elite jackal pack leader L2  2 STRENGTH 130 41 37 4 8 454 47 9 yes`,
  `... SKILLS 148 41 37 4 9 454 44 10 yes`. The «planned jackal_pack_leader» row is gone (the slot is live).
- Full suite (`Scripts/Tools/run_verify.sh`): `SUITE: ALL PASS`, 117 scripts PASS.
- Shot: `design/shots/big_leader/pack_leader_dunes.png` (`UI/capture_big_leader.gd`). The hero steps into the
  `Fight_Dunes` zone, and the log reads «spawned jackal_pack_leader elite=true HP 454 damage 41». Panel 1: the bandit and
  the jackal are on the hero while the leader runs in from the east. Panel 2: the leader's bite (attack frame 10), beside
  the jackal, clearly bigger than it and shorter than the hero. No visual defect found.
- While I was writing the capture, `Input.action_press(&"move_right")` did not move the hero in that script. The capture
  therefore places the hero inside the trigger. That limit belongs to the capture, not to the game, and the verify scripts
  do not depend on it.

## Notes

- Not merged with `cloud/lab-curse`. Both branches add a `_translated` helper and a new section at the end of
  `verify_enemy_variety.gd`, a line in `verify_hit_areas.gd` `KINDS`, a `KIND_NAMES` entry and a [3b] in
  `verify_difficulty.gd`, and a coin and voice line. Expect textual conflicts there: keep both sides, and renumber this [3b]
  to [3c] and this [6] to [7].
- `EnemyVariety.available` wants the sheet, the scene and the stats file. So on this branch `jackal_cursed` stays
  disabled: its sheet is here, but lab-curse adds its scene and stats.
- D692 also asks for the ordinary jackals to be redrawn in the leader's style (`jackal_pack` candidates). That is art, not done here.
