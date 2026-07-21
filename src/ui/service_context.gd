## ServiceContext — dependency bundle injected into every Screen at instantiation (ADR-0008 §1).
##
## Assembled ONCE by V1Game at boot and passed to
## every screen's setup(ctx) call. Because it is a RefCounted, it is kept alive as long
## as any screen holds a reference — it is NOT freed until all screens that received it
## are freed.
##
## BattleController is NOT a field here. It is reached as the global slot-11 autoload
## (Option A, ADR-0007) — Combat UI accesses it via the `TBC` singleton directly.
## (The autoload is named TBC; `BattleController` is the core RefCounted class it wraps.)
## Save/Settings are also not in the bundle — views never touch them.
##
## IMPORTANT: Screens must NOT hold references to ServiceContext past EXIT_TREE.
## If a screen stores `_ctx` in setup(), it must set `_ctx = null` in _on_exit_tree()
## to let the RefCounted teardown cleanly. Lambda closures over `ctx` from _connect_owned
## calls are FORBIDDEN for the same reason (ADR-0008 named-Callable discipline).
class_name ServiceContext
extends RefCounted

## Retired with the v0 boot chain — V1Game routes screens itself. Kept as an untyped slot
## so the field name survives for any caller still reading it.
## to request transitions — they never perform transitions themselves.
## (screen_transitions contract, ADR-0004/0008)
var screens = null

## The active SymbotBuild. Read-only from screens — equip mutations go through
## Workshop logic, never directly from a view (inline_stat_composition forbidden).
## Type is Variant until SymbotBuild is imported here; assign the real type once
## the class is stable.
var build  ## : SymbotBuild

## SynergySystem for preview() calls and synergy_changed subscription.
## Type is Variant until SynergySystem is imported; assign real type when stable.
var synergy  ## : SynergySystem

## CoreProgression gate accessor: can_equip / is_build_valid / level display.
## Variant until CoreProgression class exists.
var progression  ## : CoreProgression

## Injected diagnostics channel. Never call push_warning/push_error from a screen —
## always route through this LogSink (global_push_diagnostics forbidden, ADR-0002).
var log: LogSink

## The session's owned-part store (harvest drops + displaced parts). The WorkshopScreen
## reads this for equip candidates; DropSystem and SymbotBuild write to it.
## Type is Variant until PlayerInventory is stable (concrete InventorySink, no class_name).
var inventory  ## : PlayerInventory

## The loaded BalanceConfig (boot step 2b). The Battle screen constructs its per-fight
## DropSystem with this. Screens never mutate it — read-only tuning data.
var balance: BalanceConfig


# ---------------------------------------------------------------------------
# v1 services (design/v1/00-core-design.md). Added alongside the v0 fields rather
# than replacing them: the v0 systems and their ~700 tests are still green, and
# tearing them out is a destructive change that belongs to the owner, not to an
# unattended loop. See §9 Open items.
# ---------------------------------------------------------------------------

## Everything the player owns, and the four they field (§2, §3.1).
var roster: PlayerRoster

## Scrap and Alloy (§5.1).
var wallet: Wallet

## Install items owned but not fitted (§4.4).
var inventory_items: ItemInventory

## Named key items (Chipsets) — not socket components, so they are counted apart
## from `inventory_items`, which validates ids against the socket catalog.
var key_items: ItemInventory

## Species blueprints the player has learned to craft (§5.1).
var blueprints: BlueprintLibrary

## Which stages are cleared, and therefore which are open (§6).
var progress: StageProgress

## Timed offline missions for the bench (§7).
var expeditions: ExpeditionBoard

## Frozen content catalogs. Screens read; nothing mutates them.
var species: SpeciesCatalog
var stages: StageCatalog
var tree: SkillTree
var item_catalog: InstallItemCatalog

## skill_id -> SkillDef, built once from the catalog (§3.4).
var skills: Dictionary = {}

## item_instance_id -> InstallItemDef, for socket resolution (§4.4).
var items: Dictionary = {}

## Seeded RNG vended by RngService (ADR-0006). A battle built from this replays
## identically from the same seed.
var rng: RandomNumberGenerator
