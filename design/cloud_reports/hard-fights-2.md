---
type: report
tags: [cloud, combat, difficulty, bosses]
---

# Cloud report: hard-fights-2

**Summary.** Done: all five of Sapega's notes, all in the existing enemy move system (`EnemyLogic` / `BossLogic`).
(a) **B159 (fixed):** the bosses did not swing at a hero who stood just out of reach. They rested 30–90 px from the hero, but their combo only reaches 69–72 px, so between 70 and 90 px they only slammed and drank. The Mayor Hall fight also showed no boss bar and started the boss walking "home". (b) Speeds go up 1.25–2.6× (D767). (c) Lunges from 120–260 px (D768), and the jackal's pounce, latch, bite and shove (D769). (d) Elites, the jackals, the vulture and the bat are bigger (D766). (e) Enemies walk round the hero to his other side. The token is now 2, all from one side (D770).
`verify_masher` ALL PASS. MASHER beats the lone bandit at 63 % HP and loses everything else in both builds; GOOD wins all nine, no second tries needed. The new [4] (bosses met through their real intro) fails 3 checks on the old code and passes now.
D-IDs: D766–D770 (text in §6). B rows fixed: B159.
Not done: new poses (list in §5, for the orchestrator). Bosses got no lunge move.
Full suite: `SUITE: 1 FAIL` (`verify_enemy_stagger`, which expected walk at ×1.0; fixed for D767 and green when re-run alone), §7.

## 1. (a) The bosses do not hit: B159

