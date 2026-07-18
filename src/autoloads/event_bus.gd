## EventBus — cross-layer broadcast signals (ADR-0002 §1, closed 3-signal roster).
##
## FIRST in the autoload order (ADR-0004 §1). Stateless plain Node containing ONLY
## signal declarations — no methods, no state, no logic of any kind.
##
## Bus admission criteria (ADR-0002): a signal is on the bus ONLY if its producer is
## not a stable boot-time autoload at consumer-connect time (transient/unauthored), OR
## if it is a world-state broadcast with an unbounded consumer set. Adding a signal
## outside these criteria is `bus_by_default` (forbidden pattern, control-manifest.md).
##
## MVP roster (CLOSED — additions require amending ADR-0002):
##   encounter_resolved — world relay from Overworld Navigation → ZWM, EZ, Map UI,
##       ScreenManager, SaveLoad autosave. Criterion 1+2.
##   zone_states_changed — ZWM zone-state batch → Map UI, audio, autosave. Criterion 2.
##   zone_entered — ZWM zone entry → EZ context, UI, audio, autosave. Criterion 2.
##
## DO NOT declare battle signals here — they are owner-declared on BattleController
## and TBC emits them directly (ADR-0002). Static contract test asserts no `battle_ended`
## on EventBus and no `encounter_resolved` on BattleController.
##
## ADR-0004 inertness rule: zero _ready work. This autoload has no _ready at all.
extends Node

## World relay — sole producer: Overworld Navigation (maps TBC.battle_ended outcome to
## result/encounter_type and emits here). Consumers: Zone & World Map (win_count++),
## Encounter Zone (gate re-eval), ScreenManager (battle screen teardown), SaveLoad
## (deferred autosave). Criterion 1+2.
##
## [param result] — WIN=1, LOSS=2, FLEE=3 (maps TBC Outcome, narrowed vocabulary).
## [param encounter_type] — WILD=1, BOSS=2 (attached by Overworld Navigation at trigger time).
signal encounter_resolved(result: int, encounter_type: int)

## World-state batch — sole producer: Zone & World Map. Consumers: Map UI (animate changed
## zones), audio, SaveLoad autosave. Suppressed when the transitions array is empty
## (ZWM suppression rule). Criterion 2.
##
## [param transitions] — Array[Dictionary], each entry: {zone_id: StringName,
##     from_state: int, to_state: int}. Read-only; subscribers that mutate must copy first.
signal zone_states_changed(transitions: Array[Dictionary])

## Zone-entry notification — sole producer: Zone & World Map on player entry. Consumers:
## Encounter Zone (context), UI, audio, SaveLoad autosave. Criterion 2.
##
## [param zone_id] — the entered zone's stable StringName identifier.
signal zone_entered(zone_id: StringName)
