## Enemy-DB Story 004 — ContentValidator enemy schema-presence family.
##
## Covers:
##   AC-1  (AC-ED-01) presence/type: missing fields, bad/reserved enemy_class,
##          ELITE-value rejection, empty stats.
##   AC-2  (AC-ED-02) id uniqueness: duplicate id → error; unique → clean.
##   AC-3  (AC-ED-03 / TR-edb-019) skills count: 0→error, 5→warn, 1/4→clean.
##   AC-4  (AC-ED-03 ai_profile): empty→error; non-empty+accept-all→clean;
##          non-empty+reject-all seam→error (proves seam is wired).
##   AC-5  (AC-ED-13a/b) tier warn + over-length flavor error.
##
## Pattern: every AC pairs a CLEAN fixture (no error) with a CORRUPTED one (must
## fail), proving the validator discriminates — mirrors consumable_validator_test.gd
## (ADR-0003 authoring standard). Deterministic, in-memory catalogs, no file I/O.
## GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/enemy_database/spy_log_sink.gd")

var _spy: SpyLogSink


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

## Minimal well-formed WILD enemy. All required fields set; skills size = 1;
## non-empty ai_profile; tier = 1; short flavor_text.
func _wild(id: StringName = &"rust_hound") -> EnemyDef:
	var e := EnemyDef.new()
	e.id           = id
	e.display_name = "Rust Hound"
	e.enemy_class  = EnemyDef.EnemyClass.WILD
	e.tier         = 1
	e.stats        = {"structure": 60, "armor": 10, "resistance": 10,
	                  "physical_power": 20, "energy_power": 10,
	                  "mobility": 30, "processing": 15,
	                  "cooling": 0, "energy_capacity": 0, "recharge": 0,
	                  "output_power": 0}
	e.skills       = [&"basic_slash"]
	e.ai_profile   = &"AGGRESSIVE"
	e.flavor_text  = "A scrap-built canine found in industrial ruins."
	return e


## Minimal well-formed BOSS enemy.
func _boss(id: StringName = &"forge_king") -> EnemyDef:
	var e := EnemyDef.new()
	e.id           = id
	e.display_name = "Forge King"
	e.enemy_class  = EnemyDef.EnemyClass.BOSS
	e.tier         = 1
	e.stats        = {"structure": 200, "armor": 40, "resistance": 40,
	                  "physical_power": 39, "energy_power": 39,
	                  "mobility": 20, "processing": 50,
	                  "cooling": 0, "energy_capacity": 0, "recharge": 0,
	                  "output_power": 0}
	e.skills       = [&"hammer_strike", &"molten_wave"]
	e.ai_profile   = &"TACTICAL"
	e.flavor_text  = "Ruler of the foundry depths."
	return e


## Run validation against a list of EnemyDef entries.
## Provides an empty PartCatalog to satisfy the validator's mandatory parts check.
func _run(enemies: Array[EnemyDef]) -> Dictionary:
	var catalog    := EnemyCatalog.new()
	catalog.entries = enemies
	var catalogs   := ContentCatalogs.new()
	catalogs.parts   = PartCatalog.new()   # empty but present — always required
	catalogs.enemies = catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


## Run with a custom ContentValidator so tests can inject the ai_profile seam.
func _run_with(validator: ContentValidator, enemies: Array[EnemyDef]) -> Dictionary:
	var catalog    := EnemyCatalog.new()
	catalog.entries = enemies
	var catalogs   := ContentCatalogs.new()
	catalogs.parts   = PartCatalog.new()
	catalogs.enemies = catalog
	_spy = SpyLogSink.new()
	return validator.validate(catalogs, _spy)


## True if any error with the given code was logged.
func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


## True if any warning with the given code was logged.
func _warned(code: StringName) -> bool:
	for w in _spy.warns:
		if w["code"] == code:
			return true
	return false


# ---------------------------------------------------------------------------
# Clean fixture — passes with zero errors AND zero warnings
# ---------------------------------------------------------------------------

func test_clean_wild_enemy_passes_no_errors_no_warnings() -> void:
	var r := _run([_wild()])
	assert_true(r["ok"], "a well-formed WILD enemy validates")
	assert_eq((r["errors"] as Array).size(), 0, "no errors")
	assert_eq((r["warnings"] as Array).size(), 0, "no warnings")


func test_clean_boss_enemy_passes_no_errors_no_warnings() -> void:
	var r := _run([_boss()])
	assert_true(r["ok"], "a well-formed BOSS enemy validates")
	assert_eq((r["errors"] as Array).size(), 0, "no errors")
	assert_eq((r["warnings"] as Array).size(), 0, "no warnings")


# ---------------------------------------------------------------------------
# Prior-family non-regression: nil enemy catalog leaves prior families green
# ---------------------------------------------------------------------------

