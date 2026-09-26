# Combat HUD — DEV SPEC mapping

**Figma:** `Game Scene / Combat HUD` `434:6556` (new — the `Game Scene` section
was empty at the Phase 1 audit, which is why the hotbar phase was halted).

## The five blocking questions — all resolved ✅

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | Exactly 4 active skill slots? | **Yes — 4** | `Skill Hotbar` `434:6628` contains `Hotbar Bind 1…4`, each a `UI/Skills/Slot` 48×48 |
| 2 | Position and anchors | **Bottom-centre** | `Bottom HUD Row` at `(24, 969)` 1872×87, `justify-between`. Hotbar at local x 812.5 → absolute 836.5, width 248 ⇒ centre **960.5** = screen centre. Row bottom 1056 ⇒ 24px bottom margin |
| 3 | BAG a separate system? | **Yes** | `Bag Section` `434:6593` is a distinct sibling on the left of the same row, with its own `Consumable Slots Track` (4 binds, gap 10). No shared component with the skill hotbar |
| 4 | SP placement | **Top-left vitals panel, middle row** | `Player Vitals Panel` `434:6558` at `(24,24)` 360×162 — rows HP / **SP** / XP |
| 5 | All skill-slot visual states | **4 states shown + empty** | see table below |

## Skill Hotbar — measured spec

`Skill Hotbar` `434:6628`: bg `color/surface`, **1px `color/border-strong` (accent)**,
padding 10, gap 12, `flex items-center`.

Per slot (`Hotbar Bind N`): column, gap 4 — a 48×48 slot above a bind badge.

| State | Slot | Bind badge | Source |
|---|---|---|---|
| **Selected / highlighted** | bg `background`, **2px accent border**, glow `0 0 3px rgba(212,176,56,0.3)` | **accent bg, `#111118` text** | Bind 1 |
| **Equipped (normal)** | bg `background`, 1px `#3a3a42` | `#2a2a35` bg, 1px border, white text | Bind 2 |
| **Cooldown** | icon visible + full-slot overlay `rgba(17,17,24,0.75)` with remaining time, **Bold 16 accent** (`"3s"`) | as normal | Bind 3 |
| **Unavailable / disabled** | whole bind group at **opacity 0.40** | as normal | Bind 4 |
| **Empty** | inner icon box `#2a2a35` 28×28 centred, no real icon | as normal | Binds 1/2/4 inner |

Bind badge text: Bold **11px**, `px 6`, `py 1`.
Cooldown icon example: `icon/skills/steal` 18×18 at inset 14.

## Player Vitals Panel — measured spec

`434:6558`: bg `color/surface`, 1px `color/border`, padding 16, gap 12, 360×162.

- **Header**: name Bold **18** accent, uppercase, letter-spacing 1 · `Level Badge HUD`
  accent bg, `px 6 py 2`, Bold 11, `#111118` text
- **Rule**: 1px full width
- **Vitals Bars**: gap 6; each row = label `w 30` SemiBold 16 · `UI/ResourceBar`
  **200×8** (bg `background`, 1px border) · value `w 80` SemiBold 14, right-aligned

| Row | Fill | Label/value colour |
|---|---|---|
| HP | `#2ecc71` | text-primary |
| **SP** | `#3498db` | text-primary |
| XP | `accent` | text-**secondary** |

## Godot mapping

| Figma | Godot | Data source |
|---|---|---|
| `Skill Hotbar` | new `hotbar.tscn` in `Game.tscn/UICanvas` | `SkillManager` equipped loadout |
| slot icon | `SkillDefinition.icon` | missing ⇒ placeholder box (D28 convention) |
| cooldown overlay + timer | `SkillManager.get_remaining_cooldown()` | **no second timer in the HUD** |
| unavailable state | `SkillManager.can_use_skill()` verdict | not re-implemented in UI |
| bind badge `1…4` | new input actions `skill_slot_1…4` | see Input below |
| `Player Vitals Panel` → SP row | `SkillManager.get_current_sp()/get_max_sp()`, `sp_changed` | event-driven |
| `Player Vitals Panel` → HP row | existing `HealthComponent` | existing |
| `Player Vitals Panel` → XP row | existing `XPManager` | existing |
| `Bag Section` | **out of scope** — consumables, separate system | — |
| `Quest Info Panel`, `Currency & Settings` | **out of scope** this phase | — |

## Input

`project.godot` currently defines only `move_left/right/up/down`, `jump`,
`attack`. Figma shows bind badges labelled **1, 2, 3, 4**, so four actions
`skill_slot_1…4` are added with keys **1–4**, matching the on-screen badges.
Registered in `project.godot` like every other action, so the existing
rebinding/settings system sees them. No `Input.is_key_pressed(KEY_*)` in
gameplay code.

Controller bindings are **not** invented — Figma shows numeric badges only.
Recorded as a follow-up.

## Targeting

Unchanged from the vertical slice: `SkillManager.use_skill(id, target, source)`
takes an explicit target. The HUD does not pick targets. Runtime target
selection remains **GAME DESIGN DECISION REQUIRED** — no nearest-enemy heuristic
is invented, since none exists elsewhere in the combat architecture.

## Scope for this phase

In: `equipped_skills` model + loadout API, 4-slot hotbar, slot states, cooldown
presentation, SP display, input actions.

Out: BAG/consumables, quest panel, currency panel, passive effects, JP rewards,
production skills, targeting system, controller bindings.
