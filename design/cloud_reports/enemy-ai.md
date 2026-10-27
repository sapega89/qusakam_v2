---
type: report
tags: [cloud, combat, enemies, ai]
---

# Cloud report: enemy-ai

**Summary.** Done: all five points of Sapega's note, in the existing `EnemyLogic` / `BossLogic` / `ArcherLogic` (no parallel AI). Swings only start when they can reach, and they step in. Enemies follow a roll or a jump at once, punish openings, and read the hero: light kinds hop out of a heavy, shield kinds guard, archers kite and lead, and nobody swings into a block. After a series they step out of reach, the rhythm varies, and elites feint. Group tells come one at a time.
Measured in `verify_masher` (both bots, every fight) plus a new per-kind drill [6] where the hero rolls, jumps, walks off, blocks and swings:
- swings at the air in the drill: 10 % → 2 %;
- longest idle in reach: 1.29 s → 0.70 s (it was the bosses);
- GOOD lost by enemies after a roll: 3 → 0;
- slowest re-engage: 2.36 s → 1.34 s.

GOOD wins all nine on the first try. MASHER beats only the lone bandit, in both builds. `verify_masher`: `RESULT: ALL PASS`.
D-ID: D764 (§6). B rows fixed: B162, B163, B164, B165 (§6).
Full suite: see §7.
Not done: poses for the new moves (evade hop, guard, feint) are missing (§5). Bosses keep their patterns and do not feint.

## 0. What was measured, and how (verify_masher)

New per-fight counters, printed under each fight row as `AI (D764)`, and per kind in a table (`AI by kind`):
- **Swing at the air.** A melee strike (the hitbox switched on) whose hitbox never touched the hero's body during its active frames, and the hero did not roll or jump during the wind-up. A swing he rolled or jumped away from is counted apart, as **dodged**: that is his success, not the AI's mistake. Archers (arrows) and fliers are not melee.
- **Idle in reach.** A ground melee enemy is in reach (the far edge of its hitbox, plus its lunge, plus half the hero) on the hero's floor. It stands (|v| < 5 px/s) and is not swinging, recovering, stunned, knocked back, passing through the hero or latched. The counters are the total and the longest stretch.
- **Lost / re-engage.** The hero starts a roll or a jump. Every melee enemy within 1.5 × its engage range is followed. It is *re-engaged* when it is back at its engage range in the fight (ATTACK or swinging) after he is on the ground again. It has *lost* him when it goes home or idle, or is not back within 4 s, while it can still see him.
- **Dumb moves.** Stuck: it wants to reach the hero but stands > 1 s before a wall or a ledge. Fell: > 0.4 s in the air without a knockback or lunge. Each case is logged as a `dumb:` line.

**[6] drill.** Each kind fights alone on the flat DesertRoad arena against a hero with 99999 HP, using real input:
- roll away, jump away, roll through, jump over;
- walk off for 1.5 s;
- block for 3 s, twice;
- six heavies: half of them right after the enemy's swing, half walking up in its rest;
- two light combos.

For archers: the hero walks at them five times and jumps in front of them. Each decision an enemy makes emits `EnemyLogic.tactic(name)`; [6] counts them per kind.

**[7] checks.**
- Per bot, and for the drill: swings at the air < 15 %.
- Per bot: the longest idle in reach is ≤ 1.0 s. No stuck, fall or lost-hero case.
- Per kind, in the drill: it loses the hero 0 times after rolls and jumps, and is back within ≤ 1.5 s on average.
- Each kind uses its own answers (from fights and the drill together):
  - melee kinds: `follow`, `space_out`, `punish`, `close_in`;
  - guard kinds: `guard`;
  - evade kinds that rest inside a heavy's reach: `evade`;
  - kinds whose tells can be blocked: `wait_block`;
  - archers: `kite`, `lead`;
  - elites: `feint`.

`MASHER_ONLY=DRILL` runs only the drill; `MASHER_DEBUG=1` prints a timeline. Before = `origin/cloud/hard-fights-2` (worktree, old AI) with the same measuring script.

## 1. Before → after

**Per bot, all fights** (before: `m_before_final`; after: `m_final`, the committed code):

