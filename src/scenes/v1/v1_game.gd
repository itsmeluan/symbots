## V1Game — the v1 root: composes services, grants a new player their squad, and moves
## between the stage map and battle (Core Design §6; ADR-0004).
##
## Deliberately a SEPARATE root from the retired v0 boot chain rather than a rewrite of it.
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
##
## Extends CONTROL, not Node. A Control child of a plain Node never resolves its anchors, so
## every Screen was laid out at size (0,0): the visible widgets fell back to their minimum
## sizes and anything with EXPAND_FILL — the stage list, the tree graph, the battlefield —
## got zero space and vanished. The whole game rendered as a strip in the corner.
class_name V1Game
extends Control

const StageSelectScreenScript := preload("res://src/ui/stage_select_screen.gd")
const BattleScreenScript := preload("res://src/ui/battle/battle_screen.gd")
const WorkshopScreenScript := preload("res://src/ui/workshop/workshop_screen_v1.gd")
const SkillTreeScreenScript := preload("res://src/ui/tree/skill_tree_screen.gd")
const RewardScreenScript := preload("res://src/ui/reward_screen.gd")
const SquadScreenScript := preload("res://src/ui/squad_screen.gd")
const FoundryScreenScript := preload("res://src/ui/foundry_screen.gd")
const BagScreenScript := preload("res://src/ui/bag_screen.gd")
const HomeScreenScript := preload("res://src/ui/home_screen.gd")
const ExpeditionScreenScript := preload("res://src/ui/expedition_screen.gd")
const StageRunnerScript := preload("res://src/core/stages/stage_runner.gd")
const BattleEngineScript := preload("res://src/core/battle_v1/battle_engine.gd")
const V1StateProviderScript := preload("res://src/persistence/v1_state_provider.gd")

const SPECIES_PATH := "res://assets/data/catalogs/species_catalog.tres"
const SKILL_PATH := "res://assets/data/catalogs/skill_catalog.tres"
const ITEM_PATH := "res://assets/data/catalogs/install_item_catalog.tres"
const STAGE_PATH := "res://assets/data/catalogs/stage_catalog.tres"
const TREE_PATH := "res://assets/data/tree/skill_tree.tres"

var ctx: ServiceContext = null

## Persistence. Public so a test can point it at a spy backend instead of the disk.
var save_service: SaveLoadService = null

## Storage backend, settable BEFORE the node enters the tree. Null means the real
## FileBackend and the real `user://` slot.
##
## The injection point has to be a property rather than a constructor argument because
## _ready() fires on add_child, before a test could otherwise reach in. Without it every UI
## test would read and write the player's actual save — destroying it, and making the suite
## order-dependent on whatever the previous run left behind.
var save_backend = null

## Diagnostics channel, settable before the node enters the tree. Null means the project's
## Log autoload. Same rationale as [member save_backend]: a test that exercises a failure
## path should not be routing push_error into the runner, where a CORRECT recovery reads as
## a failed test.
var log_override: LogSink = null

## The slot this session reads and writes. One slot for now — the design has no
## multi-save requirement, and a slot picker is a screen nobody asked for.
const SAVE_SLOT := 0

var _map: StageSelectScreen = null
var _battle: BattleScreen = null
var _workshop: WorkshopScreenV1 = null
var _tree_screen: SkillTreeScreen = null
var _reward: RewardScreen = null
var _squad: SquadScreen = null
var _foundry: FoundryScreen = null
var _expeditions: ExpeditionScreen = null
var _bag: BagScreen = null
var _home: HomeScreen = null

## The run in progress: its runner, its stage, and where in the battle sequence we are.
var _runner: StageRunner = null

## Seconds of pacing around each battle action. Public so tests set it to 0 BEFORE
## choosing a stage — a paced battle in a headless test is a test that waits on theatre.
var battle_turn_pace: float = 0.55
var _stage: StageDef = null
var _battle_index: int = 0
var _units: Array = []
var _result = null


func _ready() -> void:
	# Fill the viewport, so every screen parented here has a real rect to anchor against.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The design system, applied once at the root — every screen inherits the dark sci-fi
	# look instead of Godot's editor grey. See src/ui/theme (from the approved v1 prototype).
	theme = UITheme.build()
	_install_backdrop()
	ctx = build_context()
	attach_save(SaveLoadService.new(ctx.log, save_backend))
	load_or_start_new()
	show_home()


## Register the v1 provider against [param service]. Split from _ready so a test can
## inject a service backed by memory rather than writing to the real user:// directory.
func attach_save(service: SaveLoadService) -> void:
	save_service = service
	save_service.register_provider(V1StateProviderScript.KEY,
		V1StateProviderScript.new(ctx.roster, ctx.wallet, ctx.species, ctx.tree, ctx.log,
			ctx.inventory_items, ctx.item_catalog, ctx.expeditions, ctx.progress,
			ctx.blueprints, ctx.key_items, ctx.codex))


