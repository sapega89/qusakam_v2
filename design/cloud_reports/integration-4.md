---
type: cloud-report
branch: cloud/integration
date: 2026-10-22
tags: [cloud, integration]
---
# Cloud report: integration-4

This report is named `integration-4` because `integration-2.md` and `integration-3.md` already existed from earlier
runs. The stored prompt names the file `integration-2.md`. I did not overwrite it.

Start: `origin/cloud/integration` (integration-3, `479183e4`), then `origin/feature/backlog` merged in. That was a
fast-forward and brought the owner's A3 dual-wield rework and the A4 bow art (`87c56f92`, `6f44c4aa`). Godot 4.6.2 ran
headless on Linux. There was no display, so there are no captures. `project.godot`, `MainMenu.tscn`, `GameUITheme.tres`
and `playthrough.gd` are byte-identical to `origin/feature/backlog`; I checked after every merge.

## Merged branches

| Branch | Merge commit | Report |
|---|---|---|
| `cloud/lab-9-8` | `968ce36e` | [[cloud_reports/lab-9-8]] |
| `cloud/localization-2` | `a00d5f38` | [[cloud_reports/localization-2]] |
| `cloud/weapons-all` | `650c3ec2` | [[cloud_reports/weapons-all]] |
| `cloud/bow` | `e4dc0e2c` | [[cloud_reports/bow]] |

Integration-1/2/3 had already merged these: `b82-b10`, `buildings`, `chests`, `dialogue-ui`, `lab-9-5`, `lab-9-6`,
`lab-9-7`, `localization-1`, `onboarding`, `settings-cleanup`, `skills-screen` and `weapon-gamepad`.

**Unfinished branches:** none. `cloud/bow` had no report when the run started. Its report landed during the run, so I
merged it last.

My own commits:
- `3d1ec06b`: the `.import` sidecars for the owner's A4 bow art.
- `07e6b85e`: merge fix, Crystal Sword (described below).
- `04c65734`: the `.gd.uid` sidecars for `verify_bow`, `verify_archer` and `capture_bow`.
- `964f06bc`, `5c41f705`: the registers.

## Conflicts and how I resolved them

- **`.import` sidecars (add/add, every merge).** Several branches ran `--import` on the owner's dual and bow frames, so
  each side made the same sidecar with its own uid. For `dual/**` I kept ours (the first one in). For `bow/**`,
  `arrow_charged` and `bandit_archer/sheet` I took `cloud/bow`'s copy, because its `Player.tscn` was built against them.
  Every library `.tres` and `Player.tscn` names textures by path only, so neither choice breaks a reference.
- **`Voice/README.md`** (lab-9-8 × localization-2). I kept both rows: the Lab boss voices and `Greetings/uk/`. The voice
  list uses localization-2's English names plus lab-9-8's boss and prisoner voices. The Steam line now names both models
  and lists the roars, laughs and incantation.
- **`Player.tscn`** (weapons-all × bow). Both sides' ext_resources are kept: the four weapon libraries, the palette
  shader and the bow frames. The `ShaderMaterial` sub-resource follows them. The AnimationPlayer mounts `dagger`, `mace`,
  `polearm`, `dual_sword_dagger` and `bow`.
- **`WeaponView.gd`** (weapons-all × bow):
  - `body_library()` follows weapons-all, so any grip uses its library (D359). Bow's `FRAME_GRIPS` gate (one-handed +
    bow) would have switched the halberd's frames off again, so I removed it. The bow still finds its `bow` library by
    category.
  - `pivot.visible` uses both conditions: off while the weapon is drawn in the frame (weapons-all) and never shown for
    `DRAWN_ONLY` (bow).
  - `_refresh()` sets the palette before the bow's early return, as `item.get("palette", "iron")`. The bow has no
    palette, and iron is the key, so a palette left over from the previous weapon (copper, crystal) cannot tint the
    bow's frames.
- **`uk.po` / `en.po`** (bow × localization-2). I kept localization-2's sections and added bow's four strings (Short
  Bow, its description, Desert Archer, its bestiary text). The archer's bestiary text now says «Розбійник» instead of
  «Бандит», to match D357 (Q68). I regenerated `en.po` with `po_sync.py`: 824 keys.

### Merge regression fixed

