## Damage-Formula Story 002 — `DamageFormula.type_effectiveness` chart lookup.
##
## Covers AC-DF-08 (the full 9-cell VOLT/THERMAL/KINETIC matrix), AC-DF-09 (null /
## unknown target Core → neutral ×1.0), AC-DF-10 (null skill → neutral ×1.0, NOT the
## ×1.5 super-effective result), the nested typed-Dictionary `.tres` round-trip
## (shared gate with `chassis_modifiers`), and the ContentValidator shape family
## (`content_balance_type_chart_malformed`). The three distinct ratios {0.75, 1.0,
## 1.5} are self-discriminating — a swapped cell fails a specific assertion.
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/damage-formula/spy_log_sink.gd")

const VOLT := PartDef.Element.VOLT
const THERMAL := PartDef.Element.THERMAL
const KINETIC := PartDef.Element.KINETIC

var _cfg: BalanceConfig
var _spy


func before_each() -> void:
	# Fresh BalanceConfig — its @export default type_chart is the locked Rule 6 grid.
	_cfg = BalanceConfig.new()
	_spy = SpyLogSink.new()


# ---------------------------------------------------------------------------
# AC-DF-08 — all 9 cells return the correct locked Rule 6 multiplier
# ---------------------------------------------------------------------------

func test_type_effectiveness_full_matrix_matches_rule6() -> void:
	# (skill → core) → expected multiplier, per the AC-DF-08 table. VOLT beats THERMAL,
	# THERMAL beats KINETIC, KINETIC beats VOLT; the reverse is resisted; same is neutral.
	var expected := {
		VOLT:    {VOLT: 1.0, THERMAL: 1.5, KINETIC: 0.75},
		THERMAL: {VOLT: 0.75, THERMAL: 1.0, KINETIC: 1.5},
		KINETIC: {VOLT: 1.5, THERMAL: 0.75, KINETIC: 1.0},
	}
	for skill in expected:
		for core in expected[skill]:
			var got := DamageFormula.type_effectiveness(skill, core, _cfg)
			assert_almost_eq(got, float(expected[skill][core]), 0.0001,
				"type_effectiveness(%d, %d) should be %s" % [skill, core, expected[skill][core]])


func test_type_effectiveness_super_effective_is_not_resisted() -> void:
	# Discriminating pair: the super/resisted directions must not be swapped.
	assert_almost_eq(DamageFormula.type_effectiveness(VOLT, THERMAL, _cfg), 1.5, 0.0001,
		"VOLT → THERMAL is super-effective ×1.5")
	assert_almost_eq(DamageFormula.type_effectiveness(THERMAL, VOLT, _cfg), 0.75, 0.0001,
		"THERMAL → VOLT is resisted ×0.75 (the mirror, not another ×1.5)")


# ---------------------------------------------------------------------------
# AC-DF-09 — null / unrecognized TARGET CORE element → neutral ×1.0
# ---------------------------------------------------------------------------

func test_type_effectiveness_null_core_is_neutral() -> void:
	# A Core with no element (null) must degrade to ×1.0 — never throw, never ×1.5.
	assert_almost_eq(DamageFormula.type_effectiveness(VOLT, null, _cfg), 1.0, 0.0001,
		"null target Core → neutral ×1.0 (VOLT does NOT super-effective a null)")


func test_type_effectiveness_reserved_core_is_neutral() -> void:
	# A Full-Vision reserved element (CRYO=4) has no authored column → ×1.0, no throw.
	assert_almost_eq(DamageFormula.type_effectiveness(VOLT, PartDef.Element.CRYO, _cfg), 1.0, 0.0001,
		"unknown / reserved target Core element → neutral ×1.0")


# ---------------------------------------------------------------------------
# AC-DF-10 — null / unrecognized SKILL element → neutral ×1.0 (NOT ×1.5)
# ---------------------------------------------------------------------------

func test_type_effectiveness_null_skill_is_neutral() -> void:
	# A skill with no element must be neutral — the nested .get() default fires on the
	# OUTER miss, so it must return 1.0, never the ×1.5 that THERMAL's attacker would get.
	var got := DamageFormula.type_effectiveness(null, THERMAL, _cfg)
	assert_almost_eq(got, 1.0, 0.0001, "null skill element → neutral ×1.0")
	assert_ne(got, 1.5, "must NOT be 1.5 — a null skill is neutral, not super-effective")


