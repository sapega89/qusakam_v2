---
type: status
status: reference
tags: [hub, bugs]
---

# Bugs — open defects

Things that are **built but wrong**. Unbuilt systems go to [[BACKLOG]] instead;
vault conventions in [[INDEX]].

Filed by `visual-qa` (see the `ui-screen-pipeline` skill) and by anyone who
finds a defect while doing something else. A bug found and not filed is a bug
found twice.

## What belongs here

A mismatch with Figma, or a broken behaviour, **that nobody needs to decide
about**. Triage every finding three ways before filing:

| Finding | Goes to | Not a bug because |
|---|---|---|
| An approved decision covers it | [[figma_decision_register]] — cite the D-ID | The runtime is intentionally right |
| It needs a product call (a price, a rule, keep-or-cut) | [[questions_for_sapega]] — new Q-ID | Nobody has decided yet |
| The system does not exist at all | [[BACKLOG]] + a plan note | Nothing to fix |
| **A decision approved it and nobody built it** | [[BACKLOG]] → Agreed but never built, **citing the D-ID** | Nothing is wrong; the work was dropped |
| Nothing says it is wrong — you just dislike it | **Parked observations** below, as an **O-ID** | No source to measure it against |
| **None of the above — it is simply wrong** | **here, as a B-ID** | — |

Pre-existing test failures are **not** bugs: check [[test_baseline]] first, its
three known issues (exit 139, headless display-server errors, missing item icons) are baseline noise.

## Row format

Append; never renumber. Delete the row in the commit that fixes it — git keeps
the history, this note keeps only what is open.

```markdown
### B<n> — <one-line symptom>
- **Where:** `path/to/scene.tscn` → `%NodePath` (and the script, if behaviour)
- **Screen:** [[<screen>_mapping]] · Figma `<frame> <node-id>`
- **Expected:** <value + its source: Figma variable, UITokens constant, or frame measurement>
- **Got:** <value as measured>
- **Evidence:** `design/shots/<file>.png`, or the `RESULT:` line that failed
- **Severity:** blocker | visual | cosmetic
- **Found:** <date>, <slice or task>
```

**Expected** must name its source. "Should be darker" is not a bug report;
"`UITokens.SURFACE` = `#111118` @56%, node has `#1A1A1E` @100%" is.

## Severity

| | Meaning |
|---|---|
| **blocker** | Broken behaviour, a new error in the log, or a screen that cannot be opened. Fix before the slice ships. |
| **visual** | A real mismatch with Figma: wrong token, wrong size, wrong state styling, wrong layout. |
| **cosmetic** | Visible only at a non-authoring resolution or in an edge state. |

---

## Open

> Seeded with one real finding as a format example. This list is maintained by
> whoever runs QA, not compiled in advance.

### B84 — Crit, evasion and attack speed do nothing in a fight
- **Where:** `GameManager.calculate_critical_chance` / `calculate_dodge_chance` / `calculate_attack_speed`; `PlayerCombat.hit_damage()`, `Player.mitigated_damage()`, swing times.
- **Expected:** Agility points (D335) and base dexterity change crit, evasion and attack speed in combat.
- **Got:** only the Status and Equipment screens read them; no crit roll, no evasion roll, speed ignored (D336).
- **Fix:** crit roll in `hit_damage` (×1.5) and evasion in `mitigated_damage` behind a seedable RNG so `verify_combat_flow` / `verify_souls_combat` stay exact; speed into `swing_time`. **Decided:** Sapega 2026-10-22, all three (D393).
- **Severity:** blocker for Agility being worth a point
- **Found:** 2026-10-21, `cloud/skills-screen`

### B90 — A pressed (selected) `ListRow` shows no focus ring
- **Where:** `SampleProject/UI/build_game_ui_theme.gd` `ListRow` focus (D329).
- **Expected:** the cursor is visible on the selected row too.
- **Got:** the accent ring sits on the accent fill; the `focus` stylebox cannot know the pressed state. Matters where a selected row and the cursor differ (inventory / journal lists).
- **Severity:** cosmetic
- **Found:** 2026-10-21, `cloud/settings-cleanup`

