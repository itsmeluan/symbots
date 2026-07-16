## Passive-DB Story 007 — shipping rider content gate.
##
## Proves the three authored MVP status riders — volt_shock_on_hit,
## thermal_burn_on_weapon, kinetic_stagger_on_hit — and the PassiveCatalog manifest
## carry the exact catalog-contract values (AC-PDB-04/05/06, contract portion) and
## pass EVERY ContentValidator Passive family (Stories 004 + 005) with zero errors,
## and that their ids populate the referential membership set (Story 006).
##
## Loads every resource fresh from disk (CACHE_MODE_REPLACE) so it doubles as the
## on-real-content verification of the typed-enum + behavior_params `.tres`
## round-trip. The RUNTIME firing of these riders (status application, duration,
## scope gating) is owned by TBC's Rule 13 executor — out of scope here.
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/passive_database/spy_log_sink.gd")
const PassiveDBScript := preload("res://src/core/content/passive_db.gd")

const CATALOG_PATH := "res://assets/data/catalogs/passive_catalog.tres"
const PASSIVES_DIR := "res://assets/data/passives"

const RIDER_IDS: Array[StringName] = [
	&"volt_shock_on_hit", &"thermal_burn_on_weapon", &"kinetic_stagger_on_hit",
]

var _catalog: PassiveCatalog
var _db
var _report: Dictionary
var _spy


func before_all() -> void:
	# Fresh disk parse (not the cached save-time instance) — what CI and the
	# dev-boot loader actually read, exercising the real serializer.
	_catalog = ResourceLoader.load(CATALOG_PATH, "PassiveCatalog", ResourceLoader.CACHE_MODE_REPLACE)

	# Load through the real PassiveDB so the AC-1/2/3 reads come off the loader path.
	_db = PassiveDBScript.new()
	var load_spy := SpyLogSink.new()
	_db.load_catalog(_catalog, load_spy)

	# Full validator, passive family active, referential seam mounted.
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()               # empty valid part set (avoids content_missing_part_catalog)
	catalogs.passives = _catalog                     # mounts the Passive schema/authoring families
	catalogs.passive_ids = ContentCatalogs.passive_ids_from(_catalog)
	catalogs.references_mounted = true
	_spy = SpyLogSink.new()
	_report = ContentValidator.new().validate(catalogs, _spy)


func after_all() -> void:
	if _db != null:
		_db.free()


# ---------------------------------------------------------------------------
# AC-1/2/3 — the authored contract values, read off the loaded PassiveDB
# ---------------------------------------------------------------------------

func test_ac1_volt_shock_contract_values() -> void:
	var p: PassiveDef = _db.get_passive(&"volt_shock_on_hit")
	assert_not_null(p, "volt_shock_on_hit loads through PassiveDB")
	assert_eq(p.behavior_class, PassiveDef.BehaviorClass.STATUS_RIDER, "behavior_class STATUS_RIDER")
	assert_eq(p.trigger_category, PassiveDef.TriggerCategory.ON_HIT, "trigger_category ON_HIT")
	assert_eq(p.scope, PassiveDef.Scope.ANY_DAMAGE, "scope ANY_DAMAGE")
	assert_eq(p.stacking_policy, PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER, "stacking UNIQUE_PER_TRIGGER")
	assert_eq(p.passive_class, PassiveDef.PassiveClass.STATUS_RIDER, "passive_class STATUS_RIDER")
	assert_eq(p.behavior_params.get("status_id"), &"shock", "payload names Shock")
	assert_eq(p.behavior_params.get("duration"), 1, "Shock duration 1")


