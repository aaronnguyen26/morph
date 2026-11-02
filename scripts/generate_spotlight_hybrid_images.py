#!/usr/bin/env python3
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
C_TITANIUM = (142, 142, 142, 255)
C_TITANIUM_MUTED = (142, 142, 142, 160)
C_TITANIUM_BORDER = (142, 142, 142, 50)

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
    s = size / 100.0
    draw.ellipse([cx - 40*s, cy + 38*s, cx + 40*s, cy + 52*s], fill=(0, 0, 0, 180))
    for r_offset in [14, 8, 2]:
        draw_aa_circle(draw, cx, cy, 48*s + r_offset, outline=(255, 255, 255, int(15 / r_offset)))
    body_box = [cx - 44*s, cy - 44*s, cx + 44*s, cy + 44*s]
    draw.rounded_rectangle(body_box, radius=int(32*s), fill=(26, 26, 26, 255), outline=(255, 255, 255, 60), width=int(max(1, 2*s)))
    draw.ellipse([cx - 30*s, cy - 40*s, cx + 30*s, cy - 18*s], fill=(255, 255, 255, 30))
    eye_y = cy - 6*s
    eye_spacing = 18*s

    if mode == "normal":
        for side in [-1, 1]:
            ex = cx + side * eye_spacing
            draw.rounded_rectangle([ex - 5*s, eye_y - 9*s, ex + 5*s, eye_y + 9*s], radius=int(5*s), fill=C_WHITE)
            draw_aa_circle(draw, ex + 2*s, eye_y - 4*s, int(2.5*s), fill=(255, 255, 255, 220))
        draw.arc([cx - 10*s, cy + 6*s, cx + 10*s, cy + 20*s], start=10, end=170, fill=C_WHITE, width=int(max(1, 2*s)))
        for side in [-1, 1]:
            draw.ellipse([cx + side * 28*s - 5*s, cy + 8*s - 3*s, cx + side * 28*s + 5*s, cy + 8*s + 3*s], fill=(255, 255, 255, 25))
    elif mode == "focus":
        for side in [-1, 1]:
            ex = cx + side * eye_spacing
            draw.line([(ex - 7*s, eye_y + 2*s), (ex, eye_y - 4*s), (ex + 7*s, eye_y + 2*s)], fill=C_WHITE, width=int(max(1, 3*s)))
        draw.line([(cx - 8*s, cy + 12*s), (cx + 8*s, cy + 12*s)], fill=C_WHITE, width=int(max(1, 2*s)))
        draw.arc([cx - 52*s, cy - 58*s, cx + 52*s, cy - 10*s], start=180, end=360, fill=C_WHITE, width=int(max(1, 3*s)))
        for side in [-1, 1]:
            draw.rounded_rectangle([cx + side*48*s - 6*s, cy - 18*s, cx + side*48*s + 6*s, cy + 14*s], radius=int(6*s), fill=(40, 40, 40, 255), outline=C_WHITE, width=int(max(1, 2*s)))
            draw_aa_circle(draw, cx + side*48*s, cy - 2*s, int(3*s), fill=C_WHITE)
    elif mode == "music":
        for side in [-1, 1]:
            ex = cx + side * eye_spacing
            draw.arc([ex - 6*s, eye_y - 8*s, ex + 6*s, eye_y + 4*s], start=180, end=360, fill=C_WHITE, width=int(max(1, 3*s)))
        draw.ellipse([cx - 6*s, cy + 8*s, cx + 6*s, cy + 20*s], fill=C_WHITE)
        draw.text((cx + 38*s, cy - 42*s), "♫", font=get_font(int(20*s)), fill=C_WHITE)

