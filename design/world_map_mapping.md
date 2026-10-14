# World Map — Figma → Godot mapping

**Figma:** `menu-world-map` `94:609` · **Godot:** `metsys_map_component.tscn/.gd`

MetSys is the behavioural source of truth; this phase restyles the existing
map, it does not rebuild it.

## Element mapping

| Figma element | Existing Godot feature | Visual change required |
|---|---|---|
| `world-map-base` (illustrated parchment, full-bleed) | `base_menu.tscn → MapBackground` already renders `menu_map_background.jpg` under the dim overlays | none — reuse the shell background |
| `map-title-block` `64:441` — Bold **44** accent uppercase + 32px rule · Regular 18 sub · 32px rule, gap 2/16, drop shadow, centred | none | **add** (static chrome) |
| Map viewport (`center-content` 1600×1016) | `MetSys.make_map_view()` grid render | **restyle** bounds + remove local black stylebox |
| Player marker | `MetSys.add_player_location()` — real position | keep as-is |
| Explored percentage | `update_percent()` → `MetSys.get_explored_ratio()`, `"%03d%%"` | **restyle** — Figma has no such element (see deviation) |
| `map-legend` `64:501` — 208×196 surface panel, 1px border, padding 24, gap 12; "LEGEND" Bold 14 accent; 5 rows City/Oasis/Ruins/Camp/Cave | **no backing data** | see NEEDS DESIGN DECISION |
| 13 named markers (`marker-*`, fixed x/y, dot + label, one `Current Location` tag) | **no backing data** | see NEEDS DESIGN DECISION |
| `Bottom Bar` | shared `bottom_bar.tscn` | reuse, hints reflect real actions |
| Sidebar + top bar | shared menu shell | already implemented |

## Behaviour preserved (untouched)

Explored rooms, player marker, map centring (`update_offset()` recentres on
`MetSys.get_current_flat_coords()`), `MetSys.map_updated` refresh, explored
ratio, `set_map_active()` lifecycle, all MetSys data.

## Input — fixed

`_input()` compared raw `event.keycode == KEY_LEFT/RIGHT/UP/DOWN`, which the
brief forbids. Replaced with the existing `ui_left/ui_right/ui_up/ui_down`
actions so the project's rebinding/settings system applies. Panning behaviour is
otherwise identical.

Bottom-bar hints list only what is actually implemented: pan and back.

## NEEDS DESIGN DECISION

### 1. Named location markers
Figma places **13 markers at fixed pixel positions** (`marker-sapphire-city`,
`marker-lizard-cave`, …) with a `Current Location` tag on one. The project has
**no named-location dataset** — MetSys stores a grid of room cells, not points
of interest with display names or world coordinates.

Implementing them would require inventing both the data and a
world→screen projection. Per §2 ("do not invent custom markers"), **not built**.

Unblocking needs either a location dataset (id, display name, category, map
coordinates) or a decision to drop the markers.

### 2. Legend categories
The legend keys five categories — City, Oasis, Ruins, Camp, Cave — with distinct
dot shapes/colours (`#d4af37` diamond, `#3b82f6` square, `#e11d48` diamond,
`#d4af37` small square, `#8b5cf6` square). These describe the markers above, so
the legend is blocked on the same missing dataset. A legend explaining symbols
that are not on screen would be actively misleading, so it is **not built**.

### 3. Illustrated map vs. MetSys grid
Figma draws a hand-illustrated parchment world. MetSys renders a procedural grid
of discovered room cells. These are different artifacts: the illustration cannot
show real exploration state, and the grid cannot match the illustration's
geography. This phase keeps the **MetSys grid as the live map** and the
illustration as the background art behind the menu chrome.

Resolving properly is a design call: either (a) keep MetSys as the map and treat
the illustration as decoration, or (b) author a real world map with coordinates
and project MetSys discovery onto it.

## Deviation — explored percentage

Figma shows no explored-percentage element, but the feature exists and works.
Per "do not remove existing functionality", it is **kept** and restyled with
theme tokens rather than deleted.
