## Damage-Formula Story 003 — `DamageFormula.resolve` routed composition.
##
## Covers the DF-1 damage-type routing table + full end-to-end composition:
##   AC-DF-03 (PHYSICAL binds physical_power/armor, cross-checked vs the energy swap),
##   AC-DF-04 (ENERGY binds energy_power/resistance, cross-checked vs the physical swap),
##   AC-DF-05/06/07 (element path: VOLT skill vs THERMAL/VOLT/KINETIC Core → 50/33/25),
##   and the purity + `crit_mult` pass-through guarantee.
##
## The cross-check assertions (`assert_ne`) are the point: a swapped A/D binding
## still returns *a* number, so each routing test also pins the value the WRONG
## binding would have produced and proves it is NOT returned. AC-DF-06's `33` (not
## `34`) discriminates floor-vs-round; AC-DF-07's `25` (not `24`) discriminates the
## pre-floor T order. Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/damage-formula/spy_log_sink.gd")

const PHYSICAL := PartDef.DamageType.PHYSICAL
const ENERGY := PartDef.DamageType.ENERGY

const VOLT := PartDef.Element.VOLT
const THERMAL := PartDef.Element.THERMAL
const KINETIC := PartDef.Element.KINETIC

var _cfg: BalanceConfig
var _spy


func before_each() -> void:
	# Fresh BalanceConfig — its @export defaults are the locked GDD grid
	# (damage_floor = 1, the Rule 6 type_chart).
	_cfg = BalanceConfig.new()
	_spy = SpyLogSink.new()


# ---------------------------------------------------------------------------
# AC-DF-03 — PHYSICAL binds A = physical_power, D = armor
# ---------------------------------------------------------------------------

func test_resolve_physical_binds_physical_power_and_armor() -> void:
	# Arrange: distinct physical vs energy stats so a swapped binding is visible.
	var attacker := {&"physical_power": 53, &"energy_power": 40}
	var target := {&"armor": 30, &"resistance": 20}

	# Act: null elements → T = 1.0 (neutral), so only the A/D binding is under test.
	var result := DamageFormula.resolve(attacker, PHYSICAL, null, target, null, _cfg, _spy)

	# Assert: 53²/(53+30) × 1.0 → floor 33.
	assert_eq(result, 33, "PHYSICAL binds physical_power=53 vs armor=30 → 33")


func test_resolve_physical_is_not_the_energy_binding() -> void:
	# Cross-check (AC-DF-03): the WRONG binding (energy_power=40 vs resistance=20)
	# would give 40²/60 → 26. Prove the router did not read the energy stats.
	var attacker := {&"physical_power": 53, &"energy_power": 40}
	var target := {&"armor": 30, &"resistance": 20}
	var result := DamageFormula.resolve(attacker, PHYSICAL, null, target, null, _cfg, _spy)
	assert_ne(result, 26, "must NOT read energy_power/resistance on a PHYSICAL skill")


# ---------------------------------------------------------------------------
# AC-DF-04 — ENERGY binds A = energy_power, D = resistance
# ---------------------------------------------------------------------------

func test_resolve_energy_binds_energy_power_and_resistance() -> void:
	# Arrange: physical stats are the larger, decoy pair.
	var attacker := {&"physical_power": 60, &"energy_power": 40}
	var target := {&"armor": 20, &"resistance": 30}

	# Act: T = 1.0 (null elements).
	var result := DamageFormula.resolve(attacker, ENERGY, null, target, null, _cfg, _spy)

	# Assert: 40²/(40+30) × 1.0 → floor 22.
	assert_eq(result, 22, "ENERGY binds energy_power=40 vs resistance=30 → 22")


func test_resolve_energy_is_not_the_physical_binding() -> void:
	# Cross-check (AC-DF-04): the WRONG binding (physical_power=60 vs armor=20)
	# would give 60²/80 → 45. Prove the router did not read the physical stats.
	var attacker := {&"physical_power": 60, &"energy_power": 40}
	var target := {&"armor": 20, &"resistance": 30}
	var result := DamageFormula.resolve(attacker, ENERGY, null, target, null, _cfg, _spy)
	assert_ne(result, 45, "must NOT read physical_power/armor on an ENERGY skill")


# ---------------------------------------------------------------------------
# AC-DF-05/06/07 — end-to-end element path (A = 53, D = 30 via ENERGY stats)
# ---------------------------------------------------------------------------

func _resolve_volt_vs(core_element) -> int:
	# Shared arrange for the element trio: a VOLT ENERGY skill (energy_power = 53)
	# against a target with resistance = 30, varying only the target Core element.
	var attacker := {&"energy_power": 53}
	var target := {&"resistance": 30}
	return DamageFormula.resolve(attacker, ENERGY, VOLT, target, core_element, _cfg, _spy)


func test_resolve_volt_vs_thermal_core_is_super_effective() -> void:
	# AC-DF-05: T = 1.5 → 53²/83 × 1.5 = 50.76 → floor 50 (×1.0 would be 33).
	var result := _resolve_volt_vs(THERMAL)
	assert_eq(result, 50, "VOLT skill vs THERMAL Core → T=1.5 → 50")
	assert_ne(result, 33, "the ×1.5 super-effective path must NOT collapse to the neutral 33")


func test_resolve_volt_vs_volt_core_is_neutral() -> void:
	# AC-DF-06: T = 1.0 → 53²/83 = 33.84 → floor 33 (NOT round 34).
	var result := _resolve_volt_vs(VOLT)
	assert_eq(result, 33, "VOLT skill vs VOLT Core → T=1.0 → 33")
	assert_ne(result, 34, "single floor, never round — 33.84 floors to 33, not 34")


