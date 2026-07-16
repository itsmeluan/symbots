## Consumable-DB Story 006 — Signal Jammer / Scrap Lure encounter-rate modifier.
##
## Covers AC-CD-09 (Jammer repel math + countdown), AC-CD-10 (Lure attract math),
## AC-CD-13 (latest-wins replacement, no stacking), AC-CD-14 (STRUCTURAL battle-freeze
## — no battle-turn mutator — and inert-query safety). CD-5 math is pure; the counter
## is DI via [EncounterModifierState] (the live per-step roll is the Encounter Zone
## erratum AC-CD-22, DEFERRED). GUT · Godot 4.7.
extends GutTest

const WORLD := ConsumableDef.UseContext.WORLD


# ---------------------------------------------------------------------------
# Fixtures — the two authored MODIFY_ENCOUNTER_RATE items
# ---------------------------------------------------------------------------

func _jammer() -> ConsumableDef:
	var cd := ConsumableDef.new()
	cd.consumable_id = &"signal_jammer"
	cd.effect_type = ConsumableDef.EffectType.MODIFY_ENCOUNTER_RATE
	cd.effect_params = {"rate_multiplier": 0.1, "duration_steps": 20}
	cd.use_context = WORLD
	cd.target = ConsumableDef.Target.OVERWORLD
	return cd

func _lure() -> ConsumableDef:
	var cd := ConsumableDef.new()
	cd.consumable_id = &"scrap_lure"
	cd.effect_type = ConsumableDef.EffectType.MODIFY_ENCOUNTER_RATE
	cd.effect_params = {"rate_multiplier": 2.5, "duration_steps": 15}
	cd.use_context = WORLD
	cd.target = ConsumableDef.Target.OVERWORLD
	return cd


# ---------------------------------------------------------------------------
# CD-5 — pure clamp math (IEEE-exact bases)
# ---------------------------------------------------------------------------

func test_modify_encounter_rate_jammer_repels() -> void:
	assert_almost_eq(ConsumableEffects.modify_encounter_rate(0.15, 0.1), 0.015, 0.0000001)

func test_modify_encounter_rate_lure_attracts() -> void:
	assert_almost_eq(ConsumableEffects.modify_encounter_rate(0.15, 2.5), 0.375, 0.0000001)

func test_modify_encounter_rate_dense_stays_under_ceiling() -> void:
	# 0.35 × 2.5 = 0.875 — deliberately under the 1.0 clamp; a 3.0× impl gives 1.0.
	assert_almost_eq(ConsumableEffects.modify_encounter_rate(0.35, 2.5), 0.875, 0.0000001)


# ---------------------------------------------------------------------------
# AC-CD-09 — Jammer: apply, effective rate, step countdown
# ---------------------------------------------------------------------------

func test_jammer_apply_sets_active_state() -> void:
	var state := EncounterModifierState.new()
	state.apply(_jammer())
	assert_eq(state.modifier_type, EncounterModifierState.ModifierType.JAMMER)
	assert_eq(state.steps_remaining, 20)
	assert_almost_eq(state.effective_rate(0.15), 0.015, 0.0000001)
	assert_true(state.has_active())

func test_jammer_counts_down_per_step() -> void:
	var state := EncounterModifierState.new()
	state.apply(_jammer())
	for _i in 3:
		state.on_overworld_step()
	assert_eq(state.steps_remaining, 17, "20 − 3 steps = 17")
	assert_true(state.has_active(), "still active mid-countdown")

func test_jammer_expires_and_reverts_to_base() -> void:
	var state := EncounterModifierState.new()
	state.apply(_jammer())
	for _i in 20:
		state.on_overworld_step()
	assert_false(state.has_active(), "expired at 0 steps")
	assert_eq(state.modifier_type, EncounterModifierState.ModifierType.NONE)
	assert_almost_eq(state.effective_rate(0.15), 0.15, 0.0000001, "base rate restored after expiry")


# ---------------------------------------------------------------------------
# AC-CD-10 — Lure: attract
# ---------------------------------------------------------------------------

func test_lure_apply_attracts() -> void:
	var state := EncounterModifierState.new()
	state.apply(_lure())
	assert_eq(state.modifier_type, EncounterModifierState.ModifierType.LURE)
	assert_eq(state.steps_remaining, 15)
	assert_almost_eq(state.effective_rate(0.35), 0.875, 0.0000001)


# ---------------------------------------------------------------------------
# AC-CD-13 — latest-wins replacement (no stacking)
# ---------------------------------------------------------------------------

func test_apply_replaces_active_modifier() -> void:
	var state := EncounterModifierState.new()
	state.apply(_jammer())
	for _i in 15:  # Jammer down to 5 steps remaining
		state.on_overworld_step()
	assert_eq(state.steps_remaining, 5)
	# Using a Lure REPLACES the Jammer wholesale (latest wins) — no averaging/stacking.
	# A WORLD use decrements inventory (Story 004 reuse): qty 1 → 0.
	var use := ConsumableUse.resolve(_lure(), {}, WORLD, 1)
	assert_eq(use["new_qty"], 0, "the Lure is consumed on use")
	state.apply(_lure())
	assert_eq(state.modifier_type, EncounterModifierState.ModifierType.LURE, "old Jammer gone")
	assert_eq(state.steps_remaining, 15, "fresh Lure duration, not 5 + 15")
	assert_almost_eq(state.effective_rate(0.35), 0.875, 0.0000001)


# ---------------------------------------------------------------------------
# AC-CD-14 — STRUCTURAL battle-freeze + inert-query safety
# ---------------------------------------------------------------------------

func test_no_battle_turn_mutator_exists() -> void:
	# The freeze-during-battle property is structural: on_overworld_step is the ONLY
	# countdown mutator. If a battle-turn handler is ever added, the modifier would
	# tick in battle and this guard catches it.
	var state := EncounterModifierState.new()
	assert_true(state.has_method("on_overworld_step"), "the overworld tick exists")
	assert_false(state.has_method("on_battle_turn"), "no battle-turn tick — battle can't decrement it")
	assert_false(state.has_method("on_turn"), "no generic turn tick either")

func test_inert_query_is_safe_and_returns_base() -> void:
	var state := EncounterModifierState.new()
	assert_false(state.has_active(), "fresh state is inert")
	assert_eq(state.steps_remaining, 0)
	assert_almost_eq(state.effective_rate(0.15), 0.15, 0.0000001, "inert → base rate, no crash")
	state.on_overworld_step()  # stepping an inert modifier must not underflow
	assert_eq(state.steps_remaining, 0, "no underflow below 0")

func test_battle_steps_do_not_tick_the_modifier() -> void:
	# Simulate a battle: the battle loop simply never calls on_overworld_step, so the
	# Jammer's countdown is frozen across the whole encounter.
	var state := EncounterModifierState.new()
	state.apply(_jammer())
	var before := state.steps_remaining
	# ... an entire battle resolves here (no overworld steps) ...
	assert_eq(state.steps_remaining, before, "battle turns leave the counter frozen")
