## Enemy-DB Story 008 — ContentValidator harvest-decision, TTK & density/spawn family.
##
## Covers the five Story-008 checks in [EnemyValidator], none of which are gated by
## the Part-DB referential seam — they run for every enemy on every validate() pass.
## Fixtures are otherwise schema/stat/break-region valid so a single Story-008 verdict
## can be asserted in isolation (assertions target the specific Story-008 codes, so any
## incidental advisory from a neighbouring dimension never masks the check under test).
##
##   AC-1 (AC-ED-15c / TR-edb-010 harvest-decision, BLOCKING): `loot_pool.size()` must be
##          STRICTLY greater than `break_regions.size()`. Equal → error (the `>=` off-by-one
##          discriminator: equal counts force breaking, killing the "which region?" choice);
##          3-vs-2 → no error; 1-vs-2 → no error; 1-vs-1 → error; 2-vs-1 → error.
##   AC-2 (AC-ED-14 EDB-2 TTK, ADVISORY): dual-channel band. In-band → no warning; a channel
##          out-of-band → warning naming id + channel + computed TTK; NEVER an error. The
##          armor and resistance channels are evaluated independently — a high-armor BOSS
##          warns on armor while resistance stays silent (the GDD dual-channel fixture).
##   AC-3 (AC-ED-17 spawn-disabled BOSS): a BOSS with `spawn_enabled == false` → warning;
##          a WILD with `spawn_enabled == false` → none (only BOSSes gate progression).
##   AC-4 (AC-ED-15d / TR-edb-020 null-element density, ADVISORY): catalog-scoped count of
##          null-`core_element` WILD entries over `NULL_ELEMENT_MAX_WILD` (=1) → one warning;
##          within cap → none; null-element BOSSes never count.
##   AC-5 (AC-ED-15a/b content density, ADVISORY): break_regions >3, or loot_pool outside the
##          class band (WILD 2–4, BOSS 4–6) → warning tagged by `dimension`.
##
## Deterministic, in-memory catalogs (no file I/O, no seam). Every TTK fixture is
## python3-verified (integer ceil matches math.ceil, zero divergences). GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/enemy_database/spy_log_sink.gd")

var _spy: SpyLogSink

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## A schema/stat valid enemy with the given class, structure and id. `armor`/`resistance`
## default to 10 (WILD in-band); TTK fixtures override them. No break regions or loot yet.
func _base(cls: EnemyDef.EnemyClass, structure: int, id: StringName) -> EnemyDef:
	var e := EnemyDef.new()
	e.id           = id
	e.display_name = "Density Test Enemy"
	e.enemy_class  = cls
	e.tier         = 1
	e.core_element = PartDef.Element.VOLT  # non-null by default; null-element tests override
	e.stats        = {
		"structure": structure,
		"armor": 10, "resistance": 10,
		"physical_power": 20, "energy_power": 10,
		"mobility": 15, "processing": 15,
		"cooling": 0, "energy_capacity": 0, "recharge": 0,
		"output_power": 0,
	}
	e.skills       = [&"basic_slash"]
	e.ai_profile   = &"AGGRESSIVE"
	e.flavor_text  = "A Story-008 density fixture."
	# Story 009 progression fields kept valid so the progression family stays silent
	# and does not mask the Story-008 verdict under test (WILD → xp 45, BOSS → 90).
	e.level        = 1
	e.xp_value     = XpRewardFormula.derive_xp_value(1, cls)
	return e


## A break region with a valid EDB-1 break_hp derived from `structure`.
func _region(rid: String, event: String, structure: int, fraction: float = 0.15) -> Dictionary:
	return {
		"region_id": rid,
		"region_fraction": fraction,
		"break_hp": BreakHpFormula.derive_break_hp(structure, fraction),
		"break_event": event,
	}


## A plain floor loot_pool entry (no break-event gating — harvest/density count shape only).
func _loot(id: String) -> Dictionary:
	return {"id": id, "enabled": true}


## Give `e` `region_count` distinct regions and `pool_count` floor loot entries.
func _with_counts(e: EnemyDef, region_count: int, pool_count: int) -> EnemyDef:
	var structure: int = e.stats.get("structure", 100)
	var regions: Array[Dictionary] = []
	for i in region_count:
		regions.append(_region("r%d" % i, "event_%d" % i, structure))
	e.break_regions = regions
	var pool: Array[Dictionary] = []
	for i in pool_count:
		pool.append(_loot("floor_%d" % i))
	e.loot_pool = pool
	return e