func test_resolve_volt_vs_kinetic_core_is_resisted() -> void:
	# AC-DF-07: T = 0.75 pre-floor → 53²/83 × 0.75 = 25.38 → floor 25.
	# The WRONG post-floor order (33 × 0.75 = 24.75 → 24) must NOT be returned.
	var result := _resolve_volt_vs(KINETIC)
	assert_eq(result, 25, "VOLT skill vs KINETIC Core → T=0.75 pre-floor → 25")
	assert_ne(result, 24, "T is applied pre-floor — must NOT floor first then scale (24)")


func test_resolve_physical_branch_also_applies_type_effectiveness() -> void:
	# Guards the element path through the PHYSICAL branch (AC-DF-05/06/07 only exercise
	# ENERGY): a bug that derives T in one branch but not the other would slip past them.
	# VOLT skill vs THERMAL Core → T=1.5; physical_power=53 / armor=30 → 53²/83 × 1.5 → 50.
	var attacker := {&"physical_power": 53}
	var target := {&"armor": 30}
	var result := DamageFormula.resolve(attacker, PHYSICAL, VOLT, target, THERMAL, _cfg, _spy)
	assert_eq(result, 50, "PHYSICAL branch derives T too — VOLT vs THERMAL → ×1.5 → 50")
	assert_ne(result, 33, "T must apply on the PHYSICAL branch, not collapse to neutral 33")


# ---------------------------------------------------------------------------
# Purity + crit_mult pass-through
# ---------------------------------------------------------------------------

func test_resolve_is_pure_same_inputs_same_result() -> void:
	# No runtime state: two identical calls must return identical results.
	var attacker := {&"energy_power": 53}
	var target := {&"resistance": 30}
	var first := DamageFormula.resolve(attacker, ENERGY, VOLT, target, THERMAL, _cfg, _spy)
	var second := DamageFormula.resolve(attacker, ENERGY, VOLT, target, THERMAL, _cfg, _spy)
	assert_eq(first, second, "resolve is pure — identical args yield identical output")


func test_resolve_passes_crit_mult_through_to_kernel() -> void:
	# crit_mult = 2.0 on the (53, 30, VOLT→THERMAL) case: 53²/83 × 1.5 × 2.0
	# = 101.53 → floor 101. Proves the multiplier reaches the kernel pre-floor.
	var attacker := {&"energy_power": 53}
	var target := {&"resistance": 30}
	var result := DamageFormula.resolve(attacker, ENERGY, VOLT, target, THERMAL, _cfg, _spy, 2.0)
	assert_eq(result, 101, "crit_mult=2.0 → 53²/83 × 1.5 × 2.0 → floor 101")


func test_resolve_defaults_crit_mult_to_one() -> void:
	# Omitting crit_mult must equal passing 1.0 (default pass-through parameter).
	var attacker := {&"energy_power": 53}
	var target := {&"resistance": 30}
	var defaulted := DamageFormula.resolve(attacker, ENERGY, VOLT, target, THERMAL, _cfg, _spy)
	var explicit := DamageFormula.resolve(attacker, ENERGY, VOLT, target, THERMAL, _cfg, _spy, 1.0)
	assert_eq(defaulted, explicit, "default crit_mult == explicit 1.0")


# ---------------------------------------------------------------------------
# Unknown damage_type — degrades to ENERGY binding + warns (never silent)
# ---------------------------------------------------------------------------

func test_resolve_unknown_damage_type_warns_and_degrades_to_energy() -> void:
	# A damage_type that is neither PHYSICAL(1) nor ENERGY(2) is a caller/content bug.
	# It must NOT crash: degrade to the ENERGY binding AND surface a warn so it is
	# never silent (ADR-0002 §5 recoverable anomaly). 99 is an out-of-enum sentinel.
	var attacker := {&"physical_power": 60, &"energy_power": 40}
	var target := {&"armor": 20, &"resistance": 30}
	var result := DamageFormula.resolve(attacker, 99, null, target, null, _cfg, _spy)

	# Degrades to ENERGY: energy_power=40 vs resistance=30 → 40²/70 → 22 (not the
	# PHYSICAL binding's 45), confirming the fallthrough uses the energy stats.
	assert_eq(result, 22, "unknown damage_type degrades to the ENERGY binding → 22")
	assert_eq(_spy.warns.size(), 1, "exactly one warn emitted for the unknown type")
	assert_eq(_spy.warns[0]["code"], &"damage_routing_unknown_damage_type",
		"the warn carries the routing diagnostic code")
	assert_eq(_spy.warns[0]["detail"].get(&"damage_type"), 99,
		"the warn detail reports the offending damage_type value")


func test_resolve_known_damage_types_emit_no_warning() -> void:
	# The happy path must stay silent — a PHYSICAL and an ENERGY call emit nothing.
	DamageFormula.resolve({&"physical_power": 53}, PHYSICAL, null, {&"armor": 30}, null, _cfg, _spy)
	DamageFormula.resolve({&"energy_power": 40}, ENERGY, null, {&"resistance": 30}, null, _cfg, _spy)
	assert_eq(_spy.warns.size(), 0, "known damage types route without any diagnostic")


# ---------------------------------------------------------------------------
# Routing edge — missing stat degrades to 0 (kernel guard handles it)
# ---------------------------------------------------------------------------

func test_resolve_missing_attack_stat_degrades_to_floor() -> void:
	# An absent attacker stat reads 0; with D=0 too the kernel's a==0 and d==0
	# guard returns the damage_floor (1) instead of dividing 0/0.
	var result := DamageFormula.resolve({}, PHYSICAL, null, {}, null, _cfg, _spy)
	assert_eq(result, _cfg.damage_floor, "missing stats → A=0,D=0 → kernel floor guard")
