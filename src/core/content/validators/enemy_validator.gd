## EnemyValidator — Enemy-DB validation family for [ContentValidator]
## (ADR-0003 §5).
##
## Contains the full Enemy-DB schema-presence family extracted verbatim from
## [ContentValidator]: schema presence/type, id uniqueness, skills count,
## ai_profile non-empty + referential seam, tier advisory, and flavor_text length
## (Enemy-DB Story 004).
##
## The `ai_profile` referential seam is forwarded from [ContentValidator] via
## [member _ai_profile_checker] — call [method set_ai_profile_checker] before
## [method validate_catalog] to inject a non-default checker.
##
## Story 006 appended the break-region validation family:
## [method _check_enemy_break_regions] dispatches per-region checks:
##   - ≥1 region (TR-edb-022 / EC-ED-01)
##   - stored == derived via [BreakHpFormula.derive_break_hp] (TR-edb-002)
##   - break_hp < structure (TR-edb-004 / EDB-3)
##   - region_fraction ∈ [REGION_FRACTION_MIN, REGION_FRACTION_MAX] ± 1e-9 (TR-edb-014)
##   - region_id uniqueness within enemy (TR-edb-004 / EC-ED-08)
##   - loot connectivity: break_event matches ≥1 loot_pool entry's drop_condition
##     (TR-edb-004 / EDB-3)
## NOTE: break_event uniqueness is NOT checked — same break_event on multiple
## regions is legal set semantics (TR-edb-021 / EC-ED-07 / AC-ED-20).
##
## Story 007 appended the loot/rarity/boss-grade gating family
## ([method _check_enemy_loot]), resolving each `loot_pool` id through an injected
## Part-DB seam ([member _part_lookup] / [method set_part_lookup]): referential
## integrity, class rarity (Rule 8 Boss-grade exclusivity), the AC-ED-09 boss-grade
## product invariant (`base × multiplier ≥ 0.5`), floor-loot rarity + min-break-gated
## advisories, dedup, and all/some-disabled. INERT until the seam is injected.
##
## Composed by [ContentValidator]; never instantiated directly by game code.
##
## Call sequence (per validation run):
##   1. Set [member _errors], [member _warnings], [member _log] from
##      [ContentValidator] before calling [method validate_catalog].
##   2. Optionally call [method set_ai_profile_checker] to inject a non-default seam.
##   3. [method validate_catalog] populates [member _errors] / [member _warnings]
##      in-place; [ContentValidator] merges them into its own accumulators.
extends "content_validator_base.gd"

# ---------------------------------------------------------------------------
# Enemy-DB Story 004 — Enemy schema-presence family
# ---------------------------------------------------------------------------

## The accepted MVP `enemy_class` values. ELITE (3) and RIVAL (4) are reserved
## for Full Vision — they are declared in the GDD but NOT in EnemyDef.EnemyClass,
## so any .tres that somehow stores 3/4 reads back as INVALID. This check
## enforces {WILD, BOSS} exactly; INVALID (0) is the "missing" sentinel.
const VALID_ENEMY_CLASSES: Array[int] = [EnemyDef.EnemyClass.WILD, EnemyDef.EnemyClass.BOSS]

## MVP-only enemy tier value. `tier != 1` → advisory warning (AC-ED-13a).
const ENEMY_MVP_TIER := 1

## Maximum `skills` array size before an advisory warning (TR-edb-019). Size > 4
## is legal content (not a hard error) — it merely exceeds the MVP design intent
## of 2–4 skills per enemy.
const ENEMY_SKILLS_MAX := 4

## `flavor_text` length cap (AC-ED-13b). 100 characters inclusive — a 100-char
## string PASSES; 101 FAILS. Named constant so a Part DB ratification of a
## different value is a one-line change. GDD source: AC-ED-13b (FLAVOR_TEXT_MAX).
const FLAVOR_TEXT_MAX := 100

## ai_profile referential seam (injected Callable). Signature: `(profile: StringName) -> bool`.
## Default is accept-all — valid until the EnemyAI autoload is implemented.
## Inject via [method set_ai_profile_checker] before calling [method validate_catalog].
## Do NOT call EnemyAI directly here — that would create a hard compile-time
## dependency on a not-yet-existing class.
var _ai_profile_checker: Callable = func(_p: StringName) -> bool: return true

## Part-DB referential seam (injected Callable). Signature: `(id: StringName) -> PartDef`
## (returns the resolved [PartDef], or `null` when the id is absent from the Part DB).
## Default is an INVALID Callable — the entire Story-007 loot/rarity/boss-grade family
## is INERT until a real lookup is injected (mirrors the accept-all `ai_profile` default:
## no Part DB wired ⇒ no referential verdict). This keeps every prior-story fixture
## (which mounts no Part DB) green: unresolved loot ids cannot error until the seam is
## live. Inject via [method set_part_lookup] before [method validate_catalog].
## Do NOT reference PartDatabase directly here — keep the DI seam (Control Manifest:
## Forbidden — hard PartDatabase singleton in the unit path).
var _part_lookup: Callable = Callable()


## Wire the `ai_profile` referential seam so tests (and eventually the real boot)
## can inject a non-default checker. Call before [method validate_catalog].
## [param checker] must have signature `(StringName) -> bool`.
func set_ai_profile_checker(checker: Callable) -> void:
	_ai_profile_checker = checker


## Wire the Part-DB referential seam (Story 007). Call before [method validate_catalog].
## [param lookup] must have signature `(StringName) -> PartDef` returning `null` for an
## unresolved id. When left un-injected the loot family stays inert (see [member _part_lookup]).
func set_part_lookup(lookup: Callable) -> void:
	_part_lookup = lookup


## Catalog-level dispatch: per-entry schema validation, plus catalog-wide id
## uniqueness. Mirrors [method _validate_consumable_catalog].
func validate_catalog(catalog: EnemyCatalog) -> void:
	_check_enemy_id_uniqueness(catalog)
	for enemy in catalog.entries:
		_validate_enemy(enemy)
	# Story 008 — catalog-scoped (zone-scoped in MVP: one zone) null-element density.
	_check_enemy_null_element_density(catalog)


