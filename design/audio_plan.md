---
type: plan
status: done
tags: [audio, feedback]
---

# Audio — plan (BACKLOG 26)

**Built 2026-10-21** (slices 1–4, D274–D278; `verify_audio.gd` 81 checks). Before this pass: music per room and
14 combat SFX on 4 events. Added: world sound, every combat event, character voices (babble + short greetings),
companion calls and boss voices. Left: see *Out of scope* (boss cutscene lines wait for a boss, rumble for item 24).
Listening montage (not in git): `%TEMP%/claude/…/scratchpad/shots/fb26_montage.wav`, built by a scratch script from
the game's own files in event order (combat → casts → steps → world → babble → greetings → calls → hero → enemies → boss → ambience).
Figma: no design exists (audio is not a screen). Decisions this pass makes: **D274–D278** (agent calls, Sapega to confirm).
Feedback rules: [[play_feedback_queue]]. Builds on [[souls_combat_plan]] (D264–D270), D271 casts, D254 typing, D263 cloud talk.

## What exists today

| Thing | Where | State |
|---|---|---|
| Volume API (Master / Music / SFX) | `Scripts/Systems/AudioManager.gd:45-102` | ✅ used by `SettingsModule.gd:52` |
| Loader for `Resources/Audio/default_bus_layout.tres` | `AudioManager.gd:18-24` | ❌ dead: file does not exist; the live layout is `res://default_bus_layout.tres` (`project.godot` → `buses/default_bus_layout`) |
| Bus layout | `default_bus_layout.tres` | ⚠️ Master, Music, SFX only |
| `play_sfx(name)` from `sfx_config.json` | `AudioManager.gd:106-140` | ❌ dead: the JSON does not exist, no caller |
| `play_sfx_path(path)` | `AudioManager.gd:143` | ✅ the only playback path |
| Combat SFX (swing, enemy wind-up, hit, heavy hit, hero hurt, block/parry) | `Systems/VFXHooks.gd:28-33, 79-135` | ✅ 14 Kenney CC0 files, `Assets/Audio/SFX/README.md` |
| Settings sliders | `Menus/Game/options_component.gd:159-163` | ✅ Master Volume, Music, Sound Effects (Figma 17:325) |
| Music per room | `Resources/Audio/Music/README.md`, each room's `Music` node | ✅ `verify_music.gd` |
| UI sound controller (Maaacks) | `project_ui_sound_controller.tscn` autoload | ⚠️ present, every stream empty |
| Dialogue typing per letter | `addons/dialogue_quest/.../dialogue_box.gd:78` `text_shown` | ✅ signal, nobody listens |
| Cloud talk typing (D263) | `UI/Components/speech_bubble.gd` `type_out`, `DialogueManager.gd:297` | ✅ no sound |
| Player-initiated NPC talk | `Gameplay/NPCs/NpcBase.gd:55` `_on_interacted` | ✅ the only path where the hero starts a talk; cutscenes start dialogues from room scripts |
| Skill cast wind-up / release / interrupt | `PlayerCombat.begin_cast` :286, `SkillManager.use_skill` → `skill_used`, `skill_interrupted` | ⚠️ no event at wind-up start |
| Bosses | `Characters/Bosses/BossEnemy.gd` (group `boss`; `brass_collector.tscn`, `fire_djinn.tscn`) | ✅ voiced through the D278 hook; placed in rooms by queue rows 9.3 / 9.7 |

## Missing entirely (how checked)

- Ambience: `grep -rn "Ambience\|ambience" Scripts/` → 0. Footsteps, jump, ladder, pickup, coin, level-up sounds → 0.
- Voice of any kind: no babble, no grunts, no greetings (`grep -rn "Voice\|babble\|greeting" Scripts/` → 0).
- Buses `Ambience`, `Voice` → absent from `default_bus_layout.tres`.
- Doors: no door objects in the active maps (`Portal.gd` is used only in `Maps/Legacy/`).

## Decisions (agent calls, recorded as D-IDs)

