## StageRunner — plays a stage's battles in sequence and pays out (Core Design §6).
##
## The piece that closes the loop: squad in, battles run, Scrap out, stage marked cleared.
## Everything is injected, so the same runner drives the on-screen stage and the offline
## expedition simulator — and the two therefore cannot pay different rewards for the same
## fight.
##
## Between fights in a DUNGEON, structure and ult charge carry and everything else resets
## (§3.6, §3.4b). That is the whole difference between a dungeon and a run of separate
## stages: attrition falling while charge rises, pulling opposite ways as the run goes
## deeper.
class_name StageRunner
extends RefCounted

const StageDefScript := preload("res://src/core/stages/stage_def.gd")
const BattleEngineScript := preload("res://src/core/battle_v1/battle_engine.gd")

## What a completed run yields. A plain object rather than a Dictionary so a typo in a key
## is a parse error instead of a silently missing reward.
class Result extends RefCounted:
	var cleared: bool = false
	var battles_won: int = 0
	var scrap_earned: int = 0
	var alloy_earned: int = 0
	var xp_each: int = 0
	var levels_gained: int = 0
	var chest_items: Array[StringName] = []
	var chest_blueprint: StringName = &""
	## True only when the blueprint in the chest was NEW to the player — so the reward screen
	## announces "blueprint unlocked" once, not on every replay of a cleared boss.
	var blueprint_was_new: bool = false
	## Chipsets the clear paid out. Dungeons are the only faucet (Core Design §2.2):
	## the rarity ceiling has to be earned somewhere the player chooses to go back to.
	var cores_earned: int = 0
	## One BattleEngine per fight, in order, so a caller can replay or inspect any of them.
	var battles: Array = []

var _stage: StageDef
var _species: SpeciesCatalog
var _skills: Dictionary
var _tree: SkillTree
var _items: Dictionary
var _cfg: BalanceConfig
var _rng: RandomNumberGenerator
var _log: LogSink


func _init(stage: StageDef, species: SpeciesCatalog, skills: Dictionary, tree: SkillTree,
		cfg: BalanceConfig, rng: RandomNumberGenerator, log: LogSink,
		items: Dictionary = {}) -> void:
	_stage = stage
	_species = species
	_skills = skills
	_tree = tree
	_cfg = cfg
	_rng = rng
	_log = log
	_items = items


## Run every battle in the stage with [param squad] auto-battling, and return the payout.
##
## Auto-resolution is what expeditions and "sweep a cleared stage" need. A manually played
## stage uses [method build_battle] per fight and calls [method settle] at the end, so both
## paths share the same reward arithmetic.
func run_auto(squad: Array) -> Result:
	var result := Result.new()
	var units := _build_player_units(squad)
	if units.is_empty():
		return result

	for index in _stage.battle_count():
		var engine := build_battle(units, index)
		if engine == null:
			break
		result.battles.append(engine)
		engine.start()
		var guard := 0
		while not engine.is_over() and guard < _cfg.max_battle_rounds * 40:
			engine.take_auto_action()
			guard += 1

		if engine.outcome != BattleEngineScript.Outcome.PLAYER_WON:
			# Defeat costs the chest and the time, never what already dropped (§6).
			return settle(result, false)

		result.battles_won += 1
		units = _carry_forward(units)

	return settle(result, true)


## Build the engine for battle [param index] with the given player units already in
## whatever state the run left them.
func build_battle(units: Array, index: int) -> BattleEngine:
	var enemy_ids := _stage.enemies_at(index)
	if enemy_ids.is_empty():
		return null
	var marks := _stage.marks_at(index)
	var enemies: Array = []
	for i in enemy_ids.size():
		var species := _species.get_species(enemy_ids[i])
		if species == null:
			_warn(&"stage_enemy_unresolved", {"stage": String(_stage.id), "species": String(enemy_ids[i])})
			continue
		var unit := UnitBuilder.build_enemy(species, _stage.enemy_level,
			BattleUnit.Side.ENEMY, enemies.size(), _skills, i, int(marks[i]))
		if unit != null:
			enemies.append(unit)
	if enemies.is_empty():
		return null
	return BattleEngineScript.new(units, enemies, _skills, _cfg, _rng, _log)


