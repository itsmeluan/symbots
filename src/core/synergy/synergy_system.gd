## SynergySystem — detects active element/manufacturer sets from an 8-slot build and
## produces the cumulative bonus block the stat pipeline folds in at SYN-F4 (Core).
##
## A dependency-injected `RefCounted` (NOT an autoload, NOT a node): constructed with
## its tier registry (`Array[SynergyTierDef]`) and a diagnostics [LogSink], so GUT
## exercises the exact production path. It owns one [member cached_bonus_block]
## (NEVER null) and one [member active_synergies] list (`Array[StringName]`, never null).
##
## Three entry points, all delegating to ONE private compute core so their outputs can
## never diverge:
##   [method evaluate]        — compute → cache → ALWAYS emit `synergy_changed` (Rule 7).
##   [method evaluate_silent] — compute → cache, NO emit (TBC's BATTLE_INIT path).
##   [method preview]         — pure hypothetical: NO cache write, NO emit (UI display).
##
## The pipeline is SYN-F1 (count each tag occurrence, null tags → []) → SYN-F2 (AND-logic
## activation with empty-requirements / min_count<1 guards) → SYN-F3 (blind additive
## stat aggregation + keep-first effect dedup in alphabetical `String(id)` tier order).
## SYN-F4 (`max(0, base + delta)`) is the CONSUMER's job (TBC / Workshop UI), never this
## class's — it only emits the delta block.
##
## Rule 8 (battle freeze) is a CALLER contract, not a self-lock: this system never sets a
## frozen flag; `evaluate()` after `evaluate_silent()` fully overwrites the cache. Battle
## code simply must not call recompute after BATTLE_INIT (control-manifest
## `mid_battle_stat_recompute`). Diagnostics route through the injected LogSink
## (`global_push_diagnostics` forbidden); tier defs are read-only (ADR-0003).
class_name SynergySystem
extends RefCounted

## Emitted by [method evaluate] after every recompute (Rule 7 — always, even when the
## block is unchanged). Payload is self-sufficient and read-only (ADR-0002): the active
## tier-id list and the fresh bonus block. NOT emitted by [method evaluate_silent] or
## [method preview].
signal synergy_changed(active_synergies: Array[StringName], bonus_block: Dictionary)

## The build has exactly 8 equipment slots; indices beyond this are ignored (EC-SYN-10).
const SLOT_COUNT := 8

## The cumulative bonus block from the last [method evaluate] / [method evaluate_silent]:
## `{ "stat_delta": {StringName: int}, "effects": Array[StringName] }`. NEVER null — an
## empty build yields empty sub-collections (TR-syn-012). [method preview] never writes it.
var cached_bonus_block: Dictionary = {}

## The active tier ids from the last commit, ascending-alphabetical by `String(id)`.
## `Array[StringName]`, NEVER null — empty build → empty list (TR-syn-012 / AC-SYN-07).
var active_synergies: Array[StringName] = []

# Injected, read-only.
var _tiers: Array = []          # Array[SynergyTierDef]
var _log: LogSink = null


func _init(tiers: Array = [], log: LogSink = null) -> void:
	_tiers = tiers
	_log = log
	cached_bonus_block = _empty_block()
	active_synergies = [] as Array[StringName]


## Recompute from [param parts] (an 8-length array of PartDef-or-null), commit to the
## cache, and ALWAYS emit `synergy_changed` (Rule 7). Returns nothing — read the result
## from [member cached_bonus_block] / [member active_synergies] or the signal payload.
func evaluate(parts: Array) -> void:
	var result := _compute(parts)
	active_synergies = result["active_synergies"]
	cached_bonus_block = result["bonus_block"]
	synergy_changed.emit(active_synergies, cached_bonus_block)


## Identical compute + commit to [method evaluate] but WITHOUT emitting — the entry TBC
## calls at BATTLE_INIT so a `synergy_changed` does not wake Workshop UI subscribers
## mid-transition (TR-syn-008). Delegates to the same private core, so its result is
## byte-for-byte what `evaluate()` would produce.
func evaluate_silent(parts: Array) -> void:
	var result := _compute(parts)
	active_synergies = result["active_synergies"]
	cached_bonus_block = result["bonus_block"]


## Pure read-only hypothetical (ADR-0008 reuse point): returns the bonus block that WOULD
## result if [param candidate] (a PartDef, or `null` to model an unequip) occupied
## [param target_slot] of [param current_parts]. Writes NOTHING and emits NOTHING
## (TR-syn-009). Out-of-range [param target_slot] returns an empty block and logs
## (Rule 9 — GDScript negative indices wrap, so the guard is explicit).
func preview(candidate, target_slot: int, current_parts: Array) -> Dictionary:
	if target_slot < 0 or target_slot >= SLOT_COUNT:
		_warn(&"synergy_preview_slot_out_of_range", {"target_slot": target_slot})
		return _empty_block()
	# Build the 8-length hypothetical without touching current_parts or the cache.
	var hypothetical: Array = []
	for i in range(SLOT_COUNT):
		hypothetical.append(current_parts[i] if i < current_parts.size() else null)
	hypothetical[target_slot] = candidate
	var result := _compute(hypothetical)
	return result["bonus_block"]


