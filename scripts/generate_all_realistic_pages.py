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

def setup_realistic_frame(active_tab="Home"):
    w, h = 1280, 450
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle([4, 4, w - 4, h - 4], radius=48, fill=C_BLACK_OLED, outline=(255, 255, 255, 45), width=2)
    draw.line([(50, 6), (w - 50, 6)], fill=(255, 255, 255, 75), width=1)
    
    # Left Profile pill
    draw.rounded_rectangle([32, 24, 150, 62], radius=19, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30), width=1)
    draw_aa_circle(draw, 50, 43, 13, fill=(50, 50, 50, 255))
    draw.text((42, 35), "MN", font=get_font(11, "rounded"), fill=C_WHITE)
    draw.text((70, 34), "Minh", font=get_font(14, "rounded"), fill=C_WHITE)
    draw.text((164, 34), active_tab.upper(), font=get_font(12, "mono"), fill=C_TITANIUM_MUTED)

    # Segmented Tabs Dock
    tabs = ["Home", "Focus Timer", "Music", "Notes", "Calendar", "Profile"]
    tab_x = 240
    nav_y = 24
    for tab in tabs:
        if tab == active_tab:
            draw.rounded_rectangle([tab_x, nav_y, tab_x + 94, nav_y + 38], radius=19, fill=C_WHITE)
            draw.text((tab_x + 16, nav_y + 9), tab, font=get_font(13, "rounded"), fill=C_BLACK_OLED)
            tab_x += 102
        else:
            bbox = draw.textbbox((0, 0), tab, font=get_font(13))
            tw = bbox[2] - bbox[0] + 28
            draw.rounded_rectangle([tab_x, nav_y, tab_x + tw, nav_y + 38], radius=19, fill=(24, 24, 24, 255), outline=(255, 255, 255, 20), width=1)
            draw.text((tab_x + 14, nav_y + 10), tab, font=get_font(13), fill=C_TITANIUM)
            tab_x += tw + 8

    draw_keycap(draw, w - 170, 28, "⌘K", font=get_font(12, "mono"), h=28)
    draw_aa_circle(draw, w - 100, 42, 16, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30))
    draw.text((w - 106, 33), "☼", font=get_font(14), fill=C_WHITE)
    draw_aa_circle(draw, w - 55, 42, 16, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30))
    draw.text((w - 61, 33), "📌", font=get_font(12), fill=C_WHITE)

    return canvas, draw, (w, h, 92, 330)

# =========================================================================
# 10 REALISTIC PAGES (1280 x 450 px)
# =========================================================================

