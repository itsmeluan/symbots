## SymbotBuild — the Layer-2 stateful owner of one Symbot's 8-slot assembly (ADR-0005).
##
## A dependency-injected `RefCounted` (NOT an autoload, NOT a node): constructed with
## its tuning config, a diagnostics sink, and its upstream collaborators (Inventory,
## CoreProgression, MoveDB, PassiveDB), so GUT exercises the exact production path
## with stubs. It owns the manifest (slot → [PartInstance]), the cached `final_stat`,
## and the derived move / passive pools, and is the ONLY writer of them.
##
## It calls the pure [StatPipeline.derive] on every equip (eager recompute) and keeps
## synergy OUT of the stored `final_stat` (Rule 8 — synergy composes later at
## BATTLE_INIT via SYN-F4). Reads are passive: [method get_final_stat] returns the
## cache (a copy), never re-running the pipeline or emitting.
##
## Equip follows Assembly Rule 3 exactly: validate slot → same-part no-op → CoreProgression
## gate → displace occupant to Inventory → install → eager recompute → emit. There is
## no empty-slot / unequip-without-replacement path (TR-sa-007).
##
## Signals are owner-declared, typed, direct-connection (ADR-0002) — never EventBus
## additions. Rejections and content anomalies route through the injected [LogSink]
## (`global_push_diagnostics` forbidden); frozen defs are never mutated (ADR-0003).
class_name SymbotBuild
extends RefCounted

## Emitted after a successful equip installs a new part in [param slot_type]. Payload
## is self-sufficient and read-only (ADR-0002): the slot and the newly-installed
## part's type id. NOT emitted for a same-part no-op or a rejected equip.
signal part_equipped(slot_type: int, new_part_id: StringName)

## Emitted after a successful equip's eager recompute, carrying the fresh base-stat
## dictionary (no synergy — Rule 8). NOT emitted on a passive read (AC-SA-07).
signal stats_changed(final_stat: Dictionary)

## The universal Basic Attack move id, always occupying move slot 0. The Basic Attack
## itself is defined by the TBC GDD; Assembly only slots its id (AC-SA-12).
const BASIC_ATTACK_ID := &"basic_attack"

## Passive-pool collection order (Assembly Rule 5): CORE and LEGS first, then the
## remaining slots in slot-type order. A non-null `passive_id` is appended in this
## order; null-passive slots contribute nothing (no phantom entries — AC-SA-14).
const PASSIVE_SLOT_ORDER: Array[int] = [
	PartDef.SlotType.CORE, PartDef.SlotType.LEGS, PartDef.SlotType.CHASSIS,
	PartDef.SlotType.CHIPSET, PartDef.SlotType.ENERGY_CELL, PartDef.SlotType.HEAD,
	PartDef.SlotType.ARMS, PartDef.SlotType.WEAPON,
]

var display_name: String = ""

# Injected collaborators (duck-typed: Inventory and CoreProgression are not yet
# implemented; MoveDB / PassiveDB are autoload Nodes stubbed in tests). All optional
# so a bare build can derive stats without the content DBs wired.
var _cfg: BalanceConfig = null
var _log: LogSink = null
var _inventory = null
var _core_progression = null
var _move_db = null
var _passive_db = null

# Owned state — SymbotBuild is the sole writer.
var _manifest: Dictionary = {}          # slot_type (int) → PartInstance
var _final_stat: Dictionary = {}        # canonical stat key → int (base stats, no synergy)
var _move_pool: Array = [BASIC_ATTACK_ID, null, null, null]
var _passive_pool: Array[StringName] = []


func _init(
		cfg: BalanceConfig,
		log: LogSink,
		inventory = null,
		core_progression = null,
		move_db = null,
		passive_db = null) -> void:
	_cfg = cfg
	_log = log
	_inventory = inventory
	_core_progression = core_progression
	_move_db = move_db
	_passive_db = passive_db


## Factory (EC-SA-08): seed all 8 slots from [param starters] (slot_type →
## [PartInstance]) and run the derive once, so `final_stat`, the move pool and the
## passive pool are populated before any equip — the build is valid from frame one.
static func with_starters(
		starters: Dictionary,
		cfg: BalanceConfig,
		log: LogSink,
		inventory = null,
		core_progression = null,
		move_db = null,
		passive_db = null) -> SymbotBuild:
	var build := SymbotBuild.new(cfg, log, inventory, core_progression, move_db, passive_db)
	for slot_type in starters:
		build._manifest[slot_type] = starters[slot_type]
	build._recompute()
	return build


