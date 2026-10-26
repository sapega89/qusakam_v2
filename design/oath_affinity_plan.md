---
type: plan
status: active
tags: [oaths, skills, story, combat]
---

# The oath chooses you — deeds and fighting style (Sapega, 2026-10-26)

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
5. **The census at the City Gate chooses the oath** (Sapega, 2026-10-26: «може тоді персонажа просто питають, кому він
   служить?», «як у Morrowind сузір'я», «перепис біля брами — це цікаво»). After the gate fight (the hero defended the
   one who was attacked) the gate scribe (new NPC `gate_scribe`, art drawn) writes the stranger into the city book: since
   the barrier fell and refugees come, the guard first looks into his eyes for the blue of the curse (D587), then asks
   his name, where from, and whom he serves, with 3–5 short what-would-you-do questions (Morrowind's class questions).
   The answers plus the leanings above make the scribe's suggestion («схоже, ти з тих, хто стоїть за Самаля» / «…хто
   живе угодами» / «…хто йде сам»). Then a star map with three constellations — the Sun of Samal, the Seal of the
   Contract, the Wanderer without a god (the blue day sky is cursed; the night stars still remember the old gods) — the
   suggested one lit, any can be chosen; «ще не знаю» leaves it open and the scribe can be asked again later. The oath's
   skill tree opens at level 5 (at once if he is already 5). Permanent, as today.
6. **A quiet hint, not a number.** The Journal's character page shows three emblems that grow brighter with each
   leaning; one «?» tip (once per playthrough, D-ID of hints-toggle) explains that the way he fights and acts draws a
   path to him.

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
