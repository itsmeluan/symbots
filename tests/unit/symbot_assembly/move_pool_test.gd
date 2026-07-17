## Story 004 — move-pool derivation.
## Covers AC-SA-03a (fixed order/length), AC-SA-03b (only WEAPON/HEAD/ARMS consulted),
## AC-SA-06 (missing move logs + nulls), AC-SA-12 (basic_attack pinned to slot 0).
extends GutTest

const Fixtures = preload("res://tests/unit/symbot_assembly/assembly_fixtures.gd")
const SpyLogSink = preload("res://tests/unit/symbot_assembly/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()


func _part(id: StringName, slot: int, skill: StringName) -> Object:
	return Fixtures.make_instance(Fixtures.make_part({
		"id": id, "slot_type": slot, "active_skill_id": skill,
	}), 0)


# --- AC-SA-03a / AC-SA-12: fixed order, length 4, basic_attack at slot 0 ----------

func test_move_pool_order_and_nullable_tail() -> void:
	# Arrange: WEAPON + HEAD carry skills, ARMS is empty.
	var move_db := Fixtures.StubDB.new([&"storm_lance", &"scanner_ping"])
	var starters := {
		PartDef.SlotType.WEAPON: _part(&"lance", PartDef.SlotType.WEAPON, &"storm_lance"),
		PartDef.SlotType.HEAD: _part(&"visor", PartDef.SlotType.HEAD, &"scanner_ping"),
	}
	var build := SymbotBuild.with_starters(starters, _cfg, _log, null, null, move_db)

	# Act
	var pool := build.get_move_pool()

	# Assert: [basic_attack, WEAPON, HEAD, ARMS] — index 3 null (ARMS empty).
	assert_eq(pool.size(), 4, "move pool is always length 4")
	assert_eq(pool[0], &"basic_attack", "slot 0 is always the basic attack")
	assert_eq(pool[1], &"storm_lance", "slot 1 = WEAPON skill")
	assert_eq(pool[2], &"scanner_ping", "slot 2 = HEAD skill")
	assert_null(pool[3], "slot 3 = ARMS skill — null when empty")


func test_move_pool_empty_build_is_basic_attack_only() -> void:
	# Arrange / Act: no parts at all.
	var build := SymbotBuild.new(_cfg, _log)
	var pool := build.get_move_pool()

	# Assert
	assert_eq(pool, [&"basic_attack", null, null, null])


# --- AC-SA-03b: skills on non-weapon slots are never consulted -------------------

func test_skill_on_core_slot_is_ignored() -> void:
	# Arrange: a CORE part erroneously carrying an active skill.
	var move_db := Fixtures.StubDB.new([&"forbidden_skill"])
	var starters := {
		PartDef.SlotType.CORE: _part(&"core", PartDef.SlotType.CORE, &"forbidden_skill"),
	}
	var build := SymbotBuild.with_starters(starters, _cfg, _log, null, null, move_db)

	# Act
	var pool := build.get_move_pool()

	# Assert: CORE is never read for skills — the pool stays basic-attack-only.
	assert_eq(pool, [&"basic_attack", null, null, null])
	assert_false(pool.has(&"forbidden_skill"), "non-weapon slot skill excluded")


# --- AC-SA-06: a skill id missing from the Move DB logs an error and nulls out ----

func test_missing_move_id_logs_error_and_nulls_slot() -> void:
	# Arrange: WEAPON references a skill the Move DB does not know.
	var move_db := Fixtures.StubDB.new([])   # empty DB
	var starters := {
		PartDef.SlotType.WEAPON: _part(&"lance", PartDef.SlotType.WEAPON, &"ghost_skill"),
	}
	var build := SymbotBuild.with_starters(starters, _cfg, _log, null, null, move_db)

	# Act
	var pool := build.get_move_pool()

	# Assert: slot nulled, one content error logged — no raise.
	assert_null(pool[1], "unknown skill resolves to null, not a raise")
	assert_eq(_log.errors.size(), 1)
	assert_eq(_log.errors[0]["code"], &"content_missing_move")
	assert_eq(_log.errors[0]["detail"]["skill_id"], &"ghost_skill")
