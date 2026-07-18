## Log — production LogSink host (ADR-0002 §5, ADR-0004 §1 slot 2).
##
## Exposes the single production LogSink instance as `Log.sink`. Consumers inject
## `Log.sink` into systems that need diagnostics. The sink is constructed here (not
## in _ready) because autoload field initializers run before _ready and before any
## other autoload connects to anything — guaranteeing `Log.sink` is non-null by
## the time any system references it.
##
## ADR-0004 inertness rule: zero _ready work. No I/O, no catalog loads, no signal
## connections, no cross-autoload reads.
##
## All diagnostic calls in src/ must route through an injected LogSink — never
## push_warning() / push_error() directly (`global_push_diagnostics` forbidden).
extends Node

## The active LogSink instance. Constructed at field initialization time so it is
## available before _ready runs on any node. Declared as LogSink so inference stays
## typed (not Variant) — matches the ADR-0004 boot_screen guidance.
var sink: LogSink = _ProductionLogSink.new()


## Production implementation of LogSink: routes info → print, warn → push_warning,
## error → push_error. Declared as an inner class so it is local to this autoload
## and does NOT register a class_name into the global registry (ADR-0002 §5).
class _ProductionLogSink extends LogSink:
	## Non-error breadcrumb (boot_step trace, rng_seed_issued, etc.).
	## Routes through print — NOT push_warning (info is not a recoverable anomaly).
	func info(code: StringName, detail: Dictionary) -> void:
		print("[INFO] %s %s" % [code, detail])

	## Recoverable anomaly — surfaces via push_warning so it appears in editor Output.
	func warn(code: StringName, detail: Dictionary) -> void:
		push_warning("[WARN] %s %s" % [code, detail])

	## Fatal / invariant violation — surfaces via push_error for the crash reporter.
	func error(code: StringName, detail: Dictionary) -> void:
		push_error("[ERROR] %s %s" % [code, detail])
