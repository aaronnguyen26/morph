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

# -------------------------------------------------------------
# STRICT 3-COLOR APPLE MINIMALIST PALETTE (PURE NEUTRAL MONOCHROME)
# -------------------------------------------------------------
C_BLACK_BG = (10, 10, 10, 255)
C_BLACK_CARD = (16, 16, 16, 255)
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

def draw_aa_circle(draw, cx, cy, r, outline=None, fill=None, width=1):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)

def draw_keycap(draw, x, y, text, font=None, h=24):
    if font is None:
        font = get_font(11, "mono")
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    w = max(tw + 12, 26)
    draw.rounded_rectangle([x, y, x + w, y + h], radius=6, fill=(35, 35, 35, 255), outline=(255, 255, 255, 50), width=1)
    draw.text((x + (w - tw)//2, y + (h - (bbox[3]-bbox[1]))//2 - 1), text, font=font, fill=C_WHITE)
    return w

def draw_pill_outline(draw, pill_x, pill_y, pill_w, pill_h):
    draw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=pill_h // 2, fill=None, outline=(255, 255, 255, 50), width=1)

def draw_extended_pill_hud(draw, x, y, w, h, left_text, left_sub, right_text, right_sub, feature_kind="standard"):
    draw.rounded_rectangle([x - 3, y - 2, x + w + 3, y + h + 4], radius=h//2 + 2, fill=(0, 0, 0, 200))
    draw.rounded_rectangle([x, y, x + w, y + h], radius=h // 2, fill=C_BLACK_OLED, outline=(255, 255, 255, 45), width=1)
    draw.line([(x + h//2, y + 1), (x + w - h//2, y + 1)], fill=(255, 255, 255, 60), width=1)

    font_title = get_font(15, "rounded")
    font_sub = get_font(12)
    font_mono = get_font(15, "mono")

    lx = x + 24
    if feature_kind == "music":
        bars = [8, 18, 28, 20, 10]
        for i, bh in enumerate(bars):
            draw.rounded_rectangle([lx + i * 6, y + h//2 - bh//2, lx + i * 6 + 3, y + h//2 + bh//2], radius=2, fill=C_WHITE)
        lx += 38
    elif feature_kind == "timer":
        draw_aa_circle(draw, lx + 12, y + h//2, 12, outline=C_WHITE, width=2)
        draw.line([(lx + 12, y + h//2), (lx + 12, y + h//2 - 7)], fill=C_WHITE, width=2)
        draw.line([(lx + 12, y + h//2), (lx + 17, y + h//2)], fill=C_WHITE, width=2)
        lx += 34
    else:
        bars = [6, 14, 22, 14, 8]
        for i, bh in enumerate(bars):
            draw.rounded_rectangle([lx + i * 5, y + h//2 - bh//2, lx + i * 5 + 3, y + h//2 + bh//2], radius=2, fill=C_WHITE)
        lx += 34

    draw.text((lx, y + 14), left_text, font=font_title, fill=C_WHITE)
    draw.text((lx, y + 34), left_sub, font=font_sub, fill=C_TITANIUM)

    mid_x = x + w // 2
    draw.rounded_rectangle([mid_x - 70, y, mid_x + 70, y + 26], radius=10, fill=(15, 15, 15, 255), outline=C_TITANIUM_BORDER, width=1)
    draw_aa_circle(draw, mid_x, y + 13, 5, fill=(30, 30, 30, 255), outline=(255, 255, 255, 40))

    rx = x + w - 340
    draw.text((rx, y + 14), right_text, font=font_mono if "Remaining" in right_text or ":" in right_text else font_title, fill=C_WHITE)
    draw.text((rx, y + 34), right_sub, font=font_sub, fill=C_TITANIUM)
    draw_keycap(draw, x + w - 100, y + 20, "⌘⌥M", font=get_font(12, "mono"), h=24)

def setup_page_canvas(width, height, page_num, page_title, subtitle, extended_spec):
    canvas = Image.new("RGBA", (width, height), C_BLACK_BG)
    draw = ImageDraw.Draw(canvas)

    for y in range(height):
        ratio = y / height
        v = int(10 + 4 * (1 - abs(ratio - 0.5) * 2))
        draw.line([(0, y), (width, y)], fill=(v, v, v, 255))

    font_brand = get_font(22, "rounded")
    font_page_title = get_font(28)
    font_section = get_font(18, "rounded")
    font_desc = get_font(14)

    draw.text((80, 36), "  Apple Dynamic Island Architecture", font=font_brand, fill=C_TITANIUM)
    title_text = f"PAGE {page_num:02d} — {page_title.upper()}"
    bbox = draw.textbbox((0, 0), title_text, font=font_page_title)
    draw.text((width - 80 - (bbox[2]-bbox[0]), 32), title_text, font=font_page_title, fill=C_WHITE)
    draw.line([(80, 76), (width - 80, 76)], fill=C_TITANIUM_BORDER, width=1)

    t1_y = 96
    t1_w = width - 160
    t1_h = 220
    draw.rounded_rectangle([80, t1_y, 80 + t1_w, t1_y + t1_h], radius=18, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
    draw.text((108, t1_y + 16), "STATE 2 — THE EXTENDED MORPH PILL (LIVE BACKGROUND ACTIVITY HUD)", font=font_section, fill=C_WHITE)
    draw.text((108, t1_y + 38), f"Elongated Dynamic Island pill showing live telemetry while working in background apps: {extended_spec['summary']}", font=font_desc, fill=C_TITANIUM)

    ep_w = 1100
    ep_h = 64
    ep_x = 80 + (t1_w - ep_w) // 2
    ep_y = t1_y + 70

    draw_extended_pill_hud(
        draw,
        ep_x,
        ep_y,
        ep_w,
        ep_h,
        extended_spec["left_title"],
        extended_spec["left_sub"],
        extended_spec["right_title"],
        extended_spec["right_sub"],
        feature_kind=extended_spec.get("kind", "standard")
    )

    draw.text((ep_x + 24, ep_y + ep_h + 8), "◀ LEFT WING (LIVE CONTEXT)", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)
    mid_ep = ep_x + ep_w // 2
    draw.text((mid_ep - 70, ep_y + ep_h + 8), "◆ HARDWARE NOTCH CLEARANCE", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)
    draw.text((ep_x + ep_w - 240, ep_y + ep_h + 8), "RIGHT WING (LIVE TELEMETRY) ▶", font=get_font(10, "mono"), fill=C_TITANIUM_MUTED)
    draw.text((108, t1_y + t1_h - 22), "✓ 100% Universal Coexistence: Zero occlusion of active browser tabs, search omnibox, or editor toolbars.", font=get_font(12), fill=C_WHITE)

    t2_y = t1_y + t1_h + 24
    draw.text((80, t2_y), f"STATE 3 — THE FULL BIG UI FOR MORPH (AUTONOMOUS DYNAMIC ISLAND MODAL) — {subtitle.upper()}", font=font_section, fill=C_WHITE)
    draw.text((80, t2_y + 22), "Authentic Apple Fluid Architecture: Pitch Black OLED squircle floating 14pt beneath the MacBook display notch", font=font_desc, fill=C_TITANIUM)

    desk_y = t2_y + 50
    desk_w = width - 160
    desk_h = height - desk_y - 40
    draw.rounded_rectangle([80, desk_y, 80 + desk_w, desk_y + desk_h], radius=24, fill=(14, 14, 14, 255), outline=C_TITANIUM_BORDER, width=1)

    mb_h = 36
    draw.rectangle([80, desk_y, 80 + desk_w, desk_y + mb_h], fill=(8, 8, 8, 255))
    draw.line([(80, desk_y + mb_h), (80 + desk_w, desk_y + mb_h)], fill=(255, 255, 255, 20), width=1)
    draw.text((108, desk_y + 9), "", font=get_font(16), fill=C_WHITE)
    draw.text((134, desk_y + 9), "Workspace", font=get_font(13, "rounded"), fill=C_WHITE)
    draw.text((214, desk_y + 9), "File   Edit   View   Window   Help", font=get_font(13), fill=C_TITANIUM)
    draw.text((80 + desk_w - 260, desk_y + 9), "Wi-Fi   Battery 98%   Sat Oct 31  10:42 AM", font=get_font(12, "mono"), fill=C_TITANIUM)

    notch_w = 210
    notch_h = 32
    notch_x = 80 + (desk_w - notch_w) // 2
    draw.rounded_rectangle([notch_x, desk_y, notch_x + notch_w, desk_y + notch_h], radius=14, fill=C_BLACK_OLED)
    draw_aa_circle(draw, notch_x + notch_w // 2 - 12, desk_y + 16, 5, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30))
    draw_aa_circle(draw, notch_x + notch_w // 2 + 16, desk_y + 16, 3, fill=(255, 255, 255, 50))

    gap_y = desk_y + notch_h
    gap_h = 24
    draw.line([(notch_x + notch_w + 30, gap_y), (notch_x + notch_w + 30, gap_y + gap_h)], fill=C_TITANIUM_MUTED, width=1)
    draw.text((notch_x + notch_w + 40, gap_y + 4), "14pt Breathing Clearance", font=get_font(11, "mono"), fill=C_TITANIUM)

    isl_w = 1720
    isl_h = 740
    isl_x = 80 + (desk_w - isl_w) // 2
    isl_y = gap_y + gap_h

    draw.rounded_rectangle([isl_x - 8, isl_y - 4, isl_x + isl_w + 8, isl_y + isl_h + 16], radius=44, fill=(0, 0, 0, 240))
    draw.rounded_rectangle([isl_x, isl_y, isl_x + isl_w, isl_y + isl_h], radius=40, fill=C_BLACK_OLED, outline=(255, 255, 255, 35), width=1)
    draw.line([(isl_x + 40, isl_y + 1), (isl_x + isl_w - 40, isl_y + 1)], fill=(255, 255, 255, 60), width=1)

    drag_w = 64
    drag_h = 5
    draw.rounded_rectangle([isl_x + (isl_w - drag_w)//2, isl_y + 12, isl_x + (isl_w + drag_w)//2, isl_y + 12 + drag_h], radius=3, fill=(142, 142, 142, 100))

    return canvas, draw, (isl_x, isl_y, isl_w, isl_h)

def draw_top_nav(draw, isl_x, isl_y, isl_w, active_page="Home"):
    nav_y = isl_y + 28
    tabs = ["Home", "Focus Timer", "Music", "Notes", "Calendar", "Profile"]
    tab_x = isl_x + 40
    for tab in tabs:
        if tab == active_page:
            bbox = draw.textbbox((0, 0), tab, font=get_font(13, "rounded"))
            tw = bbox[2] - bbox[0] + 32
            draw.rounded_rectangle([tab_x, nav_y, tab_x + tw, nav_y + 30], radius=15, fill=C_WHITE)
            draw.text((tab_x + 16, nav_y + 6), tab, font=get_font(13, "rounded"), fill=C_BLACK_OLED)
            tab_x += tw + 8
        else:
            bbox = draw.textbbox((0, 0), tab, font=get_font(13))
            tw = bbox[2] - bbox[0] + 24
            draw.rounded_rectangle([tab_x, nav_y, tab_x + tw, nav_y + 30], radius=15, fill=(25, 25, 25, 255), outline=(255, 255, 255, 20), width=1)
            draw.text((tab_x + 12, nav_y + 7), tab, font=get_font(13), fill=C_TITANIUM)
            tab_x += tw + 8

    draw_keycap(draw, isl_x + isl_w - 120, nav_y + 2, "⌘K", font=get_font(12, "mono"), h=26)
    draw.text((isl_x + isl_w - 60, nav_y + 5), "•••", font=get_font(14), fill=C_TITANIUM)
    draw.line([(isl_x + 30, isl_y + 72), (isl_x + isl_w - 30, isl_y + 72)], fill=(255, 255, 255, 18), width=1)

def draw_bottom_rail(draw, isl_x, isl_y, isl_w, isl_h, profile="Minh Workspace"):
    bot_y = isl_y + isl_h - 40
    draw.line([(isl_x + 30, bot_y), (isl_x + isl_w - 30, bot_y)], fill=(255, 255, 255, 18), width=1)
    draw.text((isl_x + 40, bot_y + 12), f"ACTIVE PROFILE: {profile}", font=get_font(11, "mono"), fill=C_TITANIUM_MUTED)
    draw.text((isl_x + (isl_w - 480)//2, bot_y + 12), "100% Click-Through in Idle State   Zero Occlusion of Browser Tabs", font=get_font(11, "mono"), fill=C_WHITE)
    draw.text((isl_x + isl_w - 200, bot_y + 12), "Press ⎋ to Collapse", font=get_font(11, "mono"), fill=C_TITANIUM_MUTED)

# =========================================================================
# PAGE BUILDERS (01 - 10)
# =========================================================================

def build_page_01():
    extended_spec = {
        "summary": "Focus Flow active with dynamic breath waves and countdown",
        "left_title": "Morph Ambient Active",
        "left_sub": "Focus Block in Progress",
        "right_title": "23:45 Remaining",
        "right_sub": "Deep Work Session 3 of 4",
        "kind": "standard"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 1, "Home", "Ambient Intelligence Hub", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Home")

    stage_y = iy + 86
    stage_h = ih - 138

    # Left Deck: Living Morphy Core & Focus Flow
    ld_w = 720
    ld_x = ix + 36
    draw.rounded_rectangle([ld_x, stage_y, ld_x + ld_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    core_cx = ld_x + ld_w // 2
    core_cy = stage_y + 150
    draw_aa_circle(draw, core_cx, core_cy, 96, outline=(255, 255, 255, 15), width=1)
    draw_aa_circle(draw, core_cx, core_cy, 70, outline=(255, 255, 255, 25), width=1)
    draw_aa_circle(draw, core_cx, core_cy, 46, outline=(255, 255, 255, 40), width=1)

    core_bars = [12, 22, 36, 52, 38, 24, 14]
    cb_x = core_cx - (len(core_bars) * 7) // 2
    for i, cbh in enumerate(core_bars):
        draw.rounded_rectangle([cb_x + i * 7, core_cy - cbh//2, cb_x + i * 7 + 4, core_cy + cbh//2], radius=2, fill=C_WHITE)

    draw.text((core_cx - 150, stage_y + 270), "Good afternoon, Minh", font=get_font(26, "rounded"), fill=C_WHITE)
    draw.text((core_cx - 120, stage_y + 308), "Deep Focus Flow Active", font=get_font(15), fill=C_TITANIUM)

    fcap_w = 340
    fcap_h = 44
    fcap_x = core_cx - fcap_w // 2
    fcap_y = stage_y + 346
    draw.rounded_rectangle([fcap_x, fcap_y, fcap_x + fcap_w, fcap_y + fcap_h], radius=22, fill=(35, 35, 35, 255), outline=(255, 255, 255, 45), width=1)
    draw.text((fcap_x + 22, fcap_y + 12), "Focus Flow — 24:45", font=get_font(15, "mono"), fill=C_WHITE)
    draw_keycap(draw, fcap_x + fcap_w - 60, fcap_y + 9, "⌘1", font=get_font(11, "mono"), h=26)

    # Right Deck: Calendar Tile + Action Cockpit
    rd_x = ld_x + ld_w + 24
    rd_w = iw - ld_w - 96

    # Upper Calendar Tile
    cal_h = 240
    draw.rounded_rectangle([rd_x, stage_y, rd_x + rd_w, stage_y + cal_h], radius=24, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    db_x = rd_x + 28
    db_y = stage_y + 28
    draw.rounded_rectangle([db_x, db_y, db_x + 72, db_y + 72], radius=16, fill=(35, 35, 35, 255), outline=(255, 255, 255, 40), width=1)
    draw.text((db_x + 18, db_y + 10), "OCT", font=get_font(12, "rounded"), fill=C_TITANIUM)
    draw.text((db_x + 18, db_y + 28), "31", font=get_font(28, "rounded"), fill=C_WHITE)

    draw.text((db_x + 94, db_y + 2), "CALENDAR GLANCE   IN 14 MINUTES", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((db_x + 94, db_y + 22), "Design Review — Dynamic Island Architecture", font=get_font(20, "rounded"), fill=C_WHITE)
    draw.text((db_x + 94, db_y + 50), "Spatial UX Team   Virtual Room A   4 Attendees", font=get_font(13), fill=C_TITANIUM)

    av_y = stage_y + 120
    draw.rounded_rectangle([rd_x + 24, av_y, rd_x + rd_w - 24, av_y + 90], radius=18, fill=(28, 28, 28, 255), outline=(255, 255, 255, 20), width=1)
    draw_aa_circle(draw, rd_x + 52, av_y + 45, 18, fill=(50, 50, 50, 255), outline=(255, 255, 255, 40))
    draw.text((rd_x + 42, av_y + 36), "MN", font=get_font(12, "rounded"), fill=C_WHITE)
    draw_aa_circle(draw, rd_x + 82, av_y + 45, 18, fill=(60, 60, 60, 255), outline=(255, 255, 255, 40))
    draw.text((rd_x + 74, av_y + 36), "TC", font=get_font(12, "rounded"), fill=C_WHITE)
    draw_aa_circle(draw, rd_x + 112, av_y + 45, 18, fill=(40, 40, 40, 255), outline=(255, 255, 255, 40))
    draw.text((rd_x + 104, av_y + 36), "+2", font=get_font(12, "rounded"), fill=C_TITANIUM)
    draw.text((rd_x + 148, av_y + 35), "Google Meet & FaceTime Video Ready", font=get_font(13), fill=C_WHITE)

    join_w = 150
    join_h = 42
    join_x = rd_x + rd_w - 24 - join_w - 16
    join_y = av_y + 24
    draw.rounded_rectangle([join_x, join_y, join_x + join_w, join_y + join_h], radius=21, fill=C_WHITE)
    draw.text((join_x + 24, join_y + 11), "Join Call ↗", font=get_font(14, "rounded"), fill=C_BLACK_OLED)
    draw_keycap(draw, join_x + join_w - 48, join_y + 8, "⌘6", font=get_font(10, "mono"), h=26)

    # Lower Row: 3 Action Modules
    act_y = stage_y + cal_h + 16
    act_h = stage_h - cal_h - 16
    actions = [
        {"title": "Focus Session", "sub": "Start 25m Timer", "key": "⌘2", "glyph": "⏱"},
        {"title": "YouTube Music", "sub": "Play Midnight City", "key": "⌘3", "glyph": "♫"},
        {"title": "Scratchpad Notes", "sub": "34w Quick Scratch", "key": "⌘4", "glyph": "✎"}
    ]
    cw = (rd_w - 32) // 3
    for i, act in enumerate(actions):
        cx = rd_x + i * (cw + 16)
        draw.rounded_rectangle([cx, act_y, cx + cw, act_y + act_h], radius=20, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
        draw.rounded_rectangle([cx + 18, act_y + 20, cx + 58, act_y + 60], radius=12, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30), width=1)
        draw.text((cx + 28, act_y + 28), act["glyph"], font=get_font(18), fill=C_WHITE)
        draw_keycap(draw, cx + cw - 48, act_y + 22, act["key"], font=get_font(11, "mono"), h=24)
        draw.text((cx + 18, act_y + 76), act["title"], font=get_font(16, "rounded"), fill=C_WHITE)
        draw.text((cx + 18, act_y + 104), act["sub"], font=get_font(12), fill=C_TITANIUM)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_01.png"))
    print("Generated morph_apple_dynamic_island_page_01.png")

def build_page_02():
    extended_spec = {
        "summary": "Rotary timer running in background with active tabular countdown",
        "left_title": "Phase 1: Deep Focus",
        "left_sub": "Pomodoro Session 3 of 4",
        "right_title": "23:45 Remaining",
        "right_sub": "Space to Pause / Resume",
        "kind": "timer"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 2, "Focus Timer", "Pomodoro Chronograph Dial", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Focus Timer")

    stage_y = iy + 86
    stage_h = ih - 138

    # Left Deck: 110pt Apple Watch Chronograph Dial
    ld_w = 720
    ld_x = ix + 36
    draw.rounded_rectangle([ld_x, stage_y, ld_x + ld_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    dial_cx = ld_x + ld_w // 2
    dial_cy = stage_y + 190
    dial_r = 140

    # Outer tick marks (60 ticks)
    for i in range(60):
        angle = math.radians(i * 6 - 90)
        is_major = (i % 5 == 0)
        t_len = 12 if is_major else 6
        r1 = dial_r - t_len
        r2 = dial_r
        x1 = dial_cx + r1 * math.cos(angle)
        y1 = dial_cy + r1 * math.sin(angle)
        x2 = dial_cx + r2 * math.cos(angle)
        y2 = dial_cy + r2 * math.sin(angle)
        draw.line([(x1, y1), (x2, y2)], fill=C_WHITE if is_major else C_TITANIUM_MUTED, width=2 if is_major else 1)

    # Circular progress arc (23:45 out of 25:00 = ~95% complete)
    draw_aa_circle(draw, dial_cx, dial_cy, dial_r - 20, outline=(255, 255, 255, 30), width=4)
    # Active arc
    draw.arc([dial_cx - (dial_r - 20), dial_cy - (dial_r - 20), dial_cx + (dial_r - 20), dial_cy + (dial_r - 20)], start=-90, end=250, fill=C_WHITE, width=4)

    # Center Countdown Typography
    draw.text((dial_cx - 100, dial_cy - 36), "23:45", font=get_font(46, "mono"), fill=C_WHITE)
    draw.text((dial_cx - 56, dial_cy + 22), "DEEP FOCUS", font=get_font(13, "rounded"), fill=C_TITANIUM)

    # Play/Pause tap glyph
    draw.text((dial_cx - 68, stage_y + 380), "␣ Space to Pause", font=get_font(14, "mono"), fill=C_TITANIUM)

    # Right Deck: Controls, Presets & Transport
    rd_x = ld_x + ld_w + 24
    rd_w = iw - ld_w - 96

    # 1. Mode Segmented Tabs
    mode_y = stage_y
    modes = ["Focus (25m)", "Short Break (5m)", "Long Break (15m)", "Quick Sprint (1m)"]
    draw.rounded_rectangle([rd_x, mode_y, rd_x + rd_w, mode_y + 54], radius=27, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    mx = rd_x + 8
    for i, m in enumerate(modes):
        if i == 0:
            draw.rounded_rectangle([mx, mode_y + 6, mx + 190, mode_y + 48], radius=21, fill=C_WHITE)
            draw.text((mx + 28, mode_y + 17), m, font=get_font(13, "rounded"), fill=C_BLACK_OLED)
            mx += 198
        else:
            draw.text((mx + 20, mode_y + 18), m, font=get_font(13), fill=C_TITANIUM)
            mx += 190

    # 2. Quick Presets Card
    pre_y = mode_y + 70
    draw.rounded_rectangle([rd_x, pre_y, rd_x + rd_w, pre_y + 130], radius=22, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    draw.text((rd_x + 28, pre_y + 20), "QUICK TIMER PRESETS", font=get_font(11, "mono"), fill=C_TITANIUM)
    presets = [("25m", "Standard Pomodoro"), ("15m", "Mid Focus"), ("5m", "Short Rest"), ("1m", "Instant Test")]
    pw = (rd_w - 56 - 36) // 4
    for i, (p_time, p_label) in enumerate(presets):
        px = rd_x + 28 + i * (pw + 12)
        draw.rounded_rectangle([px, pre_y + 46, px + pw, pre_y + 108], radius=14, fill=(30, 30, 30, 255), outline=(255, 255, 255, 25), width=1)
        draw.text((px + 14, pre_y + 56), p_time, font=get_font(18, "rounded"), fill=C_WHITE)
        draw.text((px + 14, pre_y + 84), p_label, font=get_font(11), fill=C_TITANIUM)

    # 3. Momentum & Streak
    str_y = pre_y + 146
    draw.rounded_rectangle([rd_x, str_y, rd_x + rd_w, str_y + 110], radius=22, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    draw.text((rd_x + 28, str_y + 22), "DAILY FOCUS MOMENTUM", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((rd_x + 28, str_y + 48), "2h 15m Focused Today", font=get_font(22, "rounded"), fill=C_WHITE)
    draw.text((rd_x + 28, str_y + 80), "4 Sessions Completed   14-Day Streak Maintained", font=get_font(13), fill=C_TITANIUM)
    draw_keycap(draw, rd_x + rd_w - 110, str_y + 40, "⌘P Pin", font=get_font(12, "mono"), h=28)

    # 4. Transport Buttons Strip
    tra_y = str_y + 126
    tb_w = (rd_w - 32) // 3
    t_btns = [("Pause Timer", "Space", C_WHITE, C_BLACK_OLED), ("Reset Session", "⇧⌘R", (35, 35, 35, 255), C_WHITE), ("Skip to Break", "⇧⌘S", (35, 35, 35, 255), C_WHITE)]
    for i, (b_title, b_key, b_fill, b_text_col) in enumerate(t_btns):
        bx = rd_x + i * (tb_w + 16)
        draw.rounded_rectangle([bx, tra_y, bx + tb_w, tra_y + 54], radius=27, fill=b_fill, outline=(255, 255, 255, 35) if b_fill != C_WHITE else None, width=1)
        draw.text((bx + 24, tra_y + 17), b_title, font=get_font(14, "rounded"), fill=b_text_col)
        draw_keycap(draw, bx + tb_w - 64, tra_y + 13, b_key, font=get_font(11, "mono"), h=28)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_02.png"))
    print("Generated morph_apple_dynamic_island_page_02.png")

def build_page_03():
    extended_spec = {
        "summary": "Audio playback waveform active with live scrubbing & volume control",
        "left_title": "Midnight City — M83",
        "left_sub": "Lossless 24-bit 96kHz",
        "right_title": "2:14 / 3:56",
        "right_sub": "AirPods Max Spatial Audio",
        "kind": "music"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 3, "Music Player", "Now Playing Studio", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Music")

    stage_y = iy + 86
    stage_h = ih - 138

    # Left Deck: Album Art & Living Waveform
    ld_w = 720
    ld_x = ix + 36
    draw.rounded_rectangle([ld_x, stage_y, ld_x + ld_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    # Album Art Squircle
    art_size = 200
    art_x = ld_x + (ld_w - art_size) // 2
    art_y = stage_y + 36
    draw.rounded_rectangle([art_x, art_y, art_x + art_size, art_y + art_size], radius=28, fill=(35, 35, 35, 255), outline=(255, 255, 255, 45), width=1)
    draw.text((art_x + 65, art_y + 80), "♫", font=get_font(48), fill=C_WHITE)
    draw.rounded_rectangle([art_x + 14, art_y + 14, art_x + 76, art_y + 36], radius=8, fill=(15, 15, 15, 220))
    draw.text((art_x + 22, art_y + 18), "LOSSLESS", font=get_font(10, "mono"), fill=C_WHITE)

    # Title & Artist
    draw.text((ld_x + 60, stage_y + 260), "Midnight City", font=get_font(28, "rounded"), fill=C_WHITE)
    draw.text((ld_x + 60, stage_y + 298), "M83 — Hurry Up, We're Dreaming", font=get_font(16), fill=C_TITANIUM)

    # Animated Equalizer Waveform
    wb_x = ld_x + 60
    wb_y = stage_y + 350
    wbars = [14, 26, 42, 58, 36, 48, 62, 30, 22, 44, 32, 18, 28, 50, 20]
    for i, wh in enumerate(wbars):
        draw.rounded_rectangle([wb_x + i * 14, wb_y - wh//2, wb_x + i * 14 + 6, wb_y + wh//2], radius=3, fill=C_WHITE)

    # Right Deck: Scrubber, Transport & Route
    rd_x = ld_x + ld_w + 24
    rd_w = iw - ld_w - 96

    # 1. Scrubber & Time Bar
    sc_y = stage_y + 20
    draw.rounded_rectangle([rd_x, sc_y, rd_x + rd_w, sc_y + 120], radius=22, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    draw.text((rd_x + 28, sc_y + 22), "TRACK PROGRESS", font=get_font(11, "mono"), fill=C_TITANIUM)
    
    # Progress Track
    draw.rounded_rectangle([rd_x + 28, sc_y + 58, rd_x + rd_w - 28, sc_y + 68], radius=5, fill=(35, 35, 35, 255))
    progress_w = int((rd_w - 56) * 0.58)
    draw.rounded_rectangle([rd_x + 28, sc_y + 58, rd_x + 28 + progress_w, sc_y + 68], radius=5, fill=C_WHITE)
    draw_aa_circle(draw, rd_x + 28 + progress_w, sc_y + 63, 8, fill=C_WHITE)
    draw.text((rd_x + 28, sc_y + 80), "2:14", font=get_font(13, "mono"), fill=C_WHITE)
    draw.text((rd_x + rd_w - 74, sc_y + 80), "-1:42", font=get_font(13, "mono"), fill=C_TITANIUM)

    # 2. Transport Cockpit
    tra_y = sc_y + 138
    draw.rounded_rectangle([rd_x, tra_y, rd_x + rd_w, tra_y + 160], radius=24, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    
    tc_cx = rd_x + rd_w // 2
    tc_cy = tra_y + 80
    # Play/Pause Circle
    draw_aa_circle(draw, tc_cx, tc_cy, 36, fill=C_WHITE)
    draw.text((tc_cx - 10, tc_cy - 16), "❚❚", font=get_font(22), fill=C_BLACK_OLED)
    draw_keycap(draw, tc_cx - 24, tc_cy + 44, "Space", font=get_font(10, "mono"), h=22)

    # Previous / Next Buttons
    draw_aa_circle(draw, tc_cx - 110, tc_cy, 28, fill=(35, 35, 35, 255), outline=(255, 255, 255, 35))
    draw.text((tc_cx - 122, tc_cy - 12), "⏮", font=get_font(18), fill=C_WHITE)
    draw_keycap(draw, tc_cx - 126, tc_cy + 36, "⌘←", font=get_font(10, "mono"), h=22)

    draw_aa_circle(draw, tc_cx + 110, tc_cy, 28, fill=(35, 35, 35, 255), outline=(255, 255, 255, 35))
    draw.text((tc_cx + 98, tc_cy - 12), "⏭", font=get_font(18), fill=C_WHITE)
    draw_keycap(draw, tc_cx + 94, tc_cy + 36, "⌘→", font=get_font(10, "mono"), h=22)

    # Shuffle & Like
    draw.text((rd_x + 60, tc_cy - 10), "🔀", font=get_font(20), fill=C_TITANIUM)
    draw.text((rd_x + rd_w - 90, tc_cy - 10), "♥", font=get_font(22), fill=C_WHITE)

    # 3. Volume & AirPlay
    vol_y = tra_y + 178
    draw.rounded_rectangle([rd_x, vol_y, rd_x + rd_w, vol_y + 90], radius=20, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    draw.text((rd_x + 28, vol_y + 34), "🔈", font=get_font(18), fill=C_TITANIUM)
    draw.rounded_rectangle([rd_x + 64, vol_y + 40, rd_x + 400, vol_y + 48], radius=4, fill=(35, 35, 35, 255))
    draw.rounded_rectangle([rd_x + 64, vol_y + 40, rd_x + 320, vol_y + 48], radius=4, fill=C_WHITE)
    draw.text((rd_x + 412, vol_y + 34), "🔊", font=get_font(18), fill=C_WHITE)

    # AirPlay pill
    draw.rounded_rectangle([rd_x + rd_w - 280, vol_y + 24, rd_x + rd_w - 28, vol_y + 66], radius=21, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((rd_x + rd_w - 256, vol_y + 34), "AirPods Max ⌵", font=get_font(13, "rounded"), fill=C_WHITE)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_03.png"))
    print("Generated morph_apple_dynamic_island_page_03.png")

def build_page_04():
    extended_spec = {
        "summary": "Pinned quick note indicator with real-time word count telemetry",
        "left_title": "Quick Notes Pinned",
        "left_sub": "34 Words Recorded",
        "right_title": "⌘⇧P to Unpin",
        "right_sub": "Auto-Saved to iCloud",
        "kind": "standard"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 4, "Scratchpad Notes", "Quick Notes Floating Glasspad", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Notes")

    stage_y = iy + 86
    stage_h = ih - 138

    # Full Width Distraction-Free Floating Notes Canvas
    nc_w = iw - 72
    nc_x = ix + 36
    draw.rounded_rectangle([nc_x, stage_y, nc_x + nc_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    # Top Toolbar Strip
    tb_y = stage_y + 20
    draw.text((nc_x + 28, tb_y + 6), "iCloud Quick Notes", font=get_font(18, "rounded"), fill=C_WHITE)
    draw.text((nc_x + 210, tb_y + 8), "34 words | 210 characters", font=get_font(12, "mono"), fill=C_TITANIUM)
    draw.text((nc_x + 400, tb_y + 8), "Auto-saved 12s ago", font=get_font(12), fill=C_TITANIUM_MUTED)

    # Action Pills on Right
    actions = [("+ Checklist", "⌘T"), ("Pin Note", "⌘⇧P"), ("Copy All", "⌘⇧C"), ("New Note", "⌘N")]
    ax = nc_x + nc_w - 28
    for label, key in reversed(actions):
        bbox = draw.textbbox((0, 0), label, font=get_font(12, "rounded"))
        lw = bbox[2] - bbox[0]
        btn_w = lw + 48
        ax -= btn_w
        draw.rounded_rectangle([ax, tb_y, ax + btn_w, tb_y + 32], radius=16, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30), width=1)
        draw.text((ax + 12, tb_y + 8), label, font=get_font(12, "rounded"), fill=C_WHITE)
        draw_keycap(draw, ax + btn_w - 30, tb_y + 5, key, font=get_font(10, "mono"), h=22)
        ax -= 10

    draw.line([(nc_x + 24, tb_y + 44), (nc_x + nc_w - 24, tb_y + 44)], fill=(255, 255, 255, 18), width=1)

    # Editor Content
    ed_y = tb_y + 64
    draw.text((nc_x + 40, ed_y), "# Dynamic Island System Architecture", font=get_font(24, "rounded"), fill=C_WHITE)
    draw.text((nc_x + 40, ed_y + 40), "Universal state mechanics across macOS Sequoia desktop and pro applications.", font=get_font(15), fill=C_TITANIUM)

    items = [
        ("✓", "Audit full 10-page feature inventory (100% functionality preserved)"),
        ("✓", "Implement 14pt vertical breathing clearance below hardware notch"),
        ("✓", "Enforce 100% click-through in State 1 resting capsule for zero browser tab occlusion"),
        ("◻", "Verify universal state transitions across Music, Timer, and Calendar HUDs")
    ]
    for i, (check, itext) in enumerate(items):
        iy_item = ed_y + 90 + i * 36
        draw.rounded_rectangle([nc_x + 40, iy_item + 2, nc_x + 62, iy_item + 24], radius=6, fill=(35, 35, 35, 255), outline=(255, 255, 255, 40), width=1)
        draw.text((nc_x + 46, iy_item + 4), check, font=get_font(12, "mono"), fill=C_WHITE if check == "✓" else C_TITANIUM)
        draw.text((nc_x + 76, iy_item + 3), itext, font=get_font(15), fill=C_WHITE if check != "◻" else C_TITANIUM)

    # Quote block
    qy = ed_y + 260
    draw.line([(nc_x + 40, qy), (nc_x + 40, qy + 46)], fill=C_WHITE, width=3)
    draw.text((nc_x + 56, qy + 4), '"Simplicity is about subtracting the obvious and adding the meaningful."', font=get_font(15, "rounded"), fill=C_WHITE)
    draw.text((nc_x + 56, qy + 26), "— John Maeda, The Laws of Simplicity", font=get_font(13), fill=C_TITANIUM)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_04.png"))
    print("Generated morph_apple_dynamic_island_page_04.png")

def build_page_05():
    extended_spec = {
        "summary": "Next meeting alert with direct one-tap video conference join pill",
        "left_title": "Design Review in 14m",
        "left_sub": "Virtual Room A   Spatial UX",
        "right_title": "Join Call ↗",
        "right_sub": "FaceTime & Google Meet",
        "kind": "standard"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 5, "Calendar & Schedule", "Smart Agenda & FaceTime Deck", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Calendar")

    stage_y = iy + 86
    stage_h = ih - 138

    # Left Deck: 7-Column Mini Month Grid
    ld_w = 640
    ld_x = ix + 36
    draw.rounded_rectangle([ld_x, stage_y, ld_x + ld_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    draw.text((ld_x + 28, stage_y + 24), "October 2026", font=get_font(20, "rounded"), fill=C_WHITE)
    draw.text((ld_x + ld_w - 70, stage_y + 24), "<   >", font=get_font(16, "mono"), fill=C_TITANIUM)

    # Days of week
    dow = ["S", "M", "T", "W", "T", "F", "S"]
    cw = (ld_w - 56) // 7
    for i, d in enumerate(dow):
        draw.text((ld_x + 28 + i * cw + cw//2 - 6, stage_y + 66), d, font=get_font(12, "mono"), fill=C_TITANIUM_MUTED)

    # Month days
    days = [
        ["", "", "", "", 1, 2, 3],
        [4, 5, 6, 7, 8, 9, 10],
        [11, 12, 13, 14, 15, 16, 17],
        [18, 19, 20, 21, 22, 23, 24],
        [25, 26, 27, 28, 29, 30, 31]
    ]
    for row_idx, row in enumerate(days):
        for col_idx, day_val in enumerate(row):
            if day_val != "":
                dx = ld_x + 28 + col_idx * cw + cw//2
                dy = stage_y + 104 + row_idx * 40
                if day_val == 31:
                    draw_aa_circle(draw, dx, dy + 8, 16, fill=C_WHITE)
                    draw.text((dx - 9, dy), str(day_val), font=get_font(13, "rounded"), fill=C_BLACK_OLED)
                else:
                    draw.text((dx - 8, dy), str(day_val), font=get_font(13), fill=C_WHITE)

    # Calendar Filter Tags
    ft_y = stage_y + 330
    draw.line([(ld_x + 24, ft_y), (ld_x + ld_w - 24, ft_y)], fill=(255, 255, 255, 18), width=1)
    draw.text((ld_x + 28, ft_y + 16), "CALENDARS", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.rounded_rectangle([ld_x + 28, ft_y + 40, ld_x + 120, ft_y + 68], radius=14, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((ld_x + 44, ft_y + 48), "Work (3)", font=get_font(12, "rounded"), fill=C_WHITE)
    draw.rounded_rectangle([ld_x + 130, ft_y + 40, ld_x + 230, ft_y + 68], radius=14, fill=(35, 35, 35, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((ld_x + 144, ft_y + 48), "Personal (1)", font=get_font(12, "rounded"), fill=C_TITANIUM)

    # Right Deck: Upcoming Agenda & Video Join
    rd_x = ld_x + ld_w + 24
    rd_w = iw - ld_w - 96

    # 1. Primary Upcoming Card
    up_h = 240
    draw.rounded_rectangle([rd_x, stage_y, rd_x + rd_w, stage_y + up_h], radius=24, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    draw.text((rd_x + 28, stage_y + 24), "UPCOMING SESSION   10:45 AM - 11:30 AM", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((rd_x + 28, stage_y + 50), "Design Review — Dynamic Island Architecture", font=get_font(22, "rounded"), fill=C_WHITE)
    draw.text((rd_x + 28, stage_y + 82), "Lead Architect Review   Virtual Room A   4 Attendees", font=get_font(14), fill=C_TITANIUM)

    # Join video pill
    draw.rounded_rectangle([rd_x + 28, stage_y + 130, rd_x + rd_w - 28, stage_y + 210], radius=20, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30), width=1)
    draw_aa_circle(draw, rd_x + 58, stage_y + 170, 18, fill=(50, 50, 50, 255), outline=(255, 255, 255, 40))
    draw.text((rd_x + 48, stage_y + 161), "MN", font=get_font(12, "rounded"), fill=C_WHITE)
    draw_aa_circle(draw, rd_x + 88, stage_y + 170, 18, fill=(60, 60, 60, 255), outline=(255, 255, 255, 40))
    draw.text((rd_x + 80, stage_y + 161), "TC", font=get_font(12, "rounded"), fill=C_WHITE)
    draw.text((rd_x + 120, stage_y + 160), "FaceTime Video & Google Meet Sync", font=get_font(14), fill=C_WHITE)

    draw.rounded_rectangle([rd_x + rd_w - 210, stage_y + 148, rd_x + rd_w - 48, stage_y + 192], radius=22, fill=C_WHITE)
    draw.text((rd_x + rd_w - 188, stage_y + 160), "Join Video Call ↗", font=get_font(13, "rounded"), fill=C_BLACK_OLED)

    # 2. Agenda Queue
    ag_y = stage_y + up_h + 16
    draw.rounded_rectangle([rd_x, ag_y, rd_x + rd_w, stage_y + stage_h], radius=22, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    draw.text((rd_x + 28, ag_y + 20), "LATER TODAY", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((rd_x + 28, ag_y + 46), "2:00 PM — Engineering Sync (Xcode Project Structure)", font=get_font(14, "rounded"), fill=C_WHITE)
    draw.text((rd_x + 28, ag_y + 74), "4:30 PM — 1:1 Architecture Review with Lead", font=get_font(14, "rounded"), fill=C_WHITE)
    draw_keycap(draw, rd_x + rd_w - 130, ag_y + 40, "+ Event ⌘N", font=get_font(11, "mono"), h=28)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_05.png"))
    print("Generated morph_apple_dynamic_island_page_05.png")

def build_page_06():
    extended_spec = {
        "summary": "Apple ID profile status with cross-device iCloud synchronization",
        "left_title": "Minh Nguyen — In Sync",
        "left_sub": "MacBook Pro & iPhone 16 Pro",
        "right_title": "4 Devices Active",
        "right_sub": "Deep Focus Mode",
        "kind": "standard"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 6, "Profile & Preferences", "Apple ID Control Center", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Profile")

    stage_y = iy + 86
    stage_h = ih - 138

    # Left Deck: Apple ID Profile & Momentum
    ld_w = 640
    ld_x = ix + 36
    draw.rounded_rectangle([ld_x, stage_y, ld_x + ld_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    # Avatar Circle
    av_cx = ld_x + ld_w // 2
    av_cy = stage_y + 90
    draw_aa_circle(draw, av_cx, av_cy, 48, fill=(45, 45, 45, 255), outline=(255, 255, 255, 45), width=2)
    draw.text((av_cx - 24, av_cy - 16), "MN", font=get_font(24, "rounded"), fill=C_WHITE)

    draw.text((av_cx - 86, stage_y + 154), "Minh Nguyen", font=get_font(24, "rounded"), fill=C_WHITE)
    draw.text((av_cx - 74, stage_y + 188), "minh@morph.app", font=get_font(14), fill=C_TITANIUM)
    draw.text((av_cx - 56, stage_y + 212), "Lead Architect", font=get_font(13, "mono"), fill=C_TITANIUM_MUTED)

    # Stats Matrix
    st_y = stage_y + 250
    draw.line([(ld_x + 24, st_y), (ld_x + ld_w - 24, st_y)], fill=(255, 255, 255, 18), width=1)
    stats = [("2,480m", "Focus Time"), ("14 Days", "Streak"), ("42", "Sessions")]
    sw = (ld_w - 48) // 3
    for i, (val, label) in enumerate(stats):
        sx = ld_x + 24 + i * sw
        draw.text((sx + sw//2 - 28, st_y + 24), val, font=get_font(22, "rounded"), fill=C_WHITE)
        draw.text((sx + sw//2 - 24, st_y + 54), label, font=get_font(11), fill=C_TITANIUM)

    # Right Deck: System Settings Control Tiles
    rd_x = ld_x + ld_w + 24
    rd_w = iw - ld_w - 96

    settings = [
        ("Appearance Mode", "Obsidian Dark Substrate with Titanium Glint", "[ Obsidian Dark ]   Light   System"),
        ("Island Pinning", "Keep Dynamic Island visible across full screen spaces", "⌘P Toggle   Enabled"),
        ("Haptic Touch Engine", "Tactile feedback on hover dwell and mode switch", "Subtle Click   Active"),
        ("Cross-Device Handoff", "Continuity with iPhone 16 Pro and iPad Pro", "4 Devices Connected"),
        ("Keyboard Shortcuts", "Quick navigation and execution bindings", "⌘? View Shortcut Map")
    ]
    sh = (stage_h - (len(settings) - 1) * 12) // len(settings)
    for i, (title, sub, right_val) in enumerate(settings):
        sy = stage_y + i * (sh + 12)
        draw.rounded_rectangle([rd_x, sy, rd_x + rd_w, sy + sh], radius=18, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
        draw.text((rd_x + 24, sy + 14), title, font=get_font(16, "rounded"), fill=C_WHITE)
        draw.text((rd_x + 24, sy + 38), sub, font=get_font(12), fill=C_TITANIUM)
        draw.text((rd_x + rd_w - 240, sy + 24), right_val, font=get_font(12, "mono"), fill=C_WHITE)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_06.png"))
    print("Generated morph_apple_dynamic_island_page_06.png")

def build_page_07():
    extended_spec = {
        "summary": "Active call HUD with real-time mic killswitch & duration telemetry",
        "left_title": "FaceTime Active Call",
        "left_sub": "Spatial Design Sync (4 In Call)",
        "right_title": "24:15 Duration",
        "right_sub": "Voice Isolation Active",
        "kind": "standard"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 7, "Meeting Cockpit", "Active Telepresence Flight Deck", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Home")

    stage_y = iy + 86
    stage_h = ih - 138

    # Left Deck: Call Duration & Telemetry
    ld_w = 720
    ld_x = ix + 36
    draw.rounded_rectangle([ld_x, stage_y, ld_x + ld_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    draw.text((ld_x + 36, stage_y + 36), "FACETIME ACTIVE CALL", font=get_font(12, "mono"), fill=C_TITANIUM)
    draw.text((ld_x + 36, stage_y + 64), "Spatial Design Sync", font=get_font(32, "rounded"), fill=C_WHITE)
    draw.text((ld_x + 36, stage_y + 110), "24:15", font=get_font(52, "mono"), fill=C_WHITE)
    draw.text((ld_x + 36, stage_y + 180), "4 Participants   Studio Display Mic   Voice Isolation Active", font=get_font(14), fill=C_TITANIUM)

    # Participant Avatars
    py = stage_y + 240
    draw.line([(ld_x + 36, py), (ld_x + ld_w - 36, py)], fill=(255, 255, 255, 18), width=1)
    draw.text((ld_x + 36, py + 16), "ROSTER", font=get_font(11, "mono"), fill=C_TITANIUM)
    roster = ["MN Minh (Host)", "TC Tim C.", "CW Craig W.", "JF Jony F."]
    for i, name in enumerate(roster):
        draw.text((ld_x + 36, py + 42 + i * 26), name, font=get_font(13, "rounded"), fill=C_WHITE)

    # Right Deck: 4 Tactile Killswitches
    rd_x = ld_x + ld_w + 24
    rd_w = iw - ld_w - 96

    draw.rounded_rectangle([rd_x, stage_y, rd_x + rd_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    draw.text((rd_x + 36, stage_y + 36), "TELEPRESENCE KILLSWITCHES", font=get_font(12, "mono"), fill=C_TITANIUM)

    switches = [
        ("Mute Microphone", "Studio Mic Unmuted (⌘⇧M)", "🎙 Active", C_WHITE, C_BLACK_OLED),
        ("Camera Video", "FaceTime HD 1080p (⌘⇧V)", "📷 Active", (35, 35, 35, 255), C_WHITE),
        ("Screen Share", "Share Window or Display (⌘⇧S)", "🖥 Sharing", (35, 35, 35, 255), C_WHITE),
        ("Leave Session", "End Call for All (⌘Q)", "📞 End", (35, 35, 35, 255), C_WHITE)
    ]
    sw_h = 70
    for i, (title, sub, badge, fill_col, text_col) in enumerate(switches):
        sy = stage_y + 80 + i * (sw_h + 16)
        draw.rounded_rectangle([rd_x + 36, sy, rd_x + rd_w - 36, sy + sw_h], radius=20, fill=fill_col, outline=(255, 255, 255, 35) if fill_col != C_WHITE else None, width=1)
        draw.text((rd_x + 56, sy + 16), title, font=get_font(18, "rounded"), fill=text_col)
        draw.text((rd_x + 56, sy + 40), sub, font=get_font(12), fill=C_TITANIUM if fill_col == C_WHITE else C_TITANIUM_MUTED)
        draw.text((rd_x + rd_w - 140, sy + 24), badge, font=get_font(13, "mono"), fill=text_col)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_07.png"))
    print("Generated morph_apple_dynamic_island_page_07.png")

def build_page_08():
    extended_spec = {
        "summary": "Staged files buffer with instant AirDrop dispatch target",
        "left_title": "AirDrop Shelf Active",
        "left_sub": "3 Staged Files (14.2 MB)",
        "right_title": "Drag to Dispatch",
        "right_sub": "Hold Mode Enabled",
        "kind": "standard"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 8, "Drop Shelf", "AirDrop Staging Bay", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Home")

    stage_y = iy + 86
    stage_h = ih - 138

    sc_w = iw - 72
    sc_x = ix + 36
    draw.rounded_rectangle([sc_x, stage_y, sc_x + sc_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    # Action Strip
    as_y = stage_y + 20
    draw.text((sc_x + 28, as_y + 8), "AIRDROP STAGING BAY", font=get_font(12, "mono"), fill=C_TITANIUM)
    draw.text((sc_x + 240, as_y + 6), "3 Items Staged | 14.2 MB Total", font=get_font(15, "rounded"), fill=C_WHITE)

    draw_keycap(draw, sc_x + sc_w - 360, as_y + 4, "Hold: ON", font=get_font(11, "mono"), h=26)
    draw_keycap(draw, sc_x + sc_w - 240, as_y + 4, "Copy All Paths ⌘⇧C", font=get_font(11, "mono"), h=26)
    draw_keycap(draw, sc_x + sc_w - 90, as_y + 4, "Clear ⌘⌫", font=get_font(11, "mono"), h=26)
    draw.line([(sc_x + 24, as_y + 42), (sc_x + sc_w - 24, as_y + 42)], fill=(255, 255, 255, 18), width=1)

    # 3 Staged File Cards
    card_y = as_y + 64
    card_h = 180
    files = [
        ("Mockup_v4.png", "PNG Image", "8.4 MB", "PNG"),
        ("Architecture_Spec.pdf", "PDF Document", "5.1 MB", "PDF"),
        ("StateConfig.json", "JSON Data", "700 KB", "JSON")
    ]
    fw = (sc_w - 56 - 32) // 3
    for i, (fname, ftype, fsize, fbadge) in enumerate(files):
        fx = sc_x + 28 + i * (fw + 16)
        draw.rounded_rectangle([fx, card_y, fx + fw, card_y + card_h], radius=20, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30), width=1)
        draw.rounded_rectangle([fx + 20, card_y + 20, fx + 68, card_y + 68], radius=12, fill=(45, 45, 45, 255), outline=(255, 255, 255, 40), width=1)
        draw.text((fx + 28, card_y + 36), fbadge, font=get_font(11, "mono"), fill=C_WHITE)

        draw.text((fx + 82, card_y + 24), fname, font=get_font(16, "rounded"), fill=C_WHITE)
        draw.text((fx + 82, card_y + 50), f"{ftype}   {fsize}", font=get_font(12), fill=C_TITANIUM)

        # Remove / Finder buttons
        draw.text((fx + 20, card_y + 130), "Reveal in Finder ↗", font=get_font(12, "rounded"), fill=C_WHITE)
        draw.text((fx + fw - 80, card_y + 130), "Remove ✕", font=get_font(12), fill=C_TITANIUM)

    # Bottom AirDrop Destination Strip
    ad_y = card_y + card_h + 24
    draw.rounded_rectangle([sc_x + 28, ad_y, sc_x + sc_w - 28, ad_y + 110], radius=20, fill=(26, 26, 26, 255), outline=(255, 255, 255, 25), width=1)
    draw.text((sc_x + 56, ad_y + 24), "AIRDROP DISPATCH TARGETS", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((sc_x + 56, ad_y + 56), "Minh's iPhone 16 Pro (Nearby)   Studio Display   MacBook Air", font=get_font(15, "rounded"), fill=C_WHITE)
    draw.rounded_rectangle([sc_x + sc_w - 240, ad_y + 36, sc_x + sc_w - 56, ad_y + 80], radius=22, fill=C_WHITE)
    draw.text((sc_x + sc_w - 212, ad_y + 48), "AirDrop All Files ↗", font=get_font(13, "rounded"), fill=C_BLACK_OLED)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_08.png"))
    print("Generated morph_apple_dynamic_island_page_08.png")

def build_page_09():
    extended_spec = {
        "summary": "Neural intake form assistant with Keychain auto-fill and live telemetry",
        "left_title": "Apple Intake Form Active",
        "left_sub": "Question 1 of 4 (25% Complete)",
        "right_title": "↵ Next Field",
        "right_sub": "Keychain Auto-Fill Ready",
        "kind": "standard"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 9, "Form Tracker", "Neural Form Autofill HUD", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Home")

    stage_y = iy + 86
    stage_h = ih - 138

    # Left Deck: Question Stepper
    ld_w = 640
    ld_x = ix + 36
    draw.rounded_rectangle([ld_x, stage_y, ld_x + ld_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    draw.text((ld_x + 28, stage_y + 28), "APPLICATION INTAKE FORM", font=get_font(11, "mono"), fill=C_TITANIUM)
    draw.text((ld_x + 28, stage_y + 54), "Question 1 of 4", font=get_font(26, "rounded"), fill=C_WHITE)
    draw.text((ld_x + 28, stage_y + 90), "25% Completed   Apple ATS Portal", font=get_font(14), fill=C_TITANIUM)

    # Progress bar
    draw.rounded_rectangle([ld_x + 28, stage_y + 120, ld_x + ld_w - 28, stage_y + 128], radius=4, fill=(35, 35, 35, 255))
    draw.rounded_rectangle([ld_x + 28, stage_y + 120, ld_x + 28 + (ld_w - 56)//4, stage_y + 128], radius=4, fill=C_WHITE)

    steps = [
        ("1. Architectural Focus", "In Progress — Active Focus"),
        ("2. Experience Level", "Pending Next"),
        ("3. System Portfolio", "Pending Next"),
        ("4. Executive Summary", "Pending Final")
    ]
    for i, (s_title, s_stat) in enumerate(steps):
        sy = stage_y + 160 + i * 50
        draw_aa_circle(draw, ld_x + 44, sy + 10, 10, fill=C_WHITE if i == 0 else (40, 40, 40, 255))
        draw.text((ld_x + 68, sy), s_title, font=get_font(14, "rounded"), fill=C_WHITE if i == 0 else C_TITANIUM)
        draw.text((ld_x + 68, sy + 20), s_stat, font=get_font(11), fill=C_TITANIUM_MUTED)

    # Right Deck: Active Question Stage
    rd_x = ld_x + ld_w + 24
    rd_w = iw - ld_w - 96

    draw.rounded_rectangle([rd_x, stage_y, rd_x + rd_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)
    draw.text((rd_x + 36, stage_y + 36), "ACTIVE PROMPT *", font=get_font(12, "mono"), fill=C_TITANIUM)
    draw.text((rd_x + 36, stage_y + 64), "What is your primary architectural focus for macOS?", font=get_font(22, "rounded"), fill=C_WHITE)

    choices = [
        ("Spatial & Dynamic Island UX", "True continuous squircle physics & zero occlusion", True),
        ("High-Performance Audio Engine", "Lossless low-latency buffer management", False),
        ("Universal App Accessibility", "Full WCAG compliance and VoiceOver ergonomics", False)
    ]
    ch_h = 60
    for i, (c_title, c_sub, is_sel) in enumerate(choices):
        cy = stage_y + 116 + i * (ch_h + 14)
        draw.rounded_rectangle([rd_x + 36, cy, rd_x + rd_w - 36, cy + ch_h], radius=16, fill=(35, 35, 35, 255) if is_sel else (25, 25, 25, 255), outline=C_WHITE if is_sel else (255, 255, 255, 25), width=2 if is_sel else 1)
        draw_aa_circle(draw, rd_x + 60, cy + ch_h//2, 10, fill=C_WHITE if is_sel else None, outline=C_WHITE, width=2)
        draw.text((rd_x + 84, cy + 12), c_title, font=get_font(15, "rounded"), fill=C_WHITE)
        draw.text((rd_x + 84, cy + 34), c_sub, font=get_font(12), fill=C_TITANIUM)

    # Keychain Autofill Card
    kc_y = stage_y + 348
    draw.rounded_rectangle([rd_x + 36, kc_y, rd_x + rd_w - 36, kc_y + 64], radius=16, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30), width=1)
    draw.text((rd_x + 56, kc_y + 14), "🔑 Keychain Autofill Suggestion", font=get_font(13, "rounded"), fill=C_WHITE)
    draw.text((rd_x + 56, kc_y + 36), "Minh Nguyen (Work Profile)   minh@morph.app", font=get_font(12), fill=C_TITANIUM)
    draw_keycap(draw, rd_x + rd_w - 180, kc_y + 18, "Fill ⌥Space", font=get_font(11, "mono"), h=28)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_09.png"))
    print("Generated morph_apple_dynamic_island_page_09.png")

def build_page_10():
    extended_spec = {
        "summary": "Dual-bubble multitasking HUD running concurrent music waveform and timer",
        "left_title": "♫ Midnight City — M83",
        "left_sub": "Equalizer Active",
        "right_title": "⏱ 23:45 Remaining",
        "right_sub": "Focus Session 3 of 4",
        "kind": "music"
    }
    canvas, draw, (ix, iy, iw, ih) = setup_page_canvas(2400, 1600, 10, "Compact Notch HUD", "Multi-Activity Background Pill", extended_spec)
    draw_top_nav(draw, ix, iy, iw, active_page="Home")

    stage_y = iy + 86
    stage_h = ih - 138

    mc_w = iw - 72
    mc_x = ix + 36
    draw.rounded_rectangle([mc_x, stage_y, mc_x + mc_w, stage_y + stage_h], radius=28, fill=C_BLACK_WELL, outline=(255, 255, 255, 25), width=1)

    draw.text((mc_x + 36, stage_y + 36), "UNIVERSAL MULTI-ACTIVITY BACKGROUND ARCHITECTURE", font=get_font(12, "mono"), fill=C_TITANIUM)
    draw.text((mc_x + 36, stage_y + 64), "Concurrent Live Activities & State Transitions", font=get_font(26, "rounded"), fill=C_WHITE)

    # 3 State Demonstration Cards
    cards = [
        ("1. STATE 1: RESTING STEALTH", "210 × 36 pt capsule floating 14pt beneath notch. 100% click-through passthrough. Whisper-thin hairline, zero occlusion of browser tabs, zero dots, zero text.", "Normal Idle"),
        ("2. STATE 2: EXTENDED PILL", "480–520 × 36 pt elongated HUD. Displays real-time background telemetry (Timer countdown, Music waveform, Call duration, Pinned notes) while user works in background apps.", "Live Activity"),
        ("3. STATE 3: FULL BIG UI", "640 × 225 pt autonomous squircle modal. Expands organically on deliberate hover dwell (>320ms) or ⌘⌥M. Comprehensive cockpit with fluid dual-deck layout.", "Expanded Workspace")
    ]
    card_w = (mc_w - 72 - 32) // 3
    for i, (c_title, c_desc, c_badge) in enumerate(cards):
        cx = mc_x + 36 + i * (card_w + 16)
        cy = stage_y + 116
        draw.rounded_rectangle([cx, cy, cx + card_w, cy + 280], radius=20, fill=(30, 30, 30, 255), outline=(255, 255, 255, 30), width=1)
        draw.text((cx + 20, cy + 24), c_badge.upper(), font=get_font(11, "mono"), fill=C_TITANIUM)
        draw.text((cx + 20, cy + 48), c_title, font=get_font(16, "rounded"), fill=C_WHITE)
        
        # Word wrap description
        words = c_desc.split()
        lines = []
        cur = ""
        for w in words:
            if len(cur + " " + w) > 36:
                lines.append(cur)
                cur = w
            else:
                cur = cur + " " + w if cur else w
        if cur:
            lines.append(cur)
        for li, ltext in enumerate(lines[:6]):
            draw.text((cx + 20, cy + 90 + li * 22), ltext, font=get_font(13), fill=C_TITANIUM)

    draw_bottom_rail(draw, ix, iy, iw, ih)
    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_page_10.png"))
    print("Generated morph_apple_dynamic_island_page_10.png")

# =========================================================================
# ARCHITECTURE & HOVER LIFECYCLE BOARDS
# =========================================================================

def build_architecture_board():
    width = 2560
    height = 2400
    canvas = Image.new("RGBA", (width, height), C_BLACK_BG)
    draw = ImageDraw.Draw(canvas)

    for y in range(height):
        ratio = y / height
        v = int(10 + 4 * (1 - abs(ratio - 0.5) * 2))
        draw.line([(0, y), (width, y)], fill=(v, v, v, 255))

    font_brand = get_font(26, "rounded")
    font_title = get_font(34)
    font_sec = get_font(22, "rounded")
    font_desc = get_font(16)

    draw.text((100, 48), "  Apple Dynamic Island Paradigm", font=font_brand, fill=C_TITANIUM)
    draw.text((width - 800, 44), "UNIVERSAL STATE ARCHITECTURE", font=font_title, fill=C_WHITE)
    draw.line([(100, 96), (width - 100, 96)], fill=C_TITANIUM_BORDER, width=1)

    sections = [
        ("STATE 1: NORMAL RESTING DYNAMIC ISLAND (RESTING STEALTH)", "210 × 36 pt   14pt vertical breathing clearance below hardware notch   100% Click-Through   Zero Occlusion", 130, 480),
        ("STATE 2: THE EXTENDED MORPH PILL (LIVE BACKGROUND ACTIVITY HUD)", "480–520 × 36 pt   Elongated bilateral wings showing real-time background telemetry while working in apps", 650, 480),
        ("STATE 3: THE FULL BIG UI FOR MORPH (EXPANDED DYNAMIC ISLAND MODAL)", "640 × 225 pt (scaled to 1800 × 740 on Retina 2x)   Autonomous 4-sided continuous squircle modal", 1170, 1100)
    ]
    for s_title, s_sub, sy, sh in sections:
        draw.rounded_rectangle([100, sy, width - 100, sy + sh], radius=24, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
        draw.text((136, sy + 24), s_title, font=font_sec, fill=C_WHITE)
        draw.text((136, sy + 56), s_sub, font=font_desc, fill=C_TITANIUM)

    # State 1 resting pill
    draw_pill_outline(draw, (width - 420)//2, 240, 420, 72)
    draw.text(((width - 340)//2, 266), "Whisper Outline (0.75pt)   100% Click-Through", font=get_font(13, "mono"), fill=C_TITANIUM)

    # State 2 extended pill
    draw_extended_pill_hud(draw, (width - 1200)//2, 770, 1200, 72, "Morph Ambient Active", "Focus Block in Progress", "23:45 Remaining", "Deep Work Session 3 of 4", "standard")

    # State 3 modal representation
    isl_x = (width - 1600) // 2
    isl_y = 1290
    draw.rounded_rectangle([isl_x, isl_y, isl_x + 1600, isl_y + 900], radius=40, fill=C_BLACK_OLED, outline=(255, 255, 255, 35), width=1)
    draw_top_nav(draw, isl_x, isl_y, 1600, "Home")
    draw.text((isl_x + 80, isl_y + 120), "Good afternoon, Minh", font=get_font(32, "rounded"), fill=C_WHITE)
    draw.text((isl_x + 80, isl_y + 170), "Autonomous Apple Dynamic Island Modal Stage", font=get_font(18), fill=C_TITANIUM)

    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_stitch_architecture.png"))
    print("Generated morph_apple_dynamic_island_stitch_architecture.png")

def build_hover_lifecycle_board():
    width = 2560
    height = 2400
    canvas = Image.new("RGBA", (width, height), C_BLACK_BG)
    draw = ImageDraw.Draw(canvas)

    for y in range(height):
        ratio = y / height
        v = int(10 + 4 * (1 - abs(ratio - 0.5) * 2))
        draw.line([(0, y), (width, y)], fill=(v, v, v, 255))

    font_brand = get_font(26, "rounded")
    font_title = get_font(34)
    font_sec = get_font(22, "rounded")
    font_desc = get_font(16)

    draw.text((100, 48), "  Apple Dynamic Island Paradigm", font=font_brand, fill=C_TITANIUM)
    draw.text((width - 800, 44), "HOVER & INTENT LIFECYCLE", font=font_title, fill=C_WHITE)
    draw.line([(100, 96), (width - 100, 96)], fill=C_TITANIUM_BORDER, width=1)

    steps = [
        ("PHASE 1: PASS-THROUGH STEALTH", "Rapid cursor sweeps (>140px/s) or active typing in Google Docs/Chrome completely pass through. ignoresMouseEvents = true. Zero popups, zero distraction.", 140),
        ("PHASE 2: DELIBERATE HOVER DWELL", "Cursor rests stationary inside island bounds for >320ms. The intent engine confirms intentional dwell and initiates fluid spring expansion.", 680),
        ("PHASE 3: MODAL EXPANSION (STATE 3)", "Island smoothly blooms outward into the full 640x225pt modal workspace. Navigation tabs, living companion, and interactive action modules activate.", 1220),
        ("PHASE 4: EXIT & RETRACTION", "Cursor departs island boundaries. A 250ms buffer prevents accidental collapse. Transitions back to State 2 (if tasks running) or State 1 (if idle).", 1760)
    ]
    for s_title, s_desc, sy in steps:
        draw.rounded_rectangle([100, sy, width - 100, sy + 460], radius=24, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
        draw.text((136, sy + 28), s_title, font=font_sec, fill=C_WHITE)
        draw.text((136, sy + 64), s_desc, font=font_desc, fill=C_TITANIUM)

    canvas.save(os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_hover_lifecycle.png"))
    print("Generated morph_apple_dynamic_island_hover_lifecycle.png")

if __name__ == "__main__":
    print("Beginning generation of all 12 Apple Dynamic Island master visual boards (v4)...")
    build_page_01()
    build_page_02()
    build_page_03()
    build_page_04()
    build_page_05()
    build_page_06()
    build_page_07()
    build_page_08()
    build_page_09()
    build_page_10()
    build_architecture_board()
    build_hover_lifecycle_board()
    print("All 12 boards successfully generated!")
