## SkillIcons — authored pixel-art icons per skill id (assets/art/icons/skills/<id>.png),
## with the code-drawn [Glyph] as the graceful fallback for anything not yet painted.
##
## The lookup is by filename convention, same as the creature art: the file IS the
## binding, so adding an icon is dropping a PNG — no registry to edit, nothing to forget.
class_name SkillIcons
extends RefCounted

const DIR := "res://assets/art/icons/skills/"

static var _cache: Dictionary = {}


static func texture_for(skill_id: StringName) -> Texture2D:
	if _cache.has(skill_id):
		return _cache[skill_id]
	var path := DIR + String(skill_id) + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[skill_id] = tex
	return tex


## An icon Control for a skill: the authored texture when it exists, else the glyph in
## [param fallback_colour]. Always [param px] square, never intercepts taps.
static func make(skill: SkillDef, px: float, fallback_colour: Color) -> Control:
	var tex := texture_for(skill.id)
	if tex == null:
		return Glyph.make(Glyph.for_skill(skill), px, fallback_colour)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(px, px)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# The generated icons are ~200px downscaled to chip size — LINEAR keeps them smooth
	# where NEAREST would shimmer.
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