func test_ac2_thermal_burn_contract_values() -> void:
	var p: PassiveDef = _db.get_passive(&"thermal_burn_on_weapon")
	assert_not_null(p, "thermal_burn_on_weapon loads through PassiveDB")
	assert_eq(p.behavior_class, PassiveDef.BehaviorClass.STATUS_RIDER, "behavior_class STATUS_RIDER")
	assert_eq(p.trigger_category, PassiveDef.TriggerCategory.ON_HIT, "trigger_category ON_HIT")
	assert_eq(p.scope, PassiveDef.Scope.WEAPON_ONLY, "scope WEAPON_ONLY (TR-pdb-003)")
	assert_eq(p.stacking_policy, PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER, "stacking UNIQUE_PER_TRIGGER")
	assert_eq(p.passive_class, PassiveDef.PassiveClass.STATUS_RIDER, "passive_class STATUS_RIDER")
	assert_eq(p.behavior_params.get("status_id"), &"burn", "payload names Burn")
	assert_eq(p.behavior_params.get("duration"), 2, "Burn duration 2")


func test_ac3_kinetic_stagger_contract_values() -> void:
	var p: PassiveDef = _db.get_passive(&"kinetic_stagger_on_hit")
	assert_not_null(p, "kinetic_stagger_on_hit loads through PassiveDB")
	assert_eq(p.behavior_class, PassiveDef.BehaviorClass.STATUS_RIDER, "behavior_class STATUS_RIDER")
	assert_eq(p.trigger_category, PassiveDef.TriggerCategory.ON_HIT, "trigger_category ON_HIT")
	assert_eq(p.scope, PassiveDef.Scope.ANY_DAMAGE, "scope ANY_DAMAGE")
	assert_eq(p.stacking_policy, PassiveDef.StackingPolicy.UNIQUE_PER_TRIGGER, "stacking UNIQUE_PER_TRIGGER")
	assert_eq(p.passive_class, PassiveDef.PassiveClass.STATUS_RIDER, "passive_class STATUS_RIDER")
	assert_eq(p.behavior_params.get("status_id"), &"stagger", "payload names Stagger")
	assert_eq(p.behavior_params.get("duration"), 1, "Stagger duration 1")


# ---------------------------------------------------------------------------
# AC-4 — catalog loads from disk, validates clean, ids resolve
# ---------------------------------------------------------------------------

func test_catalog_loads_all_three_riders_from_disk() -> void:
	assert_not_null(_catalog, "passive_catalog.tres loads from disk")
	assert_true(_catalog is PassiveCatalog, "loaded resource is a PassiveCatalog")
	assert_eq(_catalog.entries.size(), 3, "the catalog ships all three MVP riders")


func test_shipped_riders_pass_full_validator() -> void:
	assert_true(_report["ok"], "the shipped riders validate ok==true under every Passive family")
	assert_eq((_report["errors"] as Array).size(), 0,
		"the shipped riders produce zero validator errors: %s" % [_report["errors"]])
	assert_eq(_spy.errors.size(), 0, "no diagnostics reached the LogSink error channel")


func test_all_three_rider_ids_resolve_in_membership_set() -> void:
	var ids := ContentCatalogs.passive_ids_from(_catalog)
	for id in RIDER_IDS:
		assert_true(ids.has(id), "%s is present in the passive_ids membership set" % id)


func test_catalog_entry_count_matches_files_on_disk() -> void:
	# Every .tres under passives/ must be in the catalog and vice-versa. DirAccess in a
	# TEST only (the load path forbids it — ADR-0003).
	var files := _tres_files(PASSIVES_DIR)
	assert_eq(files.size(), _catalog.entries.size(),
		"passive .tres file count (%d) equals catalog entry count (%d)" % [files.size(), _catalog.entries.size()])


func test_every_catalog_entry_has_a_unique_id() -> void:
	var seen := {}
	for passive in _catalog.entries:
		assert_not_null(passive, "no null entry in the catalog")
		assert_false(seen.has(passive.id), "duplicate catalog id: %s" % [passive.id])
		seen[passive.id] = true


func _tres_files(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir_path)
	assert_not_null(da, "passives directory opens: %s" % dir_path)
	for f in da.get_files():
		if f.ends_with(".tres"):
			out.append(f)
	return out
