# Drop System

> **Status**: Approved
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-11 (APPROVED — re-review punch-list applied: DS-2 c=0 pseudocode completed with base-roll + reset; new AC-DS-30 DS-3 natural-drop reset; partial-play attempts-to-guarantee off-by-one corrected (⌈N×C/c⌉+1); pity-calibration label fixed to floor-compliant 0.16875→0.99%; economy band floor corrected to ~1,556 + game-thirds reconciled to ~1,565 conservative; Rule 6 anti-exploit wording scoped to part-conditions. 29 BLOCKING unit ACs + 1 gated. Prior: NEEDS REVISION addressed 2026-07-11 — DS-2 partial-credit pity model, Boss-grade 0% absorption, OQ-DS-6 victory-only.)
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 1/3 (parts as the persistent economy)

## Overview

The Drop System is the payoff engine of the harvest loop: the moment a won fight becomes concrete loot. On **victory only** (never on defeat or flee), it walks the defeated enemy's loot pool and, for each part, evaluates **Part DB Formula 3** — the per-rarity base rate scaled by the multipliers of whichever **drop conditions** the player fired that fight (breaking the right region, using the right damage type, finishing under the right conditions) — then rolls each result against a deterministic, seedable RNG. Winning rolls produce **part instances** written to the player's inventory. This is where "I need the Ignis Core from the Forge Boss, and I need to break its arm to get it" stops being a plan and becomes a reward.

The Drop System owns four things no other system does: the **canonical drop-condition vocabulary** (the condition keys that Part-Break emits and that part definitions reference — Part DB Rule 9 delegates this list here), the **two pity systems** that bound bad-luck tails so a skilled hunter is never soft-locked (Prototype gradient pity per Part DB DB2, and a deterministic Boss-grade acquisition floor per Part DB EC-16), the **pool-roll model** that decides how a multi-part loot pool is sampled (resolving Enemy DB OQ-5), and the **Scrap conversion** that gives duplicate parts player-controlled value (the HOLISM-01 economy). It does **not** define which parts an enemy carries (Enemy DB loot pools), does **not** determine whether a break succeeds (Part-Break System), and does **not** store or upgrade the parts it awards (Inventory / Workshop) — it is strictly the resolution layer between "battle won" and "loot in hand."

## Player Fantasy

The Drop System serves the fantasy of **the deliberate hunter** — the player who doesn't *farm* so much as *execute*. The core feeling is **earned reward**: when the Servo Arm finally drops, it lands because you broke the arm region, finished with the right damage type, and kept your win streak clean — not because the dice happened to smile. Every drop condition you fire is a visible tilt of the odds in your favor, so a successful hunt feels like a plan paying off, and a failed one feels like a lesson ("I should have broken the arm before finishing it"), never like a slot machine that owes you nothing.

The peak beat is the **targeted pull**: you entered this fight for one specific part, you did everything right, and the loot screen confirms it. The Drop System's job is to make that moment feel *causal* — the reward is legible back to your choices. Around that peak sit two quieter guarantees that protect the fantasy from its own randomness. First, **persistence always converges**: the pity systems mean a skilled hunter who keeps executing the correct play is mathematically guaranteed to get there — bad luck can delay the Boss-grade Core, never wall it off. Second, **no drop is garbage**: because duplicates are useful (equip the same part across Symbots) or convert to Scrap you choose to bank, even a "wrong" pull is fuel, so the loot screen never trains you to sigh and skip it.

This fantasy is delivered downstream — the player *feels* it on the victory/loot screen (Combat UI) and in the Workshop when they slot the part they earned. The Drop System's role is to make sure that when the reward lands, it reads as *the hunt worked*, not *the RNG blinked*.

> *Reviewed by `creative-director` 2026-07-10. Player Fantasy aligns with Pillar 2 (Harvest Goal) and the deliberate-hunter construct. Full legibility obligation added to UI Requirements (see §UI Requirements) to wire the "visible tilt" promise to a downstream system.*

## Detailed Design

### Core Rules

**Rule 1 — Resolution trigger (victory only).** The Drop System subscribes to TBC's `battle_ended(outcome, enemy_id, fired_break_events: Set)` (Rule 12). It resolves drops **only** on `VICTORY`. `DEFEAT` and `FLED` award nothing — no parts, no Scrap, no pity progress (TBC discards fired break events on those outcomes). **Design decision (OQ-DS-6, accepted 2026-07-11):** victory-only is deliberate and final — the harvest is the reward for *winning*, and firing a break on a fight you lose earns nothing. Partial drop/pity credit on defeat was considered and rejected (it blurs the win/loss line and complicates Part-Break); any resulting break-avoidance in dangerous fights is treated as a combat risk-reward tuning question, not a drop-credit change.

**Rule 2 — Independent per-part rolls over unique IDs (Enemy DB OQ-5 resolved).** The defeated enemy's **loot pool** (owned by Enemy DB) lists candidate part IDs. The Drop System iterates the pool's **unique** part IDs — a duplicate ID contributes **exactly one** roll (dedupe; aligns with Approved Enemy DB EC-ED-08, which dedupes duplicate pool entries with an authoring warning). For each unique part, the Drop System evaluates Formula 3 and rolls it as an **independent Bernoulli trial**. A single fight can yield 0, 1, or several distinct parts. **Pool size never dilutes an individual part's rate** — each part rolls at its own effective rate regardless of how many other parts share the pool (there is no `÷ pool_size` normalization). Parts with `drop_enabled = false` (Part DB EC-04) are excluded before rolling.

**Rule 3 — Condition assembly.** Before rolling, the Drop System builds the fight's **fired-condition set** from two sources: (a) `fired_break_events` in the victory payload (Part-Break events, e.g. `arm_broken`); (b) battle-outcome facts (e.g. `defeated_by_thermal`, `zero_defeats`, `targeting_active`). For each part, the entries in its `drop_conditions` array whose key is in the fired set contribute their multiplier.

**Rule 4 — Effective rate (evaluates Part DB Formula 3).** Per rolled part: `effective_drop_rate = clamp(base_drop_rate[rarity] × Π matching-condition multipliers, 0, 1)`. Base rates from Part DB config: Common 0.70, Rare 0.25, Boss-grade 0.001, Prototype 0.05. (Full formula + worked examples in Formulas.)

> **Note — Boss-grade persistence floor:** The 0.001 base rate is a **deliberate persistence floor**, not a zero gate. A patient player who never fires the qualifying break can still acquire Boss-grade parts over hundreds of fights (~39% cumulative at 500 no-break fights). The qualifying break improves odds by ×500 and earns DS-3 pity progress — mastery is strongly rewarded, but not hard-required.

**Rule 5 — Canonical drop-condition vocabulary (owned here per Part DB Rule 9).** The Drop System defines the closed set of condition keys. **These keys must match Part-Break's emitted event vocabulary exactly** (**ratified contract — Part-Break Approved 2026-07-11**; Part-Break writes `<region>_broken` / `all_boss_parts_broken` into TBC's `fired_break_events` set, and those keys are exactly this list — the former "provisional, GDD Not Started" caveat is discharged). MVP categories:
- **Break events** (from Part-Break): `<region>_broken` (e.g. `arm_broken`, `head_broken`, `core_broken`), `all_boss_parts_broken`.
- **Finish damage type:** `defeated_by_physical`, `defeated_by_energy`; element variants `defeated_by_thermal` / `_volt` / `_kinetic`.
- **Style/state:** `targeting_active`, `zero_defeats` (no player Symbot downed), `no_repairs_used`, `flawless` (no player Structure lost).

An unknown condition key in a part's `drop_conditions` is **logged as a content error and skipped**, never a crash (mirrors TBC EC-TBC-08 / Part DB null-tolerance).

**Rule 5a — `MULTIPLIER_FLOOR` (owned here; discharges Enemy DB ED3-OQ7).** A drop condition only earns its place if firing it *perceptibly* tilts the odds. The Drop System defines **`MULTIPLIER_FLOOR = 1.5`** — the minimum condition multiplier that counts as a real harvest incentive. Content authoring rule for any `drop_conditions` entry:
- multiplier `≥ MULTIPLIER_FLOOR` (≥1.5) → valid incentive;
- multiplier in the open interval `(1.0, 1.5)` → **content warning** ("sub-threshold incentive — raise to ≥ `MULTIPLIER_FLOOR` or remove"): it satisfies Enemy DB's syntactic `loot_connected` check but delivers a barely-perceptible tilt, so Pillar 2's "visible tilt" promise is only nominally met;
- multiplier `≤ 1.0` → **content error** (a no-op or negative condition is meaningless on a drop condition; remove it).

This is the functional teeth Enemy DB ED3-OQ7 asked for: `loot_connected` verifies a break event *is referenced*; `MULTIPLIER_FLOOR` verifies the reference *matters*. **Boss-grade parts carry a separate, far higher floor** — Part DB AC-11 already mandates ≥ ×500 on at least one break condition (to lift the 0.001 persistence base to an effective ≥ 0.5); `MULTIPLIER_FLOOR` is the general floor for Common/Rare/Prototype conditions, not a replacement for the Boss-grade ×500 rule.

