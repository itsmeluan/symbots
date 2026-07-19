# Character sprite source — drop new art here

This is the **source** folder for the player character. Put the delivered files in the
subfolders below, then run one command to turn them into the sheets the game loads.

Nothing here is loaded by the game directly (`.gdignore` keeps Godot out of it) — these
are the originals. The build tool writes the game-facing sheets into
`assets/art/characters/`.

---

## Where each file goes

```
character-v2/
├── char-idle/       one file per direction — the standing/breathing loop
├── char-walking/    one file per direction — the walk cycle
└── char-model/      optional: static poses, not used by the overworld yet
```

`char-idle/` and `char-walking/` are the two the game uses. Both accept **animated GIF**
or **still PNG**.

## The 8 directions

One file per direction in each folder, with the direction word somewhere in the filename:

| File contains | Character should be walking / facing | On screen |
|---|---|---|
| `east` | right | → |
| `southeast` | down and right | ↘ |
| `south` | toward the camera | ↓ |
| `southwest` | down and left | ↙ |
| `west` | left | ← |
| `northwest` | up and left | ↖ |
| `north` | away from the camera | ↑ |
| `northeast` | up and right | ↗ |

**`east` = facing the RIGHT side of the screen. `south` = facing the player.**

Filenames are matched loosely — case, spaces, hyphens and underscores are all ignored — so
`walking-east.gif`, `Walking East.GIF` and `walk_EAST.png` are equivalent. Longest match
wins, so `northeast` is never mistaken for `north`.

## Rules the art must follow

1. **Every frame the same canvas size**, within a folder and across both folders. The
   build tool crops all of them to one shared box so the character does not jitter between
   frames or jump between idle and walk — that only works if the framing is consistent.
2. **Same frame count for all 8 directions** inside a folder. Idle and walk may differ from
   each other (e.g. idle 4, walk 6); they just have to be internally consistent.
3. Transparent background.

## Build it

```
python3 tools/build_character_spritesheets.py production/art-sources/character-v2
```

This writes `assets/art/characters/char_mechanic_idle.png` and `char_mechanic_walk.png`,
then Godot picks them up on the next import. No code changes.

## Check it before trusting it

Directions are the thing that goes wrong, and it is not obvious in a still frame. After
building, render a labelled contact sheet:

```
python3 tools/check_character_directions.py
```

Row 0 must show the character oriented **rightward**, row 2 facing the **camera**, row 4
**leftward**, row 6 **away**. If a row disagrees, the source file for that direction is
mislabelled — rename it rather than changing the tool.
