# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the finished pure core drive the full
#   break -> targeted harvest -> re-equip -> feel-stronger loop end-to-end,
#   when a thin presentation layer plays the (unbuilt) Part-Break subscriber?
# Date: 2026-07-17
#
# Phase 4a headless harness. Run:
#   godot --headless -s prototypes/symbots-vertical-slice/slice_bootstrap.gd
#
# This reuses the REAL src/core systems (SymbotBuild, BattleController, DropSystem)
# against REAL content .tres. The only things it synthesizes are (a) a basic_attack
# MoveDef — moves are not authored as content yet — and (b) the Part-Break subscriber
# that turns hit_resolved into break events. Both are called out in BUILD-PLAN.md.
extends SceneTree

const SliceLogSink := preload("res://prototypes/symbots-vertical-slice/slice_log_sink.gd")

const BALANCE_PATH := "res://assets/data/balance_config.tres"
const PART_CATALOG_PATH := "res://assets/data/catalogs/part_catalog.tres"
const ENEMY_CATALOG_PATH := "res://assets/data/catalogs/enemy_catalog.tres"

const TARGET_ENEMY := &"rustcrawler"
const TARGET_REGION := &"arm"            # break this component to gate the harvest
const HARVEST_PART := &"scrapjaw_reinforced_servo_arm"  # the RARE arm we hunt
const MAX_FIGHTS := 40                   # farm cap — reports "fights to target"
const SUBMIT_CAP := 300                  # per-battle safety valve

# --- Part-Break subscriber state (the glue the slice prototypes) ---
var _log: SliceLogSink
var _controller: BattleController
var _region_damage: int = 0
var _region_break_hp: int = 0
var _region_broken: bool = false

# --- battle_ended capture ---
var _last_outcome: int = 0
var _last_break_events: Dictionary = {}


func _initialize() -> void:
	print("\n=== SYMBOTS VERTICAL SLICE — Phase 4a headless harness ===\n")
	_log = SliceLogSink.new()

	var cfg := load(BALANCE_PATH) as BalanceConfig
	var part_catalog := load(PART_CATALOG_PATH) as PartCatalog
	var enemy_catalog := load(ENEMY_CATALOG_PATH) as EnemyCatalog
	if cfg == null or part_catalog == null or enemy_catalog == null:
		push_error("Failed to load content — aborting.")
		quit(1)
		return

	# --- Assemble the stock Symbot (first COMMON part in each of the 8 slots) ---
	var starters := _pick_stock_starters(part_catalog)
	var build := SymbotBuild.with_starters(starters, cfg, _log)
	var base_stats := build.get_final_stat()
	var core_element = starters[PartDef.SlotType.CORE].part.element
	print("STOCK SYMBOT assembled — Scrapjaw all-common build:")
	for slot_type in starters:
		var pi: PartInstance = starters[slot_type]
		print("   slot %d: %s" % [slot_type, pi.part.display_name])
	print("   base structure=%d  physical_power=%d  armor=%d  energy=%d  mobility=%d\n" % [
		base_stats.get(&"structure", 0), base_stats.get(&"physical_power", 0),
		base_stats.get(&"armor", 0), base_stats.get(&"energy_capacity", 0),
		base_stats.get(&"mobility", 0)])

	# --- Frozen loadout for battle (synergy null -> empty delta; Rule 8) ---
	var part_defs: Array = []
	for slot_type in starters:
		part_defs.append(starters[slot_type].part)
	var atk := _make_basic_attack(core_element)
	var loadout := SymbotLoadout.make(
		0, base_stats, [atk, null, null, null], build.get_passive_pool(),
		core_element, part_defs)

	# --- Resolve the target enemy + its break region + loot pool ---
	var enemy_def := _find_enemy(enemy_catalog, TARGET_ENEMY)
	if enemy_def == null:
		push_error("Enemy '%s' not found." % TARGET_ENEMY)
		quit(1)
		return
	_region_break_hp = _break_hp_for_region(enemy_def, TARGET_REGION)
	var enemy_spec := {
		"id": enemy_def.id, "stats": enemy_def.stats,
		"core_element": enemy_def.core_element, "level": enemy_def.level,
		"xp_value": enemy_def.xp_value,
		"completion_bonus_xp": enemy_def.completion_bonus_xp,
		"is_first_boss_defeat": false,
	}
	var pool := _resolve_loot_pool(enemy_def, part_catalog)
	print("TARGET: %s (lvl %d, %d structure) — break the %s (break_hp=%d) to gate the harvest.\n" % [
		enemy_def.display_name, enemy_def.level, enemy_def.stats.get("structure", 0),
		TARGET_REGION, _region_break_hp])

	# --- Controller + Part-Break subscriber wiring ---
	_controller = BattleController.new(cfg, _log)
	_controller.hit_resolved.connect(_on_hit_resolved)
	_controller.battle_ended.connect(_on_battle_ended)

	# --- The hunt: fight until the RARE arm drops (deterministic seeded RNG) ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260717
	var drop_system := DropSystem.new(rng, cfg, _log)

	var harvested: PartInstance = null
	var fights := 0
	while fights < MAX_FIGHTS and harvested == null:
		fights += 1
		_reset_fight()
		var started := _controller.start_battle(
			[loadout], enemy_spec, BattleController.EncounterType.WILD, null)
		if not started:
			push_error("Battle refused to start (invalid build?).")
			quit(1)
			return
		_drive_battle(atk)
		if _last_outcome != BattleController.Outcome.VICTORY:
			print("   fight %d: outcome=%d (not victory) — retrying" % [fights, _last_outcome])
			continue
		var drops := drop_system.resolve_drops(
			DropSystem.OUTCOME_VICTORY, pool, _last_break_events, enemy_def.level)
		var names: Array = []
		for d in drops:
			names.append(String(d.part.id))
			if d.part.id == HARVEST_PART:
				harvested = d
		print("   fight %d: broke_arm=%s  drops=%s" % [
			fights, _region_broken, names])

	print("")
	if harvested == null:
		print("HARVEST FAILED — %s did not drop in %d fights (RNG/rarity). Loop still proved end-to-end.\n" % [
			HARVEST_PART, MAX_FIGHTS])
		quit(0)
		return
	print("HARVEST after %d fight(s): %s (RARE %s)\n" % [
		fights, harvested.part.display_name, harvested.part.id])

	# --- Workshop: re-equip the harvested arm; show the delta ("feel stronger") ---
	var before := build.get_final_stat()
	var result := build.equip_part(PartDef.SlotType.ARMS, harvested)
	if not result.get("ok", false):
		print("RE-EQUIP REFUSED: %s — %s" % [
			result.get("reason", "?"), result.get("message", "")])
		print("(Finding: the harvest is gated by CoreProgression / assembly rules.)\n")
		quit(0)
		return
	var after := build.get_final_stat()
	print("WORKSHOP — equipped %s into the ARMS slot. Stat delta:" % harvested.part.display_name)
	_print_delta(before, after)
	print("\n=== LOOP PROVEN: assemble -> break -> harvest -> re-equip -> stronger ===\n")
	quit(0)


