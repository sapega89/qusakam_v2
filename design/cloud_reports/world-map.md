---
type: cloud-report
branch: cloud/world-map
date: 2026-10-26
tags: [cloud, map, ui]
---

# Cloud report: world-map (the two-level World Map, D458 / D487 / D565, world_structure_plan slices 2 and 3)

**Summary.** The code for both levels is written and pushed, but **none of it has been run**. This run could not get Godot, because the cloud permission check blocked the 4.6.2 download from ROUTINE_RULES setup step 2 as external code.
So these steps are still **open**: regenerating `GameUITheme.tres` from the new tokens, `verify_world_map`, the full suite, and the `capture_world_map` shots. Until the theme is regenerated, the map's new theme types (`MapPin*`, `MapCard*`, `MapRoomName`, `MapPassage`, `MapVeil`, `MapLegendTitle`) are missing from the `.tres`, and the map draws unstyled.
Built: `map_pos` in data (first run), a `LocationMap` model read from MetSys and the room scenes, level 1 (pins, card, keys), level 2 (cells explored / seen / hidden, names, icons, passages, legend, B back), tokens, theme builder, uk/en keys, the test and the capture script.
Secrets: nothing in the data marks one, so the card omits the count (Q below). Wells: none in the data, so there is no «↓ криниця» label (Q below).
D-ID text: D713 (OVERRIDE, the frames approved), D714 (ROUTINE CALL, the build). Qs: Q98 secrets, Q99 wells. No B rows fixed.
Full suite: **not run** (no Godot). Next step on the laptop: regenerate the theme, then run `verify_world_map`, `verify_game_ui_theme`, `verify_locale`, `verify_responsive`, `verify_full_regression` and `capture_world_map`.

## What was done

| Step | Files |
|---|---|
| Continued `cloud/world-map` (first commit `map_pos`), merged `origin/feature/backlog` (no conflicts) | — |
| `LocationDB.map_pos(id)` | `SampleProject/Scripts/Systems/LocationDB.gd` |
| `LocationMap` — one location's MetSys cells, `state()` (EXPLORED / SEEN / HIDDEN), explored %, chests a/b, markers, passages, exits, the hero | `SampleProject/Scripts/Systems/LocationMap.gd` (new) |
| `LockedDoor.is_locked(gate_id, room, node_name)` — the `_ready` rule without the scene | `SampleProject/Scripts/Gameplay/LockedDoor.gd` |
| Map tokens + theme types | `SampleProject/UI/Tokens/UITokens.gd` (World Map section, `FIGMA_FONT_TYPES`), `SampleProject/UI/build_game_ui_theme.gd` `_world_map()` |
| Map icon (drawn glyphs; also the legend's room swatches) | `SampleProject/UI/Components/map_icon.gd` (new) |
| Pin plate | `SampleProject/Scenes/Menus/Game/world_map_pin.tscn` (new) |
| The tab: Frame in 1920×1080 coordinates, Level1 (Pins, Card), Level2 (Veil, Rooms/Grid, Legend), TitleBlock | `SampleProject/Scenes/Menus/Game/metsys_map_component.tscn`, `SampleProject/Scripts/Menus/Game/metsys_map_component.gd` (rewritten; MetSys `MapView`, panning and the EXPLORED panel are gone) |
| uk/en keys (pin states, card, hints, legend, passages, 11 room titles) | `uk.po` + `en.po` (via `Scripts/Tools/po_sync.py`) |
| Test and capture | `SampleProject/UI/verify_world_map.gd` (rewritten), `SampleProject/UI/capture_world_map.gd` (new) |

`SampleProject/Maps/MapData.txt` and the room scenes are untouched.

### How the data flows
- **Rooms of a location:** `locations.json rooms` → `MetSys.map_data.get_cells_assigned_to("<room>.tscn")`. Nothing is written per room, so the Region v2/v3 rebuild only has to keep `locations.json` and MapData in step.
- **Cell state** (`LocationMap.state`): explored = `MetSys.is_cell_discovered(c, false)`. Seen = not explored, but a neighbouring explored cell of the same location has a border towards it that is not a wall (MapData border ≠ 0; −1 is open inside a room, > 0 is a passage). Everything else is hidden.
- **Objects:** each room scene is instantiated off-tree (no `_ready`) and walked. A node's position is turned into a MetSys cell plus a fraction inside the cell (`in_game_cell_size` 864×480, origin = the room's smallest cell, as `RoomInstance.min_cell`).
  - `Chest` → chest; opened = `room_state opened_<name>` (the same key `Chest` uses), drawn dimmed.
  - `SavePoint.gd` → meditation / save.
  - `LockedDoor` and a `RoomDoor` with a closed `gate_id` → locked.
  - `RoomDoor` whose `target_room` is in another location → exit.
  - `NpcBase` that is `_here()` and has a `quest_marker()` → quest «!».
  - `Ladder.gd` (top + `height`) → the cell borders it crosses.
