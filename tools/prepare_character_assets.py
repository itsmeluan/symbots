#!/usr/bin/env python3
"""Prepare canonical character canvases from high-resolution generated sources."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "art" / "generated-v1" / "final" / "characters"
OUT = ROOT / "assets" / "art" / "characters"
OUT.mkdir(parents=True, exist_ok=True)


def alpha_crop(img: Image.Image) -> Image.Image:
    # Ignore faint chroma-matte residue when calculating the content bounds.
    mask = img.getchannel("A").point(lambda value: 255 if value >= 64 else 0)
    box = mask.getbbox()
    return img.crop(box) if box else img


def prepare_walk(variant: str) -> None:
    src = Image.open(SRC / f"mechanic-{variant}-overworld-walk.png").convert("RGBA")
    sheet = Image.new("RGBA", (256, 384), (0, 0, 0, 0))
    for row in range(4):
        for col in range(4):
            x0 = round(col * src.width / 4)
            x1 = round((col + 1) * src.width / 4)
            y0 = round(row * src.height / 4)
            y1 = round((row + 1) * src.height / 4)
            frame = alpha_crop(src.crop((x0, y0, x1, y1)))
            frame.thumbnail((58, 90), Image.Resampling.LANCZOS)
            px = col * 64 + (64 - frame.width) // 2
            py = row * 96 + (96 - frame.height) // 2
            sheet.alpha_composite(frame, (px, py))
    sheet.save(OUT / f"char_mechanic_{variant}_overworld_walk.png", optimize=True)


def prepare_pose(variant: str, pose: str) -> None:
    src = alpha_crop(Image.open(SRC / f"mechanic-{variant}-{pose}.png").convert("RGBA"))
    src.thumbnail((236, 236), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    out.alpha_composite(src, ((256 - src.width) // 2, (256 - src.height) // 2))
    out.save(OUT / f"char_mechanic_{variant}_{pose.replace('-', '_')}.png", optimize=True)


for identity in ("masc", "fem"):
    prepare_walk(identity)
    prepare_pose(identity, "workshop-idle")
    prepare_pose(identity, "battle-intro")
