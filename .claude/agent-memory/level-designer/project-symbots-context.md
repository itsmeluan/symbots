---
name: project-symbots-context
description: Symbots game context for level design work — one-zone MVP, terrain-keyed encounter system, mobile creature-collection RPG
metadata:
  type: project
---

Symbots is a mobile creature-collection RPG (Godot 4.6, GDScript). MVP = one zone, two bosses, turn-based combat. Core loop: explore terrain patches to hunt specific enemies, break parts, collect drops, build your Symbot.

**Why relevant to level design:**
- The "terrain = targeting lever" design means terrain patches are the primary spatial feature. Zone & World Map (#12) will realize them as map geometry.
- One zone in MVP with 3–4 terrain patches (MECHANICAL_GRASS, JUNKYARD, PYLON_FIELD, MACHINE_CAVERN).
- Two OVERWORLD bosses: Boss 1 = WIN_COUNT gate, Boss 2 = WAVE gate (arena-based).
- Encounter Zone GDD (#7) defines the data layer; Zone & World Map (#12) owns the spatial realization — this split is the main design tension for level work.

**Systems the level designer most directly depends on:**
- Encounter Zone (#7) — Designed, pending fresh-session /design-review
- Zone & World Map (#12) — Not Started
- Overworld Navigation (#16) — Not Started
- World Loot System (#13) — Not Started

**How to apply:** All level design work should be aware that Zone & World Map (#12) has not been authored yet. Any review of spatial systems should flag gaps that will cause incompatible decisions when #12 is authored.
