# Enemy Database

> **Status**: Approved
> **Review Notes**: Authored in lean mode — CD-GDD-ALIGN gate skipped; systems-designer consulted for Formulas, qa-lead for ACs. Revised 2026-07-09 per full /design-review (Session 1, 6 blockers). Re-reviewed 2026-07-09 Session 2 — 5 blockers resolved (BOSS_GRADE_BREAK_GUARANTEE 1.0→0.5, pool-size OQ5 position, AC-ED-14/05/15(c) fixes). Re-reviewed 2026-07-10 Session 3 — 5 blockers resolved (GDScript safe-access, Part DB ×500 alignment, AC-ED-07(a) counter-example, AC-ED-05(b) boundaries, floor-loot framing). Re-reviewed 2026-07-10 Session 4 — 2 blockers resolved (region_fraction schema field, floor loot rarity rule) + 18 recommended AC improvements; verdict APPROVED. See reviews/enemy-database-review-log.md.
> **Author**: Luan + Claude Code (game-designer)
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 5 (The World Is a Workshop)

## Overview

The Enemy Database is the authoritative catalog of every enemy definition in Symbots — the ~8 wild machine types and 2 bosses of the MVP zone, and every enemy added after. Each entry defines what an enemy *is*: its identity fields, its combat stat block, its Core element (read by the Damage Formula System for type effectiveness), its breakable part regions (the targets of Pillar 2's harvest decisions), and its loot table (which Sympart IDs it can drop, referencing the Part Database). It is the Part Database's sibling schema: parts define what players build with; enemies define what players hunt.

Like the Part Database, this system is read-only at runtime and stores no combat state. What an enemy's current Structure is mid-battle, which of its regions are broken, what it decided to do this turn — those belong to the Turn-Based Combat, Part-Break, and Enemy AI systems respectively. The Enemy Database only answers the question "what is a Rustcrawler?" — every downstream system (Turn-Based Combat, Encounter Zone, Drop System, Enemy AI, Damage Formula) reads from it and none may define enemy properties outside it.

## Player Fantasy

The player never thinks "the Enemy Database loaded an entry." They think: *"Crawlers drop Servo Arms when you break the arm before the kill — I need two more. There's a nest of them past the scrap dunes."* The Enemy Database is the infrastructure of the hunt plan: because every enemy has defined part regions, a defined element, and a defined loot table, every enemy in the world can be *read* — sized up, targeted, and farmed deliberately.

This is the Monster Hunter promise translated to Symbots: an enemy is never just an obstacle, it is a walking catalog of components the player wants (Pillar 2 — Every Battle Has a Harvest Goal). The fantasy this schema enables is **the world as a legible shopping list**. A player who wants a specific part should always be able to answer "which enemy, which behavior, which break target" — and the answer is stable, learnable, and worth writing down. When a player says "I'm going Crawler farming," the Enemy Database is what makes that sentence mean something.

The player also reads enemies in reverse: a new machine type appearing at the zone's edge is a promise of parts that don't exist in the inventory yet. The database's job is to make sure that promise is always real — every enemy entry must be *worth hunting* for at least one build hypothesis (Pillar 5 — The World Is a Workshop).

## Detailed Design

### Core Rules

**Rule 1 — The Enemy Schema**

Every enemy in the game is defined by the following fields. The Enemy Database stores one definition per enemy type; runtime combat state (current Structure, broken regions, Heat/Energy) is owned by the Turn-Based Combat System:

| Field | Type | Description |
|-------|------|-------------|
| `id` | StringName | Unique identifier (e.g., `"rustcrawler"`) |
| `display_name` | String | Player-visible name (e.g., "Rustcrawler") |
| `enemy_class` | Enum | `WILD` or `BOSS` (MVP). `ELITE, RIVAL` reserved for Full Vision. |
| `tier` | int | Zone-scaling tier. **Reserved field: always `1` in MVP content** (1 zone). Full Vision multi-zone content assigns higher tiers; no formula reads it in MVP. |
| `core_element` | Enum | `VOLT, THERMAL, KINETIC`, or `null`. Read by the Damage Formula System for type effectiveness (hard constraint DF3). `null` is valid content — an elementless construct; DF-1 defaults to ×1.0 per its EC-04. |
| `stats` | Dictionary | Stat name → int. Uses **the same 11 canonical stat names as Part Database Rule 4** — no enemy-specific stat vocabulary exists. See Rule 3. |
| `skills` | Array[StringName] | Move Database entry references — the enemy's move pool (2–4 in MVP). *(Provisional: Move Database GDD not yet designed.)* |
| `ai_profile` | StringName | Reference to a behavior profile defined by the Enemy AI System. *(Provisional: interface point only; Enemy AI GDD defines profile contents.)* |
| `break_regions` | Array[Dictionary] | Breakable part regions — see Rule 5. 2–3 per enemy in MVP. |
| `loot_pool` | Array[StringName] | Part Database `id`s this enemy can drop. See Rule 6. |
| `spawn_enabled` | bool | `true` = appears in encounter tables; `false` = no longer spawns (seasonal/retired). Mirrors Part Database `drop_enabled`. |
| `flavor_text` | String | One-line bestiary description, ≤100 characters. *(Aligns with the pending Part DB flavor_text length decision — whichever value is ratified there applies to both schemas.)* |
| `level` | int | **Enemy Level & Zone Scaling erratum (2026-07-13).** Power tier label [1, `MAX_ENEMY_LEVEL` = 10]. Manually authored; does NOT generate stats (EDB-2 TTK calibration is the normative stat gate). Serves three purposes: (1) zone-band membership validation (zone's `[enemy_level_floor, enemy_level_roof]` must include this value); (2) XP reward derivation (CP-F4 input); (3) drop rarity scaling (DS-F-LEVEL input). Must be ≥ 1 and ≤ 10. Level 0 or missing fails content validation (BLOCKING). *(See Enemy Level & Zone Scaling GDD, Rule 1 + Authoring Guide.)* |
| `xp_value` | int | **Enemy Level & Zone Scaling erratum (2026-07-13).** Stored XP award for defeating this enemy, derived from CP-F4: `(XP_BASE + level × XP_PER_ENEMY_LEVEL) × role_multiplier` where `XP_BASE = 35`, `XP_PER_ENEMY_LEVEL = 10`, WILD `role_multiplier = 1`, BOSS `role_multiplier = 2`. **Stored-equals-derived invariant:** the stored value must equal the CP-F4 derivation for the authored `level` — content validation fails (BLOCKING) if it diverges (e.g. after a CP-F4 constants retune). This follows the same pattern as EDB-1's `break_hp`. Verified by AC-ELZS-02. *(See ELZS GDD, Rule 2.)* |

---

**Rule 2 — Enemy Classes (MVP)**

| Class | Count (MVP) | Loot Profile | Break Regions |
|-------|-------------|--------------|---------------|
| `WILD` | ~8 types | Common and Rare parts only | 2–3 regions; breaks boost Common/Rare drop rates |
| `BOSS` | 2 | Common, Rare, **and Boss-grade exclusive** parts | 2–3 regions; **at least one region's break event must gate the Boss-grade drop** (product invariant: `base_rate × multiplier ≥ BOSS_GRADE_BREAK_GUARANTEE = 0.5`, see AC-ED-09; at `BASE_DROP_BOSS_GRADE = 0.001`, requires multiplier ≥ 500 — aligned with Part DB AC-11's ×500 floor at the current guarantee) |

Boss-grade parts never appear in a `WILD` enemy's `loot_pool` (Part DB Rule 8: "cannot appear in wild drop tables"). Prototype parts may appear in either class's pool — their gradient conditions (Part DB Formula 3) govern acquisition.

---

**Rule 3 — The Stat Block (hybrid model)**

Enemy stats are **hand-authored**, not derived from equipped parts. They use the identical 11-stat vocabulary from Part Database Rule 4 (Structure, Armor, Resistance, Physical Power, Energy Power, Mobility, Targeting, Processing, Cooling, Energy Capacity, Recharge) so that the Damage Formula and Turn-Based Combat treat both sides of a battle symmetrically.

**Range constraint (hard, inherited from DF-1):** `physical_power`, `energy_power`, `armor`, and `resistance` must stay within **[0, 110]** — the input range under which Damage Formula DF-1's behavior is verified. `structure` is exempt (it is the HP pool, not a DF-1 input) and may exceed 110, particularly for bosses. Unknown stat keys follow Part DB EC-08: warn and ignore.

**Dead-data note (Heat/Energy keys — OQ-3 RESOLVED 2026-07-10):** Per TBC Rule 8 (ED1 ratification), enemies track no Heat and no Energy — they never Overheat and their moves are always available. The `cooling`, `energy_capacity`, and `recharge` keys are therefore **dead data** in enemy stat blocks for MVP: they may be present (the 11-stat vocabulary is shared with Part DB) but TBC ignores them for enemies. Content validation SHOULD warn when an enemy entry authors non-zero values for those three keys.

**Design intent:** an enemy's stats should *read as if* it were built from parts — a heavily armored crawler has high Armor and low Mobility, matching its visible silhouette — but no formula enforces this. The fiction is carried by content authoring and by the anatomy-linked loot rule (Rule 5), not by a derivation pipeline. Full Vision may migrate `BOSS` entries to true part-assembly; the schema reserves that path (see Open Questions).

**A = 0 edge note:** a stat key absent from `stats` is treated as 0 (EC-ED-06), so `physical_power = 0` is legal enemy content. Paired with a zero-Armor player, this sends A=0, D=0 into DF-1's `A²/(A+D)` term (0/0). DF-1's `DAMAGE_FLOOR` guard owns that case — this schema merely notes it authorizes the input; do not add a second guard here.

---

**Rule 4 — Core Element (DF3 fulfillment)**

Every enemy exposes `core_element`, satisfying Damage Formula hard constraint DF3. The Turn-Based Combat System passes it as `target_core_element` into `compute_damage()`. For the reverse direction (enemy attacking player), the *player's* Core element comes from their equipped Core part's `element` field — both sides route through the same DF-1 call.

---

**Rule 5 — Break Regions (anatomy-linked loot)**

Each entry in `break_regions` defines one breakable component:

```
{ region_id: "left_arm", display_name: "Servo Arm", region_fraction: 0.48, break_hp: 40, break_event: "arm_broken" }
```
*(Illustrative: at structure 85, EDB-1 gives max(5, floor(85 × 0.48 + 0.0001)) = 40 — consistent.)*

| Field | Type | Description |
|-------|------|-------------|
| `region_id` | StringName | Unique within this enemy |
| `display_name` | String | Player-visible region name (Combat UI break pips) |
| `region_fraction` | float | Fraction of body Structure this region absorbs before breaking (0.15–0.55). Authors set this value; `break_hp` is derived from it via EDB-1 and stored alongside it so AC-ED-07(a) can confirm stored-equals-derived. |
| `break_hp` | int | Derived from EDB-1: `max(BREAK_HP_MIN, floor(structure × region_fraction + 0.0001))`. Stored for transparency and validation — must equal the derived value (AC-ED-07(a)). Independent pool — region damage does not reduce body Structure. |
| `break_event` | StringName | Event emitted when the region breaks — **must match the Part DB `drop_conditions` vocabulary exactly** (e.g., `"arm_broken"`) |

**The anatomy link is a validation rule, not a second loot channel.** There is one drop pipeline: Part DB Formula 3. A region's break influences drops because parts in this enemy's `loot_pool` carry `drop_conditions` entries keyed to this region's `break_event`. The content rule (validated by AC-ED-07): every `break_event` this enemy can emit must be referenced by at least one part in its `loot_pool` — a breakable region that boosts nothing violates Pillar 2 ("battles without meaningful drop targets feel like filler") and is a content authoring error.

*How region damage accrues, whether regions can be targeted, and break probability mechanics are owned by the Part-Break System GDD (Part DB constraint DB3). This schema only declares which regions exist, their HP pools, and the events they emit.*

---

**Rule 6 — Loot Pool**

`loot_pool` lists every Part Database `id` this enemy can drop. On battle end, the Drop System iterates the pool's **unique** ids and computes each part's effective drop rate via Part DB Formula 3 (per-rarity base rate × multipliers from fired condition events). The Enemy Database declares *what can drop*; the Drop System owns *how the roll works*. *Errata 2026-07-11: the former "whether pool size divides rates (`BASE_DROP_RARE ÷ pool_size`)" note is void — the Drop System rolls each part as an **independent Bernoulli trial at its own rate**; pool size does not dilute it (Drop System Rule 2, resolving OQ-5).*

Pool size guidance (MVP): `WILD` 2–4 parts; `BOSS` 4–6 parts including exactly 1–2 Boss-grade exclusives.

**Harvest-decision rule (hard, WILD):** `loot_pool.size()` must **exceed** `break_regions.size()`. Rationale: EDB-3 forces every region to be loot-connected, so a pool that merely equals the region count degenerates into a 1:1 region-to-part mapping — the player's harvest *decision* ("which target do I commit to?") collapses into a checklist, defeating Pillar 2. With pool > regions there is always at least one part not uniquely gated to a single break, preserving a real prioritization choice for the break-gated parts. **The un-gated part(s) are floor loot** — they drop at base rate regardless of break behavior, providing an accessible baseline for players not yet executing targeted breaks. The real harvest decisions are the break-gated parts; at minimum two pool parts should carry break conditions for Pillar 2's "which target do I commit to?" to exist with meaningful choice. In practice this raises the WILD pool floor to `regions + 1` (a 2-region WILD needs ≥3 pool parts). `BOSS` satisfies this by construction (pool 4–6 vs. 2–3 regions) — the validator still checks both classes (AC-ED-15c).

**Floor loot rarity rule (hard, content authoring):** Un-gated pool parts — those whose Part DB `drop_conditions` array contains no entry referencing any of this enemy's `break_event` values — must be **Common rarity** in MVP content. A Rare or Boss-grade part placed in the pool without break conditions drops at the base rate with no harvest incentive, silently undermining Pillar 2 ("the harvest decision requires that breaking changes your odds"). Every Rare and Boss-grade part in a `loot_pool` must carry at least one `drop_conditions` entry keyed to one of this enemy's break events. *(Validated by AC-ED-18 — ADVISORY. AC-ED-19 separately validates that at least two pool parts carry break conditions — also ADVISORY.)*

---

### States and Transitions

The Enemy Database is a static data schema — enemy definitions have no runtime states. No state machine applies. Lifecycle mirrors Part DB: entries are added at content authoring time; retired enemies are set `spawn_enabled = false` and remain valid (a defeated-boss rematch flag, if added later, is owned by Exploration Progress, not this schema).

---

### Interactions with Other Systems

| System | What It Reads | What It Expects |
|--------|--------------|-----------------|
| **Turn-Based Combat** | `stats`, `skills`, `core_element` — instantiates the runtime combatant | Stat keys match the 11 canonical names; skills reference valid Move DB entries |
| **Damage Formula** | `core_element` (via Combat's call frame); `stats` provide A and D inputs | A/D-relevant stats within [0, 110] |
| **Part-Break** | `break_regions` — region HP pools and break events | `break_event` values match Part DB drop_conditions vocabulary exactly |
| **Drop System** | `loot_pool`, fired break events | Every pool `id` exists in Part DB; boss pools contain their Boss-grade exclusives |
| **Enemy AI** | `ai_profile`, `skills`, `stats` | Profile IDs resolve to defined behavior profiles |
| **Encounter Zone** | `id`, `enemy_class`, `tier`, `spawn_enabled` — builds spawn tables | Spawn placement is Encounter Zone's domain; this schema holds no zone data |

## Formulas

### Formula EDB-1 — Break Region HP (derived)

```
break_hp = max( BREAK_HP_MIN, floor( structure × region_fraction + 0.0001 ) )
```

**Numeric precision note — the `+ 0.0001` nudge is LOAD-BEARING (verified by exhaustive IEEE 754 scan, 2026-07-09):** unlike the defensive nudges in Part DB Formulas 1–2, this one changes real results. With `region_fraction` authored at 2-decimal precision, 7 inputs in valid content ranges produce the wrong value without it — e.g., `180 × 0.35` evaluates to `62.99999999999999`; bare `floor()` returns 62, the mathematically correct result is 63. Same class of defect as Part DB Formula 2b. Implementations must apply the nudge or use integer-scaled arithmetic (e.g., `structure × fraction_hundredths / 100` in ints).

`break_hp` is **derived, not free-authored**: rebalancing an enemy's `structure` automatically preserves each region's relative break timing. Authors set `region_fraction` per region; **the schema stores both `region_fraction` (the authored input) and the computed `break_hp`** so AC-ED-07(a) can confirm stored-equals-derived.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemy body structure | `structure` | int | 60–594 | The enemy's full HP pool from its stat block (EDB-2 guidance ranges) |
| Region fraction | `region_fraction` | float | 0.15–0.55 | Fraction of body Structure this region absorbs before breaking. Encodes *when* in the fight the region breaks — see guidance table. |
| Minimum break HP | `BREAK_HP_MIN` | int | 5 (tunable) | Defensive floor — never activates for in-spec content (minimum derived value is 9) |
| Result | `break_hp` | int | 9–326 in-spec | Independent damage pool for this region. Does not reduce body Structure. |

**Region fraction guidance (content authoring):**

Break commitment scales with fight length: turns of region focus ≈ `region_fraction × TTK_body` (break_hp is `fraction × structure`, and body TTK is `structure ÷ dmg`, so the ratio holds at any damage level). The tier labels below describe *proportional* timing — they only produce three *distinct* commitment tiers on fights of ~5+ turns (WILD-mid, BOSS):

| Fraction | Proportional timing | Use for |
|----------|--------------------|---------|
| 0.15–0.25 | ~first quarter of the fight | "Opener" region — breaks with minimal focus; rewards attentiveness |
| 0.25–0.40 | ~mid fight | Primary harvest target — the deliberate hunt objective |
| 0.40–0.55 | ~late fight | Expert challenge — requires committed region focus or type advantage |

**Short-fight compression warning (WILD-early):** on a 2–4 turn fight, all three tiers compress to 1–2 turns of commitment — the tier distinctions are not meaningful. For WILD-early enemies, author regions as simply "cheap" (0.15–0.30) or "committed" (0.35–0.55) and do not expect three readable timing tiers.

The 0.55 cap keeps break cost well under kill cost (see EDB-3 note — the invariant itself cannot fail for any fraction < 1.0; the cap is a *worth* judgment, not a math bound). Fractions across an enemy's regions need not sum to 1.0 — regions are independent pools.

**Output range:** floor(594 × 0.55 + 0.0001) = 326 at the top. In-spec minimum is floor(60 × 0.15) = **9** — `BREAK_HP_MIN` (5) never activates for spec-valid content (structure ≥ 60, fraction ≥ 0.15) and is purely defensive, per AC-ED-08(b). Practical: WILD 9–88, BOSS 54–326.

**Worked example (discriminating — floor ≠ round ≠ ceil):** Rustcrawler, structure = 85, Left Arm at region_fraction = 0.35:
- `85 × 0.35 = 29.749999999999996` (IEEE 754); `+ 0.0001 → 29.7501`; `break_hp = max(5, floor(29.7501)) = 29`
- Verification: floor = **29**; round = 30; ceil = 30 — an implementation using round() or ceil() returns 30 and fails. (The nudge does not change this case; see AC-ED-08(c) for a case where it does.)

**Rebalancing behavior:** retuning Rustcrawler's structure 85 → 88 (the WILD-early ceiling) auto-updates break_hp to floor(88 × 0.35 + 0.0001) = 30 — same relative fight timing, no manual audit.

---

### Formula EDB-2 — Enemy Stat Budget (TTK calibration)

This is a **design-time calibration table**, not a runtime formula. It grounds authored enemy stats in the locked DF-1 math so fights land in the intended turn windows.

```
TTK_turns = ceil( structure / damage_per_turn(A_cal, D_enemy, T) )
```

where `damage_per_turn` is DF-1 evaluated at a calibration loadout:

| Calibration point | A | D | T | DF-1 dmg/turn |
|-------------------|---|---|---|---------------|
| Early-game neutral | 35 | 20 | 1.0 | 22 |
| Mid-game neutral | 53 | 30 | 1.0 | 33 |
| Mid-game super-effective | 53 | 30 | 1.5 | 50 |
| Mid-game resisted | 53 | 30 | 0.75 | 25 |

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemy structure | `structure` | int | 60–594 | Full HP pool — the primary TTK lever |
| Enemy defense | `D_enemy` | int | 0–110 | Armor or Resistance (DF-1's D input) |
| Calibration player power | `A_cal` | int | 20–80 | Assumed player power at the balancing milestone |
| Type effectiveness | `T` | float | {0.75, 1.0, 1.5} | Matchup assumed for calibration; use 1.0 as baseline |
| Result | `TTK_turns` | int | 2–18 | Expected fight length at the calibration point |

**TTK bands (normative) and stat range guidance:**

The **TTK band is the normative constraint**, validated per-enemy by AC-ED-14's *computed* check: `dmg = floor(A_cal² / (A_cal + armor))`, `TTK = ceil(structure / dmg)` — using the enemy's *actual* authored Armor (and Resistance, checked separately with the same formula), not a fixed reference D. This jointly bounds structure × defense automatically: a high-Armor boss must carry proportionally less Structure to stay in band. *(Float-safety: exhaustively scanned 2026-07-09 — zero float/int divergences for A_cal ∈ {35, 53}, armor 0–110, structure 1–700; pure IEEE 754 division is correctly rounded, so no epsilon is needed here, unlike EDB-1. Implement in integer arithmetic anyway per project convention.)*

| Class | A_cal | TTK band (normative) | Structure guidance* | Physical Power | Energy Power | Armor | Resistance |
|-------|-------|---------------------|--------------------|----------------|--------------|-------|------------|
| WILD (early) | 35 | 2–4 turns | 60–88 | 18–30 | 18–30 | 15–30 | 15–30 |
| WILD (mid) | 53 | 3–5 turns | 90–160 | 25–39 | 25–39 | 20–35 | 20–35 |
| BOSS | 53 | 12–18 turns | 364–594 | 35–70 | 35–70 | 30–55 | 30–55 |

\* Structure ranges are **authoring guidance at the class's reference defense** (WILD-early D=20, mid/BOSS D=30) — not independently normative. Extreme *combinations* within these ranges can still leave the TTK band (e.g., BOSS Armor 55 + Structure 594 → 26 dmg/turn → TTK 23); the computed AC-ED-14 check catches them. Conversely, a high-Armor boss may legitimately sit *below* the structure floor (D=45, Structure 350 → 28 dmg/turn → TTK 13 ✓ — in band).

Derivations at reference defense: WILD-early ceiling `ceil(88/22) = 4` ✓ (89+ gives 5 — out of band); BOSS floor `ceil(364/33) = 12` ✓ (350 gives 11 — out); BOSS ceiling `ceil(594/33) = 18` ✓ (600 gives 19 — out).

**BOSS Armor > 80 authoring constraint:** At the BOSS structure guidance floor (364), Armor values above 80 are structurally incompatible with the 12–18 TTK band at A_cal=53. At Armor=81: `dmg = floor(2809/134) = 20`, `TTK = ceil(364/20) = 19` — already out of band (upper). At Armor=90: TTK=22; at Armor=110: TTK=31. A BOSS with Armor > 80 must carry Structure well below 364 (e.g., Armor=90, Structure=220 → TTK=12 ✓) — the AC-ED-14 computed check will catch out-of-band combinations, but **Armor values 81–110 for BOSS are a content authoring footgun** unless structure is explicitly lowered to compensate. AC-ED-14 is ADVISORY for this reason (enforcement is a Beta-readiness concern, not MVP). Authors targeting the high-Armor archetype should use the formula `S_max = TTK_max × floor(A_cal²/(A_cal + Armor)) - 1` to pre-compute the compatible structure ceiling before submission.

**TTK lower bound note (WILD-early "2 turns"):** TTK=2 is only achievable via Armor=0 content — at A=35, D=0: dmg = floor(1225/35) = 35 per turn → ceil(60/35) = 2. At reference D=20, the minimum achievable TTK within the structure guidance floor (60) is ceil(60/22) = **3**. The "2" in the 2–4 band represents the theoretical floor only reachable through the degenerate zero-Armor scenario that the WILD_POWER_CAP is designed to prevent; it is not a content target. See AC-ED-14's degenerate floor note — AC-ED-14 does not warn on TTK=2 because 2 is inside the stated band, so the WILD_POWER_CAP (AC-ED-05c) is the actual guard for this case.

**WILD power cap (hard content rule):** WILD enemies' `physical_power` and `energy_power` must not exceed **39**. Derivation: the binding worst case is a **zero-Armor** player (Armor 0 is a legal stat value) at minimum Structure 60 in a super-effective matchup. At A=40, D=0, T=1.5: `floor(1600/40 × 1.5) = 60` — a **one-hit kill** from a wild encounter, which is unacceptable even as a build-failure outcome. At the cap (A=39): `floor(1521/39 × 1.5) = floor(58.5) = 58 < 60` — no one-shot exists against any legal build; a 2-hit death (58+58) against a zero-armor, minimum-structure build remains possible and is the legitimate build-failure outcome. BOSS power is exempt (up to 70; bosses are allowed to demand build homework).

**Boss TTK note:** the 12–18 turn band (not 10–20) is a mobile session-length decision — at 33 dmg/turn, 19+ turns means Structure ≥ 595 and a 5–8 minute fight; 364–594 keeps bosses substantial but bounded. A higher-armor boss trades structure for defense within the same TTK band: D=45, Structure 350 → 2809/98 = 28 dmg/turn → ceil(350/28) = 13 turns.

**Max-synergy addendum (EDB-2 calibrates for base-only stats):** The TTK bands above are computed at the calibration loadout (A_cal = 35/53), which is a *base-stats* build with no synergy bonus. A max-synergy player (effective A up to 150 under SYNERGY_POWER_BUDGET=40, or a SIGNATURE-tier move via MOVE-F1) legitimately compresses BOSS TTK to ~4–7 turns (and to 3 turns at the SIGNATURE mastery ceiling — ruled acceptable in the Move DB review). This is the intended reward for full build investment, not an out-of-band violation: AC-ED-14 validates the *base* calibration, and the synergy compression sits above it by design. *(Confirmed by /review-all-gdds cross-check 2026-07-10, HOLISM-03/difficulty-curve.)*

---

### Formula EDB-3 — Break Region Validity (content validation)

A validation rule run at authoring/import time — not a runtime computation.

```
break_cheaper_than_kill = break_hp < structure
loot_connected          = any( break_event in part.drop_conditions for part in loot_pool )
region_is_valid         = break_cheaper_than_kill AND loot_connected
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Region break HP | `break_hp` | int | 9–326 in-spec | From EDB-1 |
| Enemy structure | `structure` | int | 60–594 | Full body HP pool |
| Break event | `break_event` | StringName | — | Event this region emits (e.g., `"arm_broken"`) |
| Loot pool | `loot_pool` | Array[StringName] | — | This enemy's droppable Part DB ids |
| Result | `region_is_valid` | bool | — | `false` = content authoring error, caught at import — never a runtime fallback |

**Why `break_hp < structure`:** body and region damage are independent pools, so a break is always *possible* — the invariant is about *worth*. If breaking a region costs more damage than killing the enemy outright, targeted hunting is strictly worse than just winning, and the harvest decision loses meaning (Pillar 2). Breaking must always be the cheaper commitment **at fight start** — the invariant uses initial structure values; mid-fight, remaining body HP may fall below a region's break_hp as both damage pools progress independently, so the "cheaper" property is not guaranteed at all points in the fight. The invariant's purpose is that breaking is always *possible* as the prioritized choice before damage accumulates. (The EDB-1 fraction cap of 0.55 guarantees this at fight start with margin; the invariant catches hand-authored overrides.)

**Why `loot_connected`:** a region whose break event no pool part references is a dead UI element — a break pip that does nothing. Violates Pillar 2; same rule as Section C Rule 5.

*Advisory — syntactic-only check: `loot_connected` verifies that a region's break_event is referenced by at least one pool part's `drop_conditions`, but does NOT inspect the `multiplier` value. A condition with `multiplier = 1.0` satisfies this check but provides no harvest incentive (drop rate unchanged). Minimum-meaningful multiplier enforcement belongs in the Drop System / Part DB schema — see OQ7.*

**Worked example:** Rustcrawler (structure 85), Left Arm (break_hp 29, event `"arm_broken"`), pool contains `rustcrawler_servo_arm` with `drop_conditions: ["arm_broken"]` → `29 < 85` ✓ AND connected ✓ → valid.

**Counter-example:** region "chest_plate" with break_hp 90, event `"plate_cracked"`, no pool part referencing it → `90 < 85` ✗ AND connected ✗ → authoring error, import fails.

---

**Deliberately not defined here:** damage-to-region routing and break targeting (Part-Break System GDD, per Part DB constraint DB3); drop roll mechanics (Part DB Formula 3, executed by Drop System). This schema declares regions and pools; those systems own the runtime.

## Edge Cases

### EC-ED-01 — Enemy with zero break regions
**If** an enemy entry has an empty `break_regions` array: content validation **fails** for MVP content. Pillar 2 requires every encounter to carry a harvest target — an unbreakable enemy is filler by definition. Minimum 1 region; target 2–3 per the game concept. (If Full Vision ever adds pure-ambush trash encounters, that requires a pillar-level exception, not a silent schema allowance.)

### EC-ED-02 — `loot_pool` references a nonexistent part id
**If** any `loot_pool` entry has no matching `id` in the Part Database: content validation fails at import. Dangling loot references are never valid — this is the Enemy DB analog of Part DB AC-13's referential integrity.

### EC-ED-03 — `loot_pool` contains a part with `drop_enabled = false`
**If** a pool part is drop-disabled: the entry is **valid** — the Drop System excludes it from rolls at runtime (Part DB AC-15a). The validator emits an authoring *warning* (not a failure), since a pool full of disabled parts silently starves the enemy's loot. If **all** parts in a pool are disabled, escalate to a failure — the enemy would violate EC-ED-01's spirit with zero obtainable drops.

### EC-ED-04 — Class/rarity mismatches in the loot pool
**If** a `WILD` enemy's pool contains a Boss-grade part: content validation fails (Part DB Rule 8: Boss-grade never appears in wild drop tables). **If** a `BOSS` pool contains no Boss-grade part: content validation fails (Rule 2 requires 1–2 exclusives). Both are import-time errors.

### EC-ED-05 — `core_element` is null
**If** `core_element` is null: valid content — an elementless construct. DF-1's EC-04 fallback applies (×1.0 neutral for all incoming skills). Note the strategic consequence: a null-element enemy cannot be exploited by type-matching, making it a "neutral wall" — it mutes the type-mastery fantasy and is systematically slower to farm (no ×1.5 route). **Enforced density cap**: at most `NULL_ELEMENT_MAX_WILD` (currently 1) null-element `WILD` entries per zone — a second one emits a zone-level ADVISORY warning (AC-ED-15d). "Use sparingly" is a validated rule, not a hope.

### EC-ED-06 — Missing or unknown keys in `stats`
**If** a canonical stat key is absent: treated as 0, with one exception — `structure` absent or 0 fails validation (a 0-Structure enemy dies on contact; never valid content). **If** an unknown key is present: warn and ignore, matching Part DB EC-08 — the shared 11-stat vocabulary evolves in one place.

### EC-ED-07 — Two regions emit the same `break_event`
**If** two regions on one enemy share a `break_event` (e.g., left and right arm both emit `"arm_broken"`): valid — but break events are **set semantics** for Formula 3. Breaking both arms fires `arm_broken` *once*; a part's ×1.5 `arm_broken` multiplier applies once, not squared. The Drop System collects fired events as a deduplicated set. (Rewarding double-breaks with a stronger multiplier requires a distinct event like `"both_arms_broken"` — Full Vision vocabulary.)

### EC-ED-08 — Duplicate `region_id` or duplicate `loot_pool` entries
**If** two regions on one enemy share a `region_id`: content validation fails (region ids are unique per enemy). **If** the same part id appears twice in `loot_pool`: validator dedupes with a warning — duplicates do not double the drop chance (the Drop System iterates unique ids).

### EC-ED-09 — `spawn_enabled = false` on a boss
**If** a `BOSS` entry is spawn-disabled: the schema permits it (seasonal/event bosses are the field's purpose), but the validator emits a *progression warning* — if the Zone & World Map gates progression on defeating this boss, disabling it soft-locks the game. The Encounter Zone GDD owns the actual progression-integrity check; this schema's responsibility is only to surface the flag.

### EC-ED-10 — Empty `skills` array
**If** an enemy has no skills: content validation fails. Every enemy needs at least 1 move (its basic attack) or its combat turns are no-ops. MVP range: 2–4.

### EC-ED-11 — `region_fraction` outside [0.15, 0.55]
**If** a region's fraction is authored outside EDB-1's bounds: content validation fails at import — no silent clamping. Below 0.15 produces trivial breaks (undermines the hunt); above 0.55 violates EDB-3's break-cheaper-than-kill margin.

### EC-ED-12 — `tier ≠ 1` in MVP content
**If** any MVP-shipped entry has `tier` other than 1: validator warning (not failure). The field is reserved; no MVP formula reads it — but stray values would silently become live balance data the moment Full Vision zone-scaling activates.

## Dependencies

### Upstream Dependencies (what Enemy Database requires)

| System | What It Provides | Status |
|--------|-----------------|--------|
| **Part Database** | The `id` vocabulary for `loot_pool`; the `drop_conditions` event vocabulary that `break_event` must match; rarity rules (Boss-grade exclusivity, Rule 8); the 11 canonical stat names; Formula 3 (the drop pipeline this schema feeds) | ✓ Approved |
| **Move Database** *(provisional)* | Entries for `skills[]` references | Not designed — referential validation (AC-ED-03) is BLOCKED until it exists, mirroring Part DB AC-13 |
| **Enemy AI System** | The behavior profile contract behind `ai_profile` | Approved 2026-07-12 — resolves to {AGGRESSIVE/TACTICAL/OPPORTUNIST}; AC-ED-01(d) referential check un-blocked via `has_profile(id)` |

### Downstream Dependents (what depends on Enemy Database)

| System | What It Reads | Hard Constraint on That GDD |
|--------|--------------|------------------------------|
| **Damage Formula** | `core_element` (as `target_core_element`), `stats` as A/D inputs | Already ratified: DF3 is fulfilled by Rule 4. A/D stats within [0, 110] (Rule 3). |
| **Turn-Based Combat** | `stats`, `skills`, `core_element` — instantiates runtime combatants | **ED1**: must ratify (or replace) the assumption that enemies run the same Heat/Energy economy as player Symbots — Cooling/Energy Capacity/Recharge in enemy stat blocks are meaningless until Combat defines enemy resource tracking. |
| **Part-Break System** | `break_regions` — HP pools and events | **ED2**: must define region targeting and damage accrual against `break_hp` (per Part DB DB3), and must emit each region's `break_event` on break. |
| **Drop System** | `loot_pool`, fired break events | **ED3**: must collect fired events as a **deduplicated set** before applying Formula 3 multipliers (EC-ED-07 semantics), and iterate unique pool ids only. **ED3-OQ7 constraint — RESOLVED 2026-07-11**: the Drop System GDD now defines `MULTIPLIER_FLOOR = 1.5` (Drop System Rule 5a) — the minimum drop-condition multiplier that counts as a perceivable harvest incentive. EDB-3's `loot_connected` check remains syntactic (satisfiable by ×1.0), but a condition multiplier in `(1.0, 1.5)` is now a content warning and `≤ 1.0` a content error, giving Pillar 2 functional teeth. Boss-grade retains its separate ≥ ×500 floor (Part DB AC-11). |
| **Enemy AI** | `ai_profile`, `skills`, `stats` | **ED4 DISCHARGED** (Enemy AI Approved 2026-07-12): profile schema defined (AGGRESSIVE/TACTICAL/OPPORTUNIST + weight vectors); `ai_profile` resolves via `EnemyAI.has_profile(id)`, un-blocking AC-ED-01(d). |
| **Encounter Zone** | `id`, `enemy_class`, `tier`, `spawn_enabled` | **ED5**: owns spawn placement and must implement the progression-integrity check for spawn-disabled bosses (EC-ED-09). |
| **Combat UI** | `break_regions[].display_name` — break pip labels | **ED6**: must expose break region display names as in-combat pip labels AND provide some form of drop-hint mechanism (encounter log, post-battle codex entry, or scan mechanic) before MVP content lock — the Player Fantasy ("world as legible shopping list") requires the information layer to be discoverable in-game. Without it, the schema enables the hunt-plan fantasy but no system delivers it. |
| **Enemy Level & Zone Scaling** *(#10c, Approved 2026-07-13)* | `level`, `xp_value`, `enemy_class` (as `role_multiplier`) — reads the Level Backbone fields added by the ELZS erratum | **ELZS erratum applied 2026-07-13**: `level` and `xp_value` fields added to this schema (see Rule 1 table above). ELZS content validation (AC-ELZS-01, AC-ELZS-02) runs against every Enemy Database entry. The stored-equals-derived contract on `xp_value` requires a full-roster sweep on every content commit (CI obligation — see ELZS Errata pre-gate block). EDB-2 TTK calibration (AC-ED-14) is the cross-system guard for level-vs-stat consistency — ELZS's label/anchor model depends on it (see ELZS Dependencies). |

### Bidirectionality Note

Part Database already lists Enemy Database in its Downstream Dependents table (✓ verified). Damage Formula already lists Enemy Database as an upstream dependency via DF3 (✓ verified). Each system in the table above must reference Enemy Database in its own Dependencies section when authored.

## Tuning Knobs

All values live in external config, not code. Drop-rate knobs (`BASE_DROP_*`, break multiplier) are owned by the Part Database Tuning Knobs section — do not duplicate them here; this schema only feeds them.

| Knob | Current Value | Safe Range | What Changing It Does |
|------|--------------|------------|----------------------|
| `BREAK_HP_MIN` | 5 | 3–10 | Floor on derived break HP. **Design preference, not a formula safety bound** — EDB-3 cannot fail until BREAK_HP_MIN ≥ structure (i.e., ≥ 60), and the guard never activates for in-spec content anyway (minimum derived value is 9). Below 3, out-of-spec weak enemies' regions would break on any hit; above ~10 the floor starts overriding authored fractions on hypothetical low-Structure content. |
| `REGION_FRACTION_MIN` | 0.15 | 0.10–0.20 | Lower authoring bound for EDB-1. Lowering makes "opener" regions nearly free; raising removes the early-break reward tier. |
| `REGION_FRACTION_MAX` | 0.55 | 0.45–0.60 | Upper authoring bound. **Design judgment, not a math bound** — EDB-3's `break_hp < structure` invariant cannot fail for any fraction < 1.0; the cap exists because a break costing >55% of the kill damage stops feeling like the cheaper commitment (Pillar 2 *worth*, not formula safety). Lowering compresses the expert-challenge tier. |
| `WILD_POWER_CAP` | 39 | 30–39 | Max WILD `physical_power`/`energy_power`. At 40+, a super-effective hit one-shots a zero-armor minimum-structure player (EDB-2 derivation: floor(1600/40 × 1.5) = 60 ≥ 60); at 39 the worst case is 58 — 2-hit deaths remain the legitimate build-failure floor. Below 30, wild enemies stop threatening mid-game builds and combat pacing sags. |
| `NULL_ELEMENT_MAX_WILD` | 1 | 0–2 | Max null-element WILD entries per zone before AC-ED-15d warns. Each null-element enemy is a fight where type mastery does nothing — at 2+ of 8 wilds, a quarter of the roster mutes the game's #2 aesthetic (Challenge via type knowledge). |
| `BOSS_GRADE_BREAK_GUARANTEE` | 0.5 | 0.25–1.0 | The product floor for AC-ED-09 (`base_rate × multiplier`). **Design target: ~50% chance per qualifying break, averaging ~2 attempts per Boss-grade exclusive** — Boss-grade farming requires correct break execution plus some variance. At the 2-boss MVP roster (1–2 exclusives each), a motivated player may collect all Boss-grade exclusives within a handful of boss sessions; the 50% rate ensures every acquisition requires real gameplay effort (correct break + variance), not persistence alone. Single-session acquisition prevention is not a property this knob can enforce at MVP roster size. At `BASE_DROP_BOSS_GRADE = 0.001`, the required break condition multiplier is ×500 — aligned with Part DB AC-11's floor and the updated Part DB Tuning Knobs. The Drop System GDD must define a pity floor (guaranteed acquisition at N qualifying breaks) to bound the worst-case tail; see OQ4. |
| WILD Structure bands | 60–88 / 90–160 | ±20% | Fight length guidance for trash encounters (normative gate is computed TTK, AC-ED-14). Directly multiplies session pacing — the primary "does farming feel fast" lever. |
| BOSS Structure band | 364–594 | 330–650 | Boss fight length guidance at reference D=30 (normative gate is computed TTK, AC-ED-14 — high-Armor bosses need proportionally less). Above the band ≈ 19+ turns — mobile grind territory; below, bosses die inside 12 turns and stop feeling like walls that demand build homework. |
| Boss TTK band | 12–18 turns | 10–20 | The normative constraint (validated per-enemy by AC-ED-14's computed check). Changing this changes the Structure guidance via EDB-2 — never change one without the other. |
| Pool size (WILD / BOSS) | 2–4 / 4–6 | 2–6 / 3–8 | WILD floor is effectively `regions + 1` (Rule 6 harvest-decision rule, AC-ED-15c). Larger pools dilute per-part rates if the Drop System divides by pool size (Part DB knob note) — coordinate any change with the Drop System GDD (Open Question 5). |

**Knob interaction warning:** `WILD_POWER_CAP`, the Structure bands, and the Boss TTK target are all coupled through EDB-2's calibration points, which are themselves derived from DF-1 at assumed player loadouts. If the Part Database stat budgets or DF-1's type multipliers are retuned, re-run the EDB-2 calibration table before trusting any of these ranges.

## Visual/Audio Requirements

N/A — pure-data Foundation system. Enemy visual identity (silhouettes, part readability, break VFX) is owned by the Art Bible and per-enemy asset specs; break/damage audio is owned by the Audio System GDD. This schema's only visual-adjacent obligation is that `break_regions[].display_name` supplies the Combat UI's break pip labels.

## UI Requirements

N/A — pure-data Foundation system. The Combat UI GDD owns enemy information display (break pips, element indicator, Head/Sensor-gated part info per Part DB Rule 2); a future bestiary screen (Full Vision) would read this schema but is not an MVP requirement.

## Acceptance Criteria

ACs marked **BLOCKING** gate story completion (Logic type — automated tests in `tests/unit/enemy-database/`). ACs marked **ADVISORY** emit authoring warnings via the content validation report (the "warning surface" for all warning assertions below is the validator's structured report output, not log lines).

### Schema Validation

**AC-ED-01** (BLOCKING): Every enemy entry has all required fields present and correctly typed. **Pass when**: zero entries where `id`, `display_name`, `enemy_class`, `tier`, `stats`, `skills`, `ai_profile`, `break_regions`, `loot_pool`, `spawn_enabled`, or `flavor_text` is missing, null, or wrong-typed. Scoping: (a) this AC is **type-and-presence only** — value rules live elsewhere: `tier` value → AC-ED-13; `flavor_text` length → AC-ED-13; `skills` count → AC-ED-03; (b) `core_element` is the one nullable field — when non-null it must be `VOLT`, `THERMAL`, or `KINETIC` (EC-ED-05); (c) `enemy_class` ∈ {`WILD`, `BOSS`} — **class boundary fixtures**: `enemy_class = "ELITE"` fails (reserved for Full Vision — Rule 1 names it but validators must reject it as an invalid MVP value); `enemy_class = "WILD"` passes. **Type boundary fixture**: `spawn_enabled = 1` (int instead of bool) fails; `spawn_enabled = "false"` (String instead of bool) fails — only a true bool is valid; (d) `ai_profile` is validated as a non-empty StringName **and** referentially via `EnemyAI.has_profile(id)` — must resolve to one of `{AGGRESSIVE, TACTICAL, OPPORTUNIST}` (Enemy AI Approved 2026-07-12; `has_profile` verified by Enemy AI AC-EAI-14). An `ai_profile` outside that set fails validation. *(Un-blocked 2026-07-12 — was BLOCKED pending the Enemy AI profile schema.)*; (e) `display_name` and `flavor_text` are non-empty Strings. **Test type**: Content Validation.

**AC-ED-02** (BLOCKING): Every enemy `id` is globally unique. **Pass when**: `set.size() == entries.size()` across all entries — no duplicates. **Test type**: Content Validation.

**AC-ED-03** (partially BLOCKED): `skills` referential integrity and count. **Active now (not blocked)**: every entry has `skills.size() >= 1` — empty array fails (EC-ED-10); `skills.size() > 4` emits an ADVISORY warning (MVP design intent 2–4, not a schema error). **Boundary fixtures**: `skills = [a, b, c, d]` (size 4) → passes with zero warnings (`4 > 4` is false — the threshold is exclusive at 4); `skills = [a, b, c, d, e]` (size 5) → passes with exactly 1 ADVISORY warning (`5 > 4` is true). An implementation that warns at size ≥ 4 (instead of > 4) incorrectly warns on valid 4-skill entries. **BLOCKED portion**: every `skills[]` entry resolves via `MoveDatabase.has_skill(id)` with zero dangling references; *unblocks when: Move Database GDD defines `MoveDatabase.has_skill(id)`*. The BLOCKED label exempts only the referential check — the count checks run from day one. **Test type**: Content Validation.

**AC-ED-04** (BLOCKING): `loot_pool` referential integrity. **Pass when**: (a) every `loot_pool` entry satisfies `PartDatabase.get_part(id) != null` — zero dangling references (fail); (b) a pool where **all** parts have `drop_enabled == false` fails (EC-ED-03 escalation — zero obtainable drops); (c) a pool with **some** disabled parts passes with an ADVISORY warning per disabled entry in the validation report. **Boundary fixture**: `pool = [part_A (enabled), part_B (disabled)]` (size 2, 1 disabled of 2) → passes with 1 ADVISORY warning — this is the some-disabled, not all-disabled case; an implementation that escalates any-disabled to a BLOCKING failure incorrectly rejects this valid configuration; (d) duplicate ids within one pool are deduplicated with an ADVISORY warning (EC-ED-08); (e) **happy path**: a pool of 3 valid, enabled, distinct part ids passes with zero warnings; (f) an **empty** `loot_pool` fails — an enemy with nothing to drop violates Pillar 2. **Scope clarification:** AC-ED-04(f) owns this BLOCKING failure check; AC-ED-15(b) independently emits an ADVISORY warning when pool size falls outside the [2,4] / [4,6] guidance ranges — these are distinct checks. AC-ED-15(b) does not replace AC-ED-04(f); an empty pool must fail here, not merely warn at AC-ED-15. **Test type**: Content Validation.

**AC-ED-05** (BLOCKING): Stat ranges. **Pass when**: (a) `stats.get("structure", 0) >= 1` — value 0 or key absent fails (EC-ED-06); **validator must use `stats.get("structure", 0)`, not bracket access `stats["structure"]`** — GDScript bracket access on a missing key returns null (not 0) and may crash in strict mode; a `stats: {}` entry must produce a clean validation failure, not a runtime error; **positive boundary**: `structure = 1` passes, `structure = 0` fails, `stats = {} → structure absent → treated as 0 → fails`; (b) `physical_power`, `energy_power`, `armor`, `resistance` each ∈ [0, 110] — outside fails (DF-1 verified input range; this is a schema-safety gate, distinct from the balance bands in AC-ED-14). **Boundary fixtures:** `armor=0` passes; `armor=110` passes; `armor=111` fails; same applies to `physical_power`, `energy_power`, `resistance` (upper bound is inclusive at 110, exclusive at 111 — implement as `<= 110`, not `< 110`); (c) for every `WILD` entry: `physical_power <= 39` AND `energy_power <= 39` — above fails (`WILD_POWER_CAP`); (d) **positive boundary**: a WILD entry with `physical_power = 39` and `energy_power = 39` passes; one with `physical_power = 40` fails; (e) unknown stat keys emit an ADVISORY warning and are ignored (EC-ED-06). **Test type**: Content Validation.

**AC-ED-06** (BLOCKING): Class/pool rarity rules. Rarity is resolved by querying `PartDatabase.get_part(id).rarity` for each pool entry. **Pass when**: (a) zero `WILD` entries whose pool contains a part with `rarity == BOSS_GRADE` (Part DB Rule 8); (b) every `BOSS` entry's pool contains 1 or 2 parts with `rarity == BOSS_GRADE` — 0 fails, 3+ fails (Rule 2); (c) **all four count boundaries explicit**: exactly 1 Boss-grade passes; exactly **2 passes**; exactly **3 fails**; 0 fails — an implementation accepting only 1, or accepting 3, must fail this AC; positive case: a BOSS pool with exactly 1 Boss-grade and 3 Rare/Common parts passes; **second positive fixture:** a BOSS pool with exactly 2 Boss-grade parts and 2 Rare/Common parts also passes — an implementation checking `== 1` (only one Boss-grade valid) incorrectly fails this case; (d) **cross-enemy exclusivity**: zero part ids appearing in both a BOSS pool with `rarity == BOSS_GRADE` and any WILD pool — assertion (a) covers this by construction, stated here explicitly so the validator checks all pools, not per-enemy in isolation. **Cross-enemy fixture**: Enemy A (BOSS) pool contains part X with `rarity == BOSS_GRADE`; Enemy B (WILD) also has part X in its pool → validation fails on Enemy B (a WILD holding a BOSS_GRADE part). This fixture requires the validator to check cross-entry — a per-enemy-in-isolation validator would correctly fail Enemy B on clause (a) alone, but the explicit (d) check confirms the validator scans all pools together, not independently. **Test type**: Content Validation.

### Break Region Validation

**AC-ED-07** (BLOCKING): Break region validity (EDB-3 + EDB-1 consistency). For every region of every enemy: **Pass when**: (a) **stored-equals-derived**: `break_hp == max(BREAK_HP_MIN, floor(structure × region_fraction + 0.0001))` — integer equality; a hand-edited stale `break_hp` fails even if it satisfies (b). **Counter-example fixture:** `structure=85, region_fraction=0.35, stored break_hp=28` → derived = `max(5, floor(85×0.35+0.0001)) = 29` → fails (`28 ≠ 29`). A validator checking only EDB-3 (range + loot-connected) would pass this case — the stored-equals-derived check is a distinct requirement. **Positive boundary:** `stored break_hp=29` → passes; (b) **EDB-3 both clauses**: `break_hp < structure` AND the region's `break_event` matches the `condition` field of at least one `drop_conditions` entry on at least one pool part — schema citation: `PartDatabase.get_part(id).drop_conditions` is `Array[Dictionary]` where each entry is `{ condition: StringName, multiplier: float }` (Part DB Rule 1 / AC-11); the traversal is region → `break_event` → each pool part → each `drop_conditions[i].condition`. **False-branch fixture**: a region with `break_event = "plate_cracked"` where zero pool parts have any `drop_conditions` entry with `condition = "plate_cracked"` → fails (this is the dead-region case from EDB-3's counter-example — a break pip that boosts nothing); (c) `region_id` unique within the enemy — duplicate fails (EC-ED-08; e.g., two regions both named `"left_arm"` fail); each region's `display_name` is a non-empty String; (d) `region_fraction` within bounds **with float tolerance**: `0.15 − 1e-9 <= region_fraction <= 0.55 + 1e-9` (EC-ED-11) — tolerance required because 0.15 and 0.55 are not exactly representable in IEEE 754 and a strict `>=` fails correctly-authored content; (e) every enemy has `break_regions.size() >= 1` (EC-ED-01). **Test type**: Content Validation.

**AC-ED-08** (BLOCKING): Formula EDB-1 unit test. **Pass when**: (a) **discriminating case**: `structure = 85, region_fraction = 0.35` returns exactly `29` — `85 × 0.35 = 29.749999999999996` in IEEE 754; floor = 29, round = ceil = 30; an implementation using round() or ceil() returns 30 and fails. This case also confirms `BREAK_HP_MIN` is inactive in normal ranges (29 > 5). (b) **BREAK_HP_MIN activation (out-of-band, GUARD-ONLY test)**: `structure = 20, region_fraction = 0.15` returns exactly `5` — `20 × 0.15 = 3.0` (verified exact in IEEE 754; no epsilon interaction), `max(5, 3) = 5`. **This case does NOT discriminate rounding mode** — floor, round, and ceil all return 3 on an exact 3.0; it proves only that the `max()` guard fires. Rounding-mode discrimination is owned exclusively by cases (a) and (c). Honesty note: within MVP content ranges (structure ≥ 60, fraction ≥ 0.15 → `60 × 0.15 = 9.0` exactly, floor 9 > 5) the guard never activates — it is defensive, like the Part DB F1/F2 epsilon. (c) **Epsilon regression case (LOAD-BEARING — verified 2026-07-09)**: `structure = 180, region_fraction = 0.35` returns exactly `63` — `180 × 0.35 = 62.99999999999999` in IEEE 754; without the `+ 0.0001` nudge, floor returns 62 (wrong). An implementation omitting the nudge fails this case. Exhaustive scan (python3, 2026-07-10): **7 such inputs exist** at 2-decimal fractions in valid content ranges (structure 60–594, fraction 0.15–0.55, step 0.01). **Test type**: Unit.

**AC-ED-09** (BLOCKING): Boss-grade break gating. For every `BOSS` entry, the check is a two-step lookup: (1) collect the set of this boss's `break_event` values; (2) for each pool part with `rarity == BOSS_GRADE`, assert it has at least one `drop_conditions` entry whose `condition` is in that set AND which satisfies the **product invariant**:

```
BASE_DROP_BOSS_GRADE × multiplier >= BOSS_GRADE_BREAK_GUARANTEE
```

where `BASE_DROP_BOSS_GRADE` is read from the Part DB Tuning Knobs config (currently 0.001) and `BOSS_GRADE_BREAK_GUARANTEE` is a config constant (currently **0.5** = ~50% chance per qualifying break; see OQ4 and Tuning Knobs for the design rationale). **Pass when**: zero BOSS entries where any Boss-grade pool part lacks such a condition. **The AC asserts the product, never a hardcoded multiplier** — at the current base rate the threshold works out to ×500 (aligned with Part DB AC-11's break condition floor). The invariant survives base-rate retuning: if `BASE_DROP_BOSS_GRADE` is tuned to 0.0002, a stored ×500 (product 0.1 < 0.5) correctly **fails** — content authors must raise the multiplier to maintain the design target. **Cross-system alignment:** at current values, a ×500 multiplier satisfies both Part DB AC-11 (≥ 500) and this invariant (0.001 × 500 = 0.5 ≥ 0.5); **assert the boundary**: multiplier = 500 → product 0.5 → passes; multiplier = 499 → product 0.499 → fails (fails both ACs). Policy note: the Drop System GDD must define a pity floor (guaranteed at N qualifying breaks) that bounds the worst-case tail at the current 50%-per-break rate — see OQ4. **Test type**: Content Validation.

### Runtime Behavior

**AC-ED-10** (BLOCKING): `EnemyDatabase.get_enemy(id)` lookup. **Pass when**: a valid id returns a non-null `EnemyData` whose `id` matches; unknown id, `""`, and `null` each return `null` with no exception. **Test type**: Unit.

**AC-ED-11** (DEFERRED): `spawn_enabled = false` exclusion from spawn table. **Pass when**: `EncounterZone.build_spawn_table(zone)` excludes the disabled enemy; `EnemyDatabase.get_enemy(id)` (per AC-ED-10) still returns the full entry. *Unblocks when: Encounter Zone GDD defines its spawn table build interface.* **Note**: the ADVISORY progression warning for a spawn-disabled BOSS is tested by AC-ED-17 (undeferred, DB-side) — this AC covers only the Encounter Zone integration behavior. **Test type**: Integration.

**AC-ED-12** (DEFERRED): Break event set semantics. **System under test: the Drop System's event-collection step** (per constraint ED3 — not Part-Break's emission). **Pass when**: given an enemy with two regions both emitting `"arm_broken"`, after both break in one battle, the Drop System's collected event set contains `"arm_broken"` exactly once and Formula 3 applies its multiplier once (EC-ED-07). *Unblocks when: Drop System GDD defines its event-collection interface AND explicitly specifies deduplicated-set semantics for fired events (per constraint ED3) — an interface that collects events as a multiset rather than a set does not satisfy this AC.* **Test type**: Integration.

### Content Rules

**AC-ED-13a** (ADVISORY): Reserved `tier` field. `tier == 1` for all MVP entries — other values emit a warning in the validation report, never a failure (EC-ED-12). **Test type**: Content Validation.

**AC-ED-13b** (BLOCKING): Flavor text length. `flavor_text.length() <= FLAVOR_TEXT_MAX` where `FLAVOR_TEXT_MAX` is a **shared config constant** (currently 100) — never a literal in validator code. Boundary explicit: a 100-char string **passes**, a 101-char string **fails**. *Sync note: Part DB does not yet enforce a flavor_text length AC; both schemas must read the same constant, so a Part DB ratification of a different value is a one-line config change, not an AC rewrite (Rule 1 alignment note).* **Test type**: Content Validation.

**AC-ED-14** (ADVISORY): EDB-2 **computed TTK** validator. For every enemy, compute per defense channel:

```
dmg_armor  = floor( A_cal² / (A_cal + stats.get("armor", 0)) )
dmg_resist = floor( A_cal² / (A_cal + stats.get("resistance", 0)) )
TTK        = ceil( stats.get("structure", 0) / dmg )        # per channel
```

**Safe access required:** AC-ED-14 must not assume AC-ED-05 has already run. All stat lookups use `.get(key, 0)` so the validator does not crash on entries with absent stat keys (EC-ED-06: absent = 0). At D=0 (armor or resistance absent), `A_cal²/(A_cal+0) = A_cal` — produces maximum damage and minimum TTK; the WILD_POWER_CAP (AC-ED-05c) is the guard for zero-defense content, not this validator.

with `A_cal` = 35 (WILD-early), 53 (WILD-mid, BOSS). **Pass when** the validator is implemented and emits a warning (never a failure) whenever either channel's TTK falls outside the class band: WILD-early 2–4, WILD-mid 3–5, BOSS 12–18. **Boundary direction explicit**: TTK exactly **at** a band edge produces **no warning** (BOSS TTK = 12 → silent; TTK = 18 → silent); one turn outside warns (TTK = 11 → warning; TTK = 19 → warning). This computed check replaces static per-stat range checks as the normative gate — it jointly bounds structure × defense (a BOSS with Armor 55 + Structure 594 → dmg 26 → TTK 23 → **warns**, even though each stat is individually within guidance ranges). Power/defense stat guidance ranges from the EDB-2 table remain authoring reference only, not validated assertions. WILD-early vs WILD-mid classification for A_cal selection: MVP has one zone — classify by structure guidance band (< 90 → early, A_cal=35, band 2–4; ≥ 90 and enemy_class WILD → WILD-mid, A_cal=53, band 3–5; enemy_class BOSS → BOSS, A_cal=53, band 12–18); revisit when tiers activate. **Classification boundary fixtures**: WILD entry with `structure = 89` → WILD-early (A_cal=35, warns if TTK outside 2–4); WILD entry with `structure = 90` → WILD-mid (A_cal=53, warns if TTK outside 3–5). **Dual-channel fixture**: BOSS entry with `armor=5, resistance=60, structure=400` → `dmg_armor = floor(2809/58) = 48`, `TTK_armor = ceil(400/48) = 9` (warns — below 12–18 band); `dmg_resist = floor(2809/113) = 24`, `TTK_resist = ceil(400/24) = 17` (silent — in band). A validator checking only one channel would miss the armor-channel warning in this case. Float-safety: verified no float/int divergence across the full input space (2026-07-09 scan); implement in integer arithmetic. **Why ADVISORY (not BLOCKING):** TTK-band violations are balance-pacing concerns, not correctness failures — content outside the band is functional; fight pacing departs from design intent but the game does not break. Advisory classification lets pre-Alpha content iterate without hard-failing on balance exploration. Consider upgrading to BLOCKING before Beta content lock. **Degenerate floor note:** TTK=2 for WILD-early is only achievable via Armor=0 content — the same degenerate scenario the WILD_POWER_CAP's derivation names as the build-failure floor (see EDB-2 TTK lower bound note). At reference D=20, the minimum TTK within the structure guidance range (60+) is 3. AC-ED-14 does not warn on TTK=2 because 2 is inside the stated 2–4 band; the WILD_POWER_CAP (AC-ED-05c) is the actual guard for zero-Armor content. The AC exists so the warning surface is real and tested — a "warning" with no implemented validator is a promise with no mechanism. **Test type**: Content Validation (ADVISORY).

**AC-ED-15** (ADVISORY, except where noted): Content density counts. (a) `break_regions.size() > 3` warns (MVP intent 2–3; minimum 1 is BLOCKING via AC-ED-07(e)); (b) WILD `loot_pool.size()` warns when `size < 2 OR size > 4`; BOSS warns when `size < 4 OR size > 6`; empty pool is BLOCKING via AC-ED-04(f). **Boundary explicit**: WILD size=2 → silent; WILD size=1 → warns (also BLOCKING at AC-ED-04(f) if that 1 part is disabled); WILD size=4 → silent; WILD size=5 → warns. BOSS size=4 → silent; BOSS size=3 → warns; BOSS size=6 → silent; BOSS size=7 → warns. **Cross-AC note**: a pool of size=1 with 1 valid enabled part passes AC-ED-04 (not empty, not all-disabled) but still warns at AC-ED-15(b) — both checks run independently; (c) **BLOCKING — harvest-decision rule (Rule 6)**: for every entry, `loot_pool.size() > break_regions.size()` — equality or less fails; boundary explicit: 2 regions + 3 pool parts **passes**, 2 regions + 2 pool parts **fails**; minimum-case boundary: 1 region + 1 pool part **fails** (equality), 1 region + 2 pool parts **passes**; (d) ADVISORY — null-element density (EC-ED-05): if the count of `WILD` entries with `core_element == null` exceeds `NULL_ELEMENT_MAX_WILD` (currently 1), emit a zone-level warning — boundary: 1 null-element WILD silent, 2 warns. **Test type**: Content Validation.

**AC-ED-16** (DEFERRED): Null `core_element` integration path. **Pass when**: an enemy with `core_element = null` passed through Turn-Based Combat into `compute_damage()` produces no crash and applies `T = 1.0` (DF-1 EC-04 fallback). Expected value derived **from DF-1 itself** (damage-formula.md Formula DF-1: `max(DAMAGE_FLOOR, floor(A²/(A+D) × T × crit_mult + EPSILON))`), not from the EDB-2 calibration table: Volt skill at A=53, D=30, T=1.0, crit_mult=1.0 → `floor(2809/83 + ε) = floor(33.84...) = 33` — returns 33, not 50 (the ×1.5 value). A deferred implementer can verify 33 independently from the DF-1 definition. *Unblocks when: Turn-Based Combat GDD defines its damage call contract.* **Test type**: Integration.

**AC-ED-17** (ADVISORY): Spawn-disabled `BOSS` progression warning — **Enemy Database validator, not deferred.** **Pass when**: the Enemy Database content validator emits an ADVISORY warning in the validation report for every `BOSS` entry where `spawn_enabled == false` — signals a potential progression soft-lock if any zone gates boss-defeat on this entry (EC-ED-09). This check requires no Encounter Zone GDD; it is a property of the enemy schema state alone. **Boundary**: `BOSS` entry with `spawn_enabled == true` → no warning; `BOSS` entry with `spawn_enabled == false` → 1 ADVISORY warning. `WILD` entries with `spawn_enabled == false` → no warning (progression gating only applies to bosses). **Relationship to AC-ED-11**: AC-ED-11 (DEFERRED) tests the Encounter Zone's spawn-table exclusion — a different concern. This AC tests only the Enemy Database validator's warning emission. **Test type**: Content Validation (ADVISORY).

**AC-ED-18** (ADVISORY): Floor loot rarity rule (Rule 6). **Pass when**: for every enemy entry, every pool part with `rarity == RARE` or `rarity == BOSS_GRADE` has at least one `drop_conditions` entry whose `condition` matches one of this enemy's `break_event` values across all regions. **Warning when**: a Rare or Boss-grade pool part has zero matching conditions — it is an un-gated Rare, violating the floor loot rarity rule (a Rare that drops without any break execution undermines Pillar 2). **Happy path**: pool = [Common part (no conditions, valid floor loot) + Rare part with `drop_conditions: [{condition: "arm_broken", multiplier: 500}]`] on an enemy with `break_event: "arm_broken"` → passes with zero warnings. **Counter-example**: same setup but Rare has `drop_conditions: []` → warns. **Boundary**: the condition lookup checks the full set of `break_event` values across all this enemy's regions, not just region 0. **Test type**: Content Validation (ADVISORY).

**AC-ED-19** (ADVISORY): Minimum break-gated parts count (Rule 6). **Pass when**: for every enemy entry, the count of pool parts that have at least one `drop_conditions` entry referencing any of this enemy's `break_event` values is ≥ 2. **Warning when**: count = 0 or count = 1 — fewer than two break-gated parts means the player's "which region?" prioritization choice is degenerate. **Boundary**: 2 break-gated parts + 1 Common floor loot → passes; 1 break-gated Rare + 2 Common floor loot → warns; 3 break-gated parts → passes. **Interaction with AC-ED-07(b) and AC-ED-18**: AC-ED-07(b) validates per-region loot connectivity; AC-ED-18 validates per-Rare-part break-gating; this AC validates pool-level harvest-choice diversity. These three checks are distinct and all run. **Test type**: Content Validation (ADVISORY).

**AC-ED-20** (ADVISORY): EC-ED-07 positive case — shared `break_event` is valid. **Pass when**: an enemy with two or more regions sharing the same `break_event` value (e.g., both regions have `break_event = "arm_broken"`) passes content validation with no failure and no warning. **Guard against**: a validator that unique-checks `break_event` values (confusing them with `region_id` uniqueness from AC-ED-07(c)) incorrectly fails this valid configuration. **Boundary**: two regions with identical `break_event = "arm_broken"` → passes (set semantics, EC-ED-07); two regions with identical `region_id = "left_arm"` → fails (unique-id rule, AC-ED-07(c)). The distinction is that event names share a vocabulary while region ids must be unique within an enemy entry. **Test type**: Content Validation (ADVISORY).

## Open Questions

1. **Full Vision boss assembly migration (owner: game-designer, resolve: before Full Vision zone 2 content):** Rule 3 reserves the path to migrate `BOSS` entries from hand-authored stats to true part-assembly (stats derived via Part DB Formula 1). This requires deciding whether boss "equipped parts" become their literal loot pool. No MVP action; revisit when the Synergy System makes assembled bosses meaningful ("bosses use advanced synergies" — game concept).
2. **Compound break events (owner: systems-designer, resolve: with Drop System GDD):** EC-ED-07's set semantics mean double-breaks can't be rewarded more than single breaks. If playtesting shows players want "break everything" incentives, a compound event vocabulary (`"all_regions_broken"`, `"both_arms_broken"`) must be added to the Part DB drop_conditions vocabulary — Drop System GDD should reserve the naming pattern.
3. **Enemy resource economy symmetry — RESOLVED 2026-07-10 (TBC Rule 8 ratifies ED1 in the simplified direction).** Enemies track **no Heat and no Energy**: their moves are always available and they never Overheat (TBC Rule 8, AC-TBC-02). The `cooling`, `energy_capacity`, and `recharge` keys in enemy stat blocks are therefore **dead data in MVP** (see Rule 3 dead-data note); content validation SHOULD warn when an enemy entry authors non-zero values for those three keys. Statuses still apply to enemies normally (Burn ticks on enemy turns; Shock lowers enemy initiative). *(Confirmed by /review-all-gdds cross-check 2026-07-10, finding W-5.)*
4. **Boss-grade acquisition policy and bad-luck protection — RESOLVED 2026-07-10 (Drop System GDD).** Acquisition = ~50% per qualifying break (×500 multiplier on the 0.001 base = `BOSS_GRADE_BREAK_GUARANTEE`), and the worst-case tail is bounded by **DS-3 (BGDF-1), `M_BOSS_PITY = 8`**: after 8 consecutive qualifying-break drop-roll failures, the next qualifying break is guaranteed. This is a drop-RNG floor only; repeated break *failure* remains Part-Break's DB3. Rare bad-luck protection is subsumed by the non-diluting roll model (see OQ-5 below) — per-target Rare rate is the base rate, not a pool-diluted fraction. *(Original text retained below for provenance.)* —**Design decision set in this schema (see `BOSS_GRADE_BREAK_GUARANTEE = 0.5` in Tuning Knobs):** **Design decision set in this schema (see `BOSS_GRADE_BREAK_GUARANTEE = 0.5` in Tuning Knobs):** Boss-grade drops target ~50% per qualifying break, averaging ~2 attempts per exclusive. This preserves acquisition tension while keeping MVP Boss-grade content obtainable within a handful of boss sessions. The Drop System GDD must: (a) define a pity floor (guaranteed acquisition at N qualifying breaks) that bounds the worst-case tail — a player who correctly breaks the gating region 4+ times without a drop should be guaranteed on the next attempt; AC-ED-09's product invariant accommodates any pity value without schema changes; (b) address Rare bad-luck protection — at pool-diluted rates (~6–8% per fight at WILD-early minimum), a player has a ~42–52% chance of zero target-Rare drops in 10 fights; **mobile session note (more representative of the primary platform):** at 5-fight mobile sessions, P(zero target-Rare) = 64–72% — the majority of sessions end with no progress toward a specific Rare; the "deliberate, learnable hunting" fantasy requires that skill expression reduces wait time predictably; the Drop System GDD must take an explicit position (pity counter, streak-breaker, or a documented decision to accept variance with that statistic acknowledged).
5. **Pool-size dilution vs. Part DB "3–5 attempts" framing — RESOLVED 2026-07-10 (Drop System GDD): option (b), non-diluting independent rolls.** Each part in a loot pool rolls independently at its full base rate × conditions (Drop System Rule 2 / AC-DS-12) — **no pool-size division**. This eliminates the BOSS-Rare-harder-than-WILD structural inversion and keeps Part DB's base-rate framing valid (per-target Rare rate = base rate, not a diluted fraction). A single fight may yield multiple parts. A content-authoring cap (≤2 Common slots per WILD pool, ≤3 per BOSS) prevents Common flooding under independent rolls. *(Original text retained below for provenance.)* —**This schema's position:** **This schema's position:** pool-size ranges are locked as authored (WILD 2–4, BOSS 4–6; effectively floor 3 from Rule 6's harvest-decision rule). These produce the following per-target Rare rates and expected fight counts **if the Drop System divides by pool size**: WILD min (pool=3) → 8.33% → ~12 fights; WILD max (pool=4) → 6.25% → ~16 fights; BOSS mid (pool=5) → 5% → ~20 fights; BOSS max (pool=6) → 4.17% → ~24 fights. Part DB's "~3–5 attempts" framing assumes pool size 1 and is structurally unreachable at these ranges — it is a framing for the base rate, not the effective per-target rate. **The Drop System GDD is hard-blocked on taking one of three explicit positions** before it can be designed: (a) accept pool-size dilution and update the Part DB framing to reflect actual expected fight counts (~12–24 WILD/BOSS fights per target Rare); (b) adopt a non-diluting roll model (each part rolled independently at base rate, eliminating pool-size penalties and the BOSS-Rare-harder-to-farm-than-WILD structural inversion); or (c) apply pool-size rate compensation (scale base rate up with pool size to hold farming time constant). This Enemy DB GDD states its pool-size choices and their implied math; the Drop System GDD owns the resolution.
6. **Roster-level coverage validation (owner: TBD — Encounter Zone GDD or a dedicated content-lint tool; resolve: before MVP content authoring completes):** Pillar 5 ("every enemy worth hunting") is unenforceable per-enemy. Three roster-level checks need a home: (a) reverse coverage — every drop-enabled Part DB entry appears in ≥ 1 loot pool; (b) slot/element coverage — the zone's union of pools spans all slot types and elements (no starved build paths); (c) `part_family` progression arcs — a family's Common/Rare/Boss-grade variants are distributed coherently across enemy tiers (no skipped rungs). A single Enemy Database entry cannot see the roster; this schema's per-enemy ACs deliberately exclude these.
7. **Minimum-meaningful break multiplier — RESOLVED 2026-07-11 (owner: Drop System GDD).** The Drop System GDD now defines **`MULTIPLIER_FLOOR = 1.5`** (Drop System Rule 5a): a `drop_conditions` multiplier `≥ 1.5` is a valid incentive; a multiplier in `(1.0, 1.5)` is a **content warning** ("sub-threshold — raise or remove"); a multiplier `≤ 1.0` is a **content error**. This gives AC-ED-03's syntactic `loot_connected` check the functional floor it lacked — a break event that is referenced must now *materially* tilt the drop rate, not merely appear. Boss-grade parts keep the separate, higher ≥ ×500 floor (Part DB AC-11). *(Original text retained below for provenance.)* AC-ED-03's `loot_connected` check is syntactic-only — it verifies that a break event appears in at least one pool part's drop_conditions, but does not inspect the multiplier value. A multiplier of ×1 satisfies the check but provides no harvest incentive (drop rate unchanged from base rate). Without this floor, authors can satisfy loot_connected and Pillar 2 syntactically while providing no actual hunting incentive.
