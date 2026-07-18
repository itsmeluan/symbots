## BattleController — the turn-based combat orchestrator and FSM host (ADR-0007;
## Stories 001–006, 011–014). A `RefCounted` (NOT an autoload — this project registers
## none; signals work on RefCounted just as well), created per session and driven one
## battle at a time.
##
## [b]FSM[/b] ([enum BattleState]) is dispatched through the private turn loop
## [method _run_turns]; [member is_battle_active] gates the world. The controller owns
## the single mutable [BattleContext] and drops it synchronously after the
## [signal battle_ended] cascade (WeakRef-verified teardown, Story 001/014) — the frozen
## snapshots hold no back-reference, so there is no cycle to break.
##
## [b]Purity boundary[/b]: all math is delegated to the pure kernel
## ([BattleFormulas] / [DamagePipeline] / [BattleResolver]); the controller only
## sequences phases and mutates runtime state. Stats are never recomputed mid-battle
## (`mid_battle_stat_recompute` forbidden) — everything derives from the frozen
## [SymbotLoadout] snapshots captured at BATTLE_INIT.
##
## [b]Player action model[/b] (Story 001): a player turn PARKS — [method _run_turns]
## sets [constant BattleState.ACTION_PENDING] and returns with no `await`; the UI later
## calls [method submit_action] to resume. Enemy turns resolve synchronously.
class_name BattleController
extends RefCounted

## Combat phases (Story 001). Dispatched via the turn loop; `ACTION_PENDING` and
## `FORCED_SWITCH` are the two parked states awaiting a [method submit_action].
enum BattleState {
	BATTLE_INIT, ROUND_START, TURN_ACTIVE, ACTION_PENDING,
	RESOLVING, TURN_END, FORCED_SWITCH, BATTLE_END,
}

## Terminal outcome carried by [signal battle_ended] (Story 014).
enum Outcome { NONE = 0, VICTORY = 1, DEFEAT = 2, FLED = 3 }

## Encounter kind — gates flee (WILD only, Story 011).
enum EncounterType { WILD = 1, BOSS = 2 }

## The four player action kinds submitted through [method submit_action].
enum ActionType { MOVE = 1, SWITCH = 2, ITEM = 3, FLEE = 4 }

## Consumable effect kinds (Story 012).
enum ItemEffect { RESTORE_STRUCTURE = 1, REDUCE_HEAT = 2, RESTORE_ENERGY = 3 }

## The 8-field COMBAT terminal signal (Story 014). Deliberately non-confusable with the
## 2-field WORLD `encounter_resolved`. VICTORY carries the deduped break-event set;
## DEFEAT / FLED carry an empty Dictionary.
signal battle_ended(outcome: int, enemy_id: StringName, fired_break_events: Dictionary,
	xp_value: int, completion_bonus_xp: int, is_first_boss_defeat: bool,
	enemy_level: int, deployed_symbot_ids: Array)

## The ONLY invalid-build exit (Story 002, AC-TBC-42): emitted instead of starting when
## any fielded [SymbotLoadout] is invalid. No [BattleContext] is created.
signal battle_start_refused(invalid_symbot_ids: Array, offending_parts: Array)

## Forwarded from [BattleResolver] for Part-Break / view listeners (Story 009/014).
signal hit_resolved(move: MoveDef, damage: int, target: Combatant, sub_target: StringName)

# ---------------------------------------------------------------------------
# Phase 2-A — view-signals (ADR-0008 §UI contract; plan §5).
# Owner-declared here (NOT on EventBus — sole consumer = BattleScreen, ADR-0002
# bus admission criteria not met). All payloads are value types; no live Combatant
# refs are passed (keeps the view decoupled from mutable internals). Every emission
# is AFTER the state mutation it reports and must NOT re-enter the FSM (ADR-0002 rule 5).
# ---------------------------------------------------------------------------

## Emitted when the FSM parks in ACTION_PENDING awaiting a player choice.
## [param actor_is_player] distinguishes the parked-player case (always true here,
## but explicit for HUD clarity). Emitted in [method _run_turns].
signal action_pending(actor_is_player: bool)

## Emitted when the player's queued action begins resolving (FSM enters RESOLVING).
## Emitted in [method submit_action].
signal action_resolving()

## Emitted at the start of every round, after initiative is recomputed.
## [param turn_order] is an Array of combatant_id [StringName]s (value snapshot — not
## live refs). Emitted in [method _begin_round].
signal round_started(round_number: int, turn_order: Array)

## Emitted after a combatant's turn-start bookkeeping completes (but before its action).
## Emitted in [method _run_turns] after the [method begin_turn] call succeeds.
signal turn_started(combatant_id: StringName, is_player: bool)

