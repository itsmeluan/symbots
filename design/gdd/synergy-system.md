# Synergy System

> **Status**: In Review (revised — re-review #5: 4 blocking + recommended batch resolved 2026-07-10)
> **Author**: Luan Martins da Silva + Claude Code Game Studios agents
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 4 — Synergy Is the Endgame / Pillar 3 — Build Depth Over Content Breadth

## Overview

The Synergy System reads the `synergy_tags` carried by all 8 equipped parts and determines which elemental and manufacturer set bonuses are active for a given Symbot build. When enough parts share a tag — element, manufacturer, or a combined element-plus-manufacturer combination — the system activates a bonus block that augments the Symbot's stats beyond what the Assembly stat pipeline produces on its own. This bonus is computed independently of Assembly and added on top by Turn-Based Combat and the Workshop UI when resolving effective stats. The player engages with synergy actively: every part decision is a choice between concentrating toward a threshold or diversifying across multiple partial sets. At its best, synergy is the moment a build "clicks" — equipping a third Ironclad part and watching a defensive bonus snap into place is the specific feeling this system exists to create.

## Player Fantasy

Synergy is the reason every part slot matters. The player shouldn't just fill slots with the highest base stats — they should feel the pull of *almost* completing a bonus, the satisfaction when it activates, and the sting of sacrificing a partial set to chase a different one. The core feeling is: **I built something intentional.**

The synergy experience unfolds across five beats:

1. **Recognition** — Two Ironclad parts in the build reveal a greyed-out "Ironclad: 2 of 3 — Armor +8 when complete" indicator. The bonus is within reach. *(Bonus values in these beats use the illustrative anchor set defined in the Acceptance Criteria preamble — Ironclad 3-piece = Armor +8. Real values are authored in Synergy Content data.)*
2. **The Hunt** — The player starts evaluating every part drop by its tags, not just its stats. "Does this get me to Ironclad 3?" *(This beat is delivered jointly: this system makes tags meaningful, but the hunt itself depends on loot-pool content volume — OQ-7 — and on Workshop UI tag visibility — DCO-3, DCO-5. Approving this GDD does not by itself guarantee Beat 2.)*
3. **The Click** — The third Ironclad part equips. The bonus activates. Audio and visual confirmation. The Symbot's defensive profile changes. *(The activation presentation is a core emotional beat, not decorative polish — see the Beat 3 binding note under Visual/Audio Requirements.)*
4. **The Tradeoff** — A better WEAPON drops with a different manufacturer tag. Equipping it breaks the set. The player pauses: is the raw stat gain worth losing the activation? *(This tension is strongest at threshold — exactly 3 or 5 matching parts. A player who over-concentrates (6–8 matching parts) has purchased safety above the ceiling and can absorb one off-tag part without losing the bonus; concentration buys robustness at the cost of drama. This is intended.)*
5. **Mastery** — The player learns to hold multiple partial synergies on a single Symbot simultaneously: maintaining ironclad ≥ 3 AND VOLT ≥ 3 to keep a combined synergy active while also pushing VOLT toward 5-piece, or running two manufacturer lines at partial thresholds for complementary bonuses. The system opens into a space of overlapping commitments and deliberate tradeoffs. This mastery beat requires UI support for multi-threshold tracking (combined-tier indicators — see UI Req 1 and DCO-2) and sufficient content volume per tag (OQ-7); it is discoverable, not taught. *(Cross-Symbot team synergies — where Symbots sharing a tag unlock a shared bonus — are a Vertical Slice expansion. Rule 1 defines the per-Symbot scope for MVP.)*

The five beats describe the ideal experiential arc, not a guaranteed sequence — random early drops can hand a player three matching parts before they ever see a 2-of-3 indicator, collapsing Beats 1–2 into an accidental Beat 3 ("something clicked and I don't know why"). Starting-kit composition and early-zone drop tables should be authored so the player's first synergy encounter passes through the 2-of-3 state (a content constraint on Part Database / Drop System authoring, tracked alongside OQ-7).

The reference feeling: Monster Hunter's armor set skills — where you're not hunting stats, you're hunting *pieces of a concept*. Symbots should create the same intentionality.

## Detailed Rules

### Core Rules

**Rule 1: Per-Symbot evaluation.**
Synergy is evaluated independently for each Symbot. There are no team-wide synergy bonuses in MVP. (Team-wide synergies are deferred to Vertical Slice.)

**Rule 2: Tag counting.**
On each `evaluate()` call, the system iterates all 8 equipped part slots. For each non-null `SympartData`, increment the count for each tag in `part.synergy_tags`:
- Every part contributes exactly 1 element tag (`VOLT`, `THERMAL`, or `KINETIC`)
- Non-wild parts also contribute exactly 1 manufacturer tag (`boltwell`, `ironclad`, `scrapjaw`)
- Wild parts contribute no manufacturer tag
- Null (empty) slots contribute no tags

**Rule 3: Activation tiers.**
For each registered synergy definition, the system checks its required tag counts against the tag count map:

| Tier | Requirement | Effect |
|------|-------------|--------|
| 3-piece | ≥ 3 parts share the required tag(s) | Small bonus activates |
| 5-piece | ≥ 5 parts share the required tag(s) | Large bonus activates |

Tiers are **cumulative**: at 5-piece, both the 3-piece AND the 5-piece bonus apply. The player receives all bonuses from every tier they have crossed.

Combined synergies (e.g., Ironclad-VOLT) require ALL constituent conditions met simultaneously: `ironclad ≥ 3` AND `VOLT ≥ 3`. Combined synergy bonus blocks **stack additively** with the bonus blocks from their constituent single-tag synergies — they do not replace them. When `ironclad ≥ 3` AND `VOLT ≥ 3`, three synergy tiers are simultaneously active: Ironclad 3-piece, VOLT 3-piece, and Ironclad-VOLT 3-piece. All three contribute to SYN-F3 aggregation.

Combined synergies only define a 3-piece tier in MVP. A combined 5-piece tier (both constituent tags meeting the 5-piece threshold simultaneously) is a Vertical Slice content expansion and must not be authored in MVP Synergy Content data.

**Tier ordering (canonical).** Wherever tier iteration order is observable — SYN-F3 effect deduplication (keep-first) and the `active_synergies` signal payload — tiers are ordered by **ascending alphabetical order of their tier ID** (`StringName`, compared as UTF-8 strings). This order is deterministic and independent of the Synergy Content data file layout: reordering definitions in the content file never changes which effect survives deduplication or the order of the emitted `active_synergies` list. This is the definition of "registration order" used throughout this document. (Rationale: the content data format is unresolved — OQ-1 — so binding order to file layout would make dedup behavior fragile against unrelated content edits.) Display order of indicators for UI purposes is a *separate* concern owned by the Workshop UI GDD (see Downstream Consumer Obligations); consumers must not assume the `active_synergies` emission order is the desired display order.

**Rule 4: Bonus block structure.**
Each active synergy tier produces a bonus block:
```
{
  stat_delta: { "stat_name": int, ... }  # flat integer additions per stat
  effects:    [ &"effect_id", ... ]      # passive effect IDs for TBC to resolve
}
```
Stat bonuses are flat integers. Synergy never modifies Assembly state — Assembly `final_stat` remains base-only.

**Rule 5: Aggregation.**
All active bonus blocks are aggregated into `synergy_bonus_block`:
```
{
  stat_delta: { "stat_name": int, ... }  # summed across all active tiers
  effects:    [ &"effect_id", ... ]      # deduplicated union across all active tiers
}
```
Stat deltas are summed additively across all active tiers. Deduplication applies only to the `effects` array (to prevent the same passive effect ID from appearing twice).

**Rule 6: Passive effects contract.**
A passive effect is a `StringName` ID (e.g., `&"volt_shock_on_hit"`). This system detects which effect IDs are active and emits them. The Turn-Based Combat GDD defines what each effect ID does in battle. No effect ID may be authored in synergy content until it is registered in the TBC GDD.

**Rule 7: Trigger events.**

`evaluate(parts: Array[SympartData])` is called by the **Workshop System** after every part equip or unequip. It always emits `synergy_changed(active_synergies: Array[StringName], bonus_block: Dictionary)` — even if the resulting bonus block is identical to the prior call. Callers must not assume deduplication; if they want idempotent behavior (e.g., to avoid animation triggers on unchanged state), they must implement their own change detection before acting on the signal.

**Change-detection contract for callers**: a caller that wants to detect a *genuine* synergy state change MUST diff on the `active_synergies` tier-ID set — NOT on `bonus_block` numeric equality alone. Two different active-tier sets can aggregate to a numerically identical `stat_delta` (e.g., a build loses a +4 tier while simultaneously gaining a different +4 tier). Diffing only the aggregated block would miss this real threshold crossing and suppress a warranted activation/deactivation animation. The `active_synergies` set is the authoritative signal of which tiers are active; compare it against the previously received set to detect crossings. (Debounce windows, subscriber-side state, and animation-thrash handling on rapid part swaps are UI concerns — see DCO-7.)

`evaluate_silent(parts: Array[SympartData])` is called by **Turn-Based Combat** once at battle start to establish the baseline bonus block. It computes and caches the bonus block identically to `evaluate()` but does NOT emit `synergy_changed`. This prevents Workshop UI subscribers from receiving a spurious signal at battle start.

Signal parameters:
- `active_synergies: Array[StringName]` — ordered list of tier IDs for all currently active tiers (e.g., `[&"volt_3_piece", &"volt_5_piece"]`), ordered by registration order (ascending alphabetical by tier ID — see Rule 3)
- `bonus_block: Dictionary` — the aggregated `synergy_bonus_block` (stat_delta + effects)

**Rule 8: Frozen during battle.**
Once a battle begins, `cached_bonus_block` is frozen. Part breaks during combat do not trigger re-evaluation. If the Part-Break System needs mid-battle synergy adjustment, that is deferred to the Part-Break GDD.

The freeze is a **behavioral contract, not a system-enforced lock**: the Synergy System does not self-lock, and an `evaluate()` call mid-battle would overwrite the frozen block. The guarantee holds because no caller invokes `evaluate()` during battle — the Workshop System GDD must document that part equip/unequip is disabled while a battle is active (see DCO-8).

**Rule 9: Read-only preview.**
The Workshop UI may call `preview(candidate_part, target_slot, current_parts)` to compute the hypothetical `synergy_bonus_block` if a candidate part were placed in a slot. The hypothetical build is identical to `current_parts` except that `current_parts[target_slot]` is replaced by `candidate_part` (the current occupant is displaced — matching the SA-F2 displacement contract). If `target_slot` is out of range (< 0 or > 7), `preview()` logs a content error and returns an empty bonus block. If `candidate_part` is null, the hypothetical build treats `target_slot` as an empty slot (a null candidate contributes no tags) — this is the unequip-preview case, valid input rather than an error; the implementation must not access `candidate_part.synergy_tags` without a null check (`null.synergy_tags` is a runtime error — see EC-SYN-14, AC-SYN-24). Consumers should treat any empty return as "no synergy change" for display purposes and rely on the content error log to identify invalid slot-index calls during development — distinguishing error cases from valid no-synergy results via the return value is not required (see AC-SYN-20). This call:
- Does NOT emit `synergy_changed`
- Does NOT modify `cached_bonus_block`
- Returns the hypothetical block for UI comparison only

The Workshop UI diffs hypothetical vs. current and surfaces any threshold crossings (new activations, lost activations). This fulfills Assembly's Deferred Design Obligation #6.

---

### States and Transitions

The Synergy System holds exactly one piece of mutable state: `cached_bonus_block`, replaced on each `evaluate()` or `evaluate_silent()` call. All logic — tag counting, tier activation, aggregation — is a pure function of the input parts array; no other state is retained between calls.

| Event | Action | Result |
|-------|--------|--------|
| `evaluate(parts)` called | Recompute tag counts → check all synergy definitions → aggregate bonus blocks | Update `cached_bonus_block`; emit `synergy_changed(active_synergies, bonus_block)` |
| Battle starts | TBC calls `evaluate_silent(parts)` | Baseline `cached_bonus_block` established silently; frozen until battle ends |
| Part equipped in Workshop | Workshop System calls `evaluate(parts)` | Live recalculation and signal |
| Part unequipped in Workshop | Workshop System calls `evaluate(parts)` | Live recalculation and signal |
| `preview(candidate, slot, parts)` called | Read-only evaluation | Returns hypothetical block; no signal, no cache write |

---

### Interactions with Other Systems

| System | Direction | Interface | Data Exchanged |
|--------|-----------|-----------|----------------|
| **Symbot Assembly** | ← reads from | `SymbotBuild.get_parts()` | `Array[SympartData]` (8 entries, null for empty slots) |
| **Part Database** | ← reads from | `SympartData.synergy_tags` | `Array[StringName]` tags per part |
| **Workshop System** | ← triggered by | `evaluate(parts)` called on equip/unequip | Provides current part list |
| **Turn-Based Combat** | ← triggered by, → provides | `evaluate_silent(parts)` at battle start; provides `cached_bonus_block` | Stat delta dict + effect ID array |
| **Workshop UI** | → provides on signal | `synergy_changed` signal; `preview()` return value | Bonus block for live display and swap preview |

Assembly does NOT call Synergy. Assembly `final_stat` does NOT incorporate synergy bonuses.

## Formulas

The Synergy System's computations are entirely integer-based. No floating-point arithmetic is used, so no epsilon nudges are needed.

**Integer enforcement (dual: load + runtime)**: the integer invariant is enforced at two points, independent of how the content data format (OQ-1) resolves. (1) Content validation tooling rejects any `stat_delta` value that is not an integer literal at load time — the authoring defense. (2) SYN-F3 casts each value via `int(...)` as it is read into the aggregation sum — the runtime defense; a float that slips past validation is truncated at the system boundary. Together these guarantee every `synergy_bonus_block.stat_delta` value is `int`, so strict-integer equality in consumers and ACs (e.g., `== 73`, never `== 73.0`) is safe.

---

**SYN-F1: Tag Count**

```
tag_count[tag] = Σ (1 for each equipped part p where tag ∈ p.synergy_tags)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `tag` | `StringName` | element or manufacturer tag IDs | e.g., `&"ironclad"`, `&"VOLT"` |
| `p.synergy_tags` | `Array[StringName]` | 1–2 entries when content-valid (1 element + ≤1 manufacturer) | Tags on each non-null `SympartData`. Null slots contribute 0. A null or empty `synergy_tags` field is treated as `[]` — see EC-SYN-07. |
| `tag_count[tag]` | `int` | `[0, 8]` under valid content | Output. Can exceed 8 only under EC-SYN-11 duplicate-tag content errors. |

---

**SYN-F2: Tier Activation Check**

A synergy tier is active if and only if ALL of its required tag counts are satisfied:

```
tier_active(tier) = ∀ (tag, min_count) ∈ tier.requirements :
                      tag_count[tag] ≥ min_count
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `tier.requirements` | list of `(tag, min_count)` pairs | ≥ 1 pair (see validity invariant) | The tier's activation conditions, all of which must hold |
| `min_count` | `int` | `[1, 8]` — MUST be ≥ 1 | Required tag count. A `min_count` of 0 is vacuously satisfied (tag counts are never negative) and is a content error — see EC-SYN-13. |
| output | `bool` | — | `true` iff every requirement is satisfied |

Examples:
- Ironclad 3-piece: `[(ironclad, 3)]` → true when `tag_count[ironclad] ≥ 3`
- VOLT 5-piece: `[(VOLT, 5)]` → true when `tag_count[VOLT] ≥ 5`
- Ironclad-VOLT 3-piece: `[(ironclad, 3), (VOLT, 3)]` → true when both counts ≥ 3

Combined synergies use `SYNERGY_THRESHOLD_TIER1` (= 3) as the per-tag minimum for their 3-piece tier.

**Safe count access**: `tag_count[tag]` denotes a safe lookup — a tag absent from the count map reads as `0`, never `null` or an error (implement with `Dictionary.get(tag, 0)`). This guarantees SYN-F2 evaluates correctly on the all-empty build (EC-SYN-01), where the count map is empty and every requirement lookup returns 0.

**Requirements validity invariant**: `tier.requirements` MUST contain at least one `(tag, min_count)` pair, AND every `min_count` MUST be ≥ 1. Both violations produce the same failure mode — a permanently-active tier:
- An **empty requirements list** makes the ∀-quantifier vacuously true. Content error; handled per EC-SYN-12 (skip + log; validation tooling rejects it).
- A **`min_count` of 0** passes the non-empty check but is vacuously satisfied on every build, because `tag_count[tag] ≥ 0` always holds (SYN-F1 output is non-negative). Content error; handled per EC-SYN-13 (skip + log; validation tooling rejects it).

Neither case may ever be evaluated as always-active.

The symmetric upper bound — `min_count > 8` — is the opposite, non-hazardous failure mode: a tier that can never activate under valid content (a "dead tier", silently inert). Because it never wrongly activates, the system evaluates it normally at runtime (no skip logic needed); content validation tooling SHOULD warn on any `min_count > 8` to catch authoring typos (e.g., 9 typed for 5). The same warning applies to any requirements list whose min_counts sum past 8 across disjoint tag categories (e.g., a 3-way combined tier requiring 9+ tagged slots — unreachable in an 8-slot build).

---

**SYN-F3: Bonus Block Aggregation**

```
synergy_bonus_block.stat_delta[S] = Σ int(tier.stat_delta.get(S, 0))
                                      for all tiers where tier_active(tier) = true

synergy_bonus_block.effects = deduplicate(
  flatten([tier.effects for all active tiers])
)
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `tier.stat_delta` | `Dictionary[String, int]` | values non-negative in MVP content (EC-SYN-08 defends against negatives) | Per-tier flat stat additions; each value passes through `int(...)` at ingest per the integer-enforcement rule above |
| `tier.effects` | `Array[StringName]` | 0+ effect IDs | Passive effect IDs granted by the tier |
| `synergy_bonus_block.stat_delta` | `Dictionary[String, int]` | guaranteed `int` values | Summed across all active tiers |
| `synergy_bonus_block.effects` | `Array[StringName]` | unique IDs only | Deduplicated union, keep-first in registration order |

Active tiers are iterated in **registration order** (ascending alphabetical by tier ID — see Rule 3). `flatten` preserves tier iteration order and within-tier effect order. `deduplicate` is keep-first: the first occurrence of each effect ID is retained; later duplicates are discarded. Because registration order is alphabetical by tier ID (not content-file order), which tier "keeps" a shared effect ID is deterministic and stable against content-file reordering.

Deduplication on effects matters: if two active tiers both grant `&"volt_shock_on_hit"`, the ID appears only once in the output. This prevents double-triggering in TBC. Note: if a combined synergy's effect list duplicates an effect already granted by a constituent synergy, the combined synergy's effect contribution is silently discarded — content authors must not duplicate effect IDs across constituent and combined synergy tiers. When the content data format resolves (OQ-1), the content validator must check cross-tier effect-ID uniqueness within each synergy family; additionally, dev builds should log whenever `deduplicate` discards an occurrence (the discard is silent by design in release, but authoring needs the feedback).

**Type guarantee**: `synergy_bonus_block.effects` is always an `Array[StringName]` — never null — including when zero tiers are active (the empty build yields `[]`). This mirrors the stat_delta integer guarantee: consumers may iterate `effects` unconditionally without a null check.

---

**SYN-F4: Effective Stat (contract for TBC and Workshop UI)**

Consumers that need the effective stat (for damage calculation or display) apply:

```
effective_stat[S] = max(0, Assembly.final_stat[S] + synergy_bonus_block.stat_delta.get(S, 0))
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `Assembly.final_stat[S]` | `int` | ≥ 0 (SA-F1 guarantees) | Base stat from the Assembly pipeline |
| `synergy_bonus_block.stat_delta.get(S, 0)` | `int` | any (MVP content non-negative) | Synergy bonus; 0 if no active synergy affects stat `S` |
| `effective_stat[S]` | `int` | ≥ 0 | Output. Uncapped above (no `stat_max` ceiling — matching SA-F1 behavior). |

In MVP, all authored synergy stat_delta values are non-negative (no penalty synergies). The `max(0,…)` floor is a content-error defense only.

**Cross-system range contract (DF-1)**: `effective_stat` is deliberately uncapped above, so any downstream formula that consumes it must derive its input range from the synergy-amplified ceiling, NOT from Assembly SA-F1 alone. This specifically invalidates the Damage Formula GDD's registered DF-1 output range ([1, 165]), which predates this system and assumed base-only stat inputs — a maximally concentrated 7-tier build (EC-SYN-02) can push attack-side inputs well past SA-F1's ceiling. The Turn-Based Combat GDD MUST re-derive DF-1's input/output ranges under synergy-amplified stats before using them for balance tuning (tracked as a downstream obligation in the Dependencies table).

---

**Worked Example**

*(Fixture note: this example uses a different fixture from the Acceptance Criteria preamble — the same base stats (energy_power = 55) but a richer build with the combined tier active, so the SYN-F4 totals differ: 77 here vs. 73 in AC-SYN-06. The effect ID `&"volt_shock_on_hit"` is this example's illustrative ID; the ACs use `&"volt_test"`. Both sections are internally consistent — reconcile per-fixture, not across sections.)*

Build (8 slots — 6 occupied, 2 empty):
1. HEAD: ironclad, VOLT → tags `[ironclad, VOLT]`
2. WEAPON: ironclad, VOLT → tags `[ironclad, VOLT]`
3. CORE: ironclad, VOLT → tags `[ironclad, VOLT]`
4. ARMS: boltwell, VOLT → tags `[boltwell, VOLT]`
5. LEGS: wild, VOLT → tags `[VOLT]`
6. ENERGY_CELL: wild, THERMAL → tags `[THERMAL]`
7. BACK: null → no tags
8. CHIPSET: null → no tags

**SYN-F1 results:**
```
tag_count = { ironclad: 3, boltwell: 1, VOLT: 5, THERMAL: 1 }
```

**SYN-F2 tier activation** *(using illustrative content values — real values set in Synergy Content data)*:

| Tier | Requirements | Active? |
|------|-------------|---------|
| Ironclad 3-piece | ironclad ≥ 3 | ✓ (3 ≥ 3) → armor +8 |
| Ironclad 5-piece | ironclad ≥ 5 | ✗ (3 < 5) |
| VOLT 3-piece | VOLT ≥ 3 | ✓ (5 ≥ 3) → energy_power +6 |
| VOLT 5-piece | VOLT ≥ 5 | ✓ (5 ≥ 5) → energy_power +12, `volt_shock_on_hit` |
| Ironclad-VOLT 3-piece | ironclad ≥ 3 AND VOLT ≥ 3 | ✓ → armor +5, energy_power +4 |

**SYN-F3 aggregation:**
```
stat_delta = { armor: 8+5=13, energy_power: 6+12+4=22 }
effects    = [ &"volt_shock_on_hit" ]
```

The discriminating case: VOLT 3-piece and 5-piece both apply (6 + 12 = 18 from VOLT alone). A wrong implementation that applies only the highest tier would yield energy_power 12 (VOLT 5-piece only) + 4 (Ironclad-VOLT 3-piece) = 16 — not 22. The acceptance criteria must verify the cumulative total.

**SYN-F4** *(base stats: armor = 40, energy_power = 55)*:
```
effective_stat[armor]        = max(0, 40 + 13) = 53
effective_stat[energy_power] = max(0, 55 + 22) = 77
```

## Edge Cases

**EC-SYN-01: All slots empty.**
`evaluate()` receives 8 null entries. SYN-F1 counts are all zero. No synergy tier is active. `synergy_bonus_block = { stat_delta: {}, effects: [] }`. Signal emits with the empty block. No crash. *Verified by AC-SYN-07.*

**EC-SYN-02: Maximum tag concentration and simultaneous tier stacking.**
Pure concentration: all 8 parts share the same manufacturer AND element (e.g., 8 Ironclad-VOLT parts). Both 3-piece and 5-piece activate for Ironclad, for VOLT, and for Ironclad-VOLT (6 tiers active). All bonuses stack cumulatively per SYN-F3.

Maximum verified simultaneous tiers: a 5+3 distribution across two elements under one manufacturer (e.g., 5 ironclad-VOLT + 3 ironclad-KINETIC, giving ironclad=8, VOLT=5, KINETIC=3) yields ironclad 3-piece, ironclad 5-piece, VOLT 3-piece, VOLT 5-piece, KINETIC 3-piece, ironclad-VOLT 3-piece, ironclad-KINETIC 3-piece = **7 tiers** (verified maximum in MVP). Three manufacturers simultaneously at 3-piece is impossible — it would require 9 manufacturer-tagged slots across 8 total. There is no cap on the number of simultaneously active tiers. Content authors must budget stat_delta values assuming up to **7 tiers** could be simultaneously active — see the cumulative budget constraint in Tuning Knobs and OQ-2. *Cumulative stacking mechanics verified by AC-SYN-02, AC-SYN-03, AC-SYN-09; the 7-tier maximum fixture is exercised end-to-end by AC-SYN-27.*

**EC-SYN-03: Wild parts used across multiple synergy lines.**
Wild parts (element tag only, no manufacturer tag) intentionally enable element-focus builds that combine with manufacturer synergies. Example: 4 wild VOLT parts (element-only) plus 4 non-wild Ironclad+VOLT parts gives `tag_count = { VOLT: 8, ironclad: 4 }` — VOLT 3-piece, VOLT 5-piece, Ironclad 3-piece, AND Ironclad-VOLT 3-piece all activate simultaneously.

The tradeoff wild parts create is **specific to manufacturer counts, not to combined synergies**. Per SYN-F2, a combined synergy checks two *independent* counts (`tag_count[ironclad] ≥ 3 AND tag_count[VOLT] ≥ 3`); it does NOT require the two tags to co-locate on the same physical part. So wild parts do not block combined synergies — whenever both independent counts cross threshold, the combined tier fires regardless of which parts carry which tags. What wild parts cost is manufacturer-count throughput: every wild slot contributes zero manufacturer tags, so a wild-heavy build reaches manufacturer 3-piece/5-piece (and any combined tier that leans on a high manufacturer count) more slowly. The player trades manufacturer-set flexibility to concentrate a single element across otherwise-incompatible parts. That is the real, intended tension — not an inability to form combined synergies. *Wild-part counting behavior verified by AC-SYN-04; independent-count combined activation verified by AC-SYN-03.*

**EC-SYN-04: Same effect ID granted by multiple active tiers.**
VOLT 3-piece and VOLT 5-piece both include `&"volt_shock_on_hit"`. After SYN-F3 deduplication (keep-first), the effect appears exactly once in `synergy_bonus_block.effects`. TBC triggers the effect at most once per applicable event. If the effect appears twice in the output, the AC for this case fails. *Verified by AC-SYN-05 (dedup applied) and AC-SYN-16 (unique IDs not over-deduplicated).*

**EC-SYN-05: Effect ID not registered in TBC.**
A content author adds a new effect ID to a synergy tier before it is defined in the TBC GDD. The Synergy System emits the unknown ID in the effects array. TBC is responsible for logging a content error (unknown effect ID) and skipping it without crashing. This is a content error, not a system error. *Synergy-side transparent pass-through verified by AC-SYN-26; TBC's skip-and-log behavior is TBC's observable and its AC belongs in the TBC GDD (OQ-3).*

**EC-SYN-06: stat_delta references a stat not in Assembly's 11-stat schema.**
A content error produces `stat_delta = { "speed": 10 }`. SYN-F3 aggregates it into `synergy_bonus_block`. Consumers call `.get(S, 0)` for each of the 11 known stats and receive 0 for "speed". The unknown key is silently ignored. No crash. This is detectable only by content validation tooling. *Verified by AC-SYN-17.*

**EC-SYN-07: Part with empty or null synergy_tags.**
A `SympartData` has `synergy_tags = []` (content error — Part DB requires at least an element tag). The system iterates an empty array and contributes no counts. No crash. The part acts as a synergy-inert slot.

The same outcome applies when `synergy_tags` is **null** rather than `[]` (e.g., the field was absent from the data file and the loader did not initialize it). Null and empty are distinct runtime states in GDScript — `for tag in null` is a runtime error, not an empty iteration — so the implementation MUST guard the iteration: a null `synergy_tags` is treated exactly as `[]` (no tags contributed, no crash) and never iterated directly. **Invariant ownership**: the Part DB is the invariant owner (every part must carry at least one element tag, and the loader must initialize the field); the Synergy System's null-guard is a defensive measure only, and it is not responsible for detecting or reporting the content error. *Verified by AC-SYN-19 (both the `[]` and `null` scenarios).*

**EC-SYN-08: Negative stat_delta in content.**
A content author accidentally authors a penalty synergy: `stat_delta = { armor: -5 }`. SYN-F3 aggregates `armor: -5` into `synergy_bonus_block`. SYN-F4 applies it: `effective_stat[armor] = max(0, Assembly.final_stat[armor] - 5)`. If the penalty exceeds the base stat, the result is clamped to 0, not negative. This is the intended defensive floor — the player's stat cannot be driven below zero by a content error. *Verified by AC-SYN-10 (consumer-owned — the clamp lives in SYN-F4, which consumers apply).*

**EC-SYN-09: preview() candidate is the currently equipped part.**
No change — hypothetical evaluation returns a block identical to `cached_bonus_block`. No threshold crossings. The Workshop UI shows "no change" for this slot. *Cache stability and read-only behavior verified by AC-SYN-08; the same-part identity fixture is not separately tested (the displacement logic is exercised with changing candidates by AC-SYN-08 and AC-SYN-13).*

**EC-SYN-10: evaluate() receives wrong-length array.**
If fewer than 8 entries are provided (programming error), missing indices are treated as null (no tags contributed). If more than 8 entries are provided, indices beyond 7 are ignored. The system logs a content/programming error in both cases but does not crash. *Verified by AC-SYN-18.*

**EC-SYN-11: Part with duplicate tags in `synergy_tags`.**
A `SympartData` has `synergy_tags = [&"ironclad", &"ironclad"]` (content error). SYN-F1 iterates the array and increments the count once per occurrence — this single part contributes **2** to `tag_count["ironclad"]`. The Synergy System does NOT deduplicate tags within a single part's array; it counts each occurrence. This can silently inflate a tag count and wrongly activate a higher tier (e.g., three such parts would read as `ironclad = 6`, activating the 5-piece tier with only 3 physical parts). Detection is the responsibility of Part DB validation tooling — a part must carry exactly one element tag and at most one manufacturer tag, with no duplicates. The Synergy System is not responsible for detecting it and does not crash. (Rationale for count-each-occurrence rather than per-part dedup: SYN-F1 stays a trivial O(n) sum with no per-part set construction; the invariant is enforced upstream at content-authoring time where it belongs.) *Verified by AC-SYN-21.*

**EC-SYN-12: Synergy tier with empty `requirements`.**
A content author authors a tier with `requirements = []`. Per SYN-F2, a universally-quantified check over an empty set is vacuously true, which would make the tier permanently active on every build — including a completely empty build. This is a content error. The implementation MUST treat an empty requirements list as invalid: **skip the tier and log a content error** rather than evaluating it as always-active. Content validation tooling must reject any tier with empty requirements at load time. No crash. (See the requirements validity invariant under SYN-F2.) *Verified by AC-SYN-22.*

**EC-SYN-13: Synergy tier requirement with `min_count = 0`.**
A content author authors `requirements = [(VOLT, 0)]`. The list is non-empty — it passes the EC-SYN-12 empty-list check — but `tag_count[VOLT] ≥ 0` is always true (SYN-F1 output is non-negative), so the tier would be permanently active on every build, including the all-empty build. This is the second vacuous-activation failure mode alongside EC-SYN-12, and it is a content error. The implementation MUST treat any requirement pair with `min_count < 1` as invalid: **skip the tier and log a content error** rather than evaluating it. Content validation tooling must reject any tier containing a `min_count < 1` at load time. No crash. (See the requirements validity invariant under SYN-F2.) *Verified by AC-SYN-23.*

**EC-SYN-14: preview() with a null candidate_part (unequip preview).**
The Workshop UI previews removing a part by calling `preview(null, target_slot, current_parts)` — the most natural call when the player taps a remove/unequip control. A null candidate is valid input, not an error: the hypothetical build treats `target_slot` as empty (the null contributes no tags), exactly as a null entry in the parts array does (EC-SYN-01). The implementation MUST NOT access `candidate_part.synergy_tags` without a null check — `null.synergy_tags` is a GDScript runtime error, the same crash class as EC-SYN-07's null-field case. No log is emitted (this is not a content error). *Verified by AC-SYN-24.*

## Dependencies

### Upstream (this system reads from these)

| System | What this system reads | Status |
|--------|------------------------|--------|
| **Part Database** | `SympartData.synergy_tags` — element and manufacturer tags per part | Approved |
| **Symbot Assembly** | `SymbotBuild.get_parts()` — the 8-slot equipped part list, read-only | Approved |

Bidirectional notes:
- Part DB hard constraint DB1 states the Synergy GDD must define combined manufacturer+element bonuses. DB4 states the Synergy GDD must provide cross-element incentives. ✓ Addressed in this GDD.
- Assembly's Deferred Design Obligations section names the Synergy GDD as responsible for: synergy delta display at threshold crossings, CORE identity in combat, CHIPSET meaningfulness. ✓ Addressed in Rule 9 (read-only preview) and Deferred Design Obligations below.
- Assembly does NOT call Synergy (one-way dependency is documented in both GDDs).

---

### Downstream (these systems read from this one)

| System | What it reads | Status | Bidirectionality |
|--------|---------------|--------|-----------------|
| **Turn-Based Combat** | `cached_bonus_block` (stat_delta + effects) at battle start via `evaluate_silent()`; applies SYN-F4 for effective stats; resolves passive effect IDs | Not Started | TBC GDD must document its Synergy dependency and define the passive effect ID registry; must re-derive DF-1's registered output range under synergy-amplified stat inputs (SYN-F4 is uncapped — see the SYN-F4 cross-system range contract) |
| **Workshop System** | Triggers `evaluate(parts)` on every equip/unequip | Not Started | Workshop System GDD must document its Synergy call |
| **Workshop UI** | Reads `synergy_bonus_block` via `synergy_changed` signal and `preview()` return value | Not Started | Workshop UI GDD must document its Synergy read interface; must verify SA-F2 return type (delta vs. absolute) before speccing the combined effective-stat preview (see OQ-6) |

---

### Deferred Dependency (future)

| System | Nature | When |
|--------|--------|------|
| **Part-Break System** | Rule 8 explicitly freezes synergy during battle. If Part-Break ever needs to affect synergy mid-battle (e.g., a broken part loses its tag contributions), that interaction must be defined in the Part-Break GDD and this rule revisited. | Part-Break GDD design |

## Tuning Knobs

| Knob | Value | Unit | Safe Range | Gameplay Effect |
|------|-------|------|------------|-----------------|
| `SYNERGY_THRESHOLD_TIER1` | 3 | parts | 3–4 | How easily a small bonus triggers. At 2, any two matching parts trigger a bonus (too easy — insufficient intentionality with 8 slots). At 4, requires near-half the build even for the small reward. |
| `SYNERGY_THRESHOLD_TIER2` | 5 | parts | 4–7 | How much commitment the large bonus demands. Must be > TIER1. At 4, achievable easily in a mixed build alongside another synergy. At 7, nearly impossible without abandoning all other synergy lines. |

All **bonus values** (stat_delta per tier, effect IDs per tier) are content data authored in the Synergy Content data file — not system constants. Changing a bonus value requires only a content edit; changing a threshold requires a design decision.

**Cumulative budget constraint (content authoring)**: balancing must validate not only per-tier values but the **7-tier worst-case sum** (EC-SYN-02). For each stat, the sum of `stat_delta` across the 7 simultaneously-active tiers of a maximally concentrated build must be checked against the intended effective-stat ceiling — tuning tiers individually without testing the maximum-concentration build is a known failure mode. A per-tier per-stat cap will be defined alongside the MVP content values (OQ-2); until then, treat the worked-example magnitudes (+4 to +20 per tier) as the working band.

Combined synergies use `SYNERGY_THRESHOLD_TIER1` as the per-tag minimum (≥ 3 for each constituent tag). This is not a separate knob in MVP — if combined synergies need different thresholds, that becomes a per-synergy-definition data field rather than a global constant.

## Visual/Audio Requirements

This system owns the `synergy_changed` signal. The Workshop UI GDD owns all visual and audio presentation decisions. The table below specifies the event contract this system provides.

| Event | Visual Need | Audio Need | Owner |
|-------|-------------|------------|-------|
| Synergy tier activates (threshold crossed up) | Indicator lights up; synergy bonus animates in | Activation chime matching build "click" fantasy | Workshop UI GDD |
| Synergy tier deactivates (threshold crossed down) | Indicator dims; bonus animates out | Deactivation tone | Workshop UI GDD |
| Synergy preview activates (via preview()) | Greyed-out "would activate" indicator | None (preview only) | Workshop UI GDD |
| `synergy_changed` signal fires | Trigger for all of the above | Trigger for all of the above | Workshop UI (subscribes to signal; must implement stateful change detection per DCO-7 before triggering animations to prevent thrashing on rapid part swaps) |

**Beat 3 binding**: "The Click" (Player Fantasy Beat 3) depends on the Workshop UI implementing a clearly perceptible activation animation and audio cue when a threshold is first crossed. A silent or low-fidelity response to `synergy_changed` reduces Beat 3 to a stat number changing — the activation presentation is a core emotional beat of this system, not decorative polish. Workshop UI GDD authors: treat the first-crossing presentation as a requirement inherited from this GDD's Player Fantasy, not an optional flourish.

## UI Requirements

Requirements this system places on downstream UI GDDs:

1. **Build-relevant synergy indicators**: Workshop UI must display each synergy tier relevant to the current build. A tier is build-relevant if the player has at least 1 part with a matching tag. Tiers with no matching parts are hidden (3–8 visible indicators maximum, not all 21 theoretical tiers). Three indicator states are required:
   - **Active tier (threshold met, no next tier)**: show tier name, icon, and active bonus (e.g., "Ironclad 5-piece: Armor +20 active").
   - **Active tier (next threshold in reach)**: show active bonus AND progress toward next threshold AND next tier's pending bonus from content data (e.g., "Ironclad: 4/5 — +8 Armor active | 1 more for Armor +20").
   - **Inactive tier (threshold not yet met)**: show current count, required count, and the pending bonus value from content data (e.g., "Ironclad: 2/3 — 1 more for Armor +8"). Players must always see what they are building toward, not just how far away they are.
   Bonus values in all three states must be read from the Synergy Content data file — they are not computed by the UI. Content validation must reject any tier whose `display_name` or pending-bonus display data is null/empty — Beat 1 (Recognition) depends on the player seeing the specific pending reward ("Armor +8 when complete"), not a bare progress count.
2. **Synergy stat delta display**: Workshop UI must apply SYN-F4 before displaying any stat value — players must never see a base-only stat in the Workshop. `effective_stat[S] = max(0, Assembly.final_stat[S] + synergy_bonus_block.stat_delta.get(S, 0))`.
3. **Swap preview synergy delta**: When previewing a part swap, Workshop UI must call `preview()` and surface synergy threshold changes (new activation, lost activation) as a distinct visual element from the base-stat delta. A synergy activation or loss is not just a number change — it requires presentation that is visually distinguishable from a plain stat delta (e.g., a highlighted indicator change alongside the stat numbers).
4. **Active effects list**: Workshop UI must display active passive effect IDs by name. The Synergy Content data file must include a `display_name` string for each tier (and its effects), so Workshop UI reads human-readable names from the content data rather than raw StringName IDs.
5. **Combat UI**: During battle, Combat UI displays the frozen `cached_bonus_block` bonuses as part of effective stats. No synergy animation occurs during battle (block is frozen at battle start via `evaluate_silent()`). Display location, whether synergy bonuses are shown separately from or merged into effective stats, and behavior when no synergy is active are Combat UI GDD decisions — see Downstream Consumer Obligations.

## Downstream Consumer Obligations

The Synergy System defines its own output contract (signals, `cached_bonus_block`, `preview()`, SYN-F4). The following presentation and interaction decisions depend on that contract but are **owned by downstream GDDs** (Workshop UI, Combat UI, Workshop System), which do not exist yet. They are recorded here as explicit obligations so they are not lost — they are intentionally NOT resolved in this GDD (resolving UI layout before the UI GDD exists would be premature).

| # | Obligation | Owner GDD | Why it is deferred (not resolved here) |
|---|------------|-----------|----------------------------------------|
| DCO-1 | **Indicator overflow behavior**: what happens when a build produces more build-relevant tiers than the panel can show (UI Req 1 caps display at 3–8, but a focused build can exceed this). Silent-drop is forbidden — it would hide a reachable synergy from the player (breaks Beat 1). Specify scroll, collapse/expand, or priority-sort with a defined cutoff. | Workshop UI GDD | Depends on the Workshop screen layout and available panel space, which the Workshop UI GDD owns. |
| DCO-2 | **Indicator sort/display order**: the order indicators appear in the panel. This must NOT be inherited from the `active_synergies` emission order (that is alphabetical-by-ID, not a UX priority — see Rule 3). Define a UX priority rule (e.g., active-before-inactive; within a group, descending current tag count; combined listed after constituents). **Constraint**: a combined-tier indicator must never visually imply its constituent tiers are deactivated or replaced — all three tiers are simultaneously active (Rule 3) and must read as such. | Workshop UI GDD | Emission order is a system-determinism concern; display order is a UX attention concern. Decoupled deliberately. |
| DCO-3 | **preview() invocation trigger on touch**: what player action initiates a swap preview on iOS (no hover exists on touch). UI Req 3 requires calling `preview()` but does not specify the gesture. | Workshop UI GDD | Touch-interaction design is Workshop UI territory; the system only provides the `preview()` call. |
| DCO-4 | **Indicator tappability & touch ergonomics**: whether each indicator is an individually tappable target (required to surface per-tier effect names per UI Req 4). At 44×44pt minimum, up to 8 stacked indicators consume ~42% of an iPhone's height, forcing a scroll/collapse decision. The Synergy GDD's position: indicators **must be tappable** to satisfy UI Req 4; the layout that achieves this is the Workshop UI GDD's to design. **Gesture-conflict warning**: DCO-3 and DCO-4 may compete for the same touch surface (tap-to-reveal-effects vs. gesture-to-trigger-preview); the Workshop UI GDD must resolve both gestures together, not independently. | Workshop UI GDD | The tappability *requirement* is declared here; the layout solution belongs to the UI GDD. |
| DCO-5 | **"Next threshold in reach" definition** (indicator state 2): whether "in reach" means (A) any next tier is authored, (B) within N parts of the threshold, or (C) achievable within remaining empty slots. The UI Req 1 example ("Ironclad: 4/5 — 1 more…") implies (B). Confirm and define, so the progressing-state indicator does not advertise unachievable progress. | Workshop UI GDD | Depends on how the Workshop presents progress and empty-slot state, which the UI GDD models. |
| DCO-6 | **`display_name` character limit and null fallback**: the maximum length UI can render, and what to show if a tier's `display_name` is null/empty in content data (fall back to the raw tier ID vs. "Unknown"). Also a localization note if names are user-facing. | Workshop UI GDD (constraint); Synergy Content data (value) | Length budget depends on the indicator layout the UI GDD defines. |
| DCO-7 | **Stateful change detection + debounce**: Workshop UI must maintain a local `last_active_synergies` set (initialized empty). On each `synergy_changed` signal, diff the received `active_synergies` against the stored set *before* triggering any activation/deactivation animation, then update the stored set. Diffing `bonus_block` numeric equality alone is insufficient — see the Rule 7 change-detection contract for why. An optional debounce window (suggested starting value 100–200 ms) may suppress animation triggers on rapid sequential signals; the specific value is a Workshop UI tuning decision. | Workshop UI GDD | The system deliberately always-emits (Rule 7); the subscriber-side state and debounce tuning belong to the UI layer. The *requirement to be stateful* is declared here because it is part of this system's signal contract. |
| DCO-8 | **Battle-time equip lockout**: Rule 8's freeze is a behavioral contract, not a system-enforced lock. Workshop System must disable part equip/unequip while a battle is active, ensuring `evaluate()` is never called against a frozen `cached_bonus_block`. If Workshop System fails to enforce this, the freeze breaks silently — the Synergy System does not self-lock. | Workshop System GDD | Equip availability is Workshop System's state machine; adding a self-lock here would duplicate state the Workshop System already owns. |
| DCO-9 | **Beat 3 testable presentation criterion**: the Workshop UI GDD must define a testable acceptance criterion for the first-crossing activation presentation (a clearly perceptible animation + audio cue when a tier first activates — see the Beat 3 binding under Visual/Audio Requirements). This GDD binds the requirement; without a downstream AC it remains normative prose with no enforcement path. | Workshop UI GDD | The presentation implementation and its verification belong to the UI layer; this GDD declares the requirement inherited from its Player Fantasy. |

These obligations must be copied into (or referenced from) the Workshop UI GDD and Combat UI GDD when those are authored. Until then, they are the known, tracked gaps between this system's contract and its presentation.

## Acceptance Criteria

*(Content stat values below are illustrative anchors used to make ACs discriminating — Ironclad 3-piece: armor +8; Ironclad 5-piece: armor +20; VOLT 3-piece: energy_power +6; VOLT 5-piece: energy_power +12, effect `&"volt_test"`; Ironclad-VOLT 3-piece: armor +5, energy_power +4. Real values are authored in Synergy Content data.)*

**AC ownership note**: AC-SYN-06 and AC-SYN-10 validate the **SYN-F4 consumer contract** (`effective_stat = max(0, base + delta)`). `SynergySystem.gd` does NOT compute SYN-F4 — its consumers (Turn-Based Combat, Workshop UI) apply it. These two ACs are therefore **consumer-owned**: they must be implemented in the consumer's test suite (`tests/unit/tbc/` or `tests/unit/workshop_ui/`), not in the Synergy System's. They are stated here because this GDD defines the SYN-F4 formula, but passing them proves nothing about `SynergySystem.gd`. All other ACs (AC-SYN-01…05, 05b, 07…09, 11…27) test the Synergy System's own observable outputs.

**AC-SYN-01: Single-tag 3-piece activation**
Fixture: 8-slot build. Slots 0–2: parts with `synergy_tags = [&"ironclad", &"KINETIC"]`. Slots 3–7: parts with `synergy_tags = [&"KINETIC"]`. ironclad=3 (activates Ironclad 3-piece); VOLT=0 (no VOLT threshold reached; no Ironclad-VOLT combined possible). Ironclad 3-piece content: `stat_delta: { armor: 8 }`, no effects.
Call `evaluate(parts)`.
Pass: `cached_bonus_block.stat_delta["armor"] == 8` AND `cached_bonus_block.stat_delta.size() == 1` (no other stat key present) AND `synergy_changed` signal emitted.

**AC-SYN-02: Cumulative tier stacking (model AC)**
Fixture: Slots 0–4: parts with `synergy_tags = [&"VOLT"]`. Slots 5–7: parts with `synergy_tags = [&"KINETIC"]`. VOLT=5. VOLT 3-piece: `{ energy_power: 6 }`. VOLT 5-piece: `{ energy_power: 12, effects: [&"volt_test"] }`.
Call `evaluate(parts)`.
Pass: `cached_bonus_block.stat_delta["energy_power"] == 18` AND `cached_bonus_block.effects == [&"volt_test"]`.
FAIL: `energy_power == 12` (5-piece-only, non-cumulative bug).

**AC-SYN-03: Combined synergy — stacks with constituent bonuses**
Content: Ironclad 3-piece = `{ armor: 8 }`. VOLT 3-piece = `{ energy_power: 6 }`. Ironclad-VOLT 3-piece = `{ armor: 5, energy_power: 4 }`. All other synergies undefined or inapplicable.

*Scenario A (both conditions met):*
Fixture: Slots 0–2: parts with `synergy_tags = [&"ironclad", &"VOLT"]`. Slots 3–7: parts with `synergy_tags = [&"KINETIC"]`.
Tag counts: ironclad=3, VOLT=3.
Call `evaluate(parts)`.
Pass: `stat_delta["armor"] == 13` (8 from Ironclad 3-piece + 5 from combined) AND `stat_delta["energy_power"] == 10` (6 from VOLT 3-piece + 4 from combined).
FAIL: `armor == 5` (combined replaced constituent); `armor == 8` (combined missing); `armor == 18` (combined double-counted).

*Scenario B (ironclad ≥ 3 but VOLT not met):*
Fixture: Slots 0–2: parts with `synergy_tags = [&"ironclad", &"KINETIC"]`. Slots 3–7: parts with `synergy_tags = [&"KINETIC"]`. Tag counts: ironclad=3, KINETIC=8, VOLT=0.
Call `evaluate(parts)`.
Pass: `stat_delta["armor"] == 8` (Ironclad 3-piece only; combined NOT active because VOLT=0 < 3).
FAIL: `armor == 13` (combined wrongly activated despite VOLT=0).

**AC-SYN-04: Wild parts contribute to element tag only (engine behavior)**
Content: THERMAL 3-piece (ID `"thermal_3_piece"`): `{ stat_delta: { armor: 8 } }` (illustrative anchor). No manufacturer or combined tier is satisfiable in this fixture.
Fixture: Slots 0–3: parts with `synergy_tags = [&"THERMAL"]` only — no manufacturer tag present. Slots 4–7: null. THERMAL=4.
Call `evaluate(parts)`.
Pass (observable outputs only — no white-box access to the internal count map): received `active_synergies` contains `"thermal_3_piece"` AND `active_synergies.size() == 1` (THERMAL 5-piece not reached at 4; no manufacturer or combined tier present) AND `cached_bonus_block.stat_delta == { armor: 8 }`. Because manufacturer tags are absent from every part's `synergy_tags`, the counting loop cannot count them — this is proven by the **absence** of any manufacturer or combined tier ID in `active_synergies` (the public observable), not by asserting an internal `tag_count` value.
FAIL: any manufacturer or combined tier ID appears in `active_synergies`; `"thermal_3_piece"` missing; `active_synergies.size() != 1`.

**AC-SYN-05: Effect ID deduplication**
Fixture: Slots 0–4: VOLT-tagged parts (VOLT=5). VOLT 3-piece: `{ effects: [&"volt_test"] }`. VOLT 5-piece: `{ effects: [&"volt_test"] }` (same ID in both tiers).
Call `evaluate(parts)`.
Pass: `cached_bonus_block.effects.size() == 1` AND `cached_bonus_block.effects[0] == &"volt_test"`.
FAIL: `effects.size() == 2` (deduplication not applied; double-trigger risk in TBC).

**AC-SYN-05b: Keep-first deduplication follows alphabetical tier order, not content-file order**
AC-SYN-05's fixture uses two same-prefix tiers (`volt_3_piece`, `volt_5_piece`), which sort identically under alphabetical order AND content-file order — it cannot discriminate a broken implementation that iterates tiers in content-file order. This AC uses cross-prefix tiers authored in reverse-alphabetical file order to force the distinction.
Content (authored in the data file with the VOLT tier listed FIRST and the ironclad tier SECOND — deliberately reverse-alphabetical): Ironclad 3-piece (`"ironclad_3_piece"`): `{ effects: [&"shared_test", &"ironclad_unique"] }`. VOLT 3-piece (`"volt_3_piece"`): `{ effects: [&"shared_test", &"volt_unique"] }`. No combined tier defined.
Fixture: Slots 0–2: parts with `synergy_tags = [&"ironclad", &"VOLT"]`. Slots 3–7: null. ironclad=3, VOLT=3 → both tiers active.
Call `evaluate(parts)`.
Per SYN-F3, tiers iterate alphabetically (`ironclad_3_piece` before `volt_3_piece`); flatten gives `[shared_test, ironclad_unique, shared_test, volt_unique]`; keep-first dedup gives `[shared_test, ironclad_unique, volt_unique]`.
Pass: `cached_bonus_block.effects == [&"shared_test", &"ironclad_unique", &"volt_unique"]` — strict ordered equality.
FAIL: `effects == [&"shared_test", &"volt_unique", &"ironclad_unique"]` (content-file order used for iteration — the determinism claim in Rule 3/SYN-F3 is violated; reordering the content file would silently change which tier "owns" a shared effect); `effects.size() == 4` (dedup not applied); `effects.size() == 2` (over-deduplication).

**AC-SYN-06: SYN-F4 effective stat computation (self-contained)**
*Owner: consumer (TBC / Workshop UI). Validates the SYN-F4 contract, not `SynergySystem.gd`. Test file: `tests/unit/tbc/` or `tests/unit/workshop_ui/`.*
Fixture (consumer stub — no evaluate() call required):
- `Assembly.final_stat["energy_power"] = 55`
- `synergy_bonus_block.stat_delta = { "energy_power": 18 }` (as if VOLT 3-piece + 5-piece both active)
Apply SYN-F4: `effective_stat["energy_power"] = max(0, 55 + 18)`.
Pass: `effective_stat["energy_power"] == 73`.
FAIL: `55` (bonus not applied); `67` (5-piece only, 55+12); `61` (3-piece only, 55+6).

**AC-SYN-07: Empty build emits signal with empty block**
Fixture: Subscribe to `synergy_changed`. Signal counter initialized to 0.
Call `evaluate([null, null, null, null, null, null, null, null])`.
Pass: signal counter == 1 (emitted per Rule 7 always-emit); received `bonus_block.stat_delta.is_empty() == true`; received `bonus_block.effects.is_empty() == true`.

**AC-SYN-08: preview() is strictly read-only**
Fixture: Slots 0–2: parts with `synergy_tags = [&"ironclad", &"VOLT"]`; slots 3–7: `synergy_tags = [&"KINETIC"]`. ironclad=3, VOLT=3. Call `evaluate(parts)`. `cached_bonus_block.stat_delta["armor"] == 8` (Ironclad 3-piece active). Subscribe to `synergy_changed`; record signal counter = N before preview.
Call `preview(candidate, 0, current_parts)` where `candidate.synergy_tags = [&"KINETIC"]` (no ironclad, no VOLT).
Hypothetical: slot_0 = KINETIC, slots 1–2 = ironclad+VOLT, slots 3–7 = KINETIC. ironclad=2 (below 3-piece threshold); VOLT=2 (below threshold). No tiers active.
Pass: signal counter still == N (not incremented); `cached_bonus_block.stat_delta["armor"]` still == 8; `preview()` return value `stat_delta.is_empty() == true` AND `effects.is_empty() == true`.
FAIL: cache modified; signal emitted; return value contains ironclad bonus.

**AC-SYN-09: Threshold boundary — 5-piece cumulative at exactly 5**
Fixture: VOLT 3-piece: `{ energy_power: 6 }`. VOLT 5-piece: `{ energy_power: 12 }`. Subscribe to `synergy_changed`.

Step 1 (4 VOLT parts): Slots 0–3: VOLT-tagged. Slots 4–7: non-VOLT. Call `evaluate(parts)`.
Pass: `cached_bonus_block.stat_delta["energy_power"] == 6` (VOLT 3-piece active; VOLT 5-piece NOT active at 4 parts).
FAIL: `energy_power == 0` (3-piece missed at 4 parts); `energy_power == 18` (5-piece wrongly active at 4 parts — off-by-one bug).

Step 2 (add 5th VOLT part): Replace slot_4 with VOLT-tagged part (VOLT=5). Call `evaluate(parts)`.
Pass: `cached_bonus_block.stat_delta["energy_power"] == 18` (cumulative: 6 + 12).
FAIL: `energy_power == 12` (non-cumulative); `energy_power == 6` (5-piece not triggered).

**AC-SYN-10: SYN-F4 clamps effective stat to zero**
*Owner: consumer (TBC / Workshop UI). Validates the SYN-F4 contract, not `SynergySystem.gd`. Test file: `tests/unit/tbc/` or `tests/unit/workshop_ui/`.*
Fixture (self-contained consumer stub):
- `Assembly.final_stat["armor"] = 40`
- `synergy_bonus_block.stat_delta = { "armor": -100 }` (content-error penalty)
Apply SYN-F4: `effective_stat["armor"] = max(0, 40 + (-100))`.
Pass: `effective_stat["armor"] == 0`.
FAIL: `-60` (unclamped negative).

**AC-SYN-11: evaluate() always emits synergy_changed**
Fixture: 3 VOLT-tagged parts in slots 0–2 (VOLT=3; VOLT 3-piece active). Subscribe to `synergy_changed`. Signal counter initialized to 0.
Call `evaluate(same_parts)` twice with identical input.
Pass: signal counter == 2 (emitted on both calls per Rule 7 always-emit invariant). `cached_bonus_block` unchanged between calls.

**AC-SYN-12: synergy_changed active_synergies list is exact**
Fixture: Slots 0–4: VOLT-tagged parts (VOLT=5). VOLT 3-piece (ID: `"volt_3_piece"`) and VOLT 5-piece (ID: `"volt_5_piece"`) defined. Subscribe to `synergy_changed`.
Call `evaluate(parts)`.
Pass: received `active_synergies == [&"volt_3_piece", &"volt_5_piece"]` — strict **ordered** equality. This single assertion enforces three things at once: no spurious IDs (a superset such as `["volt_3_piece", "volt_5_piece", "ironclad_3_piece"]` fails), no missing IDs, AND the Rule 3/Rule 7 normative ordering (ascending alphabetical by tier ID). An order-independent containment check is insufficient — an implementation emitting `[&"volt_5_piece", &"volt_3_piece"]` violates the ordering contract that DCO-7 consumers diff against, and only strict equality catches it.
FAIL: any spurious or missing ID; `active_synergies == [&"volt_5_piece", &"volt_3_piece"]` (correct set, wrong order — the Rule 3 ordering contract is violated).

**AC-SYN-13: preview() models both threshold directions**

*Scenario A (candidate activates a new synergy):*
Fixture: Active build with 2 VOLT-tagged parts in slots 0–1 (VOLT=2; below 3-piece threshold). `cached_bonus_block.stat_delta.is_empty() == true`. VOLT 3-piece content: `{ energy_power: 6 }`. Slot 2 currently holds a KINETIC-tagged part (synergy_tags = [&"KINETIC"] — non-VOLT, no other threshold reached).
Call `preview(candidate_volt_part, 2, current_parts)` where `candidate_volt_part.synergy_tags = [&"VOLT"]`.
Hypothetical: slots 0–2 VOLT-tagged → VOLT=3 → VOLT 3-piece activates.
Pass: return value `stat_delta["energy_power"] == 6`; `cached_bonus_block.stat_delta.is_empty() == true` (actual cache unchanged); `synergy_changed` NOT emitted.

*Scenario B (candidate deactivates a synergy):*
Fixture: Active build with 3 VOLT-tagged parts in slots 0–2 (VOLT=3; VOLT 3-piece active). Call `evaluate(parts)`; assert `cached_bonus_block.stat_delta["energy_power"] == 6`. Subscribe to `synergy_changed`; record signal counter = N.
Call `preview(candidate_kinetic_part, 0, current_parts)` where `candidate_kinetic_part.synergy_tags = [&"KINETIC"]` (not VOLT).
Hypothetical: slot_0 = KINETIC, slots 1–2 = VOLT → VOLT=2 in hypothetical → below 3-piece threshold → no tiers active.
Pass: return value `stat_delta.is_empty() == true` (VOLT 3-piece deactivated in hypothetical); `cached_bonus_block.stat_delta["energy_power"]` still == 6 (cache unmodified); signal counter still == N (no emission).
FAIL: return value `stat_delta["energy_power"] == 6` — preview failed to model deactivation. This is the discriminating check against a delta-approach implementation that adds the candidate's tags to the cached state but never subtracts the displaced part's tags; such an implementation passes Scenario A and every other AC while being wrong.

**AC-SYN-14: evaluate_silent() computes correctly and does not emit**

*Scenario A (single-tag cumulative):*
Fixture: Slots 0–4: VOLT-tagged parts (VOLT=5). VOLT 3-piece: `{ energy_power: 6 }`. VOLT 5-piece: `{ energy_power: 12, effects: [&"volt_test"] }`. Subscribe to `synergy_changed`. Signal counter initialized to 0.
Call `evaluate_silent(parts)`.
Pass: signal counter == 0 (no emission); `cached_bonus_block.stat_delta["energy_power"] == 18`; `cached_bonus_block.effects == [&"volt_test"]`.
FAIL: counter > 0 (spurious `synergy_changed` emitted — would trigger Workshop UI subscribers at battle start); `energy_power != 18` (silent path computes differently from `evaluate()`); `cached_bonus_block` empty (silent path did not cache).

*Scenario B (combined synergy through the silent path):*
Fixture: the AC-SYN-03 Scenario A content and build (slots 0–2: `[&"ironclad", &"VOLT"]`; slots 3–7: `[&"KINETIC"]`; ironclad=3, VOLT=3 → Ironclad 3-piece + VOLT 3-piece + Ironclad-VOLT 3-piece all active). Subscribe to `synergy_changed`; counter = 0.
Call `evaluate_silent(parts)`.
Pass: signal counter == 0; `cached_bonus_block.stat_delta["armor"] == 13` AND `stat_delta["energy_power"] == 10` (identical to AC-SYN-03's `evaluate()` outputs).
FAIL: counter > 0; `armor == 8` or `energy_power == 6` (the multi-requirement SYN-F2 check diverges in the silent path — the exact bug class the shared-compute-core guidance prevents).

Note: Scenario A matches AC-SYN-02's fixture and Scenario B matches AC-SYN-03's, so any divergence between `evaluate()` and `evaluate_silent()` on either the single-tag or the combined path is immediately visible by comparing outputs across the paired ACs. (Implementation guidance: have both methods delegate to one private compute function so path divergence is impossible by construction.)

**AC-SYN-15: Tier deactivation when count drops below threshold**
Fixture: VOLT 3-piece: `{ energy_power: 6 }`. VOLT 5-piece: `{ energy_power: 12 }`. Subscribe to `synergy_changed`. Signal counter initialized to 0.
Step 1 — Activate: Slots 0–4: VOLT-tagged (VOLT=5). Call `evaluate(parts)`. Assert `cached_bonus_block.stat_delta["energy_power"] == 18` (both VOLT tiers active). Counter == 1.
Step 2 — Deactivate 5-piece: Replace slot_4 with a non-VOLT part (VOLT=4). Call `evaluate(parts)`.
Pass: `cached_bonus_block.stat_delta["energy_power"] == 6` (5-piece deactivated; 3-piece still active at VOLT=4); signal counter == 2 (signal emitted on deactivation call).
FAIL: `energy_power == 18` (5-piece not deactivated — stale cache bug); `energy_power == 0` (3-piece also wrongly deactivated); signal counter still == 1 (deactivation signal not emitted).

**AC-SYN-16: Combined synergy's unique effect ID is preserved (not over-deduplicated)**
This is the inverse of AC-SYN-05. AC-SYN-05 confirms a *duplicated* effect ID collapses to one; this AC confirms a *unique* combined-synergy effect ID is NOT wrongly discarded by an over-aggressive deduplication implementation.
Content: Ironclad 3-piece (`"ironclad_3_piece"`): `{ effects: [&"ironclad_test"] }`. VOLT 3-piece (`"volt_3_piece"`): `{ effects: [&"volt_test"] }`. Ironclad-VOLT 3-piece (`"ironclad_volt_3_piece"`): `{ effects: [&"combined_test"] }` — a UNIQUE ID present in neither constituent.
Fixture: Slots 0–2: parts with `synergy_tags = [&"ironclad", &"VOLT"]`. Slots 3–7: parts with `synergy_tags = [&"KINETIC"]`. Tag counts: ironclad=3, VOLT=3 → all three tiers active.
Call `evaluate(parts)`.
Pass: `cached_bonus_block.effects.size() == 3` AND the array contains all of `&"ironclad_test"`, `&"volt_test"`, `&"combined_test"`.
FAIL: `size() == 2` (combined's unique effect silently discarded — dedup wrongly applied against all tiers instead of keep-first-on-duplicates); `size() < 2` (constituent effects also dropped).

**AC-SYN-17: Unknown stat key in stat_delta does not crash aggregation (EC-SYN-06)**
Fixture: VOLT 3-piece content authored with a stat key not in Assembly's 11-stat schema: `{ stat_delta: { "speed": 10 } }` ("speed" is not a valid stat — content error). Slots 0–2: VOLT-tagged (VOLT=3). Subscribe to `synergy_changed`; counter initialized to 0.
Call `evaluate(parts)`.
Pass: no crash; signal counter == 1; `cached_bonus_block.stat_delta` contains key `"speed"` with value `10` (SYN-F3 aggregates blindly — it does not validate stat names). A consumer iterating the 11 known stats via `.get(S, 0)` never reads `"speed"`, so the unknown key is inert downstream.
FAIL: crash during aggregation (e.g., `[]` index access on a schema lookup rather than tolerant aggregation); signal not emitted; `stat_delta` does not contain `"speed"` (unknown key silently dropped — a filtering implementation rather than the specified blind aggregation).

**AC-SYN-18: evaluate() tolerates wrong-length arrays (EC-SYN-10)**
VOLT 3-piece: `{ energy_power: 6 }`. Two scenarios, each asserting no crash and correct counting.

*Scenario A (short array — 5 entries):* Call `evaluate([volt, volt, volt, null, null])` (indices 5–7 missing). Missing indices are treated as null.
Pass: no crash; `cached_bonus_block.stat_delta["energy_power"] == 6` (VOLT=3 → 3-piece active); a content/programming error is logged.
FAIL: index-out-of-bounds error thrown (missing indices not treated as null); energy_power != 6.

*Scenario B (long array — 10 entries):* Call `evaluate([volt, volt, volt, null, null, null, null, null, volt, volt])` (indices 8–9 are VOLT parts beyond slot 7). Indices beyond 7 must be ignored.
Pass: no crash; only indices 0–7 counted → VOLT=3 (not 5) → VOLT 3-piece active, VOLT 5-piece NOT active; `cached_bonus_block.stat_delta["energy_power"] == 6`; a content/programming error is logged.
FAIL: `energy_power == 18` (indices 8–9 wrongly counted, tipping VOLT to 5); crash.

**AC-SYN-19: Part with empty or null synergy_tags contributes no counts (EC-SYN-07)**

*Scenario A (empty array):*
Fixture: 8-slot build. Slots 0–2: parts with `synergy_tags = [&"ironclad", &"VOLT"]`. Slot 3: a non-null `SympartData` with `synergy_tags = []` (content-error part). Slots 4–7: null. Content: Ironclad 3-piece = `{ armor: 8 }`; no VOLT tier defined for this fixture. Subscribe to `synergy_changed`; counter = 0.
Call `evaluate(parts)`. ironclad = 3 (slots 0–2 only — slot 3 must NOT contribute).
Pass: no crash; signal counter == 1; `cached_bonus_block.stat_delta["armor"] == 8` AND `cached_bonus_block.stat_delta.size() == 1` (slot 3 did not inflate any count); `active_synergies.size() == 1` (only `ironclad_3_piece`).
FAIL: `armor == 0` (slot 3 wrongly blocked counting); any additional tier present (slot 3 wrongly contributed a count — e.g., an implementation substituting a default tag for empty arrays); crash.

*Scenario B (null field):*
Same fixture, but slot 3's `SympartData` has `synergy_tags = null` (not `[]`).
Pass: identical to Scenario A — no crash, `armor == 8`, `size() == 1`, `active_synergies.size() == 1`. The null field is treated exactly as `[]` per EC-SYN-07's null-guard requirement.
FAIL: runtime error on iteration (`for tag in null` — null-guard missing); any count contributed by slot 3.

**AC-SYN-20: preview() returns empty block on out-of-range target_slot (Rule 9)**
Setup: the AC-SYN-02 fixture (5 VOLT-tagged parts). Call `evaluate(parts)` to establish a non-empty `cached_bonus_block` (`energy_power == 18`). Subscribe to `synergy_changed`; counter = N.

*Scenario A (target_slot < 0):* Call `preview(candidate_part, -1, current_parts)`.
Pass: no crash; return value `stat_delta.is_empty() == true` AND `effects.is_empty() == true`; signal counter still == N; `cached_bonus_block` unchanged (`energy_power` still == 18); a content error is logged.
FAIL: crash (unchecked negative index — GDScript negative indices wrap, silently displacing the wrong slot); return value contains any bonus data; signal emitted.

*Scenario B (target_slot > 7):* Call `preview(candidate_part, 8, current_parts)`.
Pass: no crash; return value `stat_delta.is_empty() == true` AND `effects.is_empty() == true`; signal counter still == N; `cached_bonus_block` unchanged; a content error is logged.
FAIL: crash (out-of-bounds access on `current_parts[8]`); return value contains any bonus data; signal emitted.

**AC-SYN-21: Duplicate tags within a part inflate the count per SYN-F1 (EC-SYN-11)**
Fixture: Slots 0–2: parts with `synergy_tags = [&"ironclad", &"ironclad", &"VOLT"]` (two ironclad tags per part — content error). Slots 3–7: null. Content: Ironclad 3-piece: `{ armor: 8 }`; Ironclad 5-piece: `{ armor: 20 }`.
Per SYN-F1, each part contributes 2 ironclad counts → ironclad = 6 total.
Call `evaluate(parts)`.
Pass: no crash; `active_synergies` contains `ironclad_5_piece` (count 6 ≥ 5); `cached_bonus_block.stat_delta["armor"] == 28` (8 + 20, both tiers active from the inflated count).
FAIL: crash; `armor == 8` (5-piece suppressed by a per-part dedup that the spec does not define); `armor == 0` (error handling wrongly zeroed the block).
Note: this AC documents the INTENDED behavior per EC-SYN-11 and SYN-F1 — count each occurrence. It proves the system does NOT silently deduplicate within-part tags. Content validation prevents authoring such parts; the Synergy System follows its own spec under this input.

**AC-SYN-22: Tier with empty requirements is skipped and logged (EC-SYN-12)**
Fixture: Register a synergy tier `"bad_tier"` with `requirements = []`. Slots 0–7: null (the completely empty build — the strongest fixture, since the tier would fire on this build if the vacuous-truth bug is present). Subscribe to `synergy_changed`; counter = 0.
Call `evaluate([null, null, null, null, null, null, null, null])`.
Pass: no crash; signal counter == 1; `active_synergies.size() == 0` (`bad_tier` NOT activated); `cached_bonus_block.stat_delta.is_empty() == true`; a content error is logged naming `"bad_tier"`.
FAIL: `active_synergies` contains `"bad_tier"` (vacuous-truth bug — permanently-active tier on an empty build); crash; no log emitted.

**AC-SYN-23: Tier with min_count = 0 is skipped and logged (EC-SYN-13)**
Fixture: Register a synergy tier `"zero_tier"` with `requirements = [(&"VOLT", 0)]` (non-empty list — passes the EC-SYN-12 check — but vacuously satisfiable). Slots 0–7: null (empty build). Subscribe to `synergy_changed`; counter = 0.
Call `evaluate([null, null, null, null, null, null, null, null])`.
Pass: no crash; signal counter == 1; `active_synergies.size() == 0` (`zero_tier` NOT activated despite `tag_count[VOLT] = 0 ≥ 0` being true); `cached_bonus_block.stat_delta.is_empty() == true`; a content error is logged naming `"zero_tier"`.
FAIL: `active_synergies` contains `"zero_tier"` (the min_count=0 vacuous-activation bug — the non-empty-list guard alone does not catch this); crash; no log emitted.

**AC-SYN-24: preview() with null candidate models unequip (EC-SYN-14)**
Fixture: Slots 0–2: VOLT-tagged parts (VOLT=3; VOLT 3-piece active, `{ energy_power: 6 }`). Slots 3–7: null. Call `evaluate(parts)`; assert `cached_bonus_block.stat_delta["energy_power"] == 6`. Subscribe to `synergy_changed`; record signal counter = N.
Call `preview(null, 0, current_parts)`.
Hypothetical: slot 0 empty → VOLT=2 → below threshold → no tiers active.
Pass: no crash; return value `stat_delta.is_empty() == true` AND `effects.is_empty() == true` (VOLT 3-piece deactivated in hypothetical); `cached_bonus_block.stat_delta["energy_power"]` still == 6 (cache unmodified); signal counter still == N; no content error logged (null candidate is valid input).
FAIL: runtime error on `null.synergy_tags` (null-guard missing); return value `stat_delta["energy_power"] == 6` (null candidate ignored — hypothetical failed to displace the current occupant); cache modified; signal emitted.

**AC-SYN-25: evaluate() after evaluate_silent() overwrites the cache (Rule 8 is behavioral, not a lock)**
Rule 8's freeze is a caller contract — the system must NOT self-lock after `evaluate_silent()`. This AC proves `evaluate()` still works after a silent call (a self-locking implementation would silently break Workshop live recalculation after the first battle).
Fixture: Slots 0–4: VOLT-tagged (VOLT=5). Call `evaluate_silent(parts)`; assert `cached_bonus_block.stat_delta["energy_power"] == 18`. Subscribe to `synergy_changed`; counter = 0.
Call `evaluate([null, null, null, null, null, null, null, null])` (the empty build).
Pass: `cached_bonus_block.stat_delta.is_empty() == true` (cache replaced, not frozen); signal counter == 1.
FAIL: `energy_power` still == 18 (system self-locked after evaluate_silent — forbidden by Rule 8's rationale); counter == 0.

**AC-SYN-26: Unregistered effect IDs pass through unfiltered (EC-SYN-05)**
Fixture: VOLT 3-piece content: `{ effects: [&"unregistered_test_effect"] }` — an ID registered in no TBC registry. Slots 0–2: VOLT-tagged (VOLT=3).
Call `evaluate(parts)`.
Pass: `cached_bonus_block.effects == [&"unregistered_test_effect"]` — the system emits the ID transparently; it performs no known-effects filtering (skip-and-log on unknown IDs is TBC's responsibility, per EC-SYN-05).
FAIL: `effects.is_empty()` (a defensive filter silently dropped the ID — the Synergy System must not own effect-registry knowledge); crash.

**AC-SYN-27: Seven simultaneously active tiers aggregate correctly (EC-SYN-02 maximum)**
The max-stress pass through SYN-F3's aggregation loop — bugs that manifest only at higher active-tier counts (accumulation errors, dictionary-merge collisions) are invisible to the 2–3 tier fixtures elsewhere.
Content (illustrative anchors): Ironclad 3-piece `{ armor: 8 }`; Ironclad 5-piece `{ armor: 20 }`; VOLT 3-piece `{ energy_power: 6 }`; VOLT 5-piece `{ energy_power: 12 }`; KINETIC 3-piece `{ armor: 4 }`; Ironclad-VOLT 3-piece `{ armor: 5, energy_power: 4 }`; Ironclad-KINETIC 3-piece `{ armor: 3 }`.
Fixture: Slots 0–4: parts with `synergy_tags = [&"ironclad", &"VOLT"]`. Slots 5–7: parts with `synergy_tags = [&"ironclad", &"KINETIC"]`. Tag counts: ironclad=8, VOLT=5, KINETIC=3 → all 7 tiers active.
Call `evaluate(parts)`.
Pass: `active_synergies.size() == 7`; `cached_bonus_block.stat_delta["armor"] == 40` (8+20+4+5+3) AND `stat_delta["energy_power"] == 22` (6+12+4).
FAIL: `active_synergies.size() < 7` (a tier lost during high-count evaluation); any stat sum short of the cumulative total (aggregation error at higher tier counts).

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-1 | What is the Synergy Content data format? A dedicated `SynergyDatabase.tres`? Part of `PartDatabase.tres`? Separate file loaded at startup? | Technical Director / Lead Programmer | Determines how synergy definitions are authored and loaded |
| OQ-2 | What are the MVP stat bonus values for each synergy tier, and what per-tier per-stat cap bounds the 7-tier worst-case sum (EC-SYN-02)? Balancing must validate the maximum-concentration build's cumulative delta against the intended effective-stat ceiling, not just tune tiers individually — see the cumulative budget constraint in Tuning Knobs. **Calibration mandates (added re-review #5)**: (i) manufacturer-tier bonuses must compensate their structurally higher access cost — wild parts pad element counts for free while manufacturer counts cannot be padded, so equal-magnitude bonuses de facto favor element-only builds; (ii) every authored combined synergy must be reachable — the MVP part pool must include enough dual-tag parts (both constituent tags on one part) for each combined tier, a constraint on Part Database content; (iii) viability target: a TIER1-active build using average-stat parts must be competitive with the best pure-stat build in the same loot tier, or the system becomes optional noise. | Economy Designer (balance tuning) + Part Database content | Content work, but all three mandates plus the cumulative-budget validation are mandatory before MVP content ships |
| OQ-3 | Which passive effect IDs are feasible to implement for MVP, and what behavior does each define? | Turn-Based Combat GDD | Blocks authoring any effect-bearing synergy content until TBC GDD defines the registry |
| OQ-4 | Does CORE's synergy contribution need to be mechanically distinct from other slots, or does its tag contribution alone fulfill the "CORE identity" deferred obligation from Assembly? | Game Designer | May require revisiting Assembly Deferred Obligation #5 when TBC is designed |
| OQ-5 | What would the Vertical Slice team-wide synergy feature look like? (e.g., 2+ Symbots sharing a tag for a team-level bonus?) | Deferred to Vertical Slice design | No impact on MVP system |
| OQ-6 | **RESOLVED (2026-07-10)** — SA-F2 returns a signed delta (`delta[S] = hypothetical_final_stat[S] − current_final_stat[S]`), confirmed from Assembly GDD. Workshop UI combined effective-stat display formula: `effective_delta[S] = SA-F2.delta[S] + (preview().stat_delta.get(S, 0) − cached_bonus_block.stat_delta.get(S, 0))`. Precondition: Workshop System must call `evaluate()` after every equip before `preview()` is called, to avoid stale `cached_bonus_block`. Workshop UI GDD authoring is unblocked. | Resolved | None |
| OQ-7 | What is the minimum number of parts per synergy tag (per slot type) required to make Beat 2 (The Hunt) feel like a real search vs. trivial threshold-hitting? With TIER1=3 and 8 slots, a tag needs at least 5–6 authored parts in circulation with meaningful slot competition to create genuine scarcity pressure. **HARD CONSTRAINT (upgraded re-review #5)**: this is not advisory — the Part Database content plan and the Drop System GDD must each explicitly validate Beat 2 delivery against this minimum before their content ships; a Synergy System operating on a too-thin loot pool delivers thresholds without a hunt. | Economy Designer / Part Database content scope / Drop System GDD | Beat 2 fails at MVP content volume if unmet — a gate on downstream GDDs, not on this one |
