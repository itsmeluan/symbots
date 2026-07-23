## BattleScreen — the view contract (ADR-0008, Core Design §3.1).
##
## A UI test that runs headless, because the things worth pinning here are not pixels:
## that the screen never offers an action the engine would refuse, that the taunt rule is
## VISIBLE before the tap rather than a rejection after it, and that a battle driven purely
## through the screen still reaches an outcome.
extends GutTest

const BattleScreenScript := preload("res://src/ui/battle/battle_screen.gd")
const BattleEngineScript := preload("res://src/core/battle_v1/battle_engine.gd")
const SkillDefScript := preload("res://src/core/battle_v1/skill_def.gd")
const SpeciesDefScript := preload("res://src/core/species/species_def.gd")
const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

var _screen: BattleScreen
var _cfg: BalanceConfig
var _rng: RandomNumberGenerator
var _ctx: ServiceContext


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 4242
	_ctx = ServiceContext.new()
	_ctx.log = SpyLogSink.new()
	_ctx.balance = _cfg

	_screen = BattleScreenScript.new()
	add_child_autofree(_screen)
	_screen.setup(_ctx)


func after_each() -> void:
	_screen = null


func _unit(id: String, side: int, hp := 200, role := SpeciesDefScript.Role.DPS,
		mobility := 10, slot := 0) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_id = StringName(id)
	u.display_name = id
	u.side = side
	u.slot = slot
	u.role = role
	u.max_structure = hp
	u.current_structure = hp
	u.base_stats = {&"mobility": mobility, &"physical_power": 40, &"armor": 20,
		&"resistance": 20, &"targeting": 0, &"processing": 30}
	u.skills = [&"strike"]
	return u


func _strike() -> SkillDef:
	var s := SkillDef.new()
	s.id = &"strike"
	s.display_name = "Strike"
	s.target_mode = SkillDefScript.TargetMode.SINGLE_ENEMY
	s.power_percent = 100
	s.scaling_stat = &"physical_power"
	s.effects = [{"kind": SkillDefScript.EffectKind.DAMAGE}]
	return s


func _sweep() -> SkillDef:
	var s := _strike()
	s.id = &"sweep"
	s.display_name = "Sweep"
	s.target_mode = SkillDefScript.TargetMode.ALL_ENEMIES
	return s


func _table() -> Dictionary:
	return {&"strike": _strike(), &"sweep": _sweep()}


func _start(players: Array, enemies: Array) -> BattleEngine:
	var e := BattleEngineScript.new(players, enemies, _table(), _cfg, _rng, _ctx.log)
	_screen.begin_battle(e, _table())
	return e


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func test_the_screen_lays_out_four_rows_a_side() -> void:
	_start([_unit("p", BattleUnit.Side.PLAYER)], [_unit("x", BattleUnit.Side.ENEMY)])
	assert_eq(_screen._player_panels.size(), BattleScreenScript.SQUAD_SIZE)
	assert_eq(_screen._enemy_panels.size(), BattleScreenScript.SQUAD_SIZE)


func test_unused_rows_are_hidden_rather_than_drawn_empty() -> void:
	# Enemies number 1-4 (§3.1), so empty rows are the normal case, not an error.
	_start([_unit("p", BattleUnit.Side.PLAYER)], [_unit("x", BattleUnit.Side.ENEMY)])
	assert_true(_screen._enemy_panels[0].visible)
	assert_false(_screen._enemy_panels[1].visible)


func test_every_tap_target_meets_the_touch_minimum() -> void:
	_start([_unit("p", BattleUnit.Side.PLAYER)], [_unit("x", BattleUnit.Side.ENEMY)])
	for panel in _screen._player_panels:
		assert_gte(panel.custom_minimum_size.y, float(UnitPanel.MIN_TAP_HEIGHT),
			"a card below the touch minimum is unusable on the target platform")


# ---------------------------------------------------------------------------
# The screen never offers what the engine would refuse
# ---------------------------------------------------------------------------

func test_the_taunt_rule_is_visible_before_the_tap() -> void:
	# The whole point: highlighting comes from the engine's legal set, so the player is
	# never shown a target they are then not allowed to hit.
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var tank := _unit("tank", BattleUnit.Side.ENEMY, 400, SpeciesDefScript.Role.TANK, 5)
	var squishy := _unit("squishy", BattleUnit.Side.ENEMY, 100,
		SpeciesDefScript.Role.DPS, 5, 1)
	_start([p], [tank, squishy])

	_screen._on_skill_pressed(&"strike")

	assert_true(_screen._enemy_panels[0].is_targetable, "the tank is highlighted")
	assert_false(_screen._enemy_panels[1].is_targetable,
		"the protected unit is NOT — the rule is shown, not enforced by rejection")