- **Exits** also come from MapData: a non-wall border from a location cell to a cell of another location.
- **Passages:** a non-wall border between a cell and the one under it. It is a ladder when a `Ladder` crosses it, otherwise a drop. The label shows when both cells are drawn and at least one is explored.
- **Card:** `Explored N% · Chests a/b`, where N% = explored cells of the location ÷ its cells.

## D-ID text (next free numbers; the orchestrator renumbers)

| ID | Kind | Text |
|---|---|---|
| D713 | OVERRIDE | **Sapega approved both World Map frames as drawn** (2026-10-24, «карта рівень 1, рівень 2 — це супер, робіть, тут нічого не потрібно домальовувати»): level 1 the world, Figma `539:6472` (`design/refs/map_level1_world.png`); level 2 one location, Figma `539:6615` (`design/refs/map_level2_location.png`). They override the old `menu-world-map` (`94:609`) look: the MetSys grid, the 13 named markers without data and the old legend are gone (D40/D41). Spec: `design/world_map_spec.md`. |
| D714 | ROUTINE CALL | **The two-level World Map as built** (D458, D487, D565, D713; `cloud/world-map`). `metsys_map_component.tscn/.gd` (node name kept for `game_menu.tscn` and the tests) draws a 1920×1080 frame over the menu's illustrated map. It no longer has a MetSys `MapView`. **Level 1:** one pin per `locations.json` location at its `map_pos` (top-left of the plate). Pin states: here (red plate and dot, «ви тут»), visited (≥ 1 explored cell; gold, «відвідано»), locked (plate at 60 %, grey name and dot, «закрито»). Left / right walks the pins in screen order left to right. Left from the leftmost pin and B return to the tabs, as in every tab. The hero's location is selected first, and a selected visited pin gets a 3 px gold border. A locked pin can be selected (the card shows it) but does not open. The card shows `Досліджено N% · Скрині a/b` and «A — відкрити карту локації», with the hint line hidden for a locked location. **Level 2:** the menu's map under a `#EDDBB8` 93 % veil, and the title = the location in capitals plus «Карта локації · B — до карти світу». The location's cells (150×84 each) are fitted to the area x 340–1480, y 160–990: centred, and scaled down only when they do not fit. Explored cells are filled with a 3 px ink border; seen cells get a 2 px ink border at 45 %, dashed 10/8; hidden cells are not drawn. A room name goes in its first explored cell (top row, then left), only for explored rooms; a room seen but never entered gets «?». Icons are 26 px circles at the object's place in its cell, in explored cells only. The exception is locked doors and exits, which also show in seen cells, because they are visible from the doorway as in the frame. Passage labels are «↕ драбина» and «↓ спуск» at the bottom of the upper cell. The legend is at (1500, 700). B / Esc returns to level 1, and the arrows keep the focus on the map. **The tab always opens on level 1** (spec: the frames do not say; the tab is called World Map). The party column is hidden while the tab is shown, as in the frames and like Status. **Type:** the frames' Inter lines use Cormorant Garamond, the game's only font. All map text keeps its Figma size (types in `FIGMA_FONT_TYPES`, no ×1.25 from D166), because it sits in fixed plates and 150×84 cells. The pin border is 2 px (StyleBoxFlat takes whole pixels; Figma has 1.5). The glyphs (☗ ✦ ▣ ⚿ ! →) are drawn as shapes, since Cormorant has none of them. **Room titles** use the scene name as words (`LizardCave` → «Lizard Cave»), as `location_title` did before D618. uk: Каньйон, Дім діда, Печера ящерів, Розпис дракона, Табір бандитів, Підйом на Месу (from the frame); Зала мера, Підвал брами, Біля лабораторії, Камери лабораторії, Серце лабораторії (drafts). **No secrets count** (Q98) and **no «↓ криниця»** (Q99). |

