## Damage-Formula Story 001 — DF-1 pure kernel `DamageFormula.compute_damage`.
##
## Covers QA test cases for AC-DF-01/02/11/12/13/14/15/16/17/18 (the pure kernel:
## inputs are explicit a/d/type_mult/crit_mult — routing is Story 003, chart
## lookup is Story 002) plus the `damage_floor` config field + ContentValidator
## `damage_floor >= 0` guard.
##
## The anchor (53,30,1.5) → 50 is discriminating: round()/ceil() both give 51, and
## the wrong (post-floor type-multiply) order gives 49 — so a single assertion pins
## floor discipline AND pre-floor T. Fixtures confirmed by a python3 IEEE-754 scan
## (see the story Test Evidence): the DF-1 product routes through the existing
## StatMath.floor_eps and introduces no new nudge-flip. Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/damage-formula/spy_log_sink.gd")

var _cfg: BalanceConfig
var _spy


func before_each() -> void:
	# Fresh BalanceConfig — its @export default damage_floor is 1 (DI baseline).
	_cfg = BalanceConfig.new()
	_spy = SpyLogSink.new()


# ---------------------------------------------------------------------------
# AC-DF-01 / AC-DF-02 — floor discipline + pre-floor type multiply (the anchor)
# ---------------------------------------------------------------------------

func test_compute_damage_anchor_floors_not_rounds() -> void:
	# 53²/(53+30) = 33.843… ; ×1.5 = 50.765… ; floor → 50 (round/ceil give 51).
	var got := DamageFormula.compute_damage(53, 30, 1.5, _cfg, _spy, 1.0)
	assert_eq(got, 50, "53²/(53+30) × 1.5 floors to 50")
	assert_ne(got, 51, "must NOT be 51 — round()/ceil() would produce that (wrong)")
	assert_eq(roundi(2809.0 / 83.0 * 1.5), 51, "sanity: round() path is the 51 wrong answer")


func test_compute_damage_type_mult_applied_before_floor() -> void:
	# Wrong order (floor first, then ×1.5): floor(33.843)=33 → 33×1.5=49.5 → 49.
	# Correct pre-floor order gives 50, discriminating the two.
	var got := DamageFormula.compute_damage(53, 30, 1.5, _cfg, _spy, 1.0)
	assert_eq(got, 50, "type_mult applied pre-floor gives 50")
	assert_ne(got, 49, "must NOT be 49 — that is the post-floor (wrong-order) result")


# ---------------------------------------------------------------------------
# AC-DF-11 / AC-DF-12 / AC-DF-13 — zero-input paths (no special case, no divide error)
# ---------------------------------------------------------------------------

func test_compute_damage_zero_attack_returns_floor() -> void:
	# A=0, D=30 → base 0 → pre_floor 0 → max(damage_floor=1, 0) = 1. No special case.
	assert_eq(DamageFormula.compute_damage(0, 30, 1.5, _cfg, _spy), 1,
		"A=0 clamps up to DAMAGE_FLOOR via max()")


func test_compute_damage_zero_defense_no_divide_error() -> void:
	# D=0 → base = 53²/53 = 53.0 ; ×1.5 = 79.5 → floor 79. No divide-by-zero.
	assert_eq(DamageFormula.compute_damage(53, 0, 1.5, _cfg, _spy), 79,
		"D=0 → base equals A (53); ×1.5 floors to 79")


func test_compute_damage_zero_attack_and_defense_guard() -> void:
	# A=0 ∧ D=0 → the guard returns damage_floor BEFORE the 0/0 division (no NaN).
	var got := DamageFormula.compute_damage(0, 0, 1.5, _cfg, _spy)
	assert_eq(got, 1, "A=0 ∧ D=0 returns DAMAGE_FLOOR via the pre-division guard")
	assert_false(is_nan(float(got)), "result is finite — never NaN")
	assert_false(is_inf(float(got)), "result is finite — never infinity")


# ---------------------------------------------------------------------------
# AC-DF-14 / AC-DF-15 — floor activation vs floor-after-floor
# ---------------------------------------------------------------------------

