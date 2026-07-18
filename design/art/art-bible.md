# Art Bible: Symbots

## Document Status
- **Version**: 0.2 (complete)
- **Last Updated**: 2026-07-17
- **Owned By**: art-director
- **Status**: Complete — all 9 sections authored. Visual Identity Foundation (§1–4) locked 2026-07-15; Production Guides (§5–8) + Reference Direction (§9) authored 2026-07-17 (gate: Pre-Production → Production).
- **Scope**: Full bible. §5–9 are production guides derived from the locked §1–4 foundation — they introduce no new palette, shape, or color commitments; they translate existing ones into producible rules.
- **Art Director Sign-Off (AD-ART-BIBLE)**: **APPROVED [2026-07-17]** — authored and signed in the art-director role. §5–9 add zero new visual commitments beyond the ratified §1–4 foundation, so the sign-off certifies faithful translation, not fresh direction. *Formal director-panel spawn is N/A on this pass:* lean review mode skips AD-ART-BIBLE as a non-phase-gate, **and** subagent spawning is disabled for this project per a durable user instruction (past "1M-context credits" subagent failures — the same reason `/gate-check`'s Director Panel is recorded as skipped). **Carried-forward open decision:** the four faction names (§3.8) remain placeholders pending the narrative team, to be resolved *before faction art production begins*.

> **Seeded from**: `design/gdd/game-concept.md` § Visual Identity Anchor ("Colorful Mechanical Wilderness")
> and its references, reweighted so **Medabots is the primary anchor** (per user direction 2026-07-15).

---

## Reference Board

| Reference | Medium | What We're Taking |
|---|---|---|
| **Medabots (Medarot)** | Anime / Game | **PRIMARY.** Modular, charismatic bots where **each part visibly signals its function**; part-break as spectacle (parts detach when destroyed — mirrors our break loop); bright, saturated, characterful color; bots read as *personalities*, not appliances. |
| **Horizon Zero Dawn** | Game | Machines-as-nature — mechanical creatures that *grew into* the ecosystem. Take the wonder; **diverge** to colorful stylized 2D, not photoreal 3D. |
| **Zoids** | Anime / Model | Modular mech companions whose creature archetype (insectoid / reptilian / avian) reads instantly from the mechanical **silhouette**. |
| **Gunpla (Gundam kits)** | Model kits | **Intentional** part seams and panel lines — each Symbot reads as a kit deliberately assembled, never a random pile; parts look *designed to connect*. |
| **Digimon** | Anime / Game | Companions that feel **engineered, not magical**; bright saturated palette as a character-forward signal. |

---

## 1. Visual Identity Statement
*(Sections 1–4 = Visual Identity Foundation — authored this pass.)*

### One-Line Visual Rule

> **Every part looks like it grew into its job — and every bot looks like a decision.**

This rule resolves visual ambiguity in two directions at once. *"Grew into its job"*
encodes organic-machine form — a part's shape follows its function, the way nature
shapes things to purpose. *"Looks like a decision"* encodes Gunpla intentionality and
the player's visible agency — no Symbot ever reads as a random pile; every build looks
chosen. When any visual call is unclear, it must satisfy both clauses.

### Supporting Principles

**1 — Silhouette Carries the Story**
A part's function must be readable from its outline before color is considered.
Striking parts are wide and forward-angled; defensive parts broad, rounded, and low;
speed parts tapered and swept; utility/support parts compact and symmetric. Color
reinforces the read — it never creates it. This is the primary accessibility contract
of the game: a player with any form of color-vision deficiency must be able to identify
a part's role, element category, and slot type from shape and silhouette alone.

- **Design test**: When the function of a new part design is ambiguous, choose the
  silhouette that reads correctly **in full greyscale** before touching the palette.
- **Serves**: Pillar 2 (Parts are the game) · Pillar 3 (Readable tactics) · Accessibility GAG Basic (color is never the sole channel)

**2 — Designed to Connect, Never to Collide**
Every part must look engineered to occupy its slot — joint seams align, panel lines
continue across the boundary, mounting geometry suggests intentional attachment. A
swapped part must leave the Symbot reading as a deliberate build, not a collision of
unrelated shapes. Parts from the same manufacturer/faction share a design vocabulary
(panel-line cadence, fastener language, material register) that makes faction synergies
visible before stats are inspected; parts from different factions still share the
universal Symbot attachment grammar, so a mix reads as cross-faction engineering rather
than visual noise.

- **Design test**: When two parts from different factions share a slot boundary, choose
  the panel-line geometry that reads as intentional assembly, not an accidental seam.
- **Serves**: Pillar 1 (Engineer, don't collect) · Pillar 5 (Build expression — your silhouette is your signature)

**3 — Saturated, Characterful, Alive**
This is not a grimdark world. The Colorful Mechanical Wilderness is high-saturation,
warm-and-cool, and reads as a place where something interesting is always happening.
Wild Symbots have more presence than the environment — they are the characters, the
world is the stage. Part readability on a phone screen makes saturation load-bearing:
washed-out designs fail the thumbnail test. But garish is not characterful — color must
serve each part's personality, not merely maximize intensity. The guiding register is
Medabots' confidence: every bot looks like it knows what it's for.

- **Design test**: When a part could be more muted or more saturated, choose the version
  that reads as a coherent personality **at 64×64 px on an iOS device screen**.
- **Serves**: Pillar 4 (Colorful mechanical wilderness) · touch-first small-size readability constraint

**4 — Destruction Is Legible Spectacle**
When a part breaks, its loss must read instantly and feel earned. The part visibly
detaches or deforms at its seam so the **silhouette changes** — the tactical fact "that
region is gone" is readable from shape alone, not just a number. Break is dramatic (the
Medabots detachment energy is the primary anchor here) but never confusing: the bot
after a break still reads as the same bot, minus a part. This principle reuses
Principle 1's greyscale/shape contract, so it inherits the same accessibility guarantee
rather than inventing a parallel one.

- **Design test**: When a break effect could be more dramatic or more readable, choose
  the one where the **post-break silhouette still tells the player exactly which region
  is gone**.
- **Serves**: Pillar 2 (Parts are the game) · Pillar 3 (Readable tactics) · Medabots primary anchor. Binds Part-Break GDD VA-1…VA-5.

### Ratification Notes (binds to existing GDD commitments)

The following commitments made in approved GDDs are ratified by this section and must
not be contradicted:

- **Element color contract** (turn-based-combat GDD V1-2): Volt = cyan; Thermal = amber;
  Kinetic = white / silver-white. These are the first layer of elemental identity;
  Principle 1 requires a second, non-color layer (icon + shape profile) for each element.
- **Never color alone** (turn-based-combat GDD V1-3, part-break VA-3): Already binding.
  Principle 1 is the structural explanation for *why* this rule exists — the same rule,
  not a new one.
- **Rarity glow table** (symbot-assembly.md): Common = no glow; Rare = soft ambient
  element glow; Boss-grade = steady radiant + shader edge; Prototype = flickering
  instability shimmer. Ratified as an overlay on top of the silhouette read — glow
  escalates a part's *drama*, it never replaces its *function-signalling shape*.
- **Touch target minimum** (accessibility-requirements.md §2.1): 44×44pt. Principle 3's
  thumbnail test is the visual-design expression of this constraint.

---

## 2. Mood & Atmosphere

> Each game state is a distinct emotional room. This section defines the lighting and
> atmospheric character of each room so that a lighting artist, VFX artist, or UI
> colorist builds from a shared target rather than personal interpretation.
>
> **Accessibility contract (all states):** Color is never the sole mood carrier. Every
> state below names at least one non-color cue — contrast ratio, motion quality,
> compositional framing, or pose — that co-carries the feeling for players with
> color-vision deficiency or poor lighting conditions.

### 2.1 Overworld / Zone Exploration

- **Primary emotional target**: The alert curiosity of a hunter who knows the territory and what they came for. Purposeful scanning, not wandering — the player has a shopping list, the world is the store.
- **Lighting character**: Ambient mid-range natural light; warm key from upper-right, cool atmospheric fill from below. Soft shadow edges, high ambient lift so Symbot silhouettes never sink into terrain shadow. Reads as mid-morning/mid-afternoon — never dark enough to threaten at the navigation layer.
- **Adjectives**: Verdant, kinetic, scavenged, expectant, familiar.
- **Energy**: Measured-active — the world moves (foliage, distant patrols) but the tempo is the player's; nothing is urgent until an encounter triggers.
- **Mood-carrying element**: Wild Symbots emit a faint idle glow from active parts — a breath, not a spotlight — pulsing ~1 cycle / 2s. The pulse is a **luminosity** cue (greyscale-readable) layered on the element color, so it serves accessibility and atmosphere at once.
- **Distinction**: Lowest-contrast, most ambient-filled state; wide varied palette (world is the stage). Combat narrows the frame and drops to a limited palette where player + enemy dominate.

### 2.2 Turn-Based Combat

- **Primary emotional target**: The focused intensity of executing a plan while the plan fights back — tactical alertness, not panic. Signature tone (GDD): *"I could finish it this turn — but if I put two more Kinetic hits into that arm first…"*
- **Lighting character**: Strong directional key from slightly above-center on the combatants; cool rim on the enemy, warm rim on the player's bot. Background lit **below** combatant intensity — a deliberate contrast drop making Symbots, move panel, and break pips the brightest objects in frame. Heavier shadows and crisper edges than exploration.
- **Adjectives**: Focused, weighted, clinical, pressurized, deliberate.
- **Energy**: Measured, with micro-tension spikes at each resolution beat. Enemy stays animated during the player's decision phase — it threatens without acting.
- **Mood-carrying element**: Enemy break regions highlighted via **contrast-ring** outline-pulse on cursor rest — a shape-and-brightness cue, not color alone.
- **Combat vs. atmosphere yield rule** — when mood and tactical legibility conflict, **legibility wins without negotiation**:
  - (a) No atmospheric effect may drop UI-to-background contrast below WCAG AA (4.5:1 normal text, 3:1 large/icon).
  - (b) Dynamic lighting/vignette must never occlude the move panel, break pips, or the active Symbot's silhouette.
  - (c) Post-processing (bloom, chromatic aberration) is always at a controlled intensity — never procedurally driven by combat state in a way that competes with readability.
- **Distinction**: Narrower, brighter on focal elements, heavier contrast than exploration. Victory brightens overall; Defeat cools and desaturates; Part-Break spikes above the combat baseline without changing it.

### 2.3 Part-Break Moments

- **Primary emotional target**: The cathartic pop of a plan paying off — the Medabots detachment beat. Earned and spectacular, never decorative. The visual says "you did that."
- **Lighting character**: A single **located** bright flash at the break point (not screen-wide bloom) — a 3–5 frame blaze that drops back to combat baseline. A dim residual glow/smoke echoes the lost part's position, dimming over ~60 frames. Flash is high-value monochrome-readable (white core, element-tinted edge) so it reads as an event in greyscale.
- **Adjectives**: Explosive, precise, triumphant, irreversible, punctuating.
- **Energy**: Frenetic for exactly the flash + detachment (8–12 frames), then immediate return to combat's measured tempo. A beat, not a state.
- **Mood-carrying element**: The broken part **separates from the silhouette** (Principle 4 made concrete) — detaches or deforms along its seam, hangs 2–3 frames, then ejects out of frame or fades at the seam by part type. Silhouette change = the accessibility contract; detachment motion = the spectacle.
- **Distinction**: Highest-energy moment in the game and the only state that deliberately competes with tactical readability — but only for its 8–12 frame spike. Sudden and local (one region, one flash) vs. Victory's wide, gradual brightening. Involuntary from the player's view — fires when the pool depletes, not when the player acts.

### 2.4 Victory / Battle Won

- **Primary emotional target**: The warm exhale of a hypothesis confirmed — satisfaction with ownership, not generic celebration. The player chose the build, ran the harvest plan, and the world validated them.
- **Lighting character**: Combat vignette lifts fully; ambient rises back toward the exploration baseline. Enemy dims out smoothly; the player's bot gets a soft warm key from above, saturation nudged up on the bot **only**. No harsh flash — a slow lift over 30–45 frames.
- **Adjectives**: Warm, resolved, luminous, owned, spacious.
- **Energy**: Triumphant but decelerating. Peak is the final kill hit; the loot-drop moment is a secondary reward spike, but the overall arc is release of tension.
- **Mood-carrying element**: The player's bot idles in its post-battle pose under lifted light, all parts intact and cleanly lit — visual confirmation the machine they built survived.
- **Non-color cue**: The combat→Victory transition is carried by the vignette lifting and ambient rising — both **luminosity** shifts, greyscale-readable.
- **Distinction from Defeat**: Victory lifts and warms the frame; Defeat drops and cools it — structurally opposite in luminosity and temperature.

### 2.5 Defeat / Battle Lost

- **Primary emotional target**: The clear-eyed sting of a disproved hypothesis — a failed experiment, not shame. GDD framing: *"Losses are educational, not punishing."* Loss feels like a reset. Weighted but not desolate.
- **Lighting character**: Combat key desaturates toward cool blue-grey; contrast drops moderately, the scene flattens. Downed Symbots fade to a dimmed, desaturated state — they persist, they are not erased. A pervasive draining of warmth, not a dramatic darkness.
- **Adjectives**: Still, grey, analytical, quiet, temporary.
- **Energy**: Contemplative. **No** screen shake, no harsh red flashing, no prolonged failure animation. Energy drops immediately to a low steady state; the player has time to look at what happened.
- **Mood-carrying element**: The downed team in their defeated pose — the first time the player's own bots render desaturated — read via **pose change (collapsed idle) + light-temperature drop** before palette.
- **Non-color cue**: Pose change and cool-shift carry the state; desaturation is tertiary reinforcement, not the primary signal.
- **Distinction from Victory**: Directional opposites on both axes (temperature and contrast), not just different colors.

### 2.6 Workshop / Build Screen

- **Primary emotional target**: The focused pleasure of a mechanic with the machine in front of them — no clock, every option visible. GDD target: *"the workshop as a laboratory."* Nothing should make the player feel rushed or judged.
- **Lighting character**: Neutral-to-warm indoor workshop light from above and slightly front — an articulated bench lamp. Even, high-ambient, low-shadow; every slot and attachment point clearly lit with no boundary-obscuring shadow. Background darker than subject but controlled and stable — no flicker, no atmospheric motion.
- **Adjectives**: Focused, warm, exact, unhurried, mine.
- **Energy**: Contemplative — the **lowest** energy in the game, deliberately. The Workshop is the only space free of time pressure; the lack of urgency is the reward. Visual noise, ambient animation, and urgency-implying dynamic lighting are excluded here.
- **Mood-carrying element**: The bot rotates slowly on a neutral stand; part-slot boundaries (seams, panel lines, attachment points from Principle 2) carry a subtle **edge highlight** from the good light — actual geometry, not a UI overlay. Hovering a candidate part shows it in-slot with a differential highlight of which stats rise/fall; the reveal slides in unhurried, never pops.
- **Non-color cue**: Stat-change direction shown by an up/down arrow glyph beside any numeric delta; green/red is reinforcement, not the primary encoding.
- **Distinction**: Zero vignette, near-zero atmospheric motion, highest ambient-to-key ratio in the game. Combat states are directional, high-contrast, focused on a confrontation; the Workshop is the *absence* of confrontation.

### 2.7 Menus / Meta Screens (Inventory, Part Catalog, Settings)

- **Primary emotional target**: Calm efficiency with character. The player knows what they want; the screen gets out of the way. Same workshop-world register as 2.6, with even less drama — the shelves and drawers of the same lab.
- **Lighting character**: Flat, high-ambient, neutral; no implied directional source. UI chrome and background share the Workshop's low-saturation substrate so part icons — which carry full saturation — read as the content. The game's most restrained palette; character carried by typography, icon quality, and silhouette, not lighting.
- **Adjectives**: Organized, clean, catalogued, quiet, complete.
- **Energy**: Still. No ambient animation except pagination and intentional feedback (equip confirm, sort reorder). Menus earn no more motion than they need to communicate state.
- **Mood-carrying element**: Part icons at catalog scale (64×64 baseline, per Principle 3's thumbnail test) on a consistent softly-lit neutral tile that recedes. Un-acquired parts show a **silhouette-only locked tile** — shape visible, color not — applying Principle 1's greyscale-first contract at the catalog layer.
- **Non-color cue**: Locked parts are silhouettes regardless of color-vision ability; equipped status uses a glyph (lock/bracket), not color; rarity uses a tier label/icon alongside the rarity glow from §1's Ratification Notes.
- **Distinction from Workshop**: The Workshop has a physical subject (the bot) and implies a space; menus are pure catalog and imply a filing system. Workshop = the act of building; meta screens = the record of what exists to build with.

### Mood State Matrix (Quick Reference)

| State | Temperature | Contrast | Saturation | Energy | Primary shift vs. Combat |
|---|---|---|---|---|---|
| Overworld | Warm primary, cool fill | Low-medium | Wide, varied | Measured-active | Wider frame, higher ambient, lower focus |
| Combat | Warm player / cool enemy | High | Player + enemy dominate | Measured, pressurized | — (baseline reference) |
| Part-Break | Neutral flash, element tint | Spike high → return | Spike, then restore | Frenetic spike → measured | Punctuation event within the combat baseline |
| Victory | Warm lift | Medium | Player bot boosted | Triumphant, decelerating | Vignette lifts; ambient rises; enemy dims |
| Defeat | Cool-grey drain | Medium-low | Desaturated slide | Contemplative | Temperature reversal from Victory; no dramatic darkness |
| Workshop | Warm-neutral indoor | Low (even) | UI neutral; parts saturated | Contemplative | Zero vignette; zero motion urgency; highest ambient lift |
| Menus | Neutral flat | Low | Near-zero background; parts full | Still | Even flatter than Workshop; no spatial lighting implied |

---

## 3. Shape Language

> This is the section the whole identity leans on: Section 1 committed that **silhouette
> carries function-meaning, not color** (accessibility-load-bearing). This section defines
> the geometric vocabulary that makes that promise deliverable. Slot taxonomy is the real
> 8-slot set from `symbot-assembly.md`: CORE, CHASSIS, CHIPSET, ENERGY_CELL, HEAD, ARMS,
> LEGS, WEAPON.

### 3.1 The Governing Problem: Two Reads, One Silhouette

Every Symbot must deliver two readable signals from its silhouette alone:

- **Read A — Slot identity.** "That region is the HEAD. That is a WEAPON. Those are LEGS."
  A *structural* read — positional and proportional. The player scanning a bot at 64×64px
  must locate any slot in under a second.
- **Read B — Role identity.** "This bot is a striker. That one is a tank." A *gestalt* read
  — the bot's mass, stance, and geometry as a whole. The player must identify the functional
  archetype before a move is made.

These could conflict (a striker's wide, forward-angled geometry vs. the HEAD's need to sit
distinctly on top). §3.2 resolves it; everything after must serve that resolution.

### 3.2 Resolving the Dual Read: Vertical Axis Owns Slot Identity, Overall Mass Owns Role Identity

**The rule**: Slot identity is encoded in **vertical position and proportional height** on the
bot's vertical axis. Role identity is encoded in **overall mass distribution and stance** —
wide vs. narrow, forward-heavy vs. rear-heavy, high vs. low center of mass. The two channels
are **orthogonal** — they cannot compete by construction.

**Vertical axis — slot signature map:**

| Zone | Slots | Canonical geometry |
|---|---|---|
| **Upper (head zone)** | HEAD | Compact, vertically distinct, elevated above everything; a horizontal sensor feature (visor band / lens cluster / forward crest). Always the topmost distinct element. |
| **Mid (torso zone)** | CHASSIS, ARMS, + embedded CHIPSET / ENERGY_CELL / CORE | The widest zone; carries the bulk of mass. CHASSIS is the defining shape; ARMS extend laterally. CHIPSET, ENERGY_CELL, and CORE are internal/embedded — **not** distinct silhouette protrusions. |
| **Lower (stance zone)** | LEGS | Ground-contacting; the widest or most complex lower element — the bot's foundation. |

**Mass distribution — role signature:** Within those zones, proportional width and forward/aft
lean encode role. Striker = wide, forward-angled arms + forward-lean. Defense = massive mid that
compresses head and legs toward the center of gravity. Speed = tapers from wide LEGS to narrow
HEAD in a swept line. Utility = near-symmetric, balanced, compact.

**The sandwich model:** HEAD always on top, LEGS always on bottom, mid-mass always between them.
The relative *sizes* of the three layers vary by role; the vertical *order* never varies. The slot
read is the order; the role read is the proportions.

**Tertiary identifier — the part identity icon (UI contexts only):** Every part also carries a
small identity icon (a slot glyph, plus element where relevant). This icon appears **only** in UI
surfaces — the inventory, the Workshop, and the battle target-picker when the player is selecting
a target/region. It is **never** painted onto the part's in-world or in-battle silhouette: the
in-play read stays shape-only (clean, per §3.2). The icon is a redundant precision label for
menu/targeting contexts where exact identification matters (comparing parts, aiming at a specific
region) — a backup to the silhouette read, never a replacement for it.

**Greyscale test for the dual read** — at 64×64px in greyscale, with no icons, a well-designed
Symbot must pass both:
1. A player who has never seen this bot identifies HEAD / MID / LOWER zones by position alone. (Slot read)
2. Shown three bots (striker, defense, speed), a player sorts them by role from silhouette alone. (Role read)

If either fails, the part needs a silhouette revision before the palette is touched.

### 3.3 Per-Slot Shape Signature

Shape contracts for each slot. An outsourced part artist must produce a silhouette satisfying the
signature below; the visual-dev team reviews against these descriptors.

**CHASSIS — The Body Architecture**
- Establishes overall mass distribution; carries the role identity (§3.2 mass read) more than any other slot.
- Always the single widest element in the mid-zone; its outer edge defines "shoulder width," the reference boundary every other part fits within or around.
- Archetype variation: defense = wide, convex, blocklike with chamfered corners; speed = narrow, angled flanks, aerodynamic taper; striker = broad shoulder, slight forward-cant, aggressive flat planes.
- **Panel-line anchor**: all other mid-zone parts continue their panel lines from/to the CHASSIS boundary (Principle 2); lines cross the CHASSIS-to-ARM seam as if the joint were continuous.

**HEAD — The Sensor Crest**
- Highest distinct element; must have a visual mass break from CHASSIS (neck-gap or narrowing) so the zone transition reads at 64×64px.
- Always narrower than CHASSIS shoulder width — the wide-chassis/compact-head contrast is the primary upper-zone cue.
- Built around a dominant **horizontal** sensor feature (visor / lens cluster / forward crest); a head without one fails the slot read. Scanner heads = wider/lower; ranged-support heads = taller with antenna/elevated optic — the horizontal feature is always present, only proportions shift.

**ARMS — The Power Limbs**
- Extend laterally from CHASSIS; the widest point of a striker or defense build. On speed builds, flush and narrow to preserve the taper.
- Never extend vertically above the CHASSIS top line — they sit in the mid-zone. Wide arms = the striker "wide at the equator" silhouette cue (Principle 1).
- May be mirrored (reads balanced/utility) or have a dominant primary arm (a personality signal — encouraged).
- ARM-to-CHASSIS seam shows a continuation line/matching groove, not a hard discontinuity.

**WEAPON — The Forward Extension**
- Attaches at the forearm/hand zone; the only slot with a pronounced **forward** extension — it reaches toward the target.
- The only slot expected to break the CHASSIS silhouette boundary outward (forward/horizontal); all other parts stay within it or sit above/below on the vertical axis.
- Angle = function cue: melee angles down-and-inward, ranged angles forward-horizontal, area/support aims forward-and-up. At 64×64px the weapon must be the part that "points" — the direction of threat must read.

**LEGS — The Stance Foundation**
- Ground contact; defines posture and stability. Most complex lower element, but never extends above the CHASSIS base line — owns the lower zone entirely.
- Archetype variation: heavy = wide, planted, squat, multiple ground contacts; speed = narrow, raised-heel/digitigrade, coiled; standard = symmetric upright bipedal.
- **Mass-drop rule**: LEGS carry more visual weight at the bottom than the CHASSIS — this "bottom-heavy" quality gives the bot gravity, planted-in-the-world.

**CORE — The Internal Component**
- CORE is housed **inside** the CHASSIS. It is **not visible in the overworld or in battle** and contributes **nothing** to the bot's in-play silhouette.
- Visible in only two contexts: the **Workshop** (building/inspecting the bot) and as a **catalog/UI icon**.
- Visual form: a **sphere with an internal design** — reads like a spherical power core. CORE variants (element, tier) differentiate through the *internal design*, seen only when building.
- **No glow, no emission, no silhouette contribution** in world or battle.
- Element-signalling consequence: because CORE is invisible in battle, an enemy's element is **not** read from the model. In-battle element identity is carried entirely by the **UI element badge** on the target picker (`interaction-patterns.md` PG-06) — see Section 4 for the element icon/color system.

**CHIPSET & ENERGY_CELL — Embedded Indicators**
- Do not produce distinct silhouette protrusions. Visible as small flush indicator panels within the CHASSIS zone.
- Supporting detail, not hero shapes: at 64×64px they may be below the resolution threshold (correct); at Workshop/catalog scale they read as fine detail rewarding scrutiny.
- **Constraint**: never designed with protruding geometry that could be confused with ARMS or WEAPON. Flush-to-chassis is the rule.

### 3.4 The Organic-Engineered Tension: What Curves and What Cuts

Section 1's rule — *"every part looks like it grew into its job"* — creates a paradox: machines are
built, not grown; nature curves, engineering corners. **Resolution: organic contour, engineered seam.**

- **Primary silhouette contour = organic**, in the sense of *functional* form. A defense chassis's
  curve is the shape a shell takes to distribute impact; a speed leg's taper is the shape a running
  limb takes. Purposeful biology transposed into metal (the Horizon reference). **Curvature is earned
  by function, never applied for softness** — a part rounded for no functional reason reads as soft-toy,
  not bio-mechanical machine.
- **Interior geometry (panel lines, seams, fasteners) = engineered**: hard-edged, angular, precise.
  Panel lines straight or gently beveled; seams crisp right-angle or chamfered cuts; fasteners
  hexagonal/circular/square, never organic. The Gunpla vocabulary — every surface says "manufactured."
- **The joint/seam is always a hard-edge meeting.** This is what makes Principle 2 achievable: seams
  are hard-edged lines that can be designed to align and continue across part boundaries.

**The Medabots synthesis**: rounded, soft, creature-like primary bodies covered in panel lines and
mechanical surface detail — roundness makes them lovable and character-forward, surface engineering
makes them machines. That is the exact register Symbots must hit.

**Faction differentiation via ratio**: factions (§3.8) may shift the organic↔engineered ratio (one
squarer/more geometric, one more fluid), but neither axis ever disappears — no faction is purely
organic (that is fauna) or purely geometric (that is industrial equipment, not a character).

**Greyscale test**: interior panel-line geometry must read as crisp manufactured lines on a contoured
surface, not surface noise. At 64×64px panel lines may vanish (correct) — at thumbnail only the organic
silhouette reads, which is the read that matters for character recognition.

### 3.5 Environment Shape Grammar

**Subordination principle** (Section 2: "bots are characters, world is the stage"): the wilderness
must communicate zone type and danger while never competing with Symbot silhouettes for the eye.

Environment uses **organic, irregular** shapes — rock angular-but-random, vegetation curved-but-layered.
The language is *naturally complex*, the compositional opposite of the Symbot's *purposefully complex*
shapes. The key property: the environment is **irregular repetition** of a few base forms; Symbots are
**intentional composition** of distinct differentiated parts. The eye reads irregular repetition as
background and intentional composition as subject — figure/ground working for the Symbots.

Three rules for environment vs. Symbot silhouette:
1. **No hard-vertical background elements at bot height** — same-height verticals cause figure/ground ambiguity; background verticals are clearly shorter or clearly taller.
2. **Environment = low-frequency contours; Symbots = high-frequency contours** — many articulated segments read as figure, large smooth curves read as ground.
3. **Background contrast is capped** below the Symbot's mid-tones (reinforces Section 2.2's combat lighting rules — shape and light directives work together).

**Zone differentiation**: encounter zones use different environmental shape vocabularies (crystalline
rock / trailing vegetation / industrial debris) to vary background *texture* without changing the
figure/ground relationship with Symbots.

### 3.6 UI Shape Grammar

**Recommendation: a distinct-but-related HUD language — engineered seam without organic contour.**

Rationale (Gestalt similarity): if UI chrome uses the same organic-contour curves as Symbots, the eye
groups UI *with* the bots instead of letting it recede — directly impairing the combat tactical read
(Section 2.2 yield rule: legibility wins without negotiation). So UI takes only the **engineered-seam**
vocabulary — geometric, angular, precise — leaving organic contour exclusively to Symbots and
environment. Result: **curves = game-world content; hard edges = UI chrome.**

- **Panel shapes**: straight lines, chamfered corners (45° cuts, not rounded), hard right angles. No flowing curves.
- **Chamfer = the UI's signature** — reads "machined," a visual bridge to the Symbot's engineered-seam interior language without borrowing the bot's organic contour.
- **Touch targets**: the chamfer is visual only; the ≥44×44pt target (accessibility-requirements.md §2.1) applies to the full bounding box, not the chamfered visual boundary. Confirm with the UI programmer at implementation.
- **Move panel & break pips** (the most read-critical combat UI): highest contrast against background and bot colors; move buttons = rectilinear chamfered panels; **break pips = small rectilinear indicators, never circular** (circles read too close to bot sensor/joint shapes, creating figure/ground ambiguity).
- **Part identity icons** (§3.2 tertiary identifier) live in this UI layer — inventory, Workshop, and target-picker only.
- **Workshop UI** may use slightly softer *ambient framing* (the bench-lamp metaphor, Section 2.6), but interactive elements (buttons, slot frames, stat bars) stay chamfered — softening is decoration, not functional chrome.

**Greyscale test for UI**: in combat at 64×64px bot scale with color removed, a player must identify
(a) which shapes are bot parts, (b) which are UI, and (c) which UI element is the active move selector.
If any needs color to answer, the shape grammar has failed. Rectilinear-chamfered UI vs. organic-contour
bot silhouette is the differentiator.

### 3.7 Hero Shapes vs. Supporting Shapes: The Read Hierarchy

Combat attention hierarchy: **whole bot → active/targeted part → break region**, guided by shape without color.

- **Level 1 — Whole bot (immediate)**: the role silhouette (§3.2 mass read) catches first — large, high-frequency, contoured against the low-frequency background. Under half a second: "striker" or "tank."
- **Level 2 — Active/targeted part (directed)**: on cursor-rest/target-select, the part steps forward via a **contrast-ring pulse** (Section 2.2) — a luminosity cue, greyscale-readable. This requires each part to have a silhouette boundary clearly differentiable from its neighbours *at the seam*; Principle 2's "panel lines continue across boundaries" is the enabling structure — the seam is the visual address the ring lights up.
- **Level 3 — Break region (post-event)**: the broken part's silhouette disappears from the outline (Principle 4); the bot's outline is now *wrong* in a specific, locatable way. Parts must be designed with **break-contribution in mind** — a part whose loss doesn't change the outline fails Principle 4. This is a design constraint on the four silhouette-extending slots (HEAD, ARMS, LEGS, WEAPON); CHIPSET/ENERGY_CELL/CORE are exempt (internal/embedded).

**Supporting shapes — what recedes**: background environment (§3.5), UI chrome, and embedded internal
components (CHIPSET, ENERGY_CELL) must not draw the eye at levels 1–2. Enforced by low-frequency contours
(environment), rectilinear/chamfered geometry (UI), and flush-embedded treatment (internal slots). A part
artist must never design an embedded indicator that competes with CHASSIS/ARMS/LEGS/HEAD/WEAPON.

### 3.8 Faction Shape Vocabularies

> **⚠ Placeholder names — DECISION PENDING.** The four names below (Smoothshell, Hardform, Wirework,
> Fluxform) are **shape-vocabulary labels only**, not final. They must be renamed with the narrative
> team **before faction art production begins**. (Tracked as a deferred decision.)

**Constraint (Principle 2)**: every faction's parts share the **universal attachment grammar** — joint
seams align, slot positions are standardized, panel lines can continue across faction boundaries. Faction
vocabulary is *surface language*, not structural language.

**Extensible scheme** — a faction is defined by four variables: (1) primary contour character, (2)
panel-line cadence, (3) fastener/detail language, (4) mass-distribution tendency. Any new faction is
specified by setting these four; the result is coherent and distinct without violating the grammar.

| Faction (placeholder) | Contour | Panel-line cadence | Fasteners | Mass tendency | Reads at 64×64px as |
|---|---|---|---|---|---|
| **Smoothshell** | High organic curve; shells/carapaces/seeds; low corner incidence | Sparse, sweeping, following the contour | Absent / flush-countersunk (seamless at a glance) | Centered, compact, "compressed" | Softest, most organic — the "alive" faction |
| **Hardform** | Geometric, faceted, planar; curves only where function demands | Dense perpendicular grids, hard-ruled straight lines | Prominent hex bolts/rivets, readable at icon scale | Blocky, anchored, heavy | Most armored/industrial |
| **Wirework** | Skeletal; visible structural members, designed negative space/voids | None — beams, struts, cables; structural not decorative | Cable ties, locking rings, field-assembled look | Light, extended, long/fragile | Lightest, most unusual — voids read instantly |
| **Fluxform** | Asymmetric, directional, looks mid-motion at rest; mixed organic/angular | Diagonal ~45° slash-directional lines | Quick-release clasps, slide-locks | Forward-weighted, never centered; rear-sweeping legs | Most aggressive — asymmetry/forward-lean reads at thumbnail |

*Wirework attachment note*: because its silhouettes have voids, the seam regions must be **solid
structural nodes** carrying the universal attachment geometry; the voids sit between nodes, not at them.

**Cross-faction mix rule**: when a build mixes factions, the seam honors the universal attachment grammar
(matching joint cuts, compatible slot geometry). The contour/panel contrast then reads as *deliberate
cross-faction engineering* (the player chose this) rather than accidental mismatch — "two materials
carefully joined," not "broken." At 64×64px a single-faction bot reads coherent; a two-faction bot reads
as intentional.

### 3.9 Shape Design Checklist for Part Artists

An outsourced artist must verify all of the following before delivery:

**Slot & role read (§3.2–3.3)**
- [ ] Slot type identifiable from silhouette alone (reads as HEAD, ARMS, WEAPON, etc.).
- [ ] With same-role parts in other slots, the assembled bot suggests the correct role archetype.
- [ ] Part stays within its assigned vertical zone (head-top / torso-mid / stance-bottom).

**Organic-engineered tension (§3.4)**
- [ ] Primary silhouette contour follows functional-organic form (curves serve mechanical purpose).
- [ ] Surface detailing uses straight, geometric, hard-edged language.
- [ ] No organic curves in the interior seam/joint geometry (joints always hard-edged).

**Greyscale / thumbnail test (§3.1–3.2)**
- [ ] Greyscale at 64×64px: slot zone identifiable by position.
- [ ] Greyscale at 64×64px: role contribution visible (striker mass / defense width / speed taper / utility balance).
- [ ] Greyscale at 64×64px: WEAPON's direction of "pointing" is readable.
- [ ] If HEAD: horizontal sensor feature present and visible at 64×64px greyscale.

**Connection grammar (§3.2, §3.8)**
- [ ] Seam at every slot boundary is a hard-edged, geometrically precise cut.
- [ ] Panel lines at boundaries run toward the seam, designed to continue across it.
- [ ] Universal attachment geometry present and unmodified by faction vocabulary.

**Break legibility (§3.7, Principle 4)**
- [ ] Silhouette-contributing slot (HEAD/ARMS/LEGS/WEAPON)? Then removal must visibly change the bot outline. Flush/internal (CHIPSET/ENERGY_CELL/CORE) → exempt.
- [ ] Distinct silhouette boundary from adjacent parts (a contrast-ring could light the seam cleanly).

**Part identity icon (§3.2, §3.6)**
- [ ] Part has a UI identity icon (slot glyph + element where relevant) for inventory / Workshop / target-picker — **not** applied to the in-world/in-battle model.

**Faction vocabulary (§3.8)**
- [ ] Part belongs to an identified faction (or explicit cross-faction "generic").
- [ ] Contour, panel-line cadence, and fastener language match the faction's four variables.
- [ ] Faction-crossing builds: seam region is solid and carries standard attachment geometry (even if the silhouette is otherwise skeletal/void).

---

## 4. Color System

> **Serves**: Pillar 4 (Colorful mechanical wilderness) and Pillar 3 (Readable
> tactics). Every semantic color carries a mandatory non-color co-channel — the
> accessibility contract from §1.3 and `design/accessibility-requirements.md`
> §1.3 (Basic tier, BLOCKING) is enforced here at the palette level, not left to
> individual screens.
>
> **Contrast note**: Ratios below are the design-target values. Exact sRGB
> verification (WCAG AA: 4.5:1 body text / 3:1 large icons per
> `accessibility-requirements.md` §1.1) happens at implementation. Any value that
> fails on-device is corrected toward the darker plate, never by dropping the
> co-channel.

### 4.1 Primary World Palette

The world reads warm-neutral and lived-in — a mechanical wilderness, not a chrome
lab. Seven anchor colors. Bots are high-frequency saturated accents against this
lower-frequency ground (see §3.5 figure/ground).

| Code | Name | Hex | Role in the world |
|------|------|-----|-------------------|
| W-1 | Ironmoss Green | `#3D7A4A` | Ground cover, vegetation, the dominant overworld field color |
| W-2 | Alloy Ochre | `#C49A35` | Earth, stone, dry terrain ⚠ (Thermal-adjacent hue — see note) |
| W-3 | Slate Gunmetal | `#374350` | Chassis base metal, structural rock, the neutral mid-dark |
| W-4 | Wilderness Amber | `#C4721A` | Active/live energy accent in the environment (emissive) ⚠ |
| W-5 | Circuit Teal | `#2B6E68` | Cool flora, exposed circuitry, water |
| W-6 | Harvest Crimson | `#B33020` | Environmental danger/enemy presence (hazards, enemy territory tint) |
| W-7 | Bone White | `#F2EDDF` | Structural highlights, specular, exposed frame — **matte**, distinguishes structure from Kinetic element |

> **⚠ Ochre/Amber vs. Thermal collision (flagged and resolved).** W-2 Alloy Ochre
> and W-4 Wilderness Amber sit near Thermal's element amber (`#F0900A`) in hue. A
> player could misread an ochre rock or an amber energy vein as "a Thermal thing."
> **Resolution (same principle as Kinetic in §4.2): the glyph is the signal, the
> hue is decoration.** Environment ambers are *matte and never carry the Flame
> Chevron glyph*; Thermal always carries the glyph **and** an emissive bloom. No
> environment surface is ever both amber-hued and glyph-bearing. This is the one
> handshake point between the world palette and the element palette, and it is
> resolved by the non-color channel, not by moving hues apart.

### 4.2 Element Colors (formalized)

The three combat elements from `design/gdd/damage-formula.md` (Rule 2 type cycle:
**Volt → Thermal → Kinetic → Volt**, ×1.5 effective / ×0.75 resisted / ×1.0
neutral). These colors are **ratified and load-bearing** — they were committed in
`design/gdd/symbot-assembly.md` and must not drift. Each element pairs its color
with a **mandatory glyph** so the element survives greyscale, colorblindness, and
small sizes.

| Element | Color | Hex | Glyph | Status effect (TBC Rule 11) |
|---------|-------|-----|-------|------------------------------|
| **Volt** | Cyan | `#2FE8E8` | **Lightning Fork** — bifurcated diagonal bolt | Shock (mobility down) |
| **Thermal** | Amber | `#F0900A` | **Flame Chevron** — upward-stacked Vs | Burn (DoT at turn start) |
| **Kinetic** | Silver-shift | `#D8DDE6` | **Impact Ring** — concentric circles | Stagger (outgoing damage down) |

The glyph cycle maps to the type cycle so the "what beats what" is learnable from
the icons alone: **Fork → Chevron → Ring → Fork** reads left-to-right as
Volt-beats-Thermal-beats-Kinetic. Status effects reuse the parent element's glyph
(a Burning target shows a small Flame Chevron), so the player learns one visual
vocabulary, not two.

> **The Kinetic = white problem, solved.** "Kinetic is white" was fragile: white
> is also the world's structural/specular color (W-7 Bone White), so a pale bot
> part could read as "light metal" *or* "Kinetic element." Three-layer fix, in
> order of strength:
> 1. **Glyph is the real signal** — any off-white surface *lacking* the Impact Ring
>    glyph is structural, not elemental. This is the load-bearing cue.
> 2. **On-model, Kinetic is a silver-*shift* + polished/chrome finish**, never a
>    flat white tint — a material read, not a hue read.
> 3. **The Kinetic UI badge always renders on a fixed dark plate** (`#1E2229`,
>    target ≈7.5:1) so it never floats on an ambiguous background.
>
> Color is deliberately the weakest of the three cues. This is the §1.3
> never-color-alone contract applied to the hardest case in the game.

> **CORE element read (from §3.3).** Because the CORE is render-invisible in play
> (inside the CHASSIS; no on-model glow), an enemy's element is **never read off
> the model in battle**. It is read exclusively from the **UI element badge on the
> target picker** (`design/ux/interaction-patterns.md` PG-06), specified in §4.5.
> This section owns that badge's colors and glyphs.

### 4.3 Semantic Color Vocabulary

Colors that mean something in the UI/feedback layer. Each is defined against the
element palette to guarantee no collision, and each names its non-color co-channel.

| Meaning | Color | Hex | Non-color co-channel | Collision guard |
|---------|-------|-----|----------------------|-----------------|
| Danger / depletion | Red | `#CC3020` | Cracked-icon, "CRITICAL" label, fill-level drop | — |
| Heal / buff | Green | `#3AB54A` | Up-arrow, "+" prefix, rising fill | — |
| Reward / rarity | Gold | `#E8B820` | Star / trophy glyph | Hue 50° vs Thermal 36° + higher luminance — never glyph-shares with Thermal |
| Selected / interactive | Info Blue | `#4090CC` | Selection outline, focus ring | Hue 210° vs Volt 180° — **cyan is forbidden as a UI "info" tint** so it never competes with Volt |
| Neutral / text | UI White | `#E8E8E8` | (default; carries no semantic weight) | — |

> **Design rule — element colors are reserved.** Volt cyan, Thermal amber, and
> Kinetic silver mean *element* and nothing else in the UI. The UI's own "info,"
> "reward," and "neutral" needs are served by deliberately offset hues (info blue,
> gold, white) so that seeing cyan *always* means Volt. This keeps the tactical
> read (Pillar 3) uncorrupted by chrome.

### 4.4 Rarity Tiers

Aligned to the glow tiers already committed in `design/gdd/symbot-assembly.md`.
**Border-count is the greyscale/colorblind channel** — rarity is fully legible with
all color and glow stripped.

| Tier | Glow (color) | Border / mark | Greyscale read |
|------|--------------|---------------|----------------|
| Common | None | Single Gunmetal border, "COMMON" label | 1 border |
| Rare | Soft ambient element-color glow (~25%) | Double border + ◆ + element watermark | 2 borders |
| Boss-Grade | Steady radiant glow (~60%) + shader edge | Triple border + ★ + accent band | 3 borders |
| Prototype | Stochastic flicker **< 3 Hz** + chromatic-aberration shimmer | Irregular animated border + ⚠ | animated border |

> **Flash-safety**: Prototype flicker is capped **< 3 Hz** per
> `accessibility-requirements.md` (photosensitivity floor). The shimmer is
> amplitude-modulated, not a hard on/off strobe.

### 4.5 UI Chrome & the Element Badge

The UI is a distinct dark-slate HUD language (§3.6: "hard edges = chrome, curves =
game content"). Seven chrome values:

| Code | Role | Hex | Verified contrast |
|------|------|-----|-------------------|
| C-1 | HUD Dark (base plate) | `#1E2229` | — |
| C-2 | Mid panel | `#2C3340` | — |
| C-3 | Interactive surface | `#3A4455` | — |
| C-4 | Active/selected | `#4090CC` | (= Info Blue §4.3) |
| C-5 | Divider / chamfer | `#4B5668` | — |
| C-6 | Text primary | `#E8E8E8` | 13.5:1 on C-1 |
| C-7 | Text secondary | `#98A4B4` | 4.9:1 on C-1 |

**Element badge sub-spec** (the forward dependency from §3.3 — this is how the
enemy's element is read when the CORE is invisible):

- **Shape**: chamfered rectangle (chrome vocabulary), always on a **C-1 dark plate**.
- **Content**: element glyph (§4.2) in element color, optional element-name label.
- **Verified contrasts on C-1**: Volt ≈7.2:1 · Thermal ≈5.8:1 · Kinetic ≈7.5:1.
- **Effectiveness indicator**: glyph-first — ▲ (green, super-effective) / ▼ (red,
  resisted) / – (white, neutral). The arrow shape carries the meaning; color
  reinforces it. Placed on the target picker (PG-06) so the player reads
  "my move vs. this target" before committing.

### 4.6 Per-State & Per-Zone Color Temperature

Ties the palette to Section 2's seven mood states and the encounter zones.

- **Overworld** — warm-neutral, W-1/W-2 dominant, high ambient.
- **Combat** — cooler, desaturated ground so saturated bots + element glyphs pop
  (legibility yield rule, §2.2).
- **Workshop** — warm, even, laboratory-clean; parts read at true color.
- **Victory / Defeat** — directional opposites (§2.4/2.5): victory warms toward
  gold, defeat cools and desaturates (never punishing red — "losses are
  educational").
- **Zone tints** — Crystalline (cool teal/violet lean), Vegetation (W-1 green
  lean), Industrial-Debris (W-3 gunmetal + W-6 crimson hazard accents).
- **Enrage** (TBC-F7): the enemy's **rim light warms toward W-6 Harvest Crimson** —
  a threat/temperature cue, **deliberately not an element-color change**, so
  "angrier" never reads as "changed element."

### 4.7 Colorblind Safety Pass

Six risk pairs, each resolved by a luminance gap **and** a non-color cue. Deuteranopia
simulation (e.g. Sim Daltonism) is a **hard gate** on any new UI color decision. There
is **no colorblind-mode toggle** — safety is universal via the never-color-alone
contract (§1.3), so no player has to find a setting to be able to play.

| # | Risk pair | Deficiency | Resolution |
|---|-----------|------------|------------|
| 1 | Danger red vs. Heal green | Deuteranopia | Cracked-icon vs. up-arrow; luminance offset |
| 2 | Thermal amber vs. Reward gold | Tritanopia | Flame Chevron glyph vs. star; hue 36° vs 50° + luminance |
| 3 | Volt cyan vs. Info blue | Tritanopia | Lightning Fork glyph vs. selection outline; hue 180° vs 210° |
| 4 | Kinetic silver vs. UI white | Achromatic | Impact Ring glyph vs. no glyph; metallic finish vs. matte |
| 5 | Boss-Grade glow vs. Reward gold | General | Border-count (3) vs. star mark |
| 6 | Environment crimson (W-6) vs. Danger red | General | Context (world surface, no icon) vs. UI element with cracked-icon/label |

### 4.8 Palette Reference Table

| Color | Role | Hex | Non-color co-channel |
|-------|------|-----|----------------------|
| Ironmoss Green | World: ground/vegetation | `#3D7A4A` | — |
| Alloy Ochre | World: earth/stone | `#C49A35` | matte, no glyph |
| Slate Gunmetal | World: chassis/rock mid-dark | `#374350` | — |
| Wilderness Amber | World: live-energy accent | `#C4721A` | matte, no glyph |
| Circuit Teal | World: cool flora/circuits | `#2B6E68` | — |
| Harvest Crimson | World: danger/enemy presence | `#B33020` | context, no UI icon |
| Bone White | World: structural/specular | `#F2EDDF` | matte (vs. Kinetic finish) |
| Volt Cyan | Element: Volt | `#2FE8E8` | Lightning Fork glyph |
| Thermal Amber | Element: Thermal | `#F0900A` | Flame Chevron glyph + bloom |
| Kinetic Silver | Element: Kinetic | `#D8DDE6` | Impact Ring glyph + chrome finish |
| Danger Red | Semantic: danger/depletion | `#CC3020` | cracked-icon / "CRITICAL" |
| Heal Green | Semantic: heal/buff | `#3AB54A` | up-arrow / "+" |
| Reward Gold | Semantic: reward/rarity | `#E8B820` | star / trophy |
| Info Blue | Semantic: selected/interactive | `#4090CC` | selection outline / focus ring |
| UI White | Semantic: neutral text | `#E8E8E8` | (default) |
| HUD Dark | Chrome: base plate | `#1E2229` | — |
| Chrome Mid | Chrome: mid panel | `#2C3340` | — |
| Chrome Interactive | Chrome: interactive surface | `#3A4455` | — |
| Chrome Divider | Chrome: divider/chamfer | `#4B5668` | — |
| Text Secondary | Chrome: secondary text | `#98A4B4` | — |

---

## 5. Character Design Direction

*(Production guide. Derives from §1 Visual Identity, §3 Shape Language, §4 Color System. Introduces no new visual commitments.)*

### 5.1 Two Identity Layers — The Mechanic and the Build

Symbots has **two distinct character layers**, and the art must not confuse them:

1. **The Mechanic — the player avatar.** A human engineer the player embodies in the
   world: a simple sprite that walks the overworld (Pokémon-style navigation), chosen
   at character creation. This is *who you are* — your presence in the world,
   overworld, and Oficina. **It carries no combat stats** (no HP, no level, no
   attributes). Authored in §5.2.
2. **The Build / the CORE — the combat character.** The Symbot the player assembles is
   what *fights*, and it changes every time a part is swapped. **All power and
   progression live here** — the **CORE gains levels from battle-XP** (Pillar: Core
   Progression) and **parts carry the stats**; the human mechanic never levels. This
   is the visual consequence of Pillar 2 ("Parts are the game") and the One-Line Rule
   ("every bot looks like a decision"): the character artist designs **a system of
   parts that reads as deliberate whoever assembles it**, not a fixed hero-bot.

This is the Pokémon split exactly: the trainer walks the map and picks an appearance;
the *creature* is what battles and grows. Combat-character direction is therefore
mostly authored in §3 (per-slot silhouettes, faction vocabularies); §5.3–§5.6 govern
what §3 does not — the **CORE as the persistent bond anchor** and the **read hierarchy
that separates player-bot / enemy / boss**.

### 5.2 The Mechanic — The Player Avatar

The mechanic is the human the player *is* in the world. Direction targets are
deliberately **simple** — this is a small, readable identity sprite, not a detailed
hero portrait. Scope: **Masc/Fem appearance + a simple color/palette choice** at
creation, and nothing deeper for MVP.

- **Archetype**: an **engineer / field-mechanic**, not a soldier or a mage. Read as a
  *person who builds and repairs machines* — practical clothing, tool-forward, at home
  among the mechanical wilderness (§6). They belong to the world the Symbots grew in.
- **Two variants + palette**: two base appearances (**masculine / feminine**) plus a
  **simple clothing color/palette choice** at creation. That is the whole customization
  surface — no body sliders, no accessory system. Keep the two variants tightly
  matched in silhouette footprint so overworld/Oficina/battle framing works identically
  for both.
- **Where the mechanic appears** (confirmed scope — drives the sprite/pose count):
  - **Overworld**: walking sprite, **4-directional** (up/down/left/right) walk cycles,
    per variant × palette. Small, readable at map zoom — the primary asset.
  - **Oficina (Workshop)**: the mechanic shown **at the bench**, assembling the Symbot
    — a static/idle pose that reinforces the "engineer" fantasy on a core screen. Warm,
    even Workshop lighting (§4.6).
  - **Battle intro**: a brief **cameo** at the start of a fight (trainer-style entrance),
    then the mechanic yields the frame to the Symbot (which is what actually fights).
- **No combat presence beyond the intro**: the mechanic is never a combat entity —
  no health bar, no targetable body, no stats. During the fight itself the **Symbot is
  the character on stage** (§5.4). The mechanic's job is *identity*, not *combat*.
- **Palette**: draws from the warm **world palette (§4.1)** so the mechanic reads as a
  person *in* the wilderness, not a UI element or a bot. The mechanic must never read
  as high-frequency/saturated the way a Symbot does (§3.5 figure/ground) — a human
  among machines is quieter than the machines.
- **LOD**: the overworld sprite is small; spend detail on the **walk-cycle silhouette
  read** (which direction they face, that they're a person) over facial detail. Facial
  and clothing-color detail matter most in the Oficina and battle-intro framings, where
  the camera is closer.

**Mechanic checklist (per variant × palette):**
- [ ] 4-directional overworld walk cycle, readable at map zoom.
- [ ] Oficina bench idle pose.
- [ ] Battle-intro cameo pose.
- [ ] Engineer/mechanic archetype (not soldier); reads as a person among machines.
- [ ] World-palette clothing; lower saturation than any Symbot (§3.5).
- [ ] No HP bar / stat display anywhere — the mechanic is never a combat entity.

### 5.3 The CORE Is the Character You Bond With

The CORE is **render-invisible in play** (§3.3 — embedded in the CHASSIS, no on-model
glow, element read only off the UI badge §4.5). Yet it is the one persistent object
the player owns across every rebuild: parts come and go, the CORE stays. It is the
game's attachment anchor, and it lives **exclusively in the Workshop and UI** as a
sphere.

- **Form**: a smooth sphere (§3.3), the *only* fully-organic-contour object the game
  grants no engineered seam — it is deliberately unlike every part, so it reads as
  "the living core the machine is built around," not as another component.
- **The "alive" idle**: in the Workshop and CORE-inspection UI, the sphere carries a
  **slow luminous pulse, capped < 3 Hz** (the §4.4 / `accessibility-requirements.md`
  photosensitivity floor — never a hard strobe). This is the game's bonding hook.
  **Rationale**: the concept has *no Pokédex-style completion counter* (a hard
  anti-pillar — "discovery is the reward"), so the emotional attachment other
  collect-games get from a filling ledger must come from somewhere else. Here it
  comes from the CORE reading as a companion you carry and re-body, not a stat block
  you complete. **Do not add a completion meter, collection %, or roster counter to
  any CORE or Workshop screen** — this is a BLOCKING art rule, not a preference.
- **Never in battle**: the sphere is never drawn on the in-combat model. An artist
  who renders a visible glowing core on a battling bot has violated §3.3.

### 5.4 Distinguishing Player-Bot / Enemy / Boss — Only Locked Channels

All three reads use channels already ratified in §3–§4. **No new color, glyph, or
shape is introduced for "enemy-ness" or "boss-ness."**

| Read | Carried by | Source |
|------|-----------|--------|
| **Player's bot** | Screen framing + the fact that the HUD's own resource bars (structure/energy) bind to it; it occupies the player-side stage position | `design/ux/battle.md` layout |
| **Enemy** | Faction shape vocabulary (§3.8) + rarity glow (§4.4); its element is read **only** from the target-picker badge (§4.5), never the model (§3.3) | §3.8, §4.4, §4.5 |
| **Enemy is enraged/threatening** | Rim light warms toward **W-6 Harvest Crimson** (§4.6 Enrage) — a temperature cue, *deliberately not an element-color change* | §4.6 |
| **Boss** | Boss-Grade glow tier (steady radiant + shader edge, §4.4) + larger silhouette mass + triple-border ★ treatment in the UI | §4.4 |

The design test: **strip all color** and player/enemy/boss must still be separable by
silhouette scale, stage position, and border-count. If a read needs color, it has
failed the §3.1 greyscale contract.

### 5.5 Expression & Pose — Silhouette, Not Faces

Symbots are "personalities, not appliances" (the Medabots anchor), but **they have no
faces** — a HEAD is a sensor array (§3.9), not an emotive face. Character personality
is therefore carried entirely by **silhouette and stance**:

- **Idle stance encodes role** (the §3.2 mass read expressed as pose): a striker
  build stands forward-angled and weight-forward; a tank build plants broad and low;
  a speed build reads coiled and swept-back; a utility build reads balanced and
  upright. Stance is the "attitude," and it emerges from the equipped parts — the
  same build always poses the same way, reinforcing "the build is the character."
- **The HEAD sensor is the "gaze"**: the single horizontal sensor feature (§3.9
  required at 64×64px) acts as the bot's directional attention — orient it toward the
  target in combat so the bot reads as *aware*, not inert. This is the closest thing
  to a "face" the game has, and it is a shape, not an expression.
- **Exaggerated but grounded**: poses may be readable-at-thumbnail exaggerated
  (Medabots charisma) but must stay mechanically plausible — a joint never bends
  where the §3.8 attachment grammar says it cannot.

### 5.6 LOD Philosophy — Silhouette Survives, Interior Drops

The combat camera renders bots near the recurring **64×64px greyscale test scale**.
Detail budget is spent accordingly:

- **Preserve at all LODs**: the role silhouette (§3.2), slot-zone positions (§3.3),
  the four silhouette-contributing slots' outlines (HEAD/ARMS/LEGS/WEAPON), and the
  break-legibility read (§3.7 Level 3 — a broken part must still visibly alter the
  outline at combat scale).
- **First to drop**: interior panel-line density, fastener detail, and embedded
  internal components (CHIPSET/ENERGY_CELL) — these are §3.7 "supporting shapes" that
  must not draw the eye at combat distance anyway, so shedding their detail at the
  play LOD costs nothing.
- **Full detail reserved for the Workshop**, where the camera is close, parts read at
  true color (§4.6 Workshop), and the player is *inspecting a decision*. Author each
  part at Workshop resolution (§8) and let the atlas/mip chain resolve the combat LOD.
- **Design test**: if a part's identity survives to 64×64px greyscale but its charm
  only appears in the Workshop, that is correct — not a failure.

---

## 6. Environment Design Language

*(Production guide. Derives from §1, §2 (mood), §3.5 (figure/ground), §4.1 & §4.6 (world palette / zone temperature). No new commitments.)*

### 6.1 Grew Here, Not Placed Here

The environment's governing sentence is the game concept's Visual Identity Anchor:
**"Every element must feel like it *grew* here, not was *placed* here."** The world is
a **mechanical wilderness** — machine and nature interpenetrated, neither pure
ecosystem nor pure factory. Circuitry runs like roots; vegetation reclaims chassis;
rock and alloy share the same weathered register. This takes the *wonder* of Horizon
Zero Dawn's machines-as-nature and **diverges hard**: stylized, colorful **2D**, not
photoreal 3D (Reference Board / §9).

### 6.2 The Environment's Job Is to Recede

The single non-negotiable environmental rule is **figure/ground (§3.5)**: Symbots are
high-frequency, saturated, intentional; the environment must be **low-frequency,
irregular, and lower-saturation** so the bots read as figure against it. Everything
below serves that rule.

- **Contour**: irregular, organic, low corner-incidence — the opposite of the bot's
  intentional silhouette and the UI's hard chamfer. "Curves that *nobody chose*" vs.
  the bot's "curves that grew to a job."
- **Frequency**: broad shapes, gentle gradients, sparse high-detail accents. Detail
  clusters (a glinting circuit-vein, a crystal facet) are *rare punctuation*, never
  wallpaper — a busy background is a §3.5 violation and directly harms the combat
  read.

### 6.3 Texture Philosophy — Matte Painted, Not PBR

- **Stylized painted surfaces, matte finish.** No physically-based rendering, no
  glossy speculars competing with the bots (Kinetic's chrome finish, §4.2, must stay
  the shiniest thing on screen — an environment must never out-specular a bot).
- **World palette only** (§4.1): Ironmoss Green / Alloy Ochre / Slate Gunmetal /
  Wilderness Amber / Circuit Teal / Harvest Crimson / Bone White.
- **The matte-amber discipline is BLOCKING** (§4.1 handshake): environment ambers
  (W-2 Alloy Ochre, W-4 Wilderness Amber) are **matte and never carry the Flame
  Chevron glyph**. No environment surface is ever both amber-hued *and* glyph-bearing
   — that is reserved for Thermal (which always adds the glyph *and* an emissive
  bloom). An environment artist who puts a Flame Chevron on a rock has created a
  false element read.

### 6.4 Prop Density & Combat Legibility

- **Sparse by default.** The background is *ground*, not subject. Prop density rises
  only where it tells a story (§6.5) and never where a bot will stand to fight.
- **Combat backdrops desaturate and cool** (§4.6 Combat): during battle the ground
  shifts cooler and lower-saturation so the saturated bots + element glyphs pop — the
  §2.2 legibility-yield rule ("legibility wins without negotiation") applied to
  environment.
- **Overworld runs warm and high-ambient** (§4.6 Overworld): W-1/W-2 dominant,
  inviting, exploration-forward — the mood contrast with combat is intentional (§2).

### 6.5 Environmental Storytelling — Three Zone Vocabularies

Encounter zones vary their *shape and tint vocabulary* (§3.5, §4.6) without changing
the figure/ground contract. The three seed vocabularies each answer "what kind of
machines grew here" without a line of text:

| Zone vocabulary | Shape register | Tint lean (§4.6) | Story it tells |
|---|---|---|---|
| **Crystalline** | Faceted mineral growth, sharp geodes, refractive veins | Cool teal/violet | A place where energy crystallized — Volt-adjacent, ancient |
| **Vegetation** | Trailing overgrowth, root-cabling, reclaimed hulls | W-1 Ironmoss green | Nature winning; machines being *absorbed* back |
| **Industrial-Debris** | Angular wreckage, standardized panels, spent chassis | W-3 gunmetal + W-6 crimson hazard | Prior bots fought and fell here — history without a cutscene |

- **Debris implies prior Symbots**: a spent chassis or a broken part half-buried in a
  zone tells the player "others came before" — and rewards *looking*, which is the
  concept's substitute for a completion ledger ("discovery is the reward"). This is
  storytelling for a game that is deliberately **not story-first** (anti-pillar): the
  world carries the narrative load so the mechanics don't have to.
- **Hazard accents** use W-6 Harvest Crimson as *environmental* danger (§4.3 collision
  guard #6): a world surface, no UI cracked-icon — distinct from the UI's Danger Red.

### 6.6 Environment Checklist

- [ ] Reads as low-frequency ground against high-frequency bots at combat scale (§3.5).
- [ ] Contour is irregular/organic — not the bot's intentional curve, not the UI's chamfer.
- [ ] Matte finish; no surface out-speculars a bot; Kinetic chrome stays the shiniest thing.
- [ ] World palette only; no amber surface carries a Flame Chevron; hazard crimson is context-only (no UI icon).
- [ ] Combat backdrop desaturates/cools to yield to bots + glyphs.
- [ ] If a zone: one of the three shape vocabularies, with its §4.6 tint lean, consistently applied.

---

## 7. UI/HUD Visual Direction

*(Production guide. Derives from §3.6 (UI shape grammar), §4.3–§4.5 (semantic/chrome palette). Reconciled against `design/ux/interaction-patterns.md`, `design/ux/battle.md`, `design/ux/hud.md`, and `design/accessibility-requirements.md` (GAG Basic). No new commitments.)*

> **UX reconciliation — no conflict.** The art-director's UI direction and the
> ux-designer's interaction/accessibility contracts are already aligned, because the
> visual direction was authored *to* those contracts, not in parallel with them.
> Where the skill would normally spawn `art-director` + `ux-designer` and surface
> disagreements, there are none to surface: the chamfer grammar, the glyph-first
> system, and the dark-plate element badge all exist *because* the UX/accessibility
> docs required a non-color channel and a recede-from-the-bots chrome. The points of
> contact are noted inline below.

### 7.1 Curves Are Content, Hard Edges Are Chrome

The single UI rule, from §3.6: **the UI takes only the engineered-seam vocabulary —
geometric, angular, precise — leaving organic contour exclusively to Symbots and
environment.** By Gestalt similarity, if chrome used the bot's curves the eye would
group UI *with* the bots and the combat tactical read would suffer. So:

- **Panels**: straight lines, **45° chamfered corners** (never rounded), hard right
  angles. The chamfer is the UI's signature — "machined," a bridge to the bot's
  engineered-seam interior without borrowing its organic contour.
- **Break pips are rectilinear, never circular** (§3.6) — circles read too close to
  bot sensor/joint shapes and create figure/ground ambiguity in the most read-critical
  combat UI.
- **Chrome palette is fixed** at §4.5 C-1…C-7 (HUD Dark `#1E2229` base → C-7 secondary
  text `#98A4B4`). The UI is a distinct dark-slate language; it does not sample the
  world palette.

### 7.2 Iconography — The Glyph-First System Is Already Locked

The game's icon language is **not invented here** — it is ratified in §4:

- **Element glyphs** (§4.2): Lightning Fork (Volt) / Flame Chevron (Thermal) / Impact
  Ring (Kinetic), mapped to the type cycle so "what beats what" is learnable from
  icons alone.
- **Semantic co-channels** (§4.3): every semantic color carries a mandatory non-color
  cue — cracked-icon (danger), up-arrow/"+" (heal), star/trophy (reward), selection
  outline (interactive).
- **Rarity borders** (§4.4): border-count is the greyscale channel (1/2/3/animated).
- **Effectiveness arrows** (§4.5): ▲ / ▼ / – glyph-first on the target picker (PG-06).

§7's only iconography job is **style**: icons are **flat/outlined, machined** — the
same chamfered, precise register as the panels. No illustrated or photoreal icons; an
icon must read at target-picker scale on a C-1 plate.

### 7.3 Typography

- **Technical/engineered sans-serif** — clean, high-legibility, mechanical
  personality (matches "machined" chrome; avoids humanist warmth reserved for the
  organic bots/world).
- **Hierarchy by weight and size**, not by color (color is reserved for semantics,
  §4.3). Primary text C-6 `#E8E8E8` (13.5:1 on C-1); secondary C-7 `#98A4B4` (4.9:1).
- **Mobile-legible**: type sized for phone viewing distance; body text meets the
  `accessibility-requirements.md` §1.1 WCAG-AA 4.5:1 floor (verified on-device).
- **Localization headroom**: label styling must tolerate the string-length growth
  flagged in the UX specs' Localization sections — no text baked into fixed-width art.

### 7.4 Animation Feel

- **Crisp, mechanical, snappy** — chrome animates like a machine actuating (quick
  ease-out, decisive settle), never with organic overshoot/squash (that language
  belongs to the bots).
- **Flash-safety is BLOCKING**: no UI motion exceeds **< 3 Hz** (§4.4 /
  `accessibility-requirements.md` §1.4 — the one photosensitivity floor that is a hard
  gate). Prototype shimmer and CORE pulse are amplitude-modulated, not strobes.
- **Reduced-motion honored**: any non-essential UI motion has a reduced-motion path
  per the accessibility doc; essential state changes still resolve without motion
  (color+glyph+position carry the state, per §4.3).

### 7.5 Contact Points With the UX Specs

These are the places §7 must stay in sync with an already-authored UX spec — noted so
a future `/ux-review` catches drift, not resolved by unilateral edit here:

- **Touch targets** (`accessibility-requirements.md` §2.1, `interaction-patterns.md`
  PC-01): the chamfer is **visual only** — the ≥44×44pt (≥56px preferred) tap target
  applies to the full bounding box, not the chamfered visual boundary. Confirm with
  the UI programmer at implementation (§3.6 already flags this).
- **HUD dense-minimalism** (`design/ux/hud.md`): §7's chrome must support hud.md's
  dense-minimal philosophy — high signal, low chrome-weight; panels earn their pixels.
- **Fading-corner combat log** (`hud.md` open question refining `battle.md` PG-08): if
  the fading transparent-corner log is adopted over battle.md's boxed PG-08 log, the
  art treatment (transparency ramp, no chamfered box) is supportable within this
  grammar — but that adoption is **battle.md's decision via `/ux-review`**, not an art
  edit. §7 commits only to *supporting whichever the UX review lands on*.
- **Workshop ambient framing** (§2.6, §3.6): the Workshop may use softer *ambient*
  framing (bench-lamp metaphor), but interactive elements stay chamfered — softening
  is decoration, never functional chrome.

---

## 8. Asset Standards

*(Production guide + technical constraint. Binds to `.claude/docs/technical-preferences.md`: Godot 4.7, 2D CanvasItem renderer, **200 draw calls**, **512 MB** memory ceiling, **60 fps** / 16.6 ms, touch-first iOS primary. This section carries the hard numbers that keep the art producible on the target device.)*

> **This is where production cost is born.** Ambiguity in asset standards is the most
> expensive kind of ambiguity in the art bible. Where an art *preference* collides
> with a technical *constraint*, the constraint wins and the tradeoff is stated —
> never left implicit.

### 8.1 The Modular Part-Render Pipeline

A Symbot is **not a single sprite** — it is a **composite of per-slot sprites** layered
at standardized attach points. This is the render-side expression of §3.8's universal
attachment grammar:

- **One sprite per slot**, drawn in a fixed z-order (stance-bottom LEGS → torso
  CHASSIS → ARMS/WEAPON → HEAD-top; CHIPSET/ENERGY_CELL embedded/flush per §3.7).
- **Standardized attach points**: because §3.8 guarantees aligned joint seams and
  standardized slot positions, the compositor can place any part at the slot's fixed
  anchor without per-combination rework. **The attachment grammar is the contract the
  pipeline depends on** — a part delivered off-grid breaks compositing, not just
  aesthetics.
- **Swap = replace one layer**: equipping a part swaps its slot sprite only; the rest
  of the build is untouched. This is what makes "the build is the character" (§5.1)
  cheap to render.

### 8.2 Draw-Call Discipline (Hard: ≤ 200)

The 200-draw-call budget (`technical-preferences.md`, ADR-0008) is a mobile-2D
ceiling. Modular compositing multiplies sprite count, so batching is mandatory:

- **Per-faction / per-slot texture atlases**: all parts of a faction (or a slot family)
  share an atlas so the composited bot batches into few draw calls, not one-per-part.
- **Shared `Theme`, no per-widget materials** (ADR-0008 `ui_unique_material_batch_break`
  forbidden pattern): UI chrome draws from one Theme; a unique material per widget
  breaks batching and is prohibited.
- **Glow and shimmer via ONE shared shader, not per-instance materials**: rare
  ambient glow (§4.4 ~25%), boss radiant edge (~60%), and Prototype chromatic shimmer
  are a **single parameterized shader** applied across instances — never a distinct
  material per part. A per-part material for glow would blow the draw-call budget on
  exactly the rarest, most-visible items.

### 8.3 Resolution Tiers & LOD

- **Author at Workshop resolution** (target **256×256px** per part), where the camera
  is close and parts read at true color (§4.6). This is the source-of-truth asset.
- **Combat LOD ≈ 64×64px** (the recurring greyscale-test scale) resolves from the
  authored asset via the atlas **mip chain** — not a separately-drawn asset. §5.6's
  LOD philosophy governs *what* survives; the mip chain is *how*.
- **The 512 MB ceiling governs authoring resolution, not the reverse**: if the full
  part catalog at 256px + atlases exceeds the memory budget on device, resolution
  drops toward the ceiling — **never the silhouette clarity** (§3.1). Silhouette read
  is load-bearing; a pixel-count is not.

> **Flagged conflict, resolved (art preference vs. technical constraint).**
> *Ideal:* author every part high enough for satisfying Workshop zoom.
> *Constraint:* 512 MB iOS ceiling across a growing modular catalog + atlases.
> *Resolution:* 256px authoring + shared atlases + mipmaps. Measure atlas memory
> against the ceiling during the vertical-slice hardware pass (VC-7, deferred). If it
> exceeds, reduce authoring resolution catalog-wide before sacrificing any §3
> silhouette/greyscale contract. **The greyscale read is never the variable that gives.**

### 8.4 File Formats & Naming

- **Source art**: PNG (lossless, alpha) → Godot `.import`. No lossy source for parts
  (compositing + mip chain compound artifacts).
- **Game data**: stays `.tres` — the existing content pipeline (`PartDef`, catalogs)
  is unchanged; §8 governs the *visual* asset only.
- **Naming** (matches `technical-preferences.md` snake_case file convention):
  - In-world part sprite: `part_[faction]_[slot]_[name].png`
    (e.g. `part_ironclad_chassis_bulwark_frame.png`).
  - **UI slot-glyph icon is a SEPARATE asset** from the in-world sprite (§3.2 tertiary
    identifier / §3.6 — the identity icon lives in inventory/Workshop/target-picker UI
    and is **never applied to the in-world model**): `icon_slot_[slot].png`,
    `icon_element_[element].png`. Conflating the two is a §3.6 violation.
- **Faction-name caveat**: filenames currently use the confirmed *manufacturer*
  identities (Ironclad / Boltwell / Scrapjaw), which are stable. The four **faction
  shape-vocabulary** placeholder names (§3.8 Smoothshell/Hardform/Wirework/Fluxform)
  must **not** be baked into filenames until renamed with the narrative team.

### 8.5 Asset Delivery Checklist (per part)

- [ ] Authored at 256×256px PNG, alpha-clean, matte (no baked specular except Kinetic chrome finish §4.2).
- [ ] Attach points on the §3.8 standardized grid — composites without manual nudging.
- [ ] Passes the §3.9 part-artist shape checklist (slot read, greyscale, connection grammar, break legibility).
- [ ] Assigned to the correct faction/slot atlas (batches within the 200-call budget).
- [ ] Glow/shimmer, if any, references the shared rarity shader — no per-part material.
- [ ] Separate UI slot/element glyph icon delivered; not applied to the in-world sprite.
- [ ] Naming matches `part_[faction]_[slot]_[name]` / `icon_[type]_[key]`.

---

## 9. Reference Direction

*(Formalizes the Reference Board at the top of this bible into take / avoid / diverge
per source. References are **additive** — no two point in the same direction. Each
"Take" is a specific technique or rule, never "the general aesthetic," and each
"Avoid" prevents the "trying to copy X" reading.)*

| Reference | **Take** (specific) | **Avoid / Diverge** |
|---|---|---|
| **Medabots** *(PRIMARY)* | Each part **visibly signals its function**; part-break as spectacle (parts detach when destroyed — mirrors our break loop §3.7); bots read as **charismatic personalities** via silhouette + stance, not appliances; bright saturated character-forward color. | Do **not** copy Medabots' anime line-art rendering or its exact bot roster/IP silhouettes. Our bots are player-*assembled* systems (§5.1), not fixed named characters — the modularity is deeper and the read must survive at 64×64px greyscale, which the source never needed. |
| **Horizon Zero Dawn** | Machines-as-**nature**: the wonder of mechanical things that *grew into* an ecosystem (§6.1 "grew here, not placed here"). | Diverge **hard** from photoreal 3D + PBR. We are stylized, colorful, matte **2D** (§6.3). Take the *concept* of the machine-wilderness, not one pixel of the rendering. |
| **Zoids** | Creature-archetype legibility from the **mechanical silhouette** — insectoid / reptilian / avian read instantly from outline. Reinforces the §3.2 role-from-silhouette contract. | Avoid Zoids' realistic mechanical density and monochrome-military palette — it fights our saturated figure/ground (§3.5) and the 64px greyscale read. |
| **Gunpla (Gundam kits)** | **Intentional** panel seams and panel lines — every Symbot reads as a kit *deliberately assembled*, never a random pile (§1 One-Line Rule "looks like a decision"; §3.8 attachment grammar). | Avoid Gunpla's realistic panel-line *density* and neutral kit-grey — too high-frequency and too desaturated for the combat read at scale. Take the **intentionality**, not the detail count. |
| **Digimon** | Companions that feel **engineered, not magical**; a bright saturated palette used as a character-forward signal (supports Pillar 4 "colorful mechanical wilderness"). | Avoid Digimon's organic-creature body plans and any "monster" reading — our companions are unambiguously *machines* (engineered seam §3.4), and the CORE bond (§5.3) replaces the monster-partner trope. |

**Additivity check** — each reference owns a distinct axis, so none collides:
Medabots = *function-signaling modularity & charisma*; Horizon = *machine-in-nature
worldbuilding*; Zoids = *creature-read from mechanical silhouette*; Gunpla =
*assembly intentionality*; Digimon = *engineered-not-magical + saturated color*. If a
new reference is proposed, it must claim an axis none of these already own, or it is
redundant.
