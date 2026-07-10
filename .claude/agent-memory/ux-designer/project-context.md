---
name: project-context
description: Symbots game context relevant to UX design decisions — creature-collection RPG, modular robot building
metadata:
  type: project
---

**Game:** Symbots -- creature-collection RPG with modular robot building.

**Core pillars (UX-relevant):**
- Pillar 1: Engineer, Don't Collect -- the Workshop is the primary creative act, not capture screens
- Pillar 3: Build Depth Over Content Breadth -- fewer parts, more meaningful decisions
- Pillar 4: Synergy Is the Endgame -- cross-part tag combinations are the depth layer

**Team structure:** 3 Symbots (`TEAM_ROSTER_CAP=3`), each with 8 equipped slots.

**8 slots per Symbot:** CORE, CHASSIS, CHIPSET, ENERGY_CELL, HEAD, ARMS, LEGS, WEAPON.

**11 stats:** structure, armor, resistance, physical_power, energy_power, mobility, targeting, processing, cooling, energy_capacity, recharge.

**4 moves per Symbot:** Basic Attack (always), Move 2 (WEAPON skill), Move 3 (HEAD skill), Move 4 (ARMS skill -- null if Common ARMS).

**Workshop is the primary build screen.** All part swaps happen here. The Workshop UI GDD has not been authored yet (as of 2026-07-10) -- the Symbot Assembly GDD defers it to `/ux-design`.

**Primary platform:** iOS touch. Mac keyboard/mouse is development + early launch. No gamepad.

**Why:** Understanding these constraints shapes every Workshop and combat UI decision -- especially the tension between 11-stat depth and mobile screen real estate.

**How to apply:** When authoring `design/ux/workshop.md`, the 8-slot layout, 11-stat display, 3-Symbot navigation, and iOS touch interaction model must all be resolved simultaneously. See [[workshop-ux-open-issues]] for the open problems inherited from the Assembly GDD.
