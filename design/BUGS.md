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

### B128 — Hit areas do not match what is drawn: enemies hit from too far, the hero cannot reach them
- **Where:** `Scripts/Gameplay/DefaultEnemy.gd:114`: `hitbox_collision.shape.size.x = attack_range`, so the enemy's damage area is as wide as its whole attack range (melee and tank 100 px, fast 80 px plus a 60-px lunge; `Resources/Enemies/enemy_stats_*.tres`). The scene's own `hitbox` shape is 28 × 28. The shape is a shared sub-resource, so writing to it may resize every enemy's. The enemy's body / hurt area (`default_enemy.tscn` `CollisionShape2D`) and the hero's swing area (`PlayerCombat` / `WeaponView`) are not matched to their sprites either.
- **Expected:** what you see is what hits.
  - An enemy's attack reaches only as far as its visible strike: the claw, blade or lunge.
  - The hero's swing hits anything the drawn slash (`SlashTrail`) overlaps.
  - An enemy can be hit wherever its sprite is opaque at body height.
  - `attack_range` stays the distance at which an enemy *starts* its attack, not the size of the damage area.
- **Got:** Sapega, playtest 2026-10-23: «я стою далеко від мобів, але вони мене дістають — не очевидно» and «так само я не можу до них дотягнутись, хоча здається, що мав би».
- **Fix:**
  - Per kind, size the attack hitbox from the strike frames, the hurtbox from the body's opaque bounds, and the hero's hitbox from the slash trail.
  - Make each shape local to its scene, so nothing is shared.
  - Add a debug draw toggle for tuning.
  - Add `verify_hit_areas.gd`: per enemy kind and per hero weapon, the shapes stay within a few px of the sprites' opaque bounds, and the hero at the drawn reach does hit.
- **Severity:** gameplay (combat feel).
- **Found:** 2026-10-23, Sapega's playtest.

### B126 — In the Laboratory cells cutscene the cat walks out with Alisia
- **Where:** the `LabCells` cutscene (D304; `verify_lab_cells.gd`), cell 3, where Alisia and the white cat creatures sit.
- **Expected:** only Alisia is led out of cell 3 to the table and back. The cat stays in the cell.
- **Got:** the cat came out together with Alisia. Most likely it is a child of her node, or it shares the node the cutscene moves.
- **Evidence:** Sapega's screenshot (the chat, 2026-10-23).
- **Severity:** visual / story.
- **Found:** 2026-10-23, Sapega's playtest.

### B127 — Nobody is laid on the operating table
- **Where:** the same cutscene (D304: "Alisia is led to the operating table and injected by the alchemist").
- **Expected:** Alisia lies on the operating table while the alchemist injects her, then gets up and is led back.
- **Got:** she only walks up to the table; nobody is ever on it (Sapega: «на стіл ніхто нікого не поклав»).
- **Needs art:** Alisia lying on her back (a frame or two, plus getting up). It goes in the ComfyUI art batch (comfy-sprite, from her existing sheet). Then the cutscene places her on the table top.
- **Severity:** story.
- **Found:** 2026-10-23, Sapega's playtest.

### B125 — The boss ends up hanging above Kusakam
- **Where:** the Mayor Hall boss (the brass golem with the cage, `bestiary.json`), `Scripts/Gameplay/Characters/Bosses/BossLogic.gd` and the boss body; player / enemy collision (D197, now D443).
- **Expected:** the boss stays on the floor and never stands or hangs on the hero. Whoever lands on the other slides off (D443).
- **Got:** in Sapega's playtest the boss hung above Kusakam.
- **Fix where all callers route:** the shared body rule from D443, not a boss-only patch. Check it with the boss's jumps and lunges.
- **Evidence:** Sapega's report (the chat, 2026-10-23).
- **Severity:** gameplay.
- **Found:** 2026-10-23, Sapega's playtest.

### B124 — The sword changes hands between running and attacking
- **Where:** `SampleProject/Sprites/Player/Weapons/sword/` (`Run/1–7` against `Attack1–3`, `Heavy`, and the other folders); `Player.tscn` → library `sword`.
- **Expected:** the same hand in every sword frame. The sword README says "held in the near hand"; keep that, unless the majority of frames is the other way.
- **Got:** in Sapega's playtest the attack frames hold the sword in one hand ("in the right hand") and the run frames in the other ("in the left"). Qwen-Image-Edit did not keep the hand from frame to frame.
- **Fix:** check every sword folder (`CombatIdle`, `Run`, `Air`, `Attack1–3`, `Heavy`, `Block`, `Hurt`) and regenerate the frames on the wrong hand with `comfy_sprite.py hero_weapon_sword` (name the hand in the prompt), then run `weapon_key_fixups.py`. This goes in the ComfyUI art batch with B110. Check the other weapons' frames for the same drift.
- **Evidence:** Sapega's two screenshots (the chat, 2026-10-23).
- **Severity:** visual (art).
- **Found:** 2026-10-23, Sapega's playtest.

