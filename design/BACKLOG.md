---
type: status
status: reference
tags: [hub, backlog]
---

# Backlog — systems that do not exist yet

The index of unbuilt work. **Look here first** when picking up the project, and
add a row whenever a session finds a system that is missing — see the
`plan-missing-system` skill for the procedure.

Consolidated from existing notes only; no new decisions are made here. Sources:
[[runtime_ui_completion_plan]] · [[figma_coverage]] ·
[[UI_IMPLEMENTATION_STATUS]] · [[figma_decision_register]] ·
[[questions_for_sapega]] · [[dialogue_audit]] · [[scene_inventory]].
Last reconciled 2026-09-29.

Vault conventions: [[INDEX]].

**Order of work:** [[backlog_roadmap]] — phase 1 is "playable to the end".

## States

| State | Meaning | What to do with it |
|---|---|---|
| ⛔ **BLOCKED** | Plan written, work stopped on a decision or data nobody has given | Do not start. Chase the named Q-ID. |
| 📋 **PLANNED** | Plan written, nothing blocks it | Ready to run. Pick it up as-is. |
| 🔍 **NEEDS PLAN** | Known to be missing, no plan written | Write `design/<system>_plan.md` first, then link it here. |

Rule: **no invented values.** A system needing a number nobody decided — a
price, a stat, a label — is BLOCKED with a Q-ID, not built on a guess.

---

> **2026-09-29 — Q1–Q28 all answered** (D88–D115, [[figma_decision_register]] §8).
> Nothing is blocked any more. Two items were unblocked, one system came back
> into scope, and seven decisions reverse code that is already shipped and green.

## ⛔ Blocked

### Character animations — [[character_animation_plan]]
- **Exists:** player Walk/Run frames; Idle/Jump/Fall/Attack show one borrowed frame; one generic
  enemy sheet; static NPCs; many unused packs in `assets/`.
- **Decided:** D138 — Kusakam keeps the 64×64 art, the missing states are drawn in that style;
  D139 — enemies and NPCs stay as they are for now.
- **Waits on:** the frames (an artist), not a decision.
- **Resume:** slice 1 of [[character_animation_plan]] when the frames exist.

### Laboratory boss — [[lab_boss_plan]]
- **Exists:** `BOSS_FIGHT` state and its win flag; the fight is four ordinary enemies (tank, melee,
  fast, tank) in two waves. No boss enemy, stats or art.
- **Waits on:** Q52 — who the boss is, how the fight goes, its numbers and art.
- **Resume:** answer Q52, then slice 1 of [[lab_boss_plan]].

### Cutscenes — [[cutscene_plan]]
- **Exists:** the Village is a staged sequence (D140 — fade, bandit talk, the old man); the Canyon descent is
  fully staged (D256); the abduction and Mayor's Hall are still dialogues.
- **Decided:** D176 — Canyon abduction, Canyon descent, Mayor's Hall → Lab, fully staged;
  screenplay [[cutscene_script]] (draft lines for Sapega).
