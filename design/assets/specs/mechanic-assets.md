# Asset Specs — Character: The Mechanic (Player Avatar)

> **Source**: `design/art/art-bible.md` §5.1–5.2 (character direction), `design/assets/entity-inventory.md` #1
> **Art Bible**: `design/art/art-bible.md` (§3.5 figure/ground, §4.1 world palette, §4.6/§2.6 Workshop light, §2.1 overworld light, §8 asset standards)
> **Generated**: 2026-07-17
> **Review mode**: solo (no `technical-artist` spawn — disabled for this project per durable no-subagent constraint; technical fields validated **inline** by the main session, see Technical Validation note below)
> **Status**: 3 assets specced / 0 approved / 0 in production / 0 done

> **Technical Validation (inline, 2026-07-17).** A formal `technical-artist` agent was not
> spawned (subagents disabled for this project). The main session ran the technical pass
> against `.claude/docs/technical-preferences.md` (Godot 4.7, 2D CanvasItem, 200 draw calls,
> 512 MB, 60 fps) and art-bible §8:
> - **Memory**: full Mechanic set ≈1.5 MB uncompressed (0.5 MB overworld + ~1 MB close-camera) — negligible vs. the 512 MB ceiling.
> - **Draw calls**: the mechanic renders one sprite at a time (overworld / Workshop / intro) — never in the 200-call combat composite. 1 draw call each.
> - **Refinements applied**: overworld cell → 64×96 portrait (square under-resolves a humanoid); palette recolor → ONE shared palette-swap `ShaderMaterial` + flat indexed color regions (honors §8.2 shared-shader / no-per-instance-material rule).
> - **Open flags**: (1) the `char_` naming prefix extends §8.4 (which only defines `part_`/`icon_`) and needs ratification on the next art-bible touch; (2) confirm the 64×96 / 256×256 tiers and character-atlas assignment with the UI programmer at implementation.

---

## ASSET-001 — Mechanic: Overworld Walk Cycle

| Field | Value |
|-------|-------|
| Category | Sprite (character) |
| Dimensions | **64×96px per frame** (portrait) · 4 directions (down/up/left/right) × 4-frame walk = 16 frames/variant · sprite sheet |
| Variants | 2 (masculine / feminine), matched silhouette footprint |
| Palette | Runtime recolor via ONE shared palette-swap `ShaderMaterial`; author with **flat indexed color regions** — **not** baked per palette |
| Format | PNG (lossless, alpha) → Godot `.import` |
| Naming | `char_mechanic_[masc\|fem]_overworld_walk.png` (single sheet) ⚠ new `char_` prefix — extends §8.4, needs ratification |
| Texture Res | Authored 64×96/frame; map zoom-out via mip chain (§8.3) |

**Visual Description:**
A human field-engineer seen Pokémon-style in the overworld — reads as *a person who builds machines*: practical layered work clothing, a tool/satchel silhouette cue, no weapons or armor. Read priority is **facing direction** and **human-not-bot**: clean low-frequency silhouette, matte, lower saturation than any Symbot in frame. Masc/fem variants differ only in body/hair silhouette, sharing footprint so map framing is identical for both.

**Art Bible Anchors:**
- §5.2 — engineer/field-mechanic archetype; 4-directional walk; readable at map zoom; detail spent on walk-cycle silhouette over facial detail.
- §3.5 / §4.1 — world palette (W-1…W-7), **lower saturation & lower frequency than Symbots** (figure/ground: a human among machines is quieter than the machines).
- §2.1 — overworld lighting: warm key upper-right, high ambient lift so the sprite never sinks into terrain shadow.
- §8.2 / §8.3 — shared palette-swap shader (no per-instance material); mip chain for zoom LOD.

**Generation Prompt:**
*Top-down 2.5D game character sprite, human field mechanic/engineer, practical layered work-clothes with a tool pouch, walking pose, 4-directional walk-cycle sheet, colorful stylized flat 2D, matte finish, clean readable silhouette, muted warm earthy palette, flat indexed color regions, mobile pixel-clean at small scale, character-forward but understated. Negative: photoreal, 3D render, PBR, high-saturation neon, weapons, armor, soldier gear, HUD elements, baked drop shadow, painterly gradients.*

