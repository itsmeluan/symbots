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
## [28,38] concentrated ≥70% in 1–2 stats; primary (targeting=30) > Rare HEAD
## floor (17); 3 drop conditions with product 3.375 ≥ 3.0 (AC-26).
func _proto_head(id: StringName) -> PartDef:
	var p := _rare_head(id)
	p.rarity = PartDef.Rarity.PROTOTYPE
	p.passive_id = &"passive_%s" % id
	p.stat_bonuses = _sb({&"targeting": 30, &"cooling": 5, &"mobility": -8})  # +35, ratio 1.0
	p.drop_conditions = [
		{"condition": &"break_head", "multiplier": 1.5},
		{"condition": &"perfect_win", "multiplier": 1.5},
		{"condition": &"low_hp_victory", "multiplier": 1.5},
	]
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


# ---------------------------------------------------------------------------
# Helpers for Story-011 fixtures
# ---------------------------------------------------------------------------

## A valid Prototype CHASSIS: skill + passive; structure is focus (highest positive);
## structure > 29 (Rare CHASSIS floor); positive budget in [40,55]; ≥1 negative.
## Three ×1.5 drop conditions → product 3.375 ≥ 3.0 ✓.
func _proto_chassis(id: StringName, structure: int, armor: int, drawback: int) -> PartDef:
	var p := PartDef.new()
	p.id = id
	p.display_name = "Test %s" % id
	p.slot_type = PartDef.SlotType.CHASSIS
	p.rarity = PartDef.Rarity.PROTOTYPE
	p.chassis_archetype = PartDef.ChassisArchetype.BALANCED_FRAME
	p.manufacturer = &"boltwell"
	p.element = PartDef.Element.VOLT
	p.damage_type = PartDef.DamageType.ENERGY  # required when active_skill_id is set
	p.sprite_id = &"spr_%s" % id
	p.synergy_tags = [&"volt", &"boltwell"]
	p.active_skill_id = &"skill_%s" % id
	p.passive_id = &"passive_%s" % id
	p.stat_bonuses = _sb({&"structure": structure, &"armor": armor, &"mobility": drawback})
	p.drop_conditions = [
		{"condition": &"break_chassis", "multiplier": 1.5},
		{"condition": &"perfect_win", "multiplier": 1.5},
		{"condition": &"low_hp_victory", "multiplier": 1.5},
	]
	p.max_upgrade_tier = 5
	p.level_requirement = 8
	return p


# ---------------------------------------------------------------------------
# AC-25 — Prototype focus = slot primary (Story 011)
# ---------------------------------------------------------------------------

func test_ac_25_proto_chassis_focus_not_primary_errors() -> void:
	# GDD discriminating fixture (i): structure=10, armor=30 — armor strictly exceeds
	# structure (the CHASSIS primary), so (a) fails.
	# Positive sum = 40 ∈ [40,55]; concentration top_two=40/40=1.0 ✓ — isolated to AC-25.
	var p := _proto_chassis(&"ac25_fail_a", 10, 30, -8)
	var r := _one(p)
	assert_false(r["ok"], "Prototype with off-primary focus fails AC-25(a)")
	assert_true(_logged(&"content_prototype_focus_not_primary"),
		"content_prototype_focus_not_primary fires when armor > structure on CHASSIS Prototype")
	assert_false(_logged(&"content_prototype_focus_below_rare_floor"),
		"focus-floor sub-check is not reached when focus-not-primary already fires")


func test_ac_25_proto_chassis_focus_at_rare_floor_errors() -> void:
	# GDD discriminating fixture (ii): structure=29, armor=11. structure is highest
	# positive (29 > 11), so (a) passes. But 29 == Rare CHASSIS floor (29) — not strictly
	# greater — so (b) fails. A >= implementation would wrongly pass this case.
	var p := _proto_chassis(&"ac25_fail_b", 29, 11, -8)
	var r := _one(p)
	assert_false(r["ok"], "Prototype with structure=29 fails AC-25(b) — 29 is not > floor 29")
	assert_false(_logged(&"content_prototype_focus_not_primary"),
		"AC-25(a) does not fire — structure is the highest positive stat")
	assert_true(_logged(&"content_prototype_focus_below_rare_floor"),
		"content_prototype_focus_below_rare_floor fires when structure == rare floor")


