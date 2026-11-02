#!/usr/bin/env python3
import os
import base64

BASE_DIR = "/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd"
OUTPUT_HTML = os.path.join(BASE_DIR, "apple_dynamic_island_spotlight_exploration.html")

def get_b64(rel_path):
    full_path = os.path.join(BASE_DIR, rel_path)
    if not os.path.exists(full_path):
        raise FileNotFoundError(f"Missing file: {full_path}")
    with open(full_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")

print("Encoding assets to Base64...")
b64_baseline = get_b64(".user_uploaded/media_1793503484465_1afb309d.png")
b64_user_screenshot_2 = get_b64(".user_uploaded/media_1793507120129_01d91230.png")
b64_home_redesign = get_b64("morph_realistic_home_redesign.png")
b64_spotlight_flow = get_b64("morph_spotlight_island_flow.png")
b64_mascot_showcase = get_b64("morphy_mascot_showcase.png")

pages = [
    {
        "id": "page-01",
        "tab": "Home",
        "title": "Page 01 Home — Morphy Mascot & Launch Cockpit",
        "file": "realistic_page_01_home.png",
        "state2": "Resting Dynamic Capsule (210 x 36 pt) with gentle whisper breathing and ambient time telemetry. 100% click-through in idle state.",
        "state3": "Compact Home Cockpit (640 x 225 pt) featuring the animated Morphy Mascot centerpiece, morning/evening greeting, calendar glance, and quick launch triggers.",
        "features": [
            "Morphy Mascot interactive centerpiece with ambient gaze tracking",
            "Calendar Glance with today's meeting count and next scheduled event",
            "Quick Launch Cockpit for Focus Session, Music, and Scratchpad",
            "User Profile Header with active workspace indicator",
            "Hardware Notch Clearance and tactile ESC dismissal rail"
        ]
    },
    {
        "id": "page-02",
        "tab": "Focus Timer",
        "title": "Page 02 Focus Timer — Circular Pomodoro Sprint Deck",
        "file": "realistic_page_02_timer.png",
        "state2": "Active Sprint Pill (480 x 36 pt) displaying live countdown (23:45 remaining), sprint progress ring, and Morphy in focus visor mode.",
        "state3": "Expanded Focus Control Center (640 x 225 pt) with large 25-minute circular timer gauge, quick interval presets (15m, 25m, 45m, 60m), and session telemetry.",
        "features": [
            "High-contrast circular countdown gauge with remaining time display",
            "Preset sprint duration selector (15m, 25m, 45m, 60m)",
            "Morphy Mascot in dedicated Focus Visor & Studio Headphones mode",
            "Phase 1 Deep Work session tracking with daily cycle statistics",
            "Spacebar play/pause and ⌘R quick reset keyboard bindings"
        ]
    },
    {
        "id": "page-03",
        "tab": "Music",
        "title": "Page 03 Music — Spatial Audio Equalizer & Stream Deck",
        "file": "realistic_page_03_music.png",
        "state2": "Now Playing Waveform Pill (510 x 36 pt) showing track name, artist, and animated real-time audio visualizer bars.",
        "state3": "Expanded Music Player (640 x 225 pt) with album art vignette, scrubbing timeline, transport controls, and volume level slider.",
        "features": [
            "Now Playing track metadata (Midnight City by M83, Hurry Up We're Dreaming)",
            "Precision audio scrubbing bar with elapsed and remaining timestamps",
            "Tactile transport controls (Previous, Play/Pause, Next) with keyboard shortcuts",
            "Spatial Audio and Lossless Audio high-fidelity indicators",
            "Volume slider and quick source switcher (YouTube Music, Spotify, Apple Music)"
        ]
    },
    {
        "id": "page-04",
        "tab": "Notes",
        "title": "Page 04 Notes — Quick Markdown Scratchpad & Buffer",
        "file": "realistic_page_04_notes.png",
        "state2": "Active Draft Pill (420 x 36 pt) indicating active document title and word count buffer.",
        "state3": "Expanded Scratchpad (640 x 225 pt) featuring a distraction-free markdown editor, instant clipboard sync, and recent snippet drawer.",
        "features": [
            "Distraction-free monospaced markdown scratchpad with live syntax highlighting",
            "Word and character telemetry with auto-save status indicator",
            "Quick copy to clipboard with ⌘C and instant export to Apple Notes",
            "Recent snippets drawer for one-click access to pinned thoughts",
            "Clean Apple squircle input container with zero toolbar clutter"
        ]
    },
    {
        "id": "page-05",
        "tab": "Calendar",
        "title": "Page 05 Calendar — Smart Agenda & FaceTime Integration",
        "file": "realistic_page_05_calendar.png",
        "state2": "Upcoming Event Pill (460 x 36 pt) showing countdown to next meeting with one-click Join button.",
        "state3": "Full Daily Agenda (640 x 225 pt) showing chronology of today's schedule, meeting URLs, participants, and room locations.",
        "features": [
            "Chronological agenda list of all meetings scheduled for today",
            "Direct 'Join Call' primary action pill for active or imminent events",
            "Organizer and attendee avatar stack with meeting room details",
            "Daily meeting count summary and free-time buffer analysis",
            "Sync with Apple Calendar, Google Calendar, and Outlook"
        ]
    },
    {
        "id": "page-06",
        "tab": "Profile",
        "title": "Page 06 Profile — Apple ID & System Preferences (Screenshot 2 Redesign)",
        "file": "realistic_page_06_profile.png",
        "state2": "Identity Pill (380 x 36 pt) displaying user avatar, name, and iCloud sync status.",
        "state3": "Compact Profile & Settings Console (640 x 225 pt) redesigning the previously oversized window into the exact compact Morph footprint.",
        "features": [
            "User avatar (MN), full name (Minh Nguyen), role, and verified email",
            "Focus momentum metrics: 2,480m Focus Time, 14 Days Streak, 42 Sessions",
            "Apple Continuity & Handoff status with connected MacBook Pro and iPhone",
            "Appearance Mode toggle (Obsidian Dark Substrate with Titanium Glint)",
            "Dynamic Island Pinning toggle and Haptic Touch tactile feedback configuration"
        ]
    },
    {
        "id": "page-07",
        "tab": "Meeting",
        "title": "Page 07 Meeting Cockpit — Active Call & Media Controls",
        "file": "realistic_page_07_meeting.png",
        "state2": "Active Call Pill (440 x 36 pt) with call duration timer, live audio waveform, and quick mute toggle.",
        "state3": "Expanded Meeting Cockpit (640 x 225 pt) with multi-mic gain control, camera preview toggle, screen share trigger, and end call button.",
        "features": [
            "Live call telemetry: duration timer, active speaker indicator, and network latency",
            "Prominent Microphone Mute / Unmute toggle with keyboard shortcut (⌘⇧M)",
            "Camera video stream toggle with privacy shutter indicator",
            "Screen share selector for individual windows or full display",
            "Instant one-click End Call emergency action button"
        ]
    },
    {
        "id": "page-08",
        "tab": "Drop Shelf",
        "title": "Page 08 Drop Shelf — Staged Files & AirDrop Transfer Target",
        "file": "realistic_page_08_dropshelf.png",
        "state2": "Holding Shelf Pill (400 x 36 pt) showing count of staged files with drag-out readiness.",
        "state3": "Expanded Drop Shelf (640 x 225 pt) providing temporary file staging cards, batch file actions, and instant AirDrop sharing.",
        "features": [
            "Visual preview thumbnails of staged files (PDFs, images, archives)",
            "File metadata: file name, byte size, format, and staging timestamp",
            "Drag-and-drop target zone supporting simultaneous multi-file drops",
            "AirDrop sharing trigger to dispatch staged files to nearby Apple devices",
            "Batch actions: Copy All Paths, Reveal in Finder, and Clear Shelf"
        ]
    },
    {
        "id": "page-09",
        "tab": "Form Intake",
        "title": "Page 09 Form Tracker — Application Intake & Keychain Autofill",
        "file": "realistic_page_09_form.png",
        "state2": "Intake Progress Pill (430 x 36 pt) indicating active questionnaire step and completion percentage.",
        "state3": "Expanded Form Intake Console (640 x 225 pt) with multi-step progress bar, question prompt, option cards, and Keychain autofill.",
        "features": [
            "Multi-step progress tracker (Question 1 of 4, 25% complete)",
            "Active question prompt with clean, accessible typography",
            "Selectable choice cards with visual radio indicators and keyboard navigation",
            "Apple Keychain 1-click Autofill integration for identity and contact fields",
            "Keyboard shortcuts: ⌥Space to autofill, Enter to advance to next step"
        ]
    },
    {
        "id": "page-10",
        "tab": "Compact Notch HUD",
        "title": "Page 10 Compact Notch HUD — Concurrent Background Activity Pills",
        "file": "realistic_page_10_compact.png",
        "state2": "Multi-Activity Dual Capsule HUD showcasing simultaneous background operations hugging the MacBook display notch.",
        "state3": "Comparison Matrix (640 x 225 pt) illustrating the three background HUD configurations: Dual Bubble, Call + Shelf, and Stealth Capsule.",
        "features": [
            "Dual-Activity concurrent pill: Music playback on left + Focus timer on right",
            "FaceTime + Drop Shelf split pill for active communication and file workflows",
            "Resting Stealth Capsule with ultra-subtle whisper hairline and zero text",
            "100% click-through guarantee in resting state preventing browser tab blocking",
            "Zero occlusion geometry engineered specifically for MacBook notch clearance"
        ]
    }
]

for p in pages:
    p["b64"] = get_b64(p["file"])
    print(f"Encoded {p['file']}")

print("All assets successfully encoded to Base64.")

# Build HTML content
html_parts = []
html_parts.append("""<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Morph — Apple Dynamic Island Spotlight & Mascot Architecture</title>
  <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
  <style>
    @keyframes float-breath {
      0%, 100% { transform: translateY(0px) scale(1.0); }
      50% { transform: translateY(-4px) scale(1.02); }
    }
    @keyframes blink {
      0%, 90%, 100% { transform: scaleY(1); }
      95% { transform: scaleY(0.1); }
    }
    @keyframes pulse-ring {
      0%, 100% { opacity: 0.15; transform: scale(1.0); }
      50% { opacity: 0.35; transform: scale(1.06); }
    }
    .mascot-float {
      animation: float-breath 3.6s ease-in-out infinite;
    }
    .mascot-eye {
      animation: blink 4.2s infinite;
      transform-origin: center;
    }
    .specular-rim {
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.22), 0 20px 40px -10px rgba(0, 0, 0, 0.85);
    }
    .island-spring {
      transition: all 0.38s cubic-bezier(0.16, 1, 0.3, 1);
    }
    .tab-active {
      background-color: #FFFFFF !important;
      color: #000000 !important;
      font-weight: 600 !important;
    }
  </style>
</head>
<body class="bg-[#0A0A0C] text-[#E5E5E7] antialiased selection:bg-white/20 p-4 md:p-8 font-sans min-h-screen">

  <!-- Main Container -->
  <div class="max-w-6xl mx-auto space-y-12">

    <!-- Top Hero Header -->
    <header class="border-b border-white/10 pb-6 flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div>
        <div class="flex items-center space-x-2 text-xs font-mono tracking-widest text-[#8E8E93] uppercase">
          <span> Apple Dynamic Island Paradigm</span>
          <span>|</span>
          <span>Workspace Architecture v4.5</span>
        </div>
        <h1 class="text-2xl md:text-3xl font-semibold tracking-tight text-white mt-1">
          Spotlight Island Search & Morphy Mascot Redesign
        </h1>
        <p class="text-sm text-[#8E8E93] mt-1 max-w-3xl">
          An interactive architecture exploring realistic compact geometry (<span class="text-white font-mono">640 × 225 pt</span>), an expressive Apple companion mascot, and the paradigm shift from static tab pages to unified Spotlight in-pill search.
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <span class="px-3 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs font-mono text-[#8E8E93]">
          100% Neutral Monochrome
        </span>
        <span class="px-3 py-1.5 rounded-full bg-white/10 border border-white/20 text-xs font-mono text-white">
          Exact 640×225 Scale
        </span>
        <span class="px-3 py-1.5 rounded-full bg-white/10 border border-white/20 text-xs font-mono text-white">
          Self-Contained Base64
        </span>
      </div>
    </header>

    <!-- Quick Navigation Bar -->
    <nav class="sticky top-4 z-40 bg-[#121215]/90 backdrop-blur-xl border border-white/15 rounded-xl p-2.5 flex items-center justify-between overflow-x-auto gap-2 shadow-2xl">
      <div class="flex items-center space-x-1.5 text-xs font-mono">
        <a href="#simulator" class="px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-white transition-all">1. Spotlight Simulator</a>
        <a href="#mascot" class="px-3 py-1.5 rounded-lg hover:bg-white/10 text-[#8E8E93] hover:text-white transition-all">2. Morphy Mascot</a>
        <a href="#scale-validation" class="px-3 py-1.5 rounded-lg hover:bg-white/10 text-[#8E8E93] hover:text-white transition-all">3. Scale Baseline</a>
        <a href="#screenshot2-fix" class="px-3 py-1.5 rounded-lg hover:bg-white/10 text-[#8E8E93] hover:text-white transition-all">4. Screenshot 2 Fix</a>
        <a href="#realistic-suite" class="px-3 py-1.5 rounded-lg hover:bg-white/10 text-[#8E8E93] hover:text-white transition-all">5. 10 Realistic Pages</a>
        <a href="#master-boards" class="px-3 py-1.5 rounded-lg hover:bg-white/10 text-[#8E8E93] hover:text-white transition-all">6. Master Boards</a>
      </div>
      <span class="text-[11px] font-mono text-[#8E8E93] px-2 hidden lg:inline">
        Zero Broken Images | Pure Monochrome
      </span>
    </nav>
""")

# Section 1: Spotlight Search Simulator
html_parts.append(f"""
    <!-- SECTION 1: INTERACTIVE SPOTLIGHT SEARCH SIMULATOR -->
    <section id="simulator" class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl relative overflow-hidden">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-2 mb-6">
        <div>
          <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">Concept Exploration 01</span>
          <h2 class="text-xl font-semibold text-white tracking-tight">The Spotlight Island Search Flow</h2>
          <p class="text-xs text-[#8E8E93] mt-0.5">
            Hover lengthens the island into a search bar. Type a tool name (e.g. "music", "profile", "timer") or select a quick pill below to bloom directly into that realistic page view.
          </p>
        </div>
        <div class="flex items-center space-x-2">
          <button id="btn-state-1" onclick="setSimState(1)" class="px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white text-black font-medium">1. Resting (210×36)</button>
          <button id="btn-state-2" onclick="setSimState(2)" class="px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white/5 hover:bg-white/10 text-[#8E8E93]">2. Lengthened Search</button>
          <button id="btn-state-3" onclick="setSimState(3)" class="px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white/5 hover:bg-white/10 text-[#8E8E93]">3. Big UI (640×225)</button>
        </div>
      </div>

      <!-- Simulated MacBook Desktop Viewport -->
      <div class="w-full bg-[#050507] border border-white/10 rounded-xl relative overflow-hidden min-h-[480px] flex flex-col items-center">
        <!-- macOS Menu Bar -->
        <div class="w-full h-8 bg-black/60 backdrop-blur-xl border-b border-white/5 px-4 flex items-center justify-between text-xs text-[#8E8E93]">
          <div class="flex items-center space-x-4">
            <span class="text-white text-sm font-semibold cursor-default"></span>
            <span class="text-white font-medium">Workspace</span>
            <span class="hidden sm:inline">File</span>
            <span class="hidden sm:inline">Edit</span>
            <span class="hidden sm:inline">View</span>
            <span class="hidden sm:inline">Window</span>
          </div>
          <div class="flex items-center space-x-3 text-[11px] font-mono">
            <span>Wi-Fi</span>
            <span>Battery 98%</span>
            <span>Sat Oct 31 10:42 PM</span>
          </div>
        </div>

        <!-- Simulated Browser Tab Bar Directly Below Menu Bar (Proving Zero Occlusion) -->
        <div class="w-full h-9 bg-[#111114] border-b border-white/5 px-4 flex items-center space-x-2 text-xs">
          <div class="flex items-center space-x-2 px-3 py-1 rounded-t-lg bg-[#1C1C1E] text-white border-t border-x border-white/10">
            <span class="text-[10px] text-[#8E8E93]">⌘1</span>
            <span class="font-medium">GitHub — morph-agent</span>
            <span class="text-[10px] text-[#8E8E93] hover:text-white cursor-pointer ml-1">×</span>
          </div>
          <div class="flex items-center space-x-2 px-3 py-1 rounded-t-lg text-[#8E8E93] hover:bg-white/5 cursor-pointer">
            <span class="text-[10px]">⌘2</span>
            <span>Apple Developer Documentation</span>
          </div>
          <div class="flex items-center space-x-2 px-3 py-1 rounded-t-lg text-[#8E8E93] hover:bg-white/5 cursor-pointer">
            <span class="text-[10px]">⌘3</span>
            <span>Linear — Dynamic Island Sprint</span>
          </div>
        </div>

        <!-- Hardware Notch Housing -->
        <div class="w-44 h-7 bg-black rounded-b-2xl border-b border-x border-white/10 flex items-center justify-center space-x-3 z-30 shadow-2xl">
          <div class="w-2.5 h-2.5 rounded-full bg-[#111] border border-white/20"></div>
          <div class="w-1.5 h-1.5 rounded-full bg-[#050505] border border-white/10"></div>
        </div>

        <!-- THE DYNAMIC ISLAND SIMULATION -->
        <div id="island-hud" class="island-spring mt-2 bg-black rounded-[24px] border border-white/20 specular-rim z-20 flex flex-col items-center justify-center overflow-hidden cursor-pointer shadow-[0_25px_60px_-15px_rgba(0,0,0,0.9)]" style="width: 210px; height: 36px;">

          <!-- CONTENT FOR STATE 1: RESTING PILL (210 x 36) -->
          <div id="content-state-1" class="w-full h-full px-3 flex items-center justify-between text-xs font-mono">
            <div class="flex items-center space-x-2">
              <div class="w-2 h-2 rounded-full bg-white animate-pulse"></div>
              <span class="text-white text-[11px] font-semibold tracking-wide">MORPH</span>
            </div>
            <div class="flex items-center space-x-1.5 text-[10px] text-[#8E8E93]">
              <span class="px-1.5 py-0.5 rounded bg-white/10 text-white font-mono">⌘K</span>
            </div>
          </div>

          <!-- CONTENT FOR STATE 2: LENGTHENED SEARCH PILL (540 x 40) -->
          <div id="content-state-2" class="hidden w-full h-full px-3 flex items-center justify-between space-x-3">
            <div class="flex items-center space-x-2 text-white">
              <span class="text-sm">🔍</span>
              <input id="search-input" type="text" placeholder="Search commands, music, notes, timer, profile..." oninput="onSearchChange(this.value)" class="bg-transparent text-xs text-white placeholder-[#8E8E93] focus:outline-none w-56 font-mono" />
            </div>
            <div class="flex items-center space-x-1.5">
              <button onclick="openContextUI('music')" class="px-2 py-0.5 rounded-full bg-white/10 hover:bg-white/20 text-[10px] font-mono text-[#8E8E93] hover:text-white transition-all">♫ Music</button>
              <button onclick="openContextUI('timer')" class="px-2 py-0.5 rounded-full bg-white/10 hover:bg-white/20 text-[10px] font-mono text-[#8E8E93] hover:text-white transition-all">◷ Timer</button>
              <button onclick="openContextUI('notes')" class="px-2 py-0.5 rounded-full bg-white/10 hover:bg-white/20 text-[10px] font-mono text-[#8E8E93] hover:text-white transition-all">✎ Notes</button>
              <button onclick="openContextUI('profile')" class="px-2 py-0.5 rounded-full bg-white/10 hover:bg-white/20 text-[10px] font-mono text-white border border-white/20 transition-all">👤 Profile</button>
            </div>
          </div>

          <!-- CONTENT FOR STATE 3: EXPANDED BIG UI (640 x 225) -->
          <div id="content-state-3" class="hidden w-full h-full flex flex-col justify-between p-3.5 bg-black">
            <!-- Simulated Big UI Image Preview matching active selection -->
            <div id="sim-big-ui-viewport" class="w-full h-full rounded-xl overflow-hidden relative border border-white/10">
              <img id="sim-big-ui-img" src="data:image/png;base64,{pages[0]['b64']}" alt="Simulated Big UI" class="w-full h-full object-cover">
              
              <!-- Dismiss Overlay Rail -->
              <div class="absolute bottom-1.5 inset-x-3 flex items-center justify-between text-[10px] font-mono text-[#8E8E93] bg-black/80 backdrop-blur-md px-3 py-1 rounded-lg border border-white/10">
                <span id="sim-profile-status">ACTIVE VIEW: Home Dashboard</span>
                <span class="text-white">Press ESC or Click Outside to Collapse</span>
              </div>
            </div>
          </div>

        </div>

        <div class="absolute bottom-4 inset-x-0 flex justify-center pointer-events-none">
          <div class="px-4 py-1.5 rounded-full bg-white/5 border border-white/10 text-[11px] font-mono text-[#8E8E93] backdrop-blur-md">
            Click states above or use search bar to bloom into tools
          </div>
        </div>
      </div>
    </section>
""")

# Section 2: Morphy Mascot Identity
html_parts.append("""
    <!-- SECTION 2: THE MORPHY MASCOT ARCHITECTURE -->
    <section id="mascot" class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl space-y-6">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-2 border-b border-white/10 pb-4">
        <div>
          <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">Visual Identity</span>
          <h2 class="text-xl font-semibold text-white tracking-tight">Meet Morphy: The Ambient Workspace Companion</h2>
          <p class="text-xs text-[#8E8E93] mt-0.5">
            Replacing the legacy static circle and 3-dot cluster with an expressive, living Apple-crafted droplet companion.
          </p>
        </div>
        <span class="text-xs font-mono text-white bg-white/10 px-3 py-1 rounded-full border border-white/20">
          Pure Titanium & Obsidian Glass
        </span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <!-- Mascot 1: Ambient Welcome -->
        <div class="bg-black/60 border border-white/10 rounded-xl p-5 flex flex-col items-center text-center space-y-4">
          <div class="mascot-float w-28 h-28 relative flex items-center justify-center">
            <svg viewBox="0 0 100 100" class="w-full h-full drop-shadow-[0_12px_24px_rgba(255,255,255,0.12)]">
              <rect x="12" y="12" width="76" height="76" rx="28" fill="#18181A" stroke="#FFFFFF" stroke-width="2.5" stroke-opacity="0.4"/>
              <ellipse cx="50" cy="24" rx="24" ry="8" fill="#FFFFFF" fill-opacity="0.14"/>
              <g class="mascot-eye">
                <rect x="32" y="42" width="9" height="16" rx="4.5" fill="#FFFFFF"/>
                <circle cx="36" cy="46" r="2.5" fill="#18181A"/>
                <rect x="59" y="42" width="9" height="16" rx="4.5" fill="#FFFFFF"/>
                <circle cx="63" cy="46" r="2.5" fill="#18181A"/>
              </g>
              <path d="M 42 66 Q 50 74 58 66" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round" fill="none"/>
              <circle cx="26" cy="58" r="4" fill="#FFFFFF" fill-opacity="0.15"/>
              <circle cx="74" cy="58" r="4" fill="#FFFFFF" fill-opacity="0.15"/>
            </svg>
          </div>
          <div>
            <span class="text-[10px] font-mono text-[#8E8E93] uppercase tracking-wider">STATE 01</span>
            <h3 class="text-sm font-semibold text-white">Ambient Welcome Mode</h3>
            <p class="text-xs text-[#8E8E93] mt-1">
              Curious and relaxed during idle states. Greets Minh and floats gently in the center of the Home dashboard.
            </p>
          </div>
        </div>

        <!-- Mascot 2: Focus Sprint Mode -->
        <div class="bg-black/60 border border-white/10 rounded-xl p-5 flex flex-col items-center text-center space-y-4">
          <div class="mascot-float w-28 h-28 relative flex items-center justify-center">
            <svg viewBox="0 0 100 100" class="w-full h-full drop-shadow-[0_12px_24px_rgba(255,255,255,0.12)]">
              <path d="M 12 40 A 38 38 0 0 1 88 40" stroke="#FFFFFF" stroke-width="3.5" fill="none"/>
              <rect x="12" y="16" width="76" height="74" rx="28" fill="#18181A" stroke="#FFFFFF" stroke-width="2.5" stroke-opacity="0.4"/>
              <ellipse cx="50" cy="26" rx="24" ry="8" fill="#FFFFFF" fill-opacity="0.14"/>
              <rect x="6" y="32" width="10" height="24" rx="5" fill="#2C2C2E" stroke="#FFFFFF" stroke-width="1.5"/>
              <rect x="84" y="32" width="10" height="24" rx="5" fill="#2C2C2E" stroke="#FFFFFF" stroke-width="1.5"/>
              <path d="M 28 48 L 36 43 L 44 48" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" fill="none"/>
              <path d="M 56 48 L 64 43 L 72 48" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" fill="none"/>
              <line x1="44" y1="64" x2="56" y2="64" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round"/>
            </svg>
          </div>
          <div>
            <span class="text-[10px] font-mono text-[#8E8E93] uppercase tracking-wider">STATE 02</span>
            <h3 class="text-sm font-semibold text-white">Pomodoro Focus Mode</h3>
            <p class="text-xs text-[#8E8E93] mt-1">
              Puts on studio acoustics headphones and locks in with a determined focus expression during 25m sprint sessions.
            </p>
          </div>
        </div>

        <!-- Mascot 3: Music Playback Mode -->
        <div class="bg-black/60 border border-white/10 rounded-xl p-5 flex flex-col items-center text-center space-y-4">
          <div class="mascot-float w-28 h-28 relative flex items-center justify-center">
            <svg viewBox="0 0 100 100" class="w-full h-full drop-shadow-[0_12px_24px_rgba(255,255,255,0.12)]">
              <rect x="12" y="12" width="76" height="76" rx="28" fill="#18181A" stroke="#FFFFFF" stroke-width="2.5" stroke-opacity="0.4"/>
              <ellipse cx="50" cy="24" rx="24" ry="8" fill="#FFFFFF" fill-opacity="0.14"/>
              <path d="M 30 46 Q 37 38 44 46" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" fill="none"/>
              <path d="M 56 46 Q 63 38 70 46" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" fill="none"/>
              <ellipse cx="50" cy="62" rx="6" ry="9" fill="#FFFFFF"/>
              <text x="76" y="32" font-size="16" fill="#FFFFFF">♫</text>
            </svg>
          </div>
          <div>
            <span class="text-[10px] font-mono text-[#8E8E93] uppercase tracking-wider">STATE 03</span>
            <h3 class="text-sm font-semibold text-white">Now Playing Music Mode</h3>
            <p class="text-xs text-[#8E8E93] mt-1">
              Vibes joyfully to audio playback with singing expression and soundwave ripples echoing beneath the island.
            </p>
          </div>
        </div>
      </div>
    </section>
""")

# Section 3: Exact Scale Validation (User Baseline vs Redesign)
html_parts.append(f"""
    <!-- SECTION 3: EXACT REALISTIC SCALE COMPARISON -->
    <section id="scale-validation" class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl space-y-6">
      <div class="border-b border-white/10 pb-4">
        <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">Scale Validation</span>
        <h2 class="text-xl font-semibold text-white tracking-tight">Exact 640 × 225 pt Realistic Scale Comparison</h2>
        <p class="text-xs text-[#8E8E93] mt-0.5">
          Verifying that the redesigned Morph interface adheres strictly to the physical dimensions (<span class="text-white font-mono">640 × 225 pt</span>) without expanding into an oversized desktop window.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
        <!-- Left: Baseline User Screenshot -->
        <div class="space-y-2">
          <div class="flex items-center justify-between text-xs">
            <span class="font-mono text-[#8E8E93] uppercase">Current Morph Baseline (Your Screenshot)</span>
            <span class="font-mono text-[#8E8E93]">1024 × 374 px</span>
          </div>
          <div class="rounded-xl border border-white/10 overflow-hidden bg-black p-2 flex items-center justify-center shadow-xl">
            <img src="data:image/png;base64,{b64_baseline}" alt="Current Morph Baseline" class="w-full h-auto rounded-lg">
          </div>
          <p class="text-[11px] text-[#8E8E93]">
            Features old static 3-dot circle in center, top tab bar, calendar glance on left, and launch cockpit on right.
          </p>
        </div>

        <!-- Right: Redesigned Home with Morphy Mascot -->
        <div class="space-y-2">
          <div class="flex items-center justify-between text-xs">
            <span class="font-mono text-white uppercase font-semibold">Redesigned Morph Home (With Mascot)</span>
            <span class="font-mono text-white bg-white/10 px-2 py-0.5 rounded">Exact 640 × 225 pt</span>
          </div>
          <div class="rounded-xl border border-white/20 overflow-hidden bg-black p-2 flex items-center justify-center shadow-xl">
            <img src="data:image/png;base64,{b64_home_redesign}" alt="Morph Realistic Home Redesign" class="w-full h-auto rounded-lg">
          </div>
          <p class="text-[11px] text-[#8E8E93]">
            Identical compact footprint (<span class="text-white">640 × 225 pt</span>) with the adorable Morphy Mascot centerpiece, 100% pure neutral monochrome, and zero bullet dots.
          </p>
        </div>
      </div>
    </section>
""")

# Section 4: Direct Resolution of Screenshot 2 (Profile Page: Oversized vs Realistic Compact)
html_parts.append(f"""
    <!-- SECTION 4: DIRECT RESOLUTION OF SCREENSHOT 2 -->
    <section id="screenshot2-fix" class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl space-y-6">
      <div class="border-b border-white/10 pb-4">
        <div class="flex items-center space-x-2">
          <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">Direct Feedback Resolution</span>
          <span class="px-2 py-0.5 rounded bg-white/10 text-[10px] font-mono text-white">Screenshot 2 Fixed</span>
        </div>
        <h2 class="text-xl font-semibold text-white tracking-tight">Profile & Preferences Redesign: Oversized vs Realistic Scale</h2>
        <p class="text-xs text-[#8E8E93] mt-0.5">
          In response to your observation that the previous artifact's State 3 modal was unrealistically large, this direct comparison shows the oversized version vs the new realistic compact <span class="text-white font-mono">640 × 225 pt</span> architecture.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
        <!-- Left: Oversized Previous Version (Screenshot 2) -->
        <div class="space-y-2">
          <div class="flex items-center justify-between text-xs">
            <span class="font-mono text-[#8E8E93] uppercase">Previous Artifact (Your 2nd Screenshot)</span>
            <span class="font-mono text-[#8E8E93] bg-white/5 px-2 py-0.5 rounded">Oversized Desktop Window</span>
          </div>
          <div class="rounded-xl border border-white/10 overflow-hidden bg-black p-2 flex items-center justify-center shadow-xl">
            <img src="data:image/png;base64,{b64_user_screenshot_2}" alt="Previous Oversized Profile Window" class="w-full h-auto rounded-lg opacity-85">
          </div>
          <p class="text-[11px] text-[#8E8E93]">
            The previous design occupied a large desktop modal that overwhelmed the screen and broke the compact Dynamic Island feel.
          </p>
        </div>

        <!-- Right: New Realistic Compact Profile Page -->
        <div class="space-y-2">
          <div class="flex items-center justify-between text-xs">
            <span class="font-mono text-white uppercase font-semibold">New Realistic Profile Page (Redesigned)</span>
            <span class="font-mono text-white bg-white/10 px-2 py-0.5 rounded">Exact 640 × 225 pt</span>
          </div>
          <div class="rounded-xl border border-white/20 overflow-hidden bg-black p-2 flex items-center justify-center shadow-xl">
            <img src="data:image/png;base64,{pages[5]['b64']}" alt="Realistic Profile Page Redesign" class="w-full h-auto rounded-lg">
          </div>
          <p class="text-[11px] text-[#8E8E93]">
            100% of user data preserved: User avatar MN, Minh Nguyen, Focus stats (2,480m, 14 Days streak, 42 sessions), Continuity status, and Appearance & Pinning settings, engineered strictly into the compact <span class="text-white">640 × 225 pt</span> footprint.
          </p>
        </div>
      </div>
    </section>
""")

# Section 5: The Complete Suite of All 10 Realistic Pages
html_parts.append("""
    <!-- SECTION 5: COMPLETE 10-PAGE REALISTIC SUITE -->
    <section id="realistic-suite" class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl space-y-6">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-2 border-b border-white/10 pb-4">
        <div>
          <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">Universal Architecture</span>
          <h2 class="text-xl font-semibold text-white tracking-tight">Complete Suite of All 10 Redesigned Pages</h2>
          <p class="text-xs text-[#8E8E93] mt-0.5">
            Every page in Morph redesigned strictly at the exact compact size of Morph (<span class="text-white font-mono">640 × 225 pt</span>, Retina 2x <span class="text-white font-mono">1280 × 450 px</span>). Click any tab to inspect.
          </p>
        </div>
        <span class="text-xs font-mono text-white bg-white/10 px-3 py-1 rounded-full border border-white/20">
          10 / 10 Pages Ready
        </span>
      </div>

      <!-- Segmented Tab Navigation for All 10 Pages -->
      <div class="flex items-center space-x-1.5 overflow-x-auto pb-2 border-b border-white/5 scrollbar-none">
""")

for i, p in enumerate(pages):
    active_cls = "tab-active" if i == 0 else "bg-white/5 text-[#8E8E93] hover:text-white hover:bg-white/10"
    html_parts.append(f"""
        <button id="tab-btn-{i}" onclick="switchRealisticPage({i})" class="px-3 py-1.5 rounded-lg text-xs font-mono whitespace-nowrap transition-all {active_cls}">
          {i+1:02d} {p['tab']}
        </button>
    """)

html_parts.append("""
      </div>

      <!-- Active Page Display Viewport -->
      <div id="page-display-container" class="space-y-6">
""")

for i, p in enumerate(pages):
    hidden_cls = "" if i == 0 else "hidden"
    html_parts.append(f"""
        <div id="page-panel-{i}" class="{hidden_cls} space-y-4">
          <div class="flex flex-col md:flex-row md:items-center justify-between gap-2">
            <div>
              <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">EXACT 640 × 225 PT COMPACT GEOMETRY</span>
              <h3 class="text-lg font-semibold text-white mt-0.5">{p['title']}</h3>
            </div>
            <div class="flex items-center space-x-2">
              <span class="text-xs font-mono text-white bg-white/10 px-2.5 py-1 rounded border border-white/10">1280 × 450 px (Retina 2x)</span>
            </div>
          </div>

          <!-- Realistic Image Render (Embedded Base64) -->
          <div class="rounded-xl border border-white/20 overflow-hidden bg-black p-2 shadow-2xl flex items-center justify-center">
            <img src="data:image/png;base64,{p['b64']}" alt="{p['title']}" class="w-full h-auto rounded-lg">
          </div>

          <!-- Specifications Matrix: State 2 & State 3 -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
            <div class="p-4 rounded-xl bg-black/60 border border-white/10 space-y-1.5">
              <span class="font-mono text-[#8E8E93] uppercase tracking-wider font-medium text-[10px]">STATE 2 (EXTENDED BACKGROUND PILL)</span>
              <p class="text-white/90 leading-relaxed">{p['state2']}</p>
            </div>
            <div class="p-4 rounded-xl bg-black/60 border border-white/10 space-y-1.5">
              <span class="font-mono text-[#8E8E93] uppercase tracking-wider font-medium text-[10px]">STATE 3 (FULL BIG UI — 640 × 225 PT)</span>
              <p class="text-white/90 leading-relaxed">{p['state3']}</p>
            </div>
          </div>

          <!-- Features Preserved Checklist -->
          <div class="p-4 rounded-xl bg-white/[0.02] border border-white/10 space-y-2">
            <span class="font-mono text-[#8E8E93] uppercase tracking-wider font-medium text-[10px]">ORIGINAL FEATURES PRESERVED WITHOUT REGRESSION</span>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-xs text-[#E5E5E7]">
    """)
    for feat in p["features"]:
        html_parts.append(f"""
              <div class="flex items-center space-x-2">
                <span class="text-white font-mono text-[10px]">—</span>
                <span>{feat}</span>
              </div>
        """)
    html_parts.append("""
            </div>
          </div>
        </div>
    """)

html_parts.append("""
      </div>

      <!-- Quick Thumbnail Strip of All 10 Pages -->
      <div class="border-t border-white/10 pt-6">
        <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider mb-3 block">Gallery Overview (All 10 Pages at 640 × 225 pt)</span>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-3">
""")

for i, p in enumerate(pages):
    html_parts.append(f"""
          <button onclick="switchRealisticPage({i})" class="group text-left p-1.5 rounded-lg bg-black border border-white/10 hover:border-white/40 transition-all">
            <div class="aspect-[640/225] rounded overflow-hidden bg-black/40 mb-1.5">
              <img src="data:image/png;base64,{p['b64']}" alt="{p['tab']}" class="w-full h-full object-cover group-hover:scale-105 transition-all">
            </div>
            <div class="flex items-center justify-between text-[10px] font-mono">
              <span class="text-[#8E8E93] group-hover:text-white transition-colors">{i+1:02d} {p['tab']}</span>
              <span class="text-white/40">↗</span>
            </div>
          </button>
    """)

html_parts.append("""
        </div>
      </div>
    </section>
""")

# Section 6: Master Design Boards
html_parts.append(f"""
    <!-- SECTION 6: MASTER DESIGN BOARDS -->
    <section id="master-boards" class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl space-y-6">
      <div class="border-b border-white/10 pb-4">
        <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">High-Resolution Visual Boards</span>
        <h2 class="text-xl font-semibold text-white tracking-tight">Master Design Boards</h2>
        <p class="text-xs text-[#8E8E93] mt-0.5">
          High-definition interaction flows and character design sheets rendered at 2400+ px resolution.
        </p>
      </div>

      <div class="space-y-8">
        <div>
          <h3 class="text-sm font-semibold text-white mb-2">1. Spotlight Island Search Interaction Flow</h3>
          <div class="rounded-xl border border-white/10 overflow-hidden bg-black shadow-xl">
            <img src="data:image/png;base64,{b64_spotlight_flow}" alt="Spotlight Island Flow" class="w-full h-auto">
          </div>
        </div>

        <div>
          <h3 class="text-sm font-semibold text-white mb-2">2. Morphy Mascot Identity Showcase</h3>
          <div class="rounded-xl border border-white/10 overflow-hidden bg-black shadow-xl">
            <img src="data:image/png;base64,{b64_mascot_showcase}" alt="Morphy Mascot Showcase" class="w-full h-auto">
          </div>
        </div>
      </div>
    </section>

  </div>

  <!-- Interactive JavaScript Controller -->
  <script>
    // Page data mapping for simulator
    const pageImages = {{
""")

for i, p in enumerate(pages):
    html_parts.append(f"""      "{p['id']}": "data:image/png;base64,{p['b64']}",\n""")

html_parts.append("""    };

    function setSimState(state) {
      const hud = document.getElementById('island-hud');
      const c1 = document.getElementById('content-state-1');
      const c2 = document.getElementById('content-state-2');
      const c3 = document.getElementById('content-state-3');

      const b1 = document.getElementById('btn-state-1');
      const b2 = document.getElementById('btn-state-2');
      const b3 = document.getElementById('btn-state-3');

      [b1, b2, b3].forEach(b => {
        b.className = "px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white/5 hover:bg-white/10 text-[#8E8E93]";
      });

      if (state === 1) {
        hud.style.width = "210px";
        hud.style.height = "36px";
        c1.classList.remove('hidden');
        c2.classList.add('hidden');
        c3.classList.add('hidden');
        b1.className = "px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white text-black font-medium";
      } else if (state === 2) {
        hud.style.width = "540px";
        hud.style.height = "40px";
        c1.classList.add('hidden');
        c2.classList.remove('hidden');
        c3.classList.add('hidden');
        b2.className = "px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white text-black font-medium";
        setTimeout(() => {
          const input = document.getElementById('search-input');
          if (input) input.focus();
        }, 150);
      } else if (state === 3) {
        hud.style.width = "640px";
        hud.style.height = "225px";
        c1.classList.add('hidden');
        c2.classList.add('hidden');
        c3.classList.remove('hidden');
        b3.className = "px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white text-black font-medium";
      }
    }

    function openContextUI(type) {
      const img = document.getElementById('sim-big-ui-img');
      const status = document.getElementById('sim-profile-status');
      if (type === 'music') {
        img.src = pageImages['page-03'];
        status.textContent = 'ACTIVE VIEW: Music Player (Spatial Audio)';
      } else if (type === 'timer') {
        img.src = pageImages['page-02'];
        status.textContent = 'ACTIVE VIEW: Focus Timer (Pomodoro Sprint)';
      } else if (type === 'notes') {
        img.src = pageImages['page-04'];
        status.textContent = 'ACTIVE VIEW: Quick Markdown Scratchpad';
      } else if (type === 'profile') {
        img.src = pageImages['page-06'];
        status.textContent = 'ACTIVE VIEW: Profile & Preferences (Screenshot 2 Redesign)';
      } else if (type === 'calendar') {
        img.src = pageImages['page-05'];
        status.textContent = 'ACTIVE VIEW: Smart Calendar & Agenda';
      } else if (type === 'meeting') {
        img.src = pageImages['page-07'];
        status.textContent = 'ACTIVE VIEW: Meeting Cockpit';
      } else if (type === 'shelf') {
        img.src = pageImages['page-08'];
        status.textContent = 'ACTIVE VIEW: Drop Shelf (AirDrop Target)';
      } else {
        img.src = pageImages['page-01'];
        status.textContent = 'ACTIVE VIEW: Home Dashboard (Mascot Centerpiece)';
      }
      setSimState(3);
    }

    function onSearchChange(val) {
      const q = val.toLowerCase().trim();
      if (!q) return;
      if (q.includes('mus') || q.includes('song') || q.includes('mid')) {
        openContextUI('music');
      } else if (q.includes('tim') || q.includes('pomo') || q.includes('foc')) {
        openContextUI('timer');
      } else if (q.includes('not') || q.includes('scratch') || q.includes('writ')) {
        openContextUI('notes');
      } else if (q.includes('pro') || q.includes('set') || q.includes('minh') || q.includes('acc')) {
        openContextUI('profile');
      } else if (q.includes('cal') || q.includes('meet') || q.includes('agen')) {
        openContextUI('calendar');
      } else if (q.includes('drop') || q.includes('shelf') || q.includes('air')) {
        openContextUI('shelf');
      }
    }

    function switchRealisticPage(idx) {
      for (let i = 0; i < 10; i++) {
        const panel = document.getElementById(`page-panel-${i}`);
        const btn = document.getElementById(`tab-btn-${i}`);
        if (i === idx) {
          panel.classList.remove('hidden');
          btn.className = "px-3 py-1.5 rounded-lg text-xs font-mono whitespace-nowrap transition-all tab-active";
        } else {
          panel.classList.add('hidden');
          btn.className = "px-3 py-1.5 rounded-lg text-xs font-mono whitespace-nowrap transition-all bg-white/5 text-[#8E8E93] hover:text-white hover:bg-white/10";
        }
      }
    }

    document.getElementById('island-hud').addEventListener('click', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'BUTTON' || e.target.tagName === 'SPAN') return;
      const hud = document.getElementById('island-hud');
      if (hud.style.width === "210px" || !hud.style.width) {
        setSimState(2);
      } else if (hud.style.width === "540px") {
        setSimState(3);
      }
    });
  </script>
</body>
</html>
""")

full_html = "".join(html_parts)

with open(OUTPUT_HTML, "w", encoding="utf-8") as f:
    f.write(full_html)

print(f"Generated {OUTPUT_HTML} successfully! Size: {len(full_html) / 1024:.1f} KB")
