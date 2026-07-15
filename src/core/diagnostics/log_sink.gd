## LogSink — project-wide injected diagnostics channel (ADR-0002 §5).
##
## Every system reports diagnostics through an injected LogSink rather than
## calling `push_warning`/`push_error` directly (`global_push_diagnostics` is a
## registered forbidden pattern — CI greps `src/` for direct calls). This makes
## every diagnostic GUT-assertable: production wraps `print`/`push_warning`/
## `push_error`; tests inject a spy that records calls.
##
## Three channels (ADR-0002 §5):
##   info  — non-error breadcrumbs (boot_step trace ADR-0004, rng_seed_issued
##           ADR-0006). NOT a warning — must never be routed through `warn`.
##   warn  — recoverable anomalies.
##   error — fatal / invariant violations.
##
## This is an @abstract base: it declares the contract but cannot be
## instantiated. The production implementation and test spies extend it.
## Test spies are `preload()`-ed, NOT `class_name`-declared — a `class_name` in
## `tests/` would enter the production global class registry (ADR-0002 §5).
@abstract
class_name LogSink
extends RefCounted

## Non-error breadcrumb (e.g. boot-step trace, RNG seed issued).
@abstract func info(code: StringName, detail: Dictionary) -> void

## Recoverable anomaly worth surfacing but not fatal.
@abstract func warn(code: StringName, detail: Dictionary) -> void

## Fatal / invariant violation (e.g. content_null_entry, content_duplicate_id).
@abstract func error(code: StringName, detail: Dictionary) -> void