| | MASHER before → after | GOOD before → after | drill before → after |
|---|---|---|---|
| melee swings at the air | 1 / 47 (2 %) → 1 / 46 (2 %) | 4 / 97 (4 %) → 0 / 68 (0 %) | **20 / 197 (10 %) → 5 / 238 (2 %)** |
| longest idle in reach | **1.29 s** (Scorpicore) → 0.70 s | **1.02 s** (Scorpicore) → 0.69 s | 0.03 s → 0.40 s (shield-bearer, waiting out a block) |
| idle in reach, total, bosses | Scorpicore 3.3 s, Mercenary 5.7 s → 2.1 s, 3.8 s | 4.1 s, 5.7 s → 3.2 s, 3.8 s | – |
| lost the hero after a roll or jump | – (never rolls) | **3** (bandit, jackal, tank) → 0 | 0 → 0 |
| stuck at a wall or ledge, fell | 0 → 0 | 0 → 0 | 0 → 0 |

The bots walk into the enemies, so in their fights the air swings were already rare. The drill is where a hero who moves meets the old AI.

**Per kind, drill** (air = at the air; re-engage = average time back in the fight after rolls and jumps):

| kind | air before → after | re-engage before → after, s |
|---|---|---|
| bandit (melee) | **7 / 19 (37 %)** → 1 / 17 (6 %) | **2.36** → 1.13 |
| jackal (fast) | 4 / 21 (19 %) → 0 / 41 | 0.73 → 0.98 |
| cursed jackal | 4 / 24 (17 %) → 2 / 40 (5 %) | 0.60 → 1.18 |
| pack leader | 4 / 38 (11 %) → 0 / 43 | 0.78 → 0.64 |
| shield-bearer | 1 / 13 (8 %) → 1 / 15 (7 %) | **2.09** → 1.28 |
| tower shield guard | 0 / 21 → 0 / 20 | **1.75** → 1.16 |
| tank | 0 / 19 → 0 / 19 | **2.14** → 1.34 |
| bandit brute | 0 / 17 → 1 / 22 (5 %) | 0.28 → 0.28 |
| armoured scorpion | 0 / 25 → 0 / 21 | 1.04 → 0.93 |

Before, a bandit or a shield-bearer whose wind-up had started kept it going after the hero had rolled away. It swung at the air, then backed off, and only then chased (2+ s). Now the wind-up is dropped before the tell and the enemy follows. The jackals take longer than before (0.6–0.8 → 1.0–1.2 s): they used to swing at the air where he had been and stay close, and now they finish their step back out of his reach before following. All kinds are under 1.5 s.

**Fights** (hero HP left):

| fight | MASHER SKILLS / STRENGTH before → after | GOOD before → after |
|---|---|---|
| lone bandit | wins 63 % / 63 % → wins 82 % / 82 % | wins 100 % → 100 % |
| road's first fight | loses / loses → loses / loses | wins 17 % → 58 % |
| City Gates | loses / loses → loses / loses | wins 100 % → 100 % |
| lone brute | loses / loses → loses / loses | wins 59 % → 59 % |
| Lab middle | loses / loses → loses / loses | wins 100 % → 100 % |
| Mayor Hall boss | loses / loses → loses / loses | wins 16 % → 71 % |
| Caravan | loses / loses → loses / loses | wins 67 % → 84 % |
| cursed jackal | loses / loses → loses / loses | wins 49 % → 100 % |
| Laboratory boss | loses / loses → loses / loses | wins 51 % → 63 % |

MASHER still loses every elite, boss and group of 3+, and still loses HP to the lone bandit.

GOOD now ends with more HP:
- group tells no longer overlap (§2.4), so a hero who reads tells can answer each one;
- a series stops instead of chaining into his block;
- bosses do not punish the flask (§2.2).

MASHER does not answer tells, so for him nothing got easier. The lone bandit costs him less HP (82 % left instead of 63 %), because the bandit now steps back out of his reach after its series.

Group fights stay chaotic, and the runs are not deterministic. Before the one-tell rule, the same code gave GOOD 49 % in the Caravan in one run, and a loss (then a win on the second try) in another. Since the rule, GOOD has won all nine on the first try in all three full runs (`m_after8`, and twice `m_final`).

## 2. What changed, by point

All of it is in `Scripts/Gameplay/Components/EnemyLogic.gd`, unless the bullet names another file.

### 2.1 Intent to kill (point 1)

- **A swing starts only when it can reach** (`swing_fits`):
  - it predicts where the hero will be at the strike, from his velocity (up to 90 px, `PREDICT_MAX`);
  - from that, it subtracts how far it will creep during the tracking part of the wind-up (0.6 × its speed until the tell, `WINDUP_CREEP`);
  - the swing starts only if the result is within the reach (`strike_reach`: the far edge of the hitbox, plus its lunge, plus half the hero; `DefaultEnemy.strike_reach`);
  - it does not swing at a hero who is rising over its hitbox.

  Otherwise it steps in at the step-in pace (D713).
