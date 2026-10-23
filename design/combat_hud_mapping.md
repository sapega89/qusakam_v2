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

**Figma:** component `UI/HUD/HeroPanel v2` `501:6611`, 520 × 198 (the plate and, under it, the F and Q chips). In-game placement: frame `492:6543`, top left. Shot: `design/shots/figma_hero_panel_v2.png`. There is no stamina row: stamina is out for now (D551). The 8-slot hotbar v2 (`497:6587`, D549) is specified below and built in the same routine.

**Assets:** all in `SampleProject/Assets/UI/HUD/hero_panel/`.

| File | Size | What it is |
|---|---|---|
| `plate.svg` | 470 × 122 | Dark gradient plate with a gold rim and an arrow tip on the right |
| `portrait_ring.svg` | 104 × 92 | Gold hexagon ring around the portrait |
| `level_diamond.svg` | 30 × 30 | Gold level badge |
| `curl.svg` | 44 × 44 | D476 ornament. On the panel's right end it is mirrored: `flip_h`, which is Figma's rotate 180 + flip Y |
| `chip.svg` | 52 × 46 | Small hexagon for the F and Q chips |

**Layout:** positions are in Figma px from the component's top left. Scale them the way the current vitals panel is scaled (see *Player Vitals Panel*). Fonts follow the in-game font rule (`UITokens.font_px(…, true)`).

| Element | Position, size | Look |
|---|---|---|
| Plate | (0, 14) 470 × 122 | `plate.svg` |
| Portrait | (14, 29) 104 × 92 | The hero portrait (`CharacterManager.HERO_PORTRAIT`, D534), nearest-filtered, clipped to the hexagon `M26 2H78L102 46L78 90H26L2 46Z` over a `#15141C` fill. `portrait_ring.svg` sits on top |
| Level badge | (51, 107) 30 × 30 | `level_diamond.svg`. The level number is centred: Cormorant Bold 15, `#0B0B10` |
| Name | (134, 22) | "KUSAKAM": Cormorant Bold 26, `#F1D77A`, uppercase, letter spacing 3 |
| Class | right edge at x 440, top 30 | Cormorant Regular 16, `#CFC8B0`. The sworn oath's name; "Holy Warrior" before the oath (as Status, D532) |
| Rule | (134, 56) 300 × 1 | Accent `#D4AF37` at 60 % |
| HP row | label y 68, bar y 72, value y 66, h 14 | Fill `#2ECC71` |
| SP row | label y 92, bar y 96, value y 90, h 14 | Fill `#3498DB` |
| Curl | (462, 53) 44 × 44 | `curl.svg`, `flip_h` |
| F chip, the assist | (134, 136) 52 × 46 | `chip.svg` with the next or active companion's portrait, the D525 states (ready, active with the pulse, cooldown dimmed with the seconds) and the refused-press shake. Key badge (the hotbar's `key_badge.svg`) at (149, 176) with "F" |
| Q chip, potions | (200, 136) 52 × 46 | `chip.svg` with the potion icon. The count sits in a pill at the chip's bottom right, (238, 160) 23 × 20: `#0B0B10` at 90 %, a 1 px `#8A6F22` border, radius 10, text Cormorant Bold 16 `#F1D77A`. Key badge at (215, 176) with "Q" |

**Rows:**
- Each label is at x 134: Cormorant Bold 16, `#CFC8B0`.
- Each bar is at x 168, 200 wide.
- Each value is right-aligned to x 442: Cormorant SemiBold 18, white.
- The bar background is black at 60 % with a 1 px `#8A6F22` border. The fill is inset 1 px.
- HP and SP have a 3 px top highlight of white at 25 %. XP is not in this panel: it is the full-width bar below (D552).
- Colours go through `UITokens`: reuse the existing tokens, and add one only where none exists.

**The potion and the assist live here** (Sapega, 2026-10-23: «QF прибери з панелі», meaning out of the hotbar). The old "Q Potions ×N" text line (D538) becomes the Q chip, and the assist slot leaves the hotbar for the F chip.

