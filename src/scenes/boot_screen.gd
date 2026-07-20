## BootScreen — the explicit boot sequencer (ADR-0004 §4).
##
## Runs ONCE as a child of the Game root, before any screen exists. It loads content
## into the DB autoloads, assembles the ServiceContext state owners, hands the context
## to the ScreenManager, and enters the Overworld — then frees itself.
##
## This is a Node orchestrator, not a managed Screen: it runs BEFORE the ServiceContext
## exists (it is what CREATES it), so it cannot itself be instantiated by ScreenManager
## the normal way. It reaches the ScreenManager as a sibling in game.tscn.
##
## SLICE SCOPE: steps 3 (ContentValidator) and 5–6 (SaveLoad provider registration +
## autosave triggers) from the full ADR-0004 §4 sequence are deferred — see TODOs. The
## playable loop does not depend on them; they harden persistence, not the core loop.
extends Node

const PlayerInventory := preload("res://src/persistence/player_inventory.gd")
const PlayerStateProvider := preload("res://src/persistence/player_state_provider.gd")

const BALANCE_PATH := "res://assets/data/balance_config.tres"
const PART_CATALOG_PATH := "res://assets/data/catalogs/part_catalog.tres"
const ENEMY_CATALOG_PATH := "res://assets/data/catalogs/enemy_catalog.tres"
const PASSIVE_CATALOG_PATH := "res://assets/data/catalogs/passive_catalog.tres"
const CONSUMABLE_CATALOG_PATH := "res://assets/data/catalogs/consumable_catalog.tres"


func _ready() -> void:
	_run_boot()


func _run_boot() -> void:
	var log: LogSink = Log.sink
	log.info(&"boot_start", {})

	# --- Step 2: load content catalogs into their DB autoloads ---
	var part_catalog := load(PART_CATALOG_PATH) as PartCatalog
	var enemy_catalog := load(ENEMY_CATALOG_PATH) as EnemyCatalog
	var passive_catalog := load(PASSIVE_CATALOG_PATH) as PassiveCatalog
	var consumable_catalog := load(CONSUMABLE_CATALOG_PATH) as ConsumableCatalog
	if (part_catalog == null or enemy_catalog == null
			or passive_catalog == null or consumable_catalog == null):
		_boot_fail(log, &"catalog_load_null")
		return
	var ok := PartDB.load_catalog(part_catalog, log)
	ok = EnemyDB.load_catalog(enemy_catalog, log) and ok
	ok = PassiveDB.load_catalog(passive_catalog, log) and ok
	ok = ConsumableDB.load_catalog(consumable_catalog, log) and ok
	if not ok:
		_boot_fail(log, &"catalog_index_failed")
		return

	# --- Step 2b: balance config ---
	var cfg := load(BALANCE_PATH) as BalanceConfig
	if cfg == null:
		_boot_fail(log, &"balance_load_null")
		return

	# --- Step 3 (deferred): ContentValidator debug pass ---
	# TODO(persistence hardening): ContentValidator.new().validate(catalogs, cfg, log)

	# --- Step 4: RNG service root seed ---
	RngService.init()

	# --- Step 4b: construct state owners + ServiceContext ---
	var inventory := PlayerInventory.new()
	var starters := _pick_stock_starters(part_catalog)
	if starters.is_empty():
		_boot_fail(log, &"no_starter_parts")
		return
	var build := SymbotBuild.with_starters(starters, cfg, log, inventory)
	var synergy := SynergySystem.new([], log)  # no authored tiers yet — empty registry

	var screen_manager: ScreenManager = get_parent().get_node("ScreenManager")
	var ctx := ServiceContext.new()
	ctx.screens = screen_manager
	ctx.build = build
	ctx.synergy = synergy
	ctx.progression = null  # CoreProgression not built yet — SymbotBuild defaults to level 1
	ctx.log = log
	ctx.inventory = inventory
	ctx.balance = cfg  # Battle screen constructs its per-fight DropSystem from this.

	# Combat UI drives the TBC autoload directly (ADR-0007 Option A) — give it the config.
	TBC.set_config(cfg, log)

	# --- Step 5–6: SaveLoad provider registration + autosave triggers ---
	# Registration happens HERE and not in the autoload's _ready, per the ADR-0004
	# inertness rule: providers need the state owners built at step 4b, which do not
	# exist yet when autoloads initialise.
	SaveLoad.setup(log)
	SaveLoad.register_provider(PlayerStateProvider.KEY,
		PlayerStateProvider.new(build, inventory, log))
	SaveLoad.connect_autosave_triggers()

	# --- Step 6b: resume a previous session, if there is one ---
	# Restored AFTER the starter build exists, so a fresh player and a returning one take
	# the same path: the restore overwrites the starters rather than racing them.
	if SaveLoad.has_save():
		var loaded := SaveLoad.load_slot()
		if loaded.get("ok", false):
			log.info(&"save_restored", {"parts": inventory.count()})
		else:
			log.warn(&"save_restore_failed", {"reason": str(loaded.get("reason", "unknown"))})

	# --- Step 7: hand off the context and enter the Overworld ---
	screen_manager.set_context(ctx)
	log.info(&"boot_complete", {"starters": starters.size()})
	screen_manager.goto_overworld()

	queue_free()  # boot is one-shot


## Fatal boot failure — log and abort. In the slice this leaves an empty ScreenManager
## rather than a half-initialized game; the error is on record via the LogSink.
func _boot_fail(log: LogSink, code: StringName) -> void:
	log.error(&"boot_failed", {"stage": code})
	queue_free()


## Assemble a stock all-COMMON starter build: the first COMMON part found for each slot
## type in the catalog. Ported from the vertical-slice harness (proven playable).
func _pick_stock_starters(catalog: PartCatalog) -> Dictionary:
	var by_slot: Dictionary = {}
	for p: PartDef in catalog.entries:
		if p.rarity == PartDef.Rarity.COMMON and not by_slot.has(p.slot_type):
			by_slot[p.slot_type] = PartInstance.new(StringName("stock_" + String(p.id)), p, 0)
	return by_slot
