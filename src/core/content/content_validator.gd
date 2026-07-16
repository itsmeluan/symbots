## ContentValidator — the single content-integrity gate (ADR-0003 §5).
##
## A plain, fully dependency-injected [RefCounted]: it takes the loaded
## [ContentCatalogs] aggregate plus a [LogSink] and returns
## `{ok: bool, errors: Array[Dictionary], warnings: Array[Dictionary]}`. Two
## mounts share this ONE validator — the CI-blocking headless GUT run and the
## dev-boot fail-loud pass (release builds skip it). Every diagnostic is routed
## through the injected [LogSink] (`error(code, detail)`); it never calls
## `push_error`/`push_warning` (`global_push_diagnostics` is forbidden in `src/`,
## ADR-0002 §5 — direct engine pushes are invisible to GUT).
##
## Story 007 delivers the scaffold plus the schema / enum / nullability / range
## families for the Part DB (GDD AC-01/02/03/17/18/20/21/22/24). Story 008 EXTENDS
## this same validator (never a fork) with the content-composition families —
## synergy tags, Prototype ±/concentration, Boss-grade break condition, stat
## budgets, and Common-cap / Rare-floor primary bounds (AC-04/10/11/12/19/23).
## Those families read the [BalanceConfig] budget/cap/floor tables, so they run
## only when a config is injected via [member ContentCatalogs.balance]; the schema
## families need no config and always run. Story 009 adds the cross-DB referential
## integrity family (Part→Move / Part→Passive resolution, AC-13) plus the
## `level_requirement` rarity-floor and `level_growth` CORE-only structural checks
## (TR-part-011/012); that family runs only when a Move/Passive resolution index is
## mounted via [member ContentCatalogs.references_mounted]. `&""` (empty StringName)
## is the null-equivalent (ADR-0003).
##
## Move-DB Story 004 EXTENDS this same validator with the Move schema family
## (required fields, DAMAGE→power_tier, REPAIR/UTILITY→SELF targeting); Story 005
## adds the Move authoring-rule family (energy band, REPAIR Energy-brake,
## status↔element, non-DAMAGE rider ban). Both run only when a `MoveCatalog` is
## mounted via [member ContentCatalogs.moves] — Part-only fixtures skip them.
class_name ContentValidator
extends RefCounted

## Authored manufacturer affiliations. `&"wild"` is a real value ("no
## manufacturer"), NOT a null-equivalent; `&""` (the schema default) is invalid.
const VALID_MANUFACTURERS: Array[StringName] = [&"boltwell", &"ironclad", &"scrapjaw", &"wild"]

## MVP elemental affinities. CRYO/CORROSIVE/DATA are Full-Vision-reserved and
## must never appear in MVP content (AC-21).
const MVP_ELEMENTS: Array[int] = [
	PartDef.Element.VOLT, PartDef.Element.THERMAL, PartDef.Element.KINETIC,
]

## MVP damage types delivered by an active skill. DATA/TRUE are reserved.
const MVP_DAMAGE_TYPES: Array[int] = [PartDef.DamageType.PHYSICAL, PartDef.DamageType.ENERGY]

## Full-Vision-reserved damage types — rejected on any part, skill or not (AC-21).
const RESERVED_DAMAGE_TYPES: Array[int] = [PartDef.DamageType.DATA, PartDef.DamageType.TRUE]

## Recharge stat bound (AC-17): `stat_bonuses["recharge"]` ∈ [0, 15].
const RECHARGE_MAX := 15

## Heat generation bound (AC-22, Part-DB share only): `heat_generation` ∈ [0, 40].
const HEAT_MAX := 40

## Canonical stat key read for the recharge range/gating checks.
const RECHARGE_KEY := &"recharge"

## AC-01 (Rule 8) — slots permitted to carry an active skill. CORE and
## ENERGY_CELL are support slots (passive + stats only): an active skill on
## either is a `content_active_skill_forbidden`.
const SKILL_CAPABLE_SLOTS: Array[int] = [
	PartDef.SlotType.HEAD, PartDef.SlotType.ARMS, PartDef.SlotType.WEAPON,
	PartDef.SlotType.CHASSIS, PartDef.SlotType.LEGS, PartDef.SlotType.CHIPSET,
]

## AC-01 (Rule 8) — effect-capacity band per rarity, where an effect is a
## non-null `active_skill_id` or `passive_id` (counted separately). CEILING caps
## how many a part may carry; FLOOR is the minimum it must carry. Common is the
## only tier with a 0 floor — every Rare-or-above part brings at least one effect.
const EFFECT_CEILING: Dictionary = {
	PartDef.Rarity.COMMON: 0, PartDef.Rarity.RARE: 1,
	PartDef.Rarity.BOSS_GRADE: 2, PartDef.Rarity.PROTOTYPE: 2,
}
const EFFECT_FLOOR: Dictionary = {
	PartDef.Rarity.COMMON: 0, PartDef.Rarity.RARE: 1,
	PartDef.Rarity.BOSS_GRADE: 1, PartDef.Rarity.PROTOTYPE: 1,
}

# --- Story 008: content-composition families (run only when a BalanceConfig is
# injected via ContentCatalogs.balance; the schema families above always run) ---

