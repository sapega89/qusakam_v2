---
type: plan
status: planned
---

# Backlog roadmap — the order to work in

Ordering of everything in [[BACKLOG]] and [[BUGS]], 2026-10-14. The items themselves stay
where they are; this note only says **what comes first and why**.

**The rule (Sapega, 2026-10-13):** first a game that can be played from start to end, then
find out why it is not fun. So a phase is judged by one question — *does it stop a
playthrough, or does it make one better?*

## Phase 1 — playable to the end ✅

**Sapega, 2026-10-14: the game already plays to the end.** What is left here are
leftovers that make a playthrough fuller, picked up alongside phase 2, not a gate.

| # | Item | Source | Why here |
|---|---|---|---|
| 1.1 | **Playtest the Laboratory to the demo end.** Sapega has not yet seen its fight. Two of nine original cells were drawn; the map now gives it 2. Companion beats run on triggers. | B53 · [[room_state_plan]] | The only stretch nobody has played. Whatever breaks here is phase-1 work. |
| 1.2 | ✅ **Laboratory picks its state from flags** (built 2026-10-15, triggers D174) | B53 | Loading a save made inside the lab skips its fight. Fix after 1.1 shows how the triggers chain. |
| 1.3 | ✅ **Merchant on the Desert Road, Blacksmith in the City** (placed 2026-10-14) | D81, **D154** | Shop and Crafting are built and tested but unreachable in play. |
| 1.4 | **Something to pick up** — `ItemPickup` and chests placed | D88 · Q2 | Inventory, crafting materials and potions have no source in the world except the first-kill gift. |
| 1.5 | ✅ **Game Over → Load Game** (built 2026-10-14) | D92 | Dying sends you to the title; one button. |
| 1.6 | **City has a floor and nothing else**; Mayor's Hall is a copied corridor | map review 2026-10-13 | Not blocking, but the walk to the mayor is empty. Art, not code — Sapega draws. |

## Phase 2 — the game reads as a game ← **current**

What it looks and sounds like. Order inside the phase: 2.1 first (nothing blocks it), 2.2 as
soon as Q38 is answered; 2.3 waits on an artist, 2.4 on the next beat being chosen.

| # | Item | Source | Waits on |
|---|---|---|---|
| 2.1 | Dialogue presentation layer (ours, on DialogueQuest) — incl. anime speech bubbles (Q48) and NPC Remind ([[npc_recall_plan]]) | D110–D114 · [[dialogue_audit]] | nothing — rewrite the audit §3 to D110, then build |
| 2.2 | ✅ Music plays — provisional track per room | [[music_plan]] | Q38 to pick the final tracks |
| 2.3 | Kusakam's missing states (Idle, Jump, Fall, Attack, Hurt, Death) in the current 64×64 style | [[character_animation_plan]] · D138 | **the frames** — an artist; enemies/NPCs stay as they are (D139) |
| 2.4 | Cutscenes beyond the Village | [[cutscene_plan]] · D140 | which beat next — Village is staged (D140), the rest is undecided |
| 2.5 | Village: more running before the old man | BACKLOG content row | deferred by Sapega until phase 1 is done |

## Phase 3 — the economy

| # | Item | Source |
|---|---|---|
| 3.1 | ✅ Shop: no Equipment tab, quantity selector, greyed unaffordable rows; Blacksmith sells nothing | D103–D106 |
| 3.2 | ✅ Enchanting (built 2026-10-15; Blacksmith task D175) | D94, D115 |
| 3.3 | Crafting gold costs are mock (10 % of buy price) | D97 |

## Phase 4 — decisions that reverse shipped code

D89 (save-slot mock card), D90 (shared `player_data.json`), D91 (auto-save on touch back),
D99 (revert the CLAUDE.md test note), D108. Each turns a green test red on purpose; do
them together, after phase 1, so a playthrough is not broken twice.

## Phase 5 — polish and cleanup

- **Visual B-IDs** B1–B41: cosmetic and Figma-mismatch items from the screenshot reviews.
- **Settings rows with no system** (D43–D48): build or cut each.
- **Undesigned live surfaces** — level-up notification, enemy HP bar, tutorial hints,
  "objective updated" toast, demo end screen: each needs a Figma frame first.
- **Housekeeping:** B16 is fixed (D136) but still listed; B42 dangling `ObjectiveHUD`
  ext_resource.

## Decided out of the way, needs a yes/no

These are not work until someone says they are wanted:

- **Companions** — a 206-line working system was lost in refactoring; no D-ID covers it.
  Sapega, 2026-10-14: leave for now.
- ~~**Quest engine**~~ — closed by **D162** (2026-10-14): delete `Scripts/Quest/`; quests run on `story.json` + `GameFlow` ([[npc_recall_plan]]).
- **Jobs, Healing sidebar entries, character roster / Stat Points** — D65, D18.
- **The D1–D115 audit** — decisions never checked against the code.
