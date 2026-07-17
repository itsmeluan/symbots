## Story 003 — SYN-F3 effects: keep-first dedup + alphabetical String(tier_id) order.
## Covers AC-SYN-05, 05b (DoD gate — the StringName intern trap), 12, 16, 26.
extends GutTest

const Fixtures = preload("res://tests/unit/synergy/synergy_fixtures.gd")
const SpyLogSink = preload("res://tests/unit/synergy/spy_log_sink.gd")

var _log


func before_each() -> void:
	_log = SpyLogSink.new()


func _sys(tiers: Array) -> SynergySystem:
	var s := SynergySystem.new(tiers, _log)
	watch_signals(s)
	return s


func _volt_parts(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(Fixtures.part([&"VOLT"]))
	return Fixtures.slots(out)


# --- AC-SYN-05: keep-first dedup of a shared effect id -----------------------------

func test_effects_shared_id_deduplicated_keep_first() -> void:
	var tiers := [
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {}, [&"volt_test"]),
		Fixtures.tier(&"volt_5_piece", [[&"VOLT", 5]], {}, [&"volt_test"]),
	]
	var sys := _sys(tiers)

	sys.evaluate(_volt_parts(5))

	var effects = sys.cached_bonus_block["effects"]
	assert_eq(effects.size(), 1, "shared id appears once (FAIL 2 = double-trigger risk)")
	assert_eq(effects[0], &"volt_test")


# --- AC-SYN-05b: dedup follows alphabetical tier order, NOT content-file order ------
#     THE DoD GATE. Content authored reverse-alphabetically (volt first) to prove the
#     String(tier_id) sort, not insertion order, drives ownership of `shared_test`.

func test_effects_dedup_follows_alphabetical_tier_order_not_file_order() -> void:
	var tiers := [
		# volt authored FIRST (reverse-alphabetical) — the discriminating trap.
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {}, [&"shared_test", &"volt_unique"]),
		Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {}, [&"shared_test", &"ironclad_unique"]),
	]
	var sys := _sys(tiers)
	var parts := Fixtures.slots([
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"VOLT"]),
	])  # ironclad=3, VOLT=3, NO combined tier registered

	sys.evaluate(parts)

	var expected: Array[StringName] = [&"shared_test", &"ironclad_unique", &"volt_unique"]
	assert_eq(sys.cached_bonus_block["effects"], expected,
		"ironclad (alpha-first) owns shared_test; FAIL [shared,volt_unique,ironclad_unique] = file order")
	assert_eq(sys.active_synergies.size(), 2)


# --- AC-SYN-12: active_synergies is exact and alphabetically ordered ---------------

func test_active_synergies_exact_ordered_list() -> void:
	var tiers := [
		Fixtures.tier(&"volt_5_piece", [[&"VOLT", 5]], {&"energy_power": 12}),
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {&"energy_power": 6}),
	]
	var sys := _sys(tiers)

	sys.evaluate(_volt_parts(5))

	var expected: Array[StringName] = [&"volt_3_piece", &"volt_5_piece"]
	assert_eq(sys.active_synergies, expected,
		"ascending String(id); FAIL [volt_5_piece, volt_3_piece] = wrong order")


# --- AC-SYN-16: unique combined effect preserved (dedup drops repeats, not uniques) -

func test_effects_combined_unique_not_over_deduplicated() -> void:
	var tiers := [
		Fixtures.tier(&"ironclad_3_piece", [[&"ironclad", 3]], {}, [&"ironclad_test"]),
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {}, [&"volt_test"]),
		Fixtures.tier(&"ironclad_volt_3_piece", [[&"ironclad", 3], [&"VOLT", 3]], {}, [&"combined_test"]),
	]
	var sys := _sys(tiers)
	var parts := Fixtures.slots([
		Fixtures.part([&"ironclad", &"VOLT"]), Fixtures.part([&"ironclad", &"VOLT"]),
		Fixtures.part([&"ironclad", &"VOLT"]),
	])

	sys.evaluate(parts)

	var effects = sys.cached_bonus_block["effects"]
	assert_eq(effects.size(), 3, "three distinct ids kept (FAIL 2 = combined dropped)")
	assert_true(effects.has(&"ironclad_test"))
	assert_true(effects.has(&"volt_test"))
	assert_true(effects.has(&"combined_test"))


# --- AC-SYN-26: unregistered effect ids pass through unfiltered (EC-SYN-05) ---------

func test_effects_unregistered_id_passes_through() -> void:
	var sys := _sys([
		Fixtures.tier(&"volt_3_piece", [[&"VOLT", 3]], {}, [&"unregistered_test_effect"]),
	])

	sys.evaluate(_volt_parts(3))

	var expected: Array[StringName] = [&"unregistered_test_effect"]
	assert_eq(sys.cached_bonus_block["effects"], expected,
		"emitted transparently — no known-effects filtering (that's TBC's job)")