## Canonical synergy tag for each MVP element (AC-04). A part's element tag must
## appear in its `synergy_tags`. Reserved elements have no MVP tag — AC-21 rejects
## those first, so this table intentionally omits them.
const ELEMENT_TAGS: Dictionary = {
	PartDef.Element.VOLT: &"volt",
	PartDef.Element.THERMAL: &"thermal",
	PartDef.Element.KINETIC: &"kinetic",
}

## Real manufacturer tags (AC-04). A non-wild part must carry its manufacturer as a
## synergy tag; a wild part must carry NONE of these. `&"wild"` is excluded — it is
## the "no manufacturer" value and never appears as a synergy tag.
const MANUFACTURER_TAGS: Array[StringName] = [&"boltwell", &"ironclad", &"scrapjaw"]

## AC-04: a part with this `manufacturer` carries no manufacturer synergy tag.
const WILD_MANUFACTURER := &"wild"

## Slot → primary stat key (AC-23 slot primary-stat mapping). ARMS and WEAPON are
## resolved per-part by `damage_type` (see [method _primary_stat_for]) and are
## intentionally absent from this table.
const PRIMARY_STAT: Dictionary = {
	PartDef.SlotType.CORE: &"energy_capacity",
	PartDef.SlotType.CHASSIS: &"structure",
	PartDef.SlotType.CHIPSET: &"processing",
	PartDef.SlotType.ENERGY_CELL: &"energy_capacity",
	PartDef.SlotType.HEAD: &"targeting",
	PartDef.SlotType.LEGS: &"mobility",
}

## AC-23 per-part primary stat for the damage_type-split ARMS / WEAPON slots.
const PHYSICAL_PRIMARY := &"physical_power"
const ENERGY_PRIMARY := &"energy_power"

## AC-11: a Boss-grade part needs a `drop_conditions` entry with `multiplier` at
## least this, so `clamp(0.001 × mult, 0, 1) >= 0.5` (the 50% break design target).
const BOSS_BREAK_MIN_MULTIPLIER := 500.0

## AC-12 multi-stat cap: no single positive `stat_bonuses` value may exceed this
## (the Formula 1 variable range); larger budgets must spread across ≥2 stats.
const MAX_SINGLE_STAT := 55

## AC-19 Prototype concentration threshold: `top_two_sum / positive_total >= 0.70`.
const CONCENTRATION_MIN := 0.70

## AC-DF (Damage-Formula Story 001): `BalanceConfig.damage_floor` must be `>= 0` —
## a negative floor would let `max(damage_floor, …)` return negative damage. The GDD
## safe range is 0–5; only the negative case is a hard error (a high floor is a
## tuning choice, not a schema violation).
const DAMAGE_FLOOR_MIN := 0

## AC-DF (Damage-Formula Story 002): the MVP `type_chart` grid is the 3×3 Cartesian
## product of these skill/Core elements — every one of the 9 cells must be present
## (a missing cell would silently degrade to ×1.0 at runtime, hiding an authoring
## gap). Reserved Full-Vision elements (CRYO/CORROSIVE/DATA) are intentionally NOT
## required — they legitimately fall through to the ×1.0 default.
const TYPE_CHART_MVP_ELEMENTS: Array[int] = [
	PartDef.Element.VOLT, PartDef.Element.THERMAL, PartDef.Element.KINETIC,
]

## AC-DF (Story 002): every authored `type_chart` cell must be one of the three
## locked Part DB Rule 6 ratios — ×0.75 resisted, ×1.0 neutral, ×1.5 super-effective.
## Any other value (a typo, a drifted retune) is a hard error: this validator is the
## BalanceConfig-vs-GDD drift guard the ADR mandates.
const TYPE_CHART_RATIOS: Array[float] = [0.75, 1.0, 1.5]

# --- Story 009: cross-DB referential integrity + level fields (run only when a
# Move/Passive resolution index is mounted via ContentCatalogs.references_mounted) ---

## TR-part-011 per-rarity `level_requirement` floors. A part's effective requirement
## (0 → treated as 1) must be `>=` its rarity floor; it may exceed it, never go below.
const RARITY_LEVEL_FLOORS: Dictionary = {
	PartDef.Rarity.COMMON: 1,
	PartDef.Rarity.RARE: 3,
	PartDef.Rarity.BOSS_GRADE: 6,
	PartDef.Rarity.PROTOTYPE: 8,
}

var _errors: Array[Dictionary] = []
var _warnings: Array[Dictionary] = []
var _log: LogSink

## The injected balance tables (ADR-0005). Null in a schema-only validation — the
## content-composition families skip when it is absent.
var _cfg: BalanceConfig

## The mounted Move/Passive resolution index (Story 009). `_refs_mounted` gates the
## referential + level-field family; the id sets answer the AC-13 `.has(id)` checks.
var _refs_mounted := false
var _move_ids: Dictionary = {}
var _passive_ids: Dictionary = {}


## Validate every catalog in [param catalogs], routing each fatal finding through
## [param log_sink]. Returns `{ok, errors, warnings}` where `ok` is
## `errors.is_empty()`. Safe to re-run on the same instance — state is reset each
## call. Story 007 validates the Part DB; later stories append more catalogs.
func validate(catalogs: ContentCatalogs, log_sink: LogSink) -> Dictionary:
	_errors = []
	_warnings = []
	_log = log_sink
	_cfg = catalogs.balance
	_refs_mounted = catalogs.references_mounted
	_move_ids = catalogs.move_ids
	_passive_ids = catalogs.passive_ids
	# Config-level balance checks (Damage-Formula Story 001) — run once when a
	# BalanceConfig is injected; validate the config itself before the catalogs.
	if _cfg != null:
		_check_balance_config()
	_validate_part_catalog(catalogs.parts)
	# Move DB family (Move-DB Stories 004/005) — only when a move catalog is mounted;
	# Part-only fixtures leave it null and skip it, staying green.
	if catalogs.moves != null:
		_validate_move_catalog(catalogs.moves)
	return {"ok": _errors.is_empty(), "errors": _errors, "warnings": _warnings}


