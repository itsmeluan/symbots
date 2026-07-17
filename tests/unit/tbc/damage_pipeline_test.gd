## TBC Story 008 — DAMAGE pipeline SYN-F4 → DF-1 → MOVE-F1 → Stagger (TBC-F5).
##
## Covers AC-TBC-22 (SYN-F4 both sides, incl. the SYN-F4-skipped and synergy-on-enemy
## FAIL traps + the VOLT type sub-fixture), AC-TBC-26 (TBC-F5 two-step floor, applied
## through the live pipeline via a Staggered attacker), AC-TBC-28 (DF-1 extended range).
## Every worked value is discriminating: a round()/ceil() build lands a different int.
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()


# --- fixtures -------------------------------------------------------------

func _damage_move(tier: MoveDef.PowerTier, dmg_type: PartDef.DamageType,
		element: PartDef.Element) -> MoveDef:
	var m := MoveDef.new()
	m.id = &"test_move"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = tier
	m.damage_type = dmg_type
	m.element = element
	return m


# ---------------------------------------------------------------------------
# AC-TBC-22 — SYN-F4 applies to BOTH sides before DF-1
# ---------------------------------------------------------------------------

func test_synf4_composes_attacker_power_before_df1() -> void:
	# Symbot phys_power 90 + frozen synergy {physical_power:25} → effective A = 115.
	var atk := Combatant.make_player(0, 0, {&"physical_power": 90}, {&"physical_power": 25}, {},
		PartDef.Element.KINETIC)
	# Enemy armor 55, no synergy → D = 55; KINETIC core → T = 1.0 vs KINETIC skill.
	var enemy := Combatant.make_enemy(&"husk", {&"armor": 55}, PartDef.Element.KINETIC)
	var move := _damage_move(MoveDef.PowerTier.STANDARD, PartDef.DamageType.PHYSICAL,
		PartDef.Element.KINETIC)

	var dmg := DamagePipeline.resolve_move_damage(atk, enemy, move, _cfg, _log)
	assert_eq(dmg, 77, "floor(115²/170) = 77 — SYN-F4 raised A 90→115")
	# FAIL traps: SYN-F4-skipped (A=90 → 55) and synergy-on-enemy-defense both diverge.
	assert_ne(dmg, 55, "55 would mean SYN-F4 was skipped on the attacker")


func test_type_effectiveness_sub_fixture_volt_core() -> void:
	# Same A=115/D=55, but a VOLT enemy core → KINETIC skill is super-effective T=1.5.
	var atk := Combatant.make_player(0, 0, {&"physical_power": 90}, {&"physical_power": 25}, {},
		PartDef.Element.KINETIC)
	var enemy := Combatant.make_enemy(&"arc", {&"armor": 55}, PartDef.Element.VOLT)
	var move := _damage_move(MoveDef.PowerTier.STANDARD, PartDef.DamageType.PHYSICAL,
		PartDef.Element.KINETIC)

	var dmg := DamagePipeline.resolve_move_damage(atk, enemy, move, _cfg, _log)
	assert_eq(dmg, 116, "floor(77.7941×1.5) = 116 (round/ceil → 117)")


# ---------------------------------------------------------------------------
# AC-TBC-26 — TBC-F5 two-step reduction, applied through the live pipeline
# ---------------------------------------------------------------------------

func test_staggered_attacker_reduces_own_outgoing_damage() -> void:
	# Attacker Staggered (proc 86 → stagger_pct 21). Same A=115/D=55/T=1.0 → powered 77,
	# then TBC-F5: max(1, floor(77×0.79)) = 60 (round → 61).
	var atk := Combatant.make_player(0, 0, {&"physical_power": 90}, {&"physical_power": 25}, {},
		PartDef.Element.KINETIC)
	atk.statuses.apply(StatusInstance.Type.STAGGER, 86, 2, _cfg)
	var enemy := Combatant.make_enemy(&"husk", {&"armor": 55}, PartDef.Element.KINETIC)
	var move := _damage_move(MoveDef.PowerTier.STANDARD, PartDef.DamageType.PHYSICAL,
		PartDef.Element.KINETIC)

	assert_eq(_cfg.power_tier_multipliers[MoveDef.PowerTier.STANDARD], 1.00,
		"guard: STANDARD tier is the ×1.00 identity")
	var dmg := DamagePipeline.resolve_move_damage(atk, enemy, move, _cfg, _log)
	assert_eq(dmg, 60, "77 → 60 under a 21% Stagger (round → 61)")


func test_tbcf5_two_step_floor_discriminators() -> void:
	# Step 1: proc 86 → 21 (round-half-away → 22). Step 2: 50 @ 21% → 39 (round → 40).
	assert_eq(BattleFormulas.stagger_pct(86, _cfg), 21, "step 1: floor(21.5001) = 21")
	assert_eq(BattleFormulas.apply_stagger(50, 21, _cfg), 39, "step 2: floor(39.5001) = 39")
	# Floor guard: a 1-damage hit under a heavy Stagger stays at 1, never 0.
	assert_eq(BattleFormulas.apply_stagger(1, 27, _cfg), 1, "max(1, floor(0.7301)) = 1")


# ---------------------------------------------------------------------------
# AC-TBC-28 — DF-1 extended range after SYN-F4 (kernel ceilings/floor)
# ---------------------------------------------------------------------------

func test_df1_extended_range_ceilings_and_floor() -> void:
	# Absolute ceiling: A=150 (110 + 40 power budget), D=0, T=1.5 → 225.
	assert_eq(DamageFormula.compute_damage(150, 0, 1.5, _cfg, _log), 225, "A²/A ×1.5 = 225")
	# Realistic ceiling: A=150, D=55, T=1.5 → floor(164.6342…) = 164 (round/ceil → 165).
	assert_eq(DamageFormula.compute_damage(150, 55, 1.5, _cfg, _log), 164, "164, not 165")
	# Minimum: A=1, D=182 (132 + 50 defense budget), T=0.75 → max(1, 0) = 1.
	assert_eq(DamageFormula.compute_damage(1, 182, 0.75, _cfg, _log), 1, "DAMAGE_FLOOR guard")
