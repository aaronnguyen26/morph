# Morph 🛸

**Module:** Everyday Productivity & Browsing  
**Scope:** Three-Feature Minimalist Suite (Pomodoro Focus Timer, YouTube Music Player, Quick Scratchpad Notepad) with Home Launcher Dashboard

Morph is an ultra-sleek, native macOS Dynamic Island utility anchored directly to the physical MacBook notch baseline.

---

## 🥷 100% Flush Resting State (Never Sticks Out)

When resting or idle, Morph **never sticks out**:
- It sits completely flush and invisible inside the hardware notch (`179 × 32 pt`).
- Pitch-black background blends seamlessly with the hardware camera bezel.
- Zero wings or protruding elements when idle, leaving your full screen and menu bar completely unobstructed.

---

## 🚀 Hover to Expand: Home Launcher Dashboard

When you move your cursor over the notch of your computer, Morph smoothly springs outward into an ergonomic **460 × 175 pt** island.

Instead of locking you into a single tool, Morph opens to an interactive **Home Launcher Dashboard** showcasing all 3 productivity features:

### 1. ⏱️ Focus Timer Card
- **Live Preview:** Displays current timer mode and countdown (`25:00`).
- **Quick Controls:** Direct inline **Start / Pause** button.
- **Deep Workspace:** Click the card or `Open →` to enter the full Pomodoro workspace (circular draining dial, 25m/15m/5m/1m presets, mode toggle, session count).

### 2. 🎵 YouTube Music Card
- **Live Preview:** Displays track title, artist name, and a live animated 3-bar equalizer.
- **Quick Controls:** Direct inline **Play / Pause** toggle.
- **Deep Workspace:** Click the card or `Open →` to enter the full media suite (track scrubber, volume slider with instant mute, track skip controls, and automatic Google Chrome & Safari tab sync).

### 3. 📝 Scratchpad Card
- **Live Preview:** Shows a preview snippet of your notes and current word count.
- **Quick Controls:** Direct inline **Copy** button.
- **Deep Workspace:** Click the card or `Open →` to enter the full notepad editor (multi-line instant text editor, Copy All, Clear with 2.5s Undo, character/word counters, and auto-persistence to disk).

---

## 🧭 Fluid Navigation

- **Return to Home:** When inside any feature workspace, click the `← Home` button in the top left to return to the Home dashboard anytime.
- **Top Tab Bar:** Jump directly between `[Home]`, `[Focus]`, `[Music]`, and `[Notes]`.
- **Pin Island:** Click the `Pin` button in the top right to keep the island open while taking notes or reading.
- **Smooth Collapse:** Move your cursor away from the island and it smoothly collapses back into the flush hardware notch.

---

## ⌨️ Shortcuts & Controls

- **Hover over the notch:** Expands into Home Dashboard
- **Toggle Expand/Collapse:** `⌘⌃M`
- **Pin / Unpin:** `⌘⌃P`
- **Copy Notes:** `⌘⌃C`
- **Quit Morph:** `⌘Q`

Programmatic scripting:
```bash
# Toggle Expand
swift -e 'import Cocoa; DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("com.morph.toggleExpand"), object: nil, userInfo: nil, deliverImmediately: true)'

# Toggle Pin
swift -e 'import Cocoa; DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("com.morph.togglePin"), object: nil, userInfo: nil, deliverImmediately: true)'
```
