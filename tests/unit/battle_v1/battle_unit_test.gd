## BattleUnit state + TurnOrder (Core Design §3.2, §3.5).
##
## The invariants here are the ones whose violation is INVISIBLE in play: a stat that
## drifts after a buff cycle, a shield that quietly heals, a heal that reports success
## when it overhealed. Each gets an explicit test because none of them produce a crash.
extends GutTest

const StatusEffectScript := preload("res://src/core/battle_v1/status_effect.gd")
const TurnOrderScript := preload("res://src/core/battle_v1/turn_order.gd")
const SpeciesDefScript := preload("res://src/core/species/species_def.gd")


func _unit(hp: int = 100, mobility: int = 10, side: int = BattleUnit.Side.PLAYER,
		slot: int = 0) -> BattleUnit:
	var u := BattleUnit.new()
	u.side = side
	u.slot = slot
	u.max_structure = hp
	u.current_structure = hp
	u.base_stats = {&"mobility": mobility, &"physical_power": 100}
	return u


# ---------------------------------------------------------------------------
# Stats are read through effects, never rewritten
# ---------------------------------------------------------------------------

func test_stat_returns_the_base_when_no_effects_are_active() -> void:
	assert_eq(_unit().stat(&"physical_power"), 100)


func test_buff_then_expiry_restores_the_exact_original_value() -> void:
	# Arrange
	var u := _unit()
	var before := u.stat(&"physical_power")

	# Act — apply, then let it run out
	u.add_status(StatusEffectScript.attack_up(50, 1))
	var buffed := u.stat(&"physical_power")
	u.tick_statuses()

	# Assert
	assert_eq(buffed, 150, "+50% of 100")
	assert_eq(u.stat(&"physical_power"), before,
		"An expired buff must restore the ORIGINAL value, not base-minus-what-was-added")


func test_overlapping_buffs_do_not_drift_after_partial_expiry() -> void:
	# The drift case: two buffs, one expires. A subtract-on-expire implementation leaves
	# the wrong number here and nothing in the game reports it.
	var u := _unit()
	u.add_status(StatusEffectScript.attack_up(50, 1))
	u.add_status(StatusEffectScript.attack_up(30, 5))
	assert_eq(u.stat(&"physical_power"), 180, "Percentages sum before applying")

	u.tick_statuses()
	assert_eq(u.stat(&"physical_power"), 130, "Only the +30% should remain")


func test_stat_never_reads_below_zero() -> void:
	var u := _unit()
	var crush := StatusEffectScript.new(StatusEffectScript.Kind.ATTACK_DOWN, 3, true)
	crush.percent_mods[&"physical_power"] = -500
	u.add_status(crush)
	assert_eq(u.stat(&"physical_power"), 0, "A stat floors at 0 rather than going negative")


# ---------------------------------------------------------------------------
# Damage, shields, healing
# ---------------------------------------------------------------------------

func test_shield_absorbs_before_structure() -> void:
	var u := _unit(100)
	u.add_shield(30)
	var lost := u.take_damage(20)
	assert_eq(u.shield, 10)
	assert_eq(u.current_structure, 100, "Structure is untouched while shield remains")
	assert_eq(lost, 0, "Return value is STRUCTURE lost — a fully absorbed hit lost none")


func test_damage_through_a_broken_shield_spills_into_structure() -> void:
	var u := _unit(100)
	u.add_shield(30)
	var lost := u.take_damage(50)
	assert_eq(u.shield, 0)
	assert_eq(u.current_structure, 80)
	assert_eq(lost, 20, "Only the spill counts, so lifesteal and thorns are not over-credited")


func test_overkill_reports_only_the_structure_that_existed() -> void:
	var u := _unit(30)
	var lost := u.take_damage(999)
	assert_eq(u.current_structure, 0)
	assert_eq(lost, 30, "A 999 hit on a 30-HP unit destroyed 30, not 999")


