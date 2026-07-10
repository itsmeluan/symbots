# Synergy System

> **Status**: In Design
> **Author**: Luan Martins da Silva + Claude Code Game Studios agents
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 4 — Synergy Is the Endgame / Pillar 3 — Build Depth Over Content Breadth

## Overview

The Synergy System reads the `synergy_tags` carried by all 8 equipped parts and determines which elemental and manufacturer set bonuses are active for a given Symbot build. When enough parts share a tag — element, manufacturer, or a combined element-plus-manufacturer combination — the system activates a bonus block that augments the Symbot's stats beyond what the Assembly stat pipeline produces on its own. This bonus is computed independently of Assembly and added on top by Turn-Based Combat and the Workshop UI when resolving effective stats. The player engages with synergy actively: every part decision is a choice between concentrating toward a threshold or diversifying across multiple partial sets. At its best, synergy is the moment a build "clicks" — equipping a third Ironclad part and watching a defensive bonus snap into place is the specific feeling this system exists to create.

## Player Fantasy

Synergy is the reason every part slot matters. The player shouldn't just fill slots with the highest base stats — they should feel the pull of *almost* completing a bonus, the satisfaction when it activates, and the sting of sacrificing a partial set to chase a different one. The core feeling is: **I built something intentional.**

The synergy experience unfolds across five beats:

1. **Recognition** — Two Ironclad parts in the build reveal a greyed-out "Ironclad: 2 of 3 — Armor +15 when complete" indicator. The bonus is within reach.
2. **The Hunt** — The player starts evaluating every part drop by its tags, not just its stats. "Does this get me to Ironclad 3?"
3. **The Click** — The third Ironclad part equips. The bonus activates. Audio and visual confirmation. The Symbot's defensive profile changes.
4. **The Tradeoff** — A better WEAPON drops with a different manufacturer tag. Equipping it breaks the set. The player pauses: is the raw stat gain worth losing the activation?
5. **Mastery** — The player learns to hold partial synergies across multiple team members, or to stack element tags across manufacturer lines for a cross-synergy build. The system opens up beyond single-Symbot optimization.

The reference feeling: Monster Hunter's armor set skills — where you're not hunting stats, you're hunting *pieces of a concept*. Symbots should create the same intentionality.

## Detailed Design

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
| 2-piece | ≥ 2 parts share the required tag(s) | Small bonus activates |
| 4-piece | ≥ 4 parts share the required tag(s) | Large bonus activates |

Tiers are **cumulative**: at 4-piece, both the 2-piece AND the 4-piece bonus apply. The player receives all bonuses from every tier they have crossed.

Combined synergies (e.g., Ironclad-VOLT) require ALL constituent conditions met simultaneously: `ironclad ≥ 2` AND `VOLT ≥ 2`. Combined bonuses stack additively with their constituent single-tag bonuses.

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

**Rule 6: Passive effects contract.**
A passive effect is a `StringName` ID (e.g., `&"volt_shock_on_hit"`). This system detects which effect IDs are active and emits them. The Turn-Based Combat GDD defines what each effect ID does in battle. No effect ID may be authored in synergy content until it is registered in the TBC GDD.

**Rule 7: Trigger events.**
`evaluate(parts: Array[SympartData])` is called by:
- **Workshop System**: after every part equip or unequip
- **Turn-Based Combat**: once at battle start to establish the baseline bonus block
- Never called by Assembly (one-way dependency is inviolable)

**Rule 8: Frozen during battle.**
Once a battle begins, `cached_bonus_block` is frozen. Part breaks during combat do not trigger re-evaluation. If the Part-Break System needs mid-battle synergy adjustment, that is deferred to the Part-Break GDD.

**Rule 9: Read-only preview.**
The Workshop UI may call `preview(candidate_part, target_slot, current_parts)` to compute the hypothetical `synergy_bonus_block` if a candidate part were placed in a slot. This call:
- Does NOT emit `synergy_changed`
- Does NOT modify `cached_bonus_block`
- Returns the hypothetical block for UI comparison only