1. **Buses (D274).** Master → Music, SFX; **Ambience and Voice send into SFX**, so the three existing sliders keep
   working and the "Sound Effects" slider covers world, voices and ambience. No new slider rows (no Figma; a separate
   Voice slider is a Sapega call). Layout in `res://default_bus_layout.tres` (the file `project.godot` already points at).
2. **One playback path (D274).** `AudioManager.play(event)` reads `Resources/Data/sound_events.json`
   (event → bus, files, volume_db, pitch); an unknown event is an error, not silence. `SoundHooks` (child of the
   AudioManager autoload) maps `EventBus` events to sound events; movement sounds are played by `PlayerMover` itself.
   UI clicks/focus go through the existing Maaacks `ProjectUISoundController` (focus covers gamepad navigation).
   Playback is non-positional (ponytail: the camera follows the hero in rooms ≤ 3 screens; positional when it matters).
3. **Sources (D275)** — in this order: Kenney CC0 packs, OpenGameArt CC0 only, sounds synthesised in Python
   (babble), Kokoro-82M TTS (Apache 2.0 weights and voices) for greetings, companion calls, battle cries and boss shouts,
   processed by simple DSP. No XTTS-v2 / F5-TTS / non-commercial weights. Every folder has a README with pack, author,
   licence, URL; TTS lines are AI-generated → **Steam "AI generated content" disclosure: pre-generated voice lines**.
4. **Language of spoken lines (D277): English.** Kokoro has no Ukrainian voice; user-facing text is English by
   convention (future localisation); greetings are one to three words and do not translate any dialogue line.
   Ukrainian lines later via a Piper voice whose licence allows release, if Sapega wants.
5. **Greeting rule (D277).** A greeting plays **only when the hero starts the talk** (`NpcBase._on_interacted`, the menu
   opens). Meeting cutscenes are started by room scripts and triggers, never through `NpcBase`, so a first-meeting
   cutscene has no greeting by construction — no per-NPC "met before" flag to keep in sync.
6. **Bosses (D278).** Any enemy in group `boss` / `miniboss` uses the boss voice: a roar when it first sees the hero,
   a shout on some attacks, a death roar. No boss is in a room today, so the cutscene lines wait for items 16/17.

## Event → sound map (D276)

