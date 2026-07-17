## SaveLoadService — the single persistence host (ADR-0001).
##
## Owns the file format, the provider-domain registry, disk I/O, and the save
## budget. This is the ADR-0001 **purity carve-out**: it lives in `src/` but NOT
## `src/core/` — core stays free of `FileAccess`/`DirAccess`, and this host owns
## all disk contact. Providers stay pure (their `snapshot()`/`restore()`/
## `rederive()` touch only their own in-memory plain data).
##
## Story SL-1 delivers the host shell + the provider registry + the injected
## LogSink seam. The envelope, SL-PRED-1 predicate, two-phase restore, atomic
## write, budget guard, opaque-provider preservation, and emergency save land in
## SL-2..SL-5. The `drop` provider is wired in SL-6.
##
## Diagnostics route through the injected LogSink — never global
## `push_warning`/`push_error` (ADR-0002 §5, `global_push_diagnostics` forbidden).
class_name SaveLoadService
extends RefCounted

## Save-file envelope version (ADR-0001). Bumped only on a breaking envelope
## change; the SL-PRED-1 predicate (SL-2) gates restore against it.
const SAVE_FORMAT_VERSION := 1

## Hard iOS persistence budget (ADR-0001). Enforced by an explicit Release-firing
## guard in SL-4 (never `assert`-only).
const MAX_SAVE_BYTES := 2_097_152   # 2 MiB
const MAX_WRITE_MS := 50            # target synchronous-write ceiling (measured on iOS)

## Injected diagnostics channel. Never call global push_* — route through this.
var _log: LogSink

## Injected file backend (real FileAccess/DirAccess in production; a fake in
## tests). Unused in SL-1; wired in SL-3.
var _backend

## Registry of provider domains, keyed by a stable StringName (ADR-0001).
## Each value duck-types the provider contract: snapshot()/restore()/rederive().
var _providers: Dictionary = {}

## Opaque hold for provider keys present in a loaded file with no registered
## provider (a newer build, or a removed provider). Deep-copied at load, written
## back verbatim on next save — player history is never destroyed by a build
## difference (ADR-0001 rule 3). Keyed by the provider key; values are deep copies.
var _held_opaque: Dictionary = {}

## Serialized-save byte ceiling. Defaults to the ADR-0001 constant; overridable
## by tests to exercise the Release-firing budget guard without a 2 MiB string.
var _max_save_bytes: int = MAX_SAVE_BYTES

## The slot most recently written or loaded — the target for save_emergency()
## (ADR-0001 rule 8). Defaults to slot 0.
var _active_slot: int = 0

## SL-PRED-1 verdict (ADR-0001, structurally identical to EP-PRED-1).
enum Verdict { RESTORE, MIGRATE, REFUSE }


## Construct with injected dependencies. A null LogSink is tolerated (no-op
## diagnostics) so the host is trivially constructible in tests; production wires
## the real sink + backend at boot (ADR-0004).
func _init(log: LogSink = null, backend = null) -> void:
	_log = log
	_backend = backend


## Register a provider under a stable StringName key (ADR-0001).
##
## Duplicate-key registration is a **hard programmer error**, not a silent
## last-wins: the first-registered provider is retained and an error is routed
## through the injected LogSink. (Fail-loud — a silent replace would mask a
## boot-wiring bug that drops a whole domain from the save.)
func register_provider(key: StringName, provider) -> void:
	if _providers.has(key):
		_report_error(&"save_provider_duplicate_key", {"key": key})
		return  # retain the first registration; do NOT replace
	_providers[key] = provider


## True if a provider is registered under `key`.
func has_provider(key: StringName) -> bool:
	return _providers.has(key)


## The provider registered under `key`, or null if none. Internal lookup seam
## used by the save/restore orchestration (SL-2+).
func get_provider(key: StringName):
	return _providers.get(key, null)


## Count of registered providers.
func provider_count() -> int:
	return _providers.size()


## Persist every registered provider to `slot` via an atomic write (ADR-0001).
##
## Assembles the envelope, encodes pretty JSON, then writes atomically: tmp →
## verify the full failure surface → flush → close → rotate `.bak` →
## `rename_absolute` tmp → final. A failed write leaves the previous save fully
## intact (the tmp is discarded). Returns `{ok=true}` | `{ok=false, reason}`.
func save(slot: int) -> Dictionary:
	_ensure_backend()
	_active_slot = slot
	var json_str := JSON.stringify(snapshot_envelope(), "\t")
	# Release-firing budget guard (ADR-0001 Impl guideline). An explicit `if`, not
	# an `assert` — asserts are stripped from Release exports, so an assert-only
	# guard would not exist for real players. to_utf8_buffer() allocates the full
	# byte buffer to measure it: fine once per save, never per-frame.
	if json_str.to_utf8_buffer().size() >= _max_save_bytes:
		_report_error(&"save_budget_exceeded", {"bytes": json_str.to_utf8_buffer().size(), "limit": _max_save_bytes})
		return {ok = false, reason = "budget_exceeded"}
	assert(json_str.to_utf8_buffer().size() < MAX_SAVE_BYTES)  # redundant dev-only tripwire
	return _atomic_write(_slot_path(slot), json_str)


