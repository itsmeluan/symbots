## EZ-5 boss-gate WIN_COUNT first-access & sequencing spec (Encounter Zone Story 005).
##
## `EncounterResolver.evaluate_boss_gate(boss, zone, progress)` returns a fail-safe
## GateState verdict. WIN_COUNT: `UNLOCKED iff zone_win_count >= required_wins` AND
## (when present) the `requires_defeated` prerequisite boss is defeated_once.
##   AC-EZ-16/17/18  Boss 1 threshold 5/6/7 — the `>=`-vs-`>` discriminator at 6.
##   AC-EZ-19        Boss 2 threshold 9/10 with sequencing satisfied.
##   AC-EZ-20        dual gate off ONE shared counter (Boss 2 LOCKED at 6).
##   AC-EZ-56        sequencing precondition (requires_defeated).
##   AC-EZ-58        dangling prerequisite → fail-safe LOCKED + error.
##   AC-EZ-40a       progress absent → WIN_COUNT LOCKED + warning; OPEN UNLOCKED.
##
## Canonical fixture: Boss 1 `zone_boss_1` (WIN_COUNT, required_wins 6);
## Boss 2 `zone_boss_2` (WIN_COUNT, required_wins 10, requires_defeated zone_boss_1);
## both live in one zone reading the shared `zone_win_count`.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const StubProgress := preload("res://tests/unit/encounter_zone/stub_progress.gd")

const LOCKED := EncounterResolver.GateState.LOCKED
const UNLOCKED := EncounterResolver.GateState.UNLOCKED

const ZONE_ID := &"scrapfield"
const BOSS_1 := &"zone_boss_1"
const BOSS_2 := &"zone_boss_2"


func _boss(boss_id: StringName, gate_type: BossEncounter.GateType, gate_params: Dictionary) -> BossEncounter:
	var b := BossEncounter.new()
	b.boss_id = boss_id
	b.gate_type = gate_type
	b.gate_params = gate_params
	return b


func _boss_1() -> BossEncounter:
	# repeat_policy = ALWAYS_OPEN so Boss 1's post-defeat verdict stays UNLOCKED under
	# EZ-6's defeated_once routing (AC-EZ-20's "both UNLOCKED at 10" evaluates Boss 1
	# with defeated_once = true, set as Boss 2's prerequisite). First-access
	# (defeated_once = false) still applies the WIN_COUNT threshold regardless.
	var b := _boss(BOSS_1, BossEncounter.GateType.WIN_COUNT, {&"required_wins": 6})
	b.repeat_policy = BossEncounter.RepeatPolicy.ALWAYS_OPEN
	return b


func _boss_2() -> BossEncounter:
	return _boss(BOSS_2, BossEncounter.GateType.WIN_COUNT, {&"required_wins": 10, &"requires_defeated": BOSS_1})


## A zone holding both canonical bosses (needed for requires_defeated resolution).
func _zone(bosses: Array[BossEncounter]) -> ZoneDef:
	var z := ZoneDef.new()
	z.zone_id = ZONE_ID
	z.boss_encounters = bosses
	return z


func _resolver(log: LogSink = null) -> EncounterResolver:
	# Gate eval never draws RNG; pass a throwaway generator.
	return EncounterResolver.new(RandomNumberGenerator.new(), log)


# --- AC-EZ-16/17/18: Boss 1 threshold (the >= vs > discriminator) ------------

func test_ez5_boss1_five_wins_is_locked() -> void:
	var boss := _boss_1()
	var zone := _zone([boss] as Array[BossEncounter])
	var progress := StubProgress.new().set_wins(ZONE_ID, 5)
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, progress), LOCKED, "5 < 6 → LOCKED")


func test_ez5_boss1_exactly_six_wins_is_unlocked() -> void:
	# The load-bearing case: a `> 6` impl stays LOCKED at exactly 6.
	var boss := _boss_1()
	var zone := _zone([boss] as Array[BossEncounter])
	var progress := StubProgress.new().set_wins(ZONE_ID, 6)
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, progress), UNLOCKED, "6 >= 6 → UNLOCKED")


func test_ez5_boss1_seven_wins_is_unlocked() -> void:
	# No upper-bound "window" regression — above threshold stays UNLOCKED.
	var boss := _boss_1()
	var zone := _zone([boss] as Array[BossEncounter])
	var progress := StubProgress.new().set_wins(ZONE_ID, 7)
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, progress), UNLOCKED, "7 >= 6 → UNLOCKED")


# --- AC-EZ-19: Boss 2 threshold with sequencing satisfied -------------------

func test_ez5_boss2_threshold_with_prereq_defeated() -> void:
	var boss2 := _boss_2()
	var zone := _zone([_boss_1(), boss2] as Array[BossEncounter])
	# Prereq satisfied; toggle only the counter across the 10 boundary.
	var at_nine: RefCounted = StubProgress.new().set_wins(ZONE_ID, 9).mark_defeated(BOSS_1)
	var at_ten: RefCounted = StubProgress.new().set_wins(ZONE_ID, 10).mark_defeated(BOSS_1)
	assert_eq(_resolver().evaluate_boss_gate(boss2, zone, at_nine), LOCKED, "9 < 10 → LOCKED")
	assert_eq(_resolver().evaluate_boss_gate(boss2, zone, at_ten), UNLOCKED, "10 >= 10 & prereq → UNLOCKED")