## Emitted when a combatant's action phase is skipped due to the overheat penalty.
## Emitted in [method _run_turns] on the `ts["skipped_action"]` branch.
signal turn_skipped(combatant_id: StringName)

## Emitted after any mutation to a combatant's `current_structure`.
## Covers: Burn tick ([method begin_turn]), overheat self-damage ([method _settle_heat]),
## item restore ([method _apply_item_effect]), and resolver hit ([method _on_resolver_hit]).
signal structure_changed(combatant_id: StringName, new_value: int, max_value: int, is_player: bool)

## Emitted after any mutation to a player combatant's `current_energy`.
## Covers: DAMAGE-move cost spend ([method _resolve_player_move]), turn-start recharge
## ([method begin_turn]). Enemies have no energy tracking — never emitted for enemies.
signal energy_changed(combatant_id: StringName, new_value: int, max_value: int)

## Emitted after any mutation to a combatant's `current_heat` or `is_overheated` flag.
## Covers heat accumulation and the overheat flag set/clear in [method _settle_heat]
## and the overheat reset in [method begin_turn].
signal heat_changed(combatant_id: StringName, new_value: int, is_overheated: bool)

## Emitted when a status is applied to a combatant (new apply or newest-wins refresh).
## [b]Phase 2-A gap[/b]: status application is routed through
## [PassiveEffectRegistry.dispatch_on_hit] which calls [StatusSet.apply] directly,
## bypassing the controller. Wiring this cleanly requires a registry-level callback
## seam that goes beyond a minimal hook — declared here for HUD completeness but
## NOT emitted yet. See TODO below.
## TODO: Phase: StatusApplied integration — add a registry callback seam so
## dispatch_on_hit can notify the controller whenever a status is applied.
signal status_applied(combatant_id: StringName, status_id: StringName, duration: int)

## Emitted when a status expires at turn-end (duration reaches 0 in [method end_turn]).
## [param status_id] is the [enum StatusInstance.Type] name as a [StringName]
## (e.g. [code]&"BURN"[/code], [code]&"SHOCK"[/code], [code]&"STAGGER"[/code]).
signal status_expired(combatant_id: StringName, status_id: StringName)

## Emitted when a Burn status ticks at turn-start, dealing direct structure loss.
## Only BURN ticks in the MVP; the controller emits this for the Burn branch in
## [method begin_turn]. [param damage] is the raw tick magnitude (bypasses DF-1).
signal status_ticked(combatant_id: StringName, status_id: StringName, damage: int)

## Emitted when a combatant is downed (structure hits 0 and [method _down] is called).
signal combatant_downed(combatant_id: StringName, is_player: bool)

## Emitted when the FSM parks in FORCED_SWITCH, awaiting the player's free replacement
## pick. Emitted in [method _resolve_enemy_action] and [method _handle_turn_start_death].
signal forced_switch_required()

## Emitted when a combatant crosses the overheat threshold (self-damage applied).
## Emitted in [method _settle_heat] at the point [member Combatant.is_overheated] is set.
signal overheat_triggered(combatant_id: StringName, self_damage: int)

## STUB — Part-Break integration pending. Emitted when a break region's HP changes.
## [b]Phase: Part-Break integration[/b] — Part-Break is not yet routed through the
## resolver; this signal is declared for HUD completeness but will NOT fire in a normal
## battle until Part-Break lands.
## TODO: Phase: Part-Break integration — wire emission once BattleResolver routes
## break-region HP mutations.
signal break_region_updated(enemy_id: StringName, region_id: StringName, new_hp: int,
	max_hp: int, is_broken: bool)

## STUB — Part-Break integration pending. Emitted when the enemy's enrage level changes
## (driven by broken-region count). Same integration gate as [signal break_region_updated].
## TODO: Phase: Part-Break integration — wire emission once broken-region count is live.
signal enrage_changed(enemy_id: StringName, broken_count: int, enrage_pct: float)

var _cfg: BalanceConfig
var _log: LogSink
var _resolver: BattleResolver
var _synergy = null  ## injected SynergySystem for the evaluate_silent ×N snapshot pass
var _passives: PassiveEffectRegistry = null

var _active: bool = false
var _state: BattleState = BattleState.BATTLE_INIT
var _ctx: BattleContext = null


func _init(cfg: BalanceConfig, log: LogSink) -> void:
	_cfg = cfg
	_log = log
	_resolver = BattleResolver.new(cfg, log)
	_resolver.hit_resolved.connect(_on_resolver_hit)


## True between BATTLE_INIT and the [signal battle_ended] cascade (Story 001).
func is_battle_active() -> bool:
	return _active


## Current FSM phase (introspection / tests).
func state() -> BattleState:
	return _state


## The live context (tests only; null when no battle is active).
func context() -> BattleContext:
	return _ctx


