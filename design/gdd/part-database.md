# Part Database

> **Status**: Approved (Round 8 + visual amendment 2026-07-10)
> **Author**: Luan + Claude Code (game-designer)
> **Last Updated**: 2026-07-10
> **Implements Pillar**: Pillar 1 (Engineer, Don't Collect), Pillar 3 (Build Depth Over Content Breadth), Pillar 4 (Synergy Is the Endgame)

## Summary

The Part Database defines every collectible Sympart in Symbots: its slot type, stats, element, synergy tags, moves, and rarity. It is the read-only schema that all downstream systems — Assembly, Combat, Drop tables, Inventory, Workshop, and more — query to understand what a part does.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

Symparts are the atoms of Symbots — the things players hunt, theorize about, and build with. Every part a player collects, equips, or crafts is defined by its entry in the Part Database: the slot it occupies on a Symbot's body, the stats it contributes, the element it carries, the synergy tags that let it interact with other parts, the moves it unlocks in combat, and the rarity tier that signals how difficult it was to acquire.

The Part Database is the authoritative catalog of every Sympart definition in the game. It does not store inventory state (what the player currently holds) or equipped state (what is installed on a Symbot) — those belong to the Inventory and Workshop systems respectively. The Part Database is read-only from a gameplay perspective: it defines what exists in the world. All downstream systems — Symbot Assembly, Synergy, Turn-Based Combat, Drop System, Inventory, Workshop, World Loot, Enemy Database, and Blueprint Crafting — query this database to understand what a part does. No system may define part behavior outside this document.

## Player Fantasy

The player never thinks "I am querying the Part Database." They think: *"Wait — a Servo Arm with both the Ironclad tag and Volt element? That would complete my 4-piece Ironclad-Volt synergy build."* *(The synergy payoff — the bonus triggered when all 4 matching parts are equipped — is defined by the Synergy System GDD, not this document. The Part Database's role is ensuring the schema can encode the tags and elements that make that moment possible.)*

The Part Database is the inventory of possibility. When a player opens the workshop and sees parts they haven't used yet, they see hypotheses. When a new zone drops an unfamiliar part in a slot they've never built around, they feel the world opening. The schema makes those moments possible — every field in the Part Database is a dimension of the game's possibility space.

This system exists to make the collection feel meaningful before a single battle is fought. A well-designed part catalog ensures that every drop has the potential to change a player's build direction — and that every combination the player imagines can be rigorously constructed. The Part Database is the promise that the game keeps every time a part drops.

## Detailed Design

### Core Rules

**Rule 1 — The Sympart Schema**

Every Sympart in the game is defined by the following fields. The Part Database stores one definition per part type; the Inventory system stores instances:

| Field | Type | Description |
|-------|------|-------------|
| `id` | StringName | Unique identifier (e.g., `"boltwell_spark_core"`) |
| `display_name` | String | Player-visible name (e.g., "Spark Core") |
| `slot_type` | Enum | One of: `CORE, CHASSIS, CHIPSET, ENERGY_CELL, HEAD, ARMS, LEGS, WEAPON` |
| `chassis_archetype` | Enum | Chassis archetype defining stat multipliers: one of `LIGHT_FRAME, HEAVY_FRAME, BALANCED_FRAME, GUARDIAN_FRAME, ARTILLERY_FRAME`. `null` for all non-CHASSIS slot types. Required when `slot_type = CHASSIS`; must be `null` otherwise. See Rule 3 and Formula 1. |
| `rarity` | Enum | `COMMON, RARE, BOSS_GRADE, PROTOTYPE` |
| `manufacturer` | StringName | `"boltwell"`, `"ironclad"`, `"scrapjaw"`, or `"wild"` (no manufacturer) |
| `element` | Enum | `VOLT, THERMAL, KINETIC` (MVP); `CRYO, CORROSIVE, DATA` reserved for Full Vision |
| `damage_type` | Enum | `PHYSICAL` or `ENERGY` (MVP); `DATA, TRUE` reserved for Full Vision |
| `stat_bonuses` | Dictionary | Stat name → integer bonus (e.g., `{ "structure": 40, "armor": 12 }`) |
| `active_skill_id` | StringName | Reference to Move Database entry; `null` if no active skill |
| `passive_id` | StringName | Reference to Passive Database entry; `null` if no passive |
| `synergy_tags` | Array[StringName] | List of synergy group IDs this part belongs to |
| `drop_conditions` | Array[Dictionary] | Condition → drop rate multiplier pairs |
| `max_upgrade_tier` | int | Maximum upgrade tier for this part: `3` (Common), `5` (Rare / Boss-grade / Prototype) |
| `upgrade_effects` | Array[Dictionary] | Optional per-tier unlocks (tiers 1–5). Each entry: `{ tier, effect_type, description, skill_id }`. `effect_type` is one of `SKILL_UNLOCK`, `SKILL_ENHANCE`. (`STAT_BONUS` is reserved for Full Vision — not used in MVP; stat scaling is handled entirely by Formula 2.) Empty array for Common parts and Rare+ parts with no defined unlock. Only specific unique boss drops define entries at tiers 4–5. |
| `drop_enabled` | bool | `true` = appears in drop tables; `false` = no longer obtainable but remains valid in all existing inventories |
| `part_family` | StringName | Optional grouping ID for thematic variants of the same concept (e.g., `"servo_arm_family"` groups Common / Rare / Boss-grade versions of Servo Arm). `null` for unique parts with no variants. |
| `heat_generation` | int | Heat generated per use of `active_skill`; 0 if no skill |
| `ammo_cost` | int | Ammo consumed per skill use; 0 if not ammo-based |
| `flavor_text` | String | One-line lore description shown in UI |
| `sprite_id` | StringName | Art asset identifier for this part's visual representation on a Symbot. The Symbot renderer and Workshop UI look up this ID to swap the sprite for the affected visual zone when the part is equipped. Required for all parts — must be non-null and non-empty. |
| `level_requirement` | int | Core level required to equip this part. Authoring floors by rarity (CP Rule 5): COMMON=1, RARE=3, BOSS_GRADE=6, PROTOTYPE=8. Individual parts may have a higher `level_requirement` than their rarity floor; never lower. `null` or 0 defaults to no gate (treated as 1). *(Core Progression erratum 2026-07-12.)* |
| `level_growth` | Dictionary[String, int] | Per-level flat stat bonus applied by CP-F3 (Core Progression); **non-null only on CORE-slot parts**. Key = canonical stat name; value = flat bonus per level. Empty dict or `null` for all non-CORE parts — Assembly ignores `level_growth` on non-CORE slots. *(Core Progression erratum 2026-07-12.)* |

Fields reserved for later content (must be in schema now, `null` in MVP content): `motherboard_slot_type`, `ram_cost`, `weight_class`, `modification_slots`.

---

**Rule 2 — The 8 MVP Slot Types**

Each slot has a defined function on the Symbot. A Symbot always has exactly 8 parts equipped (one per slot). Empty slots are not permitted — every slot ships with a starter part that the player replaces during play.

| Slot | Function | Stat Focus | Skill |
|------|----------|------------|-------|
| **Core** | Identity. Defines the Symbot's primary element and manufacturer affiliation. The Core is what makes a Symbot "itself" when all other parts are swapped. | Energy Capacity, Recharge. *("Element-specific boost" is an authoring convention, not a schema field: a Core's `stat_bonuses` are authored to favor stats thematic to its element. No formula reads an element-boost value.)* | Unique trait — a passive via `passive_id`, required at Rare+. **Core parts never define an active skill at any rarity** (Rule 8 Core exception). |
| **Chassis** | Frame. Defines the combat archetype (Light / Heavy / Balanced / Guardian / Artillery). Determines Structure, defensive profile, and weight class. | Structure, Armor, Resistance | None (archetype determines implicit behavior) |
| **Chipset** | Logic. Defines the Symbot's processing intelligence — status effect strength, scan reliability, and Processing power. | Processing, RAM (capacity for future Software slots) | None in MVP |
| **Energy Cell** | Power. Defines the Symbot's Energy architecture — how much Energy it holds and how fast it regenerates. | Energy Capacity, Recharge | None |
| **Head / Sensor** | Perception. Defines targeting accuracy, drop hunting capability, and scan range. The Head determines whether the player sees detailed enemy part information before battle. In MVP, this information advantage is delivered as a UI feature (enemy part display) rather than a stat mechanic — Salvage Rating is reserved for Full Vision. The Combat UI and Workshop UI GDDs are responsible for implementing this display. | Targeting (MVP); Salvage Rating (Full Vision reserved) | 1 scan or utility skill |
| **Arms** | Action. Defines physical and energy manipulation — the Symbot's active combat tool beyond its weapon. | Physical Power or Energy Power | 1 active skill (attack, repair, or utility) |
| **Legs** | Mobility. Defines movement profile and stability. Each Leg type has a distinct behavior archetype — not just a speed bonus. | Mobility, Evasion | 1 passive terrain/movement effect |
| **Weapon** | Offense. Defines the primary damage source. Weapon type determines damage type (Physical or Energy), resource (Energy or Ammo), and primary combat skill. | Physical Power or Energy Power (by type) | 1 primary combat skill |

---

**Rule 3 — Chassis Archetypes**

The Chassis slot determines the Symbot's combat role archetype. Each archetype applies a modifier to the stat bonuses from ALL equipped parts on that Symbot:

| Archetype | Archetype Bonus | Archetype Penalty |
|-----------|-----------------|-------------------|
| **Light Frame** | +20% Mobility | −15% total Structure |
| **Heavy Frame** | +25% total Structure, +20% Armor | −20% Mobility |
| **Balanced Frame** | +5% Processing, +5% Cooling | None |
| **Guardian Frame** | +20% Resistance | −15% Physical Power |
| **Artillery Frame** | +20% Energy Power | −15% Armor |

Chassis archetype bonuses are applied after summing all part `stat_bonuses`, not per-part.

---

**Rule 4 — The Stat System (MVP Stats)**

Eleven stats define a Symbot's combat capabilities. All stats are integers. Every part contributes flat bonuses; there are no percentage bonuses from parts (only from synergy effects and Chassis archetype modifiers).

| Stat | Robotic Term | What It Does |
|------|-------------|--------------|
| HP | **Structure** | Total damage a Symbot can absorb before defeat. Reaches 0 = Symbot is disabled. |
| Physical defense | **Armor** | Reduces incoming Physical damage via the damage formula. |
| Energy defense | **Resistance** | Reduces incoming Energy damage via the damage formula. |
| Physical attack | **Physical Power** | Base multiplier for Physical-type skill damage. |
| Energy attack | **Energy Power** | Base multiplier for Energy-type skill damage. |
| Speed / initiative | **Mobility** | Determines turn order. Contributes to Evasion chance (derived). |
| Accuracy | **Targeting** | Determines hit chance and contributes to Critical Rate (derived). High Targeting enables accurate part-break targeting feedback. |
| Intelligence | **Processing** | Governs status effect success chance, scan quality, and repair efficiency. |
| Heat recovery | **Cooling** | Heat reduced at the start of each Symbot's turn. If Heat reaches 100, Overheat triggers. |
| Energy capacity | **Energy Capacity** | Maximum Energy pool. Consumed by Energy-based skills. Regenerated by Recharge at turn start. |
| Energy regen rate | **Recharge** | Bonus Energy regenerated at turn start, added to the fixed base regen of 10. Per-part range: 0–15. **Schema rule (enforced):** only Energy Cell and Core parts may have a non-zero `stat_bonuses["recharge"]` value — see AC-18. The total recharge_bonus across all 8 equipped parts ranges 0–30 (two contributing parts × 15 each). |

Reserved for Full Vision (present in schema, null/0 in MVP content): `Evasion` (derived from Mobility), `Critical Rate` (derived from Targeting), `Critical Output`, `Ammo Capacity`, `RAM`, `Firewall`, `Repair Power`, `Salvage Rating`, `Shield Integrity`, `Capacitor Output`.

---

**Rule 5 — The Combat Resource System (MVP)**

Every Symbot tracks 3 combat resources during battle. These are runtime values — not stored in the Part Database, but their maximum values are computed from part stats:

| Resource | Derived From | What Happens at Limit |
|----------|-------------|----------------------|
| **Structure** | Sum of all part Structure bonuses (modified by Chassis) | At 0: Symbot is defeated |
| **Energy** | Energy Capacity stat | At 0: cannot use Energy-based skills until Recharge restores some |
| **Heat** | Starts at 0; maximum is 100 | At 100: Overheat — Symbot skips next turn, loses 10% of max Structure |

Recharge per turn: each Symbot regenerates 10 + (sum of Recharge stat bonuses from all equipped parts) Energy at the start of its turn.

Heat decay per turn: Cooling stat is subtracted from current Heat at the start of each Symbot's turn.

---

**Rule 6 — The Element System (MVP)**

Three elements exist in MVP. Every part carries exactly one element tag. The Core determines the Symbot's "primary element" for visual and identity purposes, but every equipped part contributes its element tag to the Synergy System.

| Element | Concept | Beats | Weak To |
|---------|---------|-------|---------|
| **Volt** | Electrical surge, circuit disruption | Thermal | Kinetic |
| **Thermal** | Heat, combustion, Overheat pressure | Kinetic | Volt |
| **Kinetic** | Impact, force, structural damage | Volt | Thermal |

**Type effectiveness multipliers:**
- Super effective: ×1.5
- Neutral: ×1.0
- Not very effective: ×0.75

Type effectiveness applies when skill element is compared against the defender's Core element. Full specification in Damage Formula GDD.

---

**Rule 7 — The Synergy Tag System**

Every part carries a `synergy_tags` array. Tags are StringName identifiers. Two tag types are mandatory for MVP content:

**Element tags** (always present for all parts — including wild-manufacturer parts — matches `element` field):
`"volt"`, `"thermal"`, `"kinetic"`

Wild parts carry an element that reflects their thematic nature (e.g., a scrap-metal structural part is Kinetic, a junk capacitor is Volt). Content authors must assign an element to every part including wild; `synergy_tags` is never empty for any part.

**Manufacturer tags** (always present for non-"wild" parts, matches `manufacturer` field):
`"boltwell"`, `"ironclad"`, `"scrapjaw"`

Wild-manufacturer parts carry no manufacturer tag — their `synergy_tags` array contains only their element tag.

**Optional boss-origin tags** (reserved for Full Vision):
e.g., `"boss_rustcrawler"` — enables Architecture Synergy combinations.

The Synergy System GDD defines what bonuses these tags trigger and at what thresholds (2-part, 3-part, 4-part). The Part Database only defines which tags a part carries.

---

**Rule 8 — Rarity Tiers (MVP)**

Four rarity tiers in MVP. Rarity governs which schema fields are permitted to be non-null for a given part:

| Rarity | Stats | Active Skill | Passive | Drawback |
|--------|-------|-------------|---------|---------|
| **Common** | Base stat contributions only | None (`null`) | None (`null`) | None |
| **Rare** | Higher stat contributions | 1 skill (required) | None (`null`) | None |
| **Boss-grade** | High stat contributions + exclusive synergy bonus | 1 skill (required) | 1 passive (required) | None |
| **Prototype** | Very high in 1–2 focus stats (may exceed Boss-grade focus stat at +5 when Boss-grade budget is spread across multiple stats — the intended content convention; see Stat Budget Reference); lower or negative in others | 1 skill (required) | 1 passive (required) | Mandatory drawback (e.g., +30 Heat per use, stat penalty, jam chance) |

**Core slot exception (skill/passive rules):** Core parts never define an active skill — `active_skill_id` is `null` at every rarity. In place of the active-skill requirement, Rare and higher Core parts require a passive (`passive_id` non-null): the "unique trait" from Rule 2. This makes Core the only slot whose Rare-tier power is expressed as identity (a passive trait) rather than an action. Common Cores, like all Commons, have neither skill nor passive. Consequently, Core parts must not define `upgrade_effects` entries of type `SKILL_UNLOCK` (which would add an active skill); `SKILL_ENHANCE` targeting the Core's passive is permitted. AC-01 validates this exception.

Boss-grade parts are only obtainable by breaking a specific boss part region before defeating the boss. They cannot appear in wild drop tables. Prototype parts are **gradient conditional drops**: each battle condition the player fires multiplies the base rate per Formula 3; optimal play — firing all of a part's listed conditions — reaches the ~15–20% target band. Partial execution yields a partial rate, not zero (e.g., 2 of 3 ×1.5 conditions: 0.05 × 1.5 × 1.5 ≈ 11%). Every condition met visibly improves the odds — there is no all-or-nothing gate.

---

**Rule 9 — Drop Conditions**

Each part definition's `drop_conditions` array specifies how the player's battle behavior modifies the chance of this part dropping. The array is evaluated by the Drop System:

```
drop_conditions: [
  { condition: "arm_broken",           multiplier: 1.5 },
  { condition: "defeated_by_thermal",  multiplier: 0.7 },
  { condition: "targeting_active",     multiplier: 1.3 }
]
```

Multipliers stack multiplicatively. All matching conditions are evaluated. The per-rarity base drop rate (a config constant, not a per-part field — see Formula 3) is the starting probability; conditions modify it up or down. Full condition vocabulary is defined in the Drop System GDD.

---

**Rule 10 — Upgrade Tiers**

The Part Database defines how a part improves when upgraded. Upgrade tier is tracked per-instance in the Inventory system (each player-owned copy has its own tier).

| Upgrade Tier | Stat Effect | Skill Effect |
|-------------|-------------|-------------|
| +0 (base) | As defined in `stat_bonuses` | As defined in `active_skill_id` |
| +1 | ×1.15 to all stat bonuses (Formula 2) | Defined per-part in `upgrade_effects[1]` if present; otherwise none |
| +2 | ×1.30 to all stat bonuses (Formula 2) | Defined per-part in `upgrade_effects[2]` if present; otherwise none |
| +3 | ×1.50 to all stat bonuses (Formula 2) | Defined per-part in `upgrade_effects[3]` if present; otherwise none |
| +4 | ×1.70 (Rare+ only) | Defined per-part in `upgrade_effects[4]` if present; otherwise none |
| +5 | ×2.00 (Rare+ only) | Defined per-part in `upgrade_effects[5]` if present; otherwise none |

Skill-level effects (Energy cost reduction, enhanced AoE, secondary trigger additions) are defined per-part in `upgrade_effects` and specified in the **Move Database GDD** — not in Part Database. Part Database stores the `upgrade_effects` array; the Move Database defines what each effect does at runtime.

Upgrade material requirements and Workshop level gates are defined in the **Workshop System GDD**.

---

### States and Transitions

The Part Database is a static data schema — part definitions do not have runtime states. No state machine applies.

Lifecycle note: Part definitions are added at content authoring time and removed from drop tables (not deleted) if retired from design. Retired parts are marked `drop_enabled = false` — they remain fully valid in the database and in all existing player inventories, but cannot be acquired through normal play. There is no `deprecated` status field. See EC-04.

---

### Interactions with Other Systems

| System | What It Reads | What It Expects |
|--------|--------------|-----------------|
| **Symbot Assembly** | `stat_bonuses` for all equipped parts; `slot_type` for slot validation | Every equipped slot has exactly one part with a matching `slot_type` |
| **Synergy System** | `synergy_tags` for all equipped parts | Tags are consistent with `element` and `manufacturer` fields |
| **Turn-Based Combat** | `active_skill_id` for move pool; `damage_type` for defense routing; `element` for type chart | Active skills reference valid Move Database entries |
| **Damage Formula System** | `element` for type effectiveness; `damage_type` for Armor/Resistance routing; `Physical Power` / `Energy Power` stat bonuses | Stat values are integers within specified ranges |
| **Part-Break System** | `drop_conditions` vocabulary; `active_skill_id` for skills with break keywords | Drop condition keys match Part-Break event vocabulary exactly |
| **Drop System** | `drop_conditions` array; `rarity` (used to look up the per-rarity base rate from tuning config — `base_drop_rate` is not a per-part field); `id`, `drop_enabled` | Drop condition keys match canonical event vocabulary |
| **Inventory System** | `id`, `display_name`, `rarity`, `slot_type`, `flavor_text`; `upgrade_effects` for upgrade UI | Part IDs are globally unique and stable across all content updates |
| **Workshop System** | Full schema for part comparison; `stat_bonuses` for stat delta display; `upgrade_effects` | Stat field names match Workshop UI display label mapping |
| **World Loot System** | `rarity` and `element` for chest loot table filtering; `id` for specific part placement | Every part referenced in World Loot tables exists in the Part Database |

## Formulas

### Formula 1 — Total Symbot Stat

```
final_stat[S] = max(0, floor( sum( upgraded_value[S] for each of 8 equipped parts ) × chassis_modifier.get(S, 1.0) + 0.0001 ))
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Stat being computed | S | StringName | Any stat key | e.g., `"structure"`, `"physical_power"` |
| Part upgraded value | `upgraded_value[S]` | int | −55–110 per part | Output of Formula 2 (if `stat_bonuses[S] > 0`, all rarities) or Formula 2b (if `stat_bonuses[S] < 0`, Prototype only) for this part at its current upgrade tier. See Formula Pipeline. |
| Sum of upgraded values | (implicit) | int | −440–880 | Sum of all 8 equipped parts' `upgraded_value[S]` for stat S |
| Chassis modifier | `chassis_modifier[S]` | float | 0.80–1.25 | Per-stat multiplier from Chassis archetype table |
| Result | `final_stat[S]` | int | 0–unbounded | Post-archetype value used by all combat systems |

**Chassis modifier table:**

| Archetype | Structure | Armor | Resistance | Physical Power | Energy Power | Mobility | Processing | Cooling |
|-----------|-----------|-------|------------|----------------|--------------|---------|------------|---------|
| Light Frame | ×0.85 | ×1.0 | ×1.0 | ×1.0 | ×1.0 | ×1.20 | ×1.0 | ×1.0 |
| Heavy Frame | ×1.25 | ×1.20 | ×1.0 | ×1.0 | ×1.0 | ×0.80 | ×1.0 | ×1.0 |
| Balanced Frame | ×1.0 | ×1.0 | ×1.0 | ×1.0 | ×1.0 | ×1.0 | ×1.05 | ×1.05 |
| Guardian Frame | ×1.0 | ×1.0 | ×1.20 | ×0.85 | ×1.0 | ×1.0 | ×1.0 | ×1.0 |
| Artillery Frame | ×1.0 | ×0.85 | ×1.0 | ×1.0 | ×1.20 | ×1.0 | ×1.0 | ×1.0 |

Stats not listed in the modifier table (Targeting, Energy Capacity, Recharge) use ×1.0 for all archetypes. Balanced Frame's ×1.05 to Processing and Cooling is in the table above — the table is the complete, authoritative implementation source; no modifier exists outside it. The `.get(S, 1.0)` in the formula expression returns the table value for stat S when present, or `1.0` when absent — both paths are valid. The modifier table is keyed by the `chassis_archetype` field of the equipped Chassis part (see Rule 1 schema).

**Output range:** 0 to unbounded. The outer `max(0, ...)` clamps to 0 — a chassis penalty or a Prototype drawback still active in `stat_bonuses` cannot produce a negative final stat. (`floor()` alone would not clamp at 0; it floors toward negative infinity.) Re-computed at battle start and whenever a part is swapped in Workshop.

**Worked example:**
Heavy Frame Symbot. All parts sum to: Structure 90, Mobility 40, Armor 30.
- `final_stat["structure"]` = floor(90 × 1.25) = **112**
- `final_stat["mobility"]` = floor(40 × 0.80) = **32**
- `final_stat["armor"]` = floor(30 × 1.20) = **36**

---

### Formula 2 — Upgrade Tier Stat Bonus

```
upgraded_stat[S] = floor( base_stat[S] × upgrade_multiplier[tier] + 0.0001 )
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Part's base stat bonus | `base_stat[S]` | int | 0–55 | The +0 value from `stat_bonuses[S]`. **Never negative in Formula 2** — Prototype parts with negative `stat_bonuses[S]` are routed to Formula 2b instead (see Formula Pipeline). |
| Upgrade tier | `tier` | int | 0–3 (Common) or 0–5 (Rare+) | Player's current upgrade tier for this part instance; max determined by `max_upgrade_tier` |
| Tier multiplier | `upgrade_multiplier[tier]` | float | 1.00–2.00 | From table below |
| Result | `upgraded_stat[S]` | int | 0–110 | Used as `stat_bonuses[S]` input into Formula 1 |

**Tier multiplier table:**

| Tier | Multiplier | Available to |
|------|-----------|-------------|
| +0 | ×1.00 | All rarities |
| +1 | ×1.15 | All rarities |
| +2 | ×1.30 | All rarities |
| +3 | ×1.50 | All rarities |
| +4 | ×1.70 | Rare, Boss-grade, Prototype only |
| +5 | ×2.00 | Rare, Boss-grade, Prototype only |

Common parts are hard-capped at +3. Attempting to upgrade a Common part beyond +3 is blocked in the Workshop UI. The ×2.00 ceiling at +5 is intentional — a fully maxed boss drop is exactly twice as strong as its base, making the upgrade journey a meaningful long-term goal.

**Skill and effect unlocks:** At any tier from +1 to +5, a part may define an entry in `upgrade_effects`. Most parts have an empty array (stat scaling only). Specific high-rarity parts — primarily unique boss drops — define entries at +4 or +5 that unlock a new skill or enhance an existing one. Content design specifies which parts carry these unlocks; the schema enforces no minimum or maximum number of entries.

**Output range:** 0 to floor(55 × 2.00) = 110. Floored to integer.

**Worked example — Rare Weapon, Physical Power base 20:**
- +0: 20 | +1: 23 | +2: 26 | +3: 30 | +4: 34 | +5: **40**

**Worked example — Boss-grade Weapon with +5 unlock, Physical Power base 30:**
- +5 stat: floor(30 × 2.00) = **60**
- +5 effect: `upgrade_effects[5]` triggers (e.g., "Crushing Strike now ignores 40% of Armor and applies Shattered for 2 turns")

---

### Formula 2b — Prototype Drawback Reduction

Prototype parts carry a negative stat bonus (e.g., `stat_bonuses["armor"] = -15`). Upgrading a Prototype reduces the penalty toward 0; it never becomes a positive bonus.

```
upgraded_drawback[S] = -ceil( abs(base_stat[S]) × max(0, 1.0 - tier × (1.0/3.0)) - 0.0001 )
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base drawback | `base_stat[S]` | int | -55–-1 | Negative value from `stat_bonuses[S]` |
| Upgrade tier | `tier` | int | 0–5 | Player's current upgrade tier for this part |
| Result | `upgraded_drawback[S]` | int | -55–0 | Capped at 0; never becomes positive |

**Drawback by tier:**

| Tier | Scale factor | Effect on penalty |
|------|-------------|------------------|
| +0 | 1.00 | Full penalty |
| +1 | ~0.67 | ~2/3 of penalty |
| +2 | ~0.33 | ~1/3 of penalty |
| +3 | 0.00 | Penalty fully removed |
| +4 | 0.00 | Stays at 0 |
| +5 | 0.00 | Stays at 0 |

**Output range:** -55 to 0. `ceil()` ensures fractional reductions always favor the player by rounding toward 0.

**Clamp note (load-bearing):** The `max(0, …)` expression is mandatory. Without it, tier +4 computes `1.0 - 4×(1/3) = -0.33`, and the full expression becomes `-ceil(abs(base) × -0.33)` — a double negation producing a **positive stat value from a drawback field**, which violates the design intent. The `max(0, …)` must clamp the scale factor to zero before multiplication. Tiers +4 and +5 produce the same result as +3: zero penalty, zero bonus.

**Worked example — Prototype Arms, Armor drawback base -15:**
- +0: -15 | +1: -ceil(15 × 0.667) = -10 | +2: -ceil(15 × 0.333) = -5 | +3: 0 | +4: still 0 | +5: still 0

---

### Formula Pipeline — All Parts (Composition of F2, F2b, and F1)

**Formula 1 never receives raw `stat_bonuses[S]` values directly.** For every part at every rarity, `stat_bonuses[S]` is upgraded through Formula 2 (or Formula 2b for Prototype negative stats) before entering Formula 1's sum.

**For all parts (Common, Rare, Boss-grade, Prototype):**
1. Apply Formula 2 to each stat: `upgraded_value[S] = floor(stat_bonuses[S] × upgrade_multiplier[tier] + 0.0001)`
2. Sum `upgraded_value[S]` across all 8 equipped parts and pass into Formula 1 → `final_stat[S]`

At tier +0 the multiplier is ×1.00, so upgraded values equal base values — but the pipeline still applies. At higher tiers the upgrade multiplier scales the contribution.

**For Prototype parts only — additional routing for negative stats:**
Instead of routing all stats through Formula 2, route by sign of `stat_bonuses[S]`:
- If `stat_bonuses[S] > 0`: apply **Formula 2** → `upgraded_stat[S]`
- If `stat_bonuses[S] < 0`: apply **Formula 2b** → `upgraded_drawback[S]`
- If `stat_bonuses[S] = 0`: result is 0 (no scaling needed)

Formula 2 and Formula 2b (Prototype only) run in parallel on the same source `stat_bonuses[S]`. Their outputs are independent and both feed into Formula 1's sum.

**Numeric precision note (applies to Formulas 1, 2, and 2b):** All multiply-then-round operations use `floor(value + 0.0001)`; `ceil()` in Formula 2b is applied as `ceil(value - 0.0001)`. **Empirical status (verified by exhaustive IEEE 754 scan, 2026-07-09):** For Formula 2b the nudge is **load-bearing** — 26 inputs in the valid range produce the wrong result without it (e.g., `15 × (1 − 1/3)` evaluates to `10.000000000000002`; `ceil()` without the nudge returns penalty −11 instead of the correct −10). For Formulas 1 and 2, **no input in the current MVP ranges** (sums −440–880 with all tabled chassis modifiers; bases 1–55 with all five tier multipliers) changes result with or without the epsilon — there the nudge is a defensive convention, kept for uniformity and for safety if multipliers are retuned within their safe ranges (e.g., a future ×1.45 could introduce real cases). Implementations must apply the nudges or use equivalent integer-scaled arithmetic; do not remove them based on current-range behavior. *(Correction of earlier drafts: `float(20) × 1.15` evaluates to exactly `23.0` in IEEE 754 double precision, not `22.9999…` as previously claimed.)*

---

### Formula 3 — Effective Drop Rate

```
effective_drop_rate = clamp( base_drop_rate × product(multiplier for each matching condition), 0.0, 1.0 )
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base probability | `base_drop_rate` | float | 0.0–1.0 | From rarity tier table below |
| Condition multiplier | `multiplier` | float | 0.5–1000 per condition | From matching `drop_conditions` entry |
| Result | `effective_drop_rate` | float | 0.0–1.0 | Final probability passed to drop RNG; clamped |

**Base drop rate by rarity:**

| Rarity | `base_drop_rate` | Design Intent |
|--------|-----------------|--------------|
| Common | 0.70 | Near-certain; one favorable condition guarantees the drop |
| Rare | 0.25 | Hunt-worthy; ~3-5 attempts at base, ~2-3 with optimal play |
| Boss-grade | 0.001 | Only drops at meaningful rates when a specific break condition is met. **Design target (see Enemy DB `BOSS_GRADE_BREAK_GUARANTEE = 0.5`):** with break multiplier ×500: `clamp(0.001 × 500, 0, 1) = 0.5` (~50% per qualifying break — the intended authoring value). ×1000 gives `clamp(0.001 × 1000, 0, 1) = 1.0` (100% guaranteed drop; bypasses intended acquisition tension — use only when a guaranteed drop is explicitly desired for a specific part). ×999 gives 0.999 — the clamp does not trigger until the product reaches exactly 1.0. Without break condition: `clamp(0.001, 0, 1) = 0.001` (~0.1%) — functionally zero but **must not be 0.00** (multiplicative formula requires a nonzero base). |
| Prototype | 0.05 | Gradient conditional (see Rule 8): optimal play — all conditions fired — reaches ~15–20%; partial fire yields a partial rate. **Content rule:** every Prototype must define ≥3 drop conditions whose full multiplier product is ≥ ×3.0 (e.g., three ×1.5 conditions: 0.05 × 3.375 = 0.169), otherwise the 15–20% optimal-play target is unreachable. |

**Output range:** Clamped 0.0–1.0. Multiplicative stacking can exceed 1.0 (e.g., Common + two favorable conditions); the clamp handles this gracefully.

**Worked example:**
Rare Servo Arms. base_drop_rate = 0.25. Player breaks enemy arm AND uses targeting mode.
- arm_broken multiplier: ×1.5
- targeting_active multiplier: ×1.3
- effective_drop_rate = clamp(0.25 × 1.5 × 1.3, 0.0, 1.0) = **0.4875** (~49% chance)

**Worked example — Prototype gradient:**
Prototype Arms with three ×1.5 conditions (`all_boss_parts_broken`, `zero_defeats`, `targeting_active`). base_drop_rate = 0.05.
- 0 conditions fired: 0.05 (**5%**)
- 1 fired: 0.05 × 1.5 = 0.075 (**7.5%**)
- 2 fired: 0.05 × 1.5 × 1.5 = 0.1125 (**11.3%**)
- 3 fired: 0.05 × 1.5³ = **0.16875** (~17% — within the 15–20% optimal-play target band)

Each condition the player executes visibly improves the odds; there is no all-or-nothing gate (Rule 8).

---

### Formula 4 — Heat Decay

```
heat_after_decay = max( 0, heat_current − final_stat["cooling"] )
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current Heat | `heat_current` | int | 0–100 | Heat at turn start before decay |
| Cooling stat | `final_stat["cooling"]` | int | 5–18 | Post-chassis Cooling value (from Formula 1). Range derived from design-intent content targets (minimum Cooling build to maximum Cooling build); pending per-stat content validation in Stat Budget Reference. |
| Result | `heat_after_decay` | int | 0–100 | Applied at the start of each Symbot's turn |

**Output range:** 0 to 100. Cannot go negative — excess Cooling is wasted.

**Worked example:** Current Heat 75, Cooling 12 → heat_after_decay = max(0, 75 − 12) = **63**

---

### Formula 5 — Heat Accumulation and Overheat

```
skill_heat_generation = heat_generation + element_heat_bonus
heat_after_skill = min( 100, heat_current + skill_heat_generation )
```

If `heat_after_skill >= 100`, Overheat triggers:

```
overheat_structure_damage = floor( max_structure × 0.10 )
heat_carry_in_to_next_turn = 20   (constant)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current Heat | `heat_current` | int | 0–100 | Heat before skill use (after this turn's decay) |
| Schema heat | `heat_generation` | int | 0–40 | Raw value from part schema (`heat_generation` field); pre-bonus base heat per skill use |
| Element bonus | `element_heat_bonus` | int | 0 or +5 | +5 if the skill-using part's `element == THERMAL`; 0 otherwise. Applied by Combat System at runtime. |
| Skill heat | `skill_heat_generation` | int | 0–45 | `heat_generation + element_heat_bonus`; effective heat this skill use |
| Result | `heat_after_skill` | int | 0–100 | Capped at 100; if 100, Overheat triggers |
| Overheat HP damage | `overheat_structure_damage` | int | 0–floor(max_structure × 0.10) | 10% of post-chassis max Structure, floored |
| Heat carry-in | `heat_carry_in_to_next_turn` | int | 20 (constant) | Heat value at start of next Symbot turn after Overheat |

**Skill Heat generation by tier:**

| Skill Tier | Energy Cost | Heat Generated | Thermal Element Bonus |
|------------|-------------|---------------|-----------------------|
| Basic attack | 0 | 0 | — |
| Light (utility/buff) | 5–8 | 0–5 | +5 |
| Standard (damage/support) | 12–18 | 8–15 | +5 |
| High-power | 22–30 | 18–28 | +5 |
| Signature (Overheat-risk) | 32–40 | 30–40 | +5 |

**Overheat effects (when heat_after_skill = 100):**
1. Symbot loses its next action entirely.
2. Takes `floor(max_structure × 0.10)` Structure damage.
3. Starts the following turn at Heat = 20. Formula 4 does not run on that turn — the carry-in value of 20 is set directly, bypassing decay. Normal decay resumes the turn after.

**Output range:** heat_after_skill clamped 0–100. Overheat damage clamped 0 to floor(max_structure × 0.10).

**Worked example — no Overheat:** Max Structure 90, current Heat 82, Cooling 10, Thermal high-power skill (`heat_generation = 22`, `element_heat_bonus = +5`).
- Turn start decay: 82 − 10 = 72 Heat.
- skill_heat_generation: 22 + 5 = 27.
- heat_after_skill: min(100, 72 + 27) = 99. No Overheat — player is one skill from the edge.

**Worked example — Overheat triggered:** Max Structure 90, current Heat 76, Cooling 10, Thermal Signature skill (`heat_generation = 35`, `element_heat_bonus = +5`).
- Turn start decay: 76 − 10 = 66 Heat.
- skill_heat_generation: 35 + 5 = **40**.
- heat_after_skill: min(100, 66 + 40) = **100. Overheat triggers.**
- Damage: floor(90 × 0.10) = **9 Structure** lost immediately.
- Next turn start: Heat = **20** (carry-in; Formula 4 does not run this turn).

---

### Formula 6 — Energy Regeneration

```
energy_after_regen = min( energy_capacity, energy_current + BASE_ENERGY_REGEN + recharge_bonus )
energy_after_skill  = max( 0, energy_current − skill_energy_cost )
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_ENERGY_REGEN | constant | int | 10 | Fixed Energy regenerated at each turn start. **Shared constant, owned by Turn-Based Combat** (TBC applies it in Rule 4 turn-start recharge; this formula defines the regen step). Renamed from `BASE_REGEN` 2026-07-13 to unify with TBC/registry (C-3 hygiene). Safe range 8–15 — the **8 floor is load-bearing** for TBC's REPAIR anti-stall invariant (TBC-F6). |
| Recharge stat sum | `recharge_bonus` | int | 0–30 | Sum of all equipped parts' `stat_bonuses["recharge"]` values (Rule 4 — 11th MVP stat). Energy Cell and Core may each contribute up to 15 independently, so the sum can reach 30. |
| Energy Capacity | `energy_capacity` | int | 80–120 | Post-chassis maximum Energy pool. Range derived from design-intent content targets; pending per-stat content validation in Stat Budget Reference. |
| Skill cost | `skill_energy_cost` | int | 0–40 | From active skill definition; see tier table |
| After regen | `energy_after_regen` | int | 0–energy_capacity | Energy after turn-start regen; capped at capacity |
| After skill | `energy_after_skill` | int | 0–energy_capacity | Energy after spending; floored at 0 |

**Skill Energy cost tiers:**

| Tier | Energy Cost | Sustainability at BASE_ENERGY_REGEN=10 |
|------|------------|-------------------------------|
| Basic attack | 0 | Always available |
| Light | 5–8 | Sustainable every turn |
| Standard | 12–18 | Sustainable every ~2 turns |
| Heavy | 22–30 | Requires ~3 turns recovery |
| Signature | 32–40 | Requires deliberate build-up over 3-4 turns |

A skill is unavailable (grayed out in UI) when its cost exceeds current Energy. Skills cannot be used on debt.

**Output range:** Both clamped to [0, energy_capacity].

**Worked example:** Energy Capacity 100, current Energy 35, Recharge bonus 8, Standard skill cost 15.
- Regen: min(100, 35 + 10 + 8) = **53 Energy**
- Skill use: max(0, 53 − 15) = **38 Energy** remaining

---

### Stat Budget Reference

Designers must stay within these total stat-point budgets when authoring parts. 60–70% of the budget goes to the slot's primary stats; 30–40% to secondary stats.

| Slot | Common | Rare | Boss-grade | Prototype (positive budget) |
|------|--------|------|------------|-----------------------------|
| Core | 18–22 | 32–38 | 48–55 | 35–45 |
| Chassis | 22–28 | 38–46 | 55–68 | 40–55 |
| Chipset | 12–16 | 22–28 | 35–42 | 28–38 |
| Energy Cell | 14–18 | 26–32 | 40–48 | 32–42 |
| Head | 12–16 | 22–28 | 35–42 | 28–38 |
| Arms | 14–18 | 26–32 | 40–48 | 32–42 |
| Legs | 14–18 | 24–30 | 38–46 | 30–40 |
| Weapon | 16–20 | 28–35 | 45–55 | 38–50 |

**Prototype concentration rule (Option B design intent):** Prototype positive budgets are similar to or slightly lower than Boss-grade, but 70%+ of the budget must go into 1–2 focus stats. This concentration ensures that at maximum upgrade (+5, ×2.00), the Prototype's focus stat may exceed the equivalent Boss-grade part's primary stat — when the Boss-grade distributes its budget across multiple stats (the intended content authoring convention). A concentrated Boss-grade (all budget into one stat) retains a higher raw value in that stat; the Prototype's design guarantee is concentration, which Boss-grade parts are not required to follow. Content authors must spread Boss-grade budgets across ≥2 stats to preserve the Prototype's narrowed-domain advantage. A Prototype that spreads its own positive budget evenly violates this rule and must be revised. Drawback penalties are additional to the positive budget; they are not counted in the table above.

**Multi-stat cap note:** Total positive budget values above 55 require distribution across at least 2 stats — no single stat may exceed 55 (per Formula 1 variable table range). A Chassis Boss-grade at 68 points must spread, e.g., 50 Structure + 18 Armor.

**Slot primary-stat mapping (normative for AC-23):**

| Slot | Primary stat |
|------|-------------|
| Core | `energy_capacity` |
| Chassis | `structure` |
| Chipset | `processing` |
| Energy Cell | `energy_capacity` |
| Head | `targeting` |
| Arms | `physical_power` (PHYSICAL parts) / `energy_power` (ENERGY parts) |
| Legs | `mobility` |
| Weapon | `physical_power` (PHYSICAL parts) / `energy_power` (ENERGY parts) |

For Arms and Weapon, the primary stat is selected per-part by the part's `damage_type`; AC-23 compares Common and Rare parts **within the same damage_type subgroup**. An empty comparison subgroup (e.g., no Common ENERGY Arms exist) passes vacuously — the validator emits an authoring warning, not a failure.

**Common primary caps and Rare primary floors (normative for AC-23):**

| Slot | Common primary CAP | Rare primary FLOOR |
|------|-------------------|--------------------|
| Core | 15 | 23 |
| Chassis | 19 | 29 |
| Chipset | 11 | 17 |
| Energy Cell | 12 | 19 |
| Head | 11 | 17 |
| Arms | 12 | 19 |
| Legs | 12 | 19 |
| Weapon | 14 | 22 |

Derivation: `cap = floor(0.70 × max Common budget)`; `floor = floor(cap × 1.50) + 1` — guaranteeing a Rare at +0 beats any legal Common at +3 (×1.50) in the slot's primary stat. **The Rare primary floor overrides the 60–70% allocation band**: at minimum Rare budgets the primary stat may require up to ~79% of the budget to meet the floor; that is legal and intended. (Round 7 finding: without explicit caps and floors, the total-budget ranges alone cannot satisfy AC-23 in *any* slot — at minimum Rare budgets, even 100% primary allocation fell below `floor(max_common_budget × 1.50)`.)

**Content rule (Rare/Common stat floor):** For each slot (and damage_type subgroup for Arms/Weapon): every Common part's primary stat must be ≤ the slot's Common primary CAP, and every Rare part's primary stat must be ≥ the slot's Rare primary FLOOR (tables above). Because `floor = floor(cap × 1.50) + 1`, a Rare at +0 always outperforms a maxed Common (+3) in the slot's primary stat — preserving the hunt incentive between rarities. Violations must be corrected in content before ship. See AC-23.

## Edge Cases

### EC-01 — Part with no active skill
`active_skill_id = null`. Workshop displays "—" in the active slot. Combat system treats the slot as empty; no skill can be selected. Always valid — not all parts grant active skills.

### EC-02 — Part with no passive
`passive_id = null`. No passive effect registered at equip time. Always valid.

### EC-03 — Part with minimal synergy tags
All parts — including wild-manufacturer parts — must carry their element tag (e.g., `"volt"`) in `synergy_tags`. Non-wild parts additionally must carry their manufacturer tag (e.g., `"boltwell"`). Wild-manufacturer parts carry no manufacturer tag. The `synergy_tags` array is never empty for any part.

Optional extra tags (boss-origin, thematic groups, Architecture Synergy reserved for Full Vision) are additive. A non-wild part may have exactly 2 tags (mandatory only) or more (mandatory + optional). A wild part has exactly 1 tag (element only) or more (element + optional). Absence of optional tags is not an error — the Synergy System processes all tags present and ignores missing ones.

### EC-04 — Part not in drop table (`drop_enabled = false`)
The part exists in the database and all existing inventory copies remain fully functional. Players can still use it, upgrade it, equip it, or recycle it. The part simply cannot drop from enemies or loot containers while `drop_enabled` is false. This is the mechanism for seasonal or event parts, or parts that have been power-adjusted out of the active drop pool.

**What does NOT happen:** parts are never invalidated, disabled, or removed from player inventories. There is no "deprecated" state in this system.

### EC-05 — Multiple copies of the same part in inventory
Players can hold any number of copies of the same part (same `id`). Each copy is an independent instance with its own upgrade tier tracking. Uses:
- Equip one copy to each Symbot that benefits from it
- Hold spares for future Symbots
- Recycle surplus copies for scrap materials

Inventory does not deduplicate or stack part instances.

### EC-06 — Part variants (different rarity, same thematic part)
Multiple parts can share the same `part_family` tag (e.g., `"servo_arm_family"`) but are distinct database entries with different `id` values. Each variant has its own `rarity`, `stat_bonuses`, `active_skill_id`, and `passive_id`. Workshop UI uses `part_family` to group variants in the picker (e.g., "all Servo Arm versions") but each is treated as a fully independent part by combat, upgrade, and drop systems.

### EC-07 — Multiple parts occupying the same slot type
In MVP, each slot type (Core, Chassis, Chipset, Energy Cell, Head, Arms, Legs, Weapon) has exactly one slot. Equipping a second part to the same slot type replaces the current occupant — the displaced part returns to inventory.

Post-MVP Motherboard configuration will allow builds with expanded slot counts (e.g., 2× Arms). The slot governance logic is owned by the Motherboard system; Part Database only stores `slot_type` and does not enforce limits itself.

### EC-08 — stat_bonuses contains a key not in the canonical 11-stat list
Treat as unknown. Assembly System logs a warning and ignores the key. Does not crash. Allows future stat additions without breaking existing parts. The 11 canonical MVP stats are: Structure, Armor, Resistance, Physical Power, Energy Power, Mobility, Targeting, Processing, Cooling, Energy Capacity, Recharge.

### EC-09 — upgrade_effects entry at tier 0
Not meaningful — +0 is the base state, not an upgrade. Assembly System ignores `upgrade_effects` entries with `tier = 0`.

### EC-10 — Prototype part at upgrade tier +3 or higher — drawback removal
Formula 2b returns 0 for any negative `stat_bonuses` key once `tier >= 3`. The stat contribution for that key becomes 0 — neither a penalty nor a bonus. At +4 and +5 the drawback remains 0; it does not become a positive. The Workshop UI may visually indicate that the drawback has been fully eliminated.

**Design intent (post-drawback identity):** From +3 onward, a Prototype is a pure specialist — no active penalties, focus stat scaling to ×2.00 at +5. The Prototype is the highest single-stat option for dedicated builds when Boss-grade budget is spread across multiple stats (the intended content authoring convention); Boss-grade remains superior for mixed-stat builds. Build diversity is maintained by the Prototype's lower secondary stats, not by ongoing penalties. Note: a concentrated Boss-grade part (all budget into one stat) can match or exceed the Prototype's focus stat at +5 — this is an intentional content authoring risk that the Stat Budget Reference's convention (spread Boss-grade stats) is designed to prevent. When designing the Synergy System, note that Prototype focus stats may exceed Boss-grade at +5 in spread-Boss-grade builds — synergy bonuses applying to focus stats can amplify this advantage and should be considered during balance.

**Acquisition experience intent:** At +0, a Prototype must read as a meaningful tradeoff — not a pure downgrade. Content authors must ensure the focus stat at +0 is already higher than the equivalent Rare slot's primary stat in the same slot, even accounting for the drawback on a secondary stat. The drawback should feel like a penalty on a stat the player is trading away, not a degradation of the stat they care about. A player earning a Prototype after a perfect boss run should feel rewarded at the moment of equip, even before upgrading.

### EC-11 — Common part upgrade blocked at +3
Attempting to upgrade a Common part to +4 is invalid. Workshop UI disables the upgrade button. If the upgrade is somehow submitted (e.g., via API call), the system rejects it and returns the part at its current tier unchanged.

### EC-12 — Boss-grade part with no break condition in `drop_conditions`
`BASE_DROP_BOSS_GRADE` is a per-rarity config constant (currently 0.001). If a Boss-grade part's `drop_conditions` array contains no entry with a high multiplier (≥ 500), then `clamp(0.001 × 1.0, 0, 1) = 0.001` — a ~0.1% drop rate regardless of player behavior. This makes the part functionally unobtainable through normal play. This is a content authoring error — every Boss-grade part must have at least one break condition in `drop_conditions` with multiplier ≥ 500. Content validation should flag entries with either empty `drop_conditions` or no condition meeting this threshold (see AC-11).

### EC-13 — Two parts granting the same passive
Both passives are registered and active simultaneously. Passive stacking behavior is defined by the Passive System, not the Part Database. Part Database makes no assumption about stacking rules.

### EC-14 — Part with heat_generation = 0 and ammo_cost = 0
Valid — a free skill with no resource cost. Typically used for basic attacks. No special handling required.

### EC-15 — part_family is null
The part has no thematic family. Workshop UI does not group it with any variants. Always valid for unique one-off parts (e.g., a cosmetic or story-specific drop with no family members).

### EC-16 — Boss-grade acquisition floor (design commitment)
The current schema permits a player who repeatedly fails break conditions to be soft-locked from Boss-grade drops indefinitely — which gate the Boss-grade exclusive synergy bonus and directly threaten Pillar 4 (Synergy Is the Endgame). With only 2 bosses in MVP, this is a real risk. A deterministic acquisition floor — a minimum guaranteed Boss-grade drop rate per N boss attempts, independent of break success — must exist in the game. The specific mechanic (N, pity rate) is defined by the Drop System GDD. **The Drop System GDD must not be approved without specifying this floor.** This is not a Part Database schema concern; it is a hard design constraint inherited from this system's drop mechanic that the Drop System GDD is responsible for fulfilling.

## Dependencies

### Upstream Dependencies (what Part Database requires)

None. Part Database is the root Foundation system — it defines the data contract that all other systems read from. It does not depend on any other system in Symbots.

### Downstream Dependents (what depends on Part Database)

The following 11 systems read directly from the Part Database. Each entry specifies exactly what data it consumes.

| System | What It Reads from Part Database |
|--------|----------------------------------|
| **Enemy Database** | `slot_type`, `rarity`, `drop_conditions` — defines which parts appear in enemy drop tables; Enemy Database references Part Database IDs for its loot entries |
| **Symbot Core Progression** *(MVP, #10b)* | `level_requirement` (equip-gate threshold, Rule 4/5) and `level_growth` (per-CORE per-level stat contribution, CP-F3) — both are **CP-defined fields hosted in the PartDef schema** (added via the Core Progression erratum 2026-07-12). Part DB stores and content-validates them (AC-CP-20 rarity-floor + AC-CP-22 no-power-stats/25%-ceiling are DoD gates on the Part DB erratum); Core Progression owns their meaning and reads them at equip / stat-derivation time. *(Resolves the C-6 one-directional-dependency hygiene warning, 2026-07-13: Upstream stays "None" — the fields live in the root schema — but CP is a downstream reader and is now listed here.)* |
| **Move Database** | `active_skill_id`, `slot_type`, `heat_generation`, `ammo_cost`, `upgrade_effects` — Move DB (Approved 2026-07-10) defines what each active skill and upgrade effect does at runtime; Part DB stores the references, Move DB owns their behavior |
| **Damage Formula System** | `damage_type` (PHYSICAL / ENERGY), `element`, `stat_bonuses` (via Assembly output) — damage math requires knowing a part's element and damage type to apply type effectiveness multipliers |
| **Symbot Assembly System** | Full schema — reads `slot_type` to enforce slot rules, `stat_bonuses` to compute `final_stat`, `chassis_modifier` table for archetype application, `active_skill_id`, `passive_id`, `heat_generation`, `ammo_cost`, `max_upgrade_tier` |
| **Synergy System** | `synergy_tags`, `element`, `manufacturer` — detects active element sets and manufacturer bonuses from equipped parts. **Hard constraint (DB1):** The Synergy System GDD must define synergies triggered by combined manufacturer + element tags (e.g., 4-piece Ironclad-Volt). The Player Fantasy example is contingent on this. The Synergy System GDD cannot be approved without specifying cross-tag synergy thresholds. **Hard constraint (DB4):** With 1 zone and 2 bosses in MVP, type coverage is solvable in 1–2 hours using 2 elements, making ~33% of the part catalog optimization-irrelevant. The Synergy System GDD must provide cross-element incentives that keep all three elements relevant in MVP. |
| **Drop System** | `id`, `rarity`, `drop_conditions`, `drop_enabled` — selects which parts to award and computes effective drop rate via Formula 3. `base_drop_rate` is **not a per-part field**; the Drop System looks up the rarity-constant base rate from tuning config using the part's `rarity` enum as the key. **Hard constraint (DB2):** Drop System GDD must define a pity counter for Prototype acquisition: after N consecutive optimal-condition attempts with no drop, the next attempt guarantees the drop. The Drop System GDD cannot be approved without specifying N and the escalation mechanic. **Hard constraint (DB5):** Drop System GDD must define a scrap-sink mechanic that provides minimum player-perceived value to duplicate Common drops. Without a functioning sink, the 70% Common drop rate trains players to ignore drop notifications by mid-game, degrading the perceived value of Rare and Boss-grade drops. **DB5 direction set 2026-07-10 (HOLISM-01 resolution):** parts are **instances** (duplicates are useful — same part on multiple Symbots), **stored** in inventory and **scrapped at the player's choice** (never auto) to yield **Scrap** currency; the MVP Scrap sink is **material-gated part upgrading** (upgrade_tier 0→5 costs Scrap). Targeted acquisition via **Designs** (rare blueprint drops → fabricate instances w/ currency+materials) is the Alpha Blueprint Crafting layer (#25). The Drop System GDD implements these as concrete rules. |
| **Inventory System** | `id`, `display_name`, `slot_type`, `rarity`, `part_family` — stores part instances and needs schema fields to display and organize them |
| **World Loot System** | `id`, `rarity`, `drop_enabled` — places specific parts in static world chests; reads Part Database to validate that referenced part IDs exist and are obtainable |
| **Blueprint Crafting System** *(Alpha)* | `id`, `rarity`, `part_family` — recipes reference input and output part IDs |
| **Part Upgrade System** *(Alpha)* | `max_upgrade_tier`, `upgrade_effects`, `stat_bonuses` — computes upgrade costs and applies Formula 2 / Formula 2b |
| **Part-Break System** *(MVP)* | `drop_conditions` vocabulary — the condition keys (e.g., `"arm_broken"`) are events emitted by Part-Break during combat and consumed by the Drop System as multiplier triggers for Formula 3. **Stub interface contract (pending Part-Break GDD):** Part-Break must define `P(break_condition_fires)` — the probability a given break condition triggers per encounter — before Formula 3 and AC-11 can describe the full effective Boss-grade acquisition rate. As written, Formula 3 is complete for the Part Database's share of the calculation; the full acquisition rate requires Part-Break GDD. **Hard constraint (DB3):** Part-Break GDD must define both (a) the break condition success probability or triggering conditions, and (b) an escalation mechanic for repeated break failures (separate from EC-16's drop-RNG pity floor). With only 2 bosses in MVP, repeated failure to trigger the break condition — not just failure of the drop RNG after a successful break — is a distinct soft-lock path that must be addressed in the Part-Break or Drop System GDD. |

### Interface Contract

Part Database exposes **read-only access only**. No downstream system may write to Part Database entries at runtime. All content (parts, stats, skills, conditions) is authored by the design team and loaded at game start as an immutable resource.

The canonical access pattern is:

```gdscript
var part: PartDef = PartDatabase.get_part(part_id)
```

Changes to the Part Database (adding parts, patching stat values, toggling `drop_enabled`) are content updates, not runtime state changes.

### Bidirectionality Note

Per the GDD standard, each downstream system's GDD must include a reference back to Part Database in its own Dependencies section. This is the authoritative upstream entry; downstream GDDs reference it, not the other way around.

## Tuning Knobs

Tuning knobs are values designers can change without touching system logic. All values below live in an external config file (not hardcoded); the ranges given are the safe design space derived from the formulas.

### Rarity & Drop Rate Knobs

| Knob | Current Value | Safe Range | What Changing It Does |
|------|--------------|------------|----------------------|
| `BASE_DROP_COMMON` | 0.70 | 0.50–0.90 | Common drop frequency; below 0.50 makes Commons feel scarce and slows early progression |
| `BASE_DROP_RARE` | 0.25 | 0.10–0.40 | Rare hunt duration; above 0.40 deflates the satisfaction of getting a Rare. ~3–5 attempts per target at base. *Errata 2026-07-11: the former "÷ pool_size" note is void — the Drop System rolls each pool part as an **independent Bernoulli trial at its own rate**; pool size does **not** divide the rate (Drop System Rule 2, resolving Enemy DB OQ-5). Per-target rate is `BASE_DROP_RARE` regardless of pool size.* |
| `BASE_DROP_BOSS_GRADE` | 0.001 | 0.0001–0.01 | Baseline Boss-grade rate with no break condition; functionally near-zero but **must not be 0.00** — the multiplicative formula requires a nonzero base. Do not set to 0.00. |
| `BASE_DROP_PROTOTYPE` | 0.05 | 0.01–0.10 | Prototype grind length; above 0.10 makes Prototypes too accessible and dilutes their identity |
| Boss-grade break multiplier | 500 | 500–999 | **Design target (Enemy DB `BOSS_GRADE_BREAK_GUARANTEE = 0.5`):** ×500 produces `0.001 × 500 = 0.5` — ~50% chance per qualifying break, averaging ~2 attempts per Boss-grade exclusive. The intended authoring range is **×500–×999** (50%–99.9% per break). ×1000 gives exactly 1.0 (guaranteed drop via clamp) and bypasses intended acquisition tension; use only when a 100% guaranteed drop is explicitly desired for a specific part. Lowering below ×500 violates the Enemy DB `BOSS_GRADE_BREAK_GUARANTEE` invariant enforced by AC-ED-09. See Enemy DB AC-ED-09 and AC-11 for the product check. |

### Upgrade Multiplier Knobs

| Knob | Current Values | Safe Range | What Changing It Does |
|------|---------------|------------|----------------------|
| Tier multipliers (+0–+5) | ×1.00 / 1.15 / 1.30 / 1.50 / 1.70 / 2.00 | +0 must stay ×1.00; each tier must be ≥ previous | Steeper curves reward upgrade investment more; shallower curves make raw part hunting matter more than upgrading |
| `UPGRADE_CAP_COMMON` | 3 | 2–3 | Common max tier; reducing to 2 shortens early progression; expanding to 4+ collapses rarity distinction |
| `UPGRADE_CAP_RARE_PLUS` | 5 | 4–5 | Rare/Boss/Prototype max tier; reducing to 4 makes +5 bonuses unreachable and invalidates content design for +5 skill unlocks |

### Heat & Energy Knobs

| Knob | Current Value | Safe Range | What Changing It Does |
|------|--------------|------------|----------------------|
| `BASE_ENERGY_REGEN` | 10 Energy/turn | 8–15 | Raises or lowers pacing of the Energy loop; above 15 makes light skills always free and signature skills feel cheap. **Lower bound is 8, not 5** — TBC's REPAIR anti-stall invariant (TBC-F6) requires `energy_cost > BASE_ENERGY_REGEN` to be authorable at the low end; a 5-floor would let a Light-cost Repair on a max-Recharge build become indefinitely sustainable. **Owned by Turn-Based Combat** (shared constant; renamed from `BASE_REGEN` 2026-07-13 to unify name/owner/range across Part DB + TBC + registry — C-3 hygiene). |
| `HEAT_OVERHEAT_THRESHOLD` | 100 | 80–100 | Below 100 shortens the heat curve dramatically; 80 would mean any two high-heat skills in sequence triggers Overheat |
| `OVERHEAT_STRUCTURE_DAMAGE_PERCENT` | 10% | 5–20% | Punishment severity; above 20% at max Structure values (~100+) becomes a near-one-shot consequence |
| `OVERHEAT_CARRY_IN` | 20 Heat | 10–30 | Minimum Heat entering next turn after Overheat; higher values extend the recovery period. Derivation at minimum Cooling (5): carry-in 20 → decay to 15 → Signature (40 Heat) → 55 → decay to 50 → Signature → 90 → decay to 85 → Signature → Overheat (~every 3–4 Signature uses at minimum Cooling). |

### Chassis Modifier Knobs

| Knob | Current Range | Safe Range | What Changing It Does |
|------|--------------|------------|----------------------|
| Structure modifier (Light / Heavy) | ×0.85 / ×1.25 | ×0.75–0.95 / ×1.15–1.35 | Spread between light and heavy survivability; collapsing the gap makes chassis feel indistinguishable |
| Mobility modifier (Light / Heavy) | ×1.20 / ×0.80 | ×1.10–1.35 / ×0.70–0.90 | Initiative/Evasion gap between archetypes; must maintain meaningful ordering or turn economy breaks |

### Stat Budget Knobs

The stat budget table (Common / Rare / Boss-grade / Prototype per slot) is the primary content balance lever. The per-slot ranges in the Stat Budget Reference are the **intended ceilings**, not hard technical limits. Exceeding them is a content authoring choice, not a formula change.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

### Schema Validation

**AC-01**: Every part entry has all required fields populated with non-null, non-empty values for its rarity tier. **Pass when**: A schema validator iterates all part entries and finds zero entries where `id`, `display_name`, `slot_type`, `rarity`, `manufacturer`, `element`, `damage_type`, `stat_bonuses`, `max_upgrade_tier`, `drop_enabled`, `heat_generation`, or `ammo_cost` is null, missing, or the wrong type. **For non-Core slots:** zero Rare/Boss-grade/Prototype entries where `active_skill_id` is null; zero Boss-grade/Prototype entries where `passive_id` is null; zero Common entries where `active_skill_id` is non-null; zero Common or Rare entries where `passive_id` is non-null. **For the Core slot (Rule 8 Core exception):** zero Core entries at *any* rarity where `active_skill_id` is non-null; zero Rare/Boss-grade/Prototype Core entries where `passive_id` is null; zero Common Core entries where `passive_id` is non-null. **Test type**: Content Validation.

**AC-02**: Every part `id` is globally unique across the entire database. **Pass when**: A validator loads all part entries and confirms `set.size() == entries.size()` — no duplicates. **Test type**: Content Validation.

**AC-03**: Every `slot_type` value is one of the 8 valid MVP enum values: `CORE, CHASSIS, CHIPSET, ENERGY_CELL, HEAD, ARMS, LEGS, WEAPON`. **Pass when**: A validator scans all entries and finds zero `slot_type` values outside this set. **Test type**: Content Validation.

**AC-04**: All parts — including wild-manufacturer parts — must carry their element tag in `synergy_tags`. Non-wild parts must additionally carry their manufacturer tag. Wild-manufacturer parts must NOT carry a manufacturer tag. **Pass when**: (a) For every part (all manufacturers including wild): `synergy_tags` contains the element string matching the part's `element` field (e.g., `"volt"` for `VOLT`). Zero parts missing their element tag. (b) For every part where `manufacturer != "wild"`: `synergy_tags` also contains the manufacturer string (e.g., `"boltwell"`). Zero non-wild parts missing their manufacturer tag. (c) For every part where `manufacturer == "wild"`: `synergy_tags` does NOT contain any of `{"boltwell", "ironclad", "scrapjaw"}`. Zero wild parts found carrying a manufacturer tag. (d) Every string in `synergy_tags` for a wild part must be a valid element string (`"volt"`, `"thermal"`, or `"kinetic"` in MVP). Zero invalid tags on wild parts. ("Wild" is a `manufacturer` value, not a rarity — validate all checks against `manufacturer` field, not `rarity`.) **Test type**: Content Validation.

### Formula Verification

**AC-05**: Formula 1 (Total Symbot Stat) floors the result, applies `max(0, …)`, and uses upgraded values (Formula 2/2b outputs), never raw `stat_bonuses`. **Pass when**: (a) Unit test: 8 parts summing Mobility = 7 (upgraded, at their current tiers), Heavy Frame (×0.80) → `max(0, floor(5.6)) = 5`, not 6 (round) or 6 (ceil). This distinguishes `floor` from `round` and `ceil`. (b) Pipeline composition test: Prototype part at upgrade tier +1 with `stat_bonuses["armor"] = -15` (Formula 2b output: −10) plus one other part with `stat_bonuses["armor"] = +12` at tier +0, Balanced Frame (×1.0): `max(0, floor((−10 + 12) × 1.0)) = 2`. An implementation that skips Formula 2b and feeds raw `stat_bonuses["armor"] = −15` directly into Formula 1 computes `max(0, floor((−15 + 12) × 1.0)) = max(0, −3) = 0 ≠ 2` — the Pipeline composition must be used to pass this case. **Test type**: Unit.

**AC-06**: Formula 2 (Upgrade Tier Stat Bonus) applies the correct multiplier and floors to integer at each tier. **Pass when**: (a) Tier sequence with `base_stat = 7` returns exactly `[7, 8, 9, 10, 11, 14]` — specifically `floor(7 × 1.15) = floor(8.05) = 8` (ceiling would give 9; this case distinguishes floor from ceiling). (b) Tier sequence with `base_stat = 13` returns exactly `[13, 14, 16, 19, 22, 26]` — specifically `floor(13 × 1.15) = floor(14.95) = 14` (ceiling gives 15, round gives 15; this distinguishes floor from both) and `floor(13 × 1.50) = floor(19.50) = 19` (round gives 20; this further distinguishes floor from round). (c) **Epsilon regression case (verified non-discriminating)**: `base_stat = 20`, tier +1 returns exactly `23`. Empirical verification (2026-07-09): `float(20) × 1.15` evaluates to exactly `23.0` in IEEE 754 double precision, and an exhaustive scan of bases 1–55 across all five tier multipliers found **no input** where the epsilon-nudge changes Formula 2's result — this sub-test passes with or without the nudge and is retained only as a regression guard. The nudge is genuinely load-bearing in Formula 2b (see AC-08) and must remain in all implementations per the Numeric precision note. *(This resolves the IEEE 754 dispute carried since Round 5 — the earlier claim that this case discriminates was false.)* **Test type**: Unit.

**AC-07**: Common parts are hard-blocked from upgrading beyond tier +3. **Pass when**: `can_upgrade(common_part, 3)` returns `true` AND `can_upgrade(common_part, 4)` returns `false`. For `base_stat = 10`: `compute_upgraded_stat(part, 3)` returns `15` and `compute_upgraded_stat(part, 4)` also returns `15`. The test must assert both equal the literal value `15`, not merely that they equal each other — two equal wrong values (e.g., both returning `12`) would pass a weaker equality assertion but represent a broken implementation. The formula silently caps at +3; it does not return the ×1.70 result and does not throw an error. The Workshop UI is responsible for preventing the upgrade from being submitted. **Test type**: Unit.

**AC-08**: Formula 2b (Prototype Drawback Reduction) returns the correct ceiling-rounded values across all tiers, stays at 0 from +3 onward, and never returns a positive number. **Pass when**: (a) Mock Prototype part with `stat_bonuses["armor"] = -15` — `compute_upgraded_drawback` for tiers 0–5 returns exactly `[-15, -10, -5, 0, 0, 0]`. (b) Mock part with `stat_bonuses["armor"] = -1` — `compute_upgraded_drawback` for tiers 0–5 returns exactly `[-1, -1, -1, 0, 0, 0]`. Asserting the full sequence (not just tier +3) is required: the `max(0, …)` double-negation bug (BLOCK-6) manifests at tiers +4 and +5, not at +3. A test that only checks +3 will not catch a missing clamp. **Test type**: Unit.

**AC-09**: Formula 3 (Effective Drop Rate) multiplies all matching conditions and clamps to [0.0, 1.0]. **Pass when**: (a) Boss-grade part with no matching conditions → `0.001` (not `0.0` — `BASE_DROP_BOSS_GRADE` is 0.001, so `clamp(0.001 × 1.0, 0, 1) = 0.001`). (b) Same Boss-grade part with break condition multiplier 1000 → `1.0` (not `1000.0`): `clamp(0.001 × 1000, 0, 1) = 1.0`. *(This sub-assertion tests clamping behavior at the mathematical boundary — ×1000 is NOT the recommended authoring value; see AC-11 and Enemy DB AC-ED-09 for the 50% design target at ×500.)* (c) **Required sub-assertion**: Boss-grade part with break multiplier 999 returns `0.999`, not `1.0` — assert the result is strictly `0.999`. The clamp triggers only when the product reaches exactly 1.0; an implementation that rounds up before clamping fails this case. (d) Rare part, base 0.25, multipliers ×1.5 and ×1.3 → assert `abs(result − 0.4875) < 1e-9` (not `0.49`). **Float-equality warning (verified 2026-07-09):** `0.25 × 1.5 × 1.3` evaluates to `0.48750000000000004` in IEEE 754 — strict `==` against the literal `0.4875` fails a *correct* implementation. Sub-assertions (a)–(c) are verified exact (`0.001 × 999 == 0.999` and `0.001 × 1000 == 1.0` hold exactly) and may use strict equality; any *new* drop-rate assertion involving float products must use tolerance comparison (`< 1e-9`) unless verified exact. **Test type**: Unit.

### Content Rules

**AC-10**: Every Prototype part has at least one negative value and at least one positive value in `stat_bonuses`. **Pass when**: Validator loads all `PROTOTYPE` entries and confirms each has (a) at least one negative stat: `stat_bonuses.values().any(func(v): return v < 0)`, AND (b) at least one positive stat: `stat_bonuses.values().any(func(v): return v > 0)`. Zero Prototypes found missing either requirement. (Requirement (b) is also a precondition for AC-19's validator — a Prototype with no positive stats causes division-by-zero in AC-19 and is a content authoring error.) **Test type**: Content Validation.

**AC-11**: Every Boss-grade part has at least one `drop_conditions` entry where `BASE_DROP_BOSS_GRADE × multiplier` produces a practical drop rate when the break condition fires. **Pass when**: Validator loads all `BOSS_GRADE` entries and confirms each has at least one condition with `multiplier >= 500` (ensuring `clamp(0.001 × 500, 0, 1) >= 0.5`). A multiplier of 1.0 on a 0.001 base rate does not satisfy this criterion — it produces 0.001, leaving the part effectively unreachable. Zero Boss-grade parts with either empty `drop_conditions` or a maximum multiplier below 500. **Test type**: Content Validation.

**AC-12**: Every part's total positive stat spend falls within the budget range for its slot and rarity. **Pass when**: Validator computes `sum(max(0, v) for v in stat_bonuses.values())` for every entry and checks against the Stat Budget Reference section in this document. Zero entries outside the bounds for their slot/rarity combination. **Test type**: Content Validation.

**AC-13**: Every non-null `active_skill_id` and `passive_id` references an existing entry in its respective database. **Pass when**: Referential integrity validator checks all non-null skill and passive IDs via `MoveDatabase.has_skill(id)` and `PassiveDatabase.has_passive(id)`. Zero dangling references found. **Test type**: Content Validation. **Status: ACTIVE** (unblocked 2026-07-10 — Move Database and Passive Database GDDs are both Approved; `MoveDatabase.has_skill(id)` and `PassiveDatabase.has_passive(id)` interfaces are now defined). In Definition of Done.

### Runtime Behavior

**AC-14**: `PartDatabase.get_part(id)` returns the correct resource for a valid ID and returns null for an unknown ID without crashing. **Pass when**: `get_part("boltwell_spark_core")` returns a non-null `PartDef` whose `id` matches. `get_part("nonexistent_id_xyz")` returns `null` with no exception. `get_part("")` returns `null` without crash. `get_part(null)` returns `null` without crash. **Test type**: Unit.

**AC-15a**: A part with `drop_enabled = false` is excluded from drop table queries. **Pass when**: `DropSystem.build_drop_table(enemy)` does not include the disabled part in its returned pool. `PartDatabase.get_part(that_id)` still returns the full valid entry (the part is not deleted). `PartDatabase.get_part(that_id).drop_enabled == false` for a part authored with `drop_enabled = false`. **Test type**: Unit.

**AC-15b**: A part with `drop_enabled = false` remains fully functional when read by Assembly and Inventory. **Pass when**: `AssemblySystem.compute_final_stat` with that part equipped returns the correct stat value unchanged. Inventory can retrieve and display the part's metadata without errors. **Test type**: Integration. **Status: DEFERRED** — requires Assembly System and Inventory System interfaces to be defined.

**AC-16**: Formula 2b applies independently to each negative stat entry in a Prototype part's `stat_bonuses`. **Pass when**: Unit test creates a Prototype part with `stat_bonuses["armor"] = -15, stat_bonuses["mobility"] = -8`. At tier +2: `compute_upgraded_drawback("armor", part, 2)` returns `-5` and `compute_upgraded_drawback("mobility", part, 2)` returns `-3`. Each stat is reduced independently; neither result is affected by the other's drawback value. **Test type**: Unit.

**AC-17**: No part has a `stat_bonuses["recharge"]` value outside the per-part range [0, 15]. **Pass when**: Validator loads all entries and confirms `stat_bonuses.get("recharge", 0)` is in [0, 15] for every part. Parts without a `"recharge"` key are treated as 0 and pass trivially. Zero violations found. **Test type**: Content Validation.

**AC-18**: Only Energy Cell and Core parts carry non-zero `stat_bonuses["recharge"]` values (schema-enforced rule per Rule 4). **Pass when**: Validator loads all entries where `slot_type` is not `ENERGY_CELL` or `CORE` and confirms `stat_bonuses.get("recharge", 0) == 0` for all such parts. Zero violations found. **Test type**: Content Validation.

**AC-19**: Every Prototype part has 70%+ of its positive stat budget concentrated in 1–2 stats (Stat Budget Reference concentration rule). **Precondition**: AC-10 (extended) guarantees `positive_total > 0` for all evaluated entries — a Prototype with no positive stats fails AC-10 first and must not reach AC-19's validator. If AC-10 passes, division-by-zero is impossible. **Pass when**: For every `PROTOTYPE` entry, compute `positive_total = sum(max(0, v) for v in stat_bonuses.values())`. If `positive_total == 0` for any PROTOTYPE entry, FAIL immediately (AC-10 violation — this entry should have been caught earlier). Compute `top_two_sum` as the sum of the two largest positive values in `stat_bonuses`. Assert `top_two_sum / positive_total >= 0.70`. Zero violations found. (If a Prototype has exactly one positive stat, `top_two_sum` equals that stat value and the ratio is 1.0 — passes trivially and correctly.) **Test type**: Content Validation.

**AC-20**: Every `CHASSIS` part has a non-null `chassis_archetype` value from the valid enum set; every non-CHASSIS part has `chassis_archetype == null`. **Pass when**: Validator loads all entries and confirms (a) zero `CHASSIS` parts with null or out-of-set `chassis_archetype`; (b) zero non-CHASSIS parts with a non-null `chassis_archetype`. Valid enum values: `{LIGHT_FRAME, HEAVY_FRAME, BALANCED_FRAME, GUARDIAN_FRAME, ARTILLERY_FRAME}`. **Test type**: Content Validation.

**AC-21**: Every part entry has all enum fields populated with valid MVP values. **Pass when**: (a) `manufacturer` ∈ `{"boltwell", "ironclad", "scrapjaw", "wild"}`; (b) `element` ∈ `{VOLT, THERMAL, KINETIC}`; (c) `damage_type` ∈ `{PHYSICAL, ENERGY}`; (d) `rarity` ∈ `{COMMON, RARE, BOSS_GRADE, PROTOTYPE}`. Zero entries found with values outside these sets. (Full Vision reserved values such as `CRYO`, `CORROSIVE`, `DATA` must not appear in MVP content.) **Test type**: Content Validation.

**AC-22**: Every part's `heat_generation` is within the design range [0, 40] (the Formula 5 Signature-tier ceiling), and parts with no active skill generate no heat. **Pass when**: (a) Validator loads all entries and confirms `0 <= heat_generation <= 40` for every part — zero violations. (b) For every part where `active_skill_id == null`, `heat_generation == 0` (per Rule 1: "0 if no skill") — zero violations. *(Authored in Round 7 — this validator was a Round 5 recommendation whose AC number was reserved but never filled, leaving a silent numbering gap.)* **Test type**: Content Validation.

**AC-23**: Every Common part's primary stat respects its slot's Common primary CAP, and every Rare part's primary stat meets its slot's Rare primary FLOOR (Stat Budget Reference: slot primary-stat mapping + caps/floors tables). **Pass when**: For each slot type — splitting Arms and Weapon into PHYSICAL and ENERGY subgroups by each part's `damage_type`, and resolving `primary_stat` via the slot primary-stat mapping table: (a) `max(part.stat_bonuses[primary_stat] for Common parts in the group) <= common_primary_cap[slot]` — zero Common parts above the cap; (b) `min(part.stat_bonuses[primary_stat] for Rare parts in the group) >= rare_primary_floor[slot]` — zero Rare parts below the floor. An empty comparison group (no Common or no Rare parts in a slot/subgroup) passes vacuously and emits an authoring warning. Because `floor = floor(cap × 1.50) + 1`, passing (a)+(b) guarantees a Rare at +0 exceeds any legal Common at +3 in the primary stat. **Test type**: Content Validation.

**AC-24**: Every part entry has a non-null, non-empty `sprite_id`. **Pass when**: Validator loads all entries and finds zero parts with `sprite_id == null` or `sprite_id == ""`. Applies to all rarities including starter parts shipped with Symbots. **Test type**: Content Validation.

## Open Questions

[To be designed]