## Per-enemy dispatch. A null entry is fatal and short-circuits.
func _validate_enemy(enemy: EnemyDef) -> void:
	if enemy == null:
		_error(&"content_null_entry", {"db": &"enemy"})
		return
	_check_enemy_schema_presence(enemy)
	_check_enemy_skills_count(enemy)
	_check_enemy_ai_profile(enemy)
	_check_enemy_tier(enemy)
	_check_enemy_flavor_length(enemy)
	# Story 005 — stat-block value checks
	_check_enemy_stat_structure(enemy)
	_check_enemy_stat_ranges(enemy)
	_check_enemy_wild_power_cap(enemy)
	_check_enemy_stat_unknown_keys(enemy)
	_check_enemy_stat_dead_data(enemy)
	# Story 006 — break-region family
	_check_enemy_break_regions(enemy)
	# Story 007 — loot/rarity/boss-grade family. INERT until the Part-DB seam is
	# injected: without a live lookup we cannot resolve part ids, so all referential
	# and rarity verdicts are skipped (prior-story fixtures mount no Part DB).
	if _part_lookup.is_valid():
		_check_enemy_loot(enemy)
	# Story 008 — harvest-decision (BLOCKING) + TTK / density / boss-spawn advisories.
	_check_enemy_harvest_decision(enemy)
	_check_enemy_ttk_band(enemy)
	_check_enemy_content_density(enemy)
	_check_enemy_boss_spawn(enemy)
	# Story 009 — ELZS progression fields (level range / xp stored-equals-derived /
	# completion-bonus sign + BOSS-only). All BLOCKING (authored-value invariants).
	_check_enemy_level_range(enemy)
	_check_enemy_xp_value(enemy)
	_check_enemy_completion_bonus(enemy)


## AC-ED-01: required fields present and correctly typed.
## Checks: `id` non-empty, `display_name` non-empty, `enemy_class` ∈ {WILD,BOSS}
## (INVALID(0) = missing; any value outside {1,2} = unknown/reserved class),
## `stats` non-empty Dictionary, `skills` non-null (count checked separately),
## `ai_profile` StringName (presence only — referential seam lives in
## [method _check_enemy_ai_profile]).
## Every finding names the `enemy_id`.
func _check_enemy_schema_presence(enemy: EnemyDef) -> void:
	if enemy.id == &"":
		_error(&"content_enemy_schema_missing_field",
			{"enemy_id": enemy.id, "field": &"id", "display_name": enemy.display_name})
	if enemy.display_name == "":
		_error(&"content_enemy_schema_missing_field",
			{"enemy_id": enemy.id, "field": &"display_name"})
	# enemy_class: INVALID (0) is the unset sentinel; any value not in VALID_ENEMY_CLASSES
	# (which is {WILD=1, BOSS=2}) is a reserved/unknown class (ELITE/RIVAL are reserved
	# and not yet declared in EnemyClass, so they can only appear as INVALID=0 from
	# a stale .tres — but we guard the positive set explicitly anyway).
	if not VALID_ENEMY_CLASSES.has(int(enemy.enemy_class)):
		_error(&"content_enemy_schema_missing_field",
			{"enemy_id": enemy.id, "field": &"enemy_class", "value": int(enemy.enemy_class)})
	if enemy.stats.is_empty():
		_error(&"content_enemy_schema_missing_field",
			{"enemy_id": enemy.id, "field": &"stats"})


## AC-ED-02: every `id` is globally unique within the catalog. Two entries sharing
## the same id → error naming the duplicate. All-unique → no error.
func _check_enemy_id_uniqueness(catalog: EnemyCatalog) -> void:
	var seen := {}
	for enemy in catalog.entries:
		if enemy == null:
			continue
		if seen.has(enemy.id):
			_error(&"content_enemy_duplicate_id", {"enemy_id": enemy.id})
		else:
			seen[enemy.id] = true


## AC-ED-03 / TR-edb-019: skills count rules.
## `skills.size() == 0` → BLOCKING error (an enemy must have ≥1 skill to act);
## `skills.size() > ENEMY_SKILLS_MAX (4)` → ADVISORY warning (exceeds MVP intent).
## Size 1..4 → clean. The discriminating boundary: size 4 is clean, size 5 warns.
func _check_enemy_skills_count(enemy: EnemyDef) -> void:
	if enemy.skills.size() == 0:
		_error(&"content_enemy_skills_empty", {"enemy_id": enemy.id})
	elif enemy.skills.size() > ENEMY_SKILLS_MAX:
		_warn(&"content_enemy_skills_excess",
			{"enemy_id": enemy.id, "count": enemy.skills.size(), "max": ENEMY_SKILLS_MAX})


## AC-ED-03 / AC-ED-01(d): ai_profile checks.
## (1) Non-empty: `ai_profile == &""` → BLOCKING error.
## (2) Referential seam: a non-empty ai_profile is passed to the injected
##     `_ai_profile_checker` Callable. Default is accept-all (seam is inert until
##     the EnemyAI epic ships). Inject a reject-all Callable in tests to prove
##     the seam is wired — a non-empty ai_profile then errors with
##     `content_enemy_ai_profile_missing`.
func _check_enemy_ai_profile(enemy: EnemyDef) -> void:
	if enemy.ai_profile == &"":
		_error(&"content_enemy_ai_profile_missing",
			{"enemy_id": enemy.id, "reason": &"empty"})
		return
	# Seam: referential check via injected Callable. Default=accept-all until EnemyAI exists.
	if not _ai_profile_checker.call(enemy.ai_profile):
		_error(&"content_enemy_ai_profile_missing",
			{"enemy_id": enemy.id, "ai_profile": enemy.ai_profile, "reason": &"not_registered"})


## AC-ED-13a (ADVISORY): `tier != 1` → warning. Only tier 1 is live in MVP; higher
## tiers are reserved for Full Vision. A warning (never fatal) so the content
## pipeline can flag reserved-tier authoring without blocking the CI gate.
func _check_enemy_tier(enemy: EnemyDef) -> void:
	if enemy.tier != ENEMY_MVP_TIER:
		_warn(&"content_enemy_tier_reserved",
			{"enemy_id": enemy.id, "tier": enemy.tier, "expected": ENEMY_MVP_TIER})


## AC-ED-13b (BLOCKING): `flavor_text.length() > FLAVOR_TEXT_MAX` → error naming
## the `enemy_id`. A 100-char string PASSES; a 101-char string FAILS (boundary is
## inclusive ≤ 100). Empty flavor_text (length 0) passes this check; schema
## presence is [method _check_enemy_schema_presence]'s concern.
func _check_enemy_flavor_length(enemy: EnemyDef) -> void:
	if enemy.flavor_text.length() > FLAVOR_TEXT_MAX:
		_error(&"content_enemy_flavor_text_too_long",
			{"enemy_id": enemy.id, "length": enemy.flavor_text.length(), "max": FLAVOR_TEXT_MAX})


# ---------------------------------------------------------------------------
# Enemy-DB Story 005 — Enemy stat-block value family
# ---------------------------------------------------------------------------

## The four A/D stats that must stay within [STAT_AD_MIN, STAT_AD_MAX] per DF-1.
## `structure` is the HP pool and is NOT in this list (see GDD Rule 3 — structure
## is exempt from the [0,110] constraint). `mobility`, `processing`, and
## `output_power` have no hard content-validator bounds in this story.
## GDD source: Rule 3 — "physical_power, energy_power, armor, and resistance must
## stay within [0, 110]."
const STAT_AD_KEYS: Array[StringName] = [
	&"armor", &"resistance", &"physical_power", &"energy_power"
]

