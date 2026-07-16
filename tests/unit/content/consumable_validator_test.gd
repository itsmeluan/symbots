## Consumable-DB Story 007 — ContentValidator Consumable schema + economy + coherence.
##
## Covers AC-CD-17 (schema shape + effect_params key/type + unknown effect_type),
## AC-CD-18 (strict buy>sell economy invariant + ADVISORY context/target coherence +
## effect-family roster coverage). Per ADR-0003 every family pairs a CLEAN fixture
## (passes) with a deliberately-CORRUPTED one (must fail), proving the validator
## discriminates. Diagnostics asserted on the injected spy LogSink. GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/passive_database/spy_log_sink.gd")

var _spy


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

func _restorative(id: StringName, effect: ConsumableDef.EffectType, amount: int) -> ConsumableDef:
	var cd := ConsumableDef.new()
	cd.consumable_id = id
	cd.display_name  = "Test %s" % id
	cd.rarity        = ConsumableDef.Rarity.COMMON
	cd.effect_type   = effect
	cd.effect_params = {"amount": amount}
	cd.use_context   = ConsumableDef.UseContext.BOTH
	cd.target        = ConsumableDef.Target.LIVING_TEAM_MEMBER
	cd.max_stack     = 20
	cd.buy_price     = 12
	cd.sell_price    = 2
	return cd

func _beacon(id := &"salvage_beacon") -> ConsumableDef:
	var cd := ConsumableDef.new()
	cd.consumable_id = id
	cd.display_name  = "Salvage Beacon"
	cd.rarity        = ConsumableDef.Rarity.RARE
	cd.effect_type   = ConsumableDef.EffectType.BOOST_DROP
	cd.effect_params = {"multiplier": 2.0}
	cd.use_context   = ConsumableDef.UseContext.BATTLE
	cd.target        = ConsumableDef.Target.CURRENT_BATTLE
	cd.max_stack     = 10
	cd.buy_price     = 48
	cd.sell_price    = 10
	return cd

func _jammer(id := &"signal_jammer") -> ConsumableDef:
	var cd := ConsumableDef.new()
	cd.consumable_id = id
	cd.display_name  = "Signal Jammer"
	cd.rarity        = ConsumableDef.Rarity.RARE
	cd.effect_type   = ConsumableDef.EffectType.MODIFY_ENCOUNTER_RATE
	cd.effect_params = {"rate_multiplier": 0.1, "duration_steps": 20}
	cd.use_context   = ConsumableDef.UseContext.WORLD
	cd.target        = ConsumableDef.Target.OVERWORLD
	cd.max_stack     = 10
	cd.buy_price     = 45
	cd.sell_price    = 10
	return cd

## A full clean roster covering all 5 effect families (so the coverage advisory is inert).
func _clean_roster() -> Array[ConsumableDef]:
	var roster: Array[ConsumableDef] = [
		_restorative(&"weld_patch", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25),
		_restorative(&"coolant_flush", ConsumableDef.EffectType.REDUCE_HEAT, 50),
		_restorative(&"power_cell", ConsumableDef.EffectType.RESTORE_ENERGY, 25),
		_beacon(),
		_jammer(),
	]
	return roster

func _run(consumables: Array[ConsumableDef]) -> Dictionary:
	var catalog := ConsumableCatalog.new()
	catalog.entries = consumables
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()  # empty but present — the validator always checks Parts
	catalogs.consumables = catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)

func _one(consumable: ConsumableDef) -> Dictionary:
	# Pad with the clean roster so the coverage advisory never fires — isolates the
	# corruption under test from the roster warning.
	var roster := _clean_roster()
	roster.append(consumable)
	return _run(roster)

func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false

func _warned(code: StringName) -> bool:
	for w in _spy.warns:
		if w["code"] == code:
			return true
	return false


# ---------------------------------------------------------------------------
# Clean roster — passes with zero errors AND zero warnings
# ---------------------------------------------------------------------------

func test_clean_roster_passes_no_errors_no_warnings() -> void:
	var r := _run(_clean_roster())
	assert_true(r["ok"], "a well-formed roster validates")
	assert_eq((r["errors"] as Array).size(), 0, "no errors")
	assert_eq((r["warnings"] as Array).size(), 0, "no roster/coherence warnings on the designed roster")


# ---------------------------------------------------------------------------
# AC-CD-17 — schema shape (missing fields, sentinels, max_stack)
# ---------------------------------------------------------------------------