- **The strike carries a step of up to 24 px** (`_strike_step`) when the hero is just past the reach. D504 says a step back does not save him and a roll does; this makes that true for enemies too.
- **During the wind-up, before the tell, it turns and creeps toward him** (`close_in`). If he rolls or walks off so far that the swing can no longer reach, the wind-up is dropped before the tell (`_abandon_due`, which also emits `follow`). No swing at the air, and a shown tell still always strikes.
- **The next swing of a series comes only if it reaches** and would not go into a front block (`_series_fits`). Bosses play their pattern's series to the end.
- **Following:**
  - out of range: back to the chase at once (`follow`);
  - a hero walking or rolling away is run after (×1.8, `press`) and lunged at, even during the rest (`_lunge_due`);
  - a hero who jumps out of sight is followed to where he was last seen (`_last_seen_x`; never seen, as through a wall, means it stands, as B139 had it).
- **Leash.** It gives up only when the hero is beyond its chase range (B164).
- **Archers lead.** The heavy archer tilts at where the hero's body will be when the arrow arrives (`ArcherEnemy._tilt_to`). Both archers draw on a jumping hero only if he will be at their height when they release (`_hero_y_at`, `lead`).

### 2.2 Punishing openings (point 2)

`_hero_opened` counts these as openings:
- the recovery of a heavy;
- the end of his own combo, but only while he cannot attack yet for long enough to see the tell;
- the flask;
- a cast's wind-up;
- 0.35 s after he lands from a jump;
- after a swing the shield-bearer took on its shield (0.4 s);
- the heavy's wind-up, for kinds that trade (armour).

An opening sets off a swing regardless of the rest, from at least the enemy's engage range, or its lunge range for lunge kinds. **Only one enemy punishes an opening.** If another is already swinging, the rest keep their rhythm. A retreating enemy turns back to punish.

Bosses (`BossLogic._hero_opened`) punish only the heavy's recovery and landing, not the flask, cast or combo end. Their pattern already presses. With the flask punished as well, GOOD lost the Mayor Hall boss on both tries, at 3–6 % boss HP.

### 2.3 Reading the hero (point 3)

New `EnemyStats.answer_swing`:
- **evade**: bandit, jackal, pack leader, cursed jackal. When it sees a heavy's wind-up that will reach it, it rolls a die (70 %, `EVADE_CHANCE`). After 0.1 s of reaction, during which it does not start its own swing, it hops back 70 px in 0.22 s (sprite hop 10 px), and it stops at ledges. It punishes the recovery afterwards.
- **guard**: shield-bearer, tower shield guard. While the hero swings at it from the front, it stands shield-first facing him instead of walking into the swing. When the swing ends, it answers at once (`_counter_left`). The shield still blocks only from the front (D495).
- **trade** (default): tank, brute, scorpions. They take the hit on their armour and punish the heavy's wind-up.

Other reads:
- **Blocking hero.** A kind whose tell can be blocked does not swing or lunge into a front block. It walks round him (the D741 pass, when free) or waits at its distance (`wait_block`). If he holds the block longer than 1.2 s (`BLOCK_PATIENCE`), it strikes into the block, since a block spends stamina (D504). Red-tell kinds always swing.
- **The village lessons.** `CombatTraining` marks its enemies `in_training`. They swing into a block and do not hop out of a heavy, so the Block and Heavy lessons have something to block and land. Without this, `verify_onboarding` failed: the bandit walked round the blocking hero.
- **Archers** (`ArcherLogic`):
  - they back off already at 1.3 × `keep_away` when he walks at them (`kite`);
  - when cornered within 0.6 × `keep_away`, they pass through him to his other side (`reposition`);
  - they never drop a draw.

### 2.4 Spacing and rhythm (point 4)

- **After its series, every melee kind steps back out of the hero's reach** (`_hero_reach`), the tank included, unless he is already out of it. `back_off` stays the minimum. While waiting, an enemy inside his reach backs off at full pace; if it cannot back off, it swings. Bosses keep their preferred range (B154).
- **Rest between series** is `attack_cooldown` × 0.7–1.3, bosses included (`_rest`).
- **Bosses in reach.** A boss whose hero stands in its combo reach for more than 0.7 s strikes without waiting out the rest (`REACH_PATIENCE`, B165).
- **Elite feints.** Once every 2–4 series, the first swing is a feint: 0.3 s of the wind-up pose without a tell, cut off, a 0.2 s pause, then the real wind-up with its tell. The colour tell never lies (D504).
- **One tell at a time in a group.** A new attacker does not take the token while another's tell is lit. A wind-up whose tracking ends while another tell is lit holds its own tell until that strike has passed. The token stays 2 (D741), but the strikes come one after another, so each tell can be answered.

