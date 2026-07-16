## Part-DB Story 005 — Formula 1 (total Symbot stat composition).
##
## Covers GDD AC-05 (a)(b): floor + max(0) + chassis-modifier lookup, and the
## PIPELINE-COMPOSITION discriminator — Formula 1 must consume Formula 2/2b
## UPGRADED values (Story 004 output), never raw `stat_bonuses`. The AC-2 tests
## compose through [UpgradeFormula] on purpose so a raw-feed implementation fails.
## Integer results → strict `==`. Framework: GUT · Godot 4.7.
extends GutTest

var _cfg: BalanceConfig


func before_each() -> void:
	_cfg = BalanceConfig.new()  # defaults mirror the GDD chassis modifier table


func _final(stat: StringName, values: Array[int], arch: PartDef.ChassisArchetype) -> int:
	return TotalStatFormula.compute_final_stat(stat, values, arch, _cfg)


# ---------------------------------------------------------------------------
# AC-1 (GDD AC-05 a): floor (not round/ceil) + max(0) + chassis modifier
# ---------------------------------------------------------------------------

func test_ac_01_floor_not_round_or_ceil() -> void:
	# 7 × 0.80 = 5.6 → floor 5 (round→6, ceil→6 would both be wrong).
	assert_eq(_final(&"mobility", [7], PartDef.ChassisArchetype.HEAVY_FRAME), 5,
		"floor(7 × 0.80) = 5, not 6")


func test_ac_01_gdd_worked_example_heavy_frame() -> void:
	# GDD Formula 1 worked example (Structure 90, Mobility 40, Armor 30 · Heavy).
	assert_eq(_final(&"structure", [90], PartDef.ChassisArchetype.HEAVY_FRAME), 112, "90 × 1.25 = 112")
	assert_eq(_final(&"mobility", [40], PartDef.ChassisArchetype.HEAVY_FRAME), 32, "40 × 0.80 = 32")
	assert_eq(_final(&"armor", [30], PartDef.ChassisArchetype.HEAVY_FRAME), 36, "30 × 1.20 = 36")


func test_ac_01_exact_integer_after_modifier() -> void:
	# 40 × 1.25 = 50.0 exactly — the epsilon must not bump it to 51.
	assert_eq(_final(&"structure", [40], PartDef.ChassisArchetype.HEAVY_FRAME), 50,
		"an exact-integer product stays put (no epsilon over-bump)")


func test_ac_01_multiple_parts_sum_before_modifier() -> void:
	# Modifier applies to the SUM, not per-part: (10+15+15) × 0.80 = 32.
	assert_eq(_final(&"mobility", [10, 15, 15], PartDef.ChassisArchetype.HEAVY_FRAME), 32,
		"the chassis modifier scales the summed total, not each part")


func test_ac_01_negative_preclamp_sum_yields_zero() -> void:
	# max(0, …) is load-bearing: a negative running total clamps to 0, not negative.
	assert_eq(_final(&"armor", [-30], PartDef.ChassisArchetype.BALANCED_FRAME), 0,
		"a negative pre-clamp sum yields 0, never a negative stat")
	assert_eq(_final(&"physical_power", [-10], PartDef.ChassisArchetype.GUARDIAN_FRAME), 0,
		"a chassis penalty on a negative sum still clamps at 0")


func test_ac_01_empty_and_zero_sum() -> void:
	assert_eq(_final(&"structure", [], PartDef.ChassisArchetype.LIGHT_FRAME), 0, "no parts → 0")
	assert_eq(_final(&"structure", [0], PartDef.ChassisArchetype.HEAVY_FRAME), 0, "zero sum → 0")


# ---------------------------------------------------------------------------
# AC-2 (GDD AC-05 b): PIPELINE composition — never raw stat_bonuses
# ---------------------------------------------------------------------------