### B91 — The hero shows `Idle`, not the raise-the-item pose, while a chest opens
- **Where:** `SampleProject/Scripts/Gameplay/Chest.gd:17` (`HERO_POSE`), `Player.tscn` (no `Raise` animation).
- **Expected:** Kusakam raises the found item overhead (BACKLOG 33, art A1 `Sprites/Player/Raise/1–3.png`).
- **Got:** the held pose is `Idle` (D339). The Raise frames have now landed on `feature/backlog` (`b56cbe6a`) but are not wired.
- **Fix:** add an animation `Raise` (Raise/1–3) to the player's `AnimatedSprite2D` frames and set `Chest.HERO_POSE := &"Raise"`; `verify_chests` follows the constant.
- **Severity:** visual
- **Found:** 2026-10-21, `cloud/chests`

### B92 — A `Cutscene` that never reaches `end()` outlives its game
- **Where:** `SampleProject/Scripts/Systems/Cutscenes/Cutscene.gd` `_init` (connects `_hold_later` to `DialogueManager.dialogue_started`, hides `Game/UI` + `Game/UICanvas`), `Cutscene.gd:54` `hold()`.
- **Expected:** quitting to the main menu or loading a save mid-cutscene leaves nothing behind (D308).
- **Got:** the autoload connection survives; the next game's first dialogue calls `hold()` on the freed hero → **segfault**. A second cutscene in the same game sees the HUD already hidden and never shows it again.
- **Fix:** the cutscene ends itself on `player.tree_exiting` (disconnect, `Engine.time_scale = 1`, restore the HUD).
- **Severity:** blocker (crash, edge path)
- **Found:** 2026-10-21, `cloud/lab-9-5`

### B93 — `Game.gd` fails to compile when a `--script` verify names a class that references `Game`
- **Where:** `SampleProject/Scripts/Game.gd:390` `teleport_to_room()` — `var old_room_instance := MetSys.get_current_room_instance()`.
- **Expected:** a verify can name any `class_name` (e.g. `RoomDoor`) and compile.
- **Got:** when `Game.gd` is compiled before the autoloads exist, the type cannot be inferred: Parse Error, "Failed to compile depended scripts", the test crashes. `verify_village_house` works around it by typing the doors as `Area2D`.
- **Fix:** an explicit type (`var old_room_instance: Node = …`).
- **Severity:** tests only
- **Found:** 2026-10-21, `cloud/buildings`

### B94 — `verify_audio` "focusing a button (pad navigation) ticks on SFX" is flaky
- **Where:** `SampleProject/UI/verify_audio.gd:276`.
- **Expected:** the check passes whenever the focus tick plays.
- **Got:** fails about one run in three on Linux 4.6.2, on an untouched `feature/backlog` too: it samples `ButtonFocusedAudioStreamPlayer.playing` one `process_frame` after `grab_focus()`; the player is not always playing yet (or already done) on that frame.
- **Fix:** wait until `playing` with a short deadline, or count the `play()` calls.
- **Severity:** tests only (flaky)
- **Found:** 2026-10-21, `cloud/buildings` (also seen by `cloud/localization-1`)

### B95 — Keyboard Enter after a mouse click in the Game Menu does not press the focused button
- **Where:** `SampleProject/Scripts/UI/focus_router.gd` `_unhandled_input` (Game Menu).
- **Expected:** Enter presses the button the mouse click focused (e.g. the Settings → Language cell).
- **Got:** a click focuses a content button but the router stays in `"Tabs"` mode (D348 keeps that on purpose so Esc after a click closes the menu); the Enter press reaches the router → `focus_content()` moves focus to the first content control and the release lands nowhere. Pad A is not affected. `verify_locale` [2] steps around it (`focus_router.focus_content()` first).
- **Fix:** in `"Tabs"` mode, let `ui_accept` through when the focus owner is already inside the content.
- **Severity:** minor (mixed mouse + keyboard)
- **Found:** 2026-10-22, `cloud/localization-1`

