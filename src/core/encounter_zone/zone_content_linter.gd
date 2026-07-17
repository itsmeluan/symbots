## ZoneContentLinter — offline content-validation linter for [ZoneDef] data (EZ-8).
##
## Pure DI core (ADR-0003): a [RefCounted] with no autoload, no scene, NO RNG, and no
## `DirAccess` content scanning. It reads zone/patch/boss defs read-only through the
## injected content (never mutates or `duplicate()`s a def) and reports content faults
## through an injected [LogSink] (never `push_warning`/`push_error`). It is the ADVISORY
## acceptance gate authored content must pass — a linter failure blocks content
## SHIPPING, not code merge (per the AC severities).
##
## These linters run NOW against test fixtures; the real MVP zone `.tres` (one zone,
## 3–4 patches from ~8 WILD enemies, 2 bosses) is a deferred authoring pass (OQ-EZ-1)
## that will be validated against these same checks.
##
## Severity discipline (Control Manifest guardrail): structural/scope faults are
## **errors** (block shipping); the Rule 2a weight-floor shortfalls (identity-enemy
## 10%, farmable 20%) are **warnings** (authoring nudges), matching the AC tags.
##
## Usage:
## [codeblock]
##   var linter := ZoneContentLinter.new(log_sink, enemy_db_reader)
##   var ok := linter.validate_zone_scope(zone) and linter.validate_boss_config(zone) and ...
## [/codeblock]
class_name ZoneContentLinter
extends RefCounted

## Density-band encounter-rate anchors (Rule 5 / GDD Section G Tuning Knobs). The
## linter IS the enforcement of these tuning anchors — content whose `encounter_rate`
## drifts off its band anchor is flagged. Kept as documented constants (not a def
## field) because the band→rate mapping is the acceptance criterion itself.
const RATE_SPARSE := 0.07
const RATE_STANDARD := 0.15
const RATE_DENSE := 0.35
## Float comparison tolerance for band-anchor checks (AC-EZ-10/11/12).
const RATE_EPSILON := 1e-9
## Minimum DENSE/STANDARD pacing ratio — below this the fast-farm biome isn't worth
## seeking out (AC-EZ-13 / Tuning Knob warning 2). Default 0.35/0.15 ≈ 2.33 passes.
const PACING_RATIO_FLOOR := 1.6

## MVP content scope bounds (Rule 11).
const MVP_PATCH_MIN := 3
const MVP_PATCH_MAX := 4
const MVP_WILD_MIN := 6
const MVP_WILD_MAX := 10
const MVP_BOSS_COUNT := 2
## Boss 2's first-access `required_wins` must exceed Boss 1's by at least this — the
## machine-checkable escalation gap (AC-EZ-49; 10 − 6 = 4 passes).
const ESCALATION_GAP_MIN := 3

## Rule 2a weight floors as a fraction of a patch's total weight.
const IDENTITY_WEIGHT_FLOOR := 0.10  ## A2: ≥1 exclusive enemy at ≥10% of patch weight.
const FARMABLE_WEIGHT_FLOOR := 0.20  ## B: every farmable-target entry at ≥20%.

var _log: LogSink
## Enemy DB reader interface — borrowed, read-only (`get_enemy(id) -> EnemyDef`, null
## for unknown). Used by the boss-id resolution check (AC-EZ-51). Optional so linters
## that don't resolve enemy ids can omit it.
var _enemy_db: Variant


## Inject the diagnostics sink and (optionally) the Enemy DB reader. Both borrowed;
## the linter never mutates the defs it reads.
func _init(log: LogSink = null, enemy_db: Variant = null) -> void:
	_log = log
	_enemy_db = enemy_db


# --- Density-band rate mapping (AC-EZ-10/11/12/13/14) ------------------------