- **Crystal Sword × localization-2** (`07e6b85e`). weapons-all added `crystal_sword` to items.json with the old
  `name_ru` / `description_ru`, and with no `uk.po` key. localization-2 had removed every Russian field. After the merge,
  `verify_locale` [4] failed: "no uk.po entry: Crystal Sword" + its description. I added «Кришталевий меч» and «Меч із
  живого кришталю, що мерехтить у темряві. Атака: +32» to `uk.po`, dropped the Russian fields and ran `po_sync.py`.
  `po_data_keys.py` now reports 0 missing, and `verify_locale` gives ALL PASS.

## Registered

**Decisions** (`figma_decision_register.md`, all "agent call, Sapega to confirm"):
- **D310** (the row reserved for queue 9.8; lab-9-8): boss voices, cutscene voices, the demo end, the full Lab route.
- **D354–D358** (localization-2):
  - D354: English dialogue text.
  - D355: the locale is resolved when the file is read.
  - D356: ASCII speaker ids.
  - D357: Ukrainian data terms.
  - D358: Piper "lada" greetings.
- **D359–D364** (weapons-all; it called them **D380–D385**):
  - D359: every weapon type wired like the sword.
  - D360: missing frame kinds.
  - D361: palette swap.
  - D362: the palettes.
  - D363: Crystal Sword.
  - D364: the hitbox stays.

  `cloud/bow` also used D380–D387, so weapons-all is the one I renumbered: its IDs appeared only in its own report,
  while bow's are in code comments and `ranged_plan`. The weapons-all report now carries the new IDs and a note saying
  so.
- **D380–D387** (bow): the bow like Skul, bow numbers, moving with the bow, the `bow` grip, heavy/block with the bow, bow
  frames, the desert archer, placement.

**Bugs** (`BUGS.md`):
- **B86** is fixed by localization-2: D356, English character names, and `verify_locale` [5] walks every line through
  the window in both languages. I removed its row.
- Found and fixed on their branches (they are in the fixed log only):
  - **B102**: interaction prompt badge after a room change (lab-9-8).
  - **B103**: SCRIPT ERROR in `combat_hud_top` on a scene change (lab-9-8).
  - **B104**: the overlay weapon came back after the block pose (weapons-all, its B110).
- New open rows:
  - **B105**: palette swap misses (weapons-all B111).
  - **B106**: frames draw a shorter weapon than the hitbox (weapons-all B112).
  - **B107**: Ether says "MP".
  - **B108**: "Lesser Potion" heals more than "Potion". B107 and B108 are localization-2's data candidates; I checked
    both in `items.json`.
  - **B110**: the bow vanishes outside its frames (bow).
  - **B111**: enemy attack tempo ignores `EnemyStats.attack_cooldown` (bow). It keeps its own number, which is free in
    the register.
- **B109** is unused.

**Questions:** **Q68**, «бандит» or «розбійник». Until it is answered, data and speakers say «розбійник» and the part-1
objectives keep «бандит». It is not blocking.

**BACKLOG / queue marked done:**
- BACKLOG: 6, 17 and 23 (D310); 31 (D354–D358); 40 (D380–D387). 42 is partly done (D359–D364; bare hands and other
  dual pairs are left).
- Queue: 9.8, 8g, 8k and the 40 part of 10a.

## Suite

Merge-level verifies (RESULT lines):
- **lab-9-8:** lab_route, audio, interaction, demo_end, lab_boss.
- **localization-2:** locale, lab_route, audio, dialogue_speaker, npc_recall, tasks, companions, status,
  journal_sections.
- **weapons-all:** weapon_animations, souls_combat, scripts_compile, locale (after `07e6b85e`).
- **bow:** bow, archer, weapon_animations, souls_combat, combat_flow, xp_curve, road_sections, city_gates_raid, locale,
  scripts_compile.

All of them gave `RESULT: ALL PASS`.

Full suite `Scripts/Tools/run_verify.sh` after weapons-all (`07e6b85e`): **`SUITE: 1 FAIL`**, 84 of 85 PASS.
After bow (`5c41f705`): SUITE_AFTER_BOW.

The one expected failure is `verify_game_ui_theme`, which prints no RESULT line. It is the known D329 baseline:
`GameUITheme.tres` has to be regenerated on Sapega's machine, and integrators may not commit it.

## Left

- Sapega:
  - Confirm D310, D354–D364 and D380–D387.
  - Read the English dialogue twins (D354).
  - Answer Q68.
  - Decide B106 (a wider halberd cell or a shorter reach) and B111 (whether enemies should use their stats' tempo).
  - Listen to the new boss voices and the Ukrainian greetings.
- Art lane: B105 pixel touch-ups, B110 bow frames for air / block / hurt.
- Needs a display or export templates: `fb17_*` captures and the exe rebuild (queue 9.8).
