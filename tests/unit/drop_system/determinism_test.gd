## DS-6 determinism capstone spec (Drop System Story 006).
##
## This story writes NO new production code — it proves the emergent determinism
## properties that Stories 001/003/004/005 already compose:
##   AC-DS-21 parts are rolled AND reported in ID-ascending order (not insertion)
##   AC-DS-10 a pity guarantee skips the RNG draw — even for multiple guarantees
##            in one pass (the stream position is guarantee-count-independent)
##   AC-DS-18 same seed + same pity maps → byte-identical drops and post-state
##            (per-instance RNG + per-instance pity maps; no shared static state)
##   AC-DS-02 DEFEAT/FLED → zero emits, both pity maps unchanged, RNG never drawn
##
## Rate-sculpting note (AC-DS-21): three Rare parts get distinct effective rates
## (0.10 / 0.20 / 0.30) via a single fired ×0.4/×0.8/×1.2 condition on the Rare
## base 0.25. Queued draws [0.05, 0.15, 0.25] make ALL THREE drop *only* if the
## draws are consumed in ID-ascending order — any other iteration order changes
## the drop SET, so the test witnesses draw order, not merely report order.
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


## A real seeded RNG — the reproducibility fixture. Production draws through
## `call(&"randf")`, which dispatches to the native method on a real generator.
func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A Rare part with one fired condition scaling its 0.25 base to a target rate.
func _make_rare(id: StringName, cond: StringName, mult: float) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = PartDef.Rarity.RARE
	p.drop_conditions = [{"condition": cond, "multiplier": mult}]
	return p


