# Tileset sources — delivery v1

Originals as delivered, before processing. `.gdignore` keeps Godot out of this folder;
the game-facing copies live in `assets/art/overworld/`.

## What was delivered

| Source file | Tile size | Layout | Runtime copy |
|---|---|---|---|
| `grass-dirt-wang-64.png` | 64px | 4×4 Wang (16 tiles) | `tileset_grass_dirt.png` |
| `wilderness-props-64.png` | 64px | 4×4 atlas, **not Wang** | `tileset_wilderness_props.png` |
| `stonebrick-grass-wang-96.png` | **96px** | 4×4 Wang (16 tiles) | **none — see below** |

## The delivered files have 1px separators

All three ship as a 4×4 grid with a **1px gap between tiles** — hence the odd
259×259 and 387×387 dimensions rather than clean multiples (4×64 + 3 = 259).

The runtime copies have the separators stripped, so they are clean 256×256 atlases that
a `TileSetAtlasSource` reads with no margin/separation configuration. Godot can handle
separators natively via the atlas source's `separation` property, but the project's
existing tileset uses none, and one convention is worth more than avoiding one strip step.

To re-process after a new delivery, the rule is: tile `(col, row)` starts at
`(col * (size + 1), row * (size + 1))`.

## Why the 96px one has no runtime copy

The project's tile size is **64px** (`terrain_tileset.tres`, and the world grid in
`overworld_screen.gd`). 96px tiles would need a 1.5× rescale — a fractional factor, which
on pixel art produces uneven pixel widths and is exactly what the project's nearest
filter and integer stretch mode exist to prevent.

It is kept here because the art is fine; only the size is wrong for this project. Using it
means either re-generating that terrain at 64px, or moving the whole project to 96px
tiles — which would change the visible tile count and every layout tuned against it.

## `wilderness-props-64.png` is not a terrain tileset

Despite the 4×4 grid, it is not a Wang set: the 16 cells are unrelated scene pieces —
ruins, pipes, machinery, vegetation, water — not corner-transition variants of two
terrains. Painting it on a terrain layer will not autotile; it is a decoration atlas,
closer in role to the `Decals` layer than to `Terrain`.
