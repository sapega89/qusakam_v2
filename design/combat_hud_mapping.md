# Combat HUD — DEV SPEC mapping

**Figma:** `Game Scene / Combat HUD` `434:6556` (new — the `Game Scene` section
was empty at the Phase 1 audit, which is why the hotbar phase was halted).

## The five blocking questions — all resolved ✅

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | Exactly 4 active skill slots? | **Yes — 4** | `Skill Hotbar` `434:6628` contains `Hotbar Bind 1…4`, each a `UI/Skills/Slot` 48×48 |
| 2 | Position and anchors | **Bottom-centre** | `Bottom HUD Row` at `(24, 969)` 1872×87, `justify-between`. Hotbar at local x 812.5 → absolute 836.5, width 248 ⇒ centre **960.5** = screen centre. Row bottom 1056 ⇒ 24px bottom margin |
| 3 | BAG a separate system? | **Dropped — not built** | Confirmed separate from the hotbar in Figma (`Bag Section` `434:6593`), then **removed from scope by design decision**: this is a metroidvania with a dedicated Inventory screen and no separate consumable quickbar. `Bag Section` is an obsolete design artifact. |
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
| `Bag Section` | **obsolete** — not implemented, will not be | — |
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

Out: BAG/consumables (**dropped by design decision — no quickbar in this game**),
passive effects, JP rewards,
production skills, targeting system, controller bindings.

## HUD v2 hero panel (D453, D476, D485): measured spec, 2026-10-23

**Figma:** component `UI/HUD/HeroPanel v2` `501:6611`, 520 × 162. In-game placement: frame `492:6543`, top left. Shot: `design/shots/figma_hero_panel_v2.png`. The stamina row was added on 2026-10-23 for D537, and the plate grew by 22 px. The hotbar v2 (`497:6587`) is built separately, after Q86.

**Assets:** all in `SampleProject/Assets/UI/HUD/hero_panel/`.

| File | Size | What it is |
|---|---|---|
| `plate.svg` | 470 × 144 | Dark gradient plate with a gold rim and an arrow tip on the right |
| `portrait_ring.svg` | 104 × 92 | Gold hexagon ring around the portrait |
| `level_diamond.svg` | 30 × 30 | Gold level badge |
| `curl.svg` | 44 × 44 | D476 ornament. On the panel's right end it is mirrored: `flip_h`, which is Figma's rotate 180 + flip Y |

**Layout:** positions are in Figma px from the component's top left. Scale them the way the current vitals panel is scaled (see *Player Vitals Panel*). Fonts follow the in-game font rule (`UITokens.font_px(…, true)`).

| Element | Position, size | Look |
|---|---|---|
| Plate | (0, 14) 470 × 144 | `plate.svg` |
| Portrait | (14, 40) 104 × 92 | The hero portrait (`CharacterManager.HERO_PORTRAIT`, D534), nearest-filtered, clipped to the hexagon `M26 2H78L102 46L78 90H26L2 46Z` over a `#15141C` fill. `portrait_ring.svg` sits on top |
| Level badge | (51, 118) 30 × 30 | `level_diamond.svg`. The level number is centred: Cormorant Bold 15, `#0B0B10` |
| Name | (134, 22) | "KUSAKAM": Cormorant Bold 26, `#F1D77A`, uppercase, letter spacing 3 |
| Class | right edge at x 440, top 30 | Cormorant Regular 16, `#CFC8B0`. The sworn oath's name; "Holy Warrior" before the oath (as Status, D532) |
| Rule | (134, 56) 300 × 1 | Accent `#D4AF37` at 60 % |
| HP row | label y 62, bar y 66, h 14 | Fill `#2ECC71` |
| SP row | label y 84, bar y 88, h 14 | Fill `#3498DB` |
| ST row | label y 106, bar y 110, h 14 | Fill `UITokens.STAMINA_FILL` (`#E67E22`) |
| XP row | label y 126, bar y 132, h 8 | Fill accent `#D4AF37` |
| Curl | (462, 64) 44 × 44 | `curl.svg`, `flip_h` |

**Rows:**
- Each label is at x 134: Cormorant Bold 16, `#CFC8B0`.
- Each bar is at x 168, 200 wide.
- Each value is right-aligned to x 442: Cormorant SemiBold 18, white. The XP value is 16, `#E8E2CC`.
- The bar background is black at 60 % with a 1 px `#8A6F22` border. The fill is inset 1 px.
- HP, SP and ST have a 3 px top highlight of white at 25 %. XP has no highlight.
- Colours go through `UITokens`: reuse the existing tokens, and add one only where none exists.

**Not in this panel:** the potion line ("Q Potions ×N", D538). It moves to the hotbar v2 (Q86). Until then it stays where `cloud/combat-player` put it.
