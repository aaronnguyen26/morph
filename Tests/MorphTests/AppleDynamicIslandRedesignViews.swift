import SwiftUI
import AppKit

// MARK: - Apple Dynamic Island Design Tokens & Primitives

public struct AppleIslandTokens {
    public static let oledBlack = Color.black
    public static let glassSurface = Color(white: 0.12, opacity: 0.65)
    public static let specularRim = Color.white.opacity(0.14)
    public static let innerGlint = Color.white.opacity(0.20)
    public static let textPrimary = Color.white
    public static let textSecondary = Color(white: 0.70)
    public static let textTertiary = Color(white: 0.45)
    
    // Strict 3-Color Apple Minimalist Palette (Pitch Black #000000, Studio White #FFFFFF, Titanium Gray #8E8E93)
    public static let titaniumGray = Color(white: 0.58)
    public static let appleBlue = Color.white
    public static let appleAmber = Color(white: 0.58)
    public static let appleGreen = Color.white
    public static let appleRed = Color(white: 0.58)
    public static let applePurple = Color(white: 0.58)
    public static let applePink = Color.white
}

// MARK: - Autonomous Apple Dynamic Island Header Anchor

public struct AppleDynamicIslandHeaderAnchor: View {
    var showCameraLED: Bool = false
    
    public init(showCameraLED: Bool = false) {
        self.showCameraLED = showCameraLED
    }
    
    public var body: some View {
        HStack {
            Spacer()
            // Micro-machined titanium drag indicator capsule (38 x 4 pt)
            Capsule()
                .fill(Color.white.opacity(0.20))
                .frame(width: 38, height: 4)
            Spacer()
        }
        .frame(height: 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

// MARK: - 1. Apple Dynamic Island: Home Hub View

public struct AppleDynamicIslandHomeRedesign: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            AppleDynamicIslandHeaderAnchor()
            
            // Expanded Island Body
            HStack(alignment: .center, spacing: 20) {
                // Left Wing: Calendar Glance & Meeting Telemetry
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                        Text("CALENDAR GLANCE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Design Review")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                        Text("In 14m — Virtual Room A")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppleIslandTokens.titaniumGray)
                    }
                    
                    HStack(spacing: 8) {
                        Label("Saturday, Oct 31", systemImage: "clock")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                        Text("—")
                            .font(.system(size: 10))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        Label("3 Events", systemImage: "checklist")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 175, alignment: .leading)
                
                // Centerpiece: Living Morphy Core & Personalized Greeting
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Capsule().fill(AppleIslandTokens.titaniumGray).frame(width: 3, height: 12)
                        Capsule().fill(AppleIslandTokens.titaniumGray).frame(width: 3, height: 20)
                        Capsule().fill(Color.white).frame(width: 3, height: 32)
                        Capsule().fill(Color.white).frame(width: 3, height: 44)
                        Capsule().fill(Color.white).frame(width: 3, height: 30)
                        Capsule().fill(AppleIslandTokens.titaniumGray).frame(width: 3, height: 18)
                        Capsule().fill(AppleIslandTokens.titaniumGray).frame(width: 3, height: 10)
                    }
                    .frame(height: 52)
                    
