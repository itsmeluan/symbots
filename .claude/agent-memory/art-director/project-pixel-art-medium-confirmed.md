---
name: project-pixel-art-medium-confirmed
description: User confirmed 2026-07-19 the game's rendering medium is pixel art, closing the fork game-concept.md left open; art-bible.md v0.2 predates this and needs reconciliation (proposal drafted, not yet approved)
metadata:
  type: project
---

**Decision**: Luan confirmed 2026-07-19 ("o jogo será em pixel art") that Symbots
is a pixel-art game. `design/gdd/game-concept.md` § Visual Identity Anchor had
left this as an open fork ("Art Style: Stylized 2D — pixel art or clean vector
sprites"); this closes it in favor of pixel art.

**Why**: `art-bible.md` v0.2 (approved 2026-07-17, before this confirmation)
describes the medium as painted/matte 2D (§6.3 "Texture Philosophy — Matte
Painted, Not PBR"; §9 Horizon row "matte 2D") and never uses the words "pixel
art" anywhere. Meanwhile `project.godot` already commits to pixel-art-only
render settings (`mipmaps/generate=false`, `default_texture_filter=0` nearest),
`assets/art/README.md` / `production/art-sources/parts-v1/README.md` already
describe a Pixel Lab AI-conversion pipeline, and `art-prompts/_style-guide.txt`
already opens with "Pixel art, stylized flat 2D." The bible text is what lagged
— the pipeline and engine config were already pixel-art-committed.

**Concrete conflict found**: art-bible.md §8.3 specifies combat LOD (~64×64px)
"resolves from the authored [256×256] asset via the atlas **mip chain**" — this
is a smooth-texture-mipmapping model, incompatible with `mipmaps/generate=false`
+ nearest filtering. A 256px source point-sampled down to 64px with no mip chain
will alias/shimmer. This needs replacing with a native-pixel-grid + integer-scale
model (see [[project-symbots-visual-state]] for what else exists).

**Verified while drafting the reconciliation proposal (2026-07-19, not yet
approved by user)**:
- The 16 shipped PNGs in `assets/art/parts/` (e.g. `ironclad_bulwark_frame.png`)
  are confirmed-by-visual-inspection **smooth-shaded placeholder renders**, NOT
  genuine pixel art — this matches `production/art-sources/parts-v1/README.md`'s
  own note that these are pre-PixelLab-conversion placeholders awaiting the real
  pixel-art pass. **Nothing shippable is invalidated by the pixel-art
  reconciliation** — the pipeline already expected this step.
- `art-prompts/_style-guide.txt` and all 89 per-asset `art-prompts/*.txt` files
  already inherit "Pixel art, stylized flat 2D" via the shared preamble —
  **no rework needed there**.
- `project.godot` has **no `[display]`/stretch-mode section at all** — pixel-
  perfect integer scaling needs one added (flag to godot-specialist /
  technical-artist, not an art-bible-only fix).
- Exact native pixel grid size (32×32? 64×64? other?) for parts is an **open
  production question**, not yet decided — art-prompts currently request a flat
  256×256 canvas from Pixel Lab with no stated native-grid/block-size, so it's
  unverified whether that 256px canvas is genuinely fine-grained pixel art or a
  blown-up low-res grid. Needs a resolution spike before locking §8.3.

**How to apply**: Do not treat art-bible.md's "matte painted" language as current
truth in future sessions — a reconciliation proposal exists (drafted 2026-07-19,
revised 2026-07-19 after user decisions, awaiting final write) covering §1
medium declaration, §5.6/§8.3 LOD-to-integer-scale rewrite, §6.3 texture
philosophy, §9 reference-direction wording, and §7.3 typography. None of it is
written to the file yet — confirm current file state before assuming any of
these edits landed.

**Round-2 decisions (2026-07-19, same day, via coordinator)**:
- **OQ#2 (authoring model) — RESOLVED**: single native asset + integer
  upscale (not two separately-authored LOD tiers). Confirmed, no change to
  the §8.3 structural approach drafted in round 1.
- **OQ#3 (PT-BR coverage) — RESOLVED, downgraded**: the game ships in
  English; PT-BR is the user's own working/dev language only. Accented-glyph
  coverage (ã õ ç á é í ó ú â ê ô) is **advisory**, not a blocking font-
  selection criterion, wherever it's mentioned (§7.3, battle-visual-design
  §6.5). Do not delete the consideration — just don't gate on it.
- **OQ#4 (pixel display font for titles) — RESOLVED, rejected**: **one
  typeface only** — a vector geometric sans-serif, everywhere, titles
  included. The round-1 draft's Type 1 / Type 2 split is dead; §7.3 was
  rewritten single-typeface, leading with *why* a pixel-art game still uses a
  vector font for text (iOS integer-step bitmap-font problem, accessibility
  large-text-toggle continuous-scaling requirement, dense-numeral
  disambiguation). The forward-looking "conditions under which this could be
  revisited" analysis was preserved rather than deleted.
- **OQ#1 (native pixel grid size) — still OPEN.** Recommendation stands:
  write §8.3's structural fix now (native-grid + integer-scale model, no mip
  chain) with the actual pixel count as an explicit `TODO(native-grid)`
  placeholder token, rather than blocking the whole reconciliation on the
  number. A resolution spike (render one existing part at 2-3 candidate
  grids, e.g. 32/48/64px, pick by the existing §3.1 greyscale test) is the
  recommended way to close it.
- **OQ#5 (`game-concept.md` line 249)** — diff drafted ("pixel art or clean
  vector sprites" → "Pixel art."), explicitly flagged as **cross-domain**
  (file is in `design/gdd/`, not `design/art/`) per `coordination-rules.md`
  Rule 5 — art-director does not edit GDD files even with user approval of
  the content; routes through the coordinator/game-designer.
- **`project.godot` `[display]`/stretch-mode gap** — confirmed out of
  art-director's domain. Ownership stated explicitly in the revised §8.3
  text: `godot-specialist` owns the engine-configuration change; `technical-
  artist` is consulted on the integer scale factor once the native grid (the
  still-open OQ#1) is set. Art-bible states the requirement/constraint only.
