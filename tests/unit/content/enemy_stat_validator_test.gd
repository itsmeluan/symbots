## Enemy-DB Story 005 — ContentValidator enemy stat-block value family.
##
## Covers:
##   AC-1  (AC-ED-05a) structure: 0→error, negative→error, 1→clean.
##   AC-2  (AC-ED-05b) A/D stat ranges [0,110] inclusive: 110→clean, 111→error,
##          0→clean, negative→error. Discriminating: a "< 110" impl wrongly
##          rejects the legal 110 boundary.
##   AC-3  (AC-ED-05c/d) WILD power cap ≤39: WILD power=40→error, WILD
##          power=39→clean, BOSS power=40→clean. The WILD-vs-BOSS split is the
##          key discriminator — a class-blind cap wrongly fails the BOSS case.
##   AC-4  (TR-edb-011/012) Unknown-key typo warn + dead-data non-zero warn;
##          clean 11-stat block with dead-data all 0 → no warnings.
##
## Pattern: every AC pairs a CLEAN fixture (no finding) with a CORRUPTED one
## (must fire the expected error/warning), proving the validator discriminates.
## Deterministic, in-memory catalogs, no file I/O. GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/enemy_database/spy_log_sink.gd")

var _spy: SpyLogSink


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

## Minimal well-formed WILD enemy with a complete 11-stat block (dead-data all
## zero). All A/D stats within [0,110]; power values within the WILD cap (39).
func _wild(id: StringName = &"rust_hound") -> EnemyDef:
	var e := EnemyDef.new()
	e.id           = id
	e.display_name = "Rust Hound"
	e.enemy_class  = EnemyDef.EnemyClass.WILD
	e.tier         = 1
	e.stats        = {
		"structure": 60,
		"armor": 10, "resistance": 10,
		"physical_power": 20, "energy_power": 10,
		"mobility": 30, "processing": 15,
		"cooling": 0, "energy_capacity": 0, "recharge": 0,
		"output_power": 0,
	}
	e.skills       = [&"basic_slash"]
	e.ai_profile   = &"AGGRESSIVE"
	e.flavor_text  = "A scrap-built canine found in industrial ruins."
	return e


## Minimal well-formed BOSS enemy. power values can exceed the WILD cap.
func _boss(id: StringName = &"forge_king") -> EnemyDef:
	var e := EnemyDef.new()
	e.id           = id
	e.display_name = "Forge King"
	e.enemy_class  = EnemyDef.EnemyClass.BOSS
	e.tier         = 1
	e.stats        = {
		"structure": 364,
		"armor": 30, "resistance": 30,
		"physical_power": 40, "energy_power": 40,
		"mobility": 20, "processing": 50,
		"cooling": 0, "energy_capacity": 0, "recharge": 0,
		"output_power": 0,
	}
	e.skills       = [&"hammer_strike", &"molten_wave"]
	e.ai_profile   = &"TACTICAL"
	e.flavor_text  = "Ruler of the foundry depths."
	return e


## Run validation against a list of EnemyDef entries. Provides an empty
## PartCatalog to satisfy the validator's mandatory parts check.
func _run(enemies: Array[EnemyDef]) -> Dictionary:
	var catalog := EnemyCatalog.new()
	catalog.entries = enemies
	var catalogs := ContentCatalogs.new()
	catalogs.parts   = PartCatalog.new()
	catalogs.enemies = catalog
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


## True if any error with the given code was logged.
func _logged(code: StringName) -> bool:
	for e: Dictionary in _spy.errors:
		if e["code"] == code:
			return true
	return false


## True if any warning with the given code was logged.
func _warned(code: StringName) -> bool:
	for w: Dictionary in _spy.warns:
		if w["code"] == code:
			return true
	return false


# ---------------------------------------------------------------------------
# Clean baseline — the full 11-stat WILD block must pass with no findings
# ---------------------------------------------------------------------------

func test_clean_wild_enemy_passes_no_errors_no_warnings() -> void:
	var r := _run([_wild()])
	assert_true(r["ok"], "well-formed WILD enemy with correct 11-stat block validates")
	assert_eq((r["errors"] as Array).size(), 0, "no errors")
	assert_eq((r["warnings"] as Array).size(), 0, "no warnings — dead-data at 0, no unknown keys")


func test_clean_boss_enemy_passes_no_errors_no_warnings() -> void:
	# BOSS power=40 is ABOVE the WILD cap (39) but BOSS is exempt — must still
	# pass cleanly. This is the key non-regression for class-aware cap logic.
	var r := _run([_boss()])
	assert_true(r["ok"], "well-formed BOSS enemy (power=40) validates — BOSS is exempt from WILD cap")
	assert_eq((r["errors"] as Array).size(), 0, "no errors")
	assert_eq((r["warnings"] as Array).size(), 0, "no warnings")


# ---------------------------------------------------------------------------
# AC-1 (AC-ED-05a) — structure ≥ 1
# ---------------------------------------------------------------------------

