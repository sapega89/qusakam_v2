# Skills — discovery and plan

**Nothing implemented.** This is a survey plus a proposal.
No class definitions invented; no JP/SP invented.

## What actually exists today

| Thing | Where | State |
|---|---|---|
| `player_state.unlocked_skills: Array` | `PlayerStateManager.gd:17` | ✅ exists, **saved and loaded** by `PlayerDataModule` (working since the Phase 5.2A save fix) |
| `SaveSystem.add_unlocked_skill(name)` | `SaveSystem.gd:322` | ✅ append-only string list. No remove, no query, no validation |
| `Player.abilities: Array[StringName]` | `Player.gd:15` | ✅ **a second, unrelated list** — traversal abilities, saved through MetSys (`Game.gd:238/344`), read by `PlayerMover.gd:77` for `double_jump` |
| `GameGroups.SKILL_POINTS_UI` | `GameGroups.gd` | ⚠️ constant declared, never used |
| `VFXHooks.gd` | `Systems/` | ✅ exists — usable for skill VFX |
| Figma `menu-skills` `58:453` | Figma | ✅ fully designed |
| Docs | `CLAUDE_FULL.md:4099`, `IMPLEMENTATION_COMPLETE.md:303` | "Skill tree (using XP/level system)" listed as **future work** |

### Missing entirely

Skill resource/class · skill data file · `SkillManager` · EventBus skill signals
(`grep skill` on `EventBus.gd` → **0 hits**) · combat integration · cooldowns ·
skill assignment/hotbar · JP · SP/mana · class/subclass data.

### Input actions

`project.godot` defines only `move_left/right/up/down`, `jump`, `attack`.
**No skill-use action exists.** Adding any is a design decision.

### ⚠️ Two competing "skill" concepts

`unlocked_skills` (in `player_state`, saved by our SaveSystem) and
`Player.abilities` (saved by MetSys) are separate lists with no shared code.
`abilities` is the only one that currently *does* anything (`double_jump`).

**GAME DESIGN DECISION REQUIRED:** are these one system or two? Recommendation:
keep `abilities` as metroidvania **traversal unlocks** and build Skills as combat
abilities on `unlocked_skills` — but confirm.

---

## The twelve questions

### 1. What is a Skill in this game?
**Undefined.** Nothing in code or docs defines one. Figma implies a
class-tree-unlocked combat ability. **GAME DESIGN DECISION REQUIRED.**

### 2. Active, passive, or both?
No evidence either way. Figma's Skills frame splits **Job Skills** and **Support
Skills**, which reads as active vs passive — but nothing in code supports either.
**GAME DESIGN DECISION REQUIRED.**

### 3. What data structure should represent a skill?
Nothing exists. The project's established pattern is JSON + a database autoload
(`items.json` → `ItemDatabase`), so a `skills.json` + `SkillDatabase` would match
conventions exactly. Proposed minimal shape:

```json
{ "id": "shadow_strike", "name": "Shadow Strike",
  "description": "...", "type": "active|passive",
  "requires": ["..."], "cost": 0, "cooldown": 0.0 }
```

### 4. How are skills unlocked?
Only mechanism today: `SaveSystem.add_unlocked_skill(name)` — an untyped string
append with no gating. Figma shows unlock **by spending JP inside a class tree**,
which needs both JP and class data. Neither exists.
**GAME DESIGN DECISION REQUIRED.**

### 5. Is there any mana/SP/JP resource?
**No.**
- **SP** — appears in Figma (party cards, Status `Max. SP`) but has no model.
  `CharacterAttributes` holds only strength/intelligence/dexterity/constitution.
- **JP** — appears in Figma (Status `JP Obtained`, Skills `NEXT SKILL COST`).
  Zero occurrences in code.
- **Stat points** — explicitly **excluded** from this project
  (`"Исключены … stat_points"` in `CharacterManager` and `PlayerStateManager`).

What *does* exist: `InventoryManager.coins`, `XPManager` (xp + level),
`HealthComponent` (HP), and potions.

### 6. What should skills consume?
Must not be invented. Three viable options:

| Option | Requires | Notes |
|---|---|---|
| **A. Nothing (cooldown-only)** | nothing new | Smallest. Works with today's architecture. |
| **B. Add SP** | new field on `CharacterAttributes` + save migration + HUD | Matches Figma. Largest. |
| **C. Reuse HP** | nothing new | Works, but a design statement. |

**GAME DESIGN DECISION REQUIRED.** Recommendation: **A** for the first slice.

### 7. How are cooldowns represented?
Nothing exists. `TimeManager` is a pause manager, not a timer service. Godot
`Timer` nodes or a `float` accumulator in a manager are the natural options.

