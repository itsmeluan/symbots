## PartValidator — Part-DB validation family for [ContentValidator] (ADR-0003 §5).
##
## Contains the full Part-DB check families extracted verbatim from
## [ContentValidator]: schema/enum/nullability/range (Stories 007/008/009/011)
## and the Damage-Formula balance-config checks (DF Stories 001/002).
## Composed by [ContentValidator]; never instantiated directly by game code.
##
## Call sequence (per validation run):
##   1. Set [member _errors], [member _warnings], [member _log], [member _cfg],
##      [member _refs_mounted], [member _move_ids], [member _passive_ids] from
##      [ContentValidator] before calling [method validate_catalog].
##   2. [method validate_catalog] populates [member _errors] / [member _warnings]
##      in-place; [ContentValidator] merges them into its own accumulators.
extends "content_validator_base.gd"

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

## TR-part-011 per-rarity `level_requirement` floors. A part's effective requirement
## (0 → treated as 1) must be `>=` its rarity floor; it may exceed it, never go below.
const RARITY_LEVEL_FLOORS: Dictionary = {
	PartDef.Rarity.COMMON: 1,
	PartDef.Rarity.RARE: 3,
	PartDef.Rarity.BOSS_GRADE: 6,
	PartDef.Rarity.PROTOTYPE: 8,
}

## The injected balance tables (ADR-0005). Null in a schema-only validation — the
## content-composition families skip when it is absent.
var _cfg: BalanceConfig

## The mounted Move/Passive resolution index (Story 009). `_refs_mounted` gates the
## referential + level-field family; the id sets answer the AC-13 `.has(id)` checks.
var _refs_mounted := false
var _move_ids: Dictionary = {}
var _passive_ids: Dictionary = {}


## Validate every part entry in [param catalog], routing each finding through
## [member _log].  Called by [ContentValidator] when `catalogs.parts` is mounted.
## State ([member _cfg], [member _refs_mounted], etc.) must be set before calling.
func validate_catalog(catalog: PartCatalog) -> void:
	if catalog == null:
		_error(&"content_missing_part_catalog", {})
		return
	_check_unique_ids(catalog)
	for part in catalog.entries:
		_validate_part(part)
	if _cfg != null:
		_check_primary_stat_group_coverage(catalog)


# ---------------------------------------------------------------------------
# Catalog-level
# ---------------------------------------------------------------------------

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
	_check_drop_condition_entries(part)
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
		_check_prototype_focus_floor(part)
		_check_prototype_drop_conditions(part)
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
## Entry-shape validation (Story 011 — Story 009 promised): each entry must carry
## `tier` (int in [1,5]), `effect_type` (StringName, non-empty), and — when
## SKILL_UNLOCK — a non-empty `skill_id` (StringName). A malformed entry emits
## a clean `content_*` error and never panics.
func _check_upgrade_effects(part: PartDef) -> void:
	var index := 0
	for entry in part.upgrade_effects:
		# --- Entry shape ---
		if not (entry is Dictionary):
			_error(&"content_upgrade_entry_malformed",
				{"id": part.id, "index": index, "reason": &"not_a_dictionary"})
			index += 1
			continue
		# String key "tier" — matches the existing SKILL_UNLOCK check and authored .tres convention.
		var tier_val: Variant = entry.get("tier", null)
		if not (tier_val is int) or int(tier_val) < 1 or int(tier_val) > 5:
			_error(&"content_upgrade_entry_malformed",
				{"id": part.id, "index": index, "reason": &"tier_invalid",
				"value": tier_val})
		# String key "effect_type"; value is a StringName per authored content convention.
		var effect_type_raw: Variant = entry.get("effect_type", null)
		var effect_type: StringName = effect_type_raw if (effect_type_raw is StringName) else &""
		if effect_type == &"":
			_error(&"content_upgrade_entry_malformed",
				{"id": part.id, "index": index, "reason": &"effect_type_missing_or_empty"})
		# --- SKILL_UNLOCK gate (support-slot rule) ---
		if effect_type == &"SKILL_UNLOCK":
			if not SKILL_CAPABLE_SLOTS.has(part.slot_type):
				_error(&"content_upgrade_skill_unlock_forbidden",
					{"id": part.id, "slot": part.slot_type, "tier": entry.get("tier", 0)})
		index += 1


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


## AC-12 + AC-27: positive stat spend within the slot/rarity budget; no single stat
## above [constant MAX_SINGLE_STAT] (positive cap); and symmetrically, no single
## stat below [constant -MAX_SINGLE_STAT] (negative floor — guards Formula 2b's
## −55 input floor). Negative drawback values are NOT counted in the positive
## budget. Bounds are read from the injected [BalanceConfig] — an unmapped
## slot/rarity (e.g. an enum sentinel) is left to the schema families.
func _check_stat_budget(part: PartDef) -> void:
	var positive_sum := 0
	for v in part.stat_bonuses.values():
		if v > 0:
			positive_sum += v
			if v > MAX_SINGLE_STAT:
				_error(&"content_stat_exceeds_single_cap",
					{"id": part.id, "value": v, "cap": MAX_SINGLE_STAT})
		elif v < -MAX_SINGLE_STAT:
			# AC-27 symmetric negative floor — same error code, cap field is negative
			# sentinel to distinguish positive-cap vs negative-floor violations if needed.
			_error(&"content_stat_exceeds_single_cap",
				{"id": part.id, "value": v, "cap": -MAX_SINGLE_STAT})
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
# Story 011 — Prototype focus-floor (AC-25) and drop conditions (AC-26)
# ---------------------------------------------------------------------------

