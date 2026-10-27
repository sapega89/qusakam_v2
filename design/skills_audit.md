---
type: audit
status: active
tags: [skills, oaths, art, gear]
---

# Skills audit (2026-10-26)

Sapega (2026-10-26): «і щита його немає, але в нас доступний захист щитом (це дивний набір навичок)» and «і анімації
навичок теж недороблені». New since: the hero sees the base tree (Holy Warrior) and **only one** path tree — Samal
(Paladin), the god of contracts (Dark Knight) or no god (Warden) — D725–D728, [[oath_affinity_plan]]. This note audits
all 76 skills in `SampleProject/Resources/Data/skills.json` (branch `feature/backlog` at `7b200f0b`), then proposes
what to do. Background: [[skill_trees_plan]], D279, D491, D535, D626, D718.

## In short

- **48 skills work, 28 do not exist in code.** The 12 built actives all run through one generic handler
  (`SkillManager.use_skill`: damage / heal / burn / stun / chain); the 36 passives each read a stat somewhere in the
  combat code. The 28 v2 actives (D626) are `planned: true`: no numbers, no handler, no pose, no VFX — the screen shows
  them, learning answers `PLANNED`.
- **The hero has three cast poses of two frames each** (`CastPalm`, `CastFire`, `CastStorm`) for all 12 actives,
  ultimates included. That is the «анімації недороблені»: a spin, a blessing and three ultimates borrow a pose that
  shows something else.
- **VFX:** the 12 built actives have one each (3 own scenes + `OathSkill.tscn` with per-skill frames in
  `Assets/FX/Skills/<id>/`). The 28 planned have none.
- **Icons:** all 76 have their own icon (80 PNGs, no duplicates).
- **The shield:** 5 skills need one. The hero *can* own one (City caravan merchant, 180 coins, or the blacksmith's
  recipe) and it works in the numbers, but **it is invisible**: no shield art on the hero at all. Two more gear gaps:
  no mace and no dagger exist anywhere in the world (Electric Strike runs on the Mesa halberd only).
- **Overlaps:** 29 skills repeat another one's stat or move (five «take X% less damage», three «+attack», three «+max
  HP», three «after a parry, skills hit harder», three dashes, two slams, two spears, two shouts).
