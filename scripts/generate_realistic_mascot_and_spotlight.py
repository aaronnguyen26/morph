#!/usr/bin/env python3
"""
Morph Apple Dynamic Island — Realistic Scale & Spotlight Search Exploration
Strict Apple Human Interface Guidelines:
- Exact Realistic Size: 640 × 225 pt (2x Retina: 1280 × 450 px), matching user screenshot.
- Morphy Mascot: Adorable Apple-crafted titanium & obsidian companion (not a generic circle).
- Spotlight Island Search Exploration: Hover lengthens into a unified search pill,
  allowing user to search for music/timer/notes and blooming directly into the target tool.
- 100% Pure Neutral Monochrome (#000000, #FFFFFF, #8E8E93). Zero bullet dots.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = "/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd"
OUTPUT_DIR = BASE_DIR

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
C_WHITE_MUTED = (255, 255, 255, 180)
C_WHITE_DIM = (255, 255, 255, 120)
C_WHITE_RIM = (255, 255, 255, 45)
C_WHITE_FAINT = (255, 255, 255, 18)

C_TITANIUM = (142, 142, 142, 255)
C_TITANIUM_MUTED = (142, 142, 142, 160)
C_TITANIUM_BORDER = (142, 142, 142, 50)
C_TITANIUM_FAINT = (142, 142, 142, 22)

def draw_aa_circle(draw, cx, cy, r, outline=None, fill=None, width=1):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)

def draw_keycap(draw, x, y, text, font=None, h=22):
    if font is None:
        font = get_font(10, "mono")
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    w = max(tw + 10, 24)
    draw.rounded_rectangle([x, y, x + w, y + h], radius=5, fill=(35, 35, 35, 255), outline=(255, 255, 255, 50), width=1)
    draw.text((x + (w - tw)//2, y + (h - (bbox[3]-bbox[1]))//2 - 1), text, font=font, fill=C_WHITE)
    return w

def draw_morphy_mascot(draw, cx, cy, size=100, mode="normal"):
    """
    Renders Morphy Mascot:
    An adorable Apple-crafted titanium & obsidian droplet companion with personality.
    """
    s = size / 100.0
    
    # 1. Soft Ambient Ground Shadow
    draw.ellipse([cx - 40*s, cy + 38*s, cx + 40*s, cy + 52*s], fill=(0, 0, 0, 180))
    
    # 2. Outer Ambient Specular Aura
    for r_offset in [14, 8, 2]:
        draw_aa_circle(draw, cx, cy, 48*s + r_offset, outline=(255, 255, 255, int(15 / r_offset)))
        
    # 3. Mascot Body: Sleek curved organic droplet squircle
    body_box = [cx - 44*s, cy - 44*s, cx + 44*s, cy + 44*s]
    draw.rounded_rectangle(body_box, radius=int(32*s), fill=(26, 26, 26, 255), outline=(255, 255, 255, 60), width=int(max(1, 2*s)))
    
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
            draw_aa_circle(draw, ex + 2*s, eye_y - 4*s, int(2.5*s), fill=(255, 255, 255, 220))
            
        # Warm happy smile
        draw.arc([cx - 10*s, cy + 6*s, cx + 10*s, cy + 20*s], start=10, end=170, fill=C_WHITE, width=int(max(1, 2*s)))
        # Rosy cheeks
        for side in [-1, 1]:
            draw.ellipse([cx + side * 28*s - 5*s, cy + 8*s - 3*s, cx + side * 28*s + 5*s, cy + 8*s + 3*s], fill=(255, 255, 255, 25))
            
    elif mode == "focus":
        # Focused confident squinting eyes
        for side in [-1, 1]:
            ex = cx + side * eye_spacing
            draw.line([(ex - 7*s, eye_y + 2*s), (ex, eye_y - 4*s), (ex + 7*s, eye_y + 2*s)], fill=C_WHITE, width=int(max(1, 3*s)))
        draw.line([(cx - 8*s, cy + 12*s), (cx + 8*s, cy + 12*s)], fill=C_WHITE, width=int(max(1, 2*s)))
        
        # Studio Focus Headphones!
        draw.arc([cx - 52*s, cy - 58*s, cx + 52*s, cy - 10*s], start=180, end=360, fill=C_WHITE, width=int(max(1, 3*s)))
        for side in [-1, 1]:
            draw.rounded_rectangle([cx + side*48*s - 6*s, cy - 18*s, cx + side*48*s + 6*s, cy + 14*s], radius=int(6*s), fill=(40, 40, 40, 255), outline=C_WHITE, width=int(max(1, 2*s)))
            draw_aa_circle(draw, cx + side*48*s, cy - 2*s, int(3*s), fill=C_WHITE)

    elif mode == "music":
        # Vibing happy singing eyes
        for side in [-1, 1]:
            ex = cx + side * eye_spacing
            draw.arc([ex - 6*s, eye_y - 8*s, ex + 6*s, eye_y + 4*s], start=180, end=360, fill=C_WHITE, width=int(max(1, 3*s)))
        draw.ellipse([cx - 6*s, cy + 8*s, cx + 6*s, cy + 20*s], fill=C_WHITE)
        draw.text((cx + 38*s, cy - 42*s), "♫", font=get_font(int(20*s)), fill=C_WHITE)

# =========================================================================
# ASSET 1: MORPHY MASCOT SHOWCASE
# =========================================================================
def build_mascot_showcase():
    width = 2400
    height = 1400
    canvas = Image.new("RGBA", (width, height), C_BLACK_BG)
    draw = ImageDraw.Draw(canvas)

    for y in range(height):
        ratio = y / height
        v = int(10 + 4 * (1 - abs(ratio - 0.5) * 2))
        draw.line([(0, y), (width, y)], fill=(v, v, v, 255))

    draw.text((80, 40), "  Morph Design System — Official Mascot Architecture", font=get_font(22, "rounded"), fill=C_TITANIUM)
    draw.text((width - 640, 36), "MORPHY THE AMBIENT COMPANION", font=get_font(28), fill=C_WHITE)
    draw.line([(80, 84), (width - 80, 84)], fill=C_TITANIUM_BORDER, width=1)

    cards = [
        ("1. AMBIENT WELCOME MODE", "Friendly, curious, and breathing gently in idle state. Welcomes Minh and tracks ambient focus momentum.", "normal", "Greeting & Idle"),
        ("2. DEEP WORK FOCUS MODE", "Equipped with studio acoustics headphones and determined focused eyes during active Pomodoro sprint sessions.", "focus", "Pomodoro Active"),
        ("3. NOW PLAYING MUSIC MODE", "Vibing joyfully to audio playback with dynamic musical expression and acoustic soundwave resonance.", "music", "Media Audio")
    ]
    card_w = (width - 160 - 64) // 3
    for i, (title, desc, mode, badge) in enumerate(cards):
        cx = 80 + i * (card_w + 32)
        cy = 130
        draw.rounded_rectangle([cx, cy, cx + card_w, cy + 1180], radius=28, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
        
        draw.text((cx + 32, cy + 32), badge.upper(), font=get_font(12, "mono"), fill=C_TITANIUM)
        draw.text((cx + 32, cy + 60), title, font=get_font(20, "rounded"), fill=C_WHITE)
        
        # Big Morphy Mascot Centerpiece
        mcx = cx + card_w // 2
        mcy = cy + 420
        draw_morphy_mascot(draw, mcx, mcy, size=240, mode=mode)
        
        # Description Card below
        dc_y = cy + 760
        draw.rounded_rectangle([cx + 32, dc_y, cx + card_w - 32, cy + 1140], radius=20, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
        draw.text((cx + 56, dc_y + 32), "INTERACTION & EXPRESSION", font=get_font(11, "mono"), fill=C_TITANIUM)
        
        # Word wrapped description
        words = desc.split()
        lines = []
        cur = ""
        for w in words:
            if len(cur + " " + w) > 34:
                lines.append(cur)
                cur = w
            else:
                cur = cur + " " + w if cur else w
        if cur:
            lines.append(cur)
        for li, ltext in enumerate(lines):
            draw.text((cx + 56, dc_y + 68 + li * 28), ltext, font=get_font(15), fill=C_WHITE)
            
        draw.text((cx + 56, dc_y + 240), "✓ Replaces legacy static circle & 3-dot cluster", font=get_font(13), fill=C_TITANIUM)
        draw.text((cx + 56, dc_y + 274), "✓ Authentic Apple character design & physics", font=get_font(13), fill=C_TITANIUM)

    canvas.save(os.path.join(OUTPUT_DIR, "morphy_mascot_showcase.png"))
    print("Generated morphy_mascot_showcase.png")

# =========================================================================
# ASSET 2: REALISTIC HOME REDESIGN (EXACT 640 × 225 SCALE, RETINA 2X)
# =========================================================================
def build_realistic_home():
    """
    Renders Home at the EXACT realistic size of Morph (640 × 225 pt = 1280 × 450 px)
    matching the user's screenshot, featuring Morphy Mascot in the center!
    """
    w = 1280
    h = 450
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    # 1. Outer Continuous Squircle Container
    draw.rounded_rectangle([4, 4, w - 4, h - 4], radius=48, fill=C_BLACK_OLED, outline=(255, 255, 255, 45), width=2)
    # Specular Top Glint
    draw.line([(50, 6), (w - 50, 6)], fill=(255, 255, 255, 75), width=1)

    # 2. Top Header Bar
    # Left Profile pill
    draw.rounded_rectangle([32, 24, 150, 62], radius=19, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30), width=1)
    draw_aa_circle(draw, 50, 43, 13, fill=(50, 50, 50, 255))
    draw.text((42, 35), "MN", font=get_font(11, "rounded"), fill=C_WHITE)
    draw.text((70, 34), "Minh", font=get_font(14, "rounded"), fill=C_WHITE)
    draw.text((164, 34), "HOME", font=get_font(12, "mono"), fill=C_TITANIUM_MUTED)

    # Center Segmented Tabs Dock
    tabs = ["Home", "Focus Timer", "Music", "Notes", "Calendar", "Profile"]
    tab_x = 240
    nav_y = 24
    for tab in tabs:
        if tab == "Home":
            draw.rounded_rectangle([tab_x, nav_y, tab_x + 90, nav_y + 38], radius=19, fill=C_WHITE)
            draw.text((tab_x + 18, nav_y + 9), tab, font=get_font(14, "rounded"), fill=C_BLACK_OLED)
            tab_x += 98
        else:
            bbox = draw.textbbox((0, 0), tab, font=get_font(13))
            tw = bbox[2] - bbox[0] + 28
            draw.rounded_rectangle([tab_x, nav_y, tab_x + tw, nav_y + 38], radius=19, fill=(24, 24, 24, 255), outline=(255, 255, 255, 20), width=1)
            draw.text((tab_x + 14, nav_y + 10), tab, font=get_font(13), fill=C_TITANIUM)
            tab_x += tw + 8

    # Right Toolbar Buttons
    draw_keycap(draw, w - 170, 28, "⌘K", font=get_font(12, "mono"), h=28)
    draw_aa_circle(draw, w - 100, 42, 16, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30))
    draw.text((w - 106, 33), "☼", font=get_font(14), fill=C_WHITE)
    draw_aa_circle(draw, w - 55, 42, 16, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30))
    draw.text((w - 61, 33), "📌", font=get_font(12), fill=C_WHITE)

    # 3. Main Stage (Symmetrical Apple Glass Layout at Realistic Scale)
    stage_y = 92
    stage_h = 320

    # --- LEFT COLUMN: GLANCE (Date, Meeting Telemetry, Join Pill) ---
    col_w = 330
    draw.text((48, stage_y + 20), "GLANCE", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((48, stage_y + 44), "Saturday, Oct 31", font=get_font(24, "rounded"), fill=C_WHITE)
    draw.text((48, stage_y + 80), "2 meetings today", font=get_font(15), fill=C_TITANIUM)

    # Next Meeting Capsule
    draw.rounded_rectangle([48, stage_y + 116, 48 + 270, stage_y + 176], radius=16, fill=(24, 24, 24, 255), outline=(255, 255, 255, 25), width=1)
    draw.text((64, stage_y + 128), "Design Review in 14m", font=get_font(14, "rounded"), fill=C_WHITE)
    draw.text((64, stage_y + 150), "Virtual Room A   Spatial UX", font=get_font(11), fill=C_TITANIUM)
    draw_keycap(draw, 48 + 270 - 46, stage_y + 132, "⌘6", font=get_font(10, "mono"), h=24)

    # --- CENTER COLUMN: MORPHY MASCOT CENTERPIECE ---
    cx = w // 2
    cy = stage_y + 90
    draw_morphy_mascot(draw, cx, cy, size=115, mode="normal")
    draw.text((cx - 104, stage_y + 172), "Good evening, Minh", font=get_font(20, "rounded"), fill=C_WHITE)
    
    # Tactile Status Capsule
    draw.rounded_rectangle([cx - 90, stage_y + 208, cx + 90, stage_y + 242], radius=17, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((cx - 68, stage_y + 217), "Ready for Focus", font=get_font(12, "mono"), fill=C_TITANIUM)

    # --- RIGHT COLUMN: LAUNCH COCKPIT (3 Frosted Action Capsules) ---
    rx = w - col_w - 48
    draw.text((rx, stage_y + 20), "LAUNCH", font=get_font(11, "mono"), fill=C_TITANIUM)

    actions = [
        ("Focus Session", "04:49 Active", "⌘2"),
        ("YouTube Music", "Play Midnight City", "⌘3"),
        ("Scratchpad", "34w Quick Scratch", "⌘4")
    ]
    for i, (a_title, a_status, a_key) in enumerate(actions):
        ay = stage_y + 50 + i * 54
        draw.rounded_rectangle([rx, ay, rx + col_w, ay + 44], radius=16, fill=(24, 24, 24, 255), outline=(255, 255, 255, 25), width=1)
        draw.text((rx + 18, ay + 12), a_title, font=get_font(14, "rounded"), fill=C_WHITE)
        draw.text((rx + 150, ay + 14), a_status, font=get_font(11, "mono"), fill=C_TITANIUM)
        draw_keycap(draw, rx + col_w - 42, ay + 10, a_key, font=get_font(10, "mono"), h=24)

    canvas.save(os.path.join(OUTPUT_DIR, "morph_realistic_home_redesign.png"))
    print("Generated morph_realistic_home_redesign.png (Exact 640x225 pt scale)")

# =========================================================================
# ASSET 3: SPOTLIGHT ISLAND SEARCH FLOW EXPLORATION
# =========================================================================
def build_spotlight_search_flow():
    """
    Renders the revolutionary Spotlight Island workflow:
    Hover lengthens into search pill -> User searches music/timer/notes -> Blooms directly into target tool!
    """
    width = 2560
    height = 2400
    canvas = Image.new("RGBA", (width, height), C_BLACK_BG)
    draw = ImageDraw.Draw(canvas)

    for y in range(height):
        ratio = y / height
        v = int(10 + 4 * (1 - abs(ratio - 0.5) * 2))
        draw.line([(0, y), (width, y)], fill=(v, v, v, 255))

    draw.text((80, 48), "  Apple Dynamic Island Paradigm — Interaction Exploration", font=get_font(24, "rounded"), fill=C_TITANIUM)
    draw.text((width - 920, 44), "THE SPOTLIGHT ISLAND INTERACTION FLOW", font=get_font(30), fill=C_WHITE)
    draw.line([(80, 96), (width - 80, 96)], fill=C_TITANIUM_BORDER, width=1)

    steps = [
        ("STAGE 1: IDLE RESTING DYNAMIC ISLAND", "Compact 210 × 36 pt capsule floating 14pt beneath notch. 100% click-through passthrough. Whisper-thin hairline, zero occlusion.", 130, 360),
        ("STAGE 2: HOVER LENGTHENS INTO SPOTLIGHT SEARCH PILL", "On cursor hover, instead of dropping down the big heavy UI, it smoothly lengthens horizontally into a unified Spotlight search pill (540 × 40 pt).", 530, 460),
        ("STAGE 3: IN-PILL SEARCH & PREDICTIVE COMPLETION", "User types directly in the lengthened pill (e.g. 'music', 'Midnight City', '25m timer'). Shows instant smart chips without opening full window.", 1030, 460),
        ("STAGE 4: SELECTION BLOOMS INTO CONTEXTUAL BIGGEST UI", "Pressing Return or selecting an item smoothly blooms the island downward into the realistic 640 × 225 pt interface specifically for that task!", 1530, 780)
    ]

    for s_title, s_desc, sy, sh in steps:
        draw.rounded_rectangle([80, sy, width - 80, sy + sh], radius=24, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
        draw.text((116, sy + 28), s_title, font=get_font(20, "rounded"), fill=C_WHITE)
        draw.text((116, sy + 58), s_desc, font=get_font(15), fill=C_TITANIUM)

    # --- Render Stage 1 Visual: Compact Resting Pill ---
    p1_w = 420
    p1_h = 72
    p1_x = (width - p1_w) // 2
    p1_y = 230
    draw.rounded_rectangle([p1_x, p1_y, p1_x + p1_w, p1_y + p1_h], radius=p1_h//2, fill=None, outline=(255, 255, 255, 45), width=1)
    draw.text((p1_x + 40, p1_y + 26), "Whisper Hairline (0.75pt)   100% Click-Through", font=get_font(13, "mono"), fill=C_TITANIUM)

    # --- Render Stage 2 Visual: Lengthened Search Pill ---
    p2_w = 1100
    p2_h = 80
    p2_x = (width - p2_w) // 2
    p2_y = 660
    draw.rounded_rectangle([p2_x - 3, p2_y - 2, p2_x + p2_w + 3, p2_y + p2_h + 4], radius=42, fill=(0, 0, 0, 200))
    draw.rounded_rectangle([p2_x, p2_y, p2_x + p2_w, p2_y + p2_h], radius=40, fill=C_BLACK_OLED, outline=(255, 255, 255, 50), width=1)
    
    # Morphy mascot mini glyph on left
    draw_morphy_mascot(draw, p2_x + 50, p2_y + 40, size=52, mode="normal")
    draw.line([(p2_x + 84, p2_y + 20), (p2_x + 84, p2_y + 60)], fill=(255, 255, 255, 25), width=1)
    
    # Search input prompt
    draw.text((p2_x + 104, p2_y + 26), "􀊫 Search music, focus timer, notes, calendar...", font=get_font(18), fill=C_TITANIUM)
    draw.line([(p2_x + 550, p2_y + 26), (p2_x + 550, p2_y + 54)], fill=C_WHITE, width=2) # Blinking caret
    
    # Quick action chip badges
    chips = [("♫ Music", "⌘3"), ("⏱ Focus", "⌘2"), ("✎ Note", "⌘4")]
    cx = p2_x + p2_w - 380
    for clabel, ckey in chips:
        draw.rounded_rectangle([cx, p2_y + 22, cx + 110, p2_y + 58], radius=18, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30), width=1)
        draw.text((cx + 14, p2_y + 31), clabel, font=get_font(12, "rounded"), fill=C_WHITE)
        draw_keycap(draw, cx + 76, p2_y + 28, ckey, font=get_font(10, "mono"), h=22)
        cx += 120

    # --- Render Stage 3 Visual: In-Pill Search & Predictive Completion ---
    p3_w = 1100
    p3_h = 80
    p3_x = (width - p3_w) // 2
    p3_y = 1160
    draw.rounded_rectangle([p3_x - 3, p3_y - 2, p3_x + p3_w + 3, p3_y + p3_h + 4], radius=42, fill=(0, 0, 0, 200))
    draw.rounded_rectangle([p3_x, p3_y, p3_x + p3_w, p3_y + p3_h], radius=40, fill=C_BLACK_OLED, outline=(255, 255, 255, 50), width=1)
    
    # Morphy mascot mini in music mode
    draw_morphy_mascot(draw, p3_x + 50, p3_y + 40, size=52, mode="music")
    draw.line([(p3_x + 84, p3_y + 20), (p3_x + 84, p3_y + 60)], fill=(255, 255, 255, 25), width=1)
    
    # User query typed: "midnight city"
    draw.text((p3_x + 104, p3_y + 26), "midnight city", font=get_font(20, "rounded"), fill=C_WHITE)
    draw.text((p3_x + 236, p3_y + 28), "— M83 (YouTube Music Playback)", font=get_font(16), fill=C_TITANIUM)
    
    # Press Enter to open biggest UI
    draw.rounded_rectangle([p3_x + p3_w - 280, p3_y + 18, p3_x + p3_w - 24, p3_y + 62], radius=22, fill=C_WHITE)
    draw.text((p3_x + p3_w - 260, p3_y + 28), "↵ Open Player UI", font=get_font(14, "rounded"), fill=C_BLACK_OLED)

    # --- Render Stage 4 Visual: Realistic Biggest UI (Music Player at 640x225 pt scale) ---
    p4_w = 1280
    p4_h = 450
    p4_x = (width - p4_w) // 2
    p4_y = 1660
    
    draw.rounded_rectangle([p4_x, p4_y, p4_x + p4_w, p4_y + p4_h], radius=48, fill=C_BLACK_OLED, outline=(255, 255, 255, 45), width=2)
    draw.line([(p4_x + 50, p4_y + 4), (p4_x + p4_w - 50, p4_y + 4)], fill=(255, 255, 255, 75), width=1)
    
    # Top Bar of Contextual Player (No static tabs needed! Direct tool controls)
    draw.text((p4_x + 40, p4_y + 28), "NOW PLAYING STUDIO", font=get_font(12, "mono"), fill=C_TITANIUM)
    draw.text((p4_x + 210, p4_y + 26), "M83 — Hurry Up, We're Dreaming", font=get_font(15, "rounded"), fill=C_WHITE)
    draw_keycap(draw, p4_x + p4_w - 180, p4_y + 24, "⎋ Collapse", font=get_font(11, "mono"), h=26)
    draw_keycap(draw, p4_x + p4_w - 70, p4_y + 24, "⌘3", font=get_font(11, "mono"), h=26)

    # Left: Album Art & Lossless
    art_x = p4_x + 40
    art_y = p4_y + 80
    draw.rounded_rectangle([art_x, art_y, art_x + 180, art_y + 180], radius=24, fill=(35, 35, 35, 255), outline=(255, 255, 255, 40), width=1)
    draw.text((art_x + 60, art_y + 70), "♫", font=get_font(42), fill=C_WHITE)
    draw.rounded_rectangle([art_x + 12, art_y + 12, art_x + 72, art_y + 34], radius=6, fill=(15, 15, 15, 220))
    draw.text((art_x + 18, art_y + 16), "LOSSLESS", font=get_font(9, "mono"), fill=C_WHITE)

    # Morphy in Music Mode next to art
    draw_morphy_mascot(draw, art_x + 260, art_y + 90, size=95, mode="music")

    # Center/Right: Track Info, Scrubber, Transport
    tx = art_x + 360
    draw.text((tx, art_y + 10), "Midnight City", font=get_font(26, "rounded"), fill=C_WHITE)
    draw.text((tx, art_y + 44), "M83   Electronic   Lossless 24-bit 96kHz", font=get_font(13), fill=C_TITANIUM)
    
    # Scrubber Track
    draw.rounded_rectangle([tx, art_y + 80, p4_x + p4_w - 40, art_y + 88], radius=4, fill=(35, 35, 35, 255))
    draw.rounded_rectangle([tx, art_y + 80, tx + 340, art_y + 88], radius=4, fill=C_WHITE)
    draw_aa_circle(draw, tx + 340, art_y + 84, 7, fill=C_WHITE)
    draw.text((tx, art_y + 98), "2:14", font=get_font(12, "mono"), fill=C_WHITE)
    draw.text((p4_x + p4_w - 80, art_y + 98), "-1:42", font=get_font(12, "mono"), fill=C_TITANIUM)

    # Transport Controls
    t_cx = tx + 240
    t_cy = art_y + 180
    draw_aa_circle(draw, t_cx, t_cy, 30, fill=C_WHITE)
    draw.text((t_cx - 8, t_cy - 14), "❚❚", font=get_font(18), fill=C_BLACK_OLED)
    draw_aa_circle(draw, t_cx - 80, t_cy, 24, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30))
    draw.text((t_cx - 90, t_cy - 10), "⏮", font=get_font(14), fill=C_WHITE)
    draw_aa_circle(draw, t_cx + 80, t_cy, 24, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30))
    draw.text((t_cx + 70, t_cy - 10), "⏭", font=get_font(14), fill=C_WHITE)

    # Volume & AirPlay
    draw.text((tx + 440, t_cy - 10), "🔈", font=get_font(14), fill=C_TITANIUM)
    draw.rounded_rectangle([tx + 470, t_cy - 4, p4_x + p4_w - 40, t_cy + 2], radius=3, fill=(35, 35, 35, 255))
    draw.rounded_rectangle([tx + 470, t_cy - 4, tx + 560, t_cy + 2], radius=3, fill=C_WHITE)

    # Bottom status
    draw.line([(p4_x + 30, p4_y + p4_h - 40), (p4_x + p4_w - 30, p4_y + p4_h - 40)], fill=(255, 255, 255, 18), width=1)
    draw.text((p4_x + 40, p4_y + p4_h - 26), "EXACT REALISTIC SIZE: 640 × 225 PT", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)
    draw.text((p4_x + (p4_w - 440)//2, p4_y + p4_h - 26), "Opened directly via Spotlight Search without static tab bar clutter", font=get_font(11), fill=C_WHITE)
    draw.text((p4_x + p4_w - 200, p4_y + p4_h - 26), "AirPods Max Connected", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)

    canvas.save(os.path.join(OUTPUT_DIR, "morph_spotlight_island_flow.png"))
    print("Generated morph_spotlight_island_flow.png")

if __name__ == "__main__":
    build_mascot_showcase()
    build_realistic_home()
    build_spotlight_search_flow()
    print("All realistic assets generated successfully!")
