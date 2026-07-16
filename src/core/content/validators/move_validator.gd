## MoveValidator — Move-DB validation family for [ContentValidator] (ADR-0003 §5).
##
## Contains the full Move-DB check families extracted verbatim from
## [ContentValidator]: schema presence / targeting (Move-DB Story 004) and the
## cross-field authoring rules — energy band, REPAIR brake, status↔element,
## innate-rider ban (Move-DB Story 005).
## Composed by [ContentValidator]; never instantiated directly by game code.
##
## Call sequence (per validation run):
##   1. Set [member _errors], [member _warnings], [member _log] from
##      [ContentValidator] before calling [method validate_catalog].
##   2. [method validate_catalog] populates [member _errors] / [member _warnings]
##      in-place; [ContentValidator] merges them into its own accumulators.
extends "content_validator_base.gd"

# ---------------------------------------------------------------------------
# Move-DB Story 004 — Move schema family (AC-MDB-18/21, EC-MDB-04 authoring side)
# ---------------------------------------------------------------------------
# Runs only when a MoveCatalog is mounted (see validate() gate). Behaviours that
# demand SELF targeting; behaviours that require a power tier.

## Behaviours whose effect always applies to the caster, so their `targeting`
## must be SELF (AC-MDB-21): REPAIR heals the user, UTILITY (Vent) cools the user.
## DAMAGE / STATUS / SCAN act on an ENEMY and are unconstrained here.
const SELF_TARGET_BEHAVIORS: Array[int] = [
	MoveDef.Behavior.REPAIR, MoveDef.Behavior.UTILITY,
]

# --- Story 005: cross-field authoring rules (GDD Rule 3/5/7) ---

## AC-MDB-14: the `energy_cost` band a DAMAGE move must fall in, keyed by its
## PowerTier → `[min, max]` inclusive (GDD Rule 3). BASIC is the free Basic Attack
## (cost 0) and is intentionally absent — it is exempt from the band. Non-DAMAGE
## behaviours and an unset (0) tier are not keyed here and skip the check.
const ENERGY_BANDS: Dictionary = {
	MoveDef.PowerTier.LIGHT: [5, 8],
	MoveDef.PowerTier.STANDARD: [12, 18],
	MoveDef.PowerTier.HEAVY: [22, 30],
	MoveDef.PowerTier.SIGNATURE: [32, 40],
}

## AC-MDB-15: a REPAIR move must cost STRICTLY MORE than one turn's passive energy
## regen, or healing is free and stalls the match (the anti-stall brake, Rule 7 /
## TBC AC-TBC-38). `energy_cost <= BASE_ENERGY_REGEN` is illegal.
##
## FORWARD WORK: `BASE_ENERGY_REGEN` is a TBC balance constant not yet in code.
## Pinned here to the GDD value; source it from the TBC `BalanceConfig` field once
## the TBC epic ships (single source of truth), then delete this local const.
const BASE_ENERGY_REGEN := 10

## AC-MDB-16: the status a STATUS move applies is fixed by its element (Rule 5 /
## TBC Rule 11) — `status_proc.status_id` must equal this element's entry. A STATUS
## move with an unset/reserved element (not keyed here) skips the match; its
## element is the enum family's concern, not this cross-field rule's.
const STATUS_BY_ELEMENT: Dictionary = {
	PartDef.Element.VOLT: &"shock",
	PartDef.Element.THERMAL: &"burn",
	PartDef.Element.KINETIC: &"stagger",
}

## The `status_proc` sub-key carrying the applied status identity (Rule 5).
const STATUS_ID_KEY := &"status_id"


## Validate every entry in the mounted Move catalog. Mirrors
## [method _validate_part_catalog] — a null entry is fatal, each real entry is
## dispatched through [method _validate_move].
func validate_catalog(catalog: MoveCatalog) -> void:
	for move in catalog.entries:
		_validate_move(move)


## Per-move dispatch (Story 004 schema family + Story 005 authoring rules). A null
## entry is fatal and short-circuits — a null can't be field-checked.
func _validate_move(move: MoveDef) -> void:
	if move == null:
		_error(&"content_null_entry", {"db": &"move"})
		return
	# Story 004 — schema shape.
	_check_move_required_fields(move)
	_check_damage_power_tier(move)
	_check_move_targeting(move)
	# Story 005 — cross-field authoring rules.
	_check_move_energy_band(move)
	_check_move_repair_brake(move)
	_check_move_status_element(move)
	_check_move_innate_rider(move)


