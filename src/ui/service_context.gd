## ServiceContext — dependency bundle injected into every Screen at instantiation (ADR-0008 §1).
##
## Assembled ONCE by BootScreen at step 4b. ScreenManager holds it and passes it to
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

## The ScreenManager. Screens call screens.goto_*() / enter_battle() / open_workshop()
## to request transitions — they never perform transitions themselves.
## (screen_transitions contract, ADR-0004/0008)
var screens: ScreenManager

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