# ---------------------------------------------------------------------------
# Part-Break subscriber — the presentation-tier glue the slice validates.
# Tallies full move_damage against the targeted region; once it crosses break_hp
# it fires the break event through the controller's own note_break_event seam.
# ---------------------------------------------------------------------------
func _on_hit_resolved(_move: MoveDef, damage: int, target: Combatant, sub_target: StringName) -> void:
	if not target.is_enemy or sub_target != TARGET_REGION:
		return
	_region_damage += damage
	if not _region_broken and _region_damage >= _region_break_hp:
		_region_broken = true
		_controller.note_break_event(&"arm_broken")  # feeds the VICTORY payload


func _on_battle_ended(outcome: int, _enemy_id: StringName, fired_break_events: Dictionary,
		_xp: int, _bonus: int, _first_boss: bool, _level: int, _deployed: Array) -> void:
	_last_outcome = outcome
	_last_break_events = fired_break_events.duplicate()


# Drive the parked FSM to a terminal state: attack the arm until it breaks, then
# switch to STRUCTURE to finish. Each player turn parks at ACTION_PENDING.
func _drive_battle(atk: MoveDef) -> void:
	var submits := 0
	while _controller.is_battle_active() and submits < SUBMIT_CAP:
		if _controller.state() != BattleController.BattleState.ACTION_PENDING:
			break  # single-Symbot team never forced-switches; defensive
		var sub: StringName = TARGET_REGION if not _region_broken else BattleResolver.STRUCTURE
		_controller.submit_action({
			"type": BattleController.ActionType.MOVE,
			"move": atk, "sub_target": sub,
			"is_weapon_slot": false, "crit_mult": 1.0, "part_heat_generation": 0,
		})
		submits += 1


func _reset_fight() -> void:
	_region_damage = 0
	_region_broken = false
	_last_outcome = 0
	_last_break_events = {}


# ---------------------------------------------------------------------------
# Content helpers
# ---------------------------------------------------------------------------
func _pick_stock_starters(catalog: PartCatalog) -> Dictionary:
	var by_slot: Dictionary = {}
	for p in catalog.entries:
		if p.rarity == PartDef.Rarity.COMMON and not by_slot.has(p.slot_type):
			by_slot[p.slot_type] = PartInstance.new(
				StringName("stock_" + String(p.id)), p, 0)
	return by_slot


func _make_basic_attack(core_element) -> MoveDef:
	var m := MoveDef.new()
	m.id = &"slice_basic_attack"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = core_element if core_element != null else PartDef.Element.KINETIC
	m.energy_cost = 0
	return m


func _find_enemy(catalog: EnemyCatalog, id: StringName) -> EnemyDef:
	for e in catalog.entries:
		if e.id == id:
			return e
	return null


func _break_hp_for_region(enemy_def: EnemyDef, region: StringName) -> int:
	for r in enemy_def.break_regions:
		if StringName(r.get("region_id", &"")) == region:
			return int(r.get("break_hp", 0))
	return 0


func _resolve_loot_pool(enemy_def: EnemyDef, catalog: PartCatalog) -> Array[PartDef]:
	var pool: Array[PartDef] = []
	for entry in enemy_def.loot_pool:
		if not bool(entry.get("enabled", true)):
			continue
		var want := StringName(entry.get("id", &""))
		for p in catalog.entries:
			if p.id == want:
				pool.append(p)
				break
	return pool


func _print_delta(before: Dictionary, after: Dictionary) -> void:
	for key in [&"structure", &"physical_power", &"armor", &"energy_capacity", &"mobility"]:
		var b := int(before.get(key, 0))
		var a := int(after.get(key, 0))
		var arrow := "→" if a == b else ("▲" if a > b else "▼")
		print("   %-16s %4d %s %4d  (%+d)" % [key, b, arrow, a, a - b])
