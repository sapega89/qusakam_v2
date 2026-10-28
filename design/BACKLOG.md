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
> Nothing was blocked after that pass. Two items were unblocked, one system came back
> into scope, and seven decisions reverse code that is already shipped and green.
>
> **2026-10-21:** nothing is blocked. The three entries that used to sit under ⛔ Blocked are resolved below
> (hero frames exist, the Laboratory boss and the cutscene helpers are built); the heading stays for the next real block.

## ⛔ Blocked

### ~~Character animations~~ — [[character_animation_plan]] → unblocked: the hero's frames exist (2026-10-21)
- **Now:** every hero state has frames in his own style — Idle, Walk, Run, Jump, Fall, Land, Roll, Climb, Meditate, Hurt,
  Heavy, Block, CastPalm / CastFire / CastStorm (`SampleProject/Sprites/Player/`; D262, D264, D271). Enemies and NPCs stay
  as they are by D139 (NPC idle activities came with D295). No hero Death frames.
- **Was (2026-10-13):** player Walk/Run frames; Idle/Jump/Fall/Attack show one borrowed frame; one generic
  enemy sheet; static NPCs; many unused packs in `assets/`.
- **Decided:** D138 — Kusakam keeps the 64×64 art, the missing states are drawn in that style;
  D139 — enemies and NPCs stay as they are for now.
- **Waits on:** the frames (an artist), not a decision.
- **Resume:** slice 1 of [[character_animation_plan]] when the frames exist.

### ~~Laboratory boss~~ — [[lab_boss_plan]] → unblocked 2026-10-21, both bosses built (queue row 9.2, D316)
- Q52 answered by agent calls D301 (the Brass Collector, Mayor Hall) and D302 (the fire djinn, Laboratory); names confirmed by Sapega.
  The Mayor Hall fight is live (D300); the djinn's hall is queue row 9.7 ([[lab_story_plan]]).

### ~~Cutscenes~~ — [[cutscene_plan]] → unblocked: built, shared helper + HUD hidden + hold-to-skip (D308, 2026-10-21); Mayor Hall beat D300
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
   [[cutscene_plan]] → "Built". ~~Open: HUD stays on screen in cutscenes; no skip control.~~ Done 2026-10-21 (D308).
3. ~~**Healing rework**~~ — **done 2026-10-20** (D252, D261): Healing Palm is learned at level 2 (a sticky hint on the
   level-up, Esc → Skills → Enter; it lands on the first free hotbar slot); the Village old man heals Kusakam and goes
   straight to his decision and gift, no heal request; ~~potions drop from 1 kill in 10 (first-kill 5 potions stay)~~ — **now D261 (4b, 2026-10-21):** enemies drop coins
   only, the first-kill potions are gone, potions are out of the shops.
   B76 fixed on the way: Enter on a Skills row learned nothing.
