---
type: report
tags: [cloud, combat, difficulty]
---

# Cloud report: hard-fights

**Summary.** Done: `verify_masher.gd` (D754) plays 9 route fights in the real rooms with real input events. A MASHER
(light attacks, heavy after a combo, flask at low HP) plays in the STRENGTH and SKILLS builds, and a GOOD bot (block,
parry and riposte, roll from red) plays in SKILLS. **Before:** the masher won every ordinary fight, group and elite,
mostly with 100 % HP (0 enemy blows landed). Only the two bosses beat him. Why: poise broke every swing, pushes beat
slow enemies, one light swing hit a whole group, enemies came one by one, and nothing punished mashing (D755).
**After** (D755 behaviour, D756 numbers): the masher beats a lone bandit at 63 % HP and loses everything else in both
builds; GOOD wins all nine. `verify_difficulty` passes with no changes; 7 other tests follow the new rules. No B rows.
Full suite (120 scripts, Linux, Godot 4.6.2): `SUITE: 1 FAIL` — `verify_combat_player` [3], since fixed (below) and
re-run alone: `RESULT: ALL PASS`; every other script PASS, `verify_masher` and `verify_difficulty` included.

## 1. The test (D754)

`SampleProject/UI/verify_masher.gd`, about 125 s at 4× speed with one frame per physics step. Each fight runs in its own
room, through its own `RoomEnemySpawner` (waves and story spawns included); boss rooms start at their `_fight()`. The
hero is at the level he reaches the fight (the XP walk of `verify_difficulty`). He has road gear before the City and
City gear after it, and the STRENGTH or SKILLS build of `verify_difficulty._make_hero`. Rolls are calmed per fight (no
crit or evasion, as in `verify_difficulty`). Each fight has its own seed. Input is real: `InputEventAction` for moves,
`attack`, `heavy_attack`, `block`, `dodge` and the hotbar slot of Healing Palm. A fight runs until someone wins or
150 game-seconds pass.

Per fight it prints: who won, hero HP, time, enemy blows that landed, flasks (healed / pressed), parries, blocks, rolls,
how often an enemy wound up while another was already swinging (count and seconds), hero hits and how many of them
were cleaves, and blows that met post-hit i-frames. Per enemy it prints swings, swings told, strikes, swings broken
before and after the tell, and seconds in chase, ready, cooldown, swing, recovery, stun, knockback and other states.

Asserts: [1] the masher wins the lone bandit with HP lost; [2] the masher (both builds) loses every group of 3+, both
elites and both bosses; [3] GOOD wins all nine. A group fight is chaotic (one frame of timing changes the branch). A
result off the expectation gets one second try with other seeds, and the expectation has to hold in one of two. A fight
that drifts easy fails both tries; on the old code 14 checks fail.

## 2. Measured, before → after

Level shown; `hits` = enemy blows that landed on the hero. Before = `origin/feature/backlog` with this test copied in.

| fight | lvl | before: masher SKILLS / STRENGTH | after: masher SKILLS / STRENGTH | after: GOOD |
|---|---|---|---|---|
| lone bandit (Village) | 1 | wins, 100 % HP, 0 hits, 2.9 s / wins, 100 %, 0, 2.9 s | wins, 63 % HP, 2 hits, 3.4 s / wins, 63 %, 2, 3.4 s | wins, 100 %, 0 hits |
| road's first fight: 2 bandits, 2 jackals | 1 | wins, 100 %, 0 hits, 7.0 s / wins, 100 %, 0, 5.9 s | loses (enemies 20 % HP left), 6 hits, 4.1 s / loses (39 %), 6, 4.3 s | wins, 18 %, 5 hits |
| City Gates: 2 bandits, archer | 4 | wins, 62 %, 2 hits / wins, 30 %, 3 | loses (31 %), 6 hits / loses (28 %), 5 | wins, 81 %, 1 hit |
| lone bandit brute (elite) | 2 | wins, 100 %, 0 hits, 5.9 s / wins, 100 %, 0, 5.1 s | loses (18 %), 3 hits, 5.6 s / loses (13 %), 3, 5.6 s | wins, 100 %, 0 hits |
| Lab middle: bandit, 2 jackals, scorpion | 9 | wins, 100 %, 0 hits, 13 s / wins, 100 %, 0, 14.5 s | loses (44 %), 7 hits / loses (70 %), 4 | wins, 61 %, 3 hits |
| Mayor Hall boss | 5 | loses (76 %) / loses (86 %) | loses (70 %) / loses (86 %) | wins, 38 %, 3 hits |
| Caravan: armoured scorpion and 4 (elite) | 3 | wins, 53 %, 2 hits / wins, 81 %, 1 | loses (83 %), 4 hits / loses (92 %), 3 | wins, 75 % (2nd try; 1st lost at 46 %) |
| cursed jackal (elite) | 9 | wins, 100 %, 0 hits, 7.0 s / wins, 100 %, 0, 7.0 s | loses (77 %), 3 hits, 2.9 s / loses (76 %), 2, 2.1 s | wins, 100 %, 0 hits |
| Laboratory boss | 12 | loses (72 %) / loses (86 %) | loses (74 %) / loses (86 %) | wins, 67 %, 3 hits |

