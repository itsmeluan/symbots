#!/usr/bin/env python3
"""Build two review sheets without changing the standalone game assets."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/"assets/art"; OUT=ART/"mockups"
FONT="/System/Library/Fonts/SFNSMono.ttf"; DIN="/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf"

def f(n,b=False): return ImageFont.truetype(DIN if b else FONT,n)
def load(p): return Image.open(p).convert("RGBA")
def cell(sheet,d,path,x,y,w,h,label,bg="#202833"):
    d.polygon([(x+8,y),(x+w-8,y),(x+w,y+8),(x+w,y+h-8),(x+w-8,y+h),(x+8,y+h),(x,y+h-8),(x,y+8)],fill=bg,outline="#4B5668",width=2)
    im=load(path); im.thumbnail((w-18,h-38),Image.Resampling.LANCZOS); sheet.alpha_composite(im,(x+(w-im.width)//2,y+7+(h-38-im.height)//2))
    d.text((x+w//2,y+h-17),label,font=f(10),fill="#E8E8E8",anchor="mm")

# UI kit review sheet
ui=Image.new("RGBA",(1200,900),"#11171E"); d=ImageDraw.Draw(ui); d.text((30,22),"SYMBOTS — UI KIT",font=f(34,True),fill="#E8E8E8")
btns=sorted((ART/"ui/buttons").glob("*.png"))
for i,p in enumerate(btns): cell(ui,d,p,30+(i%4)*285,80+(i//4)*100,265,86,p.stem.replace("ui_btn_",""))
assets=list(sorted((ART/"ui/hud").glob("*.png")))+list(sorted((ART/"icons").glob("*.png")))+list(sorted((ART/"consumables").glob("*.png")))
start=390
for i,p in enumerate(assets): cell(ui,d,p,30+(i%10)*114,start+(i//10)*104,100,92,p.stem.replace("icon_consumable_","").replace("stat_","").replace("slot_","")[:15])
ui.convert("RGB").save(OUT/"_ui-kit-overview.jpg",quality=92)

# Sprite and modular-art review sheet
sp=Image.new("RGBA",(1400,1200),"#11171E"); d=ImageDraw.Draw(sp); d.text((30,22),"SYMBOTS — SPRITES & MODULAR ASSETS",font=f(34,True),fill="#E8E8E8")
sprites=list(sorted((ART/"enemies").glob("enemy_*_battle.png")))+list(sorted((ART/"parts").glob("part_*.png")))
for i,p in enumerate(sprites): cell(sp,d,p,28+(i%7)*195,76+(i//7)*210,178,194,p.stem.replace("enemy_","").replace("part_","")[:24])
sp.convert("RGB").save(OUT/"_sprite-catalog.jpg",quality=92)
print("Rendered UI and sprite review catalogs")
