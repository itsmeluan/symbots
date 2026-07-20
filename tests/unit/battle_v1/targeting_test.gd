## Targeting + the Taunt rule (Core Design §3.3).
##
## The taunt rule is the system that makes TANK a role, so its exceptions get the most
## coverage here — a tank wall with no way through is a wall, and a tank wall that leaks
## is not a tank. Each exception has its own test rather than being folded into one, so a
## regression names which exception broke.
extends GutTest

const BattleTargetingScript := preload("res://src/core/battle_v1/targeting.gd")
const SkillDefScript := preload("res://src/core/battle_v1/skill_def.gd")
const StatusEffectScript := preload("res://src/core/battle_v1/status_effect.gd")
const SpeciesDefScript := preload("res://src/core/species/species_def.gd")


func _unit(name: String, role: int, side: int, hp: int = 100, slot: int = 0) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = StringName(name)
	u.display_name = name
	u.role = role
	u.side = side
	u.slot = slot
	u.max_structure = hp
	u.current_structure = hp
	u.base_stats = {&"mobility": 10, &"physical_power": 50}
	return u


func _skill(mode: int, pierce: bool = false) -> SkillDef:
	var s := SkillDef.new()
	s.id = &"probe"
	s.target_mode = mode
	s.ignores_taunt = pierce
	return s


func _dps(n: String, slot: int = 0, hp: int = 100) -> BattleUnit:
	return _unit(n, SpeciesDefScript.Role.DPS, BattleUnit.Side.ENEMY, hp, slot)


func _tank(n: String, slot: int = 0, hp: int = 200) -> BattleUnit:
	return _unit(n, SpeciesDefScript.Role.TANK, BattleUnit.Side.ENEMY, hp, slot)


# ---------------------------------------------------------------------------
# The rule
# ---------------------------------------------------------------------------

func test_single_target_must_hit_the_tank_when_one_lives() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	var enemies := [_tank("tank"), _dps("squishy", 1)]
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ENEMY), [caster], enemies)
	assert_eq(legal.size(), 1, "Only the tank is targetable")
	assert_eq(legal[0].unit_id, &"tank")


func test_whole_line_opens_when_no_tank_is_present() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	var enemies := [_dps("a"), _dps("b", 1)]
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ENEMY), [caster], enemies)
	assert_eq(legal.size(), 2, "With no tank, every living enemy is fair game")


func test_line_opens_once_the_last_tank_dies() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	var tank := _tank("tank")
	var enemies := [tank, _dps("squishy", 1)]
	tank.current_structure = 0
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ENEMY), [caster], enemies)
	assert_eq(legal.size(), 1, "A dead tank protects nothing")
	assert_eq(legal[0].unit_id, &"squishy")


func test_multiple_tanks_are_all_choosable() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	var enemies := [_tank("t1"), _tank("t2", 1), _dps("squishy", 2)]
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ENEMY), [caster], enemies)
	assert_eq(legal.size(), 2, "The attacker picks freely among living tanks")


# ---------------------------------------------------------------------------
# The four exceptions — one test each, so a break names itself
# ---------------------------------------------------------------------------

func test_exception_pierce_skill_reaches_past_the_tank() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	var enemies := [_tank("tank"), _dps("squishy", 1)]
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ENEMY, true), [caster], enemies)
	assert_eq(legal.size(), 2, "A skill flagged ignores_taunt sees the whole line")


func test_exception_backline_caster_reaches_past_the_tank() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	caster.add_status(StatusEffectScript.pierce(3))
	var enemies := [_tank("tank"), _dps("squishy", 1)]
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ENEMY), [caster], enemies)
	assert_eq(legal.size(), 2, "PIERCE on the CASTER opens the line too, not just on the skill")


func test_exception_taunt_break_opens_the_line_but_keeps_the_tank_targetable() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	var tank := _tank("tank")
	tank.add_status(StatusEffectScript.taunt_break(2))
	var enemies := [tank, _dps("squishy", 1)]
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ENEMY), [caster], enemies)
	assert_eq(legal.size(), 2, "A taunt-broken tank stops compelling attacks")
	assert_true(legal.has(tank), "but is still a legal target — it is still a unit on the field")


func test_exception_aoe_ignores_taunt_by_construction() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	var enemies := [_tank("tank"), _dps("squishy", 1)]
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.ALL_ENEMIES), [caster], enemies)
	assert_eq(legal.size(), 2,
		"An AoE is not CHOOSING a target, so taunt has nothing to redirect — this is what "
		+ "makes area damage the answer to a tank wall")


# ---------------------------------------------------------------------------
# Ally-side and empty cases
# ---------------------------------------------------------------------------

func test_healing_never_targets_the_dead() -> void:
	var caster := _unit("healer", SpeciesDefScript.Role.HEALER, BattleUnit.Side.PLAYER)
	var dead := _unit("down", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER, 100, 1)
	dead.current_structure = 0
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ALLY), [caster, dead], [])
	assert_eq(legal.size(), 1, "A downed ally needs REVIVE, not a heal")


func test_lowest_hp_ally_resolves_to_exactly_one() -> void:
	var healer := _unit("healer", SpeciesDefScript.Role.HEALER, BattleUnit.Side.PLAYER, 100)
	var hurt := _unit("hurt", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER, 100, 1)
	hurt.current_structure = 12
	var legal := BattleTargetingScript.legal_targets(
		healer, _skill(SkillDefScript.TargetMode.LOWEST_HP_ALLY), [healer, hurt], [])
	assert_eq(legal.size(), 1, "The convenience mode resolves without a manual pick")
	assert_eq(legal[0].unit_id, &"hurt")


func test_no_living_enemies_yields_no_targets() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	var dead := _dps("dead")
	dead.current_structure = 0
	var legal := BattleTargetingScript.legal_targets(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ENEMY), [caster], [dead])
	assert_true(legal.is_empty(),
		"Empty means 'unusable this turn' — callers must not assume a target exists")


# ---------------------------------------------------------------------------
# Auto-battle picks
# ---------------------------------------------------------------------------

func test_auto_attacks_the_enemy_closest_to_dying() -> void:
	var caster := _unit("me", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER)
	var a := _dps("healthy", 0, 100)
	var b := _dps("nearly", 1, 100)
	b.current_structure = 7
	var pick = BattleTargetingScript.auto_pick(
		caster, _skill(SkillDefScript.TargetMode.SINGLE_ENEMY), [caster], [a, b])
	assert_eq(pick.unit_id, &"nearly", "Auto finishes what it can — and stays predictable")


func test_auto_heals_the_ally_furthest_from_full_not_the_lowest_total() -> void:
	var healer := _unit("healer", SpeciesDefScript.Role.HEALER, BattleUnit.Side.PLAYER, 100)
	# `big` has more HP left in absolute terms but is missing far more of it.
	var big := _unit("big", SpeciesDefScript.Role.TANK, BattleUnit.Side.PLAYER, 500, 1)
	big.current_structure = 200
	var small := _unit("small", SpeciesDefScript.Role.DPS, BattleUnit.Side.PLAYER, 100, 2)
	small.current_structure = 90
	var pick = BattleTargetingScript.auto_pick(
		healer, _skill(SkillDefScript.TargetMode.SINGLE_ALLY), [healer, big, small], [])
	assert_eq(pick.unit_id, &"big",
		"Healing picks by MISSING health, so a big heal is never wasted on a scratch")