## Inclusive lower bound for A/D stats. 0 is a legal authored value (EC-ED-06:
## "physical_power = 0 is legal enemy content"). GDD source: Rule 3 "[0, 110]".
const STAT_AD_MIN := 0

## Inclusive upper bound for A/D stats. 110 PASSES; 111 FAILS. AC-ED-05(b):
## "implement as <= 110, not < 110". GDD source: Rule 3 "[0, 110]".
const STAT_AD_MAX := 110

## WILD power cap — physical_power and energy_power must not exceed this value
## for WILD enemies. GDD source: Tuning Knobs — WILD_POWER_CAP = 39.
## Derivation (GDD Rule 3): at A=40, D=0, T=1.5 → floor(1600/40 × 1.5) = 60 ≥ 60
## (one-shot); at A=39 → floor(1521/39 × 1.5) = 58 < 60 (no one-shot).
const WILD_POWER_CAP := 39

## The two power stats governed by the WILD_POWER_CAP. Both channels are checked
## independently (GDD Rule 3: "physical_power AND energy_power must not exceed 39").
const WILD_POWER_KEYS: Array[StringName] = [&"physical_power", &"energy_power"]

## The canonical 11-stat allow-list (TR-edb-011). Keys matching Part DB Rule 4
## vocabulary. An unknown key → ADVISORY warn. GDD source: Rule 3 — "identical
## 11-stat vocabulary from Part Database Rule 4". Same order as enemy_def.gd doc.
const STAT_ALLOW_LIST: Array[StringName] = [
	&"structure", &"armor", &"resistance", &"physical_power", &"energy_power",
	&"mobility", &"processing", &"cooling", &"energy_capacity", &"recharge",
	&"output_power",
]

## Dead-data keys: enemies have no Heat or Energy systems in MVP (TBC Rule 8 /
## TR-edb-012). Non-zero values for these are authored by mistake — warn.
## GDD source: Rule 3 dead-data note — "cooling, energy_capacity, and recharge
## keys are dead data in enemy stat blocks for MVP."
const DEAD_DATA_KEYS: Array[StringName] = [
	&"cooling", &"energy_capacity", &"recharge"
]


## AC-ED-05(a) — `structure` must be ≥ 1. A value of 0 (or absent key → defaults
## to 0 via .get) means the enemy has no HP pool and dies on contact — never valid
## content (EC-ED-06). Uses safe `.get` access: a missing key is treated as 0 and
## fails here (not a crash). Story 004 owns `stats` *presence*; this method owns
## the *value* of `structure`. Named constant `STAT_AD_MIN` does not apply here —
## structure has its own semantics (HP pool, not an A/D input).
func _check_enemy_stat_structure(enemy: EnemyDef) -> void:
	var structure: int = enemy.stats.get("structure", 0)
	if structure < 1:
		_error(&"content_enemy_stat_structure_invalid", {"enemy_id": enemy.id, "value": structure})


## AC-ED-05(b) — armor, resistance, physical_power, energy_power ∈ [STAT_AD_MIN,
## STAT_AD_MAX] (inclusive [0, 110]). Boundaries 0 and 110 PASS; 111 fails; -1
## fails. Uses safe `.get(key, 0)` — a missing key is 0 and passes (Story 004
## owns presence; here a missing key yields 0, which is in-range). Error names
## both the stat key and the enemy id so the author knows which stat to fix.
func _check_enemy_stat_ranges(enemy: EnemyDef) -> void:
	for stat_key: StringName in STAT_AD_KEYS:
		var value: int = enemy.stats.get(stat_key, 0)
		if value < STAT_AD_MIN or value > STAT_AD_MAX:
			_error(&"content_enemy_stat_out_of_range",
				{"enemy_id": enemy.id, "stat": stat_key, "value": value,
				"min": STAT_AD_MIN, "max": STAT_AD_MAX})


## AC-ED-05(c/d) — WILD power cap. Only fires when `enemy_class == WILD`; BOSS
## entries are explicitly exempt (GDD Rule 3: "BOSS power is exempt, up to 70").
## Checks both `physical_power` and `energy_power`. A WILD with power = 39 PASSES
## (boundary is inclusive ≤ 39); power = 40 FAILS. Uses safe `.get(key, 0)`.
func _check_enemy_wild_power_cap(enemy: EnemyDef) -> void:
	if enemy.enemy_class != EnemyDef.EnemyClass.WILD:
		return
	for power_key: StringName in WILD_POWER_KEYS:
		var value: int = enemy.stats.get(power_key, 0)
		if value > WILD_POWER_CAP:
			_error(&"content_enemy_stat_wild_power_cap",
				{"enemy_id": enemy.id, "stat": power_key, "value": value,
				"cap": WILD_POWER_CAP})


## TR-edb-011 (ADVISORY) — any `stats` key not in the 11-stat allow-list is a
## likely typo (e.g., `"powr"` instead of `"physical_power"`). Warns with the
## unknown key name so the author can correct it. Unknown keys are otherwise
## ignored per GDD Rule 3 / Part DB EC-08: "warn and ignore."
func _check_enemy_stat_unknown_keys(enemy: EnemyDef) -> void:
	for key: String in enemy.stats.keys():
		var sn_key: StringName = StringName(key)
		if not STAT_ALLOW_LIST.has(sn_key):
			_warn(&"content_enemy_stat_unknown_key",
				{"enemy_id": enemy.id, "key": sn_key})


## TR-edb-012 (ADVISORY) — cooling, energy_capacity, and recharge are dead data
## in enemy stat blocks (TBC Rule 8: enemies track no Heat or Energy). A non-zero
## value means the author copied from a Part def without clearing enemy-irrelevant
## fields. Warns per offending key. Zero values (the correct authored state) are
## silently accepted. Uses `.get(key, 0)` — absent key is 0 and passes.
func _check_enemy_stat_dead_data(enemy: EnemyDef) -> void:
	for dd_key: StringName in DEAD_DATA_KEYS:
		var value: int = enemy.stats.get(dd_key, 0)
		if value != 0:
			_warn(&"content_enemy_stat_dead_data",
				{"enemy_id": enemy.id, "stat": dd_key, "value": value})


# ---------------------------------------------------------------------------
# Enemy-DB Story 006 — Break-region validation family
# ---------------------------------------------------------------------------

## Inclusive lower bound for region_fraction (TR-edb-014, GDD Tuning Knobs:
## REGION_FRACTION_MIN = 0.15). Boundary values PASS; outside → error.
## GDD source: "REGION_FRACTION_MIN | 0.15 | 0.10–0.20"
const REGION_FRACTION_MIN := 0.15

