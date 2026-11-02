#!/usr/bin/env python3
import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUTPUT_DIR = "/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd/scratch"

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
C_BLACK_WELL = (22, 22, 22, 255)
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

def draw_keycap(draw, x, y, text, font=None, h=26):
    if font is None:
        font = get_font(12, "mono")
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    w = max(tw + 14, 28)
    draw.rounded_rectangle([x, y, x + w, y + h], radius=6, fill=(35, 35, 35, 255), outline=(255, 255, 255, 50), width=1)
    draw.text((x + (w - tw)//2, y + (h - (bbox[3]-bbox[1]))//2 - 1), text, font=font, fill=C_WHITE)
    return w

def draw_aa_circle(draw, cx, cy, r, outline=None, fill=None, width=1):
    box = [cx - r, cy - r, cx + r, cy + r]
    draw.ellipse(box, fill=fill, outline=outline, width=width)

def render_home_preview():
    width = 2400
    height = 1600
    canvas = Image.new("RGBA", (width, height), C_BLACK_BG)
    draw = ImageDraw.Draw(canvas)

    # Subtle ambient gradient backdrop
    for y in range(height):
        ratio = y / height
        v = int(10 + 4 * (1 - abs(ratio - 0.5) * 2))
        draw.line([(0, y), (width, y)], fill=(v, v, v, 255))

    font_header_brand = get_font(22, "rounded")
    font_page_title = get_font(28)
    font_section = get_font(18, "rounded")
    font_desc = get_font(14)

    # Top Brand Bar
    draw.text((80, 36), "  Apple Dynamic Island Architecture", font=font_header_brand, fill=C_TITANIUM)
    title_text = "PAGE 01 — HOME: AMBIENT INTELLIGENCE HUB"
    bbox = draw.textbbox((0, 0), title_text, font=font_page_title)
    draw.text((width - 80 - (bbox[2]-bbox[0]), 32), title_text, font=font_page_title, fill=C_WHITE)
    draw.line([(80, 76), (width - 80, 76)], fill=C_TITANIUM_BORDER, width=1)

    # =========================================================
    # TIER 1: STATE 2 — THE EXTENDED MORPH PILL (LIVE ACTIVITY HUD)
    # =========================================================
    t1_y = 96
    t1_w = width - 160
    t1_h = 220
    draw.rounded_rectangle([80, t1_y, 80 + t1_w, t1_y + t1_h], radius=18, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
    draw.text((108, t1_y + 16), "STATE 2 — THE EXTENDED MORPH PILL (LIVE BACKGROUND ACTIVITY HUD)", font=font_section, fill=C_WHITE)
    draw.text((108, t1_y + 38), "Elongated pill displaying real-time telemetry while user is actively coding, browsing, or writing in background apps", font=font_desc, fill=C_TITANIUM)

    # Extended Pill (1100 x 64)
    ep_w = 1100
    ep_h = 64
    ep_x = 80 + (t1_w - ep_w) // 2
    ep_y = t1_y + 70

    # Pill shadow
    draw.rounded_rectangle([ep_x - 3, ep_y - 2, ep_x + ep_w + 3, ep_y + ep_h + 4], radius=34, fill=(0, 0, 0, 200))
    # Pill body
    draw.rounded_rectangle([ep_x, ep_y, ep_x + ep_w, ep_y + ep_h], radius=32, fill=C_BLACK_OLED, outline=(255, 255, 255, 45), width=1)

    # Left Wing: Morphy breathing wave + Focus telemetry
    # Waveform bars
    wb_x = ep_x + 28
    wb_y = ep_y + ep_h // 2
    bar_heights = [8, 16, 26, 18, 10]
    for i, bh in enumerate(bar_heights):
        draw.rounded_rectangle([wb_x + i * 6, wb_y - bh//2, wb_x + i * 6 + 3, wb_y + bh//2], radius=2, fill=C_WHITE)
    draw.text((wb_x + 40, ep_y + 14), "Morph Ambient Active", font=get_font(15, "rounded"), fill=C_WHITE)
    draw.text((wb_x + 40, ep_y + 34), "Focus Block in Progress", font=get_font(12), fill=C_TITANIUM)

    # Center Hardware Notch Cutout representation
    mid_x = ep_x + ep_w // 2
    draw.rounded_rectangle([mid_x - 70, ep_y, mid_x + 70, ep_y + 26], radius=10, fill=(15, 15, 15, 255), outline=C_TITANIUM_BORDER, width=1)
    draw_aa_circle(draw, mid_x, ep_y + 13, 5, fill=(30, 30, 30, 255), outline=(255, 255, 255, 40))

    # Right Wing: Live Focus Timer countdown + shortcut
    draw.text((ep_x + ep_w - 320, ep_y + 14), "23:45 Remaining", font=get_font(16, "mono"), fill=C_WHITE)
    draw.text((ep_x + ep_w - 320, ep_y + 34), "Deep Work Session 3 of 4", font=get_font(12), fill=C_TITANIUM)
    draw_keycap(draw, ep_x + ep_w - 110, ep_y + 19, "⌘⌥M", font=get_font(12, "mono"), h=26)

    # Under-pill indicators
    draw.text((ep_x + 28, ep_y + ep_h + 8), "◀ LEFT WING (LIVE FOCUS CONTEXT)", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)
    draw.text((mid_x - 65, ep_y + ep_h + 8), "◆ HARDWARE NOTCH CLEARANCE", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)
    draw.text((ep_x + ep_w - 240, ep_y + ep_h + 8), "RIGHT WING (COUNTDOWN & EXPAND) ▶", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)
    draw.text((108, t1_y + t1_h - 22), "✓ 100% Universal Coexistence: Zero occlusion of active browser tabs, search omnibox, or IDE split panes.", font=get_font(12), fill=C_WHITE)

    # =========================================================
    # TIER 2: STATE 3 — THE FULL BIG UI (REDESIGNED DYNAMIC ISLAND)
    # =========================================================
    t2_y = t1_y + t1_h + 24
    draw.text((80, t2_y), "STATE 3 — THE FULL BIG UI FOR MORPH (AUTONOMOUS DYNAMIC ISLAND MODAL)", font=font_section, fill=C_WHITE)
    draw.text((80, t2_y + 22), "Reimagined through authentic Apple craftsmanship: Continuous OLED squircle floating 14pt beneath the MacBook notch", font=font_desc, fill=C_TITANIUM)

    # Desktop simulation container (MacBook Notch + Floating Island)
    desk_y = t2_y + 50
    desk_w = width - 160
    desk_h = height - desk_y - 40
    draw.rounded_rectangle([80, desk_y, 80 + desk_w, desk_y + desk_h], radius=24, fill=(14, 14, 14, 255), outline=C_TITANIUM_BORDER, width=1)

    # macOS Menu Bar simulation
    mb_h = 36
    draw.rectangle([80, desk_y, 80 + desk_w, desk_y + mb_h], fill=(8, 8, 8, 255))
    draw.line([(80, desk_y + mb_h), (80 + desk_w, desk_y + mb_h)], fill=(255, 255, 255, 20), width=1)
    draw.text((108, desk_y + 9), "", font=get_font(16), fill=C_WHITE)
    draw.text((134, desk_y + 9), "Workspace", font=get_font(13, "rounded"), fill=C_WHITE)
    draw.text((214, desk_y + 9), "File   Edit   View   Window   Help", font=get_font(13), fill=C_TITANIUM)
    draw.text((80 + desk_w - 260, desk_y + 9), "􀐾  􀛨  􀙇   Sat Oct 31  10:42 AM", font=get_font(12, "mono"), fill=C_TITANIUM)

    # Hardware Notch at top center
    notch_w = 210
    notch_h = 32
    notch_x = 80 + (desk_w - notch_w) // 2
    draw.rounded_rectangle([notch_x, desk_y, notch_x + notch_w, desk_y + notch_h], radius=14, fill=C_BLACK_OLED)
    draw_aa_circle(draw, notch_x + notch_w // 2 - 12, desk_y + 16, 5, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30))
    draw_aa_circle(draw, notch_x + notch_w // 2 + 16, desk_y + 16, 3, fill=(255, 255, 255, 50))

    # 14pt vertical breathing gap annotation
    gap_y = desk_y + notch_h
    gap_h = 24  # 14pt in canvas units
    draw.line([(notch_x + notch_w + 30, gap_y), (notch_x + notch_w + 30, gap_y + gap_h)], fill=C_TITANIUM_MUTED, width=1)
    draw.text((notch_x + notch_w + 40, gap_y + 4), "14pt Breathing Clearance", font=get_font(11, "mono"), fill=C_TITANIUM)

    # -------------------------------------------------------------
    # THE REDESIGNED EXPANDED DYNAMIC ISLAND (State 3)
    # Dimensions: 1720 x 740
    # -------------------------------------------------------------
    isl_w = 1720
    isl_h = 740
    isl_x = 80 + (desk_w - isl_w) // 2
    isl_y = gap_y + gap_h

    # Deep drop shadow
    draw.rounded_rectangle([isl_x - 8, isl_y - 4, isl_x + isl_w + 8, isl_y + isl_h + 16], radius=44, fill=(0, 0, 0, 240))
    # Island Body
    draw.rounded_rectangle([isl_x, isl_y, isl_x + isl_w, isl_y + isl_h], radius=40, fill=C_BLACK_OLED, outline=(255, 255, 255, 35), width=1)
    # Specular Top Glint
    draw.line([(isl_x + 40, isl_y + 1), (isl_x + isl_w - 40, isl_y + 1)], fill=(255, 255, 255, 60), width=1)

    # Top Anchor & Segmented Pill Navigation
    drag_w = 64
    drag_h = 5
    draw.rounded_rectangle([isl_x + (isl_w - drag_w)//2, isl_y + 12, isl_x + (isl_w + drag_w)//2, isl_y + 12 + drag_h], radius=3, fill=(142, 142, 142, 100))

    # Segmented Tabs Dock
    nav_y = isl_y + 28
    tabs = ["Home", "Focus Timer", "Music", "Notes", "Calendar", "Profile"]
    tab_x = isl_x + 40
    for tab in tabs:
        if tab == "Home":
            # Active illuminated white pill
            tw = 84
            draw.rounded_rectangle([tab_x, nav_y, tab_x + tw, nav_y + 30], radius=15, fill=C_WHITE)
            draw.text((tab_x + 18, nav_y + 6), tab, font=get_font(13, "rounded"), fill=C_BLACK_OLED)
            tab_x += tw + 8
        else:
            bbox = draw.textbbox((0, 0), tab, font=get_font(13))
            tw = bbox[2] - bbox[0] + 24
            draw.rounded_rectangle([tab_x, nav_y, tab_x + tw, nav_y + 30], radius=15, fill=(25, 25, 25, 255), outline=(255, 255, 255, 20), width=1)
            draw.text((tab_x + 12, nav_y + 7), tab, font=get_font(13), fill=C_TITANIUM)
            tab_x += tw + 8

    # Trailing Search & Options
    draw_keycap(draw, isl_x + isl_w - 120, nav_y + 2, "⌘K", font=get_font(12, "mono"), h=26)
    draw.text((isl_x + isl_w - 60, nav_y + 5), "•••", font=get_font(14), fill=C_TITANIUM)

    draw.line([(isl_x + 30, isl_y + 72), (isl_x + isl_w - 30, isl_y + 72)], fill=(255, 255, 255, 18), width=1)

    # -------------------------------------------------------------
    # MAIN STAGE: ASYMMETRIC FLUID DUAL-DECK (LEFT: LIVING CORE, RIGHT: INTELLIGENCE & LAUNCHPAD)
    # -------------------------------------------------------------
    stage_y = isl_y + 86
    stage_h = isl_h - 138

    # --- LEFT DECK (Living Morphy Core & Focus Flow) ---
    ld_w = 720
    ld_x = isl_x + 36
    draw.rounded_rectangle([ld_x, stage_y, ld_x + ld_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    # Living Morphy Concentric Rings
    core_cx = ld_x + ld_w // 2
    core_cy = stage_y + 150
    draw_aa_circle(draw, core_cx, core_cy, 96, outline=(255, 255, 255, 15), width=1)
    draw_aa_circle(draw, core_cx, core_cy, 70, outline=(255, 255, 255, 25), width=1)
    draw_aa_circle(draw, core_cx, core_cy, 46, outline=(255, 255, 255, 40), width=1)

    # Dynamic Living Waveform Filaments in Center
    core_bars = [12, 22, 36, 52, 38, 24, 14]
    cb_x = core_cx - (len(core_bars) * 7) // 2
    for i, cbh in enumerate(core_bars):
        draw.rounded_rectangle([cb_x + i * 7, core_cy - cbh//2, cb_x + i * 7 + 4, core_cy + cbh//2], radius=2, fill=C_WHITE)

    # Greeting & Identity
    draw.text((core_cx - 150, stage_y + 270), "Good afternoon, Minh", font=get_font(26, "rounded"), fill=C_WHITE)
    draw.text((core_cx - 120, stage_y + 308), "Deep Focus Flow Active", font=get_font(15), fill=C_TITANIUM)

    # Tactile Focus Flow Capsule
    fcap_w = 340
    fcap_h = 44
    fcap_x = core_cx - fcap_w // 2
    fcap_y = stage_y + 346
    draw.rounded_rectangle([fcap_x, fcap_y, fcap_x + fcap_w, fcap_y + fcap_h], radius=22, fill=(35, 35, 35, 255), outline=(255, 255, 255, 45), width=1)
    draw.text((fcap_x + 22, fcap_y + 12), "Focus Flow — 24:45", font=get_font(15, "mono"), fill=C_WHITE)
    draw_keycap(draw, fcap_x + fcap_w - 60, fcap_y + 9, "⌘1", font=get_font(11, "mono"), h=26)

    # --- RIGHT DECK (Ambient Intelligence & Tactile Launchpad) ---
    rd_x = ld_x + ld_w + 24
    rd_w = isl_w - ld_w - 96

    # 1. Upper Card: Next Up Calendar Intelligence Tile
    cal_h = 240
    draw.rounded_rectangle([rd_x, stage_y, rd_x + rd_w, stage_y + cal_h], radius=24, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    
    # Date squircle badge
    db_x = rd_x + 28
    db_y = stage_y + 28
    draw.rounded_rectangle([db_x, db_y, db_x + 72, db_y + 72], radius=16, fill=(35, 35, 35, 255), outline=(255, 255, 255, 40), width=1)
    draw.text((db_x + 18, db_y + 10), "OCT", font=get_font(12, "rounded"), fill=C_TITANIUM)
    draw.text((db_x + 18, db_y + 28), "31", font=get_font(28, "rounded"), fill=C_WHITE)

    # Event details
    draw.text((db_x + 94, db_y + 2), "CALENDAR GLANCE  •  IN 14 MINUTES", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((db_x + 94, db_y + 22), "Design Review — Dynamic Island Architecture", font=get_font(20, "rounded"), fill=C_WHITE)
    draw.text((db_x + 94, db_y + 50), "Spatial UX Team  •  Virtual Room A  •  4 Attendees", font=get_font(13), fill=C_TITANIUM)

    # Attendee avatar stack + 1-Tap Join Call Pill
    av_x = rd_x + 28
    av_y = stage_y + 120
    draw.rounded_rectangle([rd_x + 24, av_y, rd_x + rd_w - 24, av_y + 90], radius=18, fill=(28, 28, 28, 255), outline=(255, 255, 255, 20), width=1)
    
    # Avatars
    draw_aa_circle(draw, av_x + 24, av_y + 45, 18, fill=(50, 50, 50, 255), outline=(255, 255, 255, 40))
    draw.text((av_x + 14, av_y + 36), "MN", font=get_font(12, "rounded"), fill=C_WHITE)
    draw_aa_circle(draw, av_x + 54, av_y + 45, 18, fill=(60, 60, 60, 255), outline=(255, 255, 255, 40))
    draw.text((av_x + 46, av_y + 36), "TC", font=get_font(12, "rounded"), fill=C_WHITE)
    draw_aa_circle(draw, av_x + 84, av_y + 45, 18, fill=(40, 40, 40, 255), outline=(255, 255, 255, 40))
    draw.text((av_x + 76, av_y + 36), "+2", font=get_font(12, "rounded"), fill=C_TITANIUM)

    draw.text((av_x + 120, av_y + 35), "Google Meet & FaceTime Video Ready", font=get_font(13), fill=C_WHITE)

    # 1-Tap Join Pill Button
    join_w = 150
    join_h = 42
    join_x = rd_x + rd_w - 24 - join_w - 16
    join_y = av_y + 24
    draw.rounded_rectangle([join_x, join_y, join_x + join_w, join_y + join_h], radius=21, fill=C_WHITE)
    draw.text((join_x + 24, join_y + 11), "Join Call ↗", font=get_font(14, "rounded"), fill=C_BLACK_OLED)
    draw_keycap(draw, join_x + join_w - 48, join_y + 8, "⌘6", font=get_font(10, "mono"), h=26)

    # 2. Lower Row: Tactile Quick Action Cockpit (3 Horizontal Modules)
    act_y = stage_y + cal_h + 16
    act_h = stage_h - cal_h - 16
    
    actions = [
        {"title": "Focus Session", "sub": "25m Sprint Active", "key": "⌘2", "glyph": "⏱"},
        {"title": "YouTube Music", "sub": "Play Midnight City", "key": "⌘3", "glyph": "♫"},
        {"title": "Scratchpad Notes", "sub": "34w Quick Scratch", "key": "⌘4", "glyph": "✎"}
    ]
    
    cw = (rd_w - 32) // 3
    for i, act in enumerate(actions):
        cx = rd_x + i * (cw + 16)
        draw.rounded_rectangle([cx, act_y, cx + cw, act_y + act_h], radius=20, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
        
        # Icon squircle
        draw.rounded_rectangle([cx + 18, act_y + 20, cx + 58, act_y + 60], radius=12, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30), width=1)
        draw.text((cx + 28, act_y + 28), act["glyph"], font=get_font(18), fill=C_WHITE)

        draw_keycap(draw, cx + cw - 48, act_y + 22, act["key"], font=get_font(11, "mono"), h=24)
        
        draw.text((cx + 18, act_y + 76), act["title"], font=get_font(16, "rounded"), fill=C_WHITE)
        draw.text((cx + 18, act_y + 104), act["sub"], font=get_font(12), fill=C_TITANIUM)

    # Bottom Telemetry & Status Rail
    bot_y = isl_y + isl_h - 40
    draw.line([(isl_x + 30, bot_y), (isl_x + isl_w - 30, bot_y)], fill=(255, 255, 255, 18), width=1)
    draw.text((isl_x + 40, bot_y + 12), "ACTIVE PROFILE: Minh Workspace", font=get_font(11, "mono"), fill=C_TITANIUM_MUTED)
    draw.text((isl_x + (isl_w - 480)//2, bot_y + 12), "100% Click-Through in Idle State  •  Zero Occlusion of Browser Tabs", font=get_font(11, "mono"), fill=C_WHITE)
    draw.text((isl_x + isl_w - 200, bot_y + 12), "Press ⎋ to Collapse", font=get_font(11, "mono"), fill=C_TITANIUM_MUTED)

    canvas.save(os.path.join(OUTPUT_DIR, "test_home_redesign_v4.png"))
    print("Saved test_home_redesign_v4.png successfully!")

if __name__ == "__main__":
    render_home_preview()