func test_missing_id_flagged() -> void:
	var bad := _restorative(&"", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	_run([bad])
	assert_true(_logged(&"content_consumable_missing_field"), "empty consumable_id is missing")

func test_sentinel_rarity_flagged() -> void:
	var bad := _restorative(&"no_rarity", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	bad.rarity = 0  # INVALID sentinel
	_run([bad])
	assert_true(_logged(&"content_consumable_missing_field"))

func test_zero_max_stack_flagged() -> void:
	var bad := _restorative(&"unstockable", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	bad.max_stack = 0
	_run([bad])
	assert_true(_logged(&"content_consumable_missing_field"), "a 0-stack item is unstockable")


# ---------------------------------------------------------------------------
# AC-CD-17 — effect_params key/type + unknown effect_type
# ---------------------------------------------------------------------------

func test_missing_required_param_key_flagged() -> void:
	var bad := _restorative(&"no_amount", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	bad.effect_params = {}  # RESTORE_STRUCTURE needs "amount"
	_run([bad])
	assert_true(_logged(&"content_consumable_effect_params_malformed"))

func test_wrong_typed_param_flagged() -> void:
	var bad := _restorative(&"float_amount", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	bad.effect_params = {"amount": 2.5}  # amount must be int
	_run([bad])
	assert_true(_logged(&"content_consumable_effect_params_malformed"))

func test_unknown_extra_param_flagged() -> void:
	var bad := _restorative(&"extra_key", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	bad.effect_params = {"amount": 25, "bonus": 1}  # "bonus" is not in the RESTORE spec
	_run([bad])
	assert_true(_logged(&"content_consumable_effect_params_malformed"))

func test_unknown_effect_type_flagged() -> void:
	var bad := _restorative(&"bogus_effect", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	bad.effect_type = 99  # out-of-range enum value (corrupted .tres)
	_run([bad])
	assert_true(_logged(&"content_consumable_unknown_effect_type"))


# ---------------------------------------------------------------------------
# AC-CD-18 — economy invariant (strict buy > sell)
# ---------------------------------------------------------------------------

func test_buy_equals_sell_is_invalid() -> void:
	# The discriminating fixture: buy == sell is an infinite-Scrap exploit. A `buy >= sell`
	# impl wrongly passes this.
	var bad := _restorative(&"break_even", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	bad.buy_price = 10
	bad.sell_price = 10
	_run([bad])
	assert_true(_logged(&"content_consumable_price_invariant"))

func test_sell_above_buy_is_invalid() -> void:
	var bad := _restorative(&"reverse", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	bad.buy_price = 5
	bad.sell_price = 20
	_run([bad])
	assert_true(_logged(&"content_consumable_price_invariant"))

func test_negative_sell_is_invalid() -> void:
	var bad := _restorative(&"neg_sell", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	bad.sell_price = -1
	_run([bad])
	assert_true(_logged(&"content_consumable_price_invariant"))

func test_valid_strict_price_passes() -> void:
	var good := _restorative(&"priced_ok", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	good.buy_price = 12
	good.sell_price = 2
	_one(good)
	assert_false(_logged(&"content_consumable_price_invariant"), "buy > sell is valid")


# ---------------------------------------------------------------------------
# AC-CD-18 — coherence advisory (WARN, never fatal)
# ---------------------------------------------------------------------------

func test_incoherent_target_warns_not_fatal() -> void:
	# A restorative that targets the OVERWORLD instead of a living team member is a
	# design smell — advisory only, never an error.
	var odd := _restorative(&"weird_heal", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	odd.target = ConsumableDef.Target.OVERWORLD
	var r := _run([odd])
	assert_true(_warned(&"content_consumable_context_target_incoherent"))
	assert_false(_logged(&"content_consumable_context_target_incoherent"), "coherence is advisory, not fatal")
	# The odd target is the ONLY issue — the price/schema are fine, so it must still validate.
	assert_true(r["ok"], "an advisory-only roster still passes")

func test_incoherent_beacon_context_warns() -> void:
	var odd := _beacon(&"world_beacon")
	odd.use_context = ConsumableDef.UseContext.WORLD  # Beacons are battle-only
	_run([odd])
	assert_true(_warned(&"content_consumable_context_target_incoherent"))


# ---------------------------------------------------------------------------
# AC-CD-18 — effect-family roster coverage advisory
# ---------------------------------------------------------------------------

func test_missing_effect_family_warns() -> void:
	# A roster with no MODIFY_ENCOUNTER_RATE item leaves that family unrepresented.
	var partial: Array[ConsumableDef] = [
		_restorative(&"weld_patch", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25),
		_restorative(&"coolant_flush", ConsumableDef.EffectType.REDUCE_HEAT, 50),
		_restorative(&"power_cell", ConsumableDef.EffectType.RESTORE_ENERGY, 25),
		_beacon(),
	]
	var r := _run(partial)
	assert_true(_warned(&"content_consumable_roster"), "the unrepresented family is flagged")
	assert_true(r["ok"], "coverage is advisory — the roster still validates")


# ---------------------------------------------------------------------------
# Catalog-level — duplicate id is fatal
# ---------------------------------------------------------------------------

func test_duplicate_consumable_id_is_fatal() -> void:
	var a := _restorative(&"dup", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25)
	var b := _restorative(&"dup", ConsumableDef.EffectType.REDUCE_HEAT, 50)
	var r := _run([a, b])
	assert_true(_logged(&"content_duplicate_id"))
	assert_false(r["ok"])

func test_null_entry_is_fatal() -> void:
	var roster: Array[ConsumableDef] = [_beacon(), null]
	var r := _run(roster)
	assert_true(_logged(&"content_null_entry"))
	assert_false(r["ok"])