## Inclusive upper bound for region_fraction (TR-edb-014, GDD Tuning Knobs:
## REGION_FRACTION_MAX = 0.55). Boundary values PASS; outside → error.
## GDD source: "REGION_FRACTION_MAX | 0.55 | 0.45–0.60"
const REGION_FRACTION_MAX := 0.55

## Tolerance for region_fraction boundary comparisons (AC-ED-07(d)).
## Required because 0.15 and 0.55 are not exactly representable in IEEE 754 —
## a strict `>=` / `<=` on a correctly-authored boundary value may fail if the
## stored float rounds inward. ±1e-9 is wide enough to accept authored values
## while being well below the 0.01 authoring granularity.
const REGION_FRACTION_TOLERANCE := 1e-9

## String key for the region's unique identifier field (authored .tres convention
## uses String keys, not StringName, for untyped Dictionary entries — EnemyDef.break_regions).
const REGION_KEY_ID := "region_id"
const REGION_KEY_FRACTION := "region_fraction"
const REGION_KEY_BREAK_HP := "break_hp"
const REGION_KEY_BREAK_EVENT := "break_event"

## String key for the loot connectivity linkage — loot_pool entry's drop_condition
## key that must match the region's break_event (GDD Rule 5 / EDB-3).
const LOOT_KEY_DROP_CONDITION := "drop_condition"
const LOOT_KEY_BREAK_EVENT := "break_event"


## Story 006 top-level dispatch: validates all break-region invariants for one
## enemy. Called per-enemy from [method _validate_enemy] after the stat family.
##
## Checks in order:
##   (1) ≥1 region (TR-edb-022 / EC-ED-01)
##   (2) Per-region: stored == derived, break_hp < structure, fraction bounds,
##       loot connectivity (TR-edb-002, TR-edb-004, TR-edb-014)
##   (3) region_id set-uniqueness across all regions (TR-edb-004 / EC-ED-08)
##
## break_event uniqueness is intentionally NOT checked — same break_event on
## multiple regions is legal set semantics (TR-edb-021 / EC-ED-07 / AC-ED-20).
func _check_enemy_break_regions(enemy: EnemyDef) -> void:
	if enemy.break_regions.is_empty():
		_error(&"content_enemy_break_no_regions", {"enemy_id": enemy.id})
		return

	var structure: int = enemy.stats.get("structure", 0)

	# Pass 1: per-region value checks.
	for region: Dictionary in enemy.break_regions:
		_check_break_region_values(enemy, region, structure)

	# Pass 2: region_id uniqueness across the enemy's full region list.
	# Separate pass so we collect all per-region errors before the set check.
	_check_break_region_id_uniqueness(enemy)


## AC-ED-07(a) stored-equals-derived: calls Story-003's [BreakHpFormula.derive_break_hp]
## and does an exact int compare. The formula owns the +0.0001 epsilon — do NOT
## re-implement it here (Control Manifest: Forbidden).
##
## AC-ED-07(b) EDB-3: break_hp < structure AND loot-connected.
##
## AC-ED-07(d) region_fraction bounds: [REGION_FRACTION_MIN, REGION_FRACTION_MAX]
## compared with ±REGION_FRACTION_TOLERANCE. Boundary values must pass; a naked
## `>=` / `<=` on raw floats may reject correctly-authored content (EC-ED-11).
func _check_break_region_values(enemy: EnemyDef, region: Dictionary, structure: int) -> void:
	var region_id: String = region.get(REGION_KEY_ID, "")
	var region_fraction: float = region.get(REGION_KEY_FRACTION, 0.0)
	var break_hp: int = region.get(REGION_KEY_BREAK_HP, 0)

	# --- Stored == derived (TR-edb-002) ---
	var derived: int = BreakHpFormula.derive_break_hp(structure, region_fraction)
	if break_hp != derived:
		_error(&"content_enemy_break_hp_mismatch",
			{"enemy_id": enemy.id, "region_id": region_id,
			 "stored": break_hp, "derived": derived})

	# --- break_hp < structure (TR-edb-004 / EDB-3) ---
	if break_hp >= structure:
		_error(&"content_enemy_break_hp_exceeds_structure",
			{"enemy_id": enemy.id, "region_id": region_id,
			 "break_hp": break_hp, "structure": structure})

	# --- region_fraction bounds (TR-edb-014) with ±tolerance (AC-ED-07(d)) ---
	# Compare with tolerance so authored boundary values (0.15, 0.55) pass even
	# when IEEE 754 representation rounds inward. DO NOT use `==` on raw floats.
	var frac_too_low: bool = region_fraction < REGION_FRACTION_MIN - REGION_FRACTION_TOLERANCE
	var frac_too_high: bool = region_fraction > REGION_FRACTION_MAX + REGION_FRACTION_TOLERANCE
	if frac_too_low or frac_too_high:
		_error(&"content_enemy_break_fraction_out_of_range",
			{"enemy_id": enemy.id, "region_id": region_id,
			 "region_fraction": region_fraction,
			 "min": REGION_FRACTION_MIN, "max": REGION_FRACTION_MAX})

	# --- Loot connectivity (TR-edb-004 / EDB-3 loot_connected clause) ---
	# A region whose break_event is referenced by NO loot_pool entry is a dead
	# UI element — violates Pillar 2 (EDB-3 counter-example: "a break pip that
	# boosts nothing"). Check both "drop_condition" and "break_event" linkage keys
	# per EnemyDef.loot_pool shape documentation.
	var break_event: String = region.get(REGION_KEY_BREAK_EVENT, "")
	if not _is_region_loot_connected(enemy.loot_pool, break_event):
		_error(&"content_enemy_break_region_orphan",
			{"enemy_id": enemy.id, "region_id": region_id, "break_event": break_event})


## Returns true if `break_event` is referenced by at least one entry in
## `loot_pool` via the "drop_condition" or "break_event" linkage keys.
## An empty `break_event` string never matches (no connection).
func _is_region_loot_connected(loot_pool: Array[Dictionary], break_event: String) -> bool:
	if break_event.is_empty():
		return false
	for entry: Dictionary in loot_pool:
		# Check "drop_condition" key (primary linkage per EnemyDef doc comment)
		if entry.get(LOOT_KEY_DROP_CONDITION, "") == break_event:
			return true
		# Check "break_event" key (alternative linkage per EnemyDef doc comment)
		if entry.get(LOOT_KEY_BREAK_EVENT, "") == break_event:
			return true
	return false


