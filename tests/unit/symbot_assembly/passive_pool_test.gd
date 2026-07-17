## Story 005 — passive-pool derivation.
## Covers AC-SA-09 (Rule-5 collection order), AC-SA-14 (compact list, no phantom nulls),
## EC-SA-04 (missing passive logged + skipped), and the all-common (empty) case.
extends GutTest

const Fixtures = preload("res://tests/unit/symbot_assembly/assembly_fixtures.gd")
const SpyLogSink = preload("res://tests/unit/symbot_assembly/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()


func _part(id: StringName, slot: int, passive: StringName) -> Object:
	return Fixtures.make_instance(Fixtures.make_part({
		"id": id, "slot_type": slot, "passive_id": passive,
	}), 0)


# --- AC-SA-09 / AC-SA-14: Rule-5 order, null slots skipped -----------------------

func test_passive_pool_follows_slot_order_and_skips_nulls() -> void:
	# Arrange: passives on WEAPON and CORE only. Rule 5 collects CORE before WEAPON,
	# regardless of the order the manifest happens to store them in.
	var passive_db := Fixtures.StubDB.new([&"pass_core", &"pass_weapon"])
	var starters := {
		PartDef.SlotType.WEAPON: _part(&"lance", PartDef.SlotType.WEAPON, &"pass_weapon"),
		PartDef.SlotType.CORE: _part(&"core", PartDef.SlotType.CORE, &"pass_core"),
		PartDef.SlotType.LEGS: _part(&"legs", PartDef.SlotType.LEGS, &""),  # no passive
	}
	var build := SymbotBuild.with_starters(starters, _cfg, _log, null, null, null, passive_db)

	# Act
	var pool := build.get_passive_pool()

	# Assert: compact, ordered [CORE, …, WEAPON] — the null-passive LEGS adds nothing.
	assert_eq(pool, [&"pass_core", &"pass_weapon"] as Array[StringName],
		"CORE precedes WEAPON; no phantom entry for the null-passive slot")


func test_passive_pool_all_common_is_empty() -> void:
	# Arrange: every part carries an empty passive_id (all-common loadout).
	var starters := {
		PartDef.SlotType.CORE: _part(&"core", PartDef.SlotType.CORE, &""),
		PartDef.SlotType.LEGS: _part(&"legs", PartDef.SlotType.LEGS, &""),
	}
	var build := SymbotBuild.with_starters(starters, _cfg, _log)

	# Act / Assert
	assert_eq(build.get_passive_pool().size(), 0, "no passives → empty pool")


# --- EC-SA-04: a passive missing from the Passive DB is logged and skipped --------

func test_missing_passive_id_logged_and_skipped() -> void:
	# Arrange: CORE references a passive the DB does not know; WEAPON is valid.
	var passive_db := Fixtures.StubDB.new([&"pass_weapon"])
	var starters := {
		PartDef.SlotType.CORE: _part(&"core", PartDef.SlotType.CORE, &"ghost_passive"),
		PartDef.SlotType.WEAPON: _part(&"lance", PartDef.SlotType.WEAPON, &"pass_weapon"),
	}
	var build := SymbotBuild.with_starters(starters, _cfg, _log, null, null, null, passive_db)

	# Act
	var pool := build.get_passive_pool()

	# Assert: the unknown passive is dropped (not appended as null), the valid one kept.
	assert_eq(pool, [&"pass_weapon"] as Array[StringName],
		"missing passive skipped, compact list preserved")
	assert_eq(_log.errors.size(), 1)
	assert_eq(_log.errors[0]["code"], &"content_missing_passive")
	assert_eq(_log.errors[0]["detail"]["passive_id"], &"ghost_passive")
