## Part-DB Story 008 — ContentValidator content-composition family.
##
## Covers GDD AC-04/10/11/12/19/23: synergy tags, Prototype ±/concentration,
## Boss-grade break condition, stat budgets, and Common-cap / Rare-floor primary
## bounds. These families run ONLY when a [BalanceConfig] is injected via
## [member ContentCatalogs.balance]; every `_run` here injects one. Per ADR-0003
## each family pairs a CLEAN fixture (passes) with a discriminating CORRUPT one
## (must fail). Diagnostics are asserted on the injected spy [LogSink]. The
## AC-10→AC-19 ordering guard (no divide-by-zero) is asserted directly.
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

var _spy
var _cfg: BalanceConfig


func before_each() -> void:
	_cfg = BalanceConfig.new()  # GDD-default budget / cap / floor tables


# ---------------------------------------------------------------------------
# Fixtures & harness
# ---------------------------------------------------------------------------

## Build a properly-typed stat_bonuses dictionary from a plain literal.
func _sb(values: Dictionary) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for k in values:
		out[k] = values[k]
	return out


## A fully-valid Common HEAD (boltwell / VOLT). Primary stat = targeting; the
## Common HEAD cap is 11 and the budget is [12,16]. Baseline for corruptions.
func _common_head(id: StringName) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.display_name = "Test %s" % id
	p.slot_type = PartDef.SlotType.HEAD
	p.rarity = PartDef.Rarity.COMMON
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.sprite_id = &"spr_%s" % id
	p.synergy_tags = [&"volt", &"boltwell"]
	p.stat_bonuses = _sb({&"targeting": 10, &"cooling": 4})  # sum 14, primary 10 ≤ cap 11
	return p


## A valid Rare HEAD: skill required (→ real damage_type); primary targeting must
## meet the Rare HEAD floor 17; budget [22,28].
func _rare_head(id: StringName) -> PartDef:
	var p := _common_head(id)
	p.rarity = PartDef.Rarity.RARE
	p.active_skill_id = &"skill_%s" % id
	p.damage_type = PartDef.DamageType.ENERGY
	p.stat_bonuses = _sb({&"targeting": 18, &"cooling": 6})  # sum 24, primary 18 ≥ floor 17
	return p


## A valid Boss-grade HEAD: skill + passive required; a ≥500 break condition;
## budget [35,42] (primary uncapped for Boss).
func _boss_head(id: StringName) -> PartDef:
	var p := _rare_head(id)
	p.rarity = PartDef.Rarity.BOSS_GRADE
	p.passive_id = &"passive_%s" % id
	p.stat_bonuses = _sb({&"targeting": 30, &"cooling": 10})  # sum 40
	p.drop_conditions = [{"condition": &"break_head", "multiplier": 500.0}]
	return p


## A valid Prototype HEAD: skill + passive; ≥1 negative drawback; positive budget
## [28,38] concentrated ≥70% in 1–2 stats.
func _proto_head(id: StringName) -> PartDef:
	var p := _rare_head(id)
	p.rarity = PartDef.Rarity.PROTOTYPE
	p.passive_id = &"passive_%s" % id
	p.stat_bonuses = _sb({&"targeting": 30, &"cooling": 5, &"mobility": -8})  # +35, ratio 1.0
	return p


## A valid Boss-grade CHASSIS (needs an archetype). Budget [55,68]; used to isolate
## the single-stat cap (>55) from the total-budget check.
func _boss_chassis(id: StringName) -> PartDef:
	var p := _common_head(id)
	p.slot_type = PartDef.SlotType.CHASSIS
	p.rarity = PartDef.Rarity.BOSS_GRADE
	p.chassis_archetype = PartDef.ChassisArchetype.BALANCED_FRAME
	p.active_skill_id = &"skill_%s" % id
	p.passive_id = &"passive_%s" % id
	p.damage_type = PartDef.DamageType.ENERGY
	p.stat_bonuses = _sb({&"structure": 50, &"armor": 12})  # sum 62 ∈ [55,68]
	p.drop_conditions = [{"condition": &"break_chassis", "multiplier": 500.0}]
	return p