## AC-ED-07(c) / EC-ED-08: duplicate region_id within one enemy → error.
## Only region_id is checked for uniqueness — break_event is explicitly NOT
## unique-checked (TR-edb-021 / EC-ED-07 / AC-ED-20: shared break_event is legal).
func _check_break_region_id_uniqueness(enemy: EnemyDef) -> void:
	var seen_ids: Dictionary = {}
	for region: Dictionary in enemy.break_regions:
		var region_id: String = region.get(REGION_KEY_ID, "")
		if seen_ids.has(region_id):
			_error(&"content_enemy_break_region_id_duplicate",
				{"enemy_id": enemy.id, "region_id": region_id})
		else:
			seen_ids[region_id] = true


# ---------------------------------------------------------------------------
# Enemy-DB Story 007 — Loot-pool, rarity & boss-grade gating family
# ---------------------------------------------------------------------------

## String key for a `loot_pool` entry's referenced Part-DB id (authored .tres
## convention uses a String key; the VALUE may be String or StringName).
const LOOT_KEY_ID := "id"

## `drop_conditions` entry keys on the resolved [PartDef] (String keys, per the
## authored `.tres` convention shared with the Part validator — `condition` VALUE
## is a StringName, `multiplier` a float > 1.0).
const DROP_KEY_CONDITION := "condition"
const DROP_KEY_MULTIPLIER := "multiplier"

## Boss-grade base drop rate (Part DB Tuning Knobs — `BASE_DROP_BOSS_GRADE`). The
## AC-ED-09 product invariant is `base × multiplier >= BOSS_GRADE_BREAK_GUARANTEE`;
## the AC asserts the PRODUCT, never a hardcoded ×500 (survives base-rate retuning).
const BASE_DROP_BOSS_GRADE := 0.001

## The AC-ED-09 product floor (GDD Tuning Knobs — `BOSS_GRADE_BREAK_GUARANTEE` = 0.5,
## ~50% per qualifying break). At the current base rate the boundary is multiplier
## 500 → product exactly 0.5 (verified in IEEE-754 double: `0.001 * 500.0 == 0.5`,
## `0.001 * 499.0 == 0.499`). The product is exact at the boundary, so no epsilon is
## needed here (unlike the floor formulas). multiplier 500 PASSES; 499 FAILS.
const BOSS_GRADE_BREAK_GUARANTEE := 0.5

## Minimum distinct break-gated pool parts before an advisory warning (AC-ED-19).
## GDD: applies to EVERY enemy (not BOSS-only) — the harvest-decision rule (Rule 6)
## wants ≥2 break-gated parts on WILD pools too so the "which region?" choice exists.
## NOTE: Story 007's inline notes narrow this to BOSS-only; the GDD AC-ED-19 text
## ("for every enemy entry") is the source of truth and is what this implements.
const MIN_BREAK_GATED_PARTS := 2


## Story 007 top-level dispatch: resolves each `loot_pool` id through the injected
## Part-DB seam, then runs referential / rarity / boss-grade / floor-loot / harvest
## checks against the resolved [PartDef]s. Only reached when [member _part_lookup]
## is valid (see [method _validate_enemy]).
##
## Checks:
##   - referential integrity (AC-ED-04a): unresolved id → error
##   - dedup (AC-ED-04d, ADVISORY): duplicate id within the pool → warn (deduped)
##   - all-disabled (AC-ED-04b): every resolved part `drop_enabled == false` → error
##   - some-disabled (AC-ED-04c, ADVISORY): a disabled resolved part → warn per entry
##   - class rarity (AC-ED-06): WILD carrying Boss-grade → error; BOSS Boss-grade
##     count ∉ {1,2} → error
##   - boss-grade gating (AC-ED-09): a BOSS's Boss-grade part lacking a break-gated
##     drop condition meeting the product floor → error
##   - floor-loot rarity (AC-ED-18, ADVISORY): un-gated Rare/Boss-grade part → warn
##   - min break-gated (AC-ED-19, ADVISORY): fewer than 2 break-gated parts → warn
func _check_enemy_loot(enemy: EnemyDef) -> void:
	# --- Pass 1: resolve + dedup + enabled accounting ---
	var resolved: Array[PartDef] = []
	var seen_ids: Dictionary = {}
	for entry: Dictionary in enemy.loot_pool:
		var pid: StringName = _loot_entry_id(entry)
		if seen_ids.has(pid):
			_warn(&"content_enemy_loot_duplicate_part",
				{"enemy_id": enemy.id, "part_id": pid})
			continue
		seen_ids[pid] = true

		var part: PartDef = _part_lookup.call(pid)
		if part == null:
			_error(&"content_enemy_loot_unresolved_part",
				{"enemy_id": enemy.id, "part_id": pid})
			continue
		resolved.append(part)

	# --- disabled accounting over the resolved (unique) set ---
	_check_loot_disabled(enemy, resolved)
	# --- class-aware rarity + boss-grade gating + advisory harvest checks ---
	_check_loot_rarity(enemy, resolved)
	_check_loot_boss_grade_gating(enemy, resolved)
	_check_loot_floor_rarity(enemy, resolved)
	_check_loot_min_break_gated(enemy, resolved)


## AC-ED-04(b/c): a resolved part whose `drop_enabled == false` warns per entry
## (some-disabled, ADVISORY); if EVERY resolved part is disabled → the pool drops
## nothing → error (all-disabled, BLOCKING). A pool whose entries all failed to
## resolve leaves `resolved` empty — the all-disabled error does not double-fire on
## top of the per-entry unresolved errors.
func _check_loot_disabled(enemy: EnemyDef, resolved: Array[PartDef]) -> void:
	if resolved.is_empty():
		return
	var enabled_count := 0
	for part: PartDef in resolved:
		if part.drop_enabled:
			enabled_count += 1
		else:
			_warn(&"content_enemy_loot_disabled_entry",
				{"enemy_id": enemy.id, "part_id": part.id})
	if enabled_count == 0:
		_error(&"content_enemy_loot_all_disabled", {"enemy_id": enemy.id})


## AC-ED-06 class/pool rarity. WILD: no Boss-grade part may appear (Part DB Rule 8)
## — error per offending part. BOSS: the count of Boss-grade parts must be 1 or 2 —
## 0 or ≥3 → error. Boundaries: exactly 1 passes, exactly 2 passes, 0 fails, 3 fails.
func _check_loot_rarity(enemy: EnemyDef, resolved: Array[PartDef]) -> void:
	if enemy.enemy_class == EnemyDef.EnemyClass.WILD:
		for part: PartDef in resolved:
			if part.rarity == PartDef.Rarity.BOSS_GRADE:
				_error(&"content_enemy_loot_rarity_violation",
					{"enemy_id": enemy.id, "part_id": part.id,
					 "reason": &"wild_carries_boss_grade"})
	elif enemy.enemy_class == EnemyDef.EnemyClass.BOSS:
		var boss_grade_count := 0
		for part: PartDef in resolved:
			if part.rarity == PartDef.Rarity.BOSS_GRADE:
				boss_grade_count += 1
		if boss_grade_count < 1 or boss_grade_count > 2:
			_error(&"content_enemy_loot_rarity_violation",
				{"enemy_id": enemy.id, "reason": &"boss_grade_count",
				 "count": boss_grade_count, "min": 1, "max": 2})


