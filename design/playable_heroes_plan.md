---
type: plan
status: future
tags: [heroes, classes, multiplayer, future]
---

# Playable heroes and co-op — plan (future, not the demo)

**Not built, and not for the demo.** Sapega, 2026-10-23: «хотів би мати можливість потім вибрати собі героя, одного з
4 — Алісію, Астрит, Уризена… потім ще додадуться, але то вже не в демо»; «це після того, як нам сподобається гра про
Кусакама і ми захочемо урізноманітнити, бо в нас буде мультиплеєр, скоріше за все, як в Castle Crashers»; the hero is
chosen **once, at the start**; «то на майбутнє, поки як план». Direction: D498.

## The idea
- The players pick one of four heroes when a new game starts, and keep that hero for the whole game, the way classes
  work in Diablo. More heroes come later.
- Co-op multiplayer is the reason for the roster: several players on one screen or online, each on their own hero, as
  in Castle Crashers.
- Every hero has their own class: three branches of skills, an action set and a look. **WoW is a mood reference
  only; no skills are copied from it.**

| Hero | Class idea | Branches (working names) |
|---|---|---|
| **Kusakam** | Holy Warrior (today's game) | the base tree, then the oaths: Paladin, Dark Knight, Warden (D280) |
| **Alisia** | hunter and archer, with her cat | *Beast* (the cat fights beside her), *Marksman* (precise long shots), *Trapper* (traps and survival) |
| **Urizen** | healer, a priest of the God of Contracts | *Light* (healing), *Ward* (shields and barriers), *Shadow* (curses and debts, contract magic) |
| **Astrit** | barbarian | *Fury* (heavy weapon and the spiked shield), *Battle-mage* (fire and runes), *Kineticist* (pushes, throws, force strikes) |

## What exists today
- Kusakam's full set: animations, the base tree, three oaths, companions (D209 / D464), and Alisia, Astrit and Urizen
  as companions with one assist each.
- Their new looks are in progress (D470–D472), but only as NPC and companion sprites, not full playable animation sets.
- Nothing for multiplayer: one `Player`, one camera, one HUD, saves for one hero.

## Missing entirely (when this starts)
- a hero choice at New Game, saved with the slot;
- per-hero data: skill trees in `skills.json` by `class_id`, the action set, the stats;
- three full playable animation sets in the hero's 64 × 64 style (idle, walk, run, jump, fall, attack ×3, heavy, block,
  roll, hurt, death, casts);
- co-op: several `Player`s, input per player, a shared camera (zoom to fit), HUD per player, and network or local
  multiplayer (Godot high-level multiplayer);
- companions: a hero who is playable cannot also be an assist in the same party.

## Decisions required (later)
1. Local co-op, online, or both (GAME DESIGN DECISION).
2. Does a solo player have AI companions, or the assists as today?
3. Does progress carry over between heroes (shared gold and items, or per hero)?
4. The skill trees for Alisia, Urizen and Astrit (GAME DESIGN DECISION; drafted by an agent, Sapega to confirm).

## Slices (when it starts)
1. Hero choice at New Game with Kusakam only, so the flow and the save data exist.
2. Alisia, playable: animation set, three branches, action set.
3. Urizen, playable.
4. Astrit, playable.
5. Local co-op: two players on one screen.
6. Online co-op.

## Out of scope now
Everything in this plan. The demo stays Kusakam's.