- **Waits on:** actor art ([[character_animation_plan]]); Q51 (Mayor's Hall story) for scene 3.
- **Resume:** slice 1 of [[cutscene_plan]] — tween helpers next to `ScreenFade` (D177) + Canyon abduction on placeholder art.

---

## 📋 Planned — ready to run

### ✅ DONE 2026-10-20 — Painted terrain in the outdoor rooms — D248, D249
All six outdoor rooms walk on painted ground (Canyon earlier; Village, DesertRoad, CityGates, City, LaboratoryOutside
now); the checker tile is gone, CityGates' ceiling included; the Canyon's gorge back wall repainted from the same rock.
Left: MayorHall (interior, `hall_body` / `hall_floor` materials not generated yet).

### Sapega's play feedback 2026-10-20 — run one agent at a time, in this order
1. ~~**Bugs and look**~~ — **done 2026-10-20.** No platform had lost its art — `verify_map_geometry` [6] now proves
   every top of a hidden collision layer is painted in every room; the Canyon gorge's back wall (`canyon_depths.png`)
   was the same light, contrasty sandstone as its ledges, so they did not read (B75): it is now a far, low-contrast
   wall sunk in violet shadow, dark at the bottom, with a ragged far rim under the bridge (`paint_terrain.depths()`).
   Fall faced the direction of the last jump, not of the hero (B74). Dialogue box opaque (`ModalPanel`) and in our
   own `Scenes/UI/dialogue_box.tscn` (D110); lines type at 24 letters/s and accept is ignored until the line is
   shown, NPC recall lines too; the DialogueQuest Skip toggle is off (it fast-forwarded text). Speed and Skip are
   agent calls — Sapega to confirm.
2. ~~**Canyon descent cutscene**~~ — **done 2026-10-20** (D254, D256): at the plateau edge the bridge collapses,
   `Canyon_ExitCutscene` plays, Kusakam climbs down behind a generated foreground boulder, the camera floats up to a
   blue sky above the room, fade, road. No fall, no damage; flags as before. Bridge art generated (`gen_bridge`).
   [[cutscene_plan]] → "Built". Open: HUD stays on screen in cutscenes; no skip control.
3. ~~**Healing rework**~~ — **done 2026-10-20** (D252, D261): Healing Palm is learned at level 2 (a sticky hint on the
   level-up, Esc → Skills → Enter; it lands on the first free hotbar slot); the Village old man heals Kusakam and goes
   straight to his decision and gift, no heal request; potions drop from 1 kill in 10 (first-kill 5 potions stay).
   B76 fixed on the way: Enter on a Skills row learned nothing.
4. ~~**Combat, souls-lite**~~ — **done 2026-10-20** ([[souls_combat_plan]], D264–D270): a 3-swing light combo
   (4 with two weapons), a heavy attack (R-click / R / pad B) with a breakable wind-up, block and parry (Ctrl / middle
   mouse / pad LB), enemy poise and staggers, enemy combos, the hero staggered by every wounding enemy hit — the tank
   and combo finishers "freeze" him 0.6 s (D253's freeze is this mechanic; no lock bug reproduced), a double dash
   also in the air, walking in towns out of combat (D251), the halberd two-handed and sword + dagger dual-wield (D250),
   skill casts interruptible (D259 hook). Open: "harder tuning" beyond combos/staggers (enemy HP/damage untouched);
   enemies have no stagger frames (tint only); no stamina by design (D264).
5. **NPCs do something** — idle activities (blacksmith hammers, merchant counts coins, elder…), generated frames.
6. **Boss** — generate the Laboratory boss ([[lab_boss_plan]]).
7. **Foreground parallax** — below.
8. ~~**A reason to climb the Canyon mountain**~~ — **done 2026-10-20** (D257): the abduction waits for the summit of the
   Pride Rock — a generated meditation stone (`gen_shrine`), Kusakam sits (generated `Meditate` frames), the camera drifts
   left, then the raid over black and the ridge lines; flags as before. [[cutscene_plan]] → "Built". Open: no skip, HUD stays.
9. **Inventory actions** (Game Menu): equip a weapon/armour/other item from the inventory; using an ingredient opens a
   modal "this item cannot be used"; using a potion heals the hero right away.
10. **Party shows only who is in it**: with one character the Game Menu shows only Kusakam until the party grows.
11. **Equipment slot picker**: clicking an equipment slot opens a window with the inventory items that fit that slot.
12. **Every hint is a tutorial window**: each hint opens the tutorial window (nothing is missed), and the topic lands in
    the Tutorial list; a Settings option turns these windows off.
13. **Journal sections**: choose between Quests and Characters (people we have met); plus a Bestiary.
14. **Blacksmith and merchant come out to meet you** (Sapega 2026-10-20): bug — the blacksmith is drawn in front of
    the hero (z-order). Each gets a building (generated art) on the road; when the hero arrives they walk out of it and a
    cutscene plays (gameplay paused): they talk to Kusakam and give a task (quests via the story-and-dialogue skill).
15. ~~**Weapons sheathed out of combat; an attack animation per weapon**~~ — **done 2026-10-20** (D268): the weapon
    is out of sight out of combat (2026-10-21 fix, Sapega: not on the back) and is drawn when a fight starts or on a swing; sword/axe arcs, mace overhead smash,
    dagger stabs, halberd thrusts, dual-wield alternating hands, heavy overhead; new hero frames Hurt, Heavy ×2, Block
    (generated from his artist frame).
16. **MayorHall cutscene and the "unbeatable" boss** (Sapega 2026-10-20): Kusakam enters the Mayor Hall, where Астрит,
    Уризен and Алісия stand in a queue and Kusakam joins it (Q65 answered: Алісия too); a wall
    bursts and a boss climbs out. The boss is meant to be unbeatable, but can be beaten: either way Kusakam ends up
    transported to the Laboratory — a win only gives more XP and items from the boss. This is the boss of item 6.
17. **The Laboratory story, rewritten** (Sapega 2026-10-20) — replaces the current three-storey companion talks:
    - Kusakam and his future team are on **one floor**: a room with an operating table and cells; everyone is behind bars.
    - Cutscene: Алісия is led to the operating table and injected; then an unknown prisoner who looks like a bandit is
      led in — he shouts and an evil boss bursts out of him, **a fire djinn**, and flees; explosions, an earthquake,
      Kusakam passes out. (His shout: Sapega said «аллах акбар»; default until confirmed — an incantation in an invented
      language, see Q in questions_for_sapega.)
    - Kusakam wakes: all cells open, all belongings in place, every character still in their cell. When he steps out,
      a cutscene: everyone gets acquainted; **Малік** offers to lead them to his "humble place" where he will give
      everyone gold, and asks to be led out of the Laboratory. The quest cannot be refused. Малік appears later as an NPC;
      for now it is only Kusakam and the companions.
    - All assists are unlocked at once; fight the Laboratory mobs; the boss waits at the end and the Laboratory cannot
      be left until it is dead.
    - Boss talk: it asks who they are; Kusakam says he is ready to bargain; the boss says "give me the cloak"; Kusakam
      cannot — it is his grandfather's cloak. Fight for the cloak: boss wins → it takes the cloak, game over; boss loses →
      Kusakam: «I don't know whether you would have given the cloak away, but I wouldn't.» The Laboratory gates open,
      we walk out, **the end** of the demo.
18. ~~**City Gates: open sky, real gates, a bandit raid**~~ **Done 2026-10-20 (D258).** (Sapega 2026-10-20): remove the tile ceiling over CityGates — it
    is the desert, the sky must be overhead (collision change: the ceiling band goes); add gate art — beautiful city
    gates with guards (generated); a cutscene when Kusakam approaches: bandits attack the gates (then the existing guard
    assist fight, D209).
19. **A living world** (Sapega 2026-10-20): idle animations on decor (banners and cloth sway, grass and palm fronds
    move, lamps and crystals flicker, dust drifts…) and clouds that drift on their own and with parallax as the hero
    moves (Canyon HighClouds/gen_clouds and the other rooms' sky planes).
20. ~~**Smoother hero animations; lighter jump dust**~~ — **done 2026-10-20 (D262):** Idle breathes over 4 keys, a jump plays Jump → Apex → Fall → Land, landing dust is 6 small wisps for 0.3 s. Was (Sapega 2026-10-20): the hero's animations must be smoother —
    redo them (more in-betweens, generated from his artist frames with comfy-sprite, D239); the jump/land dust lasts far
    too long and is too dense — shorter, thinner, in the Ender Lilies spirit.
21. ~~**Every skill has its own animation**~~ — **done 2026-10-21 (D271, D272):** each active skill is cast with a wind-up pose + charge effect and a release pose + effect (Healing Palm palm glow 0.6 s, Fire Strike flaming blade → fire wave 0.35 s, Electric Strike sky bolt → lightning arc 0.5 s); a staggering hit in the wind-up interrupts (no effect, SP and cooldown spent); hotbar slots on the pad RT/R3/L3/Back. Was (Sapega 2026-10-20): each skill (Healing Palm, Fire / Electric Strike, … —
    Resources/Data/skills.json) gets a hero pose/cast animation and its effect, not just a number change.
    A cast can be **interrupted** (a hit during the wind-up staggers the hero): the skill's effect does not happen, but
    its cooldown starts anyway and the SP is spent (D259). Goes with the stagger system of item 4.
22. ~~**Three skill trees: Light, Dark, Neutral**~~ — **done 2026-10-21 (D279–D285, [[skill_trees_plan]]):** Holy Warrior trunk + Paladin / Dark Knight / Warden of Balance trees (8 skills each to level 20, later tiers outlined), one point per level, level cap 99, the oath sworn in the City before Sister Ilvane (priest), Morrow (witch) or Kesh (sand dervish) — permanent; respec at any of them for 10 coins × level; Skills screen tabs, double click learns (B77). Left: subclass (40) and prestige (70), own cast art for the new actives, the NPCs drawn over the hero (as item 14's blacksmith). Was (Sapega 2026-10-20 «у кусакама має бути три гілки навичок — темні,
    світлі і нейтральні; все це можна взяти з навичок чемпіона або паладина з D&D і з Pathfinder, тільки переробити під
    нашу гру, як це роблять в інших іграх»). Today: 5 skills in Resources/Data/skills.json, no branches
    ([[skills_system_plan]], [[skills_combat_plan]], [[skills_ui_mapping]]). Source material: PF2e Champion (ORC
    licence — holy causes ≈ Light, unholy ≈ Dark) and the D&D 5e SRD Paladin (CC BY 4.0) — Lay on Hands, Smites, Auras,
    Channel Divinity, Oaths; Neutral = martial/defensive (Shield Block, Toughness, stances). Rename and re-shape for a
    real-time platformer (cooldowns + SP, D259 interrupts), no copied text. First a plan
    (`design/skill_trees_plan.md`): 3 trees × tiers, unlock by level/points, how Healing Palm (D252) and the existing
    5 skills slot in; then data + Skills UI; animations per item 21.
    Sapega's frame (2026-10-20, D260): level cap 99, one skill point per level (99 total), every skill gated by a level
    threshold; class path like PF2e archetypes with epic names — **Holy Warrior** (trunk) → oath: **Paladin** (light) /
    **Dark Knight** (dark) / **Warden of Balance** (neutral) → subclass at 40 → prestige at 70 (names in D260). The oath
    is sworn **in the City** before a thematic NPC: a **priest** (Paladin), a **witch** (Dark Knight), a **sand
    dervish** (Warden) — new NPCs, generated art.
23. **DesertRoad grows; the Laboratory grows and splits into screens** (Sapega 2026-10-20 «збільшити локації» → «не
    треба додавати нові назви, дорога має стати більшою» → «місто, брама і село залишаються, каньйон теж, а ось
    лабораторію треба буде збільшити і розбити на екрани»): City, CityGates, Village and Canyon stay as they are. Before
    the City only **DesertRoad** grows (longer, more MetSys cells, more fights, side ledges with pickups) and the XP curve
    (XPManager) is tuned so level 5 lands at the City. The **Laboratory** becomes bigger and is split into several
    screens (separate MetSys rooms) — fits the rewritten Laboratory story (item 17): the cells floor, the corridors of
    mobs, the boss room. Plan first: `design/world_expansion_plan.md`; new parts get the painted terrain/backdrops.
24. **Every action works on a gamepad** (Sapega 2026-10-20 «кожна дія дублюється на джойстику — це важливо, будуть
    тестувати на джойстику»): every keyboard/mouse action — movement, combat, skills, calling companions (F), menus and
    every Game Menu screen, dialogue, tutorial windows, the Skills learn (B77), inventory actions, map — has a gamepad
    binding in the InputMap and is reachable with focus navigation only. Hints name the gamepad button when a pad is in
    use. A `verify_gamepad_parity.gd` checks every InputMap action has a joypad event and drives the main menus with
    `InputEventJoypadButton`. Standing rule for every queue item from now on: a new action ships with its pad binding.
25. ~~**After the meditation: a white speech cloud, Kusakam stands still**~~ — **done 2026-10-20** (D263) (Sapega 2026-10-20 «діалог після медитації має
    бути в білому облачці мабуть, і Кусакам вже має встати з диску, але не має рухатись»): the talk that follows the
    summit meditation (item 8, D257) is shown in a white speech cloud over the speaker instead of the dialogue box; by
    then Kusakam has already risen from the stone disc (stand-up from `Meditate`) — he is standing by the time the camera
    has come back to the Canyon after its drift (Sapega «він має стояти, коли вже камера повернулась у каньйон») — and he
    cannot move or act until the talk ends. Check whether a speech-bubble presentation exists (D110 dialogue layer) before building one.
26. ~~**The world is voiced and sounds alive**~~ — **done 2026-10-21** ([[audio_plan]], D274–D278): Ambience and Voice buses into SFX (the three sliders keep working), every combat event and skill cast voiced, room ambience loops, footsteps by surface, doors, pickups, UI ticks, babble per character while text types (box and cloud talk), English greetings (Kokoro-82M, Apache 2.0) only when the hero starts the talk, enemy / hero / boss / companion voices; left: boss cutscene lines (16/17), rumble (24). Was: (Sapega 2026-10-20 «все підряд озвучувати не треба, але треба весь світ
    озвучити і всі різні штуки типу намагання вдарити ворога або героя, і босів треба озвучувати» … «всіх»): no full
    voice acting of every line. Needed: **world sound** — ambience per room (desert wind, canyon echo, town crowd, lab
    hum), footsteps per surface, jump/land, ladder, doors, pickups, UI; **combat** — every swing (hit and miss), impact,
    block/parry clang, dash, hero and enemy grunts / hurt / death, skill casts; **bosses voiced** — roars, attack shouts,
    a few short lines in their cutscenes; **characters** — every speaking character ("всіх") gets a voice: dialogue
    "babble" blips in their own timbre while text types (Undertale-style), plus short **voiced phrases**: each character's own spoken greeting when the hero talks to
    them (Sapega «так, але короткі фрази — озвучені привітання персонажа») — but **not** on the first meeting when it is
    a meeting cutscene (Sapega «але якщо це перша зустріч і є катсцена зустрічі, то немає озвучення»), battle cries, companion calls. Today: `AudioManager.gd`, 21 audio files. Plan first: `design/audio_plan.md` — sources by licence
    (CC0 packs such as Kenney / OpenGameArt first; local generators only with a licence that allows release — TTS:
    Kokoro-82M Apache 2.0 for English barks, Piper voices per-voice licence for Ukrainian; never XTTS-v2 / F5-TTS
    non-commercial weights; check Stable Audio Open's licence before using it), buses and mixing, the event→sound map,
    Steam AI-content disclosure. Gamepad rumble on hits goes with item 24.
    **Plan: [[audio_plan]]** (D274–D278), built; the listening checklist for Sapega is in the plan.

### Foreground parallax in every outdoor room
Sapega 2026-10-20: «ще в план треба додати паралакс попереду». Only Village (`gen_front`) and Laboratory have a
near/foreground plane; add one to Canyon, DesertRoad, CityGates, City, LaboratoryOutside — generated with
`comfy_backdrop.py` (Village/gen_front is the model), depth blur, sparse so gameplay reads. After the terrain.

### Room story flow — one base class — [[code_review_2026-10-19]] §3.1
- **Exists:** six copies of the same state flow (`_execute_step`, `_play_dialogue`, `advance_state`, `_complete_quest_for_dialogue`) in Canyon, Village, Laboratory, CityGates, DesertRoad, LaboratoryOutside; the "already done → advance" rule only as a comment (B66 came from a missed copy).
- **Missing:** a `RoomStoryFlow` base with steps as data and the skip rule in one place.
- **Resume:** extract it from LaboratoryOutside.gd (the smallest), move one room at a time, each with its own `verify_*`.

### Plugin cleanup — [[code_review_2026-10-19]] §2
- **Exists:** 25 addons; ~17 have no reference from the game, 5 of them still start an autoload, godot-rapier2d errors on every start.
- **Done:** phase 1 — 18 unused addons removed (D240), the kept ones tracked fully (D241). **Next:** own fsm, interaction_system, ModalDialog (with its unused `ModalDialogGlobal` autoload); our own menus instead of Maaack when the menus are next touched (D242).

### Vertical rooms — Laboratory first — [[lab_vertical_plan]]
- **Decided:** D225 (Sapega 2026-10-18: Tails of Iron as the reference, Laboratory first, ladders + one-way platforms, no ability locks yet).
- **Exists:** one-way tiles, drop-through. **Missing:** ladders, a multi-floor Laboratory.
- **Built 2026-10-18:** slices 1–2 (ladders, three-floor Laboratory). **Resume:** the next room vertical (Sapega picks), climb frames for the hero.

### NPC quests: recall, hints, side quests — [[npc_recall_plan]]
- **Decided:** D158/D161 (Figma `Quest` entry at the NPC: list, main with a gold diamond), D159 (hint
  under the objective), D160 (bubble art), D162 (side quests in `story.json` via `GameFlow`; delete
  `Scripts/Quest/` — closes D56).
- **Exists:** old man's Quest recall (D169), NPC tasks in `quests.json` with the Blacksmith's Helmet and
  Enchantment (D175, `verify_tasks.gd`).
- **Waits on:** hint texts (D159) from Sapega; Q48 + bubble PNGs for slice 3.
- `Scripts/Quest/` and the `quest_manager` code in `Canyon.gd` / `Village.gd` deleted 2026-10-15 (D162).
- **Resume:** side tasks in the Journal (Figma `journal-side-stories 192:1636`).

### Gamepad — [[gamepad_plan]]
- **Exists:** `interact` (A), tab switch (LB/RB), `save_delete` (Y); menus walk on D-pad/stick;
  D98 prompt swaps E/A; D155 NPC menu rules.
- **Missing:** no pad events on move / jump / attack / skills; no pad button confirms or backs out
  of any menu (`ui_accept` / `ui_cancel` are keys only).
- **Also:** mouse out of the game (Sapega, 2026-10-14) — slice 1b; `attack` is on the left mouse button today.
- **Decided:** D156 (pad layout), D157 (mouse: Ctrl toggle, attack stays on LMB).
- **Resume:** slice 1 of [[gamepad_plan]] — the input map.

### ✅ Merchant & Blacksmith placed — 2026-10-14
- D154. `Merchant` in `Maps/DesertRoad.tscn` (x 1350, after the fight, before `SavePoint_BeforeCity`);
  `Blacksmith` in `Maps/City.tscn` (x 1100). (Canyon test copies and `TestGold` from D165 removed 2026-10-15.)
- **Left as is (Sapega, 2026-10-15):** `Maps/City.tscn` `StateChangeTrigger_Merchant` still auto-plays the
  `[PLACEHOLDER]` `City_Merchant.dqd` greeting though no Merchant stands in the City. Not to be removed
  without asking. Tests: `verify_shop.gd`, `verify_blacksmith.gd`.

### ✅ Music — built 2026-10-14
- [[music_plan]]. A `Music` player in every room and the menu, played by the maaacks
  `ProjectMusicController`; six loops in `Resources/Audio/Music/`. Tracks are provisional (Q38).
  Test: `verify_music.gd`.

### ✅ Room state — built 2026-10-14
- [[room_state_plan]]. `Game.room_state` (saved by `FlagsModule`); `RoomEnemySpawner` remembers
  each fight's dead and the HP of the living (D152); the fight line is not replayed. Test:
  `verify_room_state.gd`.

### ✅ Crafting — built 2026-10-13
- [[crafting_mapping]]. `CraftingService` + `Scenes/Crafting/crafting_menu.tscn`, reached from the
  Blacksmith's Craft. Four station tabs (D108), recipe panel → "Craft X?" / "Cannot Craft".
  `ForgeSystem.gd` deleted (D96). Test: `verify_crafting.gd`.
- **Still mock:** every `gold_cost` (D97: 10 % of the result's buy price) — balance later.

### Dialogue — project-owned presentation layer
- **Plan:** [[dialogue_audit]] — rewrite §3 against D110 before building; the
  audit's A/B framing no longer matches the decision.
- **Decided:** **D110** — DialogueQuest stays as engine, data and branching; we
  own the presentation, compatible with `DQDialogueBox` / `DQChoiceMenu`, and do
  **not** restyle the addon prefab. **D111** — story dialogue is in scope; much
  of the prologue moves onto it. **D112** — full-body art, not portraits;
  existing assets (Зомбі, Кусакам) are usable now. **D113** — no choice UI yet.
  **D114** — merge duplicate speaker IDs, do not rewrite lines.
- **Figma:** `127:1087` box · `36:6` standard NPC · `164:1318` speech bubble ·
  `164:1334` full-screen · `36:65` story scene. Note `36:65` designs **portraits**
  at 160×320 — D112 replaces them with full-body art, so that frame is partly
  outdated.
- **Built 2026-10-15 (D178):** Kusakam's monologues play as speech bubbles over his head
  (`speech_bubble.gd`, temporary PNGs). NPC chatter in bubbles is still Q48.
- **Resume:** update the audit to D110, then build the presentation layer.

### Enchanting — [[enchanting_plan]]
- **Decided:** D94 (two identical → +1), D115 (Blacksmith menu). Picked up first (Sapega, 2026-10-14)
  for the Blacksmith's enchant quest.
- **Decided:** D163 (cap +20), D164 (cost grows with level). **Slices 1–2 built 2026-10-15** — `+N` ids,
  `EnchantingService`, Enchant screen at the Blacksmith, `verify_enchanting.gd`.
- **Resume:** compare the screen with Figma `enchant-list` once MCP is back; slice 3 (the Blacksmith's
  enchant quest) after the Tasks system in [[npc_recall_plan]].

### Shop changes — ✅ done 2026-10-15
- **D103** ✅ no `Equipment` tab; **D106** ✅ the Blacksmith is not a shop.
- **D104** ✅ quantity in "Buy X?": ←/→, 1 … what gold covers (max 99), total follows (`shop_ui.gd`).
- **D105** ✅ unaffordable rows grey, still focusable for the description, pressing does nothing;
  the "Not Enough Gold" modal path is gone. `verify_shop.gd` [4a], [4b2].

### Pickups — three paths (D88)
Enemy loot automatic, no modal · map items need an interaction prompt then show
the pickup modal · a chest opens on button press, adds contents automatically,
**then** shows the pickup modal. `ItemPickup.tscn` is built and tested; chests
are a new case. Map placement still needs named items and places.
- **Waits on (Sapega, asked 2026-10-15):** which items lie where, and a chest sprite.
- **Resume:** place `ItemPickup.tscn` instances by that list; chests as a new `NpcBase`-free interactable.

### Left open on 2026-10-15
- **Journal side tasks** — Figma `journal-side-stories 192:1636`; read the frame first (Figma MCP is back),
  then list `quests.json` tasks there ([[npc_recall_plan]] slice 4).
- **Quest list with the gold diamond (D161)** — `NpcBase._on_task_chosen()` takes one task per NPC
  (`ponytail:` comment); build the list when an NPC has two open tasks at once, or the old man's main
  quest and a task meet on one NPC.
- **Blacksmith task lines are drafts** — `dialogue_quest/Smith_*.dqd`, for Sapega to rewrite.
- **Figma comparisons owed:** Enchant screen vs `enchant-list`; Shop "Buy X?" with the quantity
  arrows (D104, undesigned) and the grey unaffordable row (D105, no Figma state).
- **Laboratory** — trigger positions (D174) are provisional until the lab is playtested (roadmap 1.1);
  its two save points were not thinned (D173 covered the rooms Sapega named).
- **NPC size / foot line (D172)** checked only in captures (`capture_npcs_in_world.gd`), not in play.

### ✅ Game Over — Load Game (D92) — built 2026-10-14
`%LoadButton` between Resume and Return to title opens `LoadGameMenu.tscn` as a scene, like
Main Menu's Continue; Back from it goes to the title. Not in Figma. Test: `verify_game_over.gd`.

---

## 🤝 Agreed but never built

A decision was approved and the work never happened. **Not bugs** — nothing is
broken, the code was simply never written. They matter because in play they are
indistinguishable from bugs, so they get reported over and over as defects.

Rule: a row here **must cite the D-ID or Q-ID that approved it.** If a report
turns out to be unimplemented and no decision covers it, it is not this — it
belongs under *Needs a plan*, and the decision still has to be made.

| Item | Approved by | State |
|---|---|---|
| **Game Menu as one scene** (supersedes "Connect `UIMenuShell`") | **D116, D117** | Plan: [[game_menu_single_scene_plan]]. The tree is already static; four scripts each pick the active tab. **B7 is not a missing `ButtonGroup`** — `vertical_tab_menu.tscn` already has one; `focus_router.focus_tabs()` focuses the first button, so Inventory wears the focus border next to the pressed tab. |
| Companion system | **D201, D209** | Decided 2026-10-18: guard at City Gates (tutorial assist), then Алісия / Астрит / Уризен from the Laboratory; one button, per-companion cooldown. Plan: [[companion_assist_plan]]. Manager is a 27-line stub; four unreferenced `Companion*.gd`; no scenes, no art. Built 2026-10-18 (D213): slices 1–4 (HUD slot right of the skills: portrait of who answers next, seconds left when all rest). **Resume:** lab dialogue lines from Sapega. |
| `ItemPickup` placement | **Q2 / D88** | Built and tested; no production map grants an inventory item. Pickup paths decided in D88, nothing placed. **Wider than this row:** [[scene_inventory]] §4 proves **no** `Objects/*.tscn` is placed in any of the 8 live maps — they contain only `TileMap`, `RoomInstance` and inline `Area2D`s. Chests (D88) are a new scene too. |
| Per-slot player data | **Q4**, then reversed by **D90** | Built in slice 1b, then deliberately reverted. Deferred, not forgotten. |
| Party card SP bar | **D3** ✅ | Built 2026-10-15 (#51): active card shows `SP cur/max` from `SkillManager` (D146); others `—/—` (D18). |
| Status `JP Obtained` | **D11** ✅ | Built 2026-10-15 (#51): `"%d JP" % get_job_points()` (D149), live on `job_points_changed`. |
| Status `Max. SP` meter | **D12** ✅ | Built 2026-10-15 (#51): meter reads `cur / max` from `SkillManager` (D146). |
| Equipment `Max. SP` row | **D24** ✅ | Built 2026-10-15 (#51): row shows `get_max_sp()`, no delta. |

**Worth an audit:** D41–D115 have never been checked against the code
(D1–D40 done 2026-10-15 — [[decision_audit]]; resume at D41). A D-ID
that asserts runtime behaviour with no implementation and no `verify_*` covering
it is an entry for this list. Apart from the D3–D24 rows above, the ones above were
found by Sapega playing, which is the expensive way to find them.

---

## ⚠️ Rework — decisions that reverse shipped code

Slices 1b, 2 and 8 built the previous defaults and pass their tests. A green
`verify_*` in these areas reflects the **old** decision. Full table:
[[figma_decision_register]] §8.

| D-ID | Change | Note |
|---|---|---|
| D89 | Save-slot card → mock data matching Figma | `verify_save_load` expectations change |
| D90 | `player_data.json` back to **shared** across slots | **Knowingly reintroduces the slot-correctness bug** the slice-1b fix removed. Per-slot data returns to this backlog as deferred work. |
| D91 | Auto-save on touch **restored**, alongside the save prompt | Two save paths to keep consistent |
| D99 | Revert the `CLAUDE.md` test-instruction fix | The stale "154 GUT tests" claim returns |
| D104 | Shop quantity selector | New, undesigned UI |
| D105 | Greyed rows instead of the gold modal | Remove the modal path |
| D108 | Blacksmith covers all four stations | Slice 4 scope grows |

---

## 🔍 Needs a plan

No plan note exists for any of these. Write one before writing code.

### Deferred by an approved decision — [[figma_decision_register]]

| System | D-ID | State today |
|---|---|---|
| Healing · Jobs | D65 | Two Figma sidebar entries with no runtime. Sidebar has 7 of Figma's 9 items. |
| Character switching · roster · Stat Points | D18 | Status shows the active character only. |
| Skill auto-targeting | D38 | `use_skill()` takes an explicit target. No heuristic invented. |
| Controller binds, 4 skill slots | D37 | Undefined in Figma. |

### Live surfaces with no design and no runtime — [[figma_coverage]] §1

Level-up notification · enemy health bar · combat context display · in-game
tutorial hints · "objective updated" toast · demo end screen.

Each needs a Figma frame **and** a plan. Raise with Sapega before assuming a design.

### Settings: behaviour spec — [[settings_plan]]

Every row: changes at once, survives a restart, Restore puts it back. Found 2026-10-16: **Language
switches nothing** (no translations registered; D194: translate UI + Journal); **Display Mode** works only in a standalone
window, not embedded in the editor; Controls mixes keyboard and pad (D193, #98); scrollbar too faint (#79).
**Resume:** slice 1 of [[settings_plan]].

### Settings rows with no backing system — [[settings_mapping]]

D43–D47: Resolution, Frame Rate Limit, Screen Brightness, Ambient volume, Text
Speed, Screen Shake, Damage Numbers. Each is a system to build or a row to cut.
D48: keep the third-party maaacks Controls widget or own the rebinding UI.

### Content placement, not systems

| Item | Blocker |
|---|---|
| `ItemPickup` placement | Q2 — built and tested; no production map gives an inventory item. Needs named items and places. |
| **Village: more running before the old man** | **Deferred until the game is playable to the end** (Sapega, 2026-10-13: first a whole game, then find out why it is not fun). Today all Village action sits in x 150–1582 of a 3-cell room (3 × 864 = 2592 px; the active MetSys settings are `SampleProject/Resources/Settings.tres`, cell 864×480): bandit fight → old man in ~2–3 s of running. Wanted on the way: more bandits, Kusakam's lines by the ruined houses, a secret or an item. Open when picked up: new MetSys rooms vs. using the room's full width; how many fights; the lines' text; which item. |

---

## Not in this note

- **Bugs and technical debt** → [[UI_IMPLEMENTATION_STATUS]] § Technical debt.
- **Pre-existing test failures** → [[test_baseline]].
- **Figma frames the designer must update** → [[UI_IMPLEMENTATION_STATUS]].
- **Finished work** → [[runtime_ui_completion_plan]] slices 0–8. Skills, shop,
  blacksmith, save/load, main menu, game over and the combat HUD are **built** —
  do not re-plan them.
