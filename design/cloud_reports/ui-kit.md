---
type: report
status: done
tags: [cloud, ui, modal, shop, b119, d433]
---

# Cloud report: `cloud/ui-kit` (2026-10-23)

**Summary.** **B119 fixed (remove the row).** The shared modal scene now follows the kit's `UI/Modal/Confirm`: padding 40 × 28, gap 16, a 1 px accent rule 300 px wide under the title, body Regular 14, and buttons stacked in a 300 px column with a 12 px gap. Each button is a 260 × 36 `UI/HexButton` (`hex_button.svg` / `hex_button_selected.svg`) with an uppercase SemiBold 18 label at tracking 2. The selected button gets the accent fill, the `›` pointer at x 49 and the white D329 ring. Every confirm modal goes through this one scene.
**D433 done.** An unaffordable row now greys its price as well as its name. On the selected (accent) row both use `TEXT_DISABLED`, which has 4.93:1 contrast against `ACCENT`.
D-ID text (proposed): **D477**, **D478** (§3). `verify_game_ui_theme` prints `ALL CHECKS PASSED`.
Full suite: `Scripts/Tools/run_verify.sh` → `SUITE: ALL PASS` (93 scripts).
Not done: nothing from the task. Open item: the Figma MCP was not available in this run, so I compared against B119's listed values and the earlier shots, not a fresh frame.

Branch `cloud/ui-kit` from `origin/feature/backlog` @ `6182a265`. Commits: `91961275` (B119 + D433), `f16db89d` (tests).
Note: the prompt said the register ends at D439, but `feature/backlog` already has D440–D442, so the new numbers start at D477.

## 1. B119: confirm modals → UI/Modal/Confirm

- `SampleProject/UI/Tokens/UITokens.gd` (end of file): the `MODAL_*` block. It has padding, gap, rule (1 px, 300), column 300, button gap 12, button 260 × 36, `MODAL_BUTTON_POINT` 17 (a texture margin, so the pointed ends never stretch), pointer x 49 / 16, `SIZE_MODAL_BODY` 14, `SIZE_MODAL_BUTTON` 18, `MODAL_BUTTON_SPACING` 2, and the three SVG paths.
- `SampleProject/UI/build_game_ui_theme.gd`:
  - `ModalPanel` content margins are now 40 / 28. The panel stays on opaque `BACKGROUND` (D195).
  - `_modal_kit()` (l. 746) adds these types: `ModalColumn` (VBox, gap 16), `ModalButtons` (VBox, gap 12), `ModalRule` (an HSeparator with a 1 px accent StyleBoxLine), `ModalBody` (Regular 14), and `ModalButton` / `ModalButtonOn`.
  - `ModalButton` / `ModalButtonOn` use a StyleBoxTexture of the outline or fill SVG (`_hex_box()`, l. 794) and a SemiBold font at `spacing_glyph` 2. The text is white on the outline and `ON_ACCENT` on the fill, and the chevron icon only shows on `On`. The right content margin is 49 + 16 + 8, so the label is centred on the button.
  - The focus box is the shared `_focus_ring(…, on_accent=true)` with corner radius 18 and `corner_detail` 1, so the white 2 px ring follows the pointed ends (D329). `verify_game_ui_theme` [3c] accepts it.
- `SampleProject/Scenes/UI/modal_dialog.tscn`: `Rule` sits between `Title` and `Description`. `Buttons` is a `VBoxContainer` (was `HBoxContainer`), and the template buttons carry `ModalButton` and the chevron icon.
- `SampleProject/Scripts/UI/modal_dialog.gd`:
  - `_ready()` sets the rule and column widths from tokens.
  - `_style_button()` (l. 90) sets 260 × 36 and swaps `ModalButton` ↔ `ModalButtonOn` on focus. Mouse hover grabs focus, the same as shop rows.
  - `_label()` translates the key and then uppercases it, because auto-translate would not find "YES". Godot's Button has no `uppercase` property.
  - `modal_templates.gd` needed no change: every template already goes through `buttons`.
- Covered, since every modal uses this one scene: buy, craft (and Cannot Craft), enchant, overwrite save, delete slot, both quit modals, item pickup / You obtained, Game Saved / Save Failed, and Cannot Use.

## 2. D433: unaffordable price greys; readable on the selected row

