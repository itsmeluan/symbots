# Drop System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 1/3 (parts as the persistent economy)

## Overview

The Drop System is the payoff engine of the harvest loop: the moment a won fight becomes concrete loot. On **victory only** (never on defeat or flee), it walks the defeated enemy's loot pool and, for each part, evaluates **Part DB Formula 3** — the per-rarity base rate scaled by the multipliers of whichever **drop conditions** the player fired that fight (breaking the right region, using the right damage type, finishing under the right conditions) — then rolls each result against a deterministic, seedable RNG. Winning rolls produce **part instances** written to the player's inventory. This is where "I need the Ignis Core from the Forge Boss, and I need to break its arm to get it" stops being a plan and becomes a reward.

The Drop System owns four things no other system does: the **canonical drop-condition vocabulary** (the condition keys that Part-Break emits and that part definitions reference — Part DB Rule 9 delegates this list here), the **two pity systems** that bound bad-luck tails so a skilled hunter is never soft-locked (Prototype gradient pity per Part DB DB2, and a deterministic Boss-grade acquisition floor per Part DB EC-16), the **pool-roll model** that decides how a multi-part loot pool is sampled (resolving Enemy DB OQ-5), and the **Scrap conversion** that gives duplicate parts player-controlled value (the HOLISM-01 economy). It does **not** define which parts an enemy carries (Enemy DB loot pools), does **not** determine whether a break succeeds (Part-Break System), and does **not** store or upgrade the parts it awards (Inventory / Workshop) — it is strictly the resolution layer between "battle won" and "loot in hand."

## Player Fantasy

The Drop System serves the fantasy of **the deliberate hunter** — the player who doesn't *farm* so much as *execute*. The core feeling is **earned reward**: when the Servo Arm finally drops, it lands because you broke the arm region, finished with the right damage type, and kept your win streak clean — not because the dice happened to smile. Every drop condition you fire is a visible tilt of the odds in your favor, so a successful hunt feels like a plan paying off, and a failed one feels like a lesson ("I should have broken the arm before finishing it"), never like a slot machine that owes you nothing.

The peak beat is the **targeted pull**: you entered this fight for one specific part, you did everything right, and the loot screen confirms it. The Drop System's job is to make that moment feel *causal* — the reward is legible back to your choices. Around that peak sit two quieter guarantees that protect the fantasy from its own randomness. First, **persistence always converges**: the pity systems mean a skilled hunter who keeps executing the correct play is mathematically guaranteed to get there — bad luck can delay the Boss-grade Core, never wall it off. Second, **no drop is garbage**: because duplicates are useful (equip the same part across Symbots) or convert to Scrap you choose to bank, even a "wrong" pull is fuel, so the loot screen never trains you to sigh and skip it.

This fantasy is delivered downstream — the player *feels* it on the victory/loot screen (Combat UI) and in the Workshop when they slot the part they earned. The Drop System's role is to make sure that when the reward lands, it reads as *the hunt worked*, not *the RNG blinked*.

> *Lean-mode note: `creative-director` was not consulted on this section (review mode = lean). Review manually before production.*

## Detailed Design

### Core Rules

**Rule 1 — Resolution trigger (victory only).** The Drop System subscribes to TBC's `battle_ended(outcome, enemy_id, fired_break_events: Set)` (Rule 12). It resolves drops **only** on `VICTORY`. `DEFEAT` and `FLED` award nothing — no parts, no Scrap (TBC discards fired break events on those outcomes).

**Rule 2 — Independent per-part rolls (Enemy DB OQ-5 resolved).** The defeated enemy's **loot pool** (owned by Enemy DB) lists candidate part IDs. For each part in the pool, the Drop System evaluates Formula 3 and rolls it as an **independent Bernoulli trial**. A single fight can yield 0, 1, or several parts. Pool size never dilutes an individual part's rate. Parts with `drop_enabled = false` (Part DB EC-04) are excluded before rolling.

**Rule 3 — Condition assembly.** Before rolling, the Drop System builds the fight's **fired-condition set** from two sources: (a) `fired_break_events` in the victory payload (Part-Break events, e.g. `arm_broken`); (b) battle-outcome facts (e.g. `defeated_by_thermal`, `zero_defeats`, `targeting_active`). For each part, the entries in its `drop_conditions` array whose key is in the fired set contribute their multiplier.

**Rule 4 — Effective rate (evaluates Part DB Formula 3).** Per rolled part: `effective_drop_rate = clamp(base_drop_rate[rarity] × Π matching-condition multipliers, 0, 1)`. Base rates from Part DB config: Common 0.70, Rare 0.25, Boss-grade 0.001, Prototype 0.05. (Full formula + worked examples in Formulas.)