- **Sapega's answer (2026-10-27), final:** «щит можна було просто підставити зверху на існуючий арт. Він його носити
  із собою не буде, він буде просто з'являтись з неба, бо це магія з Pathfinder. Блок щитом і блок скляним щитом,
  який, коли розбивається, наносить урон тому, хто по ньому б'є». So the shield is **a spell, not gear**: a magic
  shield drops from the sky in front of him over the existing Block art, holds while he blocks and fades. Two kinds:
  the **shield block** and the **glass shield block** — a glass shield that cracks under hits and, when it breaks,
  its shards damage whoever hit it. The shield skills no longer need a shield item (the audit's gear gap is gone).
  Art (🖥): the magic shield (appear from above, hold shimmer, fade) and the glass shield (appear, crack, shatter),
  drawn over Block/1; the iron-shield sprite `Sprites/Player/Shields/iron_shield` (`e5cb5681`) is superseded.
  Code (☁, after `hero-shadow`): the spell, the glass shield's break damage, no gear check. D-ID after integrate-29.
- **Recommendation (superseded by his answer above):** rework the 5 shield skills into shield-free ones (proposal a), drop the shield from the hero's
  gear, and reshape each path tree into one kit (below). Art queue at the end: 14 hero poses, 30 VFX.

## 1. The 76 skills

Tree: Base = Holy Warrior; the three paths are named by D718. A = active, P = passive, Lv = `required_level`.
Handler: where the effect is read (`file:line`, all under `SampleProject/Scripts/`); conditions (`below_hp`,
`after_parry`, `after_skill`) are checked in `SkillManager.gd:245`. Pose: the cast animation in `Player.tscn`
(`<pose>Windup` / `<pose>Release`, frames `Sprites/Player/<pose>/1–2.png`). VFX: the scene under `Scenes/FX/Skills/`.
`*` = a `[DRAFT]` name.

| # | id | Name | Tree | A/P | Lv | Needs | Effect handler | Hero pose | VFX | Icon | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `healing_palm` | Healing Palm | Base | A | 2 | 0 SP, 3 sips | use_skill: heal | CastPalm ✓ (2 fr.) | HealingPalm | ✓ | OK |
| 2 | `fire_strike` | Fire Strike | Base | A | 6 | sword/dagger, 6 SP | use_skill: damage+burn | CastFire ✓ (2 fr.) | FireStrike | ✓ | OK (no dagger in the world: sword only) |
| 3 | `electric_strike` | Electric Strike | Base | A | 6 | polearm/mace, 8 SP | use_skill: damage+stun+chain | CastStorm ✓ (2 fr.) | ElectricStrike | ✓ | needs gear: halberd only (Mesa chest); no mace in the world |
| 4 | `toughness` | Toughness | Base | P | 1 | — | GameManager.gd:217 | — (passive) | — | ✓ | OK; overlaps Aura of Valour / Iron Body (max HP) |
| 5 | `shield_block` | Shield Block | Base | P | 1 | **shield** | Player.gd:543 (shield only) | — (passive) | — | ✓ | needs gear the hero cannot show (invisible shield) |
| 6 | `devotion` | Devotion | Base | P | 3 | — | SkillManager.gd:447 | — (passive) | — | ✓ | OK |
| 7 | `weapon_training` | Weapon Training | Base | P | 4 | — | GameManager.gd:223 | — (passive) | — | ✓ | OK; overlaps Dread Aura / Perfect Balance (+attack) |
| 8 | `fortitude` | Fortitude | Base | P | 12 | — | Player.gd:544 | — (passive) | — | ✓ | OK; overlaps 4 path passives (−% damage) |
| 9 | `riposte_instinct` | Riposte Instinct* | Base | P | 8 | — | SkillManager.gd:183 + after_parry | — (passive) | — | ✓ | OK; overlaps Zealous Answer / Dark Riposte (same trigger, same stat) |
| 10 | `last_stand` | Last Stand* | Base | P | 10 | — | Player.gd:544 + below_hp | — (passive) | — | ✓ | OK |
| 11 | `radiant_smite` | Radiant Smite | Samal (Paladin) | A | 5 | 6 SP | use_skill: damage+stun | CastStorm ✓ (2 fr.) | OathSkill + FX/Skills/radiant_smite/ | ✓ | OK (shared pose) |
| 12 | `mending_hands` | Mending Hands | Samal (Paladin) | P | 5 | — | SkillManager.gd:192 | — (passive) | — | ✓ | OK |
| 13 | `aura_of_resolve` | Aura of Resolve | Samal (Paladin) | P | 8 | — | Player.gd:544 | — (passive) | — | ✓ | overlaps Fortitude / Unbroken Vow (−% damage) |
| 14 | `skys_grace` | Sky's Grace | Samal (Paladin) | P | 10 | — | SkillManager.gd:336 | — (passive) | — | ✓ | OK; name says «Sky» (D718: Samal) |
| 15 | `skyfall_blessing` | Skyfall Blessing | Samal (Paladin) | A | 12 | 12 SP | use_skill: damage+heal | CastPalm ✓ (2 fr.) | OathSkill + FX/Skills/skyfall_blessing/ | ✓ | no animation (palm pose for a strike); «Sky» name |
| 16 | `aura_of_valour` | Aura of Valour | Samal (Paladin) | P | 15 | — | GameManager.gd:217 | — (passive) | — | ✓ | overlaps Toughness (max HP) |
| 17 | `judgement_of_the_sky` | Judgement of the Sky | Samal (Paladin) | A | 20 | 16 SP, cd 60 s | use_skill: damage+stun+chain | CastStorm ✓ (2 fr.) | OathSkill + FX/Skills/judgement_of_the_sky/ | ✓ | no animation (ultimate on the shared fist-up pose); «Sky» name |
| 18 | `unbroken_vow` | Unbroken Vow | Samal (Paladin) | P | 18 | — | Player.gd:544 | — (passive) | — | ✓ | overlaps Aura of Resolve (same stat, same tree) |
| 19 | `merciful_light` | Merciful Light* | Samal (Paladin) | P | 8 | — | SkillManager.gd:192 + below_hp | — (passive) | — | ✓ | OK |
| 20 | `zealous_answer` | Zealous Answer* | Samal (Paladin) | P | 10 | — | SkillManager.gd:183 + after_parry | — (passive) | — | ✓ | overlaps Riposte Instinct |
| 21 | `consecrated_ground` | Consecrated Ground* | Samal (Paladin) | P | 15 | — | Player.gd:544 + after_skill | — (passive) | — | ✓ | OK |
| 22 | `searing_hex` | Searing Hex | Contract (Dark Knight) | A | 5 | 6 SP | use_skill: damage+burn | CastFire ✓ (2 fr.) | OathSkill + FX/Skills/searing_hex/ | ✓ | OK (shared pose) |
| 23 | `blood_pact` | Blood Pact | Contract (Dark Knight) | P | 5 | — | PlayerCombat.gd:220 | — (passive) | — | ✓ | OK |
| 24 | `dread_aura` | Dread Aura | Contract (Dark Knight) | P | 8 | — | GameManager.gd:223 | — (passive) | — | ✓ | overlaps Weapon Training (+attack) |
| 25 | `relentless` | Relentless | Contract (Dark Knight) | P | 10 | — | PlayerCombat.gd:219 | — (passive) | — | ✓ | OK; overlaps Sand Stance (other path) |
| 26 | `withering_grasp` | Withering Grasp | Contract (Dark Knight) | A | 12 | 12 SP | use_skill: damage+burn | CastFire ✓ (2 fr.) | OathSkill + FX/Skills/withering_grasp/ | ✓ | overlaps Searing Hex (same pose, burn, front strike) |
| 27 | `hoarded_ward` | Hoarded Ward | Contract (Dark Knight) | P | 15 | — | Player.gd:544 | — (passive) | — | ✓ | overlaps Fortitude; off-theme for «power for a price» |
| 28 | `eclipse_cleave` | Eclipse Cleave | Contract (Dark Knight) | A | 20 | 18 SP, cd 60 s | use_skill: damage+burn+chain | CastFire ✓ (2 fr.) | OathSkill + FX/Skills/eclipse_cleave/ | ✓ | no animation (ultimate on the shared lunge pose) |
| 29 | `crimson_thirst` | Crimson Thirst | Contract (Dark Knight) | P | 18 | — | PlayerCombat.gd:220 | — (passive) | — | ✓ | overlaps Blood Pact (same stat, same tree) |
| 30 | `desperate_hunger` | Desperate Hunger* | Contract (Dark Knight) | P | 8 | — | PlayerCombat.gd:220 + below_hp | — (passive) | — | ✓ | OK |
| 31 | `cruel_momentum` | Cruel Momentum* | Contract (Dark Knight) | P | 10 | — | GameManager.gd:223 + after_skill | — (passive) | — | ✓ | OK |
| 32 | `dark_riposte` | Dark Riposte* | Contract (Dark Knight) | P | 15 | — | SkillManager.gd:183 + after_parry | — (passive) | — | ✓ | overlaps Riposte Instinct |
| 33 | `balanced_strike` | Balanced Strike | No god (Warden) | A | 5 | 5 SP | use_skill: damage+stun | CastFire ✓ (2 fr.) | OathSkill + FX/Skills/balanced_strike/ | ✓ | OK (shared pose) |
| 34 | `bulwark` | Bulwark | No god (Warden) | P | 5 | **shield** | Player.gd:543 (shield only) | — (passive) | — | ✓ | needs gear the hero cannot show (invisible shield) |
| 35 | `sand_stance` | Sand Stance | No god (Warden) | P | 8 | — | PlayerCombat.gd:219 | — (passive) | — | ✓ | OK |
| 36 | `iron_body` | Iron Body | No god (Warden) | P | 10 | — | GameManager.gd:217 | — (passive) | — | ✓ | overlaps Toughness (max HP) |
| 37 | `dervish_whirl` | Dervish Whirl | No god (Warden) | A | 12 | 10 SP | use_skill: damage+chain | CastStorm ✓ (2 fr.) | OathSkill + FX/Skills/dervish_whirl/ | ✓ | no animation (a spin on the fist-up pose) |
| 38 | `unshakable` | Unshakable | No god (Warden) | P | 15 | — | Player.gd:544 | — (passive) | — | ✓ | overlaps Fortitude (−% damage) |
| 39 | `second_wind` | Second Wind | No god (Warden) | A | 20 | 14 SP, cd 60 s | use_skill: heal | CastPalm ✓ (2 fr.) | OathSkill + FX/Skills/second_wind/ | ✓ | overlaps Healing Palm (a bigger heal); shared palm pose |
| 40 | `perfect_balance` | Perfect Balance | No god (Warden) | P | 18 | — | GameManager.gd:223 | — (passive) | — | ✓ | overlaps Weapon Training (+attack) |
| 41 | `still_water` | Still Water* | No god (Warden) | P | 8 | — | Player.gd:544 + after_parry | — (passive) | — | ✓ | OK |
| 42 | `dervish_rhythm` | Dervish Rhythm* | No god (Warden) | P | 10 | — | PlayerCombat.gd:219 + after_skill | — (passive) | — | ✓ | OK |
| 43 | `rooted_resolve` | Rooted Resolve* | No god (Warden) | P | 15 | — | PlayerCombat.gd:219 + below_hp | — (passive) | — | ✓ | OK |
| 44 | `dash_strike` | Dash Strike* | Base | A | 1 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Blood Rush / Wind Step; no animation; no VFX |
| 45 | `rising_slash` | Rising Slash* | Base | A | 3 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 46 | `shield_bash` | Shield Bash* | Base | A | 4 | **shield**, — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; needs gear (already falls back to a pommel strike); no animation; no VFX |
| 47 | `ground_slam` | Ground Slam* | Base | A | 8 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Sweeping Arc; no animation; no VFX |
| 48 | `holy_javelin` | Holy Javelin* | Base | A | 10 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Lightspear; no animation; no VFX |
| 49 | `battle_cry` | Battle Cry* | Base | A | 12 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Dread Howl / Rally; no animation; no VFX |
| 50 | `counter_stance` | Counter Stance* | Base | A | 14 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 51 | `keen_edge` | Keen Edge* | Base | P | 14 | — | GameManager.gd:277 | — (passive) | — | ✓ | OK |
| 52 | `heavy_hand` | Heavy Hand* | Base | P | 16 | — | PlayerCombat.gd:483 | — (passive) | — | ✓ | OK |
| 53 | `shield_charge` | Shield Charge* | Samal (Paladin) | A | 5 | **shield**, — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; needs gear the hero cannot show; no animation; no VFX |
| 54 | `lightspear` | Lightspear* | Samal (Paladin) | A | 8 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Holy Javelin; no animation; no VFX |
| 55 | `aegis` | Aegis* | Samal (Paladin) | A | 10 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 56 | `hallowed_circle` | Hallowed Circle* | Samal (Paladin) | A | 10 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 57 | `rally` | Rally* | Samal (Paladin) | A | 15 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 58 | `heavens_anvil` | Heaven's Anvil* | Samal (Paladin) | A | 15 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler (same move as Dune Quake, other path); no animation; no VFX |
| 59 | `radiant_flare` | Radiant Flare* | Samal (Paladin) | A | 18 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 60 | `shield_of_faith` | Shield of Faith* | Samal (Paladin) | P | 18 | **shield** | Player.gd:525 (shield only) | — (passive) | — | ✓ | needs gear the hero cannot show (invisible shield) |
| 61 | `blood_rush` | Blood Rush* | Contract (Dark Knight) | A | 5 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Dash Strike; no animation; no VFX |
| 62 | `chain_of_night` | Chain of Night* | Contract (Dark Knight) | A | 8 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 63 | `blood_price` | Blood Price* | Contract (Dark Knight) | A | 10 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 64 | `night_reaper` | Night Reaper* | Contract (Dark Knight) | A | 10 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Eclipse Cleave (dark crescent); no animation; no VFX |
| 65 | `dread_howl` | Dread Howl* | Contract (Dark Knight) | A | 15 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Battle Cry; no animation; no VFX |
| 66 | `hellfire_stomp` | Hellfire Stomp* | Contract (Dark Knight) | A | 15 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 67 | `soul_harvest` | Soul Harvest* | Contract (Dark Knight) | A | 18 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 68 | `embers_within` | Embers Within* | Contract (Dark Knight) | P | 18 | — | DefaultEnemy.gd:726 | — (passive) | — | ✓ | OK |
| 69 | `wind_step` | Wind Step* | No god (Warden) | A | 5 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Dash Strike; no animation; no VFX |
| 70 | `sand_veil` | Sand Veil* | No god (Warden) | A | 8 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 71 | `stone_palm` | Stone Palm* | No god (Warden) | A | 10 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 72 | `sweeping_arc` | Sweeping Arc* | No god (Warden) | A | 10 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Ground Slam / Dune Quake; no animation; no VFX |
| 73 | `mirror_stance` | Mirror Stance* | No god (Warden) | A | 15 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; no animation; no VFX |
| 74 | `centered_breath` | Centered Breath* | No god (Warden) | A | 15 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler; overlaps Second Wind (heal); no animation; no VFX |
| 75 | `dune_quake` | Dune Quake* | No god (Warden) | A | 18 | — (planned, no numbers) | **no handler** (`planned`, learn → PLANNED) | **none** | **none** | ✓ | no handler (same move as Heaven's Anvil, other path); no animation; no VFX |
| 76 | `light_feet` | Light Feet* | No god (Warden) | P | 18 | — | PlayerMover.gd:143 | — (passive) | — | ✓ | OK |

Totals: 27 rows «OK» (some with an overlap note), 28 «no handler», 32 «no animation» (28 planned + 4 built on a
pose that shows another move), 28 «no VFX», 6 «needs gear», 29 with an overlap.

Data notes found on the way (no change made, this routine writes documents only):
- `skills.json` → `oaths` still names the keepers «Sister Ilvane, priest of the Sky» and «Morrow the witch» and the
  prestige «Avatar of the Sky»; D718/D726 replaced the Sky and the witch. Three skill names say «Sky» too
  (`skys_grace`, `skyfall_blessing`, `judgement_of_the_sky`).
- The base tree is named «Holy Warrior», and its draft «Holy Javelin» throws light. Under D718 the no-god path gets no
  blessing from any god, so «holy» in the shared tree reads oddly for a Warden.

## 2. Gear the skills ask for

| Gear | Skills | Can the hero get it? | Can the hero be seen holding it? |
|---|---|---|---|
| **Shield** (`iron_shield`, the only one; Defense +12, `category: shield`) | Shield Block (base), Bulwark (no god), Shield of Faith (Samal), Shield Charge (Samal, planned), Shield Bash (base, planned; already falls back to a pommel strike) | **Yes.** Sold by the City caravan merchant (`merchants.json` → `city_merchant`, 180 coins, `City.tscn:173`); recipe `craft_iron_shield` at the City blacksmith's anvil (3 iron ingots + 2 planks). Not in any chest or drop. (`GameSettings.get_default_inventory_items()` lists it but nothing calls that function.) | **No.** `Sprites/Player/` has no shield frames and `Sprites/Player/Weapons/` has sword, dagger, dual, halberd, mace, bow only. Equipped, it lowers damage (`Player._shield_in_hand()`, `Player.gd:531`; off with a two-handed weapon or a bow) but the hero still blocks with his fists or blade (`Block/1.png`). Shield-bearer enemies (D616, D711) and Astrit (D221) carry shields; the hero never does. |
| Mace | Electric Strike | **No.** `iron_mace` is in `items.json` but in no shop, chest, drop or recipe. | Yes (`Weapons/mace/`). |
| Dagger | Fire Strike | **No.** `iron_dagger` likewise has no source. | Yes (`Weapons/dagger/`). |
| Polearm | Electric Strike | Yes: `iron_halberd` in `Chest_Mesa` (`MesaClimb.tscn:248`). Two-handed, so no shield with it. | Yes (`Weapons/halberd/`). |
| Sword | Fire Strike | Yes: copper sword from the grandfather (`ElderHouse.gd:161`), iron / copper at the Desert Road merchant, silver from the Mayor Hall victory. | Yes. |
| Armour | — | No skill asks for armour; armour weight (D687) only changes the roll. | — |

So the shield skills «work» on paper: the hero can buy a shield and the numbers apply, but he looks shieldless, and
blocking/parrying already exists without one (D264: a held block takes no damage). That is the «strange set».

## 3. Proposals

### 3.1 The shield: rework the skills, or give the hero a shield

**(a) Rework the shield skills into shield-free ones that fit the paths.** Each reads the block and parry the hero
already has (no new gear):

| Was | Becomes | Tree | One line |
|---|---|---|---|
| Shield Block (P) | **Steady Guard** | Base | A held block withstands blows 20% heavier before it breaks (D264's break threshold). |
| Shield Bash* (A) | **Pommel Strike** | Base | A short jab with the hilt: breaks an enemy's wind-up, heavy guard damage, little HP damage. |
| Shield Charge* (A) | **Samal's Advance** | Samal | Run forward shoulder-first in a shell of light; enemies hit are pushed back, front blows during the run are blocked. |
| Shield of Faith* (P) | **Samal's Mercy** | Samal | A block or parry that lands heals you for 25% of the damage it stopped (today's `block_heal` without the shield check). |
| Bulwark (P) | **Read the Blow** | No god | A dodge through an enemy's swing makes your next hit within 2 s a counter: +50% poise damage. |

Cost: data and small code changes (one stat, two handlers, three renamed passives), five new icons, two poses
(Pommel Strike, Samal's Advance — in the art list). The `shield` equipment slot and `iron_shield` then lose their
reason: default is to take the shield off the hero's gear (shop, recipe, slot), keeping shields for enemies and Astrit.

**(b) Give the hero a real shield.** What it costs:
- **Art:** a shield on the off arm in every pose that can carry it — Idle 3, Walk 3, Run 8, Jump/Apex/Fall/Land 6,
  Climb 2 (on the back), Hurt 1, Dash 3, Block 1, Heavy 2, three casts × 2, Raise 2 — about 37 frames, each with a
  shield anchor, as `WeaponView` does for blades; plus one shield sprite in 3 angles (rest, guard, back). The bought
  frames (Walk, Run) are the artist's (D239), so the shield must be painted onto them by ComfyUI without breaking
  the style — the riskiest part. Every new skill pose later also needs a shield version.
- **A slot and rules:** the slot exists; one-handed weapon only (as now); dual wield and bow already forbid it.
- **Balance:** Defense +12 plus Shield Block 20% plus Bulwark 10% stack on a block that already takes no damage; the
  shield needs a cost (slower roll, heavier armour class D687, or no parry with it) or it is free power — against
  pillar 1.
- **Story:** the hero is a lizard villager who fights with what he has (D579); a knight's shield is a later look.

**Recommendation: (a).** It costs two poses instead of ~37 frames, keeps every skill visible on the hero, and turns
the block and parry he already has into the build (pillar 1 and 3). Open for Sapega: keep `iron_shield` as an
invisible armour piece, or remove it from the hero's gear (default: remove).

### 3.2 The trees under D728: one base + one path

With only one path ever shown, overlaps *between* paths stop mattering (a player never sees both Heaven's Anvil and
Dune Quake). What matters is that base + the chosen path is one kit with no repeats, and that each path plays
differently. D535's 19 per tab (10 active, 9 passive) stays.

**Base — Holy Warrior (everyone, before and after the census): swordplay and the core loop.**
- Actives (10): Healing Palm, Fire Strike, Electric Strike, Dash Strike, Rising Slash, **Pommel Strike** (was Shield
  Bash), Ground Slam, **Javelin** (was Holy Javelin: a plain thrown spear, no light), Battle Cry, Counter Stance.
- Passives (9): Toughness, **Steady Guard** (was Shield Block), Devotion, Weapon Training, Fortitude, Riposte
  Instinct, Last Stand, Keen Edge, Heavy Hand.
- Open: rename the tree itself for the no-god player («Holy Warrior» → e.g. «Village Warrior»)? Default: keep.

**Samal (Paladin): protector, light, mercy.**
- Actives (10): Radiant Smite, **Samal's Blessing** (was Skyfall Blessing), **Samal's Judgement** (ultimate, was
  Judgement of the Sky), **Samal's Advance** (was Shield Charge), Lightspear (Holy Javelin's light goes here), Aegis,
  Hallowed Circle, Rally, Heaven's Anvil, Radiant Flare.
- Passives (9): Mending Hands, Aura of Resolve, **Samal's Grace** (was Sky's Grace), Aura of Valour → **Shelter**
  (your companion takes 20% less damage; was +25 HP, a repeat of Toughness), Unbroken Vow → **Unbroken Vow** reworked
  (once a fight, a killing blow leaves you at 1 HP; was a second −8%), Merciful Light, Zealous Answer → **Answer of
  Light** (a parry heals you a little; was a repeat of Riposte Instinct), Consecrated Ground, **Samal's Mercy** (was
  Shield of Faith).