## Questions (non-blocking, filed with defaults)

| ID | Where | Question | Default |
|---|---|---|---|
| Q98 | World Map card (D714) | The frame's card shows «Секрети c/d». Nothing in the data marks a secret: no field in `locations.json`, no node type, no MapData symbol. `BreakableWall` hides passages but is not marked as a secret. What is a secret: a room flagged in `locations.json` (`secret_rooms`), a node (`SecretArea` that counts when entered), or a breakable wall that counts when broken? | The card shows only explored % and chests until something marks secrets. |
| Q99 | World Map level 2 passages (D714) | The frame labels one passage «↓ криниця» (well). No room has a well object or a well flag. Should wells exist as a passage kind (a `Well` node, like `Ladder`)? | Only «↕ драбина» (Ladder nodes) and «↓ спуск» (any other open vertical border). |

## Visible differences from the two frames (expected, not seen: no shots this run)

These come from reading the spec and the code against the pictures, not from rendered shots. The capture has to run before any of them is confirmed.

| # | Level | Difference | Triage |
|---|---|---|---|
| 1 | both | Inter (state line, card, legend, passages) → Cormorant Garamond | D714 (no Inter font in the project) |
| 2 | 1 | Pin border 2 px instead of 1.5 px | D714 |
| 3 | 1 | The card has no «Секрети c/d» | Q98 |
| 4 | 1 | The selected visited pin has a 3 px gold border (the frame shows no selection; there the selection is the card) | D714 |
| 5 | 1 | Canyon pin: the frame plate is wider than the text, and ours fits the text. The plate's top-left sits on `map_pos`, so the dot lines up but the right edge differs | check in the shot |
| 6 | 2 | Room layout, names and icons follow today's MapData and rooms (Canyon of Whispers has 8 rooms: no «Горище діда» or «Старі руїни»), so the room boxes cannot match the frame one to one | approved: D713 «draw whatever rooms the data has» |
| 7 | 2 | No «↓ криниця» | Q99 |
| 8 | 2 | «↓ спуск» shows on every open vertical border without a ladder, including inside one tall room (the frame shows three labels in total) | D714; look at the shot, might need a B if it clutters |
| 9 | 2 | Glyphs are drawn shapes (pawn, 8-point star, box, padlock, «!», arrow), not font glyphs | D714 |
| 10 | 2 | Legend rows use the same drawn icons; the swatches are 14–16 px | D714 |
| 11 | both | The bottom-bar hint is «Left / Right — choose a location. A — open its map.» / «B — back to the world map.» (the frame shows «Select a category.») | D714 (hints say what works) |

## Tests and shots
- `verify_world_map.gd` [1]–[9]: level 1 on open, no MapView, party column hidden; pins = locations at `map_pos`, with here / visited / locked states and looks; card counts from the data, no secrets line; the explored / seen / hidden rule checked cell by cell, plus an in-memory probe (explore a hidden cell, its open neighbours turn seen, a wall reveals nothing; restored afterwards); right / left / A on a locked pin / A on the hero's pin; level 2 title, names of explored rooms only, the hero icon, icons only in drawn cells, the grid inside its area, the legend, no room name hard-coded in the code; B back, arrows keep the focus, B does not close the menu; uk text; the party column round trip (Status → World Map); a clean rebuild on reopen. **Not run.**
- `capture_world_map.gd` → `design/shots/world_map/level1_world.png`, `level2_location.png`, and `*_vs_figma.png` (Figma left, game right). It explores the first three rooms of the hero's location and the City's first room, in memory only. **Not run.**
- Full suite: **not run.**