# ===========================================================================
# Story 002 — start sequence (Rule 2 order) & build-validity gate
# ===========================================================================

## Begin a battle from frozen [param loadouts] (1–3 [SymbotLoadout]s) against
## [param enemy_spec] (`{id, stats, core_element, level, xp_value, completion_bonus_xp,
## is_first_boss_defeat}`). [param synergy_system] is called `evaluate_silent` ONCE per
## loadout (Rule 2 step 2) — no `synergy_changed` emission (AC-TBC-01). [param opts] may
## carry `extra_passives` (a [PassiveEffectRegistry] entry dict) for test injection.
##
## Rule 2 ORDER: (0) validity gate — refuse before ANY snapshot; (1) freeze final_stat
## & pools; (2) evaluate_silent ×N → frozen synergy block; (3) instantiate the enemy
## (no synergy, Rule 8); (4) runtime-init players; (5) round-1 initiative. Returns true
## if the battle started, false if refused.
func start_battle(loadouts: Array, enemy_spec: Dictionary, encounter_type: int,
		synergy_system, opts: Dictionary = {}) -> bool:
	# --- Step 0: build-validity gate (BEFORE any BattleContext or snapshot) ---
	var invalid_ids: Array = []
	var offending: Array = []
	for l in loadouts:
		if not l.is_build_valid:
			invalid_ids.append(l.symbot_id)
			offending.append_array(l.offending_parts)
	if not invalid_ids.is_empty():
		battle_start_refused.emit(invalid_ids, offending)
		return false  # no snapshot taken, no context created

	_synergy = synergy_system
	_passives = PassiveEffectRegistry.new(_log, opts.get("extra_passives", {}))
	var ctx := BattleContext.new()
	ctx.encounter_type = encounter_type
	ctx.enemy_id = enemy_spec.get("id", &"")
	ctx.enemy_level = int(enemy_spec.get("level", 1))
	ctx.xp_value = int(enemy_spec.get("xp_value", 0))
	ctx.completion_bonus_xp = int(enemy_spec.get("completion_bonus_xp", 0))
	ctx.is_first_boss_defeat = bool(enemy_spec.get("is_first_boss_defeat", false))

	# --- Steps 1–2–4: per Symbot, freeze stats → evaluate_silent → runtime-init ---
	for slot in loadouts.size():
		var l = loadouts[slot]
		var synergy_delta: Dictionary = {}
		if _synergy != null:
			_synergy.evaluate_silent(l.parts)  # Rule 2 step 2 — SILENT, no synergy_changed
			synergy_delta = _synergy.cached_bonus_block.get("stat_delta", {})
		var c := Combatant.make_player(slot, l.symbot_id, l.final_stat, synergy_delta,
			_passives.frozen_passive_aura, l.core_element)
		ctx.team.append(c)
		ctx.move_pools.append(l.move_pool)
		ctx.passive_pools.append(l.passive_pool)

	# --- Step 3: enemy (Rule 8 — no synergy, no heat/energy participation) ---
	ctx.enemy = Combatant.make_enemy(ctx.enemy_id, enemy_spec.get("stats", {}),
		enemy_spec.get("core_element", null))

	_ctx = ctx
	_active = true
	_state = BattleState.BATTLE_INIT

	# ON_BATTLE_START passives (Story 013), then round 1.
	for slot in ctx.team.size():
		_passives.dispatch_battle_start(ctx.team[slot], ctx.passive_pools[slot])
	_begin_round()
	return true


# ===========================================================================
# Story 004 — initiative (recomputed every ROUND_START)
# ===========================================================================

## Pure initiative sort of [param combatants]: descending effective_mobility (TBC-F1,
## Shock consumed from each combatant's stored status), ties resolved player-first with
## NO RNG (stable — input order preserved among equal players). Returns a new ordered
## Array; does not mutate input.
static func initiative_order(combatants: Array) -> Array:
	var ordered: Array = combatants.duplicate()
	ordered.sort_custom(_initiative_before)
	return ordered


static func _initiative_before(a: Combatant, b: Combatant) -> bool:
	var ma: int = _mobility_of(a)
	var mb: int = _mobility_of(b)
	if ma != mb:
		return ma > mb  # higher mobility acts first
	return (not a.is_enemy) and b.is_enemy  # tie → the player before the enemy


static func _mobility_of(c: Combatant) -> int:
	return BattleFormulas.effective_mobility(
		int(c.final_stat.get(&"mobility", 0)),
		int(c.synergy_delta.get(&"mobility", 0)),
		c.statuses.shock_penalty())


