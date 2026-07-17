## Test double for SynergySystem's silent-evaluation seam (Story 002).
##
## preload()-ed, NOT class_name-declared (keeps the production global registry clean).
## Records how many times `evaluate_silent` was called and exposes a `cached_bonus_block`
## exactly like the real system. Carries a `synergy_changed` signal it NEVER emits from
## `evaluate_silent` — the start-sequence test connects it to prove the controller took
## the SILENT path (AC-TBC-01: exactly N evaluate_silent calls, zero synergy_changed).
extends RefCounted

signal synergy_changed()

var cached_bonus_block: Dictionary = {"stat_delta": {}, "effects": []}
var evaluate_silent_calls: int = 0
var last_parts_seen: Array = []

## Optional canned delta returned for every evaluation (default: no synergy).
var _canned_delta: Dictionary = {}


func set_canned_delta(delta: Dictionary) -> void:
	_canned_delta = delta


func evaluate_silent(parts: Array) -> void:
	evaluate_silent_calls += 1
	last_parts_seen = parts
	cached_bonus_block = {"stat_delta": _canned_delta.duplicate(), "effects": []}
