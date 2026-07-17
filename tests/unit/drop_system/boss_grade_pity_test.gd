## DS-5 Boss-grade floor-pity unit spec (Drop System Story 005).
##
## The DS-3 pity model: per-Boss-grade-ID integer break counter, a PRE-ROLL guarantee
## at M_BOSS_PITY = 8, `+= 1` per qualifying-break miss, reset on any drop, and a
## counter that only advances when the part's break actually fires.
##   AC-DS-16 trigger at counter 8, not 7; guarantee skips the RNG
##   AC-DS-17 nominal `+= 1` increment from a low counter
##   AC-DS-09 Boss-grade won WITHOUT the qualifying break → counter unchanged
##   AC-DS-30 counter resets to 0 on a natural sub-threshold drop
##   AC-DS-24 counters are per-part-ID (independent; joint guarantee draws zero RNG)
##   AC-DS-01 emit contract — one instance at upgrade_tier 0, counter reset
##   AC-DS-26 drop_enabled gates the pity update (negative + positive companion)
##
## forge_core / volt_cannon: Boss-grade (base 0.001), one break condition ×500 →
## effective rate 0.001 × 500 = 0.5 when the break fires.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")

var _balance: BalanceConfig
var _log: SpyLogSink


## Inventory sink spy — records every instance handed over on a successful roll.
class SpyInventory:
	extends InventorySink
	var received: Array[PartInstance] = []

	func receive_part_instance(instance: PartInstance) -> void:
		received.append(instance)


func before_each() -> void:
	_balance = BalanceConfig.new()
	_log = SpyLogSink.new()


func _make_drop_system(rng: RandomNumberGenerator, inventory: InventorySink = null) -> DropSystem:
	return DropSystem.new(rng, _balance, _log, inventory)


## A break-gated Boss-grade part: base 0.001 × 500 = 0.5 when `break_key` fires.
func _make_boss(id: StringName, break_key: StringName, drop_enabled: bool = true) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = PartDef.Rarity.BOSS_GRADE
	p.drop_enabled = drop_enabled
	p.drop_conditions = [{"condition": break_key, "multiplier": 500.0}]
	return p


func _resolve(ds: DropSystem, part: PartDef, fired: Dictionary) -> int:
	var pool: Array[PartDef] = [part]
	return ds.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired).size()


# --- AC-DS-16: trigger at counter 8, not 7 ---
func test_boss_pity_triggers_at_eight_not_seven() -> void:
	var forge := _make_boss(&"forge_core", &"core_broken")
	var fired := {&"core_broken": true}  # qualifying break

	# A: counter 7, qualifying, draw 0.60 (> 0.5) → 7 ≥ 8 false → miss → counter 8.
	var rng_a := Rng.Const.new(0.60)
	var ds_a := _make_drop_system(rng_a)
	ds_a.set_break_pity_counter(&"forge_core", 7)
	assert_eq(_resolve(ds_a, forge, fired), 0, "7 < 8 and 0.60 ≥ 0.5 → no drop")
	assert_eq(ds_a.get_break_pity_counter(&"forge_core"), 8, "qualifying miss → += 1 → 8")
	assert_eq(rng_a.call_count, 1, "a non-guaranteed attempt draws once")

	# B: counter 8, qualifying → guaranteed, RNG not called, counter → 0, emitted.
	var rng_b := Rng.Const.new(0.60)
	var ds_b := _make_drop_system(rng_b)
	ds_b.set_break_pity_counter(&"forge_core", 8)
	assert_eq(_resolve(ds_b, forge, fired), 1, "8 ≥ 8 → guaranteed drop")
	assert_eq(rng_b.call_count, 0, "a guaranteed drop is pre-roll — RNG untouched")
	assert_eq(ds_b.get_break_pity_counter(&"forge_core"), 0, "guarantee resets counter")


# --- AC-DS-17: nominal += 1 increment from a low counter ---
func test_boss_pity_increments_by_one_from_low_counter() -> void:
	var forge := _make_boss(&"forge_core", &"core_broken")
	var fired := {&"core_broken": true}
	var rng := Rng.Const.new(0.60)  # 0.60 ≥ 0.5 → miss
	var ds := _make_drop_system(rng)

	ds.set_break_pity_counter(&"forge_core", 0)
	assert_eq(_resolve(ds, forge, fired), 0, "miss at counter 0")
	assert_eq(ds.get_break_pity_counter(&"forge_core"), 1, "0 → 1")
	assert_eq(_resolve(ds, forge, fired), 0, "miss at counter 1")
	assert_eq(ds.get_break_pity_counter(&"forge_core"), 2, "1 → 2")


# --- AC-DS-09: Boss-grade won without the qualifying break → counter unchanged ---
func test_boss_win_without_break_does_not_increment_counter() -> void:
	var forge := _make_boss(&"forge_core", &"core_broken")
	var fired := {}  # no break fired → non-qualifying; rolls at bare 0.001
	var rng := Rng.Const.new(0.5)  # 0.5 ≥ 0.001 → no drop
	var ds := _make_drop_system(rng)
	ds.set_break_pity_counter(&"forge_core", 3)

	assert_eq(_resolve(ds, forge, fired), 0, "0.5 ≥ 0.001 base → no drop")
	assert_eq(ds.get_break_pity_counter(&"forge_core"), 3,
		"no qualifying break → counter untouched (stays 3), no break-failure tail")