func test_structure_zero_errors() -> void:
	# A 0-structure enemy has no HP and dies on contact — never valid content.
	var bad := _wild()
	bad.stats["structure"] = 0
	var r := _run([bad])
	assert_true(_logged(&"content_enemy_stat_structure_invalid"),
		"structure=0 → content_enemy_stat_structure_invalid")
	assert_false(r["ok"])


func test_structure_negative_errors() -> void:
	# Negative structure is equally invalid — should not silently pass.
	var bad := _wild()
	bad.stats["structure"] = -5
	var r := _run([bad])
	assert_true(_logged(&"content_enemy_stat_structure_invalid"),
		"structure=-5 → content_enemy_stat_structure_invalid")
	assert_false(r["ok"])


func test_structure_one_is_clean() -> void:
	# 1 is the positive boundary — must pass with no structure error.
	var good := _wild()
	good.stats["structure"] = 1
	_run([good])
	assert_false(_logged(&"content_enemy_stat_structure_invalid"),
		"structure=1 → no structure error (positive boundary)")


func test_structure_above_one_is_clean() -> void:
	var good := _wild()
	good.stats["structure"] = 60
	_run([good])
	assert_false(_logged(&"content_enemy_stat_structure_invalid"),
		"structure=60 → no structure error")


# ---------------------------------------------------------------------------
# AC-2 (AC-ED-05b) — A/D stat ranges [0, 110] inclusive
# Discriminating: a "< 110" exclusive impl wrongly rejects the legal 110 value.
# ---------------------------------------------------------------------------

func test_power_at_upper_boundary_110_passes() -> void:
	# 110 is the INCLUSIVE upper bound — must pass. An impl using `< 110`
	# (exclusive) would wrongly reject this case.
	var good := _boss()
	good.stats["physical_power"] = 110
	good.stats["energy_power"] = 10   # keep below 110 so only one stat is at boundary
	_run([good])
	assert_false(_logged(&"content_enemy_stat_out_of_range"),
		"physical_power=110 → no range error (inclusive upper boundary)")


func test_power_at_111_errors() -> void:
	# 111 is above the inclusive upper bound — must error, naming the stat.
	var bad := _boss()
	bad.stats["physical_power"] = 111
	var r := _run([bad])
	assert_true(_logged(&"content_enemy_stat_out_of_range"),
		"physical_power=111 → content_enemy_stat_out_of_range")
	assert_false(r["ok"])


func test_armor_at_zero_passes() -> void:
	# 0 is the INCLUSIVE lower bound. A=0, D=0 into DF-1 is handled by the
	# DAMAGE_FLOOR guard there — the schema authorizes the input (GDD Rule 3).
	var good := _wild()
	good.stats["armor"] = 0
	_run([good])
	assert_false(_logged(&"content_enemy_stat_out_of_range"),
		"armor=0 → no range error (inclusive lower boundary)")


func test_resist_at_120_errors() -> void:
	# 120 is well above the 110 ceiling — must error.
	var bad := _wild()
	bad.stats["resistance"] = 120
	var r := _run([bad])
	assert_true(_logged(&"content_enemy_stat_out_of_range"),
		"resistance=120 → content_enemy_stat_out_of_range")
	assert_false(r["ok"])


func test_armor_at_110_passes() -> void:
	# Second inclusive-upper-boundary check on armor (separate from power).
	var good := _boss()
	good.stats["armor"] = 110
	_run([good])
	assert_false(_logged(&"content_enemy_stat_out_of_range"),
		"armor=110 → no range error (inclusive upper boundary)")


func test_energy_power_at_111_errors() -> void:
	var bad := _boss()
	bad.stats["energy_power"] = 111
	var r := _run([bad])
	assert_true(_logged(&"content_enemy_stat_out_of_range"),
		"energy_power=111 → content_enemy_stat_out_of_range")
	assert_false(r["ok"])


func test_resistance_at_zero_passes() -> void:
	var good := _wild()
	good.stats["resistance"] = 0
	_run([good])
	assert_false(_logged(&"content_enemy_stat_out_of_range"),
		"resistance=0 → no range error")


# ---------------------------------------------------------------------------
# AC-3 (AC-ED-05c/d) — WILD power cap ≤ 39 (BOSS exempt)
# KEY DISCRIMINATOR: a class-blind cap wrongly errors the BOSS power=40 case.
# ---------------------------------------------------------------------------

func test_wild_power_40_errors() -> void:
	# WILD with physical_power=40 → BLOCKING error. Derivation: at A=40, D=0,
	# T=1.5 → floor(1600/40 × 1.5) = 60 ≥ 60 min Structure → one-hit kill.
	var bad := _wild()
	bad.stats["physical_power"] = 40
	var r := _run([bad])
	assert_true(_logged(&"content_enemy_stat_wild_power_cap"),
		"WILD physical_power=40 → content_enemy_stat_wild_power_cap")
	assert_false(r["ok"])


