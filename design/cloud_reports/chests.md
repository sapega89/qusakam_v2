---
type: cloud-report
branch: cloud/chests
date: 2026-10-21
---
# Cloud report: chests (BACKLOG 33)

Branch `cloud/chests`, based on `origin/feature/backlog` because `cloud/integration` did not exist yet.
Built with Godot 4.6.2 headless on Linux. There is no window, so there are no captures.

**Art check:** the chest frames are in the tree (`SampleProject/Assets/Props/Chest/Closed|Opening|Open`, A1).
**Kusakam's Raise pose is not** (`SampleProject/Sprites/Player/Raise/` is missing). Per the task, the chest is built
with the existing held pose (`Idle`) and leaves one hook for Raise (see below). Plan: [[chests_plan]].

## What was built
- **Scene** `SampleProject/Objects/Chest.tscn`:
  - `Area2D` root.
  - `Sprite`: an `AnimatedSprite2D` with `closed`, `opening` (3 frames, 8 fps) and `open`, drawn at ×1.5 like the hero. The origin is the chest's floor point.
  - `Interactable` ("Open"), the shared D74 component, so it opens with E or the pad button `interact` is bound to.
  - `Found`: a top-level `Sprite2D` 72 px above the hero for the item icon.
- **Behaviour** `SampleProject/Scripts/Gameplay/Chest.gd`:
  - `:55` interact adds every item in `contents` to the bag first (D88 path 3), disables the prompt and writes `opened_<node>` into the room state (`:66`, D152, the same mechanism as ItemPickup D298, saved by `FlagsModule.room_state`).
  - `:71` the lid plays `opening` and then `open`.
  - The hero is held (`set_movement_enabled(false)`) in `HERO_POSE` (`:17`), with the first item's icon above his head for `RAISE_SECONDS` = 1.2 s (`:19`, `:80`).
  - He is then released and the "You obtained:" modal shows one `<Item> × <N>` line per item (`:90`).
  - `:35` an opened chest loads open with no prompt. Unknown item ids or empty contents give `push_error` and a disabled chest. There is no fallback.
- **Raise hook:** when `Raise/1–3.png` land, add an `Animation "Raise"` to `Player.tscn` and set `Chest.HERO_POSE := &"Raise"`. Nothing else changes, and the verify follows the constant.
- **Modal** `SampleProject/Scripts/UI/modal_templates.gd:110`: `items_obtained(lines: Array[String])`. This is byte-identical to the function `cloud/dialogue-ui` adds for the gift popup, so the two branches merge cleanly.
- **Placement** `SampleProject/Maps/DesertRoad.tscn:321`: `Chest_CaravanLedge` at (4144, 256) on the caravan rock. It replaces `Pickup_CaravanLedge` (Mana Crystal × 1) and holds **Mana Crystal × 2**.
- **Notes:**
  - `design/chests_plan.md` is new.
  - `design/world_expansion_plan.md` ledge C line now mentions the chest.
  - `Scripts/Tools/godot_locked.sh` and `run_verify.sh` are now `+x`, the same change as cloud/b82-b10. Without it the suite cannot run on Linux.

## Decisions (agent call, Sapega to confirm)
- **D-new (Chest):** A chest opens with `interact` (E / pad).
  - Its contents go into the bag at once (D88 path 3).
  - The lid plays Closed → Opening 1–3 → Open.
  - Kusakam stands held with the found item's icon over his head for 1.2 s, then the "You obtained:" modal lists every item as `<Item> × <N>`.
  - An opened chest stays open, with no prompt, across room reloads and save/load (room state `opened_<node>`, like D298).
  - Until the Raise frames exist, the held pose is `Idle`. *(agent call, Sapega to confirm)*
- **D-new (placement):** The first chest replaces the DesertRoad **caravan ledge** pickup (D298 ledge C). It holds **Mana Crystal × 2**: the ledge's crystal plus one, because a chest should feel like more than a ground pickup. Like D298, it only uses items that have a drawn icon. The dune (Iron Ingot) and mesa (Herb × 2) ledges keep their pickups, so all three D88 paths exist on the road.
  - No chest in the Village centre: that house is BACKLOG 38 and is not built yet.
  - No chest in the Laboratory: rows 9.5–9.8 are rebuilding those rooms, and what a prison chest holds is a story call.

  *(agent call, Sapega to confirm)*

## New bugs
- **B-new:** the Raise pose is not wired yet. During the chest raise the hero shows `Idle`, not the raise-overhead pose BACKLOG 33 asks for. **Where:** `Chest.gd:17`. **Cause:** art A1 `hero_raise` has not landed in `feature/backlog`. **Fix:** the two-step hook above. Severity: visual.
- No game bugs found in the systems I touched.

## Verifies (RESULT lines)
| verify | result |
|---|---|
| chests (new) | `RESULT: ALL PASS` |
| road_sections | `RESULT: ALL PASS` |
| desert_road | `RESULT: ALL PASS` |
| interaction | `RESULT: ALL PASS` |
| save_load_room | `RESULT: ALL PASS` |
| room_state | `RESULT: ALL PASS` |
| **full suite** `Scripts/Tools/run_verify.sh` | **`SUITE: ALL PASS`** (70/70) |

`verify_chests.gd` uses real input. It covers:
- The caravan chest is closed and its prompt reads "Open".
- The E key event that `interact` is bound to opens it: the lid animates, the hero is held in `HERO_POSE`, the icon shows above him, and Mana Crystal × 2 lands in the bag. The modal lists it, pad A closes the modal, and the hero walks again. A second press gives nothing.
- After a room reload the chest is open, shows no prompt and gives nothing.
- After save → load it is still open, and the crystals are still in the bag.
- A chest opened with the pad button gets the same pose and icon. With two items the modal shows one line per item, and a real mouse click on OK closes it.

## What is left
- Raise animation once `SampleProject/Sprites/Player/Raise/` lands (B-new above).
- Chests in the Village-centre house (after BACKLOG 38) and possibly the Laboratory (story call).
- A lid sound (the BACKLOG 26 event map has no chest sound).
- The integrator needs to number both D-news and the B-new.