func test_tapping_a_protected_unit_changes_nothing() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var tank := _unit("tank", BattleUnit.Side.ENEMY, 400, SpeciesDefScript.Role.TANK, 5)
	var squishy := _unit("squishy", BattleUnit.Side.ENEMY, 100,
		SpeciesDefScript.Role.DPS, 5, 1)
	_start([p], [tank, squishy])

	_screen._on_skill_pressed(&"strike")
	_screen._on_unit_tapped(squishy)

	assert_eq(squishy.current_structure, 100, "the protected unit took nothing")
	assert_eq(tank.current_structure, 400, "and the turn was not spent elsewhere either")


func test_the_skill_bar_only_offers_usable_skills() -> void:
	var heavy := _strike()
	heavy.id = &"heavy"
	heavy.display_name = "Heavy"
	heavy.cooldown = 3

	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	p.skills = [&"strike", &"heavy"]
	var x := _unit("x", BattleUnit.Side.ENEMY, 9999, SpeciesDefScript.Role.DPS, 5)
	var table := _table()
	table[&"heavy"] = heavy
	var e := BattleEngineScript.new([p], [x], table, _cfg, _rng, _ctx.log)
	_screen.begin_battle(e, table)

	_screen._on_skill_pressed(&"heavy")
	_screen._on_unit_tapped(x)

	# p acts again next round; Heavy is still cooling down, so its button must be disabled.
	var disabled := 0
	for child in _screen._skill_bar.get_children():
		if child is Button and child.disabled:
			disabled += 1
	assert_gt(disabled, 0, "a button that lies about being usable is worse than no button")


func test_a_multi_target_skill_fires_on_a_confirming_second_tap() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	p.skills = [&"sweep"]
	var a := _unit("a", BattleUnit.Side.ENEMY, 300, SpeciesDefScript.Role.DPS, 5)
	var b := _unit("b", BattleUnit.Side.ENEMY, 300, SpeciesDefScript.Role.DPS, 5, 1)
	_start([p], [a, b])

	_screen._on_skill_pressed(&"sweep")
	assert_eq(a.current_structure, 300,
		"the first tap only selects — the info box is open for reading")
	assert_true(_screen._info_box.visible)

	_screen._on_skill_pressed(&"sweep")
	assert_lt(a.current_structure, 300, "the confirming tap fires the AoE")
	assert_lt(b.current_structure, 300)
	assert_false(_screen._info_box.visible, "firing closes the info box")
	assert_null(_screen._pending_skill, "and leaves no armed skill behind")


# ---------------------------------------------------------------------------
# Flow
# ---------------------------------------------------------------------------

func test_enemy_turns_resolve_without_player_input() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 5)
	var fast := _unit("fast", BattleUnit.Side.ENEMY, 400, SpeciesDefScript.Role.DPS, 40)
	_start([p], [fast])
	# The fast enemy acted during begin_battle, so control is already back with the player.
	assert_eq(_screen.engine.current_actor(), p)
	assert_lt(p.current_structure, 400, "the enemy took its turn on its own")


func test_auto_battle_runs_the_fight_to_an_outcome() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 20)
	var x := _unit("x", BattleUnit.Side.ENEMY, 60, SpeciesDefScript.Role.DPS, 5)
	_start([p], [x])

	_screen._on_auto_toggled(true)

	assert_true(_screen.engine.is_over(), "auto plays both sides through to the end")
	assert_eq(_screen.engine.outcome, BattleEngineScript.Outcome.PLAYER_WON)


func test_the_screen_reports_the_outcome_once_the_battle_ends() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 20)
	var x := _unit("x", BattleUnit.Side.ENEMY, 60, SpeciesDefScript.Role.DPS, 5)
	_start([p], [x])
	watch_signals(_screen)

	_screen._on_auto_toggled(true)

	assert_signal_emitted(_screen, "battle_finished")
	assert_eq(_screen._banner.text, "VICTORY")


func test_the_log_renders_only_new_events() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY, 9999, SpeciesDefScript.Role.DPS, 5)
	_start([p], [x])
	var drawn_after_start := _screen._events_drawn

	_screen._on_skill_pressed(&"strike")
	_screen._on_unit_tapped(x)

	assert_gt(_screen._events_drawn, drawn_after_start,
		"the drain advances so a battle is never replayed from the top")
	assert_eq(_screen._events_drawn, _screen.engine.events.size(),
		"and consumes everything the engine has emitted")


