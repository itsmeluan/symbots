# Symbots modular part set — generated v1

This set covers every authored part in `assets/data/parts/` as of 2026-07-18.

## Folders

- `final/`: isolated transparent PNGs used as the clean inputs for pixel-art conversion.
- `source/`: lossless originals on a flat `#ff00ff` key background.
- `reference/`: the visual reference supplied for this production pass.
- `../<part_id>.png`: runtime-ready copies named exactly like the authored `.tres` IDs.

`final/assembly-anchor.png` fixes the camera, proportions, finish, and installation direction.
`final/attachment-rig.png` documents the shared neck, shoulder, torso, hip, and weapon-rail
connection grammar. Use both whenever a new compatible part is generated.

Arm and leg definitions are logical paired slots in the current content model. Their PNG
therefore contains the detached left/right pair in one file; the two pieces remain visibly
separated so they can be split later if the renderer moves to independent limb slots.

## PixelLab conversion guidance

Convert one file at a time. The authored part-icon target is **256x256 px**. Keep the original
framing and orientation, preserve every socket and rail location, and prevent automatic cropping
or rotation. Use the same target canvas for all assets in the same slot family. Preserve alpha,
hard silhouette steps, material color identity, and the empty clearance around attachment points.

Suggested conversion instruction:

> Convert this isolated modular chibi-mecha component into crisp production pixel art. Preserve
> the exact silhouette, three-quarter front-left view, scale inside the canvas, facing direction,
> colors, left/right separation, and every keyed socket or rail position. Do not crop, rotate,
> mirror, redesign, add parts, add effects, add a floor, or change the transparent background.
> Use a compact controlled palette, readable clusters, selective dark outlines, and no soft
> antialiasing. The result must remain mechanically compatible with the other Symbot parts.

The current runtime copies in `assets/art/parts/` are already aspect-fitted to transparent
256x256 canvases for immediate icon use. Replace them with the PixelLab exports using the same
snake_case filenames. The project already uses nearest-neighbor filtering and lossless texture
import.

See `manifest.json` for the complete `part_id`, `sprite_id`, slot, manufacturer, rarity,
element, and file mapping.

See `connection-spec.json` for the parent/child surface and pivot convention of each slot.
