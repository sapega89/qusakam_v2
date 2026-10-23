---
type: plan
status: planned
tags: [skills, class-path, feedback]
figma: "menu-skills 58:453"
---

# Skill trees and the class path — plan (BACKLOG 22)

**Built 2026-10-21** (slices 1–5; tests `verify_skill_trees`, `verify_skill_trees_ui`, `verify_oath`; captures `fb22_*.png` in the session scratchpad, made by `capture_skill_trees.gd`). Left: see *Out of scope*. Sapega's frame is D260 (level cap 99, one point per level, every skill gated by level, Holy
Warrior → oath at 5 → subclass at 40 → prestige at 70, the oath sworn in the City before a priest / a witch / a sand
dervish). Q66's defaults apply (points reset for a price, the oath is permanent, names are drafts). Every call this
plan makes is an **agent call, Sapega to confirm**: D279–D285.
Figma: `menu-skills 58:453` — two flat columns (Primary / Secondary Class Tree), Job Skills / Support Skills sections,
no graph ([[skills_ui_mapping]]). Feedback rules: [[play_feedback_queue]]. Builds on [[skills_system_plan]] (the model),
[[skills_combat_plan]] (execution), D150 ranks, D207 effects, D259/D269 interrupts, D271 casts.

## v2: 19 skills per tab (D535), draft for Sapega, 2026-10-23

**Status: planned. The list is waiting for Sapega to read it.** He counted Dragon Nest's Gladiator: 19 skills in the Warrior tab and 19 in the Gladiator tab, with **10 active and 9 passive** in each, and not all of them can be learned. After `cloud/skills-data` our base tree has 10 skills (3 active) and each oath has 11 (3 active).

The draft adds **33 new skills**:
- the base tree gets 7 actives and 2 passives;
- each of the three oaths gets 7 actives and 1 passive.

Names and effects are drafts (`[DRAFT]` / `[ЧЕРНЕТКА]` once they are in data). Numbers come with each build slice.

Each tab gets every role Dragon Nest gives a tab:
- a gap closer;
- a launch or knock-down;
- an area hit;
- a ranged hit;
- a stance;
- a buff;
- a control;
- a finisher;
- sustain;
- (oaths only) the level-20 ultimate.

No skill puts the hero behind an enemy (Sapega: «за спину ми нікому не зможемо забігти»). No skill uses stamina: stamina is out for now (D551).

### Holy Warrior (base): 10 active, 9 passive

| Lv | Skill | Kind | Does | |
|---|---|---|---|---|
| 1 | Toughness | passive | +max HP | exists |
| 1 | Shield Block | passive | less damage with a shield | exists |
| 1 | **Dash Strike** | active | dashes forward and cuts the first enemy, stops at it (bodies block, D443) | new |
| 2 | Healing Palm | active | the 3-sip flask (D527) | exists |
| 3 | Devotion | passive | +max SP | exists |
| 3 | **Rising Slash** | active | an upward cut that throws light enemies into the air | new |
| 4 | Weapon Training | passive | +attack | exists |
| 4 | **Shield Bash** | active | breaks a wind-up and deals heavy guard damage (D495); uses the pommel when there is no shield | new |
| 6 | Fire Strike | active | burns | exists |
| 6 | Electric Strike | active | stuns, chains to one more enemy | exists |
| 8 | Riposte Instinct | passive | after a parry, skills hit harder | exists (draft) |
| 8 | **Ground Slam** | active | knocks down everyone close, on both sides | new |
| 10 | Last Stand | passive | below 30 % HP, less damage | exists (draft) |
| 10 | **Holy Javelin** | active | throws a spear of light; the base tree's ranged hit | new |
| 12 | Fortitude | passive | less damage | exists |
| 12 | **Battle Cry** | active | +attack for a while; weak enemies close by flinch | new |
| 14 | **Counter Stance** | active | a short stance: a blow taken in it is blocked and answered hard (not red unblockable attacks) | new |
| 14 | **Keen Edge** | passive | critical hits come more often (D393) | new |
| 16 | **Heavy Hand** | passive | the heavy attack deals more guard damage | new |