**Status:** Needed

---

## ASSET-002 — Mechanic: Oficina (Workshop) Bench Idle

| Field | Value |
|-------|-------|
| Category | Sprite (character) |
| Dimensions | 256×256px · single static pose (+ optional 2-frame breathing idle) |
| Variants | 2 (masc / fem) |
| Palette | Same shared palette-swap shader as ASSET-001; flat indexed regions |
| Format | PNG (lossless, alpha) → `.import` |
| Naming | `char_mechanic_[masc\|fem]_workshop_idle.png` |
| Texture Res | Authored 256×256 (close-camera framing, §8.3 Workshop authoring tier) |

**Visual Description:**
The mechanic at the workbench, mid-assembly — a warm, unhurried "laboratory" pose reinforcing the engineer fantasy on a core screen. Closer camera than overworld, so facial and clothing-color detail now reads. Calm, focused body language; the Symbot-in-progress is composited separately and is **not** part of this asset. Warm, even bench-lamp lighting, no dramatic shadow.

**Art Bible Anchors:**
- §5.2 — Oficina bench idle; facial/clothing detail matters most here (close camera).
- §2.6 / §4.6 — Workshop mood: neutral-to-warm bench light, high ambient, low shadow, zero urgency ("the workshop as a laboratory").
- §3.5 / §4.1 — world palette, still quieter than the bot beside them.

**Generation Prompt:**
*Stylized flat 2D game character, human mechanic seated/standing at a workbench, mid-assembly idle pose, warm even indoor bench-lamp lighting, colorful matte shading, flat indexed color regions, practical engineer clothing, calm focused expression, mobile game art, character portrait-scale detail. Negative: photoreal, PBR, harsh shadows, dramatic rim light, weapons, neon saturation, visible robot parts, UI chrome, painterly gradients.*

> **Reuse (Shared Asset Protocol):** the character-creation preview and any "return to Workshop" framing should **reuse ASSET-002** rather than commission a new pose (recorded in the manifest referenced-by column).

**Status:** Needed

---

## ASSET-003 — Mechanic: Battle-Intro Cameo

| Field | Value |
|-------|-------|
| Category | Sprite (character) |
| Dimensions | 256×256px · single cameo pose (+ optional short entrance frames) |
| Variants | 2 (masc / fem) |
| Palette | Same shared palette-swap shader; flat indexed regions |
| Format | PNG (lossless, alpha) → `.import` |
| Naming | `char_mechanic_[masc\|fem]_battle_intro.png` |
| Texture Res | Authored 256×256 (close-camera cameo) |

**Visual Description:**
A brief trainer-style entrance at the start of a fight — a confident "here we go" cameo pose, after which the mechanic yields the frame to the Symbot that actually fights. No health bar, no targetable body: this is identity, not combat. Momentary higher-energy pose than the Workshop idle, but still world-palette and still quieter than the bot.

**Art Bible Anchors:**
- §5.2 — battle-intro cameo; mechanic then yields the frame; never a combat entity (no HP/stats/targeting).
- §2.2 — combat lighting is high-contrast, but the mechanic is a pre-combat beat; the bot, not the human, becomes the lit subject once the fight starts.
- §3.5 / §4.1 — world palette, understated vs. the Symbot.

**Generation Prompt:**
*Stylized flat 2D game character, human mechanic in a confident entrance/ready pose, trainer-style battle intro cameo, colorful matte shading, flat indexed color regions, warm-to-neutral lighting, practical engineer clothing, dynamic but grounded stance, mobile game art. Negative: photoreal, PBR, weapons drawn, combat armor, health bar, targeting reticle, neon saturation, background bot, painterly gradients.*

**Status:** Needed

---

## Notes for downstream

- **Naming ratification**: fold a `char_[entity]_[variant]_[context]` convention into art-bible §8.4 (currently only `part_`/`icon_` are defined).
- **Palette authoring contract** (all 3): author with flat, palette-swap-friendly indexed color regions so the single shared recolor shader works — free-painted gradients break the swap.
- **Not specced here** (out of Mechanic scope): the character-creation *screen* UI (that's a `/ux-design` job — screen #28-adjacent), and the Symbot build composited beside the mechanic in ASSET-002 (that's entity #2, a separate spec).