### B96 — Settings → Controls lists action ids as names
- **Where:** maaacks input list (Settings → Controls), `String.capitalize()` of the action id.
- **Expected:** readable action names (`readable_action_names`).
- **Got:** `Dq Accept`, `Save Delete`, `Menu Prev Tab`, `Skills Unpick`… Ukrainian translations exist now (`uk.po`); the English stays clumsy.
- **Severity:** cosmetic
- **Found:** 2026-10-22, `cloud/localization-1`

### B105 — Weapon palette swap misses a few pixels
- **Where:** `SampleProject/Sprites/Player/Weapons/{halberd,dual,sword}/…` frames; `Scripts/Tools/weapon_key_fixups.py`; `Shaders/weapon_palette.gdshader`.
- **Expected:** the whole weapon recolours and the body never does (D361).
- **Got:** the halberd's butt spike stays iron in `Air/1`, `Block/1`, `CombatIdle` (below the torso box); the dual dagger stays iron in `Heavy/1` and `Run/7` (pressed to the chest) and is drawn in `#FCF3D5` (not a key colour) in `Air/3`, `Run/2`, `Run/4`, so it stays pale in every palette; a few arm pixels in `sword/Attack2/2` and `Attack3/2` tint with the palette.
- **Evidence:** `design/shots/weapon_palettes.png`
- **Severity:** cosmetic — repaint those pixels on the laptop (key on the weapon, off-key on the body), or per-frame masks
- **Found:** 2026-10-22, `cloud/weapons-all` (its B111)

### B107 — Ether says "Restores 30 MP."
- **Where:** `SampleProject/Resources/Data/items.json` → Ether `description`.
- **Expected:** SP — the game's resource (the Ukrainian text already says SP).
- **Got:** "Restores 30 MP."
- **Severity:** cosmetic (content)
- **Found:** 2026-10-22, `cloud/localization-2`

### B108 — "Lesser Potion" heals more than "Potion"
- **Where:** `SampleProject/Resources/Data/items.json` → `potion` (heal 50), "Lesser Potion" (heal 75).
- **Expected:** a lesser potion heals less than the plain one (D357: Мале / Середнє / Велике зілля).
- **Got:** Lesser 75 > plain 50.
- **Severity:** visual (data)
- **Found:** 2026-10-22, `cloud/localization-2`

