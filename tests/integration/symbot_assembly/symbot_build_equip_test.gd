## Story 002 — SymbotBuild equip (Assembly Rule 3) + starter factory.
## Covers AC-SA-01, AC-SA-04, AC-SA-10, the CoreProgression gate rejection, EC-SA-08.
extends GutTest

const Fixtures = preload("res://tests/unit/symbot_assembly/assembly_fixtures.gd")
const SpyLogSink = preload("res://tests/unit/symbot_assembly/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log
var _inv


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()
	_inv = Fixtures.StubInventory.new()


func _legs(id: StringName, mobility: int = 5) -> Object:
	return Fixtures.make_instance(Fixtures.make_part({
		"id": id, "slot_type": PartDef.SlotType.LEGS,
		"stat_bonuses": {&"mobility": mobility},
	}), 0)


# --- AC-SA-01: slot-type validation ---------------------------------------------

func test_equip_wrong_slot_rejected_no_emit() -> void:
	# Arrange: a WEAPON part offered to the LEGS slot.
	var build := SymbotBuild.new(_cfg, _log, _inv)
	watch_signals(build)
	var weapon := Fixtures.make_instance(Fixtures.make_part({
		"id": &"blaster", "slot_type": PartDef.SlotType.WEAPON,
	}), 0)

	# Act
	var result := build.equip_part(PartDef.SlotType.LEGS, weapon)

	# Assert
	assert_false(result["ok"], "slot-mismatched equip is rejected")
	assert_eq(result["reason"], &"slot_mismatch")
	assert_signal_not_emitted(build, "part_equipped")
	assert_signal_not_emitted(build, "stats_changed")
	assert_eq(_inv.added.size(), 0, "no displacement on a rejected equip")


# --- AC-SA-04: displace occupant to inventory + emit both signals ----------------

func test_equip_displaces_occupant_and_emits() -> void:
	# Arrange: an occupied LEGS slot, then a replacement.
	var old_part := _legs(&"old_legs")
	var build := SymbotBuild.new(_cfg, _log, _inv)
	build.equip_part(PartDef.SlotType.LEGS, old_part)
	watch_signals(build)   # watch only the second (replacement) equip
	var new_part := _legs(&"new_legs")

	# Act
	var result := build.equip_part(PartDef.SlotType.LEGS, new_part)

	# Assert
	assert_true(result["ok"])
	assert_eq(build.get_equipped(PartDef.SlotType.LEGS), new_part, "new part installed")
	assert_true(_inv.added.has(old_part), "displaced occupant returned to Inventory")
	assert_true(_inv.removed.has(new_part), "installed part removed from Inventory")
	assert_signal_emitted_with_parameters(
		build, "part_equipped", [PartDef.SlotType.LEGS, &"new_legs"])
	assert_signal_emitted(build, "stats_changed")


# --- AC-SA-10 / EC-SA-02: same-part no-op ---------------------------------------

func test_equip_same_part_id_is_noop() -> void:
	# Arrange: LEGS occupied; re-equip a *different instance* of the same part id.
	var build := SymbotBuild.new(_cfg, _log, _inv)
	build.equip_part(PartDef.SlotType.LEGS, _legs(&"same_legs"))
	watch_signals(build)
	var inv_adds_before: int = _inv.added.size()

	# Act
	var result := build.equip_part(PartDef.SlotType.LEGS, _legs(&"same_legs"))

	# Assert: reports ok but performs no displacement, no install, no emit.
	assert_true(result["ok"], "no-op still reports success")
	assert_signal_not_emitted(build, "part_equipped")
	assert_signal_not_emitted(build, "stats_changed")
	assert_eq(_inv.added.size(), inv_adds_before, "no displacement on a no-op")


# --- CoreProgression gate rejection ---------------------------------------------

func test_equip_rejected_by_core_level_gate() -> void:
	# Arrange: gate denies the equip.
	var gate := Fixtures.StubCoreProgression.new()
	gate.allow = false
	gate.level = 2
	var build := SymbotBuild.new(_cfg, _log, _inv, gate)
	watch_signals(build)
	var part := Fixtures.make_instance(Fixtures.make_part({
		"id": &"heavy_legs", "slot_type": PartDef.SlotType.LEGS, "level_requirement": 6,
	}), 0)

	# Act
	var result := build.equip_part(PartDef.SlotType.LEGS, part)

	# Assert
	assert_false(result["ok"])
	assert_eq(result["reason"], &"core_level")
	assert_signal_not_emitted(build, "part_equipped")
	assert_eq(_inv.added.size(), 0, "gate rejection performs no displacement")
	assert_eq(_log.warns.size(), 1, "rejection logged for diagnostics")
	assert_eq(_log.warns[0]["code"], &"equip_rejected_core_level")


# --- EC-SA-08: starter factory seeds a valid build ------------------------------

func test_with_starters_populates_final_stat_and_pools() -> void:
	# Arrange: a two-slot starter loadout (LEGS + WEAPON with a known move).
	var move_db := Fixtures.StubDB.new([&"blaster_shot"])
	var starters := {
		PartDef.SlotType.LEGS: _legs(&"start_legs", 10),
		PartDef.SlotType.WEAPON: Fixtures.make_instance(Fixtures.make_part({
			"id": &"start_blaster", "slot_type": PartDef.SlotType.WEAPON,
			"active_skill_id": &"blaster_shot",
		}), 0),
	}

	# Act
	var build := SymbotBuild.with_starters(starters, _cfg, _log, _inv, null, move_db)

	# Assert: derived up-front, no equip needed.
	assert_eq(build.get_final_stat()["mobility"], 10, "starter stats derived at construction")
	assert_eq(build.get_move_pool()[1], &"blaster_shot", "WEAPON move resolved into pool")
	assert_eq(build.get_move_pool()[0], &"basic_attack", "basic attack always slot 0")
