## DS-1 roll-core unit spec (Drop System Story 001).
##
## Covers the canonical DS-1 formula and the VICTORY-only gate:
##   AC-DS-03 pre-clamp > 1.0 guarantees the drop
##   AC-DS-04 strict-`<` boundary (the < vs <= discriminator)
##   AC-DS-05 empty fired set → bare base rates (Boss-grade ~0.001, never 0.0)
##   AC-DS-11 victory-only gate (DEFEAT/FLED draw no RNG)
##   AC-DS-20 every rarity drops at upgrade tier 0
##   AC-DS-27 Phase-6 output list contract
##
## The RNG is stubbed per the story's guidance: subclass RandomNumberGenerator and
## override randf() to return a queued or constant draw, so every assertion is
## deterministic (ADR-0006 — no real randomness in tests).
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")


## Inventory sink spy — records every instance handed over on a successful roll.
class SpyInventory:
	extends InventorySink
	var received: Array[PartInstance] = []

	func receive_part_instance(instance: PartInstance) -> void:
		received.append(instance)


var _balance: BalanceConfig
var _log: SpyLogSink


func before_each() -> void:
	_balance = BalanceConfig.new()
	_log = SpyLogSink.new()


func _make_drop_system(rng: RandomNumberGenerator) -> DropSystem:
	return DropSystem.new(rng, _balance, _log, null)


func _make_part(id: StringName, rarity: int, conditions: Array[Dictionary] = []) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = rarity
	p.drop_conditions = conditions
	return p


# --- AC-DS-03: pre-clamp rate > 1.0 guarantees the drop (verifies EC-DS-04) ---
func test_pre_clamp_rate_over_one_clamps_to_one_and_always_drops() -> void:
	var scrap_bolt := _make_part(&"scrap_bolt", PartDef.Rarity.COMMON, [
		{"condition": &"arm_broken", "multiplier": 1.5},
		{"condition": &"targeting_active", "multiplier": 1.3},
	])
	var fired := {&"arm_broken": true, &"targeting_active": true}
	var pool: Array[PartDef] = [scrap_bolt]

	# 0.70 × 1.5 × 1.3 = 1.365 → clamped to exactly 1.0 (NOT returned as 1.365).
	var ds := _make_drop_system(Rng.Const.new(0.001))
	var rate: float = ds._effective_drop_rate(scrap_bolt, fired, -1, 1.0)
	assert_almost_eq(rate, 1.0, 1e-9, "product 1.365 must clamp to 1.0, not stay unclamped")

	# Both a tiny draw and a near-1.0 draw drop, since every draw is < 1.0.
	assert_eq(ds.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired).size(), 1,
		"draw 0.001 < 1.0 → drops")
	var ds_high := _make_drop_system(Rng.Const.new(0.99))
	assert_eq(ds_high.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired).size(), 1,
		"draw 0.99 < 1.0 → drops")


# --- AC-DS-04: strict-`<` boundary (the canonical < vs <= discriminator) ---
func test_strict_less_than_boundary_rejects_equal_draw() -> void:
	var servo := _make_part(&"servo_arm", PartDef.Rarity.RARE)  # base 0.25
	var pool: Array[PartDef] = [servo]

	# Draw exactly 0.25 is NOT < 0.25 → no drop. A <= impl would drop here and fail.
	var at_boundary := _make_drop_system(Rng.Const.new(0.25)).resolve_drops(
		DropSystem.OUTCOME_VICTORY, pool, {})
	assert_eq(at_boundary.size(), 0, "0.25 is not < 0.25 — strict < rejects the equal draw")

	# Draw 0.24 < 0.25 → drop.
	var below := _make_drop_system(Rng.Const.new(0.24)).resolve_drops(
		DropSystem.OUTCOME_VICTORY, pool, {})
	assert_eq(below.size(), 1, "0.24 < 0.25 → drops")