## Recompute and store the round's turn order. Called at every ROUND_START (Story 004).
##
## Only the ACTIVE Symbot fights — benched Symbots do NOT take independent turns
## (they are switched in on demand; BattleContext: "benched ones simply aren't ticked").
## The roster is therefore exactly `[active, enemy]` (each included only while alive),
## NOT the whole living team. Putting the bench in `turn_order` makes `_run_turns` park
## on a benched Symbot's phantom turn so the enemy never acts (bug found 2026-07-18 by
## the multi-Symbot view-signal suite — the first test to drive `_run_turns` with a bench).
func compute_initiative() -> Array:
	# TODO(Luan): build `roster` from the ACTIVE Symbot + the enemy, each appended only
	# when `is_alive()`. Use `_ctx.active()` (returns the fielded team[active_index]) and
	# `_ctx.enemy`. Do NOT use `_ctx.living_team()` — that is what caused the bug.
	var roster: Array = []
	# <-- write the ~4 lines here: append active if alive, append enemy if alive.
	_ctx.turn_order = initiative_order(roster)
	return _ctx.turn_order


# ===========================================================================
# Story 003 — move-panel availability (pure query over the frozen pool + live energy)
# ===========================================================================

## Per-slot availability of [param move_pool] (`[basic_attack, WEAPON, HEAD, ARMS]`) at
## [param current_energy]: each entry is `{available, cost, move}` or `null` for an empty
## slot. `available = slot != null AND current_energy >= energy_cost`. Basic Attack
## (cost 0) is therefore always available. Never throws on a null slot (AC-TBC-06/21).
static func move_panel_state(move_pool: Array, current_energy: int) -> Array:
	var panel: Array = []
	for m in move_pool:
		if m == null:
			panel.append(null)
		else:
			var cost: int = int(m.energy_cost)
			panel.append({"available": current_energy >= cost, "cost": cost, "move": m})
	return panel


# ===========================================================================
# Story 005 / 006 — turn-start anatomy, heat & overheat
# ===========================================================================

## Run [param c]'s turn-start bookkeeping in the authoritative order (Story 005/006) and
## return `{skipped_action, burn_damage, downed}`:
##   overheated turn → heat reset flat to `overheat_reset_heat`, NO cooling decay, flag
##     consumed, action phase SKIPPED (still recharges + Burn-ticks);
##   normal player turn → (a) heat −= effective `cooling`; then
##   (b) energy = TBC-F2 recharge (players only — enemies skip decay & recharge); then
##   (c) Burn tick LAST (bypasses DF-1, may down the combatant → statuses cleared).
func begin_turn(c: Combatant) -> Dictionary:
	var result: Dictionary = {"skipped_action": false, "burn_damage": 0, "downed": false}
	var cid: StringName = _combatant_id(c)
	if c.is_overheated:
		c.current_heat = _cfg.overheat_reset_heat  # flat reset, no decay
		c.is_overheated = false  # consumed — THIS is the penalty turn
		result["skipped_action"] = true
		heat_changed.emit(cid, c.current_heat, c.is_overheated)
	elif not c.is_enemy:
		c.current_heat = maxi(0, c.current_heat - c.effective_stat(&"cooling"))  # (a) decay
		heat_changed.emit(cid, c.current_heat, c.is_overheated)
	if not c.is_enemy:  # (b) recharge — players only
		c.current_energy = BattleFormulas.recharge_energy(
			c.current_energy, c.effective_stat(&"recharge"), c.max_energy_capacity, _cfg)
		energy_changed.emit(cid, c.current_energy, c.max_energy_capacity)
	# (c) Burn tick LAST — direct structure loss, no DF-1.
	var burn: int = c.statuses.burn_tick()
	if burn > 0:
		status_ticked.emit(cid, &"BURN", burn)
		c.current_structure = maxi(0, c.current_structure - burn)
		result["burn_damage"] = burn
		structure_changed.emit(cid, c.current_structure, c.max_structure, not c.is_enemy)
		if c.current_structure == 0:
			_down(c)
			result["downed"] = true
	return result


## Turn-END: decrement every status duration (expired removed, AC-TBC-36). The overheat
## flag is NOT touched here — it is consumed at the NEXT [method begin_turn].
## Emits [signal status_expired] for each status that reaches duration 0.
func end_turn(c: Combatant) -> void:
	var expired: Array = c.statuses.decrement_turn()
	var cid: StringName = _combatant_id(c)
	for t in expired:
		status_expired.emit(cid, _status_type_name(t))


## Apply a move's heat gain to [param c] (Story 006): `min(threshold, heat + generation +
## THERMAL bonus)`. Crossing the threshold trips OVERHEATED and deals
## `floor(max_structure × overheat_self_damage_pct)` recoil. Returns
## `{overheated, self_damage}`. The caller MUST victory-check BEFORE calling this — a
## killing blow resolves before its own heat recoil (AC-TBC-09).
func apply_move_heat(c: Combatant, heat_generation: int, is_thermal_move: bool) -> Dictionary:
	var gain: int = heat_generation
	if is_thermal_move:
		gain += _cfg.thermal_move_heat_bonus
	return _settle_heat(c, gain)