## Map a [enum TerrainPatch.DensityClass] to its canonical `encounter_rate` anchor
## (AC-EZ-10/11/12). An unrecognized band (INVALID / out-of-range) is a content
## **error** and falls back CONSERVATIVELY to STANDARD 0.15 — never DENSE (AC-EZ-14):
## an unknown band must not silently become a fast-farm biome.
func density_band_rate(density_class: int) -> float:
	match density_class:
		TerrainPatch.DensityClass.SPARSE:
			return RATE_SPARSE
		TerrainPatch.DensityClass.STANDARD:
			return RATE_STANDARD
		TerrainPatch.DensityClass.DENSE:
			return RATE_DENSE
		_:
			if _log != null:
				_log.error(&"ez_unknown_density_class", {&"density_class": density_class})
			return RATE_STANDARD


## Validate that a patch's authored `encounter_rate` matches its density band anchor
## within [constant RATE_EPSILON] (AC-EZ-10/11/12). An off-anchor rate is a content
## **warning** naming the patch, the band, and the expected anchor.
func validate_patch_encounter_rate(patch: TerrainPatch) -> bool:
	var anchor := density_band_rate(patch.density_class)
	if absf(patch.encounter_rate - anchor) >= RATE_EPSILON:
		if _log != null:
			_log.warn(&"ez_encounter_rate_off_band", {
				&"terrain_type": patch.terrain_type,
				&"density_class": patch.density_class,
				&"encounter_rate": patch.encounter_rate,
				&"expected": anchor,
			})
		return false
	return true


## Validate the DENSE/STANDARD pacing ratio is at least [constant PACING_RATIO_FLOOR]
## (AC-EZ-13). Rates are passed in so a fixture can exercise both a passing (0.35/0.15
## = 2.33) and a failing (0.21/0.15 = 1.4) ratio. Below the floor is a content warning.
func validate_pacing_ratio(dense_rate: float, standard_rate: float) -> bool:
	var ratio := dense_rate / standard_rate
	if ratio < PACING_RATIO_FLOOR:
		if _log != null:
			_log.warn(&"ez_pacing_ratio_too_low", {&"ratio": ratio, &"floor": PACING_RATIO_FLOOR})
		return false
	return true


# --- MVP scope linters (AC-EZ-47/48/49/50/51) -------------------------------

## Validate a zone's own scope (AC-EZ-47): a non-empty `zone_id` and `spawn_enabled`.
## (The "exactly one zone" MVP bound is a catalog-level check; this validates the
## single ZoneDef.) Each fault is a content error; returns false on any.
func validate_zone_scope(zone: ZoneDef) -> bool:
	var ok := true
	if zone.zone_id == &"":
		if _log != null:
			_log.error(&"ez_zone_id_invalid", {&"zone_id": zone.zone_id})
		ok = false
	if not zone.spawn_enabled:
		if _log != null:
			_log.error(&"ez_zone_spawn_disabled", {&"zone_id": zone.zone_id})
		ok = false
	return ok


## Validate patch-level scope (AC-EZ-48): the zone has [constant MVP_PATCH_MIN]–[constant
## MVP_PATCH_MAX] terrain patches, every patch has a non-empty sub-pool, and every
## entry carries a positive `spawn_weight` (>= 1). Each fault is a content error;
## returns false on any.
func validate_patch_scope(zone: ZoneDef) -> bool:
	var ok := true
	var count := zone.terrain_patches.size()
	if count < MVP_PATCH_MIN or count > MVP_PATCH_MAX:
		if _log != null:
			_log.error(&"ez_patch_count_out_of_range", {&"zone_id": zone.zone_id, &"count": count})
		ok = false
	for patch in zone.terrain_patches:
		if patch.enemy_subpool.is_empty():
			if _log != null:
				_log.error(&"ez_patch_subpool_empty", {&"terrain_type": patch.terrain_type})
			ok = false
		for entry in patch.enemy_subpool:
			if entry.spawn_weight < 1:
				if _log != null:
					_log.error(&"ez_spawn_weight_non_positive", {
						&"terrain_type": patch.terrain_type,
						&"enemy_id": entry.enemy_id,
						&"spawn_weight": entry.spawn_weight,
					})
				ok = false
	return ok