## Record a fatal finding: append to the returned `errors` array AND surface it
## through the injected [LogSink]. The two stay in lock-step so a GUT spy can
## assert on either.
func _error(code: StringName, detail: Dictionary) -> void:
	_errors.append({"code": code, "detail": detail})
	_log.error(code, detail)


## Record a non-fatal authoring warning: append to `warnings` AND surface it
## through the [LogSink]. Warnings never affect `ok` (AC-23 empty-group coverage).
func _warn(code: StringName, detail: Dictionary) -> void:
	_warnings.append({"code": code, "detail": detail})
	_log.warn(code, detail)


# ---------------------------------------------------------------------------
# Catalog-level
# ---------------------------------------------------------------------------

func _validate_part_catalog(catalog: PartCatalog) -> void:
	if catalog == null:
		_error(&"content_missing_part_catalog", {})
		return
	_check_unique_ids(catalog)
	for part in catalog.entries:
		_validate_part(part)
	if _cfg != null:
		_check_primary_stat_group_coverage(catalog)


## AC-02: every `id` is globally unique within the catalog.
func _check_unique_ids(catalog: PartCatalog) -> void:
	var seen := {}
	for part in catalog.entries:
		if part == null:
			continue
		if seen.has(part.id):
			_error(&"content_duplicate_id", {"id": part.id})
		else:
			seen[part.id] = true


# ---------------------------------------------------------------------------
# Per-part dispatch
# ---------------------------------------------------------------------------

func _validate_part(part: PartDef) -> void:
	if part == null:
		_error(&"content_null_entry", {})
		return
	_check_required_identity(part)
	_check_nullability(part)
	_check_upgrade_effects(part)
	_check_slot_type(part)
	_check_enums(part)
	_check_recharge(part)
	_check_chassis_archetype(part)
	_check_heat(part)
	_check_sprite(part)
	# Content-composition families (Story 008) — only when a BalanceConfig is
	# injected; the schema families above run regardless.
	if _cfg != null:
		_check_synergy_tags(part)
		_check_prototype_balance(part)
		_check_boss_break_condition(part)
		_check_stat_budget(part)
		_check_prototype_concentration(part)
		_check_primary_stat_bounds(part)
	# Referential + level-field family (Story 009) — only when a Move/Passive
	# resolution index is mounted; prior-story fixtures mount none and skip it.
	if _refs_mounted:
		_check_referential_integrity(part)
		_check_level_requirement(part)
		_check_level_growth(part)


## AC-01 (required-field share): `id` and player-facing `display_name` present.
func _check_required_identity(part: PartDef) -> void:
	if part.id == &"":
		_error(&"content_missing_id", {"display_name": part.display_name})
	if part.display_name == "":
		_error(&"content_missing_display_name", {"id": part.id})


## AC-01 (Rule 8 — effect capacity & slot eligibility). Three data-driven rules
## replace the old per-slot skill/passive quotas: (1) an active skill is legal
## only on a skill-capable slot; (2) effect count must not exceed the rarity
## ceiling; (3) effect count must meet the rarity floor. Passives are legal on
## any slot within the band. The old CORE-passive special case is now emergent:
## Core can't hold a skill (rule 1) yet a Rare+ Core must bring one effect
## (rule 3), so its one effect can only be a passive — no inline `is_core` branch.
func _check_nullability(part: PartDef) -> void:
	var has_active := part.active_skill_id != &""
	var has_passive := part.passive_id != &""
	var effect_count := int(has_active) + int(has_passive)

	# (1) Active skill only on skill-capable slots (never CORE / ENERGY_CELL).
	if has_active and not SKILL_CAPABLE_SLOTS.has(part.slot_type):
		_error(&"content_active_skill_forbidden",
			{"id": part.id, "slot": part.slot_type, "rarity": part.rarity})

	# (2) Effect-capacity ceiling by rarity.
	if EFFECT_CEILING.has(part.rarity) and effect_count > EFFECT_CEILING[part.rarity]:
		_error(&"content_effect_capacity_exceeded",
			{"id": part.id, "rarity": part.rarity, "count": effect_count, "ceiling": EFFECT_CEILING[part.rarity]})

	# (3) Effect-capacity floor: Common carries 0, every Rare+ part carries ≥1.
	if EFFECT_FLOOR.has(part.rarity) and effect_count < EFFECT_FLOOR[part.rarity]:
		_error(&"content_effect_missing",
			{"id": part.id, "rarity": part.rarity, "count": effect_count, "floor": EFFECT_FLOOR[part.rarity]})