func _settle_heat(c: Combatant, gain: int) -> Dictionary:
	c.current_heat = mini(_cfg.overheat_threshold, c.current_heat + gain)
	var res: Dictionary = {"overheated": false, "self_damage": 0}
	var cid: StringName = _combatant_id(c)
	if c.current_heat >= _cfg.overheat_threshold:
		c.is_overheated = true
		var self_dmg: int = StatMath.floor_eps(
			float(c.max_structure) * _cfg.overheat_self_damage_pct)
		c.current_structure = maxi(0, c.current_structure - self_dmg)
		res["overheated"] = true
		res["self_damage"] = self_dmg
		heat_changed.emit(cid, c.current_heat, c.is_overheated)
		overheat_triggered.emit(cid, self_dmg)
		structure_changed.emit(cid, c.current_structure, c.max_structure, not c.is_enemy)
		if c.current_structure == 0:
			_down(c)
	else:
		heat_changed.emit(cid, c.current_heat, c.is_overheated)
	return res


# ===========================================================================
# Story 001 — turn loop, player park & submit_action resume
# ===========================================================================

func _begin_round() -> void:
	_ctx.round_number += 1
	compute_initiative()  # Story 004 — recompute every ROUND_START
	_ctx.turn_cursor = 0
	_state = BattleState.ROUND_START
	# Build a value-type snapshot of the turn order (StringName ids, not live refs).
	var order_ids: Array = []
	for c in _ctx.turn_order:
		order_ids.append(_combatant_id(c))
	round_started.emit(_ctx.round_number, order_ids)
	_run_turns()


## Drive turns until the battle ends or a player turn parks. Enemy turns resolve inline;
## a player turn sets ACTION_PENDING and returns (no await — resumed by submit_action).
func _run_turns() -> void:
	while true:
		if _check_end():
			return
		if _ctx.turn_cursor >= _ctx.turn_order.size():
			_begin_round()  # round exhausted → next round (recomputes initiative)
			return
		var actor: Combatant = _ctx.turn_order[_ctx.turn_cursor]
		if not actor.is_alive():  # died earlier this round (Burn / a prior hit)
			_ctx.turn_cursor += 1
			continue
		var ts: Dictionary = begin_turn(actor)
		var actor_cid: StringName = _combatant_id(actor)
		# turn_started is emitted AFTER begin_turn bookkeeping, but only when the actor
		# survived (not downed by a Burn tick) and hasn't yet had its action resolved.
		if not ts["downed"]:
			turn_started.emit(actor_cid, not actor.is_enemy)
		if ts["downed"]:  # Burn-kill at turn start (Story 011)
			if _handle_turn_start_death(actor):
				return  # parked on a forced switch, or battle ended
			_ctx.turn_cursor += 1
			continue
		if ts["skipped_action"]:  # overheated — no action, straight to turn-end
			turn_skipped.emit(actor_cid)
			end_turn(actor)
			_ctx.turn_cursor += 1
			continue
		if actor.is_enemy:
			_resolve_enemy_action(actor)
			if _state == BattleState.BATTLE_END:
				return
			if _state == BattleState.FORCED_SWITCH:
				return  # player's active downed by the enemy — await the forced switch
			end_turn(actor)
			_ctx.turn_cursor += 1
			continue
		# Player turn — PARK (Story 001): no await, resume via submit_action.
		_state = BattleState.ACTION_PENDING
		action_pending.emit(true)
		return


## Resume a parked player turn (Story 001). A guarded no-op unless a player action is
## actually awaited (`ACTION_PENDING` — or a `FORCED_SWITCH` SWITCH). Resolves the
## action, then advances the turn if it was consumed; a rejected action re-parks so the
## player can choose again.
func submit_action(action: Dictionary) -> void:
	if _state == BattleState.FORCED_SWITCH:
		_resolve_forced_switch(action)
		return
	if _state != BattleState.ACTION_PENDING:
		return  # not this actor's decision point — ignore
	var actor: Combatant = _ctx.turn_order[_ctx.turn_cursor]
	_state = BattleState.RESOLVING
	action_resolving.emit()
	var consumed: bool = _resolve_player_action(actor, action)
	if _state == BattleState.BATTLE_END or _state == BattleState.FORCED_SWITCH:
		return  # ended (victory/flee) or the actor's own move downed the active → forced
	if not consumed:
		_state = BattleState.ACTION_PENDING  # rejected (illegal item/flee) — retry
		action_pending.emit(true)  # re-park notification so the HUD knows a retry is expected
		return
	end_turn(actor)
	_ctx.turn_cursor += 1
	_run_turns()


