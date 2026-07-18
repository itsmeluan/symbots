## RngService — injected-seed RNG factory (ADR-0006; ADR-0004 §1 slot 9).
##
## Vends deterministic seeds and pre-seeded RandomNumberGenerator instances from one
## root. All gameplay randomness arrives through this service — global randf()/randi()
## calls are forbidden in gameplay/formula code (`global_rng_access`).
##
## Usage pattern (ADR-0006):
##   Orchestrators (BootScreen, BattleController autoload, Drop resolver host) call
##   RngService.next_seed() or RngService.make_rng() to get seeded inputs. They then
##   pass the seed/rng into pure functions — `src/core/` never touches RngService.
##   (`rng_service_in_formula_code` is a registered forbidden pattern.)
##
## Determinism boundary: within a single engine build run. The root seed is logged
## via Log.sink at init() time for replay/debug, but is NOT persisted to save files.
##
## ADR-0004 inertness rule: zero _ready work. init() is called explicitly by the
## BootScreen sequencer at boot step 4 — never in _ready.
extends Node

var _root_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Monotonically-increasing counter for sub-seed derivation. Incremented on every
## next_seed() call to guarantee each vended seed differs from the last even when
## the engine frame delta is zero.
var _counter: int = 0
## True after init() has been called. Guards against accidental pre-boot use.
var _initialized: bool = false


## Initialize the root RNG from a system-entropy seed. Called ONCE by BootScreen
## sequencer at boot step 4 (ADR-0004). The chosen root seed is logged via Log.sink
## (`rng_seed_issued` info breadcrumb) for replay. Must not be called again — calling
## init() twice reseeds the root and breaks any in-flight determinism window.
## RngService.init() is the ONLY sanctioned randomize() call in the project (ADR-0006).
func init() -> void:
	_root_rng.randomize()
	_counter = 0
	_initialized = true
	# Log the root seed for replay/debug (ADR-0006). Uses Log.sink directly because
	# this autoload is at slot 9 and Log is at slot 2 — guaranteed to be initialized.
	Log.sink.info(&"rng_seed_issued", {"root_seed": _root_rng.seed})


## Vend the next deterministic sub-seed derived from the root. Each call returns a
## unique int guaranteed to differ from the prior call. Callers inject this into pure
## functions or pass to make_rng().
##
## NOTE: if called before init(), a warning is logged and a fallback value is
## returned rather than crashing — boot order violations must not silently succeed,
## so this path warns loudly.
func next_seed() -> int:
	if not _initialized:
		push_warning("RngService.next_seed() called before init() — boot order violation")
	_counter += 1
	# XOR-fold the root seed with a counter-driven mix to produce a distinct sub-seed.
	# This is NOT cryptographic — it is a simple deterministic derivation sufficient
	# for gameplay use cases (EnemyAI, Drop rolls, crit rolls).
	return _root_rng.seed ^ (_counter * 2654435761)  # 2654435761 = Knuth's multiplicative hash


## Vend a new RandomNumberGenerator already seeded with next_seed(). The caller owns
## the instance and must NOT cache it across successive calls (`persistent_shared_rng`
## forbidden — a reused instance carries stream state; identical inputs yield different
## outputs by call history; ADR-0006 enemy-ai Rule 3).
func make_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = next_seed()
	return rng
