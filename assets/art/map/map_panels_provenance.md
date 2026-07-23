# Stage map background provenance

Version 4 removes the visible joins from Version 3 while preserving its approved mid-1990s mecha-anime cel artwork, regions, route, UI-safe corridor, filenames, and runtime dimensions.

The previous direct-stack export is preserved in `old/v3-visible-seams/`. The artwork that preceded Version 3 remains in `old/019f8738-fb5f-7c82-bda2-8d7956fe6fdb/`.

## Why Version 3 showed seams

The four ImageGen frames were generated sequentially and shared the same route and regional progression, but their exact boundary rows still contained different texture, value, and landmark information. A direct 4→3→2→1 stack therefore produced horizontal cuts even though each individual panel was visually valid.

## Seamless master construction

No new semantic image generation was used for Version 4. The approved four panels were rebuilt into one continuous master deterministically:

1. Each 1080×1920 source panel was normalized to 1080×2400.
2. Panels 4, 3, 2, and 1 were placed at `y=0`, `1760`, `3520`, and `5280`.
3. Every adjacent pair overlaps by 640 pixels.
4. Each overlap uses the complementary cosine curve `0.5 - 0.5 × cos(πt)`, keeping details crisp near the ends and concentrating the blend in the middle.
5. The final 1080×7680 master was cropped at `y=0`, `1920`, `3840`, and `5760` to create the runtime panels.

Because the runtime boundaries now fall inside continuous overlap regions, no boundary coincides with a palette or texture change.

## Prompt set and visual direction

The ImageGen source prompt set remains unchanged from Version 3:

- Steep oblique game-world-map view with no sky horizon.
- Finished mid-1990s hand-drawn mecha television-anime background treatment.
- Irregular dark outlines, chunky industrial geometry, flat colour blocks, and hard cel shadows.
- One unmarked route fixed at `x=540`; centre 35–65% kept calm for timeline UI.
- Scrap flats, signal belt, foundry, and apex regions progressing from bottom to top.
- No characters, creatures, vehicles, text, markers, UI, logos, frames, or watermarks.

The source images were generated with built-in ImageGen in session `019f8cca-ddee-7411-bfcd-b2862080801f`. Version 4 changes only deterministic scaling, overlap, blending, and cropping.

## Verification

- `map_full.png` is an sRGB PNG at exactly 1080×7680.
- Each runtime panel is an sRGB PNG at exactly 1080×1920.
- Reassembling Panels 4, 3, 2, and 1 produces zero differing pixels compared with the master.
- Boundary row MAE values are 0.0179, 0.0230, and 0.0104 at `y=1920`, `3840`, and `5760`; each falls within normal adjacent-row variation around the same location, so none is a statistical edge spike.
- Visual QA confirmed that the three runtime cuts are imperceptible in the complete map and that the centred route remains continuous.
