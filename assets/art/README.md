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
> corners, NEVER rounded**, and break pips are **rectilinear, never circles**. The current
> placeholder theme uses rounded corners — when real chrome arrives, the StyleBoxTexture
> carries the chamfer and the `corner_radius` fields become irrelevant.

---

## 4. The sprite-swap recipe (content → nodes)

For things that are *content*, not chrome (player token, enemy markers, part icons), the
placeholder is a `ColorRect` generated in code. Swap path:

- **Player token** — `src/scenes/overworld_screen.tscn` node `%Token` is a `ColorRect`.
  Replace it with a `Sprite2D`/`TextureRect` (keep the `Token` name + `unique_name_in_owner`)
  and set the texture to `characters/…png`. `overworld_screen.gd` only sets its `.position`,
  which both node types support — no code change needed.
- **Enemy markers** — generated in `overworld_screen.gd::_spawn_enemy_markers()` as
  `ColorRect`s. Change the factory to make a `TextureRect` and load
  `"res://assets/art/enemies/%s.png" % e.id`; fall back to the ColorRect when the file is
  absent so the map never breaks mid-migration.
- **Part icons** — Workshop rows are text today. Add a `TextureRect` to each candidate/slot
  button pointing at `parts/<id>.png` by the naming convention in §1.

Keep the convention `res://assets/art/<category>/<id>.png` and code can resolve art from an
entity id without a manifest.

---

## 5. Checklist when adding art

- [ ] PNG saved under the right `assets/art/<category>/` with the convention name.
- [ ] `godot --import` run (or editor focused) → `.import` sidecar generated.
- [ ] Both PNG **and** `.import` committed.
- [ ] Pointed a node/Theme stylebox at it (§3 or §4).
- [ ] Verified crisp at 1× and zoomed (nearest filter — should never blur).
- [ ] For iOS: mind the 512 MB memory ceiling — keep source PNGs at native pixel size,
      let the engine scale up; do not ship 4K sprites for 64px art.
