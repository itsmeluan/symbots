## Art — convention-based sprite resolver (asset pipeline entry point).
##
## Resolves a pixel-art texture from an entity/category by the naming convention documented
## in assets/art/README.md: res://assets/art/<category>/<id>.png. Returns null when no art
## has been authored yet, so every call site can fall back to its placeholder and the game
## keeps running through the whole art-migration (drop a PNG in → it appears, no code edit).
##
## Pure static helper — no state, no autoload slot (keeps the ADR-0004/0007 roster fixed).
class_name Art
extends RefCounted

const ROOT := "res://assets/art"


## Texture for [param category] (folder under assets/art/) + [param id] (file stem), or
## null if the PNG does not exist yet. [param id] accepts String or StringName.
static func texture(category: String, id) -> Texture2D:
	var path := "%s/%s/%s.png" % [ROOT, category, String(id)]
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	return null


## True when authored art exists for this category+id.
static func has(category: String, id) -> bool:
	return ResourceLoader.exists("%s/%s/%s.png" % [ROOT, category, String(id)], "Texture2D")
