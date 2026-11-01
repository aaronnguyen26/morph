#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

INPUT_DIR = "/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd/current_ui"
OUTPUT_DIR = "/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd"

FONT_PATH = "/System/Library/Fonts/SFNS.ttf"
if not os.path.exists(FONT_PATH):
    FONT_PATH = "/System/Library/Fonts/Helvetica.ttc"

def get_font(size):
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except Exception:
        return ImageFont.load_default()

# -------------------------------------------------------------
# STRICT 3-COLOR APPLE MINIMALIST PALETTE (PURE NEUTRAL MONOCHROME)
# Color 1: Pitch Black OLED Substrate (#000000, #0A0A0A, #121212)
# Color 2: Signal Studio White (#FFFFFF)
# Color 3: Apple Titanium Gray (#8E8E8E, #A1A1A1)
# -------------------------------------------------------------

C_BLACK_BG = (10, 10, 10, 255)
C_BLACK_CARD = (16, 16, 16, 255)
C_BLACK_OLED = (0, 0, 0, 255)
C_WHITE = (255, 255, 255, 255)
C_WHITE_MUTED = (255, 255, 255, 180)
C_WHITE_RIM = (255, 255, 255, 50)
C_WHITE_FAINT = (255, 255, 255, 20)

C_TITANIUM = (142, 142, 142, 255)
C_TITANIUM_MUTED = (142, 142, 142, 160)
C_TITANIUM_BORDER = (142, 142, 142, 60)
C_TITANIUM_FAINT = (142, 142, 142, 25)

def draw_pill_outline(draw, pill_x, pill_y, pill_w, pill_h):
    """Draws the ultra-subtle, transparent Dynamic Island resting hairline outline"""
    draw.rounded_rectangle(
        [pill_x, pill_y, pill_x + pill_w, pill_y + pill_h],
        radius=18,
        fill=(12, 12, 12, 35),
        outline=(255, 255, 255, 65),
        width=1
    )

