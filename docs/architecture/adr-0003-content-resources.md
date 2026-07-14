# ADR-0003: Content Resource Loading & Schema Mapping

## Status
Accepted (2026-07-13, via `/architecture-review` follow-up — review report `architecture-review-2026-07-13.md`).
**Acceptance does NOT waive the verification gate**: Engine Compatibility → Verification Required item (2) (`Dictionary[StringName, int]` `.tres` round-trip) must still pass before any content authoring begins; a failed gate triggers the documented fallback via explicit ADR amendment.

## Date
2026-07-13

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Resources (content pipeline) |
| **Knowledge Risk** | MEDIUM overall, **HIGH for the typed-dictionary export surface** — `Dictionary[StringName, int]` `@export` inspector authoring and `.tres` round-trip are post-cutoff and UNVERIFIED (keys may deserialize as `String` not `StringName`; typed-dict `.get()` may return `Variant`). The read-only-content posture avoids the other high-risk surface (runtime Resource re-serialization, routed around by ADR-0001) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` |
| **Post-Cutoff APIs Used** | Typed dictionaries `Dictionary[StringName, int]` as `@export` fields (Godot 4.4+); awareness-only: `duplicate_deep()` (4.5) — deliberately NOT used (defs are never duplicated) |
| **Verification Required** | **Gate: item (2) must pass BEFORE any content authoring begins.** (1) Exported-build (Mac + iOS) load of all 6 catalogs — confirm no directory scanning anywhere in the load path; (2) `@export var x: Dictionary[StringName, int]` authors correctly in the 4.6 inspector, round-trips through `.tres` with keys still `StringName` (not `String`-coerced), and typed-dict `.get()` returns the value type usable under a typed function return; (3) nested entry Resources (BreakRegionDef inside EnemyDef) load intact from a catalog reference chain |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (**Accepted 2026-07-13** — saves reference content by ID only; `live_resource_in_save_snapshot` is forbidden); ADR-0002 (**Accepted 2026-07-13** — validation gate reports through the injected LogSink; `global_push_diagnostics` is forbidden) |
| **Enables** | ADR-0004 (boot order: catalogs load before any consumer autoload); ADR-0005 (stat pipeline reads `PartDef` fields); content authoring can begin once this ADR is Accepted |
| **Blocks** | All 6 database implementation epics (Part/Enemy/Move/Passive/Consumable/World-Loot); any story that reads content data |
| **Ordering Note** | Third of the four Foundation ADRs. ADR-0004 finalizes autoload wiring; this ADR fixes the catalog format, class shapes, and validation gate that ADR-0004 sequences. |

## Context

### Problem Statement
Nineteen approved GDDs externalize every gameplay value into six content catalogs (Part ~40–60 entries, Enemy ~10, Move ~8–12, Passive 3+, Consumable 8, World Loot ~6–10 per zone). The coding standard is absolute: *"Gameplay values must be data-driven (external config), never hardcoded."* We must decide how these catalogs are authored, stored on disk, loaded at boot, schema-validated, and exposed read-only at runtime — before any database epic can start.

The catalogs are not independent: the GDDs define **12+ referential-integrity constraints** (Part→Move, Part→Passive, Enemy→Part loot pools, break-event↔drop-condition vocabulary matching, World-Loot→Part/Consumable payloads), **4 stored-equals-derived invariants** (`break_hp` via EDB-1, `xp_value` via CP-F4 — both stored AND derivable, must match), **rarity-gated nullability rules** (Part DB Rule 8), and **economy guardrails** (`buy_price > sell_price` BLOCKING, `WORLD_SCRAP_CEILING`, `loot_id` global uniqueness fatal-at-load). A content pipeline that loads without validating these invariants ships authoring bugs straight into combat math.

### Constraints
- **Registry (locked stances)**: `live_resource_in_save_snapshot` forbidden (ADR-0001) — saves store content **IDs**, never defs; `global_push_diagnostics` forbidden (ADR-0002) — validator reports via LogSink; `save_serialization` = JSON applies to **player data only** — content format is decided here and the two must not be conflated.
- **Engine**: Godot 4.5 changed `Resource.duplicate()` to shallow for nested resources (`duplicate_deep()` is the explicit deep API). In exported PCKs, `.tres` resources get companion `.remap` stubs; `DirAccess` listing returns only the stub names, so `*.tres` pattern scans fail silently post-export. `ResourceLoader.load()` resolves remaps transparently — only directory *listing* breaks, which is why the catalog reference chain is export-safe.
- **Platform**: iOS is the primary long-term target; boot-time work must stay trivial (it is: ~130 records total).
- **Coverage mandate**: 80% unit-test coverage for game logic — content lookups must be type-safe and validation must be assertable in GUT.

### Requirements
- Must map every GDD schema (fields, enums, nullability, reserved fields) onto typed, inspector-authorable structures. (TR-part-001/002/004, TR-edb-001/002/003, TR-mdb-001…004, TR-pdb-001/002, TR-cdb-001, TR-wl-001)
- Must expose read-only, O(1)-by-ID lookup to all consumers, including Enemy AI's `ai_profile` resolution. (TR-eai-003)
- Must run the content-validation gate where errors are actionable (CI) and where developers author (dev boot).
- Must support post-MVP schema extension without a format bump (reserved-null-field convention).

## Decision

**Content is authored as typed `.tres` Resource entries, shipped through one explicit catalog Resource per database, loaded at boot into read-only DB singletons, and validated by a DI-testable ContentValidator that blocks CI and fail-louds dev boots.**

### 1. Typed Resource classes (one per entity)

Each GDD entity becomes a `class_name` script extending `Resource`, with every field `@export`ed and statically typed:

| Class | Source GDD | Notes |
|-------|-----------|-------|
| `PartDef` | part-database.md | 11-stat `stat_bonuses: Dictionary[StringName, int]`; `active_skill_id`/`passive_id` as `StringName` (`&""` = null-equivalent); `level_growth` non-empty only on CORE parts |
| `EnemyDef` | enemy-database.md | `break_regions: Array[BreakRegionDef]` (nested Resource); stored `xp_value` + `break_hp` validated against CP-F4 / EDB-1 |
| `BreakRegionDef` | enemy-database.md | Nested: `region_id`, `region_fraction`, `break_hp`, `break_event` |
| `MoveDef` | move-database.md | `power_tier` required iff `behavior == DAMAGE`; `target_profile` reserved-null |
| `PassiveDef` | passive-database.md | `behavior_params: Dictionary` shape-checked per `behavior_class` by the validator |
| `ConsumableDef` | consumable-database.md | `buy_price`/`sell_price` authored now, inert in MVP (no shops) |
| `LootNodeDef` | world-loot.md | `loot_id` globally unique (fatal); `reward_payload: Dictionary` shape-checked per `reward_type` |

Enums are GDScript `enum`s declared on the def class (e.g. `PartDef.SlotType`), giving the inspector dropdowns and code compile-time names. **`.tres` stores enum values as raw integers**, so every content enum uses explicit values starting at 1 (`WEAPON = 1, ARMOR = 2, …` — 0 stays reserved/invalid to catch stale defaults) and values are **append-only: never reorder or insert**, or every already-authored `.tres` silently corrupts.

Nested Resources (`BreakRegionDef` inside `EnemyDef`) are stored **inline** in the parent entry's `.tres` — never saved as external files — so an enemy's full definition diffs in one file. Cross-DB references are `StringName` IDs — **never direct Resource references across catalogs** — so each catalog stays independently loadable and saves can store the same IDs (ADR-0001).

**Convention — empty StringName as null:** GDScript `@export` cannot express `StringName | null`. The project convention is `&""` = "no reference"; the validator enforces the rarity-gated nullability rules (e.g. Common parts MUST have `&""` for `active_skill_id`; Rare+ non-CORE MUST NOT). Each nullable field carries a doc comment on the def class stating that empty means "none" — the inspector shows authors a blank text box, and without the comment blank reads as "bug".

### 2. Catalog Resource per DB (explicit manifest, no directory scanning)

```text
assets/data/
├── catalogs/
│   ├── part_catalog.tres        # PartCatalog (entries: Array[PartDef])
│   ├── enemy_catalog.tres       # EnemyCatalog (entries: Array[EnemyDef])
│   ├── move_catalog.tres        # ... one per DB, 6 total
│   └── ...
├── parts/part_vulcan_arm.tres   # individual entries, referenced BY the catalog
├── enemies/enemy_rust_hound.tres
└── ...
```

Each catalog class is trivial: `class_name PartCatalog extends Resource` with `@export var entries: Array[PartDef]`. Adding an entry = create the `.tres` + add it to the catalog array (the catalog IS the explicit manifest of what ships — an entry not in the catalog does not exist, which makes "what's in the build" reviewable in one diff).

**Directory scanning is forbidden in the content load path.** `DirAccess`-based discovery breaks in exported PCKs (`.tres` → `.remap` renaming); the catalog reference chain is resolved entirely by `ResourceLoader` and is export-safe by construction.

### 3. DB singletons: load, index, expose read-only

Each database is an autoload (`PartDB`, `EnemyDB`, `MoveDB`, `PassiveDB`, `ConsumableDB`, `WorldLootDB` — final wiring and load order in ADR-0004) that at boot:

```gdscript
# part_db.gd — sketch of the load/index/expose contract
var _by_id: Dictionary[StringName, PartDef] = {}