- `UITokens.SHOP_TEXT_DISABLED_ON_ACCENT := TEXT_DISABLED` (#404040, Figma Disabled), plus `MIN_TEXT_CONTRAST := 4.5`. Against `ACCENT`: `TEXT_MUTED` is 2.73:1 (the old, barely readable grey), `TEXT_DISABLED` is 4.93:1, and `ON_ACCENT` is 8.94:1, so the selected disabled row still looks dimmer than an available one. This reuses an existing token instead of adding a new colour.
- Builder: `ShopRowDisabledOn`, `ShopRowPriceDisabled`, `ShopRowPriceDisabledOn` (l. 952).
- `SampleProject/UI/Components/shop_row.gd` `_apply_style()`: on a disabled row, the name and price take `…Disabled` / `…DisabledOn`. Count and detail now follow the selected state too, so the count is dark on the accent and no longer white on gold.
- Side effect: a row that is not sellable in Sell mode now shows its "—" price in grey too. It already used the same disabled branch.

## 3. D-ID text (proposed)

- **D477 | OVERRIDE→KIT | Confirm modals are the kit's UI/Modal/Confirm (B119; Sapega, 2026-10-23).** Every modal from `modal_dialog.tscn` uses:
  - padding 40 × 28 and gap 16;
  - title Regular 22, then a 1 px accent rule 300 px wide, then body Regular 14;
  - buttons stacked in a 300 px column with a 12 px gap. Each is a 260 × 36 `UI/HexButton` (`hex_button.svg` outline / `hex_button_selected.svg` fill) with an uppercase SemiBold 18 label at tracking 2.

  The focused button is the selected one: accent fill, dark text and the `›` pointer at x 49. On top of it the D329 ring is drawn white and follows the pointed ends. The panel stays opaque (D195). Theme types: `ModalColumn`, `ModalRule`, `ModalBody`, `ModalButtons`, `ModalButton`/`On`. Verified by `verify_shop` [4a0] and `verify_save_load`.
- **D478 | GAP | The disabled text colour on an accent fill is `TEXT_DISABLED` (completes D433).** An unaffordable shop row greys its name and its price: `TEXT_MUTED` on the dark row, and `TEXT_DISABLED` (#404040, 4.93:1, at least `MIN_TEXT_CONTRAST` 4.5) on the selected accent row. Count and detail follow the selected state. Verified by `verify_shop` [4b2].

## 4. B rows fixed

- **B119**: fixed. Remove the row.

## 5. Tests (RESULT lines)

- `verify_game_ui_theme`: `=== ALL CHECKS PASSED ===` (theme regenerated, 234 types).
- `verify_shop`: `RESULT: ALL PASS`.
  - New [4a0] checks, 15 in all: padding, opaque panel, gap, the rule (right under the title, 1 px accent, 300 px), body 14, the VBox column at 300 px with gap 12, No sitting under Yes at the same x, 260 × 36, YES/NO uppercase, tracking 2 / size 18, the selected fill vs the outline texture, the pointer only on the selected button at x 49, the white D329 ring, and selection following focus.
  - [4b2] adds the grey price, the `…DisabledOn` variations on the accent fill, contrast of `name 4.93:1, price 4.93:1`, and a check that the selected disabled row still differs from `ShopRowNameOn`.
- `verify_save_load`: `RESULT: ALL PASS`. The B34 size check now expects `SIZE_MODAL_BUTTON`, plus new checks for the rule under the title and for stacked uppercase `["YES", "NO"]`.
- Updated helpers that click modal buttons by text: `verify_shop._press_modal`, `verify_save_load._press_modal` (both compare against `text.to_upper()`), and `verify_main_menu` (`"CANCEL"`).
- All 25 verify scripts that open a modal passed before the full run. Full suite: `SUITE: ALL PASS`.

## 6. Shots (xvfb, 1920 × 1080; before | after crops)

- `design/shots/ui_kit_buy_confirm_compare.png`: `capture_shop.gd`, buy confirm at quantity 3.
- `design/shots/ui_kit_item_pickup_compare.png`: `capture_interaction.gd`, the misc one-button modal ("You obtained:").
- `design/shots/ui_kit_save_overwrite_compare.png`: `capture_save_load.gd`, "Overwrite Save?".
- `design/shots/ui_kit_shop_unaffordable_compare.png`: `capture_shop.gd` at 25 gold. Prices now grey. The held Iron Ingot row (30 > 25) shows #404040 on the accent.
- Refreshed: `shop_buy_confirm_1920.png`, `shop_buy_confirm_qty3_1920.png`, `shop_buy_unaffordable_1920.png`, `item_pickup_modal_1920.png`, `save_load_overwrite_1920.png`.
- The captures' `SCRIPT ERROR … health_changed / global_position` lines come from the capture scripts themselves (no player in the scene). They appear in the before run too.