## AC-01 sub-check (d) (Rule 8) — a support slot (not skill-capable) must not gain
## an active skill through an upgrade. An `upgrade_effects` entry of type
## SKILL_UNLOCK on a CORE / ENERGY_CELL part would inject an active skill at that
## tier, bypassing the static `active_skill_id` gate in `_check_nullability`.
## SKILL_ENHANCE (which tunes an existing passive) stays legal on support slots.
func _check_upgrade_effects(part: PartDef) -> void:
	if SKILL_CAPABLE_SLOTS.has(part.slot_type):
		return
	for effect in part.upgrade_effects:
		if effect.get("effect_type", &"") == &"SKILL_UNLOCK":
			_error(&"content_upgrade_skill_unlock_forbidden",
				{"id": part.id, "slot": part.slot_type, "tier": effect.get("tier", 0)})


## AC-03: `slot_type` is one of the 8 MVP enum values (rejects the 0 sentinel).
func _check_slot_type(part: PartDef) -> void:
	if not PartDef.SlotType.values().has(part.slot_type):
		_error(&"content_invalid_slot_type", {"id": part.id, "value": part.slot_type})


## AC-21: manufacturer / element / rarity / damage_type within MVP enum sets;
## Full-Vision-reserved values rejected.
func _check_enums(part: PartDef) -> void:
	if not VALID_MANUFACTURERS.has(part.manufacturer):
		_error(&"content_invalid_manufacturer", {"id": part.id, "value": part.manufacturer})
	if not MVP_ELEMENTS.has(part.element):
		_error(&"content_invalid_element", {"id": part.id, "value": part.element})
	if not PartDef.Rarity.values().has(part.rarity):
		_error(&"content_invalid_rarity", {"id": part.id, "value": part.rarity})
	_check_damage_type(part)


## AC-21 (damage_type share): reserved types (DATA/TRUE) are rejected on ANY
## part; a valid MVP type is required only when the part actually delivers an
## active skill (damage_type is skill-delivered — a no-skill part legitimately
## has the unset 0 value).
func _check_damage_type(part: PartDef) -> void:
	if RESERVED_DAMAGE_TYPES.has(part.damage_type):
		_error(&"content_reserved_damage_type", {"id": part.id, "value": part.damage_type})
	elif part.active_skill_id != &"" and not MVP_DAMAGE_TYPES.has(part.damage_type):
		_error(&"content_invalid_damage_type", {"id": part.id, "value": part.damage_type})


## AC-17 + AC-18: recharge magnitude within [0, 15]; only ENERGY_CELL and CORE
## parts may carry a non-zero recharge. A missing `recharge` key reads as 0.
func _check_recharge(part: PartDef) -> void:
	var recharge: int = part.stat_bonuses.get(RECHARGE_KEY, 0)
	if recharge < 0 or recharge > RECHARGE_MAX:
		_error(&"content_recharge_out_of_range", {"id": part.id, "value": recharge})
	var slot_allows_recharge := (
		part.slot_type == PartDef.SlotType.ENERGY_CELL
		or part.slot_type == PartDef.SlotType.CORE
	)
	if recharge != 0 and not slot_allows_recharge:
		_error(&"content_recharge_slot_gating", {"id": part.id, "slot": part.slot_type, "value": recharge})


## AC-20: CHASSIS parts carry a valid non-null `chassis_archetype`; every other
## slot leaves it at 0 (the "no archetype" sentinel).
func _check_chassis_archetype(part: PartDef) -> void:
	var is_chassis := part.slot_type == PartDef.SlotType.CHASSIS
	var has_archetype := part.chassis_archetype != 0
	if is_chassis and not has_archetype:
		_error(&"content_chassis_missing_archetype", {"id": part.id})
	elif is_chassis and not PartDef.ChassisArchetype.values().has(part.chassis_archetype):
		_error(&"content_invalid_chassis_archetype", {"id": part.id, "value": part.chassis_archetype})
	elif not is_chassis and has_archetype:
		_error(&"content_nonchassis_has_archetype",
			{"id": part.id, "slot": part.slot_type, "value": part.chassis_archetype})


## AC-22 (Part-DB share): `heat_generation` within [0, 40]; a part with no active
## skill must generate no heat. (The THERMAL +5 runtime bonus is Combat/TBC.)
func _check_heat(part: PartDef) -> void:
	if part.heat_generation < 0 or part.heat_generation > HEAT_MAX:
		_error(&"content_heat_out_of_range", {"id": part.id, "value": part.heat_generation})
	if part.active_skill_id == &"" and part.heat_generation != 0:
		_error(&"content_heat_without_skill", {"id": part.id, "value": part.heat_generation})


## AC-24: every part carries a non-empty `sprite_id` (the renderer needs it).
func _check_sprite(part: PartDef) -> void:
	if part.sprite_id == &"":
		_error(&"content_missing_sprite_id", {"id": part.id})


# ---------------------------------------------------------------------------
# Story 008 — content-composition families (AC-04/10/11/12/19/23)
# ---------------------------------------------------------------------------

## AC-04: every part carries its element tag; a non-wild part carries its
## manufacturer tag; a wild part carries no manufacturer tag at all. An invalid
## element/manufacturer is left to AC-21 — this check stays silent on it (no
## double-flagging) by only acting on recognised values.
func _check_synergy_tags(part: PartDef) -> void:
	var element_tag: StringName = ELEMENT_TAGS.get(part.element, &"")
	if element_tag != &"" and not part.synergy_tags.has(element_tag):
		_error(&"content_synergy_missing_element_tag",
			{"id": part.id, "element": part.element, "expected": element_tag})
	if part.manufacturer == WILD_MANUFACTURER:
		for tag in MANUFACTURER_TAGS:
			if part.synergy_tags.has(tag):
				_error(&"content_synergy_wild_has_manufacturer_tag", {"id": part.id, "tag": tag})
	elif MANUFACTURER_TAGS.has(part.manufacturer) and not part.synergy_tags.has(part.manufacturer):
		_error(&"content_synergy_missing_manufacturer_tag",
			{"id": part.id, "manufacturer": part.manufacturer})