**Rule 6 — Prototype gradient pity (discharges Part DB DB2).** A per-Prototype-ID **credit counter** accumulates progress toward a guaranteed drop, earning credit **proportional to how many of that part's `drop_conditions` fired** on each failed attempt. An attempt is **qualifying** if at least one of the part's conditions fired; a qualifying-but-failed attempt adds `c` credit points (where `c` = conditions fired that attempt), and the counter resets to 0 on any drop. When the counter reaches the part's threshold (`N_PROTO_PITY × C`, where `C` = the part's total condition count), the next qualifying attempt is a **guaranteed** drop. **Fully-optimal play (all conditions fired every attempt) guarantees the drop by the `(N_PROTO_PITY + 1)`th optimal attempt worst case** — credit reaches the threshold after `N_PROTO_PITY` failed attempts, and the *next* qualifying attempt is the guarantee — unchanged by this credit model; partial play (some conditions fired) still converges, just more slowly (e.g. 2-of-3 conditions → guaranteed by the 39th attempt). A **non-qualifying** attempt (none of *this part's* conditions fired) earns no credit — anti-exploit: a victory that fires none of the part's own conditions banks nothing (the enemy need not be the part's host; what matters is whether the part's conditions fired). (Exact model + calibration in Formulas.)

**Rule 7 — Boss-grade deterministic floor (discharges Part DB EC-16).** A per-Boss-grade-ID counter tracks consecutive **qualifying breaks** (the required break fired, the part was eligible) that failed the drop roll. After **M** such breaks, the next qualifying break **guarantees** the Boss-grade drop. This bounds the *drop-RNG* tail only. **There is no break-*failure* tail to bound: Part-Break is deterministic (Approved 2026-07-11) — a region breaks the instant its `break_hp` pool depletes (PB-F4), there is no `P(break fires)` probability and no break-failure soft-lock** (Part-Break DB3 dissolved; DAMAGE_FLOOR guarantees each hit makes progress). DS-3's counter therefore tracks only *qualifying breaks that failed the drop roll* — the break itself never fails. (Exact M in Formulas.)

**Rule 8 — Drop output is a part instance.** Each successful roll instantiates a **new part instance** (HOLISM-01: parts are instances) of the part definition at initial state (`upgrade_tier = 0`) and hands it to the Inventory System. Multiple successful rolls of the same definition in one fight produce multiple instances — all kept; the player scraps later by choice. The Drop System emits instances; it does not store them.

**Rule 9 — Scrap conversion (discharges Part DB DB5).** The Drop System owns the **Scrap yield per rarity** (the source side of the scrap sink). Scrapping is **player-initiated** (an Inventory/Workshop action), never automatic. The consuming sink is **material-gated part upgrading** (Part Upgrade / Workshop, MVP). (Yield values in Tuning Knobs.)

**Rule 10 — Deterministic seeded RNG.** All rolls draw from an **injected, seeded `RandomNumberGenerator`**. Parts are rolled in a **defined order** (part ID ascending) so that a given `(seed, enemy, fired conditions, pity state)` reproduces exactly — required for testable ACs. Pity counters are read/updated within the same deterministic pass.

**Rule 11 — Designs are Alpha (reserved, not rolled in MVP).** The pool contains only parts in MVP. A `Design` drop type (rare blueprint → Alpha Blueprint Crafting fabrication) is reserved in the schema but never rolled in MVP content.

**Rule 12 — Consumable drop channel + Salvage Beacon (Consumable Database erratum, 2026-07-12).** Consumables (Consumable DB) drop as a **level/rarity-scaled output class that is a *separate channel* from the part loot pool** — a consumable roll is not one of the per-part Bernoulli trials of Rule 2, does not draw from the enemy's `loot_pool`, and is not affected by `drop_conditions` or the pity systems (DS-2/DS-3 are part-only). This keeps the consumable faucet independent of the part-harvest math (a fight's part drops and its consumable drops are decided separately).

- **(a) Beacon injection — fully specified (Part A).** On `VICTORY`, if the battle context's `beacon_used_this_battle == true` (Consumable Rule 5 / CD-4), the Drop System multiplies **each part's** `effective_drop_rate` by `beacon_multiplier` (**2.0**) *inside* the existing Rule 4 product, before the `[0, 1]` clamp: `effective_drop_rate = clamp(base_rate × Π(condition_multipliers) × beacon_multiplier, 0, 1)`. It then sets `beacon_drop_multiplier_applied = true` (the observable AC-CD-12/AC-CD-21 assert against). The Beacon applies **only on VICTORY** — on `FLED`/`DEFEAT` the Beacon is already spent with no effect (Rule 1 victory-only; intended tension per Consumable Rule 5). The Beacon multiplies **part** drop rates, not the consumable channel — it never boosts consumable drops (no self-farming loop within one channel).
- **(b) Beacon × pity ordering (discharges Consumable OQ-CD-3).** The pity guarantee is checked **pre-roll** (States Phase 2a). A pity-*guaranteed* part ignores the Beacon (already 100% — the Beacon changes nothing). For a *non-guaranteed* part, the Beacon-boosted rate is used for the roll and the part's pity counter advances/​resets **on the post-Beacon outcome** exactly as an unboosted roll would (the Beacon changes the odds, not the pity bookkeeping).
- **(c) Consumable channel frequencies — DEFERRED to OQ-DS-7 (Part B).** The channel *structure* is defined here (separate roll, level/rarity-scaled, victory-only, not Beacon-boosted); the **actual per-rarity consumable drop rates and the enemy level/rarity scaling are NOT yet set** — they are a balance decision that feeds the post-MVP sell-faucet and the Beacon-accrual rate (Consumable OQ-CD-2). See OQ-DS-7. No numbers are asserted until that decision lands, so the "Beacon self-replenishes ~2:1" figure in the Consumable GDD's Tuning Knobs remains **contingent** on OQ-DS-7.

### States and Transitions

The Drop System has **no runtime state machine** — resolution is a single synchronous pass triggered by `battle_ended(VICTORY, …)`. It **does** own **persistent state**: the per-part **pity counters** (Prototype attempts, Boss-grade qualifying-breaks), which persist across battles and sessions (serialized by Save/Load).

| Phase (within one resolution) | Action |
|---|---|
| 1. Assemble | Build fired-condition set from `fired_break_events` + outcome facts (Rule 3) |
| 2. Roll loop | For each `drop_enabled` pool part (ID-ascending): **(a)** check the pity guarantee **first** (Rule 6 Prototype / Rule 7 Boss-grade) — if guaranteed, force the drop and **skip the RNG draw**; **(b)** otherwise eval Formula 3 and roll the seeded RNG (Rule 2/4); **(c)** update that part's pity counter (increment/reset). *The pity check is pre-roll — a guaranteed part never advances the RNG stream (EC-DS-06).* |
| 3. Emit | Instantiate each dropped part → hand to Inventory (Rule 8) |
| 4. Persist | Serialize updated pity counters (Save/Load) |
| 5. Report | Emit the resolved drop list for the loot screen (Combat UI) |

> **Note — pity is checked *before* the roll, not after.** The pity guarantee and the RNG roll are a single per-part decision inside the roll loop (Phase 2), not two separate passes. A guaranteed part is resolved without touching the RNG. Do **not** implement this as "roll everything, then override guaranteed parts" — that spends a draw the pity system must skip and desynchronizes the seeded stream (AC-DS-10, AC-DS-13).

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| **Turn-Based Combat** | ← consumes | `battle_ended(VICTORY, enemy_id, fired_break_events: Set)` (Rule 12) is the sole trigger |
| **Enemy Database** | ← reads | The enemy's **loot pool** (candidate part IDs) — resolves Enemy DB OQ-5 via Rule 2 |
| **Part Database** | ← reads | Formula 3 + per-rarity base rates; each part's `drop_conditions`, `rarity`, `drop_enabled`; part-instance schema (Rule 8) |
| **Part-Break System** *(Approved 2026-07-11)* | ↔ ratified | Break events → fired conditions (Rule 3). **Ratified contract:** Part-Break emits exactly the Rule 5 break-event keys into TBC's `fired_break_events` set. **Break is deterministic** — there is no `P(break fires)` probability and no break-failure pity (Part-Break DB3 dissolved: pool depletion is guaranteed, DAMAGE_FLOOR ensures progress). Our **drop-RNG pity (DS-3 / Rule 7) is separate and unaffected** — it bounds only the drop roll after a qualifying break |
| **Consumable Database** *(Approved 2026-07-12)* | ← reads | Consumable `rarity` for the separate level/rarity-scaled consumable drop channel (Rule 12); the `beacon_used_this_battle` flag → inject `beacon_multiplier` (CD-4) into the part `effective_drop_rate` product. Consumable drop *frequency* owned here (OQ-DS-7, deferred) |
| **Inventory System** *(Not Started)* | → emits | Receives new part instances (Rule 8) and dropped consumable instances (Rule 12); stores Scrap currency; hosts the player-initiated scrap action (Rule 9) |
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

**Salvage Beacon factor (Rule 12a erratum).** When `beacon_used_this_battle` on VICTORY, the product gains one more factor before the clamp: `effective_drop_rate(p) = clamp( base_drop_rate[rarity] × Π(condition multipliers) × beacon_multiplier, 0, 1 )`, `beacon_multiplier = 2.0` (Consumable CD-4). Same worked example *with* a Beacon → `clamp(0.25 × 1.5 × 1.3 × 2.0, 0, 1) = clamp(0.975) = 0.975`. A Common already at the conditioned ceiling clamps: `clamp(0.70 × … × 2.0) = 1.0` (guaranteed Commons gain nothing — acceptable). The factor is absent (≡ 1.0) on non-Beacon fights and on flee/loss.

### DS-2 — Prototype Gradient Pity (PGP-1) — discharges Part DB DB2

Per-Prototype-ID **credit counter** that accumulates progress proportional to the number of the part's `drop_conditions` fired on each failed attempt. Let `c` = number of the part's conditions fired this attempt, `C` = the part's **total** condition count (`C ≥ 3` by the authoring floor). An attempt is **qualifying** iff `c ≥ 1`.

