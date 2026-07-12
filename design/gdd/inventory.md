# Inventory System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 1 (Engineer, Don't Collect), Pillar 3 (Build Depth Over Content Breadth)

## Overview

The **Inventory System** is the per-save store of everything the player has collected but not yet committed to a build: their **part instances**, their **stackable consumables**, and their **Scrap** balance. It is the single source of truth for *what the player owns*, sitting between the systems that produce items (Drop System, World Loot) and the systems that consume them (Workshop, part upgrading, in-battle item use). It holds two fundamentally different storage models under one roof: **parts are individual instances** — every copy is a distinct object with its own upgrade tier, never stacked or deduplicated, because two copies of the same part are genuinely different tools once you tier them differently and equip them on different Symbots (Part DB EC-05, DB5). **Consumables are stackable counts** — a quantity per item id, capped by the item's `max_stack`, because one Repair Kit is interchangeable with another. The system owns the operations the player performs on that store: acquiring items (and resolving what happens when a stack overflows its cap), scrapping surplus parts into currency, and querying holdings for the Workshop and Combat UIs. Beyond the plumbing, the inventory is where **Pillar 1 (Engineer, Don't Collect)** becomes tangible: opening it is opening a box of *hypotheses* — the untested Volt core, the third copy of an arm you could tier up, the boss part no one else has found. Crucially it is a **workbench, not a trophy case** — there is no completion counter, no "gotta collect them all" (anti-pillar); every item is present because it *could go into a build*, and surplus exists to be scrapped and reinvested, never to be hoarded for a checklist.

## Player Fantasy

The player never thinks "I am managing a data store." They think: *"I've got two of that arm now — I could tier one up for the Volt build and leave the other stock for the Kinetic one."*

The Inventory's fantasy is the **well-stocked workbench** — the quiet, grounding pleasure of a builder surveying their materials before they make something. In a build-craft game the inventory is where potential lives: every part sitting in it is a build you *haven't made yet*. The reference feeling is the Monster Hunter item box or the Path of Exile stash at its best — not a chore screen, but a place you actually *like* opening because it's dense with things you're excited to use. When the player returns from a hunt and drops three new parts into the box, the feeling should be *"what can I build now?"* — not *"where do I put this?"* The inventory serves the loop's turnaround: the moment between *collected* and *committed*, where a hypothesis gets picked up off the shelf.

Two feelings do the work:

1. **Possibility, not accumulation.** Opening the inventory should feel like opening a box of hypotheses, never like checking a completion list. This is Pillar 1 made physical — the parts are yours because you *hunted and will build* them, not because they fill a registry. The system deliberately withholds the collector's dopamine loop (no "12/50 discovered!", no dex): the reward for a duplicate is *"another tool"* or *"more Scrap to reinvest,"* never *"+1 toward 100%."* A player who hoards for a checklist is playing a game we didn't build; a player who scraps a surplus Common to tier up their main is playing exactly the one we did.

2. **Frictionless when working, invisible when full.** The other half of the fantasy is one the player should barely notice — the inventory just *holds* things, correctly, across sessions, without ever making the player fight it. Parts never silently merge or vanish; a stack that hits its cap resolves in a way the player understands and chooses, not a lossy surprise. Good inventory infrastructure is felt only in its absence — the fantasy breaks the instant a player loses a part to a bug or can't find the copy they tiered. So the emotional target here is split: a *warm* direct layer (the workbench you enjoy) over *rock-solid* plumbing (the store you can trust).

This is delivered jointly with the Inventory UI (touch-first browsing, sorting, the scrap action) and the Workshop (where holdings become builds) — this GDD builds the model and the rules those surfaces present.

## Detailed Design

### Core Rules