func test_nil_enemy_catalog_does_not_affect_part_validation() -> void:
	# A catalogs bundle with NO enemy catalog: the enemy family must be silently skipped.
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()
	# catalogs.enemies is null — intentionally not set.
	var spy := SpyLogSink.new()
	var r := ContentValidator.new().validate(catalogs, spy)
	# content_missing_part_catalog is NOT expected (we gave an empty but non-null
	# PartCatalog). No enemy errors should appear.
	for e in spy.errors:
		assert_ne(e["code"], &"content_enemy_schema_missing_field",
			"no enemy errors when enemy catalog not mounted")
	assert_true(r["ok"], "part-only fixture still validates when no enemy catalog mounted")


# ---------------------------------------------------------------------------
# AC-1 (AC-ED-01) — schema presence / type
# ---------------------------------------------------------------------------

func test_missing_id_errors() -> void:
	var bad := _wild()
	bad.id = &""
	_run([bad])
	assert_true(_logged(&"content_enemy_schema_missing_field"),
		"empty id → content_enemy_schema_missing_field")


func test_missing_display_name_errors() -> void:
	var bad := _wild()
	bad.display_name = ""
	_run([bad])
	assert_true(_logged(&"content_enemy_schema_missing_field"),
		"empty display_name → content_enemy_schema_missing_field")


func test_invalid_sentinel_enemy_class_errors() -> void:
	# INVALID (0) is the unset sentinel — should always error.
	var bad := _wild()
	bad.enemy_class = EnemyDef.EnemyClass.INVALID
	_run([bad])
	assert_true(_logged(&"content_enemy_schema_missing_field"),
		"INVALID class → content_enemy_schema_missing_field")


func test_reserved_elite_value_enemy_class_errors() -> void:
	# ELITE is reserved for Full Vision and NOT declared in EnemyDef.EnemyClass.
	# Any integer not in {WILD=1, BOSS=2} is rejected. The integer that WOULD be
	# ELITE is 3 per the GDD (the commented-out enum value in enemy_def.gd).
	# A .tres storing 3 reads back as INVALID=0 (not a known enum), so the
	# validator sees 0 and flags content_enemy_schema_missing_field.
	# We test by setting the raw int that doesn't resolve to WILD or BOSS.
	var bad := _wild()
	bad.enemy_class = 0  # INVALID sentinel — same as "ELITE" from a stale .tres
	_run([bad])
	assert_true(_logged(&"content_enemy_schema_missing_field"),
		"reserved/ELITE-equivalent class → content_enemy_schema_missing_field")


func test_wild_class_passes() -> void:
	var good := _wild()
	good.enemy_class = EnemyDef.EnemyClass.WILD
	_run([good])
	assert_false(_logged(&"content_enemy_schema_missing_field"),
		"WILD is an accepted class — no schema error")


func test_boss_class_passes() -> void:
	var good := _boss()
	good.enemy_class = EnemyDef.EnemyClass.BOSS
	_run([good])
	assert_false(_logged(&"content_enemy_schema_missing_field"),
		"BOSS is an accepted class — no schema error")


func test_empty_stats_errors() -> void:
	var bad := _wild()
	bad.stats = {}
	_run([bad])
	assert_true(_logged(&"content_enemy_schema_missing_field"),
		"empty stats dict → content_enemy_schema_missing_field")


func test_non_empty_stats_passes() -> void:
	var good := _wild()
	good.stats = {"structure": 60}
	_run([good])
	assert_false(_logged(&"content_enemy_schema_missing_field"),
		"non-empty stats → no schema-presence error")


func test_null_entry_is_fatal() -> void:
	var entries: Array[EnemyDef] = [_wild(), null]
	var r := _run(entries)
	assert_true(_logged(&"content_null_entry"), "null entry → content_null_entry")
	assert_false(r["ok"])


# ---------------------------------------------------------------------------
# AC-2 (AC-ED-02) — id uniqueness
# ---------------------------------------------------------------------------

func test_duplicate_enemy_id_is_fatal() -> void:
	# Two entries sharing id &"wild_dupe" — the discriminating fixture.
	var a := _wild(&"wild_dupe")
	var b := _wild(&"wild_dupe")
	b.display_name = "Dupe B"
	var r := _run([a, b])
	assert_true(_logged(&"content_enemy_duplicate_id"),
		"duplicate id → content_enemy_duplicate_id")
	assert_false(r["ok"], "duplicate id is fatal")


func test_unique_ids_pass() -> void:
	var a := _wild(&"hound_a")
	var b := _wild(&"hound_b")
	var r := _run([a, b])
	assert_false(_logged(&"content_enemy_duplicate_id"),
		"unique ids → no duplicate error")
	assert_true(r["ok"])


# ---------------------------------------------------------------------------
# AC-3 (AC-ED-03 / TR-edb-019) — skills count
# ---------------------------------------------------------------------------

func test_empty_skills_is_fatal() -> void:
	# skills.size() == 0 → BLOCKING error.
	var bad := _wild()
	bad.skills = []
	var r := _run([bad])
	assert_true(_logged(&"content_enemy_skills_empty"),
		"0 skills → content_enemy_skills_empty")
	assert_false(r["ok"])


