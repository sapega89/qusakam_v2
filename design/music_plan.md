---
type: plan
status: planned
blocked-by: [D414]
---

# Music — plan

> **2026-10-22 — slice 3, fight music (D414, #34):** planned; the tracks wait on Sapega's pick from the CC0 candidates.
>
> **Q38 answered 2026-10-21: keep the current tracks for now.** Slice 2 (a per-room table) is not needed; the `Music` nodes in the rooms and `MainMenu.tscn` stay as built.

**✅ Built 2026-10-14, differently from the slices below.** The maaacks
`ProjectMusicController` autoload already plays any autoplay `AudioStreamPlayer` on the
`Music` bus and blends between scenes — so each room and `MainMenu.tscn` got a `Music`
node, no `MusicPlayer.gd` and no `music.json`. Six loops copied to
`SampleProject/Resources/Audio/Music/` (`assets/` is gitignored), imported with
`loop=true`. Track per room: provisional, see that folder's `README.md` (Q38).
Test: `verify_music.gd` — every MetSys room and the menu has a looping in-project track.

Original survey, kept for the record:

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

### Slice 3 — fight music (D414, 2026-10-22)
What exists: the maaacks controller blends to any stream — `ProjectMusicController.play_stream(stream)`
(`addons/maaacks_menus_template/base/nodes/autoloads/music_controller/music_controller.gd:133`); the hero's
fight state is `EventBus.combat_state_changed(in_combat)` (`PlayerCombat.gd:260-269`, 3 s linger `COMBAT_LINGER`);
the boss fights start in `LabBoss._fight()` (`Scripts/Gameplay/Scenes/LabBoss.gd:100`) and `MayorHall._fight()` (`MayorHall.gd:99`), end on
the boss's death (`_on_djinn_died`, `_on_collector_died`) or the hero's defeat (`defeat_handler`). Missing: nothing switches music inside a room (`grep play_stream SampleProject` → 0).
- **3a — mechanism.** ✅ **Built 2026-10-22 (D419, `cloud/fight-music`)**; placeholders until 3b; open: B116. Was: `SoundHooks` (already listens to `combat_state_changed`, `SoundHooks.gd:22`): fight on → the
  battle stream; fight off → back to the room's `Music` node stream. A boss fight → the boss stream until the boss
  dies or the hero is defeated (one signal from the boss rooms, or `BossEnemy` engage/death — pick the one both bosses
  already share). Tracks: two paths in `Resources/Data/sound_events.json` → `music` (`fight`, `boss`); a missing file is
  an error (D135). Crossfade: the controller's own fade (`fade_in_duration` / `fade_out_duration`).
- `verify_music.gd`: `combat_state_changed(true)` → the controller plays the battle stream, `(false)` → the room's;
  a boss fight → the boss stream, its end → the room's.
- **3b — content (after Sapega's pick):** the two CC0 files into `SampleProject/Resources/Audio/Music/` with their
  licence lines in `README.md` there; `loop=true` on import.
  **Candidates (checked 2026-10-22, all CC0 on their pages; Sapega listens and picks one per row):**
  | Use | Track | Author | Files |
  |---|---|---|---|
  | battle | [Medieval battle](https://opengameart.org/content/medieval-battle) | RandomMind | mp3, wav |
  | battle | [Swordfight](https://opengameart.org/content/swordfight) | Kistol | ogg (orchestral) |
  | boss | [Dramatic Boss Encounter](https://opengameart.org/content/dramatic-boss-encounter) | cynicmusic | wav |
  | boss | [Boss Battle #2 (Symphonic Metal)](https://opengameart.org/content/boss-battle-2-symphonic-metal) | nene | zip: opening + loop (names inside swapped) |
  | boss | [Heavy Boss Battle 1](https://opengameart.org/content/heavy-boss-battle-1) | MintoDog | mp3, ogg, loopable |

  Not offered: [Negev Fight](https://opengameart.org/content/desert-calmness-and-fighting-orchestral-141) (desert
  orchestral, CC0 on the page, but built on a film adventurer's theme — the CC0 cannot clear that melody). The only
  middle-eastern battle loops found are CC-BY 3.0 (Hitctrl, [The Eternal Sands](https://opengameart.org/comment/111407)) — they
  need a credit line, outside D414.

## Order and dependencies

`1 → 2`. Slice 1 can ship now; slice 2 waits on Q38. Slice 3: `3a → 3b`; 3a can ship before the tracks are picked (test streams), 3b waits on D414's pick.

## Out of scope for this pass

- Ambient volume row (D46 — no ambient system).
- ~~Per-fight / boss music switching — part of Q38's answer, not assumed here.~~ → slice 3 (D414).