def draw_desktop_context(draw, w, h):
    # Desktop dark gradient background
    draw.rectangle([0, 0, w, h], fill=(12, 12, 12, 255))
    
    # macOS Menu Bar (height: 52px @2x)
    draw.rectangle([0, 0, w, 52], fill=(20, 20, 20, 255))
    draw.line([(0, 52), (w, 52)], fill=(255, 255, 255, 30), width=1)
    
    # Menu items
    draw.text((28, 16), "", font=get_font(18), fill=C_WHITE)
    items = ["Workspace", "File", "Edit", "View", "Window", "Help"]
    tx = 64
    for it in items:
        draw.text((tx, 18), it, font=get_font(13, "main"), fill=C_WHITE if it == "Workspace" else C_TITANIUM)
        tx += int(draw.textbbox((0, 0), it, font=get_font(13))[2] + 20)
        
    # Right status bar items
    r_text = "Wi-Fi   Battery 98%   Sat Oct 31 10:42 PM"
    r_bbox = draw.textbbox((0, 0), r_text, font=get_font(12, "mono"))
    draw.text((w - (r_bbox[2] - r_bbox[0]) - 28, 18), r_text, font=get_font(12, "mono"), fill=C_TITANIUM)

    # Simulated Browser Window Tab Bar (height: 64px @2x)
    by = 53
    draw.rectangle([0, by, w, by + 64], fill=(16, 16, 16, 255))
    draw.line([(0, by + 64), (w, by + 64)], fill=(255, 255, 255, 25), width=1)

    # Browser tabs
    tabs = [
        ("GitHub — morph-workspace", True, "⌘1"),
        ("Apple Developer — Dynamic Island", False, "⌘2"),
        ("Linear — Workspace Sprint", False, "⌘3"),
        ("Figma — Morph Design System", False, "⌘4")
    ]
    bx = 24
    for title, is_active, sc in tabs:
        tw = 260
        if is_active:
            draw.rounded_rectangle([bx, by + 12, bx + tw, by + 64], radius=10, fill=(28, 28, 28, 255), outline=(255, 255, 255, 35), width=1)
            draw.text((bx + 14, by + 26), title, font=get_font(12, "rounded"), fill=C_WHITE)
            draw.text((bx + tw - 46, by + 28), sc, font=get_font(10, "mono"), fill=C_TITANIUM)
            draw.text((bx + tw - 20, by + 26), "×", font=get_font(14), fill=C_TITANIUM)
        else:
            draw.rounded_rectangle([bx, by + 16, bx + tw, by + 60], radius=8, fill=(20, 20, 20, 255), outline=(255, 255, 255, 15), width=1)
            draw.text((bx + 14, by + 28), title, font=get_font(12, "rounded"), fill=C_TITANIUM)
            draw.text((bx + tw - 34, by + 30), sc, font=get_font(10, "mono"), fill=(100, 100, 100, 255))
        bx += tw + 8

    # Hardware Display Notch Housing
    nw = 320
    nh = 54
    draw.rounded_rectangle([(w - nw)//2, 0, (w + nw)//2, nh], radius=18, fill=C_BLACK_OLED, outline=(255, 255, 255, 30), width=1)
    draw_aa_circle(draw, w//2 - 20, nh//2 - 2, 7, fill=(20, 20, 20, 255), outline=(255, 255, 255, 30), width=1)
    draw_aa_circle(draw, w//2 + 20, nh//2 - 2, 4, fill=(10, 10, 10, 255))

# ==========================================
# 1. STAGE 1: RESTING STEALTH CAPSULE
# ==========================================
def build_hybrid_stage_01():
    w, h = 1400, 440
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw_desktop_context(draw, w, h)

    # Dynamic Island Capsule: 210 x 36 pt -> 420 x 72 px @2x
    cw, ch = 420, 72
    cx = (w - cw) // 2
    cy = 60 # Directly below notch
    
    # Soft drop shadow
    draw.rounded_rectangle([cx - 4, cy - 2, cx + cw + 4, cy + ch + 8], radius=38, fill=(0, 0, 0, 160))
    # Main squircle
    draw.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=36, fill=C_BLACK_OLED, outline=(255, 255, 255, 50), width=2)
    # Specular rim
    draw.line([(cx + 40, cy + 2), (cx + cw - 40, cy + 2)], fill=(255, 255, 255, 90), width=1)

    # Capsule contents
    # Left: micro mascot
    draw_morphy_mascot(draw, cx + 42, cy + 36, size=32, mode="normal")
    # Brand text & status
    draw.text((cx + 74, cy + 26), "MORPH", font=get_font(13, "mono"), fill=C_WHITE)
    draw.text((cx + 144, cy + 28), "|", font=get_font(12, "mono"), fill=C_TITANIUM)
    draw.text((cx + 162, cy + 27), "Ready", font=get_font(13, "rounded"), fill=C_TITANIUM)
    # Right: shortcut
    draw_keycap(draw, cx + cw - 64, cy + 24, "⌘K", font=get_font(11, "mono"), h=24)

    # Callout Annotations
    # Left Card
    draw.rounded_rectangle([48, 160, 440, 390], radius=16, fill=(20, 20, 20, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((68, 182), "STATE 1 — RESTING STEALTH CAPSULE", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((68, 206), "Exact 210 × 36 pt Compact Footprint", font=get_font(17, "rounded"), fill=C_WHITE)
    details = [
        "100% Click-Through in Idle State",
        "Zero Tab Occlusion: Browser tabs clear underneath",
        "Gentle ambient breathing with Morphy micro-droplet",
        "Ultra-light 0.75pt titanium specular hairline"
    ]
    for i, d in enumerate(details):
        draw.text((68, 248 + i * 30), "—  " + d, font=get_font(12), fill=C_WHITE_MUTED)

    # Right Card
    draw.rounded_rectangle([w - 440, 160, w - 48, 390], radius=16, fill=(20, 20, 20, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((w - 420, 182), "INTENTIONALITY GATEWAY", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((w - 420, 206), "Zero Accidental Triggering", font=get_font(17, "rounded"), fill=C_WHITE)
    details_r = [
        "250ms Hover Dwell separates transit from intent",
        "Casual mouse movement clicks through seamlessly",
        "Intentional hover lengthens horizontally to 540pt",
        "Instant toggle via global ⌘K keyboard shortcut"
    ]
    for i, d in enumerate(details_r):
        draw.text((w - 420, 248 + i * 30), "—  " + d, font=get_font(12), fill=C_WHITE_MUTED)

    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(os.path.join(OUTPUT_DIR, "hybrid_stage_01_resting_capsule.png"))
    print("Generated hybrid_stage_01_resting_capsule.png")

# ==========================================
# 2. STAGE 2: LENGTHENED SPOTLIGHT PILL
# ==========================================
def build_hybrid_stage_02():
    w, h = 1400, 440
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw_desktop_context(draw, w, h)

    # Spotlight Pill: 540 x 40 pt -> 1080 x 80 px @2x
    cw, ch = 1080, 80
    cx = (w - cw) // 2
    cy = 58
    
    # Drop shadow
    draw.rounded_rectangle([cx - 4, cy - 2, cx + cw + 4, cy + ch + 10], radius=42, fill=(0, 0, 0, 180))
    # Main lengthened squircle
    draw.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=40, fill=C_BLACK_OLED, outline=(255, 255, 255, 60), width=2)
    draw.line([(cx + 60, cy + 2), (cx + cw - 60, cy + 2)], fill=(255, 255, 255, 95), width=1)

    # Left: Search field
    draw.text((cx + 28, cy + 26), "🔍", font=get_font(16), fill=C_WHITE)
    draw.text((cx + 64, cy + 28), "music", font=get_font(16, "mono"), fill=C_WHITE)
    # Cursor
    draw.line([(cx + 128, cy + 24), (cx + 128, cy + 54)], fill=C_WHITE, width=2)
    draw.text((cx + 140, cy + 30), "| Type to filter tools or commands...", font=get_font(13, "mono"), fill=C_TITANIUM)

    # Right: Quick Tactile Tool Chips
    chips = [
        ("♫ Music", "⌘1", True),
        ("◷ Timer", "⌘2", False),
        ("✎ Notes", "⌘3", False),
        ("👤 Profile", "⌘4", False)
    ]
    rx = cx + cw - 28
    for label, sc, is_active in reversed(chips):
        bbox = draw.textbbox((0, 0), label, font=get_font(12, "rounded"))
        lw = bbox[2] - bbox[0]
        chip_w = lw + 44
        chip_x = rx - chip_w
        if is_active:
            draw.rounded_rectangle([chip_x, cy + 18, chip_x + chip_w, cy + ch - 18], radius=16, fill=(45, 45, 45, 255), outline=C_WHITE, width=1)
            draw.text((chip_x + 12, cy + 28), label, font=get_font(12, "rounded"), fill=C_WHITE)
            draw_keycap(draw, chip_x + chip_w - 28, cy + 26, sc, font=get_font(9, "mono"), h=18)
        else:
            draw.rounded_rectangle([chip_x, cy + 18, chip_x + chip_w, cy + ch - 18], radius=16, fill=(24, 24, 24, 255), outline=(255, 255, 255, 25), width=1)
            draw.text((chip_x + 12, cy + 28), label, font=get_font(12, "rounded"), fill=C_TITANIUM)
            draw.text((chip_x + chip_w - 24, cy + 29), sc, font=get_font(9, "mono"), fill=C_TITANIUM_MUTED)
        rx -= chip_w + 10

    # Callout Annotations
    # Left Card
    draw.rounded_rectangle([48, 160, 440, 390], radius=16, fill=(20, 20, 20, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((68, 182), "STATE 2 — LENGTHENED SPOTLIGHT PILL", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((68, 206), "Horizontal In-Pill Action Bar", font=get_font(17, "rounded"), fill=C_WHITE)
    details = [
        "Exact 540 × 40 pt dimensioning",
        "Zero Vertical Expansion: Height remains strictly 40pt",
        "Underlying browser tabs remain 100% visible",
        "Direct inline query with instant autocomplete"
    ]
    for i, d in enumerate(details):
        draw.text((68, 248 + i * 30), "—  " + d, font=get_font(12), fill=C_WHITE_MUTED)

    # Right Card
    draw.rounded_rectangle([w - 440, 160, w - 48, 390], radius=16, fill=(20, 20, 20, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((w - 420, 182), "THE HYBRID ADVANTAGE", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((w - 420, 206), "Keyboard Speed + Trackpad Chips", font=get_font(17, "rounded"), fill=C_WHITE)
    details_r = [
        "Type 'm' + Enter for sub-second keyboard launch",
        "Click any tactile chip with trackpad/mouse",
        "Path A: Direct Bloom into target tool UI",
        "Path B: Press Return on empty to open Home"
    ]
    for i, d in enumerate(details_r):
        draw.text((w - 420, 248 + i * 30), "—  " + d, font=get_font(12), fill=C_WHITE_MUTED)

    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(os.path.join(OUTPUT_DIR, "hybrid_stage_02_spotlight_pill.png"))
    print("Generated hybrid_stage_02_spotlight_pill.png")

# ========================================================
# 3. STAGE 3A: PATH A (DIRECT TOOL BLOOM — MUSIC PLAYER)
# ========================================================
def build_hybrid_stage_03a():
    # 640 x 225 pt -> 1280 x 450 px @2x
    w, h = 1280, 450
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    
    # Main squircle
    draw.rounded_rectangle([4, 4, w - 4, h - 4], radius=48, fill=C_BLACK_OLED, outline=(255, 255, 255, 55), width=2)
    draw.line([(60, 6), (w - 60, 6)], fill=(255, 255, 255, 80), width=1)

    # Top Header: Breadcrumb instead of tab bar!
    # Left: Breadcrumb
    draw.rounded_rectangle([32, 22, 330, 64], radius=21, fill=(26, 26, 26, 255), outline=(255, 255, 255, 25), width=1)
    draw_aa_circle(draw, 52, 43, 13, fill=(45, 45, 45, 255))
    draw.text((44, 35), "MN", font=get_font(11, "rounded"), fill=C_WHITE)
    draw.text((74, 34), "Minh", font=get_font(14, "rounded"), fill=C_WHITE)
    draw.text((122, 35), "SPOTLIGHT ➔ MUSIC", font=get_font(12, "mono"), fill=C_TITANIUM)

    # Center: Audio telemetry badge
    draw.rounded_rectangle([w//2 - 130, 26, w//2 + 130, 60], radius=17, fill=(20, 20, 20, 255), outline=(255, 255, 255, 20), width=1)
    draw.text((w//2 - 110, 34), "LOSSLESS AUDIO   SPATIAL 3D", font=get_font(11, "mono"), fill=C_WHITE)

    # Right: Dismiss keycap
    draw_keycap(draw, w - 160, 28, "ESC ⎋ Collapse", font=get_font(11, "mono"), h=28)

    # Content Area (35% more breathing space because NO TAB BAR!)
    sy = 82
    # Left Column: Album Vinyl Art (w: 320px)
    draw.rounded_rectangle([48, sy + 16, 360, sy + 256], radius=22, fill=(22, 22, 22, 255), outline=(255, 255, 255, 30), width=1)
    # Vinyl grooves
    draw_aa_circle(draw, 204, sy + 136, 90, outline=(255, 255, 255, 15), fill=(16, 16, 16, 255), width=2)
    draw_aa_circle(draw, 204, sy + 136, 60, outline=(255, 255, 255, 20), width=1)
    draw_aa_circle(draw, 204, sy + 136, 30, outline=(255, 255, 255, 35), fill=(35, 35, 35, 255), width=1)
    draw.text((194, sy + 126), "♫", font=get_font(20), fill=C_WHITE)

    # Center Column: Track details & Animated Soundwave Visualizer (w: 520px)
    cx = 390
    draw.text((cx, sy + 20), "NOW STREAMING VIA YOUTUBE MUSIC", font=get_font(10, "mono"), fill=C_TITANIUM)
    draw.text((cx, sy + 44), "Midnight City", font=get_font(28, "rounded"), fill=C_WHITE)
    draw.text((cx, sy + 82), "M83   Hurry Up, We're Dreaming (Deluxe Edition)", font=get_font(13), fill=C_TITANIUM)

    # Equalizer wave bars
    bars = [12, 24, 38, 54, 46, 32, 60, 72, 84, 65, 45, 58, 80, 95, 70, 52, 40, 66, 88, 75, 48, 30, 42, 60, 35, 20, 14]
    b_start_x = cx
    b_y_base = sy + 195
    for i, bh in enumerate(bars):
        bx = b_start_x + i * 19
        draw.rounded_rectangle([bx, b_y_base - bh, bx + 11, b_y_base], radius=4, fill=C_WHITE if i%2==0 else (160, 160, 160, 255))

    # Track Scrubber
    draw.text((cx, sy + 218), "02:14", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.rounded_rectangle([cx + 50, sy + 223, cx + 460, sy + 227], radius=2, fill=(40, 40, 40, 255))
    draw.rounded_rectangle([cx + 50, sy + 223, cx + 240, sy + 227], radius=2, fill=C_WHITE)
    draw_aa_circle(draw, cx + 240, sy + 225, 6, fill=C_WHITE)
    draw.text((cx + 474, sy + 218), "-01:49", font=get_font(11, "mono"), fill=C_TITANIUM)

    # Right Column: Big Tactile Controls & Source (w: 300px)
    rx = w - 320
    # Transport pill
    draw.rounded_rectangle([rx, sy + 24, rx + 270, sy + 90], radius=20, fill=(24, 24, 24, 255), outline=(255, 255, 255, 25), width=1)
    draw.text((rx + 36, sy + 44), "⏮", font=get_font(20), fill=C_WHITE)
    draw_aa_circle(draw, rx + 135, sy + 57, 24, fill=C_WHITE)
    draw.text((rx + 128, sy + 44), "⏸", font=get_font(20), fill=C_BLACK_OLED)
    draw.text((rx + 204, sy + 44), "⏭", font=get_font(20), fill=C_WHITE)

    # Volume slider
    draw.rounded_rectangle([rx, sy + 110, rx + 270, sy + 160], radius=16, fill=(20, 20, 20, 255), outline=(255, 255, 255, 18), width=1)
    draw.text((rx + 20, sy + 126), "🔈", font=get_font(14), fill=C_TITANIUM)
    draw.rounded_rectangle([rx + 48, sy + 133, rx + 220, sy + 137], radius=2, fill=(40, 40, 40, 255))
    draw.rounded_rectangle([rx + 48, sy + 133, rx + 180, sy + 137], radius=2, fill=C_WHITE)
    draw.text((rx + 232, sy + 126), "🔊", font=get_font(14), fill=C_WHITE)

    # Up Next Mini Card
    draw.rounded_rectangle([rx, sy + 180, rx + 270, sy + 248], radius=16, fill=(20, 20, 20, 255), outline=(255, 255, 255, 18), width=1)
    draw.text((rx + 18, sy + 194), "UP NEXT", font=get_font(9, "mono"), fill=C_TITANIUM)
    draw.text((rx + 18, sy + 214), "Reunion — M83", font=get_font(12, "rounded"), fill=C_WHITE)

    # Bottom Rail
    draw.line([(30, h - 36), (w - 30, h - 36)], fill=(255, 255, 255, 20), width=1)
    draw.text((48, h - 25), "SPACE: Play/Pause   ⌘→: Next Track   ⌘←: Prev   ⌘↑/↓: Volume", font=get_font(10, "mono"), fill=C_TITANIUM)
    draw.text((w - 380, h - 25), "100% Click-Through in Resting State | Zero Tab Occlusion", font=get_font(10, "mono"), fill=C_WHITE)

    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(os.path.join(OUTPUT_DIR, "hybrid_stage_03a_direct_music_bloom.png"))
    print("Generated hybrid_stage_03a_direct_music_bloom.png")

# ========================================================
# 4. STAGE 3B: PATH B (DEFAULT AMBIENT HOME BLOOM)
# ========================================================
def build_hybrid_stage_03b():
    w, h = 1280, 450
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    
    # Main squircle
    draw.rounded_rectangle([4, 4, w - 4, h - 4], radius=48, fill=C_BLACK_OLED, outline=(255, 255, 255, 55), width=2)
    draw.line([(60, 6), (w - 60, 6)], fill=(255, 255, 255, 80), width=1)

    # Top Header
    draw.rounded_rectangle([32, 22, 330, 64], radius=21, fill=(26, 26, 26, 255), outline=(255, 255, 255, 25), width=1)
    draw_aa_circle(draw, 52, 43, 13, fill=(45, 45, 45, 255))
    draw.text((44, 35), "MN", font=get_font(11, "rounded"), fill=C_WHITE)
    draw.text((74, 34), "Minh", font=get_font(14, "rounded"), fill=C_WHITE)
    draw.text((122, 35), "SPOTLIGHT ➔ HOME", font=get_font(12, "mono"), fill=C_TITANIUM)

    # Integrated search bar at top center
    draw.rounded_rectangle([w//2 - 180, 24, w//2 + 180, 62], radius=19, fill=(20, 20, 20, 255), outline=(255, 255, 255, 25), width=1)
    draw.text((w//2 - 160, 34), "🔍 Type to filter (music, timer, notes...)", font=get_font(11, "mono"), fill=C_TITANIUM)

    # Right: Dismiss keycap
    draw_keycap(draw, w - 160, 28, "ESC ⎋ Collapse", font=get_font(11, "mono"), h=28)

    # Content Area: Left Calendar Glance, Center Morphy Mascot, Right Launch Cockpit
    sy = 82
    
    # Left Deck: Calendar Glance (w: 340px)
    draw.rounded_rectangle([48, sy + 16, 400, sy + 256], radius=20, fill=(20, 20, 20, 255), outline=(255, 255, 255, 22), width=1)
    draw.text((72, sy + 36), "CALENDAR GLANCE", font=get_font(10, "mono"), fill=C_TITANIUM)
    draw.text((72, sy + 60), "Saturday, Oct 31", font=get_font(24, "rounded"), fill=C_WHITE)
    draw.text((72, sy + 96), "3 meetings scheduled today", font=get_font(13), fill=C_TITANIUM)
    
    # Next Event Card
    draw.rounded_rectangle([72, sy + 130, 376, sy + 236], radius=14, fill=(28, 28, 28, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((88, sy + 144), "NEXT EVENT   11:30 AM", font=get_font(9, "mono"), fill=C_WHITE)
    draw.text((88, sy + 166), "Dynamic Island Architecture Review", font=get_font(12, "rounded"), fill=C_WHITE)
    draw.text((88, sy + 192), "Google Meet   Engineering Team", font=get_font(10), fill=C_TITANIUM)
    draw_keycap(draw, 310, sy + 198, "Join ↗", font=get_font(9, "rounded"), h=22)

    # Center Deck: Morphy Mascot Companion (w: 440px)
    cx = w // 2
    draw_morphy_mascot(draw, cx, sy + 106, size=115, mode="normal")
    draw.text((cx - 86, sy + 182), "Good evening, Minh", font=get_font(20, "rounded"), fill=C_WHITE)
    draw.rounded_rectangle([cx - 70, sy + 218, cx + 70, sy + 248], radius=15, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((cx - 56, sy + 226), "Ready for Deep Focus", font=get_font(11, "rounded"), fill=C_WHITE)

    # Right Deck: Launch Cockpit (w: 360px)
    rx = w - 410
    draw.rounded_rectangle([rx, sy + 16, rx + 360, sy + 256], radius=20, fill=(20, 20, 20, 255), outline=(255, 255, 255, 22), width=1)
    draw.text((rx + 24, sy + 36), "QUICK LAUNCH COCKPIT", font=get_font(10, "mono"), fill=C_TITANIUM)

    actions = [
        ("Focus Session", "24:49 Remaining", "⌘1"),
        ("YouTube Music", "Midnight City (M83)", "⌘2"),
        ("Scratchpad", "4 Notes Staged", "⌘3")
    ]
    for i, (title, sub, sc) in enumerate(actions):
        ay = sy + 66 + i * 58
        draw.rounded_rectangle([rx + 20, ay, rx + 340, ay + 48], radius=14, fill=(28, 28, 28, 255), outline=(255, 255, 255, 25), width=1)
        draw.text((rx + 36, ay + 12), title, font=get_font(13, "rounded"), fill=C_WHITE)
        draw.text((rx + 36, ay + 28), sub, font=get_font(10), fill=C_TITANIUM)
        draw_keycap(draw, rx + 296, ay + 13, sc, font=get_font(10, "mono"), h=22)

    # Bottom Rail
    draw.line([(30, h - 36), (w - 30, h - 36)], fill=(255, 255, 255, 20), width=1)
    draw.text((48, h - 25), "ACTIVE WORKSPACE: Minh Architecture   100% Click-Through in Resting State", font=get_font(10, "mono"), fill=C_TITANIUM)
    draw.text((w - 240, h - 25), "Press ESC to Collapse", font=get_font(10, "mono"), fill=C_WHITE)

    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(os.path.join(OUTPUT_DIR, "hybrid_stage_03b_default_home_bloom.png"))
    print("Generated hybrid_stage_03b_default_home_bloom.png")

# ========================================================
# 5. STAGE 3C: PATH A (ALTERNATIVE: DIRECT TIMER BLOOM)
# ========================================================
def build_hybrid_stage_03c():
    w, h = 1280, 450
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    
    # Main squircle
    draw.rounded_rectangle([4, 4, w - 4, h - 4], radius=48, fill=C_BLACK_OLED, outline=(255, 255, 255, 55), width=2)
    draw.line([(60, 6), (w - 60, 6)], fill=(255, 255, 255, 80), width=1)

    # Top Header
    draw.rounded_rectangle([32, 22, 330, 64], radius=21, fill=(26, 26, 26, 255), outline=(255, 255, 255, 25), width=1)
    draw_aa_circle(draw, 52, 43, 13, fill=(45, 45, 45, 255))
    draw.text((44, 35), "MN", font=get_font(11, "rounded"), fill=C_WHITE)
    draw.text((74, 34), "Minh", font=get_font(14, "rounded"), fill=C_WHITE)
    draw.text((122, 35), "SPOTLIGHT ➔ FOCUS TIMER", font=get_font(12, "mono"), fill=C_TITANIUM)

    # Center status
    draw.rounded_rectangle([w//2 - 120, 26, w//2 + 120, 60], radius=17, fill=(20, 20, 20, 255), outline=(255, 255, 255, 20), width=1)
    draw.text((w//2 - 100, 34), "PHASE 1 SPRINT   DEEP WORK", font=get_font(11, "mono"), fill=C_WHITE)

    # Right: Dismiss keycap
    draw_keycap(draw, w - 160, 28, "ESC ⎋ Collapse", font=get_font(11, "mono"), h=28)

    # Content Area
    sy = 82
    # Left: Large Circular Gauge (w: 380px)
    draw.rounded_rectangle([48, sy + 16, 420, sy + 256], radius=20, fill=(20, 20, 20, 255), outline=(255, 255, 255, 22), width=1)
    gcx, gcy = 234, sy + 136
    draw_aa_circle(draw, gcx, gcy, 88, outline=(40, 40, 40, 255), width=10)
    draw.arc([gcx - 88, gcy - 88, gcx + 88, gcy + 88], start=-90, end=190, fill=C_WHITE, width=10)
    draw.text((gcx - 68, gcy - 24), "23:45", font=get_font(34, "mono"), fill=C_WHITE)
    draw.text((gcx - 46, gcy + 18), "25m Sprint", font=get_font(12, "rounded"), fill=C_TITANIUM)

    # Center: Morphy Focus Mode
    cx = w // 2 + 10
    draw_morphy_mascot(draw, cx, sy + 106, size=115, mode="focus")
    draw.text((cx - 64, sy + 186), "Locked in Focus", font=get_font(18, "rounded"), fill=C_WHITE)
    draw.text((cx - 58, sy + 214), "Sprint 1 of 4 Completed", font=get_font(11), fill=C_TITANIUM)

    # Right: Quick presets & streak (w: 380px)
    rx = w - 440
    draw.rounded_rectangle([rx, sy + 16, rx + 390, sy + 256], radius=20, fill=(20, 20, 20, 255), outline=(255, 255, 255, 22), width=1)
    draw.text((rx + 24, sy + 36), "QUICK INTERVAL PRESETS", font=get_font(10, "mono"), fill=C_TITANIUM)
    
    presets = [("15m", "Quick Burst"), ("25m", "Pomodoro Standard"), ("45m", "Deep Sprint"), ("60m", "Extended Flow")]
    for i, (dur, sub) in enumerate(presets):
        py = sy + 64 + i * 44
        is_sel = (dur == "25m")
        draw.rounded_rectangle([rx + 20, py, rx + 370, py + 36], radius=10, fill=(35, 35, 35, 255) if is_sel else (24, 24, 24, 255), outline=C_WHITE if is_sel else (255, 255, 255, 20), width=1)
        draw.text((rx + 34, py + 9), dur, font=get_font(12, "mono"), fill=C_WHITE)
        draw.text((rx + 80, py + 10), sub, font=get_font(11, "rounded"), fill=C_WHITE if is_sel else C_TITANIUM)
        if is_sel:
            draw.text((rx + 330, py + 9), "Active", font=get_font(10, "mono"), fill=C_WHITE)

    # Bottom Rail
    draw.line([(30, h - 36), (w - 30, h - 36)], fill=(255, 255, 255, 20), width=1)
    draw.text((48, h - 25), "SPACE: Start/Pause   ⌘R: Reset Timer   ⌘1-4: Quick Select Duration", font=get_font(10, "mono"), fill=C_TITANIUM)
    draw.text((w - 240, h - 25), "Press ESC to Collapse", font=get_font(10, "mono"), fill=C_WHITE)

    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(os.path.join(OUTPUT_DIR, "hybrid_stage_03c_direct_timer_bloom.png"))
    print("Generated hybrid_stage_03c_direct_timer_bloom.png")

# ========================================================
# 6. MASTER FLOW BOARD: THE SPOTLIGHT HYBRID ARCHITECTURE
# ========================================================
def build_hybrid_master_board():
    w, h = 2560, 2400
    canvas = Image.new("RGBA", (w, h), (10, 10, 10, 255))
    draw = ImageDraw.Draw(canvas)

    # Master Board Header
    draw.text((100, 80), " APPLE DYNAMIC ISLAND ARCHITECTURE", font=get_font(18, "mono"), fill=C_TITANIUM)
    draw.text((100, 116), "The Spotlight-First Hybrid Paradigm", font=get_font(44, "rounded"), fill=C_WHITE)
    draw.text((100, 180), "Unifying In-Pill Search, Instant Tool Blooming, and Ambient Companion Living States — Exact 640 × 225 pt Geometry", font=get_font(20), fill=C_TITANIUM)

    # Paste Stage 1 (Resting)
    im_s1 = Image.open(os.path.join(OUTPUT_DIR, "hybrid_stage_01_resting_capsule.png")).resize((2360, 742))
    canvas.paste(im_s1, (100, 240))

    # Flow Arrow 1
    draw.line([(w//2, 1000), (w//2, 1060)], fill=C_WHITE, width=4)
    draw.polygon([(w//2 - 12, 1060), (w//2 + 12, 1060), (w//2, 1080)], fill=C_WHITE)
    draw.text((w//2 + 24, 1030), "Hover Dwell (250ms) or ⌘K Shortcut", font=get_font(16, "mono"), fill=C_TITANIUM)

    # Paste Stage 2 (Spotlight Pill)
    im_s2 = Image.open(os.path.join(OUTPUT_DIR, "hybrid_stage_02_spotlight_pill.png")).resize((2360, 742))
    canvas.paste(im_s2, (100, 1100))

    # Flow Branching Arrows
    draw.line([(w//2, 1860), (w//2, 1920)], fill=C_WHITE, width=4)
    draw.line([(w//4 + 100, 1920), (3*w//4 - 100, 1920)], fill=C_WHITE, width=4)
    
    # Left Branch Arrow -> Path A Direct Bloom
    draw.line([(w//4 + 100, 1920), (w//4 + 100, 1960)], fill=C_WHITE, width=4)
    draw.polygon([(w//4 + 88, 1960), (w//4 + 112, 1960), (w//4 + 100, 1980)], fill=C_WHITE)
    draw.text((w//4 - 160, 1935), "PATH A: Type 'music' or click [♫ Music] chip", font=get_font(15, "mono"), fill=C_WHITE)

    # Right Branch Arrow -> Path B Default Home Bloom
    draw.line([(3*w//4 - 100, 1920), (3*w//4 - 100, 1960)], fill=C_WHITE, width=4)
    draw.polygon([(3*w//4 - 112, 1960), (3*w//4 - 88, 1960), (3*w//4 - 100, 1980)], fill=C_WHITE)
    draw.text((3*w//4 - 240, 1935), "PATH B: Press Return on empty or click pill", font=get_font(15, "mono"), fill=C_WHITE)

    # Paste Stage 3A (Music) and Stage 3B (Home) side-by-side
    im_s3a = Image.open(os.path.join(OUTPUT_DIR, "hybrid_stage_03a_direct_music_bloom.png")).resize((1150, 404))
    canvas.paste(im_s3a, (100, 1990))

    im_s3b = Image.open(os.path.join(OUTPUT_DIR, "hybrid_stage_03b_default_home_bloom.png")).resize((1150, 404))
    canvas.paste(im_s3b, (1310, 1990))

    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(os.path.join(OUTPUT_DIR, "hybrid_spotlight_master_flow_board.png"))
    print("Generated hybrid_spotlight_master_flow_board.png")

if __name__ == "__main__":
    build_hybrid_stage_01()
    build_hybrid_stage_02()
    build_hybrid_stage_03a()
    build_hybrid_stage_03b()
    build_hybrid_stage_03c()
    build_hybrid_master_board()
    print("All Spotlight Hybrid images generated successfully!")