func test_ac_25_proto_chassis_focus_above_floor_passes() -> void:
	# GDD passing fixture: structure=30 > floor 29 and structure > armor. Both sub-checks pass.
	var p := _proto_chassis(&"ac25_pass", 30, 10, -8)
	var r := _one(p)
	assert_true(r["ok"], "Prototype with structure=30 > floor 29 passes AC-25")
	assert_false(_logged(&"content_prototype_focus_not_primary"), "no focus-not-primary error")
	assert_false(_logged(&"content_prototype_focus_below_rare_floor"), "no focus-floor error")


func test_ac_25_proto_focus_tie_with_secondary_passes() -> void:
	# Tie is permitted: AC-25(a) says no other stat STRICTLY exceeds primary.
	# structure=30 == armor=30; primary=structure=30 ≥ armor=30 → no strict exceeder.
	# Positive sum = 60 > 55 (over budget) — use HEAD Prototype to avoid that clash.
	var p := _proto_head(&"ac25_tie")
	# HEAD primary = targeting. Set targeting = cooling = 30 (tie). Both pass (a).
	# Positive sum = 60 → over HEAD Prototype budget [28,38]; adjust to keep budget clean.
	p.stat_bonuses = _sb({&"targeting": 20, &"cooling": 20, &"mobility": -8})
	# positive=40 > HEAD Prototype max 38; adjust: targeting=18, cooling=18.
	p.stat_bonuses = _sb({&"targeting": 18, &"cooling": 18, &"mobility": -8})
	# Positive=36 ∈ [28,38] ✓. Concentration: top_two=36/36=1.0 ✓. Rare HEAD floor=17.
	# targeting=18 > 17 ✓. cooling=18 ties targeting — neither strictly exceeds.
	var r := _one(p)
	assert_true(r["ok"], "a tie between primary and secondary passes AC-25(a)")
	assert_false(_logged(&"content_prototype_focus_not_primary"), "tie is not treated as a strict exceedance")


func test_ac_25_non_prototype_skipped() -> void:
	# AC-25 runs only on PROTOTYPE; a Rare part must not trigger either code.
	var p := _rare_head(&"ac25_rare")
	var r := _one(p)
	assert_false(_logged(&"content_prototype_focus_not_primary"), "AC-25 skipped for Rare")
	assert_false(_logged(&"content_prototype_focus_below_rare_floor"), "AC-25 skipped for Rare")


# ---------------------------------------------------------------------------
# AC-26 — Prototype drop conditions ≥3 entries + product ≥3.0 (Story 011)
# ---------------------------------------------------------------------------

func test_ac_26_proto_too_few_drop_conditions_errors() -> void:
	# GDD boundary: 2 × ×2.0 → product=4.0 ≥ 3.0 (b passes), but size=2 < 3 → (a) fails.
	var p := _proto_chassis(&"ac26_few", 30, 10, -8)
	p.drop_conditions = [
		{"condition": &"break_chassis", "multiplier": 2.0},
		{"condition": &"perfect_win", "multiplier": 2.0},
	]
	var r := _one(p)
	assert_false(r["ok"], "2 drop conditions fails AC-26(a)")
	assert_true(_logged(&"content_prototype_too_few_drop_conditions"),
		"content_prototype_too_few_drop_conditions fires when size < 3")
	# (b) product=4.0 ≥ 3.0 → should NOT fire.
	assert_false(_logged(&"content_prototype_drop_product_low"),
		"product sub-check (b) does not fire when product >= 3.0")


func test_ac_26_proto_product_low_errors() -> void:
	# GDD boundary: ×1.4 × ×1.4 × ×1.5 = 2.94 < 3.0 → (b) fails; size=3 ✓ → (a) passes.
	var p := _proto_chassis(&"ac26_low_prod", 30, 10, -8)
	p.drop_conditions = [
		{"condition": &"break_chassis", "multiplier": 1.4},
		{"condition": &"perfect_win", "multiplier": 1.4},
		{"condition": &"low_hp_victory", "multiplier": 1.5},
	]
	var r := _one(p)
	assert_false(r["ok"], "product 2.94 fails AC-26(b)")
	assert_false(_logged(&"content_prototype_too_few_drop_conditions"),
		"size sub-check (a) does not fire when size >= 3")
	assert_true(_logged(&"content_prototype_drop_product_low"),
		"content_prototype_drop_product_low fires when product < 3.0")


