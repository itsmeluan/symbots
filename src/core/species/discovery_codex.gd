## DiscoveryCodex — which species MARKS the player has discovered (Core Design §2).
##
## "Discovered" means obtained (owning an instance reveals every mark up to its own,
## since a Retrofit walks through them) or seen fielded in a battle the player watched.
## Anything else renders as a black silhouette in unit info — the collection tease.
##
## Keyed per (species, mark) rather than per species because meeting a wild Mk I reveals
## nothing about what its Mk III looks like — that reveal is the reward for meeting one.
##
## Plain RefCounted with dict serialization, following the StageProgress idiom; owned by
## [ServiceContext] and persisted through [V1StateProvider].
class_name DiscoveryCodex
extends RefCounted

## String(species_id) -> int bitmask; bit (mark - 1) set means that mark is discovered.
## String keys, not StringName — this dict round-trips through JSON (ADR-0001).
var _seen: Dictionary = {}


## Record one (species, mark) as seen — a unit fielded in a visible battle.
func mark_seen(species_id: StringName, mark: int) -> void:
	if species_id == &"":
		return
	var key := String(species_id)
	_seen[key] = int(_seen.get(key, 0)) | (1 << (clampi(mark, 1, 3) - 1))


## Record ownership: an owned Mk N instance has been every mark up to N.
func mark_owned(species_id: StringName, up_to_mark: int) -> void:
	for m in range(1, clampi(up_to_mark, 1, 3) + 1):
		mark_seen(species_id, m)


func is_discovered(species_id: StringName, mark: int) -> bool:
	return int(_seen.get(String(species_id), 0)) & (1 << (clampi(mark, 1, 3) - 1)) != 0


func to_dict() -> Dictionary:
	return {"seen": _seen.duplicate()}


## In-place restore, so every service holding this reference sees the loaded state.
func load_dict(raw: Dictionary) -> void:
	_seen.clear()
	var seen_raw: Dictionary = raw.get("seen", {})
	for key in seen_raw:
		_seen[String(key)] = int(seen_raw[key])