Before, GOOD won all nine, most of them untouched.

## 3. Why play was easier than paper: the measured causes

Old code, MASHER SKILLS. "broken" means a swing that never struck.

| fight | measured | cause |
|---|---|---|
| lone bandit | 1 swing, told, broken after the tell; 0.7 s staggered; dead in 2.9 s | the light combo (poise 1 + 1 + 2) broke the bandit's poise 3 every combo, and a poise break stops a swing even after its tell |
| road's first fight | 5 swings in 7 s, 0 struck; up to 3.2 s "other" (idle, then a 2 s chase cooldown); 0.0 s two enemies swinging together | the same stagger-lock, plus the four engaged one by one: the far two stood idle until the hero walked up to them |
| lone bandit brute | 3 swings, 3 broken before the tell; 1.5 s staggered, 0.9 s knocked back | poise 5 broke in a combo and a heavy, and the finisher (40 px) and heavy (70 px) pushes broke the 1.0 s wind-up before its tell |
| cursed jackal | 3 swings, 0 struck; 4.9 s of 7 s staggered | poise 2: two light hits broke it, every time |
| Lab middle | 37 hero hits, 10 of them cleaves; the scorpion 5 swings, 4 broken, 4.4 s stunned; one jackal 0 swings | the stagger-lock, and one light swing hit every enemy in its reach, so a group died about as fast as one enemy |
| Caravan | the armoured scorpion 11 swings, 10 broken before the tell, 6.6 s stunned, 3.6 s pushed; three others 0 swings, 7–13 s chasing | stagger-lock and pushes on the elite; the group queued behind its front body in the one-lane road (enemies blocked each other) |
| City Gates | the archer kept its 2.2 s pause and never shot during a flask; the two bandits died with 1 swing each | stagger-lock, and enemies ignored the flask: no punish |
| bosses | Mayor 3 of 4 struck, Lab 2 of 5 struck; the masher loses already | boss poise 14/16 and super armour hold: bosses were already hard (D676), no change |

