#!/usr/bin/env python3
"""Derive an overworld collision mask from a painted map image.

When the map is one big image rather than a tileset, collision has no data to come
from — the art carries it. This reads the image and classifies each tile of the world
grid as solid or walkable, so the tedious part (tracing every wall perimeter) is
automatic and only the misreads need a human.

It is deliberately NOT a general image segmenter. It encodes three observations about
this project's map art, each of which failed a simpler rule first:

1. Walls are bluish and dark. Grass and dirt are not. A luminance threshold alone does
   not work — the wall slate and the grass sit at the same luminance (~79), so the
   discriminator is the blue-vs-green relationship, not brightness.

2. Dark WALKABLE terrain exists (the cavern floor), and colour cannot tell it from a
   wall. Geometry can: walls are thin, floors are thick. A blob that survives two
   erosions is a floor, so it is reconstructed by dilation and subtracted.

3. The junkyard floor is dark slate MIXED WITH OCHRE brick. It is irregular and thin,
   so it survives the erosion test and would be walled off. Ochre content is the
   discriminator: walls are pure slate, junkyard ground is not.

Usage:
    python3 tools/derive_map_collision.py assets/art/overworld/map_v2.png [--out mask.json]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - environment guard
    sys.exit("Pillow is required: python3 -m pip install Pillow")

GRID_W, GRID_H = 40, 26
TILE = 64
WALL_COVERAGE = 0.60      # fraction of a tile that must read as wall
OCHRE_FLOOR_RATIO = 0.12  # above this, the tile is junkyard ground, not wall

# Declared exceptions — regions the classifier gets wrong, cleared to WALKABLE.
#
# This list exists on purpose rather than being tuned away. The junkyard floor is dark
# slate broken up by ochre brick in patches too small and irregular for either test to
# catch: it is not thick enough to read as a floor blob, and any single tile is more
# slate than ochre. Loosening either threshold to catch it starts eating real walls
# elsewhere on the map.
#
# An explicit, named exception is honest about what is automated and what is not.
# Chasing a classifier that needs no exceptions would cost more than the exception does,
# and would fail differently on the next map instead of failing visibly here.
#
# Each entry: (x, y, w, h) in tiles, plus why.
WALKABLE_OVERRIDES = [
    ((3, 1, 12, 9), "junkyard interior — walkable terrain patch, reads as wall"),
]


def is_wall_px(r: int, g: int, b: int) -> bool:
    """Bluish and dark. Blue-vs-green, not luminance — see the module docstring."""
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return b >= g - 8 and lum < 110


def is_ochre_px(r: int, g: int, b: int) -> bool:
    """Rust/brick: warm, red above blue by a clear margin."""
    return r > 90 and r > b + 30 and g > b


def erode(mask: list[list[bool]]) -> list[list[bool]]:
    out = [[False] * GRID_W for _ in range(GRID_H)]
    for y in range(GRID_H):
        for x in range(GRID_W):
            if not mask[y][x]:
                continue
            if all(
                0 <= y + dy < GRID_H and 0 <= x + dx < GRID_W and mask[y + dy][x + dx]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1)
            ):
                out[y][x] = True
    return out


def dilate(mask: list[list[bool]]) -> list[list[bool]]:
    out = [[False] * GRID_W for _ in range(GRID_H)]
    for y in range(GRID_H):
        for x in range(GRID_W):
            if not mask[y][x]:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < GRID_H and 0 <= nx < GRID_W:
                        out[ny][nx] = True
    return out


def derive(path: Path) -> list[list[bool]]:
    im = Image.open(path).convert("RGB")
    want = (GRID_W * TILE, GRID_H * TILE)
    if im.size != want:
        print(f"  note: resizing {im.size} -> {want} (nearest)")
        im = im.resize(want, Image.NEAREST)
    px = im.load()

    raw = [[False] * GRID_W for _ in range(GRID_H)]
    ochre = [[False] * GRID_W for _ in range(GRID_H)]
    for ty in range(GRID_H):
        for tx in range(GRID_W):
            wall = warm = n = 0
            # Inset by 8px: tile borders blend into the neighbour and would over-report.
            for yy in range(ty * TILE + 8, (ty + 1) * TILE - 8, 6):
                for xx in range(tx * TILE + 8, (tx + 1) * TILE - 8, 6):
                    n += 1
                    r, g, b = px[xx, yy]
                    wall += is_wall_px(r, g, b)
                    warm += is_ochre_px(r, g, b)
            raw[ty][tx] = wall / n > WALL_COVERAGE
            ochre[ty][tx] = warm / n > OCHRE_FLOOR_RATIO

    floors = dilate(dilate(erode(erode(raw))))
    final = [
        [raw[y][x] and not floors[y][x] and not ochre[y][x] for x in range(GRID_W)]
        for y in range(GRID_H)
    ]
    print(f"  raw walls: {sum(map(sum, raw))}")
    print(f"  thick dark floors removed: {sum(map(sum, floors))}")
    print(f"  ochre (junkyard ground) removed: {sum(map(sum, ochre))}")

    for (ox, oy, ow, oh), why in WALKABLE_OVERRIDES:
        cleared = 0
        for y in range(oy, min(oy + oh, GRID_H)):
            for x in range(ox, min(ox + ow, GRID_W)):
                if final[y][x]:
                    final[y][x] = False
                    cleared += 1
        print(f"  override ({ox},{oy},{ow},{oh}) cleared {cleared}: {why}")

    print(f"  FINAL: {sum(map(sum, final))} solid tiles of {GRID_W * GRID_H}")
    return final


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image", type=Path)
    ap.add_argument("--out", type=Path, default=Path("map_collision.json"))
    args = ap.parse_args()
    mask = derive(args.image)
    args.out.write_text(json.dumps(mask))
    print(f"  wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
