# Morph 🛸

**Module:** Everyday Productivity & Browsing  
**Design:** Pure OLED Black Minimalist Dynamic Island (Monochrome Architecture)

Morph is a native macOS Dynamic Island utility anchored directly to the MacBook hardware notch.

---

## 🖤 Minimalist Pure Black Aesthetic

- **OLED Pure Black:** Built with deep `#000000` black background surfaces and crisp monochrome typography. No noisy color soup.
- **Matching Notch Border Edges:** The outer island features continuous squircle curvature (`UnevenRoundedRectangle`) with a subtle hairline border edge (`white @ 14%`) that follows the exact physical contour of the MacBook notch bezel.
- **Zero Protrusion at Rest:** When idle, Morph is 100% flush inside the hardware notch (`179 × 32 pt`). It never sticks out into your display or menu bar.

---

## 📐 Expanded Form Factor (580 × 240 pt) & Notch Blind Spot Clearance

When you move your cursor over the notch, Morph smoothly expands into a spacious **580 × 240 pt** canvas designed specifically around the hardware notch geometry:

```
┌─────────────────┬───────────────────────┬───────────────────┐
│  Left Wing      │  NOTCH BLIND SPOT     │  Right Wing       │
│  (100% Visible) │  (EMPTY BLACK CUTOUT) │  (100% Visible)   │
│  MORPH / ← Home │  Zero text / features │  Tabs [●][●][●]   │
├─────────────────┴───────────────────────┴───────────────────┤
│                                                             │
│              MAIN FEATURE WORKSPACE                         │
│              (100% visible below the notch line)            │
│              • Home Launcher (3 Feature Cards)              │
│              • Pomodoro Focus Dial                          │
│              • YouTube Music Player Suite                   │
│              • Quick Scratchpad Notepad                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

- **Notch Blind Spot Clearance:** The top-center area (`185 × 34 pt`) is kept **completely empty and clear of any text, buttons, or features** so nothing is obscured behind your physical webcam notch.
- **Top Row Wings:**
  - **Left Wing:** `MORPH` brand pill or `← Home` return button.
  - **Right Wing:** Navigation tabs `[Home]` `[Focus]` `[Music]` `[Notes]`, Pin button, Collapse button.
- **Main Body:** Sits completely *below* the notch baseline, offering an unobstructed view across the full 580 pt width.

---

## ⚡ The Three Minimalist Features

1. **⏱️ Focus Timer (`[Focus]`):**
   - Elegant monochrome circular progress dial with crisp countdown (`25:00`).
   - Quick interval selectors (`25m`, `15m`, `5m`, `1m`) and mode toggle (`Work`, `Short Break`, `Long Break`).
   - Clean Start/Pause and Reset controls.

2. **🎵 YouTube Music & Media Player (`[Music]`):**
   - Minimalist album art and animated 3-bar live equalizer.
   - Track title, artist name, and source indicator (`YouTube Music • Chrome`).
   - Timeline scrubber with elapsed and remaining timestamps.
   - Volume slider with one-click mute.

3. **📝 Quick Scratchpad Notepad (`[Notes]`):**
   - Clean dark text editor canvas with auto-persistence to `UserDefaults` and disk backup.
   - One-click Copy All with clipboard confirmation.
   - Clear button with 2.5-second "Undo Clear" protection.
   - Live word and character micro-counter.

---

## ⌨️ Shortcuts & Controls

- **Hover over notch:** Expands into Home Launcher Dashboard
- **Toggle Expand/Collapse:** `⌘⌃M`
- **Pin / Unpin:** `⌘⌃P`
- **Copy Notes:** `⌘⌃C`
- **Quit Morph:** `⌘Q`

Programmatic toggle:
```bash
swift -e 'import Cocoa; DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("com.morph.toggleExpand"), object: nil, userInfo: nil, deliverImmediately: true)'
```