### B122 — The speaker's portrait sticks out below the dialogue box
- **Where:** `SampleProject/Scenes/UI/dialogue_box.tscn` (`DialogueBox` 938 × 178 from its offsets; `Margin/Rows`: `NameMargin` row (B112), then `RowMiddle` with the 160-px `PortraitBackground`); `Scripts/UI/GameDialogueBox.gd` (`set_name_text` / `set_portrait_image` toggle the rows).
- **Expected:** the box always holds the name row, the text and the portrait (it grows upward, `grow_vertical` = begin).
- **Got:** in Sapega's playtest (2026-10-23), during Grandfather's line "Hold still. This power was in our family long before you." (`OldMan_Healing.dqd`, Village, hotbar visible, not a cutscene), the box stayed 178 px tall and the portrait hung about 40 px below its bottom edge. In the Canyon exit cutscene the same box grew to 245 px correctly. An isolated repro (`logs/repro_dialogue_portrait.gd`, which sets name + portrait + text with the box shown or hidden) also grows correctly. So the cause is in the real flow: the order in which `DialogueManager` / `DQDialoguePlayer` show the box and set the name and portrait, or something that sets the box size or offsets. Reproduce it through the real Village old-man flow first.
- **Evidence:** Sapega's screenshots (the chat, 2026-10-23): seen twice, both **outside cutscenes, through `DialogueManager.start_dialogue`** with the hotbar on screen (Grandfather in the Village; Kusakam's "Enemies on the road!" on the Desert Road, `DesertRoad.gd:_play_dialogue`). **Update:** it also happened in a cutscene: the LabCells cutscene, at the Fire djinn's line "Freedom! A hundred years in this pitiful body!" (Sapega's screenshot). So it is not tied to the start_dialogue path. The Canyon exit cutscene sized correctly, so look for what differs per line: speaker change, portrait size, first line after a narrator line. B112's name row (`42d1002b`) made the content taller than the 178-px offsets.
- **Severity:** visual.
- **Found:** 2026-10-23, Sapega's playtest.

### B123 — A cutscene starts while Kusakam is still in the air
- **Where:** the shared cutscene start (`Cutscene`, D308) and its triggers; seen at the Canyon exit (`Canyon_ExitCutscene`).
- **Expected:** a cutscene starts only once the hero stands on the ground. If he is mid-jump or falling when the trigger fires, he lands first, with gravity still applied and input off, and then the cutscene begins.
- **Got:** the cutscene froze him in mid-air above the ledge, and he stayed hanging there through "So this is the edge of the canyon".
- **Fix where all callers route:** the shared cutscene start, not each trigger.
- **Severity:** visual / feel.
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

### B119 — Confirm modals do not match the kit's UI/Modal/Confirm
- **Where:** `SampleProject/Scenes/UI/modal_dialog.tscn` (`Panel/VBox/Buttons` is an `HBoxContainer`), `SampleProject/Scripts/UI/modal_templates.gd`, theme types `ModalPanel` / `ModalTitle`.
- **Expected:** Figma `UI/Modal/Confirm` `258:5332` (also `shop-buy-confirm` `153:1760`):
  - padding 40 × 28, gap 16;
  - title in Cormorant Garamond Regular 22, then a **1 px accent rule 300 px wide**, then the body in Regular 14;
  - **buttons stacked vertically** (gap 12, a 300-px column), each a `UI/HexButton` 260 × 36 with pointed ends;
  - selected button: accent fill (`SampleProject/Assets/UI/Icons/hex_button_selected.svg`) with the `›` pointer 16 px at x 49 (the glyph is `Assets/UI/Icons/chevron.svg`); other button: a 2-px `#3A3A42` outline (`hex_button.svg`);
  - labels in Cormorant Garamond SemiBold 18, **uppercase**, tracking 2 px;
  - the panel stays opaque (D195), and the D329 ring is drawn over the selected look (white on accent).
- **Got:** no rule under the title; small rectangular Yes / No buttons side by side, in mixed case.
- **Evidence:** `design/shots/shop_buy_confirm_qty3_1920.png` against `258:5332`.
- **Severity:** visual. Every confirm modal shares the scene: buy, craft, enchant, overwrite save, delete slot, quit, item pickup.
- **Found:** 2026-10-23, #43 check. Sapega chose the kit for all modals.

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
