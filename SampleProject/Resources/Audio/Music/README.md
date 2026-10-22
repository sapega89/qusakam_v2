# Music

Six looping tracks from the Desert Music pack (AlkaKrab — licence PDF in
`assets/Desert Music pack/`), copied here because `assets/` is not in git.
Imported with `loop=true`. (`time_for_adventure.mp3` is MP3 — no converter on hand; also `loop=true`.)

Each room scene and `MainMenu.tscn` has a `Music` AudioStreamPlayer (bus `Music`,
autoplay, `process_mode` Always — keeps playing under pause); the `ProjectMusicController` autoload picks it up and switches tracks
between scenes. To change a room's track, change that node's `stream` in the editor.

| Scene | Track |
|---|---|
| Main Menu | time_for_adventure.mp3 — Brackeys platformer assets (CC0, music by Brackeys, Sofia Thirslund); Sapega, 2026-10-15 |
| Laboratory, Laboratory Outside | dunes_of_silence.ogg |
| City, Mayor's Hall | scorchlight_mirage.ogg |
| Desert Road | whispers_in_the_sand.ogg |
| Canyon | canyon_echoes.ogg |
| City Gates | sunblade_horizon.ogg |
| Village | ash_and_oasis.ogg |

## Fight music (D414, music_plan slice 3)

While the hero fights (`EventBus.combat_state_changed`) `SoundHooks` asks `ProjectMusicController.play_stream` for
the battle track; during the two boss fights (`EventBus.boss_fight_changed` from `LabBoss` / `MayorHall`) the boss
track wins over it; when both end, the room's own `Music` stream comes back. Paths: `Resources/Data/sound_events.json`
→ `music`.

| Use | Track | Status |
|---|---|---|
| fight | time_for_adventure.mp3 (the menu's track) | **placeholder** — the CC0 pick is slice 3b (Sapega) |
| boss | sunblade_horizon.ogg (City Gates' track) | **placeholder** — the CC0 pick is slice 3b (Sapega) |

Provisional (Q38 — Sapega: "connect it somehow for now"). Checked by `verify_music.gd`.
