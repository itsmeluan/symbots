## PassiveValidator — Passive-DB validation family for [ContentValidator]
## (ADR-0003 §5).
##
## Contains the full Passive-DB check families extracted verbatim from
## [ContentValidator]: schema shape + Rule 3 legality matrix + Rule 4 stacking
## (Passive-DB Story 004); Rule 3a behavior_params key-set, STRUCTURAL non-negative
## rule, and Rule 6 Core doctrine (Passive-DB Story 005).
## Composed by [ContentValidator]; never instantiated directly by game code.
##
## Call sequence (per validation run):
##   1. Set [member _errors], [member _warnings], [member _log] from
##      [ContentValidator] before calling [method validate_catalog].
##   2. [method validate_catalog] populates [member _errors] / [member _warnings]
##      in-place; [ContentValidator] merges them into its own accumulators.
extends "content_validator_base.gd"

# ---------------------------------------------------------------------------
# Passive-DB Stories 004/005 — Passive schema + legality + authoring families
# ---------------------------------------------------------------------------
# The validator owns NO runtime executor — it rejects authoring errors only.

## GDD Rule 3 legality matrix (copied verbatim from the GDD's "Allowed trigger ×
## behavior combinations" table — NOT inferred): the exact set of legal
## `trigger_category` values each `behavior_class` may pair with. An author reading
## a `content_illegal_passive_pairing` error must see the same matrix the GDD
## documents. APPEND-ONLY alongside the enums.
const PASSIVE_LEGAL_TRIGGERS: Dictionary = {
	PassiveDef.BehaviorClass.STATUS_RIDER: [
		PassiveDef.TriggerCategory.ON_HIT,
	],
	PassiveDef.BehaviorClass.STAT_AURA: [
		PassiveDef.TriggerCategory.PERSISTENT,
	],
	PassiveDef.BehaviorClass.RESOURCE_EFFECT: [
		PassiveDef.TriggerCategory.ON_BATTLE_START,
		PassiveDef.TriggerCategory.ON_TURN_START,
		PassiveDef.TriggerCategory.ON_OVERHEAT,
	],
	PassiveDef.BehaviorClass.STRUCTURAL_EFFECT: [
		PassiveDef.TriggerCategory.ON_BATTLE_START,
		PassiveDef.TriggerCategory.ON_TURN_START,
		PassiveDef.TriggerCategory.ON_OVERHEAT,
	],
}

## GDD Rule 3a `behavior_params` schema — the EXACT key set each `behavior_class`
## must carry (no more, no less). String keys per the untyped-entry-dict convention
## (`_check_boss_break_condition`); `StringName` is reserved for the *values*
## (status_id / stat) and for error codes. The validator flags a missing OR an
## unknown key against this table (Story 005).
const PASSIVE_PARAM_KEYS: Dictionary = {
	PassiveDef.BehaviorClass.STATUS_RIDER: ["status_id", "duration"],
	PassiveDef.BehaviorClass.STAT_AURA: ["stat", "delta"],
	PassiveDef.BehaviorClass.RESOURCE_EFFECT: ["resource", "amount"],
	PassiveDef.BehaviorClass.STRUCTURAL_EFFECT: ["target", "amount"],
}

## GDD Rule 6 constraint 2 — the ONLY `trigger_category` values a `CORE_TRAIT`
## passive may use. `ON_HIT` and `ON_TURN_START` are deliberately excluded (status
## riders are Weapon/Arms territory; Core identity fires at battle boundaries or
## on overheat, or persists). Drives `content_core_illegal_trigger` (Story 005).
const CORE_TRIGGER_WHITELIST: Array[int] = [
	PassiveDef.TriggerCategory.ON_BATTLE_START,
	PassiveDef.TriggerCategory.ON_OVERHEAT,
	PassiveDef.TriggerCategory.PERSISTENT,
]

## The `behavior_params` key holding a STRUCTURAL_EFFECT's signed magnitude (Rule
## 3a) — read for the non-negative rule (Story 005 / EC-PDB-08 authoring side).
const PASSIVE_STRUCTURAL_AMOUNT_KEY := "amount"