## A valid WEAPON at the given rarity / damage_type. Primary is physical_power or
## energy_power per damage_type.
func _weapon(id: StringName, rarity: PartDef.Rarity, dmg: PartDef.DamageType,
		primary_value: int, secondary_value: int) -> PartDef:
	var p := _common_head(id)
	p.slot_type = PartDef.SlotType.WEAPON
	p.rarity = rarity
	p.damage_type = dmg
	if rarity != PartDef.Rarity.COMMON:
		p.active_skill_id = &"skill_%s" % id
	if rarity == PartDef.Rarity.BOSS_GRADE or rarity == PartDef.Rarity.PROTOTYPE:
		p.passive_id = &"passive_%s" % id
	var primary: StringName = &"physical_power" if dmg == PartDef.DamageType.PHYSICAL else &"energy_power"
	p.stat_bonuses = _sb({primary: primary_value, &"mobility": secondary_value})
	return p


## Run the validator over the given parts WITH the balance config injected.
func _run(parts: Array[PartDef]) -> Dictionary:
	var catalog := PartCatalog.new()
	catalog.entries = parts
	var catalogs := ContentCatalogs.new()
	catalogs.parts = catalog
	catalogs.balance = _cfg
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


## Run WITHOUT a config — the content families must be skipped (schema-only mode).
func _run_no_cfg(parts: Array[PartDef]) -> Dictionary:
	var catalog := PartCatalog.new()
	catalog.entries = parts
	var catalogs := ContentCatalogs.new()
	catalogs.parts = catalog  # .balance left null
	_spy = SpyLogSink.new()
	return ContentValidator.new().validate(catalogs, _spy)


func _one(part: PartDef) -> Dictionary:
	var parts: Array[PartDef] = [part]
	return _run(parts)


func _logged(code: StringName) -> bool:
	for e in _spy.errors:
		if e["code"] == code:
			return true
	return false


func _warned(code: StringName) -> bool:
	for w in _spy.warns:
		if w["code"] == code:
			return true
	return false


# ---------------------------------------------------------------------------
# Baseline: a valid Common/Rare/Boss/Prototype set passes with zero errors
# ---------------------------------------------------------------------------

func test_valid_catalog_passes_with_no_errors() -> void:
	var parts: Array[PartDef] = [
		_common_head(&"h_c"), _rare_head(&"h_r"), _boss_head(&"h_b"), _proto_head(&"h_p"),
	]
	var r := _run(parts)
	assert_true(r["ok"], "a valid content-composition catalog validates ok==true")
	assert_eq(_spy.errors.size(), 0, "no errors on a valid catalog")
	# HEAD/targeting group has both a Common and a Rare entry → no coverage warning.
	assert_eq(_spy.warns.size(), 0, "no empty-group warnings when Common and Rare both present")


func test_content_families_skipped_without_config() -> void:
	# A part that would fail AC-04 (no synergy tags) but is schema-valid: with no
	# BalanceConfig injected, the content families do not run.
	var p := _common_head(&"bare")
	p.synergy_tags = []
	var parts: Array[PartDef] = [p]
	var r := _run_no_cfg(parts)
	assert_true(r["ok"], "schema-only mode (no config) skips the content-composition families")
	assert_eq(_spy.errors.size(), 0, "no content-family errors surface without a config")


# ---------------------------------------------------------------------------
# AC-04 — synergy tag consistency
# ---------------------------------------------------------------------------

func test_ac_04_missing_element_tag_errors() -> void:
	var p := _common_head(&"no_elem_tag")
	p.synergy_tags = [&"boltwell"]  # missing "volt"
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_synergy_missing_element_tag"), "a part missing its element tag is flagged")


func test_ac_04_nonwild_missing_manufacturer_tag_errors() -> void:
	var p := _common_head(&"no_mfr_tag")
	p.synergy_tags = [&"volt"]  # boltwell part missing "boltwell"
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_synergy_missing_manufacturer_tag"), "a boltwell part missing its mfr tag is flagged")


func test_ac_04_wild_carrying_manufacturer_tag_errors() -> void:
	var p := _common_head(&"wild_with_mfr")
	p.manufacturer = &"wild"
	p.synergy_tags = [&"volt", &"boltwell"]  # wild must carry NO manufacturer tag
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_synergy_wild_has_manufacturer_tag"), "a wild part carrying a mfr tag is flagged")


