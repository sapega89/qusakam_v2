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

### B133 — Parrying a boss hazard staggers the boss from any distance
- **Where:** `BossFireball.gd:30`, `BossPillar.gd:26`, `BossLogic.gd:103` → `PlayerCombat.gd:465-471`, `DefaultEnemy.gd:624-625`. The hazard names the boss as the damage source.
- **Got:** a parried fireball staggered the djinn 450 px away (0.93 s left, 0 damage). A floor pillar can be blocked just by facing the boss. **Expected:** hazards cannot be parried or blocked; only melee strikes and arrows can.
- **Severity:** gameplay. **Found:** 2026-10-23, [[combat_critique_2026-10-23]] (confirmed by probe).

### B134 — Knockback cancels any wind-up, even an armoured or boss swing
- **Where:** `EnemyLogic.gd:370-374` (no armour or boss check). A combo's last swing (40 px), every mace hit (60 px), and Astrit's and the guard's assists all do it.
- **Got:** a level-1 bare-hand combo cancelled the Brass slam wind-up at 0.65 s, with no shockwave, while the boss's poise was not broken. **Expected:** once a tell is shown, the swing completes unless poise breaks; bosses ignore knockback.
- **Severity:** gameplay. **Found:** 2026-10-23, combat critique (probe).

### B135 — Boss timers keep running while the game is paused
- **Where:** `BossLogic.gd:50`, `:90`, `:118`; `BossPillar.gd:21`, `:27`. `create_timer` is called without stopping on pause.
- **Got:** the hero lost 38 HP during 1.2 s of pause. **Severity:** gameplay. **Found:** 2026-10-23, combat critique (probe).

### B136 — Turning mid-swing turns the body and weapon, but not the hitbox
- **Where:** `PlayerCombat.gd:494-497`, `:296-297`; `WeaponView.gd:119`. **Severity:** gameplay. **Found:** 2026-10-23, combat critique (by reading).

### B137 — Skills ignore Phys. Atk., so a level-20 ultimate hits for less than a light swing
- **Where:** `SkillManager.gd:131-132`, `SkillCombatExecutor.gd:17-34`. Flat 20–50 against a light hit of 45–150; this contradicts D491.
- **Expected:** skill damage scales with the hero's attack. **Severity:** gameplay. **Found:** 2026-10-23, combat critique.

### B138 — The saved hero HP is ignored: every load gives full HP
- **Where:** `PlayerDataModule.gd:31`; `PlayerStateManager.gd:33` (no callers); `Player.gd:70-71`. **Severity:** gameplay / save. **Found:** 2026-10-23, combat critique.

### B139 — Enemies notice the hero through floors and walls
- **Where:** `default_enemy.tscn` (a 300-px circle); `EnemyLogic.gd:222-227` (distance checked along X only); `PlayerCombat.gd:274-278`.
- **Got:** an enemy on another floor chases, swings at the ceiling and keeps the hero "in combat", so the fight music plays.
- **Expected:** an enemy notices the hero only on its own floor or in line of sight.
- **Severity:** gameplay. **Found:** 2026-10-23, combat critique.

### B140 — Dead code: `VFXHooks.play_boss_attack_effect` and its helpers, and `EnemyLogic`'s HP-based retreat
- **Where:** `VFXHooks.gd:202-303`; `EnemyLogic.gd:459-525` (the retreat can only run at 1 HP or less). It is removed per D131. **Severity:** code. **Found:** 2026-10-23, combat critique.

### B129 — The hero's portrait is a purple square in the Game Menu
- **Where:** Status header, Equipment "Current character", and the party card in the right column (Inventory, Equipment, Misc, Map).
- **Expected:** Kusakam's portrait, the one the dialogue box uses (`Sprites/Player/portrait.tres`), framed as in Figma `58:719`.
- **Got:** a flat purple square. **Evidence:** `design/shots/menu_qa/cmp_status.png`, `game_equipment.png`.
- **Severity:** visual. **Found:** 2026-10-23, menu QA.