func test_compute_damage_sub_floor_clamps_up() -> void:
	# 4²/(4+80) = 0.1904… ; ×0.75 = 0.1428… ; floor 0 → max(1,0) = 1.
	assert_eq(DamageFormula.compute_damage(4, 80, 0.75, _cfg, _spy), 1,
		"a pre_floor below the floor clamps up to 1")


func test_compute_damage_floor_only_clamps_when_below() -> void:
	# The floor must NOT unconditionally clamp: the (53,30,1.5) anchor stays 50,
	# proving max() only lifts sub-floor results, not every result.
	assert_eq(DamageFormula.compute_damage(53, 30, 1.5, _cfg, _spy), 50,
		"floor clamps only sub-floor pre_floors — 50 passes through, not clamped to 1")


# ---------------------------------------------------------------------------
# AC-DF-16 — determinism
# ---------------------------------------------------------------------------

func test_compute_damage_is_deterministic() -> void:
	# Five identical calls → identical output; the kernel rolls no RNG (ADR-0006).
	for i in range(5):
		assert_eq(DamageFormula.compute_damage(53, 30, 1.5, _cfg, _spy, 1.0), 50,
			"call %d returns 50 — no variance" % i)


# ---------------------------------------------------------------------------
# AC-DF-17 / AC-DF-18 — crit multiplier is injectable and pre-floor
# ---------------------------------------------------------------------------

func test_compute_damage_crit_one_is_neutral() -> void:
	# crit_mult=1.0 has no gameplay effect — identical to the un-multiplied anchor.
	assert_eq(DamageFormula.compute_damage(53, 30, 1.5, _cfg, _spy, 1.0), 50,
		"crit_mult=1.0 is a true identity")


func test_compute_damage_crit_applied_before_floor() -> void:
	# 33.843… × 1.5 × 2.0 = 101.53… → floor 101 (post-floor order 50×2=100 is wrong).
	var got := DamageFormula.compute_damage(53, 30, 1.5, _cfg, _spy, 2.0)
	assert_eq(got, 101, "crit_mult applied pre-floor gives 101")
	assert_ne(got, 100, "must NOT be 100 — that is the post-floor (wrong-order) result")


func test_compute_damage_crit_defaults_to_one() -> void:
	# The parameter is optional (default 1.0): omitting it equals passing 1.0.
	assert_eq(
		DamageFormula.compute_damage(53, 30, 1.5, _cfg, _spy),
		DamageFormula.compute_damage(53, 30, 1.5, _cfg, _spy, 1.0),
		"omitted crit_mult defaults to 1.0")


# ---------------------------------------------------------------------------
# damage_floor honoured from config (not hardcoded)
# ---------------------------------------------------------------------------

func test_compute_damage_honours_configured_floor() -> void:
	# The floor is data-driven: a config floor of 5 lifts a sub-floor result to 5.
	_cfg.damage_floor = 5
	assert_eq(DamageFormula.compute_damage(4, 80, 0.75, _cfg, _spy), 5,
		"sub-floor result clamps up to the CONFIGURED damage_floor (5), not a literal 1")


# ---------------------------------------------------------------------------
# ContentValidator — damage_floor >= 0 guard (config-level balance family)
# ---------------------------------------------------------------------------

func _validate_with_floor(value: int) -> Dictionary:
	_cfg.damage_floor = value
	var catalogs := ContentCatalogs.new()
	catalogs.parts = PartCatalog.new()  # empty catalog — config-level check runs regardless
	catalogs.balance = _cfg
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


func test_validator_accepts_non_negative_damage_floor() -> void:
	var r := _validate_with_floor(1)
	assert_false(_logged(&"content_balance_damage_floor_negative"),
		"a damage_floor of 1 is valid — no error")
	assert_true(r["ok"], "clean config validates ok")


func test_validator_rejects_negative_damage_floor() -> void:
	var r := _validate_with_floor(-1)
	assert_true(_logged(&"content_balance_damage_floor_negative"),
		"a negative damage_floor is rejected")
	assert_false(r["ok"], "negative floor fails validation")
