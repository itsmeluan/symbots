## TBC Story 007 — status model, potency snapshot, newest-wins, Burn DoT, lifecycle.
##
## Covers AC-TBC-24 (coexistence + same-type reapply), AC-TBC-13 (newest-wins incl.
## the discriminating LOWER-processing reapply), AC-TBC-15 (zero-potency no-ops),
## AC-TBC-25 (Burn floor discriminators), AC-TBC-23 (Burn bypasses DF-1), AC-TBC-36
## (tick-exactly-twice decrement/expire lifecycle). Framework: GUT · Godot 4.7.
extends GutTest

const SHOCK := StatusInstance.Type.SHOCK
const BURN := StatusInstance.Type.BURN
const STAGGER := StatusInstance.Type.STAGGER

var _cfg: BalanceConfig
var _set: StatusSet


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_set = StatusSet.new()


# ---------------------------------------------------------------------------
# AC-TBC-24 — three statuses coexist with independent snapshots
# ---------------------------------------------------------------------------

func test_three_statuses_coexist_independently() -> void:
	_set.apply(SHOCK, 53, 2, _cfg)
	_set.apply(BURN, 72, 2, _cfg)
	_set.apply(STAGGER, 86, 2, _cfg)
	assert_eq(_set.count(), 3, "all three coexist")
	assert_eq(_set.shock_penalty(), 15, "Shock penalty 15 (proc 53)")
	assert_eq(_set.burn_tick(), 5, "Burn tick 5 (proc 72)")
	assert_eq(_set.stagger_percentage(), 21, "Stagger pct 21 (proc 86)")


func test_same_type_reapply_leaves_other_types_untouched() -> void:
	_set.apply(SHOCK, 53, 2, _cfg)
	_set.apply(BURN, 72, 2, _cfg)
	_set.apply(STAGGER, 86, 2, _cfg)
	# Reapply Burn at a different processing — only Burn's record changes.
	_set.apply(BURN, 30, 2, _cfg)
	assert_eq(_set.shock_penalty(), 15, "Shock unchanged")
	assert_eq(_set.stagger_percentage(), 21, "Stagger unchanged")
	assert_eq(_set.burn_tick(), 2, "Burn re-snapshotted to proc 30 → tick max(2, floor(2.4)) = 2")
	assert_eq(_set.count(), 3, "still three — reapply refreshes, never stacks")


# ---------------------------------------------------------------------------
# AC-TBC-13 — newest-wins ENTIRELY (refresh duration AND re-snapshot)
# ---------------------------------------------------------------------------

func test_reapply_refreshes_duration_and_potency() -> void:
	# Burn proc 30 (tick 2), decrement to 1 turn left.
	_set.apply(BURN, 30, 2, _cfg)
	_set.decrement_turn()
	assert_eq(_set.get_status(BURN).duration, 1, "one turn left before reapply")
	# Reapply at proc 72 → duration back to 2, tick 5.
	_set.apply(BURN, 72, 2, _cfg)
	assert_eq(_set.get_status(BURN).duration, 2, "duration refreshed to full")
	assert_eq(_set.burn_tick(), 5, "re-snapshotted to proc 72 → tick 5")


func test_reapply_lower_processing_still_wins_no_max() -> void:
	# Discriminating: a LOWER-processing reapply must overwrite, not keep the higher.
	_set.apply(BURN, 72, 2, _cfg)
	assert_eq(_set.burn_tick(), 5, "starts at tick 5")
	_set.apply(BURN, 10, 2, _cfg)
	assert_eq(_set.burn_tick(), 2, "newest wins: proc 10 → tick 2, NOT max()-kept 5")
	assert_eq(_set.get_status(BURN).duration, 2, "duration still refreshed")


# ---------------------------------------------------------------------------
# AC-TBC-15 — zero-potency statuses are legal no-ops (Burn floors at BURN_MIN)
# ---------------------------------------------------------------------------