### Paladin: 10 active, 9 passive

| Lv | Skill | Kind | Does | |
|---|---|---|---|---|
| 5 | Radiant Smite | active | light strike, dazes | exists |
| 5 | Mending Hands | passive | stronger healing | exists |
| 5 | **Shield Charge** | active | runs forward behind the shield, knocks enemies back | new |
| 8 | Aura of Resolve | passive | less damage | exists |
| 8 | Merciful Light | passive | at low HP, stronger healing | exists (draft) |
| 8 | **Lightspear** | active | a spear of light that pierces every enemy in a line | new |
| 10 | Sky's Grace | passive | more SP from hits and parries | exists |
| 10 | Zealous Answer | passive | after a parry, skills hit harder | exists (draft) |
| 10 | **Aegis** | active | a barrier of light that soaks damage for a few seconds | new |
| 10 | **Hallowed Circle** | active | holy ground: enemies in it burn with light, and the hero and the companion heal slowly | new |
| 12 | Skyfall Blessing | active | strike and heal | exists |
| 15 | Aura of Valour | passive | +max HP | exists |
| 15 | Consecrated Ground | passive | after a skill, less damage | exists (draft) |
| 15 | **Rally** | active | the next companion assist hits harder and stays longer (still one at a time, D515) | new |
| 15 | **Heaven's Anvil** | active | leap and slam, pillars of light on both sides | new |
| 18 | Unbroken Vow | passive | less damage | exists |
| 18 | **Radiant Flare** | active | a flash that dazes every enemy around and clears burning and curses from the hero | new |
| 18 | **Shield of Faith** | passive | a block with a shield heals a little | new |
| 20 | Judgement of the Sky | ultimate | the oath's ultimate (D528) | exists |

### Dark Knight: 10 active, 9 passive

| Lv | Skill | Kind | Does | |
|---|---|---|---|---|
| 5 | Searing Hex | active | dark fire strike | exists |
| 5 | Blood Pact | passive | weapon hits heal | exists |
| 5 | **Blood Rush** | active | a dash to the enemy; the hit drinks HP | new |
| 8 | Dread Aura | passive | +attack | exists |
| 8 | Desperate Hunger | passive | at low HP, more lifesteal | exists (draft) |
| 8 | **Chain of Night** | active | a dark chain pulls one enemy to the hero | new |
| 10 | Relentless | passive | faster guard break | exists |
| 10 | Cruel Momentum | passive | after a skill, +attack | exists (draft) |
| 10 | **Blood Price** | active | pay some HP: the next three hits deal much more | new |
| 10 | **Night Reaper** | active | a wide, long crescent of dark fire | new |
| 12 | Withering Grasp | active | lingering dark fire | exists |
| 15 | Hoarded Ward | passive | less damage | exists |
| 15 | Dark Riposte | passive | after a parry, skills hit harder | exists (draft) |
| 15 | **Dread Howl** | active | weak enemies flee for a moment, strong ones flinch | new |
| 15 | **Hellfire Stomp** | active | leaves a pool of dark fire on the ground | new |
| 18 | Crimson Thirst | passive | more lifesteal | exists |
| 18 | **Soul Harvest** | active | executes an enemy with a broken guard or under 20 % HP, gives SP back | new |
| 18 | **Embers Within** | passive | burning enemies take more damage from the hero | new |
| 20 | Eclipse Cleave | ultimate | the oath's ultimate (D528) | exists |

### Warden of Balance: 10 active, 9 passive

