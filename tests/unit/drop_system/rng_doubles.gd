## Shared RNG test doubles for Drop System specs.
##
## Preload this and use the inner classes:
##   const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")
##   var rng := Rng.Const.new(0.30)             # every draw returns 0.30
##   var rng := Rng.Queued.new([0.11, 0.15])    # draws returned in order, then 0.0
##
## IMPORTANT (see the RNG-ptrcall project memory): DropSystem draws via
## `call(&"randf")` on purpose — a statically-typed `rng.randf()` would ptrcall
## past these GDScript overrides and silently draw real random values. Each
## override also needs `@warning_ignore("native_method_override")` or GUT's
## warnings-as-errors config fails the whole file to parse.
extends RefCounted


## RNG stub returning a fixed sequence of draws (consumed in call order), then 0.0.
class Queued:
	extends RandomNumberGenerator
	var _draws: Array[float] = []
	var _idx: int = 0
	var call_count: int = 0

	func _init(draws: Array[float] = []) -> void:
		_draws = draws

	@warning_ignore("native_method_override")
	func randf() -> float:
		call_count += 1
		if _idx < _draws.size():
			var v: float = _draws[_idx]
			_idx += 1
			return v
		return 0.0


## RNG stub returning one constant value for every draw, counting calls.
class Const:
	extends RandomNumberGenerator
	var value: float = 0.0
	var call_count: int = 0

	func _init(v: float) -> void:
		value = v

	@warning_ignore("native_method_override")
	func randf() -> float:
		call_count += 1
		return value
