---
type: report
tags: [cloud, routines, bosses, mayor-hall]
---

# Cloud report: mayor-boss ([[lab_boss_plan]] "Mayor Hall boss replaced (D468)", slice 3)

**Summary**
- **Done:** the bald Scorpicore axe-warrior (`scorpicore_warrior.tscn`, D644 sheet) replaces the Brass Collector in the Mayor Hall. He keeps the Collector's moves and tells on `BossEnemy` / `BossLogic`: the sweep combo (yellow, then red), the charge (red) and the slam (red). The hero fights him alone (D557). The giant scorpion (`giant_scorpion.tscn`, no body, no hitbox) comes out of the breach and rears (sting row), then backs into it before the fight. After a win it comes back and hauls the beaten warrior away. The D300 beats, the loot and both teleports are unchanged, and the cage line stays cut (D457). His numbers follow D642 at level 5: 2600 HP, 40 iron-sword hits; damage 48, charge ×1.15, slam ×1.3, so 3–4 hits kill a hero with 180 HP. The talks are drafts.
- **Not done:** an attribute-only hero is not stopped yet. A strength-only build needs 31 hits instead of 40, because strength's diminishing returns and the build simulation of D642 belong to `cloud/difficulty`. That branch had no boss formula on `feature/backlog` when this ran, so the numbers are this branch's own (D646). `brass_collector.tscn` stays only as a test fixture (six verify scripts and `capture_bosses.gd` use it). No room spawns it now.
- **D-IDs for the register:** D645–D647 (orchestrator renumbers; lab-boss runs beside this). Text below.
- **B rows fixed:** none.
- **Full suite:** running (this line is updated when it finishes).

## D-ID text (for `figma_decision_register.md`)

