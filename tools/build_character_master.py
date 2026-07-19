#!/usr/bin/env python3
"""Build an aligned eight-direction pixel-art character master from a 4x2 keyed sheet."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "assets/art/characters/master-mechanic-male-v1/source/master_turnaround_keyed.png"
OUT = ROOT / "assets/art/characters/master-mechanic-male-v1"
FRAME = 128
SOURCE_CELL = (384, 512)
NATIVE_CELL = (96, 128)
PIVOT = (64, 118)
DIRECTIONS = ["south", "southwest", "west", "northwest", "north", "northeast", "east", "southeast"]


def chroma_alpha(im: Image.Image) -> Image.Image:
    """Remove the generated magenta using a strict hue-family mask."""
    src = im.convert("RGBA")
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, _ = px[x, y]
            # Generated background varies around vivid magenta. Costume reds and
            # ochres remain safe because they do not have a strong blue channel.
            keyed = (
                r > 70
                and b > 70
                and r > g * 1.35
                and b > g * 1.35
                and abs(r - b) < 120
            )
            px[x, y] = (r, g, b, 0 if keyed else 255)
    return src


def alpha_bbox(im: Image.Image):
    return im.getchannel("A").getbbox()


def normalize_cell(cell: Image.Image) -> Image.Image:
    # The generated 1536x1024 sheet is exactly four times the intended 96x128
    # cell resolution; nearest-neighbor reduction retains deliberate pixel blocks.
    small = cell.resize(NATIVE_CELL, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    canvas.alpha_composite(small, ((FRAME - NATIVE_CELL[0]) // 2, 0))
    bbox = alpha_bbox(canvas)
    if not bbox:
        raise ValueError("Direction cell contains no foreground pixels")
    # Lock the lowest opaque pixel to a common foot baseline. Keep the axis from
    # the original grid rather than recentering the silhouette around accessories.
    dy = PIVOT[1] - (bbox[3] - 1)
    aligned = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    aligned.alpha_composite(canvas, (0, dy))
    return aligned


def quantize_shared(frames: list[Image.Image], colors: int = 48) -> list[Image.Image]:
    strip = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.alpha_composite(frame, (i * FRAME, 0))
    quantized = strip.quantize(colors=colors, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGBA")
    # Keep hard binary alpha after palette reduction.
    quantized.putalpha(strip.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return [quantized.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME)) for i in range(len(frames))]


def checker(size, tile=8):
    bg = Image.new("RGBA", size, "#1D252E")
    d = ImageDraw.Draw(bg)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                d.rectangle((x, y, x + tile - 1, y + tile - 1), fill="#283441")
    return bg


def build(source_path: Path):
    source = Image.open(source_path).convert("RGBA")
    if source.size != (1536, 1024):
        raise ValueError(f"Expected 1536x1024 source, got {source.size}")
    keyed = chroma_alpha(source)
    raw = []
    for i in range(8):
        col, row = i % 4, i // 4
        x0, y0 = col * SOURCE_CELL[0], row * SOURCE_CELL[1]
        raw.append(normalize_cell(keyed.crop((x0, y0, x0 + SOURCE_CELL[0], y0 + SOURCE_CELL[1]))))
    # Image generation produced strong canonical diagonals but duplicated their
    # facing side. Derive the opposing diagonal from the same canonical view.
    # Mirroring the facing direction also maps the anatomical left-side tool
    # pouch to its correct screen side for the opposite direction.
    raw[3] = raw[5].transpose(Image.Transpose.FLIP_LEFT_RIGHT)  # northwest from northeast
    raw[7] = raw[1].transpose(Image.Transpose.FLIP_LEFT_RIGHT)  # southeast from southwest
    frames = quantize_shared(raw)

    directions_dir = OUT / "directions"
    directions_dir.mkdir(parents=True, exist_ok=True)
    for name, frame in zip(DIRECTIONS, frames):
        frame.save(directions_dir / f"mechanic_master_{name}.png", optimize=True)

    atlas = Image.new("RGBA", (FRAME * 8, FRAME), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        atlas.alpha_composite(frame, (i * FRAME, 0))
    atlas.save(OUT / "mechanic_master_8dir_atlas.png", optimize=True)

    grid = Image.new("RGBA", (FRAME * 4, FRAME * 2), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        grid.alpha_composite(frame, ((i % 4) * FRAME, (i // 4) * FRAME))
    grid.save(OUT / "mechanic_master_8dir_grid.png", optimize=True)

    label_h = 24
    review = checker((FRAME * 4, (FRAME + label_h) * 2))
    draw = ImageDraw.Draw(review)
    font_path = "/System/Library/Fonts/SFNSMono.ttf"
    review_font = ImageFont.truetype(font_path, 12)
    for i, (name, frame) in enumerate(zip(DIRECTIONS, frames)):
        x, y = (i % 4) * FRAME, (i // 4) * (FRAME + label_h)
        review.alpha_composite(frame, (x, y))
        draw.text((x + FRAME // 2, y + FRAME + 12), name.upper(), font=review_font, fill="#E8E8E8", anchor="mm")
    review.convert("RGB").save(OUT / "mechanic_master_8dir_review.png", optimize=True)
    review.resize((review.width * 2, review.height * 2), Image.Resampling.NEAREST).convert("RGB").save(
        OUT / "mechanic_master_8dir_review_2x.png", optimize=True
    )

    manifest = {
        "version": 1,
        "character": "main_mechanic_male",
        "source": str(source_path.relative_to(ROOT)),
        "frame_size": [FRAME, FRAME],
        "pivot": {"x": PIVOT[0], "y": PIVOT[1], "meaning": "shared foot baseline / animation origin"},
        "direction_order": DIRECTIONS,
        "atlas_layout": {"columns": 8, "rows": 1},
        "grid_layout": {"columns": 4, "rows": 2},
        "palette_colors": 48,
        "alpha": "binary transparent/opaque",
        "animation_ready_contract": {
            "canvas_locked": True,
            "body_axis_x": 64,
            "foot_baseline_y": 118,
            "do_not_recenter_by_silhouette": True,
        },
    }
    (OUT / "mechanic_master_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Built 8 directions in {OUT}")


if __name__ == "__main__":
    build(Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE)