## True if a completed save exists at `slot`.
func has_save(slot: int) -> bool:
	_ensure_backend()
	return _backend.exists(_slot_path(slot))


## Load `slot`: parse → SL-PRED-1 → two-phase restore (ADR-0001 rules 1, 6).
##
## The load path is **read-only** — it never writes, so an unparseable save is
## never destroyed. On a corrupt primary it falls back to the one-generation
## `.bak`; if both fail to parse it surfaces `{ok=false, reason="corrupt"}` with
## the bytes left intact. A slot with no file at all is `{ok=false,
## reason="no_save"}` (→ new game), distinct from corruption. On success returns
## `{ok=true}` (or `{ok=true, reason="recovered_from_bak"}` when the `.bak` saved us).
func load(slot: int) -> Dictionary:
	_ensure_backend()
	_active_slot = slot
	var final_path := _slot_path(slot)
	var bak_path := final_path + ".bak"

	# Missing (not corrupt) → new game.
	if not _backend.exists(final_path) and not _backend.exists(bak_path):
		return {ok = false, reason = "no_save"}

	# Try the primary file first.
	var primary := _parse_file(final_path)
	if primary["ok"]:
		return restore_envelope(primary["dict"])

	# Primary missing/corrupt → fall back to the one-generation backup.
	var backup := _parse_file(bak_path)
	if backup["ok"]:
		var res := restore_envelope(backup["dict"])
		if res.get("ok", false):
			res["reason"] = "recovered_from_bak"
		return res

	# Both unparseable — surface, and DO NOT overwrite the bytes.
	_report_error(&"save_corrupt_unrecoverable", {"slot": slot})
	return {ok = false, reason = "corrupt"}


## Synchronous emergency save to the active slot (ADR-0001 rule 8 — the API behind
## ADR-0004's app-pause mitigation). Reuses the IDENTICAL envelope + atomic-write
## path as save() — no special format, no shortcuts (a corrupted emergency save
## would be worse than none). If the OS cuts it off mid-tmp, the atomic design
## already guarantees the prior save survives. Call ONLY from the app-lifecycle
## handler on the Game root — never from gameplay code.
func save_emergency() -> Dictionary:
	return save(_active_slot)


## Read + JSON-parse a file. Returns `{ok=true, dict}` only when the content
## parses to a Dictionary; a missing file, unparseable JSON, or a valid-but-non-
## Dictionary payload (bare array / null) is `{ok=false}` — treated as corrupt so
## the caller falls back to `.bak` rather than feeding junk to the predicate.
func _parse_file(path: String) -> Dictionary:
	if not _backend.exists(path):
		return {ok = false}
	# Use an instance parse (not the static JSON.parse_string): it returns an
	# Error code QUIETLY instead of routing a corrupt save to the global
	# push_error channel — consistent with the injected-logger rule (ADR-0001
	# rule 7). A corrupt save is an expected, handled path, not an engine error.
	var json := JSON.new()
	if json.parse(_backend.read_text(path)) != OK:
		return {ok = false}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {ok = false}
	return {ok = true, dict = json.data}


## Canonical on-disk path for a save slot.
func _slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot


## Lazily wire the real FileBackend when none was injected (production autoload);
## tests inject a fake and skip this.
func _ensure_backend() -> void:
	if _backend == null:
		_backend = FileBackend.new()


## Atomic write with the full failure surface (ADR-0001 rule 5 + Impl guideline).
##
## The `store_string()` bool is necessary but NOT sufficient — on iOS a full-disk
## / sandbox-denial surfaces via `get_error()`, not the bool. A write counts as
## successful only when open, bool, AND post-write error are all clean. Every
## early return closes the handle; a failed write discards the tmp and never
## rotates, so the previous save survives byte-identical.
func _atomic_write(final_path: String, json_str: String) -> Dictionary:
	var tmp_path := final_path + ".tmp"
	var bak_path := final_path + ".bak"

	var fa = _backend.open_write(tmp_path)   # untyped — Variant dispatch (ptrcall gotcha)
	if fa == null:
		return {ok = false, reason = "open failed: %s" % error_string(_backend.last_open_error())}

	var wrote: bool = fa.store_string(json_str)
	var err: int = fa.get_error()
	fa.flush()   # mandatory before close on iOS
	fa.close()
	if not wrote or err != OK:
		_backend.remove(tmp_path)   # discard the partial tmp; prior save intact
		return {ok = false, reason = "write failed: %s" % error_string(err)}

	# Promote atomically — only AFTER the tmp write is proven good. Rotate the
	# current file to a one-generation .bak, then rename tmp → final.
	if _backend.exists(final_path):
		_backend.rename(final_path, bak_path)
	var rename_err: int = _backend.rename(tmp_path, final_path)
	if rename_err != OK:
		return {ok = false, reason = "rename failed: %s" % error_string(rename_err)}
	return {ok = true}