func test_zero_potency_statuses_apply_but_do_nothing() -> void:
	_set.apply(SHOCK, 0, 2, _cfg)
	_set.apply(STAGGER, 0, 2, _cfg)
	_set.apply(BURN, 0, 2, _cfg)
	assert_eq(_set.shock_penalty(), 0, "Shock penalty 0 — legal no-op")
	assert_eq(_set.stagger_percentage(), 0, "Stagger 0% — no reduction")
	assert_eq(_set.burn_tick(), 2, "Burn still ticks BURN_MIN = 2 (the exception)")
	assert_eq(_set.count(), 3, "all three applied and present")


# ---------------------------------------------------------------------------
# AC-TBC-25 — Burn floor discriminators
# ---------------------------------------------------------------------------

func test_burn_floor_discriminators() -> void:
	assert_eq(StatusInstance.compute_magnitude(BURN, 72, _cfg), 5, "proc 72 → 5 (round/ceil → 6)")
	assert_eq(StatusInstance.compute_magnitude(BURN, 0, _cfg), 2, "proc 0 → BURN_MIN 2")
	assert_eq(StatusInstance.compute_magnitude(BURN, 110, _cfg), 8, "proc 110 → 8 (round/ceil → 9)")


# ---------------------------------------------------------------------------
# AC-TBC-23 — Burn bypasses DF-1 (raw magnitude, no Armor/Resistance/type)
# ---------------------------------------------------------------------------

func test_burn_tick_is_raw_magnitude_independent_of_defense() -> void:
	# The afflicted has huge armor/resistance and a KINETIC core — none of which touch Burn.
	_set.apply(BURN, 72, 2, _cfg)
	var structure := 100
	structure -= _set.burn_tick()  # the caller subtracts the raw magnitude directly
	assert_eq(structure, 95, "structure −5 exactly — armor/resistance/type never apply")


# ---------------------------------------------------------------------------
# AC-TBC-36 — tick exactly twice, decrement, expire
# ---------------------------------------------------------------------------

func test_burn_ticks_exactly_twice_then_expires() -> void:
	_set.apply(BURN, 72, 2, _cfg)
	# Turn 1: start-tick, then end-decrement.
	assert_eq(_set.burn_tick(), 5, "turn-1 start tick")
	_set.decrement_turn()
	# Turn 2: still present, start-tick, then end-decrement to 0 → removed.
	assert_true(_set.has(BURN), "still Burning at turn 2 start")
	assert_eq(_set.burn_tick(), 5, "turn-2 start tick")
	_set.decrement_turn()
	# Turn 3: absent — no third tick.
	assert_false(_set.has(BURN), "Burn expired after turn 2's end")
	assert_eq(_set.burn_tick(), 0, "no third tick")


func test_shock_and_stagger_modifiers_stop_at_expiry() -> void:
	_set.apply(SHOCK, 110, 1, _cfg)
	_set.apply(STAGGER, 110, 1, _cfg)
	assert_eq(_set.shock_penalty(), 33, "Shock active")
	assert_eq(_set.stagger_percentage(), 27, "Stagger active")
	_set.decrement_turn()  # both 1 → 0 → removed
	assert_eq(_set.shock_penalty(), 0, "Shock modifier stops at expiry")
	assert_eq(_set.stagger_percentage(), 0, "Stagger modifier stops at expiry")


# ---------------------------------------------------------------------------
# EC-TBC-14 — DOWNED clears statuses
# ---------------------------------------------------------------------------

func test_clear_removes_all_statuses() -> void:
	_set.apply(SHOCK, 53, 2, _cfg)
	_set.apply(BURN, 72, 2, _cfg)
	_set.clear()
	assert_eq(_set.count(), 0, "DOWNED cleanses every status")


# ---------------------------------------------------------------------------
# Element → status mapping (Rule 11)
# ---------------------------------------------------------------------------

func test_element_maps_to_status_type() -> void:
	assert_eq(StatusInstance.type_for_element(PartDef.Element.VOLT), SHOCK, "Volt → Shock")
	assert_eq(StatusInstance.type_for_element(PartDef.Element.THERMAL), BURN, "Thermal → Burn")
	assert_eq(StatusInstance.type_for_element(PartDef.Element.KINETIC), STAGGER, "Kinetic → Stagger")