## AC-ED-09 boss-grade break gating (BOSS-only). Every Boss-grade pool part must
## carry ≥1 `drop_conditions` entry whose `condition` is one of this enemy's break
## events AND whose product `BASE_DROP_BOSS_GRADE × multiplier >= BOSS_GRADE_BREAK_GUARANTEE`.
## A Boss-grade drop that no qualifying break can make obtainable → error. The AC
## asserts the product (not ×500) so the invariant survives base-rate retuning.
func _check_loot_boss_grade_gating(enemy: EnemyDef, resolved: Array[PartDef]) -> void:
	if enemy.enemy_class != EnemyDef.EnemyClass.BOSS:
		return
	var break_events: Dictionary = _enemy_break_events(enemy)
	for part: PartDef in resolved:
		if part.rarity != PartDef.Rarity.BOSS_GRADE:
			continue
		if not _has_qualifying_boss_gate(part, break_events):
			_error(&"content_enemy_loot_boss_grade_ungated",
				{"enemy_id": enemy.id, "part_id": part.id,
				 "base_rate": BASE_DROP_BOSS_GRADE, "guarantee": BOSS_GRADE_BREAK_GUARANTEE})


## True if `part` has a `drop_conditions` entry keyed to one of `break_events` whose
## product meets the AC-ED-09 floor. The product compare is exact at the boundary
## (multiplier 500 → 0.5) — no float tolerance (verified: `0.001 * 500.0 == 0.5`).
func _has_qualifying_boss_gate(part: PartDef, break_events: Dictionary) -> bool:
	for cond: Dictionary in part.drop_conditions:
		var cond_sn: StringName = _condition_name(cond)
		if cond_sn == &"" or not break_events.has(cond_sn):
			continue
		var multiplier: float = float(cond.get(DROP_KEY_MULTIPLIER, 0.0))
		if BASE_DROP_BOSS_GRADE * multiplier >= BOSS_GRADE_BREAK_GUARANTEE:
			return true
	return false


## AC-ED-18 (ADVISORY): a Rare or Boss-grade pool part with NO `drop_conditions`
## entry matching any of this enemy's break events is un-gated floor loot — it drops
## at base rate with no harvest incentive, silently undermining Pillar 2 → warn.
func _check_loot_floor_rarity(enemy: EnemyDef, resolved: Array[PartDef]) -> void:
	var break_events: Dictionary = _enemy_break_events(enemy)
	for part: PartDef in resolved:
		var is_gated_rarity: bool = (part.rarity == PartDef.Rarity.RARE
			or part.rarity == PartDef.Rarity.BOSS_GRADE)
		if is_gated_rarity and not _part_is_break_gated(part, break_events):
			_warn(&"content_enemy_loot_floor_rarity",
				{"enemy_id": enemy.id, "part_id": part.id, "rarity": int(part.rarity)})


## AC-ED-19 (ADVISORY): fewer than [constant MIN_BREAK_GATED_PARTS] distinct
## break-gated pool parts means the "which region do I commit to?" prioritization
## choice is degenerate → warn. Applies to every enemy (see [constant MIN_BREAK_GATED_PARTS]).
func _check_loot_min_break_gated(enemy: EnemyDef, resolved: Array[PartDef]) -> void:
	var break_events: Dictionary = _enemy_break_events(enemy)
	var gated_count := 0
	for part: PartDef in resolved:
		if _part_is_break_gated(part, break_events):
			gated_count += 1
	if gated_count < MIN_BREAK_GATED_PARTS:
		_warn(&"content_enemy_loot_min_break_gated",
			{"enemy_id": enemy.id, "count": gated_count, "min": MIN_BREAK_GATED_PARTS})


## The set (Dictionary-as-set) of this enemy's `break_event` StringNames across all
## regions. Empty break_event strings are excluded (they never gate anything).
func _enemy_break_events(enemy: EnemyDef) -> Dictionary:
	var events: Dictionary = {}
	for region: Dictionary in enemy.break_regions:
		var raw: String = region.get(REGION_KEY_BREAK_EVENT, "")
		if raw != "":
			events[StringName(raw)] = true
	return events


## True if `part` has any `drop_conditions` entry whose `condition` is one of
## `break_events` (the syntactic break-gated predicate shared by AC-ED-18/19; the
## multiplier floor is Part DB's concern, not re-checked here).
func _part_is_break_gated(part: PartDef, break_events: Dictionary) -> bool:
	for cond: Dictionary in part.drop_conditions:
		var cond_sn: StringName = _condition_name(cond)
		if cond_sn != &"" and break_events.has(cond_sn):
			return true
	return false


## Normalize a `drop_conditions` entry's `condition` value to a StringName
## (authored .tres stores it as StringName; tolerate a String too). Missing → `&""`.
func _condition_name(cond: Dictionary) -> StringName:
	var raw: Variant = cond.get(DROP_KEY_CONDITION, null)
	if raw is StringName:
		return raw
	if raw is String:
		return StringName(raw)
	return &""


## Normalize a `loot_pool` entry's referenced part id to a StringName. Authored
## .tres may store it as String or StringName; missing → `&""` (never resolves).
func _loot_entry_id(entry: Dictionary) -> StringName:
	var raw: Variant = entry.get(LOOT_KEY_ID, null)
	if raw is StringName:
		return raw
	if raw is String:
		return StringName(raw)
	return &""


# ---------------------------------------------------------------------------
# Enemy-DB Story 008 — Harvest-decision (BLOCKING) + TTK / density advisories
# ---------------------------------------------------------------------------

## EDB-2 calibration attacker power for WILD-early enemies (A_cal). GDD source:
## Formula EDB-2 TTK-bands table — "WILD (early) | 35". These are the fixed
## calibration attacker stats (the "reference attacker"), NOT a BalanceConfig
## input — AC-ED-14 defines A_cal as class-selected literals, not injected data.
const TTK_A_CAL_WILD_EARLY := 35

## EDB-2 calibration attacker power for WILD-mid and BOSS enemies (A_cal). GDD
## source: Formula EDB-2 TTK-bands table — "WILD (mid) | 53", "BOSS | 53".
const TTK_A_CAL_MID := 53

