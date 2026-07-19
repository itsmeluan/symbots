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

### Player sprites — 8 directions, idle + walk

**Generated files:** `characters/char_mechanic_walk.png` and `char_mechanic_idle.png`.
**Do not hand-edit them** — they are built from a folder of per-direction GIFs, because
Godot has no GIF importer.

To swap the character, point the tool at a new delivery folder and re-run it:

```
python3 tools/build_character_spritesheets.py ~/Downloads/char-sprites
```

The folder must contain `char-idle/` and `char-walking/`, each with one GIF (or still
PNG) per direction. Filenames are matched loosely — case, spaces, hyphens and underscores
are ignored — so `idle- north.gif` and `idle_North.GIF` both work. Idle and walk may have
different frame counts.

**Sheet contract:** 8 rows (one per direction), N columns (one per frame), **square
frames**. Square is what makes the sheet self-describing: frame side = height / 8, so
column count = width / that. Nothing in the game code needs to be told the frame count.
A sheet that violates this is refused with an `overworld_bad_walk_sheet` warning naming
the actual size, rather than silently slicing every frame at a wrong offset.

**Row order is SCREEN direction, clockwise from right:**

| Row | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| Heading | → | ↘ | ↓ | ↙ | ← | ↖ | ↑ | ↗ |

which is `round(atan2(dy, dx) / 45°)` with +x right and +y down.

> **The delivered art labels east/west mirrored relative to screen space** — the file
> named `east` draws the character facing screen-*left*. The tool's `DIRECTIONS` list owns
> that translation so it lives in one documented place. **If a new delivery uses a
> different convention, re-check it**: build the sheet, then look at row 0 and confirm the
> character is oriented rightward.

On-screen size is `PLAYER_SCALE` in `overworld_screen.gd` — **integer only**. A fractional
scale gives pixel art uneven pixel widths and shimmer on movement, which is exactly what
the project's nearest filter and integer stretch mode exist to prevent. The movement clamp
measures the live sprite, so a taller or wider character still stays inside the world.

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