## The `behavior_params` key naming a STRUCTURAL_EFFECT's target (Rule 3a); surfaced
## in the negative-structural error so the author knows which target was offending.
const PASSIVE_STRUCTURAL_TARGET_KEY := "target"


## Validate every entry in the mounted Passive catalog. Mirrors
## [method _validate_move_catalog]: per-entry dispatch, plus one catalog-level
## cross-entry pass (the Core duplicate-combo uniqueness check, AC-PDB-14).
func validate_catalog(catalog: PassiveCatalog) -> void:
	for passive in catalog.entries:
		_validate_passive(passive)
	_check_passive_core_duplicate_combo(catalog)


## Per-passive dispatch (Story 004 schema/legality/stacking + Story 005 authoring
## rules). A null entry is fatal and short-circuits — a null can't be field-checked.
func _validate_passive(passive: PassiveDef) -> void:
	if passive == null:
		_error(&"content_null_entry", {"db": &"passive"})
		return
	# Story 004 — schema shape, Rule 3 legality, Rule 4 stacking.
	_check_passive_required_fields(passive)
	_check_passive_legality(passive)
	_check_passive_stacking(passive)
	# Story 005 — Rule 3a params, STRUCTURAL non-negative, Rule 6 Core trigger.
	_check_passive_params(passive)
	_check_passive_structural_nonneg(passive)
	_check_passive_core_trigger(passive)


## AC-PDB-15 (schema half): the always-required identity + classification fields.
## Enum fields at the 0 INVALID sentinel are "missing" (an unset .tres slot). `scope`
## is required ONLY for `ON_HIT` (it is the null-equivalent 0 for every other
## trigger, so a non-ON_HIT passive with scope==0 is correct, not missing). Every
## finding names the passive `id`.
func _check_passive_required_fields(passive: PassiveDef) -> void:
	if passive.id == &"":
		_error(&"content_passive_missing_field", {"id": passive.id, "field": &"id", "display_name": passive.display_name})
	if passive.display_name == "":
		_error(&"content_passive_missing_field", {"id": passive.id, "field": &"display_name"})
	if int(passive.behavior_class) == 0:
		_error(&"content_passive_missing_field", {"id": passive.id, "field": &"behavior_class"})
	if int(passive.trigger_category) == 0:
		_error(&"content_passive_missing_field", {"id": passive.id, "field": &"trigger_category"})
	if int(passive.stacking_policy) == 0:
		_error(&"content_passive_missing_field", {"id": passive.id, "field": &"stacking_policy"})
	if int(passive.passive_class) == 0:
		_error(&"content_passive_missing_field", {"id": passive.id, "field": &"passive_class"})
	# scope is mandatory only on ON_HIT (the move-slot filter); required-but-unset there.
	if passive.trigger_category == PassiveDef.TriggerCategory.ON_HIT and int(passive.scope) == 0:
		_error(&"content_passive_missing_field", {"id": passive.id, "field": &"scope"})


## AC-PDB-15: the `trigger_category × behavior_class` pairing must be legal per the
## Rule 3 matrix ([constant PASSIVE_LEGAL_TRIGGERS]). A def sitting at an INVALID
## enum sentinel is malformed — [method _check_passive_required_fields] owns that
## error; this check skips it so it is not double-flagged as an illegal pairing
## (AC-1 edge case). The error names the id AND the offending pairing.
func _check_passive_legality(passive: PassiveDef) -> void:
	if int(passive.behavior_class) == 0 or int(passive.trigger_category) == 0:
		return
	var legal: Array = PASSIVE_LEGAL_TRIGGERS.get(passive.behavior_class, [])
	if not legal.has(int(passive.trigger_category)):
		_error(&"content_illegal_passive_pairing",
			{"id": passive.id, "trigger": passive.trigger_category, "behavior": passive.behavior_class})


## TR-pdb-004: the authored `stacking_policy` must match the `behavior_class`
## default (Story 003's canonical table, via [method PassiveDef.default_stacking_policy]).
## Skips a def with an INVALID behavior_class (no default to compare) or an unset
## stacking_policy (the missing-field check owns that). Names the id and expected policy.
func _check_passive_stacking(passive: PassiveDef) -> void:
	if int(passive.behavior_class) == 0 or int(passive.stacking_policy) == 0:
		return
	var expected := PassiveDef.default_stacking_policy(passive.behavior_class)
	if passive.stacking_policy != expected:
		_error(&"content_passive_stacking_mismatch",
			{"id": passive.id, "expected": expected, "actual": passive.stacking_policy})