## Structure ceiling separating WILD-early from WILD-mid for A_cal selection
## (AC-ED-14): `structure < 90` → WILD-early (A_cal 35, band 2–4); `structure >= 90`
## and class WILD → WILD-mid (A_cal 53, band 3–5). Boundary fixtures: structure 89
## → early, structure 90 → mid.
const TTK_WILD_MID_STRUCTURE := 90

## Normative TTK bands per class (inclusive, AC-ED-14). A TTK *at* a band edge
## produces NO warning; one turn outside warns (BOSS TTK 12 silent, 11 warns; 18
## silent, 19 warns). GDD source: Formula EDB-2 "TTK bands (normative)".
const TTK_BAND_WILD_EARLY_MIN := 2
const TTK_BAND_WILD_EARLY_MAX := 4
const TTK_BAND_WILD_MID_MIN := 3
const TTK_BAND_WILD_MID_MAX := 5
const TTK_BAND_BOSS_MIN := 12
const TTK_BAND_BOSS_MAX := 18

## Max break_regions before the density guideline warns (AC-ED-15a). MVP intent is
## 2–3 regions; `size > 3` warns. The `>= 1` minimum is BLOCKING via Story 006.
const DENSITY_BREAK_REGIONS_MAX := 3

## WILD loot_pool size guideline (AC-ED-15b): `size < 2 OR size > 4` warns. Empty
## pool is BLOCKING elsewhere; this is the advisory band. Boundaries: 2 silent,
## 1 warns, 4 silent, 5 warns.
const DENSITY_WILD_POOL_MIN := 2
const DENSITY_WILD_POOL_MAX := 4

## BOSS loot_pool size guideline (AC-ED-15b): `size < 4 OR size > 6` warns.
## Boundaries: 4 silent, 3 warns, 6 silent, 7 warns.
const DENSITY_BOSS_POOL_MIN := 4
const DENSITY_BOSS_POOL_MAX := 6

## Max null-element (`core_element == INVALID/0`) WILD entries per zone before the
## catalog-level advisory warns (AC-ED-15d). GDD Tuning Knobs: `NULL_ELEMENT_MAX_WILD`
## = 1. Boundary: 1 null-element WILD silent, 2 warns. A null-element enemy mutes the
## type-mastery fantasy, so "use sparingly" is a validated rule.
const NULL_ELEMENT_MAX_WILD := 1


## AC-ED-15c / TR-edb-010 (BLOCKING — the sole blocking check in Story 008):
## the harvest-decision rule (GDD Rule 6). Every enemy must satisfy
## `loot_pool.size() > break_regions.size()` (STRICTLY greater) so at least one
## pool part is obtainable without committing to a specific region break — the
## "which region?" choice only exists when there is a floor drop plus break-gated
## extras. Equality or fewer → error. Boundaries: 2 regions + 3 pool → passes;
## 2 regions + 2 pool → fails; 1 region + 1 pool → fails; 1 region + 2 pool → passes.
func _check_enemy_harvest_decision(enemy: EnemyDef) -> void:
	if enemy.loot_pool.size() <= enemy.break_regions.size():
		_error(&"content_enemy_harvest_decision",
			{"enemy_id": enemy.id, "loot_count": enemy.loot_pool.size(),
			 "region_count": enemy.break_regions.size()})


## AC-ED-14 (ADVISORY): EDB-2 computed-TTK band check. For each defense channel
## (armor, then resistance) computes `dmg = floor(A_cal² / (A_cal + D))` and
## `TTK = ceil(structure / dmg)`, warning when either channel's TTK falls outside
## the class band. Both channels are checked independently (a single-channel check
## would miss the GDD dual-channel fixture: armor-channel out-of-band while resist
## is in-band). NEVER a hard error — TTK-band deviations are pacing concerns, not
## correctness failures.
##
## Pure INTEGER arithmetic: `dmg` uses GDScript int/int (floor for positives) and
## `TTK` uses the integer-ceil identity `(structure + dmg - 1) / dmg`. Verified by
## exhaustive scan (A_cal ∈ {35,53}, D 0–200, structure 1–700): the integer ceil
## matches math.ceil with ZERO divergences and reproduces both GDD worked fixtures
## (dmg 48 → TTK 9; dmg 24 → TTK 17). No float/epsilon appears anywhere here.
##
## Runs only for WILD/BOSS (class already error-flagged by Story 004 otherwise) and
## only when `structure >= 1` (a structure-less enemy is already a BLOCKING Story-005
## error; a TTK warning on top would be pure noise). Uses `.get("structure", 0)` so
## it never crashes on an absent stat key (AC-ED-14 must not assume Story 005 ran).
func _check_enemy_ttk_band(enemy: EnemyDef) -> void:
	var structure: int = enemy.stats.get("structure", 0)
	if structure < 1:
		return

	var a_cal: int
	var band_min: int
	var band_max: int
	if enemy.enemy_class == EnemyDef.EnemyClass.BOSS:
		a_cal = TTK_A_CAL_MID
		band_min = TTK_BAND_BOSS_MIN
		band_max = TTK_BAND_BOSS_MAX
	elif enemy.enemy_class == EnemyDef.EnemyClass.WILD:
		if structure < TTK_WILD_MID_STRUCTURE:
			a_cal = TTK_A_CAL_WILD_EARLY
			band_min = TTK_BAND_WILD_EARLY_MIN
			band_max = TTK_BAND_WILD_EARLY_MAX
		else:
			a_cal = TTK_A_CAL_MID
			band_min = TTK_BAND_WILD_MID_MIN
			band_max = TTK_BAND_WILD_MID_MAX
	else:
		# INVALID / reserved class — Story 004 already errored on it; nothing to band.
		return

	_check_ttk_channel(enemy, structure, a_cal, &"armor", band_min, band_max)
	_check_ttk_channel(enemy, structure, a_cal, &"resistance", band_min, band_max)


## Computes one defense channel's TTK and warns if outside [band_min, band_max].
## `defense_stat` is the stat key for D (`&"armor"` or `&"resistance"`). At-edge
## values produce no warning (inclusive band). Skips silently if `dmg <= 0`
## (unreachable for A_cal ≥ 35, but defensive — never divides by zero).
func _check_ttk_channel(enemy: EnemyDef, structure: int, a_cal: int,
		defense_stat: StringName, band_min: int, band_max: int) -> void:
	var defense: int = enemy.stats.get(defense_stat, 0)
	var dmg: int = (a_cal * a_cal) / (a_cal + defense)  # floor (int/int for positives)
	if dmg <= 0:
		return
	var ttk: int = (structure + dmg - 1) / dmg          # integer ceil
	if ttk < band_min or ttk > band_max:
		_warn(&"content_enemy_ttk_out_of_band",
			{"enemy_id": enemy.id, "channel": defense_stat, "ttk": ttk,
			 "band_min": band_min, "band_max": band_max, "a_cal": a_cal})