4. ~~**Combat, souls-lite**~~ — **done 2026-10-20** ([[souls_combat_plan]], D264–D270): a 3-swing light combo
   (4 with two weapons), a heavy attack (R-click / R / pad B) with a breakable wind-up, block and parry (Ctrl / middle
   mouse / pad LB), enemy poise and staggers, enemy combos, the hero staggered by every wounding enemy hit — the tank
   and combo finishers "freeze" him 0.6 s (D253's freeze is this mechanic; no lock bug reproduced), a double dash
   also in the air, ~~walking in towns out of combat (D251)~~ (revoked 2026-10-21, D266: the hero runs everywhere), the halberd two-handed and sword + dagger dual-wield (D250),
   skill casts interruptible (D259 hook). Open: "harder tuning" beyond combos/staggers (enemy HP/damage untouched);
   enemies have no stagger frames (tint only); no stamina by design (D264).
5. ~~**NPCs do something** — idle activities (blacksmith hammers, merchant counts coins, elder…), generated frames.~~ — **done 2026-10-21** (D295):
   all seven NPCs in the maps (Blacksmith, Merchant, Grandfather, three oath keepers, two gate guards) loop a generated
   activity with random rests and turn to the hero in their talk pose while talking; `verify_npc_activity.gd`.
6. ~~**Boss**~~ — **done 2026-10-22** (D307, D310, queue row 9.8, `cloud/lab-9-8`, integration-4): both Laboratory bosses built, with their own voices. Generate the Laboratory boss ([[lab_boss_plan]]) → [[lab_story_plan]].
7. ~~**Foreground parallax**~~ — **done 2026-10-22** (D392, `cloud/living-world`): one shared `foreground_plane.tscn`
   in Village, Canyon, DesertRoad, CityGates, City and LaboratoryOutside.
8. ~~**A reason to climb the Canyon mountain**~~ — **done 2026-10-20** (D257): the abduction waits for the summit of the
   Pride Rock — a generated meditation stone (`gen_shrine`), Kusakam sits (generated `Meditate` frames), the camera drifts
   left, then the raid over black and the ridge lines; flags as before. [[cutscene_plan]] → "Built". ~~Open: no skip, HUD stays.~~ Done (D308).
9. ~~**Inventory actions**~~ — **done 2026-10-21 (D286, [[game_menu_batch_mapping]]):** double click / Enter / pad A
   uses a row — potions heal Kusakam at once, an ether restores SP, weapons / armour / accessories equip into their
   slot, materials and key items open "Cannot Use". Was (Game Menu): equip a weapon/armour/other item from the inventory; using an ingredient opens a
   modal "this item cannot be used"; using a potion heals the hero right away.
10. ~~**Party shows only who is in it**~~ — **done 2026-10-21 (D287):** the party column is Kusakam + the companions in the party (D220), one card at the start. Was: with one character the Game Menu shows only Kusakam until the party grows.
11. ~~**Equipment slot picker**~~ — **done 2026-10-21 (D288):** a slot opens a window with the bag items that fit it (worn one marked), pick equips, Unequip, B cancels. Was: clicking an equipment slot opens a window with the inventory items that fit that slot.
12. ~~**Every hint is a tutorial window**~~ — **done 2026-10-21 (D289):** a hint's first appearance opens the tutorial
    window (game paused, queued past dialogue / menus), the topic joins the Tutorial list, Settings → Game → Tutorial
    Windows turns them into banners; heavy attack and block/parry topics added; button names follow the device.
    Was: each hint opens the tutorial window (nothing is missed), and the topic lands in
    the Tutorial list; a Settings option turns these windows off.
13. ~~**Journal sections**~~ — **done 2026-10-21 (D290, [[journal_codex_plan]]):** Quests · Characters · Bestiary tabs; people recorded when they speak, enemies when they appear and die. Was: choose between Quests and Characters (people we have met); plus a Bestiary.
14. ~~**Blacksmith and merchant come out to meet you**~~ — **done 2026-10-21 (D291–D294):** NPCs no longer draw over the
    hero (the NPC scenes carried z 10 + 10; now 0, checked for every NPC in every map); a generated shop on the Desert Road
    (the Merchant moves to x 1120) and a forge in the City; on arrival each walks out of the door (new walk and front
    frames), control taken, a draft talk, and a task — "The Stolen Caravan" (Merchant) and the existing "The Helmet"
    (Blacksmith); NPC tasks are listed in the Journal. `verify_npc_arrival.gd`. Was (Sapega 2026-10-20): bug — the blacksmith
    is drawn in front of the hero (z-order). Each gets a building (generated art) on the road; when the hero arrives they
    walk out of it and a cutscene plays (gameplay paused): they talk to Kusakam and give a task.
15. ~~**Weapons sheathed out of combat; an attack animation per weapon**~~ — **done 2026-10-20** (D268): the weapon
    is out of sight out of combat (2026-10-21 fix, Sapega: not on the back) and is drawn when a fight starts or on a swing; sword/axe arcs, mace overhead smash,
    dagger stabs, halberd thrusts, dual-wield alternating hands, heavy overhead; new hero frames Hurt, Heavy ×2, Block
    (generated from his artist frame).
16. ~~**MayorHall cutscene and the "unbeatable" boss**~~ — **done 2026-10-21 (D300, queue row 9.3; boss D301/D316).** Plan [[lab_story_plan]] (D300, D301) (Sapega 2026-10-20): Kusakam enters the Mayor Hall, where Астрит,
    Уризен and Алісия stand in a queue and Kusakam joins it (Q65 answered: Алісия too); a wall
    bursts and a boss climbs out. The boss is meant to be unbeatable, but can be beaten: either way Kusakam ends up
    transported to the Laboratory — a win only gives more XP and items from the boss. This is the boss of item 6.
17. ~~**The Laboratory story, rewritten**~~ — **done 2026-10-22** (D310, queue row 9.8, `cloud/lab-9-8`, integration-4; `verify_lab_route`) — plan [[lab_story_plan]] (D302–D307) (Sapega 2026-10-20) — *cells cutscene, wake, acquaintance, Малік and the assists done 2026-10-21 (D304, D305, queue row 9.5); boss hall done (D307); the mob corridors done 2026-10-22 (D306, queue row 9.6, integration-3); voices / demo end done 2026-10-22 (D310, queue row 9.8)* — replaces the current three-storey companion talks:
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
19. **A living world** — **built 2026-10-22** (D392, `cloud/living-world`) except grass sway: there is no grass idle
    sheet yet (an art item). Was (Sapega 2026-10-20): idle animations on decor (banners and cloth sway, grass and palm fronds
    move, lamps and crystals flicker, dust drifts…) and clouds that drift on their own and with parallax as the hero
    moves (Canyon HighClouds/gen_clouds and the other rooms' sky planes).
20. ~~**Smoother hero animations; lighter jump dust**~~ — **done 2026-10-20 (D262):** Idle breathes over 4 keys, a jump plays Jump → Apex → Fall → Land, landing dust is 6 small wisps for 0.3 s. Was (Sapega 2026-10-20): the hero's animations must be smoother —
    redo them (more in-betweens, generated from his artist frames with comfy-sprite, D239); the jump/land dust lasts far
    too long and is too dense — shorter, thinner, in the Ender Lilies spirit.
21. ~~**Every skill has its own animation**~~ — **done 2026-10-21 (D271, D272):** each active skill is cast with a wind-up pose + charge effect and a release pose + effect (Healing Palm palm glow 0.6 s, Fire Strike flaming blade → fire wave 0.35 s, Electric Strike sky bolt → lightning arc 0.5 s); a staggering hit in the wind-up interrupts (no effect, SP and cooldown spent); hotbar slots on the pad RT/R3/L3/Back. Was (Sapega 2026-10-20): each skill (Healing Palm, Fire / Electric Strike, … —
    Resources/Data/skills.json) gets a hero pose/cast animation and its effect, not just a number change.
    A cast can be **interrupted** (a hit during the wind-up staggers the hero): the skill's effect does not happen, but
    its cooldown starts anyway and the SP is spent (D259). Goes with the stagger system of item 4.
22. ~~**Three skill trees: Light, Dark, Neutral**~~ — **done 2026-10-21 (D279–D285, [[skill_trees_plan]]):** Holy Warrior trunk + Paladin / Dark Knight / Warden of Balance trees (8 skills each to level 20, later tiers outlined), one point per level, level cap 99, the oath sworn in the City before Sister Ilvane (priest), Morrow (witch) or Kesh (sand dervish) — permanent; respec at any of them for 10 coins × level; Skills screen tabs, double click learns (B77). Left: subclass (40) and prestige (70), own cast art for the new actives. (The NPCs drawn over the hero — fixed with item 14, D291.) Was (Sapega 2026-10-20 «у кусакама має бути три гілки навичок — темні,
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
23. ~~**DesertRoad grows; the Laboratory grows and splits into screens**~~ — **done 2026-10-22** (D303, D310; queue rows 9.4–9.8, integration-4) (Sapega 2026-10-20 «збільшити локації» → «не
    треба додавати нові назви, дорога має стати більшою» → «місто, брама і село залишаються, каньйон теж, а ось
    лабораторію треба буде збільшити і розбити на екрани»): City, CityGates, Village and Canyon stay as they are. Before
    the City only **DesertRoad** grows (longer, more MetSys cells, more fights, side ledges with pickups) and the XP curve
    (XPManager) is tuned so level 5 lands at the City. The **Laboratory** becomes bigger and is split into several
    screens (separate MetSys rooms) — fits the rewritten Laboratory story (item 17): the cells floor, the corridors of
    mobs, the boss room. Plan: [[world_expansion_plan]] (D296–D299); new parts get the painted terrain/backdrops.
    ~~**DesertRoad part**~~ — **done 2026-10-21** (D296–D299, B79): 2 → 6 cells, three section fights (dunes, mesa,
    broken caravan) spawning on a trigger zone, three ledges with ~~a Potion~~ an Iron Ingot (4b, D261) / Herb ×2 / Mana Crystal that stay picked,
    generated watchtower / wagon / shrine; XP curve (`xp_curve.json`) and rewards (`EnemyStats.xp_reward`) in data —
    level 2 on the road, 5 on the last City Gates kill (`verify_xp_curve`, `verify_road_sections`); level and XP now
    survive a save (B79). **Laboratory part — open**, with items 16 + 17 (queue row 9; outline in the plan).
24. ~~**Every action works on a gamepad**~~ — **done 2026-10-22** (D346–D348, B97–B101, `cloud/weapon-gamepad`, integration-3; `verify_gamepad_parity`). *Left: `interaction_prompt.gd` keeps fixed E/Y textures (remaps not shown), the prologue "Press any key", the inventory tooltip wording, no LB/RB between top-level Game Menu tabs.* (Sapega 2026-10-20 «кожна дія дублюється на джойстику — це важливо, будуть
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
27. **The oath, more interesting** (Sapega 2026-10-21, after D281 «все працює, треба буде подумати, як зробити цікавіше»):
    today the oath is a menu choice at one of three NPCs. Needs a design pass with Sapega before building — candidate
    ideas, none decided: a short trial per keeper before the oath (a fight, a choice, a sacrifice that fits Light/Dark/
    Neutral); an oath ceremony cutscene with a visual change on Kusakam (aura, cloak trim, eye glow); the keepers react
    to each other and to the hero's deeds (dialogue that changes with kills, mercy, quests); a first oath skill granted
    at the ceremony; companions comment on the choice. Not queued — waits for Sapega's ideas.
28. ~~**The game must teach itself — combat first**~~ — **built 2026-10-21** (D324–D326, `cloud/onboarding`, [[onboarding_plan]]); left: the coworkers' playtest, a pad column + rebinding parity in Settings → Controls (Sapega 2026-10-21 «треба буде робити акцент на битві і тому, щоб було
    зрозуміло що і як — є на роботі хлопці, які не зрозуміли, як грати в гру, значить вона недостатньо пояснила»).
    Playtesters did not understand how to play. An onboarding pass: a safe first fight that teaches attack → combo →
    dodge → block → parry → heavy one at a time (do the move to continue), each with its button for keyboard and pad
    (D289 windows); clear on-screen goals (where to go next), readable enemy tells (4b), the hotbar/skills explained when
    they unlock, a Controls page in the menu. Plan first (what a new player sees in the first 10 minutes, step by step);
    then a playtest checklist for Sapega's coworkers. High priority — right after 4b and 8d.
29. ~~**Buildings for every trade NPC**~~ — **done 2026-10-22** (D341, `cloud/buildings`, integration-3). (Sapega 2026-10-21, after D292 «будівлі тепер треба і для наших NPC професій»): the
    oath keepers get theirs in the City — a small sky chapel (priest), a witch's hut with herbs (witch), a dervish tent
    (dervish) — generated like the shop and the forge (D292); others that work somewhere (the grandfather's house in the
    Village) too. Each NPC works at/in front of its building (D295).
30. **Effects polish** (Sapega 2026-10-21 on D273 «вже краще, але є над чим працювати»): a later pass over the generated
    swing, hit and skill effects — collect Sapega's notes first.
31. ~~**Every text in two languages: English and Ukrainian**~~ — **done 2026-10-22**: *part 1 (every UI string, the Language switch, `verify_locale`) (D349–D352, `cloud/localization-1`, integration-3); part 2 data JSON + character names + English `.dqd` twins and part 3 Ukrainian greetings (D353–D358, `cloud/localization-2`, integration-4). Left for Sapega: read the English twins (D354), Q68* (Sapega 2026-10-21 «всі тексти мають мати дві мови і перевірити,
    що на англійській версії немає кирилиці, щоб не було помилок, і так само на українській не повинно бути англійських
    текстів — окрім кнопок; назви вкладок теж мають бути перекладені»). Today: `SampleProject/Resources/Translations/en.po`,
    `uk.po` exist (partial), a few scripts call `tr()`, `.dqd` dialogue is Ukrainian, UI/data text mostly English. Needed:
    every user-facing string (scenes, data JSON — items, skills, quests, journal, bestiary, tutorials, hints — dialogue
    `.dqd` in both languages, tab names, menus, modals) through translation keys; a language switch in Settings (it
    exists? check D-IDs); translations registered without `project.godot` (runtime `TranslationServer`, D270 pattern) or
    in it once Sapega commits it. A verify that walks every screen and every text resource in each locale and fails on
    Cyrillic in EN and on Latin words in UK (allow-list: key/button glyph names like Tab, Esc, LB, RT, A/B/X/Y, and proper
    tokens HP/SP/XP — Sapega 2026-10-21 «HP, SP, XP так і залиш»). Voices: English greetings via Kokoro (D277), Ukrainian via a Piper voice whose
    licence allows release (check each voice's model card; never non-commercial weights); greeting picked by locale.
    Plan first: `design/localization_plan.md`.
32. ~~**Ledges you can get back onto**~~ — **done 2026-10-21** (D296 amended): a 2-tile step on the east side of the
    dune rock, the mesa end rock and the caravan rock; `verify_road_sections` [5] climbs every top from both sides. (Sapega 2026-10-21 «уступи мають бути такими, що я можу повернутись на них далі, бо немає
    в нас подвійного стрибка»): every DesertRoad ledge (D296/D298) reachable again from where the hero ends up — steps within
    one jump on the way back too; a verify that walks/jumps back up each ledge with real input.
33. ~~**Chests** (Q2)~~ — **done 2026-10-21** (gift modal + loot feed D323; chests D339, D340, `cloud/chests`, integration-2). *Left: wire the landed Raise frames into the player (B91).* a generated chest — closed, opening, open frames; opening it Kusakam raises the item overhead (a pickup
    pose, generated from his artist frames), then the obtained-item modal. Also: **a modal when someone gives you items**
    (the grandfather's gift, quest rewards — today only pickups show it) and **show what you picked up from a mob** (a
    small loot feed / toast on the HUD).
34. **Companion lore stubs** (Q51) — *stubs done 2026-10-22 (D343, `cloud/buildings`, integration-3); left: the Journal UI pages for character lore from Figma*: Астрит, Алісія, Уризен each get a separate description in `lore.md` (stubs marked
    [ЗАГЛУШКА]) — Sapega takes them to the characters' creators. Figma has the Journal UI for character lore and city
    flags — build those pages from Figma (ui-screen-pipeline) on top of D290.
35. ~~**NPC chatter in speech clouds**~~ — **route built 2026-10-21** (D338, `cloud/settings-cleanup`); no lines yet (Q67). (Q48): ambient NPC lines use the D263 cloud, not the box.
36. ~~**Who is speaking**~~ — **done 2026-10-21** (D321, `cloud/dialogue-ui`). (Q31): the speaker's name centred in the dialogue box with their portrait (e.g. Астрит) so the
    player knows who she is; name colours don't matter.
37. ~~**Objective plaque**~~ — **done 2026-10-21** (D322, `cloud/dialogue-ui`). (Q39): the 'Return to the village'-style objective also in the Journal list; the HUD plaque fades
    out after a few seconds and shows again after leaving a menu.
38. ~~**Village centre**~~ (Q59) — **done 2026-10-22** (D342, `cloud/buildings`, integration-3). *Left: elder art (two views) + his lines, then swap `village_elder.tscn`'s sheet; Q58's one-cell Village reshape is not done.*: a separate house at the end of the Village — an interior room like the Mayor Hall (the
    village elder's house). The Village stays one cell high (Q58).
39. ~~**Cleanup**~~ — **done 2026-10-21** (D337, `cloud/settings-cleanup`; the orphan world-object scenes stay as a parts bin): delete `Maps/Legacy` (18 maps, Q34) and the ranged stubs (`EnemyRanged.gd`, `player_projectile.tscn`).
40. ~~**Ranged weapons**~~ — **done 2026-10-22** (D380–D387, `cloud/bow`, integration-4, [[ranged_plan]]; left: bow frames for air / block / hurt B110, enemy tempo B111, aim up/down) (Q35, Sapega «стрільба з лука має бути як в грі Skul»): bows for the hero and ranged enemies;
    the hero's bow plays like Skul: The Hero Slayer (confirmed by Sapega; fast aimed shots on the attack button, arrows fly straight, charge
    for a stronger shot — confirm details with Sapega when planned). Plan first.
41. ~~**Graphics settings**~~ — **done 2026-10-21** (D327–D329, `cloud/settings-cleanup`; `GameUITheme.tres` must be regenerated locally): resolution and FPS-limit options in Settings (settings_plan.md:58 values — pick common ones:
    1280×720 … 2560×1440 / 30, 60, 120, 144, unlimited). Skills from slots auto-target the nearest enemy for now (D38).
    The eight small Figma deviations B1, B27, B28, B30, B35, B37, B39, B56 are **accepted as built** — ✅ recorded as
    **D317**, B rows deleted 2026-10-21. **One selection look in every menu** (Q33 ✅): the focused/selected row styled the same everywhere
    (theme tokens, ui-theme-tokens skill).
42. **Kusakam animated holding each weapon** — *sword frames wired 2026-10-22 (D344, D345, `cloud/weapon-gamepad`, integration-3, [[hero_weapon_animation_plan]]); ~~dagger / mace / halberd libraries, palette swap, dual-wield~~ done 2026-10-22 (D359–D364, `cloud/weapons-all`, integration-4; art fixes B105, B106); left: bare hands (optional slice 7), other dual pairs* (Sapega 2026-10-21 «анімація Кусакама має бути більш красивою: він має мати
    анімацію, як він тримає меч, і анімацію, як він тримає інші типи зброї»). Today the weapon is a separate sprite
    (`WeaponView`, D268) pinned to measured hand points on the artist frames, hidden out of combat. Needed: full-body hero
    frames per weapon grip — sword/axe one-handed, dagger, mace, halberd two-handed, dual-wield, bare hands — for combat
    idle, run, jump/fall, the light combo, heavy, block, hurt; generated from the artist frames with comfy-sprite (D239),
    the weapon drawn in the frame, smoother and prettier than now (more in-betweens). Decide with the plan whether the
    weapon stays a separate sprite on top (cheaper, swaps per item) or is baked per type (prettier). Plan first:
    `design/hero_weapon_animation_plan.md`; big — slice per weapon type.
    **Weapon variants** (Sapega 2026-10-22 «меч може бути мідний, а може бути кристалічний — перекрасимо чи як?»): frames
    are made per weapon TYPE (shape: sword, dagger, mace, halberd…); each ITEM recolours the blade/head in the frames with
    a palette-swap shader (the generated frames keep a fixed blade palette as the key; copper, iron, silver, crystal — the
    crystal one also gets a glow/shimmer). A variant whose silhouette differs (a jagged crystal blade, a curved scimitar)
    gets its own frames as a sub-type. Item data (items.json) names its type + palette; next slice after the sword wiring.
43. ~~**The Skills screen must be reworked — it is inconvenient**~~ — **done 2026-10-21** (D330–D334, `cloud/skills-screen`) (Sapega 2026-10-21 «меню вивчення скілів треба
    перероблювати, воно не зручне»). Today (D283): two columns (trunk + oath tree under three tabs), rows learned by double
    click / Enter / pad A, the right column scrolls, locked rows show a lock even when learnable. Candidate direction until
    Sapega says what bothers him: a real tree view (tiers by level, lines between skills), clear states (learned / can learn
    now / locked with the reason and level), a detail panel with cost, SP, cooldown and what it does, a visible Learn button
    (mouse) plus the pad button, assign-to-hotbar from the same screen. Check Figma first (skills frame 58:453); if the
    redesign departs from Figma it is Sapega's call. Sapega's notes:
    - **No instant learn on double click** («подвійний клік — то погано, бо я, наприклад, захочу перевибрати, поки не
      натиснув прийняти»): picks are pending — the player marks skills (and attribute points, item 44), can undo/re-pick,
      and only an **Accept** button (and its pad button) spends the points. Cancel/Esc drops the pending picks. Replaces
      the B77 double-click learn (D283).
    - **All six problems confirmed by Sapega**: (1) a lock shows even on learnable skills — clear learned / can learn now /
      locked-with-reason states; (2) what a skill does and costs is unclear — a detail panel (effect, cost, SP, cooldown,
      level gate); (3) the right column scrolls and the tabs eat space — fit without scrolling; (4) no Learn button — Accept
      button + pad button; (5) a list, not a tree — a real tree view by level tiers with links; (6) a skill cannot be put on
      the hotbar from here — assign to a slot in the same screen.
44. ~~**Attribute points every level**~~ — **done 2026-10-21** (D335, D336, `cloud/skills-screen`; Agility in combat is B84) (Sapega 2026-10-21 «треба, мабуть, сила, ловкість, HP і мудрість — навички качати
    кожен рівень, бо я так хочу»): on each level-up the hero also gets attribute points to put into **Strength, Agility,
    HP (Vitality) and Wisdom**, in the same pending/Accept flow as item 43. Today `player_state` already has strength,
    dexterity, constitution, intelligence (and StatCalculator) — check what they drive. **5 attribute points per level** (Sapega «5 навичок на рівень»; skill points stay 1 per level, D279). Values to plan (
    what each point gives: Strength → physical damage, Agility → crit/dodge/attack speed, HP → max HP, Wisdom → SP, skill
    power, SP regen), respec together with skills (D282). Plan with item 43: `design/skill_screen_rework_plan.md`.
    **Plan: [[audio_plan]]** (D274–D278), built; the listening checklist for Sapega is in the plan.

### Performance — weak-PC lag and room-change freezes — [[performance_plan]]
- **Measured 2026-10-23** (`SampleProject/UI/measure_performance.gd`, dev PC Ryzen 5 5600 / RTX 3060):
  - a first visit to a room freezes one frame for 39–172 ms, and 46–89 % of that is GDScript compiling;
  - going back to a room, or walking on, blocks 13–51 ms;
  - New Game freezes for 517 ms over two frames, with no loading screen;
  - per frame the GPU dominates: the WorldEnvironment glow and colour curves (D233) take 19–33 %, the parallax layers up to 36 % and the lab lights up to 36 %, with 8.5–9.6× overdraw outdoors;
  - textures and `assets/` are not a cost.
- **Exists:**
  - a synchronous `load()` in `MetSysGame.load_room()` (`MetSysGame.gd:89`);
  - `RoomInstance.get_neighbor_rooms()`, which nothing calls;
  - Maaack's `SceneLoader` with threaded loading, which nothing uses.
- **Waits on:**
  - slices 1–6 wait on nothing (D434 answers how the load looks);
  - slice 7 waits on Q83, then Q84.
- **Resume:** slice 1 — delete the temporary `DebugLogger.current_level = INFO` (`Game.gd:51`) and the room-change `print()`s.

### World structure: big locations, metroidvania inside — [[world_structure_plan]] (D458)
- **Exists:** 11 rooms in five linear locations, and a MetSys grid map over the parchment.
- **Waits on:** Q75–Q78 (the defaults are in the plan); the fade and background loading ([[performance_plan]]) before the pilot location.
- **Resume:** slice 1 — write `Resources/Data/locations.json` grouping the 11 rooms into the five locations, plus `verify_locations.gd`.

### Enemy stamina — [[enemy_stamina_plan]] (D824, D856)
Slice 1 built (`cloud/enemy-stamina`, merged by integrate-31); later slices in the plan.

### Enemy variety — [[enemy_variety_plan]] (D495)
- **Exists:** four kinds, one size each; enemies never block.
- **Waits on:** Q85 (defaults are in the plan); after `cloud/combat-feel` and D494.
- **Resume:** slice 1 — add a `scale` field to the enemy stats and honour it in the sprite, the shapes and the stats; add `verify_enemy_variety.gd`.

### Flying enemies — [[flying_enemies_plan]] (D445)
- **Exists:** four ground enemy kinds (melee, fast, tank, archer); `DefaultEnemy` always applies gravity.
- **Waits on:** Q74 (where they live, how they fight, numbers — defaults in the plan) and the ComfyUI art batch.
- **Resume:** slice 0 — add `enemy_vulture` / `enemy_bat` to `Scripts/Tools/comfy_sprite.py` and render a ×4 candidate sheet for Sapega.

### Ambient critters and a foreground in every room — [[ambient_critters_plan]] (D774)
- **Exists:** `FrontDark` foregrounds in 13 of 16 rooms (D749, D750); the enemy bat's sheet; no critter scene, no small bird.
- **Waits on:** nothing for slice 1 (defaults in the plan: 30 s return, 160 px scare distance).
- **Resume:** slice 1 — `AmbientCritter.gd` + `critter_bat.tscn`, two bats in `LizardCave/FrontDark`, `verify_ambient_critters.gd`.

### Dropped from the plan 2026-10-28
- **R5 — re-shoot the fixed rooms, depth critics again, an MP4 for Sapega, `verify_depth`** (Sapega 28.10: «R5 не роби взагалі»). Not to be started unless he brings it back.

### ComfyUI art — stopped 2026-10-28
Sapega 28.10: «комфі більше не запускай, в беклог все що стосується комфі». Nothing here runs until he restarts the art
lane himself. Size/shape fixes are not here: they are scaling in the cloud (P10, `prop-sizes`).
- **H3 weapon variants, dual and bow** (LungeCut, ShieldCharge, LeapSlam; D812). Sword, dagger, mace, halberd are drawn
  and wired (`wire-leftovers`). Fix-ups left on the drawn ones: the halberd's double-axe head in 5 frames (`HEADS` in
  `halberd_fixups.py`, its README), the mace handle past the fist in 3 frames. Sheet `design/shots/h3_weapon_variants_2.png`
  not yet seen by Sapega.
- **A15 the bandit in normal proportions** (not chibi, D816); then re-measure its `enemy_variety.json` scale.
- **A4 the alchemist** ([[asset_verdicts_2026-10-27]]).
- **The merchant as an older, cunning rat-folk** (entry below).
- **Burnt village**: charred palms, banners, grass (wire-backdrops left them green).
- **City**: craft quarter forge and chapel fronts (M6c).
- **Laboratory v3**: the djinn hall's cave look at ground level (D865; lab-v3-now had no art), the stairs and the guard's
  alcove still on placeholder planes (`Lab/gen_far`, slab steps).
- **Art-lane B rows that need new art**: B173 (DragonMural/MesaClimb floor baked into one backdrop), B174 (GatehouseCellar
  two speeds), B148 (comfy_sprite mixes facings on the armoured scorpion). B184 Death frames are drawn, wait on his look.
- **D915 the gap above the locked gates**: a palisade wall over BanditCamp's `Gate_Stockade`, a rock lintel over LizardCave's `Gate_Shrine` (the collision stays 416 px).
- **B168 the prisoner's sacrifice** (D459): fire burst and the body burning away, frames from comfy-sprite with his
  sheet; the djinn rises from the fire (`LabCells.gd:134` still plays `collapse` + fade-in).
- **Effects polish (A9)** if his notes need new cards (entry below).

### Moved out of MASTER_PLAN 2026-10-27 (waiting on Sapega or deferred)
Sapega: «те, що не закрито, винесемо з плану». The old plan: [[archive/MASTER_PLAN_2026-10-24]].
- **Effects polish (A9, item 30)** — waits on his notes; `fx-film` films every effect (GIFs + sheets in
  `design/shots/fx/`). Resume: send him the GIFs, collect «ok / change» per effect, one art batch.
- **The merchant becomes an older, cunning rat-folk** (Sapega's asset-catalog note on `NPCs/merchant/sheet.png`; 28.10: «це потім в беклог запиши, і все»): a new character look, normal proportions (D816), size by the chart (D814). Not started.
- ~~**The bandit's look**~~ — answered 28.10: «він чібі, а має бути нормального вигляду, як усі інші NPC» → art queue A15 ([[asset_verdicts_2026-10-27]]).
- **Pixel UI skin and font (A11, D239)** — deferred; the 2026-10-23 HUD comparison is `design/shots/ui_style/hud_compare.png`.
- **Prologue script (S18)** — deferred; the lore idea: the barrier bursts when Kusakam sits to meditate.
- **Q88, HUD text size** — keep as is / scale the hero panel and hotbar together ×1.25 / text only.
- **Plugins slices 2–3 (S4, D242)** — own ModalDialog; own menus instead of Maaack.
- **The weak PC (S14)** — i5-6600, 16 GB, Intel HD 530: D611 gives it Quality High; does it lag? If yes, move HD 5xx/6xx
  to Low on first run (amend D611).
- **Critter tweaks** — a smaller pigeon, a moth of its own shape: by scaling/stretching, no new art (Sapega 28.10) — cloud `critter-tweaks`.

### World scale: one size chart for everything next to the hero — [[world_scale_plan]]
- **Exists:** the hero ≈70 world px (the unit H), adults ×1.5 (D172), chibi (D598); props sized by eye.
- **Waits on:** nothing (Sapega approves the chart picture after slice 1).
- **Resume:** slice 1 — routine `scale-probe`: `world_scale.json`, `probe_world_scale.gd`, `scale_chart.py`.

### Dialogue review: every draft line signed off, and the oath — [[dialogue_review_plan]]
- **Exists:** ~144 lines marked `[ЧЕРНЕТКА]` / `[DRAFT]` in `uk.po` / `en.po` (chatter, task givers, oath census, charms,
  journal hints, side stories); the oath is a menu choice (D281, item 27 below has the ideas).
- **Waits on:** `integrate-28` and `side-stories` merged; the oath waits on Sapega.
- **Resume:** slice 1 — `Scripts/Tools/dialogue_review.py` builds the review page from the `.po` files (like the P1 page).

### Depth critics from video — [[depth_critics_plan]]
- **Exists:** stills only (`capture_*.gd`, `playthrough.gd`); no video, nothing measures a plane's speed.
- **Waits on:** nothing.
- **Resume:** slice 1 — `film_rooms.gd` (Movie Maker, real input), the per-plane probe, `film_pack.py` (filmstrip + slit-scan).

### Skill trees v2: 19 skills a tab — [[skill_trees_plan]] → *v2* (D535)
- **Exists:** the base tree has 10 skills (3 active) and each oath has 11 (3 active); `SkillCombatExecutor` has one hit shape and three poses.
- **Waits on:** Sapega reading the draft list of 33 new skills (28 active, 5 passive); Q86 (hotbar slots) for the HUD only.
- **Resume:** slice 1 — add the 33 draft rows to `skills.json`, make the 5 new passives work, keep the new actives unlearnable, and re-tune the JP caps (D530).

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
- D154. `Merchant` in `Maps/DesertRoad.tscn` (x 1350, moved to 1120 in front of his shop by D292; after the fight, before `SavePoint_BeforeCity`);
  `Blacksmith` in `Maps/City.tscn` (x 1100). (Canyon test copies and `TestGold` from D165 removed 2026-10-15.)
- ~~Left as is (Sapega, 2026-10-15): `Maps/City.tscn` `StateChangeTrigger_Merchant` auto-played the
  `[PLACEHOLDER]` `City_Merchant.dqd` greeting though no Merchant stood in the City.~~ Replaced on Sapega's
  2026-10-21 request by the caravan merchant himself at that spot (D311); `City_Merchant.dqd` is his Talk draft. Tests: `verify_shop.gd`, `verify_blacksmith.gd`.

### ✅ Music — built 2026-10-14
- [[music_plan]]. A `Music` player in every room and the menu, played by the maaacks
  `ProjectMusicController`; six loops in `Resources/Audio/Music/`. Tracks are provisional (Q38).
  Test: `verify_music.gd`.

### Fight music — [[music_plan]] slice 3 (D414, #34)
- A battle track for any fight, a boss track for the two bosses; room tracks stay. Exists: `ProjectMusicController.play_stream`,
  `EventBus.combat_state_changed`, the boss-room fight hooks. Waits on: Sapega's pick of the CC0 tracks (3b only).
- ✅ 3a built 2026-10-22 (D419), placeholder tracks. **Resume:** 3b — Sapega's pick from the candidates in [[music_plan]].

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
| **Game Menu as one scene** (supersedes "Connect `UIMenuShell`") | **D116, D117** | ✅ **Built:** `menu_shell`, `panel_manager.gd`, `vertical_tab_menu.tscn` are gone, `game_menu.gd` switches tabs, `verify_game_menu.gd`; later work [[game_menu_batch_mapping]]. Was: Plan: [[game_menu_single_scene_plan]]. The tree is already static; four scripts each pick the active tab. **B7 is not a missing `ButtonGroup`** — `vertical_tab_menu.tscn` already has one; `focus_router.focus_tabs()` focuses the first button, so Inventory wears the focus border next to the pressed tab. |
| Companion system | **D201, D209** | ✅ **Built 2026-10-18 (D213)**, art D243–D245, scenes `Scenes/Characters/Companions/`, `verify_companions.gd`. Was: Decided 2026-10-18: guard at City Gates (tutorial assist), then Алісия / Астрит / Уризен from the Laboratory; one button, per-companion cooldown. Plan: [[companion_assist_plan]]. Manager is a 27-line stub; four unreferenced `Companion*.gd`; no scenes, no art. Built 2026-10-18 (D213): slices 1–4 (HUD slot right of the skills: portrait of who answers next, seconds left when all rest). **Resume:** lab dialogue lines from Sapega. |
| `ItemPickup` placement | **Q2 / D88** | ✅ **Placed 2026-10-21 (D298):** `DesertRoad.tscn` has three `ItemPickup`s (`iron_ingot`, `herb`, `mana_crystal`) — the rest of this cell is the 2026-10-15 state. Was: built and tested; no production map grants an inventory item. Pickup paths decided in D88, nothing placed. **Wider than this row:** [[scene_inventory]] §4 proves **no** `Objects/*.tscn` is placed in any of the 8 live maps — they contain only `TileMap`, `RoomInstance` and inline `Area2D`s. Chests (D88) are a new scene too. |
| Journal quests grouped by city (region bar of Figma `192:1636`) | **D181** | Not built: no region in `journal_component.gd` or `story.json` (grep `region` → 0). The city name is Q54 (default *Bab ar-Rimal*). |
| Per-slot player data | **Q4** | ✅ Saves are per slot (`SaveSystem.gd:279,294`). D90 (one shared file) was never built and is cancelled by D413 ([[decision_audit]] Run 3). |
| Party card SP bar | **D3** ✅ | Built 2026-10-15 (#51): active card shows `SP cur/max` from `SkillManager` (D146); others `—/—` (D18). |
| Special story dialogue presentation (Figma `36:65`); much of the prologue's story dialogue moves onto it | **D111** | Not built: there is no story layout in code, and every story beat and cutscene plays in the standard box. Found by [[decision_audit]] Run 3, 2026-10-23. |
| Full-body character art in story scenes, not portraits | **D112** | Not built. It waits on D111, because there is no story scene to put the art in. Found by [[decision_audit]] Run 3. |
| Hero Death animation | **D138** (amended by D196 → D239) | Not built: there is no `Sprites/Player/Death/` and no `Death` animation in `Player.tscn`. `Player.die()` (`Scripts/Player.gd:269-283`) goes straight to Game Over. Every other D138 state exists. It is in the ComfyUI art batch (D435). Found by [[decision_audit]] Run 4. |
| Objective hints in the Journal: `story.json` objectives get an optional `hint` + `from`; the Journal shows the hint under its objective, attributed to the NPC who gave it, and the Quest replay ends on it | **D159** (and the hint half of **D161**) | Not built: `story.json` has no `hint` / `from` key, `journal_component.gd` has no hint line, and the replay ends only on "Current objective: …" (`StoryNpc.gd:32`). The texts are Sapega's and still owed (#27). The code can land first with empty hints, which show nothing. Plan: [[npc_recall_plan]] slice 1. Found by [[decision_audit]] Run 5. |
| Status `JP Obtained` | **D11** ✅ | Built 2026-10-15 (#51): `"%d JP" % get_job_points()` (D149), live on `job_points_changed`. |
| Status `Max. SP` meter | **D12** ✅ | Built 2026-10-15 (#51): meter reads `cur / max` from `SkillManager` (D146). |
| Equipment `Max. SP` row | **D24** ✅ | Built 2026-10-15 (#51): row shows `get_max_sp()`, no delta. |

**Worth an audit:** D179–D432 have never been checked against the code
(D1–D40 done 2026-10-15, D41–D178 on 2026-10-23 — [[decision_audit]]; resume at D179). A D-ID
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

### Future (not the demo): playable heroes and co-op — [[playable_heroes_plan]] (D498)
- **Resume:** only after Sapega says the Kusakam game is where he wants it; slice 1 is the hero choice at New Game.

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
window, not embedded in the editor; scrollbar too faint (#79).
**Resume:** slice 1 of [[settings_plan]].

### Settings rows with no backing system — [[settings_mapping]]

D43–D47: Resolution, Frame Rate Limit, Screen Brightness, Ambient volume, Text
Speed, Screen Shake, Damage Numbers. Each is a system to build or a row to cut.
D48: keep the third-party maaacks Controls widget or own the rebinding UI.

### Content placement, not systems

| Item | Blocker |
|---|---|
| ~~`ItemPickup` placement~~ | Q2 answered 2026-10-21: the three DesertRoad ledges (D298) — placed. |
| **Village: more running before the old man** | **Deferred until the game is playable to the end** (Sapega, 2026-10-13: first a whole game, then find out why it is not fun). Today all Village action sits in x 150–1582 of a 3-cell room (3 × 864 = 2592 px; the active MetSys settings are `SampleProject/Resources/Settings.tres`, cell 864×480): bandit fight → old man in ~2–3 s of running. Wanted on the way: more bandits, Kusakam's lines by the ruined houses, a secret or an item. Open when picked up: new MetSys rooms vs. using the room's full width; how many fights; the lines' text; which item. |

---

## Not in this note

- **Bugs and technical debt** → [[UI_IMPLEMENTATION_STATUS]] § Technical debt.
- **Pre-existing test failures** → [[test_baseline]].
- **Figma frames the designer must update** → [[UI_IMPLEMENTATION_STATUS]].
- **Finished work** → [[runtime_ui_completion_plan]] slices 0–8. Skills, shop,
  blacksmith, save/load, main menu, game over and the combat HUD are **built** —
  do not re-plan them.

- **The oath chooses the hero** (D725, 2026-10-26) — [[oath_affinity_plan]]; routine `oath-affinity`.