# ---------------------------------------------------------------------------
# Panels
# ---------------------------------------------------------------------------

func test_a_panel_shows_the_charge_meter_only_for_a_unit_with_an_ult() -> void:
	var ult := _strike()
	ult.id = &"ult"
	ult.is_ultimate = true
	ult.charge_cost = 50

	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	p.ultimate_skill = &"ult"
	var x := _unit("x", BattleUnit.Side.ENEMY, 200, SpeciesDefScript.Role.DPS, 5)
	var table := _table()
	table[&"ult"] = ult
	var e := BattleEngineScript.new([p], [x], table, _cfg, _rng, _ctx.log)
	_screen.begin_battle(e, table)

	assert_true(_screen._player_panels[0]._charge_bar.visible)
	assert_false(_screen._enemy_panels[0]._charge_bar.visible,
		"a unit with no ult must not show an empty meter that never fills")


func test_a_destroyed_unit_is_dimmed_rather_than_removed() -> void:
	# Removing it would reflow the column mid-fight and move every other tap target.
	var p := _unit("p", BattleUnit.Side.PLAYER, 400, SpeciesDefScript.Role.DPS, 30)
	var a := _unit("a", BattleUnit.Side.ENEMY, 1, SpeciesDefScript.Role.DPS, 5)
	var b := _unit("b", BattleUnit.Side.ENEMY, 400, SpeciesDefScript.Role.DPS, 5, 1)
	_start([p], [a, b])

	_screen._on_skill_pressed(&"strike")
	_screen._on_unit_tapped(a)

	assert_true(_screen._enemy_panels[0].visible, "still on screen")
	assert_lt(_screen._enemy_panels[0].modulate.r, 1.0, "but visibly out of the fight")


# ---------------------------------------------------------------------------
# Which battlefield gets drawn
# ---------------------------------------------------------------------------

func _screen_for(stage: StageDef) -> BattleScreen:
	var s: BattleScreen = autofree(BattleScreenScript.new())
	s.stage = stage
	return s


func test_a_stage_without_its_own_art_uses_the_shared_battlefield() -> void:
	# Most stages ship no background of their own, so the fallback is the normal path, not
	# an error path.
	var stage := StageDef.new()
	stage.id = &"stage_test"
	assert_eq(_screen_for(stage)._background_path(),
		BattleScreenScript.DEFAULT_BACKGROUND)


func test_a_stage_with_its_own_art_uses_it() -> void:
	var stage := StageDef.new()
	stage.id = &"stage_test"
	stage.background_path = BattleScreenScript.DEFAULT_BACKGROUND
	assert_eq(_screen_for(stage)._background_path(),
		BattleScreenScript.DEFAULT_BACKGROUND)


func test_a_stage_naming_missing_art_still_gets_a_battlefield() -> void:
	# There is no stage validator, so a typo'd path reaches the player. Falling back beats
	# fighting on a black screen.
	var stage := StageDef.new()
	stage.id = &"stage_test"
	stage.background_path = "res://assets/art/battle/does_not_exist.png"
	assert_eq(_screen_for(stage)._background_path(),
		BattleScreenScript.DEFAULT_BACKGROUND)


func test_every_shipped_stage_names_art_that_exists() -> void:
	# There is no stage validator, so a mistyped or renamed background would only surface as
	# the default battlefield appearing on a stage that has its own art — a silent downgrade
	# nobody notices.
	var catalog: StageCatalog = load("res://assets/data/catalogs/stage_catalog.tres")
	assert_not_null(catalog)
	var with_art := 0
	for stage in catalog.entries:
		if stage == null or stage.background_path.is_empty():
			continue
		with_art += 1
		assert_true(ResourceLoader.exists(stage.background_path),
			"'%s' names a missing background: %s" % [stage.display_name, stage.background_path])
	assert_eq(with_art, catalog.entries.size(), "every stage should have its own battlefield")


func test_no_two_stages_share_a_battlefield() -> void:
	# Two stages pointing at one image means a third image is orphaned — the symptom of the
	# art being bound by file number instead of by place.
	var catalog: StageCatalog = load("res://assets/data/catalogs/stage_catalog.tres")
	var seen: Dictionary = {}
	for stage in catalog.entries:
		if stage == null or stage.background_path.is_empty():
			continue
		assert_false(seen.has(stage.background_path),
			"'%s' reuses %s" % [stage.display_name, stage.background_path])
		seen[stage.background_path] = true


# ---------------------------------------------------------------------------
# Top strip
# ---------------------------------------------------------------------------

