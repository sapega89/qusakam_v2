---
type: plan
status: built  # cloud/charms, 2026-10-23: rules, slots, armour weight, Equipment section, attic chest; art and the other chests wait
tags: [build, pillar-3, equipment]
figma: "none — no charms frame exists; the section copies the Equipment slot rows (UI/Equipment Panel 258:5110)"
---

# Charms and armour weight — plan (D592, pillar 3)

Sapega's D592: rings and amulets that **change a rule**, as Hollow Knight's charms do, and an armour weight trade-off
(light = longer roll, heavy = more defence and a shorter roll; no stamina, D551). The paid respec from the same D592
is built (D628). Pillar 3 says "choices cost something": every charm below gives and takes, and only 2–3 fit.

## What exists today

| Thing | Where | State |
|---|---|---|
| Equipment slots `accessory_1/2` | `PlayerStateManager._initial_state`, `InventorySlotRules` | ⚠️ stat slots, no item uses them; left alone |
| A charm / ring / amulet system | `grep -rni charm SampleProject` | ❌ none |
| Roll length | `PlayerMover.start_roll` — `roll_duration × (1 + Light Feet)` | ✅ one place to add a factor |
| Block / parry | `PlayerCombat` state `BLOCK`, `EventBus.player_parried` | ✅ |
| Flask | `healing_palm`, `charges: 3` (D504); `SkillManager.get_charges / refill_charges / _pay` | ✅ max sips read from the definition |
| SP | `SkillManager.gain_sp`, `_pay` (`sp_cost`), SP per hit and parry (D504) | ✅ |
| Enemy stagger | `EnemyLogic.stun_left` (stagger, stun, parry) | ✅ no public "is staggered" |
| Kills | `EventBus.enemy_died` | ✅ |
| Armour weight | `items.json` armour has only `stats.defense` | ❌ |
| Chests | `Chest.gd`, `contents` item → count (chests_plan) | ✅ items only |
| Attic | `ElderHouse.tscn` → `Attic` (grandfather's notes, a potion pickup) | ✅ no chest |
| Family shrine (D643) | Lizard Cave | ❌ not built — the first charm goes to the attic |
| Figma frame | — | ❌ none |

## Design

**State** — `player_state.charms = {"owned": [], "equipped": ["", "", ""], "slots": 2}`; saved by `PlayerDataModule`.
**Rules** — `Scripts/Systems/Charms.gd` (static, preloaded): data, `grant`, `equip`, `unequip`, `effect(name)`.
Each system that owns a rule asks `Charms.effect(...)`; nothing is a flat stat.

### Slots
3 slots, **2 open at the start**. The **3rd opens when the Brass Collector falls** (`MayorHall` → `Charms.unlock_slot()`),
the first boss and the oath's level (D668: level 5), so the third charm comes with the build's turn.

### The six charms (`charms.json`, numbers provisional)

| id | Kind | Rule | Gives | Costs |
|---|---|---|---|---|
| `grandfathers_ring` | ring | a parry heals | 5 % max HP per parry | a slot (the parry must land) |
| `sand_runner_ring` | ring | no block, a longer roll | roll +30 % | no block, so no parry |
| `hermit_amulet` | amulet | cheaper skills, weaker healing | skill SP −30 % | every skill heal −30 % (flask too) |
| `breaker_ring` | ring | punish a staggered enemy | +35 % hero melee damage on a staggered / stunned enemy | a slot |
| `deep_gourd_amulet` | amulet | one more sip, each weaker | flask +1 sip | each sip heals −30 % (4 × 0.7 = 2.8 < 3 sips) |
| `jackal_tooth_amulet` | amulet | kills feed SP | +4 SP per kill | a slot |

### Where they are found (D583: no free gifts)

| Charm | Where | State |
|---|---|---|
| Grandfather's Ring | **the grandfather's attic chest** (`ElderHouse` → `Attic/Chest_Attic`) — the attic opens with its key | ✅ placed |
| Deep Gourd Amulet | the family shrine chest, Lizard Cave (D643) | listed, not placed (room not built) |
| Breaker's Ring | the Bandit Camp chest (D643) | listed, not placed |
| Sand Runner's Ring | the Mesa Climb's top chest (D643) | listed, not placed |
| Jackal Tooth Amulet | behind the Dragon Mural's breakable wall (D643) | listed, not placed |
| Hermit's Amulet | the Gatehouse Cellar chest (D643) | listed, not placed |

A chest gets `charm = "<id>"` (`Chest.gd`); the modal names the charm.

### Armour weight (`armour_weight.json`)

Body armour carries `"weight"` in `items.json`; the worn body armour sets the hero's class (none worn = medium, the plain roll).
Helmets and shields carry no weight.

| Class | Roll | Defence | Items |
|---|---|---|---|
| light | +15 % | +0 | `leather_armor` |
| medium | 0 | +0 | no body armour (the plain roll) |
| heavy | −15 % | +2 (and +4 max HP: 2 HP per defence) | `iron_armor` |

Heavy's +2 is added in `GameCharacter.get_equipment_stats`, so Phys. Def., `mitigated_damage` and `verify_difficulty`
see it. Checked against D642: +5 pushed jackal L9/L10 to 7 hits and the Fire Djinn to 5; +3 put the Fire Djinn at 5 (defence also adds 2 HP each, and Last Stand); +2 keeps every row where it was (report).

### UI
A **Charms** block under Attributes in the Equipment side panel (under the slot list it ran off the screen): the same
`SlotRow` template (`ListRow`, `IconSlot`, `SlotCaption`, `SlotItemName`, `AccentDot`), captions `CHARM 1–3`, the
closed slot reads "(locked)". A row opens the
existing `equip_picker` with the owned charms. The body slot row shows the weight. No new colours or sizes.

## Decisions required

1. Charm and weight numbers, the third-slot trigger, the charm placements — routine calls, filed in the report as
   D-IDs; non-blocking.
2. **Figma frame for the charms section** — none exists; built from the existing slot look. Non-blocking.
3. **Charm icons** — no art; the stand-in is the crystal icon. Art row needed. Non-blocking.

## Slices

- ✅ Slice 1 — data, state, rules, save/load, `verify_charms.gd`.
- ✅ Slice 2 — armour weight, `verify_equipment` [weight].
- ✅ Slice 3 — Equipment section, attic chest.
- Left: the five chests in D643's branch rooms (with those rooms), charm icons, a Figma frame.
