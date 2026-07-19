# Symbots art delivery

This package implements every PNG target listed in `art-prompts/_index.txt` and adds complete screen mockups plus review sheets.

## Coverage

- 89 / 89 documented MVP target paths exist.
- 11 screen-state mockups at 1024×600.
- 4 full-screen environment backdrops: main menu, overworld, workshop, and battle arena.
- 10 isolated battle enemies at 256×256, including Rust Tyrant and Storm Warden.
- 16 isolated modular Symbot parts at 256×256. The `part_*` files are the documented canonical paths; the shorter filenames are preserved as convenient aliases.
- 6 gender variants for the mechanic plus 3 default aliases. Walk sheets use a 4×4 grid at 256×384; workshop and battle poses are 256×256.
- 8 consumable icons at 64×64.
- 27 slot, element, rarity, and stat icons.
- 12 button textures covering generic, primary, and target-selector states.
- 7 battle HUD assets, 6 reusable panel/scroll assets, 3 workshop assets, and 6 overworld assets.

## Screen mockups

The `mockups/` folder contains:

- `main-menu-returning.png`
- `main-menu-first-launch.png`
- `main-menu-overwrite-confirm.png`
- `overworld.png`
- `world-map.png`
- `battle-active.png`
- `battle-salvage.png`
- `workshop-default.png`
- `workshop-selected.png`
- `pause.png`
- `settings.png`

Review-only sheets are prefixed with `_` and must not be imported as game assets:

- `_all-screens-contact-sheet.jpg`
- `_ui-kit-overview.jpg`
- `_sprite-catalog.jpg`

## Pixel Lab workflow

Use each standalone transparent PNG as its own Image to Pixel Art input. Do not upload the review sheets as source art. Preserve the canvas dimensions and use nearest-neighbor output when scaling pixel conversions.

For modular parts, keep the transparent canvas unchanged so the centered sockets and connection geometry remain aligned. Convert related parts with the same pixel scale, palette budget, outline settings, and lighting direction.

## Rebuild tools

- `tools/render_art_ui.py` rebuilds buttons, panels, HUD, utility tiles, and icons.
- `tools/render_consumables.py` rebuilds consumable icons.
- `tools/prepare_character_assets.py` rebuilds character sheets from high-resolution sources.
- `tools/render_screen_mockups.py` rebuilds all screen states and the screen contact sheet.
- `tools/render_asset_catalog.py` rebuilds the two review catalogs.

High-resolution generated sources and transparency-processed versions are preserved under `generated-v1/source/` and `generated-v1/final/`.