| Event | Source of the event | Sound event | Bus | Files (pack) |
|---|---|---|---|---|
| Light swing (hit or miss) | `player_attacked` | `swing` | SFX | knifeSlice ×2 (RPG Audio) |
| Heavy wind-up | `player_heavy_windup` | `heavy_windup` + hero `hero_effort` | SFX / Voice | drawKnife; Kokoro "Hah!" |
| Hit lands / heavy hit | `damage_dealt` | `hit`, `hit_heavy` | SFX | impactPunch medium/heavy (Impact) |
| Block / parry | `player_blocked` / `player_parried` | `block`, `parry` | SFX | impactMetal light / heavy + impactBell (Impact) |
| Hero hurt / death | `damage_received` (hero) / `player_died` | `hero_hurt` + `hero_hurt_voice`, `hero_death` | SFX / Voice | impactSoft (Impact); hit1–5, die1 (OGA tinyworlds) |
| Hero stagger | `player_staggered` | (hurt voice covers it) | — | — |
| Enemy wind-up | `attack_started` | `enemy_windup` (+ 35 % `enemy_<type>_attack` grunt) | SFX / Voice | drawKnife; grunts (OGA thebardofblasphemy) |
| Enemy hurt / death | `damage_received` (enemy) | `enemy_<type>_hurt`, `enemy_<type>_death` | Voice | grunts segments; tank pitched ×0.75, fast ×1.15 |
| Enemy staggered (poise break) | `enemy_staggered` | `stagger` | SFX | impactPlate heavy (Impact) |
| Boss attacks / dies (per boss, `boss_voices` in `sound_events.json`, D310) | `attack_started` (1st swing roar, every 2nd after it shout), death | Brass Collector `brass_collector_roar` / `boss_shout` / `boss_death`; fire djinn `fire_djinn_roar` / `fire_djinn_laugh` / `boss_death` | Voice | Kokoro roars (golem: ring-mod) + monster_roar (OGA trazzz123) layered with roar_01–03 (OGA rubberduck), Kokoro laugh and shouts pitched down |
| Cutscene voices (`Cutscene.voice`, silent under a skip, D310) | Mayor Hall: the collector climbs out; LabCells: the prisoner's shout, the djinn rises; LabBoss: the djinn takes the cloak | `brass_collector_roar`, `prisoner_incantation`, `fire_djinn_laugh` | Voice | Kokoro (Q64 invented words) |
| Dash | `PlayerMover.start_roll` | `dash` | SFX | cloth (RPG Audio) |
| Draw / sheathe (D268) | `combat_state_changed` | `draw`, `sheathe` | SFX | drawKnife; beltHandle (RPG Audio) |
| Skill wind-up / release / interrupt (D271) | new `skill_cast_started`, `skill_used`, `skill_interrupted` | `cast_<skill>_windup`, `cast_<skill>_release`, `cast_interrupt` | SFX | forceField, thrusterFire, laserSmall/Large, explosionCrunch (Sci-Fi); glitch (Interface) |
| Footsteps | `PlayerMover` stride on floor | `step_<surface>` | SFX | footstep_snow (sand), _concrete (stone), _wood (Impact) |
| Jump / land | `PlayerMover._handle_jump`, `player_landed` | `jump`, `land` | SFX | cloth; footstep heavy-pitched |
| Ladder | `PlayerMover._climb` per rung | `ladder` | SFX | impactWood light (Impact) |
| Room change into/out of an interior | `scene_loaded` + rooms table | `door` | SFX | doorOpen/doorClose (RPG Audio) |
| Pickup / coins / level up | `item_added`, `coins_changed` (up), `player_leveled_up` | `pickup`, `coin`, `level_up` | SFX | handleSmallLeather; handleCoins (RPG Audio); confirmation (Interface) |
| UI focus / press / tab / slider | Maaacks `ProjectUISoundController` | — | SFX | tick, click, switch, scroll (Interface) |
| Ambience per room | `scene_loaded` + rooms table | `amb_<name>` loop | Ambience | wind (OGA bashar3a), dungeon_ambient (OGA jaggedstone), crowd_shouting (OGA starninjas), low-rumbling (OGA musheran) |
| Dialogue typing | `dialogue_box.text_shown`, cloud `type_out` | babble of the speaker | Voice | synthesised per character |
| Greeting | `NpcBase._on_interacted` | `greet_<character>` | Voice | Kokoro |
| Companion assist | `assist_called` | `call_<companion>` | Voice | Kokoro |

Rooms table (in `sound_events.json` → `rooms`): Canyon — canyon echo (dungeon ambience + wind, sand steps);
DesertRoad, LaboratoryOutside — desert wind, sand; Village, CityGates — wind + light crowd, sand; City — crowd,
stone; MayorHall — interior, crowd low, wood; Laboratory — interior, lab hum, stone.

## Slices

### Slice 1 — buses, one playback path, combat ✅ `597306ca`
`default_bus_layout.tres`, `AudioManager.gd` (`play`, drop dead code), `Resources/Data/sound_events.json`,
`Scripts/Systems/SoundHooks.gd` (combat moved out of `VFXHooks.gd`), `EventBus.skill_cast_started`,
`Assets/Audio/SFX/*` + README; `UI/verify_audio.gd` [1] buses + sliders, [2] each combat event → stream + bus.

### Slice 2 — world ✅ `075ec3b4`
Footsteps / jump / land / ladder / dash in `PlayerMover`, pickups / coins / level-up / door / ambience in `SoundHooks`,
UI streams on the Maaacks controller, `Assets/Audio/Ambience/*` + README; `verify_audio` [3].

### Slice 3 — voices ✅ `271401f4` (+ B78 fix `7c7e2aa2`: a hit without a source broke damage listeners)
`Scripts/Tools/audio/make_babble.py` (numpy, stdlib wave), `Scripts/Tools/audio/make_voices.py` (Kokoro in a
scratch venv), grunts / roars cut and processed; `Assets/Audio/Voice/*` + README; babble hook in
`DialogueManager`, greeting in `NpcBase`, assist calls and boss voice in `SoundHooks`; `verify_audio` [4] babble while
typing, [5] greeting on a talk the hero starts and none on a cutscene dialogue, [6] boss voice.