### 2.5 No dumb behaviour (point 5)

Every case the counters met is listed in §6 as a B row and fixed:
- **lost the hero** (B164);
- **an enemy walking home that ignored the hero** (B162);
- **bosses idling in reach** (B165);
- **an error flood** from a roll through an enemy that was freed (B163).

No enemy stuck at a wall or ledge, and none fell, in any fight or the drill, before or after.

## 3. Tests changed to follow D764

- `verify_combat_enemies`:
  - [2]: the tells test puts the hero, invulnerable, inside the enemy's reach. A series now stops when the next swing cannot reach. It used to swing a full series at a hero 400 px away.
  - [9]: "the tank never retreats" is now "the tank steps back out of the hero's reach after its swing".
  - [10]: the scripted lunges calm the enemy first and only then place the hero. A freshly landed hero is an opening, and the AI would punish it on its own.
- `verify_souls_combat` [2]: the three-swing combo is struck at an invulnerable hero in reach.
- `verify_combat_stats` [4]: the tempo is `attack_cooldown` × 0.7–1.3.
- `verify_rooms_batch1` `_win`: the hero is healed while the script kills the camp fight. Enemies now land their swings in the 1.5 s between kills; in one run of three the hero died and the rest of the room tour failed.
- `verify_masher`:
  - new counters (§0), [6] and [7];
  - the enemy lines show `landed N` (blows that hit the hero, arrows counted to their archer).

Combat verifies run alone after the changes, all `RESULT: ALL PASS`:
- `combat_enemies`, `souls_combat`, `combat_flow`, `difficulty`;
- `enemy_variety`, `lab_boss`, `mayor_boss`, `mayor_hall`, `bosses`;
- `flying_enemies`, `hit_areas`, `combat_stats`, `combat_player`, `enemy_stagger`;
- `archer`, `combat_feel`, `skills_combat`, `companions`.

