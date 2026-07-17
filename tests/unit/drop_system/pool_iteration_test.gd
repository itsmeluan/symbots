## DS-3 pool-iteration unit spec (Drop System Story 003).
##
## Governs WHICH parts get a roll and HOW MANY rolls — orthogonal to the DS-1
## per-part formula (Story 001) and condition assembly (Story 002):
##   AC-DS-12 independent per-part rolls, no `÷ pool_size` dilution
##   AC-DS-08 duplicate part ID deduped to exactly one roll
##   AC-DS-06 empty / disabled pool → zero drops, no crash, no wasted draw
##
## Draw-count is the load-bearing assertion (a disabled or deduped-away part must
## not advance the seeded stream), so the RNG double records its call count.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")

var _balance: BalanceConfig
var _log: SpyLogSink


func before_each() -> void:
	_balance = BalanceConfig.new()
	_log = SpyLogSink.new()


func _make_drop_system(rng: RandomNumberGenerator) -> DropSystem:
	return DropSystem.new(rng, _balance, _log, null)


func _make_part(id: StringName, rarity: int, drop_enabled: bool = true) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = rarity
	p.drop_enabled = drop_enabled
	return p


# --- AC-DS-12: independent per-part rolls, no pool dilution (verifies R2) ---
func test_independent_rolls_no_pool_size_dilution() -> void:
	# 5 distinct parts; ID-asc order is armor_seal < bolt_plate < grip_ring <
	# servo_arm < wire_coil, so the 4th draw (0.10) lands on the Rare servo_arm.
	var pool: Array[PartDef] = [
		_make_part(&"bolt_plate", PartDef.Rarity.COMMON),   # 0.70
		_make_part(&"wire_coil", PartDef.Rarity.COMMON),    # 0.70
		_make_part(&"grip_ring", PartDef.Rarity.COMMON),    # 0.70
		_make_part(&"servo_arm", PartDef.Rarity.RARE),      # 0.25
		_make_part(&"armor_seal", PartDef.Rarity.COMMON),   # 0.70
	]
	var rng := Rng.Queued.new([0.65, 0.65, 0.65, 0.10, 0.65])  # ID-asc order
	var drops := _make_drop_system(rng).resolve_drops(DropSystem.OUTCOME_VICTORY, pool, {})
	assert_eq(drops.size(), 5, "all 5 drop (servo_arm at its own 0.25, not 0.25÷5)")
	assert_eq(rng.call_count, 5, "exactly one Bernoulli draw per unique part")

	# 10-part pool: servo_arm still rolls at 0.25 (draw 0.10 drops it; a ÷10 impl at
	# 0.025 would NOT drop at 0.10).
	var big: Array[PartDef] = []
	for i in range(9):
		big.append(_make_part(StringName("filler_%d" % i), PartDef.Rarity.COMMON))
	big.append(_make_part(&"servo_arm", PartDef.Rarity.RARE))
	var drops_big := _make_drop_system(Rng.Const.new(0.10)).resolve_drops(
		DropSystem.OUTCOME_VICTORY, big, {})
	assert_eq(drops_big.size(), 10, "0.10 < 0.25 and < 0.70 → all 10 drop; no pool-size dilution")


# --- AC-DS-08: duplicate part ID deduped to one roll (verifies EC-DS-08) ---
func test_duplicate_part_id_deduped_to_single_roll() -> void:
	var servo := _make_part(&"servo_arm", PartDef.Rarity.RARE)  # 0.25
	var dup_pool: Array[PartDef] = [servo, servo]  # same id listed twice

	# One draw 0.20 (< 0.25) → deduped to one roll → one instance, RNG called once.
	var rng := Rng.Queued.new([0.20])
	var drops := _make_drop_system(rng).resolve_drops(DropSystem.OUTCOME_VICTORY, dup_pool, {})
	assert_eq(drops.size(), 1, "duplicate id → exactly one instance (not two trials)")
	assert_eq(rng.call_count, 1, "duplicate id consumes exactly one draw")

	# Draw 0.30 (≥ 0.25) → one roll, zero instances (not over-deduped to zero rolls).
	var rng2 := Rng.Queued.new([0.30])
	var none := _make_drop_system(rng2).resolve_drops(DropSystem.OUTCOME_VICTORY, dup_pool, {})
	assert_eq(none.size(), 0, "0.30 ≥ 0.25 → no drop")
	assert_eq(rng2.call_count, 1, "still exactly one draw (part not dropped from the pool)")


# --- AC-DS-06: empty / disabled pool → zero drops, no crash, no wasted draw ---
func test_empty_and_disabled_pool_yields_no_drops_without_draw() -> void:
	# A: empty pool → [] and no draw.
	var rng_a := Rng.Queued.new([0.0])
	var empty: Array[PartDef] = []
	assert_eq(_make_drop_system(rng_a).resolve_drops(DropSystem.OUTCOME_VICTORY, empty, {}).size(), 0,
		"empty pool → []")
	assert_eq(rng_a.call_count, 0, "empty pool draws nothing")

	# B: all drop_enabled = false → [] and no draw.
	var rng_b := Rng.Queued.new([0.0, 0.0])
	var disabled: Array[PartDef] = [
		_make_part(&"off_a", PartDef.Rarity.COMMON, false),
		_make_part(&"off_b", PartDef.Rarity.COMMON, false),
	]
	assert_eq(_make_drop_system(rng_b).resolve_drops(DropSystem.OUTCOME_VICTORY, disabled, {}).size(), 0,
		"all-disabled pool → []")
	assert_eq(rng_b.call_count, 0, "disabled parts never consume a draw")

	# C: mixed → only the enabled part is rolled; disabled neither emits nor draws.
	var rng_c := Rng.Const.new(0.10)  # < 0.70, so the enabled Common drops
	var mixed: Array[PartDef] = [
		_make_part(&"on_part", PartDef.Rarity.COMMON, true),    # 0.70
		_make_part(&"off_part", PartDef.Rarity.COMMON, false),
	]
	var drops_c := _make_drop_system(rng_c).resolve_drops(DropSystem.OUTCOME_VICTORY, mixed, {})
	assert_eq(drops_c.size(), 1, "only the enabled part drops")
	assert_eq(drops_c[0].part.id, &"on_part", "the disabled part is never emitted")
	assert_eq(rng_c.call_count, 1, "the disabled part does not advance the stream")