### Slice 4 — montage, exe, queue ✅
Scratch WAV montage, exe rebuild, BACKLOG / queue update.

## Listening checklist for Sapega

Audio cannot be captured as an image. Play the exe (or the montage `fb26_montage.wav`) and check:

1. Canyon: wind with a hollow echo under the music; sand-crunch steps while running, softer at a walk.
2. Village / City Gates: wind and a distant crowd; City: crowd louder, stone steps; Mayor Hall: a door on entering, wooden steps.
3. Laboratory: a low hum; stone steps; a door on entering.
4. A 3-swing combo: three whooshes; a punchy impact on each hit; a heavier one on the finisher.
5. Heavy attack (R / right mouse): blade draw + Kusakam's "Hah!", heavy impact.
6. Block (Ctrl) a bandit: metal clang; parry: louder clang + bell.
7. Getting hit: soft thud + a short pain grunt; dying: a longer cry.
8. Bandits: a grunt on some swings, pain grunts, a death cry; the tank is deeper, the fast one higher.
9. Double dash: two cloth whooshes. Fight starts: blade drawn; 3 s after: a belt sound (sheathed).
10. Skills: Healing Palm hum → chime; Fire Strike crackle → whoosh; Electric Strike zaps → burst; hit during the
    wind-up → a glitch "fizzle".
11. Dialogue: each character "babbles" in their own pitch while text types; Kusakam's cloud talk too.
12. Talk to the grandfather, the blacksmith, the merchant (E): a short English greeting before the menu; the first
    meeting with the grandfather (cutscene) has no greeting.
13. Call a companion (assist): their battle call.
14. Menus: a tick on focus (pad D-pad too), a click on press.
15. Sliders: "Sound Effects" at 0 silences all of the above except music.

## Order and dependencies

`1 → 2 → 3 → 4`; 2 and 3 are independent of each other.

## Out of scope for this pass

- ~~Boss cutscene lines~~ — done in queue row 9.8 (D310): roars, the djinn's laugh, the prisoner's incantation.
- Gamepad rumble on hits — item 24.
- Positional (2D) sound, music ducking under voice — ponytail, add when a room grows past the camera.
- A separate Voice / Ambience slider — needs a Figma row and Sapega's word (D274).
- Ukrainian spoken lines (D277 chose English; a Piper voice with a release-clean licence if Sapega wants them).
- Voiced monologue bubbles (D178 pops a whole line at once, so there is no typing to babble on).
- Starting items given at a new game play the pickup sound once each (harmless; silence them if it grates).

## As built — where each piece lives

| Piece | File |
|---|---|
| Buses | `default_bus_layout.tres` (Master, Music, SFX, Ambience → SFX, Voice → SFX) |
| Playback, tables | `Scripts/Systems/AudioManager.gd` (`play`, `play_loop`, `room`), `Resources/Data/sound_events.json` (`events`, `rooms`, `voices`, `enemy_voice_pitch`) |
| Event → sound | `Scripts/Systems/SoundHooks.gd` (child of the AudioManager autoload) |
| Steps, jump, dash, ladder | `Player/Components/PlayerMover.gd` `_footsteps`, `step_distance` / `walk_step_distance` / `ladder_step_distance` exports |
| Room change | `EventBus.room_entered` from `Game.init_room` |
| Cast wind-up | `EventBus.skill_cast_started` from `PlayerCombat.begin_cast` |
| Babble | `DialogueManager._on_letter_shown` (box), `speech_bubble.typed` (cloud talk) → `SoundHooks.letter` |
| Greeting | `NpcBase._on_interacted` → `SoundHooks.greet(character_id)`; `character_id` set on blacksmith, merchant, Village `OldManQuest` |
| UI | `project_ui_sound_controller.tscn` streams, `process_mode` Always (menus pause the game) |
| Asset builders | `Scripts/Tools/audio/build_audio.py` (combat, world), `make_babble.py`, `make_voices.py` |