def draw_extended_pill_hud(draw, x, y, w, h, left_text, left_sub, right_text, right_sub, feature_kind="standard"):
    """
    Draws STATE 2: The Extended Dynamic Island Pill (longer Live Activity HUD),
    showing real-time status while the user works in background applications.
    """
    # Outer ambient shadow
    shadow_pad = 6
    draw.rounded_rectangle([x - shadow_pad, y - shadow_pad, x + w + shadow_pad, y + h + shadow_pad], radius=h//2 + 4, fill=(0, 0, 0, 160))
    
    # Solid OLED Black elongated pill body
    draw.rounded_rectangle([x, y, x + w, y + h], radius=h//2, fill=C_BLACK_OLED, outline=C_WHITE_RIM, width=1)
    
    # Left Wing (Live Context)
    lw_x = x + 24
    lw_y = y + (h - 32) // 2
    draw.text((lw_x, lw_y), left_text, font=get_font(16), fill=C_WHITE)
    if left_sub:
        draw.text((lw_x, lw_y + 18), left_sub, font=get_font(11), fill=C_TITANIUM)
        
    # Central deadband divider hint (subtle markers)
    mid_x = x + w // 2
    draw.line([(mid_x - 30, y + h//2), (mid_x + 30, y + h//2)], fill=(35, 35, 35, 255), width=1)
    
    # Right Wing (Live Telemetry / Action)
    rw_bbox = draw.textbbox((0, 0), right_text, font=get_font(16))
    rw_w = rw_bbox[2] - rw_bbox[0]
    rw_x = x + w - 24 - rw_w
    rw_y = y + (h - 32) // 2
    
    if feature_kind == "waveform":
        # Render animated audio waveform equalizer bars
        bars_x = x + w - 140
        bar_h_vals = [8, 18, 24, 14, 22, 10, 16, 20]
        for idx, bh in enumerate(bar_h_vals):
            bx = bars_x + idx * 7
            by = y + (h - bh) // 2
            draw.rounded_rectangle([bx, by, bx + 4, by + bh], radius=2, fill=C_WHITE)
        draw.text((x + w - 140 - rw_w - 18, rw_y), right_text, font=get_font(15), fill=C_WHITE)
        if right_sub:
            draw.text((x + w - 140 - rw_w - 18, rw_y + 18), right_sub, font=get_font(11), fill=C_TITANIUM)
    elif feature_kind == "button":
        # Render tactile quick action capsule button
        btn_w = rw_w + 24
        btn_x = x + w - 20 - btn_w
        draw.rounded_rectangle([btn_x, y + 10, btn_x + btn_w, y + h - 10], radius=14, fill=(35, 35, 35, 255), outline=C_WHITE_RIM, width=1)
        draw.text((btn_x + 12, y + (h - 16)//2), right_text, font=get_font(13), fill=C_WHITE)
    else:
        draw.text((rw_x, rw_y), right_text, font=get_font(16), fill=C_WHITE)
        if right_sub:
            rsub_bbox = draw.textbbox((0, 0), right_sub, font=get_font(11))
            rsub_w = rsub_bbox[2] - rsub_bbox[0]
            draw.text((x + w - 24 - rsub_w, rw_y + 18), right_sub, font=get_font(11), fill=C_TITANIUM)

def create_master_architecture_and_resting_board():
    """
    Generates Master Board 01:
    - 1. THE NORMAL RESTING OF MORPH RIGHT NOW (210x36 stealth whisper outline, zero tab occlusion)
    - THE 3-TIER OPERATIONAL ARCHITECTURE:
      State 1: Resting Stealth Pill
      State 2: Extended Background HUD Pill
      State 3: Full Big UI Modal Workspace
    """
    w = 2560
    h = 2400
    canvas = Image.new("RGBA", (w, h), C_BLACK_BG)
    draw = ImageDraw.Draw(canvas)
    
    for y in range(h):
        ratio = y / h
        v = int(9 + 4 * (1 - abs(ratio - 0.45) * 2))
        draw.line([(0, y), (w, y)], fill=(v, v, v, 255))
        
    font_title = get_font(32)
    font_subtitle = get_font(17)
    font_heading = get_font(21)
    font_body = get_font(14)
    font_badge = get_font(12)
    
    # Master Header
    draw.text((80, 48), "  MORPH — 3-TIER APPLE DYNAMIC ISLAND ARCHITECTURE", font=font_title, fill=C_WHITE)
    draw.text((80, 92), "State 1: Normal Resting  |  State 2: Extended Background HUD  |  State 3: Full Big UI Modal Workspace", font=font_subtitle, fill=C_TITANIUM)
    draw.line([(80, 130), (w - 80, 130)], fill=C_TITANIUM_BORDER, width=1)
    
    # -------------------------------------------------------------
    # SECTION 1: THE NORMAL RESTING OF MORPH RIGHT NOW (STATE 1)
    # -------------------------------------------------------------
    s1_y = 160
    s1_w = w - 160
    s1_h = 420
    draw.rounded_rectangle([80, s1_y, 80 + s1_w, s1_y + s1_h], radius=18, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
    
    draw.text((108, s1_y + 24), "1. THE NORMAL RESTING OF MORPH RIGHT NOW — ZERO-OCCLUSION BASELINE", font=font_heading, fill=C_WHITE)
    draw.text((108, s1_y + 54), "Compact 210 × 36 pt pill floating with 14pt clearance below menu bar. Transparent whisper outline, zero text, zero dots.", font=font_body, fill=C_TITANIUM)
    draw.text((108, s1_y + 76), "Click-Through Active: PassthroughHostingView returns nil and panel ignores mouse events — clicks pass straight to background windows.", font=font_body, fill=C_TITANIUM)
    
    # 3 Wireframe Preview Boxes of State 1 Resting in Real Apps
    apps = [
        ("VS Code / Xcode IDE", "Editor Tabs, Run Buttons & Breakpoints remain 100% visible & clickable right through island"),
        ("Chrome / Polar Browser", "Browser Tab Strips, Omnibox & Extensions are 100% accessible with zero click interception"),
        ("Figma / Slack Suite", "Top toolbar actions, share buttons & canvas viewports remain completely unobstructed")
    ]
    box_w = (s1_w - 48 - 40) // 3
    for idx, (app_name, app_desc) in enumerate(apps):
        bx = 108 + idx * (box_w + 20)
        by = s1_y + 115
        bh = 265
        draw.rounded_rectangle([bx, by, bx + box_w, by + bh], radius=12, fill=(18, 18, 18, 255), outline=C_TITANIUM_BORDER, width=1)
        
        # Window Header
        draw.rounded_rectangle([bx, by, bx + box_w, by + 36], radius=12, fill=(26, 26, 26, 255))
        draw.rectangle([bx, by + 18, bx + box_w, by + 36], fill=(26, 26, 26, 255))
        draw.ellipse([bx + 14, by + 12, bx + 22, by + 20], fill=(45, 45, 45, 255))
        draw.ellipse([bx + 28, by + 12, bx + 36, by + 20], fill=(45, 45, 45, 255))
        draw.ellipse([bx + 42, by + 12, bx + 50, by + 20], fill=(45, 45, 45, 255))
        draw.text((bx + 62, by + 10), app_name, font=get_font(12), fill=C_WHITE)
        
        # State 1 Resting Pill Mockup
        pill_w = 170
        pill_h = 28
        pill_x = bx + (box_w - pill_w) // 2
        pill_y = by + 48
        draw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=14, fill=(12, 12, 12, 40), outline=(255, 255, 255, 70), width=1)
        draw.text((pill_x + 16, pill_y + 6), "State 1: Resting Stealth (0% Occlusion)", font=get_font(9), fill=C_TITANIUM)
        
        # Content Mockup lines
        for r in range(4):
            ry = by + 94 + r * 16
            draw.rounded_rectangle([bx + 20, ry, bx + 140 + (r*40)%160, ry + 8], radius=2, fill=(28, 28, 28, 255))
            
        draw.text((bx + 16, by + bh - 48), app_desc, font=get_font(10), fill=C_TITANIUM)
        draw.text((bx + 16, by + bh - 24), "✓ 100% CLICK-THROUGH VERIFIED", font=get_font(10), fill=C_WHITE)
        
    # -------------------------------------------------------------
    # SECTION 2: 3-TIER OPERATIONAL PROGRESSION (1 → 2 → 3)
    # -------------------------------------------------------------
    s2_y = s1_y + s1_h + 36
    s2_w = w - 160
    s2_h = 1660
    draw.rounded_rectangle([80, s2_y, 80 + s2_w, s2_y + s2_h], radius=18, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
    
    draw.text((108, s2_y + 24), "2. THREE OPERATIONAL STATES ACROSS ALL WORKSPACES", font=font_heading, fill=C_WHITE)
    draw.text((108, s2_y + 54), "How Morph transitions dynamically from idle stealth, to elongated background activity HUD, to full big modal UI.", font=font_body, fill=C_TITANIUM)
    
    stages = [
        ("STATE 1: NORMAL RESTING MORPH",
         "210 × 36 pt  •  Zero Background Activity  •  Whisper Stealth Outline",
         "state1"),
        ("STATE 2: THE EXTENDED MORPH PILL",
         "480–520 × 36 pt  •  Live Background Activity HUD  •  OLED Black Bilateral Wings",
         "state2"),
        ("STATE 3: THE FULL BIG UI FOR MORPH",
         "640 × 225 pt  •  Autonomous 4-Sided Squircle Modal Window  •  Full Workspace",
         "state3")
    ]
    
    card_y = s2_y + 90
    card_h = 480
    
    # State 1 Card
    draw.rounded_rectangle([108, card_y, 108 + s2_w - 56, card_y + 140], radius=14, fill=(18, 18, 18, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((136, card_y + 20), "STATE 1 — NORMAL RESTING MORPH (IDLE)", font=get_font(16), fill=C_WHITE)
    draw.text((136, card_y + 42), "Resting in central deadband when no background task is running. Ultra-subtle outline, zero text, 100% click-through.", font=get_font(12), fill=C_TITANIUM)
    draw_pill_outline(draw, 108 + (s2_w - 56 - 240)//2, card_y + 76, 240, 36)
    draw.text((108 + (s2_w - 56 - 240)//2 + 28, card_y + 86), "State 1: Resting Stealth Outline", font=get_font(12), fill=C_TITANIUM)
    
    # State 2 Card
    c2_y = card_y + 160
    draw.rounded_rectangle([108, c2_y, 108 + s2_w - 56, c2_y + 240], radius=14, fill=(18, 18, 18, 255), outline=C_WHITE_RIM, width=1)
    draw.text((136, c2_y + 20), "STATE 2 — THE EXTENDED MORPH PILL (LIVE BACKGROUND ACTIVITY HUD)", font=get_font(16), fill=C_WHITE)
    draw.text((136, c2_y + 44), "Longer than State 1: Elongates horizontally to display live telemetry while user works in other apps.", font=get_font(13), fill=C_TITANIUM)
    draw.text((136, c2_y + 64), "Shown below: Extended Timer Pill (left) and Extended Music Now Playing Pill (right) side by side:", font=get_font(12), fill=C_TITANIUM)
    
    # Two example extended pills side by side
    ep1_w = (s2_w - 56 - 70) // 2
    draw_extended_pill_hud(draw, 136, c2_y + 100, ep1_w, 60, "◷ Focus Session", "Pomodoro Phase 1", "24:59", "Remaining", feature_kind="standard")
    draw_extended_pill_hud(draw, 136 + ep1_w + 24, c2_y + 100, ep1_w, 60, "♫ BIRDS OF A FEATHER", "Billie Eilish • HIT ME HARD", "Playing", "Audio Waveform", feature_kind="waveform")
    draw.text((136, c2_y + 180), "Left Wing: Context & Source App  |  Center: Camera Deadband Clearance  |  Right Wing: Live Metrics & Equalizer", font=get_font(11), fill=C_TITANIUM)
    draw.text((136, c2_y + 202), "Universal Intent Filter: Typing, clicking tabs, or scrolling in background apps will NEVER accidentally dismiss or expand this pill.", font=get_font(11), fill=C_WHITE)
    
    # State 3 Card
    c3_y = c2_y + 260
    draw.rounded_rectangle([108, c3_y, 108 + s2_w - 56, c3_y + 1060], radius=14, fill=(18, 18, 18, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((136, c3_y + 24), "STATE 3 — THE FULL BIG UI FOR MORPH (AUTONOMOUS EXPANDED WORKSPACE)", font=get_font(18), fill=C_WHITE)
    draw.text((136, c3_y + 54), "Unfolds downwards as an authentic freestanding 4-sided squircle modal window (640 × 225 pt).", font=get_font(13), fill=C_TITANIUM)
    draw.text((136, c3_y + 76), "Triggered intentionally via deliberate hover dwell (320ms) or shortcut (⌘⌥M, ⌘1-9). Zero camera notch cutout.", font=get_font(13), fill=C_TITANIUM)
    
    # Embed Full Big UI example (Page 01 Home)
    red_path = os.path.join(INPUT_DIR, "apple_redesign_01_home.png")
    if os.path.exists(red_path):
        rimg = Image.open(red_path).convert("L").convert("RGBA")
        target_w = s2_w - 120
        aspect = rimg.height / rimg.width
        target_h = int(target_w * aspect)
        rimg = rimg.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        rx = 108 + (s2_w - 56 - target_w) // 2
        ry = c3_y + 120
        
        # Shadow
        shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.rounded_rectangle([rx - 12, ry - 6, rx + target_w + 12, ry + target_h + 16], radius=28, fill=(0, 0, 0, 240))
        shadow = shadow.filter(ImageFilter.GaussianBlur(28))
        canvas = Image.alpha_composite(canvas, shadow)
        draw = ImageDraw.Draw(canvas)
        
        draw.rounded_rectangle([rx - 2, ry - 2, rx + target_w + 2, ry + target_h + 2], radius=24, fill=C_BLACK_OLED, outline=C_WHITE_RIM, width=1)
        canvas.paste(rimg, (rx, ry), rimg)
        
    out_file = os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_stitch_architecture.png")
    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(out_file, "PNG")
    print(f"Created master architecture & resting board: {out_file} ({os.path.getsize(out_file)/1024:.1f} KB)")

def create_hover_lifecycle_board():
    """Generates the dedicated architectural hover lifecycle board"""
    w = 2560
    h = 1600
    canvas = Image.new("RGBA", (w, h), C_BLACK_BG)
    draw = ImageDraw.Draw(canvas)
    
    for y in range(h):
        ratio = y / h
        v = int(9 + 4 * (1 - abs(ratio - 0.45) * 2))
        draw.line([(0, y), (w, y)], fill=(v, v, v, 255))
        
    font_title = get_font(32)
    font_subtitle = get_font(17)
    font_heading = get_font(20)
    font_body = get_font(14)
    font_badge = get_font(12)
    
    draw.text((80, 48), "  DYNAMIC ISLAND — UNIVERSAL INTENT DIFFERENTIATION ENGINE", font=font_title, fill=C_WHITE)
    draw.text((80, 92), "Works Across All macOS Platforms: Code Editors, Web Browsers, Terminals, Design & Productivity Suites", font=font_subtitle, fill=C_TITANIUM)
    draw.line([(80, 130), (w - 80, 130)], fill=C_TITANIUM_BORDER, width=1)
    
    stages = [
        ("STAGE 1: RESTING STEALTH (UNIVERSAL)", 
         "Dynamic Island rests silently across ANY active window.\nClear fill and subtle 0.75pt titanium hairline outline.\nPassthroughHostingView returns nil; panel ignores mouse events.\nClicks on tabs, toolbars, or window headers pass 100% through.",
         "TRANSPARENT CLICK-THROUGH"),
        ("STAGE 2: EXTENDED BACKGROUND ACTIVITY HUD",
         "When an activity is running, island elongates horizontally.\nDisplays real-time background metrics while user works in other apps.\nActive typing, clicking tabs, or scrolling in any app suppresses hover.\nFast sweeps (>140px/s) pass right through with zero popup.",
         "EXTENDED LIVE ACTIVITY HUD"),
        ("STAGE 3: FLUID 4-SIDED SQUIRCLE EXPANSION",
         "Deliberate dwell (>320ms) triggers organic spring expansion (.38s).\nExpands downward as an autonomous, freestanding Apple Dynamic Island.\nZero camera notch cutout — 100% active screen space.\nInstant auto-dismiss when cursor leaves the island boundaries.",
         "AUTONOMOUS FULLER UI")
    ]
    
    panel_w = 760
    panel_h = 1340
    
    for i, (title, desc, badge_txt) in enumerate(stages):
        px = 80 + i * (panel_w + 40)
        py = 160
        
        draw.rounded_rectangle([px, py, px + panel_w, py + panel_h], radius=18, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
        draw.text((px + 32, py + 28), title, font=font_heading, fill=C_WHITE)
        draw.line([(px + 32, py + 64), (px + panel_w - 32, py + 64)], fill=C_TITANIUM_BORDER, width=1)
        
        my = py + 90
        mw = panel_w - 64
        
        if i == 0:
            # Stage 1: Resting Stealth Outline
            draw.rounded_rectangle([px + 32, my, px + 32 + mw, my + 380], radius=12, fill=(18, 18, 18, 255), outline=C_TITANIUM_BORDER, width=1)
            draw_pill_outline(draw, px + 32 + (mw - 220)//2, my + 40, 220, 36)
            draw.text((px + 32 + (mw - 220)//2 + 20, my + 50), "State 1: Resting Stealth Outline", font=get_font(11), fill=C_TITANIUM)
            draw.text((px + 52, my + 110), "ACTIVE APP WORKSPACE (VS Code / Chrome / Figma)", font=get_font(10), fill=C_TITANIUM_MUTED)
            for r in range(4):
                draw.rounded_rectangle([px + 52, my + 130 + r * 18, px + 52 + 160 + (r*60)%200, my + 138 + r * 18], radius=2, fill=(28, 28, 28, 255))
            draw.text((px + 52, my + 340), "Clicks on underlying tabs pass 100% through", font=get_font(12), fill=C_WHITE)
        elif i == 1:
            # Stage 2: Extended Background Activity HUD
            draw.rounded_rectangle([px + 32, my, px + 32 + mw, my + 380], radius=12, fill=(18, 18, 18, 255), outline=C_WHITE_RIM, width=1)
            draw_extended_pill_hud(draw, px + 44, my + 30, mw - 24, 56, "◷ Focus Session", "Pomodoro 25m", "24:59", "Remaining", feature_kind="standard")
            draw.text((px + 52, my + 110), "ACTIVE APP WORKSPACE (Typing Code / Google Docs)", font=get_font(10), fill=C_TITANIUM_MUTED)
            for r in range(4):
                draw.rounded_rectangle([px + 52, my + 130 + r * 18, px + 52 + 160 + (r*60)%200, my + 138 + r * 18], radius=2, fill=(28, 28, 28, 255))
            draw.text((px + 52, my + 340), "Active typing & clicking in app suppresses popup", font=get_font(12), fill=C_WHITE)
        elif i == 2:
            # Stage 3: Fuller UI Modal Expansion
            red_path = os.path.join(INPUT_DIR, "apple_redesign_01_home.png")
            if os.path.exists(red_path):
                rimg = Image.open(red_path).convert("L").convert("RGBA")
                rw = mw
                rh = int(rw * (rimg.height / rimg.width))
                rimg = rimg.resize((rw, rh), Image.Resampling.LANCZOS)
                rx = px + 32
                ry = my
                draw.rounded_rectangle([rx - 2, ry - 2, rx + rw + 2, ry + rh + 2], radius=18, fill=C_BLACK_OLED, outline=C_WHITE_RIM, width=1)
                canvas.paste(rimg, (rx, ry), rimg)
            draw.text((px + 52, my + 340), "Deliberate dwell expands into Fuller UI", font=get_font(12), fill=C_WHITE)
            
        desc_y = my + 410
        draw.text((px + 32, desc_y), "SPATIAL SPECIFICATION", font=get_font(11), fill=C_TITANIUM)
        curr_y = desc_y + 24
        for line in desc.split("\n"):
            draw.text((px + 32, curr_y), line.strip(), font=font_body, fill=C_WHITE if "100%" in line or "Deliberate" in line or "Zero" in line else C_TITANIUM)
            curr_y += 24
            
        draw.rounded_rectangle([px + 32, py + panel_h - 56, px + panel_w - 32, py + panel_h - 20], radius=10, fill=(24, 24, 24, 255), outline=C_TITANIUM_BORDER, width=1)
        draw.text((px + 48, py + panel_h - 44), f" HIG COMPLIANCE — {badge_txt}", font=font_badge, fill=C_WHITE)
        
    out_file = os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_hover_lifecycle.png")
    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(out_file, "PNG")
    print(f"Created architecture lifecycle board: {out_file} ({os.path.getsize(out_file)/1024:.1f} KB)")

def create_master_page_board(page_num, page_title, subtitle, extended_spec, redesign_img_name, pills, output_name):
    """
    Generates Master Board for EACH Feature / Page.
    MANDATORY REQUIREMENT: Each board MUST contain BOTH:
    - 2. The Extended Morph Pill (showing live background activity state)
    - 3. The Full Big UI for Morph (expanded 640x225 modal window)
    """
    width = 2400
    height = 1600
    
    canvas = Image.new("RGBA", (width, height), C_BLACK_BG)
    draw = ImageDraw.Draw(canvas)
    
    for y in range(height):
        ratio = y / height
        v = int(9 + 4 * (1 - abs(ratio - 0.45) * 2))
        draw.line([(0, y), (width, y)], fill=(v, v, v, 255))
        
    font_brand = get_font(22)
    font_page_title = get_font(28)
    font_section_header = get_font(18)
    font_desc = get_font(14)
    font_badge = get_font(13)
    
    # Top Header
    draw.text((80, 36), "  Apple Dynamic Island Paradigm", font=font_brand, fill=C_TITANIUM)
    
    title_text = f"PAGE {page_num:02d} — {page_title.upper()}"
    bbox = draw.textbbox((0, 0), title_text, font=font_page_title)
    title_w = bbox[2] - bbox[0]
    draw.text((width - 80 - title_w, 32), title_text, font=font_page_title, fill=C_WHITE)
    draw.line([(80, 76), (width - 80, 76)], fill=C_TITANIUM_BORDER, width=1)
    
    # -------------------------------------------------------------
    # TIER 1: STATE 2 — THE EXTENDED MORPH PILL (LIVE BACKGROUND HUD)
    # -------------------------------------------------------------
    t1_y = 96
    t1_w = width - 160
    t1_h = 240
    
    draw.rounded_rectangle([80, t1_y, 80 + t1_w, t1_y + t1_h], radius=18, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
    
    draw.text((108, t1_y + 18), "STATE 2 — THE EXTENDED MORPH PILL (LIVE BACKGROUND ACTIVITY HUD)", font=font_section_header, fill=C_WHITE)
    draw.text((108, t1_y + 42), f"Elongated Dynamic Island pill showing live telemetry while user works in background apps: {extended_spec['summary']}", font=font_desc, fill=C_TITANIUM)
    
    # Photorealistic Extended Pill rendered in central stage
    ep_w = 1100
    ep_h = 68
    ep_x = 80 + (t1_w - ep_w) // 2
    ep_y = t1_y + 74
    
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
    
    # Pill Annotations
    draw.text((ep_x + 24, ep_y + ep_h + 12), "◀ LEFT WING (LIVE CONTEXT)", font=get_font(10), fill=C_TITANIUM_MUTED)
    mid_ep = ep_x + ep_w // 2
    draw.text((mid_ep - 70, ep_y + ep_h + 12), "◆ CAMERA CLEARANCE", font=get_font(10), fill=C_TITANIUM_MUTED)
    draw.text((ep_x + ep_w - 200, ep_y + ep_h + 12), "RIGHT WING (LIVE TELEMETRY) ▶", font=get_font(10), fill=C_TITANIUM_MUTED)
    
    draw.text((108, t1_y + t1_h - 28), "✓ 100% Universal Coexistence: Does not interfere with browser tabs, code editors, or active productivity windows.", font=get_font(12), fill=C_WHITE)

    # -------------------------------------------------------------
    # TIER 2: STATE 3 — THE FULL BIG UI FOR MORPH (EXPANDED MODAL)
    # -------------------------------------------------------------
    t2_y = t1_y + t1_h + 30
    draw.text((80, t2_y), f"STATE 3 — THE FULL BIG UI FOR MORPH (EXPANDED MODAL WORKSPACE) — {subtitle.upper()}", font=font_section_header, fill=C_WHITE)
    draw.text((80, t2_y + 24), "Pure Minimalist 3-Color Apple Architecture (Pitch Black #000000, Studio White #FFFFFF, Titanium Gray #8E8E93)", font=font_desc, fill=C_TITANIUM)
    
    red_path = os.path.join(INPUT_DIR, redesign_img_name)
    if os.path.exists(red_path):
        red_img = Image.open(red_path).convert("L").convert("RGBA")
        
        target_w = 2080
        aspect = red_img.height / red_img.width
        target_h = int(target_w * aspect)
        red_resized = red_img.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        rx = (width - target_w) // 2
        ry = t2_y + 54
        
        shadow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(shadow)
        s_draw.rounded_rectangle([rx - 16, ry - 8, rx + target_w + 16, ry + target_h + 24], radius=32, fill=(0, 0, 0, 240))
        shadow = shadow.filter(ImageFilter.GaussianBlur(36))
        canvas = Image.alpha_composite(canvas, shadow)
        draw = ImageDraw.Draw(canvas)
        
        draw.rounded_rectangle([rx - 2, ry - 2, rx + target_w + 2, ry + target_h + 2], radius=28, fill=C_BLACK_OLED, outline=C_WHITE_RIM, width=1)
        canvas.paste(red_resized, (rx, ry), red_resized)

    # --- FOOTER HIG SPECIFICATION CHIPS ---
    footer_y = height - 70
    draw.line([(80, footer_y - 16), (width - 80, footer_y - 16)], fill=C_TITANIUM_BORDER, width=1)
    
    fx = 80
    for p_text in pills:
        pbox = draw.textbbox((0, 0), p_text, font=font_badge)
        pw = pbox[2] - pbox[0] + 32
        draw.rounded_rectangle([fx, footer_y, fx + pw, footer_y + 34], radius=17, fill=(20, 20, 20, 255), outline=C_TITANIUM_BORDER, width=1)
        draw.text((fx + 16, footer_y + 9), p_text, font=font_badge, fill=C_WHITE)
        fx += pw + 16
        
    sig = "Apple Human Interface Guidelines — Minimalist 3-Color Dynamic Island Architecture (Black #000000, White #FFFFFF, Titanium Gray #8E8E93)"
    sbox = draw.textbbox((0, 0), sig, font=get_font(13))
    draw.text((width - 80 - (sbox[2] - sbox[0]), footer_y + 9), sig, font=get_font(13), fill=C_TITANIUM)
    
    out_file = os.path.join(OUTPUT_DIR, output_name)
    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(out_file, "PNG")
    print(f"Created master page board: {out_file} ({os.path.getsize(out_file)/1024:.1f} KB)")

# Master Page Specifications (MANDATORY: Every page has 2: Extended Pill HUD + 3: Full Big UI)
pages = [
    (1, "Home View", "Ambient Intelligence Hub & Companion",
     {
         "summary": "Ambient live status companion presenting focus velocity, daily glance, and background system readiness",
         "left_title": "❖ Morph Ambient Active",
         "left_sub": "Focus Block in Progress",
         "right_title": "23:45",
         "right_sub": "Velocity 92%",
         "kind": "standard"
     },
     "apple_redesign_01_home.png", 
     [" Universal Coexistence", "State 2: Extended Live Pill", "State 3: Full Big UI", "Zero Tab/Window Occlusion"], 
     "morph_apple_dynamic_island_page_01.png"),
     
    (2, "Focus Timer", "Live Activity Countdown Dial",
     {
         "summary": "Live Pomodoro countdown activity with tabular digits and phase indicators running while user codes or writes",
         "left_title": "◷ Focus Session (Work)",
         "left_sub": "Phase 1 • Deep Work",
         "right_title": "24:59",
         "right_sub": "Remaining Time",
         "kind": "standard"
     },
     "apple_redesign_02_focus_timer.png", 
     [" Chrono Arc Gauge", "State 2: Extended Timer Pill", "State 3: Full Big UI", "Tabular Monochrome Digits"], 
     "morph_apple_dynamic_island_page_02.png"),
     
    (3, "Music Player", "Now Playing Waveform HUD",
     {
         "summary": "Live music streaming activity displaying track title, artist, and animated frequency equalizer bars",
         "left_title": "♫ BIRDS OF A FEATHER",
         "left_sub": "Billie Eilish • HIT ME HARD",
         "right_title": "Now Playing",
         "right_sub": "Spatial Audio",
         "kind": "waveform"
     },
     "apple_redesign_03_music.png", 
     [" Live Frequency Equalizer", "State 2: Extended Music Pill", "State 3: Full Big UI", "Spatial Audio Routing"], 
     "morph_apple_dynamic_island_page_03.png"),
     
    (4, "Scratchpad Notes", "Quick Notes Floating Glasspad",
     {
         "summary": "Pinned quick note telemetry displaying active sprint takeaways and checklist completion counts",
         "left_title": "✎ Sprint Planning Takeaways",
         "left_sub": "Pinned to Dynamic Island",
         "right_title": "3/5 Tasks Done",
         "right_sub": "42 Words Pinned",
         "kind": "standard"
     },
     "apple_redesign_04_notes.png", 
     [" Quick Notes Pinned", "State 2: Extended Note Pill", "State 3: Full Big UI", "Markdown Checklist Engine"], 
     "morph_apple_dynamic_island_page_04.png"),
     
    (5, "Calendar & Schedule", "Smart Agenda & FaceTime Join Deck",
     {
         "summary": "Live meeting countdown indicator with 1-click video call join button ready before meetings start",
         "left_title": "In 14m: Design Review & Standup",
         "left_sub": "Virtual Room A • 4 Attendees",
         "right_title": "⇲ Join Call",
         "right_sub": "FaceTime / Meet",
         "kind": "button"
     },
     "apple_redesign_05_calendar.png", 
     [" Smart Agenda Countdown", "State 2: Extended Meeting Pill", "State 3: Full Big UI", "1-Click Meeting Join"], 
     "morph_apple_dynamic_island_page_05.png"),
     
    (6, "Profile & Preferences", "Apple ID & System Control Center",
     {
         "summary": "Apple ID cloud synchronization status, MacBook battery telemetry, and system performance health",
         "left_title": " Aaron Nguyen • Apple ID",
         "left_sub": "iCloud Synced • All Macs",
         "right_title": "98% ⚡ Battery",
         "right_sub": "Optimized Charging",
         "kind": "standard"
     },
     "apple_redesign_06_profile.png", 
     [" Apple ID Cloud Sync", "State 2: Extended Profile Pill", "State 3: Full Big UI", "System Control Center"], 
     "morph_apple_dynamic_island_page_06.png"),
     
    (7, "Meeting Cockpit", "FaceTime & Call Flight Deck",
     {
         "summary": "Active call duration timer with live voice isolation indicator and tactile mute/hangup controls",
         "left_title": "● 08:42 Live Call",
         "left_sub": "Voice Isolation Active",
         "right_title": "⊘ Muted  ✕ End",
         "right_sub": "Call Controls",
         "kind": "button"
     },
     "apple_redesign_07_meeting_cockpit.png", 
     [" Audio Waveform HUD", "State 2: Extended Call Pill", "State 3: Full Big UI", "Tactile Mic/End Toggles"], 
     "morph_apple_dynamic_island_page_07.png"),
     
    (8, "Drop Shelf", "AirDrop Staging Bay",
     {
         "summary": "AirDrop staging bay displaying count of staged files and total payload size ready to drag out to any app",
         "left_title": "⇲ 3 Files Staged",
         "left_sub": "PDF, Swift, Figma Export",
         "right_title": "14.2 MB",
         "right_sub": "Ready to Drag Out",
         "kind": "standard"
     },
     "apple_redesign_08_drop_shelf.png", 
     [" AirDrop Staging Bay", "State 2: Extended Shelf Pill", "State 3: Full Big UI", "Multi-File Drag-Out"], 
     "morph_apple_dynamic_island_page_08.png"),
     
    (9, "Application Form Tracker", "Neural Autofill & Form Intelligence HUD",
     {
         "summary": "Live question tracker and field intelligence indicator displaying current question number and autofill readiness",
         "left_title": "Q2/12 SHORT: Full Name",
         "left_sub": "Google Forms • Polar Browser",
         "right_title": "⚡ AUTOFILL",
         "right_sub": "Press 1 or Enter",
         "kind": "standard"
     },
     "apple_redesign_09_form_tracker.png", 
     [" Neural Form Intelligence", "State 2: Extended Form Pill", "State 3: Full Big UI", "Synchronous Autofill"], 
     "morph_apple_dynamic_island_page_09.png"),
     
    (10, "Compact Notch HUD", "Resting State & Multi-Activity Live HUD",
     {
         "summary": "Multi-Activity dual live activity HUD balancing simultaneous background activities (Timer on left + Music on right)",
         "left_title": "◷ 24:59 Focus",
         "left_sub": "Pomodoro Phase 1",
         "right_title": "♫ BIRDS OF A FEATHER",
         "right_sub": "Live Waveform",
         "kind": "waveform"
     },
     "apple_redesign_10_compact_hud.png", 
     [" Dual Live Activities", "State 2: Extended Dual Pill", "State 3: Full Big UI", "Multi-Activity Balance"], 
     "morph_apple_dynamic_island_page_10.png")
]

if __name__ == "__main__":
    create_master_architecture_and_resting_board()
    create_hover_lifecycle_board()
    for p in pages:
        create_master_page_board(p[0], p[1], p[2], p[3], p[4], p[5], p[6])
    print("ALL 12 MASTER BOARDS (STATE 1 RESTING + STATE 2 EXTENDED PILL + STATE 3 FULL BIG UI) CREATED!")