## HUD v2 hotbar, 8 slots (D453, D476, D549): measured spec, 2026-10-23

**Figma:** component `UI/HUD/Hotbar v2` `497:6587`, 780 × 124, at the bottom centre. It was redrawn from 4 slots to 8 on 2026-10-23 and holds only the 8 skills; the Q and F chips are on the hero panel.
- Shot: `design/shots/figma_hotbar_v2_8.png`.
- The glow of a ready slot: `design/shots/figma_hotbar_slot_ready_2x.png`.

**Assets:** in `SampleProject/Assets/UI/HUD/hotbar/`.

| File | Size | What it is |
|---|---|---|
| `plate.svg` | 700 × 96 | The plate |
| `slot.svg` | 64 × 56 | Skill slot hexagon |
| `slot_ready.svg` | 83 × 75 | Gold ring of a ready slot, including the glow margin. The SVG filter is stripped (Godot drops it), so the soft gold glow is made in the engine, matching the reference shot |
| `cooldown.svg` | 64 × 56 | Dark overlay |
| `sp_gem.svg` | 18 × 18 | Badge for the SP cost |
| `key_badge.svg` | 22 × 22 | Gold diamond under each slot |
| `centre_diamond.svg` | 16 × 16 | Divider between the two groups |

The curls are `../hero_panel/curl.svg`: the left one as drawn, the right one mirrored.

**Layout:** positions are in Figma px from the component's top left.

| Element | Position, size |
|---|---|
| Plate | (40, 22) 700 × 96 |
| Skill slots 1–4 | x 78, 154, 230, 306; y 38; 64 × 56 each |
| Centre diamond | (382, 62) 16 × 16 |
| Skill slots 5–8 | x 410, 486, 562, 638; y 38 |
| Curls | Left at (2, 48), 44 × 44. Right mirrored, with its right edge at x 778 |

**Inside each skill slot:**
- **Icon:** 28 × 28 at (+18, +14). The D550 painted icon once it exists; until then, today's icon.
- **SP cost gem:** at (+50, −6), with the cost: Cormorant Bold 13, white.
- **Key badge:** at (+21, +55), with the key: Cormorant Bold 14, `#0B0B10`.
- **Cooldown:** `cooldown.svg` over the slot, with the seconds centred: Cormorant Bold 22, white.
- **Ready:** `slot_ready.svg` plus the gold glow.
- **Empty slot:** the hexagon with nothing in it.

**Keys:**
- Keyboard: 1–8.
- Gamepad: extend today's pad scheme to 8. D549 suggests two sets of four, behind LT and RT.
- The badges show the pad glyphs while a pad is in use, as the current hotbar does.

**Behaviour:** everything `skill_hotbar.gd` does today stays. `SkillManager.SLOT_COUNT` goes from 4 to 8.

**Not here:** the potion (Q) and the assist (F). They are chips under the hero panel.

## HUD v2 XP bar (D552): spec, 2026-10-23

**Figma:** component `UI/HUD/XP Bar` `515:6662`, 1920 × 10. Its in-game placement is in `hud-combat` `492:6543`, along the bottom edge of the screen. Shot of the whole HUD: `design/shots/figma_hud_v2_context.png`.

**Look:**
- The bar runs the full width of the screen at the very bottom, 10 px tall at 1080p.
- Background: black at 60 %, with a 1 px top rim in `#8A6F22`.
- Fill: accent gold `#D4AF37`, the share of XP towards the next level, with a 2 px white highlight at 25 % along its top.
- **No label and no numbers** (Sapega: «без підпису, що це XP, всі і так знають»). At the level cap (D541) it stays full.
- It is drawn by the engine, with no texture: a `ProgressBar` with theme styleboxes and `UITokens` colours.

**HUD placement at 1080p:**
- Hero panel at (24, 24), top left.
- Hotbar centred: x 570, y 942, so 4 px above the XP bar.
- XP bar at y 1070.
