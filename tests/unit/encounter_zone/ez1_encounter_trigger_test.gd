## EZ-1 encounter-trigger & zone-data-model spec (Encounter Zone Story 001).
##
## `EncounterResolver.roll_encounter(zone, patch, active_modifier)` runs the EZ-1
## per-step trigger: `triggered = rng.randf() < clamp(encounter_rate × modifier, 0, 1)`.
##   AC-EZ-01  rate 0.0 never triggers (10,000 steps, two seeds).
##   AC-EZ-02  legal boundaries + out-of-range authored-rate clamp (content error).
##   AC-EZ-03  strict `<` discrimination via scripted draws [0.14, 0.15, 0.16] @ 0.15.
##   AC-EZ-59  encounter-rate modifier hook (Jammer/Lure) — two distinct clamps.
##   AC-EZ-57  zone-level `spawn_enabled == false` → inert (no roll, no draw).
##
## Injected seeded RNG is mandatory (ADR-0006): the `<` boundary discriminator is
## unreachable without a scripted mock. Draws go through `call(&"randf")` in the
## resolver so these GDScript doubles dispatch (RNG-ptrcall memory, shared w/ Drop).
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")

const STEPS: int = 10000


# --- fixture builders -------------------------------------------------------

func _patch(rate: float) -> TerrainPatch:
	var p := TerrainPatch.new()
	p.terrain_type = TerrainPatch.TerrainType.MECHANICAL_GRASS
	p.density_class = TerrainPatch.DensityClass.STANDARD
	p.encounter_rate = rate
	return p


func _zone(patch: TerrainPatch, spawn_enabled: bool = true) -> ZoneDef:
	var z := ZoneDef.new()
	z.zone_id = &"test_zone"
	z.spawn_enabled = spawn_enabled
	z.terrain_patches = [patch]
	return z


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- AC-EZ-01: rate 0.0 never triggers --------------------------------------

func test_ez1_rate_zero_never_triggers() -> void:
	# Arrange
	var patch := _patch(0.0)
	var zone := _zone(patch)

	# Act / Assert — two different seeds, all 10,000 steps false each.
	for seed_value in [1, 987654321]:
		var resolver := EncounterResolver.new(_seeded_rng(seed_value))
		var any_triggered := false
		for _i in STEPS:
			if resolver.roll_encounter(zone, patch):
				any_triggered = true
				break
		assert_false(any_triggered, "rate 0.0 must never trigger (seed %d)" % seed_value)


# --- AC-EZ-02: legal boundaries + out-of-range clamp ------------------------

func test_ez1_rate_one_triggers_every_step() -> void:
	# Arrange
	var patch := _patch(1.0)
	var zone := _zone(patch)
	var resolver := EncounterResolver.new(_seeded_rng(42))

	# Act / Assert — rate 1.0 vs half-open [0,1) draw always fires.
	var all_triggered := true
	for _i in STEPS:
		if not resolver.roll_encounter(zone, patch):
			all_triggered = false
			break
	assert_true(all_triggered, "rate 1.0 must trigger every step")


func test_ez1_rate_above_one_logs_content_error_and_clamps_to_one() -> void:
	# Arrange
	var patch := _patch(1.5)
	var zone := _zone(patch)
	var spy := SpyLogSink.new()
	var resolver := EncounterResolver.new(_seeded_rng(7), spy)

	# Act
	var triggered := resolver.roll_encounter(zone, patch)

	# Assert — clamps to 1.0 (always fires) AND logs a content error naming the value.
	assert_true(triggered, "rate 1.5 clamps to 1.0 and triggers")
	assert_eq(spy.warns.size(), 1, "one content-error warning for the out-of-range rate")
	assert_eq(spy.warns[0]["code"], &"ez_encounter_rate_out_of_range", "names the out-of-range condition")
	assert_eq(spy.warns[0]["detail"]["encounter_rate"], 1.5, "detail names the offending value")


func test_ez1_rate_below_zero_logs_content_error_and_never_triggers() -> void:
	# Arrange
	var patch := _patch(-0.3)
	var zone := _zone(patch)
	var spy := SpyLogSink.new()
	var resolver := EncounterResolver.new(_seeded_rng(7), spy)

	# Act / Assert — clamps to 0.0 (never fires) over many steps AND logs once per roll.
	var any_triggered := false
	for _i in 1000:
		if resolver.roll_encounter(zone, patch):
			any_triggered = true
			break
	assert_false(any_triggered, "rate -0.3 clamps to 0.0 and never triggers")
	assert_gt(spy.warns.size(), 0, "at least one content-error warning recorded")
	assert_eq(spy.warns[0]["code"], &"ez_encounter_rate_out_of_range", "names the out-of-range condition")
	assert_eq(spy.warns[0]["detail"]["encounter_rate"], -0.3, "detail names the offending value")


