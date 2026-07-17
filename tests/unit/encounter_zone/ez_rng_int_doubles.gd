## Integer RNG test doubles for Encounter Zone EZ-2 (weighted selection) specs.
##
## Preload this and use the inner class:
##   const IntRng := preload("res://tests/unit/encounter_zone/ez_rng_int_doubles.gd")
##   var rng := IntRng.QueuedInt.new([10, 16, 20])   # randi_range returns these in order
##
## IMPORTANT (RNG-ptrcall memory, shared with DropSystem): EncounterResolver draws via
## `call(&"randi_range", …)` on purpose — a statically-typed `rng.randi_range()` would
## ptrcall past this GDScript override and silently draw a real value. The override also
## needs `@warning_ignore("native_method_override")` or GUT's warnings-as-errors config
## fails the whole file to parse.
extends RefCounted


## RNG stub whose `randi_range(from, to)` returns a fixed sequence of rolls (consumed
## in call order), then repeats the final value. `from`/`to` are ignored — the scripted
## roll is asserted by the caller to already sit inside the intended [1, total] range.
class QueuedInt:
	extends RandomNumberGenerator
	var _rolls: Array[int] = []
	var _idx: int = 0
	var call_count: int = 0

	func _init(rolls: Array[int] = []) -> void:
		_rolls = rolls

	@warning_ignore("native_method_override")
	func randi_range(from: int, _to: int) -> int:
		call_count += 1
		if _idx < _rolls.size():
			var v: int = _rolls[_idx]
			_idx += 1
			return v
		return _rolls[-1] if _rolls.size() > 0 else from