## AC-10: every Prototype has ≥1 positive AND ≥1 negative `stat_bonuses` value —
## the negative is its mandatory drawback and also the AC-19 divisor precondition.
func _check_prototype_balance(part: PartDef) -> void:
	if part.rarity != PartDef.Rarity.PROTOTYPE:
		return
	var has_positive := false
	var has_negative := false
	for v in part.stat_bonuses.values():
		if v > 0:
			has_positive = true
		elif v < 0:
			has_negative = true
	if not has_positive:
		_error(&"content_prototype_missing_positive", {"id": part.id})
	if not has_negative:
		_error(&"content_prototype_missing_negative", {"id": part.id})


## AC-11: every Boss-grade part carries a `drop_conditions` entry whose
## `multiplier >= 500` — otherwise it drops at the inert ~0.1% base and is
## effectively unobtainable. Empty conditions or all-below-500 → ERROR.
func _check_boss_break_condition(part: PartDef) -> void:
	if part.rarity != PartDef.Rarity.BOSS_GRADE:
		return
	for entry in part.drop_conditions:
		if float(entry.get("multiplier", 0.0)) >= BOSS_BREAK_MIN_MULTIPLIER:
			return
	_error(&"content_boss_break_condition_missing",
		{"id": part.id, "min_multiplier": BOSS_BREAK_MIN_MULTIPLIER})


## AC-12: positive stat spend within the slot/rarity budget, and no single stat
## above [constant MAX_SINGLE_STAT]. Negative drawback values are NOT counted in
## the positive budget. Bounds are read from the injected [BalanceConfig] — an
## unmapped slot/rarity (e.g. an enum sentinel) is left to the schema families.
func _check_stat_budget(part: PartDef) -> void:
	var positive_sum := 0
	for v in part.stat_bonuses.values():
		if v > 0:
			positive_sum += v
			if v > MAX_SINGLE_STAT:
				_error(&"content_stat_exceeds_single_cap",
					{"id": part.id, "value": v, "cap": MAX_SINGLE_STAT})
	var by_rarity: Dictionary = _cfg.stat_budgets.get(part.slot_type, {})
	var bounds: Array = by_rarity.get(part.rarity, [])
	# A well-formed budget is a [min, max] pair. An unmapped (empty) or malformed
	# (<2-element) entry is left to the schema families — never index [1] blind, or
	# a hand-authored 1-element array would abort the CI gate with an engine panic
	# instead of a clean content_* error (this validator must fail loud, gracefully).
	if bounds.size() < 2:
		return
	if positive_sum < int(bounds[0]) or positive_sum > int(bounds[1]):
		_error(&"content_stat_budget_out_of_range",
			{"id": part.id, "slot": part.slot_type, "rarity": part.rarity,
			"value": positive_sum, "min": bounds[0], "max": bounds[1]})


## AC-19: a Prototype concentrates ≥70% of its positive budget in its top 1–2
## stats. Guarded by AC-10 — a zero positive_total is an AC-10 failure and skips
## the division here, so this never divides by zero. A single positive stat gives
## ratio 1.0 (passes trivially).
func _check_prototype_concentration(part: PartDef) -> void:
	if part.rarity != PartDef.Rarity.PROTOTYPE:
		return
	var positives: Array[int] = []
	for v in part.stat_bonuses.values():
		if v > 0:
			positives.append(v)
	if positives.is_empty():
		return  # AC-10 already flagged content_prototype_missing_positive
	var positive_total := 0
	for v in positives:
		positive_total += v
	positives.sort()  # ascending — the last two entries are the largest
	var top_two := positives[-1]
	if positives.size() >= 2:
		top_two += positives[-2]
	if float(top_two) / float(positive_total) < CONCENTRATION_MIN:
		_error(&"content_prototype_concentration_low",
			{"id": part.id, "top_two": top_two, "positive_total": positive_total})


## AC-23 (per-part): a Common part's primary stat must not exceed its slot CAP; a
## Rare part's primary stat must meet its slot FLOOR. Arms/Weapon resolve the
## primary per-part by `damage_type`; an unresolved primary is skipped here (its
## empty-group coverage is reported at the catalog level).
func _check_primary_stat_bounds(part: PartDef) -> void:
	var primary: StringName = _primary_stat_for(part)
	if primary == &"":
		return
	var value: int = part.stat_bonuses.get(primary, 0)
	if part.rarity == PartDef.Rarity.COMMON:
		var cap: int = _cfg.primary_stat_common_caps.get(part.slot_type, -1)
		if cap >= 0 and value > cap:
			_error(&"content_common_primary_over_cap",
				{"id": part.id, "slot": part.slot_type, "stat": primary, "value": value, "cap": cap})
	elif part.rarity == PartDef.Rarity.RARE:
		var floor_value: int = _cfg.primary_stat_rare_floors.get(part.slot_type, -1)
		if floor_value >= 0 and value < floor_value:
			_error(&"content_rare_primary_under_floor",
				{"id": part.id, "slot": part.slot_type, "stat": primary, "value": value, "floor": floor_value})