## Resolve a parked player action. Returns whether the turn was consumed (Story 011/012:
## a rejected item/flee does NOT consume). DAMAGE/REPAIR/SCAN and voluntary SWITCH all
## consume; FLEE ends the battle.
func _resolve_player_action(actor: Combatant, action: Dictionary) -> bool:
	match int(action.get("type", 0)):
		ActionType.MOVE:
			_resolve_player_move(actor, action)
			return true
		ActionType.SWITCH:
			return switch_active(int(action.get("target_index", -1)))
		ActionType.ITEM:
			return use_item(action.get("item", {}), int(action.get("target_index", -1)))
		ActionType.FLEE:
			return attempt_flee()
		_:
			_log.warn(&"battle_unknown_action", {&"type": action.get("type", 0)})
			return false


## Resolve a player MOVE by branch. DAMAGE routes through the resolver + ON_HIT riders,
## victory-checks BEFORE heat (AC-TBC-09), then applies heat. REPAIR/SCAN pay their own
## costs in the resolver; the controller then settles overheat on the raw heat added.
func _resolve_player_move(actor: Combatant, action: Dictionary) -> void:
	var move: MoveDef = action.get("move")
	var part_heat: int = int(action.get("part_heat_generation", 0))
	var actor_cid: StringName = _combatant_id(actor)
	match move.behavior:
		MoveDef.Behavior.DAMAGE:
			var sub: StringName = action.get("sub_target", BattleResolver.STRUCTURE)
			var is_weapon: bool = bool(action.get("is_weapon_slot", false))
			var crit: float = float(action.get("crit_mult", 1.0))
			var enemy_cid: StringName = _combatant_id(_ctx.enemy)
			_resolver.resolve_damage_move(actor, _ctx.enemy, move, sub, crit, 0)
			# Structure mutation is applied inside the resolver AFTER hit_resolved fires.
			structure_changed.emit(enemy_cid, _ctx.enemy.current_structure,
				_ctx.enemy.max_structure, false)
			actor.current_energy -= move.energy_cost  # DAMAGE-move energy is paid here
			energy_changed.emit(actor_cid, actor.current_energy, actor.max_energy_capacity)
			_passives.dispatch_on_hit(actor, _passive_pool_for(actor), move, is_weapon,
				_ctx.enemy, _cfg)
			if not _ctx.enemy.is_alive():  # victory BEFORE heat recoil (AC-TBC-09)
				_down(_ctx.enemy)  # emit combatant_downed for the enemy before the terminal cascade
				_end_battle(Outcome.VICTORY)
				return
			apply_move_heat(actor, part_heat, move.element == PartDef.Element.THERMAL)
		MoveDef.Behavior.REPAIR:
			_resolver.resolve_repair_move(actor, move, part_heat)  # pays energy + raw heat
			_settle_heat(actor, 0)  # trip overheat if the raw heat crossed the threshold
		MoveDef.Behavior.SCAN:
			_resolver.resolve_scan_move(actor, move, part_heat)
			_settle_heat(actor, 0)
		_:  # STATUS / UTILITY behaviors are content the MVP doesn't author yet
			_log.warn(&"battle_unhandled_move_behavior", {&"behavior": move.behavior})
	if _active and _ctx.team_wiped():  # actor could down itself via overheat recoil
		_end_battle(Outcome.DEFEAT)


func _resolve_enemy_action(enemy: Combatant) -> void:
	var target: Combatant = _ctx.active()
	var move: MoveDef = _default_enemy_move(enemy)
	_resolver.resolve_damage_move(enemy, target, move, BattleResolver.STRUCTURE, 1.0, 0)
	# Structure mutation is applied inside the resolver AFTER hit_resolved fires.
	structure_changed.emit(_combatant_id(target), target.current_structure,
		target.max_structure, true)
	if not target.is_alive():
		_down(target)
		if _ctx.team_wiped():
			_end_battle(Outcome.DEFEAT)
		else:
			_state = BattleState.FORCED_SWITCH  # await the player's replacement pick
			forced_switch_required.emit()


# ===========================================================================
# Story 011 — switch, flee, forced switch, bench/down
# ===========================================================================

## True if [param index] names a living, non-active bench Symbot (a legal switch target).
func can_switch_to(index: int) -> bool:
	if index < 0 or index >= _ctx.team.size() or index == _ctx.active_index:
		return false
	return _ctx.team[index].is_alive()