func load_catalog(catalog: PartCatalog, log_sink: LogSink) -> bool:
    for def in catalog.entries:
        if def == null:                     # stale/deleted catalog slot = fatal
            log_sink.error(&"content_null_entry", {"db": &"part"})
            return false
        if _by_id.has(def.id):
            log_sink.error(&"content_duplicate_id", {"db": &"part", "id": def.id})
            return false                    # duplicate ID within a catalog = fatal
        _by_id[def.id] = def
    return true

func has_part(id: StringName) -> bool:      # guard for the null contract below
    return _by_id.has(id)

## Returns null for an unknown id — callers MUST null-check (or guard with has_part()).
## The typed annotation does NOT protect against null: GDScript object types are nullable,
## so `-> PartDef` compiles and runs while silently delivering null to the caller.
func get_part(id: StringName) -> PartDef:
    return _by_id.get(id)
```

**Script parse gate:** all `class_name` def scripts must parse cleanly before the DB autoloads initialize — a parse-broken def script silently fails class registration and surfaces as misleading type errors at catalog load, not as "class not found". CI runs a parse pass (headless script check / GUT discovery) before the content suite.

`load_catalog` takes the catalog and LogSink as **parameters** (dependency injection) so GUT tests exercise the same code path with fixture catalogs — no autoload coupling in the logic (coding standard: DI over singletons; the autoload is a thin host).

### 4. Read-only contract — defs are frozen shared instances

Lookups return **the shared def instance**. Consumers must treat defs as immutable:

- **Mutating a content def at runtime is forbidden** (registered as a forbidden pattern), **and the ban explicitly covers calling `duplicate()` or `duplicate_deep()` on any def or catalog.** `duplicate()` (shallow for nested resources since 4.5) returns a copy whose nested `BreakRegionDef`s are still shared — treating it as a safe working copy IS the mutation trap; `duplicate_deep()` would work but is wasted per-lookup allocation on iOS and legitimizes a copy-then-mutate habit. There is no defensive copying on lookup: frozen-shared + a banned pattern is cheaper and testable.
- Systems needing mutable working state **copy specific fields into their own runtime structures** (e.g. the battle-start locked snapshot, ADR-0005; runtime part *instances* referencing their def by ID, ADR-0001's inventory provider). Runtime state never lives on a def.
- Saves store `StringName` IDs only — a def entering a save snapshot is already forbidden by ADR-0001's `live_resource_in_save_snapshot`.

### 5. Content-validation gate — CI-blocking + dev-boot check

A single `ContentValidator` (plain `RefCounted`, fully DI: takes all 6 loaded catalogs + a LogSink) produces a structured report `{ok: bool, errors: Array[Dictionary], warnings: Array[Dictionary]}`. Validation families (from the GDD acceptance criteria):

| Family | Checks | Severity |
|--------|--------|----------|
| Referential integrity | Part→Move / Part→Passive / Enemy.skills→Move / Enemy.loot_pool→Part / WorldLoot payload→Part/Consumable all resolve | ERROR |
| Stored-equals-derived | `break_hp == max(5, floor(structure × region_fraction + 0.0001))` (EDB-1, epsilon load-bearing); `xp_value == (35 + level×10) × role_mult` (CP-F4) | ERROR |
| Vocabulary matching | every `break_event` matches ≥1 `drop_conditions[].condition` in that enemy's loot pool (EDB-3); condition names match Part-Break event names exactly | ERROR |
| Rarity gates & nullability | `level_requirement` ≥ rarity floor (1/3/6/8); `active_skill_id`/`passive_id`/`upgrade_effects` nullability per Part DB Rule 8 (incl. the CORE exception); `power_tier` required iff DAMAGE | ERROR |
| Range & power caps | enemy stats ∈ [0,110]; WILD power ≤ 39 (anti-one-shot); part `stat_bonuses` ∈ [−55,110]; Recharge only on Energy Cell + Core | ERROR |
| Economy & composition | `buy_price > sell_price` strict; per-zone SCRAP sum ≤ `WORLD_SCRAP_CEILING` (180); `loot_id` globally unique; ≥1 PART node per zone; WILD `loot_pool.size() > break_regions.size()`; boss-grade break guarantee (rate × mult ≥ 0.5) | ERROR |
| MVP-legality of reserved fields | `tier == 1`; no `BLUEPRINT` reward nodes; no BOSS_GRADE consumables; Core parts carry no `SKILL_UNLOCK` | ERROR |
| Calibration bands | TTK bands per AC-ED-14 (WILD-early 2–4 turns, BOSS 12–18) | WARNING (advisory per GDD) |

**Two mounts, one validator:**
1. **CI (BLOCKING)** — a GUT suite in `tests/unit/content/` loads the real shipped catalogs, runs the validator, and asserts `report.ok`. Runs **headless** (`godot --headless`, per the CI/CD rules) so editor-cache Resource instances never contaminate the run. Content errors block merge exactly like code errors (CI/CD rule: no merge on red).
2. **Dev boot (fail-loud)** — when `OS.is_debug_build()`, the boot sequence (ADR-0004) runs the validator after catalogs load; any ERROR goes to `LogSink.error` and halts to a visible failure state. **Release builds skip the gate** — content is immutable post-CI, and skipping keeps validator code out of the shipping hot path.

### Architecture Diagram

```text
 authoring (Godot inspector)          boot (ADR-0004 order)              runtime