**Reproduced** with the real room start: Arrival marker, walk right into the trigger, the cutscene read through (and also skipped with a Tab hold), the boss bar, `boss_fight_changed`. Checked in the round-13 build (`2a935ba9`), in `cloud/hard-fights`, headless and in a window.
- The hero walks into the boss and mashes: both bosses hit. In the window this was 9 swings and 7 hits in 25 s.
- The hero stands 80–90 px from the boss (just out of the axe's reach, or after a roll past it): **0 weapon hits**. Only `BossShockwave` lands, 7 of 7 times. The boss stands at 89 px and slams over and over.

**Root cause.** `BossLogic.handle_attack_state` keeps the boss at `preferred_range` 60 ± `PREFERRED_BAND` 30 px between moves. But `combo.max_range` is 69 (Scorpicore) and 72 (mercenary). At 70–90 px the combo never fits. `pick_move` skips it for the slam (or the drink), and the boss never steps in. A second problem: `MayorHall._fight()` did not do what `LabBoss._fight()` does. There was no `on_player_detected`, so no boss bar until the boss happened to notice the hero. Its home stayed at its pre-cutscene spot, so the fight started in `RETURN_HOME`. It had the default leash.

**Fix.**
- `BossLogic.gd`: a melee boss (its `preferred_range` is inside its combo's reach) rests no farther than `combo reach − COMBO_MARGIN` (6 px).
- When the combo is next in the pattern and the hero is up to `COMBO_STEP_IN` (60 px) beyond its reach, the boss steps in instead of skipping the combo. The ranged djinn is unchanged.
- `MayorHall.gd` `_fight()`: detection, chase and leash range = the hall's width, home = where the boss stands after the cutscene, `on_player_detected` at once.

**Test:** `verify_masher` [4]. Each boss is met through its room's intro, then:
- (a) the hero stands and mashes for 12 s: the boss's own weapon (source = the boss, not the wave) lands ≥ 2;
- (b) the hero stands 86 px behind it for 6 s: the weapon lands ≥ 1.

| | old code | new code |
|---|---|---|
| Mayor Hall: boss bar at fight start | FAIL (bar false) | OK |
| Mayor Hall: stands and mashes | 4 swings, 3 land | 4 swings, 3 land |
| Mayor Hall: waits 86 px behind | **2 swings, 0 land** | 3 swings, 1 lands |
| Laboratory: stands and mashes | 4 swings, 2 land | 3 swings, 2 land |
| Laboratory: waits 86 px behind | **1 swing, 0 land** | 2 swings, 1 lands |

## 2. (b) Speeds (D767)

The hero walks at 300 px/s, ramping to 400 (`PlayerMover.speed_min/max`). Enemies chase at `speed`, run at ×1.8 (`RUN_PACE`) when far, and step in to strike at ×1.4.

| kind | speed before → after, px/s | run (×1.8) after |
|---|---|---|
| bandit (melee) | 70 → 180 | 324 |
| shield-bearer, tower shield guard | 55 → 150 | 270 |
| bandit brute | 55 → 140 | 252 |
| jackal, cursed jackal, pack leader | 120 → 200 | 360 |
| scorpion, armoured scorpion | 50 → 130 | 234 |
| archer / heavy archer | 60 → 130 / 45 → 110 | 234 / 198 |
| vulture, old vulture | 120 → 200 (the vulture keeps the jackal's speed, verify_flying_enemies) | – |
| bat / Cthulhu fly | 120 → 170 / 120 → 150 | – |

Light kinds now run faster than the hero walks; heavy kinds run slower than he walks, but not slowly. New `EnemyStats.stride_speed` (the old speed): the walk animation plays at `pace × speed / stride_speed`, so the feet don't slide.
Measured in `verify_masher`: the time from the start (hero 260 px from the fight's nearest point) to the first enemy at its engage range was 0.9–1.0 s before and 0.6–0.7 s after, in every non-boss fight.

## 3. (c) Lunges and the jackal pounce (D768, D769)

New `EnemyStats` fields `lunge_from / lunge_to / lunge_windup / lunge_tell / lunge_chance / pounce`, and the move `EnemyLogic.perform_lunge()`:
- **When.** The enemy is ready, the token is free, the hero is on its floor at `lunge_from`–`lunge_to`, and there is ground ahead; then a `lunge_chance` roll. A failed roll is retried after 0.8 s; lunges come at most once per 2.5 s (`LUNGE_REST`).
- **The move.** A short wind-up with the D504 tell (white, so it can be blocked), then a 0.2 s dash with the hitbox live. The dash goes to where the hero stood at the tell. The hero's body stops it (D443), and a roll goes through it.
- **Per kind.** Bandit stab 120–240 px, 0.5 s, chance 0.6. Shield-bearer and tower guard 120–220 px, 0.55 s, 0.4. Brute rush 120–240 px, 0.6 s, 0.5. Pack leader rush 150–260 px, 0.5 s, 0.6. Jackal and cursed jackal pounce 150–260 px, 0.5 s, 0.6.

**The pounce** (`pounce = true`) is a leap: the sprite arcs 34 px (`EnemyView.hop`) and the jump does no damage in flight. On contact:
- the hero is rolling (i-frames): it flies through;
- the hero blocks: it is turned away (a yellow tell would be a parry);
- another jackal is already latched: an ordinary bite in passing;
- otherwise it **latches** (`EnemyLogic._latch`). The hero is held in the Hurt pose (`PlayerCombat.hold`; hits during it add no stagger) and the jackal hangs on him in its frozen bite frame (`EnemyView.latch_pose`). The bite (×1.3 damage) lands 0.35 s later with a 0.09 s hit-stop. At 0.9 s the hero shoves it off (Block pose, `PlayerCombat.shove`). The jackal is thrown 160 px with a hop, lands, and is stunned 0.6 s.

Tested in `verify_combat_enemies` [10]:
- a bandit lunges ~150 px from 180 px away and hits;
- the pounce latches with no damage on contact, and the bite lands 0.35 s after the latch;
- the hero shoves the jackal ~198 px away and is free;
- a block turns the pounce away, and a roll goes through it;
- two jackals pounce at once and only one latches.

In `verify_masher` (all fights): 15 lunges for the masher, 5 latches on the masher, 0 on GOOD (it blocks white tells). Bosses keep their charges; I did not give them a lunge.

## 4. (d) Sizes (D766)

Drawn height = the opaque bounding box of the idle frame × the sprite scale. "Width" covers idle + walk frames, which for fliers is the wingspan. The hero is 52×72.

| kind | scale before → after | drawn before (w×h, h/hero) | drawn after (w×h, h/hero) |
|---|---|---|---|
| bandit, shield-bearer, archer | 1.5 | 70×75, 1.02 | unchanged |
| **bandit brute** (elite) | 1.0 → 1.15 | 81×86, 1.19 | 93×99, **1.37** |
| **tower shield guard** (elite) | 1.0 → 1.2 | 49×81, 1.12 | 59×97, **1.35** |
| heavy archer (elite) | 1.2 | 79×102, 1.42 | unchanged |
| **jackal (pack)** | 0.75 → 1.2 | 61×43, 0.59 | 97×68, 0.95 |
| **jackal pack leader** (elite) | 1.0 → 1.3 | 86×56, 0.78 | **112**×73, 1.01 (length 2.2× the hero's width) |
| **cursed jackal** (elite) | 1.0 → 1.25 | 83×58, 0.81 | **104**×72, 1.01 |
| scorpion | 2.25 | 74×52, 0.72 | unchanged |
| armoured scorpion (elite) | 1.25 | 128×92, 1.28 | unchanged (already bigger) |
| **vulture** | 1.0 → 1.25 | wingspan 59 (0.82 of the hero's height) | wingspan **74** (1.02) |
| old vulture (elite) | 1.0 | wingspan 96, 93 high | unchanged (still bigger than the vulture) |
| **bat** | 0.75 → 1.0 | wingspan 28 (0.39) | **38** (0.53) |
| **Cthulhu fly** (elite) | 0.75 → 1.125 | 38×63, 0.88 | 57×94, **1.22** |
| bosses | 1.5 | 120–135×160, 2.23 | unchanged |

- The pack jackal is ~84 % of the leader (√(w·h) 74 vs 89). The leader stays the biggest jackal.
- In the scenes, the sprite and the hit and hurt shapes grow from the drawn feet, and the body grows from its feet, so ground kinds stand on the same floor. Fliers' bodies are unchanged: a bigger body made the vulture's dive touch the floor in `verify_flying_enemies`.
- `attack_range` and `lunge` grow with the art (bandit brute 50 → 57.5, tower guard 42 → 48, leader 80 → 104 / 60 → 78, cursed 80 → 100 / 60 → 75, jackal 80 → 128 / 60 → 96, bat 50 → 66.7 / 40 → 53.3, fly 50 → 75 / 40 → 60).
- `verify_hit_areas` ALL PASS: the shapes equal the drawn frames (B128). `verify_flying_enemies` ALL PASS: fliers never touch the floor and patrol at their height.
- `verify_enemy_variety` [6], [6b]: jackal elites no longer copy the jackal's `attack_range` and `lunge`, which follow their own drawn size.

Shot: `design/shots/enemy_sizes/before_after.png` (`capture_enemy_sizes.gd`). The framing cuts off the hero and the fliers row; the bandit and jackal rows show the change.

## 5. Poses that are clearly missing (for the orchestrator to draw)

1. Jackal latched on the hero: biting the forearm or shoulder, hind legs off the ground (now: its attack frame frozen next to him).
2. The hero held by a jackal: a struggle pose with the jackal on his arm (now: Hurt).
3. The hero shoving the jackal off: a two-handed push or kick (now: Block, held 0.25 s).
4. The jackal thrown back in mid-air, tumbling, then landing (now: the stagger frames plus a hop of the sprite).
5. The jackal's pounce in the air: a stretched leap frame (now: the attack frames on an arc).
6. The bandit's lunge stab: a forward thrust with the arm extended (now: the slash frames during the dash).
7. The brute's and the leader's rush: shoulder down, mid-stride (now: attack frames during the dash).
8. An enemy rolling or slipping past the hero (D770): now a fast walk through him. A dodge or roll strip for the bandits and a leap for the jackals would sell it.

## 6. D-ID text (next free numbers at writing; the integrator renumbers)

| D766 | Sapega 26.10 | **Enemy sizes** («шакали молодші і громила якісь дуже маленькі, вони мають бути більшими»; «елітки мають бути більшими за Кусакама, і грифи й летючі миші теж якісь дуже крихітні»). Every elite is bigger than Kusakam and bigger than the kind it grows from: brute 1.37× his height, tower shield guard 1.35×, heavy archer 1.42×, armoured scorpion 1.28× (and 1.8× his height in length), Cthulhu fly 1.22×, pack leader 112 px long and cursed jackal 104 px (the hero is 72 px tall), old vulture 96 px wingspan. The pack jackal grows ×1.6 (about 85 % of the leader, who stays the biggest jackal), the vulture ×1.25 (wingspan 74 px ≥ his height), the bat ×1.33 (38 px, half his height). The art grows in its scene from the drawn feet, with the hit and hurt areas (B128) and the reach (`attack_range`, `lunge`). Fliers keep their bodies, so their paths stay clear of floors and ceilings. Table: `cloud_reports/hard-fights-2` §4. |
| D767 | Sapega 26.10 | **Enemies close in fast** («вороги якось повільно рухаються»). The hero walks at 300–400 px/s. Bandit 70 → 180 px/s, jackals 120 → 200, shield-bearers 55 → 150, brute 55 → 140, scorpions 50 → 130, archers 60 → 130 / 45 → 110, vultures 120 → 200, bat 170, fly 150. Light kinds run (×1.8) faster than he walks; heavy kinds run slower but are not sluggish. The walk cycle keeps its stride (`EnemyStats.stride_speed`). From the start to the first contact: 0.9–1.0 s before, 0.6–0.7 s after. Provisional. |
| D768 | Sapega 26.10 | **Lunges** («може треба якісь випади робити, щоб було складніше ухилитись»). Melee kinds lunge from mid range: a short wind-up (0.5–0.6 s) with a white D504 tell, then a 0.2 s dash with the strike, to where the hero stood at the tell. Standing just out of reach is not safe; a roll through it or a block beats it. Bandits stab (120–240 px, chance 0.6), shield-bearers 120–220 (0.4), the brute and the pack leader rush (120–240 / 150–260). At most one lunge per 2.5 s per enemy. Part of `EnemyLogic` (`perform_lunge`, `EnemyStats.lunge_*`). Bosses keep their charges. |
| D769 | Sapega 26.10 | **The jackal's pounce** («собака напригувати має, коли кусає»; «анімацію, як вона мене кусає, з затримкою»; «не стан як стан, а як я чекаю, поки пройде анімація кусання, і щоб ще я типу відштовхнув її після укуса»). The jackal's lunge is a leap that does not bite in flight. If it connects, it latches on, as a short scripted beat and not a status effect. The hero is held, the bite lands 0.35 s later with a hit-stop, and at 0.9 s the hero shoves the jackal off: it is thrown 160 px, lands and is stunned 0.6 s. Only one jackal latches at a time; a second one bites in passing. A roll under it or a block beats it. Poses still missing: `cloud_reports/hard-fights-2` §5. |
| D770 | Sapega 26.10 | **A group surrounds the hero** («в бою я дивлюсь — в них [Tails of Iron] вороги ходять один через одного, перекатуються, тобто не стоять в черзі, як в нас»). Ground enemies already pass through allies (D755). An enemy waiting behind another, with no one on the hero's other side, now walks through the hero at ×2.2 pace to its distance on that side. It is one walker at a time, each at most once per 3 s; only that pass lets the two bodies through each other, and otherwise the hero still cannot walk through enemies (D443). The attack token is 2 again (D576; D642 had 3), and a new attacker takes it only from the side the current attackers are on, so the hero has to turn but is struck from one side at a time. `verify_masher`: groups of 3+ had enemies on both sides of the hero 0–3 % of the time before, up to 87 % after. |

**B159** (fixed 2026-10-27, `cloud/hard-fights-2`). Sapega's playtest of the round-13 build: «боси не б'ють». Between moves both bosses rested 30–90 px from the hero, but their combo reaches only 69–72 px. A hero standing 70–90 px away (just out of reach, or after rolling past) never saw a weapon swing, only slams and drinks. The Mayor Hall fight also started without the boss bar, with the boss walking back to its pre-cutscene spot and with the default leash. Fix: `BossLogic` keeps a melee boss inside its combo's reach and steps in when the combo is next in its pattern; `MayorHall._fight()` sets the hall-wide ranges, the new home and the bar, as `LabBoss` does. Test: `verify_masher` [4] (through the real intro; 3 FAIL on the old code).

## 7. Tests

`verify_masher` (`masher_after3`, final numbers), compared with `cloud/hard-fights` running the same new measurement code:

| fight | MASHER SKILLS / STRENGTH before → after | GOOD before → after | both sides before → after (max of the 3 runs) |
|---|---|---|---|
| lone bandit | wins 63 % / 63 % → wins 63 % / 63 % | wins 100 % → 100 % | – |
| road's first fight | loses / loses → loses / loses | wins 51 % → wins 17 % | 0 % → 87 % |
| City Gates | loses / loses → loses / loses | wins 81 % → 62 % | 0 % → 9 % |
| lone brute | loses / loses → loses / loses | wins 100 % → 59 % | – |
| Lab middle | loses / loses → loses / loses | wins 54 % → 51 % | 0 % → 38 % |
| Mayor Hall boss | loses / loses → loses / loses | wins 56 % → 45 % | – |
| Caravan | loses / loses → loses / loses | wins 47 % → 84 % | 3 % → 1 % |
| cursed jackal | loses / loses → loses / loses | wins 100 % → 100 % | – |
| Laboratory boss | loses / loses → loses / loses | wins 63 % → 57 % | – |

Tuning on the way:
- With the token at 3 and no side rule, GOOD lost Lab middle and the Caravan on both tries: up to 56 swings "together" in one fight, from both sides.
- With 3 and the side rule, it lost only the Caravan.
- With 2 and the side rule, it wins all nine on the first try.

`verify_masher` also gains [5]: at least 5 lunges in all, at least 1 latch on the masher, and per bot some group fight with enemies on both sides ≥ 30 % of the time. The GOOD bot reads a lunge's reach (`lunge_to`) when it decides to block.

Combat verifies, each run alone: `verify_combat_enemies`, `verify_souls_combat`, `verify_combat_flow`, `verify_difficulty`, `verify_enemy_variety`, `verify_lab_boss`, `verify_mayor_boss`, `verify_mayor_hall`, `verify_bosses`, `verify_flying_enemies`, `verify_hit_areas`, `verify_combat_stats`, `verify_combat_player`: all `RESULT: ALL PASS`.

Tests changed to follow the new decisions:
- `verify_combat_enemies` [8]: the crowd stands on one side of the hero, and a new check that the other side waits (D770); the waiting enemy is held in place during the hand-off. New [10] for lunges and the pounce.
- `verify_souls_combat` [2], `verify_combat_flow` [2e]: the scripted series and bite pause the live AI's own lunge.
- `verify_combat_flow` [2e]: the tank is placed after the wait; [2d'] puts the hero back on the floor (faster enemies walked under him and he landed on a bandit's head).
- `verify_enemy_variety`: jackal elites' reach follows their size, and the foam check settles the wind-up lean first.

Full suite (Linux, Godot 4.6.2, run once): `SUITE: 1 FAIL`, 119 PASS. The failure was `verify_enemy_stagger` (2 checks): after a stagger, the walk plays at the kind's stride tempo (D767, e.g. ×2.57 for the bandit), and the test expected ×1.0. The check now expects `pace × speed / stride_speed` for walk; re-run alone: `RESULT: ALL PASS`.

## 8. Files

- Behaviour:
  - `Scripts/Gameplay/Characters/Bosses/BossLogic.gd`, `Scripts/Gameplay/Scenes/MayorHall.gd` (B159);
  - `Scripts/Gameplay/Components/EnemyLogic.gd` (lunge, pounce and latch, flank, side token);
  - `Scripts/Gameplay/Components/EnemyView.gd` (hop, latch pose, walk tempo);
  - `Scripts/Gameplay/DefaultEnemy.gd` (`stride_speed`);
  - `Scripts/Gameplay/Characters/Enemies/EnemyStats.gd` (new fields);
  - `Scripts/Player/Components/PlayerCombat.gd` (`hold`, `shove`, `is_held`; `stagger` split into `_break_action`).
- Data: `Resources/Enemies/enemy_stats_*.tres` (15 kinds), `Resources/Data/enemy_variety.json` (`max_attackers` 2).
- Scenes: `enemy_bandit_brute`, `enemy_tower_shield_guard`, `enemy_jackal_pack_leader`, `enemy_jackal_cursed`, `enemy_fast`, `enemy_vulture`, `enemy_bat`, `enemy_fly` (`.tscn`). `SampleProject/Maps/*` is untouched. Enemy hit effects are left to `enemy-fx`.
- Tests: `verify_masher.gd` ([4], [5], new columns), `verify_combat_enemies.gd`, `verify_combat_flow.gd`, `verify_souls_combat.gd`, `verify_enemy_variety.gd`. New capture `capture_enemy_sizes.gd`.
- Plan: `design/MASTER_PLAN.md` §3, rows B-boss, B-pace, B-size, B-pounce, B-group.

## 9. Open points (no Q-ID blocks)

- The road's first fight at level 1 is now sharp even for GOOD (17 % HP left; one of three full runs needed a second try earlier in tuning). The lever is the room (one jackal fewer), which belongs to the rooms routine, or the jackal's `lunge_chance`.
- B159 is filed in `design/BUGS.md` as fixed (the prompt asked for it). The decision register is not edited (ROUTINE_RULES): D766–D770 are above for the integrator.
- Numbers are provisional, for playtest.
