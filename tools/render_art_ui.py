#!/usr/bin/env python3
"""Render deterministic Symbots UI chrome, HUD, glyphs, and map utility assets."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "art"

COL = {
    "hud": "#1E2229",
    "panel": "#2C3340",
    "interactive": "#3A4455",
    "active": "#4090CC",
    "divider": "#4B5668",
    "text": "#E8E8E8",
    "muted": "#98A4B4",
    "green": "#3D7A4A",
    "ochre": "#C49A35",
    "gunmetal": "#374350",
    "amber_world": "#C4721A",
    "teal": "#2B6E68",
    "crimson": "#B33020",
    "bone": "#F2EDDF",
    "volt": "#2FE8E8",
    "thermal": "#F0900A",
    "kinetic": "#D8DDE6",
}


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_color.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def canvas(size: tuple[int, int], color=(0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", size, color)


def chamfer_points(box: tuple[int, int, int, int], cut: int) -> list[tuple[int, int]]:
    x0, y0, x1, y1 = box
    return [
        (x0 + cut, y0),
        (x1 - cut, y0),
        (x1, y0 + cut),
        (x1, y1 - cut),
        (x1 - cut, y1),
        (x0 + cut, y1),
        (x0, y1 - cut),
        (x0, y0 + cut),
    ]


def chamfer(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    cut: int,
    fill,
    outline=None,
    width: int = 1,
) -> None:
    pts = chamfer_points(box, cut)
    draw.polygon(pts, fill=fill)
    if outline is not None:
        draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def save(img: Image.Image, rel: str) -> None:
    path = ART / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def draw_panel(rel: str, size: tuple[int, int], fill: str, border: str, cut: int, inset=False) -> None:
    img = canvas(size)
    d = ImageDraw.Draw(img)
    chamfer(d, (1, 1, size[0] - 2, size[1] - 2), cut, rgba(fill), rgba(border), 2)
    if inset:
        chamfer(d, (7, 7, size[0] - 8, size[1] - 8), max(2, cut - 3), None, rgba(COL["hud"]), 2)
    save(img, rel)


def draw_button(rel: str, size: tuple[int, int], fill: str, border: str, accent: str | None = None) -> None:
    w, h = size
    img = canvas(size)
    d = ImageDraw.Draw(img)
    chamfer(d, (1, 1, w - 2, h - 2), 10, rgba(fill), rgba(border), 2)
    chamfer(d, (5, 5, w - 6, h - 6), 7, None, rgba(COL["hud"]), 1)
    if accent:
        d.polygon([(8, h - 8), (34, h - 8), (40, h - 14), (14, h - 14)], fill=rgba(accent))
        d.line([(w - 42, 9), (w - 12, 9)], fill=rgba(accent), width=3)
    save(img, rel)


def render_buttons() -> None:
    specs = {
        "ui/buttons/ui_btn_generic_normal.png": ("#303744", COL["divider"], None),
        "ui/buttons/ui_btn_generic_hover.png": ("#3A4455", COL["active"], COL["active"]),
        "ui/buttons/ui_btn_generic_pressed.png": ("#263F5B", COL["active"], COL["active"]),
        "ui/buttons/ui_btn_generic_disabled.png": ("#262A31", "#343A45", None),
    }
    for rel, (fill, border, accent) in specs.items():
        draw_button(rel, (192, 56), fill, border, accent)

    primary = {
        "normal": ("#326FA5", "#68A9DC"),
        "hover": ("#3C83BC", "#8EC7ED"),
        "pressed": ("#285579", "#4090CC"),
        "disabled": ("#27313B", "#414A55"),
    }
    for state, (fill, border) in primary.items():
        draw_button(f"ui/buttons/ui_btn_primary_{state}.png", (256, 64), fill, border, COL["active"] if state != "disabled" else None)

    target = {
        "normal": ("#2B3039", "#495262", None),
        "hover": ("#343C48", "#708099", COL["active"]),
        "selected": ("#443A19", COL["ochre"], COL["ochre"]),
        "disabled": ("#25282F", "#353A44", None),
    }
    for state, (fill, border, accent) in target.items():
        draw_button(f"ui/buttons/ui_btn_target_{state}.png", (192, 56), fill, border, accent)


def render_panels() -> None:
    draw_panel("ui/panel_frame.png", (256, 256), COL["panel"], COL["divider"], 16, True)
    draw_panel("ui/panel_frame_dark.png", (256, 256), COL["hud"], "#363E4B", 16, True)
    draw_panel("ui/overlay_card.png", (512, 320), "#242A33", COL["ochre"], 22, True)

    divider = canvas((256, 4))
    dd = ImageDraw.Draw(divider)
    dd.rectangle((0, 1, 255, 2), fill=rgba(COL["divider"]))
    dd.rectangle((28, 0, 76, 3), fill=rgba(COL["active"]))
    save(divider, "ui/divider_horizontal.png")

    track = canvas((16, 256))
    td = ImageDraw.Draw(track)
    chamfer(td, (3, 0, 12, 255), 3, rgba(COL["hud"]), rgba(COL["divider"]), 1)
    save(track, "ui/scroll_track.png")
    grab = canvas((16, 48))
    gd = ImageDraw.Draw(grab)
    chamfer(gd, (1, 1, 14, 46), 4, rgba(COL["interactive"]), rgba(COL["active"]), 1)
    gd.line((6, 17, 10, 17), fill=rgba(COL["muted"]), width=1)
    gd.line((6, 24, 10, 24), fill=rgba(COL["muted"]), width=1)
    gd.line((6, 31, 10, 31), fill=rgba(COL["muted"]), width=1)
    save(grab, "ui/scroll_grabber.png")


def draw_bar(rel: str, fill: str, ratio: float, zones: list[str] | None = None) -> None:
    img = canvas((256, 32))
    d = ImageDraw.Draw(img)
    chamfer(d, (0, 2, 255, 29), 6, rgba("#101318"), rgba(COL["divider"]), 2)
    if zones:
        x0, x1 = 5, 250
        seg = (x1 - x0) // len(zones)
        for i, color in enumerate(zones):
            left = x0 + i * seg
            right = x1 if i == len(zones) - 1 else left + seg - 1
            d.rectangle((left, 8, right, 23), fill=rgba(color))
    else:
        right = 5 + int(245 * ratio)
        d.rectangle((5, 8, right, 23), fill=rgba(fill))
        d.rectangle((5, 8, right, 10), fill=rgba(COL["bone"], 90))
    d.line((5, 25, 250, 25), fill=rgba("#0B0D10"), width=1)
    save(img, rel)


def render_hud() -> None:
    draw_bar("ui/hud/ui_bar_structure_player.png", "#4FAD63", 0.76)
    draw_bar("ui/hud/ui_bar_structure_enemy.png", "#D94D47", 0.63)
    draw_bar("ui/hud/ui_bar_energy.png", COL["active"], 0.68)
    draw_bar("ui/hud/ui_bar_heat.png", COL["thermal"], 1.0, ["#2B6E68", "#C49A35", "#B33020"])

    pips = canvas((128, 16))
    pd = ImageDraw.Draw(pips)
    for i in range(8):
        x = 2 + i * 16
        fill = COL["ochre"] if i < 5 else COL["hud"]
        pd.rectangle((x, 3, x + 11, 12), fill=rgba(fill), outline=rgba(COL["divider"]))
    save(pips, "ui/hud/ui_break_pip_row.png")

    draw_panel("ui/hud/ui_panel_frame_general.png", (256, 128), COL["hud"], COL["divider"], 12, True)

    reticle = canvas((128, 128))
    rd = ImageDraw.Draw(reticle)
    color = rgba(COL["ochre"])
    for pts in [
        [(6, 34), (6, 12), (12, 6), (34, 6)],
        [(94, 6), (116, 6), (122, 12), (122, 34)],
        [(122, 94), (122, 116), (116, 122), (94, 122)],
        [(34, 122), (12, 122), (6, 116), (6, 94)],
    ]:
        rd.line(pts, fill=color, width=4)
    rd.line((52, 64, 76, 64), fill=color, width=2)
    rd.line((64, 52, 64, 76), fill=color, width=2)
    save(reticle, "ui/hud/ui_target_reticle.png")


def icon_base() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = canvas((32, 32))
    return img, ImageDraw.Draw(img)


def save_icon(img: Image.Image, name: str) -> None:
    save(img, f"icons/{name}.png")


def render_slot_icons() -> None:
    c = rgba(COL["bone"])
    s = rgba(COL["gunmetal"])
    a = rgba(COL["active"])

    img, d = icon_base()
    d.polygon([(7, 12), (11, 5), (21, 5), (25, 12), (23, 24), (9, 24)], fill=s, outline=c)
    d.rectangle((10, 12, 22, 16), fill=a)
    save_icon(img, "slot_head")

    img, d = icon_base()
    d.polygon([(5, 10), (10, 5), (22, 5), (27, 10), (25, 26), (7, 26)], fill=s, outline=c)
    d.rectangle((13, 11, 19, 21), outline=a, width=2)
    save_icon(img, "slot_chassis")

    for side, name in [(-1, "slot_arm_l"), (1, "slot_arm_r")]:
        img, d = icon_base()
        x = 16
        pts = [(x, 6), (x + side * 7, 9), (x + side * 10, 20), (x + side * 6, 27), (x + side * 2, 22), (x, 14)]
        d.polygon(pts, fill=s, outline=c)
        d.ellipse((12, 4, 20, 12), outline=a, width=2)
        save_icon(img, name)

    img, d = icon_base()
    d.polygon([(8, 5), (14, 5), (15, 24), (11, 28), (7, 24)], fill=s, outline=c)
    d.polygon([(18, 5), (24, 5), (25, 24), (21, 28), (17, 24)], fill=s, outline=c)
    save_icon(img, "slot_legs")

    img, d = icon_base()
    d.polygon([(4, 13), (19, 13), (25, 8), (29, 10), (23, 16), (29, 20), (25, 23), (19, 18), (4, 18)], fill=s, outline=c)
    d.rectangle((6, 14, 13, 17), fill=a)
    save_icon(img, "slot_weapon")

    img, d = icon_base()
    d.rectangle((7, 8, 25, 24), fill=s, outline=c)
    d.rectangle((12, 12, 20, 20), outline=a, width=2)
    for x in range(9, 26, 4):
        d.line((x, 5, x, 8), fill=c)
        d.line((x, 24, x, 27), fill=c)
    save_icon(img, "slot_chipset")

    img, d = icon_base()
    chamfer(d, (9, 5, 23, 27), 3, s, c, 1)
    d.rectangle((13, 2, 19, 5), fill=c)
    d.rectangle((12, 10, 20, 21), fill=a)
    save_icon(img, "slot_energy_cell")

    img, d = icon_base()
    d.ellipse((5, 5, 27, 27), fill=s, outline=c, width=2)
    d.ellipse((10, 10, 22, 22), outline=a, width=2)
    save_icon(img, "slot_core")


def render_element_icons() -> None:
    img, d = icon_base()
    d.polygon([(18, 2), (7, 18), (14, 18), (11, 30), (25, 12), (18, 12)], fill=rgba(COL["volt"]), outline=rgba(COL["bone"]))
    save_icon(img, "element_volt")

    img, d = icon_base()
    d.polygon([(16, 2), (23, 11), (20, 12), (26, 21), (16, 30), (6, 21), (12, 12), (9, 11)], fill=rgba(COL["thermal"]), outline=rgba(COL["bone"]))
    d.polygon([(16, 12), (20, 20), (16, 25), (12, 20)], fill=rgba(COL["hud"]))
    save_icon(img, "element_thermal")

    img, d = icon_base()
    d.ellipse((4, 4, 28, 28), outline=rgba(COL["kinetic"]), width=3)
    d.ellipse((10, 10, 22, 22), outline=rgba(COL["kinetic"]), width=2)
    d.rectangle((14, 1, 18, 7), fill=rgba(COL["kinetic"]))
    d.rectangle((14, 25, 18, 31), fill=rgba(COL["kinetic"]))
    save_icon(img, "element_kinetic")


def render_rarity_icons() -> None:
    specs = {
        "rarity_common": ([COL["gunmetal"]], None),
        "rarity_rare": ([COL["gunmetal"], COL["active"]], "diamond"),
        "rarity_boss": ([COL["gunmetal"], COL["ochre"], COL["bone"]], "star"),
        "rarity_prototype": ([COL["crimson"], COL["active"]], "warning"),
    }
    for name, (borders, mark) in specs.items():
        img = canvas((72, 72))
        d = ImageDraw.Draw(img)
        for i, color in enumerate(borders):
            chamfer(d, (2 + i * 4, 2 + i * 4, 69 - i * 4, 69 - i * 4), 10 - i, None, rgba(color), 2)
        if mark == "diamond":
            d.polygon([(36, 2), (40, 6), (36, 10), (32, 6)], fill=rgba(COL["active"]))
        elif mark == "star":
            pts = []
            for j in range(10):
                ang = -math.pi / 2 + j * math.pi / 5
                rad = 6 if j % 2 == 0 else 3
                pts.append((36 + math.cos(ang) * rad, 7 + math.sin(ang) * rad))
            d.polygon(pts, fill=rgba(COL["ochre"]))
        elif mark == "warning":
            d.polygon([(36, 2), (43, 13), (29, 13)], fill=rgba(COL["crimson"]), outline=rgba(COL["bone"]))
            d.rectangle((35, 5, 37, 9), fill=rgba(COL["bone"]))
        save_icon(img, name)


def render_stat_icons() -> None:
    c = rgba(COL["bone"])
    m = rgba(COL["muted"])
    a = rgba(COL["active"])

    def new(name: str):
        img, d = icon_base()
        return name, img, d

    name, img, d = new("stat_structure")
    d.polygon([(6, 6), (26, 6), (28, 14), (23, 27), (9, 27), (4, 14)], fill=rgba(COL["gunmetal"]), outline=c)
    d.line((10, 11, 22, 22), fill=m, width=2)
    save_icon(img, name)

    name, img, d = new("stat_armor")
    d.polygon([(16, 3), (27, 8), (24, 23), (16, 29), (8, 23), (5, 8)], fill=rgba(COL["gunmetal"]), outline=c)
    d.line((16, 7, 16, 25), fill=a, width=2)
    save_icon(img, name)

    name, img, d = new("stat_resistance")
    for y in (8, 15, 22):
        d.line((26, y, 9, y), fill=c, width=3)
        d.line((9, y, 14, y - 4), fill=c, width=3)
        d.line((9, y, 14, y + 4), fill=c, width=3)
    save_icon(img, name)

    name, img, d = new("stat_physical_power")
    d.rectangle((5, 6, 19, 17), fill=rgba(COL["gunmetal"]), outline=c)
    d.rectangle((13, 16, 18, 28), fill=c)
    d.line((21, 9, 28, 4), fill=rgba(COL["kinetic"]), width=2)
    d.line((22, 14, 30, 14), fill=rgba(COL["kinetic"]), width=2)
    save_icon(img, name)

    name, img, d = new("stat_energy_power")
    for j in range(8):
        ang = j * math.pi / 4
        d.line((16 + math.cos(ang) * 6, 16 + math.sin(ang) * 6, 16 + math.cos(ang) * 14, 16 + math.sin(ang) * 14), fill=a, width=2)
    d.ellipse((11, 11, 21, 21), fill=c)
    save_icon(img, name)

    name, img, d = new("stat_mobility")
    d.polygon([(3, 13), (20, 13), (20, 7), (30, 16), (20, 25), (20, 19), (3, 19)], fill=c)
    save_icon(img, name)

    name, img, d = new("stat_targeting")
    d.ellipse((8, 8, 24, 24), outline=c, width=2)
    d.line((16, 2, 16, 10), fill=c, width=2)
    d.line((16, 22, 16, 30), fill=c, width=2)
    d.line((2, 16, 10, 16), fill=c, width=2)
    d.line((22, 16, 30, 16), fill=c, width=2)
    save_icon(img, name)

    name, img, d = new("stat_processing")
    d.rectangle((8, 8, 24, 24), fill=rgba(COL["gunmetal"]), outline=c)
    d.rectangle((12, 12, 20, 20), outline=a, width=2)
    for x in range(10, 25, 5):
        d.line((x, 4, x, 8), fill=c)
        d.line((x, 24, x, 28), fill=c)
    save_icon(img, name)

    name, img, d = new("stat_cooling")
    d.ellipse((5, 5, 27, 27), outline=c, width=2)
    for j in range(4):
        ang = j * math.pi / 2
        p1 = (16 + math.cos(ang) * 3, 16 + math.sin(ang) * 3)
        p2 = (16 + math.cos(ang + 0.5) * 10, 16 + math.sin(ang + 0.5) * 10)
        p3 = (16 + math.cos(ang - 0.5) * 7, 16 + math.sin(ang - 0.5) * 7)
        d.polygon([p1, p2, p3], fill=a)
    save_icon(img, name)

    name, img, d = new("stat_energy_capacity")
    chamfer(d, (9, 5, 23, 28), 3, rgba(COL["gunmetal"]), c, 1)
    d.rectangle((13, 2, 19, 5), fill=c)
    d.rectangle((12, 10, 20, 24), fill=a)
    save_icon(img, name)

    name, img, d = new("stat_recharge")
    chamfer(d, (4, 12, 17, 29), 2, rgba(COL["gunmetal"]), c, 1)
    d.rectangle((8, 9, 13, 12), fill=c)
    d.polygon([(22, 3), (30, 11), (25, 11), (25, 23), (19, 23), (19, 11), (14, 11)], fill=a)
    save_icon(img, name)


def render_workshop_frames() -> None:
    draw_panel("workshop/slot_frame.png", (80, 80), COL["hud"], COL["divider"], 10, True)
    img = canvas((80, 80))
    d = ImageDraw.Draw(img)
    chamfer(d, (1, 1, 78, 78), 10, rgba(COL["panel"]), rgba(COL["active"]), 3)
    chamfer(d, (7, 7, 72, 72), 7, None, rgba("#78B7E5"), 1)
    d.polygon([(8, 65), (25, 65), (31, 71), (8, 71)], fill=rgba(COL["active"]))
    save(img, "workshop/slot_frame_filled.png")


def render_overworld_utilities() -> None:
    rnd = random.Random(1307)
    tile = canvas((64, 64), rgba(COL["green"]))
    d = ImageDraw.Draw(tile)
    for y in range(0, 64, 8):
        for x in range(0, 64, 8):
            n = rnd.random()
            if n < 0.18:
                color = rgba(COL["ochre"], 110)
            elif n < 0.28:
                color = rgba(COL["teal"], 120)
            else:
                color = rgba("#477E51", 95)
            d.rectangle((x, y, x + 9, y + 9), fill=color)
    for i in range(4):
        x = i * 16
        d.line((x, 0, (x + 24) % 64, 64), fill=rgba(COL["teal"], 70), width=2)
    save(tile, "overworld/terrain_base_tile.png")

    for variant in range(3):
        img = canvas((64, 64))
        dd = ImageDraw.Draw(img)
        local = random.Random(900 + variant)
        for _ in range(3):
            x, y = local.randint(8, 54), local.randint(8, 54)
            if variant == 0:
                dd.arc((x - 8, y - 8, x + 8, y + 8), 20, 210, fill=rgba(COL["teal"]), width=2)
                dd.rectangle((x - 2, y - 2, x + 4, y + 3), fill=rgba(COL["gunmetal"]))
            elif variant == 1:
                dd.polygon([(x - 7, y - 5), (x + 7, y - 2), (x + 3, y + 6), (x - 5, y + 4)], fill=rgba(COL["gunmetal"]), outline=rgba(COL["ochre"]))
            else:
                dd.ellipse((x - 5, y - 5, x + 5, y + 5), outline=rgba(COL["ochre"]), width=2)
                dd.line((x + 4, y - 4, x + 10, y - 9), fill=rgba(COL["teal"]), width=2)
        suffix = "" if variant == 0 else f"_v{variant + 1}"
        save(img, f"overworld/terrain_accent_tile{suffix}.png")

    marker = canvas((96, 96))
    md = ImageDraw.Draw(marker)
    chamfer(md, (8, 8, 87, 87), 16, None, rgba(COL["crimson"]), 4)
    chamfer(md, (15, 15, 80, 80), 12, None, rgba(COL["ochre"]), 2)
    md.polygon([(48, 4), (54, 14), (48, 24), (42, 14)], fill=rgba(COL["crimson"]))
    save(marker, "overworld/encounter_marker_frame.png")


def render_logo() -> None:
    # Text-free chrome plate used behind a deterministic wordmark in screen composition.
    img = canvas((640, 180))
    d = ImageDraw.Draw(img)
    chamfer(d, (5, 26, 620, 150), 26, rgba(COL["hud"], 230), rgba(COL["active"]), 4)
    d.polygon([(26, 18), (320, 2), (612, 18), (590, 34), (320, 22), (48, 34)], fill=rgba(COL["ochre"]))
    d.line((32, 140, 280, 140), fill=rgba(COL["volt"]), width=5)
    d.line((360, 140, 590, 140), fill=rgba(COL["volt"]), width=5)
    save(img, "main-menu/logo_plate.png")


def main() -> None:
    render_buttons()
    render_panels()
    render_hud()
    render_slot_icons()
    render_element_icons()
    render_rarity_icons()
    render_stat_icons()
    render_workshop_frames()
    render_overworld_utilities()
    render_logo()


if __name__ == "__main__":
    main()