                    Text("Good afternoon, Minh")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppleIslandTokens.textPrimary)
                    
                    HStack(spacing: 4) {
                        Text("Focus in Progress — 24:45")
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AppleIslandTokens.titaniumGray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                }
                .frame(maxWidth: .infinity)
                
                // Right Wing: Quick Action Glass Capsules
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white)
                        Text("Focus Session")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                        Spacer()
                        Text("⌘2")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(AppleIslandTokens.glassSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                    
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white)
                        Text("YouTube Music")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                        Spacer()
                        Text("⌘3")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(AppleIslandTokens.glassSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                    
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white)
                        Text("Scratchpad")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                        Spacer()
                        Text("⌘4")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(AppleIslandTokens.glassSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                }
                .frame(width: 175, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - 2. Apple Dynamic Island: Focus Timer View

public struct AppleDynamicIslandFocusTimerRedesign: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            AppleDynamicIslandHeaderAnchor()
            
            VStack(spacing: 8) {
                // Top: Mode Segmented Pill
                HStack(spacing: 4) {
                    Text("Focus")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .clipShape(Capsule())
                    
                    Text("Short Break")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppleIslandTokens.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    
                    Text("Long Break")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppleIslandTokens.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    
                    Text("Quick 1m")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppleIslandTokens.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .padding(2)
                .background(Color(white: 0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                
                HStack(spacing: 28) {
                    // Left: Chrono Ring dial
                    ZStack {
                        Circle()
                            .stroke(Color(white: 0.16), lineWidth: 4.5)
                            .frame(width: 86, height: 86)
                        
                        Circle()
                            .trim(from: 0, to: 0.78)
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 86, height: 86)
                        
                        VStack(spacing: 1) {
                            Text("23:45")
                                .font(.system(size: 19, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                            Text("REMAINING")
                                .font(.system(size: 7.5, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(AppleIslandTokens.titaniumGray)
                        }
                    }
                    
                    // Right: Session Telemetry, Quick Presets & Tactical Glass Controls
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white)
                            Text("DEEP WORK — SESSION 3 OF 4")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                            Spacer()
                            Text("2h 15m focused today")
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                        
                        // Presets Row
                        HStack(spacing: 6) {
                            Text("Presets:")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                            
                            ForEach(["25m", "15m", "5m", "1m"], id: \.self) { preset in
                                Text(preset)
                                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(preset == "25m" ? Color.black : Color.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(preset == "25m" ? Color.white : AppleIslandTokens.glassSurface)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                            }
                        }
                        
                        // Tactical Action Strip
                        HStack(spacing: 10) {
                            // Pause / Resume Hero Pill
                            HStack(spacing: 5) {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Pause")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Space")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(Color.black.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .clipShape(Capsule())
                            
                            // Reset
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10, weight: .medium))
                                Text("Reset")
                                    .font(.system(size: 10.5, weight: .medium))
                                Text("⇧⌘R")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppleIslandTokens.textTertiary)
                            }
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(AppleIslandTokens.glassSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                            
                            // Skip
                            HStack(spacing: 4) {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 10, weight: .medium))
                                Text("Skip")
                                    .font(.system(size: 10.5, weight: .medium))
                                Text("⇧⌘S")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(AppleIslandTokens.textTertiary)
                            }
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(AppleIslandTokens.glassSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 2)
            .padding(.bottom, 14)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - 3. Apple Dynamic Island: Music Player View

public struct AppleDynamicIslandMusicRedesign: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            AppleDynamicIslandHeaderAnchor()
            
            HStack(spacing: 20) {
                // Left Deck: Now Playing & Audio Controls (340 pt)
                HStack(spacing: 14) {
                    // Album Art
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Color(white: 0.28), Color(white: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 76, height: 76)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 26, weight: .light))
                                .foregroundStyle(Color.white.opacity(0.85))
                        )
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Midnight City")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(AppleIslandTokens.textPrimary)
                                Text("M83 — Hurry Up, We're Dreaming")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(AppleIslandTokens.textSecondary)
                            }
                            Spacer()
                            Text("LOSSLESS")
                                .font(.system(size: 7.5, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                                .foregroundStyle(AppleIslandTokens.textSecondary)
                        }
                        
                        // Scrubber Progress Bar
                        HStack(spacing: 6) {
                            Text("2:14")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                            Capsule()
                                .fill(Color(white: 0.2))
                                .frame(height: 3.5)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color.white).frame(width: 80, height: 3.5)
                                }
                            Text("-1:42")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                        
                        // Transport Controls Strip
                        HStack(spacing: 12) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 10))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 26, height: 26)
                                .overlay(Image(systemName: "pause.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.black))
                            
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                            Image(systemName: "repeat")
                                .font(.system(size: 10))
                                .foregroundStyle(AppleIslandTokens.textSecondary)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white)
                            
                            Spacer()
                            
                            // Volume icon
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                    }
                }
                .frame(width: 340, alignment: .leading)
                
                // Divider
                Rectangle()
                    .fill(AppleIslandTokens.specularRim)
                    .frame(width: 1, height: 96)
                
                // Right Deck: Music Hub & Curated Playlists (220 pt)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Quick Picks")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white)
                            .clipShape(Capsule())
                        
                        Text("Playlists")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                        
                        Text("Search")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("1")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                            Text("Outro — M83")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                            Spacer()
                            Text("4:04")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                        
                        HStack(spacing: 6) {
                            Text("2")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                            Text("Wait — M83")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                            Spacer()
                            Text("5:43")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                    }
                    .padding(6)
                    .background(Color(white: 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 10))
                        Text("AirPods Max — System Sync")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(AppleIslandTokens.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - 4. Apple Dynamic Island: Scratchpad Notes View

public struct AppleDynamicIslandNotesRedesign: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            AppleDynamicIslandHeaderAnchor()
            
            VStack(spacing: 7) {
                // Top Action Toolbar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white)
                        Text("iCloud Quick Notes")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("34 words · 210 chars")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8.5))
                            Text("Pinned to Notch")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.white)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 8.5))
                            Text("Copy All (⌘⇧C)")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppleIslandTokens.glassSurface)
                        .clipShape(Capsule())
                        .foregroundStyle(AppleIslandTokens.textSecondary)
                        
                        HStack(spacing: 3) {
                            Text("New ⌘N")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppleIslandTokens.glassSurface)
                        .clipShape(Capsule())
                        .foregroundStyle(AppleIslandTokens.textTertiary)
                    }
                }
                
                // Distraction-Free Note Canvas Deck
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("Design Sprint — Apple Dynamic Island Redesign")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                        Spacer()
                        Text("Auto-saved")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.square.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white)
                        Text("Bilateral dynamic wings for background telemetry")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "square")
                            .font(.system(size: 10))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        Text("Zero-occlusion browser and code editor coexistence")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    
                    Text("“Restraint over decoration. High contrast typography and deliberate spatial rhythm.”")
                        .font(.system(size: 10.5, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(AppleIslandTokens.textTertiary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppleIslandTokens.specularRim, lineWidth: 1))
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - 5. Apple Dynamic Island: Calendar View

public struct AppleDynamicIslandCalendarRedesign: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            AppleDynamicIslandHeaderAnchor()
            
            HStack(spacing: 22) {
                // Left: 7-Column Mini Month View (175 pt)
                VStack(spacing: 5) {
                    HStack {
                        Text("<  OCTOBER 2026  >")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                        Spacer()
                        Text("Today")
                            .font(.system(size: 8.5, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.white)
                    }
                    
                    // Days Header
                    HStack(spacing: 6) {
                        ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                            Text(d)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                                .frame(width: 15)
                        }
                    }
                    
                    // Days Grid
                    HStack(spacing: 6) {
                        ForEach(["25", "26", "27", "28", "29", "30"], id: \.self) { d in
                            Text(d)
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundStyle(AppleIslandTokens.textSecondary)
                                .frame(width: 15)
                        }
                        
                        // Today Highlight
                        Text("31")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(width: 16, height: 16)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    
                    HStack(spacing: 4) {
                        Text("Work")
                            .font(.system(size: 8.5, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.white)
                        Text("Personal")
                            .font(.system(size: 8.5, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                .frame(width: 175)
                
                // Divider
                Rectangle()
                    .fill(AppleIslandTokens.specularRim)
                    .frame(width: 1, height: 104)
                
                // Right: Upcoming Meeting Card (390 pt)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white)
                            Text("UP NEXT — 10:00 AM – 11:30 AM")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                        }
                        Spacer()
                        
                        Text("In 14m")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.white)
                    }
                    
                    Text("Apple Design Sprint Review")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppleIslandTokens.textPrimary)
                    
                    Text("Dynamic Island Architecture & Spatial HUD Guidelines")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(AppleIslandTokens.textSecondary)
                    
                    HStack(spacing: 10) {
                        // Join Call Pill
                        HStack(spacing: 5) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Join FaceTime / Meet")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                        
                        // Attendee Avatars
                        HStack(spacing: -5) {
                            Text("MN")
                                .font(.system(size: 8, weight: .bold))
                                .frame(width: 18, height: 18)
                                .background(Color(white: 0.3))
                                .clipShape(Circle())
                            Text("TC")
                                .font(.system(size: 8, weight: .bold))
                                .frame(width: 18, height: 18)
                                .background(Color(white: 0.2))
                                .clipShape(Circle())
                            Text("+2")
                                .font(.system(size: 8, weight: .bold))
                                .frame(width: 18, height: 18)
                                .background(Color(white: 0.15))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("+ Event (⌘N)")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - 6. Apple Dynamic Island: Profile & Preferences View

public struct AppleDynamicIslandProfileRedesign: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            AppleDynamicIslandHeaderAnchor()
            
            HStack(spacing: 22) {
                // Left: Apple ID Profile Avatar Card (180 pt)
                VStack(spacing: 4) {
                    Circle()
                        .fill(LinearGradient(colors: [Color(white: 0.35), Color(white: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Text("MN")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.white)
                        )
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                    
                    Text("Minh Nguyen")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppleIslandTokens.textPrimary)
                    
                    Text("Lead Architect · minh@morph.app")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(AppleIslandTokens.textTertiary)
                    
                    // Stats strip
                    HStack(spacing: 8) {
                        VStack(spacing: 1) {
                            Text("2,480m")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white)
                            Text("Focus")
                                .font(.system(size: 7.5))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                        Text("·").foregroundStyle(AppleIslandTokens.textTertiary)
                        VStack(spacing: 1) {
                            Text("14 Days")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white)
                            Text("Streak")
                                .font(.system(size: 7.5))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                        Text("·").foregroundStyle(AppleIslandTokens.textTertiary)
                        VStack(spacing: 1) {
                            Text("42")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white)
                            Text("Sessions")
                                .font(.system(size: 7.5))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(width: 180)
                
                // Divider
                Rectangle()
                    .fill(AppleIslandTokens.specularRim)
                    .frame(width: 1, height: 104)
                
                // Right: System Preferences & Ecosystem Toggles (380 pt)
                VStack(alignment: .leading, spacing: 6) {
                    Text("APPLE ECOSYSTEM & CONTROLS")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(AppleIslandTokens.textTertiary)
                    
                    HStack(spacing: 8) {
                        // Theme Tile
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Appearance")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppleIslandTokens.textSecondary)
                            Text("Obsidian Dark")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppleIslandTokens.glassSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                        
                        // Island Pinning Tile
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Island Pin (⌘P)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppleIslandTokens.textSecondary)
                            Text("Autonomous")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppleIslandTokens.glassSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                        
                        // Haptics Tile
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Haptics")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppleIslandTokens.textSecondary)
                            Text("High Precision")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppleIslandTokens.glassSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "laptopcomputer.and.iphone")
                            .font(.system(size: 10))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        Text("Active on MacBook Pro 16\" — Handoff ready on iPhone 16 Pro")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Shortcuts (⌘?)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        Spacer()
                        Text("Edit Profile")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                        Text("Sign Out")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                    }
                    .padding(.top, 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - 7. Apple Dynamic Island: Meeting Cockpit View

public struct AppleDynamicIslandMeetingCockpitRedesign: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            AppleDynamicIslandHeaderAnchor()
            
            HStack(spacing: 22) {
                // Left Wing: Live Call Info & Waveform (210 pt)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white)
                        Text("FACETIME / MEET LIVE CALL")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                    }
                    
                    Text("Spatial Design Sync")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(AppleIslandTokens.textPrimary)
                    
                    HStack(spacing: 6) {
                        Text("24:15")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                        Text("—")
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        Text("4 Participants")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    
                    // Voice Isolation Pill
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 9))
                        Text("Voice Isolation Active")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.white)
                    
                    Text("Notes: Finalize 3-tier state spring curves")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(AppleIslandTokens.textTertiary)
                }
                .frame(width: 210, alignment: .leading)
                
                // Divider
                Rectangle()
                    .fill(AppleIslandTokens.specularRim)
                    .frame(width: 1, height: 104)
                
                // Right Wing: Tactical Apple Glass Call Controls (360 pt)
                HStack(spacing: 12) {
                    // Mic Mute Toggle
                    VStack(spacing: 3) {
                        Circle()
                            .fill(Color(white: 0.15))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.white)
                            )
                            .overlay(Circle().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                        Text("Mute ⌘⇧M")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    
                    // Video Toggle
                    VStack(spacing: 3) {
                        Circle()
                            .fill(Color(white: 0.15))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "video.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.white)
                            )
                            .overlay(Circle().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                        Text("Camera ⌘⇧V")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    
                    // Screen Share
                    VStack(spacing: 3) {
                        Circle()
                            .fill(Color(white: 0.15))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "rectangle.inset.filled.and.person.filled")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.white)
                            )
                            .overlay(Circle().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                        Text("Share")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    
                    // Leave Call
                    VStack(spacing: 3) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.black)
                            )
                        Text("Leave")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - 8. Apple Dynamic Island: Drop Shelf View

public struct AppleDynamicIslandDropShelfRedesign: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            AppleDynamicIslandHeaderAnchor()
            
            VStack(spacing: 8) {
                // Header Strip
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "airdrop")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                        Text("AIRDROP DYNAMIC SHELF — 3 FILES STAGED (14.2 MB)")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("Hold: ON")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.white)
                        
                        Text("Copy Paths")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        
                        Text("Clear All")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                    }
                }
                
                // Staged Files Strip
                HStack(spacing: 10) {
                    // File 1: Mockup PNG
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(white: 0.2))
                            .frame(width: 32, height: 32)
                            .overlay(Image(systemName: "photo.fill").font(.system(size: 14)).foregroundStyle(Color.white))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Interface_Mockup.png")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                            Text("2.4 MB — Image")
                                .font(.system(size: 8.5, weight: .regular))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                    }
                    .padding(6)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                    
                    // File 2: Architecture PDF
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(white: 0.2))
                            .frame(width: 32, height: 32)
                            .overlay(Image(systemName: "doc.text.fill").font(.system(size: 14)).foregroundStyle(Color.white))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Architecture_Spec.pdf")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                            Text("8.6 MB — PDF")
                                .font(.system(size: 8.5, weight: .regular))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                    }
                    .padding(6)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                    
                    // File 3: JSON
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(white: 0.2))
                            .frame(width: 32, height: 32)
                            .overlay(Image(systemName: "curlybraces").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.white))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Island_Tokens.json")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(AppleIslandTokens.textPrimary)
                            Text("3.2 MB — Code")
                                .font(.system(size: 8.5, weight: .regular))
                                .foregroundStyle(AppleIslandTokens.textTertiary)
                        }
                    }
                    .padding(6)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                }
                
                // AirDrop Nearby Discovery Row
                HStack(spacing: 8) {
                    Text("AirDrop to:")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(AppleIslandTokens.textTertiary)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "iphone")
                            .font(.system(size: 9))
                        Text("Minh's iPhone 16 Pro")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.white)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "display")
                            .font(.system(size: 9))
                        Text("Studio Display")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(AppleIslandTokens.glassSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                    .foregroundStyle(AppleIslandTokens.textSecondary)
                    
                    Spacer()
                    
                    Text("Drag Out All Files")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3.5)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - 9. Apple Dynamic Island: Application Form Tracker View

