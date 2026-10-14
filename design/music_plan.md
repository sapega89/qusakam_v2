---
type: plan
status: planned
blocked-by: [Q38]
---

# Music — plan

**Nothing wired.** No scene plays music; the old `MusicManager` autoload was
fallback-only dead code and is removed (D131). 2026-10-12.
Figma: no design exists (music has no UI beyond the existing Music volume row).

## What exists today

| Thing | Where | State |
|---|---|---|
| Music tracks, 6 × (loop + full) | `assets/Desert Music pack/Loops/mp3/`, `Tracks/{mp3,ogg,wav}/` — Dunes of Silence, Scorchlight Mirage, Whispers in the Sand, Canyon Echoes, Sunblade Horizon, Ash and Oasis | ✅ imported, unused. Licence: `AlkaKrab Music License Info.pdf` |
| One more track | `assets/brackeys_platformer_assets/music/time_for_adventure.mp3` | ✅ imported, unused |
| `SampleProject/Resources/Audio/Music/` | `README.md` only — lists `menu.ogg`, `main_theme.ogg`, `boss.ogg`, none of which exist | ❌ |
| `music_config.json` | `Resources/Data/` | ❌ never existed |
| Music volume | `AudioManager.apply_volume_settings()` (`Systems/AudioManager.gd:94`), bus `Music` | ✅ works — volume only, nothing to play |
| `MusicManager` autoload | removed 2026-10-12 (git history) | had no callers; built a hard-coded default config and fell back to `main_theme` at runtime (D135 forbids both) |

Checked: `grep -rn "MusicManager\.\|play_scene_music" SampleProject` → 0 callers
after `GameMusicManager.gd` (itself unreferenced) was deleted.

## Missing entirely

- A scene → track table (data, `Resources/Data/music.json`).
- A player: one `AudioStreamPlayer` on the `Music` bus that crossfades on room change.
- The hook: `Game.room_loaded` → look up the room's track → play it.
- Menu music for `MainMenu.tscn`.

## Decisions required

1. **Which track plays where** — Canyon, Village, Desert Road, City Gates, City,
   Mayor's Hall, Laboratory, Laboratory — Outside, Main Menu, boss fight.
   **GAME DESIGN DECISION REQUIRED** — Q38. Blocks slice 2 only.
2. Loop files (`Loops/`) or full tracks (`Tracks/`)? Recommendation: `Loops/` for
   rooms (they are made to repeat), full track for the menu. Part of Q38.

Per D135, a room with no track of its own is assigned one **explicitly** in the
table; a missing file is an error, never a silent substitute.

## Slices

### Slice 1 — player + table, no content
- `SampleProject/Scripts/Systems/MusicPlayer.gd` (one player, crossfade), autoload `MusicPlayer`.
- `Resources/Data/music.json` — `{ "rooms": { "<scene basename>": "<res path>" }, "menu": "<res path>" }`, empty until Q38.
- `Game.room_loaded` → `MusicPlayer.play_for_room(map.scene_file_path)`; a room missing from the table → `push_error`.
- `SampleProject/UI/verify_music.gd` — a room in the table starts its stream; a room not in the table errors.
- Commit.

### Slice 2 — content (after Q38)
- Fill `music.json`; move the chosen files under `SampleProject/Resources/Audio/Music/`.
- Update `README.md` there to the real list.
- Extend `verify_music.gd`: every room in `Maps/MapData.txt` has an entry.
- Commit.

## Order and dependencies

`1 → 2`. Slice 1 can ship now; slice 2 waits on Q38.

## Out of scope for this pass

- Ambient volume row (D46 — no ambient system).
- Per-fight / boss music switching — part of Q38's answer, not assumed here.
