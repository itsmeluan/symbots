---
name: project-encounter-zone-spatial-gaps
description: Three blocking spatial gaps in Encounter Zone GDD (#7) that must be resolved before Zone & World Map (#12) is authored
metadata:
  type: project
---

Encounter Zone GDD (#7) has three BLOCKING spatial gaps identified in level design review (2026-07-11):

**BG-1: Terrain boundary resolution unspecified.**
Rule 3 excludes path tiles from encounter triggers but never defines: (a) which tile's terrain_type resolves the encounter when crossing a boundary, (b) what a "path tile" is as a data concept, (c) whether a tile can have multiple terrain tags. Overworld Navigation and Zone & World Map will independently invent interpretations that may conflict.

**BG-2: WAVE arena has no spatial owner.**
Rule 7 says "enter the boss arena" for the WAVE gate. OQ-EZ-3 treats this as a presentation concern. It is actually a spatial feature — the arena must physically exist on the map, have an entry contract, and Zone & World Map must author it. Boss 2 is "OVERWORLD" placement, same as Boss 1, but the spatial behaviors are categorically different (arena entry vs. map icon tap). The conflation will cause Zone & World Map to miss the distinction.

**BG-3: OVERWORLD boss placement has no geometry contract.**
Rule 8 says the boss "becomes active" when the gate opens. This is behavioral but not spatial. Zone & World Map needs to know: is the boss a static entity on a non-encounter tile? On a terrain tile (meaning the farming re-access path always runs through encounter terrain)? A UI overlay marker? This affects pacing design fundamentally.

**Why these are blocking:**
Zone & World Map (#12) is the next level design authoring task. If these gaps aren't resolved first, #12 will make load-bearing spatial assumptions that contradict this GDD.

**How to apply:**
Before authoring Zone & World Map (#12), confirm these three gaps have been addressed in Encounter Zone GDD. Reference this memory when Zone & World Map work starts.

**See also:** [[project-symbots-context]]
