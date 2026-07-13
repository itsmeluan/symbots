# World Loot System

> **Status**: In Design
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

**Rule 5 — `loot_id` global uniqueness is a hard content constraint.** The Exploration Progress domain is a flat global Set: there is no per-zone namespace in the collection ledger. Two LootNodes sharing a `loot_id` (even in different zones) would collapse to a single collected-state bit. World Loot performs a uniqueness validation pass at content load time: duplicate `loot_id`s are a **fatal content error** (load aborts, loud error), not a silent de-dupe.

**Rule 6 — BLUEPRINT reward type is reserved for Alpha.** The `BLUEPRINT` enum value is defined in schema now so content tooling can be extended without a breaking schema change. Authoring a `BLUEPRINT` node in MVP content is a **content error** (logged, node treated as INVALID). Blueprint Crafting (#25, Alpha) un-reserves this type when it ships.

**Rule 7 — EP domain contract (this system is the `&"world_loot"` domain).** This system implements the three-operation Exploration Progress domain contract:
- `snapshot()` → sorted `Array[StringName]` of all collected `loot_id`s (sorted via `String(a) < String(b)` — raw StringName sort is session-unstable); returns a fresh copy (no aliasing of the internal set).
- `restore(data: Array)` → replaces (never merges) the runtime collected Set with `Set(data)`, deduping on reconstruction.
- `rederive()` → no-op (the collected Set is a source fact, not a derived field — there is nothing to re-derive from it).

**Rule 8 — Collection refusal on full inventory.** Before awarding, `collect()` verifies the reward can be **fully deposited** (Scrap: `current + amount ≤ SCRAP_MAX`; consumable: stack space available; parts: always accepted — instances are uncapped). If the deposit would be rejected or truncated, the collect is **REFUSED**: no reward, `loot_id` NOT added to the collected Set, node stays UNCOLLECTED, and a `collect_refused(loot_id, reason)` signal fires for UI feedback ("Scrap storage full"). The reward is never partially awarded and never destroyed — the player can free space and return.

### States and Transitions

Each `LootNode` has exactly two states:

| State | Meaning | Visual |
|-------|---------|--------|
| `UNCOLLECTED` | Default; reward available | Closed chest / glowing indicator |
| `COLLECTED` | Permanently after `collect()` | Open chest / no indicator |

State is not serialized directly — it is **derived** from the runtime collected Set (if `loot_id ∈ collected_set` → COLLECTED; else UNCOLLECTED). On load, `restore()` re-populates the Set; the visual state of every node updates from that Set. There is no intermediate or transient state.

Content-error state: if a `LootNode`'s `loot_id` resolves to no catalog entry (removed content, authoring error), it is treated as a **phantom node** — not rendered, not collectable, no crash.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Part Database** (upstream) | This system reads `part_id` → validates the reward part exists; reads `display_name` + `sprite_id` for the reward reveal popup. `drop_enabled = false` does NOT block collection — world loot is hand-placed, not drop-table-sourced. | Hard dependency |
| **Consumable Database** (upstream) | Reads `consumable_id` → validates the reward item exists. | Hard dependency |
| **Zone & World Map** (upstream) | Groups `LootNode` entries by `zone_id`; on zone load, provides the list of nodes in that zone (both UNCOLLECTED and COLLECTED) to Overworld Navigation. Never reads ZWM at runtime — `zone_id` is a static reference on each node. | Soft — zone grouping only; this system can initialize without ZWM present |
| **Inventory** (downstream) | `collect()` calls Inventory's add-part / add-scrap / add-consumable interface. This system does not own Inventory state — it writes awards and trusts Inventory's own overflow/stack rules. | Hard at collection time |
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

`collect(loot_id)` awards + records **iff** `can_collect(loot_id)` is `true`; otherwise it is a silent no-op (Rule 4). The guard is evaluated inside `collect()` itself — callers are not required to pre-check.

### WL-PRED-2 — Catalog validity invariant (startup/content-pipeline only — never in the collect path)

```
valid_catalog = ∀ node ∈ catalog:
    node.loot_id is a non-empty StringName
AND node.reward_type ∈ {PART, SCRAP, CONSUMABLE}          # BLUEPRINT authored in MVP = content error (Rule 6)
AND node.reward_payload resolves for its reward_type       # part_id in Part DB / amount ≥ 1 / consumable_id in Consumable DB
AND node.zone_id references an existing ZoneNode
AND no two nodes share a loot_id                           # global uniqueness — fatal on violation (Rule 5)
```

**Output:** boolean per node + one global uniqueness check. Runs **once at content load** (or in a CI content-validation step), never at collect-time — `collect()` must stay a pure hash-lookup hot path with no linear scans. Per-node failures degrade that node to phantom (logged, skipped); a `loot_id` duplicate is **fatal** (Rule 5).

### WL-PRED-3 — Snapshot sort contract (locked by Exploration Progress Rule 1)

```
snapshot() = collected.keys() sorted by: func(a, b): return String(a) < String(b)
```

**Output:** sorted `Array[StringName]`, fresh copy (no aliasing). The `String()` cast is **load-bearing and normative**: raw `StringName` `<` compares session-unstable intern indices — dropping the cast produces a non-deterministic sort across launches and breaks save-file comparability. This contract is owned by Exploration Progress (Rule 1, AC-EP-01); it is restated here because this system is the implementer. An empty collected Set returns `[]` (empty Array, never null).

## Edge Cases

- **EC-WL-01 — Double-collect.** *If* `collect(loot_id)` is called and `loot_id` is already in the collected Set: silent no-op — no reward, no signal, no error (Rule 4, WL-PRED-1). *Verified by AC-WL-02.*

- **EC-WL-02 — Collect on unknown `loot_id`.** *If* `collect()` is called with a `loot_id` absent from the catalog (stale reference from Overworld Navigation, removed content): no-op + **content warning** logged via the injectable sink (this indicates a caller bug, unlike EC-WL-01 which is legal). No crash, no Set mutation. *Verified by AC-WL-03.*

- **EC-WL-03 — Duplicate `loot_id` in catalog.** *If* two `LootNode` entries share a `loot_id`: **fatal content error at load** — load aborts loudly (Rule 5, WL-PRED-2). Not a first-wins de-dupe: a shared collected-bit corrupts the permanence promise silently, so it must never reach a player. *Verified by AC-WL-04.*

- **EC-WL-04 — BLUEPRINT node authored in MVP.** *If* MVP content contains a `reward_type = BLUEPRINT` node: content error logged, node degraded to **phantom** (not rendered, not collectable). Not fatal — one bad node shouldn't block the game (Rule 6). *Verified by AC-WL-05.*

- **EC-WL-05 — Reward payload does not resolve.** *If* a `PART` node's `part_id` is not in the Part Database, a `CONSUMABLE` node's `consumable_id` is not in the Consumable Database, or a `SCRAP` node's `amount < 1`: WL-PRED-2 fails for that node → **phantom** (logged, skipped). Other nodes unaffected. *Verified by AC-WL-05.*

- **EC-WL-06 — `zone_id` references a non-existent zone.** *If* a node's `zone_id` matches no ZoneNode: **phantom** + content warning. The node has nowhere to render; it must not crash zone loading. *Verified by AC-WL-05.*

- **EC-WL-07 — Orphaned collected IDs on restore.** *If* `restore()` receives `loot_id`s that match no catalog entry (content removed after the save was written): they are **preserved in the Set and written back on next snapshot** — never dropped (EP Rule 6c preserve-and-warn; losing a collected fact is the anti-fantasy). One warning logged naming the orphan count. If the content is later re-added, the node correctly restores as COLLECTED. *Verified by AC-WL-08.*

- **EC-WL-08 — Empty collected Set.** `snapshot()` on an empty Set returns `[]` (empty Array, never null); `restore([])` produces an empty Set without error. This is the new-game initial state. *Verified by AC-WL-07.*

- **EC-WL-09 — Inventory cannot fully accept the reward.** *If* the deposit check fails (Scrap would exceed `SCRAP_MAX`, consumable stacks full): collect is **REFUSED** per Rule 8 — no reward, no Set mutation, node stays UNCOLLECTED, `collect_refused(loot_id, reason)` fires. Retry after freeing space succeeds normally. *Verified by AC-WL-09.*

- **EC-WL-10 — Refused-then-retried collect.** *If* a collect was refused (EC-WL-09) and the player frees space and interacts again: the second `collect()` succeeds normally — refusal leaves no residue state. *Verified by AC-WL-09 (part b).*

- **EC-WL-11 — `restore()` with duplicate IDs in the Array.** *If* the serialized Array contains duplicates (corrupt/tampered save): deduped automatically on Set reconstruction (EP already owns the warning — EC-EP-07/AC-EP-08). This system's `restore()` is naturally idempotent per key. *Delegated — verified by EP AC-EP-08.*

- **EC-WL-12 — Collect fires mid-battle or outside the owning zone.** Cannot occur by construction: Overworld Navigation owns the interact gesture and only enables it for nodes in the currently loaded zone during overworld play. This system performs no additional context check — stated so reviewers don't flag the absence. *No AC by design (structural impossibility, owned by Overworld Navigation).*

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
- **Exploration Progress** lists World Loot as upstream (soft-provisional, "the contract #13 must satisfy") ✓ — that row's provisional marker can be discharged now (light EP erratum: mark the `&"world_loot"` row "Authored — contract implemented"; one line).
- **Consumable Database erratum (light, owed on approval):** Consumable DB predates this system — add World Loot to its downstream readers (consumables as world-loot rewards). One line.
- **Inventory erratum (light, owed on approval):** Inventory predates this system — add World Loot as a caller of its add interfaces (and note the Rule 8 pre-deposit check consumes the `{accepted, rejected}` Scrap contract). One line.
- **Systems index update:** #13's Depends On column currently reads "Part Database, Zone & World Map" — should become "Part Database, Consumable Database, Inventory, Zone & World Map" (handled at index update).

## Tuning Knobs

This system owns no runtime balance constants. Its knobs are **content-authoring levers** on the catalog, plus one economy coupling that needs a guardrail.

| Knob | Type | Owner | Effect / Safe guidance |
|------|------|-------|------------------------|
| Node count per zone | Content | This system | How reward-dense exploration feels. MVP starter zone target: **6–10 nodes**. Too few → exploration feels unrewarded (Pillar 5 violation); too many → world loot competes with the combat harvest loop as the primary acquisition route (Pillar 2 erosion). |
| Reward mix (PART / SCRAP / CONSUMABLE ratio) | Content | This system | MVP guidance: majority consumables + Scrap, **1–3 PART nodes per zone** with at most one Rare. Parts are the combat loop's payoff — world loot parts should feel exceptional, not routine. |
| `SCRAP` node `amount` | Content | This system | Per-node range guidance: **10–60** (roughly one to three WILD victories' worth per Drop System `SCRAP_YIELD`: Common 5 / Rare 20). **Economy guardrail:** total world-loot Scrap in a zone should stay under ~10% of that zone's expected combat-arc Scrap (~1,800 for the MVP arc, ESTIMATED per Drop System) — world loot is a supplement, never a faucet that competes with the victory economy. ADVISORY: re-check with economy-designer whenever zone totals change. |
| `is_hidden` ratio | Content | This system | What fraction of nodes are hidden until approach. MVP guidance: **~1/3 hidden**. All-visible → no discovery beat; all-hidden → players never learn world loot exists (onboarding failure). |
| Part rarity ceiling for world loot | Content | This system | MVP: **COMMON and RARE only**. BOSS_GRADE and PROTOTYPE parts must stay exclusive to their earn paths (boss kills, pity systems — Drop System). A world chest bypassing the Boss-grade hunt would break Pillar 2's promise that mastery earns the top rewards. |

**Cross-referenced knobs (owned elsewhere, affect this system):**

| Knob | Owner | Relevance here |
|------|-------|----------------|
| `SCRAP_MAX` | Inventory | The Rule 8 refusal boundary for SCRAP rewards. Raising it makes refusals rarer; this system never redefines it. |
| `max_stack` (per consumable) | Consumable Database | The Rule 8 refusal boundary for CONSUMABLE rewards. |
| `SCRAP_YIELD` (5/20/35/60) | Drop System | The benchmark that keeps world-loot Scrap amounts proportionate (see `amount` guidance above). |

**Warning — level_requirement interaction.** A PART node can contain a part whose `level_requirement` exceeds the player's cores when found (e.g., a RARE part needing core level 3 found at level 1). This is **intended** — the part sits in inventory as a goal ("level up to equip this"), consistent with Core Progression's gating model. Do not author around it; it's a feature, not a trap.

## Visual/Audio Requirements

This system owns the **chest/pickup presentation states** (per EP's Visual/Audio delegation: "World Loot owns chest opened/closed visuals").

**Node visual states (must be readable at overworld zoom):**
- `UNCOLLECTED`: closed pickup with a subtle idle animation (glow pulse or lid shimmer) — discoverable but not screaming. Silhouette must read as "container" instantly (game concept: part readability at a glance applies to world objects too).
- `COLLECTED`: open/emptied version of the same asset, permanently visible in the world — **never removed from the scene**. The open chest is the "world remembers" beat (EP Player Fantasy); despawning it would make the world feel like scenery.
- `is_hidden` reveal: when a hidden node enters detection range, a brief reveal effect (shimmer-in + soft chime). The reveal is its own micro-reward — it says "your curiosity was detected."

**Collection feedback:**
- Open animation on the node + a **reward reveal popup**: part sprite (via Part DB `sprite_id`), display name, rarity-coded frame. Rarity color language must match the game-wide rarity/element coding (game concept: consistent color language; boss parts glow).
- Audio: open stinger + reward sting **scaled by rarity** — COMMON modest, RARE emphatic. Same escalation grammar the Drop System loot screen will use (keep them consistent — one vocabulary for "you got a thing" across combat and world).
- Refusal (Rule 8): a distinct blocked cue (short buzz + "Scrap storage full" toast). Must not resemble the collect sound — the player needs to know nothing was consumed.

> *(Note: `art-director` not consulted — Lean mode. Review against the art bible when it exists; per-asset work via `/asset-spec system:world-loot` after art bible approval.)*

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:world-loot` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

- **Reward reveal popup**: touch-first (min 44×44pt dismiss target), tap-anywhere-to-dismiss, shows part/consumable/Scrap awarded. Owned by the overworld HUD layer (Overworld Navigation's UI pass), reading this system's `node_collected` signal payload.
- **Refusal toast**: reads `collect_refused(loot_id, reason)` → short non-blocking toast ("Scrap storage full"). No modal — don't interrupt exploration.
- **Anti-checklist constraint (normative):** no UI surface may display world-loot completion counts or percentages ("12/14 chests") — not on the world map, not in menus. Uncollected nodes get **no map markers**. Discovery is the reward; the ledger is memory, not a checklist. This is this GDD's enforcement of the game concept anti-pillar (and discharges the EP review backlog item "anti-checklist → explicit delegation to #13").

> **📌 UX Flag — World Loot**: the reward reveal popup + refusal toast have UI requirements. In Pre-Production, fold them into the overworld HUD UX spec (`/ux-design` for `design/ux/overworld-hud.md` or equivalent) before writing UI stories.

## Acceptance Criteria

[To be designed]

## Open Questions

- **OQ-WL-1 — Hidden-node detection radius.** `is_hidden` reveal distance is a feel value owned by Overworld Navigation (it owns player position and proximity). This GDD only requires *that* a reveal moment exists. *Owner: Overworld Navigation (#16) authoring.*
- **OQ-WL-2 — Renewable world resources (post-MVP).** MVP world loot is strictly one-time. A future renewable node type (respawning material nodes, weekly chests) would need a different ledger model (timestamps, not a flat Set) — explicitly out of scope; revisit at Alpha alongside Endgame Loop (#27). *Owner: game-designer, Alpha.*
- **OQ-WL-3 — BLUEPRINT un-reserve.** When Blueprint Crafting (#25) ships, define the `BLUEPRINT` payload shape and whether blueprint nodes are `is_hidden`-only ("very difficult to find" per design intent). *Owner: #25 authoring, Alpha.*
