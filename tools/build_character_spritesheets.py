#!/usr/bin/env python3
"""Build 8-direction character sprite sheets from a folder of per-direction GIFs.

Godot has no GIF importer, so animated source art has to become a sprite sheet. This
turns a delivery folder like:

    char-sprites/
      char-idle/     idle-north.gif, idle-northeast.gif, ...   (one GIF per direction)
      char-walking/  walking-north.gif, ...
      char-model/    north.png, north-east.png, ...            (static poses, optional)

into two sheets under assets/art/characters/:

    char_mechanic_idle.png    8 rows x <idle frames> columns
    char_mechanic_walk.png    8 rows x <walk frames> columns

ROW ORDER is the direction convention the game reads (see DIRECTIONS below): starting at
east and going clockwise in screen space, which is exactly `round(atan2(dy, dx) / 45deg)`.
Keep it in sync with overworld_screen.gd's DIR_* constants.

ALIGNMENT: every frame is cropped to ONE shared bounding box — the union of the opaque
area across every frame of every direction — never per-frame. Cropping each frame to its
own bounds would re-centre the character on each frame and make the animation jitter.

Direction filenames are matched loosely (case, spaces, hyphens and underscores are
ignored), because delivery folders are rarely spelled consistently.

Usage:
    python3 tools/build_character_spritesheets.py <source-dir> [--dry-run]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    from PIL import Image, ImageSequence
except ImportError:  # pragma: no cover - environment guard
    sys.exit("Pillow is required: python3 -m pip install Pillow")

# Row order is SCREEN-SPACE clockwise from right: row i is the sprite to show when the
# player is heading i * 45 degrees, computed as round(atan2(dy, dx) / 45deg) with +x right
# and +y DOWN. Must match overworld_screen.gd's direction indexing.
#
# The compass words are the STANDARD screen mapping — east is screen-right, south is
# toward the camera. Name the source files to match and the sheet comes out correct.
DIRECTIONS = [
    "east",       # row 0 — heading right
    "southeast",  # row 1 — down-right
    "south",      # row 2 — down (faces camera)
    "southwest",  # row 3 — down-left
    "west",       # row 4 — left
    "northwest",  # row 5 — up-left
    "north",      # row 6 — up (faces away)
    "northeast",  # row 7 — up-right
]

OUT_DIR = Path("assets/art/characters")
SHEETS = [
    # (source subfolder, output filename)
    ("char-idle", "char_mechanic_idle.png"),
    ("char-walking", "char_mechanic_walk.png"),
]


def normalise(name: str) -> str:
    """Lowercase and strip everything that delivery folders spell inconsistently."""
    return re.sub(r"[^a-z]", "", name.lower())


def assign_directions(files: list[Path], folder: Path) -> dict[str, Path]:
    """Map each direction to exactly one file, by classifying every file once.

    Substring matching in the other direction (asking "which file contains 'west'?") is a
    trap: 'west' is inside 'northwest' and 'southwest', 'east' is inside 'northeast' and
    'southeast'. Any tie-break on top of that -- shortest name, alphabetical -- silently
    hands one compass point another's art and leaves a direction unused. That exact bug
    shipped once here: 'west' resolved to walking-northwest.gif, so west was missing and
    northwest appeared twice.

    So: classify each FILE by the LONGEST direction its normalised name ends with, then
    require the result to be a bijection. Ambiguity becomes a hard error, not a guess.
    """
    longest_first = sorted(DIRECTIONS, key=len, reverse=True)
    owner: dict[str, list[Path]] = {d: [] for d in DIRECTIONS}
    unmatched: list[Path] = []

    for f in files:
        stem = normalise(f.stem)
        hit = next((d for d in longest_first if stem.endswith(normalise(d))), None)
        if hit is None:
            unmatched.append(f)
        else:
            owner[hit].append(f)

    problems = []
    for d in DIRECTIONS:
        if not owner[d]:
            problems.append(f"    '{d}': no file")
        elif len(owner[d]) > 1:
            names = ", ".join(p.name for p in owner[d])
            problems.append(f"    '{d}': {len(owner[d])} files ({names})")
    if problems:
        detail = "\n".join(problems)
        extra = ""
        if unmatched:
            extra = "\n    unrecognised: " + ", ".join(p.name for p in unmatched)
        raise SystemExit(
            f"  {folder}: each of the 8 directions needs exactly one file.\n"
            f"{detail}{extra}\n"
            "  Name files so each ends with its direction, e.g. walking-northwest.gif."
        )
    if unmatched:
        print(f"    ignoring {len(unmatched)} file(s) with no direction in the name: "
              + ", ".join(p.name for p in unmatched))
    return {d: owner[d][0] for d in DIRECTIONS}


def load_frames(path: Path) -> list[Image.Image]:
    """All frames of a GIF (or the single frame of a still image) as RGBA."""
    img = Image.open(path)
    return [f.convert("RGBA") for f in ImageSequence.Iterator(img)]


def union_bbox(frames: list[Image.Image]) -> tuple[int, int, int, int] | None:
    """Smallest box containing the opaque pixels of every frame."""
    box = None
    for f in frames:
        b = f.getchannel("A").getbbox()
        if b is None:
            continue
        box = b if box is None else (
            min(box[0], b[0]), min(box[1], b[1]),
            max(box[2], b[2]), max(box[3], b[3]),
        )
    return box


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", type=Path, help="folder holding char-idle/ and char-walking/")
    ap.add_argument("--dry-run", action="store_true", help="report without writing")
    args = ap.parse_args()

    if not args.source.is_dir():
        return int(bool(sys.stderr.write(f"not a directory: {args.source}\n"))) or 1

    # Pass 1 — load everything and compute ONE bounding box across all sheets, so idle and
    # walk stay aligned with each other (a character that shifts between states looks like
    # it teleports on every stop and start).
    loaded: dict[str, list[list[Image.Image]]] = {}
    all_frames: list[Image.Image] = []
    for sub, _out in SHEETS:
        src = args.source / sub
        if not src.is_dir():
            print(f"  skip: {src} not found")
            continue
        files = sorted(p for p in src.iterdir() if p.suffix.lower() in {".gif", ".png"})
        chosen = assign_directions(files, src)
        per_dir = []
        for d in DIRECTIONS:
            print(f"    {d:10} <- {chosen[d].name}")
            frames = load_frames(chosen[d])
            per_dir.append(frames)
            all_frames.extend(frames)
        counts = {len(f) for f in per_dir}
        if len(counts) != 1:
            return int(bool(sys.stderr.write(
                f"{sub}: directions disagree on frame count {sorted(counts)}; "
                "a sheet needs one column count\n"))) or 1
        loaded[sub] = per_dir
        print(f"  {sub}: 8 directions x {counts.pop()} frames")

    if not loaded:
        return int(bool(sys.stderr.write("nothing to build\n"))) or 1

    box = union_bbox(all_frames)
    if box is None:
        return int(bool(sys.stderr.write("every frame is fully transparent\n"))) or 1

    # Expand the shared box to a SQUARE, centred on the original. This makes the sheets
    # self-describing: with a fixed 8 rows, frame height = sheet height / 8, and because
    # frames are square the column count is simply sheet width / frame height. Without it
    # the reader cannot tell a 4-column sheet from a 6-column one without being told.
    src_w, src_h = all_frames[0].size
    bw, bh = box[2] - box[0], box[3] - box[1]
    side = max(bw, bh)
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    left = int(round(cx - side / 2))
    top = int(round(cy - side / 2))
    # Keep the square inside the source so no frame samples outside the image.
    left = max(0, min(left, src_w - side))
    top = max(0, min(top, src_h - side))
    box = (left, top, left + side, top + side)
    fw = fh = side
    print(f"  shared crop box {box} -> square frame {fw}x{fh} (from {src_w}x{src_h})")

    # Pass 2 — compose. Rows are directions, columns are frames.
    for sub, out_name in SHEETS:
        if sub not in loaded:
            continue
        per_dir = loaded[sub]
        cols = len(per_dir[0])
        sheet = Image.new("RGBA", (fw * cols, fh * len(DIRECTIONS)), (0, 0, 0, 0))
        for row, frames in enumerate(per_dir):
            for col, frame in enumerate(frames):
                sheet.paste(frame.crop(box), (col * fw, row * fh))
        out = OUT_DIR / out_name
        if args.dry_run:
            print(f"  would write {out} ({sheet.width}x{sheet.height})")
        else:
            out.parent.mkdir(parents=True, exist_ok=True)
            sheet.save(out)
            print(f"  wrote {out} ({sheet.width}x{sheet.height}, {cols} cols x 8 rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
