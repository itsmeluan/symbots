#!/usr/bin/env python3
"""Render the eight documented consumable icons as crisp standalone PNG assets."""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/art/consumables"
OUT.mkdir(parents=True, exist_ok=True)

S = 4
C = {
    "bg": (18, 23, 29, 255), "slate": (55, 67, 80, 255), "panel": (44, 51, 64, 255),
    "bone": (242, 237, 223, 255), "ochre": (196, 154, 53, 255), "amber": (240, 144, 10, 255),
    "red": (179, 48, 32, 255), "teal": (43, 110, 104, 255), "blue": (64, 144, 204, 255),
    "gold": (232, 184, 32, 255), "dark": (20, 25, 31, 255), "white": (232, 232, 232, 255),
}


def sc(v): return int(v * S)


def pts(seq): return [(sc(x), sc(y)) for x, y in seq]


def line(d, xy, fill, width=1): d.line(pts(xy), fill=fill, width=sc(width), joint="curve")


def poly(d, xy, fill, outline=None, width=1):
    d.polygon(pts(xy), fill=fill)
    if outline: d.line(pts(xy + [xy[0]]), fill=outline, width=sc(width), joint="curve")


def rect(d, box, fill, outline=None, width=1):
    d.rectangle(tuple(sc(v) for v in box), fill=fill, outline=outline, width=sc(width))


def ellipse(d, box, fill, outline=None, width=1):
    d.ellipse(tuple(sc(v) for v in box), fill=fill, outline=outline, width=sc(width))


def chamfer(d, box=(2, 2, 62, 62), cut=5, fill=C["bg"], outline=C["slate"], width=2):
    x0, y0, x1, y1 = box
    p = [(x0+cut,y0),(x1-cut,y0),(x1,y0+cut),(x1,y1-cut),(x1-cut,y1),(x0+cut,y1),(x0,y1-cut),(x0,y0+cut)]
    poly(d, p, fill, outline, width)


def frame(d, rarity):
    chamfer(d)
    if rarity >= 2: chamfer(d, (5,5,59,59), 3, None, C["ochre"], 1)
    if rarity >= 3:
        chamfer(d, (8,8,56,56), 3, None, C["gold"], 1)
        poly(d, [(51,9),(52.5,12),(56,12.5),(53.5,15),(54,18.5),(51,17),(48,18.5),(48.5,15),(46,12.5),(49.5,12)], C["gold"])
    elif rarity == 2:
        poly(d, [(51,8),(55,12),(51,16),(47,12)], C["ochre"])


def make(name, rarity, painter):
    im = Image.new("RGBA", (sc(64), sc(64)), (0,0,0,0))
    d = ImageDraw.Draw(im)
    frame(d, rarity)
    painter(d)
    im.resize((64,64), Image.Resampling.LANCZOS).save(OUT / f"icon_consumable_{name}.png")


def weld_patch(d):
    poly(d, [(15,20),(45,16),(50,43),(19,48)], C["slate"], C["bone"], 1)
    for a,b in [((18,22),(44,19)),((47,22),(49,40)),((45,43),(21,46)),((18,42),(16,24))]:
        line(d,[a,b],C["amber"],2)
    line(d,[(43,45),(52,51)],C["ochre"],4); ellipse(d,(49,48,55,54),C["bone"])


def repair_kit(d):
    poly(d,[(13,25),(49,25),(53,48),(10,48)],C["slate"],C["bone"],1)
    rect(d,(20,20,42,26),C["ochre"],C["dark"],1)
    rect(d,(28,30,35,44),C["bone"]); rect(d,(24,34,39,40),C["bone"])
    line(d,[(15,28),(48,28)],C["ochre"],1)


def field_forge(d):
    poly(d,[(13,20),(48,20),(53,47),(9,47)],C["slate"],C["bone"],1)
    rect(d,(17,27,45,41),C["dark"],C["ochre"],2)
    rect(d,(20,31,42,39),C["amber"])
    poly(d,[(24,17),(40,17),(36,22),(20,22)],C["bone"],C["dark"],1)


def coolant(d):
    poly(d,[(23,17),(41,17),(45,47),(19,47)],C["slate"],C["bone"],1)
    rect(d,(27,22,36,42),C["teal"],C["dark"],1)
    rect(d,(25,13,38,18),C["bone"],C["dark"],1); rect(d,(36,10,48,14),C["slate"],C["bone"],1)
    for x,y,r in [(49,13,2),(53,11,1),(55,15,1)]: ellipse(d,(x-r,y-r,x+r,y+r),C["teal"])


def power_cell(d):
    poly(d,[(15,21),(46,21),(50,44),(12,44)],C["slate"],C["bone"],1)
    rect(d,(19,28,43,36),C["blue"],C["dark"],1); rect(d,(21,30,39,34),C["bone"])
    rect(d,(21,16,27,22),C["bone"]); rect(d,(36,16,42,22),C["bone"])


def salvage(d):
    poly(d,[(18,31),(45,31),(48,49),(15,49)],C["slate"],C["bone"],1)
    poly(d,[(26,31),(37,31),(34,21),(29,21)],C["gold"],C["bone"],1)
    ellipse(d,(25,36,38,45),C["dark"],C["gold"],1); line(d,[(28,42),(35,36)],C["gold"],1)
    for off in [0,4,8]: d.arc((sc(20-off),sc(9-off),sc(43+off),sc(31+off)),200,340,fill=C["gold"],width=sc(1))


def lure(d):
    rect(d,(24,25,42,45),C["slate"],C["ochre"],1); line(d,[(33,25),(33,14)],C["bone"],2)
    for off in [0,4]: d.arc((sc(25-off),sc(8-off),sc(41+off),sc(23+off)),200,340,fill=C["amber"],width=sc(1))
    poly(d,[(10,42),(18,33),(25,44)],C["ochre"],C["dark"],1); poly(d,[(17,47),(24,37),(31,49)],C["red"],C["dark"],1)
    poly(d,[(35,50),(43,39),(52,48)],C["ochre"],C["dark"],1)


def jammer(d):
    poly(d,[(13,28),(50,28),(53,48),(10,48)],C["slate"],C["bone"],1)
    line(d,[(22,28),(20,14)],C["bone"],2); line(d,[(42,28),(44,14)],C["bone"],2)
    line(d,[(26,35),(38,43)],C["teal"],2); line(d,[(38,35),(26,43)],C["teal"],2)
    for y in [17,21]:
        line(d,[(8,y),(14,y-2)],C["teal"],1); line(d,[(17,y-3),(21,y-4)],C["teal"],1)
        line(d,[(56,y),(50,y-2)],C["teal"],1); line(d,[(47,y-3),(43,y-4)],C["teal"],1)


make("weld_patch", 1, weld_patch)
make("repair_kit", 2, repair_kit)
make("field_forge", 3, field_forge)
make("coolant_flush", 1, coolant)
make("power_cell", 1, power_cell)
make("salvage_beacon", 2, salvage)
make("scrap_lure", 1, lure)
make("signal_jammer", 2, jammer)

print(f"Rendered 8 consumable icons to {OUT}")