**The god of contracts (Dark Knight): power for a price, curses.**
- Actives (10): Searing Hex, Withering Grasp → **Binding Contract** (mark one enemy: it takes 30% more from you, you
  take 10% more from everything while it lives; was a second burning strike), Eclipse Cleave (ultimate), Blood Rush,
  Chain of Night, Blood Price, Night Reaper (made a thrown crescent so it no longer repeats the ultimate), Dread
  Howl, Hellfire Stomp, Soul Harvest.
- Passives (9): Blood Pact, Dread Aura → **Debt of Pain** (+1 attack per 10% HP missing; was a plain +4 attack),
  Relentless, Hoarded Ward → **Collateral** (each kill restores 2 SP; was a plain −8%), Crimson Thirst → **Signed in
  Blood** (when SP runs short a skill takes the rest from HP; was a repeat of Blood Pact), Desperate Hunger, Cruel
  Momentum, Dark Riposte → **Cursed Riposte** (a parry sets the attacker burning; was a repeat of Riposte Instinct),
  Embers Within.

**No god (Warden of Balance): discipline, movement, counters.**
- Actives (10): Balanced Strike, Dervish Whirl, Second Wind (ultimate → **Second Wind** reworked: refills SP and
  makes the next 3 s of dodges free and longer; a heal ultimate repeats Healing Palm), Wind Step, Sand Veil, Stone
  Palm, Sweeping Arc → **Sidestep Cut** (a short hop back, then a lunge; was a repeat of Ground Slam), Mirror Stance,
  Centered Breath (SP only, no HP, so it does not repeat the flask), Dune Quake.