## AC-PDB-16 (params half): `behavior_params` must carry EXACTLY its
## `behavior_class`'s key set (Rule 3a) — a missing required key OR an unknown extra
## key is an error, each naming the offending field. Skips an INVALID behavior_class
## (its key set is undefined — the schema check owns that). One error per bad field.
func _check_passive_params(passive: PassiveDef) -> void:
	if int(passive.behavior_class) == 0:
		return
	var required: Array = PASSIVE_PARAM_KEYS.get(passive.behavior_class, [])
	if required.is_empty():
		return
	for key in required:
		if not passive.behavior_params.has(key):
			_error(&"content_passive_params_mismatch", {"id": passive.id, "field": key})
	for key in passive.behavior_params.keys():
		if not required.has(key):
			_error(&"content_passive_params_mismatch", {"id": passive.id, "field": key})


## AC-PDB-16 (structural half) / TR-pdb-007 (EC-PDB-08 authoring side): a
## STRUCTURAL_EFFECT `amount` must be non-negative for EITHER target — persistent
## structure debuffs go through a negative STAT_AURA, never here. A missing `amount`
## is the params check's concern; this only fires when the key is present and < 0.
func _check_passive_structural_nonneg(passive: PassiveDef) -> void:
	if passive.behavior_class != PassiveDef.BehaviorClass.STRUCTURAL_EFFECT:
		return
	if not passive.behavior_params.has(PASSIVE_STRUCTURAL_AMOUNT_KEY):
		return
	if int(passive.behavior_params[PASSIVE_STRUCTURAL_AMOUNT_KEY]) < 0:
		_error(&"content_passive_negative_structural",
			{"id": passive.id, "target": passive.behavior_params.get(PASSIVE_STRUCTURAL_TARGET_KEY, &"")})


## AC-PDB-12 / TR-pdb-008: a `CORE_TRAIT` passive may only use a whitelisted trigger
## (Rule 6 constraint 2 — [constant CORE_TRIGGER_WHITELIST]). `passive_class` is the
## authoring axis, so this gates only on it; a non-Core passive with `ON_HIT` is NOT
## flagged here (that is a legal STATUS_RIDER pairing). Skips an unset trigger (the
## missing-field check owns it). Names the passive id and the illegal trigger.
func _check_passive_core_trigger(passive: PassiveDef) -> void:
	if passive.passive_class != PassiveDef.PassiveClass.CORE_TRAIT:
		return
	if int(passive.trigger_category) == 0:
		return
	if not CORE_TRIGGER_WHITELIST.has(int(passive.trigger_category)):
		_error(&"content_core_illegal_trigger",
			{"id": passive.id, "trigger": passive.trigger_category})


## AC-PDB-14: two `CORE_TRAIT` passives sharing an identical `trigger_category` +
## `behavior_class` combo are duplicates (Boss-grade Cores must be mechanically
## distinct, Rule 6). Inert until OQ-PDB-1 authors Core content — a catalog with
## zero CORE_TRAIT entries produces no error. Only real (non-sentinel) combos are
## compared. Reports the FIRST colliding pair, naming both ids and the shared combo.
func _check_passive_core_duplicate_combo(catalog: PassiveCatalog) -> void:
	var seen := {}
	for passive in catalog.entries:
		if passive == null:
			continue
		if passive.passive_class != PassiveDef.PassiveClass.CORE_TRAIT:
			continue
		if int(passive.trigger_category) == 0 or int(passive.behavior_class) == 0:
			continue
		var combo := "%d:%d" % [int(passive.trigger_category), int(passive.behavior_class)]
		if seen.has(combo):
			_error(&"content_core_duplicate_combo",
				{"id_a": seen[combo], "id_b": passive.id,
				"trigger": passive.trigger_category, "behavior": passive.behavior_class})
		else:
			seen[combo] = passive.id
