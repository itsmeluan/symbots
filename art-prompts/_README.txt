SYMBOTS — AI IMAGE PROMPT LIBRARY
===================================
Tool: Pixel Lab (pixellab.ai)
Game: Symbots (creature-collection RPG, modular battle robots, Godot 4.7)
Generated: 2026-07-18 | Art Director: Symbots Art Bible v0.2

HOW TO USE
----------
1. Open Pixel Lab at pixellab.ai.
2. Pick the .txt file for the asset you want to generate.
3. Copy the FULL prompt text from the file.
4. Paste into Pixel Lab's prompt field and generate.
5. Export PNG at the canvas size specified at the top of each file.
6. Save the PNG to the target path shown at the top of each file
   (mirroring assets/art/ from the project root).

WORKFLOW NOTES
--------------
- Every file is self-contained and paste-ready.
- _style-guide.txt contains the SHARED STYLE PREAMBLE. Several prompts say
  "USE SHARED STYLE PREAMBLE" — in those cases, copy _style-guide.txt content
  first, then append the file's unique description.
- Generate 3–5 variants per asset and pick the one with the cleanest silhouette
  at the target canvas size. Silhouette clarity is the first-pass filter.
- Test every asset by viewing it at 64x64 greyscale before accepting —
  this is the art bible's mandatory readability gate.
- Part sprites (enemies/, parts/) must pass the "slot zone read" test:
  HEAD always on top, LEGS always on bottom, MID mass in between.

EXPORT SIZES QUICK-REF
-----------------------
characters/   : 64x96 (overworld) | 256x256 (workshop/battle-intro)
enemies/      : 256x256 per enemy (Workshop/detail) | mipmapped to 128x128 for battle
parts/        : 256x256 each (Workshop source-of-truth)
hud/          : varies — see each file (most are 9-slice: 128x32 bars, 64x64 frames)
buttons/      : 128x64 (most) | 9-slice friendly, chamfered corners
icons/        : 32x32 standard | 64x64 for element + stat icons
overworld/    : 64x96 (player token) | 32x32 (markers) | 128x128 (tiles)
workshop/     : 512x512 (bench background) | 64x64 (slot frames)
consumables/  : 64x64 each

TARGET PATH MAP (assets/art/ mirror)
--------------------------------------
characters/   -> assets/art/characters/
enemies/      -> assets/art/enemies/
parts/        -> assets/art/parts/
hud/          -> assets/art/ui/hud/
buttons/      -> assets/art/ui/buttons/
icons/        -> assets/art/ui/icons/
overworld/    -> assets/art/overworld/
workshop/     -> assets/art/ui/workshop/
consumables/  -> assets/art/consumables/

NAMING CONVENTION (from art-bible §8.4 + char_ extension)
----------------------------------------------------------
In-world part sprites : part_[manufacturer]_[slot]_[name].png
Character sprites     : char_mechanic_[masc|fem]_[context].png
Enemy sprites         : enemy_[id]_[view].png
UI icons              : icon_[type]_[key].png
UI chrome             : ui_[element]_[variant].png
Consumable icons      : icon_consumable_[id].png

MANUFACTURERS (art-bible §3.8)
-------------------------------
ironclad  = geometric, faceted, planar edges; dense perpendicular grid panel-lines;
             prominent hex bolts/rivets; heavy-industrial finish
scrapjaw  = asymmetric, directional edges (mid-motion at rest); diagonal ~45 slash
             panel-lines; quick-release clasps, slide-locks; scavenged-aggressive finish
boltwell  = exposed-structure treatment; beams/struts/cabling as surface detail;
             cable ties, locking rings, exposed connectors; high-tech instrument finish
wild      = evolved-organic, biome-adaptive; organic/weathered contour; seams still
             engineered (universal attachment grammar holds); no manufacturer tag

ELEMENTS (art-bible §4.2)
--------------------------
Volt     = Cyan #2FE8E8 | Lightning Fork glyph (bifurcated diagonal bolt)
Thermal  = Amber #F0900A | Flame Chevron glyph (upward-stacked Vs)
Kinetic  = Silver-shift #D8DDE6 | Impact Ring glyph (concentric circles) + chrome finish

RARITY FRAME RULES (art-bible §4.4)
-------------------------------------
Common    = single gunmetal border; no glow
Rare      = double border + diamond pip; soft ambient element-color glow ~25%
Boss-Grade = triple border + star; steady radiant glow ~60% + edge highlight
Prototype  = animated/irregular border + warning mark; chromatic shimmer <3 Hz

FOLDER MAP
----------
art-prompts/
  _README.txt           (this file)
  _style-guide.txt      (shared style preamble — prepend to all prompts)
  _index.txt            (master checklist of all files + target paths)
  characters/           (3 files — The Mechanic avatar)
  enemies/              (10 files — all enemy .tres)
  parts/                (16 files — all part .tres + generic slot icons)
  hud/                  (8 files — bars, frames, pips, panels)
  buttons/              (6 files — primary, target-select, back/close, states)
  icons/                (22 files — element, rarity, stat, scrap currency)
  overworld/            (5 files — player token, enemy marker, terrain tiles)
  workshop/             (4 files — bench BG, slot frames, core sphere)
  consumables/          (8 files — all consumable .tres)
