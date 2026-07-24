## SkillInfo — turns a skill + the unit casting it into player-facing numbers and the
## round icon chip, shared by the battle info box, the unit dossier and the skill detail
## modal so all three read the SAME figures.
##
## The magnitude formula mirrors [method BattleEngine.preview_magnitude] (scaling stat ×
## power ÷ 100) rather than calling the engine, because the dossier is opened outside a
## battle (squad, workshop, tree) where no engine exists. One formula, stated once.
class_name SkillInfo
extends RefCounted

const STAT_LABELS := {
	&"physical_power": "Physical Power",
	&"energy_power": "Energy Power",
	&"processing": "Processing",
	&"armor": "Armor",
	&"resistance": "Resistance",
	&"mobility": "Mobility",
	&"targeting": "Targeting",
	&"structure": "Structure",
}

const TARGET_LABELS := {
	SkillDef.TargetMode.SELF: "Self",
	SkillDef.TargetMode.SINGLE_ALLY: "One ally",
	SkillDef.TargetMode.ALL_ALLIES: "Whole squad",
	SkillDef.TargetMode.LOWEST_HP_ALLY: "Most hurt ally",
	SkillDef.TargetMode.SINGLE_ENEMY: "One enemy",
	SkillDef.TargetMode.ALL_ENEMIES: "All enemies",
	SkillDef.TargetMode.RANDOM_ENEMY: "Random enemy",
}


## Pre-defense magnitude for a damage/heal/shield skill from this caster's stats.
static func magnitude(unit: BattleUnit, skill: SkillDef) -> int:
	return unit.stat(skill.scaling_stat) * skill.power_percent / 100


## Detail rows as [label, value] pairs — what the skill detail modal lists below its
## header. Damage, its stat basis, every effect, target, and the cost.
static func detail_rows(unit: BattleUnit, skill: SkillDef, ult_cost: int) -> Array:
	var rows: Array = []
	var stat_label: String = STAT_LABELS.get(skill.scaling_stat, "Power")
	for effect in skill.effects:
		match int(effect.get("kind", SkillDef.EffectKind.INVALID)):
			SkillDef.EffectKind.DAMAGE:
				rows.append(["Base power", "%d%% of %s" % [skill.power_percent, stat_label]])
				rows.append(["Damage now", "≈ %d  (before the target's defense)"
					% magnitude(unit, skill)])
			SkillDef.EffectKind.HEAL:
				rows.append(["Repairs", "≈ %d structure  (%d%% of %s)"
					% [magnitude(unit, skill), skill.power_percent, stat_label]])
			SkillDef.EffectKind.SHIELD:
				rows.append(["Shield", "≈ %d  (%d%% of %s)"
					% [magnitude(unit, skill), skill.power_percent, stat_label]])
			SkillDef.EffectKind.APPLY_STATUS:
				rows.append(["Effect", _status_detail(effect)])
			SkillDef.EffectKind.CLEANSE:
				rows.append(["Effect", "Removes all debuffs"])
			SkillDef.EffectKind.REVIVE:
				rows.append(["Effect", "Revives at %d%% structure"
					% int(effect.get("percent", 25))])
	rows.append(["Target", TARGET_LABELS.get(skill.target_mode, "—")])
	if skill.is_ultimate:
		rows.append(["Ult charge", "%d / %d" % [
			mini(unit.ultimate_charge, ult_cost), ult_cost]])
	elif skill.cooldown > 0:
		rows.append(["Cooldown", "%d turns" % skill.cooldown])
	return rows


## One APPLY_STATUS effect in words: the status name, its stat mods or per-turn amount,
## and how long it lasts.
static func _status_detail(effect: Dictionary) -> String:
	var name := StatusEffect.kind_name(int(effect.get("status", 0)))
	var turns := int(effect.get("turns", 1))
	var parts: PackedStringArray = []
	var mods: Dictionary = effect.get("percent_mods", {})
	for key in mods:
		var v := int(mods[key])
		parts.append("%s%d%% %s" % ["+" if v >= 0 else "", v, STAT_LABELS.get(key, String(key))])
	var flats: Dictionary = effect.get("flat_mods", {})
	for key in flats:
		var v := int(flats[key])
		parts.append("%s%d %s" % ["+" if v >= 0 else "", v, STAT_LABELS.get(key, String(key))])
	var tick := int(effect.get("tick_amount", 0))
	if tick != 0:
		parts.append("%d per turn" % tick)
	var body := ", ".join(parts)
	if body.is_empty():
		return "%s for %d turns" % [name, turns]
	return "%s — %s for %d turns" % [name, body, turns]


## The round icon chip from the mockup: the skill's art in a coloured ring. Amber for
## ults, cyan for everything else.
static func round_chip(skill: SkillDef, diameter: float) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(diameter, diameter)
	chip.add_theme_stylebox_override("panel", _ring(skill, diameter))
	chip.add_child(SkillIcons.make(skill, diameter * 0.6,
		UIPalette.AMBER if skill.is_ultimate else UIPalette.CYAN))
	return chip


## The same round chip as a BUTTON — tapping it opens the skill's detail modal. The icon
## and ring live inside so the whole disc is the tap target.
static func round_button(skill: SkillDef, diameter: float, on_pressed: Callable) -> Button:
	var accent := UIPalette.AMBER if skill.is_ultimate else UIPalette.CYAN
	var button := Button.new()
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.add_theme_stylebox_override("normal", _ring(skill, diameter))
	button.add_theme_stylebox_override("hover", _ring(skill, diameter, 0.12))
	button.add_theme_stylebox_override("pressed", _ring(skill, diameter, 0.2))
	button.add_theme_stylebox_override("focus", _empty())
	button.pressed.connect(on_pressed)
	var icon := SkillIcons.make(skill, diameter * 0.6, accent)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	button.add_child(icon)
	return button


static func _ring(skill: SkillDef, diameter: float, lighten: float = 0.0) -> StyleBoxFlat:
	var accent := UIPalette.AMBER if skill.is_ultimate else UIPalette.CYAN
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UIPalette.INK, 0.6).lightened(lighten)
	box.set_corner_radius_all(int(diameter * 0.5))
	box.corner_detail = 12
	box.anti_aliasing_size = 1.0
	box.set_border_width_all(2)
	box.border_color = accent
	box.set_content_margin_all(int(diameter * 0.18))
	return box


static func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()
