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
awaiting user review) covering §1 medium declaration, §5.6/§8.3 LOD-to-integer-
scale rewrite, §6.3 texture philosophy, §9 reference-direction wording, and a
§7.3 hybrid typography split (functional geometric-sans for dense/accessibility/
PT-BR-accented text vs. an optional pixel display font for large sparse titles
only). None of it is written to the file yet — confirm current file state before
assuming any of these edits landed.
