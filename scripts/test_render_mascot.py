#!/usr/bin/env python3
import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUTPUT_DIR = "/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd"

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

C_BLACK_BG = (10, 10, 10, 255)
C_BLACK_CARD = (18, 18, 18, 255)
C_BLACK_WELL = (24, 24, 24, 255)
C_BLACK_OLED = (0, 0, 0, 255)
C_WHITE = (255, 255, 255, 255)
C_TITANIUM = (142, 142, 142, 255)

def draw_aa_circle(draw, cx, cy, r, outline=None, fill=None, width=1):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)

def draw_morphy_mascot(draw, cx, cy, size=100, mode="normal"):
    """
    Renders the official Morphy Mascot:
    An adorable, sleek Apple-crafted obsidian & titanium droplet companion.
    """
    s = size / 100.0
    
    # 1. Soft Ambient Ground Shadow
    draw.ellipse([cx - 42*s, cy + 38*s, cx + 42*s, cy + 54*s], fill=(0, 0, 0, 160))
    
    # 2. Outer Ambient Specular Aura
    for r_offset in [14, 8, 2]:
        draw_aa_circle(draw, cx, cy, 48*s + r_offset, outline=(255, 255, 255, int(15 / r_offset)))
        
    # 3. Mascot Body: Sleek curved organic droplet squircle
    body_box = [cx - 44*s, cy - 44*s, cx + 44*s, cy + 44*s]
    draw.rounded_rectangle(body_box, radius=int(32*s), fill=(26, 26, 28, 255), outline=(255, 255, 255, 60), width=int(max(1, 2*s)))
    
    # Body top specular highlight (liquid glass sheen)
    draw.ellipse([cx - 30*s, cy - 40*s, cx + 30*s, cy - 18*s], fill=(255, 255, 255, 30))
    
    # 4. Expressions / Eyes
    eye_y = cy - 6*s
    eye_spacing = 18*s
    
    if mode == "normal":
        # Friendly wide curious eyes with specular sparkles
        for side in [-1, 1]:
            ex = cx + side * eye_spacing
            draw.rounded_rectangle([ex - 5*s, eye_y - 9*s, ex + 5*s, eye_y + 9*s], radius=int(5*s), fill=C_WHITE)
            # Sparkle
            draw_aa_circle(draw, ex + 2*s, eye_y - 4*s, int(2.5*s), fill=(255, 255, 255, 220))
            
        # Warm happy smile
        draw.arc([cx - 10*s, cy + 6*s, cx + 10*s, cy + 20*s], start=10, end=170, fill=C_WHITE, width=int(max(1, 2*s)))
        # Rosy cheeks (frosted titanium glow)
        for side in [-1, 1]:
            draw.ellipse([cx + side * 28*s - 5*s, cy + 8*s - 3*s, cx + side * 28*s + 5*s, cy + 8*s + 3*s], fill=(255, 255, 255, 25))
            
    elif mode == "focus":
        # Focused confident squinting eyes
        for side in [-1, 1]:
            ex = cx + side * eye_spacing
            draw.line([(ex - 7*s, eye_y + 2*s), (ex, eye_y - 4*s), (ex + 7*s, eye_y + 2*s)], fill=C_WHITE, width=int(max(1, 3*s)))
        # Determined smile
        draw.line([(cx - 8*s, cy + 12*s), (cx + 8*s, cy + 12*s)], fill=C_WHITE, width=int(max(1, 2*s)))
        
        # Studio Focus Headphones!
        # Headband arc
        draw.arc([cx - 52*s, cy - 58*s, cx + 52*s, cy - 10*s], start=180, end=360, fill=C_WHITE, width=int(max(1, 3*s)))
        # Ear cushions
        for side in [-1, 1]:
            draw.rounded_rectangle([cx + side*48*s - 6*s, cy - 18*s, cx + side*48*s + 6*s, cy + 14*s], radius=int(6*s), fill=(40, 40, 40, 255), outline=C_WHITE, width=int(max(1, 2*s)))
            draw_aa_circle(draw, cx + side*48*s, cy - 2*s, int(3*s), fill=C_WHITE)

    elif mode == "music":
        # Vibing happy singing eyes (curved happy arcs)
        for side in [-1, 1]:
            ex = cx + side * eye_spacing
            draw.arc([ex - 6*s, eye_y - 8*s, ex + 6*s, eye_y + 4*s], start=180, end=360, fill=C_WHITE, width=int(max(1, 3*s)))
        # Cute singing open mouth (O shape)
        draw.ellipse([cx - 6*s, cy + 8*s, cx + 6*s, cy + 20*s], fill=C_WHITE)
        # Musical note floating beside head
        draw.text((cx + 38*s, cy - 42*s), "♫", font=get_font(int(20*s)), fill=C_WHITE)

print("Mascot generator script ready.")