func test_type_effectiveness_null_both_sides_is_neutral() -> void:
	# Degenerate double-null still resolves cleanly to ×1.0 (no throw, no NaN).
	assert_almost_eq(DamageFormula.type_effectiveness(null, null, _cfg), 1.0, 0.0001,
		"null skill AND null core → neutral ×1.0")


# ---------------------------------------------------------------------------
# type_chart .tres round-trip — nested typed-Dictionary survives load
# ---------------------------------------------------------------------------

func test_type_chart_survives_tres_round_trip() -> void:
	# The authored production .tres must deserialize the nested Dictionary intact —
	# this is the real serialization gate (the DI default is NOT what ships).
	var loaded: BalanceConfig = load("res://assets/data/balance_config.tres")
	assert_not_null(loaded, "balance_config.tres loads as a BalanceConfig")
	assert_almost_eq(float(loaded.type_chart[VOLT][THERMAL]), 1.5, 0.0001,
		"type_chart[VOLT][THERMAL] survives .tres load as 1.5")
	assert_almost_eq(float(loaded.type_chart[THERMAL][VOLT]), 0.75, 0.0001,
		"type_chart[THERMAL][VOLT] survives .tres load as 0.75")


func test_type_effectiveness_reads_authored_tres() -> void:
	# End-to-end: the lookup function against the loaded production config agrees
	# with the kernel-default config (proves the authored data == the locked ratios).
	var loaded: BalanceConfig = load("res://assets/data/balance_config.tres")
	assert_almost_eq(DamageFormula.type_effectiveness(KINETIC, VOLT, loaded), 1.5, 0.0001,
		"KINETIC → VOLT reads ×1.5 from the authored .tres")


# ---------------------------------------------------------------------------
# ContentValidator — type_chart shape family (content_balance_type_chart_malformed)
# ---------------------------------------------------------------------------

func _validate(cfg: BalanceConfig) -> Dictionary:
	_spy = SpyLogSink.new()
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()  # empty catalog — config-level check runs regardless
	catalogs.balance = cfg
	return ContentValidator.new().validate(catalogs, _spy)


func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


func test_validator_accepts_locked_type_chart() -> void:
	# The default grid is the locked Rule 6 set — a clean config validates silently.
	var r := _validate(_cfg)
	assert_false(_logged(&"content_balance_type_chart_malformed"),
		"the locked default type_chart is well-formed — no error")
	assert_true(r["ok"], "clean config validates ok")


func test_validator_rejects_out_of_set_cell() -> void:
	# A drifted / typo'd ratio (2.0 ∉ {0.75, 1.0, 1.5}) is a hard error.
	_cfg.type_chart = {
		VOLT:    {VOLT: 1.0, THERMAL: 2.0, KINETIC: 0.75},  # 2.0 is illegal
		THERMAL: {VOLT: 0.75, THERMAL: 1.0, KINETIC: 1.5},
		KINETIC: {VOLT: 1.5, THERMAL: 0.75, KINETIC: 1.0},
	}
	var r := _validate(_cfg)
	assert_true(_logged(&"content_balance_type_chart_malformed"),
		"an out-of-set cell (2.0) is rejected")
	assert_false(r["ok"], "malformed type_chart fails validation")


func test_validator_rejects_missing_cell() -> void:
	# A cell absent from an otherwise-present row would silently read ×1.0 at runtime
	# — the validator must catch the authoring gap instead.
	_cfg.type_chart = {
		VOLT:    {VOLT: 1.0, KINETIC: 0.75},  # THERMAL cell missing
		THERMAL: {VOLT: 0.75, THERMAL: 1.0, KINETIC: 1.5},
		KINETIC: {VOLT: 1.5, THERMAL: 0.75, KINETIC: 1.0},
	}
	var r := _validate(_cfg)
	assert_true(_logged(&"content_balance_type_chart_malformed"),
		"a missing cell is rejected")
	assert_false(r["ok"], "incomplete type_chart fails validation")


func test_validator_rejects_missing_row() -> void:
	# An entire skill row absent (not a Dictionary) is malformed, not a silent skip.
	_cfg.type_chart = {
		THERMAL: {VOLT: 0.75, THERMAL: 1.0, KINETIC: 1.5},
		KINETIC: {VOLT: 1.5, THERMAL: 0.75, KINETIC: 1.0},
	}  # VOLT row missing entirely
	var r := _validate(_cfg)
	assert_true(_logged(&"content_balance_type_chart_malformed"),
		"a missing skill row is rejected")
	assert_false(r["ok"], "type_chart missing a row fails validation")
