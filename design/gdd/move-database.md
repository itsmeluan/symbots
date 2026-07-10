# Move Database

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 1 (Engineer, Don't Collect), Pillar 3 (Build Depth Over Content Breadth), Pillar 4 (Synergy Is the Endgame)

## Overview

The Move Database is the authoritative catalog of every move a Symbot can perform in combat. Each part that grants an action — a WEAPON's primary skill, a HEAD's scan or utility, an ARMS active, plus the universal Basic Attack — references a move entry by `active_skill_id`; the Move Database is where that ID resolves into a concrete, executable definition: the move's **behavior class** (`DAMAGE`, `STATUS`, `REPAIR`, `SCAN`, `UTILITY`), its `damage_type` and `element`, its Energy cost, the status it applies (if any), its targeting, and its **power coefficient** — the per-move multiplier that makes a Signature strike hit harder than a Light jab on the same power stat. It is read-only from a gameplay perspective and is the direct sibling of the Part Database: where the Part Database defines what a part *is*, the Move Database defines what a part *does* when its skill fires. It holds no runtime state — turn resolution, resource spending, and the damage math all live in Turn-Based Combat; the Move Database supplies only the static contract each move obeys. Formally, this document **ratifies MOVE-CONTRACT-1** — the provisional move schema Turn-Based Combat authored in its Rule 9 — accepting it in full with one negotiated addition: the per-move power coefficient (§Formulas), which Turn-Based Combat's original "stat-scaled only" constraint deliberately left open for this GDD to decide.

## Player Fantasy

The Move Database has no fantasy the player ever names — they never think "I am reading a move definition." Its fantasy is *borrowed and enabling*, the same relationship the Part Database has to collecting: it is the guarantee that **the move panel is the build speaking**.

When a player equips a Boltwell arc-weapon and its `active_skill_id` resolves into a cyan Volt `DAMAGE` move with a Shock rider, that panel button is the Workshop hypothesis made playable. Every option the player taps in combat — its element, its cost, whether it staggers or repairs or scans, how hard it lands — exists because a part they chose put it there. The Move Database is where *"I built this"* becomes *"I can press this."* A Signature move that hits like a truck and floods the Heat gauge, a cheap Light jab that holds tempo, a repair that buys a turn — these read as **distinct tools with distinct weights** only because this catalog gives each move its own power, cost, and rider. Flatten those into interchangeable numbers and the move panel is a list; give each move a real identity and the panel becomes an instrument.

The player *feels* this fantasy in Turn-Based Combat, which owns the moment-to-moment "build speaking" experience (TBC Player Fantasy, supporting feeling 1). The Move Database's role is upstream and quiet: it is the promise that when the build says something, combat has a concrete, differentiated move to say it with.

## Detailed Design

### Core Rules

**Rule 1 — The Move Schema (MOVE-CONTRACT-1, ratified).** Every move is one entry with these fields. This accepts Turn-Based Combat's Rule 9 schema in full and adds `power_tier` (the negotiated power coefficient):

| Field | Type | Notes |
|-------|------|-------|
| `id` | StringName | Referenced by a part's `active_skill_id` |
| `display_name` | String | Combat UI move-panel label |
| `behavior` | Enum | `DAMAGE`, `STATUS`, `REPAIR`, `SCAN`, `UTILITY` (Rule 2) |
| `power_tier` | Enum | `LIGHT`, `STANDARD`, `HEAVY`, `SIGNATURE` — maps to a damage multiplier and expected cost/heat bands (Rule 3). `null` for non-`DAMAGE` behaviors |
| `damage_type` | Enum/null | `PHYSICAL`/`ENERGY` — from the owning part's `damage_type` in MVP (DF constraint DF1). `null` for non-`DAMAGE` |
| `element` | Enum/null | From the owning part's `element` in MVP; drives type effectiveness and status identity |
| `energy_cost` | int | 0–40, must fall in the `power_tier`'s band (Rule 3) |
| `status_proc` | Dictionary/null | `{ status_id, duration }` — `STATUS` moves apply it guaranteed on hit; `DAMAGE` moves carry riders only via passives, never innately (Rule 5) |
| `targeting` | Enum | `ENEMY`, `SELF` — region sub-targeting within `ENEMY` is the Part-Break System's layer |
| `scan_payload` | Enum/null | `BREAK_REGIONS` for `SCAN` moves (Rule 6); `null` otherwise |
| `vent_amount` | int/null | Heat removed for `UTILITY` Vent (Rule 8); `null` otherwise |

`heat_generation` and `ammo_cost` remain on the **part** (Part DB schema), never the move — ratified unchanged from MOVE-CONTRACT-1.

**Rule 2 — Behavior classes.** A move's `behavior` selects its resolution path; the runtime resolution itself is owned by Turn-Based Combat (this GDD defines the contract each obeys):

- **`DAMAGE`** — deals damage via DF-1 scaled by `power_tier` (Rule 3 / §Formulas MOVE-F1). The only behavior that emits `hit_resolved` (TBC AC-TBC-34).
- **`STATUS`** — applies `status_proc` guaranteed on hit; deals no damage (Rule 5).
- **`REPAIR`** — restores the user's Structure via TBC-F6; `energy_cost > BASE_ENERGY_REGEN` (Rule 7).
- **`SCAN`** — reveals enemy break-region/drop info; no damage, no status (Rule 6).
- **`UTILITY`** — MVP: exactly one move, Vent (Rule 8).

**Rule 3 — Power tiers (the coherence spine).** `power_tier` unifies a `DAMAGE` move's damage multiplier with its expected Energy cost and its part's Heat generation, so "heavier" always means "hits harder, costs more, runs hotter" — one coherent axis, not three loose numbers:

| `power_tier` | Damage `power_mult` | Expected `energy_cost` | Expected part `heat_generation` |
|--------------|--------------------|-----------------------|-------------------------------|
| `LIGHT` | 0.80 | 5–8 | 0–5 |
| `STANDARD` | 1.00 | 12–18 | 8–15 |
| `HEAVY` | 1.20 | 22–30 | 18–28 |
| `SIGNATURE` | 1.40 | 32–40 | 30–40 |
| *Basic Attack* | 0.70 | 0 | 0 |

The Energy/Heat bands are the **same tiers Part DB Formula 5/6 already define** — this table binds them to a damage multiplier. Content validation enforces that a `DAMAGE` move's `energy_cost` falls in its tier's band, and warns when the owning part's `heat_generation` falls outside it (cross-schema, so a warning not a hard fail). `power_mult` is applied post-DF-1 (§Formulas MOVE-F1) — DF-1 itself is untouched.

**Rule 4 — The Basic Attack (built-in template).** The Move Database registers one canonical Basic Attack template: `behavior = DAMAGE`, `power_tier` = Basic Attack (mult 0.70), `energy_cost = 0`, `status_proc = null`, `targeting = ENEMY`. Turn-Based Combat instantiates it at battle start, filling `damage_type` and `element` from the equipped WEAPON (TBC Rule 9). It is always available (cost 0) and is the weakest damage option by design — the free fallback, never the optimal hit.

**Rule 5 — Status moves.** A `STATUS` move applies its `status_proc` `{ status_id, duration }` guaranteed on hit. Status **identity** is fixed by element — Volt→Shock, Thermal→Burn, Kinetic→Stagger (TBC Rule 11) — so `status_id` must match the move's `element`. Status **potency** is never a move field: it scales with the applier's `processing` at application time (TBC-F3/F4/F5). `duration` defaults to 2 (TBC Rule 11); the field exists so specific moves or `SKILL_ENHANCE` unlocks can extend it. `DAMAGE` moves never carry an innate status rider — riders come only from passive effects through TBC's Rule 13 registry, keeping base moves legible.

**Rule 6 — SCAN (delivers Enemy DB ED6).** A `SCAN` move (`scan_payload = BREAK_REGIONS`) consumes the turn, pays its Energy cost and the part's Heat, deals no damage and applies no status, and reveals the enemy's `break_regions` — each region's label and its drop hint (which part it can yield). The revealed info **persists for the rest of the battle**. This is the delivery mechanism for Enemy DB constraint ED6's "drop-hint mechanism" and directly serves Pillar 2: the player scans to learn *what to break*, then plans the harvest. The information payload's data shape is owned jointly with Enemy DB (ED6) and its on-screen display is the Combat UI GDD's; this GDD defines that SCAN *produces* the reveal event.

**Rule 7 — REPAIR.** A `REPAIR` move restores the user's Structure by TBC-F6 (`repair_amount` scales with effective `energy_power`). It **must** author `energy_cost > BASE_ENERGY_REGEN` (≥ 11 at the current 10) — the anti-stall Energy-brake contract ratified in TBC Rule 9 / AC-TBC-38. `targeting = SELF`. Overheal above `max_structure` is discarded; the Energy and Heat costs still apply (TBC EC-TBC-10).

**Rule 8 — UTILITY: Vent (the one MVP utility).** A `UTILITY` Vent move consumes the turn, pays its Energy cost, and reduces the user's `current_heat` by `vent_amount` (floored at 0). It is the *active* complement to the passive Cooling stat — it lets a Thermal or high-power build shed Heat on demand and push Signature moves harder without Overheating. `targeting = SELF`. Vent is the complete MVP `UTILITY` taxonomy; the enum retains headroom for Vertical Slice+ (buffs, energy transfer) but no other `UTILITY` move ships in MVP.

**Rule 9 — Upgrade effects (runtime semantics).** Part DB Rule 10 stores an `upgrade_effects` array on the part; this GDD defines what its two `effect_type` values do:
- **`SKILL_UNLOCK`** — at the specified upgrade tier, adds a new move (by `skill_id`) to that part's contributed move slot. In MVP this is used only by specific boss-grade/prototype parts at tiers +4/+5. (Never on a Core part — Part DB Core exception.)
- **`SKILL_ENHANCE`** — at the specified tier, modifies an existing move's parameters: reduce `energy_cost`, bump `power_tier` one step, extend a `status_proc.duration`, or add a passive rider ID. Each enhancement names the exact parameter and delta.

### States and Transitions

The Move Database is a **static data schema** — move definitions have no runtime state and no state machine, exactly like the Part Database. All mutable combat state (whether a move is affordable this turn, cooldown-equivalents, resource spending) lives in Turn-Based Combat, not here.

Lifecycle note: move definitions are added at content-authoring time. A retired move is never deleted (existing parts may reference it); it is left in the catalog and simply removed from any new part authoring. There is no `deprecated` flag on moves in MVP — the Part that references a move governs whether it is reachable.

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Part Database** | ← referenced by | Parts' `active_skill_id` → move `id`; `damage_type`/`element` sourced from the owning part; `heat_generation`/`ammo_cost` stay on the part; `upgrade_effects` array stored on the part, semantics defined here (Rule 9) |
| **Turn-Based Combat** | → consumed by | MOVE-CONTRACT-1 (Rule 1); TBC resolves every move, owns runtime state, applies `power_mult` post-DF-1, emits `hit_resolved` for `DAMAGE`. **Errata obligation on TBC** (§Formulas): TBC-F5 `final_damage` input range and `hit_resolved` damage range widen to accommodate `power_mult` |
| **Damage Formula** | ← calls | `DAMAGE` moves resolve through DF-1; `power_mult` multiplies DF-1's *output* (DF-1 unchanged) |
| **Enemy Database** | ↔ joint | Enemy `skills` reference Move DB entries; SCAN's `BREAK_REGIONS` payload reads Enemy DB `break_regions`/drop hints (ED6) |
| **Part-Break System** | → provides keyword | Moves whose resolution can break a region flow through TBC's `hit_resolved`; drop-condition keywords (e.g. `arm_broken`) are Part-Break/Drop vocabulary, matched by `id` |
| **Passive Database** | ↔ sibling | `DAMAGE`-move status riders are passives (TBC Rule 13 registry), not move fields; the two schemas are authored together |
| **Enemy AI** | ← reads | Enemy move entries (behavior, cost, tier) inform AI move selection; enemies ignore Energy/Heat gating (TBC Rule 8) |
| **Combat UI** | → displays | `display_name`, tier, cost, greyed/affordable state, and the SCAN reveal readout |

## Formulas

This GDD owns exactly **one** formula — **MOVE-F1**, the per-move power multiply. All other combat math a move triggers is owned elsewhere and only referenced here: move damage by **DF-1** (Damage Formula), status potency by **TBC-F3/F4/F5**, repair by **TBC-F6**. SCAN produces no numeric output; Vent is a flat subtraction (a tuning value, not a scaling formula).

### MOVE-F1 — Move Power Multiply

```
move_damage = max(DAMAGE_FLOOR, floor(df1_output × power_mult + EPSILON))
```

Applied **after** DF-1 returns its integer, multiplying the output. DF-1 itself is unchanged — its registered range `[1, 225]` stands. `power_mult` comes from the move's `power_tier` (Detailed Design Rule 3).

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| DF-1 output | `df1_output` | int | 1–225 | The floored DF-1 integer for this hit, pre-power |
| Power multiplier | `power_mult` | float | {0.70, 0.80, 1.00, 1.20, 1.40} | From `power_tier`; Basic Attack 0.70 |
| Damage floor | `DAMAGE_FLOOR` | int | 1 | Shared with DF-1; a hit never zeroes |
| Epsilon | `EPSILON` | float | 0.0001 | IEEE 754 nudge — **load-bearing** (see below) |
| Output | `move_damage` | int | 1–315 | Attacker-side damage pre-Stagger; carried by `hit_resolved` |

**Output range per tier** (using DF-1's realistic ceiling 164 and absolute ceiling 225):

| Tier | `power_mult` | Realistic max (df1=164) | Absolute max (df1=225) |
|------|-------------|-------------------------|------------------------|
| Basic Attack | 0.70 | 114 | 157 |
| LIGHT | 0.80 | 131 | 180 |
| STANDARD | 1.00 | 164 | 225 |
| HEAVY | 1.20 | 196 | 270 |
| SIGNATURE | 1.40 | 229 | **315** |

Minimum: `df1_output=1, power_mult=0.70` → `floor(0.7001)=0 → max(1,0)=1` (DAMAGE_FLOOR holds).

**Epsilon status (python3-scanned 2026-07-10 — LOAD-BEARING):** an exhaustive scan of all 1,125 inputs (`df1_output ∈ [1,225]` × the 5 multipliers) against exact rational arithmetic found the `+ 0.0001` nudge is **load-bearing, not defensive**: **10 inputs produce the wrong result without it**. IEEE 754 evaluates products such as `165 × 1.40 = 230.99999999999997` and `90 × 0.70 = 62.99999999999999` just below the exact integer, so a bare `floor()` returns 230 and 62 — off by one. The epsilon corrects all 10 (full list: `0.70×{90,170,180}`, `1.40×{45,85,90,165,170,175,180}`). With the epsilon: 0 errors and 0 overcorrections across all 1,125 inputs. **The nudge is mandatory; do not remove it.** Re-run the scan if any multiplier is retuned. *(This joins EDB-1 and Part DB F2b as a load-bearing epsilon; an initial analytical review mistakenly called it defensive — the empirical scan is authoritative.)*

**Worked example (discriminating — floor ≠ round ≠ ceil):** `df1_output = 164`, Basic Attack `power_mult = 0.70` → `floor(164 × 0.70 + 0.0001) = floor(114.8001) = 114` — round()/ceil() give **115**.

**Worked example (load-bearing — where the epsilon earns its keep):** `df1_output = 165`, SIGNATURE `power_mult = 1.40` → the exact product is 231, but IEEE 754 gives `230.99999999999997`; `floor(230.9999… + 0.0001) = 231` (correct). A bare `floor()` without the nudge returns **230** — wrong.

### Damage Pipeline Composition (order of operations)

The full attacker-side pipeline is three sequential floored multiplies:

```
Step 1 — DF-1:      df1_output   = max(1, floor((A²/(A+D)) × T × crit + EPSILON))              range [1, 225]
Step 2 — MOVE-F1:   move_damage  = max(1, floor(df1_output × power_mult + EPSILON))             range [1, 315]
Step 3 — TBC-F5:    hit_resolved = max(1, floor(move_damage × (1 − stagger_pct/100) + EPSILON)) range [1, 315]
```

Step 3 (Stagger) runs only when the attacker is Staggered; otherwise `hit_resolved = move_damage`. `hit_resolved` is the value Part-Break and Structure accounting consume. Verified composition: Signature/no-Stagger vs BOSS (A=150, D=30, T=1.5) → DF-1 187 → ×1.40 → **261**; Signature/max-Stagger realistic (A=150, D=55, T=1.5, proc 110) → 164 → 229 → **167**.

### Errata this creates on Turn-Based Combat (Approved) — must be propagated

Inserting MOVE-F1 between DF-1 and TBC-F5 means TBC-F5's `final_damage` input is now MOVE-F1's output, not DF-1's. **DF-1 is untouched** (the reason we chose post-multiply). Required edits, to be applied via `/propagate-design-change`:

| Target | Change |
|--------|--------|
| TBC GDD — TBC-F5 variable table | `final_damage` source "DF-1 output, 1–225" → "MOVE-F1 output, 1–315" |
| TBC GDD — TBC-F5 output & `hit_resolved` range | `[1, 225]` → `[1, 315]` (realistic 229) |
| Registry — TBC-F5 entry | `final_damage` range + `output_range` `[1,225]` → `[1,315]`; add `move-database.md` to `referenced_by` |
| Registry — new MOVE-F1 entry | source `move-database.md`, referenced_by `turn-based-combat.md`, output `[1,315]` |
| Registry — DF-1 entry | **no change** — `[1,225]` stands |

### Balance note — SIGNATURE TTK (modifies TBC's ratified TTK envelope)

A max-synergy build (A=150) firing a SIGNATURE move vs the BOSS reference (D=30, structure 594, T=1.5) deals **261/hit → 3-turn kill**, versus STANDARD's 4-turn (TBC's ratified baseline) and Basic's 5-turn. This compresses TBC's accepted 4-turn endgame ceiling to 3. **Ruling: acceptable, Heat-gated.** A SIGNATURE move generates 30–40 Heat/use (Part DB); three consecutive uses accrue 90–120 against a 100 cap, forcing Overheat at turn 2–3 unless the build is cooling-specialized. The 3-turn kill is therefore the intended Pillar-4 ceiling, achievable only by a max-synergy *and* cooling-heavy build — strictly harder to reach than the STANDARD 4-turn. No multiplier change needed; monitored in the Tuning Knobs section.

### Referenced formulas (owned elsewhere — not redefined here)

- **DF-1** (Damage Formula) — move damage; MOVE-F1 multiplies its output.
- **TBC-F3 / F4 / F5** (Turn-Based Combat) — Burn / Shock / Stagger potency; scale with applier `processing`, never a move field.
- **TBC-F6** (Turn-Based Combat) — REPAIR amount; scales with effective `energy_power`.
- **Vent**: `current_heat = max(0, current_heat − vent_amount)` — flat subtraction; `vent_amount` is a per-move tuning value (Tuning Knobs).

## Edge Cases

**EC-MDB-01 — `active_skill_id` references a missing move.** A part's `active_skill_id` points to an `id` with no Move DB entry. Assembly already exposes such slots as `null` (EC-SA-04) and TBC renders them as "—" (EC-TBC-11). The Move DB lookup contract: resolving a nonexistent `id` returns `null`, never throws. *Verified by AC-MDB-01.*

**EC-MDB-02 — `DAMAGE` move's `energy_cost` outside its `power_tier` band.** A SIGNATURE move authored at `energy_cost = 10` (below the 32–40 band): content validation flags it naming the move `id`; runtime still resolves using the authored cost and the tier's multiplier (no crash — validation is an authoring gate, not a runtime guard). *Verified by AC-MDB-02.*

**EC-MDB-03 — `STATUS` move's `status_id` doesn't match its `element`.** A Volt move authored with `status_proc.status_id = burn`: validation errors (Rule 5 — identity is element-bound). Runtime applies the authored `status_id` as written and does not silently override it — the mismatch is caught at authoring, not patched at runtime. *Verified by AC-MDB-03.*

**EC-MDB-04 — `DAMAGE` move with `null` `power_tier`.** `power_tier` is required for `DAMAGE`. If absent: validation errors; runtime defaults to `STANDARD` (`power_mult = 1.00`) — a safe, non-amplifying fallback, never a crash. *Verified by AC-MDB-04.*

**EC-MDB-05 — Non-`DAMAGE` move carries a stray `power_tier` or `damage_type`.** A REPAIR move authored with `power_tier = HEAVY`: runtime ignores it (both fields are read only for `DAMAGE` behavior); validation warns. No damage multiplier is ever applied to a non-`DAMAGE` move. *Verified by AC-MDB-05.*

**EC-MDB-06 — `SCAN` on an enemy with no break regions.** The enemy's `break_regions` is empty: SCAN resolves normally — turn consumed, Energy/Heat paid — and reveals an empty region set (Combat UI shows "no breakable regions"). No crash, no rejection. *Verified by AC-MDB-06.*

**EC-MDB-07 — Vent at `current_heat = 0`.** `current_heat = max(0, 0 − vent_amount) = 0`: the move resolves, the turn is consumed, and the Energy cost still applies. Legal and wasteful, not rejected — same principle as repairing at full Structure (TBC EC-TBC-10). *Verified by AC-MDB-07.*

**EC-MDB-08 — `REPAIR` move authored with `energy_cost ≤ BASE_ENERGY_REGEN`.** Violates the anti-stall Energy-brake (Rule 7): content validation **fails (blocking)** naming the move `id`. This is the Move DB side of TBC AC-TBC-38. *Verified by AC-MDB-08.*

**EC-MDB-09 — `SKILL_ENHANCE` bumps `power_tier` above `SIGNATURE`.** A tier bump applied to an already-SIGNATURE move: clamped to SIGNATURE (no wraparound, no sixth tier); validation warns that the bump is a no-op. *Verified by AC-MDB-09.*

**EC-MDB-10 — `SKILL_UNLOCK` on a Core part.** Forbidden by the Part DB Core exception (Rule 8 / Part DB AC-01 — Cores never gain an active skill). Move DB restates the rule: a Core part's `upgrade_effects` must not contain a `SKILL_UNLOCK` entry; validation errors. *Verified by AC-MDB-10.*

## Dependencies

### Upstream (this system reads from / composes with these)

| System | What Move DB reads | Status | Hard/Soft |
|--------|-------------------|--------|-----------|
| **Part Database** | Sources a move's `damage_type`, `element`, and heat context from the owning part; `active_skill_id` is the linkage; `upgrade_effects` array stored on the part (semantics defined here, Rule 9) | Approved | Hard |
| **Damage Formula** | MOVE-F1 multiplies **DF-1's output** — the formula composes with DF-1's `[1,225]` range but does not call DF-1 directly (TBC orchestrates: DF-1 → MOVE-F1 → TBC-F5) | Approved | Hard |
| **Turn-Based Combat** | Status potency (TBC-F3/F4/F5), repair (TBC-F6), `BASE_ENERGY_REGEN`, the Rule 13 passive registry, and the runtime resolution of every move behavior | Approved | Hard |

### Downstream (these systems read from Move DB)

| System | What it reads | Status | Obligation on that GDD |
|--------|---------------|--------|------------------------|
| **Turn-Based Combat** | MOVE-CONTRACT-1 (Rule 1) incl. the new `power_tier`; resolves every move | Approved | **Errata (see below)**: apply MOVE-F1 to the damage pipeline; widen TBC-F5 `final_damage` + `hit_resolved` to `[1,315]`; mark OQ-TBC-1 (ratified), OQ-TBC-3 (SCAN=reveal break regions), OQ-TBC-4 (UTILITY=Vent) resolved |
| **Enemy Database** | Enemy `skills` reference Move DB entries; SCAN's `BREAK_REGIONS` payload reads `break_regions`/drop hints (ED6) | Approved | Acknowledge SCAN as the ED6 drop-hint delivery mechanism; enemy skill entries conform to MOVE-CONTRACT-1 |
| **Part-Break System** | Break-relevant moves flow through TBC's `hit_resolved`; drop-condition keywords matched by move `id` | Not Started | Match its break/drop keyword vocabulary to move `id`s; consume `hit_resolved` (range now `[1,315]`) |
| **Passive Database** | `DAMAGE`-move status riders are passives via TBC Rule 13, not move fields | Not Started | Author status riders as passives; must list Move DB as a sibling dependency |
| **Enemy AI System** | Enemy move entries (behavior, cost, tier) for move selection | Not Started | Respect that enemies ignore Energy/Heat gating (TBC Rule 8) |
| **Combat UI** | `display_name`, tier, cost, affordable/greyed state, the SCAN reveal readout | Not Started | Decide where/how the SCAN break-region reveal renders (with Enemy DB ED6) |
| **Drop System** | SCAN's revealed drop hints correspond to actual drop odds | Not Started | Keep SCAN hint text consistent with real `drop_conditions` (Part DB Rule 9) |

### Errata obligations this GDD creates on Approved documents

| Target | Change | Source decision |
|--------|--------|-----------------|
| **Turn-Based Combat** (TBC-F5, pipeline, OQs) | Insert MOVE-F1 between DF-1 and TBC-F5; TBC-F5 `final_damage` "DF-1 output 1–225" → "MOVE-F1 output 1–315"; `hit_resolved` range `[1,315]`; resolve OQ-TBC-1/3/4 | §Formulas MOVE-F1; SCAN & UTILITY decisions |
| **Registry** | New `MOVE-F1` formula entry (`[1,315]`); TBC-F5 range `[1,225]`→`[1,315]` + add `move-database.md` to `referenced_by`; register `power_tier` multipliers; add `move-database.md` to DF-1's `referenced_by`; **DF-1 range unchanged** | §Formulas |
| **Enemy Database** (ED6) | Note SCAN (Move DB Rule 6) as the concrete delivery mechanism for ED6's drop-hint requirement | SCAN decision |

### Bidirectionality

- **Part Database** already references the Move Database (Rule 10: upgrade skill effects "specified in the Move Database GDD"; Interactions: "Active skills reference valid Move Database entries") ✓
- **Turn-Based Combat** already lists Move Database as an upstream dependency (provisional, MOVE-CONTRACT-1) — this GDD ratifies it, converting "provisional" to "ratified" ✓
- **Enemy Database, Damage Formula** — reference is one-directional today; each must list Move Database when its next revision lands (Enemy DB for skill entries + ED6; the registry link for DF-1↔MOVE-F1 composition).
- **Part-Break, Passive DB, Enemy AI, Combat UI, Drop System** (all Not Started) must list Move DB when authored.

## Tuning Knobs

| Knob | Value | Safe Range | What Changing It Does |
|------|-------|------------|----------------------|
| `power_mult[BASIC]` | 0.70 | 0.60–0.80 | Basic Attack strength. Below 0.60 the free fallback is too weak to ever be a real option; above 0.80 a zero-cost attack competes with costed moves and undermines the Energy economy. |
| `power_mult[LIGHT]` | 0.80 | 0.70–0.90 | Cheap-tempo damage. Must stay below STANDARD or the Light tier stops being a tempo trade-off. |
| `power_mult[STANDARD]` | 1.00 | **fixed anchor** | The calibration reference — all other tiers are relative to it, and DF-1 was balanced against 1.00. **Do not tune**: shifting it re-baselines every damage number in the game. Change the other tiers instead. |
| `power_mult[HEAVY]` | 1.20 | 1.10–1.30 | The mid-premium hit. Should sit clearly between STANDARD and SIGNATURE. |
| `power_mult[SIGNATURE]` | 1.40 | 1.30–1.50 | **Cross-document + TTK-sensitive.** At 1.50, boss TTK compresses toward 2–3 turns; at 1.30, SIGNATURE barely beats HEAVY (dead tier). **Changing it invalidates the MOVE-F1 output range `[1,315]`, the TBC-F5 input range, and the SIGNATURE TTK ruling — re-run the python3 epsilon scan and update the TBC errata.** |
| `vent_amount` (per Vent move) | 20–40 | 15–45 | Heat removed by a Vent use. Below 15 it barely offsets a Signature's heat (not worth a turn); above 45 it trivializes Overheat management and kills the resource-brinkmanship tension (a Vent should roughly offset ~1 Signature use, not neutralize Heat entirely). Coupled to the Heat cap (100) and Signature `heat_generation` (30–40). |
| `SCAN` reveal persistence | whole battle | battle / N turns | Currently the reveal lasts the full battle. A future knob could time-limit it (re-scan needed), adding tension; MVP keeps it persistent for legibility. |

**Owned elsewhere — referenced, not duplicated:** Energy-cost tiers and Heat-generation tiers (Part DB Formula 5/6); `STATUS_DURATION`, `BASE_ENERGY_REGEN`, `DAMAGE_FLOOR`, `REPAIR_COEFF`/`REPAIR_BASE`/`REPAIR_MIN` (TBC / Damage Formula); status-potency coefficients `BURN_COEFF`/`SHOCK_COEFF`/`STAGGER_COEFF` (TBC-F3/F4/F5). A move's Energy cost and its part's Heat are governed by those source tables — this GDD only binds them to a `power_tier` for coherence (Rule 3).

**Knob interaction warnings:** (1) `power_mult[SIGNATURE]` is a **cross-document constant** — coupled to the MOVE-F1 range, TBC-F5's range, the DF-1 pipeline errata, and the TTK envelope; treat any change as a design decision requiring the epsilon re-scan and TBC re-derivation, not a tuning pass. (2) `vent_amount` and the Heat system (`heat_generation` tiers, Overheat, Cooling) jointly control Overheat brinkmanship — never raise `vent_amount` without checking that Signature builds still face a real Overheat risk (Pillar: resource brinkmanship). (3) The `power_mult` tiers must stay strictly ordered (`BASIC < LIGHT < STANDARD < HEAVY < SIGNATURE`) or the tier taxonomy loses meaning.

## Visual/Audio Requirements

The Move Database is a data schema — it authors no assets and emits no signals of its own. All combat visual and audio for moves is **owned by the Turn-Based Combat GDD's Visual/Audio section** (hit VFX per element/type V3-3, status-apply V3-5, Overheat V3-8, per-element audio V4) and ratified by the Art Bible. Two Move-DB-specific notes:

- **Power-tier weight cue** (direction, not spec): a `SIGNATURE` hit should read visually and sonically *heavier* than a `LIGHT` jab — the tier the player picked should be legible in the impact. This is a note for the Art Bible / TBC V3-3, not a schema field.
- **SCAN reveal** (Rule 6): the break-region/drop-hint reveal needs a distinct, legible display treatment — owned by the **Combat UI GDD** (where it renders) jointly with Enemy DB ED6.

📌 **Asset Spec** — no assets originate here; when the Art Bible is approved, moves' VFX are specced under `/asset-spec system:turn-based-combat`, not this system.

## UI Requirements

Obligations this schema places on the **Combat UI GDD** (Not Started) — layout and interaction belong there:

1. **Move panel** displays each move's `display_name`, a **`power_tier` indicator** (so a player reads LIGHT vs SIGNATURE at a glance — the differentiation this GDD adds is only felt if the UI surfaces it), and Energy cost, with affordable/greyed state per TBC.
2. **SCAN reveal readout** — the revealed `break_regions` + drop hints display, persistent for the battle (with Enemy DB ED6).
3. **Vent feedback** — a clear Heat-drop readout when a Vent move resolves.

Most of this is already captured in TBC UI Requirements 1–10; restated here for the two Move-DB-specific additions (the `power_tier` indicator and the SCAN reveal).

> **📌 UX Flag — Move Database**: the `power_tier` indicator and SCAN reveal are new player-facing display needs. Fold them into the combat-screen `/ux-design` pass (they belong on `design/ux/combat.md`, not this GDD).

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