func test_boss_power_40_passes() -> void:
	# BOSS with physical_power=40 → clean. BOSS power is exempt from the cap
	# (GDD Rule 3: "BOSS power is exempt, up to 70"). A class-blind cap
	# implementation would wrongly fire on this case — this fixture catches that.
	var good := _boss()
	good.stats["physical_power"] = 40
	_run([good])
	assert_false(_logged(&"content_enemy_stat_wild_power_cap"),
		"BOSS physical_power=40 → no wild-power-cap error (BOSS is exempt)")


func test_wild_power_39_passes() -> void:
	# 39 is the inclusive upper bound for WILD — must pass cleanly.
	var good := _wild()
	good.stats["physical_power"] = 39
	good.stats["energy_power"] = 39
	_run([good])
	assert_false(_logged(&"content_enemy_stat_wild_power_cap"),
		"WILD physical_power=39, energy_power=39 → no cap error (inclusive boundary)")


func test_wild_energy_power_40_errors() -> void:
	# Both power channels are checked independently — energy_power=40 also caps.
	var bad := _wild()
	bad.stats["energy_power"] = 40
	var r := _run([bad])
	assert_true(_logged(&"content_enemy_stat_wild_power_cap"),
		"WILD energy_power=40 → content_enemy_stat_wild_power_cap")
	assert_false(r["ok"])


func test_boss_power_70_passes() -> void:
	# GDD Rule 3 names 70 as the BOSS power ceiling in prose — must pass.
	var good := _boss()
	good.stats["physical_power"] = 70
	good.stats["energy_power"] = 70
	_run([good])
	assert_false(_logged(&"content_enemy_stat_wild_power_cap"),
		"BOSS power=70 → no cap error")


# ---------------------------------------------------------------------------
# AC-4a (TR-edb-011) — unknown stat key → ADVISORY warning
# ---------------------------------------------------------------------------

func test_typo_key_powr_warns() -> void:
	# "powr" is a plausible typo for "physical_power" — not in the 11-stat
	# allow-list, so the validator should warn, not error.
	var e := _wild()
	e.stats["powr"] = 30
	var r := _run([e])
	assert_true(_warned(&"content_enemy_stat_unknown_key"),
		'"powr" typo key → content_enemy_stat_unknown_key warning')
	assert_true(r["ok"], "unknown-key warning is ADVISORY — result is still ok")


func test_unknown_key_warns_not_errors() -> void:
	# Confirms unknown keys produce warnings (not blocking errors).
	var e := _wild()
	e.stats["totally_made_up_stat"] = 5
	_run([e])
	assert_true(_warned(&"content_enemy_stat_unknown_key"),
		"unknown stat key → advisory warning")
	assert_false(_logged(&"content_enemy_stat_out_of_range"),
		"unknown key must NOT trigger an out-of-range error")


func test_clean_11_stat_block_no_unknown_key_warning() -> void:
	# All 11 canonical keys present, no extras → no unknown-key warning.
	var e := _wild()  # _wild() already has the complete 11-stat block.
	_run([e])
	assert_false(_warned(&"content_enemy_stat_unknown_key"),
		"clean 11-stat block → no unknown-key warning")


# ---------------------------------------------------------------------------
# AC-4b (TR-edb-012) — dead-data non-zero → ADVISORY warning
# ---------------------------------------------------------------------------

func test_cooling_nonzero_warns() -> void:
	# cooling is a dead-data key for enemies (TBC Rule 8: no enemy heat system).
	var e := _wild()
	e.stats["cooling"] = 12
	var r := _run([e])
	assert_true(_warned(&"content_enemy_stat_dead_data"),
		"cooling=12 → content_enemy_stat_dead_data warning")
	assert_true(r["ok"], "dead-data warning is ADVISORY — result is still ok")


func test_energy_capacity_nonzero_warns() -> void:
	var e := _wild()
	e.stats["energy_capacity"] = 50
	var r := _run([e])
	assert_true(_warned(&"content_enemy_stat_dead_data"),
		"energy_capacity=50 → content_enemy_stat_dead_data warning")
	assert_true(r["ok"], "advisory only")


func test_recharge_nonzero_warns() -> void:
	var e := _wild()
	e.stats["recharge"] = 5
	var r := _run([e])
	assert_true(_warned(&"content_enemy_stat_dead_data"),
		"recharge=5 → content_enemy_stat_dead_data warning")
	assert_true(r["ok"], "advisory only")


func test_dead_data_all_zero_no_warnings() -> void:
	# The canonical authored state: cooling=0, energy_capacity=0, recharge=0 →
	# no dead-data warnings. This is the "clean 11-stat block" case.
	var e := _wild()  # Already has all dead-data keys at 0.
	_run([e])
	assert_false(_warned(&"content_enemy_stat_dead_data"),
		"dead-data keys all 0 → no dead-data warning")