Things the prompt listed that were checked and are **not** the cause: spawn levels (`enemy_level` = hero level,
`verify_difficulty` [0]), enemies losing aggro (no leash or give-up in any fight), and the flask (presses mostly failed
under pressure after the punish was added, and D642 keeps the flask unchanged). After the first fixes, three causes
showed up that the old numbers hid: the hero's 0.5 s i-frames after a hit swallowed overlapping group blows; the
hero's 50 px pushback carried him out of the next enemy's reach; and a bandit walked into the hero's 113 px sword reach
(front 78 px plus the bandit's half body 35 px) slower than the masher's swings.

## 4. D-ID text (next free numbers; the orchestrator renumbers)

| D754 | ROUTINE CALL | **The real-play difficulty guard** (D642, D668; `cloud/hard-fights`). `verify_masher.gd` plays route fights in the real rooms with real input events: the lone Village bandit (L1), the road's first fight (2 bandits, 2 jackals, L1), City Gates (2 bandits and an archer, L4), the lone bandit brute (L2), Lab middle (bandit, 2 jackals, scorpion, L9), the Caravan (armoured scorpion and 4, L3), the cursed jackal (L9), the Mayor Hall boss (L5) and the Laboratory boss (L12). The hero is at the fight's level, with route gear and the `verify_difficulty` builds. A **MASHER** presses only light (and heavy after a combo), walks into the enemy and drinks the flask below 35 % HP. It never blocks, parries, rolls or jumps, and plays in both builds. A **GOOD** bot (SKILLS) blocks white tells, parries yellow ones and ripostes, and rolls away from red ones (arrows: when they arrive). It drinks and casts only while no one is winding up. Asserts: the masher wins the lone bandit with HP lost and loses every other fight; GOOD wins all. Rolls are calmed per fight and the game runs one frame per physics step at 4× speed. A result off the expectation gets one second try (group fights branch on one frame). It runs in about 125 s and prints, per fight and per enemy, the numbers it judges by. |
| D755 | ROUTINE CALL | **Why play was easier than paper, and the behaviour that fixes it** (D642; measured in `verify_masher`, report `cloud_reports/hard-fights`). (1) **A swing holds its ground:** during its wind-up and strike an enemy is not pushed by the hero's hits, and a push no longer breaks the swing before its tell; only a poise break or a parry stops it. This amends B134's "knockback before the tell breaks the swing" (`DefaultEnemy.holds_ground`). (2) **An enemy answers a hero who keeps hitting:** `EnemyStats.answer_hits` hits from the hero during the pause between series, or during its back-off, cancel the rest of the pause, and it attacks with its normal wind-up and tell (`EnemyLogic.provoked`). (3) **A fight is one group:** when one enemy of a `RoomEnemySpawner` starts chasing, the idle ones join (`_rouse`). They run at 1.8× pace while farther than 2.5 × engage range (the walk animation speeds up with them), and step in to strike at 1.4× pace. (4) **Ground enemies pass through each other** (the hero is still blocked, D443), so a group in a one-lane road no longer queues behind its front body. (5) **A light swing stops in the first enemy:** a combo swing that is not the finisher damages one target (`DamageApplier.max_targets`); the finisher, the heavy and the riposte still hit everyone in reach. (6) **A flask or potion is an opening:** like a heavy or cast wind-up, the quick-slot potion draw (`DRINK`) makes nearby melee enemies attack at once, and an archer shoots at once from its full range (`EnemyLogic._hero_opened`, `_punish_range`). (7) **Elite traits come from `enemy_variety.json` "elite"**: damage ×2.3 (was 1.5), poise ×1.6, and an elite is not pushed by the hero's hits (like a boss, B134). Elite kinds copy their base kind's numbers again (D703, D709, D711). (8) The hero's post-hit invulnerability is 0.1 s (was 0.5) and a hit pushes him 20 px (was 50), so two enemies that strike together both land. |
| D756 | ROUTINE CALL | **The numbers of D755** (provisional, `Resources/Enemies/*.tres`, `enemy_variety.json`, `Player.tscn`; table in `cloud_reports/hard-fights` §5). Poise: a light combo (4 poise) no longer breaks an ordinary enemy (bandit 14, jackal 12, shield-bearer 14, scorpion 16, archer 6), and an elite gets ×1.6 on top. Shorter pauses between series (D642 "more aggressive", below D494's): bandit 1.0 s, jackal 0.8 s, shield-bearer 1.2 s, scorpion 1.5 s, archer 1.6 s. The bandit's series is always two blows (yellow, then the red finisher) and the jackal's runs longer (`combo_chance` 0.75). The bandit brute keeps his slow red smash but winds up 0.85 s, knocks the hero down for 1.0 s and recovers in 0.5 s. All melee kinds answer after one hit. `verify_difficulty` passes with no changes to its expectations: the D642 ordinary targets (H 5–6, N 4–6) and the D676 boss numbers are untouched. |

## 5. Every number changed (old → new)

| where | number | old → new |
|---|---|---|
| `enemy_stats_melee.tres` (bandit) | poise / attack_cooldown / combo_chance / answer_hits | 3 → 14 / 1.5 → 1.0 / 0.5 → 1.0 / – → 1 |
| `enemy_stats_fast.tres` (jackal) | poise / attack_cooldown / combo_chance / answer_hits | 2 → 12 / 1.0 → 0.8 / 0.5 → 0.75 / – → 1 |
| `enemy_stats_jackal_cursed.tres`, `enemy_stats_jackal_pack_leader.tres` | same as the jackal (D703: they copy it) | 2 → 12 / 1.0 → 0.8 / 0.5 → 0.75 / – → 1 |
| `enemy_stats_shield.tres` | poise / attack_cooldown / answer_hits | 4 → 14 / 1.7 → 1.2 / – → 1 |
| `enemy_stats_tower_shield_guard.tres` | poise / answer_hits | 4 → 14 / – → 1 |
| `enemy_stats_tank.tres` (scorpion) | poise / attack_cooldown / answer_hits | 6 → 16 / 2.0 → 1.5 / – → 1 |
| `enemy_stats_armoured_scorpion.tres` | poise / answer_hits | 6 → 16 / – → 1 |
| `enemy_stats_archer.tres` | poise / attack_cooldown | 2 → 6 / 2.2 → 1.6 |
| `enemy_stats_heavy_archer.tres` | poise | 3 → 6 |
| `enemy_stats_bandit_brute.tres` | poise / attack_windup / stagger_time / recovery / answer_hits | 5 → 16 / 1.0 → 0.85 / 0.4 → 1.0 / 0.7 → 0.5 / – → 1 |
| `enemy_variety.json` elite | damage / poise / knockback_immune | 1.5 → 2.3 / – → 1.6 / – → true |
| `Player.tscn` Player | invulnerability_duration (CombatBody2D default) | 0.5 → 0.1 |
| `Player.tscn` PlayerCombat | stagger_push | 50 → 20 |
| `EnemyLogic.gd` | RUN_PACE / RUN_FROM / STEP_IN_PACE (new) | – → 1.8 / 2.5 / 1.4 |
| `PlayerCombat.gd` | LIGHT_TARGETS (new) | – → 1 |

Elite poise in play: bandit brute 26, cursed jackal and pack leader 19, armoured scorpion 26, tower shield guard 22,
heavy archer 10. Bosses are unchanged.

## 6. Tests that follow the new decisions

- `verify_enemy_variety` [2]: elite ×1.5 → ×2.3 damage, ×1.6 poise, not pushed (reads `variety.elite()` instead of a
  literal 1.5 in three checks).
- `verify_combat_enemies` [1]: a pause is now shorter than the pre-D494 one (it was equal). [5]: a push during the
  wind-up neither moves the swing nor breaks it (was: it breaks it); the test also waits out the swing's recovery
  before the next one.
- `verify_combat_stats`: the jackal swings every 0.8 s (was 1.0).
- `verify_combat_flow` [1d]: the mace target gets `answer_hits` 0, because a swinging enemy holds its ground and the
  check is about the mace's push.
- `verify_combat_player` [3] (ten rolls, no stamina): a lone shield-bearer of the road now answers and staggered the
  hero mid-series; the check freezes the enemies around it (it tests stamina, not a fight).
- `verify_road_sections`, `verify_gates`: the level-1 hero standing in the road's fight zones now dies, so these
  tests, which check spawns and gates and not fights, set `min_health` 1.

## 7. Files

- New: `SampleProject/UI/verify_masher.gd`.
- Behaviour: `Scripts/Gameplay/DefaultEnemy.gd` (`holds_ground`, `_pass_allies`, elite poise and knockback from
  variety, `provoked` on a hero hit), `Scripts/Gameplay/Components/EnemyLogic.gd` (`provoked`, run and step-in pace,
  `_hero_opened` + `_punish_range`), `Scripts/Gameplay/Components/EnemyView.gd` (`walk_pace`),
  `Scripts/Gameplay/RoomEnemySpawner.gd` (`_rouse`), `Scripts/Gameplay/Characters/Enemies/ArcherLogic.gd` (punish),
  `Scripts/Gameplay/Characters/Enemies/EnemyStats.gd` (`answer_hits`), `Scripts/Player/Components/PlayerCombat.gd`
  and `Scripts/Combat/Components/DamageApplier.gd` (one target per light swing).
- Data: `Resources/Enemies/enemy_stats_*.tres` (12 kinds), `Resources/Data/enemy_variety.json`, `Player.tscn`.

## 8. Open points (no Q-ID blocks)

- The road's first fight at level 1 (four enemies, no flask yet) now kills a masher. A careful player wins it (GOOD:
  18–100 % HP across runs). If Sapega finds the first road fight too sharp for a newcomer, the lever is the room (one
  enemy fewer), not the numbers.
- Group fights branch on single frames; the second try in `verify_masher` covers that. GOOD lost one Caravan try in
  four full runs, at 46 % enemy HP left, so the Caravan (an optional fight guarding a chest, D582) is near the edge
  for the bot.
- Numbers are provisional (D494 style) and meant for playtest.