# ---------------------------------------------------------------------------
# Run helpers — validate WITHOUT the Part-DB seam (Story-008 checks are seam-free)
# ---------------------------------------------------------------------------

func _run(enemy: EnemyDef) -> Dictionary:
	return _run_catalog([enemy])


func _run_catalog(entries: Array) -> Dictionary:
	var catalog := EnemyCatalog.new()
	var typed: Array[EnemyDef] = []
	typed.assign(entries)
	catalog.entries = typed
	var catalogs := ContentCatalogs.new()
	catalogs.parts   = PartCatalog.new()
	catalogs.enemies = catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _logged(code: StringName) -> bool:
	for e: Dictionary in _spy.errors:
		if e["code"] == code:
			return true
	return false


func _warned(code: StringName) -> bool:
	for w: Dictionary in _spy.warns:
		if w["code"] == code:
			return true
	return false


func _warn_count(code: StringName) -> int:
	var n := 0
	for w: Dictionary in _spy.warns:
		if w["code"] == code:
			n += 1
	return n


## First warning payload matching `code` (or {} if none) — for asserting id/channel/ttk.
func _warn_data(code: StringName) -> Dictionary:
	for w: Dictionary in _spy.warns:
		if w["code"] == code:
			return w.get("detail", {})
	return {}


# ===========================================================================
# AC-1 — harvest-decision (BLOCKING, the sole blocking Story-008 check)
# ===========================================================================

func test_harvest_equal_counts_errors() -> void:
	# Arrange — 2 regions, 2 pool: breaking is FORCED, the choice vanishes.
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"equal_ed"), 2, 2)
	# Act
	_run(e)
	# Assert — the `>=` off-by-one discriminator: equal MUST error.
	assert_true(_logged(&"content_enemy_harvest_decision"), "equal counts force breaking → error")


func test_harvest_pool_greater_than_regions_no_error() -> void:
	# Arrange — 2 regions, 3 pool: at least one floor drop → breaking is a choice.
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"three_two"), 2, 3)
	# Act
	_run(e)
	# Assert
	assert_false(_logged(&"content_enemy_harvest_decision"), "3 pool > 2 regions → no error")


func test_harvest_one_region_two_pool_no_error() -> void:
	# Arrange — 1 region, 2 pool: strictly greater, passes.
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"one_two"), 1, 2)
	# Act
	_run(e)
	# Assert
	assert_false(_logged(&"content_enemy_harvest_decision"), "2 pool > 1 region → no error")


func test_harvest_one_region_one_pool_errors() -> void:
	# Arrange — 1 region, 1 pool: degenerate, breaking is the only path.
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"one_one"), 1, 1)
	# Act
	_run(e)
	# Assert
	assert_true(_logged(&"content_enemy_harvest_decision"), "1 pool == 1 region → error")


func test_harvest_fewer_pool_than_regions_errors() -> void:
	# Arrange — 2 regions, 1 pool: fewer drops than regions.
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"two_one"), 2, 1)
	# Act
	_run(e)
	# Assert
	assert_true(_logged(&"content_enemy_harvest_decision"), "1 pool < 2 regions → error")


# ===========================================================================
# AC-2 — EDB-2 TTK band (ADVISORY, dual-channel, never an error)
# ===========================================================================

func test_ttk_boss_in_band_no_warning() -> void:
	# Arrange — BOSS structure 400, armor & resistance 40 → both channels TTK 14 (band 12–18).
	var e := _with_counts(_base(EnemyDef.EnemyClass.BOSS, 400, &"forge_king"), 2, 4)
	e.stats["armor"] = 40
	e.stats["resistance"] = 40
	# Act
	_run(e)
	# Assert
	assert_false(_warned(&"content_enemy_ttk_out_of_band"), "both channels in band → no TTK warning")


