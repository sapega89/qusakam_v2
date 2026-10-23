extends RefCounted

## 💬 SkillTooltip — підказка навички за Diablo II (D496): поточний ранг, наступний ранг і синергії.
##
## Числа беруться з тих самих формул SkillManager, що й бій (skill_damage / skill_heal, B137), тож підказка не бреше.
## Текст — ключі en.po / uk.po. Новий екран навичок (D489) малює data().lines; нинішній показує effect_text().


## {rank, max_rank, current, next, synergies, lines}: current / next — values() на поточному / наступному ранзі
## (порожньо, якщо навичку не вивчено / ранг найвищий); synergies — [{skill, name, per_rank, rank, bonus}].
static func data(skills: SkillManager, skill_id: String) -> Dictionary:
	var definition: SkillDefinition = skills.skill_database.get_skill(skill_id)
	var rank := skills.get_rank(skill_id)
	var result := {
		"rank": rank,
		"max_rank": SkillManager.MAX_RANK,
		"current": values(skills, definition, rank) if rank > 0 else {},
		"next": values(skills, definition, rank + 1) if rank < SkillManager.MAX_RANK else {},
		"synergies": [],
		"lines": [],
	}
	for synergy: Dictionary in definition.synergies:
		var source: SkillDefinition = skills.skill_database.get_skill(String(synergy.skill))
		var source_rank := skills.get_rank(source.id)
		result.synergies.append({"skill": source.id, "name": source.name, "per_rank": float(synergy.per_rank),
				"rank": source_rank, "bonus": float(synergy.per_rank) * source_rank})
	result.lines = _lines(skills, definition, result)
	return result


## Що навичка дає на ранзі [param rank]: damage / heal — з атакою героя і синергіями, passive — значення пасивки.
static func values(skills: SkillManager, definition: SkillDefinition, rank: int) -> Dictionary:
	return {
		"damage": skills.skill_damage(definition.id, rank),
		"heal": skills.skill_heal(definition.id, rank),
		"burn_dps": definition.burn_dps,
		"passive": definition.passive_value * (1.0 + SkillManager.RANK_BONUS * (rank - 1)),
		"sp_cost": definition.sp_cost,
		"cooldown": definition.cooldown,
		"charges": definition.charges,
	}


static func _lines(skills: SkillManager, definition: SkillDefinition, tooltip: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var rank: int = tooltip.rank
	if definition.ultimate:
		lines.append(TranslationServer.translate("Ultimate · cooldown %d s") % roundi(definition.cooldown))
	if definition.charges > 0:
		lines.append(TranslationServer.translate("Flask: %d / %d sips, refilled when you save")
				% [skills.get_charges(definition.id), definition.charges])
	if rank > 0:
		lines.append(TranslationServer.translate("Rank %d: %s") % [rank, effect_text(skills, definition, rank)])
	if not tooltip.next.is_empty():
		lines.append(TranslationServer.translate("Next rank: %s") % effect_text(skills, definition, rank + 1))
	if not tooltip.synergies.is_empty():
		lines.append(TranslationServer.translate("Receives bonuses from:"))
		for synergy: Dictionary in tooltip.synergies:
			lines.append(TranslationServer.translate("%s: +%s%% per rank (now +%s%%)")
					% [TranslationServer.translate(String(synergy.name)), _percent(synergy.per_rank), _percent(synergy.bonus)])
	return lines


## Ефект навички на ранзі [param rank] (0 — як на першому) одним рядком: «172 dmg, burn 4/s» / «−15% damage taken (below 30% HP)».
static func effect_text(skills: SkillManager, definition: SkillDefinition, rank: int) -> String:
	var at_rank := maxi(1, rank)
	var parts: Array[String] = []
	if definition.damage > 0:
		parts.append(TranslationServer.translate("%d dmg") % skills.skill_damage(definition.id, at_rank))
	if definition.heal > 0:
		parts.append(TranslationServer.translate("heal %d") % skills.skill_heal(definition.id, at_rank))
	if definition.charges > 0:
		parts.append(TranslationServer.translate("%d sips") % definition.charges)
	if definition.burn_dps > 0:
		parts.append(TranslationServer.translate("burn %d/s") % definition.burn_dps)
	if definition.chain_radius > 0.0:
		parts.append(TranslationServer.translate("chain ×%s") % String.num(definition.chain_ratio, 1))
	if definition.stun > 0.0:
		parts.append(TranslationServer.translate("stun %s s") % String.num(definition.stun, 1))
	if not definition.is_active() and not definition.passive_stat.is_empty():
		var passive := _passive_text(definition.passive_stat, definition.passive_value * (1.0 + SkillManager.RANK_BONUS * (at_rank - 1)))
		var condition := _condition_text(definition)
		parts.append(passive if condition.is_empty() else TranslationServer.translate("%s (%s)") % [passive, condition])
	return ", ".join(parts)


static func _passive_text(stat: String, value: float) -> String:
	match stat:
		"max_health": return TranslationServer.translate("+%d max HP") % roundi(value)
		"max_sp": return TranslationServer.translate("+%d max SP") % roundi(value)
		"attack": return TranslationServer.translate("+%d attack") % roundi(value)
		"shield_block": return TranslationServer.translate("−%s%% damage with a shield") % _percent(value)
		"damage_reduction": return TranslationServer.translate("−%s%% damage taken") % _percent(value)
		"heal_power": return TranslationServer.translate("heals +%s%%") % _percent(value)
		"sp_per_hit": return TranslationServer.translate("+%s SP per hit") % String.num(value, 2)
		"lifesteal": return TranslationServer.translate("hits heal %s%%") % _percent(value)
		"poise": return TranslationServer.translate("+%s%% poise damage") % _percent(value)
		"skill_damage": return TranslationServer.translate("skills +%s%%") % _percent(value)
		"crit_chance": return TranslationServer.translate("+%s%% crit") % _percent(value)
		"heavy_poise": return TranslationServer.translate("heavy attack +%s%% poise damage") % _percent(value)
		"block_heal": return TranslationServer.translate("a shield block heals %s%%") % _percent(value)
		"burning_damage": return TranslationServer.translate("+%s%% damage to burning enemies") % _percent(value)
		"roll_length": return TranslationServer.translate("roll +%s%%") % _percent(value)
	assert(false, "SkillTooltip: no text for passive stat %s" % stat)
	return ""


## D496: умова пасивки словами; без умови — "".
static func _condition_text(definition: SkillDefinition) -> String:
	match definition.passive_condition:
		"":
			return ""
		"below_hp":
			return TranslationServer.translate("below %s%% HP") % _percent(definition.passive_condition_value)
		"after_parry":
			return TranslationServer.translate("%s s after a parry") % String.num(definition.passive_condition_value, 1)
		"after_skill":
			return TranslationServer.translate("%s s after a skill") % String.num(definition.passive_condition_value, 1)
	assert(false, "SkillTooltip: no text for condition %s" % definition.passive_condition)
	return ""


static func _percent(fraction: float) -> String:
	return String.num(fraction * 100.0, 1).trim_suffix(".0")