## Reset the squad for the next fight in the same run.
##
## A plain stage never reaches here (it has one battle). In a dungeon, structure and ult
## charge survive; statuses, shields and cooldowns do not — carrying a burn or a spent
## cooldown across a room boundary would make the run's difficulty depend on exactly when
## the previous fight happened to end.
func _carry_forward(units: Array) -> Array:
	if not _stage.carries_structure():
		for u in units:
			u.current_structure = u.max_structure
			u.ultimate_charge = 0
	for u in units:
		u.statuses.clear()
		u.cooldowns.clear()
		u.shield = 0
		# A destroyed Symbot comes back on 1 structure rather than staying down. Otherwise
		# one bad room silently makes the rest of the dungeon unwinnable, and the player
		# spends five more fights discovering that.
		if not u.is_alive():
			u.current_structure = 1
	return units


## Compute the payout. Split from run_auto so a manually played stage settles identically.
func settle(result: Result, cleared: bool) -> Result:
	result.cleared = cleared
	result.scrap_earned = result.battles_won \
		* UpgradeEconomy.battle_reward(_stage.stage_level, _cfg)
	# XP is per battle won, like Scrap — a run abandoned halfway still paid for the fights
	# that were actually fought (§6: defeat costs the chest and the time, not the session).
	result.xp_each = result.battles_won * XpProgression.battle_xp(
		_stage.enemy_level, _average_enemy_count(), _cfg)
	if cleared:
		result.scrap_earned += UpgradeEconomy.chest_reward(_stage.stage_level, _cfg)
		result.chest_items = _stage.chest_item_ids.duplicate()
		result.chest_blueprint = _stage.chest_blueprint_id
		# Alloy — the rare currency — only comes from boss chests (dungeons/raids), per
		# §5.1. A plain stage pays Scrap and items; Alloy is what makes clearing a DUNGEON
		# worth more than farming trash, and it is the only way to afford crafting.
		if _stage.carries_structure():
			result.alloy_earned = _cfg.alloy_reward_base \
				+ _cfg.alloy_reward_per_stage * maxi(0, _stage.stage_level - 1)
	return result


## Pay a result into the player's wallet and mark the stage cleared. Separate from settle()
## so a caller can show the reward screen before the numbers actually move.
func award(result: Result, wallet: Wallet, progress: StageProgress,
		squad: Array = [], items: ItemInventory = null,
		library: BlueprintLibrary = null, key_items: ItemInventory = null) -> void:
	if result.scrap_earned > 0:
		wallet.earn(Wallet.SCRAP, result.scrap_earned)
	if result.alloy_earned > 0:
		wallet.earn(Wallet.ALLOY, result.alloy_earned)
	# The chest actually hands over its contents. Listing items in a Result that never
	# reached an inventory made the chest a promise the game did not keep.
	if items != null:
		for item_id in result.chest_items:
			items.add(item_id)
	# A boss chest teaches its blueprint. unlock() returns true only when it is NEW, so the
	# reward screen can announce a first-time unlock without lying on every replay.
	if library != null and result.chest_blueprint != &"":
		result.blueprint_was_new = library.unlock(result.chest_blueprint)
	if result.xp_each > 0 and not squad.is_empty():
		result.levels_gained = XpProgression.grant_squad(squad, result.xp_each, _cfg)
	# A cleared dungeon pays a Chipset, every time — it is the long-tail reason to
	# return to a boss the player has already beaten.
	if result.cleared and _stage.carries_structure():
		result.cores_earned = 1
		if key_items != null:
			key_items.add(KeyItems.CHIPSET)
	if result.cleared:
		progress.mark_cleared(_stage.id)


## Mean enemies per battle in this stage, so a three-enemy fight pays more than a lone one
## without XP depending on which room the run happened to end in.
func _average_enemy_count() -> int:
	if _stage.battle_count() == 0:
		return 1
	var total := 0
	for i in _stage.battle_count():
		total += _stage.enemies_at(i).size()
	return maxi(1, total / _stage.battle_count())


func _build_player_units(squad: Array) -> Array:
	return UnitBuilder.build_side(
		squad, _species, _tree, _skills, BattleUnit.Side.PLAYER, _items)


func _warn(code: StringName, detail: Dictionary) -> void:
	if _log != null:
		_log.warn(code, detail)
