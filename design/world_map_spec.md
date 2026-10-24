---
type: spec
status: approved
tags: [map, ui, figma]
---

# World map, two levels — the approved frames

Sapega, 2026-10-24: «карта рівень 1, рівень 2 — це супер, робіть, тут нічого не потрібно домальовувати». Approves
[[world_structure_plan]] slices 2 and 3 as drawn. The cloud cannot reach Figma, so the frames are copied here.

| Level | Figma | Picture in the repo |
|---|---|---|
| 1 — the world | `539:6472` (page «🗺️ Карта регіонів») | `design/refs/map_level1_world.png` |
| 2 — one location | `539:6615` | `design/refs/map_level2_location.png` |

Both frames are clones of the existing `menu-world-map` (`94:609`): the same Game Menu sidebar, the same top and bottom
bars, the same illustrated parchment map (`UI/World Map Base` `68:1900`) under the content. Coordinates below are in the
1920×1080 frame.

## Level 1 — the world (the World Map tab opens here)
- The illustrated map as today, **without** the MetSys grid and **without** the 13 old named markers and the old legend
  (they had no data, D40/D41).
- **One pin per location** in `locations.json` (D618). A pin is a dark rounded plate (fill `#121217` at 90 %, radius 18,
  1.5 px gold `#D9AD4D` border) holding a dot (18 px) and two lines: the name in Cormorant Garamond Bold 24 and a state
  line in Inter Bold 12, white.
  - **Here** (the hero's location): red dot and a 3 px red border `#D9261A`, state line «ви тут» / "you are here".
  - **Visited:** gold dot, state «відвідано» / "visited".
  - **Not reached yet:** grey dot, grey name, plate at 60 %, state «закрито» / "locked".
  - Drawn positions: Canyon of Whispers (1380, 430) on the painted «Canyon of Whispers»; the City (1200, 260) by
    Al-Kazar; the Laboratory (1580, 120) by «The Laboratory». The position belongs in `locations.json` (a new
    `map_pos` field), not in the scene.
- **Location card** bottom-left (368, 790): dark plate (`#121217` at 88 %, 1 px gold border, radius 6, padding 20/16):
  the selected location's name (Cormorant Garamond Bold 30, gold) and one Inter 16 line, white:
  «Досліджено N% · Скрині a/b · Секрети c/d» and «A — відкрити карту локації».
- Pad/keys: left/right (or stick) moves between pins, A / Enter opens level 2 for the selected pin. Only reached
  locations open.

## Level 2 — one location
- The same menu frame; over the illustrated map a parchment veil (`#EDDBB8` at 93 %), so the room drawing reads.
- Title block (the existing `map-title-block`): the location name in capitals, gold; the line under it
  «Карта локації · B — до карти світу».
- **Rooms are drawn from MetSys data** for that location's rooms only (`LocationDB.location(id).rooms`), one 150×84 box
  per MetSys cell (keeps the 864×480 cell shape), laid out by the cells' map coordinates:
  - a cell the hero has **explored**: fill `#D1B585`, ink border `#3D2917` 3 px;
  - a cell **not explored but next to an explored one through an open border** (the hero has seen its entrance): no
    fill, the ink border at 45 %, 2 px, dashed 10/8;
  - any other cell: not drawn.
  - The room name (Cormorant Garamond Bold 18, ink) in the top-left of the room's first cell, only for explored rooms.
    `?` for a dashed one.
- **Icons** (26 px circles, 2 px ink border, a white glyph): hero (red `#BF1A0D`), meditation spot / save point
  (blue `#4073BF`), chest (gold; dimmed once opened), locked door (grey), quest giver «!» (orange `#E6991A`),
  exit to another location «→» (ink). Placed at the object's position inside its cell.
- Passages between cells that are a ladder, a drop or a well get a small ink-red label (Inter Bold 13): «↕ драбина»,
  «↓ спуск», «↓ криниця».
- **Legend** bottom-right (1500, 700): the same dark plate as the card: «ЛЕГЕНДА», then «■ кімната, де ти був»,
  «┅ бачив вхід, ще не заходив», «☗ ти ✦ медитація (збереження)», «▣ скриня ⚿ замкнено ! завдання», «→ вихід в іншу
  локацію».
- B / Esc goes back to level 1. When the hero opens the tab, it may open straight on level 2 of the current location;
  Sapega's frames do not say — keep level 1 first (the tab is called World Map) and record it as a routine call.

## Not in these frames
- Counting secrets needs data: a secret is a room or object marked as one. If nothing marks them yet, show only what
  exists (explored %, chests) and record the gap; do not invent secrets.
- Text is uk/en through the localisation tables like the rest of the menu.
