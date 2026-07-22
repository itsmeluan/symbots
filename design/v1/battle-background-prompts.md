# Battle background art — spec and prompts

Fifteen battlefields, one per stage. These are **backdrops**, not illustrations: four Symbot
sprites stand in a vertical line on each side, and the art has to hold them.

## Why the current one fails

`battle_arena_background.png` puts its horizon at ~50% of the image height. The battle layout
needs feet planted as high as 32%, so the two rear units float in open sky and over water. The
floor is the whole job — the scenery is decoration.

## Geometry every image must obey

Measured from the live layout (viewport 360×640, arena band y=116–508):

| What | Where, as a fraction of image height |
|---|---|
| Round banner (keep clear) | top 0–7% |
| **Horizon — no lower than this** | **30%** |
| Rear rank's feet | 32% |
| Front rank's feet | 79% |
| **Continuous, unobstructed floor** | **32% → 82%** |
| Action bar covers this (keep simple, darker) | 80–100% |

Horizontally: figures stand in two lanes, **left centred at x=24%, right at x=76%**, each lane
**30% of the width** (x 9–39% and 61–91%). Those two lanes carry four creatures each and must
stay visually calm.

---

## THE PROMPT

Paste this block, then append one scene line from the list below.

> Portrait digital painting, 1080×1920 (9:16), for use as a **battle backdrop in a 2D
> turn-based mobile game**. Semi-realistic industrial sci-fi, painterly, slightly desaturated.
>
> **Composition is the priority — follow it exactly:**
>
> - The **horizon sits 30% down from the top**. Everything below it is a continuous, walkable
>   **ground plane in strong one-point perspective**, receding to a vanishing point at the
>   horizon's centre. Floor seams, panel joints and edge lines converge toward that point.
> - The ground plane must be **unbroken and unobstructed from 32% to 82% of the image height**.
>   No walls, pits, water, railings, crates or machinery interrupting it in that range.
> - Two **standing lanes** must stay visually calm and evenly lit: one centred at **24% of the
>   width**, one at **76%**, each about **30% of the width** across. Flat readable ground only —
>   no busy props, no high-contrast detail, no strong cast shadows in those two lanes.
> - A **vertical dividing feature runs down the centre** at 50% width — a floor seam, a drainage
>   channel, a strip of different material, a line of embedded lights. Subtle, not a wall. It
>   separates the two sides without blocking sightlines.
> - The **top 7%** is empty sky or haze. The **bottom 18%** is plain darker floor.
> - Upper third (above the horizon): the scenery that gives the place its identity — structures,
>   sky, distant silhouettes. Detail lives HERE, not on the floor.
>
> **Values and colour:** overall mid-to-dark and desaturated. Bright saturated pixel-art
> creatures will be composited on top of the two lanes and must pop against them. Avoid bright
> floors, avoid busy texture, avoid strong colour in the lanes.
>
> **Must not contain:** any character, robot, creature, person or animal; text, numbers, logos,
> watermarks; UI, frames, borders, vignettes; foreground objects in front of the camera.
>
> Scene:

### The fifteen scenes

Append one of these to the prompt above.

1. **Scrapyard Verge** — an open yard of compacted scrap metal underfoot; towers of crushed
   machinery and a dead crane on the skyline; overcast dusk, rust and ochre.
2. **Rusted Gantry** — a wide steel gantry deck, plates streaked with rust; a lattice of
   collapsed catwalks above the horizon; sodium-orange light, deep shadows.
3. **Coolant Run** — a poured concrete channel floor, dry; enormous coolant pipes crossing the
   sky behind; pale cyan mist, cold blue-grey.
4. **Fabrication Floor** — polished factory floor with painted lane markings; idle assembly
   arms and conveyor lines along the back wall; sterile white-green worklight.
5. **The Stack** — the flat top of a vast stacked structure; lower tiers falling away beyond
   the horizon; wind-blown haze, high altitude, cool grey-violet.
6. **Signal Yard** — packed gravel and cable trenches; a forest of antenna masts and dishes on
   the skyline; overcast, muted green-grey.
7. **Broken Relay** — a cracked ceramic platform; a toppled relay tower and torn cabling behind;
   sparking blue arcs in the distance, storm light.
8. **Cold Storage** — frosted metal decking with ice creeping in from the edges; racked frozen
   containers receding into fog; near-monochrome pale blue.
9. **Deep Fabrication** — a subterranean machine hall floor, oil-stained; vast dormant machinery
   climbing out of view behind; amber emergency lighting, heavy dark.
10. **The Foreman** — a raised inspection platform, heavy steel grating; a supervisory bank of
    dead screens and a throne-like control rig behind; hard red key light.
11. **The Overcircuit** — a floor of exposed circuit tracery glowing faintly; a colossal
    branching circuit structure filling the sky behind; electric violet on near-black.
12. **Molten Yard** — dark basalt casting floor with cooling channels of orange glow at the
    edges; foundry ladles and furnace mouths behind; hot orange rim light, smoke.
13. **Signal Apex** — a windswept platform at the top of a transmission spire; cloud deck below
    the horizon, dish arrays behind; cold dawn, thin pale gold.
14. **The Reclamation** — a cracked concrete pad reclaimed by dead grey vegetation; half-buried
    machinery and a collapsed dome behind; ashen overcast, desaturated green.
15. **The Core Foreman** — a black mirrored floor with concentric inlaid rings; an immense
    dormant core chamber behind, ribbed and cathedral-like; deep cyan on black, single hard key.

---

## Delivering the files

Save as `assets/art/battle/bg_stage_01.png` … `bg_stage_15.png` (PNG, 1080×1920).

**Not yet wired.** `StageDef` has no background field — every stage currently loads the one
shared `battle_arena_background.png`. Adding the field and the per-stage lookup is a small
code change, worth doing once the first images exist so they can be checked in place.

If fifteen is too many to generate at once, scenes 1–4 cover the early stages and are the ones
the player sees first.