func test_ac_04_valid_wild_with_only_element_tag_passes() -> void:
	var p := _common_head(&"wild_ok")
	p.manufacturer = &"wild"
	p.synergy_tags = [&"volt"]
	var r := _one(p)
	assert_true(r["ok"], "a wild part with exactly its element tag is valid")


# ---------------------------------------------------------------------------
# AC-10 — Prototype has ≥1 positive AND ≥1 negative stat
# ---------------------------------------------------------------------------

func test_ac_10_prototype_without_negative_errors() -> void:
	var p := _proto_head(&"proto_nopos_neg")
	p.stat_bonuses = _sb({&"targeting": 30, &"cooling": 5})  # no negative drawback
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_prototype_missing_negative"), "a Prototype with no negative stat is flagged")


func test_ac_10_prototype_without_positive_errors_and_guards_ac19() -> void:
	var p := _proto_head(&"proto_noneg_pos")
	p.stat_bonuses = _sb({&"mobility": -8})  # no positive → AC-10 fail; AC-19 must NOT divide by zero
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_prototype_missing_positive"), "a Prototype with no positive stat is flagged")
	assert_false(_logged(&"content_prototype_concentration_low"),
		"AC-19 is guarded: a zero positive_total never reaches the concentration division")


# ---------------------------------------------------------------------------
# AC-19 — Prototype concentration ≥ 0.70
# ---------------------------------------------------------------------------

func test_ac_19_evenly_spread_prototype_errors() -> void:
	# +12/+12/+11 = 35 positive; top_two 24; 24/35 = 0.686 < 0.70.
	var p := _proto_head(&"proto_spread")
	p.stat_bonuses = _sb({&"targeting": 12, &"cooling": 12, &"mobility": 11, &"armor": -5})
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_prototype_concentration_low"), "an evenly-spread Prototype is flagged")


func test_ac_19_single_positive_prototype_passes_trivially() -> void:
	# One positive stat → top_two == positive_total → ratio 1.0.
	var p := _proto_head(&"proto_single")
	p.stat_bonuses = _sb({&"targeting": 35, &"mobility": -8})
	var r := _one(p)
	assert_true(r["ok"], "a single-positive-stat Prototype passes AC-19 trivially (ratio 1.0)")


# ---------------------------------------------------------------------------
# AC-11 — Boss-grade break condition ≥ 500
# ---------------------------------------------------------------------------

func test_ac_11_boss_with_empty_drop_conditions_errors() -> void:
	var p := _boss_head(&"boss_empty")
	p.drop_conditions = []
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_boss_break_condition_missing"), "a Boss-grade with no break condition is flagged")


func test_ac_11_boss_with_multiplier_below_500_errors() -> void:
	var p := _boss_head(&"boss_499")
	p.drop_conditions = [{"condition": &"weak_break", "multiplier": 499.0}]  # boundary: 499 < 500
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_boss_break_condition_missing"), "×499 is below the 500 threshold")


func test_ac_11_boss_with_multiplier_exactly_500_passes() -> void:
	var p := _boss_head(&"boss_500")  # baseline already carries ×500
	var r := _one(p)
	assert_true(r["ok"], "×500 is exactly at the threshold and passes")


# ---------------------------------------------------------------------------
# AC-12 — stat budget bounds + single-stat cap
# ---------------------------------------------------------------------------

func test_ac_12_positive_sum_over_budget_errors() -> void:
	var p := _rare_head(&"over_budget")
	p.stat_bonuses = _sb({&"targeting": 18, &"cooling": 20})  # sum 38 > Rare HEAD ceiling 28
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_stat_budget_out_of_range"), "a positive sum above the slot/rarity ceiling is flagged")


func test_ac_12_at_ceiling_passes() -> void:
	var p := _rare_head(&"at_ceiling")
	p.stat_bonuses = _sb({&"targeting": 18, &"cooling": 10})  # sum 28 == ceiling
	var r := _one(p)
	assert_true(r["ok"], "a part exactly at the budget ceiling passes")