## Voluntary switch to [param index] (Story 011): consumes the turn. The incoming Symbot
## keeps its FROZEN runtime (structure/energy/heat/statuses — bench state simply wasn't
## ticked) and does NOT act this round. A switch to a downed/invalid bench slot is
## rejected + logged and does NOT consume the turn.
func switch_active(index: int) -> bool:
	if not can_switch_to(index):
		_log.warn(&"battle_switch_rejected", {&"index": index, &"reason": &"not_living_bench"})
		return false
	_ctx.active_index = index
	return true


## Flee (Story 011): WILD only. Turn-start bookkeeping has already run this turn; flee
## then ends the battle FLED. In a BOSS encounter flee is rejected + logged and does NOT
## consume the turn. Returns whether the turn was consumed (true only on a successful WILD flee).
func attempt_flee() -> bool:
	if _ctx.encounter_type != EncounterType.WILD:
		_log.warn(&"battle_flee_rejected", {&"reason": &"boss_encounter"})
		return false
	_end_battle(Outcome.FLED)
	return true


## Resolve a FORCED_SWITCH (Story 011): the active Symbot is DOWNED, so the incoming pick
## is FREE (no turn consumed) and does not act this round. Rejects a pick that is not a
## living bench Symbot (re-parks in FORCED_SWITCH).
func _resolve_forced_switch(action: Dictionary) -> void:
	if int(action.get("type", 0)) != ActionType.SWITCH:
		_log.warn(&"battle_forced_switch_expected", {})
		return
	var index: int = int(action.get("target_index", -1))
	if not can_switch_to(index):
		_log.warn(&"battle_switch_rejected", {&"index": index, &"reason": &"forced_bad_pick"})
		return  # stay parked until a valid replacement is chosen
	_ctx.active_index = index
	# The downed actor's turn is over; advance the loop (the incoming does not act).
	_ctx.turn_cursor += 1
	_run_turns()


## Handle a combatant downed by Burn AT turn start (Story 011). Player active downed with
## living bench → park FORCED_SWITCH (return true). Enemy downed → VICTORY. Team wiped →
## DEFEAT. Returns true when the loop must stop (parked or ended).
func _handle_turn_start_death(actor: Combatant) -> bool:
	if actor.is_enemy:
		_down(actor)  # enemy Burn-died at turn start — emit combatant_downed before VICTORY
		_end_battle(Outcome.VICTORY)
		return true
	if _ctx.team_wiped():
		_end_battle(Outcome.DEFEAT)
		return true
	if actor == _ctx.active():
		_state = BattleState.FORCED_SWITCH
		forced_switch_required.emit()
		return true  # await the free replacement pick
	return false  # a benched Symbot can't Burn-tick on its own turn; defensive


# ===========================================================================
# Story 012 — use item (target the active OR a bench Symbot; no switch-in)
# ===========================================================================

## Apply a consumable [param item] (`{effect, amount, id}`) to team Symbot
## [param target_index] (Story 012). Targets any LIVING team member (active or benched —
## does NOT switch it in); a DOWNED target is rejected. Consumes the turn ONLY on a
## net-positive apply; a zero-net use (already full / nothing to restore) is a pre-gate
## rejection that does NOT consume the turn. Returns whether the turn was consumed.
func use_item(item: Dictionary, target_index: int) -> bool:
	if target_index < 0 or target_index >= _ctx.team.size():
		_log.warn(&"battle_item_rejected", {&"reason": &"bad_target"})
		return false
	var target: Combatant = _ctx.team[target_index]
	if not target.is_alive():
		_log.warn(&"battle_item_rejected", {&"reason": &"downed_target"})
		return false  # DOWNED is not a valid item target
	var net: int = _apply_item_effect(target, int(item.get("effect", 0)), int(item.get("amount", 0)))
	if net <= 0:
		_log.info(&"battle_item_no_effect", {&"effect": item.get("effect", 0)})
		return false  # zero-net → turn NOT consumed, quantity unchanged
	return true


## Apply one consumable effect, clamped, and return the net change (0 if it did nothing).
## Emits [signal structure_changed], [signal heat_changed], or [signal energy_changed]
## AFTER the mutation, but only when the net change is non-zero (the caller rejects
## zero-net uses before the turn is consumed, so any emission here represents a real change).
func _apply_item_effect(target: Combatant, effect: int, amount: int) -> int:
	var cid: StringName = _combatant_id(target)
	match effect:
		ItemEffect.RESTORE_STRUCTURE:
			var before: int = target.current_structure
			target.current_structure = mini(target.max_structure, before + amount)
			var net: int = target.current_structure - before
			if net != 0:
				structure_changed.emit(cid, target.current_structure, target.max_structure,
					not target.is_enemy)
			return net
		ItemEffect.REDUCE_HEAT:
			var before_h: int = target.current_heat
			target.current_heat = maxi(0, before_h - amount)
			var net_h: int = before_h - target.current_heat
			if net_h != 0:
				heat_changed.emit(cid, target.current_heat, target.is_overheated)
			return net_h
		ItemEffect.RESTORE_ENERGY:
			var before_e: int = target.current_energy
			target.current_energy = mini(target.max_energy_capacity, before_e + amount)
			var net_e: int = target.current_energy - before_e
			if net_e != 0:
				energy_changed.emit(cid, target.current_energy, target.max_energy_capacity)
			return net_e
		_:
			return 0


