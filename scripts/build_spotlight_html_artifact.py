#!/usr/bin/env python3
import os

ARTIFACT_PATH = "/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd/apple_dynamic_island_spotlight_exploration.html"

html_content = """<!DOCTYPE html>
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
  </style>
</head>
<body class="bg-[#0A0A0C] text-[#E5E5E7] antialiased selection:bg-white/20 p-6 font-sans min-h-screen">

  <!-- Main Container -->
  <div class="max-w-6xl mx-auto space-y-10">

    <!-- Top Hero Header -->
    <header class="border-b border-white/10 pb-6 flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div>
        <div class="flex items-center space-x-2 text-xs font-mono tracking-widest text-[#8E8E93] uppercase">
          <span> Apple Dynamic Island Paradigm</span>
          <span>•</span>
          <span>Workspace Architecture v4.5</span>
        </div>
        <h1 class="text-2xl md:text-3xl font-semibold tracking-tight text-white mt-1">
          Spotlight Island Search & Morphy Mascot Redesign
        </h1>
        <p class="text-sm text-[#8E8E93] mt-1 max-w-2xl">
          An exploration of realistic compact geometry (<span class="text-white font-mono">640 × 225 pt</span>), an expressive Apple companion mascot, and the paradigm shift from static tab pages to unified Spotlight in-pill search.
        </p>
      </div>
      <div class="flex items-center space-x-3">
        <span class="px-3 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs font-mono text-[#8E8E93]">
          100% Neutral Monochrome
        </span>
        <span class="px-3 py-1.5 rounded-full bg-white/10 border border-white/20 text-xs font-mono text-white">
          Exact 640×225 Scale
        </span>
      </div>
    </header>

    <!-- SECTION 1: INTERACTIVE SPOTLIGHT SEARCH SIMULATOR -->
    <section class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl relative overflow-hidden">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-2 mb-6">
        <div>
          <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">Concept Exploration 01</span>
          <h2 class="text-xl font-semibold text-white tracking-tight">The Spotlight Island Search Flow</h2>
          <p class="text-xs text-[#8E8E93] mt-0.5">
            Hover lengthens the island into a search bar. Type or select a quick action to bloom directly into the exact tool, eliminating static tab clutter.
          </p>
        </div>
        <div class="flex items-center space-x-2">
          <button id="btn-state-1" onclick="setSimState(1)" class="px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white text-black font-medium">1. Resting (210×36)</button>
          <button id="btn-state-2" onclick="setSimState(2)" class="px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white/5 hover:bg-white/10 text-[#8E8E93]">2. Lengthened Search</button>
          <button id="btn-state-3" onclick="setSimState(3)" class="px-3 py-1.5 rounded-lg text-xs font-mono transition-all bg-white/5 hover:bg-white/10 text-[#8E8E93]">3. Big UI (640×225)</button>
        </div>
      </div>

      <!-- Simulated MacBook Desktop Viewport -->
      <div class="w-full bg-[#050507] border border-white/10 rounded-xl relative overflow-hidden min-h-[460px] flex flex-col items-center">
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
          <div class="flex items-center space-x-3 font-mono text-[11px]">
            <span>Wi-Fi</span>
            <span>98%</span>
            <span>Sat 10:42 AM</span>
          </div>
        </div>

        <!-- MacBook Hardware Notch -->
        <div class="w-44 h-7 bg-black rounded-b-xl flex items-center justify-center space-x-3 pointer-events-none z-30 shadow-md">
          <div class="w-2 h-2 rounded-full bg-[#181818] ring-1 ring-white/10"></div>
          <div class="w-1 h-1 rounded-full bg-white/30"></div>
        </div>

        <!-- 14pt Vertical Breathing Clearance Indicator -->
        <div class="h-3.5 w-full flex items-center justify-center pointer-events-none">
          <span class="text-[9px] font-mono text-[#8E8E93]/60 uppercase tracking-widest">14pt Clearance Corridor (Zero Tab Occlusion)</span>
        </div>

        <!-- The Dynamic Island Container (Interactive Simulator) -->
        <div id="island-hud" class="island-spring specular-rim bg-black border border-white/20 rounded-[28px] relative overflow-hidden flex flex-col items-center justify-center cursor-pointer shadow-2xl z-20 w-[210px] h-[36px]">

          <!-- STATE 1: RESTING PILL CONTENT -->
          <div id="content-state-1" class="w-full h-full flex items-center justify-between px-3 text-xs">
            <div class="flex items-center space-x-2">
              <span class="w-2 h-2 rounded-full bg-white/40"></span>
              <span class="font-mono text-[11px] text-[#8E8E93]">Morph Ambient</span>
            </div>
            <span class="text-[10px] font-mono text-[#8E8E93]/70">Hover to Search</span>
          </div>

          <!-- STATE 2: LENGTHENED SEARCH PILL CONTENT -->
          <div id="content-state-2" class="w-full h-full hidden flex items-center justify-between px-4 text-xs">
            <div class="flex items-center space-x-3 flex-1">
              <!-- Mini Morphy Icon -->
              <div class="w-6 h-6 rounded-full bg-white/10 flex items-center justify-center text-xs text-white">
                
              </div>
              <input id="search-input" type="text" placeholder="Search music, focus timer, notes, calendar..." value="midnight city" oninput="onSearchChange(this.value)" class="bg-transparent text-white placeholder-[#8E8E93] text-xs font-sans outline-none flex-1 border-none tracking-tight">
            </div>
            <div class="flex items-center space-x-2">
              <span onclick="openContextUI('music')" class="px-2.5 py-1 rounded-full bg-white text-black text-[11px] font-medium hover:opacity-90 transition-opacity">↵ Open Music</span>
              <span onclick="setSimState(1)" class="px-2 py-1 rounded-full bg-white/10 text-[#8E8E93] text-[11px] hover:text-white">⎋</span>
            </div>
          </div>

          <!-- STATE 3: REALISTIC BIGGEST UI (640 × 225 pt) CONTENT -->
          <div id="content-state-3" class="w-full h-full hidden flex flex-col justify-between p-4 text-xs">
            <!-- Top Row -->
            <div class="w-full flex items-center justify-between border-b border-white/10 pb-2.5">
              <div class="flex items-center space-x-2.5">
                <div class="w-7 h-7 rounded-full bg-white/10 flex items-center justify-center text-xs font-semibold text-white">
                  MN
                </div>
                <span class="font-semibold text-sm text-white">Minh</span>
                <span class="text-[10px] font-mono text-[#8E8E93] bg-white/5 px-2 py-0.5 rounded">HOME DASHBOARD</span>
              </div>
              <div class="flex items-center space-x-2">
                <span class="text-[10px] font-mono text-[#8E8E93]">640 × 225 PT REALISTIC SCALE</span>
                <button onclick="setSimState(2)" class="px-2 py-1 rounded bg-white/10 hover:bg-white/20 text-[#8E8E93] hover:text-white font-mono text-[10px]">⎋ Collapse</button>
              </div>
            </div>

            <!-- Main Stage (Tri-Deck Symmetrical Layout) -->
            <div class="grid grid-cols-12 gap-3 items-center my-auto">
              <!-- Left Deck: Calendar Glance -->
              <div class="col-span-4 p-3 rounded-xl bg-white/[0.03] border border-white/10 space-y-1">
                <span class="text-[10px] font-mono text-[#8E8E93] uppercase tracking-wider">GLANCE</span>
                <div class="text-sm font-semibold text-white">Saturday, Oct 31</div>
                <div class="text-[11px] text-[#8E8E93]">2 meetings today</div>
                <div class="mt-2 pt-2 border-t border-white/5 flex items-center justify-between">
                  <div class="truncate text-[10px] text-white">Design Review</div>
                  <span class="px-2 py-0.5 rounded-full bg-white text-black text-[9px] font-semibold">In 14m</span>
                </div>
              </div>

              <!-- Centerpiece: Morphy Mascot Companion -->
              <div class="col-span-4 flex flex-col items-center justify-center text-center p-2 rounded-xl bg-white/[0.02] border border-white/5 relative">
                <!-- Mascot Animated SVG -->
                <div class="mascot-float w-16 h-16 relative flex items-center justify-center">
                  <svg viewBox="0 0 100 100" class="w-full h-full drop-shadow-[0_8px_16px_rgba(255,255,255,0.1)]">
                    <!-- Body Squircle -->
                    <rect x="12" y="12" width="76" height="76" rx="28" fill="#1C1C1E" stroke="#FFFFFF" stroke-width="2.5" stroke-opacity="0.35"/>
                    <ellipse cx="50" cy="24" rx="24" ry="8" fill="#FFFFFF" fill-opacity="0.12"/>
                    <!-- Eyes -->
                    <g class="mascot-eye">
                      <rect x="32" y="42" width="9" height="16" rx="4.5" fill="#FFFFFF"/>
                      <circle cx="36" cy="46" r="2.5" fill="#1C1C1E"/>
                      <rect x="59" y="42" width="9" height="16" rx="4.5" fill="#FFFFFF"/>
                      <circle cx="63" cy="46" r="2.5" fill="#1C1C1E"/>
                    </g>
                    <!-- Smile -->
                    <path d="M 42 66 Q 50 74 58 66" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round" fill="none"/>
                  </svg>
                </div>
                <div class="text-xs font-semibold text-white mt-1">Good evening, Minh</div>
                <div class="px-2.5 py-0.5 rounded-full bg-white/10 text-[10px] font-mono text-[#8E8E93] mt-1 border border-white/10">
                  Ready for Focus
                </div>
              </div>

              <!-- Right Deck: Launch Cockpit -->
              <div class="col-span-4 p-3 rounded-xl bg-white/[0.03] border border-white/10 space-y-1.5">
                <span class="text-[10px] font-mono text-[#8E8E93] uppercase tracking-wider">LAUNCH</span>
                <div class="flex items-center justify-between text-xs py-1 px-2 rounded bg-white/5 border border-white/5">
                  <span class="text-white">Focus Session</span>
                  <span class="text-[10px] font-mono text-[#8E8E93]">⌘2</span>
                </div>
                <div class="flex items-center justify-between text-xs py-1 px-2 rounded bg-white/5 border border-white/5">
                  <span class="text-white">YouTube Music</span>
                  <span class="text-[10px] font-mono text-[#8E8E93]">⌘3</span>
                </div>
                <div class="flex items-center justify-between text-xs py-1 px-2 rounded bg-white/5 border border-white/5">
                  <span class="text-white">Scratchpad</span>
                  <span class="text-[10px] font-mono text-[#8E8E93]">⌘4</span>
                </div>
              </div>
            </div>

            <!-- Bottom Telemetry Rail -->
            <div class="w-full flex items-center justify-between border-t border-white/5 pt-2 text-[10px] text-[#8E8E93]">
              <span>ACTIVE PROFILE: Minh Workspace</span>
              <span class="text-white">100% Click-Through in Resting State</span>
              <span>ESC to Collapse</span>
            </div>
          </div>
        </div>

        <!-- Simulation Instruction Pill -->
        <div class="absolute bottom-4 inset-x-0 flex justify-center pointer-events-none">
          <div class="px-4 py-1.5 rounded-full bg-white/5 border border-white/10 text-[11px] font-mono text-[#8E8E93] backdrop-blur-md">
            Click buttons above or click the island to toggle states
          </div>
        </div>
      </div>
    </section>

    <!-- SECTION 2: THE MORPHY MASCOT ARCHITECTURE -->
    <section class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl space-y-6">
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

      <!-- Mascot 3 States Grid -->
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
              <!-- Headband -->
              <path d="M 12 40 A 38 38 0 0 1 88 40" stroke="#FFFFFF" stroke-width="3.5" fill="none"/>
              <rect x="12" y="16" width="76" height="74" rx="28" fill="#18181A" stroke="#FFFFFF" stroke-width="2.5" stroke-opacity="0.4"/>
              <ellipse cx="50" cy="26" rx="24" ry="8" fill="#FFFFFF" fill-opacity="0.14"/>
              <!-- Headphone ear cups -->
              <rect x="6" y="32" width="10" height="24" rx="5" fill="#2C2C2E" stroke="#FFFFFF" stroke-width="1.5"/>
              <rect x="84" y="32" width="10" height="24" rx="5" fill="#2C2C2E" stroke="#FFFFFF" stroke-width="1.5"/>
              <!-- Focused squinty eyes -->
              <path d="M 28 48 L 36 43 L 44 48" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" fill="none"/>
              <path d="M 56 48 L 64 43 L 72 48" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" fill="none"/>
              <!-- Determined smile -->
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
              <!-- Vibing curved happy eyes -->
              <path d="M 30 46 Q 37 38 44 46" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" fill="none"/>
              <path d="M 56 46 Q 63 38 70 46" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" fill="none"/>
              <!-- Singing mouth -->
              <ellipse cx="50" cy="62" rx="6" ry="9" fill="#FFFFFF"/>
              <!-- Music notes floating -->
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

    <!-- SECTION 3: EXACT REALISTIC SCALE COMPARISON -->
    <section class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl space-y-6">
      <div class="border-b border-white/10 pb-4">
        <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">Scale Validation</span>
        <h2 class="text-xl font-semibold text-white tracking-tight">Exact 640 × 225 pt Realistic Scale Comparison</h2>
        <p class="text-xs text-[#8E8E93] mt-0.5">
          Verifying that the redesigned Morph interface adheres strictly to the physical dimensions (<span class="text-white font-mono">640 × 225 pt</span>) without expanding into an oversized desktop window.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 items-start">
        <!-- Left: Baseline Screenshot Reference -->
        <div class="space-y-2">
          <div class="flex items-center justify-between text-xs">
            <span class="font-mono text-[#8E8E93] uppercase">Current Morph Baseline (Your Screenshot)</span>
            <span class="font-mono text-white/50">1024 × 374 px</span>
          </div>
          <div class="rounded-xl border border-white/10 overflow-hidden bg-black p-2 flex items-center justify-center">
            <img src="/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd/.user_uploaded/media_1793503484465_1afb309d.png" alt="Current Morph Baseline" class="w-full h-auto rounded-lg">
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
            <img src="/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd/morph_realistic_home_redesign.png" alt="Morph Realistic Home Redesign" class="w-full h-auto rounded-lg">
          </div>
          <p class="text-[11px] text-[#8E8E93]">
            Identical compact footprint (<span class="text-white">640 × 225 pt</span>) with the adorable Morphy Mascot centerpiece, 100% pure neutral monochrome, and zero bullet dots.
          </p>
        </div>
      </div>
    </section>

    <!-- SECTION 4: MASTER BOARD EMBEDS -->
    <section class="bg-[#121215] border border-white/10 rounded-2xl p-6 shadow-2xl space-y-6">
      <div class="border-b border-white/10 pb-4">
        <span class="text-xs font-mono text-[#8E8E93] uppercase tracking-wider">High-Resolution Visual Boards</span>
        <h2 class="text-xl font-semibold text-white tracking-tight">Master Design Boards</h2>
      </div>

      <div class="space-y-8">
        <div>
          <h3 class="text-sm font-semibold text-white mb-2">1. Spotlight Island Search Interaction Flow</h3>
          <div class="rounded-xl border border-white/10 overflow-hidden bg-black">
            <img src="/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd/morph_spotlight_island_flow.png" alt="Spotlight Island Flow" class="w-full h-auto">
          </div>
        </div>

        <div>
          <h3 class="text-sm font-semibold text-white mb-2">2. Morphy Mascot Identity Showcase</h3>
          <div class="rounded-xl border border-white/10 overflow-hidden bg-black">
            <img src="/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd/morphy_mascot_showcase.png" alt="Morphy Mascot Showcase" class="w-full h-auto">
          </div>
        </div>
      </div>
    </section>

  </div>

  <!-- Interactive JavaScript Logic -->
  <script>
    function setSimState(state) {
      const hud = document.getElementById('island-hud');
      const c1 = document.getElementById('content-state-1');
      const c2 = document.getElementById('content-state-2');
      const c3 = document.getElementById('content-state-3');

      const b1 = document.getElementById('btn-state-1');
      const b2 = document.getElementById('btn-state-2');
      const b3 = document.getElementById('btn-state-3');

      // Reset button styles
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
        }, 200);
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
      setSimState(3);
    }

    function onSearchChange(val) {
      if (val.toLowerCase().includes('music') || val.toLowerCase().includes('midnight')) {
        // Can dynamic trigger
      }
    }

    // Click on island cycles state
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
"""

with open(ARTIFACT_PATH, "w") as f:
    f.write(html_content)

print(f"Created HTML artifact successfully at {ARTIFACT_PATH}")