func test_the_wave_chip_appears_only_on_multi_fight_stages() -> void:
	assert_false(_screen._wave_label.visible,
		"a single-fight stage has no journey to count")
	_screen.set_wave(2, 3)
	assert_true(_screen._wave_label.visible)
	assert_eq(_screen._wave_label.text, "WAVE 2/3")
	_screen.set_wave(1, 1)
	assert_false(_screen._wave_label.visible,
		"returning to a single fight hides the chip again")


func test_an_uncharged_ultimate_card_reports_its_charge() -> void:
	var ult := SkillDefScript.new()
	ult.id = &"nova"
	ult.display_name = "Nova"
	ult.target_mode = SkillDefScript.TargetMode.ALL_ENEMIES
	ult.is_ultimate = true
	ult.charge_cost = 100

	var p := _unit("p", BattleUnit.Side.PLAYER)
	p.ultimate_skill = &"nova"
	p.ultimate_charge = 40
	assert_eq(_screen._skill_state_text(ult, p, true), "CHARGE 40%")
	p.ultimate_charge = 100
	assert_eq(_screen._skill_state_text(ult, p, true), "READY")


# ---------------------------------------------------------------------------
# Skill info & selection
# ---------------------------------------------------------------------------

func test_selecting_a_skill_opens_its_info_box_and_arms_it() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	_start([p], [_unit("x", BattleUnit.Side.ENEMY)])

	_screen._on_skill_pressed(&"strike")
	assert_eq(_screen._selected_skill_id, &"strike")
	assert_not_null(_screen._pending_skill, "a usable single-target skill arms on select")
	assert_true(_screen._info_box.visible)
	assert_eq(_screen._info_title.text, "Strike")

	_screen._on_skill_pressed(&"strike")
	assert_eq(_screen._selected_skill_id, &"", "tapping the selection again deselects")
	assert_null(_screen._pending_skill)
	assert_false(_screen._info_box.visible)


func test_an_uncharged_ult_is_readable_but_never_armed() -> void:
	var nova := SkillDefScript.new()
	nova.id = &"nova"
	nova.display_name = "Nova"
	nova.target_mode = SkillDefScript.TargetMode.ALL_ENEMIES
	nova.scaling_stat = &"physical_power"
	nova.power_percent = 200
	nova.effects = [{"kind": SkillDefScript.EffectKind.DAMAGE}]
	nova.is_ultimate = true
	nova.charge_cost = 100

	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	p.ultimate_skill = &"nova"
	p.ultimate_charge = 0
	var x := _unit("x", BattleUnit.Side.ENEMY, 300)
	var table := _table()
	table[&"nova"] = nova
	var e := BattleEngineScript.new([p], [x], table, _cfg, _rng, _ctx.log)
	_screen.begin_battle(e, table)

	# The ult card is tappable even at 0 charge — the widget must not be disabled.
	var ult_button: Button = _screen._skill_bar.get_children().back()
	assert_false(ult_button.disabled, "an uncharged ult still opens its info")

	_screen._on_skill_pressed(&"nova")
	assert_true(_screen._info_box.visible)
	assert_null(_screen._pending_skill, "reading about an ult never arms it")

	_screen._on_skill_pressed(&"nova")
	assert_eq(x.current_structure, 300, "a confirm tap on an UNUSABLE ult must not fire")
	assert_false(_screen._info_box.visible, "it just closes the info box")


# ---------------------------------------------------------------------------
# Unit info modal
# ---------------------------------------------------------------------------

func test_tapping_a_unit_with_nothing_armed_opens_its_info_modal() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY)
	_start([p], [x])

	_screen._on_unit_tapped(x)
	assert_not_null(_screen._unit_modal, "an idle tap inspects the unit")
	assert_eq(_screen._unit_modal.unit, x)

	_screen._unit_modal._dismiss()
	assert_null(_screen._unit_modal, "dismissing frees the slot for the next tap")


func test_a_legal_target_tap_still_attacks_rather_than_inspecting() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY, 300)
	_start([p], [x])

	_screen._on_skill_pressed(&"strike")
	_screen._on_unit_tapped(x)
	assert_lt(x.current_structure, 300, "targeting keeps priority over inspection")
	assert_null(_screen._unit_modal)


