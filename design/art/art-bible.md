# Art Bible: Symbots

## Document Status
- **Version**: 0.1 (in progress)
- **Last Updated**: 2026-07-15
- **Owned By**: art-director
- **Status**: Draft — authoring Visual Identity Foundation (Sections 1–4)
- **Scope this pass**: Sections 1–4 only (gate: Technical Setup → Pre-Production). Sections 5–9 deferred to a later authoring pass.
- **Art Director Sign-Off (AD-ART-BIBLE)**: pending

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

[being authored]

---

## 5. Character Design Direction

[To be authored — deferred to a later pass (not required for the Pre-Production gate).]

---

## 6. Environment Design Language

[To be authored — deferred.]

---

## 7. UI/HUD Visual Direction

[To be authored — deferred. Will reconcile with `design/ux/interaction-patterns.md` + `design/ux/accessibility-requirements.md` (GAG Basic).]

---

## 8. Asset Standards

[To be authored — deferred. Will bind to `.claude/docs/technical-preferences.md` budgets (200 draw calls, 512 MB, 60 fps) and the modular part-render pipeline.]

---

## 9. Reference Direction

[To be authored — deferred. Reference Board above is the working seed.]