## Resolve a part's AC-23 primary stat: the slot mapping, or — for the
## damage_type-split ARMS / WEAPON slots — the physical/energy primary chosen by
## `damage_type`. Returns `&""` when unresolvable (an ARMS/WEAPON whose damage_type
## is unset or reserved).
func _primary_stat_for(part: PartDef) -> StringName:
	if part.slot_type == PartDef.SlotType.ARMS or part.slot_type == PartDef.SlotType.WEAPON:
		match part.damage_type:
			PartDef.DamageType.PHYSICAL:
				return PHYSICAL_PRIMARY
			PartDef.DamageType.ENERGY:
				return ENERGY_PRIMARY
			_:
				return &""
	return PRIMARY_STAT.get(part.slot_type, &"")


## AC-23 (catalog-level): every present slot / damage_type subgroup that has no
## Common part (its CAP is uncheckable) or no Rare part (its FLOOR is uncheckable)
## is a vacuous pass that still earns an authoring WARNING. Groups are keyed by
## slot + resolved primary stat so ARMS/WEAPON PHYSICAL and ENERGY stay distinct.
func _check_primary_stat_group_coverage(catalog: PartCatalog) -> void:
	var groups := {}
	for part in catalog.entries:
		if part == null:
			continue
		var primary: StringName = _primary_stat_for(part)
		if primary == &"":
			continue
		var key := "%d|%s" % [part.slot_type, primary]
		if not groups.has(key):
			groups[key] = {"has_common": false, "has_rare": false, "slot": part.slot_type, "stat": primary}
		if part.rarity == PartDef.Rarity.COMMON:
			groups[key]["has_common"] = true
		elif part.rarity == PartDef.Rarity.RARE:
			groups[key]["has_rare"] = true
	for key in groups:
		var g: Dictionary = groups[key]
		if not g["has_common"]:
			_warn(&"content_primary_group_no_common", {"slot": g["slot"], "stat": g["stat"]})
		if not g["has_rare"]:
			_warn(&"content_primary_group_no_rare", {"slot": g["slot"], "stat": g["stat"]})


# ---------------------------------------------------------------------------
# Damage-Formula Story 001 — config-level balance check (DF-1 damage_floor)
# ---------------------------------------------------------------------------

## The injected [BalanceConfig] must carry a non-negative [member
## BalanceConfig.damage_floor] — the DF-1 `max(damage_floor, floor(...))` clamp
## would otherwise permit negative damage. Runs once per validation (config-level,
## not per-part), only when a config is mounted.
func _check_balance_config() -> void:
	if _cfg.damage_floor < DAMAGE_FLOOR_MIN:
		_error(&"content_balance_damage_floor_negative",
			{"value": _cfg.damage_floor, "min": DAMAGE_FLOOR_MIN})
	_check_type_chart()


## Damage-Formula Story 002: the injected [BalanceConfig]'s [member
## BalanceConfig.type_chart] must be a complete, well-formed 3×3 grid — every
## (skill, Core) pair over VOLT/THERMAL/KINETIC present and each value ∈ the locked
## Part DB Rule 6 ratio set {0.75, 1.0, 1.5}. A missing cell would silently read as a
## neutral ×1.0 at runtime (hiding an authoring gap); an off-set value would drift
## the type triangle away from the GDD. Both emit the single
## `content_balance_type_chart_malformed` code with a `reason` discriminator. Absent
## reserved elements (CRYO/CORROSIVE/DATA) are NOT flagged — the ×1.0 default is
## correct for them (GDD EC-04/EC-05).
func _check_type_chart() -> void:
	for skill in TYPE_CHART_MVP_ELEMENTS:
		var row: Variant = _cfg.type_chart.get(skill, null)
		if not (row is Dictionary):
			_error(&"content_balance_type_chart_malformed",
				{"reason": "missing_row", "skill": skill})
			continue
		for core in TYPE_CHART_MVP_ELEMENTS:
			if not row.has(core):
				_error(&"content_balance_type_chart_malformed",
					{"reason": "missing_cell", "skill": skill, "core": core})
				continue
			var cell: float = float(row[core])
			if not _is_locked_ratio(cell):
				_error(&"content_balance_type_chart_malformed",
					{"reason": "out_of_set", "skill": skill, "core": core, "value": cell})


## True when [param value] equals one of the three locked Rule 6 ratios (float-safe
## compare — the authored `.tres` stores IEEE-754 doubles).
func _is_locked_ratio(value: float) -> bool:
	for ratio in TYPE_CHART_RATIOS:
		if is_equal_approx(value, ratio):
			return true
	return false


# ---------------------------------------------------------------------------
# Story 009 — cross-DB referential integrity + level fields (AC-13, TR-011/012)
# ---------------------------------------------------------------------------

## AC-13 (TR-part-013) / Move-DB Story 006 (EC-MDB-01): every non-`&""`
## `active_skill_id` resolves to a mounted Move DB entry, and every non-`&""`
## `passive_id` to a mounted Passive DB entry. `&""` (no reference) is skipped,
## never flagged. Resolves against the injected id sets (ADR-0003 — StringName IDs,
## DI), never a live autoload. The skill-ref code is `content_active_skill_unresolved`
## — the single canonical code for the Part↔Move linkage, owned by Move-DB Story 006
## (it superseded the Story-009 placeholder `content_dangling_skill_ref` once the
## real Move DB landed; the `move_ids` set is now populated from a live MoveCatalog
## via [method ContentCatalogs.move_ids_from]).
func _check_referential_integrity(part: PartDef) -> void:
	if part.active_skill_id != &"" and not _move_ids.has(part.active_skill_id):
		_error(&"content_active_skill_unresolved", {"id": part.id, "active_skill_id": part.active_skill_id})
	if part.passive_id != &"" and not _passive_ids.has(part.passive_id):
		_error(&"content_dangling_passive_ref", {"id": part.id, "passive_id": part.passive_id})