```
PITY_THRESHOLD(p) = N_PROTO_PITY × C(p)          # per-part; = 25 × 3 = 75 for a 3-condition part

On resolution of a QUALIFYING attempt (c >= 1) for prototype p:
  if pity_credit[p] >= PITY_THRESHOLD(p):
      drop = guaranteed (skip roll);  pity_credit[p] = 0          # checked BEFORE the roll
  else:
      roll DS-1;  if drop: pity_credit[p] = 0  else: pity_credit[p] += c
On a NON-qualifying attempt (c == 0, none of THIS part's conditions fired):
      roll DS-1 at base_rate (no condition multipliers apply — the part still rolls, Rule 2);
      if drop: pity_credit[p] = 0    # a natural base-rate drop still resets, per AC-DS-15
      else:    pity_credit[p] unchanged   # no credit earned — anti-exploit
# Anti-exploit scope: "non-qualifying" means none of THIS part's drop_conditions fired this
# fight; the enemy need not be the part's host. A victory that fires none of the part's own
# conditions banks no credit — but the part still gets its base-rate roll and resets on a hit.
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Credit counter | `pity_credit[p]` | int | 0–`PITY_THRESHOLD(p)` | Accumulated condition-credit from failed qualifying attempts; per-Prototype-ID; persisted in save |
| Conditions fired | `c` | int | 0–`C` | Number of the part's `drop_conditions` fired this attempt |
| Condition count | `C(p)` | int | ≥3 | The part's total `drop_conditions` count (authoring floor ≥3) |
| Base threshold const | `N_PROTO_PITY` | int const | **25** (safe 15–25) | Optimal-attempts-to-guarantee. Actual credit threshold = `N_PROTO_PITY × C(p)` |

**Optimal play is unchanged by the credit model.** When `c = C` every attempt, the counter gains `C` per failure and reaches `N_PROTO_PITY × C` in exactly `N_PROTO_PITY` optimal attempts — so a fully-optimal hunter still guarantees on the (N+1)th optimal attempt worst case, **for any condition count `C`**. Partial play converges more slowly: the guarantee fires on attempt `⌈N_PROTO_PITY × C / c⌉ + 1` worst case (the `+1` because the attempt that pushes credit to/over the threshold is itself a roll; the guarantee is the *following* qualifying attempt). E.g. 3-condition part: 2-of-3 → `⌈37.5⌉ + 1 = 39` attempts; 1-of-3 → `75 + 1 = 76` attempts. This removes the old all-or-nothing dead zone (a player firing 2-of-3 for 30 attempts used to earn zero progress and, since pity is hidden, could not know they were not converging).

**Hidden from the player** — no pity-counter UI (surprise-rescue design). Integer-only; no rounding, no epsilon. **Worked example (3-condition part, threshold 75):** credit at 72 (= 24 optimal attempts × 3), optimal attempt (c=3) → `72 >= 75` false → roll, fails → credit 75. Next optimal attempt → `75 >= 75` true → **guaranteed drop**, credit → 0. **Partial-credit example:** credit at 40, a 2-of-3 attempt (c=2) fails → credit 42 (not 41).

**Calibration is authoring-gated — see "Pity Calibration Authoring Rules" below.** Calibration is stated for **optimal** play, which the credit model leaves identical to the old counter model. The **minimum floor-compliant** optimal rate is `0.05 × 1.5³ = 0.16875` (three conditions at exactly `MULTIPLIER_FLOOR` = ×1.5, product 3.375), giving `0.83125²⁵ ≈ 0.99%` of hunters ever reaching pity via optimal play — this is the headline safety-net figure for shippable content. A rate as low as 0.15 (`0.85²⁵ ≈ 1.72%`) is reachable **only with sub-floor conditions** (a multiplier in the `(1.0, 1.5)` content-warning band, i.e. non-compliant content), so 1.72% is the *worst-case-warned* bound, not the authored minimum. Both are rare-safety-net territory (pity is a tail rescue, not an expected path) **only because** the authoring floor holds N=25 above the "expected path" band — a Prototype authored below the floor would hit pity far more often. Partial play fails more often per attempt (fewer multipliers) but also banks credit more slowly, so it remains tail-rescue territory, never a shortcut.

### DS-3 — Boss-grade Deterministic Floor (BGDF-1) — discharges Part DB EC-16

Per-Boss-grade-ID counter of consecutive **qualifying breaks** (the required break fired, part eligible) that failed the drop roll:

```
On resolution of a QUALIFYING-BREAK battle for boss-grade part p:
  if break_pity_counter[p] >= M_BOSS_PITY:
      drop = guaranteed (skip roll);  break_pity_counter[p] = 0
  else:
      roll DS-1;  if drop: break_pity_counter[p] = 0  else: break_pity_counter[p] += 1