# --- AC-EZ-03: strict `<` discrimination ------------------------------------

func test_ez1_strict_less_than_discriminates_at_rate() -> void:
	# Arrange — scripted draws straddling the rate 0.15; 0.15 is the `<` vs `<=` split.
	var patch := _patch(0.15)
	var zone := _zone(patch)
	var rng := Rng.Queued.new([0.14, 0.15, 0.16])
	var resolver := EncounterResolver.new(rng)

	# Act
	var results: Array[bool] = []
	for _i in 3:
		results.append(resolver.roll_encounter(zone, patch))

	# Assert — 0.14 < 0.15 true; 0.15 < 0.15 FALSE (a `<=` impl yields true); 0.16 false.
	assert_eq(results, [true, false, false] as Array[bool], "strict `<`: [0.14,0.15,0.16] @ 0.15")


# --- AC-EZ-59: encounter-rate modifier hook ---------------------------------

func test_ez1_modifier_jammer_scales_rate_down() -> void:
	# Arrange — Signal Jammer: rate 0.15 × 0.1 = 0.015 (exact in IEEE-754).
	var patch := _patch(0.15)
	var zone := _zone(patch)
	var rng := Rng.Queued.new([0.10])
	var resolver := EncounterResolver.new(rng)

	# Assert — effective rate exact, and the single 0.10 draw discriminates.
	assert_almost_eq(resolver.effective_encounter_rate(patch, 0.1), 0.015, 1e-9, "0.15 × 0.1 == 0.015")
	# 0.10 would fire at base 0.15 (0.10 < 0.15) but NOT at hooked 0.015 — proves the hook applies.
	assert_false(resolver.roll_encounter(zone, patch, 0.1), "0.10 draw does not fire at 0.015")


func test_ez1_modifier_lure_scales_up_without_clamp() -> void:
	# Arrange — Scrap Lure: rate 0.35 × 2.5 = 0.875, NOT clamped to 1.0.
	var patch := _patch(0.35)
	var resolver := EncounterResolver.new(_seeded_rng(1))

	# Assert — exact, and explicitly not clamped.
	var eff := resolver.effective_encounter_rate(patch, 2.5)
	assert_almost_eq(eff, 0.875, 1e-9, "0.35 × 2.5 == 0.875 (no clamp)")
	assert_ne(eff, 1.0, "0.875 must not be clamped to 1.0")


func test_ez1_modifier_identity_reproduces_base_rate() -> void:
	# Arrange — no modifier → default 1.0 identity, base EZ-1 unchanged.
	var patch := _patch(0.42)
	var resolver := EncounterResolver.new(_seeded_rng(1))

	# Assert
	assert_almost_eq(resolver.effective_encounter_rate(patch), 0.42, 1e-9, "identity modifier == base rate")


func test_ez1_modifier_clamps_ceiling_without_content_error() -> void:
	# Arrange — rate 0.5 × 2.5 = 1.25 → clamps to 1.0; this is NOT a content error.
	var patch := _patch(0.5)
	var spy := SpyLogSink.new()
	var resolver := EncounterResolver.new(_seeded_rng(1), spy)

	# Assert — clamped to 1.0, and NO warning logged (base 0.5 was in range).
	assert_almost_eq(resolver.effective_encounter_rate(patch, 2.5), 1.0, 1e-9, "clamp(1.25) == 1.0")
	assert_eq(spy.warns.size(), 0, "modifier-ceiling clamp is not a content error")


# --- AC-EZ-57: zone-level spawn_enabled == false → inert ---------------------

func test_ez1_zone_spawn_disabled_is_inert_no_draw() -> void:
	# Arrange — a valid, populated patch at a firing rate, but zone master switch OFF.
	var patch := _patch(1.0)
	var entry := SpawnEntry.new()
	entry.enemy_id = &"rust_hound"
	entry.spawn_weight = 10  # enemy-level presence is valid — proves the guard is ZONE-level.
	patch.enemy_subpool = [entry]
	var zone := _zone(patch, false)
	var rng := Rng.Const.new(0.0)  # would fire at rate 1.0 if ever drawn
	var resolver := EncounterResolver.new(rng)

	# Act
	var triggered := resolver.roll_encounter(zone, patch)

	# Assert — no trigger, and crucially NO RNG draw (the AC-EZ-57 discriminator).
	assert_false(triggered, "disabled zone never triggers")
	assert_eq(rng.call_count, 0, "inert zone must not draw (EZ-1 never rolls, EZ-2 never called)")