| Lv | Skill | Kind | Does | |
|---|---|---|---|---|
| 5 | Balanced Strike | active | measured strike, stuns | exists |
| 5 | Bulwark | passive | less damage with a shield | exists |
| 5 | **Wind Step** | active | a quick step forward with a cut and a moment of invulnerability | new |
| 8 | Sand Stance | passive | faster guard break | exists |
| 8 | Still Water | passive | after a parry, less damage | exists (draft) |
| 8 | **Sand Veil** | active | sand in the eyes: enemies in front miss for a few seconds | new |
| 10 | Iron Body | passive | +max HP | exists |
| 10 | Dervish Rhythm | passive | after a skill, faster guard break | exists (draft) |
| 10 | **Stone Palm** | active | an open palm: huge guard damage, little HP damage | new |
| 10 | **Sweeping Arc** | active | a low sweep that knocks down everyone in front | new |
| 12 | Dervish Whirl | active | spinning strike | exists |
| 15 | Unshakable | passive | less damage | exists |
| 15 | Rooted Resolve | passive | at low HP, faster guard break | exists (draft) |
| 15 | **Mirror Stance** | active | a short stance that sends arrows and projectiles back | new |
| 15 | **Centered Breath** | active | a short meditation in battle: restores some HP and SP; a hit breaks it | new |
| 18 | Perfect Balance | passive | +attack | exists |
| 18 | **Dune Quake** | active | leap and slam; a sand wave both ways knocks enemies down | new |
| 18 | **Light Feet** | passive | the roll goes further and stays invulnerable a little longer | new |
| 20 | Second Wind | ultimate | the oath's ultimate (D528) | exists |

### What the new actives need that does not exist yet

Today `SkillCombatExecutor` has one shape: a hit in front, with burn, stun, daze, chain or heal riders. It has three poses: `CastFire`, `CastStorm` and `CastPalm`.

