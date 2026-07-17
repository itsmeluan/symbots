# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the finished pure core be driven into the full
#   break -> harvest -> re-equip loop by a thin presentation layer?
# Date: 2026-07-17
#
# A concrete LogSink for the slice. The core requires an injected LogSink (the
# base class is @abstract and cannot be instantiated), so the harness needs one
# real implementation. Production wires a proper diagnostics sink; here we just
# route to the console. Deliberately NOT `class_name`-declared — slice code must
# not pollute the global type registry; the harness `preload()`s it.
extends LogSink

## When false, info() is swallowed to keep the harness output readable. warn/error
## always print — a content error during the slice is a finding worth seeing.
var verbose: bool = false

func info(code: StringName, detail: Dictionary) -> void:
	if verbose:
		print("      [info]  %s  %s" % [code, detail])

func warn(code: StringName, detail: Dictionary) -> void:
	print("      [WARN]  %s  %s" % [code, detail])

func error(code: StringName, detail: Dictionary) -> void:
	print("      [ERROR] %s  %s" % [code, detail])