- Passives (9): **Read the Blow** (was Bulwark), Sand Stance, Iron Body → **Untouched** (+10% damage while you have
  not been hit this fight; was a repeat of Toughness), Unshakable → **Steady Feet** (a hit taken while rolling does
  not stagger; was a repeat of Fortitude), Perfect Balance, Still Water, Dervish Rhythm, Rooted Resolve, Light Feet.

**Moves, merges and cuts, in one list:** Holy Javelin → base «Javelin» (its light merges into Lightspear); Counter
Stance stays base; Shield Bash, Shield Block, Shield Charge, Shield of Faith, Bulwark reworked (3.1); renamed for
D718: Sky's Grace, Skyfall Blessing, Judgement of the Sky; reworked because they repeated a stat in the same kit:
Aura of Valour, Unbroken Vow, Zealous Answer, Withering Grasp, Dread Aura, Hoarded Ward, Crimson Thirst, Dark Riposte,
Iron Body, Unshakable, Second Wind, Sweeping Arc, Centered Breath (narrowed), Night Reaper (narrowed). Nothing is cut
outright: each tab keeps 19. Numbers, as for every draft, come with each build slice.

## 4. Art queue for the orchestrator (kept skills)

### Hero poses (`Sprites/Player/<Pose>/`, Windup + Release at least, with `WeaponView.CAST_POSES` anchors)