## Validate the MVP boss configuration (AC-EZ-49 / Rule 11). Enforces the STRUCTURE,
## not the literal tuning values: exactly [constant MVP_BOSS_COUNT] bosses, both
## `OVERWORLD` + `WIN_COUNT` + `LIGHTER_REGATE` (no reserved gate types); Boss 1 (index
## 0) carries no `requires_defeated`; Boss 2 (index 1) back-references Boss 1's
## `boss_id`; and the escalation gap `required_wins[Boss2] − required_wins[Boss1] >=`
## [constant ESCALATION_GAP_MIN]. Each fault is a content error; returns false on any.
func validate_boss_config(zone: ZoneDef) -> bool:
	var bosses := zone.boss_encounters
	if bosses.size() != MVP_BOSS_COUNT:
		if _log != null:
			_log.error(&"ez_boss_count_invalid", {&"zone_id": zone.zone_id, &"count": bosses.size()})
		return false
	var ok := true
	for b in bosses:
		if b.placement != BossEncounter.Placement.OVERWORLD:
			if _log != null:
				_log.error(&"ez_boss_placement_invalid", {&"boss_id": b.boss_id, &"placement": b.placement})
			ok = false
		if b.gate_type != BossEncounter.GateType.WIN_COUNT:
			if _log != null:
				_log.error(&"ez_boss_gate_type_invalid", {&"boss_id": b.boss_id, &"gate_type": b.gate_type})
			ok = false
		if b.repeat_policy != BossEncounter.RepeatPolicy.LIGHTER_REGATE:
			if _log != null:
				_log.error(&"ez_boss_repeat_policy_invalid", {&"boss_id": b.boss_id, &"repeat_policy": b.repeat_policy})
			ok = false
	var boss1 := bosses[0]
	var boss2 := bosses[1]
	if boss1.gate_params.has(&"requires_defeated"):
		if _log != null:
			_log.error(&"ez_boss_unexpected_prereq", {&"boss_id": boss1.boss_id})
		ok = false
	var prereq: StringName = boss2.gate_params.get(&"requires_defeated", &"")
	if prereq != boss1.boss_id:
		if _log != null:
			_log.error(&"ez_boss_prereq_mismatch", {
				&"boss_id": boss2.boss_id,
				&"requires_defeated": prereq,
				&"expected": boss1.boss_id,
			})
		ok = false
	var w1: int = boss1.gate_params.get(&"required_wins", 0)
	var w2: int = boss2.gate_params.get(&"required_wins", 0)
	if w2 - w1 < ESCALATION_GAP_MIN:
		if _log != null:
			_log.error(&"ez_boss_escalation_gap_too_small", {
				&"boss1_wins": w1,
				&"boss2_wins": w2,
				&"gap": w2 - w1,
			})
		ok = false
	return ok


## Validate the de-duplicated WILD enemy count across all patches is within
## [constant MVP_WILD_MIN]–[constant MVP_WILD_MAX] (AC-EZ-50, target ~8). Out of band
## is a content error.
func validate_wild_count(zone: ZoneDef) -> bool:
	var unique := {}
	for patch in zone.terrain_patches:
		for entry in patch.enemy_subpool:
			unique[entry.enemy_id] = true
	var count := unique.size()
	if count < MVP_WILD_MIN or count > MVP_WILD_MAX:
		if _log != null:
			_log.error(&"ez_wild_count_out_of_range", {&"zone_id": zone.zone_id, &"count": count})
		return false
	return true


## Validate every `boss_id` resolves to a `BOSS`-class, `spawn_enabled` Enemy DB entry
## (AC-EZ-51). A missing id, a disabled entry, or a wrong-class entry is a content
## error naming the boss; returns false on any. Requires the injected Enemy DB reader.
func validate_boss_ids_resolve(zone: ZoneDef) -> bool:
	var ok := true
	for boss in zone.boss_encounters:
		var def: EnemyDef = _enemy_db.get_enemy(boss.boss_id) if _enemy_db != null else null
		if def == null:
			if _log != null:
				_log.error(&"ez_boss_enemy_missing", {&"boss_id": boss.boss_id})
			ok = false
			continue
		if not def.spawn_enabled:
			if _log != null:
				_log.error(&"ez_boss_enemy_disabled", {&"boss_id": boss.boss_id})
			ok = false
		if def.enemy_class != EnemyDef.EnemyClass.BOSS:
			if _log != null:
				_log.error(&"ez_boss_enemy_wrong_class", {&"boss_id": boss.boss_id, &"enemy_class": def.enemy_class})
			ok = false
	return ok