┌──────────────────────────┐   ┌───────────────────────────────┐   ┌─────────────────────┐
│ parts/*.tres (PartDef)   │   │ ResourceLoader.load(catalog)  │   │ PartDB.get_part(id) │
│ enemies/*.tres (EnemyDef)│──▶│  → DB.load_catalog(cat, log)  │──▶│  → frozen shared    │
│ catalogs/*_catalog.tres  │   │  → index Dictionary[SN, Def]  │   │    PartDef instance │
│  (explicit manifest)     │   │  → [debug] ContentValidator   │   │ (mutation forbidden)│
└──────────────────────────┘   └───────────────────────────────┘   └─────────────────────┘
          ▲                                    ▲
          │ CI (BLOCKING): GUT suite loads the same catalogs → ContentValidator → assert ok
          └────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# Every def class: class_name XDef extends Resource, all fields @export + typed.
# Cross-DB references are StringName IDs (&"" = none) — never Resource links.

# Catalog: class_name PartCatalog extends Resource
@export var entries: Array[PartDef]

# DB contract (each of the 6 DBs):
func load_catalog(catalog: XCatalog, log_sink: LogSink) -> bool   # boot-time, DI; fatal on dup ID / null entry
func has_x(id: StringName) -> bool                                 # guard for the null contract
func get_x(id: StringName) -> XDef                                 # O(1); returns NULL for unknown id —
                                                                   # callers MUST null-check (typed GDScript
                                                                   # annotations do not prevent null)

# Validator: class_name ContentValidator extends RefCounted
func validate(catalogs: ContentCatalogs, log_sink: LogSink) -> Dictionary
# → {ok: bool, errors: Array[Dictionary], warnings: Array[Dictionary]}
# ContentCatalogs = plain aggregate of the 6 loaded catalogs (test fixtures build it directly)
```

## Alternatives Considered

### Alternative 1: JSON content files parsed into Resources at boot
- **Description**: Author catalogs as JSON (symmetric with ADR-0001's save format); a boot-time mapper builds typed defs.
- **Pros**: Diff-friendly; hand-editable outside the editor; one serialization story project-wide.
- **Cons**: Loses inspector authoring (enum dropdowns, sub-resource editing); adds a parse+map layer that itself needs tests; JSON parses every number as float → `int()` casts on ~every field of ~130 records; two schema definitions to keep in sync (JSON shape + def class).
- **Rejection Reason**: ADR-0001 chose JSON because *player data* must survive schema drift and be debuggable in the field. Content has the opposite profile: authored in-editor, versioned in git, immutable at runtime. The symmetry is superficial; the inspector is the better authoring tool and `.tres` diffs are reviewable.

### Alternative 2: Generic Dictionary catalogs (no typed classes)
- **Description**: DBs hold `Dictionary` records keyed by ID; consumers read fields by string key.
- **Pros**: Least code; no class-per-entity maintenance.
- **Cons**: No compile-time field checking — a typo'd key is a silent `null` at runtime; no inspector typing; every consumer re-validates shapes; fights the static-typing standard and the 80% coverage mandate.
- **Rejection Reason**: The project's registry-driven formula discipline depends on fields being exactly where the contract says. Typed defs make the compiler enforce half the contract for free.

### Alternative 3: Directory-scan loading (no catalog manifest)
- **Description**: DB autoloads scan `res://assets/data/<db>/` at boot and load every `.tres` found.
- **Pros**: Zero-touch entry addition (no catalog edit).
- **Cons**: `DirAccess` listing in exported PCKs returns `.remap` stub names instead of `.tres` names — a `*.tres` scan works in-editor and finds nothing post-export, unless workaround code strips `.remap` suffixes; ships-what-exists semantics also means a stray WIP file silently enters the build.
- **Rejection Reason**: A known works-in-editor/fails-in-export class of bug on our primary platform (iOS), traded for saving one line per new entry. The catalog IS the reviewable manifest.

### Alternative 4: One monolithic .tres per DB (entries inline)
- **Description**: All entries authored as sub-resources inside a single catalog file.
- **Pros**: Fewest files.
- **Cons**: Every content change conflicts in one file; per-entry review diffs are noisy; inspector navigation of 60 inline sub-resources is painful.
- **Rejection Reason**: Per-entry files + explicit catalog keeps diffs entry-scoped at trivial cost.

## Consequences

### Positive
- Compile-time-checked content access; typo'd IDs surface at the validator, typo'd fields at parse time.
- The catalog manifest makes shipped content a single reviewable diff surface.
- One validator, two mounts: authoring errors block merge in CI and fail loud at dev boot, with zero validator cost in release builds.
- Read-only frozen defs eliminate the 4.5 shallow-`duplicate()` trap by construction — the dangerous call is simply never made.
- Content lives entirely in Godot-native tooling: no external pipeline, no parse layer.

### Negative
- One def class + one catalog class per DB (~13 small scripts) to maintain alongside the GDD schemas.
- Adding an entry requires touching two things (entry file + catalog array) — deliberate, but one more step than directory scanning.
- `.tres` text format is Godot-specific; external tools can't easily generate content (acceptable: solo dev, in-editor authoring).
- The `&""`-as-null convention is a convention, not a type — only the validator enforces it.

### Risks

| Risk | Mitigation |
|------|-----------|
| Typed `@export` dictionaries (`Dictionary[StringName, int]`) mis-serialize, `String`-coerce keys, or lose typing in `.tres` round-trip | Verification item #2 is a **gate: must pass before content authoring begins**. If it fails, the fallback (untyped `Dictionary` + validator-enforced schema) requires an explicit ADR-0003 amendment — never a silent in-place downgrade |
| A def gets mutated at runtime despite the ban | Forbidden pattern registered; code review + a GUT test that snapshots def field values before/after a battle sim and asserts equality |
| Stored-equals-derived drift when CP-F4/EDB-1 retune | The validator computes from the SAME registry constants the game uses; a retune breaks CI until content is re-derived — that's the invariant working as intended |
| Catalog forgets a new entry (authored but not shipped) | CI fixture test asserts entry-directory count == catalog size per DB (cheap glob-count check runs in GUT, not in the game) |
| Validator and GDD ACs drift apart | Each validation family cites its GDD AC in the test name (`test_ac_ed_07a_break_hp_derivation`); `/story-done` traceability picks this up |
| Release build ships content that never passed CI (local export) | Release export checklist (ADR-0004 boot doc + release-manager) requires a green content CI run; acceptable residual risk for solo dev |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| part-database.md | Rule 8 rarity-gated nullability + CORE exception; Formula 2/2b input ranges; drop-condition vocabulary | `PartDef` typed fields; validator rarity-gate + range + vocabulary families |
| enemy-database.md | EDB-1 `break_hp` + CP-F4 `xp_value` stored-equals-derived; EC-ED-02/04/10; pool>regions (AC-ED-15c); WILD power cap | `EnemyDef`/`BreakRegionDef`; stored-equals-derived + composition + cap validation (ERROR) |
| move-database.md | AC-MDB-04 `power_tier` iff DAMAGE; `target_profile` reserved; AC-MDB-10 no CORE SKILL_UNLOCK | `MoveDef` typed enums; nullability + MVP-legality families |
| passive-database.md | AC-PDB-15 trigger×behavior legality; `behavior_params` shape per class | Validator shape-checks `behavior_params` against `behavior_class` |
| consumable-database.md | AC-CD-16 `buy_price > sell_price` BLOCKING; no BOSS_GRADE in MVP; AC-CD-15 `effect_params` shape | Economy + MVP-legality + shape families (ERROR) |
| world-loot.md | AC-WL-04 `loot_id` uniqueness fatal; WL-PRED-2 payload/ceiling/per-zone-PART; BLUEPRINT = content error | Uniqueness fatal at load; economy/composition family |
| enemy-ai.md | TR-eai-003 `ai_profile` resolution | `EnemyDef.ai_profile: StringName` + O(1) profile lookup |
| symbot-core-progression.md | AC-CP-27 `level_requirement` ≥ rarity floor; `level_growth` CORE-only | Rarity-floor + nullability validation |

## Performance Implications
- **CPU**: Boot load + index of ~130 records: sub-millisecond scale; dev-boot validation adds one linear pass over all catalogs (debug builds only). Runtime lookups O(1) `Dictionary.get`.
- **Memory**: All defs resident permanently — trivially small (a few hundred KB) against the 512MB ceiling. No per-lookup allocations (shared instances, no copying).
- **Load Time**: 6 `ResourceLoader.load` calls; no directory enumeration. No measurable impact.
- **Network**: N/A.

## Migration Plan
None — greenfield. First implementation step per DB epic: def class → catalog class → DB load/index → validator family → author MVP entries.

## Validation Criteria
- [ ] All 6 catalogs load in an exported Mac AND iOS build (no `.remap` failures; verification item #1)
- [ ] `Dictionary[StringName, int]` `@export` round-trips through `.tres` with typing intact (verification item #2)
- [ ] GUT content suite runs the ContentValidator on shipped catalogs **headless** and blocks CI when any ERROR-family check fails
- [ ] CI parse gate: all `class_name` def scripts parse cleanly before the content suite runs (a parse-broken def silently fails class registration)
- [ ] A deliberately-corrupted fixture per validation family (8 fixtures) fails its named test — proving the validator discriminates
- [ ] Dev boot with a broken catalog halts loud via LogSink; release build skips the gate (build-flag test)
- [ ] Def-immutability test: field snapshot before/after a battle sim is identical; the same test asserts `duplicate()` on a def still shares nested resources — proving duplicate() is NOT a safe copy and the ban is load-bearing
- [ ] Duplicate in-catalog ID, null catalog entry, and duplicate `loot_id` all fail fatally at load
- [ ] No `DirAccess` usage anywhere under the content load path (static grep test)

## Related Decisions
- ADR-0001 — Save/Load (saves store content IDs; `live_resource_in_save_snapshot` forbidden; JSON is for player data only)
- ADR-0002 — Event bus (LogSink is the validator's reporting channel; `global_push_diagnostics` forbidden)
- ADR-0004 — Scene/boot (will sequence: catalogs load → validate [debug] → consumer autoloads)
- ADR-0005 — Stat pipeline (reads `PartDef`; battle snapshot is where mutable copies of def-derived values live)
- docs/architecture/architecture.md — Principle 1 (data-driven read-only content), Principle 2 (registry is the contract)