### B110 — The bow vanishes outside its frames
- **Where:** `SampleProject/Player.tscn` → `AnimationLibrary_bow`; art `Sprites/Player/Weapons/bow/`.
- **Expected:** the hero holds the bow in every pose (D385).
- **Got:** A4 has bow frames only for stance, run, shots, draw and charge; in jump / apex / fall / land, block, hurt and roll the base frames play and the hero holds no bow.
- **Evidence:** `design/shots/hero_blocks_arrow.png`
- **Severity:** visual — an A-batch for the bow (Air 1–3, Block, Hurt, the sword set's list), then add them to the library
- **Found:** 2026-10-22, `cloud/bow`

### B111 — Enemy attack tempo ignores `EnemyStats.attack_cooldown`
- **Where:** `SampleProject/Scripts/Gameplay/…/EnemyLogic.gd` `handle_attack_state` (its own `attack_cooldown` 1.5 s; `initialize()` never copies the stats value).
- **Expected:** each enemy swings at its stats' tempo (the fast 1.0 s…).
- **Got:** every melee enemy swings every 1.5 s; only the archer reads `enemy.attack_cooldown` (2.2 s).
- **Severity:** visual (balance) — fixing it re-tunes every fight (4b). **Decided:** Sapega 2026-10-22, tempo from the stats (D394)
- **Found:** 2026-10-22, `cloud/bow`

> **2026-10-22:** **B106** closed as designed by D395 (the slash arc shows the reach) — row removed.
>
> **Fixed log (2026-10-22, `cloud/code-fixes`):** B42 (Game.tscn's dangling ObjectiveHUD; `verify_scripts_compile`
> now fails on any unused ext_resource) and B4 (the `or true` check in `verify_misc_modal`) — rows removed,
> `git log --grep B42` / `--grep B4`.
>
> **Fixed log (2026-10-21 cleanup):** B16, B38, B53, B54, B55, B74–B80 were fixed and their rows removed — find each
> with `git log --grep "B<n>"` (B38 checked on `design/shots/flow/04_tab_status.png`: the lit tab spans x 0–295 like the
> rest). The Figma deviations **B1, B27, B28, B30, B35, B37, B39, B56** were **accepted as built** by Sapega on 2026-10-21
> → [[figma_decision_register]] **D317**; their rows are removed too.
>
> **Fixed log (integration-1, 2026-10-21):** **B82** fixed by `cloud/b82-b10` (D320, `verify_save_load_room` [1]/[2]) —
> row removed. **B85** (tools without the exec bit), **B87** (combat training could kill the bandit) and **B88**
> (`weapon_prev` had no key) were found and fixed on their branches — see [[cloud_reports/integration-1]].
>
> **integration-2, 2026-10-21:** no B-rows fixed; B91 (`cloud/chests`) and B92 (`cloud/lab-9-5`) added — see [[cloud_reports/integration-2]].
>
> **integration-3, 2026-10-22:** **B83** fixed for the corridors by `cloud/lab-9-6` (D306, `verify_laboratory` [5]; the
> boss hall half was D307) — row removed. **B89** fixed by `cloud/weapon-gamepad` (`options_component._rebuild_list`
> re-grabs the same row, `verify_gamepad_parity` [1]) — row removed. Found and fixed on `cloud/weapon-gamepad` (its
> B100–B104, renumbered): **B97** Game Menu, pad: B in content closed the menu, A on another tab did not switch
> (`focus_router.gd`); **B98** the World Map's `_input` ate every arrow / D-pad press, a typed-array error on focus
> (`metsys_map_component`, `game_menu.gd`); **B99** main menu: pad B did nothing, Settings opened without focus, D-pad →
> from a sidebar tab went to Restore, segment rows dropped focus (`MainMenu.gd`, `options_component.gd`); **B100** Forge
> categories unreachable without a mouse, dialogue choices and the Demo end without focus; **B101** bottom-bar / hotbar
> badges fixed to one device. B93–B96 added — see [[cloud_reports/integration-3]].
>
> **integration-4, 2026-10-22:** **B86** fixed by `cloud/localization-2` (D356: ASCII speaker ids, English names, Ukrainian
> in `uk.po`; `verify_locale` [5] walks every line through the dialogue window in both languages) — row removed.
> Found and fixed on their branches: **B102** world interaction prompts showed the keyboard badge to a pad player after a
> room change (`interaction_prompt.gd` reads `InputGlyphs.using_gamepad`, `verify_interaction` [3]; `cloud/lab-9-8`);
> **B103** SCRIPT ERROR in the top HUD on every scene change from the game (`combat_hud_top.gd` connects `process_frame`
> only in the tree; `cloud/lab-9-8`); **B104** holding block with a weapon that has frames brought the overlay weapon back
> after the 0.1 s pose (`WeaponView._drawn_in_frame` reads `assigned_animation`, `verify_weapon_animations`;
> `cloud/weapons-all`, its B110). B105–B108 and `cloud/bow`'s B110, B111 added — see [[cloud_reports/integration-4]].


## Playtest intake — 2026-09-29 (Sapega)

Reported in one pass, terse by design. Each row is **reported, not reproduced**
unless it says otherwise. Do not fix from these rows alone — they are a queue,
not a diagnosis. Promote a row to a full B-ID when it has been reproduced.

Before treating any row as a bug, ask whether it was ever built. In play,
"agreed but never implemented" is indistinguishable from "broken" — and several
of these turned out to be exactly that. Check [[figma_decision_register]] for a
D-ID first; if one exists, the row belongs in [[BACKLOG]] → *Agreed but never
built*, not here.

| ID | Report | Status after a first look |
|---|---|---|
| P1 | Attack has no animation and deals no damage; assumed to follow from having no weapon | ⚠️ **cause is not the weapon.** `Player.tscn` already has the `Attack` animation (`:139`), all four `PlayerCombat` exports wired (`:181–184`), `DamageApplier.base_damage = 15`. `perform_attack()` also falls back to a 0.2 s damage window when no animation exists (`PlayerCombat.gd:75`). Needs reproduction — the real cause is elsewhere. |
| P2 | No weapon in the game | Unverified. Check whether the player is meant to start equipped and whether any map grants a weapon — related to **Q2 / D88** (no production map gives an inventory item). |
| P3 | Dialogues | Too terse to act on. Needs one sentence: which NPC, what happens instead. Note the dialogue presentation layer is unbuilt — [[BACKLOG]], D110. |
| P4 | "Дід" NPC never appears; should be a placeholder cube | ✅ **done 2026-10-12.** The story logic and trigger already existed (`Village.gd` `OLD_MAN_*`, `Village.tscn` → `StateChangeTrigger_OldManOutside` at (1582, 344)); only the visual was missing. Added `OldMan` `Sprite2D` under that trigger, frame 0 of `SampleProject/Assets/Characters/old_man_idle.png` (copied from the gitignored `assets/bosses/1 Old_man/` on 2026-10-14 so Village loads from a fresh clone), ×2, facing left. Static — no idle animation. |
| P5 | No merchant and no blacksmith; should be placeholder cubes somewhere on the desert | ✅ **not a bug — known unbuilt work.** Both scenes exist and are tested but are placed **only in `Maps/City.tscn`**. This is **D81** in [[BACKLOG]] → "Merchant / Blacksmith on production maps". Desert placement was never done. |

---

### B19 — "Attack" row puts gamepad bindings in the keyboard columns, with two naming schemes
- **Where:** Settings → Controls, Attack row (y≈598).
- **Evidence:** `settings_controls_1920.png` — Primary = `Button #0`,
  Secondary = `Button A`, Tertiary = empty.
- **Expected:** the pattern every other row follows — keyboard in Primary/Secondary,
  gamepad in Tertiary (`W`/`Up`/`Dpad Up`, `Space`/`W`/`Left Stick Up`) — and one
  naming scheme for gamepad buttons.
- **Got:** gamepad in both keyboard columns, empty gamepad column, and the same
  input class named two different ways in a single row.
- **Note:** this is binding data and labels, not maaacks widget styling, so **D48
  does not cover it**.
- **Severity:** visual

### B22 — Volume steppers have no control chrome
- **Where:** Settings → Audio, the `-` / `+` beside each slider (x≈1076, x≈1444).
- **Evidence:** `settings_audio_1920.png` — bare glyphs directly on the background.
- **Expected:** a 1px bordered box, matching every other interactive control on
  these screens (segmented control, Reset, both footer buttons).
- **Got:** unframed characters with no visible hit target.
- **Severity:** cosmetic

### B14 — Game Over text is unreadable against the stone-wall art
- **Where:** `Scenes/UI/game_over_screen.tscn`.
- **Evidence:** `design/shots/game_over_1920.png`.
- **"Khalahas Heroes"** (`:117`) — small dark-red type on the dark wall, effectively
  invisible at 1920×1080. *(The name itself is correct — `MainMenu.tscn:77` and the
  `TitleKhalahas` / `SIZE_TITLE_KHALAHAS` tokens confirm it is the game's title.)*
- **"Game Over"** — dark red over a high-contrast stone-and-iron-door photo; the
  letterforms collide with the door bars and lose their edges.
- **Expected:** a scrim or a darker backdrop behind the type, as every other
  screen uses (`DimOverlay`), so text reads at a glance.
- **Related:** this is the same missing-scrim family as **B8** — the background
  art is intended, the darkening under the text is not there.
- **Not filed:** the missing third button (Load Game) — that is **D92**, decided
  2026-09-29, after this screenshot.
- **Severity:** visual
- **Found:** 2026-09-29, screenshot review.

### B10 — A stray orange `!` glyph inside the dialogue box
- **Where:** `Scenes/UI/dialogue_box.tscn` (`DQDialogueBox`), in gameplay.
- **Evidence:** `design/shots/combat_hud_1920.png` (2026-09-29).
- **Fixed parts:** the empty portrait frame (2026-10-20; now real portraits, D321) and the Auto/Skip buttons (D319,
  `cloud/b82-b10`, `verify_npc_recall` [5]).
- **Still open:** an orange `!` floats inside the box next to the portrait frame, matching nothing in the design. Not
  re-checked since 2026-09-29 (no window in the cloud runs) — capture the box and close the row if it is gone.
- **Severity:** visual
- **Found:** 2026-09-29, screenshot review.

### B8 — Menu surfaces are transparent; the parchment map bleeds through (systemic)
- **Where:** not one screen. Confirmed on three so far:
  - **Skills tab** — no surface at all, "No skills available yet." sits on the map.
  - **Shop** — parchment visible through the top of the wares panel and the
    whole left sidebar (`design/shots/shop_buy_1920.png`).
  - **Save / Load** — all four slot cards are see-through, the map runs straight
    through the slot text (`design/shots/save_load_save_mode_1920.png`).
  - **The overwrite confirmation modal** — worst instance found. Panel interior
    measures `(12,11,15)`→`(15,14,18)` and the map's "Shifting Sands" label crosses
    it at y≈522, **directly behind the body text**. Verified arithmetically:
    `0.56×(17,17,24) + 0.44×(12,10,10)` = `(14.8,13.9,17.8)` = the measured value,
    i.e. `SURFACE` `#111118` @56% is doing exactly what it says. A destructive
    confirmation is the worst surface in the app to be see-through.
  - **Inventory empty state** — "No items in this category." sits dead centre over
    the darkest part of the bleed-through in dim grey; the least legible text found
    in any shot.
- **Originally filed as:** `SkillsPanel` in the Game Menu.
- **Expected:** the menu's opaque surface (`UITokens.SURFACE`, `#111118` @56%
  over the backdrop) behind the panel content.
- **Got:** on the Skills tab only `CentralPanel`, `PanelManager` and
  `SkillsPanel` are visible — no surface panel, no `RightPanel`/`PartyStatusPanel`.
  The illustrated parchment world map fills the whole content area and the
  "No skills available yet." text sits directly on it, barely legible.
- **Evidence:** `design/shots/flow/05_tab_skills.png`; panel-visibility dump in
  the same run.
- **Note:** the parchment backdrop is **intended** — `menu_shell.gd:63` documents
  it as *"у Figma — ілюстрована мапа під затемненням"*. What is missing is the
  darkening: `menu_shell.tscn` has a `DimOverlay`, and the legacy
  `vertical_menu.tscn` the Game Menu actually uses has **none** (`grep` → 0).
- **Root cause, shared with B7:** the Game Menu never migrated to `UIMenuShell`.
  The shell carries both the `DimOverlay` this tab lacks and the `ButtonGroup`
  B7 needs. One migration closes both.
- **Severity:** visual
- **Found:** 2026-09-29, **reproduced visually.**

---

## Parked observations

Things that look wrong to whoever was testing, but that **no source says are
wrong** — not in Figma, not in a token, not in a mapping, not in a decision.

Parked on purpose. **Do not act on an O-ID.** It does not block a PASS, does not
become a task, and is not a Q-ID — nobody is being asked anything yet. It sits
here until Sapega either turns it into a decision (→ D-ID), a question (→ Q-ID)
or deletes it.

The point: a tester's unsourced opinion is how a screen gets quietly redesigned
by whoever looked at it last. Writing it down costs one line and keeps the
option open without acting on it.

```markdown
### O<n> — <what you noticed>
- **Where:** <screen / node>
- **Why it bothered you:** one sentence
- **No source:** which of Figma / tokens / mapping / decisions you checked
- **Found:** <date>, <who or which run>
```

### O16 — Minimap is hidden at game start and overlaps the HUD once shown
In `shots`-style runs (`capture_tutorial_shots.gd`, 2026-10-12) the minimap is not on
screen after boot; it appears only after the full map (M) is opened and closed, because
the map script sets `minimap.visible = not visible`. When it shows, it sits under the
coin / settings icons of `combat_hud_top` in the top-right corner. The tutorial topic
"The Map" describes the minimap, so this matters to players. Parked — needs a call on
where the minimap lives next to the HUD.

### O15 — Map window toggles tracking on raw `KEY_D`, which is also `move_right`
`Game.tscn` (MapWindow inline script, `_input`): `elif event.keycode == KEY_D: show_delta = not show_delta`
runs on every D press, map open or not, so walking right flips the tracking arrow.
Found 2026-10-12 while writing the tutorial ([[tutorial_mapping]]). Parked — no
visible effect unless the map is open; fix by an InputMap action or a `visible` guard.

### O14 — World Map tab does not read as a map (Sapega, 2026-10-12)
Sapega: "карта в меню гри поки мені не ясна, але то не критично". Parked, not a
defect — no expectation was stated. What the tab shows today
(`shots/flow/06_tab_world map.png`, a fresh game with nothing explored):
- the whole viewport is a grid of **unexplored MetSys cells** drawn over the
  illustrated parchment (`menu_map_background.jpg`); the two layers are unrelated —
  the art's place names are not MetSys rooms ([[world_map_mapping]]: legend and the
  13 named markers have **no backing data**);