# ===========================================================================
# Story 014 — end conditions, 8-field battle_ended, teardown
# ===========================================================================

func _check_end() -> bool:
	if not _ctx.enemy.is_alive():
		_down(_ctx.enemy)  # defensive: guarantee combatant_downed fired for the enemy (idempotent)
		_end_battle(Outcome.VICTORY)
		return true
	if _ctx.team_wiped():
		_end_battle(Outcome.DEFEAT)
		return true
	return false


## Terminate the battle (Story 014): emit the 8-field [signal battle_ended] with the
## deduped break-event set on VICTORY (empty on DEFEAT/FLED), then drop the context and
## deactivate — `_ctx = null` FIRST, `_active = false` second (Story 001 order). The
## synchronous emit means every listener has run before teardown; the RefCounted context
## frees immediately (WeakRef-verified — no back-reference cycle).
func _end_battle(outcome: int) -> void:
	if not _active:
		return  # idempotent guard — never emit twice
	_ctx.outcome = outcome
	_state = BattleState.BATTLE_END
	var breaks: Dictionary = {}
	if outcome == Outcome.VICTORY:
		breaks = _ctx.fired_break_events.duplicate()
	var payload := {
		"enemy_id": _ctx.enemy_id, "xp": _ctx.xp_value, "bonus": _ctx.completion_bonus_xp,
		"first_boss": _ctx.is_first_boss_defeat, "level": _ctx.enemy_level,
		"deployed": _ctx.deployed_symbot_ids(),
	}
	battle_ended.emit(outcome, payload["enemy_id"], breaks, payload["xp"], payload["bonus"],
		payload["first_boss"], payload["level"], payload["deployed"])
	_ctx = null       # drop the context graph (Story 001 teardown order)
	_active = false


# ===========================================================================
# Internal helpers
# ===========================================================================

## Down a combatant: flag it and cleanse all statuses (EC-TBC-14 — a DOWNED combatant
## starts clean if ever revived). Emits [signal combatant_downed] after mutation.
func _down(c: Combatant) -> void:
	if c.is_downed:
		return  # idempotent — never emit combatant_downed twice for the same combatant
	c.is_downed = true
	c.statuses.clear()
	combatant_downed.emit(_combatant_id(c), not c.is_enemy)


## Return a stable [StringName] identifier for a combatant suitable for view-signal
## payloads. Enemies use their content id; player Symbots use their slot index as a
## StringName (e.g. [code]&"slot_0"[/code]) — avoids passing live refs to the view.
func _combatant_id(c: Combatant) -> StringName:
	if c.is_enemy:
		return c.enemy_id
	return ("slot_" + str(c.slot_index)) as StringName


## Map a [enum StatusInstance.Type] int to a [StringName] label for view-signal payloads
## (e.g. [code]StatusInstance.Type.BURN[/code] → [code]&"BURN"[/code]).
static func _status_type_name(status_type: int) -> StringName:
	match status_type:
		StatusInstance.Type.SHOCK:   return &"SHOCK"
		StatusInstance.Type.BURN:    return &"BURN"
		StatusInstance.Type.STAGGER: return &"STAGGER"
		_: return &"UNKNOWN"


func _passive_pool_for(actor: Combatant) -> Array:
	if actor.is_enemy:
		return []
	return _ctx.passive_pools[actor.slot_index]


## A synthesized enemy basic attack (Rule 8): PHYSICAL / STANDARD, element from the
## enemy Core, free. The Enemy DB / EnemyAI will supply real move pools later; this keeps
## the loop drivable for the vertical slice.
func _default_enemy_move(enemy: Combatant) -> MoveDef:
	var m := MoveDef.new()
	m.id = &"enemy_basic_attack"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = enemy.core_element if enemy.core_element != null else PartDef.Element.KINETIC
	m.energy_cost = 0
	return m


## Record a fired break event (Story 014 dedup). Called by the Part-Break subscriber once
## it lands; exposed now so the VICTORY payload accretes a de-duplicated set.
func note_break_event(event_id: StringName) -> void:
	if _ctx != null:
		_ctx.fired_break_events[event_id] = true


func _on_resolver_hit(move: MoveDef, damage: int, target: Combatant, sub_target: StringName) -> void:
	hit_resolved.emit(move, damage, target, sub_target)  # forward for external listeners
