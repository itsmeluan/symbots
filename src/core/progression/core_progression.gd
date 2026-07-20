## CoreProgression — the CORE's level, earned from battle XP only (Symbot Core Progression GDD).
##
## The CORE is the leveled anchor of a Symbot: parts supply stats, the core supplies a
## floor that grows with play. Level is what gates equipping high-tier parts, so a player
## cannot buy power — Scrap upgrades parts, but only fighting raises the core.
##
## PURE — no autoload, no scene, no signals into the tree. Owns a record per core
## instance and derives level from cumulative XP. Injected into [SymbotBuild], which
## calls [method can_equip] before every equip and [method get_level] for display.
##
## LEVEL IS DERIVED, NEVER STORED AS TRUTH (GDD Rule 2). `cumulative_xp` is the fact; the
## level is a lookup over it, re-derived on every read path that matters. A stored level
## is a cache for display, and a cache that can disagree with its source is a bug waiting
## for a save-file migration to expose it.
class_name CoreProgression
extends RefCounted

## Emitted when a core crosses one or more thresholds. Carries BOTH endpoints so a future
## consumer that unlocks per-level content can iterate the span; multiple levels gained at
## once emit ONCE with the full span, never once per level (GDD Rule 2).
signal core_leveled_up(core_instance_id: StringName, old_level: int, new_level: int)

const MAX_CORE_LEVEL := 10

## CP-F1 pre-computed thresholds: cumulative XP required to BE this level, indexed by
## level - 1. The GDD is explicit that this table is used directly at runtime rather than
## re-running the ramp formula — a sorted-integer lookup has no float arithmetic in it,
## so a core's level cannot drift by a rounding difference between two call sites.
const XP_THRESHOLDS: Array[int] = [
	0, 100, 220, 364, 537, 744, 993, 1292, 1650, 2080,
]

## core_instance_id -> {cumulative_xp: int, level: int}
var _records: Dictionary = {}
var _log: LogSink = null


func _init(log: LogSink = null) -> void:
	_log = log


## Create a record for a core the player now owns. Called on first acquisition.
## Re-registering is a no-op with a warning — it must never reset XP, because the most
## likely cause is a double-call, and silently zeroing a player's progress is worse than
## a duplicate record (GDD Rule 1).
func register_core(core_instance_id: StringName) -> void:
	if _records.has(core_instance_id):
		_warn(&"core_already_registered", {"core": String(core_instance_id)})
		return
	_records[core_instance_id] = {"cumulative_xp": 0, "level": 1}


func has_core(core_instance_id: StringName) -> bool:
	return _records.has(core_instance_id)


## Award XP and re-derive level. Returns the new level. Unknown cores are registered on
## the spot rather than dropping the award — losing XP the player earned is the worse
## failure, and the warning still surfaces the wiring gap.
func add_xp(core_instance_id: StringName, amount: int) -> int:
	if amount <= 0:
		return get_level(core_instance_id)
	if not _records.has(core_instance_id):
		_warn(&"core_xp_unregistered", {"core": String(core_instance_id)})
		register_core(core_instance_id)
	var rec: Dictionary = _records[core_instance_id]
	var old_level: int = rec["level"]
	rec["cumulative_xp"] = int(rec["cumulative_xp"]) + amount
	var new_level := _level_for_xp(rec["cumulative_xp"])
	rec["level"] = new_level
	if new_level > old_level:
		core_leveled_up.emit(core_instance_id, old_level, new_level)
	return new_level


## Level of a specific core, or 1 when unknown — an unregistered core is treated as
## brand new rather than as an error, so a missing record never blocks equipping.
func get_level(core_instance_id: StringName = &"") -> int:
	if core_instance_id == &"":
		return _active_level()
	var rec = _records.get(core_instance_id)
	return int(rec["level"]) if rec != null else 1


func get_xp(core_instance_id: StringName) -> int:
	var rec = _records.get(core_instance_id)
	return int(rec["cumulative_xp"]) if rec != null else 0


## Cumulative XP required for the next level, and how far into it this core is.
## Returns `{level, xp, into, needed, is_max}` for a progress readout. `needed` is 0 at
## the cap so a UI can show a full bar rather than dividing by zero.
func progress(core_instance_id: StringName) -> Dictionary:
	var level := get_level(core_instance_id)
	var xp := get_xp(core_instance_id)
	if level >= MAX_CORE_LEVEL:
		return {level = level, xp = xp, into = 0, needed = 0, is_max = true}
	var floor_xp := XP_THRESHOLDS[level - 1]
	var next_xp := XP_THRESHOLDS[level]
	return {
		level = level, xp = xp,
		into = xp - floor_xp, needed = next_xp - floor_xp, is_max = false,
	}


## Equip gate (GDD Rule 4). A part with no level requirement is always allowed, so the
## gate costs nothing for the vast majority of parts.
func can_equip(part: PartDef) -> bool:
	if part == null or part.level_requirement <= 0:
		return true
	return _active_level() >= part.level_requirement


## CP-F3 — flat per-stat bonus from the equipped core's authored growth table.
## `level_growth[stat] × (level - 1)`, so level 1 contributes exactly zero and a fresh
## player is never quietly stronger than their parts say.
func level_contribution(core_part: PartDef, core_instance_id: StringName) -> Dictionary:
	var out: Dictionary = {}
	if core_part == null:
		return out
	var steps := get_level(core_instance_id) - 1
	if steps <= 0:
		return out
	for stat_key: StringName in core_part.level_growth:
		out[stat_key] = int(core_part.level_growth[stat_key]) * steps
	return out


## Snapshot/restore for the save envelope. Level is NOT written: it is re-derived from
## cumulative_xp on restore, so a threshold retune applies to existing saves instead of
## leaving every returning player on a stale curve.
func snapshot() -> Dictionary:
	var out: Dictionary = {}
	for id in _records:
		out[String(id)] = int(_records[id]["cumulative_xp"])
	return out


func restore(data: Dictionary) -> void:
	_records.clear()
	for id in data:
		# JSON gives every number as float; XP is an integer counter and leaving it as a
		# float would poison the threshold comparison (ADR-0001 impl guideline).
		var xp := int(data[id])
		if xp < 0:
			_warn(&"core_xp_negative", {"core": str(id), "xp": xp})
			xp = 0
		_records[StringName(str(id))] = {"cumulative_xp": xp, "level": _level_for_xp(xp)}


## ADR-0001 provider triad. Nothing to do: restore() already re-derives every level from
## cumulative XP, so the records are consistent the moment restore returns. Declared
## because the triad is the contract the service calls, not because there is work here.
func rederive() -> void:
	pass


## The highest level among owned cores. With one Symbot — the MVP case — this is simply
## that core's level. It exists so the equip gate has an answer before the caller knows
## which core is installed.
func _active_level() -> int:
	var best := 1
	for id in _records:
		best = maxi(best, int(_records[id]["level"]))
	return best


func _level_for_xp(xp: int) -> int:
	var level := 1
	for i in XP_THRESHOLDS.size():
		if xp >= XP_THRESHOLDS[i]:
			level = i + 1
		else:
			break
	return mini(level, MAX_CORE_LEVEL)


func _warn(code: StringName, detail: Dictionary) -> void:
	if _log != null:
		_log.warn(code, detail)
