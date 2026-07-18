## BattleController autoload — Option A wrapper (ADR-0007; ADR-0004 §1 slot 11).
##
## Thin Node autoload that holds the per-session BattleController RefCounted and proxies
## its public API + signals. The pure core (src/core/battle/battle_controller.gd) is
## untouched — this wrapper is the global stable host that ADR-0002 §4 requires for
## is_battle_active() (the save-quiesce gate) and that ADR-0004 requires for a
## persistent-lifetime signal source (the Battle scene is queue_free()'d; this is not).
##
## Signal forwarding: all BattleController signals (the original 3 + the 16 Phase 2-A
## view-signals) are RE-DECLARED here and forwarded from the per-session RefCounted via
## _on_* handlers connected when the RefCounted is created.
##
## ADR-0004 inertness rule: zero _ready work. No I/O, no catalog loads, no signal
## connections, no cross-autoload reads in _ready. The FSM is driven only by
## start_battle(); this autoload is a transparent forwarding shell until that call.
##
## Named-Callable discipline: all internal connections use Callable(self, "_on_*")
## so they can be disconnected individually when the per-session RefCounted is replaced.
extends Node

# ---------------------------------------------------------------------------
# Re-declared forwarded signals (ADR-0002: owner-declared on TBC, proxied here).
# Consumers that need these from the persistent autoload connect here, not to the
# per-session RefCounted (which is replaced each battle).
# ---------------------------------------------------------------------------

## 8-field COMBAT terminal signal. Forwarded from the per-session BattleController.
## See src/core/battle/battle_controller.gd for field semantics.
signal battle_ended(outcome: int, enemy_id: StringName, fired_break_events: Dictionary,
	xp_value: int, completion_bonus_xp: int, is_first_boss_defeat: bool,
	enemy_level: int, deployed_symbot_ids: Array)

## Invalid-build exit signal. Forwarded from the per-session BattleController.
signal battle_start_refused(invalid_symbot_ids: Array, offending_parts: Array)

## Hit notification forwarded from BattleResolver via the per-session BattleController.
signal hit_resolved(move: MoveDef, damage: int, target: Combatant, sub_target: StringName)

# ---------------------------------------------------------------------------
# Phase 2-A: view-signals — re-declared and forwarded from the per-session RefCounted.
# The HUD-facing surface is complete; the 2 stub signals (break_region_updated,
# enrage_changed) are forwarded here but will not fire until Part-Break integration.
# ---------------------------------------------------------------------------

## Forwarded from BattleController. See source for full doc.
signal action_pending(actor_is_player: bool)

## Forwarded from BattleController. See source for full doc.
signal action_resolving()

## Forwarded from BattleController. See source for full doc.
signal round_started(round_number: int, turn_order: Array)

## Forwarded from BattleController. See source for full doc.
signal turn_started(combatant_id: StringName, is_player: bool)

## Forwarded from BattleController. See source for full doc.
signal turn_skipped(combatant_id: StringName)

## Forwarded from BattleController. See source for full doc.
signal structure_changed(combatant_id: StringName, new_value: int, max_value: int, is_player: bool)

## Forwarded from BattleController. See source for full doc.
signal energy_changed(combatant_id: StringName, new_value: int, max_value: int)

## Forwarded from BattleController. See source for full doc.
signal heat_changed(combatant_id: StringName, new_value: int, is_overheated: bool)

## Forwarded from BattleController. See source for full doc.
## NOTE: not emitted in Phase 2-A (status_applied integration gap — see core TODO).
signal status_applied(combatant_id: StringName, status_id: StringName, duration: int)

## Forwarded from BattleController. See source for full doc.
signal status_expired(combatant_id: StringName, status_id: StringName)

## Forwarded from BattleController. See source for full doc.
signal status_ticked(combatant_id: StringName, status_id: StringName, damage: int)

## Forwarded from BattleController. See source for full doc.
signal combatant_downed(combatant_id: StringName, is_player: bool)

## Forwarded from BattleController. See source for full doc.
signal forced_switch_required()

## Forwarded from BattleController. See source for full doc.
signal overheat_triggered(combatant_id: StringName, self_damage: int)

## Forwarded from BattleController. STUB — Part-Break integration pending.
signal break_region_updated(enemy_id: StringName, region_id: StringName, new_hp: int,
	max_hp: int, is_broken: bool)

## Forwarded from BattleController. STUB — Part-Break integration pending.
signal enrage_changed(enemy_id: StringName, broken_count: int, enrage_pct: float)