func test_ac_26_proto_both_sub_checks_fail_independently() -> void:
	# 2 conditions (fails a) with product 1.5×1.5=2.25 < 3.0 (fails b).
	# Both errors must fire — the checks are independent.
	var p := _proto_chassis(&"ac26_both_fail", 30, 10, -8)
	p.drop_conditions = [
		{"condition": &"break_chassis", "multiplier": 1.5},
		{"condition": &"perfect_win", "multiplier": 1.5},
	]
	var r := _one(p)
	assert_false(r["ok"], "2 conditions with product < 3.0 fails both (a) and (b)")
	assert_true(_logged(&"content_prototype_too_few_drop_conditions"),
		"(a) fires independently")
	assert_true(_logged(&"content_prototype_drop_product_low"),
		"(b) fires independently even when (a) already fires")


func test_ac_26_proto_three_at_1_5_passes() -> void:
	# GDD boundary: 3 × ×1.5 = 3.375 ≥ 3.0. _proto_chassis already has this fixture.
	var p := _proto_chassis(&"ac26_pass", 30, 10, -8)
	var r := _one(p)
	assert_true(r["ok"], "3 × ×1.5 (product 3.375) passes AC-26")
	assert_false(_logged(&"content_prototype_too_few_drop_conditions"), "no size error")
	assert_false(_logged(&"content_prototype_drop_product_low"), "no product error")


func test_ac_26_non_prototype_skipped() -> void:
	# AC-26 runs only on PROTOTYPE; a Boss-grade with 1 condition must not trigger it.
	var p := _boss_head(&"ac26_boss")  # 1 drop condition, size=1
	var r := _one(p)
	assert_false(_logged(&"content_prototype_too_few_drop_conditions"), "AC-26 skipped for Boss-grade")
	assert_false(_logged(&"content_prototype_drop_product_low"), "AC-26 skipped for Boss-grade")


# ---------------------------------------------------------------------------
# AC-27 — symmetric negative stat floor −55 (Story 011)
# ---------------------------------------------------------------------------

func test_ac_27_negative_stat_below_minus_55_errors() -> void:
	# Discriminating fixture from GDD: structure=40, armor=-60. Total positive = 40;
	# Boss CHASSIS budget [55,68]: 40 < 55, so this would fail the budget check too.
	# Use a PROTOTYPE CHASSIS with structure=40, armor=-60 to isolate AC-27:
	# positive=40 ∈ [40,55] ✓; armor=-60 < -55 → AC-27 fires.
	var p := _proto_chassis(&"ac27_neg_fail", 40, 0, -60)
	# _proto_chassis sets structure=40, armor=0, mobility=-60. armor=0 is fine (not negative).
	# mobility=-60 < -55 → AC-27 must fire.
	var r := _one(p)
	assert_false(r["ok"], "a stat of -60 violates the -55 floor")
	assert_true(_logged(&"content_stat_exceeds_single_cap"),
		"content_stat_exceeds_single_cap fires for a stat below -55")


func test_ac_27_positive_sum_within_budget_does_not_mask_negative_floor() -> void:
	# The positive sum (structure=40) passes the total-budget check for Prototype CHASSIS
	# [40,55]; the -60 drawback is NOT counted in the positive budget. AC-27 must still
	# fire on the negative value, separately from the budget check.
	var p := _proto_chassis(&"ac27_budget_ok_neg_fail", 40, 0, -60)
	var r := _one(p)
	assert_true(_logged(&"content_stat_exceeds_single_cap"), "AC-27 fires independently of budget check")
	assert_false(_logged(&"content_stat_budget_out_of_range"),
		"positive budget (40) is within [40,55] — budget error does not fire")


func test_ac_27_exactly_minus_55_passes() -> void:
	# The floor is symmetric: -55 is exactly at the boundary and must pass (< -55 fails, = -55 is fine).
	var p := _proto_chassis(&"ac27_at_floor", 40, 0, -55)
	var r := _one(p)
	assert_false(_logged(&"content_stat_exceeds_single_cap"),
		"-55 is exactly at the floor (not below it) — no single-cap error fires")


func test_ac_27_positive_single_cap_still_enforced() -> void:
	# AC-27 does not break the existing positive cap — a single stat of +56 still errors.
	var p := _boss_chassis(&"ac27_pos_cap")
	p.stat_bonuses = _sb({&"structure": 56, &"armor": 5})  # 56 > 55 positive cap
	var r := _one(p)
	assert_true(_logged(&"content_stat_exceeds_single_cap"),
		"existing positive cap (>55) is still enforced after AC-27 addition")


