# Part-Break System

> **Status**: In Design
> **Author**: Luan + Claude Code Game Studios agents
> **Last Updated**: 2026-07-11
> **Implements Pillar**: Pillar 2 (Every Battle Has a Harvest Goal), Pillar 1 (Engineer, Don't Collect)

## Overview

The Part-Break System is the runtime break state tracker for Symbots — the layer that gives enemy regions a separate, damageable health pool distinct from their total Structure, watches for region damage events during combat, and emits a break event to the victory payload when a pool is depleted. It has no logic of its own about *what* an enemy is or *what* drops when it breaks; it only answers "how much cumulative targeted damage has this region taken, and has it crossed its threshold?" Everything else belongs elsewhere: the Enemy Database authors the regions and their break HP fractions, TBC routes per-hit damage to the appropriate region pool via its `hit_resolved` hook, and the Drop System converts the emitted break events into loot multipliers.

For the player, this system is invisible machinery behind the most important per-turn question in Symbots: *"Do I route this hit into the arm or just finish it?"* That question — the harvest dilemma — only exists because break regions have real HP pools with real thresholds. A player who breaks a WILD enemy's torso before the kill sees a different loot screen than one who didn't. A player who shatters a Boss's leg before the kill may see the Boss-grade Core they came for. Part-Break makes "break the right part" a legible, achievable plan with a satisfying visual and audio payoff at the moment of break — not a vague suggestion.

## Player Fantasy

The player never thinks "the Part-Break system tracked region damage." They think: *"Three more Kinetic hits and that arm is gone. Can I survive three more turns at this Heat?"*

Part-Break's emotional signature is the **shopping list made concrete**. In the game concept's words, every battle is a harvest decision — but that decision only has teeth when breaking a region costs something. The player who routes three turns of sub-optimal damage into an arm instead of finishing fast is making a bet: the Servo Arm is worth those turns, and they can survive them. When the arm shatters, the bet pays. When it doesn't — when they misjudged the enemy's counter-damage and got DOWNED a turn before the break — the lesson lands clearly: *I aimed for the arm too late.* That's the Monster Hunter DNA translated to turn tempo. The enemy is a walking shopping list; Part-Break is the mechanism that charges you for reading from it.

The peak beat is the **break pop**: the moment a region threshold is crossed, the enemy's part explodes visually, an audio cue lands, and the break event fires into the victory payload. At that moment the player knows — before the loot screen even appears — that their targeting investment paid off. The harvesting fantasy is causal: *I broke it, so I get a shot at it.*

Beneath the pop, two quieter experiences sustain the system. First, **progress visibility**: break pips on the Combat UI show accumulated region damage as a partial fill (authored for Combat UI — not owned here), so the player always knows whether they're two hits or eight hits from the threshold. Without that feedback the break goal feels like gambling, not execution. Second, **persistence convergence**: the break-failure pity mechanic (Part-Break's DB3 obligation) means that even a player who consistently targets correctly but gets unlucky with break *firing* is guaranteed to eventually get the event. Bad luck can add turns, never wall the goal.

*Joint delivery note: the peak beat requires Combat UI (break pips) and Audio System (break SFX) to be realized. This GDD builds the break event emission; Combat UI owns the visual progress; Audio owns the sound. Neither this system nor TBC alone delivers the full fantasy.*

## Detailed Design

### Core Rules

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