## TR-part-011: a part's `level_requirement` meets its rarity floor (COMMON 1 /
## RARE 3 / BOSS_GRADE 6 / PROTOTYPE 8). 0 is the "unset" sentinel and defaults to
## 1, so a non-Common part left at 0 fails its higher floor (authoring must set it
## explicitly). A part may exceed its floor, never go below. An unmapped rarity
## (enum sentinel) is left to the schema families.
func _check_level_requirement(part: PartDef) -> void:
	if not RARITY_LEVEL_FLOORS.has(part.rarity):
		return
	var floor_value: int = RARITY_LEVEL_FLOORS[part.rarity]
	var effective: int = part.level_requirement if part.level_requirement > 0 else 1
	if effective < floor_value:
		_error(&"content_level_requirement_below_floor",
			{"id": part.id, "rarity": part.rarity, "value": part.level_requirement, "floor": floor_value})


## TR-part-012: `level_growth` is non-empty ONLY on CORE-slot parts. A non-CORE part
## with a non-empty `level_growth` is an ERROR; a CORE part with any (incl. empty)
## `level_growth` is valid (Assembly ignores growth on non-Core slots at runtime).
func _check_level_growth(part: PartDef) -> void:
	if part.slot_type != PartDef.SlotType.CORE and not part.level_growth.is_empty():
		_error(&"content_level_growth_non_core", {"id": part.id, "slot": part.slot_type})


# ---------------------------------------------------------------------------
# Move-DB Story 004 — Move schema family (AC-MDB-18/21, EC-MDB-04 authoring side)
# ---------------------------------------------------------------------------
# Runs only when a MoveCatalog is mounted (see validate() gate). Behaviours that
# demand SELF targeting; behaviours that require a power tier.

## Behaviours whose effect always applies to the caster, so their `targeting`
## must be SELF (AC-MDB-21): REPAIR heals the user, UTILITY (Vent) cools the user.
## DAMAGE / STATUS / SCAN act on an ENEMY and are unconstrained here.
const SELF_TARGET_BEHAVIORS: Array[int] = [
	MoveDef.Behavior.REPAIR, MoveDef.Behavior.UTILITY,
]

# --- Story 005: cross-field authoring rules (GDD Rule 3/5/7) ---

## AC-MDB-14: the `energy_cost` band a DAMAGE move must fall in, keyed by its
## PowerTier → `[min, max]` inclusive (GDD Rule 3). BASIC is the free Basic Attack
## (cost 0) and is intentionally absent — it is exempt from the band. Non-DAMAGE
## behaviours and an unset (0) tier are not keyed here and skip the check.
const ENERGY_BANDS: Dictionary = {
	MoveDef.PowerTier.LIGHT: [5, 8],
	MoveDef.PowerTier.STANDARD: [12, 18],
	MoveDef.PowerTier.HEAVY: [22, 30],
	MoveDef.PowerTier.SIGNATURE: [32, 40],
}

## AC-MDB-15: a REPAIR move must cost STRICTLY MORE than one turn's passive energy
## regen, or healing is free and stalls the match (the anti-stall brake, Rule 7 /
## TBC AC-TBC-38). `energy_cost <= BASE_ENERGY_REGEN` is illegal.
##
## FORWARD WORK: `BASE_ENERGY_REGEN` is a TBC balance constant not yet in code.
## Pinned here to the GDD value; source it from the TBC `BalanceConfig` field once
## the TBC epic ships (single source of truth), then delete this local const.
const BASE_ENERGY_REGEN := 10

## AC-MDB-16: the status a STATUS move applies is fixed by its element (Rule 5 /
## TBC Rule 11) — `status_proc.status_id` must equal this element's entry. A STATUS
## move with an unset/reserved element (not keyed here) skips the match; its
## element is the enum family's concern, not this cross-field rule's.
const STATUS_BY_ELEMENT: Dictionary = {
	PartDef.Element.VOLT: &"shock",
	PartDef.Element.THERMAL: &"burn",
	PartDef.Element.KINETIC: &"stagger",
}

## The `status_proc` sub-key carrying the applied status identity (Rule 5).
const STATUS_ID_KEY := &"status_id"


## Validate every entry in the mounted Move catalog. Mirrors
## [method _validate_part_catalog] — a null entry is fatal, each real entry is
## dispatched through [method _validate_move].
func _validate_move_catalog(catalog: MoveCatalog) -> void:
	for move in catalog.entries:
		_validate_move(move)


## Per-move dispatch (Story 004 schema family + Story 005 authoring rules). A null
## entry is fatal and short-circuits — a null can't be field-checked.
func _validate_move(move: MoveDef) -> void:
	if move == null:
		_error(&"content_null_entry", {"db": &"move"})
		return
	# Story 004 — schema shape.
	_check_move_required_fields(move)
	_check_damage_power_tier(move)
	_check_move_targeting(move)
	# Story 005 — cross-field authoring rules.
	_check_move_energy_band(move)
	_check_move_repair_brake(move)
	_check_move_status_element(move)
	_check_move_innate_rider(move)