## A bare Rare part with no conditions → rolls at the flat 0.25 base rate.
func _make_bare_rare(id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = PartDef.Rarity.RARE
	return p


## A break-gated Boss-grade part: 0.001 × 500 = 0.5 when `break_key` fires.
func _make_boss(id: StringName, break_key: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = PartDef.Rarity.BOSS_GRADE
	p.drop_conditions = [{"condition": break_key, "multiplier": 500.0}]
	return p


## A Prototype part with three canonical ×1.5 conditions (C = 3).
func _make_prototype(id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.rarity = PartDef.Rarity.PROTOTYPE
	p.drop_conditions = [
		{"condition": &"zero_defeats", "multiplier": 1.5},
		{"condition": &"flawless", "multiplier": 1.5},
		{"condition": &"no_repairs_used", "multiplier": 1.5},
	]
	return p


func _ids(drops: Array[PartInstance]) -> Array:
	var out: Array = []
	for d in drops:
		out.append(d.part.id)
	return out


# --- AC-DS-21: rolled AND reported in ID-ascending order, not insertion order ---
func test_parts_roll_and_report_in_id_ascending_order() -> void:
	# Distinct rates: alpha 0.25×0.4=0.10, beta 0.25×0.8=0.20, gamma 0.25×1.2=0.30.
	var alpha := _make_rare(&"alpha_core", &"zero_defeats", 0.4)
	var beta := _make_rare(&"beta_core", &"flawless", 0.8)
	var gamma := _make_rare(&"gamma_arm", &"no_repairs_used", 1.2)
	# Inserted NON-alphabetically — insertion-order iteration would be gamma→alpha→beta.
	var pool: Array[PartDef] = [gamma, alpha, beta]
	var fired := {&"zero_defeats": true, &"flawless": true, &"no_repairs_used": true}

	# Draws consumed in ID order: alpha←0.05(<0.10), beta←0.15(<0.20), gamma←0.25(<0.30).
	# Under any other order the drop SET shrinks (e.g. insertion order drops only gamma).
	var rng := Rng.Queued.new([0.05, 0.15, 0.25])
	var ds := _make_drop_system(rng)
	var drops := ds.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired)

	assert_eq(drops.size(), 3, "all three drop — only possible if draws map to parts in ID order")
	assert_eq(_ids(drops), [&"alpha_core", &"beta_core", &"gamma_arm"],
		"report list is ID-ascending (matches roll order), not insertion order")
	assert_eq(rng.call_count, 3, "one draw per part, consumed alpha→beta→gamma")


# --- AC-DS-10 A: a single pity guarantee skips its RNG draw ---
func test_single_guarantee_skips_the_draw() -> void:
	# forge_core < servo_arm. forge_core is guaranteed (Boss counter 8 + qualifying
	# break); servo_arm rolls at 0.25 and consumes the one queued draw.
	var forge := _make_boss(&"forge_core", &"core_broken")
	var servo := _make_bare_rare(&"servo_arm")
	var pool: Array[PartDef] = [forge, servo]
	var fired := {&"core_broken": true}

	var rng := Rng.Queued.new([0.20])  # 0.20 < 0.25 → servo_arm drops
	var ds := _make_drop_system(rng)
	ds.set_break_pity_counter(&"forge_core", 8)  # armed to guarantee
	var drops := ds.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired)

	assert_eq(drops.size(), 2, "both drop: forge_core (guarantee) + servo_arm (roll)")
	assert_eq(rng.call_count, 1, "the guaranteed forge_core consumes no draw — only servo_arm rolls")


# --- AC-DS-10 B: two simultaneous guarantees consume ZERO draws (stream discriminator) ---
func test_multiple_guarantees_do_not_advance_the_stream() -> void:
	# ID order alpha_core < beta_core < gamma_arm. Both cores guaranteed (Boss
	# counter 8 + qualifying break); gamma_arm rolls at 0.25 and takes the ONE draw.
	var alpha := _make_boss(&"alpha_core", &"core_broken")
	var beta := _make_boss(&"beta_core", &"weapon_broken")
	var gamma := _make_bare_rare(&"gamma_arm")
	var pool: Array[PartDef] = [alpha, beta, gamma]
	var fired := {&"core_broken": true, &"weapon_broken": true}

	# Armed with a SINGLE draw — if any guarantee drew, call_count would exceed 1
	# and the stub would begin returning its 0.0 tail.
	var rng := Rng.Queued.new([0.20])
	var ds := _make_drop_system(rng)
	ds.set_break_pity_counter(&"alpha_core", 8)
	ds.set_break_pity_counter(&"beta_core", 8)
	var drops := ds.resolve_drops(DropSystem.OUTCOME_VICTORY, pool, fired)

	assert_eq(drops.size(), 3, "two guaranteed cores + gamma_arm's rolled drop")
	assert_eq(rng.call_count, 1, "two guarantees draw the RNG zero times — only gamma_arm rolls")
	assert_eq(_ids(drops), [&"alpha_core", &"beta_core", &"gamma_arm"], "still ID-ascending")


# --- AC-DS-18: same seed + same pity maps → identical drops and identical post-state ---
func test_same_seed_and_pity_state_reproduces_exactly() -> void:
	# Pool spanning both pity systems + a plain Rare. ID order: delta_core < forge_core < servo_arm.
	# delta_core credit 42 (< 75) → rolls at 0.16875; forge_core counter 5 (< 8) → rolls at 0.5;
	# servo_arm → 0.25. None are guaranteed, so all three consume a draw in ID order.
	var fired := {&"zero_defeats": true, &"flawless": true, &"no_repairs_used": true, &"core_broken": true}

	var pool_a: Array[PartDef] = [_make_prototype(&"delta_core"), _make_boss(&"forge_core", &"core_broken"), _make_bare_rare(&"servo_arm")]
	var ds_a := _make_drop_system(_seeded_rng(424242))
	ds_a.set_prototype_pity_credit(&"delta_core", 42)
	ds_a.set_break_pity_counter(&"forge_core", 5)
	var drops_a := ds_a.resolve_drops(DropSystem.OUTCOME_VICTORY, pool_a, fired)

	# A SECOND, independent instance with the SAME seed and the SAME populated maps.
	var pool_b: Array[PartDef] = [_make_prototype(&"delta_core"), _make_boss(&"forge_core", &"core_broken"), _make_bare_rare(&"servo_arm")]
	var ds_b := _make_drop_system(_seeded_rng(424242))
	ds_b.set_prototype_pity_credit(&"delta_core", 42)
	ds_b.set_break_pity_counter(&"forge_core", 5)
	var drops_b := ds_b.resolve_drops(DropSystem.OUTCOME_VICTORY, pool_b, fired)

	# (a) Identical drop lists — same part_ids in the same order.
	assert_eq(_ids(drops_a), _ids(drops_b), "same seed + same state → identical drop list (no shared global RNG)")

	# (b) Identical post-resolution state on BOTH maps (catches a shared static map in either).
	assert_eq(ds_a.get_prototype_pity_credit(&"delta_core"), ds_b.get_prototype_pity_credit(&"delta_core"),
		"delta_core credit reproduces across instances")
	assert_eq(ds_a.get_break_pity_counter(&"forge_core"), ds_b.get_break_pity_counter(&"forge_core"),
		"forge_core counter reproduces across instances")

	# (c) Each map's post-state is CONSISTENT with its part's drop outcome:
	# delta_core → 0 if dropped else 42+3=45; forge_core → 0 if dropped else 5+1=6.
	var delta_dropped: bool = _ids(drops_a).has(&"delta_core")
	var forge_dropped: bool = _ids(drops_a).has(&"forge_core")
	assert_eq(ds_a.get_prototype_pity_credit(&"delta_core"), 0 if delta_dropped else 45,
		"delta_core credit: reset on drop, else += c (3)")
	assert_eq(ds_a.get_break_pity_counter(&"forge_core"), 0 if forge_dropped else 6,
		"forge_core counter: reset on drop, else += 1")


# --- AC-DS-02: DEFEAT/FLED → zero emits, both pity maps unchanged, RNG never drawn ---
func test_defeat_and_flee_change_nothing() -> void:
	var proto := _make_prototype(&"proto_arms")
	var forge := _make_boss(&"forge_core", &"core_broken")
	var pool: Array[PartDef] = [proto, forge]
	var fired := {&"zero_defeats": true, &"flawless": true, &"no_repairs_used": true, &"core_broken": true}

	for outcome in [2, 3]:  # 2 = DEFEAT, 3 = FLED — every non-VICTORY int is gated identically
		var rng := Rng.Const.new(0.01)  # would drop everything IF a draw ever happened
		var ds := _make_drop_system(rng)
		ds.set_prototype_pity_credit(&"proto_arms", 12)
		ds.set_break_pity_counter(&"forge_core", 5)

		var drops := ds.resolve_drops(outcome, pool, fired)

		assert_eq(drops.size(), 0, "non-victory outcome %d emits nothing" % outcome)
		assert_eq(rng.call_count, 0, "the victory gate returns before any draw (outcome %d)" % outcome)
		assert_eq(ds.get_prototype_pity_credit(&"proto_arms"), 12, "Prototype credit unchanged (outcome %d)" % outcome)
		assert_eq(ds.get_break_pity_counter(&"forge_core"), 5, "Boss counter unchanged (outcome %d)" % outcome)
