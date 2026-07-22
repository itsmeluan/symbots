# Stage map background — spec and prompt

One continuous vertical journey behind the stage timeline. The player starts at the **bottom**
and climbs; the backdrop scrolls and changes region as they go.

## The constraint that shapes everything

**No image generator will produce a 360×2560 strip.** They emit a handful of fixed aspect
ratios, and 9:64 is not one of them. So the backdrop is generated as **four stacked portrait
panels**, each 9:16, designed to butt together at their horizontal edges.

That is not a workaround — it is better for this map. The stages already pass through four
regions, so each panel gets to be its own place, which is exactly the "the background changes
as you climb" the design wants.

## Geometry

Derived from the layout: viewport 360×640, 15 stages, nodes 128px apart.

| | |
|---|---|
| Timeline length | 14 gaps × 128px = **1792px** |
| Padding so stage 1 and stage 15 can both centre | 320px top + 320px bottom |
| **Total backdrop height** | **2432px → use 2560px = exactly 4 screens** |
| Panel size | 360×640 logical each, **export at 1080×1920** |
| Panel 1 is the BOTTOM | the player starts there |

Scroll is 1:1 with the timeline. **If you would rather generate only two panels**, scroll the
backdrop at half speed (parallax 0.5) — then 1280px of art covers the whole 2560px climb, and
it reads as depth rather than as a cost saving.

## What the art must leave alone

The timeline and its cards sit on top:

- A **dashed vertical line runs up the centre** (x = 50%), drawn by the UI.
- **Circular nodes** sit on that line, one per stage.
- **Name cards** extend from each node, about **62% of the width**, alternating left and right.
- The **bottom 30%** is covered by the stage-detail overlay when a card is tapped.
- The **top 12%** is covered by the header (STAGE MAP, currencies).

So the readable background is the side margins and the horizontal gaps between cards. Detail
belongs there — not in the centre column.

---

## THE PROMPT

Generate the four panels **in order, bottom to top**, feeding the previous panel back as a
reference image each time and asking it to continue the terrain across the seam.

> Portrait digital painting, **1080×1920 (9:16)**, panel **{N} of 4** of one continuous vertical
> map, viewed **from above at a steep angle, like a game world map**. Painterly, industrial
> sci-fi, **muted and desaturated**, low contrast.
>
> **This is panel {N}, read from the BOTTOM of the journey upward.** Its bottom edge must
> continue the terrain of the panel below it and its top edge must flow into the panel above —
> matching palette, matching light direction, and the central route crossing each edge at the
> same horizontal position (50% width).
>
> **Composition rules:**
>
> - A **route runs vertically up the centre** the whole height — a road, a rail line, a cable
>   run, a dry channel. It never leaves the middle third and never branches off-panel.
> - The **centre column (35–65% of the width) stays visually calm**: the route and simple ground
>   only. No large structures, no bright shapes, no high-contrast detail there — a dashed line,
>   circular markers and wide info cards are composited over it.
> - **Landmarks and detail live in the left and right margins** (outer 25% each side), and in
>   horizontal bands so they read between the cards.
> - **Overall value is mid-to-dark and desaturated.** Bright cyan and amber UI is drawn on top
>   and must win. No bright skies, no saturated greens, no strong white.
> - **No characters, no creatures, no vehicles, no people.** No text, numbers, icons, logos or
>   watermarks. No UI, frames, borders or vignettes. No path markers or map pins — those are
>   drawn by the game.
> - Edge to edge: no margins, no letterboxing, the art bleeds off all four sides.
>
> Region:

### The four regions, bottom to top

| Panel | Stages | Region |
|---|---|---|
| **1** (bottom, where the player starts) | Scrapyard Verge, Rusted Gantry, Coolant Run, Fabrication Floor | **Scrap flats.** Low, open ground of compacted debris and dry scrub; a shallow coolant stream crossing; collapsed sheds and a dead crane in the margins. Rust, ochre, dust-green. Flat overcast light. |
| **2** | The Stack, Signal Yard, Broken Relay, Cold Storage | **Signal belt.** The ground rises into terraces; fields of antenna masts and dish arrays in the margins, cable trenches, frost creeping in at the top edge. Grey-green cooling to pale blue. |
| **3** | Deep Fabrication, The Foreman, The Overcircuit, Molten Yard | **The foundry.** Heavy industry cut into the slope; furnace mouths and casting yards glowing faint orange in the margins; smoke drifting across. Dark iron and ash with orange embers. |
| **4** (top, the summit) | Signal Apex, The Reclamation, The Core Foreman | **The apex.** Above the cloud deck; bare black rock and a monumental dormant core structure filling the upper margins; thin cold light. Near-monochrome, deep cyan on black. |

### Delivering the files

`assets/art/map/map_panel_1.png` … `map_panel_4.png`, PNG, 1080×1920, panel 1 at the bottom.

---

## Not built yet

The map screen today is a plain scrolling `VBoxContainer` of full-width buttons — no timeline,
no nodes, no bottom overlay, and it lists stages top-down rather than bottom-up. The backdrop
is the art half; the screen in the reference image is a separate build:

1. Reverse the order so stage 1 sits at the bottom.
2. Replace the card column with a centre line plus circular nodes and cards alternating sides.
3. Scroll so the next unplayed stage lands mid-screen on entry.
4. Tap a card → bottom overlay with level range, mode, first-clear reward, and DEPLOY SQUAD.
5. Four stacked panels behind it, scrolling with the timeline.

Worth doing after the first panel exists, so each piece can be checked against real art.
