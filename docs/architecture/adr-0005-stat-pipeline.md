# ADR-0005: Stat Pipeline & Battle Snapshot

## Status
Accepted (2026-07-14)

> Accepted by architecture-review 2026-07-14: all 36 gap TRs covered; engine-safe on Godot 4.6; dependencies (ADR-0001..0004) all Accepted, no cycles. Boot-step references corrected to sub-steps 2b/4b (conflict C-1) as part of acceptance; ADR-0004 amended to match.

## Date
2026-07-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (pure GDScript gameplay math — no scene, physics, or rendering surface) |
| **Knowledge Risk** | MEDIUM — 4.6 is post-cutoff HIGH globally, but every API this ADR uses (static funcs, `RefCounted`, typed signals, `Resource` `@export`) is 4.1-era stable, except typed dictionaries (4.4+) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `Dictionary[StringName, int]` typed dictionaries (4.4+) — `stat_bonuses`, `level_growth` (both already committed by ADR-0003's `PartDef`), and the new `BalanceConfig` tables. Same surface as ADR-0003's open `.tres` round-trip verification gate |
| **Verification Required** | (1) `Dictionary[StringName, int]` `.tres` round-trip — **shared with ADR-0003's open gate**; `BalanceConfig` adds a second consumer of the same pattern, it does not add a new gate. Flat tables fall back to ADR-0003's mitigation (paired arrays or String keys); the **nested** tables (`chassis_modifiers`, `type_chart` — archetype/element → per-key table) need the nested fallback form decided before `balance_config.tres` is authored: composite `String` keys (e.g. `"BRUTE:attack_power"`) or per-archetype paired key/value arrays. (2) StringName ordering: the String-cast alphabetical tier-ID sort (Synergy Rule 3) must be pinned by a determinism test at implementation (AC-SYN-05b) — never `sort()` on `Array[StringName]` directly. (3) `maxi()`/`floori()` integer-typed math variants — confirmed 4.0-era `@GlobalScope` additions (pre-cutoff, specialist-verified 2026-07-14); reconfirm only if 4.6 behavior deviates from integer truncation expectations |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted — `CoreProgressionRecord` persists as plain data inside the exploration-progress provider blob), ADR-0002 (Accepted — owner-declared typed signals; injected LogSink; 8-field `battle_ended` contract), ADR-0003 (Accepted — frozen `PartDef`/`EnemyDef` shared instances; DB typed getters), ADR-0004 (Accepted — BootScreen sequencing; fixed 10-autoload roster; ScreenManager dependency injection) |
| **Enables** | ADR-0007 (TBC state machine — consumes `CombatantSnapshot`, `DamageFormula`, `SynergyEvaluator.evaluate_silent`); ADR-0008 (UI — Workshop preview reads `preview_swap`/`preview` seams) |
| **Blocks** | All Assembly / Synergy / Core-Progression / Workshop implementation stories; TBC implementation stories (they consume this ADR's contracts) |
| **Ordering Note** | ADR-0006 (RNG) is fully independent — DF-1 is deterministic and consumes no RNG (Damage Formula Rule 5). ADR-0007 must author damage resolution against this ADR's snapshot + composition contracts, and must resolve the `battle_ended`-host seam noted in Risks |

## Context

### Problem Statement

Five approved GDDs specify the stat math to implementation precision — SA-F1's pipeline order, Formula 2/2b sign routing with load-bearing epsilon nudges, CP-F1–F4, SYN-F1–F4 with deterministic dedup ordering, DF-1's float-cast and floor discipline, and TBC's BATTLE_INIT freeze semantics. What no document decides is the **code architecture**: where these formulas live, what owns mutable state, how the battle snapshot is constructed and kept immutable (the GDDs call the freeze "a behavioral contract, not a system-enforced lock"), how consumers compose effective stats without divergent reimplementations, and how the 80%-coverage/DI mandate is met. 36 technical requirements (traceability-index.md § ADR-0005) are gapped on this decision.

### Constraints

- **Fixed 10-autoload roster** (ADR-0004) — none of these systems may be a new autoload without amending ADR-0004
- **Frozen content defs** (ADR-0003, `runtime_content_mutation` forbidden pattern) — the pipeline copies primitive fields out of `PartDef`/`EnemyDef`; it never mutates or `duplicate()`s a def
- **Injected LogSink** (ADR-0002, `global_push_diagnostics` forbidden pattern) — every content warning this pipeline emits (unknown stat key, duplicate `register_core`, invalid synergy tier) must be assertable in GUT
- **Owner-declared typed signals; closed bus** (ADR-0002) — `stats_changed`, `part_equipped`, `synergy_changed`, `core_leveled_up` are direct-connection signals, never EventBus additions
- **Data-driven mandate** (coding standards) — tuning values live in external config, never hardcoded
- **80% GUT coverage on game-logic systems; DI over singletons** (testing standards)
- **Float-epsilon empirics** (part-database.md pipeline note, 2026-07-09 scan): the Formula 2b nudge is **load-bearing** (26 valid inputs fail without it); F1/F2/DF-1 nudges are defensive but mandatory; any *new* floor/ceil formula introduced during implementation requires a python3 IEEE-754 scan before story acceptance
- **Mobile responsiveness** — the pipeline runs eagerly on every equip and twice per Workshop hover preview; it must be trivially cheap (integer math over 8 parts × 11 stats)

### Requirements

- Execute SA-F1 exactly, as the sole executor of Part DB Formula 1/2/2b (TR-sa-001…004, 006…009)
- Synergy SYN-F1–F4 with deterministic registration order, keep-first dedup, tier validation, null-tag tolerance, never-null contracts (TR-syn-001…010, 012, 013)
- Core Progression CP-F1–F4: integer threshold lookup, bench split + lead cap, equip gate, CORE-only `level_growth`, pipeline position, power-of-2 `BENCH_XP_SHARE` (TR-cp-003…006, 008, 009, 011, 019, 020)
- DF-1 as a pure stateless function with float casts, pre-floor multiplier ordering, post-floor damage floor, zero-division guard (TR-df-001, 002, 004, 005, 006)
- Battle snapshot locked at BATTLE_INIT; SYN-F4 clamp on both sides; frozen passive aura (TR-tbc-002, 012)

## Decision

**A four-layer architecture: a pure-function formula core, thin stateful owners built by boot-time DI, a typed immutable battle snapshot with a single stat-composition point, and one data-driven tuning resource.** No new autoloads. No nodes except where a signal host is unavoidable (none in this ADR).

### Layer 1 — Pure formula core (`src/core/stats/`)

Static-function classes. No state, no signals, no autoload registration. Constants come from an injected `BalanceConfig`; diagnostics go to an injected `LogSink` parameter. Every function is a pure input→output mapping, directly GUT-testable against the GDD worked examples.

| Class | Owns | Key contents |
|-------|------|--------------|
| `StatMath` | numeric primitives + the single SYN-F4 implementation | `floor_eps(x) = floor(x + EPSILON)`, `ceil_eps(x) = ceil(x - EPSILON)`; `effective_stat(base, synergy_delta, aura_delta) = maxi(0, base + synergy_delta + aura_delta)`. `EPSILON = 0.0001` is a **const here, not in BalanceConfig** — DF-1 marks it "not a tuning knob; fixed implementation constant" |
| `StatPipeline` | SA-F1 steps 1–4b | `derive(equipped, chassis_archetype, core_level, level_growth, cfg, log) -> Dictionary`: per-part F2/F2b sign routing (Formula Pipeline, part-database.md) → 8-part sum → chassis multiply from `cfg.chassis_modifiers` → `maxi(0, floor_eps(...))` → CP-F3 add (post-chassis, pre-synergy — TR-cp-011/TR-sa-004). Unknown stat keys → `log.warn` + skip (EC-SA-05) |
| `DamageFormula` | DF-1 | `compute_damage(a: int, d: int, type_mult: float, cfg, log, crit_mult: float = 1.0) -> int`: `a == 0 and d == 0` → return `cfg.damage_floor` **before** division (TR-df-006); `float(a) * float(a) / (float(a) + float(d))` — cast before divide (TR-df-004); `type_mult` and `crit_mult` multiplied **pre-floor** (TR-df-002); `maxi(cfg.damage_floor, StatMath.floor_eps(pre_floor))` (TR-df-005). `crit_mult` is a passable parameter, never hardcoded (AC-DF-18). No reads of any runtime state (TR-df-001) |
| `SynergyMath` | SYN-F1/F2/F3 | tag count with null-`synergy_tags`-as-`[]` (TR-syn-013) and `Dictionary.get(tag, 0)` safe lookup; ∀-activation with non-empty-requirements + `min_count >= 1` validation → skip + `log.error` (TR-syn-002, 007); aggregation iterating tiers in **String-cast alphabetical tier-ID order** (pinned idiom: copy the IDs into an `Array[String]` and `sort()` that copy, then iterate it — never `sort()` or `sort_custom()` on `Array[StringName]` directly, whose ordering is not contractually stable) with keep-first effect dedup and `int()` ingest on every `stat_delta` value (TR-syn-001, 003, 004, 005, 006) |
| `ProgressionMath` | CP-F1/F2/F4 | threshold lookup over `cfg.xp_thresholds` — pure sorted-int scan, no float (TR-cp-003), capped at `cfg.max_core_level` (TR-cp-004); `bench_xp = floori(full_xp * cfg.bench_xp_share)` (TR-cp-005); `xp_value = (cfg.xp_base + enemy_level * cfg.xp_per_enemy_level) * role_multiplier` — pure int (TR-cp-019) |

### Layer 2 — Stateful owners (`RefCounted`, DI-constructed; not autoloads, not nodes)

| Owner | State | Contract |
|-------|-------|----------|
| `SymbotBuild` | display name; 8-slot manifest of part instances (`instance_id`, `PartDef` ref, tier); cached `final_stat`; derived move + passive pools | `equip_part(slot_type, part_instance)` implements Assembly Rule 3: slot-type validate → `CoreProgression.can_equip` gate (TR-cp-008) → atomic displace/install, no empty slots ever (TR-sa-007) → eager `StatPipeline.derive` → emit `part_equipped(slot_type, new_part_id)`, `stats_changed(final_stat)`. Move pool fixed order Basic/WEAPON/HEAD/ARMS, `[3]` nullable (TR-sa-008); passive pool CORE, LEGS, then slot-type order (TR-sa-009). `preview_swap(candidate, slot) -> Dictionary` (SA-F2): full-pipeline hypothetical recompute in memory — including CP-F3, excluding synergy — no signal, no state change |
| `SynergyEvaluator` | exactly one mutable field: `cached_bonus_block`, initialized to the empty block (valid zero-bonus before any call) | `evaluate(parts)` — recompute + always emit `synergy_changed(active_synergies, bonus_block)`; `evaluate_silent(parts)` — recompute + cache, **no emit** (battle baseline); `preview(candidate, slot, parts)` — pure read-only: no cache write, no emit (TR-syn-009); out-of-range slot → `log.error` + empty block; null candidate = unequip preview, never dereferenced. `active_synergies` is always `Array[StringName]`, never null (TR-syn-012) |
| `CoreProgression` | ledger `Dictionary[int, CoreProgressionRecord]` (`cumulative_xp` authoritative; `level` a display cache always re-derived via CP-F1) | `register_core(id)` — duplicate → `log.warn` no-op; `can_equip(core_instance_id, part) -> bool` (TR-cp-008); `is_build_valid(build) -> bool` (TBC Rule 2.0 precondition); `apply_battle_result(outcome, xp_value, completion_bonus_xp, is_first_boss_defeat, enemy_level, deployed_symbot_ids)` — consumes the 8-field `battle_ended` payload fields verbatim (registry contract `combat_battle_end`): first-defeat bonus guard, bench split via `ProgressionMath`, bench-lead cap `benched.level >= enemy_level + cfg.bench_level_lead_cap` → 0 (TR-cp-006), level-10 XP discard (TR-cp-004); emits `core_leveled_up(id, old_level, new_level)` once per gain span. `level_growth` read only from CORE-slot parts; non-CORE `level_growth` ignored with content warning (TR-cp-009) |

**Construction & wiring.** BootScreen constructs `CoreProgression` (and the other player-state owners) at boot step 4b (ADR-0004 §4), immediately before save-provider registration (step 5); its ledger rides **inside** the exploration-progress provider blob as plain data (ADR-0001; CP GDD Interactions). `SymbotBuild` instances and the `SynergyEvaluator` belong to the Workshop domain and persist via the workshop provider. Screens receive these objects via ScreenManager injection at instantiation (ADR-0004) — no autoload lookups, no `get_parent()` climbing. All constructors take `(cfg: BalanceConfig, log: LogSink)` plus their collaborators — every owner is constructible in GUT with a spy sink and a test config.

### Layer 3 — `CombatantSnapshot` (typed, immutable-by-construction)

```gdscript
class_name CombatantSnapshot
extends RefCounted
## Built ONCE at BATTLE_INIT (TBC Rule 2). Never mutated afterward — enforced
## by construction discipline + the isolation GUT test, not by a runtime lock.

var final_stat: Dictionary        # 11 canonical keys -> int; deep-copied from SymbotBuild
var synergy_delta: Dictionary     # frozen SYN-F3 stat_delta (deep copy)
var passive_aura: Dictionary      # frozen STAT_AURA block (empty in MVP content)
var effects: Array[StringName]    # frozen deduplicated synergy effects
var move_pool: Array              # 4 entries; [3] may be null (Common ARMS)
var passive_pool: Array[StringName]
var max_structure: int
var max_energy_capacity: int

func effective_stat(s: StringName) -> int:   # THE SYN-F4 composition point in battle
    return StatMath.effective_stat(final_stat.get(s, 0),
        synergy_delta.get(s, 0), passive_aura.get(s, 0))

static func build_player(build: SymbotBuild, bonus_block: Dictionary,
        aura_block: Dictionary) -> CombatantSnapshot: ...
static func build_enemy(def: EnemyDef) -> CombatantSnapshot: ...
```

- **One class for both sides.** `build_enemy` copies the authored `stats` from `EnemyDef` into `final_stat` and leaves `synergy_delta`/`passive_aura` empty `{}` — enemies get no synergy (TBC Rule 2.3), and `effective_stat()` degenerates to `maxi(0, stat)`. DF-1 callers read `effective_stat()` on **both sides** uniformly (TR-tbc-012) without branching.
- **Immutability discipline (TR-tbc-002, TR-sa-006, TR-syn-008):** every Dictionary/Array field is `duplicate(true)`-copied at build — the snapshot shares no references with the live `SymbotBuild` or the evaluator's cache; fields are assigned only inside `build_*`; there are no setters. A dedicated GUT test mutates the source build and the evaluator cache after snapshotting and asserts the snapshot is unaffected (and vice versa). The GDD's "behavioral contract, not a self-lock" is honored: nothing recomputes during battle because no battle-scope code path calls `derive`/`evaluate` — Workshop equip is locked out while `is_battle_active` (Synergy DCO-8).
- **Consumers never inline SYN-F4.** TBC damage resolution, initiative (`effective_mobility` = `effective_stat(&"mobility")` + status modifiers), and Workshop displays all go through `StatMath.effective_stat` / `CombatantSnapshot.effective_stat`. Two implementations of one formula is how the MOVE-F1 seam was missed (design-review 2026-07-12) — this ADR makes the composition point singular and registers inlining as a forbidden pattern.

### Layer 4 — `BalanceConfig` (single typed tuning Resource)

`class_name BalanceConfig extends Resource`, authored as one `.tres` (`assets/data/balance_config.tres`), loaded by BootScreen at boot step 2b (ADR-0004 §4), immediately after the six content catalogs (fatal-on-missing → BootError), validated by ContentValidator, injected into every Layer-1/2 constructor.

| Group | Fields (all `@export`) |
|-------|------------------------|
| Assembly | `chassis_modifiers: Dictionary` (archetype → per-stat float table, Part DB Rule 3), `upgrade_multipliers: Array[float]` (tiers 0–5), canonical 11-stat key list |
| Progression | `xp_thresholds: Array[int]` (CP-F1 pre-computed table, authoritative at runtime), `max_core_level = 10`, `xp_base = 35`, `xp_per_enemy_level = 10`, `boss_xp_multiplier = 2`, `bench_xp_share = 0.5`, `bench_level_lead_cap` |
| Damage | `damage_floor = 1`, `type_chart: Dictionary` (element×element → float, Part DB Rule 6 locked values) |
| Synergy | `synergy_power_budget = 40`, `synergy_defense_budget = 50` (content-validation ceilings, TBC range re-derivation) |

ContentValidator gains a BalanceConfig section (boot + CI): `xp_thresholds` strictly increasing with `threshold[1] == 0`; `upgrade_multipliers` within the scanned safe ranges; **`bench_xp_share` must be a power of two** — the CP-F2 no-epsilon guarantee holds only for exactly-representable fractions; a non-power-of-2 value fails validation with instructions to add an epsilon guard + rerun the float scan (TR-cp-020, AC-CP-23); every `chassis_modifiers` stat key ∈ the canonical 11. `EPSILON` is deliberately **not** here (fixed const in `StatMath`).

### Pipeline order — the load-bearing contract

```
per part: F2 (base>0) | F2b (base<0, Prototype) | 0        [StatPipeline]
  → sum across 8 parts
  → × chassis_modifier.get(S, 1.0)
  → maxi(0, floor_eps(·))                                   = SA-F1 output
  → + level_growth[S] × (core.level − 1)                    = CP-F3 (post-chassis, pre-synergy)
  → stored final_stat  ——— synergy NEVER included here (Assembly Rule 8)
BATTLE_INIT: snapshot final_stat + frozen SYN-F3 block + frozen aura block
  → effective_stat(S) = maxi(0, final + synergy + aura)     = SYN-F4, single point
  → DF-1 → MOVE-F1 power tier → TBC-F5 Stagger → break-bias routing   [ADR-0007]
```

Workshop previews (`preview_swap`, `preview`) run the **same Layer-1 functions** over hypothetical inputs — the full pipeline including CP-F3, per the pipeline-composition lesson: a preview that composes only the head of the pipeline is a defect class this project has already shipped once.

### Key Interfaces

Signals (owner-declared, typed, direct-connection — ADR-0002):
- `SymbotBuild.part_equipped(slot_type: int, new_part_id: StringName)`
- `SymbotBuild.stats_changed(final_stat: Dictionary)`
- `SynergyEvaluator.synergy_changed(active_synergies: Array[StringName], bonus_block: Dictionary)`
- `CoreProgression.core_leveled_up(core_instance_id: int, old_level: int, new_level: int)`

Methods (contracts other ADRs consume):
- `StatPipeline.derive(...) -> Dictionary` — sole SA-F1 executor (TR-sa-001)
- `DamageFormula.compute_damage(a, d, type_mult, cfg, log, crit_mult := 1.0) -> int`
- `SynergyEvaluator.evaluate / evaluate_silent / preview`
- `CoreProgression.register_core / can_equip / is_build_valid / apply_battle_result`
- `CombatantSnapshot.build_player / build_enemy / effective_stat`
- `StatMath.effective_stat(base, synergy_delta, aura_delta) -> int` — the only legal SYN-F4 site outside `CombatantSnapshot`

## Alternatives Considered

### Alternative B: Stat-service autoloads
- **Description**: `StatService`, `SynergyService`, `ProgressionService` as autoload singletons computing on demand; systems call them globally.
- **Pros**: Zero wiring — any system reaches stats from anywhere; familiar Godot idiom.
- **Cons**: Requires amending ADR-0004's fixed 10-autoload roster; global reachability defeats the DI/coverage mandate (spy sinks and test configs must be smuggled past singletons); state accumulates in autoloads against the thin-host stance; hidden coupling exactly like the `autoload_ready_work` rationale warns.
- **Rejection Reason**: Contradicts two registered stances (`boot_initialization` fixed roster, thin hosts) for zero architectural gain — the consumers of these objects are few and known (Workshop, TBC, UI screens), so injection is cheap.

### Alternative C: Node-based stat components
- **Description**: Stats as `Node` components (`StatsComponent`, `SynergyComponent`) attached to Symbot scenes; recompute driven by scene-tree signals.
- **Pros**: Engine-idiomatic for action games; visible in the editor; per-entity encapsulation.
- **Cons**: There is no per-entity scene — Symbots are data records the player edits in menus; nodes drag in tree lifecycle (ready order, freed-node races the project just spent ADR-0004 eliminating); GUT tests need a scene tree; per-node overhead for what is 88 integer multiplications.
- **Rejection Reason**: This is a data pipeline, not a simulation. Scene-tree semantics add lifecycle risk and test friction with no benefit for a turn-based, menu-driven game.

### Alternative (snapshot): plain-Dictionary battle snapshots
- **Description**: BATTLE_INIT builds `duplicate(true)` Dictionaries mirroring the save/signal-payload style.
- **Pros**: No new class; symmetric with ADR-0001 plain-data discipline.
- **Cons**: No compile-time field checking — a typo'd stat key returns a default silently; the SYN-F4 composition point has no natural home, inviting inline reimplementation; contract invisible to ADR-0007's author.
- **Rejection Reason**: The snapshot is a *runtime contract between two ADRs*, not serialized data — ADR-0001's plain-data rationale (schema-stable on disk) does not apply in memory; typed fields make the compiler enforce the contract (same argument that won in ADR-0003).

### Alternative (tuning): consts in formula classes / per-system tuning resources
- **Description**: `UPPER_SNAKE_CASE` consts beside each formula, or one small `.tres` per system.
- **Pros**: Consts: zero load-order concern. Per-system: finer merge granularity.
- **Cons**: Consts violate the written data-driven standard for genuinely tunable values (`DAMAGE_FLOOR`, XP curve, chassis tables are exactly what balancing retunes); per-system multiplies boot steps and leaves cross-system constants (`SYNERGY_POWER_BUDGET` spans Synergy + DF-1 + content validation) without a home.
- **Rejection Reason**: One `BalanceConfig` is one reviewable balance diff, one boot step, one validator section. `EPSILON` stays a code const because the GDD explicitly excludes it from tuning.

## Consequences

### Positive
- Every formula is a pure function testable against the GDDs' discriminating worked examples (DF-1 53/30→50-not-51; SYN cumulative 22-not-16; F2b −10-not-−11) with a spy LogSink
- SYN-F4 exists in exactly one place; the MOVE-F1-class seam defect is structurally prevented
- ADR-0007 receives a compiler-checked snapshot contract; enemy/player symmetry removes branching in damage resolution
- Balance retuning is a one-file `.tres` diff, validated at boot and in CI
- No new autoloads; every registered stance is satisfied, none amended

### Negative
- Constructor signatures carry `(cfg, log)` everywhere — mild ceremony compared to globals (accepted: it is the testability mandate's price)
- `BalanceConfig` is a merge hotspot if balancing and content work happen concurrently (accepted: MVP is solo-dev)
- Snapshot immutability is discipline + tests, not engine-enforced (GDScript has no frozen objects) — a rogue write compiles

### Risks
- **`battle_ended`-host seam (cross-ADR, pre-existing):** ADR-0002 §4 places `is_battle_active` on "the TBC autoload orchestrator", but ADR-0004's fixed roster of 10 contains no TBC entry. This ADR only *consumes* the signal (CP subscribes) and does not resolve the host. **ADR-0007 must place the TBC orchestrator** (persistent node under `Game` root, or an ADR-0004 roster amendment) and wire `CoreProgression.apply_battle_result` at construction. Mitigation: `apply_battle_result` is host-agnostic — it takes payload fields, not a reference to TBC.
- **Typed-dict `.tres` gate still open (ADR-0003):** if `Dictionary[StringName, int]` round-trip fails, `BalanceConfig`'s flat tables fall back to the same mitigation ADR-0003 chose for `PartDef` (paired arrays or String keys); the nested tables (`chassis_modifiers`, `type_chart`) additionally need the nested form chosen (composite String keys or per-archetype paired arrays — see Engine Compatibility). Mitigation: the gate test now covers both consumers before any content or balance authoring.
- **Snapshot copy semantics vs. future Resource fields:** `Dictionary.duplicate(true)` is correct and non-deprecated for the snapshot's plain-Dictionary fields. But `duplicate()` on **nested `Resource`s** is deprecated since 4.5 (`duplicate_deep()` is the replacement, and it exists only on `Resource`, not `Dictionary`). If any snapshot field is ever changed to a `Resource` subclass, its copy in `build_*` must switch to `duplicate_deep()` — do not blanket-apply either call across field types.
- **Silent snapshot mutation** (no engine freeze): mitigated by the isolation GUT test, no-setter construction, and review checklist; any future field addition must extend the deep-copy in `build_*` (test asserts field-count parity via `get_property_list`).
- **Divergent SYN-F4 reimplementation** despite the single point: registered as forbidden pattern `inline_stat_composition`; CI grep for `max(0,` / `maxi(0,` near `synergy` outside `StatMath`/`CombatantSnapshot` as a review aid.
- **BalanceConfig drift vs. GDD tables** (registry-transcription failure class, cf. 2026-07-10 DF-1 and 2026-07-13 signal-signature incidents): mitigated by ContentValidator asserting table shapes and a fixture test comparing `balance_config.tres` values against the GDD-quoted constants.

## GDD Requirements Addressed

| GDD System | Requirement (TR IDs) | How this ADR addresses it |
|------------|----------------------|---------------------------|
| symbot-assembly.md | SA-F1 sole executor; F2/F2b routing; chassis-then-floor; CP-F3 position; battle lock; atomic equip; pool orderings (TR-sa-001…004, 006…009) | `StatPipeline.derive` is the only SA-F1 implementation; `SymbotBuild.equip_part` atomicity; pools derived in fixed order; snapshot freeze |
| part-database.md | Formula 1/2/2b + epsilon discipline | `StatMath.floor_eps`/`ceil_eps` encapsulate the nudges; sign routing per Formula Pipeline |
| synergy-system.md | SYN-F1–F4; dedup keep-first; alphabetical registration; tier validation; preview purity; never-null contracts (TR-syn-001…010, 012, 013) | `SynergyMath` pure functions; `SynergyEvaluator` single-cache statefulness; `StatMath.effective_stat` as the SYN-F4 contract |
| symbot-core-progression.md | CP-F1 int lookup; cap; bench split + lead cap; equip gate; CORE-only growth; pipeline position; power-of-2 share (TR-cp-003…006, 008, 009, 011, 019, 020) | `ProgressionMath` + `CoreProgression` ledger; gate wired into `equip_part`; CP-F3 inside `StatPipeline.derive`; validator enforces power-of-2 |
| damage-formula.md | DF-1 purity, casts, ordering, floor, zero-guard (TR-df-001, 002, 004, 005, 006) | `DamageFormula.compute_damage` static, stateless, parameterized `crit_mult` |
| turn-based-combat.md | Snapshot at battle start, immutable; SYN-F4 both sides + frozen aura at BATTLE_INIT (TR-tbc-002, 012) | `CombatantSnapshot` deep-copy build; uniform `effective_stat` for player and enemy |

## Performance Implications

- **CPU**: `derive` is ~88 integer mul/floor ops + dictionary access — microseconds; runs once per equip and twice per Workshop hover (SA-F2 hypothetical + synergy preview). BATTLE_INIT builds 4 snapshots (3 player + 1 enemy): 4 `derive`-scale copies. Nothing runs per-frame. Negligible against the 16.6 ms budget.
- **Memory**: snapshots ≈ a few KB each, freed with the battle. `BalanceConfig` < 10 KB resident. Ledger: one small record per owned core.
- **Load Time**: +1 `.tres` load at boot step 2b (BalanceConfig) — immaterial next to six catalogs.
- **Network**: n/a.

## Migration Plan

Greenfield — no stat code exists. Implementation order inside the epic: `BalanceConfig` + validator section → `StatMath`/`StatPipeline`/`DamageFormula` (+ GUT suites from GDD fixtures) → `SynergyMath`/`SynergyEvaluator` → `ProgressionMath`/`CoreProgression` → `SymbotBuild` → `CombatantSnapshot`. Each stage is independently testable before the next begins.

## Validation Criteria

- GUT fixtures reproduce every GDD discriminating example: DF-1 (53, 30, 1.5) → 50 (round/ceil give 51); F2b base −15 tier ladder −15/−10/−5/0/0/0 including the 26 scan-identified load-bearing inputs; SYN worked example → energy_power 22 (highest-tier-only gives 16); CP-F1 exact threshold boundaries (2079→L9, 2080→L10); CP-F2 odd-N exactness (65→32)
- Purity tests: `preview`/`preview_swap` leave cache, signals, and inventory untouched; `compute_damage` reads no globals
- Isolation test: post-snapshot mutation of build/evaluator does not alter the snapshot (and vice versa); field-count parity guard
- Determinism test: synergy dedup + `active_synergies` order stable under shuffled content-file order (AC-SYN-05b String-cast sort)
- Validator tests: non-power-of-2 `bench_xp_share` rejected; non-monotonic `xp_thresholds` rejected; power-stat keys in `level_growth` rejected (AC-CP-22)
- Coverage: ≥ 80% on `src/core/stats/` and the Layer-2 owners
- Every new floor/ceil expression added during implementation gets a python3 IEEE-754 scan logged in the story evidence

## Related Decisions

- ADR-0001 — Save/Load (CP ledger persists via exploration-progress provider; plain-data discipline)
- ADR-0002 — Event Bus & Signals (signal style, LogSink, 8-field `battle_ended` contract this ADR consumes)
- ADR-0003 — Content Resources (`PartDef`/`EnemyDef` frozen instances; typed-dict gate shared)
- ADR-0004 — Scene & Boot (BootScreen constructs and injects; fixed roster honored)
- ADR-0007 (planned) — TBC state machine (consumes snapshot + damage contracts; must resolve the `battle_ended`-host seam)
- design/gdd/: symbot-assembly.md, part-database.md, synergy-system.md, symbot-core-progression.md, damage-formula.md, turn-based-combat.md
