# Morph

An autonomous Apple Dynamic Island workspace and Live Activity companion for macOS.

---

## Overview

Morph transforms the top region of your Mac into an autonomous, floating Dynamic Island. Floating downward with 14pt breathing clearance below the menu bar and notch, Morph rests silently without obstructing browser tabs, code editor splits, or application toolbars.

Morph operates across three distinct operational states:

1. **Normal Resting State:** Minimalist whisper-thin outline with transparent interior. Full click-through architecture (`ignoresMouseEvents = true`, `PassthroughHostingView.hitTest = nil`) allows clicking, dragging, and navigating underlying applications with zero interference.
2. **Extended Live Activity Pill:** When a background activity is active (Pomodoro countdown, YouTube Music playback, meeting in session, pinned notes, active file staging, or live form autofill), Morph elongates horizontally to display live status widgets while you work in other apps.
3. **Full Big UI (Fuller UI):** A 4-sided continuous squircle modal workspace (`640 × 225 pt`) expanding smoothly via a 0.38s spring animation upon deliberate hover dwell (`320ms`) or shortcut trigger.

---

## Universal Cross-Platform Intent Differentiation

Morph features an intent differentiation engine that distinguishes between navigating underlying applications and intentionally opening the Dynamic Island:

- **Universal Application Support:** Works universally across all macOS workspaces — Code Editors (VS Code, Xcode, JetBrains), Web Browsers (Chrome, Polar, Safari, Arc, Brave, Firefox, Edge), Terminals (iTerm, Terminal), and Productivity Suites (Figma, Slack, Notion, Pages, Finder).
- **Background Interaction Monitoring:** Global event monitors detect clicks (left, right, middle), drags, keystrokes, and trackpad scrolling in any underlying app, immediately cancelling pending hover expansion and enforcing a 450ms interaction cooldown buffer.
- **Velocity Gating:** Swift cursor movements across the island (`> 140 pt/s`) are recognized as traversal sweeps to tabs or window controls and will not trigger expansion.
- **Zero Bottom Protrusion:** When idle, Morph applies 0pt bottom padding to ensure tabs and toolbar controls directly below the pill remain 100% accessible.

---

## Core Features & Pages

- **Home — Ambient Intelligence Hub (`⌘1`):** Ambient status hub, daily glance, focus progress, and quick-launch launcher cards.
- **Focus Timer (`⌘2`):** Minimalist Pomodoro dial with live countdown Live Activity pill, custom intervals (`25m`, `15m`, `5m`, `1m`), and haptic phase notifications.
- **YouTube Music (`⌘3`):** WebKit-powered client with playlist browsing, artist exploration, live equalizer waveform Live Activity pill, volume slider, and background session persistence.
- **Scratchpad Notes (`⌘4`):** Distraction-free notepad with markdown checklist support, live word counter, clipboard export, and persistent notch wing pinning.
- **Calendar & Schedule (`⌘5`):** 7-column month grid, upcoming agenda countdown Live Activity pill, multi-calendar support, and 1-click Google Meet / FaceTime launcher.
- **Profile & Preferences (`⌘6`):** Apple ID account management, cloud sync status, battery & system health Live Activity pill, and theme customization.
- **Meeting Cockpit (`⌘7`):** Direct in-app meeting stage for Google Meet and Zoom with WebKit WebRTC capture, active call duration Live Activity pill, voice isolation, and tactile mic/video toggles.
- **Drop Shelf (`⌘8`):** AirDrop staging bay for drag-and-drop file organization, staged file count Live Activity pill, file type badges, and multi-file drag-out to external apps.
- **Application Form Tracker (`⌘9`):** Real-time form detection for Google Forms, Typeform, Workday, and 30+ ATS portals with DOM extraction, live question counter Live Activity pill, and automated keystroke streaming.
- **Quick Command Bar (`⌘K`):** Global Spotlight-style command palette to search, navigate tabs, toggle features, and trigger actions with arrow navigation.

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘⌥M` | Toggle Expand / Collapse Island |
| `⌘⌥P` | Pin / Unpin Island Open |
| `⌘K` | Quick Command Palette |
| `⌘1` – `⌘6` | Navigate to Home, Timer, Music, Notes, Calendar, Profile |
| `⌘⌥Space` or `⌘⏎` | Play / Pause Music |
| `⌘⌥T` or `⌘T` | Start / Pause Focus Timer |
| `⌘[` / `⌘]` | Previous Track / Next Track |
| `⌘⇧C` | Copy Scratchpad to Clipboard |
| `⌘⇧P` | Pin Note to Island Wing |
| `⌥Space` | Toggle In-Meeting Mic Mute |
| `⌘W` / `Esc` | Collapse Island / Back to Home |
| `⌘Q` | Quit Morph |

---

## Installation & Build

### Requirements
- macOS 14.0 (Sonoma) or newer
- Swift 6.0+ / Xcode 15+

### Build from Source

```bash
git clone https://github.com/aaronnguyen26/morph.git
cd morph
./scripts/build_app.sh --debug
```

The build script compiles the binary and installs `Morph.app` to `/Applications/Morph.app`.