Break did NOT fire this battle: break_pity_counter[p] unchanged (the player simply didn't target/deplete the region — breaks are deterministic, so there is no "break failure" here; Part-Break DB3 dissolved).
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Counter | `break_pity_counter[p]` | int | 0–`M_BOSS_PITY` | Consecutive qualifying breaks that failed the drop roll; per-Boss-grade-ID; persisted |
| Threshold | `M_BOSS_PITY` | int const | **8** (safe 5–8) | Guarantee fires on the (M+1)th qualifying break in the worst case |

**Hidden from the player.** **Worked example:** counter at 7, qualifying break, drop roll (~0.5) fails → counter 8. Next qualifying break → `8 >= 8` true → **guaranteed drop**, counter → 0. At the authored Boss-grade break floor (effective ≥ 0.5), natural odds of reaching 8 consecutive failures: `0.5⁸ ≈ 0.39%`.

### Pity Calibration Authoring Rules

Both pity thresholds are calibrated to a **minimum content strength**. If content is authored weaker than the floor, the "natural odds" above break and pity stops being a rare rescue. These floors are load-bearing and BLOCKING for pity's design intent:

| Threshold | Depends on | Authoring floor (BLOCKING) | Odds of hitting pity at the floor | If floor is violated |
|-----------|-----------|-----------------------------|-----------------------------------|----------------------|
| `N_PROTO_PITY = 25` (DS-2) | Prototype **optimal rate** = `0.05 × Π(condition multipliers)`; credit threshold = `N_PROTO_PITY × C` (C = condition count, ≥3) | Prototype `drop_conditions` must total **≥ ×3.0** across **≥3 conditions** (e.g. ≥3 conditions at ×1.5, or fewer at higher multipliers *but still ≥3 conditions* so the credit model has a gradient) → floor-compliant optimal rate **≥ 0.16875** (three conditions at exactly ×1.5 = product 3.375; the ≥×3.0 product rule combined with the ×1.5 per-condition floor makes 0.16875 the true minimum — 0.15 is only reachable with sub-floor/warned conditions). Owned/enforced by **Part DB's Prototype authoring rule + content validation**; DS-2 depends on it. Calibration is stated for optimal play, unchanged by the credit model. | `0.83125²⁵ ≈ 0.99%` (optimal, compliant floor) | e.g. total ×2.0 → optimal 0.10 → `0.90²⁵ ≈ 7.2%` reach pity via optimal play — pity becomes a semi-expected path, eroding the surprise-rescue intent. |
| `M_BOSS_PITY = 8` (DS-3) | Boss-grade **effective break rate** = `0.001 × break_multiplier` | Boss-grade must carry a break condition of **≥ ×500** → effective rate **≥ 0.5**. **Already mandated by Part DB AC-11** (content validation fails below ×500). DS-3's `M=8` calibration is only valid because this rule holds. | `0.5⁸ ≈ 0.39%` | e.g. ×200 → effective 0.2 → `0.8⁸ ≈ 16.8%` reach pity — a wholly different feel; but Part DB AC-11 makes this un-shippable, so the floor is enforced upstream. |

**Cross-reference obligation:** the `≥ ×500` Boss-grade rule (Part DB AC-11 / Enemy DB AC-ED-09) is **load-bearing for DS-3** — if it is ever relaxed, `M_BOSS_PITY` must be re-derived. The `≥ ×3.0` Prototype floor is the DS-2 analog and **already exists in Part DB** (Prototype base-rate content rule: "every Prototype must define ≥3 drop conditions whose full multiplier product is ≥ ×3.0"). Note: that Part DB rule is stated but has **no dedicated content-validation AC** (Part DB AC-10/AC-19 cover stat budget, not drop-condition strength) — a Prototype authored below ×3.0 would slip through and silently make DS-2 pity a semi-expected path. *Surfaced obligation: Part DB should add a content-validation AC for the ≥ ×3.0 Prototype drop-condition floor (the DS-2 analog of AC-11).*

**Cross-system constants introduced here:** `N_PROTO_PITY = 25` (optimal-attempts-to-guarantee; the runtime credit threshold is the derived `N_PROTO_PITY × C` per part), `M_BOSS_PITY = 8`, `MULTIPLIER_FLOOR = 1.5` (flagged for the entity registry).

## Edge Cases

**EC-DS-01 — Victory with no conditions fired.** *If the player wins having fired zero drop conditions*: every part rolls at `base_drop_rate × 1.0` (no multipliers). Commons/Rares still drop at base; Boss-grade rolls at 0.001 (its deliberate persistence floor — see Rule 4 note; DS-3 counter is not incremented since no qualifying break fired). No crash. *Verified by AC-DS-05.*

**EC-DS-02 — Empty or fully-disabled loot pool.** *If the enemy's pool is empty or every part is `drop_enabled = false`*: zero drops emitted; the loot report is an empty list; no crash. *Verified by AC-DS-06.*

**EC-DS-03 — Unknown condition key in `drop_conditions`.** *If a part lists a condition key not in the Rule 5 vocabulary*: that entry is logged as a content error and skipped (its multiplier is not applied); all valid conditions on the part still evaluate. No crash. *Verified by AC-DS-07.*

**EC-DS-04 — Effective rate exceeds 1.0 before clamp.** *If `base × Π multipliers > 1.0`* (e.g. Common 0.70 × two favorable conditions): `clamp(...,0,1) = 1.0` → guaranteed drop (`randf() < 1.0` always true). Correct per Part DB Formula 3. *Verified by AC-DS-03.*

**EC-DS-05 — Boss-grade won without the qualifying break.** *If a Boss-grade part's required break did not fire but the player won*: rate = ~0.001 (functionally zero), and its DS-3 `break_pity_counter` is **not** incremented (only *qualifying* breaks count). No progress toward Boss-grade pity is made — by design; repeated break *failure* is Part-Break's DB3 soft-lock domain, not this counter's. *Verified by AC-DS-09.*

**EC-DS-06 — Pity guarantee and RNG determinism.** *If a pity guarantee fires (DS-2/DS-3)*: the drop is awarded **without drawing from the RNG** — the roll is skipped, so the seeded RNG stream does **not** advance for that part. This keeps `(seed, pool, conditions, pity state)` fully reproducible. *Verified by AC-DS-10.*

**EC-DS-07 — Defeat or flee after firing break events.** *If the player breaks regions but then loses or flees*: TBC discards `fired_break_events`; the Drop System never triggers (VICTORY-only, Rule 1). No drops, and **no pity counter changes** (no resolution occurred). *Verified by AC-DS-02.*

**EC-DS-08 — Duplicate part ID in a loot pool.** *If a pool lists the same part ID more than once* (content authoring noise): the Drop System iterates **unique** IDs, so the duplicate contributes no extra roll — the part rolls **once**, at most one instance from that ID per fight. This aligns with Approved Enemy DB EC-ED-08 (the content validator dedupes duplicate pool entries with an authoring warning; duplication is never a drop-rate lever). No crash. *Verified by AC-DS-08.*

**EC-DS-09 — Inventory storage of a guaranteed drop.** *If a successful/guaranteed roll produces an instance*: the Drop System **always emits** it and resets the relevant pity counter, independent of storage. MVP parts inventory is unbounded (no cap), so acceptance is guaranteed; any future cap/overflow policy is the Inventory GDD's concern. *No Drop System AC — the emit contract is verified by AC-DS-01; storage is owned by the Not-Started Inventory System.*

## Dependencies

### Upstream (Drop System reads from / is triggered by)

| System | What Drop System reads | Status | Hard/Soft |
|--------|------------------------|--------|-----------|
| **Turn-Based Combat** | `battle_ended(VICTORY, enemy_id, fired_break_events: Set)` — the sole resolution trigger (Rule 1) | Approved | Hard |
| **Part Database** | Formula 3 + per-rarity base rates; each part's `drop_conditions`, `rarity`, `drop_enabled`; the part-instance schema (Rule 8) | Approved | Hard |
| **Enemy Database** | The enemy's loot pool (candidate part IDs) — Rule 2 | Approved | Hard |
| **Part-Break System** | Break-event keys → fired conditions (Rule 3). Break is **deterministic** — no `P(break fires)` term enters the Boss-grade acquisition math; the only randomness is the drop roll (DS-1) and its DS-3 pity | **Approved (2026-07-11)** | Hard (ratified contract — Rule 5/7) |
| **Consumable Database** | Consumable `rarity` (drop-channel classification, Rule 12); the `beacon_used_this_battle` flag + `beacon_multiplier` constant (CD-4) | **Approved (2026-07-12)** | Soft (data-schema; Drop System reads the flag + classification, no runtime state) |

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
- **Part-Break System** (Approved 2026-07-11) — contract ratified: Part-Break emits the Rule 5 break-event keys deterministically into TBC's `fired_break_events` set; Rule 5/7 are no longer provisional
- **Consumable Database** (Approved 2026-07-12) already lists Drop System as a downstream reader (its Downstream table + errata obligation 2: consumable drop channel + Beacon injection) ✓ — this Rule 12 erratum discharges that obligation; consumable frequencies remain open as OQ-DS-7

### Upstream obligations this GDD discharges

- **Part DB DB2** (Prototype pity) → **DS-2**, `N_PROTO_PITY = 25`.
- **Part DB EC-16** (Boss-grade deterministic floor) → **DS-3**, `M_BOSS_PITY = 8`.
- **Part DB DB5** (scrap sink) → Rule 9 + Scrap yields (Tuning Knobs); sink = material-gated upgrading.
- **Enemy DB OQ-5** (pool-size dilution) → **resolved: independent per-part rolls over unique IDs, no `÷ pool_size`** (Rule 2). *Errata obligation: Enemy DB OQ-5 marked RESOLVED (applied this revision).*
- **Enemy DB OQ-4** (Boss-grade acquisition + bad-luck protection) → **resolved**: ×500 qualifying break (~0.5) + DS-3 deterministic floor. *Errata obligation: Enemy DB OQ-4 marked RESOLVED (applied prior revision).*
- **Enemy DB ED3-OQ7 / Recommended #7** (`MULTIPLIER_FLOOR` owner) → **resolved here: `MULTIPLIER_FLOOR = 1.5`** (Rule 5a). *Errata obligation: Enemy DB ED3-OQ7 + Recommended #7 marked RESOLVED, owner Drop System (applied this revision).*
- **Duplicate-pool-ID contract** → **resolved: dedupe to unique** (Rule 2 / EC-DS-08 / AC-DS-08), aligning with Approved Enemy DB EC-ED-08. No Enemy DB change needed (it already dedupes).
- **Stale `÷ pool_size` references** (Part DB Tuning Knob `BASE_DROP_RARE`; Enemy DB loot-pool prose) → **corrected: no pool-size normalization** (Rule 2). *Errata applied to Part DB line 696 and Enemy DB loot-pool description this revision.*

## Tuning Knobs

| Knob | Value | Safe Range | What changing it does |
|------|-------|-----------|-----------------------|
| `N_PROTO_PITY` | 25 | 15–25 | Prototype pity base (DS-2), in optimal-attempts-to-guarantee; the runtime credit threshold is `N_PROTO_PITY × C` (C = the part's condition count). Lower → pity fires more often (becomes an expected path below ~12); higher → rarer safety net. At 25, ~0.99% of hunters hit it via optimal play at the floor-compliant minimum optimal rate (0.16875 = three conditions at ×1.5); the 1.72% figure (rate 0.15) applies only to sub-floor/warned content — see Pity Calibration Authoring Rules. Partial play converges at `⌈N_PROTO_PITY × C / c⌉ + 1` attempts worst case. |
| `M_BOSS_PITY` | 8 | 5–8 | Boss-grade pity threshold (DS-3). Below 4, pity gets visible (>12% hit it) and erodes the "~2 attempts" intent; at 8, ~0.39% hit it — *valid only while the ≥ ×500 Boss-grade break rule (Part DB AC-11) holds*. |
| `MULTIPLIER_FLOOR` | 1.5 | 1.2–2.0 | Minimum drop-condition multiplier that counts as a real harvest incentive (Rule 5a; discharges Enemy DB ED3-OQ7). Below 1.2, sub-threshold conditions pass the Enemy DB `loot_connected` check but deliver an imperceptible tilt (Pillar 2 nominal-only); above 2.0, few legitimate conditions get flagged and the check loses teeth. Content-validation constant, not a runtime knob. |
| Scrap yield — Common | 5 | 3–8 | Primary faucet. Below 3 fails DB5 (feels ignorable); above 8 trends toward trivially funding all upgrades. **Highest-leverage faucet knob.** |
| Scrap yield — Rare | 20 | 15–24 | Secondary faucet (4× Common). Matters when the player scraps Rare duplicates rather than running two copies. **Below Prototype by design** — Prototypes are harder to acquire (gated by the ≥3-condition optimal hunt + DS-2 pity), so a duplicate Prototype represents more invested effort than a duplicate Rare and yields more. |
| Scrap yield — Boss-grade | 60 | 50–100 | Emotional weight (12× Common). Duplicate Boss-grades are infrequent; the number just needs to feel significant. |
| Scrap yield — Prototype | 35 | 25–45 | 7× Common, **deliberately below Boss-grade** — prevents a perverse "scrap the second Prototype instead of running it on another Symbot" incentive. |

> **Hard cross-knob constraint (AC-DS-19):** the ordering `COMMON < RARE < PROTOTYPE < BOSS_GRADE` is invariant and **supersedes the individual safe ranges above** — any retune must preserve it. The ranges are deliberately non-overlapping at their boundaries (Common ≤8, Rare 15–24, Prototype 25–45, Boss-grade ≥50) so that no legal combination of per-knob values can invert the ordering. An inversion (e.g. Prototype ≥ Boss-grade) would reward scrapping the rarer part — AC-DS-19 fails the build if it ever occurs.
| Pool Common cap (content rule) | ≤2 WILD, ≤3 BOSS | — | Caps Common slots per loot pool so independent rolls don't flood. Authoring constraint honored by **Enemy DB** loot-pool authoring. Removing it re-introduces the ~2.8-drops/fight Common flood. |

**Sink values (proposed here, owned by Part Upgrade / Workshop GDD):** upgrade cost per tier — `0→1: 10`, `1→2: 20`, `2→3: 40`, `3→4: 80`, `4→5: 160` (pure doubling). Cap totals: **Common +3 = 70**; **Rare/Prototype/Boss-grade +5 = 310**. The accelerating (doubling) curve puts the cost at the top: the cheap first hit (10) hooks the upgrade habit, while the final `+4→+5` step (160) *alone* exceeds the entire `+0→+3` journey (70), so the last two tiers (80 + 160 = 240) cost ~3.4× the first three (70). Maxing a part is a deliberate end-game investment, not a default. (Every step is ≥ the previous — monotonic; there is no discount inflection.)

**Economy model — from-scratch derivation (mild-scarcity target, 3-Symbot baseline).**

*This model is a design-time estimate; empirical precision is validated at playtest (OQ-DS-5). Its job is to show the faucet and sink are consistent and hit the mild-scarcity target — not to predict exact totals.*

**Stated assumptions:**
- **A1 — Battle volume:** ~200 victories across the ~10-hour MVP arc.
- **A2 — Per-victory drop yield** (base rates × Pool Common cap, averaged; Rare/Prototype get modest condition uplift; dedupe per Rule 2 means no duplicate flood):
  - Common: ~2.0 Common pool slots × 0.70 ≈ **1.4/victory → ~280** over the arc.
  - Rare: ~1.2 Rare slots × ~0.30 effective ≈ **0.36/victory → ~72**.
  - Boss-grade: boss fights only → **~5** over the arc.
  - Prototype: ~0.04/victory → **~8**.
- **A3 — Drop-absorption rate** (fraction of drops the player *scraps* rather than equipping across ≤3 Symbots or banking; each type is wanted on up to 3 Symbots, so early copies are kept — Commons saturate fastest, Prototype wanted on multiple builds): **Common 75%, Rare 50%, Boss-grade 0%, Prototype 25%.**
  - **Boss-grade at 0% (MVP scope):** at 2-boss MVP scale there are only ~2 distinct Boss-grade parts. A player equips both (one per Symbot, or one + a bank spare) and scraps **none** — so Boss-grade contributes ~0 Scrap in MVP, not a reliable faucet. (Corrected this revision from the earlier 25%/75-Scrap line, which was structurally implausible at 2-boss scope; any Boss-grade scrap is a rare bonus, not modeled income.)
  - **Temporal caveat (early absorption runs low):** these are *arc-average* rates. Early game (1 Symbot, hours 1–3) real Common absorption is far lower (~10–20%) — players bank duplicate Commons for the second and third Symbots they don't own yet. Scrap income is therefore **back-loaded**; see the game-thirds sketch below. This is the model's most sensitive timing assumption and a primary OQ-DS-5 watch criterion.

**Faucet (Scrap earned over the arc):**

| Rarity | Dropped (A2) | × absorption (A3) | × yield | Scrap |
|--------|--------------|-------------------|---------|-------|
| Common | 280 | 0.75 | 5 | 1,050 |
| Rare | 72 | 0.50 | 20 | 720 |
| Boss-grade | 5 | 0.00 | 60 | 0 |
| Prototype | 8 | 0.25 | 35 | 70 |
| **Total** | | | | **≈ 1,840** |

Absorption is the sensitive lever, so state a **band: ~1,555–2,125 Scrap** (Common/Rare absorption ±10pp → floor `280×0.65×5 + 72×0.40×20 + 70 = 1,556`; ceiling `280×0.85×5 + 72×0.60×20 + 70 = 2,124`; Boss-grade held at 0). Common yield alone is ~57% of the faucet — consistent with the Tuning Knobs table calling it the highest-leverage faucet knob. The band's **floor is the riskier tail**: under-absorption (banking Commons for future Symbots) is more likely than over-absorption, especially before hour 5.

**Faucet over the arc (game-thirds sketch — timing, not just total).** Because early Common absorption runs low (A3 temporal caveat), Scrap income is back-loaded rather than linear. Modeling the ramp explicitly (Common absorption 15%→60%→90% across the thirds, Rare held ~50%) yields a **conservative ~1,565 total** — this ramp averages ~55% Common absorption, *below* the faucet table's 75% arc-average, so the game-thirds view is the **back-loaded / under-absorption end of the band (≈ the ~1,556 floor)**, while the 75%-flat central estimate (~1,840) is the more optimistic arc-average. The per-third figures below sum to the conservative ~1,565, not the central 1,840:

| Arc third | ~Victories | Symbots owned | Common absorption | ~Scrap earned | What the player can afford |
|-----------|-----------|---------------|-------------------|---------------|-----------------------------|
| Hours 1–3 | ~60 | 1 | ~15% | **~300** | First cheap upgrades (10/20/40) on the lead Symbot's priority parts — the "upgrade hook" lands |
| Hours 4–7 | ~80 | 2 | ~60% | **~650** | Mid-tier upgrades on lead + starting the second Symbot; scarcity becomes felt |
| Hours 8–10 | ~60 | 3 | ~90% | **~615** | The expensive +4→+5 tiers (80/160) on priority parts; third Symbot partially kitted |

The sketch confirms the cheap early tiers (10/20/40 = 70 total for a Common max) are affordable inside the first third's ~300 Scrap, so the upgrade habit forms early even at low early absorption — the economy is not dead at the start. The expensive tiers correctly land in the final third, when **cumulative** Scrap is highest (~1,565 banked by end) and **per-victory** income peaks (~10/victory at ~90% absorption); note the final third's *total* (~615) is slightly under the middle third's (~650) only because it holds fewer victories (60 vs 80) — the player is richest at the end, not earning fastest-per-third. **Watch criterion (OQ-DS-5):** if hours 1–3 real income falls below ~120 Scrap (absorption near 0%, player hoards everything), the player cannot afford even the first +0→+1 (10) comfortably and the hook is delayed — playtest for "does the player make their first upgrade before hour 3?"

**Sink (upgrade cost to fully max priority parts):** per Symbot the player fully upgrades a **4-part core loadout** — stated priority-part rarity mix: **2 Rare (+5 = 620) + 1 Prototype (+5 = 310) + 1 Common (+3 = 70) = ~1,000 Scrap/Symbot.** Across `TEAM_ROSTER_CAP = 3` Symbots, a *full* 3-loadout max = **~3,000 Scrap**. (A duplicate Boss-grade to +5 = +310 is a stretch spend on top, not part of the baseline priority sink — Boss-grade parts are ~1 per roster, not per Symbot.)

**Result — mild scarcity holds across the band.** Central faucet ~1,840 (band ~1,555–2,125) ≈ **just under two full core loadouts** (~1.8 × ~1,000); the lead Symbot is fully kitted, the second is nearly there, and the third's loadout (~1,000 more) is only partially funded. So the player **fully kits their lead Symbot and most of a second, then chooses which parts on the third to prioritize** — upgrade-target choices stay meaningful without a grind wall. The "just under two" (rather than a clean two) is deliberate: it means even a 2-Symbot player must make a few priority calls near the end rather than maxing everything. **Note the band's floor is the load-bearing case:** at ~1,556 a 2-Symbot player is ~78% funded (not the ~92% of the central estimate), and the back-loaded game-thirds model below lands at this floor — so "mild scarcity" is stated for the *whole band*, and the floor is a sharper-choices experience, not a broken one.

**Tiered outcome by Symbot count (partial-max is the realistic play, not full-max):**
- **1 Symbot:** ~1,840 Scrap vs ~1,000 priority sink → fully maxed with ~840 surplus for stretch spends (a duplicate Boss-grade to +5 = 310, or over-investing non-priority parts). Scrap saturates — watch that upgrade choices stay meaningful past hour 5 (OQ-DS-5).
- **2 Symbots:** ~1,840 vs ~2,000 full priority sink → ~92% funded; the player maxes their lead and makes 1–2 priority calls on the second. The intended "mild scarcity" sweet spot.
- **3 Symbots:** ~1,840 vs ~3,000 full priority sink → ~61% funded (~613 Scrap/Symbot). Full-max on all three is *not* reachable; the realistic play is +3 on most parts and +5 only on each Symbot's 1–2 signature parts. Scarcity extends — choices stay sharp. See OQ-DS-5 for the >3-Symbot tail.

Pool cap (≤2 WILD / ≤3 BOSS) is an Enemy DB authoring constraint — the Drop System has no runtime enforcement and no AC for it; a future QA tester should not hunt for one.

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

2. **Condition legibility (Combat UI) — full-legibility mandate:** for each part in the enemy's loot pool, the loot screen (or a per-part detail panel, tappable) must show which drop conditions fired this fight and their combined net multiplier (e.g., `arm_broken ×1.5, targeting_active ×1.3 → effective rate ×1.95`). This is how "every drop condition you fire is a visible tilt of the odds" (Player Fantasy) is wired to the player — fired conditions are player actions, not hidden state. This obligation is owned by Drop System because it owns the canonical condition vocabulary (Rule 5).

3. **Boss-grade break requirement label (Combat UI) — pre- or in-fight:** any Boss-grade part in the enemy's loot pool must have its required break event surfaced before or during combat (e.g., on the enemy info panel: "Core Drop: requires `core_broken`"). Players cannot deliberate-hunt if they cannot discover the hunt condition. This is the primary anti-Pillar-2-violation gate for the Boss-grade acquisition mechanic.

4. **Scrap action (Inventory/Workshop UI):** player-initiated, per-part **and** batch ("scrap all duplicates of type"), with a confirmation showing Scrap gained (Rule 9).

> 📌 **UX Flag — Drop System**: the loot screen and scrap action are player-facing needs. Fold items 1–3 into the combat-screen `/ux-design` pass (`design/ux/combat.md`) and item 4 into the inventory pass (`design/ux/inventory.md`), not this GDD. The obligations above are binding requirements; the UX spec owns layout and interaction design.

## Acceptance Criteria

All BLOCKING ACs are Logic-type automated unit tests in `tests/unit/drop_system/`. RNG-based ACs inject a stub `RandomNumberGenerator` returning a stated draw sequence. Float assertions use `abs(x − expected) < 1e-9` (the listed products are exact in IEEE 754 double; epsilon is defensive against future multiplier retuning).

### Roll & Formula

**AC-DS-03** (BLOCKING): rate > 1.0 pre-clamp guarantees the drop. GIVEN Common `scrap_bolt` (0.70) with `arm_broken`(×1.5)+`targeting_active`(×1.3) fired (product 1.365 → clamped to 1.0). SCENARIO A: draw = **0.001** → drops. SCENARIO B: draw = **0.99** → drops. THEN `effective_drop_rate = 1.0` for both. FAIL: rate returned unclamped (1.365); drop false for any draw < 1.0. *Verifies EC-DS-04.*

**AC-DS-04** (BLOCKING): strict-`<` boundary. GIVEN Rare `servo_arm`, rate 0.25. SCENARIO A: draw = **0.25** → drops = **false** (0.25 is not less than 0.25). SCENARIO B: draw = **0.24** → drops = **true** (0.24 < 0.25). FAIL: SCENARIO A returns true (indicates `<=`). *`0.25` is exactly representable in IEEE 754 double — no ulp arithmetic needed. GDScript: stub the RNG by subclassing `RandomNumberGenerator` and overriding `randf()` to return the specified value. The canonical `<` vs `<=` discriminator.*

**AC-DS-05** (BLOCKING): no conditions fired → base rates. GIVEN pool [Common 0.70, Rare 0.25, Boss-grade 0.001], empty fired set, draws (ID-asc) 0.65/0.20/0.0005, THEN all three drop at base rate (no multipliers). SECOND: Boss-grade draw 0.002 → no drop (0.002 ≥ 0.001). FAIL: conditions applied on empty set; Boss-grade treated as rate 0.0 (impossible instead of ~0.001). *Verifies EC-DS-01.*

**AC-DS-07** (BLOCKING): unknown condition key logged + skipped. GIVEN Rare `servo_arm` with conditions `arm_broken`(×1.5), `UNKNOWN_KEY_XYZ`(×2.0), `targeting_active`(×1.3); `arm_broken`+`targeting_active` fired; draw 0.41, THEN rate = clamp(0.25×1.5×1.3)=0.4875, drops, exactly one content error names `UNKNOWN_KEY_XYZ`, no crash. SECOND: draw 0.70 → no drop (discriminates: applying ×2.0 would give 0.975 and falsely drop). FAIL: exception; unknown multiplier applied; no log. *Verifies EC-DS-03.*

**AC-DS-12** (BLOCKING): independent per-part rolls, no pool dilution. GIVEN a 5-part pool: [Common `bolt_plate` (0.70), Common `wire_coil` (0.70), Common `grip_ring` (0.70), Rare `servo_arm` (0.25), Common `armor_seal` (0.70)]; no conditions; draws ID-ascending = [0.65, 0.65, 0.65, **0.10**, 0.65]. THEN all 5 drop; `servo_arm` rate = 0.25; RNG called exactly 5×. SECOND: pool of 10 parts; draw for `servo_arm` = **0.10** → drops (rate still 0.25, not ÷pool_size). FAIL: `servo_arm` does not drop on draw 0.10 (pool-normalization bug: at 0.25÷5=0.05, draw 0.10 ≥ 0.05 → no drop — this is the discriminator). *Verifies R2.*

**AC-DS-22** (BLOCKING): condition matching is exact-string. GIVEN part with condition `arm_broken`; fired set has `ARM_BROKEN` + `arm_break` (not `arm_broken`), THEN no multiplier applied, rate = 0.25, no log error. FAIL: case-insensitive/substring match applies ×1.5. *Verifies R5 exact match.*

**AC-DS-23** (BLOCKING): multipliers stack multiplicatively; unfired conditions excluded. GIVEN Prototype `delta_core` (0.05), three ×1.5 conditions, exactly 2 of 3 fired. Effective rate = clamp(0.05 × 1.5 × 1.5) = **0.1125**. SCENARIO A (**discriminates additive/none**): draw = **0.11** → drops (0.11 < 0.1125); a *none-applied* impl (rate 0.05) does not drop (0.11 ≥ 0.05), and an *additive* impl `0.05 × (1 + 0.5 + 0.5) = 0.10` does not drop (0.11 ≥ 0.10). SCENARIO B (**discriminates all-three-applied**): draw = **0.15** → no drop (0.15 ≥ 0.1125); an impl that wrongly applies the unfired third condition (rate `0.05 × 1.5³ = 0.16875`) *would* drop (0.15 < 0.16875). FAIL: A does not drop, or B drops. *Verifies R3. `0.05 × 1.5 × 1.5` = 0.11250000000000002 in IEEE 754; draws 0.11/0.15 clear the ulp. The prior "0.225 (additive)" ghost value is removed — additive stacking of two ×1.5 on 0.05 yields 0.10, not 0.225.*

### Pity — Prototype (DS-2)

**AC-DS-13** (BLOCKING): credit-threshold boundary — guarantee at credit 75, not 72. PRECONDITION: `delta_core` is a Prototype (base 0.05) with **3** conditions `core_overload`(×1.5), `head_broken`(×1.5), `zero_defeats`(×1.5); `C = 3` → `PITY_THRESHOLD = N_PROTO_PITY × C = 25 × 3 = 75`; effective optimal rate = clamp(0.05×1.5³) = 0.16875; optimal = all three fired (`c = 3`). SCENARIO A: `pity_credit = 72` (= 24 optimal attempts), all three fired, draw **0.50** (> 0.16875) → `72 ≥ 75` false → roll fails → `pity_credit += 3` → **75**; no emit; one RNG draw consumed. SCENARIO B: `pity_credit = 75`, all three fired → `75 ≥ 75` true → guaranteed drop; RNG **not** called (assert stub call-count == 0); `pity_credit → 0`; exactly one instance emitted. **The pity check is BEFORE the roll:** a *post-roll* implementation (roll first, then guarantee only if the roll fails) would consume a draw here — the call-count == 0 assertion in B catches that bug. The RNG stub in B is armed with a draw of **0.50** (would fail); a correct pre-roll impl never touches it, a post-roll impl consumes it. FAIL: guarantee fires at credit 72 (threshold not scaled by C — reads a raw 25); A increments by 1 instead of `c`=3 (credit → 73, flat counter bug); B calls RNG (post-roll pity check / call-count == 1); B doesn't reset; B emits 0 or 2+ instances. *Verifies DB2/DS-2 credit threshold + `+= c` increment + pre-roll pity ordering.*

**AC-DS-14** (BLOCKING): non-qualifying attempt (zero conditions fired) gets no credit. GIVEN `delta_core` (3 conditions) `pity_credit = 10`, **zero** of its conditions fired (`c = 0`), draw 0.50 fails, THEN `pity_credit` stays **10**. FAIL: credit → 11+ (crediting a fight where none of the part's conditions fired — anti-exploit: an unrelated fight must bank nothing). *Anti-exploit; verifies the `c == 0` no-credit branch.*

**AC-DS-29** (BLOCKING): partial-credit increment — `+= c`, not `+= 1` and not `+= C`. GIVEN `delta_core` (3 conditions, base 0.05) `pity_credit = 40`, exactly **2 of 3** conditions fired (`c = 2`); effective rate = clamp(0.05 × 1.5²) = 0.1125; draw **0.50** (> 0.1125) → roll fails → `pity_credit += 2` → **42**. SECOND: from `pity_credit = 42`, a **1-of-3** attempt (`c = 1`, rate 0.05×1.5 = 0.075), draw 0.50 fails → `pity_credit → 43`. FAIL: credit → 41 (flat `+= 1` ignores conditions fired — the old all-or-nothing/flat-counter bug); credit → 43 on the first step (`+= C` = +3, over-crediting partial play to optimal rate); credit unchanged (treating 2-of-3 as non-qualifying). *Verifies DS-2 proportional credit: a qualifying-but-partial attempt banks exactly `c`. This is the discriminator between the new credit model and both the old all-or-nothing model and a naive flat-increment.*

**AC-DS-15** (BLOCKING): credit resets to 0 on any drop, even below threshold. GIVEN `delta_core` `pity_credit = 66`, optimal attempt (`c = 3`), draw 0.10 (< 0.16875) → drops via the normal roll (pity threshold 75 not reached), THEN `pity_credit → 0`. FAIL: stays 66; becomes 69 (`+= c` applied on a *drop* instead of reset). *Reset must fire on a natural drop even when the credit threshold was not reached — a natural drop ends the bad-luck run and banked credit is discarded.*

### Pity — Boss-grade (DS-3)

**AC-DS-16** (BLOCKING): trigger at counter=8, not 7. SCENARIO A: counter 7, qualifying break `core_broken`, draw 0.60 (>0.5) → `7≥8` false → fails → counter 8. SCENARIO B: counter 8, qualifying break → guaranteed, RNG not called, counter → 0, emitted. FAIL: fires at 7; B calls RNG or no reset. *Verifies EC-16/DS-3 boundary.*

**AC-DS-17** (BLOCKING): nominal DS-3 increment from a low counter (the plain increment path). GIVEN `forge_core` counter **0**, qualifying break `core_broken` fired (effective break rate 0.001 × 500 = 0.5), draw **0.60** (> 0.5) → no drop → counter → **1**. SECOND: from counter **1**, qualifying break, draw 0.60 → counter → **2** (the increment path is stable across resolutions, not only near the boundary). FAIL: counter stays 0 (increment path never taken from a low counter); jumps past 1; resets on a failure. *Covers the plain increment path from 0 — distinct from the 7→8 boundary (AC-DS-16) and the break-not-fired no-credit path (AC-DS-09). Replaces the former AC-DS-17, which duplicated AC-DS-09.*

**AC-DS-09** (BLOCKING): Boss-grade won without qualifying break → DS-3 counter NOT incremented. GIVEN `forge_core` counter 3, empty fired set, draw 0.5, THEN rate 0.001, draw 0.5 ≥ 0.001 → no drop, counter stays **3**. FAIL: → 4; reset to 0; drop true. *Verifies EC-DS-05 (the sole no-credit-on-non-qualifying-victory test; AC-DS-17 now covers the qualifying-break increment path instead).*

**AC-DS-30** (BLOCKING): DS-3 counter resets to 0 on a NATURAL drop below threshold. GIVEN `forge_core` (Boss-grade) `break_pity_counter = 5`, qualifying break `core_broken` fired (effective break rate 0.001 × 500 = 0.5), draw **0.30** (< 0.5) → **natural drop** via the normal roll (threshold 8 not reached), THEN `break_pity_counter → 0` and exactly one instance emitted. FAIL: counter stays 5; counter → 6 (`+= 1` applied on a *drop* instead of reset). *The DS-3 analog of AC-DS-15 — closes the asymmetric hole where an implementation that increments on failure but never resets on a below-threshold natural drop would pass AC-DS-16/17 (which only exercise the failure and guarantee paths). A natural drop ends the bad-luck run; the counter must reset.*

**AC-DS-24** (BLOCKING): pity counters are per-part-ID, not global. SCENARIO A (independence, one at pity): GIVEN `forge_core` counter 8 (qualifying break `core_broken` fired) + `volt_cannon` counter 2 (qualifying break `cannon_broken` fired); draw for `volt_cannon` = **0.60** (> 0.5 effective break rate). THEN `forge_core`: `8≥8` → guaranteed drop, counter → 0, instance emitted, RNG not consumed; `volt_cannon`: roll 0.60 ≥ 0.5 → no drop, counter → 3. FAIL: `volt_cannon` resets to 0 due to `forge_core` reset (shared counter); `volt_cannon` stays 2 (no update); `forge_core` RNG draw consumed. SCENARIO B (**both at pity in one fight — joint-guarantee path**): GIVEN `forge_core` counter 8 + `volt_cannon` counter 8, both Boss-grade, both qualifying breaks fired, RNG stub armed with **zero** draws; WHEN resolved (ID-ascending) → `forge_core` guaranteed drop, counter → 0; `volt_cannon` guaranteed drop, counter → 0; total RNG calls = **0**; **two** instances emitted. FAIL: either counter stays 8 (a reset on the first guarantee corrupts the second's guarantee check); any RNG call (stub exhausted → error); either instance missing (two adjacent guarantees short-circuit). *Verifies per-ID counters resolve independently even when both hit threshold in the same pass.*

### Trigger, Emit, Determinism

**AC-DS-01** (BLOCKING): emit contract. GIVEN a pity-guaranteed `forge_core`, WHEN VICTORY resolved, THEN Inventory mock receives exactly one `receive_part_instance({part_id: 'forge_core', upgrade_tier: 0})` call and `break_pity_counter['forge_core']` resets to 0. FAIL: mock receives 0 or 2+ calls; `upgrade_tier ≠ 0`; counter not reset. *Verifies EC-DS-09.*

**AC-DS-02** (BLOCKING): defeat/flee → no drops, no pity change. GIVEN `pity_credit['proto_arms'] = 12` (Prototype, DS-2) and `break_pity_counter['forge_core'] = 5` (Boss-grade, DS-3), non-empty fired set, WHEN DEFEAT (then FLED) resolved, THEN zero emits, **both** maps unchanged (`pity_credit['proto_arms'] == 12`, `break_pity_counter['forge_core'] == 5`), RNG not called. FAIL: any emit; either counter changes. *Verifies EC-DS-07.*

**AC-DS-06** (BLOCKING): empty/disabled pool → zero drops, no crash. A empty pool → []; B all `drop_enabled=false` → []; C mixed → only enabled part rolled (disabled not rolled, stream not advanced for it). FAIL: exception; disabled emitted; disabled consumes a draw. *Verifies EC-DS-02.*

**AC-DS-08** (BLOCKING): duplicate part ID → deduped to one roll. GIVEN pool listing `servo_arm` (Rare 0.25) twice, RNG stub with one draw **0.20** (< 0.25), THEN RNG called **exactly once**, **exactly one** `servo_arm` instance emitted (the duplicate is deduped, not a second trial). SECOND: draw **0.30** (≥ 0.25) → RNG called once, **zero** instances. FAIL: RNG called twice / two instances emitted (independent-trials bug — duplication must not double the roll count); zero rolls (over-dedup dropping the part entirely). *Verifies EC-DS-08; aligns with Enemy DB EC-ED-08.*

**AC-DS-10** (BLOCKING): pity guarantee skips the RNG draw. SCENARIO A (single guarantee): GIVEN pool [`forge_core` (pity-guaranteed), `servo_arm` (0.25)], RNG stub with one draw 0.20, WHEN resolved, THEN `forge_core` drops via guarantee (no draw consumed), `servo_arm` consumes the 0.20 and drops, total RNG calls = **1**. SCENARIO B (**two simultaneous guarantees — the stream-position discriminator**): GIVEN pool (ID-ascending) [`alpha_core` (pity-guaranteed), `beta_core` (pity-guaranteed), `gamma_arm` (Rare 0.25)], RNG stub armed with a **single** draw 0.20; WHEN resolved → `alpha_core` and `beta_core` both drop via guarantee (neither consumes a draw), `gamma_arm` consumes the one draw 0.20 (< 0.25) and drops, total RNG calls = **1**, three instances emitted. FAIL: 2+ draws consumed (a guaranteed part advanced the stream); `gamma_arm` reads a stale/absent draw (stub exhausted → error) because a guaranteed part consumed draw #0. *Verifies EC-DS-06 — the stream stays synchronized when multiple parts are guaranteed in one fight (realistic: a Prototype at credit-threshold and a Boss-grade at M_BOSS_PITY co-occurring).*

**AC-DS-11** (BLOCKING): victory-only gate. GIVEN `scrap_bolt`, RNG always 0.65 (<0.70). A VICTORY → one emit; B DEFEAT → zero emits, RNG not called; C FLED → zero emits, RNG not called. FAIL: non-VICTORY drops; VICTORY zero despite 0.65<0.70. *Complements AC-DS-02 (tests the gate itself).*

**AC-DS-18** (BLOCKING): deterministic reproducibility. "Identical pity state" is enumerated: **both** pity maps populated on both instances — `pity_credit['delta_core'] = 42` (Prototype, DS-2) AND `break_pity_counter['forge_core'] = 5` (Boss-grade, DS-3). GIVEN two DropSystem instances constructed with the same injected seed and these same two maps; pool = [`delta_core` (Prototype, all 3 conditions fired), `forge_core` (Boss-grade, qualifying break fired), `servo_arm` (Rare 0.25, no conditions)]; WHEN both resolve the same VICTORY payload, THEN (a) identical drop lists (same part_ids, same order), AND (b) identical post-resolution state on **both** maps: `pity_credit['delta_core']` equal across instances (0 if it dropped, else 45) AND `break_pity_counter['forge_core']` equal across instances (0 if dropped, else 6). FAIL: divergence in the drop list or *either* map (e.g. a global RNG singleton shared across instances; or the two instances sharing a single static pity map — caught only because both maps are populated and checked). *Verifies R10. Populating both maps is deliberate: a fixture seeding only one map would miss a shared-static-state bug in the other.*

**AC-DS-20** (BLOCKING): instances emitted at `upgrade_tier = 0` for all rarities. GIVEN one part of each rarity (IDs alphabetically: `armor_bolt` Common 0.70, `core_shield` Prototype 0.05, `forge_core` Boss-grade 0.001, `servo_arm` Rare 0.25); draws ID-ascending = [**0.0009**, **0.0009**, **0.0009**, **0.0009**] (all < 0.001 minimum base rate — confirms strict `<` at the tightest boundary). THEN 4 instances emitted, each `upgrade_tier = 0`. FAIL: any tier≠0; Boss-grade does not drop (draw 0.0009 < 0.001 must drop — draw 0.001 would NOT due to strict `<`). *Verifies R8.*

**AC-DS-21** (BLOCKING): parts rolled AND reported in ID-ascending order. GIVEN pool with IDs sorting alpha<beta<gamma (inserted non-alphabetically), RNG call-recording stub returning draws that make all three drop, THEN (a) RNG calls issued alpha→beta→gamma, AND (b) the emitted Phase-6 drop list, filtered to dropped parts, is ordered alpha→beta→gamma (matching roll order, not insertion order). FAIL: insertion-order iteration on the roll pass (GDScript Dictionary default); OR the drop list is assembled from a separate insertion-ordered structure so its order diverges from roll order (Combat UI would then display drops non-deterministically). *Verifies R10 ordering for both the RNG stream and the reported list.*

**AC-DS-19** (BLOCKING): Scrap yield per rarity + ordering invariant. VALUE assertions (four, exact): `get_scrap_yield(COMMON) == 5`, `get_scrap_yield(RARE) == 20`, `get_scrap_yield(PROTOTYPE) == 35`, `get_scrap_yield(BOSS_GRADE) == 60`. ORDERING assertions (three explicit booleans, evaluated programmatically — not prose): `assert get_scrap_yield(COMMON) < get_scrap_yield(RARE)`; `assert get_scrap_yield(RARE) < get_scrap_yield(PROTOTYPE)`; `assert get_scrap_yield(PROTOTYPE) < get_scrap_yield(BOSS_GRADE)`. FAIL: any value wrong, or any ordering assertion false (an inverted step creates a perverse scrapping incentive against the rarity hierarchy — e.g. Prototype ≥ Boss-grade would reward scrapping the wrong rarity). *Verifies R9 yield constants (source side; the player-initiated action is Inventory's, Advisory).*

### New Blocking ACs (this revision)

**AC-DS-25** (BLOCKING): outcome-fact conditions apply their multipliers — unit-testable half of AD-1. GIVEN a part with condition `zero_defeats`(×1.5) and base rate 0.25; fired set = {`zero_defeats`} (injected directly as a Set of strings — no TBC interface required for this unit test). Effective rate = clamp(0.25 × 1.5) = **0.375**. SCENARIO A (**the discriminator**): draw = **0.30** → drops, because 0.30 < 0.375. A broken implementation that ignores the multiplier (rate stays 0.25) does **not** drop here (0.30 ≥ 0.25) — so this single draw distinguishes applied-vs-ignored. SCENARIO B: draw = **0.40** → no drop (0.40 ≥ 0.375); this also catches over-application (additive `0.25 + 0.5 = 0.75` would wrongly drop at 0.40). FAIL: SCENARIO A does not drop (multiplier ignored); SCENARIO B drops (multiplier over-applied). *Outcome-fact keys are plain strings; multiplier application is identical to break-event keys. The multiplier is **×1.5 = `MULTIPLIER_FLOOR`** — a shippable, floor-compliant value (the prior ×1.4 was sub-floor and un-authorable). `0.25 × 1.5` is exactly 0.375 in IEEE 754 (`0x1.8p-2`); draws 0.30/0.40 need no epsilon.*

**AC-DS-26** (BLOCKING): `drop_enabled` gates the pity update — negative AND positive paths. SCENARIO A (negative): `forge_core` with `drop_enabled = false` and `break_pity_counter = 3`; qualifying break `core_broken` fired; WHEN VICTORY resolved → counter stays **3**; no instance emitted; RNG not consumed for this part. SCENARIO B (**positive companion — the discriminator**): the *same* `forge_core` fixture but `drop_enabled = true`, `break_pity_counter = 3`, same qualifying break, RNG draw **0.60** (> 0.5 effective break rate → roll fails); WHEN VICTORY resolved → counter increments to **4**; no instance emitted (roll failed). FAIL: A → 4 (pity update runs before the `drop_enabled` check); **B stays at 3** (this catches an implementation that omits the pity increment *entirely* — Scenario A alone passes trivially for such a bug because the counter never advances either way). *The A/B pair proves the counter advances iff `drop_enabled`, not that pity was skipped by accident.*

**AC-DS-27** (BLOCKING): Phase 6 output list contract. GIVEN pool with `servo_arm` (Rare 0.25), no conditions, draw **0.20** (< 0.25). WHEN VICTORY resolved. THEN resolution returns a list containing exactly one `PartInstance{part_id: 'servo_arm', upgrade_tier: 0}`. FAIL: list is null or empty; list contains wrong part_id; tier ≠ 0. *Phase 6 output contract is testable independently of Combat UI.*

**AC-DS-31** (BLOCKING): Salvage Beacon injection (Rule 12a). GIVEN a Rare part base 0.25, no conditions. SCENARIO A (**Beacon on VICTORY**): `beacon_used_this_battle = true`; effective rate = `clamp(0.25 × 2.0) = 0.50`; draw **0.40** (< 0.50) → drops, and `beacon_drop_multiplier_applied == true`. Discriminator: a no-injection impl uses 0.25 and does **not** drop at 0.40 (0.40 ≥ 0.25). SCENARIO B (**flee — no injection**): `beacon_used_this_battle = true`, outcome `FLED` → resolution awards nothing, `beacon_drop_multiplier_applied == false` (Rule 1 victory-only). SCENARIO C (**clamp**): Common base 0.70 with Beacon → `clamp(0.70 × 2.0) = 1.0` (guaranteed). SCENARIO D (**pity-guaranteed ignores Beacon**): a pity-guaranteed part with Beacon active drops exactly once and the Beacon multiplier is not applied to a rate (guarantee is pre-roll, Rule 12b). `0.25 × 2.0 = 0.5` and `0.70 × 2.0 = 1.4→clamp 1.0` are exact in IEEE-754 — no epsilon. FAIL: A doesn't drop at 0.40 (injection missing); B applies the multiplier or awards on flee; the Beacon boosts the *consumable* channel; D double-drops or applies the multiplier to a guaranteed part. **Test type**: Unit (injected seeded RNG + battle-context stub exposing `beacon_used_this_battle`).

### Gated (numbered) — release-blocking

**AC-DS-28** (GATED → BLOCKING once Save/Load exists; **release-blocker — do not ship without this passing**): pity-counter persistence across save/load, including the post-reload guarantee boundary. Integration test. GIVEN `pity_credit['delta_core'] = 72` (Prototype, 3 conditions, threshold 75) and `break_pity_counter['forge_core'] = 7` (Boss-grade, threshold 8); WHEN the game serializes state, tears down the DropSystem, and reloads from the saved data. THEN (a) both maps reload **identical** — `pity_credit['delta_core'] == 72` AND `break_pity_counter['forge_core'] == 7`; (b) a subsequent failing optimal attempt (`c = 3`) on `delta_core` advances to **75** (72 + 3, `+= c` from the restored value, not from 0), and a failing qualifying break on `forge_core` advances to **8**; (c) **the next qualifying attempt on each then fires the guarantee** — `delta_core` at 75 → guaranteed drop → 0, `forge_core` at 8 → guaranteed drop → 0 — proving the reloaded counters preserve pity-boundary semantics, not just their integer values. FAIL: either counter reloads as 0 or a wrong value; a counter is absent from the serialized payload; the advance uses `+= 1` instead of `+= c`; the guarantee fails to fire post-reload (boundary semantics lost across serialization). *Promoted from former deferred item AD-2. Non-persistence silently defeats both pity systems (every session resets the bad-luck protection), so this is a hard release gate. Unblocks the moment the Save/Load GDD defines the serialization interface for the two counter maps (see Dependencies → Save/Load).*

### Deferred (gated on Not-Started systems)

- **AD-1 — Outcome-fact provenance** (R3, OQ-DS-2): integration test — verify TBC emits outcome-fact keys (`defeated_by_thermal`, `zero_defeats`, `no_repairs_used`, `flawless`) to the Drop System's fired-condition set with the correct string values. *Unblocks when OQ-DS-2 interface is defined. Unit-testable multiplier-application half promoted to AC-DS-25 (BLOCKING).*
- **AD-2 — Pity persistence** (R6/R7): **promoted to the numbered gated AC-DS-28** (release-blocker). See "Gated (numbered)" above — no longer a loose deferred footnote.
- **AD-3 — Loot-screen report** (Phase 6): *unblocks when Combat UI is designed. Note: Drop System's output list contract is now covered by AC-DS-27; this tests UI rendering.*
- **AD-4 — Player scrap action** (R9): *unblocks when Inventory is designed.*
- **AD-5 — Part-Break contract** (R5/R7, OQ-DS-1): validate break-event keys match exactly. **Part-Break Approved 2026-07-11 — contract ratified (deterministic break, no `P(break fires)`).** This AC is now authorable against Part-Break's emitted vocabulary; it stays *gated* only on both systems being implemented so the key-match can be integration-tested. A vocabulary mismatch still produces silent multiplier loss (EC-DS-03 behavior), not a crash — which is exactly why the key-match AC exists.*

### EC↔AC Cross-Check

EC-DS-01→AC-DS-05 · EC-DS-02→AC-DS-06 · EC-DS-03→AC-DS-07 · EC-DS-04→AC-DS-03 · EC-DS-05→AC-DS-09 · EC-DS-06→AC-DS-10 · EC-DS-07→AC-DS-02 · EC-DS-08→AC-DS-08 · EC-DS-09→AC-DS-01. **All 9 ECs covered.**

### Summary

**29 BLOCKING unit + 1 gated (AC-DS-28, release-blocker) + 4 deferred** (AD-1,3,4,5; AD-2 promoted to AC-DS-28; AD-1 unit-half at AC-DS-25). Coverage: R1 (02,11), R2 (08,12), R3 (23,25), Formula 3/R4 (03,05,07,23), R5 (07,22), R6/DS-2 (13,14,15,24,29 — credit threshold, zero-cond no-credit, reset, per-ID, partial-credit `+= c`), R7/DS-3 (09,16,17,24,30 — no-credit, boundary, increment, per-ID, natural-drop reset), R8 (01,20,27), R9 (19), R10 (10,18,21), DS-1 boundary (04), drop_enabled pity (26), outcome-fact multipliers (25), pity persistence (28, gated).

**Known coverage gaps (not blocking this GDD) — all content-validation-time or gated, none runtime-untested:**
- Pity save/load persistence → now the numbered gated **AC-DS-28** (Save/Load Not Started — release blocker).
- `MULTIPLIER_FLOOR` (Rule 5a) has **no Drop System runtime AC** — it is a content-validation authoring rule (enforced by Enemy DB / Part DB content validation at author time), the same handling as the pool cap. A future QA tester should not hunt for a runtime check.
- Pity calibration floors (Prototype `drop_conditions` ≥ ×3.0; Boss-grade break ≥ ×500) are **content-validation rules owned by Part DB** (the ×500 floor is already Part DB AC-11), not Drop System runtime ACs — see Pity Calibration Authoring Rules.
- Pool cap (≤2 WILD / ≤3 BOSS) has no runtime AC — Enemy DB authoring constraint, enforced at content time only.

**GDScript testability constraints:** inject the RNG (no module-level singleton); assert floats with `<1e-9`; explicitly sort pool IDs ascending before iterating (Dictionary iterates in insertion order).

## Open Questions

| # | Question | Owner | Impact |
|---|----------|-------|--------|
| OQ-DS-1 | ✅ **RESOLVED 2026-07-11.** Part-Break (Approved) ratified the contract: break is **deterministic** (no `P(break fires)` term — pool depletion guarantees the break, DB3 dissolved), and it emits `<region>_broken` / `all_boss_parts_broken` into TBC's `fired_break_events`. Rule 5/7 are no longer provisional. Boss-grade acquisition math simplifies — the only randomness is DS-1's drop roll (bounded by DS-3 pity); the break is a certainty the player controls. Residual work: the key-match validation (AD-5) is an integration test gated on both systems shipping. | Part-Break GDD | Closed |
| OQ-DS-2 | **"Outcome fact" conditions provenance.** The non-break conditions (`defeated_by_thermal`, `zero_defeats`, `no_repairs_used`, `flawless`) need a computed source — TBC must expose them to the Drop System via the `battle_ended` payload or a companion interface. **TBC GDD needs errata** to add this interface obligation. The Drop System unit test for multiplier application is already covered (AC-DS-25, BLOCKING); what is deferred is TBC's end of the wire. | TBC GDD (errata needed) + TBC ↔ Drop interface | Rule 3 condition assembly is incomplete for non-break conditions until the interface is defined; flawless/zero-defeat style conditions can't fire |
| OQ-DS-3 | **Designs (Alpha).** The `Design` drop type + fabrication economy (currency + materials) is reserved (Rule 11) but unspecified. | Blueprint Crafting GDD (Alpha) | None in MVP — reserved only |
| OQ-DS-4 | **Inventory cap / batch-scrap UX.** Parts inventory is unbounded in MVP (EC-DS-09); a future cap/overflow policy and the scrap UX are Inventory's. | Inventory GDD | Low in MVP — unbounded is acceptable at 2-boss scope |
| OQ-DS-5 | **Scrap economy validation (assumptions A1–A3).** The rederived faucet (central ~1,840; ~1,555–2,125 Scrap band, back-loaded game-thirds view ~1,565 at the floor) vs full 3-Symbot priority sink (~3,000) targets mild scarcity, but rests on design-time assumptions: battle volume (~200 victories), per-victory yield, and the drop-absorption rates (Common 75% arc-average / Rare 50% / Prototype 25% / Boss-grade 0%). **Watch criteria at playtesting:** (a) actual battle count and absorption behavior vs A1/A3 — if absorption runs high, faucet approaches the sink and scarcity softens; if it runs low the game-thirds ~1,565 floor is the real outcome; (b) <3 Symbots → Scrap saturates early (check upgrade choices stay meaningful past hour 5); (c) >3 Symbots → scarcity extends; (d) **early-game timing** — does the player make their first upgrade before hour 3? (the game-thirds sketch assumes ~300 Scrap in hours 1–3 at ~15% Common absorption; if real early absorption is near 0%, the upgrade hook is delayed); (e) **Prototype saturation** — with only ~1–2 distinct Prototypes acquired over the arc, at what hour does the player exhaust unique-Prototype hunt goals? If before hour 7, MVP may need an additional Prototype part or an Alpha teaser to keep the Prototype hunt alive. | Playtesting + Workshop/Inventory GDD (must fix total Symbot count & upgrade-cost curve) | Economy model precision; mild scarcity may break at extreme Symbot counts, off absorption assumptions, or early-timing skew |
| OQ-DS-7 | **Consumable drop-channel frequencies (Consumable Database erratum, Part B — OPEN).** Rule 12 defines the consumable channel *structure* (a separate, level/rarity-scaled, victory-only roll, not Beacon-boosted) but **not the numbers**: the per-rarity base consumable drop rates and how enemy level/rarity scale them. This is a balance decision that sets (a) the post-MVP sell-faucet magnitude (Consumable Tuning Knob warning 3, the ~20%-of-arc ceiling), and (b) the Beacon-accrual rate that the Consumable GDD's "~2:1 self-replenish" claim depends on — economy review flagged that claim as *contingent* until this is set. Must be set against the same ~1,840-central Scrap faucet model (the consumable channel is a **new faucet** and must not silently break the mild-scarcity target). Proposed approach when tackled: a small per-fight consumable-drop probability with a rarity split mirroring parts (Common-heavy), tuned so a RARE consumable (incl. Beacon) accrues at a rate keeping Beacon drain ≥ ~2:1. | Economy decision (Drop System) — set via a focused pass (`/design-system` or economy-designer) + Consumable OQ-CD-2 | Balances the whole consumable layer + validates the Beacon economy; nothing else in MVP blocks on it (drops-only, no shops) |
| OQ-DS-6 | **Defeat-after-break — RESOLVED (accepted by design, 2026-07-11).** Rule 1 (victory-only) means a player who fires break events then loses gets zero drops and zero pity progress. This was reviewed as a possible break-avoidance trainer in high-risk fights; the decision is to **accept victory-only as final** — drops and pity are rewards for *winning the harvest*, and adding partial credit on defeat would blur the win/loss line and complicate both this system and Part-Break. No Part-Break DB3 obligation is imposed. **Residual playtest watch (advisory, non-blocking):** if playtesting shows players systematically disengage from break targeting in dangerous fights, revisit as a *combat difficulty / risk-reward* tuning question, not a drop-credit change. | Resolved — Drop System | Accepted by design; residual watch is advisory only |