func _modal_texture_rects(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is TextureRect:
			out.append(child)
		_modal_texture_rects(child, out)


func test_the_evolution_strip_silhouettes_undiscovered_marks() -> void:
	_ctx.codex = DiscoveryCodex.new()
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	p.species_id = &"gravelock"
	p.art_mark = 1
	_start([p], [_unit("x", BattleUnit.Side.ENEMY)])

	# begin_battle marked (gravelock, mk1) as seen; mk2 and mk3 remain unknown.
	_screen._on_unit_tapped(p)
	var sprites: Array = []
	_modal_texture_rects(_screen._unit_modal, sprites)
	var silhouettes := 0
	for sprite in sprites:
		if sprite.modulate == Color.BLACK:
			silhouettes += 1
	assert_eq(silhouettes, 2, "mk2 and mk3 are unmet, so both render as silhouettes")
	_screen._unit_modal._dismiss()

	_ctx.codex.mark_seen(&"gravelock", 2)
	_screen._on_unit_tapped(p)
	sprites.clear()
	_modal_texture_rects(_screen._unit_modal, sprites)
	silhouettes = 0
	for sprite in sprites:
		if sprite.modulate == Color.BLACK:
			silhouettes += 1
	assert_eq(silhouettes, 1, "meeting the mk2 in battle lifts its silhouette")
	_screen._unit_modal._dismiss()


# ---------------------------------------------------------------------------
# Floating combat numbers
# ---------------------------------------------------------------------------

func test_damage_events_spawn_floating_numbers_over_the_arena() -> void:
	# Arrange: a fast player so the first turn is theirs.
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY, 300)
	_start([p], [x])

	# Act: land a hit.
	_screen._on_skill_pressed(&"strike")
	_screen._on_unit_tapped(x)

	# Assert: at least one popup Label is riding the arena (panels are UnitPanels, so any
	# direct Label child is a combat number).
	var floats := 0
	for child in _screen._arena.get_children():
		if child is Label:
			floats += 1
	assert_gt(floats, 0, "a hit that shows no number is a hit the player has to infer")


# ---------------------------------------------------------------------------
# Turn order strip & glyphs
# ---------------------------------------------------------------------------

func test_the_turn_strip_lists_everyone_still_to_move() -> void:
	# Arrange/Act: two players and one enemy; the fastest player holds the turn.
	var p1 := _unit("p1", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var p2 := _unit("p2", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 20, 1)
	var x := _unit("x", BattleUnit.Side.ENEMY, 300, SpeciesDefScript.Role.DPS, 10)
	_start([p1, p2], [x])

	# Assert: one chip per unit still to act this round, current actor included.
	assert_eq(_screen._turn_strip.get_child_count(),
		_screen.engine.upcoming_actors().size())
	assert_gt(_screen._turn_strip.get_child_count(), 1)


func test_upcoming_actors_skips_the_dead() -> void:
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var a := _unit("a", BattleUnit.Side.ENEMY, 10, SpeciesDefScript.Role.DPS, 5)
	var b := _unit("b", BattleUnit.Side.ENEMY, 300, SpeciesDefScript.Role.DPS, 1, 1)
	var e := _start([p], [a, b])

	_screen._on_skill_pressed(&"strike")
	_screen._on_unit_tapped(a)  # kills the 10 HP enemy

	for u in e.upcoming_actors():
		assert_true(u.is_alive(), "a corpse must never appear in the action queue")


func test_skill_glyphs_derive_from_what_the_skill_does() -> void:
	# Arrange: three shapes of skill.
	var physical := _strike()
	var heal := SkillDefScript.new()
	heal.effects = [{"kind": SkillDefScript.EffectKind.HEAL}]
	var ult := SkillDefScript.new()
	ult.is_ultimate = true

	# Act + Assert.
	assert_eq(Glyph.for_skill(physical), &"sword")
	assert_eq(Glyph.for_skill(heal), &"wrench")
	assert_eq(Glyph.for_skill(ult), &"star")

	var energy := _strike()
	energy.scaling_stat = &"energy_power"
	assert_eq(Glyph.for_skill(energy), &"bolt")


func test_status_effects_show_as_chips_on_the_unit() -> void:
	# Arrange: a unit carrying one debuff.
	var p := _unit("p", BattleUnit.Side.PLAYER, 200, SpeciesDefScript.Role.DPS, 30)
	var x := _unit("x", BattleUnit.Side.ENEMY)
	_start([p], [x])
	var burn := StatusEffect.new(StatusEffect.Kind.BURN, 2, true)
	p.add_status(burn)

	# Act: redraw from state.
	_screen._player_panels[0].refresh()

	# Assert: exactly one chip rides the figure.
	assert_eq(_screen._player_panels[0]._status_row.get_child_count(), 1,
		"an invisible debuff is a rule the player cannot play around")