# ---------------------------------------------------------------------------
# Equip (Assembly Rule 3)
# ---------------------------------------------------------------------------

## Equips [param part_instance] into [param slot_type] per Assembly Rule 3. Returns a
## result dictionary: `{"ok": true}` on success (or a same-part no-op), or
## `{"ok": false, "reason": StringName, "message": String}` on rejection. On any
## rejection or no-op there is NO displacement, NO recompute, and NO signal emission.
func equip_part(slot_type: int, part_instance: PartInstance) -> Dictionary:
	# 1. Slot-type validation (AC-SA-01) — a defensive API guard, not just UI.
	if part_instance.part.slot_type != slot_type:
		return _error(&"slot_mismatch",
			"This part cannot be equipped in that slot.")

	# 1b. Same-part no-op (AC-SA-10 / EC-SA-02) — guarded on part_id, placed before the
	# gate so a redundant call is cheap and side-effect-free.
	var current: PartInstance = _manifest.get(slot_type)
	if current != null and current.part.id == part_instance.part.id:
		return _ok()

	# 1c. CoreProgression gate (the one upward call in the architecture).
	if _core_progression != null and not _core_progression.can_equip(part_instance.part):
		_log.warn(&"equip_rejected_core_level",
			{"slot": slot_type, "part": part_instance.part.id})
		return _error(&"core_level", "Core level %d required — your core is level %d." % [
			part_instance.part.level_requirement, _core_progression.get_level()])

	# 2. Displace the current occupant to Inventory at its current tier (AC-SA-04).
	if current != null and _inventory != null:
		_inventory.add(current)

	# 3. Install the incoming instance (remove it from Inventory).
	if _inventory != null:
		_inventory.remove(part_instance)
	_manifest[slot_type] = part_instance

	# 4. Eager recompute (correctness/stability covered by Story 003).
	_recompute()

	# 5. Emit — part_equipped then stats_changed.
	part_equipped.emit(slot_type, part_instance.part.id)
	stats_changed.emit(_final_stat)
	return _ok()


# ---------------------------------------------------------------------------
# Reads (passive — no recompute, no signal)
# ---------------------------------------------------------------------------

## The cached base-stat dictionary (no synergy — Rule 8), as a COPY so a caller
## mutating it cannot corrupt the stored cache (AC-SA-07). Reading never re-runs the
## pipeline nor emits `stats_changed`.
func get_final_stat() -> Dictionary:
	return _final_stat.duplicate()

## The ordered move pool: `[basic_attack, WEAPON, HEAD, ARMS]`, length 4, index 3
## nullable (AC-SA-03a). Returns a copy for caller-immutability.
func get_move_pool() -> Array:
	return _move_pool.duplicate()

## The ordered passive pool (Assembly Rule 5 order), non-null ids only. Copy returned.
func get_passive_pool() -> Array[StringName]:
	return _passive_pool.duplicate()

## The [PartInstance] currently in [param slot_type], or null if the slot is empty.
func get_equipped(slot_type: int) -> PartInstance:
	return _manifest.get(slot_type)


# ---------------------------------------------------------------------------
# Preview (SA-F2 — pure, no side effects)
# ---------------------------------------------------------------------------

## SA-F2 stat delta (AC-SA-08): the per-stat change from installing [param
## candidate_part] into [param slot_type], as a FULL hypothetical recompute over all
## canonical keys — `hypothetical[S] − current[S]`. Zero side effects: no signal, no
## Inventory write, no live-manifest or cache mutation. The candidate is previewed at
## tier +0. Chassis swaps re-apply the archetype modifier across every stat, so the
## delta can be non-zero for stats the candidate contributes nothing to (EC-SA-09).
func compute_stat_delta(slot_type: int, candidate_part: PartDef) -> Dictionary:
	return preview_swap(candidate_part, slot_type)

## ADR-0005-named alias of [method compute_stat_delta] (candidate-first arg order).
func preview_swap(candidate_part: PartDef, slot_type: int) -> Dictionary:
	var hypothetical: Dictionary = _manifest.duplicate()
	hypothetical[slot_type] = PartInstance.new(&"__preview__", candidate_part, 0)
	var hypo_final := StatPipeline.derive(
		hypothetical,
		_archetype_of(hypothetical),
		_core_level(),
		_core_level_growth(hypothetical),
		_cfg,
		_log)
	var delta: Dictionary = {}
	for key in _cfg.canonical_stat_keys:
		delta[key] = int(hypo_final.get(key, 0)) - int(_final_stat.get(key, 0))
	return delta


