# Symbots — Vertical Slice

> **VERTICAL SLICE — NOT FOR PRODUCTION**
> This build is reference-only. Production code is written from scratch; it must
> never import from `prototypes/`, and slice code is never refactored into `src/`.

## Validation Question

> *"Does a player, starting from a stock Symbot, break a specific enemy component,
> harvest the part they targeted, re-equip it, and feel their build get stronger —
> within ~3 minutes, unguided? And can we build one such loop at representative
> quality on top of the existing core?"*

## What this slice reuses vs. builds

The pure core (`src/core/`) is already implemented and green at 913 tests — battle
FSM, stat pipeline, synergy, drop system. The slice does **not** reimplement any of
it. It builds the **presentation + glue layer** that never existed (this project has
zero scenes/autoloads — the slice is the first playable entry point).

## The core loop being validated

```
stock Symbot ──▶ battle Rustcrawler ──▶ target & break its ARM ──▶ arm_broken fires
      ▲                                                                    │
      │                                                                    ▼
  feel stronger ◀── re-equip in workshop ◀── harvest the RARE arm ◀── drop resolves
```

## Build phases

See `BUILD-PLAN.md`. Phase 4a (headless harness) proves the whole loop wires
end-to-end against the real core before any UI exists.

## Running the headless harness (Phase 4a)

```sh
godot --headless -s prototypes/symbots-vertical-slice/slice_bootstrap.gd
```

It loads real content, assembles a stock Scrapjaw Symbot, fights the Rustcrawler,
breaks its arm, farms until the rare `reinforced_servo_arm` drops, re-equips it,
and prints the stat delta.
