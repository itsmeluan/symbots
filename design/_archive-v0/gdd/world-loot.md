# World Loot System

> **Status**: Approved (2026-07-13, full-panel /design-review — NEEDS REVISION → 7 blockers fixed & accepted same session)
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-13
> **Implements Pillar**: Pillar 5 (The World Is a Workshop), Pillar 2 (Every Battle Has a Harvest Goal)

## Overview

The World Loot System is the static-placement and collection-state authority for overworld pickups: it defines an authored catalog of `LootNode` entries — each pairing a zone and authored position with a specific reward (a part instance, a Scrap quantity, or a consumable) — and at runtime tracks which entries the player has already collected. When the player interacts with a pickup in the overworld, this system resolves the award into the Inventory, marks that entry's `loot_id` as collected, and ensures it never reappears. The runtime collection ledger is the `&"world_loot"` domain that the Exploration Progress System serializes and restores across sessions. In the player's experience, this system is responsible for the moment of off-path discovery: the chest tucked behind a pylon cluster that yields exactly the Rare part needed to complete a build — a reward for curiosity, not a guaranteed drop from combat.

## Player Fantasy

Finding a world chest is the game rewarding you for looking. Not for winning a fight — for going the other way, trying the path that looked like a dead end, tapping a pylon cluster that seemed decorative. The moment the chest opens, the core feeling is **curiosity validated**: you went somewhere, and the world said *yes, that was worth it*.

The reward is deliberately **build-relevant but not grind-critical**. A chest might hold the Rare Arms part you've been farming from Crawlers — suddenly you have it without a targeted break. More often it's a part you didn't know you needed: a Rare you hadn't encountered yet that suggests a build direction you weren't considering. Either way, the chest communicates that *this world has depth* — there are things in it that aren't on the combat loop's beaten path, and the combat loop alone doesn't find them.

One thing this fantasy explicitly resists: the **completionist pull**. The collected ledger exists so the world remembers what's been taken — the chest stays visually open, the reward doesn't reappear. It does not exist to surface "12/14 chests found" as a percentage. World loot rewards presence and curiosity; it punishes treating the game as a checklist. The game concept's anti-pillar ("not a catch-em-all collector") applies directly: the world is not a registry to complete — it is a place worth looking around in.

> *(Note: `creative-director` not consulted — Lean mode. Review Section B manually before production.)*

## Detailed Design

### Core Rules

**Rule 1 — The LootNode Schema.** Every world pickup is defined by a `LootNode` entry in the World Loot catalog. The catalog is read-only authored content — no entry is ever created at runtime.

| Field | Type | Notes |
|-------|------|-------|
| `loot_id` | StringName | Globally unique across all content; **stability required** — renaming a `loot_id` after a save exists triggers EP Rule 6c orphan-handling (the collected fact is preserved but the chest re-appears as uncollected on load). Convention: `&"<zone_id>_<sequential>_<descriptor>"` (e.g., `&"starter_01_rare_servo_arm"`). Zone prefix guarantees global uniqueness by construction. |
| `zone_id` | StringName | References a ZoneNode in Zone & World Map (one-to-one: this node lives in this zone). |
| `world_position` | Vector2 | Authored tile position within the zone; consumed by Overworld Navigation for rendering and proximity detection. |
| `reward_type` | Enum | `PART` / `SCRAP` / `CONSUMABLE` / `BLUEPRINT` (reserved — see Rule 6) |
| `reward_payload` | Dictionary | Shape depends on `reward_type` — see Rule 2 |
| `is_hidden` | bool | `true` = node does not appear on the overworld until the player approaches within detection range (the "behind the pylon cluster" beat). `false` = always visible. |

**Rule 2 — Reward payload shapes (by `reward_type`).**

| `reward_type` | `reward_payload` shape | Notes |
|---|---|---|
| `PART` | `{ part_id: StringName }` | `part_id` must resolve in the Part Database; `drop_enabled` is not checked here (world loot is a hand-placed guarantee, not a drop table roll) |
| `SCRAP` | `{ amount: int, min: 1 }` | Flat deposit to Inventory Scrap balance |
| `CONSUMABLE` | `{ consumable_id: StringName }` | Must resolve in the Consumable Database |
| `BLUEPRINT` | reserved — not authored in MVP | See Rule 6 |

**Rule 3 — Collection is one-time and permanent.** When the player collects a `LootNode`: the reward is awarded to Inventory, the `loot_id` is added to the runtime collected Set, and the node's visual state flips to COLLECTED. A collected node **never reappears** — not on zone re-entry, not after saving and loading.

**Rule 4 — Double-collect is silently idempotent.** If `collect(loot_id)` is called and `loot_id` is already in the collected Set: no reward is awarded, no signal fires, no error is logged. Callers may but are not required to call `can_collect(loot_id)` first — the collect path is always safe.

**Rule 5 — `loot_id` global uniqueness is a hard content constraint.** The Exploration Progress domain is a flat global Set: there is no per-zone namespace in the collection ledger. Two LootNodes sharing a `loot_id` (even in different zones) would collapse to a single collected-state bit. World Loot performs a uniqueness validation pass at content load time: duplicate `loot_id`s are a **fatal content error** — `load_catalog()` returns `{ok: false, error: …}` naming the duplicate and emits an error via the injectable sink (Rule 9.3), and no catalog is built (no node collectable). This is a returned failure result, **never a process abort** (a hard crash is untestable in GUT — see Rule 9.3). Not a silent first-wins de-dupe.

