---
type: plan
status: in-progress  # chest built and placed on DesertRoad (cloud/chests); the Raise pose waits for its art
tags: [world, items, feedback]
---

# Chests — plan (BACKLOG 33)

Linked from [[BACKLOG]] row 33 and [[play_feedback_queue]] row 8 (art A1). Rule: **D88** path 3 — a chest opens on a
button press, adds its contents automatically, **then** shows the pickup modal. Persistence like the placed pickups
(**D298**). Figma: no chest frame exists; the modal is `UI/Modal/ItemPickup 222:4880` (D71).

## What exists (cloud/chests, 2026-10-21)

| Part | Where |
|---|---|
| Art: Closed / Opening 1–3 / Open, 64×64 at the hero's scale (×1.5), bottom on row 56 | `SampleProject/Assets/Props/Chest/` (A1) |
| Scene: `Area2D` + `Sprite` (`AnimatedSprite2D`: `closed`, `opening` 8 fps, `open`) + `Interactable` ("Open") + `Found` (the icon over the hero) | `SampleProject/Objects/Chest.tscn` |
| Behaviour: interact → contents to the bag → lid → hero held in `HERO_POSE` with the icon above him for `RAISE_SECONDS` → "You obtained:" modal | `SampleProject/Scripts/Gameplay/Chest.gd` |
| Persistence: room state `opened_<node>` (D152), saved by `FlagsModule.room_state`; an opened chest loads open, no prompt | `Chest.gd` `_ready` |
| Modal text: one `<Item> × <N>` line per item, `ModalTemplates.items_obtained` (same as cloud/dialogue-ui's gift popup) | `SampleProject/Scripts/UI/modal_templates.gd` |
| Placement: `Chest_CaravanLedge` on the caravan rock, Mana Crystal × 2 — replaces the ledge's Mana Crystal pickup | `SampleProject/Maps/DesertRoad.tscn` |
| Verify | `SampleProject/UI/verify_chests.gd` |

The chest's origin is its **floor point** (place it on the top of the ground it stands on).

## The Raise pose — the hook

Kusakam's raise-the-item frames (`comfy_sprite.py hero_raise` → `SampleProject/Sprites/Player/Raise/1–3.png`) are
**not in the repo yet**. Until they land the hero stands in `Idle` (the pose every held moment uses) with the item
over his head. When they land:

1. add an `Animation` `"Raise"` to `SampleProject/Player.tscn` (frames 1→2→3, hold on 3, no loop);
2. set `Chest.HERO_POSE := &"Raise"` (`Chest.gd`, one constant).

`verify_chests` checks the hero plays `Chest.HERO_POSE`, so it follows the constant without edits.

## Left

- A chest in the Village centre — the centre house is BACKLOG 38 (cloud/buildings, art A2); a chest belongs there
  once the house exists.
- A chest in the Laboratory — the lab rooms are being rebuilt by queue rows 9.5–9.8; the prisoner story (gear taken)
  needs a product call on what a lab chest would hold. Not placed.
- A sound for the lid (BACKLOG 26 event map) — no chest sound exists.
