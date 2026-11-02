#!/usr/bin/env python3
import os
import math
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = "/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd"
OUTPUT_DIR = os.path.join(BASE_DIR, "current_ui")
os.makedirs(OUTPUT_DIR, exist_ok=True)

FONT_MAIN = "/System/Library/Fonts/SFNS.ttf"
FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
FONT_MONO = "/System/Library/Fonts/SFNSMono.ttf"

def get_font(size, kind="main"):
    p = FONT_MAIN
    if kind == "rounded" and os.path.exists(FONT_ROUNDED):
        p = FONT_ROUNDED
    elif kind == "mono" and os.path.exists(FONT_MONO):
        p = FONT_MONO
    try:
        return ImageFont.truetype(p, size)
    except Exception:
        return ImageFont.load_default()

# Monochrome Apple Liquid Glass Palette
C_BG = (12, 12, 14, 255)
C_CARD_SURFACE = (18, 18, 22, 240)
C_WELL_BG = (26, 26, 30, 255)
C_WHITE = (255, 255, 255, 255)
C_WHITE_MUTED = (255, 255, 255, 180)
C_WHITE_DIM = (255, 255, 255, 120)
C_WHITE_BORDER = (255, 255, 255, 40)
C_WHITE_PILL_BG = (255, 255, 255, 25)

def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=width)