func test_ac_02_composes_through_upgrade_formula_not_raw() -> void:
	# Prototype part: stat_bonuses["armor"] = -15 at tier +1 → F2b → -10.
	# Second part: stat_bonuses["armor"] = +12 at tier +0 → F2 → +12.
	# Balanced Frame: armor not in its row → ×1.0.  max(0, floor((-10 + 12))) = 2.
	var upgraded_drawback := UpgradeFormula.upgraded_value(-15, 1, _cfg)
	var upgraded_bonus := UpgradeFormula.upgraded_value(12, 0, _cfg)
	assert_eq(upgraded_drawback, -10, "F2b sanity: -15 at +1 → -10")
	assert_eq(upgraded_bonus, 12, "F2 sanity: +12 at +0 → +12")

	var composed: Array[int] = [upgraded_drawback, upgraded_bonus]
	assert_eq(_final(&"armor", composed, PartDef.ChassisArchetype.BALANCED_FRAME), 2,
		"composed pipeline → max(0, floor((-10 + 12) × 1.0)) = 2")


func test_ac_02_raw_feed_wrong_impl_would_yield_zero() -> void:
	# The discriminator: feeding RAW stat_bonuses (-15, +12) sums to -3 → clamps to 0.
	# This proves the formula itself is faithful; the CORRECT result (2 above) is only
	# reachable by composing through Formula 2/2b first.
	assert_eq(_final(&"armor", [-15, 12], PartDef.ChassisArchetype.BALANCED_FRAME), 0,
		"raw-feed (-15 + 12) = -3 → 0 ≠ 2 — the composed value must be supplied")


# ---------------------------------------------------------------------------
# Chassis modifier table — every archetype row + the ×1.0 fallthrough
# ---------------------------------------------------------------------------

func test_stat_absent_from_table_uses_neutral_modifier() -> void:
	# Targeting / Recharge are in no archetype row → ×1.0 for all archetypes.
	assert_eq(_final(&"targeting", [50], PartDef.ChassisArchetype.HEAVY_FRAME), 50, "targeting ×1.0")
	assert_eq(_final(&"recharge", [30], PartDef.ChassisArchetype.ARTILLERY_FRAME), 30, "recharge ×1.0")


func test_archetype_absent_from_table_uses_neutral_modifier() -> void:
	# The 0 sentinel (no archetype) resolves to the neutral ×1.0 defensively.
	assert_eq(TotalStatFormula.compute_final_stat(&"structure", [50], 0, _cfg), 50,
		"an unmapped archetype falls through to ×1.0")


func test_light_frame_row() -> void:
	assert_eq(_final(&"structure", [40], PartDef.ChassisArchetype.LIGHT_FRAME), 34, "structure ×0.85")
	assert_eq(_final(&"mobility", [40], PartDef.ChassisArchetype.LIGHT_FRAME), 48, "mobility ×1.20")


func test_balanced_frame_row() -> void:
	assert_eq(_final(&"processing", [20], PartDef.ChassisArchetype.BALANCED_FRAME), 21, "processing ×1.05")
	assert_eq(_final(&"cooling", [20], PartDef.ChassisArchetype.BALANCED_FRAME), 21, "cooling ×1.05")
	assert_eq(_final(&"structure", [40], PartDef.ChassisArchetype.BALANCED_FRAME), 40, "no penalty elsewhere")


func test_guardian_frame_row() -> void:
	assert_eq(_final(&"resistance", [50], PartDef.ChassisArchetype.GUARDIAN_FRAME), 60, "resistance ×1.20")
	assert_eq(_final(&"physical_power", [20], PartDef.ChassisArchetype.GUARDIAN_FRAME), 17, "physical_power ×0.85")


func test_artillery_frame_row() -> void:
	assert_eq(_final(&"energy_power", [50], PartDef.ChassisArchetype.ARTILLERY_FRAME), 60, "energy_power ×1.20")
	assert_eq(_final(&"armor", [40], PartDef.ChassisArchetype.ARTILLERY_FRAME), 34, "armor ×0.85")