def build_realistic_01_home():
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Home")
    col_w = 330
    draw.text((48, sy + 20), "GLANCE", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((48, sy + 44), "Saturday, Oct 31", font=get_font(24, "rounded"), fill=C_WHITE)
    draw.text((48, sy + 80), "2 meetings today", font=get_font(15), fill=C_TITANIUM)

    draw.rounded_rectangle([48, sy + 116, 48 + 270, sy + 176], radius=16, fill=(24, 24, 24, 255), outline=(255, 255, 255, 25), width=1)
    draw.text((64, sy + 128), "Design Review in 14m", font=get_font(14, "rounded"), fill=C_WHITE)
    draw.text((64, sy + 150), "Virtual Room A   Spatial UX", font=get_font(11), fill=C_TITANIUM)
    draw_keycap(draw, 48 + 270 - 46, sy + 132, "⌘6", font=get_font(10, "mono"), h=24)

    cx = w // 2
    cy = sy + 90
    draw_morphy_mascot(draw, cx, cy, size=115, mode="normal")
    draw.text((cx - 104, sy + 172), "Good evening, Minh", font=get_font(20, "rounded"), fill=C_WHITE)
    draw.rounded_rectangle([cx - 90, sy + 208, cx + 90, sy + 242], radius=17, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((cx - 68, sy + 217), "Ready for Focus", font=get_font(12, "mono"), fill=C_TITANIUM)

    rx = w - col_w - 48
    draw.text((rx, sy + 20), "LAUNCH", font=get_font(11, "mono"), fill=C_TITANIUM)
    actions = [("Focus Session", "04:49 Active", "⌘2"), ("YouTube Music", "Play Midnight City", "⌘3"), ("Scratchpad", "34w Quick Scratch", "⌘4")]
    for i, (a_title, a_status, a_key) in enumerate(actions):
        ay = sy + 50 + i * 54
        draw.rounded_rectangle([rx, ay, rx + col_w, ay + 44], radius=16, fill=(24, 24, 24, 255), outline=(255, 255, 255, 25), width=1)
        draw.text((rx + 18, ay + 12), a_title, font=get_font(14, "rounded"), fill=C_WHITE)
        draw.text((rx + 150, ay + 14), a_status, font=get_font(11, "mono"), fill=C_TITANIUM)
        draw_keycap(draw, rx + col_w - 42, ay + 10, a_key, font=get_font(10, "mono"), h=24)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    draw.text((40, h - 24), "ACTIVE PROFILE: Minh Workspace", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)
    draw.text((w - 200, h - 24), "Press ⎋ to Collapse", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_01_home.png"))
    print("Generated realistic_page_01_home.png")

def build_realistic_02_timer():
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Focus Timer")
    # Left: Chronograph dial
    dial_cx = 190
    dial_cy = sy + 130
    dial_r = 95
    for i in range(60):
        angle = math.radians(i * 6 - 90)
        is_major = (i % 5 == 0)
        t_len = 8 if is_major else 4
        r1 = dial_r - t_len
        r2 = dial_r
        draw.line([(dial_cx + r1 * math.cos(angle), dial_cy + r1 * math.sin(angle)),
                   (dial_cx + r2 * math.cos(angle), dial_cy + r2 * math.sin(angle))],
                  fill=C_WHITE if is_major else (100, 100, 100, 255), width=2 if is_major else 1)
    draw_aa_circle(draw, dial_cx, dial_cy, dial_r - 14, outline=(255, 255, 255, 30), width=3)
    draw.arc([dial_cx - (dial_r - 14), dial_cy - (dial_r - 14), dial_cx + (dial_r - 14), dial_cy + (dial_r - 14)], start=-90, end=240, fill=C_WHITE, width=3)
    draw.text((dial_cx - 62, dial_cy - 24), "23:45", font=get_font(30, "mono"), fill=C_WHITE)
    draw.text((dial_cx - 38, dial_cy + 16), "DEEP FOCUS", font=get_font(10, "rounded"), fill=C_TITANIUM)
    draw.text((dial_cx - 48, sy + 250), "␣ Space to Pause", font=get_font(11, "mono"), fill=C_TITANIUM)

    # Center: Morphy Mascot in Focus Mode
    cx = w // 2 - 40
    cy = sy + 110
    draw_morphy_mascot(draw, cx, cy, size=115, mode="focus")
    draw.text((cx - 90, sy + 190), "Session 3 of 4 — Deep Work", font=get_font(14, "rounded"), fill=C_WHITE)
    draw.text((cx - 80, sy + 218), "2h 15m Focused Today", font=get_font(12, "mono"), fill=C_TITANIUM)

    # Right: Presets & Transport
    rx = w - 440
    draw.text((rx, sy + 14), "MODE & PRESETS", font=get_font(11, "mono"), fill=C_TITANIUM)
    presets = [("25m", "Focus"), ("15m", "Sprint"), ("5m", "Rest"), ("1m", "Test")]
    pw = 86
    for i, (pt, pl) in enumerate(presets):
        px = rx + i * (pw + 10)
        draw.rounded_rectangle([px, sy + 40, px + pw, sy + 92], radius=12, fill=(28, 28, 28, 255), outline=(255, 255, 255, 25), width=1)
        draw.text((px + 14, sy + 48), pt, font=get_font(16, "rounded"), fill=C_WHITE)
        draw.text((px + 14, sy + 70), pl, font=get_font(10), fill=C_TITANIUM)

    t_btns = [("Pause (Space)", C_WHITE, C_BLACK_OLED), ("Reset (⇧⌘R)", (35, 35, 35, 255), C_WHITE), ("Skip (⇧⌘S)", (35, 35, 35, 255), C_WHITE)]
    tw_b = 120
    for i, (b_title, b_fill, b_col) in enumerate(t_btns):
        bx = rx + i * (tw_b + 10)
        draw.rounded_rectangle([bx, sy + 116, bx + tw_b, sy + 164], radius=18, fill=b_fill, outline=(255, 255, 255, 35) if b_fill != C_WHITE else None, width=1)
        draw.text((bx + 14, sy + 130), b_title, font=get_font(11, "rounded"), fill=b_col)

    draw.rounded_rectangle([rx, sy + 186, rx + 380, sy + 252], radius=14, fill=(24, 24, 24, 255), outline=(255, 255, 255, 20), width=1)
    draw.text((rx + 18, sy + 198), "DAILY FOCUS MOMENTUM", font=get_font(10, "mono"), fill=C_TITANIUM)
    draw.text((rx + 18, sy + 220), "14-Day Streak Maintained   4 Completed Blocks", font=get_font(12), fill=C_WHITE)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_02_timer.png"))
    print("Generated realistic_page_02_timer.png")

def build_realistic_03_music():
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Music")
    # Left: Album Art & Lossless
    art_x = 48
    art_y = sy + 30
    draw.rounded_rectangle([art_x, art_y, art_x + 160, art_y + 160], radius=24, fill=(35, 35, 35, 255), outline=(255, 255, 255, 40), width=1)
    draw.text((art_x + 55, art_y + 60), "♫", font=get_font(42), fill=C_WHITE)
    draw.rounded_rectangle([art_x + 10, art_y + 10, art_x + 70, art_y + 30], radius=6, fill=(15, 15, 15, 220))
    draw.text((art_x + 15, art_y + 14), "LOSSLESS", font=get_font(8, "mono"), fill=C_WHITE)
    draw.text((art_x, sy + 210), "Midnight City", font=get_font(18, "rounded"), fill=C_WHITE)
    draw.text((art_x, sy + 236), "M83 — Hurry Up, We're Dreaming", font=get_font(12), fill=C_TITANIUM)

    # Center: Morphy in Music Mode
    cx = w // 2 - 40
    cy = sy + 110
    draw_morphy_mascot(draw, cx, cy, size=115, mode="music")
    draw.text((cx - 70, sy + 190), "Vibing to YouTube Music", font=get_font(13, "rounded"), fill=C_WHITE)
    draw.text((cx - 60, sy + 216), "Lossless 24-bit 96kHz", font=get_font(11, "mono"), fill=C_TITANIUM)

    # Right: Scrubber, Controls & AirPlay
    rx = w - 480
    draw.text((rx, sy + 20), "NOW PLAYING", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.rounded_rectangle([rx, sy + 52, rx + 430, sy + 60], radius=4, fill=(35, 35, 35, 255))
    draw.rounded_rectangle([rx, sy + 52, rx + 250, sy + 60], radius=4, fill=C_WHITE)
    draw_aa_circle(draw, rx + 250, sy + 56, 6, fill=C_WHITE)
    draw.text((rx, sy + 70), "2:14", font=get_font(11, "mono"), fill=C_WHITE)
    draw.text((rx + 390, sy + 70), "-1:42", font=get_font(11, "mono"), fill=C_TITANIUM)

    # Transport
    tc_cx = rx + 215
    tc_cy = sy + 140
    draw_aa_circle(draw, tc_cx, tc_cy, 26, fill=C_WHITE)
    draw.text((tc_cx - 7, tc_cy - 12), "❚❚", font=get_font(16), fill=C_BLACK_OLED)
    draw_aa_circle(draw, tc_cx - 70, tc_cy, 20, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30))
    draw.text((tc_cx - 78, tc_cy - 9), "⏮", font=get_font(12), fill=C_WHITE)
    draw_aa_circle(draw, tc_cx + 70, tc_cy, 20, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30))
    draw.text((tc_cx + 62, tc_cy - 9), "⏭", font=get_font(12), fill=C_WHITE)

    # Volume & Route
    draw.text((rx, sy + 204), "🔈", font=get_font(13), fill=C_TITANIUM)
    draw.rounded_rectangle([rx + 26, sy + 210, rx + 220, sy + 216], radius=3, fill=(35, 35, 35, 255))
    draw.rounded_rectangle([rx + 26, sy + 210, rx + 160, sy + 216], radius=3, fill=C_WHITE)
    draw.rounded_rectangle([rx + 260, sy + 196, rx + 430, sy + 230], radius=17, fill=(30, 30, 30, 255), outline=(255, 255, 255, 25), width=1)
    draw.text((rx + 280, sy + 206), "AirPods Max ⌵", font=get_font(12, "rounded"), fill=C_WHITE)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_03_music.png"))
    print("Generated realistic_page_03_music.png")

def build_realistic_04_notes():
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Notes")
    # Action Strip
    draw.text((48, sy + 14), "iCloud Quick Notes", font=get_font(15, "rounded"), fill=C_WHITE)
    draw.text((220, sy + 16), "34 words | 210 chars   Auto-saved 12s ago", font=get_font(11, "mono"), fill=C_TITANIUM)

    actions = [("+ Checklist", "⌘T"), ("Pin Note", "⌘⇧P"), ("Copy All", "⌘⇧C"), ("New Note", "⌘N")]
    ax = w - 48
    for label, key in reversed(actions):
        bbox = draw.textbbox((0, 0), label, font=get_font(11, "rounded"))
        lw = bbox[2] - bbox[0]
        bw = lw + 42
        ax -= bw
        draw.rounded_rectangle([ax, sy + 10, ax + bw, sy + 38], radius=14, fill=(30, 30, 30, 255), outline=(255, 255, 255, 25), width=1)
        draw.text((ax + 10, sy + 16), label, font=get_font(11, "rounded"), fill=C_WHITE)
        draw_keycap(draw, ax + bw - 26, sy + 14, key, font=get_font(9, "mono"), h=18)
        ax -= 8

    draw.line([(48, sy + 48), (w - 48, sy + 48)], fill=(255, 255, 255, 18), width=1)
    
    # Notes Canvas
    draw.text((48, sy + 64), "# Dynamic Island System Architecture", font=get_font(18, "rounded"), fill=C_WHITE)
    draw.text((48, sy + 92), "Universal state mechanics across macOS Sequoia desktop and pro applications.", font=get_font(13), fill=C_TITANIUM)

    items = [
        ("✓", "Audit full 10-page feature inventory (100% functionality preserved)"),
        ("✓", "Implement 14pt vertical breathing clearance below hardware notch"),
        ("✓", "Enforce 100% click-through in State 1 resting capsule for zero browser tab occlusion"),
        ("◻", "Verify universal state transitions across Music, Timer, and Calendar HUDs")
    ]
    for i, (check, itext) in enumerate(items):
        iy_item = sy + 124 + i * 28
        draw.rounded_rectangle([48, iy_item + 1, 66, iy_item + 19], radius=5, fill=(35, 35, 35, 255), outline=(255, 255, 255, 35), width=1)
        draw.text((53, iy_item + 3), check, font=get_font(10, "mono"), fill=C_WHITE if check == "✓" else C_TITANIUM)
        draw.text((76, iy_item + 2), itext, font=get_font(13), fill=C_WHITE if check != "◻" else C_TITANIUM)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_04_notes.png"))
    print("Generated realistic_page_04_notes.png")

def build_realistic_05_calendar():
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Calendar")
    # Left: 7-column calendar
    ld_w = 460
    draw.text((48, sy + 16), "October 2026", font=get_font(16, "rounded"), fill=C_WHITE)
    draw.text((48 + ld_w - 60, sy + 16), "<   >", font=get_font(14, "mono"), fill=C_TITANIUM)
    dow = ["S", "M", "T", "W", "T", "F", "S"]
    cw = ld_w // 7
    for i, d in enumerate(dow):
        draw.text((48 + i * cw + cw//2 - 4, sy + 44), d, font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)

    days = [
        ["", "", "", "", 1, 2, 3],
        [4, 5, 6, 7, 8, 9, 10],
        [11, 12, 13, 14, 15, 16, 17],
        [18, 19, 20, 21, 22, 23, 24],
        [25, 26, 27, 28, 29, 30, 31]
    ]
    for r_idx, row in enumerate(days):
        for c_idx, val in enumerate(row):
            if val != "":
                dx = 48 + c_idx * cw + cw//2
                dy = sy + 70 + r_idx * 30
                if val == 31:
                    draw_aa_circle(draw, dx, dy + 6, 13, fill=C_WHITE)
                    draw.text((dx - 7, dy), str(val), font=get_font(11, "rounded"), fill=C_BLACK_OLED)
                else:
                    draw.text((dx - 6, dy), str(val), font=get_font(11), fill=C_WHITE)

    # Right: Upcoming Card & Video Join
    rx = w - 680
    draw.rounded_rectangle([rx, sy + 16, rx + 630, sy + 160], radius=18, fill=(24, 24, 24, 255), outline=(255, 255, 255, 25), width=1)
    draw.text((rx + 24, sy + 32), "UPCOMING SESSION   10:45 AM - 11:30 AM", font=get_font(10, "mono"), fill=C_TITANIUM)
    draw.text((rx + 24, sy + 54), "Design Review — Dynamic Island Architecture", font=get_font(18, "rounded"), fill=C_WHITE)
    draw.text((rx + 24, sy + 80), "Spatial UX Team   Virtual Room A   4 Attendees", font=get_font(12), fill=C_TITANIUM)

    draw_aa_circle(draw, rx + 44, sy + 124, 15, fill=(50, 50, 50, 255), outline=(255, 255, 255, 30))
    draw.text((rx + 36, sy + 116), "MN", font=get_font(10, "rounded"), fill=C_WHITE)
    draw_aa_circle(draw, rx + 74, sy + 124, 15, fill=(60, 60, 60, 255), outline=(255, 255, 255, 30))
    draw.text((rx + 68, sy + 116), "TC", font=get_font(10, "rounded"), fill=C_WHITE)
    draw_aa_circle(draw, rx + 100, sy + 124, 15, fill=(40, 40, 40, 255), outline=(255, 255, 255, 30))
    draw.text((rx + 94, sy + 116), "+2", font=get_font(10, "rounded"), fill=C_TITANIUM)

    draw.rounded_rectangle([rx + 420, sy + 104, rx + 600, sy + 144], radius=20, fill=C_WHITE)
    draw.text((rx + 444, sy + 116), "Join FaceTime ↗", font=get_font(12, "rounded"), fill=C_BLACK_OLED)

    draw.rounded_rectangle([rx, sy + 176, rx + 630, sy + 250], radius=16, fill=(20, 20, 20, 255), outline=(255, 255, 255, 20), width=1)
    draw.text((rx + 24, sy + 192), "2:00 PM — Engineering Sync (Xcode Project Structure)", font=get_font(12, "rounded"), fill=C_WHITE)
    draw.text((rx + 24, sy + 218), "4:30 PM — 1:1 Architecture Review with Lead", font=get_font(12, "rounded"), fill=C_TITANIUM)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_05_calendar.png"))
    print("Generated realistic_page_05_calendar.png")

def build_realistic_06_profile():
    # Exactly matching Screenshot 2!
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Profile")
    # Left: User Credentials & Stats
    ld_w = 400
    draw_aa_circle(draw, 96, sy + 64, 34, fill=(45, 45, 45, 255), outline=(255, 255, 255, 40), width=2)
    draw.text((80, sy + 50), "MN", font=get_font(18, "rounded"), fill=C_WHITE)
    draw.text((150, sy + 44), "Minh Nguyen", font=get_font(20, "rounded"), fill=C_WHITE)
    draw.text((150, sy + 70), "minh@morph.app   Lead Architect", font=get_font(11), fill=C_TITANIUM)

    # Focus stats
    stats = [("2,480m", "Focus Time"), ("14 Days", "Streak"), ("42", "Sessions")]
    sw = ld_w // 3
    for i, (val, label) in enumerate(stats):
        sx = 48 + i * sw
        draw.text((sx + 14, sy + 130), val, font=get_font(18, "rounded"), fill=C_WHITE)
        draw.text((sx + 14, sy + 154), label, font=get_font(10), fill=C_TITANIUM)

    draw.rounded_rectangle([48, sy + 186, 48 + ld_w, sy + 246], radius=14, fill=(24, 24, 24, 255), outline=(255, 255, 255, 20), width=1)
    draw.text((64, sy + 198), "CONTINUITY & HANDOFF", font=get_font(9, "mono"), fill=C_TITANIUM)
    draw.text((64, sy + 218), "MacBook Pro 16\" & iPhone 16 Pro Connected", font=get_font(12), fill=C_WHITE)

    # Right: Compact Settings Cards
    rx = w - 740
    settings = [
        ("Appearance Mode", "Obsidian Dark Substrate with Titanium Glint", "[ Obsidian Dark ]   Light   System"),
        ("Island Pinning", "Keep Dynamic Island visible across full screen spaces", "⌘P Toggle   Enabled"),
        ("Haptic Touch Engine", "Tactile feedback on hover dwell and mode switch", "Subtle Click   Active"),
        ("Keyboard Shortcuts", "Quick navigation and execution bindings", "⌘? View Map")
    ]
    card_h = 48
    for i, (stitle, ssub, sval) in enumerate(settings):
        cy = sy + 20 + i * (card_h + 12)
        draw.rounded_rectangle([rx, cy, rx + 690, cy + card_h], radius=14, fill=(24, 24, 24, 255), outline=(255, 255, 255, 25), width=1)
        draw.text((rx + 20, cy + 10), stitle, font=get_font(13, "rounded"), fill=C_WHITE)
        draw.text((rx + 20, cy + 28), ssub, font=get_font(10), fill=C_TITANIUM)
        draw.text((rx + 480, cy + 16), sval, font=get_font(11, "mono"), fill=C_WHITE)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_06_profile.png"))
    print("Generated realistic_page_06_profile.png")

def build_realistic_07_meeting():
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Home")
    ld_w = 480
    draw.text((48, sy + 24), "FACETIME ACTIVE CALL", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((48, sy + 48), "Spatial Design Sync", font=get_font(24, "rounded"), fill=C_WHITE)
    draw.text((48, sy + 88), "24:15", font=get_font(42, "mono"), fill=C_WHITE)
    draw.text((48, sy + 144), "4 Participants   Voice Isolation Active   Studio Mic", font=get_font(12), fill=C_TITANIUM)

    roster = ["MN Minh (Host)", "TC Tim C.", "CW Craig W.", "JF Jony F."]
    for i, name in enumerate(roster):
        draw.text((48 + i * 110, sy + 180), name, font=get_font(11, "rounded"), fill=C_WHITE)

    rx = w - 680
    draw.text((rx, sy + 24), "TELEPRESENCE KILLSWITCHES", font=get_font(11, "mono"), fill=C_TITANIUM)
    switches = [
        ("Mute Mic", "Studio Mic (⌘⇧M)", "🎙 Active", C_WHITE, C_BLACK_OLED),
        ("Camera", "1080p HD (⌘⇧V)", "📷 Active", (32, 32, 32, 255), C_WHITE),
        ("Screen Share", "Display 1 (⌘⇧S)", "🖥 Sharing", (32, 32, 32, 255), C_WHITE),
        ("Leave Call", "End Call (⌘Q)", "📞 End", (32, 32, 32, 255), C_WHITE)
    ]
    sw_w = 144
    for i, (title, sub, badge, fill_col, text_col) in enumerate(switches):
        sx = rx + i * (sw_w + 14)
        draw.rounded_rectangle([sx, sy + 58, sx + sw_w, sy + 180], radius=18, fill=fill_col, outline=(255, 255, 255, 30) if fill_col != C_WHITE else None, width=1)
        draw.text((sx + 16, sy + 76), badge, font=get_font(15), fill=text_col)
        draw.text((sx + 16, sy + 116), title, font=get_font(14, "rounded"), fill=text_col)
        draw.text((sx + 16, sy + 142), sub, font=get_font(10), fill=C_TITANIUM if fill_col == C_WHITE else C_TITANIUM_MUTED)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_07_meeting.png"))
    print("Generated realistic_page_07_meeting.png")

def build_realistic_08_dropshelf():
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Home")
    draw.text((48, sy + 16), "AIRDROP STAGING BAY", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((220, sy + 14), "3 Items Staged | 14.2 MB Total", font=get_font(14, "rounded"), fill=C_WHITE)

    draw_keycap(draw, w - 360, sy + 12, "Hold: ON", font=get_font(10, "mono"), h=24)
    draw_keycap(draw, w - 250, sy + 12, "Copy All ⌘⇧C", font=get_font(10, "mono"), h=24)
    draw_keycap(draw, w - 100, sy + 12, "Clear ⌘⌫", font=get_font(10, "mono"), h=24)

    draw.line([(48, sy + 44), (w - 48, sy + 44)], fill=(255, 255, 255, 18), width=1)

    files = [
        ("Mockup_v4.png", "PNG Image", "8.4 MB", "PNG"),
        ("Architecture_Spec.pdf", "PDF Document", "5.1 MB", "PDF"),
        ("StateConfig.json", "JSON Data", "700 KB", "JSON")
    ]
    fw = (w - 96 - 32) // 3
    for i, (fname, ftype, fsize, fbadge) in enumerate(files):
        fx = 48 + i * (fw + 16)
        draw.rounded_rectangle([fx, sy + 58, fx + fw, sy + 180], radius=16, fill=(26, 26, 26, 255), outline=(255, 255, 255, 25), width=1)
        draw.rounded_rectangle([fx + 16, sy + 72, fx + 56, sy + 112], radius=10, fill=(40, 40, 40, 255))
        draw.text((fx + 22, sy + 84), fbadge, font=get_font(10, "mono"), fill=C_WHITE)
        draw.text((fx + 68, sy + 76), fname, font=get_font(14, "rounded"), fill=C_WHITE)
        draw.text((fx + 68, sy + 98), f"{ftype}   {fsize}", font=get_font(11), fill=C_TITANIUM)
        draw.text((fx + 16, sy + 146), "Reveal in Finder ↗", font=get_font(11, "rounded"), fill=C_WHITE)
        draw.text((fx + fw - 70, sy + 146), "Remove ✕", font=get_font(11), fill=C_TITANIUM)

    draw.text((48, sy + 210), "AirDrop to: Minh's iPhone 16 Pro (Nearby)   Studio Display", font=get_font(12), fill=C_WHITE)
    draw.rounded_rectangle([w - 240, sy + 198, w - 48, sy + 236], radius=19, fill=C_WHITE)
    draw.text((w - 216, sy + 209), "AirDrop All Files ↗", font=get_font(12, "rounded"), fill=C_BLACK_OLED)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_08_dropshelf.png"))
    print("Generated realistic_page_08_dropshelf.png")

def build_realistic_09_form():
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Home")
    ld_w = 400
    draw.text((48, sy + 20), "APPLICATION INTAKE FORM", font=get_font(10, "mono"), fill=C_TITANIUM)
    draw.text((48, sy + 42), "Question 1 of 4", font=get_font(22, "rounded"), fill=C_WHITE)
    draw.text((48, sy + 74), "25% Complete   Apple ATS Portal", font=get_font(12), fill=C_TITANIUM)

    draw.rounded_rectangle([48, sy + 104, 48 + ld_w, sy + 112], radius=4, fill=(35, 35, 35, 255))
    draw.rounded_rectangle([48, sy + 104, 48 + ld_w//4, sy + 112], radius=4, fill=C_WHITE)

    steps = [("1. Architectural Focus", "In Progress"), ("2. Experience Level", "Pending"), ("3. System Portfolio", "Pending")]
    for i, (st, ss) in enumerate(steps):
        draw_aa_circle(draw, 58, sy + 140 + i * 36, 8, fill=C_WHITE if i == 0 else (40, 40, 40, 255))
        draw.text((76, sy + 132 + i * 36), st, font=get_font(12, "rounded"), fill=C_WHITE if i == 0 else C_TITANIUM)

    rx = w - 740
    draw.text((rx, sy + 20), "ACTIVE PROMPT *", font=get_font(10, "mono"), fill=C_TITANIUM)
    draw.text((rx, sy + 42), "What is your primary architectural focus for macOS?", font=get_font(16, "rounded"), fill=C_WHITE)

    choices = [
        ("Spatial & Dynamic Island UX", "Continuous squircle physics & zero occlusion", True),
        ("High-Performance Audio Engine", "Lossless low-latency buffer management", False)
    ]
    for i, (ct, cs, isel) in enumerate(choices):
        cy = sy + 80 + i * 56
        draw.rounded_rectangle([rx, cy, rx + 690, cy + 48], radius=14, fill=(32, 32, 32, 255) if isel else (22, 22, 22, 255), outline=C_WHITE if isel else (255, 255, 255, 25), width=2 if isel else 1)
        draw_aa_circle(draw, rx + 24, cy + 24, 8, fill=C_WHITE if isel else None, outline=C_WHITE, width=2)
        draw.text((rx + 44, cy + 10), ct, font=get_font(13, "rounded"), fill=C_WHITE)
        draw.text((rx + 44, cy + 28), cs, font=get_font(10), fill=C_TITANIUM)

    draw.rounded_rectangle([rx, sy + 200, rx + 690, sy + 246], radius=14, fill=(26, 26, 26, 255), outline=(255, 255, 255, 25), width=1)
    draw.text((rx + 18, sy + 214), "🔑 Keychain Autofill: Minh Nguyen (Work Profile)   minh@morph.app", font=get_font(12), fill=C_WHITE)
    draw_keycap(draw, rx + 560, sy + 210, "Fill ⌥Space", font=get_font(10, "mono"), h=24)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_09_form.png"))
    print("Generated realistic_page_09_form.png")

def build_realistic_10_compact():
    canvas, draw, (w, h, sy, sh) = setup_realistic_frame("Home")
    draw.text((48, sy + 16), "MULTI-ACTIVITY BACKGROUND HUD SHOWCASE", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((48, sy + 40), "Concurrent Live Activities running in State 2 Extended Pill", font=get_font(16, "rounded"), fill=C_WHITE)

    # 3 Pills comparison
    pills = [
        ("MUSIC + TIMER DUAL BUBBLE", "♫ Midnight City — M83", "Equalizer Active", "23:45 Remaining", "Phase 1 Focus"),
        ("FACETIME CALL + SHELF", "FaceTime Active (24:15)", "Spatial Audio", "3 Staged Files", "Hold Mode ON"),
        ("RESTING STEALTH CAPSULE", "Whisper Hairline (0.75pt)", "Zero Text", "100% Click-Through", "Zero Tab Occlusion")
    ]
    for i, (title, lt, ls, rt, rs) in enumerate(pills):
        py = sy + 76 + i * 56
        draw.rounded_rectangle([48, py, w - 48, py + 46], radius=23, fill=C_BLACK_OLED, outline=(255, 255, 255, 40), width=1)
        draw.text((68, py + 14), lt, font=get_font(13, "rounded"), fill=C_WHITE)
        draw.text((280, py + 16), ls, font=get_font(11), fill=C_TITANIUM)
        draw.text((w - 360, py + 14), rt, font=get_font(13, "mono"), fill=C_WHITE)
        draw.text((w - 180, py + 16), rs, font=get_font(11), fill=C_TITANIUM)

    draw.line([(30, h - 34), (w - 30, h - 34)], fill=(255, 255, 255, 18), width=1)
    canvas.save(os.path.join(OUTPUT_DIR, "realistic_page_10_compact.png"))
    print("Generated realistic_page_10_compact.png")

if __name__ == "__main__":
    build_realistic_01_home()
    build_realistic_02_timer()
    build_realistic_03_music()
    build_realistic_04_notes()
    build_realistic_05_calendar()
    build_realistic_06_profile()
    build_realistic_07_meeting()
    build_realistic_08_dropshelf()
    build_realistic_09_form()
    build_realistic_10_compact()
    print("All 10 realistic pages generated successfully at 1280x450 px!")
