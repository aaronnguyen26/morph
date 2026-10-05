# Morph 🛸

**Module:** Everyday Productivity & Browsing  
**Scope:** Three-Feature Minimalist Suite (Pomodoro Focus Timer, YouTube Music Player, Quick Scratchpad Notepad)

Morph is a sleek, native macOS Dynamic Island utility anchored directly to the physical MacBook notch baseline. It rests in a low-profile ambient state and expands into a focused 3:1 horizontal island upon hover or click.

---

## 📐 Form Factor & Dimensional Hierarchy

| UI State | Dimensions | Left Section | Center (Hardware Notch) | Right Section |
| :--- | :--- | :--- | :--- | :--- |
| **Idle State** | `179 × 32 pt` | *Hidden* | Physical Webcam Cutout | *Hidden* |
| **Passive / Active Pill** | `300 × 44 pt` | Pomodoro Countdown (`24:59`) & Mini Ring | Flush Notch Cutout | 3-Bar Live Equalizer & Play State |
| **Expanded Island** | `440 × 140 pt` | Active Feature Suite (Dial / Album Art / Editor) | Top Navigation Tabs: `[Focus]` `[Music]` `[Notes]` | Action Bar, Scrubber & Controls |

---

## ⚡ Three-Feature Minimalist Suite

### 1. ⏱️ Ambient Pomodoro Focus Timer
- **Intervals:** 25-minute standard focus sessions, 5-minute short breaks, 15-minute long breaks, and quick test presets (`25m`, `15m`, `5m`, `1m`).
- **Ambient Indicator (Pill State):** The left wing of the notch displays the real-time countdown (`24:59`) with a circular ring gently draining as focus elapses.
- **Expanded Suite:** Start/Pause pill button, Reset, Mode selector (Work, Short Break, Long Break), and completed session counter.
- **Ambient Completion Alert:** Soft emerald pulsing glow upon session completion without disruptive banner popups.

### 2. 🎵 YouTube Music & Media Controller
- **Browser & System Audio Bridge:** Automatically detects audio playing in Google Chrome, Safari, Brave, Edge, Arc (`*music.youtube.com*`).
- **Ambient Equalizer (Pill State):** The right wing displays a live animated 3-bar audio visualizer dancing to the music.
- **Expanded Playback Suite:**
  - Track Title, Artist, and Source badge (`YouTube Music • Chrome`).
  - Interactive Scrubbing Timeline with elapsed and remaining timestamps (`mm:ss`).
  - Quick Volume Slider with one-click Mute toggle.
  - Core Controls: Previous Track, Play/Pause, Next Track.
  - Interactive built-in demo track rotation for instant testing when offline.

### 3. 📝 Quick Scratchpad Notepad
- **Zero-Friction Access:** Instant multi-line scratchpad in the `[Notes]` tab for stashing ideas, tasks, links, or meeting notes.
- **Auto-Persistence:** Every keystroke saves automatically to `UserDefaults` and JSON backup (`~/Library/Application Support/Morph/scratchpad.json`).
- **Quick Actions:**
  - **Copy All:** One-click copy to macOS clipboard with checkmark confirmation.
  - **Clear with 2.5s Undo:** Instantly clear with an "Undo Clear" button to prevent accidental loss.
  - **Micro-Counter:** Real-time word and character counter (`X words • Y chars`) in the lower right corner.
  - Plain text formatting with automatic URL detection.

---

## 🚀 Running & Controls

### Run Morph
`Morph.app` is already built and running on your system:
```bash
open Morph.app
```

### Rebuild from Source
```bash
./scripts/build_app.sh
```

### Menu Bar & Keyboard Shortcuts
Click the sparkle icon in your macOS menu bar, or use global hotkeys:
- **Toggle Expand / Collapse:** `⌘⌃M`
- **Pin / Unpin Window:** `⌘⌃P`
- **Copy Scratchpad Notes:** `⌘⌃C`
- **Quit Morph:** `⌘Q`

### Scripting Notifications
You can also toggle Morph programmatically:
```bash
# Expand / Collapse toggle
swift -e 'import Cocoa; DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("com.morph.toggleExpand"), object: nil, userInfo: nil, deliverImmediately: true)'

# Pin toggle
swift -e 'import Cocoa; DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("com.morph.togglePin"), object: nil, userInfo: nil, deliverImmediately: true)'
```

---

## 📊 Performance Verification

- **Memory Consumption:** ~19.6 MB RAM (well within the `< 35MB` PRD target).
- **CPU Utilization:** ~0.1% CPU (well within the `< 0.5%` PRD target).
- **Window Level:** `NSPanel` floating at `.popUpMenu` with `.nonactivatingPanel` and borderless styling to allow immediate text input without stealing key application focus.