## Load the save, then make sure the player actually has Symbots.
##
## The gift is gated on the ROSTER BEING EMPTY after restoring — not on the load having
## failed. An earlier version used the load result, reasoning that re-granting could hand
## duplicates to someone who had scrapped everything. That was the wrong trade: the failure
## it prevented is cosmetic, and the one it caused is fatal.
##
## What it caused: a save written by the OLD game parses fine and returns ok, but contains
## no `v1_state` at all. The v1 roster restored empty, the gift was skipped because the load
## "succeeded", and the player booted into a stage map with no squad — every stage
## unenterable, no way out, and nothing on screen explaining why.
##
## Emptiness is also the honest condition on its own terms: a player with zero Symbots
## cannot play, so re-granting is the correct recovery rather than a bug to avoid.
func load_or_start_new() -> void:
	if save_service != null:
		save_service.load(SAVE_SLOT)
	if ctx.roster.symbots.is_empty():
		StartingSquad.grant(ctx.roster, ctx.species, ctx.log)
	# Owning a Symbot reveals its line up to its current mark, whatever the save said —
	# rederiving here also backfills saves written before the codex existed.
	if ctx.codex != null:
		for inst in ctx.roster.symbots:
			ctx.codex.mark_owned(inst.species_id, inst.mark)


## Write the save. Called after anything the player would be upset to redo — finishing a
## run, upgrading a part, allocating a node. Saving on a timer instead would mean the crash
## always lands between the tick and the thing they just did.
func save_now() -> void:
	if save_service != null:
		save_service.save(SAVE_SLOT)


## Assemble the v1 service bundle. Public and side-effect-free so tests can build the same
## context the game runs on rather than a hand-stubbed approximation that drifts from it.
func build_context() -> ServiceContext:
	var c := ServiceContext.new()
	c.log = log_override if log_override != null else _resolve_log()
	c.balance = BalanceConfig.new()
	c.roster = PlayerRoster.new()
	c.wallet = Wallet.new()
	c.inventory_items = ItemInventory.new()
	c.key_items = ItemInventory.new()
	c.blueprints = BlueprintLibrary.new()
	c.expeditions = ExpeditionBoard.new()
	c.progress = StageProgress.new()
	c.codex = DiscoveryCodex.new()
	c.species = load(SPECIES_PATH)
	c.stages = load(STAGE_PATH)
	c.tree = load(TREE_PATH)
	c.item_catalog = load(ITEM_PATH)
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

## A full-rect navy backdrop behind every screen, so gaps and transparent areas read as
## deep space rather than the editor's default grey.
func _install_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = UIPalette.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


## Route a bottom-dock destination to the right screen. One handler so every dock, on every
## screen, agrees on where each tab goes.
func _navigate_to(dest: StringName) -> void:
	match dest:
		&"map": show_map()
		&"squad": show_squad()
		&"workshop": show_workshop()
		&"tree": show_tree()
		&"foundry": show_foundry()
		&"expeditions": show_expeditions()
		&"bag": show_bag()
		&"home": show_home()


## Add a screen and give it the full viewport BEFORE setup runs.
##
## Every screen goes through here. Adding a Control without sizing it leaves it at 0x0, and
## a screen at 0x0 still draws its fixed-size widgets while everything with EXPAND_FILL —
## the stage list, the tree graph, the battlefield — silently gets no space at all.
func _present(screen: Screen) -> void:
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.setup(ctx)


func show_map() -> void:
	_clear_screens()
	_map = StageSelectScreenScript.new()
	_present(_map)
	_map.navigate.connect(Callable(self, "_navigate_to"))
	_map.stage_chosen.connect(Callable(self, "_on_stage_chosen"))
	_map.workshop_requested.connect(Callable(self, "show_workshop"))
	_map.tree_requested.connect(Callable(self, "show_tree"))
	_map.squad_requested.connect(Callable(self, "show_squad"))
	_map.foundry_requested.connect(Callable(self, "show_foundry"))
	_map.expeditions_requested.connect(Callable(self, "show_expeditions"))


## The Scrap sink. Reachable from the map because that is where the player lands after
## every fight — an upgrade screen buried a level deeper is one the player forgets exists.
func show_workshop() -> void:
	_clear_screens()
	_workshop = WorkshopScreenScript.new()
	_present(_workshop)
	_workshop.navigate.connect(Callable(self, "_navigate_to"))
	_workshop.closed.connect(Callable(self, "_on_sub_screen_closed"))


