## Passive-DB Story 004 — ContentValidator Passive schema + legality + stacking.
##
## Covers the Story 004 ACs (GDD Rule 3 legality matrix + Rule 4 + AC-PDB-15 +
## TR-pdb-004). Per ADR-0003 every family pairs a CLEAN fixture (passes) with a
## deliberately-CORRUPTED one (must fail), proving the validator discriminates.
## Diagnostics are asserted on the injected spy LogSink. Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/passive_database/spy_log_sink.gd")

var _spy


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

## A fully-valid STATUS_RIDER passive — the baseline most corruptions mutate from.
func _valid_rider(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = "Test %s" % id
	pd.trigger_category = PassiveDef.TriggerCategory.ON_HIT
	pd.behavior_class   = PassiveDef.BehaviorClass.STATUS_RIDER
	pd.scope            = PassiveDef.Scope.ANY_DAMAGE
	pd.stacking_policy  = PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER
	pd.passive_class    = PassiveDef.PassiveClass.STATUS_RIDER
	pd.behavior_params  = {"status_id": &"shock", "duration": 1}
	return pd


## A valid PERSISTENT STAT_AURA passive (a different legal Rule-3 pairing).
func _valid_aura(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = "Aura %s" % id
	pd.trigger_category = PassiveDef.TriggerCategory.PERSISTENT
	pd.behavior_class   = PassiveDef.BehaviorClass.STAT_AURA
	pd.scope            = 0  # null-equivalent for non-ON_HIT
	pd.stacking_policy  = PassiveDef.StackingPolicy.UNIQUE
	pd.passive_class    = PassiveDef.PassiveClass.UPGRADE_PASSIVE  # non-Core: isolates Story 004 from the Rule-6 Core checks
	pd.behavior_params  = {"stat": &"processing", "delta": 5}
	return pd


## A valid ON_OVERHEAT RESOURCE_EFFECT passive (STACKABLE default).
func _valid_resource(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = "Vent %s" % id
	pd.trigger_category = PassiveDef.TriggerCategory.ON_OVERHEAT
	pd.behavior_class   = PassiveDef.BehaviorClass.RESOURCE_EFFECT
	pd.scope            = 0
	pd.stacking_policy  = PassiveDef.StackingPolicy.STACKABLE
	pd.passive_class    = PassiveDef.PassiveClass.UPGRADE_PASSIVE
	pd.behavior_params  = {"resource": &"heat", "amount": -10}
	return pd


## A valid ON_BATTLE_START STRUCTURAL_EFFECT passive (UNIQUE default).
func _valid_structural(id: StringName) -> PassiveDef:
	var pd := PassiveDef.new()
	pd.id               = id
	pd.display_name     = "Bulwark %s" % id
	pd.trigger_category = PassiveDef.TriggerCategory.ON_BATTLE_START
	pd.behavior_class   = PassiveDef.BehaviorClass.STRUCTURAL_EFFECT
	pd.scope            = 0
	pd.stacking_policy  = PassiveDef.StackingPolicy.UNIQUE
	pd.passive_class    = PassiveDef.PassiveClass.UPGRADE_PASSIVE  # non-Core: isolates Story 004 from the Rule-6 Core checks
	pd.behavior_params  = {"target": &"current_structure", "amount": 20}
	return pd


## Run the validator over the given passives; stash the spy for diagnostic asserts.
func _run(passives: Array[PassiveDef]) -> Dictionary:
	var catalog := PassiveCatalog.new()
	catalog.entries = passives
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()  # empty but present — the validator always checks the Part catalog
	catalogs.passives = catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _one(passive: PassiveDef) -> Dictionary:
	var passives: Array[PassiveDef] = [passive]
	return _run(passives)


## True if the spy recorded an error with the given code.
func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


## Count of spy errors carrying the given code.
func _count(code: StringName) -> int:
	var n := 0
	for e in _spy.errors:
		if e["code"] == code:
			n += 1
	return n


## The detail dict of the first error with the given code (or {}).
func _detail(code: StringName) -> Dictionary:
	for e in _spy.errors:
		if e["code"] == code:
			return e["detail"]
	return {}


# ---------------------------------------------------------------------------
# Baseline: every legal Rule-3 pairing passes cleanly
# ---------------------------------------------------------------------------

## AC-2: one PassiveDef per legal pairing → zero legality errors across all.
func test_all_legal_pairings_validate_ok() -> void:
	var passives: Array[PassiveDef] = [
		_valid_rider(&"rider_on_hit"),
		_valid_aura(&"aura_persistent"),
		_valid_resource(&"resource_overheat"),
		_valid_structural(&"structural_battle_start"),
	]
	var r := _run(passives)
	assert_true(r["ok"], "all legal Rule-3 pairings validate ok==true")
	assert_eq(_spy.errors.size(), 0, "no diagnostics on an all-legal catalog")


## AC-2 (extra legal triggers): RESOURCE_EFFECT / STRUCTURAL_EFFECT also accept
## ON_TURN_START and ON_BATTLE_START — the full GDD matrix, not just the typical.
func test_resource_and_structural_accept_all_three_legal_triggers() -> void:
	var res_turn := _valid_resource(&"res_turn")
	res_turn.trigger_category = PassiveDef.TriggerCategory.ON_TURN_START
	var struct_turn := _valid_structural(&"struct_turn")
	struct_turn.trigger_category = PassiveDef.TriggerCategory.ON_TURN_START
	var struct_overheat := _valid_structural(&"struct_overheat")
	struct_overheat.trigger_category = PassiveDef.TriggerCategory.ON_OVERHEAT

	var r := _run([res_turn, struct_turn, struct_overheat] as Array[PassiveDef])
	assert_true(r["ok"], "ON_TURN_START / ON_OVERHEAT are legal for RESOURCE/STRUCTURAL")
	assert_false(_logged(&"content_illegal_passive_pairing"), "no legality error")


# ---------------------------------------------------------------------------
# AC-1 (AC-PDB-15): illegal trigger×behavior pairing rejected
# ---------------------------------------------------------------------------

func test_status_rider_at_battle_start_is_illegal_pairing() -> void:
	# Arrange — STATUS_RIDER may only fire ON_HIT (Rule 3).
	var bad := _valid_rider(&"bad_rider")
	bad.trigger_category = PassiveDef.TriggerCategory.ON_BATTLE_START

	# Act
	_one(bad)

	# Assert — exactly one legality error, naming id + pairing.
	assert_eq(_count(&"content_illegal_passive_pairing"), 1, "one legality error")
	var d := _detail(&"content_illegal_passive_pairing")
	assert_eq(d["id"], &"bad_rider", "error names the offending id")
	assert_eq(d["trigger"], PassiveDef.TriggerCategory.ON_BATTLE_START, "error carries the illegal trigger")
	assert_eq(d["behavior"], PassiveDef.BehaviorClass.STATUS_RIDER, "error carries the behavior")


func test_stat_aura_on_hit_is_illegal_pairing() -> void:
	# Arrange — STAT_AURA is PERSISTENT-only.
	var bad := _valid_aura(&"bad_aura")
	bad.trigger_category = PassiveDef.TriggerCategory.ON_HIT
	bad.scope = PassiveDef.Scope.ANY_DAMAGE  # avoid a spurious missing-scope error

	# Act
	_one(bad)

	# Assert
	assert_eq(_count(&"content_illegal_passive_pairing"), 1, "STAT_AURA + ON_HIT is illegal")
	assert_eq(_detail(&"content_illegal_passive_pairing")["id"], &"bad_aura", "names the id")


## Edge case: one legal + one illegal entry → only the illegal one errors.
func test_mixed_catalog_flags_only_the_illegal_entry() -> void:
	var good := _valid_rider(&"good_rider")
	var bad := _valid_aura(&"bad_aura")
	bad.trigger_category = PassiveDef.TriggerCategory.ON_OVERHEAT  # STAT_AURA illegal here

	_run([good, bad] as Array[PassiveDef])

	assert_eq(_count(&"content_illegal_passive_pairing"), 1, "exactly one illegal entry flagged")
	assert_eq(_detail(&"content_illegal_passive_pairing")["id"], &"bad_aura", "the illegal one is named")


## Edge case: a def at the INVALID enum sentinel errors as MALFORMED (missing
## field), NOT as an illegal pairing — the two families must not double-flag it.
func test_invalid_sentinel_is_malformed_not_illegal_pairing() -> void:
	# Arrange — a def with the behavior_class left at the 0 sentinel.
	var malformed := _valid_rider(&"malformed")
	malformed.behavior_class = 0

	# Act
	_one(malformed)

	# Assert — a missing-field error fires; the legality check stays silent.
	assert_true(_logged(&"content_passive_missing_field"), "unset behavior_class is a missing field")
	assert_false(_logged(&"content_illegal_passive_pairing"),
		"a sentinel def is malformed, never flagged as an illegal pairing")


# ---------------------------------------------------------------------------
# Structural schema checks — required fields present, enums in range
# ---------------------------------------------------------------------------

func test_missing_id_and_display_name_are_flagged() -> void:
	var bad := _valid_rider(&"placeholder")
	bad.id = &""
	bad.display_name = ""

	_one(bad)

	assert_true(_logged(&"content_passive_missing_field"), "missing id/display_name flagged")
	# Both fields report.
	var fields := {}
	for e in _spy.errors:
		if e["code"] == &"content_passive_missing_field":
			fields[e["detail"]["field"]] = true
	assert_true(fields.has(&"id"), "id reported missing")
	assert_true(fields.has(&"display_name"), "display_name reported missing")


func test_unset_enums_are_flagged_as_missing_fields() -> void:
	# Arrange — a bare def leaves every classification enum at 0.
	var bare := PassiveDef.new()
	bare.id = &"bare"
	bare.display_name = "Bare"

	# Act
	_one(bare)

	# Assert — behavior_class / trigger_category / stacking_policy / passive_class all missing.
	var fields := {}
	for e in _spy.errors:
		if e["code"] == &"content_passive_missing_field":
			fields[e["detail"]["field"]] = true
	assert_true(fields.has(&"behavior_class"),   "behavior_class reported missing")
	assert_true(fields.has(&"trigger_category"), "trigger_category reported missing")
	assert_true(fields.has(&"stacking_policy"),  "stacking_policy reported missing")
	assert_true(fields.has(&"passive_class"),    "passive_class reported missing")


## scope is required on ON_HIT (the move-slot filter) but is the null-equivalent 0
## for every other trigger — a non-ON_HIT passive with scope==0 must NOT be flagged.
func test_scope_required_only_on_on_hit() -> void:
	# Arrange — an ON_HIT rider with scope left unset.
	var no_scope := _valid_rider(&"no_scope")
	no_scope.scope = 0

	# Act
	_one(no_scope)

	# Assert — scope is reported missing on ON_HIT.
	var scope_missing := false
	for e in _spy.errors:
		if e["code"] == &"content_passive_missing_field" and e["detail"]["field"] == &"scope":
			scope_missing = true
	assert_true(scope_missing, "ON_HIT requires a scope")

	# A PERSISTENT aura with scope==0 is correct — no scope error.
	_one(_valid_aura(&"aura_ok"))
	var aura_scope_missing := false
	for e in _spy.errors:
		if e["code"] == &"content_passive_missing_field" and e["detail"]["field"] == &"scope":
			aura_scope_missing = true
	assert_false(aura_scope_missing, "non-ON_HIT passive with scope==0 is not flagged")


# ---------------------------------------------------------------------------
# AC-3 (TR-pdb-004): stacking_policy must match its behavior_class default
# ---------------------------------------------------------------------------

func test_stat_aura_stackable_is_stacking_mismatch() -> void:
	# Arrange — STAT_AURA defaults to UNIQUE; author STACKABLE instead.
	var bad := _valid_aura(&"bad_stack")
	bad.stacking_policy = PassiveDef.StackingPolicy.STACKABLE

	# Act
	_one(bad)

	# Assert — one mismatch naming id + expected UNIQUE.
	assert_eq(_count(&"content_passive_stacking_mismatch"), 1, "one stacking mismatch")
	var d := _detail(&"content_passive_stacking_mismatch")
	assert_eq(d["id"], &"bad_stack", "names the id")
	assert_eq(d["expected"], PassiveDef.StackingPolicy.UNIQUE, "reports the expected default UNIQUE")


## A passive whose policy matches its class default produces no mismatch.
func test_matching_stacking_policy_produces_no_error() -> void:
	_run([
		_valid_rider(&"r"),       # STATUS_RIDER → UNIQUE_PER_TRIGGER (match)
		_valid_aura(&"a"),        # STAT_AURA → UNIQUE (match)
		_valid_resource(&"res"),  # RESOURCE_EFFECT → STACKABLE (match)
		_valid_structural(&"s"),  # STRUCTURAL_EFFECT → UNIQUE (match)
	] as Array[PassiveDef])
	assert_false(_logged(&"content_passive_stacking_mismatch"),
		"policies matching their class default produce no mismatch")


# ---------------------------------------------------------------------------
# Null entry & family gating
# ---------------------------------------------------------------------------

func test_null_entry_is_fatal() -> void:
	var cat := PassiveCatalog.new()
	cat.entries.append(_valid_rider(&"a"))
	cat.entries.append(null)
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()
	catalogs.passives = cat
	_spy = SpyLogSink.new()

	ContentValidator.new().validate(catalogs, _spy)

	assert_true(_logged(&"content_null_entry"), "a null passive entry is fatal")
	assert_eq(_detail(&"content_null_entry")["db"], &"passive", "names the passive DB")


## The Passive family must not run when no passive catalog is mounted (a Part-only
## fixture stays green — the gate mirrors the Move family's `moves != null`).
func test_passive_family_skipped_when_catalog_absent() -> void:
	var catalogs := ContentCatalogs.new()  # no passives mounted
	catalogs.parts = PartCatalog.new()
	_spy = SpyLogSink.new()

	var r := ContentValidator.new().validate(catalogs, _spy)

	assert_true(r["ok"], "a Part-only fixture with no passive catalog validates ok")
	assert_false(_logged(&"content_illegal_passive_pairing"), "no passive checks ran")
