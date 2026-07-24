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


## Corner-rounding fraction of a skill tile's edge — small, so the square reads as a
## square with softened corners, not a rounded button.
const TILE_RADIUS_FRAC := 0.16

## Rounds the corners of the skill art itself: the sprite FILLS the tile edge to edge and
## only its corner pixels are masked away, so the coloured border traces the real sprite
## edge instead of framing a shrunken image inside a box.
const MASK_SHADER := "
shader_type canvas_item;
uniform float radius : hint_range(0.0, 0.5) = 0.16;
void fragment() {
	vec2 p = min(UV, vec2(1.0) - UV);
	vec2 c = max(vec2(radius) - p, vec2(0.0));
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(radius - 0.012, radius, length(c));
}"

static var _mask_material: ShaderMaterial = null


static func _mask() -> ShaderMaterial:
	if _mask_material == null:
		var shader := Shader.new()
		shader.code = MASK_SHADER
		_mask_material = ShaderMaterial.new()
		_mask_material.shader = shader
		_mask_material.set_shader_parameter(&"radius", TILE_RADIUS_FRAC)
	return _mask_material


## The square skill TILE from the mockup as a BUTTON — tap it for the skill's detail. The
## sprite fills the rounded square; a border in the skill's accent (amber for ults, cyan
## otherwise) hugs that exact edge.
static func square_button(skill: SkillDef, size: float, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(size, size)
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", _backing(size))
	button.add_theme_stylebox_override("hover", _backing(size, 0.06))
	button.add_theme_stylebox_override("pressed", _backing(size, 0.12))
	button.add_theme_stylebox_override("focus", _empty())
	button.pressed.connect(on_pressed)
	_fill_tile(button, skill, size)
	return button


## The same tile, non-interactive — the detail modal's header wears one.
static func square_chip(skill: SkillDef, size: float) -> Control:
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(size, size)
	tile.clip_contents = true
	tile.add_theme_stylebox_override("panel", _backing(size))
	_fill_tile(tile, skill, size)
	return tile


## Lay the art (masked to rounded corners) and the accent border into a tile control.
static func _fill_tile(tile: Control, skill: SkillDef, size: float) -> void:
	var accent := UIPalette.AMBER if skill.is_ultimate else UIPalette.CYAN
	var tex := SkillIcons.texture_for(skill.id)
	if tex != null:
		var art := TextureRect.new()
		art.texture = tex
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# SCALE fills the square exactly; the icons are near-square so aspect drift is
		# tiny, and a clean 0..1 UV is what lets the corner mask line up with the border.
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		art.material = _mask()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(art)
	else:
		var holder := CenterContainer.new()
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(Glyph.make(Glyph.for_skill(skill), size * 0.55, accent))
		tile.add_child(holder)
	tile.add_child(_border(size, accent))


static func _backing(size: float, lighten: float = 0.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UIPalette.INK, 0.6).lightened(lighten)
	box.set_corner_radius_all(int(size * TILE_RADIUS_FRAC))
	box.corner_detail = 12
	box.anti_aliasing_size = 1.0
	return box


static func _border(size: float, accent: Color) -> Panel:
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_corner_radius_all(int(size * TILE_RADIUS_FRAC))
	box.corner_detail = 12
	box.anti_aliasing_size = 1.0
	box.set_border_width_all(2)
	box.border_color = accent
	frame.add_theme_stylebox_override("panel", box)
	return frame


static func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()
