## V1Game — the v1 root: composes services, grants a new player their squad, and moves
## between the stage map and battle (Core Design §6; ADR-0004).
##
## Deliberately a SEPARATE root from `game.tscn` rather than a rewrite of it. The v0 root
## still drives the overworld, workshop and encounter flow, and ~700 tests still cover
## those systems. Ripping them out is a destructive change that belongs to the owner, not
## to an unattended loop — so this is additive, and switching between the two is one line
## in project.godot. See design §9.
##
## Screens request; the root decides. A screen never performs its own transition.
##
## class_name'd so tests can declare `var game: V1Game` and get typed member access. Left
## untyped, every `game.ctx.<anything>` is a Variant and `:=` inference fails at parse time
## — which GUT reports by silently skipping the whole file while staying green.
class_name V1Game
extends Node

const StageSelectScreenScript := preload("res://src/ui/stage_select_screen.gd")
const BattleScreenScript := preload("res://src/ui/battle/battle_screen.gd")
const WorkshopScreenScript := preload("res://src/ui/workshop/workshop_screen_v1.gd")
const SkillTreeScreenScript := preload("res://src/ui/tree/skill_tree_screen.gd")
const StageRunnerScript := preload("res://src/core/stages/stage_runner.gd")
const BattleEngineScript := preload("res://src/core/battle_v1/battle_engine.gd")

const SPECIES_PATH := "res://assets/data/catalogs/species_catalog.tres"
const SKILL_PATH := "res://assets/data/catalogs/skill_catalog.tres"
const ITEM_PATH := "res://assets/data/catalogs/install_item_catalog.tres"
const STAGE_PATH := "res://assets/data/catalogs/stage_catalog.tres"
const TREE_PATH := "res://assets/data/tree/skill_tree.tres"

var ctx: ServiceContext = null

var _map: StageSelectScreen = null
var _battle: BattleScreen = null
var _workshop: WorkshopScreenV1 = null
var _tree_screen: SkillTreeScreen = null

## The run in progress: its runner, its stage, and where in the battle sequence we are.
var _runner: StageRunner = null
var _stage: StageDef = null
var _battle_index: int = 0
var _units: Array = []
var _result = null


func _ready() -> void:
	ctx = build_context()
	StartingSquad.grant(ctx.roster, ctx.species, ctx.log)
	show_map()


## Assemble the v1 service bundle. Public and side-effect-free so tests can build the same
## context the game runs on rather than a hand-stubbed approximation that drifts from it.
func build_context() -> ServiceContext:
	var c := ServiceContext.new()
	c.log = _resolve_log()
	c.balance = BalanceConfig.new()
	c.roster = PlayerRoster.new()
	c.wallet = Wallet.new()
	c.progress = StageProgress.new()
	c.species = load(SPECIES_PATH)
	c.stages = load(STAGE_PATH)
	c.tree = load(TREE_PATH)
	c.skills = (load(SKILL_PATH) as SkillCatalog).to_table()
	c.items = (load(ITEM_PATH) as InstallItemCatalog).to_table()
	c.rng = RandomNumberGenerator.new()
	c.rng.randomize()
	return c


## The project's LogSink when the Log autoload is present, else null.
##
## The autoload is a Node that HOLDS a sink; it is not itself a LogSink (LogSink is an
## abstract RefCounted). Reaching for `.sink` rather than casting the Node is the
## difference between a channel and a parse error.
##
## Null is a legal channel — every consumer null-checks — so the v1 root also boots
## standalone in a test scene with no autoloads.
func _resolve_log() -> LogSink:
	if not is_inside_tree():
		return null
	var autoload := get_tree().root.get_node_or_null("Log")
	return autoload.sink if autoload != null else null


# ---------------------------------------------------------------------------
# Screens
# ---------------------------------------------------------------------------

func show_map() -> void:
	_clear_screens()
	_map = StageSelectScreenScript.new()
	add_child(_map)
	_map.setup(ctx)
	_map.stage_chosen.connect(Callable(self, "_on_stage_chosen"))
	_map.workshop_requested.connect(Callable(self, "show_workshop"))
	_map.tree_requested.connect(Callable(self, "show_tree"))


## The Scrap sink. Reachable from the map because that is where the player lands after
## every fight — an upgrade screen buried a level deeper is one the player forgets exists.
func show_workshop() -> void:
	_clear_screens()
	_workshop = WorkshopScreenScript.new()
	add_child(_workshop)
	_workshop.setup(ctx)
	_workshop.closed.connect(Callable(self, "show_map"))


## The skill-point sink. Sits beside the Workshop because the two are the same decision
## seen twice — where does this Symbot's investment go — and splitting them across the menu
## would hide that.
func show_tree() -> void:
	_clear_screens()
	_tree_screen = SkillTreeScreenScript.new()
	add_child(_tree_screen)
	_tree_screen.setup(ctx)
	_tree_screen.closed.connect(Callable(self, "show_map"))


func _on_stage_chosen(stage: StageDef) -> void:
	var squad := ctx.roster.squad_symbots()
	if squad.is_empty():
		return  # nothing to field; the map stays up rather than opening an empty fight

	_stage = stage
	_battle_index = 0
	_result = StageRunnerScript.Result.new()
	_runner = StageRunnerScript.new(stage, ctx.species, ctx.skills, ctx.tree,
		ctx.balance, ctx.rng, ctx.log, ctx.items)
	_units = UnitBuilder.build_side(squad, ctx.species, ctx.tree, ctx.skills,
		BattleUnit.Side.PLAYER, ctx.items)
	if _units.is_empty():
		return

	_clear_screens()
	_battle = BattleScreenScript.new()
	add_child(_battle)
	_battle.setup(ctx)
	_battle.battle_finished.connect(Callable(self, "_on_battle_finished"))
	_start_next_battle()


func _start_next_battle() -> void:
	var engine := _runner.build_battle(_units, _battle_index)
	if engine == null:
		_finish_run(true)
		return
	_result.battles.append(engine)
	_battle.begin_battle(engine, ctx.skills)


func _on_battle_finished(outcome: int) -> void:
	if outcome != BattleEngineScript.Outcome.PLAYER_WON:
		_finish_run(false)
		return

	_result.battles_won += 1
	_battle_index += 1
	if _battle_index >= _stage.battle_count():
		_finish_run(true)
		return

	# Carry the squad forward through the dungeon (§3.6) and open the next room.
	_units = _runner._carry_forward(_units)
	_start_next_battle()


## Settle, pay, and return to the map. Paying happens HERE rather than inside the battle
## screen so the reward is granted once per run, not once per fight — a dungeon that paid
## its chest three times would be the best Scrap source in the game.
func _finish_run(cleared: bool) -> void:
	_runner.settle(_result, cleared)
	_runner.award(_result, ctx.wallet, ctx.progress, ctx.roster.squad_symbots())
	_runner = null
	_stage = null
	_units = []
	show_map()


func _clear_screens() -> void:
	# remove_child first — queue_free is deferred, and a screen still in the tree keeps
	# receiving input while the next one is being built over the top of it.
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null
	if _battle != null:
		remove_child(_battle)
		_battle.queue_free()
		_battle = null
	if _workshop != null:
		remove_child(_workshop)
		_workshop.queue_free()
		_workshop = null
	if _tree_screen != null:
		remove_child(_tree_screen)
		_tree_screen.queue_free()
		_tree_screen = null