## Assemble the full save envelope from every registered provider (ADR-0001).
##
## Returns `{ "save_format_version": <CURRENT>, "providers": { key → snapshot } }`.
## `save_format_version` is a FILE-LEVEL (outer) key owned by Save/Load — it never
## lives inside a provider's blob. In-memory only; SL-3 wraps this with JSON
## encode + atomic write.
func snapshot_envelope() -> Dictionary:
	var providers_blob: Dictionary = {}
	for key in _providers:
		providers_blob[key] = _providers[key].snapshot()
	# Write back any held opaque unknown-provider blobs — but a registered
	# provider always wins its own key (the opaque path is only for keys with NO
	# registered provider, ADR-0001 rule 3).
	for key in _held_opaque:
		if not providers_blob.has(key):
			providers_blob[key] = _held_opaque[key]
			_report_warn(&"save_opaque_provider_preserved", {"key": key})
	return {
		"save_format_version": SAVE_FORMAT_VERSION,
		"providers": providers_blob,
	}


## Apply SL-PRED-1 + two-phase restore to an in-memory envelope (ADR-0001).
##
## Returns `{ok=true}` on a RESTORE verdict, else `{ok=false, reason}`. A non-
## RESTORE verdict (REFUSE / MIGRATE-with-no-hook) touches **no** provider — the
## "leaves in-memory state exactly as before load()" guarantee. SL-3 wraps this
## with the file read + parse.
func restore_envelope(envelope: Dictionary) -> Dictionary:
	var verdict := _classify(envelope)
	match verdict:
		Verdict.RESTORE:
			_capture_opaque(envelope)
			_apply_two_phase_restore(envelope)
			return {ok = true}
		Verdict.MIGRATE:
			# The MIGRATE branch exists but carries zero hooks at v1, so every
			# older blob is behaviorally REFUSE until the first real format break
			# registers a migration hook (ADR-0001 Migration Plan; mirrors EP Rule 9).
			return {ok = false, reason = "migrate_no_hook"}
		_:
			return {ok = false, reason = "refuse_version"}


## Classify an envelope's `save_format_version` per SL-PRED-1 (ADR-0001):
## `== CURRENT → RESTORE`, `< CURRENT → MIGRATE`, `> CURRENT → REFUSE`,
## missing key or non-integer value → REFUSE.
##
## The int guard matters: `JSON.parse_string` returns every number as `float`, so
## an integral float (`1.0`) is a valid version, but a string (`"1"`), a bool, or
## a non-integral float (`1.5`) is malformed → REFUSE.
func _classify(envelope: Dictionary) -> Verdict:
	if not envelope.has("save_format_version"):
		return Verdict.REFUSE
	var raw = envelope["save_format_version"]
	var version: int
	match typeof(raw):
		TYPE_INT:
			version = raw
		TYPE_FLOAT:
			if raw != floor(raw):
				return Verdict.REFUSE   # non-integral float is malformed
			version = int(raw)
		_:
			return Verdict.REFUSE       # string / bool / anything else is malformed
	if version == SAVE_FORMAT_VERSION:
		return Verdict.RESTORE
	if version < SAVE_FORMAT_VERSION:
		return Verdict.MIGRATE
	return Verdict.REFUSE


## Two-phase, order-independent restore (ADR-0001 rule 4).
## Phase 1: every provider restores raw facts (NO cross-provider reads). Phase 2:
## every provider rederives its own derived state. Two separate loops — never
## interleaved — so a Phase-1 restore can never observe a Phase-2 rederive output,
## which is what makes the outcome independent of registration order.
func _apply_two_phase_restore(envelope: Dictionary) -> void:
	var providers_blob: Dictionary = envelope.get("providers", {})
	# Phase 1 — raw facts.
	for key in _providers:
		if providers_blob.has(key):
			_providers[key].restore(providers_blob[key])
	# Phase 2 — provider-local rederive.
	for key in _providers:
		_providers[key].rederive()


## Deep-copy provider keys that have NO registered provider into the opaque hold
## (ADR-0001 rule 3). The deep copy (`duplicate(true)`) is mandatory — a live
## reference into the parsed blob could be corrupted by a later mutation of the
## source, silently losing the held player history.
func _capture_opaque(envelope: Dictionary) -> void:
	var providers_blob: Dictionary = envelope.get("providers", {})
	for key in providers_blob:
		if not _providers.has(key):
			var val = providers_blob[key]
			_held_opaque[key] = val.duplicate(true) if val is Dictionary or val is Array else val


## Cast a JSON-sourced numeric value back to `int`. `JSON.parse_string` returns
## every number as `float`; a monotonic-ID / counter field left as `float` is a
## latent bug. Providers apply this in their own `restore()` (ADR-0001 Impl
## guideline); the round-trip tests assert `typeof == TYPE_INT`, not just values.
static func as_int(v) -> int:
	return int(v)


## Route a warning through the injected sink if present.
func _report_warn(code: StringName, detail: Dictionary) -> void:
	if _log != null:
		_log.warn(code, detail)


## Route an error through the injected sink if one is present. Never falls back
## to a global push_* (that is the forbidden pattern this seam exists to avoid).
func _report_error(code: StringName, detail: Dictionary) -> void:
	if _log != null:
		_log.error(code, detail)
