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

[being authored]

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