- `EXPLORED 000%`;
- the player marker sits at the viewport's top-left corner (x≈318, y≈50), not in a cell.
Before acting, ask Sapega what the tab is for — a MetSys room map, a world/region
overview like the Figma `94:609` art, or both — and check the marker position in a
real save with explored rooms; it may be centring on an empty start.

### O12–O13 — from the scene inventory audit, 2026-09-29
Both are "code where a scene would be conventional". See [[scene_inventory]].
- **O12 — save points are 10 hand-built `Area2D` copies and there is no
  `SavePoint.tscn`.** `Scripts/SavePoint.gd` is attached inline to an `Area2D` +
  `CollisionShape2D` + `Label` triple in each of the 8 live maps
  (`Maps/Canyon.tscn:101`, `Maps/City.tscn:22`, `Maps/DesertRoad.tscn` ×2,
  `Maps/Laboratory.tscn` ×2, `Maps/CityGates.tscn:32`, …) plus
  `Maps/Legacy/StartingRoom.tscn`. **No source requires a scene:** D75/D74 specify
  the prompt and the flow, not the object's packaging. Figma has `prop/save-pillar`
  art, which nothing uses — that is art, not a structural requirement. It bothered
  the reviewer because 10 copies means 10 places to change when the pillar art or
  the prompt label lands.