The Workshop UI diffs hypothetical vs. current and surfaces any threshold crossings (new activations, lost activations). This fulfills Assembly's Deferred Design Obligation #6.

---

### States and Transitions

The Synergy System is a stateless pure computation. It holds one cached result, replaced on each `evaluate()` call.

| Event | Action | Result |
|-------|--------|--------|
| `evaluate(parts)` called | Recompute tag counts → check all synergy definitions → aggregate bonus blocks | Update `cached_bonus_block`; emit `synergy_changed(active_synergies, bonus_block)` |
| Battle starts | TBC calls `evaluate()` | Baseline `cached_bonus_block` established; frozen until battle ends |
| Part equipped in Workshop | Workshop System calls `evaluate()` | Live recalculation and signal |
| Part unequipped in Workshop | Workshop System calls `evaluate()` | Live recalculation and signal |
| `preview(candidate, slot, parts)` called | Read-only evaluation | Returns hypothetical block; no signal, no cache write |

---

### Interactions with Other Systems

| System | Direction | Interface | Data Exchanged |
|--------|-----------|-----------|----------------|
| **Symbot Assembly** | ← reads from | `SymbotBuild.get_parts()` | `Array[SympartData]` (8 entries, null for empty slots) |
| **Part Database** | ← reads from | `SympartData.synergy_tags` | `Array[StringName]` tags per part |
| **Workshop System** | ← triggered by | `evaluate(parts)` called on equip/unequip | Provides current part list |
| **Turn-Based Combat** | ← triggered by, → provides | `evaluate(parts)` at battle start; provides `cached_bonus_block` | Stat delta dict + effect ID array |
| **Workshop UI** | → provides on signal | `synergy_changed` signal; `preview()` return value | Bonus block for live display and swap preview |

Assembly does NOT call Synergy. Assembly `final_stat` does NOT incorporate synergy bonuses.

## Formulas

The Synergy System's computations are entirely integer-based. No floating-point arithmetic is used, so no epsilon nudges are needed.

---

**SYN-F1: Tag Count**

```
tag_count[tag] = Σ (1 for each equipped part p where tag ∈ p.synergy_tags)
```

Variables:
- `tag` — a `StringName` (e.g., `&"ironclad"`, `&"VOLT"`)
- `p.synergy_tags` — `Array[StringName]` on each non-null `SympartData`
- Null slots contribute 0

Output range: `[0, 8]` (at most 8 occupied slots)

---

**SYN-F2: Tier Activation Check**

A synergy tier is active if and only if ALL of its required tag counts are satisfied:

```
tier_active(tier) = ∀ (tag, min_count) ∈ tier.requirements :
                      tag_count[tag] ≥ min_count
```

Variables:
- `tier.requirements` — list of `(tag, min_count)` pairs

Output: boolean

Examples:
- Ironclad 2-piece: `[(ironclad, 2)]` → true when `tag_count[ironclad] ≥ 2`
- VOLT 4-piece: `[(VOLT, 4)]` → true when `tag_count[VOLT] ≥ 4`
- Ironclad-VOLT 2-piece: `[(ironclad, 2), (VOLT, 2)]` → true when both counts ≥ 2

---

**SYN-F3: Bonus Block Aggregation**

```
synergy_bonus_block.stat_delta[S] = Σ tier.stat_delta.get(S, 0)
                                      for all tiers where tier_active(tier) = true

synergy_bonus_block.effects = deduplicate(
  flatten([tier.effects for all active tiers])
)
```

Output: `stat_delta` is a `Dictionary[String, int]`; `effects` is `Array[StringName]`

Deduplication on effects matters: if two active tiers both grant `&"volt_shock_on_hit"`, the ID appears only once in the output. This prevents double-triggering in TBC.

---

**SYN-F4: Effective Stat (contract for TBC and Workshop UI)**

Consumers that need the effective stat (for damage calculation or display) apply:

```
effective_stat[S] = max(0, Assembly.final_stat[S] + synergy_bonus_block.stat_delta.get(S, 0))
```

