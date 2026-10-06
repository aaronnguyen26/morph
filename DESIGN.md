# Morph Design System & Guidelines (DESIGN.md)

## 1. Anti-Clutter & Visual Discipline
- **No Unnecessary Details**: Never add decorative dots, status pips, or trailing symbols next to user names (e.g., no dot next to "Aaron" or any user name).
- **No Unsolicited Telemetry on Home**: Do not put arbitrary metrics chips (e.g., "145m focus", "170m focus", "streak pips") on the Home screen.
- **No 'Ready' or Orange Status Indicators**: Media player must never display orange status indicators or 'Ready' badges. Keep all controls and status feedback strictly monochromatic.
- **Integrated Playlist & Queue Panel**: Media player must provide a dedicated, visible space for users to browse and scroll through their playlist/queue directly alongside the Now Playing controls.
- **Zen Simplicity**: The Home screen must remain pure and focused:
  1. Morphy cyber companion (floating center stage with soft ambient aura).
  2. Single-line dynamic greeting: `Good morning, <User>` (or `Good morning`).
  3. Action capsules: `Start 25m Focus`, `Play Music`, `Notes`.
  4. Nothing else.

## 2. Window Geometry & Proportions
- **Expanded Width**: `640 pt` (Restored full desktop width for balanced lateral wings).
- **Expanded Height (Length)**: `225 pt` (Shortened length, 3/4 of original 300 pt height for compact vertical footprint).
- **Hardware Notch Clearance**: Center blind spot of `179 pt × 32 pt` must always remain 100% unobstructed.
- **Corner Curvature**:
  - Outer window frame: Continuous squircle (`UnevenRoundedRectangle`, 28 pt radius).
  - Controls, tabs, buttons, chips: Continuous `Capsule()`.
  - Zero sharp 90° corners.

## 3. User Customization & Identity
- **User Profile Customization**:
  - The profile must be fully adjustable and customizable by the user directly within the UI.
  - Editable fields: First Name, Last Name, Email, Avatar Initials, and Status.
  - Edits must immediately persist to local cache and synchronize to the Supabase database.
- **Left Wing Profile Pill**:
  - Clean avatar circle with user initials + First Name only.
  - No trailing pips, dots, or clutter.
  - Clicking navigates seamlessly to the Profile customization screen.

## 4. Color Palette
- Strict monochromatic luxury: Obsidian blacks (`#08080a` to `#121215`), subtle glass translucency, silver, and crisp white typography.
- No saturated/neon colors.

## 5. macOS Standard Keyboard Shortcuts (Command / ⌘)
Morph adheres strictly to native macOS keyboard conventions so Mac users can operate with high-speed muscle memory:
- **Navigation & Views**:
  - `⌘1` / `⌘0`: Home View
  - `⌘2`: Focus / Pomodoro Timer
  - `⌘3`: Music Player
  - `⌘4`: Scratchpad Notes
  - `⌘5` / `⌘,`: Profile & Preferences
  - `⌘[`: Back / Return to Home
- **Window & Island Lifecycle**:
  - `⌘W`: Close / Collapse Notch Island to resting state
  - `⌘M`: Minimize to Notch
  - `⌘P`: Pin Island open (prevents auto-collapse on mouse exit)
  - `⌘R`: Refresh & Sync Profile with Supabase
  - `⌘H`: Hide / Collapse Island
  - `⌘Q`: Quit Morph
- **Playback & Audio**:
  - `⌘⏎` / `⌘⌥Space`: Play / Pause track
  - `⌘]` / `⌘→`: Next Track
  - `⌘[` / `⌘←`: Previous Track
  - `⌘↑` / `⌘↓`: Volume Up / Down (+/- 10%)
  - `⌘L`: Like / Favorite Track
  - `⌘U`: Toggle Mute / Unmute
- **Focus Timer**:
  - `⌘⏎` (or `⌘T`): Start / Pause Focus Timer
  - `⌘⇧R`: Reset Focus Timer
  - `⌘⇧S`: Skip session / break
- **Notes & Text Editing**:
  - `⌘N`: New Note / Clear Scratchpad
  - `⌘S`: Save Note
  - `⌘⇧C`: Copy entire note to system clipboard
  - `⌘⇧P`: Pin note preview to collapsed notch HUD
  - Standard responder commands: `⌘A` (Select All), `⌘C` (Copy), `⌘X` (Cut), `⌘V` (Paste), `⌘Z` (Undo), `⌘⇧Z` (Redo)
- **Global Hotkeys (System-Wide)**:
  - `⌘⌥M`: Expand / Collapse Morph Island from any macOS application
  - `⌘⌥P`: Toggle Pin from anywhere
  - `⌘⌥Space`: Play / Pause music from anywhere

