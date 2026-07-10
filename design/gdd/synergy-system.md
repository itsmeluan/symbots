# Synergy System

> **Status**: In Review
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

`evaluate_silent(parts: Array[SympartData])` is called by **Turn-Based Combat** once at battle start to establish the baseline bonus block. It computes and caches the bonus block identically to `evaluate()` but does NOT emit `synergy_changed`. This prevents Workshop UI subscribers from receiving a spurious signal at battle start.

Signal parameters:
- `active_synergies: Array[StringName]` — ordered list of tier IDs for all currently active tiers (e.g., `[&"volt_3_piece", &"volt_5_piece"]`), iterated in synergy-definition registration order
- `bonus_block: Dictionary` — the aggregated `synergy_bonus_block` (stat_delta + effects)

**Rule 8: Frozen during battle.**
Once a battle begins, `cached_bonus_block` is frozen. Part breaks during combat do not trigger re-evaluation. If the Part-Break System needs mid-battle synergy adjustment, that is deferred to the Part-Break GDD.

**Rule 9: Read-only preview.**
The Workshop UI may call `preview(candidate_part, target_slot, current_parts)` to compute the hypothetical `synergy_bonus_block` if a candidate part were placed in a slot. The hypothetical build is identical to `current_parts` except that `current_parts[target_slot]` is replaced by `candidate_part` (the current occupant is displaced — matching the SA-F2 displacement contract). If `target_slot` is out of range (< 0 or > 7), `preview()` logs a content error and returns an empty bonus block. This call:
- Does NOT emit `synergy_changed`
- Does NOT modify `cached_bonus_block`
- Returns the hypothetical block for UI comparison only

The Workshop UI diffs hypothetical vs. current and surfaces any threshold crossings (new activations, lost activations). This fulfills Assembly's Deferred Design Obligation #6.

---

### States and Transitions

The Synergy System is a stateless pure computation. It holds one cached result, replaced on each `evaluate()` or `evaluate_silent()` call.

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
- Ironclad 3-piece: `[(ironclad, 3)]` → true when `tag_count[ironclad] ≥ 3`
- VOLT 5-piece: `[(VOLT, 5)]` → true when `tag_count[VOLT] ≥ 5`
- Ironclad-VOLT 3-piece: `[(ironclad, 3), (VOLT, 3)]` → true when both counts ≥ 3

Combined synergies use `SYNERGY_THRESHOLD_TIER1` (= 3) as the per-tag minimum for their 3-piece tier.

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

Active tiers are iterated in synergy-definition registration order. `flatten` preserves tier iteration order and within-tier effect order. `deduplicate` is keep-first: the first occurrence of each effect ID is retained; later duplicates are discarded.

Deduplication on effects matters: if two active tiers both grant `&"volt_shock_on_hit"`, the ID appears only once in the output. This prevents double-triggering in TBC. Note: if a combined synergy's effect list duplicates an effect already granted by a constituent synergy, the combined synergy's effect contribution is silently discarded — content authors must not duplicate effect IDs across constituent and combined synergy tiers.

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
`evaluate()` receives 8 null entries. SYN-F1 counts are all zero. No synergy tier is active. `synergy_bonus_block = { stat_delta: {}, effects: [] }`. Signal emits with the empty block. No crash.

**EC-SYN-02: Maximum tag concentration and simultaneous tier stacking.**
Pure concentration: all 8 parts share the same manufacturer AND element (e.g., 8 Ironclad-VOLT parts). Both 3-piece and 5-piece activate for Ironclad, for VOLT, and for Ironclad-VOLT (6 tiers active). All bonuses stack cumulatively per SYN-F3.

Maximum theoretical simultaneous tiers: a 5+5 distribution between two elements under one manufacturer (e.g., 5 ironclad-VOLT + 3 ironclad-KINETIC, giving ironclad=8, VOLT=5, KINETIC=3) yields ironclad 3-piece, ironclad 5-piece, VOLT 3-piece, VOLT 5-piece, KINETIC 3-piece, ironclad-VOLT 3-piece, ironclad-KINETIC 3-piece = 7 tiers. With ironclad≥5 AND VOLT≥5: ironclad 3-piece, ironclad 5-piece, VOLT 3-piece, VOLT 5-piece, KINETIC 3-piece (if 3+ KINETIC), ironclad-VOLT 3-piece = up to 10 tiers. There is no cap on the number of simultaneously active tiers. Content authors must budget stat_delta values assuming up to 10 tiers could be simultaneously active.

