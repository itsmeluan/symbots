## EZ-7 gate-params validation & reserved-gate fail-safe spec (Encounter Zone Story
## 007). A `validate_gate(boss)` pass runs BEFORE evaluation; every structural fault
## defaults the boss to LOCKED + a LogSink diagnostic — the single invariant here is
## that no fault ever falls through to accessible.
##   AC-EZ-34  WIN_COUNT missing `required_wins` → error + LOCKED (NOT a 0-default open).
##   AC-EZ-35  OPEN + spurious params → UNLOCKED + WARNING (params ignored, not a gate).
##   AC-EZ-36  OPEN + empty params → UNLOCKED, silent.
##   AC-EZ-37  REACH → error + LOCKED.  AC-EZ-38  DUNGEON_RUSH → error + LOCKED.
##   AC-EZ-24  WAVE → error + LOCKED (no crash, no OPEN fall-through).
##   AC-EZ-31  WILD-class enemy in a boss slot → error + LOCKED (boss-slot class check).
##   AC-EZ-25  regate strictly-lighter-and-≥1 content linter (A too-heavy / B zero / C ok).
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const StubEnemyReader := preload("res://tests/unit/encounter_zone/stub_enemy_reader.gd")

const LOCKED := EncounterResolver.GateState.LOCKED
const UNLOCKED := EncounterResolver.GateState.UNLOCKED

const ZONE_ID := &"scrapfield"
const BOSS_ID := &"zone_boss"


func _boss(gate_type: BossEncounter.GateType, gate_params: Dictionary) -> BossEncounter:
	var b := BossEncounter.new()
	b.boss_id = BOSS_ID
	b.gate_type = gate_type
	b.gate_params = gate_params
	return b


func _zone(boss: BossEncounter) -> ZoneDef:
	var z := ZoneDef.new()
	z.zone_id = ZONE_ID
	z.boss_encounters = [boss] as Array[BossEncounter]
	return z


func _resolver(log: LogSink = null, enemy_db: Variant = null) -> EncounterResolver:
	# Gate validation/eval never draws RNG; pass a throwaway generator.
	return EncounterResolver.new(RandomNumberGenerator.new(), log, enemy_db)


# --- AC-EZ-34: WIN_COUNT missing required_wins → fail-safe LOCKED ------------

func test_ez7_wincount_missing_required_wins_is_failsafe_locked() -> void:
	# gate_params = {} → the required key is absent. A 0-default would open the boss.
	var boss := _boss(BossEncounter.GateType.WIN_COUNT, {})
	var zone := _zone(boss)
	var spy := SpyLogSink.new()

	var verdict := _resolver(spy).evaluate_boss_gate(boss, zone, null)

	assert_eq(verdict, LOCKED, "missing required_wins fails safe to LOCKED, never 0-default open")
	assert_eq(spy.errors.size(), 1, "one content error for the missing key")
	assert_eq(spy.errors[0]["code"], &"ez_gate_missing_required_wins", "missing-key error code")
	assert_eq(spy.errors[0]["detail"]["boss_id"], BOSS_ID, "names the offending boss")
	assert_eq(spy.errors[0]["detail"]["missing_key"], &"required_wins", "names the missing key")


# --- AC-EZ-35: OPEN + spurious params → UNLOCKED + warning -------------------

func test_ez7_open_spurious_params_warns_and_unlocks() -> void:
	# An OPEN gate ignores params; the leftover required_wins:3 must NOT lock it.
	var boss := _boss(BossEncounter.GateType.OPEN, {&"required_wins": 3})
	var zone := _zone(boss)
	var spy := SpyLogSink.new()

	var verdict := _resolver(spy).evaluate_boss_gate(boss, zone, null)

	assert_eq(verdict, UNLOCKED, "OPEN ignores spurious params — never read as a WIN_COUNT threshold")
	assert_eq(spy.warns.size(), 1, "spurious params on OPEN are a warning")
	assert_eq(spy.errors.size(), 0, "spurious OPEN params are a warning, not an error")
	assert_eq(spy.warns[0]["code"], &"ez_open_spurious_params", "spurious-params warning code")
	assert_eq(spy.warns[0]["detail"]["boss_id"], BOSS_ID, "names the boss")


# --- AC-EZ-36: OPEN + empty params → UNLOCKED, silent -----------------------

func test_ez7_open_empty_params_is_silent_unlocked() -> void:
	var boss := _boss(BossEncounter.GateType.OPEN, {})
	var zone := _zone(boss)
	var spy := SpyLogSink.new()

	var verdict := _resolver(spy).evaluate_boss_gate(boss, zone, null)

	assert_eq(verdict, UNLOCKED, "OPEN with empty params is valid and UNLOCKED")
	assert_eq(spy.total(), 0, "valid empty OPEN params log nothing")


# --- AC-EZ-37 / 38 / 24: reserved gate types → fail-safe LOCKED -------------

func test_ez7_reach_gate_is_failsafe_locked() -> void:
	_assert_reserved_gate_locks(BossEncounter.GateType.REACH)


