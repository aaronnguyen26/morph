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

def draw_window_traffic_lights(draw, x, y):
    draw.ellipse([x + 18, y + 16, x + 28, y + 26], fill=(45, 45, 45, 255), outline=C_TITANIUM_MUTED, width=1)
    draw.ellipse([x + 36, y + 16, x + 46, y + 26], fill=(45, 45, 45, 255), outline=C_TITANIUM_MUTED, width=1)
    draw.ellipse([x + 54, y + 16, x + 64, y + 26], fill=(45, 45, 45, 255), outline=C_TITANIUM_MUTED, width=1)

def draw_code_editor_window(draw, x, y, w, h, active_file="MorphController.swift", show_stealth_pill=True):
    """Developer IDE Workspace (VS Code / Xcode)"""
    draw.rounded_rectangle([x, y, x + w, y + h], radius=14, fill=(16, 16, 16, 255), outline=C_TITANIUM_BORDER, width=1)
    chrome_h = 44
    draw.rounded_rectangle([x, y, x + w, y + chrome_h], radius=14, fill=(24, 24, 24, 255))
    draw.rectangle([x, y + 20, x + w, y + chrome_h], fill=(24, 24, 24, 255))
    draw.line([(x, y + chrome_h), (x + w, y + chrome_h)], fill=C_TITANIUM_FAINT, width=1)
    
    draw_window_traffic_lights(draw, x, y)
    
    tab_y = y + 8
    tab_h = 28
    # Editor Tabs
    draw.rounded_rectangle([x + 85, tab_y, x + 220, tab_y + tab_h], radius=7, fill=(38, 38, 38, 255), outline=C_WHITE_RIM, width=1)
    draw.text((x + 98, tab_y + 6), f"⌥ {active_file}", font=get_font(11), fill=C_WHITE)
    
    draw.rounded_rectangle([x + 230, tab_y, x + 350, tab_y + tab_h], radius=7, fill=(28, 28, 28, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((x + 242, tab_y + 6), "NotchModel.swift", font=get_font(11), fill=C_TITANIUM)
    
    draw.rounded_rectangle([x + 360, tab_y, x + 388, tab_y + tab_h], radius=7, fill=(24, 24, 24, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((x + 370, tab_y + 5), "+", font=get_font(12), fill=C_TITANIUM)
    
    # Scheme selector on right
    draw.rounded_rectangle([x + w - 240, tab_y, x + w - 30, tab_y + tab_h], radius=7, fill=(28, 28, 28, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((x + w - 225, tab_y + 6), "▶  Morph > My Mac (Apple Silicon)", font=get_font(10), fill=C_TITANIUM)
    
    # Editor Line wireframe
    vp_y = y + chrome_h + 12
    draw.text((x + 24, vp_y), "CODE EDITOR WORKSPACE — ZERO TAB OR BREAKPOINT OCCLUSION", font=get_font(10), fill=C_TITANIUM_MUTED)
    for row in range(5):
        ly = vp_y + 24 + row * 18
        draw.text((x + 24, ly), f"{row+1:2d}", font=get_font(10), fill=C_TITANIUM_MUTED)
        draw.rounded_rectangle([x + 50, ly + 2, x + 160 + (row * 60) % 240, ly + 10], radius=3, fill=(30, 30, 30, 255))
        
    if show_stealth_pill:
        pill_w = 210
        pill_h = 36
        pill_x = x + (w - pill_w) // 2
        pill_y = y + 4
        draw_pill_outline(draw, pill_x, pill_y, pill_w, pill_h)

def draw_browser_window(draw, x, y, w, h, browser_title="Chrome / Polar", active_tab="Docs • Reading Response", show_stealth_pill=True):
    """Web Browser Workspace (Chrome / Polar / Safari / Arc / Firefox)"""
    draw.rounded_rectangle([x, y, x + w, y + h], radius=14, fill=(16, 16, 16, 255), outline=C_TITANIUM_BORDER, width=1)
    chrome_h = 44
    draw.rounded_rectangle([x, y, x + w, y + chrome_h], radius=14, fill=(24, 24, 24, 255))
    draw.rectangle([x, y + 20, x + w, y + chrome_h], fill=(24, 24, 24, 255))
    draw.line([(x, y + chrome_h), (x + w, y + chrome_h)], fill=C_TITANIUM_FAINT, width=1)
    
    draw_window_traffic_lights(draw, x, y)
    
    tab_y = y + 8
    tab_h = 28
    draw.rounded_rectangle([x + 85, tab_y, x + 235, tab_y + tab_h], radius=7, fill=(38, 38, 38, 255), outline=C_WHITE_RIM, width=1)
    draw.text((x + 98, tab_y + 6), active_tab, font=get_font(11), fill=C_WHITE)
    
    draw.rounded_rectangle([x + 245, tab_y, x + 365, tab_y + tab_h], radius=7, fill=(28, 28, 28, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((x + 258, tab_y + 6), "GitHub — morph", font=get_font(11), fill=C_TITANIUM)
    
    draw.rounded_rectangle([x + 375, tab_y, x + 405, tab_y + tab_h], radius=7, fill=(24, 24, 24, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((x + 386, tab_y + 5), "+", font=get_font(12), fill=C_TITANIUM)
    
    # Omnibox on right
    omni_w = 260
    omni_x = x + w - omni_w - 20
    draw.rounded_rectangle([omni_x, tab_y, omni_x + omni_w, tab_y + tab_h], radius=7, fill=(14, 14, 14, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((omni_x + 14, tab_y + 6), "docs.google.com/document/d/...", font=get_font(10), fill=C_TITANIUM)
    
    vp_y = y + chrome_h + 12
    draw.text((x + 24, vp_y), f"WEB WORKSPACE ({browser_title.upper()}) — ZERO TAB OCCLUSION", font=get_font(10), fill=C_TITANIUM_MUTED)
    draw.rounded_rectangle([x + 24, vp_y + 24, x + 320, vp_y + 36], radius=4, fill=(30, 30, 30, 255))
    draw.rounded_rectangle([x + 24, vp_y + 44, x + 460, vp_y + 54], radius=3, fill=(24, 24, 24, 255))
    draw.rounded_rectangle([x + 24, vp_y + 62, x + 400, vp_y + 72], radius=3, fill=(24, 24, 24, 255))
    
    if show_stealth_pill:
        pill_w = 210
        pill_h = 36
        pill_x = x + (w - pill_w) // 2
        pill_y = y + 4
        draw_pill_outline(draw, pill_x, pill_y, pill_w, pill_h)

def draw_productivity_window(draw, x, y, w, h, app_title="Figma / Slack", doc_title="Design System & Canvas", show_stealth_pill=True):
    """Creative & Productivity Workspace (Figma / Slack / Notion / Pages / Finder)"""
    draw.rounded_rectangle([x, y, x + w, y + h], radius=14, fill=(16, 16, 16, 255), outline=C_TITANIUM_BORDER, width=1)
    chrome_h = 44
    draw.rounded_rectangle([x, y, x + w, y + chrome_h], radius=14, fill=(24, 24, 24, 255))
    draw.rectangle([x, y + 20, x + w, y + chrome_h], fill=(24, 24, 24, 255))
    draw.line([(x, y + chrome_h), (x + w, y + chrome_h)], fill=C_TITANIUM_FAINT, width=1)
    
    draw_window_traffic_lights(draw, x, y)
    
    tab_y = y + 8
    tab_h = 28
    draw.rounded_rectangle([x + 85, tab_y, x + 240, tab_y + tab_h], radius=7, fill=(38, 38, 38, 255), outline=C_WHITE_RIM, width=1)
    draw.text((x + 98, tab_y + 6), f"❖ {doc_title}", font=get_font(11), fill=C_WHITE)
    
    # Tool buttons
    tools = ["Select", "Frame", "Shape", "Pen", "Text", "Plugins"]
    tx = x + 250
    for t in tools:
        draw.rounded_rectangle([tx, tab_y, tx + 46, tab_y + tab_h], radius=6, fill=(26, 26, 26, 255), outline=C_TITANIUM_BORDER, width=1)
        draw.text((tx + 7, tab_y + 7), t[:4], font=get_font(10), fill=C_TITANIUM)
        tx += 52
        
    draw.rounded_rectangle([x + w - 160, tab_y, x + w - 30, tab_y + tab_h], radius=7, fill=(36, 36, 36, 255), outline=C_WHITE_RIM, width=1)
    draw.text((x + w - 146, tab_y + 6), "Share / Present", font=get_font(10), fill=C_WHITE)
    
    vp_y = y + chrome_h + 12
    draw.text((x + 24, vp_y), f"PRODUCTIVITY WORKSPACE ({app_title.upper()}) — ZERO TOOLBAR OCCLUSION", font=get_font(10), fill=C_TITANIUM_MUTED)
    draw.rounded_rectangle([x + 24, vp_y + 24, x + 220, vp_y + 90], radius=8, fill=(24, 24, 24, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.rounded_rectangle([x + 260, vp_y + 24, x + 460, vp_y + 90], radius=8, fill=(24, 24, 24, 255), outline=C_TITANIUM_BORDER, width=1)
    
    if show_stealth_pill:
        pill_w = 210
        pill_h = 36
        pill_x = x + (w - pill_w) // 2
        pill_y = y + 4
        draw_pill_outline(draw, pill_x, pill_y, pill_w, pill_h)

def create_universal_architecture_board():
    """Generates the Master Architecture board showing coexistence across ALL macOS platform archetypes"""
    w = 2560
    h = 2300
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
    
    # Master Header
    draw.text((80, 48), "  DYNAMIC ISLAND — ZERO-OCCLUSION CROSS-PLATFORM COEXISTENCE", font=font_title, fill=C_WHITE)
    draw.text((80, 92), "Strict 3-Color Monochromatic Architecture: Pitch Black #000000, Studio White #FFFFFF, Titanium Gray #8E8E93", font=font_subtitle, fill=C_TITANIUM)
    draw.line([(80, 130), (w - 80, 130)], fill=C_TITANIUM_BORDER, width=1)
    
    # 3 Parallel Platform Columns
    cols = [
        ("PLATFORM ARCHETYPE A: CODE EDITORS & IDEs", 
         "VS Code, Xcode, JetBrains, Terminal, iTerm",
         "draw_code",
         "Dynamic Island rests in the central 320px deadband.\nClear fill and subtle 0.75pt titanium outline.\nEditor tabs, run actions, and line numbers are 100% visible.\nClicks pass straight through to code tabs without interception.",
         "ZERO EDITOR TAB BLOCKING"),
        ("PLATFORM ARCHETYPE B: WEB & DOCUMENT BROWSERS",
         "Chrome, Polar, Safari, Arc, Brave, Firefox, Edge",
         "draw_browser",
         "Universal click-through across multi-tab browser strips.\nZero interference with Google Docs, Sheets, or tab switching.\nGlobal click & drag monitors instantly cancel hover intent.\nOnly a deliberate 320ms dwell expands into fuller UI.",
         "ZERO BROWSER TAB OCCLUSION"),
        ("PLATFORM ARCHETYPE C: CREATIVE & PRODUCTIVITY",
         "Figma, Slack, Notion, Obsidian, Pages, Finder",
         "draw_prod",
         "Resting stealth mode lets top toolbars remain 100% accessible.\nKeystrokes, text selection, and window drags cancel hover.\nFull compatibility with fullscreen and multi-window displays.\nAutonomous 4-sided squircle unfolds cleanly on demand.",
         "ZERO TOOLBAR INTERFERENCE")
    ]
    
    col_w = (w - 160 - 80) // 3
    col_h = 2050
    
    for i, (title, sub, draw_type, desc, badge_txt) in enumerate(cols):
        cx = 80 + i * (col_w + 40)
        cy = 160
        
        draw.rounded_rectangle([cx, cy, cx + col_w, cy + col_h], radius=18, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
        
        # Column Header
        draw.text((cx + 28, cy + 24), title, font=get_font(16), fill=C_WHITE)
        draw.text((cx + 28, cy + 48), sub, font=get_font(12), fill=C_TITANIUM)
        draw.line([(cx + 28, cy + 74), (cx + col_w - 28, cy + 74)], fill=C_TITANIUM_BORDER, width=1)
        
        # Mockup 1: Resting Stealth Wireframe
        my1 = cy + 96
        mw = col_w - 56
        mh = 230
        if draw_type == "draw_code":
            draw_code_editor_window(draw, cx + 28, my1, mw, mh, active_file="MorphController.swift", show_stealth_pill=True)
        elif draw_type == "draw_browser":
            draw_browser_window(draw, cx + 28, my1, mw, mh, browser_title="Chrome / Polar", active_tab="Google Docs #4", show_stealth_pill=True)
        else:
            draw_productivity_window(draw, cx + 28, my1, mw, mh, app_title="Figma", doc_title="Design System v4", show_stealth_pill=True)
            
        draw.text((cx + 28, my1 + mh + 14), "1. Resting State: Transparent outline, 100% click-through", font=get_font(11), fill=C_TITANIUM)
        
        # Mockup 2: Hover Awaken / Intent Gate Wireframe
        my2 = my1 + mh + 48
        if draw_type == "draw_code":
            draw_code_editor_window(draw, cx + 28, my2, mw, mh, active_file="NotchModel.swift", show_stealth_pill=False)
        elif draw_type == "draw_browser":
            draw_browser_window(draw, cx + 28, my2, mw, mh, browser_title="Safari", active_tab="GitHub — morph", show_stealth_pill=False)
        else:
            draw_productivity_window(draw, cx + 28, my2, mw, mh, app_title="Slack", doc_title="Team Channel", show_stealth_pill=False)
            
        pill_w = 210
        pill_h = 36
        pill_x = (cx + 28) + (mw - pill_w) // 2
        pill_y = my2 + 4
        draw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=18, fill=C_BLACK_OLED, outline=C_WHITE_RIM, width=1)
        
        # Simulated pointer dwelling
        px_cur = pill_x + 105
        py_cur = pill_y + 18
        draw.polygon([(px_cur, py_cur), (px_cur + 11, py_cur + 11), (px_cur + 5, py_cur + 12), (px_cur + 7, py_cur + 18), (px_cur + 4, py_cur + 19), (px_cur + 2, py_cur + 13), (px_cur - 2, py_cur + 17)], fill=C_WHITE, outline=C_BLACK_OLED)
        draw.text((cx + 28, my2 + mh + 14), "2. Intent Dwell: Cursor settles >320ms, awakens OLED solid black", font=get_font(11), fill=C_WHITE)
        
        # Mockup 3: Fuller UI Expansion
        my3 = my2 + mh + 48
        red_names = ["apple_redesign_02_focus_timer.png", "apple_redesign_01_home.png", "apple_redesign_04_notes.png"]
        rname = red_names[i]
        rpath = os.path.join(INPUT_DIR, rname)
        if os.path.exists(rpath):
            rimg = Image.open(rpath).convert("L").convert("RGBA")
            target_rw = mw
            target_rh = int(target_rw * (rimg.height / rimg.width))
            rimg = rimg.resize((target_rw, target_rh), Image.Resampling.LANCZOS)
            
            # Shadow
            shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            sd = ImageDraw.Draw(shadow)
            sd.rounded_rectangle([cx + 24, my3 - 4, cx + 28 + target_rw + 4, my3 + target_rh + 12], radius=24, fill=(0, 0, 0, 240))
            shadow = shadow.filter(ImageFilter.GaussianBlur(20))
            canvas = Image.alpha_composite(canvas, shadow)
            draw = ImageDraw.Draw(canvas)
            
            draw.rounded_rectangle([cx + 26, my3 - 2, cx + 28 + target_rw + 2, my3 + target_rh + 2], radius=20, fill=C_BLACK_OLED, outline=C_WHITE_RIM, width=1)
            canvas.paste(rimg, (cx + 28, my3), rimg)
            
        draw.text((cx + 28, my3 + 460 + 14), "3. Spring Expansion: Unfolds into autonomous 4-sided squircle", font=get_font(11), fill=C_WHITE)
        
        # Technical Explanations
        desc_y = my3 + 460 + 44
        draw.text((cx + 28, desc_y), "INTENT & COEXISTENCE SPECIFICATIONS", font=get_font(11), fill=C_TITANIUM)
        curr_y = desc_y + 24
        for line in desc.split("\n"):
            draw.text((cx + 28, curr_y), line.strip(), font=font_body, fill=C_WHITE if "100%" in line or "Zero" in line else C_TITANIUM)
            curr_y += 22
            
        # HIG Chip at bottom
        draw.rounded_rectangle([cx + 28, cy + col_h - 50, cx + col_w - 28, cy + col_h - 18], radius=10, fill=(24, 24, 24, 255), outline=C_TITANIUM_BORDER, width=1)
        draw.text((cx + 42, cy + col_h - 38), f" HIG COMPLIANCE — {badge_txt}", font=font_badge, fill=C_WHITE)
        
    out_file = os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_stitch_architecture.png")
    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(out_file, "PNG")
    print(f"Created universal architecture board: {out_file} ({os.path.getsize(out_file)/1024:.1f} KB)")

def create_hover_lifecycle_board():
    """Generates the dedicated architectural hover lifecycle board across universal platforms"""
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
    
    # Header
    draw.text((80, 48), "  DYNAMIC ISLAND — UNIVERSAL INTENT DIFFERENTIATION ENGINE", font=font_title, fill=C_WHITE)
    draw.text((80, 92), "Works Across All macOS Platforms: Code Editors, Web Browsers, Terminals, Design & Productivity Suites", font=font_subtitle, fill=C_TITANIUM)
    draw.line([(80, 130), (w - 80, 130)], fill=C_TITANIUM_BORDER, width=1)
    
    stages = [
        ("STAGE 1: RESTING STEALTH (UNIVERSAL)", 
         "Dynamic Island rests silently across ANY active window.\nClear fill and subtle 0.75pt titanium hairline outline.\nPassthroughHostingView returns nil; panel ignores mouse events.\nClicks on tabs, toolbars, or window headers pass 100% through.",
         "TRANSPARENT CLICK-THROUGH"),
        ("STAGE 2: UNIVERSAL INTENT DIFFERENTIATION",
         "Active typing, clicking tabs, dragging windows, or scrolling in ANY app\nimmediately cancels hover intent and enforces a 450ms cooldown.\nFast cursor sweeps (>140px/s) pass right through with zero popup.\nOnly deliberate resting/dwelling (>320ms) awakens solid OLED black.",
         "INTENT DWELL & VELOCITY GATE"),
        ("STAGE 3: FLUID 4-SIDED SQUIRCLE EXPANSION",
         "Deliberate dwell triggers organic spring expansion (0.38s response).\nExpands downward as an autonomous, freestanding Apple Dynamic Island.\nZero camera notch cutout — 100% active screen space.\nInstant auto-dismiss when cursor leaves the island boundaries.",
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
        
        safari_x = px + 32
        safari_y = py + 84
        safari_w = panel_w - 64
        safari_h = 440
        
        if i == 0:
            draw_code_editor_window(draw, safari_x, safari_y, safari_w, safari_h, active_file="VS Code • App.swift", show_stealth_pill=True)
            draw.text((safari_x + 20, safari_y + safari_h - 30), "Resting across VS Code: Outline only, 0% tab occlusion", font=get_font(12), fill=C_TITANIUM)
        elif i == 1:
            draw_browser_window(draw, safari_x, safari_y, safari_w, safari_h, browser_title="Chrome / Polar", active_tab="Google Docs / Sheets", show_stealth_pill=False)
            pill_w = 210
            pill_h = 36
            pill_x = safari_x + (safari_w - pill_w) // 2
            pill_y = safari_y + 4
            draw.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], radius=18, fill=C_BLACK_OLED, outline=C_WHITE_RIM, width=1)
            cx = pill_x + 130
            cy = pill_y + 24
            draw.polygon([(cx, cy), (cx + 12, cy + 12), (cx + 5, cy + 13), (cx + 8, cy + 20), (cx + 4, cy + 22), (cx + 1, cy + 15), (cx - 3, cy + 19)], fill=C_WHITE, outline=C_BLACK_OLED)
            draw.text((safari_x + 20, safari_y + safari_h - 30), "Intent Validated: Awakens solid black after deliberate dwell", font=get_font(12), fill=C_WHITE)
        elif i == 2:
            draw_productivity_window(draw, safari_x, safari_y, safari_w, safari_h, app_title="Figma", doc_title="Design System", show_stealth_pill=False)
            red_path = os.path.join(INPUT_DIR, "apple_redesign_01_home.png")
            if os.path.exists(red_path):
                rimg = Image.open(red_path).convert("L").convert("RGBA")
                rw = safari_w - 40
                rh = int(rw * (rimg.height / rimg.width))
                rimg = rimg.resize((rw, rh), Image.Resampling.LANCZOS)
                rx = safari_x + 20
                ry = safari_y + 30
                
                shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                s_draw = ImageDraw.Draw(shadow)
                s_draw.rounded_rectangle([rx - 10, ry - 6, rx + rw + 10, ry + rh + 16], radius=24, fill=(0, 0, 0, 240))
                shadow = shadow.filter(ImageFilter.GaussianBlur(24))
                canvas = Image.alpha_composite(canvas, shadow)
                draw = ImageDraw.Draw(canvas)
                
                draw.rounded_rectangle([rx - 2, ry - 2, rx + rw + 2, ry + rh + 2], radius=20, fill=C_BLACK_OLED, outline=C_WHITE_RIM, width=1)
                canvas.paste(rimg, (rx, ry), rimg)
                draw.text((safari_x + 20, safari_y + safari_h - 30), "Expanded Fuller UI: Autonomous 4-sided squircle", font=get_font(12), fill=C_WHITE)
                
        desc_y = safari_y + safari_h + 30
        draw.text((px + 32, desc_y), "SPATIAL MECHANICS SPECIFICATION", font=get_font(11), fill=C_TITANIUM)
        curr_y = desc_y + 28
        for line in desc.split("\n"):
            if line.strip():
                draw.text((px + 32, curr_y), line.strip(), font=font_body, fill=C_WHITE if "100%" in line or "Deliberate" in line or "Zero" in line else C_TITANIUM)
                curr_y += 24
            else:
                curr_y += 12
                
        draw.rounded_rectangle([px + 32, py + panel_h - 56, px + panel_w - 32, py + panel_h - 20], radius=10, fill=(24, 24, 24, 255), outline=C_TITANIUM_BORDER, width=1)
        draw.text((px + 48, py + panel_h - 44), f" HIG COMPLIANCE — {badge_txt}", font=font_badge, fill=C_WHITE)
        
    out_file = os.path.join(OUTPUT_DIR, "morph_apple_dynamic_island_hover_lifecycle.png")
    canvas = canvas.convert("L").convert("RGBA")
    canvas.save(out_file, "PNG")
    print(f"Created architecture overview board: {out_file} ({os.path.getsize(out_file)/1024:.1f} KB)")

def create_master_page_board(page_num, page_title, subtitle, app_type, redesign_img_name, pills, output_name):
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
    
    # --- TIER 1: UNIVERSAL PLATFORM COEXISTENCE SIMULATOR ---
    t1_y = 96
    t1_h = 320
    t1_w = width - 160
    
    draw.rounded_rectangle([80, t1_y, 80 + t1_w, t1_y + t1_h], radius=18, fill=C_BLACK_CARD, outline=C_TITANIUM_BORDER, width=1)
    
    left_w = (t1_w - 60) // 2
    left_x = 100
    draw.text((left_x, t1_y + 18), "ZERO-OCCLUSION UNIVERSAL PLATFORM COEXISTENCE", font=font_section_header, fill=C_WHITE)
    draw.text((left_x, t1_y + 42), "Floats with 14pt clearance in 320px central deadband — Tabs, code & toolbars in ANY app 100% accessible", font=font_desc, fill=C_TITANIUM)
    
    if app_type == "code":
        draw_code_editor_window(draw, left_x, t1_y + 70, left_w, 230, active_file="MorphApp.swift", show_stealth_pill=True)
    elif app_type == "browser":
        draw_browser_window(draw, left_x, t1_y + 70, left_w, 230, browser_title="Chrome / Polar", active_tab="Google Docs / Workspace", show_stealth_pill=True)
    else:
        draw_productivity_window(draw, left_x, t1_y + 70, left_w, 230, app_title="Figma / Slack", doc_title="Design System / Team", show_stealth_pill=True)
        
    right_x = left_x + left_w + 40
    right_w = left_w
    draw.text((right_x, t1_y + 18), "UNIVERSAL INTENT ENGINE LIFECYCLE", font=font_section_header, fill=C_WHITE)
    draw.text((right_x, t1_y + 42), "Typing, clicking, or scrolling in ANY app suppresses expansion — only deliberate dwell triggers Fuller UI", font=font_desc, fill=C_TITANIUM)
    
    flow_y = t1_y + 70
    flow_h = 230
    draw.rounded_rectangle([right_x, flow_y, right_x + right_w, flow_y + flow_h], radius=14, fill=(18, 18, 18, 255), outline=C_TITANIUM_BORDER, width=1)
    
    draw.rounded_rectangle([right_x + 24, flow_y + 24, right_x + 320, flow_y + 74], radius=12, fill=(24, 24, 24, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((right_x + 40, flow_y + 36), "1. Resting State", font=get_font(12), fill=C_TITANIUM)
    draw.text((right_x + 40, flow_y + 52), "Stealth outline, click-through", font=get_font(13), fill=C_WHITE)
    
    draw.rounded_rectangle([right_x + 360, flow_y + 24, right_x + 680, flow_y + 74], radius=12, fill=(24, 24, 24, 255), outline=C_TITANIUM_BORDER, width=1)
    draw.text((right_x + 376, flow_y + 36), "2. Intent Filter", font=get_font(12), fill=C_TITANIUM)
    draw.text((right_x + 376, flow_y + 52), "Suppresses sweeps, typing & drags", font=get_font(13), fill=C_WHITE)
    
    draw.rounded_rectangle([right_x + 720, flow_y + 24, right_x + right_w - 24, flow_y + 74], radius=12, fill=(24, 24, 24, 255), outline=C_WHITE_RIM, width=1)
    draw.text((right_x + 736, flow_y + 36), "3. Deliberate Dwell", font=get_font(12), fill=C_TITANIUM)
    draw.text((right_x + 736, flow_y + 52), "Fluid modal expansion into Fuller UI", font=get_font(13), fill=C_WHITE)
    
    draw.text((right_x + 28, flow_y + 104), "HIG CROSS-PLATFORM SPECIFICATIONS", font=get_font(11), fill=C_TITANIUM)
    draw.text((right_x + 28, flow_y + 128), "— Universal Coexistence: Zero tab or button obstruction across VS Code, Chrome, Terminal, Slack & Figma", font=font_desc, fill=C_WHITE)
    draw.text((right_x + 28, flow_y + 152), "— Zero Camera Notch Cutout: Fully autonomous 4-sided squircle decoupled from physical hardware notch", font=font_desc, fill=C_WHITE)
    draw.text((right_x + 28, flow_y + 176), "— Universal Intent Engine: 320ms dwell and velocity filter differentiate active app work from deliberate opening", font=font_desc, fill=C_TITANIUM)
    draw.text((right_x + 28, flow_y + 200), "— Pure Click-Through: In idle resting mode, clicks pass straight through to whatever window is underneath", font=font_desc, fill=C_TITANIUM)

    # --- TIER 2: AUTONOMOUS DYNAMIC ISLAND FULLER UI REDESIGN ---
    t2_y = 440
    draw.text((80, t2_y), f"AUTONOMOUS DYNAMIC ISLAND FULLER UI — {subtitle.upper()}", font=font_section_header, fill=C_WHITE)
    draw.text((80, t2_y + 24), "Pure Minimalist 3-Color Apple Architecture (Pitch Black #000000, Studio White #FFFFFF, Titanium Gray #8E8E93)", font=font_desc, fill=C_TITANIUM)
    
    red_path = os.path.join(INPUT_DIR, redesign_img_name)
    if os.path.exists(red_path):
        red_img = Image.open(red_path).convert("L").convert("RGBA")
        
        target_w = 2080
        aspect = red_img.height / red_img.width
        target_h = int(target_w * aspect)
        red_resized = red_img.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        rx = (width - target_w) // 2
        ry = t2_y + 60
        
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

pages = [
    (1, "Home View", "Ambient Intelligence Hub & Companion", "browser",
     "apple_redesign_01_home.png", 
     [" Universal Coexistence", "Acoustic Waveform Core", "Tactile Frosted Glass", "Zero Tab/Window Occlusion"], 
     "morph_apple_dynamic_island_page_01.png"),
     
    (2, "Focus Timer", "Live Activity Countdown Dial", "code",
     "apple_redesign_02_focus_timer.png", 
     [" VS Code / Xcode Coexistence", "Chrono Arc Gauge", "Monochrome Tabular Digits", "Zero Breakpoint Occlusion"], 
     "morph_apple_dynamic_island_page_02.png"),
     
    (3, "Music Player", "Now Playing Waveform HUD", "productivity",
     "apple_redesign_03_music.png", 
     [" Creative Canvas Coexistence", "Live Audio Waveform", "AirPods Spatial Routing", "Zero Toolbar Occlusion"], 
     "morph_apple_dynamic_island_page_03.png"),
     
    (4, "Scratchpad Notes", "Quick Notes Floating Glasspad", "code",
     "apple_redesign_04_notes.png", 
     [" Developer Scratchpad", "Pinned Autonomous Deck", "Markdown Checklist Engine", "Universal Typing Protection"], 
     "morph_apple_dynamic_island_page_04.png"),
     
    (5, "Calendar & Schedule", "Smart Agenda & FaceTime Join Deck", "productivity",
     "apple_redesign_05_calendar.png", 
     [" Slack & Calendar Coexistence", "7-Column Mini Month Grid", "FaceTime & Meet One-Tap Join", "Attendee Avatar Stacks"], 
     "morph_apple_dynamic_island_page_05.png"),
     
    (6, "Profile & Preferences", "Apple ID & System Control Center", "code",
     "apple_redesign_06_profile.png", 
     [" Apple ID iCloud Sync", "Control Center Glass Tiles", "MacBook & iPhone Handoff", "Autonomous Island Pinning"], 
     "morph_apple_dynamic_island_page_06.png"),
     
    (7, "Meeting Cockpit", "FaceTime & Call Flight Deck", "productivity",
     "apple_redesign_07_meeting_cockpit.png", 
     [" Zoom / Meet Telepresence", "Tactile Mic & Video Toggles", "Voice Isolation Active", "Spatial Head Tracking"], 
     "morph_apple_dynamic_island_page_07.png"),
     
    (8, "Drop Shelf", "AirDrop Staging Bay", "browser",
     "apple_redesign_08_drop_shelf.png", 
     [" Finder & AirDrop Bay", "Instant Drag-to-Island Staging", "Visual File Type Badges", "Multi-File Drag-Out"], 
     "morph_apple_dynamic_island_page_08.png"),
     
    (9, "Application Form Tracker", "Neural Autofill & Form Intelligence HUD", "browser",
     "apple_redesign_09_form_tracker.png", 
     [" Universal Web & ATS Portals", "Live DOM Question Extraction", "Interactive Option Pills", "Synchronous Capture"], 
     "morph_apple_dynamic_island_page_09.png"),
     
    (10, "Compact Notch HUD", "Resting State & Multi-Activity Live HUD", "productivity",
     "apple_redesign_10_compact_hud.png", 
     [" True OLED Black #000000", "Bilateral Multi-Tasking Bubbles", "Specular Outer Rim Highlight", "Zero Distraction When Idle"], 
     "morph_apple_dynamic_island_page_10.png")
]

if __name__ == "__main__":
    create_universal_architecture_board()
    create_hover_lifecycle_board()
    for p in pages:
        create_master_page_board(p[0], p[1], p[2], p[3], p[4], p[5], p[6])
    print("ALL UNIVERSAL APPLE DYNAMIC ISLAND BOARDS SUCCESSFULLY CREATED!")
