# Building maps

How to draw the overworld: ground, decoration, and walls. Everything here is done in the
Godot editor — no code.

> **Enemy placement is not in this document, and that is deliberate.** In this game's
> design, *painting terrain is how you place enemies*: a terrain type is bound to a
> weighted enemy pool, so the ground you draw decides what you meet standing on it. That
> system (`src/core/encounter_zone/`) is built and tested but not yet wired to the
> overworld. Until it is, enemies come from a fixed list in `overworld_screen.gd`.
> See "What is not wired yet" at the bottom.

---

## Open the map

`src/scenes/overworld_screen.tscn` → the world lives under `WorldView/WorldViewport`:

| Node | What it is | Auto-filled? |
|------|-----------|--------------|
| `Terrain` | The ground. Every cell gets a tile. | Yes — empty cells only |
| `Decals` | Scrap, plants. Transparent overlays **on top of** the ground. | Yes — sparse, empty cells only |
| `Obstacles` | **Walls.** Anything painted here blocks the player. | **No — entirely yours** |

Select a layer, then use the TileMap panel at the bottom of the editor to paint.

**The auto-fill only touches cells you left empty.** Anything you paint is kept — the code
never overwrites your work, so you can paint a region and leave the rest generated.

## The tiles

The tileset is `assets/art/overworld/terrain_tileset.tres`, one atlas, 64×64 tiles:

| Tile | Use |
|------|-----|
| 0 | Ground — the only full ground tile today |
| 1, 2, 3 | Decals — **transparent**. Paint these on `Decals`, never on `Terrain`: on the ground layer they punch a hole in the floor |
| 4 | Obstacle placeholder — a darkened slate variant of the ground, standing in until real wall art exists |

## Walls

Paint anything on `Obstacles` and it blocks. That is the whole rule — no per-tile flag to
set, nothing to keep in sync when tiles are added.

Collision is measured at the character's **feet**, not the full sprite, which is why you
can walk with the head overlapping a wall above you. That is intended: colliding with the
whole 126px sprite would stop the player a head short of every wall and make corridors
feel narrower than they look. `FEET_SIZE` and `FEET_OFFSET_Y` in `overworld_screen.gd`
tune it.

Movement resolves each axis separately, so walking diagonally into a wall **slides along
it** instead of sticking.

## Map size

`WORLD_TILES` in `overworld_screen.gd` — currently 40×26 tiles (2560×1664 px, about
2.7 × 3 screens). The camera clamps to these bounds, so the player never sees past the
edge. Changing it changes how much there is to paint.

---

## What is not wired yet

Three things stand between this and the map the design describes:

1. **Only one ground tile.** You cannot draw a *path* with a single ground tile — a path
   needs to contrast with what surrounds it. The design defines four terrain types
   (`MECHANICAL_GRASS`, `JUNKYARD`, `PYLON_FIELD`, `MACHINE_CAVERN`) and there is art for
   none of them.
2. **No zone is authored.** `ZoneDef` binds each terrain type to its enemy pool and
   encounter rate. `assets/data/` has no zones folder yet.
3. **The overworld does not read terrain.** It never asks which tile the player is on and
   never calls `EncounterResolver`, so painting terrain currently changes only how the map
   looks — not what lives there.

Until those land, enemies are six fixed positions in `_scatter_spots()`.