func test_healing_reports_zero_when_it_overheals() -> void:
	var u := _unit(100)
	u.current_structure = 95
	assert_eq(u.heal(50), 5, "An overheal reports what it actually restored")
	assert_eq(u.current_structure, 100)


func test_the_dead_cannot_be_healed() -> void:
	var u := _unit(100)
	u.current_structure = 0
	assert_eq(u.heal(50), 0, "A downed unit needs REVIVE — heal must not resurrect it")
	assert_eq(u.current_structure, 0)


func test_cleanse_strips_debuffs_and_spares_buffs() -> void:
	var u := _unit()
	u.add_status(StatusEffectScript.burn(5, 3))
	u.add_status(StatusEffectScript.attack_up(20, 3))
	assert_eq(u.cleanse(), 1, "Exactly one debuff removed")
	assert_eq(u.stat(&"physical_power"), 120, "The buff survived — a cleanse is not a reset")


# ---------------------------------------------------------------------------
# Cooldowns
# ---------------------------------------------------------------------------

func test_a_skill_on_cooldown_becomes_ready_after_its_turns() -> void:
	var u := _unit()
	u.put_on_cooldown(&"blast", 2)
	assert_false(u.is_skill_ready(&"blast"))
	u.tick_cooldowns()
	assert_false(u.is_skill_ready(&"blast"), "Still one turn to go")
	u.tick_cooldowns()
	assert_true(u.is_skill_ready(&"blast"))


# ---------------------------------------------------------------------------
# Turn order
# ---------------------------------------------------------------------------

func test_faster_units_act_first_regardless_of_side() -> void:
	var slow_ally := _unit(100, 5, BattleUnit.Side.PLAYER, 0)
	var fast_enemy := _unit(100, 20, BattleUnit.Side.ENEMY, 0)
	var order = TurnOrderScript.for_round([slow_ally], [fast_enemy])
	assert_eq(order[0], fast_enemy, "Speed decides, not side")


func test_speed_ties_break_toward_the_player() -> void:
	var ally := _unit(100, 10, BattleUnit.Side.PLAYER, 0)
	var enemy := _unit(100, 10, BattleUnit.Side.ENEMY, 0)
	var order = TurnOrderScript.for_round([ally], [enemy])
	assert_eq(order[0], ally,
		"A tie the player loses invisibly reads as the game cheating — and a fixed rule "
		+ "is what lets a seed replay identically")


func test_the_dead_are_not_in_the_order() -> void:
	var alive := _unit(100, 10, BattleUnit.Side.PLAYER, 0)
	var dead := _unit(100, 99, BattleUnit.Side.PLAYER, 1)
	dead.current_structure = 0
	var order = TurnOrderScript.for_round([alive, dead], [])
	assert_eq(order.size(), 1, "A destroyed unit takes no turn even at top speed")


func test_slow_pushes_a_unit_down_the_order() -> void:
	var a := _unit(100, 20, BattleUnit.Side.PLAYER, 0)
	var b := _unit(100, 15, BattleUnit.Side.PLAYER, 1)
	assert_eq(TurnOrderScript.for_round([a, b], [])[0], a, "Baseline: a is faster")

	a.add_status(StatusEffectScript.slow(50, 2))
	assert_eq(TurnOrderScript.for_round([a, b], [])[0], b,
		"Slow feeds through stat() into ordering — 20 becomes 10, below b's 15")


func test_unit_builder_carries_the_level_onto_the_unit() -> void:
	# Arrange: a minimal species; Act: build a level-12 wild from it.
	var species := SpeciesDef.new()
	species.id = &"testbot"
	species.display_name = "Testbot"
	species.base_stats = {&"structure": 100, &"mobility": 10}
	var unit := UnitBuilder.build_enemy(species, 12, BattleUnit.Side.ENEMY, 0, {})

	# Assert: the display level survives the build — the nameplate reads it.
	assert_eq(unit.level, 12)