Today: `CastPalm`, `CastFire`, `CastStorm`, 2 frames each; `Meditate` exists and can be reused.

| # | Pose | For | Note |
|---|---|---|---|
| 1 | **DashCut** — low lunge, blade forward | Dash Strike, Blood Rush, Wind Step | can start from `Dash/1–3` |
| 2 | **RisingSlash** — crouch, cut upward | Rising Slash | |
| 3 | **PommelJab** — short jab with the hilt | Pommel Strike, Stone Palm (open palm variant) | |
| 4 | **LeapSlam** — jump up, slam down | Ground Slam, Heaven's Anvil, Dune Quake, Hellfire Stomp | 3–4 frames |
| 5 | **Throw** — overhand throw | Javelin, Lightspear, Chain of Night, Sand Veil, Night Reaper | |
| 6 | **Shout** — chest out, head back | Battle Cry, Dread Howl, Rally | |
| 7 | **Stance** — guard hold + counter release | Counter Stance, Mirror Stance, Aegis | |
| 8 | **Spin** — full turn with the blade out | Dervish Whirl | 3–4 frames; replaces the wrong fist-up pose |
| 9 | **ShoulderCharge** — run shoulder-first | Samal's Advance | |
| 10 | **Kneel** — one knee, weapon planted | Hallowed Circle, Samal's Blessing | Centered Breath reuses `Meditate` |
| 11 | **Execute** — downward stab | Soul Harvest | |
| 12 | **BloodOath** — palm cut on the blade | Blood Price, Binding Contract | |
| 13 | **Ultimates**, one pose each (3–4 frames): Samal's Judgement (two-hand blade raised, light), Eclipse Cleave (huge overhead two-hand cleave), Second Wind (breath out, dust ring) | the three ultimates | D491 asked for «its own cast»; today they borrow shared poses |
| 14 | **SidestepCut** — hop back, lunge | Sidestep Cut | can reuse DashCut's release |

