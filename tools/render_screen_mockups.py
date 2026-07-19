#!/usr/bin/env python3
"""Compose all approved Symbots screen states from the generated asset kit."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/art"
OUT = ART / "mockups"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1024, 600

DIN = "/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf"
MONO = "/System/Library/Fonts/SFNSMono.ttf"
COL = {
    "hud": "#1E2229", "panel": "#2C3340", "panel2": "#151B22", "edge": "#4B5668",
    "blue": "#4090CC", "teal": "#2B6E68", "white": "#E8E8E8", "muted": "#98A4B4",
    "ochre": "#C49A35", "amber": "#F0900A", "red": "#B33020", "gold": "#E8B820",
    "cyan": "#2FE8E8", "green": "#55B76A",
}


def font(size, heading=False): return ImageFont.truetype(DIN if heading else MONO, size)


def rgba(path): return Image.open(path).convert("RGBA")


def fit(im, size):
    out = Image.new("RGBA", size, (0,0,0,0)); cp = im.copy(); cp.thumbnail(size, Image.Resampling.LANCZOS)
    out.alpha_composite(cp, ((size[0]-cp.width)//2, (size[1]-cp.height)//2)); return out


def paste_fit(base, path, box, flip=False, opacity=255):
    im = fit(rgba(path), (box[2],box[3]));
    if flip: im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if opacity < 255: im.putalpha(im.getchannel("A").point(lambda a: a*opacity//255))
    base.alpha_composite(im, (box[0],box[1]))


def txt(d, xy, value, size=18, color=None, heading=False, anchor="la", stroke=0):
    d.text(xy, value, font=font(size, heading), fill=color or COL["white"], anchor=anchor,
           stroke_width=stroke, stroke_fill="#111820")


def chamfer_points(box, cut=12):
    x0,y0,x1,y1=box
    return [(x0+cut,y0),(x1-cut,y0),(x1,y0+cut),(x1,y1-cut),(x1-cut,y1),(x0+cut,y1),(x0,y1-cut),(x0,y0+cut)]


def panel(base, box, fill=(30,36,45,230), edge=COL["edge"], cut=12, width=2):
    d=ImageDraw.Draw(base); p=chamfer_points(box,cut); d.polygon(p,fill=fill); d.line(p+[p[0]],fill=edge,width=width,joint="curve")


def button(base, box, label, kind="generic", state="normal", small=20):
    p=ART/f"ui/buttons/ui_btn_{kind}_{state}.png"; im=rgba(p).resize((box[2],box[3]),Image.Resampling.LANCZOS)
    base.alpha_composite(im,(box[0],box[1])); d=ImageDraw.Draw(base)
    color=COL["muted"] if state=="disabled" else COL["white"]
    txt(d,(box[0]+box[2]//2,box[1]+box[3]//2-1),label,small,color,True,"mm",1)


def header(base, title, sub=None):
    overlay=Image.new("RGBA",(W,66),(22,28,36,238)); base.alpha_composite(overlay,(0,0)); d=ImageDraw.Draw(base)
    d.line((0,65,W,65),fill=COL["blue"],width=2); txt(d,(24,12),title,30,heading=True)
    if sub: txt(d,(24,48),sub,11,COL["muted"])


def compose_bot(size=380):
    c=Image.new("RGBA",(512,512),(0,0,0,0))
    layers=[
        ("parts/wild_tread_legs.png",(76,230,360,250),False),
        ("parts/scrapjaw_servo_arm.png",(60,135,390,300),False),
        ("parts/ironclad_aegis_frame.png",(95,130,320,300),False),
        ("parts/wild_optic_sensor.png",(156,40,200,200),False),
        ("parts/boltwell_arc_blaster.png",(300,165,190,190),False),
        ("parts/boltwell_surge_core.png",(202,195,108,108),False),
    ]
    for rel,b,fl in layers: paste_fit(c,ART/rel,b,fl)
    return fit(c,(size,size))


def main_menu(first=False, modal=False):
    base=rgba(ART/"main-menu/background.png")
    shade=Image.new("RGBA",(610,H),(7,14,24,120)); base.alpha_composite(shade,(0,0)); d=ImageDraw.Draw(base)
    plate=rgba(ART/"main-menu/logo_plate.png").resize((520,146),Image.Resampling.LANCZOS); base.alpha_composite(plate,(28,28))
    txt(d,(286,83),"SYMBOTS",60,"#F5F7FA",True,"mm",2); txt(d,(286,128),"FORGE  •  FIGHT  •  EVOLVE",14,COL["cyan"],False,"mm")
    labels=["NEW GAME","SETTINGS"] if first else ["CONTINUE","NEW GAME","SETTINGS","QUIT"]
    y=210
    for i,label in enumerate(labels):
        kind="primary" if i==0 else "generic"; w=300 if kind=="primary" else 260; h=64 if kind=="primary" else 56
        button(base,(64,y,w,h),label,kind,"normal",23); y+=70
    txt(d,(28,574),"v0.1.0  •  PROTOTYPE BUILD",11,COL["muted"])
    if modal:
        base.alpha_composite(Image.new("RGBA",(W,H),(3,7,12,180)),(0,0)); panel(base,(272,158,752,438),(26,32,41,250),COL["blue"],16,3); d=ImageDraw.Draw(base)
        txt(d,(512,205),"START A NEW GAME?",32,heading=True,anchor="mm")
        txt(d,(512,258),"Your current run will be overwritten.",15,COL["muted"],anchor="mm")
        txt(d,(512,286),"This cannot be undone.",13,COL["red"],anchor="mm")
        button(base,(312,338,184,56),"CANCEL","generic","normal",19); button(base,(528,338,184,56),"OVERWRITE","primary","normal",19)
    return base


def overworld(worldmap=False):
    base=rgba(ART/"overworld/map_background.png"); header(base,"WORLD MAP" if worldmap else "OVERWORLD", "Explore, salvage, and choose your encounters")
    d=ImageDraw.Draw(base)
    # Route line and encounter nodes
    route=[(147,430),(290,360),(468,390),(610,288),(760,330),(875,218)]
    d.line(route,fill=(232,184,32,190),width=5,joint="curve")
    names=["SCRAP FIELDS","MOSS WORKS","IRON PASS","ARC MARSH","FORGE RIDGE","STORM CRADLE"]
    enemies=["enemy_rustcrawler_battle.png","enemy_scrapjaw_skirmisher_battle.png","enemy_husk_walker_battle.png","enemy_ironclad_sentry_battle.png","enemy_slag_hauler_battle.png","enemy_storm_warden_battle.png"]
    for i,(x,y) in enumerate(route):
        d.ellipse((x-17,y-17,x+17,y+17),fill=(23,29,38,235),outline=COL["gold"],width=3)
        if worldmap:
            txt(d,(x,y+29),names[i],12,heading=True,anchor="ma",stroke=1)
            paste_fit(base,ART/"enemies"/enemies[i],(x-42,y-92,84,84))
    if not worldmap:
        # First frame of mechanic spritesheet (64x96)
        sheet=rgba(ART/"characters/char_mechanic_fem_overworld_walk.png"); frame=sheet.crop((0,0,64,96)).resize((72,108),Image.Resampling.NEAREST)
        base.alpha_composite(frame,(430,330)); paste_fit(base,ART/"enemies/enemy_rustcrawler_battle.png",(715,280,112,112))
        txt(d,(468,456),"YOU",13,COL["cyan"],True,"mm",1); txt(d,(770,396),"ENCOUNTER",12,COL["amber"],True,"mm",1)
    panel(base,(20,490,1004,580),(22,28,36,236),COL["edge"],10,2)
    txt(d,(42,514),"OBJECTIVE",14,COL["muted"],True); txt(d,(42,540),"Reach Storm Cradle  •  Encounters cleared  6 / 10",19,heading=True)
    button(base,(790,505,188,56),"WORKSHOP","generic","normal",18)
    return base


def battle(salvage=False):
    base=rgba(ART/"battle/battle_arena_background.png"); header(base,"BATTLE", "Target break regions, manage Energy and Heat")
    bot=compose_bot(330); base.alpha_composite(bot,(120,160)); paste_fit(base,ART/"enemies/enemy_ironclad_sentry_battle.png",(650,170,300,300))
    d=ImageDraw.Draw(base)
    panel(base,(28,82,364,154),(22,28,36,232),COL["blue"],10,2); txt(d,(45,98),"YOUR SYMBOT",17,heading=True); txt(d,(45,125),"STRUCTURE",11,COL["muted"])
    d.rectangle((139,126,337,140),fill="#141A22",outline=COL["edge"]); d.rectangle((141,128,310,138),fill=COL["green"]); txt(d,(334,125),"860 / 1000",10,anchor="ra")
    panel(base,(660,82,996,154),(22,28,36,232),COL["red"],10,2); txt(d,(677,98),"IRONCLAD SENTRY",17,heading=True); txt(d,(677,125),"STRUCTURE",11,COL["muted"])
    d.rectangle((771,126,969,140),fill="#141A22",outline=COL["edge"]); d.rectangle((773,128,906,138),fill=COL["red"]); txt(d,(966,125),"1240 / 1800",10,anchor="ra")
    panel(base,(235,486,789,584),(22,28,36,242),COL["edge"],10,2)
    txt(d,(256,504),"ENERGY",11,COL["muted"]); d.rectangle((324,505,515,519),fill="#141A22"); d.rectangle((326,507,451,517),fill=COL["blue"])
    txt(d,(548,504),"HEAT",11,COL["muted"]); d.rectangle((600,505,761,519),fill="#141A22"); d.rectangle((602,507,690,517),fill=COL["amber"])
    for i,label in enumerate(["ARM","HEAD","CORE"]): button(base,(245+i*112,532,104,42),label,"target","selected" if i==0 else "normal",15)
    button(base,(600,528,168,48),"ATTACK","primary","normal",19)
    if salvage:
        base.alpha_composite(Image.new("RGBA",(W,H),(3,7,12,175)),(0,0)); panel(base,(230,110,794,510),(25,32,41,250),COL["gold"],16,3); d=ImageDraw.Draw(base)
        txt(d,(512,154),"SALVAGE",40,COL["gold"],True,"mm",2); txt(d,(512,192),"Target destroyed — choose one recovered item",13,COL["muted"],anchor="mm")
        cards=[("scrapjaw_rustcrawler_claw.png","RUSTCRAWLER CLAW"),("icon_consumable_power_cell.png","POWER CELL"),("icon_consumable_weld_patch.png","WELD PATCH")]
        for i,(name,label) in enumerate(cards):
            x=272+i*168; panel(base,(x,225,x+144,388),(28,35,44,245),COL["ochre"],8,2)
            path=(ART/"parts"/name) if "consumable" not in name else (ART/"consumables"/name)
            paste_fit(base,path,(x+16,236,112,112)); txt(d,(x+72,362),label,11,heading=True,anchor="mm")
        button(base,(384,422,256,64),"CONTINUE","primary","normal",22)
    return base


def workshop(selected=False):
    base=rgba(ART/"workshop/bench_backdrop.png"); header(base,"WORKSHOP — EQUIP HARVESTED PARTS", "Build a Symbot from compatible modular assemblies")
    d=ImageDraw.Draw(base); panel(base,(18,82,232,574),(22,28,36,238),COL["edge"],10,2); panel(base,(246,82,666,574),(18,24,31,190),COL["blue"],12,2); panel(base,(680,82,1006,574),(22,28,36,238),COL["edge"],10,2)
    txt(d,(36,99),"SLOTS",22,heading=True); txt(d,(698,99),"AVAILABLE PARTS",22,heading=True)
    slot_names=["HEAD","CHASSIS","ARM L","ARM R","LEGS","WEAPON","CORE","CHIPSET"]
    icons=["slot_head.png","slot_chassis.png","slot_arm_l.png","slot_arm_r.png","slot_legs.png","slot_weapon.png","slot_core.png","slot_chipset.png"]
    for i,(lab,ic) in enumerate(zip(slot_names,icons)):
        y=132+i*51; paste_fit(base,ART/"icons"/ic,(34,y,40,40)); txt(d,(82,y+20),lab,13,heading=True,anchor="lm")
        if selected and i==1: d.line((30,y-3,214,y-3),fill=COL["blue"],width=2); d.line((30,y+43,214,y+43),fill=COL["blue"],width=2)
    bot=compose_bot(390); base.alpha_composite(bot,(260,130)); txt(d,(456,500),"MK-I FIELD BUILD",20,heading=True,anchor="mm")
    parts=["ironclad_aegis_frame.png","wild_optic_sensor.png","wild_tread_legs.png","scrapjaw_servo_arm.png","boltwell_arc_blaster.png","boltwell_surge_core.png"]
    for i,name in enumerate(parts):
        x=700+(i%3)*96; y=132+(i//3)*110; panel(base,(x,y,x+82,y+92),(28,35,44,245),COL["ochre"] if selected and i==0 else COL["edge"],7,2)
        paste_fit(base,ART/"parts"/name,(x+5,y+3,72,72)); txt(d,(x+41,y+81),"EQUIPPED" if selected and i==0 else "PART",9,COL["gold"] if selected and i==0 else COL["muted"],True,"mm")
    txt(d,(700,370),"STATS",18,heading=True)
    stats=[("STRUCTURE","860"),("ARMOR","42"),("ENERGY","100"),("HEAT LIMIT","120")]
    for i,(k,v) in enumerate(stats): txt(d,(700,404+i*27),k,11,COL["muted"]); txt(d,(968,404+i*27),v,13,heading=True,anchor="ra")
    button(base,(726,510,236,48),"EQUIP" if selected else "SELECT A PART","primary", "normal" if selected else "disabled",18)
    button(base,(850,12,144,44),"CLOSE  ✕","generic","normal",16)
    return base


def pause_screen():
    base=overworld(False); base.alpha_composite(Image.new("RGBA",(W,H),(3,7,12,180)),(0,0)); panel(base,(330,76,694,528),(25,32,41,250),COL["blue"],16,3); d=ImageDraw.Draw(base)
    txt(d,(512,126),"PAUSED",42,heading=True,anchor="mm",stroke=2)
    for i,label in enumerate(["RESUME","WORKSHOP","SETTINGS","MAIN MENU"]): button(base,(384,182+i*73,256,64 if i==0 else 56),label,"primary" if i==0 else "generic","normal",21)
    return base


def settings_screen():
    base=rgba(ART/"main-menu/background.png"); base=ImageEnhance.Brightness(base).enhance(.38); header(base,"SETTINGS", "Audio, display, controls, and accessibility")
    panel(base,(120,88,904,560),(24,31,40,247),COL["blue"],14,3); d=ImageDraw.Draw(base)
    tabs=["AUDIO","DISPLAY","CONTROLS","ACCESSIBILITY"]
    for i,t in enumerate(tabs): button(base,(150+i*181,108,168,46),t,"target","selected" if i==0 else "normal",14)
    rows=[("MASTER VOLUME",.82),("MUSIC",.70),("SFX",.90),("UI SOUNDS",.65)]
    for i,(lab,val) in enumerate(rows):
        y=193+i*61; txt(d,(168,y),lab,16,heading=True); d.rectangle((400,y+2,770,y+16),fill="#121820",outline=COL["edge"]); d.rectangle((402,y+4,402+int(366*val),y+14),fill=COL["blue"]); d.polygon(chamfer_points((786,y-8,848,y+30),7),fill=COL["panel"],outline=COL["edge"]); txt(d,(817,y+11),f"{int(val*100)}",13,heading=True,anchor="mm")
    txt(d,(168,455),"MUTE WHEN UNFOCUSED",16,heading=True); button(base,(645,442,192,48),"ON","target","selected",16)
    button(base,(510,505,160,44),"CANCEL","generic","normal",16); button(base,(690,501,160,48),"APPLY","primary","normal",17)
    return base


screens={
    "main-menu-returning.png":main_menu(), "main-menu-first-launch.png":main_menu(True),
    "main-menu-overwrite-confirm.png":main_menu(False,True), "overworld.png":overworld(False),
    "world-map.png":overworld(True), "battle-active.png":battle(False), "battle-salvage.png":battle(True),
    "workshop-default.png":workshop(False), "workshop-selected.png":workshop(True),
    "pause.png":pause_screen(), "settings.png":settings_screen(),
}
for name,im in screens.items(): im.convert("RGB").save(OUT/name,quality=95)

# Review contact sheet.
thumbs=[]
for name,im in screens.items():
    t=im.copy(); t.thumbnail((400,234),Image.Resampling.LANCZOS); thumbs.append((name,t))
row_h=270
rows=(len(thumbs)+2)//3
sheet=Image.new("RGB",(1260,rows*row_h),(15,19,25)); sd=ImageDraw.Draw(sheet)
for i,(name,t) in enumerate(thumbs):
    x=15+(i%3)*415; y=12+(i//3)*row_h
    sheet.paste(t.convert("RGB"),(x,y)); sd.text((x,y+238),name,font=font(13),fill=COL["white"])
sheet.save(OUT/"_all-screens-contact-sheet.jpg",quality=92)
print(f"Rendered {len(screens)} screens to {OUT}")