### 8. How should a skill be equipped/assigned?
No hotbar, no assignment UI, no input action. Figma's Skills screen shows a
**tree**, not an assignment surface. **GAME DESIGN DECISION REQUIRED.**

### 9. How should skills be saved?
**Already solved.** `player_state.unlocked_skills` round-trips through
`PlayerDataModule` and is covered by `verify_core_wiring.gd`. A list of skill ids
needs no new save code. Cooldowns should be runtime-only.

### 10. How should skills connect to combat?
Existing surface: `Player.gd:174` (`attack` action) → `combat.perform_attack()`
on `PlayerCombat`; `DamageApplier` / `HealthComponent` apply damage; `VFXHooks`
for effects; `EventBus` for broadcast. A skill would need a new input action and
a `perform_skill(id)` entry point on `PlayerCombat`. None exists.

### 11. How does the Figma Skills UI map to the gameplay model?

| Figma element | Backing today | Verdict |
|---|---|---|
| Character header, name | `CharacterManager` | ✅ available |
| `JP OBTAINED: 928 JP` | — | ❌ **no JP system** |
| `SHADOW BLADE` / `THIEF` tree headers | — | ❌ **needs class data** (missing `pathfinder_classes.json`) |
| `NEXT SKILL COST: 5,000 JP` | — | ❌ **no JP** |
| Job Skills / Support Skills lists | — | ❌ no skill data |
| Learned ✓ / locked / `???` states | `unlocked_skills` could drive learned-vs-not | ⚠️ partially available |
| Selected-skill description box | — | ❌ no descriptions |
| Primary/Secondary class columns | — | ❌ **needs class data** |

**Roughly 80% of the Skills frame depends on systems that do not exist.**

### 12. What depends on the missing class data?
`pathfinder_classes.json` was **never implemented** (see
`design/investigation_pathfinder_classes.md`). Blocked by it:
- both class-tree column headers,
- the primary/secondary split itself,
- any per-class skill list,
- Status `PRIMARY JOB` / `SECONDARY JOB` (already deviation D14).

A class-tree Skills screen **cannot be built** until class data exists.

---

## Smallest viable Skills implementation

Works with today's architecture, invents nothing, adds no fake resource.

**Scope: flat list of unlockable passive/active skills, no JP, no class trees.**

1. **`SkillDatabase` autoload + `Resources/Data/skills.json`** — mirrors
   `ItemDatabase`/`items.json` exactly. Fields: `id`, `name`, `description`,
   `type` (`active`/`passive`), `requires` (skill ids), `cooldown`.
2. **`SkillManager`** extending `ManagerBase`, registered in `ServiceLocator`
   like every other manager. API: `is_unlocked(id)`, `unlock(id)`,
   `get_unlocked()`, `can_unlock(id)`. Backed by the existing
   `player_state.unlocked_skills` — **no new save code**.
3. **EventBus signals**: `skill_unlocked(id)`, `skill_used(id)` — matching the
   existing equipment-signal pattern.
4. **Skills screen** rendering the flat list with learned / available / locked
   states, styled from the Figma skill-row component (`UI/Skills/SkillRow`
   `222:4734` has exactly those states). Unlock via a button, gated by
   `can_unlock()`.
5. **Unlock currency: none initially.** Gate on level (`XPManager.get_level()`)
   and prerequisites — both already exist. JP can be layered on later without
   reshaping the data.
6. **Combat: deferred.** Ship unlock + display first; `perform_skill()` and an
   input action come once the skill list is real.

**Deliberately excluded from the first slice:** JP, SP, class trees, the
primary/secondary split, hotbar assignment, cooldown UI.

**Figma consequence:** the Skills screen would ship visually reduced —
one flat column instead of two class trees, no JP readouts. That is a
**GAME DESIGN DECISION REQUIRED** before implementation: either

- **(a)** author `pathfinder_classes.json` + a JP system and build the Figma
  screen in full, or
- **(b)** accept the reduced screen now and mark Figma as needing an update.

---

## Decisions needed before any Skills code

| # | Decision |
|---|---|
| 1 | What is a Skill — active, passive, or both? |
| 2 | Are `unlocked_skills` and `Player.abilities` one system or two? |
| 3 | Does the project get JP? If not, what gates unlocks? |
| 4 | Does the project get SP? (Also unblocks Status `Max. SP` and party HP/SP.) |
| 5 | Will `pathfinder_classes.json` be authored? Class trees are blocked on it. |
| 6 | Are skills assignable to a hotbar, and which input action triggers them? |
| 7 | Reduced screen now (option b), or full Figma screen after the data exists (option a)? |