# --- AC-EZ-20: dual gate off ONE shared counter -----------------------------

func test_ez5_shared_counter_gates_two_bosses_independently() -> void:
	var boss1 := _boss_1()
	var boss2 := _boss_2()
	var zone := _zone([boss1, boss2] as Array[BossEncounter])
	var resolver := _resolver()

	# At 6, Boss 1 undefeated: Boss 1 opens (6 >= 6), Boss 2 stays shut (6 < 10).
	var at_six := StubProgress.new().set_wins(ZONE_ID, 6)
	assert_eq(resolver.evaluate_boss_gate(boss1, zone, at_six), UNLOCKED, "Boss 1 UNLOCKED at 6")
	assert_eq(resolver.evaluate_boss_gate(boss2, zone, at_six), LOCKED,
		"Boss 2 LOCKED at 6 — NOT an 'any boss unlocked' flag")

	# At 10 with Boss 1 defeated: both open.
	var at_ten: RefCounted = StubProgress.new().set_wins(ZONE_ID, 10).mark_defeated(BOSS_1)
	assert_eq(resolver.evaluate_boss_gate(boss1, zone, at_ten), UNLOCKED, "Boss 1 UNLOCKED at 10")
	assert_eq(resolver.evaluate_boss_gate(boss2, zone, at_ten), UNLOCKED, "Boss 2 UNLOCKED at 10 & prereq")


# --- AC-EZ-56: sequencing precondition (requires_defeated) -------------------

func test_ez5_sequencing_requires_prerequisite_defeated() -> void:
	var boss2 := _boss_2()
	var zone := _zone([_boss_1(), boss2] as Array[BossEncounter])
	# Threshold met at 10 in BOTH cases; only Boss 1's defeated_once differs.
	var prereq_unmet := StubProgress.new().set_wins(ZONE_ID, 10)
	var prereq_met: RefCounted = StubProgress.new().set_wins(ZONE_ID, 10).mark_defeated(BOSS_1)
	assert_eq(_resolver().evaluate_boss_gate(boss2, zone, prereq_unmet), LOCKED,
		"threshold met but prerequisite undefeated → LOCKED")
	assert_eq(_resolver().evaluate_boss_gate(boss2, zone, prereq_met), UNLOCKED,
		"threshold met AND prerequisite defeated → UNLOCKED")


# --- AC-EZ-58: dangling prerequisite → fail-safe LOCKED + error -------------

func test_ez5_dangling_requires_defeated_is_failsafe_locked() -> void:
	# requires_defeated names a boss that is not in the zone.
	var boss2 := _boss(BOSS_2, BossEncounter.GateType.WIN_COUNT,
		{&"required_wins": 10, &"requires_defeated": &"no_such_boss"})
	var zone := _zone([_boss_1(), boss2] as Array[BossEncounter])
	var spy := SpyLogSink.new()
	var progress := StubProgress.new().set_wins(ZONE_ID, 10)

	var verdict := _resolver(spy).evaluate_boss_gate(boss2, zone, progress)

	# Fail-SAFE: a fail-open impl returns UNLOCKED at win_count >= 10.
	assert_eq(verdict, LOCKED, "dangling prerequisite fails safe to LOCKED, never fail-open")
	assert_eq(spy.errors.size(), 1, "one content error for the unresolved prerequisite")
	assert_eq(spy.errors[0]["code"], &"ez_requires_defeated_unresolved", "unresolved-prereq error code")
	assert_eq(spy.errors[0]["detail"]["boss_id"], BOSS_2, "names the boss carrying the bad reference")
	assert_eq(spy.errors[0]["detail"]["requires_defeated"], &"no_such_boss", "names the unresolved value")


# --- AC-EZ-40a: progress absent → safe defaults, no crash -------------------

func test_ez5_absent_progress_locks_wincount_with_warning() -> void:
	# Null progress stub — the MVP dev-period fallback until Exploration Progress ships.
	var boss1 := _boss_1()
	var zone := _zone([boss1] as Array[BossEncounter])
	var spy := SpyLogSink.new()

	var verdict := _resolver(spy).evaluate_boss_gate(boss1, zone, null)

	# Counter reads 0 → 0 < 6 → LOCKED; provisional WARNING (not error); no crash.
	assert_eq(verdict, LOCKED, "absent progress → counter 0 → WIN_COUNT LOCKED")
	assert_eq(spy.warns.size(), 1, "provisional progress-absent warning")
	assert_eq(spy.errors.size(), 0, "absent progress is a WARNING, not an error")
	assert_eq(spy.warns[0]["code"], &"ez_progress_absent", "progress-absent warning code")


func test_ez5_absent_progress_leaves_open_gate_unlocked() -> void:
	# An OPEN boss is accessible even with no progress connected.
	var open_boss := _boss(&"tutorial_boss", BossEncounter.GateType.OPEN, {})
	var zone := _zone([open_boss] as Array[BossEncounter])
	var spy := SpyLogSink.new()

	var verdict := _resolver(spy).evaluate_boss_gate(open_boss, zone, null)

	assert_eq(verdict, UNLOCKED, "OPEN gate is UNLOCKED regardless of progress")
	assert_eq(spy.total(), 0, "OPEN gate logs nothing — no counter read attempted")