**Rule 5 — Canonical drop-condition vocabulary (owned here per Part DB Rule 9).** The Drop System defines the closed set of condition keys. **These keys must match Part-Break's emitted event vocabulary exactly** (provisional Part-Break contract — Part-Break GDD Not Started). MVP categories:
- **Break events** (from Part-Break): `<region>_broken` (e.g. `arm_broken`, `head_broken`, `core_broken`), `all_boss_parts_broken`.
- **Finish damage type:** `defeated_by_physical`, `defeated_by_energy`; element variants `defeated_by_thermal` / `_volt` / `_kinetic`.
- **Style/state:** `targeting_active`, `zero_defeats` (no player Symbot downed), `no_repairs_used`, `flawless` (no player Structure lost).

An unknown condition key in a part's `drop_conditions` is **logged as a content error and skipped**, never a crash (mirrors TBC EC-TBC-08 / Part DB null-tolerance).

**Rule 6 — Prototype gradient pity (discharges Part DB DB2).** A per-Prototype-ID counter tracks consecutive **optimal-condition attempts** (all of that part's `drop_conditions` fired) that failed to drop it. After **N** such attempts, the next optimal attempt is a **guaranteed** drop. Counter increments only on a qualifying (optimal-but-no-drop) attempt, resets to 0 on any drop of that part. (Exact N + partial-attempt handling in Formulas.)

**Rule 7 — Boss-grade deterministic floor (discharges Part DB EC-16).** A per-Boss-grade-ID counter tracks consecutive **qualifying breaks** (the required break fired, the part was eligible) that failed the drop roll. After **M** such breaks, the next qualifying break **guarantees** the Boss-grade drop. This bounds the *drop-RNG* tail only; it does **not** address repeated break *failure* — that soft-lock path is Part-Break's DB3 obligation. (Exact M in Formulas.)

**Rule 8 — Drop output is a part instance.** Each successful roll instantiates a **new part instance** (HOLISM-01: parts are instances) of the part definition at initial state (`upgrade_tier = 0`) and hands it to the Inventory System. Multiple successful rolls of the same definition in one fight produce multiple instances — all kept; the player scraps later by choice. The Drop System emits instances; it does not store them.

**Rule 9 — Scrap conversion (discharges Part DB DB5).** The Drop System owns the **Scrap yield per rarity** (the source side of the scrap sink). Scrapping is **player-initiated** (an Inventory/Workshop action), never automatic. The consuming sink is **material-gated part upgrading** (Part Upgrade / Workshop, MVP). (Yield values in Tuning Knobs.)

**Rule 10 — Deterministic seeded RNG.** All rolls draw from an **injected, seeded `RandomNumberGenerator`**. Parts are rolled in a **defined order** (part ID ascending) so that a given `(seed, enemy, fired conditions, pity state)` reproduces exactly — required for testable ACs. Pity counters are read/updated within the same deterministic pass.

**Rule 11 — Designs are Alpha (reserved, not rolled in MVP).** The pool contains only parts in MVP. A `Design` drop type (rare blueprint → Alpha Blueprint Crafting fabrication) is reserved in the schema but never rolled in MVP content.

### States and Transitions

The Drop System has **no runtime state machine** — resolution is a single synchronous pass triggered by `battle_ended(VICTORY, …)`. It **does** own **persistent state**: the per-part **pity counters** (Prototype attempts, Boss-grade qualifying-breaks), which persist across battles and sessions (serialized by Save/Load).

| Phase (within one resolution) | Action |
|---|---|
| 1. Assemble | Build fired-condition set from `fired_break_events` + outcome facts (Rule 3) |
| 2. Roll loop | For each `drop_enabled` pool part (ID-ascending): eval Formula 3, roll seeded RNG (Rule 2/4) |
| 3. Pity checks | Apply Prototype (Rule 6) and Boss-grade (Rule 7) guarantees; a guarantee forces the drop |
| 4. Emit | Instantiate each dropped part → hand to Inventory (Rule 8) |
| 5. Update | Increment/reset pity counters; persist (Save/Load) |
| 6. Report | Emit the resolved drop list for the loot screen (Combat UI) |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Turn-Based Combat** | ← consumes | `battle_ended(VICTORY, enemy_id, fired_break_events: Set)` (Rule 12) is the sole trigger |
| **Enemy Database** | ← reads | The enemy's **loot pool** (candidate part IDs) — resolves Enemy DB OQ-5 via Rule 2 |
| **Part Database** | ← reads | Formula 3 + per-rarity base rates; each part's `drop_conditions`, `rarity`, `drop_enabled`; part-instance schema (Rule 8) |
| **Part-Break System** *(Not Started)* | ↔ provisional | Break events → fired conditions (Rule 3). **Provisional contract:** Part-Break emits exactly the Rule 5 break-event keys and owns `P(break fires)` + break-failure pity (its DB3), separate from our drop-RNG pity (Rule 7) |
| **Inventory System** *(Not Started)* | → emits | Receives new part instances (Rule 8); stores Scrap currency; hosts the player-initiated scrap action (Rule 9) |
| **Part Upgrade / Workshop** *(Not Started)* | → feeds | Scrap is consumed by material-gated upgrading (the sink; Rule 9) |
| **Save/Load** *(Not Started)* | ↔ persists | Pity counters (Rule 6/7) serialized across sessions |
| **Combat UI** *(Not Started)* | → reports | The resolved drop list for the victory/loot screen (Phase 6) |

## Formulas

The Drop System owns three formulas: the drop roll (DS-1) and the two pity counters (DS-2, DS-3). It **evaluates** Part DB Formula 3 (Effective Drop Rate) but does not own it. Scrap yields and upgrade costs are per-rarity constants, defined in Tuning Knobs.

### DS-1 — Effective Drop Roll (per part)

For each `drop_enabled` part `p` in the loot pool (rolled in **ID-ascending order** for reproducibility):

```
drops(p) = pity_guaranteed(p) OR ( rng.randf() < effective_drop_rate(p) )
effective_drop_rate(p) = clamp( base_drop_rate[rarity(p)] × Π(multiplier for each matching condition), 0, 1 )   # Part DB Formula 3
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Effective rate | `effective_drop_rate(p)` | float | 0.0–1.0 | Part DB Formula 3 output for part `p` |
| RNG draw | `rng.randf()` | float | [0.0, 1.0) | Seeded, injected `RandomNumberGenerator` (Rule 10) |
| Pity override | `pity_guaranteed(p)` | bool | true/false | DS-2 (Prototype) or DS-3 (Boss-grade) forced drop |

**Output:** boolean per part. **Comparison is strict `<`**: `rate = 0.0` never drops (never occurs — base is always > 0); `rate = 1.0` *always* drops (since `randf() < 1.0` is always true — a clamp-to-1.0 or pity guarantee is deterministic).

**Worked example:** Rare Servo Arm, base 0.25; `arm_broken` (×1.5) + `targeting_active` (×1.3) fired → `clamp(0.25 × 1.5 × 1.3, 0, 1) = 0.4875`. Seeded draw `randf() = 0.41 < 0.4875` → **drops**. A draw of `0.49` → no drop.

### DS-2 — Prototype Gradient Pity (PGP-1) — discharges Part DB DB2

Per-Prototype-ID counter of consecutive **optimal** attempts (all of that part's `drop_conditions` fired) that failed to drop:

```
On resolution of an OPTIMAL attempt for prototype p:
  if pity_counter[p] >= N_PROTO_PITY:
      drop = guaranteed (skip roll);  pity_counter[p] = 0          # checked BEFORE the roll
  else:
      roll DS-1;  if drop: pity_counter[p] = 0  else: pity_counter[p] += 1
On a NON-optimal attempt (not all conditions fired): pity_counter[p] unchanged (no credit — anti-exploit; rewards mastery, not persistence).
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Counter | `pity_counter[p]` | int | 0–`N_PROTO_PITY` | Consecutive failed optimal attempts; per-Prototype-ID; persisted in save |
| Threshold | `N_PROTO_PITY` | int const | **25** (safe 15–25) | Guarantee fires on the (N+1)th optimal attempt in the worst case |

**Hidden from the player** — no pity-counter UI (surprise-rescue design). Integer-only; no rounding, no epsilon. **Worked example:** counter at 24, optimal attempt → `24 >= 25` false → roll, fails → counter 25. Next optimal attempt → `25 >= 25` true → **guaranteed drop**, counter → 0. (Natural odds of reaching 25 consecutive optimal failures at the ~16.9% optimal rate: `0.831²⁵ ≈ 0.9%`.)

### DS-3 — Boss-grade Deterministic Floor (BGDF-1) — discharges Part DB EC-16

Per-Boss-grade-ID counter of consecutive **qualifying breaks** (the required break fired, part eligible) that failed the drop roll:

```
On resolution of a QUALIFYING-BREAK battle for boss-grade part p:
  if break_pity_counter[p] >= M_BOSS_PITY:
      drop = guaranteed (skip roll);  break_pity_counter[p] = 0
  else:
      roll DS-1;  if drop: break_pity_counter[p] = 0  else: break_pity_counter[p] += 1
Break did NOT fire this battle: break_pity_counter[p] unchanged (break-failure is Part-Break's DB3, not this counter).
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Counter | `break_pity_counter[p]` | int | 0–`M_BOSS_PITY` | Consecutive qualifying breaks that failed the drop roll; per-Boss-grade-ID; persisted |
| Threshold | `M_BOSS_PITY` | int const | **8** (safe 5–8) | Guarantee fires on the (M+1)th qualifying break in the worst case |

**Hidden from the player.** **Worked example:** counter at 7, qualifying break, drop roll (~0.5) fails → counter 8. Next qualifying break → `8 >= 8` true → **guaranteed drop**, counter → 0. (Natural odds of reaching 8 consecutive failures at 0.5: `0.5⁸ ≈ 0.4%`.)

**Cross-system constants introduced here:** `N_PROTO_PITY = 25`, `M_BOSS_PITY = 8` (flagged for the entity registry).

## Edge Cases

**EC-DS-01 — Victory with no conditions fired.** *If the player wins having fired zero drop conditions*: every part rolls at `base_drop_rate × 1.0` (no multipliers). Commons/Rares still drop at base; Boss-grade sits at ~0.001 (functionally zero — you didn't break it). No crash. *Verified by AC-DS-05.*

**EC-DS-02 — Empty or fully-disabled loot pool.** *If the enemy's pool is empty or every part is `drop_enabled = false`*: zero drops emitted; the loot report is an empty list; no crash. *Verified by AC-DS-06.*

**EC-DS-03 — Unknown condition key in `drop_conditions`.** *If a part lists a condition key not in the Rule 5 vocabulary*: that entry is logged as a content error and skipped (its multiplier is not applied); all valid conditions on the part still evaluate. No crash. *Verified by AC-DS-07.*

**EC-DS-04 — Effective rate exceeds 1.0 before clamp.** *If `base × Π multipliers > 1.0`* (e.g. Common 0.70 × two favorable conditions): `clamp(...,0,1) = 1.0` → guaranteed drop (`randf() < 1.0` always true). Correct per Part DB Formula 3. *Verified by AC-DS-03.*

**EC-DS-05 — Boss-grade won without the qualifying break.** *If a Boss-grade part's required break did not fire but the player won*: rate = ~0.001 (functionally zero), and its DS-3 `break_pity_counter` is **not** incremented (only *qualifying* breaks count). No progress toward Boss-grade pity is made — by design; repeated break *failure* is Part-Break's DB3 soft-lock domain, not this counter's. *Verified by AC-DS-09.*

**EC-DS-06 — Pity guarantee and RNG determinism.** *If a pity guarantee fires (DS-2/DS-3)*: the drop is awarded **without drawing from the RNG** — the roll is skipped, so the seeded RNG stream does **not** advance for that part. This keeps `(seed, pool, conditions, pity state)` fully reproducible. *Verified by AC-DS-10.*

**EC-DS-07 — Defeat or flee after firing break events.** *If the player breaks regions but then loses or flees*: TBC discards `fired_break_events`; the Drop System never triggers (VICTORY-only, Rule 1). No drops, and **no pity counter changes** (no resolution occurred). *Verified by AC-DS-02.*

**EC-DS-08 — Duplicate part ID in a loot pool.** *If a pool lists the same part ID more than once* (content authoring choice): each entry is an independent trial, so up to that many instances can drop in one fight. Not an error — instances are the model (HOLISM-01). *Verified by AC-DS-08.*

**EC-DS-09 — Inventory storage of a guaranteed drop.** *If a successful/guaranteed roll produces an instance*: the Drop System **always emits** it and resets the relevant pity counter, independent of storage. MVP parts inventory is unbounded (no cap), so acceptance is guaranteed; any future cap/overflow policy is the Inventory GDD's concern. *No Drop System AC — the emit contract is verified by AC-DS-01; storage is owned by the Not-Started Inventory System.*

## Dependencies

### Upstream (Drop System reads from / is triggered by)

| System | What Drop System reads | Status | Hard/Soft |
|--------|------------------------|--------|-----------|
| **Turn-Based Combat** | `battle_ended(VICTORY, enemy_id, fired_break_events: Set)` — the sole resolution trigger (Rule 1) | Approved | Hard |
| **Part Database** | Formula 3 + per-rarity base rates; each part's `drop_conditions`, `rarity`, `drop_enabled`; the part-instance schema (Rule 8) | Approved | Hard |
| **Enemy Database** | The enemy's loot pool (candidate part IDs) — Rule 2 | Approved | Hard |
| **Part-Break System** | Break-event keys → fired conditions (Rule 3); `P(break fires)` for the full Boss-grade acquisition rate | **Not Started** | Hard (provisional contract — Rule 5/7) |

### Downstream (these read from Drop System)

| System | What it reads | Status | Obligation on that GDD |
|--------|---------------|--------|------------------------|
| **Inventory System** | New part instances (Rule 8); Scrap currency; hosts the player-initiated scrap action (Rule 9) | Not Started | Must accept emitted instances (unbounded in MVP), store Scrap, and own the scrap-tap UX (incl. batch-scrap) |
| **Part Upgrade / Workshop** | Scrap is consumed by material-gated upgrading (the sink, Rule 9) | Not Started | Must own the final upgrade-cost curve (proposed values in Tuning Knobs) |
| **Save/Load** | `pity_counter` and `break_pity_counter` per-part (DS-2/DS-3) persisted across sessions | Not Started | Must serialize both pity-counter maps |
| **Combat UI** | The resolved drop list for the victory/loot screen (Phase 6) | Not Started | Must render drops; must **not** surface pity counters (hidden by design) |

### Bidirectionality

- **Turn-Based Combat** already references Drop System (Rule 12 emits `fired_break_events` "for the Drop System") ✓
- **Part Database** already references Drop System (Downstream Dependents table; DB2/DB5; Formula 3 "evaluated by the Drop System") ✓
- **Enemy Database** already references Drop System (OQ-4/OQ-5 deferred here; loot pools) ✓ — **this GDD resolves both** (see obligations below)
- **Part-Break System** (Not Started) will reference Drop System when authored (provisional contract, Rule 5/7)

### Upstream obligations this GDD discharges

- **Part DB DB2** (Prototype pity) → **DS-2**, `N_PROTO_PITY = 25`.
- **Part DB EC-16** (Boss-grade deterministic floor) → **DS-3**, `M_BOSS_PITY = 8`.
- **Part DB DB5** (scrap sink) → Rule 9 + Scrap yields (Tuning Knobs); sink = material-gated upgrading.
- **Enemy DB OQ-5** (pool-size dilution) → **resolved: independent per-part rolls** (Rule 2). *Errata obligation: Enemy DB OQ-5 should be marked RESOLVED.*
- **Enemy DB OQ-4** (Boss-grade acquisition + bad-luck protection) → **resolved**: ×500 qualifying break (~0.5) + DS-3 deterministic floor. *Errata obligation: Enemy DB OQ-4 should be marked RESOLVED.*

## Tuning Knobs

| Knob | Value | Safe Range | What changing it does |
|------|-------|-----------|-----------------------|
| `N_PROTO_PITY` | 25 | 15–25 | Prototype pity threshold (DS-2). Lower → pity fires more often (becomes an expected path below ~12); higher → rarer safety net. At 25, ~0.9% of hunters ever hit it. |
| `M_BOSS_PITY` | 8 | 5–8 | Boss-grade pity threshold (DS-3). Below 4, pity gets visible (>12% hit it) and erodes the "~2 attempts" intent; at 8, ~0.4% hit it. |
| Scrap yield — Common | 5 | 3–8 | Primary faucet. Below 3 fails DB5 (feels ignorable); above 8 trends toward trivially funding all upgrades. **Highest-leverage faucet knob.** |
| Scrap yield — Rare | 20 | 15–30 | Secondary faucet (4× Common). Matters when the player scraps Rare duplicates rather than running two copies. |
| Scrap yield — Boss-grade | 60 | 40–100 | Emotional weight (12× Common). Duplicate Boss-grades are infrequent; the number just needs to feel significant. |
| Scrap yield — Prototype | 35 | 25–50 | 7× Common, **deliberately below Boss-grade** — prevents a perverse "scrap the second Prototype instead of running it on another Symbot" incentive. |
| Pool Common cap (content rule) | ≤2 WILD, ≤3 BOSS | — | Caps Common slots per loot pool so independent rolls don't flood. Authoring constraint honored by **Enemy DB** loot-pool authoring. Removing it re-introduces the ~2.8-drops/fight Common flood. |

**Sink values (proposed here, owned by Part Upgrade / Workshop GDD):** upgrade cost per tier — `0→1: 10`, `1→2: 20`, `2→3: 40`, `3→4: 80`, `4→5: 130` (Common cap +3 = 70 total; Rare+ cap +5 = 280 total). Accelerating steps: fast first hit hooks the upgrade habit; the +4/+5 wall (costs more than +0→+3 combined) makes maxing a deliberate choice. Over the ~10hr MVP this yields **mild scarcity** (~730–1,095 Scrap earned vs ~1,260–1,960 to fully upgrade priority parts) — you can't max everything, so upgrade choices stay meaningful.

**Referenced (owned elsewhere, not Drop System knobs):** the per-rarity `base_drop_rate` (Common 0.70 / Rare 0.25 / Boss-grade 0.001 / Prototype 0.05) and condition multipliers are **Part DB** config — tune them there, not here. `BOSS_GRADE_BREAK_GUARANTEE = 0.5` (×500 break multiplier) is **Enemy DB**.

## Visual/Audio Requirements

The Drop System authors no assets; all drop/loot feedback is owned by Combat UI and Inventory/Workshop UI and ratified by the Art Bible. Direction for those owners:

- **Rarity-escalated drop reveal:** the loot screen escalates feedback by rarity — Common quiet, Rare a notable cue, Boss-grade/Prototype a distinct celebratory flourish (audio sting + VFX) so the "targeted pull" peak beat lands. Direction for **Combat UI / Art Bible**.
- **Pity is invisible:** a pity-guaranteed drop (DS-2/DS-3) must look and sound **identical** to a natural drop — no tell — preserving the surprise-rescue design.
- **Scrap:** a satisfying but non-celebratory confirmation (routine sink action); batch-scrap gets one summary flourish. Direction for **Inventory / Workshop UI**.

📌 **Asset Spec** — no assets originate here; drop/loot proc VFX are specced under Combat UI when the Art Bible is approved.

## UI Requirements

Obligations this system places on Not-Started UIs:

1. **Victory/loot screen (Combat UI):** list each dropped instance by `display_name` + rarity with rarity-escalated emphasis; touch-friendly at 44pt targets; **must not display pity counters** (hidden by design, DS-2/DS-3).
2. **Scrap action (Inventory/Workshop UI):** player-initiated, per-part **and** batch ("scrap all duplicates of type"), with a confirmation showing Scrap gained (Rule 9).

> 📌 **UX Flag — Drop System**: the loot screen and scrap action are player-facing needs. Fold them into the combat-screen and inventory `/ux-design` passes (`design/ux/combat.md`, `design/ux/inventory.md`), not this GDD.

## Acceptance Criteria

All BLOCKING ACs are Logic-type automated unit tests in `tests/unit/drop_system/`. RNG-based ACs inject a stub `RandomNumberGenerator` returning a stated draw sequence. Float assertions use `abs(x − expected) < 1e-9` (the listed products are exact in IEEE 754 double; epsilon is defensive against future multiplier retuning).

### Roll & Formula

**AC-DS-03** (BLOCKING): rate > 1.0 pre-clamp guarantees the drop. GIVEN Common `scrap_bolt` (0.70) with `arm_broken`(×1.5)+`targeting_active`(×1.3) fired (product 1.365), WHEN DS-1 evaluated with any draw in [0,1), THEN `effective_drop_rate = 1.0` and drops. FAIL: rate returned unclamped; drop false for a draw < 1.0. *Verifies EC-DS-04.*

**AC-DS-04** (BLOCKING): strict-`<` boundary. GIVEN Rare `servo_arm`, rate 0.25, WHEN draw = 0.25 exactly, THEN drops = **false**; WHEN draw = `0.25 − ulp` THEN drops = **true**. FAIL: draw==rate drops (indicates `<=`). *The canonical `<` vs `<=` discriminator.*

**AC-DS-05** (BLOCKING): no conditions fired → base rates. GIVEN pool [Common 0.70, Rare 0.25, Boss-grade 0.001], empty fired set, draws (ID-asc) 0.65/0.20/0.0005, THEN all three drop at base rate (no multipliers). SECOND: Boss-grade draw 0.002 → no drop (0.002 ≥ 0.001). FAIL: conditions applied on empty set; Boss-grade treated as rate 0.0 (impossible instead of ~0.001). *Verifies EC-DS-01.*

**AC-DS-07** (BLOCKING): unknown condition key logged + skipped. GIVEN Rare `servo_arm` with conditions `arm_broken`(×1.5), `UNKNOWN_KEY_XYZ`(×2.0), `targeting_active`(×1.3); `arm_broken`+`targeting_active` fired; draw 0.41, THEN rate = clamp(0.25×1.5×1.3)=0.4875, drops, exactly one content error names `UNKNOWN_KEY_XYZ`, no crash. SECOND: draw 0.70 → no drop (discriminates: applying ×2.0 would give 0.975 and falsely drop). FAIL: exception; unknown multiplier applied; no log. *Verifies EC-DS-03.*

**AC-DS-12** (BLOCKING): independent per-part rolls, no pool dilution. GIVEN a 5-part pool, no conditions, draws all below base rates, THEN Rare rate = 0.25 (not ÷5), all 5 drop, RNG called exactly 5×. SECOND: 10-part pool → Rare rate still 0.25 (not 0.025). FAIL: rate shrinks with pool size; pool normalization applied. *Verifies R2.*

**AC-DS-22** (BLOCKING): condition matching is exact-string. GIVEN part with condition `arm_broken`; fired set has `ARM_BROKEN` + `arm_break` (not `arm_broken`), THEN no multiplier applied, rate = 0.25, no log error. FAIL: case-insensitive/substring match applies ×1.5. *Verifies R5 exact match.*

**AC-DS-23** (BLOCKING): multipliers stack multiplicatively; unfired conditions excluded. GIVEN Prototype `delta_core` (0.05), three ×1.5 conditions, 2 of 3 fired, THEN rate = clamp(0.05×1.5×1.5)=0.1125 — NOT 0.05 (none), NOT 0.16875 (all three), NOT 0.225 (additive). FAIL: any of those wrong values. *Verifies R3.*

### Pity — Prototype (DS-2)

**AC-DS-13** (BLOCKING): trigger at counter=25, not 24. SCENARIO A: counter 24, optimal attempt, draw 0.50 (>0.16875) → `24≥25` false → roll fails → counter 25. SCENARIO B: counter 25, optimal attempt → `25≥25` true → guaranteed drop, RNG **not** called, counter → 0, instance emitted. FAIL: fires at 24 (off-by-one); B calls RNG or doesn't reset. *Verifies DB2/DS-2 boundary.*

**AC-DS-14** (BLOCKING): non-optimal attempt gets no credit. GIVEN `delta_core` counter 10, only 2 of 3 conditions fired, draw 0.50 fails, THEN counter stays **10**. FAIL: counter → 11 (crediting a non-optimal miss). *Anti-exploit.*

**AC-DS-15** (BLOCKING): counter resets on any drop. GIVEN counter 22, optimal attempt, draw 0.10 (<0.16875) drops via normal roll (pity not reached), THEN counter → 0. FAIL: stays 22; becomes 23. *Reset must fire even when pity threshold not reached.*

### Pity — Boss-grade (DS-3)

**AC-DS-16** (BLOCKING): trigger at counter=8, not 7. SCENARIO A: counter 7, qualifying break `core_broken`, draw 0.60 (>0.5) → `7≥8` false → fails → counter 8. SCENARIO B: counter 8, qualifying break → guaranteed, RNG not called, counter → 0, emitted. FAIL: fires at 7; B calls RNG or no reset. *Verifies EC-16/DS-3 boundary.*

**AC-DS-17** (BLOCKING): break-not-fired leaves counter unchanged. GIVEN `forge_core` counter 5, empty fired set, WHEN VICTORY resolved, THEN roll at 0.001, counter stays **5**. FAIL: → 6 or → 0 (treating any victory as qualifying). *Complements AC-DS-09 from the DS-3 update path.*

**AC-DS-09** (BLOCKING): Boss-grade won without qualifying break → DS-3 counter NOT incremented. GIVEN `forge_core` counter 3, empty fired set, draw 0.5, THEN rate 0.001, counter stays **3**, no drop. FAIL: → 4; reset to 0; drop true. *Verifies EC-DS-05.*

**AC-DS-24** (BLOCKING): pity counters are per-part-ID, not global. GIVEN two Boss-grade parts, `forge_core` counter 8 + `volt_cannon` counter 2, both qualifying-break, THEN `forge_core` guaranteed→reset 0, `volt_cannon` rolls and its counter moves independently. FAIL: shared counter; resetting one affects the other.

### Trigger, Emit, Determinism

**AC-DS-01** (BLOCKING): emit contract. GIVEN a pity-guaranteed `forge_core`, WHEN VICTORY resolved, THEN exactly one `PartInstance{part_id, upgrade_tier=0}` emitted and `break_pity_counter` reset to 0. FAIL: no emit; tier≠0; not reset; 2+ emits. *Verifies EC-DS-09.*

**AC-DS-02** (BLOCKING): defeat/flee → no drops, no pity change. GIVEN counters `proto_arms`=12, `forge_core`=5, non-empty fired set, WHEN DEFEAT (then FLED) resolved, THEN zero emits, both counters unchanged, RNG not called. FAIL: any emit; counter changes. *Verifies EC-DS-07.*

**AC-DS-06** (BLOCKING): empty/disabled pool → zero drops, no crash. A empty pool → []; B all `drop_enabled=false` → []; C mixed → only enabled part rolled (disabled not rolled, stream not advanced for it). FAIL: exception; disabled emitted; disabled consumes a draw. *Verifies EC-DS-02.*

**AC-DS-08** (BLOCKING): duplicate part ID → independent trials. GIVEN pool listing `servo_arm` twice, draws 0.20/0.20, THEN RNG called twice, two instances emitted. SECOND: draws 0.20/0.30 → one instance. FAIL: deduplicated to one roll; single-instance cap. *Verifies EC-DS-08.*

**AC-DS-10** (BLOCKING): pity guarantee skips the RNG draw. GIVEN pool [`forge_core` (pity-guaranteed), `servo_arm` (0.25)], RNG stub with one draw 0.20, WHEN resolved, THEN `forge_core` drops via guarantee (no draw consumed), `servo_arm` consumes the 0.20 and drops, total RNG calls = **1**. FAIL: 2 draws consumed; `servo_arm` reads the wrong draw. *Verifies EC-DS-06 — the stream-position test.*

**AC-DS-11** (BLOCKING): victory-only gate. GIVEN `scrap_bolt`, RNG always 0.65 (<0.70). A VICTORY → one emit; B DEFEAT → zero emits, RNG not called; C FLED → zero emits, RNG not called. FAIL: non-VICTORY drops; VICTORY zero despite 0.65<0.70. *Complements AC-DS-02 (tests the gate itself).*

**AC-DS-18** (BLOCKING): deterministic reproducibility. GIVEN two DropSystem instances seeded identically with identical pity state, WHEN both resolve the same VICTORY, THEN identical drop lists + identical post-resolution pity state. FAIL: divergence (e.g. a global RNG singleton shared across instances). *Verifies R10.*

**AC-DS-20** (BLOCKING): instances emitted at `upgrade_tier = 0` for all rarities. GIVEN one part of each rarity, draws guaranteeing all drop, THEN 4 instances, each tier 0. FAIL: any tier≠0 (e.g. rarity used as tier proxy). *Verifies R8.*

**AC-DS-21** (BLOCKING): parts rolled in ID-ascending order. GIVEN pool with IDs sorting alpha<beta<gamma (inserted non-alphabetically), RNG call-recording stub, THEN calls issued alpha→beta→gamma. FAIL: insertion-order iteration (GDScript Dictionary default). *Verifies R10 ordering.*

**AC-DS-19** (BLOCKING): Scrap yield per rarity. `get_scrap_yield`: Common 5, Rare 20, Boss-grade 60, Prototype 35. FAIL: any value wrong; **Prototype ≥ Boss-grade** (35<60 is a design invariant). *Verifies R9 yield constants (source side; the player-initiated action is Inventory's, Advisory).*

### Deferred (gated on Not-Started systems)

- **AD-1 — Outcome-fact assembly** (R3, OQ-DS-2): once the TBC↔Drop interface for `defeated_by_thermal`/`zero_defeats`/`no_repairs_used`/`flawless` exists, verify outcome facts join the fired-condition set. *Unblocks when OQ-DS-2 resolves.*
- **AD-2 — Pity persistence** (R6/R7): integration test — serialize counters, reload, verify identical. *Unblocks when Save/Load is designed.*
- **AD-3 — Loot-screen report** (Phase 6): *unblocks when Combat UI is designed.*
- **AD-4 — Player scrap action** (R9): *unblocks when Inventory is designed.*
- **AD-5 — Part-Break contract** (R5/R7, OQ-DS-1): validate break-event keys match exactly. *Unblocks when Part-Break is designed.*

### EC↔AC Cross-Check

EC-DS-01→AC-DS-05 · EC-DS-02→AC-DS-06 · EC-DS-03→AC-DS-07 · EC-DS-04→AC-DS-03 · EC-DS-05→AC-DS-09 · EC-DS-06→AC-DS-10 · EC-DS-07→AC-DS-02 · EC-DS-08→AC-DS-08 · EC-DS-09→AC-DS-01. **All 9 ECs covered.**

### Summary

**24 ACs: 21 BLOCKING unit + 5 deferred** (AD-1–5). Coverage: R1 (02,11), R2 (08,12), R3 (23), Formula 3/R4 (03,05,07,23), R5 (07,22), R6/DS-2 (13,14,15,24), R7/DS-3 (09,16,17,24), R8 (01,20), R9 (19), R10 (10,18,21), DS-1 boundary (04).

**Known coverage gaps (deferred, not blocking this GDD):** outcome-fact provenance (OQ-DS-2), pity save/load persistence (Save/Load Not Started), pity-counter upper-bound assertion (low priority — add to AC-DS-13A).

**GDScript testability constraints:** inject the RNG (no module-level singleton); assert floats with `<1e-9`; explicitly sort pool IDs ascending before iterating (Dictionary iterates in insertion order).

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-DS-1 | **Part-Break contract binding.** The Rule 5 break-event vocabulary and `P(break fires)` must be ratified by the Part-Break GDD; condition keys must match this catalog exactly. | Part-Break GDD | Blocks full Boss-grade acquisition-rate math (Part DB DB3); Rule 5/7 are provisional until then |
| OQ-DS-2 | **"Outcome fact" conditions provenance.** The non-break conditions (`defeated_by_thermal`, `zero_defeats`, `no_repairs_used`, `flawless`) need a computed source — TBC (or a battle-stats tracker) must expose them to the Drop System. The interface is undefined. | TBC ↔ Drop interface | Rule 3 condition assembly is incomplete for non-break conditions until this is defined |
| OQ-DS-3 | **Designs (Alpha).** The `Design` drop type + fabrication economy (currency + materials) is reserved (Rule 11) but unspecified. | Blueprint Crafting GDD (Alpha) | None in MVP — reserved only |
| OQ-DS-4 | **Inventory cap / batch-scrap UX.** Parts inventory is unbounded in MVP (EC-DS-09); a future cap/overflow policy and the scrap UX are Inventory's. | Inventory GDD | Low in MVP — unbounded is acceptable at 2-boss scope |
