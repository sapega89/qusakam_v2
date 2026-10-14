---
type: mapping
status: done
figma: "tutorial-content 135:1260"
tags: [tutorial, misc]
---

# Tutorial — Figma → Godot mapping

Decided by Sapega 2026-10-12: **D126** ([[figma_decision_register]] §9). Fixes
[[BUGS]] **B2**. File key: see memory / `zZet0eKcVhXSwQUNZsrOlO`.

## Two levels (D126)

1. **Topic list** — `130:1172`, a panel in the Game Menu centre
   (`tutorial_component.tscn` in `ContentRoot`, shown by `game_menu._show_only()` from
   Misc → Tutorial; Misc stays pressed). Header "Tutorial" (`SettingsHeading` 36) +
   "Topic" (`SettingsEyebrow`) + rule; rows = `ListRow` from the `%TopicRow` template
   (D117, `UIRows.fill`). Panel = `SidePanel` (surface, 1 px border) — Figma pads 48.
   Bottom bar hint "Select a tutorial topic.". Not built: the 36 px icon squares
   (empty placeholders in Figma too).
2. **Topic window** — `135:1260`, full-screen, opened from a row through
   `ModalLayer.show_custom_modal()`; the running game is never unloaded (B2). Arrows /
   LB·RB switch topics; B/Esc closes it back to the list (game menu `_unhandled_input`).

Shots: `shots/tutorial_list_1920.png`, `shots/tutorial_topic_1920.png`.
Tests: `verify_misc_destinations.gd` [6].

## Element mapping (`135:1260`)

| Figma | Godot | Style |
|---|---|---|
| background `#111118` full-bleed | `Background` Panel | new `ScreenPanel` (bg `BACKGROUND`) |
| 4 × `ornate-corner` 24 px, diamond 16 px, 40 px from edges | `Corner*` TextureRect | `Assets/UI/Icons/diamond_sm.svg` (main menu's diamond) |
| `border-top-line` / `border-bottom-line` y 51 / 1027, x 64→1856 | `TopRule`, `BottomRule` HSeparator | new `FrameRule` (1 px `BORDER`) |
| title Bold 48 white | `Title` Label | `StatusName` (Bold `SIZE_NAME` 48) |
| `title-gold-divider` 1.5 px accent | `TitleRule` HSeparator | new `AccentRule` |
| body Regular 22, line-height 1.5 | `Body` Label, autowrap | new `TutorialBody` (`SIZE_TUTORIAL_BODY` 22) |
| screenshot 1000×480, 2 px `border` | `ShotFrame` PanelContainer › `Shot` TextureRect | new `TutorialShot`; hidden when a topic has no image |
| "Press the [RB] Button to …" Regular 18 + badge | `HintBar` › `HintPre` / `KeyBadge` / `HintText` | `SettingsRowLabel`-size regular → new `TutorialHint`; new `KeyBadge` + `KeyBadgeLabel` (surface, 1.5 accent border, Bold 14) |
| layout: pt 80, px 120, gap 40 | `Margin` + `Page` VBox | scene constants (as other screens) |
| Bottom Bar | shared `bottom_bar.tscn` | context hint = topic navigation |

## Data — `Resources/Data/tutorial.json`

Only topics about systems that exist (D126). Texts are Claude's English drafts from
the real bindings (`project.godot` [input], `Game.tscn` map window, `SavePoint.gd`) —
edit freely.

| Topic | Grounded in |
|---|---|
| Basic Controls | `move_left/right` A·D·arrows, `jump` Space·W, `attack` left mouse, `interact` E, Esc = game menu (`Game.gd:133`) |
| The Map | minimap top-right (`Game.gd:308`), M toggles the full map and pauses the player, arrows pan (`Game.tscn` MapWindow script) |
| Saving Your Progress | `SavePoint.gd`: E at a save point → Save Slot Selection; no auto-save today (D91 never built) |
| The Journal | Game Menu → Journal (D120–D125) |

Images: in-game screenshots taken by `UI/capture_tutorial_shots.gd` into
`Assets/UI/Tutorial/` (re-run it when the game's look changes).

Not taken from Figma: its 12 topic titles (Boost Mode, Jobs, Fast Travel, Side Stories…
describe systems the game does not have).

## Found on the way

- `Game.tscn` map-window script toggles position tracking on **raw `KEY_D`**, which is
  also `move_right` — every step right flips it. Parked as [[BUGS]] O15.
