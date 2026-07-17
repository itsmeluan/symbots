## DS-8 Scrap-yield & rarity-ordering-invariant spec (Drop System Story 008).
##
## `DropSystem.get_scrap_yield(rarity)` vends the Rule 9 per-rarity Scrap yield from
## the injected BalanceConfig's `@export` defaults.
##   AC-DS-19 four EXACT values (5 / 20 / 35 / 60) AND the three ordering booleans
##            (COMMON < RARE < PROTOTYPE < BOSS_GRADE) asserted programmatically —
##            an inverted step (e.g. Prototype ≥ Boss-grade) must fail the build.
##
## The ordering is deliberately NOT numeric-rarity-index order: Prototype's yield (35)
## sits between Rare (20) and Boss-grade (60).
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const Rng := preload("res://tests/unit/drop_system/rng_doubles.gd")

var _ds: DropSystem


func before_each() -> void:
	# Yields come from BalanceConfig `@export` defaults — a bare .new() is the DI source.
	_ds = DropSystem.new(Rng.Const.new(0.0), BalanceConfig.new(), SpyLogSink.new(), null)


# --- AC-DS-19: exact per-rarity values ---
func test_scrap_yield_values_per_rarity() -> void:
	assert_eq(_ds.get_scrap_yield(PartDef.Rarity.COMMON), 5, "Common scraps for 5")
	assert_eq(_ds.get_scrap_yield(PartDef.Rarity.RARE), 20, "Rare scraps for 20")
	assert_eq(_ds.get_scrap_yield(PartDef.Rarity.PROTOTYPE), 35, "Prototype scraps for 35")
	assert_eq(_ds.get_scrap_yield(PartDef.Rarity.BOSS_GRADE), 60, "Boss-grade scraps for 60")


# --- AC-DS-19: ordering invariant COMMON < RARE < PROTOTYPE < BOSS_GRADE ---
func test_scrap_yield_ordering_invariant_holds() -> void:
	# Evaluated as `<` comparisons, NOT documented in a comment — an inverted retune
	# (e.g. Prototype ≥ Boss-grade, rewarding the scrapping of a rarer part) fails here.
	var common := _ds.get_scrap_yield(PartDef.Rarity.COMMON)
	var rare := _ds.get_scrap_yield(PartDef.Rarity.RARE)
	var proto := _ds.get_scrap_yield(PartDef.Rarity.PROTOTYPE)
	var boss := _ds.get_scrap_yield(PartDef.Rarity.BOSS_GRADE)

	assert_true(common < rare, "COMMON (%d) < RARE (%d)" % [common, rare])
	assert_true(rare < proto, "RARE (%d) < PROTOTYPE (%d)" % [rare, proto])
	assert_true(proto < boss, "PROTOTYPE (%d) < BOSS_GRADE (%d)" % [proto, boss])