| D645 | ROUTINE CALL | **The Mayor Hall fight with the Scorpicore axe-warrior, as built** (D468, D556, D557, D644; `cloud/mayor-boss`). `Scenes/Characters/Bosses/scorpicore_warrior.tscn` (`enemy_type` `scorpicore_warrior`, bar name "The Scorpicore Axe-Warrior", uk «Сокирник Скорпікори», agent call: he has no name yet) uses `mayor_hall_boss/sheet.png` on the Brass Collector's grid and moves. **Sweep** ≤ 69 px, 2 swings, yellow then red (phase 2: yellow, yellow, red). **Charge** 140–600 px, wind-up 0.8 s, 320 px dash, red. **Slam** ≤ 240 px, wind-up 1.0 s, a shockwave 240 px each side, red (jump over it). The pattern, the preferred range of 60 px and phase 2 are the Collector's (D577). The glint sits on the axe blade of each pose (`tell_at` (−20, −40), `tell_at_charge` (22, 22), `tell_at_slam` (−6, −47)). The stagger pose is frame 20 of the same sheet, since there is no `stagger.png`. Hurtbox and hitbox match the drawn sprite (B128): reach 67.5 px. Voice: roar and shout `boss_shout`, death `boss_death`, and his dialogue babble is `bandit_leader`. He has a dialogue character `SCORPICORE_WARRIOR` (portrait from `build_portraits.gd`) and a bestiary entry, and he is not listed in the Journal's people. Objective: "Survive the Scorpicore Axe-Warrior". `MayorHall` node `ScorpicoreWarrior`, mark `WarriorStand` (was `CollectorStand`). The sleep gas is gone from the hall (D556). |
| D646 | ROUTINE CALL | **The axe-warrior's numbers, from D642** (`cloud/mayor-boss`; no `cloud/difficulty` formula existed). The hero meets him at **level 5** (`verify_xp_curve`: the City is reached at 5, and the hall's 400 XP takes him to 8). A level-5 hero with an iron sword and no attribute points has 180 HP and 65 Phys. Atk. **HP 2600** = 40 light hits (35 with the combo's ×1.4 finisher). **Damage 48** per sweep swing = 4 hits to kill, **charge ×1.15** (55) = 4, **slam ×1.3** (62) = 3. Before this, the Collector had 1400 HP, damage 36, charge ×1.3 and slam ×1.5. XP 400, speed 55, poise 14 and stagger 0.6 s are unchanged. A strength-only build (20 points, Phys. Atk. 85) still wins in 31 hits, so "an attribute-only hero must struggle" waits for strength's diminishing returns (D642, `cloud/difficulty`). `verify_mayor_boss.gd` [1] and [2] fail if the numbers drift outside 35–45 hits and 3–4 hits. |
| D647 | ROUTINE CALL | **The giant scorpion in the Mayor Hall cutscene** (D557, D556, D300; `cloud/mayor-boss`). `giant_scorpion.tscn` is a Node2D with a sprite (×2, 256×160) and idle, walk and sting animations. It has no body and no hitbox, so it never deals damage. **Wall burst:** after the burst it walks out of the breach (`ScorpionOut` x 840 → `ScorpionStand` x 740, fading in) and rears (sting) with a roar (`brass_collector_roar`, the shared creature roars). The warrior climbs out in front of it and shouts. The scorpion turns and walks back into the breach, fading out, and then `MayorHall_WallBurst` plays. **Win:** the warrior falls; the scorpion comes back to his body, the body fades ("taken"), the scorpion leaves through the breach, then `MayorHall_Victory` plays (Kusakam only, in clouds) and the screen goes black → LabCells. **Loss:** black, `MayorHall_Defeat` (the warrior orders the clan to bind him, D556) → LabCells, no Game Over. Draft lines `[ЧЕРНЕТКА]` / `[DRAFT]` in `dialogue_quest/MayorHall_*.dqd` and `dialogue_quest/en/MayorHall_*.dqd`. |

## Draft lines (dialogue files, both languages)

The prompt said `uk.po` / `en.po`, but this project's dialogue lines live in `.dqd` files: `dialogue_quest/` (uk) and
`dialogue_quest/en/`. The `.po` files hold the UI strings: the bar and speaker name, the objective and the bestiary
text. Both sets are in.

| File | uk | en |
|---|---|---|
| `MayorHall_WallBurst` | URIZEN «Стіна! Що за...» · SCORPICORE_WARRIOR «Жалом клану. Усі ви — з нами.» · ALISIA «Тікаймо!» · KUSAKAM «Біжіть! Я його затримаю.» | "The wall! What the..." · "By the clan's sting. All of you — with us." · "Run!" · "Go! I'll hold him off." |
| `MayorHall_Victory` | «Впав... Я зміг.» · «Скорпіон забрав його... а крізь пролам лізуть іще.» | "It's down... I did it." · "The scorpion took him... and more of them are coming through the breach." |
| `MayorHall_Defeat` | «Надто... сильний...» · SCORPICORE_WARRIOR «Зв'яжіть ящера. Він піде з іншими.» | "Too... strong..." · "Bind the lizard. He goes with the others." |

Suggested Q (non-blocking, not filed): **what is the axe-warrior called?** Default: no name; he is "the Scorpicore Axe-Warrior"
(«Сокирник Скорпікори»).

## Details

- Boss scene: `SampleProject/Scenes/Characters/Bosses/scorpicore_warrior.tscn` (stats, moves, tell points, shapes).
- Scorpion: `SampleProject/Scenes/Characters/Bosses/giant_scorpion.tscn`.
- Hall: `SampleProject/Maps/MayorHall.tscn` has `ScorpicoreWarrior`, `GiantScorpion`, and the marks `WarriorStand`, `ScorpionStand` and
  `ScorpionOut`. `SampleProject/Scripts/Gameplay/Scenes/MayorHall.gd`: `_queue_and_burst`, `_on_warrior_died` and
  `_scorpion_walk`.
- Data: `bestiary.json`, `sound_events.json` (`boss_voices.scorpicore_warrior`, `voices.SCORPICORE_WARRIOR`),
  `journal_people.json` (`not_listed`), `en.po` / `uk.po` (4 keys), `dialogue_quest/characters/SCORPICORE_WARRIOR.tres`,
  `mayor_hall_boss/portrait.tres` (`Scripts/Tools/build_portraits.gd` entry added; the tool's re-run also rewrote the
  old_man and alchemist portraits, and those changes were reverted).
- Tests:
  - `verify_mayor_boss.gd` (new) → `RESULT: ALL PASS`. [1] D642 numbers at level 5. [2] Each move gets its tell colour from `EventBus.enemy_tell_shown`, the glint sits on the axe of its pose, the move lands, and each hit kills the level-5 hero in 3–4. Only the first sweep swing lands, because the hero's hit stagger carries him out of the second. [2] also checks stagger frame 20. [3] The scorpion comes out, rears and goes back; it has no collision object, no `damage_token` reaches the hero, and the axe-warrior is the only boss. [4] On a win the scorpion returns, the body is taken, the scorpion leaves before `MayorHall_Victory`, and the hero lands in LabCells with `mayor_boss_defeated`.
  - `verify_mayor_hall.gd` (updated node name and objective; it keeps the defeat flow: a real hit → no Game Over → LabCells) → `RESULT: ALL PASS`.
  - `verify_hit_areas.gd` (new scene added) → `RESULT: ALL PASS`.
- Capture: `SampleProject/UI/capture_mayor_boss.gd` → `design/shots/mayor_boss.png`. Top left: the slam's red glint on the
  raised axe. Top right: the axe lands (−62). Bottom: the scorpion rears out of the breach beside the queue.