The new actives need:
- a **dash** and a **leap-slam**, where the hero moves during the skill;
- a **projectile** (the bow's arrow is the model);
- **stances** for counter and reflect (the parry window is the model);
- timed **buffs** (the D529 "for N s after…" passives are the model);
- **ground zones**;
- new enemy states: **launched**, **knocked down**, **blinded** and **feared**;
- a **pull**;
- an **execute** on a broken guard (D495, `cloud/combat-enemies`).

Around the skills themselves the work also needs:
- hero poses for the new actives;
- 33 icons (with D455);
- the skills screen at 19 nodes a tab, with `485:6490` redrawn first.

### v2 slices (each its own branch and test)

1. **Data and passives.**
   - Add the 33 rows to `skills.json` as drafts.
   - Make the 5 new passives work.
   - The new actives exist in data but cannot be learned until their slice lands.
   - Re-tune the JP caps (D530) so a full tab cannot be maxed.
   - Test: `verify_skill_rules`.
2. **Skills screen at 19 a tab.** Claude redraws Figma `485:6490`, then the screen is built (with D489 and D490).
3. **Movement skills:** Dash Strike, Shield Charge, Blood Rush, Wind Step, Heaven's Anvil, Dune Quake.
4. **Ranged and zones:** Holy Javelin, Lightspear, Hallowed Circle, Hellfire Stomp.
5. **Stances and buffs:** Counter Stance, Mirror Stance, Centered Breath, Battle Cry, Aegis, Blood Price, Rally.
6. **Control and finishers:** Rising Slash, Ground Slam, Sweeping Arc, Shield Bash, Stone Palm, Chain of Night, Sand Veil, Dread Howl, Radiant Flare, Night Reaper, Soul Harvest. Soul Harvest goes in after `cloud/combat-enemies`.
7. **Art batch (ComfyUI lane):** hero poses for the new actives, icons, effects.

**Order:**
- Slice 1, then slice 2.
- Slices 3–6 in any order. In slice 6, Soul Harvest waits for the guard bar.
- Slice 7 runs alongside the rest.

**Open:** Q86 (hotbar slots, answered: D549). Icons for every skill: [[skill_icons_brief]].

## What exists today

| Thing | Where | State |
|---|---|---|
| Skill data, 5 skills | `Resources/Data/skills.json` | ✅ Healing Palm L2 (D261), Fire / Electric Strike L6, Toughness, Shield Block |
| Definition + validation | `Scripts/Systems/SkillDefinition.gd:62` `from_dict` | ✅ `class_id`, `subclass_id`, `required_level`, `prerequisites`, effects |
| Database autoload | `Scripts/Systems/SkillDatabase.gd:30` | ✅ reads `skills` only |
| Learn / rank / slots / cast | `Scripts/Managers/Gameplay/SkillManager.gd:288` `can_unlock`, `:306` `unlock_skill`, `:94` `upgrade_skill`, `:456` `cast_skill` | ✅ level gate, prerequisites, JP cost |
| Points per level | `SkillManager.gd:40` `JP_PER_LEVEL := 2` (D149) | ⚠️ D260 says 1 |
| Passive stats | `SkillManager.gd:119` `passive_value(stat)`; read at `GameManager.gd:201` (max_health), `Player.gd:430` (shield_block) | ✅ two stats only |
| Level | `Scripts/Managers/XPManager.gd:36` `_check_level_up` | ⚠️ no cap |
| Class of the hero | `PlayerStateManager.gd:29` `class_id "champion"`, `subclass_id "paladin"`; names in `pathfinder_classes.json` empty | ⚠️ the subclass is overwritten from `CharacterManager` on every equip (`CharacterManager.gd:303`) — unfit to hold the oath |
| Skills screen | `Scripts/Menus/Game/skills_component.gd:109` `_rebuild_columns` — left = class skills + classless, right = `subclass_id` skills | ✅ keyboard/pad rows; ❌ a mouse cannot learn (B77) |
| NPC menu with actions | `Scripts/Gameplay/NPCs/NpcBase.gd:43` `menu_entries`, `UI/Components/npc_action_menu.gd` | ✅ Talk / Quest / custom ids, pad + keys |
| Coins | `InventoryManager.gd:64` `add_coins / get_coins / spend_coins` | ✅ |
| City | `Maps/City.tscn` — 3 cells (2592 px), save point x 600, merchant trigger x 800, Blacksmith x 1100 (feet y 396) | ✅ |

`grep -rn "oath\|respec" SampleProject/Scripts` → 0 hits: oath, respec, trees and the oath NPCs are missing entirely.

## Decisions (agent calls, Sapega to confirm)

- **D279 Trees.** One trunk, **Holy Warrior**, open to everyone, and three oath trees — **Light: Paladin**,
  **Dark: Dark Knight**, **Neutral: Warden of Balance**. A skill names its tree in a new `oath` field
  (`""` = trunk). The five existing skills stay in the trunk at their levels (Healing Palm L2 D261, Fire / Electric
  Strike L6 D149, Toughness / Shield Block L1) — no one loses what they learned. Oath skills start at level 5.
  Costs: 1 point up to level 10, 2 points from 12, 3 from 30. **One point per level** (D260; amends D149's 2).
  Ranks stay (D150). Every new active is cast (D271) with an existing pose and an existing effect — Radiant Smite
  and Judgement reuse CastStorm + a gold-tinted `ElectricStrike`, the Dark hexes CastFire + a violet `FireStrike`,
  the Warden strikes CastFire + a sand `FireStrike`, heals CastPalm + `HealingPalm`.
- **D280 Oath.** Stored as `player_state.oath` (`""`, `paladin`, `dark_knight`, `warden`), saved by
  `PlayerDataModule` — not `subclass_id`, which `CharacterManager` rewrites. `SkillManager.swear_oath(id)`: level ≥ 5,
  no oath yet, else a `Result`. Permanent (Q66). An oath skill of another oath: `OTHER_OATH`; before the oath:
  `NO_OATH`. Class title: `Holy Warrior` → the oath's name (`Paladin` …); subclass (40) and prestige (70) are data
  only, shown in the plan, not built.
- **D281 The oath NPCs.** In the City, east of the Blacksmith: **Sister Ilvane, priest of the Sky** (Paladin, x 1500),
  **Morrow the witch** (Dark Knight, x 1850), **Kesh the sand dervish** (Warden, x 2200). Menu: Talk (a draft
  `.dqd`), **Swear the oath** (level ≥ 5 and no oath; level < 5 the entry still shows and the dialogue says to come
  back at level 5), then a second menu **"I swear — <Oath> (permanent)" / "Not yet"** — the one choice in the game
  (D113 said no choice UI; this reuses the NPC menu, not a dialogue choice box). After the oath the sworn NPC's Talk
  says so. Generated art, two views (D243): front when idle, profile turned to the hero while the menu is open.
- **D282 Respec.** Any of the three oath NPCs: **"Unlearn skills (N coins)"**, N = **10 × level**, shown when
  anything is learned; a confirm menu as above. Refunds every point spent (cost + ranks above 1), forgets every skill,
  empties the hotbar; the oath stays. Not enough coins → the entry is still there, the confirm says so.
- **D283 Skills screen.** The Figma layout stays: left column = the trunk (title "Holy Warrior", subtitle "Primary
  Class Tree"), right column = an oath tree with **three tabs** (TabButton, as Inventory) — Paladin · Dark Knight ·
  Warden; before the oath any tab can be browsed, rows locked "Swear an oath in the City (level 5)"; after it the
  sworn tab opens first, the other two stay browsable and read "Sworn to another oath". The header class line shows
  the class title (D280). Tabs and rows are reached with focus (keys / pad); **a double click learns** (fixes B77).
- **D284 New passive stats.** `max_sp` (SkillManager `get_max_sp`), `attack` (`GameManager.calculate_physical_damage`,
  shows in Status Phys. Atk.), `damage_reduction` (`Player.mitigated_damage`), `heal_power` (heals ×(1+v)),
  `sp_regen` (+v SP/s), `lifesteal` (weapon hits heal v × damage, `PlayerCombat._on_damage_applied`), `poise`
  (×(1+v) poise damage). Reductions are capped: each multiplier at most 0.75 off.
- **D285 Sources and credits.** Shapes adapted from the **Pathfinder 2e Champion** (Paizo, ORC licence — holy causes
  ≈ Light, unholy ≈ Dark) and the **D&D 5e SRD 5.1 Paladin** (Wizards of the Coast, CC BY 4.0 — Lay on Hands, Divine
  Smite, auras, Channel Divinity, oaths); Neutral from martial/defensive features (Shield Block, Toughness, stances).
  All names and texts are ours; credits in `CREDITS.md`.
- **XP cap.** `XPManager.MAX_LEVEL = 99` — at 99 XP stops counting, no more level-ups (D260).

## The trees (levels 1–20 built; later tiers outlined)

A = active (SP / cooldown / cast pose), P = passive (value at rank 1, +10 % per rank, D150).

### Trunk — Holy Warrior (everyone)

| id | Name | Lv | Cost | Kind | Effect | From |
|---|---|---|---|---|---|---|
| toughness | Toughness | 1 | 1 | P | +10 max HP | existing |
| shield_block | Shield Block | 1 | 1 | P | −20 % damage with a shield | existing |
| healing_palm | Healing Palm | 2 | 0 | A | heal 40 · 5 SP · 4 s · CastPalm | existing, D261 |
| devotion | Devotion | 3 | 1 | P | +5 max SP | Channel Divinity's pool, reshaped |
| weapon_training | Weapon Training | 4 | 1 | P | +3 attack | martial training |
| fire_strike | Fire Strike | 6 | 1 | A | 20 + burn · sword/dagger | existing |
| electric_strike | Electric Strike | 6 | 1 | A | 25 + chain + stun · polearm/mace | existing |
| fortitude | Fortitude | 12 | 2 | P | −5 % damage taken | Divine Health, reshaped |

### Light — Paladin (Oath of the Sky; priest)

| id | Name | Lv | Cost | Kind | Effect | Needs | From |
|---|---|---|---|---|---|---|---|
| radiant_smite | Radiant Smite | 5 | 1 | A | 24 dmg, stun 0.3 s · 6 SP · 3 s · CastStorm | — | Divine Smite / Retributive Strike |
| mending_hands | Mending Hands | 5 | 1 | P | heals +25 % | — | Lay on Hands |
| aura_of_resolve | Aura of Resolve | 8 | 1 | P | −8 % damage taken | — | Aura of Protection |
| skys_grace | Sky's Grace | 10 | 1 | P | +0.5 SP/s | — | Channel Divinity |
| skyfall_blessing | Skyfall Blessing | 12 | 2 | A | 28 dmg + heal 20 · 12 SP · 8 s · CastPalm | radiant_smite | Sacred Weapon + Lay on Hands |
| aura_of_valour | Aura of Valour | 15 | 1 | P | +25 max HP | — | Aura of Courage |
| judgement_of_the_sky | Judgement of the Sky | 18 | 2 | A | 45 dmg, chain 160 px ×0.6, stun 0.6 · 16 SP · 10 s · CastStorm | skyfall_blessing | Improved Smite / Blade of Justice |
| unbroken_vow | Unbroken Vow | 20 | 2 | P | −8 % damage taken | aura_of_resolve | Aura of Devotion |

### Dark — Dark Knight (Oath of the Eclipse; witch)

| id | Name | Lv | Cost | Kind | Effect | Needs | From |
|---|---|---|---|---|---|---|---|
| searing_hex | Searing Hex | 5 | 1 | A | 18 dmg + burn 5/s 4 s · 6 SP · 3 s · CastFire | — | Touch of Corruption |
| blood_pact | Blood Pact | 5 | 1 | P | weapon hits heal 10 % of damage | — | unholy cause, drain |
| dread_aura | Dread Aura | 8 | 1 | P | +4 attack | — | Destructive Vengeance |
| relentless | Relentless | 10 | 1 | P | +25 % poise damage | — | Tyrant's iron command |
| withering_grasp | Withering Grasp | 12 | 2 | A | 34 dmg + burn 6/s 3 s · 12 SP · 7 s · CastFire | searing_hex | harmful touch |
| hoarded_ward | Hoarded Ward | 15 | 1 | P | −8 % damage taken | — | Selfish Shield |
| eclipse_cleave | Eclipse Cleave | 18 | 2 | A | 50 dmg, chain 160 px ×0.5, burn 8/s 3 s · 18 SP · 10 s · CastFire | withering_grasp | — |
| crimson_thirst | Crimson Thirst | 20 | 2 | P | weapon hits heal 10 % more | blood_pact | — |

### Neutral — Warden of Balance (Oath of the Sands; dervish)

| id | Name | Lv | Cost | Kind | Effect | Needs | From |
|---|---|---|---|---|---|---|---|
| balanced_strike | Balanced Strike | 5 | 1 | A | 26 dmg, stun 0.5 s · 5 SP · 2.5 s · CastFire | — | martial strike |
| bulwark | Bulwark | 5 | 1 | P | −10 % more with a shield | shield_block | Shield Block |
| sand_stance | Sand Stance | 8 | 1 | P | +30 % poise damage | — | stances |
| iron_body | Iron Body | 10 | 1 | P | +20 max HP | toughness | Toughness |
| dervish_whirl | Dervish Whirl | 12 | 2 | A | 30 dmg, chain 140 px ×0.6 · 10 SP · 6 s · CastStorm | balanced_strike | Whirlwind |
| unshakable | Unshakable | 15 | 1 | P | −10 % damage taken | — | Juggernaut |
| second_wind | Second Wind | 18 | 2 | A | heal 60 · 14 SP · 20 s · CastPalm | — | Second Wind |
| perfect_balance | Perfect Balance | 20 | 2 | P | +8 attack | dervish_whirl | — |

Budget check: levels 2–10 give 9 points; trunk 1–4 costs 4, the oath's two level-5 picks 2, a strike at 6 is 1,
the level-8 pick 1 — level 10 leaves one point for a rank. Every level up to 10 has something new to take.

### Later tiers — outlined, not built

| Lv | Trunk | Light | Dark | Neutral |
|---|---|---|---|---|
| 25 | Holy Vigour (+max HP) | Aura of Warding (magic dmg −) | Soul Harvest (SP on kill) | Shield Bash (A, stun) |
| 30 | — | Cleansing Touch (A, removes burn/stun) | Night's Embrace (A, lifesteal burst) | Counter Stance (parry window +) |
| 35 | Steel Resolve | Wings of the Sky (A, aerial smite) | Dread Brand (A, mark) | Sandstep (dash +1) |
| **40 subclass** | — | **Sky Warden** / **Dragon Crusader** | **Lord of Ash** / **Oathreaper** | **Sand Warden** / **Wandering Blade** |
| 45–65 | 3 skills per subclass (one active, two passive) per 10 levels | | | |
| **70 prestige** | — | **Avatar of the Sky** | **Lord of the Eclipse** | **Keeper of Balance** |
| 75–99 | prestige capstones, one per 5 levels | | | |

Subclass at 40 is chosen at the same NPC (a second `swear`), stored as `player_state.oath_subclass`; prestige at 70
is automatic. Both wait for a world that reaches level 40 (BACKLOG 23).

## Slices

### Slice 1 — data + SkillManager (points, gates, trees, oath lock, new passives)
- `skills.json` (+`oaths` block, `oath` field, 24 new skills), `SkillDefinition.gd` (`oath`), `SkillDatabase.gd`
  (`oaths`), `SkillManager.gd` (`JP_PER_LEVEL = 1`, `swear_oath`, `get_oath`, `class_title`, `NO_OATH`/`OTHER_OATH`,
  `get_max_sp`, `sp_regen`, `heal_power`), `PlayerStateManager.gd` + `PlayerDataModule.gd` (`oath`), `EventBus.gd`
  (`oath_sworn`, `skills_reset`), `GameManager.gd` (attack), `Player.gd` (damage_reduction, refresh on reset),
  `PlayerCombat.gd` (lifesteal, poise), three tinted effect scenes in `Scenes/FX/Skills/`.
- `verify_skill_trees.gd`. Commit.

### Slice 2 — XP cap 99
- `XPManager.gd` `MAX_LEVEL`. Check in `verify_skill_trees.gd`. Commit.

### Slice 3 — Skills screen tree view
- `skills_component.tscn` (TreeTabs row in the right panel), `skills_component.gd` (trunk / oath columns, tabs,
  reasons, class title, double click). `verify_skill_trees_ui.gd` (real mouse double click, focus to tabs, pad accept);
  `verify_skills_ui.gd` fixtures move from `subclass_id` to `oath`. Commit.

### Slice 4 — oath NPCs, the oath choice, respec
- `Scripts/Gameplay/NPCs/OathKeeper.gd` (on `NpcBase`), `Scenes/.../NPCs/oath_keeper_{priest,witch,dervish}.tscn`,
  art via `comfy_sprite.py priest|witch|dervish`, `dialogue_quest/City_Oath_*.dqd` (drafts) + three `DQCharacter`s,
  `Maps/City.tscn`, `SkillManager.respec`. `verify_oath.gd`. Commit.

### Slice 5 — captures, exe, registers
- Skills screen, the three NPCs in the City, the oath menu → `fb22_*.png`; rebuild the exe; BACKLOG / queue / D-IDs.

## Out of scope for this pass

Left after the build: the oath keepers stand in front of the hero (z-index, as the Blacksmith — item 14);
the tinted effects only darken the originals (modulate cannot shift hue) — Searing Hex reads dark red, Balanced
Strike close to Fire Strike; the Skills right column scrolls (8 rows + tabs), its scrollbar touches NEXT SKILL COST.
Subclass (40) and prestige (70) content and choice (outline above); new cast poses or effects per new skill (reuse,
D271/D273 — listed as left); balance (numbers are mock, as D150); a respec without an NPC; Status screen showing the oath.
