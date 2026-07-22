# Battle background art — spec and handoff prompt

Fifteen battlefields, one per stage. These are **backdrops**, not illustrations: four Symbot
sprites stand in a vertical line on each side, and the art has to hold them.

## Attempt 1 failed on style, not geometry

The first set (generated 2026-07-21) is in the repo and works structurally — the floor is where
it needs to be and the units stand on it. It was rejected because it does not look like the
game: the prompt asked for *"semi-realistic painterly industrial sci-fi, muted and desaturated,
low contrast"*, which is the opposite of the sprites in every respect.

| Attempt 1 asked for | The game actually is |
|---|---|
| painterly semi-realism | **cel-shaded TV anime** |
| muted, desaturated | **saturated, full colour** |
| low contrast | high contrast, clear light |
| soft edges | **defined outlines** |
| realistic detail | simplified, flat-shaded shapes |

The geometry section below is **kept unchanged** — it was verified against the running game.
Only the style vocabulary is replaced.

## Geometry — do not change this

Derived from the live layout: viewport 360×640, arena band y=116–508.

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

# HANDOFF PROMPT

Paste everything below into a Claude session connected to this repo.

---

You are generating replacement battlefield backdrops for **Symbots**, a portrait mobile
turn-based squad battler built in Godot. The repo is connected — read from it before you start.

## First, look at what the art has to match

Open three or four sprites from `assets/art/symbots/` — for example `coilsprite_mk3.png`,
`ironmaul_mk1.png`, `solderfly_mk3.png`. **These define the target style.** Look at the outline
weight, the flat colour blocking, the saturation, the way volume is suggested with two or three
tones rather than a gradient.

Then open one existing backdrop, `assets/art/battle/bg_stage_01.png`. That is the style that was
rejected. Note how the painterly muted realism fights the sprites.

## The style you are aiming for

**Mid-90s mecha TV anime — Medabots, Digimon, Zoids.** Specifically:

- **Cel shading.** Two or three flat tones per surface, hard-edged transitions. No soft gradients,
  no airbrushing, no photographic texture.
- **Defined outlines** on structures and silhouettes — darker than the fill, not pure black.
- **Saturated colour.** Confident teals, oranges, warm greys. Colour identity per location.
- **Simplified, chunky shapes.** Readable at thumbnail size. Detail comes from silhouette and
  colour blocking, not from surface noise.
- **Clear directional light** with a stated time of day. Skies can be dramatic — big flat cloud
  shapes, gradient bands, a low sun.
- Illustrated background art for a game, not concept art and not a photo.

It should look like a frame from the anime the sprites came out of.

## The composition rules — these are load-bearing

Every image is **1080×1920 PNG (9:16 portrait)** and must satisfy:

- The **horizon sits 30% down from the top**. Everything below it is a continuous **walkable
  ground plane in one-point perspective**, receding to a vanishing point at the horizon's centre.
  Floor seams and edge lines converge toward that point.
- The ground plane is **unbroken and unobstructed from 32% to 82% of the image height**. No
  walls, pits, water, railings, crates or machinery interrupting it in that range.
- Two **standing lanes** stay visually calm and evenly lit: one centred at **24% of the width**,
  one at **76%**, each about **30% of the width** across. Flat readable ground only — no busy
  props, no high-contrast detail, no cast shadows in those two lanes.
- A **vertical dividing feature runs down the centre** at 50% width — a floor seam, a channel, a
  strip of different material, a line of embedded lights. Subtle, not a wall.
- The **top 7%** is empty sky. The **bottom 18%** is plain darker floor.
- Detail and landmarks live **above the horizon** and in the outer margins — not on the floor.
- **Bright saturated sprites are composited on the two lanes.** Keep the floor a mid value so
  they read: not black, not white, not busier than they are.

**Must not contain:** any character, robot, creature, person or animal; text, numbers, logos or
watermarks; UI, frames, borders or vignettes; foreground objects in front of the camera.

## Which scene goes in which file — read this carefully

**Do not assume `stage_07.tres` uses `bg_stage_07.png`.** It does not. The bindings were made by
place, and two pairs are crossed.

For each `assets/data/stages/stage_NN.tres`:

1. Read its `display_name` and its `background_path`.
2. Generate the scene for **that display_name**, from the table below.
3. Save it to **exactly that `background_path`**, overwriting the existing file.

Do not edit any `.tres`. The bindings are correct; only the pixels are being replaced.

| Stage name | Scene |
|---|---|
| Scrapyard Verge | Open yard of compacted scrap; crushed-machinery towers and a dead crane on the skyline. Rust, ochre, warm grey. Late afternoon, long light. |
| Rusted Gantry | Wide steel gantry deck, rust-streaked plates; a lattice of collapsed catwalks above the horizon. Sodium orange against deep blue shadow. |
| Coolant Run | Dry poured-concrete channel; enormous coolant pipes crossing the sky behind. Pale cyan mist, cold blue-grey, bright overcast. |
| Fabrication Floor | Polished factory floor with painted lane markings; idle assembly arms and conveyors along the back wall. Green-white worklight, clean and bright. |
| The Stack | Flat top of a vast stacked structure, lower tiers falling away past the horizon. High altitude, wind haze, cool violet-grey, big sky. |
| Signal Yard | Packed gravel and cable trenches; a forest of antenna masts and dishes on the skyline. Muted green-grey, flat overcast. |
| Broken Relay | Cracked ceramic platform; a toppled relay tower and torn cabling behind. Storm light, blue arcs sparking in the distance. |
| Cold Storage | Frosted metal decking, ice creeping in from the edges; racked frozen containers receding into fog. Near-monochrome pale blue. |
| Deep Fabrication | Subterranean machine hall, oil-stained floor; vast dormant machinery climbing out of frame behind. Amber emergency lighting, heavy shadow. |
| The Foreman | Raised inspection platform of heavy steel grating; a bank of dead screens and a throne-like control rig behind. Hard red key light. |
| The Overcircuit | Floor of exposed circuit tracery glowing faintly; a colossal branching circuit structure filling the sky. Electric violet on near-black. |
| Molten Yard | Dark basalt casting floor, cooling channels glowing orange at the edges; foundry ladles and furnace mouths behind. Hot orange rim light, smoke. |
| Signal Apex | Windswept platform atop a transmission spire; cloud deck below the horizon, dish arrays behind. Cold dawn, thin pale gold. |
| The Reclamation | Cracked concrete pad taken back by grey-green vegetation; half-buried machinery and a collapsed dome behind. Ashen overcast. |
| The Core Foreman | Black mirrored floor with concentric inlaid rings; an immense dormant core chamber behind, ribbed and cathedral-like. Deep cyan on black, one hard key light. |

## Generate ONE first

Do **Scrapyard Verge** alone and stop. Show it to the user next to `coilsprite_mk3.png` and ask
whether the style is right. Only continue to the other fourteen once they say yes — fifteen
images in the wrong style is the mistake this whole pass is correcting.

## When the images are in

Run these from the repo root and report the results:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --import .
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit
```

The suite is at **1421 tests, all passing**. Two of them (`test_every_shipped_stage_names_art_that_exists`
and `test_no_two_stages_share_a_battlefield`) check the art bindings and will catch a file saved
to the wrong path.

Do not lower `BattleScreen.BACKDROP_DIM` (currently 0.28) to compensate for art that is too dark
— fix the art instead. That constant was already tuned once for a backdrop set that is being
replaced.