**EC-SYN-03: Wild parts used across multiple synergy lines.**
Wild parts (element tag only, no manufacturer tag) intentionally enable element-focus builds that can be combined with manufacturer synergies. Example: 4 wild VOLT parts (element-only) reach VOLT 3-piece; the remaining 4 slots use non-wild Ironclad parts for Ironclad 3-piece. Both synergy lines activate simultaneously. This is intended design — the flexibility cost is that wild slots contribute no manufacturer counts, so the player cannot accumulate a combined synergy (which requires both element AND manufacturer counts meeting the threshold). A player using all 4 wild VOLT slots cannot reach Ironclad-VOLT 3-piece without additional Ironclad-tagged VOLT parts in their remaining slots.

**EC-SYN-04: Same effect ID granted by multiple active tiers.**
VOLT 3-piece and VOLT 5-piece both include `&"volt_shock_on_hit"`. After SYN-F3 deduplication (keep-first), the effect appears exactly once in `synergy_bonus_block.effects`. TBC triggers the effect at most once per applicable event. If the effect appears twice in the output, the AC for this case fails.

**EC-SYN-05: Effect ID not registered in TBC.**
A content author adds a new effect ID to a synergy tier before it is defined in the TBC GDD. The Synergy System emits the unknown ID in the effects array. TBC is responsible for logging a content error (unknown effect ID) and skipping it without crashing. This is a content error, not a system error.

**EC-SYN-06: stat_delta references a stat not in Assembly's 11-stat schema.**
A content error produces `stat_delta = { "speed": 10 }`. SYN-F3 aggregates it into `synergy_bonus_block`. Consumers call `.get(S, 0)` for each of the 11 known stats and receive 0 for "speed". The unknown key is silently ignored. No crash. This is detectable only by content validation tooling.

**EC-SYN-07: Part with empty synergy_tags array.**
A `SympartData` has `synergy_tags = []` (content error — Part DB requires at least an element tag). The system iterates an empty array and contributes no counts. No crash. The part acts as a synergy-inert slot. This is a Part DB validation failure; the Synergy System is not responsible for detecting it.

**EC-SYN-08: Negative stat_delta in content.**
A content author accidentally authors a penalty synergy: `stat_delta = { armor: -5 }`. SYN-F3 aggregates `armor: -5` into `synergy_bonus_block`. SYN-F4 applies it: `effective_stat[armor] = max(0, Assembly.final_stat[armor] - 5)`. If the penalty exceeds the base stat, the result is clamped to 0, not negative. This is the intended defensive floor — the player's stat cannot be driven below zero by a content error.

**EC-SYN-09: preview() candidate is the currently equipped part.**
No change — hypothetical evaluation returns a block identical to `cached_bonus_block`. No threshold crossings. The Workshop UI shows "no change" for this slot.

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
| **Turn-Based Combat** | `cached_bonus_block` (stat_delta + effects) at battle start via `evaluate_silent()`; applies SYN-F4 for effective stats; resolves passive effect IDs | Not Started | TBC GDD must document its Synergy dependency and define the passive effect ID registry |
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

Combined synergies use `SYNERGY_THRESHOLD_TIER1` as the per-tag minimum (≥ 3 for each constituent tag). This is not a separate knob in MVP — if combined synergies need different thresholds, that becomes a per-synergy-definition data field rather than a global constant.

## Visual/Audio Requirements

This system owns the `synergy_changed` signal. The Workshop UI GDD owns all visual and audio presentation decisions. The table below specifies the event contract this system provides.

| Event | Visual Need | Audio Need | Owner |
|-------|-------------|------------|-------|
| Synergy tier activates (threshold crossed up) | Indicator lights up; synergy bonus animates in | Activation chime matching build "click" fantasy | Workshop UI GDD |
| Synergy tier deactivates (threshold crossed down) | Indicator dims; bonus animates out | Deactivation tone | Workshop UI GDD |
| Synergy preview activates (via preview()) | Greyed-out "would activate" indicator | None (preview only) | Workshop UI GDD |
| `synergy_changed` signal fires | Trigger for all of the above | Trigger for all of the above | Workshop UI (subscribes to signal; must implement own change detection before triggering animations to prevent thrashing on rapid part swaps) |

## UI Requirements

Requirements this system places on downstream UI GDDs:

1. **Build-relevant synergy indicators**: Workshop UI must display each synergy tier relevant to the current build. A tier is build-relevant if the player has at least 1 part with a matching tag. For each build-relevant tier: active tiers show the tier name, icon, and bonus summary; inactive tiers show current vs. required count (e.g., "Ironclad: 2/3 — 1 more for bonus"). Tiers with no matching parts in the current build are hidden (3–8 visible indicators maximum, not all 30 theoretical tiers).
2. **Synergy stat delta display**: Workshop UI must apply SYN-F4 before displaying any stat value — players must never see a base-only stat in the Workshop. `effective_stat[S] = max(0, Assembly.final_stat[S] + synergy_bonus_block.stat_delta.get(S, 0))`.
3. **Swap preview synergy delta**: When previewing a part swap, Workshop UI must call `preview()` and surface synergy threshold changes (new activation, lost activation) as a distinct visual element from the base-stat delta. A synergy activation or loss is not just a number change — it requires presentation that is visually distinguishable from a plain stat delta (e.g., a highlighted indicator change alongside the stat numbers).
4. **Active effects list**: Workshop UI must display active passive effect IDs by name. The Synergy Content data file must include a `display_name` string for each tier (and its effects), so Workshop UI reads human-readable names from the content data rather than raw StringName IDs.
5. **Combat UI**: During battle, Combat UI displays the frozen `cached_bonus_block` bonuses as part of effective stats. No synergy animation occurs during battle (block is frozen at battle start via `evaluate_silent()`).

