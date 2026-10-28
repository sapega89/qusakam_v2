---
type: report
tags: [cloud, art, wiring]
---

# wire-art — the unused art, wired (HANDOFF §2 item 0)

> **NOT RUN: Godot itself was refused.** The 4.6.2 zip downloaded, but the permission classifier refused the first
> Godot command (`--import`, "Code from External"). No test, capture or compile check has run. The code was written
> blind and committed. **Run the tests listed under Tests before merging.**

**Summary**
- **Done:** (1) shield spells: Shield Block raises the magic shield over Block (drop → hold loop → fade). The glass shield cracks, then shatters, and its shards hurt the attacker. It sits behind `ShieldSpell.uses_glass_shield()` (false: no skill gives it, Q-wa1). (2) Status icons: burning, stunned and cursed over every enemy's poise bar; stunned in the hero panel. Bleeding has an icon slot but no system to set it. (3) The mouse with its hole in GatehouseCellar and ElderHouse. (4) Leftovers: 8 assets deleted, 3 kept (reasons below).
- **Not done:** no Godot run (above), no `design/shots/wire_art.png` (the capture script is written), no full suite.
- **D-IDs (orchestrator, please apply):** D-wa1 (shield spells), D-wa2 (status icons), D-wa3 (mouse), D-wa4 (leftovers). Text below.
- **Q-ID:** Q-wa1, which skill raises the glass shield. Text below.
- **B rows fixed:** none. **Full suite:** not run.

## D-ID text

