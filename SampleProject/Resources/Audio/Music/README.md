# Music

Six looping tracks from the Desert Music pack (AlkaKrab — licence PDF in
`assets/Desert Music pack/`), copied here because `assets/` is not in git.
Imported with `loop=true`.

Each room scene and `MainMenu.tscn` has a `Music` AudioStreamPlayer (bus `Music`,
autoplay); the `ProjectMusicController` autoload picks it up and switches tracks
between scenes. To change a room's track, change that node's `stream` in the editor.

| Scene | Track |
|---|---|
| Main Menu, Laboratory, Laboratory Outside | dunes_of_silence.ogg |
| City, Mayor's Hall | scorchlight_mirage.ogg |
| Desert Road | whispers_in_the_sand.ogg |
| Canyon | canyon_echoes.ogg |
| City Gates | sunblade_horizon.ogg |
| Village | ash_and_oasis.ogg |

Provisional (Q38 — Sapega: "connect it somehow for now"). Checked by `verify_music.gd`.