func test_ttk_armor_channel_out_warns_resist_silent() -> void:
	# Arrange — GDD dual-channel fixture: BOSS s400, armor 5 → TTK 9 (<12, warns),
	# resistance 60 → TTK 17 (in band, silent). Exactly one TTK warning, channel=armor.
	var e := _with_counts(_base(EnemyDef.EnemyClass.BOSS, 400, &"glass_armor"), 2, 4)
	e.stats["armor"] = 5
	e.stats["resistance"] = 60
	# Act
	_run(e)
	# Assert — the channels are independent: only the armor channel breaches the band.
	assert_eq(_warn_count(&"content_enemy_ttk_out_of_band"), 1, "only the armor channel warns")
	var data := _warn_data(&"content_enemy_ttk_out_of_band")
	assert_eq(data.get("channel"), &"armor", "the breaching channel is armor")
	assert_eq(data.get("ttk"), 9, "computed armor TTK is 9")


func test_ttk_resist_channel_out_warns_armor_silent() -> void:
	# Arrange — mirror image: BOSS s400, armor 40 → TTK 14 (in), resistance 200 → TTK 37 (>18).
	var e := _with_counts(_base(EnemyDef.EnemyClass.BOSS, 400, &"aegis_wall"), 2, 4)
	e.stats["armor"] = 40
	e.stats["resistance"] = 200
	# Act
	_run(e)
	# Assert
	assert_eq(_warn_count(&"content_enemy_ttk_out_of_band"), 1, "only the resistance channel warns")
	assert_eq(_warn_data(&"content_enemy_ttk_out_of_band").get("channel"), &"resistance",
		"the breaching channel is resistance")


func test_ttk_out_of_band_is_warning_never_error() -> void:
	# Arrange — a wildly out-of-band BOSS (armor 200 → TTK 37 both channels).
	var e := _with_counts(_base(EnemyDef.EnemyClass.BOSS, 400, &"unbreakable"), 2, 4)
	e.stats["armor"] = 200
	e.stats["resistance"] = 200
	# Act
	_run(e)
	# Assert — pacing advisory only; TTK never blocks.
	assert_true(_warned(&"content_enemy_ttk_out_of_band"), "out-of-band warns")
	assert_false(_logged(&"content_enemy_ttk_out_of_band"), "TTK is ADVISORY — never an error")


func test_ttk_wild_early_in_band_no_warning() -> void:
	# Arrange — WILD structure 60 (<90 → early band 2–4, A_cal 35), armor/res 10 → TTK 3.
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"scrap_hound"), 2, 3)
	# Act
	_run(e)
	# Assert
	assert_false(_warned(&"content_enemy_ttk_out_of_band"), "WILD TTK 3 in early band → no warning")


func test_ttk_wild_too_tanky_warns() -> void:
	# Arrange — WILD s60, armor 100 → dmg 9 → TTK 7 (>4 early-band max).
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"rock_crab"), 2, 3)
	e.stats["armor"] = 100
	# Act
	_run(e)
	# Assert
	assert_true(_warned(&"content_enemy_ttk_out_of_band"), "WILD TTK 7 exceeds early band → warns")
	assert_eq(_warn_data(&"content_enemy_ttk_out_of_band").get("ttk"), 7, "computed WILD TTK is 7")


# ===========================================================================
# AC-3 — spawn-disabled BOSS (ADVISORY progression warning)
# ===========================================================================

func test_spawn_disabled_boss_warns() -> void:
	# Arrange — a retired BOSS silently removes a progression gate.
	var e := _with_counts(_base(EnemyDef.EnemyClass.BOSS, 400, &"retired_boss"), 2, 4)
	e.stats["armor"] = 40
	e.stats["resistance"] = 40
	e.spawn_enabled = false
	# Act
	_run(e)
	# Assert
	assert_true(_warned(&"content_enemy_boss_spawn_disabled"), "disabled BOSS → progression warning")


func test_spawn_disabled_wild_no_warning() -> void:
	# Arrange — retiring a WILD is routine content management, not a gate risk.
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"retired_wild"), 2, 3)
	e.spawn_enabled = false
	# Act
	_run(e)
	# Assert
	assert_false(_warned(&"content_enemy_boss_spawn_disabled"), "disabled WILD → no warning")


func test_spawn_enabled_boss_no_warning() -> void:
	# Arrange — an active BOSS is fine (spawn_enabled defaults true).
	var e := _with_counts(_base(EnemyDef.EnemyClass.BOSS, 400, &"active_boss"), 2, 4)
	e.stats["armor"] = 40
	e.stats["resistance"] = 40
	# Act
	_run(e)
	# Assert
	assert_false(_warned(&"content_enemy_boss_spawn_disabled"), "enabled BOSS → no warning")


