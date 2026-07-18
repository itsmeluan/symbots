## BattleController autoload — Option A wrapper (ADR-0007; ADR-0004 §1 slot 11).
##
## Thin Node autoload that holds the per-session BattleController RefCounted and proxies
## its public API + signals. The pure core (src/core/battle/battle_controller.gd) is
## untouched — this wrapper is the global stable host that ADR-0002 §4 requires for
## is_battle_active() (the save-quiesce gate) and that ADR-0004 requires for a
## persistent-lifetime signal source (the Battle scene is queue_free()'d; this is not).
##
## Signal forwarding: the 3 EXISTING BattleController signals (battle_ended,
## battle_start_refused, hit_resolved) are RE-DECLARED here and forwarded from the
## per-session RefCounted via _on_* handlers connected when the RefCounted is created.
## DO NOT add the ~14 view-signals declared in the plan §5 here — those are Phase 2-A
## (next wave) and will be added to the core BattleController then forwarded here.
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
# Phase 2-A: forward view-signals here (next wave — do NOT add until core declares them)
# ---------------------------------------------------------------------------
# signal action_pending(actor_is_player: bool)
# signal action_resolving()
# signal round_started(round_number: int, turn_order: Array)
# signal turn_started(combatant_id: StringName, is_player: bool)
# signal turn_skipped(combatant_id: StringName)
# signal structure_changed(combatant_id: StringName, new_value: int, max_value: int, is_player: bool)
# signal energy_changed(combatant_id: StringName, new_value: int, max_value: int)
# signal heat_changed(combatant_id: StringName, new_value: int, is_overheated: bool)
# signal status_applied(combatant_id: StringName, status_id: StringName, duration: int)
# signal status_expired(combatant_id: StringName, status_id: StringName)
# signal status_ticked(combatant_id: StringName, status_id: StringName, damage: int)
# signal combatant_downed(combatant_id: StringName, is_player: bool)
# signal forced_switch_required()
# signal overheat_triggered(combatant_id: StringName, self_damage: int)
# signal break_region_updated(enemy_id: StringName, region_id: StringName, new_hp: int, max_hp: int, is_broken: bool)
# signal enrage_changed(enemy_id: StringName, broken_count: int, enrage_pct: float)

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


## Current FSM state — for test introspection. Returns BATTLE_INIT when no battle active.
func state() -> BattleController.BattleState:
	if _bc == null:
		return BattleController.BattleState.BATTLE_INIT
	return _bc.state()


# ---------------------------------------------------------------------------
# Signal forwarding — connect named Callables to the per-session RefCounted
# ---------------------------------------------------------------------------

func _connect_bc_signals() -> void:
	_bc.battle_ended.connect(Callable(self, "_on_battle_ended"))
	_bc.battle_start_refused.connect(Callable(self, "_on_battle_start_refused"))
	_bc.hit_resolved.connect(Callable(self, "_on_hit_resolved"))
	# Phase 2-A: connect forwarding for view-signals here when they exist on _bc.


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