# ---------------------------------------------------------------------------
# Per-session state
# ---------------------------------------------------------------------------

## The current per-session BattleController RefCounted. Null between battles.
## Never expose this reference to callers — they use this autoload's proxy API.
var _bc: BattleController = null

## BalanceConfig used to construct each BattleController. Set by BootScreen after
## loading the balance .tres (boot step 2b). Required before start_battle().
## TODO: BootScreen will call set_balance_config(cfg) at boot step 4b.
var _cfg: BalanceConfig = null

## LogSink injected at boot. Falls back to Log.sink at start_battle time if not set.
var _log: LogSink = null


# ---------------------------------------------------------------------------
# Boot injection (called by BootScreen, never in _ready)
# ---------------------------------------------------------------------------

## Inject the BalanceConfig and LogSink so start_battle() can construct the RefCounted.
## Called by BootScreen at step 4b (after _balance_config is loaded). Never in _ready.
func set_config(cfg: BalanceConfig, log: LogSink) -> void:
	_cfg = cfg
	_log = log


# ---------------------------------------------------------------------------
# Proxy API — mirrors BattleController's public surface
# ---------------------------------------------------------------------------

## True between BATTLE_INIT and the battle_ended cascade. Reads the per-session
## RefCounted if one exists; returns false otherwise (no battle active = safe to save).
## This is the ADR-0002 §4 quiesce gate — called by SaveLoad.is_battle_active().
func is_battle_active() -> bool:
	if _bc == null:
		return false
	return _bc.is_battle_active()


## Create a new per-session BattleController and start a battle. Replaces any prior
## RefCounted (though start_battle is guarded — the prior _bc should be inactive by now).
## Requires set_config() to have been called first (BootScreen step 4b).
## [param loadouts] — Array of SymbotLoadout.
## [param enemy_spec] — Dictionary per battle_controller.gd start_battle contract.
## [param encounter_type] — BattleController.EncounterType int.
## [param synergy_system] — injected SynergySystem (Variant for now).
## [param opts] — forwarded to BattleController (test injection, etc.).
## Returns true if the battle started, false if refused.
func start_battle(loadouts: Array, enemy_spec: Dictionary, encounter_type: int,
		synergy_system = null, opts: Dictionary = {}) -> bool:
	var log: LogSink = _log if _log != null else Log.sink
	if _cfg == null:
		log.error(&"battle_controller_no_config",
			{"reason": "set_config() not called before start_battle()"})
		return false
	_bc = BattleController.new(_cfg, log)
	_connect_bc_signals()
	return _bc.start_battle(loadouts, enemy_spec, encounter_type, synergy_system, opts)


## Resume a parked player turn. Delegates to the per-session RefCounted; no-op if no
## battle is active (guarded no-op per BattleController contract).
func submit_action(action: Dictionary) -> void:
	if _bc != null:
		_bc.submit_action(action)


## Record a fired break event on the per-session BattleController so the VICTORY
## payload accretes a de-duplicated set (Story 014). Called by the Battle screen's
## Part-Break subscriber once a region's cumulative damage crosses its break_hp.
## No-op if no battle is active.
func note_break_event(event_id: StringName) -> void:
	if _bc != null:
		_bc.note_break_event(event_id)


## Current FSM state — for test introspection. Returns BATTLE_INIT when no battle active.
func state() -> BattleController.BattleState:
	if _bc == null:
		return BattleController.BattleState.BATTLE_INIT
	return _bc.state()


## The live per-session BattleContext, or null between battles. The Battle screen reads
## this to refresh its bars inside signal handlers (NEVER in _process — that is the
## forbidden view_state_polling; a pull inside a signal handler is legal, ADR-0008).
func context() -> BattleContext:
	if _bc == null:
		return null
	return _bc.context()


# ---------------------------------------------------------------------------
# Signal forwarding — connect named Callables to the per-session RefCounted
# ---------------------------------------------------------------------------

