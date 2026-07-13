# Symbots — Master Architecture

## Document Status
- **Version:** 1.0
- **Last Updated:** 2026-07-13
- **Engine:** Godot 4.6 / GDScript
- **Platforms:** macOS (launch) · iOS (primary long-term; touch-first)
- **GDDs Covered:** 19 approved MVP GDDs (Foundation/Core/Feature/World) + systems-index (25 MVP systems)
- **Requirements Baseline:** 148 technical requirements (TR-*), extracted 2026-07-13; see `docs/architecture/tr-registry.yaml` (to be populated by `/architecture-review`)
- **ADRs Referenced:** none yet — this document produces the 8-ADR work plan (0/148 TRs currently in ADRs)
- **Technical Director Sign-Off:** 2026-07-13 — **APPROVED WITH CONCERNS** (blueprint sound; the 4 Foundation ADRs — esp. ADR-0001 Save/Load — must be written + Accepted before coding; persistence budget + `battle_ended` disambiguation are the load-bearing decisions)
- **Lead Programmer Feasibility:** skipped — Lean review mode

---

## Engine Knowledge Gap Summary

Engine: **Godot 4.6** (Jan 2026). LLM training covers ~4.3; post-cutoff versions 4.4/4.5/4.6 carry HIGH-risk changes. **For this turn-based 2D game most HIGH-risk changes are 3D-only and do not apply.** The genuinely relevant risk surface:

| Domain | Risk | Relevance | Architectural implication |
|--------|------|-----------|---------------------------|
| **UI — dual-focus + AccessKit** (4.5/4.6) | HIGH | Workshop/Combat/Map UI, touch-first, iOS | Mouse/touch focus now separate from keyboard/gamepad focus; screen-reader via AccessKit. Constrains the UI-framework ADR + the "never color alone" accessibility commitment. |
| **Resources / serialization** (4.4/4.5) | HIGH | Save/Load, part instances, Inventory | `FileAccess.store_*` returns `bool` (was void); `duplicate_deep()` for nested resources; `Resource.duplicate()` is shallow. Directly shapes the Save/Load ADR. |
| **2D Navigation** (4.5) | MEDIUM | Overworld Navigation | Dedicated 2D nav server (smaller export). Low relevance for a turn-based game. |
| **GDScript** (`@abstract`, variadic, backtracing) (4.5) | LOW | project-wide | Additive, safe to adopt. |
| **Physics (Jolt default), 3D rendering, IK, visionOS** | — | **NOT APPLICABLE** | 2D physics unchanged; this game does no collision simulation. |

**Tooling note:** ripgrep has no `gdscript` type — `*.gd` is registered under `gap`. Always use `--glob "*.gd"`.

HIGH/MEDIUM-risk recommendations in this document are flagged inline with ⚠️.

---

## System Layer Map

```
┌───────────────────────────────────────────────────────────────────┐
│ PRESENTATION   Workshop UI · Combat UI · World Map UI ·            │  ← touch-first, AccessKit ⚠️
│                Main Menu & Settings · Audio System                 │
├───────────────────────────────────────────────────────────────────┤
│ FEATURE        Core Progression · Enemy AI · Drop · Inventory ·    │  ← gameplay features on Core
│                Encounter Zone · Zone & World Map · World Loot ·     │
│                Overworld Navigation · Workshop System              │
├───────────────────────────────────────────────────────────────────┤
│ CORE           Symbot Assembly · Synergy · Turn-Based Combat ·     │  ← stateful combat resolution
│                Part-Break                                          │
├───────────────────────────────────────────────────────────────────┤
│ FOUNDATION     Part DB · Move DB · Passive DB · Consumable DB ·    │  ← data schemas, pure formulas,
│                Enemy DB · Damage Formula (pure) ·                   │    persistence, event bus
│                Exploration Progress · Save/Load ·                   │
│                Event Bus · Content/Resource Loading               │
├───────────────────────────────────────────────────────────────────┤
│ PLATFORM       Godot 4.6 — Godot Physics 2D · CanvasItem 2D ·      │  ← engine + OS surface
│                FileAccess/Resource · Input · AudioServer · Mac/iOS │
└───────────────────────────────────────────────────────────────────┘
```

