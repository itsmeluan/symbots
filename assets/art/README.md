# Symbots — Art / Sprite Pipeline

How pixel-art PNGs from Pixel Lab become in-game visuals. The project is pre-configured
for crisp pixel art, so **dropping a PNG into the right folder is 90% of the work** — the
last 10% is pointing a node or the Theme at it.

> Prompts to generate every asset live in **[`../../art-prompts/`](../../art-prompts/)**.
> The filename each prompt targets is written at the top of its `.txt`. Save the Pixel Lab
> export under that name, in the matching folder below.

---

## 1. Where each asset goes

| Folder | Contents | Consumed as |
|--------|----------|-------------|
| `hud/` | Battle/overworld HUD frames, bars, meters | Theme StyleBox **or** TextureRect |
| `ui/` | Button faces, panel frames, dividers, generic chrome | Theme StyleBoxTexture (§3) |
| `buttons` → `ui/` | (buttons live in `ui/`) | Theme `Button` styleboxes |
| `characters/` | Player Mechanic avatar / token | `Sprite2D` / `TextureRect` |
| `enemies/` | Enemy sprites + overworld markers | `Sprite2D` / `TextureRect` |
| `parts/` | Per-part icons (one PNG per `.tres` in `assets/data/parts/`) | `TextureRect` in Workshop rows |
| `consumables/` | Consumable item icons | `TextureRect` |
| `overworld/` | Map tiles, terrain, background | `Sprite2D` / `TileMap` / `TextureRect` |
| `icons/` | Slot icons, element glyphs, rarity pips, status icons | `TextureRect` |
| `workshop/` | Bench backdrop, slot frames | Theme StyleBox / `TextureRect` |

Naming: `snake_case` matching the source `.tres` where one exists
(`ironclad_bulwark_frame.tres` → `parts/ironclad_bulwark_frame.png`). This lets code
resolve an icon from a part id by convention (`"res://assets/art/parts/%s.png" % id`).

---

## 2. Import — already handled

`project.godot` sets these **project-wide**, so no per-file fiddling:

- `rendering/textures/canvas_textures/default_texture_filter = 0` → **Nearest** filtering.
  Pixel art stays crisp at any zoom; no blur.
- `[importer_defaults] texture` → `compress/mode = 0` (Lossless), `mipmaps/generate = false`,
  `detect_3d/compress_to = 0`. Stops Godot from VRAM-compressing or mip-blurring sprites.

Drop a PNG in and Godot auto-imports it on focus (or run
`godot --headless --path . --import`). A `.import` sidecar appears next to each PNG —
**commit both the PNG and its `.import`**.

For a texture that must **9-slice** (stretchable button/panel border that shouldn't
distort corners), after import select it and there is nothing to change here — 9-slice is
configured on the **StyleBoxTexture**, not the import (see §3).

---

## 3. The sprite-swap recipe (UI chrome → Theme)

All screen styling flows through **one** file: `assets/ui/theme/symbots_theme.tres`.
Today it uses flat colors (`StyleBoxFlat`). To skin a widget with art, swap that for a
`StyleBoxTexture` — **every widget of that type updates at once**, no screen edits.

Example — give every `Button` a pixel-art face:

1. Import `ui/button_normal.png` (drop it in `assets/art/ui/`).
2. Open `symbots_theme.tres` in the editor → find the `Button/styles/normal` StyleBox.
3. Change its type `StyleBoxFlat` → `StyleBoxTexture`; set `texture` to `button_normal.png`.
4. Set **Texture Margins** (L/T/R/B) to the border thickness in px → 9-slice so corners
   stay crisp while the middle stretches.
5. Repeat for `hover` / `pressed` / `disabled` (or reuse one with a modulate).

The Theme's **type variations** (`PrimaryButton`, `TargetButton`, `EnemyBar`, …) each have
their own styleboxes — skin them independently the same way. Bars: swap
`ProgressBar/styles/fill` (and each `*Bar/styles/fill` variation) to a `StyleBoxTexture`.

> Art-bible reminder (`../../art-prompts/_style-guide.txt`): UI panels use **chamfered 45°
> corners, NEVER rounded**, and break pips are **rectilinear, never circles**. The theme's
> `corner_radius` fields are now all **0** — hard edges, which is the closest a
> `StyleBoxFlat` gets to the rule. The actual 45° chamfer needs real chrome art: when it
> arrives, the StyleBoxTexture carries the chamfer and `corner_radius` becomes irrelevant.

---

## 4. Swapping content sprites (player, enemies, parts)

**These are already wired.** Every one of them resolves through
`Art.texture(category, id)` (`src/ui/art.gd`) → `res://assets/art/<category>/<id>.png`.
So swapping art is **replace the file, keep the name** — no code edit, no scene edit.

### Player walk sprite

**File:** `characters/char_mechanic_walk.png`

Overwrite it and the mechanic changes on the next import. Two rules:

1. **It must be a 4×4 grid** of frames. *Any* pixel resolution works — 128×192, 256×384,
   512×768 — as long as width divides by 4 and height divides by 4. The frame size is
   measured from the texture, not hardcoded. An uneven sheet is refused with a
   `overworld_bad_walk_sheet` warning (naming the actual size) rather than silently
   slicing every frame at the wrong offset.
2. **Row order is the direction convention:**

   | Row | Direction | Used? |
   |-----|-----------|-------|
   | 0 | Facing the camera (down) | yes |
   | 1 | Three-quarter turn | **no** — free for anything |
   | 2 | Profile facing **right** | yes (mirrored for left) |
   | 3 | Facing away (up) | yes |

   Left is the right-facing row flipped horizontally, so do not draw a separate left row.

On-screen size is driven by `PLAYER_HEIGHT` in `overworld_screen.gd`, with width following
the sheet's own aspect — a taller or wider character still reads at a consistent height,
and the movement clamp measures the live sprite so it stays inside the world either way.

To use a different shipped variant instead of replacing the file, point `PLAYER_SPRITE`
(top of `overworld_screen.gd`) at it, e.g. `&"char_mechanic_fem_overworld_walk"`.

### Enemy sprites

**Files:** `enemies/<enemy_id>.png` — the id from `assets/data/enemies/*.tres`
(`rustcrawler.png`, `volt_sentinel.png`, …). One still image, no sheet.

Scaled to a fixed on-screen height with width following the source aspect, so a squat
crawler and a tall sentinel both read correctly. Crop transparent padding before saving —
scaling is driven by the image bounds, so a sprite floating in a large empty canvas renders
small.

### Part icons

**Files:** `parts/<part_id>.png` — the id from `assets/data/parts/*.tres`. They appear on
Workshop slot and candidate buttons automatically.

> **The filename must equal the content id.** Art-bible §8.4. A file named anything else
> is never loaded — this already cost the project 16 dead `part_*.png` files and 10
> unreachable `enemy_*_battle.png` files.

---

## 5. Checklist when adding art

- [ ] PNG saved under the right `assets/art/<category>/` with the convention name.
- [ ] `godot --import` run (or editor focused) → `.import` sidecar generated.
- [ ] Both PNG **and** `.import` committed.
- [ ] Pointed a node/Theme stylebox at it (§3 or §4).
- [ ] Verified crisp at 1× and zoomed (nearest filter — should never blur).
- [ ] For iOS: mind the 512 MB memory ceiling — keep source PNGs at native pixel size,
      let the engine scale up; do not ship 4K sprites for 64px art.