## AC-MDB-18: the always-required identity/schema fields, plus the DAMAGE-only
## `damage_type` + `element`. `power_tier` is DAMAGE-required too but has its own
## dedicated code (see [method _check_damage_power_tier]). `energy_cost` is NOT
## checked here — 0 is a legitimate cost (a Basic Attack is free), so it has no
## "missing" sentinel. Every finding names the move `id` (AC requirement).
func _check_move_required_fields(move: MoveDef) -> void:
	if move.id == &"":
		_error(&"content_move_missing_field", {"id": move.id, "field": &"id", "display_name": move.display_name})
	if move.display_name == "":
		_error(&"content_move_missing_field", {"id": move.id, "field": &"display_name"})
	if int(move.behavior) == 0:
		_error(&"content_move_missing_field", {"id": move.id, "field": &"behavior"})
	if int(move.targeting) == 0:
		_error(&"content_move_missing_field", {"id": move.id, "field": &"targeting"})
	if move.behavior == MoveDef.Behavior.DAMAGE:
		if int(move.damage_type) == 0:
			_error(&"content_move_missing_field", {"id": move.id, "field": &"damage_type"})
		if int(move.element) == 0:
			_error(&"content_move_missing_field", {"id": move.id, "field": &"element"})


## EC-MDB-04 (authoring side): a DAMAGE move must declare a real `power_tier` —
## the 0 sentinel is a missing tier. (TBC's runtime STANDARD fallback is a
## separate, resolution-time concern; content authoring must be explicit.)
func _check_damage_power_tier(move: MoveDef) -> void:
	if move.behavior == MoveDef.Behavior.DAMAGE and int(move.power_tier) == 0:
		_error(&"content_damage_move_missing_power_tier", {"id": move.id})


## AC-MDB-21: a REPAIR or UTILITY(Vent) move must target SELF. The `targeting != 0`
## guard skips the unset sentinel — that is already the required-field check's
## job (no double-flagging). A REPAIR/UTILITY that explicitly targets ENEMY errors.
func _check_move_targeting(move: MoveDef) -> void:
	if not SELF_TARGET_BEHAVIORS.has(int(move.behavior)):
		return
	if int(move.targeting) != 0 and move.targeting != MoveDef.Targeting.SELF:
		_error(&"content_move_bad_targeting",
			{"id": move.id, "behavior": move.behavior, "targeting": move.targeting})


## AC-MDB-14 (Story 005): a DAMAGE move's `energy_cost` must fall in its PowerTier
## band (Rule 3). BASIC (the free Basic Attack) and an unset tier are not keyed in
## [constant ENERGY_BANDS] and are exempt — a missing tier is Story 004's error.
func _check_move_energy_band(move: MoveDef) -> void:
	if move.behavior != MoveDef.Behavior.DAMAGE:
		return
	if not ENERGY_BANDS.has(move.power_tier):
		return
	var band: Array = ENERGY_BANDS[move.power_tier]
	if move.energy_cost < int(band[0]) or move.energy_cost > int(band[1]):
		_error(&"content_move_energy_band",
			{"id": move.id, "power_tier": move.power_tier, "energy_cost": move.energy_cost,
			"min": band[0], "max": band[1]})


## AC-MDB-15 (Story 005): a REPAIR move must cost more than [constant
## BASE_ENERGY_REGEN] — the anti-stall brake (Rule 7). `<=` regen is free healing.
func _check_move_repair_brake(move: MoveDef) -> void:
	if move.behavior != MoveDef.Behavior.REPAIR:
		return
	if move.energy_cost <= BASE_ENERGY_REGEN:
		_error(&"content_move_repair_brake",
			{"id": move.id, "energy_cost": move.energy_cost, "base_regen": BASE_ENERGY_REGEN})


## AC-MDB-16 (Story 005): a STATUS move's `status_proc.status_id` must be the
## status fixed by its `element` (Rule 5). An empty `status_proc` reads status_id
## as `&""`, which never matches — so this same check also enforces AC-4's "a
## STATUS move REQUIRES a status_proc" (a missing rider IS a mismatch: it can't
## carry the element's status). An unset/reserved element is not keyed in
## [constant STATUS_BY_ELEMENT] and is skipped (an enum-family concern).
func _check_move_status_element(move: MoveDef) -> void:
	if move.behavior != MoveDef.Behavior.STATUS:
		return
	var expected: StringName = STATUS_BY_ELEMENT.get(move.element, &"")
	if expected == &"":
		return
	var status_id: StringName = move.status_proc.get(STATUS_ID_KEY, &"")
	if status_id != expected:
		_error(&"content_move_status_element_mismatch",
			{"id": move.id, "element": move.element, "status_id": status_id, "expected": expected})


## TR-mdb-009 (Story 005): a DAMAGE move must NOT carry an innate `status_proc` —
## damage riders come only via passives (TBC Rule 13), never baked into the move.
## STATUS is the one behaviour that owns a `status_proc`; every other behaviour
## leaves it empty (a stray proc on non-DAMAGE is silently harmless, but the
## DAMAGE case is the authored-content trap this guards).
func _check_move_innate_rider(move: MoveDef) -> void:
	if move.behavior == MoveDef.Behavior.DAMAGE and not move.status_proc.is_empty():
		_error(&"content_move_innate_rider", {"id": move.id})