## AC-25 (Round 11): every Prototype's focus stat IS its slot's primary stat. Two
## sub-checks: (a) `stat_bonuses[primary]` is the highest positive bonus — no other
## stat strictly exceeds it (ties are legal); (b) `stat_bonuses[primary]` strictly
## exceeds the slot's Rare primary FLOOR. Reuses [method _primary_stat_for] from
## AC-23 — an unresolved primary (ARMS/WEAPON with bad damage_type) is skipped here;
## the enum family already flags it. Runs only on PROTOTYPE parts. Known co-fire: a
## primary value ≤ 0 (missing key or all-negative bonuses) makes any positive stat a
## strict exceeder, so (a) fires alongside AC-10's missing-positive error — noisy but
## never wrong (such a part is invalid either way).
func _check_prototype_focus_floor(part: PartDef) -> void:
	if part.rarity != PartDef.Rarity.PROTOTYPE:
		return
	var primary: StringName = _primary_stat_for(part)
	if primary == &"":
		return  # unresolvable — already flagged by enum family
	var primary_value: int = part.stat_bonuses.get(primary, 0)

	# (a) primary must be the highest positive stat; no other stat may strictly exceed it.
	for v: int in part.stat_bonuses.values():
		if v > primary_value:
			_error(&"content_prototype_focus_not_primary",
				{"id": part.id, "primary": primary, "value": primary_value,
				"exceeding_value": v})
			return  # one error per part — the first offender is sufficient

	# (b) primary must STRICTLY exceed the Rare primary floor for its slot.
	var rare_floor: int = _cfg.primary_stat_rare_floors.get(part.slot_type, -1)
	if rare_floor >= 0 and primary_value <= rare_floor:
		_error(&"content_prototype_focus_below_rare_floor",
			{"id": part.id, "primary": primary, "value": primary_value,
			"slot": part.slot_type, "floor": rare_floor})


## AC-26: every Prototype carries ≥3 `drop_conditions` entries and the product of
## ALL their `multiplier` values is ≥ 3.0. Both sub-checks are independent — a
## two-entry product ≥ 3.0 still fails (a). Product uses float accumulation;
## compared with `>= 3.0 − 1e-9` tolerance per the GDD float-equality warning.
## This check trusts each entry's `multiplier > 1.0` invariant (Rule 9 / Drop System
## Rule 5a, enforced per-entry by [method _check_drop_condition_entries]); it does NOT
## re-validate entry shape — that is [method _check_drop_condition_entries]'s concern.
## Runs only on PROTOTYPE parts.
func _check_prototype_drop_conditions(part: PartDef) -> void:
	if part.rarity != PartDef.Rarity.PROTOTYPE:
		return
	# Sub-check (a) — size.
	if part.drop_conditions.size() < 3:
		_error(&"content_prototype_too_few_drop_conditions",
			{"id": part.id, "size": part.drop_conditions.size(), "min": 3})
		# Do NOT return — sub-check (b) is independent and must run even when size fails.

	# Sub-check (b) — product of all multipliers >= 3.0. String key matches authored
	# .tres convention (same as _check_boss_break_condition uses "multiplier").
	var product := 1.0
	for entry: Dictionary in part.drop_conditions:
		var m: float = float(entry.get("multiplier", 1.0))
		product *= m
	if product < 3.0 - 1e-9:
		_error(&"content_prototype_drop_product_low",
			{"id": part.id, "product": product, "min": 3.0})


## Entry-shape validator for `drop_conditions` arrays (Story 011 — Story 009 debt).
## Each entry requires: `condition` (StringName, non-empty), `multiplier` (float > 1.0).
## A malformed entry emits a clean `content_*` error and never panics with an engine
## exception on malformed authored content. Runs on ALL rarities (Boss-grade needs
## `multiplier >= 500`; this check guards the structural invariant that the entry is
## even readable). Called from [method _validate_part] before rarity-specific checks.
## Keys use the String convention matching `_check_boss_break_condition` and authored
## `.tres` content; `condition` VALUE is a StringName.
func _check_drop_condition_entries(part: PartDef) -> void:
	var index := 0
	for entry: Dictionary in part.drop_conditions:
		# `condition` key — String key, StringName value (per authored .tres convention).
		var cond_raw: Variant = entry.get("condition", null)
		var cond_sn: StringName = cond_raw if (cond_raw is StringName) else &""
		if cond_sn == &"":
			_error(&"content_drop_condition_entry_malformed",
				{"id": part.id, "index": index, "reason": &"condition_missing_or_empty"})
		# `multiplier` key — String key, float value > 1.0 (Rule 9 / Drop Rule 5a).
		var mult_raw: Variant = entry.get("multiplier", null)
		if mult_raw == null:
			_error(&"content_drop_condition_entry_malformed",
				{"id": part.id, "index": index, "reason": &"multiplier_missing"})
		elif not (mult_raw is float or mult_raw is int):
			_error(&"content_drop_condition_entry_malformed",
				{"id": part.id, "index": index, "reason": &"multiplier_wrong_type"})
		elif float(mult_raw) <= 1.0:
			_error(&"content_drop_condition_entry_malformed",
				{"id": part.id, "index": index, "reason": &"multiplier_not_above_one",
				"value": float(mult_raw)})
		index += 1


# ---------------------------------------------------------------------------
# Damage-Formula Story 001 — config-level balance check (DF-1 damage_floor)
# ---------------------------------------------------------------------------

## The injected [BalanceConfig] must carry a non-negative [member
## BalanceConfig.damage_floor] — the DF-1 `max(damage_floor, floor(...))` clamp
## would otherwise permit negative damage. Runs once per validation (config-level,
## not per-part), only when a config is mounted.
func check_balance_config() -> void:
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
