---
type: report
status: done
tags: [cloud, bugs, playtest]
---

# Cloud report — `cloud/bugfix-1` (2026-10-23)

**Summary.** B142 is fixed: an enchanted weapon loaded `Assets/Weapons/iron_sword+1.png`, which does not exist. The release
build **segfaults** on that null texture (reproduced: exit 139). B144, B138, B141, B143, B120 and B121 are fixed, each with a
check that fails before the fix and passes after. **B145 is not reproduced:** the Canyon descent ran without a crash in the
debug build, the Linux release build headless, and the release build under OpenGL, with and without tutorial windows. Its
most likely cause is B142 (see §2). **B rows fixed:** B142, B144, B138, B141, B143, B120, B121. B145 stays open.
**D-ID:** D678 (below). **Full suite:** `SUITE: 2 FAIL`, 112 PASS. `verify_lab_boss` fails the same way on `feature/backlog` (new B row proposed below). `verify_audio` failed only inside the suite run and passes alone.

> **D678** | ROUTINE CALL | **The Mayor Hall boss carries the D642 boss numbers** (B144; `cloud/bugfix-1`). The Scorpicore
> axe-warrior takes the numbers `cloud/difficulty` gave the Brass Collector: `base_damage` 120, `attack_cooldown` 1.3 s,
> `max_health` 3900. It keeps its own move multipliers (slam ×1.3, charge ×1.15). At level 5 the SKILLS hero falls in 4 hits
> and needs 38. The STRENGTH hero loses: 51 hits needed, survives 3 blows. The heaviest move (156) never kills a full-HP hero
> at once. D642 is checked only by `verify_difficulty`, which takes boss names from the boss scenes. `verify_mayor_boss`
> prints its "nothing invested" hero numbers as info. A hero with no attributes and no armour is not a D642 build.

## 1. B142 — an enchanted weapon crashed the game (blocker)

- **Cause.** `Scripts/Player/Components/WeaponView.gd` loaded the weapon sprite by the item id: `TEXTURE % item.id` in
  `_set_texture` and `drawn_swing_rect`. An enchanted id (`iron_sword+1`, D94) has no file, so `load()` gave null and
  `.get_width()` / `.get_height()` were called on null. In the debug build that is a SCRIPT ERROR. In the **release** build it
  is a segfault. A driver in the exported Linux release build that equips `iron_sword+1` exits with 139 before the fix, and
  after the fix it equips, swings and plays on.
- **Fix.** Both loads go through `ItemDatabase.base_id()` (`WeaponView.gd:190`, `:358`).
- **Second error found by the test.** When a save loaded with a weapon in hand, `WeaponView._ready → _refresh → _hold_pose`
  read `player.combat` before the hero's `_ready` had set it (SCRIPT ERROR `'state' on Nil`). The first refresh now waits for
  `player.ready` (one-shot). A release build did not crash on this one; it was an error, and now there is none.
- **Other id-as-key places checked, all fine:** icons (`get_item_icon` uses the duplicated base `icon_path`), category,
  grip, palette and the hero's frame library (`body_library` uses the category), stats (`_enchanted_item`), save modules
  (ids → counts, equipment ids restored).
- **Test.** New `verify_enchanted_equip.gd`: every enchantable item (12) at +1..+20 equips in its slot. For weapons it is
  also drawn, with a sprite, and swings. An Iron Sword +1 and an Iron Armor +3 survive save → load, and the sword is in hand
  with its sprite. Before the fix: `RESULT: 8 FAIL` and 315 SCRIPT ERRORs. After: `RESULT: ALL PASS`, no SCRIPT ERROR.

## 2. B145 — crash going down from the Canyon (blocker, not reproduced)

What was run:
- `verify_canyon_exit` and `verify_lab_route` (debug, headless): `ALL PASS`, no SCRIPT ERROR.
- A driver scene (temporary, not committed) does the real descent: the flags after the village, a walk to the edge, the
  exit cutscene and its talk. Then 150 s on the Desert Road walking right, jumping and attacking, with vultures and bandits
  hitting the hero. It ran in four setups:
  - the debug binary;
  - the **Linux release export, headless**;
  - the **Linux release export under Xvfb with the OpenGL renderer**;
  - that release run again with **tutorial windows on**, closed with Esc as a player would.

  No crash and no SCRIPT ERROR in any of them.
- How to run a scene in a release export: release templates refuse `--script` and a scene path on the command line. An
  `override.cfg` beside the binary that sets `application/run/main_scene` works.
- Checked and ruled out: `assert()` calls with side effects (none; release strips asserts), textures over 8192 px (none),
  and export excludes hiding a referenced resource (none).

**Most likely cause: B142.** Sapega reported the enchanted-sword crash on the same round 12 build. The Desert Road below
the Canyon is the first fight after the Village, where the blacksmith enchants. Equipping an enchanted weapon or swinging one
(`drawn_swing_rect` runs on every attack) segfaults the release build. This was reproduced for equipping and is fixed.
**Not proven:** whether Sapega had an enchanted weapon equipped on the way down. The log was lost (now 50 are kept).
**Rule learned:** every SCRIPT ERROR the debug tests print is a possible native crash in the export. `run_verify.sh` already
fails on any SCRIPT ERROR. B145 stays open until the next playtest on this branch.