## AC-MDB-18: the always-required identity/schema fields, plus the DAMAGE-only
## `damage_type` + `element`. `power_tier` is DAMAGE-required too but has its own
## dedicated code (see [method _check_damage_power_tier]). `energy_cost` is NOT
## checked here — 0 is a legitimate cost (a Basic Attack is free), so it has no
## "missing" sentinel. Every finding names the move `id` (AC requirement).
func _check_move_required_fields(move: MoveDef) -> void:
	if move.id == &"":
		_error(&"content_move_missing_field", {"id": move.id, "field": &"id", "display_name": move.display_name})
	if move.display_name == "":
		_error(&"content_move_missing_field", {"id": move.id, "field": &"display_name"})
	if int(move.behavior) == 0:
		_error(&"content_move_missing_field", {"id": move.id, "field": &"behavior"})
	if int(move.targeting) == 0:
		_error(&"content_move_missing_field", {"id": move.id, "field": &"targeting"})
	if move.behavior == MoveDef.Behavior.DAMAGE:
		if int(move.damage_type) == 0:
			_error(&"content_move_missing_field", {"id": move.id, "field": &"damage_type"})
		if int(move.element) == 0:
			_error(&"content_move_missing_field", {"id": move.id, "field": &"element"})


## EC-MDB-04 (authoring side): a DAMAGE move must declare a real `power_tier` —
## the 0 sentinel is a missing tier. (TBC's runtime STANDARD fallback is a
## separate, resolution-time concern; content authoring must be explicit.)
func _check_damage_power_tier(move: MoveDef) -> void:
	if move.behavior == MoveDef.Behavior.DAMAGE and int(move.power_tier) == 0:
		_error(&"content_damage_move_missing_power_tier", {"id": move.id})


## AC-MDB-21: a REPAIR or UTILITY(Vent) move must target SELF. The `targeting != 0`
## guard skips the unset sentinel — that is already the required-field check's
## job (no double-flagging). A REPAIR/UTILITY that explicitly targets ENEMY errors.
func _check_move_targeting(move: MoveDef) -> void:
	if not SELF_TARGET_BEHAVIORS.has(int(move.behavior)):
		return
	if int(move.targeting) != 0 and move.targeting != MoveDef.Targeting.SELF:
		_error(&"content_move_bad_targeting",
			{"id": move.id, "behavior": move.behavior, "targeting": move.targeting})


## AC-MDB-14 (Story 005): a DAMAGE move's `energy_cost` must fall in its PowerTier
## band (Rule 3). BASIC (the free Basic Attack) and an unset tier are not keyed in
## [constant ENERGY_BANDS] and are exempt — a missing tier is Story 004's error.
func _check_move_energy_band(move: MoveDef) -> void:
	if move.behavior != MoveDef.Behavior.DAMAGE:
		return
	if not ENERGY_BANDS.has(move.power_tier):
		return
	var band: Array = ENERGY_BANDS[move.power_tier]
	if move.energy_cost < int(band[0]) or move.energy_cost > int(band[1]):
		_error(&"content_move_energy_band",
			{"id": move.id, "power_tier": move.power_tier, "energy_cost": move.energy_cost,
			"min": band[0], "max": band[1]})


## AC-MDB-15 (Story 005): a REPAIR move must cost more than [constant
## BASE_ENERGY_REGEN] — the anti-stall brake (Rule 7). `<=` regen is free healing.
func _check_move_repair_brake(move: MoveDef) -> void:
	if move.behavior != MoveDef.Behavior.REPAIR:
		return
	if move.energy_cost <= BASE_ENERGY_REGEN:
		_error(&"content_move_repair_brake",
			{"id": move.id, "energy_cost": move.energy_cost, "base_regen": BASE_ENERGY_REGEN})


## AC-MDB-16 (Story 005): a STATUS move's `status_proc.status_id` must be the
## status fixed by its `element` (Rule 5). An empty `status_proc` reads status_id
## as `&""`, which never matches — so this same check also enforces AC-4's "a
## STATUS move REQUIRES a status_proc" (a missing rider IS a mismatch: it can't
## carry the element's status). An unset/reserved element is not keyed in
## [constant STATUS_BY_ELEMENT] and is skipped (an enum-family concern).
func _check_move_status_element(move: MoveDef) -> void:
	if move.behavior != MoveDef.Behavior.STATUS:
		return
	var expected: StringName = STATUS_BY_ELEMENT.get(move.element, &"")
	if expected == &"":
		return
	var status_id: StringName = move.status_proc.get(STATUS_ID_KEY, &"")
	if status_id != expected:
		_error(&"content_move_status_element_mismatch",
			{"id": move.id, "element": move.element, "status_id": status_id, "expected": expected})


## TR-mdb-009 (Story 005): a DAMAGE move must NOT carry an innate `status_proc` —
## damage riders come only via passives (TBC Rule 13), never baked into the move.
## STATUS is the one behaviour that owns a `status_proc`; every other behaviour
## leaves it empty (a stray proc on non-DAMAGE is silently harmless, but the
## DAMAGE case is the authored-content trap this guards).
func _check_move_innate_rider(move: MoveDef) -> void:
	if move.behavior == MoveDef.Behavior.DAMAGE and not move.status_proc.is_empty():
		_error(&"content_move_innate_rider", {"id": move.id})
