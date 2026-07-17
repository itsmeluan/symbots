## TBC Story 003 — move-panel availability (pure query over frozen pool + live energy).
##
## Covers AC-TBC-06 (a slot is available iff it is non-null AND current_energy ≥ its cost),
## AC-TBC-21 (Basic Attack, cost 0, is ALWAYS available; empty slots surface as null and
## never throw). Pure static method — no battle context. Framework: GUT · Godot 4.7.
extends GutTest


func _move(id: StringName, cost: int) -> MoveDef:
	var m := MoveDef.new()
	m.id = id
	m.behavior = MoveDef.Behavior.DAMAGE
	m.energy_cost = cost
	return m


func _pool() -> Array:
	# [basic_attack(0), WEAPON(25), HEAD empty, ARMS(40)]
	return [_move(&"basic_attack", 0), _move(&"storm_lance", 25), null, _move(&"aegis_pulse", 40)]


# ---------------------------------------------------------------------------
# AC-TBC-06 — availability gated on current_energy ≥ cost
# ---------------------------------------------------------------------------

func test_availability_tracks_energy_threshold() -> void:
	# Energy 30 covers basic(0) and storm_lance(25) but NOT aegis_pulse(40).
	var panel := BattleController.move_panel_state(_pool(), 30)

	assert_eq(panel.size(), 4, "one entry per slot, order preserved")
	assert_true(panel[0]["available"], "basic_attack (cost 0) available")
	assert_true(panel[1]["available"], "storm_lance cost 25 ≤ energy 30 → available")
	assert_eq(panel[1]["cost"], 25, "cost surfaced for the panel")
	assert_null(panel[2], "the empty HEAD slot is null, not a crash")
	assert_false(panel[3]["available"], "aegis_pulse cost 40 > energy 30 → unavailable")


func test_exact_cost_is_affordable() -> void:
	# Boundary: energy exactly equals cost → available (≥, not >).
	var panel := BattleController.move_panel_state([_move(&"x", 40)], 40)
	assert_true(panel[0]["available"], "energy == cost is affordable")


# ---------------------------------------------------------------------------
# AC-TBC-21 — Basic Attack always available, even at zero energy
# ---------------------------------------------------------------------------

func test_basic_attack_available_at_zero_energy() -> void:
	var panel := BattleController.move_panel_state(_pool(), 0)

	assert_true(panel[0]["available"], "Basic Attack (cost 0) is available at 0 energy")
	assert_false(panel[1]["available"], "a costed move is not")
	assert_null(panel[2], "empty slot still null at 0 energy")
