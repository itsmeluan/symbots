## ConsumableValidator — Consumable-DB validation family for [ContentValidator]
## (ADR-0003 §5).
##
## Contains the full Consumable-DB check family extracted verbatim from
## [ContentValidator]: schema presence, effect-params key/type correctness, price
## invariant, coherence advisory, and effect-type coverage advisory
## (Consumable-DB Story 007).
## Composed by [ContentValidator]; never instantiated directly by game code.
##
## Call sequence (per validation run):
##   1. Set [member _errors], [member _warnings], [member _log] from
##      [ContentValidator] before calling [method validate_catalog].
##   2. [method validate_catalog] populates [member _errors] / [member _warnings]
##      in-place; [ContentValidator] merges them into its own accumulators.
extends "content_validator_base.gd"

# ---------------------------------------------------------------------------
# Consumable DB family (Consumable-DB Story 007)
# ---------------------------------------------------------------------------

## The exact `effect_params` key set + value type each `EffectType` must carry
## (Consumable-DB AC-CD-17). Keys are `String` (matching the untyped `effect_params`
## Dictionary the .tres authors — same convention as the Part-DB entry dicts). The
## value is the expected Variant.Type. A def whose params miss a required key, carry
## an unknown extra key, or store a key at the wrong type is malformed.
const CONSUMABLE_PARAM_SPEC: Dictionary = {
	ConsumableDef.EffectType.RESTORE_STRUCTURE: {"amount": TYPE_INT},
	ConsumableDef.EffectType.REDUCE_HEAT: {"amount": TYPE_INT},
	ConsumableDef.EffectType.RESTORE_ENERGY: {"amount": TYPE_INT},
	ConsumableDef.EffectType.BOOST_DROP: {"multiplier": TYPE_FLOAT},
	ConsumableDef.EffectType.MODIFY_ENCOUNTER_RATE: {"rate_multiplier": TYPE_FLOAT, "duration_steps": TYPE_INT},
}

## The coherent `(use_context, target)` pairing each `EffectType` is designed for
## (AC-CD-18, ADVISORY). A restorative acts on a living team member usable in either
## context; a Beacon is battle-only against the current battle; an encounter modifier
## is world-only against the overworld. A def that diverges is authorable but flagged
## as a design smell (a WORLD-context heal, a battle-target Lure) — a warning, never fatal.
const CONSUMABLE_COHERENCE: Dictionary = {
	ConsumableDef.EffectType.RESTORE_STRUCTURE: {"context": ConsumableDef.UseContext.BOTH, "target": ConsumableDef.Target.LIVING_TEAM_MEMBER},
	ConsumableDef.EffectType.REDUCE_HEAT: {"context": ConsumableDef.UseContext.BOTH, "target": ConsumableDef.Target.LIVING_TEAM_MEMBER},
	ConsumableDef.EffectType.RESTORE_ENERGY: {"context": ConsumableDef.UseContext.BOTH, "target": ConsumableDef.Target.LIVING_TEAM_MEMBER},
	ConsumableDef.EffectType.BOOST_DROP: {"context": ConsumableDef.UseContext.BATTLE, "target": ConsumableDef.Target.CURRENT_BATTLE},
	ConsumableDef.EffectType.MODIFY_ENCOUNTER_RATE: {"context": ConsumableDef.UseContext.WORLD, "target": ConsumableDef.Target.OVERWORLD},
}


## Catalog-level dispatch (mirrors [method _validate_passive_catalog]): per-entry
## schema/price/params validation, plus catalog-wide duplicate-id + effect-type coverage.
func validate_catalog(catalog: ConsumableCatalog) -> void:
	var seen_ids := {}
	for consumable in catalog.entries:
		_validate_consumable(consumable)
		if consumable != null and consumable.consumable_id != &"":
			if seen_ids.has(consumable.consumable_id):
				_error(&"content_duplicate_id", {"db": &"consumable", "id": consumable.consumable_id})
			else:
				seen_ids[consumable.consumable_id] = true
	_check_consumable_effect_coverage(catalog)


## Per-consumable dispatch. A null entry is fatal and short-circuits — a null can't be
## field-checked (mirrors [method _validate_passive]).
func _validate_consumable(consumable: ConsumableDef) -> void:
	if consumable == null:
		_error(&"content_null_entry", {"db": &"consumable"})
		return
	_check_consumable_required_fields(consumable)
	_check_consumable_effect_params(consumable)
	_check_consumable_price_invariant(consumable)
	_check_consumable_coherence(consumable)