Variables:
- `Assembly.final_stat[S]` — integer from SA-F1, already ≥ 0
- `synergy_bonus_block.stat_delta.get(S, 0)` — integer synergy bonus; 0 if no active synergy affects stat `S`

Output: integer ≥ 0. Stats are uncapped above (no `stat_max` ceiling — matching SA-F1 behavior).

In MVP, all authored synergy stat_delta values are non-negative (no penalty synergies). The `max(0,…)` floor is a content-error defense only.

---

**Worked Example**

Build (8 slots — 6 occupied, 2 empty):
1. HEAD: ironclad, VOLT → tags `[ironclad, VOLT]`
2. WEAPON: ironclad, VOLT → tags `[ironclad, VOLT]`
3. CORE: ironclad, KINETIC → tags `[ironclad, KINETIC]`
4. ARMS: boltwell, VOLT → tags `[boltwell, VOLT]`
5. LEGS: wild, VOLT → tags `[VOLT]`
6. ENERGY_CELL: wild, THERMAL → tags `[THERMAL]`
7. BACK: null → no tags
8. CHIPSET: null → no tags

**SYN-F1 results:**
```
tag_count = { ironclad: 3, boltwell: 1, VOLT: 4, KINETIC: 1, THERMAL: 1 }
```

**SYN-F2 tier activation** *(using illustrative content values — real values set in Synergy Content data)*:

| Tier | Requirements | Active? |
|------|-------------|---------|
| Ironclad 2-piece | ironclad ≥ 2 | ✓ (3 ≥ 2) → armor +8 |
| Ironclad 4-piece | ironclad ≥ 4 | ✗ (3 < 4) |
| VOLT 2-piece | VOLT ≥ 2 | ✓ (4 ≥ 2) → energy_power +6 |
| VOLT 4-piece | VOLT ≥ 4 | ✓ (4 ≥ 4) → energy_power +12, `volt_shock_on_hit` |
| Ironclad-VOLT 2-piece | ironclad ≥ 2 AND VOLT ≥ 2 | ✓ → armor +5, energy_power +4 |

**SYN-F3 aggregation:**
```
stat_delta = { armor: 8+5=13, energy_power: 6+12+4=22 }
effects    = [ &"volt_shock_on_hit" ]
```

The discriminating case: VOLT 2-piece and 4-piece both apply (6 + 12 = 18 from VOLT alone). A wrong implementation that applies only the highest tier would yield energy_power 12 + 4 = 16 — not 22. The acceptance criteria must verify the cumulative total.

**SYN-F4** *(base stats: armor = 40, energy_power = 55)*:
```
effective_stat[armor]        = max(0, 40 + 13) = 53
effective_stat[energy_power] = max(0, 55 + 22) = 77
```

## Edge Cases

**EC-SYN-01: All slots empty.**
`evaluate()` receives 8 null entries. SYN-F1 counts are all zero. No synergy tier is active. `synergy_bonus_block = { stat_delta: {}, effects: [] }`. Signal emits with the empty block. No crash.

**EC-SYN-02: Maximum tag concentration.**
All 8 parts share the same manufacturer AND element (e.g., 8 Ironclad-VOLT parts). Both 2-piece and 4-piece activate for Ironclad, for VOLT, and for Ironclad-VOLT (6 tiers active total). All bonuses stack cumulatively per SYN-F3. There is no cap on the number of simultaneously active tiers.

**EC-SYN-03: Wild parts used to reach an element threshold.**
A build uses 4 wild THERMAL parts (element tags only, no manufacturer tag). `tag_count[THERMAL] = 4`. THERMAL 2-piece and 4-piece both activate. No manufacturer synergy activates for those slots. Correct behavior per Rule 2 — wild parts intentionally enable element-focus builds that sacrifice manufacturer synergy.

**EC-SYN-04: Same effect ID granted by multiple active tiers.**
VOLT 2-piece and VOLT 4-piece both include `&"volt_shock_on_hit"`. After SYN-F3 deduplication, the effect appears exactly once in `synergy_bonus_block.effects`. TBC triggers the effect at most once per applicable event. If the effect appears twice in the output, the AC for this case fails.

