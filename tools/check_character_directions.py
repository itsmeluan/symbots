#!/usr/bin/env python3
"""Render a labelled contact sheet of the built character sheets, to eyeball directions.

Direction mix-ups are the failure mode of an 8-way character: the sheet builds fine, the
game runs fine, and the character just walks backwards. A still frame in isolation is hard
to judge, so this lays all 8 out in screen order with an arrow on each, which makes a wrong
row obvious at a glance.

    python3 tools/check_character_directions.py [--out PATH]

Read it as: "when the player walks THIS way (arrow), the character looks like THIS."
Row 0 must face right, row 2 face the camera, row 4 face left, row 6 face away.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - environment guard
    sys.exit("Pillow is required: python3 -m pip install Pillow")

SHEETS = [
    ("WALKING", Path("assets/art/characters/char_mechanic_walk.png")),
    ("IDLE", Path("assets/art/characters/char_mechanic_idle.png")),
]
ARROWS = ["-> right", "\\  down-right", "|  down", "/  down-left",
          "<- left", "\\  up-left", "|  up", "/  up-right"]
ROWS = 8
ZOOM = 4
PAD = 10
BG = (24, 27, 33)
FG = (232, 232, 232)
ACCENT = (120, 220, 150)


def load_font(size: int):
    for path in ("/System/Library/Fonts/HelveticaNeue.ttc",
                 "/System/Library/Fonts/Helvetica.ttc",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=Path("character_directions.png"))
    args = ap.parse_args()

    font = load_font(13)
    title_font = load_font(15)
    panels = []

    for label, path in SHEETS:
        if not path.exists():
            print(f"  missing: {path} — run build_character_spritesheets.py first")
            continue
        sheet = Image.open(path).convert("RGBA")
        side = sheet.height // ROWS
        if sheet.width % side:
            print(f"  {path.name}: width {sheet.width} is not a whole number of "
                  f"{side}px square frames — the sheet is malformed")
            continue
        cols = sheet.width // side
        fw = side * ZOOM
        panel = Image.new("RGB", (PAD + ROWS * (fw + PAD), fw + 54), BG)
        d = ImageDraw.Draw(panel)
        d.text((PAD, 6), f"{label}  ({cols} frames per direction)", font=title_font, fill=FG)
        for row in range(ROWS):
            frame = sheet.crop((0, row * side, side, (row + 1) * side))
            frame = frame.resize((fw, fw), Image.NEAREST)
            x = PAD + row * (fw + PAD)
            panel.paste(frame, (x, 26), frame)
            d.text((x, 30 + fw), f"{row}  {ARROWS[row]}", font=font, fill=ACCENT)
        panels.append(panel)

    if not panels:
        return 1

    out = Image.new("RGB", (max(p.width for p in panels),
                            sum(p.height for p in panels) + PAD), BG)
    y = 0
    for p in panels:
        out.paste(p, (0, y))
        y += p.height + PAD
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out)
    print(f"  wrote {args.out} ({out.width}x{out.height})")
    print("  Row 0 must face RIGHT, row 2 the CAMERA, row 4 LEFT, row 6 AWAY.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