# ---------------------------------------------------------------------------
# Internal — recompute & pool derivation
# ---------------------------------------------------------------------------

## Eager full recompute of `final_stat` + move pool + passive pool from the current
## manifest. Called only on equip (and construction) — never mid-battle (ADR-0005
## `mid_battle_stat_recompute` forbidden).
func _recompute() -> void:
	_final_stat = StatPipeline.derive(
		_manifest,
		_archetype_of(_manifest),
		_core_level(),
		_core_level_growth(_manifest),
		_cfg,
		_log)
	_move_pool = _derive_move_pool(_manifest)
	_passive_pool = _derive_passive_pool(_manifest)


## The equipped CHASSIS part's archetype for [param manifest], or 0 (no archetype →
## neutral ×1.0 modifiers) when the CHASSIS slot is empty.
func _archetype_of(manifest: Dictionary) -> PartDef.ChassisArchetype:
	var chassis: PartInstance = manifest.get(PartDef.SlotType.CHASSIS)
	if chassis == null:
		return 0 as PartDef.ChassisArchetype
	return chassis.part.chassis_archetype


## The CORE part's `level_growth` dict for [param manifest] (empty when no CORE).
## Assembly reads `level_growth` ONLY from the CORE slot (TR-cp-009).
func _core_level_growth(manifest: Dictionary) -> Dictionary:
	var core: PartInstance = manifest.get(PartDef.SlotType.CORE)
	if core == null:
		return {}
	return core.part.level_growth


## The current Core progression level from the injected CoreProgression, defaulting to
## 1 (CP-F3 contributes 0 at level 1) when no CoreProgression is wired.
func _core_level() -> int:
	if _core_progression != null:
		return _core_progression.get_level()
	return 1


## Move pool (AC-SA-03/06/12): fixed order `[basic_attack, WEAPON, HEAD, ARMS]`. Only
## those three slots are consulted for `active_skill_id`; CORE/CHASSIS/CHIPSET/
## ENERGY_CELL are never read, even if malformed content sets a skill on them.
func _derive_move_pool(manifest: Dictionary) -> Array:
	return [
		BASIC_ATTACK_ID,
		_resolve_skill(manifest, PartDef.SlotType.WEAPON),
		_resolve_skill(manifest, PartDef.SlotType.HEAD),
		_resolve_skill(manifest, PartDef.SlotType.ARMS),
	]


## Resolves one slot's `active_skill_id` against the Move DB. Returns null for an
## empty slot, an unset skill (&""), or a skill whose Move DB entry is missing (the
## missing case logs a content error — AC-SA-06 / EC-SA-04 — never raises).
func _resolve_skill(manifest: Dictionary, slot_type: int) -> Variant:
	var inst: PartInstance = manifest.get(slot_type)
	if inst == null:
		return null
	var skill_id: StringName = inst.part.active_skill_id
	if skill_id == &"":
		return null
	if _move_db != null and not _move_db.has_move(skill_id):
		_log.error(&"content_missing_move", {"slot": slot_type, "skill_id": skill_id})
		return null
	return skill_id


## Passive pool (AC-SA-09/14, EC-SA-04): non-null `passive_id`s collected in
## [constant PASSIVE_SLOT_ORDER]. A passive whose Passive DB entry is missing is
## logged and skipped (not appended as null — the pool is a compact list).
func _derive_passive_pool(manifest: Dictionary) -> Array[StringName]:
	var pool: Array[StringName] = []
	for slot_type in PASSIVE_SLOT_ORDER:
		var inst: PartInstance = manifest.get(slot_type)
		if inst == null:
			continue
		var passive_id: StringName = inst.part.passive_id
		if passive_id == &"":
			continue
		if _passive_db != null and not _passive_db.has_passive(passive_id):
			_log.error(&"content_missing_passive",
				{"slot": slot_type, "passive_id": passive_id})
			continue
		pool.append(passive_id)
	return pool


func _ok() -> Dictionary:
	return {"ok": true}


func _error(reason: StringName, message: String) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message}