**Rule 6 — BLUEPRINT reward type is reserved for Alpha.** The `BLUEPRINT` enum value is defined in schema now so content tooling can be extended without a breaking schema change. Authoring a `BLUEPRINT` node in MVP content is a **content error** (logged, node treated as INVALID). Blueprint Crafting (#25, Alpha) un-reserves this type when it ships.

**Rule 7 — EP domain contract (this system is the `&"world_loot"` domain).** This system implements the three-operation Exploration Progress domain contract. **The EP contract (exploration-progress.md Rule 3) requires `snapshot()` to return a Dictionary and refuses any save whose domain snapshot is a non-Dictionary (EP AC-EP-12 uses an Array-returning snapshot as its broken-domain fixture); a bare Array would both refuse every save AND be treated as a wrong-type sub-blob on load (EP Rule 6d → `restore({})` → all loot state wiped).** The collected-Set payload is therefore wrapped in a single-key Dictionary:
- `snapshot()` → `{ "collected": <sorted Array[StringName]> }` — the `collected` value is the sorted list of all collected `loot_id`s (sorted via `String(a) < String(b)` — raw StringName sort is session-unstable); returns a **fresh Dictionary** (a new Dictionary literal each call, no aliasing of the internal set).
- `restore(data: Dictionary)` → reads `data.get("collected", [])` (absent key → empty list, covering EC-WL-07 / EP Rule 6a gracefully) and replaces (never merges) the runtime collected Set with `Set(collected)`, deduping on reconstruction.
- `rederive()` → no-op (the collected Set is a source fact, not a derived field — there is nothing to re-derive from it).

**Rule 8 — Collection refusal on full inventory.** Before awarding, `collect()` verifies the reward can be **fully deposited** (Scrap: `current + amount ≤ SCRAP_MAX`; consumable: stack space available; parts: always accepted — instances are uncapped). **The deposit verification is delegated to Inventory's add-interface return value** — this system does not re-implement Inventory's cap logic. For Scrap it reads Inventory's `{accepted, rejected}` contract (refuse if `rejected > 0`); for consumables it reads the accept/reject result (MVP world-loot consumable awards are always exactly 1 unit — the CONSUMABLE payload carries no quantity field — so the check reduces to "Inventory accepts one more of `consumable_id`"). If the deposit would be rejected or truncated, the collect is **REFUSED**: no reward, `loot_id` NOT added to the collected Set, node stays UNCOLLECTED, and a `collect_refused(loot_id, reason)` signal fires for UI feedback ("Scrap storage full"). The reward is never partially awarded and never destroyed — the player can free space and return.

**Rule 9 — Testability contract (hard interface requirements — the ACs cannot be written without these; lead programmer must design them in before implementation).**

1. **Injectable warning/error sink.** Godot 4's `push_warning()`/`push_error()` cannot be captured by GUT. Every content warning and error this GDD mandates (EC-WL-02/04/05/06/07, Rule 5 fatal) is emitted through an injectable reporting interface (production: forwards to `push_warning`/`push_error`; tests: a recording sink). Same pattern as EP Rule 3a.3.
2. **Injectable Inventory interface.** The Inventory dependency is injected (constructor or setter), never a singleton access. Tests configure a stub to accept or reject deposits — the only practical seam for the Rule 8 refusal path (AC-WL-09).
3. **Catalog load returns a structured result.** `load_catalog()` returns `{ok: bool, error: String}` — the Rule 5 fatal duplicate is a returned error plus sink emission, never a process abort (a hard crash is untestable in GUT).
4. **Concrete, testable node-state accessor.** Derived visual state (UNCOLLECTED / COLLECTED) must be readable through a concrete method — `get_node_state(loot_id) → LootNode.State` — not only inferred from `can_collect()`. `can_collect()` folds catalog-presence and collected-state into one bool and cannot express the COLLECTED-vs-phantom distinction the visual layer needs. AC-WL-11 asserts on `get_node_state()` so a Set-restored-but-node-desynced impl is caught (the most likely shipping bug — chest art not matching collection truth after a load).

### States and Transitions

Each `LootNode` has exactly two states:

| State | Meaning | Visual |
|-------|---------|--------|
| `UNCOLLECTED` | Default; reward available | Closed chest / glowing indicator |
| `COLLECTED` | Permanently after `collect()` | Open chest / no indicator |

State is not serialized directly — it is **derived** from the runtime collected Set (if `loot_id ∈ collected_set` → COLLECTED; else UNCOLLECTED). On load, `restore()` re-populates the Set; the visual state of every node updates from that Set. There is no intermediate or transient state. **The derived state is readable through `get_node_state(loot_id) → LootNode.State` (Rule 9.4)** — the concrete accessor the rendering layer reads and AC-WL-11 asserts against, so a restored-but-not-re-derived node (Set correct, visual desynced) is caught rather than shipped.

Content-error state: if a `LootNode`'s `loot_id` resolves to no catalog entry (removed content, authoring error), it is treated as a **phantom node** — not rendered, not collectable, no crash.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Part Database** (upstream) | This system reads `part_id` → validates the reward part exists; reads `display_name` + `sprite_id` for the reward reveal popup. `drop_enabled = false` does NOT block collection — world loot is hand-placed, not drop-table-sourced. | Hard dependency |
| **Consumable Database** (upstream) | Reads `consumable_id` → validates the reward item exists. | Hard dependency |
| **Zone & World Map** (upstream) | Groups `LootNode` entries by `zone_id`; on zone load, provides the list of nodes in that zone (both UNCOLLECTED and COLLECTED) to Overworld Navigation. Never reads ZWM at runtime — `zone_id` is a static reference on each node. | Soft — zone grouping only; this system can initialize without ZWM present |
| **Inventory** (downstream) | `collect()` calls Inventory's add-part / add-scrap / add-consumable interface. This system does not own Inventory state — it writes awards and trusts Inventory's own overflow/stack rules. **The Rule 8 deposit check is delegated to Inventory's return value** (Scrap `{accepted, rejected}` contract; consumable accept/reject) — WL does not re-implement cap logic. | Hard at collection time |
| **Overworld Navigation** (downstream) | Provides the `LootNode` position list per zone for rendering. Receives `node_collected(loot_id)` signal after each successful collection. Overworld Navigation owns the interact gesture that triggers `collect(loot_id)` on this system. | Signal + API |
| **Exploration Progress** (downstream) | Registers as the `&"world_loot"` domain on EP startup; implements `snapshot()` / `restore()` / `rederive()`. EP serializes and restores the collected Set across sessions. | EP pulls via domain contract; no direct call |

## Formulas

This system owns **no balance mathematics**. All numeric rewards are authored constants delegated to Inventory at collect-time (a `SCRAP` node's `amount` is a hand-authored int, not a computed value). This section documents the three behavioral predicates that carry correctness contracts.

**No formula in this system uses `floor()`, `ceil()`, or floating-point arithmetic. No IEEE-754 epsilon scan is required** (stated per project convention so reviewers don't flag the absence — same pattern as EZ-1/EZ-2/EP-PRED-1).

### WL-PRED-1 — Idempotent collect guard

```
can_collect(loot_id) = catalog.has(loot_id) AND NOT collected.has(loot_id)
```

**Variables:**

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `loot_id` | StringName | catalog key space | The node being tested |
| `catalog` | Dictionary[StringName, LootNode] | authored content | The full loot catalog (read-only) |
| `collected` | Dictionary[StringName, bool] | runtime | The collected Set (Godot set idiom) |
| result | bool | {true, false} | Whether `collect()` will award and record |

**Output:** boolean. Pure hash lookup + boolean AND — no arithmetic.
**Worked example:** `loot_id = &"starter_01_rare_servo_arm"`, present in catalog, not yet collected → `true`. Same call after a successful collect → `false` (the idempotency guard of Rule 4). A `loot_id` absent from the catalog (phantom node) → `false` regardless of collected state.

`collect(loot_id)` awards + records **iff** `can_collect(loot_id)` is `true`; otherwise it is a silent no-op (Rule 4) **except** for the unknown-`loot_id` case, which warns (EC-WL-02). Because `can_collect()` returns a bare bool, `collect()` cannot distinguish "already collected" (silent, AC-WL-02) from "not in catalog" (warns, AC-WL-03) from the guard result alone — so `collect()` performs the two checks in this **normative order**:

```
func collect(loot_id):
    if not catalog.has(loot_id):
        sink.warn("world_loot: collect() on unknown loot_id " + String(loot_id))   # EC-WL-02 — warns
        return
    if collected.has(loot_id):
        return                                                                       # EC-WL-01 — silent no-op
    # Rule 8 deposit check → award → record → emit node_collected(loot_id)
```

The warning fires from inside `collect()` (never from `can_collect()`, which stays a pure predicate). This ordering makes AC-WL-02 (zero warnings) and AC-WL-03 (exactly one warning) derivable from the rules alone. The guard is evaluated inside `collect()` itself — callers are not required to pre-check.

### WL-PRED-2 — Catalog validity invariant (startup/content-pipeline only — never in the collect path)

```
valid_catalog = ∀ node ∈ catalog:
    node.loot_id is a non-empty StringName
AND node.reward_type ∈ {PART, SCRAP, CONSUMABLE}          # BLUEPRINT authored in MVP = content error (Rule 6)
AND node.reward_payload resolves for its reward_type       # part_id in Part DB / amount ≥ 1 / consumable_id in Consumable DB
AND node.zone_id references an existing ZoneNode           # SKIPPED when ZWM not registered at load — see note below
AND no two nodes share a loot_id                           # global uniqueness — fatal on violation (Rule 5)

# Per-zone aggregate invariants (evaluated per zone_id group):
AND ∀ zone: Σ(amount for SCRAP nodes in zone) ≤ WORLD_SCRAP_CEILING   # economy guardrail (Tuning Knobs) — content error on violation
AND ∀ zone: count(PART nodes in zone) ≥ 1                             # Pillar 5 — every zone feeds the build loop; content error on violation
```

**Output:** boolean per node + two per-zone aggregate checks + one global uniqueness check. Runs **once at content load** (the normative gate for shipped builds; a CI content-validation step SHOULD run the same predicate as the primary defense, with content-load as the runtime safety net), never at collect-time — `collect()` must stay a pure hash-lookup hot path with no linear scans. **Failure handling by clause:** per-node failures (bad payload, bad reward_type) degrade that node to **phantom** (logged, skipped); a `loot_id` duplicate is **fatal** (Rule 5, returns `{ok: false}`); the two per-zone aggregate invariants (Scrap ceiling, min-1-PART) are **content errors** (logged via the sink; the offending zone's composition must be fixed — they do not degrade individual nodes to phantom, since the fault is the zone composition, not any one node).

**ZWM-absent skip (soft-dependency reconciliation).** Zone & World Map is a *soft* dependency — this system can initialize without it. If ZWM is **not registered** at `load_catalog()` time, the `node.zone_id references an existing ZoneNode` clause is **skipped** (not treated as failed — otherwise every node would wrongly degrade to phantom), and a single advisory warning is logged. Zone-existence validation is then deferred to first zone-grouping request (when ZWM is guaranteed present). All other clauses still run.

### WL-PRED-3 — Snapshot sort contract (locked by Exploration Progress Rule 1)

```
snapshot() = { "collected": collected.keys() sorted by: func(a, b): return String(a) < String(b) }
```

**Output:** a fresh Dictionary `{ "collected": <sorted Array[StringName]> }` (no aliasing — a new Dictionary literal is built each call). The `String()` cast is **load-bearing and normative**: raw `StringName` `<` compares session-unstable intern indices — dropping the cast produces a non-deterministic sort across launches and breaks save-file comparability. This contract is owned by Exploration Progress (Rule 1, AC-EP-01); it is restated here because this system is the implementer. **The Dictionary wrapper is required by the EP snapshot type contract (Rule 7)** — a bare Array refuses every save. An empty collected Set returns `{ "collected": [] }` (never null, never a bare Array).

## Edge Cases

- **EC-WL-01 — Double-collect.** *If* `collect(loot_id)` is called and `loot_id` is already in the collected Set: silent no-op **at the logic layer** — no reward, no signal, no error (Rule 4, WL-PRED-1). (Presentation is *not* silent: interacting with a visible COLLECTED node plays the "already emptied" ambient cue — see Visual/Audio Collection feedback — but that cue is triggered by Overworld Navigation's gesture layer, not by `collect()`.) *Verified by AC-WL-02 (logic-layer silence).*

- **EC-WL-02 — Collect on unknown `loot_id`.** *If* `collect()` is called with a `loot_id` absent from the catalog (stale reference from Overworld Navigation, removed content): no-op + **content warning** logged via the injectable sink (this indicates a caller bug, unlike EC-WL-01 which is legal). No crash, no Set mutation. *Verified by AC-WL-03.*

- **EC-WL-03 — Duplicate `loot_id` in catalog.** *If* two `LootNode` entries share a `loot_id`: **fatal content error at load** — load aborts loudly (Rule 5, WL-PRED-2). Not a first-wins de-dupe: a shared collected-bit corrupts the permanence promise silently, so it must never reach a player. *Verified by AC-WL-04.*

- **EC-WL-04 — BLUEPRINT node authored in MVP.** *If* MVP content contains a `reward_type = BLUEPRINT` node: content error logged, node degraded to **phantom** (not rendered, not collectable). Not fatal — one bad node shouldn't block the game (Rule 6). *Verified by AC-WL-05.*

- **EC-WL-05 — Reward payload does not resolve.** *If* a `PART` node's `part_id` is not in the Part Database, a `CONSUMABLE` node's `consumable_id` is not in the Consumable Database, or a `SCRAP` node's `amount < 1`: WL-PRED-2 fails for that node → **phantom** (logged, skipped). Other nodes unaffected. *Verified by AC-WL-05.*

- **EC-WL-06 — `zone_id` references a non-existent zone.** *If* a node's `zone_id` matches no ZoneNode: **phantom** + content warning. The node has nowhere to render; it must not crash zone loading. *Verified by AC-WL-05.*

- **EC-WL-07 — Orphaned collected IDs on restore.** *If* `restore()` receives `loot_id`s that match no catalog entry (content removed after the save was written): they are **preserved in the Set and written back on next snapshot** — never dropped (EP Rule 6c preserve-and-warn; losing a collected fact is the anti-fantasy). One warning logged naming the orphan count. If the content is later re-added, the node correctly restores as COLLECTED. *Verified by AC-WL-08.*

- **EC-WL-08 — Empty collected Set.** `snapshot()` on an empty Set returns `{ "collected": [] }` (never null, never a bare Array); `restore({})` and `restore({"collected": []})` both produce an empty Set without error. This is the new-game initial state. *Verified by AC-WL-07.*

- **EC-WL-09 — Inventory cannot fully accept the reward.** *If* the deposit check fails (Scrap would exceed `SCRAP_MAX`, consumable stacks full): collect is **REFUSED** per Rule 8 — no reward, no Set mutation, node stays UNCOLLECTED, `collect_refused(loot_id, reason)` fires. Retry after freeing space succeeds normally. *Verified by AC-WL-09.*

- **EC-WL-10 — Refused-then-retried collect.** *If* a collect was refused (EC-WL-09) and the player frees space and interacts again: the second `collect()` succeeds normally — refusal leaves no residue state. *Verified by AC-WL-09 (part b).*

- **EC-WL-11 — `restore()` with duplicate IDs in the Array.** *If* the serialized Array contains duplicates (corrupt/tampered save): deduped automatically on Set reconstruction (EP already owns the warning — EC-EP-07/AC-EP-08). This system's `restore()` is naturally idempotent per key. *Delegated — verified by EP AC-EP-08.*

- **EC-WL-12 — Collect fires mid-battle or outside the owning zone.** Cannot occur by construction: Overworld Navigation owns the interact gesture and only enables it for nodes in the currently loaded zone during overworld play. This system performs no additional context check — stated so reviewers don't flag the absence. **Cross-system obligation (logged for Overworld Navigation #16 authoring):** this impossibility is a *promise WL makes on Overworld Nav's behalf* — #16 MUST gate the interact gesture to (overworld state) ∧ (node ∈ currently-loaded zone), and MUST carry this into its GDD as an explicit AC. Until #16 is authored it is an accepted-but-unverified assumption. *No AC on this system by design (structural impossibility, owned by Overworld Navigation).*

## Dependencies

### Upstream Dependencies (what this system requires)

| System | What this system reads/calls | Hard/Soft | Status |
|--------|------------------------------|-----------|--------|
| **Part Database** (#1) | `part_id` resolution for PART rewards; `display_name` + `sprite_id` for the reward reveal. `drop_enabled` deliberately NOT consulted (Rule 2). | **Hard** | Approved ✓ |
| **Consumable Database** (#1c) | `consumable_id` resolution for CONSUMABLE rewards; `max_stack` participates in the Rule 8 deposit check. | **Hard** | Approved ✓ |
| **Inventory** (#11) | `collect()` deposits via Inventory's add-part / add-Scrap / add-consumable interfaces; the Rule 8 refusal check reads Inventory's acceptance contract (`SCRAP_MAX` headroom, stack space). | **Hard** at collect time | Approved ✓ |
| **Zone & World Map** (#12) | `zone_id` validation (WL-PRED-2) and per-zone node grouping. Static reference only — no runtime ZWM reads. | **Soft** — initializes without ZWM; nodes in unknown zones degrade to phantom | Approved ✓ |

### Downstream Dependents (what depends on this system)

| System | What it reads/calls | Status |
|--------|--------------------|--------|
| **Exploration Progress** (#14) | This system registers as the `&"world_loot"` domain and implements the EP Rule 3 contract (`snapshot()`/`restore()`/`rederive()`). **This GDD discharges EP's "soft-provisional" dependency row** — the contract EP pre-defined is implemented exactly as specified (Rule 7). | Approved ✓ |
| **Overworld Navigation** (#16) | Reads per-zone node lists (`world_position`, `is_hidden`, derived state) for rendering; owns the interact gesture that calls `collect(loot_id)`; consumes `node_collected` / `collect_refused` signals. | Not Started |
| **Save/Load** (#17) | Indirect only — receives the collected Set inside EP's progression blob. Never touches this system directly. | Not Started |

### Bidirectionality Notes

- **Zone & World Map** already lists World Loot as a downstream dependent ✓ (its Dependencies table, added at ZWM authoring). Confirmed consistent.
- **Part Database** already names World Loot in its Overview's downstream list ✓.
- **Exploration Progress** ✅ **ERRATUM APPLIED 2026-07-13** — the `&"world_loot"` domain row (Rule 1 table + both dependency tables) marked "Authored — contract implemented"; the serialized-form description corrected to the `{"collected": [...]}` Dictionary envelope (it previously described the superseded bare-Array form, which was itself inconsistent with EP's own Rule 3).
- **Consumable Database** ✅ **ERRATUM APPLIED 2026-07-13** — World Loot added to both downstream-reader tables (`consumable_id` + `max_stack` for CONSUMABLE rewards; `max_stack` feeds the Rule 8 deposit check).
- **Inventory** ✅ **ERRATUM APPLIED 2026-07-13** — the existing World Loot downstream row updated to Approved with the Rule 8 `{accepted, rejected}` refusal-check semantics (refuse if `rejected > 0`, no partial award).
- **Systems index update:** #13's Depends On column currently reads "Part Database, Zone & World Map" — should become "Part Database, Consumable Database, Inventory, Zone & World Map" (handled at index update).
- **Erratum completion tracking (owed on approval — surfaces at next re-review):** the two light errata above (Consumable DB + Inventory downstream-reader rows) have no AC; they are logged here and in the review log so a future design-review pass verifies they were applied.
- **Cross-system obligation logged for Overworld Navigation (#16):** EC-WL-12 gesture-gating (overworld-state ∧ node-in-loaded-zone) is a promise WL makes on #16's behalf — #16 must carry it as an explicit AC when authored. Also owned by #16: the refused-node return-navigation affordance and the "already emptied" ambient-cue trigger (Rule 4 presentation), both flagged in this GDD but implemented there.

## Tuning Knobs

This system owns no runtime balance constants. Its knobs are **content-authoring levers** on the catalog, plus one economy coupling that needs a guardrail.

| Knob | Type | Owner | Effect / Safe guidance |
|------|------|-------|------------------------|
| Node count per zone | Content | This system | How reward-dense exploration feels. MVP starter zone target: **6–10 nodes**. Too few → exploration feels unrewarded (Pillar 5 violation); too many → world loot competes with the combat harvest loop as the primary acquisition route (Pillar 2 erosion). |
| Reward mix (PART / SCRAP / CONSUMABLE ratio) | Content | This system | MVP guidance: majority consumables + Scrap, **1–3 PART nodes per zone** with at most one Rare. Parts are the combat loop's payoff — world loot parts should feel exceptional, not routine. |
| `SCRAP` node `amount` | Content | This system | Per-node range guidance: **10–60** (roughly one to three WILD victories' worth per Drop System `SCRAP_YIELD`: Common 5 / Rare 20). **Economy guardrail — now enforced, not advisory:** the sum of all SCRAP-node `amount`s in a zone must not exceed `WORLD_SCRAP_CEILING` (next row) — validated at content load (WL-PRED-2 per-zone clause). This is ~10% of the zone's expected combat-arc Scrap (~1,800 for the MVP arc, ESTIMATED per Drop System). **World-loot Scrap is a one-time, front-loaded, session-1 supplement** — all nodes exhaust in the first zone pass, so this ~180 lands in session 1 and never recurs; it is NOT in Drop System's hours-1-3 game-thirds sketch. Retunes to the ceiling still warrant an economy-designer re-check. |
| `WORLD_SCRAP_CEILING` | Constant (int) | This system | **180** (MVP). Max total of all SCRAP-node `amount`s summed per zone. Derivation: 10% × ~1,800 ESTIMATED combat-arc Scrap (Drop System). Safe range **120–200**. Enforced by WL-PRED-2's per-zone Scrap-sum clause — a zone whose SCRAP total exceeds it is a content error (logged via the sink; authoring must reduce amounts). Retune alongside the Drop System arc-Scrap estimate. |
| `is_hidden` ratio | Content | This system | What fraction of nodes are hidden until approach. MVP guidance: **~1/3 hidden**. All-visible → no discovery beat; all-hidden → players never learn world loot exists (onboarding failure). |
| Part rarity ceiling for world loot | Content | This system | MVP: **COMMON and RARE only**. BOSS_GRADE and PROTOTYPE parts must stay exclusive to their earn paths (boss kills, pity systems — Drop System). A world chest bypassing the Boss-grade hunt would break Pillar 2's promise that mastery earns the top rewards. **At most one RARE PART node per zone** (also the reward-mix cap) — see DDR-WL-1 below. |
| `is_hidden` × node value | Content | This system | **RARE PART nodes SHOULD default to `is_hidden = true`** — the discovery beat (shimmer-in + emphatic rarity sting) lands hardest when the best reward is earned by looking, not walked into. SCRAP/CONSUMABLE nodes may be visible or hidden at author discretion, subject to the ~1/3 hidden ratio. Ties visibility to value so the `is_hidden` budget serves the "curiosity validated" fantasy, not just texture. |

**Cross-referenced knobs (owned elsewhere, affect this system):**

| Knob | Owner | Relevance here |
|------|-------|----------------|
| `SCRAP_MAX` | Inventory | The Rule 8 refusal boundary for SCRAP rewards. Raising it makes refusals rarer; this system never redefines it. |
| `max_stack` (per consumable) | Consumable Database | The Rule 8 refusal boundary for CONSUMABLE rewards. |
| `SCRAP_YIELD` (5/20/35/60) | Drop System | The benchmark that keeps world-loot Scrap amounts proportionate (see `amount` guidance above). |

**DDR-WL-1 — Early-zone RARE bypass is a deliberate design decision (2026-07-13).** A single authored RARE part in the starter zone deliberately bypasses Drop System DS-F-LEVEL's ×0.5 early-Rare drop throttle. This is **intended, not an oversight.** DS-F-LEVEL governs *combat drop rates* (the RNG faucet); world loot is *authored discovery* (a curated, one-time channel). The Player Fantasy explicitly celebrates "the Rare Arms you've been farming, suddenly without a targeted break" — that is the fantasy working, not a leak. The throttle's scarcity guarantee is scoped to the combat faucet; it does not extend to authored placement. **Guardrail:** at most one RARE PART node per zone (see rarity-ceiling row), so the bypass is a one-time curiosity reward, never a farmable shortcut. *(economy-designer dissented, preferring a hard core-level gate on RARE nodes to keep the early economy airtight; creative-director + author accepted the DDR as truer to the Player Fantasy. Revisit if playtest shows the early Rare trivializes the harvest loop.)*

**Warning — level_requirement interaction.** A PART node can contain a part whose `level_requirement` exceeds the player's cores when found (e.g., a RARE part needing core level 3 found at level 1). This is **intended for multi-zone progression** — the part sits in inventory as a goal ("level up to equip this"), consistent with Core Progression's gating model. **MVP-scope clause:** for the 1-zone MVP, a PART node's `level_requirement` MUST be reachable within the arc's level ceiling — authoring a part gated above the max core level a single-zone playthrough can reach produces a dead inventory item (or a 20-Scrap scrap payout), not a goal. Keep the forward-tease delta modest (~1–2 levels above the zone's expected core range) so it reads as aspirational, not demoralizing. Within that caveat, do not author around it; it's a feature, not a trap.

## Visual/Audio Requirements

This system owns the **chest/pickup presentation states** (per EP's Visual/Audio delegation: "World Loot owns chest opened/closed visuals").

**Node visual states (must be readable at overworld zoom):**
- `UNCOLLECTED`: closed pickup with a subtle idle animation (glow pulse or lid shimmer) — discoverable but not screaming. Silhouette must read as "container" instantly (game concept: part readability at a glance applies to world objects too).
- `COLLECTED`: open/emptied version of the same asset, permanently visible in the world — **never removed from the scene**. The open chest is the "world remembers" beat (EP Player Fantasy); despawning it would make the world feel like scenery.
- `is_hidden` reveal: when a hidden node enters detection range, a brief reveal effect (shimmer-in + soft chime). The reveal is its own micro-reward — it says "your curiosity was detected."

**Collection feedback:**
- Open animation on the node + a **reward reveal popup**: part sprite (via Part DB `sprite_id`), display name, rarity-coded frame. Rarity color language must match the game-wide rarity/element coding (game concept: consistent color language; boss parts glow).
- **Reward-reveal popup content by `reward_type`** (the popup is architecturally part-metadata-shaped, so the non-PART types need explicit format): **PART** → part sprite (`sprite_id`), display name, rarity-coded frame. **SCRAP** → generic Scrap icon + the amount as text ("+15 Scrap"), neutral frame (no rarity color — Scrap has no rarity). **CONSUMABLE** → consumable icon + display name (from Consumable DB), rarity-coded frame per the consumable's tier. All three share the same popup shell, tap-anywhere-to-dismiss.
- Audio: open stinger + reward sting **scaled by rarity** — COMMON modest, RARE emphatic (SCRAP uses the modest/neutral sting — no rarity escalation). Same escalation grammar the Drop System loot screen will use (keep them consistent — one vocabulary for "you got a thing" across combat and world).
- Refusal (Rule 8): a distinct blocked cue (short buzz + "Scrap storage full" toast). Must not resemble the collect sound — the player needs to know nothing was consumed.
- Already-collected interaction (Rule 4 / EC-WL-01): interacting with a COLLECTED node (the permanently-visible open chest) plays a **soft, non-reward ambient cue** (a light "empty" tick — no popup, no reward sting) so the player reads *"already taken,"* not *"the game ignored me."* This closes the silent-no-feedback gap while preserving idempotency: it is a **presentation response owned by Overworld Navigation's gesture layer** (it checks `can_collect() == false` and plays the cue), NOT part of `collect()`'s contract — `collect()` stays a silent logic-layer no-op (no reward, no Set mutation, no `node_collected` signal). The cue is distinct from both the collect stinger and the refusal buzz.

> *(Note: `art-director` not consulted — Lean mode. Review against the art bible when it exists; per-asset work via `/asset-spec system:world-loot` after art bible approval.)*

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:world-loot` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

- **Reward reveal popup**: touch-first (min 44×44pt dismiss target), tap-anywhere-to-dismiss, shows part/consumable/Scrap awarded. Owned by the overworld HUD layer (Overworld Navigation's UI pass), reading this system's `node_collected` signal payload.
- **Refusal toast**: reads `collect_refused(loot_id, reason)` → short non-blocking toast ("Scrap storage full"). No modal — don't interrupt exploration.
- **Anti-checklist constraint (normative):** no UI surface may display world-loot completion counts or percentages ("12/14 chests") — not on the world map, not in menus. Uncollected nodes get **no map markers**. Discovery is the reward; the ledger is memory, not a checklist. This is this GDD's enforcement of the game concept anti-pillar (and discharges the EP review backlog item "anti-checklist → explicit delegation to #13").

> **📌 UX Flag — World Loot**: the reward reveal popup + refusal toast have UI requirements. In Pre-Production, fold them into the overworld HUD UX spec (`/ux-design` for `design/ux/overworld-hud.md` or equivalent) before writing UI stories.

## Acceptance Criteria

**Test path:** `tests/unit/world_loot/` · **Framework:** GUT (GDScript) · All fixtures use synthetic IDs (`zone_01_*`, `dup_id`, `orphan_*`) — no real content dependencies. Inventory is stubbed per Rule 9.2; warnings asserted via the Rule 9.1 sink, never log output.

**AC-WL-01** (BLOCKING, Unit) — **Happy-path collect for all three reward types.** **GIVEN** a catalog with one PART node (`{part_id: &"part_servo_arm_r"}`), one SCRAP node (`{amount: 15}`), one CONSUMABLE node (`{consumable_id: &"cons_repair_kit"}`), and an accepting Inventory stub, **WHEN** each is collected, **THEN per node, asserted independently** (the Inventory stub's add-call count is recorded/read per-node — never as a combined total of 3 that could hide a double-award on one node offset by a missed dispatch on another): exactly one matching Inventory add-call (add-part with `part_servo_arm_r` / add-scrap 15 / add-consumable), the `loot_id` enters the collected Set, `can_collect(loot_id)` flips to `false`, `assert_signal_emit_count(self, "node_collected", 1)` **per node** (a combined `>= 1` or total-of-3 assertion misses a single-node double-fire), and `assert_signal_emitted_with_parameters(self, "node_collected", [loot_id])` (payload carries the correct `loot_id`). Discriminators: Set-mutation-without-award fails the Inventory assertion; award-without-mutation fails `can_collect`; award-during-`can_collect`-then-again-in-`collect` fails the per-node count == 1. *(Rules 2, 3; WL-PRED-1 true branch)*

**AC-WL-02** (BLOCKING, Unit) — **Double-collect is a silent no-op.** **GIVEN** `&"zone_01_part_servo"` already collected, **WHEN** `collect()` is called again, **THEN** the Inventory stub records **exactly one** add-call total across both calls, no signal fires on the second call, `collected_set.size() == 1`, and `sink.warning_count == 0` AND `sink.error_count == 0` (logic-layer silence is normative — this is legal, not a bug; the presentation "already emptied" cue is Overworld Navigation's, not asserted here). *(Rule 4; WL-PRED-1 already-collected branch; EC-WL-01)*

**AC-WL-03** (BLOCKING, Unit) — **Unknown `loot_id` warns and no-ops.** **WHEN** `collect(&"nonexistent_phantom_id")` is called with no such catalog entry, **THEN** no Set mutation, no signal, `can_collect()` returns `false`, and **exactly one warning** via the sink whose message **contains the unknown ID**: assert both `sink.warning_count == 1` **and** `sink.warnings[0].contains("nonexistent_phantom_id")` (a generic "unknown loot node" warning passes the count but fails the content check — EC-WL-02 requires naming the ID). The warning-count assertion is the discriminator against EC-WL-01: an impl treating unknown IDs silently (like double-collect) passes every state assertion but fails the warning check. *(WL-PRED-1 absent-from-catalog branch; EC-WL-02; Rule 4 collect() ordering)*

**AC-WL-04** (BLOCKING, Unit) — **Duplicate `loot_id` is fatal at load.** **GIVEN** a two-node catalog sharing `loot_id = &"dup_id"`, **WHEN** `load_catalog()` runs, **THEN** it returns `{ok: false, error: …}` naming the duplicate (Rule 9.3 structured result — asserted on the return value, not log output), an error is emitted via the sink, and no catalog is built: assert `can_collect(&"dup_id") == false` (a partial-build impl that keeps one of the two dup entries fails this concrete check). *(Rule 5; WL-PRED-2 uniqueness clause; EC-WL-03)*

**AC-WL-05** (BLOCKING, Unit) — **Phantom degradation is non-contagious.** Three sub-fixtures, **each an independent catalog instance** (one bad node + two valid PART nodes; the two valid PART nodes also satisfy the min-1-PART per-zone rule), with ZWM registered so clause (c) runs: **(a)** `reward_type = BLUEPRINT`; **(b)** PART with `part_id = &"nonexistent_part_xyz"`; **(c)** `zone_id = &"zone_doesnt_exist"`. **THEN** in each: the bad node is phantom (`assert_false(can_collect(bad_id))`, not rendered), **exactly one** warning via the sink (`sink.warning_count == 1`) whose message contains the bad node's `loot_id`, **and both valid nodes remain collectable** (`assert_true(can_collect(&"valid_1"))` AND `assert_true(can_collect(&"valid_2"))`). Discriminators: a fail-hard impl that aborts the whole load fails the valid-node assertions; a fail-open impl that includes the bad node fails the phantom assertion; a composed-into-one-catalog reading produces 3 warnings and fails the count. *(Rule 6; WL-PRED-2 per-node clause; EC-WL-04/05/06)*

**AC-WL-06** (BLOCKING, Unit) — **Snapshot sort contract + Dictionary envelope + fresh-copy.** **GIVEN** keys inserted in the order `&"z_node"` → `&"a_node"` → `&"m_node"` (non-alphabetical insertion, normative — makes intern order diverge from alphabetical so both the insertion-order bug and the raw-StringName-sort bug produce wrong output), **WHEN** `snapshot()` is called, **THEN** the result is exactly `{ "collected": [&"a_node", &"m_node", &"z_node"] }` — assert with `&`-prefixed **StringName literals** (comparing against plain-String literals would let an `Array[String]` impl pass by GDScript's implicit StringName↔String `==` coercion, violating the type contract). Add a type guard: `assert_true(result is Dictionary)`, `assert_true(result["collected"] is Array)`, and `assert_true(result["collected"][0] is StringName)`. **Fresh-copy sub-fixture:** mutate the returned `result["collected"]` Array, call `snapshot()` again → second result still `{ "collected": [&"a_node", &"m_node", &"z_node"] }` (guards against an impl returning an internal Array reference rather than a per-call fresh Dictionary literal). **Empty sub-fixture:** empty Set → `assert_eq(result, {"collected": []})` and `assert_true(result["collected"] is Array)` (not merely `assert_not_null` — an empty Array, empty Dictionary, and `false` are all non-null; the type + value must both be checked). *(WL-PRED-3; Rule 7 snapshot clause)*

**AC-WL-07** (BLOCKING, Unit) — **Empty-state round-trip.** `snapshot()` on a fresh instance → `{"collected": []}`; **both** `restore({})` and `restore({"collected": []})` → empty Set, no error, `sink.warning_count == 0` (assert the concrete zero — a spurious "empty restore" warning must fail this). The `restore({})` case is exactly what EP hands this domain under wrong-type/missing handling (EP Rule 6d, AC-EP-07) — WL must treat a missing `collected` key as empty, not error. This is the new-game state. *(EC-WL-08; Rule 7 restore clause)*

**AC-WL-08** (BLOCKING, Unit) — **Orphan preservation.** **WHEN** `restore({"collected": [&"known_id", &"orphan_a", &"orphan_b"]})` runs where only `known_id` exists in the catalog, **THEN** the Set contains all three (`size == 3`), one warning via the sink reports the orphans, and `snapshot()` returns `{"collected": [&"known_id", &"orphan_a", &"orphan_b"]}` (sorted, StringName literals). **Round-trip sub-fixture:** that snapshot restored on a fresh instance still carries both orphans **and re-emits sorted** — assert `snapshot() == {"collected": [&"known_id", &"orphan_a", &"orphan_b"]}` on the round-tripped instance (not merely `size == 3`; an insertion-order-preserving impl passes the size check but fails the sort re-validation). Discriminating line: `assert_eq(size, 3)` — a drop-unknown-IDs impl fails it (losing a collected fact is the anti-fantasy). *(Rule 7 restore clause; EC-WL-07; EP Rule 6c)*

**AC-WL-09** (BLOCKING, Unit) — **Refusal + retry leaves no residue.** **The Inventory stub's add-call counter is NOT reset between the two legs** — the assertions read one continuous counter so a stray add-call in the refusal leg cannot be hidden. **GIVEN** the Inventory stub configured to reject (Rule 9.2 seam), **WHEN** `collect(loot_id)` runs, **THEN** exactly one `collect_refused` fires with the correct payload (`assert_signal_emitted_with_parameters(self, "collect_refused", [loot_id, <non-empty reason>])`), the Set is unmutated, `stub.add_call_count == 0`, and `can_collect(loot_id)` still returns `true`; **WHEN** the stub is reconfigured to accept and `collect()` retried (counter still not reset), **THEN** `node_collected` fires, the Set contains `loot_id`, and `stub.add_call_count == 1` (exactly one add-call *total across both legs* — a double-award-in-refusal-path impl reads 2 here). Discriminator: an impl that marks collected despite refusing (wrong guard order) fails the mid-sequence `can_collect == true`. *(Rule 8; EC-WL-09/10)*

**AC-WL-10** (BLOCKING, Unit) — **Restore replaces, never merges.** Restore `{"collected": [&"chest_a", &"chest_b"]}`, then restore `{"collected": [&"chest_c"]}` → Set is exactly `{chest_c}` (`size == 1`), and the second restore emits no spurious warning (`sink.warning_count == 0` — a "restore called twice" warning would be wrong; replacement is normal). The discriminating line: `assert_false(collected_set.has(&"chest_a"))` — a merge-based restore passes every single-restore test and fails only here. *(Rule 7; EP Rule 3 replacement semantics)*

**AC-WL-11** (BLOCKING, Unit) — **Permanence survives a session round-trip (both logic AND derived visual state).** Collect a node → `snapshot()` → **fresh WL instance** (same catalog) → `restore(snapshot)` → assert **both**: (1) `can_collect(loot_id) == false` (logic layer), **and** (2) `get_node_state(loot_id) == LootNode.State.COLLECTED` (derived visual state, per Rule 9.4). The second assertion is the discriminator and the reason it is separate: an impl that restores the Set correctly (passing assertion 1) but never re-derives the per-node visual state from the restored Set ships a **visible desync** — the chest renders closed/available while collection truth says taken. Asserting only `can_collect` misses exactly this bug. This is the "never reappears" guarantee of Rule 3 crossing a simulated restart — distinct from AC-WL-10 (replacement semantics in isolation). *(Rule 3; Rule 9.4; States and Transitions)*

**AC-WL-12** (ADVISORY, Unit) — **`rederive()` is a safe no-op.** **GIVEN** a populated collected Set, **WHEN** `rederive()` is called, **THEN** the Set is unchanged, no error, no signal. Advisory: a no-op is trivially correct — the test only guards against an impl that wipes state. *(Rule 7 rederive clause)*

**EC↔AC Cross-Check:** EC-WL-01 → AC-02 · EC-02 → AC-03 · EC-03 → AC-04 · EC-04/05/06 → AC-05(a/b/c) · EC-07 → AC-08 · EC-08 → AC-07 · EC-09 → AC-09 · EC-10 → AC-09 (retry leg) · EC-11 → delegated (EP AC-EP-08A) · EC-12 → no AC by design (structural impossibility, owned by Overworld Navigation). **All 12 ECs covered, delegated, or explicitly no-AC-by-design.**

**Summary: 11 BLOCKING unit + 1 ADVISORY.** Every core rule (1–9) and predicate (WL-PRED-1/2/3) has ≥1 AC. Anti-hardcoding: all fixtures use synthetic IDs. GDScript traps addressed: StringName intern-order sort (AC-06 normative insertion order), StringName↔String `==` coercion masking an `Array[String]` impl (AC-06 `&`-prefixed StringName literals + `is StringName` type guard), `push_warning` non-capturability (Rule 9.1 sink), EP Dictionary-envelope snapshot contract (AC-06/07/08/10/11 use `{"collected": [...]}` form — a bare Array refuses every save, Rule 7), per-call fresh Dictionary vs internal-Array aliasing (AC-06 fresh-copy), per-node vs total signal/add-call counting (AC-01 per-node, AC-09 non-reset counter), warning-content assertions (AC-03/05 `.contains(id)`), sink-silence concrete counts (AC-02/07/10 `warning_count == 0`), derived-visual-state desync after restore (AC-11 `get_node_state()` per Rule 9.4 — the highest-risk shipping bug), signal double-fire (`assert_signal_emit_count` in AC-01).

## Open Questions

- **OQ-WL-1 — Hidden-node detection radius.** `is_hidden` reveal distance is a feel value owned by Overworld Navigation (it owns player position and proximity). This GDD only requires *that* a reveal moment exists. *Owner: Overworld Navigation (#16) authoring.*
- **OQ-WL-2 — Renewable world resources (post-MVP).** MVP world loot is strictly one-time. A future renewable node type (respawning material nodes, weekly chests) would need a different ledger model (timestamps, not a flat Set) — explicitly out of scope; revisit at Alpha alongside Endgame Loop (#27). *Owner: game-designer, Alpha.*
- **OQ-WL-3 — BLUEPRINT un-reserve.** When Blueprint Crafting (#25) ships, define the `BLUEPRINT` payload shape and whether blueprint nodes are `is_hidden`-only ("very difficult to find" per design intent). *Owner: #25 authoring, Alpha.*
- **OQ-WL-4 — Consumable world-loot supply co-balances with Drop System OQ-DS-7.** World-loot CONSUMABLE nodes are a second, unmodeled consumable faucet (the first being combat drops, whose frequencies are open in Drop System OQ-DS-7). Authors should not finalize consumable node content — especially any Rare-tier consumable such as the Salvage Beacon — until OQ-DS-7 resolves, since world-loot and combat-drop consumable supply must be balanced together. Interim guidance: keep world-loot consumables to Common-tier salvage items; treat a Rare-tier consumable node as equivalent to a RARE PART node against the zone's 1–3 cap. *Owner: economy-designer, alongside OQ-DS-7.*