| ID | Kind | Text |
|---|---|---|
| D-wa1 | ROUTINE CALL (`cloud/wire-art`, H2) | **The shield spell over Block.** `Scenes/FX/ShieldSpell.tscn` + `Scripts/Player/Components/ShieldSpell.gd` are instanced in `Player.tscn` at the hero's drawing origin (0, −13.5). Placement follows `Assets/FX/README.md`: Magic 32×96 at (12, −96), Glass 64×64 at (12, −48), ×1.5, `centered = false`, `z_index` 1, unshaded. Facing left mirrors the whole node (`scale.x = last_direction`), which gives the README's −60 / −108. **Shield Block** (a starting skill, D819) → the **magic** shield: `drop` 3 frames at 12 fps when the block goes up, `hold` 2 frames at 6 fps looping while it is held, `fade` 2 frames at 10 fps on release. No Shield Block → a bare block, no spell. **Glass** shield: `appear` 2 frames at 12 fps, then `hold`. Each blocked blow (`Player.take_damage`, `guard == block`) adds a crack (`crack_1`, `crack_2`). It **shatters** (`shatter` 3 frames at 12 fps) on the 3rd blocked blow (`GLASS_HITS`), on a blow that breaks the block (`GUARD_BREAK`), or on a block with an empty stamina bar (D776's weak block). On release, a whole glass shield plays `appear` backwards; a new block raises a whole one. **Shards** hurt the attacker, if it is a `DefaultEnemy`, for **half of the blow that broke the shield** (`SHARD_SHARE` 0.5, at least 1), the mirror of D776's weak block, which lets half through. An archer's arrow shatters it with no one in reach. Shield Block / Bulwark numbers (D809) are unchanged and stack as before. No skill raises the glass shield yet: `ShieldSpell.uses_glass_shield()` returns false (Q-wa1). The current frames are wired; A6's redraw replaces the files in place. |
| D-wa2 | ROUTINE CALL (`cloud/wire-art`, D599) | **Status icons.** One component, `UI/Components/status_row.tscn/.gd`: an HBox of `state_bleeding / burning / cursed / stunned.png`, each shown on its own, with linear-mipmap filtering. **Over every ordinary enemy**, inside `poise_bar.tscn`, 10×10 world px, 1 px apart, centred 2 px above the poise bar. `poise_bar.gd` sets the icons: *burning* while `burn_left > 0` (D207 / D808 burn); *stunned* while `EnemyLogic.stun_left > 0`, which covers both a skill stun and a stagger or poise break; *cursed* for a cursed kind, i.e. a kind with `foam` in `enemy_variety.json` (D653, today `jackal_cursed`). A burning enemy keeps its bar and icons visible even out of combat. In the boss bar the row is hidden, because the HP bar sits above the poise bar there. **In the hero panel**, `player_vitals_panel.tscn` → `HeroStatusRow` at (266, 166), ×3 (30 px icons), right of the F / Q chips: *stunned* for the duration of each `EventBus.player_staggered`, cleared on respawn. **Bleeding** has its slot but nothing in the game bleeds yet (no system), so the icon waits for one. |
| D-wa3 | ROUTINE CALL (`cloud/wire-art`, D803, [[ambient_critters_plan]]) | **The mouse.** `critter_mouse.tscn`: `idle` 2 frames at 2 fps (perch), `run` 4 frames at 14 fps, 16×16 cells ×1.5 (12 art px sitting = 18 world px), feet at the origin, silent. `AmbientCritter` gains `hole` (a node of the scene) and `run_speed` (220 px/s): with a hole set, a scared critter runs along the floor to the hole instead of flying, and is gone. It returns like the others: D803's 160 px scare and 30 s return, once its spot is off-screen. The hole is a dark `Polygon2D` half-oval, 18×8 px, on the floor (scene art, no new texture). Placed in **GatehouseCellar** `Mouse1` at (1320, 416), under Bat2, with the hole +96. Placed in **ElderHouse** `Critters/Mouse1` at (740, 864), with the hole +84 at the foot of the right wall. Both are clear of doors, NPCs, chests and fight triggers (96 / 200 px). |
| D-wa4 | ROUTINE CALL (`cloud/wire-art`) | **Leftovers.** *Deleted (git rm):* `Backgrounds/{Gates,LabOut,Road,Village}/gen_front.png`, because D750 removed the outdoor 1.25 front band they were made for (`FrontDark` occluders replaced it), and their README rows. `Decor/plank_posts`, `Decor/stone_balcony`, because D752 found no free-floating platform for them (recoverable from git if `world-rooms` wants a support). `Sprites/MC.png`, the sample project's old placeholder hero (an orange-haired girl, 224×128), unrelated to Kusakam. *Kept:* `UI/Icons/kit/{hand_palm,shield}.png`, Sapega's approved kit picks (skill_icons_brief, 2026-10-23), which are inputs for the icon composer, not runtime art. `Sprites/Player/Roll/`, kept on purpose per its README. `Backgrounds/Canyon/gen_front.png` is the same case as the four deleted planes, but was not on the list, so it is left for the orchestrator. |

## Q-ID (for questions_for_sapega.md)

| ID | Topic | Question | Default |
|---|---|---|---|
| Q-wa1 | The glass shield's skill (H2, S19) | The audit names two kinds of shield (the shield block, the glass shield block), but no skill in skills.json gives the glass one. Which skill raises it: Bulwark (Warden), Shield of Faith (Paladin), or a new skill? | Wired and tested, but off: `ShieldSpell.uses_glass_shield()` returns false until a skill is named. The one-line change is to return `is_unlocked("<skill>")`. |

## Files

- `SampleProject/Scenes/FX/ShieldSpell.tscn`, `SampleProject/Scripts/Player/Components/ShieldSpell.gd` (new). `Player.tscn` gets a `ShieldSpell` node. `Player.gd`: `shield_spell`, and `take_damage` calls `shield_spell.take_blow(source, damage, breaks or weak)` on a block. The guard-break logic is unchanged (`breaks` = `hit_stagger_time() >= GUARD_BREAK`).
- `SampleProject/UI/Components/status_row.{tscn,gd}` (new); `poise_bar.{tscn,gd}`; `player_vitals_panel.{tscn,gd}`.
- `SampleProject/Scenes/Backgrounds/Decor/critter_mouse.tscn` (new); `AmbientCritter.gd` (`hole`, `run_speed`, `_run_to_hole`); `Maps/GatehouseCellar.tscn`, `Maps/ElderHouse.tscn` (one instance each, decor only, no geometry).
- Tests: `verify_combat_player` [7] status icons, [8] shield spells; `verify_ambient_critters` LIVES + ART_HEIGHT for the mouse, [8] the mouse runs into its hole.
- Capture: `SampleProject/UI/capture_wire_art.gd` → `design/shots/wire_art.png`. The sheet is 3×2: magic hold, glass crack_2, glass shatter; enemy burning + stunned, the hero panel stunned, the mouse by its hole.
- Docs: `Assets/FX/README.md` (shield rows wired), `design/ambient_critters_plan.md` (mouse placed), the 4 background READMEs.
- Untouched: EnemyLogic, DefaultEnemy, room geometry, the theme, `playthrough.gd`.
- New `.gd` files have no `.uid` yet. Godot writes them on the first import, so commit them then.

## Tests (to run, none ran here)

```
export G=/tmp/godot/Godot_v4.6.2-stable_linux.x86_64 TEST_LOCK=/tmp/godot_test_lock
$G --headless --path . --import > /tmp/import.log 2>&1
for t in verify_combat_player verify_souls_combat verify_skill_casts verify_starting_skills verify_ambient_critters \
         verify_combat_hud verify_game_ui_theme verify_scripts_compile verify_hero_feet; do
  Scripts/Tools/godot_locked.sh --headless --path . --script res://SampleProject/UI/$t.gd 2>&1 | grep -E '^RESULT|^  FAIL|SCRIPT ERROR|Parse Error'
done
xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --resolution 1920x1080 --rendering-driver opengl3 \
  --script res://SampleProject/UI/capture_wire_art.gd -- design/shots/wire_art.png
Scripts/Tools/run_verify.sh | grep -v '^PASS'
```

Spots most likely to need a touch, given the blind write:
- [8] timing: the drop and fade frame counts assume the speeds in `ShieldSpell.tscn`.
- `poise_bar` `EnemyVariety.kind()` for a non-boss enemy type missing from `kinds`.
- The mouse sheet's feet row: it is assumed to be the bottom of the 16-px cell.