# --- Terrain-identity invariants (AC-EZ-54, Rule 2a) ------------------------

## Validate the terrain-identity authoring invariants (AC-EZ-54 / Rule 2a) that make
## "terrain = targeting lever" real:
## - **A (error):** every patch must contain ≥ 1 `enemy_id` present in no other patch
##   (its identity enemy). A zone where all patches share one pool (cosmetic terrain)
##   fails.
## - **A2 (warning):** at least one such patch-exclusive enemy must be ≥ [constant
##   IDENTITY_WEIGHT_FLOOR] of the patch's total weight — closes the token-exclusive
##   loophole (a weight-1 exclusive in a 100-weight pool passes A but warns on A2).
## - **B (warning):** every `is_farmable_target` entry must be ≥ [constant
##   FARMABLE_WEIGHT_FLOOR] of its patch's total weight.
##
## Returns true iff A holds for every patch (A2/B are warnings that never flip the
## return value — they are authoring nudges, not shipping blockers).
func validate_terrain_identity(zone: ZoneDef) -> bool:
	var membership := _patch_membership(zone)
	var ok := true
	for patch in zone.terrain_patches:
		var total := _patch_total_weight(patch)
		var exclusives: Array[SpawnEntry] = []
		for entry in patch.enemy_subpool:
			if int(membership.get(entry.enemy_id, 0)) == 1:
				exclusives.append(entry)
		# A: at least one zone-exclusive enemy.
		if exclusives.is_empty():
			if _log != null:
				_log.error(&"ez_terrain_no_identity_enemy", {&"terrain_type": patch.terrain_type})
			ok = false
		else:
			# A2: at least one exclusive at or above the identity weight floor.
			var has_weighty_exclusive := false
			for entry in exclusives:
				if total > 0 and float(entry.spawn_weight) >= IDENTITY_WEIGHT_FLOOR * float(total):
					has_weighty_exclusive = true
					break
			if not has_weighty_exclusive and _log != null:
				_log.warn(&"ez_identity_enemy_below_weight_floor", {
					&"terrain_type": patch.terrain_type,
					&"total_weight": total,
				})
		# B: every farmable-target entry at or above the farmable weight floor.
		for entry in patch.enemy_subpool:
			if entry.is_farmable_target and total > 0 and float(entry.spawn_weight) < FARMABLE_WEIGHT_FLOOR * float(total):
				if _log != null:
					_log.warn(&"ez_farmable_below_weight_floor", {
						&"terrain_type": patch.terrain_type,
						&"enemy_id": entry.enemy_id,
						&"spawn_weight": entry.spawn_weight,
						&"total_weight": total,
					})
	return ok


## Count, per unique `enemy_id`, how many DISTINCT patches contain it (dedup within a
## patch). An enemy with count 1 is exclusive to its single patch.
func _patch_membership(zone: ZoneDef) -> Dictionary:
	var membership := {}
	for patch in zone.terrain_patches:
		var seen := {}
		for entry in patch.enemy_subpool:
			if seen.has(entry.enemy_id):
				continue
			seen[entry.enemy_id] = true
			membership[entry.enemy_id] = int(membership.get(entry.enemy_id, 0)) + 1
	return membership


## Sum of a patch's `spawn_weight`s (EZ-2's `total_weight`, recomputed read-only).
func _patch_total_weight(patch: TerrainPatch) -> int:
	var total := 0
	for entry in patch.enemy_subpool:
		total += entry.spawn_weight
	return total