# ===========================================================================
# AC-4 — null-element density (ADVISORY, catalog-scoped)
# ===========================================================================

func _null_wild(id: StringName) -> EnemyDef:
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, id), 2, 3)
	e.core_element = 0 as PartDef.Element  # null / no elemental affinity
	return e


func test_null_element_over_cap_warns_once() -> void:
	# Arrange — two null-element WILDs exceed the cap of 1 (catalog-scoped).
	var entries := [_null_wild(&"null_a"), _null_wild(&"null_b")]
	# Act
	_run_catalog(entries)
	# Assert — exactly ONE catalog-level warning carrying the observed count.
	assert_eq(_warn_count(&"content_enemy_null_element_density"), 1, "one catalog-level warning")
	assert_eq(_warn_data(&"content_enemy_null_element_density").get("count"), 2, "count is 2")


func test_null_element_within_cap_no_warning() -> void:
	# Arrange — a single null-element WILD sits at the cap (1), so no warning.
	var entries := [_null_wild(&"null_solo"),
		_with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"volt_wild"), 2, 3)]
	# Act
	_run_catalog(entries)
	# Assert
	assert_false(_warned(&"content_enemy_null_element_density"), "1 null-element WILD is within cap")


func test_null_element_boss_does_not_count() -> void:
	# Arrange — a null-element BOSS is a deliberate "neutral wall", not roster dilution;
	# paired with one null WILD (at cap) → no warning.
	var boss := _with_counts(_base(EnemyDef.EnemyClass.BOSS, 400, &"neutral_wall"), 2, 4)
	boss.stats["armor"] = 40
	boss.stats["resistance"] = 40
	boss.core_element = 0 as PartDef.Element
	var entries := [boss, _null_wild(&"null_solo")]
	# Act
	_run_catalog(entries)
	# Assert — only the single WILD counts; the null BOSS is excluded.
	assert_false(_warned(&"content_enemy_null_element_density"), "null BOSS excluded from the count")


# ===========================================================================
# AC-5 — content-density guidelines (ADVISORY, tagged by dimension)
# ===========================================================================

func test_density_too_many_break_regions_warns() -> void:
	# Arrange — 4 break regions exceeds the MVP cap of 3. Pool 5 keeps it harvest-clean.
	var e := _with_counts(_base(EnemyDef.EnemyClass.BOSS, 400, &"over_regioned"), 4, 5)
	e.stats["armor"] = 40
	e.stats["resistance"] = 40
	# Act
	_run(e)
	# Assert
	assert_true(_warned(&"content_enemy_density_guideline"), "4 break regions → density warning")
	assert_eq(_warn_data(&"content_enemy_density_guideline").get("dimension"), &"break_regions",
		"the flagged dimension is break_regions")


func test_density_wild_pool_below_band_warns() -> void:
	# Arrange — WILD pool of 1 is below the 2–4 band (2 regions keeps it under the region cap;
	# harvest still errors at 1-vs-2 but we assert only the density dimension here).
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"thin_wild"), 0, 1)
	# Act
	_run(e)
	# Assert — pool 1 < WILD min 2.
	assert_true(_warned(&"content_enemy_density_guideline"), "WILD pool below band → warning")
	assert_eq(_warn_data(&"content_enemy_density_guideline").get("dimension"), &"loot_pool",
		"the flagged dimension is loot_pool")


func test_density_boss_pool_above_band_warns() -> void:
	# Arrange — BOSS pool of 7 exceeds the 4–6 band.
	var e := _with_counts(_base(EnemyDef.EnemyClass.BOSS, 400, &"loot_pinata"), 2, 7)
	e.stats["armor"] = 40
	e.stats["resistance"] = 40
	# Act
	_run(e)
	# Assert
	assert_true(_warned(&"content_enemy_density_guideline"), "BOSS pool above band → warning")


func test_density_wild_in_band_no_warning() -> void:
	# Arrange — WILD with 2 regions and pool 3 (in 2–4 band) → no density warning.
	var e := _with_counts(_base(EnemyDef.EnemyClass.WILD, 60, &"tidy_wild"), 2, 3)
	# Act
	_run(e)
	# Assert
	assert_false(_warned(&"content_enemy_density_guideline"), "WILD pool 3, 2 regions → clean")
