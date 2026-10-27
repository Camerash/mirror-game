"""Compose every style board into one canvas. Usage: canvas.py scratch_dir out.jpg"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
S, out = sys.argv[1], sys.argv[2]
cells = [
    ("Ceramic dawn", f"{S}/boards/board_ceramic.png", "Round 1"),
    ("Paper and ink", f"{S}/boards/board_ink.png", "Round 1"),
    ("Sunlit terracotta", f"{S}/boards/board_terracotta.png", "Round 1"),
    ("Twilight lanterns", f"{S}/boards/board_twilight.png", "Round 1"),
    ("Papercraft", f"{S}/boards2/board_papercraft.png", "Round 2"),
    ("Clay miniature", f"{S}/boards2/board_clay.png", "Round 2"),
    ("Risograph print", f"{S}/boards2/board_risograph.png", "Round 2"),
    ("Overgrown garden", f"{S}/boards2/board_garden.png", "Round 2"),
    ("Winter town", f"{S}/boards2/board_winter.png", "Round 2"),
    ("Wooden toy blocks", f"{S}/boards2/board_toy.png", "Round 2"),
    ("Ligne claire comic", f"{S}/boards2/board_ligne_claire.png", "Round 2"),
    ("Tide pool and sea glass", f"{S}/boards2/board_tidepool.png", "Round 2"),
    ("Grey box (the start)", f"{S}/look/greybox_hero.png", "Reference"),
    ("Ceramic in engine", f"{S}/look/ceramic_hero.png", "Built in Godot"),
    ("Ink in engine", f"{S}/look/ink_hero.png", "Built in Godot"),
    ("Twilight in engine", f"{S}/look/twilight_hero.png", "Built in Godot"),
]
cols, cw, ch, cap, head = 4, 960, 540, 54, 90
rows = (len(cells) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cw, head + rows * (ch + cap)), (236, 231, 222))
draw = ImageDraw.Draw(sheet)
title = ImageFont.load_default(size=44)
font = ImageFont.load_default(size=28)
small = ImageFont.load_default(size=22)
draw.text((24, 22), "Mirror: style concepts, one diorama", fill=(40, 36, 46), font=title)
missing = 0
for index, (name, path, tag) in enumerate(cells):
    x, y = (index % cols) * cw, head + (index // cols) * (ch + cap)
    if os.path.exists(path):
        img = Image.open(path).convert("RGB")
        w, h = img.size
        if w / h > 16 / 9:
            nw = int(h * 16 / 9); img = img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
        else:
            nh = int(w * 9 / 16); img = img.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
        sheet.paste(img.resize((cw - 12, ch - 12), Image.LANCZOS), (x + 6, y + 6))
    else:
        missing += 1
        draw.rectangle((x + 6, y + 6, x + cw - 6, y + ch - 6), fill=(214, 208, 200))
        draw.text((x + 40, y + ch // 2 - 14), "not generated yet", fill=(110, 104, 112), font=font)
    draw.text((x + 16, y + ch + 6), name, fill=(40, 36, 46), font=font)
    draw.text((x + cw - 16 - draw.textlength(tag, font=small), y + ch + 12), tag, fill=(120, 112, 120), font=small)
sheet.save(out, quality=86, optimize=True)
print(out, sheet.size, "missing", missing)