**Placement rationale:**
- **Foundation** holds the 5 content databases + Damage Formula (pure, stateless, read-only at runtime — the data/rules contract everything reads) plus the persistence contract (Exploration Progress + Save/Load) and the Event Bus (owns the dual-`battle_ended` disambiguation).
- **Core** holds the stateful combat-resolution systems: the Assembly stat-derivation pipeline, Synergy, the TBC battle orchestrator (owner of runtime Structure/Energy/Heat), and Part-Break.
- **Core Progression is Feature** (a support/pacing progression system) but exposes `can_equip`/`is_build_valid` that Core (Assembly) and Feature (Workshop) call at equip/battle-start time — an **upward-call boundary** handled in API Boundaries.
- **Presentation** systems are all consumers of read-APIs + signals from lower layers; all Not Started, correctly deferred (mechanics-first).

**Engine-risk flags on Core/Foundation systems:**
- Save/Load + Exploration Progress + Inventory (Foundation) → **Resources/serialization HIGH** ⚠️
- No Core/Foundation system touches physics, 3D rendering, or IK.

---

## Module Ownership

Format: **Owns** (sole responsibility for data/state) · **Exposes** (public read/call surface) · **Consumes** (reads from others) · **Engine APIs** (⚠️ = post-cutoff / HIGH risk).