public struct AppleDynamicIslandFormTrackerRedesign: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            AppleDynamicIslandHeaderAnchor()
            
            VStack(spacing: 7) {
                // Header with Sparkle
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "apple.intelligence")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white)
                        Text("APPLE FORM INTELLIGENCE — REAL-TIME HUD")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Text("Question 1 of 4 · 25%")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        Capsule()
                            .fill(Color(white: 0.2))
                            .frame(width: 50, height: 3.5)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color.white).frame(width: 15, height: 3.5)
                            }
                    }
                }
                
                // Active Question Box
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("What is your primary design specialization?")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                        Text("*")
                            .foregroundStyle(Color.white)
                    }
                    
                    // Interactive Option Pills
                    HStack(spacing: 6) {
                        // Selected Option
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Spatial & Dynamic Island UX")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .foregroundStyle(Color.black)
                        
                        // Option 2
                        Text("System Typography")
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(white: 0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                        
                        // Option 3
                        Text("Haptics & Motion")
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(white: 0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppleIslandTokens.specularRim, lineWidth: 0.8))
                
                // Footer Navigation
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white)
                        Text("Keychain autofill suggested: Minh Nguyen (Work)")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(AppleIslandTokens.textSecondary)
                    }
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("Export Draft")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textTertiary)
                        
                        HStack(spacing: 4) {
                            Text("Next Field ↵")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .foregroundStyle(Color.black)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - 10. Apple Dynamic Island: Compact Notch Pill HUD & Multi-Activity States

public struct AppleDynamicIslandCompactHUD: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            AppleDynamicIslandHeaderAnchor()
            
            VStack(spacing: 8) {
                Text("APPLE DYNAMIC ISLAND — COMPACT & MULTI-ACTIVITY HUD")
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(AppleIslandTokens.textTertiary)
                
                // Row 1: Dual Multi-Activity Island (Music Left + Timer Right)
                HStack(spacing: 14) {
                    // Left Island Bubble: Music Waveform
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white, Color(white: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 16, height: 16)
                        
                        HStack(spacing: 2) {
                            Capsule().fill(Color.white).frame(width: 2, height: 8)
                            Capsule().fill(Color.white).frame(width: 2, height: 14)
                            Capsule().fill(Color.white).frame(width: 2, height: 6)
                            Capsule().fill(Color.white).frame(width: 2, height: 12)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                    
                    // Center Camera Gap
                    Capsule()
                        .fill(Color(white: 0.12))
                        .frame(width: 16, height: 6)
                    
                    // Right Island Bubble: Focus Timer Countdown
                    HStack(spacing: 6) {
                        ZStack {
                            Circle().stroke(Color(white: 0.2), lineWidth: 1.5).frame(width: 12, height: 12)
                            Circle().trim(from: 0, to: 0.75).stroke(Color.white, lineWidth: 1.5).rotationEffect(.degrees(-90)).frame(width: 12, height: 12)
                        }
                        Text("23:45")
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                }
                
                // Row 2: AirDrop & Call Compact Indicators
                HStack(spacing: 16) {
                    // AirDrop Sending State
                    HStack(spacing: 5) {
                        Image(systemName: "airdrop")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                        Text("AirDrop — 3 Files Staged")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(AppleIslandTokens.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                    
                    // Live Call State
                    HStack(spacing: 5) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white)
                        Text("FaceTime — 24:15")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 2)
            .padding(.bottom, 12)
        }
        .frame(width: 640, height: 225)
        .background(AppleIslandTokens.oledBlack)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppleIslandTokens.specularRim, lineWidth: 1)
        )
    }
}

