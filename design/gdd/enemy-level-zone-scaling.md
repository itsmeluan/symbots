# Enemy Level & Zone Scaling

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 5 (The World Is a Workshop), Pillar 2 (Every Battle Has a Harvest Goal)

## Overview

The Enemy Level & Zone Scaling system is the **world side of the Level Backbone**: it defines what `level` means for enemies and zones, and wires enemy level to two downstream rewards — XP and drop quality. Every enemy carries a manually-authored `level` integer (the label/anchor model — level classifies the enemy's power tier, it does not generate stats by formula). Every zone carries a `[enemy_level_floor, enemy_level_roof]` band; enemies spawned in that zone must have levels within the band. The Zone & World Map's `difficulty_band` label (EARLY/MID/LATE/ENDGAME) maps to a concrete level range defined here. On the reward side, a defeated enemy's level feeds CP-F4 to produce its `xp_value`, and higher-level enemies raise the base rarity-odds for part drops — a hard fight in a dangerous zone is more likely to yield Rare components than an easy fight in an early zone. This system owns no runtime logic; it owns authoring rules, content validation constraints, and the data fields that four existing systems (Enemy Database, Encounter Zone, Zone & World Map, Drop System) each incorporate as errata.

## Player Fantasy

The player never thinks "I'm in the level 3–5 zone." They think: *"That Crawler was a real fight. But I got two Rare drops from it — the Servo Arm I've been chasing."*

That is the two-part fantasy this system exists to support.

**The danger that means something:** A zone labeled EARLY is a warm-up. When the player pushes into a zone where the enemies are visibly tougher — more aggressive, with stats that punish underprepared builds — the environment itself is communicating "you should earn your place here." The world has teeth. Level is the measurement of those teeth.

**The reward that matches the risk:** Higher-level enemies drop parts more likely to be Rare. This is not a guarantee — a player who fights BOSS-tier enemies without a targeted break strategy still earns XP and might earn a Common. But a player who fights harder enemies well — breaking the right regions, using effective types — is rewarded with not just better XP but better drop odds. Risk and reward are coupled through the same level number.

**What to avoid:** Never let level become the reason a player grinds. If reaching the next zone requires "getting your team to level X," the system has become a treadmill. The player should advance because they have the parts and the build — and their cores' levels are a byproduct of the fights they had to have anyway to get those parts. Level is the stage. The workshop wins the fight.

**Ownership note (joint fantasy delivery):** the two halves of this fantasy have different owners. The *danger* half is delivered by the Enemy Database's EDB-2 stat calibration — this system's `level` field only labels the danger; it does not generate it (Rule 1). This system directly owns the *reward* half (DS-F-LEVEL Rare scaling). For BOSS fights specifically, the reward-risk coupling is skill-expression, not zone-advancement: Boss 1's differentiated loot is entirely break-gated (Rule 5 note) — a player who wins without executing the break earns the same Rare odds as a WILD-mid fight. The Combat UI's pre-fight break-requirement label (Drop System UI contract) is therefore load-bearing for this fantasy: without it, a no-break boss win with no Boss-grade drop reads as bad RNG rather than a missed break, undermining Pillar 2's visible tilt.

> *(Note: creative-director not consulted — Lean mode. Review Section B manually before production.)*

## Detailed Rules

### Core Rules

**Rule 1 — Enemy `level` field (label/anchor model).** Each entry in the Enemy Database carries a `level: int` field. This field is manually authored by content creators; it does not generate stats by formula. Stats are still authored per the EDB-2 TTK calibration. The `level` field serves three explicit purposes: (1) zone-band membership validation (content authors must place each enemy in a zone whose `[enemy_level_floor, enemy_level_roof]` includes its level); (2) XP reward derivation (CP-F4 reads `enemy.level` to compute `xp_value`); (3) drop rarity scaling (Rule 5). `MAX_ENEMY_LEVEL = 10`, matching `MAX_CORE_LEVEL`.

**Authoring guide (not validated — EDB-2 TTK is the normative stat gate via AC-ED-14):**

| Level | Expected EDB-2 class | Notes |
|-------|---------------------|-------|
| 1–2 | WILD-early (structure 60–88, A_cal 35) | Intro enemies; fast fights |
| 3–5 | WILD-mid (structure 90–160, A_cal 53) | Mid-tier; real build tests begin |
| 5–7 | BOSS (structure 364–594) | Boss 1 at 5; Boss 2 at 6 in MVP |
| 7–9 | BOSS (Alpha zone content) | Higher structure/armor within EDB-2 bounds |
| 10 | BOSS (ENDGAME content) | Full Vision cap |

Level 5 is shared: a WILD-mid enemy at level 5 and Boss 1 at level 5 may coexist in the same zone — enemy_class and level are orthogonal.

---

**Rule 2 — `xp_value` field (stored-equals-derived).** Each Enemy Database entry also carries `xp_value: int`, derived from CP-F4:

`xp_value = (XP_BASE + enemy_level × XP_PER_ENEMY_LEVEL) × role_multiplier`

where `role_multiplier` = 1 (WILD) or `BOSS_XP_MULTIPLIER` = 2 (BOSS). This value is **stored on the enemy entry** (not computed at runtime) so that Core Progression lookups are O(1). The stored value must equal the CP-F4 derivation for the enemy's authored `level` — the same stored-equals-derived validation pattern as EDB-1's `break_hp` (AC-ELZS-02). If CP-F4 constants are retuned, all `xp_value` fields must be recomputed and re-stored.

---

**Rule 3 — Zone level band (Encounter Zone erratum).** Each Encounter Zone entry gains two new fields:

| Field | Type | Constraint |
|-------|------|-----------|
| `enemy_level_floor` | int | ≥ 1; ≤ enemy_level_roof |
| `enemy_level_roof` | int | ≥ enemy_level_floor; ≤ MAX_ENEMY_LEVEL |

Content validation: every enemy in the zone's spawn pool must have `level ∈ [enemy_level_floor, enemy_level_roof]`. An enemy whose `level` falls outside the band is a content error (BLOCKING) — it must be moved to the correct zone or have its level re-authored.

**MVP zone definition:** `enemy_level_floor = 1`, `enemy_level_roof = 6`, `difficulty_band = EARLY`.

---

**Rule 4 — `difficulty_band` ↔ level range (Zone & World Map guideline).** The Zone & World Map's `difficulty_band` label maps to a level range according to the zone's **entry experience** — the floor of enemies a player first encounters, not the zone's ceiling. A zone whose entry is level-1 enemies remains EARLY even if it contains a level-6 boss (the boss is an earned milestone, not the introduction).

| difficulty_band | Level floor guideline | Interpretation |
|----------------|----------------------|----------------|
| EARLY | 1–3 | Starter zone; builds viable at any rarity |
| MID | 3–6 | Mid-game; Rare parts more available; demands solid builds |
| LATE | 6–9 | Alpha zones; high stats; demands strong builds |
| ENDGAME | 8–10 | Full Vision cap content; max-level enemies |

This mapping is an authoring guideline and an ADVISORY validation rule, not a hard constraint. The Zone & World Map's `difficulty_band` honesty warning applies: the label must genuinely reflect the player's first encounter, not aspirational difficulty.

---

**Rule 5 — Level → drop rarity-odds scaling (Drop System erratum).** Higher-level enemies receive a `level_rarity_mult` factor added to the Drop System's effective drop rate product. This factor is a lookup over (level_band, rarity):

`level_band(level)`:
- EARLY: level ∈ [1, LEVEL_BAND_MID_FLOOR − 1] = [1, 2]
- MID: level ∈ [LEVEL_BAND_MID_FLOOR, LEVEL_BAND_HIGH_FLOOR − 1] = [3, 5]
- HIGH: level ∈ [LEVEL_BAND_HIGH_FLOOR, MAX_ENEMY_LEVEL] = [6, 10]

`LEVEL_RARITY_MULTS[level_band][rarity]`:

| level_band | Common | Rare | Boss-grade | Prototype |
|-----------|--------|------|------------|-----------|
| EARLY | 1.0 | 0.5 | 1.0 | 1.0 |
| MID | 1.0 | 1.0 | 1.0 | 1.0 |
| HIGH | 1.0 | 1.5 | 1.0 | 1.0 |

Only Rare is scaled — Common must stay reliable for floor loot at all levels; Boss-grade is already conditioned by the ×500 break multiplier system; Prototype stays at its authored 0.05.

**Boss 1 level-band note:** Boss 1 (level 5) sits in the MID band (×1.0 Rare mult) — identical to any WILD-mid enemy at levels 3–5. Its loot differentiation over WILD-mid enemies is Boss-grade break drops (the ×500 condition multiplier on the break region), not Rare-band elevation. This is intentional: the level band rewards zone advancement; break execution rewards combat skill. Both are required for best drops — they are orthogonal multipliers in the DS-F-LEVEL product.

The amended Drop System effective-rate formula (DS-F-LEVEL — see Formulas):
`effective_drop_rate(p) = clamp(base_drop_rate[rarity(p)] × level_rarity_mult × Π(condition_multipliers) × beacon_factor, 0, 1)`

where `level_rarity_mult = LEVEL_RARITY_MULTS[level_band(enemy.level)][rarity(p)]` and `beacon_factor = BEACON_MULTIPLIER` if `beacon_used_this_battle` else `1.0`.

---

**Rule 6 — `MAX_ENEMY_LEVEL` cap.** No enemy entry may carry `level > MAX_ENEMY_LEVEL = 10`. This matches `MAX_CORE_LEVEL` — the hardest endgame enemies are on par with a fully-leveled core. Content validation fails any entry violating this (BLOCKING).

---

### States and Transitions

This system has no runtime states. Enemy levels and zone bands are static data authored at content-creation time. The level bracket of a zone is fixed; enemies within it are constant. The only "state change" is at content-authoring time when a zone or enemy entry is revised — in which case the content validation rules (Rules 1–6) must be re-run.

---

### Interactions with Other Systems

| System | Direction | Change delivered |
|--------|-----------|-----------------|
| **Enemy Database** (upstream — amended) | ← errata | Add `level: int` and `xp_value: int` to every enemy entry schema. Authoring guide (Rule 1 table). `xp_value` stored-equals-derived from CP-F4 (Rule 2, AC-ELZS-02). |
| **Encounter Zone** (upstream — amended) | ← errata | Add `enemy_level_floor: int`, `enemy_level_roof: int` to zone schema (Rule 3). Content validation: spawn-pool enemies must be in-band (AC-ELZS-05). |
| **Zone & World Map** (upstream — amended) | ← errata | Map `difficulty_band` → level range per Rule 4 table; authoring guideline + ADVISORY validation. |
| **Drop System** (upstream — amended) | ← errata | Insert `level_rarity_mult` factor into the DS-1 product (Rule 5, DS-F-LEVEL). LEVEL_RARITY_MULTS table drives the factor. |
| **Symbot Core Progression** (downstream) | → supplies | `enemy.level` is the `enemy_level` input to CP-F4; `enemy.xp_value` is passed in the `battle_ended` payload per the TBC erratum. This system resolves OQ-CP-1 (MVP zone level range = [1, 6]) and OQ-CP-2 (label model). |

## Formulas

### DS-F-LEVEL — Level-Scaled Drop Rate (amends Drop System DS-1)

This formula amends the Drop System's DS-1 effective-rate product. It inserts a `level_rarity_mult` factor derived from the enemy's level band. The amendment is additive — it does not replace any existing factor; it adds one.

**Formula:**
`effective_drop_rate(p) = clamp(base_drop_rate[rarity(p)] × level_rarity_mult × Π(condition_multipliers) × beacon_factor, 0, 1)`

**level_band derivation (sub-function):**
```
level_band(level):
  if level < LEVEL_BAND_MID_FLOOR:  return EARLY   # [1, 2]
  if level < LEVEL_BAND_HIGH_FLOOR: return MID      # [3, 5]
  return HIGH                                        # [6, MAX_ENEMY_LEVEL]
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `base_drop_rate[rarity(p)]` | — | float | {0.70, 0.25, 0.05, 0.001} | Per-rarity base rate; owned by Part DB. Common/Rare/Prototype/Boss-grade. |
| `level_rarity_mult` | — | float | {0.5, 1.0, 1.5} | Band × rarity lookup from LEVEL_RARITY_MULTS table below |
| `Π(condition_multipliers)` | — | float | [1.0, ∞) | Product of all fired drop-condition multipliers (existing DS-1 factor) |
| `beacon_factor` | — | float | {1.0, 2.0} | BEACON_MULTIPLIER if beacon_used_this_battle, else 1.0 (existing CD-4) |
| `LEVEL_BAND_MID_FLOOR` | — | int | 3 | Level at which MID band begins |
| `LEVEL_BAND_HIGH_FLOOR` | — | int | 6 | Level at which HIGH band begins |
| `effective_drop_rate(p)` | *(output)* | float | [0.0, 1.0] | Clamped effective probability that part p drops |

**LEVEL_RARITY_MULTS table:**

| level_band | Common | Rare | Boss-grade | Prototype |
|-----------|--------|------|------------|-----------|
| EARLY (L1–2) | 1.0 | **0.5** | 1.0 | 1.0 |
| MID (L3–5) | 1.0 | **1.0** | 1.0 | 1.0 |
| HIGH (L6+) | 1.0 | **1.5** | 1.0 | 1.0 |

Only Rare is scaled. Common stays reliable for floor loot at all tiers. Boss-grade is already gated by ×500 break multipliers. Prototype stays at 0.05 across all bands. **Prototype's all-1.0 row is load-bearing for DS-2:** the `N_PROTO_PITY` calibration assumes an unscaled 0.05 Prototype base — changing any Prototype mult away from 1.0 requires re-deriving `N_PROTO_PITY` for the affected band (non-obvious cross-system dependency; do not tune casually).

**Output range:** `[0.0, 1.0]` — clamped. Pure float product + clamp; NO floor/ceil/epsilon. This is the same float pattern as CD-4 (Beacon) and CD-5 (Jammer/Lure), both approved. No python3 scan required.

**Worked examples (discriminating — show EARLY/MID/HIGH Rare spread):**

| Scenario | base | level_mult | Π(cond) | beacon | raw | clamped |
|----------|------|-----------|---------|--------|-----|---------|
| Rare, EARLY, one ×1.5 cond, no beacon | 0.25 | 0.5 | 1.5 | 1.0 | 0.1875 | **0.1875** |
| Rare, MID, one ×1.5 cond, no beacon | 0.25 | 1.0 | 1.5 | 1.0 | 0.375 | **0.375** |
| Rare, HIGH, one ×1.5 cond, no beacon | 0.25 | 1.5 | 1.5 | 1.0 | 0.5625 | **0.5625** |
| Rare, HIGH, one ×1.5 cond, beacon active | 0.25 | 1.5 | 1.5 | 2.0 | 1.125 | **1.0 (clamped)** |
| Common, HIGH, ×2.0 cond, beacon active | 0.70 | 1.0 | 2.0 | 2.0 | 2.80 | **1.0 (clamped — pre-existing, no change)** |

The three Rare rows are the discriminating cases: 0.1875 ≠ 0.375 ≠ 0.5625 — an implementation that ignores `level_rarity_mult` returns the MID value (0.375) for all three, failing EARLY and HIGH tests.

---

### CP-F4 Constants (ratified — formula owned by symbot-core-progression.md)

The provisional constants `XP_BASE = 35` and `XP_PER_ENEMY_LEVEL = 10` are **now confirmed** for the MVP zone level range [1, 6]. OQ-CP-1 is **RESOLVED** by this pass.

| Enemy | Level | xp_value |
|-------|-------|----------|
| WILD-early | 1 | 45 |
| WILD-early | 2 | 55 |
| WILD-mid | 3 | 65 |
| WILD-mid | 4 | 75 |
| WILD-mid | 5 | 85 |
| Boss 1 (BOSS) | 5 | 170 |
| Boss 2 (BOSS) | 6 | 190 |
| *WILD at cap (ENDGAME, no MVP content)* | 10 | 135 |
| *BOSS at cap (ENDGAME, no MVP content)* | 10 | 270 |

The two level-10 rows are the formula's registered upper boundary (`MAX_ENEMY_LEVEL`) — outside the MVP zone band `[1, 6]` but required reference values for any future ENDGAME content authoring and for full-range validator fixtures.

**Pacing confirmation:** Level 3 reached in ~4–5 WILD fights; Level 5 reached in ~10–12 total fights (including Boss 1). This confirms "level-up as a side-effect of part hunting."

**Anti-grind guard on the ×2 BOSS multiplier:** boss refights are rate-limited by the Encounter Zone's delta re-gate (Rule 9/8a — each boss re-challenge requires fresh WILD wins), so farming a boss for 2× XP is never an available optimal loop; the multiplier prices the fight's difficulty, not a farmable faucet.

## Edge Cases

**EC-ELZS-01 — Enemy `level` missing or zero.** *If* an Enemy Database entry has no `level` field or `level == 0`: content validation **fails** (BLOCKING). Enemies must be explicitly leveled — 0 is not a valid level (minimum is 1). *Verified by AC-ELZS-01.*

**EC-ELZS-02 — Enemy `level` exceeds MAX_ENEMY_LEVEL.** *If* any enemy entry has `level > MAX_ENEMY_LEVEL (10)`: content validation **fails** (BLOCKING). *Verified by AC-ELZS-01.*

**EC-ELZS-03 — Enemy `level` outside zone's `[floor, roof]` band.** *If* an enemy in a zone's spawn pool has `level < enemy_level_floor` or `level > enemy_level_roof`: content validation **fails** (BLOCKING) — the enemy is misplaced. The author must revise the enemy's level or move the enemy to the correct zone. *Verified by AC-ELZS-05.*

**EC-ELZS-04 — `xp_value` stored ≠ CP-F4 derived.** *If* an enemy entry's stored `xp_value` does not equal `(XP_BASE + level × XP_PER_ENEMY_LEVEL) × role_multiplier`: content validation **fails** (BLOCKING). This drift occurs when CP-F4 constants are retuned without re-deriving stored values. Follows the same stored-equals-derived pattern as EDB-1's `break_hp`. *Verified by AC-ELZS-02.*

**EC-ELZS-05 — `enemy_level_floor > enemy_level_roof`.** *If* a zone entry has `enemy_level_floor > enemy_level_roof`: content validation **fails** (BLOCKING). An inverted band classifies no valid enemy level — authoring error. *Verified by AC-ELZS-03.*

**EC-ELZS-06 — Zone spawn pool has no in-band enemies.** *If* a zone's spawn pool is non-empty but every enemy fails the `level ∈ [floor, roof]` check: content validation **fails** (BLOCKING). A zone with no spawnable in-band enemies cannot run encounters. *Verified by AC-ELZS-05 combined with Encounter Zone EC-EZ-01.*

**EC-ELZS-07 — Rare + HIGH band + Beacon + strong conditions clamps to 1.0.** *If* a Rare part drops from a HIGH-band enemy (L6+) while a Salvage Beacon is active and one or more strong condition multipliers are fired: `0.25 × 1.5 × 1.5 × 2.0 = 1.125` → clamped to 1.0 (guaranteed drop). This is **expected behavior** — the full skill expression (right zone + right break + Beacon) earns the guaranteed drop. The clamp handles it correctly. No fix needed. *Verified by AC-ELZS-10.*

**EC-ELZS-08 — Level 9–10 benched core earns 0 bench XP in MVP zone.** *If* a benched core is at level ≥ 9 while the MVP zone's `enemy_level_roof = 6`: `9 >= 6 + 3 (BENCH_LEVEL_LEAD_CAP)` → bench XP is 0. This is **intentional** — the bench-lead-cap guard prevents free power-leveling of veteran cores in low-level zones. In the single-zone MVP, a level 9–10 core must be actively fielded to gain XP. *Verified by Core Progression AC-CP-08.*

**EC-ELZS-09 — `difficulty_band` label inconsistent with `enemy_level_floor`.** *If* a zone's `difficulty_band` is inconsistent with the Rule 4 floor-based guideline (e.g., `difficulty_band = EARLY` but `enemy_level_floor = 7`): content validation **warns** (ADVISORY). Mismatched labels can mislead players about zone danger. *Verified by AC-ELZS-06.*

**EC-ELZS-10 — `level_band` boundary: `level == LEVEL_BAND_MID_FLOOR` exactly.** *If* `enemy.level == 3 (LEVEL_BAND_MID_FLOOR)`: `level_band = MID` (not EARLY). A `>` vs `>=` boundary error here silently misclassifies L3 enemies as EARLY, halving their Rare drop multiplier. *Verified by AC-ELZS-09.*

**EC-ELZS-11 — Zone band fields missing or out of global range.** *If* a zone entry lacks `enemy_level_floor`/`enemy_level_roof`, or `floor < 1`, or `roof > MAX_ENEMY_LEVEL`: content validation **fails** (BLOCKING). *Verified by AC-ELZS-04.*

**EC-ELZS-12 — Zone spawn pool is empty.** *If* a zone entry has a valid level band (`enemy_level_floor ≤ enemy_level_roof`) but the spawn pool contains no enemy entries at all: content validation **fails** (BLOCKING). A zone with no enemies cannot run encounters. This is a distinct condition from EC-ELZS-06 (which covers a *non-empty* pool where every enemy is out-of-band); both are blocking content errors but require separate checks. *Verified by AC-ELZS-12.*

**EC-ELZS-13 — Spawn pool references a non-existent `enemy_id`.** *If* a zone's spawn pool references an `enemy_id` that does not resolve to any Enemy Database entry (authoring typo, deleted enemy): content validation **fails** (BLOCKING), naming the unresolvable ID. The validator must never skip the reference or treat the phantom enemy as in-band — fail-safe, matching Encounter Zone EC-EZ-12's broken-reference pattern. *Verified by AC-ELZS-13.*

## Dependencies

### Upstream Dependencies (what this system requires)

| System | What this system reads/amends | Hard/Soft | Status |
|--------|------------------------------|-----------|--------|
| **Enemy Database** (#2) | Adds `level: int` and `xp_value: int` to the enemy entry schema. Reads existing `enemy_class` (WILD/BOSS) as the `role_multiplier` input to CP-F4. | **Hard** — without `level`, neither XP nor drop rarity scaling can function | Approved ✓ *(erratum: add `level` + `xp_value` fields and stored-equals-derived validation)* |
| **Encounter Zone** (#7) | Adds `enemy_level_floor: int` and `enemy_level_roof: int` to the zone schema. Reads existing `terrain_patches[].subpool[].enemy_id` to validate in-band placement. | **Hard** — without zone bands, in-band validation has no reference to check against | Approved ✓ *(erratum: add two new fields + in-band content validation)* |
| **Drop System** (#8) | Amends DS-1 to insert the `level_rarity_mult` factor (DS-F-LEVEL). Reads existing `base_drop_rate[rarity]` and `Π(condition_multipliers)` and `beacon_factor`. | **Hard** — level → rarity odds scaling requires DS-1 to be amended | Approved ✓ *(erratum: DS-F-LEVEL factor insertion + LEVEL_RARITY_MULTS table)* |
| **Zone & World Map** (#12) | Adds `difficulty_band` → level range guideline. Reads existing `difficulty_band` enum (EARLY/MID/LATE/ENDGAME). | **Soft** — the guideline is advisory and does not gate any runtime behavior | Approved ✓ *(erratum: Rule 4 guideline table + ADVISORY validation)* |

### Downstream Dependents (what depends on this system)

| System | What it reads | Status |
|--------|--------------|--------|
| **Symbot Core Progression** (#10b) | Reads `enemy.level` (via `battle_ended` payload) as the `enemy_level` input to CP-F4; reads `enemy.xp_value` as the XP award amount. This system resolves OQ-CP-1, OQ-CP-2, OQ-CP-7. | Approved ✓ *(pending TBC erratum for `battle_ended` payload extension — owned by Core Progression errata pass)* |

### Bidirectionality Notes (errata obligations)

- **Enemy Database erratum**: Add `level: int` and `xp_value: int` to schema; stored-equals-derived validation (AC-ELZS-02 pattern); add "depended on by Enemy Level & Zone Scaling" to dependencies section.
- **Encounter Zone erratum**: Add `enemy_level_floor: int` and `enemy_level_roof: int` to zone schema; in-band content validation; add "depended on by Enemy Level & Zone Scaling" to dependencies section.
- **Drop System erratum**: Amend DS-1 expression to include `level_rarity_mult` factor; add LEVEL_RARITY_MULTS table to Tuning Knobs; add DS-F-LEVEL to Formulas; add "depended on by Enemy Level & Zone Scaling" to dependencies section. **Economy model re-annotation (mandatory — derivation below):** DS-F-LEVEL shifts the arc-average Rare drop rate relative to the ~0.36/victory baseline the Drop System's `≈1,840 Scrap central` model assumes (that model was derived before DS-F-LEVEL existed). The correction is derived from an explicit fight-distribution weighting over the MVP zone [1,6]:

  | Band | Fight share (weight) | Rare mult | Contribution | Weight rationale |
  |------|---------------------|-----------|--------------|------------------|
  | EARLY (L1–2) | 15% | 0.5 | 0.075 | Pacing table: player exits the EARLY band in ~4–5 fights; only early-hours wandering in L1–2 terrain sub-pools after that |
  | MID (L3–5) | 80% | 1.0 | 0.800 | Bulk of the arc — all WILD-mid content + Boss 1, spanning both boss-gate win counters (6 and 10 cumulative wins) |
  | HIGH (L6) | 5% | 1.5 | 0.075 | Boss 2 only, gated behind 10 zone wins; refights rate-limited by Encounter Zone Rule 9/8a delta re-gate |
  | **Weighted arc mult** | | | **0.95** | |

  Arc-average Rare rate: `0.36 × 0.95 ≈ 0.34 Rares/victory` (~68 Rares over the ~200-victory arc vs. 72 baseline; ~680 Rare Scrap vs. 720; revised central **~1,800 vs. 1,840** — a ~2% reduction). **Mild-scarcity band validity: ESTIMATED at the derived figure (design-time model)** — the revised central sits well inside the Drop System's mild-scarcity band (floor ~1,556). Sensitivity: doubling the EARLY share to 30% (a player who lingers in starter terrain) gives weighted mult 0.875 → ~0.315 Rares/victory → central ~1,750, still inside the band. The EARLY ×0.5 mult therefore depresses hours-1 Rare throughput *locally* (a feel concern — OQ-ELZS-4) without threatening the arc economy. Annotate the Drop System's economy model with this derivation table when applying the erratum.

  **Weight provenance (why ESTIMATED, not CONFIRMED):** the 15/80/5 shares are design-time estimates, not derived constants. The HIGH 5% assumes a small Boss 2 refight count — the Encounter Zone's delta re-gate rate-limits refights but specifies no expected count (if the real share is 2–3%, the weighted mult rises to ~0.97 — closer to baseline). The ~200-victory denominator is inherited from the Drop System's arc model; the weights are conditional on that arc length. The EARLY 15% is more likely overstated than understated (the ×0.5 mult itself pushes players out of EARLY terrain — real share plausibly 5–8%, mult ~0.975). All plausible weight errors therefore move the mult *toward* 1.0 (the looser, safer direction); the band conclusion is robust, but the point figures are estimates. Validate the actual band shares at playtest (OQ-ELZS-4 watch metrics).
- **Zone & World Map erratum**: Add Rule 4 guideline table; add ADVISORY validation; add "depended on by Enemy Level & Zone Scaling" to dependencies section.
- **No reverse dependency on Core Progression**: This system supplies level data; it does not read any Core Progression output.

## Tuning Knobs

| Knob | Type | Value | Owner | Effect / Safe guidance |
|------|------|-------|-------|------------------------|
| `MAX_ENEMY_LEVEL` | int | 10 | This system | Hard cap on any enemy's `level` field. Matches `MAX_CORE_LEVEL`. Increasing requires adding new level-band entries or extending HIGH; decreasing requires re-leveling all enemies above the new cap. MVP safe range: 10. |
| `LEVEL_BAND_MID_FLOOR` | int | 3 | This system | Level at which MID band begins (enemies at L1–(floor-1) are EARLY). Lowering broadens EARLY and shrinks MID; raising does the reverse. Safe range 2–4. At 2: EARLY is a single level (starter feel exits fast); at 4: Boss 1 sits in EARLY band territory. |
| `LEVEL_BAND_HIGH_FLOOR` | int | 6 | This system | Level at which HIGH band begins (Rare ×1.5). Aligned with the MVP zone's `enemy_level_roof`. Safe range 5–7. At 5: Boss 1 gets HIGH-tier Rare odds (may under-differentiate Boss 2); at 7: HIGH only activates in Alpha zones (no player feels it in MVP). |
| `LEVEL_RARITY_MULTS[EARLY][Rare]` | float | 0.5 | This system | Rare drop multiplier in the EARLY band. At 1.0: no farming incentive to push deeper. At 0.0: Rares cannot drop from EARLY enemies. Safe range 0.3–0.8. |
| `LEVEL_RARITY_MULTS[HIGH][Rare]` | float | 1.5 | This system | Rare drop multiplier in the HIGH band. The current value (1.5) **intentionally** triggers the guaranteed-drop cap when Beacon is active and any condition fires (`0.25 × 1.5 × 1.5 × 2.0 = 1.125 → clamped`) — this is EC-ELZS-07's expected behavior ("full skill expression earns the guaranteed drop"). The cap threshold is any `mult ≥ 1 / (0.25 × MULTIPLIER_FLOOR × BEACON_MULTIPLIER) = 1 / (0.25 × 1.5 × 2.0) = 1.333`. **Warning for tuning up:** values ≥ 2.0 (= `1 / (0.25 × BEACON_MULTIPLIER)` = `1 / (0.25 × 2.0)`) guarantee Rare with Beacon alone — no break execution required. Safe range 1.2–1.6 for intentional guarantee-via-execution; keep < 2.0 to prevent Beacon-only guarantee. |
| `XP_BASE` | int | 35 | This system (→ symbot-core-progression.md) | Flat XP floor in CP-F4. Reducing it devalues low-level enemies; raising flattens the XP gradient. Re-calibrate CP-F1 arc if changed. |
| `XP_PER_ENEMY_LEVEL` | int | 10 | This system (→ symbot-core-progression.md) | XP added per enemy level in CP-F4. Primary lever for how fast leveling tracks enemy difficulty. Safe range 7–15. The anti-grind invariant: a player should hit level 3 in ~4–5 fights, not 10+. |
| MVP zone `enemy_level_floor` | int | 1 | Content authoring | Lowest enemy level in the MVP zone. Do not raise above 2 without redesigning the tutorial encounter flow. |
| MVP zone `enemy_level_roof` | int | 6 | Content authoring | Highest enemy level in the MVP zone. Raising to 7 extends bench XP coverage to cores 1–9; the bench dead zone (EC-ELZS-08) shrinks by one level per point raised. |

**Cross-referenced knobs (owned elsewhere, affect this system):**

| Knob | Owner | Relevance here |
|------|-------|----------------|
| `BENCH_LEVEL_LEAD_CAP` | symbot-core-progression.md | Jointly determines bench dead zone with `enemy_level_roof`. Tune both together when adjusting bench coverage. |
| `BEACON_MULTIPLIER` | consumable-database.md | Stacks with `LEVEL_RARITY_MULTS[HIGH][Rare]` in DS-F-LEVEL. Tuning either affects the other's ceiling. |
| `base_drop_rate[Rare]` | part-database.md | Base rate (0.25) that `level_rarity_mult` multiplies; changes cascade across all three bands. |

## Visual/Audio Requirements

This system renders nothing and emits no signals — it is static authoring data. Its visual footprint is entirely delegated: enemy level display (Combat UI GDD), zone difficulty presentation (World Map UI GDD — `difficulty_band` badge per Zone & World Map's existing UI contract), and drop-rarity feedback (already owned by Drop System's rarity-escalated reveal direction). One direction-level note for those GDDs: **enemy level should be legible at encounter start** — the player sizing up a fight (Pillar 2's harvest decision) needs the level read-out to judge XP value and Rare-odds band without opening a menu. A small "Lv N" tag near the enemy nameplate suffices; no dedicated VFX.

## UI Requirements

Exposes only static data; contributes no screens. Consumed by:
- **Combat UI (#19):** enemy `level` displayed at encounter start and on the battle HUD ("Lv 4 Crawler"). The level tag is the player's XP/drop-band signal. **Drop-band legibility requirement:** The UI must communicate that enemy level affects Rare drop odds — not just XP value. Without this, the EARLY ×0.5 Rare penalty reads as RNG variance rather than a design gradient, misattributing outcomes and undermining Pillar 2. **Minimum bar (normative for the Combat UI pass):** a drop-band tier label AND a directional Rare indicator (e.g., "Rare ↓" / "Rare ↑") visible at encounter start — not only in the post-battle reveal. The exact visual form is delegated to the Combat UI GDD pass, but a signal below this bar (a bare color dot, a buried tooltip) does not satisfy the requirement; the Combat UI GDD should carry an ADVISORY AC verifying the signal's presence at encounter start.
- **World Map UI (#20):** `difficulty_band` label per zone (already contracted in Zone & World Map); this GDD adds the underlying level-range meaning. Optional enhancement (defer to World Map UI pass): show the zone's level band ("Lv 1–6") alongside the band label.
- **Post-battle summary (Combat UI):** `xp_value` earned is displayed per the Core Progression UI contract (per-core XP lines, bench-cap "over-level" message). No new surface added by this system.

> **📌 UX Flag — Enemy Level & Zone Scaling**: Combat UI must show enemy level at encounter start; World Map UI should surface zone level ranges. Fold these requirements into the `/ux-design` passes for those two screens — no standalone spec needed for this system. Touch-first: tap targets ≥ 44×44pt.

## Acceptance Criteria

ACs marked **BLOCKING** gate story completion. Content Validation ACs run at content-authoring time (schema/data validator); Unit ACs are automated tests. Test file locations: the two Unit ACs (09, 10) belong in `tests/unit/drop_system/` — they test the same `level_band()` / `effective_drop_rate()` functions that DS-F-LEVEL amends; enemy-side Content Validation ACs (01, 02) belong in `tests/unit/enemy_database/`; zone-side Content Validation ACs (03–06, 12, 13) belong in `tests/unit/encounter_zone/`; the Integration AC (11) belongs in `tests/integration/drop_system/`.

**AC-ELZS-01** (BLOCKING) — Enemy `level` field: present, non-zero, in-range [1, MAX_ENEMY_LEVEL]. **GIVEN** any Enemy Database entry, **WHEN** the content validator runs, **THEN** `level` is a present field, `level >= 1`, and `level <= MAX_ENEMY_LEVEL (10)`. A missing `level` field fails (BLOCKING); `level == 0` fails; `level == 11` fails; `level == 10` **passes**. Boundary discriminator: an implementation using `> 9` incorrectly rejects level 10. *(Rule 1; Rule 6; EC-ELZS-01; EC-ELZS-02)* **Test:** Content Validation.

**AC-ELZS-02** (BLOCKING) — `xp_value` stored equals CP-F4 derived, full roster. **GIVEN** any Enemy Database entry with authored `level` and `enemy_class` (WILD or BOSS), **WHEN** the content validator runs, **THEN** `stored_xp_value == (XP_BASE + level × XP_PER_ENEMY_LEVEL) × role_multiplier` where `XP_BASE = 35`, `XP_PER_ENEMY_LEVEL = 10`, WILD `role_multiplier = 1`, BOSS `role_multiplier = 2`. Concrete checks: WILD level 1 → `xp_value == 45`; WILD level 3 → `xp_value == 65`; BOSS level 5 → `xp_value == 170`; BOSS level 6 → `xp_value == 190`; **BOSS level 3 → `xp_value == 130`** — the anti-hardcoding discriminator: an implementation that stores a lookup table of the four MVP-roster values instead of evaluating the formula fails at this fixture, because no MVP enemy exists at BOSS/L3 (the fixture is a synthetic validator input). An entry storing any deviating value — including a WILD level-3 entry storing a stale `70` from a pre-retune derivation — fails (BLOCKING). (The full-roster invocation contract — the validator must sweep every entry on every content commit, not only touched entries — is a CI-configuration requirement, specified in the Errata pre-gate block, not a fixture of this AC.) *(Rule 2; EC-ELZS-04)* **Test:** Content Validation.

**AC-ELZS-03** (BLOCKING) — Zone band is non-inverted (`floor <= roof`). **GIVEN** any Encounter Zone entry, **WHEN** the content validator runs, **THEN** `enemy_level_floor <= enemy_level_roof`. `[3, 6]` passes; `[6, 3]` fails (BLOCKING); `[4, 4]` (equal values) **passes** — a single-level band is valid. An implementation using strict `<` instead of `<=` incorrectly rejects the equal-floor-roof case. *(Rule 3; EC-ELZS-05)* **Test:** Content Validation.

**AC-ELZS-04** (BLOCKING) — Zone band fields present and in global range. **GIVEN** any Encounter Zone entry, **WHEN** the content validator runs, **THEN** both `enemy_level_floor` and `enemy_level_roof` are present integer fields, `enemy_level_floor >= 1`, and `enemy_level_roof <= MAX_ENEMY_LEVEL (10)`. Missing either field fails (BLOCKING); `enemy_level_roof = 11` fails. Boundary discriminators: `enemy_level_floor = 1` **passes** (an implementation using `> 1` incorrectly rejects the global minimum); `enemy_level_roof = 10` **passes** (an implementation using `< 10` incorrectly rejects the global maximum). The MVP zone definition (`floor = 1, roof = 6`) must pass. *(Rule 3; EC-ELZS-11)* **Test:** Content Validation.

**AC-ELZS-05** (BLOCKING) — All spawn-pool enemies within the zone's level band. **GIVEN** an Encounter Zone entry with `enemy_level_floor = F`, `enemy_level_roof = R`, and a non-empty spawn pool referencing enemy entries by ID, **WHEN** the content validator resolves each referenced enemy's `level` and checks membership, **THEN** every enemy `level ∈ [F, R]` (inclusive both ends). **(A)** zone `[1, 6]`, pool levels `[1, 3, 5, 6]` → passes. **(B)** zone `[3, 6]`, pool includes a level-2 enemy → fails (BLOCKING, under-floor), identifying the out-of-band enemy. **(C)** zone `[3, 6]`, pool includes a level-6 enemy → **passes** (at-roof boundary discriminator: an implementation using strict `level < R` instead of `level <= R` incorrectly rejects this enemy — in the MVP zone that misclassifies Boss 2 itself). **(D)** zone `[1, 6]`, pool includes a level-7 enemy → fails (over-roof). **(E)** zone `[3, 6]`, pool = `[level-1 enemy, level-2 enemy]` (non-empty, **all** entries out-of-band) → fails (BLOCKING), identifying **both** enemies — discriminator for implementations that short-circuit on the first failure instead of reporting the complete error list; this is EC-ELZS-06's specific scenario. The empty-pool guard is a separate code path with its own AC — see AC-ELZS-12; ID resolution failure is covered by AC-ELZS-13. *(Rule 3; EC-ELZS-03; EC-ELZS-06)* **Test:** Content Validation.

**AC-ELZS-06** (ADVISORY) — `difficulty_band` label consistent with `enemy_level_floor`. **GIVEN** any zone entry with a `difficulty_band` value and an authored `enemy_level_floor`, **WHEN** the content validator runs, **THEN** if the floor falls outside the Rule 4 guideline range for that band — EARLY: floor ∈ [1, 3]; MID: [3, 6]; LATE: [6, 9]; ENDGAME: [8, 10] — the validator emits an ADVISORY warning naming the inconsistency. `EARLY + floor = 7` warns; `EARLY + floor = 1` is silent. The MVP zone (`floor = 1, band = EARLY`) must emit no warning. Does not block content from shipping — the validator exits 0 on ADVISORY-only findings, but **must emit the warning to stdout/log so it is visible in CI output**; a validator that suppresses the warning silently fails this AC. *(Rule 4; EC-ELZS-09)* **Test:** Content Validation.

**AC-ELZS-07** — *No separate AC.* EC-ELZS-07 (Rare + HIGH + Beacon clamp to 1.0) is expected behavior, verified inside AC-ELZS-10's clamp scenario.

**AC-ELZS-08** — *No separate AC.* EC-ELZS-08 (level 9–10 bench dead zone in MVP) is intentional behavior per the bench-lead-cap guard, verified by Core Progression **AC-CP-08**.

**AC-ELZS-09** (BLOCKING) — `level_band()` boundary discriminators + constants injection. **Injection contract:** the sub-function signature is `level_band(level: int, mid_floor: int, high_floor: int) -> StringName` — both band floors are **function parameters** (production callers pass `LEVEL_BAND_MID_FLOOR` / `LEVEL_BAND_HIGH_FLOOR` from config), not module-level literals, so tests inject alternative floors as direct arguments. **Boundary fixtures** (all direct calls): `level_band(3, 3, 6) == MID` (the discriminating input — a `>`-based implementation misclassifies L3 as EARLY, halving its Rare multiplier from 1.0 to 0.5); `level_band(2, 3, 6) == EARLY`; `level_band(6, 3, 6) == HIGH`; `level_band(5, 3, 6) == MID`. **Retune fixtures (both floors, independently):** MID floor retuned to 4 → `level_band(3, 4, 6) == EARLY` and `level_band(4, 4, 6) == MID` (an implementation with `if level < 3` baked in passes the boundary fixtures but fails here); HIGH floor retuned to 7 → `level_band(6, 3, 7) == MID` and `level_band(7, 3, 7) == HIGH` (an implementation that parameterizes the MID floor but hardcodes `6` for HIGH passes every other fixture and fails here). *(Rule 5; EC-ELZS-10)* **Test:** Unit.

**AC-ELZS-10** (BLOCKING) — DS-F-LEVEL: EARLY/MID/HIGH Rare spread, Common invariance, clamp. **GIVEN** `base_drop_rate[Rare] = 0.25`, one fired condition at ×1.5, `beacon_factor = 1.0`: enemy level 2 (EARLY, mult 0.5) → `clamp(0.25 × 0.5 × 1.5) = `**0.1875**; level 4 (MID, mult 1.0) → **0.375**; level 6 (HIGH, mult 1.5) → **0.5625**. All three asserted as a unit — an implementation ignoring `level_rarity_mult` returns 0.375 for all three, passing MID but failing EARLY and HIGH. **Common invariance:** Common (0.70) at HIGH with ×1.5 condition → `clamp(0.70 × 1.0 × 1.5) = 1.0`; Common's multiplier must be exactly 1.0 at every band. **Clamp:** Rare + HIGH + ×1.5 condition + Beacon (2.0) → `clamp(0.25 × 1.5 × 1.5 × 2.0) = clamp(1.125) = `**1.0** — the raw 1.125 must never be returned unclamped. *(Rule 5; DS-F-LEVEL; EC-ELZS-07)* **Test:** Unit.

**AC-ELZS-11** (BLOCKING) — DS-F-LEVEL amendment live in production Drop System, both directions. **GIVEN** the production `effective_drop_rate()` implementation in the Drop System (not a standalone test stub), **WHEN** called with a Rare part, one fired condition at ×1.5, and `beacon_factor = 1.0`: **(A)** with a level-2 enemy, **THEN** the function returns **0.1875** — not 0.375 (a return of 0.375 means `level_rarity_mult` was not wired; EARLY mult 0.5 not applied); **(B)** with a level-6 enemy, **THEN** the function returns **0.5625** — not 0.375. Both fixtures are required as a unit: an implementation that wires the factor only for EARLY (a hardcoded low-level special case) passes (A) but returns 0.375 on (B); an implementation ignoring the factor entirely fails both. The reduction direction (A) and the amplification direction (B) must each be confirmed live in production code. **Interface note:** the Drop System erratum story must document the production `effective_drop_rate()` interface (which class owns it; whether it takes `enemy_level` and resolves `level_rarity_mult` internally, or takes a pre-computed mult) — this AC's fixtures bind to whichever form the erratum documents. *(Rule 5; DS-F-LEVEL; Bidirectionality Notes)* **Test:** Integration — **required as a Done condition on the Drop System erratum story, not a follow-on task**; the erratum story is not Done until this integration test passes (test file `tests/integration/drop_system/`).

**AC-ELZS-12** (BLOCKING) — Empty spawn pool fails independently of the membership check. **GIVEN** an Encounter Zone entry with a valid, non-inverted level band (`enemy_level_floor ≤ enemy_level_roof`), **WHEN** the content validator runs and the spawn pool contains zero enemy entries, **THEN** validation fails (BLOCKING) — a zone with no enemies cannot run encounters. Discriminator: this is a distinct code path from AC-ELZS-05's membership loop — a membership-only validator iterating an empty pool encounters no failures and passes silently; this AC's fixture (valid band `[1, 6]`, empty pool → fail) catches exactly that implementation. *(Rule 3; EC-ELZS-12)* **Test:** Content Validation.

**AC-ELZS-13** (BLOCKING) — Unresolvable `enemy_id` in spawn pool fails, never skips. **GIVEN** an Encounter Zone entry whose spawn pool references an `enemy_id` with no matching entry in the Enemy Database (e.g., a typo — `crawler_99` where no such enemy exists), **WHEN** the content validator attempts to resolve the referenced enemy's `level` for the in-band check, **THEN** validation fails (BLOCKING), naming the unresolvable ID. The validator must never silently skip an unresolvable reference or treat it as in-band — fail-safe, matching Encounter Zone EC-EZ-12's broken-reference pattern (fail LOCKED, never fail-open). Fail fixture: zone `[1, 6]`, pool `[valid_L3_enemy, "crawler_99"]` → fails naming `crawler_99`; an implementation that filters unresolvable IDs before the membership loop passes the pool as all-in-band and is caught by this fixture. Pass fixture: zone `[1, 6]`, pool `[valid_L3_enemy, valid_L5_enemy]` (both IDs resolve) → passes with no error — an always-fail validator passes the fail fixture but is caught here. *(Rule 3; EC-ELZS-13)* **Test:** Content Validation.

**EC↔AC Cross-Check:** EC-ELZS-01 → AC-01 · EC-02 → AC-01 · EC-03 → AC-05 · EC-04 → AC-02 · EC-05 → AC-03 · EC-06 → AC-05(E) · EC-07 → AC-10 (expected behavior) · EC-08 → AC-CP-08 (delegated) · EC-09 → AC-06 · EC-10 → AC-09 · EC-11 → AC-04 · EC-12 → AC-12 · EC-13 → AC-13. **All 13 ECs covered.**

**Summary: 10 BLOCKING (including AC-ELZS-11 integration gate) + 1 ADVISORY + 2 delegated citations.**

> **Errata pre-gate (process requirement):** Four Approved GDDs receive amendments from this system. Before any implementation story for this GDD begins, confirm all four errata are applied: (1) Enemy DB — `level: int`, `xp_value: int` fields + stored-equals-derived validation; (2) Encounter Zone — `enemy_level_floor: int`, `enemy_level_roof: int` + in-band validation; (3) Drop System — DS-F-LEVEL factor + LEVEL_RARITY_MULTS table + economy-model Rare-throughput re-annotation (see Bidirectionality Notes), **plus three erratum-integrity obligations**: (3a) replace the Drop System's partially overlapping DS-1 expressions (Rule 4 base form; Rule 12a Beacon note) with **one canonical amended DS-1** — `clamp(base_drop_rate[rarity(p)] × level_rarity_mult × Π(condition_multipliers) × beacon_factor, 0, 1)` — retiring or "as amended"-labeling the partial forms; (3b) update **AC-DS-31** (Beacon fixture), which predates DS-F-LEVEL and would coincidentally pass an implementation that never wires `level_rarity_mult` — add a stated enemy level, e.g. L6/HIGH, no conditions, Beacon → `clamp(0.25 × 1.5 × 2.0) = 0.75`, draw 0.60 drops (an implementation missing the level factor returns 0.50 and does not drop); (3c) document the production `effective_drop_rate()` interface and land AC-ELZS-11's integration test as a **Done condition of the erratum story** (see AC-ELZS-11); (4) Zone & World Map — Rule 4 guideline table + ADVISORY validation. Sprint task for each errata; AC-ELZS-11 serves as the integration gate that confirms Errata 3 is live in code.
>
> **CI obligations:** (a) the content-validation runner (AC-ELZS-01/02/03/04/05/06/12/13) sweeps the **entire enemy roster and all zone entries on every content commit** — not only entries touched in the change; the full-roster sweep is what catches partial re-derivations after a CP-F4 constants retune (AC-ELZS-02's drift case). (b) This CI hook must exist **before any CP-F4 constant retune is permitted in any sprint** — until the validator is CI-gated, the stored-equals-derived pattern has no enforcement and `xp_value` drift is silent.

## Open Questions

- **OQ-ELZS-1 — Alpha zone band authoring.** Rule 4's LATE/ENDGAME rows are guidelines with no content behind them until Alpha zones are designed. Re-validate the difficulty_band mapping and the LEVEL_RARITY_MULTS HIGH values when the second zone (Vertical Slice) is authored — the ×1.5 Rare mult calibration assumes MVP's single-zone context. Note: in the MVP zone, the HIGH band is arithmetically negligible (Boss 2 only, ~5% of arc fights — see the fight-distribution derivation in Bidirectionality Notes); its real economic weight only materializes when LATE/ENDGAME zones put HIGH-band enemies in regular spawn pools. Do not tune ×1.5 against MVP data alone. *Owner: Vertical Slice zone design pass.*
- **OQ-ELZS-2 — Part stat rolls from enemy level (OQ-CP-3 residual).** OQ-CP-3 asked whether enemy level should influence dropped-part **rarity odds** and/or **stat rolls**. This GDD resolves the rarity-odds half (DS-F-LEVEL); the stat-roll half (PoE item-level model — higher-level enemies drop better-rolled instances) is **deferred** — MVP part instances have fixed stats per definition (no roll system exists). Revisit if/when a stat-roll system is designed (Alpha, alongside Part Upgrade #26). *Owner: Alpha design pass.*
- **OQ-ELZS-3 — Consumable drop channel level scaling (OQ-DS-7 coupling).** Drop System Rule 12 specifies the consumable channel is "level/rarity-scaled" but its frequencies are OPEN (OQ-DS-7). When OQ-DS-7 is resolved, the consumable channel should reuse this GDD's `level_band()` sub-function rather than inventing a second banding — one banding vocabulary across both drop channels. **Economy validity condition:** the mild-scarcity confirmation in Bidirectionality Notes is a *parts-channel-only* model; it remains valid only while the consumable channel adds no Scrap-equivalent value — which holds by construction in MVP: consumables are not scrappable, and their `sell_price` fields are authored-but-inert (Consumable DB Rule 8 — no shops, no vendor-sell in MVP). When shops ship (post-MVP) or if OQ-DS-7's resolution adds any Scrap conversion, the arc economy model must be re-derived with both channels. *Owner: OQ-DS-7 resolution pass (economy).*
- **OQ-ELZS-4 — Playtest: does the EARLY Rare penalty (×0.5) feel punishing?** The 0.5 multiplier halves Rare odds in the starter band. Intent: push players toward harder enemies for Rares. Risk: early-game Rare drought feels unrewarding before the player understands the gradient. **Watch metrics:** the penalty's primary early effect is *build quality*, not Scrap — track "Rare parts equipped by fight 10" (not Scrap-by-hour-3; early-hours Rare-sourced Scrap is near zero regardless of the multiplier because single-Symbot players keep their Rares). Also log actual fight-band shares to validate the 15/80/5 economy weights (see Weight provenance in Bidirectionality Notes). **Intervention criterion:** if >40% of playtest participants report early-game drop frustration before their first WILD-mid encounter, retune `LEVEL_RARITY_MULTS[EARLY][Rare]` upward within the 0.3–0.8 safe range. *Owner: playtest.*

**Resolved-by-this-pass log (for cross-reference):** OQ-CP-1 → RESOLVED (MVP zone [1, 6]; CP-F4 constants XP_BASE=35 / XP_PER_ENEMY_LEVEL=10 confirmed). OQ-CP-2 → RESOLVED (label/anchor model, Rule 1). OQ-CP-3 → PARTIALLY RESOLVED (rarity odds yes via DS-F-LEVEL; stat rolls deferred, OQ-ELZS-2). OQ-CP-7 → RESOLVED (bench dead zone documented as intentional, EC-ELZS-08; roof=6 keeps bench active through core level 8 = 80% of the arc).
