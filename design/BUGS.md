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

### B124 — The sword changes hands between running and attacking
- **Where:** `SampleProject/Sprites/Player/Weapons/sword/` (`Run/1–7` against `Attack1–3`, `Heavy`, and the other folders); `Player.tscn` → library `sword`.
- **Expected:** the same hand in every sword frame. The sword README says "held in the near hand"; keep that, unless the majority of frames is the other way.
- **Got:** in Sapega's playtest the attack frames hold the sword in one hand ("in the right hand") and the run frames in the other ("in the left"). Qwen-Image-Edit did not keep the hand from frame to frame.
- **Fix:** check every sword folder (`CombatIdle`, `Run`, `Air`, `Attack1–3`, `Heavy`, `Block`, `Hurt`) and regenerate the frames on the wrong hand with `comfy_sprite.py hero_weapon_sword` (name the hand in the prompt), then run `weapon_key_fixups.py`. This goes in the ComfyUI art batch with B110. Check the other weapons' frames for the same drift.
- **Evidence:** Sapega's two screenshots (the chat, 2026-10-23).
- **Severity:** visual (art).
- **Found:** 2026-10-23, Sapega's playtest.

### B110 — The bow vanishes outside its frames
- **Where:** `SampleProject/Player.tscn` → `AnimationLibrary_bow`; art `Sprites/Player/Weapons/bow/`.
- **Expected:** the hero holds the bow in every pose (D385).
- **Got:** A4 has bow frames only for stance, run, shots, draw and charge; in jump / apex / fall / land, block, hurt and roll the base frames play and the hero holds no bow.
- **Evidence:** `design/shots/hero_blocks_arrow.png`
- **Severity:** visual — an A-batch for the bow (Air 1–3, Block, Hurt, the sword set's list), then add them to the library
- **Found:** 2026-10-22, `cloud/bow`

> **Round 10 (2026-10-23):** **B137** fixed by `cloud/skills-data` — skills scale with Phys. Atk. / Elem. Atk. (D526, `verify_skill_rules` [2]); row removed. **B129, B130, B131, B132** fixed by `cloud/menu-qa` — one hero portrait in the Game Menu (D534), jobs and weapon icons on Status (D532), Equipment's empty frame removed (D531), unexplored map cells not drawn; rows removed. **B136** fixed by `cloud/combat-player` — facing stays locked until the hit is out (D536, `verify_combat_player`); row removed. **B133, B134, B135, B139, B140** fixed by `cloud/combat-enemies` — hazards cannot be parried (D575), committed enemy swings ignore knockback (D576), boss timers pause (D577), noticing needs sight (D578), the dead boss-effect code is gone; rows removed.

> **Round 8 (2026-10-22):** **B116** fixed by `cloud/combat-fixes` — a held or dead hero leaves combat at once (D425); row removed.
> **B118** fixed by `cloud/settings-store` — one settings file per install (D424); row removed.
>
> **2026-10-22, after round 7:** **B117** fixed — not chance: the test flipped the hero near/far every 0.5 s, and with the djinn's 1.0 s rest (D411) the flip always landed on the same side at the pick (26 moves, no fireball). [5] now places the hero for the move still missing (400 px → fireball, 60 → claws, 135 → only the pillar fits); row removed.
>
> **Round 7 (2026-10-22):** **B112** fixed by `cloud/ui-fixes` — the speaker's name is the first row of `Margin/Rows`, hidden on narration (`verify_dialogue_speaker`); row removed.
>
> **2026-10-22, the next session:** **B113** fixed — row removed. Every failure had the same signature: the hero was still
> invulnerable at the test's double hit, after a hitstop in [2b] showed an enemy hit landing past the fixed 1 s wait
> (10 local runs, 5 under full CPU load, all green — the source was not caught). [2b] now takes the enemies out of the
> physics world (`PROCESS_MODE_DISABLED`) and waits until the i-frames really end (a check of its own), then restores them.
>
> **Round 6, combat-stats (2026-10-22):** **B84** (D393) and **B111** (D394) fixed by `cloud/combat-stats` — rows removed.
> Found and fixed by the orchestrator at merge: **B115** a tutorial hint already on screen stayed in the old language after
> a language switch (`TutorialHintDisplay` set its text once; now re-resolves on `NOTIFICATION_TRANSLATION_CHANGED`;
> `verify_locale` [3]).
>
> **Round 6 (2026-10-22):** fixed, rows removed — **B95, B96, B19, B22, B90, B14, B10, B8** (`cloud/ui-bugs`, D396–D402),
> **B91, B92, B93, B94, B107, B108** (`cloud/misc-bugs`, D403–D405), **B105** (`cloud/art-fixes-wire`). Found and fixed on
> `cloud/skill-fx`: **B114** casting any oath active asserted in `SoundHooks` (no `cast_<id>_*` events; each now reuses
> its pose's base cast sounds). B112, B113 added — see [[cloud_reports/ui-bugs]], [[cloud_reports/misc-bugs]],
> [[cloud_reports/skill-fx]], [[cloud_reports/art-fixes-wire]].
>
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



> **Fixed 2026-10-23:**
> - **B119** (`cloud/ui-kit`, D477): confirm modals follow `UI/Modal/Confirm`.
> - **B122** (`cloud/playtest-1` `c6c71df0`): the box was hidden and then cleared, so Godot kept a stale minimum size. `GameDialogueBox` now refits its `offset_top` on every content or visibility change. `verify_dialogue_speaker`.
> - **B123** (`374daa57`): `Cutscene` lands an airborne hero first and holds the lines until he lands. `verify_cutscene` [0].

> **Fixed 2026-10-23:** B126 (`cloud/story-text`, D499): in the LabCells cutscene only Alisia's body moves; the cat stays in cell 3.

> **Fixed 2026-10-23:** B128 (`cloud/combat-feel`, D519): hit areas are measured from the drawn frames, and shapes are local to their scene. B125 (D520): bodies block and slide off, so the boss no longer hangs on the hero.

> **Fixed 2026-10-26 (integrator-14):** **B150** (`cloud/dash-fix`, D713; the branch called it B149): a ground dash off a ledge or a step hovered level instead of falling. `PlayerMover.air_dash`: only a dash started in the air stays level. `verify_dash`.
> **Closed 2026-10-27: B145** (the exe crashed going down from the Canyon, Sapega's playtest 2026-10-23) — not reproduced in round 13 (`cloud/b145`), and Sapega: «то вже давно не вилітає при спуску». Release builds keep flushing logs with call stacks, so a return would leave a trace.

> **Fixed 2026-10-26 (`cloud/ui-critic`, integrated on the PC):**
> - **B151** — The tutorial hint banner overflowed its box (long uk texts hung out) and was drawn over the hero, e.g. the block/parry hint on DesertRoad and the combo lesson in the Village. Critic, round 13: «Текст підказки не влазить, це дивно, і чому він на персонажі». Root: the text was set while the node was hidden, so its minimum size was stale (as in B122), and its fixed place was bottom-centre, where the camera keeps the hero. ✅ fixed in `cloud/ui-critic` 9984499b (D731); `verify_tutorial_hints` [6] written, not run
> - **B152** — The inventory did not show which gear is worn. Enter on a worn item equipped it again and said "… equipped" every time. Critic, round 13: «Не видно в інвентарі, що спорядження споряджене, але коли клацаю, то постійно «споряджено»». ✅ fixed in `cloud/ui-critic` 7e3ebbe5 (D734); `verify_use_item` [5b] written, not run

> **B149** (integrator-14): opening the game menu while RoomPreloader loaded in the background could deadlock. Root cause: `game_menu_state.gd` `preload`ed `game_menu.tscn`, so the menu scene was loaded while that script compiled, with the GDScript cache mutex held. The menu shares `base_menu.tscn`, `bottom_bar.tscn` and `party_status_panel.tscn` with `shop_menu.tscn`, which SceneWarmer pins into the preloader. The main thread waited for the worker's task on that shared scene, and the worker waited for the cache mutex to compile its scripts (gdb + `--verbose`, 2026-10-26). `tutorial_component.gd` → `tutorial_menu.tscn` → `bottom_bar.tscn` had the same pattern. Both now `load()` at open time; the menu scene is kept in a static var after the first open. `verify_menu_after_room_change` (new): [1] no script in the menu tree preloads a scene that shares a scripted scene with the rooms or the warm-up (both directions), [2] the first opening while the shop reloads in the background, [3] 15 room changes with the menu opened at once. The repro (`verify_skill_screen` without its wait) hung about 1 run in 7 before the fix and passed 48/48 after; the skill tests no longer wait for the preloader.

> **Fixed 2026-10-26 (`cloud/camera-transitions`):** **B153** — Sapega's playtest: «камера скаче багато де, передивись переходи між кімнатами». Measured by `verify_camera_transitions` (every edge passage and door both ways, the cutscene ends, new game and loading a save, run/jump/drop from every cell of every room): 13 of 14 doors jumped 35–246 px in one visible frame and slid up to 1 s after the fade-in; a new game and a loaded save jumped 74 / 43 px and slid 0.75 s. Edge passages, the cutscene ends and the rooms themselves were already still. Cause: the door / teleport path never reset `position_smoothing`, and the room's limits were set later, deferred, in `init_room()`. Fix, one place for every change (`Game.load_room()`): the new room's limits right after the swap (`_fit_camera_to_room`), the caller places the hero, then `_lift_fade()` (deferred) snaps the camera (`reset_smoothing` + `force_update_scroll`) before the first lit frame; a new game places the hero in the same frame. D483's ground share and D434's fade unchanged. Report: [[cloud_reports/camera-transitions]].

> **Fixed 2026-10-27 (`cloud/dialogue-triggers`, integrated on the PC):** **B154** — triggers were lost or misfired while a dialogue ran: a monologue let the hero walk on into the next trigger; a trigger changed the state mid-dialogue and its `require_state` was checked against the old state and dropped; in Canyon the new state's dialogue was discarded as «вже програється інший»; fights, combat text and room cutscenes started on top of the talk; E on a door teleported mid-talk. Sapega 2026-10-26: «діалоги блокують тригери». Fix (D737): one gate in `DialogueManager` (`when_story_free` / `when_story_free_inside`) queues triggers until the story dialogue ends; story dialogues hold the hero. `verify_dialogue_triggers`.

> **Fixed 2026-10-27 (`cloud/skills-party`, integrated on the PC; the branch called it B151):** *The party column covers the Skills side panel* (Sapega, playtest 2026-10-26, exported Windows build: «панель скілів закрила панель атрибутів … атрибутів не видно … там наче її закриває паті-панель з Кусакамом»). · **Repro:** game → Esc → Status → Skills. The party column stayed visible (x 1520–1920) over the side panel (x 1085–1533, squeezed left), so the attribute panel behind «Attributes» could not be seen. Opening Skills straight away, or coming from World Map, was fine. · **Cause:** `game_menu._show_only` walks `ContentRoot` in child order, showing one panel and hiding the rest. Skills (shown) hid the column, then StatusScroll (being hidden, and later in the order) showed it again. World Map had worked around the same race with a deferred hide. · **Fix:** the column is set in one place, `game_menu._show_only`, after the switch, from `metadata/hide_party_column = true` on `MetSysMapComponent`, `SkillsComponent` and `StatusScroll` in `game_menu.tscn`. The handlers in `skills_component.gd`, `stats_component.gd` and `metsys_map_component.gd` are removed. · **Tests:** `verify_new_points` [1] checks six tab paths at both window sizes. `verify_status` [4d] checks that nothing covers the attribute rows.

> **Fixed 2026-10-27 (`cloud/boss-fix`, integrated on the PC; the branch called it B154):** **B159** — Sapega's playtest of the round-13 build: «боси не б'ють». In both boss fights, started through the room, the boss never used its weapon. The LabBoss mercenary did slam → drink → slam, and the MayorHall axe-warrior did a charge that stopped short, then slams. Only the floor shockwave hit a hero who stood still, and a hero in the air or out of its radius was never hit. Root cause in `BossLogic.handle_attack_state`: between moves the boss rested at `preferred_range` ± `PREFERRED_BAND` (60 ± 30 px). That is outside its combo `max_range` (72 / 69 px). When ready, `_fits_any` accepted the far-reaching slam/drink, so `pick_move` skipped the combo every time. The charge `max_range` was 600 px, but its line (D522) is `distance` + `melee_reach` ≈ 387 px. Fix: the rest band ends at the reach of the move the boss rests for (`_rest_reach`). When the next pattern move is out of reach, the boss walks in (`_must_close`); only a charge may stand in, because it closes the gap itself. A charge fits only within its line (`_reach`). `verify_boss_hits` (new), `verify_combat_enemies` [10] (Brass «only charge» distance 400 → 360, plus 420 px = no move).
> The same bug was fixed again on its own by `cloud/hard-fights-2` (which called it B154). The PC kept boss-fix's `BossLogic` and took hard-fights-2's `MayorHall._fight()`: the hall-wide ranges, the home after the cutscene and the boss bar at once, as in `LabBoss`.

> **Fixed 2026-10-27 (integration on the PC):**
> - **B157** — loading a save in the middle of a bubble monologue (e.g. Canyon_Intro) kept the old monologue running on its freed bubble: `SCRIPT ERROR: show_line in base 'previously freed'` (`verify_save_load_room`). Cause: after `_on_bubble_gone` sets `_bubble = null`, a freed bubble compares equal to null in Godot, so `_bubble == bubble` stayed true. `DialogueManager._is_current()` also checks `is_instance_valid`.
> - **B158** — after the new LabCells → Laboratory iron door (D747) the camera eased down for 0.45 s after the fade: the arrival point sits ~26 px above the floor and the hero fell into place on screen (`verify_camera_transitions`). `Game._place_on_floor()`: a door, a cutscene teleport and a new game put the hero on the floor under the arrival point (up to 128 px) while the screen is still black. Edge passages keep the hero's own motion.
> - **B160** (`cloud/oath-census` OCB1) — during the census at the City Gate the cellar door's «Enter» prompt (x 1090) showed behind the answer buttons (`design/shots/oath_census/census_serve.png`): E was already ignored during a story dialogue (D737), but the prompt stayed. `InteractableComponent` now shows the prompt only while gameplay input is allowed, rechecked every frame while the hero is in the zone; `verify_interaction` [5] checks it.
> - **B161** — the City's dark foreground (D750, `rooms-look`) used the Canyon boulder (`gen_rock.png`, ×2.2) right in the street: at the ForgeDoor end it hid half the screen and the hero (`design/shots/city_life_a.png` before). The rock is removed from `Maps/City.tscn`; the palm occluder stays, so `verify_living_world` still sees a passing occluder.

> **Open 2026-10-27:** **B162** — in the Lizard Cave the hero runs on air (Sapega: «в печері ми бігаємо наче не по землі, а по повітрю»): the room is one baked backdrop (`LizardCave/gen_back.png` ×1.5, two copies) whose painted floor is uneven and does not meet the flat collision floor, and the room has no floor band (A16 covered only the outdoor rooms). Fix (Sapega: «там є три плани — передній, середній і задній, їх треба порізати»): cut the backdrop into its three planes, each on its own parallax, the front plane's floor on the walk line; the idol shrines stay where they are (M6, [[m6_backdrops]]).

> **Fixed 2026-10-27 (`cloud/enemy-ai`, D775; integrate-28, the branch called them B162–B165):**
> - **B163** — An enemy walking home (RETURN_HOME) ignored the hero. If he stood in its way it pushed against him and never fought again. Found by `verify_combat_enemies` [7] once D775 made enemies walk to where they last saw him. Fix: walking home, it goes back to the chase when it sees him within its detection range (after the chase cooldown).
> - **B164** — `PlayerMover._release_passed`: an enemy freed during a roll through it (a room swap) stayed in the typed `_passing` array. `erase()` of a freed object fails, so the error repeated every physics frame: 368 712 errors in one `verify_masher` run. Fix: freed entries are filtered out first.
> - **B165** — Mid-fight, an enemy past its leash gave up and walked home while the hero stood 80–350 px away. In `verify_masher`, GOOD lost a bandit, a jackal and a tank this way after rolls (Caravan, Lab middle, road's first fight). Fix: the leash ends the chase only when the hero is beyond the enemy's chase range.
> - **B166** — Bosses stood idle up to 1.29 s with the hero inside their combo reach (fixed rest of 1.0–1.3 s, Mayor Hall and Laboratory). Fix: a boss whose hero stands in its combo reach for more than 0.7 s strikes (`BossLogic.REACH_PATIENCE`); the rest varies ×0.7–1.3.

> **From `cloud/decision-audit-2` (D179–D330 audit, integrate-28):**
> - **B167** (fixed by `cloud/journal-hints`, D781) — D181 was not built: the Journal grouped quests by story stage («PROLOGUE») and «Tasks», not by city/location (`journal_component.gd:176-196`). journal-hints now groups the Quests list under one header per location of `locations.json`.
> - **B168** (open) — D459 (amends D304) is not built: in the cells cutscene the prisoner does not burst into flame; `LabCells.gd:134` still plays `collapse` and then fades the djinn in. Needs the sacrifice animation (frames or an FX) before the djinn appears.

### B148 — the comfy_sprite generator mixes facings on the armoured scorpion
- **Where:** comfy_sprite `_pick("big_armoured_scorpion", …)`; `Enemies/scorpion_armoured/sheet.png` (`cloud/big-scorpion`, D704)
- **Expected:** a regenerated sheet faces one way in every row
- **Got:** idle, attack and death are built from the candidate (seed 134, three-quarter), which faces left, while walk and hurt are prompted "to the right". The committed sheet was fixed by mirroring the cells; a re-run of the generator mixes them again. Needs `FLIP` on those rows or a right-facing base. Check the other D692 picks (`jackal_leader`, `archer_heavy`, `vulture_old`) the same way: idle and walk should face the same way.
- **Severity:** minor (tooling)
- **Found:** 2026-10-24, big-scorpion report


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
