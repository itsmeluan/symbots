## PassiveEffectRegistry — trigger-dispatched passive effects for battle (ADR-0007
## Rule 13; Story 013). A `RefCounted` created once per battle by the orchestrator.
##
## Maps an `effect_id` (from a Symbot's passive pool or a Synergy `effects` list) to a
## registry entry `{ trigger, scope, status_type, duration, action }` and dispatches it
## at the matching battle phase:
##   ON_HIT         — the carrier landed a DAMAGE move (scope narrows: ANY_DAMAGE vs
##                    WEAPON_ONLY); a STATUS_RIDER applies its status to the target,
##                    snapshotting the carrier's PRE-synergy `processing` (Story 007).
##   ON_TURN_START  — the carrier's turn begins.
##   ON_BATTLE_START— once in BATTLE_INIT, before turn 1.
##   PERSISTENT     — NOT an event: its STAT_AURA delta is captured into
##                    `frozen_passive_aura` at BATTLE_INIT and never re-fires.
##   ON_OVERHEAT    — routing exists; no MVP content.
##
## Unknown ids (no registry entry) are logged ONCE via the injected [LogSink] and
## skipped — never crash, never silent-swallow (AC-TBC-14). When several passives fire
## on one event they resolve in ascending alphabetical `effect_id` order.
class_name PassiveEffectRegistry
extends RefCounted

## When a passive fires relative to the battle timeline.
enum Trigger {
	ON_HIT         = 1,
	ON_TURN_START  = 2,
	ON_BATTLE_START = 3,
	PERSISTENT     = 4,
	ON_OVERHEAT    = 5,
}

## Which DAMAGE moves an ON_HIT rider qualifies on.
enum Scope {
	NONE        = 0,
	ANY_DAMAGE  = 1,  ## any DAMAGE move
	WEAPON_ONLY = 2,  ## only a WEAPON-slot DAMAGE move
}

var _entries: Dictionary = {}
var _log: LogSink

## STAT_AURA deltas of PERSISTENT passives, captured at BATTLE_INIT, held whole battle.
## Empty in MVP (all three seed riders are ON_HIT STATUS_RIDERs) but wired so the first
## STAT_AURA Core passive reaches the SYN-F4 clamp (Story 008 reads it via effective_stat).
var frozen_passive_aura: Dictionary = {}


## Build the registry with the MVP seed set. [param extra_entries] merges in additional
## entries (used by tests to inject synthetic ON_BATTLE_START / ON_TURN_START counters);
## a key present in both overrides the seed.
func _init(log: LogSink, extra_entries: Dictionary = {}) -> void:
	_log = log
	_entries = _seed_entries()
	for id in extra_entries:
		_entries[id] = extra_entries[id]


## The three MVP status-rider passives (Rule 13). Volt→Shock 1T (any DAMAGE),
## Thermal→Burn 2T (WEAPON-slot only), Kinetic→Stagger 1T (any DAMAGE).
func _seed_entries() -> Dictionary:
	return {
		&"volt_shock_on_hit": _rider(Scope.ANY_DAMAGE, StatusInstance.Type.SHOCK, 1),
		&"thermal_burn_on_weapon": _rider(Scope.WEAPON_ONLY, StatusInstance.Type.BURN, 2),
		&"kinetic_stagger_on_hit": _rider(Scope.ANY_DAMAGE, StatusInstance.Type.STAGGER, 1),
	}


func _rider(scope: Scope, status_type: int, duration: int) -> Dictionary:
	return {"trigger": Trigger.ON_HIT, "scope": scope,
		"status_type": status_type, "duration": duration, "action": Callable()}


## Register a generic entry firing [param action] (a Callable taking the carrier
## [Combatant]) at [param trigger]. Used for non-rider passives / test counters.
static func generic(trigger: Trigger, action: Callable) -> Dictionary:
	return {"trigger": trigger, "scope": Scope.NONE,
		"status_type": 0, "duration": 0, "action": action}


## True if an entry exists for [param effect_id].
func has_effect(effect_id: StringName) -> bool:
	return _entries.has(effect_id)


## Dispatch ON_HIT riders for [param carrier]'s [param passive_pool] after it lands a
## DAMAGE [param move] on [param target]. [param is_weapon_slot] narrows WEAPON_ONLY
## scope. Non-DAMAGE moves apply nothing. Riders apply their status to [param target]
## with the carrier's PRE-synergy `processing` snapshot (Story 007 newest-wins). Unknown
## ids log once and are skipped. Fires in ascending alphabetical id order.
func dispatch_on_hit(carrier: Combatant, passive_pool: Array, move: MoveDef,
		is_weapon_slot: bool, target: Combatant, cfg: BalanceConfig) -> void:
	if move.behavior != MoveDef.Behavior.DAMAGE:
		return  # ON_HIT riders never trigger on Repair/Status/SCAN (AC-TBC-29 negative)
	for effect_id in _sorted_known(passive_pool):
		var entry: Dictionary = _entries[effect_id]
		if entry["trigger"] != Trigger.ON_HIT:
			continue
		if entry["scope"] == Scope.WEAPON_ONLY and not is_weapon_slot:
			continue  # AC-TBC-30: thermal_burn_on_weapon skips HEAD-slot moves
		var proc: int = carrier.snapshot_stat(&"processing")
		target.statuses.apply(entry["status_type"], proc, entry["duration"], cfg)


## Dispatch ON_BATTLE_START entries for [param carrier]'s [param passive_pool], once at
## BATTLE_INIT. Alphabetical order; unknown ids logged+skipped.
func dispatch_battle_start(carrier: Combatant, passive_pool: Array) -> void:
	_dispatch_phase(carrier, passive_pool, Trigger.ON_BATTLE_START)


## Dispatch ON_TURN_START entries for [param carrier] at the start of its turn.
func dispatch_turn_start(carrier: Combatant, passive_pool: Array) -> void:
	_dispatch_phase(carrier, passive_pool, Trigger.ON_TURN_START)


func _dispatch_phase(carrier: Combatant, passive_pool: Array, trigger: Trigger) -> void:
	for effect_id in _sorted_known(passive_pool):
		var entry: Dictionary = _entries[effect_id]
		if entry["trigger"] != trigger:
			continue
		var action: Callable = entry["action"]
		if action.is_valid():
			action.call(carrier)


## Return [param passive_pool] ids that HAVE a registry entry, alphabetically sorted;
## each unknown id is logged exactly once (AC-TBC-14) and dropped. Called per dispatch —
## an id unknown at every trigger is logged at every phase it is asked about, but within
## a single dispatch it is logged once, matching "processing continues" semantics.
func _sorted_known(passive_pool: Array) -> Array:
	var known: Array = []
	for effect_id in passive_pool:
		if _entries.has(effect_id):
			known.append(effect_id)
		else:
			_log.error(&"content_unknown_passive_effect", {&"effect_id": effect_id})
	known.sort()
	return known