## 3. B144 — Mayor Hall boss too easy for D642

`Scenes/Characters/Bosses/scorpicore_warrior.tscn`: `base_damage` 48 → 120, `attack_cooldown` 1.8 → 1.3, `max_health`
2600 → 3900 (D678). `verify_difficulty.gd` took boss names from a stale dict ("Brass Collector", "Fire Djinn"); it now reads
`display_name` from the boss scene. `RESULT: 2 FAIL` → `ALL PASS`. Its table:

| enemy | lvl | build | HP | hit | H | H+F | e.HP | N | wins |
|---|---|---|---|---|---|---|---|---|---|
| Scorpicore Axe-Warrior | 5 | STRENGTH | 204 | 120 | 3 | 4 | 3900 | 51 | no |
| Scorpicore Axe-Warrior | 5 | SKILLS | 246 | 120 | 4 | 6 | 3900 | 38 | yes |

`verify_mayor_boss`: its 4 D642 checks used a hero with no attributes, armour or skills. They are now info lines (D678).
`ALL PASS`. `verify_mayor_hall`: `ALL PASS`.

## 4. B138 — the saved HP was ignored on load

- `Game._save_full_game_data_to_save_system()` writes the hero's live HP into `player_state` through
  `PlayerStateManager.update_player_health()`, which had no callers. Before this, `player_state.current_health` stayed at
  its default of 100.
- The load branch of `Game._initialize_save_and_room()` calls the new `Player.restore_health()`. It recomputes Max HP from
  the loaded level, gear and skills, then clamps the saved HP into it.
- Note: saves made before this branch hold the old default of 100 and load at 100 HP (capped at Max HP).
- Test: `verify_save_load_room` saves at 37 HP. Before: `1 FAIL … (110/110, saved 37/110)`. After: `ALL PASS`.

## 5. B141 — Laboratory Outside: the hero stood 56 units above the grass

The room is right: the floor collision is y 384, the top of `LaboratoryOutside_Terrain` (probed down from the painted
line). A hero walking out of the Laboratory stands at y 360 on the floor. The float came from `capture_world_fixes.gd`. It
places the hero at `Arrival.y − 40`, and the demo-end screen disables his movement, so he hung where he was put. The capture
now re-enables movement after it removes the screen, so he falls onto the grass. It also no longer names the `DemoEndScreen`
type, which stopped the script compiling before the autoloads (no capture of it ran). `verify_lab_route` now checks that the
hero outside is on the floor, below the Arrival mark: `ALL PASS`. Shot:
`design/shots/bugfix_1/B141_LaboratoryOutside_after.png` (hero on the grass; before: `design/shots/world_fixes/LaboratoryOutside.png`).

## 6. B143, B120, B121

- **B143** — `tutorial.json` block topic, `en.po`, `uk.po`. Text and hint: yellow glint → tap {block} as the blow lands
  (parry); a red glint cannot be blocked or parried, so roll (D573, D574). `verify_tutorial_hints` checks it: `ALL PASS`.
- **B120** — `crafting_recipes.json` `craft_potion` `gold_cost` 4 → 8 (D416: 10 % of 2 × 40). `verify_crafting` now checks
  the D416 rule on all 18 recipes: `ALL PASS`.
- **B121** — `verify_misc_modal` drops `or true`. For each row, `find_valid_focus_neighbor(SIDE_BOTTOM)` must be the next
  row: `ALL PASS`.

## Full suite

`Scripts/Tools/run_verify.sh`: 112 PASS, `SUITE: 2 FAIL`.

- `verify_audio`: `RESULT: 1 FAIL` inside the suite run. Run alone right after: `RESULT: ALL PASS`. Timing under load; no
  audio file was touched.
- `verify_lab_boss`: `RESULT: 2 FAIL: balanced build: he dies in 2.6 of the mercenary's blows (406 HP; mace 129, club
  206), balanced build: the mercenary takes 60 light hits (6800 HP, Phys. Atk. 100)`. The **same 2 FAIL on
  `origin/feature/backlog` @ `1a1fd911`**, checked in a clean worktree, so this branch did not cause it.

**Proposed new B row (for the orchestrator):** *B146 — `verify_lab_boss` still checks the Mercenary against its pre-D642
"balanced build"*. Since `cloud/difficulty`, the Mercenary has 6800 HP and hits for 180, with a ×1.6 slam. `verify_difficulty`
passes it for the SKILLS build at level 12 (4 hits kill the hero, 45 to kill it), while `verify_lab_boss` still expects its own
balanced-build numbers. This is the same conflict as B144: one of the two tests has to give way, and D678's call (D642
lives in `verify_difficulty`) would settle it the same way. Severity: test. Not fixed here: it is outside this task's list.
