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

[being authored]

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
