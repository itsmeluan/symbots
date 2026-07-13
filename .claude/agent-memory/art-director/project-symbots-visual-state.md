---
name: project-symbots-visual-state
description: Current state of all visual direction artifacts for Symbots — what exists, what is deferred, what GDDs have committed to
metadata:
  type: project
---

As of 2026-07-13 (Systems Design phase, entering Technical Setup gate):

**What exists:**
- Visual Identity Anchor in `design/gdd/game-concept.md` (line ~191): "Colorful Mechanical Wilderness" direction, one-line visual rule ("every element must feel like it grew here, not was placed here"), organic-machine silhouettes, part-readability test, elemental color language (Fire=amber/red, Electric=cyan/yellow), color philosophy (saturated, warm earth + cool metal, boss parts glow).
- Art style: Stylized 2D — pixel art or clean vector sprites; modular silhouette design.
- Element color contract committed in TBC GDD (V1-2): Volt=cyan, Thermal=amber, Kinetic=white/silver-white.
- Rarity glow table in symbot-assembly.md: Common=no glow, Rare=soft ambient element glow, Boss-grade=steady radiant + shader edge, Prototype=flickering instability shimmer.
- Sprite layer order (8 layers, z-order 1–8) in symbot-assembly.md Visual/Audio section.
- Detailed visual and audio intent in TBC GDD (V1–V5 sections): animation timing budgets, damage number escalation, status VFX intent, heat gauge three-zone design, switch animations, break-pop intent.
- Part-Break GDD: VA-1 through VA-5 visual intent (break-pop, escalating damage states, enrage telegraph, timing budget).
- Consumable DB: VA-1 (per-effect-type feedback), VA-2 (rarity readability).
- Core Progression: quiet level-up beat (line in post-battle summary OR glow on Workshop core slot); greyed-out parts becoming available as the core levels.
- Drop System: rarity-escalated drop reveal direction (Common quiet, Rare notable, Boss-grade/Prototype celebratory flourish).

**What does NOT exist:**
- No art bible (`design/art/` directory does not exist).
- No asset specifications (dimensions, formats, palette locks, animation frame budgets).
- No entity inventory.
- No color palette document.
- No Workshop UI, Combat UI, World Map UI, Main Menu GDDs.
- No Audio System GDD.

**Key commitments already made in approved GDDs that the art bible must ratify or extend (not contradict):**
- Element color assignments: Volt=cyan, Thermal=amber, Kinetic=white/silver
- Rarity glow table (Assembly)
- Sprite layer z-order table (Assembly)
- Animation timing budget: ≤2.0s per full turn resolution (TBC V2)
- Accessibility rule: never color alone (TBC V1-3, Part-Break VA-3)
- Touch target minimum: 44×44pt

**Why:** Art bible is authored during Technical Setup, before Pre-Production asset production. All approved GDDs flag "after Art Bible approved, run /asset-spec" as the next step for their visual sections.

**How to apply:** When `/art-bible` is invoked, use the GDD visual intent sections as input constraints. The art bible must ratify element colors, rarity glow language, and the sprite layering model — it cannot contradict them without triggering errata on 5+ approved GDDs.