func test_ac_12_single_stat_above_55_errors() -> void:
	# Boss CHASSIS budget [55,68]: 56 + 5 = 61 is IN budget, but 56 > 55 single-cap.
	var p := _boss_chassis(&"single_over")
	p.stat_bonuses = _sb({&"structure": 56, &"armor": 5})
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_stat_exceeds_single_cap"), "a single stat above 55 is flagged even inside the total budget")
	assert_false(_logged(&"content_stat_budget_out_of_range"), "the total (61) is within the Boss Chassis budget [55,68]")


# ---------------------------------------------------------------------------
# AC-23 — Common cap / Rare floor per slot (+ damage_type subgroup)
# ---------------------------------------------------------------------------

func test_ac_23_common_weapon_primary_over_cap_errors() -> void:
	# Common WEAPON cap 14; physical_power 15 exceeds it. Budget [16,20]: 15+3=18 OK.
	var p := _weapon(&"cw_over", PartDef.Rarity.COMMON, PartDef.DamageType.PHYSICAL, 15, 3)
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_common_primary_over_cap"), "a Common Weapon primary above its cap is flagged")


func test_ac_23_rare_weapon_primary_under_floor_errors() -> void:
	# Rare WEAPON floor 22; physical_power 21 is below it. Budget [28,35]: 21+10=31 OK.
	var p := _weapon(&"rw_under", PartDef.Rarity.RARE, PartDef.DamageType.PHYSICAL, 21, 10)
	var r := _one(p)
	assert_false(r["ok"])
	assert_true(_logged(&"content_rare_primary_under_floor"), "a Rare Weapon primary below its floor is flagged")


func test_ac_23_common_weapon_at_cap_passes() -> void:
	var p := _weapon(&"cw_at", PartDef.Rarity.COMMON, PartDef.DamageType.PHYSICAL, 14, 4)  # 14 == cap
	var r := _one(p)
	assert_true(r["ok"], "a Common Weapon primary exactly at the cap passes")


func test_ac_23_energy_subgroup_not_compared_as_physical() -> void:
	# A Rare ENERGY arm's primary is energy_power (19 ≥ floor 19). Its physical_power
	# is 0 — a wrong implementation comparing physical_power would flag under-floor.
	var p := _common_head(&"energy_arm")
	p.slot_type = PartDef.SlotType.ARMS
	p.rarity = PartDef.Rarity.RARE
	p.active_skill_id = &"skill_ea"
	p.damage_type = PartDef.DamageType.ENERGY
	p.stat_bonuses = _sb({&"energy_power": 19, &"mobility": 7})  # sum 26 ∈ Rare Arms [26,32]
	var r := _one(p)
	assert_true(r["ok"], "an ENERGY arm is judged on energy_power, not physical_power")
	assert_false(_logged(&"content_rare_primary_under_floor"), "the energy subgroup is not compared as physical")


func test_ac_23_empty_common_subgroup_warns_but_passes() -> void:
	# A lone Rare ENERGY weapon: the WEAPON/energy_power group has no Common entry →
	# a vacuous PASS plus an authoring WARNING (not an error).
	var p := _weapon(&"lone_rare", PartDef.Rarity.RARE, PartDef.DamageType.ENERGY, 24, 8)
	var r := _one(p)
	assert_true(r["ok"], "an empty comparison subgroup passes vacuously")
	assert_true(_warned(&"content_primary_group_no_common"), "the empty Common subgroup emits an authoring warning")


# ---------------------------------------------------------------------------
# Lock-step contract — warnings and errors route through the LogSink
# ---------------------------------------------------------------------------

func test_warnings_route_through_log_sink() -> void:
	var p := _weapon(&"warn_route", PartDef.Rarity.RARE, PartDef.DamageType.PHYSICAL, 24, 8)
	var r := _run([p] as Array[PartDef])
	assert_true(r["ok"], "the lone Rare weapon is valid")
	assert_eq((r["warnings"] as Array).size(), _spy.warns.size(),
		"every returned warning is mirrored through the injected LogSink")
	assert_gt(_spy.warns.size(), 0, "the empty Common subgroup produced at least one warning")