## The skill-point sink. Sits beside the Workshop because the two are the same decision
## seen twice — where does this Symbot's investment go — and splitting them across the menu
## would hide that.
func show_tree() -> void:
	_clear_screens()
	_tree_screen = SkillTreeScreenScript.new()
	_present(_tree_screen)
	_tree_screen.navigate.connect(Callable(self, "_navigate_to"))
	_tree_screen.closed.connect(Callable(self, "_on_sub_screen_closed"))


## Squad composition is the strategic layer that replaced build-from-parts, so it sits at
## the same level as the Workshop and the tree rather than nested inside one of them.
func show_squad() -> void:
	_clear_screens()
	_squad = SquadScreenScript.new()
	_present(_squad)
	_squad.navigate.connect(Callable(self, "_navigate_to"))
	_squad.closed.connect(Callable(self, "_on_sub_screen_closed"))


## The Alloy sink and the collection board. Sits beside the other build screens on the map.
## Home — where the game opens: the squad's lead Symbot and the player's badge.
func show_home() -> void:
	_clear_screens()
	_home = HomeScreenScript.new()
	_present(_home)
	_home.navigate.connect(Callable(self, "_navigate_to"))


## The Bag — a read-only ledger of components, Chipsets and blueprints.
func show_bag() -> void:
	_clear_screens()
	_bag = BagScreenScript.new()
	_present(_bag)
	_bag.navigate.connect(Callable(self, "_navigate_to"))


func show_foundry() -> void:
	_clear_screens()
	_foundry = FoundryScreenScript.new()
	_present(_foundry)
	_foundry.navigate.connect(Callable(self, "_navigate_to"))
	_foundry.closed.connect(Callable(self, "_on_sub_screen_closed"))


## Offline expeditions (§7). Leaving it saves — an expedition in progress is state the
## player expects to persist.
func show_expeditions() -> void:
	_clear_screens()
	_expeditions = ExpeditionScreenScript.new()
	_present(_expeditions)
	_expeditions.navigate.connect(Callable(self, "_navigate_to"))
	_expeditions.closed.connect(Callable(self, "_on_sub_screen_closed"))


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
	_battle.turn_pace = battle_turn_pace
	# Assigned before _present, because _present calls setup() and that is where the
	# battlefield art is chosen.
	_battle.stage = stage
	_present(_battle)
	_battle.battle_finished.connect(Callable(self, "_on_battle_finished"))
	_start_next_battle()


func _start_next_battle() -> void:
	var engine := _runner.build_battle(_units, _battle_index)
	if engine == null:
		_finish_run(true)
		return
	_result.battles.append(engine)
	_battle.set_wave(_battle_index + 1, _stage.battle_count())
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
	_runner.award(_result, ctx.wallet, ctx.progress, ctx.roster.squad_symbots(),
		ctx.inventory_items, ctx.blueprints, ctx.key_items)
	save_now()

	# The reward screen reads the settled result, so the stage reference has to survive
	# until it is shown. Clearing the run state first would leave it with nothing to name.
	var finished_stage := _stage
	var finished_result = _result
	_runner = null
	_stage = null
	_units = []
	show_reward(finished_result, finished_stage)


## The payoff beat. The moment a run ends is the most motivating point in the loop, and
## dropping the player straight back on the map spends it for nothing.
func show_reward(result, stage: StageDef) -> void:
	_clear_screens()
	_reward = RewardScreenScript.new()
	_reward.stage = stage
	_present(_reward)
	_reward.show_result(result, stage)
	_reward.dismissed.connect(Callable(self, "show_map"))


## Leaving the Workshop or the tree is the natural commit point for whatever was spent
## there — the player has finished a session of decisions and is walking away from them.
func _on_sub_screen_closed() -> void:
	save_now()
	show_map()


## The app being backgrounded on a phone is a real close, not a pause (ADR-0001
## save_emergency lifecycle path). Losing a run to a phone call is not acceptable.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


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
	if _bag != null:
		remove_child(_bag)
		_bag.queue_free()
		_bag = null
	if _home != null:
		remove_child(_home)
		_home.queue_free()
		_home = null
	if _tree_screen != null:
		remove_child(_tree_screen)
		_tree_screen.queue_free()
		_tree_screen = null
	if _reward != null:
		remove_child(_reward)
		_reward.queue_free()
		_reward = null
	if _squad != null:
		remove_child(_squad)
		_squad.queue_free()
		_squad = null
	if _foundry != null:
		remove_child(_foundry)
		_foundry.queue_free()
		_foundry = null
	if _expeditions != null:
		remove_child(_expeditions)
		_expeditions.queue_free()
		_expeditions = null
