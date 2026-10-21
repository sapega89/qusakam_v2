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

> **Fixed log (2026-10-21 cleanup):** B16, B38, B53, B54, B55, B74–B80 were fixed and their rows removed — find each
> with `git log --grep "B<n>"` (B38 checked on `design/shots/flow/04_tab_status.png`: the lit tab spans x 0–295 like the
> rest). The Figma deviations **B1, B27, B28, B30, B35, B37, B39, B56** were **accepted as built** by Sapega on 2026-10-21
> → [[figma_decision_register]] **D317**; their rows are removed too.

### B82 — A loaded save puts the hero at the scene's default position, not where he saved
- **Where:** `SampleProject/Scripts/Game.gd:200` (`save_manager.retrieve_game(self)`) and `:239` (comment: "позиція вже
  відновлена через save_manager.retrieve_game"); `SampleProject/Scripts/Managers/Gameplay/PlayerStateManager.gd:54`
  (`get_player_position()`).
- **Expected:** loading a save brings the hero back to the place he saved (the save point he used).
- **Got (from the code, not reproduced in play):** the position is written — `Game._save_full_game_data_to_save_system()`
  (`Game.gd:600`) → `PlayerDataModule.gd:32` `player_position` — and read back into `player_state` (`PlayerDataModule.gd:103-108`),
  but nothing applies it: `get_player_position()` has no callers, `Game` does not override `_set_save_data()`, so
  `retrieve_game()` restores MetSys map data only. The saved room loads; the hero keeps his default position from `Game.tscn`.
  A new game is fine (`_position_player_at_start()`, `Game.gd:400`).
- **Severity:** blocker (a load can drop the hero anywhere in the room, inside a wall or a fight)
- **Found:** 2026-10-21, documentation cleanup (docs/CLAUDE.md "Player spawning" claim checked against the code)

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

### B42 — `ObjectiveHUD.tscn` is loaded by `Game.tscn` and never added to the tree
- **Where:** `SampleProject/Game.tscn:15` —
  `[ext_resource type="PackedScene" uid="uid://objectivehud001" path="res://SampleProject/Scenes/UI/ObjectiveHUD.tscn" id="10_objective"]`
- **Screen:** [[figma_coverage]] §F — ObjectiveHUD is superseded by Quest Info Panel
  `434:6580`, already implemented as `UI/Components/combat_hud_top.tscn`.
- **Expected:** every declared `ext_resource` is used by a node in the same scene.
- **Got:** `grep -c 'ExtResource("10_objective")' SampleProject/Game.tscn` = **0**.
  The scene is parsed and loaded on every `Game.tscn` load and never instantiated.
- **Evidence:** swept all 121 `.tscn` for this pattern; `10_objective` is the only
  dangling `PackedScene` `ext_resource` in the project. It is also why a plain
  path-grep reports `ObjectiveHUD.tscn` as used when it is not.
- **Severity:** cosmetic — wasted load, no visible effect. Delete the line, and the
  scene with it unless Q34's answer keeps it.
- **Found:** 2026-09-29, scene inventory audit


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

### B10 — Dialogue box shows an empty portrait frame and undesigned Auto/Skip buttons
- **Where:** DialogueQuest `dialogue_box.tscn` (`DQDialogueBox`), in gameplay.
- **Evidence:** `design/shots/combat_hud_1920.png`.
- **Empty portrait frame:** a blank brown square sits on the right of the box.
  **Q26's applied default was "hide the empty frame"** — it was never applied.
  D112 later replaced portraits with full-body art, so this frame has no future
  either way.
  **Fixed 2026-10-20:** `GameDialogueBox.set_portrait_image()` shows the frame only when the speaker has a
  portrait (none does today); the placeholder `MC.png` is gone from `Scenes/UI/dialogue_box.tscn`.
  `verify_npc_recall` [5]. Auto/Skip and the `!` glyph are still open.
  **Checked 2026-10-21 (not fixed, row kept):** Skip is hidden (`Resources/Dialogue/dialogue_player_settings.tres`
  `skip_enabled = false`), but **Auto still shows** (`autoplay_enabled = true`, the addon calls `get_auto_button().show()`);
  the `!` glyph was not re-checked (no fresh screenshot).
- **Auto / Skip buttons:** present top-left of the box. [[dialogue_audit]] §1
  records that Figma's `npc-dialog-simple 36:6` has **no Auto/Skip buttons**.
- **Stray glyph:** an orange `!` floats inside the box next to the portrait
  frame, matching nothing in the design.
- **Not duplicated here:** the box being entirely off-theme (no accent border,
  wrong font, magenta speaker name instead of accent gold) is the known unbuilt
  presentation layer — [[BACKLOG]], D110.
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

### B4 — `verify_misc_modal.gd` asserts navigation by grepping source; one check cannot fail
- **Where:** `SampleProject/UI/verify_misc_modal.gd:104, 111–120`
- **Expected:** a test named "Tutorial destination still resolves" presses the
  button and asserts where the player ends up.
- **Got:** three of the four Misc destinations are never pressed.
  - `:111–114` opens `game_menu.gd` with `FileAccess` and asserts
    `menu_src.find("TutorialMenuScene") != -1` — a **string search of the source
    file** — plus `ResourceLoader.exists(tutorial_path)`, a file-on-disk check.
  - `:118` Exit asserts `ResourceLoader.exists("res://SampleProject/MainMenu.tscn")`.
  - `:104` `ck(current_scene == null or true, "no scene change")` — `X or true`
    is **always true**. The assertion is incapable of failing.
- **Consequence:** [[BUGS]] **B2** (Tutorial unloads the game into a dead-end
  stub) sits directly under a check called "tutorial route still wired" that
  passes because the *string* is present. The suite cannot catch it, and never
  could. Only `[5] Settings destination` actually drives the UI.
- **Evidence:** run 2026-09-29, `RESULT: ALL PASS` (40 checks) on
  `Godot_v4.6.2-stable_win64_console.exe`. Passing is the problem.
- **Severity:** blocker — a green suite is the reason these shipped.
- **Found:** 2026-09-29, **confirmed by running the script.**
- **Note:** the test otherwise drives the real path (`ServiceLocator` →
  `UIManager.open_game_menu()` → real modal layer), so its Settings result is
  trustworthy. Fixing this means pressing the remaining three buttons and
  asserting the destination, not adding more file-existence checks.

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