func _connect_bc_signals() -> void:
	# Original 3 signals
	_bc.battle_ended.connect(Callable(self, "_on_battle_ended"))
	_bc.battle_start_refused.connect(Callable(self, "_on_battle_start_refused"))
	_bc.hit_resolved.connect(Callable(self, "_on_hit_resolved"))
	# Phase 2-A view-signals (12 emitting + 2 stubs)
	_bc.action_pending.connect(Callable(self, "_on_action_pending"))
	_bc.action_resolving.connect(Callable(self, "_on_action_resolving"))
	_bc.round_started.connect(Callable(self, "_on_round_started"))
	_bc.turn_started.connect(Callable(self, "_on_turn_started"))
	_bc.turn_skipped.connect(Callable(self, "_on_turn_skipped"))
	_bc.structure_changed.connect(Callable(self, "_on_structure_changed"))
	_bc.energy_changed.connect(Callable(self, "_on_energy_changed"))
	_bc.heat_changed.connect(Callable(self, "_on_heat_changed"))
	_bc.status_applied.connect(Callable(self, "_on_status_applied"))
	_bc.status_expired.connect(Callable(self, "_on_status_expired"))
	_bc.status_ticked.connect(Callable(self, "_on_status_ticked"))
	_bc.combatant_downed.connect(Callable(self, "_on_combatant_downed"))
	_bc.forced_switch_required.connect(Callable(self, "_on_forced_switch_required"))
	_bc.overheat_triggered.connect(Callable(self, "_on_overheat_triggered"))
	_bc.break_region_updated.connect(Callable(self, "_on_break_region_updated"))
	_bc.enrage_changed.connect(Callable(self, "_on_enrage_changed"))


# ---------------------------------------------------------------------------
# Forwarders — original 3 signals
# ---------------------------------------------------------------------------

func _on_battle_ended(outcome: int, enemy_id: StringName, fired_break_events: Dictionary,
		xp_value: int, completion_bonus_xp: int, is_first_boss_defeat: bool,
		enemy_level: int, deployed_symbot_ids: Array) -> void:
	battle_ended.emit(outcome, enemy_id, fired_break_events, xp_value,
		completion_bonus_xp, is_first_boss_defeat, enemy_level, deployed_symbot_ids)


func _on_battle_start_refused(invalid_symbot_ids: Array, offending_parts: Array) -> void:
	battle_start_refused.emit(invalid_symbot_ids, offending_parts)


func _on_hit_resolved(move: MoveDef, damage: int, target: Combatant,
		sub_target: StringName) -> void:
	hit_resolved.emit(move, damage, target, sub_target)


# ---------------------------------------------------------------------------
# Forwarders — Phase 2-A view-signals
# ---------------------------------------------------------------------------

func _on_action_pending(actor_is_player: bool) -> void:
	action_pending.emit(actor_is_player)


func _on_action_resolving() -> void:
	action_resolving.emit()


func _on_round_started(round_number: int, turn_order: Array) -> void:
	round_started.emit(round_number, turn_order)


func _on_turn_started(combatant_id: StringName, is_player: bool) -> void:
	turn_started.emit(combatant_id, is_player)


func _on_turn_skipped(combatant_id: StringName) -> void:
	turn_skipped.emit(combatant_id)


func _on_structure_changed(combatant_id: StringName, new_value: int, max_value: int,
		is_player: bool) -> void:
	structure_changed.emit(combatant_id, new_value, max_value, is_player)


func _on_energy_changed(combatant_id: StringName, new_value: int, max_value: int) -> void:
	energy_changed.emit(combatant_id, new_value, max_value)


func _on_heat_changed(combatant_id: StringName, new_value: int, is_overheated: bool) -> void:
	heat_changed.emit(combatant_id, new_value, is_overheated)


func _on_status_applied(combatant_id: StringName, status_id: StringName,
		duration: int) -> void:
	status_applied.emit(combatant_id, status_id, duration)


func _on_status_expired(combatant_id: StringName, status_id: StringName) -> void:
	status_expired.emit(combatant_id, status_id)


func _on_status_ticked(combatant_id: StringName, status_id: StringName,
		damage: int) -> void:
	status_ticked.emit(combatant_id, status_id, damage)


func _on_combatant_downed(combatant_id: StringName, is_player: bool) -> void:
	combatant_downed.emit(combatant_id, is_player)


func _on_forced_switch_required() -> void:
	forced_switch_required.emit()


func _on_overheat_triggered(combatant_id: StringName, self_damage: int) -> void:
	overheat_triggered.emit(combatant_id, self_damage)


func _on_break_region_updated(enemy_id: StringName, region_id: StringName, new_hp: int,
		max_hp: int, is_broken: bool) -> void:
	break_region_updated.emit(enemy_id, region_id, new_hp, max_hp, is_broken)


func _on_enrage_changed(enemy_id: StringName, broken_count: int, enrage_pct: float) -> void:
	enrage_changed.emit(enemy_id, broken_count, enrage_pct)