# --- Private compute core (shared by all three entry points) ----------------------

## The single count → activate → aggregate pipeline. Returns
## `{ "active_synergies": Array[StringName], "bonus_block": Dictionary }`. Pure: reads
## only [param parts] and the injected tiers; writes no instance state. Having one core
## makes evaluate / evaluate_silent / preview divergence impossible by construction.
func _compute(parts: Array) -> Dictionary:
	var counts := _count_tags(parts)
	var active := _activate(counts)
	var block := _aggregate(active)
	return {"active_synergies": active, "bonus_block": block}


## SYN-F1 — pure tag sum over slots 0..7. Each part contributes ALL its tags, counting
## every occurrence (no within-part dedup — EC-SYN-11); null / null-tag parts contribute
## nothing (EC-SYN-07). Wrong-length arrays are tolerated: missing indices are null,
## indices beyond slot 7 are ignored, and a diagnostic is logged (EC-SYN-10).
func _count_tags(parts: Array) -> Dictionary:
	if parts.size() != SLOT_COUNT:
		_warn(&"synergy_parts_wrong_length", {"size": parts.size(), "expected": SLOT_COUNT})
	var counts := {}
	var n: int = mini(parts.size(), SLOT_COUNT)
	for i in range(n):
		var part = parts[i]
		if part == null:
			continue
		var tags = part.synergy_tags
		if tags == null:
			continue
		for tag in tags:
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


## SYN-F2 — a tier activates iff EVERY `[tag, min_count]` requirement is met (AND logic).
## Malformed tiers are skipped and logged BEFORE evaluation: empty requirements
## (EC-SYN-12) and any `min_count < 1` (EC-SYN-13) both fail the vacuous-truth guard.
## Returns the active ids sorted ascending-alphabetical by `String(id)` — the same order
## SYN-F3 flattens effects in, and the order the payload's active_synergies uses.
func _activate(counts: Dictionary) -> Array[StringName]:
	var active: Array[StringName] = []
	for tier in _tiers:
		if not _tier_is_valid(tier):
			continue
		if _tier_satisfied(tier, counts):
			active.append(tier.id)
	active.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return active


## Guards a tier against vacuous activation (EC-SYN-12 / EC-SYN-13). Returns false + logs
## when the tier could fire on inputs it must not (empty requirements, or a zero/negative
## min_count).
func _tier_is_valid(tier) -> bool:
	if tier.requirements.is_empty():
		_warn(&"synergy_tier_empty_requirements", {"tier": tier.id})
		return false
	for req in tier.requirements:
		if int(req[1]) < 1:
			_warn(&"synergy_tier_min_count_below_one", {"tier": tier.id, "min_count": req[1]})
			return false
	return true


func _tier_satisfied(tier, counts: Dictionary) -> bool:
	for req in tier.requirements:
		if int(counts.get(req[0], 0)) < int(req[1]):
			return false
	return true


## SYN-F3 — aggregate the active tiers into one block. Stat deltas sum blindly (unknown
## keys pass through verbatim — EC-SYN-06). Effects flatten in the alphabetical tier order
## of [param active] and are keep-first deduplicated (TR-syn-005/006); the first tier
## alphabetically that names a shared id owns it. Effect ids pass through unfiltered — the
## system owns no effect registry (TR-syn-014 / EC-SYN-05).
func _aggregate(active: Array[StringName]) -> Dictionary:
	var by_id := {}
	for tier in _tiers:
		by_id[tier.id] = tier
	var stat_delta := {}
	var effects: Array[StringName] = []
	for id in active:
		var tier = by_id[id]
		for s in tier.stat_delta:
			stat_delta[s] = int(stat_delta.get(s, 0)) + int(tier.stat_delta[s])
		for e in tier.effects:
			if not effects.has(e):
				effects.append(e)
	return {"stat_delta": stat_delta, "effects": effects}


## A fresh, never-null empty block. Sub-collections are typed so consumers relying on the
## `effects: Array[StringName]` shape never see a bare `Array` (TR-syn-012).
func _empty_block() -> Dictionary:
	return {"stat_delta": {}, "effects": [] as Array[StringName]}


## Routes a recoverable anomaly through the injected sink (no-op if none injected). All
## Synergy diagnostics are recoverable — a malformed tier is skipped, a bad slot returns
## empty — so `warn` is the channel (never global `push_warning`, ADR-0002 §5).
func _warn(code: StringName, detail: Dictionary) -> void:
	if _log != null:
		_log.warn(code, detail)
