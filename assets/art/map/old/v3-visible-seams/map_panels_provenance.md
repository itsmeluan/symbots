# Stage map background provenance

Version 3 rebuilds the four runtime panels in the same visual direction as the approved Symbots battle backgrounds: finished mid-1990s hand-drawn mecha television-anime environmental art, with irregular dark outlines, simplified chunky machinery, two or three flat tones per surface, hard cel shadows, and controlled saturated colour blocks.

The previous map artwork and its metadata are preserved in `old/019f8738-fb5f-7c82-bda2-8d7956fe6fdb/`.

## Composition system

- Four portrait panels, generated and reviewed from bottom to top.
- A single route remains at `x=540` and crosses every horizontal edge.
- The centre column from 35–65% width remains calm for the dashed timeline, circular nodes, and alternating cards.
- Landmarks remain in the outer margins and separated horizontal bands.
- The top 12% and bottom 30% of each panel use restrained values for the header and stage-detail overlay.
- No characters, creatures, vehicles, text, numbers, markers, icons, logos, UI, frames, or watermarks.

## Prompt set

All panels used the `stylized-concept` taxonomy and the approved battle backgrounds as style anchors. The shared prompt required a steep oblique world-map view with no sky horizon; 1990s mecha-anime cel rendering; mid-to-dark values; a calm central corridor; and an unmarked route fixed at 50% width.

The regional prompts were:

1. **Scrap flats:** rust, ochre, dust-green, compacted scrap, a cyan coolant crossing, collapsed sheds, pipe fragments, and a dead crane in the margins.
2. **Signal belt:** rising grey-green terraces, lateral antenna and dish fields, broken relay structures, cable infrastructure, and frost increasing toward the top.
3. **The foundry:** dark iron and ash, lateral casting yards and furnaces, restrained flat orange embers, sparse smoke, and a clear central route.
4. **The apex:** foundry terrain continuing through the lower quarter, then bare black rock and a monumental dormant core complex in deep cyan on black, with a calm near-black summit header zone.

Panel 4 was generated a second time because its first lower edge changed from foundry to apex too abruptly. The selected retry preserves foundry pipework and restrained orange accents in its lower quarter before transitioning to the cold summit.

## Generation sources

Built-in ImageGen session: `019f8cca-ddee-7411-bfcd-b2862080801f`.

- Panel 1: `/Users/martinsluan/.codex/generated_images/019f8cca-ddee-7411-bfcd-b2862080801f/exec-38464353-97e6-4d18-a898-fa90c7344245.png`
- Panel 2: `/Users/martinsluan/.codex/generated_images/019f8cca-ddee-7411-bfcd-b2862080801f/exec-242299fd-2196-48f0-b2b3-026a9b79206a.png`
- Panel 3: `/Users/martinsluan/.codex/generated_images/019f8cca-ddee-7411-bfcd-b2862080801f/exec-4616c5b4-fe2e-4ad8-9830-dfdce2d462b2.png`
- Panel 4, discarded first attempt: `/Users/martinsluan/.codex/generated_images/019f8cca-ddee-7411-bfcd-b2862080801f/exec-cc1a20b4-03b7-463a-864b-3085f4ba8a09.png`
- Panel 4, selected retry: `/Users/martinsluan/.codex/generated_images/019f8cca-ddee-7411-bfcd-b2862080801f/exec-7d9d7a08-7bd0-4748-9c75-18c42310b32e.png`

Every selected source was normalized once to 1080×1920 sRGB PNG. `map_full.png` was then assembled deterministically by stacking Panels 4, 3, 2, and 1 without resampling or blending.

## Verification

- `map_full.png` is an sRGB PNG at exactly 1080×7680.
- Each runtime panel is an sRGB PNG at exactly 1080×1920.
- Reassembling the panels in order 4, 3, 2, and 1 produces zero differing pixels compared with the master.
- Visual QA confirmed the centred route, calm UI corridor, margin landmarks, continuous regional progression, and all content exclusions.
