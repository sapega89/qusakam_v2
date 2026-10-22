---
type: cloud-report
tags: [cloud, art, combat]
---

# art-fixes-wire — wiring the fe96e88a art (remaining_work Art 3–4)

**Summary.** Done: dagger `Heavy/1–3`, `Attack2/2–3` and dual `Hurt/1` play from their own frames; bandit, jackal,
scorpion, Brass Collector and fire djinn play `stagger.png` for the whole stagger, then their sheet again; B105 fixed
through `MANUAL` rectangles in `weapon_key_fixups.py`; the in-place sheet fixes kept their cells (no wiring); all of it
in game in one image, `design/shots/art_fixes_all.png`.
**D-ID text (new, agent call, Sapega to confirm):** «Enemy stagger pose (D264, remaining_work Art 4): an enemy or boss
with a `stagger.png` plays it for the whole stagger — frame 0 (knocked back) for the first 30 %, frame 1 (dazed) for
the rest — with the blue stun tint on top, then its normal animation; killed while staggered, it dies with its own
death frames. The archer has no stagger art and keeps the tint alone.»
**B rows fixed:** B105 (halberd butt spike, dual dagger in `Heavy/1` and `Run/7`, off-key blades in dual `Air/3`,
shoulder in `sword/Attack3/2`); its `Run/2`, `Run/4` and `sword/Attack2/2` parts do not reproduce (below).
**Full suite:** `SUITE: 2 FAIL` — `verify_game_ui_theme` (expected) and `verify_combat_flow` (two player-hit checks under
full-suite load; alone on the same tree `RESULT: ALL PASS` — it tests the hero being hit, which this branch does not touch).

## 1. Weapon frames

- `Scripts/Tools/weapon_libraries.py` — the `dagger` and `dual_sword_dagger` overrides are gone; the libraries are
  rewritten from the frame folders: `dagger/HeavyWindup` = `Heavy/1`, `HeavyStrike` = `Heavy/2`, `Heavy/3`,
  `dagger/Attack2` = `Attack2/1–3` + `CombatIdle/1`, `dual_sword_dagger/Hurt` = `dual/Hurt/1`.
- `verify_weapon_animations` [0b] checks those frame lists: `RESULT: ALL PASS`.
- The dagger and dual READMEs say «wired» now.

## 2. Enemy stagger pose

- Each of `default_enemy.tscn` (bandit), `enemy_fast.tscn` (jackal), `enemy_tank.tscn` (scorpion),
  `brass_collector.tscn`, `fire_djinn.tscn` has an animation `stagger` (length 1 s): `Sprite2D:texture` = its
  `stagger.png`, `hframes` 2, `vframes` 1, `frame` 0 → 1 at 0.3 s. Cells are the sheet's size with the same feet row
  (bandit 64×64, jackal/scorpion 96×72, bosses 96×112 — checked), so the sprite offset stays.
- `EnemyView.gd`: `play_stagger(duration)` sets `speed_scale = length / duration` (the pose lasts exactly the stagger:
  0.6 s poise break, 1.0 s parry); while `staggered`, `update_state` and `on_attack_ended` only record the state
  (the broken swing's `attack_ended` arrives after the stagger starts and used to cut it); `end_stagger()` restores
  the sheet, hframes, vframes and plays the state's animation (`idle` between swings).
- `DefaultEnemy.gd`: `stagger()` plays the pose when the scene has one (`has_stagger_pose()`); `_physics_process`
  ends it when `stun_left` runs out; `die()` restores the sheet first. `BossEnemy.gd`: its two `idle` plays wait for
  the stagger to end. The `STUN_TINT` modulate is unchanged and shows on top.
- Not changed: `stun()` (skills) keeps the tint alone — it is not a D264 stagger.
- Test `verify_enemy_stagger.gd` (new): for all five — stagger.png 2×1 and frame 0 at once, the tint, still the pose
  at 60 % with frame 1, after the stagger the sheet and its cells back, a normal animation at speed 1, tint gone;
  a bandit killed in stagger dies with the sheet's death frames; the archer keeps its sheet with the tint.
  `RESULT: ALL PASS`. Also run: `verify_souls_combat`, `verify_bosses`, `verify_lab_boss` — `ALL PASS`.
- `scorpion/stagger.png.import` was missing from 5ce1ec39 — committed.

## 3. B105 — weapon palette key

`Scripts/Tools/weapon_key_fixups.py` gets `MANUAL`: per-frame rectangles applied after the heuristic, each with a
colour swap — `WEAPON` (body twin → key), `BODY_TWIN` (key → twin) or off-key blade colours → key. It now counts net
pixel changes, so a rerun prints 0 for every set (checked).

| frame | rectangle | swap |
|---|---|---|
| `halberd/Air/1` | 60–61, 79–80 | butt spike → key |
| `halberd/Block/1` | 56–58, 84–86 | butt spike → key |
| `halberd/CombatIdle/1–4` | 40–42, 84–87 | butt spike → key |
| `dual/Heavy/1` | 49–68, 71–72 | dagger at the chest → key (the chest armour above stays twin) |
| `dual/Run/7` | 50–68, 77–84 | dagger → key |
| `dual/Air/3` | 64–79, 40–64 | sword: `#FCF3D5` → light, `#C0C0C0` → mid, `#F4CE8A` edge → dark, twins → key |
| `dual/Air/3` | 43–60, 73–81 | dagger: `#FCF3D5` → light, `#C0C0C0` → mid |
| `sword/Attack3/2` | 41–48, 59–62 | shoulder plate → body twin |

- Does not reproduce: `dual/Run/2` and `Run/4` have no `#FCF3D5` at all — their daggers are already in the key; in
  `dual/Air/3` the **sword** was off-key too (not only the dagger), now fixed. `sword/Attack2/2`: every key pixel is
  the blade, guard or grip (traced pixel by pixel at 20×) — no arm pixel tints.
- The new dagger `Heavy/1–3`, `Attack2/2–3` and dual `Hurt/1` were checked with the same tool: blades in the key,
  body off it; the tool changes nothing in them.
- `verify_weapon_animations` [0] (key metal in every animation): pass.

## 4. In-place sheet fixes

Old (fe96e88a^) vs new, per cell: every sheet keeps its size (Malik 256×288, alchemist 256×384, priestess 256×288,
grandfather 192×192, djinn 288×560, boss far 576×324) and every changed cell keeps its bottom row (feet / flame
tail); only the content inside moved (alchemist mask; priestess work cells lose 2 px on the left — the stick;
grandfather idle 11 px narrower; djinn cell 12 arms wide). So no `.tscn` or animation changes were needed.

`design/shots/art_fixes_all.png` (`SampleProject/UI/capture_art_fixes.gd` → `Scripts/Tools/art_fixes_sheet.py`),
all in game under the game camera: Malik in his cell (robe solid behind the bars), the alchemist at his table (grey
mask), the priestess praying (no stick), the grandfather idle (staff in the near hand), the djinn's death 0, the dagger
`HeavyWindup` / `HeavyStrike` against a bandit, that bandit's stagger frames 0 and 1 (blue tint), the LabBoss hall
with the triangular glyphs. Noise in the shots: the dialogue portrait in the alchemist tile, the boss-bar inset in
the djinn tile, «Hold Tab to skip» of the boss intro.

Capture notes: the capture moves the hero by position, so it resets the camera itself (after a new game the prologue
cutscene leaves the camera `top_level`; a teleport during it keeps it there — not a player path) and calls
`combat.heavy_attack(1)` directly (an `InputEventAction` under xvfb did not always reach `Player._input`).
