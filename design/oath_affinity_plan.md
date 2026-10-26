---
type: plan
status: active
tags: [oaths, skills, story, combat]
---

# The oath chooses you — deeds and fighting style (Sapega, 2026-10-26)

> **Latest (overrides any routine prompt that differs):** no star map — the census is a short dialogue with the gate
> scribe (item 5); the path is chosen there and then, no «ще подумаю»; the Skills screen shows only the chosen path's
> tree (item 7).

Sapega: the problem with the oaths is not the lore but how they are presented: «як три NPC — виглядає дуже дивно, і
персонаж не захоче до них підходити»; a separate quest — «а навіщо?»; «ми не хочемо закривати Майор Хол через нестачу
скілів (як зараз)». From the brainstorm he picked: **deeds choose the oath** and **the fighting style chooses the oath**
(«вчинки і стиль бою — це цікаво»). Lore of the three paths: [[figma_decision_register]] D718 (Samal, the god of
contracts, no god for the neutral path).

## What changes

1. **No gate.** The Mayor Hall door no longer waits for an oath (City.gd `MayorHallGate`, D488 superseded). Without an
   oath the hero simply has no oath skills and the fights are harder (as in L2 / WoW).
2. **Three leanings, tracked quietly.** `PlayerState` keeps three numbers, saved with the game:
   - **Samal** (Paladin, Light): the protector — blocks and parries that land, standing your ground, saving people.
   - **Contract** (Witch / Dark Knight): the price — trading HP for damage (hitting while low on HP, heavy trades),
     deals and bargains, taking what is offered.
   - **No god** (Warden of Balance): the dancer — dodging through attacks, fights won without being hit, staying out of
     other people's quarrels, walking your own way.
3. **The fighting style feeds them** from events the combat already emits (block/parry landed, damage taken/dealt with
   HP below a third, dodges through an enemy swing, fights won untouched). Each fight adds a little, capped per fight,
   so grinding one trick does not decide everything.
4. **Deeds feed them** at a few choice points in the first act (the game has almost no dialogue choices today — the
   oath menu is «the only choice in the game», OathKeeper.gd). Drafts to add, each a short choice in an existing scene:
   the grandfather's decision, the wounded in the burning village, the Caravan (help / take the reward / walk past), the
   lone brute's key and the Bandit Camp (spare / bargain / leave), Alisia (heal / bargain / leave). Text marked as
   drafts for Sapega.
5. **The census at the City Gate: a short talk, no star map** (Sapega, 2026-10-26: «ой, ні, сузір'я не треба, треба
   пару питань, по типу кому служиш і так далі. Ти кажеш «я не знаю», він питає «любиш те або те, робиш так або так» і
   пропонує служити одному з трьох, але радить того-то. А гравець такий: та ні, краще той»). After the gate fight (the
   hero defended the one who was attacked) the gate scribe (`gate_scribe`) checks his eyes for the blue of the curse
   (D587) and writes him into the city book in a short dialogue:
   - «Ім'я? Звідки?» then **«Кому служиш?»** with the answers: Samal / the god of contracts / nobody, I walk on my own /
     «Не знаю».
   - On «Не знаю» the scribe asks two or three quick this-or-that questions («любиш те чи те, робиш так чи так»,
     drafts), and then names the three paths and **advises one** — the one his answers and the leanings above point to
     («Раджу тобі Самаля»).
   - The player takes the advice or says **«Та ні, краще…»** and picks another of the three. The choice is made
     there and then — no «ще подумаю», no coming back later (Sapega: «фолбек тут не треба, просто вибрав шлях і
     іди далі»).
   - The chosen path is the oath (permanent, the existing SkillManager oath ids); its tree opens at level 5, at once if
     he is already 5. It is all one dialogue in the normal dialogue box — no star map, no separate screen.
6. **A quiet hint, not a number.** The Journal's character page shows three emblems that grow brighter with each
   leaning; one «?» tip (once per playthrough, D-ID of hints-toggle) explains that the way he fights and acts draws a
   path to him.

7. **One skill set, not three** (Sapega: «в нас буде один з трьох наборів скілів, всі три показувати не треба»). The
   Skills screen shows the base tree (Holy Warrior) and, once the path is chosen, only that path's tree — the other two
   oath trees are not shown at all (no locked tabs, no previews). Before the census only the base tree shows.

## The keepers become ordinary people
The priest of Samal, the priest of contracts (replaces the witch: «теж жрець, просто в чорному, і в золоті, бо контрактів
багато підписав»; new art `contract_priest`) and the dervish stay in the City as plain NPCs who talk about their path;
they give no oath and no menu.

## Defaults until Sapega says otherwise
- Leanings are hidden as numbers, visible as emblem brightness.
- The deed choices are drafts written by the routine and read by Sapega.

## Built by
Routine `oath-affinity` (after `hints-toggle`, which also edits Village.gd and the tips). It also does D718's text work
(no Sky worship; Samal, the god of contracts, no god) that the paused routine `oaths-lore` was going to do.