# --- AC-DS-05: no conditions fired → base rates (verifies EC-DS-01) ---
func test_empty_fired_set_uses_base_rates() -> void:
	# IDs chosen so ID-ascending order is [common, rare, boss] → draws align by rarity.
	var common := _make_part(&"a_common", PartDef.Rarity.COMMON)      # 0.70
	var rare := _make_part(&"b_rare", PartDef.Rarity.RARE)            # 0.25
	var boss := _make_part(&"c_boss", PartDef.Rarity.BOSS_GRADE)      # 0.001
	var pool: Array[PartDef] = [boss, common, rare]  # unsorted on purpose; system sorts by id

	# consumed in ID-asc order: a < b < c
	var rng := Rng.Queued.new([0.65, 0.20, 0.0005])
	var drops := _make_drop_system(rng).resolve_drops(DropSystem.OUTCOME_VICTORY, pool, {})
	assert_eq(drops.size(), 3, "0.65<0.70, 0.20<0.25, 0.0005<0.001 → all three drop at base rate")

	# Boss-grade base is ~0.001, never 0.0: draw 0.002 ≥ 0.001 → no drop.
	var rng2 := Rng.Queued.new([0.002])
	var boss_only: Array[PartDef] = [boss]
	var no_drop := _make_drop_system(rng2).resolve_drops(DropSystem.OUTCOME_VICTORY, boss_only, {})
	assert_eq(no_drop.size(), 0, "0.002 ≥ 0.001 → no drop (Boss-grade base is 0.001, not 0.0)")


# --- AC-DS-11: victory-only gate; DEFEAT/FLED draw no RNG ---
func test_victory_only_gate_blocks_non_victory_without_rng_draw() -> void:
	var scrap := _make_part(&"scrap_bolt", PartDef.Rarity.COMMON)  # 0.70
	var pool: Array[PartDef] = [scrap]

	# VICTORY with a constant 0.65 (< 0.70) → exactly one drop, one sink handoff.
	var rng_v := Rng.Const.new(0.65)
	var spy := SpyInventory.new()
	var ds_v := DropSystem.new(rng_v, _balance, _log, spy)
	var v := ds_v.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, {})
	assert_eq(v.size(), 1, "VICTORY with 0.65 < 0.70 → one drop")
	assert_eq(spy.received.size(), 1, "inventory sink receives exactly one instance")

	# DEFEAT (2) → zero drops, RNG untouched.
	var rng_d := Rng.Const.new(0.65)
	var d := DropSystem.new(rng_d, _balance, _log, null).resolve_drops(2, pool, {})
	assert_eq(d.size(), 0, "DEFEAT → zero drops")
	assert_eq(rng_d.call_count, 0, "DEFEAT must not draw the RNG")

	# FLED (3) → zero drops, RNG untouched.
	var rng_f := Rng.Const.new(0.65)
	var f := DropSystem.new(rng_f, _balance, _log, null).resolve_drops(3, pool, {})
	assert_eq(f.size(), 0, "FLED → zero drops")
	assert_eq(rng_f.call_count, 0, "FLED must not draw the RNG")


# --- AC-DS-20: every rarity drops at upgrade tier 0 (verifies R8) ---
func test_all_rarities_drop_at_upgrade_tier_zero() -> void:
	var pool: Array[PartDef] = [
		_make_part(&"armor_bolt", PartDef.Rarity.COMMON),       # 0.70
		_make_part(&"core_shield", PartDef.Rarity.PROTOTYPE),   # 0.05
		_make_part(&"forge_core", PartDef.Rarity.BOSS_GRADE),   # 0.001 (tightest)
		_make_part(&"servo_arm", PartDef.Rarity.RARE),          # 0.25
	]
	# 0.0009 < every base rate incl. 0.001
	var rng := Rng.Queued.new([0.0009, 0.0009, 0.0009, 0.0009])
	var drops := _make_drop_system(rng).resolve_drops(DropSystem.OUTCOME_VICTORY, pool, {})
	assert_eq(drops.size(), 4, "0.0009 < 0.001 (tightest strict-< boundary) → all four drop")
	for inst in drops:
		assert_eq(inst.tier, 0, "every dropped instance is at upgrade tier 0")


# --- AC-DS-27: Phase-6 output list contract ---
func test_resolution_returns_phase6_part_instance_list() -> void:
	var servo := _make_part(&"servo_arm", PartDef.Rarity.RARE)  # 0.25
	var pool: Array[PartDef] = [servo]
	var drops := _make_drop_system(Rng.Const.new(0.20)).resolve_drops(
		DropSystem.OUTCOME_VICTORY, pool, {})
	assert_not_null(drops, "resolution returns a non-null list")
	assert_eq(drops.size(), 1, "exactly one PartInstance")
	var inst: PartInstance = drops[0]
	assert_eq(inst.part.id, &"servo_arm", "correct part_id")
	assert_eq(inst.tier, 0, "upgrade_tier 0")