# --- AC-DS-30: counter resets to 0 on a natural sub-threshold drop ---
func test_boss_counter_resets_on_natural_drop_below_threshold() -> void:
	var forge := _make_boss(&"forge_core", &"core_broken")
	var fired := {&"core_broken": true}  # rate 0.5
	var rng := Rng.Const.new(0.30)  # 0.30 < 0.5 → natural drop
	var ds := _make_drop_system(rng)
	ds.set_break_pity_counter(&"forge_core", 5)  # below the 8 threshold

	assert_eq(_resolve(ds, forge, fired), 1, "0.30 < 0.5 → natural drop")
	assert_eq(ds.get_break_pity_counter(&"forge_core"), 0,
		"any drop resets to 0 — not 5 (unchanged) or 6 (+=1 on a drop)")


# --- AC-DS-24: pity counters are per-part-ID, not global ---
func test_boss_pity_counters_are_per_part_id() -> void:
	# ID-asc order is forge_core < volt_cannon.
	var forge := _make_boss(&"forge_core", &"core_broken")
	var volt := _make_boss(&"volt_cannon", &"weapon_broken")
	var pool: Array[PartDef] = [forge, volt]
	var fired := {&"core_broken": true, &"weapon_broken": true}  # both qualify

	# A: forge_core at 8 (guaranteed, no draw), volt_cannon at 2 (draws 0.60 → miss → 3).
	var rng_a := Rng.Queued.new([0.60])  # the single draw goes to volt_cannon
	var ds_a := _make_drop_system(rng_a)
	ds_a.set_break_pity_counter(&"forge_core", 8)
	ds_a.set_break_pity_counter(&"volt_cannon", 2)
	var drops_a := ds_a.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired)
	assert_eq(drops_a.size(), 1, "only forge_core (guaranteed) drops; volt_cannon misses")
	assert_eq(drops_a[0].part.id, &"forge_core", "the guaranteed drop is forge_core")
	assert_eq(rng_a.call_count, 1, "forge_core's guarantee consumes no draw; only volt_cannon rolls")
	assert_eq(ds_a.get_break_pity_counter(&"forge_core"), 0, "forge_core guarantee reset")
	assert_eq(ds_a.get_break_pity_counter(&"volt_cannon"), 3, "volt_cannon miss → 2 → 3 (independent)")

	# B: both at 8 → joint guarantee, ZERO draws, two instances, both counters reset.
	var rng_b := Rng.Queued.new([])  # armed with no draws — any draw would be a bug
	var ds_b := _make_drop_system(rng_b)
	ds_b.set_break_pity_counter(&"forge_core", 8)
	ds_b.set_break_pity_counter(&"volt_cannon", 8)
	var drops_b := ds_b.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired)
	assert_eq(drops_b.size(), 2, "both guaranteed → two instances")
	assert_eq(rng_b.call_count, 0, "two joint guarantees draw the RNG zero times")
	assert_eq(ds_b.get_break_pity_counter(&"forge_core"), 0, "forge_core reset")
	assert_eq(ds_b.get_break_pity_counter(&"volt_cannon"), 0, "volt_cannon reset")


# --- AC-DS-01: emit contract — one instance at upgrade_tier 0, counter reset ---
func test_boss_pity_guaranteed_emit_contract() -> void:
	var forge := _make_boss(&"forge_core", &"core_broken")
	var fired := {&"core_broken": true}
	var spy := SpyInventory.new()
	var ds := _make_drop_system(Rng.Const.new(0.60), spy)
	ds.set_break_pity_counter(&"forge_core", 8)  # guaranteed

	_resolve(ds, forge, fired)
	assert_eq(spy.received.size(), 1, "Inventory receives exactly one instance")
	assert_eq(spy.received[0].part.id, &"forge_core", "correct part_id")
	assert_eq(spy.received[0].tier, 0, "emitted at upgrade_tier 0")
	assert_eq(ds.get_break_pity_counter(&"forge_core"), 0, "counter reset after the guaranteed emit")


# --- AC-DS-26: drop_enabled gates the pity update (negative + positive) ---
func test_drop_enabled_gates_boss_pity_update() -> void:
	var fired := {&"core_broken": true}  # qualifying break in both scenarios

	# A (negative): drop_enabled = false → filtered before the loop → counter stays 3,
	# no emit, RNG not consumed.
	var disabled := _make_boss(&"forge_core", &"core_broken", false)
	var rng_a := Rng.Const.new(0.60)
	var ds_a := _make_drop_system(rng_a)
	ds_a.set_break_pity_counter(&"forge_core", 3)
	assert_eq(_resolve(ds_a, disabled, fired), 0, "disabled part never drops")
	assert_eq(ds_a.get_break_pity_counter(&"forge_core"), 3, "disabled part's counter does not advance")
	assert_eq(rng_a.call_count, 0, "disabled part consumes no draw")

	# B (positive companion): drop_enabled = true, counter 3, qualifying, draw 0.60 →
	# miss → counter 4 (guards against omitting the increment entirely).
	var enabled := _make_boss(&"forge_core", &"core_broken", true)
	var rng_b := Rng.Const.new(0.60)
	var ds_b := _make_drop_system(rng_b)
	ds_b.set_break_pity_counter(&"forge_core", 3)
	assert_eq(_resolve(ds_b, enabled, fired), 0, "0.60 ≥ 0.5 → miss")
	assert_eq(ds_b.get_break_pity_counter(&"forge_core"), 4, "enabled qualifying miss → 3 → 4")