# ---------------------------------------------------------------------------
# Entry-shape validation — upgrade_effects (Story 011)
# ---------------------------------------------------------------------------

func test_entry_shape_upgrade_effects_missing_tier_errors() -> void:
	# An entry with no "tier" key at all should fire content_upgrade_entry_malformed.
	var p := _rare_head(&"ue_no_tier")
	p.upgrade_effects = [{"effect_type": &"SKILL_ENHANCE"}]  # tier missing
	var r := _one(p)
	assert_false(r["ok"], "a upgrade_effects entry without tier is malformed")
	assert_true(_logged(&"content_upgrade_entry_malformed"),
		"content_upgrade_entry_malformed fires for missing tier")


func test_entry_shape_upgrade_effects_tier_out_of_range_errors() -> void:
	# tier=0 is below the [1,5] range.
	var p := _rare_head(&"ue_tier_zero")
	p.upgrade_effects = [{"tier": 0, "effect_type": &"SKILL_ENHANCE"}]
	var r := _one(p)
	assert_false(r["ok"], "tier=0 is outside [1,5] — malformed")
	assert_true(_logged(&"content_upgrade_entry_malformed"),
		"content_upgrade_entry_malformed fires for tier=0")


func test_entry_shape_upgrade_effects_missing_effect_type_errors() -> void:
	# An entry with no "effect_type" key.
	var p := _rare_head(&"ue_no_type")
	p.upgrade_effects = [{"tier": 2}]  # effect_type missing
	var r := _one(p)
	assert_false(r["ok"], "a upgrade_effects entry without effect_type is malformed")
	assert_true(_logged(&"content_upgrade_entry_malformed"),
		"content_upgrade_entry_malformed fires for missing effect_type")


func test_entry_shape_upgrade_effects_valid_entry_passes() -> void:
	# A well-formed entry on a skill-capable slot must not trigger any malformed error.
	var p := _rare_head(&"ue_valid")
	p.upgrade_effects = [{"tier": 3, "effect_type": &"SKILL_ENHANCE"}]
	var r := _one(p)
	assert_false(_logged(&"content_upgrade_entry_malformed"),
		"a valid upgrade_effects entry does not trigger malformed error")


# ---------------------------------------------------------------------------
# Entry-shape validation — drop_conditions (Story 011)
# ---------------------------------------------------------------------------

func test_entry_shape_drop_conditions_missing_condition_errors() -> void:
	# An entry with no "condition" key (or empty StringName).
	var p := _boss_head(&"dc_no_cond")
	p.drop_conditions = [{"multiplier": 500.0}]  # condition key missing
	var r := _one(p)
	assert_false(r["ok"], "a drop_conditions entry without condition is malformed")
	assert_true(_logged(&"content_drop_condition_entry_malformed"),
		"content_drop_condition_entry_malformed fires for missing condition")


func test_entry_shape_drop_conditions_multiplier_at_one_errors() -> void:
	# multiplier = 1.0 violates Rule 9 / Drop Rule 5a (must be > 1.0).
	var p := _boss_head(&"dc_mult_one")
	p.drop_conditions = [{"condition": &"break_head", "multiplier": 1.0}]
	var r := _one(p)
	assert_false(r["ok"], "multiplier=1.0 violates the >1.0 invariant")
	assert_true(_logged(&"content_drop_condition_entry_malformed"),
		"content_drop_condition_entry_malformed fires for multiplier not above 1.0")


func test_entry_shape_drop_conditions_missing_multiplier_errors() -> void:
	# An entry with no "multiplier" key.
	var p := _boss_head(&"dc_no_mult")
	p.drop_conditions = [{"condition": &"break_head"}]  # multiplier missing
	var r := _one(p)
	assert_false(r["ok"], "a drop_conditions entry without multiplier is malformed")
	assert_true(_logged(&"content_drop_condition_entry_malformed"),
		"content_drop_condition_entry_malformed fires for missing multiplier")


func test_entry_shape_drop_conditions_valid_entry_passes_shape_check() -> void:
	# A well-formed Boss-grade entry with condition+multiplier > 1.0 and >= 500 passes all checks.
	var p := _boss_head(&"dc_valid")  # already has {"condition": &"break_head", "multiplier": 500.0}
	var r := _one(p)
	assert_false(_logged(&"content_drop_condition_entry_malformed"),
		"a valid drop_conditions entry does not trigger malformed error")