## AC-ED-15a/b (ADVISORY): content-density guidelines. Warns when `break_regions`
## exceeds the MVP cap (>3) and when `loot_pool` size falls outside the class band
## (WILD 2–4, BOSS 4–6). Each dimension warns independently with the same
## `content_enemy_density_guideline` code, tagged by `dimension` so the author knows
## which count to adjust. These are pacing hints, never blocking (the hard minimums
## live in Stories 004/006).
func _check_enemy_content_density(enemy: EnemyDef) -> void:
	if enemy.break_regions.size() > DENSITY_BREAK_REGIONS_MAX:
		_warn(&"content_enemy_density_guideline",
			{"enemy_id": enemy.id, "dimension": &"break_regions",
			 "count": enemy.break_regions.size(), "max": DENSITY_BREAK_REGIONS_MAX})

	var pool_size: int = enemy.loot_pool.size()
	if enemy.enemy_class == EnemyDef.EnemyClass.BOSS:
		if pool_size < DENSITY_BOSS_POOL_MIN or pool_size > DENSITY_BOSS_POOL_MAX:
			_warn(&"content_enemy_density_guideline",
				{"enemy_id": enemy.id, "dimension": &"loot_pool", "count": pool_size,
				 "min": DENSITY_BOSS_POOL_MIN, "max": DENSITY_BOSS_POOL_MAX})
	elif enemy.enemy_class == EnemyDef.EnemyClass.WILD:
		if pool_size < DENSITY_WILD_POOL_MIN or pool_size > DENSITY_WILD_POOL_MAX:
			_warn(&"content_enemy_density_guideline",
				{"enemy_id": enemy.id, "dimension": &"loot_pool", "count": pool_size,
				 "min": DENSITY_WILD_POOL_MIN, "max": DENSITY_WILD_POOL_MAX})


## AC-ED-17 (ADVISORY): a BOSS authored with `spawn_enabled == false` is progression
## risk — a boss retired from spawn tables can lock zone completion. Warns so the
## author confirms the retirement is intentional. WILD entries get NO warning
## (retiring a wild is routine content management).
func _check_enemy_boss_spawn(enemy: EnemyDef) -> void:
	if enemy.enemy_class == EnemyDef.EnemyClass.BOSS and not enemy.spawn_enabled:
		_warn(&"content_enemy_boss_spawn_disabled", {"enemy_id": enemy.id})


## AC-ED-15d (ADVISORY, catalog/zone-scoped): counts WILD entries whose
## `core_element` is the null/INVALID sentinel (0 — "no elemental affinity", a legal
## authored state per EnemyDef). More than `NULL_ELEMENT_MAX_WILD` such entries mutes
## the type-mastery fantasy for too much of the roster → one catalog-level warning
## carrying the observed count. Only WILD entries count (a null-element BOSS is a
## deliberate "neutral wall" archetype, not roster dilution). MVP has one zone, so
## catalog-scope == zone-scope.
func _check_enemy_null_element_density(catalog: EnemyCatalog) -> void:
	var null_wild_count := 0
	for enemy in catalog.entries:
		if enemy == null:
			continue
		if enemy.enemy_class == EnemyDef.EnemyClass.WILD and int(enemy.core_element) == 0:
			null_wild_count += 1
	if null_wild_count > NULL_ELEMENT_MAX_WILD:
		_warn(&"content_enemy_null_element_density",
			{"count": null_wild_count, "max": NULL_ELEMENT_MAX_WILD})


# ---------------------------------------------------------------------------
# Enemy-DB Story 009 — ELZS progression fields (level / xp_value / completion_bonus)
# ---------------------------------------------------------------------------

## Enemy level range (TR-edb-017, GDD Rule 1 `level` row). Level is a power-tier
## label in [1, MAX_ENEMY_LEVEL]; 0 or missing is a BLOCKING content error.
const MIN_ENEMY_LEVEL := 1
const MAX_ENEMY_LEVEL := 10

## AC-ELZS/TR-edb-017 (BLOCKING): `level` must sit in [MIN_ENEMY_LEVEL, MAX_ENEMY_LEVEL]
## inclusive. Boundaries: 1 and 10 pass; 0 and 11 error. An exclusive-bound impl would
## wrongly reject 1 or 10 — the boundary fixtures in the evidence test guard against that.
func _check_enemy_level_range(enemy: EnemyDef) -> void:
	if enemy.level < MIN_ENEMY_LEVEL or enemy.level > MAX_ENEMY_LEVEL:
		_error(&"content_enemy_progression_level_range",
			{"enemy_id": enemy.id, "level": enemy.level,
			 "min": MIN_ENEMY_LEVEL, "max": MAX_ENEMY_LEVEL})


## AC-ELZS-02 / TR-edb-015 (BLOCKING): the stored-equals-derived invariant on
## `xp_value`. Re-derives CP-F4 via [XpRewardFormula] (the single formula home — never
## paste the math here) and errors when the authored value diverges (e.g. after a
## CP-F4 constants retune, or a wrong-role / no-multiplier authoring bug). Runs only
## for WILD/BOSS: an INVALID class is already a Story-004 error and CP-F4's role
## multiplier is undefined for it, so an xp mismatch on top would be pure noise.
func _check_enemy_xp_value(enemy: EnemyDef) -> void:
	if enemy.enemy_class != EnemyDef.EnemyClass.WILD \
			and enemy.enemy_class != EnemyDef.EnemyClass.BOSS:
		return
	var derived: int = XpRewardFormula.derive_xp_value(enemy.level, enemy.enemy_class)
	if enemy.xp_value != derived:
		_error(&"content_enemy_progression_xp_mismatch",
			{"enemy_id": enemy.id, "stored": enemy.xp_value, "derived": derived,
			 "level": enemy.level})


## TR-edb-016 (BLOCKING): completion-bonus rules. `completion_bonus_xp` must be `>= 0`
## (a negative bonus is nonsense) AND `0` unless the enemy is a BOSS — the one-time
## zone-completion bonus is a boss-only reward vector (a class-blind impl would wrongly
## pass a positive bonus on a WILD). The two failure modes error independently so an
## author sees exactly which rule a value breaks.
func _check_enemy_completion_bonus(enemy: EnemyDef) -> void:
	if enemy.completion_bonus_xp < 0:
		_error(&"content_enemy_progression_bonus_negative",
			{"enemy_id": enemy.id, "completion_bonus_xp": enemy.completion_bonus_xp})
	if enemy.completion_bonus_xp > 0 and enemy.enemy_class != EnemyDef.EnemyClass.BOSS:
		_error(&"content_enemy_progression_bonus_non_boss",
			{"enemy_id": enemy.id, "completion_bonus_xp": enemy.completion_bonus_xp,
			 "enemy_class": enemy.enemy_class})