// MARK: - Individual Page Compact Floating Dynamic Island Pills

public struct AppleCompactPillHome: View {
    public init() {}
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
        }
        .frame(width: 210, height: 36)
        .background(Color.clear)
    }
}

public struct AppleCompactPillTimer: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().stroke(Color(white: 0.2), lineWidth: 1.8).frame(width: 13, height: 13)
                Circle().trim(from: 0, to: 0.75).stroke(Color.white, lineWidth: 1.8).rotationEffect(.degrees(-90)).frame(width: 13, height: 13)
            }
            Text("23:45 Focus")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
    }
}

public struct AppleCompactPillMusic: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(LinearGradient(colors: [Color.white, Color(white: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 16, height: 16)
            Text("Midnight City")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.white)
            HStack(spacing: 2) {
                Capsule().fill(Color.white).frame(width: 2, height: 7)
                Capsule().fill(Color.white).frame(width: 2, height: 13)
                Capsule().fill(Color.white).frame(width: 2, height: 9)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 5.5)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
    }
}

public struct AppleCompactPillNotes: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "note.text")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
            Text("Quick Notes — 34w")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.white)
            Image(systemName: "pin.fill")
                .font(.system(size: 8.5))
                .foregroundStyle(AppleIslandTokens.titaniumGray)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
    }
}

public struct AppleCompactPillCalendar: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 7) {
            Text("OCT 31")
                .font(.system(size: 8.5, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.white)
                .clipShape(Capsule())
                .foregroundStyle(Color.black)
            Text("Design Review in 14m")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 5.5)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
    }
}

public struct AppleCompactPillProfile: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(white: 0.3))
                .frame(width: 15, height: 15)
                .overlay(Text("MN").font(.system(size: 7.5, weight: .bold)).foregroundStyle(Color.white))
            Text("Minh Nguyen — iCloud")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
    }
}

public struct AppleCompactPillMeeting: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "video.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.white)
            Text("Spatial Sync — 24:15")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
    }
}

public struct AppleCompactPillDropShelf: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "airdrop")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
            Text("AirDrop — 3 Files Staged")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
    }
}

public struct AppleCompactPillForm: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
            Text("Q1: Spatial UX (1/4)")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppleIslandTokens.specularRim, lineWidth: 1))
    }
}
