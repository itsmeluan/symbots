## TBC Story 009 — sub-target routing, spillover, the hit_resolved hook, TBC-F7 enrage.
##
## Covers AC-TBC-34 Fixture A (STRUCTURE emit — payload damage 60, sub_target STRUCTURE),
## Fixture B (region emit — sub_target "left_arm", NOT the hardcoded default), the
## non-DAMAGE exclusion (Repair/SCAN never emit), and TBC-F7 enemy enrage applied POST-
## Stagger through the resolver with a stubbed broken-region count. Framework: GUT · 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log
var _resolver: BattleResolver
var _events: Array = []


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()
	_resolver = BattleResolver.new(_cfg, _log)
	_events = []
	_resolver.hit_resolved.connect(_on_hit_resolved)


func _on_hit_resolved(move: MoveDef, damage: int, target: Combatant, sub_target: StringName) -> void:
	_events.append({"move": move, "damage": damage, "target": target, "sub_target": sub_target})


func _damage_move() -> MoveDef:
	var m := MoveDef.new()
	m.id = &"test_move"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = PartDef.Element.KINETIC
	return m


# A player attacker Staggered to pct 21, hitting an A=115/D=55/T=1.0 enemy → move_damage 60.
func _staggered_attacker() -> Combatant:
	var atk := Combatant.make_player(0, 0, {&"physical_power": 90}, {&"physical_power": 25}, {},
		PartDef.Element.KINETIC)
	atk.statuses.apply(StatusInstance.Type.STAGGER, 86, 2, _cfg)
	return atk


func _enemy_target() -> Combatant:
	return Combatant.make_enemy(&"husk", {&"armor": 55, &"structure": 200}, PartDef.Element.KINETIC)


# ---------------------------------------------------------------------------
# AC-TBC-34 Fixture A — STRUCTURE hit emits once with damage 60
# ---------------------------------------------------------------------------

func test_structure_hit_emits_once_with_post_stagger_damage() -> void:
	var atk := _staggered_attacker()
	var enemy := _enemy_target()
	var start := enemy.current_structure

	var returned := _resolver.resolve_damage_move(atk, enemy, _damage_move(), BattleResolver.STRUCTURE)

	assert_eq(_events.size(), 1, "hit_resolved fires exactly once")
	assert_eq(_events[0]["damage"], 60, "payload carries post-Stagger 60 (round → 61 FAIL)")
	assert_eq(_events[0]["sub_target"], BattleResolver.STRUCTURE, "sub_target is STRUCTURE")
	assert_eq(returned, 60, "resolver returns the post-Stagger move_damage")
	assert_eq(enemy.current_structure, start - 60, "STRUCTURE hit reduces structure by 60 (PB-F1 identity)")


# ---------------------------------------------------------------------------
# AC-TBC-34 Fixture B — region hit carries the CHOSEN sub_target, not STRUCTURE
# ---------------------------------------------------------------------------

func test_region_hit_emits_chosen_subtarget_and_spills() -> void:
	var atk := _staggered_attacker()
	var enemy := _enemy_target()
	var start := enemy.current_structure

	_resolver.resolve_damage_move(atk, enemy, _damage_move(), &"left_arm")

	assert_eq(_events.size(), 1, "one emit for the region hit")
	assert_eq(_events[0]["sub_target"], &"left_arm", "sub_target is the chosen region, NOT STRUCTURE")
	assert_ne(_events[0]["sub_target"], BattleResolver.STRUCTURE, "hardcoded STRUCTURE would be the trap FAIL")
	# PB-F3 spillover into shared Structure: floor(60 × 0.20) = 12.
	assert_eq(enemy.current_structure, start - 12, "region hit spills floor(60×0.20)=12 into Structure")


# ---------------------------------------------------------------------------
# Non-DAMAGE moves never emit hit_resolved
# ---------------------------------------------------------------------------

func test_repair_and_scan_do_not_emit_hit_resolved() -> void:
	var user := Combatant.make_player(0, 0, {&"energy_power": 45, &"structure": 100}, {}, {}, null)
	var repair := MoveDef.new()
	repair.behavior = MoveDef.Behavior.REPAIR
	repair.energy_cost = 15
	var scan := MoveDef.new()
	scan.behavior = MoveDef.Behavior.SCAN
	scan.energy_cost = 8

	_resolver.resolve_repair_move(user, repair, 8)
	_resolver.resolve_scan_move(user, scan, 6)

	assert_eq(_events.size(), 0, "DAMAGE-free moves never fire the per-hit hook")


# ---------------------------------------------------------------------------
# TBC-F7 enrage — enemy pipeline, POST-Stagger, stubbed broken_region_count
# ---------------------------------------------------------------------------

func test_enemy_enrage_applies_post_stagger_through_resolver() -> void:
	# Enemy attacker phys_power 100 vs player armor 40 → A²/(A+D) = 10000/140 = 71.
	var enemy := Combatant.make_enemy(&"prowler", {&"physical_power": 100}, PartDef.Element.KINETIC)
	var player := Combatant.make_player(0, 0, {&"armor": 40, &"structure": 100}, {}, {},
		PartDef.Element.KINETIC)
	var start := player.current_structure

	# Stubbed broken_region_count = 1 → ×1.12 enrage on the 71 hit → 79.
	var move_damage := _resolver.resolve_damage_move(
		enemy, player, _damage_move(), BattleResolver.STRUCTURE, 1.0, 1)

	assert_eq(move_damage, 71, "hit_resolved payload is the pre-enrage post-Stagger 71")
	assert_eq(_events[0]["damage"], 71, "the emit carries the pre-enrage value")
	assert_eq(player.current_structure, start - 79, "enrage ×1.12: floor(71×1.12)=79 reduces structure")


func test_enrage_identity_and_maxstack_are_discriminating() -> void:
	# count 0 is the identity path; count 3 = ×1.36. Pure-formula cross-check.
	assert_eq(BattleFormulas.enrage_damage(43, 0, _cfg), 43, "count 0 → identity 43")
	assert_eq(BattleFormulas.enrage_damage(43, 1, _cfg), 48, "count 1 → 48 (round/ceil → 49)")
	assert_eq(BattleFormulas.enrage_damage(41, 3, _cfg), 55, "count 3 → 55 (round/ceil → 56)")