## Acceptance Criteria

*(Content stat values below are illustrative anchors used to make ACs discriminating — Ironclad 3-piece: armor +8; Ironclad 5-piece: armor +20; VOLT 3-piece: energy_power +6; VOLT 5-piece: energy_power +12, effect `&"volt_test"`; Ironclad-VOLT 3-piece: armor +5, energy_power +4. Real values are authored in Synergy Content data.)*

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
Fixture: Slots 0–3: parts with `synergy_tags = [&"THERMAL"]` only — no manufacturer tag present. Slots 4–7: null.
Call `evaluate(parts)`.
Assert: `tag_count["THERMAL"] == 4`; `tag_count["ironclad"] == 0`; `tag_count["boltwell"] == 0`; `tag_count["scrapjaw"] == 0`. No manufacturer tag appears in the count map.
Pass: THERMAL 3-piece bonus activates (THERMAL=4 ≥ 3); no manufacturer synergy activates. This tests the counting loop — manufacturer tags are absent from `synergy_tags`, so the engine cannot count them.

**AC-SYN-05: Effect ID deduplication**
Fixture: Slots 0–4: VOLT-tagged parts (VOLT=5). VOLT 3-piece: `{ effects: [&"volt_test"] }`. VOLT 5-piece: `{ effects: [&"volt_test"] }` (same ID in both tiers).
Call `evaluate(parts)`.
Pass: `cached_bonus_block.effects.size() == 1` AND `cached_bonus_block.effects[0] == &"volt_test"`.
FAIL: `effects.size() == 2` (deduplication not applied; double-trigger risk in TBC).

**AC-SYN-06: SYN-F4 effective stat computation (self-contained)**
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
Pass: received `active_synergies` contains exactly `["volt_3_piece", "volt_5_piece"]` (in any order — use set equality) — no missing tiers, no spurious IDs.

**AC-SYN-13: preview() returns hypothetical when candidate activates a new synergy**
Fixture: Active build with 2 VOLT-tagged parts in slots 0–1 (VOLT=2; below 3-piece threshold). `cached_bonus_block.stat_delta.is_empty() == true`. VOLT 3-piece content: `{ energy_power: 6 }`. Slot 2 currently holds a non-VOLT part (or is null).
Call `preview(candidate_volt_part, 2, current_parts)` where `candidate_volt_part.synergy_tags = [&"VOLT"]`.
Hypothetical: slots 0–2 VOLT-tagged → VOLT=3 → VOLT 3-piece activates.
Pass: return value `stat_delta["energy_power"] == 6`; `cached_bonus_block.stat_delta.is_empty() == true` (actual cache unchanged); `synergy_changed` NOT emitted.

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-1 | What is the Synergy Content data format? A dedicated `SynergyDatabase.tres`? Part of `PartDatabase.tres`? Separate file loaded at startup? | Technical Director / Lead Programmer | Determines how synergy definitions are authored and loaded |
| OQ-2 | What are the MVP stat bonus values for each synergy tier? | Economy Designer (balance tuning) | No impact on system design — pure content work done during prototype balancing |
| OQ-3 | Which passive effect IDs are feasible to implement for MVP, and what behavior does each define? | Turn-Based Combat GDD | Blocks authoring any effect-bearing synergy content until TBC GDD defines the registry |
| OQ-4 | Does CORE's synergy contribution need to be mechanically distinct from other slots, or does its tag contribution alone fulfill the "CORE identity" deferred obligation from Assembly? | Game Designer | May require revisiting Assembly Deferred Obligation #5 when TBC is designed |
| OQ-5 | What would the Vertical Slice team-wide synergy feature look like? (e.g., 2+ Symbots sharing a tag for a team-level bonus?) | Deferred to Vertical Slice design | No impact on MVP system |
| OQ-6 | Does SA-F2 (Assembly swap delta) return an absolute hypothetical stat or a delta? This must be verified before Workshop UI GDD is authored, to determine whether the UI can safely combine SA-F2 and SYN preview() outputs for a combined effective-stat delta display. | Lead Programmer / Assembly GDD | Blocks Workshop UI GDD authoring if unresolved |
