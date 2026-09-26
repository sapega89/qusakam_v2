# Skills — combat vertical slice

Phase 5.5. Proves the Skills Foundation can execute a real combat skill
end-to-end. No UI, no production skill content, no JP rewards.

## 1. The existing combat path (audited before any change)

```
input "attack"  (Player.gd:174)
  └─ PlayerCombat.perform_attack(direction)
       ├─ attack_cooldown  (float accumulator ticked in _process)
       ├─ animation + _set_hitbox_active()
       └─ DamageApplier.enable_damage()
            └─ hitbox body_entered
                 ├─ skips owner_body and already-hit targets
                 ├─ _find_health_component(body)
                 └─ HealthComponent.apply_damage(current_damage, owner_body)
                      └─ IDamageable.safe_take_damage → CombatBody2D.take_damage()
                           ├─ set_meta("last_damage_source", source)
                           └─ register_damage() → health_changed / entity_died → EventBus
```

Damage amount comes from `DamageApplier.update_damage()`, which reads
`IDamageDealer.safe_get_current_damage(owner_body)` — i.e. the player's own
stat pipeline, not a constant.

**Key observation:** `DamageApplier` is **collision-driven**. It answers "what
did my hitbox touch?", which is the wrong question for a skill that already
knows its target. The reusable primitive one level down is
`HealthComponent.apply_damage(amount, source)` — that is what the skill path
reuses, so `take_damage`, the `last_damage_source` meta, death handling and all
EventBus combat signals behave identically to a normal attack.

Relevant EventBus signals already present: `damage_dealt`, `damage_received`,
`attack_started`, `attack_finished`, `enemy_died`, `player_died`.

`VFXHooks` is EventBus-driven (`_connect_to_event_bus`), so skill VFX needs no
new coupling — it can subscribe to `skill_used` when VFX work begins.

## 2. Combat ServiceLocator sites repaired this phase

**None were required.**

`grep Engine.has_singleton("ServiceLocator")` over `Scripts/Combat/**`,
`Scripts/Player/Components/**` and `Player.gd` returns **zero hits** — the
damage path was already clean. The combat-tagged entries still held in
`design/service_locator_audit.md` are in `DefaultEnemy.gd` (4 sites), and all
four concern **`EnemyStateManager`** (enemy state persistence), not damage
application. They remain held, and `verify_skills_combat.gd` demonstrates that
damage lands without them.

No repository-wide replacement was performed.

## 3. Architecture

```
caller (tests today, UI later)
  └─ SkillManager.use_skill(skill_id, target, source)
       ├─ can_use_skill()        unknown / not unlocked / passive / cooldown / SP
       ├─ target required if definition.damage > 0
       ├─ SkillCombatExecutor.execute(definition, source, target)
       │    └─ HealthComponent.apply_damage(definition.damage, source)
       │         └─ (existing pipeline, unchanged)
       ├─ spend_sp(definition.sp_cost)
       ├─ _cooldowns[skill_id] = definition.cooldown
       └─ EventBus.skill_used   /   EventBus.skill_failed
```

**Responsibility split**

| Layer | Owns | Must never |
|---|---|---|
| `SkillManager` | validation, SP, cooldown, events | compute damage, know about hitboxes |
| `SkillCombatExecutor` | applying the effect through existing combat code | own a damage formula, duplicate `DamageApplier` |
| UI (later) | *requesting* a skill | calculate damage |

`combat_executor` is a plain injectable field, so tests can substitute a fake
without touching the manager.

### Ordering guarantee

The effect runs **before** SP is spent and **before** the cooldown starts. If
`execute()` returns `false`, the call fails as `EFFECT_FAILED` having changed
nothing. A failed skill therefore deals no damage, spends no SP and starts no
cooldown — asserted in `verify_skills_combat.gd` §1, §2 and §5.

## 4. Cooldown

Runtime-only `Dictionary` on `SkillManager` (`skill_id → seconds remaining`),
decremented in `_process`. `SkillDefinition.cooldown` stays pure configuration;
no live cooldown is ever written to a definition.

Query API (matching project naming): `can_use_skill()`,
`is_skill_on_cooldown()`, `get_remaining_cooldown()`, `clear_cooldowns()`.

**Not persisted.** Momentary cooldowns are not part of the saved `player_state`
contract, and nothing in the existing architecture requires them to be.
`verify_skills_combat.gd` §9 asserts the save payload contains no `cooldowns`
key. `clear_cooldowns()` exists so a load can reset them deliberately.

## 5. New definition field

One field was added — the minimum needed for a damage skill:

| Field | Type | Meaning |
|---|---|---|
| `damage` | `int`, default `0`, clamped `>= 0` | Direct damage applied via `HealthComponent.apply_damage()`. `0` = the skill deals no direct damage. Forced to `0` for passives. |

It is **configuration, not a formula**. No balance values were added to
production data: `skills.json` still contains an empty `skills` array.

## 6. Events — exact semantics

| Signal | Fires when | Guarantees |
|---|---|---|
| `skill_unlocked(skill_id)` | a skill is successfully learned | JP already deducted, id already in `unlocked_skills` |
| `skill_used(skill_id)` | **success only** — all checks passed, effect executed, SP spent, cooldown started | never fires for a failed attempt |
| `skill_failed(skill_id, reason)` | any rejected attempt; `reason` is a `SkillManager.Result` | no damage, no SP spent, no cooldown started |
| `job_points_changed(current, previous)` | JP value actually changes | not emitted when the value is unchanged |
| `sp_changed(current_sp, max_sp)` | SP value actually changes | not emitted when the value is unchanged |

**`skill_use_requested` was deliberately not added.** It would have no consumer
today and exists only for symmetry, which the brief rules out. `skill_failed`
*does* earn its place: UI error feedback and audio need to distinguish a refused
cast from a silent no-op.

## 7. Input

None added. Tests call `SkillManager.use_skill()` directly. No new input action,
no hotbar, no `equipped_skills` — those remain a separate phase.

## 8. Test fixtures

`verify_skills_combat.gd` defines its own fixtures, marked **TEST-ONLY**, and
injects them with `SkillDatabase.load_from_array()`. Deterministic values
(`damage: 7`, `sp_cost: 10`, `cooldown: 0.25`) exist purely so assertions can be
exact. Production `skills.json` remains free of invented content.

Cooldown expiry is verified by calling `_process(delta)` directly rather than
sleeping, keeping the suite deterministic and fast.

## 9. Coverage — `verify_skills_combat.gd`, 42 assertions

Locked / unknown / passive / no-target rejection · insufficient SP · failed
attempts spend nothing and start no cooldown · successful use damages the
intended target by exactly `damage` · caster recorded as `last_damage_source`
(proving the existing `take_damage` pipeline ran) · unrelated target untouched ·
cooldown starts, blocks reuse, counts down, expires, and the skill becomes
usable again · zero-cost/zero-cooldown skill · `skill_used` fires once on
success and `skill_failed` once on failure · traversal `Player.abilities`
untouched · normal attack entry point intact · Equipment stat pipeline still
working · save payload still valid and free of cooldowns.

All seven suites green after this phase.

## 10. Still out of scope

Figma Skills UI · skill tree · hotbar · `equipped_skills` · JP rewards ·
production skill content · class lore · passive effects · AoE · buffs/debuffs ·
healing · status effects.
