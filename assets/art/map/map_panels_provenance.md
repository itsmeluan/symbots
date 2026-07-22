# Stage map background provenance

Version 2 replaces the hard four-panel joins with one continuous 1080×7680 master. The four 1080×1920 runtime panels are exact, non-resampled crops of that master, so stacking Panels 4, 3, 2, and 1 reconstructs the master pixel for pixel.

The previous exports and their metadata are preserved in `archive/v1/`.

## Visual direction

The lighter mechanical-wilderness direction is based on the approved Symbots mockups from Codex task `019f819a-3784-73f1-86c1-b6815d099a2c`, especially:

- `prototypes/symbots-ui-system/qa/v1-stage-map-390x844.png`
- `/Users/martinsluan/.codex/generated_images/019f819a-3784-73f1-86c1-b6815d099a2c/exec-b6af1fca-f910-4aae-b279-2dd72298e442.png`

The references informed daylight, lifted midtones, sage/olive terrain, cyan atmospheric depth, readable industrial ruins, and controlled amber highlights. Their UI, text, characters, and layout were not copied into the background.

## Generation and assembly

Five 9:16 source frames were generated bottom to top with the built-in image-generation workflow. Every frame after the first used the immediately preceding normalized frame as a continuity reference and repeated the same requirements for route position, viewpoint, terrain scale, palette progression, light direction, and a 25% continuation zone.

The normalized sources were placed on the 1080×7680 master with 480-pixel overlaps. Adjacent frames were combined with a complementary cosine feather, producing gradual transitions instead of hard joins. No stretching was used. The resulting master was then cropped at y=0, 1920, 3840, and 5760 for Panels 4, 3, 2, and 1 respectively.

## Prompt set

All five prompts used the `stylized-concept` taxonomy and shared these hard constraints:

- Painterly semi-realistic industrial-mechanical wilderness viewed from above at a steep map angle.
- One route fixed at x=50%, crossing every edge; calm central 35–65%; landmarks in the outer margins.
- Open daylight, lifted midtones, moderate saturation, and low-to-medium contrast.
- No characters, creatures, vehicles, people, text, numbers, symbols, icons, logos, UI, borders, markers, or watermarks.

The frame progression was:

1. Bright ochre and sage scrap flats with a cyan coolant crossing, dead crane, and collapsed sheds; the upper quarter begins the signal terrain.
2. Scrap terrain rises continuously into signal terraces with margin masts, dishes, cable trenches, blue-cyan air, and light frost.
3. Frosted signal terrain transitions continuously into a daylight foundry with readable slate iron, thin smoke, and restrained amber furnaces in the margins.
4. Foundry terraces climb through haze into readable blue-gray apex rock with restrained cyan mechanical/mineral accents.
5. The summit continues above side-valley cloud wisps into monumental dormant core structures in the upper margins under cold luminous daylight.

## Generated source images

- `/Users/martinsluan/.codex/generated_images/019f8757-e7df-7c12-a8c0-d551c328b123/exec-88af09e3-bffa-4ccd-9190-7b46e8208d40.png`
- `/Users/martinsluan/.codex/generated_images/019f8757-e7df-7c12-a8c0-d551c328b123/exec-efad6c56-b6d7-4b0f-84f3-132b29e515a0.png`
- `/Users/martinsluan/.codex/generated_images/019f8757-e7df-7c12-a8c0-d551c328b123/exec-974d937a-73bb-4aba-b767-f51b0384acd2.png`
- `/Users/martinsluan/.codex/generated_images/019f8757-e7df-7c12-a8c0-d551c328b123/exec-288e72ca-b883-4d3d-adfd-bdf175c4b456.png`
- `/Users/martinsluan/.codex/generated_images/019f8757-e7df-7c12-a8c0-d551c328b123/exec-150d77d5-f4a5-4c25-a450-42ec7608772b.png`

## Verification

- `map_full.png` is an RGB PNG at exactly 1080×7680.
- Each runtime panel is an RGB PNG at exactly 1080×1920.
- Reassembling the panels in order 4, 3, 2, 1 produces zero differing pixels compared with the master.
- The three panel boundaries have no row-difference spikes beyond normal local image variation.
- Mean luminance increased from v1 to v2 in every region, including the apex from 0.133 to 0.379.
- Visual QA confirmed the centered route, calm overlay corridor, margin landmarks, gradual biome transitions, and all content exclusions.
