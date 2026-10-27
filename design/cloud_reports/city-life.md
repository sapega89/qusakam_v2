---
type: report
tags: [cloud, city, npc, living-world]
---

# city-life — the City comes alive (D740)

**Summary.** Branch `cloud/city-life`, from `origin/cloud/oath-census` (`93601509`).
- **Done:** 8 townsfolk walk their own routes along the City street (stalls, the well, two doorways), pause, look around, step aside when the hero is near and never block him. 3 more stand in a queue at the City Gate, but only once the gate fight is won. Walkers say short barks (10 for the City, 4 for the queue, uk/en drafts) near the hero, never in a dialogue, menu or fight. 6 things to poke work with the shared interaction prompt: notice board, well, fruit stall, cat, crate and shrine of Samal.
- **Not done:** **none of the 4 townsfolk sheets is committed** (`townsfolk_{water_carrier,porter,old_man,merchant_woman}/sheet.png`). The walkers use tinted stand-ins (blacksmith, prisoner, Malik, merchant), which is a one-line swap per kind scene. There is no art for the six props either, so each is marked by the world glint (D446) over the painted background. There is no fruit item, so the stall sells `potion_lesser`. The game has no night, so there is no night crowd.
- **D-ID:** D740 (text below). **B rows fixed:** none.
- **Tests:** `verify_city_life` **ALL PASS**. Existing city verifies pass: `city_gates_raid`, `npc_chatter`, `npc_activity`, `oath_census`, `room_entrances`, `room_state`, `blacksmith`, `locations`. `npc_arrival` and `living_world` fail the same way on the base. Full suite: FULL_SUITE_LINE

## D740 (for `figma_decision_register.md`)