- **O13 — `NpcActionMenu` is the only `UI/Components/` member with a `.gd` and no
  `.tscn`.** `Scripts/Gameplay/NPCs/NpcBase.gd:22` does `NpcActionMenu.new()`
  against `UI/Components/npc_action_menu.gd:2`; the other ten components in that
  folder are all `.gd` + `.tscn` pairs. `CLAUDE.md` asks for shared reusable
  components and a common Theme, which the code-built menu satisfies — nothing says
  a component must be a scene. Parked, not a defect. (B40, its 2px inter-row rule, fixed
  2026-10-16 by `NPC_MENU_GAP = -BORDER_WIDTH`, #63.)

### O9–O11 — from the NPC / interaction pass, 2026-09-29
- **O9 — pickup modal is ~440×280 design px for ~90px of content**, leaving 84px
  above and 86px below. D100 approves *using* the shared modal family but nothing
  specifies its size. Resolved with B26/B36 (#71, #74): the shared modal now sizes to its content.
- **O10 — Journal's two content columns are ~39px apart** (list ends x=939, detail
  rule starts x=979) — off the 2/4/8/12/16/24/32/48 scale in both directions. No
  Figma measurement exists for this frame.
- **O11 — every sidebar tab sits flush at x=0** inside a 320px sidebar, putting all
  24px of slack on the right. Reads as unpadded against the window edge; no token
  covers a sidebar left inset.

> **Coverage limit, not a finding:** the NPC menu and prompt fixtures render on flat
> `#1b1916` / `#111118`, so prompt legibility **over real world art** is untested.

### O4–O8 — from the save/load pass, 2026-09-29
All measured, none with a source that makes them wrong:
- **O4 — splash prompt colour.** "PRESS ANY BUTTON" measures `#a4a4a5` = white @64%
  over `#050508`, not `TEXT_SECONDARY #a1a1a1`. Almost certainly a mid-pulse frame
  of a fade — its flanking ornaments are pure `#ffffff`.
- **O5 — no text hierarchy on the slot card.** Timestamp, "Kael", playtime, "No save
  data available" and the "SAVE DATA MANAGEMENT" eyebrow all resolve to `#ffffff`.
  `TEXT_SECONDARY` appears only in the bottom hint bar. Needs the frame to call.
- **O6 — date format.** `9/23/2026 00:05` — unpadded US M/D/YYYY beside a 24h clock.
  No format token or decision exists.
- **O7 — modal button voice and default focus.** "Yes"/"No" while the hint bar
  speaks verbs ("Confirm", "Return", "Delete"); and the **destructive** `Yes` is the
  default-focused button. No project source for either.
- **O8 — splash copyright weight.** ~11px legal microcopy renders essentially white
  (brightest `#eeeeee`).

### O1 — Party portraits are flat colour squares, and the fourth is empty
- **Where:** party status panel, all menu screens
- **Why it bothered the reviewer:** three members show flat blue / red / purple
  squares, the fourth ("Три темніх жреца") an empty black one — so even the
  placeholders are inconsistent with each other
- **No source:** placeholder portrait art is a known gap; nothing specifies what
  a missing portrait should look like
- **Found:** 2026-09-29, screenshot review (agent pass)

### O2 — Party names are Cyrillic while the UI language is English
- **Where:** party status panel, visible on every menu screen; the Game tab shows
  English selected
- **Why it bothered the reviewer:** mixed scripts in one frame
- **No source:** character names are content data. `LocalizationManager` ships two
  languages (D67), but nothing says proper nouns are translated
- **Found:** 2026-09-29, screenshot review (agent pass)

### O3 — Controls table labels look a step smaller than Audio/Game row labels
- **Where:** Settings → Controls vs Audio/Game row labels
- **Why it bothered the reviewer:** "Move Up" reads smaller than "Master Volume"
- **No source:** font size cannot be measured off a PNG with confidence, and
  **D48** may cover the widget anyway. Resolve by reading the scene, not the image
- **Found:** 2026-09-29, screenshot review (agent pass)

> **Resolved during triage, not parked:** the bright green HP bar was queried as
> off-palette. It is `UITokens.HP_FILL = #2ecc71` — a real token. Not a finding.

---

## Not in this note

- **Technical debt** — known, accepted, not a regression → [[UI_IMPLEMENTATION_STATUS]]
  § Technical debt (139 `Engine.has_singleton` sites, one of which makes
  `EventBus.player_health_changed` dead; `Player._initialize_health_bar()`
  infinite `call_deferred` recursion; `ModalLayer` has no public close method).
- **Pre-existing test failures** → [[test_baseline]].
- **Figma frames the designer must update** → [[UI_IMPLEMENTATION_STATUS]].
  A stale frame is the designer's task, not a code bug.