## AC-CD-17 (schema half): the always-required identity + classification fields. Enum
## fields at the 0 INVALID sentinel are "missing" (an unset .tres slot); `max_stack`
## must be at least 1 (a 0-stack item is unstockable). Each finding names the id.
func _check_consumable_required_fields(consumable: ConsumableDef) -> void:
	if consumable.consumable_id == &"":
		_error(&"content_consumable_missing_field", {"id": consumable.consumable_id, "field": &"consumable_id", "display_name": consumable.display_name})
	if consumable.display_name == "":
		_error(&"content_consumable_missing_field", {"id": consumable.consumable_id, "field": &"display_name"})
	if int(consumable.rarity) == 0:
		_error(&"content_consumable_missing_field", {"id": consumable.consumable_id, "field": &"rarity"})
	if int(consumable.effect_type) == 0:
		_error(&"content_consumable_missing_field", {"id": consumable.consumable_id, "field": &"effect_type"})
	if int(consumable.use_context) == 0:
		_error(&"content_consumable_missing_field", {"id": consumable.consumable_id, "field": &"use_context"})
	if int(consumable.target) == 0:
		_error(&"content_consumable_missing_field", {"id": consumable.consumable_id, "field": &"target"})
	if consumable.max_stack < 1:
		_error(&"content_consumable_missing_field", {"id": consumable.consumable_id, "field": &"max_stack"})


## AC-CD-17 (params half): `effect_params` must carry EXACTLY its `effect_type`'s key
## set at the correct type ([constant CONSUMABLE_PARAM_SPEC]) — a missing required key,
## an unknown extra key, or a wrong-typed value is malformed. An `effect_type` not in
## the spec (and not the 0 sentinel — the schema check owns that) is an unknown type.
## Skips a def at the 0 sentinel (missing-field check owns it). One error per bad key.
func _check_consumable_effect_params(consumable: ConsumableDef) -> void:
	if int(consumable.effect_type) == 0:
		return
	if not CONSUMABLE_PARAM_SPEC.has(consumable.effect_type):
		_error(&"content_consumable_unknown_effect_type", {"id": consumable.consumable_id, "effect_type": consumable.effect_type})
		return
	var spec: Dictionary = CONSUMABLE_PARAM_SPEC[consumable.effect_type]
	for key in spec:
		if not consumable.effect_params.has(key):
			_error(&"content_consumable_effect_params_malformed", {"id": consumable.consumable_id, "field": key, "issue": &"missing"})
		elif typeof(consumable.effect_params[key]) != spec[key]:
			_error(&"content_consumable_effect_params_malformed", {"id": consumable.consumable_id, "field": key, "issue": &"wrong_type"})
	for key in consumable.effect_params.keys():
		if not spec.has(key):
			_error(&"content_consumable_effect_params_malformed", {"id": consumable.consumable_id, "field": key, "issue": &"unknown"})


## AC-CD-18 (economy): the buy price must STRICTLY exceed the sell price — a store that
## buys back for what it sells (or more) is an infinite-Scrap exploit. `buy == sell` is
## the discriminating fixture (a `buy >= sell` impl wrongly passes it). Sell price must
## also be non-negative. Names the id and both prices.
func _check_consumable_price_invariant(consumable: ConsumableDef) -> void:
	if consumable.sell_price < 0:
		_error(&"content_consumable_price_invariant", {"id": consumable.consumable_id, "buy": consumable.buy_price, "sell": consumable.sell_price, "issue": &"negative_sell"})
	if consumable.buy_price <= consumable.sell_price:
		_error(&"content_consumable_price_invariant", {"id": consumable.consumable_id, "buy": consumable.buy_price, "sell": consumable.sell_price, "issue": &"buy_not_above_sell"})


## AC-CD-18 (coherence, ADVISORY): warn when an effect_type's authored `use_context` /
## `target` diverges from its designed pairing ([constant CONSUMABLE_COHERENCE]) — a
## design smell, never fatal. Skips an unknown/sentinel effect_type (owned above).
func _check_consumable_coherence(consumable: ConsumableDef) -> void:
	if not CONSUMABLE_COHERENCE.has(consumable.effect_type):
		return
	var expected: Dictionary = CONSUMABLE_COHERENCE[consumable.effect_type]
	if int(consumable.use_context) != 0 and consumable.use_context != expected["context"]:
		_warn(&"content_consumable_context_target_incoherent",
			{"id": consumable.consumable_id, "field": &"use_context", "expected": expected["context"], "actual": consumable.use_context})
	if int(consumable.target) != 0 and consumable.target != expected["target"]:
		_warn(&"content_consumable_context_target_incoherent",
			{"id": consumable.consumable_id, "field": &"target", "expected": expected["target"], "actual": consumable.target})


## Effect-type coverage advisory (ADVISORY): the MVP roster is designed to represent
## every `EffectType` family; warn per family with no representative consumable so a
## designer who removes the last item of a family is told. Inert on the full roster
## (all 5 families covered → 0 warnings). Non-brittle: no hard-coded id list.
func _check_consumable_effect_coverage(catalog: ConsumableCatalog) -> void:
	var present := {}
	for consumable in catalog.entries:
		if consumable != null and int(consumable.effect_type) != 0:
			present[consumable.effect_type] = true
	for effect_type in CONSUMABLE_PARAM_SPEC:
		if not present.has(effect_type):
			_warn(&"content_consumable_roster", {"effect_type": effect_type, "issue": &"family_unrepresented"})