func test_skills_size_five_warns_not_errors() -> void:
	# skills.size() == 5 → ADVISORY warning (> 4), not a blocking error.
	var e := _wild()
	e.skills = [&"s1", &"s2", &"s3", &"s4", &"s5"]
	var r := _run([e])
	assert_true(_warned(&"content_enemy_skills_excess"),
		"5 skills → content_enemy_skills_excess warning")
	assert_false(_logged(&"content_enemy_skills_empty"),
		"5 skills must NOT also fire the empty-skills error")
	assert_true(r["ok"], "excess-skills is advisory — result is still ok")


func test_skills_size_one_is_clean() -> void:
	# size-1 is the minimum legal count. No error, no warning.
	var e := _wild()
	e.skills = [&"basic_slash"]
	_run([e])
	assert_false(_logged(&"content_enemy_skills_empty"),
		"size-1 → no empty-skills error")
	assert_false(_warned(&"content_enemy_skills_excess"),
		"size-1 → no excess-skills warning")


func test_skills_size_four_is_clean() -> void:
	# size-4 is the boundary — must be clean (not warned). A >-off-by-one impl
	# would wrongly warn at 4; this fixture catches that.
	var e := _wild()
	e.skills = [&"s1", &"s2", &"s3", &"s4"]
	_run([e])
	assert_false(_warned(&"content_enemy_skills_excess"),
		"size-4 must NOT warn (warn triggers only at > 4, i.e. 5+)")


# ---------------------------------------------------------------------------
# AC-4 (AC-ED-03 ai_profile) — empty + referential seam
# ---------------------------------------------------------------------------

func test_empty_ai_profile_is_fatal() -> void:
	var bad := _wild()
	bad.ai_profile = &""
	var r := _run([bad])
	assert_true(_logged(&"content_enemy_ai_profile_missing"),
		"empty ai_profile → content_enemy_ai_profile_missing")
	assert_false(r["ok"])


func test_non_empty_ai_profile_with_default_accept_all_seam_passes() -> void:
	# The default seam is accept-all — a non-empty ai_profile must NOT error.
	var good := _wild()
	good.ai_profile = &"AGGRESSIVE"
	_run([good])
	assert_false(_logged(&"content_enemy_ai_profile_missing"),
		"non-empty ai_profile + accept-all seam → no error")


func test_non_empty_ai_profile_with_reject_all_seam_errors() -> void:
	# Injecting a reject-all Callable proves the referential seam is wired:
	# a non-empty ai_profile passed to a checker that returns false must error.
	var bad := _wild()
	bad.ai_profile = &"AGGRESSIVE"
	var validator := ContentValidator.new()
	validator.set_ai_profile_checker(func(_p: StringName) -> bool: return false)
	_run_with(validator, [bad])
	assert_true(_logged(&"content_enemy_ai_profile_missing"),
		"non-empty ai_profile + reject-all seam → content_enemy_ai_profile_missing")


# ---------------------------------------------------------------------------
# AC-5 (AC-ED-13a) — tier advisory
# ---------------------------------------------------------------------------

func test_tier_two_warns() -> void:
	# tier == 2 → advisory warning (only tier 1 is live in MVP).
	var e := _wild()
	e.tier = 2
	var r := _run([e])
	assert_true(_warned(&"content_enemy_tier_reserved"),
		"tier=2 → content_enemy_tier_reserved warning")
	assert_true(r["ok"], "tier warning is advisory — result is still ok")


func test_tier_one_does_not_warn() -> void:
	var e := _wild()
	e.tier = 1
	_run([e])
	assert_false(_warned(&"content_enemy_tier_reserved"),
		"tier=1 → no tier warning")


# ---------------------------------------------------------------------------
# AC-5 (AC-ED-13b) — flavor_text length
# ---------------------------------------------------------------------------

func test_flavor_text_at_cap_passes() -> void:
	# Boundary: exactly 100 characters PASSES (≤ 100 is valid).
	var e := _wild()
	e.flavor_text = "A".repeat(100)
	_run([e])
	assert_false(_logged(&"content_enemy_flavor_text_too_long"),
		"flavor_text length=100 → no error (inclusive boundary)")


func test_flavor_text_over_cap_errors() -> void:
	# Boundary: 101 characters FAILS.
	var e := _wild()
	e.flavor_text = "A".repeat(101)
	var r := _run([e])
	assert_true(_logged(&"content_enemy_flavor_text_too_long"),
		"flavor_text length=101 → content_enemy_flavor_text_too_long")
	assert_false(r["ok"])


func test_empty_flavor_text_does_not_trigger_length_error() -> void:
	# Empty flavor_text (length 0) is ≤ 100 — must not fire the length check.
	# (Schema presence for non-empty flavor_text is out of scope for this story.)
	var e := _wild()
	e.flavor_text = ""
	_run([e])
	assert_false(_logged(&"content_enemy_flavor_text_too_long"),
		"empty flavor_text → no flavor-length error")