func test_ez7_dungeon_rush_gate_is_failsafe_locked() -> void:
	_assert_reserved_gate_locks(BossEncounter.GateType.DUNGEON_RUSH)


func test_ez7_wave_gate_is_failsafe_locked() -> void:
	_assert_reserved_gate_locks(BossEncounter.GateType.WAVE)


func _assert_reserved_gate_locks(gate_type: BossEncounter.GateType) -> void:
	var boss := _boss(gate_type, {})
	var zone := _zone(boss)
	var spy := SpyLogSink.new()

	var verdict := _resolver(spy).evaluate_boss_gate(boss, zone, null)

	assert_eq(verdict, LOCKED, "reserved gate type is not fulfillable in MVP → fail-safe LOCKED")
	assert_eq(spy.errors.size(), 1, "one content error for the reserved gate type")
	assert_eq(spy.errors[0]["code"], &"ez_gate_type_reserved", "reserved-gate error code")
	assert_eq(spy.errors[0]["detail"]["boss_id"], BOSS_ID, "names the boss")
	assert_eq(spy.errors[0]["detail"]["gate_type"], gate_type, "names the offending gate type")


# --- AC-EZ-31: WILD-class enemy in a boss slot → fail-safe LOCKED -----------

func test_ez7_wild_in_boss_slot_is_failsafe_locked() -> void:
	# boss_id resolves to a WILD-class enemy in the injected Enemy DB. Even with an
	# OPEN gate (which would otherwise UNLOCK), the class fault must LOCK it.
	var boss := _boss(BossEncounter.GateType.OPEN, {})
	boss.boss_id = &"iron_crawler"
	var zone := _zone(boss)
	var spy := SpyLogSink.new()
	var db: RefCounted = StubEnemyReader.new().add(&"iron_crawler", EnemyDef.EnemyClass.WILD)

	var verdict := _resolver(spy, db).evaluate_boss_gate(boss, zone, null)

	assert_eq(verdict, LOCKED, "WILD in a boss slot fails safe to LOCKED, not OPEN")
	assert_eq(spy.errors.size(), 1, "one content error for the misplaced WILD enemy")
	assert_eq(spy.errors[0]["code"], &"ez_boss_slot_wild_class", "wild-in-boss-slot error code")
	assert_eq(spy.errors[0]["detail"]["boss_id"], &"iron_crawler", "names the offending boss id")


# --- AC-EZ-25: regate strictly-lighter-and-≥1 content linter ----------------

func _regate_boss(first_access: int, regate: int) -> BossEncounter:
	var b := _boss(BossEncounter.GateType.WIN_COUNT, {&"required_wins": first_access})
	b.repeat_policy = BossEncounter.RepeatPolicy.LIGHTER_REGATE
	b.regate_params = {&"required_wins": regate}
	return b


func test_ez7_regate_not_lighter_is_content_error() -> void:
	# A: regate 6 vs first-access 6 → not strictly lighter (degenerates to FULL_REGATE).
	var boss := _regate_boss(6, 6)
	var spy := SpyLogSink.new()

	var ok := _resolver(spy).validate_regate_params(boss)

	assert_false(ok, "regate >= first-access is invalid")
	assert_eq(spy.errors.size(), 1, "one content error for the too-heavy regate")
	assert_eq(spy.errors[0]["code"], &"ez_regate_not_lighter", "regate-not-lighter error code")
	assert_eq(spy.errors[0]["detail"]["boss_id"], BOSS_ID, "names the boss")
	assert_eq(spy.errors[0]["detail"]["regate_required"], 6, "surfaces the regate value")
	assert_eq(spy.errors[0]["detail"]["first_access_required"], 6, "surfaces the first-access value")


func test_ez7_regate_zero_is_content_error() -> void:
	# B: regate 0 → degenerates to ALWAYS_OPEN.
	var boss := _regate_boss(6, 0)
	var spy := SpyLogSink.new()

	var ok := _resolver(spy).validate_regate_params(boss)

	assert_false(ok, "regate 0 is invalid (must be >= 1)")
	assert_eq(spy.errors.size(), 1, "one content error for the zero regate")
	assert_eq(spy.errors[0]["code"], &"ez_regate_not_lighter", "regate-not-lighter error code")
	assert_eq(spy.errors[0]["detail"]["regate_required"], 0, "surfaces the zero regate value")


func test_ez7_valid_regate_params_pass() -> void:
	# C: Boss 1 (1 <= 2 < 6) and Boss 2 (1 <= 3 < 10) are both valid → no error.
	var boss1 := _regate_boss(6, 2)
	var boss2 := _regate_boss(10, 3)
	var spy := SpyLogSink.new()
	var resolver := _resolver(spy)

	assert_true(resolver.validate_regate_params(boss1), "1 <= 2 < 6 is a valid regate")
	assert_true(resolver.validate_regate_params(boss2), "1 <= 3 < 10 is a valid regate")
	assert_eq(spy.total(), 0, "valid regate params log nothing")
