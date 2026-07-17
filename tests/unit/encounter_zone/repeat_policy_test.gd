## EZ-6 repeat-policy spec (Encounter Zone Story 006): LIGHTER_REGATE delta re-gate &
## ALWAYS_OPEN. Access routes on the boss's OWN `defeated_once`: false → first-access
## gate (Story 005); true → `repeat_policy`.
##   AC-EZ-21  LIGHTER_REGATE DELTA re-gate (raw-counter impl unlocks too early).
##   AC-EZ-22  re-lock at the moment of defeat — delta 0 → LOCKED (the central
##             discriminator: DEFEATED is a genuine resting state).
##   AC-EZ-23  re-gate met after banking the delta (>= on the delta).
##   AC-EZ-39  re-access path gated on `defeated_once` (first-access applies pre-defeat).
##   AC-EZ-52  ALWAYS_OPEN — permanently open post-first-defeat; first-access still
##             applies before it.
extends GutTest

const StubProgress := preload("res://tests/unit/encounter_zone/stub_progress.gd")

const LOCKED := EncounterResolver.GateState.LOCKED
const UNLOCKED := EncounterResolver.GateState.UNLOCKED

const ZONE_ID := &"scrapfield"


func _boss(boss_id: StringName, required_wins: int, repeat_policy: BossEncounter.RepeatPolicy, regate_wins: int) -> BossEncounter:
	var b := BossEncounter.new()
	b.boss_id = boss_id
	b.gate_type = BossEncounter.GateType.WIN_COUNT
	b.gate_params = {&"required_wins": required_wins}
	b.repeat_policy = repeat_policy
	b.regate_params = {&"required_wins": regate_wins}
	return b


func _zone(boss: BossEncounter) -> ZoneDef:
	var z := ZoneDef.new()
	z.zone_id = ZONE_ID
	z.boss_encounters = [boss]
	return z


func _resolver() -> EncounterResolver:
	# Gate eval never draws RNG; pass a throwaway generator.
	return EncounterResolver.new(RandomNumberGenerator.new())


# --- AC-EZ-21: LIGHTER_REGATE delta re-gate (delta, not raw counter) ---------

func test_ez6_lighter_regate_uses_delta_not_raw_counter() -> void:
	# Boss 2 defeated at 10 wins; re-gate needs 3 MORE wins (delta), not win_count >= 3.
	var boss := _boss(&"zone_boss_2", 10, BossEncounter.RepeatPolicy.LIGHTER_REGATE, 3)
	var zone := _zone(boss)
	var at_thirteen: RefCounted = StubProgress.new().set_wins(ZONE_ID, 13).mark_defeated(&"zone_boss_2").set_last_defeat(&"zone_boss_2", 10)
	var at_twelve: RefCounted = StubProgress.new().set_wins(ZONE_ID, 12).mark_defeated(&"zone_boss_2").set_last_defeat(&"zone_boss_2", 10)

	# delta 13-10 = 3 >= 3 → UNLOCKED; delta 12-10 = 2 < 3 → LOCKED.
	# A raw-counter impl unlocks at 12 (12 >= 3) — assert LOCKED.
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, at_thirteen), UNLOCKED, "delta 3 >= 3 → UNLOCKED")
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, at_twelve), LOCKED, "delta 2 < 3 → LOCKED (not raw 12 >= 3)")


# --- AC-EZ-22: re-lock at the moment of defeat (delta 0) ---------------------

func test_ez6_regate_relocks_at_moment_of_defeat() -> void:
	# Boss 1 just defeated at win_count 6 → wins_at_last_defeat = 6, counter still 6.
	var boss := _boss(&"zone_boss_1", 6, BossEncounter.RepeatPolicy.LIGHTER_REGATE, 2)
	var zone := _zone(boss)
	var at_defeat: RefCounted = StubProgress.new().set_wins(ZONE_ID, 6).mark_defeated(&"zone_boss_1").set_last_defeat(&"zone_boss_1", 6)

	# delta 6-6 = 0 < 2 → LOCKED. Discriminator against BOTH the raw-counter bug
	# (6 >= 2) AND an ignore-defeated_once first-access impl (6 >= 6). Proves
	# LIGHTER_REGATE does NOT collapse into ALWAYS_OPEN.
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, at_defeat), LOCKED,
		"delta 0 → LOCKED: DEFEATED is a resting state, re-gate does not pass through")


# --- AC-EZ-23: re-gate met after banking the delta --------------------------

func test_ez6_regate_met_after_banking_delta() -> void:
	var boss := _boss(&"zone_boss_1", 6, BossEncounter.RepeatPolicy.LIGHTER_REGATE, 2)
	var zone := _zone(boss)
	var at_eight: RefCounted = StubProgress.new().set_wins(ZONE_ID, 8).mark_defeated(&"zone_boss_1").set_last_defeat(&"zone_boss_1", 6)
	var at_seven: RefCounted = StubProgress.new().set_wins(ZONE_ID, 7).mark_defeated(&"zone_boss_1").set_last_defeat(&"zone_boss_1", 6)

	# 7→delta 1 LOCKED / 8→delta 2 UNLOCKED is the `>=` boundary on the delta.
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, at_eight), UNLOCKED, "delta 2 >= 2 → UNLOCKED")
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, at_seven), LOCKED, "delta 1 < 2 → LOCKED")


# --- AC-EZ-39: re-access path gated on defeated_once -------------------------

func test_ez6_predefeat_applies_first_access_not_regate() -> void:
	# defeated_once = false, so first-access WIN_COUNT (6) applies — NOT the re-gate.
	var boss := _boss(&"zone_boss_1", 6, BossEncounter.RepeatPolicy.LIGHTER_REGATE, 2)
	var zone := _zone(boss)

	# A (negative): win 3, wins_at_last_defeat unset (0). An impl ignoring
	# defeated_once takes the re-gate (delta 3-0 = 3 >= 2 → UNLOCKED); the correct
	# path is first-access (3 < 6 → LOCKED).
	var pre_low: RefCounted = StubProgress.new().set_wins(ZONE_ID, 3)
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, pre_low), LOCKED,
		"pre-defeat uses first-access (3 < 6), not the re-gate")

	# B (positive): win 6 → first-access 6 >= 6 → UNLOCKED (an impl that never unlocks
	# pre-defeat fails this).
	var pre_high: RefCounted = StubProgress.new().set_wins(ZONE_ID, 6)
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, pre_high), UNLOCKED,
		"pre-defeat first-access opens at 6 >= 6")


# --- AC-EZ-52: ALWAYS_OPEN --------------------------------------------------

func test_ez6_always_open_permanently_accessible_after_first_clear() -> void:
	# WIN_COUNT first-access 6, ALWAYS_OPEN repeat.
	var boss := _boss(&"open_boss", 6, BossEncounter.RepeatPolicy.ALWAYS_OPEN, 0)
	var zone := _zone(boss)

	# A: defeated_once = true, win_count 0 → UNLOCKED (no re-gate; counter irrelevant).
	var cleared: RefCounted = StubProgress.new().set_wins(ZONE_ID, 0).mark_defeated(&"open_boss")
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, cleared), UNLOCKED,
		"ALWAYS_OPEN post-defeat is UNLOCKED even at win_count 0")

	# B: defeated_once = false, win_count 0 → first-access still applies (0 < 6 → LOCKED).
	var pristine: RefCounted = StubProgress.new().set_wins(ZONE_ID, 0)
	assert_eq(_resolver().evaluate_boss_gate(boss, zone, pristine), LOCKED,
		"ALWAYS_OPEN only takes effect post-first-defeat; first-access LOCKS at 0 < 6")