**Rule 1 — Three stores.** The Inventory holds exactly three logical stores per save:
- **`part_instances`** — a collection of `PartInstance` records (**uncapped** in MVP; Part DB EC-05).
- **`consumable_stacks`** — a map `consumable_id → quantity` (int, one logical count per id, `0 ≤ quantity ≤ max_stack`).
- **`scrap`** — a single non-negative integer currency balance (the game's sole currency; the Drop System economy / HOLISM-01 owns *yields and targets*, Inventory owns the *running balance*).

**Rule 2 — `PartInstance` schema.** Every part the player owns is a distinct instance:

| Field | Type | Notes |
|-------|------|-------|
| `instance_id` | int (StringName-safe) | Unique per-save, **stable, never reused** — the handle Workshop/UI reference |
| `part_id` | StringName | → Part DB definition (immutable; validates against Part DB) |
| `upgrade_tier` | int | Per-instance, `0 … max_upgrade_tier` (Part DB: 0–3 Common / 0–5 Rare+); mutated only by the upgrade path |

Instances are **never merged, stacked, or deduplicated** (Part DB EC-05). Two instances of the same `part_id` are fully independent. Equipped state is **not** a field here — it is owned by Workshop and *queried* (Rule 5).

**Rule 3 — Consumable stacks.** Consumables are stored as a single count per `consumable_id`, `0 ≤ quantity ≤ max_stack` (max_stack read-only from Consumable DB). A quantity of 0 means "none held" — an absent key is equivalent to 0. Inventory owns only the count; the definition (name, effect, cap) lives in Consumable DB.

**Rule 4 — Acquisition (`add`).** When an item enters inventory (Drop System, World Loot, future shop):
- **Part** → append a new `PartInstance` with a fresh `instance_id` and the dropped tier (default 0). Always succeeds (uncapped).
- **Consumable** → increment that id's count toward `max_stack`. If the add would exceed `max_stack`, the count is set to `max_stack` and the **excess is rejected** — not stored, not converted (no Scrap in MVP). The call returns `{accepted, rejected}` so the awarding system can surface a "stack full" notice. No silent loss (the reject is reported). *This resolves Consumable EC-CD-12 and un-blocks AC-CD-23.*
- **Scrap** → add to the balance (clamped at `SCRAP_MAX`, Tuning Knobs).

**Rule 5 — Scrapping a part.** The player may, by **explicit choice**, scrap a part instance: it is permanently removed from `part_instances` and the balance gains Scrap per the scrap-value formula (INV-1, Section D). Scrapping is:
- **Manual only** — never automatic (Part DB DB5: "scrapped at the player's choice, never auto").
- **Irreversible** — the instance is destroyed; no undo (the confirm dialog belongs to UI).
- **Blocked on equipped instances** — an instance currently equipped on any Symbot (per Workshop's equipped set) is **not scrappable**; the operation is rejected and the instance is untouched. The player must unequip in Workshop first. This is the safety guard that protects an in-use part.

**Rule 6 — Consumable use decrement.** On a **successful** consumable apply (TBC in-battle Rule 7a, or overworld use), Inventory decrements that id's count by 1. A **rejected** use (Consumable Rule 3) decrements nothing. Inventory refuses to decrement below 0 (EC-CD-04: nothing to use at quantity 0). Use *validation* (target/context) is owned by TBC/Consumable; Inventory owns only the count and the decrement.

**Rule 7 — Query interface (read-only, no mutation).**
- `get_parts(filter?) → [PartInstance]` — optionally filtered by `slot_type` / `rarity` / `part_family` (Workshop & UI)
- `get_consumable_count(id) → int`  ·  `get_scrap() → int`
- `has_instance(instance_id) → bool`  ·  `get_instance(instance_id) → PartInstance`
- `is_scrappable(instance_id) → bool` — false if the instance is equipped or missing

**Rule 8 — Ownership boundary (what Inventory does NOT do).** Does not: define parts/consumables (Databases); set drop frequency or the economy *target* (Drop System / HOLISM-01); equip/unequip or *store* equipped state (Workshop — Inventory only *queries* it for the Rule 5 guard); raise a part's tier (the upgrade path spends Scrap and mutates `upgrade_tier` — Inventory owns the field, not the upgrade logic); render, sort, or confirm in UI (Inventory/Combat UI); serialize to disk (Save/Load — Inventory defines the in-memory model it persists).

### States and Transitions

Inventory is a data store, not a state machine. The only lifecycle is a light one on `PartInstance`:

| State | Meaning | Enters via | Exits to |
|-------|---------|------------|----------|
| **HELD** | in inventory, not on a Symbot | `add` (acquire); Workshop unequip/displace | EQUIPPED (Workshop equip); SCRAPPED (player scrap) |
| **EQUIPPED** | installed on a Symbot (**Workshop-owned overlay**, seen via query) | Workshop equip | HELD (Workshop unequip/displace) |
| **SCRAPPED** | destroyed for Scrap (**terminal**) | player scrap of a HELD instance | — |

Scrapping an EQUIPPED instance is **blocked** (Rule 5) — the only guarded transition. Consumable counts are a plain int in `[0, max_stack]` (+N capped on acquire, −1 on successful use); the Scrap balance is an int in `[0, SCRAP_MAX]` (+yield on scrap/drop, −cost on upgrade / future purchase). Neither has sub-states.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Part Database** *(Approved)* | ← reads | Part definitions (`id`, `display_name`, `rarity`, `slot_type`, `part_family`, `flavor_text`, `max_upgrade_tier`, `upgrade_effects`) to validate `part_id` and display instances |
| **Consumable Database** *(Approved)* | ← reads | Consumable definitions (`id`, `display_name`, `rarity`, `max_stack`, use-context, effect metadata). Rule 4 enforces `max_stack` — **resolves EC-CD-12, un-blocks AC-CD-23** |
| **Drop System** *(Approved)* | → deposits | Awards part instances, consumable increments, and Scrap via `add` (Rule 4); receives `{accepted, rejected}` for stack-full feedback |
| **World Loot System** *(Not Started)* | → deposits | Same `add` interface for overworld chests/pickups |
| **Workshop System** *(Not Started)* | ↔ | Reads holdings (`get_parts`/`get_instance`) to build; **owns the equipped-instance set** Inventory queries for the Rule 5 scrap guard; mutates a `PartInstance.upgrade_tier` when upgrading (spending Scrap) |
| **Turn-Based Combat** *(Approved erratum)* | → decrements | On a successful in-battle item apply (TBC Rule 7a), calls Inventory to decrement a consumable count by 1 (Rule 6); rejected use decrements nothing. Wiring realized at TBC integration |
| **Save/Load System** *(Not Started)* | → serializes | Persists/restores the three stores; Inventory defines the serialization-friendly model (flat records, stable `instance_id`s) |
| **Inventory UI / Combat UI** *(Not Started)* | → surfaced by | Render holdings, sort/filter, scrap-confirm flow, stack-full notices |

*Provisional: Workshop / World Loot / Save/Load / UI are Not Started — their interface columns are the contract this GDD exposes for them. Part DB, Consumable DB, Drop System are Approved.*

## Formulas

Inventory owns **exactly one formula** — the consumable overflow split (INV-1). The Scrap gained from scrapping a part is **not an Inventory formula**: it references the Drop System's `SCRAP_YIELD[rarity]` (owned there, Drop Rule 9). **No formula here uses `floor()`/`ceil()` or floats** — INV-1 is pure integer `min`/subtraction, so no epsilon nudge and no python3 float scan is required.

### INV-1 — Consumable overflow split

`accepted = min(qty, max_stack − current)`
`rejected = qty − accepted`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `current` | int | [0, max_stack] | Count already in the stack before this add |
| `qty` | int | [0, ∞) | Incoming quantity being added |
| `max_stack` | int | {5, 10, 20} | Per-rarity ceiling (Prototype 5 / Rare 10 / Common 20), read from Consumable DB |
| `accepted` | int | [0, max_stack] | Units written into the stack |
| `rejected` | int | [0, qty] | Units surfaced as excess ("stack full" notice) |

**Output range:** both non-negative integers; **invariant `accepted + rejected = qty`** — no unit is ever silently lost. `max_stack − current ≥ 0` always (current is bounded by max_stack), so `accepted ≥ 0`; `accepted ≤ qty`, so `rejected ≥ 0`. No divide, no float, no degenerate output.

**Boundary cases:**

| Scenario | current | qty | max_stack | accepted | rejected |
|----------|---------|-----|-----------|----------|----------|
| Normal partial fill | 7 | 8 | 20 | 8 | 0 |
| Already full, any qty | 20 | 5 | 20 | 0 | 5 |
| qty = 0 (no-op) | 10 | 0 | 20 | 0 | 0 |
| qty huge | 3 | 999 | 20 | 17 | 982 |
| Exact fill (current+qty == cap) | 15 | 5 | 20 | 5 | 0 |
| Empty stack, full drop | 0 | 20 | 20 | 20 | 0 |

**Worked example (discriminating — `accepted ≠ qty`, `rejected > 0`):** `current = 14, qty = 9, max_stack = 20` → `accepted = min(9, 6) = 6`, `rejected = 3`. The stack lands at 20 and a "stack full (+3 lost)" notice fires.

### Scrap yield (referenced — owned by Drop System)

`scrap_value(part) = SCRAP_YIELD[part.rarity]` — **independent of `upgrade_tier`** in MVP.

| Rarity | `SCRAP_YIELD` | Owner |
|--------|--------------|-------|
| COMMON | 5 | Drop System (Rule 9 / Tuning Knobs) |
| RARE | 20 | Drop System |
| PROTOTYPE | 35 | Drop System |
| BOSS_GRADE | 60 | Drop System |

Inventory **imports these by name; it does not define or shadow them** (redefining would conflict with the Drop System's owned tuning knobs + invariant `COMMON < RARE < PROTOTYPE < BOSS_GRADE`, AC-DS-19). Scrapping a *tiered* part yields the flat per-rarity value — the invested upgrade Scrap is **not** refunded in MVP (a total sink; upgrade costs are Alpha/undefined, so a partial-refund formula cannot be specified now). Whether a future tier refund exists is **OQ-INV-1**, deferred to the Part Upgrade System (Alpha), which would own any `calculate_scrap_value(part_instance)` refund logic Inventory then calls.

## Edge Cases

- **EC-INV-01 — Consumable stack overflow (INV-1 reject).** Acquiring a consumable that would push a stack past `max_stack`: the count is clamped to `max_stack`, the excess is **rejected** (not stored, not converted), and `add` returns `{accepted, rejected}` so the caller fires a "stack full" notice. Sub-cases: **partial** (`current=14, qty=9, cap=20` → accepted 6, rejected 3); **already full** (`current=20` → accepted 0, all rejected). No silent loss — the reject is always reported. *Verified by AC-INV-01. Resolves Consumable EC-CD-12; un-blocks AC-CD-23.*
- **EC-INV-02 — Scrap an equipped part (blocked).** A scrap request on an instance in Workshop's equipped set is **rejected**; the instance is untouched and no Scrap is granted (Rule 5 guard). The player must unequip first. *Verified by AC-INV-04.*
- **EC-INV-03 — Scrap a missing/invalid `instance_id`.** A scrap request naming an id not in `part_instances` is a **no-op** — rejected, no Scrap granted, no crash. *Verified by AC-INV-05.*
- **EC-INV-04 — Use/decrement a consumable at quantity 0.** A decrement when the id's count is 0 (or absent) does nothing — Inventory refuses to go below 0; the use is rejected upstream (Consumable EC-CD-04). No negative count, no crash. *Verified by AC-INV-07.*
- **EC-INV-05 — Duplicate part instances never merged.** Holding N copies of the same `part_id` yields N distinct `PartInstance` records, each with its own `instance_id` and `upgrade_tier`; `get_parts` returns all N separately (Part DB EC-05). No dedup, no stacking, ever. *Verified by AC-INV-03.*
- **EC-INV-06 — Scrap balance at `SCRAP_MAX` (defensive).** Adding Scrap beyond `SCRAP_MAX` clamps at `SCRAP_MAX`; the excess is not stored. In MVP the whole-arc faucet is ~1,555–2,125 Scrap (Drop System), far below any sane `SCRAP_MAX`, so this is a defensive guard that never fires in normal play. *Verified by AC-INV-10.*
- **EC-INV-07 — `instance_id` never reused.** Ids come from a monotonic per-save counter; a scrapped instance's id is **never** reassigned to a future part. This prevents a dangling Workshop/UI reference from silently resolving to a different part. *Verified by AC-INV-09.*
- **EC-INV-08 — Unknown `part_id` / `consumable_id` on `add` (referential guard).** An `add` naming an id absent from Part DB / Consumable DB is a **content/integrity error**: rejected and logged naming the bad id; never stored, never crashes. (In shipped play this can only arise from a data bug or a stale save after content removal.) *Verified by AC-INV-11.*
- **EC-INV-09 — Absent consumable key ≡ 0.** `get_consumable_count(id)` for an id never acquired returns `0` (absent key is equivalent to zero — Rule 3), not null, no crash. *Verified by AC-INV-08.*
- **EC-INV-10 — Future shop-sell loop (future-scope, no MVP AC).** If a post-MVP shop ever sells consumables *for Scrap*, the loop `earn Scrap → buy consumable → sell consumable → earn Scrap` could open. MVP's reject-with-no-conversion overflow policy breaks the consumable→Scrap half today, so no loop exists now. **No MVP AC** — the selling path does not exist in MVP (drops-only); flagged so the future Shop GDD runs a rate audit before enabling consumable sell. *(Surfaced by the systems-designer exploit scan.)*

## Dependencies

### Upstream (Inventory reads from these)

| System | What Inventory reads | Status | Hard/Soft |
|--------|---------------------|--------|-----------|
| **Part Database** | Part definitions (`id`, `display_name`, `rarity`, `slot_type`, `part_family`, `flavor_text`, `max_upgrade_tier`, `upgrade_effects`) to validate `part_id` and display instances | Approved | Hard |
| **Consumable Database** | Consumable definitions (`id`, `display_name`, `rarity`, `max_stack`, use-context, effect metadata) — `max_stack` is the cap INV-1 enforces | Approved | Hard |

### Downstream (these read from / write to Inventory)

| System | Interface | Status |
|--------|-----------|--------|
| **Drop System** | Calls `add()` to deposit part instances, consumable increments, and Scrap; reads `{accepted, rejected}` for stack-full feedback. Owns `SCRAP_YIELD` (Inventory references it) | Approved |
| **World Loot System** | Calls `add()` for overworld chests/pickups | Not Started |
| **Workshop System** | Reads holdings; **owns the equipped-instance set Inventory queries** for the Rule 5 scrap guard; mutates a `PartInstance.upgrade_tier` when upgrading (spends Scrap); initiates the scrap action | Not Started |
| **Turn-Based Combat** | Calls `decrement_consumable(id)` on a successful in-battle item use (TBC Rule 7a); rejected use decrements nothing | Approved (erratum) |
| **Save/Load System** | Serializes/restores the three stores (flat records, stable `instance_id`s) | Not Started |
| **Inventory UI / Combat UI** | Render/sort holdings, scrap-confirm flow, stack-full notices | Not Started |

**Interface this GDD exposes:**
- `add(item) → {accepted, rejected}` — parts always accepted (uncapped); consumables per INV-1; Scrap clamped at `SCRAP_MAX`
- `scrap(instance_id) → {ok, scrap_gained}` — blocked if equipped or missing (EC-INV-02/03)
- `decrement_consumable(id) → bool` — false if count is 0 (EC-INV-04)
- `get_parts(filter?)` · `get_consumable_count(id)` · `get_scrap()` · `has_instance(id)` · `get_instance(id)` · `is_scrappable(id)`
- **Requires from Workshop:** `equipped_instance_ids() → Set` (feeds the scrap guard)

### Bidirectionality

- **Part Database, Consumable Database, Drop System** already list Inventory in their Dependencies (verified) — bidirectionality confirmed. They currently tag it "Not Started"; a light touch updates those rows to "Designed/Approved" on approval.
- **Workshop, World Loot, Save/Load, Inventory/Combat UI** (all Not Started) must list Inventory when authored.

### Errata obligations this GDD creates on Approved docs

1. **Consumable Database** — this GDD **resolves EC-CD-12** (overflow policy = reject-with-notice, owned here), **un-blocks/activates AC-CD-23** (the DEFERRED stacking test now has a model to assert against: single count per id, `add` returns `{accepted, rejected}`), and **resolves OQ-CD-5**'s overflow-policy half (reject; the `max_stack` values C20/R10/P5 stand as the caps INV-1 enforces). Light re-review touch.

*(Part Database and Drop System are read-only/producer contracts — Inventory adds itself as a reader and a deposit target with no reciprocal rule change; Drop retains ownership of `SCRAP_YIELD`.)*

## Tuning Knobs

### Inventory-owned knobs

| Knob | Value | Safe Range | What Changing It Does |
|------|-------|------------|----------------------|
| `SCRAP_MAX` | 999,999 | ≥ 100,000 | The Scrap-balance ceiling (EC-INV-06). Purely **defensive** — MVP whole-arc income (~2,125 Scrap, Drop System) never approaches it. Lower only if a save-size or display constraint demands, and it must stay well above the richest plausible late-game balance or a player silently loses earned Scrap. |
| `PART_INSTANCE_SOFT_CAP` *(reserved)* | unset (uncapped) | — | Reserved, not active in MVP: parts are uncapped (Part DB EC-05). If mobile save-size profiling later forces a soft cap, it lands here paired with a "scrap to make room" prompt — a post-MVP decision, not a knob to set now. |

### Owned elsewhere — referenced, not duplicated

- **`max_stack` per consumable** — Consumable DB (Common 20 / Rare 10 / Prototype 5); the cap INV-1 enforces.
- **`SCRAP_YIELD` per rarity** — Drop System (Common 5 / Rare 20 / Prototype 35 / Boss-grade 60) + the invariant `COMMON < RARE < PROTOTYPE < BOSS_GRADE` (AC-DS-19); the value `scrap()` grants.
- **Upgrade costs** — Part Upgrade System (Alpha, undefined); the Scrap *sink* `SCRAP_MAX` must accommodate.
- **`upgrade_tier` caps** — Part DB (0–3 Common / 0–5 Rare+); the bound on the instance field.

## Visual/Audio Requirements

> Inventory is a data layer and owns no assets. These are advisory obligations on the presentation systems.

- **VA-1 (advisory) — Acquire feedback.** A distinct, satisfying deposit cue when items enter inventory, differentiated for part / consumable / Scrap. The "three new parts land in the box → *what can I build?*" moment (Player Fantasy) lives on this cue. *(Inventory UI / Audio.)*
- **VA-2 (advisory) — Scrap feedback.** A tactile "recycle/crush" SFX plus a Scrap-gain readout when a part is scrapped, so the irreversible-but-rewarding action reads as deliberate. *(Inventory UI / Audio.)*
- **VA-3 (advisory) — Stack-full notice.** A soft, non-alarming cue when overflow is rejected (EC-INV-01) — distinct from an error tone; the player should read "already stocked," not "something went wrong." *(Inventory UI / Audio.)*
- **Audio intent:** reuse the shared UI SFX palette; no bespoke inventory music.

## UI Requirements

> Obligations on Inventory UI / Combat UI (both Not Started) — layout and interaction belong to those GDDs.

1. **Scrap confirmation.** The irreversible scrap (Rule 5) requires an explicit confirm showing the Scrap to be gained *before* committing. Equipped parts render visibly non-scrappable (`is_scrappable == false` → blocked with a reason).
2. **Stack-full feedback.** When `add` returns `rejected > 0`, surface a clear "stack full (+N not kept)" notice (EC-INV-01) — informative, not lossy-feeling.
3. **No completion counter.** The UI must **not** present a Pokédex-style "X/Y collected" metric (anti-pillar / Player Fantasy). Organize by *build-relevance* (slot, rarity, family), never by a checklist.
4. **Touch-first.** ≥44×44pt targets; sort/filter by `slot_type` / `rarity` / `part_family`; no hover-only interactions (technical-preferences).
5. **Batch-scrap.** Support scrapping multiple surplus parts in one confirmed action (Drop System's "batch-scrap" note), with equipped parts auto-excluded.
6. **Consumable stack display.** Show `quantity / max_stack` per consumable (e.g., "7 / 20").

> **📌 UX Flag — Inventory**: this system places scrap-confirm, stack-full-notice, no-completion-counter, and batch-scrap requirements on the Inventory UI. In Pre-Production, run `/ux-design` for the Inventory UI **before** writing epics; stories should cite the resulting `design/ux/` spec, not this GDD directly.

## Acceptance Criteria

**Tags:** BLOCKING (automated test, gates story completion) · DEFERRED (needs a Not-Started system). **Test types:** Unit (GUT, `tests/unit/inventory/`) · Integration. The scrap guard takes the equipped-instance set as an **injected parameter** (Workshop's `equipped_instance_ids()`), never a singleton call — so every unit test runs without Workshop. All fixtures use Consumable DB `max_stack` and Drop System `SCRAP_YIELD` **by name**, never magic numbers.

**AC-INV-01** (BLOCKING, Unit): **INV-1 overflow split.** GIVEN `max_stack=20 (COMMON)`. THEN: partial `current=14, qty=9 → {accepted:6, rejected:3}`; full `current=20, qty=5 → {0, 5}`; exact `current=15, qty=5 → {5, 0}`; no-op `qty=0 → {0, 0}`. Every case asserts `accepted + rejected == qty` and the stored count never exceeds `max_stack`. FAIL: negative output, `accepted+rejected ≠ qty`, or count > cap. *(EC-INV-01)*

**AC-INV-02** (BLOCKING, Unit): **`add(part)` appends a new instance + return shape.** GIVEN an empty store. WHEN `add` a Common part at tier 0. THEN `part_instances.size() == 1`, the new `PartInstance` has a fresh `instance_id` and `upgrade_tier == 0`, and the call returns `{accepted:1, rejected:0}`. Adding 600 distinct parts leaves all 600 present (uncapped). FAIL: not appended, wrong return shape, or a cap rejects the 600th. *(R4, R2)*

**AC-INV-03** (BLOCKING, Unit): **Duplicate parts never merged.** WHEN `add` the same `part_id` three times. THEN `get_parts()` returns **3 distinct** `PartInstance`s with 3 distinct `instance_id`s; none merged or stacked. FAIL: any dedup/merge, or fewer than 3 instances. *(EC-INV-05, R2)*

**AC-INV-04** (BLOCKING, Unit): **Scrap blocked on equipped.** GIVEN an instance whose id is in the injected equipped set. WHEN `scrap(instance_id)`. THEN return `{ok:false, scrap_gained:0}`, the instance remains in `part_instances`, and the Scrap balance is unchanged. FAIL: instance removed, any Scrap granted, or `ok:true`. *(EC-INV-02, R5)*

**AC-INV-05** (BLOCKING, Unit): **Scrap missing id + unknown-id queries.** WHEN `scrap(unknown_id)` → `{ok:false, scrap_gained:0}`, balance unchanged (no-op). AND `get_instance(unknown_id) → null` (no crash), `has_instance(unknown_id) → false`. FAIL: crash, non-null instance, or any balance change. *(EC-INV-03, R7)*

**AC-INV-06** (BLOCKING, Unit): **Scrap a HELD part grants `SCRAP_YIELD[rarity]`, tier-ignored.** WHEN `scrap` a HELD instance. THEN it is removed, `balance += SCRAP_YIELD[rarity]`, and return is `{ok:true, scrap_gained:yield}`. Fixtures — Common tier-0 → **+5**; **Common tier-3 → +5** (tier ignored — discriminating vs. any tier-scaled bug); Rare → **+20**; Prototype → **+35**; Boss-grade → **+60**. FAIL: tier changes the yield, wrong per-rarity value, or `scrap_gained` mismatches the balance delta. *(R5, referenced SCRAP_YIELD)*

**AC-INV-07** (BLOCKING, Unit): **`decrement_consumable` success/floor.** GIVEN count 3 → `decrement` returns `true`, count `2`. GIVEN count 0 → returns `false`, count stays `0` (never negative). FAIL: decrement below 0, wrong return, or count mutated at 0. *(EC-INV-04, R6)*

**AC-INV-08** (BLOCKING, Unit): **Absent-key & empty-query defaults.** `get_consumable_count(never-acquired id) → 0` (not null). `get_parts(filter matching zero instances) → []` (empty list, not null, no crash). FAIL: null return or crash on either. *(EC-INV-09, R7)*

**AC-INV-09** (BLOCKING, Unit): **`instance_id` never reused.** WHEN `add` a part (id `A`), `scrap` it, then `add` another part. THEN the new instance's id `≠ A`. FAIL: the scrapped id is reassigned. *(EC-INV-07)*

**AC-INV-10** (BLOCKING, Unit): **Scrap balance clamps at `SCRAP_MAX`.** GIVEN balance at `SCRAP_MAX − 2`. WHEN Scrap `+10` is added. THEN balance `== SCRAP_MAX` (excess discarded), no overflow/negative wrap. FAIL: balance exceeds `SCRAP_MAX` or wraps. *(EC-INV-06)*

**AC-INV-11** (BLOCKING, Unit): **Unknown id on `add` rejected + logged.** GIVEN a stub Part DB / Consumable DB that reports "not found" for a bad id. WHEN `add` that id. THEN the item is not stored, exactly one content error is logged naming the bad id, and no exception is thrown. FAIL: stored anyway, silent, or crash. *(EC-INV-08)*

**AC-INV-12** (BLOCKING, Unit): **`is_scrappable` paths.** **(a)** equipped instance → `false`; **(b)** missing id → `false`; **(c)** held (unequipped) instance → `true`. (Split 12a/12b/12c in the test file for isolation.) FAIL: any path returns the wrong boolean. *(R7, R5 guard)*

**AC-INV-13** (DEFERRED, Integration): **Drop System deposit end-to-end.** GIVEN a victory drop bundle. WHEN Drop calls `add` for parts, consumables, and Scrap. THEN part instances appear, consumable stacks increment (with `{accepted, rejected}` honored), and the Scrap balance rises. *Activate when: Drop System is wired to a live Inventory.*

**AC-INV-14** (DEFERRED, Integration): **TBC in-battle use decrement.** GIVEN a battle item use (TBC Rule 7a). WHEN the use **succeeds**, the consumable count drops by 1; when **rejected**, it is unchanged. *Activate when: TBC's item-use action is implemented.* (The pure `decrement_consumable` contract is already covered now by AC-INV-07; this covers only the TBC wiring.)

**AC-INV-15** (DEFERRED, Integration): **Save/Load round-trip.** GIVEN a populated inventory. WHEN serialized and restored. THEN the three stores (part_instances, consumable_stacks, scrap) are deep-equal to the originals, including `instance_id`s and tiers. *Activate when: Save/Load System exists.*

### EC ↔ AC Coverage

EC-01→01, EC-02→04, EC-03→05, EC-04→07, EC-05→03, EC-06→10, EC-07→09, EC-08→11, EC-09→08, EC-10→(no AC — future-scope, mechanism absent in MVP). **Rule/formula coverage:** INV-1→01; R4 add→01/02/11; R5 scrap→04/05/06/12; R6 decrement→07; R7 queries→05/08/12; R2 instance model→02/03/09; SCRAP_MAX→10; Drop/TBC/Save integration→13/14/15 (DEFERRED). **15 ACs: 12 BLOCKING (Unit) / 3 DEFERRED (Integration).** No ADVISORY, no untestable criteria — every BLOCKING AC has a discriminating fixture and every observable EC has a verifying AC (EC-10 excepted with stated rationale).

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-INV-1 | **Tier-refund on scrap.** MVP yields flat `SCRAP_YIELD[rarity]`, tier ignored (total sink). When Part Upgrade (Alpha) defines upgrade costs, revisit whether scrapping an upgraded part refunds a fraction of invested Scrap. | Part Upgrade System (Alpha) | Economy feel; post-MVP |
| OQ-INV-2 | **Batch-scrap UX + safety.** How the player bulk-scraps surplus (select-all-duplicates? scrap-all-below-rarity?) without ever nuking a wanted copy. | Inventory UI / ux-designer | Scrap ergonomics; set at UX design |
| OQ-INV-3 | **`SCRAP_MAX` final value + part soft-cap.** The defensive `SCRAP_MAX` and the reserved `PART_INSTANCE_SOFT_CAP` depend on mobile save-size profiling. | Save/Load / performance-analyst | Only matters if saves grow large; revisit at Save/Load |
| OQ-INV-4 | **Sort/filter defaults.** Which default ordering best serves the "what can I build?" fantasy (by slot? newest? rarity?). | ux-designer | First-open readability; playtest |