### B130 — Status shows "—" for the primary job, weapon types and stat icons
- **Where:** Status (`58:719`).
- **Expected:**
  - Primary Job shows the hero's class, Holy Warrior.
  - Secondary Job shows the oath once one is sworn.
  - Weapon Types shows the icons of the usable weapons.
  - Each stat row has its icon (Figma's crossed-swords glyph).
- **Got:** "—" in the job and weapon boxes, and empty squares instead of the stat icons. Path Action and Talent are "—" too: hide them while the hero has none.
- **Severity:** visual / data. **Found:** 2026-10-23, menu QA.

### B131 — Equipment shows an empty frame above Attributes
- **Where:** Equipment, the middle column.
- **Expected:** that frame shows the hero (his sprite in the current gear) or it is not there.
- **Got:** a large empty bordered box. **Evidence:** `design/shots/menu_qa/game_equipment.png`.
- **Severity:** visual. **Found:** 2026-10-23, menu QA.

### B132 — The World Map is covered by a dense cell grid
- **Where:** Game Menu → World Map (`metsys_map_component`).
- **Expected:** the parchment map reads clearly (Figma `94:609`). D487 replaces it with per-region maps later.
- **Got:** unexplored MetSys cells are drawn as a fine square pattern over the whole parchment, so the map is hard to read and the two explored cells are tiny. **Evidence:** `design/shots/menu_qa/cmp_map.png`.
- **Severity:** visual. **Found:** 2026-10-23, menu QA.

### B127 — Nobody is laid on the operating table
- **Where:** the same cutscene (D304: "Alisia is led to the operating table and injected by the alchemist").
- **Expected:** Alisia lies on the operating table while the alchemist injects her, then gets up and is led back.
- **Got:** she only walks up to the table; nobody is ever on it (Sapega: «на стіл ніхто нікого не поклав»).
- **Needs art:** Alisia lying on her back (a frame or two, plus getting up). It goes in the ComfyUI art batch (comfy-sprite, from her existing sheet). Then the cutscene places her on the table top.
- **Severity:** story.
- **Found:** 2026-10-23, Sapega's playtest.

### B124 — The sword changes hands between running and attacking
- **Where:** `SampleProject/Sprites/Player/Weapons/sword/` (`Run/1–7` against `Attack1–3`, `Heavy`, and the other folders); `Player.tscn` → library `sword`.
- **Expected:** the same hand in every sword frame. The sword README says "held in the near hand"; keep that, unless the majority of frames is the other way.
- **Got:** in Sapega's playtest the attack frames hold the sword in one hand ("in the right hand") and the run frames in the other ("in the left"). Qwen-Image-Edit did not keep the hand from frame to frame.
- **Fix:** check every sword folder (`CombatIdle`, `Run`, `Air`, `Attack1–3`, `Heavy`, `Block`, `Hurt`) and regenerate the frames on the wrong hand with `comfy_sprite.py hero_weapon_sword` (name the hand in the prompt), then run `weapon_key_fixups.py`. This goes in the ComfyUI art batch with B110. Check the other weapons' frames for the same drift.
- **Evidence:** Sapega's two screenshots (the chat, 2026-10-23).
- **Severity:** visual (art).
- **Found:** 2026-10-23, Sapega's playtest.

### B120 — `craft_potion` still charges the price from before D403
- **Where:** `SampleProject/Resources/Data/crafting_recipes.json:164-180` (`craft_potion`: Herb ×2 + Stone ×1 → Potion ×2, `gold_cost` 4).
- **Expected:** the gold cost is 10 % of the result's buy price (D97's placeholder rule, kept by D179 / D416; the formula is in [[crafting_mapping]] "Data"). Potion ×2 at buy 40 gives **8**.
- **Got:** 4, which was right for the old Potion at buy 20. D403 swapped Potion and Lesser Potion but did not update this recipe, so 2 Potions now cost 4 gold. That is cheaper than the chain step (2 Lesser → 1 Potion), which also costs 4.
- **Evidence:** of the 18 recipes compared with the `items.json` buy prices, 17 follow the rule and only `craft_potion` does not. `verify_crafting` only checks `gold_cost > 0`.
- **Severity:** data. The fix is `gold_cost` 8, applying the D416 formula. Pointing the recipe at `potion_lesser` instead would change the recipe, which D403 did not ask for.
- **Found:** 2026-10-23, [[decision_audit]] Run 3 (D97).

### B121 — `verify_misc_modal` still has an `or true` check after B4 was closed
- **Where:** `SampleProject/UI/verify_misc_modal.gd:102`: `ck(row.focus_neighbor_bottom != NodePath() or true, "%s in the focus chain" % row.name)`.
- **Expected:** every `ck()` can fail (B4's rule; the fixed log says B4 removed the `or true` check in `verify_misc_modal`).
- **Got:** the B4 fix (`dc9a6e32`) replaced only the "no scene change" check. The "in the focus chain" check still always passes.
- **Evidence:** `grep -n "or true" SampleProject/UI/verify_*.gd` finds only this line.
- **Severity:** cosmetic, test only.
- **Found:** 2026-10-23, [[decision_audit]] Run 2.

### B110 — The bow vanishes outside its frames
- **Where:** `SampleProject/Player.tscn` → `AnimationLibrary_bow`; art `Sprites/Player/Weapons/bow/`.
- **Expected:** the hero holds the bow in every pose (D385).
- **Got:** A4 has bow frames only for stance, run, shots, draw and charge; in jump / apex / fall / land, block, hurt and roll the base frames play and the hero holds no bow.
- **Evidence:** `design/shots/hero_blocks_arrow.png`
- **Severity:** visual — an A-batch for the bow (Air 1–3, Block, Hurt, the sword set's list), then add them to the library
- **Found:** 2026-10-22, `cloud/bow`

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