| D740 | GAP | **A living City: townsfolk, barks, things to poke** (Sapega 2026-10-26: «місто треба показати живим, щоб NPC ходили по ньому, щоб можна було щось кудись тикнути», «не артом, а додати жителів»; agent call on the numbers, Sapega to confirm; `cloud/city-life`). **Townsfolk** (`Scenes/Gameplay/Objects/NPCs/Townsfolk/`, `Townsfolk.gd`): there are 4 kinds (water carrier, porter, old man, merchant woman), each a 64×96 sheet with rows idle and walk. 8 walk in the City, with repeated kinds on different routes at 22–56 px/s. Each walks its stops back and forth, pauses for 2–5 s and sometimes turns mid-pause. Two doorways (x 95, x 1407) take a walker inside for 4–9 s, with a fade. A walker has no body, so the hero walks through it. When the hero is within 56 px, the walker steps 10 px up the street (behind him) and carries on. No stop is closer than 60 px to a door, an NPC or the save point, or closer than 50 px to a prop. 3 stand in a queue at the City Gate (`with_flag city_gates_fight_complete`), so nobody walks into the gate fight. **Barks** (`TownsfolkCrowd.gd`): the walker nearest the hero (within 110 px) says one line in the usual passing cloud (`say_line_in_passing`), every 8–16 s. A line does not repeat until all the lines have played. There are no barks during a dialogue, a passing cloud, a menu or a modal, or while `PlayerCombat.in_combat()`. **Things to poke** (`town_prop.tscn`, `TownProp.gd`, the shared prompt, a glint until the props have art): notice board (*Read*: 3 notices in `misc_popup`); well (*Drink*: heals by `potion_lesser`'s effect value, once per room visit); fruit stall (*Buy*: one `potion_lesser` for its `buy_price`, or «Not enough coins»); cat (*Pet*: «Prrr…» and a new `love` heart emote); crate (*Search*: 5 coins, once per game, saved as room state like a chest); shrine of Samal (*Look*: one line). The crate's coins go against D583 (no free gifts on the road). Sapega asked for them after D583, so they stay small; Sapega to confirm. |

## What changed (file:line)

### Walkers
- `SampleProject/Scripts/Gameplay/NPCs/Townsfolk.gd`. The route, pauses and turns live in `_process`. Arriving at a stop or a doorway is `_arrive` (:103), and `_go_inside` (:129) handles the fade into a doorway. `_step_aside` (:142) moves a walker back from the hero (`ASIDE_RADIUS` :23). Exports: `stops`, `doorways`, `speed`, `pause_*`, `inside_*`.
- `SampleProject/Scenes/Gameplay/Objects/NPCs/Townsfolk/townsfolk.tscn` is the base scene: Sprite2D ×1.5, AnimationPlayer `idle` 0–1 and `walk` 4–7. Four inherited kind scenes set the sheet. The stand-ins and how to swap them are in `Assets/Characters/NPCs/README.md` → *Townsfolk*.
- `SampleProject/Scripts/Gameplay/NPCs/TownsfolkCrowd.gd` covers barks (`_process` :33, `_may_bark` :53) and the flag gate (`_show` :89). It emits `barked(walker, line)` for tests.
- `Maps/City.tscn:152` `Crowd` holds 8 walkers and sits before the NPC nodes, so walkers pass behind the NPCs. `Maps/CityGates.tscn:183` `Crowd` holds the 3-person queue at x 896–1012, left of the cellar door (1090) and the scribe (1150).

### Things to poke
- `SampleProject/Scripts/Gameplay/TownProp.gd` covers the six kinds (`_on_interacted` :49, `_buy` :83). `SampleProject/Scenes/Gameplay/Objects/town_prop.tscn` has the same glint, area and `InteractableComponent` as `StoryNote`.
- `Maps/City.tscn:204` `Props`, placed on the painted street: NoticeBoard 240, FruitStall 340 (painted stalls), Crate 470, Well 1500, Shrine 1720 (by the chapel), Cat 2120 (by the tent).
- `Assets/UI/Icons/emote_love.svg` is a 9×8 pixel heart in the style of the D460 emotes. `Scripts/FX/Emote.gd` gains the `love` kind, and `UITokens.EMOTE_LOVE` (= `HURT_RED`).
- Texts: 29 new keys in `uk.po` (section «Живе Місто», D740), with `en.po` from `po_sync.py`. All are drafts.

## Tests
- `SampleProject/UI/verify_city_life.gd` — **RESULT: ALL PASS**.
  - [0] Prints which townsfolk sheets are committed. All 4 are missing.
  - [1] The City has 8 walkers of all 4 kinds, none of them with a collision body.
  - [2] No stop is near a door, an NPC or the save point (10 of them) or near a prop, and no prop covers a door or an NPC.
  - [3] In about 36 s of game time every walker covers more than 60 px (old men 260–270 px, porters about 900–1500 px). 4 routes have a doorway.
  - [4] With the hero close, the walker steps up the street, then returns when he leaves.
  - [5] One bark near the hero, in a cloud, with a line from the crowd's keys. No bark with nobody near, and none during a running dialogue.
  - [6] Each prop is driven by a real `interact` press, and its prompt shows first. Board: a modal. Well: +50 HP, then disabled. Stall: with no coins nothing is sold; with 23 coins, one is bought and 3 coins are left. Cat: heart and purr. Crate: +5, once only, and room state is saved. Shrine: a cloud.
  - [7] CityGates: the queue is hidden and disabled before the fight flag and visible after. There are 3 in the queue, clear of the cellar door and the scribe.
- Shots (`SampleProject/UI/capture_city_life.gd`): `design/shots/city_life_a.png` (market, hero at 420), `city_life_c.png` (chapel, witch hut, «Look» prompt at the shrine), `city_life_d.png` (tent, guards), `city_life_gates.png` (the queue at the gate).
- Full suite: see the summary. FULL_SUITE_DETAIL

## Calls made (Sapega to confirm)
- The stand-in art and the glints are temporary. They come out when the art lands (MASTER_PLAN S20).
- The numbers are mine: speeds, pauses, bark radius 110 px and gap 8–16 s, step aside at 56 px, crate 5 coins. The well heals by `potion_lesser`'s value (50) and the stall sells `potion_lesser` at 20, so no item stats are invented.
- The bark texts follow `design/lore.md`: the barrier fell asleep, the blue sky makes eyes blue, refugees, the census, the mayor's queue.