### Foundation Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|-------------|
| **Content DBs** (Part/Move/Passive/Consumable/Enemy) | `.tres` catalogs, immutable at runtime | `get_part(id)` / `get_move(id)` / … → typed `Resource`; base drop-rate config | — (root) | `Resource`, `ResourceLoader`, `.get()` for optional keys |
| **Damage Formula** | nothing (pure) | `compute_damage(A, dmg_type, elem, D, target_elem, crit) → int` — stateless/injectable | Part DB type chart | — (pure GDScript; `float()` casts binding) |
| **Exploration Progress** | save-blob *semantics*: domain registry (`&"zones"`/`&"cores"`/`&"world_loot"`), version predicate, two-phase restore | `serialize() → {ok, blob\|failed_domain}`, `restore(blob)`, domain registration | each domain's `snapshot()/restore()/rederive()`; injected warning sink | — |
| **Save/Load** (#17) | file format/encoding, slots, timing, disk I/O; serializes non-progression state (Inventory + `next_instance_id` + Scrap, Workshop builds, Drop pity, Settings) | `save(slot)`, `load(slot)` | EP `serialize/restore`; Inventory/Workshop/Drop snapshots | ⚠️ `FileAccess.store_*` (returns `bool` in 4.6), `FileAccess`, `Resource.duplicate_deep()` for nested |
| **Event Bus** | signal routing; the **two distinct `battle_ended` shapes** | named signals (autoload) | — | `Signal`, autoload singleton |

### Core Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|-------------|
| **Symbot Assembly** | `SymbotBuild` (8-slot manifest + `final_stat`) | `equip_part()`, `get_final_stat()`, `SA-F2` preview; emits `part_equipped`, `stats_changed` | Part DB; `CoreProgression.can_equip` (upward); Synergy tags | `Resource`, `Dictionary`, `floor()` + epsilon |
| **Synergy** | single `cached_bonus_block` (never null) | `evaluate(parts)` (emits `synergy_changed`), `evaluate_silent(parts)` (no emit), `preview()` | Part DB synergy tags | `String(tier_id)` sort ⚠️ (StringName intern trap) |
| **Turn-Based Combat** | runtime `current_structure/energy/heat` per combatant; battle FSM; region break pools | 8-field `battle_ended`, `hit_resolved`, `battle_start_refused`, `is_battle_active()` | Assembly snapshot, Synergy `evaluate_silent`, DF-1, Enemy AI `request_move`, Part-Break | `Signal` (synchronous emit), `RandomNumberGenerator` (injected for status procs) |
| **Part-Break** | battle-local region break pools (no persistence) | `<region>_broken` events into TBC's fired set | `hit_resolved` accumulator; EDB-1 `break_hp` | pure int/`floor` |

### Feature Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|-------------|
| **Core Progression** | `CoreProgressionRecord` (per core) | `can_equip`, `is_build_valid`, `register_core`, `core_leveled_up` | 8-field `battle_ended`; injected logger | `Dictionary`, pure int/`floor` |
| **Inventory** | `part_instances`, `consumables`, `scrap`, `next_instance_id` (monotonic) | `add() → {accepted, rejected}`, `scrap_part`, read APIs | Part DB metadata; Workshop equipped-set (for scrap guard) | `Resource`, int keys (never String-coerced) |
| **Drop System** | pity maps (per-Prototype, per-Boss-grade) | rolled `PartInstance`s → Inventory `add()`; consumable channel | 8-field `battle_ended`; injected seeded RNG; DS-1 factors | ⚠️ `RandomNumberGenerator` (injected seed) |
| **Enemy AI** | nothing (pure per call) | `request_move(battle_state) → Move`, `has_profile(id)` | DF-1 preview (pure); `AI_PROFILE_WEIGHTS` `.tres` | `RandomNumberGenerator` (injected seed) |
| **Encounter Zone** | spawn tables, gate semantics | EZ-1 step trigger, EZ-2 selection, gate-check | injected seeded RNG; ZWM `win_count`/`boss_progress` | `RandomNumberGenerator` |
| **Zone & World Map** | `ZoneRuntimeState` (`win_count`, `boss_progress`) | `zone_states_changed`, `zone_entered`, `can_travel`, `enter_zone` | relayed **2-field** `battle_ended(result, encounter_type)` | graph BFS (pure) |
| **World Loot** | runtime collected-set (`&"world_loot"` domain) | `collect(loot_id)`, `get_node_state`, `node_collected` | LootNode catalog; Inventory `add()`; injected error sink | `Resource`, StringName keys |
| **Overworld Navigation** (#16) | encounter-modifier state; **computes `is_first_boss_defeat` + `encounter_type`** | relays the 2-field `battle_ended`; hands `is_first_boss_defeat` to TBC pre-battle | ZWM `defeated_once`; EZ triggers | — (Not Started) |
| **Workshop System** (#15) | active-build set, equipped-set | equip/unequip routing, build compare | Assembly, Inventory, CP gate | — (Not Started) |

### Presentation Layer (all Not Started — consume read-APIs + signals)

| Module | Consumes |
|--------|----------|
| **Workshop UI / Combat UI / World Map UI / Main Menu / Audio** | `stats_changed`, `core_leveled_up`, `can_equip` result, `battle_ended` (combat), `hit_resolved`, `zone_states_changed`, `is_battle_active`; touch-first ⚠️ (dual-focus, AccessKit) |

### Dependency diagram (ASCII)

```
Presentation ──read/subscribe──▶ Feature ──▶ Core ──▶ Foundation ──▶ Platform
    (UI/Audio)                     │           │          │
                                   └──────upward gate call: Assembly ─▶ CoreProgression.can_equip
   Event Bus (Foundation) ◀── all layers publish/subscribe named signals
   Save/Load (Foundation) ◀── serializes: Inventory, ZWM, CoreProgression, WorldLoot, Drop pity, Workshop, Settings
```
The only non-downward edge is **Assembly → Core Progression** (`can_equip`, an upward gate query from Core into Feature); it is a stateless call and does not create a cycle (Core Progression consumes only the `battle_ended` event, never Assembly state).

---

## Data Flow

### 1. Turn resolution (frame/turn update path)
```
Player input (touch) ─▶ Combat UI ─▶ TBC FSM (ACTION_PENDING)
   TBC uses the BATTLE-START LOCKED SNAPSHOT (final_stat + frozen synergy block):
      SYN-F4 (effective stats) ─▶ DF-1 (pure, injected) ─▶ MOVE-F1 (power tier) ─▶ TBC-F5 (Stagger)
   ─▶ hit_resolved(move, damage, target, sub_target) ─▶ Part-Break (PB-F1/F3 spillover, TBC-F7 enrage)
   ─▶ mutate runtime Structure/Energy/Heat (TBC-owned) ─▶ Combat UI signals
```
Producer→consumer are **synchronous calls**; DF-1 and Enemy AI reads are pure (no shared-state mutation). No thread boundaries.

### 2. Event / signal path (the `battle_ended` seam)
```
TBC ──emit(SYNCHRONOUS)──▶ battle_ended(VICTORY, enemy_id, fired_break_events, xp_value,
                                         completion_bonus_xp, is_first_boss_defeat,
                                         enemy_level, deployed_symbot_ids)   [8-field COMBAT signal]
        ├─▶ Core Progression   (XP award; folds boss bonus iff is_first_boss_defeat)
        └─▶ Drop System        (loot payout; reads fired_break_events + still-live break pools)
        runtime state discarded ONLY AFTER all subscribers return; ordering NOT relied upon.

Overworld Navigation ──emit──▶ battle_ended(result, encounter_type)          [2-field WORLD signal]
        ├─▶ Zone & World Map   (win_count++ on WIN/WILD; boss flags)
        └─▶ Encounter Zone     (gate re-eval)
```
⚠️ **These two signals share the name `battle_ended` but have different shapes.** ADR-0002 must make them contractually distinct (rename one, or namespace via the Event Bus) so a subscriber can never bind the wrong payload. This is the single highest-risk seam for architecture to lock in badly.

### 3. Save / load path
```
SAVE:  event-boundary quiesce point ─▶ Save/Load.save(slot)
         ─▶ EP.serialize() ─▶ per-domain snapshot() (pure read) ─▶ {domain_key: blob} + progress_format_version
         ─▶ + non-progression state (Inventory + next_instance_id + Scrap, Workshop builds, Drop pity, Settings)
         ─▶ FileAccess.store_* (⚠️ returns bool — check it)   [a non-Dictionary snapshot REFUSES the save, never partial-corrupt]

LOAD:  Save/Load.load(slot) ─▶ EP-PRED-1 version predicate (== RESTORE / < MIGRATE / > or bad REFUSE)
         ─▶ Phase 1 raw restore(data) (NO cross-domain reads)
         ─▶ Phase 2 rederive() (domain-local: ZWM zone states, CoreProgression level from cumulative_xp)
         [REFUSE leaves all in-memory state unchanged; unknown domain keys preserved opaquely via duplicate(true)]
```
State that serializes (**source facts only**): `win_count`/`boss_progress`, `CoreProgressionRecord.cumulative_xp`, `part_instances` + `next_instance_id` + `scrap` + `consumables`, collected `world_loot` IDs, Drop pity maps, Workshop builds, Settings. **Derived state is never trusted from disk** (zone LOCKED/ACCESSIBLE/CLEARED, core `level`).

### 4. Initialization order
```
Platform (Godot autoloads) ─▶ Content DBs load (.tres, immutable) ─▶ Event Bus + RNG service + Save/Load (autoloads)
   ─▶ EP.restore(blob) [Phase 1 raw] ─▶ rederive() [Phase 2: zone states via ZWM-F2, core levels via CP-F1]
   ─▶ gameplay systems boot against restored+derived state
```
DBs must be fully loaded before any system that reads them; EP restore must complete before any derived state is computed.

---

## API Boundaries

The public contracts programmers implement against. Pseudocode in GDScript-flavored signatures.

### Damage Formula (Foundation — pure)
```gdscript
# Stateless. MUST use float() casts (int/int truncates); T applied before the single floor().
static func compute_damage(A:int, damage_type:int, element:int, D:int,
                           target_core_element:int, crit_mult:float=1.0) -> int
# Invariant callers respect: A∈[0,150], D∈[0,182]. Guarantee: returns ≥ DAMAGE_FLOOR(1); deterministic.
```

### Symbot Assembly (Core)
```gdscript
func equip_part(build:SymbotBuild, slot:int, part_id:StringName) -> Dictionary  # {ok, error?}
func get_final_stat(build:SymbotBuild) -> Dictionary                            # 11 int stats (locked in combat)
func preview_swap(build, slot, candidate_part_id) -> Dictionary                 # SA-F2 delta, NO signals/writes
# Guarantee: final_stat computed as SA-F1 → CP-F3 → SYN-F4 order (ADR-0005). Equip calls CoreProgression.can_equip first.
signal part_equipped(slot_type:int, new_part_id:StringName)
signal stats_changed(final_stat:Dictionary)
```

### Core Progression (Feature — exposes an UPWARD gate query)
```gdscript
func can_equip(core_instance_id:int, part) -> bool          # level_requirement gate (Rule 4/5)
func is_build_valid(build) -> bool                          # ∀ equipped parts can_equip
func register_core(core_instance_id:int) -> void           # idempotent; warns on duplicate (injected logger)
# Consumes battle_ended (8-field); awards XP; folds completion_bonus_xp iff is_first_boss_defeat.
signal core_leveled_up(core_id:int, old_level:int, new_level:int)   # once, spanning, on threshold cross
```

### Turn-Based Combat (Core)
```gdscript
func start_battle(builds, enemy_id, is_first_boss_defeat:bool) -> void   # refuses invalid builds (AC-TBC-42)
func is_battle_active() -> bool
# Guarantee: reads a LOCKED snapshot at BATTLE_INIT; runtime Structure/Energy/Heat owned here, discarded post-emit.
signal battle_ended(outcome, enemy_id, fired_break_events:Dictionary, xp_value:int,
                    completion_bonus_xp:int, is_first_boss_defeat:bool,
                    enemy_level:int, deployed_symbot_ids:Array)   # 8-field COMBAT — distinct from the world relay
signal hit_resolved(move, damage:int, target, sub_target)
signal battle_start_refused(invalid_symbot_ids:Array, offending_parts:Array)
```

### Exploration Progress + Save/Load (Foundation)
```gdscript
# EP owns blob semantics; Save/Load owns file I/O.
func EP.serialize() -> Dictionary            # {ok:true, blob} | {ok:false, failed_domain, error}
func EP.restore(blob:Dictionary) -> void     # two-phase; REFUSE leaves in-memory state untouched
func EP.register_domain(key:StringName, provider)   # provider: snapshot()/restore()/rederive()
# Each domain provider contract:
func snapshot() -> Dictionary                # pure read, no side effects
func restore(data:Dictionary) -> void        # Phase 1: raw, NO cross-domain reads
func rederive() -> void                      # Phase 2: domain-local recompute
```

### Event Bus (Foundation)
```gdscript
# ADR-0002 decides direct-signals vs central bus. Whichever: the two battle_ended shapes MUST be
# distinguishable by name or namespace so no subscriber can bind the wrong payload.
# All content warnings/errors route through an INJECTED logger/sink (never global push_warning/push_error) — GUT testability.
```

### Injected RNG (Feature/Core — determinism)
```gdscript
# Drop / Enemy AI / Encounter Zone: fresh RandomNumberGenerator per pass, seeded from an injected int.
# NEVER call global randf(). Pity checked BEFORE the RNG draw (guaranteed drop skips the draw → no stream desync).
```

---

## ADR Audit

**No ADRs exist yet** — `docs/architecture/` contains only the empty `tr-registry.yaml` template. There is therefore nothing to audit for engine-compatibility or conflicts, and **all 148 technical requirements are currently traceability gaps**. Every gap is covered by one of the 8 Required ADRs below (full TR→ADR mapping is populated by `/architecture-review` into `tr-registry.yaml`).

Traceability summary: **0 covered / 148 gaps** → 8 Required ADRs.

---

## Required ADRs

Priority: **Foundation ADRs must be Accepted before any coding**; Core ADRs before those systems are built; Presentation ADR before UI systems.

### Must have before coding starts (Foundation)

**ADR-0001 — Save/Load architecture & serialization format** ⚠️ *Resources/serialization HIGH*
Generalize Exploration Progress's domain-registered envelope (two-phase order-independent restore, EP-PRED-1 version predicate, source-vs-derived re-derivation, opaque unknown-key preservation) to the **whole save file** so Workshop builds + Drop pity + Settings slot in without a format bump. **First deliverable: one enumerated durable-state manifest.** Decide `.tres` vs custom binary/JSON; verify Godot 4.6 `FileAccess.store_*` bool return + `duplicate_deep()` for nested resources; **set a persistence budget (max blob size, max save-write time on iOS)** against the 512MB ceiling and uncapped part instances. Covers TR-ep-001…012, TR-cp-001, TR-inv-001/005, TR-zwm-002, TR-drop-003, TR-wl-002, TR-perf-002, TR-eng-001.

**ADR-0002 — Event bus & signal architecture**
Direct Godot signals vs a central event-bus autoload. **Resolve the `battle_ended` dual-signal seam** (the 8-field combat signal vs the 2-field Overworld-Nav world relay) by making them contractually distinct (rename one, or namespace). Specify the synchronous-emit teardown-ordering contract (state discarded only after all subscribers return; no inter-subscriber ordering dependency) and the project-wide **injected-logger/sink** pattern (never global `push_*`). Covers TR-tbc-004/005, TR-cp-006/007/008, TR-drop-004, TR-zwm-004/005, TR-ez-004, TR-ep-011, TR-wl-004.

**ADR-0003 — Content resource loading & schema mapping**
GDD schemas → Godot `Resource` classes (`.tres`), read-only at runtime. Define the schema-to-resource mapping, the reserved-null-field convention (post-MVP extensibility), and the **content-validation gate** (stored-equals-derived invariants for `xp_value`/`break_hp`; break-vocabulary match Drop↔Part-Break; rarity gate floors; `level_growth` guards). Covers TR-part-001/002/004, TR-edb-001/002/003, TR-mdb-001…004, TR-pdb-001/002, TR-cdb-001, TR-wl-001, TR-eai-003.

**ADR-0004 — Scene management & boot / initialization order**
Autoload/singleton strategy for Foundation services (DBs, Event Bus, RNG, Save/Load); scene graph (Main Menu → Overworld → Battle → Workshop) and transition ownership; the boot order (DBs load → autoloads → EP restore → derive → gameplay). Covers the init-order TRs + TR-ep-004.

### Should have before the relevant Core system is built

**ADR-0005 — Stat-derivation pipeline & combat snapshot** *(load-bearing ordering)*
Codify the **SA-F1 → CP-F3 → SYN-F4** order (AC-SA-15/AC-CP-18 discriminator: 160 ≠ 168; CP-F3 bypasses the chassis multiplier) and the **battle-start locked snapshot** (`final_stat` + `evaluate_silent()` frozen bonus block; combat-lock contract — no equip mid-battle). Covers TR-sa-002/003/006/007, TR-cp-003, TR-syn-001/003, TR-tbc-002/006, TR-df-001.

**ADR-0006 — RNG & determinism strategy**
Standardize **injected-seed + fresh `RandomNumberGenerator` per pass** (never global `randf()`); the **pity-before-roll** stream-preservation rule; DF-1 purity/injectability (Enemy AI determinism depends on it); the float/epsilon-scan discipline (python3 scan every new floor/ceil formula). Covers TR-df-001/002/003, TR-drop-001/002, TR-eai-001/002, TR-ez-002/003, TR-test-001.

**ADR-0007 — TBC state machine & runtime-state ownership**
The battle FSM (BATTLE_INIT → ROUND_START → ACTION_PENDING → … → BATTLE_END); TBC as sole owner of runtime Structure/Energy/Heat + battle-local region pools; the per-hit pipeline and `hit_resolved` routing to Part-Break; `battle_start_refused` on invalid builds. Covers TR-tbc-001/003/006/007/008/009, TR-pb-001…004.

### Should have before the Presentation layer is built

**ADR-0008 — Touch-first UI framework & input** ⚠️ *UI HIGH (dual-focus, AccessKit)*
Godot `Control`-node strategy; the 4.6 dual-focus model (mouse/touch focus separate from keyboard/gamepad); 44×44pt tap targets, no hover-only affordances; the AccessKit accessibility approach + "never color alone" palette alternatives (coordinate with the art bible); the read-API/signal consumption pattern UI uses. Covers TR-ui-001/002, TR-sa-005, TR-cp-007, TR-syn-002, TR-zwm-004.

### Missing-ADR priority summary
- **Before coding:** ADR-0001, ADR-0002, ADR-0003, ADR-0004 (Foundation)
- **Before the Core system:** ADR-0005, ADR-0006, ADR-0007
- **Can defer to just before Presentation:** ADR-0008

---

## Architecture Principles

1. **Data-driven, read-only-at-runtime content.** All gameplay values live in Godot `Resource` (`.tres`) catalogs loaded at boot and never mutated at runtime. Code reads the data contract; it never hardcodes balance values. (technical-preferences; TR-part-004)
2. **The registry is the interface contract.** `design/registry/entities.yaml` (48 constants, 34 formulas) is the authoritative cross-system contract; ADRs and code derive from it. Formula ordering and epsilon behavior are load-bearing and python3-scanned — never "clean up" a `floor(... + 0.0001)` without a scan.
3. **Source facts persist; derived state re-derives.** Only irreducible facts are serialized (counters, flags, cumulative XP, collected IDs, instances). Everything computable (zone states, core levels, `final_stat`) is recomputed on load and never trusted from disk. Saves survive formula retunes.
4. **Determinism by injection.** Combat math is pure (no RNG inside DF-1). Stochastic systems take an injected seed + a fresh `RandomNumberGenerator` per pass; no global `randf()`. This makes every system unit-testable and replay-stable.
5. **Explicit, shape-typed events; injected logging.** Systems communicate via named signals with fixed payload shapes (the two `battle_ended` signals are distinct contracts, not one overloaded name). All diagnostics route through an injected logger/sink so tests can assert on them.
6. **Locked combat snapshot.** Combat reads a frozen copy of `final_stat` + synergy block taken at battle start; the Workshop is the only writer of build state and is disabled during combat. No build mutation mid-battle.

---

## Open Questions

| ID | Summary | Priority | Resolution path |
|----|---------|----------|-----------------|
| QQ-01 | Save-file format (`.tres` vs binary vs JSON) + the single durable-state manifest + iOS serialization budget | **High** | ADR-0001 |
| QQ-02 | `battle_ended` dual-signal disambiguation (rename vs namespace) — the highest-risk seam | **High** | ADR-0002 |
| QQ-03 | Central event-bus autoload vs direct node signals | High | ADR-0002 |
| QQ-04 | Uncapped part-instance count vs 512MB ceiling — soft cap? on-disk compaction? | High | ADR-0001 (budget) |
| QQ-05 | `is_first_boss_defeat` + `encounter_type` provenance lives in Overworld Navigation (#16, Not Started) — must supply both to TBC pre-battle | Medium | Overworld Nav GDD + ADR-0002 |
| QQ-06 | Scrap sink (Part Upgrade #26 / Workshop #15) is Not Started but its economy is a binding constraint on those GDDs | Medium | Workshop/Part-Upgrade GDDs; treat Drop cost curve as binding |
| QQ-07 | AccessKit accessibility approach + colorblind palette alternatives (coordinate with art bible) | Medium | ADR-0008 + `/art-bible` |
| QQ-08 | enemy-ai `H_cur` range annotation `[1,594]` stale vs leveled-core 612 (heuristic input; cosmetic) | Low | light enemy-ai.md touch |