def render_compact_stage_card():
    # 380 x 125 pt @ 2x scale = 760 x 250 px
    scale = 2
    w = 380 * scale
    h = 125 * scale
    img = Image.new("RGBA", (w + 40, h + 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Shadow
    for i in range(12):
        alpha = int(35 * (1 - i / 12))
        draw_rounded_rect(draw, [20 - i, 20 - i//2, 20 + w + i, 20 + h + i], radius=22 * scale + i, fill=(0, 0, 0, alpha))
        
    # Main Liquid Glass Body
    card_bbox = [20, 20, 20 + w, 20 + h]
    draw_rounded_rect(draw, card_bbox, radius=22 * scale, fill=(18, 18, 20, 250), outline=(255, 255, 255, 55), width=2)
    
    # Top Header: Morphy mascot badge + Brand + Context Telemetry + Right 'X'
    f_brand = get_font(10 * scale, "mono")
    f_badge = get_font(9 * scale, "mono")
    f_x = get_font(11 * scale, "main")
    
    # Mascot Circle
    draw.ellipse([45, 36, 45 + 24 * scale, 36 + 24 * scale], fill=(30, 30, 34, 255), outline=(255, 255, 255, 40), width=1)
    draw.text((45 + 7 * scale, 36 + 4 * scale), "✦", font=get_font(11 * scale), fill=C_WHITE)
    
    draw.text((45 + 32 * scale, 36 + 5 * scale), "MORPH", font=f_brand, fill=C_WHITE_MUTED)
    
    # Status Badge
    badge_text = "READY FOR FOCUS"
    draw_rounded_rect(draw, [w - 220 * scale, 36 + 2 * scale, w - 80 * scale, 36 + 22 * scale], radius=10 * scale, fill=(255, 255, 255, 22), outline=(255, 255, 255, 35))
    draw.text((w - 208 * scale, 36 + 5 * scale), badge_text, font=f_badge, fill=C_WHITE_MUTED)
    
    # Right 'X' Button
    draw.ellipse([w - 60 * scale + 20, 36 + 1 * scale, w - 38 * scale + 20, 36 + 23 * scale], fill=(255, 255, 255, 30), outline=(255, 255, 255, 45))
    draw.text((w - 53 * scale + 20, 36 + 3 * scale), "✕", font=f_x, fill=C_WHITE)
    
    # Center Stage: Ambient Greeting & Context
    f_greeting = get_font(16 * scale, "rounded")
    f_sub = get_font(10 * scale, "main")
    draw.text((w // 2 - 80 * scale + 20, 85), "Good evening, Minh", font=f_greeting, fill=C_WHITE)
    draw.text((w // 2 - 68 * scale + 20, 125), "MacBook Pro • Schedule Clear", font=f_sub, fill=C_WHITE_DIM)
    
    # Bottom Row: Action Capsules
    # Primary: Start 25m Focus
    draw_rounded_rect(draw, [45, 175, 45 + 170 * scale, 175 + 30 * scale], radius=15 * scale, fill=C_WHITE)
    draw.text((45 + 18 * scale, 175 + 6 * scale), "🔥 Start 25m Focus", font=get_font(12 * scale, "rounded"), fill=(0, 0, 0, 255))
    
    # Secondary: Music
    draw_rounded_rect(draw, [45 + 182 * scale, 175, 45 + 260 * scale, 175 + 30 * scale], radius=15 * scale, fill=(255, 255, 255, 25), outline=(255, 255, 255, 35))
    draw.text((45 + 196 * scale, 175 + 6 * scale), "🎵 Music", font=get_font(11 * scale, "rounded"), fill=C_WHITE)
    
    # Tertiary: Notes
    draw_rounded_rect(draw, [45 + 272 * scale, 175, 45 + 348 * scale, 175 + 30 * scale], radius=15 * scale, fill=(255, 255, 255, 25), outline=(255, 255, 255, 35))
    draw.text((45 + 286 * scale, 175 + 6 * scale), "📝 Notes", font=get_font(11 * scale, "rounded"), fill=C_WHITE)
    
    out_path = os.path.join(OUTPUT_DIR, "compact_staging_view_prompt10.png")
    img.save(out_path, "PNG")
    print(f"Saved: {out_path}")
    return out_path

def render_spotlight_pill_card():
    # 510 x 38 pt @ 2x scale = 1020 x 76 px
    scale = 2
    w = 510 * scale
    h = 38 * scale
    img = Image.new("RGBA", (w + 40, h + 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    for i in range(8):
        alpha = int(30 * (1 - i / 8))
        draw_rounded_rect(draw, [20 - i, 20 - i//2, 20 + w + i, 20 + h + i], radius=19 * scale + i, fill=(0, 0, 0, alpha))
        
    card_bbox = [20, 20, 20 + w, 20 + h]
    draw_rounded_rect(draw, card_bbox, radius=19 * scale, fill=(16, 16, 18, 250), outline=(255, 255, 255, 55), width=2)
    
    # Mascot Icon
    draw.ellipse([45, 30, 45 + 24 * scale, 30 + 24 * scale], fill=(30, 30, 34, 255), outline=(255, 255, 255, 40), width=1)
    draw.text((45 + 7 * scale, 30 + 4 * scale), "✦", font=get_font(10 * scale), fill=C_WHITE)
    
    # Glass Magnifier
    draw.text((45 + 32 * scale, 30 + 5 * scale), "🔍", font=get_font(11 * scale), fill=C_WHITE_MUTED)
    
    # Text Field
    draw.text((45 + 56 * scale, 30 + 4 * scale), "Search, focus, plan, or ask Morph...", font=get_font(12 * scale, "rounded"), fill=C_WHITE_DIM)
    
    # Right 'X' Button
    draw.ellipse([w - 30 * scale + 20, 30 + 1 * scale, w - 8 * scale + 20, 30 + 23 * scale], fill=(255, 255, 255, 30), outline=(255, 255, 255, 45))
    draw.text((w - 23 * scale + 20, 30 + 3 * scale), "✕", font=get_font(10 * scale, "main"), fill=C_WHITE)
    
    out_path = os.path.join(OUTPUT_DIR, "lengthened_spotlight_pill_prompt10.png")
    img.save(out_path, "PNG")
    print(f"Saved: {out_path}")
    return out_path

if __name__ == "__main__":
    p1 = render_compact_stage_card()
    p2 = render_spotlight_pill_card()
    print("Verification boards generated successfully.")
