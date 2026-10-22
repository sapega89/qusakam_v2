---
type: report
tags: [cloud, music]
---

# fight-music — D414, music_plan slice 3a (GitHub #34)

**Summary**
- Done: fight music switching. `combat_state_changed(true)` → battle track; a boss fight (`LabBoss._fight`, `MayorHall._fight`) → boss track, wins over the battle track; the end (boss's death or hero's defeat) → battle track if the hero is still in combat, else the room's own `Music` stream. All through `ProjectMusicController.play_stream`, no second music player.
- Not done: slice 3b (Sapega's CC0 pick). **Both tracks are placeholders:** fight → `time_for_adventure.mp3` (menu track), boss → `sunblade_horizon.ogg` (City Gates track); named in `sound_events.json` → `music._comment` and `Resources/Audio/Music/README.md`.
- D-ID text: *D414 slice 3a built — `EventBus.boss_fight_changed(arena, active)` from LabBoss/MayorHall; `SoundHooks._update_music()` picks boss > fight > room and plays it with `ProjectMusicController.play_stream`; tracks in `sound_events.json → music {fight, boss}`, a missing file asserts at start (D135); the controller's fades stay 0 (hard cut, same as room changes).*
- B rows fixed: none. Proposed new B row below (hero stays "in combat" through MayorHall's post-fight cutscenes).
- Full suite: `SUITE: 1 FAIL` — verify_lab_boss "claws, fireball and pillar all come" (the djinn's random move pick gave no fireball in 40 s); the same test is ALL PASS on the run before and on a re-run → flaky, not music. Every other script PASS.

## What changed
- `Resources/Data/sound_events.json` → `"music": {"fight", "boss"}` — full `res://` paths (music lives outside `Assets/Audio/`).
- `Scripts/Systems/AudioManager.gd` — `music` dictionary, loaded in `_ready()`; a missing file → assert (D135).
- `Scripts/Core/EventBus.gd` — `boss_fight_changed(arena: Node, active: bool)`. Chosen over `BossEnemy` engage/death because the hero's defeat also has to end it, and both rooms already own that moment (`defeat_handler`).
- `LabBoss.gd` — emits `true` at the end of `_fight()`, `false` in `_on_hero_defeated()` and `_on_djinn_died()`. `MayorHall.gd` — `true` in `_fight()`, `false` in `_end_fight()` (covers win and loss).
- `Scripts/Systems/SoundHooks.gd` — "Музика бою" section: `_update_music()`. Tracks the `play_stream` player it started (`_music_override`); when the controller is playing anything else (a new scene's `Music` node took over), that stream is taken as the room's track. An arena that leaves the tree mid-fight (teleport, quit to menu, load) ends the boss fight (`tree_exiting`); a new game resets `_in_fight` (old hero gone without a `false`).
- The maaacks controller frees the room's own `Music` node when it switches; going back is `play_stream(room stream)`, so the room track restarts from 0.

## Tests
- `verify_music.gd` (ALL PASS): fight in → battle; out → room; boss → boss; a fight starting and ending inside the boss fight → boss stays; boss end → room; boss during a fight → boss, its end → battle, then room; arena freed mid-fight → next fight gets the battle track. Every step also checks exactly one music player is playing.
- `verify_lab_boss.gd` (ALL PASS): boss track in the played, skipped and loaded fights; the hall's own Music (`dunes_of_silence.ogg`) back after the loss (cloak → Game Over) and after the win.
- `verify_mayor_hall.gd` (ALL PASS): boss track in the played, skipped and loaded fights; after win and loss the boss track is off and the battle track plays, because the hero is still in combat (see below).

## Open notes (non-blocking, for the orchestrator)
- **Proposed B row:** in MayorHall, after the collector dies or beats the hero, `PlayerCombat.in_combat()` stays true through the victory/defeat cutscene (the hero is held in `Hurt`, `COMBAT_LINGER` never runs out), so the battle track — and the drawn weapon — last until the transport to the lab. Music follows the signal as specified; the fix belongs to `PlayerCombat._track_combat` (outside this task).
- Fades: `project_music_controller.tscn` has `fade_in_duration = fade_out_duration = 0`, so fight music cuts in hard. Raising them would also change every room transition — a product call if the cut sounds wrong once the real tracks are in (slice 3b).
- A room whose own track equals a placeholder (City Gates ↔ boss, menu ↔ fight) sounds unchanged; irrelevant once 3b lands.