Also: the three existing cast poses are 2 frames each; a third, middle frame for each would smooth them (low
priority). With proposal (b) instead, every pose here also needs a shield version.

### VFX (`Scenes/FX/Skills/` or frames in `Assets/FX/Skills/<id>/` for `OathSkill.tscn`)

Built and present: Healing Palm, Fire Strike, Electric Strike + the 9 oath actives (radiant_smite, skyfall_blessing,
judgement_of_the_sky, searing_hex, withering_grasp, eclipse_cleave, balanced_strike, dervish_whirl, second_wind).
Reworked ones need new frames: Binding Contract (a curse mark, not Withering Grasp's fire), Second Wind (SP/dash
burst, not a heal).

Missing (one each): Dash Strike (speed streak), Rising Slash (upward arc), Pommel Strike (impact star), Ground Slam
(dust ring), Javelin (spear + trail), Battle Cry (shout rings), Counter Stance (guard glint + counter flash),
Samal's Advance (light shell), Lightspear (light line), Aegis (light barrier), Hallowed Circle (ground circle),
Rally (link to the companion), Heaven's Anvil (light pillars), Radiant Flare (flash), Blood Rush (blood trail), Chain
of Night (chain), Blood Price (blood sigil), Night Reaper (thrown crescent), Dread Howl (dark rings), Hellfire Stomp
(fire pool), Soul Harvest (soul wisp), Wind Step (afterimage), Sand Veil (sand cloud), Stone Palm (palm shock),
Sidestep Cut (afterimage + arc), Mirror Stance (reflect flash), Centered Breath (calm aura), Dune Quake (sand wave),
plus Binding Contract and Second Wind above — **30 in all**.

Passive feedback (small, not scenes): a heal sparkle on Samal's Mercy, a flame flick on Cursed Riposte, an
afterimage on Read the Blow.

### Icons
New icons for the reworked and renamed skills (D601/D603 kit): Steady Guard, Pommel Strike, Javelin, Samal's
Advance, Samal's Mercy, Shelter, Answer of Light, Binding Contract, Debt of Pain, Collateral, Signed in Blood, Cursed
Riposte, Read the Blow, Untouched, Steady Feet, Sidestep Cut — 16. The D718 renames can keep their icons.
