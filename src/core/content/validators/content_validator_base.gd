## ContentValidatorBase — shared diagnostic machinery for the per-DB validator
## helpers that compose [ContentValidator].
##
## Provides [member _errors], [member _warnings], [member _log], and the two
## accumulator methods ([method _error] / [method _warn]) so every family helper
## can route findings through the injected [LogSink] in lock-step with the
## returned arrays.  State is set up by [ContentValidator] before each helper is
## used — helpers must NOT reset state themselves.
##
## ADR-0003 §5 rules apply here too:
## - Never call `push_error`/`push_warning` — use [method _error] / [method _warn].
## - All findings are routed through the injected [LogSink] only.
extends RefCounted

## Accumulated fatal findings — populated by [method _error].
var _errors: Array[Dictionary] = []

## Accumulated non-fatal findings — populated by [method _warn].
var _warnings: Array[Dictionary] = []

## Injected log sink (set by [ContentValidator] before each call).
var _log: LogSink


## Record a fatal finding: append to [member _errors] AND surface it through the
## injected [LogSink].  The two stay in lock-step so a GUT spy can assert on either.
func _error(code: StringName, detail: Dictionary) -> void:
	_errors.append({"code": code, "detail": detail})
	_log.error(code, detail)


## Record a non-fatal authoring warning: append to [member _warnings] AND surface
## it through the [LogSink].  Warnings never affect `ok`.
func _warn(code: StringName, detail: Dictionary) -> void:
	_warnings.append({"code": code, "detail": detail})
	_log.warn(code, detail)
