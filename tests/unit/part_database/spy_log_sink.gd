## Test spy for LogSink — records every diagnostic call for assertion.
##
## preload()-ed, NOT class_name-declared (ADR-0002 §5): a class_name in tests/
## would pollute the production global class registry.
extends LogSink

var infos: Array[Dictionary] = []
var warns: Array[Dictionary] = []
var errors: Array[Dictionary] = []

func info(code: StringName, detail: Dictionary) -> void:
	infos.append({"code": code, "detail": detail})

func warn(code: StringName, detail: Dictionary) -> void:
	warns.append({"code": code, "detail": detail})

func error(code: StringName, detail: Dictionary) -> void:
	errors.append({"code": code, "detail": detail})

## Convenience: total diagnostics recorded across all channels.
func total() -> int:
	return infos.size() + warns.size() + errors.size()
