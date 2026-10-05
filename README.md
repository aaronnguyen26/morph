# Morph 🛸

A modern native macOS Dynamic Island application that sits directly in the notch of your MacBook.

When idle, **Morph** stays seamlessly nestled inside the notch area. When you hover your cursor over the notch, it smoothly expands into an interactive bigger screen using native fluid spring physics.

---

## ✨ Features

- **Hardware Notch Alignment**: Automatically detects the MacBook Pro / MacBook Air hardware notch (`NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`), calibrating exact width (`179 pt`) and height (`32 pt`).
- **Fluid Spring Physics**: Apple-grade continuous curvature corners and spring transitions (`response: 0.38s, dampingFraction: 0.78`).
- **Zero-Latency Hover Detection**:
  - Global and local mouse monitoring tracks cursor movement across all applications.
  - Generous hit area and 0.25s grace period to prevent flickering.
- **Interactive Expanded Screen**:
  - Live status indicator (Active / Pinned).
  - Hardware display specs (`179 × 32 pt` calibrated notch).
  - Accent Theme switcher (Cyan, Violet, Emerald, Amber, Silver) with real-time ambient glow.
  - Interactive "Trigger Pulse Effect" test button.
  - Pin button to keep the screen expanded while inspecting.
- **macOS Menu Bar Extra**:
  - Sparkle icon in the system menu bar.
  - Shortcuts: Toggle Expand (`⌘⌃M`), Pin (`⌘⌃P`), Quit (`⌘Q`).
  - Allows full control even when cursor is elsewhere.

---

## 🚀 How to Run

### Run the App
`Morph.app` is already built and ready in the project root:
```bash
open Morph.app
```

### Rebuild from Source
To rebuild `Morph.app`:
```bash
./scripts/build_app.sh
```

Or run via Swift CLI:
```bash
swift run morph
```

### Quit the App
- Press `⌘Q` in the Morph menu bar item (sparkle icon), or run:
```bash
killall morph
```

---

## 🛠️ Architecture

- [`Sources/morph/main.swift`](file:///Users/minhnguyen/Desktop/Coding/morph/Sources/morph/main.swift): Application entry point configured with `.accessory` activation policy.
- [`Sources/morph/NotchModel.swift`](file:///Users/minhnguyen/Desktop/Coding/morph/Sources/morph/NotchModel.swift): Observable state for notch geometry, hover state, pinning, and accent themes.
- [`Sources/morph/NotchPanel.swift`](file:///Users/minhnguyen/Desktop/Coding/morph/Sources/morph/NotchPanel.swift): Transparent, borderless `NSPanel` floating at `.statusBar` level across all spaces.
- [`Sources/morph/MorphController.swift`](file:///Users/minhnguyen/Desktop/Coding/morph/Sources/morph/MorphController.swift): Manages mouse tracking, window resizing, and spring transition coordination.
- [`Sources/morph/MorphIslandView.swift`](file:///Users/minhnguyen/Desktop/Coding/morph/Sources/morph/MorphIslandView.swift): SwiftUI view rendering both the collapsed notch and expanded bigger screen.
- [`Sources/morph/MenuBarManager.swift`](file:///Users/minhnguyen/Desktop/Coding/morph/Sources/morph/MenuBarManager.swift): System status bar menu extra for quick control and shortcuts.
