## SaveLoad — save/load provider registry + autosave + quiesce gate (ADR-0001; ADR-0004 §1 slot 10).
##
## This is the STUB for Wave 1. Real ADR-0001 logic (single-file JSON envelope, atomic
## writes, two-phase restore, REFUSE semantics, emergency save lifecycle path) is out of
## Wave 1 scope. The public API surface is declared here so callers (BootScreen, EventBus
## autosave subscribers, BattleController quiesce check) can compile and test against it.
##
## ADR-0004 inertness rule: zero _ready work. Provider registration and EventBus autosave
## connections happen in BootScreen steps 5–6 — never in _ready. Providers register via
## register_provider(); autosave connects via connect_autosave_triggers().
##
## The two EventBus.CONNECT_DEFERRED autosave sites (encounter_resolved + zone_entered)
## are the ONLY sanctioned CONNECT_DEFERRED uses in the project (ADR-0002 §4). When the
## real implementation lands, they must remain deferred so the autosave snapshot always
## observes post-cascade world state.
##
## TODO (ADR-0001 implementation story): replace stub method bodies with real logic.
##   - register_provider: store provider in _providers dict keyed by StringName.
##   - connect_autosave_triggers: connect EventBus.encounter_resolved and zone_entered
##       with CONNECT_DEFERRED; callables target THIS autoload (permanent — never a
##       scene-tree node that could be queue_free()'d under the subscription).
##   - is_battle_active: delegate to BattleController autoload.
##   - save_emergency(): synchronous atomic write — called from Game root's
##       NOTIFICATION_APPLICATION_PAUSED (iOS background/termination).
extends Node

## Registered providers, keyed by StringName. Populated by BootScreen step 5.
var _providers: Dictionary = {}


## Register [param provider] under [param key] for snapshot()/restore()/rederive()
## lifecycle. Called by BootScreen step 5, never in _ready. Providers must implement
## snapshot() -> Dictionary / restore(data: Dictionary) / rederive() (ADR-0001 triad).
## TODO: store provider and validate triad shape in the real implementation.
func register_provider(key: StringName, provider: Object) -> void:
	_providers[key] = provider


## Connect the two deferred autosave trigger sites (ADR-0002 §4, ADR-0004 boot step 6).
## MUST use CONNECT_DEFERRED so the autosave snapshot fires AFTER the entire synchronous
## post-battle / zone-entry cascade has completed — these are the ONLY deferred sites
## in the project. Called by BootScreen step 6, never in _ready.
## TODO: connect EventBus.encounter_resolved and EventBus.zone_entered with
##       CONNECT_DEFERRED targeting _on_autosave_trigger and _on_autosave_trigger_zone.
func connect_autosave_triggers() -> void:
	pass  # TODO: implement in ADR-0001 story


## True when a battle is in progress (ADR-0002 §4 quiesce gate for manual save).
## Delegates to the TBC autoload (slot 11) at call time — never cached.
## Returns false in this stub (no battle is active before TBC is set up).
func is_battle_active() -> bool:
	return TBC.is_battle_active()


## Emergency synchronous save — called from Game root's NOTIFICATION_APPLICATION_PAUSED
## (iOS background/termination, ADR-0001 File Rule 8). Bypasses the CONNECT_DEFERRED
## autosave path; writes the same envelope atomically.
## TODO: implement in ADR-0001 story.
func save_emergency() -> void:
	pass  # TODO: implement in ADR-0001 story
