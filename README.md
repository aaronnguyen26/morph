# Morph

A pure OLED-black Dynamic Island utility anchored directly to the MacBook hardware notch.

---

## Overview

Morph transforms the physical notch area into an unobtrusive, multi-functional workspace. When idle, Morph rests flush inside the camera notch. Hovering or triggering a shortcut expands the canvas into a unified productivity hub with complete clearance for the hardware webcam cutout.

### Core Features

- **Focus Timer (`⌘2`):** Minimalist Pomodoro dial with custom work/break intervals (`25m`, `15m`, `5m`, `1m`) and live progress indicator.
- **YouTube Music (`⌘3`):** WebKit-powered client with full playlist browsing, artist exploration, top-song playback, volume control, and background session persistence.
- **Scratchpad Notes (`⌘4`):** Persistent distraction-free notepad with live word count, instant clipboard copy, and notch pinning.
- **Google Calendar (`⌘6`):** Dual-deck calendar with 7-column month grid, upcoming meeting notifications with direct Google Meet links, multi-calendar support, quick event creation, and tab-reusing browser sync.
- **Profile & Sync (`⌘5`):** Account profile management with cloud session persistence and automated multi-service authentication.

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘⌥M` | Toggle Expand / Collapse |
| `⌘⌥P` | Pin / Unpin Island |
| `⌘⌥Space` or `⌘⏎` | Play / Pause Music |
| `⌘⌥T` or `⌘T` | Start / Pause Focus Timer |
| `⌘1` – `⌘6` | Navigate to Home, Timer, Music, Notes, Profile, Calendar |
| `⌘[` / `⌘]` | Previous Track / Next Track |
| `⌘⇧C` | Copy Scratchpad to Clipboard |
| `⌘⇧P` | Pin Note to Notch Wing |
| `⌘W` / `Esc` | Collapse Island / Back to Home |
| `⌘Q` | Quit Morph |

---

## Installation & Build

### Requirements
- macOS 14.0 (Sonoma) or newer
- MacBook with camera notch (also supports non-notch displays via virtual anchor)
- Swift 6.0+ / Xcode 15+

### Build from Source

```bash
git clone https://github.com/AaronNguyen22/morph.git
cd morph
./scripts/build_app.sh
```

The script compiles the release binary and installs `Morph.app` to `/Applications/Morph.app`.
