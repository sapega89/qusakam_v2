---
type: cloud-report
branch: cloud/big-scorpion
date: 2026-10-24
tags: [cloud, combat, enemies]
---

# Cloud report: big-scorpion (the armoured scorpion goes live, D652 / D692)

**Summary.** Done: `armoured_scorpion` is a live elite kind. It has its own scene on the scorpion behaviour, hit shapes
measured from its frames (D519), elite numbers at each slot's level (D642), and a bestiary entry in en/uk. Both of its
slots spawn it: DesertRoad `Fight_Caravan` (level 3) and Laboratory `Fight_Lower` (level 10). Neither is a first
encounter with two big or cursed kinds (D582). The sheet came with its idle, attack and death cells facing **left**,
so I mirrored them in place. Not done: nothing in scope. D-IDs: **D704, D705** (text below; renumber as needed).
B rows fixed: none. New B row proposed: the generator's left-facing base (below). Full suite: 117 PASS after the `verify_gates` fix (first run: 113 PASS, 4 FAIL, see Results).

## D-ID text (for the register; the next free numbers after D692, other routines run beside, renumber as needed)

| D704 | ROUTINE CALL | **The armoured scorpion, as built** (D652, D681, D692; `cloud/big-scorpion`). `Scenes/Characters/Enemies/enemy_armoured_scorpion.tscn` is the bandit base scene with the D692 sheet (`Enemies/scorpion_armoured/sheet.png`, 128×80 cells, 3 × 5: idle 2, walk 2, attack 3, hurt 1, death 3) at ×1.25. Its drawing is 127.5 × 92.5 px, so it stands about 1.2× the hero and is 1.7× as wide as the ordinary scorpion (74 × 52). The feet line matches the other enemies (drawn bottom +28.75). Shapes measured from the frames (D519): hurtbox 127.5 × 92.5, strike from the centre forward 72.5 px (the sting, frames 7–8 from `attack_strike_time` 0.7), stagger = the hurt frame. The **blocking body is 64 × 32**, not the 32 × 32 torso: a 128-px beast with a 16-px half-body let the hero stand inside its drawing (an agent call, like the bosses' bigger bodies). `enemy_stats_armoured_scorpion.tres` is the scorpion's (`tank`) behaviour and base numbers unchanged: 215 HP, damage 28, front ×0.3, super armour, dodge tell, windup 1.0, XP 70. Only `attack_range` changes, 46 → **78**, where the 72.5-px sting lands on a hero standing still. The elite multipliers (HP ×2.5, damage ×1.5, XP ×1) and the fight level do the rest: Caravan L3 has 645 HP and 58.8 damage; Lab Lower L10 has 1559 HP and 193.2 damage. `verify_difficulty`: at L3 both builds win (11 / 12 hits), and at L10 STRENGTH loses and SKILLS wins (D642 / D668 [3]). Coins 6–9 (the scorpion's 4–6, plus a bit for an elite). Voice pitch 0.6 (the scorpion's is 0.75). Bestiary «Armoured Scorpion» / «Броньований скорпіон». **Art fix:** the D692 sheet's idle, attack and death cells faced left. The candidate base (seed 134, three-quarter) faces left, and every edit made from it kept that facing. Walk and hurt were prompted "to the right". Cells 0, 1, 6, 7, 8, 12, 13 and 14 are mirrored in place, so the whole sheet faces right as the game expects. |
| D705 | ROUTINE CALL | **Where the armoured scorpion stands** (D582, D617, D682). Its two slots, unchanged: DesertRoad `Fight_Caravan/BigSlot_ArmouredScorpion_1` (x 3640, level 3, the optional fight that guards the ledge chest, with a jackal, a shield-bearer, an ordinary scorpion and a vulture) and Laboratory `Fight_Lower/BigSlot_ArmouredScorpion_1` (x 1250, level 10, the group before the boss save point, with a shield-bearer, the cursed-jackal slot and an ordinary scorpion). The first encounter is the Caravan, and no other big or cursed kind stands there. Lab Lower will hold the cursed jackal too once it lands, but that is neither kind's first encounter (the cursed jackal first meets the hero in Lab Upper). `verify_difficulty` [0b] now checks that every live big or cursed kind first meets the hero with no other big or cursed kind (live or slot) in the same fight. Known gap: until the bandit brute's art lands, the Caravan scorpion (x 3500) comes before the lone elite (x 4300), so a hero who takes the optional chest fight meets his first elite in a group, not alone as D617 planned. I kept the placement. The Caravan is the optional, rewarded big fight that D582 allows, the numbers hold at L3 for both builds, and the brute's art will restore the lone-elite lesson. If the order matters before then, it is Sapega's call. |

## B row proposed (for BUGS.md; the orchestrator files it)

- **comfy_sprite base facing:** `_pick("big_armoured_scorpion", …)` builds idle, attack and death from the candidate,
  and that candidate faces left (seed 134, three-quarter). Walk and hurt are prompted "to the right", so a regenerated
  sheet comes out mixed again. The committed sheet is fixed by mirroring the cells. A re-run of the generator needs
  `FLIP` on those rows, or a right-facing base. Check the other D692 picks (`jackal_leader`, `archer_heavy`,
  `vulture_old`) the same way: idle and walk should face the same way.

## D582 check: every placement

| Slot | Fight (level) | Others in the fight | First encounter? | Other big / cursed kinds |
|---|---|---|---|---|
| DesertRoad `Fight_Caravan/BigSlot_ArmouredScorpion_1` | Caravan (3), optional, guards the chest | jackal, shield-bearer, scorpion, vulture | **yes** | none |
| Laboratory `Fight_Lower/BigSlot_ArmouredScorpion_1` | Lower (10), before the boss | shield-bearer, scorpion, `BigSlot_JackalCursed_3` | no | cursed jackal (slot; its first is Lab Upper) |

Seen while checking, outside this kind: DesertRoad `Fight_Dunes` holds the pack leader's only slot (its first encounter)
next to a `BigSlot_BanditBrute_1`. Once both are live, `verify_difficulty` [0b] will fail on Dunes. This belongs to
`cloud/big-leader` and the brute.

## What changed (files)

- `Scenes/Characters/Enemies/enemy_armoured_scorpion.tscn`: new.
- `Resources/Enemies/enemy_stats_armoured_scorpion.tres`: new (the tank's numbers, `attack_range` 78).
- `Assets/Characters/Enemies/scorpion_armoured/sheet.png`: 8 cells mirrored. `README.md` and `sheet.png.import` are new.
- `Resources/Data/enemy_variety.json`: `kinds.armoured_scorpion.sheet` → `scorpion_armoured/sheet.png` (the folder
  D692 used). This is the only line touched.
- `Resources/Data/sound_events.json`: `enemy_voice_pitch.armoured_scorpion` 0.6, placed after `tank`.
- `Resources/Data/bestiary.json`: an entry after the Giant Scorpion. `en.po` / `uk.po`: its name and text.
- `Scripts/Gameplay/DefaultEnemy.gd`: a `_calculate_coin_drop` case after `tank`.
- Tests: `verify_enemy_variety` gets a new [6] (live, the scorpion's behaviour, both slots spawn it, elite numbers at
  L3 / L10, bestiary en/uk). `verify_hit_areas` checks the new scene in [1] and its strike in [3]. `verify_difficulty`
  gets the kind's name and the new [0b] D582 first-encounter check. `verify_gates`: the hero is kept alive in the Caravan fight it wins for the key.
- `UI/capture_armoured_scorpion.gd`: new, shot `design/shots/enemy_variety/armoured_scorpion.png`.

Merge notes for `cloud/big-leader`: the same files will grow neighbouring lines (`sound_events.json` voice-pitch line,
the `bestiary.json` / `.po` entries, the coin `match`, `KIND_NAMES`, `verify_hit_areas` `KINDS` and the [3] case
list). Take both sides. The two `.import` files for `jackal_leader` / `archer_heavy` that an import creates are left
uncommitted here.

## Results

- `verify_enemy_variety`: RESULT: ALL PASS ([6]: «Fight_Caravan, level 3: an elite, HP 645, damage 58.8, XP 70»,
  «Fight_Lower, level 10: an elite, HP 1559, damage 193.2, XP 70»).
- `verify_hit_areas`: RESULT: ALL PASS («hurtbox (127.5, 92.5) = drawn body», «hitbox (72.5, 91.25) = drawn strike»,
  «attack_range 78 starts a strike that reaches (body contact 44, reach 84)», hit at 3 px inside, missed 6 px past).
- `verify_difficulty`: RESULT: ALL PASS ([0b]: «armoured_scorpion first meets the hero in DesertRoad/Fight_Caravan,
  with no other big or cursed kind», the same for the fly in Lab `Fight_Fly`).
- Full suite (`Scripts/Tools/run_verify.sh`, 117 tests; the run was resumed after the background limit cut it at
  `verify_crafting`): 113 PASS, 4 FAIL.
  - `verify_cutscene`, `verify_damage_numbers` and `verify_demo_end` hung for 180 s. All three PASS on a re-run on this branch
    and on `origin/feature/backlog`, so these were transient hangs, not this change.
  - `verify_gates` (9 FAIL) **was this change**. The test parks the hero (about 100 HP) for 4 s, twice, inside the Caravan
    fight to win the bandit key. The Caravan now holds the elite scorpion (sting 58.8), so the hero went down to 10 HP and
    the game paused, and every later step failed. Fixed in the test, not the game: it is a gates test, so the hero gets
    99999 HP for those waits, like `verify_hit_areas` does. Now `PASS  verify_gates`. It also shows the Caravan is a real
    elite fight at level 3, as intended.
- Shot `design/shots/enemy_variety/armoured_scorpion.png`: (1) the Caravan fight as spawned, with the big scorpion on
  the left and the jackal and shield-bearer behind; (2) the hero, the big scorpion and the ordinary one side by side;
  (3) the sting frame with F9 zones: yellow hurtbox, red hitbox from the centre toward the hero, white bodies.
  My first capture showed the attack pose facing away from the hero, and that is how the left-facing cells were found.