**EC-SYN-05: Effect ID not registered in TBC.**
A content author adds a new effect ID to a synergy tier before it is defined in the TBC GDD. The Synergy System emits the unknown ID in the effects array. TBC is responsible for logging a content error (unknown effect ID) and skipping it without crashing. This is a content error, not a system error.

**EC-SYN-06: stat_delta references a stat not in Assembly's 11-stat schema.**
A content error produces `stat_delta = { "speed": 10 }`. SYN-F3 aggregates it into `synergy_bonus_block`. Consumers call `.get(S, 0)` for each of the 11 known stats and receive 0 for "speed". The unknown key is silently ignored. No crash. This is detectable only by content validation tooling.

**EC-SYN-07: Part with empty synergy_tags array.**
A `SympartData` has `synergy_tags = []` (content error — Part DB requires at least an element tag). The system iterates an empty array and contributes no counts. No crash. The part acts as a synergy-inert slot. This is a Part DB validation failure; the Synergy System is not responsible for detecting it.

**EC-SYN-08: Negative stat_delta in content.**
A content author accidentally authors a penalty synergy: `stat_delta = { armor: -5 }`. SYN-F3 aggregates `armor: -5` into `synergy_bonus_block`. SYN-F4 applies it: `effective_stat[armor] = max(0, Assembly.final_stat[armor] - 5)`. If the penalty exceeds the base stat, the result is clamped to 0, not negative. This is the intended defensive floor — the player's stat cannot be driven below zero by a content error.

**EC-SYN-09: preview() candidate is the currently equipped part.**
No change — hypothetical evaluation returns a block identical to `cached_bonus_block`. All stat deltas are 0. No threshold crossings. The Workshop UI shows "no change" for this slot.

**EC-SYN-10: evaluate() receives wrong-length array.**
If fewer than 8 entries are provided (programming error), missing indices are treated as null (no tags contributed). If more than 8 entries are provided, indices beyond 7 are ignored. The system logs a content/programming error in both cases but does not crash.

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
| **Turn-Based Combat** | `cached_bonus_block` (stat_delta + effects) at battle start; applies SYN-F4 for effective stats; resolves passive effect IDs | Not Started | TBC GDD must document its Synergy dependency and define the passive effect ID registry |
| **Workshop System** | Triggers `evaluate()` on every equip/unequip | Not Started | Workshop System GDD must document its Synergy call |
| **Workshop UI** | Reads `synergy_bonus_block` via `synergy_changed` signal and `preview()` return value | Not Started | Workshop UI GDD must document its Synergy read interface |

---

### Deferred Dependency (future)

| System | Nature | When |
|--------|--------|------|
| **Part-Break System** | Rule 8 explicitly freezes synergy during battle. If Part-Break ever needs to affect synergy mid-battle (e.g., a broken part loses its tag contributions), that interaction must be defined in the Part-Break GDD and this rule revisited. | Part-Break GDD design |

## Tuning Knobs

| Knob | Value | Unit | Safe Range | Gameplay Effect |
|------|-------|------|------------|-----------------|
| `SYNERGY_THRESHOLD_TIER1` | 2 | parts | 2–3 | How easily a small bonus triggers. At 1, every build triggers every single-tag synergy (degenerate). At 3, requires deliberate investment even for the small reward. |
| `SYNERGY_THRESHOLD_TIER2` | 4 | parts | 3–6 | How much commitment the large bonus demands. Must be > TIER1. At 3, achievable alongside other synergies (too easy with 8 slots). At 6, only near-total concentration qualifies. |

All **bonus values** (stat_delta per tier, effect IDs per tier) are content data authored in the Synergy Content data file — not system constants. Changing a bonus value requires only a content edit; changing a threshold requires a design decision.

Combined synergies use `SYNERGY_THRESHOLD_TIER1` as the per-tag minimum (≥ 2 for each constituent tag). This is not a separate knob in MVP — if combined synergies need different thresholds, that becomes a per-synergy-definition data field rather than a global constant.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