`verify_masher` (`m_final`, alone; under the suite's 180 s limit it cannot finish, §7): `RESULT: ALL PASS`.

The drill repeats a phase (bounded) until the kind has shown its answers:
- the block phase twice, up to four times;
- the heavies six times, up to fourteen;
- the archer walk-in five times, up to ten.

Before that, a single full run sometimes missed one kind's rare answer (a tower guard's `wait_block`, a brute's `punish`).

## 4. Files

- **Behaviour:**
  - `Scripts/Gameplay/Components/EnemyLogic.gd`;
  - `Scripts/Gameplay/Characters/Bosses/BossLogic.gd`;
  - `Scripts/Gameplay/Characters/Enemies/ArcherLogic.gd`, `ArcherEnemy.gd`;
  - `Scripts/Gameplay/DefaultEnemy.gd` (`strike_reach`);
  - `Scripts/Gameplay/Characters/Enemies/EnemyStats.gd` (`answer_swing`);
  - `Scripts/Player/Components/PlayerCombat.gd` (`strike_reach`);
  - `Scripts/Player/Components/PlayerMover.gd` (B163);
  - `Scripts/Gameplay/CombatTraining.gd` (`in_training`).
- **Data:** `Resources/Enemies/enemy_stats_{melee,fast,jackal_cursed,jackal_pack_leader,shield,tower_shield_guard}.tres` (`answer_swing`).
- **Tests:** `verify_masher.gd`, `verify_combat_enemies.gd`, `verify_souls_combat.gd`, `verify_combat_stats.gd`, `verify_rooms_batch1.gd`.
- **Plan:** `design/MASTER_PLAN.md` §3, row B-ai. `SampleProject/Maps/*` is untouched.

## 5. Poses that are missing (for the orchestrator)

1. The evade hop: a short back-step or hop with the weapon drawn. Now it is the sprite lifted 10 px during a backward slide, in the walk frames.
2. The guard: shield raised and braced. Now it is the idle frame, standing, facing the hero.
3. The feint: a wind-up that is cut off visibly, with a shoulder twitch back to the stance. Now it is the wind-up pose, then idle.
4. The strike step: there are no frames for stepping into a strike; the body slides 24 px during the attack frames.

## 6. D-ID and B rows (next free numbers at writing; the integrator renumbers)

| D764 | Sapega 26.10 | **Enemies mean to kill** («інтелект ворогів має бути трохи кращий»; «щоб вони хотіли вбити персонажа, а не просто бачили, рухались і били по повітрю»). The existing enemy logic now hunts the hero (`EnemyLogic`, `BossLogic`, `ArcherLogic`). (1) A swing starts only if it will reach the hero at the strike: his position is predicted from his velocity; the enemy creeps in and turns until the tell and strikes with a step of up to 24 px. A wind-up the hero has rolled or walked out of is dropped before the tell, and a series stops when its next swing cannot reach. After a roll or a jump enemies follow at once: they run after a hero who walks away, lunge at him, and go to where they last saw him. (2) Openings are punished out of rhythm, by one enemy at a time: a heavy's recovery, the end of the hero's combo, the flask, a cast, a landing. Bosses punish only the recovery and the landing. (3) The enemy reads the hero (`EnemyStats.answer_swing`): light kinds hop back out of a heavy's reach (70 %), shield kinds stand shield-first through his swing and answer after it, and armoured kinds trade. Blockable kinds do not swing into a front block: they walk round him or wait, and after 1.2 s of block they test it; the village lessons' enemies always swing into it. Archers back off earlier, pass through him when cornered, and lead their shots. (4) After a series every melee kind steps out of his reach. The rest between series is ×0.7–1.3. A boss with the hero in its combo reach for over 0.7 s strikes. Elites feint once every 2–4 series: a wind-up pose without a tell, cut off; a shown tell still always strikes (D504). In a group only one tell is lit at a time. In the drill, swings at the air fell from 10 % to 2 %, and the longest idle in reach from 1.29 s to 0.70 s. Numbers are provisional. Report: `cloud_reports/enemy-ai`. |

**B162** (fixed 2026-10-27, `cloud/enemy-ai`). An enemy walking home (RETURN_HOME) ignored the hero. If he stood in its way it pushed against him and never fought again. Found by `verify_combat_enemies` [7] once D764 made enemies walk to where they last saw him. Fix: walking home, it goes back to the chase when it sees him within its detection range (after the chase cooldown).

**B163** (fixed 2026-10-27, `cloud/enemy-ai`). `PlayerMover._release_passed`: an enemy freed during a roll through it (a room swap) stayed in the typed `_passing` array. `erase()` of a freed object fails, so the error repeated every physics frame: 368 712 errors in one `verify_masher` run. Fix: freed entries are filtered out first.

**B164** (fixed 2026-10-27, `cloud/enemy-ai`). Mid-fight, an enemy past its leash gave up and walked home while the hero stood 80–350 px away. In `verify_masher`, GOOD lost a bandit, a jackal and a tank this way after rolls (Caravan, Lab middle, road's first fight). Fix: the leash ends the chase only when the hero is beyond the enemy's chase range.

**B165** (fixed 2026-10-27, `cloud/enemy-ai`). Bosses stood idle up to 1.29 s with the hero inside their combo reach (fixed rest of 1.0–1.3 s, Mayor Hall and Laboratory). Fix: a boss whose hero stands in its combo reach for more than 0.7 s strikes (`BossLogic.REACH_PATIENCE`); the rest varies ×0.7–1.3.

## 7. Full suite

The suite was run twice, because the first run found three things to fix.

**First run** (on the first commit): `SUITE: 5 FAIL`.
- `verify_onboarding` 4 FAIL: the lesson bandit walked round the blocking hero. Fixed by `in_training`, §2.3.
- `verify_rooms_batch1`: the hero died in the scripted camp fight in one run. The test now heals him, §3.
- `verify_combat_player` 1 FAIL.
- `verify_audio` 1–2 FAIL.
- `verify_masher` hung at the suite's 180 s limit.

The block patience (§2.3) came from the same round.

**Second run** (`Scripts/Tools/run_verify.sh`, Linux, Godot 4.6.2, 120 scripts): `SUITE: 4 FAIL`, 116 PASS.
- `verify_masher`: HUNG, killed after the suite's 180 s limit. Here a full run takes about 30 minutes; the drill [6] adds about a third. Run alone (`m_final`): `RESULT: ALL PASS`.
- `verify_combat_player` [4]: "a hit before the sip: no heal" (269 instead of 300). A live enemy of the room punished the potion. Enemies now punish the flask from further away and no longer leave mid-fight (B164). The potion check now stops the room's enemies first, as its stamina check already did. Run alone three times after the fix: `RESULT: ALL PASS`.
- `verify_audio` 1 FAIL: a different hurt-sound check in each suite run (`hero_hurt`, `hero_hurt_voice`, `cast_interrupt`). Run alone, 4 of 5 passed; the one that failed passed on the next run. `design/test_baseline.md` already lists `verify_audio` as flaky under suite load in the cloud.
- `verify_souls_combat` [3]: "pushed away from the enemy (−13 px)", only under suite load. Run alone three times: `RESULT: ALL PASS`. It passed in the first suite run.

Every other script: PASS.
